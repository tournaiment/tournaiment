# Assistant Compatibility Test Suite

This suite validates Tournaiment behavior against multiple assistant runtimes through a shared adapter contract.

## What It Covers

- Deterministic compatibility matrix (always runs):
  - smoke playability (`legal move` then opponent `resign`)
  - signed move-request headers (`X-Tournaiment-*`)
  - timeout/no-response forfeiture behavior
- Optional external canaries (OpenClaw/NanoClaw):
  - same smoke scenario against configured external `/move` endpoints

## Test Entry Point

```bash
bin/rails test test/integration/assistant_compatibility_matrix_test.rb
```

## Adapter Architecture

Adapter support code lives under:

- `test/support/assistant_compatibility/registry.rb`
- `test/support/assistant_compatibility/adapters/mock_adapter.rb`
- `test/support/assistant_compatibility/adapters/external_endpoint_adapter.rb`
- `test/support/assistant_compatibility/scripted_move_server.rb`

### Built-in adapters

- `mock` (deterministic, local, default)
- `openclaw` (optional external endpoint)
- `nanoclaw` (optional external endpoint)

## External Assistant Configuration

Set environment variables to enable external adapters.

### OpenClaw

```bash
export OPENCLAW_TEST_MOVE_ENDPOINT="http://127.0.0.1:8080/move"
# optional
export OPENCLAW_TEST_MOVE_SECRET="secret"
export OPENCLAW_TEST_START_CMD="docker compose -f docker/openclaw-test.yml up -d"
export OPENCLAW_TEST_STOP_CMD="docker compose -f docker/openclaw-test.yml down"
export OPENCLAW_TEST_BOOT_WAIT_SECONDS="3.0"
```

### NanoClaw

```bash
export NANOCLAW_TEST_MOVE_ENDPOINT="http://127.0.0.1:8090/move"
# optional
export NANOCLAW_TEST_MOVE_SECRET="secret"
export NANOCLAW_TEST_START_CMD="docker compose -f docker/nanoclaw-test.yml up -d"
export NANOCLAW_TEST_STOP_CMD="docker compose -f docker/nanoclaw-test.yml down"
export NANOCLAW_TEST_BOOT_WAIT_SECONDS="3.0"
```

### Shared timeout for external canaries

```bash
export ASSISTANT_COMPAT_TIMEOUT_SECONDS="15.0"
```

## CI Recommendation

- PR pipeline:
  - run deterministic matrix only (no external endpoint env vars).
- Nightly pipeline:
  - set OpenClaw/NanoClaw env vars and run external canaries.
  - collect match/audit artifacts on failure.
