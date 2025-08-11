# Telegram Bridge 配置说明

## 重要提示

Telegram Bridge 需要您自己的 API 凭据才能正常工作。

## 获取 Telegram API 凭据

1. 访问 https://my.telegram.org/apps
2. 使用您的 Telegram 手机号登录
3. 创建新应用或选择已有应用
4. 记录以下信息：
   - **API ID** (数字)
   - **API Hash** (字符串)

## 配置 API 凭据

编辑配置文件 `/root/dendrite/config/mautrix-telegram.yaml`：

```yaml
telegram:
    api_id: YOUR_API_ID_HERE     # 替换为您的 API ID
    api_hash: YOUR_API_HASH_HERE # 替换为您的 API Hash
```

## 重启服务

配置完成后，重启 Telegram bridge：

```bash
docker-compose restart mautrix-telegram
```

## 使用 Telegram Bridge

### 首次连接

1. 登录 Element Web: https://app.yifanyiscrm.com
2. 使用管理员账户登录：
   - 用户名: `admin`
   - 密码: `Admin@123456`

3. 与 Telegram Bot 开始对话：
   - 点击 "开始新对话"
   - 输入: `@telegrambot:api.yifanyiscrm.com`
   - 发送消息开始对话

### 登录 Telegram

在与 telegrambot 的对话中：

1. 发送命令: `!tg login`
2. Bot 会请求您的手机号
3. 输入您的 Telegram 手机号（包括国家代码，如 +86）
4. 您会收到 Telegram 的验证码
5. 输入验证码完成登录

### 双傀儡模式

双傀儡模式已默认启用，这意味着：
- 您发送的消息会显示为从您自己的账户发送
- 已读回执会正确同步
- 打字指示器会正常工作
- 支持更好的端到端加密

### 验证双傀儡状态

在与 telegrambot 的对话中发送：
```
!tg ping
```

如果双傀儡正常工作，您会看到确认消息。

## 故障排除

### 检查服务状态

```bash
docker-compose ps mautrix-telegram
```

### 查看日志

```bash
docker-compose logs --tail=50 mautrix-telegram
```

### 常见问题

1. **"API ID/Hash 无效"**
   - 确认您已正确配置 API 凭据
   - 确认凭据来自 https://my.telegram.org/apps

2. **无法登录**
   - 检查网络连接
   - 确认手机号格式正确（包括国家代码）
   - 检查 Telegram 是否可以正常访问

3. **双傀儡未激活**
   - 确认共享密钥配置正确
   - 重新登录 Telegram

## 安全注意事项

1. **保护 API 凭据**: 不要分享您的 API ID 和 Hash
2. **定期更新**: 保持 bridge 更新到最新版本
3. **监控日志**: 定期检查异常活动

## 相关文档

- [Mautrix Telegram 官方文档](https://docs.mau.fi/bridges/python/telegram/)
- [双傀儡配置说明](./DOUBLE_PUPPET.md)