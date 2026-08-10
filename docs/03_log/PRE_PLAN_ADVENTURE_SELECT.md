# PRE_PLAN_ADVENTURE_SELECT.md

`EXEC_ADVENTURE_SELECT.md` に対応する実装計画。コードは書かない。

参照: `AGENTS.md` / `EXEC_ADVENTURE_SELECT.md` / `PLAN_ADVENTURE_SELECT.md`（存在すれば）。

## 1. 作成・変更するファイル一覧

### 1.1 新規作成

| パス | 役割 |
|---|---|
| `res://scenes/adventure/adventure_select.tscn` | 冒険選択画面のシーン。`adventure_select.gd` をルートにアタッチ。`base_screen.tscn` の構成に揃える（Background + VBoxContainer）。 |
| `res://scenes/adventure/adventure_select.gd` | 冒険選択画面のスクリプト。スタミナ表示・ステージ行生成・挑戦処理を担う。 |
| `res://resources/balance/master/stage_order.json` | ステージ並び順のみを保持するマスタ。`{"story": ["stage_1", "stage_2", "stage_3"]}`。`stages.json` は Dictionary でキー順が保証されないため、表示順はここに一本化する。 |

### 1.2 既存変更

| パス | 変更箇所 | 変更内容 |
|---|---|---|
| `res://resources/balance/master/stages.json` | 既存 `stage_1` の中身に `name_key` フィールドを 1 つ追加。`waves` と `rewards` は **1 文字も変えない**。 | `name_key: "ui_stage_1"` を `stage_1` の先頭に挿入する。続けて `stage_2` / `stage_3` のエントリを新規追加する（EXEC §1 の全文そのまま）。 |
| `res://scripts/systems/master_data_loader.gd` | ファイル末尾に追記のみ。**既存の `const` ブロック・`_ensure_loaded()`・既存 `static var` には一切触れない**。 | `static var _cache_stage_order: Dictionary` と `static var _stage_order_loaded: bool` を宣言し、`get_stage_order(mode: String) -> Array` を追加する。詳細は §2。 |

### 1.3 触らないファイル（人間が対応済み）

`autoload/game_manager.gd`（`refund_stamina()` / `_add_stamina_uncapped()` 追加済み）、`autoload/balance.gd`（`@export var adventure` 追加済み）、`scenes/base/base_screen.gd`（`SCREEN_SCENES` の差し替え済み）、`localization/ja.csv`（翻訳キー追記済み）、`scenes/adventure/battle_controller.gd`（全文差し替え済み）、`resources/balance/adventure_config.gd` / `adventure_config.tres`（作成・値入力済み）。

## 2. MasterDataLoader への get_stage_order() の足し方

### 2.1 方針

EXEC §3 の指定に従い、**ファイル末尾への追記だけで完結**させる。既存の `const DIR_PATH` 配下に新しい `const PATH_STAGE_ORDER` を足す必要が出るが、これも「`const` ブロックに**追加で 1 行**」であれば末尾挙動は壊れない。`_ensure_loaded()` は触らず、`get_stage_order` 関数側で独立に遅延ロードする。

### 2.2 static var の宣言位置

`MasterDataLoader` には既に `static var _cache_loaded: bool` が `static var _cache_skills: Dictionary` の直後にある。**この行を改変せず**、さらに後ろ（既存の `static var` 群の末尾、`get_character` などの関数定義が始まる直前）に 2 行追加する：

```
static var _cache_stage_order: Dictionary = {}
static var _stage_order_loaded: bool = false
```

GDScript は `static var` を関数定義より下に置けるため、`get_character` の上あたりに追加しても問題ない。ただし「既存 5 つの `static var` の直後に置く」ほうがgrepで追いやすいので、**`_cache_skills` の 1 行下（`_cache_loaded` 宣言の**後**）に置く**。GDScript の `static var` 順は実行に影響しないので読みやすさ優先。

### 2.3 const の扱い

`PATH_STAGES` のすぐ下に 1 行追加する：

```
const PATH_STAGE_ORDER: String = DIR_PATH + "stage_order.json"
```

