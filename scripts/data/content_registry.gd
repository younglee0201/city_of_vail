extends Node

const DATA_PATH := "res://resources/data/contents.json"
const FALLBACK_LANGS := ["tc", "en"]

var current_language: String = "tc"
var _by_key: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var rows := TableLoader.load_table(DATA_PATH)
	for row in rows:
		var key_v: Variant = row.get("key")
		if key_v == null:
			continue
		_by_key[str(key_v)] = row


func text(key: String) -> String:
	if key == "":
		return ""
	var entry: Variant = _by_key.get(key)
	if entry == null:
		push_warning("ContentRegistry: key not found: %s" % key)
		return key
	var resolved: String = _lookup(entry, current_language)
	if resolved != "":
		return resolved
	for lang in FALLBACK_LANGS:
		if lang == current_language:
			continue
		resolved = _lookup(entry, lang)
		if resolved != "":
			return resolved
	return key


func has(key: String) -> bool:
	return _by_key.has(key)


func _lookup(entry: Dictionary, lang: String) -> String:
	var v: Variant = entry.get(lang)
	if v == null:
		return ""
	return str(v)
