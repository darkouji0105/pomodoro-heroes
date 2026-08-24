class_name TransferKeys
extends RefCounted

# 画面間データ受け渡し用キー定数。
# SceneManager.change_scene_with_data() で使うキー名を集約する。
# 本タスク時点では空。各画面の実装時に各PLANファイル側で追記していく。

# 未実装画面（placeholder_screen）へ、どの画面のつもりで来たかを渡すためのキー。
# 値には GameStateKeys.SCREEN_* を入れる。
const SCREEN_ID: String = "screen_id"
const WAREHOUSE_TAB: String = "warehouse_tab"
const STAGE_ID: String = "stage_id"
const PARTY_ID: String = "party_id"
const STAGE_TYPE: String = "stage_type"

# ポモドーロから拠点へ渡す受け取り数（PLAN_MODAL.md タスク2）
const POMODORO_POTIONS: String = "pomodoro_potions"
const POMODORO_CHESTS: String = "pomodoro_chests"
const CHARACTER_ID: String = "character_id"

# パーティ選択画面から「戻る」で帰る先（EXEC_PARTY_PRESETS.md §7）。
# ⚠ 入口が2つある（冒険選択・拠点）ので、来た側がここにパスを入れる。
#   入っていなければ拠点へ帰る（履歴に依存しない。base_screen.gd と同じ流儀）。
const RETURN_PATH: String = "return_path"
