# プロジェクト進捗状況 / 次の会話での使い方ガイド

このドキュメント自体を、新しい会話の最初に見せると状況共有が早い。

---

## 全体進捗（3層構造）

| 層 | 内容 | 状態 |
|---|---|---|
| **第1層：戦略計画** | プロジェクト全体の設計図・ルール | ✅ **完了**（`CLAUDE.md`は`AGENTS.md`にリネーム済み） |
| **第2層：作戦計画** | 各画面・機能の詳細設計 | 🟡 **一部完了**（冒険選択・パーティ選択・設定・シナリオ等が未作成。下記参照） |
| **第3層：実行指示書** | AIに渡す実装プロンプト | 🟡 **一部完了**（共通基盤のみ・未実装） |

---

## ファイル一覧と役割

### 第1層（戦略計画）── 全て完了
| ファイル | 内容 |
|---|---|
| `CONCEPT.md` | コンセプトシート・設計原則 |
| `SCENES.md` | シーンインベントリ・画面遷移図・体験版スコープ |
| `DATA_SCHEMA.md` | 全画面のデータスキーマ（拠点・ポモドーロ・冒険選択・戦闘・ギルド） |
| `AGENTS.md`（旧`CLAUDE.md`） | プロジェクトルール（フォルダ構造・命名規則・数値管理・Autoload一覧・拒否仕様）。Zivaが実際に読み込む規約ファイル名に合わせてリネーム済み |
| `GODOT_SETUP.md` | Godotプロジェクト基盤設定（Input Map・エクスポート・翻訳準備） |
| `CHECKPOINTS.md` | MVP定義・段階的ロードマップ |
| `DEMO_CHECKLIST.md` | デモ版として完成とみなす全項目チェックリスト |

### 第2層（作戦計画）── 一部完了
| ファイル | 内容 | 状態 |
|---|---|---|
| `PLAN_COMMON_INFRA.md` | 5つのAutoload（GameManager/Balance/SaveManager/SceneManager/SignalBus）のインターフェース定義。チェスト・ポモドーロ報酬・戦闘報酬・ショップ・育成・研究・作業場対応で拡張済み | ✅ 完了 |
| `PLAN_UI_COMMON.md` | Theme・共通UIコンポーネント（ボタン等）の方針 | ✅ 完了 |
| `PLAN_TITLE_TO_BASE.md` | タイトル→拠点画面（遷移のみ）の作戦計画書 | ✅ 完了 |
| `PLAN_BASE_SCREEN.md` | 拠点画面（表示のみ）の作戦計画書 | ✅ 完了 |
| `PLAN_POMODORO_CORE_LOOP.md` | ポモドーロ最小ループの作戦計画書 | ✅ 完了 |
| `PLAN_BATTLE_SCREEN.md` | 戦闘画面（本番用）の作戦計画書 | ✅ 完了 |
| `PLAN_GUILD_WAREHOUSE.md` | ギルド：倉庫の作戦計画書 | ✅ 完了 |
| `PLAN_GUILD_SHOP.md` | ギルド：ショップの作戦計画書 | ✅ 完了 |
| `PLAN_GUILD_TRAINING.md` | ギルド：育成の作戦計画書 | ✅ 完了 |
| `PLAN_GUILD_RESEARCH.md` | ギルド：研究の作戦計画書 | ✅ 完了 |
| `PLAN_GUILD_WORKSHOP.md` | ギルド：作業場の作戦計画書 | ✅ 完了 |

#### ⬜ 第2層がまだ存在しない画面（要作成）

`SCENES.md`で体験版スコープ✅になっているのに、対応するPLANファイルが無い画面がある。「第2層は全部完了」ではないので注意。

