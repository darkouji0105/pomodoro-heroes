# PRE_PLAN_MODAL.md

汎用モーダル実装計画。`EXEC_MODAL.md` タスク1（本体）のみ対象。タスク2（各画面への適用）は含まない。

## 1. 作成するファイル一覧

| パス | 役割 | 新規/変更 |
|---|---|---|
| `res://scenes/ui/components/modal_dialog.tscn` | モーダルダイアログ本体のシーン。CanvasLayer + Block/Control + Dimmer/ColorRect + Panel/PanelContainer + Margin/MarginContainer + VBox/VBoxContainer + MessageLabel/Label + Buttons/HBoxContainer(ConfirmButton/CloseButton×PrimaryButton) | 新規 |
| `res://scenes/ui/components/modal_dialog.gd` | 上記シーンのルートスクリプト。`class_name ModalDialog extends CanvasLayer`。`setup(message, is_confirm, pause)` 公開。`closed(result)` シグナル発火。Escape/ボタン/暗幕クリック・pause管理を担当 | 新規 |
| `res://scripts/systems/modal.gd` | 静的呼び出し口。`class_name Modal extends RefCounted`。`notify(caller, message_key, format_args, pause)` / `confirm(caller, message_key, format_args, pause)` を公開。Autoloadにはしない | 新規 |
| `res://tests/modal_test.tscn` | 検証用シーン。`tests/` 配下に隔離。本番シーンに残さない | 新規 |
| `res://tests/modal_test.gd` | 検証用シーンのスクリプト。5つのボタンから各パターンを呼び出し、結果を `print` する | 新規 |

EXEC §6（`base_screen.gd` の `_on_save_pressed()` 変更）と §5（`ja.csv` 追記）は人間が担当するため、本計画には含めない。


## 2. modal_dialog.tscn のノード構成

EXEC §1 の指定そのまま。`uid="uid://..."` は Godot が再インポート時に自動付与するため、作成時は省略する。

### ノード階層

```
ModalDialog (CanvasLayer)            ← script: modal_dialog.gd
└─ Blocker (Control)                  ← mouse_filter = STOP（背後を止める核心）
	├─ Dimmer (ColorRect)             ← 全画面（Full Rect）
	└─ Panel (PanelContainer)         ← 中央配置
		└─ Margin (MarginContainer)
			└─ VBox (VBoxContainer)
				├─ MessageLabel (Label)
				└─ Buttons (HBoxContainer)
					├─ ConfirmButton   instance of primary_button.tscn
					└─ CloseButton     instance of primary_button.tscn
```

### 各ノードの設定

- **ModalDialog (CanvasLayer)**
  - `layer = 200`（BattleDebugPanel の 100 より上、EXEC §1 指示）
  - `script` = `res://scenes/ui/components/modal_dialog.gd`
  - コード側で `process_mode = PROCESS_MODE_ALWAYS` を `setup(pause=true)` のとき設定する。シーンには書かない（`pause=false` のモーダルが常時更新されてしまうため）
- **Blocker (Control)**
  - `anchors_preset = 15`（Full Rect）/ `anchor_right = 1.0` / `anchor_bottom = 1.0`
  - `grow_horizontal = 2` / `grow_vertical = 2`
  - **`mouse_filter = MOUSE_FILTER_STOP`（3）**——ここが「背後のボタンを止める」本体。Blocker が全画面を覆い、かつ入力を食い止めるため、Blocker 配下の Dimmer を含む全領域で背後 Control へのクリックは届かない。Blocker 自体は透明（透明度指定なし）で、Dimmer の上に Panel が重なる
  - 子に Dimmer と Panel を持つ構造のため、Blocker の `mouse_filter` を STOP にしてあれば、Dimmer 上と Panel 上のどちらも背後へ抜ける心配がない
- **Dimmer (ColorRect)**
  - `anchors_preset = 15` / `anchor_right = 1.0` / `anchor_bottom = 1.0`
  - `color = Color(0, 0, 0, 0.6)`（EXEC §1。Theme が効かないので直接指定）
  - `mouse_filter` は未指定（既定の STOP を継承しないよう `MOUSE_FILTER_IGNORE` = 2 を明示する）。**Blocker 側の STOP が親として効いているので Dimmer 自身が STOP である必要はないが、明示しておくと Blocker を取り除いたときに事故らない**
  - **`gui_input` は接続しない**。クリックを無視して閉じる動作を実装しない（EXEC §2「暗幕をクリックしても閉じない」）
