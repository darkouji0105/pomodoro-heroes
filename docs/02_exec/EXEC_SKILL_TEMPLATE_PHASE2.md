# EXEC_SKILL_TEMPLATE_PHASE2.md — 実行中のスキル層と `trigger`（段階2）

**第3層。決定台帳は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`（6章・7章・19章・20章がこの回の本体）。**

**この回で「多段」と「遅延」が書けるようになる。**

⚠ **段階1と違い、「挙動が1件も変わらない」だけでは足りない。** 新層が実際に動いていることを目で見る必要がある。**土台は「既存17スキルの数字が変わらない」、本体は「速射が2連射に見える」。**

---

## 1. 人間による決定事項（2026-08-16・**本文と矛盾する場合こちらが優先**）

### 1-1.【体制】設計役が全部書く。MiniMax（実装役）は使わない

**直近6タスクと同じ。PRE_PLAN も IMPL_LOG も作らない。**
⚠ **`battle_controller.gd` は915行。途中の書き換えは設計役が全文を書く。**

### 1-2.【決定】タイムアウトしたら**発火させる ＋ `push_warning`**

**PLAN 21章の未決だったもの。** 遅れてでもダメージは出す。**無音で消える形を作らない。**

### 1-3.【決定】新層は `scripts/systems/skill_runtime.gd` / `class_name SkillRuntime`

**新しいフォルダは作らない。**

### 1-4.【決定】`charge_start` を段階2で実装する

`_on_charge_button_down()` から新層に流す。⚠ **利用者はゼロのまま**（本命の用途「チャージ中の軽減」は状態＝段階3）。

### 1-5.【決定】`delay` の検証は**実スキル**で行う。検証用の一時データを足さない

**`skill_rapid_volley`（速射）を「2体同時」から「2体 × 2連射」に書き換える。**

⚠ **「1体に2連射」にするか「2体 × 2連射」にするかは保留。** 既定は**2体 × 2連射**（`count: 2` の利用者が残り、`delay` と両方を1スキルで検証できる）。変えるのは `skills.json` の1箇所。

### 1-6.【決定】中断したら待ち行列を**捨てる。`push_warning` は出さない**

**ウェーブ交代・勝敗確定・使用者の死。** 起きて当然のことなので正常系。

⚠ **決定1-2 と衝突しない。別物。**

| | 何が起きた | 扱い |
|---|---|---|
| **タイムアウト** | 合図が来るはずなのに来ない＝**異常** | **発火させる ＋ `push_warning`** |
| **中断** | 起きて当然＝**正常** | **捨てる。警告なし** |

### 1-7.【決定】種別タグの出どころは `effects[].delivery`（**新設**）

`melee` / `projectile` / `magic`。**省略時 `melee`。**

**PLAN 6-8 が「待ち行列の要素に種別タグ」を要求しているが、値の出どころが決まっていなかった。**
⚠ **`attack_type` は流用できない**（あれは「どの防御で受けるか」であって、送り方ではない・PLAN 5-2-1）。

**箱だけ作って値を固定にしない。** 弓兵の7効果に `projectile`、僧侶の魔法4効果に `magic` を実際に書く。**段階3の「飛び道具の無効化」（効果 `cancel`）がそのまま書ける状態にする。**

---

## 2. 触るファイルと担当

| ファイル | 何をする | 誰が |
|---|---|---|
| `scripts/systems/skill_runtime.gd` | **新規**（この回の本体） | AI |
| `scripts/systems/skill_resolver.gd` | `resolve()` の入口を作り替える（§5） | AI |
| `scripts/systems/skill_schema.gd` | `delivery` の語彙と検証・`trigger` の警告条件（§6） | AI |
| `scenes/adventure/battle_controller.gd` | ⚠ **915行。触るのは8箇所だけ**（§7） | AI |
| `resources/balance/master/skills.json` | 速射を2連射に・`delivery` を11効果に書く（§8） | AI |
| 実機確認（§11-B） | | ⚠ **人間** |

**`.tscn` `.tres` `ja.csv` は触らない。** 新しい翻訳キーは増えない。

---

## 3. 着手前に確認した実コード（2026-08-16・`grep` 済み）

| | 事実 |
|---|---|
| `skill_resolver.gd` | **459行**。`select_targets()` / `resolve()` / `fold_charge_ratio()` |
| `resolve()` の呼び出し元 | ⚠ **`battle_controller.gd` 606行の1箇所だけ**（この回で新層に移る） |
| `select_targets()` の呼び出し元 | `skill_activation.gd` 49行 と `resolve()` 214行 |
| `resolve()` の戻り値 | `{ "unit_id", "amount", "is_heal", "is_crit" }` の配列 |
| `resolve()` が今 `trigger` を見ている場所 | **188〜191行**。`cast` 以外を `push_warning` して飛ばす。⚠ **この回で消す**（新層が持つ） |
| `skill_schema.gd` | **382行**。`_is_trigger_shape()` は 362〜369行。W5（`trigger` の警告）は 311〜312行 |
| `battle_controller.gd` | **915行** |
| `_process()` | **292〜330行**。`_tick_charge` → `_update_skill_buttons` → `_result_applied`で return → 状態ガード → CD → 対象再選択 → 攻撃/移動 → 勝敗判定 |
| `_fire_skill()` | **591〜617行** |
| `_on_charge_button_down()` | **624〜635行**。最後に `_charging = {"entry": entry, "time": 0.0}` |
| `_enter_wave_clear()` | **727〜736行**。⚠ **`_reset_party_positions()` で味方が左端へ瞬間移動する** |
| `_enter_victory()` / `_enter_defeat()` | 739行 / 784行。どちらも `_cancel_charge()` を呼んでいる |
| ⚠ **`_on_retry_pressed()`** | **815〜830行**。`_init_session()` が **`BattleSession` を作り直す**（829行） |
| 敵の `unit_id` | `"enemy_%d_%d" % [current_wave, local_index]`（258行）。⚠ **ウェーブ番号が入るので次のウェーブと衝突しない** |
| 座標が動く場所 | ⚠ **`_step_unit()` の390〜391行の1箇所だけ**。スキルは座標を動かさない |
| ユニットの死 | `take_damage()` の中で `hp` が 0 になるだけ。⚠ **死亡を知らせるシグナルは無い** |
| ロード時検証のログ | `[MasterDataLoader] skills validated: 18 entries, 0 errors, 0 warnings` ⚠ **これが唯一の `print`** |

---

## 4. 新規：`scripts/systems/skill_runtime.gd`

### 4-1. 位置づけ

```
battle_controller   … 入力と表示だけ
       ↓ cast() を1回呼ぶ
