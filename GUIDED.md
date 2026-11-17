# Working with a coding agent: the guided version (1 hour)

The guided version of the tutorial: no programming needed, more explanations, and a hint under each step. It
covers the everyday features of a coding agent; the [full version](README.md) goes further into running agents
without a human.

**The idea.** A coding agent is a language model that can read files, run commands and edit files by itself, in a
loop, until the task is done. You will use [OpenCode](https://opencode.ai), an open-source agent; Claude Code, Codex,
Gemini CLI and Cursor work the same way, with the same features under similar names.

**The material.** The folder `cases/dev/` holds small Python programs ("task files") that generate exercises to
train language models (logic puzzles, planning, ...). Some have a planted mistake. You do not need to understand
the code: the agent reads it, and you judge what it does.

| Part | Time | You learn |
|---|---|---|
| 0. Setup | 10 min | open the Codespace, enter the class key |
| 1. First steps | 10 min | the two modes, tool calls, attaching a file |
| 2. Let it act, safely | 10 min | edits, undo, asking permission first |
| 3. Project memory | 10 min | `AGENTS.md`: instructions it reads every time |
| 4. A reusable skill | 15 min | teach it a procedure once, reuse it |
| 5. Context and sessions | 5 min | why long chats degrade, `/compact`, `/new` |
| Optional | | run it from a script, a subagent with rules, measure it |

Stuck? Open the **Hint** under the step, ask your neighbour, or raise your hand. The agent can be slow (10 to 60
seconds per answer): that is normal, it is reading files and thinking.

## 0. Setup (10 min)

1. Open **[tinyurl.com/opencode-tutorial](https://tinyurl.com/opencode-tutorial)** and sign in to GitHub.
2. Before clicking **Create codespace**, fill in the two fields **`CLASS_API_URL`** and **`CLASS_API_KEY`** with the
   values your teacher shows. Leave `NVIDIA_API_KEY` empty.
3. Click **Create codespace** and wait for the terminal at the bottom of the screen (1 to 2 minutes; the editor may
   stay blank meanwhile).
4. In the terminal, type `opencode` and press Enter.

**What you should see:** a full-screen chat, with the model name `deepseek-v4-flash-0731` at the bottom.

<details><summary>Hint</summary>

- **No fields to fill in?** On the GitHub page of the repository, click the green **Code** button, then
  **Codespaces**, **...**, **New with options**. Already created it? Add the two values at
  [github.com/settings/codespaces](https://github.com/settings/codespaces) (**New secret**, repository
  `sileod/opencode-tutorial`), then reload the Codespace page.
- **Another model name** (`deepseek-v4.1-flash-free`)? The class key was not found. It works for a few minutes,
  but fix it.
- **`opencode: command not found`?** The setup is still running: wait a minute, then open a new terminal (the **+**
  in the terminal panel).
- Quit OpenCode: **Ctrl+C** twice. Restart it: `opencode`.

</details>

## 1. First steps (10 min)

OpenCode has two modes, shown at the bottom of the screen; the **Tab** key switches between them.

- **Plan** reads and answers, but does not change anything.
- **Build** may edit files and run commands.

**1a. Ask (in Plan).** Type:

`What does cases/dev/c05.py generate? Explain it simply.`

**What you should see:** before the answer, lines such as `Read cases/dev/c05.py`. These are **tool calls**: actions
the agent decided to take by itself. A chatbot only writes text; an agent acts, looks at the result, and continues.

**1b. Attach a file.** Type `@`, start typing `c05`, pick the file in the list, then add:
`Could a correct answer to this puzzle be marked wrong?`

**What you should see:** perhaps the planted mistake: two answers can tie for the best score; the program then picks
one of them, but the question never says which one, so a solver who gives the other one is marked wrong. Did the
agent find it? Attaching the file saves it from searching, and tells it exactly what you mean.

**1c. Commands.** Type `/` alone: a menu lists the commands. You will use `/undo`, `/compact`, `/new`, `/models`.

<details><summary>Hint</summary>

- No answer after a minute? **Esc** interrupts; ask again.
- The `@` list is empty? Type the beginning of the path: `@cases/dev/c0`.

</details>

## 2. Let it act, safely (10 min)

**2a. Run a command (in Build).** Press **Tab** to switch to **Build**, then:

`Run python tools/validate_file.py cases/dev/c02.py and explain the result simply.`

**What you should see:** a line `$ python tools/validate_file.py ...`, then its output: the check **fails** with
"Examples should not be identical" (the program fixes its randomness, so it repeats the same exercise).

**2b. An edit, then undo.** Type:

`Add a one-line comment at the top of cases/dev/c01.py saying what it generates.`

**What you should see:** the change, shown as a diff (red: removed, green: added). Type `/undo`: the change is
reverted. (`/redo` would put it back.)

**2c. Ask permission first.** By default the agent edits files and runs commands without asking. Open the file
`opencode.json` (in the file list on the left) and replace its content with:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": { "edit": "ask", "bash": "ask" }
}
```

Save (**Ctrl+S**), quit OpenCode (**Ctrl+C** twice), start it again (`opencode`), switch to **Build**, and ask again
for the comment of 2b.

**What you should see:** OpenCode stops and asks before editing: allow once, always, or reject. Reject it.

<details><summary>Hint</summary>

- To check that nothing changed in your files, open a second terminal (**+** in the terminal panel) and type
  `git status`. To put every file back as it was: `git checkout .`
- `opencode.json` will not save? Check the commas and braces: copy the block exactly.

</details>

👉 **Question.** Which is safer: rules written in the instructions ("never edit files"), or permissions in the
configuration? Why?

## 3. Project memory (10 min)

Every new conversation starts from zero: the agent knows nothing about your project or your preferences. A file
named `AGENTS.md` at the root of the project is read at the start of every conversation (Claude Code calls it
`CLAUDE.md`). Teams put there what a newcomer must know: how to run the tests, the conventions, the traps.

Create it from the second terminal:

```bash
echo "Always answer in French, in at most five lines." > AGENTS.md
```

Restart OpenCode, then ask (in Plan): `What does cases/dev/c09.py generate?`

**What you should see:** a short answer, in French, although you asked in English.

<details><summary>Hint</summary>

- Still in English? Check that the file is at the top of the folder (`ls` shows `AGENTS.md`), then restart OpenCode.
- Optional, slow (about 5 minutes): the `/init` command asks the agent to read the whole project and write an
  `AGENTS.md` for it. Compare with yours.

</details>

👉 **Question.** What would you write in an `AGENTS.md` for your own work or studies?

## 4. A reusable skill (15 min)

You will often ask for the same procedure: "explain this file simply, in this format". Instead of typing it every
time, write it once as a **skill**: a Markdown file with a name, a description, and the procedure. The agent sees the
names and descriptions of all skills, and loads the full text only when a request matches. Skills work the same way in
Claude Code, Codex and others, so they can be shared.

**4a. Create it.** In the second terminal:

```bash
mkdir -p .opencode/skills/explain-task
code .opencode/skills/explain-task/SKILL.md
```

Paste this in the file that opens, and save (**Ctrl+S**):

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

**4b. Use it without naming it.** Restart OpenCode, then: `Explain cases/dev/c01.py to my grandmother.`

**What you should see:** a line `Skill "explain-task"` (the agent recognised that the request matches the
description and loaded the skill), then an answer in your three parts, in French because of `AGENTS.md`.

**4c. Improve it.** Change the procedure: add a fourth part ("**Difficulty**: easy, medium or hard for a human"),
or ask for an emoji per part. Save, restart, ask about another file (`c07.py`). The skill improves for every future
request, without retyping anything.

<details><summary>Hint</summary>

- **No `Skill` line?** Check the path (`.opencode/skills/explain-task/SKILL.md`, with `SKILL` in capitals) and the
  header between the two `---` lines, then restart OpenCode. You can also ask: `Use the explain-task skill on
  cases/dev/c01.py`.
- `code: command not found`? Create the file from the file list on the left: right-click `.opencode/skills/explain-task`,
  **New File**, `SKILL.md`.

</details>

👉 **Question.** What is the difference between the skill and `AGENTS.md`? (Hint: when is each one read?)

## 5. Context and sessions (5 min)

Everything in the conversation (your messages, the files read, the outputs of commands) is sent to the model at
every step: this is the **context**. It has a maximum size, it costs time, and the longer it gets, the worse the
model follows it ("context rot").

- `/compact` replaces the conversation so far by a summary, and continues: use it when a long task drifts.
- `/new` starts a fresh conversation: use it when you change topic. `/sessions` lists the old ones to go back.
- `/models` switches the model, for example to Qwen3 Coder (faster, but it sometimes writes an action as text,
  `<function=...>`, instead of doing it: then switch back).

Try: ask two or three more questions, type `/compact`, then ask `What did we do so far?`

**What you should see:** the agent answers from the summary.

👉 **Question.** You ask the agent to fix a bug, it tries three times and fails. Continue in the same conversation,
or start a new one? Why?

## Optional: running agents without a human

For those who finished, or at home. These parts show how agents are used at scale, with nobody watching.

<details><summary><b>A. No human in the loop (10 min)</b></summary>

The same agent runs without the chat screen: one instruction in, the answer out. So it can be looped, over every
file, every night. In the second terminal:

```bash
for f in cases/dev/c01.py cases/dev/c05.py cases/dev/c10.py; do
  echo "=== $f"; opencode run "Review $f against reasoning_core/TASK_AUTHORING_GUIDE.md. Is it correct?"
done
```

(A few minutes; read the first answer while the next one runs.) Then `git status`. If you set permissions to `ask`
in part 2, the runs cannot ask anyone: what happens to the edits?

👉 Could a program read these answers and decide "accept" or "reject"? What would the agent need to always do?

</details>

<details><summary><b>B. A subagent with rules (15 min)</b></summary>

A **subagent** is an agent with a fixed job: a role, rules, an answer in a fixed format, and its own permissions, in
one file. A ready-made one reviews task files:

```bash
mkdir -p .opencode/agents && cp examples/task-reviewer.md .opencode/agents/
```

Open `.opencode/agents/task-reviewer.md`. The header (between `---`) has its permissions: it may never edit, and the
only command it may run is the checker. The body has its rules and the required last line `VERDICT: OK` or
`VERDICT: RULE1, RULE2`. The rules in plain words:

| Rule | The task file is wrong because ... |
|---|---|
| `SUMMARY` | its one-line description is missing or does not describe it |
| `DIFFICULTY` | asking for a harder level does not really make the exercise harder |
| `UNIQUE` | several answers are correct, but the question does not say which one is expected |
| `FORMAT` | the question does not say in what form to answer |
| `SCORER` | the grading accepts wrong answers or rejects right ones |
| `SHORTCUT` | you can often guess the answer without solving anything |
| `RNG` | the randomness is fixed, so the exercises repeat |
| `METADATA` | it stores data in a form that cannot be saved |

Restart OpenCode, type `@`, pick **task-reviewer**, then `Review cases/dev/c02.py`: a short answer ending with
`VERDICT: RNG`. In a loop, one line per file:

```bash
for f in cases/dev/c01.py cases/dev/c05.py cases/dev/c10.py; do
  echo "$f $(opencode run --agent task-reviewer "Review $f" | grep VERDICT)"
done
```

(The right answers: c01 `DIFFICULTY`, c05 `UNIQUE`, c10 `OK`.) Try `@task-reviewer Fix the problem in
cases/dev/c02.py`: what stops it?

</details>

<details><summary><b>C. Measure it (10 min)</b></summary>

How do you know the reviewer is good? Test it on cases where you know the answer, with a check it cannot edit:

```bash
python tools/score.py --only c05,c10
```

It takes 5 to 10 minutes (add `--model class/qwen3-coder-30b-a3b-instruct` for about 1 minute: faster, but
less careful; its failed runs are retried automatically). One line per case (true label, verdict, `ok` or
`WRONG`), then the mistakes caught and the false alarms. The
transcripts are in `runs/`. Change one thing in `.opencode/agents/task-reviewer.md` (reword a rule, add an example),
score again, compare. Run it twice: is the result the same? How many cases before you trust it?

</details>

The [full version](README.md) does these three parts in depth, writing the subagent from its specification.

## Take away

- An agent acts: it reads, runs and edits in a loop. Watch its tool calls, check its diffs, keep `/undo` at hand.
- Permissions are enforced by the tool; instructions are only requested from the model.
- `AGENTS.md` is read every time; a skill is loaded when a request matches; both make it better without retyping.
- Keep the context short and on topic: `/compact` and `/new`.

---
Cases are task files from reasoning_core (MIT license, © sileod), some with one planted defect.
