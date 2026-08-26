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

# シナリオの種類。
# ⚠ screen は窓あり専用。ヘッドレスでは描画がダミーなので何も分からない。
const KIND_BATTLE: String = "battle"
const KIND_SCREEN: String = "screen"
# ⚠ 戦闘も画面も使わず、GameManager を直接叩いて print だけして終わる枝。
#   素材・等級・鍛冶・分解のように「戦闘に1行も出ない」ものは、これが無いと
#   検証の口が無い（EXEC_MATERIAL_TIERS.md §0-2 の8）。
const KIND_REPORT: String = "report"

# KIND_REPORT の中でどの報告を出すか。
# ⚠ 枝が増えたら _ready() の match に1行足す。シーンもスクリプトも増やさないこと。
const REPORT_MATERIALS: String = "materials"
const REPORT_PARTS: String = "parts"
const REPORT_DROPS: String = "drops"
const REPORT_PRESETS: String = "presets"
const REPORT_LAYOUT: String = "layout"
const REPORT_UNLOCK: String = "unlock"
const REPORT_RESEARCH: String = "research"
const REPORT_WORKSHOP: String = "workshop"
const REPORT_ECONOMY: String = "economy"
const REPORT_FLOOR: String = "floor"

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
		# ⚠ 武器のルーン枠 → スキル1 ／ アクセのルーン枠2つ → スキル2（GAME_DESIGN 7-5）。
		# ⚠ char_debug_status には1つも刺さない（撃ってもルーンが出ないことの回帰）。
		"runes": {
			"char_debug_mix": {
				"weapon": ["part_rune_shield_1"],
				"accessory": ["part_rune_buff_5", "part_rune_move_5"],
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
		"note": "パッシブ。Lv20/40/60/80/100 で1→5件・条件付き4件・react 2件が発火するか",
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
	print("[DebugBoot] scenario=%s : %s" % [scenario_name, str(scenario.get("note", ""))])

	# ⚠ 状態は書き換えるが、絶対に保存しない。
	#   set_party_member() / select_skill() は本物の状態を触るので、保存すると
	#   人間の編成とスキル枠が黙って変わる。SaveManager をこのファイルから呼ばないこと。
	_apply_party(scenario)
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
		elif report == REPORT_LAYOUT:
			# ⚠ これだけ await を持つ（レイアウトは1フレーム待たないと確定しない）。
			await _report_layout()
		else:
			push_error("[DebugBoot] 知らない report: " + report)
		get_tree().quit()
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
	# ⚠ call_deferred なのは、_ready() の時点では root が子を組み立てている最中で
	#   add_child() が弾かれるため（"Parent node is busy setting up children"）。
	#   SceneManager が DebugOverlay を足すときに call_deferred しているのと同じ理由。
	get_tree().root.add_child.call_deferred(driver)

	# ⚠ 遷移も call_deferred。_ready() の中から呼ぶと、今のシーン（＝自分）を外す
	#   remove_child() が root の組み立て中に当たって弾かれる。
	SceneManager.change_scene_with_data.call_deferred(SCENE_BATTLE, {
		TransferKeys.STAGE_ID: str(scenario.get("stage_id", "")),
		TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
	})


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
# ⚠ パッシブは Lv20/40/60/80/100 で解放される。Lv1 のままだと1件も付かず、
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
	var probe: String = "ui_chest_legendary"
	print("[DebugBoot] ja.csv の再インポート: %s" % (
		"まだ（⚠ scenario=layout が赤3本・研究画面の効果が「？」になる）" if tr(probe) == probe
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
		print("  %-16s Lv%-4d passives=%d  %s" % [
			character_id,
			int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1)),
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
	for stage_id: String in stage_ids:
		var per_run: int = _economy_stage_material(stage_id, level_material)
		if per_run <= 0:
			print("  %-10s %s が 0 個/周 -> ⚠ ∞（このステージでは上がらない）" % [stage_id, level_material])
			continue
		var runs: int = int(ceil(float(total_one * 3) / float(per_run)))
		var stamina_total: int = runs * stamina_cost
		var focus_min: int = int(ceil(float(stamina_total) / float(stamina_per_potion) * float(focus_per_potion)))
		print("  %-10s %d 個/周 -> %d 周 / スタミナ %d / 集中 %d 分（%.1f 時間）" % [
			stage_id, per_run, runs, stamina_total, focus_min, float(focus_min) / 60.0
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
		var best_per_run: int = 0
		for stage_id: String in stage_ids:
			var per_run: int = _economy_stage_material(stage_id, material_id)
			if per_run > best_per_run:
				best_per_run = per_run
				best_stage = stage_id
		if best_per_run > 0:
			print("  %-24s %4d 個  最良 %s が %d 個/周 -> %d 周" % [
				material_id, need, best_stage, best_per_run,
				int(ceil(float(need) / float(best_per_run)))
			])
		else:
			print("  %-24s %4d 個  ⚠ どのステージからも落ちない -> %s" % [
				material_id, need, _economy_shop_line(material_id)
			])

	# --- 5. ゴールドの入口 ---
	print("[DebugBoot] --- ゴールドの入口（⚠ ショップの支払い元）---")
	for stage_id: String in stage_ids:
		print("  %-10s %d G/周" % [stage_id, _economy_stage_gold(stage_id)])

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
	print("  %-10s %4d G / スタミナ -%d / 宝箱 %s" % [
		stage_id, _economy_stage_gold(stage_id), stamina_cost,
		_economy_chest_expectation(str(rewards.get(GameStateKeys.CHEST_ID, ""))),
	])
	print("  %-10s 素材 %s" % ["", " + ".join(columns) if not columns.is_empty() else "（無し）"])
	print("  %-10s 持ち物 %s" % ["", " + ".join(inv_columns) if not inv_columns.is_empty() else "（無し）"])


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
		if not GameManager.forge_equipment(instance_id):
			push_error("[DebugBoot] 等級%d から鍛えられなかった" % grade)
			return

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
	var chest_rewards: Dictionary = chest.get(GameStateKeys.CHEST_REWARDS, {})
	var chest_inv: Dictionary = chest_rewards.get(GameStateKeys.REWARD_INVENTORY, {})
	print("  chest_id = '%s' / source = '%s' / inventory = %s" % [
		str(chest.get(GameStateKeys.CHEST_ID, "")),
		str(chest.get(GameStateKeys.CHEST_SOURCE, "")),
		str(chest_inv),
	])
	for item_id: String in chest_inv:
		if not _draw_has_item(probe_chest, item_id):
			push_error("[DebugBoot] %s のテーブルに無いIDが宝箱に入った: %s" % [probe_chest, item_id])

	var instance_id: String = str(chest.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
	var before_instances: int = _instance_count()
	var opened: bool = GameManager.open_chest(instance_id)
	print("  open_chest() = %s / 個体 %d -> %d" % [str(opened), before_instances, _instance_count()])
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
	print("  編成プリセット   = %d 件（10 が正解）" % GameManager.get_party_presets().size())
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
		GameManager.get_party_preset_apply_report(9).get(GameManager.APPLY_REASON, "")
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
		Balance.adventure.floor_chest_chance_pct
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
	var backup_chance: int = int(Balance.adventure.floor_chest_chance_pct)
	Balance.adventure.floor_chest_chance_pct = 0
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
	Balance.adventure.floor_chest_chance_pct = backup_chance
	print("  合計 %d 個 / %d 周（⚠ ちょうど %d 個＝各周1個が正解）" % [
		guarantee_total, guarantee_rounds, guarantee_rounds
	])
	print("  ⚠ 1個も出なかった周 = %d（0 が正解）" % guarantee_zero)
	print("  出現率を %d%% に戻した" % int(Balance.adventure.floor_chest_chance_pct))
	GameManager._state[GameStateKeys.PENDING_CHESTS] = []

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
	for scene_path: String in LAYOUT_SCENES:
		var other: PackedScene = load(scene_path)
		if other == null:
			push_error("[DebugBoot] 開けない: " + scene_path)
			continue
		# ⚠ 装備画面は character_id を渡さないと黄を1本出す（正常な保険）。
		#   ⚠ 測るためだけに黄を増やさない。先に渡しておく。
		SceneManager._transfer_data = {
			TransferKeys.CHARACTER_ID: str(GameManager.get_party_members()[0]),
		}
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

		var box: Control = _outermost_container(instance)
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
		instance.queue_free()
		await get_tree().process_frame


# 測る器。⚠ 増やすときはここに1行足す（関数の中に決め打ちしない）。
const LAYOUT_PATHS: Array[String] = [
	".",
	"Layout",
	"Layout/BottomArea",
	"Layout/BottomArea/BottomLayout",
	"Layout/BottomArea/BottomLayout/ResourceRow",
	"Layout/BottomArea/BottomLayout/MaterialsScroll",
	"Layout/BottomArea/BottomLayout/MaterialsScroll/MaterialsDisplay",
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
const LAYOUT_SCENE_SHOW: Dictionary = {
	"res://scenes/guild/training_screen.tscn": {
		"Margin/Layout/ListPanel": false,
		"Margin/Layout/DetailPanel": true,
	},
	# ⚠ ギルドは段階解放でボタンが1つずつ増える器。⚠ 開いた直後は1つも解放されておらず、
	#   ⚠ 見出しと戻るだけの姿を測っていた（72 x 72）。⚠ 段階11で6個目が増えたので、
	#   ⚠ 全部出した姿を測る（「5個前提の並びに6個目」を数字で見る唯一の道具）。
	"res://scenes/guild/guild_screen.tscn": {
		"CenterContainer/Layout/WarehouseButton": true,
		"CenterContainer/Layout/ShopButton": true,
		"CenterContainer/Layout/TrainingButton": true,
		"CenterContainer/Layout/ResearchButton": true,
		"CenterContainer/Layout/WorkshopButton": true,
	},
}


const LAYOUT_SCENES: Array[String] = [
	"res://scenes/adventure/party_preset_screen.tscn",
	"res://scenes/adventure/adventure_select.tscn",
	# ⚠ この2枚は、コードでノードを足しているので開かないと分からない
	#   （@onready のパス取り違え・move_child の相手違い）。
	"res://scenes/guild/training_screen.tscn",
	"res://scenes/guild/equipment_screen.tscn",
	# ⚠ 段階9でボタンの出し分けを足した。ボタンが減ると器の幅が変わる。
	"res://scenes/guild/guild_screen.tscn",
	# ⚠ 段階3でパッシブの一覧（見出し＋5行）をコードで足した。今まで測っていない。
	"res://scenes/guild/skill_select_screen.tscn",
	# ⚠ 段階10でノードが5件から18件に増え、カテゴリの見出しも足した。今まで測っていない。
	#   ⚠ ノード行は ScrollContainer の中なので、縦のはみ出しはここでは捕まらない
	#     （測れるのは横だけ。縦は人間が実機で見る＝EXEC_GUILD_RESEARCH_V2.md §7-3 の S-10）。
	"res://scenes/guild/research_screen.tscn",
	# ⚠ 段階11で復活した。ギルドのボタンが5個から6個に増えた回でもある
	#   （⚠ ギルドは VBoxContainer なので、はみ出すなら横ではなく縦）。
	"res://scenes/guild/workshop_screen.tscn",
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
	# ⚠ 撃った直後の x を出すか（段階8。移動系ルーンのロックを見るため）。
	#   ⚠ 既定は false。既存シナリオの出力を1行も増やさない。
	var dump_each_fire: bool = false

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
	# ⚠ 最後に「敵を全滅させた」時刻。⚠ bool にしないこと。ウェーブが複数ある
	#   ステージでは2回目以降も殺す必要がある（_process() の最後の枝）。
	var _last_kill_sec: float = -999.0
	var _finished_sec: float = -1.0


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
			if _finished_sec >= SETTLE_SEC:
				print("[DebugBoot] 終了")
				get_tree().quit()
			return

		if session.elapsed_sec > GIVE_UP_SEC:
			push_error("[DebugBoot] %.0f 秒たっても終わらないので諦める（撃った数=%d/%d）" % [
				GIVE_UP_SEC, _fired, skill_plan.size()
			])
			get_tree().quit()
			return

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
		return current


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
