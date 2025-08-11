package deltas

import (
	"context"
	"database/sql"
	"fmt"
)

func UpRefreshTokens(ctx context.Context, tx *sql.Tx) error {
	_, err := tx.ExecContext(ctx, `
ALTER TABLE userapi_devices ADD COLUMN IF NOT EXISTS refresh_token TEXT;
CREATE INDEX IF NOT EXISTS userapi_devices_refresh_token_idx ON userapi_devices(refresh_token);`)
	if err != nil {
		return fmt.Errorf("failed to execute upgrade: %w", err)
	}
	return nil
}

func DownRefreshTokens(ctx context.Context, tx *sql.Tx) error {
	_, err := tx.ExecContext(ctx, `
	DROP INDEX IF EXISTS userapi_devices_refresh_token_idx;
	ALTER TABLE userapi_devices DROP COLUMN refresh_token;`)
	if err != nil {
		return fmt.Errorf("failed to execute downgrade: %w", err)
	}
	return nil
}
