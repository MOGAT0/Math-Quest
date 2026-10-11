extends Node

signal report_exported(summary_csv_path: String)

signal graphs_saved(path: String)
signal share_requested(paths: PackedStringArray)

var _last_export_paths : PackedStringArray = []

const ANALYSIS_PATH := "user://analysis_data.json"
const EXPORT_FOLDER_NAME := "MathQuest-Report"

var _fell_back_to_private : bool = false

const C_BG := Color("#f7ead0")
const C_GRID := Color("#d9c48f")
const C_TEXT := Color("#241a10")
const C_LINE := Color("#8a1f1f")
const C_FILL := Color(0.54, 0.12, 0.12, 0.25)
const C_ACCENT := Color("#a8781a")

var _overlay : CanvasLayer = null


func _is_mobile() -> bool:
	return OS.get_name().to_lower() in ["android", "ios"]

# ------------------------------------------------------------------ storage --

func record_answer(entry: Dictionary) -> void:
	var data := _load_raw()
	data["attempts"].append(entry)
	_save_raw(data)

func get_attempts() -> Array:
	return _load_raw()["attempts"]

func clear_data() -> void:
	_save_raw({"attempts": []})

func _load_raw() -> Dictionary:
	var empty := {"attempts": []}
	if not FileAccess.file_exists(ANALYSIS_PATH):
		return empty
	var f := FileAccess.open(ANALYSIS_PATH, FileAccess.READ)
	if f == null:
		return empty
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("attempts")) != TYPE_ARRAY:
		return empty
	return parsed

