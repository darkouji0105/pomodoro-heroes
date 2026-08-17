# EXEC — **変数表の残り（戦闘の群 ＋ stack）＋ stack の上限 ＋ パッシブ**

段階3の後半 **④-a**。⚠ **④は2回に割った**（人間の決定・2026-08-17）。

| 回 | 中身 |
|---|---|
| **④-a（これ）** | 変数表の「戦闘」4つ ／ `stack` の変数と**上限** ／ `of: "source"` を赤にする ／ **パッシブ** |
| ④-b（次） | **コンボ**（購読の `host: battle` 拡張 ＋ `combo_count`） |

> ⚠ **`combo_count` はこの回で作らない。** コンボと対なので ④-b へ一緒に動かした（NEXT_STEPS 1-3 の「片方だけ作らないこと」はこれで満たされる）。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **範囲** | **2分割。** ④-a＝変数＋パッシブ、④-b＝コンボ。⚠ **`host: battle` の拡張はこの回で1行も触らない** |
| **`stack:<状態ID>` の書き方** | ⚠ **入れ子。** `{ "source": "stack", "status_id": "..." }`。前方一致は採らない |
| **stack の上限** | ⚠ **最小で入れる。** `stack: "independent"` に `max_stack` を必須にし、上限を超えた分を積まない |
| **`of: "source"`** | ⚠ **実装しない。代わりにロード時検証で赤にする。** 今は `SCALE_OF_KNOWN` に入っていてロードを通り、発火時に黄＋0.0 になる。**書けるのに0になる経路を消す** |
| ⚠ **パッシブとは何か** | ⚠ **「発動の型が違うだけのスキル」。** **`passives.json` を作らない。定義は既存の `skills.json`。** 読み込みも検証もキャッシュも既存のまま |
| ⚠ **敵のパッシブ** | ⚠ **敵も持つ。** 上の決定の帰結（敵のスキルも同じ `skills.json` の仕組みに載っている）。**⚠ 初稿の「敵は持たない」は撤回** |
| ⚠ **条件付きパッシブ** | ⚠ **③の `condition` でそのまま書ける。新規実装ゼロ** |
| ⚠ **枠** | ⚠ **別枠。** スキル枠とは別に持つ。⚠ **枠の仕組みを複製しない。既存の関数を「枠の種類」で一般化する** |
| ⚠ **発動の仕方** | ⚠ **スキルとまったく同じ `_fire_skill()` を通す。違うのは「引き金を引くのが誰か」だけ。** 味方＝ボタン ／ 敵＝攻撃拍 ／ **パッシブ＝走査**。⚠ **`SkillActivation` に専用の分岐を足さない** |
| **付け直し** | 戦闘中に `_fire_skill()` し、**引き金の走査を1本**置く（`_step_passives()`）。「消えない印」を状態に足す案は採らない |

### 0-1. ⚠ 初稿から変わった点（**2026-08-17・人間の指摘で差し替え**）

初稿は **`passives.json` ＋ 専用キャッシュ ＋ 専用の検証**という**別のロード系統**で書いていた。**間違い。**
⚠ **「定義を分ける」と「枠を分ける」は別の話。** 分けるのは**枠だけ**で、定義・読み込み・検証・発動の経路は**スキルと同じ1本**。

| | 初稿 | ⚠ **これ** |
|---|---|---|
| 定義の置き場 | `characters/<id>/passives.json`（新設） | ⚠ **既存の `skills.json`** |
| 読み込み | `_load_character_files("passives.json", ...)` を1本追加 | ⚠ **足さない。`master_data_loader.gd` を1行も触らない** |
| 検証 | `_validate_all_skills()` を引数化して2回呼ぶ | ⚠ **既存の1回のまま。E77 も要らなくなる** |
| 所持 | `characters.json` に `"passives"` 配列を新設 | ⚠ **別枠。** 味方＝育成のパッシブ枠 ／ 敵＝`enemies.json` の `"passives"` 配列 |
| **敵** | ⚠ **持てない**（ロード経路が2系統になるため） | ⚠ **持てる。定義を分けないので自動で載る** |
| 撃てないようにする | パッシブ専用の分岐 | ⚠ **何も要らない**（下） |

**分けたせいで「敵は持てない」という制約を自分で作っていた。** 分けなければ制約自体が存在しない。

### 0-1-1. ⚠ **「別枠」にすると、弾く仕掛けが2つとも消える**（2026-08-17・人間の指摘）

初稿は**パッシブを `skill_ids` に混ぜ、後段で弾く**設計だった。そのために弾く仕掛けが2つ要っていた。

| 弾く必要があったもの | ⚠ **別枠にすると** |
|---|---|
| 敵AI が撃ってしまう | `_try_enemy_skill()` は **`skill_ids` しか回さない**（`battle_controller.gd:548`）。⚠ **別配列なら自動で撃たれない** |
| 味方のボタンに並んでしまう | ボタンも **`skill_ids` しか見ない**（`unit.gd:97`）。⚠ **UI のフィルタが要らない** |
| → `SkillActivation.blocked_reason()` に1行 | ⚠ **要らない。`skill_activation.gd` を1行も触らない** |
| → `SkillSchema.is_passive()` を UI 2箇所から呼ぶ | ⚠ **要らない** |

**混ぜなければ弾かなくてよい。**

### 0-1-2. ⚠ `_step_passives()` は「特別な経路」ではなく**引き金**

発動の経路は**3つとも同じ**。違うのは引き金を引くのが誰かだけ。