- **Panel (PanelContainer)**
  - 画面中央。`anchors_preset = 8`（Center）または size_flags_center 系の組み合わせで中央寄せ
  - `custom_minimum_size = Vector2(400, 0)` 程度にして本文が横に伸びるのを防ぐ
  - サイズは `MessageLabel` の幅 400 とボタンの最小幅に合わせる
- **Margin (MarginContainer)**
  - `theme_override_constants/margin_left = 24` / `margin_right = 24` / `margin_top = 16` / `margin_bottom = 16`
- **VBox (VBoxContainer)**
  - `theme_override_constants/separation = 16`
- **MessageLabel (Label)**
  - `autowrap_mode = TEXT_AUTOWRAP_WORD_SMART`（3）
  - `custom_minimum_size.x = 400`
  - 初期 `text` は空。`setup()` で `text = message` を入れる
  - `horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER`
- **Buttons (HBoxContainer)**
  - `alignment = BoxContainer.ALIGNMENT_CENTER`
  - `theme_override_constants/separation = 16`
- **ConfirmButton (PrimaryButton)**
  - `label_key` は**シーンに書かない**。`setup()` 内で `is_confirm` を見て表示制御し、ラベルは `ui_common_yes` に設定する
  - 初期 `visible = false`（setup まで表示しない）
- **CloseButton (PrimaryButton)**
  - `label_key` はシーンに書かない。`setup()` 内で `ui_common_no`（確認モーダル）または `ui_common_close`（通知モーダル）に設定する
  - 初期 `visible = true`

### 暗幕クリックで閉じない保証

Blocker の `mouse_filter = STOP` が「入力を止める」。これを「閉じるイベントとして拾う」コードを書かなければ、暗幕クリックは何も起きない。`modal_dialog.gd` 側では `_gui_input` / `pressed` シグナルを一切接続しない。Escape のみ `_unhandled_key_input` で拾う。

### ext_resource / sub_resource

- `[ext_resource type="Script" path="res://scenes/ui/components/modal_dialog.gd" id="1_modal_script"]`
- `[ext_resource type="PackedScene" path="res://scenes/ui/components/primary_button.tscn" id="2_primary_button"]`
- PrimaryButton は 2 つインスタンス化するため `id` は `2_primary_button` を共有する


## 3. modal_dialog.gd の設計

EXEC §2 準拠。`class_name ModalDialog extends CanvasLayer`。

### シグナル

```
signal closed(result: bool)
```

通知モーダルでも発火する（そのとき `result` は常に `false`）。`Modal` 側は `confirm()` の `await` 専用にこれを待つ。`notify()` は待たないが、シグナルが余分に発火しても害はない。

### 公開関数

```
func setup(message: String, is_confirm: bool, pause: bool) -> void
```

- `message` は**翻訳済みの文字列**。`tr()` はここでは呼ばない。`Modal.notify/confirm` 側で済ませてから渡す（EXEC §2）
- `is_confirm == true` のとき：
  - `ConfirmButton.visible = true`
  - `ConfirmButton.label_key = "ui_common_yes"` → `tr("ui_common_yes")` で "はい"
  - `CloseButton.label_key = "ui_common_no"` → `tr("ui_common_no")` で "いいえ"
  - `Buttons` の `add_theme_constant_override` は使わず、ラベルのみ差し替える
- `is_confirm == false` のとき：
  - `ConfirmButton.visible = false`
  - `CloseButton.label_key = "ui_common_close"` → "閉じる"
- `MessageLabel.text = message`
- `pause == true` のとき、`_apply_pause()` を呼ぶ（後述）
- `pause == false` のときは pause に一切触らない（後述、§4 と連動）

### 内部状態

```
var _is_confirm: bool = false
var _pause: bool = false
```

- `_is_confirm` は ConfirmButton の表示制御に使う（`setup()` 後の状態保持）
- `_pause` は `_exit_tree()` で「自分が `pause = true` を立てたか」を判別するためのフラグ。`true` のときだけ `_release_pause()` を呼ぶ（§4 詳細）

