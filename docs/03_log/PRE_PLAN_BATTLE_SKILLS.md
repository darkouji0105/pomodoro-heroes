# 【実装計画書】戦闘画面 フェーズ2（スキルとボス）

ベース：`res://docs/02_exec/EXEC_BATTLE_SKILLS.md`（人間による実行指示書）
- フェーズ1（`EXEC_BATTLE_CORE.md`）完了済み・コミット済み前提
- パーティを3人（剣士・弓兵・僧侶）・スキル6つに拡張する
- `autoload/`, `project.godot`, `.tres`, `ja.csv` の編集は禁止（人間担当）
- 完了条件は EXEC「動作確認手順」の 17 項目をそのまま IMPL_LOG に転記
- 計算式は `SkillResolver` のみ。`unit.gd` と `battle_controller.gd` に書かない（PLAN §7 方針）

---

## 1. 作成・変更するファイル一覧

### 1.1 新規作成

| パス | 役割 |
|---|---|
| `res://resources/balance/master/skills.json` | スキル6件の定義。`name_key` / `type` / `multiplier` / `cooldown_sec` / `user_character_id` を持つ |
| `res://scripts/systems/skill_resolver.gd` | `class_name SkillResolver extends RefCounted` の静的クラス。`static func resolve(skill_data, user, session) -> Array` を1つだけ公開。Autoloadにしない |

`SkillResolver` の置き場は `scripts/systems/`（既存システム群と同列。AGENTS.md のフォルダ構造に整合）。

### 1.2 既存変更（追記のみ。既存行の書き換えは禁止）

| パス | 追記位置 | 追記内容 |
|---|---|---|
| `res://resources/balance/master/characters.json` | 全キャラの末尾に `skills` 配列を追加。`char_priest` ブロックを新規追加 | 剣士に2スキル、弓兵に2スキル、僧侶を新規追加して2スキル |
| `res://resources/balance/master/parties.json` | `party_default.members` を3要素に書き換え（既存2要素からの差替。並び順厳守：剣士→弓兵→僧侶） | `["char_swordsman", "char_archer", "char_priest"]` |
| `res://resources/balance/master/stages.json` | ウェーブ5の敵エントリに `stat_overrides` キー追記 | `"stat_overrides": { "atk": 26 }`（ボス基本値 20 → 26） |
| `res://scripts/systems/master_data_loader.gd` | 末尾に `PATH_SKILLS` / `_cache_skills` 追加。`_ensure_loaded()` に skills.json 読込1行追加。`get_skill()` を追加 | 既存4関数と同じ形式（`push_error` ＋ 空 dict ＋ `duplicate(true)`） |
| `res://scripts/systems/unit.gd` | 末尾に `skill_ids` / `skill_cooldowns` フィールドと `tick_cooldowns()` / `is_skill_ready()` / `start_cooldown()` / `get_cooldown()` の4メソッドを追加 | 既存の `take_damage()` / `heal()` / `is_alive()` / 全フィールドには触らない |
| `res://scenes/adventure/battle_controller.gd` | ① `_init_party_units()` の味方生成直後に `skill_ids` 設定。② `_process()` の末尾にクールダウン進行と `STATE_BATTLE_ACTIVE` 以外での早期 return を1行追加（既にSTATE_BATTLE_ACTIVE ガードはあるので、クールダウン tick をその中に追加するだけ）。③ `_spawn_current_wave_enemies()` の敵生成直前に `stat_overrides` 上書き処理を追加。④ 新規メソッド `_on_skill_button_pressed(unit, skill_id)` と `debug_reset_cooldowns()` を追加。⑤ スキルボタン6つを保持する `_skill_buttons: Array = []` フィールドと `_build_skill_buttons()` メソッドを追加。⑥ `_ready()` 末尾で `_build_skill_buttons()` を呼ぶ | 既存のメソッドシグネチャ・順序を壊さない。`_process` への挿入は「STATE_BATTLE_ACTIVE ガードを通った後、対象再選択より前」 |
| `res://scenes/adventure/battle_debug_panel.gd` | `_unhandled_input` の `match` に `KEY_S` ケースを追加。`_help_label.text` に `[S] スキルCD全リセット` の1行を追加 | 既存のキー割り当て（F3, 1〜4, K, L, J, V, B）は変えない |
| `res://scenes/adventure/battle.tscn` | `HUD`（CanvasLayer）配下に `SkillButtons`（HBoxContainer）を1ノード追加 | 画面下部に配置。アンカー・オフセットはコードで設定するため最小構成でOK |

### 1.3 触らないファイル

- `res://autoload/` 全般（人間担当）
- `res://localization/ja.csv`（§8 翻訳キーを人間が付記する。実装役は触らない）
- `res://resources/balance/` 配下の `.tres`（人間担当）
- `res://addons/ziva_agent/` 等のプラグイン

## 2. BattleUnit に追加するフィールドとメソッド

### 2.1 追加するフィールド（末尾に2行）