| 引き金 | 誰が引くか | その先 |
|---|---|---|
| 味方のスキル | `_on_skill_button_pressed()`（ボタン） | ⚠ **`_fire_skill()` → `cast()` → `SkillResolver`** |
| 敵のスキル | `_try_enemy_skill()`（攻撃拍） | ⚠ **同上** |
| **パッシブ** | **`_step_passives()`（走査）** | ⚠ **同上** |

⚠ **`_fire_skill()` を迂回しないこと。** 迂回すると、クールダウンの開始も購読の配布も揃わなくなる（`battle_controller.gd:543-544` の注記と同じ理由）。

### 0-2. 採らなかった案と、その理由

- **`trigger: "passive"` にする**（人間の言葉は「トリガーが違うだけ」だった）：⚠ **軸は `activation` が正しい。** `trigger` は**効果1件ごと**の「いつ発火するか」で、解釈するのは `SkillRuntime`（`skill_schema.gd:104`）。`trigger` に置くと**1つのスキルの中に「cast の効果」と「パッシブの効果」が混在でき、そのスキルが撃てるものなのか決まらなくなる。** `activation`（発動の型）は**スキル全体**の性質なので、「プレイヤーが撃つものではない」はこちらの軸。⚠ **概念としては人間の言うとおり「スキルの一種」で変わらない**
- **`stack:<ID>` の前方一致**：JSON は短くなるが、`scale_sources()` の利用者すべて（`condition_sources()` ／ E群 ／ 評価器2本）に前置き分岐が要る。⚠ **`"stack:status_poion"` が「正しい形の source」に見えて永遠に0**になる
- **パッシブの状態に「消えない印」を足す**：印を見る分岐が**4〜5箇所に散る**（§1-3）。⚠ **PLAN 11-1 の「ブレると4箇所バラバラになる」を最初から踏む**
- **復活のときだけパッシブを付け直す**：ウェーブ交代と将来の `dispel` に穴が残り、**2箇所目3箇所目ができる**（③ §2-2 で避けた形）

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-17**）

### 1-1. ⚠ 変数表は「1本」ではなく **2本の評価器**に効く

`scale_sources()`（`skill_schema.gd:216`）を `condition_sources()`（`skill_schema.gd:234`）が流用している（`distance` だけ除く）。
⚠ **`scale_sources()` に1つ足すと、その瞬間に `condition` にも書けるようになる。** 評価器は別々の2本：

| 評価器 | 場所 | 種類 | session を持つか |
|---|---|---|---|
| `_scale_variable(source, of, user, target)` | `skill_resolver.gd:512` | **static** | ❌ **持たない** |
| `_condition_value(cond, unit)` | `status_registry.gd:636` | インスタンス | ✅ `_session` を持つ |

⚠ **片方に足し忘れると `push_error` ＋ 0.0。** 赤は出るが戦闘は続く（NEXT_STEPS 2-3 の一歩手前）。

### 1-2. ⚠ `_scale_variable()` に session が届いていない

この回で足す変数は全部 session か registry が要る。⚠ **`resolve()` は両方持っている**（`skill_resolver.gd:226`）。
`_scale_value_sum()` → `_scale_variable()` へ通すだけで届く。**呼び出し元は2箇所**（damage の329行 ／ heal の403行）。⚠ **署名が4本変わる**。

### 1-3. ⚠ パッシブの状態が消える経路は **4本ある**（＋将来1本）

| 経路 | 場所 | パッシブはどうなるか |
|---|---|---|
| **復活の全消し** | `clear_for_unit(unit_id, "revive_clear")`（`status_registry.gd:871`） | ⚠ **消えて二度と戻らない** |
| 宿主の死亡 | `_drop_dead_hosts()` | 消える。⚠ **将来「他人の蘇生」が入ると同じ穴**（宿題16番） |
| **ウェーブ交代** | `enemy_units` は毎ウェーブ作り直す（`battle_session.gd:28`）。⚠ **`party_units` は作り直さないが、`status_clear` が味方の状態も捨てる**（2026-08-17・実測） | ⚠ **敵も味方も毎ウェーブ付け直しが要る。** ⚠ **初稿は「味方は消えない」と書いていたが誤り** |
| 戦闘開始・リトライ | `reset()` → `clear_all()`（`status_registry.gd:63`） | 付け直す前提なので問題なし |
| **（将来）`dispel`** | `EFFECT_TYPES_KNOWN` に**語彙だけある・未実装**（`skill_schema.gd:65`） | 実装したらここも消す経路になる |

**→ 走査1本（`_step_passives()`）に寄せると、この4本が何本に増えても関係なくなる。**

### 1-4. ⚠ `cast()` はその場で発火する（**1フレームの穴が空かない根拠**）

`SkillRuntime.cast()` は `trigger: "cast"` の効果を**その場で発火する**（`skill_runtime.gd:90-93` が「⚠ cast を次のフレームに回さないこと」と明記）。
⚠ **復活したそのフレームのうちにパッシブが戻る。** 走査を `_step_deaths()` の直後に置けば穴は無い。

### 1-5. 「撃てるか」の判定は **1箇所しかない**（⚠ **この回は触らない**）

`SkillActivation.blocked_reason(user, skill_id, skill_data, session)`（`skill_activation.gd:29`）。
**味方のボタン（`_on_skill_button_pressed`）も、敵のAI（`_try_enemy_skill`）も、同じ `_fire_skill()` を通ってここへ来る**（`battle_controller.gd:787-795`）。

⚠ **パッシブも同じ `_fire_skill()` を通す**（§0-1-2）。**別枠なので弾く必要が無い**（§0-1-1）。
→ ⚠ **`skill_activation.gd` を1行も触らない。**