### 閉じる経路4つ

| 経路 | ハンドラ | 動作 |
|---|---|---|
| 1. ConfirmButton 押下 | `_on_confirm_pressed()` | `_close(true)` |
| 2. CloseButton 押下 | `_on_close_pressed()` | `_close(false)` |
| 3. Escape キー | `_unhandled_key_input()` | `_close(false)`。`get_viewport().set_input_as_handled()` を呼んで背後への伝播を止める |
| 4. 暗幕クリック | （ハンドラ無し） | Blocker の `mouse_filter = STOP` がクリックを食い、コード側では `_gui_input` も `pressed` シグナル接続もしない。よって何も起きない。閉じないことを保証している |

### `_close(result: bool) -> void` の中身（順序厳守）

```
1. closed.emit(result)        # 先にシグナル発火
2. _release_pause()            # pause を立てた場合のみ paused = false に戻す
3. queue_free()                # 自分を解放
```

順序が逆（先に `queue_free()`）だと、待っている側にシグナルが届かない。EXEC §2 の指示。

### `_unhandled_key_input` の中身

```
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_close(false)
```

`KEY_ESCAPE` は Godot の `Key` enum 定数。文字列ではなく定数で比較する。`get_viewport().set_input_as_handled()` を呼ばないと背後の画面にも Escape が届く（タイトル画面などが `ui_cancel` にバインドしているため誤遷移する）。

### 暗幕クリックで閉じない保証（二重化）

1. シーン側で `Blocker.mouse_filter = STOP`、Dimmer/暗幕の `gui_input` 接続なし
2. コード側で `Blocker.gui_input` シグナルを接続しない、`_input` もオーバーライドしない
3. よって「閉じるイベントが発生する経路」が物理的に存在しない。将来誰かが `Blocker.gui_input.connect(...)` を書かない限り、暗幕クリックは閉じない

### ハンドラ接続

`_ready()` で：
- `ConfirmButton.pressed.connect(_on_confirm_pressed)`
- `CloseButton.pressed.connect(_on_close_pressed)`
- `setup()` は `Modal` 側（呼び出し側）が `_current.add_child()` 直後に呼ぶ


## 4. ポーズの扱い（最重要）

EXEC §2 で「**戻し忘れるとゲームが二度と動かなくなる**」「項目10〜12が今回いちばん事故りやすい」と強調されている箇所。`pause` を立てたモーダルだけが `paused` を操作し、そうでないモーダルは触らない——この分離を厳守する。

### `get_tree().paused = true` を立てる条件

`_apply_pause()` メソッド。`setup(pause: true)` のとき**だけ**呼ばれる。`setup(pause: false)` のときには呼ばれない。

```
func _apply_pause() -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause = true
```

- `get_tree().paused = true` でゲーム全体を停止
- `process_mode = PROCESS_MODE_ALWAYS` で**自分自身は止まらない**ようにする。止めた瞬間に自分も止まる → 入力もシグナルも `_process` も全部止まり、閉じる手段が無くなる（ESC すら拾えない）
- `_pause = true` を立てて `_exit_tree()` で参照する

### `get_tree().paused = false` に戻す箇所（3 つすべて必須）

| # | 場所 | 条件 | 処理 |
|---|---|---|---|
| 1 | `_close(result)` | `_pause == true` のとき | `_release_pause()` を呼んでから `queue_free()` |
| 2 | `_exit_tree()` | `_pause == true` のとき | `_release_pause()` を呼ぶ |
| 3 | `Modal._drain_queue()` の最後 | 次のモーダル表示の直前 | 直前のモーダルが `_pause == true` だったなら、現状は paused が false に戻っているので、ここでは何もしない。ただしキューに残ったモーダルが `pause: true` なら、その `setup()` 内で `_apply_pause()` が再度呼ばれる |

### `_release_pause()` メソッド

```
func _release_pause() -> void:
	if not _pause:
		return       # 自分が立てたのではない場合は触らない
	_pause = false
	get_tree().paused = false
```

`_pause` フラグで二重防御。`pause = false` で開いたモーダルが誤って paused を false にしてしまう事故を防ぐ。

### `_exit_tree()` の中身