```gdscript
# 所持スキルID（順序を保つため配列で持つ。ボタンの並び順になる）
var skill_ids: Array = []
# skill_id -> cooldown_remaining(float)
var skill_cooldowns: Dictionary = {}
```

### 2.2 追加するメソッド（末尾に4つ）

| メソッド | シグネチャ | 仕様 |
|---|---|---|
| `tick_cooldowns` | `(delta: float) -> void` | `skill_cooldowns` 全エントリの値を `delta` だけ減らし、`0.0` を下限とする（`max(0.0, value - delta)`）。負の値にならない |
| `is_skill_ready` | `(skill_id: String) -> bool` | `skill_ids` に含まれていない ID は **`false`** を返す（含まれていないスキルを発動可能と誤判定しない）。含まれている場合は `skill_cooldowns.get(skill_id, 0.0) <= 0.0` を返す |
| `start_cooldown` | `(skill_id: String, sec: float) -> void` | `skill_cooldowns[skill_id] = sec` をセット。`skill_ids` 外の ID は何もしない（発動経路で既にフィルタ済みだが、安全のため） |
| `get_cooldown` | `(skill_id: String) -> float` | `skill_cooldowns.get(skill_id, 0.0)` を返す |

### 2.3 既存フィールド・メソッドを1つも消さないことをどう担保するか

実装時の3つの自己チェック手順：

1. **追記前に `read` で現状ファイルを開く**（78行・末尾の `is_alive()` まで確認する）。追記は `is_alive()` の **後ろ** のみ。`class_name` 直下・`const` 群・`_init()`・`take_damage()`・`heal()` には触らない
2. **追記直後に再度 `read` でファイルを開き、以下を確認する**：
   - 1行目 `class_name BattleUnit extends RefCounted` が変わっていない
   - `const TEAM_PARTY: String = "party"` と `const TEAM_ENEMY: String = "enemy"` が変わっていない
   - `var unit_id` 〜 `var is_boss` の12フィールドが全て残っている
   - `_init()` の引数10個・本体9行が変わっていない
   - `take_damage()` / `heal()` / `is_alive()` が3つとも残っている
3. **既存呼び出し側の不変性**：`_init_party_units()` で `BattleUnit.new(...)` を呼んでいるが、新フィールドはデフォルト値（`[]` と `{}`）で初期化されるため既存呼び出しはそのまま動く。`_init()` のシグネチャを変えないので、ここも破壊しない

### 2.4 敵ユニットには設定しない

`BattleUnit` の新フィールドはクラスに属するが、**値をセットするのは `_init_party_units()` の味方生成直後だけ**。敵生成側（`_spawn_current_wave_enemies()`）では触らない。これにより「敵は `skill_ids` 空配列」のままになり、`is_skill_ready()` は常に `false` を返す。敵にスキルUIを出す経路も存在しないため、副作用なし。

## 3. SkillResolver の設計

### 3.1 クラス宣言

```gdscript
class_name SkillResolver
extends RefCounted
```

Autoload にしない。`MasterDataLoader` と同じ「静的クラス」スタイル。

### 3.2 公開関数（1つだけ）

```gdscript
static func resolve(skill_data: Dictionary, user: BattleUnit, session: BattleSession) -> Array
```

- 戻り値：`Array` of `Dictionary`
- 各要素の形式：`{ "unit_id": String, "amount": int, "is_heal": bool }`
- `unit_id` は効果を受けたユニットの `unit_id`（=`BattleController._views_by_unit_id` のキー）
- `amount` は適用した量（`is_heal: true` なら回復量、偽ならダメージ量）
- **`SkillResolver` は表示（`pop_damage` 等）には一切関与しない**。戻り値を `BattleController` に渡し、そこで `_pop_damage()` を呼んで数値表示する

### 3.3 タイプ別の対象決定と計算

`skill_data["type"]` の値により分岐。`type` が `single` / `aoe` / `heal` / `buff` / `dot` / `projectile` のいずれでも無い場合（マスターデータ不備）は `push_error` を出して空配列を返す。

#### `type == "single"`

1. 対象：`session.get_alive_units(BattleUnit.TEAM_ENEMY)`（敵の生存者）
2. 1体選択：そのうち `user.x` との `abs(x_diff)` が最小の1体
3. 計算：`raw = floor(user.atk * skill_data["multiplier"]) - target.def`、`dmg = max(1, raw)`
4. `target.take_damage(dmg)`
5. 戻り値に `{"unit_id": target.unit_id, "amount": dmg, "is_heal": false}` を1要素 push

#### `type == "aoe"`

1. 対象：`session.get_alive_units(BattleUnit.TEAM_ENEMY)`（敵の生存者 全員）
2. 計算：各ターゲットごとに `raw = floor(user.atk * multiplier) - target.def`、`dmg = max(1, raw)`。**各ターゲット個別に `def` を引く**（フェーズ1通常攻撃と同じ式）
3. `target.take_damage(dmg)` をそれぞれ
4. 戻り値に各ターゲットの dict を push

