#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CMD="${1:-send}"

case "$CMD" in
  send|send_chat|sync_gist|sync_tennis_gist|sync_telegram_posts|version|help) ;;
  *)
    echo "Unknown command for start.sh: $CMD" >&2
    echo "Allowed: send, send_chat, sync_gist, sync_tennis_gist, sync_telegram_posts, version, help" >&2
    exit 2
    ;;
esac

bundle exec ruby ./exe/sport_notify_bot "$CMD"