```
func _exit_tree() -> void:
	# 画面遷移などで自分が予期せず消えた場合への備え。
	# pause を立てたモーダルだけ paused を戻す。
	_release_pause()
```

### 「pause を指定していないモーダルが _exit_tree() で paused に触らない」保証

`_release_pause()` の冒頭 `if not _pause: return` で担保。`pause = false` で開いたモーダルは `_apply_pause()` を一度も呼ばないため `_pause` は `false` のまま。`_exit_tree()` が走っても `_release_pause()` は早期 return して `get_tree().paused` には触れない。

### 想定事故パターンと防止

| 事故 | 防止策 |
|---|---|
| モーダル表示中に画面遷移 → 自分が `_exit_tree()` → `paused = true` のまま取り残されてゲーム停止 | `_exit_tree()` で `_release_pause()`（#2） |
| 確認モーダルで「いいえ」を押したのに `paused` が戻らない | `_close(result)` で `_release_pause()`（#1） |
| 別モーダル（`pause: false`）が `_exit_tree()` で `paused = false` にしてしまい、裏で動いている `pause: true` モーダルの停止が解除される | `_release_pause()` の `if not _pause: return` |
| モーダルがポーズで止まり自分も止まって ESC が効かない | `_apply_pause()` で `process_mode = PROCESS_MODE_ALWAYS` |
| 戦闘画面でモーダルを開いたが `paused` の効果が戦闘にも及ぶ（仕様通り） | `pause = true` を渡せば OK。`BattleController._exit_tree()` が `Engine.time_scale` を 1.0 に戻すのとは別系統で、`paused` は `time_scale` に依存せず独立に動く |


## 5. modal.gd の設計

EXEC §3 準拠。`class_name Modal extends RefCounted`。**Autoload にしない**（AGENTS.md の Autoload 5 固定ルール）。`MasterDataLoader` の静的クラスと同じスタイル。

### 静的変数の持ち方

```
class_name Modal
extends RefCounted

const MODAL_SCENE: PackedScene = preload("res://scenes/ui/components/modal_dialog.tscn")

static var _current: ModalDialog = null
static var _queue: Array = []                 # Array[Dictionary] 想定
static var _queue_scene: Node = null
```

各 Dictionary は `{caller, message_key, format_args, is_confirm, pause}` を持つ。`message_key` ではなく翻訳前キーのままキューに積むのは、表示直前に `tr()` を評価するため（`ja.csv` が後で更新されてもキュー済みのものは影響を受けない、という選択肢もあるが、EXEC §3「`tr(message_key) % format_args`」とあり、表示直前で評価するのが素直）。

ただし**シーンが変わった場合はキューをクリアする**ので、翻訳キー vs 翻訳済み文字列の差は問題にならない。`notify()` の即時表示は翻訳キーのまま積まず、`add_child` 直前に `tr()` を済ませて `message` を確定させる。

### 公開関数

#### `static func notify(caller: Node, message_key: String, format_args: Array = [], pause: bool = false) -> void`

- 内部で `_enqueue(caller, message_key, format_args, false, pause)` を呼ぶ
- `await` しない。呼び出し側は戻り値を見ない

#### `static func confirm(caller: Node, message_key: String, format_args: Array = [], pause: bool = false) -> bool`

- 内部で `_enqueue(caller, message_key, format_args, true, pause)` を呼んだ後、`_current.closed` を `await` する
- `confirm` の中で `await _current.closed` すると、`_current` が切り替わったら await が成立しなくなるため、**ローカル変数に保持してから await する**：

```
static func confirm(...) -> bool:
	_enqueue(...)
	if _current == null:
		return false
	var dlg: ModalDialog = _current
	return await dlg.closed
```

- `await` 対象をローカル変数経由にすることで、表示中に別モーダル要求が入って `_current` が差し替わっても、自分の `await` は確実に最初のモーダルの `closed` を待つ

### 内部関数

#### `static func _enqueue(caller: Node, message_key: String, format_args: Array, is_confirm: bool, pause: bool) -> void`

- `caller` から `get_tree()` を取得し、`tree.current_scene` を見る
- `current_scene == null` なら `push_warning("[Modal] current_scene is null")` して return
- **`_current` が生きている（`is_instance_valid(_current) and is_instance_valid(_current)` かつツリーに居る）ならキューに積む**
- `_current` が null か解放済みなら**即時表示**する
- `_current_scene_changed_check()` を呼んでキューをクリアする判定を先に行う

