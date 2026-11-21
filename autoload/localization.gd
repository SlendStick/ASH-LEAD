extends Node
## Localization: Russian by default, English available. Strings live in
## res://locale/translations.json as { "key": { "ru": "...", "en": "..." } }.

signal language_changed(lang: String)

const LOCALE_PATH := "res://locale/translations.json"

var language: String = "ru"
var _table: Dictionary = {}


func _ready() -> void:
	load_table()


func load_table() -> void:
	_table = {}
	if not FileAccess.file_exists(LOCALE_PATH):
		push_error("ASH&LEAD: missing locale file %s" % LOCALE_PATH)
		return
	var f := FileAccess.open(LOCALE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_table = parsed


func t(key: String) -> String:
	var entry: Variant = _table.get(key)
	if entry is Dictionary:
		var value: Variant = entry.get(language, entry.get("en", entry.get("ru", "")))
		return String(value)
	return key


func set_language(lang: String) -> void:
	if lang != "ru" and lang != "en":
		return
	language = lang
	language_changed.emit(lang)
