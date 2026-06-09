# V6 交易引擎自检清单 Skill

> 最后更新：2026-06-09 | 来源：TOOLS.md V6 自检清单（2026-05-27 迭代）

## 使用方式

当老公要求「自检」「检查引擎」「巡检V6」时，自动加载本skill，按以下清单逐项检查并输出报告。

## 自检覆盖范围（必须遍历全部文件）

```
src/    ← engine.js, server.js, binance.js, db.js, auth.js
admin/  ← index.html, login.html  ← 之前漏了！
```

---

## 一、核心 13 维（D1-D13）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| D1 | 语法安全 | `node --check` 全部JS文件（含 admin/） | 零错误退出 |
| D2 | 参数一致性 | 策略参数与文档逐项核对（19项） | 全部一致 |
| D3 | API联通性 | Binance 余额/持仓/K线/杠杆设置 | 全部返回正常 |
| D4 | 引擎运行 | 进程/端口/CPU/内存/启动时间 | 进程存活、端口监听 |
| D5 | 🔥函数计算逻辑 | 全部核心计算节点（见下方子项） | 计算结果正确 |
| D6 | 状态机 | IDLE→MONITOR→OPEN→COOLDOWN 流转 | 流转无死锁 |
| D7 | 数据持久化 | DB日志/交易记录 + 持仓状态落地 | 重启后从DB恢复持仓 |
| D8 | 余额与开仓 | getBalance()用walletBalance而非availableBalance | 余额×杠杆≥最小开仓量 |
| D9 | 版本号 | VERSION 与 CHANGELOG 一致 | 版本号匹配 |
| D10 | 端口健康 | `sudo ss -tlnp \| grep 3040` | 端口正常监听 |
| D11 | 重启计数 | `systemctl show trading-v6 \| grep NRestarts` | 应为0或小数字 |
| D12 | 系统资源 | 磁盘/内存/负载 | 磁盘<85%、内存<85%、负载<3.0 |
| D13 | 函数调用审计 | 自定义函数参数个数/类型核对 | 参数匹配 |

### D5 子项详解

| 子项 | 检查点 | 验证方法 |
|------|--------|---------|
| 开仓量计算 | bal×leverage/price 乘除正确 | 核对代码行 |
| 平仓PnL | (exit-entry)×qty 多空方向正确 | 核对代码行 |
| 入场均价 | cummulativeQuoteQty/executedQty | 核对代码行 |
| 止损/止盈 | ±$20/$80 阈值正确 | 核对配置值 |
| 移动止盈 | 极值回撤距离计算正确 | 核对代码行 |

### D13 函数参数参考

| 函数 | 参数个数 | 说明 |
|------|---------|------|
| openPosition | 6个 | 开仓函数 |
| closePosition | 4个 | 平仓函数 |
| getOpenPosition | 1个 | 获取持仓 |

---

## 二、前端/管理面板（F1-F4）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| F1 | API调用审查 | admin前端调用的每个API端点：方法(GET/POST)、路径、参数正确性 | 全部匹配后端定义 |
| F2 | 定时器审计 | 所有setInterval/setTimeout是否合理 | 不会造成重复/误调用 |
| F3 | 前端功能验证 | 启动/停止按钮只响应手动点击 | 不被自动流程触发 |
| F4 | 注释与实际一致 | 注释描述的功能与代码实际行为是否相符 | 注释准确 |

> ⚠️ 踩坑记录：admin曾误调 /engine/start

---

## 三、异常容错（E1-E5）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| E1 | 端口自愈 | EADDRINUSE时自动fuser -k杀僵尸+1秒重试 | 自愈机制存在 |
| E2 | 所有catch审计 | 检查是否有catch(e){}空吃错误 | 无空catch |
| E3 | 进程级兜底 | 进程崩溃后systemd自动恢复 | 自动恢复生效 |
| E4 | 熔断保护 | StartLimitBurst=3，60秒内崩>3次即停 | 熔断配置正确 |
| E5 | 定时器防泄露 | 每次setInterval前先clearInterval旧的 | 无定时器泄露 |

---

## 四、架构韧性（A1-A4）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| A1 | 状态持久化 | 持仓/监控状态是否落地DB，重启后能恢复 | DB中有持仓记录 |
| A2 | 崩溃恢复 | 完整恢复路径：语法检查→端口自愈→状态还原→熔断保护 | 全链路通畅 |
| A3 | 日志健康 | info/warn/error 与 debug 分离，events端点只展示关键事件 | 日志分级正确 |
| A4 | 重启计数监控 | NRestarts>10 应触发微信报警 | 报警机制存在 |

---

## 五、历史回溯（H1-H5）★ 过往踩坑复盘

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| H1 | 定时器循环可靠性 | _tick的setTimeout在finally里？.catch()兜底？_tickBusy锁？ | 三元锁完整 |
| H2 | 异常兜底 | 每个catch块都有恢复机制？会不会卡死在异常态？ | 无死锁catch |
| H3 | COOLDOWN恢复 | 每个COOLDOWN设置点都有对应的回IDLE定时器？ | 定时器完备 |
| H4 | 仓位三方对齐 | engine内存状态 vs DB vs 币安 | 三方一致 |
| H5 | 推送通道 | WebSocket实时bookTicker正常？微信推送信号可达？ | 通道畅通 |

---

