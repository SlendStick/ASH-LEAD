#!/usr/bin/env python3
"""Static consistency audit for the ASH&LEAD codebase (no Godot required)."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


# ---------------------------------------------------------------- collect
gd_files = sorted(list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "autoload").rglob("*.gd")))
sources = {str(p.relative_to(ROOT)): p.read_text(encoding="utf-8") for p in gd_files}

class_names = {}
for path, src in sources.items():
    m = re.search(r"^class_name\s+(\w+)", src, re.M)
    if m:
        class_names[m.group(1)] = path

autoloads = {}
pg = (ROOT / "project.godot").read_text(encoding="utf-8")
for m in re.finditer(r"^\[autoload\](.*?)(?=^\[|\Z)", pg, re.M | re.S):
    for line in m.group(1).splitlines():
        mm = re.match(r'^"([^"]+)"\s*=\s*\*"res://([^"]+)"', line.strip())
        if mm:
            autoloads[mm.group(1)] = mm.group(2)

# ---------------------------------------------------------------- localization
tr = json.loads((ROOT / "locale" / "translations.json").read_text(encoding="utf-8"))
tr_keys = set(tr.keys())
prefixes = set()
for path, src in sources.items():
    for m in re.finditer(r'Localization\.t\(\s*"([^"]+)"\s*\+', src):
        prefixes.add(m.group(1))
    for m in re.finditer(r'Localization\.t\(\s*"([^"]+)"', src):
        key = m.group(1)
        if key in tr_keys:
            continue
        if any(key.startswith(p) for p in prefixes):
            continue
        err(f"{path}: missing localization key '{key}'")

# ---------------------------------------------------------------- data ids
data = {}
for name in ("weapons", "modes", "maps", "roles", "civilians"):
    data[name] = json.loads((ROOT / "data" / f"{name}.json").read_text(encoding="utf-8"))

for path, src in sources.items():
    for m in re.finditer(r'Data\.(mode|map|role|weapon|civilian)\(\s*"([^"]+)"', src):
        table, key = m.group(1), m.group(2)
        entries = data[table + "s"] if table + "s" in data else data[table]
        if isinstance(entries, dict):
            entries = list(entries.values())[0] if entries else []
        ids = {e.get("id") for e in entries} if isinstance(entries, list) else set(entries)
        if key not in ids:
            err(f"{path}: Data.{table}('{key}') not found in data/{table}s.json")

# ---------------------------------------------------------------- resources
for path, src in sources.items():
    for m in re.finditer(r'(?:load|preload)\(\s*"res://([^"]+)"', src):
        rel = m.group(1)
        if "%" in rel:
            continue
        if not (ROOT / rel).exists():
            err(f"{path}: missing resource res://{rel}")
    for m in re.finditer(r'"res://([^"]+\.(?:tscn|gd|json|wav|png|svg|tres))"', src):
        rel = m.group(1)
        if "%" in rel:
            continue
        if not (ROOT / rel).exists():
            err(f"{path}: missing resource res://{rel}")

# ---------------------------------------------------------------- signals
signal_defs = {}
for path, src in sources.items():
    for m in re.finditer(r"^signal\s+(\w+)", src, re.M):
        signal_defs.setdefault(m.group(1), path)

for path, src in sources.items():
    for m in re.finditer(r"\.(emit|connect)\(\s*(\w+)\b", src):
        name = m.group(2)
        if name in ("pressed", "text_changed", "item_selected", "toggled", "timeout", "resized",
                    "ready", "mouse_entered", "mouse_exited", "focus_entered", "focus_exited",
                    "button_down", "button_up", "draw", "visibility_changed", "tree_exiting",
                    "body_entered", "area_entered", "body_exited", "area_exited", "finished",
                    "value_changed", "tab_changed", "child_entered_tree", "child_exiting_tree",
                    "screen_resized", "size_flags_changed", "sort_children", "gui_input",
                    "close_requested", "files_dropped", "window_focus_changed", "files_changed",
                    "file_changed", "dir_changed", "changed", "toggled_pressed"):
            continue
        if name not in signal_defs:
            warn(f"{path}: signal '{name}' not defined in scripts")

# ---------------------------------------------------------------- classes
for path, src in sources.items():
    for m in re.finditer(r"\b([A-Z]\w+)\.new\(", src):
        cls = m.group(1)
        if cls in ("Weapon", "MapData", "Character", "Match", "HUD", "Minimap", "Crosshair",
                   "OrderWheel", "Scoreboard", "MapOverlay", "DeathScreen", "CivilianMenu",
                   "NegotiationMenu", "MainMenu", "SettingsScreen", "LobbyScreen", "LoadoutScreen",
                   "ResultsScreen", "ReplayView", "PauseMenu", "ProfileScreen", "CollectionScreen",
                   "CreditsScreen", "ReplayRecorder", "GameMode", "MapGenerator", "Props",
                   "Perception", "NoiseManager", "FogOfWar", "CityResonance", "BotController",
                   "CivilianController", "PlayerController", "Interactable", "Door", "MapView",
                   "InteractDevice", "InteractLoot", "InteractZone", "InteractHeal",
                   "InteractCivilian", "InteractHostage", "Node", "Control", "Label", "Button",
                   "Panel", "PanelContainer", "VBoxContainer", "HBoxContainer", "GridContainer",
                   "ColorRect", "TextureRect", "LineEdit", "TextEdit", "OptionButton", "CheckBox",
                   "Slider", "ProgressBar", "TabContainer", "ScrollContainer", "Sprite2D",
                   "CharacterBody2D", "Camera2D", "Timer", "RandomNumberGenerator", "StyleBoxFlat",
                   "StyleBoxEmpty", "InputEvent", "InputEventKey", "InputEventMouseButton",
                   "InputEventMouseMotion", "InputEventJoypadMotion", "InputEventJoypadButton",
                   "AudioStreamPlayer", "AudioStreamPlayer2D", "ENetMultiplayerPeer",
                   "MultiplayerAPI", "SceneTree", "Tween", "RayCast2D", "Line2D", "PointLight2D",
                   "CanvasLayer", "Node2D", "ResourceLoader", "FileAccess", "DirAccess",
                   "JSON", "Time", "OS", "Engine", "DisplayServer", "TextServer", "Input",
                   "InputMap", "ProjectSettings", "Color", "Vector2", "Vector2i", "Rect2",
                   "Rect2i", "Transform2D", "PackedScene", "Texture2D", "AudioStream",
                   "AudioStreamWAV", "AudioBusLayout", "Callable", "Signal", "Dictionary", "Array",
                   "String", "StringName", "NodePath", "RID", "Object", "RefCounted", "Resource",
                   "Viewport", "Window", "TextureButton", "Range", "SpinBox", "ItemList",
                   "MenuBar", "PopupPanel", "AcceptDialog", "FileDialog", "Sep",
                   "CollisionShape2D", "CircleShape2D", "RectangleShape2D", "Light2D",
                   "StaticBody2D", "TileMapLayer", "TileSet", "TileSetAtlasSource",
                   "LightOccluder2D", "OccluderPolygon2D", "CanvasModulate", "AudioListener2D",
                   "CheckButton", "HSlider", "Rain", "TextureButton", "BaseButton",
                   "Container", "BoxContainer", "Control", "Node",
                   ):
            continue
        warn(f"{path}: unknown class '{cls}'")

# ---------------------------------------------------------------- autoloads
for path, src in sources.items():
    for m in re.finditer(r"\b(GameTypes|U|Data|Game|NetManager|SettingsManager|InputManager|Localization|AudioManager|ProfileManager)\b", src):
        pass

print(f"files: {len(gd_files)}")
print(f"class_names: {sorted(class_names)}")
print(f"autoloads: {sorted(autoloads)}")
print(f"localization keys: {len(tr_keys)}")
for w in warnings:
    print("WARN " + w)
for e in errors:
    print("ERROR " + e)
print(f"ERRORS={len(errors)} WARNINGS={len(warnings)}")
sys.exit(1 if errors else 0)
