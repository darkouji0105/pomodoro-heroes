# AGENTS.md - プロジェクトルール

このファイルはAIエージェント（Ziva等）がコードを書く前に必ず読むこと。ここに書かれていないやり方は勝手に採用しない。

第3層（実行指示書）はタスクごとに別ファイルにする。このファイルには常に守るプロジェクト共通ルールのみを置く。

---

## 使用技術
- 使用言語: GDScript（C#は使わない）
- エンジン: Godot 4.x
- Ziva: Godotエディタに組み込むAIコーディングエージェント（ChatGPT/Claude/Gemini対応）。バージョン確定次第ここに記載

---

## フォルダ構造（固定・AIは変更禁止）

```
res://
├── assets/               # 未加工アセット
│   ├── images/
│   ├── sounds/
│   └── fonts/
├── scenes/               # すべてのシーン(.tscn)
│   ├── ui/
│   │   └── components/   # 2画面以上で使い回すUIパーツのみ（下記ルール参照）
│   ├── title/
│   ├── base/             # 拠点
│   ├── guild/            # 倉庫・ショップ・育成・作業場・研究
│   ├── adventure/        # 冒険選択・戦闘
│   └── pomodoro/
├── scripts/
│   ├── components/       # 再利用可能なカスタムノード
│   ├── systems/          # ゲームロジック（マネージャー類）
│   └── utils/            # 汎用ヘルパー
├── autoload/              # シングルトン（GameManager, Balance等）
├── theme/                 # main_theme.tres（配色・フォント・ボタン等の基本スタイル）
├── localization/          # ja.csv（翻訳表）。詳細は「翻訳キーの運用」参照
├── resources/
│   └── balance/           # 数値調整用 .tres ファイル置き場（下記ルール参照）
│       └── master/        # スキル・ウェーブ・敵ステータス等のマスターデータ（IDで引く量産型データ）。Balanceの@exportではなくMasterDataLoaderが読み込む（PLAN_BATTLE_SCREEN.md参照）
├── addons/                # プラグイン（Ziva等）※手動インストール、AIは触らない
├── docs/                  # 設計ドキュメント（AIは指示されたもの以外読まない・編集しない）
└── tests/                 # 実験用シーンの隔離場所
```

- 新しいフォルダが必要になったら、AIは必ず人間に提案し、承認を得てから作成すること。
- `res://addons/` と `res://autoload/` の既存ファイルには無断で触れないこと。
- `res://docs/` 配下は設計ドキュメント専用。AIはここのファイルを勝手に書き換えないこと。**例外**：`IMPL_LOG_◯◯.md`の生成のみ許可し、`res://docs/03_log/`に置く。

### UIパーツの置き場所ルール（重要）

`scenes/ui/components/` に置くのは、**2つ以上の画面で使い回すパーツだけ**。

| 使う画面の数 | 置き場所 |
|---|---|
| 2画面以上 | `scenes/ui/components/` |
| 1画面だけ | その画面のフォルダ（例：`scenes/pomodoro/`） |

- 例：`primary_button.tscn`（全画面で使う）→ `scenes/ui/components/`
- 例：`timer_display.tscn`（ポモドーロでしか使わない）→ `scenes/pomodoro/`
- **迷ったら画面フォルダに置く。** 後から他画面でも使うことになった時点で`components/`へ移せばよい。逆（共通に置いたが実は1画面でしか使わない）のほうが整理しにくくなるため
- この基準を守らないと`components/`が「なんとなくUIっぽいもの置き場」になり、共通パーツを探せなくなる

### Themeの扱い

- 配色・フォント・ボタン等の基本スタイルは `res://theme/main_theme.tres` に一元化し、プロジェクト全体のデフォルトThemeとして設定する
- **個別シーンで色やフォントを直接指定しない。** Theme1箇所を差し替えれば全画面に反映される状態を常に保つ（`PLAN_UI_COMMON.md`参照）

---

## 数値管理ルール（重要・厳守）

