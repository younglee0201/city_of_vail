class_name TableLoader


static func load_table(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Table file not found at %s" % path)
		return rows
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Array):
		push_error("Table is not a JSON array: %s" % path)
		return rows
	var arr: Array = parsed
	if arr.is_empty():
		push_error("Table is empty: %s" % path)
		return rows
	if not (arr[0] is Dictionary):
		push_error("Table type header (row 0) is not an object: %s" % path)
		return rows
	var type_row: Dictionary = arr[0]
	for i in range(1, arr.size()):
		if not (arr[i] is Dictionary):
			continue
		var raw: Dictionary = arr[i]
		if raw.is_empty():
			continue
		var dict: Dictionary = {}
		for col in type_row.keys():
			if not raw.has(col):
				continue
			var type_name: String = str(type_row[col])
			dict[col] = _convert(raw[col], type_name)
		rows.append(dict)
	return rows


static func _convert(value: Variant, type_name: String) -> Variant:
	if value == null:
		return null
	match type_name:
		"int":
			return int(value)
		"float":
			return float(value)
		"bool":
			return bool(value)
		"string":
			return str(value)
		_:
			return value