これで他の `PATH_*` と同じ命名規約に揃う。**既存の 5 つの `const` 行は変更しない**（削除・改名禁止）。

### 2.4 get_stage_order() の実装

`_ensure_loaded()` には一切手を加えず、`get_stage_order` 関数側で `_stage_order_loaded` フラグを使って遅延ロードする形にする。実装の骨子（**コードは書かない**、方針のみ）：

1. 既に読み込み済みなら `_cache_stage_order` から該当モードの配列を `duplicate(true)` して返す。
2. 未読み込みなら `_load_json(PATH_STAGE_ORDER)` を呼ぶ（既存の `_load_json` をそのまま使う。`_load_mode` の判定や `load()` フォールバックは既存実装に任せる）。
3. 戻り値を `_cache_stage_order` に格納し、`_stage_order_loaded = true` にする。
4. `mode` が `_cache_stage_order` に無ければ `push_error` を出して空 `Array` を返す（空配列も `duplicate(true)` 不要）。
5. 返す値は常に `duplicate(true)` する（get_character / get_stage と同じ流儀）。

## 3. adventure_select.tscn のノード構成

`base_screen.tscn` の構成を踏襲する。`uid` は `create_file` で作らないため **書かない**（Godot が初回保存時に自動採番する）。

### 3.1 ルートと最外殻

- **AdventureSelect** (`Control`)
  - `anchors_preset = 15`、`anchor_right = 1.0`、`anchor_bottom = 1.0`、`grow_horizontal = 2`、`grow_vertical = 2`
  - `layout_mode = 3`（anchors で配置するため）
  - `script = res://scenes/adventure/adventure_select.gd`（ext_resource で参照）

- **Background** (`ColorRect`, parent = ".")
  - 全画面（`anchors_preset = 15`、`anchor_right = 1.0`、`anchor_bottom = 1.0`、`grow_horizontal = 2`、`grow_vertical = 2`）
  - `layout_mode = 1`、背景色は `main_theme.tres` の標準値があればそれに合わせる。**個別色を直接指定しない**（AGENTS.md Theme の扱い）。

- **Layout** (`VBoxContainer`, parent = ".")
  - 全画面・余白あり。`anchors_preset = 15`、左右に 16px 程度の `offset_left/right` を入れて余白を作る。
  - `theme_override_constants/separation = 8`

### 3.2 Header（HBoxContainer, parent = "Layout"）

`size_flags_horizontal = 3`（EXPAND_FILL）でヘッダー行を横一杯に広げる。

- **TitleLabel** (`Label`)
  - `text = "ui_adventure_title"`（自動翻訳される。`base_screen.tscn` の `text = "ui_res_gold"` と同じ流儀）
  - `layout_mode = 2`（VBox の子として size_flags を継承）

- **Spacer** (`Control`)
  - `size_flags_horizontal = 3`（EXPAND_FILL）。TitleLabel と StaminaNameLabel の隙間を埋める。

- **StaminaNameLabel** (`Label`)
  - `text = "ui_res_stamina"`（自動翻訳）

- **StaminaValue** (`ResourceDisplay` インスタンス)
  - `resource_display.tscn` を `instance=ExtResource(...)` で貼る
  - `layout_mode = 2`

> `ResourceDisplay` には `name_key` のような「名前を出す手段」がない（EXEC §0 既存実装状況）ため、**名前を隣の `StaminaNameLabel` で出す**。これは EXEC §4 の指示と一致する。

### 3.3 MessageLabel

- **MessageLabel** (`Label`, parent = "Layout")
  - `text = ""`（空文字で初期化。コード側で必要に応じて書き換える）
  - `layout_mode = 2`

### 3.4 StageList と Spacer2

- **StageList** (`VBoxContainer`, parent = "Layout")
  - `size_flags_horizontal = 3`（EXPAND_FILL）
  - 中身は **コードで生成**（専用の `.tscn` は作らない。1画面専用で構造が単純なため AGENTS.md の "1画面だけ → その画面のフォルダ" に従う）

- **Spacer2** (`Control`, parent = "Layout")
  - `size_flags_vertical = 3`（EXPAND_FILL）。StageList と Footer の間の余白。

