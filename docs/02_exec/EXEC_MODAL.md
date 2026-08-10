# 【実行指示書】汎用モーダル（タスク1・本体）

`PLAN_MODAL.md` のタスク1に対応する第3層。**各画面への適用（宝箱・タイトルへ戻る確認・セット完了）はタスク2であり、今回は含まない。**

---

## §0 作業の進め方（厳守）

| 禁止 | 理由 |
|---|---|
| `edit_file` | このプロジェクトでは動作しない |
| `create_file` に150行を超える本文 | トークン上限で失敗する。`cat >>` で分割する |
| `cat >` での既存ファイルの上書き | 既存の内容が消える |
| `sed` / `awk` | シェル依存で動作が保証されない |
| 補助スクリプト（`.py` 等）の作成 | 誤字修正のために作り始めて止まらなくなる |
| 書き終わったあとの読み返し・誤字修正 | 誤字は人間が直す |
| `.tres` ファイルの編集 | 人間がInspectorで行う |
| `autoload/` 配下の編集 | 人間が行う |
| `ja.csv` の編集 | 人間が行う |
| `project.godot` の変更 | 人間が行う |
| 中間ファイルを経由した書き換え | 編集先を取り違える |

**例外**：既存ファイルに追記した直後だけ `read` で開き、破壊されていないことを確認すること。

### 止まってよい・止まるべき条件

**1つのファイルへの書き込みが2回失敗したら、そのファイルは諦めて報告すること。** 方法を変えても回数は増える。キャッシュ削除・再起動・ファイルを消して作り直すのも1回に数える。

「編集したのに反映されない」と感じたら、環境の問題だと判断する前に、**編集したファイルのパスが実際に読み込まれているファイルと同じか**を確認すること。

### 未実装と書いてよい

実装できなかったファイルは「未実装」と正直に書いてよい。埋めなくてよい。**指示書の一覧に無いファイルを作らないこと。**

---

## 前提・参照ドキュメント

- `AGENTS.md`
- `PLAN_MODAL.md`

### 既存の実装状況（実コードで確認済みの事実）

| 事実 | 場所 |
|---|---|
| Autoloadは5つ固定。**6つ目を作らない** | `AGENTS.md` |
| `MasterDataLoader` / `SkillResolver` は `scripts/systems/` の静的クラス。Autoloadではない | `scripts/systems/` |
| `PrimaryButton`（`scenes/ui/components/primary_button.tscn`）は `label_key` に翻訳キーを入れると `tr()` を通す | `primary_button.gd` |
| `SaveManager.save_game()` は `bool` を返す。`false` になるのは `FileAccess.open()` が `null` を返したときのみ | `autoload/save_manager.gd` |
| `BattleDebugPanel` は `CanvasLayer` の `layer = 100` を使っている | `scenes/adventure/battle_debug_panel.gd` |
| 戦闘画面は `Engine.time_scale` を変更し、`_exit_tree()` で1.0に戻している | `scenes/adventure/battle_controller.gd` |
| `ja.csv` に `ui_common_close` と `ui_common_ok` は**既にある** | `localization/ja.csv` |
| `ColorRect` にThemeは効かない。色を直接指定する必要がある | 実測（冒険選択画面の背景が白くなった） |

---

## 今回のタスク

### やること

1. `modal_dialog.tscn` と `modal_dialog.gd`（ダイアログ本体）
2. `modal.gd`（静的な呼び出し口）
3. `tests/modal_test.tscn` と `modal_test.gd`（検証用シーン）

### やらないこと

- **各画面への適用**（宝箱・タイトルへ戻る確認・ポモドーロのセット完了）。タスク2
- トースト（自動で消える通知）
- 入力欄つきダイアログ
- アニメーション・効果音
- 複数のモーダルを同時に重ねて表示すること
- 冒険選択画面の `MessageLabel` の置き換え。**あれは画面内に留めるのが仕様**

### 人間が対応済み（触らないこと）

- `localization/ja.csv` への翻訳キー追記（§5に一覧）
- `scenes/base/base_screen.gd` の `_on_save_pressed()` の変更

---

## §1 `modal_dialog.tscn`

出力先：`res://scenes/ui/components/modal_dialog.tscn`

```
ModalDialog (CanvasLayer)  ← modal_dialog.gd
└─ Blocker (Control)              全画面（Full Rect）
    ├─ Dimmer (ColorRect)         全画面（Full Rect）
    └─ Panel (PanelContainer)     中央
        └─ Margin (MarginContainer)
            └─ VBox (VBoxContainer)
                ├─ MessageLabel (Label)
                └─ Buttons (HBoxContainer)
                    ├─ ConfirmButton   primary_button.tscn
                    └─ CloseButton     primary_button.tscn
```

### 設定

