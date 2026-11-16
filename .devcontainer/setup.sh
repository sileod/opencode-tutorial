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

# Model, in new shells: the class proxy when your teacher gave you its URL and key (secrets CLASS_API_URL and
# CLASS_API_KEY), else NVIDIA when you have a key (secret or /connect), else a free OpenCode model (no account, rate-limited).
cat >> "$HOME/.bashrc" <<'RC'
if [ -n "${CLASS_API_URL:-}" ] && [ -n "${CLASS_API_KEY:-}" ]; then
  export OPENCODE_CONFIG_CONTENT='{"provider":{"class":{"npm":"@ai-sdk/openai-compatible","name":"Class proxy","options":{"baseURL":"{env:CLASS_API_URL}","apiKey":"{env:CLASS_API_KEY}"},"models":{"qwen3-coder-30b-a3b-instruct":{"name":"Qwen3 Coder 30B"},"deepseek-v4-flash-0731":{"name":"DeepSeek V4 Flash"}}}},"model":"class/qwen3-coder-30b-a3b-instruct"}'
elif [ -z "${NVIDIA_API_KEY:-}" ] && ! grep -qs '"nvidia"' "$HOME/.local/share/opencode/auth.json"; then
  export OPENCODE_CONFIG_CONTENT='{"model":"opencode/deepseek-v4.1-flash-free"}'
fi
RC
