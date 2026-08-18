# EXEC — **段階5：`phases[]` / `recast`（再発動・構え型）**

前提は `docs/01_plan/PLAN_SKILL_TEMPLATE.md` 3-2（`phases[]` の形）と 8章（`activation`）。
検証の道具は `docs/02_exec/EXEC_DEBUG_BOOT.md`（`res://tests/debug_boot.tscn`）。

⚠ **この回で本番スキルの挙動は1ミリも変わらない。** 増えるのは器と検証用データだけ。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-18）

| # | 決めたこと | 内容 |
|---|---|---|
| **1** | **`window_sec` 切れ** | ⚠ **そのまま終わる。** 撃った段までで完結し、1段目のダメージは残る。最終段を自動で出さない・巻き戻さない |
| **2** | **入力** | ⚠ **同じスキルボタンをもう一度押す。** ボタンを増やさない |
| **3** | **クールダウン** | ⚠ **1段目のあとに回り始める**（＝ `_fire_skill()` の末尾で回す今の形を変えない） |
| **3-b** | **決定2と3の両立** | ⚠ **構え中だけクールダウンを見ない。** `blocked_reason()` の `cooldown` 判定の前に「構え中なら通す」を1本入れる。⚠ **CDは1段目から回り続けるので、`window_sec` のぶんCDが先食いされる**（最終段のあとにCDが伸びない） |
| **4** | **段の途中で死亡** | ⚠ **構えを捨てる。残りの段は出ない。CDは追加で回さない**（1段目で既に回っているので「何もしない」が答え）。⚠ **復活しても構えは戻らない** |
| **5** | **`phases[]` × `charge`** | ⚠ **同時に書けない。ロード時に赤。** `activation` は軸なので値は1つ。段ごとのチャージ倍率の畳み方が未決定のまま通ると無音でズレる |

---

## 0-1. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め・要確認**）

**この章は人間が目を通していない。違うと思うものがあれば実装前に言うこと。**

| # | 決めたこと | なぜそうしたか |
|---|---|---|
| **1** | ⚠ **段を取り出すのは `SkillSchema.phase_of(skill_data, index)` 1本。** ⚠ **`phases` が無ければ引数をそのまま返す** | ⚠ **「`phases` 省略の既存スキル全件が1ミリも変わらない」を、注意ではなく構造で守るため。** ⚠ **`phases` が無いスキルは複製すら作らず、同じ Dictionary が今までどおりの経路を通る。** 分岐を `_fire_skill` / `blocked_reason` / `cast` の3箇所に書くと、必ず1箇所だけ直す事故になる |
| **2** | ⚠ **`phases` と top-level の `target` / `effects` の同居は赤**（E86） | ⚠ **どちらが効くか実機でしか分からなくなる。** `basic_attack` に `range` を書けなくした理由（射程が2箇所にある状態を作らない）と同じ |
| **3** | ⚠ **段は2つ以上（1段の `phases` は赤）**（E87） | ⚠ **1段の `recast` は `window_sec` が意味を持たない。** 書き手が「省略と同じ」のつもりなのか「2段目を書き忘れた」のかが読めない。⚠ **既定値を作らない方針**（`origin` / `stack` / `scale_from` と同じ） |
| **4** | ⚠ **構えは `BattleUnit` が持つ**（`skill_cooldowns` の隣） | ⚠ **`blocked_reason(user, ...)` が `user` から到達できる必要がある**（3-b）。⚠ **`SkillRuntime` の待ち行列は「効果」の待ちであって「発動」の状態ではない。** 混ぜると「効果を取り消すと構えも消える」が無音で起きる |
| **5** | ⚠ **「構え中か」は `SkillActivation` が自分で見る。引数で渡さない** | ⚠ **`blocked_reason()` は「撃てるかを1箇所で答える」場所**（PLAN 12章）。⚠ **`in_recast: bool` を引数にすると、呼び出し側が判定を持つことになり、集約の決定が形骸化する** |
| **6** | ⚠ **`BattleLog` に `ev: "recast"` を1つ足す**（`begin` / `expire` / `death`） | ⚠ **窓切れ（決定1）と死亡（決定4）は、画面にも `damage` にも何も出ない。** ⚠ **記録が無いと「そのまま終わった」のか「2段目を撃ち損ねた」のかを設計役が区別できない** |
| **7** | ⚠ **`log_cast()` に `phase` を足すが、既定は `-1` で欄を出さない** | ⚠ **既存スキルの `battle_last.jsonl` が1バイトも変わらない**（§4の完了条件をそのまま検証できる） |
| **8** | ⚠ **検証用ステージは `stage_dbg_area` を使い回す。新しいステージを作らない** | ⚠ **1タスク＝1つの通し。** ⚠ **`stage_dbg_*` は既に5件あり、リリース前に消す宿題になっている**（増やすほど片付けが重くなる） |
| **9** | ⚠ **`debug_boot` の改修は `fire` の行に `gap` 欄を足すだけ** | ⚠ **同じ `skill` を2行書けば2回撃つ形に既になっている**（`_fired` はインデックス）。⚠ **足りないのは「2段目を `window_sec` の中で撃つ」ための間隔の上書きだけ**（既定の `FIRE_GAP_SEC=1.0` は窓より長くなりうる） |
| **10** | ⚠ **段ごとの `target` は必須**（省略して1段目を引き継がない）（E90） | ⚠ **引き継ぎを許すと「2段目の対象がどこから来たか」が JSON から読めない。** ⚠ **`effects[].target` の上書きと違い、段は独立した発動**（`cast_id` が別・`BattleLog` の行も別） |

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-18**）

