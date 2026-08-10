# 【実装計画書】戦闘画面 フェーズ1（骨格）

ベース：`res://docs/02_exec/EXEC_BATTLE_CORE.md`（人間による実行指示書）
- `autoload/`, `project.godot`, `.tres` の編集禁止
- `ja.csv` への追記は人間の作業
- 完了条件は §「動作確認手順」の 19 項目をそのまま IMPL_LOG に転記

---

## 1. 作成するファイル一覧（パスと役割）

### 1.1 マスターデータ（JSON）

EXEC §1 に基づき、`res://resources/balance/master/` 配下に4ファイル。

| パス | 役割 |
|---|---|
| `resources/balance/master/characters.json` | 味方キャラのステータス（swordsman / archer）。`name_key` を含む |
| `resources/balance/master/enemies.json` | 敵のステータス（slime / wolf / slime_king）。`is_boss` 読み込み元 |
| `resources/balance/master/parties.json` | パーティ構成。`party_default` のみ（members: [char_swordsman, char_archer]） |
| `resources/balance/master/stages.json` | ステージ定義。`stage_1` のみ。waves に 5 ウェーブ分の敵構成を持つ |

`.tres` ではなく `.json` を使う点が PLAN_BATTLE_SCREEN.md と異なる（EXEC §1 決定）。理由：データをコードから文字列リテラル的に書ける形式で、ID 引きに向くため。

### 1.2 スクリプト

| パス | 役割 | 種別 |
|---|---|---|
| `scripts/systems/master_data_loader.gd` | 4 つの JSON を読み込み ID で引く静的クラス。`load()` 方式を主、`FileAccess` 方式を副とする。**どちらで動いたかを IMPL_LOG に書く**（EXPORT 対応のため） | 新規 |
| `scripts/systems/unit.gd` | `class_name BattleUnit extends RefCounted`。`team` は `TEAM_PARTY` / `TEAM_ENEMY` の `const` で持つ。フィールド・メソッドは EXEC §3 の通り（hp 直接書き換え禁止） | 新規 |
| `scripts/systems/battle_session.gd` | `class_name BattleSession extends RefCounted`。状態 5 種を `const` で定義。`_process` を持たない | 新規 |
| `scenes/adventure/unit_view.gd` | `UnitView` のスクリプト。`setup(unit)` で初期化、`_process(delta)` で `position.x` と `HpBar.value` を同期 | 新規 |

### 1.3 シーン

| パス | 役割 |
|---|---|
| `scenes/adventure/battle.tscn` | 戦闘画面。EXEC §6 のノード階層（Background / PartyUnitsContainer / EnemyUnitsContainer / HUD/WaveLabel / ResultView{ResultLabel, RewardLabel, RetryButton, BackButton}） |
| `scenes/adventure/unit_view.tscn` | `UnitView` のノード構成（Body:ColorRect 64x64 / HpBar:ProgressBar 幅64高さ8 / NameLabel:Label） |

### 1.4 触らないファイル

- `autoload/game_manager.gd`：`apply_battle_rewards()` と `mark_stage_cleared()` は人間追記済み
- `autoload/scene_manager.gd` / `autoload/signal_bus.gd`：完成済み
- `scripts/utils/transfer_keys.gd`：`STAGE_ID` / `PARTY_ID` / `STAGE_TYPE` 追記済み
- `scripts/utils/state_keys.gd`：`BATTLE_VICTORY` / `BATTLE_WAVES_CLEARED` / `BATTLE_REWARDS` / `STAGE_TYPE_STORY` / `STAGE_TYPE_TRAINING` 追記済み
- `res://scenes/base/base_screen.tscn`：SCREEN_SCENES 差し替え済み
- `res://resources/balance/initial_state_config.tres`：`adventure_select` アンロック追加済み
- `res://localization/ja.csv`：§8 翻訳キーの追記は人間作業

### 1.5 やらないこと（EXEC §「やらないこと」より）

- スキル（フェーズ2）
- ボスの見た目区別（`is_boss` は読み込むだけ）
- スタミナ消費
- パーティ選択・冒険選択画面
- 演出・アニメーション・効果音
- ステージ 2 以降のデータ


