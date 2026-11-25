#!/usr/bin/env bash
# Fallback without a Codespace: the same setup on your own machine (macOS, Linux, or Windows inside WSL).
# Needs git, curl and Python 3.10+. Installs nothing system-wide: OpenCode in ~/.opencode, Python packages in .venv.
# Run once from the repository folder:  bash local-setup.sh
# Then, in every new terminal:          source tools/activate.sh
set -euo pipefail
cd "$(dirname "$0")"
OPENCODE_VERSION=1.19.3
PY=${PYTHON:-python3}
"$PY" -c 'import sys; sys.exit(sys.version_info < (3, 10))' || { echo "Python 3.10 or newer is needed (set PYTHON=...)"; exit 1; }
curl -fsSL https://opencode.ai/install | bash -s -- --version "$OPENCODE_VERSION" --no-modify-path
"$HOME/.opencode/bin/opencode" --version

[ -d reasoning_core ] || git clone --depth 1 https://github.com/sileod/reasoning-core reasoning_core
[ -d .venv ] || "$PY" -m venv .venv
echo "$(pwd)/reasoning_core" > "$(.venv/bin/python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')/reasoning_core.pth"
.venv/bin/pip install --quiet -r reasoning_core/requirements/task-authoring.txt sympy tiktoken openai
.venv/bin/python -c "from reasoning_core.template import Task; print('reasoning_core ready')"
echo "Done. In every new terminal, from this folder:  source tools/activate.sh"