### 1-1. ⚠ 台帳の作業項目が1つ、もう終わっている（**報告済み**）

⚠ **`PLAN_SKILL_TEMPLATE.md` 8章と `NEXT_STEPS.md` §1-1 の「現在は `charge` 欄の有無で分岐している（`battle_controller.gd` 493〜498行）。軸を見る形に変える」は、実コードでは既に済んでいる。**

- `battle_controller.gd:744` に「発動の型は activation を見る。charge 欄の有無で分岐しないこと（PLAN 8章）」のコメント
- `:751` `if activation == SkillSchema.ACTIVATION_CHARGE:`（ゲージ生成）
- `:781` `if activation == ACTIVATION_CHARGE and not charge.is_empty():`（押下/離上の接続）
- ⚠ **台帳が指す 493〜498 行は現在 `_step_deaths()` / `_step_passives()` の周辺で、`charge` と無関係**

→ ⚠ **この回の作業から外す。台帳を直すかは人間の判断**（設計役は勝手に触らない）。

### 1-2. 器の受け皿は既に入っている（**黄を実装に差し替える回になる**）

| 場所 | 今 | この回で |
|---|---|---|
| `skill_schema.gd:28` | `ACTIVATION_RECAST` の定数 | そのまま使う |
| `skill_schema.gd:392-393` | ⚠ **`recast` / `toggle` は「段階5以降。段階1では動かない」の黄** | ⚠ **`recast` だけ黄をやめる。`toggle` は黄のまま残す** |
| `skill_schema.gd:453-454` | ⚠ **`phases` は「段階5。段階1では読まれない」の黄** | ⚠ **黄をやめ、E84〜E91 の検証に差し替える** |
| `skill_schema.gd:250` | `SKILL_FIELDS_KNOWN` に `phases` は入っている | ⚠ **`recast` を足す**（忘れると E26 が全件を赤にする） |

### 1-3. ⚠ 決定を縛っている実コードの事実（**3つ**）