---

## 2. MasterDataLoader の読み込み方式

### 2.1 方針：EXEC §2 準拠（load() を主、FileAccess を副）

**第1試行（load 方式）：** Godot 4 は `.json` を `JSON` リソースとしてインポートするため、以下で Dictionary が取れる。
```
var res: JSON = load("res://resources/balance/master/characters.json") as JSON
var data: Dictionary = res.data as Dictionary
```

**第2試行（FileAccess 方式）：** 上記が `null` を返した場合のみ、`FileAccess.open(path, FileAccess.READ)` + `JSON.parse_string(text)` に切り替える。

**判定は初回ロード時に1回だけ行う。** どちらで成功したかを `static var _load_mode: String` に記録し、IMPL_LOG に書く（EXPORT 時に `.json` を含めるフィルタ設定が必要か人間が決めるため）。

### 2.2 キャッシュ戦略

- 4 ファイルそれぞれに対応する `static var _cache_<name>: Dictionary` を持つ
- 初回 `get_*` 呼び出し時にロード、以降はキャッシュを返す
- キャッシュにヒットしない ID が引かれた場合：`push_error("[MasterDataLoader] id not found: <id>")` を出して空 Dictionary を返す（黙って握りつぶさない）
- ファイル自体が無い / パース失敗：`push_error` を出して空 Dictionary を返す
- 返す Dictionary は `duplicate(true)`（呼び出し側が書き換えられないように）

### 2.3 公開 API

```
static func get_character(id: String) -> Dictionary      # characters.json
static func get_enemy(id: String) -> Dictionary          # enemies.json
static func get_party(id: String) -> Dictionary          # parties.json
static func get_stage(id: String) -> Dictionary          # stages.json
```

すべて `Dictionary` を返す。型キャストは呼び出し側が行う。

### 2.4 Autoload にしない理由

EXEC §2 に明記。Autoload は 5 つ固定のルールで、本ローダーは戦闘中しか呼ばれない。`MasterDataLoader.get_stage("stage_1")` のように静的呼び出しする。

### 2.5 IMPL_LOG への記載事項

「どちらの方式で動いたか」＋「第2試行に切り替えた場合は理由（エラーメッセージ）」を必ず書く。`FileAccess` 方式で動いた場合、EXPORT 時に JSON をフィルタに含めるよう人間に依頼する必要がある。


---

## 3. BattleUnit と BattleSession のフィールド・メソッド一覧

EXEC §3, §4 に厳密準拠。前回 PRE_PLAN との差分を反映する。

### 3.1 BattleUnit（`scripts/systems/unit.gd`）

```gdscript
class_name BattleUnit
extends RefCounted
```

`class_name` は **`BattleUnit`**。`Unit` ではない（EXEC §3 注：将来他用途・Godot 組み込みと衝突するため）。

#### 定数

```
const TEAM_PARTY: String = "party"
const TEAM_ENEMY: String = "enemy"
```

文字列リテラルを直書きしないため、`team` 代入時もこの const を使う。

#### フィールド

| 名前 | 型 | 備考 |
|---|---|---|
| `unit_id` | `String` | 生成時に一意に振る。味方は `"party_0"` / `"party_1"`、敵は `"enemy_<wave_index>_<連番>"` |
| `team` | `String` | `TEAM_PARTY` または `TEAM_ENEMY` |
| `unit_name_key` | `String` | 翻訳キー。UnitView 側で `tr()` する |
| `hp` | `int` | 現在 HP |
| `max_hp` | `int` | 最大 HP（不変） |
| `atk` | `int` | 素の攻撃力 |
| `def` | `int` | 防御力 |
| `atk_multiplier` | `float` | 装備補正。本フェーズでは常に `1.0` |
| `attack_range` | `float` | 射程（px） |
| `attack_interval_sec` | `float` | 通常攻撃のクールダウン秒数 |
| `speed` | `float` | 秒あたりの移動 px |
| `x` | `float` | **1次元。y 方向は移動しない** |
| `target_unit_id` | `String` | 未設定は **`""`**（`null` 禁止、型が揺れる） |
| `attack_timer` | `float` | 次の攻撃までの秒数 |
| `is_boss` | `bool` | 見た目用フラグ。ロジック上は通常ユニットと区別しない |

