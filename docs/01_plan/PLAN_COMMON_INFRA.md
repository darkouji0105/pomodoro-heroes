# 【作戦計画書】共通基盤（Autoload群）

第2層・作戦計画。個別シーンの実装より先にこれを完成させる。AGENTS.mdで定義した5つのAutoloadのインターフェースを決める。ここではUIやノード階層は扱わない。

---

## 1. GameManager

**責務**：拠点共通データ（DATA_SCHEMA.md「1. 拠点（共通データ）」）に加えて、育成・図鑑・ショップ・研究ツリー・製作キューなど、複数画面から参照される永続データ全般を保持・更新する。全画面のSingle Source of Truth。

> **注記（第2層の書き方について）**：以下は「GameManagerに何ができるか」を人が読んで理解できる形で書いたもの。カッコ内の名前は第3層（実行指示書）で実際の関数名として使う際の目安であり、正式な型定義やシグネチャはここでは決めない。

### できること（基本リソース）
- 現在の状態をまとめて取得する（`get_state`）。返すのは内部データそのものではなく、複製した読み取り専用のスナップショット（呼び出し側から直接書き換えられないようにするため）
- ゴールドを増やす（`add_gold`）
- スタミナを増やす（`add_stamina`）
- スタミナを消費する。足りなければ何もせず失敗を返す（`spend_stamina`）
- 素材を増やす（`add_material`）
- アイテムをインベントリに追加する（`add_to_inventory`）。アイテム種別（equipment / consumable / key_item / gift）は引数で明示的に渡す。省略時は「種別不明」として登録し、**呼び出し側の意図を勝手に推測しない**
- 素材の所持数を取得する（`get_material_count`）
- ジェムを増やす（`add_gems`）

### できること（画面アンロック）
- 画面をアンロックする（`unlock_screen`）
- 画面がアンロック済みか確認する（`is_screen_unlocked`）

### できること（宝箱）
- 未開封の宝箱を追加する（`add_pending_chest`）
- 宝箱を開封し、中身の報酬を反映する。存在しない宝箱なら何もせず失敗を返す（`open_chest`）
- 未開封の宝箱件数を取得する（`get_pending_chest_count`）

### できること（ポモドーロ報酬）
- ポモドーロセッションの報酬をまとめて反映する。所持金・スタミナ・素材の反映、完了回数の加算、最終プレイ日時の更新までを一度にまとめて行う（`apply_pomodoro_rewards`）

### できること（戦闘報酬）
- 戦闘の結果報酬（gold・素材）をまとめて反映する（`apply_battle_rewards`）。経験値（exp）は扱わない：レベル上げは専用素材消費型で、育成データにexpフィールドを持たないため（DATA_SCHEMA.md 4-3準拠）

### できること（倉庫：図鑑・インベントリ整理）
- 図鑑の1エントリの情報（発見済みか等）を取得する（`get_codex_entry`）
- インベントリ内アイテムの並び位置を更新する（`update_inventory_slot_position`）

### できること（セーブ／ロード連携）
- セーブデータから状態を復元する（`load_state`）。復元後、表示更新用に主要なシグナルを発火する。必須キー（`save_version`）が無ければ何もせず失敗を返す
- 保存直前に最終保存日時を更新する（`mark_saved`）
- ※ 図鑑の発見フラグは、アイテムを初めてインベントリに追加する処理（`add_to_inventory`）の中で自動的に更新される。呼び出し側で別途図鑑を更新する必要はない

### できること（ショップ）
- 指定したショップ種別（日替わり／週替わり／月替わり）の現在のラインナップを取得する（`get_shop_lineup`）
- ショップの商品を購入する。残高不足・売り切れなら何もせず失敗を返す（`purchase_shop_item`）
- 補充タイミングを過ぎていればラインナップを再生成する（`refresh_shop_if_needed`）

### できること（育成）
- 指定キャラクターの育成データ（レベル・ステータス・装備・スキル）を取得する（`get_character_growth`）
- キャラクターをレベルアップさせる。素材不足なら何もせず失敗を返す（`level_up_character`）
- 装備を着せる／外す（`equip_item` / `unequip_item`）
- スキルスロットにスキルを設定する（`select_skill`）

