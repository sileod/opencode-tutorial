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
| 1. Drive it | 15 min | ask, plan, let it act, check the diff, undo |
| 2. Memory and skills | 15 min | `AGENTS.md`, a reusable skill |
| 3. Context and cost | 10 min | its reasoning, `/compact`, what a run costs |
| 4. A subagent in a loop | 15 min | one Markdown file: role, permissions, output format; run it over files |
| 5. Measure and improve | 15 min | score it on labelled cases, change one thing, score again |

**NLP course, TP4 (from an API call to an agent).** Start with the notebook
[`part1-api.ipynb`](part1-api.ipynb) (30 min; `jupyter lab part1-api.ipynb` after the setup below): one call to a model through an API, a spelling-error detector with a
strict JSON output, and its precision and recall. Then do sections 1 to 5 below: the same pattern, with an agent.

## 0. Setup (at home, before the session, 10 min)

The same tools you will use for your own projects. On Windows, first install WSL (in PowerShell: `wsl --install`,
then restart) and type everything below in the Ubuntu terminal.

```bash
curl -fsSL https://opencode.ai/install | bash -s -- --version 1.19.6   # OpenCode; then open a new terminal
git clone https://github.com/sileod/opencode-tutorial && cd opencode-tutorial
bash local-setup.sh                              # uv, Python and the packages, in .venv (about a minute)
source .venv/bin/activate                        # in every new terminal, from this folder
opencode
```