#### メソッド

- `_init(unit_id, team, unit_name_key, max_hp, atk, def, attack_range, attack_interval_sec, speed, is_boss=false) -> void`
  - 内部で `hp = max_hp`、`attack_timer = 0.0`、`target_unit_id = ""`、`atk_multiplier = 1.0` に初期化
- `take_damage(amount: int) -> void`
  - `hp = max(0, hp - amount)`。`amount <= 0` は何もしない
- `heal(amount: int) -> void`
  - `hp = min(max_hp, hp + amount)`
- `is_alive() -> bool`
  - `hp > 0`

**`hp` を外から直接書き換えない。** 必ず `take_damage()` / `heal()` 経由。

### 3.2 BattleSession（`scripts/systems/battle_session.gd`）

```gdscript
class_name BattleSession
extends RefCounted
```

#### 定数（状態）

```
const STATE_WAVE_INTRO: String = "wave_intro"
const STATE_BATTLE_ACTIVE: String = "battle_active"
const STATE_WAVE_CLEAR: String = "wave_clear"
const STATE_VICTORY: String = "victory"
const STATE_DEFEAT: String = "defeat"
```

文字列リテラルを直書きしない。

#### フィールド

| 名前 | 型 | 備考 |
|---|---|---|
| `stage_id` | `String` | |
| `stage_type` | `String` | `GameStateKeys.STAGE_TYPE_STORY` |
| `party_id` | `String` | |
| `state` | `String` | 上記 5 状態のいずれか |
| `current_wave` | `int` | **1 始まり**（EXEC §4 表記） |
| `total_waves` | `int` | `stages.json` の `waves` 要素数から取る。**5 をハードコードしない** |
| `party_units` | `Array` | `BattleUnit` の配列。ウェーブ間で作り直さない（HP 引き継ぎ） |
| `enemy_units` | `Array` | `BattleUnit` の配列。ウェーブごとに作り直す |
| `result` | `Dictionary` | `{BATTLE_VICTORY, BATTLE_WAVES_CLEARED, BATTLE_REWARDS}`。確定時にセット |

#### メソッド（判定用のみ）

- `is_wave_cleared() -> bool`：`enemy_units` に生存者がいない
- `is_party_wiped() -> bool`：`party_units` に生存者がいない
- `is_final_wave() -> bool`：`current_wave >= total_waves`
- `get_alive_units(team: String) -> Array`：`team` 側の生存ユニットを返す

**`_process` は持たない。** `RefCounted` のため持てない。ループは `BattleController` が回す。`BattleSession` は「データと状態の判定だけ」を責務とする（EXEC §4）。

### 3.3 設計上の注意

- `BattleSession` に `wave_index` は持たない。EXEC §4 の表記は `current_wave`（1 始まり）
- `BattleUnit.is_boss` は `BattleController` 側で `stages.json` の `is_boss` を読んでセットする。`UnitView` の色分け（紫）のために使う
- 死亡した味方は `party_units` から**削除しない**。`is_alive() == false` のまま残し、次のウェーブで `is_party_wiped()` の判定に使う


---

## 4. 戦闘ループの処理順序（毎フレーム何をどの順でやるか）

`BattleController._process(delta: float) -> void` の内部処理。
**実行順は厳守**。EXEC §6-4, §6-6, §7-1 に従う。

### 4.1 早期リターン（多重要ガード）

```
if session.state != BattleSession.STATE_BATTLE_ACTIVE:
	return
if _result_applied:
	return
```

- 戦闘中以外の状態（wave_intro / wave_clear / victory / defeat）では戦闘ロジックを走らせない
- 報酬適用済みフラグで二重発火を防ぐ（EXEC §7-1 フラグ）

### 4.2 フェーズ A：対象再選択（生存ユニット全て、味→敵の順）