| 画面 | 影響 |
|---|---|
| 冒険選択画面 | `DEMO_CHECKLIST.md`の「ストーリーステージ1〜10面が選択できる」を満たすのに必須。ステージクリア状況（`story.stages`）の更新関数がGameManagerに未定義 |
| パーティ選択画面 | 戦闘画面が`party_id`を受け取る前提になっているが、その`party_id`を作る画面が未設計 |
| トレーニングモード | 敵ダミー・DPS表示の仕様が未設計 |
| 設定画面 | `SCENES.md`・`DEMO_CHECKLIST.md`とも「詳細は別途設計」のまま |
| シナリオ画面 | 同上 |
| ポモドーロの記録画面・タイマー装飾・ストリーク | `PLAN_POMODORO_CORE_LOOP.md`のスコープ外。`DATA_SCHEMA.md` 2-4〜2-6にデータ構造はあるがPLANが無い |

**方針**：これらは着手するタイミングで第2層（PLAN）と第3層（EXEC）をまとめて書く。今は「無いことを認識している」状態を保てばよい。ただし共通基盤に関わるキー（`story` / `training_mode_unlocked`）だけは、後から名前がブレないよう`EXEC_COMMON_INFRA.md`の`GameStateKeys`に先行定義済み。

**⚠️ 戦闘画面について**：本番用の作戦計画書は`PLAN_BATTLE_SCREEN.md`で解消済み。マスターデータの読み込み方式（`MasterDataLoader`）・スキル効果の集約先（`SkillResolver`）・`battle_finished`の発火元・expの扱いも確定済み。残るのは各スキルタイプの具体的な計算式と`projectile`の当たり判定のみ。

### 参考資料（ユーザー提供・そのまま使うかは要判断）
| ファイル | 位置づけ |
|---|---|
| `godot_battle_plan_revised.md` | **プロトタイプ用**。戦闘ロジックの検証には使えるが、本番実装の第2層/第3層としてはそのまま使わない方針。`PLAN_BATTLE_SCREEN.md`と食い違う場合は必ずPLANを優先する（`DATA_SCHEMA.md` 3-1の参照先もPLANに変更済み） |
| `ステージウェーブ＆ボス拡張プラン.txt` | ウェーブ／ボス構成の設計思想は採用済み（DATA_SCHEMA.mdに反映済み）。実行指示書自体は未作成 |

### 第3層（実行指示書）── 着手済み・タスクごとに別ファイル

**共通基盤（`EXEC_COMMON_INFRA.md`）は実装完了・進行ゲート突破済み**（完了条件14項目クリア。レビューで指摘した4点も修正済み）。
| ファイル | 内容 | 状態 |
|---|---|---|
| `EXEC_COMMON_INFRA.md` | 共通基盤（5つのAutoload）の空実装指示書 | ✅ 完了（完了条件14項目。キー定数化・スナップショット化・Autoload登録順・IMPL_LOG生成を条件に追加済み） |
| `IMPL_LOG_TEMPLATE.md` | Zivaが実装完了ごとに生成する実装ログの型。全EXECタスク共通で使う | ✅ 完了 |
| `EXEC_UI_COMMON.md` | Theme・共通UIコンポーネント3つの実行指示書（完了条件13項目） | ✅ 完了 |
| 拠点画面（表示のみ）の実行指示書 | - | ⬜ 未着手（次） |
| `EXEC_TITLE_TO_BASE.md` | タイトル画面＋SaveManager実装＋拠点仮シーン（完了条件14項目） | ✅ 完了 |
| タイトル→拠点画面の実行指示書 | - | ⬜ 未着手 |
| ポモドーロ最小ループの実行指示書 | - | ⬜ 未着手 |
| 戦闘画面（本番用）の実行指示書 | - | ⬜ 未着手 |
| ギルド各箱（倉庫・ショップ・育成・研究・作業場）の実行指示書 | - | ⬜ 未着手（5ファイル） |

**方針**：第3層はタスクが増えるたびに1ファイルにまとめず、`EXEC_◯◯.md`のようにタスクごとに分ける（1ファイルへの追記式は途中でボリュームが大きくなりすぎるため不採用）。Zivaに渡す際は`AGENTS.md` + 該当`EXEC_◯◯.md` + `IMPL_LOG_TEMPLATE.md`の3点セットにする（`AGENTS.md`「開発ルール」参照）。

---

## 次の会話で「何を見せるか」早見表

