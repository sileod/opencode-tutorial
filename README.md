# Working with a coding agent: a hands-on tutorial

> **New to coding agents, or not a programmer?** Follow the **[guided version](GUIDED.md)** (1 hour): the everyday
> features (modes, undo, permissions, `AGENTS.md`, skills, context) with a hint under each step.

A practical session for people who will **use** agents, not build them. You drive OpenCode (an open-source coding
agent, like Claude Code or Codex) by hand, then run it without a human in a loop over many files, see why that
needs an agent with precise rules, write that agent in one Markdown file, measure it and improve it.

The repository: [reasoning_core](https://github.com/sileod/reasoning-core) generates verifiable reasoning tasks
(logic, parsing, planning, ...) to train language models. Each task is a small Python generator that must follow
`TASK_AUTHORING_GUIDE.md`. Many generators are now written by agents, so reviewing them is the bottleneck: today an
agent reviews them.

| Part | Time | You do |
|---|---|---|
| 0. Setup | before | install on your machine, a free model key (10 min) |
| 1. Interactive | 15 min | ask, plan, let it act, undo |
| 2. Non-interactive, in a loop | 10 min | `opencode run` over several files: what breaks? |
| 3. A subagent with rules | 15 min | one Markdown file: role, permissions, output format |
| 4. Measure and improve | 15 min | score it on labelled cases, change one thing, score again |

**NLP course, TP4 (from an API call to an agent).** Start with the notebook
[`part1-api.ipynb`](part1-api.ipynb) (30 min, on
[Colab](https://colab.research.google.com/github/sileod/opencode-tutorial/blob/main/part1-api.ipynb) with your
`NVIDIA_API_KEY` secret from TP3): one call to a model through an API, a spelling-error detector with a
strict JSON output, and its precision and recall. Then do sections 1 to 4 below: the same pattern, with an agent.

## 0. Setup (at home, before the session, 10 min)

1. **Install.** On macOS or Linux, open a terminal. On Windows, first install WSL (in PowerShell: `wsl --install`,
   then restart; it takes a while) and use the Ubuntu terminal. Then:

   ```bash
   sudo apt install git curl python3-venv     # Ubuntu/WSL only; macOS has them (or: xcode-select --install)
   git clone https://github.com/sileod/opencode-tutorial && cd opencode-tutorial
   bash local-setup.sh                        # once, a few minutes
   source tools/activate.sh                   # in every new terminal, from this folder
   ```

2. **Model key.** A free NVIDIA key (NLP course: the one from TP3; otherwise create it on
   [build.nvidia.com](https://build.nvidia.com), **Get API Key**). Start `opencode`, type `/connect`, choose
   **NVIDIA**, paste the key, quit with Ctrl+C. Never paste a key in a file or a chat.
3. **Check.** In a new terminal: `source tools/activate.sh`, then `opencode run "Say hi"`. It should answer.

Work only in this folder: the agent edits files and runs commands. To confine it to this folder, use
`bash tools/sandbox.sh` instead of `source tools/activate.sh` (recommended; needs Node.js 20+, and on Linux/WSL
`sudo apt install bubblewrap socat ripgrep`, on macOS `brew install ripgrep`).

**If your teacher gives you a URL and a key instead,** type `export CLASS_API_URL=...  CLASS_API_KEY=...` before
`source tools/activate.sh`, in every new terminal. **If the install fails,** use a GitHub Codespace:
[codespaces.new/sileod/opencode-tutorial](https://codespaces.new/sileod/opencode-tutorial), key in the
`NVIDIA_API_KEY` field, then type `opencode` in the terminal at the bottom.

## 1. Interactive (15 min)

OpenCode has two main agents; **Tab** switches between them (shown at the bottom of the screen).

- **Plan** reads and answers, but does not modify files.
- **Build** may edit files and run commands.

Try, in this order:

1. In **Plan**: `What does reasoning_core/reasoning_core/tasks/generated/dynamic_programming.py generate? Explain its apply_difficulty.`
   Watch the tool calls it makes (reading files) before it answers.
2. Type `@` to attach a file: `@cases/dev/c02.py what would make this task too easy?`
3. Switch to **Build**: `Run python tools/validate_file.py cases/dev/c02.py and explain the result.`
4. Ask for a change: `Add a one-line docstring to the class in cases/dev/c01.py.` Look at the diff, then type
   `/undo` to revert it. Then run `git diff` in a terminal: did it change anything else?

👉 What did the agent do that you did not ask for?

## 2. Non-interactive, in a loop (10 min)

The same agent runs without the interface, from a script: one prompt in, the transcript out.

```bash
opencode run "Review cases/dev/c05.py against reasoning_core/TASK_AUTHORING_GUIDE.md. Is it correct?"
```

So it can be **looped**, e.g. over every task file, every night, on every pull request:

```bash
for f in cases/dev/c01.py cases/dev/c05.py cases/dev/c10.py; do
  echo "=== $f"; opencode run "Review $f against reasoning_core/TASK_AUTHORING_GUIDE.md. Is it correct?"
done
```

(It takes a few minutes: read the first answers while the next run.) Then run `git status`.

👉 Could a program use these answers? Look at the length and form of each answer, what the agent decided to read
or run, how long it took, and whether it changed any file. Nobody was there to say no.

To loop an agent, its job must be specified like a function: a fixed role, fixed rules, a fixed output that a
program can parse, and permissions that hold when nobody watches. That is a **subagent**.

## 3. A subagent with rules (15 min)

A subagent is configured in one Markdown file, `.opencode/agents/<name>.md` ([docs](https://opencode.ai/docs/agents/)): a header (its description and
permissions) and instructions as the body. Ask OpenCode (in Build) to write `.opencode/agents/task-reviewer.md`
from this specification, then read and fix what it wrote:

- header: a `description`, `mode: all` (so that `opencode run --agent` can use it), and `permission:` that
  **denies** `edit`, `webfetch`, `glob`, `grep`, `list`, and every `bash` command except
  `python tools/validate_file.py *`, the whole header:

  ```yaml
  ---
  description: Reviews one reasoning_core task file and ends with one VERDICT line
  mode: all
  permission:
    edit: deny
    webfetch: deny
    glob: deny
    grep: deny
    list: deny
    bash:
      "*": deny
      "python tools/validate_file.py *": allow
  ---
  ```

- body: review the one file it is given (run the validator, read the file once, do not search) and end with exactly
  one line `VERDICT: OK` or `VERDICT: RULE1, RULE2`, with these rules:

  | Rule | The task file ... |
  |---|---|
  | `SUMMARY` | has no `summary`, or one that is not a one-line spec of what it generates |
  | `DIFFICULTY` | has an `apply_difficulty` that is not monotonic (a knob resets or shrinks at a higher level), branches on the level, or barely changes anything; a ceiling such as `min(0.9, ...)` on a fraction is fine |
  | `UNIQUE` | accepts several correct answers but the prompt gives no rule to pick one |
  | `FORMAT` | has a prompt that does not say what form the answer takes |
  | `SCORER` | has a `score_answer` that rewards wrong answers or rejects correct ones |
  | `SHORTCUT` | can often be answered right by a constant or trivial guess |
  | `RNG` | seeds the global random generator |
  | `METADATA` | stores metadata that is not JSON-serializable |

**Check the file before using it:** it must start with the header between two `---` lines, as in the example
above. Models often write `mode` and `permission` as plain text in the body instead: there they are not enforced.

Try it interactively: type `@`, pick `task-reviewer` in the menu, then `Review cases/dev/c05.py` (check that the
answer comes from `task-reviewer`, not from Build). Then in the loop:

```bash
for f in cases/dev/c01.py cases/dev/c05.py cases/dev/c10.py; do
  echo "$f $(opencode run --agent task-reviewer "Review $f" | grep VERDICT)"
done
```

👉 Compare with part 2: one line per file, no edits, no wandering. Which rules are enforced by the harness
(permissions) and which only requested from the model (the instructions)?

## 4. Measure and improve (15 min)

An agent is a model plus a configuration: measure it like a model, on labelled cases, with a check it cannot edit.
`tools/score.py` is the loop above plus the labels:

```bash
python tools/score.py --only c03,c05,c09,c10   # three defects first agents usually miss, one clean file: 1 to 10 min
```

It prints, per case, the label, the verdict and the time, then the defects caught and the false alarms. While it
runs, read the transcripts in `runs/`. Then **improve the subagent**: change one thing (a rule's wording, an example
of a defect, the order of the steps), score again, and keep the version that does better. The full dev set
(`python tools/score.py`, 11 cases) takes about 30 minutes.

👉 Did your change help, or did it only move the error? What would you need before trusting this reviewer on real
pull requests?

## Take away

- An agent runs as well from a script as in a chat, so it can be looped over thousands of items.
- Looping needs a specification: a role, rules, a parseable output and permissions, written in one file (a
  subagent here; the same idea exists in Claude Code, Codex and Cursor).
- Instructions steer; permissions enforce; measurement on labelled cases tells you whether it works.

---
Cases are task files from reasoning_core (MIT license, © sileod), some with one planted defect.
