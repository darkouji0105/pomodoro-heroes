extends Node

# ============================================================
# 検証用の起動口。⚠ シーンは1個だけ。
#
# ⚠ 検証専用。リリース前に消す（NEXT_STEPS §6 の片付け）。
# ⚠ 本番コードから呼ばないこと。scenes/ と autoload/ と scripts/ には1行も足していない。
#
# 使い方（ヘッドレス）：
#   godot --headless --path d:\pomodoro-heroes res://tests/debug_boot.tscn -- scenario=area
#
# ⚠ 引数を付けないとシナリオ名の一覧を出して終わる。
#   既定のシナリオを作らないのは、「どれを見たのか」が後から分からなくなるため
#   （skill_schema の origin に既定値を作らなかったのと同じ理由）。
#
# ⚠ 検証したい形が増えたら SCENARIOS に1行足す。シーンもスクリプトも増やさないこと。
#   増やしたくなったら、それは設計が間違っている合図（tests/ には既にデバッグ用が9件ある）。
# ============================================================

const SCENE_BATTLE: String = "res://scenes/adventure/battle.tscn"
const SCENE_BASE: String = "res://scenes/base/base_screen.tscn"
# ⚠ 装備画面の装飾の枠を出すための下ごしらえ（2026-09-22・`_layout_fill_equipment_parts()`）。
#   ⚠ 品は `items.json` に在るものを使う。⚠ ここで性能を書かない。
const LAYOUT_PART_WEAPON_ID: String = "weapon_iron_sword"
const LAYOUT_PART_ITEM_ID: String = "part_gem_atk_1"

# シナリオの種類。
# ⚠ screen は窓あり専用。ヘッドレスでは描画がダミーなので何も分からない。
const KIND_BATTLE: String = "battle"
const KIND_SCREEN: String = "screen"
# ⚠⚠ 画面を PNG で撮る枝（2026-09-21）。⚠ 窓あり専用。
const KIND_SHOT: String = "shot"
# ⚠ 戦闘も画面も使わず、GameManager を直接叩いて print だけして終わる枝。
#   素材・等級・鍛冶・分解のように「戦闘に1行も出ない」ものは、これが無いと
#   検証の口が無い（EXEC_MATERIAL_TIERS.md §0-2 の8）。
const KIND_REPORT: String = "report"
# ⚠⚠ 画面の本物のボタン・行を押して回る枝（2026-09-27・人間「⚠ それ以外のやつはあなたが確認できると思うがどうか」）。
#   ⚠ 撮影と同じく root に係を置くので、⚠ 画面を移っても続けられる。⚠ ヘッドレスで回せる（⚠ 絵は取らない）。
const KIND_UI_FLOW: String = "ui_flow"
const KIND_CLOSE: String = "close"
# ⚠ 難ダンジョンを自動で潜って数字を取る枝（2026-10-03・回6）。⚠ 係（`DungeonSimRunner`）を root に置く。
const KIND_DUNGEON_SIM: String = "dungeon_sim"

# KIND_REPORT の中でどの報告を出すか。
# ⚠ 枝が増えたら _ready() の match に1行足す。シーンもスクリプトも増やさないこと。
const REPORT_MATERIALS: String = "materials"
const REPORT_PARTS: String = "parts"
const REPORT_DROPS: String = "drops"
const REPORT_PRESETS: String = "presets"
const REPORT_LAYOUT: String = "layout"
const REPORT_GAIN: String = "gain"
const REPORT_UNLOCK: String = "unlock"
const REPORT_RESEARCH: String = "research"
const REPORT_WORKSHOP: String = "workshop"
const REPORT_ECONOMY: String = "economy"
const REPORT_FLOOR: String = "floor"
const REPORT_DUNGEON: String = "dungeon"
const REPORT_INVENTORY: String = "inventory"
const REPORT_GLYPHS: String = "glyphs"
const REPORT_THEME: String = "theme"
const REPORT_SUBWINDOW_DRAG: String = "subwindow_drag"
const REPORT_INVENTORY_WINDOW: String = "inventory_window"
const REPORT_DRAG_CURSOR: String = "drag_cursor"
const REPORT_BASE_CHEST: String = "base_chest"

# ⚠⚠ 画面を撮る（2026-09-21・人間の許可「⚠ その実験もいいよ　画面とる」）。
#
# ⚠⚠ これだけは **`--headless` を付けずに** 回す。⚠ ヘッドレスは描画がダミーで、
#   ⚠ 撮っても中身の無い絵しか出ない（CLAUDE.md「実行環境の制約」）。
# ⚠⚠ 窓が人間の画面に出る。⚠ 最小化したり別の窓で覆ったりすると**描画そのものが止まり**、
#   ⚠ 1枚も撮れない（⚠ 下の「描いた枚数」が増えないまま時間切れになる）。
# ⚠ 出し先は `shot_dir=<パス>` で渡す。⚠ プロジェクトの中に新しいフォルダを作らないための逃げ道
#   （⚠ フォルダの新設は人間の承認が要る＝AGENTS.md）。
const SHOT_DIR_DEFAULT: String = "user://shots"
# ⚠ 撮る前の下ごしらえ。⚠ 増やすなら ShotTaker._prepare() に1行。
const SHOT_PREPARE_NONE: String = ""
const SHOT_PREPARE_DUNGEON: String = "dungeon"
const SHOT_PREPARE_FLOOR: String = "floor"
# ⚠⚠ ボスの先に立たせる（2026-09-22）。⚠ 「わかれ道」「商人」はここでないと開かない
#   （⚠ どちらも `can_retreat_from_dungeon()` で弾く）。
# ⚠ 歩いてボスへ行くのは使えない。⚠ 歩く口はマスを踏むだけで戦闘は画面が起こすので、
#   ⚠ 戦わずにボスを使い切る（CLAUDE.md の罠・2026-09-21）。⚠ だから `phase` を直に書く口を使う。
const SHOT_PREPARE_DUNGEON_BOSS: String = "dungeon_boss"
# ⚠ 装飾の枠を出すための下ごしらえ（2026-09-22・回3）。⚠ 着けて・鍛えて・刺すところまで。
const SHOT_PREPARE_EQUIPMENT: String = "equipment"
# ⚠ 画面を開いたあとに窓を出す手（⚠ 増やすなら ShotTaker._after() に1行）。
# ⚠ 検査の設定ファイル（⚠ 本物の `user://settings.cfg` を書かない・2026-09-28）。
const SETTINGS_TEST_PATH: String = "user://settings_debug_boot.cfg"
const SAVE_TEST_PATH: String = "user://saves/save_debug_boot.json"
const SHOT_AFTER_NONE: String = ""
const SHOT_AFTER_LOOT_OVERLAY: String = "loot_overlay"
const SHOT_AFTER_BATTLE_RESULT: String = "battle_result"
const SHOT_AFTER_MODAL_CONFIRM: String = "modal_confirm"
# ⚠ 昇級申請書で判を押した姿（2026-09-27・回UI-組 育成）。⚠ 画面の口（`_on_press_pressed`）を呼ぶ。
const SHOT_AFTER_LEVEL_UP_PRESS: String = "level_up_press"
const SHOT_AFTER_PART_POPOVER: String = "part_popover"
const SHOT_AFTER_RELIC_PICK: String = "relic_pick"
const SHOT_AFTER_RUN_MENU: String = "run_menu"
const SHOT_AFTER_RELIC_LIST: String = "relic_list"
const SHOT_AFTER_MAP_STEP: String = "map_step"
# ⚠ 届いた宝箱（2026-09-27）。⚠ 内側の `PREPARE_CHESTS` / `AFTER_CHEST_OPEN` と同じ字。
const SHOT_PREPARE_CHESTS: String = "chests"
# ⚠ 帰還報告書（2026-09-29）。⚠ 内側の `PREPARE_REPORT_*` と同じ字。
const SHOT_PREPARE_REPORT_RETURNED: String = "report_returned"
const SHOT_PREPARE_REPORT_DEFEATED: String = "report_defeated"
# ⚠ 潜る深さ（2026-10-03・決定49）：⚠ 最深 3（30層）・ノルマ札1枚で出撃の準備（難ダンジョン）。⚠ 内側の `PREPARE_SORTIE_DEPTH` と同じ字。
const SHOT_PREPARE_SORTIE_DEPTH: String = "sortie_depth"
const SHOT_AFTER_CHEST_OPEN: String = "chest_open"
# ⚠ 鍛冶場で「鍛える」を押した姿（2026-09-27）。⚠ 内側の `AFTER_FORGE_PRESS` と同じ字。
const SHOT_AFTER_FORGE_PRESS: String = "forge_press"
const SHOT_AFTER_FORGE_FAIL: String = "forge_fail"
# ⚠ 出撃の準備（2026-09-28）：⚠ ガイドを「とばす」／ ⚠ 3番の枠を押す。⚠ 内側の同じ名前の字と揃える。
const SHOT_AFTER_GUIDE_SKIP: String = "guide_skip"
const SHOT_AFTER_SORTIE_PICK: String = "sortie_pick"
# ⚠ 出撃の署名を書き終えて「受理」の判が押された姿（2026-09-28・手本 Sign）。⚠ 内側の `AFTER_SORTIE_SIGN` と同じ字。
const SHOT_AFTER_SORTIE_SIGN: String = "sortie_sign"
# ⚠ 設定の「ポモドーロと小窓」タブ（2026-09-28・手本 Settings と同じタブ）。⚠ 内側の `AFTER_SETTINGS_POMODORO` と同じ字。
const SHOT_AFTER_SETTINGS_POMODORO: String = "settings_pomodoro"
const SHOT_AFTER_SETTINGS_AUDIO: String = "settings_audio"
# ⚠ 鍛える演出の画面の途中（2026-09-28・人間「⚠ 別の画面でやる」）。⚠ 内側の `AFTER_FORGE_STRIKE` と同じ字。
const SHOT_AFTER_FORGE_STRIKE: String = "forge_strike"
# ⚠ 記録の図鑑で品を1つ押した姿（2026-09-28・右に詳しく）。⚠ 内側の `AFTER_RECORDS_PICK` と同じ字。
const SHOT_AFTER_RECORDS_PICK: String = "records_pick"
# ⚠ 集中の道具（2026-09-29）：⚠ 柱時計を押した姿 ／ ⚠ 集中を始めて6割進んだ姿。⚠ 内側の同じ名前の字と揃える。
const SHOT_AFTER_FOCUS_TOOLS_CLOCK: String = "focus_tools_clock"
const SHOT_AFTER_POMODORO_RUNNING: String = "pomodoro_running"
const SHOT_AFTER_MINI_ASK: String = "mini_ask"
# ⚠ 10-06（`NAV-19`）：⚠ 鍛冶場で「入手先を見る」を押した姿。⚠ 内側の `AFTER_ITEM_SOURCE` と同じ字。
const SHOT_AFTER_ITEM_SOURCE: String = "item_source"
const SHOT_AFTER_MINI_WINDOW: String = "mini_window"
# ⚠ 10-06：⚠ 小窓のリストを開いた姿（⚠ 小窓の枚と同じ手 ＋ 「リスト」）。
const SHOT_AFTER_MINI_LIST: String = "mini_list"
# ⚠ 10-06：⚠ 小窓のまま振り返り（⚠ 小窓の枚と同じ手 ＋ 「次へ」で集中を終える）。
const SHOT_AFTER_MINI_REFLECTION: String = "mini_reflection"
# ⚠ 装備の特殊効果（2026-10-02）：⚠ いばらの鎧を入れて選んだ持ち物。⚠ 内側の `AFTER_SPECIAL_EFFECT` と同じ字。
const SHOT_AFTER_SPECIAL_EFFECT: String = "special_effect"
# ⚠ 掲示板の「高難度の依頼」タブ（2026-10-02・ノルマ札）。⚠ 内側の `AFTER_BOARD_HARD` と同じ字。
const SHOT_AFTER_BOARD_HARD: String = "board_hard"
# ⚠ ポモドーロの画面の設定の窓（2026-10-02）。⚠ 内側の `AFTER_POMODORO_SETTINGS` と同じ字。
const SHOT_AFTER_POMODORO_SETTINGS: String = "pomodoro_settings"
# ⚠ デバッグの窓を出した姿（2026-10-03・人間「⚠ デバッグ窓はもっとコンパクトに」）。⚠ 内側の `AFTER_DEBUG_OVERLAY` と同じ字。
const SHOT_AFTER_DEBUG_OVERLAY: String = "debug_overlay"
# ⚠ 宝箱の高レアの演出の途中（2026-09-27 の見る回）。⚠ 内側の `AFTER_CHEST_FX` と同じ字。
const SHOT_AFTER_CHEST_FX: String = "chest_fx"
# ⚠ タスクのメモ（2026-10-04・`TK-n`）：⚠ タスクを並べる ／ 終えたものを記録へ移す ／ 詳しくを開く ／ 選ぶ窓 ／ 記録のタブ。⚠ 内側の同じ名前の字と揃える。
const SHOT_PREPARE_TASKS: String = "tasks"
# ⚠ 10-06：⚠ 第1話・第2話を済みにしてフロアを降りた姿（⚠ 札の足が「済・周回・受ける・すぐ出撃」でいちばん混む）。⚠ 内側の `PREPARE_BOARD_CLEARED` と同じ字。
const SHOT_PREPARE_BOARD_CLEARED: String = "board_cleared"
const SHOT_PREPARE_TASK_LOG: String = "task_log"
const SHOT_AFTER_TASK_DETAIL: String = "task_detail"
const SHOT_AFTER_TASK_PICK: String = "task_pick"
const SHOT_AFTER_TASK_LIST: String = "task_list"
const SHOT_AFTER_TASK_DELETE: String = "task_delete"
# ⚠ 10-05（モック4・3）：⚠ 集中を始める前にリストのタスクを選んだ姿 ／ ⚠ 期限のカレンダーを開いた姿。
const SHOT_AFTER_TASK_LINKED: String = "task_linked"
const SHOT_AFTER_TASK_CALENDAR: String = "task_calendar"
# ⚠ 10-05（人間「⚠ 詳しいこともポモドーロ中に決められるように」）：⚠ 集中中にサイドバーの「詳しく」を開いた姿。
const SHOT_AFTER_TASK_DETAIL_RUNNING: String = "task_detail_running"
const SHOT_AFTER_RECORDS_TASKS: String = "records_tasks"

# ⚠ Theme の検証で見る型（2026-09-07）。⚠ 名前は `tools/build_theme.gd` と揃えること。
#   ⚠ 値（色・寸法）はここに書かない。⚠ 「在るか」しか見ない。
const THEME_PATH: String = "res://theme/main_theme.tres"
const MODAL_SCENE_PATH: String = "res://scenes/ui/components/modal_dialog.tscn"
const THEME_BUTTON_TYPES: Array[String] = ["Button", "PrimaryButton", "GhostButton", "DangerButton", "BackButton"]
const THEME_BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
const THEME_BUTTON_COLORS: Array[String] = [
	"font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color",
]
const THEME_CONSTANT_TYPES: Array[String] = [
	"VBoxContainer", "HBoxContainer",
	"TightList", "NodeList", "PanelStack", "SectionGap", "SectionStack", "ButtonRow", "WideRow",
]
const THEME_MARGIN_TYPES: Array[String] = ["MarginContainer", "ScreenMargin", "DialogMargin"]
const THEME_LABEL_TYPES: Array[String] = [
	"Label", "HeadingLabel", "TimerLabel", "ErrorLabel", "GainLabel", "MutedLabel",
]

# 通路の線が横に動いてよい上限（px。段階20-g）。
#
# ⚠⚠ 人間の指摘「⚠ 左から右に行く道がやたら生成される」。⚠ 列を揃えたので
#   「隣の列ぶん」までが正解（⚠ マスの幅104 ＋ 間隔56 ＝ 160）。
# ⚠ 入口（1ノード）から区画の入口3つへ広がるぶんだけは超える（⚠ 仕様）。
#   ⚠ 2列ぶん（320）＋ 端のずらし に少し余裕を見て 380。
# ⚠⚠ 2026-09-27：⚠ マスを列の中でばらけさせた（`RUN-16`・人間「⚠ もっとばらけていい」）。
#   ⚠ 2列ぶんの道でも両端のずれ（± `MAP_NODE_JITTER`）ぶん伸びる＝ 320 ＋ ずれ × 2 ＋ 余裕 10。
#   ⚠ 丸いマスは中心から出る（⚠ 端のずらし＝前の 60 はもう無い）。
const NODE_COLUMN_SPAN_LIMIT: float = 330.0 + 2.0 * float(ThemeBuilder.MAP_NODE_JITTER)

# マップの中心が画面の中心からずれてよい幅（px。決定37・2026-09-19）。
# ⚠ 縦のスクロールバーのぶん（数 px）だけ左へずれるので、⚠ それより少し広く取る。
const MAP_CENTER_TOLERANCE: float = 16.0

# 撃つ前の下ごしらえ。
# ⚠ damage_party は「回復を検証するとき、味方が満タンだと回復量0で何も起きない」を潰すもの
#   （④-a で hp: 9999 に条件を書いて踏んだのと同じ形）。
const PREPARE_NONE: String = ""
const PREPARE_DAMAGE_PARTY: String = "damage_party"
# ⚠ 味方を全滅させる（段階6）。召喚が生きていても敗北するか＝
#   is_party_wiped() に召喚が混ざっていないかを見るためのもの。
# ⚠ この下ごしらえを使う行は "skill": "" にすること。全滅後は撃てる者が
#   居らず、_find_user() が null で赤を出す。
const PREPARE_KILL_PARTY: String = "kill_party"


const SCENARIOS: Dictionary = {
	# 素材の4段階と装備の等級10の検証（EXEC_MATERIAL_TIERS.md §6-A / §6-B）。
	# ⚠ 戦闘を1回も回さない。ここで見るのは GameManager が返す数値だけ。
	"materials": {
		"kind": KIND_REPORT,
		"report": REPORT_MATERIALS,
		"note": "素材16件 / 等級1〜10の鍛冶コストと段階 / 分解の戻り",
	},
	# 装飾（宝石・護符・紋章）の検証（EXEC_DECORATION.md §6-A 〜 §6-C）。
	# ⚠ 装飾は戦闘に1行も出ない（ステータスに乗るだけ）ので、materials と同じ report の枝を使う。
	"parts": {
		"kind": KIND_REPORT,
		"report": REPORT_PARTS,
		"note": "装飾36件 / 部位ごとの種類 / 刺す→加算→外して壊れる / ロールの範囲 / 段階上げ",
	},
	# ステージの抽選ドロップの検証（EXEC_STAGE_DROPS.md §6-A / §6-B）。
	# ⚠ 抽選は戦闘の外（apply_battle_rewards）で起きるので、materials / parts と同じ report の枝を使う。
	"drops": {
		"kind": KIND_REPORT,
		"report": REPORT_DROPS,
		"note": "3ステージの抽選テーブル / 1000回の分布 / 宝箱を積む→開ける→個体になる",
	},
	# 段階9（機能の段階解放）の検証。EXEC_SCREEN_UNLOCK.md §6-A 〜 §6-D。
	# ⚠ 戦闘を回さない。mark_stage_cleared() を直接呼んで解放が進むかだけを見る。
	"unlock": {
		"kind": KIND_REPORT,
		"report": REPORT_UNLOCK,
		"note": "画面の段階解放。最初から3つ / floor_1〜5 で段階的に開く / 一度開いたら閉じない",
	},
	# 段階8（ルーン）の検証。EXEC_RUNES.md §6-A / §6-B。
	# ⚠ ここだけ report の枝では足りない。ルーンは戦闘の挙動そのものを変えるので、
	#   KIND_BATTLE で実際に撃たないと何も分からない。
	# ⚠ ステージは stage_dbg_area を使い回す（シーンもステージも増やさない）。
	"runes": {
		"kind": KIND_BATTLE,
		"note": "ルーン。スキルの直前に シールド/回復/バフ/デバフ/移動 が乗る。CD中は乗らない",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_area_narrow", "skill_dbg_area_wide"],
			"char_debug_life": ["skill_dbg_area_far", "skill_dbg_area_heal"],
		},
		# ⚠ 武器のルーン枠 → スキル1 ／ アクセのルーン枠 → スキル2（GAME_DESIGN 7-5）。
		# ⚠ char_debug_status には1つも刺さない（撃ってもルーンが出ないことの回帰）。
		#
		# ⚠⚠ 2026-09-08：⚠ アクセを **1本**に直した（⚠ 人間の指示「⚠ あくせののルーンは１個で」）。
		#   ⚠ 2026-09-07 に「⚠ アクセのルーン枠を1つに」した時点で、⚠ ここが2本のままになり
		#   ⚠ `scenario=runes` が赤を1本出し続けていた（⚠ 本番コードは正しかった）。
		#   ⚠⚠ 枠は 武器1 ＋ アクセ1 の **計2本**しか無い。⚠ 5種を4枠に入れられないので、
		#   ⚠ シールドを外した（⚠ 5種のうち唯一「⚠ 何も起きないのが正解」の枝で、
		#   ⚠ 外しても読めなくなる出力が無い）。⚠ シールドを見るときは buff と入れ替える。
		"runes": {
			"char_debug_mix": {
				"weapon": ["part_rune_buff_5"],
				"accessory": ["part_rune_move_5"],
			},
			"char_debug_life": {
				"weapon": ["part_rune_heal_5"],
				"accessory": ["part_rune_debuff_5"],
			},
		},
		# ⚠ 既定（choices の先頭）と違う値を選ぶ。後退が効いているか読むため。
		"rune_move": {"char_debug_mix": {"part_rune_move_5": -120}},
		# ⚠ 撃った直後の x を出す（移動のロックを見る唯一の手段）。
		"dump_each_fire": true,
		"fire": [
			{"skill": "skill_dbg_area_narrow", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_far", "prepare": PREPARE_DAMAGE_PARTY, "gap": 2.5},
			{"skill": "skill_dbg_area_wide", "prepare": PREPARE_NONE, "gap": 2.5},
			{"skill": "skill_dbg_area_heal", "prepare": PREPARE_NONE, "gap": 2.5},
			# ⚠ シールドのCDは20秒。ここでは乗らない（スキルだけ出るのが正解）。
			{"skill": "skill_dbg_area_narrow", "prepare": PREPARE_NONE, "gap": 2.5},
		],
	},
	# 段階3の残り（本番キャラのパッシブ）の検証。EXEC_CHARACTER_PASSIVES.md §6-A。
	#
	# ⚠ report の枝では足りない。パッシブは戦闘の数値そのものを変えるうえ、
	#   購読（react）は実際に殴られないと1度も発火しない（ルーンと同じ判断）。
	# ⚠ 本番の味方3人を使う2本目のシナリオ（1本目は lineup）。
	# ⚠ stage_dbg_area を使うのは敵の atk が 1 だから。本番ステージだと
	#   本番の味方が react を見る前に落ちる（lineup と同じ理由）。
	# ⚠ levels を Lv100 にするのは、5件とも付いた状態を見たいから。
	#   途中の段（Lv20/40/60/80）の件数は _apply_levels() が通過時に出す。
	# ⚠ スキルは撃たない（fire は待つだけ）。見たいのはパッシブと react であって
	#   スキルの当たり方ではない。⚠ fire を空配列にしないこと（lineup の注意書き）。
	"passives": {
		"kind": KIND_BATTLE,
		"note": "パッシブ。総ポイント 20/40/60/80/100pt（Lv21/41/61/81/100）で1→5件・条件付き4件・react 2件が発火するか",
		"stage_id": "stage_dbg_area",
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"levels": {
			"char_swordsman": 100,
			"char_archer": 100,
			"char_priest": 100,
		},
		"skills": {},
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			# ⚠ 殴り合うまで待つ。took_damage / dealt_damage はここで初めて出る。
			{"skill": "", "prepare": PREPARE_NONE, "gap": 14.0},
		],
	},
	# 段階4（mode: area）の検証。EXEC_SKILL_AREA.md §6 の数字をそのまま見る。
	"area": {
		"kind": KIND_BATTLE,
		"note": "範囲攻撃。narrow=2体 / wide=4体 / far=4体 / heal=味方3体",
		"stage_id": "stage_dbg_area",
		# ⚠ 浮かぶ数値の件数・大きさ・ずらし（2026-09-18・モック §11）。⚠ 範囲攻撃は同じ瞬間に何件も出る。
		"dump_pops": true,
		# ⚠ 編成は状態が唯一の正。stages.json の party_id では決まらない
		#   （battle_session.gd:19 / battle_controller.gd:176）。
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		# ⚠ スキル枠は2つ（SKILL_SLOT_COUNT=2）。段階4はここの押し忘れで1回ぶん溶けている。
		"skills": {
			"char_debug_mix": ["skill_dbg_area_narrow", "skill_dbg_area_wide"],
			"char_debug_life": ["skill_dbg_area_far", "skill_dbg_area_heal"],
		},
		# ⚠ 撃つ順。1つずつ間を空ける（同じ t に重なると、巻き込んだ数を
		#   「同じ t の damage の行数」で数えられなくなる）。
		"fire": [
			{"skill": "skill_dbg_area_narrow", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_wide", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_far", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_heal", "prepare": PREPARE_DAMAGE_PARTY},
		],
	},
	# ⚠⚠ 中央のチャージバー（2026-09-17）。⚠ 本番の3人で、剣士の薙ぎ払い（charge）を
	#   ⚠ 1回目は窓の手前（0.5秒）、2回目はジャスト（1.0秒）、3回目は行き過ぎ（1.6秒）で離す。
	#   ⚠ 見るもの：押している間だけ表示=true ／ 行が1本 ／ 帯=true はジャストのときだけ ／ 離すと表示=false。
	"charge": {
		"kind": KIND_BATTLE,
		"note": "中央のチャージバー。薙ぎ払いを 0.5 / 1.0 / 1.6 秒溜めて離す",
		"stage_id": "stage_dbg_area",
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"skills": {
			"char_swordsman": ["skill_power_slash", "skill_wide_sweep"],
		},
		"fire": [
			{"skill": "skill_wide_sweep", "prepare": PREPARE_NONE, "hold_sec": 0.5},
			{"skill": "skill_wide_sweep", "prepare": PREPARE_NONE, "hold_sec": 1.0},
			{"skill": "skill_wide_sweep", "prepare": PREPARE_NONE, "hold_sec": 1.6},
		],
	},
	# ⚠⚠ 敵の行動予告の SP（2026-09-18・人間の決定「敵に SP を付けて、それが溜まったら」）。
	#   ⚠ `stage_dbg_area` の敵は `enemy_dbg_ranged`（100 / 10）と `enemy_wolf`（100 / 12）。
	#   ⚠⚠ 2026-09-18 に**雑魚にもスキルを持たせた**（人間「雑魚にもスキルを持たせる」）ので、狼も SP を持つ。
	#   ⚠ 見るもの：⚠ 両方ゲージが出る ／ ⚠ 狼は約8.3秒・ranged は10秒で満ちる ／ ⚠ 満ちたら撃って 0 に戻る。
	#   ⚠ スキルは撃たない（⚠ 見たいのは敵側）。⚠ fire を空配列にしないこと。
	"enemy_sp": {
		"kind": KIND_BATTLE,
		"note": "敵の行動予告。SP が満ちて撃つ（ranged 10秒・狼 約8.3秒）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {},
		"dump_enemy_sp": true,
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 14.0},
		],
	},
	# ⚠⚠ ボスの行動予告（2026-09-18・人間の指示「とりあえずスライムキングに、強力な全体攻撃を」）。
	#   ⚠ ボスが出るのは**難ダンジョンのボスのマス**（⚠ ステージ直行では出せない）。
	#   ⚠ 2本目（ボス戦）で SP が満ちるまで待つ：⚠ ボスは 100 / 8 ＝ 12.5秒。
	#   ⚠ 見るもの：⚠ ボスにゲージが出る ／ ⚠ 12.5秒で満ちて「粘液の大波」を撃つ ／ ⚠ 撃つと 0 に戻る。
	"boss_sp": {
		"kind": KIND_BATTLE,
		"note": "ボスの行動予告。スライムキングの SP が満ちて全体攻撃を撃つ",
		"dungeon": true,
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"skills": {},
		"dump_enemy_sp": true,
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 16.0},
		],
	},
	# ⚠⚠ 戦闘の結果窓（2026-09-17・§0-UI-G）。⚠ 本番の3人で殴り合ってから決着させる（⚠ 被ダメージを0にしないため）。
	#   ⚠ 見るもの：題・見出し・副題（時間と被ダメージ）・注記（検証用は報酬なし）・ボタン（拠点へ＋次へ進む）・窓の中心 640,360。
	#   ⚠ そのあと見本の報酬（floor_5 のボス）で差し替え：マス9件（列6）・ピル gold +65。
	"result": {
		"kind": KIND_BATTLE,
		"note": "結果窓（勝ち）。本物の窓 → 見本の報酬（floor_5）で差し替え。⚠ スキルのマスのホバーの枠も見る",
		"stage_id": "stage_dbg_area",
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"skills": {},
		"dump_result": true,
		# ⚠ スキルのマスのホバーの枠（2026-09-18）。⚠ 本番の3人なので説明文（ui_desc_*）がある。
		"dump_tooltip": true,
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 6.0},
		],
	},
	# ⚠ 負け（全滅）。⚠ 見るもの：題が敗北・見出しが負けの色・ボタン（拠点へ＋もう一度）。
	"result_defeat": {
		"kind": KIND_BATTLE,
		"note": "結果窓（負け）。味方を全滅させる",
		"stage_id": "stage_dbg_area",
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"skills": {},
		"dump_result": true,
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "", "prepare": PREPARE_KILL_PARTY, "gap": 3.0},
		],
	},
	# 段階5（phases[] / recast）の検証。⚠ ステージは stage_dbg_area を使い回す。
	# ⚠ 同じ skill を2行書くと2回撃つ（_fired はインデックスなので既にそうなっている）。
	#   足りなかったのは間隔の上書きだけ（既定の FIRE_GAP_SEC=1.0 は窓より長くなりうる）。
	"recast": {
		"kind": KIND_BATTLE,
		"note": "再発動。2段とも撃つ（phase 0 → 1。ダメージが 0.5倍 → 2.0倍 に変わる）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_recast_two", "skill_dbg_area_wide"],
		},
		"fire": [
			{"skill": "skill_dbg_recast_two", "prepare": PREPARE_NONE},
			# ⚠ window_sec は 3.0。0.5 秒後に撃てば窓の中に収まる。
			{"skill": "skill_dbg_recast_two", "prepare": PREPARE_NONE, "gap": 0.5},
		],
	},
	# ⚠ 窓切れ（人間の決定：そのまま終わる）の検証。1段目しか撃たない。
	"recast_expire": {
		"kind": KIND_BATTLE,
		"note": "再発動を1段目だけ撃ち、window_sec を過ぎるまで待つ（expire が出るか）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_recast_two", "skill_dbg_area_wide"],
		},
		# ⚠ 2行目は「撃たずに待つ」ための行。撃ち終わると決着させてしまうので、
		#   window_sec（3.0）を過ぎるまで別のスキルで時間を使う。
		"fire": [
			{"skill": "skill_dbg_recast_two", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_area_wide", "prepare": PREPARE_NONE, "gap": 4.0},
		],
	},
	# 段階6（spawn）の検証。⚠ ステージは stage_dbg_area を使い回す。
	# ⚠ 召喚は summon_units（専用配列）に入るので、勝敗判定には最初から混ざらない。
	#   ここで見るのは「座標の規則」「期限で消える」「召喚自身のステータスで殴る」の3つ。
	"summon": {
		"kind": KIND_BATTLE,
		"note": "召喚。2体が召喚者の x−60 / x−120 に出て、4.0秒で消える（damage は召喚の atk=50）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_summon", "skill_dbg_area_wide"],
			# ⚠ 回復は「召喚が味方の母集団（get_alive_units）に入っているか」を
			#   ログで見るためだけに入れてある。後衛の召喚は味方より後ろに立つので、
			#   敵の nearest には選ばれず、狙われる側からは検証できない。
			"char_debug_life": ["skill_dbg_area_far", "skill_dbg_area_heal"],
		},
		"fire": [
			{"skill": "skill_dbg_summon", "prepare": PREPARE_NONE},
			# ⚠ 召喚が生きているあいだに撃つこと（duration_sec は 4.0）。
			{"skill": "skill_dbg_area_heal", "prepare": PREPARE_DAMAGE_PARTY, "gap": 0.5},
			# ⚠ duration_sec を跨いで待たないと expire が出ないまま決着する。
			{"skill": "skill_dbg_area_wide", "prepare": PREPARE_NONE, "gap": 6.0},
		],
	},
	# ⚠ 召喚は頭数に入らない（人間の決定）の検証。味方だけ全滅させる。
	# ⚠ 混ざっていると決着せず、GIVE_UP_SEC の赤が出る（無音で通らない）。
	"summon_wipe": {
		"kind": KIND_BATTLE,
		"note": "召喚を出してから味方を全滅させる。召喚が生きていても敗北すること",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_summon", "skill_dbg_area_wide"],
		},
		"fire": [
			{"skill": "skill_dbg_summon", "prepare": PREPARE_NONE},
			# ⚠ 撃たない行（下ごしらえだけ）。skill を空にすること。
			{"skill": "", "prepare": PREPARE_KILL_PARTY, "gap": 0.5},
		],
	},
	# ダメージの介入点（EXEC_SKILL_MITIGATION.md）。⚠ 3本に分けてある。
	#
	# ⚠ 分けている理由：スキル枠は2つ（SKILL_SLOT_COUNT）。1体につき
	#   「介入を付ける」＋「殴る」で2枠を使い切るので、1シナリオに3件しか載らない。
	# ⚠ もう1つ。敵に付ける介入（軽減・盾・反射）が同じ敵に重なると、
	#   どれが効いた数値なのか読めなくなる。1シナリオに「敵へ付ける介入」は
	#   1種類までにしてある（shield だけは盾を吸い切ってから棘を付けるので2件）。
	#
	# ⚠ 数値の作り方：char_debug_* は atk 1。multiplier 200 の確定ダメージで
	#   ぴったり 200 になる（BattleFormula.damage は power * multiplier）。
	#   200 を基準にすると、軽減40%→120 / 会心150%→300 が整数で出て読める。
	# ⚠ 敵の hp は 400。1体に 400 を超えて当てると死んで、次の一撃が別の敵に飛ぶ。
	#   実測で踏んだ：貫通の「素 → 貫通あり」を同じシナリオに入れたら、素の一撃で
	#   敵が死に、貫通ありの一撃が別の敵（軽減が付いていない敵）に当たって
	#   「116 → 200」という、貫通と軽減が混ざった数字になった。
	# ⚠ 「敵に付ける介入 × 前後の比較」は1シナリオに1件まで。
	"mitigate": {
		"kind": KIND_BATTLE,
		"note": "介入点：軽減40%（200→120）と確定会心（200→300）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_hit_true", "skill_dbg_mit_reduce"],
			"char_debug_status": ["skill_dbg_hit_true_b", "skill_dbg_mit_crit"],
		},
		# ⚠ 必ず「素で殴る → 介入を付ける → もう一度殴る」の順。同じ撃ち手・同じ
		#   スキルで前後を比べないと、対象が変わったのか介入が効いたのか分からない。
		# ⚠ 会心を先、軽減をあと。実測で踏んだ：軽減を先にすると、会心の
		#   「素の一撃」が軽減の付いた敵に当たって 200 ではなく 120 になり、
		#   120 → 300 という「軽減が外れたのか会心が効いたのか読めない」比較になる。
		# ⚠ 会心（200 + 300 = 500）は敵1体（hp 400）を殺すので、そのあとの軽減の
		#   比較は無傷の敵で始まる。確定会心は自分に付ける介入なので、対象が
		#   変わっても数字は動かない（確定ダメージなので敵の def を見ない）。
		"fire": [
			{"skill": "skill_dbg_hit_true_b", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_mit_crit", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true_b", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_mit_reduce", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
		],
	},
	# ⚠ 貫通だけ単独。物理で殴らないと def を無視したことが数字に出ないので、
	#   「def を持つ敵に、同じ敵へ2回」当てる必要がある（合計 394 で 400 未満）。
	# ⚠ 狼の def は 3。194（素）→ 200（貫通100%）＝ 確定ダメージと同じ値になる。
	"pierce": {
		"kind": KIND_BATTLE,
		"note": "介入点：貫通100%（物理 194 → 200。敵の def 3 を無視する）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_life": ["skill_dbg_hit_phys", "skill_dbg_mit_pierce"],
		},
		"fire": [
			{"skill": "skill_dbg_hit_phys", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_mit_pierce", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_phys", "prepare": PREPARE_NONE},
		],
	},
	# ⚠ 盾。吸う → 吸い切って消える → 素に戻る、の3段を1本で見る。
	# ⚠ 棘（盾＋固定値の反射）は、盾が全部吸っても固定値が返ることを見るためのもの
	#   （人間の決定4）。弱打（multiplier 1 ＝ ダメージ1）で殴る。
	"shield": {
		"kind": KIND_BATTLE,
		"note": "介入点：盾30が吸う→吸い切って消える→素に戻る／棘は盾ごしに固定値を返す",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_hit_true", "skill_dbg_mit_shield"],
			"char_debug_status": ["skill_dbg_hit_weak", "skill_dbg_mit_thorns"],
		},
		"fire": [
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_mit_shield", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_mit_thorns", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_weak", "prepare": PREPARE_NONE},
		],
	},
	# ⚠ 反射（%）。⚠ 単独のシナリオにしてある。盾と同じ敵に乗ると、
	#   返ってきた量が「盾で減ったあとの50%」なのか「棘の固定値」なのか読めない。
	"reflect": {
		"kind": KIND_BATTLE,
		"note": "介入点：反射50%（殴った側に返る。反射が反射を呼ばないこと）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_life": ["skill_dbg_hit_true_c", "skill_dbg_mit_reflect"],
			# ⚠ DoT は反射しないこと（人間が見ていない決め4）を見るために入れてある。
			#   毒を「殴り返す」相手が居ない（source は付けた本人で、その場に居るとは限らない）。
			"char_debug_status": ["skill_dbg_dot_long", ""],
		},
		# ⚠ 素で殴る（反射なし）→ 反射を付ける → 毒を入れる → もう一度殴る、の順。
		#   毒は反射の付いた敵に入り、周期ダメージのあいだ反射が1本も出ないことを見る。
		# ⚠ 2発（200+200=400）で敵の hp とちょうど同じ。最後の一撃で死ぬが、
		#   反射はその一撃で返ってから死ぬ。
		"fire": [
			{"skill": "skill_dbg_hit_true_c", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_mit_reflect", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_dot_long", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true_c", "prepare": PREPARE_NONE, "gap": 3.0},
		],
	},
	# ⚠ 攻撃力の倍率（EXEC_SILENT_HOLES.md）。空だった受け口 atk_multiplier を使う。
	#
	# ⚠ +100%（2倍）にしてある。倍率は元の値に比例するので、大きくすると damage が
	#   万を超えて読みにくい。200 → 400 なら桁が変わらず読める。
	"atk_mult": {
		"kind": KIND_BATTLE,
		"note": "攻撃力の倍率：素 200 → +100% で 400 → 切れて 200 に戻る",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_hit_true", "skill_dbg_atk_mult"],
		},
		# ⚠ 素で殴る → 倍率を付ける → もう一度殴る → 切れるまで待って もう一度殴る。
		# ⚠ duration_sec は 6.0。3発目は 6 秒を跨いでから撃つ。
		"fire": [
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_atk_mult", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE, "gap": 7.0},
		],
	},
	# ⚠ 毒のダメージで購読（react）が発火するか（EXEC_SILENT_HOLES.md）。
	#
	# ⚠ 実測で踏んだ：初稿は skill_dbg_mit_reflect（介入点の反射）で試したが、
	#   ⚠ あれは購読ではない。intervene の反射は _apply_damage の中で処理され、
	#   しかも DoT では意図的に返さない設計なので、⚠ 宿題の経路を1ミリも通らない。
	#   ⚠ 「反射」という言葉が2つの別の器を指していることに注意。
	# ⚠ 購読は「毒を受ける本人」に付いていないと発火しない。
	#   → char_debug_mix に skill_dbg_react_thorns（took_damage の購読）と
	#     自分がけの毒の両方を持たせる。⚠ スキルはキャラに紐づくので他キャラのは使えない。
	"dot_react": {
		"kind": KIND_BATTLE,
		"note": "毒の周期ダメージで購読（react）が発火すること。⚠ 連鎖しないこと",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_react_thorns", "skill_dbg_dot_self_mix"],
		},
		# ⚠ 購読を先に付ける。あとだと最初の数発が拾われない。
		"fire": [
			{"skill": "skill_dbg_react_thorns", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_dot_self_mix", "prepare": PREPARE_NONE},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 7.0},
		],
	},
	# ⚠ オーラ（host: point の条件・EXEC_SKILL_AURA.md）。
	#
	# ⚠ 数字の作り方：char_debug_* の atk は 1。オーラで atk+50 にすると、
	#   確定ダメージ multiplier 200 のスキルが 200 → 10200 になる。桁が違うので
	#   「中に居たか」が damage の1行で読める。
	# ⚠ 半径 150 で、味方は 60 / 180 / 300 の段に散っている（前々回）。付与者
	#   （char_debug_mix・後衛）を中心にすると、中衛までが入り前衛は入らない。
	"aura": {
		"kind": KIND_BATTLE,
		"note": "オーラ（固定・味方だけ・atk+50）。中に居る味方だけ数字が変わること",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_aura_atk", "skill_dbg_hit_true"],
			"char_debug_status": ["skill_dbg_hit_true_b", ""],
		},
		# ⚠ 素で殴る → オーラを置く → もう一度殴る。⚠ 撃ち手を変えないこと。
		# ⚠ 4行目でもう一度オーラを置く（重ねがけの置き換え）。人間のプレイのログで
		#   「置き換えたときに leave が出ない」を踏んだので、ここで毎回見る。
		"fire": [
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_aura_atk", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_aura_atk", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_hit_true_b", "prepare": PREPARE_NONE},
		],
	},
	# ⚠ 追従。⚠ 半径 80 と狭くしてある。付与者が歩くと中の顔ぶれが変わる。
	"aura_follow": {
		"kind": KIND_BATTLE,
		"note": "追従オーラ。付与者が歩くと enter / leave が出直すこと",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			# ⚠ 前衛（射程60）に持たせ、team: enemy にしてある。実測で踏んだ：
			#   味方に効くオーラを味方に持たせると、隊列ごと歩くので相対距離が
			#   変わらず、enter が1件も増えない（＝追従を証明できない）。
			#   敵は先に止まるので、enter が出たら「中心が動いた」以外に説明が付かない。
			"char_debug_status": ["skill_dbg_aura_follow", ""],
		},
		# ⚠ 置いたあとに待つ行で、前衛が歩く時間を作る。
		"fire": [
			{"skill": "skill_dbg_aura_follow", "prepare": PREPARE_NONE},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 10.0},
		],
	},
	# ⚠ 毒沼と回復地帯。⚠ 周期の効果が「範囲内の全員」に当たること。
	"pool": {
		"kind": KIND_BATTLE,
		"note": "毒沼（敵だけ・周期ダメージ）と回復地帯（味方だけ・周期回復）",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_life": ["skill_dbg_pool_dmg", "skill_dbg_pool_heal"],
		},
		# ⚠ 回復地帯は味方が満タンだと 0 になって何も出ない。先に削る。
		# ⚠ 最後の待ちは duration_sec（6.0）より長く取る。寿命切れで zone の leave が
		#   出ることを見るため（人間のプレイのログで「enter だけ出て leave が出ない」を
		#   踏んだ箇所）。⚠ 短いと戦闘が先に終わって、消えたのか終わったのか分からない。
		"fire": [
			{"skill": "skill_dbg_pool_dmg", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_pool_heal", "prepare": PREPARE_DAMAGE_PARTY},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 9.0},
		],
	},
	# ⚠ 反射を「画面で見られる形」にしたもの（人間の指摘・2026-08-21）。
	#
	# ⚠ これが要る理由：reflect シナリオは反射を敵に付けるので、画面では
	#   「味方が殴ったら味方が減る」という読みにくい絵になる。⚠ 人間からは
	#   「反射を持っているキャラが前衛じゃないので分からない」と言われた。
	#   ⚠ 段階6で召喚に対して踏んだのと同じ形（後衛に付けた効果は画面で確かめられない）。
	# ⚠ char_debug_status は射程 60 ＝ 前衛。敵の nearest に選ばれるのはこの1体だけなので、
	#   自分に反射を付けると「敵が殴ってくる → 敵の頭上に数字が出る」が見える。
	# ⚠ 味方の hp は 9999・敵の atk は 1 なので、% だけだと 0 になって何も返らない。
	#   固定値 5 を併せて持たせてある。
	"reflect_self": {
		"kind": KIND_BATTLE,
		"note": "反射：前衛の味方に自分がけの反射を付け、殴ってきた敵に返ること",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_status": ["skill_dbg_mit_reflect_self", ""],
		},
		# ⚠ 最後の「待つだけの行」で、敵が殴ってくる時間を作る。
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "skill_dbg_mit_reflect_self", "prepare": PREPARE_NONE, "gap": 6.0},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 8.0},
		],
	},
	# ⚠ 移設した既存3件（復活 / 免疫 / 被回復低下）が実行時にも効くことの確認。
	#
	# ⚠ これが要る理由：intervene{} へ畳んだ3件は stage_dbg_intervene にしか居らず、
	#   既存のシナリオはどれも stage_dbg_area しか見ていない。ロード時検証が通っても
	#   「読む側（status_registry）が新しい入れ子から読めているか」は分からない。
	#   移設で一番怖いのは「無音で効かなくなる」ことなので、実行時に1回通す。
	# ⚠ ウェーブ1が復活持ち、ウェーブ2が免疫持ち。
	"intervene_legacy": {
		"kind": KIND_BATTLE,
		"note": "移設した既存3件：復活（death）と免疫（status）が intervene{} からでも効くこと",
		"stage_id": "stage_dbg_intervene",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_hit_true", "skill_dbg_mit_reduce"],
			"char_debug_status": ["skill_dbg_dot_long", "skill_dbg_hit_true_b"],
		},
		# ⚠ 待つだけの行を先頭に置く（1行目の gap は _last_fire_sec の初期値 -999 の
		#   せいで効かない）。⚠ 実測で踏んだ：待たずに撃つと、敵が自分に復活バフを
		#   掛ける前に殺してしまい、intervene が1行も出ないまま「通った」ように見える。
		#   復活も免疫も、敵AIが射程内に入って拍が来たときに自分へ撃つ instant スキル。
		# ⚠ 200 の確定ダメージで一撃で殺す（復活持ちは hp 60）。復活したらもう一度殺す。
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE, "gap": 6.0},
			{"skill": "skill_dbg_hit_true", "prepare": PREPARE_NONE, "gap": 0.6},
			{"skill": "skill_dbg_dot_long", "prepare": PREPARE_NONE, "gap": 6.0},
		],
	},
	# 立ち位置（射程の段）の検証。⚠ 本番の味方3人を並べるのはこのシナリオだけ。
	#
	# ⚠ スキルを1つも割り当てない。見たいのは「歩くのをやめたときの x」だけ。
	# ⚠ fire を空配列にしないこと。空だと _fired(0) >= size(0) が最初のフレームで
	#   成立し、合図を待たずに敵を全滅させる（_process() の最後の枝）。位置が1回も出ない。
	# ⚠ stage_dbg_area を使うのは敵の atk が 1 だから。本番ステージだと本番の味方
	#   （hp 70〜120）が位置を見る前に死ぬ。
	"lineup": {
		"kind": KIND_BATTLE,
		"note": "立ち位置。本番の味方3人が射程の段（60/180/300）で散るか",
		"stage_id": "stage_dbg_area",
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"skills": {},
		# ⚠ 待つだけの行を2つ書く。1行目の gap は効かない（_last_fire_sec の初期値が
		#   -999 なので、どんな gap でも最初のフレームで通ってしまう）。⚠ 実際に待つのは
		#   2行目。剣士（射程 60・spd 60）は敵が止まってからさらに 6 秒ほど歩くため、
		#   短いと止まる前に決着させてしまう（実測：t=5.80 で決着し、x=547.6 の途中だった）。
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			{"skill": "", "prepare": PREPARE_NONE, "gap": 14.0},
		],
	},
	# 状態のUI（EXEC_STATUS_UI.md）。⚠ ヘッドレスは絵を出さない。
	#   ここで取れるのは「その瞬間に何が何件乗っていたか」だけで、色と漢字は人間が見る。
	#
	# ⚠ 見たいのは色の分岐3本が全部通ること。dot(ダメージ)＝赤 / dot(回復)＝緑 /
	#   buff と react＝青。⚠ 4種類が同じ瞬間に乗っている必要がある。
	# ⚠ 敵に付ける効果を混ぜない（前後の比較をしないので1件までの制約には触れないが、
	#   敵が死ぬと決着して状態が出揃う前に終わる）。全部味方に乗せる。
	"status_ui": {
		"kind": KIND_BATTLE,
		"note": "状態のマス。buff / dot(ダメージ) / dot(回復) / react の4種類が同時に乗るか",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			# ⚠ react と dot を同じ人に乗せる（1人の帯に2色並ぶことを見る）。
			"char_debug_mix": ["skill_dbg_react_thorns", "skill_dbg_dot_self_mix"],
			# ⚠ pool_heal は host: point・team: ally・radius 400。味方3人（x=200/300/400）が
			#   全員入るので、緑のマスが3人に出る。
			"char_debug_life": ["skill_dbg_pool_heal", "skill_dbg_buff_short"],
			"char_debug_status": ["skill_dbg_buff_stack", "skill_dbg_buff_refresh"],
		},
		# ⚠ 寿命の短い順に後から撃つ。react は 15秒・dot_self_mix は 6秒・
		#   pool_heal は 6秒・buff_stack は 20秒なので、最後の1発の時点で全部生きている。
		"fire": [
			{"skill": "skill_dbg_react_thorns", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_buff_stack", "prepare": PREPARE_NONE, "gap": 0.5},
			{"skill": "skill_dbg_dot_self_mix", "prepare": PREPARE_NONE, "gap": 0.5},
			{"skill": "skill_dbg_pool_heal", "prepare": PREPARE_NONE, "gap": 0.5},
		],
	},
	# ⚠⚠ チップの区分け（2026-09-17・人間「ツートンで決める」）。⚠ 撃ち終わった瞬間に、
	#   ⚠ 全ユニットの状態を1件ずつ `StatusChips.tone_of()` に通して出す。
	#   ⚠ 期待：盾付与（シールドだけ）＝HIDDEN ／ 棘の盾（シールド＋反射）＝BUFF ／ とげの鎧（react）＝BUFF ／
	#     ⚠ 防御デバフ（value -50・敵）＝DEBUFF ／ 単発DoT（敵）＝DEBUFF ／ 回復地帯＝BUFF。
	#   ⚠ 復活はこの編成で付けられないので、⚠ 器と同じ形の見本で REVIVE を見る。
	"status_tone": {
		"kind": KIND_BATTLE,
		"note": "状態のチップの区分け。シールドだけ=出さない / 反射・react・回復=青 / デバフ・毒=赤 / 復活=黄",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_mix": ["skill_dbg_mit_shield", "skill_dbg_react_thorns"],
			"char_debug_life": ["skill_dbg_dot_once", "skill_dbg_pool_heal"],
			"char_debug_status": ["skill_dbg_debuff_def", "skill_dbg_mit_thorns"],
		},
		"dump_status_tones": true,
		"fire": [
			{"skill": "skill_dbg_mit_shield", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_react_thorns", "prepare": PREPARE_NONE, "gap": 0.3},
			{"skill": "skill_dbg_mit_thorns", "prepare": PREPARE_NONE, "gap": 0.3},
			{"skill": "skill_dbg_debuff_def", "prepare": PREPARE_NONE, "gap": 0.3},
			{"skill": "skill_dbg_dot_once", "prepare": PREPARE_NONE, "gap": 0.3},
			{"skill": "skill_dbg_pool_heal", "prepare": PREPARE_NONE, "gap": 0.3},
		],
	},
	# ⚠ 件数でマスの大きさが変わること（人間の指示・2026-08-22）の検証。
	#   1人に7件乗せる。⚠ 「6個まで」のような決め打ちが残っていたら、ここで気づける。
	# ⚠ ヘッドレスで取れるのは件数だけ。大きさが変わったかは人間が見る（§7-17）。
	"status_ui_over": {
		"kind": KIND_BATTLE,
		"note": "状態のマス。1人に7件（buff_stack×5 ＋ refresh ＋ 回復地帯）乗ること",
		"stage_id": "stage_dbg_area",
		"party": ["char_debug_mix", "char_debug_life", "char_debug_status"],
		"skills": {
			"char_debug_status": ["skill_dbg_buff_stack", "skill_dbg_buff_refresh"],
			"char_debug_life": ["skill_dbg_pool_heal", "skill_dbg_buff_short"],
		},
		# ⚠ buff_stack は independent・max_stack 5・CD 1.0。gap を CD より短くすると
		#   撃てずに黙って飛ぶので、1.0 以上にすること。duration は 20 秒なので全部残る。
		"fire": [
			{"skill": "skill_dbg_buff_stack", "prepare": PREPARE_NONE},
			{"skill": "skill_dbg_buff_stack", "prepare": PREPARE_NONE, "gap": 1.1},
			{"skill": "skill_dbg_buff_stack", "prepare": PREPARE_NONE, "gap": 1.1},
			{"skill": "skill_dbg_buff_stack", "prepare": PREPARE_NONE, "gap": 1.1},
			{"skill": "skill_dbg_buff_stack", "prepare": PREPARE_NONE, "gap": 1.1},
			{"skill": "skill_dbg_buff_refresh", "prepare": PREPARE_NONE, "gap": 1.1},
			{"skill": "skill_dbg_pool_heal", "prepare": PREPARE_NONE, "gap": 0.5},
		],
	},
	# プリセット2階層の検証（EXEC_PARTY_PRESETS.md §9）。
	# ⚠ プリセットは戦闘に1行も出ない（適用した結果が戦闘に出るだけ）ので、
	#   materials / parts / drops と同じ report の枝を使う。
	"presets": {
		"kind": KIND_REPORT,
		"report": REPORT_PRESETS,
		"note": "プリセット2階層 / 焼く→適用 / 空の参照先を保存が焼く / 装備に触らない / 正規化",
	},
	# 拠点の下段が横にはみ出していないかを数字で見る。
	#
	# ⚠ ヘッドレスでも「レイアウトの計算」は走る（描画がダミーなだけ）。
	#   ⚠ 絵は取れないが、最小幅が画面幅を超えているかは取れる。
	# ⚠ 横に溢れる事故を2回踏んでいる（素材12件で HBoxContainer が溢れた／
	#   拠点のナビに6個目を足して押し潰した）。⚠ 3回目を数字で止めるための道具。
	"layout": {
		"kind": KIND_REPORT,
		"report": REPORT_LAYOUT,
		"note": "拠点の下段の最小幅を測る（画面幅を超えていないか）",
	},
	# ⚠⚠ リソースが増えたときの演出（2026-09-09・人間のモック「採用版」）。
	#   ⚠ 絵は取れないが「⚠ 何個飛ばしたか ／ ⚠ 着地先を見つけたか ／ ⚠ 数字が回ったか」は取れる。
	#   ⚠ 個数は増える量で変わるので、⚠ 表そのものが合っているかをここで見る。
	"gain": {
		"kind": KIND_REPORT,
		"report": REPORT_GAIN,
		"note": "増える量→飛ぶ個数の表 / 着地先を探せるか / 数字が回って増えるか",
	},
	# ⚠⚠ Theme を組み立て直して、⚠ 欠けが無いかを見る（2026-09-07・ボタンの4階層）。
	#
	# ⚠ `tools/build_theme.gd` は EditorScript だが、⚠ `_run()` は
	#   ResourceLoader / ResourceSaver しか触らないので、⚠ ここから直接呼べる
	#   （⚠ ヘッドレスでもエディタのバイナリなので EditorScript の型は在る）。
	# ⚠ ＝⚠ 人間がエディタで「実行」しなくても、⚠ 設計役が `.tres` を作り直せる。
	# ⚠ 見た目そのものは取れない（⚠ 色の値が入っているかまで）。⚠ 絵は人間が見る。
	"theme": {
		"kind": KIND_REPORT,
		"report": REPORT_THEME,
		"note": "Theme を組み立て直す。ボタン4階層 × 5状態 / 間隔 / 余白 / 見出しの欠けを見る",
	},
	# 段階10（研究ボードの作り替え）の検証。EXEC_GUILD_RESEARCH_V2.md §7-1。
	#
	# ⚠ 戦闘を回さない。研究は「レベル上限」と「宝箱の抽選回数」に化けるだけで、
	#   戦闘のログには1行も出ない（unlock と同じ判断）。
	# ⚠ ここで見たい一番の項目は「全部解放したとき上限がちょうど 100 か」。
	#   ⚠ ずれるとパッシブの Lv100 が永久に解放されないが、赤も黄も出ない。
	"research": {
		"kind": KIND_REPORT,
		"report": REPORT_RESEARCH,
		"note": "研究ボード。ボード1→2の切り替え / 上限の合計 / 抽選回数 / 閉じたボードは解放できない",
	},
	# 段階11（作業場の復活）の検証。EXEC_WORKSHOP_REVIVE.md §5-A。
	# ⚠ 戦闘を回さない。start_craft() / collect_craft() を直接呼ぶ。
	# ⚠ 待たない。キューの started_at を巻き戻して completed にする（30分待てないため）。
	# ⚠ 素材は一度に配る。「足りるまで足す」ループを書かないこと（2026-08-24 の罠）。
	"workshop": {
		"kind": KIND_REPORT,
		"report": REPORT_WORKSHOP,
		"note": "装飾のくじ。レシピ3件 / 分布 / 受け取りで個体が増える / 研究の作業場枝 / E129",
	},
	# 段階12（バランス実測）の検証。EXEC_BALANCE_ECONOMY.md §5-A。
	#
	# ⚠ 戦闘を1回も回さない。1周で入るものは stages.json の rewards と
	#   _roll_chest_draw() から出す（drops / workshop と同じ形）。
	#   「1000回戦わせる」を書くと終わらない（1本10〜20秒）。
	# ⚠ 赤も黄も1本も足さない。「出口が無い素材」は print で名指しするだけ
	#   （EXEC_BALANCE_ECONOMY.md 決め1）。赤にすると30本全部が赤になる。
	# ⚠ 研究は最後に解放する。_roll_chest_draw() に宝箱枝が乗っているため、
	#   先に解放すると素の期待値が二度と取れない（決め5）。
	"economy": {
		"kind": KIND_REPORT,
		"report": REPORT_ECONOMY,
		"note": "資源の収支。素材16件の入口と出口 / 1周で入るもの / Lv100までの周回数と集中時間",
	},
	# 段階14-a（フロアの器）の検証。EXEC_SCENARIO_FLOOR.md §5。
	# ⚠ 戦闘を1回も回さない。マップを組んで歩けるかだけを見る。
	# ⚠ 全ルート総当たりは「合流あり」を選んだ根拠そのもの（PLAN_SCENARIO_MAP.md §3-2）。
	#   ここが0件でなくなったら、どこかのルートが行き止まりになっている。
	"floor": {
		"kind": KIND_REPORT,
		"report": REPORT_FLOOR,
		"note": "フロア5本。層構造の生成 / 入口からボスまで歩ける / 進めない先は弾く / 全ルート総当たり",
	},
	# 段階17-a（難ダンジョンのランの器）の検証。PLAN_HARD_DUNGEON.md §4 / §5。
	# ⚠ 戦闘を1回も回さない。⚠ 戦闘との接続は 17-b。
	# ⚠ シナリオ（scenario=floor）とは器が別。⚠ こちらが動いても floor の数字は
	#   1つも動かないのが正解（動いたら「シナリオ側に手が当たっている」合図）。
	"dungeon": {
		"kind": KIND_REPORT,
		"report": REPORT_DUNGEON,
		"note": "難ダンジョンのラン。層構造の生成 / 全ルート総当たり / ノード種に紐づく戦利品 / 鞄と一時通貨 / ボス後の続行と撤退 / 全ロスト",
	},
	# 段階17-b（難ダンジョンと戦闘の接続）の検証。PLAN_HARD_DUNGEON.md §4-4。
	#
	# ⚠ report の枝では足りない。⚠ 見たいのは「戦闘が削った HP がそのまま
	#   ランの MAX HP の目減りになるか」で、実際に殴り合わないと1つも出ない。
	# ⚠ ステージを1本も足していない。⚠ 敵は dungeon.json から
	#   GameManager.get_dungeon_node_wave() が引く（戦闘画面は battle_pool を読まない）。
	# ⚠ 2連戦する（道中の battle ノード → ボスのノード）。⚠ ボスに勝ったときだけ
	#   clear_dungeon_boss() が呼ばれることを見るため。
	# ⚠ スキルは撃たない。⚠ 見たいのは HP の出入りであってスキルの当たり方ではない。
	#   ⚠ fire を空配列にしないこと（passives の注意書きと同じ）。
	"dungeon_battle": {
		"kind": KIND_BATTLE,
		"note": "難ダンジョンの戦闘。ランのMAX HP で戦う / 終了時のHPが目減りになる / ボスに勝つと clear_dungeon_boss",
		"dungeon": true,
		"party": ["char_swordsman", "char_archer", "char_priest"],
		"skills": {},
		"fire": [
			{"skill": "", "prepare": PREPARE_NONE, "gap": 0.0},
			# ⚠ 殴られる時間を取る。⚠ ここが短いと目減りが 0 になり、何も分からない。
			{"skill": "", "prepare": PREPARE_NONE, "gap": 6.0},
		],
	},
	# 段階19-a（見た目の簡略表現）の検証。
	#
	# ⚠⚠ 「その字がフォントに在るか」だけを見る。⚠ 絵が出るかは人間しか見られない。
	#   ⚠ 在るかは has_char() で取れる。⚠ 豆腐（□）になるのは在らない字。
	# ⚠ 2026-09-04 に実測した：⚠ NotoSansJP は絵文字を1文字も持たない（収録 16,732 字）。
	#   ⚠ segoe-ui-emoji.ttf を fallback に足した（⚠ COLR/CPAL・1,274 字だけ）。
	#   ⚠⚠ 1,274 字しか無いので「思いついた絵文字が在る」とは限らない。
	#     ⚠ Glyphs に足したら必ずここを回して、⚠ NG が0件であることを確かめる。
	"glyphs": {
		"kind": KIND_REPORT,
		"report": REPORT_GLYPHS,
		"note": "見た目の字がフォントに在るか。Glyphs の全定数を has_char() で見る（NG が0件で正解）",
	},
	# 段階18-a（マス目）の検証。PLAN_INVENTORY.md §5-1。
	#
	# ⚠ 戦闘を1回も回さない。⚠ 見るのは「何がマスを1つ占めるか」と「何マス使うか」だけ。
	# ⚠⚠ 未決7（消耗品と装飾が個数ぶんマスを食う）の実測はここで取る。
	#   ⚠ 遊ぶ前に当てられないので、⚠ 仮置きの枠が妥当かはこの数字で決める。
	"inventory": {
		"kind": KIND_REPORT,
		"report": REPORT_INVENTORY,
		"note": "マス目。何がマスを占めるか / 汎用素材は入らない / 1個＝1マス（重ねない） / 何マス使うか",
	},
	# 2026-09-15。⚠ 埋め込みの Window 同士でドラッグが渡るか（人間の許可「5 いいよ」）。
	# ⚠ 本番のコードは使わない。⚠ つまむ側・受ける側は下の DragProbeSource / DragProbeTarget。
	# ⚠ ① が渡らなければ、入力の流し方のほうが壊れている（② ③ の結果は信じない）。
	"subwindow_drag": {
		"kind": KIND_REPORT,
		"report": REPORT_SUBWINDOW_DRAG,
		"note": "ドラッグが渡るか。① 普通の Control 同士 ／ ② 埋め込み Window の中 ／ ③ 埋め込み Window A→B",
	},
	# 2026-09-15 → ⚠⚠ 2026-09-23 に中身を入れ替えた（⚠ 倉庫の別窓を消した・人間「⚠ もう倉庫の別窓はいらない」）。
	# ⚠ 名前は残した（⚠ 過去の記録から引けるように）。⚠ 見るのは「窓が無いこと」と「ギルドのカードから入れること」。
	"inventory_window": {
		"kind": KIND_REPORT,
		"report": REPORT_INVENTORY_WINDOW,
		"note": "倉庫の別窓が無い / 右上の倉庫ボタンが無い / ギルドのカードに倉庫 / 倉庫が題と戻るを持つ画面",
	},
	# ⚠ 「equip_drag」（装備画面でドラッグして装備）は 2026-09-27 に消した（⚠ 装備画面ごと無くなった・持ち物の回・人間「⚠ 3あ」）。
	# 2026-09-15（段3b）。⚠ つまんだ品のカーソルの絵。⚠ 絵そのものは見られないので、⚠ 画素で確かめる。
	"drag_cursor": {
		"kind": KIND_REPORT,
		"report": REPORT_DRAG_CURSOR,
		"note": "カーソルの絵。大きさ / 角が等級の色 / 真ん中に線画の色 / 線画の無い品は地と枠だけ",
	},
	# 2026-09-15。⚠ 拠点の宝箱バッジで宝箱の一覧（ChestPanel）を開いて、⚠ 1つずつ／まとめて開ける。
	# ⚠ 2026-09-27：⚠ 一覧は「届いた宝箱」の画面になった＝⚠ 押して確かめる分は `ui_flow` へ移した。⚠ ここは画面に依らない分だけ。
	# ⚠ 宝箱は grant_chest() で積む（⚠ 状態は書き換えるが保存しない）。
	"base_chest": {
		"kind": KIND_REPORT,
		"report": REPORT_BASE_CHEST,
		"note": "宝箱（画面に依らない分）。items と chests のIDの重なり / 宝箱の絵の等級 / 知らせの窓の題の帯 / 呼び出し元が消えた順番待ち",
	},
	# ⚠ 育成・昇級・持ち物を本物のボタンで押して回る（2026-09-27）。⚠ 状態は書き換えるが保存しない。
	# ⚠ 難ダンジョンを自動で潜って数字を取る（2026-10-03・回6・人間「⚠ １　あ」）。⚠ 引数 runs= level= floors= speed=。
	"dungeon_sim": {
		"kind": KIND_DUNGEON_SIM,
		"note": "難ダンジョンを自動で潜る（スキルは撃てたら撃つ・休憩・ポーション・商人）→ 何層で倒れるか・コイン・ポーションの数字",
		"party": ["char_swordsman", "char_archer", "char_priest"],
	},
	"close": {
		"kind": KIND_CLOSE,
		"note": "窓を閉じる道（回P-1）：ポモドーロを開いて閉じる合図 → 確定 → 検査用のファイルに書いて終わる",
	},
	"ui_flow": {
		"kind": KIND_UI_FLOW,
		"note": "育成の札とタブ ／ 割り振り ／ スキル ／ 装備 ／ 昇級 ／ 持ち物（鍛える・刺す・外す・分解・段階・捨てる・図鑑）／ 詰所（ビルド・並べ替え・控え・開く）／ 掲示板（タブ・札・出撃届・続きから）",
	},
	# 2026-09-21。⚠⚠ 窓あり専用。⚠ 画面を PNG で撮る（⚠ 設計役が絵を見られる唯一の口）。
	# ⚠ `--headless` を付けないこと。⚠ 出し先は `shot_dir=<パス>`。
	# ⚠ 撮る画面を増やすなら `shots` に1行足す。⚠ シーンもスクリプトも増やさないこと。
	#
	# ⚠⚠ **何を撮るかは「役割」で選んである**（2026-09-21・人間の指示「⚠ 役割に応じて何開くか決めて」）。
	#   ⚠ ①ランの中で判断する ／ ⚠ ②戦う ／ ⚠ ③拠点の入口 ／ ⚠ ④育てる ／ ⚠ ⑤回す（経済）。
	#   ⚠ 同じ役割の画面を2枚撮らない（⚠ `floor_map` と `dungeon_map` だけは**器が別**なので両方撮る＝台帳 §7）。
	# ⚠⚠ **窓も撮れるようになった（2026-09-22・回1）。** ⚠ 撮り方は2通りで、⚠ どちらも本番の口を通す。
	#   ⚠ ① `SceneManager` で開くもの（⚠ レリック選択・商人・わかれ道）＝ ⚠ 普通の行に `prepare` を足すだけ
	#   ⚠ ② 画面の上に重ねるもの（⚠ 拾いもの・戦闘の結果・共通モーダル）＝ ⚠ `after` に手を1つ書く
	# ⚠⚠ 名前と中身がずれないように、⚠ 撮る直前に**開いた画面が `scene` と同じか**を確かめる
	#   （⚠ `dungeon_floor_clear` のように「条件を満たさないと自分でマップへ送り返す」画面があるため。
	#   ⚠ 09-21 は**マップの絵が「わかれ道」の名前で保存される**のを恐れて足せなかった。⚠ いまは弾く）。
	"shot": {
		"kind": KIND_SHOT,
		"note": "画面を PNG で撮る。⚠ --headless を外して回す。出し先は shot_dir= で渡す",
		"shots": [
			# ① ランの中で判断する。⚠ 器が別なので2枚撮る（台帳 §7）。
			{
				"name": "01_dungeon_map",
				"scene": "res://scenes/adventure/dungeon_map.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
			},
			{
				"name": "02_floor_map",
				"scene": "res://scenes/adventure/floor_map.tscn",
				"prepare": SHOT_PREPARE_FLOOR,
			},
			# ② 戦う。⚠ 敵と味方が並ぶまで待つので間を長めに取る。
			{
				"name": "03_battle",
				"scene": SCENE_BATTLE,
				"data": {
					TransferKeys.STAGE_ID: "stage_dbg_area",
					TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
				},
				"settle": 90,
				# ⚠ 人間の指摘「⚠ したのぱねるもおさめてほしい」（2026-09-21）。
				"measure": [
					"HUD/Root/Layout/BottomPanel",
					"HUD/Root/Layout/BottomPanel/SkillButtons",
					"HUD/Root/Layout/Header",
				],
			},
			# ③ 拠点の入口。
			{"name": "04_base", "scene": SCENE_BASE},
			# ⚠ タイトル（2026-09-27・回UI-4・手本 Title）。⚠ セーブの有無でボタンが変わる（⚠ 撮る側の PC のセーブ次第）。
			{"name": "25_title", "scene": "res://scenes/title/title_screen.tscn"},
			# ⚠ 加護を選ぶ（2026-09-27・回UI-4・手本 Pomodoro）。⚠ 今日まだ選んでいない状態なら加護のカードが出る。
			{"name": "26_pomodoro", "scene": "res://scenes/pomodoro/pomodoro.tscn"},
			# ⚠ `05_guild` は 2026-09-26（回UI-3）に消した（⚠ ギルドの画面ごと無い）。⚠ 番号は空けたまま。
			{"name": "06_adventure_select", "scene": "res://scenes/adventure/adventure_select.tscn"},
			# ④ 育てる。⚠ 装備は「誰の」が要るので渡す。
			{"name": "07_training", "scene": "res://scenes/guild/training_screen.tscn"},
			# ⚠ 育成のタブ（2026-09-27・回UI-組 育成・人間「⚠ 1い」）。⚠ 1画面の中のタブなので `data` のタブで開き分ける。
			{
				"name": "27_training_nodes",
				"scene": "res://scenes/guild/training_screen.tscn",
				"data": {TransferKeys.CHARACTER_ID: "char_swordsman", TransferKeys.TRAINING_TAB: TransferKeys.TRAINING_TAB_NODES},
			},
			{
				"name": "28_training_skills",
				"scene": "res://scenes/guild/training_screen.tscn",
				"data": {TransferKeys.CHARACTER_ID: "char_swordsman", TransferKeys.TRAINING_TAB: TransferKeys.TRAINING_TAB_SKILLS},
			},
			# ⚠ 昇級申請書（人間「⚠ 3あ」）。⚠ 31 は画面の口で判を押した姿（⚠ 素材は初期の分で足りる。⚠ 保存はしない）。
			{
				"name": "30_level_up",
				"scene": "res://scenes/guild/level_up_screen.tscn",
				"data": {TransferKeys.CHARACTER_ID: "char_swordsman"},
			},
			{
				"name": "31_level_up_done",
				"scene": "res://scenes/guild/level_up_screen.tscn",
				"data": {TransferKeys.CHARACTER_ID: "char_swordsman"},
				"after": SHOT_AFTER_LEVEL_UP_PRESS,
			},
			# ⚠ 08（装備画面）は 2026-09-27 に消した（⚠ 画面ごと無くなった・持ち物の右の紙へ移った）。
			# ⑤ 回す（経済）。
			{"name": "09_shop", "scene": "res://scenes/guild/shop_screen.tscn"},
			{"name": "10_workshop", "scene": "res://scenes/guild/workshop_screen.tscn"},
			{"name": "11_research", "scene": "res://scenes/guild/research_screen.tscn"},
			# ⚠ 2026-09-23：⚠ 倉庫を別窓からふつうの画面に戻した（⚠ 別窓のころは撮れなかった）。
			{"name": "19_warehouse", "scene": "res://scenes/guild/warehouse_screen.tscn"},
			# ⚠ 2026-09-26（回UI-2）：⚠ 紙の部品。⚠ UI テストのページの一番上に並べてある。
			{"name": "20_ui_parts", "scene": "res://tests/ui_test_page.tscn"},
			# ⑥ 窓（2026-09-22・回1）。⚠ ここから下は「重ねるもの」と「ボスの先のもの」。
			#
			# ⚠⚠ 拾いもの。⚠ 本番は**マップの上に重ねる**（決定36）ので、⚠ マップを開いてから
			#   ⚠ マップ自身の口（`_open_loot_overlay()`）を呼ぶ。
			#   ⚠ `run_loot_window.tscn` を単体で開くと**本番と違う絵**になる（⚠ 幕が透けない・後ろが無い）。
			{
				"name": "12_run_loot_window",
				"scene": "res://scenes/adventure/dungeon_map.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
				"after": SHOT_AFTER_LOOT_OVERLAY,
			},
			# ⚠⚠ 戦闘の結果。⚠ 戦闘画面の子（`HUD/ResultView`）なので、⚠ 戦って勝つ必要は無い。
			#   ⚠ 中身は `scenario=result` と同じ見本（⚠ floor_5 の報酬）。⚠ 勝ちの側を撮る。
			{
				"name": "13_battle_result",
				"scene": SCENE_BATTLE,
				"data": {
					TransferKeys.STAGE_ID: "stage_dbg_area",
					TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
				},
				"settle": 90,
				"after": SHOT_AFTER_BATTLE_RESULT,
			},
			# ⚠ レリック選択。⚠ `node_id` を渡さないとマップへ戻される（⚠ 宿題73）。⚠ マスは下ごしらえで探す。
			{
				"name": "14_relic_select",
				"scene": "res://scenes/adventure/run_relic_select.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
				"data": {TransferKeys.RUN_KIND: GameManager.RUN_KIND_DUNGEON},
				# ⚠ マスの ID はランを作るまで分からない。⚠ 種で1つ探して `RUN_NODE_ID` に入れる。
				"fill_node_id": GameStateKeys.DUNGEON_NODE_KIND_RELIC,
			},
			# ⚠ 2026-09-26（回UI-4 レリック）：⚠ カードを1枚選んだ姿（⚠ 「選んだ」の判・縁・付ける人）。
			#   ⚠ 1人用の候補があればそれを選び、⚠ 人も1人選ぶ（⚠ 「◯◯に付ける」まで出す）。
			{
				"name": "21_relic_chosen",
				"scene": "res://scenes/adventure/run_relic_select.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
				"data": {TransferKeys.RUN_KIND: GameManager.RUN_KIND_DUNGEON},
				"fill_node_id": GameStateKeys.DUNGEON_NODE_KIND_RELIC,
				"after": SHOT_AFTER_RELIC_PICK,
			},
			# ⚠ 2026-09-26（人間「⚠ その場で降りるボタンは消す　⚠ メニューからいけるようにする右上の」
			#   「⚠ レリックはレリックをまとめて見れるようにしたい」）：⚠ 右上のメニューを開いた姿 ／ ⚠ まとめて見る窓。
			{
				"name": "22_run_menu",
				"scene": "res://scenes/adventure/dungeon_map.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
				"after": SHOT_AFTER_RUN_MENU,
			},
			{
				"name": "23_relic_list",
				"scene": "res://scenes/adventure/dungeon_map.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
				"after": SHOT_AFTER_RELIC_LIST,
			},
			# ⚠ 2026-09-26（人間「⚠ すでに行った場所を赤いラインに」）：⚠ 1歩進めた姿（⚠ 通った道の赤い実線）。
			{
				"name": "24_map_walked",
				"scene": "res://scenes/adventure/dungeon_map.tscn",
				"prepare": SHOT_PREPARE_DUNGEON,
				"after": SHOT_AFTER_MAP_STEP,
			},
			# ⚠⚠ ボスの後のわかれ道（決定48）。⚠ ボスの先でないと自分でマップへ送り返す。
			{
				"name": "15_dungeon_floor_clear",
				"scene": "res://scenes/adventure/dungeon_floor_clear.tscn",
				"prepare": SHOT_PREPARE_DUNGEON_BOSS,
			},
			# ⚠ 商人。⚠ ボスの先だけ（決定15）。⚠ 品はマスターが持つので、⚠ phase を立てれば並ぶ。
			{
				"name": "16_dungeon_shop",
				"scene": "res://scenes/adventure/dungeon_shop.tscn",
				"prepare": SHOT_PREPARE_DUNGEON_BOSS,
			},
			# ⚠⚠ 共通モーダル（決定39・`MD-1`〜`MD-9`）。⚠ 09-21 に器を入れたが**絵は1枚も無い**。
			#   ⚠ 実行が赤・はいが左・題の帯・暗幕60% が1枚で見える件を撮る（⚠ セーブの削除の確認）。
			#   ⚠ 撮るだけ。⚠ 押さないので**セーブは消えない**（⚠ `await` していないため先へ進まない）。
			{
				"name": "17_modal_confirm",
				"scene": SCENE_BASE,
				"after": SHOT_AFTER_MODAL_CONFIRM,
			},
			# ⚠⚠ 装飾の枠（2026-09-22・回3・人間の決定「マス＋吹き出し」→ ⚠ 09-27 から持ち物の右の紙）。
			#   ⚠ 着けて鍛えて刺した武器を選び、⚠ 空きの枠を押して「刺せる装飾」に切り替わった姿（⚠ 2手の1手目）。
			{
				"name": "18_belongings_attach",
				"scene": "res://scenes/guild/warehouse_screen.tscn",
				"prepare": SHOT_PREPARE_EQUIPMENT,
				"after": SHOT_AFTER_PART_POPOVER,
			},
			# ⚠ 持ち物の装飾・素材のタブ（2026-09-27・回UI-組 持ち物）。⚠ 18 の下ごしらえで装飾を持っている。
			{
				"name": "32_belongings_part",
				"scene": "res://scenes/guild/warehouse_screen.tscn",
				"data": {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_PART},
			},
			{
				"name": "33_belongings_material",
				"scene": "res://scenes/guild/warehouse_screen.tscn",
				"data": {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_MATERIAL},
			},
			# ⚠ 育成の装備タブ（2026-09-27）。⚠ 18 の下ごしらえ（着けて・鍛えて・刺した姿）をそのまま使う（⚠ 2回呼ぶと「刺せない」で赤）。
			{
				"name": "29_training_equip",
				"scene": "res://scenes/guild/training_screen.tscn",
				"data": {TransferKeys.CHARACTER_ID: "char_swordsman", TransferKeys.TRAINING_TAB: TransferKeys.TRAINING_TAB_EQUIP},
			},
			# ⚠ 鍛冶場（2026-09-27・回UI-仕組み①・手本 Forge / ForgeResult）。⚠ 18 の下ごしらえの装備（⚠ 2回呼ぶと「刺せない」で赤）を
			#   ⚠ 先頭の個体として選んだ姿 ／ ⚠ 画面の口で「鍛える」を押した姿（⚠ 検査は必ず成功＝「成功」の判）。
			{"name": "36_forge", "scene": "res://scenes/guild/forge_screen.tscn"},
			{"name": "37_forge_result", "scene": "res://scenes/guild/forge_screen.tscn", "after": SHOT_AFTER_FORGE_PRESS},
			# ⚠ 失敗の窓（2026-09-27 の見る回・人間「⚠ 個別の演出を」）。⚠ 撮影の手の中だけ成功率を 0 にする。
			{"name": "40_forge_fail", "scene": "res://scenes/guild/forge_screen.tscn", "after": SHOT_AFTER_FORGE_FAIL},
			# ⚠ 鍛える演出の画面（2026-09-28・人間「⚠ 鍛冶場で鍛えるとき、演出を入れたい　⚠ 別の画面でやる」）。
			{"name": "48_forge_strike", "scene": "res://scenes/guild/forge_screen.tscn", "after": SHOT_AFTER_FORGE_STRIKE},
			# ⚠ 詰所（2026-09-27・回UI-組 詰所・手本 Barracks・決定 `NAV-11`）。⚠ 拠点から来た姿（⚠ 施設の帯あり）。
			#   ⚠ 下の紙が施設の帯（下 76）に隠れないか測る（⚠ 1回目は隠れた）。
			# ⚠⚠ 2026-09-28：⚠ 詰所＝出撃の準備（モック）。⚠ 初めて開くとガイドが出る＝`41` がその姿、⚠ `34` はガイドを「とばす」で閉じた姿。
			{"name": "41_sortie_guide", "scene": "res://scenes/adventure/party_preset_screen.tscn"},
			{
				"name": "34_barracks",
				"scene": "res://scenes/adventure/party_preset_screen.tscn",
				"after": SHOT_AFTER_GUIDE_SKIP,
				"measure": ["Margin/Layout/Roster", "FacilityBar"],
			},
			# ⚠ 依頼を受けた姿（⚠ 1話）／ ⚠ 3番の枠を押して名簿から選ぶ姿。
			{
				"name": "42_sortie",
				"scene": "res://scenes/adventure/party_preset_screen.tscn",
				"data": {TransferKeys.SORTIE_STAGE_ID: "floor_1", TransferKeys.RETURN_PATH: "res://scenes/adventure/adventure_select.tscn"},
			},
			{
				"name": "43_sortie_pick",
				"scene": "res://scenes/adventure/party_preset_screen.tscn",
				"data": {TransferKeys.SORTIE_STAGE_ID: "floor_1", TransferKeys.RETURN_PATH: "res://scenes/adventure/adventure_select.tscn"},
				"after": SHOT_AFTER_SORTIE_PICK,
			},
			# ⚠ 記録（2026-09-28・回UI-仕組み②・手本 Records）。⚠ 図鑑のタブ。
			{"name": "45_records", "scene": "res://scenes/guild/records_screen.tscn", "after": SHOT_AFTER_RECORDS_PICK},
			# ⚠ 設定（2026-09-28・回UI-仕組み③・手本 Settings）。⚠ 手本と同じ「ポモドーロと小窓」タブ ／ ⚠ 音のタブ（つまみ）。
			{"name": "46_settings", "scene": "res://scenes/base/settings_screen.tscn", "after": SHOT_AFTER_SETTINGS_POMODORO},
			{"name": "47_settings_audio", "scene": "res://scenes/base/settings_screen.tscn", "after": SHOT_AFTER_SETTINGS_AUDIO},
			# ⚠ 集中の道具（2026-09-29・回UI-仕組み⑤・手本 PomoSkin / Focus）。
			{"name": "51_focus_tools", "scene": "res://scenes/pomodoro/focus_tools_screen.tscn", "after": SHOT_AFTER_FOCUS_TOOLS_CLOCK},
			{"name": "52_focus_running", "scene": "res://scenes/pomodoro/pomodoro.tscn", "after": SHOT_AFTER_POMODORO_RUNNING},
			# ⚠ 装備の特殊効果（2026-10-02・回UI-仕組み⑦・手本 RichItemFx）。
			{"name": "54_special_effect", "scene": "res://scenes/guild/warehouse_screen.tscn", "after": SHOT_AFTER_SPECIAL_EFFECT},
			# ⚠ ノルマ札（2026-10-02・回UI-仕組み⑧）。⚠ 高難度の依頼＝札が要る姿。
			{"name": "55_board_hard", "scene": "res://scenes/adventure/adventure_select.tscn", "after": SHOT_AFTER_BOARD_HARD},
			# ⚠ 潜る深さ（2026-10-03・決定49・モック Q8 A案）。⚠ 最深 30層・ノルマ札1枚＝「31層から」。
			{
				"name": "58_sortie_depth",
				"scene": "res://scenes/adventure/party_preset_screen.tscn",
				"prepare": SHOT_PREPARE_SORTIE_DEPTH,
				"data": {TransferKeys.SORTIE_DUNGEON_ID: "dungeon_hard", TransferKeys.RETURN_PATH: "res://scenes/adventure/adventure_select.tscn"},
				"measure": ["Margin/Layout/Middle/Side", "Margin/Layout/Middle/Side/Depth", "Margin/Layout/Middle/Side/Reserve"],
			},
			# ⚠ タスクのメモ（2026-10-04・`TK-3`・`TK-7`・`TK-10`・`TK-8`）。⚠ 拠点（紙あり・溢れて送る）／ タスクの画面（詳しく）／ ポモドーロの選ぶ窓 ／ 記録のタブ。
			{"name": "59_base_tasks", "scene": SCENE_BASE, "prepare": SHOT_PREPARE_TASKS, "measure": ["Layout/TopArea/TaskWallNote"]},
			{"name": "60_task_screen", "scene": "res://scenes/base/task_screen.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_DETAIL},
			# ⚠ 10-05（人間「⚠ やることリストはサイドバーにする」）：⚠ 選ぶ窓 → 右のサイドバー。⚠ 集中を始める前の姿。
			{"name": "61_pomodoro_sidebar", "scene": "res://scenes/pomodoro/pomodoro.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_PICK, "measure": ["Margin", "TaskSidebar", "Margin/Layout/CurrentViewContainer/FocusView/Layout/StartButton"]},
			# ⚠ 集中中に右上の「リスト」を開いた姿（10-04・人間「⚠ ポモドーロ中にリストを見れるように　メニューと同じように」）。
			# ⚠ 「消す」の確かめの窓（10-04・`TK-15`）。⚠ 押さないので消えない。
			{"name": "64_task_delete", "scene": "res://scenes/base/task_screen.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_DELETE},
			{"name": "65_task_linked", "scene": "res://scenes/pomodoro/pomodoro.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_LINKED},
			{"name": "66_task_calendar", "scene": "res://scenes/base/task_screen.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_CALENDAR},
			{"name": "67_task_detail_running", "scene": "res://scenes/pomodoro/pomodoro.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_DETAIL_RUNNING},
			{"name": "63_task_list_running", "scene": "res://scenes/pomodoro/pomodoro.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_TASK_LIST},
			# ⚠ 記録へ移すので、⚠ タスクの枚のいちばん後ろ。
			{"name": "62_records_tasks", "scene": "res://scenes/guild/records_screen.tscn", "prepare": SHOT_PREPARE_TASK_LOG, "after": SHOT_AFTER_RECORDS_TASKS},
			# ⚠ ポモドーロの画面の設定の窓（2026-10-02・人間「⚠ ポモドーロ関連の設定はポモドーロ画面からできるように」）。
			{"name": "56_pomodoro_settings", "scene": "res://scenes/pomodoro/pomodoro.tscn", "after": SHOT_AFTER_POMODORO_SETTINGS},
			# ⚠ 「出撃する」→ 署名を書き終えて「受理」の判が押された姿（⚠ 出発の前で止める＝フロアに入らない）。
			{
				"name": "44_sortie_sign",
				"scene": "res://scenes/adventure/party_preset_screen.tscn",
				"data": {TransferKeys.SORTIE_STAGE_ID: "floor_1", TransferKeys.RETURN_PATH: "res://scenes/adventure/adventure_select.tscn"},
				"after": SHOT_AFTER_SORTIE_SIGN,
			},
			# ⚠ 宝箱の高レアの演出の途中（2026-09-27 の見る回・人間「⚠ 4あ」）。⚠ 種類ごとに1個積み直して legendary を開ける。
			{
				"name": "39_chest_fx",
				"scene": "res://scenes/base/chest_screen.tscn",
				"prepare": SHOT_PREPARE_CHESTS,
				"after": SHOT_AFTER_CHEST_FX,
			},
			# ⚠ 育成の一覧（2026-09-27 の見る回・人間「⚠ 3あ」）。⚠ 身上書カードは詰所からここへ移した。
			{"name": "38_training_list", "scene": "res://scenes/guild/training_list_screen.tscn"},
			# ⚠ 届いた宝箱（2026-09-27・回UI-組 宝箱・手本 Chest・決定 `BS-21`）。⚠ 種類ごとに1個積み、⚠ 1個開けた姿。
			{
				"name": "35_chest",
				"scene": "res://scenes/base/chest_screen.tscn",
				"prepare": SHOT_PREPARE_CHESTS,
				"after": SHOT_AFTER_CHEST_OPEN,
			},
			# ⚠ 帰還報告書（2026-09-29・回UI-仕組み④・手本 DungeonResult）。⚠ 持ち帰り ／ 倒れた。
			#   ⚠⚠ **いちばん最後に置く**（⚠ ランを終わらせ、⚠ 持ち帰った宝箱が宝物庫に積まれる＝宝箱の枚の下ごしらえが狂う）。
			{"name": "49_run_report", "scene": "res://scenes/adventure/run_report_screen.tscn", "prepare": SHOT_PREPARE_REPORT_RETURNED},
			{"name": "50_run_report_defeated", "scene": "res://scenes/adventure/run_report_screen.tscn", "prepare": SHOT_PREPARE_REPORT_DEFEATED},
			# ⚠ デスクトップの小窓（2026-10-02・回UI-仕組み⑥・手本 Companion）。⚠ 窓が本当に小さくなる＝⚠⚠ いちばん最後。
			{"name": "53_mini_window", "scene": "res://scenes/pomodoro/pomodoro.tscn", "after": SHOT_AFTER_MINI_WINDOW},
			{"name": "68_mini_list", "scene": "res://scenes/pomodoro/pomodoro.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_MINI_LIST},
			# ⚠ 「小窓にしますか？」（10-06・不便7）：⚠ はじめて集中を始めたときの窓。
			{"name": "70_mini_ask", "scene": "res://scenes/pomodoro/pomodoro.tscn", "after": SHOT_AFTER_MINI_ASK},
			{"name": "71_item_source", "scene": "res://scenes/guild/forge_screen.tscn", "after": SHOT_AFTER_ITEM_SOURCE},
			{"name": "72_board_quick", "scene": "res://scenes/adventure/adventure_select.tscn", "prepare": SHOT_PREPARE_BOARD_CLEARED},
			{"name": "69_mini_reflection", "scene": "res://scenes/pomodoro/pomodoro.tscn", "prepare": SHOT_PREPARE_TASKS, "after": SHOT_AFTER_MINI_REFLECTION},
			# ⚠ デバッグの窓（2026-10-03）。⚠ 出したままになる＝⚠ いちばん最後。
			{"name": "57_debug_overlay", "scene": "res://scenes/base/base_screen.tscn", "after": SHOT_AFTER_DEBUG_OVERLAY},
		],
	},
	# 画面をいきなり開くだけのシナリオ。⚠ 窓あり専用。
	"training": {
		"kind": KIND_SCREEN,
		"note": "育成画面をいきなり開く（拠点→ギルド→育成を辿らない）",
		"scene": "res://scenes/guild/training_screen.tscn",
	},
}


func _ready() -> void:
	var scenario_name: String = _read_scenario_name()
	if not SCENARIOS.has(scenario_name):
		_print_usage(scenario_name)
		get_tree().quit()
		return

	var scenario: Dictionary = SCENARIOS[scenario_name]
	# ⚠ 自動で潜る枝（2026-10-03・回6）は `level=` で3人の Lv を決める（⚠ 1 なら新しいセーブのまま）。
	if str(scenario.get("kind", "")) == KIND_DUNGEON_SIM:
		scenario = scenario.duplicate(true)
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("level=") and int(arg.substr(6)) > 1:
				var levels: Dictionary = {}
				for member: Variant in scenario.get("party", []):
					levels[str(member)] = int(arg.substr(6))
				scenario["levels"] = levels
	print("[DebugBoot] scenario=%s : %s" % [scenario_name, str(scenario.get("note", ""))])

	# ⚠⚠ 設定（`GameSettings`・2026-09-28）は検査用のファイルへ差し替え、毎回既定から始める。
	#   ⚠ 遊んでいる人の `user://settings.cfg` を書き換えない。⚠ 窓で撮るので全画面を戻す。
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST_PATH))
	GameSettings.use_path(SETTINGS_TEST_PATH)
	# ⚠ 「小窓にしますか？」はもう聞いたことにする（10-06）：⚠ 集中を始めるたびに窓が出て、⚠ ほかの手を塞がないように。⚠ 聞く手は ui_flow の `_flow_mini_ask()` だけ。
	GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_ASKED, true)
	# ⚠⚠ セーブも検査用のファイルへ（2026-10-05・回P-1・自動セーブが入った）。⚠ 遊んでいる人の save_slot_0.json を書かない。
	#   ⚠ 自動で書くのはタイトルで始めたあとだけ＝⚠ ここでは書かない（⚠ 下の「SaveManager を呼ばない」は守ったまま）。
	SaveManager.use_path(SAVE_TEST_PATH)
	SaveManager.end_session()
	GameSettings.apply_display()
	SoundManager.refresh_volumes()
	# ⚠ 状態は書き換えるが、絶対に保存しない。
	#   set_party_member() / select_skill() は本物の状態を触るので、保存すると
	#   人間の編成とスキル枠が黙って変わる。SaveManager をこのファイルから呼ばないこと。
	_apply_party(scenario)
	# ⚠⚠ 鍛冶を必ず成功にする（2026-09-27・`EQ-6` で等級5→6 から失敗するようになった）。
	#   ⚠ 検査の多くが「鍛えたら等級が1上がる」を前提に数えている＝⚠ 乱数で揺れると毎回コードを疑うことになる（AGENTS.md）。
	#   ⚠ 失敗を見る検査（`ui_flow` の鍛冶場）は自分で下げてから戻す。⚠ メモリの中だけ（⚠ `.tres` は書かない）。
	if Balance.equipment != null:
		var always: Array[int] = []
		for _i: int in range(Balance.equipment.forge_success_pct_by_grade.size()):
			always.append(100)
		Balance.equipment.forge_success_pct_by_grade = always
	# ⚠ レベルはスキル枠より先に上げる。select_skill() は unlock_level で弾くため、
	#   Lv1 のままだと上位のスキルが「候補に無い」で入らない。
	_apply_levels(scenario)
	_apply_skills(scenario)
	_apply_runes(scenario)

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_REPORT:
		# ⚠ 報告の枝が増えたらここに1行足す。シーンもスクリプトも増やさないこと。
		var report: String = str(scenario.get("report", REPORT_MATERIALS))
		if report == REPORT_MATERIALS:
			_report_materials()
		elif report == REPORT_PARTS:
			_report_parts()
		elif report == REPORT_DROPS:
			_report_drops()
		elif report == REPORT_PRESETS:
			_report_presets()
		elif report == REPORT_UNLOCK:
			_report_unlock()
		elif report == REPORT_RESEARCH:
			_report_research()
		elif report == REPORT_WORKSHOP:
			_report_workshop()
		elif report == REPORT_ECONOMY:
			_report_economy()
		elif report == REPORT_FLOOR:
			_report_floor()
		elif report == REPORT_DUNGEON:
			_report_dungeon()
		elif report == REPORT_INVENTORY:
			_report_inventory()
		elif report == REPORT_GLYPHS:
			_report_glyphs()
		elif report == REPORT_THEME:
			_report_theme()
		elif report == REPORT_LAYOUT:
			# ⚠ これだけ await を持つ（レイアウトは1フレーム待たないと確定しない）。
			await _report_layout()
		elif report == REPORT_GAIN:
			await _report_gain()
		elif report == REPORT_SUBWINDOW_DRAG:
			await _report_subwindow_drag()
		elif report == REPORT_INVENTORY_WINDOW:
			await _report_inventory_window()
		elif report == REPORT_DRAG_CURSOR:
			_report_drag_cursor()
		elif report == REPORT_BASE_CHEST:
			await _report_base_chest()
		else:
			push_error("[DebugBoot] 知らない report: " + report)
		get_tree().quit()
		return

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_SHOT:
		# ⚠ ヘッドレスで回されたらここで止める。⚠ 黙って真っ黒な絵を保存するのが一番たちが悪い。
		if DisplayServer.get_name() == "headless":
			push_error("[DebugBoot] ⚠ shot は窓あり専用。⚠ --headless を外して回すこと")
			get_tree().quit()
			return
		var taker: ShotTaker = ShotTaker.new()
		taker.name = "DebugBootShotTaker"
		taker.out_dir = _read_shot_dir()
		taker.shots = scenario.get("shots", [])
		# ⚠ Driver と同じ理由で root に残す。⚠ 画面を差し替えると自分（＝debug_boot）は消える。
		get_tree().root.add_child.call_deferred(taker)
		return

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_DUNGEON_SIM:
		var sim: DungeonSimRunner = DungeonSimRunner.new()
		sim.name = "DebugBootDungeonSim"
		get_tree().root.add_child.call_deferred(sim)
		return

	# ⚠ 窓を閉じる道（2026-10-05・回P-1）：⚠ 始めた状態でポモドーロを開き、2秒後に本物の「閉じる」の合図を root に流す。
	#   ⚠ 見るのはログ（⚠ `[Pomodoro] settled` → `[SaveManager] save_game -> 検査用のファイル` → 終わる）。⚠ 書くのは検査用のファイルだけ。
	if str(scenario.get("kind", KIND_BATTLE)) == KIND_CLOSE:
		SaveManager.begin_session()
		var timer: Timer = Timer.new()
		timer.wait_time = 2.0
		timer.one_shot = true
		timer.autostart = true
		# ⚠ root のメソッドにつなぐ（⚠ この debug_boot は画面を移ると消える＝ラムダで掴まない）。
		timer.timeout.connect(get_tree().root.propagate_notification.bind(NOTIFICATION_WM_CLOSE_REQUEST))
		get_tree().root.add_child.call_deferred(timer)
		SceneManager.change_scene_with_data.call_deferred("res://scenes/pomodoro/pomodoro.tscn", {})
		return

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_UI_FLOW:
		var runner: UiFlowRunner = UiFlowRunner.new()
		runner.name = "DebugBootUiFlow"
		# ⚠ 撮影の係と同じ理由で root に残す（⚠ 画面を差し替えると自分＝debug_boot は消える）。
		get_tree().root.add_child.call_deferred(runner)
		return

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_SCREEN:
		print("[DebugBoot] kind=screen（⚠ 窓あり専用。ヘッドレスでは何も分からない）")
		# ⚠ battle の枝と同じ理由で call_deferred。_ready() の中から遷移すると
		#   今のシーン（＝自分）を外す remove_child() が弾かれる。
		#   ⚠ 片方だけ直して片方を忘れた（2026-08-18）。枝が2つあることを忘れないこと。
		SceneManager.change_scene.call_deferred(str(scenario.get("scene", "")))
		return

	# ⚠ change_scene すると今のシーン（＝自分）は消えるので、撃つ役を root に残す。
	#   SceneManager が DebugOverlay を root に足しているのと同じ形（scene_manager.gd:29-34）。
	var driver: Driver = Driver.new()
	driver.name = "DebugBootDriver"
	driver.battle_scene_path = SCENE_BATTLE
	driver.skill_plan = scenario.get("fire", [])
	driver.dump_each_fire = bool(scenario.get("dump_each_fire", false))
	driver.dump_result = bool(scenario.get("dump_result", false))
	driver.dump_status_tones = bool(scenario.get("dump_status_tones", false))
	driver.dump_pops = bool(scenario.get("dump_pops", false))
	driver.dump_tooltip = bool(scenario.get("dump_tooltip", false))
	driver.dump_enemy_sp = bool(scenario.get("dump_enemy_sp", false))
	# ⚠ call_deferred なのは、_ready() の時点では root が子を組み立てている最中で
	#   add_child() が弾かれるため（"Parent node is busy setting up children"）。
	#   SceneManager が DebugOverlay を足すときに call_deferred しているのと同じ理由。
	# 渡すもの。⚠ 通常のステージは stage_id、⚠ 難ダンジョンは dungeon_node_id
	#   （段階17-b）。⚠ 両方入れないこと。器が別で、入口も別。
	var transfer: Dictionary = {
		TransferKeys.STAGE_ID: str(scenario.get("stage_id", "")),
		TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
	}
	if bool(scenario.get("dungeon", false)):
		var dungeon_node_id: String = _prepare_dungeon_battle()
		if dungeon_node_id == "":
			get_tree().quit()
			return
		driver.dungeon_mode = true
		driver.dungeon_base_max_hp = _dungeon_base_max_hp
		transfer = {
			TransferKeys.DUNGEON_NODE_ID: dungeon_node_id,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
		}

	get_tree().root.add_child.call_deferred(driver)

	# ⚠ 遷移も call_deferred。_ready() の中から呼ぶと、今のシーン（＝自分）を外す
	#   remove_child() が root の組み立て中に当たって弾かれる。
	SceneManager.change_scene_with_data.call_deferred(SCENE_BATTLE, transfer)


# --- 起動引数 --------------------------------------------------

# `-- scenario=area` の形で受け取る。
# ⚠ コードを書き換えずに切り替えられることが要件。定数を書き換える運用にしない。
func _read_scenario_name() -> String:
	var args: Array = []
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for raw in args:
		var arg: String = str(raw)
		if arg.begins_with("scenario="):
			return arg.substr("scenario=".length())
		if arg.begins_with("--scenario="):
			return arg.substr("--scenario=".length())
	return ""


func _print_usage(given: String) -> void:
	if given == "":
		print("[DebugBoot] scenario が指定されていない")
	else:
		print("[DebugBoot] 知らない scenario: %s" % given)
	print("[DebugBoot] 使い方: -- scenario=<名前>")
	for key in SCENARIOS.keys():
		var scenario: Dictionary = SCENARIOS[key]
		print("[DebugBoot]   %s [%s] %s" % [
			str(key), str(scenario.get("kind", "")), str(scenario.get("note", ""))
		])


# --- 下ごしらえ ------------------------------------------------

func _apply_party(scenario: Dictionary) -> void:
	var members: Array = scenario.get("party", [])
	for i: int in range(members.size()):
		var character_id: String = str(members[i])
		if not GameManager.set_party_member(i, character_id):
			push_error("[DebugBoot] set_party_member(%d, '%s') が false" % [i, character_id])
	print("[DebugBoot] party=%s" % str(GameManager.get_party_members()))


# レベルの下ごしらえ（段階3・EXEC_CHARACTER_PASSIVES.md §4-8）。
#
# ⚠⚠ パッシブは**ステータスノードの総ポイント** 20/40/60/80/100 で自動で解放される
#   （2026-09-14・人間の決定。⚠ Lv21/41/61/81/100）。⚠ Lv1 のままだと1件も付かず、
#   「パッシブが効かない」のか「まだ解放されていない」のか読めない。
# ⚠ 研究の上限解放を先に通す。get_effective_level_cap() が 20 のままだと
#   Lv21 以降に上がらず、level_up_character() が false を返し続ける。
# ⚠ 素材は一度に配る。「足りるまで足す」ループを書かないこと（在庫を減らすために
#   操作を繰り返す形にすると出力が数万行になる。2026-08-24 に踏んだ罠）。
# ⚠ 状態は書き換えるが保存しない（_apply_party() と同じ）。
func _apply_levels(scenario: Dictionary) -> void:
	var table: Dictionary = scenario.get("levels", {})
	if table.is_empty():
		return

	# ⚠ 素材が先。unlock_research_node() は素材を払うので、逆にすると1件も解放されない
	#   （F4 の「研究を全部解放（先に素材）」と同じ順）。
	for material_id: Variant in MasterDataLoader.get_all_items():
		var definition: Dictionary = MasterDataLoader.get_all_items()[material_id]
		if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_MATERIAL:
			GameManager.add_material(str(material_id), 9999999)
	# ⚠ 前提を辿るので、解放できなくなるまで繰り返す（F4 の _unlock_all_research と同じ形）。
	for _pass_index: int in range(MasterDataLoader.get_all_research_nodes().size()):
		var unlocked_this_pass: int = 0
		for node_id: Variant in MasterDataLoader.get_all_research_nodes():
			if GameManager.unlock_research_node(str(node_id)):
				unlocked_this_pass += 1
		if unlocked_this_pass == 0:
			break

	# ⚠ ja.csv の再インポートは人間の作業で、設計役にはできない。
	#   済んだかどうかを設計役が観測できる合図をここで出す
	#   （scenario=unlock が .tres について同じことをしている）。
	# ⚠ 未了だと scenario=layout が赤を出す。tr() がキー文字列をそのまま返し、
	#   "%d" が無いまま % を当てるため（研究画面のヘッダと効果の表示）。
	# ⚠ 見るキーは「その回に足したもの」に必ず差し替えること（段階10で踏んだ）。
	#   ⚠ 前の回のキーを見たままだと、再インポート済みのキーに当たって
	#     「済んでいる」と出るのに、その回のキーは未インポートのまま先へ進む。
	# ⚠ 2026-08-31 に ui_icon_* 23行（仮アセットの文字）へ差し替えた。
	#   ⚠ 同じ日の2回目に、残り78件（素材16・装飾61・消耗品1）を足したので、
	#     その回のキーへ差し替える。⚠ 23行だけ再インポート済みでも「まだ」と出るのが正しい。
	var probe: String = "ui_icon_part_gem_hp_1"
	print("[DebugBoot] ja.csv の再インポート: %s" % (
		"まだ（⚠ アイコンにキー名がそのまま出る）" if tr(probe) == probe
		else "済んでいる"
	))

	# ⚠ 何段で何件付くかを出すのがこの関数の本題。件数だけ出す（名前は戦闘のログに出る）。
	print("[DebugBoot] --- レベルとパッシブの件数（⚠ 解放されたものが全部効く）---")
	for raw_character_id: Variant in table.keys():
		var character_id: String = str(raw_character_id)
		var goal: int = int(table[raw_character_id])
		var marks: Array[String] = []
		while true:
			var level: int = int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
			if level >= goal:
				break
			if not GameManager.level_up_character(character_id):
				push_error("[DebugBoot] level_up_character('%s') が false（Lv%d で止まった・目標 %d）" % [
					character_id, level, goal
				])
				break
			# 解放の段を通過した瞬間だけ記録する。毎レベル出すと297行になる。
			var reached: int = int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
			var count: int = GameManager.get_battle_passives(character_id).size()
			if count != marks.size():
				marks.append("Lv%d:%d件" % [reached, count])
		# ⚠ 開いたレベルは上のループが記録している（⚠ Lv21/41/61/81/100 で 1→5 件が正解）。
		print("  %-16s Lv%-4d total=%dpt passives=%d  %s" % [
			character_id,
			int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1)),
			GameManager.get_stat_node_total_points(character_id),
			GameManager.get_battle_passives(character_id).size(),
			" ".join(marks),
		])


func _apply_skills(scenario: Dictionary) -> void:
	var table: Dictionary = scenario.get("skills", {})
	for raw_character_id in table.keys():
		var character_id: String = str(raw_character_id)
		var skill_ids: Array = table[raw_character_id]
		for slot: int in range(skill_ids.size()):
			# ⚠ 既に同じ枠に入っている場合は false が返るが、それは正常
			#   （game_manager.gd:2168 の "already in this slot"）。
			GameManager.select_skill(character_id, slot, str(skill_ids[slot]))


# 機能の段階解放（段階9・EXEC_SCREEN_UNLOCK.md §3-J）。
#
# ⚠ 戦闘を回さない。mark_stage_cleared() を直接呼ぶ。
# ⚠ 状態は書き換えるが保存しない（_ready() の注意書きと同じ）。
func _report_unlock() -> void:
	print("[DebugBoot] --- 画面IDの一覧（GAME_DESIGN.md 9-5 の解放順）---")
	var all_ids: Array[String] = GameManager.get_all_screen_ids()
	print("  %d 件: %s" % [all_ids.size(), str(all_ids)])

	print("[DebugBoot] --- stages.json の unlocks ---")
	var listed: Array[String] = []
	# ⚠ 段階14-a でフロア5本になった（stage_1..3 は無い）。
	for stage_id: String in ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5"]:
		var unlocks: Array[String] = GameManager.get_stage_unlocks(stage_id)
		listed.append_array(unlocks)
		print("  %-10s -> %s" % [stage_id, str(unlocks)])
	# ⚠ 知らない screen_id は E125 がロード時に赤で言う。ここでは逆向きを出す。
	var never: Array[String] = []
	for screen_id: String in all_ids:
		if not (screen_id in listed):
			never.append(screen_id)
	print("  ⚠ unlocks に1度も出てこないもの: %s" % str(never))
	print("     （最初から開く3つだけが正解。⚠ workshop は段階14-a で floor_4 に入った）")

	# ⚠ 新規開始の状態を作り直す。debug_boot はセーブを読まないので、
	#   ここに来た時点の unlocked_screens は initial_state_config.tres の中身。
	print("[DebugBoot] --- 段階的に開くか ---")
	print("  最初            %s" % str(_unlocked_ids()))
	# ⚠ initial_state_config.tres は .tres なので設計役には直せない（CLAUDE.md）。
	#   ⚠ 人間が guild と pomodoro を配列から消したかを、ここで数字にして出す。
	var leaked: Array[String] = []
	for screen_id: String in [GameStateKeys.SCREEN_GUILD, GameStateKeys.SCREEN_POMODORO]:
		if GameManager.is_screen_unlocked(screen_id):
			leaked.append(screen_id)
	if leaked.is_empty():
		print("  ⚠ initial_state_config.tres は直っている（最初から開くのは3つ）")
	else:
		print("  ⚠ initial_state_config.tres がまだ直っていない: %s が最初から開いている" % str(leaked))
		print("     （Inspector の initially_unlocked_screens から2件を消す。EXEC_SCREEN_UNLOCK.md §7-A）")
	for stage_id: String in ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5"]:
		var before: Array[String] = _unlocked_ids()
		GameManager.mark_stage_cleared(stage_id, 0)
		var after: Array[String] = _unlocked_ids()
		var added: Array[String] = []
		for screen_id: String in after:
			if not (screen_id in before):
				added.append(screen_id)
		print("  %-10s クリア -> +%s" % [stage_id, str(added)])
	print("  最後            %s" % str(_unlocked_ids()))
	print("  workshop は開いたか -> %s（⚠ 段階11から true が正解）" % str(
		GameManager.is_screen_unlocked(GameStateKeys.SCREEN_WORKSHOP)
	))

	# --- 装飾とルーンの機能ID（決定5）---
	print("[DebugBoot] --- 種類 -> 機能ID ---")
	for kind: String in [
		GameManager.PART_KIND_GEM, GameManager.PART_KIND_CHARM,
		GameManager.PART_KIND_EMBLEM, GameManager.PART_KIND_RUNE,
	]:
		print("  %-8s -> %s" % [kind, str(GameManager.is_part_kind_unlocked(kind))])

	# --- 足した検証が本当に出るか（2箇所で壊す・メモリ上の状態だけ）---
	print("[DebugBoot] --- 壊して確かめる ---")
	# (a) 開いているものを1つ消してから同期 -> クリア済みなので開き直る
	var poisoned: Dictionary = GameManager.get_state().get(GameStateKeys.UNLOCKED_SCREENS, {})
	poisoned.erase(GameStateKeys.SCREEN_SHOP)
	GameManager._state[GameStateKeys.UNLOCKED_SCREENS] = poisoned
	print("  (a) shop を消した -> %s" % str(GameManager.is_screen_unlocked(GameStateKeys.SCREEN_SHOP)))
	GameManager._sync_unlocked_screens_from_master()
	print("  (a) 同期した後   -> %s（true が正解）" % str(
		GameManager.is_screen_unlocked(GameStateKeys.SCREEN_SHOP)
	))
	# (b) クリアを取り消してから同期 -> 一度開いたものは閉じない
	var story: Dictionary = GameManager.get_state().get(GameStateKeys.STORY, {})
	var stages: Dictionary = story.get(GameStateKeys.STORY_STAGES, {})
	stages.erase("floor_5")
	story[GameStateKeys.STORY_STAGES] = stages
	GameManager._state[GameStateKeys.STORY] = story
	GameManager._sync_unlocked_screens_from_master()
	print("  (b) floor_5 のクリアを消して同期 -> rune=%s shop=%s（どちらも true が正解）" % [
		str(GameManager.is_screen_unlocked(GameStateKeys.SCREEN_RUNE)),
		str(GameManager.is_screen_unlocked(GameStateKeys.SCREEN_SHOP)),
	])
	# (d) 「最初から」で状態が作り直されるか（2026-08-24・人間が実機で見つけた穴）。
	# ⚠ セーブファイルは触らない。メモリ上の状態が戻るかだけを見る。
	#   ⚠ title_screen が新規開始のときに呼ぶのと同じ1本を通す。
	print("[DebugBoot] --- 最初から（reset_to_new_game）---")
	GameManager.add_gold(99999)
	print("  遊んだ状態  gold=%d 開いている画面=%d件" % [
		int(GameManager.get_state().get(GameStateKeys.GOLD, 0)), _unlocked_ids().size()
	])
	GameManager.reset_to_new_game()
	print("  最初から後  gold=%d 開いている画面=%d件" % [
		int(GameManager.get_state().get(GameStateKeys.GOLD, 0)), _unlocked_ids().size()
	])
	print("  ⚠ gold が initial_state_config.tres の値に戻り、クリア済みが消えていること")

	# (c) E125 … unlocks に知らない screen_id を混ぜて、検証が赤を出すか。
	# ⚠ 壊すのは MasterDataLoader のメモリ上のキャッシュだけ。stages.json は触らない
	#   （git diff が最初から空のまま）。
	# ⚠ この枝だけ ERROR: を1本わざと出す。⚠ 赤が1本出るのが正解
	#   （drops が黄を1本多く出すのと同じ形）。
	print("  (c) unlocks に知らない screen_id を混ぜる（⚠ この下の赤1本が正解）")
	var poisoned_stage: Dictionary = MasterDataLoader._cache_stages["floor_1"]
	var backup: Variant = poisoned_stage[GameManager.STAGE_MASTER_UNLOCKS]
	poisoned_stage[GameManager.STAGE_MASTER_UNLOCKS] = ["screen_that_does_not_exist"]
	MasterDataLoader._validate_all_item_refs()
	poisoned_stage[GameManager.STAGE_MASTER_UNLOCKS] = backup
	print("  (c) 戻した -> floor_1 の unlocks = %s" % str(GameManager.get_stage_unlocks("floor_1")))


# 研究ボード（段階10・EXEC_GUILD_RESEARCH_V2.md §7-1）。
#
# ⚠ 戦闘を回さない。unlock_research_node() を直接呼ぶ。
# ⚠ 状態は書き換えるが保存しない（_report_unlock() と同じ）。
# ⚠ 素材は一度に配る。「足りるまで足す」ループを書かないこと（2026-08-24 の罠）。
func _report_research() -> void:
	var nodes: Dictionary = MasterDataLoader.get_all_research_nodes()

	# --- ボードごとの内訳 ---
	print("[DebugBoot] --- research.json の内訳（%d件）---" % nodes.size())
	var boards: Array[int] = []
	for node_id: Variant in nodes:
		var board: int = GameManager.get_research_board_of(str(node_id))
		if not (board in boards):
			boards.append(board)
	boards.sort()
	for board: int in boards:
		var progress: Dictionary = GameManager.get_research_board_progress(board)
		print("  ボード%d  %d件" % [board, int(progress.get("total", 0))])

	# --- 上限の合計（⚠ この報告の本題）---
	# ⚠ 「全部解放したとき ちょうど max_character_level に届くか」を数字で出す。
	#   ⚠ ずれても赤も黄も出ない形の穴（E127 が同じことをロード時に見張っている）。
	var base_cap: int = int(Balance.character.base_level_cap)
	var max_level: int = int(Balance.character.max_character_level)
	var sum_unlocks: int = 0
	var cap_nodes: int = 0
	for node_id: Variant in nodes:
		var definition: Dictionary = nodes[node_id]
		if str(definition.get(GameStateKeys.NODE_EFFECT_TYPE, "")) != GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			continue
		cap_nodes += 1
		sum_unlocks += int(definition.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	print("[DebugBoot] --- レベル上限の合計 ---")
	print("  base_level_cap %d + level_cap_unlock %d件 %d = %d / max_character_level %d -> %s" % [
		base_cap, cap_nodes, sum_unlocks, base_cap + sum_unlocks, max_level,
		"一致" if base_cap + sum_unlocks == max_level else "⚠ ずれている（E127）",
	])

	# --- 閉じているボードは解放できないか ---
	# ⚠ 素材を先に配る。素材不足で false になると、ボードのゲートを見たことにならない。
	for material_id: Variant in MasterDataLoader.get_all_items():
		var item: Dictionary = MasterDataLoader.get_all_items()[material_id]
		if str(item.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_MATERIAL:
			GameManager.add_material(str(material_id), 9999999)

	print("[DebugBoot] --- ボードの切り替え ---")
	print("  最初の今のボード -> %d" % GameManager.get_current_research_board())
	var later_board_id: String = ""
	for node_id: Variant in nodes:
		if GameManager.get_research_board_of(str(node_id)) == 2:
			later_board_id = str(node_id)
			break
	if later_board_id == "":
		push_error("[DebugBoot] ボード2のノードが1件も無い（research.json）")
	else:
		# ⚠ 前提が空のノードでも、ボードが閉じていれば解放できないのが正解。
		print("  ボード2の '%s' をいきなり解放 -> %s（false が正解）" % [
			later_board_id, str(GameManager.unlock_research_node(later_board_id))
		])

	# --- ボード1を全部解放する ---
	# ⚠ 前提を辿るので、解放できなくなるまで繰り返す（F4 の _unlock_all_research と同じ形）。
	var unlocked_total: int = 0
	for _pass_index: int in range(nodes.size()):
		var unlocked_this_pass: int = 0
		for node_id: Variant in nodes:
			if GameManager.get_research_board_of(str(node_id)) != 1:
				continue
			if GameManager.unlock_research_node(str(node_id)):
				unlocked_this_pass += 1
		unlocked_total += unlocked_this_pass
		if unlocked_this_pass == 0:
			break
	print("  ボード1を %d件 解放 -> 今のボード %d / 実効レベル上限 %d" % [
		unlocked_total,
		GameManager.get_current_research_board(),
		GameManager.get_effective_level_cap(""),
	])
	print("     （⚠ ボード1のクリアで Lv%d に届くのが正解。パッシブの Lv100 がここで開く）" % max_level)

	# --- ボード2も全部解放する ---
	var before_bonus: int = GameManager.get_research_chest_draw_bonus()
	for _pass_index: int in range(nodes.size()):
		var unlocked_this_pass: int = 0
		for node_id: Variant in nodes:
			if GameManager.unlock_research_node(str(node_id)):
				unlocked_this_pass += 1
		if unlocked_this_pass == 0:
			break
	print("[DebugBoot] --- 全部解放したあと ---")
	print("  実効レベル上限 %d（⚠ ボード2に上限ノードは無いので %d のまま が正解）" % [
		GameManager.get_effective_level_cap(""), max_level
	])
	print("  宝箱の抽選回数のボーナス %d -> %d" % [
		before_bonus, GameManager.get_research_chest_draw_bonus()
	])
	var stat_boosts: Dictionary = GameManager.get_stat_boost_all()
	print("  ステータス加算 %s" % str(stat_boosts))
	print("     （⚠ \"all\" は全軸・それ以外は軸1本だけに乗る。get_effective_stats() が合成する）")


# 作業場（段階11・EXEC_WORKSHOP_REVIVE.md §5-A）。
#
# ⚠ 戦闘を回さない。start_craft() / collect_craft() を直接呼ぶ。
# ⚠ 30分待たない。キューの started_at を巻き戻して完了させる。
# ⚠ 状態は書き換えるが保存しない（_report_unlock() と同じ）。
# ⚠ 素材は一度に配る。「足りるまで減らす／足す」ループを書かないこと（2026-08-24 の罠）。
# ⚠ この関数は _unlocked_ids() の手前で終わる。差し込む前に「次の func までどこまでか」を
#   見てある（2026-08-25 に _report_unlock() の途中へ差し込んだ）。
func _report_workshop() -> void:
	# --- 1. レシピが読めているか ---
	print("[DebugBoot] --- レシピ（recipes.json）---")
	var recipes: Array = GameManager.get_available_recipes()
	print("  解放済みで妥当なレシピ %d 件（⚠ 3 件が正解）" % recipes.size())
	for entry: Variant in recipes:
		var recipe: Dictionary = entry
		var draw_def: Variant = recipe.get(GameManager.RECIPE_DRAW, {})
		var entry_count: int = 0
		if draw_def is Dictionary:
			entry_count = ((draw_def as Dictionary).get(GameManager.CHEST_DRAW_ENTRIES, []) as Array).size()
		print("  %-14s %6ds  投入 %s  出るもの %s / 抽選 %d 件" % [
			str(recipe.get(GameManager.RECIPE_ID, "")),
			int(recipe.get(GameManager.RECIPE_DURATION_SEC, 0)),
			_io_summary(recipe.get(GameManager.RECIPE_INPUTS, [])),
			_io_summary(recipe.get(GameManager.RECIPE_OUTPUTS, [])),
			entry_count,
		])

	# --- 2. 抽選の分布（⚠ 良い素材ほど高い段階が出やすいこと）---
	print("[DebugBoot] --- 1000回引いたときの段階の分布 ---")
	for entry: Variant in recipes:
		var recipe: Dictionary = entry
		var draw_def: Variant = recipe.get(GameManager.RECIPE_DRAW, {})
		if not (draw_def is Dictionary) or (draw_def as Dictionary).is_empty():
			continue
		var tiers: Dictionary = {}
		var runes: int = 0
		for _i: int in range(1000):
			for item_id: String in GameManager._roll_recipe_draw(draw_def as Dictionary):
				var definition: Dictionary = MasterDataLoader.get_item(item_id)
				var tier: int = int(definition.get(GameManager.ITEM_MASTER_PART_TIER, 0))
				tiers[tier] = int(tiers.get(tier, 0)) + 1
				if str(definition.get(GameManager.ITEM_MASTER_PART_KIND, "")) == GameManager.PART_KIND_RUNE:
					runes += 1
		var columns: Array[String] = []
		for tier: int in [1, 2, 3, 4]:
			columns.append("段階%d %4d" % [tier, int(tiers.get(tier, 0))])
		print("  %-14s %s  / ⚠ ルーン %d 件（0 が正解）" % [
			str(recipe.get(GameManager.RECIPE_ID, "")), "  ".join(columns), runes
		])

	# --- 3. 作って受け取る ---
	print("[DebugBoot] --- 作って受け取る ---")
	# ⚠ 一度に配る。減らすために回さない。
	for tier: int in [1, 2, 3, 4]:
		GameManager.add_material("decor_material_%d" % tier, 500)
		GameManager.add_material("construction_material_%d" % tier, 5000)
	var first_id: String = str((recipes[0] as Dictionary).get(GameManager.RECIPE_ID, ""))
	var before_parts: int = _part_count()
	print("  start_craft('%s') = %s" % [first_id, str(GameManager.start_craft(first_id))])
	print("  2本目 start_craft('%s') = %s（⚠ キューが1本なので false が正解）" % [
		first_id, str(GameManager.start_craft(first_id))
	])
	_rewind_craft_queue()
	GameManager.refresh_crafting_queue_if_needed()
	var queue: Array = GameManager.get_crafting_queue()
	var queue_id: String = str((queue[0] as Dictionary).get(GameStateKeys.CRAFT_QUEUE_ID, ""))
	print("  巻き戻した後の status = %s" % str((queue[0] as Dictionary).get(GameStateKeys.CRAFT_STATUS, "")))
	print("  ⚠ output_item_id = '%s'（⚠ draw だけのレシピは空が正解）" % str(
		(queue[0] as Dictionary).get(GameStateKeys.CRAFT_OUTPUT_ITEM_ID, "")
	))
	print("  collect_craft() = %s" % str(GameManager.collect_craft(queue_id)))
	print("  装飾の所持数 %d -> %d（⚠ 1 増えるのが正解）" % [before_parts, _part_count()])
	print("  受け取り後のキュー %d 件（⚠ 0 が正解）" % GameManager.get_crafting_queue().size())

	# --- 4. 研究の作業場枝 ---
	print("[DebugBoot] --- 研究の作業場枝（craft_speed_bonus / craft_slot_bonus）---")
	print("  解放前  同時製作 %d 本 / 短縮 %d%% / 宝箱の抽選 +%d" % [
		GameManager.get_max_queue_slots(),
		GameManager.get_research_craft_speed_percent(),
		GameManager.get_research_chest_draw_bonus(),
	])
	# ⚠ 前提の順に何度も回す（_report_research() と同じ形）。
	for _pass_index: int in range(MasterDataLoader.get_all_research_nodes().size()):
		var unlocked_this_pass: int = 0
		for node_id: Variant in MasterDataLoader.get_all_research_nodes():
			if GameManager.unlock_research_node(str(node_id)):
				unlocked_this_pass += 1
		if unlocked_this_pass == 0:
			break
	print("  解放後  同時製作 %d 本 / 短縮 %d%% / 宝箱の抽選 +%d" % [
		GameManager.get_max_queue_slots(),
		GameManager.get_research_craft_speed_percent(),
		GameManager.get_research_chest_draw_bonus(),
	])
	print("     （⚠ 同時製作 1 -> 2 ／ 短縮 0 -> 20 が正解）")
	print("  start_craft('%s') = %s" % [first_id, str(GameManager.start_craft(first_id))])
	print("  2本目 start_craft('%s') = %s（⚠ キューが2本になったので true が正解）" % [
		first_id, str(GameManager.start_craft(first_id))
	])
	var after: Array = GameManager.get_crafting_queue()
	if not after.is_empty():
		var duration: Variant = (after[0] as Dictionary).get(GameStateKeys.CRAFT_DURATION_SEC, 0)
		print("  duration_sec = %s %s（⚠ 1440 かつ int が正解。⚠ 1800 のままなら短縮が乗っていない）" % [
			str(duration), type_string(typeof(duration))
		])
	# ⚠ 宝箱の枝が作業場のくじに乗っていないこと（EXEC_WORKSHOP_REVIVE.md 決め2）。
	var draw_first: Variant = (recipes[0] as Dictionary).get(GameManager.RECIPE_DRAW, {})
	var total_drawn: int = 0
	for _i: int in range(200):
		for item_id: String in GameManager._roll_recipe_draw(draw_first as Dictionary):
			total_drawn += 1
	print("  ⚠ 200回引いて出た件数 %d（⚠ 200 が正解。⚠ 宝箱の枝が乗っていると 200 を超える）" % total_drawn)

	# --- 5. 足した検証が本当に出るか（2箇所で壊す・キャッシュだけ）---
	# ⚠ recipes.json は触らない（git diff が最初から空のまま）。
	# ⚠ この枝だけ ERROR: を2本わざと出す。⚠ 赤が2本出るのが正解。
	print("[DebugBoot] --- 壊して確かめる（⚠ この下の赤2本が正解）---")
	var poisoned: Dictionary = MasterDataLoader._cache_recipes[first_id]
	# (a) draw.entries の item_id を空にする -> E129
	var rows: Array = (poisoned[GameManager.RECIPE_DRAW] as Dictionary)[GameManager.CHEST_DRAW_ENTRIES]
	var backup_row: Dictionary = (rows[0] as Dictionary).duplicate(true)
	(rows[0] as Dictionary)[GameManager.CHEST_DRAW_ITEM_ID] = ""
	print("  (a) draw.entries[0].item_id を空にした")
	MasterDataLoader._validate_all_item_refs()
	rows[0] = backup_row
	# (b) outputs も draw も無くす -> E129
	var backup_draw: Variant = poisoned[GameManager.RECIPE_DRAW]
	poisoned.erase(GameManager.RECIPE_DRAW)
	print("  (b) draw ごと消した（outputs は元から空）")
	MasterDataLoader._validate_all_item_refs()
	poisoned[GameManager.RECIPE_DRAW] = backup_draw
	print("  戻した -> レシピ %d 件 / 抽選 %d 件（⚠ 3 と 18 が正解）" % [
		MasterDataLoader.get_all_recipes().size(),
		((MasterDataLoader.get_recipe(first_id)[GameManager.RECIPE_DRAW] as Dictionary)[GameManager.CHEST_DRAW_ENTRIES] as Array).size(),
	])


# inputs / outputs を「id x個」の1行にする。⚠ tr() を使わない（ログのため）。
# 本番でないステージの接頭辞。⚠ stage_dbg_* を収支に混ぜない（決め2）。
# ⚠ rewards.gold が本番 50/80/120 に対して検証用は全部 1 で、
#   接頭辞以外に本番と検証を見分けられる欄が stages.json に無い。
# ⚠ この綴りは宿題35（リリース前に消すもの）が既に名指ししているもの。
const ECONOMY_DBG_STAGE_PREFIX: String = "stage_dbg_"

# 宝箱の期待値を出すのに引く回数。⚠ drops / workshop と同じ 1000 回。
const ECONOMY_DRAW_TRIALS: int = 1000


# 段階12（バランス実測）の報告。EXEC_BALANCE_ECONOMY.md §3。
#
# ⚠ 戦闘を1回も回さない（決め8）。1周で入るものは stages.json の rewards と
#   _roll_chest_draw() から出す。
# ⚠ 赤も黄も1本も足さない（決め1）。「出口が無い」は print で名指しするだけ。
# ⚠ 研究の解放はいちばん最後（決め5）。_roll_chest_draw() に宝箱枝が乗っているため、
#   先に解放すると素の期待値が二度と取れない。
# ⚠ MasterDataLoader が返す数値は float。int() で包み忘れると表に .0 が出る。
func _report_economy() -> void:
	var material_ids: Array[String] = _economy_material_ids()
	var sources: Dictionary = _economy_sources()
	var sinks: Dictionary = _economy_sinks()

	# --- 1. 素材16件の入口と出口 ---
	print("[DebugBoot] --- 素材の入口と出口（⚠ 16 件が正解）---")
	print("  素材 %d 件" % material_ids.size())
	var no_source: Array[String] = []
	var no_sink: Array[String] = []
	for material_id: String in material_ids:
		var in_list: Array = sources.get(material_id, [])
		var out_list: Array = sinks.get(material_id, [])
		if in_list.is_empty():
			no_source.append(material_id)
		if out_list.is_empty():
			no_sink.append(material_id)
		print("  %-24s 入口 %s" % [material_id, _economy_join(in_list)])
		print("  %-24s 出口 %s" % ["", _economy_join(out_list)])
	print("  ⚠ 入口が0件のもの %d 件: %s" % [no_source.size(), str(no_source)])
	print("  ⚠ 出口が0件のもの %d 件: %s" % [no_sink.size(), str(no_sink)])
	print("     （⚠ 赤にも黄にもしない。⚠ 穴かどうかは人間が決める＝決め1）")

	# --- 2. 1周で入るもの（研究0件のとき）---
	print("[DebugBoot] --- 1周で入るもの（⚠ 研究0件・勝った前提）---")
	print("  ⚠ 宝箱の行は式で出した期待値。⚠ 実測は scenario=floor の「1周あたりの宝箱」（100周）と突き合わせること")
	var stage_ids: Array[String] = _economy_stage_ids()
	print("  本番ステージ %d 本（⚠ stage_dbg_* は除いた）" % stage_ids.size())
	var stamina_cost: int = int(Balance.adventure.stamina_cost_per_stage)
	for stage_id: String in stage_ids:
		_economy_print_stage_row(stage_id, stamina_cost)

	# --- 3. Lv100 までの周回数と集中時間 ---
	print("[DebugBoot] --- Lv100 までに要る育成素材 ---")
	var config: CharacterConfig = Balance.character
	var level_material: String = str(config.level_up_material_id)
	# ⚠ 道具を疑う（決め4・§3-5）。式を直接評価した値が実装と一致するか。
	var members: Array = GameManager.get_party_members()
	var probe_id: String = str(members[0]) if not members.is_empty() else ""
	# ⚠ 上限は max_character_level（100）で測る。get_effective_level_cap() は
	#   研究を解放するまで 20 を返すので、そのまま使うと「Lv20 までの表」になる。
	var cap: int = int(config.max_character_level)
	var total_one: int = _economy_level_total(cap)
	var from_impl: int = 0
	if probe_id != "":
		from_impl = int(GameManager.get_level_up_cost(probe_id).get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	var from_formula: int = _economy_level_cost_at(1)
	print("  ⚠ Lv1 の突き合わせ 実装 %d / 式 %d -> %s" % [
		from_impl, from_formula, "一致" if from_impl == from_formula else "⚠ 式の評価が実装とずれている"
	])
	print("  上限 Lv%d（⚠ 研究0件のときの実効上限は Lv%d）/ 素材 %s" % [
		cap, GameManager.get_effective_level_cap(probe_id), level_material
	])
	# ⚠ 式は character_config.gd の @export 既定値（.tres に行が無い＝設計役が直せる）。
	#   .tres に行があるのは base / growth / level_up_material_id の3行だけ
	#   （EXEC_BALANCE_TUNE.md §0-2。⚠ 以前ここは「式も人間しか直せない」と書いていた）。
	print("  式 '%s'（⚠ character_config.gd の既定値）/ base=%d growth=%s（⚠ .tres の2行＝人間だけ）" % [
		str(config.level_up_cost_formula),
		int(config.base_level_up_cost), str(config.cost_growth_per_level),
	])
	print("  ⚠ 1キャラ %d 個 / 3キャラ %d 個" % [total_one, total_one * 3])

	print("[DebugBoot] --- Lv100 までの周回数と集中時間（⚠ 3キャラぶん）---")
	var focus_per_potion: int = int(Balance.pomodoro.potion_focus_minutes_per_unit)
	var stamina_per_potion: int = int(Balance.pomodoro.stamina_potion_recovery)
	print("  1周 %d スタミナ / ポーション1個 +%d スタミナ / 集中 %d 分で1個" % [
		stamina_cost, stamina_per_potion, focus_per_potion
	])
	# ⚠ ズレ44（2026-08-28に直した）。⚠ ここは以前 stages.json の固定報酬だけを
	#   数えていた。⚠ 段階14-b で宝箱が「移動に紐づく」に変わって以降、
	#   実態のほぼ半分しか見ておらず、⚠ floor_5 を 33.3 時間と報告していた。
	# ⚠ 固定と宝箱を両方出す。⚠ どちらを触ったのかが前後の差で分かるようにするため。
	print("  ⚠ 「固定」は stages.json の rewards ／「宝箱」は移動に紐づく期待値（＋必ず通るショップの無料ガチャ）")
	for stage_id: String in stage_ids:
		var fixed_run: int = _economy_stage_material(stage_id, level_material)
		var all_run: float = _economy_stage_material_all(stage_id, level_material)
		if all_run <= 0.0:
			print("  %-10s %s が 0 個/周 -> ⚠ ∞（このステージでは上がらない）" % [stage_id, level_material])
			continue
		var runs: int = int(ceil(float(total_one * 3) / all_run))
		var stamina_total: int = runs * stamina_cost
		var focus_min: int = int(ceil(float(stamina_total) / float(stamina_per_potion) * float(focus_per_potion)))
		print("  %-10s 固定 %d ＋ 宝箱 %.2f ＝ %.2f 個/周 -> %d 周 / スタミナ %d / 集中 %d 分（%.1f 時間）" % [
			stage_id, fixed_run, all_run - float(fixed_run), all_run,
			runs, stamina_total, focus_min, float(focus_min) / 60.0
		])

	# --- 4. 研究20件の総コスト ---
	print("[DebugBoot] --- 研究の総コストと入口 ---")
	var research_cost: Dictionary = _economy_research_cost()
	var research_total: int = 0
	for material_id: String in research_cost:
		research_total += int(research_cost[material_id])
	print("  ノード %d 件 / 合計 %d 個" % [MasterDataLoader.get_all_research_nodes().size(), research_total])
	for material_id: String in material_ids:
		if not research_cost.has(material_id):
			continue
		var need: int = int(research_cost[material_id])
		var best_stage: String = ""
		var best_per_run: float = 0.0
		# ⚠ ズレ44。⚠ ここも宝箱を数える。⚠ construction_material_3 / _4 は
		#   固定報酬が細いぶん、宝箱の寄与が相対的に大きい。
		for stage_id: String in stage_ids:
			var per_run: float = _economy_stage_material_all(stage_id, material_id)
			if per_run > best_per_run:
				best_per_run = per_run
				best_stage = stage_id
		if best_per_run > 0.0:
			print("  %-24s %4d 個  最良 %s が %.2f 個/周（固定 %d ＋宝箱）-> %d 周" % [
				material_id, need, best_stage, best_per_run,
				_economy_stage_material(best_stage, material_id),
				int(ceil(float(need) / best_per_run))
			])
		else:
			print("  %-24s %4d 個  ⚠ どのステージからも落ちない -> %s" % [
				material_id, need, _economy_shop_line(material_id)
			])

	# --- 5. ゴールドの入口 ---
	print("[DebugBoot] --- ゴールドの入口（⚠ ショップの支払い元）---")
	# ⚠ 宿題63。⚠ ボスだけでなく道中の戦闘ぶんを足した「1周の実入り」を出す。
	#   ⚠ ここが たいまつ（0/50/150/400 G）と フロア内回復（60 G）の桁の基準になる。
	for stage_id: String in stage_ids:
		var boss_g: int = _economy_stage_gold(stage_id)
		var node_g: int = _economy_node_gold(stage_id)
		var exp_n: float = _economy_battle_nodes_expected(stage_id)
		print("  %-10s %.1f G/周（ボス %d ＋ 道中 %d × %.2f 回）" % [
			stage_id, float(boss_g) + node_g * exp_n, boss_g, node_g, exp_n
		])

	# --- 6. 研究を全部解放してから、宝箱の期待値を測り直す（⚠ いちばん最後）---
	print("[DebugBoot] --- 研究を全部解放したあとの1周 ---")
	for material_id: String in material_ids:
		GameManager.add_material(material_id, 999999)
	for _pass_index: int in range(MasterDataLoader.get_all_research_nodes().size()):
		var unlocked_this_pass: int = 0
		for node_id: Variant in MasterDataLoader.get_all_research_nodes():
			if GameManager.unlock_research_node(str(node_id)):
				unlocked_this_pass += 1
		if unlocked_this_pass == 0:
			break
	print("  宝箱の抽選 +%d" % GameManager.get_research_chest_draw_bonus())
	for stage_id: String in stage_ids:
		_economy_print_stage_row(stage_id, stamina_cost)
	print("     （⚠ 研究0件のときより宝箱の期待値が大きいのが正解＝枝が生きている）")

	# --- 7. 宿題12（inventory の count が float で戻る）---
	# ⚠ UIから到達できない経路なので、ここで見る（EXEC_BALANCE_ECONOMY.md A-10）。
	# ⚠ load_state() はセーブを書かない。SaveManager は呼ばないこと。
	# ⚠ この枝で状態を丸ごと入れ替えるので、⚠ 必ずいちばん最後に置く。
	print("[DebugBoot] --- 宿題12：セーブから戻した count の型 ---")
	var probe_item: String = "part_gem_hp_1"
	var probe_save: Dictionary = {
		GameStateKeys.SAVE_VERSION: 3,
		GameStateKeys.INVENTORY: {
			probe_item: {
				GameStateKeys.ITEM_COUNT: 5.0,
				GameStateKeys.ITEM_TYPE: GameStateKeys.ITEM_TYPE_PART,
			},
			# ⚠ Dictionary でない値を混ぜる。⚠ 落ちないことを同じ枝で見る。
			"⚠ 壊れた行": 1.0,
		},
	}
	print("  渡した count = 5.0 (%s)" % type_string(typeof(5.0)))
	print("  load_state() = %s" % str(GameManager.load_state(probe_save)))
	var loaded: Variant = GameManager.get_state().get(GameStateKeys.INVENTORY, {}).get(probe_item, {})
	var loaded_count: Variant = (loaded as Dictionary).get(GameStateKeys.ITEM_COUNT, null) if loaded is Dictionary else null
	print("  戻ってきた count = %s (%s)（⚠ int が正解。⚠ 直す前は float だった）" % [
		str(loaded_count), type_string(typeof(loaded_count))
	])
	print("  get_item_count('%s') = %d" % [probe_item, GameManager.get_item_count(probe_item)])


# 素材（storage == material）のIDを綴り順で返す。
# ⚠ IDの綴りから素材かどうかを推測しない。items.json の storage で判定する。
func _economy_material_ids() -> Array[String]:
	var ids: Array[String] = []
	var all_items: Dictionary = MasterDataLoader.get_all_items()
	for item_id: String in all_items:
		var definition: Dictionary = all_items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_STORAGE, "")) == GameManager.ITEM_STORAGE_MATERIAL:
			ids.append(item_id)
	ids.sort()
	return ids


# 本番ステージのIDを綴り順で返す（決め2）。
func _economy_stage_ids() -> Array[String]:
	var ids: Array[String] = []
	for stage_id: Variant in MasterDataLoader._cache_stages:
		if str(stage_id).begins_with(ECONOMY_DBG_STAGE_PREFIX):
			continue
		ids.append(str(stage_id))
	ids.sort()
	return ids


# 素材の入口。{material_id: [説明の行]}。
# ⚠ 出口を作る _economy_sinks() と対になっている。片方だけ直さないこと（決め9）。
func _economy_sources() -> Dictionary:
	var out: Dictionary = {}
	# (a) ステージの固定報酬
	for stage_id: String in _economy_stage_ids():
		var rewards: Dictionary = MasterDataLoader.get_stage(stage_id).get(GameStateKeys.BATTLE_REWARDS, {})
		var mats: Variant = rewards.get(GameStateKeys.REWARD_MATERIALS, {})
		if mats is Dictionary:
			for material_id: String in (mats as Dictionary):
				_economy_add(out, material_id, "%s x%d/周" % [stage_id, int((mats as Dictionary)[material_id])])
	# (b) 宝箱（固定と抽選の両方）
	for chest_id: Variant in MasterDataLoader.get_all_chests():
		var chest: Dictionary = MasterDataLoader.get_chest(str(chest_id))
		var chest_rewards: Variant = chest.get(GameStateKeys.BATTLE_REWARDS, {})
		if chest_rewards is Dictionary:
			var chest_mats: Variant = (chest_rewards as Dictionary).get(GameStateKeys.REWARD_MATERIALS, {})
			if chest_mats is Dictionary:
				for material_id: String in (chest_mats as Dictionary):
					_economy_add(out, material_id, "宝箱 %s x%d" % [
						str(chest_id), int((chest_mats as Dictionary)[material_id])
					])
		var draw_def: Variant = chest.get(GameManager.CHEST_DRAW, {})
		if draw_def is Dictionary:
			for row: Variant in ((draw_def as Dictionary).get(GameManager.CHEST_DRAW_ENTRIES, []) as Array):
				var drawn_id: String = str((row as Dictionary).get(GameManager.CHEST_DRAW_ITEM_ID, ""))
				if drawn_id == "":
					continue
				_economy_add(out, drawn_id, "宝箱 %s の抽選" % str(chest_id))
	# (c) ショップ
	for shop_type: Variant in MasterDataLoader.get_all_shop_types():
		for slot: Variant in MasterDataLoader.get_shop_slots(str(shop_type)):
			var row: Dictionary = slot
			if str(row.get(GameManager.SHOP_SLOT_PAYOUT_TYPE, "")) != GameManager.PAYOUT_TYPE_MATERIAL:
				continue
			var cost: Dictionary = row.get(GameStateKeys.SHOP_COST, {})
			_economy_add(out, str(row.get(GameStateKeys.SHOP_ITEM_ID, "")), "%s x%d を %d %s（在庫 %d）" % [
				str(shop_type),
				int(row.get(GameManager.SHOP_SLOT_PAYOUT_COUNT, 0)),
				int(cost.get(GameStateKeys.COST_AMOUNT, 0)),
				str(cost.get(GameStateKeys.COST_CURRENCY_TYPE, "")),
				int(row.get(GameStateKeys.SHOP_STOCK_LIMIT, 0)),
			])
	# (d) 分解（装備 -> 鍛冶素材 / 装飾 -> 装飾素材）
	for tier: int in range(1, GameManager.get_forge_material_tier_count() + 1):
		_economy_add(out, "forging_material_%d" % tier, "装備の分解（返却率 %s）" % str(
			Balance.equipment.dismantle_refund_ratio
		))
	var dismantle_by_tier: Array[int] = Balance.part.dismantle_by_tier
	for tier: int in range(1, dismantle_by_tier.size() + 1):
		_economy_add(out, "decor_material_%d" % tier, "装飾を壊す x%d" % int(dismantle_by_tier[tier - 1]))
	return out


# 素材の出口。{material_id: [説明の行]}。
func _economy_sinks() -> Dictionary:
	var out: Dictionary = {}
	# (a) レベルアップ
	_economy_add(out, str(Balance.character.level_up_material_id), "レベルアップ")
	# (b) 鍛冶（等級2..上限）
	var max_grade: int = GameManager.get_max_equipment_grade()
	for grade: int in range(2, max_grade + 1):
		_economy_add(out, "forging_material_%d" % GameManager.get_forge_material_tier(grade), "鍛冶 等級%d x%d" % [
			grade, GameManager.get_forge_cost_amount(grade)
		])
	# (c) 装飾の段階上げ（段階 n -> n+1 に decor_material_<n> を払う）
	var upgrade_cost: Array[int] = Balance.part.upgrade_cost_by_tier
	for tier: int in range(1, upgrade_cost.size() + 1):
		_economy_add(out, "decor_material_%d" % tier, "装飾 段階%d->%d x%d" % [
			tier, tier + 1, int(upgrade_cost[tier - 1])
		])
	# (d) 研究
	var research_cost: Dictionary = _economy_research_cost()
	for material_id: String in research_cost:
		_economy_add(out, material_id, "研究 合計 x%d" % int(research_cost[material_id]))
	# (e) 作業場のレシピ
	for recipe_id: Variant in MasterDataLoader.get_all_recipes():
		var recipe: Dictionary = MasterDataLoader.get_recipe(str(recipe_id))
		for row: Variant in (recipe.get(GameManager.RECIPE_INPUTS, []) as Array):
			_economy_add(out, str((row as Dictionary).get(GameManager.RECIPE_IO_ITEM_ID, "")), "作業場 %s x%d" % [
				str(recipe_id), int((row as Dictionary).get(GameManager.RECIPE_IO_COUNT, 0))
			])
	return out


# 研究20件のコストを素材ごとに合計する。{material_id: 合計}
func _economy_research_cost() -> Dictionary:
	var out: Dictionary = {}
	var nodes: Dictionary = MasterDataLoader.get_all_research_nodes()
	for node_id: Variant in nodes:
		var node: Dictionary = nodes[node_id]
		var material_id: String = str(node.get(GameManager.RESEARCH_NODE_COST_MATERIAL_ID, ""))
		if material_id == "":
			continue
		out[material_id] = int(out.get(material_id, 0)) + int(node.get(GameManager.RESEARCH_NODE_COST_AMOUNT, 0))
	return out


# ステージ1周で入る素材の個数（固定報酬のみ・宝箱は含まない）。
func _economy_stage_material(stage_id: String, material_id: String) -> int:
	var rewards: Dictionary = MasterDataLoader.get_stage(stage_id).get(GameStateKeys.BATTLE_REWARDS, {})
	var mats: Variant = rewards.get(GameStateKeys.REWARD_MATERIALS, {})
	if not (mats is Dictionary):
		return 0
	return int((mats as Dictionary).get(material_id, 0))


func _economy_stage_gold(stage_id: String) -> int:
	var rewards: Dictionary = MasterDataLoader.get_stage(stage_id).get(GameStateKeys.BATTLE_REWARDS, {})
	return int(rewards.get(GameStateKeys.REWARD_GOLD, 0))


# --- 道中の戦闘ノード（宿題63・2026-08-28） ---
#
# ⚠ 1周のゴールドは「ボスの固定報酬」だけでは無くなった。⚠ 道中の戦闘ノード1つにつき
#   node_rewards.gold が入る。⚠ 何回戦うかはルート次第なので、期待値と幅の両方を出す。
# ⚠ 期待値は「無作為にルートを選んだとき」＝ run_floor_auto() と同じモデル。
#   ⚠ プレイヤーは戦闘を避けることも狙うこともできるので、実際は幅の中で動く。

func _economy_node_gold(floor_id: String) -> int:
	var raw: Variant = MasterDataLoader.get_stage(floor_id).get(GameManager.STAGE_MASTER_NODE_REWARDS, null)
	if not (raw is Dictionary):
		return 0
	return int((raw as Dictionary).get(GameStateKeys.REWARD_GOLD, 0))


# 1周で踏む戦闘ノードの期待回数（無作為ルート）。
#
# ⚠ ボスは含まない（ボスの報酬は rewards 側）。
# ⚠ 層1（入口）も含まない。⚠ start_floor() が「戦わずに position に置く」ので、
#   ⚠ 入口のノードは一度も戦闘にならない（2026-08-28に発見＝ズレ47）。
#   ⚠ 数え始めを 2 にしないと、実測 2.85 に対して式が 3.50 を返す。
func _economy_battle_nodes_expected(floor_id: String) -> float:
	var layers: int = _economy_floor_layer_count(floor_id)
	var total: float = 0.0
	for layer: int in range(2, layers + 1):
		var weights: Dictionary = GameManager.get_floor_layer_weights(layer)
		var sum: int = 0
		for kind: String in weights:
			sum += int(weights[kind])
		if sum <= 0:
			continue
		total += float(int(weights.get(GameStateKeys.FLOOR_NODE_KIND_BATTLE, 0))) / float(sum)
	return total


# 1周で踏む戦闘ノードの最少・最多（層ごとに battle があり得るかで数える）。
# ⚠ 層1（入口）は数えない。⚠ 上と同じ理由（ズレ47）。
func _economy_battle_nodes_range(floor_id: String) -> Array[int]:
	var layers: int = _economy_floor_layer_count(floor_id)
	var low: int = 0
	var high: int = 0
	for layer: int in range(2, layers + 1):
		var weights: Dictionary = GameManager.get_floor_layer_weights(layer)
		if not weights.has(GameStateKeys.FLOOR_NODE_KIND_BATTLE):
			continue
		high += 1
		# ⚠ その層が battle しか無いなら避けられない。
		if weights.size() == 1:
			low += 1
	return [low, high]


# 1周の行を1本出す。⚠ 研究の前後で2回呼ぶので関数にしてある。
func _economy_print_stage_row(stage_id: String, stamina_cost: int) -> void:
	var rewards: Dictionary = MasterDataLoader.get_stage(stage_id).get(GameStateKeys.BATTLE_REWARDS, {})
	var mats: Variant = rewards.get(GameStateKeys.REWARD_MATERIALS, {})
	var columns: Array[String] = []
	if mats is Dictionary:
		var keys: Array = (mats as Dictionary).keys()
		keys.sort()
		for material_id: Variant in keys:
			columns.append("%s x%d" % [str(material_id), int((mats as Dictionary)[material_id])])
	var inventory: Variant = rewards.get(GameStateKeys.REWARD_INVENTORY, {})
	var inv_columns: Array[String] = []
	if inventory is Dictionary:
		for item_id: String in (inventory as Dictionary):
			inv_columns.append("%s x%d" % [item_id, int((inventory as Dictionary)[item_id])])
	# ⚠ 宿題63。⚠ ゴールドは「ボス」＋「道中の戦闘 × 回数」になった。
	#   ⚠ 回数はルート次第なので、期待値（無作為ルート）と幅の両方を出す。
	var boss_gold: int = _economy_stage_gold(stage_id)
	var node_gold: int = _economy_node_gold(stage_id)
	if node_gold > 0:
		var expected: float = _economy_battle_nodes_expected(stage_id)
		var span: Array[int] = _economy_battle_nodes_range(stage_id)
		print("  %-10s ボス %d G ＋ 道中 %d G × 期待 %.2f 回 = %.1f G（幅 %d〜%d G）/ スタミナ -%d / 宝箱 %s" % [
			stage_id, boss_gold, node_gold, expected, float(boss_gold) + node_gold * expected,
			boss_gold + node_gold * span[0], boss_gold + node_gold * span[1], stamina_cost,
			_economy_chest_expectation(str(rewards.get(GameStateKeys.CHEST_ID, ""))),
		])
	else:
		print("  %-10s %4d G / スタミナ -%d / 宝箱 %s" % [
			stage_id, boss_gold, stamina_cost,
			_economy_chest_expectation(str(rewards.get(GameStateKeys.CHEST_ID, ""))),
		])
	print("  %-10s 素材 %s" % ["", " + ".join(columns) if not columns.is_empty() else "（無し）"])
	print("  %-10s 持ち物 %s" % ["", " + ".join(inv_columns) if not inv_columns.is_empty() else "（無し）"])
	# ⚠ ズレ44。⚠ 上の「素材」は stages.json の固定報酬だけ。⚠ 段階14-b 以降、
	#   1周で入るものの過半は「移動に紐づく宝箱」から来ている。
	var chest_mats: Dictionary = _economy_floor_chest_materials(stage_id)
	if chest_mats.is_empty():
		return
	# ⚠ 素材と持ち物（装備・装飾）を分けて出す。混ぜると1行が長すぎて読めない。
	var known_materials: Array[String] = _economy_material_ids()
	var chest_keys: Array = chest_mats.keys()
	chest_keys.sort()
	var mat_columns: Array[String] = []
	var item_columns: Array[String] = []
	for item_id: Variant in chest_keys:
		var column: String = "%s x%.2f" % [str(item_id), float(chest_mats[item_id])]
		if known_materials.has(str(item_id)):
			mat_columns.append(column)
		else:
			item_columns.append(column)
	# ⚠ 5フロアとも同じ数字が出るのが正解（層数6・出現率が共通のため）。
	#   ⚠ 層数か floor_chest_chance_pct をフロアごとに変えたらここが割れる。
	print("  %-10s ⚠ 宝箱 %.2f 個/周%s" % [
		"", _economy_floor_chest_count(stage_id),
		"（＋必ず通るショップの無料ガチャ 1回）" if _economy_floor_has_forced_shop(stage_id) else "",
	])
	print("  %-10s ⚠ 宝箱の素材 %s" % ["", " + ".join(mat_columns) if not mat_columns.is_empty() else "（無し）"])
	print("  %-10s ⚠ 宝箱の持ち物 %s" % ["", " + ".join(item_columns) if not item_columns.is_empty() else "（無し）"])


# 宝箱1個の期待値（1周あたり何個出るか）を文字列で返す。
# ⚠ _roll_chest_draw() には研究の宝箱枝が乗っている（決め5）。呼ぶ順番で値が変わる。
func _economy_chest_expectation(chest_id: String) -> String:
	if chest_id == "":
		return "（無し）"
	var chest: Dictionary = MasterDataLoader.get_chest(chest_id)
	var draw_def: Variant = chest.get(GameManager.CHEST_DRAW, {})
	if not (draw_def is Dictionary) or (draw_def as Dictionary).is_empty():
		return "%s（抽選なし）" % chest_id
	var total: int = 0
	for _i: int in range(ECONOMY_DRAW_TRIALS):
		var rolled: Dictionary = GameManager._roll_chest_draw(draw_def as Dictionary)
		for item_id: String in rolled:
			total += int(rolled[item_id])
	return "%s 期待値 %.2f 個/周" % [chest_id, float(total) / float(ECONOMY_DRAW_TRIALS)]


# --- 1周で入る宝箱の期待値（ズレ44・2026-08-28） ---
#
# ⚠ なぜ足したか：段階14-b で宝箱が「移動に紐づく」に変わったので、
#   stages.json の rewards だけ数えていたこの道具は、1周で入るものの
#   半分しか見なくなっていた（floor_5 は 6 個/周 と出るが実際は約 12 個/周）。
#   ⚠ この数字を根拠に数値を決めると、実態の2倍きつく調整してしまう。
#
# ⚠ 抽選を回さず式で出す（決め4・「level_up_character() を99回回さない」と同じ理由）。
#   _roll_chest_draw() を回すと研究の宝箱枝が乗り、呼ぶ順番で値が変わる。
# ⚠ 実装（GameManager._roll_floor_chest）と式が一致していることは
#   _report_economy() の突き合わせ行が見張る。ずれたらそちらが先に鳴る。

# 宝箱1個ぶんの素材期待値。⚠ {material_id: float}。装備・装飾の枠は数えない。
func _economy_draw_material_expect(chest_id: String) -> Dictionary:
	var out: Dictionary = {}
	if chest_id == "":
		return out
	var chest: Dictionary = MasterDataLoader.get_chest(chest_id)
	# ⚠ 固定報酬の宝箱（generic / bonus_*）は draw を持たない。materials を直接読む。
	var fixed: Variant = chest.get(GameStateKeys.BATTLE_REWARDS, {})
	if fixed is Dictionary:
		var fixed_mats: Variant = (fixed as Dictionary).get(GameStateKeys.REWARD_MATERIALS, {})
		if fixed_mats is Dictionary:
			for material_id: Variant in (fixed_mats as Dictionary):
				out[str(material_id)] = float((fixed_mats as Dictionary)[material_id])
	var draw_def: Variant = chest.get(GameManager.CHEST_DRAW, {})
	if not (draw_def is Dictionary) or (draw_def as Dictionary).is_empty():
		return out
	var entries: Array = (draw_def as Dictionary).get(GameManager.CHEST_DRAW_ENTRIES, [])
	var rolls: int = int((draw_def as Dictionary).get(GameManager.CHEST_DRAW_ROLLS, 1))
	var total_weight: int = 0
	for row: Variant in entries:
		total_weight += maxi(0, int((row as Dictionary).get(GameManager.CHEST_DRAW_WEIGHT, 0)))
	if total_weight <= 0:
		return out
	for row: Variant in entries:
		var item_id: String = str((row as Dictionary).get(GameManager.CHEST_DRAW_ITEM_ID, ""))
		if item_id == "":
			continue
		var weight: int = maxi(0, int((row as Dictionary).get(GameManager.CHEST_DRAW_WEIGHT, 0)))
		var count: int = maxi(1, int((row as Dictionary).get(GameManager.CHEST_DRAW_COUNT, 1)))
		var add: float = float(rolls) * float(weight) / float(total_weight) * float(count)
		out[item_id] = float(out.get(item_id, 0.0)) + add
	return out


# 層 ℓ に着いたときの、宝箱1個ぶんの素材期待値。⚠ レアリティ分布で混ぜる。
func _economy_layer_material_expect(floor_id: String, layer: int) -> Dictionary:
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	var chest_ids: Variant = stage.get(GameManager.STAGE_MASTER_CHEST_IDS, {})
	if not (chest_ids is Dictionary):
		return {}
	var table: Dictionary = {
		GameManager.CHEST_RARITY_COMMON: Balance.floor.chest_weight_common,
		GameManager.CHEST_RARITY_RARE: Balance.floor.chest_weight_rare,
		GameManager.CHEST_RARITY_EPIC: Balance.floor.chest_weight_epic,
		GameManager.CHEST_RARITY_LEGENDARY: Balance.floor.chest_weight_legendary,
	}
	var total: int = 0
	var weights: Dictionary = {}
	for rarity: String in table:
		var row: Array = table[rarity]
		if row.is_empty():
			continue
		# ⚠ 実装と同じ clampi（配列より深い層に着いたら末尾を使う）。
		var w: int = maxi(0, int(row[clampi(layer - 1, 0, row.size() - 1)]))
		weights[rarity] = w
		total += w
	var out: Dictionary = {}
	if total <= 0:
		return out
	for rarity: String in weights:
		var share: float = float(weights[rarity]) / float(total)
		if share <= 0.0:
			continue
		var per_chest: Dictionary = _economy_draw_material_expect(
			str((chest_ids as Dictionary).get(rarity, ""))
		)
		for material_id: String in per_chest:
			out[material_id] = float(out.get(material_id, 0.0)) + share * float(per_chest[material_id])
	return out


# 1周ぶん（入口 -> ボス）の宝箱の期待個数。
#
# ⚠ 移動は層数と同じ回数。着く層は 2, 3, ... , L, L+1（ボス）。
# ⚠ 最低1回の保証は「ボスに着いた時点で0個なら確定で出す」なので、
#   最後の1回だけ確率が p ではなく p + (1-p)^L になる。
func _economy_floor_chest_count(floor_id: String) -> float:
	var layers: int = _economy_floor_layer_count(floor_id)
	if layers <= 0:
		return 0.0
	var p: float = float(int(Balance.floor.chest_chance_pct)) / 100.0
	return float(layers) * p + pow(1.0 - p, float(layers))


# 1周ぶんの宝箱から入る素材。⚠ {material_id: float}。
func _economy_floor_chest_materials(floor_id: String) -> Dictionary:
	var layers: int = _economy_floor_layer_count(floor_id)
	var out: Dictionary = {}
	if layers <= 0:
		return out
	var p: float = float(int(Balance.floor.chest_chance_pct)) / 100.0
	for move: int in range(1, layers + 1):
		# ⚠ move 回目に着く層。最後の1回がボス（層 L+1）。
		var layer: int = move + 1
		var chance: float = p
		if move == layers:
			chance = p + pow(1.0 - p, float(layers))
		var per_chest: Dictionary = _economy_layer_material_expect(floor_id, layer)
		for material_id: String in per_chest:
			out[material_id] = float(out.get(material_id, 0.0)) + chance * float(per_chest[material_id])
	# ⚠ 無料ガチャ。⚠ 「必ず通る層」がある場合だけ数える。
	#   ⚠ 抽選で出る shop は、在っても行けるとは限らない（PLAN_SCENARIO_MAP.md §10-2-C）。
	if _economy_floor_has_forced_shop(floor_id):
		var gacha: Dictionary = _economy_draw_material_expect(GameManager.FLOOR_GACHA_CHEST_ID)
		for material_id: String in gacha:
			out[material_id] = float(out.get(material_id, 0.0)) + float(gacha[material_id])
	return out


func _economy_floor_layer_count(floor_id: String) -> int:
	var raw: Variant = MasterDataLoader.get_stage(floor_id).get(GameManager.STAGE_MASTER_LAYERS, null)
	if not (raw is Array):
		return 0
	return (raw as Array).size()


# ⚠ 「必ず通るショップの層」があるか。⚠ node_count に関係なく、
#   その層の重みが shop だけなら、どのノードを選んでも shop になる。
func _economy_floor_has_forced_shop(floor_id: String) -> bool:
	var raw: Variant = MasterDataLoader.get_stage(floor_id).get(GameManager.STAGE_MASTER_LAYERS, null)
	if not (raw is Array):
		return false
	for layer: Variant in (raw as Array):
		var weights: Variant = (layer as Dictionary).get(GameManager.LAYER_WEIGHTS, {})
		if not (weights is Dictionary):
			continue
		var kinds: Array = (weights as Dictionary).keys()
		if kinds.size() != 1:
			continue
		if str(kinds[0]) != GameStateKeys.FLOOR_NODE_KIND_SHOP:
			continue
		if int((weights as Dictionary)[kinds[0]]) > 0:
			return true
	return false


# 固定報酬 ＋ 宝箱で、1周に入る素材の合計。⚠ float（宝箱は期待値なので端数が出る）。
func _economy_stage_material_all(stage_id: String, material_id: String) -> float:
	return float(_economy_stage_material(stage_id, material_id)) \
		+ float(_economy_floor_chest_materials(stage_id).get(material_id, 0.0))


# Lv1 -> cap に要る素材の合計。⚠ level_up_character() を99回回さない（決め4）。
func _economy_level_total(cap: int) -> int:
	var total: int = 0
	for level: int in range(1, cap):
		total += _economy_level_cost_at(level)
	return total


# そのレベルから1つ上げるのに要る個数。get_level_up_cost() の中身と同じ式・同じ引数。
func _economy_level_cost_at(level: int) -> int:
	var config: CharacterConfig = Balance.character
	var base: float = float(config.base_level_up_cost)
	var growth: float = config.cost_growth_per_level
	return GrowthFormula.evaluate_int(
		config.level_up_cost_formula,
		{"base": base, "growth": growth, "level": float(level)},
		base + growth * float(level - 1)
	)


# その素材をショップで買うときの行（どのステージからも落ちない素材のため）。
func _economy_shop_line(material_id: String) -> String:
	var rows: Array[String] = []
	for shop_type: Variant in MasterDataLoader.get_all_shop_types():
		for slot: Variant in MasterDataLoader.get_shop_slots(str(shop_type)):
			var row: Dictionary = slot
			if str(row.get(GameStateKeys.SHOP_ITEM_ID, "")) != material_id:
				continue
			var cost: Dictionary = row.get(GameStateKeys.SHOP_COST, {})
			rows.append("%s x%d を %d %s（1周期に %d 回まで）" % [
				str(shop_type),
				int(row.get(GameManager.SHOP_SLOT_PAYOUT_COUNT, 0)),
				int(cost.get(GameStateKeys.COST_AMOUNT, 0)),
				str(cost.get(GameStateKeys.COST_CURRENCY_TYPE, "")),
				int(row.get(GameStateKeys.SHOP_STOCK_LIMIT, 0)),
			])
	if rows.is_empty():
		return "⚠ ショップにも無い"
	return " / ".join(rows)


func _economy_add(table: Dictionary, material_id: String, line: String) -> void:
	if material_id == "":
		return
	if not table.has(material_id):
		table[material_id] = []
	(table[material_id] as Array).append(line)


func _economy_join(list: Array) -> String:
	if list.is_empty():
		return "⚠ 無し"
	return " / ".join(list)


func _io_summary(list: Variant) -> String:
	if not (list is Array) or (list as Array).is_empty():
		return "（無し）"
	var columns: Array[String] = []
	for entry: Variant in (list as Array):
		if entry is Dictionary:
			columns.append("%s x%d" % [
				str((entry as Dictionary).get(GameManager.RECIPE_IO_ITEM_ID, "")),
				int((entry as Dictionary).get(GameManager.RECIPE_IO_COUNT, 0)),
			])
	return " + ".join(columns)


# 手持ちの装飾（ルーンを除く）の合計個数。
func _part_count() -> int:
	var total: int = 0
	var inventory: Dictionary = GameManager.get_state().get(GameStateKeys.INVENTORY, {})
	for item_id: String in inventory:
		var definition: Dictionary = MasterDataLoader.get_item(item_id)
		if str(definition.get(GameManager.ITEM_MASTER_PART_KIND, "")) == "":
			continue
		if str(definition.get(GameManager.ITEM_MASTER_PART_KIND, "")) == GameManager.PART_KIND_RUNE:
			continue
		total += int((inventory[item_id] as Dictionary).get(GameStateKeys.ITEM_COUNT, 0))
	return total


# 製作キューの started_at を duration_sec ぶん巻き戻す。⚠ 30分待たないため。
# ⚠ 状態を直接触るのは tests だけ。本番コードでこれをしないこと。
func _rewind_craft_queue() -> void:
	var queue: Array = GameManager._state[GameStateKeys.CRAFTING_QUEUE]
	for i: int in range(queue.size()):
		var entry: Dictionary = queue[i]
		entry[GameStateKeys.CRAFT_STARTED_AT] = int(entry[GameStateKeys.CRAFT_STARTED_AT]) - int(entry[GameStateKeys.CRAFT_DURATION_SEC]) - 1
		queue[i] = entry
	GameManager._state[GameStateKeys.CRAFTING_QUEUE] = queue



# 開いている画面IDを、get_all_screen_ids() の順に並べて返す。
# ⚠ Dictionary のキー順（＝開いた順）だと差分が読みにくい。
func _unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	for screen_id: String in GameManager.get_all_screen_ids():
		if GameManager.is_screen_unlocked(screen_id):
			result.append(screen_id)
	return result


# ルーンの下ごしらえ（段階8・EXEC_RUNES.md §3-L）。
#
# ⚠ 装備を作って等級を上げ、ルーン枠に刺して、着ける。ここまでやらないと
#   ルーンは1件も戦闘に届かない（枠が開くのは等級5から）。
# ⚠ 状態は書き換えるが保存しない（_ready() の注意書きと同じ）。
# ⚠ 刺す位置は決め打ちしない。get_part_slot_defs() が「ルーンだけが刺さる枠」と
#   言っている位置を順に使う（枠の並びを変えてもここは直さなくてよい）。
func _apply_runes(scenario: Dictionary) -> void:
	var table: Dictionary = scenario.get("runes", {})
	if table.is_empty():
		return
	# ⚠ 等級を上げるのに素材が要る。F4 の「素材を全種類」と同じ経路で配る。
	for material_id: Variant in MasterDataLoader.get_all_items():
		var definition: Dictionary = MasterDataLoader.get_all_items()[material_id]
		if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_MATERIAL:
			GameManager.add_material(str(material_id), 99999)

	var base_item: Dictionary = {
		GameStateKeys.EQUIP_WEAPON: "weapon_iron_sword",
		GameStateKeys.EQUIP_ACCESSORY: "acc_ring_power",
	}

	for raw_character_id: Variant in table.keys():
		var character_id: String = str(raw_character_id)
		var by_slot: Dictionary = table[raw_character_id]
		for raw_slot: Variant in by_slot.keys():
			var equip_slot: String = str(raw_slot)
			var rune_ids: Array = by_slot[raw_slot]

			GameManager.add_to_inventory(
				str(base_item.get(equip_slot, "")), 1, GameStateKeys.ITEM_TYPE_EQUIPMENT
			)
			var instance_id: String = _newest_instance()
			# 等級を上げられるだけ上げる（ルーン枠が開くのは等級5）。
			while GameManager.forge_equipment(instance_id):
				pass

			var positions: Array[int] = _rune_slot_positions(equip_slot)
			for i: int in range(rune_ids.size()):
				if i >= positions.size():
					push_error("[DebugBoot] %s のルーン枠は %d 個しか無い" % [equip_slot, positions.size()])
					break
				var rune_id: String = str(rune_ids[i])
				GameManager.add_to_inventory(rune_id, 1, GameStateKeys.ITEM_TYPE_PART)
				if not GameManager.attach_part(instance_id, positions[i], rune_id):
					push_error("[DebugBoot] attach_part('%s', %d, '%s') が false" % [
						instance_id, positions[i], rune_id
					])
			if not GameManager.equip_instance(character_id, equip_slot, instance_id):
				push_error("[DebugBoot] equip_instance('%s', '%s', '%s') が false" % [
					character_id, equip_slot, instance_id
				])

	# 移動量。⚠ 既定（choices の先頭）と違う値を選ばせる行がシナリオにある。
	var move_table: Dictionary = scenario.get("rune_move", {})
	for raw_character_id: Variant in move_table.keys():
		var moves: Dictionary = move_table[raw_character_id]
		for raw_rune_id: Variant in moves.keys():
			if not GameManager.set_rune_move(str(raw_character_id), str(raw_rune_id), int(moves[raw_rune_id])):
				push_error("[DebugBoot] set_rune_move('%s', '%s') が false" % [
					str(raw_character_id), str(raw_rune_id)
				])

	# ⚠ 紐付けは戦闘が始まる前に出しておく。戦闘中のログだけでは
	#   「乗らなかった」のが CD なのか紐付いていないのか読めない。
	print("[DebugBoot] --- ルーンの紐付け（武器＝スキル1 / アクセ＝スキル2）---")
	for character_id: Variant in GameManager.get_party_members():
		print("  %-20s skills=%s runes=%s" % [
			str(character_id),
			str(GameManager.get_battle_skills(str(character_id))),
			str(GameManager.get_battle_runes(str(character_id))),
		])


# その部位で「ルーンだけが刺さる枠」の位置。⚠ 位置を決め打ちしない。
func _rune_slot_positions(equip_slot: String) -> Array[int]:
	var result: Array[int] = []
	for def: Variant in GameManager.get_part_slot_defs(equip_slot):
		if not (def is Dictionary):
			continue
		var kinds: Variant = (def as Dictionary).get(GameManager.PART_VIEW_KINDS, [])
		if kinds is Array and (kinds as Array).size() == 1 				and str((kinds as Array)[0]) == GameManager.PART_KIND_RUNE:
			result.append(int((def as Dictionary).get(GameManager.PART_VIEW_INDEX, 0)))
	return result


# いちばん最後に作られた装備の個体。
# ⚠ _find_instance_of() は同じ item_id の1つ目を返すので、2個目を作ると取り違える。
func _newest_instance() -> String:
	var next_id: int = int(GameManager.get_state().get(GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID, 1))
	return GameManager.INSTANCE_ID_PREFIX + str(next_id - 1)


# --- kind=report ------------------------------------------------

# 素材の4段階と装備の等級10を、数値で1画面に出す（EXEC_MATERIAL_TIERS.md §6-A / §6-B）。
#
# ⚠ 戦闘を回さないので battle_last.jsonl は書かれない。ここの出口は print だけ
#   （tests/ は print が出口。NEXT_STEPS §4）。
# ⚠ 状態は書き換えるが保存しない。SaveManager をこのファイルから呼ばないこと
#   （_ready() の注意書きと同じ理由）。
func _report_materials() -> void:
	print("[DebugBoot] --- 素材（items.json）---")
	var items: Dictionary = MasterDataLoader.get_all_items()
	var material_ids: Array[String] = []
	for item_id: Variant in items:
		var definition: Dictionary = items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_MATERIAL:
			continue
		material_ids.append(str(item_id))
	var sort_key: String = GameManager.INSTANCE_VIEW_SORT_ORDER
	material_ids.sort_custom(func(a: String, b: String) -> bool:
		return int(items[a].get(sort_key, 0)) < int(items[b].get(sort_key, 0)))
	for material_id: String in material_ids:
		print("  %-26s sort=%2d  %s" % [
			material_id, int(items[material_id].get(sort_key, 0)), tr("ui_res_" + material_id)
		])
	print("  合計 %d 件" % material_ids.size())

	# --- 倉庫の素材タブ（2026-09-10・人間の指示「素材を見れるようにしたい」）---
	#
	# ⚠ 画面の絵は取れないが、⚠ 「何件並ぶか」「0個も並ぶか」「個数が入るか」は取れる。
	# ⚠ item_type で数えた上の一覧と、⚠ storage で数える画面側の一覧が
	#   食い違っていないことも一緒に見る（⚠ items.json の2つの欄がズレていたら赤）。
	print("[DebugBoot] --- 倉庫の素材タブ（GameManager.get_material_slot_entries）---")
	var slot_entries: Array = GameManager.get_material_slot_entries()
	print("  マスの数 = %d（⚠ 上の合計 %d と同じが正解）" % [slot_entries.size(), material_ids.size()])
	if slot_entries.size() != material_ids.size():
		push_error("[DebugBoot] items.json の item_type と storage の素材の数が食い違っている")
	var zero_count: int = 0
	for entry: Variant in slot_entries:
		var row: Dictionary = entry
		if int(row.get(GameManager.SLOT_ENTRY_COUNT, -1)) < 0:
			push_error("[DebugBoot] 素材のマスに個数が入っていない: %s" % str(
				row.get(GameManager.SLOT_ENTRY_ITEM_ID, "")
			))
		if int(row.get(GameManager.SLOT_ENTRY_COUNT, 0)) == 0:
			zero_count += 1
	print("  0個のマス = %d（⚠ 0個でも並ぶのが正解＝1件でも並べば効いている）" % zero_count)
	print("  並び（先頭4件）= %s" % str(GameManager.get_material_ids().slice(0, 4)))
	# ⚠ 増やしたら、⚠ そのマスの個数だけが変わること（⚠ 並びは変わらない）。
	var probe_id: String = str(GameManager.get_material_ids()[0])
	var probe_before: int = GameManager.get_material_count(probe_id)
	GameManager.add_material(probe_id, 7)
	var probe_entries: Array = GameManager.get_material_slot_entries()
	print("  %s を7個増やした -> マスの個数 %d（⚠ %d が正解）/ マスの数 %d（⚠ 変わらないこと）" % [
		probe_id,
		int((probe_entries[0] as Dictionary).get(GameManager.SLOT_ENTRY_COUNT, 0)),
		probe_before + 7,
		probe_entries.size(),
	])
	if int((probe_entries[0] as Dictionary).get(GameManager.SLOT_ENTRY_COUNT, 0)) != probe_before + 7:
		push_error("[DebugBoot] 素材のマスの個数が増えていない")

	var max_grade: int = GameManager.get_max_equipment_grade()
	print("[DebugBoot] --- 鍛冶（上限=等級%d）---" % max_grade)
	for grade: int in range(2, max_grade + 1):
		var material_id: String = GameManager.get_forge_material_id(grade)
		print("  等級%2d へ  段階%d  %-22s x%d" % [
			grade, GameManager.get_forge_material_tier(grade),
			material_id, GameManager.get_forge_cost_amount(grade)
		])

	print("[DebugBoot] --- 分解（実際に鍛えてから戻す）---")
	# ⚠ 素材を配ってから鍛える。can_forge() が本番と同じ判定を通ることも一緒に見る。
	for tier: int in range(1, GameManager.get_forge_material_tier_count() + 1):
		GameManager.add_material(GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX + str(tier), 9999)

	GameManager.add_to_inventory("weapon_iron_sword", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	var owned: Array = GameManager.get_owned_instances()
	if owned.is_empty():
		push_error("[DebugBoot] 個体が作られなかった（add_to_inventory が個体を作っていない）")
		return
	var instance_id: String = str(owned[owned.size() - 1].get(GameManager.INSTANCE_VIEW_ID, ""))

	var paid: Dictionary = {}
	for grade: int in range(1, max_grade + 1):
		if grade in [1, 5, max_grade]:
			print("  等級%2d の分解 → %s（合計 %d / 払った合計 %d）" % [
				grade, str(GameManager.get_dismantle_refund(instance_id)),
				GameManager.get_dismantle_refund_total(instance_id), _sum_values(paid)
			])
		if grade >= max_grade:
			continue
		var cost: Dictionary = GameManager.get_forge_cost(instance_id)
		var cost_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
		paid[cost_id] = int(paid.get(cost_id, 0)) + int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
		# ⚠ 次の等級の見込み（2026-09-14）。⚠ 鍛えた後の実際の値と一致しなければ赤。
		var preview: Dictionary = GameManager.get_instance_stats_at_grade(instance_id, grade + 1)
		if not GameManager.forge_equipment(instance_id):
			push_error("[DebugBoot] 等級%d から鍛えられなかった" % grade)
			return
		var actual: Dictionary = GameManager.get_instance_stats(instance_id)
		if preview != actual:
			push_error("[DebugBoot] 次の等級の見込み %s と鍛えた後 %s が違う（等級%d）" % [str(preview), str(actual), grade + 1])
		elif grade + 1 in [2, 5, max_grade]:
			print("  等級%2d の見込み = 鍛えた後 atk=%d" % [grade + 1, int(actual.get("atk", 0))])

	# ⚠ 上限に達したあと、もう1回叩いても上がらないこと。
	if GameManager.forge_equipment(instance_id):
		push_error("[DebugBoot] 上限（等級%d）を超えて鍛えられた" % max_grade)
	else:
		print("  等級%d で打ち止め（forge_equipment が false）" % max_grade)


# 装飾の報告（EXEC_DECORATION.md §3-K）。
#
# ⚠ 状態は書き換えるが絶対に保存しない（_ready() のコメント）。
# ⚠ 乱数は固定しない。seed() を打つと出目が Godot の RNG 実装に依存し、
#   「値が変わったら赤」という壊れやすい完了条件になる（EXEC_DECORATION.md §0-3 の11）。
#   代わりに「範囲に収まっているか」と「2種類以上出るか」で見る。
func _report_parts() -> void:
	# ⚠ 在庫を持たない装飾を1つ残しておく（PART_REJECT_STOCK を出すため）。
	var reserved_id: String = "part_charm_mdef_4"

	# --- 1. items.json の装飾 ---
	print("[DebugBoot] --- 装飾（items.json）---")
	var items: Dictionary = MasterDataLoader.get_all_items()
	var sort_key: String = GameManager.INSTANCE_VIEW_SORT_ORDER
	var part_ids: Array[String] = []
	for item_id: Variant in items:
		var definition: Dictionary = items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_PART:
			continue
		part_ids.append(str(item_id))
	part_ids.sort_custom(func(a: String, b: String) -> bool:
		return int(items[a].get(sort_key, 0)) < int(items[b].get(sort_key, 0)))

	var mismatched: int = 0
	for part_id: String in part_ids:
		var d: Dictionary = GameManager.get_part_definition(part_id)
		var expected: String = GameManager.PART_ID_FORMAT % [
			str(d.get(GameManager.ITEM_MASTER_PART_KIND, "")),
			str(d.get(GameManager.ITEM_MASTER_PART_STAT, "")),
			int(d.get(GameManager.ITEM_MASTER_PART_TIER, 0)),
		]
		# ⚠ ルーンには軸が無いので欄からIDを組み立てられない。ここでは数えない
		#   （E124 が runes.json と1:1で突き合わせている）。
		if expected != part_id and GameManager.get_rune_definition(part_id).is_empty():
			mismatched += 1
		print("  %-26s %-7s %-10s 段階%d  base=%3d  roll=0〜%-2d  %s" % [
			part_id,
			str(d.get(GameManager.ITEM_MASTER_PART_KIND, "")),
			str(d.get(GameManager.ITEM_MASTER_PART_STAT, "")),
			int(d.get(GameManager.ITEM_MASTER_PART_TIER, 0)),
			int(d.get(GameManager.ITEM_MASTER_PART_BASE, 0)),
			int(d.get(GameManager.ITEM_MASTER_PART_ROLL_MAX, 0)),
			tr("ui_res_" + part_id),
		])
	print("  合計 %d 件（⚠ IDと欄の綴りが一致しないもの %d 件）" % [part_ids.size(), mismatched])

	# --- 2. 部位ごとの枠の表（GAME_DESIGN.md 6-4）---
	print("[DebugBoot] --- 部位ごとの枠（位置 / 開く等級 / 刺さる種類）---")
	for slot: String in GameManager.get_equip_slots():
		var cells: Array[String] = []
		for def: Variant in GameManager.get_part_slot_defs(slot):
			var kinds: Array = (def as Dictionary).get(GameManager.PART_VIEW_KINDS, [])
			if kinds.is_empty():
				cells.append("[%d]—" % int((def as Dictionary).get(GameManager.PART_VIEW_INDEX, 0)))
				continue
			cells.append("[%d]等級%d:%s" % [
				int((def as Dictionary).get(GameManager.PART_VIEW_INDEX, 0)),
				int((def as Dictionary).get(GameManager.PART_VIEW_MIN_GRADE, 0)),
				"/".join(kinds),
			])
		print("  %-10s %s" % [slot, "  ".join(cells)])

	# --- 3. 等級ごとに開く枠の数 ---
	print("[DebugBoot] --- 等級ごとに開く枠の数 ---")
	for slot: String in [GameStateKeys.EQUIP_HEAD, GameStateKeys.EQUIP_WEAPON, GameStateKeys.EQUIP_ACCESSORY]:
		var counts: Array[String] = []
		for grade: int in range(1, GameManager.get_max_equipment_grade() + 1):
			counts.append("%d:%d" % [grade, GameManager.get_open_part_slot_count(slot, grade)])
		print("  %-10s %s" % [slot, "  ".join(counts)])

	# --- 下ごしらえ：素材と装飾を配る ---
	# ⚠ 前はここで倉庫の上限を外していた（⚠ 2026-10-03・回3-d で容量そのものを消した）。
	for tier: int in range(1, GameManager.get_forge_material_tier_count() + 1):
		GameManager.add_material(GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX + str(tier), 99999)
	for tier: int in range(1, GameManager.get_max_part_tier() + 1):
		GameManager.add_material(GameManager.get_decor_material_id(tier), 99999)
	for part_id: String in part_ids:
		if part_id == reserved_id:
			continue
		GameManager.add_to_inventory(part_id, 300, GameStateKeys.ITEM_TYPE_PART)

	GameManager.add_to_inventory("armor_iron_helm", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	var helm_id: String = _find_instance_of("armor_iron_helm")
	if helm_id == "":
		push_error("[DebugBoot] 個体が作られなかった（add_to_inventory が個体を作っていない）")
		return
	while GameManager.forge_equipment(helm_id):
		pass

	# --- 4. 刺す → 加算 → 外して壊れる ---
	print("[DebugBoot] --- 刺す → 加算 → 外して壊れる ---")
	var char_id: String = "char_priest"
	GameManager.equip_instance(char_id, GameStateKeys.EQUIP_HEAD, helm_id)

	var test_id: String = "part_gem_hp_4"
	var stock_before: int = GameManager.get_item_count(test_id)
	var hp_before: int = int(GameManager.get_effective_stats(char_id).get(GameStateKeys.STAT_HP, 0))
	if not GameManager.attach_part(helm_id, 0, test_id):
		push_error("[DebugBoot] 刺せなかった: " + test_id)
		return
	var value: int = GameManager.get_part_stat_value(_part_entry_at(helm_id, 0))
	var hp_after: int = int(GameManager.get_effective_stats(char_id).get(GameStateKeys.STAT_HP, 0))
	print("  刺した %s  hp %d -> %d（差 %d / 装飾の値 %d）" % [
		test_id, hp_before, hp_after, hp_after - hp_before, value
	])
	print("  在庫 %d -> %d（刺すと1つ減る）" % [stock_before, GameManager.get_item_count(test_id)])

	var decor_id: String = GameManager.get_decor_material_id(4)
	var mat_before: int = GameManager.get_material_count(decor_id)
	GameManager.detach_part(helm_id, 0)
	var hp_detached: int = int(GameManager.get_effective_stats(char_id).get(GameStateKeys.STAT_HP, 0))
	print("  外した  hp %d -> %d（刺す前と同じか: %s）" % [
		hp_after, hp_detached, str(hp_detached == hp_before)
	])
	print("  壊れて %s が %d -> %d（+%d）／ 在庫は %d のまま（戻らないこと）" % [
		decor_id, mat_before, GameManager.get_material_count(decor_id),
		GameManager.get_material_count(decor_id) - mat_before, GameManager.get_item_count(test_id)
	])

	# --- 5. ロールの範囲（100回・乱数は固定しない）---
	var rolls: Dictionary = {}
	var min_roll: int = 99999
	var max_roll: int = -1
	for i: int in range(100):
		if not GameManager.attach_part(helm_id, 0, test_id):
			push_error("[DebugBoot] ロールの試行で刺せなくなった（%d回目）" % i)
			break
		var roll: int = int((_part_entry_at(helm_id, 0) as Dictionary).get(GameStateKeys.PART_ROLL, -1))
		rolls[roll] = int(rolls.get(roll, 0)) + 1
		min_roll = mini(min_roll, roll)
		max_roll = maxi(max_roll, roll)
		GameManager.detach_part(helm_id, 0)
	var roll_max: int = int(GameManager.get_part_definition(test_id).get(GameManager.ITEM_MASTER_PART_ROLL_MAX, 0))
	print("[DebugBoot] --- ロール100回（%s / 上限 %d）---" % [test_id, roll_max])
	print("  最小 %d / 最大 %d / 出た種類 %d（範囲内か: %s）" % [
		min_roll, max_roll, rolls.size(), str(min_roll >= 0 and max_roll <= roll_max)
	])

	# --- 6. 刺せない理由（6通り）---
	print("[DebugBoot] --- 刺せない理由（判定1〜6が別々のキーを返すこと）---")
	print("  1 個体が無い       -> '%s'" % GameManager.get_part_reject_reason("eq_9999", 0, test_id))

	GameManager.add_to_inventory("armor_leather_cap", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	var cap_id: String = _find_instance_of("armor_leather_cap")
	print("  2 枠が開いていない -> '%s'（等級1の頭）" % GameManager.get_part_reject_reason(cap_id, 0, test_id))

	GameManager.attach_part(helm_id, 0, test_id)
	print("  3 枠が埋まっている -> '%s'（宝石枠1）" % GameManager.get_part_reject_reason(helm_id, 0, test_id))
	print("  4 知らない装飾     -> '%s'" % GameManager.get_part_reject_reason(helm_id, 1, "part_gem_hp_99"))

	GameManager.add_to_inventory("weapon_iron_sword", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	var sword_id: String = _find_instance_of("weapon_iron_sword")
	while GameManager.forge_equipment(sword_id):
		pass
	# ⚠ 枠の種類は部位ではなく枠で決まる。武器にも宝石枠（位置0・等級3）はある。
	#   種類で弾かれるのはルーン枠（位置2・等級5）に宝石を刺そうとしたとき。
	print("  5 枠の種類が違う   -> '%s'（武器のルーン枠に宝石）" % GameManager.get_part_reject_reason(sword_id, 2, test_id))
	print("    ⚠ 同じ武器の宝石枠（位置0）には刺さる -> '%s'（空文字が正解）" % GameManager.get_part_reject_reason(sword_id, 0, test_id))
	print("  6 在庫が無い       -> '%s'（%s を1つも持っていない）" % [
		GameManager.get_part_reject_reason(helm_id, 4, reserved_id), reserved_id
	])

	# --- 6-b. ワイルド枠と、アクセサリーだけの2つ目のルーン枠 ---
	print("[DebugBoot] --- 特別枠（等級5）---")
	print("  防具のワイルド枠（位置2）に宝石 -> '%s'（空文字が正解）" % GameManager.get_part_reject_reason(helm_id, 2, "part_gem_atk_1"))
	print("  防具のワイルド枠（位置2）に護符 -> '%s'（空文字が正解）" % GameManager.get_part_reject_reason(helm_id, 2, "part_charm_def_1"))
	print("  防具のワイルド枠（位置2）に紋章 -> '%s'（空文字が正解）" % GameManager.get_part_reject_reason(helm_id, 2, "part_emblem_haste_1"))
	print("  防具の位置3（アクセ専用）      -> '%s'（locked が正解）" % GameManager.get_part_reject_reason(helm_id, 3, "part_gem_atk_1"))
	GameManager.add_to_inventory("acc_ring_power", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	var acc_id: String = _find_instance_of("acc_ring_power")
	while GameManager.forge_equipment(acc_id):
		pass
	print("  アクセの位置2/3 に刺さる種類   -> %s / %s（どちらもルーン枠）" % [
		str(GameManager.get_part_kinds_for_slot_index(GameStateKeys.EQUIP_ACCESSORY, 2)),
		str(GameManager.get_part_kinds_for_slot_index(GameStateKeys.EQUIP_ACCESSORY, 3)),
	])
	print("  アクセのルーン枠（位置2）にルーン -> '%s'（空文字が正解）" % GameManager.get_part_reject_reason(acc_id, 2, "part_rune_shield_1"))
	print("  アクセのルーン枠（位置2）に宝石   -> '%s'（kind が正解）" % GameManager.get_part_reject_reason(acc_id, 2, "part_gem_atk_1"))

	# --- 7. 段階上げと壊す ---
	print("[DebugBoot] --- 段階上げ（分解方式）と壊す ---")
	for tier: int in range(1, GameManager.get_max_part_tier() + 1):
		var pid: String = "part_gem_atk_%d" % tier
		var cost: Dictionary = GameManager.get_part_upgrade_cost(pid)
		var amount: int = int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0))
		var up_text: String = "—（上限）"
		if amount > 0:
			up_text = "%s x%d -> %s" % [
				str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, "")), amount,
				GameManager.get_upgraded_part_id(pid)
			]
		print("  段階%d  上げる: %-38s  壊す: %s" % [
			tier, up_text, str(GameManager.get_part_dismantle_refund(pid, 1))
		])

	var next_before: int = GameManager.get_item_count("part_gem_atk_2")
	var upgraded: bool = GameManager.upgrade_part("part_gem_atk_1")
	print("  upgrade_part('part_gem_atk_1') -> %s（part_gem_atk_2 が %d -> %d）" % [
		str(upgraded), next_before, GameManager.get_item_count("part_gem_atk_2")
	])
	print("  upgrade_part('part_gem_atk_4') -> %s（上限なので false が正解）" % str(
		GameManager.upgrade_part("part_gem_atk_4")
	))
	print("  dismantle_part('part_gem_atk_2', 3) -> %s" % str(
		GameManager.dismantle_part("part_gem_atk_2", 3)
	))
	print("  ⚠ 上げるのに払うのは decor_material_<いまの段階>、壊して返るのは decor_material_<その段階>。")
	print("     段階1→2 は _1 を10払い、段階2を壊すと _2 が5返る。同じ素材が増える経路は無い。")

	_report_runes(acc_id)


# ルーン（段階8・EXEC_RUNES.md §6-C）。
# ⚠ 戦闘の挙動そのものは scenario=runes で見る。ここで見るのは
#   「データが揃っているか」「重ねられるか」「移動量が保存されるか」の3つだけ。
func _report_runes(acc_id: String) -> void:
	print("[DebugBoot] --- ルーン（runes.json）---")
	var runes: Dictionary = MasterDataLoader.get_all_runes()
	var rune_ids: Array[String] = []
	for rune_id: Variant in runes:
		rune_ids.append(str(rune_id))
	rune_ids.sort()
	for rune_id: String in rune_ids:
		var rune: Dictionary = runes[rune_id]
		var effects: Variant = rune.get(MasterDataLoader.RUNE_EFFECTS, [])
		var kinds: Array[String] = []
		if effects is Array:
			for raw_effect: Variant in (effects as Array):
				if raw_effect is Dictionary:
					kinds.append(str((raw_effect as Dictionary).get("type", "")))
		print("  %-24s 段階%d CD=%4.1f 効果=%-12s 移動=%-28s next=%-24s %s" % [
			rune_id,
			int(GameManager.get_part_definition(rune_id).get(GameManager.ITEM_MASTER_PART_TIER, 0)),
			float(rune.get(MasterDataLoader.RUNE_COOLDOWN_SEC, 0.0)),
			str(kinds),
			str(GameManager.get_rune_move_choices(rune_id)),
			str(rune.get(MasterDataLoader.RUNE_NEXT_ID, "—")),
			tr("ui_res_" + rune_id),
		])
	print("  合計 %d 件" % rune_ids.size())

	# --- ステータスを1つも足さないこと（EXEC_RUNES.md §6-C の19）---
	print("[DebugBoot] --- ルーンはステータスを足さない ---")
	var before: Dictionary = GameManager.get_instance_stats(acc_id)
	GameManager.add_to_inventory("part_rune_shield_1", 4, GameStateKeys.ITEM_TYPE_PART)
	var attached: bool = GameManager.attach_part(acc_id, 2, "part_rune_shield_1")
	var after: Dictionary = GameManager.get_instance_stats(acc_id)
	print("  attach_part(アクセ, 枠2, part_rune_shield_1) -> %s" % str(attached))
	print("  刺す前 %s" % str(before))
	print("  刺した後 %s（⚠ 同じであること。⚠ W18 の黄も出ないこと）" % str(after))

	# --- 重ねる（GAME_DESIGN.md 7-7）---
	print("[DebugBoot] --- 重ねる ---")
	print("  upgrade_part('part_rune_shield_1') -> %s（⚠ 分解方式では上がらない。false が正解・赤も出ないこと）" % str(
		GameManager.upgrade_part("part_rune_shield_1")
	))
	var merge_cost: int = GameManager.get_rune_merge_count()
	var t1_before: int = GameManager.get_item_count("part_rune_shield_1")
	var t2_before: int = GameManager.get_item_count("part_rune_shield_2")
	var merged: bool = GameManager.merge_runes("part_rune_shield_1")
	print("  merge_runes('part_rune_shield_1') -> %s（段階1 %d -> %d / 段階2 %d -> %d・%d個で1個）" % [
		str(merged), t1_before, GameManager.get_item_count("part_rune_shield_1"),
		t2_before, GameManager.get_item_count("part_rune_shield_2"), merge_cost,
	])
	# ⚠ 在庫を1個だけにしてから呼ぶ（stock で弾かれるか）。
	#   ⚠ merge を繰り返して減らさないこと（前の章で大量に配っているので百回以上回る）。
	GameManager._remove_from_inventory("part_rune_shield_1", GameManager.get_item_count("part_rune_shield_1") - 1)
	var stock_before: int = GameManager.get_item_count("part_rune_shield_1")
	print("  在庫 %d 個で merge -> %s / 理由 '%s'（在庫は %d のまま）" % [
		stock_before, str(GameManager.merge_runes("part_rune_shield_1")),
		GameManager.get_rune_merge_reject_reason("part_rune_shield_1"),
		GameManager.get_item_count("part_rune_shield_1"),
	])
	GameManager.add_to_inventory("part_rune_shield_5", merge_cost, GameStateKeys.ITEM_TYPE_PART)
	print("  段階5 で merge -> %s / 理由 '%s'（⚠ かけらは今回作っていない）" % [
		str(GameManager.merge_runes("part_rune_shield_5")),
		GameManager.get_rune_merge_reject_reason("part_rune_shield_5"),
	])
	print("  宝石で merge -> 理由 '%s'（kind が正解）" % GameManager.get_rune_merge_reject_reason("part_gem_atk_1"))
	print("  ルーンを壊す -> %s（⚠ 空が正解。かけらの器が無いので素材にならない）" % str(
		GameManager.get_part_dismantle_refund("part_rune_shield_5", 1)
	))

	# --- 移動量（GAME_DESIGN.md 7-7・キャラプリセットの5つ目のキー）---
	print("[DebugBoot] --- 移動量 ---")
	var character_id: String = str(GameManager.get_party_members()[0])
	var move_id: String = "part_rune_move_5"
	print("  choices(%s) = %s" % [move_id, str(GameManager.get_rune_move_choices(move_id))])
	print("  未設定のとき get_rune_move() -> %d（choices の先頭が正解）" % GameManager.get_rune_move(character_id, move_id))
	# ⚠ 既定（choices の先頭）と違う値を選ぶこと。同じ値だと「効いた」が読めない。
	print("  set_rune_move(120) -> %s / いま %d" % [
		str(GameManager.set_rune_move(character_id, move_id, 120)),
		GameManager.get_rune_move(character_id, move_id),
	])
	print("  set_rune_move(999)  -> %s / いま %d（⚠ 弾かれて変わらないこと）" % [
		str(GameManager.set_rune_move(character_id, move_id, 999)),
		GameManager.get_rune_move(character_id, move_id),
	])
	print("  set_rune_move(宝石) -> %s（移動系でないので false が正解）" % str(
		GameManager.set_rune_move(character_id, "part_gem_atk_1", 60)
	))

	# --- プリセットが5つ目のキーを運ぶか ---
	print("[DebugBoot] --- キャラプリセットの5つ目のキー ---")
	GameManager.save_character_preset(character_id, 0)
	var preset: Dictionary = GameManager.get_character_presets(character_id)[0]
	print("  焼いた rune_move = %s" % str(preset.get(GameStateKeys.GROWTH_RUNE_MOVE, null)))
	GameManager.set_rune_move(character_id, move_id, 60)
	print("  60 に変えてから適用 -> ok=%s" % str(
		GameManager.apply_character_preset(character_id, 0).get("ok", null)
	))
	print("  適用後 get_rune_move() -> %d（120 に戻っていること）" % GameManager.get_rune_move(character_id, move_id))

	# --- 足した検証が本当に出るか（2箇所で壊す・メモリ上の状態だけ）---
	print("[DebugBoot] --- 壊して確かめる ---")
	var growth: Dictionary = GameManager.get_character_growth(character_id)
	var broken: Dictionary = (growth.get(GameStateKeys.GROWTH_RUNE_MOVE, {}) as Dictionary).duplicate(true)
	broken[move_id] = 777
	broken["part_gem_atk_1"] = 60
	print("  壊した rune_move = %s" % str(broken))
	growth[GameStateKeys.GROWTH_RUNE_MOVE] = broken
	GameManager._write_growth(character_id, growth)
	GameManager._normalize_skill_slots_from_save()
	print("  正規化が残したもの -> %s（777 と宝石が落ちること）" % str(
		GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	))
	# ⚠ アクセを装備していないとルーンが誰にも紐づかない。先に着ける。
	var acc_instance: String = _find_instance_of("acc_ring_power")
	GameManager.equip_instance(character_id, GameStateKeys.EQUIP_ACCESSORY, acc_instance)
	print("  刺さっているルーンのIDを壊す -> get_battle_runes() が %s" % str(
		_broken_rune_lookup(character_id)
	))


# 刺さっているルーンのIDを存在しないものに書き換えて、get_battle_runes() が
# その1件だけ落とすかを見る。⚠ 壊すのはメモリ上の状態だけ（保存しない）。
func _broken_rune_lookup(character_id: String) -> Dictionary:
	var instance_id: String = GameManager.get_equipped_instance_id(character_id, GameStateKeys.EQUIP_ACCESSORY)
	if instance_id == "":
		return {"skipped": "アクセを装備していない"}
	if GameManager.get_battle_skills(character_id).size() < 2:
		return {"skipped": "スキル枠が2つ無い"}
	GameManager.attach_part(instance_id, 3, "part_rune_buff_1")
	var before: int = _count_runes(GameManager.get_battle_runes(character_id))
	# ⚠ 壊すのはメモリ上の状態だけ（_report_presets_normalize と同じ流儀）。
	var instance: Dictionary = GameManager.get_equipment_instance(instance_id)
	var parts: Array = instance.get(GameStateKeys.INSTANCE_PARTS, [])
	parts[3] = {GameStateKeys.PART_ITEM_ID: "part_rune_does_not_exist", GameStateKeys.PART_ROLL: 0}
	instance[GameStateKeys.INSTANCE_PARTS] = parts
	GameManager._write_instance(instance_id, instance)
	var after: int = _count_runes(GameManager.get_battle_runes(character_id))
	return {"before": before, "after": after}


func _count_runes(by_skill: Dictionary) -> int:
	var total: int = 0
	for raw_list: Variant in by_skill.values():
		if raw_list is Array:
			total += (raw_list as Array).size()
	return total



# 開いている枠のうち、位置 index のものの中身（{item_id, roll} または null）。
# ⚠ get_part_entries() は開いている枠だけを返し、位置は詰めない。
#   配列の添字ではなく index で探すこと。
func _part_entry_at(instance_id: String, index: int) -> Variant:
	for view: Variant in GameManager.get_part_entries(instance_id):
		if view is Dictionary and int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, -1)) == index:
			return (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
	return null

# 指定の item_id の個体IDを1つ返す。無ければ ""。
func _find_instance_of(item_id: String) -> String:
	for view: Variant in GameManager.get_owned_instances():
		if not (view is Dictionary):
			continue
		if str((view as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == item_id:
			return str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
	return ""


func _sum_values(table: Dictionary) -> int:
	var total: int = 0
	for value: Variant in table.values():
		total += int(value)
	return total


# ステージの抽選ドロップ（EXEC_STAGE_DROPS.md §3-G）。
#
# ⚠ 戦闘を1回も回さない。見るのは GameManager が返す数値と _state の中身だけ。
# ⚠ SaveManager を呼ばない。人間のセーブを黙って書き換えない（_ready の注記と同じ）。
# ⚠ 乱数を固定しない。分布で見る（EXEC_STAGE_DROPS.md §0-1 の9）。
func _report_drops() -> void:
	# --- 1. chests.json の全エントリ ---
	print("[DebugBoot] --- 宝箱の定義（chests.json）---")
	var chests: Dictionary = MasterDataLoader.get_all_chests()
	var ids: Array[String] = []
	for chest_id: Variant in chests:
		ids.append(str(chest_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(chests[a].get("sort_order", 0)) < int(chests[b].get("sort_order", 0)))

	for chest_id: String in ids:
		var chest: Dictionary = chests[chest_id]
		var fixed: Variant = chest.get(GameStateKeys.CHEST_REWARDS, null)
		var draw_def: Variant = chest.get(GameManager.CHEST_DRAW, null)
		var kind: String = ""
		if fixed is Dictionary:
			kind += "固定%s " % str((fixed as Dictionary).get(GameStateKeys.REWARD_MATERIALS, {}))
		if draw_def is Dictionary:
			kind += "抽選(当たり率 %.1f%% / rolls=%d)" % [
				_draw_hit_pct(draw_def as Dictionary),
				int((draw_def as Dictionary).get(GameManager.CHEST_DRAW_ROLLS, 1)),
			]
		print("  %-13s %-22s %s" % [chest_id, str(chest.get(GameManager.CHEST_NAME_KEY, "")), kind])
	print("  合計 %d 件" % ids.size())

	# --- 2. stages.json がどの宝箱を指しているか ---
	print("[DebugBoot] --- ステージ → 宝箱 ---")
	# ⚠ 段階14-b で「1周につき宝箱1個」の固定報酬を外した。宝箱は移動に紐づく
	#   （PLAN_SCENARIO_MAP.md §4）。なので rewards.chest_id は5フロアとも空が正解。
	for stage_id: String in ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "stage_dbg_area"]:
		var rewards: Variant = MasterDataLoader.get_stage(stage_id).get("rewards", {})
		var cid: String = ""
		if rewards is Dictionary:
			cid = str((rewards as Dictionary).get(GameStateKeys.CHEST_ID, ""))
		print("  %-18s 固定報酬の宝箱='%s'（空が正解） chest_ids=%s" % [
			stage_id, cid,
			str(MasterDataLoader.get_stage(stage_id).get(GameManager.STAGE_MASTER_CHEST_IDS, {})),
		])

	# --- 3. floor_1_common の draw を1000回引く ---
	# ⚠ 段階14-b でハズレ枠を廃止した。引いたら必ず何か出るのが正解。
	print("[DebugBoot] --- floor_1_common の抽選を1000回引く ---")
	var sample_chest: String = "floor_1_common"
	var trials: int = 1000
	var counts: Dictionary = {}
	var empty_draws: int = 0
	var sample_draw: Dictionary = _draw_of(sample_chest)
	for _i: int in range(trials):
		var drawn: Dictionary = GameManager._roll_chest_draw(sample_draw)
		if drawn.is_empty():
			empty_draws += 1
			continue
		for item_id: String in drawn:
			counts[item_id] = int(counts.get(item_id, 0)) + int(drawn[item_id])
	print("  ⚠ 空が返った回数 = %d / %d（⚠ 0 が正解＝ハズレ枠を廃止した）" % [empty_draws, trials])
	for item_id: String in counts:
		print("    %-24s %d 個" % [item_id, int(counts[item_id])])
	print("  出た種類 = %d（%s の枠は4種）" % [counts.size(), sample_chest])
	var foreign: int = 0
	for item_id: String in counts:
		if not _draw_has_item(sample_chest, item_id):
			foreign += 1
			push_error("[DebugBoot] %s のテーブルに無いIDが出た: %s" % [sample_chest, item_id])
	print("  よそのIDが出た件数 = %d（0 が正解）" % foreign)

	# --- 3-b. ハズレ枠が1件も残っていないか（全宝箱）---
	print("[DebugBoot] --- ハズレ枠の残り（⚠ 0 件が正解）---")
	var with_blank: Array[String] = []
	for chest_id: Variant in MasterDataLoader.get_all_chests():
		var draw_def: Dictionary = _draw_of(str(chest_id))
		for row: Variant in (draw_def.get(GameManager.CHEST_DRAW_ENTRIES, []) as Array):
			if str((row as Dictionary).get(GameManager.CHEST_DRAW_ITEM_ID, "")) == "":
				with_blank.append(str(chest_id))
				break
	print("  ハズレ枠を持つ宝箱 = %d 件%s" % [
		with_blank.size(), "" if with_blank.is_empty() else " " + str(with_blank)
	])

	# --- 4. 壊したテーブル ---
	print("[DebugBoot] --- 壊したテーブル ---")
	var all_miss: Dictionary = {
		GameManager.CHEST_DRAW_ROLLS: 1,
		GameManager.CHEST_DRAW_ENTRIES: [
			{GameManager.CHEST_DRAW_ITEM_ID: "", GameManager.CHEST_DRAW_WEIGHT: 100},
		],
	}
	print("  ハズレだけ   -> %s（空が正解）" % str(GameManager._roll_chest_draw(all_miss)))
	var zero_weight: Dictionary = {
		GameManager.CHEST_DRAW_ROLLS: 1,
		GameManager.CHEST_DRAW_ENTRIES: [
			{GameManager.CHEST_DRAW_ITEM_ID: "weapon_wooden_sword", GameManager.CHEST_DRAW_WEIGHT: 0},
		],
	}
	print("  weight 合計0 -> %s（空が正解・赤も黄も出ないこと）" % str(GameManager._roll_chest_draw(zero_weight)))

	# --- 5. 固定の宝箱（ポモドーロの経路）---
	print("[DebugBoot] --- 固定の宝箱を積んで開ける（generic）---")
	var mat_before: int = GameManager.get_material_count("construction_material_1")
	var granted: bool = GameManager.grant_chest("generic", GameStateKeys.CHEST_SOURCE_POMODORO)
	print("  grant_chest('generic') = %s / 未開封 = %d" % [str(granted), GameManager.get_pending_chest_count()])
	var fixed_chest: Dictionary = _last_unopened_chest()
	print("  chest_id = '%s' / source = '%s' / rewards = %s" % [
		str(fixed_chest.get(GameStateKeys.CHEST_ID, "")),
		str(fixed_chest.get(GameStateKeys.CHEST_SOURCE, "")),
		str(fixed_chest.get(GameStateKeys.CHEST_REWARDS, {})),
	])
	var _o1: bool = GameManager.open_chest(str(fixed_chest.get(GameStateKeys.CHEST_INSTANCE_ID, "")))
	var mat_after: int = GameManager.get_material_count("construction_material_1")
	print("  木材 %d -> %d（差 %d・期待 4）" % [mat_before, mat_after, mat_after - mat_before])

	# --- 6. 知らない宝箱 ---
	print("[DebugBoot] --- 知らない chest_id ---")
	var before_unknown: int = GameManager.get_pending_chest_count()
	var bad: bool = GameManager.grant_chest("chest_that_does_not_exist", GameStateKeys.CHEST_SOURCE_BATTLE)
	print("  戻り = %s（false が正解）/ 未開封 %d -> %d（増えないこと）" % [
		str(bad), before_unknown, GameManager.get_pending_chest_count(),
	])

	# --- 7. 抽選の宝箱（戦闘の経路）---
	# ⚠ 段階14-b でハズレ枠を廃止したので、1回目で必ず積まれるのが正解。
	#   （以前は7割が空で、積まれるまで最大200回引いていた）
	var probe_chest: String = "floor_5_legendary"
	print("[DebugBoot] --- 抽選の宝箱を積んで開ける（%s）---" % probe_chest)
	var before_chests: int = GameManager.get_pending_chest_count()
	var attempts: int = 0
	while GameManager.get_pending_chest_count() == before_chests and attempts < 200:
		attempts += 1
		var _r: bool = GameManager.grant_chest(probe_chest, GameStateKeys.CHEST_SOURCE_FLOOR)
	if GameManager.get_pending_chest_count() == before_chests:
		push_error("[DebugBoot] 200回引いても宝箱が1個も積まれなかった")
		return
	print("  %d 回目で積まれた（⚠ 1 が正解＝ハズレ枠を廃止した）" % attempts)

	var chest: Dictionary = _last_unopened_chest()
	# ⚠⚠ 2026-09-18 から**中身は開けるときに振る**（人間の決定）。⚠ 積んだ時点の中身は空が正解。
	print("  積んだ時点の中身 = %s（⚠ 空が正解＝開けるときに振る）" % str(
		chest.get(GameStateKeys.CHEST_REWARDS, {})
	))
	if not (chest.get(GameStateKeys.CHEST_REWARDS, {}) as Dictionary).is_empty():
		push_error("[DebugBoot] 積んだ時点で中身が焼き込まれている（開けるときに振る決定と食い違う）")

	var instance_id: String = str(chest.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
	var before_instances: int = _instance_count()
	var opened: bool = GameManager.open_chest(instance_id)
	print("  open_chest() = %s / 個体 %d -> %d" % [str(opened), before_instances, _instance_count()])
	# ⚠ 開けたあとの記録に、振った中身が残る（⚠ 画面はここを読んで「何が入ったか」を出す）。
	var chest_rewards: Dictionary = _chest_record(instance_id).get(GameStateKeys.CHEST_REWARDS, {})
	var chest_inv: Dictionary = chest_rewards.get(GameStateKeys.REWARD_INVENTORY, {})
	print("  chest_id = '%s' / source = '%s' / 開けた中身の inventory = %s" % [
		str(chest.get(GameStateKeys.CHEST_ID, "")),
		str(chest.get(GameStateKeys.CHEST_SOURCE, "")),
		str(chest_inv),
	])
	for item_id: String in chest_inv:
		if not _draw_has_item(probe_chest, item_id):
			push_error("[DebugBoot] %s のテーブルに無いIDが宝箱に入った: %s" % [probe_chest, item_id])
	var instances: Dictionary = GameManager.get_state().get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	for inst_id: String in instances:
		var inst: Dictionary = instances[inst_id]
		var grade: Variant = inst.get(GameStateKeys.INSTANCE_GRADE, null)
		var parts_arr: Variant = inst.get(GameStateKeys.INSTANCE_PARTS, [])
		print("    %-6s item_id=%-24s grade=%s（型=%s） parts長=%d" % [
			inst_id,
			str(inst.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
			str(grade), type_string(typeof(grade)),
			(parts_arr as Array).size(),
		])
	var opened_again: bool = GameManager.open_chest(instance_id)
	print("  2回目の open_chest() = %s / 個体 = %d（増えないこと）" % [str(opened_again), _instance_count()])

	# --- 7-b. ⚠⚠ 抽選で出た素材が「素材」へ入るか（2026-09-10・人間が実機で見つけた）---
	#
	# ⚠ chests.json の抽選表は素材（storage: "material"）を含む。⚠ 前は storage を見ずに
	#   rewards.inventory へ合流させていたので、⚠ 鍛冶の欠片などが倉庫のマスに入っていた。
	# ⚠⚠ 容量の数え方も食い違っていた：⚠ 開ける前の判定は「素材は0マス」と答えるのに、
	#   ⚠ add_to_inventory() は本物のマスを消費する。⚠ だから「マスが増えないこと」まで見る。
	# ⚠ floor_1_common は4枠とも素材なので、⚠ inventory 側は空が正解。
	print("[DebugBoot] --- 抽選で出た素材が素材へ入るか（floor_1_common・4枠とも素材）---")
	var mat_chest_id: String = "floor_1_common"
	var _mat_granted: bool = GameManager.grant_chest(mat_chest_id, GameStateKeys.CHEST_SOURCE_FLOOR)
	var mat_chest: Dictionary = _last_unopened_chest()
	var slots_before: int = _inventory_entry_count()
	var forge_before: int = GameManager.get_material_count("forging_material_1")
	var mat_instance: String = str(mat_chest.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
	var _mat_opened: bool = GameManager.open_chest(mat_instance)
	# ⚠ 中身は開けたあとの記録から読む（⚠ 2026-09-18 から開けるときに振る）。
	var mat_rewards: Dictionary = _chest_record(mat_instance).get(GameStateKeys.CHEST_REWARDS, {})
	var mat_table: Dictionary = mat_rewards.get(GameStateKeys.REWARD_MATERIALS, {})
	var mat_inv: Dictionary = mat_rewards.get(GameStateKeys.REWARD_INVENTORY, {})
	print("  materials = %s（⚠ ここに入るのが正解）" % str(mat_table))
	print("  inventory = %s（⚠ 空が正解）" % str(mat_inv))
	if not mat_inv.is_empty():
		push_error("[DebugBoot] 抽選で出た素材が rewards.inventory に入っている（倉庫のマスを食う）")
	if mat_table.is_empty():
		push_error("[DebugBoot] 抽選で出た素材が rewards.materials に入っていない")
	print("  開けたあと 持ち物の一覧 %d -> %d 件（⚠ 増えないのが正解）" % [
		slots_before, _inventory_entry_count()
	])
	if _inventory_entry_count() != slots_before:
		push_error("[DebugBoot] 素材だけの宝箱を開けて持ち物の一覧が増えた")
	print("  鍛冶の欠片 %d -> %d（⚠ 出た回だけ増える）" % [
		forge_before, GameManager.get_material_count("forging_material_1")
	])

	# --- 8. 表示名（再インポートの合図）---
	print("  表示名 = '%s'（再インポート前は 'ui_chest_legendary' のままが正常）" % tr("ui_chest_legendary"))


# chests.json の draw を引く。無ければ空。
func _draw_of(chest_id: String) -> Dictionary:
	var draw_def: Variant = MasterDataLoader.get_chest(chest_id).get(GameManager.CHEST_DRAW, null)
	if not (draw_def is Dictionary):
		return {}
	return draw_def as Dictionary


# 当たり枠の重みが全体の何%か。
func _draw_hit_pct(draw_def: Dictionary) -> float:
	var rows: Variant = draw_def.get(GameManager.CHEST_DRAW_ENTRIES, [])
	if not (rows is Array):
		return 0.0
	var total: int = 0
	var miss: int = 0
	for row: Variant in (rows as Array):
		if not (row is Dictionary):
			continue
		var entry: Dictionary = row as Dictionary
		var weight: int = int(entry.get(GameManager.CHEST_DRAW_WEIGHT, 0))
		total += weight
		if str(entry.get(GameManager.CHEST_DRAW_ITEM_ID, "")) == "":
			miss += weight
	if total <= 0:
		return 0.0
	return float(total - miss) * 100.0 / float(total)


func _draw_has_item(chest_id: String, item_id: String) -> bool:
	var rows: Variant = _draw_of(chest_id).get(GameManager.CHEST_DRAW_ENTRIES, [])
	if not (rows is Array):
		return false
	for row: Variant in (rows as Array):
		if row is Dictionary and str((row as Dictionary).get(GameManager.CHEST_DRAW_ITEM_ID, "")) == item_id:
			return true
	return false


func _instance_count() -> int:
	return (GameManager.get_state().get(GameStateKeys.EQUIPMENT_INSTANCES, {}) as Dictionary).size()


func _last_unopened_chest() -> Dictionary:
	var chests: Array = GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, [])
	for i: int in range(chests.size() - 1, -1, -1):
		if not (chests[i] is Dictionary):
			continue
		var chest: Dictionary = chests[i]
		if not bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			return chest
	return {}


# instance_id で宝箱の記録を1件引く（⚠ 開けたあとも残る）。⚠ 無ければ空。
func _chest_record(instance_id: String) -> Dictionary:
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if chest is Dictionary and str((chest as Dictionary).get(GameStateKeys.CHEST_INSTANCE_ID, "")) == instance_id:
			return chest
	return {}


# プリセット2階層の検証（EXEC_PARTY_PRESETS.md §9 / §11-A）。
#
# ⚠ 状態は書き換えるが、絶対に保存しない（_ready() の注記と同じ）。
# ⚠ 本番のデータファイルを一時的に壊さない。壊すのはメモリ上の状態だけなので、
#   git diff は最初から空のまま（元に戻す作業が要らない）。
func _report_presets() -> void:
	var members: Array = GameManager.get_party_members()
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		push_error("[DebugBoot] 編成が %d 件（%d のはず）" % [
			members.size(), GameStateKeys.PARTY_SLOT_COUNT
		])
		return
	var char_a: String = str(members[0])
	var char_b: String = str(members[1])

	# --- 1. 器の件数 ---
	print("[DebugBoot] --- 器の件数 ---")
	# ⚠ 2026-09-27：10 → 8（決定 `NAV-11`）。
	print("  編成プリセット   = %d 件（8 が正解）" % GameManager.get_party_presets().size())
	print("  get_party_preset_count()     = %d" % GameManager.get_party_preset_count())
	print("  get_character_preset_count() = %d" % GameManager.get_character_preset_count())
	for character_id: Variant in members:
		print("  %-20s のビルド = %d 件（3 が正解）" % [
			str(character_id), GameManager.get_character_presets(str(character_id)).size()
		])

	# --- 2. 焼く ---
	print("[DebugBoot] --- 焼く（現在の状態を書き写す）---")
	# 装備を1つ着けてから焼く。⚠ 個体を作る口は add_to_inventory() だけ（CLAUDE.md 8番）。
	GameManager.add_to_inventory("weapon_wooden_sword", 1)
	var sword: String = _find_instance_of("weapon_wooden_sword")
	print("  個体を1つ作った: %s" % sword)
	print("  %s に着ける -> %s" % [char_a, str(GameManager.equip_instance(char_a, GameStateKeys.EQUIP_WEAPON, sword))])
	print("  save_character_preset('%s', 0) -> %s" % [char_a, str(GameManager.save_character_preset(char_a, 0))])
	print("  save_character_preset('%s', 0) -> %s" % [char_b, str(GameManager.save_character_preset(char_b, 0))])
	print("  save_character_preset('%s', 0) -> %s" % [str(members[2]), str(GameManager.save_character_preset(str(members[2]), 0))])
	var build: Dictionary = GameManager.get_character_preset(char_a, 0)
	print("  焼いた中身の4項目:")
	print("    nodes     = %s" % str(build.get(GameStateKeys.GROWTH_NODES, null)))
	print("    skills    = %s" % str(build.get(GameStateKeys.GROWTH_SKILLS, null)))
	print("    passives  = %s" % str(build.get(GameStateKeys.GROWTH_PASSIVES, null)))
	print("    equipment = %s" % str(build.get(GameStateKeys.GROWTH_EQUIPMENT, null)))

	var slots: Array = []
	for i: int in range(GameStateKeys.PARTY_SLOT_COUNT):
		slots.append({
			GameStateKeys.PRESET_CHARACTER_ID: str(members[i]),
			GameStateKeys.PRESET_INDEX: 0,
		})
	print("  save_party_preset(0) -> %s" % str(GameManager.save_party_preset(0, slots)))
	print("  空きのプリセットを適用 -> reason=%s（ui_party_preset_unsaved が正解）" % str(
		# ⚠ 最後の番号は件数から引く（⚠ 2026-09-27 に 10 → 8 で「9」が範囲外になった）。
		GameManager.get_party_preset_apply_report(GameManager.get_party_preset_count() - 1).get(GameManager.APPLY_REASON, "")
	))

	# --- 2-b. 空の参照先は「保存」が焼く ---
	# ⚠ これが無いと行き止まりになる（適用が ui_party_preset_ref_unsaved で
	#   弾かれ続け、画面から抜け出せない）。2026-08-23に人間が踏んだ。
	print("[DebugBoot] --- 空の参照先を「保存」が焼くか ---")
	var slots_2: Array = []
	for i: int in range(GameStateKeys.PARTY_SLOT_COUNT):
		slots_2.append({
			GameStateKeys.PRESET_CHARACTER_ID: str(members[i]),
			# ⚠ 誰も焼いていない番号（2）を指す。
			GameStateKeys.PRESET_INDEX: 2,
		})
	print("  焼く前 %s[2] の saved = %s（false が正解）" % [
		char_a, str(GameManager.get_character_preset(char_a, 2).get(GameStateKeys.PRESET_SAVED, null))
	])
	print("  save_party_preset(1) -> %s" % str(GameManager.save_party_preset(1, slots_2)))
	print("  焼いた後 %s[2] の saved = %s（true が正解）" % [
		char_a, str(GameManager.get_character_preset(char_a, 2).get(GameStateKeys.PRESET_SAVED, null))
	])
	print("  そのまま適用 -> ok=%s（true が正解。⚠ ref_unsaved で弾かれないこと）" % str(
		GameManager.apply_party_preset(1).get(GameManager.APPLY_OK, false)
	))

	# --- 2-c. キャラ単体の適用（育成・装備の「適用」ボタン）---
	# ⚠ 編成プリセットと同じ部品（_plan_build / _write_build）を通ること。
	# ⚠ 編成を触らないこと（当てるのはそのキャラの中身だけ）。
	print("[DebugBoot] --- キャラ単体の適用 ---")
	print("  空きのビルドを当てる -> reason=%s（ui_party_preset_unsaved が正解・⚠ 赤を出さない）" % str(
		GameManager.get_character_preset_apply_report(char_a, 1).get(GameManager.APPLY_REASON, "")
	))
	var before_members: Array = GameManager.get_party_members()
	var single: Dictionary = GameManager.apply_character_preset(char_a, 0)
	print("  ビルド1を当てる -> ok=%s members=%s（%s だけが正解）" % [
		str(single.get(GameManager.APPLY_OK, false)),
		str(single.get(GameManager.APPLY_MEMBERS, [])), char_a,
	])
	print("  編成 = %s（%s のまま＝触っていないことが正解）" % [
		str(GameManager.get_party_members()), str(before_members)
	])

	if not GameManager.PRESET_EQUIPMENT_ENABLED:
		# --- 3'. 装備はいったん止めている ---
		# ⚠ 見るのは「装備が付く」ことではなく「装備に触らない」こと。
		#   ⚠ 空の計画で上書きすると、プリセットを当てるたびに裸になる。
		print("[DebugBoot] --- 装備はいったん止めている（PRESET_EQUIPMENT_ENABLED=false）---")
		print("  焼いた equipment = %s（全部 null が正解）" % str(
			GameManager.get_character_preset(char_a, 0).get(GameStateKeys.GROWTH_EQUIPMENT, null)
		))
		print("  %s に着ける -> %s" % [char_a, str(
			GameManager.equip_instance(char_a, GameStateKeys.EQUIP_WEAPON, sword)
		)])
		var report_off: Dictionary = GameManager.apply_party_preset(0)
		print("  apply -> ok=%s conflicts=%d missing=%d（どちらも 0 が正解）" % [
			str(report_off.get(GameManager.APPLY_OK, false)),
			(report_off.get(GameManager.APPLY_CONFLICTS, []) as Array).size(),
			(report_off.get(GameManager.APPLY_MISSING, []) as Array).size(),
		])
		print("  適用後の %s の weapon = '%s'（⚠ %s のまま＝外れていないことが正解）" % [
			char_a, GameManager.get_equipped_instance_id(char_a, GameStateKeys.EQUIP_WEAPON), sword
		])
		_report_presets_normalize(char_a)
		return

	# --- 3. 取り合い（奪う）---
	print("[DebugBoot] --- 取り合い（編成の外のキャラが装備中の個体を要求する）---")
	# ⚠ 奪ったと報告するのは「編成の外のキャラから取るとき」だけ。編成の3人の間で
	#   移るのは、3人とも同じ適用でビルドを当て直しているので、焼いたときの意図どおり
	#   （報告すると、普通の切り替えのたびにメッセージが出る）。
	# 剣を char_a から外して「編成に居ないキャラ」に着け直し、char_a のビルドを適用する。
	var outsider: String = _character_outside_party()
	print("  編成の外のキャラ = %s" % outsider)
	GameManager.unequip_instance(char_a, GameStateKeys.EQUIP_WEAPON)
	print("  %s に着け替える -> %s" % [outsider, str(GameManager.equip_instance(outsider, GameStateKeys.EQUIP_WEAPON, sword))])
	print("  いまの持ち主 = %s" % _owner_of(sword))
	var report: Dictionary = GameManager.apply_party_preset(0)
	print("  apply -> ok=%s conflicts=%d" % [
		str(report.get(GameManager.APPLY_OK, false)),
		(report.get(GameManager.APPLY_CONFLICTS, []) as Array).size(),
	])
	for entry: Variant in (report.get(GameManager.APPLY_CONFLICTS, []) as Array):
		print("    %s から %s を外して %s へ" % [
			str((entry as Dictionary).get(GameManager.APPLY_FROM_CHARACTER_ID, "")),
			str((entry as Dictionary).get(GameManager.APPLY_INSTANCE_ID, "")),
			str((entry as Dictionary).get(GameManager.APPLY_CHARACTER_ID, "")),
		])
	print("  適用後の持ち主 = %s（%s が正解）" % [_owner_of(sword), char_a])
	print("  %s の weapon = '%s'（空が正解）" % [
		outsider, GameManager.get_equipped_instance_id(outsider, GameStateKeys.EQUIP_WEAPON)
	])
	print("  ⚠ 編成の中で移るぶんは conflicts に積まない（char_b=%s は報告の対象外）" % char_b)

	# --- 4. 消えた個体（分解された）---
	print("[DebugBoot] --- 消えた個体 ---")
	GameManager.unequip_instance(char_a, GameStateKeys.EQUIP_WEAPON)
	print("  dismantle_equipment('%s') -> %s" % [sword, str(GameManager.dismantle_equipment(sword))])
	var report2: Dictionary = GameManager.apply_party_preset(0)
	print("  apply -> ok=%s missing=%d（1 が正解）" % [
		str(report2.get(GameManager.APPLY_OK, false)),
		(report2.get(GameManager.APPLY_MISSING, []) as Array).size(),
	])
	print("  %s の weapon = '%s'（空が正解。⚠ 赤も黄も出ないこと）" % [
		char_a, GameManager.get_equipped_instance_id(char_a, GameStateKeys.EQUIP_WEAPON)
	])

	_report_presets_normalize(char_a)


# --- 5. 正規化（2箇所で壊す）---
#
# ⚠ 足した検証は2箇所で壊して確かめる（NEXT_STEPS §3-1）。
# ⚠ 装備を止めている枝からも呼ぶので、関数に切り出してある。
#   ⚠ 2本目を書かないこと（片方だけ直る形になる）。
func _report_presets_normalize(char_a: String) -> void:
	print("[DebugBoot] --- 正規化（2箇所で壊す）---")
	# (a) 件数を1件に減らす。
	var broken_a: Dictionary = GameManager.get_state().get(GameStateKeys.CHARACTER_PRESETS, {})
	var one: Array = [GameManager.get_character_preset(char_a, 0)]
	GameManager._state[GameStateKeys.CHARACTER_PRESETS] = {char_a: one}
	print("  (a) 壊す前 = %d 件 / 壊した後 = 1 件" % GameManager.get_character_presets(char_a).size())
	GameManager._normalize_presets_from_save()
	print("  (a) 直った後 = %d 件（3 が正解）" % GameManager.get_character_presets(char_a).size())

	# (b) 存在しない個体を equipment に入れる。
	var poisoned: Array = GameManager.get_character_presets(char_a)
	var entry_b: Dictionary = poisoned[0]
	var equipment_b: Dictionary = (entry_b.get(GameStateKeys.GROWTH_EQUIPMENT, {}) as Dictionary).duplicate(true)
	equipment_b[GameStateKeys.EQUIP_WEAPON] = "eq_99999"
	entry_b[GameStateKeys.GROWTH_EQUIPMENT] = equipment_b
	poisoned[0] = entry_b
	GameManager._write_character_presets(char_a, poisoned)
	print("  (b) 壊した後 = %s" % str(GameManager.get_character_preset(char_a, 0).get(GameStateKeys.GROWTH_EQUIPMENT, {})))
	GameManager._normalize_presets_from_save()
	print("  (b) 直った後 = %s（weapon が null なら正解）" % str(
		GameManager.get_character_preset(char_a, 0).get(GameStateKeys.GROWTH_EQUIPMENT, {})
	))

	# (c) rune_move（段階8で5つ目のキーになった）。
	# ⚠ 段階7の時点では「知らないキーが残る」ことを見ていた。段階8で器ができたので、
	#   ⚠ いまは「Dictionary でなければ空に直る」を見る（EXEC_RUNES.md §3-F）。
	var future: Array = GameManager.get_character_presets(char_a)
	var entry_c: Dictionary = future[0]
	entry_c[GameStateKeys.GROWTH_RUNE_MOVE] = 3
	future[0] = entry_c
	GameManager._write_character_presets(char_a, future)
	GameManager._normalize_presets_from_save()
	print("  (c) rune_move に 3 を入れる -> %s（{} に直るのが正解）" % str(
		GameManager.get_character_preset(char_a, 0).get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	))
	# 参照が壊れた編成プリセットは空きに戻る。
	var party_presets: Array = GameManager.get_party_presets()
	var broken_party: Dictionary = party_presets[0]
	broken_party[GameStateKeys.PRESET_SLOTS] = [{
		GameStateKeys.PRESET_CHARACTER_ID: char_a,
		GameStateKeys.PRESET_INDEX: 99,
	}]
	party_presets[0] = broken_party
	GameManager._state[GameStateKeys.PARTY_PRESETS] = party_presets
	GameManager._normalize_presets_from_save()
	print("  壊した編成プリセット saved = %s（false が正解）" % str(
		(GameManager.get_party_presets()[0] as Dictionary).get(GameStateKeys.PRESET_SAVED, null)
	))
	# (d) 10件のころのセーブ（2026-09-27・決定 `NAV-11`＝10 → 8）。⚠ 9・10番に残した分は落ちる。
	var old_ten: Array = GameManager.get_party_presets()
	while old_ten.size() < 10:
		old_ten.append({GameStateKeys.PRESET_SAVED: false, GameStateKeys.PRESET_SLOTS: []})
	GameManager._state[GameStateKeys.PARTY_PRESETS] = old_ten
	print("  (d) 10件のセーブ = %d 件" % GameManager._state[GameStateKeys.PARTY_PRESETS].size())
	GameManager._normalize_presets_from_save()
	var after_count: int = GameManager.get_party_presets().size()
	print("  (d) 読み込んだ後 = %d 件（%d が正解）" % [after_count, GameManager.get_party_preset_count()])
	if after_count != GameManager.get_party_preset_count():
		push_error("[DebugBoot] 10件のセーブが %d 件に落ちなかった（%d 件）" % [GameManager.get_party_preset_count(), after_count])
	print("  ⚠ ここまで状態を書き換えたが、保存はしていない（%d 件のキャラプリセット）" % broken_a.size())


# フロアの器（段階14-a・EXEC_SCENARIO_FLOOR.md §5）。
#
# ⚠ 戦闘を1回も回さない。ここで見るのは GameManager が組んだマップだけ。
# ⚠ 状態は書き換えるが、絶対に保存しない（_ready() の注記と同じ）。
#   最後に abandon_floor() で必ず降りること。
func _report_floor() -> void:
	var floor_ids: Array[String] = []
	for stage_id: Variant in MasterDataLoader._cache_stages:
		if GameManager.is_floor_stage(str(stage_id)):
			floor_ids.append(str(stage_id))
	floor_ids.sort()

	# --- 1. フロアの一覧 ---
	print("[DebugBoot] --- フロアの一覧（⚠ 5 本が正解）---")
	print("  実際 = %d 本" % floor_ids.size())
	for floor_id: String in floor_ids:
		var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
		var layers: Array = stage.get(GameManager.STAGE_MASTER_LAYERS, [])
		var counts: Array[String] = []
		var sum_nodes: int = 0
		for layer: Variant in layers:
			var n: int = int((layer as Dictionary).get(GameManager.LAYER_NODE_COUNT, 0))
			counts.append(str(n))
			sum_nodes += n
		print("  %-8s 層=%d 各層=[%s] 生成ノード=%d（+ボス1 = %d） unlocks=%s" % [
			floor_id, layers.size(), ", ".join(counts), sum_nodes, sum_nodes + 1,
			str(GameManager.get_stage_unlocks(floor_id)),
		])

	# --- 2. 生成して歩く / 3. 全ルート総当たり / 6. ノード種の内訳 ---
	for floor_id: String in floor_ids:
		print("[DebugBoot] --- %s を組む ---" % floor_id)
		if not GameManager.start_floor(floor_id):
			push_error("[DebugBoot] start_floor が false: " + floor_id)
			continue
		var run: Dictionary = GameManager.get_floor_run()
		var nodes: Dictionary = run.get(GameStateKeys.FLOOR_RUN_NODES, {})
		var entry_id: String = str(run.get(GameStateKeys.FLOOR_RUN_POSITION, ""))

		# 6. ノード種の内訳。
		var kind_count: Dictionary = {}
		for node_id: Variant in nodes:
			var kind: String = str((nodes[node_id] as Dictionary).get(GameStateKeys.FLOOR_NODE_KIND, ""))
			kind_count[kind] = int(kind_count.get(kind, 0)) + 1
		var kinds: Array = kind_count.keys()
		kinds.sort()
		var kind_parts: Array[String] = []
		for kind: Variant in kinds:
			kind_parts.append("%s=%d" % [str(kind), int(kind_count[kind])])
		print("  ノード %d 件 / %s" % [nodes.size(), " ".join(kind_parts)])

		# 3. 全ルート総当たり。⚠ ここが「合流あり」を選んだ根拠そのもの。
		var routes: Array = []
		var reached: Dictionary = {}
		_walk_all_routes(nodes, entry_id, [], routes, reached)
		var dead_ends: int = 0
		var lengths: Dictionary = {}
		for route: Variant in routes:
			var path: Array = route
			var last_kind: String = str(
				(nodes[str(path[path.size() - 1])] as Dictionary).get(GameStateKeys.FLOOR_NODE_KIND, "")
			)
			if last_kind != GameStateKeys.FLOOR_NODE_KIND_BOSS:
				dead_ends += 1
			lengths[path.size()] = int(lengths.get(path.size(), 0)) + 1
		print("  全ルート = %d 本 / ⚠ ボスに着かなかったルート = %d 本（0 が正解）" % [
			routes.size(), dead_ends
		])
		print("  歩数の内訳 = %s（層数 %d ＋ボス1 = %d 個のノードを通るのが正解）" % [
			str(lengths), GameManager.get_floor_layer_count(floor_id),
			GameManager.get_floor_layer_count(floor_id) + 1,
		])
		var unreachable: Array[String] = []
		for node_id: Variant in nodes:
			if not reached.has(str(node_id)):
				unreachable.append(str(node_id))
		unreachable.sort()
		print("  ⚠ どのルートからも通れないノード = %d 件%s（0 が正解）" % [
			unreachable.size(),
			"" if unreachable.is_empty() else " " + str(unreachable),
		])

		# 2. 入口からボスまで1本だけ実際に歩く（毎回いちばん手前の分岐を選ぶ）。
		if floor_id == floor_ids[0]:
			print("  --- 入口からボスまで歩く ---")
			var steps: int = 0
			while true:
				var here: String = str(GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_POSITION, ""))
				var node: Dictionary = GameManager.get_floor_node(here)
				var moves: Array = GameManager.get_available_moves()
				print("    %d手目 いま=%-8s 種類=%-6s 進める先=%s" % [
					steps, here, str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")), str(moves)
				])
				if moves.is_empty():
					break
				if not GameManager.move_to_node(str(moves[0])):
					push_error("[DebugBoot] move_to_node が false: " + str(moves[0]))
					break
				steps += 1
				if steps > 50:
					push_error("[DebugBoot] 50手で終わらない（ループしている）")
					break
			print("    歩数 = %d（層数 %d が正解）" % [steps, GameManager.get_floor_layer_count(floor_id)])

			# 4. 進めない先を渡す。⚠ 入口へ戻れないことを見る。
			var bad_id: String = entry_id
			var before: String = str(GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_POSITION, ""))
			var rejected: bool = GameManager.move_to_node(bad_id)
			var after: String = str(GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_POSITION, ""))
			print("  ⚠ 進めない先 '%s' を渡す -> %s（false が正解） / 位置 %s -> %s（動かないのが正解）" % [
				bad_id, str(rejected), before, after
			])

		# 5. 降りる。
		GameManager.abandon_floor()
		print("  abandon_floor() -> is_in_floor()=%s（false が正解）" % str(GameManager.is_in_floor()))

	# --- 9. 宝箱（段階14-b・EXEC_SCENARIO_CHEST.md §5）---
	#
	# ⚠ 宝箱は「移動」に紐づく。ノードではない（PLAN_SCENARIO_MAP.md §4）。
	# ⚠ レアリティの分布は _roll_chest_rarity() を直接叩いて数える。
	#   実際に歩かせて数えると add_pending_chest() の print で出力が埋まる
	#   （NEXT_STEPS §4「在庫を減らすために操作を繰り返す書き方をしない」）。
	print("[DebugBoot] --- 宝箱のID（⚠ 5フロア × 4段階 = 20 件が正解）---")
	var missing_chest: Array[String] = []
	var listed_chest: int = 0
	for floor_id: String in floor_ids:
		var ids: Variant = MasterDataLoader.get_stage(floor_id).get(GameManager.STAGE_MASTER_CHEST_IDS, null)
		if not (ids is Dictionary):
			missing_chest.append(floor_id + ":chest_ids が無い")
			continue
		for rarity: String in [
			GameManager.CHEST_RARITY_COMMON, GameManager.CHEST_RARITY_RARE,
			GameManager.CHEST_RARITY_EPIC, GameManager.CHEST_RARITY_LEGENDARY,
		]:
			var chest_id: String = str((ids as Dictionary).get(rarity, ""))
			listed_chest += 1
			if chest_id == "" or MasterDataLoader.get_chest(chest_id).is_empty():
				missing_chest.append("%s:%s" % [floor_id, rarity])
	print("  chest_ids に並んでいる = %d 件 / ⚠ chests.json に無いもの = %d 件%s" % [
		listed_chest, missing_chest.size(),
		"" if missing_chest.is_empty() else " " + str(missing_chest),
	])
	print("  chests.json の総数 = %d 件（⚠ 20 + generic/bonus_* の4 = 24 が正解）" % (
		MasterDataLoader.get_all_chests().size()
	))

	print("[DebugBoot] --- レアリティの深度補正（各 10000 回）---")
	for layer: int in [1, 3, 5]:
		var dist: Dictionary = {}
		for _i: int in range(10000):
			var rarity: String = GameManager._roll_chest_rarity(layer)
			dist[rarity] = int(dist.get(rarity, 0)) + 1
		print("  層%d  common=%.1f%% rare=%.1f%% epic=%.1f%% legendary=%.1f%%" % [
			layer,
			float(int(dist.get(GameManager.CHEST_RARITY_COMMON, 0))) / 100.0,
			float(int(dist.get(GameManager.CHEST_RARITY_RARE, 0))) / 100.0,
			float(int(dist.get(GameManager.CHEST_RARITY_EPIC, 0))) / 100.0,
			float(int(dist.get(GameManager.CHEST_RARITY_LEGENDARY, 0))) / 100.0,
		])
	print("     （⚠ 奥ほどレジェンダリーが増えるのが正解。⚠ 画面にも明示する決定＝§4-5）")

	# 実際に歩いて1周あたりの宝箱を数える。⚠ 100周だけ（print が増えるため）。
	print("[DebugBoot] --- 1周あたりの宝箱（100周・出現率 %d%%）---" % int(
		Balance.floor.chest_chance_pct
	))
	var rounds: int = 100
	var zero_rounds: int = 0
	var total_chests: int = 0
	for _r: int in range(rounds):
		GameManager._state[GameStateKeys.PENDING_CHESTS] = []
		if not GameManager.start_floor(floor_ids[0]):
			break
		_walk_to_boss()
		var got: int = GameManager.get_floor_chest_count()
		total_chests += got
		if got <= 0:
			zero_rounds += 1
		GameManager.abandon_floor()
	print("  合計 %d 個 / %d 周 = %.2f 個/周" % [
		total_chests, rounds, float(total_chests) / float(rounds)
	])
	print("  ⚠ 1個も出なかった周 = %d（0 が正解＝1フロア最低1回の保証）" % zero_rounds)

	# 出現率を0にして保証だけを見る。⚠ 必ず元に戻すこと。
	print("[DebugBoot] --- 保証だけ（出現率 0%）---")
	var backup_chance: int = int(Balance.floor.chest_chance_pct)
	Balance.floor.chest_chance_pct = 0
	var guarantee_rounds: int = 100
	var guarantee_total: int = 0
	var guarantee_zero: int = 0
	for _r: int in range(guarantee_rounds):
		GameManager._state[GameStateKeys.PENDING_CHESTS] = []
		if not GameManager.start_floor(floor_ids[0]):
			break
		_walk_to_boss()
		var got: int = GameManager.get_floor_chest_count()
		guarantee_total += got
		if got <= 0:
			guarantee_zero += 1
		GameManager.abandon_floor()
	Balance.floor.chest_chance_pct = backup_chance
	print("  合計 %d 個 / %d 周（⚠ ちょうど %d 個＝各周1個が正解）" % [
		guarantee_total, guarantee_rounds, guarantee_rounds
	])
	print("  ⚠ 1個も出なかった周 = %d（0 が正解）" % guarantee_zero)
	print("  出現率を %d%% に戻した" % int(Balance.floor.chest_chance_pct))
	GameManager._state[GameStateKeys.PENDING_CHESTS] = []

	# ⚠⚠ シナリオの鞄（2026-09-18・人間の決定「難ダンジョンのインベントリをシナリオでも適用」
	#   「宝箱と道中の戦利品」「とりあえず８枠」「ストーリーのやつはボス倒したら」）。
	#   ⚠ 拾ったものはまず拾い待ち → 鞄へ入れる → ボスで持ち帰る（宝箱は拠点の宝箱） → 降りたら失う。
	print("[DebugBoot] --- シナリオの鞄（拾い待ち → 鞄 → ボスで持ち帰る・降りたら失う）---")
	var floor_kind: String = GameManager.RUN_KIND_FLOOR
	if GameManager.start_floor(floor_ids[0]):
		print("  鞄の枠 = %d（⚠ 8 が正解）" % GameManager.get_run_bag_slots(floor_kind))
		_walk_to_boss()
		# ⚠ 道中の戦利品（戦闘のマスで勝ったぶん）を1回だけ積む。⚠ どのマスでも戦闘なら引く。
		var battle_node: String = ""
		for node_id: Variant in GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_NODES, {}):
			if str(GameManager.get_floor_node(str(node_id)).get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.FLOOR_NODE_KIND_BATTLE:
				battle_node = str(node_id)
				break
		var node_loot: Dictionary = GameManager.grant_floor_node_loot(floor_ids[0], battle_node)
		var pending: Dictionary = GameManager.get_run_pending_loot(floor_kind)
		var pending_chests: int = 0
		for item_id: Variant in pending:
			if GameManager.is_chest_item(str(item_id)):
				pending_chests += int(pending[item_id])
		print("  歩き終えて 拾い待ち=%s（宝箱 %d 個）/ 道中の戦利品=%s / 拠点の未開封=%d（⚠ 0 が正解）" % [
			str(pending), pending_chests, str(node_loot), GameManager.get_pending_chest_count(),
		])
		if node_loot.is_empty():
			push_error("[DebugBoot] 道中の戦利品が1つも積まれなかった")
		var taken: Dictionary = GameManager.take_all_run_pending_loot(floor_kind)
		var bag_chests: int = 0
		for item_id: Variant in GameManager.get_run_bag(floor_kind):
			if GameManager.is_chest_item(str(item_id)):
				bag_chests += int(GameManager.get_run_bag(floor_kind)[item_id])
		print("  全部入れる -> 鞄 %d/%d ／ 入れた %s ／ 残り %s" % [
			GameManager.get_run_bag_used(floor_kind), GameManager.get_run_bag_slots(floor_kind),
			str(taken), str(GameManager.get_run_pending_loot(floor_kind)),
		])
		var delivered: Dictionary = GameManager.deliver_floor_bag()
		print("  deliver_floor_bag() -> 持ち帰った %s ／ 拠点の未開封=%d（⚠ 鞄の宝箱 %d と同じが正解）／ 鞄 %d（⚠ 0 が正解）" % [
			str(delivered.get("granted", {})), GameManager.get_pending_chest_count(), bag_chests,
			GameManager.get_run_bag_used(floor_kind),
		])
		if GameManager.get_pending_chest_count() != bag_chests or GameManager.get_run_bag_used(floor_kind) != 0:
			push_error("[DebugBoot] シナリオの鞄の持ち帰り方が食い違う")
		GameManager.abandon_floor()
	GameManager._state[GameStateKeys.PENDING_CHESTS] = []
	if GameManager.start_floor(floor_ids[0]):
		_walk_to_boss()
		var _taken_lost: Dictionary = GameManager.take_all_run_pending_loot(floor_kind)
		var held_lost: int = GameManager.get_run_bag_used(floor_kind)
		GameManager.abandon_floor()
		print("  鞄に %d 個のまま降りる -> 拠点の未開封=%d（⚠ 0 が正解＝失う）" % [
			held_lost, GameManager.get_pending_chest_count()
		])
		if GameManager.get_pending_chest_count() != 0:
			push_error("[DebugBoot] 降りたのにシナリオの鞄が拠点へ届いている")
	GameManager._state[GameStateKeys.PENDING_CHESTS] = []

	# --- 10. レリック（段階14-d・PLAN_SCENARIO_MAP.md §5-2）---
	#
	# ⚠ いちばん危ないのは「取れたのに戦闘で何も起きない」。定義が _cache_skills に
	#   入っていないと _restore_passives() が引けず、赤も黄も1本も出ない。
	#   ⚠ get_skill() で引けることを必ず確かめる。
	print("[DebugBoot] --- レリック ---")
	var relic_ids: Array[String] = MasterDataLoader.get_all_relic_ids()
	var party_scope: int = 0
	var single_scope: int = 0
	var not_in_skills: Array[String] = []
	for relic_id: String in relic_ids:
		if GameManager.is_single_relic(relic_id):
			single_scope += 1
		else:
			party_scope += 1
		if MasterDataLoader.get_skill(relic_id).is_empty():
			not_in_skills.append(relic_id)
	print("  relics.json = %d 件（3人用 %d / 1人用 %d）" % [
		relic_ids.size(), party_scope, single_scope
	])
	print("  ⚠ get_skill() で引けないもの = %d 件%s（0 が正解＝引けないと戦闘で無音で消える）" % [
		not_in_skills.size(), "" if not_in_skills.is_empty() else " " + str(not_in_skills)
	])

	if GameManager.start_floor(floor_ids[0]):
		var members: Array = GameManager.get_party_members()
		var solo: String = str(members[0])
		# 3人用を1つ、1人用を1つ取る。
		var party_relic: String = ""
		var single_relic: String = ""
		for relic_id: String in relic_ids:
			if single_relic == "" and GameManager.is_single_relic(relic_id):
				single_relic = relic_id
			elif party_relic == "" and not GameManager.is_single_relic(relic_id):
				party_relic = relic_id
		var took_party: bool = GameManager.take_relic(party_relic, "")
		var took_single: bool = GameManager.take_relic(single_relic, solo)
		print("  3人用 '%s' を取る -> %s / 1人用 '%s' を %s に -> %s" % [
			party_relic, str(took_party), single_relic, solo, str(took_single)
		])
		for member: Variant in members:
			print("    %-16s に効くレリック = %s" % [
				str(member), str(GameManager.get_floor_relic_passives(str(member)))
			])
		print("     （⚠ 3人用は全員に、⚠ 1人用は %s にだけ並ぶのが正解）" % solo)

		# ⚠ 弾く枝。1人用に character_id を渡さない／編成に居ないIDを渡す。
		print("  ⚠ 1人用に空の character_id -> %s（false が正解・⚠ 下の黄1本が正解）" % str(
			GameManager.take_relic(single_relic, "")
		))
		print("  ⚠ 編成に居ないキャラ -> %s（false が正解・⚠ 下の黄1本が正解）" % str(
			GameManager.take_relic(single_relic, "char_not_in_party")
		))
		print("  所持 = %d 件（2 が正解＝弾いたぶんは増えない）" % GameManager.get_floor_relics().size())
		# ⚠⚠ 画面が呼ぶ口（2026-09-19・レリック選択を1枚にした）。⚠ シナリオへ振り分けられるか。
		#   ⚠ 候補は FLOOR_RELIC_CHOICE_COUNT 件 ／ ⚠ 取ると FLOOR_RUN のほうに増える（⚠ 難ダンジョンの器は触らない）。
		var run_choices: Array = GameManager.get_run_relic_choices(GameManager.RUN_KIND_FLOOR, "")
		var took_run: bool = GameManager.take_run_relic(
			GameManager.RUN_KIND_FLOOR, "", party_relic, ""
		)
		print("  ⚠ 共通の口：候補 %d 件（%d が正解）／ 取る -> %s ／ 所持 = %d 件（3 が正解）／ 脱落 = %s（false が正解）" % [
			run_choices.size(), GameManager.FLOOR_RELIC_CHOICE_COUNT, str(took_run),
			GameManager.get_floor_relics().size(),
			str(GameManager.is_run_character_downed(GameManager.RUN_KIND_FLOOR, solo)),
		])
		if run_choices.size() != GameManager.FLOOR_RELIC_CHOICE_COUNT or not took_run \
				or GameManager.get_floor_relics().size() != 3:
			push_error("[DebugBoot] レリックの共通の口がシナリオへ振り分けられていない")
		GameManager.abandon_floor()
		print("  abandon_floor() 後の所持 = %d 件（0 が正解＝フロアを降りると消える）" % (
			GameManager.get_floor_relics().size()
		))

	# --- 11. たいまつとショップ（段階14-e・EXEC_SCENARIO_SHOP.md）---
	#
	# ⚠ いちばん危ないのは「たいまつを買っても見える層が変わらない」。
	#   ⚠ 配列の添字を1つずらすと無音でそうなる。買う前後の数を並べて見る。
	print("[DebugBoot] --- たいまつ ---")
	if GameManager.start_floor(floor_ids[0]):
		var max_grade: int = GameManager.get_floor_torch_max_grade()
		print("  上限グレード = %d（floor_torch_reveal_layers の長さ - 1）" % max_grade)
		GameManager.add_gold(99999)
		for step: int in range(max_grade + 2):
			var grade: int = GameManager.get_floor_torch_grade()
			var reveal: int = GameManager.get_floor_reveal_layers()
			var price: int = GameManager.get_floor_torch_next_price()
			print("    grade=%d -> %d 層先まで見える / 次は %s" % [
				grade, reveal, ("買えない（上限）" if price < 0 else "%d G" % price)
			])
			if not GameManager.buy_floor_torch():
				break

		# 視界の判定。⚠ grade 0 に戻してから、層ごとに見えるかを並べる。
		GameManager.abandon_floor()
		var _restarted: bool = GameManager.start_floor(floor_ids[0])
		var run_t: Dictionary = GameManager.get_floor_run()
		var nodes_t: Dictionary = run_t.get(GameStateKeys.FLOOR_RUN_NODES, {})
		var hidden_by_layer: Dictionary = {}
		var shown_by_layer: Dictionary = {}
		for node_id: Variant in nodes_t:
			var layer_t: int = int((nodes_t[node_id] as Dictionary).get(GameStateKeys.FLOOR_NODE_LAYER, 1))
			if GameManager.is_floor_node_revealed(str(node_id)):
				shown_by_layer[layer_t] = int(shown_by_layer.get(layer_t, 0)) + 1
			else:
				hidden_by_layer[layer_t] = int(hidden_by_layer.get(layer_t, 0)) + 1
		print("  grade=%d（%d 層先）で入口に立ったとき" % [
			GameManager.get_floor_torch_grade(), GameManager.get_floor_reveal_layers()
		])
		print("    見える = %s / 伏せられている = %s" % [str(shown_by_layer), str(hidden_by_layer)])
		print("     （⚠ 層1と層2が見え、⚠ 奥は伏せられ、⚠ ボスの層だけは常に見えるのが正解）")

		# ショップ。⚠ 無料ガチャは grant_chest の1本を通る。
		print("[DebugBoot] --- フロア内ショップ ---")
		GameManager._state[GameStateKeys.PENDING_CHESTS] = []
		var gacha_hits: int = 0
		for _i: int in range(20):
			if GameManager.grant_floor_gacha():
				gacha_hits += 1
		print("  無料ガチャ 20回 -> 積まれた %d 個（⚠ 20 が正解＝ハズレ枠が無い）" % gacha_hits)
		GameManager._state[GameStateKeys.PENDING_CHESTS] = []

		var heal_before: bool = GameManager.buy_floor_heal()
		print("  全員満タンで回復を買う -> %s（false が正解）" % str(heal_before))
		GameManager.set_floor_hp_carry({str(GameManager.get_party_members()[0]): 1})
		print("  1人だけ HP=1 にして買う -> %s（true が正解） 傷 %s" % [
			str(GameManager.buy_floor_heal()), str(GameManager.get_floor_hp_carry())
		])
		GameManager.abandon_floor()
		print("  abandon_floor() 後の たいまつ = %d（0 が正解＝フロアごとにリセット）" % (
			GameManager.get_floor_torch_grade()
		))

	# --- 12. 周回の自動処理（段階14-f・EXEC_SCENARIO_AUTORUN.md）---
	#
	# ⚠ 宿題49 がここで閉じる。
	# ⚠ いちばん危ないのは「周回だけ宝箱の数が違う」。歩く経路が初回と別だと
	#   無音でそうなる。初回と同じ move_to_node() を通していることを、数で見る。
	print("[DebugBoot] --- 周回の自動処理 ---")
	var auto_floor: String = floor_ids[0]
	print("  未クリアで周回 -> 断る理由 = '%s'（not_cleared が正解）" % (
		GameManager.get_floor_auto_reject_reason(auto_floor)
	))
	GameManager.mark_stage_cleared(auto_floor, 0)
	GameManager.add_stamina(9999)
	print("  クリア済みにした -> 断る理由 = '%s'（空が正解）" % (
		GameManager.get_floor_auto_reject_reason(auto_floor)
	))

	# ⚠ 20周ぶん回して、1周あたりの宝箱を初回（2.01個/周）と突き合わせる。
	GameManager._state[GameStateKeys.PENDING_CHESTS] = []
	var auto_rounds: int = 20
	var auto_chests: int = 0
	var auto_gacha: int = 0
	var auto_steps: int = 0
	var auto_zero: int = 0
	for _r: int in range(auto_rounds):
		var res: Dictionary = GameManager.run_floor_auto(auto_floor)
		var got: int = int(res.get(GameManager.AUTO_RUN_CHESTS, 0))
		auto_chests += got
		auto_gacha += int(res.get(GameManager.AUTO_RUN_GACHA, 0))
		auto_steps += int(res.get(GameManager.AUTO_RUN_STEPS, 0))
		if got <= 0:
			auto_zero += 1
	print("  %d周 -> 宝箱 %d 個（%.2f 個/周・⚠ 初回の実測 2.01 と同じ桁が正解）" % [
		auto_rounds, auto_chests, float(auto_chests) / float(auto_rounds)
	])
	print("  歩数 %.1f 手/周（層数 %d が正解） / ショップのガチャ %d 個" % [
		float(auto_steps) / float(auto_rounds),
		GameManager.get_floor_layer_count(auto_floor), auto_gacha
	])
	print("  ⚠ 1個も出なかった周 = %d（0 が正解＝保証は周回でも効く）" % auto_zero)
	print("  周回のあと is_in_floor()=%s（false が正解＝降りている）" % str(GameManager.is_in_floor()))
	GameManager._state[GameStateKeys.PENDING_CHESTS] = []

	# ⚠ フロアの途中では周回できない。
	if GameManager.start_floor(auto_floor):
		print("  フロアの途中で周回 -> 断る理由 = '%s'（in_floor が正解）" % (
			GameManager.get_floor_auto_reject_reason(auto_floor)
		))
		GameManager.abandon_floor()

	# --- 7. セーブ→ロードの往復（int() 正規化・EXEC_SCENARIO_FLOOR.md §3-3）---
	#
	# ⚠ debug_boot はセーブを書かない（_ready() の注記）。なので JSON の往復だけを再現する。
	#   JSON.parse_string() を通すと数値は全部 float になる。load_state() がそれを
	#   int() に戻せていなければ、セーブに "layer": 3.0 と書かれ続ける（CLAUDE.md 3番）。
	# ⚠ 宿題57（STORY の current_chapter 1.0 / stars 0.0）がまさにこの形で起きている。
	print("[DebugBoot] --- セーブ→ロードの往復（int() 正規化）---")
	if GameManager.start_floor(floor_ids[0]):
		GameManager.move_to_node(str(GameManager.get_available_moves()[0]))
		var json_text: String = JSON.stringify(GameManager.get_state())
		var restored: Variant = JSON.parse_string(json_text)
		if not (restored is Dictionary):
			push_error("[DebugBoot] JSON の往復に失敗した")
		else:
			var raw_run: Dictionary = (restored as Dictionary).get(GameStateKeys.FLOOR_RUN, {})
			var raw_nodes: Dictionary = raw_run.get(GameStateKeys.FLOOR_RUN_NODES, {})
			var sample_id: String = str(raw_nodes.keys()[0])
			print("  JSON を通した直後 layer の型 = %s（float=%d が JSON の素の姿）" % [
				type_string(typeof((raw_nodes[sample_id] as Dictionary)[GameStateKeys.FLOOR_NODE_LAYER])),
				TYPE_FLOAT,
			])
			var loaded: bool = GameManager.load_state(restored as Dictionary)
			var after_run: Dictionary = GameManager.get_floor_run()
			var after_nodes: Dictionary = after_run.get(GameStateKeys.FLOOR_RUN_NODES, {})
			var floats: Array[String] = []
			for node_id: Variant in after_nodes:
				var layer_value: Variant = (after_nodes[node_id] as Dictionary).get(GameStateKeys.FLOOR_NODE_LAYER, 0)
				if typeof(layer_value) != TYPE_INT:
					floats.append(str(node_id))
			print("  load_state() = %s / floor_id='%s' position='%s' ノード %d 件" % [
				str(loaded),
				str(after_run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")),
				str(after_run.get(GameStateKeys.FLOOR_RUN_POSITION, "")),
				after_nodes.size(),
			])
			print("  ⚠ layer が int でないノード = %d 件（0 が正解）" % floats.size())
			print("  torch_grade の型 = %s / chest_count の型 = %s（どちらも int が正解）" % [
				type_string(typeof(after_run.get(GameStateKeys.FLOOR_RUN_TORCH_GRADE, 0))),
				type_string(typeof(after_run.get(GameStateKeys.FLOOR_RUN_CHEST_COUNT, 0))),
			])
	GameManager.abandon_floor()

	# --- 8. フロアに入っていない状態の器（新規開始の形）---
	GameManager.reset_to_new_game()
	var fresh: Dictionary = GameManager.get_floor_run()
	var fresh_keys: Array = fresh.keys()
	fresh_keys.sort()
	print("[DebugBoot] --- 新規開始の floor_run ---")
	print("  欄 %d 件（9 が正解）= %s" % [fresh_keys.size(), str(fresh_keys)])
	print("  floor_id='%s'（空が正解） is_in_floor()=%s（false が正解）" % [
		str(fresh.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")), str(GameManager.is_in_floor())
	])

	print("[DebugBoot] ⚠ 状態は書き換えたが保存していない。is_in_floor()=%s" % str(GameManager.is_in_floor()))


# いまのフロアを入口からボスまで歩き切る。⚠ 毎回いちばん手前の分岐を選ぶ。
func _walk_to_boss() -> void:
	var steps: int = 0
	while true:
		var moves: Array = GameManager.get_available_moves()
		if moves.is_empty():
			return
		if not GameManager.move_to_node(str(moves[0])):
			return
		steps += 1
		if steps > 50:
			push_error("[DebugBoot] _walk_to_boss が50手で終わらない")
			return


# entry から next をたどって全ルートを集める。
#
# ⚠ 層構造なので閉路は無い。あっても 50 段で打ち切る。
func _walk_all_routes(
		nodes: Dictionary, node_id: String, path: Array, out_routes: Array, out_reached: Dictionary
) -> void:
	out_reached[node_id] = true
	var next_path: Array = path.duplicate()
	next_path.append(node_id)
	if next_path.size() > 50:
		push_error("[DebugBoot] ルートが50段を超えた（閉路の疑い）")
		return
	var node: Variant = nodes.get(node_id, null)
	var next_ids: Array = []
	if node is Dictionary:
		next_ids = (node as Dictionary).get(GameStateKeys.FLOOR_NODE_NEXT, [])
	if next_ids.is_empty():
		out_routes.append(next_path)
		return
	for raw_next: Variant in next_ids:
		_walk_all_routes(nodes, str(raw_next), next_path, out_routes, out_reached)


# 拠点の下段が横にはみ出していないかを数字で見る。
#
# ⚠ ヘッドレスは描画がダミーだが、⚠ レイアウトの計算（最小サイズの伝播）は走る。
#   ⚠ 「絵は取れない」と「寸法も取れない」は別。ここで取れるのは寸法だけ。
# ⚠ 見るのは get_combined_minimum_size().x。⚠ これが画面幅を超えている器が
#   1つでもあると、⚠ 親が anchors_preset=15 / grow_horizontal=2 なので
#   左右に均等にはみ出して両端が切れる（2026-08-23に実際にそうなった）。
# 仮アセットのアイコン（2026-08-31）。⚠ 画面の絵は取れないので、
#   ⚠ 出るはずの「字・右下の数字・色」を値として出すのがここの仕事。
#
# ⚠ 見るのは3つ：
#   1. ja.csv の字が当たっているか（キー名がそのまま出ていないか＝再インポート未了）
#   2. 右下の数字が段数と合っているか（装備＝等級 ／ 装飾・素材＝段階 ／ レリック＝無し）
#   3. 色が10色のどれになるか（等級・段階の写し違いはここでしか見えない）
#
# ⚠ 2026-09-07：字は 2文字 → **1文字**（人間の指示「絵文字があるので文字は1文字でいい」）。
#   ⚠ 長さの検査もそれに合わせた。⚠ 2文字に戻すなら length() != 1 のほうも戻すこと。
func _report_item_icons() -> void:
	print("[DebugBoot] --- 仮アセットのアイコン（⚠ 字・右下の数字・色）---")
	# [item_id, 渡す等級（装備の個体だけ。0 なら item_id から引く）]
	var samples: Array = [
		["weapon_wooden_sword", 1], ["armor_iron_mail", 4],
		["acc_ring_power", 7], ["weapon_steel_sword", 10],
		["part_gem_atk_1", 0], ["part_gem_atk_4", 0],
		["part_charm_mdef_2", 0], ["part_emblem_crit_dmg_3", 0],
		["part_rune_buff_1", 0], ["part_rune_shield_5", 0],
		["construction_material_1", 0], ["decor_material_4", 0],
		["stamina_potion", 0], ["relic_thorns", 0],
	]
	var missing_keys: int = 0
	var wrong_length: int = 0
	for sample: Variant in samples:
		var row: Array = sample
		var item_id: String = str(row[0])
		# ⚠⚠ 右下の数字は「持っている数」（2026-09-10・人間の決定「⚠ 等級の数字を消して
		#   ⚠ そこにスタック数をかく」）。⚠ ここは数を渡さないので**空が正解**。
		#   ⚠ 前はここに等級・段数が出ていた。⚠ 空でなくなったら回帰。
		var icon: ItemIcon = ItemIcon.create(item_id, int(row[1]))
		add_child(icon)
		var text: String = icon.text_label.text
		var number: String = icon.grade_label.text
		if number != "":
			push_error("[DebugBoot] 数を渡していないのに右下に '%s' が出ている（%s）" % [
				number, item_id
			])
		# ⚠ 中央は絵文字か線画か。⚠ 部品に聞く（⚠ ここで中を覗かない）。
		var center: String = icon.get_center_debug_text()
		var box: StyleBox = icon.get_theme_stylebox("panel")
		# ⚠ 等級は **枠線** の色（2026-09-08 に地から移した）。⚠ 地は全部同じ暗い一色なので、
		#   ⚠ bg_color を出しても等級が読めない（⚠ 移した日に1回それで意味を失った）。
		var color: Color = (box as StyleBoxFlat).border_color if box is StyleBoxFlat else Color.BLACK
		if text == "ui_icon_" + item_id:
			missing_keys += 1
		elif text.length() != 1:
			wrong_length += 1
		# ⚠ 絵文字も出す（2026-09-07）。⚠ レリック12件が ITEM_FALLBACK（📦）に
		#   落ちていたのを、⚠ ここが出していなかったせいで気づけなかった。
		print("  %-26s 中央='%s' 字='%s' 右下='%s'（⚠ 空が正解） 枠=(%.2f, %.2f, %.2f)" % [
			item_id, center, text, number, color.r, color.g, color.b
		])
		remove_child(icon)
		icon.queue_free()

	# ⚠ 数を渡したときだけ右下に出ること（⚠ 0個も出る＝素材タブが0個を並べるため）。
	print("  ⚠ 数を渡したとき（⚠ 素材タブ・鞄・宝箱の窓が通る道）")
	for probe_count: int in [0, 1, 12, 999]:
		var counted: ItemIcon = ItemIcon.create("construction_material_1", 0, probe_count)
		add_child(counted)
		print("    count=%-4d -> 右下='%s'（⚠ '%d' が正解）" % [
			probe_count, counted.grade_label.text, probe_count
		])
		if counted.grade_label.text != str(probe_count):
			push_error("[DebugBoot] 右下に個数が出ていない（count=%d）" % probe_count)
		remove_child(counted)
		counted.queue_free()
	if missing_keys > 0:
		push_error("[DebugBoot] ja.csv に ui_icon_* が %d 件無い（キー名がそのまま出る）" % missing_keys)
	if wrong_length > 0:
		push_warning("[DebugBoot] ui_icon_* に1文字でないものが %d 件（左上からはみ出す）" % wrong_length)


func _report_layout() -> void:
	# ⚠ フロアの報告はこの関数の手前に置いてある（_report_floor / _walk_all_routes）。
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	print("[DebugBoot] viewport = %.0f x %.0f" % [viewport_size.x, viewport_size.y])

	# ⚠ 最悪ケースを作ってから測る。初期状態の素材は2件しかないが、
	#   F4 の「素材を全種類」を押すと16件・4桁になる。⚠ 溢れるのはそちら。
	#   ⚠ 「手元では収まっていた」で見逃さないため、必ず全部入れてから測る。
	var material_count: int = 0
	for item_id: Variant in MasterDataLoader.get_all_items():
		var definition: Dictionary = MasterDataLoader.get_item(str(item_id))
		if str(definition.get(GameManager.ITEM_MASTER_STORAGE, "")) != GameManager.ITEM_STORAGE_MATERIAL:
			continue
		GameManager.add_material(str(item_id), 2999)
		material_count += 1
	print("[DebugBoot] 素材を %d 種類（4桁）入れてから測る" % material_count)

	# ⚠ 2026-08-31・仮アセットのアイコンを足した回で追加。倉庫とショップの行は
	#   コードで積むので、持ち物が空だと器が 108 x 80 で返る（＝何も測れていない）。
	#   ⚠ 「もっともらしい小さい数字を信じない」（NEXT_STEPS §4）。
	# ⚠ 装備は add_to_inventory() が個体を作る（CLAUDE.md 8番）。直接 inventory を書かない。
	var inventory_count: int = 0
	for item_id: Variant in MasterDataLoader.get_all_items():
		var definition: Dictionary = MasterDataLoader.get_item(str(item_id))
		var item_type: String = str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, ""))
		if item_type == GameStateKeys.ITEM_TYPE_MATERIAL:
			continue
		# ⚠ ラン専用の品（段階17-c）は拠点の倉庫に入らないもの。⚠ 測るためだけに
		#   入れると、⚠ 遊びでは起こりえない状態を道具が作ることになる（決定17・§4-3-1）。
		if item_type == GameStateKeys.ITEM_TYPE_DUNGEON:
			continue
		GameManager.add_to_inventory(str(item_id), 1, item_type)
		inventory_count += 1
	print("[DebugBoot] 持ち物を %d 種類入れてから測る" % inventory_count)

	_report_item_icons()

	var packed: PackedScene = load(SCENE_BASE)
	if packed == null:
		push_error("[DebugBoot] base_screen.tscn が読めない")
		return
	var root: Control = packed.instantiate()
	# ⚠ call_deferred でないと弾かれる（"Parent node is busy setting up children"）。
	#   ⚠ _ready() の中から root に add_child しているため。⚠ 弾かれても赤が1本出るだけで
	#     測定は続き、⚠ 「全部0」というもっともらしい数字が出る（2026-08-23に踏んだ）。
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame
	root.size = viewport_size
	# ⚠ さらに2フレーム待つ。画面の _ready() が足す子（編成ボタン・素材欄）が
	#   最小サイズに反映されるまで1フレームでは足りない。
	await get_tree().process_frame
	await get_tree().process_frame

	if not root.is_inside_tree():
		push_error("[DebugBoot] base_screen をツリーに入れられなかった（測定は無効）")
		return

	print("[DebugBoot] --- 器の最小幅（⚠ %.0f を超えたら はみ出す）---" % viewport_size.x)
	for path: String in LAYOUT_PATHS:
		var node: Variant = root.get_node_or_null(NodePath(path))
		if not (node is Control):
			print("  %-46s （無い）" % path)
			continue
		var control: Control = node
		var minimum: Vector2 = control.get_combined_minimum_size()
		var over: String = "  ⚠ はみ出す（+%.0f）" % (minimum.x - viewport_size.x) if minimum.x > viewport_size.x else ""
		print("  %-46s 最小 %6.0f x %-5.0f 実際 %6.0f x %-5.0f%s" % [
			path, minimum.x, minimum.y, control.size.x, control.size.y, over
		])

	print("[DebugBoot] --- 下段の1件ずつ（⚠ 合計が画面幅を超えていないか）---")
	for parent_path: String in LAYOUT_ROWS:
		var parent: Variant = root.get_node_or_null(NodePath(parent_path))
		if not (parent is Control):
			continue
		var total: float = 0.0
		var separation: float = float((parent as Control).get_theme_constant("separation"))
		print("  %s（separation=%.0f）" % [parent_path, separation])
		for child: Node in (parent as Control).get_children():
			if not (child is Control):
				continue
			var child_min: Vector2 = (child as Control).get_combined_minimum_size()
			total += child_min.x
			print("    %-24s 最小幅 %6.0f" % [child.name, child_min.x])
		total += separation * float(maxi((parent as Control).get_child_count() - 1, 0))
		var verdict: String = "⚠ はみ出す" if total > viewport_size.x else "収まる"
		print("    合計（separation 込み）= %.0f / %.0f … %s" % [total, viewport_size.x, verdict])

	root.queue_free()

	# --- 手書きした .tscn が開くか ---
	print("[DebugBoot] --- 他の画面が開くか（⚠ 最小幅も見る）---")
	# ⚠ マップ画面はフロアに入っていないと _ready() が冒険選択へ戻す（段階14-c）。
	#   ⚠ 測るために先に1本入れておく。⚠ 保存はしない。
	if not GameManager.is_in_floor():
		var _started: bool = GameManager.start_floor("floor_5")
	# ⚠ 難ダンジョンのマップ（段階17-d）も同じ。⚠ ランに入っていないと戻される。
	#   ⚠ 鞄にポーションを入れてから測る。⚠ 空だとポーションの行が1行も出ず、
	#     一番横に長い行（アイコン＋名前＋3人ぶんのボタン）を measure できない。
	if not GameManager.is_in_dungeon():
		var _entered: bool = GameManager.start_dungeon_run()
		var _got: int = GameManager.add_to_dungeon_bag("dungeon_potion_heal", 1)
		var _got2: int = GameManager.add_to_dungeon_bag("dungeon_potion_revive", 1)
	# ⚠⚠ 宿題73（2026-09-06に解消）：⚠ 難ダンジョンの3枚は「戻さない条件」を先に作る。
	#   ⚠ 宝箱   … 拾い待ちがあること（⚠ ボスの戦利品が拾い待ちへ行く＝決定29）
	#   ⚠ ショップ … ボスを倒した先であること（決定15）
	#   ⚠ レリック … DUNGEON_NODE_ID が渡されていること（⚠ 下の _layout_transfer_for()）
	# ⚠ 画面側の条件を緩めていない。⚠ 満たしてから開いている。
	for scene_path: String in LAYOUT_SCENES:
		_layout_prepare_for(scene_path)
		var other: PackedScene = load(_layout_load_path(scene_path))
		if other == null:
			push_error("[DebugBoot] 開けない: " + scene_path)
			continue
		# ⚠ 装備画面は character_id を渡さないと黄を1本出す（正常な保険）。
		#   ⚠ 測るためだけに黄を増やさない。先に渡しておく。
		SceneManager._transfer_data = _layout_transfer_for(scene_path)
		var instance: Node = other.instantiate()
		get_tree().root.add_child.call_deferred(instance)
		await get_tree().process_frame
		if instance is Control:
			(instance as Control).size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		# ⚠ ルートを測らないこと。画面のルートは素の Control で、子の MarginContainer は
		#   アンカー配置なので、get_combined_minimum_size() が必ず 0 を返す。
		#   2026-08-25 まで6シーンとも「最小幅 0」と出ており、横も縦も測れていなかった。
		# ⚠ 測るのは中の一番外側の Container（＝Margin）。
		# ⚠ 開いた直後の姿だけでは足りない。育成画面は「一覧」と「詳細」が
		#   排他で、縦に長いのは詳細のほう。開いた直後は一覧なので見逃す
		#   （2026-08-25 に人間が実機で見つけた縦のはみ出しが、これで測れていなかった）。
		# ⚠ 表を1行足すだけで済む形にする。画面ごとに if を書かないこと。
		for raw_path: Variant in LAYOUT_SCENE_SHOW.get(scene_path, {}).keys():
			var target: Variant = instance.get_node_or_null(NodePath(str(raw_path)))
			if target is Control:
				(target as Control).visible = bool(LAYOUT_SCENE_SHOW[scene_path][raw_path])
		await get_tree().process_frame

		# ⚠ 測る器。⚠ 既定は「一番外側の Container」だが、⚠ それでは当たらない画面が
		#   ある（⚠ 戦闘は `UnitView` の `StatusChips` を先に拾って `0 x 0` になる）。
		#   ⚠ 表に1行足して指す。⚠ 画面ごとに if を書かないこと。
		var box: Control = null
		var named: String = str(LAYOUT_SCENE_BOX.get(scene_path, ""))
		if named != "":
			var picked: Variant = instance.get_node_or_null(NodePath(named))
			if picked is Control:
				box = picked as Control
			else:
				push_error("[DebugBoot] 測る器が見つからない: %s / %s" % [scene_path.get_file(), named])
		else:
			box = _outermost_container(instance)
		var minimum: Vector2 = box.get_combined_minimum_size() if box != null else Vector2.ZERO
		# ⚠ 基準は project.godot の window/size（1280 x 720）。ヘッドレスの viewport は
		#   1280 x 1280 で高さが違うため、そのまま使うと縦のはみ出しを見逃す。
		var over: String = ""
		if minimum.x > SCREEN_SIZE.x:
			over += "  ⚠ 横にはみ出す（+%.0f）" % (minimum.x - SCREEN_SIZE.x)
		if minimum.y > SCREEN_SIZE.y:
			over += "  ⚠ 縦にはみ出す（+%.0f）" % (minimum.y - SCREEN_SIZE.y)
		print("  %-46s 最小 %.0f x %.0f（基準 %.0f x %.0f）%s" % [
			scene_path.get_file(), minimum.x, minimum.y, SCREEN_SIZE.x, SCREEN_SIZE.y, over
		])
		# ⚠ コードで描く線（段階19-e）。⚠ 絵は取れないが「何本引いたか」は取れる。
		#   ⚠ 0 本なら通路が1本も見えていない（⚠ 人間が実機で報告した症状そのもの）。
		#   ⚠ 画面ごとに if を書かない。⚠ その部品を持っている画面だけが出る。
		# ⚠ 面に重ねた「当たり」を何枚見たか（⚠ 0 枚なら下の検査が素通りしている）。
		var hits_checked: int = 0
		for raw_child: Node in instance.find_children("*", "Control", true, false):
			# ⚠⚠ ヘッダーの戻るが空になっていないか（2026-09-14・人間が実機で発見）。
			#   ⚠ 「⚠ ステータスノードとスキルの戻るボタンがつぶれてる」。⚠ 原因は
			#   ⚠ `set_back_text()` のあとに `set_subtitle_text()` を呼ぶと `_refresh()` が
			#   ⚠ 戻るの文字を `tr("")` で上書きしていたこと。⚠ 空の戻るは潰れて見える。
			if raw_child is ScreenHeader:
				var back: Button = (raw_child as ScreenHeader).back_button
				if back != null and back.visible:
					print("    ⚠ 戻る = '%s'（⚠ 空なら潰れている）" % back.text)
					if back.text == "":
						push_error("[DebugBoot] %s の戻るが空（潰れて見える）" % scene_path.get_file())
			# ⚠ タイマーの輪（2026-09-09）。⚠ 絵は取れないが「数字が何枚あるか」は取れる。
			#   ⚠⚠ 人間が実機で「タイマーが二重になってる」と見つけた事故の再発を止めるため。
			#   ⚠ 原因は `.tscn` 側の子とコードで作る子の**両方が出た**こと。⚠ 1枚が正解。
			if raw_child is TimerRing:
				var labels: int = 0
				for grand: Node in raw_child.get_children():
					if grand is Label:
						labels += 1
				print("    ⚠ タイマーの数字 = %d 枚（1 枚が正解。2 枚なら重なっている）" % labels)
				if labels != 1:
					push_error("[DebugBoot] タイマーの数字が %d 枚（1 枚でないと重なる）" % labels)
			# ⚠⚠ 振り返りの「何文字以上か」（2026-09-10）。⚠ 前はビューに `20` を直書きしていて、
			#   ⚠ `Balance.pomodoro.reflection_min_chars` の欄は在るのに誰も読んでいなかった
			#   （⚠ Inspector で変えても何も起きない状態だった）。
			#   ⚠ 文言の中の数字も Config から入れるので、⚠ ここで文と設定の一致まで見る。
			#   ⚠ `InstructionLabel` という名前は他の画面にも在るので、⚠ 振り返りに絞る。
			if scene_path.get_file() == "reflection_view.tscn" and (
				raw_child is Label and raw_child.name == "InstructionLabel"
			):
				var want: int = int(Balance.pomodoro.reflection_min_chars)
				var shown: String = (raw_child as Label).text
				print("    ⚠ 振り返りの文言 = '%s'（⚠ Config の %d が入るのが正解）" % [shown, want])
				if not shown.contains(str(want)):
					push_error("[DebugBoot] 振り返りの文言に Config の文字数(%d)が入っていない" % want)
			# ⚠⚠ 育成（2026-09-27・回UI-組 育成・人間「⚠ 1い」）。⚠ 前は一覧の行・ステータスノード・スキルの
			#   ⚠ 画面を別々に見ていた。⚠ いまは1画面の中のタブなので、⚠ `#タブ` で開き分けて同じ名前を見る。
			#   ⚠ 絵は取れないが「何行あるか」と「何と書いてあるか」は取れる（⚠ 行はコードで作る＝0 行なら組めていない）。
			var training_tab: String = scene_path.get_slice("#", 1) if scene_path.contains("#") else ""
			var in_training: bool = _layout_load_path(scene_path).get_file() == "training_screen.tscn"
			# ⚠ 右上のキャラの札（⚠ 前の一覧の代わり）。⚠ 0 枚なら切り替えられない。
			if in_training and training_tab == "" and raw_child.name == "Chips":
				var chips: int = 0
				for grand: Node in raw_child.get_children():
					if grand is CharacterAvatar:
						chips += 1
				print("    ⚠ 育成のキャラの札 = %d 枚（0 枚なら切り替えられない）" % chips)
				if chips <= 0:
					push_error("[DebugBoot] 育成のキャラの札が 0 枚")
			# ⚠ 身上書の10軸（⚠ 前の「振ったあとのステータス」の代わり）。⚠ 10軸ぜんぶ出ているか。
			if in_training and training_tab == "" and raw_child.name == "Stats" and raw_child.get_parent() is CharacterDossier:
				var stat_rows: int = raw_child.get_child_count()
				print("    ⚠ 身上書の値 = %d 行" % stat_rows)
				if stat_rows != GameManager.get_stat_keys().size():
					push_error("[DebugBoot] 身上書の値が %d 行（%d 軸あるはず）" % [
						stat_rows, GameManager.get_stat_keys().size()
					])
			# ⚠ 概要の行（⚠ ステータスノード・スキル・装備）。
			if in_training and training_tab == "" and raw_child.name == "Rows":
				var lines: Array[String] = []
				for grand: Node in raw_child.get_children():
					if grand is PanelContainer:
						lines.append(_row_text(grand as PanelContainer))
				print("    ⚠ 概要の行 = %d 行" % lines.size())
				for text: String in lines:
					print("      %s" % text)
				if lines.is_empty():
					push_error("[DebugBoot] 育成の概要の行が 0 行")
			# ⚠ 修練の道（パッシブ）。⚠ 何 pt で開くかの字が全部の行にあるか。
			if training_tab == TransferKeys.TRAINING_TAB_NODES and raw_child.name == "Passives":
				var passive_rows: int = 0
				var with_points: int = 0
				for grand: Node in raw_child.get_children():
					if not str(grand.name).begins_with("Passive_"):
						continue
					passive_rows += 1
					var points: Node = grand.find_child("PointsLabel", false, false)
					if points is Label and (points as Label).text != "":
						with_points += 1
				print("    ⚠ 修練の道 = %d 行 ／ pt の字 = %d 行（⚠ 同じ数が正解）" % [passive_rows, with_points])
				if passive_rows > 0 and with_points != passive_rows:
					push_error("[DebugBoot] 修練の道の pt が %d / %d 行にしか出ていない" % [with_points, passive_rows])
			if training_tab == TransferKeys.TRAINING_TAB_SKILLS and (
				raw_child.name == "Slots" or raw_child.name == "Candidates"
			):
				var lines: Array[String] = []
				for grand: Node in raw_child.get_children():
					if grand is PanelContainer:
						lines.append(_row_text(grand as PanelContainer))
				print("    ⚠ スキルの%s = %d 件（0 件なら組めていない）" % [raw_child.name, lines.size()])
				for text: String in lines:
					print("      %s" % text)
				if lines.is_empty():
					push_error("[DebugBoot] スキルのタブの %s が 0 件" % raw_child.name)
			# ⚠ ステータスノードの軸の行（⚠ 1軸 = 1行 + 点の列。⚠ 段は `TierDots` から取る）。
			if training_tab == TransferKeys.TRAINING_TAB_NODES and raw_child.name == "Branches":
				var branch_count: int = 0
				for grand: Node in raw_child.get_children():
					if not (grand is PanelContainer):
						continue
					branch_count += 1
					var dots: Array[Node] = grand.find_children("Dots", "Control", true, false)
					var tier_text: String = "点が無い"
					if not dots.is_empty() and dots[0] is TierDots:
						tier_text = (dots[0] as TierDots).to_text() + " 段"
					print("      %s = %s ／ %s" % [
						grand.name, tier_text, _row_text(grand as PanelContainer)
					])
				print("    ⚠ 割り振りの軸 = %d 行（0 行なら組めていない）" % branch_count)
				if branch_count <= 0:
					push_error("[DebugBoot] ステータスノードの軸が 0 行")
			# ⚠ 装備のタブ（⚠ 部位5行 ／ 候補）。⚠ 下ごしらえで装飾を刺した品を着せてあるので ◆ が出るはず。
			if training_tab == TransferKeys.TRAINING_TAB_EQUIP and (
				raw_child.name == "SlotColumn" or raw_child.name == "Candidates"
			):
				var lines: Array[String] = []
				for grand: Node in raw_child.get_children():
					if grand is PanelContainer:
						lines.append(_row_text(grand as PanelContainer))
				print("    ⚠ 装備の%s = %d 件" % [raw_child.name, lines.size()])
				for text: String in lines:
					print("      %s" % text)
				if raw_child.name == "SlotColumn" and lines.size() != GameManager.get_equip_slots().size():
					push_error("[DebugBoot] 装備のタブの部位が %d 行（%d 部位あるはず）" % [
						lines.size(), GameManager.get_equip_slots().size()
					])
			# ⚠⚠ 持ち物の右の紙の装飾の枠（2026-09-22・回3 → ⚠ 09-27 に装備画面から移った）。⚠ 「マス＋吹き出し」。
			#   ⚠ 下ごしらえ（`_layout_fill_equipment_parts()`）で1つ刺した武器を選んで開くので、
			#   ⚠ **0 行なら枠が出ていない**。
			var in_belongings: bool = _layout_load_path(scene_path).get_file() == "warehouse_screen.tscn"
			if in_belongings and raw_child.name == "Rows":
				var lines: Array[String] = []
				for grand: Node in raw_child.get_children():
					if grand is PanelContainer:
						lines.append(_row_text(grand as PanelContainer))
				print("    ⚠ 持ち物の行 = %d 行" % lines.size())
				for text: String in lines.slice(0, 6):
					print("      %s" % text)
			if in_belongings and raw_child is BelongingsDetail:
				var buttons: Array[String] = []
				for node: Node in raw_child.find_children("*", "Button", true, false):
					var button: Button = node as Button
					if button.text != "":
						buttons.append("[%s%s]" % [button.text, "・押せない" if button.disabled else ""])
				print("    ⚠ 右の紙のボタン = %s" % " ".join(buttons))
			if in_belongings and raw_child is PartSlotRow:
				var part_row: PartSlotRow = raw_child
				print("    ⚠ 装飾の枠 %s = %d/%d ／ %s" % [
					part_row.name, part_row.get_filled_count(), part_row.get_open_count(),
					part_row.to_text(),
				])
				if part_row.get_open_count() <= 0:
					push_error("[DebugBoot] %s に開いている枠が無い" % part_row.name)
			# ⚠⚠ 面に重ねた「当たり」が本当に押せるか（2026-09-11・人間が実機で
			#   ⚠ 「⚠ ギルド画面でボタンが反応しない」と見つけた事故の再発防止）。
			#
			# ⚠ 絵もクリックも取れないが、⚠ **押下を食べる器が当たりの上に乗っていないか**
			#   ⚠ は取れる。⚠ 当たりは面の一番下に敷くので、⚠ 上に居る兄弟とその子が
			#   ⚠ `MOUSE_FILTER_IGNORE` でないと押下がそこで止まる。
			# ⚠ `BaseButton`（面の中の本物のボタン）は `STOP` のままで正しい。
			if raw_child is Button and raw_child.name == "Hit":
				hits_checked += 1
				var blockers: Array[String] = []
				var panel: Node = raw_child.get_parent()
				for sibling: Node in panel.get_children():
					if sibling == raw_child:
						continue
					for inner: Node in ([sibling] + sibling.find_children("*", "Control", true, false)):
						if inner is BaseButton:
							continue
						if inner is Control and (inner as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
							blockers.append("%s(%s)" % [inner.name, inner.get_class()])
				if not blockers.is_empty():
					push_error("[DebugBoot] 当たりの上に押下を食べる器: %s / %s" % [
						panel.name, " ".join(blockers)
					])
				# ⚠⚠ ホバーの縁が**面の外側**に出ているか（⚠ 人間の指摘「まだ内側に枠が出る」）。
				#   ⚠ `PanelContainer` は子を内側の余白ぶん内側に置くので、⚠ 当たりの縁は
				#   ⚠ **その余白ぶん外へ広げて**いないと面の内側に描かれる。
				var panel_style: StyleBox = (panel as PanelContainer).get_theme_stylebox(&"panel")
				var hover: StyleBox = (raw_child as Button).get_theme_stylebox(&"hover")
				if panel_style != null and hover is StyleBoxFlat:
					var flat: StyleBoxFlat = hover as StyleBoxFlat
					var want: float = panel_style.content_margin_left + flat.border_width_left
					if flat.expand_margin_left < want:
						push_error("[DebugBoot] ホバーの縁が面の内側に出る: %s（外へ %.0f / 要 %.0f）" % [
							panel.name, flat.expand_margin_left, want
						])
			# ⚠⚠ マップが真ん中にあるか（決定37・2026-09-19）。⚠ 人間「今は右側に表示されている」。
			#   ⚠ 絵は取れないが、⚠ マスの並びの中心と画面の中心の差は取れる。
			if raw_child is RunMapView:
				var map_rect: Rect2 = (raw_child as RunMapView).get_global_rect()
				# ⚠⚠ 2026-10-03（人間「⚠ 左側にインベントリやHPの状況などを」）：⚠ 左に板（`RunSide`）が入った＝⚠ 物差しは**地図の紙の真ん中**。
				#   ⚠ 紙が無い画面（⚠ 板の無い古い形）は今までどおり画面の真ん中。
				var sheet: Node = instance.find_child("MapSheet", true, false)
				var screen_rect: Rect2 = (sheet as Control).get_global_rect() if sheet is Control else instance.get_global_rect()
				var off: float = map_rect.get_center().x - screen_rect.get_center().x
				print("    ⚠ マップの中心 − 地図の紙の中心 = %.0f px（⚠ 0 に近いのが正解）／ マップの幅 %.0f" % [
					off, map_rect.size.x
				])
				if absf(off) > MAP_CENTER_TOLERANCE:
					push_error("[DebugBoot] マップが真ん中に無い（%.0f px ずれている）" % off)
				# ⚠ たいまつの暗さ（2026-09-19・モック v2 §0）。⚠ 見えている層の上に境目があるか。
				var fog_edge: float = (raw_child as RunMapView).get_fog_edge_y()
				print("    ⚠ たいまつ %d 層先 ／ 暗さの境目 y = %.0f（⚠ -1 なら暗さ無し）" % [
					(raw_child as RunMapView).torch_reveal_layers, fog_edge
				])
			# ⚠ 3人のHPのバー（2026-09-20・人間の指示「HPをバーにして見やすく」）。
			#   ⚠ 絵は取れないが「満ちている割合」は取れる。⚠ 削れていれば 1.0 未満になる。
			if raw_child is RunHpBar:
				print("    ⚠ HPのバー %s（割合 %.2f）" % [
					(raw_child as RunHpBar).to_text(), (raw_child as RunHpBar).get_ratio()
				])
			# ⚠ 遺物片の絵（2026-09-20・人間の指示「遺物片にあいこんを」）。⚠ 空なら絵が引けていない。
			if raw_child is ResourceDisplay and raw_child.name == "CurrencyValue":
				var texture: Texture2D = (raw_child as ResourceDisplay).icon_texture
				print("    ⚠ 遺物片の絵 = %s（⚠ 空なら引けていない）" % [
					"無し" if texture == null else texture.resource_path.get_file()
				])
				if texture == null:
					push_error("[DebugBoot] 遺物片の絵が引けていない")
				# ⚠⚠ 増えたときの演出の着地先（2026-09-20・人間の指示「⚠ リソース入手のエフェクトも実装」）。
				#   ⚠⚠ ここで実際に飛ばさないこと。⚠ 飛ばすと、⚠ 測り終えて画面を解放したときに
				#     ⚠ 飛んでいる最中のものが消えた相手を触り、⚠ 「Lambda capture ... was freed」が赤で6本出る
				#     （⚠ 2026-09-20 に実測）。⚠ 見るのは「⚠ 着地先（同じ resource_id の表示）が見つかるか」だけ。
				#   ⚠ 実際に飛ぶところは scenario=gain が見ている。
				if not ResourceGainEffect.is_ready():
					ResourceGainEffect.spawn_into(get_tree().root)
					await get_tree().process_frame
					await get_tree().process_frame
				var landing: Control = ResourceGainEffect._instance._find_display(
					GameStateKeys.DUNGEON_RUN_CURRENCY
				)
				print("    ⚠ 遺物片の演出の着地先 = %s（⚠ 無しなら飛んでも着地できない）" % [
					"無し" if landing == null else landing.name
				])
				if landing == null:
					push_error("[DebugBoot] 遺物片の入手の演出の着地先が見つからない")
				# ⚠⚠ 拾いものの窓の中の遺物片（2026-09-20・人間の指示「拾い物の中に、遺物片を見せてそこから飛ばす」）。
				#   ⚠ 見るのは GameManager 側だけ（⚠ 入った量を覚える → 受け取ると 0）。
				#   ⚠⚠ **窓をここで実際に開かない**：⚠ 開いて閉じると「Lambda capture ... was freed」が赤で6本出た
				#     （⚠ 2026-09-20・原因は未特定。⚠ 測定の途中で窓を作って壊す形そのものが怪しい）。
				#     ⚠ 窓に行が出ることは**人間が実機で見る**（⚠ §0-UI-N-5 の実機の項目）。
				GameManager.add_dungeon_currency(20)
				var gain_before: int = GameManager.peek_last_dungeon_currency_gain()
				var gain_after: int = GameManager.take_last_dungeon_currency_gain()
				print("    ⚠ 遺物片の入りの覚え = %d → 受け取ると %d（⚠ 20 → 0 が正解）" % [
					gain_before, GameManager.peek_last_dungeon_currency_gain()
				])
				if gain_before != 20 or gain_after != 20 or GameManager.peek_last_dungeon_currency_gain() != 0:
					push_error("[DebugBoot] 遺物片の入りの覚えが受け取りで消えていない")
			if raw_child is DungeonEdgeLines:
				var drawn: int = (raw_child as DungeonEdgeLines).get_line_count()
				# ⚠ 通路の真ん中に出す字（段階20-c）。⚠ 効果のある通路にだけ付くので
				#   ⚠ 線の本数より少ないのが正解。⚠ 0 本なら1つも出ていない。
				var labelled: int = (raw_child as DungeonEdgeLines).get_label_count()
				# ⚠ 一番横に長い線（段階20-g）。⚠ 人間の指摘「左から右に行く道がやたら」。
				#   ⚠ 列を揃えたので、⚠ 隣の列ぶんまでに収まるのが正解。
				var span: float = (raw_child as DungeonEdgeLines).get_max_horizontal_span()
				print("    ⚠ 通路の線 = %d 本（0 本なら通路が1本も見えていない） ／ 真ん中の字 = %d 個 ／ ⚠ 一番斜めな線の横幅 = %.0f px" % [
					drawn, labelled, span
				])
				# ⚠ 区画の切れ目の表示は 2026-09-20 に消した（人間の指示）。⚠ 数える検査も一緒に消した。
				if drawn <= 0:
					push_error("[DebugBoot] 通路の線が0本（段階19-e が効いていない）")
				# ⚠ 字が0個でも赤にしない。⚠ たいまつ等級1では1層先しか見えず、
				#   ⚠ そこに効果つきの通路が無いことがある（⚠ 5本に1本の抽選）。
				#   ⚠ 「字が出るか」自体は段階20-c で実測済み（101 → 2 個）。
				if labelled > drawn:
					push_error("[DebugBoot] 通路の字が線より多い（線1本に字が2つ付いている）")
				# ⚠⚠ 斜めの長さ（段階20-g）。⚠ 列を揃えたので隣の列ぶんまでが正解。
				#   ⚠ 入口（1ノード）から区画の入口3つへ広がるぶんだけ超える。
				if span > NODE_COLUMN_SPAN_LIMIT:
					push_error("[DebugBoot] 横に長すぎる通路がある（%.0f px。列が揃っていない）" % span)
		# ⚠ いま立っているマスへスクロールが寄っているか（段階20-c・人間の指示）。
		#   ⚠ 絵は取れないが「スクロール位置が0でない」ことは取れる。
		#   ⚠ 入口は一番下なので、⚠ 25層ぶん下へ寄っているはず。
		# ⚠ 2026-10-03：紙は左の板と並ぶ器（`Body`）へ移った＝名前で探す。
		var raw_scroll: Node = instance.find_child("MapScroll", true, false)
		if raw_scroll is ScrollContainer:
			var scroller: ScrollContainer = raw_scroll
			print("    ⚠ スクロール位置 = %d / 中身の高さ %d ／ 見える高さ %d（⚠ 入口は一番下なので 0 でないのが正解）" % [
				scroller.scroll_vertical, int(scroller.get_v_scroll_bar().max_value), int(scroller.size.y),
			])
			# ⚠ 2026-10-03（決定49）：1フロアが 10層になり、⚠ 検査の窓（見える高さ 960）にはマップが全部入る＝動かさないのが正解。
			#   ⚠ 中身が見える高さより大きいときだけ見る（⚠ 窓ありの撮影 `01_dungeon_map` では寄っている）。
			if scroller.get_v_scroll_bar().max_value > scroller.size.y and scroller.scroll_vertical <= 0:
				push_error("[DebugBoot] スクロールが先頭のまま（段階20-c が効いていない）")
		# ⚠⚠ 押したマスの近くの「できること」（2026-09-19・モック v2）。⚠ 拾いものの窓で最初のマスを押す。
		#   ⚠ 絵は取れないが「吹き出しが出たか・ボタンが何個か・画面の中に収まったか」は取れる。
		if instance is RunLootWindow:
			var loot: Node = instance.find_child("LootGrid", true, false)
			if loot is ItemGrid and loot.get_child_count() > 0:
				(loot.get_child(0) as ItemSlot).pressed.emit()
				await get_tree().process_frame
				await get_tree().process_frame
				# ⚠ find_children の型の絞り込みは class_name に効かない（⚠ 組み込みの型だけ）。⚠ 自分で探す。
				var pops: Array[Node] = []
				for child: Node in instance.get_children():
					if child is SlotActionPopover:
						pops.append(child)
				var texts: Array[String] = []
				var inside: bool = false
				if not pops.is_empty():
					for b: Node in pops[0].find_children("*", "Button", true, false):
						texts.append("%s%s" % [(b as Button).text, "(押せない)" if (b as Button).disabled else ""])
					inside = get_viewport().get_visible_rect().encloses((pops[0] as Control).get_global_rect())
				print("    ⚠ 拾い待ちのマスを押した → 吹き出し %d 枚 ／ ボタン %s ／ 画面の中 = %s" % [
					pops.size(), str(texts), str(inside)
				])
				if pops.size() != 1 or texts.is_empty():
					push_error("[DebugBoot] マスを押しても「できること」の吹き出しが出ない")
			# ⚠ 削れた「戦闘時 MAX HP」のバー（2026-09-20）。⚠ 満タンの画面しか測れないので、⚠ ここで作って見る。
			var probe: RunHpBar = RunHpBar.new()
			probe.set_values(58, 70)
			print("    ⚠ 削れたバー %s（割合 %.2f・⚠ 1.00 未満が正解＝削れたぶんが残る）" % [
				probe.to_text(), probe.get_ratio()
			])
			if probe.get_ratio() >= 1.0:
				push_error("[DebugBoot] 削れた戦闘時 MAX HP がバーに出ていない")
			probe.queue_free()
			# ⚠⚠ 閉じたときの自動収納の見せ方（決定40・モック v2 §8）。⚠ 失うものが無い＝1行 ／ ある＝窓。
			var line_a: String = RunLootWindow.present_auto_result(self, {
				RunLootWindow.AUTO_TAKEN: {"construction_material_4": 2}, RunLootWindow.AUTO_LOST: {},
			})
			var had_modal: bool = Modal._current != null and is_instance_valid(Modal._current)
			var line_b: String = RunLootWindow.present_auto_result(self, {
				RunLootWindow.AUTO_TAKEN: {"construction_material_4": 2},
				RunLootWindow.AUTO_LOST: {"training_material_4": 1},
			})
			await get_tree().process_frame
			var modal_b: bool = Modal._current != null and is_instance_valid(Modal._current)
			print("    ⚠ 自動収納：失うもの無し → 行 '%s' ／ 失うものあり → 行 '%s'・窓 %s（⚠ 前から窓 %s）" % [
				line_a, line_b, str(modal_b), str(had_modal)
			])
			if line_a == "" or line_b != "" or not modal_b:
				push_error("[DebugBoot] 自動収納の結果の見せ方が混ぜ方どおりでない")
			if modal_b and not had_modal:
				Modal._current.queue_free()
				Modal._current = null
		# ⚠ 面に重ねた当たりを持つ画面だけ出す（⚠ 0 枚の画面は黙っている）。
		if hits_checked > 0:
			print("    ⚠ 面ぜんぶが押せる器 = %d 枚（⚠ 上に押下を食べる器があれば赤が出る）" % hits_checked)
		instance.queue_free()
		await get_tree().process_frame


# 測る器。⚠ 増やすときはここに1行足す（関数の中に決め打ちしない）。
const LAYOUT_PATHS: Array[String] = [
	".",
	"Layout",
	"Layout/BottomArea",
	"Layout/BottomArea/BottomLayout",
	"Layout/BottomArea/BottomLayout/ResourceRow",
	# ⚠ `MaterialsScroll` / `MaterialsDisplay` は消した（2026-09-10）。
	#   ⚠ 素材16件は右上の `ResourceBar` へ移り、⚠ 拠点の下段から無くなったため。
	"Layout/BottomArea/BottomLayout/NavigationButtons",
]

const LAYOUT_ROWS: Array[String] = [
	"Layout/BottomArea/BottomLayout/ResourceRow",
	"Layout/BottomArea/BottomLayout/NavigationButtons",
]

# 手書きした .tscn が本当に開くかも、ついでにここで見る。
# ⚠ 画面のスクリプトは他のシナリオから読み込まれないため、
#   ⚠ ノードパスの取り違えは人間が開くまで分からない。⚠ それを1本前に倒す。
# 実機の画面サイズ（project.godot の window/size）。
# ⚠ ヘッドレスの viewport（1280 x 1280）は高さが違う。縦のはみ出しを見るときは
#   こちらを基準にすること。
const SCREEN_SIZE: Vector2 = Vector2(1280, 720)


# 画面の中で一番外側の Container を返す。⚠ 無ければ null。
#
# ⚠ 画面のルートは素の Control（アンカー配置）で、最小サイズを子から計算しない。
#   はみ出しを測れるのは Container から下だけ。
func _outermost_container(node: Node) -> Control:
	for child: Node in node.get_children():
		if child is Container:
			return child as Container
	for child: Node in node.get_children():
		var found: Control = _outermost_container(child)
		if found != null:
			return found
	return null


# 測る前に出し入れするノード（画面ごと）。⚠ 排他で切り替わる器を測るための表。
#
# ⚠ 画面ごとに if を書かないこと。⚠ 新しく排他の器が増えたらここに1行足す。
# ⚠ 育成画面は「一覧」と「詳細」が排他で、⚠ 縦に長いのは詳細のほう。
# 測る器を名指しする画面（⚠ 一番外側の Container では当たらないもの）。
#
# ⚠ 戦闘は `Node2D` の下に `UnitView`（その子に `StatusChips` という Container）が
#   ぶら下がるので、⚠ 自動で探すと空の帯を掴んで `0 x 0` になる。
# ⚠ 増えたらここに1行足す。⚠ 画面ごとに if を書かないこと。
const LAYOUT_SCENE_BOX: Dictionary = {
	SCENE_BATTLE: "HUD/Root/Layout",
}

const LAYOUT_SCENE_SHOW: Dictionary = {
	# ⚠ 育成の「一覧／詳細」の行は 2026-09-27 に消した（⚠ 一覧が無くなった。⚠ タブは `#タブ` で開き分ける）。
	# ⚠ ギルドは 2026-09-11 に `_layout_prepare_for()` へ移した（⚠ カードは解放の有無で
	#   ⚠ 中身ごと変わるため、⚠ `visible` を立てるだけでは中身が空き枠のままになる）。
}


# ⚠⚠ 測る前に「戻さない条件」を作る（宿題73・2026-09-06）。
#
# ⚠⚠ 歩くのを測定ループの前に置かないこと。⚠ 置くと現在地が最上層になり、
#   ⚠ `dungeon_map` の「⚠ 現在地を真ん中に寄せる」（段階20-c）の検証が
#   ⚠ 「スクロールが先頭のまま」で赤を出す（⚠ 2026-09-06に実測。⚠ 入口が一番下だから）。
# ⚠ ＝⚠ 3枚の直前で初めて歩く。⚠ `dungeon_map` はそれより前に並べておくこと。
# ⚠ 行の中の Label を左から順につないだもの（⚠ 設計役は絵を見られないので文で取る）。
func _row_text(row: PanelContainer) -> String:
	var parts: Array[String] = []
	# ⚠ 絵も文で出す（⚠ 絵は取れないが「どのファイルが入ったか」は取れる）。
	for rect: Node in row.find_children("*", "TextureRect", true, false):
		var texture: Texture2D = (rect as TextureRect).texture
		if texture != null:
			parts.append("[%s]" % texture.resource_path.get_file().get_basename())
	for label: Node in row.find_children("*", "Label", true, false):
		var text: String = (label as Label).text
		if text != "":
			parts.append(text)
	return " ／ ".join(parts)


func _layout_prepare_for(scene_path: String) -> void:
	# ⚠⚠ 割り振りは「1段も振っていない姿」だと点が全部暗く、⚠ 合計も緑の数字も出ない
	#   （2026-09-12）。⚠ **横に一番長いのは値が入った姿**なので、⚠ 先に少し振ってから測る
	#   （⚠ ギルドと同じ考え方：⚠ `visible` をいじらず**状態のほうを作る**）。
	if scene_path == "res://scenes/guild/training_screen.tscn#" + TransferKeys.TRAINING_TAB_NODES:
		_layout_fill_stat_nodes(str(GameManager.get_party_members()[0]))
		return
	# ⚠ 育成の装備タブは装飾の下ごしらえを呼ばない（⚠ 下ごしらえは持ち物（`warehouse_screen`）で1回だけ。
	#   ⚠ 2回呼ぶと「刺せなかった」の黄が1本増える＝2026-09-27 に踏んだ）。
	# ⚠ ただし装備の段階解放は開ける（⚠ 閉じているとタブごと出ない＝本番の決まり。⚠ 本番の口 `unlock_screen()`）。
	if scene_path == "res://scenes/guild/training_screen.tscn#" + TransferKeys.TRAINING_TAB_EQUIP:
		GameManager.unlock_screen(GameStateKeys.SCREEN_EQUIPMENT)
		return
	# ⚠⚠ 装飾の枠（2026-09-22・回3 → ⚠ 09-27 から持ち物の右の紙）。⚠ 何も着けていない姿だと枠が1つも出ず、
	#   ⚠ 「マス＋吹き出し」の側が**一度も通らない**。
	#   ⚠ 枠は等級3から開く（GAME_DESIGN.md 6-4）ので、⚠ 着けて・鍛えて・刺すところまで作る。
	if scene_path == "res://scenes/guild/warehouse_screen.tscn":
		_layout_fill_equipment_parts(str(GameManager.get_party_members()[0]))
		return
	if scene_path not in [
		"res://scenes/adventure/run_loot_window.tscn",
		"res://scenes/adventure/run_relic_select.tscn",
		"res://scenes/adventure/dungeon_shop.tscn",
	]:
		return
	if GameManager.get_dungeon_shop_entries().is_empty():
		_layout_walk_dungeon_to_boss()


# ⚠ 割り振りに段を入れておく（2026-09-12）。⚠ ポイントは **レベル-1** なので、
#   ⚠ 先にレベルを上げる。⚠ 上げるには素材が要るので配る（⚠ 測るだけ・保存はしない）。
# ⚠ 押す順は段の小さい順。⚠ 前提が1本道なので、⚠ 「押せたら次」を繰り返せば埋まる。
# 装飾を刺した装備を1つ作って着せる（2026-09-22・回3）。
#
# ⚠ 個体を作るのは `add_to_inventory()` の1本（CLAUDE.md 8番）。⚠ 直に inventory を書かない。
# ⚠ 装飾の枠は**段階解放**でも閉じる（`is_part_kind_unlocked()`）ので、⚠ 画面も開けておく。
# ⚠ 判定は全部 GameManager の口に聞く。⚠ 失敗したら黄で言う（⚠ 黙って枠が出ないのが一番困る）。
func _layout_fill_equipment_parts(character_id: String) -> void:
	GameManager.unlock_screen(GameStateKeys.SCREEN_DECORATION)
	var instance_id: String = _find_instance_of(LAYOUT_PART_WEAPON_ID)
	if instance_id == "":
		GameManager.add_to_inventory(LAYOUT_PART_WEAPON_ID, 1)
		instance_id = _find_instance_of(LAYOUT_PART_WEAPON_ID)
	if instance_id == "":
		push_warning("[DebugBoot] ⚠ %s の個体が作れなかった" % LAYOUT_PART_WEAPON_ID)
		return
	for material_id: Variant in MasterDataLoader.get_all_items():
		GameManager.add_material(str(material_id), 99999)
	# ⚠ 枠が開くまで鍛える（⚠ 等級3から・GAME_DESIGN.md 6-4）。
	for _i: int in range(3):
		var _forged: bool = GameManager.forge_equipment(instance_id)
	var _equipped: bool = GameManager.equip_instance(
		character_id, GameStateKeys.EQUIP_WEAPON, instance_id
	)
	var part_slots: Array = GameManager.get_part_entries(instance_id)
	if part_slots.is_empty():
		push_warning("[DebugBoot] ⚠ 枠が1つも開かなかった（⚠ 鍛えられていない）")
		return
	# ⚠ 1つだけ刺す（⚠ 「空き」と「刺さっている」を両方測りたい）。
	if not GameManager.attach_part(
		instance_id,
		int((part_slots[0] as Dictionary).get(GameManager.PART_VIEW_INDEX, 0)),
		LAYOUT_PART_ITEM_ID
	):
		push_warning("[DebugBoot] ⚠ %s を刺せなかった" % LAYOUT_PART_ITEM_ID)


func _layout_fill_stat_nodes(character_id: String) -> void:
	if not GameManager.get_stat_nodes(character_id).is_empty():
		return
	if Balance.character != null:
		GameManager.add_material(str(Balance.character.level_up_material_id), 999)
	for _i: int in range(8):
		if not GameManager.level_up_character(character_id):
			break

	var ids: Array = MasterDataLoader.get_all_character_nodes().keys()
	ids.sort()
	# ⚠ 6段ぶん。⚠ 全部埋めない（⚠ 「済」の行と「まだの行」を両方測りたい）。
	# ⚠ 先に `can_unlock_stat_node()` で絞る。⚠ いきなり `unlock_stat_node()` を
	#   ⚠ 全IDに当てると、⚠ 他のキャラのノードで false のログが 1000 行出る（⚠ 実測）。
	for _step: int in range(6):
		for raw_id: Variant in ids:
			var node_id: String = str(raw_id)
			if not GameManager.can_unlock_stat_node(character_id, node_id):
				continue
			if GameManager.unlock_stat_node(character_id, node_id):
				break


# ⚠⚠ ボスのマスまで歩いて倒す（宿題73 の「戻さない条件」を作る道具）。
#
# ⚠⚠ `clear_dungeon_boss()` は「ボスのマスに立っている」ことが条件
#   （⚠ 2026-09-06に実測。⚠ 入口で叩くと `ボスノードに居ない: d_1_0` で false）。
# ⚠ 戦闘のマスは倒してから進む（⚠ 倒さないと先へ進めない＝不1 の修正後の仕様）。
# ⚠⚠ ボスの戦利品（拾い待ち）は片付けない。⚠ 宝箱の画面を出す条件そのものだから。
func _layout_walk_dungeon_to_boss() -> void:
	var steps: int = 0
	while steps <= 60:
		var here: String = str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
		)
		var kind: String = str(
			GameManager.get_dungeon_node(here).get(GameStateKeys.DUNGEON_NODE_KIND, "")
		)
		if kind == GameStateKeys.DUNGEON_NODE_KIND_BATTLE:
			var _won: bool = GameManager.clear_dungeon_battle()
		if kind == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
			break
		# ⚠ 道中の拾い待ちは片付ける（⚠ 残すと歩けなくなる／次の画面に混ざる）。
		var _left: Dictionary = GameManager.clear_dungeon_pending_loot()
		var moves: Array = GameManager.get_dungeon_moves()
		if moves.is_empty():
			break
		if not GameManager.move_in_dungeon(str(moves[0])):
			break
		steps += 1
	var _cleared: bool = GameManager.clear_dungeon_boss()


# 測るときに渡す転送データ（⚠ 画面ごとに違う。⚠ 画面ごとの if を測定ループに書かない）。
#
# ⚠ 装備画面は character_id を渡さないと黄を1本出す（正常な保険）。⚠ 全画面に渡しておく。
# ⚠ レリックの画面は node_id が無いとマップへ戻す（宿題73）。⚠ relic のマスを1つ探して渡す。
func _layout_transfer_for(scene_path: String) -> Dictionary:
	var data: Dictionary = {
		TransferKeys.CHARACTER_ID: str(GameManager.get_party_members()[0]),
	}
	# ⚠⚠ 戦闘（2026-09-16）。⚠ HUD をコンテナ化したので**ここから測れるようになった**
	#   （⚠ それまでは Node2D ＋ 絶対座標で `0 x 0` しか返らなかった）。
	#   ⚠ 測れるのは HUD の3段だけ。⚠ 戦場のユニットは Node2D のまま
	#     （⚠ 戦闘中に x が動くので器に並べられない）。
	#   ⚠ stage_id を渡さないと黄が1本出る。⚠ 測るためだけに黄を増やさない。
	# ⚠ この1回で `battle_last.jsonl` が新しく開き直される（⚠ 戦闘の記録は残らない）。
	if scene_path == SCENE_BATTLE:
		data[TransferKeys.STAGE_ID] = "floor_1"
		data[TransferKeys.STAGE_TYPE] = GameStateKeys.STAGE_TYPE_STORY
	# ⚠ レリック選択は1枚（2026-09-19）。⚠ 測るのは難ダンジョンの側（⚠ マスの形は同じ）。
	if scene_path == "res://scenes/adventure/run_relic_select.tscn":
		data[TransferKeys.RUN_KIND] = GameManager.RUN_KIND_DUNGEON
		data[TransferKeys.RUN_NODE_ID] = _find_dungeon_node_of_kind(
			GameStateKeys.FLOOR_NODE_KIND_RELIC
		)
	# ⚠ 育成・持ち物のタブ（2026-09-27）。⚠ `#` の後ろがタブの字。
	if scene_path.contains("#"):
		var tab_key: String = TransferKeys.WAREHOUSE_TAB if scene_path.contains("warehouse_screen") else TransferKeys.TRAINING_TAB
		data[tab_key] = scene_path.get_slice("#", 1)
	# ⚠ 持ち物（装備のタブ）は、⚠ 下ごしらえで装飾を刺した武器を選んでおく（⚠ 右の紙に枠が出る）。
	if scene_path == "res://scenes/guild/warehouse_screen.tscn":
		data[TransferKeys.WAREHOUSE_INSTANCE_ID] = GameManager.get_equipped_instance_id(
			str(GameManager.get_party_members()[0]), GameStateKeys.EQUIP_WEAPON
		)
	return data


# ⚠ 読み込むパス（⚠ `#タブ` を外す・2026-09-27）。
func _layout_load_path(scene_path: String) -> String:
	return scene_path.get_slice("#", 0)


# いまのランの中から、種で1つ探す（⚠ ノードを組み直さない＝口を2本にしない）。
func _find_dungeon_node_of_kind(kind: String) -> String:
	var run: Dictionary = GameManager.get_dungeon_run()
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	var ids: Array = nodes.keys()
	ids.sort()
	for entry: Variant in ids:
		var node_id: String = str(entry)
		if str((nodes.get(node_id, {}) as Dictionary).get(GameStateKeys.FLOOR_NODE_KIND, "")) == kind:
			return node_id
	return ""


# ⚠ リソースが増えたときの演出（2026-09-09）。⚠ 絵は取れないが、
#   ⚠ 「⚠ 何個飛ばしたか」「⚠ 着地先を見つけたか」「⚠ 数字が回ったか」は取れる。
#   ⚠ 拠点を開くのは、⚠ そこにしか金・スタミナの `ResourceDisplay` が無いため。
func _report_gain() -> void:
	print("[DebugBoot] --- 増える量 → 飛ぶ個数（⚠ モックの表と合っているか）---")
	var effect: ResourceGainEffect = ResourceGainEffect.spawn_into(get_tree().root)
	# ⚠ `spawn_into()` は `add_child` を遅らせるので、⚠ 面ができるまで待つ。
	await get_tree().process_frame
	await get_tree().process_frame
	print("  出せる状態か = %s（⚠ true が正解）" % [ResourceGainEffect.is_ready()])
	if not ResourceGainEffect.is_ready():
		push_error("[DebugBoot] 演出の面ができていない")
		return
	# ⚠ 1種だけのとき ／ ⚠ 3種以上が同時のとき（⚠ 絞りが効くか）。
	for amount: int in [1, 5, 9, 10, 40, 99, 100, 300, 999, 1000, 2400]:
		print("  +%-5d -> 1種のとき %d 個 ／ 3種同時なら %d 個" % [
			amount, effect._count_for(amount, 1), effect._count_for(amount, 3),
		])

	print("[DebugBoot] --- 拠点で実際に流す ---")
	var base: Node = load("res://scenes/base/base_screen.tscn").instantiate()
	get_tree().root.add_child(base)
	await get_tree().process_frame
	await get_tree().process_frame

	var displays: Array[Node] = get_tree().get_nodes_in_group(ResourceGainEffect.GROUP_DISPLAY)
	print("  グループに入っている表示欄 = %d 個（⚠ 0 なら着地先が1つも見つからない）" % displays.size())
	if displays.is_empty():
		push_error("[DebugBoot] ResourceDisplay がグループに1つも入っていない")

	var gold_display: Variant = null
	for node: Node in displays:
		if node is ResourceDisplay and (node as ResourceDisplay).resource_id == GameStateKeys.GOLD:
			gold_display = node
			break
	print("  金の表示欄が見つかったか = %s（⚠ true が正解）" % [gold_display != null])
	if gold_display == null:
		push_error("[DebugBoot] 金の ResourceDisplay を resource_id から引けない")
		base.queue_free()
		return

	var display: ResourceDisplay = gold_display
	var before: int = display.value
	# ⚠ 本番と同じ順（⚠ 画面が先に値を更新し、⚠ そのあと演出が回す）。
	display.set_value(before + 120)
	display.play_gain(24, 0.21)
	await get_tree().process_frame
	print("  値 %d -> %d ／ 回している最中の表示 = %s（⚠ 本当の値より小さいのが正解）" % [
		before, display.value, display._display_override,
	])
	if display._display_override < 0 or display._display_override >= display.value:
		push_error("[DebugBoot] 数字が回っていない（見せかけの数が入っていない）")

	# ⚠⚠ **本物の増加を通す**（2026-09-09・人間の指示「リソースの移動に紐づけてほしい」）。
	#   ⚠ 演出を直接呼ばない。⚠ `GameManager` を動かして、⚠ それだけで出るかを見る。
	#   ⚠ 同じフレームに3種増やす（⚠ 宝箱と同じ形）。⚠ まとめて1回になるのが正解。
	GameManager.add_gold(120)
	GameManager.add_gems(3)
	GameManager.add_material("construction_material_1", 4)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("  ⚠ 資源を増やしただけで出たか：演出の面に載っているもの = %d 個（⚠ 0 なら紐づいていない）"
		% effect.field.get_child_count())
	if effect.field.get_child_count() <= 0:
		push_error("[DebugBoot] 資源が増えても演出が出ない（resource_changed に紐づいていない）")

	# ⚠ 出どころの数字は**種類ぶん**出る（2026-09-10・人間の指示
	#   「⚠ 複数素材を手に入れたら、⚠ 発射もとにも複数書いて」）。
	#   ⚠ 3種増やしたので、⚠ 縦に積まれた数字が3つ在るのが正解。
	#   ⚠ 種類ごとに時間をずらすので、⚠ 出そろうまで待つ。
	# ⚠⚠ ヘッドレスは1フレームの長さが実機と違い、⚠ 数える瞬間には消えているものがある。
	#   ⚠ 「その時点の数」ではなく **見えた最大の数** を追う。
	# ⚠ 重なっているかはここでは分からない（⚠ 数字は上へ流れるので y が毎フレーム変わる）。
	#   ⚠ 取れるのは「⚠ 何個同時に出たか」まで。⚠ 読めるかどうかは人間が実機で見る。
	var float_max: int = 0
	for _i: int in range(240):
		await get_tree().process_frame
		var now: int = 0
		for child: Node in effect.field.get_children():
			if child is HBoxContainer:
				now += 1
		float_max = maxi(float_max, now)
	print("  ⚠ 出どころの数字 = 同時に最大 %d 個（⚠ 3種増やしたので 3 個が正解）" % float_max)

	# ⚠ 資源ごとに色が変わるか（2026-09-10・人間の指示「⚠ 色も変えて。⚠ 全部緑色」）。
	#   ⚠ 絵は取れないが、⚠ 引いた色そのものは取れる。⚠ 全部同じ値なら効いていない。
	var colors: Dictionary = {}
	# ⚠ IDを直書きしない（AGENTS.md）。⚠ 実際に "decoration_material_1" と書いて
	#   ⚠ 逃げ道の色になり、⚠ 正しくは `decor_material_` だと分かった（2026-09-10）。
	for resource_id: String in [
		GameStateKeys.GOLD, GameStateKeys.GEMS, GameStateKeys.STAMINA,
		GameStateKeys.ITEM_CONSTRUCTION_MATERIAL_PREFIX + "1",
		GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX + "1",
		GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX + "1",
		GameStateKeys.ITEM_DECOR_MATERIAL_PREFIX + "1",
	]:
		var color: Color = effect._color_of(resource_id)
		colors[color.to_html(false)] = true
		print("    %-26s -> #%s" % [resource_id, color.to_html(false)])
	print("  ⚠ 色の種類 = %d（⚠ 1 なら全部同じ色＝効いていない）" % colors.size())
	if colors.size() <= 1:
		push_error("[DebugBoot] 資源ごとに色が変わっていない（全部同じ）")
	if float_max < 3:
		push_error("[DebugBoot] 出どころの数字が種類ぶん出ていない（最大 %d 個）" % float_max)

	# ⚠ 減ったときは流さない（⚠ 増えたときだけ）。
	var before_count: int = effect.field.get_child_count()
	GameManager.add_gold(-50)
	await get_tree().process_frame
	await get_tree().process_frame
	print("  ⚠ 減らしたとき：%d 個 -> %d 個（⚠ 増えていないのが正解）" % [
		before_count, effect.field.get_child_count(),
	])
	if effect.field.get_child_count() > before_count:
		push_error("[DebugBoot] 減ったのに演出が出た")

	base.queue_free()
	await get_tree().process_frame


const LAYOUT_SCENES: Array[String] = [
	"res://scenes/adventure/party_preset_screen.tscn",
	"res://scenes/adventure/adventure_select.tscn",
	# ⚠ 段階14-c で足したマップ画面。層の行はコードで作るので開かないと分からない。
	#   ⚠ フロアに入っていないと _ready() が冒険選択へ戻すので、先に start_floor() する
	#     （_report_layout の中で入れてある）。
	"res://scenes/adventure/floor_map.tscn",
	# ⚠ 段階17-d の難ダンジョンのマップ。⚠ 層・3人のHP・鞄のマス目を全部コードで作る。
	#   ⚠ ランに入っていないと _ready() が冒険選択へ戻す（_report_layout の中で入れてある）。
	"res://scenes/adventure/dungeon_map.tscn",
	# ⚠⚠ 段階17-e-3 の2枚 ＋ 宝箱（宿題72・73）。⚠ 2026-09-06 に入れられるようになった。
	#   ⚠ どれも _ready() で条件を満たさないと SceneManager.change_scene() でマップへ戻し、
	#     ⚠ 測定が終わらなくなる（2026-09-04 に実測。⚠ 8分で止めた）。
	#   ⚠ 上の準備で「戻さない条件」を作ってある（⚠ ボスを倒す ／ node_id を渡す）。
	#   ⚠⚠ 条件を外したら、⚠ ここの3行も一緒に外すこと（⚠ 外すと測定が止まる）。
	"res://scenes/adventure/run_loot_window.tscn",
	# ⚠ レリック選択（2026-09-19 にシナリオと1枚にした）。⚠ 準備は難ダンジョンの側で作る。
	"res://scenes/adventure/run_relic_select.tscn",
	"res://scenes/adventure/dungeon_shop.tscn",
	# ⚠⚠ 戦闘（2026-09-16）。⚠ 27画面で唯一「一度も測れていない」画面だった。
	#   ⚠ HUD をヘッダー／戦場／下部パネルの3段の器にしたので測れる。
	#   ⚠ 出る数字は **HUD だけ**。⚠ 戦場は Node2D なので入らない。
	SCENE_BATTLE,
	# ⚠ UI テストのページ（2026-09-06）。⚠ 中身は全部コードで積むので、開かないと分からない。
	#   ⚠ リリース前に消すときは、⚠ この行も一緒に消す。
	"res://tests/ui_test_page.tscn",
	# ⚠ 段階14-e のフロア内ショップ。⚠ 開くだけで無料ガチャが1回引かれる
	#   （測るために開くので、状態に宝箱が1個積まれる。⚠ 保存はしない）。
	"res://scenes/adventure/floor_shop.tscn",
	# ⚠ この2枚は、コードでノードを足しているので開かないと分からない
	#   （@onready のパス取り違え・move_child の相手違い）。
	"res://scenes/guild/training_screen.tscn",
	# ⚠ 装備画面（仮の鍛冶場）は 2026-09-27 に消した（⚠ 持ち物の右の紙へ移った・人間「⚠ 3あ」）。
	# ⚠⚠ 育成のタブ（2026-09-27・回UI-組 育成・人間「⚠ 1い」）。⚠ 前のステータスノード・スキルの画面は消えて、
	#   ⚠ 育成の中のタブになった。⚠ **`#タブ` を後ろに付けると、そのタブで開く**（⚠ `_layout_transfer_for()`）。
	#   ⚠ 読み込むのは `#` の前だけ（⚠ `_layout_load_path()`）。
	"res://scenes/guild/training_screen.tscn#" + TransferKeys.TRAINING_TAB_NODES,
	"res://scenes/guild/training_screen.tscn#" + TransferKeys.TRAINING_TAB_SKILLS,
	"res://scenes/guild/training_screen.tscn#" + TransferKeys.TRAINING_TAB_EQUIP,
	# ⚠ 昇級申請書（2026-09-27・人間「⚠ 3あ」）。
	"res://scenes/guild/level_up_screen.tscn",
	# ⚠ 段階10でノードが5件から18件に増え、カテゴリの見出しも足した。今まで測っていない。
	#   ⚠ ノード行は ScrollContainer の中なので、縦のはみ出しはここでは捕まらない
	#     （測れるのは横だけ。縦は人間が実機で見る＝EXEC_GUILD_RESEARCH_V2.md §7-3 の S-10）。
	"res://scenes/guild/research_screen.tscn",
	# ⚠ 段階11で復活した。ギルドのボタンが5個から6個に増えた回でもある
	#   （⚠ ギルドは VBoxContainer なので、はみ出すなら横ではなく縦）。
	"res://scenes/guild/workshop_screen.tscn",
	# ⚠ 2026-08-31・仮アセットのアイコンを足した回で追加。行の頭に 40px の器が1つ増える。
	#   ⚠ 倉庫は行を GridContainer にコードで積む。持ち物が多いほど横に伸びる
	#     （測るのは開いた直後の姿だけ。中身の件数は F4 を押した状態と違う）。
	"res://scenes/guild/warehouse_screen.tscn",
	# ⚠ 持ち物のほかのタブ（2026-09-27・回UI-組 持ち物）。⚠ `#タブ` で開き分ける（⚠ 育成と同じ）。
	"res://scenes/guild/warehouse_screen.tscn#" + TransferKeys.WAREHOUSE_TAB_PART,
	"res://scenes/guild/warehouse_screen.tscn#" + TransferKeys.WAREHOUSE_TAB_MATERIAL,
	# ⚠ 記録（2026-09-28・回UI-仕組み②）。⚠ 図鑑は持ち物のタブからここへ移した。
	"res://scenes/guild/records_screen.tscn",
	# ⚠ 同上。ショップは13枠を HBoxContainer の行で積む。1行に器が4つ並ぶ。
	"res://scenes/guild/shop_screen.tscn",
	# ⚠⚠ ポモドーロの器と4ビュー（2026-09-09）。⚠ **今まで1枚も測っていなかった**。
	#   ⚠ 4ビューが絶対座標（anchor ＋ offset の直書き）で組まれていて、
	#   ⚠ コンテナが1つも無かったため `get_combined_minimum_size()` が 0 を返していた。
	#   ⚠ コンテナへ組み替えたので、⚠ ここから縦の詰まりが測れる。
	# ⚠ 器（pomodoro.tscn）は「上部バー ＋ そのとき出ているビュー」を測る。
	#   ⚠ どのビューが出るかは加護を選んだかで変わるので、⚠ ビュー単体も並べて測る。
	"res://scenes/pomodoro/pomodoro.tscn",
	"res://scenes/pomodoro/protection_select_view.tscn",
	"res://scenes/pomodoro/focus_view.tscn",
	"res://scenes/pomodoro/break_view.tscn",
	"res://scenes/pomodoro/reflection_view.tscn",
	# ⚠⚠ 「まだ一度も測っていない3枚」のうち2枚（2026-09-12・宿題13）。
	#   ⚠ 拠点は下段（`LAYOUT_PATHS`）だけ測っていて、⚠ **画面全体は測っていなかった**。
	#   ⚠ タイトルは1枚も測っていなかった。
	# ⚠⚠ **戦闘（`battle.tscn`）は足さない。⚠ measure しても `0 x 0` にしかならない**
	#   ⚠ （2026-09-12 に1回入れて実測）。⚠ 中身が `Node2D` と `CanvasLayer` で、
	#   ⚠ `get_combined_minimum_size()` を持つ Container が1つも無いため
	#   ⚠ （⚠ `ui_test_page.tscn` が 0 x 0 なのと同じ理由）。
	#   ⚠⚠ 測りたければ**先に HUD をコンテナへ組み替える**こと（⚠ ポモドーロと同じ道）。
	#   ⚠ 開くと敵とタイマーが動き出すぶん、⚠ 入れておく損のほうが大きい。
	"res://scenes/base/base_screen.tscn",
	"res://scenes/title/title_screen.tscn",
]


# いま編成に入っていないキャラを1人。
func _character_outside_party() -> String:
	var members: Array = GameManager.get_party_members()
	for character_id: Variant in GameManager.get_party_candidates():
		if not (str(character_id) in members):
			return str(character_id)
	return ""


# その個体の持ち主。誰も装備していなければ "(なし)"。
func _owner_of(instance_id: String) -> String:
	for entry: Variant in GameManager.get_owned_instances():
		if str((entry as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) != instance_id:
			continue
		var owner: String = str((entry as Dictionary).get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
		return owner if owner != "" else "(なし)"
	return "(個体が無い)"


# ============================================================
# 撃つ役。画面遷移で消えないよう root に付く。
# ⚠ 本番のノードを1つも作らない。見るだけ・呼ぶだけ。
# ============================================================
# ============================================================
# 難ダンジョンを自動で潜って数字を取る（2026-10-03・回6・人間「⚠ １　あ」＝⚠ 設計役が数字を出してから決める）。
#
# ⚠ 戦闘は本物の戦闘画面（⚠ 勝ち負けは画面が GameManager に書く＝`_finish_dungeon_battle()`）。⚠ スキルは撃てたら撃つ。
# ⚠ 道：HP が減っていれば休憩・ほかはランダム ／ ⚠ 宝箱は開ける ／ ⚠ レリックは1枚目 ／ ⚠ 拾いものは入るだけ ／
#   ⚠ ボスの後：商人で蘇生1・回復を3本まで → 潜る ／ ⚠ 戦闘のあと：脱落なら蘇生・素の 50% を切ったら回復。
# ⚠ 引数：`runs=`（既定 10）・`level=`（3人の Lv・既定 1＝新しいセーブのまま）・`floors=`（ここまで潜ったら持ち帰る・既定 10）・`speed=`（既定 8）。
# ⚠ 状態は書き換えるが保存しない（⚠ debug_boot の約束）。
# ============================================================
class DungeonSimRunner extends Node:
	const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
	const POTION_HEAL: String = "dungeon_potion_heal"
	const POTION_REVIVE: String = "dungeon_potion_revive"
	const GIVE_UP_GAME_SEC: float = 240.0
	const REST_BELOW_PCT: float = 0.6
	const HEAL_BELOW_PCT: float = 0.5
	const HEAL_STOCK: int = 3

	var runs: int = 10
	var floors_cap: int = 10
	var speed: float = 8.0
	var _results: Array = []
	# 1回ぶんの数字。
	var _r: Dictionary = {}

	func _ready() -> void:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("runs="):
				runs = maxi(1, int(arg.substr(5)))
			elif arg.begins_with("floors="):
				floors_cap = maxi(1, int(arg.substr(7)))
			elif arg.begins_with("speed="):
				speed = maxf(1.0, float(arg.substr(6)))
		ResourceGainEffect.set_muted(true)
		SoundManager.set("_config", null)
		Engine.time_scale = speed
		for i: int in range(runs):
			await _one_run(i)
		_summary()
		Engine.time_scale = 1.0
		get_tree().quit()

	func _one_run(index: int) -> void:
		var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
		if GameManager.is_in_dungeon():
			GameManager.abandon_dungeon_run()
		seed(1000 + index)
		_r = {"run": index + 1, "end": "", "floors": 0, "layer": 1, "battles": 0, "battle_sec": 0.0, "hp_lost": 0,
			"coin_got": 0, "coin_spent": 0, "coin_left": 0, "heal_bought": 0, "revive_bought": 0, "heal_used": 0, "revive_used": 0,
			"rests": 0, "relics": 0, "bag_max": 0, "picked": 0, "equips": 0, "stalemate": 0}
		if not GameManager.start_dungeon_run(dungeon_id):
			push_error("[DungeonSim] 入れなかった")
			return
		var guard: int = 0
		while GameManager.is_in_dungeon() and guard < 2000:
			guard += 1
			_r["layer"] = maxi(int(_r["layer"]), GameManager.get_dungeon_current_layer())
			if GameManager.can_retreat_from_dungeon():
				_r["floors"] = GameManager.get_dungeon_floor_index()
				if GameManager.get_dungeon_floor_index() >= floors_cap or not GameManager.can_descend_dungeon_floor():
					_r["coin_left"] = GameManager.get_dungeon_currency()
					var _back: Dictionary = GameManager.retreat_from_dungeon()
					_r["end"] = "持ち帰り"
					break
				_shop()
				GameManager.descend_dungeon_floor()
				continue
			var moves: Array = GameManager.get_dungeon_moves()
			if moves.is_empty():
				_r["end"] = "行き止まり"
				break
			var next: String = _choose(moves)
			var coin_before: int = GameManager.get_dungeon_currency()
			if not GameManager.move_in_dungeon(next):
				_r["end"] = "進めない"
				break
			var kind: String = str(GameManager.get_dungeon_node(next).get(GameStateKeys.DUNGEON_NODE_KIND, ""))
			if kind == GameStateKeys.DUNGEON_NODE_KIND_BATTLE or kind == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
				await _battle(next)
				if not GameManager.is_in_dungeon():
					_r["end"] = "倒れた"
					break
			elif kind == GameStateKeys.DUNGEON_NODE_KIND_CHEST:
				var _opened: Dictionary = GameManager.open_dungeon_chest(next)
			elif kind == GameStateKeys.DUNGEON_NODE_KIND_RELIC:
				_take_relic(next)
			elif kind == GameStateKeys.DUNGEON_NODE_KIND_REST:
				_r["rests"] = int(_r["rests"]) + 1
			if GameManager.has_pending_dungeon_corridor_chest():
				var _corridor: Dictionary = GameManager.open_dungeon_corridor_chest()
			_pick_up()
			_use_potions()
			_r["coin_got"] = int(_r["coin_got"]) + maxi(0, GameManager.get_dungeon_currency() - coin_before)
		if _r["end"] == "":
			_r["end"] = "上限"
		_results.append(_r.duplicate(true))
		print("[DungeonSim] %d回目: %s ／ %d層まで・%dフロア突破 ／ 戦闘 %d（平均 %.0f 秒）・削られた HP %d ／ コイン 得 %d 使 %d 残 %d ／ 回復 買%d 使%d・蘇生 買%d 使%d ／ 休憩 %d・レリック %d ／ 鞄 最大 %d・拾った %d（装備 %d）・決着せず %d" % [
			int(_r["run"]), str(_r["end"]), int(_r["layer"]), int(_r["floors"]), int(_r["battles"]),
			float(_r["battle_sec"]) / maxf(1.0, float(_r["battles"])), int(_r["hp_lost"]),
			int(_r["coin_got"]), int(_r["coin_spent"]), int(_r["coin_left"]),
			int(_r["heal_bought"]), int(_r["heal_used"]), int(_r["revive_bought"]), int(_r["revive_used"]),
			int(_r["rests"]), int(_r["relics"]), int(_r["bag_max"]), int(_r["picked"]), int(_r["equips"]), int(_r["stalemate"]),
		])

	# HP が減っていて休憩が選べれば休憩・ほかはランダム。
	func _choose(moves: Array) -> String:
		if _lowest_ratio() < REST_BELOW_PCT:
			for raw: Variant in moves:
				if str(GameManager.get_dungeon_node(str(raw)).get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_REST:
					return str(raw)
		return str(moves[randi() % moves.size()])

	func _lowest_ratio() -> float:
		var lowest: float = 1.0
		for member: Variant in GameManager.get_party_members():
			var id: String = str(member)
			var base: int = maxi(1, GameManager.get_dungeon_base_max_hp(id))
			lowest = minf(lowest, float(GameManager.get_dungeon_character_max_hp(id)) / float(base))
		return lowest

	func _party_hp() -> int:
		var total: int = 0
		for member: Variant in GameManager.get_party_members():
			total += GameManager.get_dungeon_character_max_hp(str(member))
		return total

	func _battle(node_id: String) -> void:
		var hp_before: int = _party_hp()
		SceneManager.change_scene_with_data(BATTLE_PATH, {
			TransferKeys.DUNGEON_NODE_ID: node_id,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
		})
		var battle: Node = null
		for _i: int in range(600):
			await get_tree().process_frame
			var scene: Node = get_tree().current_scene
			if scene != null and scene.scene_file_path == BATTLE_PATH and scene.has_method("get_session") and scene.call("get_session") != null:
				battle = scene
				break
		if battle == null:
			push_error("[DungeonSim] 戦闘画面が開かなかった")
			return
		var session: BattleSession = battle.call("get_session")
		while session.state != BattleSession.STATE_VICTORY and session.state != BattleSession.STATE_DEFEAT:
			if session.elapsed_sec > GIVE_UP_GAME_SEC:
				# ⚠ 決着しない（⚠ 削り合いが終わらない）＝倒れた扱いにはしない。⚠ 数えて全員を倒させる。
				_r["stalemate"] = int(_r["stalemate"]) + 1
				battle.call("debug_kill_all_enemies")
				for _w: int in range(30):
					await get_tree().process_frame
					if session.state == BattleSession.STATE_VICTORY or session.state == BattleSession.STATE_DEFEAT:
						break
				break
			for entry: Variant in battle.get("_skill_buttons"):
				var tile: Variant = (entry as Dictionary).get("button", null)
				var user: Variant = (entry as Dictionary).get("user", null)
				if tile is BaseButton and is_instance_valid(tile) and not (tile as BaseButton).disabled and user is BattleUnit and (user as BattleUnit).is_alive():
					battle.call("_on_skill_button_pressed", user, str((entry as Dictionary).get("skill_id", "")))
			await get_tree().process_frame
		for _i: int in range(5):
			await get_tree().process_frame
		_r["battles"] = int(_r["battles"]) + 1
		_r["battle_sec"] = float(_r["battle_sec"]) + session.elapsed_sec
		if GameManager.is_in_dungeon():
			_r["hp_lost"] = int(_r["hp_lost"]) + maxi(0, hp_before - _party_hp())

	func _take_relic(node_id: String) -> void:
		var choices: Array = GameManager.get_dungeon_relic_choices(node_id)
		if choices.is_empty():
			return
		var relic_id: String = str(choices[0])
		if GameManager.take_dungeon_relic(node_id, relic_id, "") or GameManager.take_dungeon_relic(node_id, relic_id, str(GameManager.get_party_members()[0])):
			_r["relics"] = int(_r["relics"]) + 1

	func _pick_up() -> void:
		var pending: Dictionary = GameManager.get_run_pending_loot(GameManager.RUN_KIND_DUNGEON)
		var taken: Dictionary = GameManager.take_all_run_pending_loot(GameManager.RUN_KIND_DUNGEON)
		for key: Variant in taken:
			_r["picked"] = int(_r["picked"]) + int(taken[key])
			if GameManager.run_bag_grade(str(key)) > 0:
				_r["equips"] = int(_r["equips"]) + int(taken[key])
		if not pending.is_empty():
			var _left: Dictionary = GameManager.clear_run_pending_loot(GameManager.RUN_KIND_DUNGEON)
		_r["bag_max"] = maxi(int(_r["bag_max"]), GameManager.get_dungeon_bag_used())

	func _bag_count(item_id: String) -> int:
		return int(GameManager.get_dungeon_bag().get(item_id, 0))

	func _use_potions() -> void:
		for member: Variant in GameManager.get_party_members():
			var id: String = str(member)
			if GameManager.is_dungeon_character_downed(id) and _bag_count(POTION_REVIVE) > 0:
				if GameManager.use_dungeon_item(POTION_REVIVE, id):
					_r["revive_used"] = int(_r["revive_used"]) + 1
			var base: int = maxi(1, GameManager.get_dungeon_base_max_hp(id))
			if not GameManager.is_dungeon_character_downed(id) and float(GameManager.get_dungeon_character_max_hp(id)) / float(base) < HEAL_BELOW_PCT and _bag_count(POTION_HEAL) > 0:
				if GameManager.use_dungeon_item(POTION_HEAL, id):
					_r["heal_used"] = int(_r["heal_used"]) + 1

	# 商人：⚠ 蘇生が無ければ1本・回復を HEAL_STOCK 本まで。
	func _shop() -> void:
		var entries: Array = GameManager.get_dungeon_shop_entries()
		for _round: int in range(HEAL_STOCK + 1):
			for i: int in range(entries.size()):
				var entry: Dictionary = entries[i]
				var item_id: String = str(entry.get("item_id", ""))
				var want: bool = (item_id == POTION_REVIVE and _bag_count(POTION_REVIVE) < 1) \
					or (item_id == POTION_HEAL and _bag_count(POTION_HEAL) < HEAL_STOCK)
				if not want:
					continue
				var before: int = GameManager.get_dungeon_currency()
				if GameManager.buy_dungeon_shop_entry(i):
					_r["coin_spent"] = int(_r["coin_spent"]) + maxi(0, before - GameManager.get_dungeon_currency())
					var counter: String = "revive_bought" if item_id == POTION_REVIVE else "heal_bought"
					_r[counter] = int(_r[counter]) + 1
		GameManager.mark_dungeon_shop_seen()

	func _summary() -> void:
		print("[DungeonSim] ===== まとめ（%d 回・3人 Lv %s・上限 %d フロア）=====" % [
			_results.size(), str(GameManager.get_character_growth(str(GameManager.get_party_members()[0])).get(GameStateKeys.GROWTH_LEVEL, 1)), floors_cap
		])
		var ends: Dictionary = {}
		var sums: Dictionary = {}
		var layers: Array[int] = []
		for raw: Variant in _results:
			var r: Dictionary = raw
			ends[str(r["end"])] = int(ends.get(str(r["end"]), 0)) + 1
			layers.append(int(r["layer"]))
			for key: String in ["floors", "battles", "battle_sec", "hp_lost", "coin_got", "coin_spent", "coin_left", "heal_bought", "heal_used", "revive_bought", "revive_used", "rests", "bag_max", "picked", "equips", "stalemate"]:
				sums[key] = float(sums.get(key, 0.0)) + float(r[key])
		layers.sort()
		var n: float = maxf(1.0, float(_results.size()))
		print("  終わり方 = %s" % str(ends))
		print("  届いた層 = 最小 %d ／ 中央 %d ／ 最大 %d ／ 全部 %s" % [layers[0], layers[layers.size() / 2], layers[layers.size() - 1], str(layers)])
		for key: Variant in sums:
			print("  平均 %-14s = %.1f" % [str(key), float(sums[key]) / n])


class Driver extends Node:

	# 撃つ間隔。⚠ これは「配置が整ったか」の合図ではなく、単なる間隔。
	#   同じ t に重なると「巻き込んだ数＝同じ t の damage の行数」が数えられなくなるため。
	const FIRE_GAP_SEC: float = 1.0
	# 決着してからログが出揃うまでの余裕。
	const SETTLE_SEC: float = 1.0
	# ⚠ 2回目以降の全滅までに置く間（ウェーブが複数あるステージ用）。
	#   次のウェーブの敵が自分に状態を掛け、互いを回復するのを見るための時間。
	const NEXT_WAVE_WATCH_SEC: float = 8.0
	# ⚠ 合図が来ないまま戦闘が長引いたら諦める（ヘッドレスがぶら下がったままにならないように）。
	const GIVE_UP_SEC: float = 180.0
	# 回復の検証で味方を削る量。⚠ BattleFormula を通るので def で割られる。
	const PREPARE_DAMAGE_POWER: int = 500
	# 味方を全滅させる量（段階6）。⚠ char_debug_mix は hp 9999。def で割られても
	#   確実に落ちる値にしてある。
	const PREPARE_KILL_POWER: int = 999999

	var battle_scene_path: String = ""
	var skill_plan: Array = []
	# 難ダンジョンの2連戦モード（段階17-b）。⚠ 既定は false（既存シナリオの挙動を1つも変えない）。
	var dungeon_mode: bool = false
	var dungeon_base_max_hp: Dictionary = {}
	# ⚠ 撃った直後の x を出すか（段階8。移動系ルーンのロックを見るため）。
	#   ⚠ 既定は false。既存シナリオの出力を1行も増やさない。
	var dump_each_fire: bool = false
	# ⚠ 決着のあとに結果窓の中身を出すか（2026-09-17・§0-UI-G）。⚠ 既定は false。
	#   ⚠ 本物の窓を出したあと、⚠ 見本の報酬（floor_5 のボス＝マス9件）で差し替えてもう1回出す
	#   （⚠ 検証用ステージは報酬を配らないので、⚠ 本物ではマスとピルが見られない）。
	var dump_result: bool = false
	var _result_dumped: int = 0
	# ⚠ 撃ち終わった瞬間に状態のチップの区分けを出すか（2026-09-17）。⚠ 既定は false。
	var dump_status_tones: bool = false
	var _status_tones_dumped: bool = false
	# ⚠ 浮かぶダメージ数値を1回だけ出すか（2026-09-18・モック §11）。⚠ 既定は false。
	#   ⚠ 絵は取れないので「何件・どの大きさ・待っている（透明）か」を数字で見る。
	var dump_pops: bool = false
	var _pops_dumped: bool = false
	# ⚠ スキルのマスのホバーの枠を1回だけ出すか（2026-09-18）。⚠ 既定は false。
	var dump_tooltip: bool = false
	var _tooltip_dumped: bool = false
	# ⚠ 敵の行動予告の SP を何回か出すか（2026-09-18）。⚠ 既定は false。
	var dump_enemy_sp: bool = false
	var _sp_dumps: int = 0

	# ⚠ battle_controller.gd に class_name が無いので型を付けられない。
	#   ここは検証用スクリプトなので許容する。本番コードでこの書き方をしないこと
	#   （AGENTS.md「エラーを理由にルールを緩めない」）。
	# 「止まった」とみなす1フレームの移動量と、その状態が続くべき長さ。
	const STILL_EPSILON: float = 0.5
	const STILL_HOLD_SEC: float = 0.5

	var _battle = null
	var _fired: int = 0
	var _last_fire_sec: float = -999.0
	var _signal_seen: bool = false
	var _prev_enemy_x: Dictionary = {}
	var _still_sec: float = 0.0
	# ⚠ 「全員が動くのをやめた」は 合図（＝敵が動くのをやめた）とは別物。
	#   実測：lineup で敵が止まった t=4.78 の時点で、味方の剣士（射程 60）はまだ
	#   歩いていた（x=486.7 → 目標 840）。⚠ 敵の停止は味方の停止を保証しない。
	# ⚠ 既存の 合図 の意味は変えないこと（段階4がその合図で数字を取っている）。
	var _prev_all_x: Dictionary = {}
	var _all_still_sec: float = 0.0
	var _all_settled_seen: bool = false
	var _prepared: Dictionary = {}
	# ⚠ チャージの押しっぱなし（2026-09-17・`hold_sec` の行）。⚠ 押し始めた t。負なら押していない。
	var _hold_started_sec: float = -1.0
	var _hold_mid_dumped: bool = false
	# ⚠ 最後に「敵を全滅させた」時刻。⚠ bool にしないこと。ウェーブが複数ある
	#   ステージでは2回目以降も殺す必要がある（_process() の最後の枝）。
	var _last_kill_sec: float = -999.0
	var _finished_sec: float = -1.0
	# ダンジョンで戦った回数と、⚠ 1本目の戦闘ノードの instance_id
	#   （遷移した直後の1フレームは古いシーンが current のままなので、
	#     同じものを2回つかまないための目印）。
	var _dungeon_battles: int = 0
	var _prev_battle_id: int = 0


	func _process(delta: float) -> void:
		if _battle == null:
			_battle = _find_battle()
			if _battle == null:
				return
			print("[DebugBoot] 戦闘画面をつかんだ")

		var session: BattleSession = _battle.get_session()
		if session == null:
			return

		# 決着した。ログが出揃うまで少し待ってから終わる。
		if session.state == BattleSession.STATE_VICTORY \
				or session.state == BattleSession.STATE_DEFEAT:
			if _finished_sec < 0.0:
				_finished_sec = 0.0
				print("[DebugBoot] 決着 state=%s t=%.2f" % [session.state, session.elapsed_sec])
				_dump_positions(session, "決着")
			_finished_sec += delta
			if dump_result and _step_dump_result(session):
				return
			if _finished_sec >= SETTLE_SEC:
				# ⚠ ダンジョンは2連戦する（道中 → ボス）。⚠ 続きがあるあいだは終わらない。
				if dungeon_mode and _next_dungeon_battle():
					return
				print("[DebugBoot] 終了")
				get_tree().quit()
			return

		if session.elapsed_sec > GIVE_UP_SEC:
			push_error("[DebugBoot] %.0f 秒たっても終わらないので諦める（撃った数=%d/%d）" % [
				GIVE_UP_SEC, _fired, skill_plan.size()
			])
			get_tree().quit()
			return

		if dump_pops and not _pops_dumped:
			_pops_dumped = _dump_pops()

		if dump_tooltip and not _tooltip_dumped:
			_tooltip_dumped = true
			_dump_tooltip()

		# ⚠ 敵の SP は時間で溜まるので、⚠ 何秒かおきに3回出す（⚠ 溜まる → 満ちる → 撃って戻る）。
		if dump_enemy_sp and _sp_dumps < SP_DUMP_SEC.size() \
				and session.elapsed_sec >= SP_DUMP_SEC[_sp_dumps]:
			_sp_dumps += 1
			_dump_enemy_sp(session)

		# ⚠ 立ち位置を測る合図。撃つ合図（_step_fire の 合図）とは別に、1回だけ出す。
		#   ここでしか「全員が射程ぴったりに落ち着いた x」は取れない。
		if not _all_settled_seen and _all_settled(session, delta):
			_all_settled_seen = true
			_dump_positions(session, "静止")

		if _fired < skill_plan.size():
			_step_fire(session, delta)
			return

		# 撃ち終わった。⚠ このステージは放っておいても終わらない（敵 hp 400 / 味方の火力が低い）ので、
		#   ログに result の行を出すために決着させる。
		#
		# ⚠ 1回きりにしないこと。⚠ 実測で踏んだ：ウェーブが複数あるステージでは、
		#   1回目の全滅で次のウェーブが始まり、そのウェーブは誰も殺さないまま
		#   GIVE_UP_SEC まで回って赤が出る（stage_dbg_intervene は敵同士が回復し合う）。
		# ⚠ 1ウェーブのステージでは1回目で決着するので、挙動は変わらない。
		# ⚠ 2回目以降だけ間を長く取る。⚠ 1回目を SETTLE_SEC のままにするのは、
		#   1ウェーブのシナリオ（既存の全部）の所要時間を1秒も変えないため。
		#   ⚠ 2回目以降を長くするのは、次のウェーブの敵が自分に状態を掛けたり
		#   互いを回復したりするのを観測する時間が要るため（stage_dbg_intervene）。
		if dump_status_tones and not _status_tones_dumped:
			_status_tones_dumped = true
			_dump_status_tones(session)
		var wait: float = SETTLE_SEC if _last_kill_sec < 0.0 else NEXT_WAVE_WATCH_SEC
		if session.elapsed_sec - maxf(_last_kill_sec, _last_fire_sec) >= wait:
			_last_kill_sec = session.elapsed_sec
			print("[DebugBoot] 撃ち終わったので決着させる t=%.2f" % session.elapsed_sec)
			_battle.debug_kill_all_enemies()


	func _step_fire(session: BattleSession, delta: float) -> void:
		# ⚠ 合図は時間で書かない。「敵が動くのをやめた」＝全員が射程ぴったりの位置に落ち着いた。
		#   段階4では t=2.32 で撃ってしまい、狼が歩いている途中で敵4体が固まっていたため
		#   radius:150 でも4体入って判定できなかった（EXEC_SKILL_AREA.md §2-2）。
		#
		# ⚠ 「味方が殴られたら」では足りない。実測で、最初に殴ってきたのは射程300の置物
		#   （enemy_dbg_ranged）で、狼はまだ歩いていた。殴られたことは配置を保証しない。
		if not _signal_seen:
			if not _enemies_settled(session, delta):
				return
			_signal_seen = true
			print("[DebugBoot] 合図：敵が動くのをやめた t=%.2f" % session.elapsed_sec)
			_dump_positions(session, "合図")
			return

		var entry: Dictionary = skill_plan[_fired]
		var skill_id: String = str(entry.get("skill", ""))

		# ⚠ 行ごとに間隔を上書きできる（段階5で足した）。recast の2段目は
		#   window_sec の中で撃つ必要があり、既定の FIRE_GAP_SEC では窓を跨ぐ。
		#   逆に「窓が切れるまで待つ」検証では既定より長くする。
		var gap: float = FIRE_GAP_SEC
		if entry.has("gap"):
			gap = float(entry["gap"])
		if session.elapsed_sec - _last_fire_sec < gap:
			return

		# 撃つ前の下ごしらえ（回復のために味方を削る等）。行ごとに1回だけ。
		#
		# ⚠ 行の番号で覚える。skill_id で覚えると、同じスキルを2行書いたとき
		#   （recast の2段目）に2行目の下ごしらえが飛ぶ。
		# ⚠ 値は外側の PREPARE_* 定数と綴りを揃えること。内部クラスからは外側の
		#   const を参照できないため、ここだけリテラルになっている。
		var prepare: String = str(entry.get("prepare", ""))
		if prepare != "" and not _prepared.has(_fired):
			_prepared[_fired] = true
			if prepare == "damage_party":
				print("[DebugBoot] 下ごしらえ：味方を削る（%s の前）" % skill_id)
				_battle.debug_damage_party(PREPARE_DAMAGE_POWER, BattleUnit.ATTACK_TYPE_PHYSICAL)
			elif prepare == "kill_party":
				print("[DebugBoot] 下ごしらえ：味方を全滅させる t=%.2f" % session.elapsed_sec)
				_battle.debug_damage_party(PREPARE_KILL_POWER, BattleUnit.ATTACK_TYPE_PHYSICAL)
			else:
				push_error("[DebugBoot] 知らない prepare: '%s'" % prepare)
			return

		# ⚠ skill が空の行は「下ごしらえだけの行」。ここで消化しないと、この下の
		#   _find_user() が null を返して赤を出す（全滅後は撃てる者が居ない）。
		if skill_id == "":
			_fired += 1
			_last_fire_sec = session.elapsed_sec
			return

		var user: BattleUnit = _find_user(session, skill_id)
		if user == null:
			push_error("[DebugBoot] %s を持っているユニットが居ない（スキル枠の割り当てを見ること）" % skill_id)
			_fired += 1
			return

		# ⚠⚠ チャージを押しっぱなしで撃つ行（2026-09-17・中央のチャージバー）。
		#   ⚠ マスのボタンと同じ入口（`_on_charge_button_down` / `_up`）を通す。
		#   ⚠ 押している途中と離す直前に、⚠ 中央のバーの状態をログに出す（⚠ 絵は取れない）。
		if entry.has("hold_sec"):
			_step_hold(session, entry, skill_id, user)
			return

		# ⚠ 戻り値は「撃てたか」。false ならクールダウン中か対象0体なので、次のフレームで試し直す。
		#   「押したつもりで撃てていない」がここで検出できる。
		if not _battle._fire_skill(user, skill_id, 1.0):
			return

		_fired += 1
		_last_fire_sec = session.elapsed_sec
		print("[DebugBoot] 撃った %s（%s） t=%.2f  %d/%d" % [
			skill_id, user.unit_id, session.elapsed_sec, _fired, skill_plan.size()
		])
		# ⚠ 段階8。移動系ルーンは「撃った瞬間に跳ぶ」ので、ここで x を取らないと
		#   合図・静止・決着の3点では跳んだことが1つも残らない。
		if dump_each_fire:
			_dump_positions(session, "撃った直後")


	# ⚠ 敵の SP を出す時刻（秒）。⚠ 検証用の敵（10秒）とボス（12.5秒）の両方をまたぐように取る。
	const SP_DUMP_SEC: Array[float] = [3.0, 10.5, 13.0]


	# 敵の行動予告の SP（2026-09-18）。⚠ 器の値と、⚠ ビューのゲージの両方を見る。
	func _dump_enemy_sp(session: BattleSession) -> void:
		var rows: Array[String] = []
		for u in session.enemy_units:
			if not (u is BattleUnit) or not u.is_alive():
				continue
			var unit: BattleUnit = u
			var gauge: String = "—"
			for view: Variant in _battle._enemy_views:
				if view is UnitView and (view as UnitView)._unit == unit:
					gauge = "ゲージ=%s" % (view as Node).get_node("SpBar").visible
			rows.append("%s(%s) SP %.1f/%.1f（回復 %.1f/秒）満=%s %s" % [
				unit.unit_id, unit.master_id, unit.sp, unit.sp_max, unit.sp_regen,
				unit.is_sp_full(), gauge,
			])
		print("[DebugBoot] 敵のSP t=%.2f ｜ %s" % [session.elapsed_sec, " ／ ".join(rows)])


	# スキルのマスのホバーの枠（2026-09-18）。⚠ 本物の配線を通す（⚠ マスの mouse_entered を出す）。
	#
	# ⚠ 絵は取れないので「何が書かれているか」と「マスの上に出ているか」を数字で見る。
	func _dump_tooltip() -> void:
		if _battle._skill_buttons.is_empty():
			push_error("[DebugBoot] スキルのマスが1つも無い")
			return
		var entry: Dictionary = _battle._skill_buttons[0]
		var tile: SkillTile = entry.get("button", null)
		var tip: SkillTooltip = _battle._skill_tooltip
		if tile == null or tip == null:
			push_error("[DebugBoot] マスか説明の枠が無い")
			return
		var hovered: Array[String] = []
		for raw: Variant in _battle._skill_buttons:
			var t: Variant = (raw as Dictionary).get("button", null)
			if t is SkillTile and (t as SkillTile).is_hovered():
				hovered.append(str((raw as Dictionary).get("skill_id", "")))
		print("[DebugBoot] 説明の枠（乗せる前）表示=%s ｜ 乗っているマス=%s ｜ マウス=%s" % [
			tip.visible, ",".join(hovered), _battle.get_viewport().get_mouse_position()
		])
		tile.mouse_entered.emit()
		var tile_rect: Rect2 = tile.get_global_rect()
		var rect: Rect2 = tip.get_global_rect()
		print("[DebugBoot] 説明の枠（%s）表示=%s ｜ 名前='%s' キー='%s' ｜ %s ｜ 説明='%s'（表示=%s）" % [
			str(entry.get("skill_id", "")), tip.visible,
			tip._name_label.text, tip._key_label.text, tip._meta_label.text,
			tip._desc_label.text, tip._desc_label.visible,
		])
		print("[DebugBoot]   枠 %.0f,%.0f %.0fx%.0f ／ マス %.0f,%.0f %.0fx%.0f（⚠ 枠の下端 %.0f < マスの上端 %.0f が正解）" % [
			rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			tile_rect.position.x, tile_rect.position.y, tile_rect.size.x, tile_rect.size.y,
			rect.end.y, tile_rect.position.y,
		])
		tile.mouse_exited.emit()
		print("[DebugBoot] 説明の枠（外したあと）表示=%s（⚠ false が正解）" % tip.visible)


	# 浮かぶダメージ数値（2026-09-18）。⚠ 出ていれば true を返して以後は呼ばれない。
	#
	# ⚠ 数字の Label は `UnitView` の**親**（陣営のコンテナ）に乗る（`pop_label()`）。
	# ⚠ 待っている件は透明（`modulate.a == 0`）。⚠ ここでずらしが効いているかを見る。
	func _dump_pops() -> bool:
		var rows: Array[String] = []
		for container_name: String in ["PartyUnitsContainer", "EnemyUnitsContainer"]:
			var container: Node = _battle.get_node_or_null(container_name)
			if container == null:
				continue
			for child: Node in container.get_children():
				if not (child is Label):
					continue
				var label: Label = child
				rows.append("'%s' 大きさ=%d 待ち=%s" % [
					label.text,
					label.get_theme_font_size(&"font_size"),
					label.modulate.a == 0.0,
				])
		# ⚠ 1件だけのフレームは通常攻撃。⚠ 見たいのは「同じ瞬間に何件も出て、
		#   ⚠ 後ろの件が待っている（透明）」フレームなので、⚠ それがそろうまで出さない。
		var waiting: int = 0
		for row: String in rows:
			if row.ends_with("待ち=true"):
				waiting += 1
		if rows.size() < 2 or waiting == 0:
			return false
		print("[DebugBoot] 浮かぶ数値 %d 件（⚠ うち待ち %d 件）｜ %s" % [
			rows.size(), waiting, " ／ ".join(rows)
		])
		# ⚠ 会心はこのステージでは出ない（⚠ 会心率0）ので、⚠ 大きさの計算だけ出す。
		var cfg: AdventureConfig = Balance.adventure
		print("[DebugBoot]   会心の大きさ = %d（⚠ 通常 %d × %.2f）／ ずらし %.2f 秒" % [
			int(round(float(cfg.pop_damage_font_size) * cfg.pop_crit_scale)),
			cfg.pop_damage_font_size, cfg.pop_crit_scale, cfg.pop_stagger_sec,
		])
		return true


	# 状態のチップの区分け（2026-09-17）。⚠ 器の本物の件を `StatusChips.tone_of()` に通す。
	func _dump_status_tones(session: BattleSession) -> void:
		var names: Array = StatusChips.Tone.keys()
		print("[DebugBoot] --- チップの区分け t=%.2f ---" % session.elapsed_sec)
		for u in session.party_units + session.enemy_units:
			if not (u is BattleUnit) or not u.is_alive():
				continue
			for entry: Dictionary in _battle._status.entries_for(u.unit_id):
				print("[DebugBoot]   %-10s %-24s kind=%-5s -> %s" % [
					u.unit_id, str(entry.get("status_id", "")), str(entry.get("kind", "")),
					names[StatusChips.tone_of(entry)],
				])
		# ⚠ 復活はこの編成で付けられない。⚠ 器の件と同じ欄を持つ見本で通す。
		var sample: Dictionary = {"kind": StatusRegistry.KIND_BUFF, "on_death": {"revive_hp_ratio": 0.3}}
		print("[DebugBoot]   見本       on_death（復活）          -> %s" % names[StatusChips.tone_of(sample)])
		# ⚠ シールドだけの件は、⚠ 敵に付くと撃ち終わる前に削り切られて消える（⚠ 実測で1件も残らなかった）。
		var shield_only: Dictionary = {"kind": StatusRegistry.KIND_BUFF, SkillSchema.INTERVENE_SHIELD_HP: 30}
		var shield_reflect: Dictionary = shield_only.duplicate()
		shield_reflect[SkillSchema.INTERVENE_REFLECT_FLAT] = 5
		print("[DebugBoot]   見本       シールドだけ              -> %s（⚠ HIDDEN が正解）" % names[StatusChips.tone_of(shield_only)])
		print("[DebugBoot]   見本       シールド＋反射            -> %s（⚠ BUFF が正解）" % names[StatusChips.tone_of(shield_reflect)])


	# 結果窓を出す（2026-09-17）。⚠ 戻りが true のあいだは終わらない。
	# ⚠ 1回目＝本物の窓 ／ 2回目＝見本の報酬で差し替えた窓。⚠ 差し替えは1フレーム待ってから測る
	#   （⚠ レイアウトは1フレーム待たないと確定しない）。
	func _step_dump_result(session: BattleSession) -> bool:
		var view: BattleResultView = _battle.result_view
		if _result_dumped == 0:
			if _finished_sec < SETTLE_SEC * 0.5:
				return true
			var damage: Array[String] = []
			for u in session.party_units:
				if u is BattleUnit:
					damage.append("%s=%d" % [u.unit_id, u.damage_taken])
			print("[DebugBoot] 結果窓（本物）表示=%s ｜ 被ダメージの内訳 %s ｜ %s" % [
				view.visible, ", ".join(damage), view.get_debug_summary()
			])
			var sample: Dictionary = MasterDataLoader.get_stage("floor_5").get("rewards", {})
			view.show_result({
				BattleResultView.DATA_VICTORY: true,
				BattleResultView.DATA_HEADING: "3層 波 3 / 3",
				BattleResultView.DATA_ELAPSED_SEC: 84.0,
				BattleResultView.DATA_DAMAGE_TAKEN: 142,
				BattleResultView.DATA_REWARDS: sample,
			})
			_result_dumped = 1
			return true
		if _result_dumped == 1:
			_result_dumped = 2
			print("[DebugBoot] 結果窓（見本 floor_5 の報酬）%s" % view.get_debug_summary())
		return false


	func _step_hold(session: BattleSession, entry: Dictionary, skill_id: String, user: BattleUnit) -> void:
		var button_entry: Dictionary = {}
		for raw: Variant in _battle._skill_buttons:
			if str((raw as Dictionary).get("skill_id", "")) == skill_id and (raw as Dictionary).get("user", null) == user:
				button_entry = raw
		if button_entry.is_empty():
			push_error("[DebugBoot] %s のマスが無い" % skill_id)
			_fired += 1
			return
		var hold: float = float(entry["hold_sec"])
		if _hold_started_sec < 0.0:
			if not user.is_skill_ready(skill_id):
				return
			_battle._on_charge_button_down(button_entry)
			_hold_started_sec = session.elapsed_sec
			_hold_mid_dumped = false
			_dump_charge_bar("押した直後", button_entry)
			return
		var held: float = session.elapsed_sec - _hold_started_sec
		if not _hold_mid_dumped and held >= hold * 0.5:
			_hold_mid_dumped = true
			_dump_charge_bar("途中", button_entry)
		if held < hold:
			return
		_dump_charge_bar("離す直前", button_entry)
		var t: float = float(_battle._charging.get("time", 0.0))
		var just: bool = _battle._is_just(button_entry, t)
		_battle._on_charge_button_up(button_entry)
		_dump_charge_bar("離した直後", button_entry)
		_hold_started_sec = -1.0
		_fired += 1
		_last_fire_sec = session.elapsed_sec
		print("[DebugBoot] 溜めて撃った %s（%s） 溜め=%.2f秒 ジャスト=%s  %d/%d" % [
			skill_id, user.unit_id, t, just, _fired, skill_plan.size()
		])


	# 中央のチャージバーの状態を1行で出す。⚠ 絵は取れないので「出ているか・どの行か・秒・帯の中か」。
	func _dump_charge_bar(label: String, button_entry: Dictionary) -> void:
		var bar: ChargeBar = _battle._charge_bar
		if bar == null:
			push_error("[DebugBoot] チャージバーが作られていない")
			return
		var row: int = int(button_entry.get("charge_row", -1))
		var shown: Array[String] = []
		for i: int in range(bar._rows.size()):
			var track: Variant = bar._rows[i]["track"]
			shown.append("行%d t=%.2f 帯=%s 過ぎ=%s" % [i, track.t, track.in_band(), track.is_over()])
		# ⚠ 横の真ん中に居るか（2026-09-17・人間「今は左に寄って見える」）。⚠ 基準の幅 1280 の中心は 640。
		var rect: Rect2 = bar.get_global_rect()
		# ⚠ 「JUST!」の残り秒と、⚠ 帯に入ったときの顔の枠（2026-09-18）。⚠ 絵は取れないので数字で見る。
		var just_left: float = bar._just_left_sec
		var face_border: int = 0
		if row >= 0 and row < bar._rows.size():
			face_border = (bar._rows[row]["face"] as CharacterAvatar)._border_width
		print("[DebugBoot] チャージバー（%s）表示=%s 行数=%d このスキルの行=%d 左右=%.0f〜%.0f（中心 %.0f）｜ JUST残り=%.2f秒 顔の枠=%dpx ｜ %s" % [
			label, bar.visible, bar._rows.size(), row,
			rect.position.x, rect.end.x, rect.get_center().x,
			just_left, face_border, " ／ ".join(shown)
		])


	# 生きているユニットの立ち位置を x の昇順で出す。
	#
	# ⚠ これが要る理由：battle_last.jsonl で位置を持っているのは spawn の行だけ
	#   （battle_log.gd:181-190）。damage にも cast にも x が無いので、
	#   「射程の段で散ったか」を設計役が観測する手段が他に無い。
	# ⚠ 本番の BattleLog には足さない（出来事の種類を増やさない）。検証の道具側に閉じる。
	#
	# ⚠ 「最小間隔」は同じチームの隣同士の x の差。⚠ 同じ型が複数体出ると必ず 0.0 になる
	#   （人間の決定2で許容した状態）ので、⚠ 型をまたぐぶんだけの最小値も併せて出す。
	#   型は unit_name_key で見分ける（同じマスターから作られた個体は同じキーを持つ）。
	func _dump_positions(session: BattleSession, label: String) -> void:
		print("[DebugBoot] 位置（%s）t=%.2f" % [label, session.elapsed_sec])
		var groups: Array = [
			["party", session.party_units],
			["enemy", session.enemy_units],
			["summon", session.summon_units],
		]
		var summary: Array = []
		for group: Array in groups:
			var team_label: String = str(group[0])
			var rows: Array = []
			for u in group[1]:
				if not (u is BattleUnit) or not u.is_alive():
					continue
				# ⚠ 狙う相手も出す。battle_last.jsonl には target_unit_id が1件も出ないので、
				#   「近くの敵を無視して後ろの敵へ行く」の切り分けがログからできない。
				rows.append({
					"id": u.unit_id, "key": u.unit_name_key, "x": u.x,
					"range": u.attack_range, "target": u.target_unit_id,
				})
			if rows.is_empty():
				continue
			rows.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))

			var min_gap: float = -1.0
			var min_gap_cross: float = -1.0
			for i: int in range(rows.size()):
				var row: Dictionary = rows[i]
				var gap_text: String = "—"
				if i > 0:
					var prev: Dictionary = rows[i - 1]
					var gap: float = float(row["x"]) - float(prev["x"])
					gap_text = "%.1f" % gap
					if min_gap < 0.0 or gap < min_gap:
						min_gap = gap
					if str(prev["key"]) != str(row["key"]):
						if min_gap_cross < 0.0 or gap < min_gap_cross:
							min_gap_cross = gap
				print("[DebugBoot]   %-6s %-20s x=%8.1f  range=%5.0f  間隔=%-7s 狙う=%s" % [
					team_label, str(row["id"]), float(row["x"]), float(row["range"]),
					gap_text, str(row["target"])
				])
			summary.append("%s=%.1f(型跨ぎ %.1f)" % [team_label, maxf(min_gap, 0.0), maxf(min_gap_cross, 0.0)])
		if not summary.is_empty():
			print("[DebugBoot]   最小間隔  %s" % " ".join(PackedStringArray(summary)))


	func _find_battle():
		var current: Node = get_tree().current_scene
		if current == null:
			return null
		if current.scene_file_path != battle_scene_path:
			return null
		# ⚠ 2本目へ遷移した直後の1フレームは、まだ1本目のシーンが current。
		#   ⚠ ここで弾かないと、決着済みの同じ戦闘をもう一度つかんで即終了する。
		if _prev_battle_id != 0 and current.get_instance_id() == _prev_battle_id:
			return null
		return current


	# ダンジョンの戦闘が1本終わった。⚠ 結果を出し、続きがあれば次の戦闘へ行く。
	#
	# ⚠ 戻り値 true = まだ続く（終了しない）。
	# ⚠ ここで GameManager を直接叩くのは「見る」ためだけ。⚠ HP の書き戻しも
	#   ボスの撃破も、⚠ 本番コード（battle_controller）が済ませている。
	func _next_dungeon_battle() -> bool:
		_dungeon_battles += 1
		_report_dungeon_state("%d本目のあと" % _dungeon_battles)

		if _dungeon_battles >= 2:
			_report_dungeon_base_max_hp()
			return false
		if not GameManager.is_in_dungeon():
			print("[DebugBoot]   ⚠ ランが終わっている（＝死亡）ので2本目は回さない")
			_report_dungeon_base_max_hp()
			return false

		# ボスまで歩く。⚠ 道中の戦利品はここで入る（ノード種に紐づく）。
		var guard: int = 0
		while true:
			var moves: Array = GameManager.get_dungeon_moves()
			if moves.is_empty():
				break
			if not GameManager.move_in_dungeon(str(moves[0])):
				push_error("[DebugBoot] move_in_dungeon が false: " + str(moves[0]))
				return false
			guard += 1
			if guard > 50:
				push_error("[DebugBoot] 50手でボスに着かない")
				return false
		var position: String = str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
		)
		if not GameManager.is_dungeon_boss_node(position):
			push_error("[DebugBoot] ボスのノードに着いていない: " + position)
			return false
		print("[DebugBoot] --- 2本目：ボスのノード '%s' で戦う（%d手歩いた）---" % [position, guard])
		print("  ⚠ 戦う前の phase = '%s'（map が正解）" % GameManager.get_dungeon_phase())

		# 同じ Driver を作り直さずに使い回す。⚠ 撃つ計画は最初から数え直す。
		_prev_battle_id = _battle.get_instance_id()
		_battle = null
		_fired = 0
		_last_fire_sec = -999.0
		_signal_seen = false
		_prev_enemy_x = {}
		_still_sec = 0.0
		_prev_all_x = {}
		_all_still_sec = 0.0
		_all_settled_seen = false
		_prepared = {}
		_last_kill_sec = -999.0
		_finished_sec = -1.0
		# ⚠ 2本目（ボス）でも SP を出す（2026-09-18）。⚠ 戻さないと1本目のぶんで数え終わっている。
		_sp_dumps = 0
		SceneManager.change_scene_with_data(battle_scene_path, {
			TransferKeys.DUNGEON_NODE_ID: position,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
		})
		return true


	# ランの中身を出す。⚠ 目減り（§4-4）が見えるのはここ。
	func _report_dungeon_state(label: String) -> void:
		print("[DebugBoot] --- ランの状態（%s）---" % label)
		if not GameManager.is_in_dungeon():
			print("  is_in_dungeon() = false（＝撤退したか死亡した）")
			return
		print("  ランのMAX HP = %s ／ HP = %s（⚠ 戦闘終了時のHPがそのまま両方に入るのが正解）" % [
			str(GameManager.get_dungeon_max_hp()), str(GameManager.get_dungeon_hp())
		])
		var downed: Array[String] = []
		for member: Variant in GameManager.get_party_members():
			if GameManager.is_dungeon_character_downed(str(member)):
				downed.append(str(member))
		print("  脱落 = %d 人%s ／ 出られる編成 = %s" % [
			downed.size(), "" if downed.is_empty() else " " + str(downed),
			str(GameManager.get_dungeon_active_members()),
		])
		print("  phase = '%s' ／ 鞄 = %d/%d ／ 一時通貨 = %d ／ フロア = %d" % [
			GameManager.get_dungeon_phase(),
			GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots(),
			GameManager.get_dungeon_currency(), GameManager.get_dungeon_floor_index(),
		])
		print("  can_retreat_from_dungeon() = %s" % str(GameManager.can_retreat_from_dungeon()))


	# 素の MAX HP が1も動いていないこと（決定8の一番の落とし穴）。
	func _report_dungeon_base_max_hp() -> void:
		print("[DebugBoot] --- 素の MAX HP（⚠ ダンジョンが触るのはランの MAX HP だけ）---")
		var drifted: int = 0
		for character_id: Variant in dungeon_base_max_hp:
			var before: int = int(dungeon_base_max_hp[character_id])
			var now: int = int(
				GameManager.get_effective_stats(str(character_id)).get(GameStateKeys.STAT_HP, 0)
			)
			if now != before:
				push_error("[DebugBoot] 素の MAX HP が動いた: %s %d -> %d" % [str(character_id), before, now])
				drifted += 1
			print("    %-16s %d -> %d" % [str(character_id), before, now])
		print("  動いたキャラ = %d 人（0 が正解）" % drifted)


	# 生きている敵全員の x が STILL_HOLD_SEC のあいだ動かなかったか。
	# ⚠ ユニットは「距離 <= attack_range」で止まる（battle_controller.gd:601-627）ので、
	#   止まった＝全員が狙う相手の射程ぴったりに落ち着いた、という意味になる。
	func _enemies_settled(session: BattleSession, delta: float) -> bool:
		var moved: bool = false
		var current: Dictionary = {}
		for u in session.enemy_units:
			if not (u is BattleUnit) or not u.is_alive():
				continue
			current[u.unit_id] = u.x
			if _prev_enemy_x.has(u.unit_id) \
					and absf(float(_prev_enemy_x[u.unit_id]) - u.x) > STILL_EPSILON:
				moved = true

		var had_sample: bool = not _prev_enemy_x.is_empty()
		_prev_enemy_x = current

		if moved or current.is_empty() or not had_sample:
			_still_sec = 0.0
			return false

		_still_sec += delta
		return _still_sec >= STILL_HOLD_SEC


	# 生きている全ユニット（味方・敵・召喚）の x が STILL_HOLD_SEC のあいだ動かなかったか。
	#
	# ⚠ _enemies_settled() との違いは2つ。
	#   ① 母集団（味方・敵・召喚の全員）。敵が止まっても味方はまだ歩いていることがある
	#      （射程が短い者ほど遠くまで歩く）ので、立ち位置はこちらで測る。
	#   ② ⚠ 「動いた」の測り方。_enemies_settled() は「前のフレームからの差」で見るが、
	#      これはフレームレート依存で、⚠ ヘッドレスの高い fps では歩いている者を
	#      止まったと誤判定する。実測：剣士（spd 60）は 486.8 で「静止」と判定されたが、
	#      実際にはそのあと 547.6 まで歩いた（1フレームの移動量が STILL_EPSILON 未満）。
	#      → ⚠ 「窓の始まりの位置」を基準に、窓のあいだの総移動量で見る。
	#   ⚠ _enemies_settled() 側は直さない。段階4がその合図で数字を取っている。
	func _all_settled(session: BattleSession, delta: float) -> bool:
		var current: Dictionary = {}
		for group: Array in [session.party_units, session.enemy_units, session.summon_units]:
			for u in group:
				if not (u is BattleUnit) or not u.is_alive():
					continue
				current[u.unit_id] = u.x

		if current.is_empty():
			_all_still_sec = 0.0
			_prev_all_x = {}
			return false

		# 基準（窓の始まり）から動いた者が居るか。⚠ 顔ぶれが変わったら測り直す。
		var moved: bool = _prev_all_x.size() != current.size()
		if not moved:
			for id in current.keys():
				if not _prev_all_x.has(id) \
						or absf(float(_prev_all_x[id]) - float(current[id])) > STILL_EPSILON:
					moved = true
					break

		if moved:
			_prev_all_x = current
			_all_still_sec = 0.0
			return false

		_all_still_sec += delta
		return _all_still_sec >= STILL_HOLD_SEC


	func _find_user(session: BattleSession, skill_id: String) -> BattleUnit:
		for u in session.party_units:
			if u is BattleUnit and u.is_alive() and skill_id in u.skill_ids:
				return u
		return null


# ============================================================
# マス目（段階18-a・PLAN_INVENTORY.md）
#
# ⚠ 「何がマスを1つ占めるか」を決める口は GameManager.get_inventory_slot_entries() の1本。
#   ⚠ ここで item_type を見て数え直さないこと（数え方が2箇所になる）。
# ============================================================

# 持ち物の一覧の要素の数（⚠ 2026-10-03・回3-d：⚠ 「マスの数」の口は消した＝一覧の長さで数える）。
func _inventory_entry_count() -> int:
	return GameManager.get_inventory_slot_entries().size()


func _report_inventory() -> void:
	print("[DebugBoot] --- 持ち物の一覧（⚠ 汎用素材は並ばない＝人間の決定5）---")
	print("  最初の状態： %d 件" % _inventory_entry_count())

	# 1. 素材を入れても一覧は増えないこと。
	var before_material: int = _inventory_entry_count()
	GameManager.add_material("construction_material_1", 999)
	print("  素材を 999 個足す -> %d 件（増えないのが正解） / 所持 %d 個" % [
		_inventory_entry_count(), GameManager.get_material_count("construction_material_1")
	])
	if _inventory_entry_count() != before_material:
		push_error("[DebugBoot] 汎用素材で一覧が増えた（決定5 に反する）")

	# 2. ⚠⚠ 消耗品は **1種類＝1件**（2026-09-10・人間の決定「⚠ 1マスに重ねて x3 と出す」）。
	var before_potion: int = _inventory_entry_count()
	GameManager.add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, 3, GameStateKeys.ITEM_TYPE_CONSUMABLE)
	print("  消耗品を 3 個足す -> %d 件（⚠ +1 が正解＝重ねる）" % _inventory_entry_count())
	if _inventory_entry_count() != before_potion + 1:
		push_error("[DebugBoot] 消耗品の数え方が 1種類＝1件 になっていない")
	var before_more: int = _inventory_entry_count()
	GameManager.add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, 3, GameStateKeys.ITEM_TYPE_CONSUMABLE)
	print("  同じものをもう 3 個 -> %d 件（⚠ 増えないのが正解） / 所持 %d 個" % [
		_inventory_entry_count(), GameManager.get_item_count(GameStateKeys.ITEM_STAMINA_POTION),
	])
	if _inventory_entry_count() != before_more:
		push_error("[DebugBoot] 既に持っている品で一覧が増えた（重ねられていない）")

	# 3. 装飾も同じ。
	var before_part: int = _inventory_entry_count()
	GameManager.add_to_inventory("part_gem_atk_1", 5, GameStateKeys.ITEM_TYPE_PART)
	print("  装飾を 5 個足す -> %d 件（⚠ +1 が正解）" % _inventory_entry_count())
	if _inventory_entry_count() != before_part + 1:
		push_error("[DebugBoot] 装飾の数え方が 1種類＝1件 になっていない")

	# 4. 装備は個体なので 1個＝1件。
	var before_equip: int = _inventory_entry_count()
	GameManager.add_to_inventory("weapon_iron_sword", 2, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	print("  装備を 2 本足す -> %d 件（+2 が正解＝個体）" % _inventory_entry_count())
	if _inventory_entry_count() != before_equip + 2:
		push_error("[DebugBoot] 装備の数え方が 1個＝1件 になっていない")

	# 5. 中身の内訳。⚠ マス1つぶんの形が画面（ItemSlot）へそのまま渡る。
	var entries: Array = GameManager.get_inventory_slot_entries()
	var by_kind: Dictionary = {}
	for entry: Variant in entries:
		var kind: String = str((entry as Dictionary).get(GameManager.SLOT_ENTRY_KIND, ""))
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
	print("  内訳 = %s ／ 合計 %d マス" % [str(by_kind), entries.size()])
	for i: int in range(mini(4, entries.size())):
		var row: Dictionary = entries[i]
		print("    %d: kind=%-8s item=%-22s instance=%-6s grade=%d 装備中=%s" % [
			i, str(row.get(GameManager.SLOT_ENTRY_KIND, "")),
			str(row.get(GameManager.SLOT_ENTRY_ITEM_ID, "")),
			str(row.get(GameManager.SLOT_ENTRY_INSTANCE_ID, "")),
			int(row.get(GameManager.SLOT_ENTRY_GRADE, 0)),
			str(row.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, "")),
		])

	# 5-b. ⚠⚠ マスが個数を持っていること（2026-09-10・重ねる形にした回）。
	#    ⚠ 数を出すのは `ItemIcon` の右下。⚠ その元になるのがこの `count`。
	#    ⚠ 入っていないと、⚠ マスに数が出ないまま「6個持っているのに1個に見える」。
	print("[DebugBoot] --- マスが持つ個数（SLOT_ENTRY_COUNT）---")
	var potion_slot: Dictionary = {}
	for entry: Variant in GameManager.get_inventory_slot_entries():
		if str((entry as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, "")) == (
			GameStateKeys.ITEM_STAMINA_POTION
		):
			potion_slot = entry
			break
	print("  スタミナポーションのマス count=%s（⚠ 所持 %d と同じが正解）" % [
		str(potion_slot.get(GameManager.SLOT_ENTRY_COUNT, "無し")),
		GameManager.get_item_count(GameStateKeys.ITEM_STAMINA_POTION),
	])
	if int(potion_slot.get(GameManager.SLOT_ENTRY_COUNT, -1)) != GameManager.get_item_count(
		GameStateKeys.ITEM_STAMINA_POTION
	):
		push_error("[DebugBoot] マスの個数が所持数と合っていない")

	# ⚠ 5-c（捨てる個数）・6（未決7 の実測）・6-B（ページ）は 2026-10-03 に消した（回3-d：⚠ 捨てる・容量・ページが無くなった）。
	_report_inventory_equip()

	# 7. ⚠ 器が実際に組めるか（段階18-a の本体）。⚠ 画面に出すのは 18-c / 18-d。
	#   ⚠ ここで見るのは「マスの数が中身と枠から正しく出るか」と「赤が出ないこと」だけ。
	#   ⚠ 絵は取れない（ヘッドレス）。⚠ 見た目は人間が 18-c で見る。
	var entries_now: Array = GameManager.get_inventory_slot_entries()
	var grid: ItemGrid = ItemGrid.new()
	grid.name = "InventoryGridProbe"
	grid.columns = 8
	add_child(grid)
	var slot_count: int = entries_now.size() + 5
	grid.rebuild(entries_now, slot_count)
	print("[DebugBoot] --- 器（ItemGrid / ItemSlot）---")
	print("  中身 %d 件 / 枠 %d -> マス %d 個（⚠ 枠と同じが正解） / 空き %d 個" % [
		entries_now.size(), slot_count, grid.get_slot_count(), slot_count - entries_now.size()
	])
	if grid.get_slot_count() != slot_count:
		push_error("[DebugBoot] マスの数が枠と合わない")
	# ⚠ 先頭は中身入り、⚠ 末尾は空。⚠ 空のマスも同じ部品で並ぶこと。
	var first: ItemSlot = grid.get_child(0)
	var last: ItemSlot = grid.get_child(grid.get_slot_count() - 1)
	print("  先頭のマス is_empty=%s（false が正解） / 末尾のマス is_empty=%s（true が正解）" % [
		str(first.is_empty()), str(last.is_empty())
	])
	# ⚠⚠ マスの中の子が「押下を飲まない」こと（2026-09-03・人間が実機で見つけた穴）。
	#   ⚠ 中身のあるマスはアイコンが 40px を覆う。⚠ そこが STOP だと、
	#     ⚠ マスの縁 4px しか押せず、⚠ 選べないしドラッグも始まらない。
	#   ⚠ 絵は取れないが mouse_filter は取れる。⚠ ここが唯一の確かめ方。
	print("  マスの中の子の mouse_filter（⚠ 2＝IGNORE が正解。⚠ 0＝STOP だと押下を飲む）")
	for child: Node in first.get_children():
		if not (child is Control):
			continue
		print("    %-14s %d" % [child.name, int((child as Control).mouse_filter)])
		if int((child as Control).mouse_filter) != Control.MOUSE_FILTER_IGNORE:
			push_error("[DebugBoot] マスの中の '%s' が押下を飲む（mouse_filter=%d）" % [
				child.name, int((child as Control).mouse_filter)
			])
		for grand: Node in child.get_children():
			if not (grand is Control):
				continue
			print("      %-12s %d" % [grand.name, int((grand as Control).mouse_filter)])
			if int((grand as Control).mouse_filter) != Control.MOUSE_FILTER_IGNORE:
				push_error("[DebugBoot] マスの中の '%s' が押下を飲む（mouse_filter=%d）" % [
					grand.name, int((grand as Control).mouse_filter)
				])
	print("  マスそのもの（ItemSlot）の mouse_filter = %d（⚠ 0＝STOP が正解。⚠ ここは受け取る側）" % [
		int(first.mouse_filter)
	])

	# ⚠⚠ ツールチップの二重表示（2026-09-10・積み残し9）。
	#   ⚠ ホバーの枠（`ItemDetailPopup`）が出る画面では、⚠ 品の名前がツールチップと
	#     枠の2枚で重なって出ていた。⚠ `watch()` が器ごとツールチップを落とす形にした。
	#   ⚠ 絵は取れないが `tooltip_text` は取れる。⚠ ここが唯一の確かめ方。
	print("[DebugBoot] --- ツールチップの二重表示（ItemSlot / ItemDetailPopup）---")
	print("  枠が無いとき（⚠ 装備・UIテストの一部）: '%s'（⚠ 品の名前が入るのが正解）" % [
		first.tooltip_text
	])
	if not first.is_empty() and first.tooltip_text == "":
		push_error("[DebugBoot] 枠を出さない画面でツールチップまで消えている")
	var probe_popup: ItemDetailPopup = ItemDetailPopup.adopt(self, ItemDetail.new())
	probe_popup.watch(grid)
	print("  watch のあと・既にあるマス: '%s'（⚠ 空が正解＝枠と二重に出ない）" % first.tooltip_text)
	if first.tooltip_text != "":
		push_error("[DebugBoot] watch したのにツールチップが残っている（枠と二重に出る）")
	# ⚠ 倉庫の順番（⚠ _ready で watch → ⚠ あとで rebuild）でも消えていること。
	#   ⚠ 器が覚えていないと、⚠ 作り直した瞬間に二重表示へ戻る。
	grid.rebuild(entries_now, slot_count)
	var first_rebuilt: ItemSlot = grid.get_child(0)
	print("  watch のあとに作り直したマス: '%s'（⚠ 空が正解）" % first_rebuilt.tooltip_text)
	if first_rebuilt.tooltip_text != "":
		push_error("[DebugBoot] 作り直したマスにツールチップが戻っている")
	probe_popup.queue_free()
	grid.queue_free()

	# 8. ⚠ 押したときの詳細（段階18-c-2・共有部品 ItemDetail）。
	#   ⚠ 画面の絵は取れないが、⚠ 出る「行」は取れる。⚠ ここが唯一の確かめ方。
	print("[DebugBoot] --- 押したときの詳細（ItemDetail の行）---")
	var detail: ItemDetail = ItemDetail.new()
	detail.name = "ItemDetailProbe"
	add_child(detail)
	detail.show_entry({})
	print("  選んでいないとき: %s" % str(detail.get_lines()))
	var seen_kinds: Dictionary = {}
	for entry: Variant in entries_now:
		var row: Dictionary = entry
		var key: String = "%s_%s" % [
			str(row.get(GameManager.SLOT_ENTRY_KIND, "")),
			"rune" if not GameManager.get_rune_definition(
				str(row.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
			).is_empty() else "normal",
		]
		if seen_kinds.has(key):
			continue
		seen_kinds[key] = true
		detail.show_entry(row)
		print("  %s（%s）" % [str(row.get(GameManager.SLOT_ENTRY_ITEM_ID, "")), key])
		for line: String in detail.get_lines():
			print("    %s" % line)
	# ⚠ 装飾を刺した装備も見る（⚠ 等級1では枠が1つも開かないので、⚠ 先に鍛える）。
	#   ⚠ 枠は等級3から開く（GAME_DESIGN.md 6-4）。⚠ ここを飛ばすと「枠の行」が一度も出ない。
	var forge_target: String = _find_instance_of("weapon_iron_sword")
	if forge_target != "":
		for material_id: Variant in MasterDataLoader.get_all_items():
			GameManager.add_material(str(material_id), 99999)
		for _i: int in range(3):
			var _forged: bool = GameManager.forge_equipment(forge_target)
		var part_slots: Array = GameManager.get_part_entries(forge_target)
		if part_slots.is_empty():
			print("  ⚠ 枠が1つも開かなかった（鍛えられていない）")
		else:
			var _attached: bool = GameManager.attach_part(
				forge_target,
				int((part_slots[0] as Dictionary).get(GameManager.PART_VIEW_INDEX, 0)),
				"part_gem_atk_1"
			)
			detail.show_entry({
				GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
				GameManager.SLOT_ENTRY_ITEM_ID: "weapon_iron_sword",
				GameManager.SLOT_ENTRY_INSTANCE_ID: forge_target,
				GameManager.SLOT_ENTRY_GRADE: int(GameManager.get_equipment_instance(forge_target).get(
					GameStateKeys.INSTANCE_GRADE, 1
				)),
				GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
			})
			print("  ⚠ 鍛えて装飾を刺した装備（⚠ 枠の行が出るか）")
			for line: String in detail.get_lines():
				print("    %s" % line)

	# ⚠ 消耗品も1つ見る（⚠ 説明文＝ja.csv の ui_desc_* が出るか）。
	detail.show_entry({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
		GameManager.SLOT_ENTRY_ITEM_ID: GameStateKeys.ITEM_STAMINA_POTION,
		GameManager.SLOT_ENTRY_INSTANCE_ID: "",
		GameManager.SLOT_ENTRY_GRADE: 0,
		GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
	})
	print("  stamina_potion（説明文が出るか）")
	for line: String in detail.get_lines():
		print("    %s" % line)

	# ⚠ 装備の「品」（＝個体ではない）も見る（2026-09-07・人間の指示
	#   「⚠ 装備などに関してはスロットなども人眼で見れるように」）。
	#   ⚠ 等級を変えると開いている枠が増えるのが正解（⚠ 「いつ開くか」は出さない）。
	#   ⚠ 等級 0 は UI テスト以外のマス（⚠ 個数を出す枝）。
	for probe_grade: int in [0, 1, 5, GameManager.get_max_equipment_grade()]:
		detail.show_entry({
			GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
			GameManager.SLOT_ENTRY_ITEM_ID: "weapon_iron_sword",
			GameManager.SLOT_ENTRY_INSTANCE_ID: "",
			GameManager.SLOT_ENTRY_GRADE: probe_grade,
			GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
		})
		print("  weapon_iron_sword 等級%d（⚠ 品としての装備。⚠ 開いている枠だけ出るか）" % probe_grade)
		for line: String in detail.get_lines():
			print("    %s" % line)

	# ⚠ アクセも見る（2026-09-07・人間の指示「⚠ アクセのルーン枠を1つに」）。
	#   ⚠ 最大等級で **ルーン枠が1つ**なのが正解（⚠ 前は2つだった）。
	detail.show_entry({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
		GameManager.SLOT_ENTRY_ITEM_ID: "acc_ring_power",
		GameManager.SLOT_ENTRY_INSTANCE_ID: "",
		GameManager.SLOT_ENTRY_GRADE: GameManager.get_max_equipment_grade(),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
	})
	print("  acc_ring_power 最大等級（⚠ ルーン枠が1つなのが正解）")
	for line: String in detail.get_lines():
		print("    %s" % line)

	# ⚠ 頭・胴・脚だけ **ワイルド枠**を持つ（`game_manager.gd:2884`）。
	#   ⚠ 2026-09-08 にワイルドの枠線を虹色にした（⚠ 人間の指示）。⚠ 色は取れないが、
	#   ⚠ 「⚠ ワイルド枠がここにしか出ない」ことはこの行で分かる。
	detail.show_entry({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
		GameManager.SLOT_ENTRY_ITEM_ID: "armor_iron_helm",
		GameManager.SLOT_ENTRY_INSTANCE_ID: "",
		GameManager.SLOT_ENTRY_GRADE: GameManager.get_max_equipment_grade(),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
	})
	print("  armor_iron_helm 最大等級（⚠ ワイルド枠が1つ出るのが正解＝虹色の枠）")
	for line: String in detail.get_lines():
		print("    %s" % line)

	# ⚠⚠ 要約（＝ホバーの枠）も見る（2026-09-08・段階④）。
	#   ⚠ フルとの違い：⚠ 部位が枠の行の頭に回る ／ ⚠ 分解・鍛えるの数字が消える。
	#   ⚠ ここを測らないと、⚠ 画面の絵が取れない以上、要約の中身を誰も確かめられない。
	detail.set_summary(true)
	detail.show_entry({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
		GameManager.SLOT_ENTRY_ITEM_ID: "armor_iron_helm",
		GameManager.SLOT_ENTRY_INSTANCE_ID: "",
		GameManager.SLOT_ENTRY_GRADE: GameManager.get_max_equipment_grade(),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
	})
	print("  ⚠ 要約 armor_iron_helm 最大等級（⚠ 「頭 ／ 枠 ／ 0 / 7」が1行になるのが正解）")
	for line: String in detail.get_lines():
		print("    %s" % line)
	if forge_target != "":
		detail.show_entry({
			GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
			GameManager.SLOT_ENTRY_ITEM_ID: "weapon_iron_sword",
			GameManager.SLOT_ENTRY_INSTANCE_ID: forge_target,
			GameManager.SLOT_ENTRY_GRADE: int(GameManager.get_equipment_instance(forge_target).get(
				GameStateKeys.INSTANCE_GRADE, 1
			)),
			GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
		})
		print("  ⚠ 要約 鍛えた個体（⚠ 「素材にする」「鍛える」の行が出ないのが正解）")
		for line: String in detail.get_lines():
			print("    %s" % line)
		# ⚠⚠ 着けている人の行（2026-09-10・積み残し9）。⚠ 前はフルにしか出さず、
		#   ⚠ 要約側では マスの素のツールチップが同じことを出していた。
		#   ⚠ その二重表示を止めたので、⚠ 要約が唯一の出どころになった。
		detail.show_entry({
			GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
			GameManager.SLOT_ENTRY_ITEM_ID: "weapon_iron_sword",
			GameManager.SLOT_ENTRY_INSTANCE_ID: forge_target,
			GameManager.SLOT_ENTRY_GRADE: int(GameManager.get_equipment_instance(forge_target).get(
				GameStateKeys.INSTANCE_GRADE, 1
			)),
			GameManager.SLOT_ENTRY_EQUIPPED_BY: str(GameManager.get_party_members()[0]),
		})
		print("  ⚠ 要約 着けている個体（⚠ 「装備中」の行が1本出るのが正解）")
		for line: String in detail.get_lines():
			print("    %s" % line)
	detail.set_summary(false)
	for slot_name: String in GameManager.get_equip_slots():
		print("    枠の数 %-10s = %d" % [
			slot_name, GameManager.get_open_part_slot_count(slot_name, GameManager.get_max_equipment_grade())
		])
	detail.queue_free()

	_report_inventory_no_capacity()


# 装備するとマスが移る（人間の決定7・2026-09-03）。
#
# ⚠ 見るのは「装備中の個体が持ち物の一覧に出ないこと」（⚠ 満杯で外させない判定は 10-03 に消した）。
func _report_inventory_equip() -> void:
	print("[DebugBoot] --- 装備するとマスが移る（⚠ インベントリ → キャラの装備マス）---")
	var character_id: String = str(GameManager.get_party_members()[0])
	# ⚠ 素の状態から見たいので、⚠ 空いている個体を1つ作る。
	var _accepted: int = GameManager.add_to_inventory(
		"armor_iron_helm", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT
	)
	var instance_id: String = _find_instance_of("armor_iron_helm")
	if instance_id == "":
		push_error("[DebugBoot] 個体を作れなかった（装備の検証ができない）")
		return

	var before: int = _inventory_entry_count()
	var equipped: bool = GameManager.equip_instance(character_id, GameStateKeys.EQUIP_HEAD, instance_id)
	var after_equip: int = _inventory_entry_count()
	print("  装備する -> %s / 持ち物 %d -> %d 件（⚠ 1 減るのが正解）" % [
		str(equipped), before, after_equip
	])
	if after_equip != before - 1:
		push_error("[DebugBoot] 装備してもインベントリのマスが減っていない（決定7 に反する）")

	# キャラの装備マスに出ていること。⚠ 5枠ぶん必ず返る（空も含む）。
	var slots: Array = GameManager.get_equipment_slot_entries(character_id)
	var filled: int = 0
	for row: Variant in slots:
		if not ((row as Dictionary)[GameManager.SLOT_ENTRY_ENTRY] as Dictionary).is_empty():
			filled += 1
	print("  キャラの装備マス = %d 枠（5 が正解） / 埋まっている = %d 枠" % [slots.size(), filled])
	for row: Variant in slots:
		var entry: Dictionary = (row as Dictionary)[GameManager.SLOT_ENTRY_ENTRY]
		print("    %-10s %s" % [
			str((row as Dictionary)[GameManager.SLOT_ENTRY_EQUIP_SLOT]),
			"（空）" if entry.is_empty() else str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")),
		])

	# 外すと戻る。
	var unequipped: bool = GameManager.unequip_instance(character_id, GameStateKeys.EQUIP_HEAD)
	print("  外す -> %s / 持ち物 %d -> %d 件（⚠ 1 増えて元に戻るのが正解）" % [
		str(unequipped), after_equip, _inventory_entry_count()
	])
	if not unequipped or _inventory_entry_count() != before:
		push_error("[DebugBoot] 外しても持ち物に戻っていない")


# 拠点に容量が無いこと（⚠ 2026-10-03・回3-d・`BS-20`・`EXEC_BASE_NO_CAPACITY.md`）。
#
# ⚠ 前は「容量の口6本（満杯なら払う前に弾くか）」だった。⚠ 判定を消したので、⚠ どの口も**全部入る**のが正解。
func _report_inventory_no_capacity() -> void:
	print("[DebugBoot] --- 拠点に容量が無い（⚠ どの口も全部入るのが正解）---")
	# ① 直接入れる：⚠ 装備を 600 本（⚠ 前の上限 500 マスを超える）入れても全部個体になる。
	var instances_before: int = GameManager.get_owned_instances().size()
	var granted: int = GameManager.add_to_inventory("weapon_iron_sword", 600, GameStateKeys.ITEM_TYPE_EQUIPMENT)
	var instances_after: int = GameManager.get_owned_instances().size()
	print("  ① add_to_inventory（装備 600 本） -> %d 本入った ／ 個体 %d -> %d（+600 が正解）" % [
		granted, instances_before, instances_after
	])
	if granted != 600 or instances_after != instances_before + 600:
		push_error("[DebugBoot] 装備が全部入っていない（容量の判定が残っている疑い）")

	# ② 宝箱：⚠ 中身が持ち物でも開く（⚠ 前は満杯なら断っていた）。
	var opened: int = 0
	for _try: int in range(10):
		if not GameManager.grant_chest("floor_1_epic", "debug"):
			continue
		var probe: String = str(_last_unopened_chest().get(GameStateKeys.CHEST_INSTANCE_ID, ""))
		if GameManager.open_chest(probe):
			opened += 1
	print("  ② open_chest（epic を積めただけ） -> %d 個開いた（積めた数と同じが正解・断られない）" % opened)
	if GameManager.get_pending_chest_count() > 0 and opened == 0:
		push_error("[DebugBoot] 宝箱が開かない（容量の判定が残っている疑い）")

	# ③ ショップ：⚠ 品を買える（⚠ 前は満杯なら払う前に弾いた）。
	var gold_before: int = int(GameManager.get_state().get(GameStateKeys.GOLD, 0))
	GameManager.add_gold(999999)
	var bought: bool = false
	var line_up: Array = GameManager.get_shop_lineup(GameStateKeys.SHOP_TYPE_DAILY)
	for entry: Variant in line_up:
		var slot: Dictionary = entry
		if str(slot.get(GameManager.SHOP_SLOT_PAYOUT_TYPE, "")) == GameManager.PAYOUT_TYPE_MATERIAL:
			continue
		# ⚠ ノルマ札（上限がある）・金貨で買えない棚・売り切れは飛ばす（⚠ 容量と関係ない理由で断られる）。
		if str(slot.get(GameStateKeys.SHOP_ITEM_ID, "")) == GameStateKeys.ITEM_QUOTA_TICKET:
			continue
		if str((slot.get(GameStateKeys.SHOP_COST, {}) as Dictionary).get(GameStateKeys.COST_CURRENCY_TYPE, "")) != GameStateKeys.GOLD:
			continue
		if int(slot.get(GameStateKeys.SHOP_STOCK_LIMIT, 0)) > 0 \
				and int(slot.get(GameStateKeys.SHOP_PURCHASED_COUNT, 0)) >= int(slot.get(GameStateKeys.SHOP_STOCK_LIMIT, 0)):
			continue
		bought = GameManager.purchase_shop_item(
			GameStateKeys.SHOP_TYPE_DAILY, int(slot.get(GameStateKeys.SHOP_SLOT_ID, 0))
		)
		break
	print("  ③ purchase_shop_item -> %s（true が正解）" % str(bought))
	if not bought:
		push_error("[DebugBoot] ショップで品が買えない（容量の判定が残っている疑い）")
	GameManager.add_gold(gold_before - int(GameManager.get_state().get(GameStateKeys.GOLD, 0)))

	# ④ 作業場：受け取れる
	var recipes: Array = GameManager.get_available_recipes()
	var craft_started: bool = false
	if not recipes.is_empty():
		var recipe_id: String = str((recipes[0] as Dictionary).get(GameManager.RECIPE_ID, ""))
		for material_id: Variant in MasterDataLoader.get_all_items():
			GameManager.add_material(str(material_id), 9999)
		craft_started = GameManager.start_craft(recipe_id)
		_rewind_craft_queue()
		GameManager.refresh_crafting_queue_if_needed()
	var queue: Array = GameManager.get_state().get(GameStateKeys.CRAFTING_QUEUE, [])
	if craft_started and not queue.is_empty():
		var queue_id: String = str((queue[0] as Dictionary).get(GameStateKeys.CRAFT_QUEUE_ID, ""))
		var collected: bool = GameManager.collect_craft(queue_id)
		print("  ④ collect_craft -> %s（true が正解）" % str(collected))
		if not collected:
			push_error("[DebugBoot] 作業場で受け取れない（容量の判定が残っている疑い）")
	else:
		print("  ④ collect_craft … ⚠ キューを作れなかったので見られていない")

	# ⑤ ダンジョンの撤退：⚠ 全部持ち帰る（⚠ 「置いてきた」は無い）。
	if GameManager.is_in_dungeon():
		GameManager.abandon_dungeon_run()
	if GameManager.start_dungeon_run():
		var _got: int = GameManager.add_to_dungeon_bag("weapon_iron_sword", 2)
		var _got2: int = GameManager.add_to_dungeon_bag("construction_material_1", 3)
		_walk_dungeon_to_boss()
		var _cleared: bool = GameManager.clear_dungeon_boss()
		var report: Dictionary = GameManager.retreat_from_dungeon()
		print("  ⑤ retreat_from_dungeon -> 持ち帰った %s ／ 鍵 left_behind が無い=%s（true が正解）" % [
			str(report.get("granted", {})), str(not report.has("left_behind"))
		])
		if int((report.get("granted", {}) as Dictionary).get("weapon_iron_sword", 0)) != 2 or report.has("left_behind"):
			push_error("[DebugBoot] 撤退で装備が全部持ち帰れていない")

	print("  ⚠ 最後に 持ち物 %d 件" % _inventory_entry_count())


# ============================================================
# 難ダンジョン（段階17-a・PLAN_HARD_DUNGEON.md）
#
# ⚠ 戦闘を1回も回さない。ランの器を組んで歩けるかだけを見る。
# ⚠ シナリオ（_report_floor）とは器が別。⚠ ここが動いても scenario=floor と
#   scenario=economy の数字は1つも動かないのが正解。
# ============================================================

# 見た目の字がフォントに在るか（段階19-a）。
#
# ⚠⚠ 絵が出るかは人間しか見られない。⚠ ここで取れるのは「その字がフォントに在るか」だけ。
#   ⚠ 在らない字は豆腐（□）になる。⚠ NG が0件で正解。
# ⚠ 見るのは main_theme.tres の default_font（＝実際に画面が使うフォント）。
#   ⚠ .ttf を直接 load しないこと。⚠ fallback の設定が効いているかまで見たいので、
#     ⚠ テーマが持っている Font をそのまま聞く。
# ⚠⚠ Theme を組み立て直して、欠けが無いかを見る（2026-09-07・ボタンの4階層）。
#
# ⚠ 見た目の値を持つのは `tools/build_theme.gd` と `main_theme.tres` だけ。
#   ⚠ ここには色も寸法も書かない。⚠ 「在るか」しか見ない。
# ⚠ E140 = Theme に欠けがある（⚠ ボタンが素の見た目に落ちる）。
func _report_theme() -> void:
	print("[DebugBoot] --- Theme を組み立て直す（tools/build_theme.gd）---")
	# ⚠ 呼ぶのは `ThemeBuilder`（素のクラス）。⚠ `tools/build_theme.gd` は
	#   EditorScript で、⚠ エディタ以外では new できない（実測・2026-09-07）。
	ThemeBuilder.build()

	# ⚠ 書いた直後のものを読み直す（⚠ キャッシュを避ける）。
	var theme: Theme = ResourceLoader.load(THEME_PATH, "Theme", ResourceLoader.CACHE_MODE_IGNORE)
	if theme == null:
		push_error("[DebugBoot] E140 main_theme.tres を読めない")
		return

	var missing: Array[String] = []

	# ⚠ フォントが消えていないこと（⚠ 新規作成で上書きすると消える）。
	if theme.default_font == null:
		missing.append("default_font（⚠ 上書きで消えた恐れ）")
	else:
		print("  default_font = '%s' / 既定の大きさ = %d" % [
			theme.default_font.get_font_name(), theme.default_font_size,
		])

	# ⚠ 見出しの明朝（2026-09-26・`UI-12`）。⚠ フォントの名前だけ見る。
	if not theme.has_font(&"font", &"HeadingLabel"):
		missing.append("HeadingLabel に見出しのフォントが無い（⚠ 明朝が当たっていない）")
	else:
		var heading_font: Font = theme.get_font(&"font", &"HeadingLabel")
		print("  見出しのフォント = '%s'" % heading_font.get_font_name())
		if not heading_font.get_font_name().contains("Shippori"):
			missing.append("見出しのフォントが明朝ではない: " + heading_font.get_font_name())

	print("[DebugBoot] --- ボタン4階層 × 5状態（⚠ 欠けが0件で正解）---")
	for type_name: String in THEME_BUTTON_TYPES:
		var states: int = 0
		for state: String in THEME_BUTTON_STATES:
			if theme.has_stylebox(StringName(state), StringName(type_name)):
				states += 1
			else:
				missing.append("%s/styles/%s" % [type_name, state])
		var colors: int = 0
		for color_name: String in THEME_BUTTON_COLORS:
			if theme.has_color(StringName(color_name), StringName(type_name)):
				colors += 1
			else:
				missing.append("%s/colors/%s" % [type_name, color_name])
		print("  %-16s 状態 %d/%d ／ 色 %d/%d ／ 継承元 '%s'" % [
			type_name, states, THEME_BUTTON_STATES.size(),
			colors, THEME_BUTTON_COLORS.size(),
			str(theme.get_type_variation_base(StringName(type_name))),
		])

	print("[DebugBoot] --- 間隔・余白・見出し（⚠ 用途で名付けた variation）---")
	for type_name: String in THEME_CONSTANT_TYPES:
		if not theme.has_constant(&"separation", StringName(type_name)):
			missing.append("%s/constants/separation" % type_name)
			continue
		print("  %-16s separation = %d ／ 継承元 '%s'" % [
			type_name, theme.get_constant(&"separation", StringName(type_name)),
			str(theme.get_type_variation_base(StringName(type_name))),
		])
	for type_name: String in THEME_MARGIN_TYPES:
		if not theme.has_constant(&"margin_left", StringName(type_name)):
			missing.append("%s/constants/margin_left" % type_name)
			continue
		print("  %-16s 余白 左右 %d ／ 上下 %d" % [
			type_name,
			theme.get_constant(&"margin_left", StringName(type_name)),
			theme.get_constant(&"margin_top", StringName(type_name)),
		])
	for type_name: String in THEME_LABEL_TYPES:
		var has_size: bool = theme.has_font_size(&"font_size", StringName(type_name))
		var has_color: bool = theme.has_color(&"font_color", StringName(type_name))
		if not has_size and not has_color:
			missing.append("%s（大きさも色も無い）" % type_name)
			continue
		print("  %-16s 大きさ %s ／ 色 %s" % [
			type_name,
			str(theme.get_font_size(&"font_size", StringName(type_name))) if has_size else "—",
			str(theme.get_color(&"font_color", StringName(type_name))) if has_color else "—",
		])

	# ⚠⚠ 紙の上の字（2026-09-26・`UI-14`）。⚠ 紙の器に `paper_theme.tres` を持たせ、
	#   ⚠ 中の字が**実際に**墨を引くかを木に入れて聞く（⚠ `.tres` に在るかでは足りない＝探す順を見たい）。
	#   ⚠ 値は書かない。⚠ `ThemeBuilder` の定数と見比べる。
	print("[DebugBoot] --- 紙の上の字（⚠ 墨・薄墨になれば正解）---")
	var paper_theme: Theme = ResourceLoader.load(ThemeBuilder.PAPER_THEME_PATH, "Theme", ResourceLoader.CACHE_MODE_IGNORE)
	if paper_theme == null:
		missing.append("paper_theme.tres を読めない")
	else:
		var sheet: PanelContainer = PanelContainer.new()
		sheet.theme_type_variation = &"PaperPanel"
		sheet.theme = paper_theme
		var box: VBoxContainer = VBoxContainer.new()
		sheet.add_child(box)
		var checks: Dictionary = {
			"Label": ThemeBuilder.TOKEN_INK,
			"MutedLabel": ThemeBuilder.TOKEN_INK_SUB,
			"CaptionLabel": ThemeBuilder.TOKEN_INK_SUB,
			"AccentLabel": ThemeBuilder.TOKEN_BRASS_INK,
		}
		var probes: Dictionary = {}
		for variation: String in checks:
			var label: Label = Label.new()
			if variation != "Label":
				label.theme_type_variation = StringName(variation)
			box.add_child(label)
			probes[variation] = label
		# ⚠ 紙の外の字（⚠ 暗い地のまま＝墨になっていてはいけない）。
		var outside: Label = Label.new()
		add_child(sheet)
		add_child(outside)
		for variation: String in checks:
			var got: Color = (probes[variation] as Label).get_theme_color(&"font_color")
			var want: Color = Color.html(str(checks[variation]))
			print("  紙の上 %-14s = %s（期待 %s）" % [variation, got.to_html(false), want.to_html(false)])
			if not got.is_equal_approx(want):
				missing.append("紙の上の %s が %s（⚠ 墨になっていない）" % [variation, got.to_html(false)])
		var outside_color: Color = outside.get_theme_color(&"font_color")
		print("  紙の外 Label          = %s（期待 %s）" % [outside_color.to_html(false), ThemeBuilder.TOKEN_TEXT_ON_DARK])
		if not outside_color.is_equal_approx(Color.html(ThemeBuilder.TOKEN_TEXT_ON_DARK)):
			missing.append("紙の外の Label が %s（⚠ 暗い地の字になっていない）" % outside_color.to_html(false))
		var paper_box: StyleBox = sheet.get_theme_stylebox(&"panel")
		if not (paper_box is StyleBoxFlat) or not (paper_box as StyleBoxFlat).bg_color.is_equal_approx(Color.html(ThemeBuilder.TOKEN_PAPER)):
			missing.append("PaperPanel の地が羊皮紙になっていない")
		remove_child(sheet)
		sheet.queue_free()
		remove_child(outside)
		outside.queue_free()

	print("[DebugBoot] 欠け = %d 件（0 が正解）" % missing.size())
	for entry: String in missing:
		push_error("[DebugBoot] E140 Theme に欠けがある: " + entry)

	_report_all_scenes_load()
	_report_modal_window()


# ⚠⚠ ウィンドウ形式のモーダル（2026-09-08・段階⑤-③・台帳の決定39）。
#
# ⚠ 見た目は取れない。⚠ ここで見るのは「⚠ 見出し・中身・ボタンの文言が入ったか」だけ。
# ⚠ 押して出すことはできない（⚠ ヘッドレスにマウスが無い）ので、⚠ `setup()` を直接呼ぶ。
# ⚠ `Modal` を通さないのは、⚠ あちらが `current_scene` に足す作りで、
#   ⚠ ここでは現在のシーンが自分（DebugBoot）だから。⚠ 出す口の検証ではなく器の検証。
func _report_modal_window() -> void:
	print("[DebugBoot] --- ウィンドウ形式のモーダル（⚠ 見出し・中身・ボタンの文言）---")
	var scene: PackedScene = load(MODAL_SCENE_PATH)
	if scene == null:
		push_error("[DebugBoot] E140 modal_dialog.tscn を読めない")
		return
	var dialog: ModalDialog = scene.instantiate()
	add_child(dialog)

	var content: Label = Label.new()
	content.name = "ProbeContent"
	content.text = "中身"
	dialog.setup("", false, false, {
		Modal.OPTION_TITLE: "でんせつの宝箱",
		Modal.OPTION_CONTENT: content,
		Modal.OPTION_CLOSE_LABEL: "ui_warehouse_receive",
	})
	print("  見出し = '%s'（出るか=%s）" % [dialog.title_label.text, str(dialog.title_bar.visible)])
	print("  中身の器 = %s ／ 中の数 = %d" % [
		str(dialog.content_box.visible), dialog.content_box.get_child_count()
	])
	print("  閉じるボタン = '%s'（⚠ 「受け取る」が正解）" % dialog.close_button.text)
	print("  本文 = '%s'（⚠ 空なら行ごと消えるのが正解 / 出るか=%s）" % [
		dialog.message_label.text, str(dialog.message_label.visible)
	])
	if dialog.title_label.text == "" or not dialog.content_box.visible:
		push_error("[DebugBoot] E140 ウィンドウ形式の見出しか中身が入っていない")
	dialog.free()

	_report_modal_knobs(scene)


# ⚠⚠ 窓のつまみ（2026-09-21・決定 `MD-1`〜`MD-9`）。
#
# ⚠ 見るのは「⚠ 渡した指定が値になって出てくるか」だけ。⚠ 見え方は人間と絵が見る。
# ⚠ 幅は Theme が持つので、⚠ ここに 300 / 400 / 560 / 720 と書かない（⚠ 引き直して比べる）。
func _report_modal_knobs(scene: PackedScene) -> void:
	print("[DebugBoot] --- 窓のつまみ（MD-1〜MD-9）---")

	# --- 幅の3段階（MD-3）---
	var want: Dictionary = {
		ModalDialog.WIDTH_TINY: &"width_tiny",
		ModalDialog.WIDTH_SMALL: &"width_small",
		ModalDialog.WIDTH_MEDIUM: &"width_medium",
		ModalDialog.WIDTH_LARGE: &"width_large",
	}
	for size_name: String in want.keys():
		var d: ModalDialog = scene.instantiate()
		add_child(d)
		d.setup("あ", false, false, {Modal.OPTION_WIDTH: size_name})
		var got: float = d.panel.custom_minimum_size.x
		var expected: float = float(d.panel.get_theme_constant(want[size_name], &"Window"))
		print("  幅 %-6s = %.0f（Theme %.0f）" % [size_name, got, expected])
		if not is_equal_approx(got, expected):
			push_error("[DebugBoot] E141 窓の幅が Theme と合わない: " + size_name)
		d.free()

	# --- 暗幕の3通り（MD-6）---
	var dims: Dictionary = {
		ModalDialog.DIM_NONE: &"dim_none_pct",
		ModalDialog.DIM_NORMAL: &"dim_normal_pct",
		ModalDialog.DIM_HEAVY: &"dim_heavy_pct",
	}
	for dim_name: String in dims.keys():
		var d2: ModalDialog = scene.instantiate()
		add_child(d2)
		d2.setup("あ", false, false, {Modal.OPTION_DIM: dim_name})
		var alpha: float = d2.dimmer.color.a
		var want_pct: float = float(d2.dimmer.get_theme_constant(dims[dim_name], &"Window"))
		# ⚠⚠ 暗幕が無くても後ろは押せない（⚠ 受け止めるのは Blocker）。⚠ ここが崩れたら赤。
		var blocks: bool = d2.blocker.mouse_filter == Control.MOUSE_FILTER_STOP
		print("  暗幕 %-6s = %.0f%%（Theme %.0f%%） ／ 後ろを止めるか=%s" % [
			dim_name, alpha * 100.0, want_pct, str(blocks)
		])
		if not is_equal_approx(alpha * 100.0, want_pct) or not blocks:
			push_error("[DebugBoot] E142 暗幕の濃さか、後ろを止める作りが合わない: " + dim_name)
		d2.free()

	# --- はいが左・実行を赤（MD-4 / MD-5）---
	var d3: ModalDialog = scene.instantiate()
	add_child(d3)
	d3.setup("消しますか？", true, false, {
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_part_dismantle",
	})
	var row: Node = d3.confirm_button.get_parent()
	var yes_first: bool = row.get_child(0) == d3.confirm_button
	print("  はいが左か=%s ／ 実行の階層=%d（%d が赤） ／ 文言='%s'" % [
		str(yes_first), d3.confirm_button.variant, UiButton.Variant.DANGER, d3.confirm_button.text
	])
	if not yes_first or d3.confirm_button.variant != UiButton.Variant.DANGER:
		push_error("[DebugBoot] E143 はいが左でないか、実行が赤になっていない")
	d3.free()

	# --- 帯は任意（MD-1）---
	var d4: ModalDialog = scene.instantiate()
	add_child(d4)
	d4.setup("題のない窓", false, false, {})
	print("  題を渡さないとき 帯が出るか=%s（false が正解＝MD-1）" % str(d4.title_bar.visible))
	if d4.title_bar.visible:
		push_error("[DebugBoot] E144 題を渡していないのに帯が出ている")
	d4.free()

	# --- 続けて出るときの間（MD-8）---
	# ⚠ 窓自身に聞く（⚠ 画面のルートが Control でないと引けない書き方をしない）。
	var d5: ModalDialog = scene.instantiate()
	add_child(d5)
	var gap: int = d5.queue_gap_ms()
	print("  窓が続くときの間 = %d ms（⚠ 0 だと中身だけ替わって見える）" % gap)
	if gap <= 0:
		push_error("[DebugBoot] E145 窓が続くときの間が 0（MD-8 が効かない）")
	d5.free()

	# --- 長押し（MD-11）---
	# ⚠ 押すのは本番と同じ口（`button_down` / `button_up` がつながる先）。⚠ 時間は `_process()` に直に渡して進める。
	var d6: ModalDialog = scene.instantiate()
	add_child(d6)
	d6.setup("消しますか？", true, false, {
		Modal.OPTION_DANGER: true,
		Modal.OPTION_HOLD: "ui_title_delete_hold_hint",
	})
	var results: Array = []
	d6.closed.connect(func(r: bool) -> void: results.append(r))
	var hold_ms: float = float(d6.panel.get_theme_constant(&"confirm_hold_ms", &"Window"))
	d6.confirm_button.pressed.emit()
	var closed_by_click: bool = not results.is_empty()
	d6.confirm_button.button_down.emit()
	d6._process(hold_ms * 0.5 / 1000.0)
	d6.confirm_button.button_up.emit()
	d6._process(hold_ms / 1000.0)
	var closed_by_short: bool = not results.is_empty()
	d6.confirm_button.button_down.emit()
	d6._process(hold_ms * 1.05 / 1000.0)
	var closed_by_hold: bool = results.size() == 1 and bool(results[0])
	print("  長押し %.0f ms ／ 押しただけで閉じたか=%s ／ 途中で離して閉じたか=%s ／ 押しつづけて「はい」で閉じたか=%s" % [
		hold_ms, str(closed_by_click), str(closed_by_short), str(closed_by_hold)
	])
	if hold_ms <= 0.0 or closed_by_click or closed_by_short or not closed_by_hold:
		push_error("[DebugBoot] E148 長押しの窓の決まり方が合わない（MD-11）")
	d6.free()


# ⚠ 全シーンが読めるか（2026-09-07・ボタンの差し替えで 22 枚の ext_resource を書き換えたため）。
#
# ⚠ 読むだけ＝`instantiate()` しない。⚠ 画面によっては `_ready()` が別画面へ飛ばすため。
#   ⚠ ここで見たいのは「参照先（path / uid）が壊れていないか」の1点だけ。
# ⚠ `LAYOUT_SCENES` に入っていない5枚（タイトル・拠点・ポモドーロ・ステータスのノード・戦闘）も通る。
func _report_all_scenes_load() -> void:
	var paths: Array[String] = []
	_collect_scenes("res://scenes", paths)
	_collect_scenes("res://tests", paths)
	paths.sort()
	var failed: Array[String] = []
	for path: String in paths:
		if load(path) == null:
			failed.append(path)
	print("[DebugBoot] --- 全シーンが読めるか ---")
	print("  読んだ = %d 枚 ／ 読めなかった = %d 枚（0 が正解）" % [paths.size(), failed.size()])
	for path: String in failed:
		push_error("[DebugBoot] E140 シーンを読めない: " + path)


func _collect_scenes(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_scenes(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


# ⚠⚠ これから使おうとしている絵文字の下見（2026-09-08）。
#
# ⚠ フォントは 1,274 字しか無い。⚠ 「思いついた絵文字が在るとは限らない」。
#   ⚠ `Glyphs` に入れてから NG に気づくと、⚠ 入れ直しで往復が1回増える。
# ⚠ ここに候補を並べて先に見る。⚠ 使うと決めたものだけ `Glyphs` の定数にする。
# ⚠ 赤も黄も出さない（⚠ 候補であって、⚠ 使っているものではない）。
const GLYPH_CANDIDATES: Array[String] = [
	"❤", "💗", "💖", "💓",
	"👊", "✊", "💢", "🔥", "⚡", "🗯",
	"✨", "🌟", "💫", "🌙", "☄",
	"🚧", "🔰", "🧊", "🏰", "🚪", "⛰",
	"🔯", "🌀", "☯", "🕉", "🧿",
	"💨", "🌬", "⏩", "⏪",
	"⏱", "⏳", "⌛", "🕐", "⏰",
	"🎯", "🔍", "👁", "☘", "🍀",
	"💥", "💣", "🌋", "⭐",
	"👟", "🏃", "🐇", "✈", "🛴",
]


func _report_glyphs() -> void:
	var theme: Theme = load("res://theme/main_theme.tres")
	if theme == null:
		push_error("[DebugBoot] main_theme.tres を読めない")
		return
	var font: Font = theme.default_font
	if font == null:
		push_error("[DebugBoot] main_theme.tres の default_font が空")
		return

	print("[DebugBoot] --- フォント（⚠ 画面が実際に使うもの）---")
	print("  名前 = '%s' / fallback = %d 本" % [font.get_font_name(), (font.fallbacks as Array).size()])
	for fallback: Variant in (font.fallbacks as Array):
		if fallback is Font:
			print("    fallback: '%s'" % (fallback as Font).get_font_name())
	if (font.fallbacks as Array).is_empty():
		push_warning("[DebugBoot] W32 fallback が0本。絵文字フォントが繋がっていない（NotoSansJP-VariableFont_wght.ttf.import の fallbacks）")

	# ⚠ 候補の下見。⚠ 使うと決める前にここで見る（⚠ 入れてから直すと往復が増える）。
	print("[DebugBoot] --- 候補の下見（⚠ まだ使っていない字。⚠ NG でも赤は出さない）---")
	var candidate_ok: Array[String] = []
	for candidate: String in GLYPH_CANDIDATES:
		var ok: bool = true
		for i: int in range(candidate.length()):
			var code: int = candidate.unicode_at(i)
			if code >= 0xFE00 and code <= 0xFE0F:
				continue
			if not font.has_char(code):
				ok = false
		if ok:
			candidate_ok.append(candidate)
	print("  在る = %d / %d 件" % [candidate_ok.size(), GLYPH_CANDIDATES.size()])
	print("  在る: %s" % " ".join(candidate_ok))
	var candidate_ng: Array[String] = []
	for candidate: String in GLYPH_CANDIDATES:
		if not (candidate in candidate_ok):
			candidate_ng.append(candidate)
	print("  無い: %s" % " ".join(candidate_ng))

	# ⚠⚠ 線画（SVG）が全部読めるか（2026-09-08）。⚠ 絵は見えないので「在るか」と「大きさ」だけ。
	#   ⚠ 1枚でも読めないと、⚠ その種類だけ黙って絵文字に落ちる（⚠ 気づけない）。
	print("[DebugBoot] --- 線画（SVG）が読めるか（⚠ 読めない = 0 件が正解）---")
	var textures: Dictionary = IconTextures.all_for_check()
	var missing_icons: Array[String] = []
	var sizes: Dictionary = {}
	for name: Variant in textures:
		var texture: Variant = textures[name]
		if texture == null:
			missing_icons.append(str(name))
			continue
		var size: Vector2i = (texture as Texture2D).get_size()
		sizes[str(size.x) + "x" + str(size.y)] = int(sizes.get(str(size.x) + "x" + str(size.y), 0)) + 1
	print("  読めた = %d 枚 ／ 読めない = %d 枚" % [
		textures.size() - missing_icons.size(), missing_icons.size()
	])
	print("  大きさの内訳 = %s（⚠ SVG は viewBox × svg/scale でラスタライズされる）" % str(sizes))
	for name: String in missing_icons:
		push_error("[DebugBoot] E140 線画を読めない: " + name)

	# ⚠ Glyphs の表を全部見る。⚠ 1つでも NG なら豆腐が出る。
	print("[DebugBoot] --- Glyphs の字がフォントに在るか（⚠ NG が0件で正解）---")
	var table: Dictionary = Glyphs.all_for_check()
	var names: Array = table.keys()
	names.sort()
	var ng: Array[String] = []
	for entry: Variant in names:
		var glyph_name: String = str(entry)
		var glyph: String = str(table[glyph_name])
		# ⚠ 1文字とは限らない（⚠ 異体字セレクタや ZWJ が付く絵文字がある）。
		#   ⚠ 全ての符号位置が在ることを見る。
		var missing: Array[String] = []
		for i: int in range(glyph.length()):
			var code: int = glyph.unicode_at(i)
			# ⚠ 異体字セレクタ（U+FE0F など）はどのフォントにも無いことがあるが、
			#   ⚠ 絵は出る。⚠ 数えない。
			if code >= 0xFE00 and code <= 0xFE0F:
				continue
			if not font.has_char(code):
				missing.append("U+%05X" % code)
		if missing.is_empty():
			print("  OK  %-26s %s" % [glyph_name, glyph])
		else:
			print("  NG  %-26s %s  無い符号位置 = %s" % [glyph_name, glyph, str(missing)])
			ng.append(glyph_name)
	print("  表の件数 = %d / NG = %d 件（⚠ 定数を足したら件数が増えるのが正解）" % [
		table.size(), ng.size()
	])
	if not ng.is_empty():
		push_error("[DebugBoot] E138 glyphs.gd: フォントに無い字がある（画面で豆腐になる）: " + str(ng))

	# ⚠ 実際の引き方も通す（⚠ 表に在ることと、⚠ 口が正しく引くことは別）。
	print("[DebugBoot] --- 引き口（⚠ 分岐が1箇所であることの確認）---")
	var character_ids: Array = MasterDataLoader.get_all_characters().keys()
	character_ids.sort()
	for character_id: Variant in character_ids:
		print("  キャラ %-20s %s" % [str(character_id), Glyphs.for_character(str(character_id))])
	# ⚠ 敵は一覧の口が無いので名指しで並べる（⚠ 口を新しく作らない＝ここは検証の道具）。
	for enemy_id: String in ["enemy_slime", "enemy_wolf", "boss_slime_king", "enemy_dbg_react"]:
		print("  敵    %-20s %s" % [enemy_id, Glyphs.for_enemy(enemy_id)])
	var samples: Array[String] = [
		"weapon_iron_sword", "armor_iron_helm", "part_gem_atk_1", "part_charm_def_1",
		"part_emblem_crit_rate_1", "part_rune_buff_1", "construction_material_1",
		"stamina_potion", "dungeon_potion_heal", "dungeon_potion_revive", "not_an_item",
	]
	for item_id: String in samples:
		print("  品    %-26s %s" % [item_id, Glyphs.for_item(item_id)])
	for kind: String in [
		GameStateKeys.DUNGEON_NODE_KIND_BATTLE, GameStateKeys.DUNGEON_NODE_KIND_RELIC,
		GameStateKeys.DUNGEON_NODE_KIND_REST, GameStateKeys.DUNGEON_NODE_KIND_CHEST,
		GameStateKeys.DUNGEON_NODE_KIND_BOSS, "",
	]:
		print("  マス  %-20s %s" % [kind if kind != "" else "(知らない種類)", Glyphs.for_dungeon_node(kind)])
	# ⚠ シナリオのマス（2026-09-19）。⚠ ショップだけシナリオにしか無い。
	for kind: String in [
		GameStateKeys.FLOOR_NODE_KIND_BATTLE, GameStateKeys.FLOOR_NODE_KIND_SHOP,
		GameStateKeys.FLOOR_NODE_KIND_RELIC, GameStateKeys.FLOOR_NODE_KIND_REST,
		GameStateKeys.FLOOR_NODE_KIND_BOSS, "",
	]:
		print("  フロア %-19s %s" % [kind if kind != "" else "(知らない種類)", Glyphs.for_floor_node(kind)])


func _report_dungeon() -> void:
	var dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()

	# --- 1. dungeon.json の一覧 ---
	print("[DebugBoot] --- ダンジョンの一覧（⚠ 1 本が正解）---")
	print("  実際 = %d 本" % dungeon_ids.size())
	for dungeon_id: String in dungeon_ids:
		var dungeon: Dictionary = MasterDataLoader.get_dungeon(dungeon_id)
		var layers: Array = dungeon.get(GameManager.DUNGEON_MASTER_LAYERS, [])
		var counts: Array[String] = []
		var sum_nodes: int = 0
		for layer: Variant in layers:
			var n: int = int((layer as Dictionary).get(GameManager.DUNGEON_LAYER_NODE_COUNT, 0))
			counts.append(str(n))
			sum_nodes += n
		print("  %-14s 層=%d 各層=[%s] 生成ノード=%d（+ボス1 = %d）" % [
			dungeon_id, layers.size(), ", ".join(counts), sum_nodes, sum_nodes + 1,
		])

	if dungeon_ids.is_empty():
		push_error("[DebugBoot] ダンジョンが1本も無いので以降を回せない")
		return
	var target_id: String = dungeon_ids[0]
	# ⚠ 層数は dungeon.json から引く。⚠ 6 を書かないこと（段階19-d で 8 になった）。
	var layer_total: int = (
		MasterDataLoader.get_dungeon(target_id).get(GameManager.DUNGEON_MASTER_LAYERS, []) as Array
	).size()

	# --- 2. 層のノード出現比（DungeonConfig）---
	print("[DebugBoot] --- 層のノード出現比（⚠ shop が1件も無いのが正解＝ショップはボスの先だけ）---")
	for layer: int in range(1, layer_total + 1):
		print("  層%d %s" % [layer, str(GameManager.get_dungeon_layer_weights(layer))])

	# --- 3. ランに入る ---
	print("[DebugBoot] --- %s に入る ---" % target_id)
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] start_dungeon_run が false: " + target_id)
		return
	# ⚠ 素の MAX HP を控えておく（§4-4 の一番の落とし穴。ここが動いたら赤）。
	var base_max_hp_before: Dictionary = {}
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		base_max_hp_before[character_id] = int(
			GameManager.get_effective_stats(character_id).get(GameStateKeys.STAT_HP, 0)
		)
	print("  ランのMAX HP = %s ／ 素のMAX HP = %s（同じ値で始まるのが正解）" % [
		str(GameManager.get_dungeon_max_hp()), str(base_max_hp_before)
	])
	print("  鞄 = %d/%d（0/8 が正解＝空で始まる） ／ 一時通貨 = %d（0 が正解）" % [
		GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots(),
		GameManager.get_dungeon_currency(),
	])
	print("  フロア = %d（1 が正解） ／ phase = '%s'（map が正解）" % [
		GameManager.get_dungeon_floor_index(), GameManager.get_dungeon_phase()
	])

	var run: Dictionary = GameManager.get_dungeon_run()
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	var entry_id: String = str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, ""))

	# --- 4. ノード種の内訳 ---
	var kind_count: Dictionary = {}
	for node_id: Variant in nodes:
		var kind: String = str((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_KIND, ""))
		kind_count[kind] = int(kind_count.get(kind, 0)) + 1
	var kinds: Array = kind_count.keys()
	kinds.sort()
	var kind_parts: Array[String] = []
	for kind: Variant in kinds:
		kind_parts.append("%s=%d" % [str(kind), int(kind_count[kind])])
	print("  ノード %d 件 / %s" % [nodes.size(), " ".join(kind_parts)])

	# --- 4-B. 通路の形（段階19-c-1。⚠ 器だけ入れ替えた回）---
	#
	# ⚠⚠ ここが崩れると総当たりが「黙って通る」形で壊れる（⚠ ルート数が1本になる等）。
	#   ⚠ 全ルート総当たりの前に、⚠ 形そのものを見ておく。
	# ⚠ 19-c-1 の時点では effect は全部 ""（⚠ 中身は 19-c-2）。
	var edge_total: int = 0
	var edge_bad: int = 0
	var edge_with_effect: int = 0
	for node_id: Variant in nodes:
		var raw_next: Variant = (nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_NEXT, [])
		for raw_edge: Variant in (raw_next as Array):
			edge_total += 1
			if not (raw_edge is Dictionary):
				edge_bad += 1
				continue
			var edge: Dictionary = raw_edge
			# ⚠ 行き先が実在するか（⚠ 綴り違いは「進める先が消える」形で出る）。
			if not nodes.has(str(edge.get(GameStateKeys.DUNGEON_EDGE_TO, ""))):
				edge_bad += 1
				continue
			if str(edge.get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")) != "":
				edge_with_effect += 1
	print("  通路 = %d 本 / ⚠ 形が違う・行き先が無い = %d 本（0 が正解） / 効果つき = %d 本（⚠ 5本に1本＝2割ぐらいが正解）" % [
		edge_total, edge_bad, edge_with_effect
	])
	if edge_bad > 0:
		push_error("[DebugBoot] 通路が {to, effect} になっていないか、行き先が実在しない")
	if edge_with_effect <= 0:
		push_error("[DebugBoot] 効果つきの通路が0本（段階19-c-2 が効いていない）")
	# ⚠ 効果の内訳（⚠ 5種とも出るかは抽選なので毎回は揃わない。⚠ 綴りだけ見る）。
	var effect_count: Dictionary = {}
	for node_id: Variant in nodes:
		for raw_edge: Variant in ((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_NEXT, []) as Array):
			if not (raw_edge is Dictionary):
				continue
			var eff: String = str((raw_edge as Dictionary).get(GameStateKeys.DUNGEON_EDGE_EFFECT, ""))
			if eff == "":
				continue
			effect_count[eff] = int(effect_count.get(eff, 0)) + 1
			if not (eff in GameManager.DUNGEON_EDGE_EFFECTS_KNOWN):
				push_error("[DebugBoot] 知らない通路の効果: " + eff)
	var effect_names: Array = effect_count.keys()
	effect_names.sort()
	var effect_parts: Array[String] = []
	for eff_name: Variant in effect_names:
		effect_parts.append("%s=%d" % [str(eff_name), int(effect_count[eff_name])])
	print("    効果の内訳 = %s" % (" ".join(effect_parts) if not effect_parts.is_empty() else "（無し）"))
	# ⚠ 1マスから出る通路の本数（段階19-f・人間の指摘「入り組ませないでほしい」）。
	#   ⚠ 上限は DungeonConfig.max_edges_per_node。⚠ ただし到達性のほうが優先なので、
	#     ⚠ 「入ってくる線が0本のマス」を補うぶんだけ上限を超えることがある。
	var out_count: Dictionary = {}
	var out_max: int = 0
	for node_id: Variant in nodes:
		var out_edges: int = ((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_NEXT, []) as Array).size()
		out_count[out_edges] = int(out_count.get(out_edges, 0)) + 1
		out_max = maxi(out_max, out_edges)
	var out_keys: Array = out_count.keys()
	out_keys.sort()
	var out_parts: Array[String] = []
	for out_key: Variant in out_keys:
		out_parts.append("%d本=%dマス" % [int(out_key), int(out_count[out_key])])
	print("    1マスから出る通路 = %s ／ 最大 %d 本（⚠ 上限 %d。⚠ 区画の入口は %d 本まで／到達性の補正でも超える）" % [
		" ".join(out_parts), out_max,
		int(Balance.dungeon.max_edges_per_node), int(Balance.dungeon.segment_choices),
	])
	# ⚠ 口が2本とも同じものを見ているか（⚠ get_dungeon_moves は ID だけを返す）。
	var here_now: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var moves_now: Array = GameManager.get_dungeon_moves()
	var edges_now: Array = GameManager.get_dungeon_edges(here_now)
	print("  入口の進める先 = %s ／ 通路 = %d 本（同じ数が正解）" % [str(moves_now), edges_now.size()])
	if moves_now.size() != edges_now.size():
		push_error("[DebugBoot] get_dungeon_moves() と get_dungeon_edges() の数が違う")
	if not moves_now.is_empty():
		var probe: Dictionary = GameManager.get_dungeon_edge(here_now, str(moves_now[0]))
		print("    1本引く get_dungeon_edge('%s','%s') = %s（空でないのが正解）" % [
			here_now, str(moves_now[0]), str(probe)
		])
		if probe.is_empty():
			push_error("[DebugBoot] get_dungeon_edge が進める先の通路を返さない")
		# ⚠ 無い通路を聞いたら空（⚠ 黙って先頭を返さないこと）。
		if not GameManager.get_dungeon_edge(here_now, "d_not_a_node").is_empty():
			push_error("[DebugBoot] 無い通路を聞いたのに空が返らない")

	# --- 4-C. 区画（合流しないエリア。段階20-b・人間の決定28）---
	#
	# ⚠⚠ 見るのは「区画と区画のあいだに通路が1本も無いこと」。
	#   ⚠ 区画の中では合流してよい（⚠ 外の台帳 §3-2 の図がそう）。
	# ⚠ 区画の判定を道具側で書き直さない。⚠ 「層の中で、⚠ どのノードから
	#   どのノードへ行けるか」の形だけを見る（⚠ 到達できるノードの集合で分かる）。
	print("[DebugBoot] --- 区画（⚠ 区画と区画のあいだは合流しない）---")
	# ⚠ 層ごとのノード数を出す（⚠ 区画帯の端は 3。⚠ 中は区画ごとに 1 か 2 なので 3〜6 で揺れる）。
	var count_by_layer: Dictionary = {}
	for node_id: Variant in nodes:
		var layer_no: int = int((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_LAYER, 0))
		count_by_layer[layer_no] = int(count_by_layer.get(layer_no, 0)) + 1
	var layer_nos: Array = count_by_layer.keys()
	layer_nos.sort()
	var shape: Array[String] = []
	for layer_no: Variant in layer_nos:
		shape.append(str(int(count_by_layer[layer_no])))
	print("  層ごとのノード数 = [%s]" % ", ".join(shape))
	# ⚠⚠ 区画の外へ漏れていないか：⚠ 「同じ層の2ノードから、⚠ 同じ行き先へ入っている」
	#   ことは合流。⚠ 区画帯の中で合流が起きても良い（中は合流してよい）が、
	#   ⚠ 別の区画のノードと混ざっていないかは「入ってくる元の集合」で分かる。
	#   ⚠ ここでは「1ノードから出る先が全部同じ層か」だけを見る（⚠ 層飛びが無いこと）。
	var layer_jump: int = 0
	for node_id: Variant in nodes:
		var from_layer: int = int((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_LAYER, 0))
		for to_id: String in _dungeon_edge_targets(nodes, str(node_id)):
			var to_layer: int = int((nodes[to_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_LAYER, 0))
			if to_layer != from_layer + 1:
				layer_jump += 1
	print("  ⚠ 層を飛ばす通路 = %d 本（0 が正解）" % layer_jump)
	if layer_jump > 0:
		push_error("[DebugBoot] 層を飛ばす通路がある（区画の組み方が壊れている）")

	# ⚠⚠ 左へ行く通路があるか（段階20-i・人間の指摘「左上のノードにいく生成がない」）。
	#   ⚠ ノードIDの末尾が「その層の何番目か」。⚠ 行き先の番号が小さければ左へ行く道。
	#   ⚠ 0 本だとマップが右へ流れるだけになり、⚠ 左のマスへ入る線が無くなる。
	var to_left: int = 0
	var to_right: int = 0
	var straight: int = 0
	for node_id: Variant in nodes:
		var from_index: int = int(str(node_id).get_slice("_", 2)) if str(node_id) != "d_boss" else 0
		for to_id: String in _dungeon_edge_targets(nodes, str(node_id)):
			if to_id == "d_boss":
				continue
			var to_index: int = int(to_id.get_slice("_", 2))
			if to_index < from_index:
				to_left += 1
			elif to_index > from_index:
				to_right += 1
			else:
				straight += 1
	print("  ⚠⚠ 通路の向き = 左へ %d 本 ／ 真下 %d 本 ／ 右へ %d 本（⚠ 左が 0 本だと右へ流れるだけになる）" % [
		to_left, straight, to_right
	])
	if to_left <= 0:
		push_error("[DebugBoot] 左へ行く通路が0本（マップが右へ流れるだけになっている）")

	# ⚠⚠ 分離しているか：⚠ 層のノードを「行き先を共有するか」でグループに分ける。
	#   ⚠ 通常の層は合流するので1グループ。⚠ 区画の入口層だけ 区画の数 に分かれる。
	#   ⚠ これが「区画と区画のあいだは合流しない」の直接の根拠。
	var split_layers: Array[String] = []
	for layer_no: Variant in layer_nos:
		var row: Array[String] = []
		for node_id: Variant in nodes:
			if int((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_LAYER, 0)) == int(layer_no):
				row.append(str(node_id))
		if row.size() < 2:
			continue
		var groups: int = _count_dungeon_next_groups(nodes, row)
		if groups >= 2:
			split_layers.append("層%d=%dグループ" % [int(layer_no), groups])
	print("  ⚠⚠ 行き先が分かれている層 = %s（⚠ 区画の入口が %d 個ぶん出るのが正解）" % [
		" ".join(split_layers) if not split_layers.is_empty() else "（無し）",
		int(Balance.dungeon.segment_count),
	])
	if split_layers.size() < int(Balance.dungeon.segment_count):
		push_error("[DebugBoot] 区画の分離が足りない（区画と区画のあいだで合流している）")

	# ⚠⚠ 区画ごとに分岐の長さが違うか（2026-09-20・2回目・人間が実機で見つけた直し）。
	#   ⚠ 3つの区画は**横に並んでいる**ので、⚠ 帯に1回だけ振ると層のノード数が
	#     ⚠ 区画の数で必ず割り切れる（⚠ 3・6・6 のように）。⚠ 区画ごとに振ると割り切れない層が出る。
	#   ⚠ 数は上の「層ごとのノード数」がもう出している。⚠ ここは割り切れない層を数えるだけ。
	var seg_total: int = maxi(1, int(Balance.dungeon.segment_count))
	var uneven: int = 0
	for raw_layer: Variant in count_by_layer:
		var at_layer: int = int(count_by_layer[raw_layer])
		if at_layer > seg_total and (at_layer % seg_total) != 0:
			uneven += 1
	print("  ⚠ 区画の数で割り切れない層 = %d 件（⚠ 0 が続くなら3つの区画が同じ形の疑い）" % uneven)

	# ⚠⚠ 一本しかない道に罠が付いていないか（2026-09-20・人間の指示
	#   「⚠ 一本しかない道に罠を作らないように」）。⚠ 選んでいない道の減点は避けようが無い。
	# ⚠ 得（宝箱・資源）は一本道でも付いてよい。⚠ 数えるのは罠だけ。
	var lone_traps: Array[String] = []
	var lone_gains: int = 0
	for raw_node: Variant in nodes:
		var next_list: Array = (nodes[raw_node] as Dictionary).get(GameStateKeys.DUNGEON_NODE_NEXT, [])
		if next_list.size() != 1:
			continue
		var effect: String = str((next_list[0] as Dictionary).get(GameStateKeys.DUNGEON_EDGE_EFFECT, ""))
		if effect == "":
			continue
		if effect in [
			GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP,
			GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_CURRENCY,
		]:
			lone_traps.append("%s->%s(%s)" % [
				str(raw_node), str((next_list[0] as Dictionary).get(GameStateKeys.DUNGEON_EDGE_TO, "")), effect
			])
		else:
			lone_gains += 1
	lone_traps.sort()
	print("  ⚠ 一本しかない道に付いた罠 = %d 件%s（0 が正解）／ ⚠ 得は %d 件（0 でなくてよい）" % [
		lone_traps.size(), "" if lone_traps.is_empty() else " " + str(lone_traps), lone_gains,
	])
	if not lone_traps.is_empty():
		push_error("[DebugBoot] 一本しかない道に罠が付いている（避けようが無い減点）")

	# --- 5. 全ルート（⚠ 数えるだけ。⚠ 1本ずつ歩かない）---
	#
	# ⚠⚠ 段階20-a で「1本ずつ歩いて列挙する」のをやめた。⚠ 1階が 8層 → 25層 になり、
	#   ⚠ 列挙の本数が指数で増えて終わらなくなるため（⚠ 8層で181本 → 25層では天文学的）。
	#   ⚠ 数だけなら DAG の動的計画法で数えられる（⚠ ノードの数に比例）。
	# ⚠ 「通れないノード」と「行き止まり」は幅優先で見る。⚠ どちらも列挙は要らない。
	var route_report: Dictionary = _count_dungeon_routes(nodes, entry_id)
	print("  全ルート = %d 本 / ⚠ ボスに着かない行き止まり = %d 件（0 が正解）" % [
		int(route_report["routes"]), (route_report["dead_ends"] as Array).size()
	])
	if not (route_report["dead_ends"] as Array).is_empty():
		push_error("[DebugBoot] ボスに着かない行き止まりがある: " + str(route_report["dead_ends"]))
	var unreachable: Array[String] = []
	for node_id: Variant in nodes:
		if not (route_report["reached"] as Dictionary).has(str(node_id)):
			unreachable.append(str(node_id))
	unreachable.sort()
	print("  ⚠ どのルートからも通れないノード = %d 件%s（0 が正解）" % [
		unreachable.size(), "" if unreachable.is_empty() else " " + str(unreachable),
	])
	if not unreachable.is_empty():
		push_error("[DebugBoot] どのルートからも通れないノードがある")

	# --- 6. 入口からボスまで歩く（戦利品はノード種に紐づく）---
	print("  --- 入口からボスまで歩く（⚠ 戦利品は「移動」ではなく「ノード種」に紐づく）---")
	var steps: int = 0
	# ⚠⚠ 最初に踏んだ戦闘のマスで「踏んだだけでは配らない」を1回だけ見る（不1・2026-09-05）。
	var battle_checked: bool = false
	while true:
		var here: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
		var node: Dictionary = GameManager.get_dungeon_node(here)
		if not battle_checked \
				and str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BATTLE:
			battle_checked = true
			print("  --- 戦闘のマス '%s'（⚠ 踏んだだけでは配らない・不1）---" % here)
			print("    踏んだ直後の拾い待ち = %s（⚠ 空が正解＝戦闘が起きる前に報酬が出ない）" % [
				str(GameManager.get_dungeon_pending_loot())
			])
			if GameManager.has_dungeon_pending_loot():
				push_error("[DebugBoot] 戦闘のマスを踏んだだけで拾い待ちが立った（不1 の再発）")
			var won: bool = GameManager.clear_dungeon_battle()
			print("    clear_dungeon_battle() -> %s（true が正解） / 拾い待ち = %s" % [
				str(won), str(GameManager.get_dungeon_pending_loot())
			])
			print("    ⚠ もう一度倒す -> %s（false が正解＝1マス1回）" % [
				str(GameManager.clear_dungeon_battle())
			])
			# ⚠ 拾い待ちを片付けてから歩き続ける（⚠ 溜めると次の節の測定に混ざる）。
			var _left: Dictionary = GameManager.clear_dungeon_pending_loot()
		var moves: Array = GameManager.get_dungeon_moves()
		print("    %d手目 いま=%-8s 種類=%-6s 鞄=%d/%d 通貨=%d 進める先=%s" % [
			steps, here, str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")),
			GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots(),
			GameManager.get_dungeon_currency(), str(moves),
		])
		if moves.is_empty():
			break
		if not GameManager.move_in_dungeon(str(moves[0])):
			push_error("[DebugBoot] move_in_dungeon が false: " + str(moves[0]))
			break
		steps += 1
		if steps > 50:
			push_error("[DebugBoot] 50手で終わらない（ループしている）")
			break
	print("    歩数 = %d（層数%d ＋ボス1 → %d 手が正解）" % [steps, layer_total, layer_total])

	# --- 7. 進めない先を渡す（入口へ戻れない＝引き返さない）---
	var before_position: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var rejected: bool = GameManager.move_in_dungeon(entry_id)
	var after_position: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	print("  ⚠ 入口 '%s' へ戻ろうとする -> %s（false が正解＝引き返さない） / 位置 %s -> %s" % [
		entry_id, str(rejected), before_position, after_position,
	])

	# --- 8. ボスの手前では撤退できない ---
	print("  ⚠ ボスを倒す前の can_retreat_from_dungeon() = %s（false が正解＝層の途中に降り口は無い）" % [
		str(GameManager.can_retreat_from_dungeon())
	])

	# --- 9. ボスを倒す ---
	var bag_before_boss: int = GameManager.get_dungeon_bag_used()
	var currency_before_boss: int = GameManager.get_dungeon_currency()
	var cleared: bool = GameManager.clear_dungeon_boss()
	print("  clear_dungeon_boss() -> %s / phase='%s'（boss_cleared が正解）" % [
		str(cleared), GameManager.get_dungeon_phase()
	])
	print("  ボスの取り分：鞄 %d -> %d ／ 通貨 %d -> %d" % [
		bag_before_boss, GameManager.get_dungeon_bag_used(),
		currency_before_boss, GameManager.get_dungeon_currency(),
	])
	print("  can_retreat_from_dungeon() = %s（true が正解） / get_dungeon_moves() = %s（空が正解）" % [
		str(GameManager.can_retreat_from_dungeon()), str(GameManager.get_dungeon_moves()),
	])
	print("  ⚠ 二重に倒せないこと：clear_dungeon_boss() をもう一度 -> %s（false が正解）" % [
		str(GameManager.clear_dungeon_boss())
	])

	# --- 10. 続行する（フロア2へ潜る）---
	var bag_before_descend: Dictionary = GameManager.get_dungeon_bag()
	var currency_before_descend: int = GameManager.get_dungeon_currency()
	var max_hp_before_descend: Dictionary = GameManager.get_dungeon_max_hp()
	# ⚠ 潜る「前」に聞く（段階20-a）。⚠ 潜ったあとは phase が map に戻るので、
	#   ⚠ can_descend_dungeon_floor() は false を返す（⚠ 正しい挙動だがログが誤解を招く）。
	print("  ⚠ 潜れる階 = %d（決定49：50階＝500層） / いま %d 階目 / もう1階潜れるか %s（true が正解）" % [
		GameManager.get_dungeon_max_floors(), GameManager.get_dungeon_floor_index(),
		str(GameManager.can_descend_dungeon_floor()),
	])
	if not GameManager.can_descend_dungeon_floor():
		push_error("[DebugBoot] 1階目のボスを倒したのに続行できない")
	var descended: bool = GameManager.descend_dungeon_floor()
	print("  descend_dungeon_floor() -> %s / フロア=%d（2 が正解） / phase='%s'（map が正解）" % [
		str(descended), GameManager.get_dungeon_floor_index(), GameManager.get_dungeon_phase()
	])
	print("  持ち越し：鞄 %s -> %s ／ 通貨 %d -> %d ／ ランのMAX HP %s -> %s（どれも同じが正解）" % [
		str(bag_before_descend), str(GameManager.get_dungeon_bag()),
		currency_before_descend, GameManager.get_dungeon_currency(),
		str(max_hp_before_descend), str(GameManager.get_dungeon_max_hp()),
	])
	print("  フロア2 の位置 = '%s' / 進める先 = %s（作り直された新しいマップ）" % [
		str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")),
		str(GameManager.get_dungeon_moves()),
	])

	# --- 11. 鞄の枠（溢れたぶんは入らない）---
	# ⚠⚠ 2026-09-20・決定42：⚠ **素材は1枠に `bag_material_stack` 個まで重なる**（⚠ 人間「素材関連を１０まで」）。
	#   ⚠ ポーション・宝箱は今までどおり1個1枠。⚠ 枠の数え方は `get_run_bag_used()` の1本。
	print("[DebugBoot] --- 鞄の枠（⚠ 素材は重なる ／ ポーション・宝箱は1個1枠）---")
	var stack_limit: int = GameManager.get_run_bag_stack_limit(
		GameManager.RUN_KIND_DUNGEON, "construction_material_1"
	)
	var potion_limit: int = GameManager.get_run_bag_stack_limit(
		GameManager.RUN_KIND_DUNGEON, "dungeon_potion_heal"
	)
	print("  重なる上限：素材 %d ／ ポーション %d（⚠ 素材 > 1・ポーション = 1 が正解）" % [
		stack_limit, potion_limit
	])
	if stack_limit <= 1 or potion_limit != 1:
		push_error("[DebugBoot] 鞄の重なる上限が決定42どおりでない")
	# ⚠ 1枠ぶん＋5個入れて、⚠ 2枠になること（⚠ 端数は1枠）。
	var before_used: int = GameManager.get_dungeon_bag_used()
	var _put: int = GameManager.add_to_dungeon_bag("construction_material_1", stack_limit + 5)
	var after_used: int = GameManager.get_dungeon_bag_used()
	print("  素材 %d 個を入れる -> 枠 %d → %d（⚠ 2枠ぶん増えるのが正解）" % [
		stack_limit + 5, before_used, after_used
	])
	if after_used - before_used != 2:
		push_error("[DebugBoot] 素材の重なりが枠の数に効いていない")
	var free_before: int = GameManager.get_dungeon_bag_slots() - GameManager.get_dungeon_bag_used()
	var accepted: int = GameManager.add_to_dungeon_bag("training_material_1", free_before * stack_limit + 5)
	print("  空き %d 枠に %d 個入れようとする -> %d 個入った（⚠ 空き × %d が正解） / 鞄 %d/%d" % [
		free_before, free_before * stack_limit + 5, accepted, stack_limit,
		GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots(),
	])
	if accepted != free_before * stack_limit:
		push_error("[DebugBoot] 空き枠 × 重なる上限まで入っていない")
	var accepted_full: int = GameManager.add_to_dungeon_bag("forging_material_1", 1)
	print("  満杯の鞄にもう1個 -> %d 個（0 が正解＝勝手に何かを捨てない）" % accepted_full)

	# ⚠ 鞄のマス目（段階18-d）。⚠ 長さは枠。⚠ 空きマスは空の Dictionary。
	var bag_layout: Array = GameManager.get_dungeon_bag_slot_layout()
	var bag_filled: int = 0
	for entry: Variant in bag_layout:
		if not (entry as Dictionary).is_empty():
			bag_filled += 1
	# ⚠ マスの中身＝そのマスに入っている個数（⚠ 重なった素材は 10・10・3 のように分かれる）。
	print("  鞄のマス目 = %d マス（枠 %d と同じが正解） / 中身 %d（使用 %d と同じが正解）" % [
		bag_layout.size(), GameManager.get_dungeon_bag_slots(),
		bag_filled, GameManager.get_dungeon_bag_used(),
	])
	if bag_layout.size() != GameManager.get_dungeon_bag_slots():
		push_error("[DebugBoot] 鞄のマス目の長さが枠と違う")
	if bag_filled != GameManager.get_dungeon_bag_used():
		push_error("[DebugBoot] 鞄のマス目の中身が使用数と合わない")
	if not bag_layout.is_empty():
		print("    先頭のマス = %s ／ 鞄の個数 = %d（⚠ 拠点の所持数ではない）" % [
			str((bag_layout[0] as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, "")),
			int((bag_layout[0] as Dictionary).get(GameManager.SLOT_ENTRY_COUNT, 0)),
		])

	# --- 11-A. レリック（段階17-e-2。⚠ 表はシナリオ側と共有）---
	print("[DebugBoot] --- レリック（⚠ relics.json をシナリオ側と共有）---")
	var relic_node: String = ""
	for node_id: Variant in (GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_NODES, {}) as Dictionary):
		if str(GameManager.get_dungeon_node(str(node_id)).get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_RELIC:
			relic_node = str(node_id)
			break
	if relic_node == "":
		print("  ⚠ この生成には relic のマスが1つも無かった（⚠ 抽選なので毎回は出ない）")
	else:
		var choices_a: Array = GameManager.get_dungeon_relic_choices(relic_node)
		var choices_b: Array = GameManager.get_dungeon_relic_choices(relic_node)
		print("  '%s' の候補 = %s（%d 件）" % [relic_node, str(choices_a), choices_a.size()])
		print("  ⚠ もう一度引く -> %s（同じが正解＝描き直しても入れ替わらない）" % str(choices_b))
		if choices_a != choices_b:
			push_error("[DebugBoot] レリックの候補が引き直されている（画面を描くたびに変わる）")
		# ⚠ そのマスに居ないと取れない。
		print("  ⚠ そのマスに居ないのに取る -> %s（false が正解）" % [
			str(GameManager.take_dungeon_relic(relic_node, str(choices_a[0])))
		])

	# --- 11-A2. レリックの説明文（段階20-d・人間の指示「レリックなどの説明文が欲しい」）---
	#
	# ⚠⚠ 17-e-3 では「名前と全体/1人だけ」しか出していなかった（⚠ 効果の文章が無かった）。
	# ⚠ `ItemDetail` は `ui_desc_<id>` が在るときだけ説明を出す。⚠ コードは触っていない。
	#   ⚠ ここで見るのは「12件とも ja.csv に説明が在るか」だけ。
	print("[DebugBoot] --- レリックの説明文（⚠ ui_desc_<relic_id> が12件とも在るか）---")
	var relic_missing: Array[String] = []
	for raw_relic_id: Variant in MasterDataLoader.get_all_relic_ids():
		var relic_id: String = str(raw_relic_id)
		var desc_key: String = "ui_desc_" + relic_id
		var desc_text: String = TranslationServer.translate(desc_key)
		if desc_text == desc_key:
			relic_missing.append(relic_id)
		else:
			print("  %-26s %s" % [relic_id, desc_text])
	print("  ⚠ 説明が無いレリック = %d 件（0 が正解）%s" % [
		relic_missing.size(), "" if relic_missing.is_empty() else " " + str(relic_missing),
	])
	if not relic_missing.is_empty():
		push_error("[DebugBoot] 説明文の無いレリックがある（画面で名前しか出ない）")

	# --- 11-B. ショップとたいまつ（段階17-e）---
	#
	# ⚠ 店が出るのは「ボスを倒した先」だけ。⚠ いまはフロア2 の道中なので空が正解。
	print("[DebugBoot] --- ボスの先のショップ（⚠ 決定15。⚠ 途中では店が無い）---")
	print("  ⚠ ボスの手前で get_dungeon_shop_entries() = %d 件（0 が正解）" % [
		GameManager.get_dungeon_shop_entries().size()
	])
	print("  たいまつ 等級%d / %d 層先まで見える（上限 等級%d）" % [
		GameManager.get_dungeon_torch_grade(), GameManager.get_dungeon_reveal_layers(),
		GameManager.get_dungeon_torch_max_grade(),
	])
	# ⚠ 見えているノードの数（⚠ たいまつを買うと増えるはず）。
	var revealed_before: int = _count_revealed_dungeon_nodes()
	print("  いま中身が見えているノード = %d 件" % revealed_before)

	# --- 12. 撤退する（鞄の中身を持ち帰る）---
	print("[DebugBoot] --- 撤退（⚠ 個体化の口は add_to_inventory() の1本だけ）---")
	# ⚠ 歩く途中で relic のマスに着いたら、⚠ そこで実際に取る（段階17-e-2）。
	_take_dungeon_relic_on_the_way()

	# ⚠ 撤退できるのはボスの先だけなので、フロア2 のボスまで歩いてから倒す。
	_walk_dungeon_to_boss()
	GameManager.clear_dungeon_boss()

	# ⚠ ボスを倒したので店が開く（段階17-e）。⚠ ここで買ってから撤退する。
	print("[DebugBoot] --- ボスを倒した先のショップ ---")
	var shop_entries: Array = GameManager.get_dungeon_shop_entries()
	print("  品揃え = %d 件 ／ 一時通貨 = %d" % [shop_entries.size(), GameManager.get_dungeon_currency()])
	for i: int in range(shop_entries.size()):
		var row: Dictionary = shop_entries[i]
		print("    %d: %-10s %-24s %d 遺物片 ／ 断る理由 '%s'" % [
			i, str(row.get(GameManager.DUNGEON_SHOP_KIND, "")),
			str(row.get(GameManager.SLOT_ENTRY_ITEM_ID, "")),
			int(row.get(GameManager.DUNGEON_SHOP_COST, 0)),
			GameManager.get_dungeon_shop_reject_reason(i),
		])
	_report_dungeon_map_shop_row()
	# ⚠ 鞄の枠を買う（⚠ 枠が増えること）。
	for i: int in range(shop_entries.size()):
		if str((shop_entries[i] as Dictionary).get(GameManager.DUNGEON_SHOP_KIND, "")) != GameManager.DUNGEON_SHOP_KIND_BAG_SLOT:
			continue
		var slots_before: int = GameManager.get_dungeon_bag_slots()
		var currency_before: int = GameManager.get_dungeon_currency()
		var bought: bool = GameManager.buy_dungeon_shop_entry(i)
		print("  鞄の枠を買う -> %s / 枠 %d -> %d ／ 通貨 %d -> %d" % [
			str(bought), slots_before, GameManager.get_dungeon_bag_slots(),
			currency_before, GameManager.get_dungeon_currency(),
		])
		break
	# ⚠ たいまつを買う（⚠ 見えるノードが増えること）。
	for i: int in range(shop_entries.size()):
		if str((shop_entries[i] as Dictionary).get(GameManager.DUNGEON_SHOP_KIND, "")) != GameManager.DUNGEON_SHOP_KIND_TORCH:
			continue
		var layers_before: int = GameManager.get_dungeon_reveal_layers()
		var seen_before: int = _count_revealed_dungeon_nodes()
		var bought_torch: bool = GameManager.buy_dungeon_shop_entry(i)
		print("  たいまつを買う -> %s / 見える層 %d -> %d ／ 見えるノード %d -> %d" % [
			str(bought_torch), layers_before, GameManager.get_dungeon_reveal_layers(),
			seen_before, _count_revealed_dungeon_nodes(),
		])
		break
	# ⚠⚠ たいまつが効くのは「次のフロア」（⚠ そのフロアはもう全部踏んでいる）。
	#   ⚠ 17-a は降りるとき 0 に戻していた。⚠ 17-e で覆した（⚠ 戻すと買う意味が無い）。
	var torch_before_descend: int = GameManager.get_dungeon_torch_grade()
	if GameManager.descend_dungeon_floor():
		print("  次のフロアへ降りる -> たいまつ 等級%d -> %d（⚠ 持ち越すのが正解） / %d 層先" % [
			torch_before_descend, GameManager.get_dungeon_torch_grade(),
			GameManager.get_dungeon_reveal_layers(),
		])
		print("    ⚠ 入口で中身が見えているノード = %d 件（⚠ たいまつ 等級0 なら 4 件だった）" % [
			_count_revealed_dungeon_nodes()
		])
		# ⚠⚠ ショップの覚えは階ごとに戻る（2026-09-20）。⚠ 戻らないと2階のボスの後に出ない。
		print("    ⚠ ショップを自動で出したか = %s（⚠ false が正解＝階ごとに戻る）" % [
			str(GameManager.has_seen_dungeon_shop())
		])
		if GameManager.has_seen_dungeon_shop():
			push_error("[DebugBoot] 降りてもショップの覚えが戻っていない（次の階でショップが出ない）")
		if GameManager.get_dungeon_torch_grade() != torch_before_descend:
			push_error("[DebugBoot] たいまつがフロアをまたいで消えた（買う意味が無くなる）")
		# ⚠ 撤退できる状態に戻す（⚠ このあと §12 が持ち帰る）。
		_walk_dungeon_to_boss()
		var _cleared_again: bool = GameManager.clear_dungeon_boss()

	# ⚠⚠ 最後の階では続行できないこと（段階20-a・決定26）。
	#   ⚠ 上限まで潜ってから叩く。⚠ 撤退はできるが続行はできないのが正解。
	print("[DebugBoot] --- 潜れる上限（⚠ 決定49：50階＝500層）---")
	for _floor_try: int in range(GameManager.get_dungeon_max_floors() + 2):
		if not GameManager.can_descend_dungeon_floor():
			break
		if not GameManager.descend_dungeon_floor():
			break
		_walk_dungeon_to_boss()
		var _cleared_more: bool = GameManager.clear_dungeon_boss()
	print("  ⚠ %d 階目まで潜った（上限 %d） / もう1階潜れるか %s（false が正解） / 撤退できるか %s（true が正解）" % [
		GameManager.get_dungeon_floor_index(), GameManager.get_dungeon_max_floors(),
		str(GameManager.can_descend_dungeon_floor()), str(GameManager.can_retreat_from_dungeon()),
	])
	if GameManager.get_dungeon_floor_index() != GameManager.get_dungeon_max_floors():
		push_error("[DebugBoot] 上限まで潜れていない（または上限を超えた）")
	if GameManager.can_descend_dungeon_floor():
		push_error("[DebugBoot] 最後の階なのに続行できる（1ランが終わらない）")
	print("  ⚠ それでも descend_dungeon_floor() を叩く -> %s（false が正解） / 階 %d（増えないのが正解）" % [
		str(GameManager.descend_dungeon_floor()), GameManager.get_dungeon_floor_index()
	])

	# ⚠ 一時通貨が足りないときは買えない（⚠ 払ってから弾かない）。
	var drained: int = GameManager.get_dungeon_currency()
	GameManager.add_dungeon_currency(-drained)
	print("  ⚠ 通貨0で買う -> %s（false が正解） / 理由 '%s'（currency が正解）" % [
		str(GameManager.buy_dungeon_shop_entry(0)), GameManager.get_dungeon_shop_reject_reason(0)
	])
	GameManager.add_dungeon_currency(drained)
	var bag_at_retreat: Dictionary = GameManager.get_dungeon_bag()
	var owned_before: Dictionary = _dungeon_owned_snapshot(bag_at_retreat)
	var report: Dictionary = GameManager.retreat_from_dungeon()
	print("  持ち帰った = %s ／ ラン専用で消えた = %s" % [str(report["granted"]), str(report["discarded"])])
	var owned_after: Dictionary = _dungeon_owned_snapshot(bag_at_retreat)
	for item_id: Variant in owned_before:
		print("    %-26s 拠点 %d -> %d（鞄に %d 個あった）" % [
			str(item_id), int(owned_before[item_id]), int(owned_after[item_id]),
			int(bag_at_retreat[item_id]),
		])
	print("  is_in_dungeon() = %s（false が正解） / 鞄 = %s（空が正解）" % [
		str(GameManager.is_in_dungeon()), str(GameManager.get_dungeon_bag())
	])

	# --- 13. 全ロスト（死亡／その場で降りる）---
	print("[DebugBoot] --- 全ロスト（⚠ 逃げ道は残すが、タダにはしない）---")
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 2本目の start_dungeon_run が false")
		return
	GameManager.add_to_dungeon_bag("construction_material_1", 3)
	var lost_bag: Dictionary = GameManager.get_dungeon_bag()
	var owned_before_lost: Dictionary = _dungeon_owned_snapshot(lost_bag)
	GameManager.abandon_dungeon_run()
	var owned_after_lost: Dictionary = _dungeon_owned_snapshot(lost_bag)
	for item_id: Variant in owned_before_lost:
		print("    %-26s 拠点 %d -> %d（増えないのが正解） / 失った鞄 %d 個" % [
			str(item_id), int(owned_before_lost[item_id]), int(owned_after_lost[item_id]),
			int(lost_bag[item_id]),
		])
	print("  is_in_dungeon() = %s（false が正解）" % str(GameManager.is_in_dungeon()))

	# --- 13-A1. 通路の効果（段階19-c-2・人間の決定24）---
	#
	# ⚠ 抽選なので「どれが出るか」は毎回変わる。⚠ 見るのは
	#   ①効果を直接叩いたときに状態が動くか ②宝箱が持ち越しになるか
	#   ③罠で脱落しないこと（⚠ 設計役の判断。⚠ 死ぬのは戦闘だけ）。
	# ⚠ 効かせる口（_apply_dungeon_edge_effect）は private なので、
	#   ⚠ ここでは「通路を通る」を繰り返して実際に踏ませる。
	print("[DebugBoot] --- 通路の効果（⚠ 罠・宝箱・資源。⚠ 5本に1本）---")
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 通路ぶんの start_dungeon_run が false")
		return
	print("  ⚠ たいまつ 等級%d / %d 層先まで見える（⚠ 決定25：⚠ 等級1 を持って始まる）" % [
		GameManager.get_dungeon_torch_grade(), GameManager.get_dungeon_reveal_layers()
	])
	if GameManager.get_dungeon_torch_grade() <= 0:
		push_error("[DebugBoot] ランの開始時にたいまつを持っていない（決定25）")
	# ⚠ 入口から出ている通路の中身（⚠ 画面が出すもの）。
	var entry_edges: Array = GameManager.get_dungeon_edges(entry_id)
	for raw_entry_edge: Variant in entry_edges:
		var entry_edge: Dictionary = raw_entry_edge
		var entry_to: String = str(entry_edge.get(GameStateKeys.DUNGEON_EDGE_TO, ""))
		print("    入口 -> %-8s 効果 '%s' ／ 見えているか %s" % [
			entry_to, str(entry_edge.get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")),
			str(GameManager.is_dungeon_edge_revealed(entry_id, entry_to)),
		])
	# ⚠⚠ 効果は抽選なので、⚠ 1本のランでは5種のうち1〜2種しか踏めない
	#   （⚠ 最初はそう書いて、⚠ 罠(HP)も通路の宝箱も1度も踏めていなかった）。
	#   ⚠ ランを作り直しながら「効果のある通路を優先して歩く」を繰り返し、
	#     ⚠ 5種とも1度は踏むまで回す。
	var seen_effects: Dictionary = {}
	var runs_used: int = 0
	for _run_try: int in range(20):
		runs_used += 1
		var before_hp: Dictionary = GameManager.get_dungeon_max_hp()
		var before_currency: int = GameManager.get_dungeon_currency()
		for effect: String in _walk_dungeon_preferring_edges():
			seen_effects[effect] = int(seen_effects.get(effect, 0)) + 1
		print("  %2d本目：⚠ 戦闘時MAX HP %s -> %s ／ 通貨 %d -> %d" % [
			runs_used, str(before_hp), str(GameManager.get_dungeon_max_hp()),
			before_currency, GameManager.get_dungeon_currency(),
		])
		if seen_effects.size() >= GameManager.DUNGEON_EDGE_EFFECTS_KNOWN.size():
			break
		GameManager.abandon_dungeon_run()
		if not GameManager.start_dungeon_run(target_id):
			push_error("[DebugBoot] 通路ぶんの start_dungeon_run が false（作り直し）")
			break
	var effect_names_seen: Array = seen_effects.keys()
	effect_names_seen.sort()
	var seen_parts: Array[String] = []
	for effect_name: Variant in effect_names_seen:
		seen_parts.append("%s=%d" % [str(effect_name), int(seen_effects[effect_name])])
	print("  ⚠ %d 本のランで踏んだ効果 = %s（⚠ 5種とも1回以上が正解）" % [
		runs_used, " ".join(seen_parts)
	])
	for known_effect: String in GameManager.DUNGEON_EDGE_EFFECTS_KNOWN:
		if not seen_effects.has(known_effect):
			push_error("[DebugBoot] %d 本回しても踏めなかった通路の効果: %s" % [runs_used, known_effect])
	GameManager.abandon_dungeon_run()

	# ⚠⚠ 罠（HP）で脱落しないこと（⚠ 設計役の判断。⚠ 死ぬのは戦闘だけ＝§4-4-2）。
	#   ⚠ 満タンで歩いても削られる量が小さくて 0 に届かないので、⚠ 先に 1 まで削っておく。
	#   ⚠ ここが「見えない通路を通っただけで全ロストにならない」ことの唯一の根拠。
	print("[DebugBoot] --- 罠（HP）は脱落させない（⚠ HP 1 から歩く）---")
	var trap_hp_hits: int = 0
	for _trap_try: int in range(20):
		if not GameManager.start_dungeon_run(target_id):
			push_error("[DebugBoot] 罠ぶんの start_dungeon_run が false")
			break
		var one_hp: Dictionary = {}
		for member: Variant in GameManager.get_party_members():
			one_hp[str(member)] = 1
		var _died: bool = GameManager.apply_dungeon_battle_result(one_hp)
		for effect: String in _walk_dungeon_preferring_edges():
			if effect == GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP:
				trap_hp_hits += 1
		if trap_hp_hits > 0:
			print("  HP 1 のまま罠（HP）を %d 回踏んだ -> 戦闘時MAX HP = %s（⚠ 1 未満にならないのが正解）" % [
				trap_hp_hits, str(GameManager.get_dungeon_max_hp())
			])
			var downed_by_trap: Array[String] = []
			for member: Variant in GameManager.get_party_members():
				if GameManager.is_dungeon_character_downed(str(member)):
					downed_by_trap.append(str(member))
			print("  ⚠ 罠だけで脱落した者 = %d 人（0 が正解）%s" % [
				downed_by_trap.size(), "" if downed_by_trap.is_empty() else " " + str(downed_by_trap),
			])
			if not downed_by_trap.is_empty():
				push_error("[DebugBoot] 通路の罠で脱落した（見えない通路で全ロストになりうる）")
			break
		GameManager.abandon_dungeon_run()
	if trap_hp_hits <= 0:
		push_error("[DebugBoot] 20本回しても罠（HP）を踏めなかった（脱落しないことを確かめられていない）")
	GameManager.abandon_dungeon_run()
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 通路の節のあとの start_dungeon_run が false")
		return
	GameManager.abandon_dungeon_run()

	# --- 13-A2. 宝箱のマス（段階19-b。⚠ その場で開く＝案A）---
	#
	# ⚠ 見るのは4つ：⚠ ①踏んだだけでは配らない ②開けると鞄に入る
	#   ③1マスにつき1回だけ ④鞄が満杯なら置いてくる（⚠ 黙って消さない）。
	# ⚠ 拠点の PENDING_CHESTS が1件も増えないことも見る（⚠ 決定7・§4-8）。
	print("[DebugBoot] --- 宝箱のマス（⚠ その場で開く。⚠ pending_chests には積まない）---")
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 宝箱ぶんの start_dungeon_run が false")
		return
	var chest_node: String = _walk_dungeon_to_kind(GameStateKeys.DUNGEON_NODE_KIND_CHEST)
	if chest_node == "":
		print("  ⚠ この生成には chest のマスへ着ける道が無かった（⚠ 抽選なので毎回は出ない）")
	else:
		var bag_before_chest: int = GameManager.get_dungeon_bag_used()
		var currency_before_chest: int = GameManager.get_dungeon_currency()
		var pending_before: int = (
			GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []) as Array
		).size()
		print("  '%s' に立った / 鞄 %d/%d ／ 通貨 %d ／ 開けたか=%s（false が正解＝踏んだだけでは開かない）" % [
			chest_node, bag_before_chest, GameManager.get_dungeon_bag_slots(),
			currency_before_chest, str(GameManager.was_dungeon_chest_opened(chest_node)),
		])
		# ⚠ 鞄の数では見ない。⚠ ここへ来るまでに戦闘のマスを通るので、⚠ 鞄は0ではない
		#   （⚠ 最初はそう書いて赤を出した）。⚠ 見るのは「まだ開いていない」ことだけ。
		if GameManager.was_dungeon_chest_opened(chest_node):
			push_error("[DebugBoot] 宝箱のマスを踏んだだけで開いている（開ける動作が飾りになる）")
		var opened: Dictionary = GameManager.open_dungeon_chest(chest_node)
		# ⚠⚠ 段階20-e：⚠ 開けても鞄には入らない。⚠ 拾い待ちへ積まれ、⚠ プレイヤーが選ぶ。
		print("  開ける -> 拾い待ちへ %s ／ 鞄 %d -> %d（⚠ 増えないのが正解） ／ 通貨 %d -> %d" % [
			str(opened["granted"]),
			bag_before_chest, GameManager.get_dungeon_bag_used(),
			currency_before_chest, GameManager.get_dungeon_currency(),
		])
		if GameManager.get_dungeon_bag_used() != bag_before_chest:
			push_error("[DebugBoot] 宝箱を開けただけで鞄が増えた（選ぶ余地が消える）")
		print("    拾い待ち = %s ／ マス目 %d 個" % [
			str(GameManager.get_dungeon_pending_loot()),
			GameManager.get_dungeon_pending_loot_slot_layout().size(),
		])
		if not GameManager.has_dungeon_pending_loot():
			push_error("[DebugBoot] 宝箱を開けたのに拾い待ちが空")
		# ⚠ 1個だけ鞄へ入れる（⚠ 選べることの根拠）。
		# ⚠⚠ 先に空きを作る。⚠ 層が25になって戦闘が増え、⚠ 宝箱に着く時点で鞄が
		#   満杯のことがある（⚠ 実際にそうなって赤を出した）。⚠ 満杯の枝は下の節で測る。
		if GameManager.get_dungeon_bag_used() >= GameManager.get_dungeon_bag_slots():
			var room_id: String = str(GameManager.get_dungeon_bag().keys()[0])
			var _made_room: bool = GameManager.discard_dungeon_bag_item(room_id)
			print("  ⚠ 鞄が満杯だったので '%s' を1個捨てて空きを作った（⚠ 道具の下ごしらえ）" % room_id)
		var pick_id: String = str(GameManager.get_dungeon_pending_loot().keys()[0])
		var bag_before_take: int = GameManager.get_dungeon_bag_used()
		print("  ⚠ '%s' を1個だけ鞄へ -> %s ／ 鞄 %d -> %d ／ 拾い待ち = %s" % [
			pick_id, str(GameManager.take_dungeon_pending_loot(pick_id)),
			bag_before_take, GameManager.get_dungeon_bag_used(),
			str(GameManager.get_dungeon_pending_loot()),
		])
		if GameManager.get_dungeon_bag_used() != bag_before_take + 1:
			push_error("[DebugBoot] 1個入れたのに鞄が1つ増えていない")
		# ⚠ 残りを全部入れる。
		var taken_all: Dictionary = GameManager.take_all_dungeon_pending_loot()
		print("  ⚠ 残りを全部入れる -> %s ／ 鞄 %d/%d ／ 拾い待ち = %s" % [
			str(taken_all), GameManager.get_dungeon_bag_used(),
			GameManager.get_dungeon_bag_slots(), str(GameManager.get_dungeon_pending_loot()),
		])
		print("  開けたか=%s（true が正解） ／ ⚠ もう一度開ける -> 拾い待ちへ %s（空が正解＝1マス1回）" % [
			str(GameManager.was_dungeon_chest_opened(chest_node)),
			str(GameManager.open_dungeon_chest(chest_node)["granted"]),
		])
		var pending_after: int = (
			GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []) as Array
		).size()
		print("  ⚠ 拠点の未開封の宝箱 %d -> %d（増えないのが正解＝全ロストの対象から外れない）" % [
			pending_before, pending_after
		])
		if pending_after != pending_before:
			push_error("[DebugBoot] ランの宝箱が拠点の pending_chests に積まれた（決定7 が崩れる）")
	GameManager.abandon_dungeon_run()

	# ⚠⚠ 宝箱のまま持ち帰る（2026-09-18・人間の決定「難ダンジョンの宝箱も同じように
	#   ⚠ インベントリに入るように」「表を借りて拠点で引く」）。
	#   ⚠ 鞄の宝箱は撤退で**拠点の宝箱**になり、⚠ 中身は拠点で開けたときに引く。
	#   ⚠ ラン専用の品（回復薬）は拠点では出ない。
	print("[DebugBoot] --- 宝箱を鞄のまま持ち帰る（撤退 → 拠点の宝箱 → 開ける）---")
	if GameManager.start_dungeon_run(target_id):
		var carry_node: String = _walk_dungeon_to_kind(GameStateKeys.DUNGEON_NODE_KIND_CHEST)
		if carry_node == "":
			print("  ⚠ この生成には chest のマスへ着ける道が無かった")
		else:
			var _opened_carry: Dictionary = GameManager.open_dungeon_chest(carry_node)
			var _taken_carry: Dictionary = GameManager.take_all_run_pending_loot(GameManager.RUN_KIND_DUNGEON)
			var chests_in_bag: int = int(GameManager.get_dungeon_bag().get(GameManager.DUNGEON_CHEST_ID, 0))
			# ⚠ ボスまで歩いて倒す（⚠ 撤退できるのはボスの先だけ）。
			var guard_carry: int = 0
			while true:
				var moves_carry: Array = GameManager.get_dungeon_moves()
				if moves_carry.is_empty():
					break
				if not GameManager.move_in_dungeon(str(moves_carry[0])):
					break
				guard_carry += 1
				if guard_carry > 60:
					break
			var _cleared_carry: bool = GameManager.clear_dungeon_boss()
			var pending_before_carry: int = GameManager.get_pending_chest_count()
			var carried: Dictionary = GameManager.retreat_from_dungeon()
			var pending_after_carry: int = GameManager.get_pending_chest_count()
			print("  鞄の宝箱 %d 個 -> 撤退 -> 拠点の未開封 %d -> %d（⚠ %d 増えるのが正解）／ 持ち帰った %s" % [
				chests_in_bag, pending_before_carry, pending_after_carry, chests_in_bag,
				str(carried.get("granted", {})),
			])
			if pending_after_carry != pending_before_carry + chests_in_bag:
				push_error("[DebugBoot] 鞄の宝箱が拠点の宝箱にならなかった")
			# ⚠ 拠点で開ける。⚠ 中身は dungeon.json の表から引く（⚠ ラン専用の品は出ない）。
			if chests_in_bag > 0:
				var carried_instance: String = str(_last_unopened_chest().get(GameStateKeys.CHEST_INSTANCE_ID, ""))
				var _opened_at_base: bool = GameManager.open_chest(carried_instance)
				var got: Dictionary = _chest_record(carried_instance).get(GameStateKeys.CHEST_REWARDS, {})
				print("  拠点で開ける -> %s（⚠ ラン専用の品が混じらないのが正解）" % str(got))
				for table_key: String in [GameStateKeys.REWARD_MATERIALS, GameStateKeys.REWARD_INVENTORY]:
					for got_id: Variant in (got.get(table_key, {}) as Dictionary):
						var definition: Dictionary = MasterDataLoader.get_item(str(got_id))
						if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_DUNGEON:
							push_error("[DebugBoot] 拠点で開けた宝箱にラン専用の品が入った: " + str(got_id))
	if GameManager.is_in_dungeon():
		GameManager.abandon_dungeon_run()

	# ⚠ 鞄が満杯のときに開ける枝（⚠ 置いてきたぶんが戻り値に出るか）。
	#
	# ⚠⚠ 1本目のランの続きで測らない。⚠ 1つ目を開けた時点で鞄が埋まることがあり、
	#   ⚠ その先に2つ目の chest が在るかは抽選なので、⚠ 測れたり測れなかったりする。
	#   ⚠ 新しいランで「着いてから満杯にする」なら必ず通る。
	print("[DebugBoot] --- 宝箱：鞄が満杯のとき（⚠ 黙って消さない）---")
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 満杯ぶんの start_dungeon_run が false")
		return
	var chest_node_full: String = _walk_dungeon_to_kind(GameStateKeys.DUNGEON_NODE_KIND_CHEST)
	if chest_node_full == "":
		print("  ⚠ この生成には chest のマスへ着ける道が無かった（⚠ 満杯の枝は測れていない）")
	else:
		# ⚠⚠ 2026-09-20・決定42：⚠ 素材は重なるので、⚠ 「空き枠の数」だけ入れても満杯にならない。
		#   ⚠ 空き枠 × 重なる上限ぶん入れて満杯にする。
		var _filled: int = GameManager.add_to_dungeon_bag(
			"construction_material_1",
			(GameManager.get_dungeon_bag_slots() - GameManager.get_dungeon_bag_used())
				* GameManager.get_run_bag_stack_limit(
					GameManager.RUN_KIND_DUNGEON, "construction_material_1"
				)
		)
		var full_result: Dictionary = GameManager.open_dungeon_chest(chest_node_full)
		# ⚠⚠ 段階20-e：⚠ 満杯でも拾い待ちには積まれる（⚠ 枠が無い）。
		#   ⚠ 鞄へ入れようとして初めて弾かれる。⚠ 「捨てて入れ替える」ための余地。
		print("  ⚠ 鞄が満杯（%d/%d）で開ける -> 拾い待ちへ %s（空でないのが正解）" % [
			GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots(),
			str(full_result["granted"]),
		])
		if not GameManager.has_dungeon_pending_loot():
			push_error("[DebugBoot] 満杯だと拾い待ちにも積まれない（選ぶ余地が消える）")
		var full_pick: String = str(GameManager.get_dungeon_pending_loot().keys()[0])
		print("  ⚠ 満杯のまま鞄へ入れる -> %s（false が正解）" % [
			str(GameManager.take_dungeon_pending_loot(full_pick))
		])
		if GameManager.take_dungeon_pending_loot(full_pick):
			push_error("[DebugBoot] 満杯の鞄に入った")
		# ⚠ 鞄からそのマスのぶんを捨てると入る（⚠ 人間の指示「入れ替えられる」）。
		#   ⚠⚠ 2026-09-20・決定42：⚠ 素材は重なるので、⚠ **1個だけ捨てても枠は空かない**。
		#     ⚠ 画面も「そのマスのぶん」を渡す（⚠ 10個入った枠を空けるのに10回押させない）。
		var bag_drop_id: String = str(GameManager.get_dungeon_bag().keys()[0])
		var bag_drop_count: int = GameManager.get_run_bag_stack_limit(
			GameManager.RUN_KIND_DUNGEON, bag_drop_id
		)
		var dropped_ok: bool = GameManager.discard_dungeon_bag_item(bag_drop_id, bag_drop_count)
		var took_after: bool = GameManager.take_dungeon_pending_loot(full_pick)
		print("  ⚠ 鞄から '%s' を捨てる -> %s ／ そのあと入れる -> %s（両方 true が正解＝入れ替えられる）" % [
			bag_drop_id, str(dropped_ok), str(took_after)
		])
		if not (dropped_ok and took_after):
			push_error("[DebugBoot] 鞄を空けても入れ替えられない")
		# ⚠ 残りを置いていく（⚠ 画面を出るときの口）。
		print("  ⚠ 残りを置いていく -> %s ／ 拾い待ち = %s（空が正解）" % [
			str(GameManager.clear_dungeon_pending_loot()),
			str(GameManager.get_dungeon_pending_loot()),
		])
		if GameManager.has_dungeon_pending_loot():
			push_error("[DebugBoot] 置いていったのに拾い待ちが残っている")
		# ⚠ 開けたことは残る（⚠ 拾えなかったからといって引き直せない＝抽選し放題を塞ぐ）。
		print("  ⚠ 1個も入らなかったが開けたことは残る=%s（true が正解＝引き直せない）" % [
			str(GameManager.was_dungeon_chest_opened(chest_node_full))
		])
	GameManager.abandon_dungeon_run()

	# --- 13-B. 目減り・脱落・死亡（段階17-b。⚠ 戦闘を回さずに書き戻しの口だけ叩く）---
	#
	# ⚠ 戦闘そのものは scenario=dungeon_battle が回す。⚠ ここで見るのは
	#   「編成3人が全員脱落したら鞄を失うか」＝戦闘では起こしにくい枝。
	print("[DebugBoot] --- 目減りと脱落と死亡（⚠ 書き戻しの口は apply_dungeon_battle_result の1本）---")
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 3本目の start_dungeon_run が false")
		return
	var members: Array = GameManager.get_party_members()
	var half: Dictionary = {}
	for member: Variant in members:
		half[str(member)] = int(GameManager.get_dungeon_character_max_hp(str(member))) / 2
	var died_half: bool = GameManager.apply_dungeon_battle_result(half)
	print("  半分まで削る -> 死亡=%s（false が正解） / ランのMAX HP = %s / HP = %s" % [
		str(died_half), str(GameManager.get_dungeon_max_hp()), str(GameManager.get_dungeon_hp())
	])

	# 1人だけ 0 にする＝脱落（ランは続く）。
	var one_down: Dictionary = GameManager.get_dungeon_max_hp()
	one_down[str(members[0])] = 0
	var died_one: bool = GameManager.apply_dungeon_battle_result(one_down)
	print("  1人だけ 0 にする -> 死亡=%s（false が正解） / 脱落=%s / 出られる編成=%s" % [
		str(died_one), str(GameManager.is_dungeon_character_downed(str(members[0]))),
		str(GameManager.get_dungeon_active_members()),
	])

	# 全員 0 ＝死亡。⚠ 鞄を失う（§4-4-2）。
	GameManager.add_to_dungeon_bag("construction_material_1", 2)
	var bag_before_death: Dictionary = GameManager.get_dungeon_bag()
	var all_down: Dictionary = {}
	for member: Variant in members:
		all_down[str(member)] = 0
	var died_all: bool = GameManager.apply_dungeon_battle_result(all_down)
	print("  全員 0 にする -> 死亡=%s（true が正解） / is_in_dungeon()=%s（false が正解） / 失った鞄=%s" % [
		str(died_all), str(GameManager.is_in_dungeon()), str(bag_before_death),
	])

	# --- 13-C. ポーションと休憩（段階17-c・§4-3 / §4-9・決定19）---
	#
	# ⚠ 戦闘を回さない。⚠ 見るのは「戻る量」と「無駄撃ちを弾くか」と「鞄が減るか」。
	print("[DebugBoot] --- ポーションと休憩（⚠ 使う口は use_dungeon_item の1本）---")
	if not GameManager.start_dungeon_run(target_id):
		push_error("[DebugBoot] 4本目の start_dungeon_run が false")
		return
	var potion_members: Array = GameManager.get_party_members()
	var hurt: String = str(potion_members[0])
	var downed: String = str(potion_members[1])
	var base_hp: int = GameManager.get_dungeon_base_max_hp(hurt)

	# 1人を削り、1人を脱落させる（＝戦闘が終わった直後の形）。
	var after_battle: Dictionary = GameManager.get_dungeon_max_hp()
	after_battle[hurt] = int(base_hp) / 4
	after_battle[downed] = 0
	GameManager.apply_dungeon_battle_result(after_battle)
	print("  戦闘のあと：ランのMAX HP = %s ／ 出られる編成 = %s" % [
		str(GameManager.get_dungeon_max_hp()), str(GameManager.get_dungeon_active_members())
	])

	# 回復ポーション。⚠ 鞄に入れてから使う（鞄が唯一の持ち方）。
	GameManager.add_to_dungeon_bag("dungeon_potion_heal", 2)
	GameManager.add_to_dungeon_bag("dungeon_potion_revive", 1)
	var bag_before_use: Dictionary = GameManager.get_dungeon_bag()
	var healed: bool = GameManager.use_dungeon_item("dungeon_potion_heal", hurt)
	print("  回復ポーション -> %s（true が正解） / %s の上限 %d -> %d（素 %d の 30%% ぶん）" % [
		str(healed), hurt, int(after_battle[hurt]),
		GameManager.get_dungeon_character_max_hp(hurt), base_hp,
	])
	print("  HP = %d（上限と同じが正解＝決定18）" % GameManager.get_dungeon_character_hp(hurt))

	# ⚠ 無駄撃ちは弾く（脱落者に回復・生きている者に蘇生）。⚠ 鞄の枠は資源。
	print("  ⚠ 脱落者に回復 -> %s（false が正解） ／ 生きている者に蘇生 -> %s（false が正解）" % [
		str(GameManager.use_dungeon_item("dungeon_potion_heal", downed)),
		str(GameManager.use_dungeon_item("dungeon_potion_revive", hurt)),
	])

	# 蘇生ポーション。⚠ 素の 50% ／ HP はそのまた 50%（決定13）。
	var revived: bool = GameManager.use_dungeon_item("dungeon_potion_revive", downed)
	print("  蘇生ポーション -> %s（true が正解） / %s 上限 0 -> %d ／ HP %d（素 %d の 50%% と 25%%）" % [
		str(revived), downed, GameManager.get_dungeon_character_max_hp(downed),
		GameManager.get_dungeon_character_hp(downed), GameManager.get_dungeon_base_max_hp(downed),
	])
	print("  鞄 %s -> %s（使ったぶんだけ減るのが正解） / 脱落 = %d 人" % [
		str(bag_before_use), str(GameManager.get_dungeon_bag()),
		GameManager.get_party_members().size() - GameManager.get_dungeon_active_members().size(),
	])
	print("  ⚠ 鞄に無い品を使う -> %s（false が正解）" % [
		str(GameManager.use_dungeon_item("dungeon_potion_revive", downed))
	])

	# 休憩ノード。⚠ 呼ぶのは move_in_dungeon() の1本だが、⚠ どの層に出るかは抽選なので
	#   ここでは同じ関数を直接叩く（本番の口を増やしていない）。
	print("  --- 休憩ノード（⚠ 回復が先、⚠ そのあと脱落者を戻す）---")
	var rest_before: Dictionary = GameManager.get_dungeon_max_hp()
	GameManager.apply_dungeon_rest()
	print("  休憩：ランのMAX HP %s -> %s ／ HP = %s" % [
		str(rest_before), str(GameManager.get_dungeon_max_hp()), str(GameManager.get_dungeon_hp())
	])
	GameManager.abandon_dungeon_run()

	# --- 14. 素の MAX HP を1も削っていないこと（決定8の一番の落とし穴）---
	print("[DebugBoot] --- 素の MAX HP（⚠ ダンジョンが触るのはランの MAX HP だけ）---")
	var drifted: int = 0
	for character_id: Variant in base_max_hp_before:
		var now: int = int(
			GameManager.get_effective_stats(str(character_id)).get(GameStateKeys.STAT_HP, 0)
		)
		var before: int = int(base_max_hp_before[character_id])
		if now != before:
			push_error("[DebugBoot] 素の MAX HP が動いた: %s %d -> %d" % [str(character_id), before, now])
			drifted += 1
		print("    %-16s %d -> %d" % [str(character_id), before, now])
	print("  動いたキャラ = %d 人（0 が正解）" % drifted)

	# --- 15. ラン専用の item_type（決定17。中身は 17-c で足す）---
	var dungeon_typed: Array[String] = []
	var all_items: Dictionary = MasterDataLoader.get_all_items()
	for item_id: Variant in all_items:
		var definition: Variant = all_items[item_id]
		if not (definition is Dictionary):
			continue
		if str((definition as Dictionary).get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_DUNGEON:
			dungeon_typed.append(str(item_id))
	dungeon_typed.sort()
	print("[DebugBoot] --- ラン専用の item_type='%s' の品 = %d 件%s ---" % [
		GameStateKeys.ITEM_TYPE_DUNGEON, dungeon_typed.size(),
		"" if dungeon_typed.is_empty() else " " + str(dungeon_typed),
	])
	print("  ⚠ 17-c で 2 件（回復・蘇生）が入った。⚠ どちらも撤退では持ち帰れない（決定17・§4-3-1）")
	_report_dungeon_depth()


# 深さで変わる難ダンジョン（2026-10-03・回4・決定47・`EXEC_DUNGEON_DEPTH.md`）。
#   ⚠ 見るのは ① 敵の強さがフロアで伸びる（⚠ フロア1 は 100%）② 帯を差し込むとその層から顔ぶれが変わる。
func _report_dungeon_depth() -> void:
	print("[DebugBoot] --- 深さ（⚠ 敵の強さ・帯）---")
	var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
	if GameManager.is_in_dungeon():
		GameManager.abandon_dungeon_run()
	GameManager.start_dungeon_run(dungeon_id)
	var battle_id: String = _find_dungeon_node_of_kind(GameStateKeys.DUNGEON_NODE_KIND_BATTLE)
	var boss_id: String = "d_boss"
	var slime_hp: int = int(MasterDataLoader.get_enemy("enemy_slime").get(GameStateKeys.STAT_HP, 0))
	var pct_1: int = GameManager.get_dungeon_enemy_stat_pct()
	var boss_atk_1: int = _wave_stat(GameManager.get_dungeon_node_wave(boss_id), GameStateKeys.STAT_ATK)
	for _i: int in range(3):
		GameManager.debug_mark_dungeon_boss_cleared()
		GameManager.descend_dungeon_floor()
	var pct_4: int = GameManager.get_dungeon_enemy_stat_pct()
	var boss_atk_4: int = _wave_stat(GameManager.get_dungeon_node_wave(boss_id), GameStateKeys.STAT_ATK)
	battle_id = _find_dungeon_node_of_kind(GameStateKeys.DUNGEON_NODE_KIND_BATTLE)
	var slime_hp_4: int = 0
	for _try: int in range(30):
		var wave: Dictionary = GameManager.get_dungeon_node_wave(battle_id)
		for raw: Variant in (wave.get("enemies", []) as Array):
			if str((raw as Dictionary).get("enemy_type_id", "")) == "enemy_slime":
				slime_hp_4 = int(((raw as Dictionary).get("stat_overrides", {}) as Dictionary).get(GameStateKeys.STAT_HP, 0))
		if slime_hp_4 > 0:
			break
	# ⚠ 2026-10-03（回6・人間「⚠ １あ」）：⚠ HP・攻撃には難ダンジョンの素の倍率（`enemy_base_stat_pct`）も掛かる＝能力ごとの倍率で数える。
	var base_pct: int = int(Balance.dungeon.enemy_base_stat_pct)
	var hp_pct_4: int = int(round(float(pct_4) * float(base_pct) / 100.0))
	var boss_atk_master: int = 30
	print("  強さ フロア1 = %d%% ／ フロア4 = %d%%（⚠ 100 と 130 が正解・伸び %d%%）／ HP・攻撃の素の倍率 %d%%" % [
		pct_1, pct_4, int(Balance.dungeon.enemy_stat_growth_pct_per_floor), base_pct
	])
	print("  ボスの攻撃 フロア1 = %d ／ フロア4 = %d（⚠ 表の 30 × %d%% ／ × %d%%） ／ スライムの HP フロア4 = %d（⚠ 素の %d × %d%%）" % [
		boss_atk_1, boss_atk_4, base_pct, hp_pct_4, slime_hp_4, slime_hp, hp_pct_4
	])
	var growth: int = int(Balance.dungeon.enemy_stat_growth_pct_per_floor)
	if pct_1 != 100 or pct_4 != 100 + growth * 3:
		push_error("[DebugBoot] 敵の強さがフロアで伸びていない")
	if boss_atk_1 != int(round(float(boss_atk_master) * float(base_pct) / 100.0)) \
			or boss_atk_4 != int(round(float(boss_atk_master) * float(hp_pct_4) / 100.0)) \
			or slime_hp_4 != int(round(float(slime_hp) * float(hp_pct_4) / 100.0)):
		push_error("[DebugBoot] 敵の値に強さが掛かっていない")

	# ② 帯を差し込む（⚠ 検査の中だけ・キャッシュを書き換える＝保存しない）。⚠ フロア4（31〜40層）から狼だけ・ボスは狼。
	var cache: Dictionary = MasterDataLoader._cache_dungeons[dungeon_id]
	var band_from: int = GameManager.get_dungeon_floor_first_layer()
	cache[GameManager.DUNGEON_MASTER_DEPTH_BANDS] = [{
		GameManager.DUNGEON_BAND_FROM_LAYER: band_from,
		GameManager.DUNGEON_MASTER_BATTLE_POOL: [{"enemies": [{"enemy_type_id": "enemy_wolf", "count": 4}]}],
	}]
	var banded: Dictionary = GameManager.get_dungeon_node_wave(battle_id)
	var first_enemy: String = str(((banded.get("enemies", []) as Array)[0] as Dictionary).get("enemy_type_id", ""))
	var boss_enemy: String = str(((GameManager.get_dungeon_node_wave(boss_id).get("enemies", []) as Array)[0] as Dictionary).get("enemy_type_id", ""))
	print("  帯（%d層から 狼×4）を差し込む -> 戦闘 '%s' ×%d（狼×4 が正解） ／ ボスは '%s'（帯に書いていない＝入口のまま）" % [
		band_from, first_enemy, int(((banded.get("enemies", []) as Array)[0] as Dictionary).get("count", 0)), boss_enemy
	])
	if first_enemy != "enemy_wolf" or boss_enemy != "boss_slime_king":
		push_error("[DebugBoot] 帯から顔ぶれが引けていない（または書いていない鍵まで変わった）")
	# ⚠ 手前の層（帯より浅い）は入口のまま。⚠ 帯の境目を1つ先へずらして同じマスで見る。
	(cache[GameManager.DUNGEON_MASTER_DEPTH_BANDS] as Array)[0][GameManager.DUNGEON_BAND_FROM_LAYER] = band_from + 100
	var before_band: Dictionary = GameManager.get_dungeon_node_wave(battle_id)
	var count_wolf4: bool = false
	for raw: Variant in (before_band.get("enemies", []) as Array):
		if int((raw as Dictionary).get("count", 0)) == 4:
			count_wolf4 = true
	print("  帯を %d層からにずらす -> 狼×4 が出ない=%s（true が正解＝手前は入口の表）" % [band_from + 100, str(not count_wolf4)])
	if count_wolf4:
		push_error("[DebugBoot] 帯より浅い層で帯の顔ぶれが出た")
	cache[GameManager.DUNGEON_MASTER_DEPTH_BANDS] = []
	GameManager.abandon_dungeon_run()
	_report_equip_drop()


# 装備のドロップ（2026-10-03・回4-b・`EXEC_EQUIP_DROP.md`・人間「⚠ １あ　⚠ ２あ　⚠ ３あ　⚠ ４あ」）。
func _report_equip_drop() -> void:
	print("[DebugBoot] --- 装備のドロップ（⚠ 拾った瞬間に等級・珍しい品・拠点の宝箱）---")
	var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
	GameManager.start_dungeon_run(dungeon_id)
	var grade_range: Vector2i = GameManager.get_dungeon_equip_grade_range(dungeon_id, 1)
	# ① 入口の帯：⚠ ボスの戦利品を 200 回引き、⚠ 装備の鍵と等級・珍しい品を数える。
	var keys: Dictionary = {}
	for _i: int in range(200):
		var _got: Dictionary = GameManager.call("_grant_dungeon_node_gains", GameStateKeys.DUNGEON_NODE_KIND_BOSS, true)
	for raw: Variant in GameManager.get_run_pending_loot(GameManager.RUN_KIND_DUNGEON):
		var key: String = str(raw)
		if GameManager.call("_is_equipment_item", GameManager.run_bag_item_id(key)):
			keys[key] = true
	var bad_grade: int = 0
	var rare: int = 0
	for key: Variant in keys:
		var grade: int = GameManager.run_bag_grade(str(key))
		if grade < grade_range.x or grade > grade_range.y:
			bad_grade += 1
		if GameManager.get_item_drop_min_grade(GameManager.run_bag_item_id(str(key))) > grade_range.y:
			rare += 1
	print("  入口の帯の範囲 = %s ／ 出た装備の鍵 %d 種（例 %s） ／ 範囲の外 %d（0 が正解） ／ 珍しい品 %d（0 が正解）" % [
		str(grade_range), keys.size(), str(keys.keys().slice(0, 3)), bad_grade, rare
	])
	if keys.is_empty() or bad_grade > 0 or rare > 0:
		push_error("[DebugBoot] 装備が等級つきで落ちていない（または珍しい品が入口で出た）")
	# ② 拾って持ち帰る：⚠ その等級の個体になる。
	if not keys.is_empty():
		var pick: String = str(keys.keys()[0])
		GameManager.call("_remove_run_pending_loot", GameManager.RUN_KIND_DUNGEON, pick)
		GameManager.clear_run_pending_loot(GameManager.RUN_KIND_DUNGEON)
		GameManager.call("_add_run_pending_loot", GameManager.RUN_KIND_DUNGEON, pick, 1)
		var taken: bool = GameManager.take_run_pending_loot(GameManager.RUN_KIND_DUNGEON, pick)
		var before: Dictionary = {}
		for view: Variant in GameManager.get_owned_instances():
			before[str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))] = true
		GameManager.debug_mark_dungeon_boss_cleared()
		var report: Dictionary = GameManager.retreat_from_dungeon()
		var made_grade: int = 0
		for view: Variant in GameManager.get_owned_instances():
			var id: String = str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
			if not before.has(id):
				made_grade = int(GameManager.get_equipment_instance(id).get(GameStateKeys.INSTANCE_GRADE, 0))
		print("  '%s' を拾う -> %s ／ 持ち帰ると個体の等級 %d（%d が正解） ／ 報告書の品 %s（品の ID でまとまる）" % [
			pick, str(taken), made_grade, GameManager.run_bag_grade(pick), str(GameManager.get_last_run_report().get(GameManager.REPORT_GRANTED, {}))
		])
		if not taken or made_grade != GameManager.run_bag_grade(pick):
			push_error("[DebugBoot] 拾った等級で個体が生まれていない")
		if (GameManager.get_last_run_report().get(GameManager.REPORT_GRANTED, {}) as Dictionary).has(pick):
			push_error("[DebugBoot] 報告書に鍵（item_id#等級）がそのまま残っている")
	# ③ 帯で範囲を 9〜9 にすると、⚠ 珍しい品も 9 で出る（⚠ 検査の中だけ・キャッシュを書き換える）。
	var cache: Dictionary = MasterDataLoader._cache_dungeons[dungeon_id]
	cache[GameManager.DUNGEON_MASTER_DEPTH_BANDS] = [{GameManager.DUNGEON_BAND_FROM_LAYER: 1, GameManager.DUNGEON_MASTER_EQUIP_GRADE: [9, 9]}]
	if GameManager.is_in_dungeon():
		GameManager.abandon_dungeon_run()
	GameManager.start_dungeon_run(dungeon_id)
	for _i: int in range(400):
		var _got: Dictionary = GameManager.call("_grant_dungeon_node_gains", GameStateKeys.DUNGEON_NODE_KIND_BOSS, true)
	var rare_seen: int = 0
	var not_nine: int = 0
	for raw: Variant in GameManager.get_run_pending_loot(GameManager.RUN_KIND_DUNGEON):
		var item_id: String = GameManager.run_bag_item_id(str(raw))
		if not GameManager.call("_is_equipment_item", item_id):
			continue
		if GameManager.run_bag_grade(str(raw)) != 9:
			not_nine += 1
		if GameManager.get_item_drop_min_grade(item_id) == 9:
			rare_seen += 1
	print("  帯で 9〜9 -> 等級9 以外 %d（0 が正解） ／ 珍しい品の種類 %d（1 以上が正解）" % [not_nine, rare_seen])
	if not_nine > 0 or rare_seen == 0:
		push_error("[DebugBoot] 帯の等級の範囲が効いていない（または珍しい品が出ない）")
	cache[GameManager.DUNGEON_MASTER_DEPTH_BANDS] = []
	GameManager.abandon_dungeon_run()
	# ④ 拠点の宝箱に装備の行が無い（`EQ-12`）。
	var equip_rows: int = 0
	for chest_id: Variant in MasterDataLoader.get_all_chests():
		var draw: Dictionary = MasterDataLoader.get_chest(str(chest_id)).get("draw", {})
		for row: Variant in (draw.get("entries", []) as Array):
			if GameManager.call("_is_equipment_item", str((row as Dictionary).get("item_id", ""))):
				equip_rows += 1
	print("  拠点の宝箱の装備の行 = %d（0 が正解）" % equip_rows)
	if equip_rows > 0:
		push_error("[DebugBoot] 拠点の宝箱に装備が残っている（EQ-12）")


func _wave_stat(wave: Dictionary, stat: String) -> int:
	var enemies: Array = wave.get("enemies", [])
	if enemies.is_empty():
		return 0
	var entry: Dictionary = enemies[0]
	var base: Dictionary = MasterDataLoader.get_enemy(str(entry.get("enemy_type_id", "")))
	return int((entry.get("stat_overrides", {}) as Dictionary).get(stat, base.get(stat, 0)))


# 鞄に入っている item_id について、拠点側の所持数を数える。
#
# ⚠ 素材（storage: material）と持ち物（storage: inventory）で数える先が違うので、
#   両方見る（GameManager._grant_item() が振り分けている先と同じ2つ）。
func _dungeon_owned_snapshot(bag: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var item_ids: Array = bag.keys()
	item_ids.sort()
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		# ⚠ get_item_count() が items.json の storage で materials / inventory を振り分ける。
		#   ⚠ get_material_count() を足さないこと（素材を二重に数える）。
		result[item_id] = GameManager.get_item_count(item_id)
	return result


# 難ダンジョンのランに入り、最初の battle ノードまで歩く（段階17-b）。
#
# ⚠ 戻り値はそのノードID（＝戦闘へ渡すもの）。⚠ 組めなかったら "" を返す。
# ⚠ ここで敵を組まない。⚠ 敵を引く口は GameManager.get_dungeon_node_wave() の1本で、
#   呼ぶのは戦闘画面（17-a の決め8）。
func _prepare_dungeon_battle() -> String:
	var dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()
	if dungeon_ids.is_empty():
		push_error("[DebugBoot] ダンジョンが1本も無い")
		return ""
	if not GameManager.start_dungeon_run(dungeon_ids[0]):
		push_error("[DebugBoot] start_dungeon_run が false: " + dungeon_ids[0])
		return ""

	# ⚠ 素の MAX HP を控える（§4-4 の一番の落とし穴。⚠ 最後にここが動いていたら赤）。
	_dungeon_base_max_hp = {}
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		_dungeon_base_max_hp[character_id] = int(
			GameManager.get_effective_stats(character_id).get(GameStateKeys.STAT_HP, 0)
		)
	print("[DebugBoot] --- 難ダンジョンの戦闘（段階17-b）---")
	print("  素のMAX HP = %s ／ ランのMAX HP = %s（入った時点では同じ値が正解）" % [
		str(_dungeon_base_max_hp), str(GameManager.get_dungeon_max_hp())
	])

	# 最初の battle ノードまで歩く。⚠ 進める先の先頭を選び続ける（_walk_dungeon_to_boss と同じ流儀）。
	var guard: int = 0
	while true:
		var here: String = str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
		)
		var kind: String = str(
			GameManager.get_dungeon_node(here).get(GameStateKeys.DUNGEON_NODE_KIND, "")
		)
		if kind == GameStateKeys.DUNGEON_NODE_KIND_BATTLE and guard > 0:
			print("  1本目：道中の battle ノード '%s' で戦う（%d手目）" % [here, guard])
			return here
		var moves: Array = GameManager.get_dungeon_moves()
		if moves.is_empty():
			push_error("[DebugBoot] battle ノードに着く前に進める先が無くなった: " + here)
			return ""
		if not GameManager.move_in_dungeon(str(moves[0])):
			push_error("[DebugBoot] move_in_dungeon が false: " + str(moves[0]))
			return ""
		guard += 1
		if guard > 50:
			push_error("[DebugBoot] 50手で battle ノードに着かない")
			return ""
	return ""


# 素の MAX HP の控え（_prepare_dungeon_battle が入れ、Driver へ渡す）。
#
# ⚠ この Node は change_scene で消えるので、⚠ 控えは Driver 側にも持たせる
#   （Driver は root に残る）。⚠ ここを見に行く形にすると、⚠ 戦闘が終わった
#     ころには自分が居ない。
var _dungeon_base_max_hp: Dictionary = {}


# 歩きながら relic のマスに着いたら1つ取る（段階17-e-2）。
#
# ⚠ 抽選なので relic に当たらない生成もある。⚠ そのときは何も出さずに戻る。
func _take_dungeon_relic_on_the_way() -> void:
	var guard: int = 0
	while guard < 50:
		var here: String = str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
		)
		var node: Dictionary = GameManager.get_dungeon_node(here)
		if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_RELIC 				and not bool(node.get(GameStateKeys.DUNGEON_NODE_CLEARED, false)):
			var choices: Array = GameManager.get_dungeon_relic_choices(here)
			if choices.is_empty():
				return
			var relic_id: String = str(choices[0])
			var owner: String = ""
			if GameManager.is_single_relic(relic_id):
				owner = str(GameManager.get_dungeon_active_members()[0])
			var before: int = GameManager.get_dungeon_relics().size()
			var took: bool = GameManager.take_dungeon_relic(here, relic_id, owner)
			print("  レリックを取る '%s'（%s） -> %s / 所持 %d -> %d" % [
				relic_id, "1人用 " + owner if owner != "" else "全体用", str(took),
				before, GameManager.get_dungeon_relics().size(),
			])
			print("  ⚠ 同じマスでもう1つ取る -> %s（false が正解＝1マス1つ）" % [
				str(GameManager.take_dungeon_relic(here, relic_id, owner))
			])
			for member: Variant in GameManager.get_party_members():
				print("    %s に効くレリック = %s" % [
					str(member), str(GameManager.get_dungeon_relic_passives(str(member)))
				])
			return
		var moves: Array = GameManager.get_dungeon_moves()
		if moves.is_empty():
			return
		if not GameManager.move_in_dungeon(str(moves[0])):
			return
		guard += 1


# ⚠⚠ ボスを倒した先のマップに「ショップへ」の行が出ているか（2026-09-20・人間の報告
#   「⚠ ボス倒したあとショップによれなかった」）。
#
# ⚠ GameManager の口（`get_dungeon_shop_entries()`）が 4 件返すことは上で見ている。
#   ⚠ ここで見るのは**画面が行を作るか**（⚠ 絵は取れないが、⚠ 子の数と大きさは取れる）。
# ⚠ `_ready()` は `add_child()` の中で走るので `await` は要らない（⚠ 子はその場でできる）。
# ⚠⚠ 開く前に拾い待ちと「遺物片の覚え」を空にする。
#   ⚠ 拾い待ちが残っていると `_ready()` が拾いものの窓を重ねる（⚠ 測るものが変わる）。
#   ⚠ 覚えが残っていると `ResourceGainEffect.play()` が飛び、⚠ 解放と取り合って赤が出る
#     （CLAUDE.md 10番・2026-09-20 に6本出した件）。
# ⚠⚠ 開く前に「ショップはもう見せた」を立てる（2026-09-20・A案を入れたあと）。
#   ⚠ 立てないと `_ready()` が **自動でショップへ遷移**し、⚠ 測るものが消えてシナリオが壊れる。
func _report_dungeon_map_shop_row() -> void:
	var _left: Dictionary = GameManager.clear_dungeon_pending_loot()
	var _gain: int = GameManager.take_last_dungeon_currency_gain()
	print("  ⚠ わかれ道の画面を出したか（開く前）= %s（false が正解）" % [
		str(GameManager.has_seen_dungeon_shop())
	])
	GameManager.mark_dungeon_shop_seen()

	# --- ① マップに「ショップへ」の行が出ていないこと（2026-09-21・決定48-b）---
	var scene: PackedScene = load("res://scenes/adventure/dungeon_map.tscn")
	if scene == null:
		push_error("[DebugBoot] dungeon_map.tscn が読めない")
		return
	var map: Node = scene.instantiate()
	add_child(map)
	var row: Node = map.get_node_or_null("Layout/ShopList")
	var row_children: int = row.get_child_count() if row != null else -1
	print("  ⚠ マップの「ショップへ」の行 = 子 %d 個（⚠ 0 が正解＝決定48-b で消した）" % row_children)
	if row_children != 0:
		push_error("[DebugBoot] E146 ⚠ 「ショップへ」の行が残っている（⚠ 入口が二重になる）")
	# ⚠ 続行・撤退もマップには出さない（⚠ 選ぶのはわかれ道の画面）。
	for button_name: String in ["DescendButton", "RetreatButton"]:
		var button: Node = map.find_child(button_name, true, false)
		if button is Control and (button as Control).visible:
			push_error("[DebugBoot] E146 ⚠ マップに %s が出ている（⚠ 入口が二重になる）" % button_name)
	remove_child(map)
	map.queue_free()

	# --- ② わかれ道の画面（決定48）---
	var clear_scene: PackedScene = load("res://scenes/adventure/dungeon_floor_clear.tscn")
	if clear_scene == null:
		push_error("[DebugBoot] E147 dungeon_floor_clear.tscn が読めない")
		return
	var clear: Node = clear_scene.instantiate()
	add_child(clear)
	var heading: Node = clear.find_child("Heading", true, false)
	var descend: Node = clear.find_child("DescendButton", true, false)
	var retreat: Node = clear.find_child("RetreatButton", true, false)
	var loot_box: Node = clear.find_child("LootBox", true, false)
	print("  ⚠ わかれ道：見出し='%s' ／ さらに潜る=%s ／ ここで戻る=%s ／ 手に入れたもの=子 %d 個" % [
		(heading as Label).text if heading is Label else "(無い)",
		str((descend as Control).visible) if descend is Control else "(無い)",
		str((retreat as Control).visible) if retreat is Control else "(無い)",
		loot_box.get_child_count() if loot_box != null else -1,
	])
	if heading == null or descend == null or retreat == null or loot_box == null:
		push_error("[DebugBoot] E147 ⚠ わかれ道の画面の形が変わった")
	elif (heading as Label).text == "" or not (retreat as Control).visible:
		push_error("[DebugBoot] E147 ⚠ 見出しが空か、⚠ 「ここで戻る」が出ていない")
	# ⚠⚠ 左上の「戻る」は出さない（人間「⚠ 2 は出さない」）。
	if clear.find_child("BackButton", true, false) != null:
		push_error("[DebugBoot] E147 ⚠ わかれ道の画面に「戻る」がある（⚠ 出さない決定）")
	remove_child(clear)
	clear.queue_free()


# `shot_dir=<パス>` を読む。⚠ 無ければ user://shots。
func _read_shot_dir() -> String:
	var args: Array = []
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for raw: Variant in args:
		var arg: String = str(raw)
		if arg.begins_with("shot_dir="):
			return arg.substr("shot_dir=".length())
	return SHOT_DIR_DEFAULT


# 中身が見えているノードの数（段階17-e・たいまつ）。
func _count_revealed_dungeon_nodes() -> int:
	var count: int = 0
	var nodes: Dictionary = GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_NODES, {})
	for node_id: Variant in nodes:
		if GameManager.is_dungeon_node_revealed(str(node_id)):
			count += 1
	return count


# その種類のノードまで進める（段階19-b）。⚠ 着けたらノードIDを、⚠ 無ければ "" を返す。
#
# ⚠ 進める先を1手ずつ幅優先で調べ、⚠ その種類に届く手だけを選ぶ。
#   ⚠ 「先頭を選び続ける」（_walk_dungeon_to_boss）では、⚠ 抽選で置かれた
#     宝箱のマスに当たるかどうかが運になり、⚠ 検証が起動ごとに通ったり通らなかったりする。
func _walk_dungeon_to_kind(kind: String) -> String:
	var nodes: Dictionary = GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_NODES, {})
	# ⚠ while true にしない。⚠ 戻り値のある関数だと「全ての経路が値を返さない」で
	#   パースエラーになる（⚠ _walk_dungeon_to_boss は void なので通っている）。
	for _guard: int in range(51):
		var here: String = str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
		)
		var here_node: Dictionary = GameManager.get_dungeon_node(here)
		# ⚠ 済み（cleared）のマスは目的地にしない。⚠ しないと、⚠ 宝箱を開けた直後に
		#   もう一度呼んだとき、⚠ その場から動かずに「開け済みのマス」を返す。
		if str(here_node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == kind \
				and not bool(here_node.get(GameStateKeys.DUNGEON_NODE_CLEARED, false)):
			return here
		var moves: Array = GameManager.get_dungeon_moves()
		if moves.is_empty():
			return ""
		var chosen: String = ""
		for move: Variant in moves:
			if _dungeon_kind_reachable_from(nodes, str(move), kind, {}):
				chosen = str(move)
				break
		if chosen == "":
			return ""
		if not GameManager.move_in_dungeon(chosen):
			push_error("[DebugBoot] _walk_dungeon_to_kind: move_in_dungeon が false: " + chosen)
			return ""
		# ⚠ 戦利品も拾い待ちへ行く（段階20-f）。⚠ 溜めたまま歩かない。
		_settle_dungeon_pending_loot()
	push_error("[DebugBoot] _walk_dungeon_to_kind: 50手で終わらない")
	return ""


# node_id から先（自分を含む）に、その種類のノードが在るか。
func _dungeon_kind_reachable_from(
		nodes: Dictionary, node_id: String, kind: String, seen: Dictionary
) -> bool:
	if seen.has(node_id):
		return false
	seen[node_id] = true
	var node: Variant = nodes.get(node_id, null)
	if not (node is Dictionary):
		return false
	# ⚠ cleared のマスは数えない（⚠ 目的地の判定と揃えること。⚠ ずれると、⚠ 進んだ先で
	#   「在るはずのものが無い」になり、⚠ 途中で止まる）。⚠ 状態は毎回 GameManager に聞く。
	if str((node as Dictionary).get(GameStateKeys.DUNGEON_NODE_KIND, "")) == kind \
			and not bool(GameManager.get_dungeon_node(node_id).get(GameStateKeys.DUNGEON_NODE_CLEARED, false)):
		return true
	# ⚠ 通路は {to, effect}（段階19-c-1）。⚠ str() で読まないこと。
	for raw_edge: Variant in ((node as Dictionary).get(GameStateKeys.DUNGEON_NODE_NEXT, []) as Array):
		if not (raw_edge is Dictionary):
			continue
		var to_id: String = str((raw_edge as Dictionary).get(GameStateKeys.DUNGEON_EDGE_TO, ""))
		if _dungeon_kind_reachable_from(nodes, to_id, kind, seen):
			return true
	return false


# 拾い待ちを片付ける（段階20-f）。⚠ 入るだけ入れて、⚠ 残りは置いていく。
#
# ⚠⚠ 戦利品も拾い待ちへ行くようになったので（人間の指示）、⚠ 1手進むたびに溜まる。
#   ⚠ 片付けないと、⚠ 次の宝箱の検証に前のマスの戦利品が混ざる。
# ⚠ 本番では画面がこれをやる。⚠ 道具は「選ぶ」を全部入れるで代用している。
func _settle_dungeon_pending_loot() -> void:
	if not GameManager.has_dungeon_pending_loot():
		return
	var _picked: Dictionary = GameManager.take_all_dungeon_pending_loot()
	var _left: Dictionary = GameManager.clear_dungeon_pending_loot()


# ボスに着くまで、⚠ 効果のある通路を優先して歩く（段階19-c-2）。
#
# 戻り値: 踏んだ通路の効果の配列（⚠ 効果の無い通路は入れない）。
#
# ⚠⚠ 「進める先の先頭」を選び続ける（_walk_dungeon_to_boss）だと、⚠ 効果は
#   5本に1本の抽選なので、⚠ 1本のランで1〜2種しか踏めない。⚠ 検証が起動ごとに
#   通ったり通らなかったりする（⚠ 実際にそうなって罠(HP)を1度も踏めていなかった）。
# ⚠ 通路の宝箱はその場で開ける（⚠ 持ち越しが残ると次の手で邪魔になる）。

# ⚠ 決定31 の「開けずに立ち去ると消える」は、⚠ ラン全体で最初の1個だけで見る
#   （⚠ 残りは今までどおり開ける。⚠ 開ける側の検証を殺さないため）。
var _corridor_discard_checked: bool = false


func _walk_dungeon_preferring_edges() -> Array[String]:
	var result: Array[String] = []
	for _step: int in range(51):
		var here: String = str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
		)
		var moves: Array = GameManager.get_dungeon_moves()
		if moves.is_empty():
			return result
		# ⚠ 効果のある通路を先に選ぶ。⚠ 無ければ先頭。
		var chosen: String = str(moves[0])
		var chosen_effect: String = ""
		for move: Variant in moves:
			var effect: String = str(
				GameManager.get_dungeon_edge(here, str(move)).get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")
			)
			if effect != "":
				chosen = str(move)
				chosen_effect = effect
				break
		if not GameManager.move_in_dungeon(chosen):
			push_error("[DebugBoot] _walk_dungeon_preferring_edges: move_in_dungeon が false: " + chosen)
			return result
		if chosen_effect != "":
			result.append(chosen_effect)
			# ⚠ 通路のできごとが画面に渡せる形で取れるか（段階20-d）。
			#   ⚠ ここが空だとモーダルが黙る（⚠ 人間が報告した「何も分からない」に戻る）。
			var edge_event: Dictionary = GameManager.get_last_dungeon_edge_event()
			print("    ⚠ 通路のできごと = %s" % str(edge_event))
			if str(edge_event.get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")) != chosen_effect:
				push_error("[DebugBoot] 通路のできごとが取れない（モーダルが黙る）: " + chosen_effect)
		# ⚠⚠ 決定31（2026-09-05）：⚠ 最初の1個は「開けずに立ち去る」を見る。
		#   ⚠ 人間の指示「宝箱はあとから開けれないようにしたい」。⚠ 持ち越しが残らないのが正解。
		if GameManager.has_pending_dungeon_corridor_chest() and not _corridor_discard_checked:
			_corridor_discard_checked = true
			var walked_away: bool = GameManager.discard_dungeon_corridor_chest()
			print("    ⚠ 通路の宝箱を開けずに立ち去る -> %s / 持ち越し = %s（false が正解＝決定31）" % [
				str(walked_away), str(GameManager.has_pending_dungeon_corridor_chest())
			])
			if GameManager.has_pending_dungeon_corridor_chest():
				push_error("[DebugBoot] 開けずに立ち去ったのに通路の宝箱が残っている（決定31）")
		elif GameManager.has_pending_dungeon_corridor_chest():
			var chest_result: Dictionary = GameManager.open_dungeon_corridor_chest()
			print("    ⚠ 通路の宝箱を開けた -> 拾い待ちへ %s" % str(chest_result["granted"]))
			if GameManager.has_pending_dungeon_corridor_chest():
				push_error("[DebugBoot] 通路の宝箱を開けたのに持ち越しが残っている")
			# ⚠ もう一度開けても何も出ない（⚠ 引き直せない）。
			if not (GameManager.open_dungeon_corridor_chest()["granted"] as Dictionary).is_empty():
				push_error("[DebugBoot] 通路の宝箱を二度開けられる")
		# ⚠ 拾い待ちは画面が処理する。⚠ 道具では入るだけ入れて先へ進む（段階20-e / 20-f）。
		_settle_dungeon_pending_loot()
	push_error("[DebugBoot] _walk_dungeon_preferring_edges: 50手で終わらない")
	return result


# ボスに着くまで進める先の先頭を選び続ける。
func _walk_dungeon_to_boss() -> void:
	var guard: int = 0
	while true:
		var moves: Array = GameManager.get_dungeon_moves()
		if moves.is_empty():
			return
		if not GameManager.move_in_dungeon(str(moves[0])):
			push_error("[DebugBoot] _walk_dungeon_to_boss: move_in_dungeon が false")
			return
		# ⚠ 戦利品も拾い待ちへ行く（段階20-f）。⚠ 溜めたまま歩かない。
		_settle_dungeon_pending_loot()
		guard += 1
		if guard > 50:
			push_error("[DebugBoot] _walk_dungeon_to_boss: 50手で終わらない")
			return


# ダンジョンのルートを「数える」（段階20-a）。
#
# 戻り値: {"routes": int, "reached": {node_id: true}, "dead_ends": [node_id]}
#
# ⚠⚠ 1本ずつ歩いて列挙しない。⚠ 1階が 8層 → 25層 になり、⚠ 列挙は指数で増えて
#   終わらなくなったため（⚠ 8層で181本。⚠ 25層では数えきれない）。
# ⚠ 数だけなら動的計画法で足りる：⚠ 深い層から「そのノードからボスへ何通りあるか」を
#   足し上げる。⚠ 層 L の通路は必ず層 L+1 へ向かうので閉路が無く、⚠ 層の降順に回せば
#   行き先の値が先に確定している。
# ⚠ 「通れないノード」は幅優先で入口から届くかを見る。⚠ 列挙は要らない。
#
# ⚠ _walk_all_routes()（シナリオ側）を借りない。⚠ 読むキーが別の定数だから
#   （あちらは FLOOR_NODE_NEXT）。⚠ 借りると、片方の綴りを変えたときに
#   もう片方の検証が黙って通らなくなる。
func _count_dungeon_routes(nodes: Dictionary, entry_id: String) -> Dictionary:
	# 1. 入口から届くノード（幅優先）。
	var reached: Dictionary = {}
	var queue: Array[String] = [entry_id]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if reached.has(here) or not nodes.has(here):
			continue
		reached[here] = true
		for to_id: String in _dungeon_edge_targets(nodes, here):
			if not reached.has(to_id):
				queue.append(to_id)

	# 2. 行き止まり（⚠ 届くのに出口が無く、⚠ ボスでもないノード）。
	var dead_ends: Array[String] = []
	for raw_id: Variant in reached:
		var node_id: String = str(raw_id)
		if not _dungeon_edge_targets(nodes, node_id).is_empty():
			continue
		if str((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
			continue
		dead_ends.append(node_id)
	dead_ends.sort()

	# 3. ルート数（⚠ 層の降順に足し上げる）。
	var by_layer_desc: Array = reached.keys()
	by_layer_desc.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((nodes[str(a)] as Dictionary).get(GameStateKeys.DUNGEON_NODE_LAYER, 0)) \
			> int((nodes[str(b)] as Dictionary).get(GameStateKeys.DUNGEON_NODE_LAYER, 0))
	)
	var ways: Dictionary = {}
	for raw_id: Variant in by_layer_desc:
		var node_id: String = str(raw_id)
		var targets: Array[String] = _dungeon_edge_targets(nodes, node_id)
		if targets.is_empty():
			# ⚠ ボスなら1通り（＝そこで終わり）。⚠ 行き止まりは0通り（＝ボスに着けない）。
			var is_boss: bool = str((nodes[node_id] as Dictionary).get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BOSS
			ways[node_id] = 1 if is_boss else 0
			continue
		var total: int = 0
		for to_id: String in targets:
			total += int(ways.get(to_id, 0))
		ways[node_id] = total

	return {
		"routes": int(ways.get(entry_id, 0)),
		"reached": reached,
		"dead_ends": dead_ends,
	}


# 層のノードを「行き先を共有するか」でグループに分けて数える（段階20-b）。
#
# ⚠⚠ 通常の層は次の層で合流するので1グループになる。⚠ 区画の入口層だけ
#   区画の数に分かれる。⚠ これが「区画と区画のあいだは合流しない」の直接の根拠。
# ⚠ 区画の番号を道具側で持たない（⚠ 生成の中だけの値）。⚠ 形だけを見る。
func _count_dungeon_next_groups(nodes: Dictionary, row: Array[String]) -> int:
	# ⚠ ノードの番号 -> グループの番号。⚠ 素朴な結合で足りる（1層は数ノード）。
	var group_of: Array[int] = []
	for i: int in range(row.size()):
		group_of.append(i)
	var targets: Array = []
	for node_id: String in row:
		targets.append(_dungeon_edge_targets(nodes, node_id))
	for i: int in range(row.size()):
		for j: int in range(i + 1, row.size()):
			var shares: bool = false
			for to_id: Variant in (targets[i] as Array):
				if str(to_id) in (targets[j] as Array):
					shares = true
					break
			if not shares:
				continue
			# ⚠ 共有していたら同じグループにまとめる（⚠ 大きい番号を小さいほうへ寄せる）。
			var from_group: int = group_of[j]
			var to_group: int = group_of[i]
			for k: int in range(row.size()):
				if group_of[k] == from_group:
					group_of[k] = to_group
	var seen: Dictionary = {}
	for g: int in group_of:
		seen[g] = true
	return seen.size()


# そのノードから出ている通路の行き先（段階20-a）。
#
# ⚠ 通路は {to, effect}（段階19-c-1）。⚠ str(raw) で読まないこと
#   （⚠ Dictionary の文字列表現が行き先IDとして扱われ、⚠ 検証が黙って通らなくなる）。
func _dungeon_edge_targets(nodes: Dictionary, node_id: String) -> Array[String]:
	var result: Array[String] = []
	var node: Variant = nodes.get(node_id, null)
	if not (node is Dictionary):
		return result
	for raw_edge: Variant in ((node as Dictionary).get(GameStateKeys.DUNGEON_NODE_NEXT, []) as Array):
		if not (raw_edge is Dictionary):
			push_error("[DebugBoot] 通路が {to, effect} になっていない: " + str(raw_edge))
			continue
		result.append(str((raw_edge as Dictionary).get(GameStateKeys.DUNGEON_EDGE_TO, "")))
	return result


# --- 埋め込み Window 同士のドラッグ（2026-09-15） ---
#
# ⚠ インベントリを別の窓に出せるかの材料。⚠ OS の別窓は前回の実機で「渡らない」と出ている。
# ⚠ ヘッドレスは窓を作れないので、Window は必ず埋め込みになる（⚠ 測れるのは埋め込みだけ）。
# ⚠ 入力は root に push_input で流す（⚠ 埋め込みの Window へは root が振り分ける）。

func _report_subwindow_drag() -> void:
	var root: Window = get_tree().root
	# ⚠ _ready() の中から add_child すると「Parent node is busy」で弾かれる（⚠ 1回目で踏んだ）。
	await get_tree().process_frame
	print("[DebugBoot] --- 埋め込み Window 同士のドラッグ ---")
	print("  DisplayServer = %s ／ 別窓を作れるか = %s ／ 埋め込み = %s ／ root の大きさ（直す前） = %s" % [
		DisplayServer.get_name(),
		DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS),
		root.gui_embed_subwindows,
		root.size,
	])
	# ⚠ ヘッドレスの root は 64 x 64（⚠ 1回目で踏んだ）。⚠ 基準の 1280 x 720 に広げてから測る。
	root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	print("  root の大きさ（直した後） = %s ／ 表示の変換 = %s（⚠ 拡大1・ずれ0 が前提）" % [
		root.size, root.get_final_transform(),
	])

	# ① 普通の Control 同士（⚠ 比べる基準）。
	var holder: Control = Control.new()
	holder.name = "DragProbeHolder"
	root.add_child(holder)
	var src_1: DragProbeSource = _make_probe_source(Vector2(100, 100))
	var dst_1: DragProbeTarget = _make_probe_target(Vector2(400, 100))
	holder.add_child(src_1)
	holder.add_child(dst_1)
	var ok_1: bool = await _drag_probe_case("① 普通の Control 同士", src_1, dst_1)
	if not ok_1:
		push_error("[DebugBoot] ① が渡らない。⚠ 入力の流し方が壊れているので ② ③ は信じない")
	root.remove_child(holder)
	holder.queue_free()

	# ② 埋め込み Window の中どうし。
	var win_2: Window = _make_probe_window("DragProbeWindow2", Vector2i(100, 300))
	var src_2: DragProbeSource = _make_probe_source(Vector2(20, 20))
	var dst_2: DragProbeTarget = _make_probe_target(Vector2(200, 20))
	win_2.add_child(src_2)
	win_2.add_child(dst_2)
	await _drag_probe_case("② 埋め込み Window の中どうし", src_2, dst_2)
	root.remove_child(win_2)
	win_2.queue_free()

	# ③ 埋め込み Window A → B。
	var win_a: Window = _make_probe_window("DragProbeWindowA", Vector2i(100, 300))
	var win_b: Window = _make_probe_window("DragProbeWindowB", Vector2i(600, 300))
	var src_3: DragProbeSource = _make_probe_source(Vector2(20, 20))
	var dst_3: DragProbeTarget = _make_probe_target(Vector2(20, 20))
	win_a.add_child(src_3)
	win_b.add_child(dst_3)
	await _drag_probe_case("③ 埋め込み Window A → B", src_3, dst_3)
	root.remove_child(win_a)
	root.remove_child(win_b)
	win_a.queue_free()
	win_b.queue_free()


func _make_probe_window(window_name: String, at: Vector2i) -> Window:
	var window: Window = Window.new()
	window.name = window_name
	window.borderless = true
	window.size = Vector2i(320, 160)
	window.position = at
	get_tree().root.add_child(window)
	return window


func _make_probe_source(at: Vector2) -> DragProbeSource:
	var source: DragProbeSource = DragProbeSource.new()
	source.name = "Source"
	source.position = at
	source.size = Vector2(80, 80)
	return source


func _make_probe_target(at: Vector2) -> DragProbeTarget:
	var target: DragProbeTarget = DragProbeTarget.new()
	target.name = "Target"
	target.position = at
	target.size = Vector2(80, 80)
	return target


# root から見た Control の真ん中。⚠ 埋め込み Window の中なら Window の位置を足す。
func _probe_root_point(control: Control) -> Vector2:
	var point: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	if window != get_tree().root:
		point += Vector2(window.position)
	return point


# 押す → 12歩で動かす → 離す。⚠ 受け取れたら true。
func _drag_probe_case(label: String, source: Control, target: DragProbeTarget) -> bool:
	var root: Window = get_tree().root
	await get_tree().process_frame
	await get_tree().process_frame
	var from: Vector2 = _probe_root_point(source)
	var to: Vector2 = _probe_root_point(target)

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = from
	press.global_position = from
	root.push_input(press)
	await get_tree().process_frame

	var steps: int = 12
	var dragging_seen: bool = false
	for i: int in range(1, steps + 1):
		var point: Vector2 = from.lerp(to, float(i) / float(steps))
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = point
		motion.global_position = point
		motion.relative = (to - from) / float(steps)
		root.push_input(motion)
		await get_tree().process_frame
		if source.get_viewport().gui_is_dragging() or root.gui_is_dragging():
			dragging_seen = true

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release)
	await get_tree().process_frame
	await get_tree().process_frame

	var passed: bool = target.received.size() == 1
	print("  %s：%s → %s ／ ドラッグが始まったか = %s ／ 受ける側に聞いた回数 = %d ／ 受け取った数 = %d ／ %s" % [
		label, from, to, dragging_seen, target.can_drop_calls, target.received.size(),
		"渡った" if passed else "渡らない",
	])
	return passed


# ⚠⚠ 画面を撮る役（2026-09-21・人間の許可「⚠ その実験もいいよ　画面とる」）。
#
# ⚠ `Driver` と同じ理由で root に残す。⚠ 画面を差し替えると debug_boot 自身が消えるため。
# ⚠⚠ 画面は必ず `SceneManager` 経由で開く。⚠ `add_child()` で直に足すと、
#   ⚠ **右上の通貨のような「画面が自分の `_ready()` で消すもの」が本番と違う状態で写る**
#   （⚠ 2026-09-21 の1枚目で踏んだ。⚠ `ResourceHud` がまだ生まれておらず、
#   ⚠ `dungeon_map.gd:91` の `set_shown(false)` が空振りして、⚠ 出ないはずの通貨が写っていた）。
class ShotTaker extends Node:

	# ⚠ 画面を開いてから撮るまでに置く間（⚠ 配置と初回の描き込みが落ち着くまで）。
	const SETTLE_FRAMES: int = 20
	# ⚠ 窓が1枚も描かないまま諦めるまで。⚠ 覆われている／最小化されていると進まない。
	const DRAW_TIMEOUT_FRAMES: int = 180
	# ⚠ デバッグのパネルは画面の右側を覆うので、⚠ 撮る前に消す（⚠ 既定で出ている）。
	const DEBUG_OVERLAY_NAME: String = "DebugOverlay"
	# ⚠ 外側の `SHOT_PREPARE_*` / `SHOT_AFTER_*` と同じ字。⚠ 内側のクラスから外の const は引けない。
	const PREPARE_DUNGEON: String = "dungeon"
	const PREPARE_FLOOR: String = "floor"
	const PREPARE_DUNGEON_BOSS: String = "dungeon_boss"
	const PREPARE_EQUIPMENT: String = "equipment"
	const AFTER_PART_POPOVER: String = "part_popover"
	# ⚠ 下ごしらえで使う品（⚠ 外側の `LAYOUT_PART_*` と同じ字。⚠ 内側から外の const は引けない）。
	const PART_WEAPON_ID: String = "weapon_iron_sword"
	const PART_ITEM_ID: String = "part_gem_atk_1"
	const PART_CHARACTER_ID: String = "char_swordsman"
	const AFTER_LOOT_OVERLAY: String = "loot_overlay"
	const AFTER_BATTLE_RESULT: String = "battle_result"
	const AFTER_MODAL_CONFIRM: String = "modal_confirm"
	const AFTER_LEVEL_UP_PRESS: String = "level_up_press"
	const AFTER_RELIC_PICK: String = "relic_pick"
	const AFTER_RUN_MENU: String = "run_menu"
	const AFTER_RELIC_LIST: String = "relic_list"
	const AFTER_MAP_STEP: String = "map_step"
	# ⚠ 届いた宝箱（2026-09-27）：⚠ 種類ごとに1個積む ／ ⚠ 画面の口で「次を開ける」を押す。
	const PREPARE_CHESTS: String = "chests"
	const PREPARE_REPORT_RETURNED: String = "report_returned"
	const PREPARE_REPORT_DEFEATED: String = "report_defeated"
	const PREPARE_SORTIE_DEPTH: String = "sortie_depth"
	const PREPARE_BOARD_CLEARED: String = "board_cleared"
	const AFTER_CHEST_OPEN: String = "chest_open"
	const AFTER_SORTIE_SIGN: String = "sortie_sign"
	const AFTER_SETTINGS_POMODORO: String = "settings_pomodoro"
	const AFTER_SETTINGS_AUDIO: String = "settings_audio"
	const AFTER_FORGE_STRIKE: String = "forge_strike"
	const AFTER_RECORDS_PICK: String = "records_pick"
	const AFTER_FOCUS_TOOLS_CLOCK: String = "focus_tools_clock"
	const AFTER_POMODORO_RUNNING: String = "pomodoro_running"
	const AFTER_MINI_ASK: String = "mini_ask"
	const AFTER_ITEM_SOURCE: String = "item_source"
	const AFTER_MINI_WINDOW: String = "mini_window"
	const AFTER_MINI_LIST: String = "mini_list"
	const AFTER_MINI_REFLECTION: String = "mini_reflection"
	const AFTER_SPECIAL_EFFECT: String = "special_effect"
	const AFTER_BOARD_HARD: String = "board_hard"
	const AFTER_POMODORO_SETTINGS: String = "pomodoro_settings"
	const AFTER_DEBUG_OVERLAY: String = "debug_overlay"
	const FORGE_STRIKE_WAIT_MS: int = 4000
	const SIGN_WAIT_MS: int = 8000
	const CHEST_RISE_WAIT_FRAMES: int = 90
	const AFTER_FORGE_PRESS: String = "forge_press"
	const FORGE_FX_WAIT_FRAMES: int = 60
	const AFTER_FORGE_FAIL: String = "forge_fail"
	const AFTER_GUIDE_SKIP: String = "guide_skip"
	const AFTER_SORTIE_PICK: String = "sortie_pick"
	# ⚠ 高レアの演出の途中（⚠ legendary は 1.4 秒で蓋が開く＝その手前で撮る）。
	const AFTER_CHEST_FX: String = "chest_fx"
	const PREPARE_TASKS: String = "tasks"
	const PREPARE_TASK_LOG: String = "task_log"
	const AFTER_TASK_DETAIL: String = "task_detail"
	const AFTER_TASK_PICK: String = "task_pick"
	const AFTER_TASK_LIST: String = "task_list"
	const AFTER_TASK_DELETE: String = "task_delete"
	const AFTER_TASK_LINKED: String = "task_linked"
	const AFTER_TASK_CALENDAR: String = "task_calendar"
	const AFTER_TASK_DETAIL_RUNNING: String = "task_detail_running"
	const AFTER_RECORDS_TASKS: String = "records_tasks"
	const CHEST_FX_WAIT_FRAMES: int = 50
	# ⚠ 窓を出してから撮るまでに置く間（⚠ 重ねたものが並び終わるまで）。
	const AFTER_FRAMES: int = 12

	var out_dir: String = ""
	var shots: Array = []

	func _ready() -> void:
		await _run()
		get_tree().quit()

	func _run() -> void:
		DirAccess.make_dir_recursive_absolute(out_dir)
		if not DirAccess.dir_exists_absolute(out_dir):
			push_error("[DebugBoot] ⚠ 出し先が作れない: " + out_dir)
			return
		print("[DebugBoot] --- 画面を撮る ---")
		print("  出し先 = %s" % out_dir)
		print("  画面の出し方 = %s ／ 窓の大きさ = %s" % [
			DisplayServer.get_name(), str(DisplayServer.window_get_size())
		])
		# ⚠ 鍵の掛かった画面は開けないので、⚠ 撮る前に全部開けておく
		#   （⚠ `tests/debug_overlay.gd` の「画面を全部解放」と同じことをしている）。
		var opened: int = 0
		for screen_id: String in GameManager.get_all_screen_ids():
			if GameManager.is_screen_unlocked(screen_id):
				continue
			GameManager.unlock_screen(screen_id)
			opened += 1
		print("  ⚠ 撮るために画面を %d 件 解放した（⚠ 保存はしない）" % opened)
		# ⚠ 下ごしらえ（`start_floor()` のスタミナ等）で資源が動くと演出が飛ぶ。
		#   ⚠ 飛んでいる最中に次の画面へ移らせないために黙らせる。
		# ⚠ ここは資源の変化から自動で流れる経路なので `set_muted()` が効く
		#   （⚠ 効かないのは `play()` を直に呼ぶ経路のほう）。
		# ⚠⚠ **これでは `resource_hud.gd:117` の赤2本は消えない**（⚠ 2026-09-21 に実測）。
		#   ⚠ 原因は別。⚠ §0-UI-Q-4 の報告を見ること
		ResourceGainEffect.set_muted(true)
		for raw: Variant in shots:
			await _take_one(raw as Dictionary)

	func _take_one(shot: Dictionary) -> void:
		var shot_name: String = str(shot.get("name", "shot"))
		if not _prepare(str(shot.get("prepare", ""))):
			push_error("[DebugBoot] ⚠ %s の下ごしらえが通らなかった" % shot_name)
			return
		var scene_path: String = str(shot.get("scene", ""))
		var data: Dictionary = (shot.get("data", {}) as Dictionary).duplicate()
		# ⚠ マスの ID はランを作るまで分からない（⚠ レリック選択）。⚠ 種で1つ探して入れる。
		var node_kind: String = str(shot.get("fill_node_id", ""))
		if node_kind != "":
			var node_id: String = _find_dungeon_node_of_kind(node_kind)
			if node_id == "":
				push_error("[DebugBoot] ⚠ %s の %s のマスが1つも無い" % [shot_name, node_kind])
				return
			data[TransferKeys.RUN_NODE_ID] = node_id
		if data.is_empty():
			SceneManager.change_scene(scene_path)
		else:
			SceneManager.change_scene_with_data(scene_path, data)
		var settle: int = int(shot.get("settle", SETTLE_FRAMES))
		for _i: int in range(settle):
			await get_tree().process_frame
		# ⚠⚠ 開いた画面が頼んだものと同じか（2026-09-22）。⚠ 条件を満たさない画面は
		#   ⚠ `_ready()` の中で自分で別の画面へ送り返す（⚠ `dungeon_floor_clear.gd` / `run_relic_select.gd`）。
		#   ⚠ 確かめないと**別の画面の絵がこの名前で保存される**＝台帳に嘘が載る。
		var opened: Node = get_tree().current_scene
		var opened_path: String = "" if opened == null else str(opened.scene_file_path)
		if opened_path != scene_path:
			push_error("[DebugBoot] ⚠⚠ %s は開かなかった（⚠ いま居るのは %s）＝保存しない" % [
				shot_name, opened_path
			])
			return
		# ⚠ 窓を出す手（⚠ 重ねるものはここで出す）。⚠ 出せなければ保存しない。
		if not await _after(str(shot.get("after", "")), opened, shot_name):
			return
		# ⚠ デバッグの窓を撮る枚（2026-10-03）だけは消さない。
		if str(shot.get("after", "")) != AFTER_DEBUG_OVERLAY:
			_hide_debug_overlay()
		# ⚠ 絵だけでは「切れている」のか「余白が無い」のか言い切れない。
		#   ⚠ 撮ると同時に寸法も取る（2026-09-21）。
		_measure(shot)
		var image: Image = await _capture_window()
		if image == null:
			push_error(
				"[DebugBoot] ⚠ %s は1枚も描かれなかった（⚠ 窓が覆われている／最小化されている疑い）"
				% shot_name
			)
			return
		var path: String = out_dir.path_join(shot_name + ".png")
		if image.save_png(path) != OK:
			push_error("[DebugBoot] ⚠ 保存できない: " + path)
			return
		print("  ✅ %s = %s（%d x %d）" % [
			shot_name, path, image.get_width(), image.get_height()
		])

	# 最深を `floors` にして、⚠ ランの外・ノルマ札1枚の姿にする（⚠ 最深を書く口は本番のランの終わりだけ＝本番の口で潜って持ち帰る）。
	func _prepare_best_floors(floors: int) -> bool:
		var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
		if GameManager.is_in_dungeon():
			GameManager.abandon_dungeon_run()
		if GameManager.get_dungeon_best_floors(dungeon_id) < floors:
			if not GameManager.start_dungeon_run(dungeon_id):
				return false
			for i: int in range(floors):
				GameManager.debug_mark_dungeon_boss_cleared()
				if i < floors - 1 and not GameManager.descend_dungeon_floor():
					return false
			var _back: Dictionary = GameManager.retreat_from_dungeon()
			GameManager.mark_run_report_seen()
		if GameManager.get_quota_ticket_count() < 1:
			GameManager.add_to_inventory(GameStateKeys.ITEM_QUOTA_TICKET, 1)
		return GameManager.get_dungeon_best_floors(dungeon_id) >= floors and GameManager.has_quota_ticket_for_entry()

	# タスクを並べる（⚠ 本番の口だけ）。⚠ 紙が溢れて送る姿を撮るために 9 件。⚠ 色・期限（今日・昨日・先）・タグ・🍅・終えた1件。
	func _prepare_tasks() -> bool:
		if not GameManager.get_tasks().is_empty():
			return true
		var today: String = GameDate.get_game_date_string()
		var specs: Array = [
			["企画書の下書きを書く", 0, TaskParts.shift_date(today, -1), ["仕事"], 3],
			["週報をまとめる", 3, today, ["仕事"], 1],
			["英単語を30個", 2, "", ["勉強"], 2],
			["メールの返信", 1, TaskParts.shift_date(today, 2), ["仕事"], 0],
			["部屋の片付け", 5, "", [], 0],
			["本を1章読む", 4, "", ["勉強", "読書"], 1],
			["請求書を出す", 0, TaskParts.shift_date(today, 5), [], 0],
			["ギターの練習", 2, "", ["趣味"], 0],
			["買い物リストを作る", 1, "", [], 0],
		]
		var first_id: String = ""
		for spec: Array in specs:
			var task_id: String = GameManager.add_task(str(spec[0]))
			if task_id == "":
				return false
			if first_id == "":
				first_id = task_id
			var _c: bool = GameManager.set_task_color(task_id, int(spec[1]))
			if str(spec[2]) != "":
				var _d: bool = GameManager.set_task_due(task_id, str(spec[2]))
			for tag: Variant in spec[3]:
				var _t: bool = GameManager.add_task_tag(task_id, str(tag))
			for _i: int in range(int(spec[4])):
				var _p: bool = GameManager.add_task_focus_seconds(task_id, 1500)
		var _m: bool = GameManager.set_task_memo(first_id, "結論を先に。図は3枚まで。")
		# ⚠ 終えた1件（⚠ 一覧では線を引いて残る＝`TK-6`）。
		var done_id: String = str((GameManager.get_tasks()[2] as Dictionary).get(GameStateKeys.TASK_ID, ""))
		return GameManager.set_task_done(done_id, true)

	# ⚠ 下ごしらえを増やすならここに1行。
	func _prepare(kind: String) -> bool:
		if kind == "":
			return true
		if kind == PREPARE_DUNGEON:
			if GameManager.is_in_dungeon():
				return true
			var dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()
			if dungeon_ids.is_empty():
				push_error("[DebugBoot] ⚠ ダンジョンが1本も無い")
				return false
			return GameManager.start_dungeon_run(str(dungeon_ids[0]))
		# ⚠⚠ ボスの先に立たせる（2026-09-22）。⚠ 「わかれ道」「商人」はここでないと居座れない。
		#   ⚠ ボスまで歩く手は使えない（⚠ 歩く口はマスを踏むだけ＝戦わずにボスを使い切る）。
		#   ⚠ だから `phase` を直に書く検証用の口を使う（⚠ リリース前に消す口・CLAUDE.md）。
		if kind == PREPARE_DUNGEON_BOSS:
			if not GameManager.is_in_dungeon():
				var boss_dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()
				if boss_dungeon_ids.is_empty():
					push_error("[DebugBoot] ⚠ ダンジョンが1本も無い")
					return false
				if not GameManager.start_dungeon_run(str(boss_dungeon_ids[0])):
					return false
			if GameManager.can_retreat_from_dungeon():
				return true
			if not GameManager.debug_mark_dungeon_boss_cleared():
				push_error("[DebugBoot] ⚠ ボスを倒した扱いにできなかった")
				return false
			# ⚠⚠ 「もう見せたか」を戻す。⚠ 立てたままだと `dungeon_map` が
			#   ⚠ わかれ道へ送らなくなる（⚠ 12枚目のマップの絵がその後の枚に化ける）。
			GameManager.clear_dungeon_shop_seen()
			return GameManager.can_retreat_from_dungeon()
		# ⚠⚠ 装飾の枠を出す（2026-09-22・回3）。⚠ 枠は等級3から開く（GAME_DESIGN.md 6-4）。
		#   ⚠ 外側の `_layout_fill_equipment_parts()` と同じ手順。⚠ 外側は画面を差し替えた時点で
		#   ⚠ 消えているので参照を持てない（⚠ マスを探す口と同じ理由でもう1つ持つ）。
		#   ⚠ 個体を作るのは `add_to_inventory()` の1本（CLAUDE.md 8番）。
		if kind == PREPARE_EQUIPMENT:
			GameManager.unlock_screen(GameStateKeys.SCREEN_DECORATION)
			var equip_id: String = _find_instance_of(PART_WEAPON_ID)
			if equip_id == "":
				GameManager.add_to_inventory(PART_WEAPON_ID, 1)
				equip_id = _find_instance_of(PART_WEAPON_ID)
			if equip_id == "":
				push_error("[DebugBoot] ⚠ %s の個体が作れなかった" % PART_WEAPON_ID)
				return false
			for material_id: Variant in MasterDataLoader.get_all_items():
				GameManager.add_material(str(material_id), 99999)
			for _i: int in range(3):
				var _forged: bool = GameManager.forge_equipment(equip_id)
			# ⚠ 刺す品そのものは**倉庫に無いと弾かれる**（⚠ `ui_part_reject_stock`）。
			#   ⚠ 鍛えるのに素材を食うので、⚠ 鍛えたあとに入れる（⚠ 先に入れても消える）。
			GameManager.add_to_inventory(PART_ITEM_ID, 1)
			if not GameManager.equip_instance(
				PART_CHARACTER_ID, GameStateKeys.EQUIP_WEAPON, equip_id
			):
				push_error("[DebugBoot] ⚠ 着けられなかった")
				return false
			var slots: Array = GameManager.get_part_entries(equip_id)
			if slots.is_empty():
				push_error("[DebugBoot] ⚠ 枠が1つも開かなかった（⚠ 鍛えられていない）")
				return false
			var slot_index: int = int((slots[0] as Dictionary).get(GameManager.PART_VIEW_INDEX, 0))
			if GameManager.attach_part(equip_id, slot_index, PART_ITEM_ID):
				return true
			# ⚠ 弾かれた理由は GameManager が持っている。⚠ ここで推測しない。
			push_error("[DebugBoot] ⚠ %s を枠%d に刺せない：%s" % [
				PART_ITEM_ID, slot_index,
				GameManager.get_part_reject_reason(equip_id, slot_index, PART_ITEM_ID),
			])
			return false
		if kind == PREPARE_CHESTS:
			# ⚠ 積む口は `grant_chest()` の1本。⚠ 抽選のハズレは false（⚠ 正常系）＝積めるまで試す。
			if GameManager.get_pending_chest_count() > 0:
				return true
			for chest_id: Variant in MasterDataLoader.get_all_chests().keys():
				for _attempt: int in range(20):
					if GameManager.grant_chest(str(chest_id), GameStateKeys.CHEST_SOURCE_DUNGEON):
						break
			return GameManager.get_pending_chest_count() > 0
		if kind == PREPARE_FLOOR:
			if GameManager.is_in_floor():
				return true
			# ⚠ `floor_1..5` は stages.json の中で `layers` を持つものだけ（`_report_floor()` と同じ引き方）。
			var floor_ids: Array[String] = []
			for stage_id: Variant in MasterDataLoader._cache_stages:
				if GameManager.is_floor_stage(str(stage_id)):
					floor_ids.append(str(stage_id))
			floor_ids.sort()
			if floor_ids.is_empty():
				push_error("[DebugBoot] ⚠ フロアが1本も無い")
				return false
			return GameManager.start_floor(floor_ids[0])
		if kind == PREPARE_REPORT_RETURNED or kind == PREPARE_REPORT_DEFEATED:
			# ⚠ 帰還報告書（2026-09-29）：⚠ ランを本番の口で終わらせて報告を作る（⚠ 鞄に宝箱・素材・装飾）。
			var dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()
			if not GameManager.is_in_dungeon() and not GameManager.start_dungeon_run(str(dungeon_ids[0])):
				return false
			var chest_ids: Array = MasterDataLoader.get_all_chests().keys()
			GameManager.add_to_dungeon_bag(str(chest_ids[0]), 2)
			GameManager.add_to_dungeon_bag(GameManager.get_material_ids()[0], 10)
			GameManager.add_to_dungeon_bag(PART_ITEM_ID, 1)
			if kind == PREPARE_REPORT_RETURNED:
				GameManager.debug_mark_dungeon_boss_cleared()
				var _returned: Dictionary = GameManager.retreat_from_dungeon()
			else:
				GameManager.abandon_dungeon_run(GameManager.RUN_END_DEFEATED)
			return GameManager.has_unseen_run_report()
		if kind == PREPARE_SORTIE_DEPTH:
			# ⚠ 潜る深さ（2026-10-03・決定49）：⚠ 本番の口でボスを3体倒して持ち帰る＝最深 3（30層）→ ⚠ 札を1枚持たせる。
			return _prepare_best_floors(3)
		if kind == PREPARE_TASKS:
			return _prepare_tasks()
		if kind == PREPARE_BOARD_CLEARED:
			if GameManager.is_in_floor():
				GameManager.abandon_floor()
			var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
			GameManager.mark_stage_cleared(str(order[0]))
			GameManager.mark_stage_cleared(str(order[1]))
			return true
		if kind == PREPARE_TASK_LOG:
			# ⚠ 終えたものを記録へ移す（⚠ 明日の「今」を渡す＝朝4:00 をまたいだ姿）。⚠ 2件目を終えてから移す＝記録が2行。
			if not _prepare_tasks():
				return false
			if GameManager.get_task_log().is_empty():
				var open_tasks: Array = GameManager.get_open_tasks()
				if not open_tasks.is_empty():
					var _done: bool = GameManager.set_task_done(str((open_tasks[0] as Dictionary).get(GameStateKeys.TASK_ID, "")), true)
				var _moved: int = GameManager.roll_over_done_tasks(Time.get_unix_time_from_system() + 86400.0)
			return not GameManager.get_task_log().is_empty()
		push_error("[DebugBoot] ⚠ 知らない下ごしらえ: " + kind)
		return false

	# ⚠⚠ 画面を開いたあとに窓を出す（2026-09-22・回1）。⚠ 増やすならここに1枝。
	#
	# ⚠⚠ **本番と同じ口から出すこと。** ⚠ 窓を単体のシーンとして開くと、⚠ 後ろが無い・幕が透けない
	#   ＝**本番と違う絵**になる（⚠ 09-21 に `add_child()` で踏んだのと同じ話）。
	# ⚠ 出せなかったら false。⚠ 呼ぶ側が保存を止める（⚠ 窓の無い絵をその名前で残さない）。
	func _after(kind: String, screen: Node, shot_name: String) -> bool:
		if kind == "":
			return true
		if kind == AFTER_LOOT_OVERLAY:
			# ⚠ マップ自身の口を呼ぶ（⚠ 本番も `_enter_chest_node()` からこれを呼ぶ）。
			#   ⚠ 宝箱のマスが無いランなら、⚠ 拾い待ち（通路の資源）の側で出す。
			var node_id: String = _find_dungeon_node_of_kind(GameStateKeys.DUNGEON_NODE_KIND_CHEST)
			if node_id == "" and not GameManager.has_dungeon_pending_loot():
				push_error("[DebugBoot] ⚠ %s は宝箱のマスも拾い待ちも無い" % shot_name)
				return false
			# ⚠ `call()` で呼ぶ。⚠ `Node` 型の変数から直に呼ぶと**静的解析で通らない**
			#   （⚠ `dungeon_map.gd` に `class_name` が無いため）。
			screen.call("_open_loot_overlay", node_id, false)
		elif kind == AFTER_BATTLE_RESULT:
			# ⚠ 戦って勝つ必要は無い。⚠ 器（`HUD/ResultView`）へ見本を流すだけ
			#   （⚠ `scenario=result` と同じ見本）。
			var view: BattleResultView = screen.get_node_or_null("HUD/ResultView") as BattleResultView
			if view == null:
				push_error("[DebugBoot] ⚠ %s の結果窓が見つからない（⚠ 道が変わった疑い）" % shot_name)
				return false
			view.show_result({
				BattleResultView.DATA_VICTORY: true,
				BattleResultView.DATA_HEADING: "3層 波 3 / 3",
				BattleResultView.DATA_ELAPSED_SEC: 84.0,
				BattleResultView.DATA_DAMAGE_TAKEN: 142,
				BattleResultView.DATA_REWARDS: MasterDataLoader.get_stage("floor_5").get("rewards", {}),
			})
		elif kind == AFTER_PART_POPOVER:
			# ⚠ 本番と同じ口（⚠ 枠のマスを押したときに呼ばれるもの）。
			# ⚠⚠ 2026-09-22（回3-b）：⚠ **空きの枠**を押す。⚠ 右の持ち物が
			#   ⚠ 「刺せる装飾」に切り替わるところを撮る（⚠ これが2手の1手目）。
			var equip_id: String = GameManager.get_equipped_instance_id(
				PART_CHARACTER_ID, GameStateKeys.EQUIP_WEAPON
			)
			var empty_index: int = -1
			for raw: Variant in GameManager.get_part_entries(equip_id):
				if not (raw is Dictionary):
					continue
				if (raw as Dictionary).get(GameManager.PART_VIEW_ENTRY, null) is Dictionary:
					continue
				empty_index = int((raw as Dictionary).get(GameManager.PART_VIEW_INDEX, 0))
				break
			if empty_index < 0:
				push_error("[DebugBoot] ⚠ %s は空きの枠が1つも無い" % shot_name)
				return false
			# ⚠ 2026-09-27：⚠ 持ち物の口（⚠ 右の紙で空きの枠か「刺す」を押したときに呼ばれるもの）。
			#   ⚠ 下ごしらえで刺した装飾は持ち物から減っているので、⚠ 並ぶ品を2つ足す（⚠ 本番の口 `add_to_inventory()`）。
			GameManager.add_to_inventory(PART_ITEM_ID, 2)
			screen.set("_selected_key", equip_id)
			screen.call("_on_attach_requested", equip_id, empty_index)
		elif kind == AFTER_RUN_MENU:
			var menu: RunMenuButton = screen.find_child("MenuButton", true, false) as RunMenuButton
			if menu == null:
				push_error("[DebugBoot] ⚠ %s にメニューが無い" % shot_name)
				return false
			menu.call("_open")
		elif kind == AFTER_MAP_STEP:
			# ⚠ 本番の口で1歩進め（`move_in_dungeon()`）、⚠ 画面の口で描き直す（`_rebuild()`）。
			var steps: Array = GameManager.get_dungeon_moves()
			if steps.is_empty() or not GameManager.move_in_dungeon(str(steps[0])):
				push_error("[DebugBoot] ⚠ %s で1歩も進めなかった" % shot_name)
				return false
			screen.call("_rebuild")
		elif kind == AFTER_RELIC_LIST:
			# ⚠ 本番の口でレリックを1つ持たせる：⚠ 隣のレリックのマスへ `move_in_dungeon()` で移り、⚠ `take_run_relic()` で取る。
			# ⚠⚠ マップはランダムなので、⚠ **隣にレリックのマスが無い回は空の窓を撮る**（⚠ どちらになったかを必ず print）。
			var relic_node: String = ""
			for move: Variant in GameManager.get_dungeon_moves():
				var node: Dictionary = GameManager.get_dungeon_node(str(move))
				if str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_RELIC:
					relic_node = str(move)
					break
			if relic_node != "" and GameManager.move_in_dungeon(relic_node):
				var picks: Array = GameManager.get_run_relic_choices(GameManager.RUN_KIND_DUNGEON, relic_node)
				var relic_id: String = str(picks[0]) if not picks.is_empty() else ""
				var owner: String = str(GameManager.get_party_members()[0]) if GameManager.is_single_relic(relic_id) else ""
				var took: bool = relic_id != "" and GameManager.take_run_relic(GameManager.RUN_KIND_DUNGEON, relic_node, relic_id, owner)
				print("  %s: 隣のレリック %s を取った = %s" % [shot_name, relic_id, str(took)])
			else:
				print("  %s: ⚠ 隣にレリックのマスが無い回 → 空の窓を撮る" % shot_name)
			screen.call("_open_relic_list")
		elif kind == AFTER_RELIC_PICK:
			# ⚠ 画面自身の口（⚠ カードの当たり・人の札が押されたときに呼ばれるもの）。
			var choices: Array = screen.get("_choices")
			if choices == null or choices.is_empty():
				push_error("[DebugBoot] ⚠ %s は候補が無い" % shot_name)
				return false
			var pick: String = str(choices[0])
			for raw: Variant in choices:
				if GameManager.is_single_relic(str(raw)):
					pick = str(raw)
					break
			screen.call("_on_card_pressed", pick)
			if GameManager.is_single_relic(pick):
				screen.call("_on_character_pressed", str(GameManager.get_party_members()[0]))
		elif kind == AFTER_GUIDE_SKIP:
			# ⚠ ガイドの「とばす」（⚠ 本物のボタン）。⚠ 押すと「見た」になり、⚠ 以後の枚には出ない。
			var skip_button: Node = screen.find_child("GuideSkip", true, false)
			if skip_button is BaseButton:
				(skip_button as BaseButton).pressed.emit()
			await get_tree().process_frame
		elif kind == AFTER_SORTIE_PICK:
			# ⚠ 3番の枠の面を押す（⚠ 本物の当たり）→ ⚠ 名簿に「◯番と入れ替わる」が出る。
			var slot: Node = screen.find_child("Slot_2", true, false)
			var hit: Node = null if slot == null else slot.find_child("Hit", true, false)
			if not (hit is BaseButton):
				push_error("[DebugBoot] ⚠ %s の3番の枠が押せない" % shot_name)
				return false
			(hit as BaseButton).pressed.emit()
			await get_tree().process_frame
		elif kind == AFTER_FOCUS_TOOLS_CLOCK:
			# ⚠ 柱時計の行を押す（⚠ 本物の行）→ ⚠ 見本が柱時計で動く。
			var clock_row: Node = screen.find_child("Tool_clock", true, false)
			if not (clock_row is LedgerRow):
				push_error("[DebugBoot] ⚠ %s に柱時計の行が無い" % shot_name)
				return false
			(clock_row as LedgerRow).pressed.emit()
			for _i: int in range(20):
				await get_tree().process_frame
		elif kind == AFTER_TASK_DETAIL:
			# ⚠ 1行目（⚠ 期限切れ・メモあり）を押して右に詳しく（⚠ 本物の行）。
			var first_row: Node = null
			for node: Node in screen.find_children("Task_*", "", true, false):
				if node is LedgerRow:
					first_row = node
					break
			if first_row == null:
				push_error("[DebugBoot] ⚠ %s にタスクの行が無い" % shot_name)
				return false
			(first_row as LedgerRow).pressed.emit()
			for _i: int in range(4):
				await get_tree().process_frame
		elif kind == AFTER_TASK_PICK:
			# ⚠ 10-05：⚠ 選ぶ窓は消した＝⚠ 集中を始める前のサイドバーの姿（⚠ 加護だけ進める）。
			var pick_select: Node = screen.find_child("ProtectionSelectView", true, false)
			if pick_select != null:
				(pick_select.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			for _i: int in range(3):
				await get_tree().process_frame
		elif kind == AFTER_TASK_LINKED:
			# ⚠ 加護（⚠ 出ていれば「始める」）→ サイドバーの1件目（⚠ 期限切れ）を押す。⚠ 始めない。
			var linked_select: Node = screen.find_child("ProtectionSelectView", true, false)
			if linked_select != null:
				(linked_select.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			var linked_row: Node = null
			for node: Node in screen.find_children("Side_*", "", true, false):
				if node is LedgerRow:
					linked_row = node
					break
			if linked_row == null:
				push_error("[DebugBoot] ⚠ %s のサイドバーに行が無い" % shot_name)
				return false
			(linked_row as LedgerRow).pressed.emit()
			for _i: int in range(4):
				await get_tree().process_frame
		elif kind == AFTER_TASK_DETAIL_RUNNING:
			# ⚠ 加護 → サイドバーの1件目 →「はじめる」→ その行の「詳しく」。
			var detail_select: Node = screen.find_child("ProtectionSelectView", true, false)
			if detail_select != null:
				(detail_select.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			var detail_row: Node = null
			for node: Node in screen.find_children("Side_*", "", true, false):
				if node is LedgerRow:
					detail_row = node
					break
			var detail_start: Node = screen.find_child("FocusView", true, false)
			detail_start = null if detail_start == null else detail_start.find_child("StartButton", true, false)
			if detail_row == null or not (detail_start is BaseButton):
				push_error("[DebugBoot] ⚠ %s でサイドバーの行か「はじめる」が無い" % shot_name)
				return false
			var detail_row_name: String = str(detail_row.name)
			(detail_row as LedgerRow).pressed.emit()
			for _i: int in range(3):
				await get_tree().process_frame
			(detail_start as BaseButton).pressed.emit()
			for _i: int in range(3):
				await get_tree().process_frame
			detail_row = screen.find_child(detail_row_name, true, false)
			var detail_button: Node = null if detail_row == null else detail_row.find_child("DetailButton", true, false)
			if not (detail_button is BaseButton):
				push_error("[DebugBoot] ⚠ %s に「詳しく」が無い" % shot_name)
				return false
			(detail_button as BaseButton).pressed.emit()
			for _i: int in range(8):
				await get_tree().process_frame
		elif kind == AFTER_TASK_CALENDAR:
			# ⚠ 4行目（⚠ 先の期限）を押す →「日付を選ぶ ▼」。
			var rows: Array = screen.find_children("Task_*", "", true, false)
			if rows.size() < 4:
				push_error("[DebugBoot] ⚠ %s にタスクの行が足りない" % shot_name)
				return false
			(rows[3] as LedgerRow).pressed.emit()
			for _i: int in range(4):
				await get_tree().process_frame
			var due_pick: Node = screen.find_child("DuePick", true, false)
			if not (due_pick is BaseButton):
				push_error("[DebugBoot] ⚠ %s に「日付を選ぶ」が無い" % shot_name)
				return false
			(due_pick as BaseButton).pressed.emit()
			for _i: int in range(6):
				await get_tree().process_frame
		elif kind == AFTER_TASK_DELETE:
			# ⚠ 1行目を押す →「消す」（⚠ 本物のボタン＝確かめの窓が出る。⚠ 「はい」は押さない）。
			for node: Node in screen.find_children("Task_*", "", true, false):
				if node is LedgerRow:
					(node as LedgerRow).pressed.emit()
					break
			for _i: int in range(4):
				await get_tree().process_frame
			var delete_button: Node = screen.find_child("DeleteButton", true, false)
			if not (delete_button is BaseButton):
				push_error("[DebugBoot] ⚠ %s に「消す」が無い" % shot_name)
				return false
			(delete_button as BaseButton).pressed.emit()
			for _i: int in range(6):
				await get_tree().process_frame
		elif kind == AFTER_TASK_LIST:
			# ⚠ 加護 → サイドバーの1件目 →「はじめる」→ ⚠ 残りを6割にして集中中の姿。
			var list_select: Node = screen.find_child("ProtectionSelectView", true, false)
			if list_select != null:
				(list_select.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			var list_row: Node = null
			for node: Node in screen.find_children("Side_*", "", true, false):
				if node is LedgerRow:
					list_row = node
					break
			if list_row == null:
				push_error("[DebugBoot] ⚠ %s のサイドバーに行が無い" % shot_name)
				return false
			(list_row as LedgerRow).pressed.emit()
			for _i: int in range(4):
				await get_tree().process_frame
			var list_start: Node = screen.find_child("FocusView", true, false)
			list_start = null if list_start == null else list_start.find_child("StartButton", true, false)
			if not (list_start is BaseButton):
				push_error("[DebugBoot] ⚠ %s で「はじめる」が無い" % shot_name)
				return false
			(list_start as BaseButton).pressed.emit()
			await get_tree().process_frame
			screen.set("time_left_sec", float(screen.get("phase_total_sec")) * 0.6)
			for _i: int in range(5):
				await get_tree().process_frame
		elif kind == AFTER_RECORDS_TASKS:
			var records_tabs: Node = screen.find_child("Tabs", true, false)
			if records_tabs == null or records_tabs.get_child_count() <= RecordsScreen.TAB_TASKS:
				push_error("[DebugBoot] ⚠ %s に「終わったタスク」のタブが無い" % shot_name)
				return false
			(records_tabs.get_child(RecordsScreen.TAB_TASKS) as BaseButton).pressed.emit()
			for _i: int in range(3):
				await get_tree().process_frame
		elif kind == AFTER_DEBUG_OVERLAY:
			var overlay: Node = get_tree().root.find_child("DebugOverlay", true, false)
			if overlay == null:
				push_error("[DebugBoot] ⚠ %s にデバッグの窓が無い" % shot_name)
				return false
			overlay.set("visible", true)
			for _i: int in range(4):
				await get_tree().process_frame
		elif kind == AFTER_POMODORO_SETTINGS:
			var settings_button: Node = screen.find_child("PomodoroSettingsButton", true, false)
			if not (settings_button is BaseButton):
				push_error("[DebugBoot] ⚠ %s に「ポモドーロの設定」が無い" % shot_name)
				return false
			(settings_button as BaseButton).pressed.emit()
			for _i: int in range(6):
				await get_tree().process_frame
		elif kind == AFTER_BOARD_HARD:
			# ⚠ 2枚目のタブ（⚠ 本物のタブの札）。⚠ 札は持たせない＝「ノルマ札が要る」の姿。
			#   ⚠ 前の枚の下ごしらえでダンジョンの途中＝「続きから」になる＝⚠ ランを終えてからタブを押し直す。
			if GameManager.is_in_dungeon():
				GameManager.abandon_dungeon_run()
			var board_tabs: Node = screen.find_child("Tabs", true, false)
			if board_tabs == null or board_tabs.get_child_count() < 2:
				push_error("[DebugBoot] ⚠ %s に掲示板のタブが無い" % shot_name)
				return false
			(board_tabs.get_child(0) as BaseButton).pressed.emit()
			await get_tree().process_frame
			(board_tabs.get_child(1) as BaseButton).pressed.emit()
			for _i: int in range(3):
				await get_tree().process_frame
		elif kind == AFTER_SPECIAL_EFFECT:
			# ⚠ いばらの鎧と竜殺しの大剣を入れ（⚠ 本番の口）→ ⚠ いばらの鎧の行を押す。
			GameManager.add_to_inventory("armor_thorn_mail", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
			GameManager.add_to_inventory("weapon_dragon_greatsword", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
			for _i: int in range(3):
				await get_tree().process_frame
			var thorn_row: Node = null
			for raw: Variant in GameManager.get_owned_instances():
				if str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == "armor_thorn_mail":
					thorn_row = screen.find_child("Row_" + str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")), true, false)
			if not (thorn_row is LedgerRow):
				push_error("[DebugBoot] ⚠ %s にいばらの鎧の行が無い" % shot_name)
				return false
			(thorn_row as LedgerRow).pressed.emit()
			for _i: int in range(3):
				await get_tree().process_frame
		elif kind == AFTER_MINI_WINDOW or kind == AFTER_MINI_LIST or kind == AFTER_MINI_REFLECTION:
			# ⚠ 設定（⚠ 検査用のファイル）で小窓をオン → ⚠ 加護「始める」→ 集中「開始」→ ⚠ 小窓（⚠ 窓が本当に小さくなる）。
			GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_WINDOW, true)
			var mini_select: Node = screen.find_child("ProtectionSelectView", true, false)
			if mini_select != null:
				(mini_select.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			# ⚠ 2026-10-05（回P-2）：⚠ タスクを選んでから始める（⚠ 小窓にタスクの行と「タスクを終える」を写す）。
			var mini_view: Node = screen.find_child("FocusView", true, false)
			if mini_view != null and kind == AFTER_MINI_WINDOW:
				mini_view.call("set_task", GameManager.add_task("企画書の下書きを書く"))
			var mini_start: Node = screen.find_child("StartButton", true, false)
			if not (mini_start is BaseButton):
				push_error("[DebugBoot] ⚠ %s で集中の「開始」が無い" % shot_name)
				return false
			(mini_start as BaseButton).pressed.emit()
			for _i: int in range(20):
				await get_tree().process_frame
			if not bool(screen.call("is_mini_window_active")):
				push_error("[DebugBoot] ⚠ %s で小窓にならない" % shot_name)
				return false
			if kind == AFTER_MINI_REFLECTION:
				screen.call("end_phase")
				for _i: int in range(20):
					await get_tree().process_frame
			if kind == AFTER_MINI_LIST:
				var mini_node: Node = screen.find_child("MiniWindow", true, false)
				if mini_node != null:
					mini_node.call("toggle_list")
				for _i: int in range(20):
					await get_tree().process_frame
		elif kind == AFTER_ITEM_SOURCE:
			var source_button: Node = screen.find_child("SourceButton", true, false)
			if not (source_button is BaseButton):
				push_error("[DebugBoot] ⚠ %s で「入手先を見る」が無い" % shot_name)
				return false
			(source_button as BaseButton).pressed.emit()
			for _i: int in range(10):
				await get_tree().process_frame
		elif kind == AFTER_MINI_ASK:
			# ⚠ まだ聞いていないことにして集中を始める（⚠ 窓は本番の口＝`_ask_mini_window()` が出す）。⚠ 聞いた印は窓が書き戻す。
			GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_ASKED, false)
			# ⚠ 前の撮影（53 ほか）で小窓がオンのまま＝⚠ オンなら聞かない作りなので、⚠ オフに戻してから始める。
			GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_WINDOW, false)
			var ask_select: Node = screen.find_child("ProtectionSelectView", true, false)
			if ask_select != null:
				(ask_select.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			var ask_start: Node = screen.find_child("StartButton", true, false)
			if not (ask_start is BaseButton):
				push_error("[DebugBoot] ⚠ %s で集中の「開始」が無い" % shot_name)
				return false
			(ask_start as BaseButton).pressed.emit()
			for _i: int in range(15):
				await get_tree().process_frame
		elif kind == AFTER_POMODORO_RUNNING:
			# ⚠ 加護を選ぶ（⚠ 出ていれば「始める」）→ ⚠ 集中の「開始」→ ⚠ 残りを4割にして道具の進みを見せる。
			var select_view: Node = screen.find_child("ProtectionSelectView", true, false)
			if select_view != null:
				(select_view.find_child("StartButton", true, false) as BaseButton).pressed.emit()
				for _i: int in range(3):
					await get_tree().process_frame
			var focus_start: Node = screen.find_child("StartButton", true, false)
			if not (focus_start is BaseButton):
				push_error("[DebugBoot] ⚠ %s で集中の「開始」が無い" % shot_name)
				return false
			(focus_start as BaseButton).pressed.emit()
			await get_tree().process_frame
			screen.set("time_left_sec", float(screen.get("phase_total_sec")) * 0.4)
			for _i: int in range(5):
				await get_tree().process_frame
		elif kind == AFTER_RECORDS_PICK:
			# ⚠ 装備の表のいちばん右下の等級の枠を押す（⚠ 本物の枠）。
			var grade_cells: Array = screen.find_children("Grade_*", "", true, false)
			var cell: Node = null if grade_cells.is_empty() else grade_cells[grade_cells.size() - 1]
			if not (cell is BaseButton):
				push_error("[DebugBoot] ⚠ %s で図鑑の枠が押せない" % shot_name)
				return false
			(cell as BaseButton).pressed.emit()
			for _i: int in range(3):
				await get_tree().process_frame
		elif kind == AFTER_FORGE_STRIKE:
			# ⚠ 「鍛える」（⚠ 画面の口）→ ⚠ 最後の一打の火花が飛んでいるところで撮る（⚠ 成功＝金の光）。
			screen.call("_on_forge_pressed")
			var strike_node: Node = screen.find_child("ForgeStrike", true, false)
			if not (strike_node is ForgeStrike):
				push_error("[DebugBoot] ⚠ %s で鍛える演出が出ない" % shot_name)
				return false
			var until: int = Time.get_ticks_msec() + FORGE_STRIKE_WAIT_MS
			# ⚠ 2打目の途中（⚠ 最後の一打の金の光は画面ぜんぶを塗る＝⚠ 金床と槌が見える姿を撮る）。
			#   ⚠ 1打＝`strike_ms`（⚠ 頭の待ち 0.4 ＋ 振り下ろし 0.3 ＋ 戻り 0.7）＝2打目が当たった直後まで時間で待つ。
			var strike_ms: int = (strike_node as Control).get_theme_constant(&"strike_ms", &"Forge")
			until = Time.get_ticks_msec() + int(float(strike_ms) * (0.4 + 1.0 + 0.3)) + 60
			while Time.get_ticks_msec() < until and is_instance_valid(strike_node):
				await get_tree().process_frame
		elif kind == AFTER_SETTINGS_POMODORO or kind == AFTER_SETTINGS_AUDIO:
			# ⚠ ポモドーロ＝3枚目 ／ 音＝2枚目のタブ（⚠ 本物のタブの札を押す）。
			var tab_index: int = 2 if kind == AFTER_SETTINGS_POMODORO else 1
			var tabs: Node = screen.find_child("Tabs", true, false)
			if tabs == null or tabs.get_child_count() <= tab_index or not (tabs.get_child(tab_index) is BaseButton):
				push_error("[DebugBoot] ⚠ %s の設定のタブが無い" % shot_name)
				return false
			(tabs.get_child(tab_index) as BaseButton).pressed.emit()
			await get_tree().process_frame
		elif kind == AFTER_SORTIE_SIGN:
			# ⚠ 「出撃する」（⚠ 画面の口）→ ⚠ 判が押されるまで待つ → ⚠ 出発の前で流れを止める（⚠ 撮影でフロアに入らない）。
			screen.call("_on_sortie_pressed")
			var stamp: Node = screen.find_child("AcceptStamp", true, false)
			if not bool(screen.get("_signing")) or not (stamp is Stamp):
				push_error("[DebugBoot] ⚠ %s で署名が始まらない（⚠ 出られない理由は帯の右端）" % shot_name)
				return false
			var until: int = Time.get_ticks_msec() + SIGN_WAIT_MS
			while (stamp as Stamp).modulate.a < 1.0 and Time.get_ticks_msec() < until:
				await get_tree().process_frame
			var sign_tween: Variant = screen.get("_sign_tween")
			if sign_tween is Tween and (sign_tween as Tween).is_valid():
				(sign_tween as Tween).kill()
			await get_tree().process_frame
		elif kind == AFTER_CHEST_FX:
			# ⚠ legendary の箱を選んで「次を開ける」（⚠ 画面の口）→ ⚠ 演出の途中で撮る。
			#   ⚠ 09-28 から演出は中身の等級で決まる＝⚠ メモリの中だけ閾値を 0 にして必ず出す（⚠ 強い演出も 0 から＝強いほうを撮る）。
			var legend: String = ""
			for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
				var chest_id: String = str((chest as Dictionary).get(GameStateKeys.CHEST_ID, ""))
				if not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)) \
						and GameManager.get_chest_rarity(chest_id) == GameManager.CHEST_RARITY_LEGENDARY:
					legend = chest_id
					break
			if legend == "":
				push_error("[DebugBoot] ⚠ %s は legendary の宝箱が無い" % shot_name)
				return false
			screen.set("_selected_kind", legend)
			var fx_theme: Theme = ThemeDB.get_project_theme()
			var saved_grades: Array[int] = [fx_theme.get_constant(&"fx_grade", &"ChestScreen"), fx_theme.get_constant(&"fx_strong_grade", &"ChestScreen")]
			fx_theme.set_constant(&"fx_grade", &"ChestScreen", 0)
			fx_theme.set_constant(&"fx_strong_grade", &"ChestScreen", 0)
			# ⚠ 資源の演出は撮影の頭（`_run`）で止めてある。⚠ ここで戻さない（⚠ 戻すと後の枚で飛び、終了時に赤）。
			screen.call("_on_next_pressed")
			fx_theme.set_constant(&"fx_grade", &"ChestScreen", saved_grades[0])
			fx_theme.set_constant(&"fx_strong_grade", &"ChestScreen", saved_grades[1])
			for _i: int in range(CHEST_FX_WAIT_FRAMES):
				await get_tree().process_frame
		elif kind == AFTER_FORGE_PRESS or kind == AFTER_FORGE_FAIL:
			# ⚠ 失敗の姿は成功率を 0 にして押す（⚠ メモリの中だけ。⚠ 押したらすぐ戻す）。
			var saved_pct: Array[int] = Balance.equipment.forge_success_pct_by_grade.duplicate()
			if kind == AFTER_FORGE_FAIL:
				var never: Array[int] = []
				for _i: int in range(saved_pct.size()):
					never.append(0)
				Balance.equipment.forge_success_pct_by_grade = never
			screen.call("_on_forge_pressed")
			Balance.equipment.forge_success_pct_by_grade = saved_pct
			# ⚠ 09-28：⚠ 鍛える演出の画面（`ForgeStrike`）を飛ばす（⚠ 途中の姿は `48_forge_strike`）。
			var strike: Node = screen.find_child("ForgeStrike", true, false)
			if strike is ForgeStrike:
				(strike as ForgeStrike).skip()
			# ⚠ 09-28 から結果は結果の画面（⚠ 紙が記録に変わる）。⚠ 判が押されて紙が光る・震えるまで待つ。
			await get_tree().process_frame
			var record: Node = screen.find_child("RecordPage", true, false)
			if record == null:
				push_error("[DebugBoot] ⚠ %s で鍛えられなかった（⚠ 記録の窓が出ない）" % shot_name)
				return false
			for _i: int in range(FORGE_FX_WAIT_FRAMES):
				await get_tree().process_frame
		elif kind == AFTER_CHEST_OPEN:
			# ⚠ 画面の口（⚠ 「まとめて開ける」を押したときに呼ばれるもの）。⚠ 種類の色の帯と、⚠ 初めての品のしおり紐が
			#   ⚠ 両方写るように全部開ける（⚠ 1個だと素材1枚になりがちで紐が写らない）。
			var pending: int = GameManager.get_pending_chest_count()
			# ⚠ 資源が増える演出は撮影の頭（`_run`）で止めてある（CLAUDE.md 10番）。⚠⚠ ここで `set_muted(false)` に戻さないこと
			#   （⚠ 09-28 に踏んだ：⚠ 戻すと後の枚で演出が飛び、⚠ 終了時に着地先が解放されて「Lambda capture ... was freed」が赤3本）。
			screen.call("_on_open_all_pressed")
			if GameManager.get_pending_chest_count() >= pending:
				push_error("[DebugBoot] ⚠ %s で宝箱を開けられなかった" % shot_name)
				return false
			# ⚠ 高レアの演出は台を押して飛ばす（⚠ 画面の口＝台の入力）。⚠ 演出の途中の姿は `39_chest_fx` が撮る。
			var skip: InputEventMouseButton = InputEventMouseButton.new()
			skip.button_index = MOUSE_BUTTON_LEFT
			skip.pressed = true
			await get_tree().process_frame
			(screen.find_child("Stage", true, false) as Control).gui_input.emit(skip)
			# ⚠ 札が浮かび上がり終わるまで待つ（⚠ 0.5 秒 ＋ 1枚ずつ 0.15 秒。⚠ 1秒ぶん見ておく）。
			for _i: int in range(CHEST_RISE_WAIT_FRAMES):
				await get_tree().process_frame
		elif kind == AFTER_LEVEL_UP_PRESS:
			# ⚠ 画面の口で判を押す（⚠ 昇級そのものは `level_up_character()`）。⚠ 押せない回は申請書のまま撮れる＝赤にする。
			var before: int = int(GameManager.get_character_growth("char_swordsman").get(GameStateKeys.GROWTH_LEVEL, 1))
			screen.call("_on_press_pressed")
			var after_level: int = int(GameManager.get_character_growth("char_swordsman").get(GameStateKeys.GROWTH_LEVEL, 1))
			print("  %s: 判を押した Lv %d → %d" % [shot_name, before, after_level])
			if after_level <= before:
				push_error("[DebugBoot] ⚠ %s で昇級できなかった" % shot_name)
				return false
		elif kind == AFTER_MODAL_CONFIRM:
			# ⚠⚠ **`Modal.confirm()` は撮るのに使えない**（⚠ 2026-09-22 に2手とも外れた）。
			#   ⚠ ① 直に呼ぶ → ⚠ **パースエラー**（`must be called with "await"`）
			#   ⚠ ② `Callable` 越しに呼ぶ → ⚠ **実行時に赤**（`Trying to call an async function without "await"`）
			#   ⚠ `await` してしまうと「はい／いいえ」が押されるまで戻らないので、⚠ 1枚も撮れない。
			# ⚠⚠ だから**器を作って返す1段下の口**を呼ぶ（⚠ `confirm()` も `notify()` もここを通る）。
			#   ⚠ 器を自分で `instantiate()` しないこと。⚠ 幅・暗幕・赤・間は向こうが持っている。
			# ⚠⚠ 押さないので**セーブは消えない**（⚠ 消すのは戻りを見る `title_screen.gd` の側）。
			var dlg: ModalDialog = Modal._enqueue(
				screen, "ui_title_restart_confirm", [], true, false, {
					Modal.OPTION_TITLE: tr("ui_title_restart_title"),
					Modal.OPTION_DANGER: true,
					Modal.OPTION_CONFIRM_LABEL: "ui_title_delete_save_hold",
					Modal.OPTION_STAMP: "ui_stamp_erased",
					Modal.OPTION_HOLD: "ui_title_delete_hold_hint",
				}
			)
			if dlg == null:
				push_error("[DebugBoot] ⚠ %s の窓が出せなかった" % shot_name)
				return false
		else:
			push_error("[DebugBoot] ⚠ 知らない窓の出し方: " + kind)
			return false
		for _i: int in range(AFTER_FRAMES):
			await get_tree().process_frame
		return true

	# ⚠ 持っている個体から1つ探す（⚠ 外側にも同じものが在る。⚠ 理由は下と同じ）。
	func _find_instance_of(item_id: String) -> String:
		for view: Variant in GameManager.get_owned_instances():
			if not (view is Dictionary):
				continue
			if str((view as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == item_id:
				return str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
		return ""


	# ⚠ いまのランの中から種で1つ探す（⚠ 外側にも同じものが在るが、⚠ 外側（`debug_boot`）は
	#   ⚠ 画面を差し替えた時点で消えているので参照を持てない＝ここに持つ）。
	func _find_dungeon_node_of_kind(kind: String) -> String:
		var nodes: Dictionary = GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_NODES, {})
		var ids: Array = nodes.keys()
		ids.sort()
		for entry: Variant in ids:
			var node_id: String = str(entry)
			if str((nodes.get(node_id, {}) as Dictionary).get(GameStateKeys.FLOOR_NODE_KIND, "")) == kind:
				return node_id
		return ""

	# ⚠⚠ `CanvasLayer` は `CanvasItem` ではない。⚠ `is CanvasItem` だけで見ると
	#   **黙って効かず、パネルが写ったままになる**（⚠ 2026-09-21 の2枚目で踏んだ）。
	# ⚠ 撮った画面の中の節点の位置と大きさを出す（2026-09-21）。
	#   ⚠ `shots` の行に `"measure": ["ノードへの道", ...]` を書くと出る。
	#   ⚠ 画面からはみ出していたら黄で知らせる（⚠ 絵では切れているか判断できない）。
	func _measure(shot: Dictionary) -> void:
		var paths: Array = shot.get("measure", [])
		if paths.is_empty():
			return
		var screen: Node = get_tree().current_scene
		if screen == null:
			return
		var view: Vector2 = Vector2(get_tree().root.size)
		for raw: Variant in paths:
			var node_path: String = str(raw)
			var node: Node = screen.get_node_or_null(node_path)
			if node == null or not (node is Control):
				push_warning("[DebugBoot] ⚠ 測れない: %s" % node_path)
				continue
			var rect: Rect2 = (node as Control).get_global_rect()
			var over_x: float = rect.end.x - view.x
			var over_y: float = rect.end.y - view.y
			print("    %s = %.0f,%.0f %.0f x %.0f ／ 右下 %.0f,%.0f（画面 %.0f x %.0f）" % [
				node_path, rect.position.x, rect.position.y, rect.size.x, rect.size.y,
				rect.end.x, rect.end.y, view.x, view.y,
			])
			if over_x > 0.5 or over_y > 0.5:
				push_warning("[DebugBoot] ⚠⚠ %s が画面からはみ出している（右 %.0f / 下 %.0f）" % [
					node_path, maxf(over_x, 0.0), maxf(over_y, 0.0)
				])


	func _hide_debug_overlay() -> void:
		var overlay: Node = get_tree().root.get_node_or_null(DEBUG_OVERLAY_NAME)
		if overlay == null:
			print("  ⚠ %s が見つからない（⚠ 名前が変わった疑い）" % DEBUG_OVERLAY_NAME)
			return
		if overlay is CanvasLayer:
			(overlay as CanvasLayer).visible = false
		elif overlay is CanvasItem:
			(overlay as CanvasItem).visible = false
		else:
			push_error("[DebugBoot] ⚠ %s を消せない型: %s" % [
				DEBUG_OVERLAY_NAME, overlay.get_class()
			])

	# ⚠ 窓が実際に描いた絵を1枚もらう。
	#
	# ⚠⚠ `await RenderingServer.frame_post_draw` は使わない。⚠ 窓が描いていないときに
	#   **永久に返ってこない**（⚠ `addons/ziva_agent/ziva_input_harness.gd:1049` に同じ注意書きがある）。
	# ⚠ 「描いた枚数」が進むのを上限つきで待ち、⚠ 進まなければ null を返して知らせる。
	func _capture_window() -> Image:
		var drawn_before: int = Engine.get_frames_drawn()
		var waited: int = 0
		while Engine.get_frames_drawn() < drawn_before + 2:
			if waited >= DRAW_TIMEOUT_FRAMES:
				return null
			await get_tree().process_frame
			waited += 1
		var texture: ViewportTexture = get_tree().root.get_texture()
		if texture == null:
			return null
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			return null
		return image


class DragProbeSource extends ColorRect:
	func _get_drag_data(_at_position: Vector2) -> Variant:
		return {"probe": str(name)}


class DragProbeTarget extends ColorRect:
	var can_drop_calls: int = 0
	var received: Array = []

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		can_drop_calls += 1
		return data is Dictionary and (data as Dictionary).has("probe")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		received.append(data)


# --- 拠点の宝箱（2026-09-15） ---

func _report_base_chest() -> void:
	await get_tree().process_frame
	print("[DebugBoot] --- 拠点の宝箱 ---")
	# ⚠ 抽選のハズレは false が返る（⚠ 正常系）。⚠ 種類ごとに2個積めるまで試す。
	for chest_id: Variant in MasterDataLoader.get_all_chests().keys():
		var granted: int = 0
		for attempt: int in range(20):
			if GameManager.grant_chest(str(chest_id), "debug_boot"):
				granted += 1
			if granted >= 2:
				break
	var kinds: Dictionary = {}
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if chest is Dictionary and not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)):
			kinds[str((chest as Dictionary).get(GameStateKeys.CHEST_ID, ""))] = true
	var before: int = GameManager.get_pending_chest_count()
	print("  積んだ宝箱 = %d 個 ／ 種類 = %d" % [before, kinds.size()])
	if before < 2:
		push_error("[DebugBoot] 宝箱を2個以上積めなかった")
		return

	# ⚠⚠ 2026-09-27（決定 `BS-21`）：⚠ 一覧は「届いた宝箱」の画面になった（⚠ 拠点の上の `ChestPanel` は消した）。
	#   ⚠ 画面を押して確かめる分（⚠ 行・選ぶ・次を開ける・まとめて開ける・戻る）は `scenario=ui_flow` へ移した。
	#   ⚠ ここに残すのは画面に依らない確かめだけ（⚠ IDの重なり・宝箱の絵の等級・窓の順番待ち）。
	var checks: Array = []
	# ⚠⚠ 鞄のマスに入る宝箱（2026-09-18）。⚠ 品のアイコンと同じ部品で、絵は宝箱・枠はレアリティの色。
	#   ⚠ items.json と chests.json の ID が重なっていないこと（⚠ 重なると宝箱が品として扱われる）。
	var overlap: Array[String] = []
	for kind: Variant in MasterDataLoader.get_all_chests().keys():
		if not MasterDataLoader.get_item(str(kind)).is_empty():
			overlap.append(str(kind))
	checks.append(["① items.json と chests.json のIDの重なり %s" % str(overlap), overlap.is_empty()])
	var chest_icon: ItemIcon = ItemIcon.create("floor_1_legendary", 0, 1)
	add_child(chest_icon)
	var legend_grade: int = int(ItemIcon.grade_of("floor_1_legendary", 0).get(ItemIcon.RESULT_GRADE, 0))
	var common_grade: int = int(ItemIcon.grade_of("floor_1_common", 0).get(ItemIcon.RESULT_GRADE, 0))
	checks.append([
		"① 宝箱のアイコン 絵=%s 名前=%s 等級 legendary=%d > common=%d" % [
			chest_icon.get_center_debug_text(), tr(GameManager.item_name_key("floor_1_legendary")),
			legend_grade, common_grade,
		],
		GameManager.is_chest_item("floor_1_legendary") and legend_grade > common_grade
			and not GameManager.is_chest_item("weapon_wooden_sword"),
	])
	chest_icon.queue_free()
	# ⚠ 知らせの窓の縁と題の帯（2026-09-18・人間の決定「全部のモーダルに付ける」）。
	#   ⚠ 前は宝箱の結果の窓で見ていた（⚠ 09-27 に宝箱は窓を出さなくなった）＝⚠ 素の Control を呼び出し元にして出す。
	var host: Control = Control.new()
	add_child(host)
	var _shown: ModalDialog = Modal.notify(host, "ui_warehouse_no_chest", [], false, {Modal.OPTION_TITLE: tr("ui_chest_title")})
	await get_tree().process_frame
	checks.append(["② 知らせの窓が出る", Modal._current != null and is_instance_valid(Modal._current)])
	if Modal._current != null and is_instance_valid(Modal._current):
		var dialog: ModalDialog = Modal._current
		var window_panel: PanelContainer = dialog.get_node("Blocker/Panel")
		checks.append([
			"② 題の帯が出る（題='%s' 高さ=%.0f 帯の面=%s 窓の面=%s）" % [
				dialog.title_label.text, dialog.title_bar.size.y,
				dialog.title_bar.theme_type_variation, window_panel.theme_type_variation,
			],
			dialog.title_bar.visible and dialog.title_bar.size.y >= 36.0
				and window_panel.theme_type_variation == &"WindowPanel",
		])
	# ⑤ ⚠ 順番待ちのモーダルの呼び出し元が先に消えても赤を出さない（`modal.gd` の穴・2026-09-16）。
	#   ⚠ 画面からは踏めない順番（⚠ 窓が出ている間は後ろを押せない）。⚠ ここでは合図を直に出して作る。
	#   ⚠ 1枚目が出ている間に2枚目を積む → ⚠ 呼び出し元を先に消す → ⚠ 1枚目を閉じる。
	var _queued: ModalDialog = Modal.notify(host, "ui_warehouse_no_chest", [], false, {})
	await get_tree().process_frame
	remove_child(host)
	host.queue_free()
	await get_tree().process_frame
	await _close_current_modal()
	checks.append(["⑤ 呼び出し元が消えた順番待ちでも赤を出さない（残り %d）" % Modal._queue.size(), Modal._queue.is_empty()])
	await _close_current_modal()

	for check: Variant in checks:
		print("  %s = %s（⚠ true が正解）" % [(check as Array)[0], (check as Array)[1]])
		if not bool((check as Array)[1]):
			push_error("[DebugBoot] 拠点の宝箱: " + str((check as Array)[0]))


# いま出ているモーダルを、⚠ 閉じるボタンと同じ口で閉じる。
#
# ⚠ 閉じたあとの片付けは1フレーム遅れるので2フレーム待つ。
# ⚠⚠ さらに、⚠ 2026-09-21 から**次の窓が出るまでに間が入る**（決定 `MD-8`・既定 150ms）。
#   ⚠ 待たずに `Modal._queue` を見ると「まだ残っている」で赤になる（⚠ その日に踏んだ）。
#   ⚠ 間の長さは Theme から引く（⚠ ここに 150 と書かない）。
func _close_current_modal() -> void:
	var gap_ms: int = 0
	if Modal._current != null and is_instance_valid(Modal._current):
		gap_ms = Modal._current.queue_gap_ms()
		Modal._current._on_close_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	if gap_ms > 0:
		# ⚠ 間より少し長く待つ（⚠ ちょうどだと取りこぼす）。
		await get_tree().create_timer(float(gap_ms) / 1000.0 + 0.05).timeout
		await get_tree().process_frame


# --- 倉庫の入口（2026-09-15 → ⚠ 2026-09-23 に入れ替えた） ---
#
# ⚠⚠ 倉庫の別窓（`InventoryWindow`）は 2026-09-23 に消した（人間「⚠ もう倉庫の別窓はいらない」）。
#   ⚠ 倉庫はギルドのカードから入るふつうの画面（⚠ 人間の決定「1ア」・決定 `BS-15`）。

func _report_inventory_window() -> void:
	# ⚠ SceneManager の常駐物は call_deferred で足される。⚠ 2フレーム待ってから見る。
	await get_tree().process_frame
	await get_tree().process_frame
	print("[DebugBoot] --- 倉庫の入口 ---")
	var checks: Array = []

	# ① 別窓が root に居ない。
	checks.append(["① root に倉庫の別窓が無い", get_tree().root.get_node_or_null("InventoryWindow") == null])
	# ② 右上の常駐に「倉庫」ボタンが無い。
	var hud: ResourceHud = ResourceHud.get_instance()
	checks.append(["② 右上の常駐が在る", hud != null])
	if hud != null:
		checks.append(["② 右上に倉庫ボタンが無い", hud.find_child("StorageButton", true, false) == null])

	# ③ 施設の帯に「持ち物」と「記録」が在り、⚠ 行き先のシーンが在る（⚠ 2026-09-26・回UI-3：
	#   ⚠ ギルドのカードをやめて帯にした＝決定 `NAV-6`）。
	var path: String = ""
	var records_path: String = ""
	for entry: Dictionary in BaseFacilityBar.facilities():
		var id: String = str(entry.get(FacilityBar.ENTRY_ID, ""))
		if id == BaseFacilityBar.BELONGINGS:
			path = str(entry.get(BaseFacilityBar.KEY_PATH, ""))
		elif id == BaseFacilityBar.RECORDS:
			records_path = str(entry.get(BaseFacilityBar.KEY_PATH, ""))
	checks.append(["③ 帯の行き先 %s が在る" % path, path != "" and ResourceLoader.exists(path)])
	# ⚠ 2026-09-28：記録は記録の画面（⚠ 前は持ち物の図鑑タブ）。
	checks.append(["③ 記録は記録の画面 %s" % records_path, records_path == "res://scenes/guild/records_screen.tscn" and ResourceLoader.exists(records_path)])
	if not GameManager.is_screen_unlocked(GameStateKeys.SCREEN_WAREHOUSE):
		GameManager.unlock_screen(GameStateKeys.SCREEN_WAREHOUSE)
	var base: Control = load(SCENE_BASE).instantiate()
	get_tree().root.add_child(base)
	await get_tree().process_frame
	var button: Button = base.find_child("Facility_" + BaseFacilityBar.BELONGINGS, true, false) as Button
	print("  帯の「持ち物」 = %s" % (button.text if button != null else "<無い>"))
	checks.append(["③ 拠点の帯に持ち物が出る", button != null])
	checks.append(["③ 帯の字が翻訳されている", button != null and not button.text.begins_with("ui_")])
	get_tree().root.remove_child(base)
	base.queue_free()

	# ④ 倉庫が「題と戻る」を持つ画面になっている。
	if path == "":
		push_error("[DebugBoot] 倉庫の入口: 行き先が無い")
		return
	var screen: WarehouseScreen = load(path).instantiate()
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	# ⚠ 2026-09-27（回UI-組 持ち物）：⚠ 題は「持ち物」・タブは紙のタブ4枚（装備・装飾・素材・図鑑＝人間「⚠ 2あ」）。
	var tab_count: int = screen.tabs.get_child_count()
	print("  題 = %s ／ タブの数 = %d（⚠ 4＝装備・装飾・素材・図鑑）" % [screen.header.title_key, tab_count])
	checks.append(["④ 題が持ち物", screen.header.title_key == "ui_facility_belongings"])
	checks.append(["④ タブが4つ", tab_count == 4])
	checks.append(["④ 戻るがつながっている", screen.header.back_pressed.is_connected(screen._on_back_pressed)])
	get_tree().root.remove_child(screen)
	screen.queue_free()

	for check: Variant in checks:
		print("  %s = %s（⚠ true が正解）" % [(check as Array)[0], (check as Array)[1]])
		if not bool((check as Array)[1]):
			push_error("[DebugBoot] 倉庫の入口: " + str((check as Array)[0]))



# --- つまんだ品のカーソルの絵（2026-09-15・段3b） ---
#
# ⚠ 見るのは画素だけ。⚠ 色が合っているか・ぼやけていないかは人間が実機で見る。

func _report_drag_cursor() -> void:
	var config: IconConfig = Balance.icon
	print("[DebugBoot] --- カーソルの絵 ---")
	print("  マスの大きさ = %d ／ 線画の大きさ = %d ／ 枠線 = %d" % [
		config.icon_size_px, config.glyph_font_size, config.icon_border_width,
	])
	# ⚠ 装備（等級3）／ 装飾（中身の絵あり）／ 素材。
	var cases: Array = [["weapon_iron_sword", 3], ["part_gem_hp_2", 0], ["part_rune_buff_1", 0]]
	for material_id: Variant in MasterDataLoader.get_all_items():
		if str(MasterDataLoader.get_item(str(material_id)).get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_MATERIAL:
			cases.append([str(material_id), 0])
			break
	for case: Variant in cases:
		var item_id: String = str((case as Array)[0])
		var grade: int = int((case as Array)[1])
		var image: Image = ItemDragCursor.build_image(item_id, grade)
		if image == null:
			push_error("[DebugBoot] %s のカーソルの絵が作れない" % item_id)
			continue
		var grade_color: Color = config.color_of_grade(
			int(ItemIcon.grade_of(item_id, grade).get(ItemIcon.RESULT_GRADE, config.default_grade))
		)
		# ⚠ 地でも枠でもない画素の数＝線画が乗った画素。
		# ⚠ 色は幅を持たせて比べる（⚠ 画像は 0〜255 の整数。⚠ is_equal_approx も to_rgba32 も
		#   ⚠ 丸めの向きで1段ずれて外れた・1〜2回目で踏んだ）。
		var glyph_pixels: int = 0
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				if not _cursor_color_close(pixel, config.icon_bg_color) and not _cursor_color_close(pixel, grade_color):
					glyph_pixels += 1
		var has_texture: bool = IconTextures.for_item(item_id) != null
		print("  %-22s 大きさ %d x %d ／ 角が等級の色 = %s ／ 線画 = %s ／ 線画の画素 = %d" % [
			item_id, image.get_width(), image.get_height(),
			_cursor_color_close(image.get_pixel(0, 0), grade_color), has_texture, glyph_pixels,
		])
		print("      角の色 = %s ／ 等級の色 = %s ／ 地の色 = %s ／ (2,20) の色 = %s" % [
			image.get_pixel(0, 0), grade_color, config.icon_bg_color, image.get_pixel(2, image.get_height() / 2),
		])
		if image.get_width() != config.icon_size_px or image.get_width() > 256:
			push_error("[DebugBoot] %s のカーソルの大きさが違う（⚠ Windows は 256 まで）" % item_id)
		if config.icon_border_width > 0 and not _cursor_color_close(image.get_pixel(0, 0), grade_color):
			push_error("[DebugBoot] %s のカーソルの角が等級の色ではない" % item_id)
		if has_texture and glyph_pixels == 0:
			push_error("[DebugBoot] %s は線画があるのにカーソルに乗っていない" % item_id)


# ============================================================
# ⚠⚠ 画面の本物のボタン・行を押して回る係（2026-09-27・人間「⚠ それ以外のやつはあなたが確認できると思うがどうか」）。
#
# ⚠ 押すのは**画面が持っている本物の器**（⚠ ボタンの `pressed`・台帳の行の `pressed`・枠の `pressed`）。
#   ⚠ 状態は GameManager の口で確かめる（⚠ 画面の中の数字を信じない）。⚠ 行き先は `current_scene` で確かめる。
# ⚠ 確かめの窓は、⚠ 出た窓の「はい」を押す（⚠ `Modal.confirm()` を待つのは画面の側）。
# ⚠ 撮影の係と同じく root に置く（⚠ 画面を差し替えても消えない）。⚠ 状態は書き換えるが保存しない。
# ⚠ 分からないもの（⚠ 色・手応え・気づけるか）はここでは見ない＝人間の見る回へ。
# ============================================================
class UiFlowRunner extends Node:

	const TRAINING: String = "res://scenes/guild/training_screen.tscn"
	const LEVEL_UP: String = "res://scenes/guild/level_up_screen.tscn"
	const BELONGINGS: String = "res://scenes/guild/warehouse_screen.tscn"
	const BARRACKS: String = "res://scenes/adventure/party_preset_screen.tscn"
	const ADVENTURE: String = "res://scenes/adventure/adventure_select.tscn"
	const FLOOR_MAP: String = "res://scenes/adventure/floor_map.tscn"
	const BASE: String = "res://scenes/base/base_screen.tscn"
	const CHEST: String = "res://scenes/base/chest_screen.tscn"
	const FORGE: String = "res://scenes/guild/forge_screen.tscn"
	const RECORDS: String = "res://scenes/guild/records_screen.tscn"
	const SETTINGS: String = "res://scenes/base/settings_screen.tscn"
	const REPORT: String = "res://scenes/adventure/run_report_screen.tscn"
	const FOCUS_TOOLS: String = "res://scenes/pomodoro/focus_tools_screen.tscn"
	const BATTLE: String = "res://scenes/adventure/battle.tscn"
	const FOLLOW_STRIKE_WAIT_SEC: float = 8.0
	const DUNGEON_FLOOR_CLEAR: String = "res://scenes/adventure/dungeon_floor_clear.tscn"
	const DUNGEON_MAP: String = "res://scenes/adventure/dungeon_map.tscn"
	const POMODORO: String = "res://scenes/pomodoro/pomodoro.tscn"
	const TRAINING_LIST: String = "res://scenes/guild/training_list_screen.tscn"
	const TASK_SCREEN: String = "res://scenes/base/task_screen.tscn"
	# ⚠ 一覧の画面は class_name を持たない＝⚠ 並びの口は script を読んで呼ぶ。
	const TrainingListScreenRef: GDScript = preload("res://scenes/guild/training_list_screen.gd")
	const HERO: String = "char_swordsman"
	const OTHER: String = "char_archer"
	const WEAPON_ID: String = "weapon_iron_sword"
	const PART_ID: String = "part_gem_atk_1"
	const POTION_ID: String = "stamina_potion"
	const WAIT_FRAMES: int = 4
	const OPEN_FRAMES: int = 10

	var _passed: int = 0
	var _failed: int = 0

	func _ready() -> void:
		print("[DebugBoot] --- 画面を押して回る（ui_flow）---")
		_setup()
		await _flow_training()
		await _flow_level_up()
		await _flow_nodes()
		await _flow_skills()
		var instance_id: String = await _flow_equip_tab()
		await _flow_belongings(instance_id)
		await _flow_belongings_tabs()
		await _flow_facility()
		await _flow_barracks()
		await _flow_quest_board()
		await _flow_chest()
		await _flow_settings()
		await _flow_run_report()
		await _flow_focus_tools()
		await _flow_special_effects()
		await _flow_quota_ticket()
		await _flow_dungeon_depth()
		await _flow_tasks()
		await _flow_autosave()
		await _flow_pomodoro_extras()
		await _flow_mini_ask()
		await _flow_return_paths()
		await _flow_item_sources()
		_flow_debug_tools()
		print("[DebugBoot] ui_flow: 通った %d ／ 落ちた %d" % [_passed, _failed])
		get_tree().quit()

	# --- 下ごしらえ（⚠ 本番の口だけ） ---

	func _setup() -> void:
		ResourceGainEffect.set_muted(true)
		# ⚠⚠ 効果音を鳴らさない（2026-10-02）：⚠ ヘッドレスで効果音（集中が終わったアラーム）を鳴らすと、
		#   ⚠ 終了時に「1 resources still in use at exit」の赤が出たり出なかったりした（⚠ 鳴らすと4回中3回・止めると4回中0回）。
		#   ⚠ 再生を `stop()` しても消えなかった＝⚠ 音を出す先が無いので、再生が片付かないまま終わる。⚠ 小窓のせいではなかった。
		#   ⚠ `SoundManager` は設定（`_config`）が無いと何も鳴らさない作り＝⚠ それを使う。
		SoundManager.set("_config", null)
		for screen_id: String in GameManager.get_all_screen_ids():
			GameManager.unlock_screen(screen_id)
		for material_id: String in GameManager.get_material_ids():
			GameManager.add_material(material_id, 99999)
		GameManager.add_to_inventory(WEAPON_ID, 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
		# ⚠ 装飾は多めに（⚠ 刺す1つ ＋ 段階を上げるのに同じ装飾を使う）。
		GameManager.add_to_inventory(PART_ID, 10)
		GameManager.add_to_inventory(POTION_ID, 3, GameStateKeys.ITEM_TYPE_CONSUMABLE)

	# --- 育成：札とタブ ---

	func _flow_training() -> void:
		var t: Node = await _open(TRAINING, {TransferKeys.CHARACTER_ID: HERO})
		if t == null:
			return
		var chips: Node = t.find_child("Chips", true, false)
		_check("育成：右上の札が3枚以上", chips != null and chips.get_child_count() >= 3)
		await _press(_hit_of(t, "Chip_" + OTHER))
		var other_name: String = tr(str(MasterDataLoader.get_character(OTHER).get("name_key", "")))
		_check("育成：札を押すと副題が %s" % other_name, (t as TrainingScreen).header.subtitle_label.text == other_name)
		_check("育成：札を押すと身上書の名前が %s" % other_name, _label_text(t, "Dossier", "NameLabel") == other_name)
		await _press(_hit_of(t, "Chip_" + HERO))
		await _press(_tab_button(t, 1))
		_check("育成：2枚目のタブでステータスノード", t.find_child("NodesPage", true, false) != null)
		await _press(_tab_button(t, 0))
		await _press(t.find_child("Row_" + TransferKeys.TRAINING_TAB_SKILLS, true, false))
		_check("育成：概要のスキルの行を押すとスキルのタブ", t.find_child("SkillsPage", true, false) != null)
		await _press(_tab_button(t, 0))

	# --- 昇級：申請書 → 判 → 続けて → 点を振りに行く ---

	func _flow_level_up() -> void:
		var t: Node = get_tree().current_scene
		await _press(t.find_child("LevelUpButton", true, false), OPEN_FRAMES)
		var l: Node = get_tree().current_scene
		_check("昇級：「昇級させる」で昇級申請書が開く", _path_of(l) == LEVEL_UP)
		if _path_of(l) != LEVEL_UP:
			return
		var before: int = _level()
		await _press(l.find_child("PressButton", true, false))
		_check("昇級：判を押すと Lv %d → %d" % [before, before + 1], _level() == before + 1)
		_check("昇級：判（昇級）が出る", l.find_child("Seal", true, false) is Stamp)
		await _press(l.find_child("AgainButton", true, false))
		_check("昇級：「続けて昇級させる」で申請書に戻る", l.find_child("PressButton", true, false) != null)
		await _press(l.find_child("PressButton", true, false))
		_check("昇級：続けてもう1回 Lv %d" % (before + 2), _level() == before + 2)
		await _press(l.find_child("GoNodesButton", true, false), OPEN_FRAMES)
		var t2: Node = get_tree().current_scene
		_check("昇級：「点を振りに行く」で育成のステータスノード", _path_of(t2) == TRAINING and t2.find_child("NodesPage", true, false) != null)

	# --- ステータスノード：＋ と 振り直す ---

	func _flow_nodes() -> void:
		var t: Node = get_tree().current_scene
		var spent: int = GameManager.get_stat_node_spent_points(HERO)
		var add: Button = null
		for node: Node in t.find_children("AddButton", "", true, false):
			if not (node as Button).disabled:
				add = node as Button
				break
		await _press(add)
		_check("割り振り：＋で使った点が増える（%d → %d）" % [spent, GameManager.get_stat_node_spent_points(HERO)], GameManager.get_stat_node_spent_points(HERO) > spent)
		await _press(t.find_child("ResetButton", true, false))
		_check("割り振り：振り直すで 0 に戻る", GameManager.get_stat_node_spent_points(HERO) == 0)

	# --- スキル：枠 → 候補 → 外す ---

	func _flow_skills() -> void:
		var t: Node = get_tree().current_scene
		await _press(_tab_button(t, 2))
		await _press(t.find_child("Slot_1", true, false))
		var slot: Node = t.find_child("Slot_1", true, false)
		_check("スキル：枠2を押すと行き先になる", slot is LedgerRow and (slot as LedgerRow).selected)
		var pick: String = ""
		var selected: Array = GameManager.get_selected_skills(HERO, GameManager.SLOT_KIND_SKILL)
		for raw: Variant in GameManager.get_skill_candidates(HERO, GameManager.SLOT_KIND_SKILL):
			if not (str(raw) in selected):
				pick = str(raw)
				break
		await _press(t.find_child("Candidate_" + pick, true, false))
		selected = GameManager.get_selected_skills(HERO, GameManager.SLOT_KIND_SKILL)
		_check("スキル：候補 %s を押すと枠2に入る" % pick, selected.size() > 1 and str(selected[1]) == pick)
		var slot_now: Node = t.find_child("Slot_1", true, false)
		await _press(slot_now.find_child("ClearButton", true, false) if slot_now != null else null)
		selected = GameManager.get_selected_skills(HERO, GameManager.SLOT_KIND_SKILL)
		_check("スキル：外すで枠2が空く", selected.size() < 2 or str(selected[1]) == "")

	# --- 装備のタブ：部位 → 候補 → 着ける・外す → 鍛冶場で鍛える ---

	func _flow_equip_tab() -> String:
		var t: Node = get_tree().current_scene
		await _press(_tab_button(t, 3))
		await _press(t.find_child("Slot_" + GameStateKeys.EQUIP_WEAPON, true, false))
		var instance_id: String = _instance_of(WEAPON_ID)
		await _press(t.find_child("Candidate_" + instance_id, true, false))
		await _press(t.find_child("EquipButton", true, false))
		_check("装備：「◯を着ける」で武器に着く", GameManager.get_equipped_instance_id(HERO, GameStateKeys.EQUIP_WEAPON) == instance_id)
		_check("装備：身上書の攻撃に緑の増分が出る", _label_text(t, "Stat_atk", "DeltaLabel") != "")
		await _press(t.find_child("UnequipButton", true, false))
		_check("装備：「外す」で外れる", GameManager.get_equipped_instance_id(HERO, GameStateKeys.EQUIP_WEAPON) == "")
		await _press(t.find_child("Candidate_" + instance_id, true, false))
		await _press(t.find_child("EquipButton", true, false))
		await _press(t.find_child("ForgeButton", true, false), OPEN_FRAMES)
		var f: Node = get_tree().current_scene
		# ⚠ 2026-09-27（人間「⚠ 3あ」）：⚠ 鍛冶場をその品を選んで開く（⚠ 前は持ち物）。
		_check("装備：「鍛冶場で鍛える」で鍛冶場がその品を選んで開く", _path_of(f) == FORGE and str(f.get("_selected")) == instance_id)
		await _flow_forge(instance_id)
		return instance_id

	# --- 鍛冶場（2026-09-27・`EQ-6`・`EQ-7`）：鍛える → 記録 ／ 失敗 ／ 確定成功の札 ／ 持ち物で見る ---

	func _flow_forge(instance_id: String) -> void:
		var f: Node = get_tree().current_scene
		if _path_of(f) != FORGE:
			return
		var row: Node = f.find_child("Item_" + instance_id, true, false)
		_check("鍛冶場：左の一覧でその品が選ばれている", row is LedgerRow and (row as LedgerRow).selected)
		var grade: int = _grade(instance_id)
		# ⚠ 09-28（人間「⚠ 鍛冶場で鍛えるとき、演出を入れたい　⚠ 別の画面でやる」）：⚠ 押すと演出の画面が被さり、⚠ 結果はまだ出ない。
		await _press(f.find_child("ForgeButton", true, false))
		var strike: Node = f.find_child("ForgeStrike", true, false)
		_check("鍛冶場：「鍛える」で演出の画面が被さる（結果はまだ・押すと飛ばす）",
			strike is ForgeStrike and (strike as ForgeStrike).is_playing() and f.find_child("RecordPage", true, false) == null)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		if strike is Control:
			(strike as Control).gui_input.emit(click)
		await _wait()
		_check("鍛冶場：演出を押すと飛ばして結果の画面", f.find_child("ForgeStrike", true, false) == null and f.find_child("RecordPage", true, false) != null)
		_check("鍛冶場：「鍛える」で等級 %d → %d" % [grade, _grade(instance_id)], _grade(instance_id) == grade + 1)
		# ⚠ 図鑑に新しい等級が載る（2026-09-28・`EXEC_CODEX_GRADES.md` §4）。
		var forged_item: String = str(GameManager.get_equipment_instance(instance_id).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		_check("鍛冶場：鍛えると図鑑にその等級が載る（%s %s）" % [forged_item, str(GameManager.get_codex_grades(forged_item))],
			_grade(instance_id) in GameManager.get_codex_grades(forged_item))
		# ⚠ 09-28（人間「⚠ 鍛冶の演出は、これも専用画面がいる」）：⚠ 結果は窓でなく結果の画面（⚠ タブと一覧が消え、紙いっぱいに記録）。
		var seal: Node = f.find_child("ResultStamp", true, false)
		var tabs: Node = f.find_child("Tabs", true, false)
		_check("鍛冶場：鍛えると結果の画面（記録・「成功」の判・タブと一覧が消える・窓は出ない）",
			_modal_of(f) == null and f.find_child("RecordPage", true, false) != null and f.find_child("ForgePage", true, false) == null
			and f.find_child("List", true, false) == null and tabs is Control and not (tabs as Control).visible
			and seal is Stamp and (seal as Stamp).label_key == "ui_forge_success")
		var again: Node = f.find_child("ContinueButton", true, false)
		_check("鍛冶場：結果の画面に「続けて鍛える」", again is Button and (again as Button).text == tr("ui_forge_continue") and not (again as Button).disabled)
		# ⚠ 09-28 人間「⚠ 続けて鍛えるで元の画面に戻らないで」＝⚠ その場でもう一度鍛え、結果の画面のまま。
		grade = _grade(instance_id)
		await _forge_press(again)
		_check("鍛冶場：「続けて鍛える」でその場でもう一度鍛える（等級 %d → %d・結果の画面のまま）" % [grade, _grade(instance_id)],
			_grade(instance_id) == grade + 1 and f.find_child("RecordPage", true, false) != null and f.find_child("ForgePage", true, false) == null
			and str(f.get("_selected")) == instance_id and not (tabs as Control).visible)
		# ⚠ 「戻る」は結果の画面から鍛える紙へ戻る（⚠ 拠点へは出ない）。
		f.call("_on_back_pressed")
		await get_tree().process_frame
		_check("鍛冶場：結果の画面で「戻る」は鍛える紙へ（拠点へは出ない）",
			get_tree().current_scene == f and f.find_child("ForgePage", true, false) != null and (tabs as Control).visible)
		# ⚠ 枠が開くまで鍛える（⚠ 等級3から・GAME_DESIGN.md 6-4）。⚠ 1回目は「鍛える」・あとは結果の画面の「続けて鍛える」。
		if _first_empty(instance_id) < 0:
			await _forge_press(f.find_child("ForgeButton", true, false))
			for _i: int in range(4):
				if _first_empty(instance_id) >= 0:
					break
				await _forge_press(f.find_child("ContinueButton", true, false))
			f.call("_on_back_pressed")
			await get_tree().process_frame

		# 失敗（`EQ-6`）：⚠ 成功率を 0 にして押す（⚠ メモリの中だけ。⚠ debug_boot は既定で 100 に置いている）。
		var saved: Array[int] = Balance.equipment.forge_success_pct_by_grade.duplicate()
		var never: Array[int] = []
		for _i: int in range(saved.size()):
			never.append(0)
		Balance.equipment.forge_success_pct_by_grade = never
		grade = _grade(instance_id)
		var cost: Dictionary = GameManager.get_forge_cost(instance_id)
		var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
		var before_material: int = GameManager.get_material_count(material_id)
		await _forge_press(f.find_child("ForgeButton", true, false))
		seal = f.find_child("ResultStamp", true, false)
		again = f.find_child("ContinueButton", true, false)
		_check("鍛冶場：失敗すると等級はそのまま（%d）・素材は減る（%d → %d）・「失敗」の判・「もう一度鍛える」" % [_grade(instance_id), before_material, GameManager.get_material_count(material_id)],
			_grade(instance_id) == grade and GameManager.get_material_count(material_id) < before_material and seal is Stamp and (seal as Stamp).label_key == "ui_forge_fail"
			and again is Button and (again as Button).text == tr("ui_forge_retry"))
		before_material = GameManager.get_material_count(material_id)
		await _forge_press(again)
		_check("鍛冶場：「もう一度鍛える」もその場で鍛える（素材 %d → %d・結果の画面のまま）" % [before_material, GameManager.get_material_count(material_id)],
			GameManager.get_material_count(material_id) < before_material and f.find_child("RecordPage", true, false) != null)
		f.call("_on_back_pressed")
		await get_tree().process_frame
		# 確定成功の札（`EQ-7`）：⚠ 1枚持たせ、⚠ 札を使うに切り替えて押す → ⚠ 成功率 0 でも成功・札が減る。
		GameManager.add_to_inventory(GameStateKeys.ITEM_FORGE_GUARANTEE_TOKEN, 1, GameStateKeys.ITEM_TYPE_CONSUMABLE)
		# ⚠ 札が増えたのを画面へ見せる（⚠ 画面は自分の操作でしか描き直さない＝一覧の行を押し直す）。
		await _press(f.find_child("Item_" + instance_id, true, false))
		var tokens: int = GameManager.get_forge_token_count()
		await _press(f.find_child("TokenCheck", true, false))
		_check("鍛冶場：札を使うに切り替えると成功 100%%（%s）" % _label_text(f, "ForgePage", "ChanceLabel"), _label_text(f, "ForgePage", "ChanceLabel") == tr("ui_forge_chance") % 100)
		await _forge_press(f.find_child("ForgeButton", true, false))
		_check("鍛冶場：確定成功の札で成功（等級 %d → %d・札 %d → %d）" % [grade, _grade(instance_id), tokens, GameManager.get_forge_token_count()],
			_grade(instance_id) == grade + 1 and GameManager.get_forge_token_count() == tokens - 1)
		Balance.equipment.forge_success_pct_by_grade = saved
		# ⚠ 「持ち物で見る」は結果の画面からも押せる（⚠ 手本の右下）。
		await _press(f.find_child("BelongingsButton", true, false), OPEN_FRAMES)
		var w: Node = get_tree().current_scene
		_check("鍛冶場：「持ち物で見る」で持ち物がその品を選んで開く", _path_of(w) == BELONGINGS and str(w.get("_selected_key")) == instance_id)

	# --- 持ち物：持ち主 ／ 鍛える ／ 刺す ／ 枠の吹き出しで外す ／ 分解 ---

	func _flow_belongings(instance_id: String) -> void:
		var w: Node = get_tree().current_scene
		if _path_of(w) != BELONGINGS:
			return
		var hero_name: String = tr(str(MasterDataLoader.get_character(HERO).get("name_key", "")))
		_check("持ち物：右の紙に「装備中：%s」" % hero_name, _label_text(w, "Detail", "OwnerLine").contains(hero_name))
		_check("持ち物：キャラの札は出ない", w.find_child("Chip_" + HERO, true, false) == null)
		# ⚠ 2026-09-27（人間「⚠ 3あ」）：⚠ 「鍛える」は鍛冶場をその品を選んで開く（⚠ ここでは鍛えない）。⚠ 「持ち物で見る」で戻る。
		var grade: int = _grade(instance_id)
		await _press(w.find_child("ForgeButton", true, false), OPEN_FRAMES)
		var f: Node = get_tree().current_scene
		_check("持ち物：「鍛える」で鍛冶場がその品を選んで開く（等級は %d のまま）" % _grade(instance_id), _path_of(f) == FORGE and str(f.get("_selected")) == instance_id and _grade(instance_id) == grade)
		await _press(f.find_child("BelongingsButton", true, false), OPEN_FRAMES)
		w = get_tree().current_scene
		if _path_of(w) != BELONGINGS:
			_check("持ち物：鍛冶場から持ち物へ戻れない", false)
			return
		var filled: int = _filled(instance_id)
		await _press(w.find_child("AttachButton", true, false))
		_check("持ち物：「刺す」で左が刺せる装飾になる", str(w.get("_attach_instance")) == instance_id)
		await _press(w.find_child("Row_" + PART_ID, true, false))
		_check("持ち物：装飾を押すと刺さる（%d → %d）" % [filled, _filled(instance_id)], _filled(instance_id) == filled + 1)
		_check("持ち物：刺したら一覧が戻る", str(w.get("_attach_instance")) == "")
		# 刺さっている枠 → 吹き出し → 外す → 確かめの窓の「はい」。
		var icon: PartSlotIcon = null
		for node: Node in w.find_children("PartSlot_*", "", true, false):
			if node is PartSlotIcon and (node as PartSlotIcon).get_part_entry() is Dictionary and not ((node as PartSlotIcon).get_part_entry() as Dictionary).is_empty():
				icon = node as PartSlotIcon
				break
		if icon != null:
			icon.pressed.emit(icon.get_part_view())
			await _wait()
		var popover: Node = _first_of_type(w, "SlotActionPopover")
		_check("持ち物：刺さっている枠を押すと吹き出し", popover != null)
		if popover != null:
			await _press(popover.find_child("DetachButton", true, false))
			await _confirm_modal()
		_check("持ち物：吹き出しの「外す」→ はい で枠が空く", _filled(instance_id) == filled)
		# 分解：⚠ 着けている品は押せない ／ ⚠ 外してから（⚠ 外すのは本番の口）→ 確かめの窓の「はい」で無くなる。
		var melt: Node = w.find_child("DismantleButton", true, false)
		_check("持ち物：着けている品の「分解」は押せない", melt is Button and (melt as Button).disabled)
		GameManager.unequip_instance(HERO, GameStateKeys.EQUIP_WEAPON)
		await _wait()
		await _press(w.find_child("DismantleButton", true, false))
		await _confirm_modal()
		_check("持ち物：「分解」→ はい で品が無くなる", GameManager.get_equipment_instance(instance_id).is_empty())

	# --- 持ち物：装飾の段階 ／ 捨てる ／ 図鑑 ---

	func _flow_belongings_tabs() -> void:
		var w: Node = get_tree().current_scene
		if _path_of(w) != BELONGINGS:
			return
		await _press(_tab_button(w, 1))
		await _press(w.find_child("Row_" + PART_ID, true, false))
		var before: int = GameManager.get_item_count(PART_ID)
		await _press(w.find_child("PartUpgradeButton", true, false))
		_check("持ち物：装飾の「段階を上げる」で %s が減る（%d → %d）" % [PART_ID, before, GameManager.get_item_count(PART_ID)], GameManager.get_item_count(PART_ID) < before)
		await _press(_tab_button(w, 2))
		await _press(w.find_child("Row_" + POTION_ID, true, false))
		# ⚠ 「捨てる」は消した（2026-10-03・回3-d・`EQ-14`）＝ボタンが無いのが正解。
		_check("持ち物：消耗品に「捨てる」が無い（拠点に容量は無い）", w.find_child("DiscardButton", true, false) == null)
		# ⚠ 2026-09-28（人間「⚠ 4あ」）：⚠ 図鑑タブは記録の画面へ移した＝持ち物は3枚。
		_check("持ち物：タブは装備・装飾・素材の3枚（図鑑は記録へ）", _tab_button(w, 2) != null and _tab_button(w, 3) == null)

	# --- 施設の帯：育成 → 持ち物 ---

	func _flow_facility() -> void:
		var t: Node = await _open(TRAINING, {TransferKeys.CHARACTER_ID: HERO})
		if t == null:
			return
		await _press(t.find_child("Facility_" + BaseFacilityBar.BELONGINGS, true, false), OPEN_FRAMES)
		_check("施設の帯：「持ち物」で持ち物が開く", _path_of(get_tree().current_scene) == BELONGINGS)
		var w: Node = get_tree().current_scene
		await _press(w.find_child("Facility_" + BaseFacilityBar.RECORDS, true, false), OPEN_FRAMES)
		var r: Node = get_tree().current_scene
		_check("施設の帯：「記録」で記録の画面（図鑑）が開く", _path_of(r) == RECORDS and r.find_child("CodexHeading", true, false) != null)
		# ⚠ 09-27 の見る回で「育成」を戻した（⚠ 人間「⚠ 育成タブを復活させたほうがいい」）。
		_check("施設の帯：「育成」がある", r.find_child("Facility_" + BaseFacilityBar.TRAINING, true, false) != null)
		# ⚠ 09-28 人間「⚠ 鍛冶場を装備以外のところからいけるようにしたい」＝⚠ 持ち物と同じ解放で帯に出る。
		# ⚠ `_setup()` は全部を解放している＝⚠ 帯の定義で「解放の条件が持ち物と同じ」を見る。
		var unlocks: Dictionary = {}
		for entry: Dictionary in BaseFacilityBar.facilities():
			unlocks[str(entry.get(FacilityBar.ENTRY_ID, ""))] = str(entry.get(BaseFacilityBar.KEY_UNLOCK, ""))
		_check("施設の帯：「鍛冶場」は持ち物と同じ解放で出る（%s）" % str(unlocks.get(BaseFacilityBar.FORGE, "")),
			r.find_child("Facility_" + BaseFacilityBar.FORGE, true, false) != null
			and unlocks.get(BaseFacilityBar.FORGE, "?") == unlocks.get(BaseFacilityBar.BELONGINGS, "!"))
		await _flow_records()

	# --- ノルマ札（2026-10-02・回UI-仕組み⑧・`EXEC_QUOTA_TICKET.md`・人間「⚠ 1あ　⚠ 2あ　⚠ 3あ　⚠ 4あ」） ---

	func _flow_quota_ticket() -> void:
		const TICKET: String = GameStateKeys.ITEM_QUOTA_TICKET
		if GameManager.is_in_dungeon():
			GameManager.abandon_dungeon_run()
		var have: int = GameManager.get_quota_ticket_count()
		if have > 0:
			GameManager.call("_remove_from_inventory", TICKET, have)
		GameManager.add_gold(99999)
		var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
		# 0 枚：⚠ 掲示板の難ダンジョンは押せず「ノルマ札が要る」。
		var q: Node = await _open(ADVENTURE, {})
		await _press(_tab_button(q, 1))
		var take: Node = q.find_child("DungeonCard_" + dungeon_id, true, false).find_child("DungeonButton", true, false)
		_check("ノルマ札：0 枚なら難ダンジョンの「受ける」が押せない・「%s」" % _label_text(q, "DungeonCard_" + dungeon_id, "QuotaTicketLabel"),
			take is BaseButton and (take as BaseButton).disabled and _label_text(q, "DungeonCard_" + dungeon_id, "QuotaTicketLabel") == tr("ui_quota_ticket_needed"))
		# 上限：⚠ 3 枚持っていたらショップで買えない（⚠ 金貨も棚も減らない）。
		GameManager.add_to_inventory(TICKET, GameManager.get_quota_ticket_max(), GameStateKeys.ITEM_TYPE_CONSUMABLE)
		var gold: int = int(GameManager.get_state().get(GameStateKeys.GOLD, 0))
		_check("ノルマ札：上限（%d 枚）なら買えない" % GameManager.get_quota_ticket_count(),
			not GameManager.purchase_shop_item(GameStateKeys.SHOP_TYPE_DAILY, 13) and int(GameManager.get_state().get(GameStateKeys.GOLD, 0)) == gold)
		GameManager.call("_remove_from_inventory", TICKET, GameManager.get_quota_ticket_count())
		# ショップ：⚠ 金貨で1枚・1日1枚。
		_check("ノルマ札：ショップで買うと1枚（%d）" % (GameManager.get_quota_ticket_count() + 1),
			GameManager.purchase_shop_item(GameStateKeys.SHOP_TYPE_DAILY, 13) and GameManager.get_quota_ticket_count() == 1 and int(GameManager.get_state().get(GameStateKeys.GOLD, 0)) == gold - 1000)
		_check("ノルマ札：同じ日にもう1枚は買えない（在庫1）", not GameManager.purchase_shop_item(GameStateKeys.SHOP_TYPE_DAILY, 13))
		# 1 枚：⚠ 掲示板の「受ける」→ 出撃の準備（⚠ 帯に「1枚（1 → 0）」）→ 出撃すると0枚。
		q = await _open(ADVENTURE, {})
		await _press(_tab_button(q, 1))
		take = q.find_child("DungeonCard_" + dungeon_id, true, false).find_child("DungeonButton", true, false)
		_check("ノルマ札：1 枚なら「受ける」が押せる・「%s」" % _label_text(q, "DungeonCard_" + dungeon_id, "QuotaTicketLabel"),
			take is BaseButton and not (take as BaseButton).disabled)
		await _press(take, OPEN_FRAMES)
		var b: Node = get_tree().current_scene
		_check("ノルマ札：出撃の準備の帯に「%s」" % _label_text(b, "Strip", "QuotaTicketLabel"),
			_label_text(b, "Strip", "QuotaTicketLabel") == tr("ui_quota_ticket_use") % [1, 1, 0])
		await _press(b.find_child("SortieButton", true, false))
		if b.has_method("skip_sign"):
			b.call("skip_sign")
		await _wait(OPEN_FRAMES)
		_check("ノルマ札：出撃すると1枚使ってマップ（残り %d）" % GameManager.get_quota_ticket_count(),
			_path_of(get_tree().current_scene) == DUNGEON_MAP and GameManager.is_in_dungeon() and GameManager.get_quota_ticket_count() == 0)
		# 続きから：⚠ 札は使わない。
		q = await _open(ADVENTURE, {})
		await _press(_tab_button(q, 1))
		await _press(q.find_child("DungeonCard_" + dungeon_id, true, false).find_child("DungeonButton", true, false), OPEN_FRAMES)
		_check("ノルマ札：「続きから」は札が無くても入れる", _path_of(get_tree().current_scene) == DUNGEON_MAP)
		GameManager.abandon_dungeon_run()

	# --- ダンジョンの形（2026-10-03・決定49・`EXEC_DUNGEON_SHAPE.md`・人間「⚠ 1い　⚠ 2あ　⚠ 3あ　⚠ 4あ　⚠ 5あ」） ---
	#   ⚠ 最深を書く口は本番のランの終わりだけ＝⚠ 本番の口でボスを3体倒して持ち帰る（最深 3＝30層）。

	func _flow_dungeon_depth() -> void:
		const TICKET: String = GameStateKeys.ITEM_QUOTA_TICKET
		var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
		var per_floor: int = GameManager.get_dungeon_layers_per_floor(dungeon_id)
		if GameManager.is_in_dungeon():
			GameManager.abandon_dungeon_run()
		if GameManager.get_dungeon_best_floors(dungeon_id) < 3:
			GameManager.start_dungeon_run(dungeon_id)
			for i: int in range(3):
				GameManager.debug_mark_dungeon_boss_cleared()
				if i < 2:
					GameManager.descend_dungeon_floor()
			var _back: Dictionary = GameManager.retreat_from_dungeon()
			GameManager.mark_run_report_seen()
		var best: int = GameManager.get_dungeon_best_floors(dungeon_id)
		_check("深さ：1フロアは %d 層・最深 %d で入れるのは %s" % [per_floor, best, str(GameManager.get_dungeon_start_floor_options(dungeon_id))],
			per_floor == 10 and str(GameManager.get_dungeon_start_floor_options(dungeon_id)) == str(range(1, best + 2)))
		# ⚠ 開いていない深さは入れない（⚠ 札も減らない）。
		var have: int = GameManager.get_quota_ticket_count()
		if have > 0:
			GameManager.call("_remove_from_inventory", TICKET, have)
		GameManager.add_to_inventory(TICKET, 1, GameStateKeys.ITEM_TYPE_CONSUMABLE)
		_check("深さ：開いていない深さ（%d）では入れず札も減らない" % (best + 2),
			not GameManager.enter_dungeon_with_ticket(dungeon_id, best + 2) and not GameManager.is_in_dungeon() and GameManager.get_quota_ticket_count() == 1)
		# 掲示板の「受ける」→ 出撃の準備に「潜る深さ」（⚠ 最初は最深の次）。
		var q: Node = await _open(ADVENTURE, {})
		await _press(_tab_button(q, 1))
		await _press(q.find_child("DungeonCard_" + dungeon_id, true, false).find_child("DungeonButton", true, false), OPEN_FRAMES)
		var b: Node = get_tree().current_scene
		var deepest_layer: int = best * per_floor + 1
		_check("深さ：出撃の準備に「%s 層から」・「%s」・「%s」" % [_label_text(b, "Depth", "StartLayerLabel"), _label_text(b, "Depth", "FromExitLabel"), _label_text(b, "Depth", "NextExitLabel")],
			_label_text(b, "Depth", "StartLayerLabel") == str(deepest_layer)
			and _label_text(b, "Depth", "FromExitLabel") == tr("ui_depth_from_exit") % (deepest_layer - 1)
			and _label_text(b, "Depth", "NextExitLabel") == tr("ui_depth_next_exit") % ((best + 1) * per_floor)
			and _label_text(b, "Strip", "CarryLabel") != "")
		_check("深さ：最深の次なら「+10」「最深へ」は押せない・「−10」は押せる",
			(b.find_child("DepthPlusButton", true, false) as BaseButton).disabled and (b.find_child("DepthDeepestButton", true, false) as BaseButton).disabled
			and not (b.find_child("DepthMinusButton", true, false) as BaseButton).disabled)
		await _press(b.find_child("DepthMinusButton", true, false))
		await _wait(OPEN_FRAMES)
		_check("深さ：「−10」で %s 層から・「+10」が押せる" % _label_text(b, "Depth", "StartLayerLabel"),
			_label_text(b, "Depth", "StartLayerLabel") == str(deepest_layer - per_floor) and not (b.find_child("DepthPlusButton", true, false) as BaseButton).disabled)
		for _i: int in range(best):
			var minus: Node = b.find_child("DepthMinusButton", true, false)
			if minus is BaseButton and not (minus as BaseButton).disabled:
				await _press(minus)
				await _wait(OPEN_FRAMES)
		_check("深さ：いちばん浅いと「%s」・%s 層から・「−10」は押せない" % [_label_text(b, "Depth", "FromExitLabel"), _label_text(b, "Depth", "StartLayerLabel")],
			_label_text(b, "Depth", "StartLayerLabel") == "1" and _label_text(b, "Depth", "FromExitLabel") == tr("ui_depth_from_entrance")
			and (b.find_child("DepthMinusButton", true, false) as BaseButton).disabled)
		await _press(b.find_child("DepthDeepestButton", true, false))
		await _wait(OPEN_FRAMES)
		_check("深さ：「最深へ」で %s 層から" % _label_text(b, "Depth", "StartLayerLabel"), _label_text(b, "Depth", "StartLayerLabel") == str(deepest_layer))
		# 出撃 → 選んだ深さから（⚠ 札を1枚使う）。
		await _press(b.find_child("SortieButton", true, false))
		if b.has_method("skip_sign"):
			b.call("skip_sign")
		await _wait(OPEN_FRAMES)
		var m: Node = get_tree().current_scene
		_check("深さ：出撃するとフロア %d（入ったフロア %d）・札 %d 枚・見出し「%s」" % [GameManager.get_dungeon_floor_index(), GameManager.get_dungeon_start_floor(), GameManager.get_quota_ticket_count(), _label_text(m, "Header", "FloorLabel")],
			_path_of(m) == DUNGEON_MAP and GameManager.get_dungeon_floor_index() == best + 1 and GameManager.get_dungeon_start_floor() == best + 1
			and GameManager.get_quota_ticket_count() == 0
			and _label_text(m, "Header", "FloorLabel") == tr("ui_dungeon_header_layer") % [deepest_layer, per_floor - 1]
			and GameManager.get_dungeon_layers_to_exit() == per_floor - 1)
		# ⚠ 地図の左の板（2026-10-03・人間「⚠ 左側にインベントリやHPの状況などを　⚠ 長くなるならスクロール」）。
		var bag_node: Node = m.find_child("BagGrid", true, false)
		var side_node: Node = m.find_child("RunSide", true, false)
		_check("地図の左の板：3人の行と鞄が板の中・鞄は %s 列で折り返し・スクロールの枠の中" % (str((bag_node as GridContainer).columns) if bag_node is GridContainer else "?"),
			side_node != null and bag_node is GridContainer and side_node.is_ancestor_of(bag_node)
			and (bag_node as GridContainer).columns == (side_node as RunSidePanel).bag_columns()
			and bag_node.get_parent() is ScrollContainer and side_node.find_child("PartyList", true, false) != null)
		# ⚠ セーブの形（⚠ JSON を通すと 4.0 になる＝読み込みで int に戻るか）。
		var saved: Variant = JSON.parse_string(JSON.stringify(GameManager.get_state()))
		GameManager.load_state(saved as Dictionary)
		var start_value: Variant = GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_START_FLOOR, null)
		_check("深さ：セーブを通しても start_floor_index は int の %s" % str(start_value), typeof(start_value) == TYPE_INT and int(start_value) == best + 1)
		# わかれ道：⚠ 「40層　ボスを倒した」「もう10層」「41–50層」→ 出る → 報告書「31 → 40」。
		GameManager.debug_mark_dungeon_boss_cleared()
		var fork: Node = await _open(DUNGEON_FLOOR_CLEAR, {})
		if fork == null:
			return
		var exit_layer: int = (best + 1) * per_floor
		_check("深さ：わかれ道「%s」・「%s」" % [(fork.get("heading") as Label).text, _label_text(fork, "DescendCard", "NextRangeLabel")],
			(fork.get("heading") as Label).text == tr("ui_dungeon_clear_heading") % exit_layer
			and _label_text(fork, "DescendCard", "NextRangeLabel") == tr("ui_dungeon_layer_range") % [exit_layer + 1, exit_layer + per_floor])
		await _press(fork.find_child("RetreatButton", true, false), OPEN_FRAMES)
		var r: Node = get_tree().current_scene
		_check("深さ：報告書「%s」・最深 %d" % [_label_text(r, "FloorLine", "FloorsLabel"), GameManager.get_dungeon_best_floors(dungeon_id)],
			_path_of(r) == REPORT and _label_text(r, "FloorLine", "FloorsLabel") == tr("ui_report_layer_span") % [deepest_layer, exit_layer]
			and GameManager.get_dungeon_best_floors(dungeon_id) == best + 1)

	# --- 装備の特殊効果（2026-10-02・回UI-仕組み⑦・手本 RichItemFx・人間「⚠ 1い　⚠ 2あ　⚠ 3あ」） ---

	func _flow_special_effects() -> void:
		const THORN: String = "armor_thorn_mail"
		_check("特殊効果：いばらの鎧は「棘の返し」・鉄の鎧には無い",
			GameManager.get_item_special_effect(THORN) == "eqfx_thorn" and GameManager.get_item_special_effect("armor_iron_mail") == ""
			and not GameManager.get_special_effect_view("eqfx_thorn").is_empty())
		# ⚠ 入れて剣士に着せる（⚠ 本番の口）。
		GameManager.add_to_inventory(THORN, 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
		var thorn_id: String = ""
		for raw: Variant in GameManager.get_owned_instances():
			if str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == THORN:
				thorn_id = str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
		var slot: String = str(MasterDataLoader.get_item(THORN).get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))
		GameManager.equip_instance(HERO, slot, thorn_id)
		_check("特殊効果：着けると戦闘のパッシブに入る（%s）" % str(GameManager.get_equipment_effect_passives(HERO)),
			"eqfx_thorn" in GameManager.get_equipment_effect_passives(HERO))
		# 持ち物：⚠ 行に星・右の紙に札。
		var w: Node = await _open(BELONGINGS, {TransferKeys.WAREHOUSE_INSTANCE_ID: thorn_id})
		var row: Node = w.find_child("Row_" + thorn_id, true, false)
		var card: Node = w.find_child("SpecialEffectCard", true, false)
		_check("特殊効果：持ち物の行に星・説明の紙に札（%s）" % _label_text(w, "SpecialEffectCard", "EffectName"),
			row != null and row.find_child("SpecialStar", true, false) != null and card != null
			and _label_text(w, "SpecialEffectCard", "EffectTrigger") == tr("ui_eqfx_trigger_took_damage"))
		var iron_rows: int = 0
		for node: Node in w.find_children("Row_*", "", true, false):
			if node.find_child("SpecialStar", true, false) != null:
				iron_rows += 1
		# ⚠ ほかの手で特殊効果つきの装備が手に入っていることがある（⚠ 伝説の宝箱）＝⚠ 持っている数と比べる。
		var with_effect: int = 0
		for raw: Variant in GameManager.get_owned_instances():
			if GameManager.get_item_special_effect(str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, ""))) != "":
				with_effect += 1
		_check("特殊効果：星は特殊効果のある品だけ（%d 行 ＝ %d 個）" % [iron_rows, with_effect], iron_rows == with_effect and with_effect >= 1)
		# 戦闘：⚠ 剣士のユニットのパッシブに入っている（⚠ 本物の戦闘の画面）。
		var b: Node = await _open(BATTLE, {
			TransferKeys.STAGE_ID: "stage_dbg_area",
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
		})
		await _wait(OPEN_FRAMES)
		var session: Variant = null if b == null else b.get("_session")
		var found: bool = false
		if session is BattleSession:
			for unit: Variant in (session as BattleSession).party_units:
				if unit is BattleUnit and (unit as BattleUnit).master_id == HERO and "eqfx_thorn" in (unit as BattleUnit).passive_ids:
					found = true
		_check("特殊効果：戦闘で着けている人に「棘の返し」がかかる", found)
		GameManager.unequip_instance(HERO, slot)
		# ⚠ 追い打ちが本当に発火するか（2026-10-03・人間「⚠ 追撃は出てないのか、同じタイミングで出て見えないのか」）。
		#   ⚠ 竜殺しの大剣を持たせて戦闘を数秒回し、⚠ 戦闘の記録（battle_last.jsonl）に反応の行があるかを見る。
		var sword_id: String = str(get_tree().root.find_child("DebugOverlay", true, false).call("grant_equipment", "weapon_dragon_greatsword", 1)) \
			if get_tree().root.find_child("DebugOverlay", true, false) != null else ""
		if sword_id == "":
			GameManager.add_to_inventory("weapon_dragon_greatsword", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
			for raw: Variant in GameManager.get_owned_instances():
				if str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == "weapon_dragon_greatsword":
					sword_id = str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
		GameManager.equip_instance(HERO, GameStateKeys.EQUIP_WEAPON, sword_id)
		b = await _open(BATTLE, {
			TransferKeys.STAGE_ID: "stage_dbg_area",
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
		})
		await get_tree().create_timer(FOLLOW_STRIKE_WAIT_SEC).timeout
		BattleLog.flush()
		var log_text: String = FileAccess.get_file_as_string(BattleLog.FILE_PATH)
		var reacts: int = log_text.count("status_eqfx_follow_strike")
		print("  [追い打ち] 記録の行 %d" % reacts)
		_check("特殊効果：竜殺しの大剣の追い打ちが戦闘で発火する（記録 %d 行）" % reacts, reacts > 0)
		GameManager.unequip_instance(HERO, GameStateKeys.EQUIP_WEAPON)

	# --- 集中の道具（2026-09-29・回UI-仕組み⑤・手本 PomoSkin / Focus・人間「⚠ 1あ　⚠ 2あ　⚠ 3あ　⚠ 4い」） ---
	#   ⚠ 選んだ道具は設定のファイル（⚠ 検査用に差し替えてある）。

	func _flow_focus_tools() -> void:
		var p: Node = await _open(POMODORO, {})
		if p == null:
			return
		var tools_button: Node = p.find_child("FocusToolsButton", true, false)
		_check("ポモドーロ：「集中の道具」「ポモドーロの設定」がある", tools_button != null and p.find_child("PomodoroSettingsButton", true, false) != null)
		await _press(tools_button, OPEN_FRAMES)
		var t: Node = get_tree().current_scene
		var rows_ok: bool = true
		for tool_id: String in ["hourglass", "candle", "clock", "water_clock", "unknown"]:
			rows_ok = rows_ok and t.find_child("Tool_" + tool_id, true, false) != null
		var hourglass_row: Node = t.find_child("Tool_hourglass", true, false)
		_check("集中の道具：目録に5行（持っている3・まだ2）・砂時計が使用中・「使う」は押せない",
			_path_of(t) == FOCUS_TOOLS and rows_ok and hourglass_row != null and hourglass_row.find_child("InUseStamp", true, false) != null
			and (t.find_child("UseButton", true, false) as Button).disabled)
		await _press(t.find_child("Tool_candle", true, false))
		await _wait()
		var preview: Node = t.find_child("PreviewTool", true, false)
		var use: Button = t.find_child("UseButton", true, false) as Button
		_check("集中の道具：ろうそくを押すと見本がろうそく・「ろうそくを使う」が押せる（%s）" % (use.text if use != null else "?"),
			preview is FocusTool and (preview as FocusTool).tool_id == "candle" and use != null and not use.disabled
			and use.text == tr("ui_focus_tools_use") % tr("ui_focus_tool_candle"))
		await _press(use)
		await _wait()
		var candle_row: Node = t.find_child("Tool_candle", true, false)
		_check("集中の道具：「使う」でろうそくが使用中（設定 %s）" % GameSettings.focus_tool(),
			GameSettings.focus_tool() == "candle" and candle_row != null and candle_row.find_child("InUseStamp", true, false) != null)
		var header: Node = t.find_child("Header", true, false)
		await _press(null if header == null else header.find_child("BackButton", true, false), OPEN_FRAMES)
		p = get_tree().current_scene
		_check("集中の道具：「戻る」でポモドーロ", _path_of(p) == POMODORO)
		# ⚠ 加護を選ぶビューなら「始める」を押して集中のビューへ（⚠ 本物のボタン）。
		var start: Node = p.find_child("ProtectionSelectView", true, false)
		if start != null:
			await _press(start.find_child("StartButton", true, false), OPEN_FRAMES)
		var tool: Node = p.find_child("FocusTool", true, false)
		_check("ポモドーロ：集中の画面は輪の代わりに選んだ道具（%s・進み %s）" % [str(tool.get("tool_id")) if tool != null else "無い", str(tool.get("progress")) if tool != null else "?"],
			tool is FocusTool and (tool as FocusTool).tool_id == "candle" and (tool as FocusTool).progress == 0.0)
		# ⚠ ポモドーロの設定（⚠ 10-02 人間「⚠ ポモドーロ関連の設定はポモドーロ画面からできるように」）：⚠ 画面を移らず紙の窓。
		await _press(p.find_child("PomodoroSettingsButton", true, false))
		await _wait()
		var modal: ModalDialog = _modal_of(p)
		var panel: Node = null if modal == null else modal.find_child("PomodoroSettingsPanel", true, false)
		_check("ポモドーロ：「ポモドーロの設定」は画面を移らず紙の窓（集中・休憩・小窓の行）",
			_path_of(get_tree().current_scene) == POMODORO and panel != null and panel.find_child("FocusRow", true, false) != null
			and panel.find_child("MiniWindowRow", true, false) != null)
		await _press(panel.find_child("Focus_50", true, false))
		await _wait()
		_check("ポモドーロ：窓で集中 50分を選ぶと、始める前の時間がすぐ 50:00（%s 秒）" % str(p.get("time_left_sec")),
			GameSettings.focus_minutes() == 50 and int(p.get("time_left_sec")) == 50 * 60)
		await _close_modal(p)
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_FOCUS_MINUTES, 25)
		await _flow_mini_window()

	# --- デスクトップの小窓（2026-09-29・回UI-仕組み⑥・人間「⚠ 1あ　⚠ 2あ　⚠ 3い　⚠ 4あ」） ---
	#   ⚠ ヘッドレス＝窓は動かない。⚠ 見るのは中身の出し入れと画面の論理の大きさ（`content_scale_size`）。

	func _flow_mini_window() -> void:
		var root_window: Window = get_tree().root
		var full_size: Vector2i = root_window.content_scale_size
		# ⚠ 既定オフ：⚠ 集中を始めても小窓にならない。
		var p: Node = await _open(POMODORO, {})
		await _pomodoro_start_focus(p)
		_check("小窓：設定がオフなら集中を始めても小窓にならない", not bool(p.call("is_mini_window_active")))
		# ⚠ 設定の画面でオンにする（⚠ 本物の札）。
		var s: Node = await _open(SETTINGS, {TransferKeys.SETTINGS_TAB: SettingsScreen.TAB_POMODORO})
		await _press(s.find_child("Mini_true", true, false))
		_check("小窓：設定の「オン」で残る", GameSettings.mini_window())
		# ⚠ 2026-10-05（回P-2）：⚠ タスクを選んで始める（⚠ 小窓にタスクの名前と「タスクを終える」が出る）。
		var mini_task: String = GameManager.add_task("小窓の検査")
		p = await _open(POMODORO, {})
		var select_view: Node = p.find_child("ProtectionSelectView", true, false)
		if select_view != null:
			await _press(select_view.find_child("StartButton", true, false), OPEN_FRAMES)
		var focus_view: Node = p.find_child("FocusView", true, false)
		if focus_view != null:
			focus_view.call("set_task", mini_task)
			await _press(focus_view.find_child("StartButton", true, false))
		await _wait()
		var mini: Node = p.find_child("MiniWindow", true, false)
		var mini_size: Vector2i = Vector2i(ThemeDB.get_project_theme().get_constant(&"width", &"MiniWindow"), ThemeDB.get_project_theme().get_constant(&"height", &"MiniWindow"))
		_check("小窓：集中を始めると小窓（画面の大きさ %s・%s %s・タスク「%s」）" % [str(root_window.content_scale_size), _label_text(p, "MiniWindow", "PhaseLabel"), _label_text(p, "MiniWindow", "TimeLabel"), _label_text(p, "MiniWindow", "TaskLabel")],
			bool(p.call("is_mini_window_active")) and root_window.content_scale_size == mini_size and mini != null
			and _label_text(p, "MiniWindow", "PhaseLabel") == tr("ui_mini_phase_focus") and _label_text(p, "MiniWindow", "TaskLabel") == "小窓の検査"
			and mini.find_child("MiniSetDots", true, false) is SetDots and mini.find_child("Leader", true, false) == null)
		_check("小窓：集中中は時間の下に [一時停止][次へ]（%s）・タスクの右に ✓" % (mini.find_child("MiniNextButton", true, false) as Button).tooltip_text,
			(mini.find_child("FinishTaskButton", true, false) as Button).visible and (mini.find_child("MiniNextButton", true, false) as Button).visible
			and (mini.find_child("MiniNextButton", true, false) as Button).tooltip_text == tr("ui_pomodoro_end_focus")
			and mini.find_child("Controls", true, false).is_ancestor_of(mini.find_child("MiniPauseButton", true, false))
			and mini.find_child("TaskLine", true, false).is_ancestor_of(mini.find_child("FinishTaskButton", true, false)))
		# ⚠ 小窓のリスト（10-06・人間「⚠ 小窓でも、リストを出し入れできるように」→「⚠ リストのサイドバーをそのまま追加で伸ばす形に」）：
		#   ⚠ 10-06 3回目「⚠ 上にリストを出して追加はいらないかも」：⚠ 開く → 窓が上へ伸びてサイドバー（⚠ ペンと足す欄は無い）→ 行で替える → 閉じる。
		var mini_other: String = GameManager.add_task("小窓の検査2")
		await _press(mini.find_child("MiniListButton", true, false))
		await _wait()
		var theme_now: Theme = ThemeDB.get_project_theme()
		var list_size: Vector2i = mini_size + Vector2i(0, theme_now.get_constant(&"list_top_height", &"MiniWindow"))
		var mini_side: Node = mini.find_child("MiniSidebar", true, false)
		var mini_rows: int = 0 if mini_side == null else mini_side.find_children("Side_*", "", true, false).size()
		var timer_column: Control = mini.find_child("TimeLabel", true, false) as Control
		_check("小窓：「リスト」で窓が上へ伸びる（%s）・サイドバーがタイマーの上（%d 行 ／ 一覧 %d）・ペンは無い・足す欄はある" % [str(root_window.content_scale_size), mini_rows, GameManager.get_tasks().size()],
			bool(mini.call("is_list_open")) and root_window.content_scale_size == list_size and mini_side is TaskSidebar and (mini_side as Control).visible
			and mini_rows == GameManager.get_tasks().size() and mini_side.find_child("DetailButton", true, false) == null
			and (mini_side.find_child("AddLine", true, false) as Control).visible and not (mini_side.find_child("HintLabel", true, false) as Control).visible
			and timer_column != null and (mini_side as Control).get_global_rect().position.y < timer_column.get_global_rect().position.y)
		await _press(null if mini_side == null else mini_side.find_child("Side_" + mini_other, true, false))
		await _wait()
		_check("小窓：サイドバーの行を押すといまのタスクが替わる（%s）・明るい行・小窓のまま" % _label_text(p, "MiniWindow", "TaskLabel"),
			str(p.call("_current_task_id")) == mini_other and _label_text(p, "MiniWindow", "TaskLabel") == "小窓の検査2" and bool(p.call("is_mini_window_active"))
			and (mini_side.find_child("Side_" + mini_other, true, false) as LedgerRow).selected)
		await _press(null if mini_side == null else mini_side.find_child("Side_" + mini_task, true, false))
		await _wait()
		await _press(mini.find_child("MiniListButton", true, false))
		_check("小窓：もう一度「リスト」で縮む（%s）・いまのタスクは戻した（%s）" % [str(root_window.content_scale_size), str(GameManager.get_task(str(p.call("_current_task_id"))).get(GameStateKeys.TASK_TITLE, ""))],
			not bool(mini.call("is_list_open")) and root_window.content_scale_size == mini_size and str(p.call("_current_task_id")) == mini_task)
		# ⚠ 小窓のリストから足す（10-06）：⚠ 足すだけ（⚠ いまのタスクは変えない）。
		var count_before_mini_add: int = GameManager.get_tasks().size()
		await _press(mini.find_child("MiniListButton", true, false))
		await _wait()
		(mini_side.find_child("SideNewEdit", true, false) as LineEdit).text = "小窓から足した"
		await _press(mini_side.find_child("SideAddButton", true, false))
		var mini_added: String = str((GameManager.get_tasks().back() as Dictionary).get(GameStateKeys.TASK_ID, ""))
		_check("小窓：リストの下の欄で足せる（%s）・いまのタスクは変わらない" % str(GameManager.get_task(mini_added).get(GameStateKeys.TASK_TITLE, "")),
			GameManager.get_tasks().size() == count_before_mini_add + 1 and str(GameManager.get_task(mini_added).get(GameStateKeys.TASK_TITLE, "")) == "小窓から足した"
			and str(p.call("_current_task_id")) == mini_task)
		await _press(mini.find_child("MiniListButton", true, false))
		var _deleted_added: bool = GameManager.delete_task(mini_added)
		var _deleted_other: bool = GameManager.delete_task(mini_other)
		# ⚠ 小窓の「一時停止」（回P-3）→ ⚠ 止まる・上が「集中（停止中）」→ もう一度で再開。
		await _press(mini.find_child("MiniPauseButton", true, false))
		_check("小窓：「一時停止」で止まる・「%s」・小窓のまま" % _label_text(p, "MiniWindow", "PhaseLabel"),
			bool(p.call("is_paused")) and _label_text(p, "MiniWindow", "PhaseLabel") == tr("ui_mini_paused") % tr("ui_mini_phase_focus") and bool(p.call("is_mini_window_active")))
		await _press(mini.find_child("MiniPauseButton", true, false))
		_check("小窓：もう一度押すと再開", not bool(p.call("is_paused")))
		# ⚠ 小窓のまま「タスクを終える」→ ⚠ 終わる・選んでいない・小窓のまま・タイマーは動いたまま。
		await _press(mini.find_child("FinishTaskButton", true, false))
		await _wait()
		_check("小窓：「タスクを終える」で終わる（終えた=%s）・タスクの行が消える・小窓のまま・タイマーは動く" % str(int(GameManager.get_task(mini_task).get(GameStateKeys.TASK_DONE_AT, 0)) != 0),
			int(GameManager.get_task(mini_task).get(GameStateKeys.TASK_DONE_AT, 0)) != 0 and not (mini.find_child("TaskLine", true, false) as Control).visible
			and bool(p.call("is_mini_window_active")) and bool(p.get("is_timer_active")) and str(p.call("_current_task_id")) == "")
		# ⚠ 「大きく」→ ⚠ このフェーズは元の大きさ。
		await _press(mini.find_child("ExpandButton", true, false))
		_check("小窓：「大きく」で元の大きさ（%s）" % str(root_window.content_scale_size), not bool(p.call("is_mini_window_active")) and root_window.content_scale_size == full_size)
		# ⚠ 10-06（人間「⚠ フェーズが変わるとき小窓にするかどうかは今の画面が小窓かどうかで判断するように」）：
		#   ⚠ 大きいまま集中が終わる → 振り返りも大きいまま → 「小窓にする」→ 休憩・次のセットも小窓のまま。
		p.set("time_left_sec", 0.01)
		await _wait()
		_check("小窓：大きくしたあとフェーズが変わっても大きいまま（振り返り）", int(p.get("current_state")) == 2 and not bool(p.call("is_mini_window_active")) and root_window.content_scale_size == full_size)
		await _press(p.find_child("MiniModeButton", true, false))
		await _wait()
		_check("小窓：振り返りも小窓（10-06）・欄と「確定」", bool(p.call("is_mini_window_active"))
			and (p.find_child("MiniWindow", true, false).find_child("ReflectionLine", true, false) as Control).visible)
		var reflection: Node = p.find_child("SkipButton", true, false)
		if reflection == null:
			p.call("_on_reflection_completed", "", true)
		else:
			await _press(reflection)
		await _wait()
		mini = p.find_child("MiniWindow", true, false)
		_check("小窓：小窓のまま振り返りが終わると休憩も小窓・「%s」・「次へ」（とばす）だけ" % _label_text(p, "MiniWindow", "PhaseLabel"),
			bool(p.call("is_mini_window_active")) and _label_text(p, "MiniWindow", "PhaseLabel") == tr("ui_mini_phase_break")
			and (mini.find_child("MiniNextButton", true, false) as Button).visible and (mini.find_child("MiniNextButton", true, false) as Button).tooltip_text == tr("ui_mini_skip_break")
			and not (mini.find_child("FinishTaskButton", true, false) as Button).visible)
		# ⚠ 小窓のまま「次へ」→ ⚠ 次のセットの始める前も小窓のまま（10-06・今の画面で決める）。
		var set_before: int = int(p.get("current_set_index"))
		await _press(mini.find_child("MiniNextButton", true, false))
		await _wait()
		_check("小窓：「次へ」で次のセット（%d → %d）・始める前も小窓のまま（%s）" % [set_before, int(p.get("current_set_index")), _label_text(p, "MiniWindow", "PhaseLabel")],
			int(p.get("current_set_index")) == set_before + 1 and bool(p.call("is_mini_window_active")) and root_window.content_scale_size == mini_size
			and _label_text(p, "MiniWindow", "PhaseLabel") == tr("ui_mini_phase_ready"))
		# ⚠ 小窓の「次へ」で始めても小窓 → ⚠ 小窓のまま拠点へ出る → ⚠ 元の大きさに戻る。
		await _press(mini.find_child("MiniNextButton", true, false))
		await _wait()
		_check("小窓：次のセットを始めても小窓のまま", bool(p.call("is_mini_window_active")) and bool(p.get("_focus_started")))
		SceneManager.change_scene(BASE)
		await _wait(OPEN_FRAMES)
		_check("小窓：小窓のまま画面を離れると元の大きさ（%s）" % str(root_window.content_scale_size), root_window.content_scale_size == full_size)
		var _deleted: bool = GameManager.delete_task(mini_task)
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_WINDOW, false)
		# ⚠ いつでも小窓（10-06・人間「⚠ いつでも小窓にできるように」）：⚠ 設定はオフのまま・⚠ 始める前に上の「小窓にする」。
		p = await _open(POMODORO, {})
		if p == null:
			return
		var manual_select: Node = p.find_child("ProtectionSelectView", true, false)
		if manual_select != null:
			_check("いつでも小窓：加護を選ぶあいだは「小窓にする」が出ない", not (p.find_child("MiniModeButton", true, false) as Control).visible)
			await _press(manual_select.find_child("StartButton", true, false), OPEN_FRAMES)
		await _press(p.find_child("MiniModeButton", true, false))
		await _wait()
		mini = p.find_child("MiniWindow", true, false)
		var next_button: Button = null if mini == null else mini.find_child("MiniNextButton", true, false) as Button
		_check("いつでも小窓：始める前に「小窓にする」で小窓（%s・「%s」・次へ=%s）" % [str(root_window.content_scale_size), _label_text(p, "MiniWindow", "PhaseLabel"), "" if next_button == null else next_button.tooltip_text],
			bool(p.call("is_mini_window_active")) and root_window.content_scale_size == mini_size and _label_text(p, "MiniWindow", "PhaseLabel") == tr("ui_mini_phase_ready")
			and next_button != null and next_button.visible and next_button.tooltip_text == tr("ui_mini_next_start") and not bool(p.get("is_timer_active")))
		var mini_top: Control = mini.find_child("Top", true, false) as Control
		var inner_width: int = ThemeDB.get_project_theme().get_constant(&"width", &"MiniWindow") - 2 * ThemeDB.get_project_theme().get_constant(&"pad", &"MiniWindow")
		_check("いつでも小窓：「これから集中」でも上の行が入りきる（%.0f ≦ %d）" % [mini_top.get_combined_minimum_size().x, inner_width],
			mini_top.get_combined_minimum_size().x <= float(inner_width))
		await _press(next_button)
		await _wait()
		_check("いつでも小窓：「次へ」で集中が始まる・小窓のまま", bool(p.get("is_timer_active")) and bool(p.get("_focus_started")) and bool(p.call("is_mini_window_active")))
		var today_before_end: int = GameManager.get_cumulative_focus_minutes()
		var count_before_end: int = GameManager.get_total_pomodoro_completed()
		var full_min: int = int(float(p.get("phase_total_sec")) / 60.0)
		p.set("time_left_sec", 0.01)
		await _wait()
		# ⚠ 10-06（PLAN_POMODORO_USABILITY 不便1・6）：⚠ 今日の分は集中が終わった時点で入る（⚠ 振り返りを待たない）・⚠ 回数も +1。
		_check("集中の分：タイマーが0になった時点で今日の分に入る（%d → %d・%d分）・回数 +1（%d → %d）" % [today_before_end, GameManager.get_cumulative_focus_minutes(), full_min, count_before_end, GameManager.get_total_pomodoro_completed()],
			int(p.get("current_state")) == 2 and GameManager.get_cumulative_focus_minutes() == today_before_end + full_min
			and GameManager.get_total_pomodoro_completed() == count_before_end + 1)
		# ⚠ 振り返りも小窓で書く（10-06・人間「⚠ 振り返りも小窓でできるように」）：⚠ 足りないと確定できない → ⚠ 書くと画面の欄にも入る → 確定で休憩。
		var mini_edit: LineEdit = mini.find_child("MiniReflectionEdit", true, false) as LineEdit
		var mini_ok: Button = mini.find_child("MiniReflectionOk", true, false) as Button
		_check("いつでも小窓：振り返りの下書きに要る文字数が出る（%s）" % ("" if mini_edit == null else mini_edit.placeholder_text),
			mini_edit != null and mini_edit.placeholder_text.contains(str(int(Balance.pomodoro.reflection_min_chars))))
		_check("いつでも小窓：振り返りも小窓・「%s」・欄と「確定」（まだ押せない・%s）" % [_label_text(p, "MiniWindow", "PhaseLabel"), _label_text(p, "MiniWindow", "MiniReflectionHint")],
			int(p.get("current_state")) == 2 and bool(p.call("is_mini_window_active")) and _label_text(p, "MiniWindow", "PhaseLabel") == tr("ui_mini_phase_reflection")
			and mini_edit != null and mini_edit.is_visible_in_tree() and mini_ok != null and mini_ok.disabled
			and not (mini.find_child("Controls", true, false) as Control).visible)
		var today_before_reflect: int = GameManager.get_cumulative_focus_minutes()
		mini_edit.text = "小窓から書いた振り返りです。二十字を超えるように書いておく。"
		mini_edit.text_changed.emit(mini_edit.text)
		await _wait()
		var view_text: String = str(p.find_child("ReflectionView", true, false).call("get_text"))
		_check("いつでも小窓：小窓で書くと画面の欄にも入る・「確定」が押せる（%s）" % _label_text(p, "MiniWindow", "MiniReflectionHint"),
			view_text == mini_edit.text and not mini_ok.disabled)
		await _press(mini_ok)
		await _wait()
		_check("いつでも小窓：小窓の「確定」で振り返りが終わる・今日の分は二重に足さない（%d → %d）" % [today_before_reflect, GameManager.get_cumulative_focus_minutes()],
			int(p.get("current_state")) == 3 and GameManager.get_cumulative_focus_minutes() == today_before_reflect)
		_check("いつでも小窓：振り返りが終わると休憩でまた小窓", int(p.get("current_state")) == 3 and bool(p.call("is_mini_window_active")))
		await _press(mini.find_child("MiniNextButton", true, false))
		await _wait()
		_check("いつでも小窓：休憩を「次へ」でとばしても小窓のまま（始める前）", int(p.get("current_state")) == 1 and not bool(p.get("_focus_started")) and bool(p.call("is_mini_window_active")))
		await _press(mini.find_child("ExpandButton", true, false))
		await _wait()
		_check("いつでも小窓：「大きく」で元の大きさ・「小窓にする」がまた出る", not bool(p.call("is_mini_window_active")) and root_window.content_scale_size == full_size
			and (p.find_child("MiniModeButton", true, false) as Control).visible)
		SceneManager.change_scene(BASE)
		await _wait(OPEN_FRAMES)

	# ポモドーロで集中を始める（⚠ 加護を選ぶビューなら「始める」→ ⚠ 集中の「開始」）。
	# --- 自動セーブと閉じたとき（2026-10-05・回P-1・人間「⚠ ｑ１　あ　ｑ２　あ　ｑ３　いい」） ---
	#   ⚠ 本当に窓を閉じると検査ごと終わる＝⚠ 閉じる合図（`SaveManager.quitting`）と書き込み（`autosave()`）を分けて見る。
	func _flow_autosave() -> void:
		var test_file: String = ProjectSettings.globalize_path(SAVE_TEST_PATH)
		_check("自動セーブ：検査は検査用のファイルに書く（%s）" % SaveManager.save_path(), SaveManager.save_path() == SAVE_TEST_PATH)
		DirAccess.remove_absolute(test_file)
		_check("自動セーブ：タイトルで始めていないあいだは書かない", not SaveManager.autosave() and not FileAccess.file_exists(SAVE_TEST_PATH))
		SaveManager.begin_session()
		var b: Node = await _open(BASE, {})
		_check("自動セーブ：始めたあとは画面を移ると書く", b != null and FileAccess.file_exists(SAVE_TEST_PATH))
		# 閉じたとき：⚠ 集中の途中 → 閉じる合図 → 「やめる」と同じ確定（⚠ タスクの時間・セッションの回数・タイマーが止まる）。
		var task_id: String = GameManager.add_task("自動セーブ検査")
		var p: Node = await _open(POMODORO, {})
		if p == null:
			SaveManager.end_session()
			return
		var select_view: Node = p.find_child("ProtectionSelectView", true, false)
		if select_view != null:
			await _press(select_view.find_child("StartButton", true, false), OPEN_FRAMES)
		var view: Node = p.find_child("FocusView", true, false)
		if view != null:
			view.call("set_task", task_id)
			await _press(view.find_child("StartButton", true, false))
		var total_sec: float = float(p.get("phase_total_sec"))
		p.set("time_left_sec", total_sec - 120.0)
		var sessions_before: int = int(GameManager.get_state().get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0))
		var today_before_close: int = GameManager.get_cumulative_focus_minutes()
		DirAccess.remove_absolute(test_file)
		SaveManager.quitting.emit()
		var saved: bool = SaveManager.autosave()
		var task_sec: int = int(GameManager.get_task(task_id).get(GameStateKeys.TASK_FOCUS_SEC, 0))
		var sessions_after: int = int(GameManager.get_state().get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0))
		# ⚠ 10-06（不便6）：⚠ 途中で閉じたのは「集中を終えた回数」に数えない。
		_check("閉じたとき：集中の途中でも確定する（タスクに %d 秒・回数は増えない %d → %d・タイマー止まる）・書く" % [task_sec, sessions_before, sessions_after],
			absi(task_sec - 120) <= 1 and sessions_after == sessions_before and not bool(p.get("is_timer_active")) and saved and FileAccess.file_exists(SAVE_TEST_PATH))
		# ⚠ 10-06（`BS-22` を覆した）：⚠ 途中まで集中した分（2分）も今日の分に入る。
		_check("閉じたとき：途中まで集中した分も今日の分に入る（%d → %d）" % [today_before_close, GameManager.get_cumulative_focus_minutes()],
			GameManager.get_cumulative_focus_minutes() == today_before_close + 2)
		SaveManager.quitting.emit()
		_check("閉じたとき：合図が2回来ても二重に配らない（回数 %d）" % int(GameManager.get_state().get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0)),
			int(GameManager.get_state().get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0)) == sessions_after)
		# ⚠ 後片付け：⚠ 以降の検査では書かない・⚠ 足したタスクは消す・⚠ 検査用のファイルは残さない。
		SaveManager.end_session()
		var _deleted: bool = GameManager.delete_task(task_id)
		DirAccess.remove_absolute(test_file)
		await _open(BASE, {})

	# --- ポモドーロの残り（2026-10-05・回P-3・人間「⚠ 全部作って一気に確認したい」） ---
	#   ⚠ 一時停止 ／ ＋5分 ／ スペースキー ／ 時計の差分 ／ 1日の目標 ／ 休憩明けの自動開始。
	func _flow_pomodoro_extras() -> void:
		# ⚠ 設定の画面で目標を 120分・自動開始をオンに（⚠ 本物の札）。
		var s: Node = await _open(SETTINGS, {TransferKeys.SETTINGS_TAB: SettingsScreen.TAB_POMODORO})
		if s == null:
			return
		await _press(s.find_child("Goal_120", true, false))
		await _press(s.find_child("AutoStart_true", true, false))
		_check("設定：1日の目標 %d分・休憩明けの自動開始 %s" % [GameSettings.daily_goal_minutes(), str(GameSettings.auto_start_focus())],
			GameSettings.daily_goal_minutes() == 120 and GameSettings.auto_start_focus())
		# ⚠ 10-06（PLAN_POMODORO_USABILITY 不便9）：⚠ 集中に15分・⚠ 長い休憩を選べる（⚠ 20分にして、あとで長い休憩の長さを見る）。
		await _press(s.find_child("LongBreak_20", true, false))
		_check("設定：集中に15分の札がある・長い休憩を %d分に" % GameSettings.long_break_minutes(),
			s.find_child("Focus_15", true, false) != null and GameSettings.long_break_minutes() == 20)
		var p: Node = await _open(POMODORO, {})
		if p == null:
			return
		var today_before: int = GameManager.get_cumulative_focus_minutes()
		_check("目標：上に「%s」" % _label_text(p, "TopBar", "GoalLabel"), _label_text(p, "TopBar", "GoalLabel") == tr("ui_pomodoro_goal_progress") % [today_before, 120]
			or (today_before >= 120 and _label_text(p, "TopBar", "GoalLabel") == tr("ui_pomodoro_goal_reached") % [today_before, 120]))
		var select_view: Node = p.find_child("ProtectionSelectView", true, false)
		if select_view != null:
			await _press(select_view.find_child("StartButton", true, false), OPEN_FRAMES)
		var pause: Button = p.find_child("PauseButton", true, false) as Button
		var next: Button = p.find_child("NextButton", true, false) as Button
		_check("一時停止：始める前は「一時停止」「次へ」が出ない（「はじめる」がある）・「＋5分」は無い", pause != null and next != null and not pause.visible and not next.visible
			and p.find_child("ExtendButton", true, false) == null)
		# スペースキー（始める前）＝始める。
		var space: InputEventKey = InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = true
		get_viewport().push_input(space)
		await _wait()
		_check("スペース：始める前に押すと集中が始まる", bool(p.get("is_timer_active")) and bool(p.get("_focus_started")))
		_check("一時停止：始めたら「一時停止」「次へ」（%s）が真ん中（「はじめる」の場所）に出る・「はじめる」は消える" % next.tooltip_text,
			pause.visible and next.visible and next.tooltip_text == tr("ui_pomodoro_end_focus") and pause.tooltip_text == tr("ui_pomodoro_pause") and pause.icon != null and pause.get_parent().name == &"RunControls"
			and p.find_child("FocusView", true, false).is_ancestor_of(pause) and not (p.find_child("FocusView", true, false).get_node("Layout/StartButton") as Control).visible)
		await _press(pause)
		var held: float = float(p.get("time_left_sec"))
		await get_tree().create_timer(0.3).timeout
		_check("一時停止：止めると残りが減らない（%.2f → %.2f）・字が「再開」" % [held, float(p.get("time_left_sec"))],
			bool(p.call("is_paused")) and is_equal_approx(float(p.get("time_left_sec")), held) and pause.tooltip_text == tr("ui_pomodoro_resume"))
		get_viewport().push_input(space)
		await get_tree().create_timer(0.3).timeout
		_check("スペース：止めているときに押すと再開・残りが減る（%.2f → %.2f）" % [held, float(p.get("time_left_sec"))],
			not bool(p.call("is_paused")) and float(p.get("time_left_sec")) < held)
		# 時計の差分：⚠ 2分眠っていたことにする（⚠ 時計の基準を 120 秒前へ）。
		var before_sleep: float = float(p.get("time_left_sec"))
		p.set("_last_wall", Time.get_unix_time_from_system() - 120.0)
		await _wait()
		_check("時計：スリープ明けのように時計が 120 秒進むと残りも 120 秒減る（%.0f → %.0f）" % [before_sleep, float(p.get("time_left_sec"))],
			absf(before_sleep - float(p.get("time_left_sec")) - 120.0) < 1.0)
		# ⚠ 10-06（不便8）：⚠ 集中中も上の「今日」が経過分だけ動く（⚠ 数えたのではない＝今日の分そのものは増えない）。
		var live_min: int = int((float(p.get("phase_total_sec")) - float(p.get("time_left_sec"))) / 60.0)
		_check("目標：集中中も上の「今日」が経過分（%d分）だけ動く（%s）・今日の分そのものは %d のまま" % [live_min, _label_text(p, "TopBar", "GoalLabel"), GameManager.get_cumulative_focus_minutes()],
			live_min >= 2 and _label_text(p, "TopBar", "GoalLabel") == tr("ui_pomodoro_goal_progress") % [today_before + live_min, 120]
			and GameManager.get_cumulative_focus_minutes() == today_before)
		var count_before_next: int = GameManager.get_total_pomodoro_completed()
		# 次へ（10-06・人間「⚠ 今のポモドーロのフェーズを終わらせるボタンも」）：⚠ 10分集中したところで「次へ」→ 振り返り → ⚠ 今日の分は集中した分だけ。
		p.set("time_left_sec", float(p.get("phase_total_sec")) - 600.0)
		await _wait()
		var focused_sec: float = float(p.get("phase_total_sec")) - float(p.get("time_left_sec"))
		await _press(next)
		await _wait()
		var focus_min: int = int(focused_sec / 60.0)
		_check("次へ：集中中に押すとそこで終えて振り返り（集中した %.0f 秒）" % focused_sec, int(p.get("current_state")) == 2)
		# ⚠ 10-06：⚠ 「次へ」を押した時点で入っている（⚠ 振り返りの前）。
		var today_after: int = GameManager.get_cumulative_focus_minutes()
		p.call("_on_reflection_completed", "途中で終えた分を数えるかの検査です。二十字を超えるように書く。", false)
		await _wait()
		_check("次へ：振り返りを確定しても今日の分は二重に足さない（%d → %d）・途中で終えたのは回数に数えない（%d → %d）" % [today_after, GameManager.get_cumulative_focus_minutes(), count_before_next, GameManager.get_total_pomodoro_completed()],
			GameManager.get_cumulative_focus_minutes() == today_after and GameManager.get_total_pomodoro_completed() == count_before_next)
		_check("次へ：今日の分は集中した分だけ入る（%d → %d・%d分）・目標の字も変わる（%s）" % [today_before, today_after, focus_min, _label_text(p, "TopBar", "GoalLabel")],
			today_after == today_before + focus_min and _label_text(p, "TopBar", "GoalLabel").begins_with(tr("ui_pomodoro_goal_progress").split("%")[0])
			and _label_text(p, "TopBar", "GoalLabel").contains(str(today_after)))
		# 休憩：⚠ 真ん中に [一時停止][次へ]・⚠ 「とばす」の札は隠れる → ⚠ 終わると自動で次の集中が始まる。
		pause = p.find_child("PauseButton", true, false) as Button
		next = p.find_child("NextButton", true, false) as Button
		var break_view: Node = p.find_child("BreakView", true, false)
		_check("休憩：真ん中に「一時停止」「次へ」（%s）・「とばす」の札は隠れる" % ("" if next == null else next.tooltip_text), int(p.get("current_state")) == 3 and pause != null and pause.visible
			and break_view.is_ancestor_of(pause) and next != null and next.visible and next.tooltip_text == tr("ui_mini_skip_break")
			and not (break_view.get_node("Layout/SkipButton") as Control).visible)
		var set_before: int = int(p.get("current_set_index"))
		p.set("time_left_sec", 0.01)
		await _wait(OPEN_FRAMES)
		_check("自動開始：休憩が終わると次のセット（%d → %d）の集中が始まっている" % [set_before, int(p.get("current_set_index"))],
			int(p.get("current_set_index")) == set_before + 1 and int(p.get("current_state")) == 1 and bool(p.get("is_timer_active")) and bool(p.get("_focus_started")))
		# 振り返りの時間切れ（10-06・PLAN_POMODORO_USABILITY 不便1）：⚠ 集中の分は消えない・⚠ 打ちかけの字は残る。
		var today_before_timeout: int = GameManager.get_cumulative_focus_minutes()
		var timeout_min: int = int(float(p.get("phase_total_sec")) / 60.0)
		p.set("time_left_sec", 0.01)
		await _wait()
		var reflection_view: Node = p.find_child("ReflectionView", true, false)
		var half_text: String = "書きかけの振り返り"
		if reflection_view != null:
			reflection_view.call("set_text", half_text)
		p.set("time_left_sec", 0.01)
		await _wait()
		var reflections: Array = p.get("reflections") as Array
		var last: Dictionary = {} if reflections.is_empty() else reflections[reflections.size() - 1] as Dictionary
		_check("時間切れ：振り返りが時間切れでも集中の分は入る（%d → %d・%d分）・書きかけの字は残る（%s）・休憩へ" % [today_before_timeout, GameManager.get_cumulative_focus_minutes(), timeout_min, str(last)],
			GameManager.get_cumulative_focus_minutes() == today_before_timeout + timeout_min and bool(last.get("skipped", false))
			and str(last.get("text", "")) == half_text and int(p.get("current_state")) == 3)
		# 続ける（10-06・不便2・人間「⚠ ２は続けられるように」）：⚠ 4セット目の振り返りのあとも拠点へ戻らず長い休憩 → ⚠ 5セット目は「2周目」。
		p.set("current_set_index", 2)
		p.set("time_left_sec", 0.01)
		await _wait(OPEN_FRAMES)
		p.set("time_left_sec", 0.01)
		await _wait()
		_check("続ける：4セット目（%d）の集中が終わると振り返り" % int(p.get("current_set_index")), int(p.get("current_set_index")) == 3 and int(p.get("current_state")) == 2)
		p.call("_on_reflection_completed", "四セット目の振り返りです。二十字を超えるように書いておく。", false)
		await _wait()
		_check("続ける：4セット目のあとも拠点へ戻らず長い休憩（%.0f 秒・%s）" % [float(p.get("phase_total_sec")), str(get_tree().current_scene == p)],
			get_tree().current_scene == p and int(p.get("current_state")) == 3 and is_equal_approx(float(p.get("phase_total_sec")), 20.0 * 60.0)
			and _label_text(p, "BreakView", "TypeLabel") == tr("ui_pomodoro_break_long"))
		p.set("time_left_sec", 0.01)
		await _wait(OPEN_FRAMES)
		_check("続ける：長い休憩のあとは5セット目・上に「%s」" % _label_text(p, "TopBar", "RoundLabel"),
			int(p.get("current_set_index")) == 4 and int(p.get("current_state")) == 1 and (p.get("set_titles") as Array).size() == 5
			and _label_text(p, "TopBar", "RoundLabel") == tr("ui_pomodoro_round") % 2 and (p.find_child("RoundLabel", true, false) as Control).visible)
		# ⚠ 後片付け（⚠ 設定を既定に戻す）。
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_DAILY_GOAL, 0)
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_AUTO_START, false)
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_LONG_BREAK_MINUTES, 30)
		await _open(BASE, {})

	# --- 小窓にしますか？（10-06・PLAN_POMODORO_USABILITY 不便7・人間「⚠ 初回だけ聞く」） ---
	#   ⚠ 「このまま」→ 設定はオフのまま・もう聞かない → ⚠ もう一度聞く状態に戻して「小窓にする」→ 設定オン・小窓。
	func _flow_mini_ask() -> void:
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_WINDOW, false)
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_ASKED, false)
		var p: Node = await _open(POMODORO, {})
		await _pomodoro_start_focus(p)
		await _wait()
		var modal: ModalDialog = _modal_of(p)
		_check("小窓を聞く：はじめて集中を始めると「%s」の窓（はい=%s・いいえ=%s）" % ["" if modal == null else modal.title_label.text, "" if modal == null else modal.confirm_button.text, "" if modal == null else modal.close_button.text],
			modal != null and modal.confirm_button.text == tr("ui_pomodoro_mini_ask_yes") and modal.close_button.text == tr("ui_pomodoro_mini_ask_no")
			and GameSettings.mini_window_asked() and bool(p.get("is_timer_active")))
		if modal != null:
			modal.close_button.pressed.emit()
		await _wait(WAIT_FRAMES * 3)
		_check("小窓を聞く：「このまま」で設定はオフのまま・大きいまま", not GameSettings.mini_window() and not bool(p.call("is_mini_window_active")) and _modal_of(p) == null)
		p = await _open(POMODORO, {})
		await _pomodoro_start_focus(p)
		await _wait()
		_check("小窓を聞く：2回目は聞かない", _modal_of(p) == null and bool(p.get("is_timer_active")))
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_ASKED, false)
		p = await _open(POMODORO, {})
		await _pomodoro_start_focus(p)
		await _confirm_modal()
		_check("小窓を聞く：「小窓にする」で設定がオン・いま小窓", GameSettings.mini_window() and bool(p.call("is_mini_window_active")))
		# ⚠ 後片付け（⚠ 既定に戻す・⚠ 聞いたことにしておく）。
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_WINDOW, false)
		GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_MINI_ASKED, true)
		await _open(BASE, {})

	func _pomodoro_start_focus(p: Node) -> void:
		if p == null:
			return
		var select_view: Node = p.find_child("ProtectionSelectView", true, false)
		if select_view != null:
			await _press(select_view.find_child("StartButton", true, false), OPEN_FRAMES)
		var focus_view: Node = p.find_child("FocusView", true, false)
		if focus_view != null:
			await _press(focus_view.find_child("StartButton", true, false))

	# --- 帰還報告書（2026-09-29・回UI-仕組み④・`EXEC_RUN_REPORT.md`・人間「⚠ 1い　⚠ 2あ　⚠ 3い」） ---
	#   ⚠ 持ち帰り（わかれ道の「ここで戻る」）／ 2回目の浅い持ち帰り ／ 降りた（マップのメニュー）／ 倒れた ／ 通常の依頼のクリア ／ 最深のセーブ。

	func _flow_run_report() -> void:
		if GameManager.is_in_dungeon():
			GameManager.abandon_dungeon_run()
		if GameManager.is_in_floor():
			GameManager.abandon_floor()
		var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
		# ⚠ 宝箱は chests.json（⚠ items.json には無い）。
		var chest_id: String = ""
		for raw: Variant in MasterDataLoader.get_all_chests():
			if GameManager.is_chest_item(str(raw)):
				chest_id = str(raw)
				break
		var material_id: String = GameManager.get_material_ids()[0]
		var best_before: int = GameManager.get_dungeon_best_floors(dungeon_id)

		# 持ち帰り：⚠ ボスを倒した先で宝箱と素材を鞄に入れ、⚠ わかれ道の「ここで戻る」を押す。
		GameManager.start_dungeon_run(dungeon_id)
		GameManager.debug_mark_dungeon_boss_cleared()
		GameManager.add_to_dungeon_bag(chest_id, 1)
		GameManager.add_to_dungeon_bag(material_id, 2)
		var fork: Node = await _open(DUNGEON_FLOOR_CLEAR, {})
		if fork == null:
			return
		await _press(fork.find_child("RetreatButton", true, false), OPEN_FRAMES)
		var r: Node = get_tree().current_scene
		var heading: Node = r.find_child("ReportHeading", true, false)
		_check("帰還報告書：「ここで戻る」で帰還報告書（題=%s・フロア %s）" % [str(heading.get("title_key")) if heading != null else "?", _label_text(r, "FloorLine", "FloorsLabel")],
			_path_of(r) == REPORT and heading is SheetHeading and (heading as SheetHeading).title_key == "ui_report_title_returned"
			and _label_text(r, "FloorLine", "FloorsLabel") == tr("ui_report_layer_span") % [1, GameManager.get_dungeon_layers_per_floor(dungeon_id)]
			and r.find_child("Boss_1", true, false) != null)
		_check("帰還報告書：持ち帰った品（宝箱・素材）と「宝箱は宝物庫へ」・「宝箱を開けに行く」",
			r.find_child("Item_" + chest_id, true, false) != null and r.find_child("Item_" + material_id, true, false) != null
			and r.find_child("ChestNote", true, false) != null and r.find_child("ChestButton", true, false) != null)
		_check("帰還報告書：最深を更新したら判（最深 %d → %d）" % [best_before, GameManager.get_dungeon_best_floors(dungeon_id)],
			GameManager.get_dungeon_best_floors(dungeon_id) == maxi(best_before, 1)
			and ((r.find_child("BestStamp", true, false) != null) == (best_before < 1)))
		_check("帰還報告書：開いたら「見た」になる", not GameManager.has_unseen_run_report())
		await _press(r.find_child("ChestButton", true, false), OPEN_FRAMES)
		_check("帰還報告書：「宝箱を開けに行く」で届いた宝箱", _path_of(get_tree().current_scene) == CHEST)

		# 2回目：⚠ 同じ深さでは判は出ない（⚠ 今の最深を小さく出す）。
		GameManager.start_dungeon_run(dungeon_id)
		GameManager.debug_mark_dungeon_boss_cleared()
		var _again: Dictionary = GameManager.retreat_from_dungeon()
		r = await _open(REPORT, {})
		_check("帰還報告書：同じ深さでは「最深 更新」の判は出ない（%s）" % _label_text(r, "FloorLine", "BestLabel"),
			r.find_child("BestStamp", true, false) == null and _label_text(r, "FloorLine", "BestLabel")
			== tr("ui_report_best") % (GameManager.get_dungeon_best_floors(dungeon_id) * GameManager.get_dungeon_layers_per_floor(dungeon_id)))
		await _press(r.find_child("HomeButton", true, false), OPEN_FRAMES)
		_check("帰還報告書：「本部へ戻る」で本部", _path_of(get_tree().current_scene) == BASE)

		# 降りた：⚠ マップのメニューの「その場で降りる」→ 確かめの窓の「はい」→ 撤退報告書（失った品）。
		GameManager.start_dungeon_run(dungeon_id)
		GameManager.add_to_dungeon_bag(material_id, 5)
		var map: Node = await _open(DUNGEON_MAP, {})
		if map != null:
			map.call("_on_abandon_pressed")
			await _confirm_modal()
			await _wait(OPEN_FRAMES)
			r = get_tree().current_scene
			heading = r.find_child("ReportHeading", true, false)
			_check("帰還報告書：降りると撤退報告書・失った品・「失わないもの」の注記・宝箱の口は無い",
				_path_of(r) == REPORT and heading is SheetHeading and (heading as SheetHeading).title_key == "ui_report_title_abandoned"
				and r.find_child("Item_" + material_id, true, false) != null and r.find_child("LostNote", true, false) != null
				and r.find_child("ChestButton", true, false) == null and r.find_child("NoBossLabel", true, false) != null)

		# 倒れた：⚠ 全員脱落の口（`apply_dungeon_battle_result()` が呼ぶ形）→ 敗走報告書。
		GameManager.start_dungeon_run(dungeon_id)
		GameManager.abandon_dungeon_run(GameManager.RUN_END_DEFEATED)
		_check("帰還報告書：倒れると見ていない報告がある", GameManager.has_unseen_run_report())
		r = await _open(REPORT, {})
		heading = r.find_child("ReportHeading", true, false)
		_check("帰還報告書：倒れると敗走報告書", heading is SheetHeading and (heading as SheetHeading).title_key == "ui_report_title_defeated")

		# 通常の依頼のクリア：⚠ 鞄を持ち帰る口（ボスを倒したとき）→ 帰還報告書（通常の依頼）。
		GameManager.start_floor("floor_1")
		GameManager.add_to_run_bag(GameManager.RUN_KIND_FLOOR, material_id, 3)
		var _delivered: Dictionary = GameManager.deliver_floor_bag()
		GameManager.abandon_floor()
		r = await _open(REPORT, {})
		heading = r.find_child("ReportHeading", true, false)
		_check("帰還報告書：通常の依頼のクリアにも帰還報告書（%s）" % str(heading.get("right_text")) if heading != null else "?",
			heading is SheetHeading and (heading as SheetHeading).title_key == "ui_report_title_returned"
			and (heading as SheetHeading).right_text == tr("ui_quest_tab_normal") and r.find_child("Item_" + material_id, true, false) != null)

		# 最深はセーブに残る（⚠ 読み込みで int に戻る）。
		var best_now: int = GameManager.get_dungeon_best_floors(dungeon_id)
		GameManager.load_state(GameManager.get_state().duplicate(true))
		_check("帰還報告書：最深はセーブに残る（%d）" % GameManager.get_dungeon_best_floors(dungeon_id), best_now > 0 and GameManager.get_dungeon_best_floors(dungeon_id) == best_now)

	# --- 設定（2026-09-28・回UI-仕組み③・手本 Settings・人間「⚠ 1あ　⚠ 2あ　⚠ 3い　⚠ 4あ」） ---
	#   ⚠ 設定のファイルは検査用（`SETTINGS_TEST_PATH`）に差し替えてある。

	func _flow_settings() -> void:
		# ⚠ 09-28：⚠ 途中で置き場所が本物へ戻り、本物の設定を書いた（⚠ static 変数が初期値に戻った）＝⚠ ここで見張る。
		_check("設定：検査の設定ファイルを使っている（%s）" % GameSettings.path(), GameSettings.path() == SETTINGS_TEST_PATH)
		if GameSettings.path() != SETTINGS_TEST_PATH:
			return
		var b: Node = await _open(BASE, {})
		if b == null:
			return
		var settings_button: Node = b.find_child("SettingsButton", true, false)
		_check("本部：「設定」ボタンが出ている", settings_button is Control and (settings_button as Control).visible)
		await _press(settings_button, OPEN_FRAMES)
		var s: Node = get_tree().current_scene
		_check("本部の「設定」で設定の画面（タブ4枚）", _path_of(s) == SETTINGS and _tab_button(s, 3) != null and _tab_button(s, 4) == null)
		if _path_of(s) != SETTINGS:
			return
		# 表示：⚠ 全画面を選ぶと設定に残る（⚠ ヘッドレスでは窓は変わらない）→ 窓に戻す。
		await _press(s.find_child("Display_true", true, false))
		var chosen: Node = s.find_child("Display_true", true, false)
		_check("設定：表示「全画面」を選ぶと残る・札が選ばれた姿", GameSettings.is_fullscreen() and chosen is Button and (chosen as Button).theme_type_variation == &"PaperChoiceSelected")
		await _press(s.find_child("Display_false", true, false))
		_check("設定：表示「窓」に戻せる", not GameSettings.is_fullscreen())
		# 音：⚠ つまみを動かすと設定に残り、⚠ 右の % が変わる。
		await _press(_tab_button(s, 1))
		var slider: Node = s.find_child("SeRow", true, false).find_child("Slider", true, false) if s.find_child("SeRow", true, false) != null else null
		if slider is HSlider:
			(slider as HSlider).value = 40
			await get_tree().process_frame
		_check("設定：効果音を 40%% にすると残る（%d%%・表示 %s）" % [GameSettings.volume_pct(GameSettings.KEY_SE), _label_text(s, "SeRow", "ValueLabel")],
			GameSettings.volume_pct(GameSettings.KEY_SE) == 40 and _label_text(s, "SeRow", "ValueLabel") == tr("ui_settings_percent") % 40)
		# ポモドーロ：⚠ 集中 45分・休憩 10分を選ぶ → ⚠ ポモドーロの画面の長さが変わる。
		await _press(_tab_button(s, 2))
		await _press(s.find_child("Focus_45", true, false))
		await _press(s.find_child("Break_10", true, false))
		_check("設定：集中 45分・休憩 10分を選ぶと残る（%d・%d）" % [GameSettings.focus_minutes(), GameSettings.break_minutes()],
			GameSettings.focus_minutes() == 45 and GameSettings.break_minutes() == 10)
		# ⚠ 09-29（回UI-仕組み⑥）：⚠ 小窓の2行はオフ｜オン（⚠ 既定オフ・いつも前はオン）／ ⚠ 「話しかける」だけ「まだ」。
		_check("設定：小窓はオフ｜オン（既定オフ）・いつも前は既定オン・「話しかける」だけ「まだ」",
			s.find_child("Mini_false", true, false) is Button and (s.find_child("Mini_false", true, false) as Button).theme_type_variation == &"PaperChoiceSelected"
			and s.find_child("MiniTop_true", true, false) is Button and (s.find_child("MiniTop_true", true, false) as Button).theme_type_variation == &"PaperChoiceSelected"
			and s.find_child("TalkRow", true, false) != null and s.find_children("LaterLabel", "", true, false).size() == 1)
		# データ：⚠ セーブを消すは置かない（「⚠ 3い」）。
		await _press(_tab_button(s, 3))
		var sheet_body: Node = s.find_child("SheetBody", true, false)
		_check("設定：データはセーブを消すボタンが無く案内だけ", s.find_child("DataNoteRow", true, false) != null
			and sheet_body != null and sheet_body.find_children("*", "BaseButton", true, false).is_empty())
		var header: Node = s.find_child("Header", true, false)
		await _press(null if header == null else header.find_child("BackButton", true, false), OPEN_FRAMES)
		_check("設定：「戻る」で本部", _path_of(get_tree().current_scene) == BASE)
		var p: Node = await _open(POMODORO, {})
		if p != null:
			var preset: Variant = p.get("current_preset")
			_check("ポモドーロ：設定の長さで始まる（集中 %s 秒・休憩 %s 秒）" % [str(preset.focus_duration_sec) if preset != null else "?", str(preset.short_break_sec) if preset != null else "?"],
				preset != null and int(preset.focus_duration_sec) == 45 * 60 and int(preset.short_break_sec) == 10 * 60)

	# --- 記録（2026-09-28・回UI-仕組み②・手本 Records・人間「⚠ 1い　⚠ 2あ　⚠ 3い　⚠ 4あ　⚠ 5あ」） ---

	func _flow_records() -> void:
		var r: Node = get_tree().current_scene
		if _path_of(r) != RECORDS:
			return
		# 図鑑：⚠ 数は GameManager の口と揃う・⚠ 手に入れていない品は「？」の枠・⚠ 素材の段もある。
		var found: int = 0
		var total: int = 0
		var records: RecordsScreen = r as RecordsScreen
		for kind: String in GameManager.CODEX_KINDS:
			var counts: Vector2i = records.codex_counts(kind)
			found += counts.x
			total += counts.y
		var heading: Node = r.find_child("CodexHeading", true, false)
		_check("記録：図鑑の見出しに「%d / %d」" % [found, total], heading is SheetHeading and (heading as SheetHeading).right_text == "%d / %d" % [found, total] and total > 0)
		# ⚠ 種類の切り替え（⚠ 09-29 人間「⚠ 2あ」）：⚠ 最初は装備だけ・⚠ 札を押すとその種類だけ。
		_check("記録：図鑑は「装備｜装飾｜素材」の切り替え・最初は装備だけ",
			r.find_child("KindChoices", true, false) != null and r.find_child("KindChoices", true, false).get_child_count() == 3
			and r.find_child("Section_equipment", true, false) != null and r.find_child("Section_part", true, false) == null and r.find_child("Section_material", true, false) == null)
		var shown: int = 0
		var unknown: int = 0
		for kind: String in GameManager.CODEX_KINDS:
			await _press(r.find_child("Kind_" + kind, true, false))
			await _wait()
			shown += r.find_children("Found_*", "", true, false).size() + r.find_children("Grade_*", "", true, false).size()
			unknown += r.find_children("Unknown_*", "", true, false).size() + r.find_children("UnknownGrade_*", "", true, false).size()
		_check("記録：3種類を切り替えると、手に入れた品（装備は等級）は絵・まだは「？」（絵 %d ／ ？ %d）" % [shown, unknown], shown == found and unknown == total - found)
		_check("記録：「素材」を押すと素材の段だけ", r.find_child("Section_material", true, false) != null and r.find_child("Section_equipment", true, false) == null)
		await _press(r.find_child("Kind_" + GameManager.CODEX_KIND_EQUIPMENT, true, false))
		await _wait()
		# ⚠ 装備は部位ごとの表（⚠ 09-28 人間「⚠ 等級ごとに列を作って　⚠ カテゴリごとに分ける」）：⚠ 列＝等級1〜最大 ／ 部位の小見出し。
		var header_row: Node = r.find_child("GradeHeader", true, false)
		_check("記録：装備の表は等級の列（%d）と部位の小見出し（%d）" % [0 if header_row == null else header_row.get_child_count() - 1, r.find_children("Slot_*", "", true, false).size()],
			header_row != null and header_row.get_child_count() - 1 == GameManager.get_max_equipment_grade()
			and r.find_children("Slot_*", "", true, false).size() > 1 and r.find_children("Row_*", "", true, false).size() == GameManager.get_codex_ids(GameManager.CODEX_KIND_EQUIPMENT).size())
		# ⚠ 品を押すと右に詳しく出る（⚠ 09-28 見る回・人間「⚠ クリックすると詳細も見れるようにしたい」）。
		_check("記録：選ぶ前は右に「品を押すと」の案内", r.find_child("DetailNone", true, false) != null)
		# ⚠ 素材の段で品を押す → ⚠ 右に名前・手に入れた数（⚠ 09-29 人間「⚠ 持っている数ではなく手に入れた数で」）・初めて手に入れた日。
		await _press(r.find_child("Kind_" + GameManager.CODEX_KIND_MATERIAL, true, false))
		await _wait()
		var founds: Array = r.find_children("Found_*", "", true, false)
		var first_found: Node = null if founds.is_empty() else founds[0]
		var picked_id: String = "" if first_found == null else str(first_found.name).trim_prefix("Found_")
		await _press(first_found)
		await _wait()
		_check("記録：品を押すと右に名前と手に入れた数 %s（口 %d）・初めて手に入れた日（%s）" % [_label_text(r, "ObtainedCountLine", "ValueLabel"), GameManager.get_codex_obtained_count(picked_id), _label_text(r, "CodexDetail", "DetailName")],
			picked_id != "" and _label_text(r, "CodexDetail", "DetailName") == tr(GameManager.item_name_key(picked_id))
			and _label_text(r, "ObtainedCountLine", "ValueLabel") == tr("ui_records_detail_count") % GameManager.get_codex_obtained_count(picked_id)
			and r.find_child("ObtainedLine", true, false) != null
			and (r.find_child("Found_" + picked_id, true, false) as Button).theme_type_variation == &"RecordsCellPicked")
		# ⚠ 手に入れた数は増えるだけ（⚠ 入れると増え・⚠ 使っても減らない）。
		if picked_id != "":
			var obtained_before: int = GameManager.get_codex_obtained_count(picked_id)
			GameManager.add_material(picked_id, 3)
			GameManager.add_material(picked_id, -2)
			_check("記録：素材を3個入れると手に入れた数が3増え、2個使っても減らない（%d → %d）" % [obtained_before, GameManager.get_codex_obtained_count(picked_id)],
				GameManager.get_codex_obtained_count(picked_id) == obtained_before + 3)
		await _press(r.find_child("Kind_" + GameManager.CODEX_KIND_EQUIPMENT, true, false))
		await _wait()
		# ⚠ 装備の等級の枠を押すと、その等級の値（⚠ `get_item_stats_at_grade()`）。
		var grade_cells: Array = r.find_children("Grade_*", "", true, false)
		if not grade_cells.is_empty():
			var grade_cell: Node = grade_cells[grade_cells.size() - 1]
			var parts: PackedStringArray = str(grade_cell.name).trim_prefix("Grade_").rsplit("_", true, 1)
			await _press(grade_cell)
			await _wait()
			_check("記録：装備の等級の枠を押すとその等級（%s・等級 %s）" % [parts[0], _label_text(r, "GradeLine", "ValueLabel")],
				_label_text(r, "CodexDetail", "DetailName") == tr(GameManager.item_name_key(parts[0])) and _label_text(r, "GradeLine", "ValueLabel") == parts[1])
		else:
			_check("記録：装備の等級の枠が1つも無い", false)
		# ⚠ 素材も図鑑に載る（「⚠ 2あ」）：⚠ まだの素材を1個入れると載る。
		var fresh: String = ""
		for material_id: String in GameManager.get_codex_ids(GameManager.CODEX_KIND_MATERIAL):
			if not GameManager.is_codex_discovered(material_id):
				fresh = material_id
				break
		if fresh != "":
			GameManager.add_material(fresh, 1)
			await _press(_tab_button(r, 1))
			await _press(_tab_button(r, 0))
			await _press(r.find_child("Kind_" + GameManager.CODEX_KIND_MATERIAL, true, false))
			await _wait()
			_check("記録：素材を手に入れると図鑑に載る（%s）" % fresh, GameManager.is_codex_discovered(fresh) and r.find_child("Found_" + fresh, true, false) != null)
		# 集中の履歴：合計・今日・最後（⚠ 日ごとの履歴はまだ＝「⚠ 5あ」）。
		await _press(_tab_button(r, 1))
		_check("記録：集中の履歴に合計 %s・今日 %s" % [_label_text(r, "TotalRow", "ValueLabel"), _label_text(r, "TodayRow", "ValueLabel")],
			_label_text(r, "TotalRow", "ValueLabel") == tr("ui_records_count") % GameManager.get_total_pomodoro_completed()
			and _label_text(r, "TodayRow", "ValueLabel") == tr("ui_records_minutes") % GameManager.get_cumulative_focus_minutes_today()
			and r.find_child("FocusNote", true, false) != null)
		# キャラの情報：⚠ 候補ぜんぶの行・⚠ 押すとその人の育成。
		await _press(_tab_button(r, 2))
		var candidates: Array = GameManager.get_party_candidates()
		_check("記録：キャラの情報に %d 人" % candidates.size(), r.find_children("Character_*", "", true, false).size() == candidates.size() and candidates.size() > 0)
		# ダンジョンの情報：⚠ 話ごとに済・まだ ／ 難ダンジョン。
		await _press(_tab_button(r, 3))
		var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
		var first_stage: String = str(order[0]) if not order.is_empty() else ""
		_check("記録：ダンジョンの情報に話 %d・難ダンジョン %d（1話=%s）" % [r.find_children("Stage_*", "", true, false).size(), r.find_children("Dungeon_*", "", true, false).size(), _label_text(r, "Stage_" + first_stage, "ValueLabel")],
			r.find_children("Stage_*", "", true, false).size() == order.size() and r.find_children("Dungeon_*", "", true, false).size() == MasterDataLoader.get_all_dungeon_ids().size()
			and _label_text(r, "Stage_" + first_stage, "ValueLabel") == tr("ui_records_cleared" if GameManager.is_stage_cleared(first_stage) else "ui_records_not_cleared"))
		# ⚠ 前のセーブ（図鑑の装備に grades が無い）を読むと、⚠ 持っている個体の等級まで埋まる（`EXEC_CODEX_GRADES.md` §5）。
		#   ⚠ ここまでの手で装備を手放していることがある＝⚠ 木の剣を1本入れて等級3まで鍛えてから見る（⚠ 本番の口だけ）。
		GameManager.add_to_inventory("weapon_wooden_sword", 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
		for raw: Variant in GameManager.get_owned_instances():
			if str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == "weapon_wooden_sword" \
					and int((raw as Dictionary).get(GameStateKeys.INSTANCE_GRADE, 1)) == 1:
				var sword_id: String = str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
				GameManager.forge_equipment(sword_id)
				GameManager.forge_equipment(sword_id)
				break
		var old_state: Dictionary = GameManager.get_state().duplicate(true)
		var top: Dictionary = {}
		for raw: Variant in GameManager.get_owned_instances():
			var held_id: String = str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
			top[held_id] = maxi(int(top.get(held_id, 0)), int((raw as Dictionary).get(GameStateKeys.INSTANCE_GRADE, 1)))
		for item_id: Variant in (old_state[GameStateKeys.CODEX] as Dictionary):
			((old_state[GameStateKeys.CODEX] as Dictionary)[item_id] as Dictionary).erase(GameStateKeys.CODEX_GRADES)
			((old_state[GameStateKeys.CODEX] as Dictionary)[item_id] as Dictionary).erase(GameStateKeys.CODEX_OBTAINED_COUNT)
		GameManager.load_state(old_state)
		# ⚠ 手に入れた数は、いま持っている数で埋まる（⚠ §7-2・下限）。
		if picked_id != "":
			_check("記録：前のセーブを読むと手に入れた数は持っている数（%s %d ＝ %d）" % [picked_id, GameManager.get_codex_obtained_count(picked_id), GameManager.get_material_count(picked_id)],
				GameManager.get_codex_obtained_count(picked_id) == GameManager.get_material_count(picked_id))
		var migrated: bool = not top.is_empty()
		for held_id: String in top:
			var expect: Array[int] = []
			for grade: int in range(1, int(top[held_id]) + 1):
				expect.append(grade)
			if GameManager.get_codex_grades(held_id) != expect:
				migrated = false
		_check("記録：前のセーブを読むと持っている装備の等級まで図鑑が埋まる（%d 品）" % top.size(), migrated)
		await _press(_tab_button(r, 2))
		var hero_row: Node = r.find_child("Character_" + str(candidates[0]), true, false)
		await _press(hero_row, OPEN_FRAMES)
		_check("記録：キャラの行を押すとその人の育成", _path_of(get_tree().current_scene) == TRAINING)

	# --- 詰所＝出撃の準備（2026-09-28・モック・決定 `NAV-11`）：ガイド ／ 枠 → 名簿 ／ ビルド ▼ ／ 控え（残す・呼ぶ）／ 選んだ人を育成で ---

	func _flow_barracks() -> void:
		# ⚠ 名簿の検査のため、⚠ 英雄のビルド2を先に焼いておく（⚠ 本番の口）。
		GameManager.save_character_preset(HERO, 1)
		var r: Node = get_tree().current_scene
		await _press(r.find_child("Facility_" + BaseFacilityBar.BARRACKS, true, false), OPEN_FRAMES)
		var b: Node = get_tree().current_scene
		_check("詰所：施設の帯の「詰所」で詰所が開く", _path_of(b) == BARRACKS)
		if _path_of(b) != BARRACKS:
			return

		# はじめてのガイド（⚠ 人間「⚠ 2あ」）：⚠ 初めてだけ出る ／ つぎへ → はじめるで消えて「見た」になる。
		var guide: Node = b.find_child("SortieGuide", true, false)
		_check("詰所：はじめてのガイドが出る（見た=%s）" % str(GameManager.is_guide_seen(GameManager.GUIDE_SORTIE)), guide is SortieGuide and not GameManager.is_guide_seen(GameManager.GUIDE_SORTIE))
		var first_title: String = _label_text(b, "SortieGuide", "TitleLabel")
		await _press(null if guide == null else guide.find_child("GuideNext", true, false))
		_check("詰所：「つぎへ」でガイドの2枚目（%s → %s）" % [first_title, _label_text(b, "SortieGuide", "TitleLabel")], _label_text(b, "SortieGuide", "TitleLabel") != first_title and _label_text(b, "SortieGuide", "TitleLabel") != "")
		await _press(null if guide == null else guide.find_child("GuideNext", true, false))
		_check("詰所：「はじめる」でガイドが消えて「見た」になる", b.find_child("SortieGuide", true, false) == null and GameManager.is_guide_seen(GameManager.GUIDE_SORTIE))

		var members: Array = GameManager.get_party_members()
		_check("詰所：3つの枠・控え %d 件・「選んだ人を育成で開く」（出撃する・署名の行・受理の判は無い）" % b.find_children("Preset_*", "", true, false).size(),
			b.find_children("Slot_*", "", true, false).size() == 3 and b.find_children("Preset_*", "", true, false).size() == GameManager.get_party_preset_count()
			and b.find_child("OpenTrainingButton", true, false) != null and b.find_child("SortieButton", true, false) == null
			and b.find_children("Signature_*", "", true, false).is_empty() and b.find_child("AcceptStamp", true, false) == null)

		# 光り方（⚠ 09-28 人間「⚠ ハイライトするのは入れ替えもとだけでいい」「⚠ 出撃してない人だけハイライト」）：
		#   ⚠ 選ぶ前はどの枠も光らない ／ ⚠ 名簿は出撃していない人の札だけ光る ／ ⚠ 枠を押すとその枠だけ光る。
		var lit_slots: int = 0
		for i: int in range(3):
			if b.find_child("Slot_%d" % i, true, false).find_child("PulseFrame", false, false) != null:
				lit_slots += 1
		var lit_ok: bool = true
		for character_id: String in GameManager.get_party_candidates():
			var card: Node = b.find_child("Roster_" + character_id, true, false)
			var lit: bool = card != null and card.find_child("PulseFrame", false, false) != null
			if lit == (character_id in members):
				lit_ok = false
		_check("詰所：選ぶ前は枠が光らない（%d）・名簿は出撃していない人だけ光る" % lit_slots, lit_slots == 0 and lit_ok)
		# ◀ ▶（⚠ 09-28 人間「⚠ 入れ替えは、上側でできるように　⚠ 右と左にボタンを作ってそこと入れ替え」）。
		_check("詰所：1番の「◀」と3番の「▶」は押せない",
			(b.find_child("MoveLeft_0", true, false) as Button).disabled and (b.find_child("MoveRight_2", true, false) as Button).disabled)
		await _press(b.find_child("MoveRight_0", true, false))
		var moved: Array = GameManager.get_party_members()
		_check("詰所：1番の「▶」で2番と入れ替わる（%s → %s）" % [str(members), str(moved)], moved[0] == members[1] and moved[1] == members[0] and moved[2] == members[2])
		await _press(b.find_child("MoveLeft_1", true, false))
		_check("詰所：2番の「◀」で元に戻る", GameManager.get_party_members() == members)
		# 枠 → 名簿（⚠ 人間「⚠ キャラを選んで入れ替えるってのが大事」）：3番を押す → 1番の人に「1番と入れ替わる」→ 押すと入れ替わる。
		await _press(_slot_hit(b, 2))
		var picked_frame: Node = b.find_child("Slot_2", true, false).find_child("PulseFrame", false, false)
		_check("詰所：3番を押すとその枠だけ光る（名簿の板は光らない）",
			picked_frame is PulseFrame and b.find_child("Slot_0", true, false).find_child("PulseFrame", false, false) == null
			and b.find_child("Roster", true, false).find_child("PulseFrame", false, false) == null)
		var badge: String = _label_text(b, "Roster_" + str(members[0]), "Badge")
		_check("詰所：3番の枠を押すと名簿に「1番と入れ替わる」（%s）" % badge, badge == tr("ui_sortie_swap_with") % 1)
		await _press(_roster_hit(b, str(members[0])))
		var swapped: Array = GameManager.get_party_members()
		_check("詰所：名簿で1番の人を選ぶと入れ替わる（%s → %s）" % [str(members), str(swapped)], swapped[2] == members[0] and swapped[0] == members[2] and swapped[1] == members[1])

		# ビルド ▼：吹き出しで選ぶと当てる（⚠ 中身の無いビルドは押せない）。
		await _press(b.find_child("Build_" + HERO, true, false))
		var pop: Node = _first_of_type(b, "SlotActionPopover")
		var empty_choice: Node = null if pop == null else pop.find_child("BuildChoice_2", true, false)
		_check("詰所：ビルドの吹き出し・中身の無いビルド3は押せない", pop != null and empty_choice is Button and (empty_choice as Button).disabled)
		await _press(null if pop == null else pop.find_child("BuildChoice_1", true, false))
		var build_button: Node = b.find_child("Build_" + HERO, true, false)
		_check("詰所：ビルド2を選ぶと当たる（%s）" % ((build_button as Button).text if build_button is Button else ""), int(b.get("_selected_builds").get(HERO, -1)) == 1)

		# 控え：1件目で「いまを残す」→「いまと同じ」の判 ／ 並びを変えて「呼ぶ」→ 予告の窓 → 呼ぶで戻る ／ 上書きは確かめる。
		await _press(b.find_child("Preset_0", true, false))
		await _press(b.find_child("KeepButton", true, false))
		var preset: Dictionary = GameManager.get_party_presets()[0]
		var hero_index: int = -1
		for entry: Variant in preset.get(GameStateKeys.PRESET_SLOTS, []):
			if str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, "")) == HERO:
				hero_index = int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, -1))
		_check("詰所：「いまを残す」で控え1に残る（ビルド番号 %d）・「いまと同じ」の判" % (hero_index + 1),
			bool(preset.get(GameStateKeys.PRESET_SAVED, false)) and hero_index == 1 and b.find_child("Preset_0", true, false).find_child("SameStamp", true, false) != null)
		var kept: Array = GameManager.get_party_members()
		await _press(_slot_hit(b, 0))
		await _press(_roster_hit(b, str(kept[1])))
		_check("詰所：並びを変えると「いまと同じ」が消える", b.find_child("Preset_0", true, false).find_child("SameStamp", true, false) == null)
		await _press(b.find_child("CallButton", true, false))
		var modal: ModalDialog = _modal_of(b)
		_check("詰所：「呼ぶ」で予告の窓（並び・ビルド）", modal != null and modal.find_child("CallPreview", true, false) != null)
		await _confirm_modal()
		_check("詰所：予告の窓で「呼ぶ」→ 残した並びに戻る（%s）" % str(GameManager.get_party_members()), GameManager.get_party_members() == kept)
		await _press(b.find_child("KeepButton", true, false))
		_check("詰所：保存済みの控えに「いまを残す」は上書きを確かめる", _modal_of(b) != null)
		await _confirm_modal()

		# 詰所：名簿で人を押して「選んだ人を育成で開く」→ その人の育成。⚠ 戻ると育成の一覧（⚠ 下の手へ続く）。
		await _press(_roster_hit(b, OTHER))
		await _press(b.find_child("OpenTrainingButton", true, false), OPEN_FRAMES)
		var opened: Node = get_tree().current_scene
		_check("詰所：「選んだ人を育成で開く」で %s の育成" % OTHER, _path_of(opened) == TRAINING and str(opened.get("_selected_id")) == OTHER)
		b = await _open(BARRACKS, {})
		if b == null:
			return
		_check("詰所：2回目はガイドが出ない", b.find_child("SortieGuide", true, false) == null)

		# 育成の一覧（⚠ 09-27 の見る回・人間「⚠ 3あ」）：施設の帯 → 身上書カード → 開く → 育成 → 戻るで一覧。
		await _press(b.find_child("Facility_" + BaseFacilityBar.TRAINING, true, false), OPEN_FRAMES)
		var l: Node = get_tree().current_scene
		_check("育成の一覧：施設の帯の「育成」で一覧が開く", _path_of(l) == TRAINING_LIST)
		if _path_of(l) != TRAINING_LIST:
			return
		var cards: int = l.find_children("Dossier", "", true, false).size()
		_check("育成の一覧：身上書カードが %d 枚（キャラ %d 人）" % [cards, TrainingListScreenRef.character_order().size()], cards == TrainingListScreenRef.character_order().size())
		# ⚠ 下ごしらえで素材を持たせてあるので、⚠ 上限でなければ上がれる＝判が出る。
		var can: bool = DossierCard.can_level_up(HERO)
		var hero_card: Node = l.find_child("Card_" + HERO, true, false)
		var stamp: Node = null if hero_card == null else hero_card.find_child("LevelUpStamp", true, false)
		_check("育成の一覧：上がれるなら「昇級できる」の判（上がれる=%s）" % str(can), (stamp != null) == can)
		var other_card: Node = l.find_child("Card_" + OTHER, true, false)
		await _press(null if other_card == null else other_card.find_child("OpenButton", true, false), OPEN_FRAMES)
		var t: Node = get_tree().current_scene
		_check("育成の一覧：「開く ›」で %s の育成が開く" % OTHER, _path_of(t) == TRAINING and str(t.get("_selected_id")) == OTHER)
		var t_header: Node = t.find_child("Header", true, false)
		await _press(null if t_header == null else t_header.find_child("BackButton", true, false), OPEN_FRAMES)
		_check("育成：「戻る」で育成の一覧", _path_of(get_tree().current_scene) == TRAINING_LIST)

	# --- 依頼掲示板（2026-09-27・決定 `NAV-12`）：タブ ／ 札 ／ 出撃届（詰所で変える → 戻る ／ 出撃する）／ 続きから ---

	func _flow_quest_board() -> void:
		var q: Node = await _open(ADVENTURE, {})
		if q == null:
			return
		var story: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
		var first: String = str(story[0])
		_check("掲示板：編成の行は無い", q.find_child("PartyBox", true, false) == null)
		var cards: int = q.find_children("StageCard_*", "", true, false).size()
		_check("掲示板：通常の依頼に話の札が %d 枚＋練習場" % cards, cards == story.size() and q.find_child("TrainingCard", true, false) != null)
		# ⚠ 解放前の話は薄く・ボタンなし（⚠ 2話目は1話目を終えるまで閉じている）。
		if story.size() > 1 and not GameManager.is_stage_cleared(first):
			var second: Node = q.find_child("StageCard_" + str(story[1]), true, false)
			_check("掲示板：解放前の話は「前の話を終えると」でボタンなし", second != null and second.find_child("LockedLabel", true, false) != null and second.find_child("ChallengeButton", true, false) == null)
		await _press(_tab_button(q, 1))
		_check("掲示板：「高難度の依頼」に難ダンジョンの札", q.find_children("DungeonCard_*", "", true, false).size() == MasterDataLoader.get_all_dungeon_ids().size())
		await _press(_tab_button(q, 2))
		_check("掲示板：「検証用」に検証用の札", q.find_children("DebugCard_*", "", true, false).size() == MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_DEBUG).size())
		await _press(_tab_button(q, 0))

		# 受ける → 出撃の準備（⚠ まだ出ない）→ 戻ると掲示板（⚠ 2026-09-28・モック）。
		await _press(q.find_child("StageCard_" + first, true, false).find_child("ChallengeButton", true, false), OPEN_FRAMES)
		var b: Node = get_tree().current_scene
		var quest_title: String = _label_text(b, "Strip", "QuestTitle")
		_check("掲示板：「受ける」で出撃の準備（依頼=%s・まだ出ない）" % quest_title,
			_path_of(b) == BARRACKS and quest_title.contains(tr(str(MasterDataLoader.get_stage(first).get("name_key", ""))))
			and b.find_child("SortieButton", true, false) != null and b.find_child("FacilityBar", true, false) == null and not GameManager.is_in_floor())
		var back: Node = b.find_child("Header", true, false)
		await _press(null if back == null else back.find_child("BackButton", true, false), OPEN_FRAMES)
		q = get_tree().current_scene
		_check("掲示板：出撃の準備の「戻る」で掲示板へ戻る", _path_of(q) == ADVENTURE)
		if _path_of(q) != ADVENTURE:
			return

		# 難ダンジョンも出撃の準備を通す（⚠ 人間「⚠ 4あ」）。⚠ 10-02 から入るのにノルマ札が要る＝1枚持たせて開き直す。
		if not GameManager.has_quota_ticket_for_entry():
			GameManager.add_to_inventory(GameStateKeys.ITEM_QUOTA_TICKET, 1, GameStateKeys.ITEM_TYPE_CONSUMABLE)
			q = await _open(ADVENTURE, {})
		await _press(_tab_button(q, 1))
		var dungeon_id: String = MasterDataLoader.get_all_dungeon_ids()[0]
		await _press(q.find_child("DungeonCard_" + dungeon_id, true, false).find_child("DungeonButton", true, false), OPEN_FRAMES)
		b = get_tree().current_scene
		_check("掲示板：難ダンジョンの「受ける」で出撃の準備", _path_of(b) == BARRACKS and _label_text(b, "Strip", "QuestTitle") == tr(str(MasterDataLoader.get_dungeon(dungeon_id).get("name_key", ""))))
		q = await _open(ADVENTURE, {})
		if q == null:
			return

		# 出撃する → ⚠ 署名（1番から順）→「受理」の判 → フロアのマップ（⚠ 2026-09-28・手本 Sign・人間「⚠ 2い　⚠ 3あ」）。
		await _press(q.find_child("StageCard_" + first, true, false).find_child("ChallengeButton", true, false), OPEN_FRAMES)
		b = get_tree().current_scene
		var sigs: Array = b.find_children("Signature_*", "", true, false)
		var styles: Dictionary = {}
		for sig: Node in sigs:
			styles[(sig as SortieSignature).style()] = true
		var members: Array = GameManager.get_party_members()
		var expect_styles: Dictionary = {}
		for cid: Variant in members:
			expect_styles[str(MasterDataLoader.get_character(str(cid)).get("sign_style", SortieSignature.STYLE_PEN))] = true
		_check("出撃の準備：枠ごとに署名の行（%d 本・書き方 %s）・まだ書いていない" % [sigs.size(), str(styles.keys())],
			sigs.size() == members.size() and styles.size() == expect_styles.size() and sigs.all(func(s: Node) -> bool: return (s as SortieSignature).progress == 0.0))
		await _press(b.find_child("SortieButton", true, false))
		var stamp: Node = b.find_child("AcceptStamp", true, false)
		_check("出撃の準備：「出撃する」で署名が始まる（まだ出ない・押すと飛ばす幕・判はまだ）",
			bool(b.get("_signing")) and b.find_child("SignBlocker", true, false) != null and _path_of(get_tree().current_scene) == BARRACKS
			and stamp is Stamp and (stamp as Stamp).modulate.a == 0.0)
		# ⚠ 1番が書き終わった時点では2番・3番はまだ（⚠ 順に書く）・判もまだ。
		var first_sig: SortieSignature = b.find_child("Signature_0", true, false) as SortieSignature
		var last_sig: SortieSignature = b.find_child("Signature_%d" % (members.size() - 1), true, false) as SortieSignature
		var until: int = Time.get_ticks_msec() + 5000
		while first_sig != null and first_sig.progress < 1.0 and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		_check("出撃の準備：1番から順に書く（1番 %.2f ／ 最後 %.2f・判 %.2f）" % [first_sig.progress, last_sig.progress, (stamp as Stamp).modulate.a],
			first_sig.progress >= 1.0 and last_sig.progress < 1.0 and (stamp as Stamp).modulate.a == 0.0)
		until = Time.get_ticks_msec() + 5000
		while is_instance_valid(stamp) and (stamp as Stamp).modulate.a < 1.0 and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		_check("出撃の準備：全員が書き終わってから「受理」の判", is_instance_valid(stamp) and (stamp as Stamp).modulate.a >= 1.0 and last_sig.progress >= 1.0)
		until = Time.get_ticks_msec() + 5000
		while _path_of(get_tree().current_scene) != FLOOR_MAP and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		await _wait(OPEN_FRAMES)
		_check("掲示板：出撃の準備の「出撃する」→ 署名と判のあとフロアのマップ", _path_of(get_tree().current_scene) == FLOOR_MAP and GameManager.is_in_floor())

		# 続きから → ⚠ 出撃届を挟まずマップ。
		q = await _open(ADVENTURE, {})
		if q == null:
			return
		var resume: Node = q.find_child("StageCard_" + first, true, false).find_child("ChallengeButton", true, false)
		_check("掲示板：途中のフロアは「続きから」", resume is Button and (resume as Button).text == tr("ui_floor_resume"))
		await _press(resume, OPEN_FRAMES)
		_check("掲示板：「続きから」は出撃届を挟まずマップ", _path_of(get_tree().current_scene) == FLOOR_MAP)
		GameManager.abandon_floor()

		# 署名の途中で画面を押すと飛ばしてすぐ出発（⚠ 全員書いた姿・判を押した姿にしてから）。
		q = await _open(ADVENTURE, {})
		if q == null:
			return
		await _press(q.find_child("StageCard_" + first, true, false).find_child("ChallengeButton", true, false), OPEN_FRAMES)
		b = get_tree().current_scene
		await _press(b.find_child("SortieButton", true, false))
		var blocker: Node = b.find_child("SignBlocker", true, false)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		if blocker is Control:
			(blocker as Control).gui_input.emit(click)
		await _wait(OPEN_FRAMES)
		_check("出撃の準備：署名の途中で押すと飛ばしてすぐフロアのマップ", _path_of(get_tree().current_scene) == FLOOR_MAP and GameManager.is_in_floor())
		GameManager.abandon_floor()

	# --- 届いた宝箱（2026-09-27・決定 `BS-21`）：バッジ → 画面 ／ 行を選ぶ ／ 次を開ける（窓は出ない）／ まとめて開ける ／ 戻る ---

	func _flow_chest() -> void:
		# ⚠ 種類ごとに2個ずつ積む（⚠ 抽選のハズレは false＝正常系。⚠ 積めるまで試す）。
		for chest_id: Variant in MasterDataLoader.get_all_chests().keys():
			var granted: int = 0
			for _attempt: int in range(20):
				if GameManager.grant_chest(str(chest_id), GameStateKeys.CHEST_SOURCE_DUNGEON):
					granted += 1
				if granted >= 2:
					break
		var kinds: Dictionary = {}
		for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
			if chest is Dictionary and not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)):
				kinds[str((chest as Dictionary).get(GameStateKeys.CHEST_ID, ""))] = true
		var base: Node = await _open(BASE, {})
		if base == null:
			return
		await _press(base.get("chest_badge"), OPEN_FRAMES)
		var c: Node = get_tree().current_scene
		_check("宝箱：拠点のバッジで「届いた宝箱」の画面", _path_of(c) == CHEST)
		if _path_of(c) != CHEST:
			return
		var rows: Array = c.find_children("ChestRow_*", "", true, false)
		_check("宝箱：帳面の行 %d ＝ 種類 %d" % [rows.size(), kinds.size()], rows.size() == kinds.size() and rows.size() >= 2)
		_check("宝箱：行の絵は宝箱のマス（枠がレアリティの色）", rows.size() > 0 and (rows[0] as Node).find_child("ChestGlyph", true, false) is ItemIcon)
		var second: String = str(kinds.keys()[1]) if kinds.size() > 1 else ""
		await _press(c.find_child("ChestRow_" + second, true, false))
		_check("宝箱：行を押すとその種類を選ぶ", str(c.get("_selected_kind")) == second)
		var before: int = GameManager.get_pending_chest_count()
		var before_kind: int = _pending_of(second)
		await _press(c.find_child("NextButton", true, false))
		_check("宝箱：「次を開ける」で選んだ種類が1減る（%d → %d）" % [before_kind, _pending_of(second)], _pending_of(second) == before_kind - 1 and GameManager.get_pending_chest_count() == before - 1)
		_check("宝箱：確かめの窓は出ない", Modal._current == null or not is_instance_valid(Modal._current))
		var cards: int = c.find_children("Card_*", "", true, false).size()
		_check("宝箱：台に札が出る（%d 枚）・名前は %s" % [cards, _label_text(c, "Stage", "OpenedName")], cards > 0 and _label_text(c, "Stage", "OpenedName") == tr(GameManager.item_name_key(second)))
		var box: Node = c.find_child("Box", true, false)
		_check("宝箱：箱が開いた姿", box is ChestBox and (box as ChestBox).opened)
		var screen: ChestScreen = c as ChestScreen

		# ⚠ 演出は**出た品の等級**で決まる（⚠ 09-28 人間「⚠ 出るアイテムの等級で」「⚠ 1い」＝5 以上・8 以上で強く）。
		var theme: Theme = ThemeDB.get_project_theme()
		var low: Dictionary = {GameStateKeys.REWARD_MATERIALS: {"forging_material_1": 1}}
		var high: Dictionary = {GameStateKeys.REWARD_MATERIALS: {"forging_material_1": 3, "forging_material_4": 1}}
		_check("宝箱：中身のいちばん高い等級で決める（段階1=%d は出さない・段階4=%d は出す／強い=%d 以上）" % [screen.top_grade_of(low), screen.top_grade_of(high), theme.get_constant(&"fx_strong_grade", &"ChestScreen")],
			not screen.is_fx_grade(screen.top_grade_of(low)) and screen.is_fx_grade(screen.top_grade_of(high))
			and screen.top_grade_of(high) >= theme.get_constant(&"fx_strong_grade", &"ChestScreen")
			and theme.get_constant(&"fx_grade", &"ChestScreen") == 5)
		# ⚠ 1つ開ける → 演出中 → 台を押すと飛ばす → 札。⚠ 中身は振られる＝⚠ メモリの中だけ閾値を 0 にして必ず出す。
		for kind: Variant in kinds:
			if _pending_of(str(kind)) > 0:
				await _press(c.find_child("ChestRow_" + str(kind), true, false))
				break
		var saved_grade: int = theme.get_constant(&"fx_grade", &"ChestScreen")
		theme.set_constant(&"fx_grade", &"ChestScreen", 0)
		var played_before: int = screen.fx_played
		await _press(c.find_child("NextButton", true, false))
		theme.set_constant(&"fx_grade", &"ChestScreen", saved_grade)
		_check("宝箱：高い等級の品が出ると演出（演出中=%s・箱が光る=%s）" % [str(screen.get("_fx_busy")), str((box as ChestBox).is_playing_fx())],
			bool(screen.get("_fx_busy")) and (box as ChestBox).is_playing_fx() and screen.fx_played == played_before + 1)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		(c.find_child("Stage", true, false) as Control).gui_input.emit(click)
		await _wait()
		_check("宝箱：演出中に台を押すと飛ばして札が出る（%d 枚）" % c.find_children("Card_*", "", true, false).size(),
			not bool(screen.get("_fx_busy")) and c.find_children("Card_*", "", true, false).size() > 0 and (box as ChestBox).opened)

		# まとめて開ける：⚠ 高い等級の品が出た箱**ぜんぶ**に演出（⚠ 人間「⚠ まとめて開けるときは全部演出を」）。
		#   ⚠ 待つ時間を縮めるため、⚠ 演出の時間だけメモリの中で短くする（⚠ テーマの `.tres` は書かない）。
		var saved_fx: Dictionary = {}
		for fx_name: StringName in [&"fx_ms", &"fx_strong_ms", &"fx_fade_ms"]:
			saved_fx[fx_name] = theme.get_constant(fx_name, &"ChestScreen")
			theme.set_constant(fx_name, &"ChestScreen", 20)
		# ⚠ 開ける前にまだの箱を控える（⚠ 中身は開けたときに振られる＝数えるのは開けたあと）。
		var unopened: Array[String] = []
		for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
			if chest is Dictionary and not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)):
				unopened.append(str((chest as Dictionary).get(GameStateKeys.CHEST_INSTANCE_ID, "")))
		played_before = screen.fx_played
		# ⚠ 開ける前の図鑑を控える（⚠ 画面と同じ判定＝前に無く、いま載っている品にしおり紐）。
		var known: Dictionary = {}
		for item_id: Variant in GameManager.get_state().get(GameStateKeys.CODEX, {}):
			known[str(item_id)] = true
		await _press(c.find_child("OpenAllButton", true, false))
		for _i: int in range(600):
			if not bool(screen.get("_fx_busy")):
				break
			await get_tree().process_frame
		for fx_name: StringName in saved_fx:
			theme.set_constant(fx_name, &"ChestScreen", int(saved_fx[fx_name]))
		var expected_fx: int = 0
		var grades: Array[int] = []
		for instance_id: String in unopened:
			var top: int = screen.top_grade_of(screen.call("_read_chest_rewards", instance_id))
			grades.append(top)
			if screen.is_fx_grade(top):
				expected_fx += 1
		_check("宝箱：まとめて開けると高い等級の品が出た箱ぜんぶに演出（%d ＝ %d 箱・中身のいちばん高い等級 %s）" % [screen.fx_played - played_before, expected_fx, str(grades)],
			screen.fx_played - played_before == expected_fx and not unopened.is_empty())
		_check("宝箱：「まとめて開ける」で 0（%d）" % GameManager.get_pending_chest_count(), GameManager.get_pending_chest_count() == 0)
		var banded: int = 0
		var ribbons: int = 0
		var expected: int = 0
		var all_cards: Array = c.find_children("Card_*", "", true, false)
		for card: Node in all_cards:
			if str(card.get_meta(ChestScreen.META_KIND, "")) != "":
				banded += 1
			if bool(card.get_meta(ChestScreen.META_NEW, false)):
				ribbons += 1
			var item_id: String = str(card.get_meta(ChestScreen.META_ITEM_ID, ""))
			if item_id != "" and not known.has(item_id) and not GameManager.get_codex_entry(item_id).is_empty():
				expected += 1
		_check("宝箱：札ぜんぶに種類の帯（%d / %d）" % [banded, all_cards.size()], banded == all_cards.size() and banded > 0)
		_check("宝箱：しおり紐は初めて手に入れた品だけ（紐 %d ＝ 初めて %d）" % [ribbons, expected], ribbons == expected and ribbons > 0)
		var list: Node = c.find_child("ChestList", true, false)
		_check("宝箱：空になると空の表示", list != null and list.get_child_count() == 1 and list.get_child(0) is EmptyState)
		var next: Node = c.find_child("NextButton", true, false)
		var all: Node = c.find_child("OpenAllButton", true, false)
		_check("宝箱：空なら「次を開ける」「まとめて開ける」は押せない", next is Button and (next as Button).disabled and all is Button and (all as Button).disabled)
		var header: Node = c.find_child("Header", true, false)
		await _press(null if header == null else header.find_child("BackButton", true, false), OPEN_FRAMES)
		_check("宝箱：「戻る」で拠点", _path_of(get_tree().current_scene) == BASE)

	# --- デバッグの窓の2つのボタン（2026-09-28・人間「⚠ デバッグ用で、たからばこや、鍛冶用にアイテムをゲットしたい」）---
	#   ⚠ 窓（`tests/debug_overlay.gd`）は root に常駐している。⚠ ボタンの先の関数を呼ぶ（⚠ ボタンは文字で作っていて名前が無い）。

	func _flow_debug_tools() -> void:
		var overlay: Node = null
		for node: Node in get_tree().root.get_children():
			if node.has_method("_grant_rare_chests"):
				overlay = node
		if overlay == null:
			_check("デバッグの窓が無い", false)
			return
		var rare: Array[String] = [GameManager.CHEST_RARITY_EPIC, GameManager.CHEST_RARITY_LEGENDARY]
		var rare_before: int = 0
		for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
			if chest is Dictionary and not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)) \
					and GameManager.get_chest_rarity(str((chest as Dictionary).get(GameStateKeys.CHEST_ID, ""))) in rare:
				rare_before += 1
		overlay.call("_grant_rare_chests")
		var rare_after: int = 0
		for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
			if chest is Dictionary and not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)) \
					and GameManager.get_chest_rarity(str((chest as Dictionary).get(GameStateKeys.CHEST_ID, ""))) in rare:
				rare_after += 1
		_check("デバッグ：「宝箱：高レア」で epic・legendary が積まれる（%d → %d）" % [rare_before, rare_after], rare_after > rare_before)
		var tokens: int = GameManager.get_forge_token_count()
		overlay.call("_grant_forge_set")
		var grade5: bool = false
		for view: Variant in GameManager.get_owned_instances():
			if int((view as Dictionary).get(GameStateKeys.INSTANCE_GRADE, 1)) >= 5:
				grade5 = true
		_check("デバッグ：「鍛冶の一式」で等級5の装備と確定成功の札（札 %d → %d）" % [tokens, GameManager.get_forge_token_count()],
			grade5 and GameManager.get_forge_token_count() == tokens + 3)
		# ⚠ 好きな装備をもらう（⚠ 10-02 人間「⚠ すきなそうびをげっとできるようにしたい」）：⚠ 竜殺しの大剣を等級7で。
		var picker: Node = overlay.find_child("EquipmentPicker", true, false)
		var made: String = str(overlay.call("grant_equipment", "weapon_dragon_greatsword", 7))
		var made_view: Dictionary = GameManager.get_equipment_instance(made)
		_check("デバッグ：「装備をもらう」で選んだ装備を選んだ等級で（%s 等級 %s・一覧 %d 品）" % [
			str(made_view.get(GameStateKeys.INSTANCE_ITEM_ID, "")), str(made_view.get(GameStateKeys.INSTANCE_GRADE, 0)),
			0 if picker == null else (picker.find_child("EquipmentPick", true, false) as OptionButton).item_count],
			picker != null and str(made_view.get(GameStateKeys.INSTANCE_ITEM_ID, "")) == "weapon_dragon_greatsword"
			and int(made_view.get(GameStateKeys.INSTANCE_GRADE, 0)) == 7
			and (picker.find_child("EquipmentPick", true, false) as OptionButton).item_count == GameManager.get_codex_ids(GameManager.CODEX_KIND_EQUIPMENT).size())

	# --- タスクのメモ（2026-10-04・DECISIONS.md `TK-1`〜`TK-14`・PLAN_TASK_MEMO.md §5） ---
	#   ⚠ 拠点の紙 → タスクの画面 → 足す・チェック・並べ替え・名前・色・期限・タグ → 拠点の紙 → ポモドーロで選ぶ・足す → 🍅 → 朝4:00 → 記録。
	#   ⚠ 朝4:00 は画面から起こせない＝⚠ 移す口に「今」を渡して日付を差し替える（⚠ 本物のセーブ・設定は書かない）。

	func _flow_tasks() -> void:
		var before: int = GameManager.get_tasks().size()
		# ⚠ やることが1件も無いポモドーロ（10-06・人間「⚠ 追加するよう促す」）：⚠ 真ん中に促し・選んでいない。
		if GameManager.get_open_tasks().is_empty():
			var p0: Node = await _open(POMODORO, {})
			if p0 != null:
				var select0: Node = p0.find_child("ProtectionSelectView", true, false)
				if select0 != null:
					await _press(select0.find_child("StartButton", true, false), OPEN_FRAMES)
				var prompt: Label = p0.find_child("EmptyPrompt", true, false) as Label
				var view0: Node = p0.find_child("FocusView", true, false)
				_check("ポモドーロ：やることが無いと真ん中に「%s」・選んでいない" % ("" if prompt == null else prompt.text),
					prompt != null and prompt.visible and view0 != null and str(view0.call("get_task_id")) == "")
		else:
			_check("ポモドーロ：やることが無い姿を見られない（まだ %d 件）" % GameManager.get_open_tasks().size(), false)
		var b: Node = await _open(BASE, {})
		if b == null:
			return
		var note: Node = b.find_child("TaskWallNote", true, false)
		_check("タスク：拠点に壁の紙（%d 件のとき空の案内あり）" % before,
			note != null and (before > 0 or note.find_child("EmptyState", true, false) != null))
		await _press(null if note == null else note.find_child("OpenTasksButton", true, false), OPEN_FRAMES)
		var t: Node = get_tree().current_scene
		_check("タスク：紙の「ひらく」でタスクの画面", _path_of(t) == TASK_SCREEN)
		if _path_of(t) != TASK_SCREEN:
			return
		# 足す（`TK-2`）：⚠ 3件。⚠ 空の題は足さない。
		for title: String in ["TK検査A", "TK検査B", "TK検査C", "  "]:
			(t.find_child("NewTaskEdit", true, false) as LineEdit).text = title
			await _press(t.find_child("AddTaskButton", true, false))
		var ids: Array[String] = _task_order()
		_check("タスク：足すで TASKS が %d → %d（空の題は足さない）" % [before, ids.size()], ids.size() == before + 3)
		if ids.size() < before + 3:
			return
		var a_id: String = ids[before]
		var b_id: String = ids[before + 1]
		var c_id: String = ids[before + 2]
		_check("タスク：足した3件が一覧の行に出る", t.find_child("Task_" + a_id, true, false) != null and t.find_child("Task_" + c_id, true, false) != null)
		var a_task: Dictionary = GameManager.get_task(a_id)
		_check("タスク：足した行の数の欄が int（色 %s・集中した秒 %s・作った時刻 %s）" % [type_string(typeof(a_task.get(GameStateKeys.TASK_COLOR))), type_string(typeof(a_task.get(GameStateKeys.TASK_FOCUS_SEC))), type_string(typeof(a_task.get(GameStateKeys.TASK_CREATED_AT)))],
			a_task.get(GameStateKeys.TASK_COLOR) is int and a_task.get(GameStateKeys.TASK_FOCUS_SEC) is int and a_task.get(GameStateKeys.TASK_CREATED_AT) is int)
		# チェック（`TK-4`・`TK-6`）：⚠ 終えても一覧に残り、薄墨＋線。
		var a_row: Node = t.find_child("Task_" + a_id, true, false)
		var check: Node = null if a_row == null else a_row.find_child("DoneCheck", true, false)
		if check is TaskCheck:
			(check as TaskCheck).button_pressed = true
		await _wait()
		a_row = t.find_child("Task_" + a_id, true, false)
		var a_title: Node = null if a_row == null else a_row.find_child("TitleLabel", true, false)
		_check("タスク：チェックで終えたことになり、一覧に線を引いて残る",
			int(GameManager.get_task(a_id).get(GameStateKeys.TASK_DONE_AT, 0)) != 0 and a_title is Label and (a_title as Label).theme_type_variation == &"TaskDoneLabel")
		# 並べ替え（`TK-7`）：⚠ A を押して選ぶ（⚠ ▲▼ は選んだ行にだけ出る・モック2）→ 1つ下へ。
		_check("タスク：選んでいない行に ▲▼ は出ない", a_row != null and a_row.find_child("DownButton", true, false) == null)
		await _press(a_row)
		a_row = t.find_child("Task_" + a_id, true, false)
		await _press(null if a_row == null else a_row.find_child("DownButton", true, false))
		_check("タスク：▼で A が1つ下へ（%s）" % str(_task_order()), _task_order().find(a_id) == before + 1 and _task_order().find(b_id) == before)
		# 詳しく：⚠ B を押す → 名前 ／ メモ ／ 色 ／ 期限 ／ タグ。
		await _press(t.find_child("Task_" + b_id, true, false))
		var title_edit: LineEdit = t.find_child("TitleEdit", true, false) as LineEdit
		if title_edit != null:
			title_edit.text = "TK検査B2"
			title_edit.text_changed.emit(title_edit.text)
		await _wait()
		_check("タスク：詳しくの名前を書き換えると名前が変わる（%s）" % str(GameManager.get_task(b_id).get(GameStateKeys.TASK_TITLE, "")),
			str(GameManager.get_task(b_id).get(GameStateKeys.TASK_TITLE, "")) == "TK検査B2")
		var memo: TextEdit = t.find_child("MemoEdit", true, false) as TextEdit
		if memo != null:
			memo.text = "メモの検査"
			memo.text_changed.emit()
		await _press(t.find_child("Color_3", true, false))
		await _press(t.find_child("DueToday", true, false))
		var tag_edit: LineEdit = t.find_child("TagEdit", true, false) as LineEdit
		if tag_edit != null:
			tag_edit.text = "検査"
		await _press(t.find_child("AddTagButton", true, false))
		var bt: Dictionary = GameManager.get_task(b_id)
		_check("タスク：メモ・色・期限・タグが入る（%s / %d / %s / %s）" % [str(bt.get(GameStateKeys.TASK_MEMO, "")), int(bt.get(GameStateKeys.TASK_COLOR, -1)), str(bt.get(GameStateKeys.TASK_DUE, "")), str(bt.get(GameStateKeys.TASK_TAGS, []))],
			str(bt.get(GameStateKeys.TASK_MEMO, "")) == "メモの検査" and int(bt.get(GameStateKeys.TASK_COLOR, -1)) == 3
			and str(bt.get(GameStateKeys.TASK_DUE, "")) == GameDate.get_game_date_string() and "検査" in (bt.get(GameStateKeys.TASK_TAGS, []) as Array))
		var b_row: Node = t.find_child("Task_" + b_id, true, false)
		var b_stamp: Node = null if b_row == null else b_row.find_child("DueStamp", true, false)
		_check("タスク：今日が期限なら一覧の行に「今日まで」の判（`TK-13`）", b_stamp is Stamp and (b_stamp as Stamp).label_key == "ui_task_due_today")
		# 期限の札（モック3）：⚠ 明日＝「あと1日」／ ⚠ 今週中＝設定の週の終わりの日（`TK-17`）／ ⚠ カレンダーで昨日＝「期限切れ」。
		var today: String = GameDate.get_game_date_string()
		await _press(t.find_child("DueTomorrow", true, false))
		_check("期限：「明日」で %s・「%s」" % [str(GameManager.get_task(b_id).get(GameStateKeys.TASK_DUE, "")), _label_text(t, "DueRow", "DaysLeftLabel")],
			str(GameManager.get_task(b_id).get(GameStateKeys.TASK_DUE, "")) == TaskParts.shift_date(today, 1) and _label_text(t, "DueRow", "DaysLeftLabel") == tr("ui_task_days_left") % 1)
		var s_screen: Node = await _open(SETTINGS, {TransferKeys.SETTINGS_TAB: SettingsScreen.TAB_POMODORO})
		await _press(null if s_screen == null else s_screen.find_child("WeekEnd_0", true, false))
		_check("設定：「週の終わりの日」を日曜に（%d）" % GameSettings.week_end_weekday(), GameSettings.week_end_weekday() == 0)
		t = await _open(TASK_SCREEN, {})
		if t == null:
			return
		await _press(t.find_child("Task_" + b_id, true, false))
		await _press(t.find_child("DueWeek", true, false))
		var week_due: String = str(GameManager.get_task(b_id).get(GameStateKeys.TASK_DUE, ""))
		_check("期限：「今週中」は次の日曜（%s・曜日 %d・あと %d日）" % [week_due, TaskParts.weekday(week_due), TaskParts.days_from_today(week_due)],
			TaskParts.weekday(week_due) == 0 and TaskParts.days_from_today(week_due) >= 0 and TaskParts.days_from_today(week_due) <= 6)
		GameSettings.set_value(GameSettings.SECTION_TASK, GameSettings.KEY_WEEK_END, 6)
		await _press(t.find_child("DuePick", true, false))
		var calendar: Node = t.find_child("TaskCalendar", true, false)
		# 年を送る（10-05・人間「⚠ 日付の選択は年も選べるように」）：» で次の年 → « で戻す。
		var month_label: Label = null if calendar == null else calendar.find_child("MonthLabel", true, false) as Label
		var cal_year: int = int(today.split("-")[0])
		var cal_month: int = int(today.split("-")[1])
		await _press(null if calendar == null else calendar.find_child("CalNextYear", true, false))
		var next_year_text: String = "" if month_label == null else month_label.text
		await _press(null if calendar == null else calendar.find_child("CalPrevYear", true, false))
		_check("期限：カレンダーの » で次の年（%s）・« で戻る（%s）" % [next_year_text, "" if month_label == null else month_label.text],
			next_year_text == tr("ui_task_cal_month") % [cal_year + 1, cal_month] and month_label != null and month_label.text == tr("ui_task_cal_month") % [cal_year, cal_month])
		var yesterday: String = TaskParts.shift_date(today, -1)
		if calendar != null and calendar.find_child("Day_" + yesterday, true, false) == null:
			# ⚠ 昨日が先月なら ◀ で1か月戻す。
			await _press(calendar.find_child("CalPrev", true, false))
		var today_cell: Node = null if calendar == null else calendar.find_child("Day_" + today, true, false)
		_check("期限：「日付を選ぶ」でカレンダー（今日＝真鍮の輪）", calendar is TaskCalendar and (calendar as TaskCalendar).visible
			and (today_cell == null or (today_cell as Button).theme_type_variation == &"TaskCalToday"))
		await _press(null if calendar == null else calendar.find_child("Day_" + yesterday, true, false))
		b_row = t.find_child("Task_" + b_id, true, false)
		b_stamp = null if b_row == null else b_row.find_child("DueStamp", true, false)
		_check("期限：カレンダーで昨日を押すと閉じて「期限切れ」の小さい判（%s）" % str(GameManager.get_task(b_id).get(GameStateKeys.TASK_DUE, "")),
			calendar is TaskCalendar and not (calendar as TaskCalendar).visible and str(GameManager.get_task(b_id).get(GameStateKeys.TASK_DUE, "")) == yesterday
			and b_stamp is Stamp and (b_stamp as Stamp).label_key == "ui_task_due_overdue" and (b_stamp as Stamp).small)
		# タグで絞る（`TK-12`）。
		await _press(t.find_child("Filter_検査", true, false))
		_check("タスク：タグで絞ると B だけ・「%s」「%s」" % [_label_text(t, "ListSheet", "FilterNote"), _label_text(t, "ListSheet", "HiddenNote")],
			t.find_child("Task_" + b_id, true, false) != null and t.find_child("Task_" + a_id, true, false) == null and t.find_child("Task_" + c_id, true, false) == null
			and _label_text(t, "ListSheet", "FilterNote") == tr("ui_task_filter_note") % ["検査", 1] and _label_text(t, "ListSheet", "HiddenNote") == tr("ui_task_hidden_note") % 2)
		await _press(t.find_child("Filter_all", true, false))
		_check("タスク：「すべて」で戻る", t.find_child("Task_" + a_id, true, false) != null)
		# 拠点の紙（`TK-3`）：⚠ まだのものだけ全部・⚠ 期限切れの判。
		var header: Node = t.find_child("Header", true, false)
		await _press(null if header == null else header.find_child("BackButton", true, false), OPEN_FRAMES)
		b = get_tree().current_scene
		var open_count: int = GameManager.get_open_tasks().size()
		var note_rows: int = 0 if b == null else b.find_children("Note_*", "", true, false).size()
		_check("タスク：「戻る」で拠点・紙にまだのタスクが全部（%d 行 ／ まだ %d）・終えた A は出ない" % [note_rows, open_count],
			_path_of(b) == BASE and note_rows == open_count and b.find_child("Note_" + a_id, true, false) == null)
		var b_note: Node = null if b == null else b.find_child("Note_" + b_id, true, false)
		_check("タスク：紙の B に「期限切れ」の判", b_note != null and b_note.find_child("DueStamp", true, false) is Stamp)
		# ポモドーロ（`TK-10`・10-05 サイドバー）：⚠ 右のサイドバーの行を押す → 題がタスクの名前 → 書き換えると名前が変わる。
		var p: Node = await _open(POMODORO, {})
		if p == null:
			return
		var select_view: Node = p.find_child("ProtectionSelectView", true, false)
		if select_view != null:
			await _press(select_view.find_child("StartButton", true, false), OPEN_FRAMES)
		var view: Node = p.find_child("FocusView", true, false)
		var side: Node = p.find_child("TaskSidebar", true, false)
		if view == null or side == null:
			_check("ポモドーロ：集中のビューかサイドバーが無い", false)
			return
		var first_open: String = str((GameManager.get_open_tasks()[0] as Dictionary).get(GameStateKeys.TASK_ID, "")) if not GameManager.get_open_tasks().is_empty() else ""
		_check("ポモドーロ：何も選んでいなければリストのいちばん上（%s）を自動で選ぶ・促しは出ない" % str(GameManager.get_task(first_open).get(GameStateKeys.TASK_TITLE, "")),
			first_open != "" and str(view.call("get_task_id")) == first_open and not (view.find_child("EmptyPrompt", true, false) as Label).visible)
		var side_rows: int = side.find_children("Side_*", "", true, false).size()
		var margin_right: float = (p.get_node("Margin/Layout") as Control).get_global_rect().end.x
		_check("ポモドーロ：右にサイドバー（%d 行 ／ 一覧 %d）・中身の柱はサイドバーの手前まで（%.0f ≦ %.0f）" % [side_rows, GameManager.get_tasks().size(), margin_right, (side as Control).get_global_rect().position.x],
			side_rows == GameManager.get_tasks().size() and margin_right <= (side as Control).get_global_rect().position.x
			and view.find_child("PickTaskButton", true, false) == null)
		await _press(side.find_child("Side_" + b_id, true, false))
		var focus_title: LineEdit = view.find_child("TitleEdit", true, false) as LineEdit
		var b_side: Node = side.find_child("Side_" + b_id, true, false)
		_check("ポモドーロ：サイドバーで B を押すと選ばれ、題が「%s」・B が明るい行" % ("" if focus_title == null else focus_title.text),
			str(view.call("get_task_id")) == b_id and focus_title != null and focus_title.text == "TK検査B2" and b_side is LedgerRow and (b_side as LedgerRow).selected)
		if focus_title == null:
			return
		focus_title.text = "TK検査B3"
		focus_title.text_changed.emit(focus_title.text)
		_check("ポモドーロ：選んだあとに題を書き換えるとタスクの名前が変わる（%s）" % str(GameManager.get_task(b_id).get(GameStateKeys.TASK_TITLE, "")),
			str(GameManager.get_task(b_id).get(GameStateKeys.TASK_TITLE, "")) == "TK検査B3")
		var band: Node = view.find_child("LinkedBand", true, false)
		_check("ポモドーロ：選ぶと紙の帯（題・期限切れの判・外す）・題の欄の左に色の印",
			band is Control and (band as Control).visible and band.find_child("LinkedTitle", true, false) is Label and band.find_child("LinkedStamp", true, false) is Stamp
				and (band.find_child("LinkedStamp", true, false) as Stamp).label_key == "ui_pomodoro_task_selected_stamp" and (band.find_child("LinkedTitle", true, false) as Label).text == "TK検査B3" and band.find_child("DueStamp", true, false) is Stamp
			and band.find_child("UnlinkButton", true, false) != null and (view.find_child("TitleMark", true, false) as Control).visible)
		# 「外す」→ 選んでいない（⚠ 題が残っているので「書いた題をリストに足す」が出る）。
		await _press(null if band == null else band.find_child("UnlinkButton", true, false))
		var add_to_list: Node = view.find_child("AddToListButton", true, false)
		_check("ポモドーロ：「外す」で選んでいない・サイドバーの明るい行が消える・題があるので「書いた題をリストに足す」",
			str(view.call("get_task_id")) == "" and not ((side.find_child("Side_" + b_id, true, false) as LedgerRow).selected)
			and add_to_list is Button and (add_to_list as Button).visible and str(GameManager.get_task(b_id).get(GameStateKeys.TASK_TITLE, "")) == "TK検査B3")
		focus_title.text = ""
		focus_title.text_changed.emit("")
		_check("ポモドーロ：題が空なら「書いた題をリストに足す」は出ない（コンパクト）", not (add_to_list as Button).visible)
		# サイドバーで足す（⚠ ポモドーロ中も足せる＝人間の指示）：⚠ 足すだけ（⚠ 選ばない）。
		var count_before_side: int = GameManager.get_tasks().size()
		(side.find_child("SideNewEdit", true, false) as LineEdit).text = "TK検査E"
		await _press(side.find_child("SideAddButton", true, false))
		var e_id: String = _task_order().back() if GameManager.get_tasks().size() > count_before_side else ""
		_check("サイドバー：下の欄で足すと一覧に1件・行が出る・選びはしない（%s）" % str(GameManager.get_task(e_id).get(GameStateKeys.TASK_TITLE, "")),
			str(GameManager.get_task(e_id).get(GameStateKeys.TASK_TITLE, "")) == "TK検査E" and side.find_child("Side_" + e_id, true, false) != null
			and str(view.call("get_task_id")) == "" and (side.find_child("SideNewEdit", true, false) as LineEdit).text == "")
		# 題を打って「リストに足す」。
		focus_title.text = "TK検査D"
		focus_title.text_changed.emit(focus_title.text)
		var count_before_add: int = GameManager.get_tasks().size()
		await _press(view.find_child("AddToListButton", true, false))
		var d_id: String = str(view.call("get_task_id"))
		_check("ポモドーロ：「書いた題をリストに足す」で1件増えて選ばれる（%s）" % str(GameManager.get_task(d_id).get(GameStateKeys.TASK_TITLE, "")),
			GameManager.get_tasks().size() == count_before_add + 1 and str(GameManager.get_task(d_id).get(GameStateKeys.TASK_TITLE, "")) == "TK検査D")
		# 集中した時間（`TK-5`）：⚠ サイドバーで B を選び直して集中 → 5分で C に替える → さらに3分20秒で C を終える → 残りは選んでいない＝記録しない。
		await _press(side.find_child("Side_" + b_id, true, false))
		var counts_before: Dictionary = _task_counts()
		await _press(view.find_child("StartButton", true, false))
		var total_sec: float = float(p.get("phase_total_sec"))
		b_side = side.find_child("Side_" + b_id, true, false)
		_check("集中中：サイドバーはそのまま・いまの B が明るい行", bool(p.get("is_timer_active")) and b_side is LedgerRow and (b_side as LedgerRow).selected)
		# ⚠ 集中中に足しても時間の区切りにならない（⚠ いまのタスクは変わらない）。
		(side.find_child("SideNewEdit", true, false) as LineEdit).text = "TK検査F"
		await _press(side.find_child("SideAddButton", true, false))
		_check("集中中：サイドバーで足せる（いまは B のまま）", str(GameManager.get_tasks().back().get(GameStateKeys.TASK_TITLE, "")) == "TK検査F" and str(p.call("_current_task_id")) == b_id)
		# 詳しく（10-05・人間「⚠ 詳しいこともポモドーロ中に決められるように」）：⚠ サイドバーの B の「詳しく」→ 紙の窓 → 色・メモ・期限 → 閉じる。⚠ タイマーは止めない。
		var b_detail_row: Node = side.find_child("Side_" + b_id, true, false)
		var memo_button: Button = null if b_detail_row == null else b_detail_row.find_child("DetailButton", true, false) as Button
		_check("サイドバー：行の右はメモのアイコン（字は無い・絵 %s）" % str(memo_button != null and memo_button.icon != null),
			memo_button != null and memo_button.icon != null and memo_button.text == "" and memo_button.theme_type_variation == &"TaskMemoButton")
		await _press(memo_button)
		var detail_modal: ModalDialog = _modal_of(p)
		var detail_panel: Node = null if detail_modal == null else detail_modal.find_child("TaskDetailPanel", true, false)
		_check("集中中：「詳しく」で紙の窓（名前 %s・消すは無い）" % ("" if detail_panel == null else (detail_panel.find_child("TitleEdit", true, false) as LineEdit).text),
			detail_panel is TaskDetailPanel and (detail_panel.find_child("TitleEdit", true, false) as LineEdit).text == "TK検査B3"
			and detail_panel.find_child("DeleteButton", true, false) == null)
		if detail_panel != null:
			await _press(detail_panel.find_child("Color_4", true, false))
			var detail_memo: TextEdit = detail_panel.find_child("MemoEdit", true, false) as TextEdit
			if detail_memo != null:
				detail_memo.text = "集中中のメモ"
				detail_memo.text_changed.emit()
			await _press(detail_panel.find_child("DueTomorrow", true, false))
		var bd: Dictionary = GameManager.get_task(b_id)
		_check("集中中：窓で色・メモ・期限が入る（%d / %s / %s）・タイマーは動いたまま" % [int(bd.get(GameStateKeys.TASK_COLOR, -1)), str(bd.get(GameStateKeys.TASK_MEMO, "")), str(bd.get(GameStateKeys.TASK_DUE, ""))],
			int(bd.get(GameStateKeys.TASK_COLOR, -1)) == 4 and str(bd.get(GameStateKeys.TASK_MEMO, "")) == "集中中のメモ"
			and str(bd.get(GameStateKeys.TASK_DUE, "")) == TaskParts.shift_date(GameDate.get_game_date_string(), 1) and bool(p.get("is_timer_active")))
		# ⚠ 窓の外（暗幕の左上）を押して閉じる（10-06・人間「⚠ 窓が出たとき画面外をクリックしても閉じるように」）。⚠ 窓の中を押しても閉じない。
		var outside_modal: ModalDialog = _modal_of(p)
		if outside_modal != null:
			var inside_click: InputEventMouseButton = InputEventMouseButton.new()
			inside_click.button_index = MOUSE_BUTTON_LEFT
			inside_click.pressed = true
			inside_click.global_position = outside_modal.panel.get_global_rect().get_center()
			outside_modal.blocker.gui_input.emit(inside_click)
			await _wait()
			var stayed: bool = _modal_of(p) != null
			var outside_click: InputEventMouseButton = inside_click.duplicate() as InputEventMouseButton
			outside_click.global_position = Vector2(2.0, 2.0)
			outside_modal.blocker.gui_input.emit(outside_click)
			await _wait(WAIT_FRAMES * 3)
			_check("集中中：窓の中を押しても閉じない（%s）・外を押すと閉じる" % str(stayed), stayed and _modal_of(p) == null)
		else:
			_check("集中中：窓が無い", false)
		_check("集中中：窓を閉じても B のまま・サイドバーの B の色の印が藍→紫", _modal_of(p) == null and str(p.call("_current_task_id")) == b_id
			and ((side.find_child("Side_" + b_id, true, false) as Node).find_child("ColorMark", true, false) as TaskColorMark).color_index == 4)
		# 選んでいる行のメモ（10-05・人間「⚠ 選択中のタスクは、メモを見れるように」）：⚠ 集中中もサイドバーの B の下に出る。
		var b_memo: Label = (side.find_child("Side_" + b_id, true, false) as Node).find_child("MemoLabel", true, false) as Label
		var other_memos: int = side.find_children("MemoLabel", "", true, false).size()
		_check("集中中：選んでいる B の行の下にメモ（%s）・ほかの行には出ない（メモの数 %d）" % ["" if b_memo == null else b_memo.text, other_memos],
			b_memo != null and b_memo.text == "集中中のメモ" and other_memos == 1)
		p.set("time_left_sec", total_sec - 300.0)
		await _press(side.find_child("Side_" + c_id, true, false))
		var after_switch: Dictionary = _task_counts()
		var work_title: Label = view.find_child("WorkTitle", true, false) as Label
		_check("集中中：行を押して C に替えると、B に 5分（%d 秒）・大きい題が C（%s）" % [int(after_switch.get(b_id, 0)) - int(counts_before.get(b_id, 0)), "" if work_title == null else work_title.text],
			absi(int(after_switch.get(b_id, 0)) - int(counts_before.get(b_id, 0)) - 300) <= 1 and str(p.call("_current_task_id")) == c_id
			and work_title != null and work_title.text == "TK検査C")
		p.set("time_left_sec", total_sec - 500.0)
		var c_row: Node = side.find_child("Side_" + c_id, true, false)
		var c_check: Node = null if c_row == null else c_row.find_child("DoneCheck", true, false)
		if c_check is TaskCheck:
			(c_check as TaskCheck).button_pressed = true
		await _wait()
		var after_finish: Dictionary = _task_counts()
		_check("集中中：C の四角で終えると、C に 3分20秒（%d 秒）・C は終えた・いまは選んでいない" % (int(after_finish.get(c_id, 0)) - int(counts_before.get(c_id, 0))),
			absi(int(after_finish.get(c_id, 0)) - int(counts_before.get(c_id, 0)) - 200) <= 1
			and int(GameManager.get_task(c_id).get(GameStateKeys.TASK_DONE_AT, 0)) != 0 and str(p.call("_current_task_id")) == "")
		p.set("time_left_sec", 0.01)
		await _wait()
		var counts_after: Dictionary = _task_counts()
		_check("集中中：選んでいない残りはどれにも記録しない（%s → %s）" % [str(after_finish), str(counts_after)],
			_counts_same_except(after_finish, counts_after, ""))
		# 選ばずに集中（`TK-11`）：⚠ どれも増えない。⚠ 10-06 から開くといちばん上を自動で選ぶ＝⚠ 「外す」を押してから始める。
		p = await _open(POMODORO, {})
		if p != null:
			var select_unlink: Node = p.find_child("ProtectionSelectView", true, false)
			if select_unlink != null:
				await _press(select_unlink.find_child("StartButton", true, false), OPEN_FRAMES)
			var unlink_band: Node = p.find_child("LinkedBand", true, false)
			if unlink_band != null and (unlink_band as Control).visible:
				await _press(unlink_band.find_child("UnlinkButton", true, false))
		await _pomodoro_start_focus(p)
		counts_before = _task_counts()
		if p != null:
			p.set("time_left_sec", 0.01)
		await _wait()
		_check("集中した時間：選ばずに集中が0になってもどれも増えない（%s）" % str(_task_counts()),
			p != null and str(p.get("current_state")) != "1" and _counts_same_except(counts_before, _task_counts(), ""))
		# 朝4:00（`TK-6`）：⚠ 明日の「今」を渡す → 終えた A が記録へ。
		# ⚠ 終えたのは A（一覧のチェック）と C（集中中の四角）＝2件が移るはず。
		var tasks_before: int = GameManager.get_tasks().size()
		var log_before: int = GameManager.get_task_log().size()
		var done_before: int = tasks_before - GameManager.get_open_tasks().size()
		var moved: int = GameManager.roll_over_done_tasks(Time.get_unix_time_from_system() + 86400.0)
		var log_ids: Array[String] = []
		for entry: Variant in GameManager.get_task_log():
			log_ids.append(str((entry as Dictionary).get(GameStateKeys.TASK_ID, "")))
		_check("朝4:00：またぐと終えた %d 件が移る（TASKS %d → %d・TASK_LOG %d → %d・C の時間 %s）" % [done_before, tasks_before, GameManager.get_tasks().size(), log_before, GameManager.get_task_log().size(), str(_log_focus(c_id))],
			done_before == 2 and moved == 2 and GameManager.get_tasks().size() == tasks_before - 2 and GameManager.get_task_log().size() == log_before + 2
			and a_id in log_ids and c_id in log_ids and absi(_log_focus(c_id) - 200) <= 1)
		_check("朝4:00：同じ日のうちは移さない", GameManager.roll_over_done_tasks() == 0)
		# 記録（`TK-8`）。
		var r: Node = await _open(RECORDS, {})
		if r == null:
			return
		await _press(_tab_button(r, RecordsScreen.TAB_TASKS))
		var year_key: String = GameDate.get_game_date_string().substr(0, 4)
		var month_key: String = GameDate.get_game_date_string().substr(0, 7)
		_check("記録：「終わったタスク」のタブ＝年・月の帯が開いて A（%s）" % _label_text(r, "DoneTask_" + a_id, "TitleLabel"),
			_label_text(r, "DoneTask_" + a_id, "TitleLabel") == "TK検査A" and r.find_child("Year_" + year_key, true, false) != null and r.find_child("Month_" + month_key, true, false) != null)
		var month_band: Node = r.find_child("Month_" + month_key, true, false)
		await _press(null if month_band == null else month_band.find_child("Hit", false, false))
		_check("記録：月の帯を押すと畳む（A が隠れる）", r.find_child("DoneTask_" + a_id, true, false) == null and r.find_child("Month_" + month_key, true, false) != null)
		# ⚠ セーブから戻したとき int に戻るか（CLAUDE.md 3番）：⚠ JSON を通した形に `load_state()` と同じ直しを当てる（⚠ ファイルは書かない）。
		var restored: Array = GameManager._normalize_task_list(JSON.parse_string(JSON.stringify(GameManager.get_tasks())))
		var first: Dictionary = {} if restored.is_empty() else restored[0] as Dictionary
		_check("セーブ：JSON から戻すと色・集中した秒・日付が int（%s）" % type_string(typeof(first.get(GameStateKeys.TASK_FOCUS_SEC))),
			first.get(GameStateKeys.TASK_FOCUS_SEC) is int and first.get(GameStateKeys.TASK_DONE_AT) is int and first.get(GameStateKeys.TASK_COLOR) is int)
		var legacy: Array = GameManager._normalize_task_list([{GameStateKeys.TASK_ID: "task_old", GameStateKeys.TASK_POMODORO_COUNT: 3.0}])
		_check("セーブ：10-04 の回数は捨て、集中した秒は 0 で生える", not (legacy[0] as Dictionary).has(GameStateKeys.TASK_POMODORO_COUNT) and (legacy[0] as Dictionary).get(GameStateKeys.TASK_FOCUS_SEC) == 0)
		# 消す（`TK-15`）：⚠ D を選ぶ →「消す」→ 確かめの窓の「いいえ」では消えない →「消す」→「はい」で一覧から消え、記録は増えない。
		var t2: Node = await _open(TASK_SCREEN, {})
		if t2 == null:
			return
		await _press(t2.find_child("Task_" + d_id, true, false))
		var tasks_before_delete: int = GameManager.get_tasks().size()
		var log_before_delete: int = GameManager.get_task_log().size()
		await _press(t2.find_child("DeleteButton", true, false))
		await _close_modal(t2)
		_check("消す：確かめの窓で「いいえ」なら消えない", not GameManager.get_task(d_id).is_empty())
		await _press(t2.find_child("DeleteButton", true, false))
		await _confirm_modal()
		_check("消す：「はい」で一覧から消える（TASKS %d → %d・TASK_LOG %d のまま）・行も消える" % [tasks_before_delete, GameManager.get_tasks().size(), GameManager.get_task_log().size()],
			GameManager.get_task(d_id).is_empty() and GameManager.get_tasks().size() == tasks_before_delete - 1
			and GameManager.get_task_log().size() == log_before_delete and t2.find_child("Task_" + d_id, true, false) == null
			and t2.find_child("DetailNone", true, false) != null)

	# --- 寄り道の「戻る」は来た画面へ（2026-10-06・拠点の遷移の見直し・`NAV-18`） ---

	func _back(scene: Node) -> void:
		var header: Node = scene.find_child("Header", true, false)
		await _press(header.find_child("BackButton", false, false) if header != null else null, OPEN_FRAMES)

	func _flow_return_paths() -> void:
		const ADVENTURE_SHOP: String = "res://scenes/guild/shop_screen.tscn"
		GameManager.add_to_inventory(WEAPON_ID, 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
		var instance_id: String = _instance_of(WEAPON_ID)
		# ① 育成（装備タブ）→ 鍛冶場 → 戻る → 同じキャラの装備タブ → 戻る → 一覧。
		var t: Node = await _open(TRAINING, {TransferKeys.CHARACTER_ID: OTHER, TransferKeys.TRAINING_TAB: TransferKeys.TRAINING_TAB_EQUIP})
		if t == null:
			return
		await _press(t.find_child("Slot_" + GameStateKeys.EQUIP_WEAPON, true, false))
		await _press(t.find_child("Candidate_" + instance_id, true, false))
		await _press(t.find_child("EquipButton", true, false))
		await _press(t.find_child("ForgeButton", true, false), OPEN_FRAMES)
		var f: Node = get_tree().current_scene
		_check("戻り先：育成の「鍛冶場で鍛える」で鍛冶場", _path_of(f) == FORGE)
		await _back(f)
		t = get_tree().current_scene
		_check("戻り先：鍛冶場の「戻る」で育成（%s・%s）に戻る（前は本部）" % [str(t.get("_selected_id")), str(t.get("_tab"))],
			_path_of(t) == TRAINING and str(t.get("_selected_id")) == OTHER and str(t.get("_tab")) == TransferKeys.TRAINING_TAB_EQUIP)
		await _back(t)
		_check("戻り先：もう一度「戻る」で育成の一覧（積んだものは尽きた）", _path_of(get_tree().current_scene) == TRAINING_LIST)
		GameManager.unequip_instance(OTHER, GameStateKeys.EQUIP_WEAPON)
		# ② 持ち物 → 鍛える → 戻る → その品を選んだ持ち物 → 戻る → 本部。
		var w: Node = await _open(BELONGINGS, {TransferKeys.WAREHOUSE_INSTANCE_ID: instance_id})
		if w == null:
			return
		await _press(w.find_child("ForgeButton", true, false), OPEN_FRAMES)
		await _back(get_tree().current_scene)
		w = get_tree().current_scene
		_check("戻り先：持ち物 → 鍛冶場 →「戻る」で持ち物（その品を選んだまま）",
			_path_of(w) == BELONGINGS and str(w.get("_selected_key")) == instance_id)
		await _back(w)
		_check("戻り先：持ち物の「戻る」は本部", _path_of(get_tree().current_scene) == BASE)
		# ③ 鍛冶場（帯から）→ 持ち物で見る → 戻る → その品を選んだ鍛冶場。
		f = await _open(FORGE, {TransferKeys.FORGE_INSTANCE_ID: instance_id})
		if f == null:
			return
		await _press(f.find_child("BelongingsButton", true, false), OPEN_FRAMES)
		await _back(get_tree().current_scene)
		f = get_tree().current_scene
		_check("戻り先：鍛冶場 → 持ち物で見る →「戻る」で鍛冶場（その品のまま）", _path_of(f) == FORGE and str(f.get("_selected")) == instance_id)
		# ⚠ 施設の帯で移ると積んだものは捨てる（⚠ 古い戻り先が残らない）。
		await _press(f.find_child("Facility_" + BaseFacilityBar.RECORDS, true, false), OPEN_FRAMES)
		_check("戻り先：施設の帯で移ると積んだ戻り先は消える", _path_of(get_tree().current_scene) == RECORDS and not SceneManager.has_return())
		# ④ 記録（キャラ）→ 育成 → 昇級 → 戻る → 育成 → 戻る → 記録のキャラのタブ。
		var r: Node = await _open(RECORDS, {TransferKeys.RECORDS_TAB: RecordsScreen.TAB_CHARACTERS})
		if r == null:
			return
		await _press(r.find_child("Character_" + HERO, true, false), OPEN_FRAMES)
		t = get_tree().current_scene
		_check("戻り先：記録のキャラを押すと育成", _path_of(t) == TRAINING)
		await _press(t.find_child("LevelUpButton", true, false), OPEN_FRAMES)
		await _back(get_tree().current_scene)
		t = get_tree().current_scene
		_check("戻り先：昇級の「戻る」で育成（%s）" % str(t.get("_selected_id")), _path_of(t) == TRAINING and str(t.get("_selected_id")) == HERO)
		await _back(t)
		r = get_tree().current_scene
		_check("戻り先：育成の「戻る」で記録のキャラのタブ（前は育成の一覧）（%s）" % str(r.get("_tab")),
			_path_of(r) == RECORDS and int(r.get("_tab")) == RecordsScreen.TAB_CHARACTERS)
		# ⑤ 詰所 → 育成 → 戻る → 詰所（帯つき）。
		var b: Node = await _open(BARRACKS, {})
		if b == null:
			return
		await _press(b.find_child("OpenTrainingButton", true, false), OPEN_FRAMES)
		await _back(get_tree().current_scene)
		b = get_tree().current_scene
		_check("戻り先：詰所 → 育成 →「戻る」で詰所（帯つき）", _path_of(b) == BARRACKS and b.find_child("FacilityBar", false, false) != null)
		# ⑥ 出撃の準備（依頼つき）→ 育成 → 戻る → 同じ依頼の準備。
		var stage_id: String = str(MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)[0])
		b = await _open(BARRACKS, {TransferKeys.SORTIE_STAGE_ID: stage_id, TransferKeys.RETURN_PATH: ADVENTURE})
		if b == null:
			return
		_check("戻り先：出撃の準備にも「育成」がある", b.find_child("OpenTrainingButton", true, false) != null and b.find_child("SortieButton", true, false) != null)
		await _press(b.find_child("OpenTrainingButton", true, false), OPEN_FRAMES)
		await _back(get_tree().current_scene)
		b = get_tree().current_scene
		_check("戻り先：出撃の準備 → 育成 →「戻る」で同じ依頼の準備（%s・戻り先 %s）" % [str(b.get("_stage_id")), str(b.get("_return_path")).get_file()],
			_path_of(b) == BARRACKS and str(b.get("_stage_id")) == stage_id and str(b.get("_return_path")) == ADVENTURE)
		# ⑦ 掲示板（高難度・札0）→ ショップで買う → 戻る → 掲示板の高難度タブ。
		var have: int = GameManager.get_quota_ticket_count()
		if have > 0:
			GameManager.call("_remove_from_inventory", GameStateKeys.ITEM_QUOTA_TICKET, have)
		var q: Node = await _open(ADVENTURE, {TransferKeys.QUEST_TAB: 1})
		if q == null:
			return
		var shop_link: Node = q.find_child("ShopLinkButton", true, false)
		_check("戻り先：札が足りない高難度の札に「ショップで買う」", shop_link is BaseButton)
		await _press(shop_link, OPEN_FRAMES)
		_check("戻り先：「ショップで買う」でショップ", _path_of(get_tree().current_scene) == ADVENTURE_SHOP)
		await _back(get_tree().current_scene)
		q = get_tree().current_scene
		_check("戻り先：ショップの「戻る」で掲示板の高難度タブ（%s）" % str(q.get("_tab")), _path_of(q) == ADVENTURE and int(q.get("_tab")) == 1)
		# ⑧ タスクの画面で選ぶ →「これで集中」→ ポモドーロでそのタスクが選ばれている。
		var task_id: String = GameManager.add_task("寄り道の検査")
		var ts: Node = await _open(TASK_SCREEN, {})
		if ts == null:
			return
		var focus_this: Node = ts.find_child("FocusThisButton", true, false)
		_check("戻り先：何も選んでいなければ「これで集中」は出ない", focus_this is Control and not (focus_this as Control).visible)
		await _press(ts.find_child("Task_" + task_id, true, false))
		focus_this = ts.find_child("FocusThisButton", true, false)
		_check("戻り先：タスクを選ぶと「これで集中」", focus_this is Control and (focus_this as Control).visible)
		await _press(focus_this, OPEN_FRAMES)
		var p: Node = get_tree().current_scene
		var picked: String = str(p.call("_current_task_id")) if _path_of(p) == POMODORO else ""
		if picked == "" and _path_of(p) == POMODORO:
			picked = str(p.get("_wanted_task_id"))
		_check("戻り先：「これで集中」でポモドーロ・そのタスクを選んでいる（%s）" % picked, _path_of(p) == POMODORO and picked == task_id)
		await _open(BASE, {})

	# --- 入手先の窓（2026-10-06・`NAV-19`） ---

	func _source_window(scene: Node) -> Node:
		var modal: ModalDialog = _modal_of(scene)
		return null if modal == null else modal.find_child("ItemSourceWindow", true, false)

	# ⚠ 窓の中で、その種類の行の「行く」を探す（⚠ 並びは `get_item_sources()` と同じ）。
	func _source_go(window: Node, item_id: String, kind: String) -> Node:
		var sources: Array[Dictionary] = GameManager.get_item_sources(item_id)
		for i: int in range(sources.size()):
			if str(sources[i].get(GameManager.ITEM_SOURCE_KIND, "")) == kind:
				var row: Node = window.find_child("Source_%d" % i, true, false)
				return null if row == null else row.find_child("GoButton", true, false)
		return null

	func _flow_item_sources() -> void:
		const SHOP_SCREEN: String = "res://scenes/guild/shop_screen.tscn"
		# ⚠ データの口：マスターから引けているか（⚠ 手書きの表は無い）。
		var kinds: Array[String] = []
		for source: Dictionary in GameManager.get_item_sources("forging_material_1"):
			kinds.append(str(source.get(GameManager.ITEM_SOURCE_KIND, "")))
		_check("入手先：鍛冶の素材1 は ショップ・通常の依頼（%s）" % str(kinds),
			GameManager.ITEM_SOURCE_SHOP in kinds and GameManager.ITEM_SOURCE_STAGE in kinds)
		kinds.clear()
		for source: Dictionary in GameManager.get_item_sources("forging_material_4"):
			kinds.append(str(source.get(GameManager.ITEM_SOURCE_KIND, "")))
		_check("入手先：鍛冶の素材4 は 高難度の依頼（%s）" % str(kinds), GameManager.ITEM_SOURCE_DUNGEON in kinds)
		# ⚠ 入手先が1つも無い素材（⚠ 報告：いまマスターのどこにも出てこない）。
		var orphans: Array[String] = []
		for material_id: String in GameManager.get_material_ids():
			if GameManager.get_item_sources(material_id).is_empty():
				orphans.append(material_id)
		print("[DebugBoot] 入手先が無い素材: %s" % str(orphans))
		# ① 鍛冶場の素材の行 → 窓 → ショップへ → 戻る → その品を選んだ鍛冶場。
		GameManager.add_to_inventory(WEAPON_ID, 1, GameStateKeys.ITEM_TYPE_EQUIPMENT)
		var instance_id: String = _instance_of(WEAPON_ID)
		var f: Node = await _open(FORGE, {TransferKeys.FORGE_INSTANCE_ID: instance_id})
		if f == null:
			return
		var cost: Dictionary = GameManager.get_forge_cost(instance_id)
		var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
		await _press(f.find_child("SourceButton", true, false))
		var window: Node = _source_window(f)
		var rows: int = 0 if window == null else window.find_children("Source_*", "", true, false).size()
		_check("入手先：鍛冶場の「入手先を見る」で窓・行は %d（入手先 %d）" % [rows, GameManager.get_item_sources(material_id).size()],
			window != null and rows == GameManager.get_item_sources(material_id).size() and rows > 0)
		var locked_ok: bool = true
		var sources: Array[Dictionary] = GameManager.get_item_sources(material_id)
		for i: int in range(sources.size()):
			var go: Node = window.find_child("Source_%d" % i, true, false).find_child("GoButton", true, false) if window != null else null
			if not (go is BaseButton) or (go as BaseButton).disabled == bool(sources[i].get(GameManager.ITEM_SOURCE_OPEN, false)):
				locked_ok = false
		_check("入手先：まだ行けない行だけ「行く」が押せない", locked_ok)
		await _press(_source_go(window, material_id, GameManager.ITEM_SOURCE_SHOP), OPEN_FRAMES)
		_check("入手先：「ショップへ」でショップ", _path_of(get_tree().current_scene) == SHOP_SCREEN)
		await _back(get_tree().current_scene)
		f = get_tree().current_scene
		_check("入手先：ショップの「戻る」でその品を選んだ鍛冶場", _path_of(f) == FORGE and str(f.get("_selected")) == instance_id)
		# ② 届いた宝箱がその素材を出しうるなら、窓のいちばん上に「開けに行く」→ 宝箱 → 戻る → 鍛冶場。
		var chest_id: String = ""
		for raw: Variant in MasterDataLoader.get_all_chests():
			if GameManager.chest_can_give(str(raw), material_id):
				chest_id = str(raw)
				break
		if chest_id != "" and GameManager.grant_chest(chest_id, "debug_boot"):
			await _press(f.find_child("SourceButton", true, false))
			window = _source_window(f)
			var first: Dictionary = GameManager.get_item_sources(material_id)[0]
			_check("入手先：届いた宝箱（%s）がいちばん上" % chest_id, str(first.get(GameManager.ITEM_SOURCE_KIND, "")) == GameManager.ITEM_SOURCE_PENDING_CHEST)
			await _press(_source_go(window, material_id, GameManager.ITEM_SOURCE_PENDING_CHEST), OPEN_FRAMES)
			_check("入手先：「開けに行く」で届いた宝箱", _path_of(get_tree().current_scene) == CHEST)
			await _back(get_tree().current_scene)
			_check("入手先：宝箱の「戻る」で鍛冶場", _path_of(get_tree().current_scene) == FORGE)
		else:
			_check("入手先：%s を出す宝箱が見つからない" % material_id, false)
		# ③ 昇級 → 窓 → 出撃の準備へ（その話）→ 戻る → 昇級（同じキャラ）→ 戻る → 本部（積んだものは尽きた）。
		var l: Node = await _open(LEVEL_UP, {TransferKeys.CHARACTER_ID: HERO})
		if l == null:
			return
		var level_material: String = ""
		await _press(l.find_child("SourceButton", true, false))
		window = _source_window(l)
		var stage_go: Node = null
		var stage_ref: String = ""
		if window != null:
			var head_name: String = _label_text(window, "Head", "NameLabel")
			for item_id: String in GameManager.get_material_ids():
				if tr(GameManager.item_name_key(item_id)) == head_name:
					level_material = item_id
			for source: Dictionary in GameManager.get_item_sources(level_material):
				if str(source.get(GameManager.ITEM_SOURCE_KIND, "")) == GameManager.ITEM_SOURCE_STAGE and bool(source.get(GameManager.ITEM_SOURCE_OPEN, false)):
					stage_ref = str(source.get(GameManager.ITEM_SOURCE_REF, ""))
					break
			stage_go = _source_go(window, level_material, GameManager.ITEM_SOURCE_STAGE)
		_check("入手先：昇級の「入手先を見る」で窓（%s）・通常の依頼の行がある" % level_material, window != null and stage_go is BaseButton)
		await _press(stage_go, OPEN_FRAMES)
		var b: Node = get_tree().current_scene
		_check("入手先：「出撃の準備へ」でその話の出撃の準備（%s）" % str(b.get("_stage_id")), _path_of(b) == BARRACKS and str(b.get("_stage_id")) == stage_ref)
		await _back(b)
		l = get_tree().current_scene
		_check("入手先：出撃の準備の「戻る」で昇級（%s）" % str(l.get("_character_id")), _path_of(l) == LEVEL_UP and str(l.get("_character_id")) == HERO)
		await _back(l)
		_check("入手先：昇級の「戻る」は育成（積んだものは尽きた＝前と同じ）", _path_of(get_tree().current_scene) == TRAINING)
		# ④ 持ち物の素材 → 窓 → 掲示板へ（高難度）→ 戻る → 持ち物の素材タブ。
		var w: Node = await _open(BELONGINGS, {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_MATERIAL})
		if w == null:
			return
		await _press(w.find_child("Row_forging_material_4", true, false))
		await _press(w.find_child("SourceButton", true, false))
		window = _source_window(w)
		await _press(_source_go(window, "forging_material_4", GameManager.ITEM_SOURCE_DUNGEON) if window != null else null, OPEN_FRAMES)
		var q: Node = get_tree().current_scene
		_check("入手先：「掲示板へ」で掲示板の高難度タブ", _path_of(q) == ADVENTURE and int(q.get("_tab")) == TransferKeys.QUEST_TAB_HARD)
		await _back(q)
		w = get_tree().current_scene
		_check("入手先：掲示板の「戻る」で持ち物の素材タブ（%s）" % str(w.get("_tab")), _path_of(w) == BELONGINGS and str(w.get("_tab")) == TransferKeys.WAREHOUSE_TAB_MATERIAL)
		# ⚠ 修練の素材2・3（10-06・人間「⚠ trainingmateriualはシナリオ報酬と宝箱」）。
		for training_id: String in ["training_material_2", "training_material_3"]:
			var training_kinds: Array[String] = []
			for source: Dictionary in GameManager.get_item_sources(training_id):
				training_kinds.append(str(source.get(GameManager.ITEM_SOURCE_KIND, "")))
			_check("入手先：%s は通常の依頼で手に入る（%s）" % [training_id, str(training_kinds)], GameManager.ITEM_SOURCE_STAGE in training_kinds)
		await _flow_board_quick()
		await _flow_source_everywhere()
		await _open(BASE, {})

	# --- 素材を見せる所はどこからでも入手先の窓（2026-10-06・人間「⚠ 素材関連は全部広げる」） ---

	func _flow_source_everywhere() -> void:
		const RESEARCH_SCREEN: String = "res://scenes/guild/research_screen.tscn"
		const WORKSHOP_SCREEN: String = "res://scenes/guild/workshop_screen.tscn"
		# ⚠ 昇級の素材の段（`GR-7`）。
		var tiers: Array[String] = []
		for level: int in [1, 20, 21, 40, 41, 60, 61, 99]:
			tiers.append(GameManager.get_level_up_material_id(level))
		_check("昇級の素材：Lv1・20＝1 ／ 21・40＝2 ／ 41・60＝3 ／ 61・99＝4（%s）" % str(tiers),
			tiers == ["training_material_1", "training_material_1", "training_material_2", "training_material_2",
				"training_material_3", "training_material_3", "training_material_4", "training_material_4"])
		# ⚠ 本部には素材を出さない（10-06・人間「⚠ 拠点では書かずに、関連する画面でのみ表示するように」）。
		var base: Node = await _open(BASE, {})
		if base != null:
			_check("素材の帯：本部には素材のチップが無い", base.find_child("Chip_forging_material_1", true, false) == null)
		# 見出しの素材のチップ（⚠ その画面の系統だけ・「＋」つき・押すと窓）。
		var headers: Dictionary = {
			TRAINING_LIST: GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX,
			FORGE: GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX,
			RESEARCH_SCREEN: GameStateKeys.ITEM_CONSTRUCTION_MATERIAL_PREFIX,
			WORKSHOP_SCREEN: GameStateKeys.ITEM_DECOR_MATERIAL_PREFIX,
		}
		for path: String in headers:
			var screen: Node = await _open(path, {})
			if screen == null:
				continue
			var bar: Node = screen.find_child("MaterialBar", true, false)
			var ids: Array[String] = GameManager.get_material_ids_of_series(str(headers[path]))
			var chips: int = 0 if bar == null else bar.find_children("Chip_*", "", true, false).size()
			var first: Node = null if bar == null else bar.find_child("Chip_" + ids[0], true, false)
			_check("素材の帯：%s の見出しに %s の %d 件（%d）・「＋」" % [path.get_file(), str(headers[path]), ids.size(), chips],
				chips == ids.size() and first != null and first.find_child("PlusMark", true, false) != null)
			await _press(first.find_child("Hit", false, false) if first != null else null)
			_check("入手先：%s の見出しの素材を押すと窓" % path.get_file(), _source_window(screen) != null)
			await _close_modal(screen)
		# 育成の概要の昇級の行。
		var t: Node = await _open(TRAINING, {TransferKeys.CHARACTER_ID: HERO})
		if t != null:
			await _press(t.find_child("SourceButton", true, false))
			_check("入手先：育成の昇級の行から窓", _source_window(t) != null)
			await _close_modal(t)
		# 研究のノード。
		var rs: Node = await _open(RESEARCH_SCREEN, {})
		if rs != null:
			var research_source: Node = null
			for node: Node in rs.find_children("SourceButton_*", "", true, false):
				research_source = node
				break
			await _press(research_source)
			_check("入手先：研究のノードから窓", _source_window(rs) != null)
			await _close_modal(rs)
		# 作業場のレシピの材料。
		var ws: Node = await _open(WORKSHOP_SCREEN, {})
		if ws != null:
			var workshop_source: Node = null
			for node: Node in ws.find_children("SourceButton_*", "", true, false):
				workshop_source = node
				break
			await _press(workshop_source)
			_check("入手先：作業場の材料から窓", _source_window(ws) != null)
			await _close_modal(ws)
		# 持ち物の装飾の「段階を上げる」。
		var w: Node = await _open(BELONGINGS, {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_PART})
		if w != null:
			await _press(w.find_child("Row_" + PART_ID, true, false))
			await _press(w.find_child("SourceButton", true, false))
			_check("入手先：装飾の段階を上げる素材から窓", _source_window(w) != null)
			await _close_modal(w)

	# --- 施設の帯の掲示板 ／ 「すぐ出撃」（2026-10-06・人間「⚠ ３はどっちも行う」） ---

	func _flow_board_quick() -> void:
		var r: Node = await _open(RECORDS, {})
		if r == null:
			return
		await _press(r.find_child("Facility_" + BaseFacilityBar.BOARD, true, false), OPEN_FRAMES)
		var q: Node = get_tree().current_scene
		_check("掲示板：施設の帯の「掲示板」で依頼掲示板（帯つき）", _path_of(q) == ADVENTURE and q.find_child("FacilityBar", false, false) != null)
		if GameManager.is_in_floor():
			GameManager.abandon_floor()
		GameManager.add_stamina(9999)
		q = await _open(ADVENTURE, {})
		var stage_id: String = str(MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)[0])
		var card: Node = q.find_child("StageCard_" + stage_id, true, false)
		var quick: Node = null if card == null else card.find_child("QuickSortieButton", true, false)
		_check("掲示板：札に「すぐ出撃」", quick is BaseButton)
		await _press(quick, OPEN_FRAMES)
		var b: Node = get_tree().current_scene
		if _path_of(b) == BARRACKS and b.has_method("skip_sign"):
			b.call("skip_sign")
		await _wait(OPEN_FRAMES)
		_check("掲示板：「すぐ出撃」で準備の「出撃する」を押さずに出発（%s）" % _path_of(get_tree().current_scene).get_file(),
			_path_of(get_tree().current_scene) == FLOOR_MAP and GameManager.is_in_floor())
		GameManager.abandon_floor()

	func _task_order() -> Array[String]:
		var order: Array[String] = []
		for task: Variant in GameManager.get_tasks():
			order.append(str((task as Dictionary).get(GameStateKeys.TASK_ID, "")))
		return order

	func _log_focus(task_id: String) -> int:
		for entry: Variant in GameManager.get_task_log():
			if str((entry as Dictionary).get(GameStateKeys.TASK_ID, "")) == task_id:
				return int((entry as Dictionary).get(GameStateKeys.TASK_FOCUS_SEC, 0))
		return -1

	func _task_counts() -> Dictionary:
		var counts: Dictionary = {}
		for task: Variant in GameManager.get_tasks():
			counts[str((task as Dictionary).get(GameStateKeys.TASK_ID, ""))] = int((task as Dictionary).get(GameStateKeys.TASK_FOCUS_SEC, 0))
		return counts

	func _counts_same_except(before_counts: Dictionary, after_counts: Dictionary, skip_id: String) -> bool:
		for key: Variant in before_counts:
			if str(key) != skip_id and int(before_counts[key]) != int(after_counts.get(key, -1)):
				return false
		return true

	func _pending_of(chest_id: String) -> int:
		var count: int = 0
		for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
			if chest is Dictionary and not bool((chest as Dictionary).get(GameStateKeys.CHEST_OPENED, false)) \
					and str((chest as Dictionary).get(GameStateKeys.CHEST_ID, "")) == chest_id:
				count += 1
		return count

	# --- 小さい道具 ---

	func _open(path: String, data: Dictionary) -> Node:
		SceneManager.change_scene_with_data(path, data)
		await _wait(OPEN_FRAMES)
		var scene: Node = get_tree().current_scene
		if _path_of(scene) != path:
			_check("開く：%s" % path.get_file(), false)
			return null
		return scene

	func _press(node: Node, frames: int = WAIT_FRAMES) -> void:
		if node == null:
			_check("押す相手が見つからない", false)
			return
		if node is BaseButton:
			if (node as BaseButton).disabled:
				_check("押せない：%s" % node.name, false)
				return
			(node as BaseButton).pressed.emit()
		elif node is LedgerRow:
			(node as LedgerRow).pressed.emit()
		await _wait(frames)

	# 出撃の準備の枠の面の当たり（⚠ 枠は傾いた紙＝`Slot_<n>/Sheet/Hit`）。
	func _slot_hit(scene: Node, slot_index: int) -> Node:
		var slot: Node = scene.find_child("Slot_%d" % slot_index, true, false)
		return null if slot == null else slot.find_child("Hit", true, false)

	# 出撃の準備の名簿の札の当たり。
	func _roster_hit(scene: Node, character_id: String) -> Node:
		var card: Node = scene.find_child("Roster_" + character_id, true, false)
		return null if card == null else card.find_child("Hit", false, false)

	# ⚠ 画面の子に積まれた窓（⚠ 無ければ null）。
	func _modal_of(scene: Node) -> ModalDialog:
		for node: Node in scene.get_children():
			if node is ModalDialog and not node.is_queued_for_deletion():
				return node as ModalDialog
		return null

	# ⚠ 出ている窓を「閉じる」で閉じる（⚠ 本物のボタン）。⚠ 次の窓が出るまでの間（`MD-8`）も待つ。
	func _close_modal(scene: Node) -> void:
		var modal: ModalDialog = _modal_of(scene)
		if modal == null:
			return
		modal.close_button.pressed.emit()
		await _wait(WAIT_FRAMES * 3)

	# ⚠ 確かめの窓の「はい」を押す（⚠ 窓は画面の子に積まれる）。
	func _confirm_modal() -> void:
		await _wait()
		var scene: Node = get_tree().current_scene
		for node: Node in scene.get_children():
			if node is ModalDialog:
				(node as ModalDialog).confirm_button.pressed.emit()
				await _wait()
				return
		_check("確かめの窓が出ない", false)

	func _wait(frames: int = WAIT_FRAMES) -> void:
		for _i: int in range(frames):
			await get_tree().process_frame

	func _check(label: String, ok: bool) -> void:
		print("  %s = %s" % [label, "通った" if ok else "⚠ 落ちた"])
		if ok:
			_passed += 1
		else:
			_failed += 1
			push_error("[DebugBoot] ui_flow: " + label)

	func _path_of(node: Node) -> String:
		return "" if node == null else str(node.scene_file_path)

	func _hit_of(scene: Node, chip_name: String) -> Node:
		var chip: Node = scene.find_child(chip_name, true, false)
		return null if chip == null else chip.find_child("Hit", false, false)

	# 鍛える（⚠ 押す → ⚠ 演出の画面 `ForgeStrike` を飛ばす → ⚠ 結果の画面が出るまで）。
	func _forge_press(node: Node) -> void:
		await _press(node)
		var scene: Node = get_tree().current_scene
		var strike: Node = null if scene == null else scene.find_child("ForgeStrike", true, false)
		if strike is ForgeStrike:
			(strike as ForgeStrike).skip()
			await _wait()

	func _tab_button(scene: Node, index: int) -> Node:
		var tabs: Node = scene.find_child("Tabs", true, false)
		if tabs == null or index >= tabs.get_child_count():
			return null
		return tabs.get_child(index)

	func _label_text(scene: Node, holder_name: String, label_name: String) -> String:
		var holder: Node = scene.find_child(holder_name, true, false)
		var label: Node = null if holder == null else holder.find_child(label_name, true, false)
		return (label as Label).text if label is Label else ""

	func _first_of_type(root: Node, type_name: String) -> Node:
		for node: Node in root.find_children("*", "", true, false):
			var script: Script = node.get_script() as Script
			if script != null and script.get_global_name() == StringName(type_name):
				return node
		return null

	func _level() -> int:
		return int(GameManager.get_character_growth(HERO).get(GameStateKeys.GROWTH_LEVEL, 1))

	func _grade(instance_id: String) -> int:
		return int(GameManager.get_equipment_instance(instance_id).get(GameStateKeys.INSTANCE_GRADE, 0))

	func _instance_of(item_id: String) -> String:
		for view: Variant in GameManager.get_owned_instances():
			if str((view as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, "")) == item_id:
				return str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, ""))
		return ""

	func _first_empty(instance_id: String) -> int:
		for view: Variant in GameManager.get_part_entries(instance_id):
			if not ((view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null) is Dictionary):
				return int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, -1))
		return -1

	func _filled(instance_id: String) -> int:
		var count: int = 0
		for view: Variant in GameManager.get_part_entries(instance_id):
			if (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null) is Dictionary:
				count += 1
		return count


# 画素の色が近いか（⚠ 各色 2/255 まで）。⚠ カーソルの検査だけで使う。
func _cursor_color_close(a: Color, b: Color) -> bool:
	var limit: float = 2.0 / 255.0
	return absf(a.r - b.r) <= limit and absf(a.g - b.g) <= limit and absf(a.b - b.b) <= limit and absf(a.a - b.a) <= limit