| 事実 | 場所 | この回への影響 |
|---|---|---|
| ⚠ **クールダウンは `_fire_skill()` の末尾で無条件に回る** | `battle_controller.gd:894-898` | ⚠ **決定3をそのまま満たす。ここは動かさない** |
| ⚠ **`blocked_reason()` は `skill_data["target"]` が Dictionary でないと `skill_not_found` を返す** | `skill_activation.gd:45-49` | ⚠ **`phases[]` 型は top-level に `target` が無い。** ⚠ **`phase_of()` を通した辞書を渡さないと、recast スキルが必ず撃てない** |
| ⚠ **発火済みの効果は取り消せない**（取り消せるのは未発火の待ち行列だけ） | `skill_runtime.gd:186-189` のコメント | ⚠ **決定1（巻き戻さない）が器と合っている** |

### 1-4. ⚠ `is_skill_ready()` / `start_cooldown()` は非対称（**触らない**）

`is_skill_ready()` は `skill_ids` と `passive_ids` の両方を見るが、`start_cooldown()` は `skill_ids` だけ（`unit.gd:263-274`）。
⚠ **パッシブにクールダウンを持たせないための意図的な非対称。この回で揃えない。**

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ `phases` 省略の既存スキル全件を1ミリも変えない（**段階1〜4で毎回かけている完了条件**）

⚠ **`phase_of()` が `phases` の無い辞書を「複製せずそのまま返す」形であること。**
⚠ **`duplicate()` して返す形にすると、参照が変わるだけで挙動は同じに見えるが、`fold_charge_ratio()` との組み合わせで無駄な複製が二重になる。**

### 2-2. ⚠ 構えを捨てる経路を数え落とさない

⚠ **状態を消す経路が4本ある形（復活・死亡・ウェーブ交代・reset）で1本ずつ対応して事故った前例がある**（`battle_controller.gd:_step_passives()` のコメント）。
⚠ **構えも同じ。捨てる場所を先に数えてから書くこと**：**①窓切れ ②死亡 ③ウェーブ交代 ④リトライ（`reset`）**。

### 2-3. ⚠ `MasterDataLoader` が返す数値は必ず `float`

⚠ **`window_sec` を `is int` で見ない。** ⚠ **`E69` はこれで9件を誤って赤にしていた**（`CLAUDE.md` 3番）。
⚠ **検証は `_is_num()` を使う**（既存の `charge.just_sec` と同じ形）。

### 2-4. ⚠ 構え中のボタンが押せる状態であること

⚠ **決定2は「同じボタンをもう一度」。** ⚠ **`_update_skill_buttons()` がクールダウン残りでボタンを `disabled` にしていると、判定を通しても押せない**（無音）。
→ ⚠ **`_fire_skill()` を直す前に `_update_skill_buttons()` を読むこと。**

### 2-5. ⚠ 編集したら `grep` で当たったことを確認する

⚠ **`grep -n "phase_of" <ファイル>` が0件でないことを、書いた直後に確認する**（`CLAUDE.md` 2番）。

---

## 3. 実装（ファイル別）

⚠ **インデントはタブ。** ⚠ **関数を足す前に `grep -n "func <名前>"`。**

### 3-0. JSON の形（**決まり**）

```json
"skill_dbg_recast_two": {
	"name_key": "ui_battle_skill_dbg_recast_two",
	"user_character_id": "char_debug_mix",
	"unlock_level": 1,
	"cooldown_sec": 6.0,
	"activation": "recast",
	"recast": { "window_sec": 3.0 },
	"phases": [
		{ "target": { ... }, "effects": [ ... ] },
		{ "target": { ... }, "effects": [ ... ] }
	]
}
```

⚠ **`target` / `effects` を top-level に書かない**（同居は赤・E86）。⚠ **段は2つ以上**（E87）。

### 3-1. `scripts/systems/skill_schema.gd`

**足す定数**：`FIELD_RECAST` / `RECAST_FIELDS_REQUIRED = ["window_sec"]` / `PHASE_FIELDS_KNOWN = ["target", "effects"]`。
**`SKILL_FIELDS_KNOWN` に `"recast"` を足す。**

