# デザインの依頼（2026-11-08・ポモドーロだけで使える形）

web版の Claude にモックを作ってもらうための一式。**ゲームのコードは入っていない。**

絵のアセットが揃うまで、ゲーム部分なしでも **タスク管理 → ポモドーロ → 報酬** がひと続きで使える形を探す。

## 使い方

1. web版で新しい会話を開く
2. `PROMPT.md` の中身を全部貼る
3. `images/` の絵と `reference_mocks/` の HTML を添付する（⚠ 入りきらなければ、絵は `01` `02` `03` `07` `07b` `08` `09b` `10` を優先・手本は `Main_1018_desk.html` `Pomodoro.html` `Focus.html` `Chest.html` `UI_GUIDE.md` を優先）
4. できたモック（HTML）はこのフォルダの `result/` に置いて、Claude Code に「このモックから作って」と渡す

## 中身

| 置き場 | 中身 |
|---|---|
| `PROMPT.md` | web版に貼る依頼文（いまの仕組み ＋ 作ってほしい画面 A〜F ＋ 報酬の案2つ）。⚠ タスクはモックの中で実際に操作できるように頼んでいる |
| `images/` | いまの画面の絵（1280×720・2026-11-08 にゲームから撮ったもの）。⚠ 左下の DEBUG は検証用 |
| `reference_mocks/` | 前に web版で作ってもらった手本の HTML（色・字・部品の見本）。下の表 |

### 手本の対応

| ファイル | 中身 |
|---|---|
| `Pomodoro.html` `Focus.html` `FocusSkins.html` `PomoSkin.html` `Companion.html` | ポモドーロ（加護・集中・道具・小窓） |
| `Chest.html` | 宝箱（受け取りの窓の手本） |
| `Records.html` | 記録 |
| `Main.html` | 拠点（09-26 の手本一式のもの） |
| `Main_1018_desk.html` / `Main_1018_desk.png` | 拠点の机（10-18 の新しい手本・左に「今日の紙」＝タスク） |
| `TASK_MEMO_REQUEST_1004.md` | 前回（10-04）のタスクの依頼書。⚠ そのとき返ってきたタスクのモックの HTML はリポジトリに残っていない（いまの画面＝`07` がそれを入れたあと） |
| `UI_GUIDE.md` / `ui_tokens.json` | 見た目の決まり（色・字・紙・判・ボタン） |

### 絵の対応

| 絵 | 画面 |
|---|---|
| `01_protection_select_now` | 加護を選ぶ（ポモドーロに入ると最初に出る） |
| `02_focus_before_start_now` | 集中の前（右にやることのサイドバー） |
| `03_focus_running_now` / `03b_…` | 集中中 ／ 集中中にタスクの詳しくを開いた |
| `04_pomodoro_settings_now` | ポモドーロの設定 |
| `05_focus_tools_now` | 集中の道具（砂時計・ろうそく・柱時計） |
| `06_mini_window_now` 〜 `06d_…` | 小窓（いつもの／リスト／振り返り／タスク未選択で聞く） |
| `07_task_screen_now` / `07b_…` / `07c_…` | タスクの画面（拠点から）／ 日付を選ぶ ／ 消す確かめ |
| `08_base_desk_now` | 拠点の机（左が「今日の紙」） |
| `09_reward_opening_now` / `09b_…` | 受け取りの窓（開く途中／開いたあと） |
| `10_records_tasks_now` | 記録の「終わったタスク」タブ |

## 書いているときに分かったこと（コードは直していない）

- `PomodoroConfig` の `gold_per_focus_minute` / `stamina_per_focus_minute` / `materials_per_focus_minute` は**どこからも読まれていない**。ポモドーロを終えたときの `GameManager.apply_pomodoro_rewards({})` は空の辞書で呼ばれている＝**集中した分のお金・スタミナ・素材は配られていない**。いま配られているのは**ポーション（25分ごと）と加護の宝箱だけ**（`PROMPT.md` の報酬の節はこの実際の形で書いた）
- 加護の宝箱の中身は全部 `construction_material_1`（4／10／25／30個・`chests.json`）
