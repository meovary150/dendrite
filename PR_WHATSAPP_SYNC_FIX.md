# Pull Request: WhatsApp Bridge 历史同步修复

## 问题描述

WhatsApp bridge 登录成功后，联系人和聊天历史无法同步到 Matrix 服务器。尽管配置了 `request_full_sync: true`，但历史同步请求未被发送到 WhatsApp 服务器。

## 调查发现

### 症状
- 用户成功登录（验证通过数据库 user_login 表）
- 历史同步配置正确（request_full_sync: true）
- 历史同步表完全为空（0 conversations, 0 messages）
- 日志显示 "Starting history sync loops" 但无实际同步活动
- 没有 RequestHistorySync 相关的方法调用日志

### 根本原因
mautrix-whatsapp v0.12.3+dev 版本在初始登录后未自动触发历史同步请求。这可能是由于：
1. WhatsApp 协议更新导致同步机制变化
2. Bridge 开发版本的 bug
3. 缺少必要的同步触发条件

## 已尝试的修复

### 1. 配置文件优化
```yaml
history_sync:
  request_full_sync: true
  backfill_on_login: true  # 新增
  request_on_login: true   # 新增
  create_portals: true     # 新增
```

### 2. 手动触发尝试
- 重启 bridge 多次
- 更新数据库 metadata 尝试触发
- 尝试通过 Matrix API 发送命令

### 3. 诊断脚本
创建了 `trigger_sync.sh` 脚本用于诊断和尝试触发同步。

## 建议的解决方案

### 短期方案
1. **降级到稳定版本**：使用 mautrix-whatsapp v0.12.0 稳定版
2. **手动同步补丁**：添加代码强制发送历史同步请求

### 长期方案
1. **向上游报告**：向 mautrix-whatsapp 项目提交 issue
2. **实现自动触发器**：在登录成功后自动发送同步请求

## 代码修改建议

在 mautrix-whatsapp 中添加同步触发器：

```go
// historysync.go
func (user *User) TriggerInitialSync() {
    if user.Client == nil || !user.Client.IsLoggedIn() {
        return
    }
    
    // 强制请求历史同步
    user.Client.DangerousInternals().RequestAppStateKeys(context.Background(), []appstate.WAPatchName{
        appstate.WAPatchRegular,
        appstate.WAPatchRegularHigh,
        appstate.WAPatchRegularLow,
        appstate.WAPatchCriticalBlock,
        appstate.WAPatchCriticalUnblockLow,
    })
    
    user.log.Info("Manually triggered history sync request")
}
```

## 相关文件
- `/root/dendrite/config/mautrix-whatsapp.yaml` - 更新的配置文件
- `/root/dendrite/FIX_SYNC_ISSUE.md` - 详细的问题分析文档
- `/root/dendrite/trigger_sync.sh` - 同步触发诊断脚本

## 测试步骤
1. 应用配置更改
2. 重启 mautrix-whatsapp
3. 检查数据库表 `whatsapp_history_sync_conversation`
4. 验证 Matrix 房间中是否出现 WhatsApp 联系人

## 影响范围
- 仅影响新登录的 WhatsApp 账户
- 不影响已有的同步数据
- 不影响 Telegram bridge

## 待办事项
- [ ] 测试稳定版本 v0.12.0
- [ ] 向 mautrix-whatsapp 提交 issue
- [ ] 实现临时修复补丁
- [ ] 更新部署文档

## 参考链接
- [mautrix-whatsapp Issue Tracker](https://github.com/mautrix/whatsapp/issues)
- [WhatsApp Web Protocol Documentation](https://github.com/tulir/whatsmeow)
- [Matrix Bridge Documentation](https://docs.mau.fi/bridges/)