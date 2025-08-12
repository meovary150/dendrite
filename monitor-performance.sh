#!/bin/bash

# Dendrite 性能监控脚本
# 用于持续监控 Dendrite 的 CPU 和内存使用情况

# 配置阈值
CPU_THRESHOLD=50    # CPU 使用率阈值（百分比）
MEM_THRESHOLD=70    # 内存使用率阈值（百分比）
CHECK_INTERVAL=30   # 检查间隔（秒）

# 颜色代码
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "========================================="
echo "Dendrite 性能监控"
echo "========================================="
echo "CPU 阈值: ${CPU_THRESHOLD}%"
echo "内存阈值: ${MEM_THRESHOLD}%"
echo "检查间隔: ${CHECK_INTERVAL}秒"
echo "========================================="
echo ""

# 监控循环
while true; do
    # 获取当前时间
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 获取 Dendrite 容器状态
    if ! docker ps | grep -q dendrite-server; then
        echo -e "${RED}[ERROR] ${TIMESTAMP} - Dendrite 容器未运行！${NC}"
        sleep $CHECK_INTERVAL
        continue
    fi
    
    # 获取 CPU 和内存使用率
    STATS=$(docker stats dendrite-server --no-stream --format "{{.CPUPerc}} {{.MemPerc}}")
    CPU=$(echo $STATS | cut -d' ' -f1 | sed 's/%//')
    MEM=$(echo $STATS | cut -d' ' -f2 | sed 's/%//')
    
    # 获取容器内存使用详情
    MEM_USAGE=$(docker stats dendrite-server --no-stream --format "{{.MemUsage}}")
    
    # 默认状态为正常
    STATUS="${GREEN}[OK]${NC}"
    
    # 检查 CPU 阈值
    if (( $(echo "$CPU > $CPU_THRESHOLD" | bc -l) )); then
        STATUS="${RED}[WARNING]${NC}"
        echo -e "${RED}[WARNING] ${TIMESTAMP} - 高 CPU 使用率: ${CPU}%${NC}"
        echo "内存使用: $MEM_USAGE"
        
        # 显示最近的错误日志
        echo "最近的错误日志："
        docker-compose logs --tail=20 dendrite 2>/dev/null | grep -E "ERROR|CRITICAL" | tail -5
        
        # 显示数据库活动
        echo "数据库活动连接："
        docker exec dendrite-postgres psql -U dendrite -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null
    fi
    
    # 检查内存阈值
    if (( $(echo "$MEM > $MEM_THRESHOLD" | bc -l) )); then
        STATUS="${YELLOW}[WARNING]${NC}"
        echo -e "${YELLOW}[WARNING] ${TIMESTAMP} - 高内存使用率: ${MEM}%${NC}"
        echo "内存使用: $MEM_USAGE"
        
        # 显示内存详情
        docker exec dendrite-server sh -c "cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable'" 2>/dev/null
    fi
    
    # 正常状态输出
    if [ "$STATUS" == "${GREEN}[OK]${NC}" ]; then
        echo -e "$STATUS $TIMESTAMP - CPU: ${CPU}% | 内存: $MEM_USAGE"
    fi
    
    # 每 10 次检查输出一次统计信息
    if [ $(($(date +%s) % 300)) -lt $CHECK_INTERVAL ]; then
        echo "----------------------------------------"
        echo "5分钟统计："
        echo "数据库连接数："
        docker exec dendrite-postgres psql -U dendrite -c "SELECT state, count(*) FROM pg_stat_activity WHERE datname = 'dendrite' GROUP BY state;" 2>/dev/null
        echo "----------------------------------------"
    fi
    
    # 等待下一次检查
    sleep $CHECK_INTERVAL
done