```
for unit in session.party_units + session.enemy_units:
	if not unit.is_alive():
		continue
	if unit.target_unit_id == "" or not _is_target_alive(unit):
		_acquire_nearest_enemy(unit, session)
```

`_acquire_nearest_enemy` の中身：
- 敵対チームの生存ユニットを `session.get_alive_units(opposite_team)` で取得
- `abs(self.x - other.x)` 最小を選ぶ
- 生存者がいなければ何もしない（`target_unit_id` はそのまま空のまま）

### 4.3 フェーズ B：通常攻撃の射程判定＋発動

```
for unit in session.party_units + session.enemy_units:
	if not unit.is_alive():
		continue
	if unit.target_unit_id == "":
		continue
	var target: BattleUnit = _find_unit_by_id(session, unit.target_unit_id)
	if target == null or not target.is_alive():
		continue
	var distance: float = abs(target.x - unit.x)
	if distance <= unit.attack_range:
		# 射程内
		unit.attack_timer += delta
		if unit.attack_timer >= unit.attack_interval_sec:
			# タイマー満了 → 攻撃発動
			var dmg: int = _compute_damage(unit, target)
			target.take_damage(dmg)
			unit.attack_timer = 0.0
	else:
		# 射程外
		var dir: float = sign(target.x - unit.x)
		unit.x += dir * unit.speed * delta
		# 射程外では attack_timer を進めない
```

### 4.4 フェーズ C：ダメージ計算（**EXEC §6-5 いちばん間違えやすい箇所**）

```
func _compute_damage(attacker: BattleUnit, target: BattleUnit) -> int:
	var raw: int = int(floor(attacker.atk * attacker.atk_multiplier)) - target.def
	return max(1, raw)
```

**`max(1, ...)` を必ず入れる。** 無いと防御力 ≥ 攻撃力でダメージ 0 / 負になり、戦闘が永遠に続く固まりバグになる。エラーは出ないので気付きにくい。完了条件 6 で実測確認する。

### 4.5 フェーズ D：勝敗判定（**敗北判定を先に行う**）

```
if session.is_party_wiped():
	_enter_defeat()
elif session.is_wave_cleared():
	_enter_wave_clear()
```

**敗北判定を勝利判定より先。** 相打ちで両チーム全滅すると「全滅したのに勝った」事故になる（EXEC §6-6）。

### 4.6 フェーズ E：UI 同期

```
_update_unit_views()  # BattleUnit.x, hp を UnitView に反映
_update_wave_label()  # "%d / %d" % [current_wave, total_waves]
```

`WaveLabel.text` は数値のみなので `tr()` を通さない（AGENTS.md）。`UnitView._process(delta)` 内部でも同期するが、コントローラ側からも明示的に呼ぶのは冗長ではない（同じフレーム内の反映遅れを防ぐ）。

### 4.7 ウェーブ進行（state 機械）

```
# STATE_WAVE_INTRO 開始時
await get_tree().create_timer(0.5).timeout
_enemy_units_for_current_wave()  # 敵を生成して session.enemy_units へ
session.state = BattleSession.STATE_BATTLE_ACTIVE

# STATE_WAVE_CLEAR 開始時（_enter_wave_clear 内）
if session.is_final_wave():
	_enter_victory()
else:
	session.current_wave += 1
	session.state = BattleSession.STATE_WAVE_INTRO
```

- `await` を使うため、`_enter_wave_clear` 自体はコルーチン関数
- 敵の生成はウェーブごと（`session.enemy_units` を破棄して新規生成）
- 味方は**作り直さない**（HP 引き継ぎ、死亡者もそのまま残す）

### 4.8 起動時シーケンス（`_ready()`）

```
var data: Dictionary = SceneManager.consume_transfer_data()  # 1回だけ
var stage_id: String = data.get(TransferKeys.STAGE_ID, "")
if stage_id == "":
	push_warning("[Battle] stage_id が渡されていないため stage_1 で開始する")
	stage_id = "stage_1"
```

**`consume_transfer_data()` は 1 回だけ呼ぶ。** 2 回目は空 dict になる（EXEC §6-1）。


---

## 5. 勝敗確定時の処理順序

