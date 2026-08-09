# res://tests/base_screen_debug.gd
extends Control

func _ready() -> void:
	print("--- BaseScreen Debug Test ---")
	
	# 拠点画面をインスタンス化して表示
	var base_screen: Control = preload("res://scenes/base/base_screen.tscn").instantiate()
	add_child(base_screen)
	
	# 少し待ってから検証用入力をシミュレート
	await get_tree().create_timer(1.0).timeout
	
	# 項目6: add_gold(100)
	print("Testing Item 6: add_gold(100)")
	GameManager.add_gold(100)
	
	# 項目7: add_material("construction_material", 3)
	print("Testing Item 7: add_material('construction_material', 3)")
	GameManager.add_material("construction_material", 3)
	
	# 項目8: add_material("test_ore", 1)
	print("Testing Item 8: add_material('test_ore', 1)")
	GameManager.add_material("test_ore", 1)
	
	# 項目9: spend_stamina(3)
	print("Testing Item 9: spend_stamina(3)")
	GameManager.spend_stamina(3)
	
	# 項目10: add_pending_chest
	print("Testing Item 10: add_pending_chest")
	GameManager.add_pending_chest({"chest_id": "test_box", "chest_type": "wood"})
	
	print("Debug inputs completed. Verify visuals.")
