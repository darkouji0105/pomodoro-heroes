# 【作戦計画書】拠点画面（表示のみ）

第2層・作戦計画。PROJECT_STATUS.mdの推奨順序に従い、まずは「表示」と「遷移ボタン」のみを扱う。施設タップ時の詳細処理（各サブ画面の中身）や、タイトル→拠点への遷移演出そのものは別の作戦計画書で扱う。

---

## 1. スコープ

### 含む
- 拠点画面のシーン階層構成
- 上部（施設・キャラ描画エリア）の表示ロジック（最小限）
- 下部（リソース表示＋遷移ボタン）の表示ロジック
- GameManagerの状態を購読して表示を更新する仕組み
- 各遷移ボタンからSceneManager経由で画面遷移すること

### 含まない（別の作戦計画書で扱う）
- タイトル画面→拠点画面の遷移そのもの
- 施設タップ後に開く各サブ画面の中身（ギルド・ポモドーロ等）
- キャラクターの配置ロジック・アニメーション詳細

---

## 2. 画面構成（SCENES.mdより）

2ウィンドウ構成：
- **上**：施設・キャラ描画
- **下**：リソース＋遷移ボタン

### 遷移先一覧
| ボタン | 遷移先screen_id | unlocked_screensでの表示制御 |
|---|---|---|
| 冒険選択 | adventure_select | あり |
| ギルド | guild | あり |
| ポモドーロ | pomodoro | あり |
| 設定 | settings | あり |
| シナリオ | scenario | あり |

すべて `DATA_SCHEMA.md`「1. 拠点（共通データ）」の`unlocked_screens`に対応するキーが存在する。

---

## 3. シーン階層案

```
res://scenes/base/base_screen.tscn
BaseScreen (Control)
├─ TopArea (Control)
│   ├─ FacilityContainer
│   └─ CharacterContainer
└─ BottomArea (Control)
    ├─ ResourceDisplay
    │   ├─ GoldLabel
    │   ├─ GemsLabel
    │   ├─ StaminaLabel
    │   ├─ MaterialsDisplay
    │   │   └─ MaterialEntry（materialsの種類数ぶん動的生成）
    │   └─ ChestBadge
    │       ├─ ChestIcon
    │       └─ ChestCountLabel
    └─ NavigationButtons
        ├─ AdventureButton
        ├─ GuildButton
        ├─ PomodoroButton
        ├─ SettingsButton
        └─ ScenarioButton
```

- `scenes/ui/components/`の共通ボタン（PrimaryButton等）を`NavigationButtons`配下で使い回す。

---

## 4. 表示データ（DATA_SCHEMA.mdより）

`GameManager.get_state()`から取得する想定（返り値は読み取り専用のスナップショット。表示以外の用途で書き換えないこと）：

| データ | 表示先 | 備考 |
|---|---|---|
| `gold` | GoldLabel | そのまま数値表示 |
| `gems` | GemsLabel | そのまま数値表示 |
| `stamina.current` / `stamina.max` | StaminaLabel | `"current/max"`形式 |
| `materials`（種類ごと） | MaterialsDisplay内のMaterialEntry | `materials`辞書のキーごとに1エントリ生成。種類が増えてもレイアウトが破綻しないようScrollContainer or 折り返しレイアウトを検討 |
| `unlocked_screens` | NavigationButtonsの各visible | falseなら非表示 |
| `pending_chests` | ChestBadge（アイコン＋未開封件数） | 下記6-1参照 |

---

## 5. 更新の仕組み

- `base_screen`のスクリプトは`_ready()`で以下を購読する：
  - `GameManager.resource_changed(resource_type, new_value)` → 該当ラベルのみ更新
  - `GameManager.screen_unlocked(screen_id)` → 該当ボタンのvisibleを更新
- 画面遷移で戻ってくるたびに全データを再取得するのではなく、シグナル駆動で差分更新する（AGENTS.mdのSingle Source of Truth方針に合わせる）。

---

## 6. 個別仕様

### 6-1. チェストバッジ（宝箱アイコン）の仕様

- `pending_chests`配列のうち`opened: false`の件数をカウントし、`ChestCountLabel`に表示する
- 件数が0の場合は`ChestBadge`自体を非表示にする
- `ChestIcon`タップで倉庫（ギルド内）の宝箱受け取りUIへ遷移する（`SceneManager.change_scene()`経由）
  - 受け取り処理自体（開封演出・報酬付与）は倉庫画面側の作戦計画書で扱う。ここでは遷移のトリガーのみ
- 更新タイミング：`GameManager.pending_chests_changed(pending_count)`シグナル受信時。`ChestCountLabel`にそのまま`pending_count`を反映し、0なら`ChestBadge`を非表示にする
- 件数取得の初期表示は`GameManager.get_pending_chest_count()`を`_ready()`で呼び出す

### 6-2. 施設・キャラタップ時の挙動（最小実装）

- 施設ノードタップ → `SignalBus.facility_tapped(facility_id)` を発火するのみ
- キャラノードタップ → `SignalBus.character_tapped(character_id)` を発火するのみ
- 発火後にどの画面が何を表示するか（ダイアログ、詳細画面遷移等）はこの計画書のスコープ外。各サブ画面側がSignalBusを購読して自分で処理する（AGENTS.mdの「画面同士は直接参照しない」制約に準拠）。

---

## 7. 未確定・要決定

- `materials`の種類数が増えた場合のレイアウト（スクロール／折り返し等）の最終仕様
- 施設・キャラの配置座標やレイアウトの詳細（本計画書では扱わず、実装時に決める）

※ `pending_chests`変更通知用シグナルは`PLAN_COMMON_INFRA.md`に追記済み（`pending_chests_changed`）。

---

## 8. 完了条件（このチェックポイントのゴール）

- [ ] `base_screen.tscn`が上記シーン階層案の通りに作成されている
- [ ] `GameManager.add_gold(100)`を呼ぶと、拠点画面上の`GoldLabel`が自動更新される
- [ ] `GameManager.add_material()`を呼ぶと、`MaterialsDisplay`に該当エントリが表示・更新される
- [ ] `pending_chests`が0件のときは`ChestBadge`が非表示、1件以上で件数表示される
- [ ] `unlocked_screens`がfalseの画面のボタンは非表示になっている
- [ ] 各遷移ボタンが`SceneManager.change_scene()`経由でのみ画面遷移する（`change_scene_to_file()`を直接呼ばない）
- [ ] 施設・キャラタップで`SignalBus`にシグナルが発火することをprintで確認できる

この計画書がそのまま第3層（実行指示書）のベースになる。