#### `static func _show(caller: Node, message_key: String, format_args: Array, is_confirm: bool, pause: bool) -> void`

- 翻訳：`var message: String = tr(message_key) if format_args.is_empty() else tr(message_key) % format_args`
- `caller.get_tree().current_scene` を取得
- `_current = MODAL_SCENE.instantiate()`
- `current_scene.add_child(_current)` —— `get_tree().root` には絶対に足さない（EXEC §3）
- `_current.setup(message, is_confirm, pause)` を呼ぶ
- `_current.closed.connect(_on_current_closed)` を `ONE_SHOT` で接続
- `_queue_scene = current_scene` を記録

#### `static func _on_current_closed(_result: bool) -> void`

- `_current.closed` シグナル発火後、`_current` は `queue_free()` される（§3 の `_close()` 順序）
- 次フレームで `is_instance_valid(_current)` が false になることを確認した上で `_current = null` に
- キューに積まれたものがあるなら `_drain_queue()` を呼ぶ

#### `static func _drain_queue() -> void`

- キュー先頭を取り出す（`pop_front()`）
- `_show()` と同等のパスで表示する
- ここで `_queue_scene` を再比較：現在の `current_scene` と違っていれば、**そのモーダルも含めてキューを全クリア**する（前の画面の通知が次の画面で出る意味不明状態を防ぐ）
  - 実装上は `_show()` 呼び出し前に `if _queue_scene != tree.current_scene: _queue.clear(); return`

#### `static func _queue_scene_changed_check(caller: Node) -> bool`

- `tree.current_scene != _queue_scene` なら `true` を返す
- `true` の場合 `_queue.clear()` する
- 通知/確認を `_enqueue` するたびに呼ぶ

### キューに積む/取り出す流れ

```
notify(caller, "ui_base_save_completed")
  └─ _enqueue(...)
	   ├─ _current が生きている？ → _queue.append(...)
	   └─ 空いている → _show(...)

（ユーザーが「閉じる」を押す）
  └─ _current.closed(false) 発火
  └─ _close(false) → queue_free()
  └─ _on_current_closed(false)
	   ├─ _current = null
	   └─ _drain_queue()
			├─ 先頭取り出し
			├─ _scene check
			└─ _show(次のモーダル)
```

### `confirm` が `await` で結果を返す仕組み

`confirm` の中で `_current` の `closed` を `await` する。`ModalDialog._close(true)` が `closed.emit(true)` を先に発火してから `queue_free()` するので、待っている側はその `true` を受け取って関数の戻り値として返す。`confirm` を呼んだ側は次の行から `true` を見て分岐できる。

```
var r: bool = await Modal.confirm(self, "ui_title_back_confirm")
if r:
	SceneManager.change_scene(TITLE_PATH)
```

「`await` 中にモーダルが別の経路で閉じられたら？」→ `_close()` 自体が `closed` を必ず 1 回発火するので、漏れはない。`_exit_tree()` 経由でも `_close()` を通す（`queue_free` する前に `closed` を発火する）ことで対応する。実装：

```
func _close(result: bool) -> void:
	closed.emit(result)
	_release_pause()
	queue_free()

func _exit_tree() -> void:
	_release_pause()        # pause の後始末
	# closed は _close 経由で既に発火済み or _current を queue_free するだけ
```

ただし「_exit_tree 経路でもシグナルを発火する必要があるか？」は別途検討が必要。**画面遷移でモーダルが消える場合、呼び出し側は遷移で先に進んでいるため、await 結果は誰も拾わない可能性が高い。** `await` 対象が `queue_free` された場合、GDScript の `await` は `null` か シグナル未発火で停止する。`confirm` 呼び出し側が遷移中なら、それは関心が無いので問題ない。

### シーンが変わったときのキューの扱い

`_enqueue` の冒頭で `_queue_scene_changed_check(caller)` を呼び、`current_scene` が変わっていたら `_queue.clear()` してから積む。`_drain_queue` の冒頭でも同じチェックを入れ、二重に防護する。


## 6. 検証用シーンの構成