| やりたいこと | 見せるファイル |
|---|---|
| 新しい会話を始める（状況共有） | このファイル（`PROJECT_STATUS.md`） |
| **共通基盤を実装させる**（実装済みの空実装をレビュー・拡張したい） | `AGENTS.md` + `EXEC_COMMON_INFRA.md` |
| UI共通パーツを実装させる | `AGENTS.md` + `PLAN_UI_COMMON.md` |
| 拠点画面の実行指示書を一緒に書く | `AGENTS.md` + `PLAN_BASE_SCREEN.md` |
| タイトル→拠点の実行指示書を一緒に書く | `AGENTS.md` + `PLAN_TITLE_TO_BASE.md` |
| ポモドーロの実行指示書を一緒に書く | `AGENTS.md` + `PLAN_POMODORO_CORE_LOOP.md` |
| 戦闘の実行指示書を一緒に書く | `AGENTS.md` + `PLAN_BATTLE_SCREEN.md` |
| ギルド各箱の実行指示書を一緒に書く | `AGENTS.md` + 該当する`PLAN_GUILD_◯◯.md` |
| 実装をAIにさせる（第3層をそのままZivaに渡す） | `AGENTS.md` + 該当する`EXEC_◯◯.md` + `IMPL_LOG_TEMPLATE.md`（他は不要） |
| Zivaの実装結果がPLAN通りか確認したい | 生成された`IMPL_LOG_◯◯.md`（特に「5. 指示書からの逸脱・迷った判断」欄）を見せてもらう |
| 進捗確認・次に何をやるか相談したい | `CHECKPOINTS.md` + `DEMO_CHECKLIST.md` |

**渡し方のコツ**：毎回全ファイルを渡さない。「今日やること」に関係するものだけに絞る方が、AIも人間も混乱しない。ただし「実行指示書を一緒に書く」系のタスクでは、PLANファイルに加えて**依存する既存Autoload／既存シーンの実コード**も見せること（詳細は「第3層を書くたびに守るルール」参照）。PLANの記述だけを根拠にすると、実装済みコードとのズレに気づけない。

---

## ⚠️ 進行ゲート（ここを飛ばして先に進まない）

**`EXEC_COMMON_INFRA.md`をZivaに渡して実装させ、完了条件（14項目）を実際に満たすか確認するまで、他の第3層（`EXEC_◯◯.md`）は書き始めない。**

理由：GameManagerが拠点データ〜作業場キューまで全ドメインをDictionaryベースで一括管理する設計になっており、他の全画面がこの上に乗る。ここでZivaの実装のクセ（命名の解釈違い・シグナル発火漏れ等）や設計上の無理（`GameStateKeys`定数化が徹底されない等）が見つかった場合、後から直すほど影響範囲が広がる。

- [ ] `EXEC_COMMON_INFRA.md`の完了条件14項目をすべて満たした
- [ ] `GameStateKeys` / `TransferKeys`経由でのアクセスが徹底されていることをコードレビューで確認した
- [ ] 上記で違和感（Dictionary運用のしんどさ、命名規則のブレ等）が出た場合、ここで設計を見直した（見直さずに次へ進まない）

これらが済んでから、`PLAN_UI_COMMON.md`以降のEXEC執筆に進む。

### 第3層を書くたびに守るルール（実コードとの突き合わせ）

PLANドキュメント（第2層）はあくまで「意図」の記録であり、Zivaが実際に実装したコードとは細部でズレうる（関数名・シグナル発火タイミング・`GameStateKeys`徹底具合など）。このズレに気づかないまま次のEXECをPLAN記述だけで書くと、存在しない関数を呼ぶ指示書や実態と違う前提の指示書をZivaに渡すことになる。

- 新しい`EXEC_◯◯.md`を書く前に、そのタスクが依存する既存Autoload／既存シーンの**実コード（.gd/.tscn）を見せてもらい**、PLANの記述と突き合わせる
- ズレがあれば、まずそのズレをPLAN側に反映してから、EXECの中身を実コードに合わせて書く
- 例：拠点画面（`EXEC_BASE_SCREEN.md`）を書く前に、`GameManager.gd` / `SceneManager.gd` / `SignalBus.gd`の実装済みコードを確認する

