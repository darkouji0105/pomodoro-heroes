extends Node

# GameManagerが持つ状態のファイル保存・読込。
# 保存先: user://saves/ （Steamクラウドセーブ対応。GODOT_SETUP.md 6章参照）
# 保存形式・タイミングは未確定（本タスクでは空実装）。

func save_game() -> void:
	print("[SaveManager] save_game() called (dummy)")

func load_game() -> bool:
	# セーブがあればtrueで読み込み、なければfalse
	print("[SaveManager] load_game() called (dummy) -> false")
	return false

func has_save() -> bool:
	print("[SaveManager] has_save() called (dummy) -> false")
	return false
