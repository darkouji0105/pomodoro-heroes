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
- `res://docs/` 配下は設計ドキュメント専用。AIはここのファイルを勝手に書き換えないこと。**例外**：`PRE_PLAN_◯◯.md`と`IMPL_LOG_◯◯.md`の生成のみ許可し、`res://docs/03_log/`に置く。

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
| `SoundManager` | 効果音の再生（`play_se(sound_id)`）。音源と音量は持たず、`Balance.sound`（`SoundConfig`）から毎回引く。**IDは`SoundIds`の定数を渡す** |

AIはこの6つ以外のAutoloadを勝手に追加しない。追加が必要な場合は人間に提案してから登録すること。詳細は`GODOT_SETUP.md`参照。

### Autoloadの登録順（厳守）

Project SettingsのAutoloadタブでは、必ず以下の順に登録すること。

```
1. Balance
2. GameManager
3. SaveManager
4. SceneManager
5. SignalBus
6. SoundManager
```

理由：`GameManager`は`_ready()`で`Balance.initial_state`（`InitialStateConfig`）を参照して自身を初期化するため、`Balance`が先に初期化済みでなければならない。Godotは登録順に初期化するため、この順序を崩すとnull参照になる。**`SoundManager`も`_ready()`で`Balance.sound`を読むため、`Balance`より後（末尾）に置く。**

> `project.godot`では`SoundManager="*uid://..."`とUID形式で書かれている。**Godot 4.4以降の通常の書き方であり、他の5つがパス形式なのと混在していても正常。**

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
| `DAILY_SHOP` / `WEEKLY_SHOP` / `MONTHLY_SHOP` | `{refresh_at, line_up: [{slot_id, item_id, cost: {currency_type, amount}, stock_limit, purchased_count, payout_type, count, item_type}]}`。`refresh_at`は**ゲーム内日付の文字列**（`"2026-08-11"`）。`payout_type` / `count` / `item_type`は`shop.json`側のキーで、`GameStateKeys`ではなく`GameManager`の定数を使う |
| `CHARACTER_GROWTH` | `{character_id: {level, stats: {hp, atk, def, spd}, skills, equipment: {weapon, armor, accessory}}}` |
| `RESEARCH_TREE` | `{node_id: {unlocked, effect_type, effect_value, prerequisites}}` |
| `RECIPES_UNLOCKED` | `{recipe_id: bool}` |
| `CRAFTING_QUEUE` | `[{queue_id, recipe_id, recipe_type, started_at, duration_sec, status, output_item_id}]` |

報酬Dictionary（宝箱・ポモドーロ・戦闘で共通）：`{gold, gems, stamina, materials, inventory}`

画面ID（`UNLOCKED_SCREENS`のキー・画面遷移の識別子）も`GameStateKeys`に`SCREEN_GUILD`等として定義済み。文字列リテラルで書かないこと。

### GameManagerのシグナル

| シグナル | 用途 |
|---|---|
| `resource_changed(resource_type, new_value)` | gold / gems / stamina の変化。`resource_type`は`GameStateKeys.GOLD`等の定数 |
| `material_changed(material_id, new_amount)` | 素材の変化。素材は種類ごとに表示先が分かれるため専用シグナルにしている |
| `screen_unlocked(screen_id)` | 画面のアンロック |
| `inventory_changed(item_id)` | インベントリの変化 |
| `pending_chests_changed(pending_count)` | 未開封の宝箱件数の変化 |
| `character_growth_changed(character_id)` | 育成データの変化（レベル・ステータス・装備・スキル）。素材の増減は`material_changed`側で通知されるため含まない |
| `research_node_unlocked(node_id)` | 研究ノードの解放。実効レベル上限とステータス上昇は都度計算のため、この通知だけで全画面が追従できる |
| `shop_changed(shop_type)` | ショップのラインナップの変化（購入・リフレッシュの両方）。`shop_type`は`GameStateKeys.SHOP_TYPE_DAILY`等の定数。所持金・素材・アイテムの増減は`resource_changed` / `material_changed` / `inventory_changed`側で通知されるため含まない |

