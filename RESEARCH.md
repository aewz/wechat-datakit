# 算法与技术调研（结合开发记录）

本文件汇总本工具在开发过程中参考的公开仓库、可用算法与技术，并说明哪些已整合进 v1.2.0。

## 0. 参考仓库索引

| 仓库 | 平台 | 核心价值 |
|---|---|---|
| `TANGandXUE/wcdb-key-tool` | Linux x86_64 | ELF 静态分析 + GDB 断点抓 passphrase；PBKDF2 派生 |
| `josephdavis/wechat-decrypt` | Win/Linux/macOS | 内存扫 `x'<key><salt>'`；SQLCipher4 页面/WAL；图片 V1/V2/XOR |
| `328336690/wechat-decrypt` | Win/Linux/macOS | 同上游，含 WAL patch、MCP、图片解码 |
| `r266-tech/wxkey` | macOS/Go | salt 邻域、二进制堆哨兵、只读区、bare-hex 四类扫描策略 |
| `stargazer-2026/wechat-4.1.12-decrypt` | Windows | 4.1.11+ 密钥格式变化；Frida 抓 password；sender 映射坑 |
| `hwdemtv/wechat-self-analysis` | Windows | 离线自我行为分析报告（消息导出+统计） |
| `rmqg/wechat-mac-export` | macOS | lldb 断点 CommonCrypto 抓 per-DB key |
| `lopleec/wxchat-export` | macOS/Linux | CLI 导出 Markdown/JSONL；GDB 抓 key |
| `wxq` (PyPI) | Win/macOS/Linux | 本地查询 CLI，SQLCipher4 + WAL |
| `sjzar/chatlog` | Go | 解密数据库 + 聊天记录迁移导入 |
| `0xlane/wechat-dump-rs` | Rust | SQLCipher 4 正确实现参考 |
| `robbin/wechat-exporter` | macOS | Claude Code / Codex skill 规范，页面格式与 WAL 验收 |
| `huangserva/wechat-radar` | macOS | SQLCipher4 全量+WAL 增量，企业微信扩展 |
| `Panther114/Weport` | Windows | 从 MMKV `key_<code>_*.statistic` 离线派生图片 key |
| `H3CoF6/py_wx_key` | Windows | DB key hook + 图片 key 本地计算 |
| `lyrcsjy/wechat-decrypt` / `hicccc77/WeFlow` | macOS | V2 图片 key = `MD5(uin+wxid)[:16]` 派生 |
| `zhizunbao84/WeChatDataAnalysis` | Windows | 年度总结、朋友圈导出 |
| `JamesHopbourn/WeChatDataAnalysis` | Windows | 老版本可视化分析思路 |
| `Jintian-JTST/WeChat-Annual-Report-Generation` | 跨平台 | Spotify Wrapped 式年度报告，全年热力图 / 作息分布 |
| `caigee-cmd/wechat-insight` | macOS | 单文件 HTML 滑动年报，关系/商机/情绪/表达习惯 |
| `yuanfangdeshang/2025-WeChat-Annual-Chat-Report-Generator` | Python | 好友默契度、社交人格测试、年度称号 |
| `raclen/wechat-suite` | 本地 | 从数据库导出后用大模型按天生成 Markdown 群聊日报 |
| `kdnsna/WeChatDataAnalysis-` | Windows | 高仿微信界面 + 年度总结 + 朋友圈导出 |
| `chainlesschain/chainlesschain` | Android/PDH | frida 抓 `libWCDB.so` 的 `sqlite3_key` 思路与 Runbook |
| `ylytdeng/wechat-decrypt` | Win/Linux/macOS | wechat-decrypt 上游，内存扫描基础实现 |
| `Bryan-Cyf/WeChatDaily` | Win/Linux/macOS | 工具集：个人微信 SQLCipher4 + 企业微信 wxSQLite3 AES-128 |
| `wxq` (PyPI) | Win/macOS/Linux | 本地查询 CLI + MCP，SQLCipher4 + WAL + `wxq export` |
| `liuxiaogang/wx-group-report` | 本地 | 群聊日报/周报，AI 生成 roast/wrapped/tabloid/esports 四种风格 |
| WeChat MCP servers (glama) | macOS | 只读 MCP 查询会话/聊天/联系人/群成员 |

## 1. 数据库密钥提取

### 1.1 内存扫描 `x'<enc_key><salt>'`

微信 4.x 的 WCDB 会把派生后的 raw key 以 SQL 字面量形式缓存在进程内存：

```text
x'<64位 hex enc_key><32位 hex salt>'
```

通过遍历微信进程可读内存区域，正则匹配该模式，再用数据库 page 1 做 HMAC 校验即可确认。

- 来源：`josephdavis/wechat-decrypt`、`328336690/wechat-decrypt`
- 已整合：本工具 `scan` 子命令即使用该算法，并额外支持纯 64-hex（无 `x'...'` 包裹）匹配。

