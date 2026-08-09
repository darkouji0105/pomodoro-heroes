class_name TransferKeys
extends RefCounted

# 画面間データ受け渡し用キー定数。
# SceneManager.change_scene_with_data() で使うキー名を集約する。
# 本タスク時点では空。各画面の実装時に各PLANファイル側で追記していく。

# 未実装画面（placeholder_screen）へ、どの画面のつもりで来たかを渡すためのキー。
# 値には GameStateKeys.SCREEN_* を入れる。
const SCREEN_ID: String = "screen_id"
const WAREHOUSE_TAB: String = "warehouse_tab"