EXEC §7「今回いちばん事故が起きる箇所」に厳密準拠。

### 5.1 報酬二重加算を防ぐ仕組み（EXEC §7-1 フラグ方式）

`BattleController` に **`var _result_applied: bool = false`** を持たせる。

`_enter_victory()` の中：
```
if _result_applied:
	return                       # ① 二重実行ガード
_result_applied = true           # ② フラグを立てる
session.state = BattleSession.STATE_VICTORY   # ③ 状態を確定
GameManager.apply_battle_rewards({...})       # ④ 報酬反映
GameManager.mark_stage_cleared(stage_id, 0)   # ⑤ ステージクリア記録
ResultView.show_victory(result_data)          # ⑥ 結果画面表示
```

**フラグを立てるのは報酬呼び出しの前。** `await` を挟むと、その間に次フレームが走って二重に呼ばれる（EXEC §7-1 重要）。

`_process` の冒頭でも `if _result_applied: return` するため、以降のフレームでは何も走らない（セクション 4.1）。

### 5.2 victory 確定時の処理順序

```
1. if _result_applied: return
2. _result_applied = true
3. session.state = STATE_VICTORY
4. var result_data := {
	 GameStateKeys.BATTLE_VICTORY: true,
	 GameStateKeys.BATTLE_WAVES_CLEARED: session.total_waves,
	 GameStateKeys.BATTLE_REWARDS: stage_data.get("rewards", {}),
   }
5. GameManager.apply_battle_rewards(result_data)
   # 内部で SignalBus.battle_finished.emit(result_data) される
6. GameManager.mark_stage_cleared(session.stage_id, 0)
7. ResultView の表示：
   - ResultLabel.text = tr("ui_battle_victory")
   - RewardLabel.text = tr("ui_battle_reward_gold") + ": 50" 等
   - RetryButton.hide()       # 勝利時は再戦ボタン非表示
   - BackButton.show()
```

キーは必ず `GameStateKeys` の定数経由。文字列リテラル禁止（EXEC §7-2、AGENTS.md）。

### 5.3 defeat 確定時の処理順序

```
1. if _result_applied: return
2. _result_applied = true
3. session.state = STATE_DEFEAT
4. ResultView の表示：
   - ResultLabel.text = tr("ui_battle_defeat")
   - RewardLabel は空 or 非表示
   - RetryButton.show()
   - BackButton.show()
```

**`apply_battle_rewards()` は呼ばない。** ** `mark_stage_cleared()` も呼ばない。** （EXEC §7-4）

完了条件 16 で「敗北時に `apply_battle_rewards` の print が出ない」を実測確認する。

### 5.4 `SignalBus.battle_finished` の発火元

**`battle_controller.gd` には `SignalBus.battle_finished.emit()` を絶対に書かない。** `apply_battle_rewards()` 内部からのみ発火する（EXEC §7-3、実コード確認済み）。

完了条件 13 で「`battle_controller.gd` に `SignalBus.battle_finished.emit` が 1 箇所も書かれていない」をコードレビュー確認する。

### 5.5 敗北→リトライの処理順序

`RetryButton.pressed` → `_on_retry_pressed()`：

```
1. _result_applied = false
2. session = null
3. _init_session()              # BattleSession を作り直し、ウェーブ1から
4. ResultView.hide()
5. _enter_wave_intro()          # 0.5秒待ってウェーブ1開始
```

「もう一度」では味方の HP が満タンに戻る（`BattleUnit` を作り直すため）。これは仕様（EXEC §7-5）。

### 5.6 ボタンの挙動

| ボタン | ハンドラ | 遷移先 |
|---|---|---|
| `RetryButton` | `_on_retry_pressed()` | 同ステージ・ウェーブ 1 から再開（敗北時のみ表示） |
| `BackButton` | `_on_back_pressed()` | `SceneManager.change_scene("res://scenes/base/base_screen.tscn")` |

`SceneManager.go_back()` は使わない（履歴がダミー実装のため。EXEC §7-5）。

### 5.7 ウェーブ進行中の報酬混入防止

