# 【作戦計画書】拠点画面（下部：リソース表示と遷移ボタン）

第2層・作戦計画。PROJECT_STATUS.mdの推奨順序に従い、まずは「下部の表示」と「遷移ボタン」のみを扱う。上部エリア（施設・キャラの描画）、施設タップ時の詳細処理、各サブ画面の中身は別の作戦計画書で扱う。

---

## 1. スコープ

### 含む
- 拠点画面のシーン階層構成
- 下部（リソース表示＋遷移ボタン）の表示ロジック
- 上部（施設・キャラ描画エリア）の**枠だけ**を用意すること
- GameManagerの状態を購読して表示を更新する仕組み
- 各遷移ボタンからSceneManager経由で画面遷移すること

### 含まない（別の作戦計画書で扱う）
- タイトル画面→拠点画面の遷移そのもの（`PLAN_TITLE_TO_BASE.md`で完了済み）
- 施設タップ後に開く各サブ画面の中身（ギルド・ポモドーロ等）
- **上部エリア（施設・キャラ）の描画・タップ判定・`SignalBus`への通知**
  → 絵のアセットが未確定で、吹き出し（`notification_label.tscn`）の追従挙動も決められないため、次の拠点タスクへ送る
- **gemsの表示**
  → 体験版にgemsを増やす手段が存在せず、常に0のまま表示され続けるため。`GameManager`には`add_gems()`と`resource_changed(GEMS, ...)`が既にあり、必要になった時点で1エントリ足せば済む
- キャラクターの配置ロジック・アニメーション詳細

---

## 2. 画面構成（SCENES.mdより）

2ウィンドウ構成：
- **上**：施設・キャラ描画（本計画書では空の枠のみ）
- **下**：リソース＋遷移ボタン

### 遷移先一覧
| ボタン | 遷移先screen_id | unlocked_screensでの表示制御 |
|---|---|---|
| 冒険選択 | adventure_select | あり |
| ギルド | guild | あり |
| ポモドーロ | pomodoro | あり |
| 設定 | settings | あり |
| シナリオ | scenario | あり |

すべて `DATA_SCHEMA.md`「1. 拠点（共通データ）」の`unlocked_screens`に対応するキーが存在する。`screen_id`は`GameStateKeys.SCREEN_*`の定数として定義し、文字列リテラルで散らさない。

---

## 3. シーン階層案

```
res://scenes/base/base_screen.tscn
BaseScreen (Control)
├─ Background (ColorRect)
└─ Layout (VBoxContainer)
	├─ TopArea (Control)                  # 今回は空。施設・キャラは次タスク
	└─ BottomArea (PanelContainer)
		└─ BottomLayout (VBoxContainer)
			├─ ResourceRow (HBoxContainer)
			│   ├─ GoldEntry（NameLabel + ResourceDisplay）
			│   ├─ StaminaEntry（NameLabel + ResourceDisplay）
			│   ├─ MaterialsDisplay
			│   │   └─ MaterialEntry（materialsの種類数ぶん動的生成）
			│   ├─ Spacer
			│   ├─ ChestBadge (Button)
			│   │   └─ ChestCountLabel
			│   ├─ SaveButton         # 仮。オートセーブ実装まで
			│   └─ BackToTitleButton  # 仮。同上
			└─ NavigationButtons (HBoxContainer)
				├─ AdventureButton
				├─ GuildButton
				├─ PomodoroButton
				├─ SettingsButton
				└─ ScenarioButton
```

- `scenes/ui/components/`の共通ボタン（`primary_button.tscn`）を`NavigationButtons`配下で使い回す
- レイアウトの目安（1280×720基準）：`BottomArea`の高さ160、内訳は`ResourceRow` 56 : `NavigationButtons` 104。遷移ボタンは`EXPAND_FILL`で等幅に広げる
- `ChestBadge`は`Spacer`を挟んで右側に置き、リソース表示と視覚的に分離する（所持数ではなく画面遷移の導線であるため）

### 命名について（実装済みコードとの整合）

