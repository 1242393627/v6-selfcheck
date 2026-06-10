# V6 Trading Engine Self-Check Skill

> 一套完整的量化交易引擎自动化自检清单，覆盖47项检查维度，支持一键脚本和代码级审计。

## 概述

专为 V6 量化交易系统设计的自检工具，将运维经验沉淀为标准化检查流程。适用于基于 Node.js + Binance API 的加密货币自动交易系统。

## 功能特性

- **47项自检维度** — 覆盖语法安全、策略参数、API联通、状态机、异常容错、架构韧性等8大类
- **一键自动化脚本** — SSH远程执行，自动检测进程/端口/磁盘/内存/systemd状态
- **代码级审计** — 逐行检查函数计算逻辑、catch兜底、定时器泄露、价格安全等
- **标准化报告** — 统一输出格式，✅通过/❌异常/⚠️警告一目了然
- **历史踩坑记录** — 内置21条修复历史，避免重复犯错

## 检查维度总览

| 维度 | 项目数 | 覆盖内容 |
|------|--------|---------|
| 核心(D1-D13) | 13 | 语法安全、参数一致性、API联通、引擎运行、函数计算逻辑、状态机、数据持久化、余额逻辑、版本号、端口健康、重启计数、系统资源、函数调用审计 |
| 前端(F1-F4) | 4 | API调用审查、定时器审计、前端功能验证、注释与实际一致 |
| 异常容错(E1-E5) | 5 | 端口自愈、catch审计、进程级兜底、熔断保护、定时器防泄露 |
| 架构韧性(A1-A4) | 4 | 状态持久化、崩溃恢复、日志健康、重启计数监控 |
| 历史回溯(H1-H5) | 5 | 定时器循环、异常兜底、COOLDOWN恢复、仓位对齐、推送通道 |
| 关键路径(C1-C6) | 6 | 启动链、停止链、状态机完整性、外部干预、变更验证、回滚验证 |
| 优化验证(O1-O3) | 3 | systemd守护、SQLite备份、WS可靠性加固 |
| 安全维度(S1-S7) | 7 | 密钥健康、配置持久化、WS重连、价格安全、故障恢复、日志容量、内存趋势 |

## 文件结构

```
v6-selfcheck/
├── SKILL.md            # 完整47项自检清单（检查方法+判定标准+报告模板）
├── check-script.sh     # 自动化检查脚本（SSH远程执行）
└── README.md           # 本文件
```

## 快速开始

### 1. 自动化脚本检查

```bash
# 基本用法
bash check-script.sh <服务器IP> <SSH端口>

# 示例
bash check-script.sh 154.12.40.196 63197
```

脚本自动检测：
- D1 语法安全（node --check）
- D4 引擎进程存活
- D10 端口监听状态
- D11 systemd重启计数
- D12 系统资源（磁盘/内存/CPU负载）
- O1 systemd服务状态
- O2 备份cron任务
- D7 数据库文件
- S6 日志容量

### 2. 代码级审计

需要拉取源代码后逐项检查：

```bash
# 拉取代码
scp -r user@server:/path/to/trading-v6/*.js ./audit/

# 语法检查
node --check audit/engine.js
node --check audit/server.js
node --check audit/binance.js
node --check audit/db.js

# 空catch审计
grep -n 'catch(e){}' audit/engine.js

# 定时器审计
grep -n 'setInterval\|clearInterval' audit/engine.js

# 价格安全审计
grep -n 'isFinite' audit/engine.js
```

### 3. 报告输出格式

```
## V6 交易引擎自检报告
- 时间：YYYY-MM-DD HH:mm
- 版本：v6.x.x
- 服务器：新加坡(xxx.xxx.xxx.xxx)

### 检查结果汇总
| 维度 | 总项 | ✅通过 | ❌异常 | ⚠️警告 |
|------|------|--------|--------|--------|
| 核心(D1-D13) | 13 | x | x | x |
| ... | ... | ... | ... | ... |
| **合计** | **47** | **x** | **x** | **x** |

### 结论
🟢 全部通过 / 🟡 有警告但可运行 / 🔴 有致命问题需立即修复
```

## D5 函数计算逻辑详解

这是最容易出Bug的维度，必须逐项核对：

| 子项 | 正确公式 | 常见错误 |
|------|---------|---------|
| 开仓量 | `Math.floor(bal × leverage / price × 1000) / 1000` | 乘除反了 |
| 平仓PnL（多） | `(exit - entry) × qty` | 方向反了 |
| 平仓PnL（空） | `(entry - exit) × qty` | 方向反了 |
| 入场均价 | `cummulativeQuoteQty / executedQty` | 用错字段 |
| 止损阈值 | `delta <= -slOffset` | 符号反了 |
| 移动止盈 | `极值 - 当前价 >= pullback` | 回撤距离计算 |

## 历史踩坑记录

内置21条修复历史，每条都是真实生产事故的复盘：

```
① bal/leverage→bal*leverage（乘除反了）
② 开仓失败→COOLDOWN+定时器（异常恢复）
⑨ _tick循环finally+_tickBusy+.catch（三元锁）
⑯ toFixed(3)向上取整→Math.floor向下取整（余额不足Bug）
⑰ systemd ExecStartPre（语法错误禁止启动）
⑱ EADDRINUSE自动杀僵尸（端口自愈）
⑲ systemd熔断（不再死循环436次）
⑳ 持仓持久化（重启恢复）
...
```

## 适用场景

- **日常巡检** — 定期运行脚本检查引擎健康状态
- **代码变更后** — 修改engine.js/server.js后立即自检
- **升级前** — 执行pre_upgrade_check.sh前先跑一遍
- **故障排查** — 引擎异常时逐项定位问题根因
- **新人上手** — 了解交易系统有哪些需要注意的检查点

## 依赖

- Node.js 18+
- SSH访问目标服务器
- systemd管理的交易服务

## 许可

MIT License

## 作者

香菜