---

## 次にやることのおすすめ順序

第2層（作戦計画）はすべて完了している。ここからは第3層（実行指示書）をタスクごとに書き、Zivaに渡して実装 → 動作確認、を繰り返す段階。

1. ~~`PLAN_COMMON_INFRA.md`を渡して、5つのAutoloadを空実装で作る~~ → `EXEC_COMMON_INFRA.md`として完了。実際にZivaへ渡して実装させ、完了条件（14項目）を満たすか確認する
2. ~~`PLAN_UI_COMMON.md`を渡して、Theme・共通ボタン等の実行指示書を書く~~ → `EXEC_UI_COMMON.md`として完了。Zivaに渡して実装させる段階
3. 「タイトル→拠点画面（遷移だけ）」の実行指示書を`PLAN_TITLE_TO_BASE.md`から書いてから実装
4. 「拠点画面（表示のみ）」の実行指示書を`PLAN_BASE_SCREEN.md`から書いてから実装
5. 「ポモドーロ最小ループ」の実行指示書を`PLAN_POMODORO_CORE_LOOP.md`から書いてから実装
6. ここまでで`CHECKPOINTS.md`のMVPが完成 → 実際にビルドして遊んでみる
7. 以降、`CHECKPOINTS.md`のロードマップに沿って、戦闘（`PLAN_BATTLE_SCREEN.md`）・ギルド各箱（`PLAN_GUILD_◯◯.md`×5）の実行指示書を順に書いて拡張

**次の一手候補**：3〜5のどれからでも着手できる状態（依存関係の強い順は3→4→5）。または先に共通基盤の空実装を実際にZivaで動かして、完了条件がちゃんと満たせるか確認してから進むのも手。

---

## 横断的な未確定事項一覧（複数ファイルにまたがるもの）

同じ論点が複数のPLANファイルで別々に「未確定」と書かれると、片方だけ決めてもう片方が更新されずに矛盾する恐れがある。ここに集約し、各PLANファイル側は詳細を書かずこのセクションへのポインタのみ残す。

