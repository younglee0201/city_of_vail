extends Node

const DATA_PATH := "res://resources/data/buildings.json"
const ART_DIR := "res://resources/assets/building/"


class BuildingEntry:
	var id: int
	var key: String
	var display_name_key: String
	var icon: String
	var size: Variant
	var cost: Variant
	var cooldown: Variant
	var coin_gain: Variant
	var effect: Variant
	var hp: Variant
	var tier: Variant
	var display_text: String
	var texture_paths: Array[String] = []


var _entries: Array[BuildingEntry] = []
var _by_id: Dictionary = {}
var _by_key: Dictionary = {}
var _by_icon: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var rows := TableLoader.load_table(DATA_PATH)
	for row in rows:
		var id_v: Variant = row.get("id")
		if id_v == null:
			continue
		var entry := BuildingEntry.new()
		entry.id = int(id_v)
		entry.key = _str(row.get("key"))
		entry.display_name_key = _str(row.get("name"))
		entry.icon = _str(row.get("icon"))
		entry.size = row.get("size")
		entry.cost = row.get("cost")
		entry.cooldown = row.get("cooldown")
		entry.coin_gain = row.get("coin gain $")
		entry.effect = row.get("effect")
		entry.hp = row.get("hp")
		entry.tier = row.get("Tier")
		entry.display_text = _str(row.get("Display Text"))
		entry.texture_paths = _find_variants(entry.icon)
		_entries.append(entry)
		_by_id[entry.id] = entry
		_by_key[entry.key] = entry
		_by_icon[entry.icon] = entry


func _str(v: Variant) -> String:
	return "" if v == null else str(v)


func _find_variants(icon: String) -> Array[String]:
	var paths: Array[String] = []
	if icon == "":
		return paths
	var i := 1
	while true:
		var path := "%s%s_%03d.png" % [ART_DIR, icon, i]
		if not ResourceLoader.exists(path):
			break
		paths.append(path)
		i += 1
	return paths


func all() -> Array[BuildingEntry]:
	return _entries


func by_id(id: int) -> BuildingEntry:
	return _by_id.get(id)


func by_key(key: String) -> BuildingEntry:
	return _by_key.get(key)


func by_icon(icon: String) -> BuildingEntry:
	return _by_icon.get(icon)


func display_name(entry: BuildingEntry) -> String:
	return ContentRegistry.text(entry.display_name_key)


func display_text(entry: BuildingEntry) -> String:
	return ContentRegistry.text(entry.display_text)


func random_texture_path(entry: BuildingEntry) -> String:
	if entry.texture_paths.is_empty():
		return ""
	return entry.texture_paths[randi() % entry.texture_paths.size()]


func has_art(entry: BuildingEntry) -> bool:
	return not entry.texture_paths.is_empty()


func with_art() -> Array[BuildingEntry]:
	var result: Array[BuildingEntry] = []
	for entry in _entries:
		if has_art(entry):
			result.append(entry)
	return result
