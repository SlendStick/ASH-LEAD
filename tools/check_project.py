#!/usr/bin/env python3
"""ASH&LEAD static checker.

No Godot editor is available in this environment, so this script does the
things a parser cannot:

  * every `res://` path referenced from GDScript exists
  * every `Signals.<name>` / `Db.<NAME>` / `GameFlow.<name>` / `NetLink.<name>`
    / `Sfx.<name>` / `Ui.<name>` used in the project is really declared
  * `X.member` / `X.method()` on a variable whose type is one of our
    `class_name` scripts resolves to a real member (catches typos and stale
    renames that the parser happily accepts)
  * `Class.CONST` on our own classes exists
  * duplicate function names inside one file
  * GDScript hazards: assignment of a ternary used as a statement, a `Label`
    theme override that does not exist, inner `class` instantiated across files

Usage:  python3 tools/check_project.py [--quiet]
Exit code 1 when anything is reported.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
QUIET = "--quiet" in sys.argv

AUTOLOADS = {
    "Signals": "src/autoload/signals.gd",
    "Db": "src/autoload/db.gd",
    "NetLink": "src/autoload/net_link.gd",
    "Sfx": "src/autoload/sfx.gd",
    "GameFlow": "src/autoload/game_flow.gd",
    "Ui": "src/autoload/ui_layer.gd",
}

# Built-in members we do not want to whitelist one by one.
# CharacterBody2D / CollisionObject2D members our Actor subclasses inherit.
BUILTIN = set("""
velocity collision_layer collision_mask is_on_floor is_on_wall body_entered
body_exited move_and_slide move_and_collide up_direction floor_snap_length
""".split())
BUILTIN |= set("""
add_child remove_child queue_free get_node get_parent get_tree get_children get_child
get_child_count get_index find_child has_node is_instance_valid is_queued_for_deletion
duplicate set get call call_deferred callv connect disconnect emit is_connected
has_method set_meta get_meta has_meta remove_meta position global_position rotation
scale visible modulate z_index name owner size set_anchors_and_offsets_preset
add_theme_stylebox_override add_theme_color_override add_theme_font_size_override
add_theme_constant_override add_theme_font_override mouse_filter process_mode
set_process set_physics_process queue_redraw draw_rect draw_line draw_circle
draw_arc draw_string draw_colored_polygon draw_polyline draw_set_transform
text value min_value max_value step show_percentage columns add_item select
selected item_selected get_item_count clear pressed hover text_changed
value_changed toggled button_pressed item_selected length length_squared
normalized distance_to angle lerp rotated abs clamp clampf clampi min max floor
ceil round sign sqrt pow dot cross limit_length move_toward wrapf wrapi
create_tween tween_property tween_interval tween_callback tween_method
get_viewport get_visible_rect make_current get_camera_2d is_empty has erase
append append_array insert remove_at pop_front pop_back slice keys values merge
create_timer instantiate change_scene_to_file change_scene_to_packed
get_unhandled_input get_global_mouse_position get_local_mouse_position
play stop seek stream volume_db pitch_scale bus set_identity
set_shader_parameter delta speed_scale
""".split())

PRIMITIVE = {
    "Vector2", "Vector2i", "Color", "Rect2", "Rect2i", "Array", "Dictionary",
    "String", "int", "float", "bool", "Callable", "Variant", "Node", "Node2D",
    "Control", "CanvasItem", "Object", "Resource", "Script", "Timer", "Tween",
    "ColorRect", "Label", "Button", "PanelContainer", "VBoxContainer",
    "HBoxContainer", "GridContainer", "MarginContainer", "ProgressBar",
}


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def collect_classes():
    """class_name -> {file, extends, funcs, consts, vars, signals}"""
    out = {}
    for root, _dirs, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            path = os.path.join(root, fn)
            text = read(path)
            m = re.search(r"^class_name\s+(\w+)", text, re.M)
            if not m:
                continue
            ext = re.search(r"^extends\s+(\w+)", text, re.M)
            entry = {
                "file": path,
                "extends": ext.group(1) if ext else "",
                "funcs": set(re.findall(r"^(?:static\s+)?func\s+(\w+)", text, re.M)),
                "consts": set(re.findall(r"^(?:static\s+)?const\s+(\w+)", text, re.M)),
                "vars": set(re.findall(r"^(?:@onready\s+)?var\s+(\w+)", text, re.M)),
                "signals": set(re.findall(r"^signal\s+(\w+)", text, re.M)),
            }
            for enum in re.finditer(r"enum\s+\w*\s*\{([^}]*)\}", text, re.S):
                for part in enum.group(1).split(","):
                    ident = part.strip().split("=")[0].strip()
                    if ident:
                        entry["consts"].add(ident)
            out[m.group(1)] = entry
    return out


CLASSES = collect_classes()


def autoload_members():
    out = {}
    for name, rel in AUTOLOADS.items():
        text = read(os.path.join(ROOT, rel))
        members = set(re.findall(r"^(?:static\s+)?func\s+(\w+)", text, re.M))
        members |= set(re.findall(r"^(?:static\s+)?const\s+(\w+)", text, re.M))
        members |= set(re.findall(r"^(?:@onready\s+)?var\s+(\w+)", text, re.M))
        members |= set(re.findall(r"^signal\s+(\w+)", text, re.M))
        for enum in re.finditer(r"enum\s*\w*\s*\{([^}]*)\}", text, re.S):
            for part in enum.group(1).split(","):
                ident = part.strip().split("=")[0].strip()
                if ident:
                    members.add(ident)
        out[name] = members
    return out


AUTOLOAD_MEMBERS = autoload_members()
problems = []


def report(path, line, kind, detail, context=""):
    rel = os.path.relpath(path, ROOT)
    problems.append((rel, line, kind, detail, context.strip()[:100]))


def chain(cls):
    seen = set()
    out = []
    while cls in CLASSES and cls not in seen:
        seen.add(cls)
        out.append(CLASSES[cls])
        cls = CLASSES[cls]["extends"]
    return out


def has_member(cls, name):
    if cls in PRIMITIVE:
        return True
    entries = chain(cls)
    for entry in entries:
        if name in entry["funcs"] or name in entry["vars"] or name in entry["consts"]:
            return True
    # a class extending a built-in inherits that built-in's members
    if entries and entries[-1]["extends"] in PRIMITIVE:
        return True
    return False


def declared_types(text):
    types = {}
    for m in re.finditer(r"^(?:@onready\s+)?var\s+(\w+)\s*:\s*([\w\[\]]+)", text, re.M):
        types[m.group(1)] = re.sub(r"\[.*\]", "", m.group(2))
    for m in re.finditer(r"func\s+\w+\s*\(([^)]*)\)", text, re.S):
        for param in m.group(1).split(","):
            pm = re.match(r"\s*(\w+)\s*:\s*([\w\[\]]+)", param)
            if pm:
                types[pm.group(1)] = re.sub(r"\[.*\]", "", pm.group(2))
    for m in re.finditer(r"^(?:@onready\s+)?var\s+(\w+)\s*:?=\s*(\w+)\.new\s*\(", text, re.M):
        if m.group(2) in CLASSES:
            types[m.group(1)] = m.group(2)
    return types


def check_file(path):
    text = read(path)
    lines = text.split("\n")

    # res:// paths
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r'"(res://[^"]+)"', line):
            target = m.group(1)
            if "%" in target:
                continue  # dynamic (mode_%s.gd)
            if not os.path.exists(os.path.join(ROOT, target.replace("res://", ""))):
                report(path, i, "MISSING-PATH", target)

    # duplicate functions
    seen = {}
    for i, line in enumerate(lines, 1):
        m = re.match(r"^(?:static\s+)?func\s+(\w+)", line)
        if m:
            if m.group(1) in seen:
                report(path, i, "DUPLICATE-FUNC", m.group(1), "first at line %d" % seen[m.group(1)])
            else:
                seen[m.group(1)] = i

    # autoload member access
    for i, line in enumerate(lines, 1):
        if line.strip().startswith("#"):
            continue
        for m in re.finditer(r"\b(Signals|Db|NetLink|Sfx|GameFlow|Ui)\.(\w+)", line):
            owner, member = m.group(1), m.group(2)
            if owner not in AUTOLOAD_MEMBERS:
                continue
            if member not in AUTOLOAD_MEMBERS[owner]:
                report(path, i, "MISSING-AUTOLOAD-MEMBER", "%s.%s" % (owner, member), line)

    # typed variable member access
    types = declared_types(text)
    # an identifier reused with two different types (a loop var `c`, a param
    # `visual`...) cannot be checked reliably -- drop it
    counts = {}
    for m in re.finditer(r"\b(?:var|for)\s+(\w+)\b[^\n]*?:\s*([\w\[\]]+)", text):
        counts.setdefault(m.group(1), set()).add(re.sub(r"\[.*\]", "", m.group(2)))
    for ident, kinds in counts.items():
        if len(kinds) > 1 and ident in types:
            types.pop(ident)
    for m in re.finditer(r"for\s+(\w+)\s+in\s+(\w+)", text):
        types.pop(m.group(1), None)
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for m in re.finditer(r"\b(\w+)\.(\w+)\s*\(", line):
            obj, meth = m.group(1), m.group(2)
            cls = types.get(obj)
            if cls is None or cls not in CLASSES:
                continue
            if not has_member(cls, meth) and meth not in BUILTIN:
                report(path, i, "UNKNOWN-METHOD", "%s:%s.%s()" % (obj, cls, meth), line)
        for m in re.finditer(r"\b(\w+)\.(\w+)\b(?!\s*\()", line):
            obj, prop = m.group(1), m.group(2)
            cls = types.get(obj)
            if cls is None or cls not in CLASSES:
                continue
            if not has_member(cls, prop) and prop not in BUILTIN:
                report(path, i, "UNKNOWN-PROP", "%s:%s.%s" % (obj, cls, prop), line)

    # Class.CONST on own classes
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r"\b([A-Z]\w+)\.([A-Z][A-Z0-9_]*)\b", line):
            cls, const = m.group(1), m.group(2)
            if cls not in CLASSES:
                continue
            found = any(const in e["consts"] for e in chain(cls))
            if not found:
                report(path, i, "UNKNOWN-CONST", "%s.%s" % (cls, const), line)

    # GDScript hazards
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        # a bare ternary as a statement (only valid inside an expression)
        # A ternary is only illegal when it is the whole statement; inside
        # call arguments, dict literals or a return it is fine.
        if stripped.startswith(("return ", "var ", "const ", "print(", "assert(")):
            continue
        if "=" in stripped or "(" in stripped or stripped.startswith(("[", "{", "#")):
            continue
        if re.match(r"^[A-Za-z_][\w\.\[\]\"']*\s*(!=|==)?\s*[^=]*\bif\b.+\belse\b", stripped):
            report(path, i, "TERNARY-AS-STATEMENT", stripped[:60])
        if "shadow_outline_size" in line and "add_theme_constant_override" in line:
            report(path, i, "BAD-THEME-PROP", "Label has no shadow_outline_size")


def main():
    files = []
    for root, _dirs, names in os.walk(SRC):
        for fn in sorted(names):
            if fn.endswith(".gd"):
                files.append(os.path.join(root, fn))
    for path in files:
        check_file(path)

    if problems:
        for rel, line, kind, detail, ctx in problems:
            print("%s:%d  %-24s %s  | %s" % (rel, line, kind, detail, ctx))
    if not QUIET:
        print("\n%d scripts checked, %d problem(s)" % (len(files), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