**足す静的関数（2本）**：

| 関数 | 契約 |
|---|---|
| `phase_count(skill_data) -> int` | `phases` が無ければ **1**。あれば段数 |
| `phase_of(skill_data, index) -> Dictionary` | ⚠ **`phases` が無ければ `skill_data` をそのまま返す**（複製しない）。あれば `target` / `effects` を段のもので差し替え、`phases` を外した**浅い複製**を返す。範囲外の `index` は 0 に丸める |

**検証（E81〜E92）**：

| # | 赤にする条件 |
|---|---|
| E81 | `activation: recast` なのに `recast{}` が無い、または Dictionary でない |
| E82 | `activation` が `recast` 以外なのに `recast{}` がある |
| E83 | `recast.window_sec` が数値でない、または `0.0` 以下 |
| E84 | `activation: recast` なのに `phases` が無い |
| E85 | `phases` があるのに `activation` が `recast` でない |
| E86 | ⚠ **`phases` と top-level の `target` / `effects` が同居している** |
| E87 | `phases` が配列でない、または段が **2つ未満** |
| E88 | `phases[i]` が Dictionary でない |
| E89 | `phases[i]` に知らない欄がある（`target` / `effects` 以外） |
| E90 | `phases[i].target` が無い、または Dictionary でない |
| E91 | `phases[i].effects` が無い、配列でない、または空 |
| E92 | `activation: 'passive'` に `recast` は書けない（既存 E73 の一覧に `"recast"` を足すだけ） |

⚠ **`phases` があるときは、既存の E8（`target` が無い）と E17（`effects` が無い）を top-level に対して走らせない。** 走らせると、正しく書いた recast スキルが必ず2本赤を出す。
⚠ **段の中身は既存の `_validate_target()` / `_validate_effect()` をそのまま呼ぶ**（2本目の検証を書かない）。`activation` は `ACTIVATION_RECAST` を渡す。

**消すもの**：`:392-393` の `recast` の黄（`toggle` は残す）／ `:453-454` の `phases` の黄。

### 3-2. `scripts/systems/unit.gd`

**足す変数**：`var recast_pending: Dictionary = {}`（`skill_id -> {"phase": int, "remaining": float}`）。⚠ **`skill_cooldowns` の隣に置く。**

**足す関数（5本）**：

| 関数 | 契約 |
|---|---|
| `recast_phase(skill_id) -> int` | 構え中なら次に撃つ段の番号。構えていなければ **-1** |
| `begin_recast(skill_id, next_phase, window_sec) -> void` | 構えを立てる／上書きする |
| `clear_recast(skill_id) -> void` | 1つ捨てる |
| `clear_all_recast() -> Array` | 全部捨て、捨てた `skill_id` を返す（ログ用） |
| `tick_recast(delta) -> Array` | `remaining` を減らし、**0以下になった `skill_id` を捨てて返す**（決定1） |

⚠ **`tick_cooldowns()` と同じく `Dictionary` を回しながら消さないこと**（GDScript は回している最中の erase で壊れる）。⚠ **消す ID を一度配列に集めてから消す。**

### 3-3. `scripts/systems/skill_activation.gd`

`REASON_COOLDOWN` の判定を、**構え中はスキップする**（決定3-b）。

```gdscript
# ⚠ 構え中（recast の2段目以降）はクールダウンを見ない。
#    1段目で既にCDが回っており、見ると同じボタンでの再発動が必ず弾かれる。
if user.recast_phase(skill_id) < 0 and not user.is_skill_ready(skill_id):
	return REASON_COOLDOWN
```

⚠ **引数を足さない**（§0-1 の5）。⚠ **判定の順番を変えない**（`no_target` は最後のまま）。

### 3-4. `scenes/adventure/battle_controller.gd`

**`_fire_skill()`**（`:879`）：