`STATE_WAVE_CLEAR` 中間状態では `apply_battle_rewards` を**呼ばない**。`current_wave += 1` して `STATE_WAVE_INTRO` へ遷移するのみ。途中経過の報酬加算は存在しない（PLAN_BATTLE_SCREEN §8 通り）。

### 5.8 防御の多重性まとめ

| レイヤー | 仕組み | 役割 |
|---|---|---|
| ① | `if _result_applied: return`（入口） | 多重呼び出しを関数レベルで防ぐ |
| ② | `_result_applied = true` を報酬呼び出しの**前**にセット | フラグ設定前に `await` が割り込むことを防ぐ |
| ③ | `session.state != STATE_BATTLE_ACTIVE` ガード | `_process` の冒頭で戦闘ロジックを停止 |
| ④ | `apply_battle_rewards` 内部の gold / materials 加算が冪等でないことを利用 | 関数を 2 回呼んでも 2 回分の gold が入らないよう、関数を呼ばない設計にする |

3 つ目までで「`_process` が `STATE_VICTORY` を見て何もしなくなる」+「`_enter_victory` の入口で早期 return」が成立する。


---

## 6. 判断に迷った点

### 6.1 `.tres` ではなく `.json` でマスターデータを持つ点

**迷った：** PLAN_BATTLE_SCREEN §10 は `.tres` を `resources/balance/master/` 配下に置く方針だった。EXEC §1 はこれを一転して `.json` にしている。

**判断：** EXEC を優先する。理由：
- `MasterDataLoader` 側で ID 直指定の `load()` 方式とファイル走査方式を切り替えやすい（テキスト形式の方が扱いやすい）
- AGENTS.md「数値管理ルール」は「`.tres` を Inspector で差し替えられる」ことを重視するが、**本フェーズでは数値を人間が後から微調整する想定**で、JSON でも差し替えは容易
- 最終的な形式（`.tres` 化 or JSON 継続）はフェーズ 2 以降で再判断すればよく、現時点では EXEC の方針に従う

**人間への確認事項：** `.json` 形式が最終形でよいか、それともフェーズ 2 で `.tres` に移行するか。

### 6.2 `class_name` を `Unit` ではなく `BattleUnit` にする点

**迷った：** PLAN_BATTLE_SCREEN §3 は `Unit` という名称を使っている。

**判断：** EXEC §3 に従い `BattleUnit` にする。理由：
- `Unit` は Godot 組み込みのクラス名と近い（CharacterBody 等のベースになる概念名）
- 将来的にギルド内の `Unit`（施設ユニット等）と衝突する可能性が高い
- タイプ数も少ないので命名変更コストは低い

**人間への確認事項：** なし。EXEC の注記で理由が明示されている。

### 6.3 育成データ（`character_growth`）が現状空だが取得を試みる点

**迷った：** §6-2 には「`get_character_growth` は空 dict を返す」とある。空チェックを書いておかないと、無いキーで `null` 参照になるリスクがある。

**判断：** EXEC §6-2 の優先順を厳密に従う：
```
1. GameManager.get_character_growth(character_id)
2. 戻り値が空でなく GROWTH_STATS を持つなら、その hp/atk/def/spd を使う
3. そうでなければ characters.json の値を使う
```

判定は `is_empty()` + `has()` の両方でガード。`attack_range` / `attack_interval_sec` / `name_key` は育成データに存在しないので**常に JSON から**取る（EXEC §6-2 末尾）。

### 6.4 `atk_multiplier` の装備補正

**迷った：** PLAN では `atk_multiplier` を装備から計算する想定だったが、EXEC §6-2 では「常に 1.0」と明示。

**判断：** EXEC に従い `1.0` 固定。`BattleUnit._init` の引数で 1.0 をデフォルトにする。将来の装備実装で `BattleController` が `GameManager.get_character_growth()` から読み替えて渡せばよい。`BattleUnit` 自体に装備解決ロジックは持たせない。

### 6.5 `ResourceDisplay` を使わない点

**迷った：** 拠点画面では `ResourceDisplay` で報酬表示している箇所がある。戦闘画面の `RewardLabel` にも適用すべきか。

