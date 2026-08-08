# Godotプロジェクト基盤設定

第1層・戦略計画の一部。実装開始前にGodotエディタ上で設定を完了させること。

---

## 1. プロジェクト基本設定

| 項目 | 値 |
|---|---|
| プロジェクト名 | 未定（仮称でも可、決まり次第このドキュメントを更新） |
| 対象プラットフォーム | PC専用（マウス／キーボード） |
| 画面向き | 固定なし（PCウィンドウ、リサイズ可） |
| 基準解像度 | 1280×720（16:9、後で変更可） |
| Stretch Mode | `canvas_items` |
| Stretch Aspect | `expand` |
| メインシーン | `res://scenes/title/title_screen.tscn`（ファイル名はsnake_case。`AGENTS.md`命名規則参照） |

---

## 2. エクスポート設定（Export Presets）

体験版のターゲットはPCのみのため、以下3プリセットを用意する。

| プリセット | 用途 |
|---|---|
| Windows Desktop | 主要配布形態 |
| macOS | 任意（配布予定があれば） |
| Linux/X11 | 任意（配布予定があれば） |

- アイコン・パッケージ名は後日確定（コンセプト確定後）
- 現時点では体験版用の仮アイコンで進めてよい

---

## 3. Input Map（入力アクション定義）

PC・マウス中心のUI操作が主体のため、独自アクションは最小限にする。**倉庫のドラッグ&ドロップ、施設・キャラクターのクリック判定などは、Input Mapのアクションではなく各Control/Area2Dノードの`gui_input`／`_input_event`で個別に処理する**（Godotの標準的なUI操作はInput Map不要のため）。

以下は、グローバルなショートカットとして定義するもののみ。

| アクション名 | デフォルトキー | 用途 |
|---|---|---|
| `ui_accept`（Godot標準） | Enter / Space | 各種確定ボタン |
| `ui_cancel`（Godot標準） | Escape | メニューを閉じる／一つ戻る／ポーズメニューを開く |
| `pomodoro_pause_toggle` | **P** | ポモドーロの一時停止／再開（ボタンでも操作可能にするが、キーボードショートカットも用意） |

**キー衝突の解消（決定済み）**：

- `pomodoro_pause_toggle`は当初Spaceを想定していたが、`ui_accept`（Enter / Space）と衝突し、フォーカス中のボタンが同時に押される事故が起きるため**Pキーに変更**した。
- `pause_menu_toggle`（Escape）は`ui_cancel`（Escape）と完全に重複するため**独自アクションを作らず`ui_cancel`に統合**する。ポーズメニューの開閉は、各画面が`ui_cancel`を受け取ったときの挙動として実装する（最前面にダイアログがあればそれを閉じる、無ければポーズメニューを開く）。

※ 今後、戦闘画面やトレーニングモードで固有の操作（攻撃・スキル発動など）が必要になった場合はここに追記する。

---

## 4. Autoload（シングルトン）一覧

| Autoload名 | 責務 | 備考 |
|---|---|---|
| `GameManager` | 拠点共通データ（gold, gems, stamina, materials, inventory, unlocked_screens, pity_counters等）の保持・更新 | DATA_SCHEMA.md「1. 拠点（共通データ）」に対応 |
| `Balance` | 数値調整用Resource（PomodoroConfig, ShopConfig, ResearchConfig等）を集約 | AGENTS.mdの数値管理ルールに対応。シーンとして登録し、Inspectorから`.tres`を割り当てる |
| `SaveManager` | セーブ／ロード処理（GameManagerのデータをファイルに書き出す） | セーブファイル形式・タイミングは別途設計が必要 |
| `SceneManager` | 画面遷移の一元管理（`change_scene_to_file`のラップ、遷移アニメーション等） | 直接`get_tree().change_scene_to_file()`を各所で呼ばない |
| `SignalBus` | 画面間通信用のグローバルシグナル中継 | 循環参照を避けるため、画面同士は直接参照せずSignalBus経由で通知する |

**登録順（厳守）**：`Balance` → `GameManager` → `SaveManager` → `SceneManager` → `SignalBus`。`GameManager`が`_ready()`で`Balance.initial_state`を参照するため、`Balance`が先に初期化されている必要がある。

**運用ルール**：AIはこの5つ以外のAutoloadを勝手に追加しない。追加が必要な場合は人間に提案してから登録する（AGENTS.mdに追記予定）。

---

## 5. 翻訳（ローカライズ）準備

- `res://localization/` フォルダを作成し、`.po` / `.pot` ファイルをここに配置
- デフォルトロケールは日本語（`ja`）
- AGENTS.mdの命名規則ルールにある通り、**すべてのテキストは`tr()`で囲む**（実装時点から徹底。後回しにすると全シーンの修正が必要になるため）
- Godotエディタの Project Settings → Localization → POT Generation で、`tr()`を使用しているシーン／スクリプトを自動収集する設定を有効化する

---

## 6. Steam連携の前提（体験版MVPのスコープ外・先行メモ）

実装は後回しでよいが、**先に決めておかないと後で移行が面倒になる**ものだけここに書く。

### セーブファイルの保存先（先に決めておくこと）

- セーブは必ず `user://` 配下に保存する（OSごとの適切な場所にGodotが振り分けるため）
- セーブ関連ファイルは1フォルダにまとめる：**`user://saves/`**
- 理由：Steamクラウドセーブは「指定フォルダを丸ごと同期する」仕組みのため、保存先が散っていると後から対応できない。実行ファイルと同じ場所には書かない

### Steam Rich Presence（フレンド欄への状態表示）

- ポモドーロ中の状態をフレンドリストに表示する（DATA_SCHEMA 2-7に仕様を定義済み）
- 実装には `GodotSteam`（サードパーティ製プラグイン）と、Steamworksでの App ID 取得が必要
- **表示文言はSteamworks側にローカライズトークンとして登録する**。ゲーム側からは`steam_display`キーとパラメータのみ送る
- 体験版の実装順としては最後でよい。ただし`PomodoroController`に`get_presence_status()`を用意しておくこと（`PLAN_POMODORO_CORE_LOOP.md` 6-2）
- **振り返りの入力内容は絶対に送信しない**（DATA_SCHEMA 2-7のプライバシー制約）

### 実績（Achievements）

- `DATA_SCHEMA.md`の`total_pomodoro_completed` / `streak.current_streak_days`がそのまま実績条件に使える形になっている
- 追加の設計作業は不要。App ID取得後に紐付けるだけ

### 進める順序

```
MVP完成 → 遊んで確認 → 体験版フル実装
  → Steamworks登録・App ID取得 → GodotSteam導入
  → Rich Presence・実績・クラウドセーブ
```

Steam側の作業（ストアページ・審査・トレーラー）はリリース1〜2ヶ月前から着手すれば間に合う。

---

## 未確定・要決定事項
- 正式なプロジェクト名
- アイコン・パッケージ名
- セーブファイルの保存**形式**・タイミング（自動セーブ頻度など）※保存**先**は`user://saves/`で確定（上記6章）
- 戦闘画面固有の入力アクション（トレーニングモード実装時に確定）

## 更新履歴
- 追記：6章「Steam連携の前提」を追加。セーブ保存先を`user://saves/`に確定（クラウドセーブ対応のため）。Rich Presence・実績の前提と着手順序を明記
- 改訂（整合性レビュー反映）：`pomodoro_pause_toggle`のキーをSpaceからPへ変更（`ui_accept`との衝突回避）。`pause_menu_toggle`を廃止し`ui_cancel`に統合。Autoloadの登録順を明記