## 4. ステージ行の生成と3状態の出し分け

### 4.1 行の組み立て

`_ready()` の中で `MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)` を呼び、戻り値の `Array` を `for` で回す。各 `stage_id` について：

1. `MasterDataLoader.get_stage(stage_id)` で `Dictionary` を取得。**空 `{}` が返ったら `push_error` して行を生成しない**（並び順にあるのに実体データが無い異常状態のため）。
2. `stage_data["name_key"]` を読み、`tr(name_key)` でステージ名文字列を得る。
3. 解放状態を §4.2 の式で計算する。
4. `HBoxContainer`（名前は `StageRow`）を `new()` して `StageList` に `add_child` する。子要素は EXEC §5-3 の図どおり：
   - `NameLabel` (`Label`)
   - `Spacer` (`Control`, `size_flags_horizontal = 3`)
   - `CostLabel` (`Label`)
   - `ChallengeButton` (`PrimaryButton` インスタンス)

`CostLabel.text` は `str(Balance.adventure.stamina_cost_per_stage)`。**数値のみなので `tr()` は通さない**（AGENTS.md）。

`ChallengeButton` は `pressed.connect(_on_challenge_pressed.bind(stage_id, challenge_button))` のように行データを bind する。後で `disabled` を切り替えたいときに備え、ボタン参照も一緒に持っておく。

### 4.2 解放判定（都度計算する）

EXEC §5-4 の指定に従い、**`GameManager.is_stage_cleared()` のみを呼んで計算する**。解放状態を画面側でキャッシュしない。

```
先頭のステージ (index == 0)   → 常に解放（挑戦可能扱い）
2 番目以降 (index >= 1)       → stage_order[index - 1] が cleared なら解放
```

疑似コード（実装はしない）：

```
var order: Array = MasterDataLoader.get_stage_order(STAGE_TYPE_STORY)
for i in range(order.size()):
	var sid: String = order[i]
	var unlocked: bool = (i == 0) or GameManager.is_stage_cleared(order[i - 1])
	var cleared: bool = GameManager.is_stage_cleared(sid)
	# → unlocked=false → 未解放 / unlocked=true かつ cleared=false → 挑戦可能 / cleared=true → クリア済み
```

### 4.3 ステージIDから数字を切り出す方法を使わない理由

`stage_id`（`"stage_1"` 等）の `"_"` 以降を整数化して `stage_(N-1)` を組み立てるような書き方を**しない**。理由は EXEC §5-4 に明記されている通り：

- 並び順の正本は `stage_order.json` であり、**`Dictionary` ではなく `Array` で順序を保証**する。解放判定は **その `Array` の前後関係**で決めるのが仕様。
- ID の数字部分を切り出すと、ID 体系を `"chapter_2_stage_1"` のように変えた瞬間（または並び順を `["stage_2", "stage_1", "stage_3"]` に変えた瞬間）に **ID の数字と表示順が乖離して壊れる**。
- 「1 つ前」を **データの並びで決める**ことで、ID 命名と並び順を疎結合に保てる。これは完了条件 14（並び順を入れ替えても正しく動く）を満たす根拠にもなる。

### 4.4 3状態の見た目

EXEC §5-4 の表に従う：

| 状態 | `NameLabel.text` | ボタン | 押したときの挙動 | `NameLabel.modulate` |
|---|---|---|---|---|
| クリア済み | `tr(name_key) + " ✓"` | 有効 | 挑戦処理に進む | 既定（暗くしない） |
| 挑戦可能 | `tr(name_key)` | 有効 | 挑戦処理に進む | 既定 |
| 未解放 | `tr(name_key) + " 🔒"` | **`disabled = false` のまま** | 何もせず `MessageLabel.text = tr("ui_adventure_locked")` | `Color(0.5, 0.5, 0.5)` |

**未解放でも `disabled` にしない**のは EXEC §5-4 の指示。押せなくすると理由が見えなくなるため、**押せて、メッセージで理由を伝える**設計にする。

## 5. 挑戦したときの処理順序

