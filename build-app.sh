#!/bin/bash
# 把 SPM 产物包装成标准 .app bundle。
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="F50 Dashboard"
BUNDLE="build/${APP_NAME}.app"

echo "==> 编译 release"
swift build -c release

echo "==> 组装 ${BUNDLE}"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp .build/release/F50Dashboard "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>F50 Dashboard</string>
    <key>CFBundleDisplayName</key>
    <string>F50 Dashboard</string>
    <key>CFBundleExecutable</key>
    <string>F50 Dashboard</string>
    <key>CFBundleIdentifier</key>
    <string>local.majun.f50dashboard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <!-- 菜单栏常驻，平时不出现在 Dock 里 -->
    <key>LSUIElement</key>
    <true/>
    <!-- 路由器只提供明文 HTTP，需要为本地网络放行 ATS -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <!-- macOS 15 起访问局域网设备需要声明用途并由用户授权 -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>需要访问局域网内的 ZTE F50 Pro 路由器以读取其运行状态。</string>
</dict>
PLIST
echo "</plist>" >> "$BUNDLE/Contents/Info.plist"

# 未签名的 app 在本机运行需要一个 ad-hoc 签名，否则可能被直接拒绝启动
echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$BUNDLE"

echo "==> 完成: $(pwd)/${BUNDLE}"