| 当初案 | 現行 | 理由 |
|---|---|---|
| `ResourceDisplay`（コンテナ名） | `ResourceRow` | 共通パーツの`class_name ResourceDisplay`と同名で紛らわしい |
| `GoldLabel` | `GoldEntry`（名前ラベル＋`ResourceDisplay`の組） | 実装済みの`ResourceDisplay`は`Icon`と`ValueLabel`しか持たず、名前を出す手段がない。アイコン画像が未用意の現状、数字だけでは何の値か分からない |
| `GemsLabel` | 削除 | 上記1章のとおり |
| `ChestIcon` | `ChestBadge`（`Button`） | アイコン画像が未用意。テクスチャができたら`TextureButton`に差し替える |
| （なし） | `SaveButton` / `BackToTitleButton` | オートセーブが未実装のため、これを消すとゲームがセーブ不能になる。暫定措置 |

---

## 4. 表示データ（DATA_SCHEMA.mdより）

`GameManager.get_state()`から取得する（返り値は`duplicate(true)`の読み取り専用スナップショット。書き換えても内部状態には反映されない）：

| データ | 表示先 | 備考 |
|---|---|---|
| `gold` | GoldEntry | そのまま数値表示 |
| `stamina.current` / `stamina.max` | StaminaEntry | `"current/max"`形式 |
| `materials`（種類ごと） | MaterialsDisplay内のMaterialEntry | `materials`辞書のキーごとに1エントリ動的生成。素材名は`tr("ui_res_" + material_id)`で引く |
| `unlocked_screens` | NavigationButtonsの各visible | falseなら非表示。判定は`GameManager.is_screen_unlocked()` |
| `pending_chests` | ChestBadge（ボタン＋未開封件数） | 下記6-1参照 |

### staminaの注意（実コードで確認済み）

**`resource_changed(STAMINA, ...)`の第2引数は`current`の`int`単体で、`max`を含まない。**
`ResourceDisplay.set_value_with_max()`は`max`を必要とするため、`set_value_with_max(current, 0)`と書くと`10/0`と表示される。`max`は`get_state()`から読み直すこと。

将来`max`を変更する機能（研究・施設強化等）が入ったら、GameManager側に`max`を含む通知を追加して差し替える。

---

## 5. 更新の仕組み

- `base_screen`のスクリプトは`_ready()`で以下を購読する：
  - `GameManager.resource_changed(resource_type, new_value)` → 該当エントリのみ更新。`resource_type`は`GameStateKeys.GOLD` / `STAMINA`のいずれか（文字列リテラルで比較しないこと）。`GEMS`は表示していないため無視する
  - `GameManager.material_changed(material_id, new_amount)` → 該当する`MaterialEntry`のみ更新。エントリが未生成なら新規生成する
  - `GameManager.screen_unlocked(screen_id)` → 該当ボタンのvisibleを更新
  - `GameManager.pending_chests_changed(pending_count)` → 下記6-1
- 画面遷移で戻ってくるたびに全データを再取得するのではなく、シグナル駆動で差分更新する（AGENTS.mdのSingle Source of Truth方針に合わせる）

### 遷移先の対応表

- 遷移先のシーンパスは、ボタンごとに直書きせず**`screen_id → シーンパス`の対応表（定数Dictionary）1箇所に集約する**。各画面が実装できたら表の該当行を差し替えるだけでよく、ボタン側のコードを触らずに済む
- 遷移先の画面がまだ存在しない間は、すべて`res://scenes/ui/placeholder_screen.tscn`（未実装画面・共通の受け皿）を指す。`SceneManager.change_scene_with_data()`で`screen_id`を渡し、受け取り側が画面名を出し分ける
- 5つの空シーンを作らない理由：空シーンを残すと、後続タスクで「既存を書き換えるのか新規で作るのか」が曖昧になるため。仮が1つなら「これは仮」が明らかになる

---

## 6. 個別仕様

### 6-1. チェストバッジの仕様

- `pending_chests`配列のうち`opened: false`の件数を`ChestCountLabel`に表示する
- 件数が0の場合は`ChestBadge`自体を非表示にする
- タップで倉庫（ギルド内）の宝箱受け取りUIへ遷移する。倉庫は単独シーンがまだ無いため、当面はギルドの遷移先を共用する
  - 受け取り処理自体（開封演出・報酬付与）は倉庫画面側の作戦計画書で扱う。ここでは遷移のトリガーのみ
- 更新タイミング：`GameManager.pending_chests_changed(pending_count)`シグナル受信時。`pending_count`をそのまま反映し、0なら非表示にする
- 初期表示は`GameManager.get_pending_chest_count()`を`_ready()`で呼び出す