### 1-6. ⚠ `is_skill_ready()` が `skill_ids` を見る（**別枠にしたときの唯一の落とし穴**）

`BattleUnit.is_skill_ready()`（`unit.gd:245-248`）は **`skill_id in skill_ids` でなければ無条件に `false`**。
⚠ **パッシブを別配列に置くと、`_fire_skill()` が `REASON_COOLDOWN` を返して発動しない。**

> ⚠ **理由が嘘になるので追いにくい。** クールダウンを持たないパッシブが「クールダウン中」で弾かれる。**エラーは1つも出ない。**

→ **`unit.gd` に `passive_ids` を足し、`is_skill_ready()` が「`skill_ids` または `passive_ids` に含まれていれば」に見るようにする**（§3-3）。
⚠ **`start_cooldown()` は `skill_ids` のままにする。** パッシブにクールダウンを持たせないため（`unit.gd:254`）。

⚠ **`skill_ids` は「ボタンの並び順になる」**（`unit.gd:97`）。**別枠にすることで、ここへパッシブが混ざらない**＝UI のフィルタが要らない。

### 1-7. `stack` の現状

- 種類は2つだけ（`skill_schema.gd:146-148`）：`independent` ／ `refresh`
- 上限・消え方・再付与・閾値は**4つとも未実装**（宿題6番）
- ⚠ **`independent` は今も無限に積む。** `EXEC_SKILL_CONDITION.md` §2-3 が `status_count` を**あえて作らなかった**理由がこれ
- 既存の `"stack": "independent"` は **9件 / 5ファイル**（`.bak` の3件を除く）

### 1-8. `BattleSession` に経過時間の欄が無い

`current_wave`（**1始まり**・`battle_session.gd:24`）と `get_alive_units(team)`（:67）はある。**経過秒だけ無い。**

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ 変数を足すときは **必ず2箇所**（§1-1）

`scale_sources()` に足したら、**`_scale_variable()` と `_condition_value()` の両方**に枝を足す。
⚠ **片方だけだと「damage では効くのに condition では0」という、エラーが1行出るだけの壊れ方をする。**

### 2-2. ⚠ `of` を読まない source が **3つに増える**

今は `distance` だけの例外（`skill_resolver.gd:513`）。この回で `elapsed_sec` / `wave_index` が加わり **3つ**。
→ ⚠ **例外を各所に散らさない。** `SCALE_SOURCES_NO_OF` という定数の配列を1本作り、**「例外の一覧が1箇所にある」形にする。** 分岐を3つ書かないこと。

### 2-3. ⚠ `wave_index` は **1始まり**

`BattleSession.current_wave` が1始まり。⚠ **名前が `_index` なので0始まりに読める。**
→ **値は `current_wave` をそのまま返す。** JSON で `wave_index >= 2` と書いたら「2波目以降」。⚠ **EXEC とコメントの両方に書く。**

### 2-4. ⚠ `alive_count_ally` / `alive_count_enemy` は **`of` で指したユニットから見た**味方・敵

絶対（party / enemy）にしない。⚠ **他の変数が全部「`of` で指したユニットの値」なので、ここだけ絶対にすると意味が揺れる。**
敵が撃つスキルに `alive_count_ally` と書いたら**敵の生存数**になる。**これが正しい。**

### 2-5. ⚠ `max_stack` を足すと**既存の JSON が全部赤になる**

`stack: "independent"` に必須にするので、**既存9件に足すまでロードが赤になる。**
→ ⚠ **`.gd` を入れたら続けて JSON を入れること**（③ §9 と同じ順序の罠）。

### 2-6. ⚠ パッシブの効果は `stack: "refresh"` に限る

走査が「欠けていたら cast し直す」形なので、⚠ **`independent` を許すと毎フレーム積み上がる。**
→ **ロード時検証で赤にする。** ⚠ **これを省くとフレームレートごと落ちる。**

### 2-7. ⚠ パッシブは `trigger` を `"cast"` に限る

`delay:` や `event:` を許すと、**「いつ付くか」が走査と噛み合わない**（走査は「付いていなければ cast」なので、遅れて付くものは毎フレーム cast され続ける）。
→ **ロード時検証で赤にする。**

### 2-8. ⚠ 走査は1箇所だけ

`_step_passives()` の2本目を作らない。「復活のときだけ `resolve_death()` の中で付け直す」を足した瞬間に、**片方だけ直す事故**になる（③ §2-2）。

### 2-9. ⚠ 枠を増やしたら**旧セーブの正規化**が要る

`_normalize_skill_slots_from_save()`（`game_manager.gd:1931`）が、旧セーブと枠数変更を吸収して **`save_version` を上げずに済ませている**（`EXEC_SKILL_SELECT.md` §9）。
⚠ **パッシブ枠を足すと、既存セーブには欄が無い。** 正規化を通さないと `null` のまま画面へ行く。
→ ⚠ **枠の仕組みを「枠の種類」で一般化すれば、正規化も同じ1本が両方を見る**（§3-4）。**2本目を書かないこと。**

### 2-10. ⚠ `_fire_skill()` を迂回しない

パッシブ専用の `cast()` を書かない（§0-1-2）。⚠ **迂回すると購読の配布が揃わず、「パッシブに `react` を書いたのに発火しない」が無音で起きる。**

---

## 3. 実装（ファイル別）

