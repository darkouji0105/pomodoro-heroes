extends Node

# 画面遷移の一元管理。
# 各シーンのスクリプトから get_tree().change_scene_to_file() を直接呼ばせない。

var _transfer_data: Dictionary = {}
var _history: Array[String] = []

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