### 6-2. 施設・キャラタップ時の挙動

※ **上部エリアそのものが次タスク送りになったため、本節の内容は今回のスコープに含まれない。方針としては維持する。**

- 施設ノードタップ → `SignalBus.facility_tapped(facility_id)` を発火するのみ
- キャラノードタップ → `SignalBus.character_tapped(character_id)` を発火するのみ
- 発火後にどの画面が何を表示するか（ダイアログ、詳細画面遷移等）はこの計画書のスコープ外。各サブ画面側がSignalBusを購読して自分で処理する（AGENTS.mdの「画面同士は直接参照しない」制約に準拠）

### 6-3. 素材エントリの動的生成

- `materials`は種類が増える想定のため、`.tscn`に決め打ちで並べずスクリプトから生成する
- 生成した`MaterialEntry`は`material_id`をキーにした`Dictionary`で保持し、`material_changed`受信時に該当エントリのみ更新する
- 未知の`material_id`が来たら、その場で新規エントリを生成して追加する
- 翻訳キーが`ja.csv`に無い場合、`tr()`はキー文字列をそのまま返す。**これは意図した挙動として許容する**（素材を追加したときの`ja.csv`への追記漏れが画面上ですぐ分かるため）。フォールバック処理は入れない

---

## 7. 未確定・要決定

- `materials`の種類数が増えた場合のレイアウト（スクロール／折り返し等）
  → 現状1種類のため今回は決めない。3種類を超えた時点（作業場・研究の実装後）に判断する
- 施設・キャラの配置座標やレイアウトの詳細 → 次の拠点タスクで扱う
- gemsを下部に表示するか → 現状は表示しない。gemsを増やす手段が実装されたら再検討する
- `stamina.max`の変化を通知する手段がGameManagerに無い
  → 現状maxを変える機能が無いため実害なし。研究・施設強化等でmaxを動かす機能が入る際に、GameManager側へ通知を追加する
- `SaveButton` / `BackToTitleButton`をいつ外すか
  → オートセーブ（保存タイミング）の設計タスク時に判断する

---

## 8. 完了条件（このチェックポイントのゴール）

- [ ] `base_screen.tscn`が上記シーン階層案の通りに作成されている
- [ ] `GameManager.add_gold(100)`を呼ぶと、`GoldEntry`の数値だけが自動更新される
- [ ] `GameManager.add_material()`を呼ぶと、該当する`MaterialEntry`のみが更新される（全エントリを作り直さない）。未知の素材IDなら新規エントリが追加される
- [ ] `stamina`が`current/max`形式で表示され、`spend_stamina()`後も`max`が0に化けない
- [ ] `pending_chests`が0件のときは`ChestBadge`が非表示、1件以上で件数表示される
- [ ] `unlocked_screens`がfalseの画面のボタンは非表示になっている
- [ ] 各遷移ボタンが`SceneManager.change_scene_with_data()`経由でのみ画面遷移する（`change_scene_to_file()`を直接呼ばない）
- [ ] 遷移先が未実装画面に集約され、画面名がボタンごとに出し分けられる

この計画書がそのまま第3層（実行指示書）のベースになる。第3層は`EXEC_BASE_SCREEN.md`（完了条件20項目）。

---

## 更新履歴
- 初版：拠点画面（表示のみ）の作戦計画書として作成
- 改訂（実コード突き合わせ・`EXEC_BASE_SCREEN.md`執筆時）：
  - 上部エリア（施設・キャラ）とgems表示をスコープ外に変更。完了条件から「施設・キャラタップでシグナル発火」を削除
  - シーン階層案を実装済みの共通パーツ（`ResourceDisplay`が名前ラベルを持たない）に合わせて改訂。`GemsLabel`削除、`ChestIcon`を`ChestBadge`(Button)に変更、暫定の`SaveButton` / `BackToTitleButton`を追加
  - `resource_changed(STAMINA)`が`current`のみを運ぶ事実を4章に明記（`10/0`表示事故の防止）
  - 遷移先を`screen_id → シーンパス`の対応表に集約し、未実装画面1つへ集約する方針を5章に追加
  - 素材エントリの動的生成の詳細を6-3として追加