`ChallengeButton.pressed` のハンドラ（bind で `stage_id` を受け取る）。実行する手順は EXEC §5-5 の番号をそのまま守る：

### 5.1 解放状態の最終チェック

`is_unlocked(stage_id)` を呼び（§4.2 と同じ計算を `stage_id` で行う）、`false` なら：

```
message_label.text = tr("ui_adventure_locked")
return
```

`spend_stamina` は**呼ばない**。スタミナは減らない（完了条件 6 の根拠）。

### 5.2 消費スタミナの取得

```
var cost: int = int(Balance.adventure.stamina_cost_per_stage)
```

数値のハードコードは禁止（AGENTS.md）。`Balance` Autoload 経由で読む。

### 5.3 spend_stamina を呼ぶ

```
var ok: bool = GameManager.spend_stamina(cost)
```

`false` が返った場合（**スタミナ不足**）：

```
var state: Dictionary = GameManager.get_state()
var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
message_label.text = tr("ui_adventure_stamina_short") + " (%d / %d)" % [cost, current]
return
```

**遷移しない。スタミナも減っていない**（EXEC §5-5 / 完了条件 10）。「あといくつ足りないか」が分かる形式にするのは EXEC §5-6 の指示。

### 5.4 遷移（true が返った場合のみ）

EXEC §5-5 末尾の式をそのまま使う。**`PARTY_ID` は渡さない**：

```
SceneManager.change_scene_with_data(
	"res://scenes/adventure/battle.tscn",
	{
		TransferKeys.STAGE_ID: stage_id,
		TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
	}
)
```

戦闘画面側は `stages.json` の `party_id` を読む実装のため、冒険選択画面から `PARTY_ID` を渡すと**責務が重複**するだけでなく、後にパーティ選択を別画面で持つように拡張した際に **古い `PARTY_ID` が紛れ込む事故**の温床になる。渡さないのが正解。

### 5.5 戦闘パスについて

`res://scenes/adventure/battle.tscn` は既に存在する（`scenes/adventure/` 配下を確認済み）。新規作成しない。パスは `const BATTLE_PATH` として **スクリプト先頭の `const` ブロック**に置く（`base_screen.gd` の `BASE_PATH` / `TITLE_PATH` と同じ流儀）。

## 6. スタミナ表示の更新

### 6.1 初期化（_ready 1 回目）

EXEC §5-2 の指定コードをそのまま使う：

```
var state: Dictionary = GameManager.get_state()
var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
stamina_value.set_value_with_max(
	int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
	int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
)
```

完了条件 2（`20 / 100` の形で表示され、`20 / 0` にならない）を満たす。

### 6.2 resource_changed ハンドラ

`GameManager.resource_changed.connect(_on_resource_changed)` を `_ready` で結線する。ハンドラ `_on_resource_changed(resource_type, new_value)` の実装方針：

- `resource_type == GameStateKeys.STAMINA` のときだけ更新する。
- **`new_value` は `current` 単体**であり `max` を含まない（AGENTS.md「resource_changed が STAMINA で発火するとき」/ EXEC §0 既存実装状況）。**`set_value_with_max(new_value, 0)` と書くと `20 / 0` になる** ので、**`max` は `get_state()` から読み直す**。
- 具体的にやること：
  1. `var state := GameManager.get_state()` でスナップショット取得（AGENTS.md `get_state()` は `duplicate(true)` した読み取り専用）。
  2. `var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})`。
  3. `var stamina_max: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))`。
  4. `stamina_value.set_value_with_max(int(new_value), stamina_max)`。
- `GameStateKeys.GOLD` / `GAMEStateKeys.GEMS` が来たときは **何もしない**（この画面では表示していないため。`base_screen.gd` の `GEMS` 分岐が `pass` なのと同じ考え方）。
- 未知の `resource_type` は `push_warning` する（`base_screen.gd` と同じ対応）。

### 6.3 なぜ get_state() 経由か（補足）

