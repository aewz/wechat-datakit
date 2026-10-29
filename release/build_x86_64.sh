#!/usr/bin/env bash
set -euo pipefail
#
# 在 x86_64 (amd64) Linux 上构建微数全解安装包。
# 用法: 在 x86_64 机器上克隆源码后运行 bash build_x86_64.sh
#
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$TOOL_DIR/.venv-x64"
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q pyinstaller pycryptodome
"$VENV/bin/pyinstaller" --onefile --name wxchat-tool --distpath "$TOOL_DIR/build/bin" --workpath "$TOOL_DIR/build/pyi" --specpath "$TOOL_DIR/build/pyi" "$TOOL_DIR/wxchat_tool.py"
"$VENV/bin/pyinstaller" --onefile --name wxchat-gui --distpath "$TOOL_DIR/build/bin" --workpath "$TOOL_DIR/build/pyi" --specpath "$TOOL_DIR/build/pyi" "$TOOL_DIR/wxchat_gui.py"
echo "构建完成: $TOOL_DIR/build/bin/"