`res://tests/modal_test.tscn` + `res://tests/modal_test.gd`。EXEC §4 準拠。`res://tests/` 配下に隔離し、本番シーンに検証用コードを残さない。

### modal_test.tscn のノード構成

```
ModalTest (Control)                    ← script: modal_test.gd
└─ Layout (VBoxContainer)
	└─ Buttons (VBoxContainer)
		├─ NotifyButton (Button)        text = "通知"
		├─ NotifyWithNumberButton       text = "通知（数値入り）"
		├─ NotifyTwiceButton            text = "通知を2連続"
		├─ ConfirmButton                text = "確認"
		└─ SaveFailedButton             text = "セーブ失敗の表示確認"
```

- 全ボタンが画面幅に収まるよう `Layout` に `custom_minimum_size = Vector2(0, 0)`、`Buttons` は `separation = 8`
- ボタンは素の `Button` でよい（`PrimaryButton` を使う必要なし、検証用なので）
- `text` は日本語を直書き（検証用シーンのボタンは `tr()` 不要、AGENTS.md 翻訳規則の例外に準じる）

### modal_test.gd の各ボタンの処理

```
extends Control

func _ready() -> void:
	$Layout/Buttons/NotifyButton.pressed.connect(_on_notify_pressed)
	$Layout/Buttons/NotifyWithNumberButton.pressed.connect(_on_notify_with_number_pressed)
	$Layout/Buttons/NotifyTwiceButton.pressed.connect(_on_notify_twice_pressed)
	$Layout/Buttons/ConfirmButton.pressed.connect(_on_confirm_pressed)
	$Layout/Buttons/SaveFailedButton.pressed.connect(_on_save_failed_pressed)

func _on_notify_pressed() -> void:
	Modal.notify(self, "ui_common_ok")

func _on_notify_with_number_pressed() -> void:
	Modal.notify(self, "ui_base_chest_received", [3])

func _on_notify_twice_pressed() -> void:
	Modal.notify(self, "ui_common_ok")
	Modal.notify(self, "ui_base_chest_received", [3])

func _on_confirm_pressed() -> void:
	var r: bool = await Modal.confirm(self, "ui_title_back_confirm")
	print("[ModalTest] confirm result = ", r)

func _on_save_failed_pressed() -> void:
	Modal.notify(self, "ui_base_save_failed")
```

### 期待される動作（EXEC §4 の表そのまま）

| ボタン | 期待動作 |
|---|---|
| 通知 | 「OK」表示の通知モーダル。「閉じる」のみ |
| 通知（数値入り） | 「宝箱を3個受け取りました」表示。`%d` がそのまま出ないこと |
| 通知を2連続 | 1つ目「OK」を閉じると2つ目「宝箱を3個受け取りました」が出る。同時に重ならず、後勝ちで消えない |
| 確認 | 「タイトルに戻りますか？…」確認モーダル。「はい」→ `print true`、「いいえ」→ `print false`、Escape → `print false` |
| セーブ失敗の表示確認 | 「セーブに失敗しました」表示。SaveManager を実際に失敗させず表示だけ確認 |


## 7. 判断に迷った点

### 7-1. queue に積むデータ：翻訳キー vs 翻訳済み文字列

**迷った**：`_enqueue` 時点で `tr(message_key) % format_args` を評価して翻訳済み文字列を積むか、それとも `message_key` と `format_args` をそのまま積んで `_show` 直前で翻訳するか。

**判断**：`_show` 直前で翻訳する。
- 理由：キューが長時間滞留するケースが現実的にあり、滞留中に `ja.csv` が更新（リロード含む）されても表示は最新になる
- 副次効果：「現在のシーンの言語設定で表示する」が自然に成立する

### 7-2. `confirm` の `await` 対象をローカル変数で受ける

**迷った**：`await _current.closed` と直接書くか、`var dlg = _current; await dlg.closed` とローカル変数を経由するか。

**判断**：ローカル変数を経由する。
- 理由：`confirm` を呼び出した直後に別スレッドで `_drain_queue` が走って `_current` が差し替わると、`_current.closed` のバインド先が変わる可能性がある。GDScript の `await` は式の評価時点のノードを見るので、`_show` で `add_child` したモーダルが別のものに変わると `closed` シグナルが永久に発火しない事故が考えられる
- ローカル変数に束縛すれば、最初のモーダルが `closed` を発火するまで確実に待つ