`resource_changed(STAMINA, current)` のシグナル契約では `max` は送られてこない。これは `AGENTS.md` と `EXEC §0` が明示している仕様であり、**「足りない情報を後付けで足す」より「受け側で `get_state()` から最新を取り直す」ほうが GameManager 側に余計な API を生やさない**。将来 `max` が変わる機能が入ったら、そのときに GameManager 側に `max` を含む専用シグナルを追加する（AGENTS.md の将来対応として明記されている）。

### 6.4 完了条件との対応

- 完了条件 2（`20 / 100` 表示）: §6.1 と §6.2 の両方で `max` を `get_state()` から取ることで達成。
- 完了条件 7（20 → 15 に減って表示更新）: `spend_stamina` 成功で `resource_changed(STAMINA, 15)` が発火 → §6.2 が走り `15/100` に更新。
- 完了条件 10（スタミナ不足時 3 のまま）: §5.3 で `spend_stamina` を呼ばずに `return` するため、シグナルは飛ばず表示はそのまま。

## 7. 判断に迷った点

実装方針を決めるうえで曖昧さが残った箇所を列挙する。**「特になし」は避ける**。

### 7.1 `stages.json` の `name_key` 挿入位置

- **迷い**: 既存 `stage_1` に `name_key` を追加するとき、キーの**先頭**に足すか末尾に足すか。
- **判断**: `name_key` は表示用途のフィールドであり、`party_id` / `rewards` / `waves` の並び順は戦闘側ロジックで参照される可能性がある。**先頭に追加する**（EXEC §1 のサンプルが先頭）。
- **リスク**: 戦闘側スクリプトがキー名で参照しているなら順序は無関係。万一キーインデックスで参照している箇所があれば壊れるが、Dictionary アクセスなのでその可能性は実質ゼロ。

### 7.2 `MasterDataLoader.get_stage_order` の `mode` 引数の扱い

- **迷い**: モードが `_cache_stage_order` に無いとき、`push_error` のみで `[]` を返すか、`push_warning` に留めるか。
- **判断**: EXEC §3 の「`mode` が無ければ `push_error` を出して空の `Array` を返す」をそのまま採用。**`push_warning` ではない**。
- **理由**: 並び順データが必要な場面で未知の `mode` が来るのは **呼び出し側のバグ**であり、無音で `[]` を返すと一覧に何もない状態で起動して原因が掴めなくなる。エラー出力で気付けるほうがデバッグに有利。

### 7.3 未解放ボタンを `disabled` にしないことの徹底

- **迷い**: 「未解放」を `disabled` で表現したほうが「チャレンジ」感が出て UX 的に分かりやすい気もする。
- **判断**: EXEC §5-4 の指示に従い **`disabled = false` のまま**にし、押すと `MessageLabel` に `ui_adventure_locked` を出す。
- **理由**: `disabled` だと「押せない理由」が伝わらない。メッセージで理由を伝えることで、**次に何をすべきか（前のステージをクリアする）**をユーザーが理解できる。

### 7.4 メッセージの自動消去

- **迷い**: 一定時間後に `MessageLabel.text = ""` で自動的に消すか。
- **判断**: EXEC §5-6 の指示に従い **タイマーで消さない**。次にボタンが押されるまで残す。
- **理由**: タイマーで消すと「読めないうちに消える」事故が起きる。ユーザーが再度情報を確認したいときに消えていると困る。

### 7.5 メッセージが残ったまま他のボタンを押されたら

- **迷い**: 新しい行の解放メッセージが出ている状態で、別行の「挑戦」ボタンを押したら、上書きされる前のメッセージがどう見えるか。
- **判断**: これも EXEC §5-6 の指示に従い、**次に押された時点で上書き**する。新しいメッセージがそのまま最新状態として出るので問題なし。
- **明示的にやること**: 「消費したのに遷移に失敗した」「別のエラーが起きた」のような状態を別表示で残す必要は **今回のスコープには無い**。スタミナ不足・未解放の 2 種だけが出れば十分。

### 7.6 `Background` の色指定

