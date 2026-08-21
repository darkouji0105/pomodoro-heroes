# EXEC — **段階6：`spawn`（召喚・分裂）**

前提は `docs/01_plan/PLAN_SKILL_TEMPLATE.md` 9章（`host`）・12-2（発動者の分離）・14-2（召喚）・14-5（選抜対象）。
直前の回は `docs/02_exec/EXEC_SKILL_RECAST.md`（段階5）。検証の道具は `res://tests/debug_boot.tscn`。

⚠ **この回で本番スキルの挙動は1ミリも変わらない。** 増えるのは器と検証用データだけ。
⚠ **召喚が1体も居ないとき、既存の走査は全部空回りするだけであること**（段階1〜5の「既存を1ミリも変えない」の段階6版）。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-21）

| # | 決めたこと | 内容 |
|---|---|---|
| **1** | **座標** | ⚠ **JSON で指定する。前衛・後衛どちらのパターンもあり得る。** → 効果に `offset_x`（必須・正負可）。⚠ **符号は「敵に向かう向きが正」**（前衛が正・後衛が負）。味方は `+x`、敵は `-x` が敵方向なので、**チームで符号を反転してからワールド座標に足す** |
| **2** | **頭数** | ⚠ **数えない。専用配列（`BattleSession.summon_units`）を作る。** → `is_party_wiped()` / `is_wave_cleared()` は**1行も触らない**（混ざりようがない）。代わりに `_process()` の走査・`_find_unit_by_id()`・`get_alive_units()` に召喚を通す |
| **3** | **消え方** | ⚠ **`duration_sec` 切れは死亡ではない。**（`BattleLog` に `spawn` / `expire` を出して静かに消える）。⚠ **HP が0なら普通の死亡**（既存の `_step_deaths()` を通る＝復活の介入点も通る）。⚠ **召喚者が死んだら召喚も消える**（PLAN 14-2 のホログラム） |
| **4** | **発動者** | ⚠ **召喚ユニット自身。本体に何も戻さない。** `scale_from` も購読も召喚のもの。⚠ **`caster` 欄は今回作らない。** ⚠ **段階6では「召喚がスキルを撃つ」は作らない**（撃つ判断＝AIが別EXEC）。通常攻撃だけ撃つ |
| **5** | **上限** | ⚠ **上限を作らない。** `max_active` の欄を足さない |
| **6** | **ウェーブ交代・リトライ** | ⚠ **両方で消える。** 構え（`recast`）を捨てている4箇所と同じ場所に足す |
| **7** | **器の書き方** | ⚠ **`type: "summon"` が正。`host: "spawn"` は赤にする**（今の W6 を E93 に格上げ）。同じことが2通り書ける状態を残さない（E86 と同じ形） |

### 0-0. ⚠ 決定5（上限なし）の代償（**言ったうえで、決定どおりに作る**）

⚠ **CDの短い召喚スキルを1本書くと、召喚が無限に増える。** 走査が全部 `summon_units` を回るので、
フレームレートと `get_alive_units()` の母集団が同時に育つ。**エラーは1つも出ない。**
→ ⚠ **検証用スキルの `cooldown_sec` を 20.0 にして、この回で自分から踏まないようにする。**
→ ⚠ **§10 の宿題に「上限が無い」を残す。**

---

## 0-1. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め・要確認**）

**この章は人間が目を通していない。違うと思うものがあれば実装前に言うこと。**

