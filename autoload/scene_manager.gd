extends Node

# 画面遷移の一元管理。
# 各シーンのスクリプトから get_tree().change_scene_to_file() を直接呼ばせない。

var _transfer_data: Dictionary = {}
var _history: Array[String] = []

# ⚠ ここから _spawn_debug_overlay() の終わりまでは検証用。リリース前に消す。
# 消すのはこの _ready() と _spawn_debug_overlay()、それと res://tests/debug_overlay.gd の3つだけ。
#
# 画面を持たない Autoload の中でいちばん「画面の器」に近いのが SceneManager なので、
# ここに置いている。新しい Autoload を足すと project.godot と登録順のルール
# （AGENTS.md「Autoloadの登録順」）を触ることになり、消すときの手数が増える。
const DEBUG_OVERLAY_SCRIPT: GDScript = preload("res://tests/debug_overlay.gd")


func _ready() -> void:
	if not OS.is_debug_build():
		return
	# root の子として足す。current_scene ではなく root に付けるので、
	# change_scene_to_file() で画面が入れ替わってもオーバーレイは残る。
	#
	# call_deferred なのは、Autoload の _ready() の時点では
	# root の構築（メインシーンの追加）がまだ終わっていないため。
	_spawn_debug_overlay.call_deferred()


func _spawn_debug_overlay() -> void:
	# スクリプトが CanvasLayer を継承しているので、.new() で CanvasLayer が返る。
	var overlay: CanvasLayer = DEBUG_OVERLAY_SCRIPT.new()
	overlay.name = "DebugOverlay"
	get_tree().root.add_child(overlay)
	print("[SceneManager] DebugOverlay を生成した（[F4] で表示）")

func change_scene(scene_path: String) -> void:
	print("[SceneManager] change_scene -> %s" % scene_path)
	_record_history()
	get_tree().change_scene_to_file(scene_path)

func go_back() -> void:
	# 履歴管理は最小実装（ダミー扱い。PLANで「実装時に決める」と未確定のため）
	print("[SceneManager] go_back (dummy history)")
	if _history.is_empty():
		print("[SceneManager] no history to go back to")
		return
	var prev: String = _history.pop_back()
	get_tree().change_scene_to_file(prev)

func change_scene_with_data(scene_path: String, data: Dictionary) -> void:
	# _transfer_dataをセットしてからchange_sceneと同様の遷移を行う
	print("[SceneManager] change_scene_with_data -> %s, data=%s" % [scene_path, data])
	_transfer_data = data.duplicate(true)
	_record_history()
	get_tree().change_scene_to_file(scene_path)

func consume_transfer_data() -> Dictionary:
	# 取り出すと同時に_transfer_dataを空にする（次の遷移に前回データが混ざらないようにするため）
	var data: Dictionary = _transfer_data.duplicate(true)
	_transfer_data.clear()
	print("[SceneManager] consume_transfer_data -> %s (now empty: %s)" % [data, _transfer_data])
	return data

func _record_history() -> void:
	var tree: SceneTree = get_tree()
	if tree.current_scene != null:
		var path: String = tree.current_scene.scene_file_path
		if path != "":
			_history.push_back(path)