## 六、关键路径审计（C1-C6）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| C1 | 完整启动链 | start()→_tick()→_sync()每步状态变化正确 | 启动链完整 |
| C2 | 完整停止链 | stop()确实停止了所有资源（WS/定时器/tick循环） | 资源全释放 |
| C3 | 状态机完整性 | IDLE→MONITOR→OPEN→COOLDOWN每条边都有守卫和恢复 | 无死角 |
| C4 | 外部干预路径 | API端点/管理页面/手动操作对引擎状态的意外影响 | 无意外副作用 |
| C5 | 变更验证 | 改代码后自动执行node --check + git tag + CHANGELOG记录 | 变更可追溯 |
| C6 | 回滚验证 | rollback.sh可用、git tag存在、回滚后能正常启动 | 回滚可用 |

---

## 七、新增优化验证（O1-O3）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| O1 | systemd守护 | `systemctl is-active trading-v6` | active/running/开机自启 |
| O2 | SQLite自动备份 | 检查cron任务和备份文件 | 每小时/保留72h |
| O3 | WS可靠性加固 | 节流+心跳+回落K线机制 | 机制完整 |

---

## 八、安全与持久维度（S1-S7）

| 编号 | 维度 | 检查方法 | 判定标准 |
|------|------|---------|---------|
| S1 | 密钥健康 | Binance API Key 有效性/权限/过期日 | Key有效未过期 |
| S2 | 配置持久化 | 网页配置⇔运行中this.cfg一致性 | 配置同步 |
| S3 | WS重连 | WebSocket彻底断开后自动重连机制生效 | 重连成功 |
| S4 | 价格安全 | 零值/插针/异常价格检测过滤 | isFinite+零值过滤 |
| S5 | 故障恢复 | 服务器重启后持仓自动同步（syncPosition） | 同步成功 |
| S6 | 日志容量 | DB文件/日志文件大小预警 | DB<20MB、日志已轮转 |
| S7 | 内存趋势 | 长时间运行内存增长曲线（泄漏检测） | 无持续增长 |

---

## 九、升级/回滚流程

### 升级流程
```bash
1. ./pre_upgrade_check.sh          # 先自检（语法/Git/引擎/systemd/磁盘）
2. git add . && git commit -m "v6.x.x 功能说明"
3. git tag v6.x.x-stable           # 打标签
4. git push origin master --tags   # 推送到远端（如果有remote）
5. sudo systemctl restart trading-v6.service
6. 观察日志5分钟确认运行正常
```

### 回滚流程
```bash
# 方式1：一键回滚（推荐）
sudo ./rollback.sh                  # 默认回 v6.1.0-stable
sudo ./rollback.sh 81c1f33          # 回特定版本(commit hash)

# 方式2：手动
cd /home/ubuntu/trading-v6
git reset --hard v6.1.0-stable
sudo systemctl restart trading-v6.service
```

---

## 十、修复历史（备忘）

```
① bal/leverage→bal*leverage line 207
② 开仓失败→COOLDOWN+定时器 line 219
③ 外部平仓→COOLDOWN+定时器 line 248
④ 平仓3次失败→COOLDOWN+定时器 line 240
⑤ 实时WS移动止盈 lines 253-302
⑥ systemd守护进程 /etc/systemd/
⑦ SQLite备份 cron hourly
⑧ WS节流/心跳/回落 engine.js
⑨ _tick循环finally+_tickBusy+.catch 三元锁
⑩ _processMonitoring加载this.cfg 保证配置刷新
⑪ _executeExit平仓重试 最多3次间隔2秒
⑫ syncPosition 检测外部开仓覆盖已有持仓修复
⑬ S4 价格安全 — WS消息加isFinite+零值过滤
⑭ S6 日志容量 — logrotate每周轮转+DB>20MB预警
⑮ 升级/回滚方案 — git tag + rollback.sh + pre_upgrade_check.sh
⑯ toFixed(3)向上取整→Math.floor向下取整 修复余额不足Bug (V6.1.1)
⑰ systemd ExecStartPre — node --check 全量JS文件，语法错误禁止启动
⑱ EADDRINUSE自动杀僵尸 — server.js listen报端口被占时fuser -k + 1秒重试
⑲ systemd熔断 — StartLimitIntervalSec=60 + StartLimitBurst=3，不再死循环436次
⑳ 持仓持久化 — openPosition/closePosition/getOpenPosition 写入DB，重启恢复
㉑ F1/F2降debug — 122733条F1日志不再刷屏，/v6/api/events只看关键事件
```

---

## 自检报告输出模板

```
## V6 交易引擎自检报告
- 时间：YYYY-MM-DD HH:mm
- 版本：v6.x.x
- 服务器：新加坡(154.12.40.196)

### 检查结果汇总
| 维度 | 总项 | 通过 | 异常 | 跳过 |
|------|------|------|------|------|
| 核心(D1-D13) | 13 | x | x | x |
| 前端(F1-F4) | 4 | x | x | x |
| 容错(E1-E5) | 5 | x | x | x |
| 韧性(A1-A4) | 4 | x | x | x |
| 回溯(H1-H5) | 5 | x | x | x |
| 路径(C1-C6) | 6 | x | x | x |
| 优化(O1-O3) | 3 | x | x | x |
| 安全(S1-S7) | 7 | x | x | x |
| **合计** | **47** | **x** | **x** | **x** |

### 异常项详情
（列出每个异常项的具体问题和建议修复方案）

### 结论
🟢 全部通过 / 🟡 有警告但可运行 / 🔴 有致命问题需立即修复
```