| 論点 | 影響先ファイル | 状態 |
|---|---|---|
| 「1日」の区切りの判定基準 | `PLAN_POMODORO_CORE_LOOP.md`、`PLAN_GUILD_SHOP.md`（リフレッシュ判定）、`DATA_SCHEMA.md` 2-4（ストリーク） | **決定済み：毎朝4:00**。`DATA_SCHEMA.md` 2-4に元から明記されていた基準に統一。判定は`scripts/utils/game_date.gd`（`class_name GameDate`）に切り出し、加護選択・ストリーク・ショップから共用する |
| マスターデータ（スキル・ウェーブ・敵ステータス）の読み込み方式・置き場所 | `PLAN_BATTLE_SCREEN.md` | 決定済み（10章。`MasterDataLoader` + `resources/balance/master/`） |
| スキルタイプごとの効果適用ロジック | `PLAN_BATTLE_SCREEN.md` | 決定済み（10-1章。`SkillResolver`に集約） |
| `projectile`スキルの当たり判定方式（弾速・命中タイミング） | `PLAN_BATTLE_SCREEN.md` | 未決定。骨格は決まっているため他タスクの後回しでよい |
| 戦闘報酬のexpの扱い | `PLAN_BATTLE_SCREEN.md`、`PLAN_GUILD_TRAINING.md`、`PLAN_COMMON_INFRA.md` | **決定済み：expは廃止**。レベル上げは専用素材消費型のみ。戦闘での成長は素材ドロップで表現する |
| `battle_finished`の発火元 | `PLAN_BATTLE_SCREEN.md`、`PLAN_COMMON_INFRA.md` | **決定済み：GameManager（`apply_battle_rewards`内）に一本化**。戦闘画面からは発火しない |
| UIパーツの置き場所 | `PLAN_UI_COMMON.md`、`AGENTS.md` | **決定済み：2画面以上で使うものだけ`scenes/ui/components/`へ。1画面専用はその画面のフォルダ**。迷ったら画面フォルダに置く |
| Themeの置き場所 | `PLAN_UI_COMMON.md`、`AGENTS.md` | **決定済み：`res://theme/main_theme.tres`**。Project Settingsでプロジェクト全体のデフォルトThemeに設定し、個別シーンで色を指定しない |
| ファイル名の命名規則 | 全ファイル | **決定済み：ファイル名はsnake_case、`class_name`とノード名はPascalCase**（`AGENTS.md`命名規則に明記） |
| UI共通パーツのスコープ | `PLAN_UI_COMMON.md`、`EXEC_UI_COMMON.md` | **決定済み**：今回はTheme + `primary_button` / `resource_display` / `dialog_base` の3つ。`cooldown_button`（戦闘）と`notification_label`（拠点）は、使う画面の実装時に一緒に設計する |
| 配色・フォント | `PLAN_UI_COMMON.md` | **決定済み**：トマト基調のダーク配色8色（2章）。フォントはNoto Sans JP（アセット確定後に差し替える前提） |
| ポモドーロのプリセット表現 | `PLAN_POMODORO_CORE_LOOP.md`、`PLAN_COMMON_INFRA.md` | **決定済み：`PomodoroPreset`Resourceの配列**として`PomodoroConfig`が保持（単一の`focus_duration_sec`では3プリセットを表現できないため） |
| 冒険選択・パーティ選択・設定・シナリオ画面の設計 | `SCENES.md`、`DEMO_CHECKLIST.md` | **未着手（第2層ごと無し）**。着手時にPLANとEXECをまとめて作成する |
| Steam Rich Presence（フレンド欄への状態表示） | `DATA_SCHEMA.md` 2-7、`PLAN_POMODORO_CORE_LOOP.md` 6-2、`GODOT_SETUP.md` 6章 | **仕様は決定済み・実装は後回し**。セットごとの任意タイトル＋経過/残り時間を表示。振り返り内容は絶対に含めない。`get_presence_status()`の口だけMVPで用意する |
| セーブファイルの保存先・形式 | `GODOT_SETUP.md` 6章、`PLAN_COMMON_INFRA.md`、`EXEC_TITLE_TO_BASE.md` | **決定済み：`user://saves/save_slot_0.json`、JSON形式**。`EXEC_TITLE_TO_BASE.md`で実装する。保存タイミング（オートセーブ）は未定 |
| セッションタイトルの文字数上限 | `PLAN_POMODORO_CORE_LOOP.md` | 未決定（20〜30文字程度を想定）。`Balance.pomodoro`に`@export`で持たせる |
| 新規開始時のGameManagerデフォルト値をどこに定義するか | `PLAN_TITLE_TO_BASE.md`、`PLAN_COMMON_INFRA.md` | 決定済み（`Balance.initial_state` / `InitialStateConfig`） |
| ショップのラインナップ再生成（抽選テーブル・重み付け） | `PLAN_GUILD_SHOP.md` | 未決定 |
| 研究ツリーのノード数・具体的な効果値 | `PLAN_GUILD_RESEARCH.md` | 未決定（数値投入は第3層以降） |
| スキルスロットの解放条件 | `PLAN_GUILD_TRAINING.md` | 未決定 |
| 装備中アイテムのインベントリ側での区別表示 | `PLAN_GUILD_TRAINING.md`、`PLAN_GUILD_WAREHOUSE.md` | 未決定 |
| ポモドーロ進行と連動した素材製作の仕組み | `PLAN_GUILD_WORKSHOP.md` | 今回スコープ外・後日 |

**運用ルール**：新しい未確定事項が見つかったら、まずこの表に追記する。個別PLANファイルの「未確定・要決定」欄には「→ 詳細はPROJECT_STATUS.md「横断的な未確定事項一覧」参照」とだけ書く。

---

