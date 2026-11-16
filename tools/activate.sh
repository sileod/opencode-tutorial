# Your machine only (not needed in a Codespace): source tools/activate.sh, from the repository folder, in every new
# terminal. Before it, if your teacher gave you a class URL and key, type them once in that terminal:
#   export CLASS_API_URL=...   CLASS_API_KEY=...
export PATH="$HOME/.opencode/bin:$PATH"
. .venv/bin/activate
. tools/model-env.sh
model=$(printf '%s' "${OPENCODE_CONFIG_CONTENT:-}" | sed -n 's/.*"model":"\([^"]*\)".*/\1/p')
echo "OpenCode $(opencode --version), model: ${model:-nvidia/nvidia/nemotron-3.5-lightning-30b-a3b (your NVIDIA key)}"