- `ModalDialog` の `layer` は **200**。デバッグパネルが100なので、それより上に出す
- `Blocker` の `mouse_filter` を **`STOP`** にする。**これが背後のボタンを止める仕組み**
- `Dimmer` の色は `Color(0, 0, 0, 0.6)`。**`ColorRect` にThemeは効かないので直接指定する**
- `MessageLabel` は `autowrap_mode` を `WORD_SMART` にし、`custom_minimum_size.x` を 400 程度にする。本文が長いと縦に伸び、横には伸びない形にする
- ボタンの `label_key` はコード側で設定する。シーンには入れない

---

## §2 `modal_dialog.gd`

出力先：`res://scenes/ui/components/modal_dialog.gd`

```gdscript
class_name ModalDialog
extends CanvasLayer
```

### シグナル

```gdscript
signal closed(result: bool)
```

通知モーダルでも発火する（そのときは常に `false`）。

### 公開関数

```gdscript
func setup(message: String, is_confirm: bool, pause: bool) -> void
```

- `message` は**翻訳済みの文字列**を受け取る。`tr()` はここで呼ばない（`Modal` 側で済ませる）
- `is_confirm` が `true` なら `ConfirmButton` を表示し、`CloseButton` の `label_key` を `ui_common_no` にする
- `is_confirm` が `false` なら `ConfirmButton` を隠し、`CloseButton` の `label_key` を `ui_common_close` にする

### ポーズの扱い（重要）

`pause` が `true` のときのみ：

- `get_tree().paused = true`
- 自分自身の `process_mode` を `PROCESS_MODE_ALWAYS` にする（止めた側が止まると閉じられない）

閉じるときに `false` に戻す。**`_exit_tree()` でも戻すこと。**

**戻し忘れるとゲームが二度と動かなくなる。** 画面遷移などでモーダルが予期せず消えた場合に備えて、閉じる処理と `_exit_tree()` の両方に入れる。`pause` を指定していないモーダルは、`_exit_tree()` でも `paused` に触らないこと（他のモーダルが止めている最中に解除してしまう）。

### 閉じ方

| 操作 | 結果 |
|---|---|
| `ConfirmButton` | `closed(true)` |
| `CloseButton` | `closed(false)` |
| `Escape` | `closed(false)` |
| **暗幕のクリック** | **閉じない** |

`Escape` は `_unhandled_key_input()` で拾い、`get_viewport().set_input_as_handled()` を呼ぶこと。呼ばないと背後の画面にも届く。

閉じるときは `closed` を発火してから `queue_free()` する。**順序が逆だと、待っている側にシグナルが届かない。**

暗幕をクリックしても閉じないのは仕様。**確認モーダルで誤って閉じると意図しない結果になるため。**

---

## §3 `modal.gd`

出力先：`res://scripts/systems/modal.gd`

```gdscript
class_name Modal
extends RefCounted
```

**Autoloadにしない。** 静的関数のみを持つ。

### 公開関数

```gdscript
static func notify(caller: Node, message_key: String, format_args: Array = [], pause: bool = false) -> void
static func confirm(caller: Node, message_key: String, format_args: Array = [], pause: bool = false) -> bool
```

- `caller` はシーンツリーを辿るために使う
- `message_key` は**翻訳キー**。生の日本語を受け取らない
- `format_args` が空でなければ、`tr(message_key) % format_args` で数値を差し込む
- `confirm` は `await` で `bool` を返す

`format_args` を `Array` にしているのは、`%d個の宝箱を%s から受け取りました` のような複数差し込みに対応するため。`ja.csv` 側に `%d` を書く。

### 差し込む場所

`caller.get_tree().current_scene` の子として `add_child()` する。

**`get_tree().root` に直接足さないこと。** シーンを切り替えたときに取り残され、次の画面に居座る。

`current_scene` が `null` の場合は `push_warning` を出して何もしない。

### キュー

静的変数で持つ。

```gdscript
static var _current: ModalDialog = null
static var _queue: Array = []
static var _queue_scene: Node = null
```

- `_current` が生きているなら、新しい要求は `_queue` に積む
- `_current` が閉じたら、キューの先頭を取り出して表示する
- **後勝ちで上書きしないこと。** 宝箱の通知がセーブ失敗の通知に消されると報酬を見逃す

**シーンが変わったらキューを空にする。** 表示のたびに `current_scene` を `_queue_scene` と比べ、違っていたら `_queue` を `clear()` してから積む。前の画面の通知が次の画面で出てくると意味が分からない。

`_current` は `is_instance_valid()` で確認すること。`queue_free()` された参照が残る。

### `confirm` の待ち方

`ModalDialog` の `closed` シグナルを `await` して、その結果を返す。**キューに積まれた場合も、実際に表示されて閉じるまで待つこと。**

---

## §4 検証用シーン

出力先：`res://tests/modal_test.tscn` と `res://tests/modal_test.gd`

**`res://tests/` に置く。本番シーンに検証用コードを残さない**（`AGENTS.md`）。

ボタンを5つ並べ、それぞれ押すと以下を実行する。押した結果は `print` で出す。

