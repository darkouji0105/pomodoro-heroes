extends Node

const SAVE_DIR: String = "user://saves/"
const SAVE_PATH: String = "user://saves/save_slot_0.json"
# 10軸化で character_growth.stats のキーが4本から10本に増えたため2へ。
# さらに character_growth に nodes（解放済みステータスノード）が増え、
# stat_growth_formula が "base" になって stats の意味が変わったため3へ。
# 旧バージョンは読み込まず捨てる（GAME_DESIGN.md 14章）。移行処理は書かない。
const CURRENT_SAVE_VERSION: int = 3

# GameManagerの現在の状態をJSONで保存する。
# 保存前にlast_saved_atを更新すること。
func save_game() -> bool:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	
	
	var snapshot: Dictionary = GameManager.get_state()
	var json_text: String = JSON.stringify(snapshot, "\t")
	
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] save_game: cannot open %s for writing" % SAVE_PATH)
		return false
	
	f.store_string(json_text)
	f.close()
	GameManager.mark_saved()
	print("[SaveManager] save_game -> %s" % SAVE_PATH)
	return true

# セーブがあれば読み込んでGameManagerに反映しtrueを返す。
# セーブが無い／壊れている場合は何もせずfalseを返す。
func load_game() -> bool:
	if not has_save():
		return false
	
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] load_game: cannot open %s" % SAVE_PATH)
		return false
	
	var json_text: String = f.get_as_text()
	f.close()
	
	var data: Variant = JSON.parse_string(json_text)
	if data == null:
		push_warning("[SaveManager] load_game: JSON parse failed (file might be broken)")
		return false
	
	if not (data is Dictionary):
		push_warning("[SaveManager] load_game: JSON is not a Dictionary")
		return false
	
	if not data.has(GameStateKeys.SAVE_VERSION):
		push_warning("[SaveManager] load_game: missing save_version")
		return false
	
	var loaded_version: int = int(data[GameStateKeys.SAVE_VERSION])
	if loaded_version != CURRENT_SAVE_VERSION:
		# 読み込まずに false を返す。以前は warning を出して続行していたが、
		# それだと4軸のセーブが10軸のコードに流れ込み、新6軸が 0 のまま
		# 「バグなのか仕様なのか」判別できない状態になる。
		# ファイルは消さない。消すのはタイトル画面の「セーブを削除」だけ。
		push_warning("[SaveManager] load_game: version mismatch (have=%d, expected=%d) - refusing to load" % [loaded_version, CURRENT_SAVE_VERSION])
		return false

	# ⚠ 読み込みの間は増えた演出を止める（2026-09-09）。⚠ ロードは全部の資源を
	#   ⚠ 一度に書き換えるので、⚠ そのまま流すと画面いっぱいに飛ぶ。
	ResourceGainEffect.set_muted(true)
	var ok: bool = GameManager.load_state(data as Dictionary)
	ResourceGainEffect.set_muted(false)
	return ok

# セーブファイルが存在するか
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# セーブを削除する（テスト・デバッグ用）
func delete_save() -> bool:
	if not has_save():
		return true # べき等性確保
	
	var err: Error = DirAccess.remove_absolute(SAVE_PATH)
	if err != OK:
		push_error("[SaveManager] delete_save: failed to remove %s (error code: %d)" % [SAVE_PATH, err])
		return false
	
	print("[SaveManager] delete_save: success")
	return true

# --- 設定（2026-09-15） ---
#
# ⚠ ゲームのセーブとは別のファイル（人間の決定「別のファイルだね」）。
#   ⚠ 窓の出し方や音量は「その PC の好み」で、⚠ セーブスロットごとに変わるものではない。
# ⚠ 画面は ConfigFile を直接触らない。⚠ 項目ごとの get_ / set_ を通す。

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION_UI: String = "ui"
const SETTINGS_KEY_INVENTORY_MODE: String = "inventory_mode"
# インベントリの出し方。⚠ 実験中（⚠ 両方を試して比べる・人間の決定 2026-09-15）。
# ⚠ ファイルに書く綴りなので、⚠ 決めたあとに改名しないこと。
const INVENTORY_MODE_EMBEDDED: String = "embedded"
const INVENTORY_MODE_NATIVE: String = "native"
const INVENTORY_MODES: Array[String] = [INVENTORY_MODE_EMBEDDED, INVENTORY_MODE_NATIVE]

var _settings: ConfigFile = null


func get_inventory_mode() -> String:
	var value: String = str(_load_settings().get_value(
		SETTINGS_SECTION_UI, SETTINGS_KEY_INVENTORY_MODE, INVENTORY_MODE_EMBEDDED
	))
	if not INVENTORY_MODES.has(value):
		push_warning("[SaveManager] get_inventory_mode: unknown value '%s' - using %s" % [value, INVENTORY_MODE_EMBEDDED])
		return INVENTORY_MODE_EMBEDDED
	return value


# ⚠ 判定と書き込みを全部終えてから、⚠ 手元の設定を差し替える（CLAUDE.md 6番）。
#   ⚠ 書き込みに失敗したら、⚠ 手元もファイルも前のまま。
func set_inventory_mode(mode: String) -> bool:
	if not INVENTORY_MODES.has(mode):
		push_error("[SaveManager] set_inventory_mode: unknown mode '%s'" % mode)
		return false
	var next: ConfigFile = ConfigFile.new()
	next.parse(_load_settings().encode_to_text())
	next.set_value(SETTINGS_SECTION_UI, SETTINGS_KEY_INVENTORY_MODE, mode)
	var err: Error = next.save(SETTINGS_PATH)
	if err != OK:
		push_error("[SaveManager] set_inventory_mode: cannot write %s (error code: %d)" % [SETTINGS_PATH, err])
		return false
	_settings = next
	print("[SaveManager] set_inventory_mode -> %s" % mode)
	return true


func _load_settings() -> ConfigFile:
	if _settings != null:
		return _settings
	_settings = ConfigFile.new()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return _settings
	var err: Error = _settings.load(SETTINGS_PATH)
	if err != OK:
		push_warning("[SaveManager] cannot read %s (error code: %d) - using defaults" % [SETTINGS_PATH, err])
		_settings = ConfigFile.new()
	return _settings