⚠ **関数を足す前に `grep -n "func <名前>"`、足したあとにも `grep -n` で当たったか確認する**（`CLAUDE.md` 2番）。
⚠ **E番号は E67 まで使用済み。この回は E68 から。** W番号は `grep -n "W[0-9]" skill_schema.gd` で次を確かめてから使う。

### 3-1. `scripts/systems/battle_session.gd` — 経過秒を1つ

```gdscript
# 戦闘開始からの経過秒（scale_from / condition の elapsed_sec・PLAN 5-5-2）。
# ⚠ 積むのは battle_controller._process() の1箇所だけ。2本目の時計を作らない。
# ⚠ 状態1件ごとの elapsed（StatusRegistry の entry）とは別物。混同しないこと。
# ⚠ ウェーブ交代では戻さない。「戦闘開始から」であって「ウェーブ開始から」ではない。
var elapsed_sec: float = 0.0
```

### 3-2. `scripts/systems/skill_schema.gd` — 語彙・`of` の例外一覧・E68〜

#### (a) 定数を足す

```gdscript
# --- activation に1つ足す ---
# ⚠ 「発動の型」であって効果の trigger ではない（§0-2）。プレイヤーも敵AIも
#   撃たない。SkillActivation が弾き、_step_passives() が付け直す。
const ACTIVATION_PASSIVE: String = "passive"

# --- scale_from の source のうち、戦闘全体の値（PLAN 5-5-2「戦闘」の群） ---
const SCALE_ELAPSED_SEC: String = "elapsed_sec"
const SCALE_ALIVE_ALLY: String = "alive_count_ally"
const SCALE_ALIVE_ENEMY: String = "alive_count_enemy"
const SCALE_WAVE_INDEX: String = "wave_index"

# --- scale_from の source のうち、状態の群 ---
# ⚠ 入れ子で書く。{ "source": "stack", "status_id": "..." }（人間の決定）。
#   前方一致（"stack:xxx"）にしない。scale_sources() の「列挙できる形」が
#   崩れ、利用者すべてに前置き分岐が要る（PLAN 5-5-4）。
const SCALE_STACK: String = "stack"

# of を読まない source。⚠ 例外の一覧はここ1本。分岐を各所に散らさない。
const SCALE_SOURCES_NO_OF: Array = [SCALE_DISTANCE, SCALE_ELAPSED_SEC, SCALE_WAVE_INDEX]

# independent の上限。⚠ 上限に達したら「積まない」。古いものを捨てて積む形に
#   しないこと（寿命が延び続け、実質無限になる）。
const FIELD_MAX_STACK: String = "max_stack"
```

⚠ **`ACTIVATIONS_KNOWN`（30行）に `ACTIVATION_PASSIVE` を足す。**
⚠ **`EFFECT_TYPES_*` / `HOSTS_KNOWN` / `EVENTS_KNOWN` / `STACKS_KNOWN` / `TRIGGERS` には何も足さない。** 増える語彙は `activation` の1つだけ。

#### (b) `scale_sources()`（216行）に5つ足す

`SCALE_ELAPSED_SEC` / `SCALE_ALIVE_ALLY` / `SCALE_ALIVE_ENEMY` / `SCALE_WAVE_INDEX` / `SCALE_STACK`
⚠ **`condition_sources()`（234行）は触らない。** `distance` を除くだけの流用のままでよい。

#### (c) `SCALE_OF_KNOWN`（186行）から `SCALE_OF_SOURCE` を**外さない**

⚠ **外すと `of が不明` という別の文言で赤が出る。** 定数は残し、**E68 で専用の文言を出す**。

#### (d) 新しい検証

| 番号 | 内容 | 色 |
|---|---|---|
| **E68** | `scale_from` の `of` が `"source"`。⚠ **「実装しないと決めた。`of: user` / `of: target` で書くこと」**という文言にする | 赤 |
| **E69** | `stack: "independent"` に `max_stack` が無い／整数でない／**1未満** | 赤 |
| **E70** | `max_stack` が `stack: "refresh"` の効果に書かれている（何も起きない欄を書かせない・E39 と同じ考え方） | 赤 |
| **E71** | `scale_from` / `condition` の `source: "stack"` に `status_id` が無い、または空文字 | 赤 |
| **E72** | `scale_from` の項に `status_id` があるのに `source` が `"stack"` でない（⚠ **condition 側は `status_registry.gd:420` に同等の検査が既にある**） | 赤 |
| **W（次番号）** | `SCALE_SOURCES_NO_OF` の source に `of` が書かれている（無視される欄） | ⚠ **黄。** 既存 JSON に `distance` ＋ `of` があると赤で止まるため |
| **E73** | `activation: "passive"` に `cooldown_sec` / `charge` / `phases` が書かれている（撃つものではない） | 赤 |
| **E74** | `activation: "passive"` の `target.team` が `"self"` でない | 赤 |
| **E75** | ⚠ **`activation: "passive"` の効果の `stack` が `"refresh"` でない**（§2-6）／ `host` が `"unit"` でない | 赤 |
| **E76** | ⚠ **`activation: "passive"` の効果の `trigger` が `"cast"` でない**（§2-7） | 赤 |

⚠ **E77 は作らない。** 初稿の「`characters.json` の書き忘れ検査」は、**所持が既存の `"skills"` 配列に戻ったので、パッシブだけの話ではなくなった**（skills 全体の宿題のまま・§8）。

### 3-3. `scripts/systems/unit.gd` — 別枠を1本（§1-6）

```gdscript
# 所持パッシブID。⚠ skill_ids と別に持つ（人間の決定）。
# ⚠ 別枠なので、ボタンにも _try_enemy_skill() にも混ざらない。
#   混ぜて後段で弾く形にしないこと（EXEC §0-1-1）。
var passive_ids: Array = []
```

