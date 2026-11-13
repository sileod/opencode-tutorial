"""Run reasoning_core's own checks on one task file: python tools/validate_file.py cases/dev/c01.py

Loads the file as a module, then calls validate() on every Task class it defines. Prints OK or the
first failure. This is the deterministic check; the reviewer agent judges what it cannot see.
"""
import importlib.util
import sys
import traceback
from pathlib import Path

from reasoning_core.template import Task

path = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location(path.stem, path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
tasks = [c for c in vars(module).values() if isinstance(c, type) and issubclass(c, Task) and c is not Task and c.__module__ == module.__name__]
if not tasks:
    sys.exit(f"{path.name}: no Task class found")
failed = False
for cls in tasks:
    try:
        cls().validate(n_samples=3)   # 3 samples keep it fast; reasoning_core defaults to 10
        print(f"{cls.__name__}: validate() OK")
    except Exception as e:
        failed = True
        last = traceback.extract_tb(e.__traceback__)[-1]
        print(f"{cls.__name__}: validate() FAILED: {type(e).__name__}: {e}  (at {Path(last.filename).name}:{last.lineno})")
sys.exit(1 if failed else 0)