func _save_raw(data: Dictionary) -> void:
	var f := FileAccess.open(ANALYSIS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("AnalysisReport: cannot write %s" % ANALYSIS_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# ----------------------------------------------------------------- analysis --

func _order_key(grade: String, lesson: String) -> int:
	var g := grade.trim_prefix("g").to_int()
	var l := 11 if lesson == "final" else 0
	if l == 0:
		var parts := lesson.split("-l")
		l = parts[1].to_int() if parts.size() > 1 else 0
	return g * 100 + l

## Returns:
##  lessons : per-lesson stats, curriculum order
##  sessions: one entry per lesson run, chronological (feeds the line graph)
##  radar_grade / radar_labels / radar_values : accuracy per lesson of one grade
func analyze(radar_grade: String = "") -> Dictionary:
	var lessons := {}
	var sessions := {}
	var latest_grade := ""

	for a in get_attempts():
		var g := str(a.get("grade", ""))
		var l := str(a.get("lesson", ""))
		var ok := bool(a.get("is_correct", false))
		var t := int(a.get("time_ms", 0))
		var key := "%s|%s" % [g, l]
		latest_grade = g

		if not lessons.has(key):
			lessons[key] = {
				"grade": g, "lesson": l, "title": str(a.get("lesson_title", l)),
				"total": 0, "correct": 0, "time_ms": 0, "order": _order_key(g, l)
			}
		var ls : Dictionary = lessons[key]
		ls["total"] += 1
		ls["correct"] += 1 if ok else 0
		ls["time_ms"] += t

		var sid := str(a.get("session", key))
		if not sessions.has(sid):
			sessions[sid] = {
				"label": l, "total": 0, "correct": 0,
				"ts": int(a.get("timestamp", 0)), "seq": sessions.size()
			}
		sessions[sid]["total"] += 1
		sessions[sid]["correct"] += 1 if ok else 0

	var lesson_list : Array = lessons.values()
	for ls in lesson_list:
		ls["accuracy"] = 100.0 * ls["correct"] / max(ls["total"], 1)
		ls["avg_time_s"] = ls["time_ms"] / 1000.0 / max(ls["total"], 1)
	lesson_list.sort_custom(func(x, y): return x["order"] < y["order"])

	var session_list : Array = sessions.values()
	for s in session_list:
		s["accuracy"] = 100.0 * s["correct"] / max(s["total"], 1)
	session_list.sort_custom(func(x, y):
		return x["ts"] < y["ts"] if x["ts"] != y["ts"] else x["seq"] < y["seq"])

	if radar_grade == "":
		radar_grade = latest_grade
	var radar_labels : Array = []
	var radar_values : Array = []
	for ls in lesson_list:
		if ls["grade"] == radar_grade:
			var parts : PackedStringArray = str(ls["lesson"]).split("-l")
			radar_labels.append("Final" if ls["lesson"] == "final" else "L%s" % (parts[1] if parts.size() > 1 else ls["lesson"]))
			radar_values.append(ls["accuracy"])

	return {
		"lessons": lesson_list, "sessions": session_list,
		"radar_grade": radar_grade, "radar_labels": radar_labels, "radar_values": radar_values
	}


# ------------------------------------------------------------------- export --

func _export(radar_grade: String = "", target_folder: String = "") -> String:
	var attempts := get_attempts()
	if attempts.is_empty():
		push_warning("AnalysisReport: nothing to export yet.")
		return ""

	var folder := _get_export_folder(target_folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var summary_path := folder.path_join("analysis_summary_%s.csv" % stamp)
	var answers_path := folder.path_join("analysis_answers_%s.csv" % stamp)
	var png_path := folder.path_join("analysis_graphs_%s.png" % stamp)

	var result := analyze(radar_grade)

	var f := FileAccess.open(summary_path, FileAccess.WRITE)
	if f == null:
		push_error("AnalysisReport: cannot write %s" % summary_path)
		return ""
	f.store_csv_line(PackedStringArray(["grade", "lesson", "title", "answers", "correct", "wrong", "accuracy_pct", "avg_time_sec"]))
	for ls in result["lessons"]:
		f.store_csv_line(PackedStringArray([
			ls["grade"], ls["lesson"], ls["title"], str(ls["total"]), str(ls["correct"]),
			str(ls["total"] - ls["correct"]), "%.1f" % ls["accuracy"], "%.2f" % ls["avg_time_s"]
		]))
	f.close()

	var r := FileAccess.open(answers_path, FileAccess.WRITE)
	if r != null:
		r.store_csv_line(PackedStringArray([
			"datetime", "grade", "lesson", "lesson_title", "question_no", "question",
			"selected_answer", "correct_answer", "is_correct", "time_sec", "relearn"
		]))
		for a in attempts:
			r.store_csv_line(PackedStringArray([
				str(a.get("datetime", "")), str(a.get("grade", "")), str(a.get("lesson", "")),
				str(a.get("lesson_title", "")), str(int(a.get("question_idx", 0)) + 1),
				str(a.get("question", "")), str(a.get("selected_answer", "")),
				str(a.get("correct_answer", "")), str(a.get("is_correct", false)),
				"%.2f" % (int(a.get("time_ms", 0)) / 1000.0), str(a.get("relearn", false))
			]))
		r.close()
	
	_last_export_paths = PackedStringArray([summary_path, answers_path, png_path])
	export_graphs_png(png_path, radar_grade)  # async, finishes a few frames later
	report_exported.emit(summary_path)
	print("AnalysisReport exported to: ", folder)
	return summary_path


var _last_dir : String = ""
func pick_folder_and_export(radar_grade: String = "") -> void:
	if _is_mobile():
		OS.request_permissions()
		var path := _export(radar_grade)
		if path == "":
			return
		await graphs_saved
		if _fell_back_to_private:
			share_requested.emit(_last_export_paths)
		return

	# Desktop: let the user choose a folder.
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.title = "Choose a folder for the report"
	dlg.use_native_dialog = true
	dlg.min_size = Vector2i(700, 450)
	dlg.current_dir = _last_dir if _last_dir != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	add_child(dlg)

	dlg.dir_selected.connect(func(dir: String):
		_last_dir = dir
		_export(radar_grade, dir)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered_ratio(0.7)

func _get_export_folder(custom_folder: String = "") -> String:
	_fell_back_to_private = false
	if _is_mobile():
		if OS.get_name().to_lower() == "android":
			var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			var shared := docs.path_join(EXPORT_FOLDER_NAME)
			if not docs.is_empty() and DirAccess.make_dir_recursive_absolute(shared) == OK:
				var test := FileAccess.open(shared.path_join(".write_test"), FileAccess.WRITE)
				if test != null:
					test.close()
					DirAccess.remove_absolute(shared.path_join(".write_test"))
					return shared
		_fell_back_to_private = true
		var private_folder := ProjectSettings.globalize_path("user://").path_join(EXPORT_FOLDER_NAME)
		DirAccess.make_dir_recursive_absolute(private_folder)
		return private_folder
		
	if custom_folder != "" and DirAccess.make_dir_recursive_absolute(custom_folder) == OK:
		return custom_folder

	var base := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if base.is_empty():
		base = ProjectSettings.globalize_path("user://")
	var folder := base.path_join(EXPORT_FOLDER_NAME)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		folder = ProjectSettings.globalize_path("user://")
	return folder

func export_graphs_png(path: String, radar_grade: String = "") -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var report := build_report(radar_grade)
	report.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(report)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	if img:
		img.save_png(path)
	vp.queue_free()
	graphs_saved.emit(path)


# ------------------------------------------------------------------- report --

## Builds the report UI (summary + line graph + radar chart) as a Control.
func build_report(radar_grade: String = "") -> Control:
	var result := analyze(radar_grade)

	var root := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 20)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)

	var total := 0
	var correct := 0
	for ls in result["lessons"]:
		total += ls["total"]
		correct += ls["correct"]
	var overall = 100.0 * correct / max(total, 1)

	vbox.add_child(_label("Learning Analysis Report", 24))
	vbox.add_child(_label("%d answers  |  %d correct  |  %.1f%% overall accuracy" % [total, correct, overall], 15))

	vbox.add_child(_label("Accuracy per lesson attempt", 18))
	var line := LineChart.new()
	line.custom_minimum_size = Vector2(0, 280)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.points = result["sessions"].map(func(s): return {"label": s["label"], "value": s["accuracy"]})
	vbox.add_child(line)

	vbox.add_child(_label("Mastery by lesson - Grade %s" % str(result["radar_grade"]).trim_prefix("g"), 18))
	var radar := RadarChart.new()
	radar.custom_minimum_size = Vector2(0, 360)
	radar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	radar.labels = result["radar_labels"]
	radar.values = result["radar_values"]
	vbox.add_child(radar)

	return root

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", C_TEXT)
	return l

## Opens the report full-screen on top of everything.
func show_report(radar_grade: String = "") -> void:
	hide_report()
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(col)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var report := build_report(radar_grade)
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(report)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)

	var export_btn := Button.new()
	export_btn.text = "Export CSV"
	export_btn.custom_minimum_size = Vector2(160, 48)
	export_btn.pressed.connect(func(): _export(radar_grade))
	bar.add_child(export_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 48)
	close_btn.pressed.connect(hide_report)
	bar.add_child(close_btn)

func hide_report() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


# ------------------------------------------------------------------- charts --

class LineChart extends Control:
	var points : Array = []   # [{label: String, value: float 0-100}]

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var ink := Color("#241a10")
		var grid := Color("#d9c48f")
		var plot := Rect2(46, 16, size.x - 46 - 16, size.y - 16 - 34)

		for i in range(5):
			var y := plot.end.y - plot.size.y * i / 4.0
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), grid, 1.0)
			draw_string(font, Vector2(4, y + 5), "%d%%" % (i * 25), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		draw_line(plot.position, Vector2(plot.position.x, plot.end.y), ink, 1.5)
		draw_line(Vector2(plot.position.x, plot.end.y), plot.end, ink, 1.5)

		if points.is_empty():
			draw_string(font, plot.get_center() - Vector2(40, 0), "No data yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
			return

		var n := points.size()
		var label_every := maxi(1, ceili(n / 10.0))
		var pts := PackedVector2Array()
		for i in range(n):
			var x := plot.get_center().x if n == 1 else plot.position.x + plot.size.x * i / float(n - 1)
			var y := plot.end.y - plot.size.y * clampf(float(points[i]["value"]), 0.0, 100.0) / 100.0
			pts.append(Vector2(x, y))
			if i % label_every == 0:
				draw_string(font, Vector2(x - 18, plot.end.y + 18), str(points[i]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)

		if pts.size() > 1:
			draw_polyline(pts, Color("#8a1f1f"), 2.5, true)
		for p in pts:
			draw_circle(p, 5.0, Color("#a8781a"))
			draw_circle(p, 3.0, Color("#f7ead0"))


class RadarChart extends Control:
	var labels : Array = []
	var values : Array = []   # 0-100

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var ink := Color("#241a10")
		var grid := Color("#d9c48f")
		var n := labels.size()
		if n == 0:
			draw_string(font, size / 2.0 - Vector2(40, 0), "No data yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
			return

		var c := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 36.0

		for ring in range(1, 5):
			var rr := radius * ring / 4.0
			var ring_pts := PackedVector2Array()
			for i in range(n):
				ring_pts.append(c + Vector2.from_angle(_angle(i, n)) * rr)
			ring_pts.append(ring_pts[0])
			draw_polyline(ring_pts, grid, 1.0)
			draw_string(font, c + Vector2(4, -rr + 12), "%d%%" % (ring * 25), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)

		var poly := PackedVector2Array()
		for i in range(n):
			var dir := Vector2.from_angle(_angle(i, n))
			draw_line(c, c + dir * radius, grid, 1.0)
			var v := clampf(float(values[i]), 0.0, 100.0) / 100.0
			poly.append(c + dir * radius * v)
			var lp := c + dir * (radius + 18.0) - Vector2(10, -5)
			draw_string(font, lp, str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

		if n >= 3:
			draw_colored_polygon(poly, Color(0.54, 0.12, 0.12, 0.25))
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color("#8a1f1f"), 2.5, true)
		for p in poly:
			draw_circle(p, 4.0, Color("#a8781a"))

	func _angle(i: int, n: int) -> float:
		return -PI / 2.0 + TAU * i / float(n)