### 7-3. `pause: false` モーダルでも `process_mode` を変更すべきか

**迷った**：`pause: false` のときも `PROCESS_MODE_ALWAYS` にすべきか、既定の `PROCESS_MODE_INHERIT`（= `PROCESS_MODE_PAUSABLE` を継承）のままにすべきか。

**判断**：`pause: false` のときは**触らない**。
- 理由：そもそも pause しないので「止まる」事故が起きない。既定の `PAUSABLE` のままにしておき、別の理由でツリーが pause したときに自分も止まるのが自然
- `pause: true` のときだけ `PROCESS_MODE_ALWAYS` を設定するのは §4 で書いたとおり

### 7-4. 暗幕クリックで「意図的に」閉じたいケースの将来対応

**迷った**：今は「暗幕クリックで閉じない」が仕様。将来「通知モーダルだけ暗幕クリックで閉じたい」と言われたときのために、フラグで逃げ道を残すか。

**判断**：今は**残さない**。
- 理由：「閉じない」が仕様であることが明文化されており、AGENTS.md の「将来必要になった時点で足す」方針に沿う
- フラグを足す = コードが太る = レビューコスト増。必要になったら `setup` の引数に `dismiss_on_dimmer: bool` を足すか、`is_confirm = false` のときだけ暗幕クリックを拾うという条件分岐で十分対応できる

### 7-5. `_exit_tree()` で `closed` シグナルを発火すべきか

**迷った**：画面遷移で `queue_free` された場合、待っている `await` がエラーにならずに `false` 相当で復帰してほしい。

**判断**：今は**発火しない**。
- 理由：遷移で消えるモーダルの `await` を待っている呼び出し側は、ほぼ同時に `SceneManager.change_scene` を呼んでいて、戻ってきた `bool` 値に関心が無い。発火の有無で挙動は変わらない
- 万一 `await` したまま進まなくなるリスクは、呼び出し側が `_on_some_button_pressed()` のような単純なハンドラで await する場合は問題にならない（モーダル解放の次フレームで GDScript のランタイムが `null` を返すか、無効オブジェクトへの接続で停止する。シーン遷移で当該 Node 自体が消えるため）
- 必要になったら `_exit_tree()` でも `closed.emit(false)` を発火させる案を再検討する

### 7-6. `notify` 2連続のキュー保持期間

**迷った**：「通知を2連続」を押したあと、1つ目を閉じる前に画面遷移が起きたら2つ目が消えていいのか？

**判断**：「消える」が正しい。
- §5 で書いたとおり `_enqueue` 冒頭と `_drain_queue` 冒頭で `current_scene` を比較し、変わっていれば `_queue.clear()` する
- 前の画面（テストシーンや拠点）で積んだ通知が、次の画面（タイトル等）で出ても意味が通じないため破棄が妥当
- これも EXEC §3「前の画面の通知が次の画面で出てくると意味が分からない」に明記されている方針と一致

### 7-7. BattleDebugPanel との layer 競合

**迷った**：`ModalDialog` を `layer = 200` にしたが、戦闘画面で `Modal.notify(..., pause=true)` したときにデバッグパネル（layer=100）より手前に出る。デバッグパネル入力がモーダルに届かないのは仕様通りだが、戦闘確認中にデバッグ表示を切り替えられなくなる。

**判断**：**許容する**。
- モーダル開放確認中にデバッグ操作は無意味（閉じたいだけ）なので、layer=200 で塞いでも問題なし
- どうしても操作したければモーダルを閉じてから。デバッグは開発者向けなので UX を犠牲にしない

### 7-8. ColorRect の `mouse_filter` を明示するか

**迷った**：Blocker が `STOP` なので、子の Dimmer には `mouse_filter` を設定しなくても入力は止まる。Dimmer の `mouse_filter` を `IGNORE` で明示する価値があるか。

**判断**：**明示する**。
- 理由：Blocker を取り除いたときや、Blocker を再配置したときの事故を防ぐため
- デフォルトは `STOP` ではなく、Godot 4 では `ColorRect` のデフォルトは `MOUSE_FILTER_STOP`（3）だが、これはバージョンによって差がある。明示しておけば将来 Blocker 構成を変えても安全