| # | 決めたこと | なぜそうしたか |
|---|---|---|
| **1** | ⚠ **召喚の素データは新しいマスターファイル `resources/balance/master/summons.json` に置く**（`enemies.json` を使い回さない） | ⚠ **`enemies.json` に混ぜると、ウェーブの `enemy_type_id` にも書けてしまい、どちらの用途で置かれた行なのかロード時に判定できない。** ⚠ **リリース後にIDを改名できない**（`CLAUDE.md` 4番）ので、後から分けるのは無理。⚠ **フォルダは増やさない**（既存の `master/` に1ファイル） |
| **2** | ⚠ **`summons.json` のエントリの形は `enemies.json` の1件と同じ**（`name_key` / 10軸 / `attack_range` / `attack_interval_sec` / `attack_type` / `basic_attack`） | ⚠ **`BattleUnit.create()` が読む欄がそれで全部。2本目の形を作ると、軸を増やしたときに片方だけ直す** |
| **3** | ⚠ **`summons.json` に `skills` / `passives` を書いたら赤**（E101） | ⚠ **決定4で「段階6では召喚はスキルを撃たない」と決まっている。** 書けてしまうと無音で無視され、「持たせたのに撃たない」を実機で追うことになる |
| **4** | ⚠ **召喚は `results` 配列に `kind: "summon"` の1件として流し、生成は `battle_controller` がやる** | ⚠ **`SkillResolver` / `SkillRuntime` / `StatusRegistry` は `RefCounted` でノードを知らない（契約・PLAN 7-3）。** ⚠ **効果の種類の分岐は `SkillResolver` の1箇所（PLAN 9章が名指しで禁じている）** ので、`SkillRuntime` に `summon` の枝を置かない。⚠ **`results` に流すと `StatusRegistry.effects_applied` も同じ口を通るので、将来「死亡時に生える」（PLAN 10-1）が配線ゼロで通る** |
| **5** | ⚠ **`kind` の欄は召喚の1件だけが持つ。既存の damage / heal の1件には足さない** | ⚠ **`battle_last.jsonl` が1バイトも変わらないこと**（§6-3 の完了条件をそのまま検証できる）。⚠ **`log_results()` は `kind` を持つ1件を飛ばす** |
| **6** | ⚠ **走査に召喚を通すのは `_all_units()` 1本**（`_process` の各ループ・`_step_deaths` ・`_step_passives` ・`_clear_all_recast` ・`_find_unit_by_id`） | ⚠ **足す場所が8箇所ある。1つずつ書くと必ず1つ忘れ、しかも「召喚だけCDが回らない」のような無音の欠けになる**（構えを捨てる経路を1本ずつ対応して踏んだのと同じ形） |
| **7** | ⚠ **`get_alive_units(team)` は召喚を母集団に入れる**（＝敵に狙われる・味方の回復対象にもなる） | ⚠ **PLAN 14-5 の2欄（敵に狙われるか／味方の支援対象になるか）は、召喚ユニット自身が持つ欄として後で足す。** ⚠ **今回入れないと、召喚が誰からも狙われず誰にも狙えない置物になり、器として何も検証できない** → §10 の宿題 |
| **8** | ⚠ **死んだ召喚は `_step_deaths()` の**あと**に配列から取り除く**（`spawn` / `death`） | ⚠ **死体を残すと、上限が無い（決定5）ぶんだけ死体も無限に溜まる。** ⚠ **`_step_deaths()` より後なのは、復活の介入点を先に通すため**（復活したら消さない） |
| **9** | ⚠ **`unit_id` は `summon_<通し番号>`。番号は戦闘のあいだ増え続ける**（`summon_0` / `summon_1` …） | ⚠ **`party_%d` / `enemy_%d_%d` と綴りが被らないこと。** ⚠ **消えた番号を再利用しない**（`battle_last.jsonl` で同じIDが別の個体を指すと追えなくなる） |
| **10** | ⚠ **`count` は必須欄**（省略して1体にしない） | ⚠ **既定値を作らない方針**（`origin` / `stack` / `scale_from` と同じ）。⚠ **分裂は1体・取り巻きは3体で、どちらが既定かを決める理由が無い** |
| **11** | ⚠ **N体目の位置は `offset_x * (n + 1)`**（等間隔に伸ばす） | ⚠ **同じ x に重ねると数字が読めない**（宿題28）。⚠ **2本目の間隔の欄（`spacing_x`）を作らない**（欄が増えるほど書き忘れが増える） |
| **12** | ⚠ **召喚スキルにも top-level の `target` は必須**（既存の E8 を緩めない） | ⚠ **`blocked_reason()` が `target` を見て `skill_not_found` を返す**（`skill_activation.gd:45-49`）。⚠ **`summon` の効果は `target_ids` を読まないので、書いた `target` は選抜に使われるだけで当たらない** → §10 の宿題 |
| **14** | ⚠ **`BattleSession.find_unit()` を1本作り、`_find_unit()` の複製4本をそこへ寄せた**（宿題20の解消。⚠ **実装中に必要になったので後から足した決め**） | ⚠ **複製のうち3本が `summon_units` を知らず、召喚が「撃った記録だけ出てダメージが1本も出ない」状態になった（§11-1 の①）。** ⚠ **エラーは1つも出ない。** 3本を個別に直すと、次に配列を足すときに同じ事故が起きる。⚠ **配列を持っているクラスが探し方も持つ形にした** |
| **13** | ⚠ **`debug_boot` の改修は2つだけ**：`skill` が空の行は「下ごしらえだけの行」として消化する／`prepare` に `kill_party` を足す | ⚠ **味方を全滅させたあとにスキルを撃とうとすると `_find_user()` が null を返して赤を出す**（既存の `push_error`）。⚠ **シーンは増やさない** |

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-21**）

### 1-1. ⚠ 器の受け皿が**2通り**入っている（**この回で1本に潰す**）

| 場所 | 今 | この回で |
|---|---|---|
| `skill_schema.gd:89` | `EFFECT_TYPES_KNOWN` に `"summon"`（生の文字列） | ⚠ **`EFFECT_SUMMON` の定数にし、`EFFECT_TYPES_IMPLEMENTED` へ移す**（W4 が消える） |
| `skill_schema.gd:124` | `HOST_SPAWN` の定数 | ⚠ **定数は残す**（PLAN 9章の分類語として）。⚠ **効果の欄に書いたら赤**（E93） |
| `skill_schema.gd:821` | E30 が `and host != HOST_SPAWN` で `spawn` を除外している | ⚠ **除外をやめる** |
| `skill_schema.gd:827-829` | W6「`host: 'spawn'` は段階6。今は飛ばされる」 | ⚠ **E93 に格上げ**（W6 は欠番になる） |
| `skill_resolver.gd:349-350` | 未実装の効果は `push_warning` で飛ばす | ⚠ **`summon` の枝を足す。この行は残す**（`dispel` / `cancel` / `transform` / `move` がまだ通る） |

### 1-2. ⚠ 決定を縛っている実コードの事実（**5つ**）

| 事実 | 場所 | この回への影響 |
|---|---|---|
| ⚠ **`is_wave_cleared()` / `is_party_wiped()` は `enemy_units` / `party_units` しか見ない** | `battle_session.gd:54-66` | ⚠ **決定2（専用配列）なら、この2本を1行も触らずに「数えない」が成り立つ** |
| ⚠ **`get_alive_units(team)` は選抜と対象取得の唯一の口** | `battle_session.gd:74-80` | ⚠ **ここに召喚を足さないと、召喚は狙われも狙いもしない置物になる**（§0-1 の7） |
| ⚠ **`BattleUnit` は `RefCounted`。`UnitView` の生成は `battle_controller` の2箇所だけ** | `battle_controller.gd:241` / `:352` | ⚠ **召喚の生成も同じ層に置く。3箇所目になるので、`_make_unit_view()` を1本作って3箇所とも通す** |
| ⚠ **`results` は「ダメージ数値を出す」ためだけの配列** | `battle_controller.gd:1090` / `battle_log.gd:182` | ⚠ **`kind` を持つ1件を、表示（`_on_skill_effects_applied`）と記録（`log_results`）の両方で先に弾く**。片方だけだと `amount: 0` の damage の行が出る |
| ⚠ **リトライは `BattleSession` を作り直す** | `battle_controller.gd:1362` | ⚠ **`summon_units` は新しい配列になるので自動で空。⚠ ビューは残るので `_clear_all_summons()` を明示的に呼ぶ** |