## 更新履歴
- 初版作成：第1層完了、第2層（共通基盤・UI共通）完了時点のスナップショット
- 更新：第2層が全画面ぶん完了（タイトル→拠点・拠点表示・ポモドーロ最小ループ・戦闘・ギルド5画面）。`CLAUDE.md`を`AGENTS.md`にリネーム。第3層は`EXEC_◯◯.md`としてタスクごとに分割する方針に決定し、共通基盤（`EXEC_COMMON_INFRA.md`）が完了
- 更新：共通基盤の実装完了。進行ゲート突破（完了条件14項目クリア）。実コードレビューで4点を修正（シグナルの種別を定数化、`material_changed`シグナル新設、`add_to_inventory`のアイテム種別引数、ネストDictionaryの複製ルール）。`GameStateKeys`にネストのキーを追加し、`AGENTS.md`に状態構造の表を追記
- 追記：`EXEC_TITLE_TO_BASE.md`を作成。空実装のままだった`SaveManager`をここで実装する方針に決定（`has_save()`が常にfalseだと「つづきから」を永久に検証できないため）。あわせて`GameManager.load_state()`が存在しない欠落を発見し追加
- 追記：`EXEC_UI_COMMON.md`を作成。配色（トマト基調ダーク）とフォント（Noto Sans JP・差し替え前提）を確定
- 追記：UIパーツの置き場所ルール（2画面以上で使うものだけ`components/`へ）とThemeの置き場所（`res://theme/`）を確定し、`AGENTS.md`のフォルダ構造に`theme/`・`localization/`・`docs/`を明記
- 追記（Steam連携の先行検討）：ポモドーロ中の状態をフレンド欄に表示する仕様（Steam Rich Presence）を`DATA_SCHEMA.md` 2-7に定義。セットごとの任意タイトル＋経過/残り時間を表示し、振り返り内容は絶対に含めない方針を確定。あわせてセーブ保存先を`user://saves/`に確定（クラウドセーブ対応のため）。実装自体はApp ID取得後で、MVPでは`get_presence_status()`の口だけ用意する
- **改訂（整合性レビュー反映）**：全ドキュメントを横断チェックし、以下を修正
  - `EXEC_COMMON_INFRA.md`の重複ファイルを解消し、完了条件を14項目に統一（旧10/11項目版は破棄）
  - 「`GameManager`のみシーン化」という誤記を修正（シーン化必須なのは`Balance`のみ）
  - Autoloadの登録順（`Balance`を`GameManager`より先）を`AGENTS.md`・`GODOT_SETUP.md`・`EXEC`に明記
  - `battle_finished`の発火元をGameManagerに一本化し、`PLAN_BATTLE_SCREEN.md`側の矛盾を解消
  - 戦闘報酬から`exp`を削除（DATA_SCHEMA 4-3の素材消費型と矛盾していたため）
  - `GameStateKeys`に不足していたキー（`scenario_chapter` / `boss_unlocked` / `pity_counters` / `save_version` / `last_saved_at` / `story` / `training_mode_unlocked`）を追加
  - `get_state()`を`duplicate(true)`のスナップショット返却に変更（参照渡しで内部状態が書き換えられる穴を塞ぐ）
  - ファイル名の命名規則をsnake_caseに統一（`Title.tscn` → `title_screen.tscn`等）
  - 残存していた`CLAUDE.md`への参照を全て`AGENTS.md`に置換
  - Input Mapのキー衝突を解消（`pomodoro_pause_toggle`をPキーへ、`pause_menu_toggle`を`ui_cancel`に統合）
  - `PomodoroConfig`をプリセット配列（`PomodoroPreset`）構造に変更
  - 「1日の区切り＝毎朝4:00」を確定として反映（`DATA_SCHEMA.md` 2-4に元から明記されていた）
  - `DATA_SCHEMA.md` 3-1の参照先を`godot_battle_plan_revised.md`から`PLAN_BATTLE_SCREEN.md`へ変更
  - 第2層の進捗表記を「完了」から「一部完了」へ修正（冒険選択・パーティ選択・設定・シナリオ等のPLANが未作成であることを明記）