- ゲームバランスに関わる数値（時間、倍率、コスト、しきい値、必要素材数など）は**絶対にスクリプト内にハードコードしない**。
- 必ず専用の `Resource` クラス（例: `class_name PomodoroConfig extends Resource`）に `@export` 変数として定義し、`.tres` ファイルとして `res://resources/balance/` 配下に保存する。
- 全ての設定Resourceは、Autoload「Balance」（シーンとして登録し、ルートノードに集約スクリプトを付与）経由で `Balance.pomodoro.focus_duration_sec` のようにアクセスする。
- 理由：Godot Inspectorから数値をポチポチ調整できるようにするため。コードを触らずにバランス調整できる状態を常に保つ。

---

## Autoload（シングルトン）一覧

| Autoload名 | 責務 |
|---|---|
| `GameManager` | 拠点共通データ＋育成・図鑑・ショップ・研究ツリー・製作キューなど、複数画面から参照される永続データ全般の保持・更新。全画面のSingle Source of Truth |
| `Balance` | 数値調整用Resource（PomodoroConfig, ShopConfig, ResearchConfig等）を集約。シーンとして登録し、Inspectorから`.tres`を割り当てる |
| `SaveManager` | セーブ／ロード処理 |
| `SceneManager` | 画面遷移の一元管理。各所で直接`change_scene_to_file()`を呼ばない。画面間のデータ受け渡しも一元管理する |
| `SignalBus` | 画面間通信用のグローバルシグナル中継。循環参照回避のため、画面同士は直接参照しない |

AIはこの5つ以外のAutoloadを勝手に追加しない。追加が必要な場合は人間に提案してから登録すること。詳細は`GODOT_SETUP.md`参照。

### Autoloadの登録順（厳守）

Project SettingsのAutoloadタブでは、必ず以下の順に登録すること。

```
1. Balance
2. GameManager
3. SaveManager
4. SceneManager
5. SignalBus
```

理由：`GameManager`は`_ready()`で`Balance.initial_state`（`InitialStateConfig`）を参照して自身を初期化するため、`Balance`が先に初期化済みでなければならない。Godotは登録順に初期化するため、この順序を崩すとnull参照になる。

### 状態アクセスのルール

- `GameManager.get_state()`は、内部Dictionaryそのものではなく`duplicate(true)`した**読み取り専用スナップショット**を返す。GDScriptのDictionaryは参照渡しのため、そのまま返すと呼び出し側から内部状態を直接書き換えられてしまい、「必ず関数経由」というルールが構造的に守れなくなるため。
- 状態を変更したい場合は、必ず`add_gold()`等の専用関数を経由すること。
- `get_state()`が返すDictionaryのキーは、文字列リテラルではなく`GameStateKeys`（`res://scripts/utils/state_keys.gd`）の定数経由で組み立て・参照すること。**トップレベルだけでなくネストしたキーも同様**。画面間で使うキーも`TransferKeys`（`res://scripts/utils/transfer_keys.gd`）に集約する。
- `_state`内のネストしたDictionary/Arrayを更新するときは、取り出したものを直接書き換えない。複製してから変更し、`_state`へ代入し直す（GDScriptのDictionary/Arrayは参照渡しのため）。

### GameManagerの状態構造（ネストのキー）

Dictionaryは存在しないキーを読んでもエラーにならず`null`を返すため、キー名を推測して書くと**実行するまで誤りに気づけない**。以下の構造を推測で補わず、必ず`GameStateKeys`の定数を使うこと。定義は`res://scripts/utils/state_keys.gd`にすべて揃っている。