`SignalBus`の`pomodoro_session_completed` / `battle_finished`は、**GameManagerの`apply_*_rewards()`内からのみ発火する**。呼び出し元の画面から直接発火しないこと（二重発火防止）。

**`resource_changed`が`STAMINA`で発火するとき、第2引数は`current`の`int`単体であり`max`を含まない。** `max`が必要な場合は`get_state()`から読み直すこと。`ResourceDisplay.set_value_with_max(current, 0)`と書くと`10/0`と表示される。将来`max`を変更する機能が入る際は、GameManager側に`max`を含む通知を追加すること。

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
| `ui_base_` | 拠点画面 | `ui_base_save` |
| `ui_pomodoro_` | ポモドーロ画面 | `ui_pomodoro_focus` |
| `ui_battle_` | 戦闘画面 | `ui_battle_victory` |
| `ui_guild_` | ギルド各画面 | `ui_guild_shop_sold_out` |

**`screen_id`と対応するキーは綴りを揃える。** `ui_nav_` 系は `"ui_nav_" + screen_id` で機械的に引ける状態を保つこと（例：`screen_id = "adventure_select"` → `ui_nav_adventure_select`）。同様に素材名は `"ui_res_" + material_id` で引く。

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
- CSVを編集したら、FileSystemパネルで`ja.csv`を右クリック → 再インポート（またはGodot再起動）する。これをしないと反映されない
- 日本語にカンマ（`,`）を含める場合はセル全体を `"` で囲む
- キーの重複を作らない。同じ意味のテキストは既存キーを使い回す
- 英語列（`en`）は今回作らない。多言語対応が必要になった時点で列を追加する
- `ja.csv`に無いキーを`tr()`に渡すと、キー文字列がそのまま返る。**これは意図した挙動として許容する**（追記漏れが画面上ですぐ分かるため）。フォールバック処理を入れないこと

---

## 開発ルール

- エラーが出たらまずZivaのログを確認すること。
- 同じ箇所を3回以上直させた場合は実装を止めて設計（シーン構成・スクリプト分割）を見直す。
- 実験的な機能は「ダミー実装」と明示してから作り、本番ブランチにはマージしない。
- 検証用のコードは本番シーンに残さない。必要なら `res://tests/` 配下に隔離する。

### エラーを理由にルールを緩めない（厳守）

**型指定・命名規則・状態アクセスのルールを、エラー回避のために緩めてはならない。** 回避策を採る前に必ず人間に報告し、判断を仰ぐこと。

- 例：`class_name` が認識されないエラーが出ても、`@onready` の型指定を `Node` に落として `has_method()` / `call()` で逃げない。関数名のtypoが実行時まで分からなくなり、「文字列リテラルを排除する」というプロジェクトの方針が構造的に崩れる
- 上記のエラーは多くの場合 **Godotエディタの再起動で解消する**（`class_name` はエディタ起動時にスキャンされるため）
- 同様に、`GameStateKeys` を経由せず文字列リテラルを書く、`tr()` を外す、`SceneManager` を通さず `change_scene_to_file()` を直接呼ぶ、といった回避も禁止

### 完了条件は転記して検証する（厳守）

**完了条件は `EXEC_◯◯.md` から項目番号ごと、文言をそのまま転記する。** 自分で要約したり項目を作り直したりしない。

- 項目を作り直すと、検証しにくい項目が無意識に落ちる
- 転記した上で、1項目ずつ**実際に動かして**検証する。「ハンドラ実装を確認」「ロジック上確認」はコードレビューであって動作確認ではない。コードレビューで足りる項目は、完了条件側にそう書いてある
- 検証結果には「何をしたら何と表示されたか」を書く（例：「`spend_stamina(3)` を呼び、`7/10` と表示された」）

### ツールの制約（この環境固有）