> 仕様注：`skill_holy_ray` は `type: "aoe"` だが、僧侶の「聖光」は敵全体攻撃という実装になる。`type: "heal"` ではない（EXC §1-3 定義に従う）。`aoe` で誤って味方を殴る事故を防ぐため、対象は必ず `TEAM_ENEMY` 固定のコメントを `SkillResolver` 内に必ず残す

#### `type == "heal"`

1. 対象：`session.get_alive_units(BattleUnit.TEAM_PARTY)`（味方の生存者 全員）
2. 計算：`amount = floor(user.atk * skill_data["multiplier"])`
3. `unit.heal(amount)`（`BattleUnit.heal()` が `max_hp` を超えないことを担保）
4. 戻り値に `{"unit_id": u.unit_id, "amount": amount, "is_heal": true}` を push
5. **使用者自身も対象に含む**（対象は「味方の生存者すべて」）。`user` を特別扱いしない

#### `type` が `buff` / `dot` / `projectile` の場合

```gdscript
push_warning("[SkillResolver] 未実装のスキルタイプ: " + type)
return []
```

- 何もせず空配列を返す（エラーではない、`warning` のみ）
- 将来同じ分岐を実装する人がコードを見て分かるよう、分岐自体は用意する（EXEC §「やらないこと」）

### 3.4 全タイプ共通の防御策

- **対象が0体**（`get_alive_units()` が空）の場合は何もせず空配列を返す。エラーにしない（EXEC §4 末尾）
- **死亡した味方は回復対象にならない**：`get_alive_units()` が `is_alive()` のみでフィルタしているため、自動的に保証される
- **ダメージは必ず `max(1, ...)`** を通す。防御力の高い敵に撃って `0` や負になっても、通常攻撃より弱くならない
- **スキル定義が壊れている場合**（`type` 不在・`multiplier` 不在）は `push_error` を出して空配列を返す。発動ボタン側の `disabled` 制御とは独立

## 4. スキルボタンの生成と状態更新

### 4.1 ノード配置

`battle.tscn` の `HUD`（CanvasLayer）配下に `SkillButtons`（HBoxContainer）を1ノード追加。アンカー・オフセットは下端中央付近を `primary_button.tscn` のインスタンス化後にコードで整える（HBoxContainer の中身は中央寄せ）。

### 4.2 ボタンの生成手順

`BattleController._build_skill_buttons()` を新設し、`_ready()` 末尾（`_enter_wave_intro()` の直前）で1回だけ呼ぶ。`_init_party_units()` の中で呼ばない理由：味方がリトライで再生成されたとき、ボタンも作り直されるため → クールダウンを巻き戻す仕様（EXEC §5-6「もう一度」項）と整合する

1. `_skill_buttons = []` で初期化
2. `_session.party_units` を順に走査
3. 各 `unit` について `unit.skill_ids` を順に走査
4. 1スキルにつき以下を行う：
   - `var btn: Button = PRIMARY_BUTTON_SCENE.instantiate()`（`primary_button.tscn` の `PackedScene` 定数を `UNIT_VIEW_SCENE` の隣に置く）
   - `btn.text = tr(skill_data.name_key)`（初期テキスト）
   - `btn.custom_minimum_size = Vector2(120, 48)` 程度（6つ並ぶ幅を確保）
   - `btn.pressed.connect(_on_skill_button_pressed.bind(unit, skill_id))` … ではなく、**Callable を直接生成**：`var cb := Callable(self, "_on_skill_button_pressed").bind(unit, skill_id)` を `_skill_buttons` 配列に `{ "button": btn, "user": unit, "skill_id": skill_id, "callback": cb }` の Dictionary で記録
   - `SkillButtons.add_child(btn)`
5. **Dictionary で保持する理由**：アレイ要素にCallableを直接入れると `bind` の管理が難しくなる。`{user, skill_id, callback}` の3点セットを1要素にすることで、`pressed.disconnect(callback)` も可能になり、リトライ時のクリーンアップが楽になる

### 4.3 ボタンの並び順

`_init_party_units()` が `members` の順で `_session.party_units` に append している（`for i in range(members.size())`）。`members = ["char_swordsman", "char_archer", "char_priest"]` なので、ボタンは必ず

```
[剣士スキル1: 強撃][剣士スキル2: 横薙ぎ][弓兵スキル1: 狙撃][弓兵スキル2: 矢の雨][僧侶スキル1: 癒しの光][僧侶スキル2: 聖光]
```

の順に並ぶ。完了条件2と一致する。

### 4.4 disabled にする条件（漏れなく列挙）

`_process(delta)` の中で `_skill_buttons` の各要素について以下の判定を毎フレーム行う。**いずれかに該当すれば `disabled = true`、全なければ `false`**。