`is_skill_ready()`（245行）を **`skill_ids` または `passive_ids`** に変える。

⚠ **これを忘れると `_fire_skill()` が `REASON_COOLDOWN` を返し、パッシブが無音で発動しない**（§1-6）。
⚠ **`start_cooldown()`（254行）は `skill_ids` のまま。** パッシブにクールダウンを持たせない。
⚠ **`skill_ids` / `take_damage()` / `heal()` / `is_alive()` / `death_handled` は1文字も変えない。**

### 3-4. `autoload/game_manager.gd` — パッシブ枠（⚠ **複製せず一般化する**）

`game_manager.gd:1765-2110` のスキル枠の仕組みを、**「枠の種類」を引数で通す形に一般化する。**

⚠ **同じ関数をもう一式作らないこと。** 枠が3種類目になったとき破綻する。

種類ごとに違うのは**4つだけ**：

| | スキル枠 | パッシブ枠 |
|---|---|---|
| 状態のキー | `GameStateKeys.GROWTH_SKILLS` | ⚠ **`GROWTH_PASSIVES`（新設）** |
| 枠数 | `SKILL_SLOT_COUNT` | パッシブ枠の数 |
| 候補の出どころ | `characters.json` の `"skills"` | ⚠ **`"passives"`（新設）** |
| 未選択のとき | 候補の先頭を入れる（`get_battle_skills()`） | ⚠ **決めが要る**（§3-4-1） |

⚠ **`_normalize_skill_slots_from_save()` も一般化の側に寄せる**（§2-9）。**2本目を書かない。**
⚠ **`GameStateKeys` に `GROWTH_PASSIVES` を足す**（文字列リテラルを書かない・`AGENTS.md`）。
⚠ **`AGENTS.md` の状態構造の表に1行足すかは人間の判断**（§8）。

#### 3-4-1. ⚠ 未選択のパッシブ枠の扱い（**設計役の判断・要確認**）

`get_battle_skills()` は「未選択なら候補の先頭を入れる」（`game_manager.gd:1991-1993`）。**セーブに初期値を書かないための仕組み。**
⚠ **パッシブで同じことをすると、「外したつもりのパッシブが勝手に付く」。**
→ **パッシブは未選択なら空のままにする**（`get_battle_passives()` は空欄を埋めない）。⚠ **スキルと挙動が違う点なので §8 に残す。**

### 3-5. `scripts/systems/skill_resolver.gd` — 変数の評価

#### (a) 署名を4本変える（§1-2）

```
resolve()            … 既に session / registry を持つ。変更なし
  → _apply_damage()  … session / registry を渡す
  → _apply_heal()    … session を足す（registry は③で既に足した）
     → _scale_value_sum(effect, user, target, fallback, session, registry)
        → _scale_variable(source, of, user, target, session, registry, status_id)
```

⚠ **`registry` の型は `RefCounted` のまま**（`skill_resolver.gd:216-221` の Cyclic reference の注記）。
⚠ **`_scale_value_sum()` の呼び出し元は2箇所だけ**（329行 ／ 403行）。**3箇所目を作らない。**

#### (b) `_scale_variable()` に枝を足す

`of` を読む**前**に `SCALE_SOURCES_NO_OF` を処理する（既存の `distance` の枝をここへ畳む）。

```gdscript
if source in SkillSchema.SCALE_SOURCES_NO_OF:
	match source:
		SkillSchema.SCALE_DISTANCE:    … 既存のまま
		SkillSchema.SCALE_ELAPSED_SEC: return 0.0 if session == null else session.elapsed_sec
		SkillSchema.SCALE_WAVE_INDEX:  return 0.0 if session == null else float(session.current_wave)  # ⚠ 1始まり（§2-3）
```

`of` を読んだあと（`u` が決まったあと）：

- `SCALE_ALIVE_ALLY` / `SCALE_ALIVE_ENEMY` … ⚠ **`u` のチームから見る**（§2-4）。`session.get_alive_units(team)` の件数
- `SCALE_STACK` … `registry` に「(宿主 `u`, `status_id`) の件数」を訊く

⚠ **`of: "source"` の枝（526-528行）は残す。** ロード時に赤で弾くので通常は到達しないが**二重に守る**（PLAN 5-4）。⚠ **文言を「E68 で弾いているのでここへは来ないはず」に変える。**

### 3-6. `scripts/systems/status_registry.gd` — 件数・上限・条件側の変数

#### (a) 件数を返す公開関数（新設）

```gdscript
# (宿主, status_id) に一致する状態の件数。⚠ scale_from / condition の
# source: "stack" が唯一の利用者。
# ⚠ active が偽の件も数える（「積まれている数」であって「効いている数」ではない）。
#   ここを active で絞ると、条件付き状態のスタック数が条件で揺れる。
func count_stacks(host_unit_id: String, status_id: String) -> int:
```

⚠ **`has()` と別の関数にする。** `has()` は真偽しか返さない契約を保つ。

#### (b) `add()` に上限（169行より前・⚠ **状態を1つも触っていない場所**）

`stack == STACK_INDEPENDENT` のとき、`count_stacks(...) >= max_stack` なら **`false` を返して積まない。**
⚠ **古いものを捨てて積む形にしない。** ⚠ **`BattleLog.log_status_add()` より前で弾く**（免疫と同じ理由・③ §2-7）。

#### (c) `_make_entry()` に `"max_stack"` を足す