- **`edit_file` は使用しない。** このプロジェクトでは動作しない。ファイルへの追記は `bash` の `cat >> "パス" << 'EOF'` を使う
- **`create_file` に長文を一度に渡さない。** トークン上限で失敗する。セクションごとに分割して追記する
- **誤字修正のための補助スクリプト（`.py` 等）を作らない。** 書き終わったら止めること。誤字は人間が直す
- `project.godot` の `[autoload]` は `update_project_setting` が受け付けないため、必要な場合のみ `bash` で直接編集する（登録済みのため通常は不要）

### 実装ログ（IMPL_LOG）

- **実行指示書（`EXEC_◯◯.md`）の実装が完了するたびに、`IMPL_LOG_TEMPLATE.md`（`res://docs/02_exec/`）の型に沿って`IMPL_LOG_◯◯.md`を`res://docs/03_log/`に生成すること。** Zivaはシステムプロンプトを持たずセッションをまたいで記憶を保持しないため、この実装ログが「実際に何がどう実装されたか」を後から検証するための唯一の記録になる
- 「5. 指示書からの逸脱・迷った判断」は空欄にしない。実装すれば必ず解釈の余地が生じる
- EXECファイルを渡す際は、`AGENTS.md` + 該当`EXEC_◯◯.md` + `PRE_PLAN_◯◯.md` + `IMPL_LOG_TEMPLATE.md` の4点セットで渡す

### 二段構え（計画 → 実装）

いきなり実装させず、先に `PRE_PLAN_◯◯.md` を書かせて人間が確認する。

```
【A】計画を書かせる → PRE_PLAN_◯◯.md
【B】人間が確認・修正指示
【C】PRE_PLANに「人間による決定事項」章を追記してから実装させる
【D】検証 + IMPL_LOG生成
```

- 【A】の段階では**コードを書かせない**
- 人間の決定事項は必ず `PRE_PLAN_◯◯.md` の末尾に章として書き込む。計画と実装で別のモデルを使う場合、会話が引き継がれないため、ファイルに書かないと決定が届かない
- その章は、PRE_PLAN本文と矛盾する場合に**優先される**ことを明記する

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
- 追記：Zivaはシステムプロンプトを持たないため、実装完了ごとに`IMPL_LOG_TEMPLATE.md`の型で実装ログを生成するルールを追加
- 追記：「翻訳キーの運用」を追加。翻訳表を`res://localization/ja.csv`に集約し、キーの命名規則（`ui_<領域>_<用途>`）と追加手順を明記。`.po`ではなくCSV方式に決定
- 追記（実コードレビュー反映）：「GameManagerの状態構造（ネストのキー）」「GameManagerのシグナル」の表を追加。ネストしたキーも`GameStateKeys`定数を使うルール、ネスト更新時の複製ルールを明記
- 追記：フォルダ構造に`theme/`・`localization/`・`docs/`を明記。UIパーツの置き場所ルールとThemeの扱いを追加
- 追記（整合性レビュー反映）：ファイル名はsnake_case・`class_name`とノード名はPascalCaseに統一するルールを明記。Autoloadの登録順を厳守事項として追加。`get_state()`は`duplicate(true)`のスナップショットを返すルール、`GameStateKeys` / `TransferKeys`経由でのキーアクセスルールを追加
- **追記（拠点画面の実装で判明した失敗モードへの対応）**：
  - 「エラーを理由にルールを緩めない」を追加（`class_name`認識エラーを`Node`型キャストで回避した事例。正しい対処はエディタ再起動）
  - 「完了条件は転記して検証する」を追加（完了条件20項目を15項目に作り直され、検証しにくい項目が落ちた事例）
  - 「ツールの制約」を追加（`edit_file`が動作しない、`create_file`のトークン上限、誤字修正スクリプトの自作を禁止）
  - 「二段構え（計画 → 実装）」を追加。人間の決定事項を`PRE_PLAN`末尾に書き込む運用を明文化（計画と実装でモデルを分けると会話が引き継がれないため）
  - `resource_changed(STAMINA)`が`max`を含まない仕様上の注意をシグナル表に追記
  - `screen_id`と`ui_nav_`キーの綴りを揃えるルール、`ja.csv`にキーが無い場合の挙動を許容する方針を翻訳の節に追記
  - `res://docs/`の書き換え例外に`PRE_PLAN_◯◯.md`を追加

