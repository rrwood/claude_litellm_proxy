# Debug Tools

Troubleshooting and development utilities for the LiteLLM proxy container.

## Files

- **Dockerfile.debug** — Identical to the main Dockerfile but uses the debug entrypoint with verbose step-by-step logging
- **docker-compose.debug.yml** — Compose file for debugging; uses `restart: "no"` so failures are visible instead of looping
- **entrypoint-debug.sh** — Entrypoint script that prints each startup step with pass/fail status
- **rebuild.sh** — Clean rebuild script: stops containers, removes images, prunes cache, rebuilds with `--no-cache`
- **recreate-macvlan.sh** — Recreates the `macvlan-for-direct-access` Docker network (edit variables inside to match your network)

## Usage

To run the debug build:

```bash
docker compose -f debug/docker-compose.debug.yml up
```

Note: the debug compose file expects to be run from the repo root (build context is `.`).