SkillRuntime(新層)  … 待ち行列。trigger・タイムアウト・中断・演出シーンとの往復
       ↓ 「今この瞬間・この効果・この対象」
SkillResolver       … 1つの効果を確定した対象に当てる。時間を知らない
```

- **`RefCounted` 派生。`static` にしない**（状態＝待ち行列を持つため）
- **`BattleController` が1体だけ持つ。** ノードツリーに入れない
- ⚠ **`SkillResolver` の契約は変えない**（PLAN 7-3）。**時間を持たず、次のフレームを知らず、ノードを触らない**
- ⚠ **新層はビューを知ってよい。** 今回は `effects_applied` シグナルで結果を投げるところまで

### 4-2. ⚠ 待ち行列は**1本**（PLAN 6-8・**後から変えられない**）

> **`_pending: Array` を1本だけ持つ。スキルごとの private な待ち行列を作らない。**

**中断は「自分で自分を捨てる」だけなので private でも成立してしまう。** 気づかずに閉じた作りにしやすい。
**外から参照・取り消しできる形にしておくと、段階3の `cancel`（飛び道具の無効化）と詠唱中断が同じ操作で開く。**

### 4-3. 待ち行列の要素

```
{
	"cast_id": int,          # 1回の発動を識別する。同じ発動の残りをまとめて捨てるのに使う
	"user_id": String,       # ⚠ 参照ではなく ID（PLAN 4-4）
	"skill_id": String,      # 警告メッセージに出す
	"effect": Dictionary,    # チャージ倍率を畳み込み済みの効果1つ
	"target_ids": Array,     # ⚠ cast 時に確定。以降選び直さない（PLAN 4-4）
	"delivery": String,      # 種別タグ（決定1-7）
	"wait": String,          # "delay" / "event"
	"remaining": float,      # delay の残り秒 ／ event のタイムアウト残り秒
	"event_name": String,    # wait == "event" のときだけ
}
```

⚠ **`target_ids` を cast 時に確定させるのがこの回の肝。** 発火時に選び直すと、**多段の2発目が「生きている別の敵」に吸われる**（PLAN 4-4）。

### 4-4. 定数

```
const WAIT_DELAY: String = "delay"
const WAIT_EVENT: String = "event"