- ファイルに追記する前に、追記しようとしている内容が
  既に存在しないか grep で確認する。
  「2回書かない」と決めても本人は1回のつもりなので、
  書く前の確認を手順に入れること

tr() は静的関数から呼べない。 静的クラスでは TranslationServer.translate() を使う。

画面を見て確認する種類の完了条件を、実装役に検証させない。 EXECの完了条件に「クリックして反応しないこと」「押すと表示が変わること」のような項目を書くときは、人間が検証する項目として最初から分ける。 実装役はヘッドレスでそれを再現しようとして、必ず時間を溶かす。

実例：モーダルの完了条件12項目のうち8項目が画面を見る種類だったが、分けずに渡したため、ヘッドレスでクリックを再現しようとして$0.66を消費し、実装が中断した。

### 完了条件は「どこを見るか」で3つに分ける（実測による制約）

完了条件には、確認する場所が違うものが混ざる。**書く側が最初から分けること。**

| 種類 | どこを見るか | 例 |
|---|---|---|
| **ログ** | Godotの出力パネル | 同期件数、関数の戻り値、失敗時の理由 |
| **ファイル** | `save_slot_0.json`等をテキストエディタで開く | 保存された値、型（`5`か`5.0`か） |
| **画面** | 実機で操作する | 表示内容・ボタンの活性・遷移・レイアウト |

**同じことを2箇所に書かない。** 画面で分かることをログの項目にも書くと、人間は同じ確認を2回やることになり、しかも2回目で「これはさっきやった」と気づいて章ごと飛ばす。

判定：**その項目が画面を操作すれば分かるなら、画面の章にだけ書く。** ログの章に残すのは、画面に出ない内部の値と、UIから到達できない経路（二重実行・不正なID・データ不整合）だけ。

実例：研究のEXECで、ログの章16項目のうち10項目が画面の章と重複していた。原因は、**実装役を使わない体制なのに、実装役がいた頃のA章／B章の型をそのまま流用したこと。** 「`print`で確認する」の主体がいなくなっているのに、関数を直接呼ぶ前提の文言が残っていた。

> 以前は「A章＝実装役が`print`で確認／B章＝人間が画面で確認」と分けていた。**担当者で分ける書き方は、実装役を使わないタスクでは機能しない。** 場所で分けること。

### `.tres`のネストしたResourceはInspectorで2階層になる

`Array[SomeResource]`型の`@export`に、配列の要素として**別の型のリソースを直接ドロップできない。**

実例：`SoundConfig.entries`（`Array[SoundEntry]`）に`.wav`をドラッグして
「選択されたリソース (AudioStreamWAV) は、このプロパティ (SoundEntry) が求める型に一致していません」で止まった。

**正しい手順**：要素の欄で「新規 `SoundEntry`」を作る → その中を開く → `Stream`欄に`.wav`を入れる。

**人間に`.tres`の作成を依頼するときは、この2階層を手順に書くこと。** 「配列に音源を入れる」と書くと必ず1階層目に入れようとする。

### 検証手順は、その出力が実在することを確かめてから書く

EXECに「ログで確認する」と書くなら、**その`print`が本当に存在するかコードを見てから書く。**

実例：育成のEXECで「再生してログで確認する」と書いたが、`_ready()`の`print`に`materials`が含まれておらず、通らない確認手順を指定していた。

### UIから到達できない項目を人間に確認させない

「解放済みのノードをもう一度解放しようとする」「存在しないIDを渡す」といった項目は、**画面から実行できない。** これらはコードを変えたときの保険であって、人間の確認項目ではない。

完了条件に書くなら「将来コードを変えたときに見る項目」として別枠にするか、書かない。


### 静的関数から tr() は呼べない

`tr()` は `Object` のインスタンスメソッドであり、静的クラス
（`Modal` / `MasterDataLoader` など）の静的関数からは呼べない。
パースエラーになる。`TranslationServer.translate(key)` を使う。

