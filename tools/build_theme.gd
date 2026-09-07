@tool
extends EditorScript

# main_theme.tres を組み立て直す入口（2026-09-07・ボタンの4階層）。
#
# ⚠ 使い方：⚠ Godot エディタでこのファイルを開き、⚠ 「ファイル → 実行」（Ctrl+Shift+X）。
#
# ⚠⚠ 中身はここに書かない。⚠ 色・寸法・variation 名を持つのは
#   `tools/theme_builder.gd`（`class_name ThemeBuilder`）だけ。
#   ⚠ 理由：⚠ `EditorScript` はエディタでしか `new()` できないため、
#   ⚠ ここに実装を置くとヘッドレスから組み立て直せなくなる（実測・2026-09-07）。
# ⚠ ヘッドレスで同じことをするなら：
#   `res://tests/debug_boot.tscn -- scenario=theme`


func _run() -> void:
	ThemeBuilder.build()
