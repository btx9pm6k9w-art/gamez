#!/usr/bin/env python3
"""Catch GDScript local-variable redeclarations that Godot rejects at parse time.

Godot refuses a script when a block declares a local (var, const or a for-loop
variable) whose name is already declared in the same function in an enclosing
or the same block, e.g. `for k in 2:` inside a loop that already uses `k`.
gdtoolkit does not catch this, so cloud sessions without Godot run this too.

Usage: tools/shadow_check.py [paths...]   (default: scripts/)
Exit code 1 when a problem is found.
"""
import pathlib
import re
import sys

DECL = re.compile(r"^\s*(?:var|const)\s+([A-Za-z_]\w*)")
FOR = re.compile(r"^\s*for\s+([A-Za-z_]\w*)\s*(?::\s*[\w\[\]]+\s*)?in\b")
FUNC = re.compile(r"^(\s*)(?:static\s+)?func\s+\w*\s*\(([^)]*)\)")
LAMBDA = re.compile(r"\bfunc\s*\(([^)]*)\)")


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip("\t"))


def params(text: str) -> list[str]:
    out = []
    for p in text.split(","):
        p = p.strip()
        if p:
            out.append(re.split(r"[\s:=]", p)[0])
    return out


def check(path: pathlib.Path) -> list[str]:
    problems = []
    scopes: list[tuple[int, set[str]]] = []  # (indent of the block body, names)
    in_func = False
    func_indent = 0
    for n, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip() if not raw.lstrip().startswith("##") else ""
        if not line.strip():
            continue
        ind = indent_of(raw)
        m = FUNC.match(line)
        if m and ind == 0:
            in_func = True
            func_indent = 0
            scopes = [(1, set(params(m.group(2))))]
            continue
        if not in_func:
            continue
        if ind <= func_indent:
            in_func = False
            scopes = []
            continue
        while scopes and ind < scopes[-1][0]:
            scopes.pop()
        if not scopes or ind > scopes[-1][0]:
            scopes.append((ind, set()))
        visible = set().union(*(s for _, s in scopes))
        lam = LAMBDA.search(line)
        names = []
        d = DECL.match(line)
        if d:
            names.append(d.group(1))
        f = FOR.match(line)
        if f:
            names.append(f.group(1))
        for name in names:
            if name in visible:
                problems.append(f"{path}:{n}: '{name}' is already declared in this function")
            scopes[-1][1].add(name)
        if f or line.rstrip().endswith(":"):
            # The loop variable belongs to the loop body block.
            body = set([f.group(1)]) if f else set()
            scopes[-1][1].discard(f.group(1) if f else "")
            scopes.append((ind + 1, body))
        if lam:
            for p in params(lam.group(1)):
                if p in visible:
                    problems.append(f"{path}:{n}: lambda parameter '{p}' shadows a local")
    return problems


def main() -> int:
    roots = [pathlib.Path(a) for a in sys.argv[1:]] or [pathlib.Path("scripts")]
    files = []
    for r in roots:
        files += [r] if r.is_file() else sorted(r.rglob("*.gd"))
    problems = []
    for f in files:
        problems += check(f)
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