### 切り分けは2手まで

1つの症状に対して試す方法は2つまでとする。3つ目に進まず報告させる。

「同じ箇所を2回失敗したら止める」の別の側面。方法を変えると本人は
回数を数え直すため、症状の側からも上限を掛ける必要がある。

実例：モーダルの検証で1つの症状に6通りの手段を試し、
本番コードを切り分けのために書き換え、テストシーンを自動実行に
作り替えた結果、何が原因で何が直ったのか分からない状態になった。
実際の原因は環境ではなく `confirm()` の待ち方の設計ミスだった。

- 原因を「環境の問題」と結論づけさせない。観測した事実だけ報告させる
- 切り分けのために本番コードを書き換えさせない
- 検証のためにテストコードの仕様を変えさせない

- **追記（音の第1弾＝ポモドーロのアラームの完了時点）**：
  - Autoload一覧に`SoundManager`を追加し、「この5つ以外」を**6つ**に修正。登録順にも`6. SoundManager`を追加（`Balance.sound`を読むため末尾）
  - `project.godot`のAutoloadがUID形式で書かれることを注記（Godot 4.4以降）
  - **「`.tres`のネストしたResourceはInspectorで2階層になる」を追加**（`Array[SoundEntry]`に`.wav`を直接入れようとして型エラーになった事例）

- **追記（研究の完了時点）**：
  - 「GameManagerのシグナル」表に`character_growth_changed`と`research_node_unlocked`を追記（育成の時点で追記漏れがあった）
  - 完了条件の分け方を「担当者で分ける（A章／B章）」から**「どこを見るかで3つに分ける（ログ／ファイル／画面）」**へ変更。実装役を使わないタスクでは担当者による分割が機能しないため
  - 「同じことを2箇所に書かない」を明記。研究のEXECでログの章16項目中10項目が画面の章と重複していた
  - 「UIから到達できない項目を人間に確認させない」を追加
  - **マスターデータと状態を同期する型**を追加（下記）

### マスターデータと状態を同期する型

`research_tree`のように「マスターデータで定義し、進捗だけを状態に持つ」データは、
**起動時とロード時にマスターから流し込み直す。**

- 進捗フラグ（`unlocked`など）だけ既存の値を残す
- それ以外の定義（効果値・前提条件）は毎回マスターデータで上書きする

こうすると、JSONの数値を調整したときに**既存セーブにも次の起動で反映される。**
`initial_state_config.tres`はセーブが存在すると読まれないため、
同じ感覚で`.tres`に数値を置くと「直したのに変わらない」が起きる。

**代償**：マスターデータからIDが消えると、その進捗も消える。
**リリース後にIDを改名しないこと。**

実装例：`GameManager._sync_research_tree_from_master()`。
ショップ・作業場のレシピも同じ型で書く。

- **追記（ショップの完了時点）**：
  - 「GameManagerのシグナル」表に`shop_changed`を追記
  - 「GameManagerの状態構造」のショップ行を実装に合わせて更新（`payout_type` / `count` / `item_type`、`refresh_at`の型）
  - **1回の操作で複数のシグナルが飛ぶ画面の再描画**について下記を追加

### 再描画は await を持たせない（1操作で複数のシグナルが飛ぶ場合）

行をコードで生成する画面で、`queue_free()` + `await get_tree().process_frame`
という形で作り直すと、**1回の操作で2本以上のシグナルが飛ぶ場合に行が二重に並ぶ。**

`await`の間に2本目の再描画が削除を終えてしまい、1本目と2本目が
それぞれ行を追加するため。

対策：`remove_child()`してから`queue_free()`し、再描画関数に`await`を持たせない。
`remove_child()`はその場で効く。

実例：ショップの購入は`resource_changed`（所持金）と`shop_changed`（在庫）を
続けて発火する。倉庫画面と同じ書き方をすると商品が10行並ぶ。

> 倉庫画面（`_rebuild_inventory()`等）は`await`を持つ書き方のままだが、
> 発火するシグナルが1本ずつのため表面化していない。**触るときは注意すること。**
