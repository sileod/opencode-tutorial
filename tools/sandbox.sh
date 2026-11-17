#!/usr/bin/env bash
# Your machine only, optional but recommended: a sandboxed shell for this tutorial, with srt (Anthropic's open-source
# sandbox runtime; no VM, no Docker). Inside it, OpenCode and every command it runs can read only this folder and the
# tools it needs (not the rest of your home folder), write only this folder, and reach only the model APIs.
# Needs Node.js 20 or newer (srt asks for 22.12; 20 worked in our test). Linux and WSL2: sudo apt install bubblewrap socat ripgrep. macOS: brew install ripgrep.
# Usage, from the repository folder, after local-setup.sh (and after `export CLASS_API_URL=... CLASS_API_KEY=...`
# if your teacher gave you these):   bash tools/sandbox.sh        then use opencode as usual; `exit` to leave.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$(pwd)
mkdir -p .sandbox/data .sandbox/cache .sandbox/config .sandbox/state .sandbox/tmp
PYBASE=$(.venv/bin/python -c 'import sys; print(sys.base_prefix)')
HOSTS="opencode.ai *.opencode.ai models.dev registry.npmjs.org integrate.api.nvidia.com albert.api.etalab.gouv.fr"
[ -n "${CLASS_API_URL:-}" ] && HOSTS="$HOSTS $(python3 -c 'import sys, urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname)' "$CLASS_API_URL")"
python3 - "$REPO" "$PYBASE" $HOSTS > .sandbox/srt-settings.json <<'PY'
import json, sys
repo, pybase, *hosts = sys.argv[1:]
print(json.dumps({
    "network": {"allowedDomains": hosts, "deniedDomains": []},
    "filesystem": {
        "denyRead": ["~"],                                    # your home folder: documents, keys, other projects
        "allowRead": [repo, "~/.opencode", pybase],           # except this folder, OpenCode and Python
        "allowWrite": [repo],
        "denyWrite": [repo + "/.git/hooks"],                  # hooks would run outside the sandbox at your next commit
    },
    "allowPty": True,                                         # macOS: OpenCode's full-screen interface needs a terminal
}, indent=1))
PY
# srt itself lives in .sandbox/ too: the sandbox hides your home folder, where npx would cache it.
[ -x .sandbox/srt/node_modules/.bin/srt ] || npm install --silent --no-fund --no-audit --prefix .sandbox/srt @anthropic-ai/sandbox-runtime@0.0.83
# OpenCode writes this file into ~/.opencode on its first run; that folder holds the OpenCode program, so it stays
# read-only in the sandbox (an agent must not be able to replace a program that runs outside it later).
[ -f "$HOME/.opencode/.gitignore" ] || printf 'node_modules\npackage.json\npackage-lock.json\nbun.lock\n.gitignore\n' > "$HOME/.opencode/.gitignore"
# OpenCode keeps its data, cache and settings inside .sandbox/, not in your home folder.
exec .sandbox/srt/node_modules/.bin/srt --settings .sandbox/srt-settings.json \
  env XDG_DATA_HOME="$REPO/.sandbox/data" XDG_CACHE_HOME="$REPO/.sandbox/cache" \
      XDG_CONFIG_HOME="$REPO/.sandbox/config" XDG_STATE_HOME="$REPO/.sandbox/state" TMPDIR="$REPO/.sandbox/tmp" \
  bash --rcfile tools/sandbox-rc.sh -i