### できること（研究）
- 研究ツリー全体を取得する（`get_research_tree`）
- 研究ノードを解放する。前提ノード未解放・素材不足なら何もせず失敗を返す（`unlock_research_node`）
- 指定キャラクターの実効レベル上限を、解放済みノードから都度計算して返す。値そのものは保存しない（`get_effective_level_cap`）
- 全キャラ共通のステータス上昇量を、解放済みノードから都度計算して返す。値そのものは保存しない（`get_stat_boost_all`）

### できること（作業場）
- 現在の製作キューを取得する（`get_crafting_queue`）
- レシピの製作を開始する。レシピ未解放・素材不足なら何もせず失敗を返す（`start_craft`）
- 完成した製作物を受け取り、インベントリへ反映する。まだ完了していなければ何もせず失敗を返す（`collect_craft`）

### 通知（変化があったときに知らせるもの）
- リソース（gold・gems・stamina）が変化したことを知らせる（`resource_changed`）。種別は`GameStateKeys`の定数で渡す（文字列リテラル禁止）
- 素材が変化したことを、**どの素材がいくつになったか**の形で知らせる（`material_changed`）。素材は種類ごとに表示先が分かれるため、辞書全体を渡す`resource_changed`では差分更新できないため専用シグナルを分ける
- 画面がアンロックされたことを知らせる（`screen_unlocked`）
- インベントリの中身が変化したことを知らせる（`inventory_changed`）
- 未開封の宝箱件数が変化したことを知らせる（`pending_chests_changed`）
- ショップ・育成・研究・作業場については、今回は専用の通知は設けない。各画面側が操作の成功後にその場で取得し直す方式でシンプルに保つ（通知が必要になったら第3層検討時に追加する）

### 制約
- 他のAutoloadやシーンは、GameManagerが持つデータを直接書き換えない。必ず上記の「できること」経由で変更する。
- 状態が変わったら、対応する通知（シグナル）があるものは必ず発火する。
- 宝箱の中身を反映するときや、ポモドーロ・戦闘の報酬を反映するときは、ゴールド追加・素材追加といった基本操作を内部で使い回し、同じような更新処理をあちこちに重複して書かない。
- ポモドーロの報酬反映（`apply_pomodoro_rewards`）は、反映からセッション完了通知の発火までを一つの処理としてまとめて行う。呼び出し元（ポモドーロ画面側）で個別に通知を発火しない（二重発火防止のため、発火元はGameManagerに一本化する）。
- 戦闘の報酬反映（`apply_battle_rewards`）も同様に、反映から戦闘終了通知（`battle_finished`）の発火までを一つの処理としてまとめて行う。呼び出し元（戦闘画面側）で個別に通知を発火しない。
- 状態のキー名は文字列リテラルで散らさず、`GameStateKeys`（`scripts/utils/state_keys.gd`）の定数に集約する。**シグナルで渡す種別名（`resource_changed`の第1引数）も同じ定数を使う。**
- `_state`内のネストしたDictionary/Arrayを更新するときは、取り出したものを直接書き換えない。複製してから変更し、`_state`へ代入し直す（GDScriptのDictionary/Arrayは参照渡しのため、直接書き換えると代入前に内部状態が変わってしまう）。

---

## 2. Balance

**責務**：数値調整用Resourceの集約。AGENTS.mdの「数値管理ルール」を実現する本体。

### 公開プロパティ（Inspectorで.tresを割り当てる）
```gdscript
@export var pomodoro: PomodoroConfig
@export var shop: ShopConfig
@export var research: ResearchConfig
@export var workshop: WorkshopConfig
@export var character: CharacterConfig
@export var initial_state: InitialStateConfig
```

- `InitialStateConfig`：新規開始時（`SaveManager.has_save() == false`）のGameManager初期値（gold, stamina.max, unlocked_screensの初期状態等）。`GameManager`は`_ready()`でこの値を使って自身を初期化する。そのためAutoloadの登録順は`Balance`を`GameManager`より先にする（`AGENTS.md`「Autoloadの登録順」参照）