**判断：** EXEC §「`ResourceDisplay` は本タスクでは使わない」明記。理由：
- `ResourceDisplay` には `Icon` と `ValueLabel` しかなく、**名前を表示する手段が無い**
- 報酬表示は「ゴールド：50」「建築素材：3」のように「翻訳キー + 数値」のペアが必要
- 素の `Label` を使う方が記述量が少ない

完了条件 14 で確認する箇所なので、誤字には注意。

### 6.6 ボス（`is_boss`）の色分け

**迷った：** 「ボスの見た目の区別はフェーズ 2 でやらない」とあるが、`is_boss` は読み込むだけ。色（紫）はいつ適用するか。

**判断：** EXEC §5 の表に従い、`UnitView.setup()` 内で：
```
if unit.is_boss:
	body.color = COLOR_BOSS  # 紫
elif unit.team == TEAM_PARTY:
	body.color = COLOR_PARTY
else:
	body.color = COLOR_ENEMY
```

「見た目だけ」の話で、ロジックには影響しない。`COLOR_BOSS` / `COLOR_PARTY` / `COLOR_ENEMY` の 3 定数を `unit_view.gd` 内に const で持つ（EXEC §5 許可）。

### 6.7 ウェーブ 1 開始までの 0.5 秒タイマー

**迷った：** EXEC §6-6 で `await get_tree().create_timer(0.5).timeout` とあるが、その間にユーザーが「拠点に戻る」ボタンを押したら何が起きるか。

**判断：** ボタン UI は `_ready()` 完了直後に `ResultView` が `hide()` 状態のため、ユーザーが押せるのは ResultView 内の Retry/Back のみ。戦闘中（wave_intro 含む）に Back ボタンは出していない。`await` 中は `session.state = STATE_WAVE_INTRO` なので `_process` 早期リターンで何も走らない、安全。

念のため `RetryButton` / `BackButton` は `ResultView` の中だけに配置し、wave_intro 中は触れられない構造にする（EXEC §6 シーン階層通り）。

### 6.8 「もう一度」で `BattleSession` を作り直す範囲

**迷った：** `session = BattleSession.new(...)` だけでよいか、`UnitView` も全部 `queue_free()` して再生成すべきか。

**判断：**
- `BattleSession` を作り直す → 敵ユニットは新しくなる、味方は `_init_party_units` で再生成され HP 満タンに
- `PartyUnitsContainer` 配下の `UnitView` も対応して破棄・再生成
- `EnemyUnitsContainer` も同じ

`_init_session()` を `_ready()` と `_on_retry_pressed()` の両方から呼ぶ DRY 構成にする。

### 6.9 19 項目の完了条件をコードで確認する項目

**迷った：** 完了条件 6, 13, 15, 16, 18, 19 は **コードレビューや状態ダンプ**で検証する項目。実行テストと区別したい。

**判断：** IMPL_LOG では各項目について「何をしたら何と表示されたか」を書く。コードレビュー項目（13 など）は、レビューで「書いていないことを確認した」という形で記録する。`grep_code` で `SignalBus.battle_finished.emit` を `battle_controller.gd` から検索し 0 件であることをログに残す、のように。

### 6.10 完了条件 6 / 19 の JSON 一時書き換え

**迷った：** `enemies.json` の値を書き換えて動作確認する必要があるが、戻し忘れが怖い。

**判断：** 確認前に値を控えておき、確認後に `bash` で元の値に戻す（`cat > file << EOF` ではなく `sed` は AGENTS.md で禁止なので使えない）。**実装完了チェックリストに「JSON を元に戻したか確認」を含める。**

### 6.11 セクション構造の単位

**迷った：** 1 つのセクションを 1 ツール呼び出しで書くのは質問の指示通り。セクション 4（戦闘ループ）が最も情報量が多いが 60 行以内に収めた。

**判断：** 6 回の `cat >>` で完了。セクション 4 を 2 回に分けることはせず、コードブロック中心なので短縮可能だった。

### 6.12 スキップした EXEC の項目