1. `var phase_index: int = maxi(user.recast_phase(skill_id), 0)`
2. `var phase_data: Dictionary = SkillSchema.phase_of(skill_data, phase_index)`
3. `blocked_reason(user, skill_id, phase_data, _session)` に **`phase_data` を渡す**（`skill_data` ではない）
4. `_skill_runtime.cast(user, skill_id, phase_data, power_ratio)`
5. ⚠ **`start_cooldown()` は `phase_index == 0` のときだけ**（決定3）
6. 次の段があれば `begin_recast(skill_id, phase_index + 1, window_sec)`、無ければ `clear_recast(skill_id)`

⚠ **状態を変えるのは3の判定を通したあとだけ**（`CLAUDE.md` 6番）。

**`_process()`**（`:410` / `:413` の隣）：`unit.tick_recast(delta)` を呼び、返ってきた `skill_id` を `BattleLog` に `expire` で出す。
**`_resolve_one_death()`**：`u.death_handled = true` の直後に `u.clear_all_recast()`（ログは `death`）。
**ウェーブ交代・リトライ**：`_skill_runtime.clear_all()` / `reset()` を呼んでいる場所で、全ユニットの `clear_all_recast()` も呼ぶ（§2-2 の③④）。
**`_update_skill_buttons()`**：⚠ **構え中はボタンを `disabled` にしない**（§2-4）。

### 3-5. `scripts/systems/battle_log.gd`

- `log_cast(unit_id, skill_id, target_ids, phase: int = -1)` … ⚠ **`phase < 0` なら欄を出さない**（§0-1 の7）
- `log_recast(unit_id, skill_id, phase, why)` … `ev: "recast"`。`why` は `begin` / `expire` / `death`

### 3-6. 検証用データ（**2ファイル。⚠ 片方だけでは動かない**）

**`resources/balance/master/characters/char_debug_mix/skills.json`** … `skill_dbg_recast_two` を1件。
**`resources/balance/master/characters.json`** … ⚠ **`char_debug_mix` の `skills[]`（候補一覧）にも足す。**

⚠ **候補一覧が正で、`skills.json` に足すだけでは `select_skill()` が `is not a candidate` で弾く**（`game_manager.gd:2129`）。⚠ **実装中に実際に踏んだ**（§7-11）。

⚠ **段で `multiplier` を変える**（1段目 `2.0` / 2段目 `8.0`）。⚠ **`attack_type` は `true`。**
⚠ **理由：`damage` の数値だけで「どちらの段が出たか」を `battle_last.jsonl` から読めるようにするため。** ⚠ **`physical` では敵の `def` で両段とも `amount: 1` に潰れて区別できない**（実測・§7-11）。

`window_sec: 3.0` ／ `cooldown_sec: 6.0`（窓より長い＝窓の中で撃てるのは再発動だけ、を保証する）。

### 3-7. `localization/ja.csv`

`ui_battle_skill_dbg_recast_two,再発動テスト` を1行。⚠ **UTF-8（BOMなし）。編集後の再インポートは人間の作業。**

### 3-8. `tests/debug_boot.gd`

- `fire` の行に **`gap` 欄**（省略時は `FIRE_GAP_SEC`）。⚠ **`_step_fire()` の `FIRE_GAP_SEC` 参照を、行の `gap` があればそちらに差し替える**
- シナリオ **`recast`**：`stage_dbg_area`／`fire` に `skill_dbg_recast_two` を **2行**（2行目は `gap: 0.5`）
- シナリオ **`recast_expire`**：同じスキルを **1行だけ**。⚠ **撃ったあと窓が切れるのを待つ**（`SETTLE_SEC` のあと `debug_kill_all_enemies()` が走るので、`window_sec: 3.0` を待つには**撃ち終わりの待ちを行の `gap` で伸ばす**か、`fire` に「何もしない待ち」の行を1つ足す）

⚠ **シーンを増やさない。`SCENARIOS` に2行足すだけ。**

### 3-9. 触らないファイル