- **迷い**: 個別に `Color(0.101961, 0.0784314, 0.0941176, 1)` を指定するか、Theme に任せるか。
- **判断**: AGENTS.md「Theme の扱い」により **`ColorRect` 自体に `color` を書かない**。`Background` ノードで `color` 行を出さず、Theme 経由で配色される前提にする。`base_screen.tscn` が `color` を直書きしているのは既存実装であり、本タスクでは `adventure_select.tscn` 側で Theme 経由に寄せる（Theme 経由で背景が出ない場合は最終的に `.tscn` 側でも `color` を入れるが、**その判断は実装時に Theme の状態を再確認してから**）。
- **本計画での扱い**: ひとまず Theme 経由を前提に `.tscn` 側では `color` を書かない。実装時に背景が出ないようなら IMPL_LOG の「5. 指示書からの逸脱・迷った判断」に経緯を書いて `.tscn` 側に最小の `color` を入れる。

### 7.7 `BATTLE_PATH` の const 化とハードコード回避のバランス

- **迷い**: 戦闘パスを `const` で持つように EXEC §5-7 で指示されているが、AGENTS.md の数値管理ルールは「数値」を対象としており、パスは含まない。**それでも const 化する**のが指示なのでそれに従う。
- **判断**: `const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"` を `adventure_select.gd` の先頭 `const` ブロックに置く。`base_screen.gd` の `BASE_PATH` / `TITLE_PATH` と同じ流儀。

## 8. 人間による決定事項（実装時はここを最優先で従うこと）

§1〜§7 と矛盾する場合は **この章を優先する。**

### 8-1.【承認】スタミナ変動時の ChallengeButton の disabled 状態

§5.3 の方針でよい。

ChallengeButton の disabled はスタミナの増減で切り替えない（常に false）。
スタミナ不足のフィードバックは、押されたときの spend_stamina() の
戻り値と MessageLabel で行う。

未解放の扱いと合わせて「押せるが、押すと理由が分かる」で統一する。
押せなくすると、なぜ押せないのかが伝わらない。

### 8-2.【要修正】MasterDataLoader への static var は末尾に追記すること

§2.2 の「既存の static var ブロックの末尾（_cache_skills の直後）に置く」を
変更する。**ファイルの末尾に追記すること。**

理由：既存行の間に挿入するのは中間編集であり、この環境で最も失敗している
操作である。前回のタスクでは中間編集の失敗が連鎖し、ファイルが611行に
膨張してパースエラーが解消しなくなった。

GDScript は static var の宣言を関数のあとに書けるため、
ファイル末尾に以下をまとめて追記すれば動作は同じになる。

  1. static var _cache_stage_order: Dictionary = {}
  2. static var _stage_order_loaded: bool = false
  3. static func get_stage_order(mode: String) -> Array

上部の const ブロック・既存の static var ブロック・_ensure_loaded() には
一切触らないこと。追記後に read で開き、既存の5つの get_* 関数と
_load_json() が残っていることを確認すること。

### 8-3.【明確化】AdventureConfig の実物を先に確認すること

Balance.adventure（AdventureConfig）は人間が作成済みだが、
実装の最初に read で以下を確認してから使うこと。

- adventure_config.gd の class_name が AdventureConfig であること
- stamina_cost_per_stage という名前の @export があること

想定と違っていたら、そこで止めて報告すること。
勝手に名前を合わせにいったり、値をハードコードで代用したりしないこと。

### 8-4. そのまま採用する判断

以下は実装役の判断が正しい。計画のまま進めてよい。

- §2.1 MasterDataLoader の変更を追記のみに留め、_ensure_loaded() に触らない
- §2.4 stage_order が引けないときは push_error して空配列を返す
- §3.2 StaminaNameLabel を別途置く（ResourceDisplay に名前を出す手段が無いため）
- §4.1 get_stage() が空を返した行は生成せず push_error を出す
- §4.2 解放判定を stage_order の index で行う
- §4.3 ステージIDから数字を切り出さない
- §5.3 spend_stamina が false なら遷移せず return する
- §5.4 PARTY_ID を渡さない
- §6.2 resource_changed の第2引数を使わず get_state() から max を読み直す
- §7.4 メッセージをタイマーで自動消去しない
- §7.6 Background の色を直接指定せず Theme に任せる
- §7.7 遷移先のパスを const で持つ
