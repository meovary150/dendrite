# Dendrite 性能分析报告

## 当前状态

根据监控数据，Dendrite 的 CPU 使用率实际上**很低**（0.4-0.8%），不存在高 CPU 占用问题。

### 实际资源使用情况

```
容器: dendrite-server
CPU 使用率: 0.4-0.8%
内存使用: 161MB (0.42% of 30GB)
进程状态: 正常运行
数据库连接: 6个 (5个空闲，1个活跃)
```

## 可能导致 CPU 占用的因素

虽然当前 CPU 使用率正常，但以下因素可能在某些情况下导致高 CPU 占用：

### 1. JetStream 消息队列

**当前配置：**
```yaml
jetstream:
  in_memory: false  # 使用磁盘存储
  storage_path: /var/dendrite/jetstream
```

**潜在问题：**
- 大量消息积压可能导致 CPU 峰值
- 磁盘 I/O 可能成为瓶颈

**优化建议：**
```yaml
jetstream:
  in_memory: true  # 如果内存充足，使用内存存储
  max_memory: 1GB  # 限制内存使用
```

### 2. 数据库连接池

**当前配置：**
```yaml
database:
  max_open_conns: 90
  max_idle_conns: 5
  conn_max_lifetime: -1  # 永不过期
```

**潜在问题：**
- 过多的数据库连接可能导致上下文切换
- 连接永不过期可能导致连接泄漏

**优化建议：**
```yaml
database:
  max_open_conns: 20    # 减少最大连接数
  max_idle_conns: 2     # 减少空闲连接
  conn_max_lifetime: 3600  # 1小时后重建连接
```

### 3. 联邦通信

**可能的问题：**
- 与其他 Matrix 服务器的联邦通信
- TLS 握手和加密解密
- DNS 查询

**优化建议：**
```yaml
federation_api:
  disable_http_keepalives: false  # 保持连接复用
  send_max_retries: 8  # 减少重试次数（当前为16）
  
dns_cache:
  cache_size: 512  # 增加 DNS 缓存（当前为256）
  cache_lifetime: "30m"  # 延长缓存时间（当前为10m）
```

### 4. 媒体处理

**当前配置：**
```yaml
media_api:
  max_thumbnail_generators: 10
  dynamic_thumbnails: true
```

**潜在问题：**
- 同时生成多个缩略图可能导致 CPU 峰值
- 大文件上传/下载

**优化建议：**
```yaml
media_api:
  max_thumbnail_generators: 4  # 减少并发缩略图生成
  max_file_size_bytes: 52428800  # 限制为 50MB
```

### 5. 同步 API

**可能的问题：**
- 大量客户端同时同步
- 长轮询连接

**优化建议：**
在 nginx/traefik 前端添加速率限制：
```yaml
# Traefik 配置
middlewares:
  rate-limit:
    rateLimit:
      average: 100
      burst: 200
```

## 监控命令

### 实时监控 CPU 使用

```bash
# 持续监控容器资源
docker stats dendrite-server

# 查看容器内进程
docker exec dendrite-server top

# 查看 goroutine 数量（如果支持）
curl http://localhost:8008/debug/pprof/goroutine?debug=1
```

### 数据库性能监控

```bash
# 查看慢查询
docker exec dendrite-postgres psql -U dendrite -c "
SELECT query, calls, mean_exec_time, max_exec_time 
FROM pg_stat_statements 
WHERE mean_exec_time > 100 
ORDER BY mean_exec_time DESC 
LIMIT 10;"

# 查看表大小
docker exec dendrite-postgres psql -U dendrite -c "
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;"
```

### JetStream 监控

```bash
# 查看 JetStream 目录大小
docker exec dendrite-server du -sh /var/dendrite/jetstream/

# 查看消息队列状态（如果有 nats CLI）
docker exec dendrite-server nats stream ls
```

## 性能优化建议

### 1. 立即可实施的优化

```yaml
# 修改 /root/dendrite/config/dendrite.yaml

global:
  database:
    max_open_conns: 20      # 从 90 降到 20
    max_idle_conns: 2       # 从 5 降到 2
    conn_max_lifetime: 3600 # 从 -1 改为 3600
  
  dns_cache:
    cache_size: 512         # 从 256 增到 512
    cache_lifetime: "30m"   # 从 10m 增到 30m

media_api:
  max_thumbnail_generators: 4  # 从 10 降到 4

federation_api:
  send_max_retries: 8      # 从 16 降到 8
```

### 2. 监控和告警

创建监控脚本 `monitor-performance.sh`:

```bash
#!/bin/bash

# CPU 阈值（百分比）
CPU_THRESHOLD=50

# 内存阈值（百分比）
MEM_THRESHOLD=70

while true; do
  # 获取 CPU 和内存使用率
  STATS=$(docker stats dendrite-server --no-stream --format "{{.CPUPerc}} {{.MemPerc}}")
  CPU=$(echo $STATS | cut -d' ' -f1 | sed 's/%//')
  MEM=$(echo $STATS | cut -d' ' -f2 | sed 's/%//')
  
  # 检查阈值
  if (( $(echo "$CPU > $CPU_THRESHOLD" | bc -l) )); then
    echo "[WARNING] High CPU usage: ${CPU}%"
    docker-compose logs --tail=50 dendrite | grep ERROR
  fi
  
  if (( $(echo "$MEM > $MEM_THRESHOLD" | bc -l) )); then
    echo "[WARNING] High memory usage: ${MEM}%"
  fi
  
  sleep 30
done
```

### 3. 定期维护

```bash
# 每周清理任务（添加到 crontab）
0 2 * * 0 docker exec dendrite-postgres vacuumdb -U dendrite -d dendrite -z
0 3 * * 0 docker exec dendrite-postgres reindexdb -U dendrite -d dendrite
```

## 故障排查步骤

如果遇到高 CPU 占用：

1. **识别问题时段**
   ```bash
   docker stats dendrite-server
   ```

2. **检查日志**
   ```bash
   docker-compose logs --tail=200 dendrite | grep -E "ERROR|panic"
   ```

3. **分析数据库**
   ```bash
   docker exec dendrite-postgres psql -U dendrite -c "SELECT * FROM pg_stat_activity WHERE state != 'idle';"
   ```

4. **检查网络连接**
   ```bash
   docker exec dendrite-server netstat -an | grep ESTABLISHED | wc -l
   ```

5. **重启服务（最后手段）**
   ```bash
   docker-compose restart dendrite
   ```

## 结论

当前 Dendrite 的 CPU 使用率正常（<1%），系统运行稳定。如果您观察到高 CPU 占用，可能是：

1. **瞬时峰值**：处理大量消息或媒体文件
2. **外部因素**：网络问题或联邦服务器问题
3. **配置问题**：需要根据上述建议优化配置

建议定期监控并根据实际使用情况调整配置。