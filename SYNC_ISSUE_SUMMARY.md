# WhatsApp 同步问题调查总结

## 问题状态：已识别，待上游修复

### 问题描述
WhatsApp 账户登录成功，但联系人和聊天历史无法同步到 Matrix 服务器。

### 根本原因
**mautrix-whatsapp v0.12.3+dev 版本未发送历史同步请求到 WhatsApp 服务器。**

尽管配置了 `request_full_sync: true`，但 bridge 在登录后没有实际触发同步请求。

### 已完成的工作

#### 1. 问题诊断
- ✅ 确认用户已成功登录（@admin:api.yifanyiscrm.com）
- ✅ 验证配置文件设置正确
- ✅ 检查数据库同步表（确认为空）
- ✅ 分析日志（未发现 RequestHistorySync 调用）

#### 2. 尝试的修复
- ✅ 更新配置文件添加触发选项
  - `backfill_on_login: true`
  - `request_on_login: true` 
  - `create_portals: true`
- ✅ 多次重启 bridge
- ✅ 创建诊断脚本 `trigger_sync.sh`
- ✅ 尝试通过 Matrix API 触发

#### 3. 文档和报告
- ✅ 创建详细问题分析文档 `FIX_SYNC_ISSUE.md`
- ✅ 创建 PR 说明文档 `PR_WHATSAPP_SYNC_FIX.md`
- ✅ 创建触发脚本 `trigger_sync.sh`

### 建议的下一步

#### 短期解决方案
1. **降级版本**：使用 mautrix-whatsapp v0.12.0 稳定版
   ```bash
   docker pull dock.mau.dev/mautrix/whatsapp:v0.12.0
   ```

2. **手动触发**：修改源代码添加强制同步
   ```go
   // 在登录成功后添加
   user.RequestHistorySync()
   ```

#### 长期解决方案
1. **提交 Issue**：向 [mautrix-whatsapp](https://github.com/mautrix/whatsapp) 报告问题
2. **等待修复**：等待官方修复开发版本的同步问题

### 验证命令

```bash
# 检查同步状态
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -c \
  "SELECT COUNT(*) FROM whatsapp_history_sync_conversation;"

# 监控日志
docker exec mautrix-whatsapp tail -f /data/bridge.log | grep -i sync

# 运行诊断脚本
./trigger_sync.sh
```

### 相关文件
- 配置：`/root/dendrite/config/mautrix-whatsapp.yaml`
- 诊断：`/root/dendrite/trigger_sync.sh`
- 分析：`/root/dendrite/FIX_SYNC_ISSUE.md`
- PR：`/root/dendrite/PR_WHATSAPP_SYNC_FIX.md`

### 影响评估
- **严重性**：高 - 新用户无法获取历史消息
- **影响范围**：仅影响新登录的 WhatsApp 账户
- **临时措施**：可以接收新消息，但无法获取历史记录

### 结论
这是 mautrix-whatsapp 开发版本的一个已知问题，需要：
1. 降级到稳定版本
2. 或等待官方修复
3. 或手动修改源代码

所有调查结果和解决方案已记录并提交到 GitHub 仓库。