### 1-3. ⚠ 段階5から引き継いだ、この回に効く事実

- ⚠ **検証用スキルは `characters.json` の候補一覧にも足さないと枠に入らない**（`game_manager.gd:2129`）
- ⚠ **`attack_type: physical` だと敵の `def` で `amount: 1` に潰れる。数値で区別したいなら `"true"`**
- ⚠ **`char_debug_mix` の `atk` は 1。** ⚠ **召喚の `atk` を 50 にすれば、`damage` の数値だけで「本体が殴ったか召喚が殴ったか」が読める**（決定4の検証がタダで付く）
- ⚠ **E は E92 まで／W は W12 まで使用済み**（W7 は欠番）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ 走査を8箇所に散らさない

⚠ **`_all_units()` を1本作り、`party_units` → `enemy_units` → `summon_units` の順で返す。**
⚠ **順番を変えないこと。** 対象の選び直しと攻撃の順が変わると、同じ入力で違うログが出る（再現性が落ちる）。

### 2-2. ⚠ 「召喚が0体のとき、既存が1ミリも変わらない」

⚠ **段階1〜5で毎回かけている完了条件の段階6版。** `summon_units` が空なら、足したループは全部空回りする。
⚠ **`results` に `kind` を足すのは召喚の1件だけ**（既存の1件に `kind: ""` を足さない。`battle_last.jsonl` が変わる）。

### 2-3. ⚠ `MasterDataLoader` が返す数値は必ず `float`

⚠ **`duration_sec` / `offset_x` を `is int` で見ない。** `E69` はこれで9件を誤って赤にしていた（`CLAUDE.md` 3番）。
⚠ **検証は `_is_num()` を使う。** ⚠ **`count` だけは「整数であること」を見るが、`is int` ではなく `float` を `int()` に落として元と一致するかで見る。**

### 2-4. ⚠ 符号をワールド座標に直接足さない

⚠ **決定1は「敵に向かう向きが正」。** 味方は `+1`、敵は `-1` を掛けてから足す。
⚠ **掛け忘れると、敵の召喚だけ後ろ向きに出る。** 敵の召喚がまだ居ないので**実機で気づけない**（§8 に回す）。

### 2-5. ⚠ ビューの後始末を忘れない

⚠ **消える経路が5本ある**：**①期限切れ ②召喚者の死亡 ③召喚自身の死亡 ④ウェーブ交代 ⑤リトライ**。
⚠ **`BattleUnit` を配列から外すだけではノードが残る。** 外す処理は `_remove_summon()` 1本に閉じ、5本ともそこを通す。

### 2-6. ⚠ 編集したら `grep` で当たったことを確認する

⚠ **`grep -n "summon_units" <ファイル>` が0件でないことを、書いた直後に確認する**（`CLAUDE.md` 2番）。

---

## 3. 実装（ファイル別）

⚠ **インデントはタブ。** ⚠ **関数を足す前に `grep -n "func <名前>"`。**

### 3-0. JSON の形（**決まり**）

```json
{
	"type": "summon",
	"unit_id": "summon_dbg_guard",
	"count": 2,
	"duration_sec": 4.0,
	"offset_x": -60.0
}
```

| 欄 | 必須 | 意味 |
|---|---|---|
| `unit_id` | ✅ | `summons.json` のID |
| `count` | ✅ | 出す体数。**N体目は `offset_x * (N+1)`** |
| `duration_sec` | ✅ | 期限（秒）。**0以下は赤。無期限は作らない** |
| `offset_x` | ✅ | 召喚者からの距離。⚠ **正＝前衛（敵に向かう向き）／負＝後衛** |

⚠ **`target` / `scale_from` / `multiplier` / `attack_type` / `host` は書けない**（E98 / E93）。
⚠ **スキルの top-level には `target` が要る**（§0-1 の12。書いた `target` は当たらない）。

### 3-1. `resources/balance/master/summons.json`（**新規**）

```json
{
	"summon_dbg_guard": {
		"name_key": "ui_battle_summon_dbg_guard",
		"hp": 200, "atk": 50, "mag": 1, "def": 5, "mdef": 5,
		"spd": 300, "atkspd": 0, "haste": 0, "crit_rate": 0, "crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 400,
		"attack_interval_sec": 0.5,
		"basic_attack": {
			"effects": [
				{ "type": "damage", "delivery": "melee", "multiplier": 1.0, "attack_type": "true", "scale_from": "atk" }
			]
		}
	}
}
```

⚠ **`attack_type: "true"` は `basic_attack` の効果のほうに書く**（`def` で潰されて `amount: 1` になるのを避ける・段階5の実測）。
⚠ **`atk: 50`** … 本体（`char_debug_mix` は `atk: 1`）と数値で区別するため。
⚠ **`skills` / `passives` を書かない**（E101）。

### 3-2. `scripts/systems/master_data_loader.gd`

