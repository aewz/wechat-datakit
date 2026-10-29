# 微数全解 WeChat DataKit

一个用于解密**用户本人**微信 4.x 本地数据库的图形化工具，并可将聊天记录导出为 CSV / JSONL / HTML。

本仓库只提供**二进制安装包**与说明文档，不包含 Python 源码。

## 安装包（v1.3.1，单文件二进制）

位于 [`release/`](release/) 目录：

- `wxchat-tool_1.3.1_arm64.deb` — Debian / Ubuntu（ARM64）安装包（推荐）
- `wxchat-tool-1.3.1-linux-arm64.tar.gz` — 免安装压缩包
- `SHA256SUMS` — 校验和

> 本版本使用 PyInstaller 打包为单文件 ELF 二进制，不附带 `.py` 源码，
> 可避免被直接阅读源码。校验和用于验证文件完整性，防止下载被篡改。

## 安装

```bash
# Debian / Ubuntu（ARM64）
sudo dpkg -i release/wxchat-tool_1.3.1_arm64.deb
```

或免安装包：

```bash
tar -xzf release/wxchat-tool-1.3.1-linux-arm64.tar.gz
cd wxchat-tool-1.3.1-linux-arm64 && bash install.sh
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
- 一键生成年度报告（月度趋势 / 高频关键词 / 活跃时段）
- 关键词搜索聊天记录
- 按个人/群聊单选或多选导出（全解 / 整理版两种模式）
- 图片 `.dat` 解密（V1 / V2 / 旧 XOR）
- 图形界面可自定义数据库目录、附件目录、输出目录
- 图形界面「输出产物」页可一键直达解密结果
- 图形界面带过渡动画与呼吸灯效果
- 首次启动显示免责声明同意书（10 秒确认）

## 系统要求

- Linux（ARM64）
- 微信 4.x 正在运行且已登录
- 密钥提取需要 root 或 CAP_SYS_PTRACE

## 用法（命令行）

```bash
wxchat-tool all --out ~/wxchat-output
wxchat-tool decrypt --keys ~/wxchat-output/all_keys.json --out ~/wxchat-output
wxchat-tool export --out ~/wxchat-output
wxchat-tool report --out ~/wxchat-output
wxchat-tool year --out ~/wxchat-output
wxchat-tool search --query 关键词 --out ~/wxchat-output
wxchat-tool images --attach-dir ~/Documents/xwechat_files/<wxid>/msg/attach
wxchat-gui
```

### 命令速查

| 命令 | 作用 |
|---|---|
| `all` | 提取密钥 + 全量解密 + 导出（一步完成） |
| `scan` | 仅提取数据库密钥 |
| `decrypt` | 仅解密（需已有 `all_keys.json`） |
| `export` | 导出联系人 / 会话 / 消息 |
| `report` | 生成统计报告 |
| `year` | 生成年度报告 |
| `search --query 词` | 关键词搜索聊天记录 |
| `images` | 解密 `.dat` 图片 |

### 输出结构

```text
<out>/
├── all_keys.json          # 每个数据库的密钥（敏感，勿外传）
├── decrypted/             # 解密后的 SQLite 数据库（已合并 WAL）
├── images/                # 解密后的图片
└── export/
    ├── contacts.csv
    ├── sessions.csv
    ├── messages.jsonl
    ├── index.html
    ├── report.html
    ├── year_report.html
    └── search_results.jsonl
```

## 语言与状态

![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)
![GUI](https://img.shields.io/badge/GUI-Tkinter-8B5CF6?style=flat)
![Database](https://img.shields.io/badge/DB-SQLCipher%204-0e8f6a?style=flat)
![Packaging](https://img.shields.io/badge/Packaging-PyInstaller-1f6feb?style=flat)
![Platform](https://img.shields.io/badge/Linux-ARM64-9cf?style=flat)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat)

> 本仓库按用户要求只发布二进制安装包与文档；源码未公开。

## 相关说明

- 算法与技术调研：见 [RESEARCH.md](RESEARCH.md)
- 免责声明：见 [DISCLAIMER.md](DISCLAIMER.md)
- 微信安全规则：见 [WECHAT_SAFETY.md](WECHAT_SAFETY.md)
- 许可证：见 [LICENSE](LICENSE)
