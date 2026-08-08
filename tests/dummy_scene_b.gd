extends Control

# SceneManager.change_scene の検証用ダミーシーンB。
# change_scene() 経由で到着したことをprintする（最終到達地点）。

func _ready() -> void:
	print("[DummySceneB] _ready() — arrived via change_scene()")
	print("[DummySceneB] SceneManager transition test complete.")
	# ヘッドレス検証時にプロセスが自動終了するよう、少し待ってからquit
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func() -> void: get_tree().quit())
	add_child(timer)
	timer.start()