| # | 条件 | 理由 |
|---|---|---|
| ① | `unit.is_skill_ready(skill_id) == false`（クールダウンが残っている） | 基本。残り時間 > 0 は撃てない |
| ② | `unit.is_alive() == false`（使用者が死亡している） | 死体からスキルは出ない |
| ③ | `_session.state != BattleSession.STATE_BATTLE_ACTIVE` | 結果画面表示中・ウェーブ間0.5秒の待機中・ウェーブクリア演出中に発動を抑止。これが無いと**何も起きないままクールダウンだけ消費される**報告されにくいバグになる（EXEC §5-4 強調） |
| ④ | `user == null` または `skill_id` が現在そのユニットの `skill_ids` に無い | リトライ直後など、参照が古い場合の安全弁 |

**③を忘れないこと**が最重要。`STATE_WAVE_INTRO`（0.5秒の演出中）・`STATE_WAVE_CLEAR`（次ウェーブへの遷移中）・`STATE_VICTORY` / `STATE_DEFEAT`（結果画面表示中）のいずれでも、`disabled = true` にする

### 4.5 テキスト更新

`_process` の中で `disabled` 判定とセットで行う。

```gdscript
var cd: float = unit.get_cooldown(skill_id)
if cd > 0.0:
	btn.text = tr(skill_data.name_key) + " (" + format("%.1f", cd) + ")"
else:
	btn.text = tr(skill_data.name_key)
```

`name_key` は `MasterDataLoader.get_skill(skill_id)["name_key"]` で取得。**`_build_skill_buttons()` で先に辞書引きして、各ボタンの dict 要素に `"name_key": String` を追加保持しておく**ことで毎フレームの `get_skill()` 呼び出しを回避（6回 × 60fps = 360回/秒のJSON参照を避ける）

`format("%.1f", cd)` の数値部分は `tr()` を通さない（AGENTS.md「`tr()` を使わないもの：数値のみの表示」）。

## 5. スキル発動時の処理順序

### 5.1 ハンドラ

`BattleController._on_skill_button_pressed(user: BattleUnit, skill_id: String)` を新設。`bind` で第1・第2引数を固定する。

### 5.2 処理順序（厳守）

`pressed` シグナルが飛んできた直後、**以下の順で早期 return しながら**進む。途中 return した場合、副作用は一切残らない。

```
1. _session が null でないか / _result_applied が false か（防御）
2. _session.state が STATE_BATTLE_ACTIVE か
3. user.is_alive() == true か
4. user.is_skill_ready(skill_id) == true か（クールダウンが完了しているか）
5. skill_data = MasterDataLoader.get_skill(skill_id)
6. skill_data が空でないか（マスターデータ不備）
7. results = SkillResolver.resolve(skill_data, user, _session)
8. results の各要素を走査：
	 _pop_damage(_find_unit_by_id(elem["unit_id"]), elem["amount"])
   ※_pop_damage は is_alive() を見ていない（フェーズ1実装）。死亡したユニット
	に対する pop_damage は view 側 hide() 済みで何も表示されないため問題なし
9. user.start_cooldown(skill_id, skill_data["cooldown_sec"])
```

### 5.3 クールダウン開始のタイミング — 必ず **最後**

**ステップ9を必ず最後に行う。** `SkillResolver.resolve()` が空配列を返した場合（対象が0体だった・`type` が未実装等）でも、クールダウンは入れる必要があるかどうか迷う場面が出る。これに対しては仕様で「**入れる**」と決める（EXEC §5-5「先に開始してから resolve で対象なしと分かると、何も起きていないのにクールダウンだけ入る」）。理由：

- 対象が0体の状況は「敵が全滅した直後に押した」「味方が全滅した直後に押した」など、**状態が壊れている場面だけ**。正常な操作では起きない
- 連打による「無料でリキャスト短縮」を防ぐ方が、状態不整合の対策より優先度が高い
- 対象が0体でも`SkillResolver`は空配列を返すだけで例外は出さないため、ステップ9が**いつ実行されても安全**

### 5.4 勝敗判定をここで行わない理由

スキル発動で敵が全滅しても、**このハンドラでは `_enter_wave_clear()` も `_enter_victory()` も呼ばない。**

理由：勝敗確定の経路が2本になると、フェーズ1で潰した「報酬の二重適用」が別ルートから復活する。具体的には：

- 経路A（既存）：`_process()` 末尾の `is_wave_cleared()` チェック → `_enter_wave_clear()` → （最終ウェーブなら）`_enter_victory()` → `_result_applied = true`
- 経路B（新規）：スキルで敵を全滅 → 即座に `_enter_victory()`

スキルで全滅した直後のフレームに `_process()` が走ると、経路Aの `is_wave_cleared()` も `true` を返す。ここで `_result_applied` フラグが無ければ、`apply_battle_rewards()` と `mark_stage_cleared()` が2回呼ばれてしまう。