- `PATH_SUMMONS` / `_cache_summons` / `get_summon(id)` / `has_summon(id)` を足す
- `_ensure_loaded()` に `_cache_summons = _load_json(PATH_SUMMONS)` を1行（⚠ **`_validate_all_skills()` より前**）
- `_validate_all_skills()` に**クロス検証を2本**（既存の `target.range` × `attack_range` と同じ場所・同じ形）
  - **E100** … `summon` の `unit_id` が `summons.json` に無い
  - **E101** … `summons.json` のエントリに `skills` / `passives` が書いてある
  - ⚠ **`phases[]` の中の効果も見ること**（`SkillSchema.phase_count()` / `phase_of()` を回す）

### 3-3. `scripts/systems/skill_schema.gd`

**足す定数**：`EFFECT_SUMMON = "summon"` ／ `SUMMON_FIELDS_REQUIRED = ["unit_id", "count", "duration_sec", "offset_x"]` ／ `SUMMON_FIELDS_FORBIDDEN = ["target", "scale_from", "multiplier", "attack_type"]`。
`EFFECT_TYPES_KNOWN` の生文字列 `"summon"` を定数に差し替え、**`EFFECT_TYPES_IMPLEMENTED` に足す。**

**検証（E93〜E99・W13）**：

| # | 赤にする条件 |
|---|---|
| E93 | ⚠ **`host: "spawn"` が書いてある**（W6 の格上げ。`HOST_SPAWN` の定数は残す） |
| E94 | `summon` に `unit_id` が無い、または空 |
| E95 | `summon.duration_sec` が数値でない、または `0.0` 以下 |
| E96 | `summon.offset_x` が数値でない |
| E97 | `summon.count` が整数でない、または 1 未満 |
| E98 | `summon` に書けない欄がある（`SUMMON_FIELDS_FORBIDDEN`） |
| E99 | `summon` 以外の効果に `unit_id` / `offset_x` / `count` が書いてある |
| **W13** | `summon.offset_x` が `0.0`（⚠ **召喚者と完全に重なって数字が読めない**・宿題28） |

⚠ **E30 の `and host != HOST_SPAWN` を外す。** 外し忘れると E93 と E30 が同じ行に2本出る。
⚠ **既存の E29（残る効果に `host` が無い）を `summon` に走らせない**（`summon` は状態ではない）。

### 3-4. `scripts/systems/battle_session.gd`

- `var summon_units: Array = []` を足す（`enemy_units` の隣）。`_init()` でも空にする
- ⚠ **`is_wave_cleared()` / `is_party_wiped()` は触らない**（決定2）
- `get_alive_units(team)` … ⚠ **`summon_units` のうち `team` が一致する生存者を末尾に足す**（§0-1 の7）

### 3-5. `scripts/systems/unit.gd`

**足す変数（3本）**：

| 変数 | 意味 |
|---|---|
| `is_summon: bool = false` | 召喚か。⚠ **書いてよいのは `battle_controller._spawn_summon()` だけ** |
| `summon_owner_id: String = ""` | 召喚者の `unit_id`（決定3の「本体が死んだら消える」） |
| `summon_remaining: float = 0.0` | 期限の残り |

⚠ **関数を足さない。** 期限を減らすのは `battle_controller._step_summons()` の1箇所（`recast` と違い、判定する側が `BattleUnit` の外に居るため）。

### 3-6. `scripts/systems/skill_resolver.gd`

`resolve()` の効果の分岐に `summon` の枝を1本足す（`EFFECT_TYPES_STATUS` の下・未実装の `push_warning` の上）。

```gdscript
elif effect_type == SkillSchema.EFFECT_SUMMON:
	# ⚠ ここではノードを作らない（契約・PLAN 7-3）。results に1件流すだけ。
	#   生成は battle_controller。⚠ target_ids は読まない（召喚は対象を取らない）。
	results.append({
		"kind": SkillSchema.EFFECT_SUMMON,
		"source_unit_id": user.unit_id,
		"summon_unit_id": str(effect.get("unit_id", "")),
		"count": int(effect.get("count", 0)),
		"duration_sec": float(effect.get("duration_sec", 0.0)),
		"offset_x": float(effect.get("offset_x", 0.0)),
	})
```

⚠ **`unit_id` の欄を作らない**（既存の1件では「ダメージを受けた側」の意味。同じ名前で別の意味を持たせない）。
⚠ **`host` のガード（`:328`）は `summon` を通すこと**（`summon` は `host` を書かないので `HOST_NONE` のまま通る＝**触らなくてよい**）。

### 3-7. `scripts/systems/battle_log.gd`

- `log_results()` … ⚠ **先頭で `if r.has("kind"): continue`**（`amount: 0` の damage の行を出さない）
- `log_spawn(owner_id, unit_id, source_id, x, why)` … `ev: "spawn"`。`why` は `begin` / `expire` / `owner_death` / `death`

### 3-8. `scenes/adventure/battle_controller.gd`

**足す定数**：`SPAWN_WHY_BEGIN` / `SPAWN_WHY_EXPIRE` / `SPAWN_WHY_OWNER_DEATH` / `SPAWN_WHY_DEATH`。

**足す変数**：`_summon_views: Array = []` ／ `_next_summon_serial: int = 0`。

**足す関数**：

| 関数 | 契約 |
|---|---|
| `_all_units() -> Array` | `party_units` ＋ `enemy_units` ＋ `summon_units` を**この順で**返す |
| `_make_unit_view(unit, parent) -> Node` | ⚠ **既存の味方・敵の生成もこれに通す**（3箇所目を作らない） |
| `_spawn_summon(r: Dictionary) -> void` | `results` の1件から召喚を生やす |
| `_step_summons(delta) -> void` | 期限・召喚者の死亡・召喚自身の死亡をまとめて片付ける |
| `_remove_summon(unit, why) -> void` | ⚠ **消す経路5本の唯一の出口**（§2-5） |
| `_clear_all_summons(why) -> void` | 全部消す（ウェーブ交代・リトライ・勝敗確定） |

