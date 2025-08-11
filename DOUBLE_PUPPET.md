# 双傀儡模式配置说明

## 什么是双傀儡模式？

双傀儡（Double Puppeting）模式允许桥接用户使用自己的 Matrix 账户发送消息，而不是通过桥接机器人。这提供了更自然的聊天体验：

- 消息显示为从您自己的账户发送
- 已读回执正确同步
- 打字指示器工作正常
- 更好的端到端加密支持

## 已配置的双傀儡支持

### ✅ WhatsApp Bridge
- **状态**: 已启用
- **自动激活**: 是
- **共享密钥**: 已配置

### ✅ Telegram Bridge  
- **状态**: 已启用
- **自动激活**: 是
- **共享密钥**: 已配置

## 配置详情

### 1. 共享密钥配置

所有桥接服务和 Dendrite 使用相同的 `registration_shared_secret`：

```yaml
# Dendrite (config/dendrite.yaml)
registration_shared_secret: "f6cc9bcee3d474517feb23d636d1e0bf4b89315b53547d26bae2550b3c9364a3"

# WhatsApp Bridge (config/mautrix-whatsapp.yaml)
login_shared_secret_map:
  api.yifanyiscrm.com: "f6cc9bcee3d474517feb23d636d1e0bf4b89315b53547d26bae2550b3c9364a3"

# Telegram Bridge (config/mautrix-telegram.yaml)  
login_shared_secret_map:
  api.yifanyiscrm.com: "f6cc9bcee3d474517feb23d636d1e0bf4b89315b53547d26bae2550b3c9364a3"
```

### 2. 双傀儡服务器映射

每个桥接都配置了服务器映射：

```yaml
double_puppet_server_map:
  api.yifanyiscrm.com: https://api.yifanyiscrm.com
double_puppet_allow_discovery: true
```

### 3. 额外配置

WhatsApp Bridge 额外配置：
```yaml
double_puppet_backfill: true      # 自动为新用户创建双傀儡
double_puppet_allow_puppet: true  # 允许双傀儡发送消息
```

## 使用方法

### WhatsApp 双傀儡

1. 登录 Element Web
2. 与 `@whatsappbot:api.yifanyiscrm.com` 开始对话
3. 发送 `login` 命令获取二维码
4. 使用 WhatsApp 手机应用扫描二维码
5. 双傀儡会自动激活

### Telegram 双傀儡

1. 登录 Element Web
2. 与 `@telegrambot:api.yifanyiscrm.com` 开始对话
3. 发送 `!tg login` 命令
4. 按照提示完成 Telegram 登录
5. 双傀儡会自动激活

## 验证双傀儡状态

### 检查 WhatsApp 双傀儡
```bash
# 在与 whatsappbot 的聊天中
!wa ping
```

### 检查 Telegram 双傀儡
```bash
# 在与 telegrambot 的聊天中
!tg ping
```

## 优势

1. **更自然的体验**: 消息显示为从您的账户发送
2. **完整的功能**: 支持已读回执、打字指示器等
3. **更好的加密**: 支持端到端加密
4. **历史同步**: 可以同步历史消息
5. **无缝集成**: 自动激活，无需手动配置

## 故障排除

### 双傀儡未激活

1. 确认共享密钥配置正确
2. 检查桥接日志：
   ```bash
   sudo docker-compose logs mautrix-whatsapp
   sudo docker-compose logs mautrix-telegram
   ```

3. 重新登录桥接服务

### 消息发送失败

1. 检查网络连接
2. 确认双傀儡权限配置
3. 查看 Dendrite 日志：
   ```bash
   sudo docker-compose logs dendrite
   ```

## 安全注意事项

1. **共享密钥安全**: 确保 `registration_shared_secret` 保密
2. **访问控制**: 只允许信任的用户使用双傀儡
3. **定期更新**: 保持桥接服务更新到最新版本
4. **监控日志**: 定期检查异常活动

## 相关配置文件

- `/root/dendrite/config/dendrite.yaml` - Dendrite 主配置
- `/root/dendrite/config/mautrix-whatsapp.yaml` - WhatsApp 桥接配置
- `/root/dendrite/config/mautrix-telegram.yaml` - Telegram 桥接配置
- `/root/dendrite/config/appservices/` - Appservice 注册文件

## 更多信息

- [Mautrix WhatsApp 文档](https://docs.mau.fi/bridges/go/whatsapp/)
- [Mautrix Telegram 文档](https://docs.mau.fi/bridges/python/telegram/)
- [双傀儡概念说明](https://docs.mau.fi/bridges/general/double-puppeting.html)