- §8 翻訳キー：人間が `ja.csv` に追記する分担のため PRE_PLAN 側では扱わない
- §「動作確認手順」19 項目：IMPL_LOG 側で逐語転記する。PRE_PLAN では項目番号のみ参照

## 7. 人間による決定事項（実装時はここを最優先で従うこと）

§1〜§6 と矛盾する場合は **この章を優先する。**

### 7-1.【明確化】BattleSession._init() の引数

_init(stage_id: String, stage_type: String, party_id: String, total_waves: int)

- stage_type は GameStateKeys.STAGE_TYPE_STORY を渡す
- party_id は MasterDataLoader.get_stage(stage_id)["party_id"] から取得する
- total_waves は stage_data["waves"].size() から取得する

party_units と enemy_units は _init 内では空配列のままにし、
生成後に BattleController から外部でセットする。

### 7-2.【明確化】stage_type の設定

転送データに TransferKeys.STAGE_TYPE があればそれを使い、
無ければ GameStateKeys.STAGE_TYPE_STORY をフォールバックとして使う。

stage_id と同じ扱いにすること。固定値で直書きしないこと。
冒険選択画面ができたとき、トレーニングモードの導線が
コードを変えずに繋がるようにするため。

フォールバックした場合の push_warning は不要
（stage_id 側で既に警告が出るため）。

### 7-3.【回答】マスターデータの永続形式

JSON を継続する。フェーズ2以降も .tres には移行しない。

これは PLAN_BATTLE_SCREEN.md §2-1 で決定済みの事項であり、
今回新たに決めたものではない。理由は以下：

- 敵・ウェーブ・スキルはすぐ数十件になり、
  .tres を1件ずつInspectorで手入力するのは現実的でない
- 過去に「.tres に値を入れた」と報告されて空だった事故がある。
  JSONはテキストなので人間が目視で中身を確認でき、
  同じ事故が構造的に起きない
- git diff で変更内容が読める

### 7-4.【要修正】ウェーブ切替時に古い敵の UnitView を破棄する

EXEC §5 の「死亡しても hide() するだけでノードは消さない」は
**同一ウェーブ内での話**であり、ウェーブ切替時には当てはまらない。

ウェーブが切り替わるとき、EnemyUnitsContainer 配下の
古い UnitView をすべて queue_free() してから新しい敵を生成すること。
消さないと、5ウェーブぶんの非表示ノードが残り _process が回り続ける。

実装上の注意：
- queue_free() は即座には削除されない（フレーム末尾に遅延実行される）
- したがって get_child_count() や get_children() で
  「消えたこと」を確認しないこと。次のフレームまで古い子が残っている
- BattleController 側で生成した UnitView の参照を配列で持ち、
  破棄時にその配列も clear() すること

PartyUnitsContainer は破棄しない。味方はウェーブをまたいで
同じ BattleUnit と UnitView を使い続ける（連戦のため）。

### 7-5.【却下】ターゲット不在でユニットが停止する懸念について

レビューで「敵対チームに生存者がいない場合、target_unit_id が
空のままユニットが停止するのではないか」という指摘があったが、
対応不要。

敵の生存者がゼロになった時点で、同じフレーム内の
is_wave_cleared() が true を返して state が STATE_WAVE_CLEAR に移る。
ユニットが停止したまま残る状況は発生しない。

ガードを足さないこと。動かない条件を増やすと、
本当に止まったときの原因切り分けが難しくなる。

### 7-6. そのまま採用する判断

以下は実装役の判断が正しい。計画のまま進めてよい。

- §3.1 class_name を BattleUnit にする
- §3.2 total_waves を JSON から取得する
- §4.4 ダメージ計算に max(1, ...) を入れる
- §4.5 敗北判定を勝利判定より先に行う
- §4.7 味方ユニットをウェーブ間で作り直さない
- §4.8 consume_transfer_data() を1回だけ呼ぶ
- §5.1 _result_applied フラグを報酬呼び出しより前に立てる
- §5.4 SignalBus.battle_finished を戦闘画面から発火しない
- §6.6 ボスの色分けに関する判断
- §6.10 JSON を一時書き換えしたあと元に戻す手順