**差し替える場所**：

1. `_on_skill_effects_applied()` … ⚠ **ループの先頭で `kind` を見て `_spawn_summon()` へ回し `continue`**（`_find_unit_by_id` より前）
2. `_process()` の走査5本（`tick_cooldowns` / `_step_recast_windows` / `_acquire_target_if_needed` / `_step_unit` / `_step_deaths` / `_step_passives`）を `_all_units()` に寄せる
3. `_process()` の `_step_deaths()` の**直後**に `_step_summons(delta)`（⚠ **`_step_passives()` より前・勝敗判定より前**）
4. `_find_unit_by_id()` に `summon_units` を足す
5. `_clear_all_recast()` を `_all_units()` に寄せる
6. `_enter_wave_clear()` / `_enter_victory()` / `_enter_defeat()` の `_clear_all_recast()` の隣に `_clear_all_summons()`
7. `_init_session()`（リトライ）… ⚠ **`_session` を作り直す**前**に `_clear_all_summons()`**（あとだと新しい空配列を見てビューが残る）

**`_spawn_summon()` の中身**：

```
1. owner = _find_unit_by_id(r.source_unit_id)。null か死んでいたら何もしない
2. data = MasterDataLoader.get_summon(r.summon_unit_id)。空なら何もしない（ロード時検証が赤で言っている）
3. dir = +1.0 if owner.team == TEAM_PARTY else -1.0     # ⚠ 決定1の符号
4. for n in range(count):
     unit = BattleUnit.create("summon_%d" % _next_summon_serial, owner.team, data, data, false)
     _next_summon_serial += 1
     unit.is_summon = true
     unit.summon_owner_id = owner.unit_id
     unit.summon_remaining = duration_sec
     unit.x = owner.x + dir * offset_x * float(n + 1)
     _session.summon_units.append(unit)
     _make_unit_view(unit, self) → _summon_views / _views_by_unit_id
     BattleLog.log_spawn(owner.unit_id, unit.unit_id, summon_unit_id, unit.x, SPAWN_WHY_BEGIN)
```

⚠ **`skill_ids` / `passive_ids` を埋めない**（決定4）。⚠ **ビューの親は `self`**（投射物と同じ。敵のコンテナに入れるとウェーブ交代で巻き添えになる）。

**`_step_summons()` の中身**（⚠ **配列を回しながら消さない。集めてから消す**）：

```
消す候補を集める：
  ・summon_remaining <= 0.0            → expire
  ・召喚者が居ない or 死んでいる        → owner_death
  ・自分が死んでいる（is_alive() == false） → death
残す個体だけ summon_remaining -= delta
集めた個体を _remove_summon(unit, why)
```

⚠ **`_step_deaths()` の後に置くこと。** 前に置くと、復活の介入点を通る前に召喚を消してしまう。

### 3-9. `scripts/systems/skill_activation.gd`

⚠ **触らない。** 召喚スキルも top-level の `target` を持つので、判定は今の形のまま通る（§0-1 の12）。

### 3-10. 検証用データ（**3ファイル。⚠ どれか1つ欠けると動かない**）

**`resources/balance/master/characters/char_debug_mix/skills.json`**

```json
"skill_dbg_summon": {
	"name_key": "ui_battle_skill_dbg_summon",
	"user_character_id": "char_debug_mix",
	"unlock_level": 1,
	"cooldown_sec": 20.0,
	"activation": "instant",
	"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
	"effects": [
		{ "type": "summon", "unit_id": "summon_dbg_guard", "count": 2, "duration_sec": 4.0, "offset_x": -60.0 }
	]
}
```

**`resources/balance/master/characters.json`** … ⚠ **`char_debug_mix` の `skills[]`（候補一覧）にも `skill_dbg_summon` を足す**（`game_manager.gd:2129`。足し忘れると `debug_boot` が「スキルを持っているユニットが居ない」の赤を出す）。

**`localization/ja.csv`** … 2行。⚠ **UTF-8（BOMなし）。再インポートは人間の作業。**

```
ui_battle_skill_dbg_summon,召喚テスト
ui_battle_summon_dbg_guard,守護霊（検証用）
```

⚠ **`cooldown_sec: 20.0`** … 上限が無い（決定5）ので、検証中に無限召喚を踏まないため。
⚠ **`offset_x: -60.0`（後衛）** … 味方は `x=200/300/400` なので、`x=140` と `x=80` に出る。⚠ **前衛（正）の側はコードの符号だけで、この回のデータでは通らない** → §8。

### 3-11. `tests/debug_boot.gd`

- 定数 `PREPARE_KILL_PARTY: String = "kill_party"` と `PREPARE_KILL_POWER: int = 999999` を足す
- `_step_fire()` の下ごしらえの分岐を `damage_party` / `kill_party` の2つにする
- ⚠ **`skill` が空文字の行は「下ごしらえだけの行」**として `_fired += 1` して消化する（⚠ **足さないと `_find_user()` が null で赤を出す**）
- シナリオ **`summon`** と **`summon_wipe`** を `SCENARIOS` に2行足す

```
"summon": stage_dbg_area / char_debug_mix に ["skill_dbg_summon", "skill_dbg_area_wide"]
	fire: [ {skill: "skill_dbg_summon"},
	        {skill: "skill_dbg_area_wide", gap: 6.0} ]   # ⚠ duration 4.0 を跨いで待つ

"summon_wipe": 同じ編成
	fire: [ {skill: "skill_dbg_summon"},
	        {skill: "", prepare: PREPARE_KILL_PARTY, gap: 0.5} ]
```

⚠ **シーンを増やさない。`SCENARIOS` に2行足すだけ。**

