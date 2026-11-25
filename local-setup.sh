#!/usr/bin/env bash
# Python side of the tutorial, on your own machine (macOS, Linux, or Windows inside WSL). Run once from this folder:
#   bash local-setup.sh
# It installs uv if you do not have it (https://docs.astral.sh/uv: Python and packages, fast), then a .venv here with
# reasoning_core, the scoring tools' packages and Jupyter. Nothing is installed system-wide apart from uv.
set -euo pipefail
cd "$(dirname "$0")"
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
UV=$(command -v uv || echo "$HOME/.local/bin/uv")
[ -d reasoning_core ] || git clone --depth 1 https://github.com/sileod/reasoning-core reasoning_core
[ -d .venv ] || "$UV" venv --quiet --python 3.12 .venv
"$UV" pip install --quiet --python .venv/bin/python -r reasoning_core/requirements/task-authoring.txt sympy tiktoken openai jupyterlab
echo "$(pwd)/reasoning_core" > "$(.venv/bin/python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')/reasoning_core.pth"
.venv/bin/python -c "from reasoning_core.template import Task; print('reasoning_core ready')"
echo "Done. In every new terminal, from this folder:  source .venv/bin/activate"