### 7-9. `format_args` の型

**迷った**：`Array` で受け、`%` 演算子に渡す。`int` を渡しても `%d` でフォーマットされるが、`String` を `%s` でフォーマットする場合は String をそのまま積む。

**判断**：`Array`（型注釈なし）のままでよい。
- 内部で `tr(key) % format_args` するため、`format_args` の要素型は呼び出し側責任（EXEC §3 の例 `[3]` を見る限り `int` と `String` 混在を想定）
- `Array[Variant]` 相当を期待。静的型を厳しくすると `[3, "hoge"]` がコンパイルで弾かれるので `Array` のままにしておく

### 7-10. テストシーンの配置先

**迷った**：`res://tests/` 配下と AGENTS.md に明記。`tests/` には他の実験用シーンが入っている可能性があり、命名規約に照らして `modal_test.tscn` か `test_modal.tscn` か。

**判断**：`modal_test.tscn` にする。
- 既存の `tests/` 配下ファイル名が `*_test.tscn` 形式とは限らないが、AGENTS.md は「実験用シーンの隔離場所」とのみ書いており命名規約は強制していない
- 機能名で始まる方がgrepしやすい（`grep modal_test` で一覧できる）
- EXEC §4 のタイトル「検証用シーンの構成」と整合（「テスト」 ≒ 「検証」）

## 8. 人間による決定事項（実装時はここを最優先で従うこと）

§1〜§7 と矛盾する場合は **この章を優先する。**

### 8-1.【要修正】_exit_tree() でも closed を発火すること

§7-5 の「_exit_tree() では closed を発火しない」を変更する。
**発火すること。結果は false とする。**

理由：発火しないと、confirm() を await している呼び出し側が
永久に戻らない。Blocker が防ぐのはマウス操作だけであり、
コード側からの画面遷移は止められない。実際に起こりうる経路：

- ポモドーロのタイマー満了による自動遷移
- 5分ルールによる状態復元
- 他の処理からの SceneManager.change_scene()

await の直後には、たいてい change_scene や状態変更が書かれている。
そこへ到達しないまま関数が宙吊りになると、
「何も起きない」という形で現れ、原因の特定が難しい。

false を返せば、呼び出し側は「いいえ」と同じ扱いで自然に終わる。
「いいえ」と「閉じる」を同じ false にしたのと同じ考え方。

実装上の注意：
- 二重発火を防ぐこと。_close() で発火済みなら _exit_tree() では発火しない
- そのためのフラグ（例：_closed_emitted）を持つ
- _exit_tree() での発火順は、_release_pause() より前でも後でもよいが、
  どちらも必ず通ること

### 8-2.【明確化】_show() で _queue_scene を必ず更新すること

§5 に記述はあるが、実装で落ちやすいので明示する。

_show() を呼ぶ時点で必ず _queue_scene = current_scene を記録すること。
_drain_queue() の「シーンが変わっていたら全クリア」の経路を通ったときは
_show() を呼ばないため _queue_scene は更新されないが、
次の _enqueue() で再チェックが入るので問題ない。

### 8-3. そのまま採用する判断

以下は実装役の判断が正しい。計画のまま進めてよい。

- §2 Blocker の mouse_filter = STOP で背後の操作を止める
- §2 ModalDialog の layer = 200（デバッグパネルの 100 より上）
- §3 暗幕には gui_input を一切接続しない（クリックしても閉じない）
- §3 Escape を _unhandled_key_input で拾い set_input_as_handled する
- §3 closed を発火してから queue_free する順序
- §4 paused を戻す箇所を _close() と _exit_tree() の2つに置く
- §4 _release_pause() の冒頭で _pause フラグを見て、
  自分が立てていないポーズには触らない
- §4 pause 時に process_mode を PROCESS_MODE_ALWAYS にする
- §5 Modal を RefCounted の静的クラスにし、Autoload にしない
- §5 current_scene の子として add_child する（root には足さない）
- §5 current_scene が null なら push_warning して何もしない
- §5 _enqueue と _drain_queue の両方でシーン変更をチェックする
- §7-1 翻訳を _show の直前で行う
- §7-2 confirm の await 対象をローカル変数で受ける
- §7-4 暗幕クリックで閉じるフラグを今は用意しない