# 合図が来ないまま何秒待つか。⚠ 演出シーンが存在しないので、今は event: を
# 書いたスキルが無い＝この値は実戦で使われない。
const EVENT_TIMEOUT_SEC: float = 5.0
```

### 4-5. 公開する関数

| 関数 | 何をするか |
|---|---|
| `_init(p_session: BattleSession)` | セッションを受け取る |
| **`reset(p_session: BattleSession) -> void`** | ⚠ **待ち行列を捨てて、セッションを差し替える。リトライ用**（§7-8の罠） |
| `cast(user, skill_id, skill_data, power_ratio) -> void` | 発動1回ぶん。効果を待ち行列に置き、`cast` のものは即発火 |
| `charge_start(user, skill_id, skill_data) -> void` | `trigger: "charge_start"` の効果だけを即発火 |
| `tick(delta: float) -> void` | 中断の掃除 → 時間を進める → 発火 |
| **`notify_event(cast_id: int, event_name: String) -> void`** | ⚠ **受け口だけ。呼び出し元ゼロ**（アニメが無い） |
| `cancel_for_user(unit_id: String) -> int` | その使用者の残りを捨てる。捨てた件数を返す |
| **`cancel_by_delivery(delivery: String) -> int`** | ⚠ **受け口だけ。段階3の `cancel` が使う** |
| `clear_all() -> int` | 全部捨てる。ウェーブ交代・勝敗確定 |
| `pending_count() -> int` / `pending_snapshot() -> Array` | 外から見える（PLAN 6-8） |

**シグナル**：`signal effects_applied(results: Array)` — `resolve()` の戻り値をそのまま流す。`battle_controller` が `_pop_damage()` する。

### 4-6. ⚠ 発火の経路は**1本**（PLAN 6-5・**ここが一番重要**）

```
cast()          … trigger: "cast"        ──┐
tick()          … trigger: "delay:0.35"  ──┼→ _fire(entry) → SkillResolver.resolve()
notify_event()  … trigger: "event:hit1"  ──┤
charge_start()  … trigger: "charge_start"──┘
```

> **`_fire(entry)` は1本しか作らない。** アニメが入るときに足すのは `notify_event()` を呼ぶ側だけで、**新層の構造も JSON の形も `SkillResolver` も変わらない。**

⚠ **段階2を「タイマー専用」で作ってはならない。** `tick()` が `_fire()` を呼ぶのであって、`_fire()` が時間を知ってはならない。

### 4-7. `cast()` の中身

1. `effective = SkillResolver.fold_charge_ratio(skill_data, power_ratio)`
2. `cast_id` を1つ発番する
3. `effective["effects"]` を**先頭から順に**回す：
   - `trigger` が `charge_start` の効果は**飛ばす**（`charge_start()` の担当）
   - 対象の定義は「効果ごとの `target` 上書き」→ 無ければ「スキルの `target`」
   - ⚠ **ここで `SkillResolver.select_targets()` を呼び、`target_ids` を確定させる**
   - `delivery` は `effect.get("delivery", SkillSchema.DELIVERY_MELEE)`
   - `cast` → **その場で `_fire()`**（待ち行列に積んでから次のフレームで、にしない。ダメージの表示が1フレーム遅れ、勝敗判定の順序も変わる）
   - `delay:N` → `wait = "delay"`, `remaining = N`、待ち行列へ
   - `event:X` → `wait = "event"`, `remaining = EVENT_TIMEOUT_SEC`, `event_name = X`、待ち行列へ
   - それ以外 → `push_error`（ロード時検証が守っているが二重に）

⚠ **`target_ids` が0件でも待ち行列に積む。** 空振りは正常系（PLAN 4-2）。積まないと `pending_count()` が実態と合わなくなる。

⚠ **`delay:N` の N は文字列から取り出す。`is_valid_float()` → `float()` の順**（`SkillSchema._is_trigger_shape()` と同じ判定）。

### 4-8. `tick()` の中身（**順番が要件**）

```
1. 中断の掃除 … _pending から「使用者が死んでいる／居ない」要素を捨てる（⚠ 警告を出さない・決定1-6）
2. 時間を進める … remaining -= delta
3. remaining <= 0 の要素を、待ち行列の順のまま取り出す
4. 取り出した要素を順に _fire()
```

⚠ **3と4を分ける。** 回しながら消すと順番が飛ぶ。
⚠ **`wait == "event"` の要素が時間切れになったときだけ `push_warning`**（決定1-2）。`"delay"` は時間が来て発火するのが正常なので警告しない。

**⚠ ユニットの死を知らせるシグナルが無いので、中断は毎フレームの走査で行う。** 要素は多くても数件なので速度は問題にならない。

### 4-9. `_fire(entry)` の中身

1. `user = _find_unit(entry.user_id)`。居ない／死んでいるなら**何もしないで戻る**（1で掃除済みのはず。二重に守る）
2. ⚠ **`SkillResolver` に渡す実効スキルデータは `{ "effects": [entry.effect] }` だけ**
   - **PLAN 7-3 の歯止め**：*実効スキルデータは `skills.json` に書ける欄しか含んではならない*。`effects` は書ける欄なので守れている
   - ⚠ **`target_ids` を skill_data の中に入れてはならない。** 引数として横から渡す（§5）
3. `results = SkillResolver.resolve(one, user, _session, entry.target_ids)`
4. `results` が空でなければ `effects_applied` を発火

### 4-10. `charge_start()` の中身

`trigger == "charge_start"` の効果だけを、`select_targets()` して**即 `_fire()`**。

⚠ **`fold_charge_ratio()` を通さない。** チャージ開始時点では倍率が存在しない（＝ `power_ratio` は 1.0）。
⚠ **チャージを途中でやめても、既に発火した効果は戻らない。** 本命の用途（チャージ中の軽減）は**状態＝段階3**なので、この回の利用者はゼロ。

### 4-11. `notify_event()` の中身（⚠ **呼び出し元ゼロ**）

`wait == "event"` かつ `cast_id` と `event_name` が一致する要素を、待ち行列から取り出して `_fire()`。

⚠ **この関数を「あとで書く」にしないこと。** ここが空だと `tick()` が唯一の発火経路になり、**新層が「時間で進むもの」になる**（PLAN 6-5 が禁じている形そのもの）。

---

## 5. `scripts/systems/skill_resolver.gd`（**入口2つのまま。`resolve()` の引数が1つ増える**）

### 5-1. 変える1点

```gdscript
static func resolve(
        skill_data: Dictionary, user: BattleUnit, session: BattleSession, target_ids: Array
) -> Array:
```

**`target_ids` は必須。** 既定値を作らない。

⚠ **なぜ引数で渡すのか**：**対象は cast 時に確定する**（PLAN 4-4）。`resolve()` の中で `select_targets()` を呼び直すと、**多段の2発目が別人に当たる。**

⚠ **契約は無傷**（PLAN 7-3）：**時間を持たず・次のフレームを知らず・ノードを触らない**。どれも変わっていない。**入口も2つのまま**（`select_targets()` / `resolve()`）。

⚠ **歯止めも無傷**：IDは `skill_data` の**外**を通る。`skill_data` に `skills.json` に書けない欄は1つも入らない。

### 5-2. `resolve()` の中で消すもの・残すもの

| | どうする |
|---|---|
| **188〜191行の `trigger` チェック**（`cast` 以外を `push_warning` して飛ばす） | ⚠ **消す。** `trigger` は新層が持つ。ここに残すと**2箇所で解釈することになり、必ずズレる** |
| **193〜196行の `host` チェック** | **残す**（段階3） |
| 214行の `select_targets()` 呼び出し | ⚠ **消す。** 引数の `target_ids` を使う |
| 効果ごとの `target` 上書きを読む処理（201〜212行） | ⚠ **消す。** cast 時に新層が解釈済み |
| `chance` の警告 | 残す |

### 5-3. ⚠ 効果が2つ以上来たら警告する

```
段階2以降、resolve() は「1つの効果」を解く。新層が effects を1件ずつに割って渡す。
2件以上来たら、割り忘れか、新層を通さずに呼ばれている。
```

**`effects` の要素数が1でなければ `push_warning`。** 処理は続ける（全効果に同じ `target_ids` を当てる）。

### 5-4. 触らないもの

**`select_targets()` / `_sorted_units()` / `_apply_damage()` / `_apply_heal()` / `_scale_value_sum()` / `fold_charge_ratio()` は1行も変えない。**

⚠ **特に `_apply_damage()` の2段構え**（PLAN 11-0・後から変えられない）**と、`roll_crit()` を対象1体につき1回振る順番を変えないこと。**

---

## 6. `scripts/systems/skill_schema.gd`

### 6-1. `delivery` の語彙を足す（決定1-7）

```
# --- effects[].delivery（どう届くか。待ち行列の種別タグ・PLAN 6-8）---
# ⚠ attack_type（どの防御で受けるか）とは別物。混ぜないこと。
const DELIVERY_MELEE: String = "melee"
const DELIVERY_PROJECTILE: String = "projectile"
const DELIVERY_MAGIC: String = "magic"
const DELIVERIES_KNOWN: Array = [DELIVERY_MELEE, DELIVERY_PROJECTILE, DELIVERY_MAGIC]
```

**検証（E28）**：`_validate_effect()` に足す。**書いてあって値が不明なら赤。省略は許す（＝ `melee`）。**

⚠ **`SKILL_FIELDS_KNOWN` は触らない。** あれはスキル直下の欄の一覧で、効果の欄には未知欄チェックが無い。

### 6-2. `trigger` の警告条件を変える（**311〜312行**）

**今**：`cast` 以外は全部「段階2。段階1では飛ばされる」と黄。
**これから**：**`event:` で始まるものだけ黄。**

```
`cast` / `charge_start` / `delay:<数値>` … 警告なし（段階2で実装した）
`event:◯◯`                              … 黄「合図を出す側が居ない（アニメ未実装）。
                                              タイムアウトで発火する」