### 3-12. 触らないファイル

⚠ **`skill_runtime.gd`（効果の種類の分岐を持たせない）／ `status_registry.gd` ／ `skill_activation.gd` ／ `battle_formula.gd`**
⚠ **本番スキルの JSON 全件 ／ `enemies.json` ／ `stages.json` ／ `project.godot` ／ `addons/`**

---

## 4. 変えないもの

- ⚠ **召喚が0体のときの挙動**（本番の全件。§2-2）
- ⚠ **`is_wave_cleared()` / `is_party_wiped()` の中身**（決定2）
- ⚠ **`phases` / `recast` の挙動**（段階5）
- ⚠ **`battle_last.jsonl` の既存の行の形**（`kind` を持つのは召喚の1件だけ）
- ⚠ **`SkillResolver` の契約**（時間を知らない・段を知らない・ノードを知らない）
- ⚠ **`stage_dbg_area` と `skill_dbg_area_*` と `skill_dbg_recast_two`**

---

## 5. 完了条件 — **§0 事前チェック**（⚠ **設計役・ヘッドレス。人間の仕事は無い**）

⚠ **人間に渡す前に、設計役が全シナリオを1回ずつ回す。**

1. ⚠ **引数なしで起動すると、シナリオ一覧に `summon` と `summon_wipe` が出て `exit=0` で終わること**
2. ⚠ **stderr に `ERROR:` / `SCRIPT ERROR:` / `Parse Error` が1行も出ないこと**（全シナリオ：`area` / `recast` / `recast_expire` / `training` / `summon` / `summon_wipe` / 引数なし）
3. ⚠ **`skills validated: 61 entries, 0 errors, 1 warnings` が出ること**（⚠ **60 → 61 は `skill_dbg_summon` の1件ぶん。黄1本は `skill_dbg_dot_odd` の端数＝出るのが正解**）

## 6. 完了条件 — **ログ / ファイル**（⚠ **設計役が読む**）

### 6-1. `-- scenario=summon`

4. ⚠ **`spawn` の行が `why: "begin"` で2本出ていること**（`count: 2`）。⚠ **`unit_id` が `summon_0` / `summon_1` で、番号が重複していないこと**
5. ⚠ **2本の `x` が `召喚者の x − 60` と `召喚者の x − 120` であること**（決定1・⚠ **等間隔＝`offset_x * (n+1)`**。⚠ **符号が逆なら「敵に向かう向きが正」を掛け忘れている**）
6. ⚠ **`source_unit_id` が `summon_*` の `damage` の行が1本以上出ていること**（＝召喚が走査に乗って歩いて殴った）
7. ⚠ **その `damage` の `amount` が `50`（召喚の `atk`）であって `1`（本体の `atk`）でないこと**（決定4・発動者の分離）
8. ⚠ **`spawn` の `why: "expire"` が2本、`begin` の `t` から `4.0` 秒後に出ていること**（⚠ **`is int` で読んで即座に切れる事故＝§2-3 がここで出る**）
9. ⚠ **`expire` のあとに `source_unit_id` が `summon_*` の `damage` が1本も無いこと**（消えている）
10. ⚠ **`skill_dbg_area_heal` の `heal` の行が5本出ていること**（味方3体 ＋ 召喚2体）。⚠ **`dst` に `summon_0` / `summon_1` が含まれていること**（§0-1 の7・召喚が味方の母集団＝`get_alive_units()` に入っている）
	- ⚠ **これは元は §7（画面）の「敵が召喚を殴りに来る」だった。⚠ 後衛の召喚は味方より後ろに立つので、敵の `nearest` には選ばれず画面では確かめられない**（人間の指摘・2026-08-21）。⚠ **狙われる側からは検証できないので、支援される側から取る**
11. ⚠ **`result` の行が出ていること**（途中で切れていない）

### 6-2. `-- scenario=summon_wipe`

12. ⚠ **味方3人が死んだフレームで `result` の `victory: false` が出ていること**（⚠ **召喚が生きていても敗北する＝`is_party_wiped()` に混ざっていない**。⚠ **混ざっていたら決着せず、`180 秒たっても終わらないので諦める` の赤が出る**）
13. ⚠ **`spawn` の `why` が `owner_death` で出ていること**（決定3・召喚者が死んだら消える）

### 6-3. `-- scenario=area` / `-- scenario=recast`（**既存が1ミリも変わっていないこと**）

14. ⚠ **`area` で巻き込んだ数が段階4の実測と一致すること**：`narrow` **2** ／ `wide` **4** ／ `far` **4** ／ `heal` の `heal` 行 **3**（⚠ **召喚が居ないシナリオなので3のまま。ここが5になったら、召喚が居ないのに母集団が増えている**）
15. ⚠ **`recast` の `cast` が2本で `phase` が `0` と `1`、`damage` が **2** と **8** であること**（段階5の実測と一致）
16. ⚠ **どちらのシナリオにも `spawn` の行と `kind` の欄が1つも無いこと**（§0-1 の5）

### 6-4. セーブ

17. ⚠ **`save_slot_0.json` が走らせる前と1バイトも変わらないこと**（`debug_boot` は保存しない）

### 6-5. ⚠ 足した検証が本当に赤を出すか（**無音で通るのが一番怖い**）

18. ⚠ **検証用データを一時的に壊して、E93〜E99 のうち2本以上が実際に出ることを確かめる。⚠ 確かめたら必ず戻し、`61 entries, 0 errors, 1 warnings` に戻ることまで見る。** ⚠ **本番コードは1行も触らない**

## 7. 完了条件 — **画面**（⚠ **人間。窓ありで1回だけ**）

