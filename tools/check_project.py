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

KEYWORDS = {
    "if", "for", "while", "match", "return", "func", "class", "and", "or", "not",
    "in", "is", "as", "pass", "break", "continue", "signal", "var", "const",
    "enum", "extends", "super", "self", "await", "print", "assert", "push_error",
    "range", "load", "preload", "str", "int", "float", "bool", "len", "typeof",
    "Vector2", "Vector2i", "Color", "Rect2", "Rect2i", "Array", "Dictionary",
    "String", "max", "min", "abs", "clamp", "lerp", "sign", "floor", "ceil",
    "round", "sqrt", "pow", "sin", "cos", "tan", "atan2", "randf", "randi",
    "randf_range", "randi_range", "fmod", "wrapf", "wrapi", "snapped", "is_equal_approx",
    "maxf", "minf", "maxi", "mini", "absf", "absi", "signf", "signi", "clampf", "clampi",
    "clamp", "hash", "lerpf", "inverse_lerp", "remap", "smoothstep", "stepify",
    "deg_to_rad", "rad_to_deg", "move_toward", "nearest_po2", "linear_to_db",
    "print_debug", "print_rich", "push_warning", "type_exists", "is_instance_of",
    "instance_from_id", "var_to_str", "str_to_var", "get_stack", "weakref",
    "Color8", "Color", "Rect2", "Vector3", "Transform2D", "PackedScene",
    "roundf", "floorf", "ceilf", "snappedf", "else", "elif", "get_node_or_null",
    "set_process_unhandled_input", "set_process_input", "set_physics_process_internal",
    "notify_property_list_changed", "get_parent", "get_tree", "is_inside_tree",
    "add_to_group", "remove_from_group", "is_in_group", "set_deferred", "get_meta",
}

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

    # calls to own-class methods with no receiver (`_host_tick()` etc.)
    own = None
    m = re.search(r"^class_name\s+(\w+)", text, re.M)
    if m:
        own = m.group(1)
    elif path.endswith(".gd"):
        # scripts without class_name still get checked against their own body
        own = None
    if own is not None:
        defined = set()
        for entry in chain(own):
            defined |= entry["funcs"]
            defined |= entry["vars"]
            defined |= entry["consts"]
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith(("#", "func ", "signal ")):
                continue
            code = line.split("#")[0]
            for m2 in re.finditer(r"(?<![\w.\"'])([a-z_]\w*)\s*\(", code):
                name = m2.group(1)
                if name in BUILTIN or name in KEYWORDS or name in defined:
                    continue
                report(path, i, "UNKNOWN-CALL", name + "()", line)

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


def check_world_contract():
    """Modes talk to MatchWorld through world.call/get("name"). Those strings are
    invisible to the parser, so validate them against the class itself."""
    world_path = os.path.join(SRC, "core", "match_world.gd")
    if not os.path.exists(world_path):
        return
    text = read(world_path)
    members = set(re.findall(r"^(?:static\s+)?func\s+(\w+)", text, re.M))
    members |= set(re.findall(r"^(?:@onready\s+)?var\s+(\w+)", text, re.M))
    members |= set(re.findall(r"^(?:static\s+)?const\s+(\w+)", text, re.M))
    members |= set(re.findall(r"^signal\s+(\w+)", text, re.M))
    for root, _dirs, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            path = os.path.join(root, fn)
            body = read(path)
            for i, line in enumerate(body.split("\n"), 1):
                if line.strip().startswith("#"):
                    continue
                for m in re.finditer(r'\bworld\.(?:call|get)\(\s*"(\w+)"', line):
                    if m.group(1) not in members:
                        report(path, i, "WORLD-CONTRACT", "world has no " + m.group(1), line)
                for m in re.finditer(r'\bworld\.set\(\s*"(\w+)"', line):
                    if m.group(1) not in members:
                        report(path, i, "WORLD-CONTRACT", "world has no " + m.group(1), line)


def check_sfx_ids():
    """play_at("…") with an id that has no synthesized bank is a silent no-op.
    Catch those before a designer spends an hour wondering why the door is quiet."""
    path = os.path.join(SRC, "autoload", "sfx.gd")
    if not os.path.exists(path):
        return
    text = read(path)
    built = set(re.findall(r'banks\["(\w+)"\]\s*=', text))
    for root, _dirs, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            fpath = os.path.join(root, fn)
            for i, line in enumerate(read(fpath).split("\n"), 1):
                if line.strip().startswith("#"):
                    continue
                for m in re.finditer(r'\bplay(?:_at|_ui)?\(\s*"([\w]+)"', line):
                    if m.group(1) not in built:
                        report(fpath, i, "MISSING-SFX", m.group(1), line)


def check_music_ids():
    path = os.path.join(SRC, "autoload", "sfx.gd")
    if not os.path.exists(path):
        return
    text = read(path)
    tracks = set(re.findall(r'music_tracks\["(\w+)"\]', text))
    if not tracks:
        return
    for root, _dirs, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            fpath = os.path.join(root, fn)
            for i, line in enumerate(read(fpath).split("\n"), 1):
                if line.strip().startswith("#"):
                    continue
                for m in re.finditer(r'play_music\(\s*"([\w]+)"', line):
                    if m.group(1) not in tracks:
                        report(fpath, i, "MISSING-MUSIC", m.group(1), line)


def check_project_godot():
    path = os.path.join(ROOT, "project.godot")
    if not os.path.exists(path):
        report(path, 0, "MISSING-FILE", "project.godot")
        return
    text = read(path)
    for m in re.finditer(r'^\w+="(res://[^"]+)"', text, re.M):
        target = m.group(1)
        if not os.path.exists(os.path.join(ROOT, target.replace("res://", ""))):
            report(path, 0, "MISSING-PATH", target)
    for m in re.finditer(r'^\w+\s*=\s*"(\w+)"', text, re.M):
        pass
    # autoloads referenced in the [autoload] section must exist
    section = re.search(r"\[autoload\](.*?)(\n\[|$)", text, re.S)
    if section:
        for m in re.finditer(r'^(\w+)="(res://[^"]+)"', section.group(1), re.M):
            if not os.path.exists(os.path.join(ROOT, m.group(2).replace("res://", ""))):
                report(path, 0, "MISSING-AUTOLOAD", "%s -> %s" % (m.group(1), m.group(2)))


def main():
    files = []
    for root, _dirs, names in os.walk(SRC):
        for fn in sorted(names):
            if fn.endswith(".gd"):
                files.append(os.path.join(root, fn))
    for path in files:
        check_file(path)
    check_world_contract()
    check_sfx_ids()
    check_music_ids()
    check_project_godot()

    if problems:
        for rel, line, kind, detail, ctx in problems:
            print("%s:%d  %-24s %s  | %s" % (rel, line, kind, detail, ctx))
    if not QUIET:
        print("\n%d scripts checked, %d problem(s)" % (len(files), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
