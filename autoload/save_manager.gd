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

	return GameManager.load_state(data as Dictionary)

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