⚠ **ヘッドレスでは分からないものだけ。** ⚠ **合図で書く。時間で書かない。**

19. ⚠ **`skill_dbg_summon` のボタンを押すと、味方の列の**左側**に四角が2つ増えること**（⚠ **1つしか増えない／右側に出るなら `offset_x` の符号か `count` が効いていない**）
20. ⚠ **増えた2つが、敵に届くと数字を出すこと。⚠ その数字が味方の出す数字より大きいこと**（同じなら本体のステータスで殴っている）
21. ⚠ **数字を出していた四角が、押してからしばらくすると消えること。消えたあとに死亡の演出（数字・色の変化）が出ないこと**（決定3・期限切れは死亡ではない）
22. ⚠ **もう一度押すと、また2つ増えること**（⚠ **上限が無い＝決定5。増えなければ上限を作ってしまっている**）

> ⚠ **「敵が召喚を殴りに来るか」はここに書かない**（人間の指摘・2026-08-21）。⚠ **今の検証用データは後衛（`offset_x: -60`）だけで、召喚は味方より後ろに立つ。敵は `nearest` で選ぶので、召喚は最後まで狙われない。** → ⚠ **母集団に入っていることは §6-1 の10（回復の `heal` が5本）で取る。「前衛の召喚が狙われるか」は §8。**

---

## 8. 将来コードを変えたときに見る項目（**UIから到達できない・人間の確認項目にしない**）

- ⚠ **敵が召喚したときに符号が反転するか**（`offset_x` が正なら敵は `-x` 側へ）。⚠ **敵の召喚スキルがまだ無いので実測できない**（§2-4）
- ⚠ **`offset_x` が正（前衛）のとき、味方の列より右に出るか**（この回のデータは負だけ）
- ⚠ **前衛の召喚が敵に狙われるか**（`nearest` の一番手になるのは前衛のときだけ。⚠ **後衛では最後まで狙われない**ので、この回のデータでは画面でもログでも出ない。⚠ **母集団に入っていること自体は §6-1 の10 で取れている**）
- ⚠ **召喚が生きているまま次のウェーブへ進んだときに消えるか**（`stage_dbg_area` は1ウェーブなので実測できない）
- ⚠ **リトライで召喚のビューが残らないか**（`debug_boot` はリトライを押さない）
- ⚠ **味方の回復（`team: ally, sort: all`）が召喚も回復するか**（PLAN 14-5 の欄がまだ無いので、今は必ず入る）
- ⚠ **`scale_from` の `alive_count_*` に召喚が入るか**（`get_alive_units()` を通すので入る。本番に召喚が無いので影響ゼロ）

---

## 9. Ziva に渡せる部分

⚠ **無い。**

⚠ **`summons.json`（§3-1）と `skill_dbg_summon`（§3-10）と `ja.csv` の2行は JSON と CSV だけだが、`skill_schema.gd` の E93〜E99 と `master_data_loader.gd` の `summons.json` 読み込みが入る前に足すと、ロード時に赤が出る**（`type: "summon"` が W4 で飛ばされ、`unit_id` / `offset_x` / `count` は「知らない欄」の検出が無い（宿題15）ので**無音で無視される**）。⚠ **順番が縛られているので分割しない。**

---

## 10. 終わったあとに足す宿題（`PROJECT_STATUS.md`。⚠ **書き換えるかは人間の判断**）

- ⚠ **NEW：召喚の同時数に上限が無い**（人間の決定5）。⚠ **CDの短い召喚スキルを1本書くと無限に増え、エラーは1つも出ない**
- ⚠ **NEW：PLAN 14-5 の2欄（敵に狙われるか／味方の支援対象になるか）がまだ無い。** ⚠ **今はどちらも「入る」で固定**（ゾンビ型＝支援を吸わない召喚が書けない）
- ⚠ **NEW：召喚はスキルもパッシブも持てない**（決定4）。⚠ **持たせるときは `caster`（PLAN 12-2）と発動判断（AI）を先に決める**
- ⚠ **NEW：召喚スキルにも意味の無い `target` を書かされる**（§0-1 の12）。⚠ **`blocked_reason()` が `target` を要求しているため**
- ⚠ **NEW：召喚の x が既存のユニットと重なりうる**（宿題28と同じ枠。立ち位置をずらす仕組みが要る）
- ⚠ **NEW：`W6` が欠番になった**（`host: "spawn"` を E93 に格上げ・決定7）。⚠ **W7 に続いて2件目**
- ⚠ **NEW：`summons.json` を足したので、`MasterDataLoader` が読むファイルが5本になった**（`CHARACTER_DIRS_REQUIRED` と同じで、足し忘れると無音で消える形が1つ増えた）
- ⚠ **既存：検証用のものはリリース前に消す**（`summons.json` ／ `skill_dbg_summon` ／ `tests/debug_boot` も対象）
- ⚠ **解消：宿題20（`_find_unit()` が3ファイルに同じ形で3本ある）** … §11-1 で `BattleSession.find_unit()` の1本に寄せた（**4本あった**）

---

## 11. ⚠ 実施結果（**2026-08-21・設計役がヘッドレスで実行して判定**）

⚠ **§5・§6 は全部通った。§7（画面・19〜22）は未実施＝人間の担当。**

