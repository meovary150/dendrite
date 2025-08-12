#!/bin/bash

# Script to manually trigger WhatsApp history sync

echo "=== Manually Triggering WhatsApp History Sync ==="
echo ""

# Step 1: Log the current state
echo "Current sync state:"
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -t -c \
    "SELECT COUNT(*) as conversations FROM whatsapp_history_sync_conversation;"
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -t -c \
    "SELECT COUNT(*) as messages FROM whatsapp_history_sync_message;"

# Step 2: Send signal to request history sync via database
echo ""
echo "Attempting to trigger sync via database update..."

# Update user metadata to force resync
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -c \
    "UPDATE user_login SET metadata = jsonb_set(metadata, '{history_sync_requested}', 'true') 
     WHERE user_mxid = '@admin:api.yifanyiscrm.com';"

# Step 3: Restart the bridge to force reconnection
echo ""
echo "Restarting WhatsApp bridge to trigger sync..."
docker restart mautrix-whatsapp

# Wait for restart
sleep 10

# Step 4: Check logs for sync activity
echo ""
echo "Checking for sync activity in logs..."
docker exec mautrix-whatsapp tail -100 /data/bridge.log | grep -E "sync|history|backfill" | tail -20

# Step 5: Check if data was synced
echo ""
echo "Checking if data was synced..."
sleep 5
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -t -c \
    "SELECT COUNT(*) as conversations FROM whatsapp_history_sync_conversation;"
docker exec dendrite-postgres psql -U dendrite -d mautrix_whatsapp -t -c \
    "SELECT COUNT(*) as messages FROM whatsapp_history_sync_message;"

echo ""
echo "=== Sync trigger attempt completed ==="