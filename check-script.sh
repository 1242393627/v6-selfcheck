#!/bin/bash
# V6 交易引擎自动化自检脚本
# 用法：bash check-script.sh [服务器IP] [SSH端口]
# 示例：bash check-script.sh 154.12.40.196 63197

SERVER="${1:-154.12.40.196}"
PORT="${2:-63197}"
SSH_CMD="ssh -p $PORT -o ConnectTimeout=10 root@$SERVER"
V6_DIR="/home/ubuntu/trading-v6"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local label="$1"
    local result="$2"
    if [ "$result" = "PASS" ]; then
        echo -e "  ${GREEN}✅${NC} $label"
        ((PASS++))
    elif [ "$result" = "WARN" ]; then
        echo -e "  ${YELLOW}⚠️${NC} $label"
        ((WARN++))
    else
        echo -e "  ${RED}❌${NC} $label"
        ((FAIL++))
    fi
}

echo "========================================"
echo "V6 交易引擎自检报告"
echo "时间：$(date '+%Y-%m-%d %H:%M')"
echo "服务器：$SERVER:$PORT"
echo "========================================"
echo ""

# === D1 语法安全 ===
echo "【D1 语法安全】"
SYNTAX_RESULT=$($SSH_CMD "cd $V6_DIR && node --check src/*.js src/**/*.js admin/**/*.js 2>&1" 2>/dev/null)
if [ $? -eq 0 ]; then
    check "node --check 全量JS文件" "PASS"
else
    check "node --check 全量JS文件 — $SYNTAX_RESULT" "FAIL"
fi

# === D4 引擎运行 ===
echo ""
echo "【D4 引擎运行】"
PROC_CHECK=$($SSH_CMD "pgrep -f 'node.*engine' >/dev/null && echo 'RUNNING' || echo 'STOPPED'" 2>/dev/null)
if [ "$PROC_CHECK" = "RUNNING" ]; then
    check "引擎进程存活" "PASS"
else
    check "引擎进程未运行" "FAIL"
fi

# === D10 端口健康 ===
echo ""
echo "【D10 端口健康】"
PORT_CHECK=$($SSH_CMD "sudo ss -tlnp | grep ':3040' >/dev/null && echo 'LISTENING' || echo 'NOT_FOUND'" 2>/dev/null)
if [ "$PORT_CHECK" = "LISTENING" ]; then
    check "端口3040正常监听" "PASS"
else
    check "端口3040未监听" "FAIL"
fi

# === D11 重启计数 ===
echo ""
echo "【D11 重启计数】"
N_RESTARTS=$($SSH_CMD "systemctl show trading-v6 --property=NRestarts --value 2>/dev/null || echo 'N/A'" 2>/dev/null)
if [ "$N_RESTARTS" = "0" ] || [ "$N_RESTARTS" = "N/A" ]; then
    check "NRestarts=$N_RESTARTS" "PASS"
elif [ "$N_RESTARTS" -lt 10 ] 2>/dev/null; then
    check "NRestarts=$N_RESTARTS（偏高）" "WARN"
else
    check "NRestarts=$N_RESTARTS（异常！需排查）" "FAIL"
fi

# === D12 系统资源 ===
echo ""
echo "【D12 系统资源】"
DISK_USAGE=$($SSH_CMD "df / --output=pcent | tail -1 | tr -d ' %'" 2>/dev/null)
MEM_USAGE=$($SSH_CMD "free | awk '/Mem/{printf(\"%.0f\",\$3/\$2*100)}'" 2>/dev/null)
LOAD_AVG=$($SSH_CMD "cat /proc/loadavg | awk '{print \$1}'" 2>/dev/null)
CPU_CORES=$($SSH_CMD "nproc" 2>/dev/null)

if [ -n "$DISK_USAGE" ]; then
    if [ "$DISK_USAGE" -lt 70 ]; then
        check "磁盘使用 ${DISK_USAGE}%" "PASS"
    elif [ "$DISK_USAGE" -lt 85 ]; then
        check "磁盘使用 ${DISK_USAGE}%（偏高）" "WARN"
    else
        check "磁盘使用 ${DISK_USAGE}%（危险！）" "FAIL"
    fi
fi

