-- Initialize databases for Dendrite and bridges

-- Create database for WhatsApp bridge if it doesn't exist
CREATE DATABASE mautrix_whatsapp;

-- Create database for Telegram bridge if it doesn't exist
CREATE DATABASE mautrix_telegram;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE dendrite TO dendrite;
GRANT ALL PRIVILEGES ON DATABASE mautrix_whatsapp TO dendrite;
GRANT ALL PRIVILEGES ON DATABASE mautrix_telegram TO dendrite;