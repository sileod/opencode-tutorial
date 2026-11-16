"""Score your reviewer agent on labelled cases: python tools/score.py [cases/dev] [--model MODEL]

The model defaults to the class proxy when CLASS_API_URL and CLASS_API_KEY are set, else to the free NVIDIA endpoint when an NVIDIA key is set (NVIDIA_API_KEY or /connect), else to a free OpenCode model.

For each case, runs `opencode run --agent task-reviewer "Review the file task.py in the current directory."` in a fresh temporary directory outside
the repository that holds only the agent, the tools and the case renamed task.py, and denies access outside
that directory: the agent cannot see the labels.
Reads the last `VERDICT:` line and compares it with labels.json. A defect case is caught when one of its labels
is in the verdict; a clean case (OK) is a false alarm when the verdict names any rule. Transcripts go to runs/<case>.txt so you can see
why a case failed.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

NVIDIA_MODEL = "nvidia/nvidia/nemotron-3.5-lightning-30b-a3b"
FREE_MODEL = "opencode/deepseek-v4.1-flash-free"
CLASS_MODEL = "class/qwen3-coder-30b-a3b-instruct"
RULES = {"OK", "SUMMARY", "DIFFICULTY", "UNIQUE", "FORMAT", "SCORER", "SHORTCUT", "RNG", "METADATA"}


def verdict(text):
    lines = re.findall(r"^\W*VERDICT:\s*(.+)$", text, re.M)
    if not lines:
        return None
    found = {r for r in re.findall(r"[A-Z]+", lines[-1]) if r in RULES}
    if not found:
        return None  # e.g. "VERDICT: looks fine": not parseable, counted apart
    return found - {"OK"} or {"OK"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cases", nargs="?", default="cases/dev")
    auth = Path.home() / ".local/share/opencode/auth.json"
    has_key = os.environ.get("NVIDIA_API_KEY") or (auth.exists() and '"nvidia"' in auth.read_text())
    class_proxy = os.environ.get("CLASS_API_URL") and os.environ.get("CLASS_API_KEY")  # provider set in ~/.bashrc
    default_model = CLASS_MODEL if class_proxy else NVIDIA_MODEL if has_key else FREE_MODEL
    ap.add_argument("--model", default=default_model)
    ap.add_argument("--agent", default="task-reviewer")
    ap.add_argument("--timeout", type=int, default=900, help="seconds per case")
    ap.add_argument("--jobs", type=int, default=4, help="cases reviewed in parallel")
    ap.add_argument("--only", help="comma-separated case names to review, e.g. c03,c05")
    args = ap.parse_args()
    cases = Path(args.cases)
    labels = json.loads((cases / "labels.json").read_text())
    if args.only:
        keep = {n if n.endswith(".py") else n + ".py" for n in args.only.split(",")}
        labels = {n: g for n, g in labels.items() if n in keep}
    here = Path.cwd()
    (here / "runs").mkdir(exist_ok=True)
    def review(name):
        box = Path(tempfile.mkdtemp(prefix="review-"))
        for item in (".opencode", "tools", "opencode.json"):
            src = here / item
            if src.is_dir():
                shutil.copytree(src, box / item, ignore=shutil.ignore_patterns("node_modules", "package*.json", "bun.lock"))
            elif src.exists():
                shutil.copy(src, box / item)
        # No link to reasoning_core (installed with pip) or to the repository: through a link the agent could
        # walk up to cases/ and read the labels. The agent may not leave the box.
        config = json.loads((box / "opencode.json").read_text()) if (box / "opencode.json").exists() else {}
        config.setdefault("permission", {})["external_directory"] = "deny"
        config["snapshot"] = False  # undo history is not needed here, and snapshotting the box slows every step
        (box / "opencode.json").write_text(json.dumps(config, indent=1))
        shutil.copy(cases / name, box / "task.py")
        cmd = ["opencode", "run", "--agent", args.agent, "-m", args.model, "Review the file task.py in the current directory."]
        # OpenCode takes its project directory from $PWD, which cwd= does not change. Its own data directory per run,
        # outside the box: parallel runs sharing one session database fail with "database is locked".
        data = Path(tempfile.mkdtemp(prefix="review-data-"))
        env = {**os.environ, "PWD": str(box), "XDG_DATA_HOME": str(data)}
        time.sleep(5 * (order[name] % args.jobs))  # parallel OpenCode processes can collide when they start together
        start = time.time()
        for attempt in range(2):
            try:
                proc = subprocess.run(cmd, cwd=box, env=env, capture_output=True, text=True, timeout=args.timeout)
                out = proc.stdout
                if proc.returncode != 0:
                    out += f"\n[score.py: opencode exited with {proc.returncode}]\n{proc.stderr[-2000:]}"
                    if time.time() - start < 60 and attempt == 0:
                        time.sleep(10)
                        continue  # a crash at startup: try once more
            except subprocess.TimeoutExpired as e:
                out = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
                out += f"\n[score.py: timed out after {args.timeout} s]\n"
            break
        (here / "runs" / name.replace(".py", ".txt")).write_text(out)
        shutil.rmtree(box, ignore_errors=True)
        shutil.rmtree(data, ignore_errors=True)
        return verdict(out), time.time() - start

    order = {name: i for i, name in enumerate(labels)}
    caught = missed = alarms = clean = unparsed = 0
    with ThreadPoolExecutor(args.jobs) as pool:
        results = dict(zip(labels, pool.map(review, labels)))
    for name, gold in labels.items():
        got, seconds = results[name]
        unparsed += got is None
        if got is None:
            ok = False
            missed += gold != ["OK"]
        elif gold == ["OK"]:
            ok = got == {"OK"}
            alarms += not ok
        else:
            ok = bool(set(gold) & got)
            caught += ok
            missed += not ok
        print(f"{name}  label {','.join(gold):<16} verdict {','.join(sorted(got)) if got else 'none':<20} {'ok' if ok else 'WRONG':<6} {seconds:4.0f} s")
    clean = sum(gold == ["OK"] for gold in labels.values())
    print(f"\ndefects caught: {caught}/{caught + missed}   false alarms on clean cases: {alarms}/{clean}"
          + (f"   no parseable VERDICT line: {unparsed} (see runs/)" if unparsed else ""))


if __name__ == "__main__":
    main()