### 1.2 HMAC 校验（SQLCipher 4）

```text
salt      = db[0:16]
mac_salt  = salt XOR 0x3a
mac_key   = PBKDF2-HMAC-SHA512(enc_key, mac_salt, 2, dklen=32)
valid     = HMAC-SHA512(mac_key, db[16:4032] + pack("<I",1)) == db[4032:4096]
```

- 来源：SQLCipher 4 公开格式；`wechat-decrypt`、`wcdb-key-tool`
- 已整合：`verify_enc_key()`。

### 1.3 PBKDF2 主密钥派生

拿到 32 字节 password 后，每个库用自己的 salt 派生 enc_key：

```text
enc_key = PBKDF2-HMAC-SHA512(password, db[0:16], 256000, dklen=32)
```

- 来源：`TANGandXUE/wcdb-key-tool`、`stargazer-2026/wechat-4.1.12-decrypt`

### 1.4 salt 邻域扫描（新整合）

部分版本不再保留 `x'...'` 字符串，但 SQLCipher codec 上下文仍可能把
`salt` 与 `enc_key` 的原始字节放在一起。算法：

1. 在进程内存中查找某个数据库 salt 的原始 16 字节；
2. 在命中位置 ±4096 字节窗口内，逐个尝试 32 字节候选作为 enc_key；
3. 用 page 1 HMAC 校验。

- 来源：`r266-tech/wxkey` 的 `IncludeSaltNeighborhood`
- 已整合：本工具 `scan` 自动执行该兜底。

### 1.5 二进制堆布局哨兵模式（调研，待整合）

新版微信可能把 32 字节 password 作为原始字节放在堆布局哨兵附近，例如：

```text
哨兵: 20 66 74 73 35 28 25 00   (" fts5(%\0")
候选偏移: +16 / -80 / +64
```

候选需用 256000 轮 PBKDF2 验证，成本高，适合作为最后兜底。

- 来源：`r266-tech/wxkey`、`ai-hermes/chatlog`

### 1.6 GDB 断点捕获 password（Linux x86_64）

Linux 微信不暴露符号，需 ELF 静态分析：在 `.rodata` 中找
`com.Tencent.WCDB.Config.Cipher`，顺交叉引用找到处理密钥的函数入口，
再用 GDB 断点，在重新登录时从寄存器读取 32 字节 password。

- 来源：`TANGandXUE/wcdb-key-tool`
- 说明：本工具当前在 ARM64 上以内存扫描为主，未移植 x86_64 GDB 方案。

## 2. 数据库解密

### 2.1 SQLCipher 4 页面格式

```text
page 1:  [0:16]=salt | [16:4016]=密文 | [4016:4032]=IV | [4032:4096]=HMAC
page N:  [0:4016]=密文 | [4016:4032]=IV | [4032:4096]=HMAC
```

AES-256-CBC，无 padding（SQLCipher 自管）。

- 来源：`wechat-decrypt`、`stargazer-2026/wechat-4.1.12-decrypt`
- 已整合：`decrypt_page()`。

### 2.2 WAL 帧合并

WAL 帧格式：

```text
frame = pgno(4, 大端) + dbsize(4, 大端) + salt(8, 大端) + page(4096)
```

只合并帧 salt 与 WAL header salt 一致的当前周期帧；旧周期帧已 checkpoint 进主库。
解密 WAL 页用主库 enc_key。

- 来源：`wechat-decrypt/monitor_web.py`、`stargazer-2026/wechat-4.1.12-decrypt`
- 已整合：`decrypt_wal_full()`。

## 3. 图片 `.dat` 解密

### 3.1 三种格式

| 格式 | Magic | 算法 | 密钥 |
|---|---|---|---|
| 旧 XOR | 无 | 单字节 XOR | 自动检测 |
| V1 | `07 08 V1 08 07` | AES-128-ECB + XOR | 固定 `cfcd208495d565ef` |
| V2 | `07 08 V2 08 07` | AES-128-ECB + XOR | 从进程内存提取 |

- 来源：`wechat-decrypt/decode_image.py`
- 已整合：`decode_one_dat()`。

### 3.2 V2 图片密钥本地派生（macOS / 部分平台）

```text
xor_key = uin & 0xFF
aes_key = MD5(str(uin) + normalized_wxid).hexdigest()[:16]
```

uin 来源：

1. kvcomm 缓存文件名 `key_<uin>_*.statistic`
2. wxid 目录后 4 位 == `md5(str(uin))[:4]`，枚举反推

- 来源：`lyrcsjy/wechat-decrypt`、`hicccc77/WeFlow`、`H3CoF6/py_wx_key`
- 说明：Linux 当前未发现 kvcomm 缓存，故 Linux 仍走内存扫描。

## 4. 消息导出的已知坑