⚠ **`scripts/systems/skill_resolver.gd`（段を知らないままにする。時間も段も知らないのが契約）／ `status_registry.gd` ／ `skill_runtime.gd`**
⚠ **本番スキルの JSON 全件 ／ `stages.json` ／ `project.godot` ／ `addons/`**

---

## 4. 変えないもの

- ⚠ **`phases` 省略のスキル全件の挙動**（本番の全件。§2-1）
- ⚠ **`charge` の挙動**（`skill_wide_sweep` の1件）
- ⚠ **`activation: toggle` の黄**（段階5では実装しない）
- ⚠ **`is_skill_ready()` / `start_cooldown()` の非対称**（§1-4）
- ⚠ **`stage_dbg_area` と `skill_dbg_area_*`**（段階4の検証用データ）
- ⚠ **`SkillResolver` の契約**（時間を知らない・段を知らない）

---

## 5. 完了条件 — **§0 事前チェック**（⚠ **設計役・ヘッドレス。人間の仕事は無い**）

⚠ **人間に渡す前に、設計役が全シナリオを1回ずつ回す**（前回ここを守らず赤を踏んだ・`EXEC_DEBUG_BOOT.md` §7-12）。

1. ⚠ **引数なしで起動すると、シナリオ一覧に `recast` と `recast_expire` が出て `exit=0` で終わること**
2. ⚠ **stderr に `ERROR:` / `SCRIPT ERROR:` / `Parse Error` が1行も出ないこと**（全シナリオ：`area` / `training` / `recast` / `recast_expire` / 引数なし）
3. ⚠ **`skills validated: 60 entries, 0 errors, 1 warnings` が出ること**（⚠ **59 → 60 は `skill_dbg_recast_two` の1件ぶん。黄1本は `skill_dbg_dot_odd` の端数＝出るのが正解**）

## 6. 完了条件 — **ログ / ファイル**（⚠ **設計役が読む**）

### 6-1. `-- scenario=recast`（**2段とも撃つ**）

4. ⚠ **`cast` の行が `skill_dbg_recast_two` で2本出て、`phase` が `0` と `1` であること**
5. ⚠ **`recast` の行が `why: "begin"` で1本出ていること**（1段目の直後）
6. ⚠ **`recast` の行に `why: "expire"` が1本も無いこと**（窓の中で撃てた）
7. ⚠ **2本の `cast` の `damage` の値が違うこと**（1段目 `multiplier 2.0` ／ 2段目 `8.0`。⚠ **同じなら段が差し替わっていない**）
8. ⚠ **`result` の行が出ていること**（途中で切れていない）

### 6-2. `-- scenario=recast_expire`（**1段目だけ撃つ**）

9. ⚠ **`cast` の行が `skill_dbg_recast_two` で1本だけ、`phase: 0` であること**
10. ⚠ **`recast` の行が `why: "begin"` → `why: "expire"` の順で出ていること**（決定1）
11. ⚠ **`expire` の `t` が `begin` の `t` より `window_sec`（3.0）ぶん後であること**（⚠ **`is int` で読んで即座に切れる事故＝§2-3 がここで出る**）
12. ⚠ **`expire` のあとに `skill_dbg_recast_two` の `cast` が1本も無いこと**（構えが残っていない）

### 6-3. `-- scenario=area`（**既存が1ミリも変わっていないこと**）

13. ⚠ **`cast` の行に `phase` の欄が1つも無いこと**（§0-1 の7）
14. ⚠ **巻き込んだ数が段階4の実測と一致すること**：`narrow` **2** ／ `wide` **4** ／ `far` **4** ／ `heal` の `heal` 行 **3**

### 6-4. セーブ

15. ⚠ **`save_slot_0.json` が走らせる前と1バイトも変わらないこと**（`debug_boot` は保存しない）

## 7. 完了条件 — **画面**（⚠ **人間。窓ありで1回だけ**）