if [ -n "$MEM_USAGE" ]; then
    if [ "$MEM_USAGE" -lt 70 ]; then
        check "内存使用 ${MEM_USAGE}%" "PASS"
    elif [ "$MEM_USAGE" -lt 85 ]; then
        check "内存使用 ${MEM_USAGE}%（偏高）" "WARN"
    else
        check "内存使用 ${MEM_USAGE}%（危险！）" "FAIL"
    fi
fi

if [ -n "$LOAD_AVG" ] && [ -n "$CPU_CORES" ]; then
    LOAD_THRESHOLD=$(echo "$CPU_CORES * 2" | bc)
    LOAD_CHECK=$(echo "$LOAD_AVG < $LOAD_THRESHOLD" | bc)
    if [ "$LOAD_CHECK" -eq 1 ]; then
        check "CPU负载 ${LOAD_AVG}（${CPU_CORES}核）" "PASS"
    else
        check "CPU负载 ${LOAD_AVG}（${CPU_CORES}核，过高！）" "FAIL"
    fi
fi

# === O1 systemd守护 ===
echo ""
echo "【O1 systemd守护】"
SVC_STATUS=$($SSH_CMD "systemctl is-active trading-v6 2>/dev/null || echo 'inactive'" 2>/dev/null)
SVC_ENABLED=$($SSH_CMD "systemctl is-enabled trading-v6 2>/dev/null || echo 'disabled'" 2>/dev/null)
if [ "$SVC_STATUS" = "active" ]; then
    check "trading-v6 服务状态: active" "PASS"
else
    check "trading-v6 服务状态: $SVC_STATUS" "FAIL"
fi
if [ "$SVC_ENABLED" = "enabled" ]; then
    check "trading-v6 开机自启: enabled" "PASS"
else
    check "trading-v6 开机自启: $SVC_ENABLED" "WARN"
fi

# === O2 SQLite备份 ===
echo ""
echo "【O2 SQLite自动备份】"
BACKUP_CHECK=$($SSH_CMD "crontab -l 2>/dev/null | grep -i 'sqlite\|backup\|trading' | head -3" 2>/dev/null)
if [ -n "$BACKUP_CHECK" ]; then
    check "备份cron任务存在" "PASS"
else
    check "未找到备份cron任务" "WARN"
fi

# === D9 版本号 ===
echo ""
echo "【D9 版本号】"
VERSION=$($SSH_CMD "cat $V6_DIR/VERSION 2>/dev/null || echo 'N/A'" 2>/dev/null)
echo "  📌 当前版本：$VERSION"

# === D7 持仓持久化 ===
echo ""
echo "【D7 数据持久化】"
DB_CHECK=$($SSH_CMD "ls -lh $V6_DIR/data/*.db 2>/dev/null || ls -lh $V6_DIR/*.db 2>/dev/null || echo 'NO_DB'" 2>/dev/null)
if [ "$DB_CHECK" != "NO_DB" ]; then
    check "数据库文件存在" "PASS"
    echo "  $DB_CHECK"
else
    check "未找到数据库文件" "WARN"
fi

# === S6 日志容量 ===
echo ""
echo "【S6 日志容量】"
DB_SIZE=$($SSH_CMD "find $V6_DIR -name '*.db' -exec du -m {} \; 2>/dev/null | awk '{print \$1}' | head -1" 2>/dev/null)
if [ -n "$DB_SIZE" ] && [ "$DB_SIZE" -lt 20 ] 2>/dev/null; then
    check "DB大小 ${DB_SIZE}MB（<20MB）" "PASS"
elif [ -n "$DB_SIZE" ]; then
    check "DB大小 ${DB_SIZE}MB（>20MB，需关注）" "WARN"
fi

# === 汇总 ===
echo ""
echo "========================================"
echo "检查结果汇总"
echo "========================================"
echo -e "  ${GREEN}✅ 通过：${PASS}${NC}"
echo -e "  ${YELLOW}⚠️ 警告：${WARN}${NC}"
echo -e "  ${RED}❌ 失败：${FAIL}${NC}"
TOTAL=$((PASS + FAIL + WARN))
echo "  合计：$TOTAL 项"

if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🟢 全部通过${NC}"
elif [ "$FAIL" -lt 3 ]; then
    echo ""
    echo -e "${YELLOW}🟡 有警告但可运行${NC}"
else
    echo ""
    echo -e "${RED}🔴 有致命问题需立即修复！${NC}"
fi
