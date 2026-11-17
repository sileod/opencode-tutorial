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
| 0. Setup | before | a Codespace (one click), optionally a free model key |
| 1. Interactive | 15 min | ask, plan, let it act, undo |
| 2. Non-interactive, in a loop | 10 min | `opencode run` over several files: what breaks? |
| 3. A subagent with rules | 15 min | one Markdown file: role, permissions, output format |
| 4. Measure and improve | 15 min | score it on labelled cases, change one thing, score again |

## 0. Setup (before the session, 10 min)

1. **Codespace.** Open **[tinyurl.com/opencode-tutorial](https://tinyurl.com/opencode-tutorial)** (or
   [codespaces.new/sileod/opencode-tutorial](https://codespaces.new/sileod/opencode-tutorial)) and click
   **Create codespace**. The editor may stay blank while it connects: wait for the terminal at the bottom. Then type
   `opencode` in the terminal.
2. **Model.** Without a key, OpenCode uses one of its free models (`opencode/deepseek-v4.1-flash-free`), with no
   account: enough to try part 1, but it stops after a few minutes of use ("Free usage limit reached").
   For the loops of parts 2 to 4, a model key is needed, for example a free NVIDIA key: create an account on
   [build.nvidia.com](https://build.nvidia.com), click **Get API Key**, and paste it in the `NVIDIA_API_KEY`
   field when you create the Codespace (or later: type `/connect` in OpenCode, choose NVIDIA, then open a new
   terminal). The model is then `nvidia/nemotron-3.5-lightning-30b-a3b`. Never paste a key in a file or a chat.
   **In a class where the teacher gives you a URL and a key**, paste them in the `CLASS_API_URL` and
   `CLASS_API_KEY` fields instead when you create the Codespace (no NVIDIA account needed). The model is then
   `class/deepseek-v4-flash-0731` (`/models` also offers Qwen3 Coder, faster but it sometimes writes a tool call as text and stops). Already created your Codespace?
   Add both as Codespace secrets ([github.com/settings/codespaces](https://github.com/settings/codespaces)),
   then stop and restart it.

**No Codespace?** (no GitHub account, or it does not start) Do the same on your own machine: macOS, Linux, or
Windows inside WSL (`wsl --install` in PowerShell, then use the Ubuntu terminal). You need `git`, `curl` and
Python 3.10 or newer.

```bash
git clone https://github.com/sileod/opencode-tutorial && cd opencode-tutorial
bash local-setup.sh                                # once: OpenCode, reasoning_core, a .venv (a few minutes)
export CLASS_API_URL=...  CLASS_API_KEY=...        # only if your teacher gave you these, in every new terminal
source tools/activate.sh                           # in every new terminal; it prints the model in use
```

Nothing is installed system-wide (OpenCode goes to `~/.opencode`, Python packages to `.venv`). Run everything from
this folder, and only on this tutorial's files: the agent can edit and run commands.

**Sandbox on your machine (recommended, Linux, WSL2 and macOS).** Unlike a Codespace, your laptop holds your files.
`tools/sandbox.sh` opens a shell where OpenCode and everything it runs can read only this folder (not the rest of your
home folder), write only this folder, and reach only the model APIs, using
[srt](https://github.com/anthropics/sandbox-runtime), Anthropic's open-source sandbox runtime (no VM, no
Docker). It needs Node.js 20 or newer; on Linux and WSL2 also `sudo apt install bubblewrap socat ripgrep`, on macOS
`brew install ripgrep`. Then, instead of `source tools/activate.sh`:

```bash
bash tools/sandbox.sh      # a "(sandbox)" shell opens: use opencode as usual, `exit` to leave
```

Codespaces are free for 60 hours a month with a GitHub account. Delete yours afterwards
([github.com/codespaces](https://github.com/codespaces)).

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