⚠ **ヘッドレスでは分からないものだけ。** ⚠ **合図で書く。時間で書かない。**

16. ⚠ **`skill_dbg_recast_two` のボタンを押すと1段目が出て、そのボタンの表示が `▶3.0` の形（残りの窓）に変わり、押せる状態のままであること**（§2-4。⚠ **`(6.0)` のようなカッコ付きになって押せなくなっていたら、構えが立っていない**）
17. ⚠ **`▶` が出ているあいだに同じボタンをもう一度押すと、2段目のダメージ数値が1段目より大きく出ること**
18. ⚠ **2段目を押さずに待つと、表示が `▶` からカッコ付きのクールダウン表示に変わり、押せなくなること**（＝構えが切れた）
19. ⚠ **2段目を撃ったあと、クールダウンの残りが「6秒」ではなく「6秒 − 構えていた時間」から始まること**（決定3-b。⚠ **押した瞬間に6.0に戻るなら、CDを最終段で回している＝決定3に反する**）

---

## 7-10. ⚠ 実施結果（**2026-08-18・設計役がヘッドレスで実行して判定**）

⚠ **§5・§6 は全部通った。§7（画面）は未実施＝人間の担当。**

| 項目 | 結果 |
|---|---|
| 5-1 一覧に `recast` / `recast_expire` が出て `exit=0` | ✅ 通った |
| 5-2 全シナリオで stderr に赤が1行も無い | ✅ 通った（`area` / `training` / `recast` / `recast_expire` / 引数なし。⚠ **黄は `skill_dbg_dot_odd` の1本だけ＝正解**） |
| 5-3 `skills validated: 60 entries, 0 errors, 1 warnings` | ✅ 通った |
| 6-4 `cast` が2本・`phase` が `0` と `1` | ✅ 通った（`t=7.38` / `t=7.89`） |
| 6-5 `recast` の `why: "begin"` が1本 | ✅ 通った（`phase:1`・`t=7.38`） |
| 6-6 `expire` が1本も無い | ✅ 通った |
| 6-7 2本の `damage` の値が違う | ✅ 通った（**2 と 8**） |
| 6-8 `result` の行が出ている | ✅ 通った |
| 6-9 `cast` が1本・`phase: 0` | ✅ 通った |
| 6-10 `begin` → `expire` の順 | ✅ 通った |
| 6-11 `expire` が `begin` の `window_sec` ぶん後 | ✅ **`7.39` → `10.39` ＝ ちょうど 3.00 秒**（⚠ **`is int` で読んでいたら即座に切れていた。E69 の形をここで潰せている**） |
| 6-12 `expire` のあとに `cast` が無い | ✅ 通った |
| 6-13 `area` の `cast` に `phase` 欄が1つも無い | ✅ 通った（0件） |
| 6-14 巻き込んだ数が段階4と一致 | ✅ **`narrow`=2 ／ `wide`=4 ／ `far`=4 ／ `heal`=3。完全一致** |
| 6-15 セーブが変わらない | ✅ **`save_slot_0.json` は存在しないまま**（`debug_boot` は1度も書いていない） |

**所要：1シナリオ 13〜17 秒。**

### 7-11. ⚠ 実装中に踏んだこと（**次に検証用スキルを足すとき用**）

**① ⚠ 検証用スキルは `characters.json` にも足さないと枠に入らない。**
`skills.json` に足しただけでは `select_skill()` が `skill '...' is not a candidate of '...'` で弾き、
⚠ **`debug_boot` が「スキルを持っているユニットが居ない」の赤を出す**（`game_manager.gd:2129`。候補一覧が正）。
→ ⚠ **EXEC §3-6 が `skills.json` しか書いていなかった。2ファイルに直した。**