In OpenCode, type `/connect`, choose **NVIDIA** and paste your free key (NLP course: the one from TP3; otherwise
[build.nvidia.com](https://build.nvidia.com), **Get API Key**). Then ask it anything: it should answer. Quit with
Ctrl+C. Never paste a key in a file or a chat.

The agent edits files and runs commands as you: run it in this folder only. For your own projects, consider a
sandbox (`tools/sandbox.sh` is an example).

## 1. Drive it (15 min)

Start `opencode` in this folder. **Tab** switches between its two main agents (shown at the bottom):

- **Plan** reads and answers. It should not modify files, but it can still run commands: watch them.
- **Build** may edit files and run commands, without asking.

1. In **Plan**: `What does reasoning_core/reasoning_core/tasks/generated/dynamic_programming.py generate? Explain its apply_difficulty.`
   Watch the tool calls (files read, commands run) before the answer.
2. Type `@` to attach a file: `@cases/dev/c02.py what would make this task too easy?`
3. In **Build**: `Run python tools/validate_file.py cases/dev/c02.py and explain the result.`
4. Still in Build: `Add a one-line docstring to the class in cases/dev/c01.py.` Look at the diff, type `/undo`, then
   run `git status` in another terminal.

👉 What did the agent do that you did not ask for? (Agents often "fix" things on their way: always check
`git status` and `git diff`, and `git checkout .` puts everything back.)

## 2. Memory and skills (15 min)

Every conversation starts from zero. Two files change that.

**`AGENTS.md`**, at the root of a project, is read at the start of every conversation (Claude Code calls it
`CLAUDE.md`): how to run the tests, the conventions, the traps. Try it:

```bash
echo "Always answer in French, in at most five lines." > AGENTS.md
```

Restart OpenCode and ask (in Plan): `What does cases/dev/c09.py generate?` The answer comes in French.

**A skill** is a procedure written once and loaded only when a request matches its description (skills work the
same way in Claude Code and Codex). Create `.opencode/skills/explain-task/SKILL.md` with any editor:

```markdown
---
name: explain-task
description: Explain a task file from cases/dev to someone who does not program
---

Read the file once, then answer in three short parts, with no code:
1. **What it generates**: one sentence.
2. **A tiny example**: a made-up question and its answer.
3. **What could go wrong**: one sentence.
```

Restart OpenCode, then: `Explain cases/dev/c01.py to my grandmother.` You should see a line `Skill "explain-task"`,
then the three parts. Add a fourth part to the skill and ask about `c07.py`.

👉 When is `AGENTS.md` read, and when is a skill read? What would you put in each for your project?

## 3. Context and cost (10 min)

Everything in the conversation (your messages, files read, command outputs) is sent to the model again at every
step: this is the **context**. It has a maximum size, it costs tokens, and the longer it gets, the worse the model
follows it.

1. **Its reasoning.** `opencode run --thinking "Is cases/dev/c10.py correct? Answer in one line."` shows the thinking
   blocks before the answer. Run it again with `--variant fast` (defined in `opencode.json`: thinking turned off):
   how long does it take, and is the answer as good?
2. **Compaction.** In the interface, after a few questions, type `/compact` (the conversation is replaced by a
   summary), then ask `What did we do so far?`. `/new` starts a fresh conversation.
3. **Cost.** `opencode stats --project ""` shows the tokens used in this folder (NVIDIA's free endpoint costs you
   nothing). Even `Say hi` sends over 10,000 input tokens: OpenCode's instructions and tool descriptions.

👉 How many tokens did one review of a task file take? At $2 per million input tokens and $10 per million output
tokens (a frontier model), what would reviewing 1,000 files cost? When should you `/compact`, and when `/new`?

## 4. A subagent in a loop (15 min)

The same agent runs without the interface, from a script, so it can be looped over files:

```bash
opencode run "Review cases/dev/c05.py against reasoning_core/TASK_AUTHORING_GUIDE.md. Is it correct?"
```

👉 Could a program use this answer? Look at its length and form, what the agent read or ran, and `git status`.

To loop an agent, specify it like a function: a role, rules, a fixed output and permissions that hold when nobody
watches. That is a **subagent**, one Markdown file in `.opencode/agents/` ([docs](https://opencode.ai/docs/agents/)).
Ask OpenCode (in Build) to write `.opencode/agents/task-reviewer.md` from this specification, then read and fix it:

- the header, exactly this (permissions are enforced by OpenCode):

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

- the body: review the one file it is given (run the validator, read the file once, do not search), and end with
  exactly one plain line, `VERDICT: OK` or `VERDICT: RULE1, RULE2`, with these rules:

  | Rule | The task file ... |
  |---|---|
  | `SUMMARY` | has no `summary`, or one that is not a one-line spec of what it generates |
  | `UNIQUE` | accepts several correct answers but the prompt gives no rule to pick one |
  | `FORMAT` | has a prompt that does not say what form the answer takes |
  | `RNG` | seeds the global random generator |

Check the file: the header must be between two `---` lines at the very top (models often write it as plain text,
where it is not enforced). Then:

```bash
for f in cases/dev/c02.py cases/dev/c05.py cases/dev/c10.py; do      # the three run in parallel: 1 to 3 min
  (echo "$f $(opencode run --agent task-reviewer "Review $f" | grep VERDICT)") &
done; wait
```

👉 Which of its rules are enforced by OpenCode, and which are only requested from the model?

## 5. Measure and improve (15 min)

An agent is a model plus a configuration: measure it like a model, on labelled cases, with a check it cannot edit.
`tools/score.py` runs your subagent on each case in a fresh folder without the labels, in parallel:

```bash
python tools/score.py --only c02,c03,c05,c09,c10     # four defects and one clean file: 2 to 4 min
```

Each case prints as soon as it is done (label, verdict, time), then the defects caught and the false alarms; the
transcripts are in `runs/`: read the first ones while the others run. Read the misses, change **one** thing in the
subagent (a rule's wording, an example of a defect, the order of the steps), and score again.

👉 Did your change help, or did it only move the error? For scale: one subagent, scored twice without any
change, caught 3 and then 2 of the 4 defects, and raised a false alarm only the second time. What would you need before trusting this reviewer on real
pull requests?

## Take away

- Watch what the agent does, not only what it says: tool calls, `git diff`, `/undo`.
- `AGENTS.md` is read every time; a skill when a request matches. Keep the context short: `/compact`, `/new`.
- Reasoning and context cost tokens; at scale, tokens are the bill.
- To loop an agent, specify it in one file: role, rules, parseable output, permissions. Instructions steer;
  permissions enforce; measurement on labelled cases tells you whether it works.

---
Cases are task files from reasoning_core (MIT license, © sileod), some with one planted defect.