⚠ **持たない件（`refresh`）にも必ず持たせる**（`0`）。持たない件があると `query()` が黙って外す（③ §3-2(b)）。

#### (d) `_condition_value()`（636行）に**同じ5つ**を足す（§2-1）

⚠ **`_scale_variable()` と枝の中身を揃える。** `_session` は既に持っている。
⚠ `elapsed_sec` / `wave_index` は引数の `unit` を読まない。

#### (e) `_fill_condition()`（426行）は触らない

⚠ **`host: "unit"` のみの制限はこの回でも維持**（`host: battle` は ④-b）。

### 3-7. 育成画面 — パッシブ枠の表示

⚠ **スキル枠の描画をそのまま流用する**（§3-4 の一般化に乗せる）。**枠の描画コードを複製しない。**
⚠ **戦闘画面のスキルボタンは1行も触らない。** `skill_ids` しか見ないので、別枠にした時点でパッシブは並ばない（§0-1-1）。
⚠ **実装前に `grep` で育成画面のスキル枠の描画箇所を確定してから触る。**

### 3-8. `scenes/adventure/battle_controller.gd` — 経過秒と引き金の走査

#### (a) `_process()` の並び

```
_step_unit()             … 通常攻撃
_skill_runtime.tick()    … スキル
_status.tick()           … 状態（先頭で _drop_dead_hosts）
_step_deaths()           … 死亡の介入点（③）
_step_passives()         … ⚠ この回。復活で消えたパッシブを同じフレームで戻す
勝敗判定
```

⚠ **`_step_deaths()` より後・勝敗判定より先。** 前に置くと、復活の全消しがパッシブを消したまま1フレーム残る。

`_session.elapsed_sec += delta` は **`_process()` の1箇所だけ**。⚠ **`_status.tick(delta)` に渡すのと同じ `delta`**（速度変更に自動で追従する）。

#### (b) `_step_passives()`

```gdscript
# パッシブの引き金（PLAN 7-2・19章）。
# ⚠ 味方のボタン・敵の攻撃拍と同じ立場。その先は同じ _fire_skill() を通る（§0-1-2）。
# ⚠ 走査は1箇所だけ。「復活のときだけ付け直す」を別に書かないこと（§2-8）。
# ⚠ 生きているユニットだけ。死者に付け直すと _drop_dead_hosts() と綱引きになる。
# ⚠ 味方と敵で分岐しない。passive_ids は両方が持つ（§1-6）。
func _step_passives() -> void:
```

- `party_units` と `enemy_units` を回す。⚠ **`is_alive()` が偽なら飛ばす**
- `unit.passive_ids` を回す（⚠ **`skill_ids` は見ない**）
- その定義の効果群の `status_id` が**全部付いているか**を `_status.has()` で確かめ、**1つでも欠けていたら `_fire_skill(unit, passive_id, 1.0)`**
- ⚠ **`stack: "refresh"` が必須なので（E75）、既に付いている分は置き直されるだけ**

⚠ **`_fire_skill()` を必ず通す。`_skill_runtime.cast()` を直接呼ばない**（§2-10）。
⚠ **`_fire_skill()` の中で `start_cooldown()` が走るが、`passive_ids` は `skill_ids` に無いので何も起きない**（`unit.gd:254`）。**これが正しい。**

#### (c) ユニット生成時に `passive_ids` を入れる

- 味方 … `GameManager.get_battle_passives(character_id)`（§3-4）
- 敵 … `enemies.json` の `"passives"` 配列

⚠ **`enemy_units` はウェーブごとに作り直すので、毎ウェーブここを通る**（§1-3）。

---

## 4. 変えないもの

- ⚠ **`host: battle` まわり全部**（E51 ／ `_fill_condition` ／ `_fire_intervals`）。**④-b の範囲**
- ⚠ **`combo_count`**（④-b）
- ⚠ **`master_data_loader.gd`（1行も触らない）** ／ `CHARACTER_DIRS_*` ／ `ENEMY_DIRS_*` ／ `_validate_all_skills()` の署名
- ⚠ **`scripts/systems/skill_activation.gd`（1行も触らない）**。⚠ **`REASON_PASSIVE` を作らない**（§0-1-1）
- ⚠ **`battle_controller.gd` の `_try_enemy_skill()` / `_fire_skill()`**（§1-5。**パッシブ用の分岐を書かない**）
- ⚠ **戦闘画面のスキルボタンの生成**（`skill_ids` しか見ないので、別枠にした時点で触る必要が無い）
- ⚠ **`BattleUnit.start_cooldown()`**（`skill_ids` のまま。パッシブにCDを持たせない）
- `_step_crit_override()` / `_step_reduction()`（ダメージの受け口・**`pass` のまま**。⚠ **4つのうちこれだけ利用者ゼロが続く**）
- `BattleUnit.take_damage()` / `heal()` / `is_alive()` / `death_handled` / `skill_ids`
- `_step_deaths()` / `resolve_death()` / `_drop_dead_hosts()`（③のもの。**1文字も変えない**）
- `condition_sources()` の「`distance` を除く」規則
- `EFFECT_TYPES_*` / `HOSTS_KNOWN` / `EVENTS_KNOWN` / `STACKS_KNOWN`（⚠ **増える語彙は `activation` の1つだけ**）
- `parties.json` ／ `stage_order.json` の `"story"` 列 ／ `main_theme.tres`

---

## 5. 完了条件 — **ログ**（Godot の出力パネル）

