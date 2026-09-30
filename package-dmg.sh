#!/bin/bash
# 用 Developer ID 签名、公证并打包成可对外分发的 DMG。
#
# 前置条件（各做一次即可）：
#   1. 拥有 Developer ID Application 证书
#      Xcode › Settings › Accounts › Manage Certificates › + › Developer ID Application
#   2. 准备公证凭据，二选一：
#      a) App Store Connect API 密钥（推荐，文件式，不受钥匙串重置影响）
#         把 .p8 放到 ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8，
#         并设好 F50_KEY_ID 与 F50_ISSUER_ID 两个环境变量。
#      b) 钥匙串 profile（需要 App 专用密码，去 appleid.apple.com 生成）
#         xcrun notarytool store-credentials "f50-notary" \
#             --apple-id <你的 Apple ID> --team-id <团队 ID>
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="F50 Dashboard"
VERSION="$(defaults read "$(pwd)/build/${APP_NAME}.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo 1.0)"
NOTARY_PROFILE="${NOTARY_PROFILE:-f50-notary}"
DIST_DIR="dist"
DMG="${DIST_DIR}/F50-Dashboard-${VERSION}.dmg"

# grep 没匹配到会返回 1，在 pipefail 下得显式吞掉，否则脚本直接退出
IDENTITY="$(security find-identity -v -p codesigning \
    | { grep "Developer ID Application" || true; } \
    | head -1 \
    | sed -E 's/.*"(.*)"/\1/')"

# 没有 Developer ID 证书时退化成 ad-hoc 签名、不公证。
# 这种包只适合自用或内测：别人打开会被 Gatekeeper 拦，需要右键「打开」。
if [ -z "$IDENTITY" ]; then
    echo "⚠️  找不到 Developer ID Application 证书，改出未公证版本。" >&2
    echo "   正式分发请先在 Xcode › Settings › Accounts › Manage Certificates 创建证书。" >&2
    IDENTITY="-"
    UNSIGNED=1
    DMG="${DIST_DIR}/F50-Dashboard-${VERSION}-unsigned.dmg"
else
    UNSIGNED=0
    echo "==> 使用证书: $IDENTITY"
fi

echo "==> 重新构建"
./build-app.sh > /dev/null

echo "==> 签名 app"
if [ "$UNSIGNED" = 1 ]; then
    codesign --force --deep --sign - "build/${APP_NAME}.app"
else
    # 公证要求启用 hardened runtime，并带安全时间戳
    codesign --force --deep --options runtime --timestamp \
        --sign "$IDENTITY" "build/${APP_NAME}.app"
fi
codesign --verify --strict --verbose=2 "build/${APP_NAME}.app"

echo "==> 制作 DMG"
rm -rf "$DIST_DIR" && mkdir -p "$DIST_DIR"
STAGING="$(mktemp -d)"
cp -R "build/${APP_NAME}.app" "$STAGING/"
# 拖拽安装用的快捷方式
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" > /dev/null
rm -rf "$STAGING"

if [ "$UNSIGNED" = 1 ]; then
    echo
    echo "⚠️  完成（未公证）: $(pwd)/${DMG}"
    echo "   仅供自用或内测。对外发布需要 Developer ID 证书 + 公证。"
    exit 0
fi

echo "==> 签名 DMG"
codesign --force --sign "$IDENTITY" "$DMG"

echo "==> 提交公证（通常几分钟）"
# 优先用 API 密钥：它是磁盘上的文件，不会像钥匙串条目那样莫名消失
API_KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${F50_KEY_ID:-none}.p8"
if [ -n "${F50_KEY_ID:-}" ] && [ -n "${F50_ISSUER_ID:-}" ] && [ -f "$API_KEY" ]; then
    echo "    使用 API 密钥 $F50_KEY_ID"
    NOTARY_AUTH=(--key "$API_KEY" --key-id "$F50_KEY_ID" --issuer "$F50_ISSUER_ID")
else
    echo "    使用钥匙串 profile $NOTARY_PROFILE"
    NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
fi

xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait

echo "==> 装订公证票据"
# 装订后即使离线，Gatekeeper 也能验证通过
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "✅ 完成: $(pwd)/${DMG}"