| 項目 | 結果 |
|---|---|
| 5-1 一覧に `summon` / `summon_wipe` が出て `exit=0` | ✅ 通った |
| 5-2 全シナリオで stderr に赤が1行も無い | ✅ 通った（`area` / `recast` / `recast_expire` / `training` / `summon` / `summon_wipe` / 引数なし。⚠ **黄は `skill_dbg_dot_odd` の1本だけ＝正解**） |
| 5-3 `skills validated: 61 entries, 0 errors, 1 warnings` | ✅ 通った |
| 6-4 `spawn` の `begin` が2本・`summon_0` / `summon_1` | ✅ 通った（`t=7.38`） |
| 6-5 `x` が `召喚者 − 60` と `− 120` | ✅ **`600.36` に対して `540.36` / `480.36`。等間隔・符号とも一致** |
| 6-6 `src` が `summon_*` の `damage` が1本以上 | ✅ **14本**（`t=7.89` 〜 `10.92`） |
| 6-7 その `amount` が `50`（召喚の atk） | ✅ **全件 `50`。本体（`atk: 1`）の1と数値で区別できている**（決定4の発動者の分離） |
| 6-8 `expire` が `begin` の 4.0 秒後 | ✅ **`7.38` → `11.39` ＝ 4.01 秒**（`is int` で読んでいたら即座に切れていた） |
| 6-9 `expire` のあとに召喚の `damage` が無い | ✅ 通った（最後の1本は `10.92`） |
| 6-10 `heal` が5本・`dst` に召喚2体 | ✅ **`party_0` / `party_1` / `party_2` / `summon_0` / `summon_1`。召喚が味方の母集団に入っている**（§0-1 の7） |
| 6-11 `result` が出ている | ✅ 通った |
| 6-12 味方全滅で `victory: false` | ✅ **`t=7.89` に全滅させ、`t=7.90` に `defeat`**（召喚2体は生きたまま） |
| 6-13 `owner_death` が出ている | ✅ 通った（2本・`t=7.90`） |
| 6-14 `area` の巻き込み数 | ✅ **`narrow`=2 ／ `wide`=4 ／ `far`=4 ／ `heal`=3。段階4と完全一致**（⚠ **召喚が居ないので3のまま**） |
| 6-15 `recast` の段とダメージ | ✅ **`phase` 0/1・`damage` 2/8。段階5と完全一致** |
| 6-16 `area` / `recast` に `spawn` も `kind` も無い | ✅ **0件** |
| 6-17 セーブが変わらない | ✅ **`save_slot_0.json` は存在しないまま** |
| 6-18 壊すと赤が出る | ✅ **§11-2** |

### 11-1. ⚠ 実装中に踏んだこと（**次に走査を足すとき用**）

**① ⚠ `_find_unit()` の複製4本のうち3本が召喚を見つけられなかった**（宿題20が実害になった）。

⚠ **`SkillRuntime` / `SkillResolver` / `StatusRegistry` がそれぞれ `party_units` と
`enemy_units` だけを回す同じ関数を持っていた。** 召喚は `summon_units` に居るので、
⚠ **`cast` の行だけ出て `damage` が1本も出ない**という形で表面化した。

⚠ **エラーは1つも出なかった。** `SkillRuntime._fire()` が user を引けずに黙って帰るだけで、
`cast` は撃つ前に記録されるため、ログ上は「撃ったのに当たらない」に見える。

→ ⚠ **`BattleSession.find_unit()` を1本作り、4本ともそこへ寄せた**（配列を持っている
クラスが探し方も持つ）。⚠ **新しい配列を足したら直すのはこの1本だけ。**

**② ⚠ `results` に `kind` を持つ1件を混ぜると、`log_results()` が `amount: 0` の damage を出す。**
⚠ **表示（`_on_skill_effects_applied`）と記録（`log_results`）の**両方**で先に弾くこと。**
片方だけだと、画面には出ないのに `battle_last.jsonl` にだけ幽霊の行が残る。

**③ ⚠ 後衛の召喚は敵に狙われないので、「狙われる母集団に入っているか」を画面から取れない**（人間の指摘・2026-08-21）。

⚠ **初稿は §7（画面）に「敵が召喚を殴りに来る個体が居ること」と書いていたが、⚠ 検証用データが後衛（`offset_x: -60`）だけなので、召喚は味方より後ろに立ち、`nearest` で最後まで選ばれない。**
→ ⚠ **支援される側から取る形に差し替えた**（`skill_dbg_area_heal` の `heal` が5本＝味方3＋召喚2・§6-1 の10）。⚠ **画面の項目が1つ減り、ログの項目が1つ増えた。**

**④ 内部クラス（`Driver`）から外側の `const` を参照できない。**
⚠ **`PREPARE_*` の値は `debug_boot.gd` の中で2箇所（外側の const と Driver のリテラル）に
分かれたままにしてある**（既存の `"damage_party"` と同じ形）。⚠ **綴りを揃えること。**

### 11-2. ⚠ 足した検証が本当に赤を出すことを確かめた（**無音で通るのが一番怖いため**）

⚠ **検証用データを一時的に壊して3回走らせ、毎回戻した。** ⚠ **本番コードは1行も触っていない。**

| 壊し方 | 出た赤・黄 |
|---|---|
| `count` を消す ／ `duration_sec: 0.0` | ✅ `count が無い`（E94）＋ `duration_sec は 0 より大きいこと`（E95） |
| `unit_id` を `summon_typo` に ／ `host: "spawn"` を足す ／ `offset_x: 0.0` | ✅ `host: 'spawn' は書けない`（E93）＋ `summon の unit_id が summons.json に無い`（E100）＋ **黄** `offset_x が 0`（W13） |
| `summons.json` に `"skills"` を足す | ✅ `'skills' は書けない（段階6では召喚はスキルを撃たない）`（E101） |

⚠ **戻したあと `61 entries, 0 errors, 1 warnings` に戻ることも毎回確認済み。**

### 11-3. ⚠ 設計役がヘッドレスを13回走らせた

⚠ **`godot.log` は保持5本。** ⚠ **この回より前に人間が遊んだぶんの出力パネルは、押し出されて残っていない。**