| トップレベル | 中身 |
|---|---|
| `GOLD` / `GEMS` | `int` |
| `STAMINA` | `{current: int, max: int}` |
| `MATERIALS` | `{material_id: int}` |
| `INVENTORY` | `{item_id: {count, type, slot_position: {x, y}, properties}}` |
| `PENDING_CHESTS` | `[{chest_id, chest_type, source, obtained_at, opened, rewards}]` |
| `UNLOCKED_SCREENS` | `{screen_id: bool}` |
| `STORY` | `{current_chapter: int, stages: {stage_id: {cleared, stars}}}` |
| `CODEX` | `{item_id: {discovered, obtained_at}}` |
| `DAILY_SHOP` / `WEEKLY_SHOP` / `MONTHLY_SHOP` | `{refresh_at, line_up: [{slot_id, item_id, cost: {currency_type, amount}, stock_limit, purchased_count}]}` |
| `CHARACTER_GROWTH` | `{character_id: {level, stats: {hp, atk, def, spd}, skills, equipment: {weapon, armor, accessory}}}` |
| `RESEARCH_TREE` | `{node_id: {unlocked, effect_type, effect_value, prerequisites}}` |
| `RECIPES_UNLOCKED` | `{recipe_id: bool}` |
| `CRAFTING_QUEUE` | `[{queue_id, recipe_id, recipe_type, started_at, duration_sec, status, output_item_id}]` |

報酬Dictionary（宝箱・ポモドーロ・戦闘で共通）：`{gold, gems, stamina, materials, inventory}`

### GameManagerのシグナル

| シグナル | 用途 |
|---|---|
| `resource_changed(resource_type, new_value)` | gold / gems / stamina の変化。`resource_type`は`GameStateKeys.GOLD`等の定数 |
| `material_changed(material_id, new_amount)` | 素材の変化。素材は種類ごとに表示先が分かれるため専用シグナルにしている |
| `screen_unlocked(screen_id)` | 画面のアンロック |
| `inventory_changed(item_id)` | インベントリの変化 |
| `pending_chests_changed(pending_count)` | 未開封の宝箱件数の変化 |

`SignalBus`の`pomodoro_session_completed` / `battle_finished`は、**GameManagerの`apply_*_rewards()`内からのみ発火する**。呼び出し元の画面から直接発火しないこと（二重発火防止）。

---

## 命名規則

- 変数: snake_case
- 関数: snake_case
- 定数: SCREAMING_SNAKE_CASE
- シグナル: past_tense（例: `enemy_destroyed`）
- **ファイル名（`.gd` / `.tscn` / `.tres`）: すべて snake_case**（例: `title_screen.tscn`, `game_manager.gd`, `pomodoro_config.tres`）
- **`class_name`: PascalCase**（例: `class_name PomodoroConfig`）
- ノード名（シーンツリー内）: PascalCase（例: `GoldLabel`, `NavigationButtons`）
- 全てのテキストは `tr()` で囲む（日本語ハードコード禁止）。詳細は下記「翻訳キーの運用」参照

> **注意**：ファイル名は snake_case、`class_name`とノード名は PascalCase。この2つを混同しないこと。過去のドキュメントに`Title.tscn`のようなPascalCaseのファイル名表記が残っていた場合は、snake_case（`title_screen.tscn`）が正。

### 翻訳キーの運用（厳守）

表示テキストは日本語を直接書かず、翻訳キーを `tr()` に渡す。翻訳表は `res://localization/ja.csv` に集約する。

**キーの命名規則**：`ui_<領域>_<用途>` の形。すべて snake_case。

| 接頭辞 | 用途 | 例 |
|---|---|---|
| `ui_common_` | 全画面で使う汎用語 | `ui_common_ok`, `ui_common_close` |
| `ui_res_` | リソース名 | `ui_res_gold`, `ui_res_stamina` |
| `ui_nav_` | 画面遷移ボタン | `ui_nav_guild`, `ui_nav_pomodoro` |
| `ui_title_` | タイトル画面 | `ui_title_start_new` |
| `ui_base_` | 拠点画面 | `ui_base_placeholder` |
| `ui_pomodoro_` | ポモドーロ画面 | `ui_pomodoro_focus` |
| `ui_battle_` | 戦闘画面 | `ui_battle_victory` |
| `ui_guild_` | ギルド各画面 | `ui_guild_shop_sold_out` |

**新しいテキストを追加するときの手順**：