`SkillResolver` 経由でも `_process` 経由でも、必ず `_process` の既存判定を通すことで、勝敗確定が**常に1箇所**で行われる。`_result_applied` フラグが二重適用を防ぐ最終防壁だが、そもそも経路を1つに絞ったほうが安全。

### 5.5 数値表示の注意

`_pop_damage()` は `pop_damage(amount)` を呼び、内部で `Label.new()` → `parent.add_child()` → `tween.queue_free` を行う。これは戦闘中なら安全に動く。スキルでも同じ関数を使う。**`SkillResolver` 側に `Label` や `Tween` の生成は持たせない**（表示責務は `UnitView`、呼び出しは `BattleController`）。

### 5.6 クールダウンの進行（`_process` 内）

`_process(delta)` の **STATE_BATTLE_ACTIVE ガードを通った直後**、対象再選択より前に以下を挿入：

```gdscript
for unit in _session.party_units:
	if unit is BattleUnit and unit.is_alive():
		unit.tick_cooldowns(delta)
```

`tick_cooldowns()` は `0.0` を下限にするので、`STATE_BATTLE_ACTIVE` 以外の状態では呼ばれない（毎フレームガードがある）。これでウェーブ間（`STATE_WAVE_CLEAR` 状態）でもクールダウンは止まり、**完了条件14の「次ウェーブでも減り続けている」を満たすには逆にここを止めないといけない**……が、よく読むと `STATE_BATTLE_ACTIVE` 中だけ進む仕様は完了条件14と矛盾する。

**確認**：完了条件14は「`L` で敵を全滅させ、直前に使ったスキルの残り時間が次ウェーブでも減り続けていることを確認する」と読める。`_enter_wave_clear()` で `_session.state = STATE_WAVE_CLEAR` になり、0.5秒の `_enter_wave_intro()` 待機に入る。この間 `STATE_BATTLE_ACTIVE` ではない。**完了条件14を満たすには、`_process` のガードを `STATE_BATTLE_ACTIVE` だけでなく `STATE_WAVE_INTRO` にも広げる必要がある**。

→ この判断は **「判断に迷った点」セクション7 に転記**。実装フェーズで人間に確認する（`STATE_WAVE_INTRO` 中にクールダウンを進行させるかどうか）。

## 6. stat_overrides の適用方法

### 6.1 適用箇所

`BattleController._spawn_current_wave_enemies()` の `for n in range(count)` ループ内、`BattleUnit.new(...)` を呼ぶ **直前** に上書き変数を計算する。

### 6.2 具体的な差し込み位置

`battle_controller.gd:217-234` 付近の構造（抜粋）：

```gdscript
# 既存
var enemy_data: Dictionary = MasterDataLoader.get_enemy(enemy_type_id)
if enemy_data.is_empty():
	push_error("[Battle] enemy not found: " + enemy_type_id)
	continue

for n: int in range(count):
	# ★★★ ここに上書き計算を差し込む ★★★
	var unit: BattleUnit = BattleUnit.new(
		"enemy_%d_%d" % [...],
		BattleUnit.TEAM_ENEMY,
		str(enemy_data.get("name_key", "")),
		int(enemy_data.get("hp", 0)),  # ← ここを overrides 込みの値に
		...
	)
```

差し込む内容は以下の通り（`int(enemy_data.get(...))` をすべて経由するため、`.duplicate(true)` の心配は不要）：

```gdscript
# stat_overrides の適用（EXEC §6-1）
var overrides: Dictionary = (entry.get("stat_overrides", {}) as Dictionary)
func _override(key: String, default_value: Variant) -> Variant:
	return overrides.get(key, default_value)
```

そして `BattleUnit.new(...)` の引数を `int(_override("hp", enemy_data.get("hp", 0)))` 形式に書き換える。`hp` を上書きした場合は `BattleUnit._init()` 内で `max_hp = p_max_hp; hp = p_max_hp` が両方セットされるため、HPバーが最初から満タンでなくなる挙動が自然に出る（EXEC §6-1）。

### 6.3 対応キー一覧

| 上書き対象 | JSONのキー | `BattleUnit` のフィールド |
|---|---|---|
| HP | `hp` | `max_hp` / `hp`（`_init` で同時セット） |
| 攻撃力 | `atk` | `atk` |
| 防御力 | `def` | `def` |
| 速度 | `spd` | `speed`（`BattleUnit._init` の引数名は `p_speed`） |
| 射程 | `attack_range` | `attack_range` |
| 攻撃間隔 | `attack_interval_sec` | `attack_interval_sec` |

### 6.4 既存コードの書き換え

`int(enemy_data.get("hp", 0))` のような **式ごと** 上書きする。元の式を残したまま上書きを重ねる実装（例：`unit.max_hp = overrides.get("hp", enemy_data.hp)`）はしない。理由：上書き忘れが目視で確認しづらくなるため。

### 6.5 `stages.json` のウェーブ5への追記

