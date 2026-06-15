#!/usr/bin/env bash
#
# promotion-log-append.sh — Optional audit log helper for web releases
# No-op if consumer doesn't have deployment/PROMOTION_LOG.yaml.
#
set -euo pipefail

PLATFORM="web"; HOST=""; STAGE=""; ACTOR=""; RUN_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host)     shift; HOST="${1:-}"     ;;
    --stage)    shift; STAGE="${1:-}"    ;;
    --actor)    shift; ACTOR="${1:-}"    ;;
    --run-id)   shift; RUN_ID="${1:-}"   ;;
  esac
  shift || true
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG="$REPO_ROOT/deployment/PROMOTION_LOG.yaml"
[[ -f "$LOG" ]] || exit 0

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
TARGET="${PLATFORM}-${HOST}-${STAGE}"
CI_URL="local"
[[ -n "${GITHUB_REPOSITORY:-}" && "$RUN_ID" != "local" ]] && \
  CI_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${RUN_ID}"

cat >> "$LOG" <<EOF

  - timestamp:    "$TS"
    actor:        "${ACTOR:-ci-system}"
    target:       "$TARGET"
    tier:         1
    commit_sha:   "$SHA"
    ci_run_url:   "$CI_URL"
    outcome:      "success"
EOF