> ⚠ **この章と §9-1 の突き合わせは `EXEC_PASSIVE_VARS_ZIVA_CHECK.md` に切り出して Ziva に渡す。** §6 は設計役、§7 は人間。

1. 戦闘を開始したとき、**赤いエラー（parse error / Invalid call）が1つも出ないこと。** 特に `_scale_value_sum()` / `_scale_variable()` の**引数の数**（2本とも増えている）
2. ⚠ **`skills validated:` の件数が、足したパッシブと検証用スキルのぶんだけ増えていること**（⚠ **パッシブも同じ数に入る**。別枠のログを作っていないことの確認）。⚠ **`errors` は 0。`warnings` は 1 のまま**（`skill_dbg_dot_odd` の端数。**黄1本は出るのが正解**）
3. ⚠ **`[SkillResolver] scale_from の source が不明:` が出ないこと。** 出たら `scale_sources()` に足したのに `_scale_variable()` に枝が無い（§2-1 の片側落ち）
4. ⚠ **`[StatusRegistry] condition.source が不明:` が出ないこと**（§2-1 のもう片側）
5. ⚠ **`[SkillResolver] scale_from の of: source` の警告が出ないこと**（E68 で弾いているので到達しないはず）

## 6. 完了条件 — **ファイル**（`user://logs/battle_last.jsonl`）

⚠ **戦闘のたびに上書きされる。読む前に別の戦闘を始めないこと。**
⚠ **画面で分かることをここに書かない。** ⚠ **設計役が直接読んで判定する**（人間にやらせない）。

`stage_dbg_passive` を1回戦い終えてから開く。

6. **`battle_start` の直後に、味方のパッシブぶんの `status_add` が出ていること**
7. ⚠ **敵のパッシブぶんの `status_add` が、`wave` の行の直後に出ていること**（⚠ **敵も持てることの確認。この回の設計変更の本体**）
8. ⚠ **同じ `status_id` の `status_add` が、1体につき毎フレーム出ていないこと**（走査が `has()` を見ずに毎回 cast していたら溢れる。E75 の `refresh` 必須が効いているかの確認）
9. ⚠ **1波の敵を倒して復活させたとき、`intervene`(death) → `status_end`(`revive_clear`) の**直後**に、その敵のパッシブの `status_add` が**もう一度**出ていること**（§1-3 の本体。**出ていなければ走査が効いていない**）
10. ⚠ **2波に入ったとき、新しい敵にパッシブの `status_add` が出ていること**（ウェーブ交代で敵が作り直される経路）。
    ⚠ **味方のパッシブの `status_add` も出るのが正しい**（**2026-08-17・実測で判明**）。
    ウェーブ交代で **`status_clear` が味方の状態も捨てる**（実測：`{"ev":"status_clear","count":7}`）。
    ⚠ **初稿は「`party_units` は作り直さないから味方のパッシブは消えない」と書いていたが誤り。**
    ユニットは作り直さなくても**状態は消える。** §1-3 の「消える経路」は味方にもウェーブ交代が効く。
11. ⚠ **`stack` の上限**：`skill_dbg_stack_cap` を上限より多く撃ったとき、`status_add` の件数が**上限で止まっていること**。⚠ **絶対値ではなく「撃った回数より少ない」で見る**
12. ⚠ **`damage` / `dot` / `heal` / `status_add` / `status_end` / `cast` / `condition` / `intervene` の行の形が変わっていないこと**

## 7. 完了条件 — **画面**（実機で操作する）

**準備**：冒険選択 →「編成」で**検証用3体**を選ぶ → **`stage_dbg_passive`** に入る。

13. **戦闘が始まった瞬間から、F3 → `P` で味方にパッシブの状態が載っていること**（何も操作していないのに付いている）
14. ⚠ **戦闘画面のスキルボタンに、パッシブが並んで**いない**こと**（別枠なので自然にそうなるはず。並んでいたら `passive_ids` ではなく `skill_ids` に入れている）
15. **育成画面に「パッシブ枠」が出て、スキル枠とは別に選べること**
16. ⚠ **パッシブ枠を空にすると、戦闘でそのパッシブが付かないこと**（§3-4-1。**スキル枠と違って「候補の先頭が勝手に入る」が起きないこと**）
17. ⚠ **既存のセーブでロードしても、育成画面が壊れないこと**（§2-9 の正規化。⚠ **`save_version` を上げていない**）
18. ⚠ **敵が通常攻撃をしてくること**（NEXT_STEPS 2-6 の罠。**パッシブを撃とうとして殴らなくなっていないこと**）
19. **1波の `enemy_dbg_revive` を倒して復活させたあと、F3 → `P` でその敵のパッシブが**まだ載っていること****
20. ⚠ **条件付きパッシブが、条件が真の間だけ効くこと**（F3 → `P` で `active` の切り替わりが見える）
21. ⚠ **`stage_dbg_condition` を1回戦い、条件バフが従来どおり効くこと**（`_condition_value()` を触った影響）
22. ⚠ **`stage_dbg_intervene` を3波とも戦い、復活・免疫・被回復低下が③のとおり効くこと**（走査を1本増やした影響）
23. **本編のステージを1つ戦い、勝てること**（`_scale_value_sum()` の引数が2つ増えた影響）
24. **僧侶の回復が緑・通常のダメージが黄色・毒が紫のままであること**
25. ⚠ **F3 →「4」で速度8倍にしても、パッシブが1体につき1件のままであること**（走査が多重に走っていないこと）

### 7-1. ⚠ 数字の絶対値を期待値にしない

