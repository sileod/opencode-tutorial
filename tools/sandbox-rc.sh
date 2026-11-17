# Start-up file of the sandboxed shell opened by tools/sandbox.sh.
. tools/activate.sh
PS1="(sandbox) \w \$ "
echo "Sandboxed shell: this folder only, model APIs only. Type exit to leave."
