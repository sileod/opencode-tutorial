#!/usr/bin/env bash
# Codespace setup: OpenCode 1 (pinned) on PATH, and reasoning_core, whose task files the agent reviews.
set -euo pipefail
OPENCODE_VERSION=1.19.3
curl -fsSL https://opencode.ai/install | bash -s -- --version "$OPENCODE_VERSION" --no-modify-path
sudo ln -sf "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
opencode --version

[ -d reasoning_core ] || git clone --depth 1 https://github.com/sileod/reasoning-core reasoning_core
pip install --quiet -e reasoning_core --no-deps
pip install --quiet -r reasoning_core/requirements/task-authoring.txt sympy tiktoken
python -c "from reasoning_core.template import Task; print('reasoning_core ready')"

# Without an NVIDIA key (secret or /connect), new shells use a free OpenCode model instead (no account, rate-limited).
cat >> "$HOME/.bashrc" <<'RC'
if [ -z "${NVIDIA_API_KEY:-}" ] && ! grep -qs '"nvidia"' "$HOME/.local/share/opencode/auth.json"; then
  export OPENCODE_CONFIG_CONTENT='{"model":"opencode/deepseek-v4.1-flash-free"}'
fi
RC
