#!/bin/bash
# 双击安装 Local Clipboard 到「应用程序」并启动
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/Local Clipboard.app"
DEST="/Applications/Local Clipboard.app"
OLD="/Applications/ClipNest.app"

if [ ! -d "$SRC" ]; then
  echo "找不到 Local Clipboard.app，请确认它与本脚本在同一目录。"
  read -r -p "按回车退出…" _
  exit 1
fi

# 先退出正在运行的旧版本
osascript -e 'tell application "Local Clipboard" to quit' >/dev/null 2>&1 || true
pkill -f "/Applications/Local Clipboard.app/Contents/MacOS/LocalClipboard" >/dev/null 2>&1 || true
pkill -f "/Applications/ClipNest.app/Contents/MacOS/ClipNest" >/dev/null 2>&1 || true
sleep 0.6

echo "正在安装 Local Clipboard 到 /Applications …"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
xattr -dr com.apple.quarantine "$DIR/../Local Clipboard.app" 2>/dev/null || true

# 清理旧名字留下的应用（如有）
if [ -d "$OLD" ]; then
  rm -rf "$OLD"
fi

# 迁移旧数据目录（如存在且新目录还没建立）
OLD_DATA="$HOME/Library/Application Support/ClipNest"
NEW_DATA="$HOME/Library/Application Support/Local Clipboard"
if [ -d "$OLD_DATA" ] && [ ! -d "$NEW_DATA" ]; then
  cp -R "$OLD_DATA" "$NEW_DATA"
fi

echo "启动 Local Clipboard …"
open "$DEST"

echo ""
echo "安装完成！Local Clipboard 已出现在菜单栏，按 ⌘⇧V 唤出面板。"
echo "若要开机自启，请在应用内「设置 → 通用」中打开。"
sleep 1.5
