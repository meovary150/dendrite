# 消息回填配置说明

## 概述

消息回填（Backfill）功能允许桥接服务在用户登录后自动同步历史消息到 Matrix。这确保您不会丢失在使用 Matrix 之前的聊天记录。

## 当前配置状态

### ✅ WhatsApp Bridge 回填配置

**已启用的功能：**
- 完整历史同步：最近 90 天的消息
- 自动媒体下载：图片、视频、文件自动同步
- 分批处理：避免服务器过载
- 双傀儡回填：使用您自己的账户显示历史消息

**配置详情：**
```yaml
history_sync:
  request_full_sync: true         # 请求完整同步
  full_sync_config:
    days_limit: 90                # 同步 90 天历史
    size_mb_limit: 500            # 每次最大 500MB
  media_requests:
    auto_request_media: true      # 自动下载媒体
    request_method: immediate     # 立即请求
  max_initial_conversations: -1   # 同步所有对话
  immediate:
    worker_count: 3               # 3 个工作线程
    max_events: 50                # 每批 50 条消息
  deferred:                       # 分批处理
    - 最近 7 天：50 条/批
    - 最近 30 天：100 条/批  
    - 最近 90 天：200 条/批
```

### ✅ Telegram Bridge 回填配置

**已启用的功能：**
- 初始历史回填：100 条消息
- 双傀儡回填：支持
- 直接聊天同步：启用
- 所有对话同步：无限制

**配置详情：**
```yaml
sync_direct_chats: true          # 同步直接聊天
sync_create_limit: 0             # 同步所有对话
backfill:
  initial_limit: 100             # 初始 100 条消息
  double_puppet_backfill: true   # 双傀儡回填
  immediate:
    max_events: 100              # 最多 100 条
    worker_count: 3              # 3 个工作线程
  forward_backfill: true         # 转发消息回填
```

## 使用说明

### WhatsApp 历史同步

1. **首次登录时自动同步**
   - 使用二维码登录后，自动开始同步
   - 最近的消息优先同步
   - 媒体文件自动下载

2. **同步进度**
   - 查看日志：`docker-compose logs -f mautrix-whatsapp`
   - 关键词：`history sync`, `backfill`, `portal created`

3. **同步时间估算**
   - 100 个对话：约 5-10 分钟
   - 1000 条消息：约 2-5 分钟
   - 取决于网络速度和媒体大小

### Telegram 历史同步

1. **登录后自动回填**
   - 使用 `!tg login` 登录
   - 自动同步最近 100 条消息
   - 所有聊天室自动创建

2. **手动请求更多历史**
   - 在聊天室中：`!tg backfill <数量>`
   - 例如：`!tg backfill 500`

## 性能优化建议

### 资源使用

- **内存使用**：回填期间可能增加 200-500MB
- **CPU 使用**：3 个工作线程，约 20-30% CPU
- **存储空间**：每 1000 条消息约 10-50MB（含媒体）

### 优化设置

如需调整回填性能，可修改：

1. **减少工作线程**（降低 CPU 使用）：
   ```yaml
   worker_count: 1  # 从 3 改为 1
   ```

2. **限制同步天数**（减少数据量）：
   ```yaml
   days_limit: 30   # 从 90 改为 30
   ```

3. **限制媒体大小**（节省存储）：
   ```yaml
   size_mb_limit: 100  # 从 500 改为 100
   ```

## 常见问题

### Q: 为什么有些旧消息没有同步？

**可能原因：**
- 超过配置的天数限制（当前 90 天）
- 消息已被删除
- 媒体文件过期

### Q: 同步卡住了怎么办？

**解决方法：**
1. 检查日志：`docker-compose logs --tail=50 mautrix-whatsapp`
2. 重启服务：`docker-compose restart mautrix-whatsapp`
3. 检查数据库连接

### Q: 可以重新同步历史吗？

**WhatsApp：**
- 登出再登录会触发重新同步
- 使用命令：`!wa relogin`

**Telegram：**
- 使用命令：`!tg backfill <数量>`
- 或重新登录：`!tg logout` 然后 `!tg login`

### Q: 媒体文件没有同步？

**检查配置：**
```yaml
auto_request_media: true  # 确保为 true
request_method: immediate # 确保为 immediate
```

## 监控命令

### 查看同步状态

```bash
# WhatsApp 同步日志
docker-compose logs -f mautrix-whatsapp | grep -E "history|backfill|sync"

# Telegram 同步日志  
docker-compose logs -f mautrix-telegram | grep -E "backfill|sync|portal"

# 检查数据库中的消息数
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -c "SELECT COUNT(*) FROM message;"
```

### 性能监控

```bash
# 查看资源使用
docker stats mautrix-whatsapp mautrix-telegram

# 查看数据库大小
docker exec dendrite-postgres psql -U dendrite -c "\l+"
```

## 安全注意事项

1. **隐私保护**：历史消息存储在本地数据库
2. **加密消息**：端到端加密的消息需要密钥
3. **存储管理**：定期清理旧媒体文件
4. **访问控制**：只有授权用户可以查看历史

## 故障排除

### 重置同步状态

如果需要完全重新同步：

```bash
# 停止服务
docker-compose stop mautrix-whatsapp

# 清除同步状态（保留消息）
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -c "DELETE FROM user_portal WHERE user_mxid='@admin:api.yifanyiscrm.com';"

# 重启服务
docker-compose start mautrix-whatsapp
```

## 相关文档

- [双傀儡配置](./DOUBLE_PUPPET.md)
- [部署说明](./DEPLOYMENT.md)
- [Telegram 设置](./TELEGRAM_SETUP.md)