```

⚠ **これを直さないと、速射に `delay:0.35` を書いた瞬間にロード時の警告が1件出て、完了条件 A-1 の「0 warnings」が崩れる。**

---

## 7. `scenes/adventure/battle_controller.gd`（⚠ **915行。触るのは8箇所だけ**）

| # | 場所 | 何をする |
|---|---|---|
| **7-1** | 変数宣言（60行の `_charging` の下） | `var _skill_runtime: SkillRuntime = null` を足す |
| **7-2** | `_ready()`（92行 `_session = BattleSession.new(...)` の直後） | 新層を作り、`effects_applied` を `_on_skill_effects_applied` に繋ぐ |
| **7-3** | `_process()`（**322行の攻撃/移動ループの後・324行の勝敗判定の前**） | `_skill_runtime.tick(delta)` を1行 |
| **7-4** | `_fire_skill()`（591〜617行） | `resolve()` → `_pop_damage()` のループを **`_skill_runtime.cast(...)` の1行**に置き換える |
| **7-5** | 新規メソッド | `_on_skill_effects_applied(results: Array) -> void` … 今の607〜611行のループをそのまま移す |
| **7-6** | `_on_charge_button_down()`（635行 `_charging = {...}` の直後） | `_skill_runtime.charge_start(user, skill_id, skill_data)` |
| **7-7** | `_enter_wave_clear()` / `_enter_victory()` / `_enter_defeat()` | `_skill_runtime.clear_all()` |
| **7-8** | `_init_session()`（829行 `_session = BattleSession.new(...)` の直後） | ⚠ **`_skill_runtime.reset(_session)`** |

### 7-3 の位置がなぜそこか

```
CD → 対象再選択 → 攻撃/移動 → 【ここで tick】 → 勝敗判定
```

- **勝敗判定より前**：遅延で入った止めの一撃が、**同じフレームの勝敗判定に反映される**。後ろに置くと「死んでいるのに1フレーム戦闘が続く」
- **攻撃/移動より後**：`distance` でスケールする効果（遠矢）が、**そのフレームの移動後の距離**を読む。通常攻撃と同じ基準になる
- ⚠ **状態ガード（304行）の内側に置く。** `_tick_charge()`（299行）はガードの外だが、**待ち行列はウェーブ間や結果画面で進んではいけない**

### 7-6 の注意

`_on_charge_button_down()` は `blocked_reason()` を通っていない（CD・生存・セッション状態だけ見ている）。**この回でそこを変えない。** `charge_start` の効果を持つスキルが0件なので影響が出ない。

⚠ **`skill_data` はこの関数の中に無い。** `entry` から `skill_id` を取って `MasterDataLoader.get_skill()` を引くこと。

### 7-7 の注意

⚠ **`_enter_wave_clear()` では `_reset_party_positions()` より前に捨てる。** あとだと、味方が左端へ瞬間移動した後の距離で遠矢が計算される。

### 7-8 が**この回で一番踏みやすい罠**

⚠ **「もう一度」を押すと `_init_session()` が `BattleSession` を作り直す**（829行）。

**新層が古いセッションを掴んだままだと、リトライ後のスキルが「前の戦闘のユニット」を `_find_unit()` で探して見つからず、無音で空振りする。** エラーは1つも出ない。

**`reset()` はセッションの差し替えと待ち行列の破棄を同時にやること。** 片方だけだともう片方を忘れる。

### 7-9. 変えないもの

- **`_update_skill_buttons()` の活性条件**（541行）。待ち行列に残りがあってもボタンは押せてよい
- **クールダウンの開始位置**（`_fire_skill()` の最後）。⚠ **待ち行列が空になるまで待たない。** 押した時点で回り始めるのが今の挙動
- **`_tick_charge()` / `_cancel_charge()` / `_charge_power_ratio()` / `_is_just()`**
- **通常攻撃の経路**（`_step_unit()`）。⚠ **新層を通さない**（PLAN 21章の担当外）

---

## 8. `resources/balance/master/skills.json`

⚠ **インデントはタブ。スキルIDを改名しない。**

### 8-1. `skill_rapid_volley`（速射）を2体 × 2連射にする（決定1-5）

```json
	"skill_rapid_volley": {
		"name_key": "ui_battle_skill_rapid_volley",
		"user_character_id": "char_archer",
		"unlock_level": 15,
		"cooldown_sec": 8.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 2 },
		"effects": [
			{
				"type": "damage",
				"delivery": "projectile",
				"attack_type": "physical",
				"multiplier": 0.65,
				"scale_from": [
					{ "source": "atk", "of": "user", "weight": 1.0 },
					{ "source": "atkspd", "of": "user", "weight": 1.5 }
				]
			},
			{
				"type": "damage",
				"trigger": "delay:0.35",
				"delivery": "projectile",
				"attack_type": "physical",
				"multiplier": 0.65,
				"scale_from": [
					{ "source": "atk", "of": "user", "weight": 1.0 },
					{ "source": "atkspd", "of": "user", "weight": 1.5 }
				]
			}
		]
	},
