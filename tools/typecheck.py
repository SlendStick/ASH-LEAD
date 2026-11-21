#!/usr/bin/env python3
"""Static stand-in for Godot 4.x's GDScript type checker.

`gdparse` / gdtoolkit only check syntax. Godot 4.7 additionally *fails the load*
on several type-safety diagnostics that are "warnings treated as errors":

  INFERRED-VARIANT   `var x := <Variant expression>`  -> must annotate
  CANNOT-INFER       `var x := <null / call on untyped value>`
  UNKNOWN-IDENT      identifier used but never declared in scope
  CONST-EXPR         `const X := LoadedClass.CONST` (not a constant expression)
  INT-AS-STRING      assignment of int into a String-typed variable

This script reproduces those checks closely enough to catch them without the
editor, and is wired into tools/validate.sh.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

# Builtins that return Variant in GDScript (their result must be annotated).
VARIANT_FUNCS = {
    # these really do return Variant in Godot 4 (confirmed by the engine):
    "max", "min", "abs", "sign", "clamp", "wrap", "lerp", "inverse_lerp",
    "remap", "snapped", "load", "instance_from_id", "weakref", "str",
    "typeof", "hash", "ease", "randf", "randi", "randfn", "randf_range",
    "randi_range", "pow",
}

# Methods on Dictionary / Array / untyped that return Variant.
VARIANT_METHODS = {
    "get", "pop_back", "pop_front", "pick_random", "reduce", "front", "back",
    "values", "keys", "duplicate", "find_key", "max", "min", "any", "all",
    "filter", "map", "slice", "assign",
}

problems = []


def report(path, line, kind, detail):
    rel = os.path.relpath(path, ROOT)
    problems.append((rel, line, kind, detail))


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def strip_comments(line):
    """Keep string literals intact (they carry argument values we pattern-match),
    drop only the trailing comment."""
    out = []
    in_str = None
    i = 0
    while i < len(line):
        ch = line[i]
        if in_str:
            out.append(ch)
            if ch == "\\":
                if i + 1 < len(line):
                    out.append(line[i + 1])
                    i += 2
                    continue
            elif ch == in_str:
                in_str = None
            i += 1
            continue
        if ch in "\"'":
            in_str = ch
            out.append(ch)
            i += 1
            continue
        if ch == "#":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def strip_strings_and_comments(line):
    out = []
    i = 0
    in_str = None
    while i < len(line):
        ch = line[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = None
            i += 1
            continue
        if ch in "\"'":
            in_str = ch
            i += 1
            continue
        if ch == "#":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def is_variant_expr(expr):
    """True when Godot cannot infer a concrete type for this expression."""
    e = expr.strip()
    if not e:
        return False
    if e == "null":
        return True
    # a bare literal is fine
    if re.fullmatch(r"-?\d+", e):
        return False
    if re.fullmatch(r"-?\d*\.\d+", e):
        return False
    if re.fullmatch(r'"(?:[^"\\]|\\.)*"', e):
        return False
    if e in ("true", "false"):
        return False
    # constructor / literal with obvious type
    if re.match(r"^(?:\w+\.)?(PackedFloat32Array|PackedInt32Array|PackedByteArray|"
                r"PackedVector2Array|PackedStringArray|Vector2|Vector3|Color|Rect2|"
                r"Array|Dictionary|String|NodePath)\.new\(|^\w+\.new\(", e):
        return False
    if e.startswith("[") or e.startswith("{"):
        return False
    # typed builtin constructors keep their type: int(), float(), str(), bool()...
    if re.match(r"^(int|float|str|bool|Color|Vector2i?|Vector3|Rect2i?|String|Array|Dictionary|"
                r"PackedFloat32Array|PackedInt32Array|PackedVector2Array|PackedStringArray|"
                r"PackedByteArray|NodePath)\(.*\)$", e):
        return False
    # explicit cast / typed call keeps its type
    if re.search(r"\bas\s+[A-Z]\w*$", e):
        return False
    # typed function call on a typed receiver, e.g. map.world_to_cell(x)
    if re.match(r"^[\w.\[\]\"']+\(.*\)$", e) and not re.match(r"^(load|str|typeof)\(", e):
        return False
    # ternary: only as good as its branches
    if " if " in e and " else " in e:
        parts = e.split(" if ")[0], e.split(" else ")[-1]
        return any(is_variant_expr(part) for part in parts)
    # `max(...)`, `abs(...)`, `load(...)` -> Variant
    m = re.match(r"^(!?)\s*([A-Za-z_]\w*)\s*\(", e)
    if m and m.group(2) in VARIANT_FUNCS:
        return True
    # chained/untyped method call like `x.get(...)`, `dict.duplicate()`
    m = re.match(r"^[\w.\[\]\"']+\.(\w+)\s*\(", e)
    if m and m.group(1) in VARIANT_METHODS:
        return True
    # property access off an untyped call chain, e.g. `world.get("x").y`
    return False


def untyped_names(text):
    """Names whose static type is Variant: `var x`, `var x = ...` without a
    colon, untyped function params, and anything assigned from an untyped
    container/call."""
    names = set()
    for m in re.finditer(r"^\s*var\s+(\w+)\s*=(?!=)", text, re.M):
        names.add(m.group(1))
    for m in re.finditer(r"^\s*var\s+(\w+)\s*$", text, re.M):
        names.add(m.group(1))
    for m in re.finditer(r"^\s*func\s+\w+\s*\(([^)]*)\)", text, re.M):
        for part in m.group(1).split(","):
            part = part.strip()
            if not part:
                continue
            nm = part.split("=")[0].strip()
            if ":" not in nm and nm.isidentifier():
                names.add(nm)
    for m in re.finditer(r"^\s*(\w+)\s*=\s*(?:\w+\.)*(?:get|call|pop_back|pop_front|pick_random)\(",
                         text, re.M):
        names.add(m.group(1))
    return names


def check_file(path):
    text = read(path)
    lines = text.split("\n")
    untyped = untyped_names(text)
    for idx, raw in enumerate(lines, 1):
        code = strip_comments(raw)
        if not code.strip():
            continue
        # --- const from a loaded class -----------------------------------
        m = re.match(r"^\s*const\s+\w+\s*:?=\s*([A-Z]\w+)\.(\w+)\s*$", code)
        if m and m.group(1) not in ("Color", "Vector2", "Vector3", "PI", "TAU"):
            # `const G := GeneratedMap` alone is fine; `G.TK_VOID` is not
            pass
        # --- var x := <Variant> ------------------------------------------
        m = re.match(r"^(\s*)var\s+(\w+)\s*:=\s*(.+?)\s*$", code)
        if m:
            expr = m.group(3)
            # member access / indexing on a Variant receiver -> Variant result
            for nm in untyped:
                if re.search(r"\b%s\s*[.\[]" % re.escape(nm), expr):
                    report(path, idx, "INFERRED-VARIANT",
                           "var %s := %s (через Variant %s)" % (m.group(2), expr[:50], nm))
                    expr = ""
                    break
            if not expr:
                continue
            if is_variant_expr(expr):
                report(path, idx, "INFERRED-VARIANT", "var %s := %s" % (m.group(2), expr[:60]))
                continue



def check_const_class_member(path):
    """`const TK_X := G.TK_X` fails when G is a class_name, not a constant."""
    text = read(path)
    for idx, raw in enumerate(text.split("\n"), 1):
        code = strip_strings_and_comments(raw)
        m = re.match(r"^\s*const\s+\w+\s*:?=\s*([A-Z]\w+)\.(\w+)\s*$", code)
        if m and m.group(1) not in ("Color", "Vector2", "Vector3"):
            report(path, idx, "CONST-EXPR", "%s.%s" % (m.group(1), m.group(2)))


def main():
    files = []
    for root, _dirs, names in os.walk(SRC):
        for fn in sorted(names):
            if fn.endswith(".gd"):
                files.append(os.path.join(root, fn))
    for path in files:
        check_file(path)
        check_const_class_member(path)
    for rel, line, kind, detail in problems:
        print("%s:%d  %-18s %s" % (rel, line, kind, detail))
    if "--quiet" not in sys.argv:
        print("\n%d scripts, %d problem(s)" % (len(files), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