`stage_1.waves[4].enemies[0]`（ボス）に `"stat_overrides": { "atk": 26 }` を追加。既存フィールド（`enemy_type_id` / `count` / `is_boss`）はそのまま。**`stages.json` の他のウェーブには触らない**。`is_boss: true` のエントリは1行しかないため、位置の特定は容易。

`stat_overrides` が無いウェーブは `_override()` が `default_value` を返すので、既存挙動を完全に保つ。

### 6.6 ボスの見た目（サイズ1.5倍）

`UnitView.setup()` の `if unit.is_boss:` ブロック内で、`Body` と `HpBar` の `size` を 1.5倍にする。色は変更しない（EXEC §6-2「新しい色を足さない」）。`Body` は `ColorRect`、`HpBar` は `ProgressBar`。両者とも `size` プロパティで `Vector2(96, 96)` / `Vector2(96, 12)` 程度になる（基本 64×64 / 64×8 の1.5倍）。

- `name_label` のサイズは触らない（名前の長さは変えない）
- `position` は `setup()` 末尾の `position.x = unit.x` だけ。`offset_*` の書き換えは子ノード側で行う
- 死亡時の `hide()` 動作は変えない

### 6.7 既存コードの改変位置

| ファイル | 改変位置 | 改変内容 |
|---|---|---|
| `scenes/adventure/unit_view.gd` | `setup()` 内、`if unit.is_boss:` ブロック | `body.size = Vector2(96, 96)` と `hp_bar.size = Vector2(96, 12)` を追加。`body.color` の1行はそのまま |
| `resources/balance/master/stages.json` | ウェーブ5の enemies[0] | `"stat_overrides": { "atk": 26 }` を1キー追加 |
| `scenes/adventure/battle_controller.gd` | `_spawn_current_wave_enemies()` の `for n in range(count):` 直前〜`BattleUnit.new(...)` 呼び出し | `_override()` ローカル関数と引数の上書き |

## 7. 判断に迷った点

実装に入る前に人間に確認したい判断ポイント。実装時に決め打ちで進めると手戻りが大きいもの。

### 7.1 完了条件14と STATE_BATTLE_ACTIVE ガードの整合性

**問題**：完了条件14は「ウェーブが切り替わったとき、スキルのクールダウンがリセットされていない」「`L` で敵を全滅させ、直前に使ったスキルの残り時間が次ウェーブでも減り続けていることを確認する」と読める。

現在の `_process(delta)` は `if _session.state != BattleSession.STATE_BATTLE_ACTIVE: return` で早期 return している。`_enter_wave_clear()` で `STATE_WAVE_CLEAR` に遷移し、`_enter_wave_intro()` で `STATE_WAVE_INTRO` に戻る。**この遷移中（典型的には 0.5秒 + α）に `tick_cooldowns()` が呼ばれない**。

完了条件14を文字通り読むと「次ウェーブでも減り続けている」を確認する必要がある。`_enter_wave_intro()` の中の `await get_tree().create_timer(0.5)` の間も減っていてほしい。

**選択肢**：
- A. `_process` の `STATE_BATTLE_ACTIVE` ガードを緩め、`STATE_WAVE_CLEAR` / `STATE_WAVE_INTRO` でも `tick_cooldowns()` を呼ぶ。戦闘ロジック（対象選択・攻撃・勝敗判定）は従来どおり `STATE_BATTLE_ACTIVE` 限定のまま
- B. 完了条件14を「`STATE_BATTLE_ACTIVE` 中に減り続けている」と読み替え、ウェーブ間0.5秒は停止でも仕様とする。EXC §5-6「ウェーブ間でクールダウンをリセットしないこと」と「減り続けている」が別物かどうかで解釈が変わる
- C. 完了条件14を満たすには、`_enter_wave_intro()` の待機中も `tick_cooldowns()` を毎フレーム呼ぶよう、`_enter_wave_intro()` の中で `delta` 累積して対応する

→ **A を採用するのが安全**（完了条件14の自然な読み方に一致）。`tick_cooldowns()` だけ別ガードにする実装を提案する。実装フェーズで人間に再確認する

### 7.2 ボタン保持の構造

スキルボタンの情報を `_skill_buttons: Array[Dictionary]` で持つ案と、`_skill_buttons: Array[Array]`（ボタンのみ連想配列は別）で持つ案がある。

- 前者：`{ "button": btn, "user": unit, "skill_id": id, "callback": cb, "name_key": key }` の Dictionary 要素
- 後者：ボタンのみ配列、user/skill_id は `_skill_user_by_button: Dictionary` で別途管理

**前者の方が `_process` 内のループが1回で済む**ため採用したい。Dictionary 1要素に情報を寄せる。メモリは 6要素 × 数十バイトなので無視できる

### 7.3 僧侶の `skill_holy_ray` の `type` 設定

EXEC §1-3 では `skill_holy_ray` は `type: "aoe"`、`skill_healing_light` は `type: "heal"` と定義されている。**「聖光」は敵全体にダメージのAoE**で、回復スキルではない。実装はEXECに厳密に従う。

