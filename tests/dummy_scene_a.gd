extends Control

# SceneManager.change_scene_with_data の検証用ダミーシーンA。
# consume_transfer_data() で受け取ったデータをprintし、
# 2回目の呼び出しで空になっていることを確認する。
# その後 Timer で change_scene() を使って DummySceneB へ遷移する。

func _ready() -> void:
	print("[DummySceneA] _ready() — arrived via change_scene_with_data")
	var data: Dictionary = SceneManager.consume_transfer_data()
	print("[DummySceneA] consume_transfer_data() -> %s" % data)
	print("[DummySceneA] consume again (should be empty) -> %s" % SceneManager.consume_transfer_data())
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_go_to_b)
	add_child(timer)
	timer.start()

func _go_to_b() -> void:
	print("[DummySceneA] auto-transitioning to DummySceneB via change_scene()")
	SceneManager.change_scene("res://tests/dummy_scene_b.tscn")