| ボタン | 動作 |
|---|---|
| 通知 | `Modal.notify(self, "ui_common_ok")` |
| 通知（数値入り） | `Modal.notify(self, "ui_base_chest_received", [3])` |
| 通知を2連続 | `notify` を2回続けて呼ぶ（キューの確認） |
| 確認 | `var r = await Modal.confirm(self, "ui_title_back_confirm")` の結果を `print` |
| セーブ失敗の表示確認 | `Modal.notify(self, "ui_base_save_failed")` |

**最後の1つを入れる理由**：`SaveManager.save_game()` が `false` を返すのは書き込み用にファイルを開けなかったときだけで、実機で意図的に起こすのが難しい。**表示だけをここで確認する。**

---

## §5 翻訳キー（人間が `ja.csv` に追記する）

**実装役はこのファイルを編集しないこと。**

`ui_common_close` と `ui_common_ok` は既にあるため追記しない。

| キー | 日本語 |
|---|---|
| `ui_common_yes` | はい |
| `ui_common_no` | いいえ |
| `ui_base_save_completed` | セーブしました |
| `ui_base_save_failed` | セーブに失敗しました |
| `ui_base_chest_received` | 宝箱を%d個受け取りました |
| `ui_title_back_confirm` | タイトルに戻りますか？ 保存していない進行状況は失われます |

下2つはタスク2で使うものだが、検証用シーンで表示を確かめるため先に入れる。

---

## §6 人間が担当する変更

**実装役はこのファイルに触らないこと。** 参考として載せる。

`scenes/base/base_screen.gd` の `_on_save_pressed()` を以下にする。

```gdscript
func _on_save_pressed() -> void:
	if SaveManager.save_game():
		Modal.notify(self, "ui_base_save_completed")
	else:
		Modal.notify(self, "ui_base_save_failed")
```

---

## 動作確認手順（完了条件）

**この12項目を、項目番号と文言をそのまま IMPL_LOG に転記すること。** 要約したり作り直したりしないこと。

**書き方**：`[ ] 項目N：（EXECの文言をそのまま）` を先に書き、**改行してから**検証結果を書くこと。1つの文にまとめないこと。

「何をしたら何と表示されたか」を書くこと。実際に動かせなかった項目は `[x]` を付けず、「実機未検証」と正直に書いてよい。

1. [ ] 拠点でセーブボタンを押すと「セーブしました」の通知モーダルが出る
2. [ ] モーダルが出ている間、背後の遷移ボタン（冒険・ギルド・ポモドーロ）をクリックしても反応しない
3. [ ] 「閉じる」でモーダルが消え、背後のボタンが再び押せるようになる
4. [ ] `Escape` でも閉じる
5. [ ] 暗幕（本文の外側の暗い部分）をクリックしても閉じない
6. [ ] 本文が翻訳キー（`ui_base_save_completed`）ではなく日本語で表示される
7. [ ] `tests/modal_test.tscn` の「確認」を押すと「はい」「いいえ」の2つのボタンが出て、「はい」で `true`、「いいえ」で `false`、`Escape` で `false` が `print` される
8. [ ] 「通知を2連続」を押すと、1つ目を閉じたあとに2つ目が出る（同時に重ならず、後勝ちで消えない）
9. [ ] 「通知（数値入り）」で「宝箱を3個受け取りました」と表示される（`%d` のまま出ていないこと）
10. [ ] `pause` を `true` にして戦闘画面から呼ぶと、ユニットの動きが止まり、閉じると再開する
11. [ ] モーダルを開いたまま画面を遷移させると、次の画面にモーダルが残らない
12. [ ] `pause` を `true` にしたモーダルを開いたまま画面を遷移させても、ゲームが止まったままにならない（拠点のボタンが押せる）

**項目10〜12が今回いちばん事故りやすい。** `get_tree().paused` を戻し損ねるとゲームが二度と動かなくなり、再起動しないと確認を続けられない。

項目10は、`battle_controller.gd` に一時的に呼び出しを足して確認してよい。**確認後に必ず消し、消したことを IMPL_LOG に明記すること。**

---

## 最後に必ず報告すること

変更・作成したすべてのファイルについて、次の表を出すこと。

| パス | 新規/変更/未実装 | 行数 |

行数は `read` で開いて数えた実際の値を書くこと。**この指示書の一覧に無いパスがこの表にあってはいけない。**

そのうえで `IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_MODAL.md` を生成すること。「5. 指示書からの逸脱・迷った判断」を空欄にしないこと。

---

## 遵守事項（`AGENTS.md` より再掲）

- ファイル名は snake_case。`class_name` とノード名は PascalCase
- 表示テキストは `tr()` を通す。数値のみの表示と `print` / `push_warning` は除く
- **`Modal` に生の日本語を渡す経路を作らない。** 翻訳キーのみを受け取る
- キーは `GameStateKeys` / `TransferKeys` の定数経由。文字列リテラルを書かない
- 画面遷移は `SceneManager` 経由
- **Autoloadを増やさない**
- `class_name` が認識されないエラーが出たら Godot を再起動する。型指定を `Node` に落として `call()` で回避しない