完了条件10〜12は「`heal` タイプが正しく動くか」を確認する項目なので、検証対象は `skill_healing_light` のみ。`skill_holy_ray` は戦闘ログとデバッグパネルの `atk 26` ボス（`stat_overrides`）相手に確認すれば良い

### 7.4 `primary_button.tscn` を流用するか否か

EXEC §5-2 で「`primary_button.tscn` をインスタンス化する」と明示されている。これは戦闘画面以外でも使う全画面共通コンポーネントだが、スキルボタンに **クールダウン数値を毎フレーム上書きする** 使い方は想定外。

`PrimaryButton` クラスは `label_key` をセットすると `text = tr(label_key)` が走る setter を持つ（`primary_button.gd:7-11`）。`label_key = ""` にして `text` を直接いじる分には問題ない。**`label_key` は空文字のまま**にし、毎フレーム `btn.text = ...` を上書きする

完了条件2でボタンの並び順が「強撃」「横薙ぎ」「狙撃」「矢の雨」「癒しの光」「聖光」と指定されている。`tr()` を通して日本語表示になるのは `ja.csv` に §8 のキーが追記された後の話（人間作業）

### 7.5 ボタンの幅と画面解像度

6つのボタンを画面下部に並べる。`primary_button.tscn` の Button は最小サイズ未指定なので、custom_minimum_size を `Vector2(120, 48)` に設定する想定。6 × 120 = 720px。デフォルトの 1152×648 ビューでは十分収まる（中央寄せ + `HBoxContainer.alignment = BOX_ALIGNMENT_CENTER`）。

ただしリサイズ時の挙動は未検討。今回は固定ウィンドウ想定で進める

### 7.6 `BattleSession.party_units` の型ヒント

`BattleSession.party_units: Array = []` は要素型未定。実装中も `for unit in _session.party_units:` で `unit is BattleUnit` チェックを毎回行う既存スタイルを踏襲する。**型ヒントを `Array[BattleUnit]` に変える改善は今回触らない**（フェーズ1のスタイルに合わせる）

### 7.7 `_init_party_units()` 内のスキル設定タイミング

味方を `BattleUnit.new()` した直後、`_session.party_units.append(unit)` の **前** にスキルを設定する。理由：append 後に設定しても動くが、append 前に設定する方が「ユニット生成時に全てのパラメータが確定している」可読性で勝る。append 後にすると「リストに何を入れるか」と「リストに入れた後に何を足すか」が分離して読みにくい

### 7.8 `BattleUnit.skill_ids` への `char_data["skills"]` の代入

`char_data["skills"]` は JSON 由来で `Array` 型。`unit.skill_ids = char_data.get("skills", [])` でコピーされる（`Dictionary.get()` は値を返すだけで参照コピーだが、Array の要素は String なので浅いコピーで実害なし）。`unit.skill_cooldowns` は空 Dictionary のまま初期化される（`_init()` ではなく宣言のデフォルト値）

### 7.9 `is_skill_ready` の `skill_ids` 外のID対応

EXEC §3 に「`skill_ids` に無いIDを渡された場合、`is_skill_ready` は `false` を返す」とある。`Dictionary.has()` または `in` 演算子で確認。`has()` は O(1)、`in` も O(1) なのでどちらでも良い。**`in` 演算子の方が見た目が短くなる**ため採用

### 7.10 `BattleDebugPanel._help_label` の更新

`_help_label.text` を `_ready()` 時に1回だけセットしている。`S` キー追加時は1行加えるだけ。`_process` 毎の書き換えはしない。`info_label` だけ毎フレーム更新する既存構造を維持

### 7.11 `debug_reset_cooldowns()` の実装

```gdscript
func debug_reset_cooldowns() -> void:
	if _session == null:
		return
	for u in _session.party_units:
		if u is BattleUnit:
			for skill_id in u.skill_ids:
				u.start_cooldown(skill_id, 0.0)
	print("[BattleDebug] 全味方のスキルクールダウンをリセット")
```

`start_cooldown(id, 0.0)` で全スキルを即座に撃てる状態に戻す。`is_skill_ready()` は `0.0 <= 0.0` で `true` を返す

### 7.12 完了条件の検証方法

17項目のうち、以下は `BattleDebugPanel` の `S` キーを使う前提で楽：
- 7（クールダウン表示）→ スキル使用後 12秒スキル（`skill_holy_ray`）で残り時間表示
- 8（連打）→ `S` でリセットして再テスト
- 9（独立クールダウン）→ `S` なしでも確認可
- 10〜12（heal）→ `J` でHP削ってテスト

`S` キーは **12秒クールダウンを何度も試す** ための支援（EXEC §7 の理由）。`skill_holy_ray` 12秒は検証の待ち時間が長いため

### 7.13 `SkillResolver` の `type` 判定のディスパッチ

`match` 文を使う案と `if/elif` 連鎖の案がある。GDScript 4 の `match` は `Dictionary` の値比較が不得意（`match` はパターンマッチで `==` ではない）。

