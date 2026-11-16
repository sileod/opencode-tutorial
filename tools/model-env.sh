# Sourced by every new shell (Codespace: from ~/.bashrc; your machine: from tools/activate.sh). Picks the model:
# the class proxy when your teacher gave you its URL and key (CLASS_API_URL and CLASS_API_KEY), else NVIDIA when you
# have a key (NVIDIA_API_KEY or /connect), else a free OpenCode model (no account, rate-limited).
if [ -n "${CLASS_API_URL:-}" ] && [ -n "${CLASS_API_KEY:-}" ]; then
  export OPENCODE_CONFIG_CONTENT='{"provider":{"class":{"npm":"@ai-sdk/openai-compatible","name":"Class proxy","options":{"baseURL":"{env:CLASS_API_URL}","apiKey":"{env:CLASS_API_KEY}"},"models":{"qwen3-coder-30b-a3b-instruct":{"name":"Qwen3 Coder 30B"},"deepseek-v4-flash-0731":{"name":"DeepSeek V4 Flash"}}}},"model":"class/qwen3-coder-30b-a3b-instruct"}'
elif [ -z "${NVIDIA_API_KEY:-}" ] && ! grep -qs '"nvidia"' "$HOME/.local/share/opencode/auth.json"; then
  export OPENCODE_CONFIG_CONTENT='{"model":"opencode/deepseek-v4.1-flash-free"}'
else
  unset OPENCODE_CONFIG_CONTENT
fi
