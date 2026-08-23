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
	_apply_skills(scenario)

	if str(scenario.get("kind", KIND_BATTLE)) == KIND_REPORT:
		# ⚠ 報告の枝が増えたらここに1行足す。シーンもスクリプトも増やさないこと。
		var report: String = str(scenario.get("report", REPORT_MATERIALS))
		if report == REPORT_MATERIALS:
			_report_materials()
		elif report == REPORT_PARTS:
			_report_parts()
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


func _apply_skills(scenario: Dictionary) -> void:
	var table: Dictionary = scenario.get("skills", {})
	for raw_character_id in table.keys():
		var character_id: String = str(raw_character_id)
		var skill_ids: Array = table[raw_character_id]
		for slot: int in range(skill_ids.size()):
			# ⚠ 既に同じ枠に入っている場合は false が返るが、それは正常
			#   （game_manager.gd:2168 の "already in this slot"）。
			GameManager.select_skill(character_id, slot, str(skill_ids[slot]))


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
		if expected != part_id:
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
	print("  ⚠ ルーンは items.json に0件なので、ルーン枠には今は何も刺さらない")

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