```gdscript
match skill_data.get("type", ""):
	"single": ...
	"aoe": ...
	"heal": ...
	_: push_warning(...); return []
```

String リテラルとの比較なら `match` で問題ない。**`match` を採用**する（読みやすさ）

### 7.14 翻訳キーの `ui_battle_char_priest` の ja.csv への追加

実装役は `ja.csv` を触らない。完了条件2でボタンの並び順を「強撃」「横薙ぎ」「狙撃」「矢の雨」「癒しの光」「聖光」と指定しているが、**これは `tr()` 適用後の表示**。`ja.csv` にキーが無いと `tr()` はキー文字列をそのまま返す（AGENTS.md）。**§8 の7キーが人間によって ja.csv に追記されるまで、ボタンには `ui_battle_skill_power_slash` 等が表示される**。これは想定済み（AGENTS.md「これは意図した挙動として許容する」）

実装完了時に `ja.csv` に未追記であることを検出し、IMPL_LOG に「人間作業待ち」と明記する

## 8. 人間による決定事項（実装時はここを最優先で従うこと）

§1〜§7 と矛盾する場合は **この章を優先する。**

### 8-1.【決定】tick_cooldowns() の進行範囲 → 選択肢B

EXEC §5-6 のとおり、STATE_BATTLE_ACTIVE のときだけ
tick_cooldowns(delta) を呼ぶこと。§7.1 の選択肢Aは採用しない。

理由：「戦闘中だけ時間が進む」というルールを1本に保つため。
状態ごとに進む・進まないの例外リストを作ると、
今後 一時停止・結果画面・演出待ちが増えるたびに
判断が必要になり、いずれ食い違う。

ウェーブ紹介の0.5秒間はクールダウンが止まるが、これは仕様とする。
誰も行動できない時間なので、止まっていて不都合はない。

完了条件14は矛盾ではなく、文言が曖昧だった。
以下に読み替えて検証すること。

  14. ウェーブが切り替わったとき、スキルのクールダウンが
	  リセットされていない（L で敵を全滅させ、直前に使った
	  スキルの残り時間が、次ウェーブ開始時に 0 や初期値に
	  戻っていないことを確認する。ウェーブ紹介の 0.5 秒間だけ
	  残り時間が止まって見えるのは正しい挙動）

### 8-2.【要修正】リトライ時にスキルボタンを作り直すこと

_build_skill_buttons() を _ready() で1回だけ呼ぶ設計は不十分。

_on_retry_pressed() → _init_session() → _init_party_units() で
味方の BattleUnit は作り直される。ボタンが保持している user 参照は
古い BattleUnit のままになり、押しても新しいユニットには効かない。
見た目には「押せるのに何も起きない」状態になり、報告されにくい。

対応：_init_party_units() の直後に _build_skill_buttons() を呼ぶこと。
_ready() と _on_retry_pressed() の両方の経路で通るようにする。

_build_skill_buttons() の先頭で、既存のボタンを必ず破棄すること。

  1. 保持している配列の各ボタンを queue_free()
  2. 配列を clear()
  3. SkillButtons コンテナの get_children() も queue_free()
  4. そのうえで新しく生成する

queue_free() は遅延実行のため、直後に get_child_count() で
0 になったことを確認しないこと。フェーズ1の
_spawn_current_wave_enemies() と同じ考え方で書くこと。

### 8-3.【明確化】_ready() の実行順序

フェーズ1の _ready() の構造を変えないこと。
_init_session() を新設したり、既存の初期化処理を
関数に切り出し直したりしないこと。

現在の _ready() は BattleSession を直接 new してから
_init_party_units() を呼ぶ形になっている。
その直後に _build_skill_buttons() を1行足すだけでよい。

### 8-4.【承認】debug_reset_cooldowns() の実装

§7.11 のとおり、_session.party_units の全ユニットについて
skill_ids に含まれるスキルの残り時間を 0 にする形でよい。

### 8-5. そのまま採用する判断

以下は実装役の判断が正しい。計画のまま進めてよい。

- §2.2 skill_ids に無いIDでは is_skill_ready が false を返す
- §2.4 敵には skill_ids を設定しない
- §3.3 計算式を SkillResolver にのみ置く
- §3.3 回復は使用者自身も対象に含む
- §3.4 対象が0体なら空配列を返しエラーにしない
- §4.4 disabled の条件3つ（クールダウン・使用者死亡・戦闘中でない）
- §5.3 クールダウンの開始を resolve のあと、最後に行う
- §5.4 スキル発動時に勝敗判定をしない
- §5.6 クールダウン中の連打をガードする
- §6.2 stat_overrides を BattleUnit.new() の引数の時点で反映する
- §6.6 ボスは Body と HpBar のサイズのみ1.5倍にし、色は既存を使う
- §7.4 primary_button.tscn の label_key を使わず text を直接セットする
