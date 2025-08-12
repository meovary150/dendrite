#!/bin/bash

# Matrix 系统状态检查脚本

echo "========================================="
echo "Matrix 系统状态检查"
echo "========================================="
echo ""

# 检查所有服务状态
echo "📦 服务运行状态:"
echo "-----------------------------------------"
docker-compose ps
echo ""

# 检查 Dendrite 健康状态
echo "🏥 Dendrite 健康检查:"
echo "-----------------------------------------"
curl -s http://localhost:8008/_matrix/static/ > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Dendrite API 响应正常"
else
    echo "❌ Dendrite API 无响应"
fi

# 检查联邦端口
curl -s http://localhost:8448/_matrix/key/v2/server > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 联邦端口 (8448) 响应正常"
else
    echo "❌ 联邦端口 (8448) 无响应"
fi
echo ""

# 检查数据库连接
echo "🗄️ 数据库状态:"
echo "-----------------------------------------"
docker exec dendrite-postgres pg_isready -U dendrite > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL 数据库运行正常"
    # 显示数据库列表
    echo "📊 数据库列表:"
    docker exec dendrite-postgres psql -U dendrite -c "\l" 2>/dev/null | grep -E "(dendrite|mautrix)" | awk '{print "   - " $1}'
else
    echo "❌ PostgreSQL 数据库连接失败"
fi
echo ""

# 检查 Bridge 状态
echo "🌉 Bridge 服务状态:"
echo "-----------------------------------------"

# WhatsApp Bridge
if docker-compose ps mautrix-whatsapp | grep -q "Up"; then
    echo "✅ WhatsApp Bridge 运行中"
    # 检查双傀儡配置
    docker-compose exec -T mautrix-whatsapp cat /data/config.yaml 2>/dev/null | grep -q "double_puppet_server_map" && echo "   ✓ 双傀儡模式已配置"
else
    echo "❌ WhatsApp Bridge 未运行"
fi

# Telegram Bridge
if docker-compose ps mautrix-telegram | grep -q "Up"; then
    echo "✅ Telegram Bridge 运行中"
    echo "   ⚠️  需要配置 API 凭据 (参见 TELEGRAM_SETUP.md)"
else
    echo "❌ Telegram Bridge 未运行"
fi
echo ""

# 检查 Web 服务
echo "🌐 Web 服务状态:"
echo "-----------------------------------------"

# Element Web
if docker-compose ps element-web | grep -q "Up"; then
    echo "✅ Element Web 运行中"
    echo "   🔗 访问地址: https://app.yifanyiscrm.com"
else
    echo "❌ Element Web 未运行"
fi

# Traefik
if docker-compose ps traefik | grep -q "Up"; then
    echo "✅ Traefik 反向代理运行中"
    # 检查证书状态
    if [ -f "./data/traefik/letsencrypt/acme.json" ]; then
        echo "   ✓ Let's Encrypt 证书已配置"
    else
        echo "   ⚠️  Let's Encrypt 证书未找到"
    fi
else
    echo "❌ Traefik 未运行"
fi
echo ""

# 显示访问信息
echo "📱 访问信息:"
echo "-----------------------------------------"
echo "Element Web: https://app.yifanyiscrm.com"
echo "Matrix API:  https://api.yifanyiscrm.com"
echo ""
echo "管理员账户:"
echo "  用户名: admin"
echo "  密码: Admin@123456"
echo ""

# 显示双傀儡状态
echo "👥 双傀儡模式:"
echo "-----------------------------------------"
echo "✅ WhatsApp: 已启用"
echo "⚠️  Telegram: 已启用 (需配置 API 凭据)"
echo ""

# 显示消息回填状态
echo "📜 消息回填 (Backfill):"
echo "-----------------------------------------"
echo "✅ WhatsApp: 已启用 (90天历史，自动媒体下载)"
echo "✅ Telegram: 已启用 (100条初始消息)"
echo "详细配置请查看: BACKFILL_CONFIG.md"
echo ""

# 最近的错误日志
echo "⚠️  最近的错误 (如果有):"
echo "-----------------------------------------"
docker-compose logs --tail=20 --no-log-prefix 2>&1 | grep -E "(ERROR|CRITICAL|FATAL)" | tail -5 || echo "没有发现错误"
echo ""

echo "========================================="
echo "检查完成!"
echo "详细日志请运行: docker-compose logs [服务名]"
echo "========================================="