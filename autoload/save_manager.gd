extends Node

# ⚠⚠ 自動セーブと閉じたときの扱い（2026-10-05・回P-1・人間「⚠ ｑ１　あ　ｑ２　あ　ｑ３　いい」）。
#   ⚠ 自動で書くのは「遊んでいる最中」だけ（⚠ タイトルで始めた `begin_session()` 〜 タイトルに戻った `end_session()`）。
#     ⚠ 書く時＝⚠ 画面を移るとき（`SceneManager`）／ ⚠ ポモドーロのセットが終わるたび ／ ⚠ 窓を閉じるとき。
#   ⚠ 窓を閉じる（×）と、⚠ `quitting` を出す（⚠ ポモドーロは「やめる」と同じに確定する）→ ⚠ 書く → ⚠ 閉じる。
#   ⚠ 検査（debug_boot）は `use_path()` で置き場所を差し替える（⚠ 遊んでいる人のセーブを書かない・`GameSettings` と同じ形）。
#     ⚠ 置き場所は Engine のメタ（⚠ static 変数は途中で初期値に戻った＝メモリ「static 変数は途中で戻る」）。

# ⚠ 窓が閉じる直前（⚠ 書く前）。⚠ つなぐ側は**その場で**状態を確定する（⚠ await しない＝待たずに閉じる）。
signal quitting

const SAVE_PATH: String = "user://saves/save_slot_0.json"
const META_PATH: StringName = &"save_manager_path"

var _session_active: bool = false


func _ready() -> void:
	# ⚠ × で即座に閉じない（⚠ 確定と書き込みを済ませてから閉じる）。
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quitting.emit()
		autosave()
		get_tree().quit()


# いまの置き場所。
func save_path() -> String:
	return str(Engine.get_meta(META_PATH, SAVE_PATH))


# 置き場所を差し替える（⚠ 検査用＝遊んでいる人のセーブを書かない）。
func use_path(new_path: String) -> void:
	Engine.set_meta(META_PATH, new_path)


# タイトルで始めた（⚠ 読み込んだ・新しく作った）。⚠ ここから自動で書く。
func begin_session() -> void:
	_session_active = true


# タイトルに戻った。⚠ タイトルにいる間は書かない（⚠ 読む前の状態で上書きしない）。
func end_session() -> void:
	_session_active = false


func is_session_active() -> bool:
	return _session_active


# 自動セーブ（⚠ 遊んでいる最中だけ）。⚠ 書いたら true。
func autosave() -> bool:
	if not _session_active:
		return false
	return save_game()
# 10軸化で character_growth.stats のキーが4本から10本に増えたため2へ。
# さらに character_growth に nodes（解放済みステータスノード）が増え、
# stat_growth_formula が "base" になって stats の意味が変わったため3へ。
# 旧バージョンは読み込まず捨てる（GAME_DESIGN.md 14章）。移行処理は書かない。
const CURRENT_SAVE_VERSION: int = 3

# GameManagerの現在の状態をJSONで保存する。
# 保存前にlast_saved_atを更新すること。
func save_game() -> bool:
	var dir: String = save_path().get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	
	var snapshot: Dictionary = GameManager.get_state()
	var json_text: String = JSON.stringify(snapshot, "\t")
	
	var f: FileAccess = FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] save_game: cannot open %s for writing" % save_path())
		return false
	
	f.store_string(json_text)
	f.close()
	GameManager.mark_saved()
	print("[SaveManager] save_game -> %s" % save_path())
	return true

# セーブがあれば読み込んでGameManagerに反映しtrueを返す。
# セーブが無い／壊れている場合は何もせずfalseを返す。
func load_game() -> bool:
	if not has_save():
		return false
	
	var f: FileAccess = FileAccess.open(save_path(), FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] load_game: cannot open %s" % save_path())
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
	return FileAccess.file_exists(save_path())

# セーブを削除する（テスト・デバッグ用）
func delete_save() -> bool:
	if not has_save():
		return true # べき等性確保
	
	var err: Error = DirAccess.remove_absolute(save_path())
	if err != OK:
		push_error("[SaveManager] delete_save: failed to remove %s (error code: %d)" % [save_path(), err])
		return false
	
	print("[SaveManager] delete_save: success")
	return true