**② ⚠ `attack_type: physical` では段の違いが数値に出ない。**
初稿は `multiplier` を `0.5` / `2.0` にしたが、⚠ **敵の `def` で両段とも `amount: 1` に潰れた。**
⚠ **「倍率を変えたのだから数値も変わるはず」は成り立たない。** → `attack_type: "true"` ＋ `2.0` / `8.0` に変えた。

**③ ⚠ `_update_skill_buttons()` は CD残りでボタンを `disabled` にしていた**（`:878`）。
⚠ **§2-4 で警戒していたとおり。** 直さなければ、判定を通しても構え中のボタンが押せず**再発動が無音でできない**状態だった。
→ 構え中は `disabled` にせず、残りの窓を `▶3.0` の形で出す。

**④ ⚠ `kind: screen` のシナリオはヘッドレスで `quit()` しない**（画面を開いたままぶら下がる）。
⚠ **`--quit-after 300` を付けて回した。** ⚠ **判定には使っていない**（`training` は jsonl を見ないシナリオなので §2-6 の罠に当たらない）。

### 7-12. ⚠ 足した検証が本当に赤を出すことを確かめた（**無音で通るのが一番怖いため**）

⚠ **検証用データを一時的に壊して2回走らせ、毎回戻した。** ⚠ **本番コードは1行も触っていない。**

| 壊し方 | 出た赤 |
|---|---|
| `recast` を `recastXX` に改名 | ✅ `activation: recast なのに recast{} が無い`（E81）＋ `知らない欄がある: 'recastXX'`（E26） |
| `window_sec: 0.0` ／ 段に `targt` を足す | ✅ `recast.window_sec は 0 より大きいこと`（E83）＋ `phases[1] に知らない欄がある: 'targt'`（E89・**段の位置つきで出る**） |

⚠ **戻したあと `60 entries, 0 errors, 1 warnings` に戻ることも確認済み。**

### 7-13. ⚠ 設計役がヘッドレスを8回走らせた

⚠ **`godot.log` は保持5本。** ⚠ **この回より前に人間が遊んだぶんの出力パネルは、押し出されて残っていない。**

---

## 8. 将来コードを変えたときに見る項目（**UIから到達できない・人間の確認項目にしない**）

- `phases` に段を3つ書いたときに3段とも撃てるか（今のデータは2段だけ）
- `activation: recast` の敵スキル（`_try_enemy_skill()` は `_fire_skill()` を通るので通るはずだが、利用者ゼロ）
- ウェーブ交代・リトライで構えが捨てられるか（§2-2 の③④。⚠ **`stage_dbg_area` は1ウェーブなので実測できない**）

---

## 9. Ziva に渡せる部分

⚠ **無い。**

⚠ **JSON と `ja.csv` だけで完結する部分が無いため。** `skill_dbg_recast_two`（§3-6）と `ja.csv` の1行（§3-7）は JSON と CSV だけだが、⚠ **`skill_schema.gd` の E84〜E91 が入る前に足すと、ロード時に赤が11本出る**（`phases` が読めないため）。⚠ **順番が縛られているので分割しない。**

---

## 10. 終わったあとに足す宿題（`PROJECT_STATUS.md`。⚠ **書き換えるかは人間の判断**）

- ⚠ **NEW：`activation: toggle` は黄のまま**（段階5では実装しない）
- ⚠ **NEW：構えを捨てる経路が4本ある**（窓切れ・死亡・ウェーブ交代・リトライ）。⚠ **5本目を作るときは4本全部を見直す**
- ⚠ **NEW：`phases` の段ごとに `charge` を書けない**（決定5）。⚠ **必要になったら「段ごとの倍率の畳み方」を先に決める**
- ⚠ **NEW：構え中の見た目が無い**（ボタンの色も残り窓のゲージも出ない。⚠ **段階3の「見た目」の宿題と同じ枠**）
- ⚠ **既存：台帳の「`charge` 欄の有無で分岐している」が実コードと違う**（§1-1）
- ⚠ **既存：検証用のものはリリース前に消す**（`skill_dbg_recast_two` も対象）
