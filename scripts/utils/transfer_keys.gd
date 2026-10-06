class_name TransferKeys
extends RefCounted

# 画面間データ受け渡し用キー定数。
# SceneManager.change_scene_with_data() で使うキー名を集約する。
# 本タスク時点では空。各画面の実装時に各PLANファイル側で追記していく。

# 未実装画面（placeholder_screen）へ、どの画面のつもりで来たかを渡すためのキー。
# 値には GameStateKeys.SCREEN_* を入れる。
const SCREEN_ID: String = "screen_id"
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

# フロアのどのノードから戦いに来たか（段階14-c）。
# ⚠ 入っていなければ従来どおり stages.json の waves を使う（stage_dbg_* がこちら）。
# ⚠ 戦闘画面はこのIDで「ボスかどうか」を GameManager に聞く。自分で判定しない。
const FLOOR_NODE_ID: String = "floor_node_id"

# 難ダンジョンのどのノードから戦いに来たか（段階17-b・PLAN_HARD_DUNGEON.md §4-4）。
# ⚠ FLOOR_NODE_ID と混ぜないこと。器が別で、スタミナ・クリア記録・画面解放は
#   ダンジョンでは1つも動かない（台帳 §7）。
# ⚠ 入っていれば stages.json は1行も引かない（敵は GameManager が dungeon.json から引く）。
const DUNGEON_NODE_ID: String = "dungeon_node_id"
# ⚠⚠ ショップを出たら次の階へ潜る（2026-09-21・決定48）。
#   ⚠ 「わかれ道の画面」で［さらに潜る］を選んだときだけ true。
#   ⚠⚠ **潜るのはショップを出たあと**。⚠ 先に潜ると `can_retreat_from_dungeon()` が false になり、
#     ⚠ `get_dungeon_shop_entries()` が空を返して**店が消える**。
const DUNGEON_DESCEND_AFTER_SHOP: String = "dungeon_descend_after_shop"

# どちらのランから来たか（2026-09-19・レリック選択を1枚にした）。
# ⚠ 値は GameManager.RUN_KIND_FLOOR ／ RUN_KIND_DUNGEON。
# ⚠ RUN_NODE_ID は踏んだマス（⚠ シナリオのレリックでは使わないが、⚠ 渡し方は揃える）。
# ⚠ 戦闘へは渡さない（⚠ 戦闘は FLOOR_NODE_ID ／ DUNGEON_NODE_ID で枝を分ける）。
const RUN_KIND: String = "run_kind"
const RUN_NODE_ID: String = "run_node_id"

# 通路の宝箱として宝箱の画面へ来たか（段階19-c-2・台帳 §5-3-1）。
# ⚠ true なら DUNGEON_NODE_ID は入っていない（⚠ 通路の宝箱はノードに紐づかない）。
# ⚠ 開けたかの覚え方が別（⚠ ノード＝cleared ／ 通路＝持ち越しの欄）。
const DUNGEON_CORRIDOR_CHEST: String = "dungeon_corridor_chest"

# 倉庫をどのタブで開くか（2026-09-26・回UI-3）。
# ⚠ 値は下の定数（⚠ タブの番号を渡さない＝倉庫のタブの並びを外に漏らさない）。⚠ 無ければ持ち物タブ。
# ⚠ 図鑑タブ（`WAREHOUSE_TAB_CODEX`）は 2026-09-28 に記録の画面へ移して消した。
const WAREHOUSE_TAB: String = "warehouse_tab"

# 設定をどのタブで開くか（2026-09-29・人間「⚠ ポモドーロ設定はポモドーロ画面から開ける」）。⚠ 値は `SettingsScreen.TAB_*`。
#   ⚠ 戻り先は `RETURN_PATH`（⚠ 無ければ本部）。
const SETTINGS_TAB: String = "settings_tab"

# 育成をどのタブで開くか（2026-09-27・回UI-組 育成・人間「⚠ 1い」＝1画面の中でタブを切り替える）。
# ⚠ 値は下の定数（⚠ タブの番号を渡さない）。⚠ 無ければ概要。⚠ 昇級の結果・仮の鍛冶場から戻るときに使う。
const TRAINING_TAB: String = "training_tab"
const TRAINING_TAB_OVERVIEW: String = "overview"
const TRAINING_TAB_NODES: String = "nodes"
const TRAINING_TAB_SKILLS: String = "skills"
const TRAINING_TAB_EQUIP: String = "equip"

# 持ち物のほかのタブ（2026-09-27・回UI-組 持ち物）。⚠ `WAREHOUSE_TAB` の値。⚠ 無ければ装備。
const WAREHOUSE_TAB_EQUIP: String = "equip"
const WAREHOUSE_TAB_PART: String = "part"
const WAREHOUSE_TAB_MATERIAL: String = "material"
# 持ち物を開いたときに選んでおく装備の個体（⚠ 育成の装備タブの「鍛冶場で鍛える」から来る）。
const WAREHOUSE_INSTANCE_ID: String = "warehouse_instance_id"
# 出撃の準備（2026-09-28・`party_preset_screen`＝詰所と同じ画面）で受ける依頼。⚠ どちらも無ければ詰所として開く。
const SORTIE_STAGE_ID: String = "sortie_stage_id"
const SORTIE_DUNGEON_ID: String = "sortie_dungeon_id"
# 鍛冶場を開いたときに選んでおく装備の個体（2026-09-27・人間「⚠ 3あ」＝持ち物・育成の「鍛える」から来る）。
const FORGE_INSTANCE_ID: String = "forge_instance_id"# ⚠ 寄り道から戻ったときに元の姿へ戻すためのもの（2026-10-06・拠点の遷移の見直し・`NAV-18`）。
# 出撃の準備で選んでいた難ダンジョンの入るフロア（⚠ 状態に無い＝画面が持っている）。
const SORTIE_START_FLOOR: String = "sortie_start_floor"
# 掲示板の「すぐ出撃」（⚠ true なら出撃の準備を開いてすぐ「出撃する」と同じ口を通す）。
const SORTIE_AUTO_GO: String = "sortie_auto_go"
# 記録の画面で開いておくタブ（⚠ 値は `RecordsScreen.TAB_*`）。
const RECORDS_TAB: String = "records_tab"
# 依頼掲示板で開いておくタブ（⚠ 値は `AdventureSelect` の `TAB_*`）。
const QUEST_TAB: String = "quest_tab"
# ⚠ 高難度の依頼のタブ（⚠ `AdventureSelect` の `TAB_HARD` と同じ値。⚠ 入手先の窓が使う）。
const QUEST_TAB_HARD: int = 1
# ポモドーロを開いたときに選んでおくタスク（⚠ タスクの画面の「これで集中」）。
const TASK_ID: String = "task_id"