- 消息表名 = `Msg_<MD5(wxid)>`，需用 `Name2Id` 表映射。
- `real_sender_id` 在不同消息库（message_0/1/2/3）中含义可能不同甚至相反，逐库需锚点句验证。
- `local_type`: 1=文本, 47=表情, 3/34/43=图片/语音/视频, 10000=系统消息。
- 手机备份 `Backup.db` 用手机端独立密钥，PC 端无法解密。

- 来源：`stargazer-2026/wechat-4.1.12-decrypt`

## 5. 已整合清单（v1.2.0）

- [x] 内存扫描 `x'<key><salt>'` + 纯 64-hex
- [x] SQLCipher 4 HMAC 校验 + 页面解密 + WAL 合并
- [x] salt 邻域兜底扫描
- [x] 图片 V1 / V2 / 旧 XOR 解码 + 内存 AES key 扫描
- [x] 图形界面与自定义存储位置
- [x] PyInstaller 单文件二进制分发（不附带 Python 源码）

## 6. 年度报告与关键词算法（v1.2.3）

### 6.1 年度报告（参考 `hicccc77/WeFlow`）

WeFlow 提供“年度报告 / 双人报告 / 私聊分析 / 群聊分析”。本工具吸收其
“年度报告”思想，新增 `year` 子命令，按年或全量生成：

- 总消息数、会话数、文本消息数、活跃月份
- 月度消息量柱状图
- 高频关键词 TOP30
- 聊天 TOP15
- 24 小时活跃分布
- 消息类型分布

### 6.2 轻量中文关键词提取（自研，无需 jieba）

```text
1. 对文本做 CJK 连续串正则 [\u4e00-\u9fff]{2,}
2. 对每个连续串统计 2-gram 词频
3. 过滤单字停用词
4. 英文词 [A-Za-z]{2,} 统一小写计数
5. 合并排序取 TOP N
```

优点：零第三方依赖，适合打包进单文件二进制；缺点：无分词语义，适合高频词概览。

## 7. 防检测设计（自研说明）

本工具读取微信密钥/图片密钥时，采用**只读被动扫描**，不注入、不 Hook、不 ptrace：

- 通过 `/proc/<pid>/mem` 直接读取可读内存区域
- 不 `attach` 调试器，不修改微信任何指令/数据
- 默认只扫匿名 RW 区域，跳过系统库，减少触发微信 anti-debug 的概率
- 候选密钥只做本地 HMAC 校验，不写入、不上传

这比 GDB/Frida 注入方案更“安静”，不容易被微信的反调试/完整性检测发现。

## 8. 可视化与年度报告类仓库（v1.3.2 收录）

### 8.1 Spotify Wrapped 式年度报告

- `Jintian-JTST/WeChat-Annual-Report-Generation`：把整年聊天记录生成可滚动、可分享的
  年度报告，包含全年活跃热力图（GitHub 贡献图风格）与 24 小时作息分布。
- `caigee-cmd/wechat-insight`：基于已导出的 JSONL 生成“滑动年报”，覆盖关系、商机、
  情绪、表达习惯四个维度，输出单文件 HTML。
- `yuanfangdeshang/2025-WeChat-Annual-Chat-Report-Generator`：好友默契度、社交人格测试、
  年度称号等游戏化维度。

可借鉴点：

```text
1. 活跃热力图：按 年 × 周 × 日 聚合消息数，渲染 GitHub-style 格子
2. 作息分布：按小时聚合 + 按消息类型分层
3. 关系维度：TOP 聊天、双向消息比例、回复间隔
4. 表达习惯：词频、消息长度、表情使用偏好
5. 人格/称号：基于统计规则生成趣味标签
```

### 8.2 大模型整理与日报

- `raclen/wechat-suite`：先导出聊天记录，再用大模型按天生成 Markdown 群聊日报，可渲染成 PNG。

借鉴意义：本工具当前只做确定性统计；后续可在“整理版”导出后接入本地大模型做摘要，
仍保持本地处理。

### 8.4 企业微信与 MCP 扩展

- `Bryan-Cyf/WeChatDaily`：除个人微信 SQLCipher4 外，还提供企业微信
  `wxSQLite3 AES-128` 解密实现，适合扩展企微导出。
- `wxq`：命令行本地查询并暴露 MCP，支持 `wxq export "Alice"` 直接导出单聊。
- `liuxiaogang/wx-group-report`：AI 群聊日报，支持 roast（脱口秀）、wrapped（年报）、
  tabloid（八卦周刊）、esports（战报）四种文风。
- WeChat MCP servers：只读 MCP，可把本地解密能力接到 Claude/Codex 等 Agent。

### 8.3 密钥提取补充

- `chainlesschain/chainlesschain`：Android 侧用 frida attach `libWCDB.so` 的
  `sqlite3_key` 导出函数抓 key 的思路，与本工具的只读内存扫描互补（仅作学习参考）。
- `ylytdeng/wechat-decrypt`：`josephdavis/wechat-decrypt` 的上游，内存扫描基础实现出处。