```

- **倍率 1.3 を 0.65 × 2 に割った。** 合計は同じ
- ⚠ **合計ダメージは完全に同じにならない。** `BattleFormula.damage()` が `floor` して最低1を返すので、**2回に割ると端数が2回切り捨てられる。** 素の値で `18 → 9 + 9`。**これは正常**
- ⚠ **会心が2回別々に振られる。** 片方だけ会心することがある。**これも正常**（PLAN 5-5-4「多段では段ごとに1回ずつ振られる＝望ましい挙動」）
- **`delay:0.35`** … 等速で目に見えて、かつ「連射」に見える長さ

### 8-2. `delivery` を書く（決定1-7）

| キャラ | 書く値 | 対象 |
|---|---|---|
| **剣士**（6件） | **書かない**（＝ `melee`） | — |
| **弓兵**（6件） | **`projectile`** | 狙撃・矢の雨・追い討ち・遠矢・**速射の2効果**・貫きの矢 ＝ **7効果** |
| **僧侶** | **`magic`** | 聖光・吸命①・浄化の波動・裁きの雷 ＝ **4効果** |
| 僧侶の回復（癒しの光・集中治療・吸命②） | **書かない** | ⚠ 回復に送り方の概念が要るのは投射する回復を作るときなので、**今は書かない** |

**合計11効果に書く。**

⚠ **捨て身の一撃の②（自分への確定ダメージ）にも書かない。** 自分に当てるものに送り方は無い。

---

## 9. このタスクでやらないこと

- **状態の器・`buff` / `dot` ・購読・条件・パッシブ**（段階3）。⚠ **「実行中のスキル層」と混ぜると、術者が死んだ瞬間に敵のDoTが消える**（PLAN 7-2）
- **`trigger: "event:◯◯"` を出す側**（アニメが無い。受け口だけ・PLAN 6-4）
- **`mode: area`**（段階4）／**`phases[]` / `recast`**（段階5）／**`spawn`**（段階6）
- **`target.range`**（座標定数の回）／**ダメージの介入点の中身**（段階3）
- **通常攻撃を新層に通すこと**（PLAN 21章の担当外）
- **12スキルのバランス調整**
- ⚠ **`scale_from` に積を書けるようにすること**（器の穴。`PLAN_SKILL_TEMPLATE.md` 側で決めてから）

---

## 10. 事故りやすい箇所（**名指し**）

### 10-1. ⚠ リトライでセッションが作り直される（§7-8）

**この回で一番踏みやすい。** 無音で空振りする。

### 10-2. ⚠ 対象を発火時に選び直さない

**`resolve()` から `select_targets()` を消し忘れると、速射の2発目が「生き残っている別の敵」に吸われる。** 数字は出るので**気づきにくい。**

**確認**：`grep -n "select_targets" scripts/systems/skill_resolver.gd` が **`static func` の定義行1件だけ**になること。

### 10-3. ⚠ `trigger` を2箇所で解釈しない

`resolve()` の 188〜191行を消し忘れると、**新層が `delay` を待ってから発火させたのに、`resolve()` が「`cast` じゃない」と言って飛ばす。** ダメージが完全に消える。

### 10-4. ⚠ ロード時の警告が0件でなくなる

`delay:0.35` を書くと、`skill_schema.gd` の W5 が黄を1件出す。**§6-2 を先にやること。**

### 10-5. ⚠ 無音で消える3つ

| 形 | 置く警告 |
|---|---|
| 合図が来ないままタイムアウト | **`push_warning` ＋ 発火**（決定1-2） |
| 中断で捨てられた | **警告なし**（決定1-6・正常系） |
| 対象0体 | **警告なし**（正常系・PLAN 6-6） |

⚠ **3つを混ぜない。** 中断や空振りに警告を付けると、正常なプレイで出力パネルが埋まって**本物の異常が見えなくなる。**

### 10-6. ⚠ `cast` を次のフレームに回さない

待ち行列に積んで `tick()` を待つ作りにすると、**既存17スキルのダメージが1フレーム遅れ、勝敗判定の順序も変わる。** 完了条件 B-1（数字が変わらない）は通っても、**取りこぼしの形で挙動が変わる。**

### 10-7. ⚠ 編集したら `grep` で当たったことを確認する

```
grep -n "SkillRuntime"      scenes/adventure/battle_controller.gd   # 0件でないこと
grep -n "_skill_runtime"    scenes/adventure/battle_controller.gd   # 8箇所ぶん
grep -n "select_targets"    scripts/systems/skill_resolver.gd       # 定義行の1件だけ
grep -n "delivery"          scripts/systems/skill_schema.gd         # 0件でないこと
grep -c "\"delivery\""      resources/balance/master/skills.json    # 11
grep -n "delay:0.35"        resources/balance/master/skills.json     # 1件
```

### 10-8. インデントはタブ

`.gd` も `.json` も。

---

## 11. 完了条件

### 11-A. ログとファイル（**画面を見ないで確かめられる**）

| # | 見るもの | 期待 |
|---|---|---|
| A-1 | タイトル →「つづきから」→ 育成か戦闘画面に入ったときの出力パネル | `[MasterDataLoader] skills validated: 18 entries, 0 errors, 0 warnings` ⚠ **`delay:0.35` を書いても 0 warnings のままであること**（§6-2） |
| A-2 | `scripts/systems/skill_runtime.gd` | 新規。§4-5 の10関数と `effects_applied` シグナルがある |
| A-3 | `skills.json` | `"delivery"` が**11箇所**、`"delay:0.35"` が**1箇所** |
| A-4 | §10-7 の `grep` 6本 | 全部期待どおり |

⚠ **A-1 が唯一の `print`。** 新しい `print` は足さない。

### 11-B. 画面（⚠ **人間が実機で操作する**）

**準備**：弓兵に**速射**（Lv15）を装備する。⚠ **研究でレベル上限を上げていないと選べない。** 検証は**等速**で行う（8倍速だと0.35秒が見えない）。

| # | どこで | 何を見るか |
|---|---|---|
| B-1 | 戦闘（`F3` → `S` でCDリセット） | **速射以外の17スキルの数字が、前回と変わらない** |
| B-2 | 戦闘・速射 | **1発目のあと、少し遅れて2発目が出る。** 2体それぞれに2回ずつ、計4つの数字 |
| B-3 | 同上 | **2発目は1発目と同じ敵に当たる。** ⚠ **1発目で敵Aが死んでも、2発目は敵Aの上に出る**（別の敵に吸われない） |
| B-4 | 速射の1発目で**そのウェーブの最後の敵が死ぬ**ようにする（`K` で敵を減らしてから） | **2発目は出ない。** ウェーブがそのまま進む。⚠ **出力パネルに警告も出ない**（正常な中断） |
| B-5 | 速射で**最終ウェーブの最後の敵**を倒す | **勝利画面が出たあとに数字が出ない** |
| B-6 | 敗北 →「もう一度」→ 速射を撃つ | ⚠ **2連射が正しく出る**（§7-8の罠。ここが壊れていると**1発も出ない**） |
| B-7 | 戦闘・横薙ぎ（剣士のチャージ） | **今までどおり。** ためて離すと発動、JUST演出も出る |
| B-8 | 遠矢を撃った直後にウェーブが変わる状況 | **数字が跳ねない**（そもそも2発目が無いので、遠矢は単発のまま） |
| B-9 | 出力パネル | **上のどれをやっても赤も黄も出ない** |

### 11-C. 将来コードを変えたときに見る項目（⚠ **人間の確認項目ではない**）

- **`notify_event()` は呼び出し元ゼロ。** アニメーションが入ったとき、演出シーンから `cast_id` と `event_name` を渡して呼ぶ。**足すのは「呼ぶ側1本」だけで、新層も `SkillResolver` も JSON も変わらない**（PLAN 6-5）
- **タイムアウト（`EVENT_TIMEOUT_SEC` 5.0秒）は実戦で1度も通らない。** `event:` を書いたスキルが0件のため。**演出が入って初めて意味が出る**
- **`cancel_by_delivery()` も呼び出し元ゼロ。** 段階3の効果 `cancel`（飛び道具の無効化）と詠唱中断が使う
- **`charge_start` も利用者ゼロ。** 本命の「チャージ中の軽減」は状態＝段階3
- **`delivery` を書いていない効果は `melee` 扱い。** 回復と自傷にも `melee` が入る。**投射する回復を作るときに見直す**

---

## 12. ⚠ PLAN とのズレ（**勝手に直していない。人間が判断すること**）

### 12-1. 種別タグの出どころが PLAN に無い（決定1-7で埋めた）

**PLAN 6-8 は「要素に種別タグ（投射物／近接／魔法）」とだけ書いてあり、値をどこから取るかが書かれていない。** `skills.json` に該当する欄が無く、`attack_type` は流用できない（PLAN 5-2-1 が「どの防御で受けるか」に純化したばかり）。

**`effects[].delivery` を新設して埋めた。PLAN 5-2 の効果の欄の表に `delivery` が無い。**

### 12-2. `resolve()` の引数が1つ増える（PLAN 7-3）

**PLAN は「入口は2つ」としか書いていない。** 入口の数は変わらないが、**`resolve()` が対象IDを外から受け取る形になる**ことは書かれていない。

**PLAN 4-4（対象は cast 時に確定・ID保持）を満たすには他に方法が無い。** 契約（時間を持たない・次のフレームを知らない・ノードを触らない）と歯止め（実効スキルデータは `skills.json` に書ける欄しか含まない）は**どちらも無傷。**

### 12-3. `PLAN_SKILL_TEMPLATE.md` 21章の未確定4件

**`NEXT_STEPS.md` のとおり、段階1のEXECで既に決着している**（`sort` 5値を全部実装／リソースは作らない／遮蔽は入れない／`count` の上限は設けない）。**PLAN 側は未確定のまま。**

### 12-4. 引き継いだまま直していないもの

- ⚠ **`scale_from` は「和」しか書けない**（PLAN 5-5-1）。器の穴
- ⚠ **PLAN 5-5-2 の「想定レンジ 50〜500」が実データと合わない**
- **`target.range` が18件とも未設定**（座標定数待ち）
- **ダメージの介入点は利用者ゼロのまま**（段階3）

---

## 13. コミットメッセージ

```
feat(skill): 実行中のスキル層と trigger（段階2・多段と遅延）
```
