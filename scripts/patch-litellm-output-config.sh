#!/usr/bin/env bash
# patch-litellm-output-config.sh
# Patches LiteLLM to strip `output_config` before forwarding requests to
# non-Anthropic providers (Nvidia NIM, Bedrock, etc.).
#
# Run once after container first boot, or bake into your Dockerfile.
# Safe to re-run — checks whether each patch is already applied first.
#
# Confirmed working on LiteLLM 1.83.14

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }

# ── Locate LiteLLM install ─────────────────────────────────────────────────────
info "Locating LiteLLM installation..."

LITELLM_PATH=$(python3 -c "import litellm, os; print(os.path.dirname(litellm.__file__))" 2>/dev/null) \
  || error "Could not locate litellm package. Is it installed?"

info "Found LiteLLM at: $LITELLM_PATH"

ADAPTERS_DIR="$LITELLM_PATH/llms/anthropic/experimental_pass_through/adapters"
MESSAGES_DIR="$LITELLM_PATH/llms/anthropic/experimental_pass_through/messages"

ADAPTER_TRANSFORM="$ADAPTERS_DIR/transformation.py"
ADAPTER_HANDLER="$ADAPTERS_DIR/handler.py"
MESSAGES_TRANSFORM="$MESSAGES_DIR/transformation.py"

for f in "$ADAPTER_TRANSFORM" "$ADAPTER_HANDLER" "$MESSAGES_TRANSFORM"; do
  [[ -f "$f" ]] || error "Expected file not found: $f"
done

PATCH_FLAG="$LITELLM_PATH/.output_config_patched"

# ── Already patched? ───────────────────────────────────────────────────────────
if [[ -f "$PATCH_FLAG" ]]; then
  ok "Patches already applied (found $PATCH_FLAG). Skipping."
  exit 0
fi

ERRORS=0

# ── Patch 1: adapters/transformation.py ───────────────────────────────────────
info "Patch 1: removing 'output_config' from adapters supported params list..."

if grep -q '"output_config"' "$ADAPTER_TRANSFORM"; then
  sed -i '/"output_config",/d' "$ADAPTER_TRANSFORM"
  if grep -q '"output_config"' "$ADAPTER_TRANSFORM"; then
    warn "Patch 1: 'output_config' still present after sed — check manually"
    ERRORS=$((ERRORS + 1))
  else
    ok "Patch 1 applied."
  fi
else
  ok "Patch 1: already absent, skipping."
fi

# ── Patch 2: adapters/handler.py — extra_kwargs injection ─────────────────────
info "Patch 2: removing extra_kwargs output_config injection from adapters handler..."

if grep -q 'if "output_config" in extra_kwargs:' "$ADAPTER_HANDLER"; then
  sed -i \
    '/if "output_config" in extra_kwargs:/,/request_data\["output_config"\] = extra_kwargs\["output_config"\]/d' \
    "$ADAPTER_HANDLER"
  if grep -q 'request_data\["output_config"\]' "$ADAPTER_HANDLER"; then
    warn "Patch 2: injection still present after sed — check manually"
    ERRORS=$((ERRORS + 1))
  else
    ok "Patch 2 applied."
  fi
else
  ok "Patch 2: already absent, skipping."
fi

# ── Patch 3a: messages/transformation.py — supported params list ───────────────
info "Patch 3a: removing 'output_config' from messages supported params list..."

if grep -q '"output_config"' "$MESSAGES_TRANSFORM"; then
  sed -i '/"output_config",/d' "$MESSAGES_TRANSFORM"
  ok "Patch 3a applied."
else
  ok "Patch 3a: already absent, skipping."
fi

# ── Patch 3b: messages/transformation.py — optional_params injection ───────────
info "Patch 3b: removing optional_params output_config injection from messages transformer..."

if grep -q 'existing_output_config = optional_params.get("output_config")' "$MESSAGES_TRANSFORM"; then
  sed -i \
    '/existing_output_config = optional_params.get("output_config")/,/optional_params\["output_config"\] = existing_output_config/d' \
    "$MESSAGES_TRANSFORM"
  if grep -q 'optional_params\["output_config"\]' "$MESSAGES_TRANSFORM"; then
    warn "Patch 3b: injection still present after sed — check manually"
    ERRORS=$((ERRORS + 1))
  else
    ok "Patch 3b applied."
  fi
else
  ok "Patch 3b: already absent, skipping."
fi

# ── Patch 4: adapters/handler.py — explicit pop before acompletion ─────────────
info "Patch 4: inserting completion_kwargs.pop('output_config') before acompletion call..."

if grep -q 'completion_kwargs.pop("output_config"' "$ADAPTER_HANDLER"; then
  ok "Patch 4: already applied, skipping."
elif grep -q 'completion_response = await litellm.acompletion(\*\*completion_kwargs)' "$ADAPTER_HANDLER"; then
  sed -i \
    's/        completion_response = await litellm.acompletion(\*\*completion_kwargs)/        completion_kwargs.pop("output_config", None)\n        completion_response = await litellm.acompletion(**completion_kwargs)/' \
    "$ADAPTER_HANDLER"
  if grep -q 'completion_kwargs.pop("output_config"' "$ADAPTER_HANDLER"; then
    ok "Patch 4 applied."
  else
    warn "Patch 4: pop line not found after sed — check manually"
    ERRORS=$((ERRORS + 1))
  fi
else
  warn "Patch 4: acompletion call line not found — LiteLLM version may differ, check manually"
  ERRORS=$((ERRORS + 1))
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
if [[ $ERRORS -eq 0 ]]; then
  touch "$PATCH_FLAG"
  ok "All patches applied successfully."
  info "Restart LiteLLM to pick up the changes."
else
  error "$ERRORS patch(es) failed — review warnings above and patch manually."
fi
