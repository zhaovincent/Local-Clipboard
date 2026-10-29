#!/bin/bash
# Local Clipboard 构建脚本：编译 -> 组装 .app -> 生成 .icns -> ad-hoc 签名 -> 打包 DMG
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Local Clipboard"      # 显示名（App 包名 / 窗口标题 / DMG 卷名）
EXEC_NAME="LocalClipboard"      # 可执行文件名（不带空格，避免启动项/脚本转义问题）
VERSION="1.0.0"
BUILD="build"
APP="$BUILD/$APP_NAME.app"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos13.0"

echo "==> 清理"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/web"

echo "==> 编译 Swift（$TARGET）"
swiftc -O -Osize -sdk "$SDK" -target "$TARGET" \
  -o "$APP/Contents/MacOS/$EXEC_NAME" \
  Sources/Models.swift \
  Sources/SettingsStore.swift \
  Sources/ImageUtils.swift \
  Sources/HistoryStore.swift \
  Sources/ClipboardMonitor.swift \
  Sources/PasteService.swift \
  Sources/HotKeyManager.swift \
  Sources/PanelController.swift \
  Sources/AppDelegate.swift \
  Sources/main.swift \
  -framework AppKit -framework WebKit -framework Carbon

echo "==> 复制资源"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Web/index.html Web/styles.css Web/app.js Web/logo.png "$APP/Contents/Resources/web/"

echo "==> 生成图标"
if [ -f Resources/AppLogo.png ]; then
  swift -sdk "$SDK" scripts/make_icon_from_image.swift Resources/AppLogo.png "$BUILD/AppIcon.iconset" Web/logo.png >/dev/null
else
  swift -sdk "$SDK" scripts/make_icon.swift "$BUILD/AppIcon.iconset" >/dev/null
fi
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> 签名"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (签名跳过)"

echo "==> 打包 DMG"
DMGROOT="$BUILD/dmgroot"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
cp scripts/Install.command "$DMGROOT/Install Local Clipboard.command"
chmod +x "$DMGROOT/Install Local Clipboard.command"
cp scripts/安装说明.txt "$DMGROOT/安装说明.txt"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMGROOT" -ov -quiet -format UDZO \
  "$BUILD/$EXEC_NAME-$VERSION.dmg"

mkdir -p dist
rm -f "dist/Local Clipboard-$VERSION.dmg" "dist/$EXEC_NAME-$VERSION.dmg"
cp "$BUILD/$EXEC_NAME-$VERSION.dmg" "dist/Local Clipboard-$VERSION.dmg"

echo ""
echo "构建完成："
echo "  应用: $APP"
echo "  安装包: dist/Local Clipboard-$VERSION.dmg"
du -sh "$APP" "dist/Local Clipboard-$VERSION.dmg"
