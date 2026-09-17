class_name ChargeBar
extends VBoxContainer

# 戦闘の中央のチャージバー（2026-09-17・人間のモック §9・人間「中央にチャージバーを」）。
#
# ⚠⚠ チャージの進み具合を出すのは**ここだけ**（モック §9-1）。⚠ マスとユニットには出さない。
# ⚠⚠ 行は**編成順で位置を固定**（モック §9-2）。⚠ 溜めていない行も高さを確保し、中身だけ隠す。
#   ⚠ 3人目がジャスト直前のときに1人目が離しても、⚠ 3人目の行が上にズレない。
# ⚠ 1人も溜めていなければ**器ごと隠す**。⚠ フェードは入れない（モック §9-6）。
# ⚠⚠ バーの右端＝**ジャストの窓の終わり**（`just_sec + just_window_sec`）。
#   ⚠ 窓（`just_sec ± just_window_sec`）は末尾の帯になる。⚠ 行き過ぎたら赤（⚠ 威力は100%に戻る）。
#   ⚠ 判定そのものは `BattleController._is_just()` の1本。⚠ ここは同じ数字で**描くだけ**。
# ⚠ 色・寸法は Theme の `ChargeBar` 型から引く（⚠ ここに書かない）。
# ⚠ 使うのは戦闘だけなので `scenes/adventure/`（AGENTS.md）。

const THEME_TYPE: StringName = &"ChargeBar"


# 1行ぶんの溝と塗り。⚠ `ProgressBar` を使わない（⚠ 帯を先に見せる・色を段で変えるため）。
class Track:
	extends Control

	var just_sec: float = 1.0
	var window_sec: float = 0.15
	# ⚠ 溜めた秒。⚠ 負なら溜めていない（⚠ 溝と帯だけ描く）。
	var t: float = -1.0

	func full_sec() -> float:
		return maxf(just_sec + window_sec, 0.001)

	func in_band() -> bool:
		return t >= 0.0 and absf(t - just_sec) <= window_sec

	func is_over() -> bool:
		return t > just_sec + window_sec

	func _draw() -> void:
		var tt: StringName = ChargeBar.THEME_TYPE
		var box: Rect2 = Rect2(Vector2.ZERO, size)
		var radius: int = int(size.y * 0.5)
		var border_color: Color = get_theme_color(&"track_border", tt)
		if in_band():
			border_color = get_theme_color(&"border_band", tt)
		elif is_over():
			border_color = get_theme_color(&"border_over", tt)

		var groove: StyleBoxFlat = StyleBoxFlat.new()
		groove.bg_color = get_theme_color(&"track_bg", tt)
		groove.border_color = border_color
		groove.set_border_width_all(get_theme_constant(&"border", tt))
		groove.set_corner_radius_all(radius)
		draw_style_box(groove, box)

		var band_from: float = size.x * clampf((just_sec - window_sec) / full_sec(), 0.0, 1.0)
		draw_rect(Rect2(band_from, 1.0, size.x - band_from - 1.0, size.y - 2.0), get_theme_color(&"band_idle", tt))

		if t < 0.0:
			return
		var ratio: float = clampf(t / full_sec(), 0.0, 1.0)
		if is_over():
			draw_rect(Rect2(1.0, 1.0, size.x - 2.0, size.y - 2.0), get_theme_color(&"fill_over", tt))
			return
		var fill_w: float = size.x * ratio
		var mid: float = float(get_theme_constant(&"mid_percent", tt)) / 100.0
		var fill_color: Color = get_theme_color(&"fill_mid" if ratio >= mid else &"fill_low", tt)
		draw_rect(Rect2(1.0, 1.0, minf(fill_w, band_from) - 1.0, size.y - 2.0), fill_color)
		# ⚠ 帯に入ったぶんは琥珀（モック §9-3）。
		if fill_w > band_from:
			draw_rect(
				Rect2(band_from, 1.0, fill_w - band_from - 1.0, size.y - 2.0),
				get_theme_color(&"fill_band", tt)
			)


# 行ごとの部品。{row: HBoxContainer, name: Label, track: Track}
var _rows: Array[Dictionary] = []


# 行を組む。⚠ 戦闘の編成が決まったときに1回（⚠ リトライでも呼び直してよい）。
#
# ⚠ `specs` は編成順（⚠ 左のキャラの左のスキルから）の
#   `{character_id, name, just_sec, window_sec}`。⚠ 0件なら何も出さない。
func build(specs: Array) -> void:
	theme_type_variation = &"ChargeRows"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠ remove_child() してから queue_free()（CLAUDE.md 5番）。
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()

	custom_minimum_size.x = get_theme_constant(&"width", THEME_TYPE)
	var row_h: int = get_theme_constant(&"row_height", THEME_TYPE)
	for raw: Variant in specs:
		var spec: Dictionary = raw
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"ChargeRow"
		row.custom_minimum_size.y = row_h
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)

		row.add_child(CharacterAvatar.create(
			str(spec.get("character_id", "")), get_theme_constant(&"icon", THEME_TYPE)
		))

		var name_label: Label = Label.new()
		name_label.theme_type_variation = &"BattleNameLabel"
		name_label.text = str(spec.get("name", ""))
		name_label.custom_minimum_size.x = get_theme_constant(&"name_width", THEME_TYPE)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		var track: Track = Track.new()
		track.just_sec = float(spec.get("just_sec", 1.0))
		track.window_sec = float(spec.get("window_sec", 0.15))
		track.custom_minimum_size.y = get_theme_constant(&"track_height", THEME_TYPE)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(track)

		_rows.append({"row": row, "name": name_label, "track": track})
	show_charging(-1, 0.0)


# いま溜めている行と秒を出す。⚠ `index` が負なら誰も溜めていない＝器ごと隠す。
# ⚠ 毎フレーム呼んでよい。
func show_charging(index: int, t: float) -> void:
	visible = index >= 0 and index < _rows.size()
	for i: int in range(_rows.size()):
		var parts: Dictionary = _rows[i]
		var charging: bool = i == index
		# ⚠ 行は消さない（⚠ 高さを残す）。⚠ 中身だけ見えなくする。
		for child: Node in (parts["row"] as HBoxContainer).get_children():
			(child as Control).modulate.a = 1.0 if charging else 0.0
		var track: Track = parts["track"]
		track.t = t if charging else -1.0
		track.queue_redraw()
		var name_key: StringName = &"name"
		if charging and track.in_band():
			name_key = &"name_band"
		elif charging and track.is_over():
			name_key = &"name_over"
		(parts["name"] as Label).add_theme_color_override(
			&"font_color", get_theme_color(name_key, THEME_TYPE)
		)
