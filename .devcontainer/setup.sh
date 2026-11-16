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

# Model choice in every new shell: see tools/model-env.sh.
echo ". \"$(pwd)/tools/model-env.sh\"" >> "$HOME/.bashrc"
