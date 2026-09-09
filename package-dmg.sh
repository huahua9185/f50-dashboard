#!/bin/bash
# 用 Developer ID 签名、公证并打包成可对外分发的 DMG。
#
# 前置条件（各做一次即可）：
#   1. 拥有 Developer ID Application 证书
#      Xcode › Settings › Accounts › Manage Certificates › + › Developer ID Application
#   2. 存好公证凭据（需要 App 专用密码，去 appleid.apple.com 生成）
#      xcrun notarytool store-credentials "f50-notary" \
#          --apple-id <你的 Apple ID> --team-id <团队 ID> --password <App 专用密码>
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="F50 Dashboard"
VERSION="$(defaults read "$(pwd)/build/${APP_NAME}.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo 1.0)"
NOTARY_PROFILE="${NOTARY_PROFILE:-f50-notary}"
DIST_DIR="dist"
DMG="${DIST_DIR}/F50-Dashboard-${VERSION}.dmg"

IDENTITY="$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" \
    | head -1 \
    | sed -E 's/.*"(.*)"/\1/')"

if [ -z "$IDENTITY" ]; then
    echo "错误：找不到 Developer ID Application 证书。" >&2
    echo "请在 Xcode › Settings › Accounts › Manage Certificates 中创建后重试。" >&2
    exit 1
fi
echo "==> 使用证书: $IDENTITY"

echo "==> 重新构建"
./build-app.sh > /dev/null

echo "==> 签名 app"
# 公证要求启用 hardened runtime，并带安全时间戳
codesign --force --deep --options runtime --timestamp \
    --sign "$IDENTITY" "build/${APP_NAME}.app"
codesign --verify --strict --verbose=2 "build/${APP_NAME}.app"

echo "==> 制作 DMG"
rm -rf "$DIST_DIR" && mkdir -p "$DIST_DIR"
STAGING="$(mktemp -d)"
cp -R "build/${APP_NAME}.app" "$STAGING/"
# 拖拽安装用的快捷方式
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" > /dev/null
rm -rf "$STAGING"

echo "==> 签名 DMG"
codesign --force --sign "$IDENTITY" "$DMG"

echo "==> 提交公证（通常几分钟）"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> 装订公证票据"
# 装订后即使离线，Gatekeeper 也能验证通过
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "✅ 完成: $(pwd)/${DMG}"