検証用キャラの `atk` は 1 だが**与ダメージは 4**。⚠ **`elapsed_sec` や `alive_count_*` を使ったスキルの威力も、絶対値ではなく「時間が経つと増える」「敵を1体倒すと変わる」という差で見る。**

---

## 8. 終わったあとに足す宿題（`PROJECT_STATUS.md`）

⚠ **書き換えるかは人間の判断。** 設計役は勝手に触らない。

- ⚠ **NEW：`activation` に `passive` が増えた。** ⚠ **`recast` / `toggle` は今も器だけ**（段階5以降）
- ⚠ **NEW：`of` を読まない source が3つになった**（`distance` / `elapsed_sec` / `wave_index`）。`SCALE_SOURCES_NO_OF` に集約したが、**4つ目を足すときは必ずこの配列に入れること**
- ⚠ **NEW：`stack` の上限だけ入れた。残り3つ（消え方・再付与・閾値）は未実装のまま**（宿題6番を縮小して残す）
- ⚠ **NEW：`of: "source"` は「実装しない」と決めて赤にした。** 定数 `SCALE_OF_SOURCE` は残っている。**将来実装するなら E68 を消すところから**
- ⚠ **NEW：パッシブは `dispel` で剥がせない**（走査が次フレームで戻す）。⚠ **「パッシブ無効」を作るなら別の状態として設計する**
- ⚠ **NEW：枠が2種類になった**（スキル枠 ／ パッシブ枠）。⚠ **3種類目を足すときは、複製せず §3-4 の一般化に乗せること**
- ⚠ **NEW：`AGENTS.md` の「GameManagerの状態構造」の表の `CHARACTER_GROWTH` 行に `passives` を足すか、人間の判断**
- ⚠ **NEW：パッシブ枠だけ「未選択なら空」**（スキル枠は候補の先頭が入る・§3-4-1）。**挙動が2つに分かれている**
- ⚠ **NEW：`BattleUnit.is_skill_ready()` が `skill_ids` と `passive_ids` の両方を見る形になった**（`start_cooldown()` は `skill_ids` のまま）。⚠ **この非対称を崩すとパッシブが `REASON_COOLDOWN` で無音で止まる**
- ⚠ **NEW：`characters.json` / `enemies.json` の `"skills"` 配列への書き忘れは今も無音**（③ §2-8 で踏んだ罠）。⚠ **パッシブも同じ配列に載るので、同じ罠が効く**
- **NEW：検証用のもの（`stage_dbg_passive` ／ パッシブ定義 ／ `skill_dbg_stack_cap`）はリリース前に消す**（宿題23番に含める）
- **既存のまま残るもの**：ダメージの介入点の利用者ゼロ（宿題15番） ／ `scale_from` は「和」しか書けない（宿題1番） ／ 購読は `host: unit` のみ（宿題4番・**④-b で埋まる**） ／ DoT の周期ダメージで購読が発火しない（宿題5番）

---

## 9. データ（`.gd` を1行も触らない分）

⚠ **`.gd` より先にデータを入れないこと。** 先に入れるとロード時検証が知らない欄として扱う（③ §9 と同じ）。
⚠ **`.json` はタブインデント**（`stages.json` だけトップレベルが半角スペース2つ）。
⚠ **Windows の bash で `cat >>` すると追記分が CRLF になる。追記したら改行コードを確かめる。**
⚠ **`ja.csv` は UTF-8（BOMなし）。再インポートは人間の作業。**

### 9-1. 既存の `independent` に `max_stack`（⚠ **2026-08-17：設計役が実施済み**）

> ⚠ **当初は Ziva に切り出す前提だったが、人間の指示（「全部あなたで」）により設計役が入れた。**
> **`EXEC_PASSIVE_VARS_ZIVA_CHECK.md` は作っていない。** 以下は「何が入ったか」の記録として読むこと。

**既存の `"stack": "independent"` 9件（5ファイル）に `max_stack: 5` を足した。**
⚠ **これが入るまで E69 でロードが赤になる**（`.gd` を先に入れたため）。

| ファイル | 件数 |
|---|---|
| `characters/char_debug_life/skills.json` | 3 |
| `characters/char_debug_status/skills.json` | 3 |
| `characters/char_debug_mix/skills.json` | 1 |
| `characters/char_priest/skills.json` | 1 |
| `enemies/enemy_dbg_dot/skills.json` | 1 |

⚠ **`.bak` の3件は触らない**（宿題26番。消すのは人間の判断）。
⚠ **§5 のログの突き合わせも同じファイルに入れる。** ⚠ **`battle_last.jsonl` は読ませない**（③と同じ）。

### 9-2. 設計役がやる分

- **味方のパッシブ**：`characters/char_debug_*/skills.json` に `activation: "passive"` の定義を足し、⚠ **`characters.json` の `"passives"` 配列（新設）**に入れる。⚠ **`"skills"` 配列には入れない**（入れるとボタンに並ぶ）
- ⚠ **敵のパッシブ**：`enemies/<id>/skills.json` に同じ形で足し、⚠ **`enemies.json` の `"passives"` 配列（新設）**に入れる（⚠ **この回の設計変更で可能になったもの。必ず1件は作って §6-7 で確かめる**）
- **条件付きパッシブ**：③の `condition` を載せたものを1件（§7-18）
- `skill_dbg_stack_cap`（上限の検証用）と、**戦闘の群の変数を使うスキル1件**
- `stages.json` / `stage_order.json` の `"debug"` 列 — `stage_dbg_passive`
- `ja.csv` — ステージ名・スキル名。⚠ **状態（`status_dbg_*`）には行を足さない**（宿題25番）
