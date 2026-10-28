# 微数全解 WeChat DataKit

一个用于解密**用户本人**微信 4.x 本地数据库的图形化工具，并可将聊天记录导出为 CSV / JSONL / HTML。

本仓库只提供**二进制安装包**与说明文档，不包含 Python 源码。

## 安装包（v1.2.2，单文件二进制）

位于 [`release/`](release/) 目录：

- `wxchat-tool_1.2.2_arm64.deb` — Debian / Ubuntu（ARM64）安装包（推荐）
- `wxchat-tool-1.2.2-linux-arm64.tar.gz` — 免安装压缩包
- `SHA256SUMS` — 校验和

> 本版本使用 PyInstaller 打包为单文件 ELF 二进制，不附带 `.py` 源码，
> 可避免被直接阅读源码。校验和用于验证文件完整性，防止下载被篡改。

## 安装

```bash
# Debian / Ubuntu（ARM64）
sudo dpkg -i release/wxchat-tool_1.2.2_arm64.deb
```

或免安装包：

```bash
tar -xzf release/wxchat-tool-1.2.2-linux-arm64.tar.gz
cd wxchat-tool-1.2.2-linux-arm64 && bash install.sh
```

校验完整性：

```bash
sha256sum -c SHA256SUMS
```

安装后：

- 图形界面：应用菜单启动“微数全解”，或运行 `wxchat-gui`
- 命令行：`wxchat-tool`

## 功能

- 从运行中的微信进程内存提取数据库密钥（含 salt 邻域兜底）
- 全量解密微信本地数据库（主库 + WAL 合并）
- 导出联系人、会话、聊天记录
- 一键生成统计报告（消息类型 / 聊天 TOP / 24 小时分布）
- 关键词搜索聊天记录
- 图片 `.dat` 解密（V1 / V2 / 旧 XOR）
- 图形界面可自定义数据库目录、附件目录、输出目录
- 图形界面「输出产物」页可一键直达解密结果

## 系统要求

- Linux（ARM64）
- 微信 4.x 正在运行且已登录
- 密钥提取需要 root 或 CAP_SYS_PTRACE

## 用法（命令行）

```bash
wxchat-tool all --out ~/wxchat-output
wxchat-tool report --out ~/wxchat-output
wxchat-tool search --query 关键词 --out ~/wxchat-output
wxchat-gui
```

## 相关说明

- 算法与技术调研：见 [RESEARCH.md](RESEARCH.md)
- 免责声明：见 [DISCLAIMER.md](DISCLAIMER.md)
- 微信安全规则：见 [WECHAT_SAFETY.md](WECHAT_SAFETY.md)
- 许可证：见 [LICENSE](LICENSE)