### 制約
- シーン（.tscn）として登録し、Autoload一覧にはそのシーンパスを指定する（スクリプト単体ではなくシーンにする理由：Inspectorで各Configを差し替えられるようにするため）。
- 各Configクラス（`PomodoroConfig`等）は`resources/balance/`配下に定義し、ロジックを持たない（純粋なデータ）。
- `PomodoroConfig`には以下も含める（DATA_SCHEMA.md 2-3「加護」に対応）：
  - 加護3種（light / middle / hard）ごとのしきい値・倍率（`threshold_min`, `bonus_multiplier`, `before_multiplier`, `after_multiplier`）
  - 集計した作業分数からgold / stamina / materialsへの換算レート（報酬計算式の数値部分）
  - **プリセット（`short` 15/3・`standard` 25/5・`long` 50/10）を`PomodoroPreset`という別Resourceの配列として保持する**。単一の`focus_duration_sec`では3プリセットを表現できないため。`PomodoroPreset`は`preset_id` / `focus_duration_sec` / `short_break_sec` / `long_break_sec` / `long_break_interval` / `default_total_sets`を持つ
  - ユーザーが設定できる範囲（セット数・長休憩の分数・長休憩の挿入間隔の最小／最大値）
  - これらもAGENTS.mdの数値管理ルールに従い、コード内にハードコードせず`@export`で保持する。

---

## 3. SaveManager

**責務**：GameManagerが持つ状態のファイル保存・読込。

### 公開関数
```gdscript
func save_game() -> bool   # 書き込み成功でtrue（呼び出し元が失敗を検知できるようboolに変更）
func load_game() -> bool   # セーブがあればtrueで読み込み、なければfalse
func has_save() -> bool
func delete_save() -> bool # テスト・デバッグ用
```

- 保存形式は**JSON**。`GameManager.get_state()`の返り値をそのまま`JSON.stringify()`する
- **JSONは整数をfloatとして復元する**ため、読み込み時に`int()`で明示変換すること
- セーブが壊れていた場合は、警告を出して`false`を返すのみ。**ゲームを止めない**（`DEMO_CHECKLIST.md`「時刻を極端に操作した場合、警告表示のみ行い進行は停止しない」と同じ方針）

### 保存先（決定済み）
- セーブは必ず `user://saves/` 配下に保存する。実行ファイルと同じ場所や、複数の場所に分散させない
- 理由：Steamクラウドセーブが「指定フォルダを丸ごと同期する」仕組みのため（`GODOT_SETUP.md` 6章）

### 未確定・要決定（後回しでOK）
- 保存タイミング（各セッション終了時／拠点画面遷移時／定期オートセーブ、のどれか）
- 保存ファイルの形式（JSON / Godotの`ResourceSaver`等）

---

## 4. SceneManager

**責務**：画面遷移の一元管理。

### できること
- 指定したシーンへ画面遷移する（`change_scene`）
- 1つ前の画面へ戻る（`go_back`）
- データを持たせてシーン遷移する（`change_scene_with_data`）
- 遷移時に渡されたデータを取り出す。取り出すと同時に内部のデータは空になる（`consume_transfer_data`）

### 制約
- 各シーンのスクリプトは`get_tree().change_scene_to_file()`を直接呼ばない。必ず`SceneManager.change_scene()`（または`change_scene_with_data()`）を経由する。
- 遷移履歴（`go_back()`用）をどこまで持つかは実装時に決める。
- **画面間のデータ受け渡し**：ページ（画面）ごとに専用の受け渡しクラス／フォルダは作らない。`SceneManager`が`transfer_data: Dictionary`を1つだけ保持する汎用の仕組みとし、どの画面から呼ばれても同じAPIで受け渡す。
  - `change_scene_with_data()`は内部で`transfer_data`をセットしてから`change_scene()`と同様の遷移を行う
  - 遷移先の`_ready()`で`consume_transfer_data()`を呼び、取り出すと同時に`transfer_data`を空にする（次の遷移に前回のデータが混ざらないようにするため）
  - Dictionaryのキー名はtypoに気づきにくいため、画面ごとに使うキー名は各作戦計画書側で明記し、可能であれば`scripts/utils/`配下に定数（例：`TransferKeys`）としてまとめる

---

## 5. SignalBus

**責務**：画面間通信のグローバルシグナル中継。循環参照を避けるため、画面同士は直接参照しない。

### 代表的なシグナル（実装が進むごとに追記していく）
```gdscript
signal pomodoro_session_completed(reward_data: Dictionary)
signal battle_finished(result_data: Dictionary)
signal facility_tapped(facility_id: String)
signal character_tapped(character_id: String)
```

