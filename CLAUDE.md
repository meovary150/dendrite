# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About Dendrite

Dendrite is a second-generation Matrix homeserver written in Go, designed to be efficient, reliable, and scalable. It implements the Matrix specification and serves as an alternative to Synapse.

## Communication

- 永远使用简体中文进行思考和对话

## Documentation

- 编写 .md 文档时，也要用中文
- 正式文档写到项目的 docs/ 目录下
- 用于讨论和评审的计划、方案等文档，写到项目的 discuss/ 目录下

## Build and Development Commands

### Building Dendrite
```bash
# Build all Dendrite binaries
go build -o bin/ ./cmd/...

# Build specific component
go build -o bin/dendrite ./cmd/dendrite
```

### Running Tests
```bash
# Run all unit tests
go test ./...

# Run tests with race detection
go test --race -v ./...

# Run specific test
go test ./roomserver/...

# Run tests with coverage
go test -coverprofile=coverage.out ./...
```

### Linting
```bash
# Run linting (installs golangci-lint if needed)
./build/scripts/find-lint.sh

# Run linting with fast mode
./build/scripts/find-lint.sh fast
```

### Development Workflow
```bash
# Full build, test, and lint cycle  
./build/scripts/build-test-lint.sh

# Generate signing keys for Matrix federation
./bin/generate-keys --private-key matrix_key.pem

# Create a user account
./bin/create-account --config dendrite.yaml --username alice

# Run Dendrite server
./bin/dendrite --tls-cert server.crt --tls-key server.key --config dendrite.yaml
```

### Testing with Sytest and Complement
```bash
# Run Sytest (Matrix specification compliance tests)
./run-sytest.sh

# Run Complement tests (newer Matrix test suite)
./build/scripts/complement.sh
```

## Architecture Overview

### Core Components

1. **Client API** (`/clientapi`): Handles client-server API endpoints for Matrix clients
2. **Federation API** (`/federationapi`): Manages server-to-server federation with other Matrix homeservers
3. **Room Server** (`/roomserver`): Core room state management and event processing
4. **User API** (`/userapi`): User account management, devices, and authentication
5. **Sync API** (`/syncapi`): Provides real-time updates to Matrix clients
6. **Media API** (`/mediaapi`): Handles media upload/download and thumbnailing
7. **App Service API** (`/appservice`): Integration with Matrix application services
8. **Relay API** (`/relayapi`): Federation relay support for P2P scenarios

### Key Interfaces

- **RoomserverInternalAPI**: Central interface for room operations, event processing, and state management
- **UserAPI**: Manages user accounts, devices, keys, and authentication
- **FederationInternalAPI**: Handles federation with other Matrix servers
- Each component exposes an internal API interface for inter-component communication

### Database Architecture

- Supports both PostgreSQL (recommended for production) and SQLite
- Each component has its own storage package with interface definitions
- Database migrations are handled automatically via numbered migration files
- Shared storage logic in `/storage/shared`, with database-specific implementations in `/storage/postgres` and `/storage/sqlite3`

### Event Processing Flow

1. Events enter via Client API or Federation API
2. Processed by Room Server's InputRoomEvents
3. State resolution and auth checks performed
4. Events distributed to other components via internal APIs
5. Sync API notifies connected clients of updates

### Configuration

- Main configuration in `dendrite.yaml` (copy from `dendrite-sample.yaml`)
- Global settings apply to all components
- Component-specific settings for fine-tuning
- Database connection strings can be global or per-component

### Refresh Token Implementation

Refresh tokens support was recently added with the following key changes:
- Device interface extended with `QueryRefreshToken` and `UpdateRefreshToken` methods
- PostgreSQL and SQLite implementations in respective device tables
- `CreateDeviceWithRefreshToken` method properly stores refresh tokens
- Located in `/userapi/storage/` with database-specific implementations

## Testing Strategy

- Unit tests alongside code files (`*_test.go`)
- Integration tests in component test files
- Sytest for Matrix spec compliance
- Complement for modern Matrix testing
- GitHub Actions CI for automated testing across platforms

## Development Tips

- Use absolute paths when working with file operations
- Follow existing code patterns and conventions in each component
- Check `go.mod` for available dependencies before adding new ones
- Database queries should use prepared statements and transactions appropriately
- All API endpoints should validate input and handle errors gracefully
- Keep components loosely coupled through well-defined interfaces