1. `res://localization/ja.csv` に `キー名,日本語` の行を追記する
2. コード側では `tr("キー名")` を使う（`PrimaryButton` なら `label_key` に入れる）
3. **1と2を必ずセットで行う。** キーだけ使って翻訳表に追記しないと、画面にキー名（`ui_xxx`）がそのまま表示される

**`tr()` を使わないもの**：

- 数値のみの表示（`"100"`、`"3/10"` 等）
- `print()` のデバッグログ（開発者向けであり画面に出ないため）
- `push_warning` / `push_error` のメッセージ

**編集時の注意**：

- `ja.csv` は **UTF-8（BOMなし）** で保存する。BOM付きだと1行目のキーが `\ufeffkeys` になり全滅する
- 日本語にカンマ（`,`）を含める場合はセル全体を `"` で囲む
- キーの重複を作らない。同じ意味のテキストは既存キーを使い回す
- 英語列（`en`）は今回作らない。多言語対応が必要になった時点で列を追加する

---

## 開発ルール

- エラーが出たらまずZivaのログを確認すること。
- 同じ箇所を3回以上直させた場合は実装を止めて設計（シーン構成・スクリプト分割）を見直す。
- 実験的な機能は「ダミー実装」と明示してから作り、本番ブランチにはマージしない。
- **実行指示書（`EXEC_◯◯.md`）の実装が完了するたびに、`IMPL_LOG_TEMPLATE.md`の型に沿って`IMPL_LOG_◯◯.md`を生成すること。** Zivaはシステムプロンプトを持たずセッションをまたいで記憶を保持しないため、この実装ログが「実際に何がどう実装されたか」を後から検証するための唯一の記録になる。EXECファイルを渡す際は、必ず`AGENTS.md` + 該当`EXEC_◯◯.md` + `IMPL_LOG_TEMPLATE.md`の3点セットで渡すこと。

---

## 拒否仕様（体験版スコープ外・実装しない）

- イベント交換所
- DLCショップ
- ダンジョン
- 戦闘プレビュー画面
- ボス画面
- タイマー装飾のマルチプレイ共有

---

## 更新履歴
- 初版作成：フォルダ構造・命名規則・数値管理ルール・拒否仕様を統合（旧`CLAUDE.md`）
- リネーム：Zivaが実際に読み込む規約ファイル名（AGENTS.md）に合わせ、`CLAUDE.md`から`AGENTS.md`へ改名
- 第3層はタスクごとに別ファイルにする方針に変更したため、実行指示書の内容はこのファイルから分離
- 追記：`resources/balance/master/`（スキル・ウェーブ・敵ステータス等のマスターデータ置き場）をフォルダ構造に追加。`PLAN_BATTLE_SCREEN.md`の10章決定に対応
- 追記：Zivaはシステムプロンプトを持たないため、実装完了ごとに`IMPL_LOG_TEMPLATE.md`の型で実装ログを生成するルールを追加。EXECファイルは今後`AGENTS.md` + `EXEC_◯◯.md` + `IMPL_LOG_TEMPLATE.md`の3点セットで渡す
- 追記：「翻訳キーの運用」を追加。翻訳表を`res://localization/ja.csv`に集約し、キーの命名規則（`ui_<領域>_<用途>`）と追加手順を明記。`.po`ではなくCSV方式に決定
- 追記（実コードレビュー反映）：「GameManagerの状態構造（ネストのキー）」「GameManagerのシグナル」の表を追加。ネストしたキーも`GameStateKeys`定数を使うルール、ネスト更新時の複製ルールを明記
- 追記：フォルダ構造に`theme/`（main_theme.tres置き場）・`localization/`・`docs/`を明記。UIパーツの置き場所ルール（2画面以上で使うものだけ`scenes/ui/components/`へ）とThemeの扱いを追加
- 追記（整合性レビュー反映）：ファイル名はsnake_case・`class_name`とノード名はPascalCaseに統一するルールを明記。Autoloadの登録順（`Balance`を`GameManager`より先）を厳守事項として追加。`get_state()`は`duplicate(true)`のスナップショットを返すルール、`GameStateKeys` / `TransferKeys`経由でのキーアクセスルールを追加