### 制約
- 画面Aのスクリプトが画面Bのノードを直接参照・呼び出すことを禁止する。必ずSignalBus経由で通知し、Bが自分で処理する。

---

## 完了条件（このチェックポイントのゴール）

- [ ] 5つのAutoloadが空実装（関数シグネチャのみ）で作成されている
- [ ] Project SettingsのAutoloadタブに5つとも登録されている
- [ ] `GameManager.add_gold(100)` → `resource_changed`シグナルが発火することをprintで確認できる
- [ ] `GameManager.add_pending_chest()` / `open_chest()` → `pending_chests_changed`シグナルが正しい件数で発火することをprintで確認できる
- [ ] `GameManager.apply_pomodoro_rewards({...})` → gold/staminaが反映され、`total_pomodoro_completed`が+1、`SignalBus.pomodoro_session_completed`が発火することをprintで確認できる
- [ ] `GameManager.apply_battle_rewards({...})` → gold/materialsが反映され、`SignalBus.battle_finished`がGameManager内部から発火することをprintで確認できる
- [ ] `GameManager.purchase_shop_item()` / `level_up_character()` / `unlock_research_node()` / `start_craft()` / `collect_craft()` それぞれが、条件を満たさない場合は何もせず失敗を返すことを確認できる
- [ ] `Balance.pomodoro`が`.tres`を割り当てた状態でInspectorから開ける
- [ ] `SceneManager.change_scene()`でダミーシーン間の遷移ができる
- [ ] `SceneManager.change_scene_with_data()`で渡したDictionaryを、遷移先で`consume_transfer_data()`経由で取得でき、取得後は空になっていることを確認できる

この計画書がそのまま第3層（実行指示書）のベースになる。

---

## 更新履歴
- 初版：5つのAutoloadインターフェースを定義
- 追記：拠点画面（表示のみ）作戦計画書でのチェストバッジ実装に伴い、GameManagerに`pending_chests`関連の関数・シグナルを追加
- 追記：ポモドーロ最小ループ作戦計画書に伴い、GameManagerに`apply_pomodoro_rewards()`を追加。Balance（PomodoroConfig）に加護のしきい値・倍率と報酬換算レートを追加
- 追記：戦闘画面（本番用）作戦計画書に伴い、SceneManagerに画面間データ受け渡し用の`change_scene_with_data()` / `consume_transfer_data()`を追加（画面ごとの専用クラスは作らず、汎用Dictionary1つで統一する方針）
- 追記：`SaveManager`の保存形式をJSONに確定し、`save_game`の戻り値を`bool`に変更。`delete_save`を追加。GameManagerに`load_state` / `mark_saved`を追加（セーブから状態を復元する関数が存在しなかったため）
- 改訂（実コードレビュー反映）：`material_changed`シグナルを追加（`resource_changed`で素材辞書ごと渡していたため、どの素材が変わったか特定できなかった）。`add_to_inventory`にアイテム種別の引数を追加（種別を勝手に`equipment`と推測していたため）。`add_gems` / `get_material_count`を追加。ネストしたDictionary更新時の複製ルールを明記
- 改訂（整合性レビュー反映）：`battle_finished`の発火元をGameManagerに一本化（従来はPLAN_BATTLE_SCREEN側で戦闘画面が発火する記述と矛盾していた）。`apply_battle_rewards`から`exp`を削除（DATA_SCHEMA 4-3の素材消費型と矛盾していたため）。`Balance`に`initial_state`（`InitialStateConfig`）を追加。`PomodoroConfig`にプリセット配列（`PomodoroPreset`）を追加。`get_state()`をスナップショット返却に変更
- 改訂：ギルド各箱（倉庫・ショップ・育成・研究・作業場）の作戦計画書に伴い、GameManagerの責務を「拠点共通データ」から「全画面が参照する永続データ全般」に拡張。図鑑・ショップ・育成・研究ツリー・製作キューをGameManagerに集約し、関連機能を追加。あわせて、GameManagerの「できること」一覧を関数シグネチャ形式から人が読める説明形式に書き換え（第2層は人が読める記法、コード形式への変換は第3層で行う方針に統一）
