# WhatsApp 历史同步问题分析与修复方案

## 问题描述
WhatsApp 账户已成功登录，但联系人和聊天历史未同步到 Matrix。

## 根本原因分析

### 1. 现象观察
- ✅ 用户已成功登录（user_mxid: @admin:api.yifanyiscrm.com, phone: 85264029863）
- ✅ 配置文件已启用历史同步（request_full_sync: true）
- ❌ 历史同步表为空（0 conversations, 0 messages）
- ❌ 日志中没有 RequestHistorySync 相关调用
- ✅ 日志显示 "Starting history sync loops" 但无实际同步

### 2. 根本原因
**历史同步请求未发送到 WhatsApp 服务器**

mautrix-whatsapp 虽然配置了 `request_full_sync: true`，但实际上没有向 WhatsApp 服务器发送历史同步请求。这可能是因为：

1. **缺少初始同步触发器**：新登录的账户需要显式触发同步请求
2. **WhatsApp 协议变更**：WhatsApp 可能更改了历史同步的协议
3. **Bridge 版本问题**：当前使用的开发版本（0.12.3+dev.c160ecbf）可能存在同步问题

## 修复方案

### 方案一：手动触发同步（推荐）

创建一个补丁来强制发送历史同步请求：

```go
// 在 user.go 或相应的初始化代码中添加
func (user *User) RequestInitialHistorySync() error {
    if user.Client == nil || !user.Client.IsConnected() {
        return errors.New("client not connected")
    }
    
    // 强制发送历史同步请求
    historySyncRequest := &waProto.HistorySyncNotification{
        FileSha256: proto.String(""),
        FileLength: proto.Uint64(0),
        MediaKey: []byte{},
        FileEncSha256: []byte{},
        DirectPath: proto.String(""),
        SyncType: waProto.HistorySyncNotification_FULL.Enum(),
        ChunkOrder: proto.Uint32(0),
    }
    
    _, err := user.Client.SendHistorySyncRequest(historySyncRequest)
    if err != nil {
        user.log.Errorf("Failed to request history sync: %v", err)
        return err
    }
    
    user.log.Info("History sync request sent successfully")
    return nil
}
```

### 方案二：配置文件调整

修改 mautrix-whatsapp.yaml：

```yaml
bridge:
  history_sync:
    request_full_sync: true
    # 添加以下配置
    backfill_on_login: true  # 登录时立即回填
    request_on_login: true   # 登录时请求同步
    
    full_sync_config:
      days_limit: 90
      size_mb_limit: 500
      storage_quota_mb: null
      
    # 确保启用即时同步
    immediate:
      enabled: true  # 添加此行
      worker_count: 3
      max_events: 50
```

### 方案三：使用 Matrix 命令触发

通过 Matrix 命令手动触发同步：

```bash
# 1. 创建与 bot 的私聊房间
# 2. 发送命令
!wa sync-history
!wa request-sync
!wa backfill
```

### 方案四：数据库触发

直接在数据库中插入同步请求：

```sql
-- 插入同步请求标记
INSERT INTO whatsapp_history_sync_notification (
    bridge_id, 
    user_login_id, 
    notification_id,
    timestamp,
    sync_type
) VALUES (
    'whatsapp',
    '85264029863',
    'manual-' || extract(epoch from now())::text,
    NOW(),
    'FULL'
);
```

## 建议的修复步骤

1. **立即操作**：
   - 更新配置文件添加 `backfill_on_login: true`
   - 重启 bridge

2. **如果步骤1无效**：
   - 检查 mautrix-whatsapp 的 GitHub issues
   - 考虑降级到稳定版本（v0.12.0）

3. **长期修复**：
   - 向 mautrix-whatsapp 提交 issue
   - 实现自动同步触发器

## 验证方法

```bash
# 检查同步是否开始
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -c \
    "SELECT COUNT(*) FROM whatsapp_history_sync_conversation;"

# 检查日志
docker exec mautrix-whatsapp tail -f /data/bridge.log | grep -i "sync"
```

## 临时解决方案

如果以上方法都无效，可以考虑：

1. **重新登录**：注销后重新登录 WhatsApp
2. **使用不同版本**：尝试 mautrix-whatsapp 的稳定版本
3. **手动导入**：通过 WhatsApp Web 导出聊天记录，然后手动导入

## 相关资源

- [mautrix-whatsapp GitHub](https://github.com/mautrix/whatsapp)
- [WhatsApp History Sync Documentation](https://docs.mau.fi/bridges/go/whatsapp/authentication.html#backfilling)
- [Known Issues](https://github.com/mautrix/whatsapp/issues?q=is%3Aissue+history+sync)