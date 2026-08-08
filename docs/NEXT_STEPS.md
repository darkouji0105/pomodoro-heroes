# 次にやること：共通基盤の実装（手順書）

このファイルは「今日、実際に何をどの順でやるか」の作業手順書です。上から順にやれば終わります。

---

## はじめに：いま何をしようとしているのか

設計図（ドキュメント）は全部そろいました。ここからは**作る**段階です。

ただし、いきなり画面を作りません。最初に作るのは「**5つの土台**」です。

| 名前 | 役割をひとことで |
|---|---|
| `GameManager` | 所持金やアイテムなど、**全部のデータを持っている人** |
| `Balance` | 「作業時間は25分」などの**数値だけをまとめた設定ファイル置き場** |
| `SaveManager` | **セーブとロード**の担当 |
| `SceneManager` | **画面の切り替え**の担当 |
| `SignalBus` | 画面同士の**連絡係** |

拠点画面もポモドーロ画面も戦闘画面も、全部この5つの上に乗ります。だからここを最初に作ります。

### 「空実装」って何？

今回作るのは**中身が空っぽの5つ**です。

```gdscript
func add_gold(amount: int) -> void:
    print("add_gold が呼ばれた：", amount)   # ← これだけ
```

「ゴールドを増やす」という**名前と形だけ**を先に決めて、実際の処理はまだ書きません。

なぜかというと、先に形を決めておけば、後から画面を作るときに「`GameManager.add_gold()` を呼べばいい」と分かるからです。中身は後から埋められます。家でいう骨組みだけ先に建てるイメージです。

### 今日のゴール

`EXEC_COMMON_INFRA.md` の**完了条件14項目**を実際に満たすこと。

### 時間の目安

| ステップ | 内容 | 目安 |
|---|---|---|
| 0〜3 | 準備（フォルダ整理・Godot設定） | 40分 |
| 4 | Zivaに実装させる | 1〜2時間 |
| 5〜6 | 動作確認とレビュー | 40分 |

---

## ステップ0：ドキュメントを整理する（15分）

### 0-1. 古いファイルを消す

まず、混乱のもとになるファイルを消します。

- [ ] **`CLAUDE.md` を削除**
  → `AGENTS.md` に統合済みです。残しておくとZivaが古いルールを読んでしまいます。

- [ ] **古い `EXEC_COMMON_INFRA.md` を削除**
  → 完了条件が「10.」で終わっているほうが古い版です。新しいほうは「14.」まであります。開いて末尾を見れば区別できます。

### 0-2. 新しいファイルに差し替える

- [ ] ダウンロードしたファイルで、手元のドキュメントを上書きする

### 0-3. Godotプロジェクトの中に置く

**ここが重要です。** ドキュメントはGodotプロジェクトの**中**に置いてください。

> **なぜ？**
> Zivaは「Godotプロジェクトの中にあるファイル」しか読めません。デスクトップやDropboxに置いてあると、Zivaから見えないので参照できません。

こういう構成にします。

```
（プロジェクトフォルダ）
├── project.godot          ← これがあるのがプロジェクトのルート
├── AGENTS.md              ← ここだけルート直下に置く
└── docs/                  ← ほかは全部この中へ
    ├── PROJECT_STATUS.md
    ├── NEXT_STEPS.md      ← このファイル
    ├── 00_concept/
    │   ├── CONCEPT.md
    │   ├── SCENES.md
    │   ├── DATA_SCHEMA.md
    │   ├── GODOT_SETUP.md
    │   └── DEMO_CHECKLIST.md
    ├── 01_plan/
    │   └── PLAN_*.md（11ファイル）
    ├── 02_exec/
    │   ├── EXEC_COMMON_INFRA.md
    │   └── IMPL_LOG_TEMPLATE.md
    └── 03_log/
        └──（空。あとでZivaがログを生成する）
```

**`AGENTS.md` だけルート直下に残す**のがポイントです。この手の規約ファイルは、AIツールがルートを見に行く決まりになっていることが多いためです。

- [ ] 上の構成のとおりにフォルダを作り、ファイルを配置した

> **移動はGodotのFileSystemパネルの中でドラッグしてください。**
> エクスプローラー（Finder）で直接動かすと、Godotが管理している情報とズレることがあります。`.md`ファイルは比較的安全ですが、癖として揃えておくと事故が減ります。

---

## ステップ1：Godotのプロジェクト設定（10分）

Godotエディタの上のメニューから **Project → Project Settings** を開きます。

### 1-1. 画面サイズの設定

左のリストから **Display → Window** を選びます。

| 設定する項目 | 値 |
|---|---|
| Viewport Width | `1280` |
| Viewport Height | `720` |
| Stretch → Mode | `canvas_items` |
| Stretch → Aspect | `expand` |

> **これは何をしている？**
> 「基準となる画面サイズは1280×720。でもウィンドウを大きくしたら中身も一緒に伸びてね」という設定です。
> `canvas_items` にしておくと、文字がぼやけずにきれいに拡大されます。

- [ ] 4つとも設定した

### 1-2. キー設定（Input Map）

上のタブから **Input Map** を選びます。

- [ ] 一番上の入力欄に `pomodoro_pause_toggle` と入力して **Add** を押す
- [ ] 追加された行の右にある **＋** を押す
- [ ] 「Physical Key」を選び、キーボードの **P** を押して **OK**

> **なぜPキー？**
> 最初はスペースキーの予定でしたが、スペースはGodot標準の「決定」キーと重なります。ボタンにフォーカスが当たっているときにスペースを押すと、一時停止とボタン押下が同時に起きてしまうため、Pに変えました。

ほかのキーは追加不要です。`ui_accept`（Enter）と `ui_cancel`（Escape）は最初から入っています。

### 1-3. まだ設定しないもの

- **Main Scene**（Application → Run）は**まだ空のまま**にしてください。
  タイトル画面をまだ作っていないので、指定するものがありません。ステップ4のあとで設定します。

---

## ステップ2：フォルダを作る（10分）

Godotの左下にある **FileSystem** パネルで、`res://` を右クリック → **New Folder**。

以下を**空のまま**作ります。

```
res://
├── assets/
│   ├── images/
│   ├── sounds/
│   └── fonts/
├── scenes/
│   ├── ui/components/
│   ├── title/
│   ├── base/
│   ├── guild/
│   ├── adventure/
│   └── pomodoro/
├── scripts/
│   ├── components/
│   ├── systems/
│   └── utils/
├── autoload/
├── theme/
├── resources/balance/master/
├── localization/
└── tests/
```

> **`scenes/ui/components/` について**
> ここに入れるのは「2つ以上の画面で使うパーツ」だけです。
> ポモドーロでしか使わないパーツは `scenes/pomodoro/` に置きます。
> 迷ったら画面のフォルダに置いてください。あとで他でも使うことになったら、そのとき移せばいいだけです。

> **なぜ先に作る？**
> `AGENTS.md` に「新しいフォルダが必要なら人間に確認してから作る」というルールを書いています。フォルダが無いとZivaがそこで止まってしまうので、先に用意しておきます。

- [ ] 全部作った

> Gitを使っている場合は、空フォルダが記録されないので、各フォルダに `.gitkeep` という空ファイルを置いてください。使っていないなら気にしなくて大丈夫です。

---

## ステップ3：Zivaに渡す準備（5分）

### 渡すファイルは3つだけ

1. `AGENTS.md`
2. `EXEC_COMMON_INFRA.md`
3. `IMPL_LOG_TEMPLATE.md`

> **なぜ3つだけ？**
> 必要な情報はこの3つに全部入っています。
> PLANファイルやDATA_SCHEMA.mdを一緒に渡すと、Zivaが「じゃあ戦闘画面も作っておこう」と、頼んでいないことまで実装し始めることがあります。渡す情報を絞るほど、期待どおりのものが出てきます。

### 二段構えでやる（重要）

**いきなり実装させません。** 先に「これからこうやります」を書かせて、確認してから実装させます。

> **なぜ？**
> いきなり実装させると、AIが誤解したまま30ファイル作ってしまい、直すのが大変になります。
> 先に手順を言わせれば、そこで「Autoloadの順番が違う」と1行で指摘できます。
> **間違いは、コードになる前に見つけるほど安い**です。

```
【A】計画を書かせる → PRE_PLAN_COMMON_INFRA.md が出てくる
        ↓
【B】自分で確認する（4箇所だけ見る。5分）
        ↓
【C】OKを出して実装させる
        ↓
【D】検証 + IMPL_LOG生成
```

---

### 【A】まず計画を書かせる（コピペ用）

```
添付の3ファイルを読んでください。

1. AGENTS.md：プロジェクト共通ルール。ここに書かれていないやり方は
   採用しないでください。
2. EXEC_COMMON_INFRA.md：今回の実装指示書。
3. IMPL_LOG_TEMPLATE.md：実装完了後に生成するログの型。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【重要】このメッセージではコードを書かないでください。
実装計画だけを立ててください。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

res://docs/03_log/PRE_PLAN_COMMON_INFRA.md というファイルを作り、
以下の内容を書いてください。

## 1. 作成するファイル一覧
| パス | 役割 |
（実際に作る予定のファイルを全部。パスはsnake_caseで）

## 2. Autoloadの登録
| 登録順 | 登録名 | パス | スクリプト or シーン |

## 3. GameStateKeys に定義する定数一覧
| 定数名 | 値 |
（EXEC_COMMON_INFRA.md の表に対応するもの全部）

## 4. 各Configクラスと @export 変数
| クラス名 | 定義する @export |

## 5. 判断に迷った点・複数の実装方法がありえた点
指示書に明記されていなかった箇所を、どう解釈するつもりか。
「特になし」は避け、少しでも迷った箇所は必ず書いてください。

## 6. 指示書に書かれていないが必要だと思われること
あれば書いてください。無ければ「なし」。

書けたら、そこで止めてください。
私が確認して「OK」と返すまで、実装に進まないでください。
```

---

### 【B】計画を確認する（5分・見るのは4箇所だけ）

`PRE_PLAN_COMMON_INFRA.md` が出てきたら、ここだけ見ます。

- [ ] **2章：Autoloadの登録順** — `Balance` が1番目になっているか
- [ ] **1章：ファイル名** — `game_manager.gd` のような小文字か（`GameManager.gd` ならNG）
- [ ] **3章：定数の数** — 24個あるか（`EXEC_COMMON_INFRA.md`の表と照合）
- [ ] **5章：迷った点** — **空になっていないか**

> **5章が「特になし」だったら、一度聞き返してください。**
> 「本当に迷った箇所はありませんか？　例えば `update_inventory_slot_position` の
> `position` 引数の型は指示書に明記されていましたか？」
>
> 実装すれば必ず解釈の余地は出ます。書かれていないのは、
> 無いのではなく**気づいていない**か**書いていない**だけです。

問題があれば、その場で指摘して計画を直させます。**ここで直すのが一番安い。**

---

### 【C】実装させる（コピペ用）

計画に問題がなければ、これを送ります。

```
計画を確認しました。OKです。この計画どおりに実装してください。

実装後、EXEC_COMMON_INFRA.md の「動作確認手順（完了条件）」14項目を
自分で1つずつ確認してください。

最後に IMPL_LOG_TEMPLATE.md の型に沿って
res://docs/03_log/IMPL_LOG_COMMON_INFRA.md を生成してください。

改めて念押し：
- 実際のゲームロジックは書かず、print で呼ばれたことが分かる
  空実装にしてください
- PRE_PLAN から変更した箇所があれば、IMPL_LOG の
  「5. 指示書からの逸脱・迷った判断」に必ず書いてください
```

計画に直したい箇所があれば、こう返します。

```
計画のうち、以下を直してください。直したら再度提示してください。
まだ実装には進まないでください。

- （例）Autoloadの登録順が違います。Balance を1番目にしてください。
  GameManager が _ready() で Balance.initial_state を参照するためです。
```

---

## ステップ4：Zivaに実装させる（1〜2時間）

- [ ] 【A】計画を書かせた
- [ ] 【B】4箇所を確認した
- [ ] 【C】OKを出して実装させた

### 途中で気をつけること

**エラーが出たら、まずZivaのログを見てください。** エラーメッセージには原因が書いてあることが多いです。

**同じ場所を3回以上直させたら、そこで止めてください。**
これは `AGENTS.md` に書いたルールです。3回直しても直らないということは、Zivaの理解不足ではなく**設計側に無理がある**サインです。無理に押し切ると、あとでもっと大きく壊れます。止めて相談してください。

### Zivaが終わったあと、自分でやる作業

コードが書けても、Godotエディタでの手作業が残ることがあります。

**(a) Autoloadの登録**

Project Settings → **Autoload** タブを開く。5つが登録されているか確認します。

**並び順が超重要です。**

```
1. Balance        ← 一番上
2. GameManager
3. SaveManager
4. SceneManager
5. SignalBus
```

> **なぜ順番が大事？**
> `GameManager` は起動時に `Balance` の設定値を読んで、自分の初期状態（最初の所持金など）を作ります。
> Godotは上から順に起動するので、`Balance` が下にあると「まだ用意できていないものを読もうとした」というエラーになります。

順番が違ったら、右の**上下の矢印**で並べ替えてください。

**(b) `.tres` ファイルを作る**

`.tres` は「数値をまとめて入れておく箱」です。これがないと `Balance` が空のままになります。

1. FileSystemで `res://resources/balance/` を右クリック
2. **Create New → Resource**
3. 検索欄に `PomodoroConfig` と入力して選択、**Create**
4. `pomodoro_config.tres` という名前で保存

同じ手順で残りも作ります：`shop_config.tres` / `research_config.tres` / `workshop_config.tres` / `character_config.tres` / `initial_state_config.tres`

> **`PomodoroConfig` が検索しても出てこないときは？**
> `class_name` を書いた直後はGodotが認識していないことがあります。**Godotを一度再起動**してください。これで大体直ります。

**(c) `.tres` を Balance に割り当てる**

1. `res://autoload/balance.tscn` をダブルクリックで開く
2. シーンツリーの**一番上のノード**をクリック
3. 右側のInspectorに `Pomodoro` `Shop` `Research`... という欄が並んでいる
4. さっき作った `.tres` を、FileSystemから対応する欄へ**ドラッグ&ドロップ**
5. **Ctrl+S**（Macは Cmd+S）で保存

---

## ステップ5：自分で動作確認する（30分）

**Zivaの「できました」を信用しないでください。** 実際に動かして自分の目で確認します。

### テスト用シーンの作り方

**1) シーンを作る**

- 上メニュー **Scene → New Scene**
- 右側の「その他のノード」から **Node** を選んで作成
- **Ctrl+S** で `res://tests/test_infra.tscn` として保存

**2) スクリプトを付ける**

- シーンツリーのルートノードを選択
- 右クリック → **Attach Script**
- パスを `res://tests/test_infra.gd` にして **Create**

**3) 下のコードを全部貼り付ける**（元からある内容は消してOK）

```gdscript
extends Node

func _ready() -> void:
	print("========== 共通基盤テスト開始 ==========")

	# --- 項目3：add_gold で resource_changed が発火するか ---
	GameManager.resource_changed.connect(_on_resource_changed)
	print("[3] add_gold(100) を呼ぶ →")
	GameManager.add_gold(100)

	# --- 項目12：get_state がスナップショットか ---
	print("[12] get_state のスナップショット検証 →")
	var snapshot: Dictionary = GameManager.get_state()
	var before = snapshot.get(GameStateKeys.GOLD, null)
	snapshot[GameStateKeys.GOLD] = 999999
	var after = GameManager.get_state().get(GameStateKeys.GOLD, null)
	if after == 999999:
		print("  ❌ 失敗：外から書き換えたら内部状態も変わってしまった")
	else:
		print("  ✅ 成功：内部状態は守られた（前=%s 後=%s）" % [before, after])

	# --- 項目4：宝箱 ---
	print("[4] add_pending_chest → open_chest →")
	GameManager.pending_chests_changed.connect(_on_chests_changed)
	GameManager.add_pending_chest({
		"chest_id": "test_chest_1",
		"chest_type": "normal",
		"source": "pomodoro",
		"opened": false,
		"rewards": {"gold": 50, "gems": 0, "materials": {}, "inventory": {}}
	})
	print("  未開封件数 = %d（期待値: 1）" % GameManager.get_pending_chest_count())
	GameManager.open_chest("test_chest_1")
	print("  開封後の未開封件数 = %d（期待値: 0）" % GameManager.get_pending_chest_count())

	# --- 項目5：ポモドーロ報酬 ---
	print("[5] apply_pomodoro_rewards →")
	SignalBus.pomodoro_session_completed.connect(_on_pomodoro_done)
	GameManager.apply_pomodoro_rewards({
		"gold": 30, "stamina": 2, "materials": {"construction_material": 1}
	})

	# --- 項目6：戦闘報酬 ---
	print("[6] apply_battle_rewards →")
	SignalBus.battle_finished.connect(_on_battle_done)
	GameManager.apply_battle_rewards({
		"victory": true, "waves_cleared": 5,
		"rewards": {"gold": 100, "materials": {"construction_material": 3}}
	})

	# --- 項目7：条件を満たさないとき false を返すか ---
	print("[7] 失敗するはずの操作 →")
	print("  purchase_shop_item = %s（期待値: false）" % GameManager.purchase_shop_item("daily", 0))
	print("  level_up_character = %s（期待値: false）" % GameManager.level_up_character("dummy_char"))
	print("  unlock_research_node = %s（期待値: false）" % GameManager.unlock_research_node("dummy_node"))
	print("  start_craft = %s（期待値: false）" % GameManager.start_craft("dummy_recipe"))
	print("  collect_craft = %s（期待値: false）" % GameManager.collect_craft("dummy_queue"))
	print("  spend_stamina(99999) = %s（期待値: false）" % GameManager.spend_stamina(99999))

	# --- 項目13：Balance が読めているか ---
	print("[13] Balance の参照確認 →")
	if Balance == null:
		print("  ❌ Balance が null。Autoloadの登録を確認")
	elif Balance.initial_state == null:
		print("  ⚠️ initial_state が未割り当て。balance.tscn のInspectorで .tres を割り当てる")
	else:
		print("  ✅ Balance.initial_state を参照できた")

	print("========== テスト終了 ==========")


func _on_resource_changed(resource_type: String, new_value) -> void:
	print("  ✅ resource_changed 発火: %s = %s" % [resource_type, new_value])

func _on_chests_changed(pending_count: int) -> void:
	print("  ✅ pending_chests_changed 発火: %d件" % pending_count)

func _on_pomodoro_done(reward_data: Dictionary) -> void:
	print("  ✅ pomodoro_session_completed 発火: %s" % reward_data)

func _on_battle_done(result_data: Dictionary) -> void:
	print("  ✅ battle_finished 発火: %s" % result_data)
```

**4) 実行する**

`test_infra.tscn` を開いた状態で **F6** を押します（「現在のシーンを実行」）。

> F5 は「メインシーンを実行」なので違います。**F6** です。
> Macで動かない場合は、エディタ右上の「再生」ボタンの隣にある**フィルムのアイコン**を押しても同じです。

**5) 結果を読む**

エディタ下部の **出力（Output）** パネルにログが出ます。`❌` が出ていなければ合格です。

### ログを目で確認するチェックリスト

- [ ] `[3]` で `resource_changed 発火` が出た
- [ ] `[12]` が `✅ 成功` になっている
- [ ] `[4]` の件数が `1` → `0` になっている
- [ ] `[5]` `[6]` でシグナルが発火している
- [ ] `[7]` が全部 `false`
- [ ] `[13]` が `✅`

### スクリプトでは見られない項目（目で確認）

- [ ] **項目1**：`res://autoload/` に5つある。**ファイル名が小文字とアンダースコア**（`game_manager.gd` であって `GameManager.gd` ではない）
- [ ] **項目2**：Autoloadの並び順が `Balance` から始まっている
- [ ] **項目8**：`balance.tscn` を開き、Inspectorの `Pomodoro` 欄に `.tres` が入っていて、クリックすると中身が開ける
- [ ] **項目11**：`game_manager.gd` の `get_state()` を読む。`"gold"` という**生の文字列ではなく** `GameStateKeys.GOLD` になっているか

### 項目9・10（画面遷移）の確認方法

これは別に確認が必要です。

1. `res://tests/` にシーンを2つ作る（`test_scene_a.tscn` / `test_scene_b.tscn`）
2. Aのスクリプトに書く：

```gdscript
extends Node

func _ready() -> void:
	print("シーンA。3秒後にBへ遷移します")
	await get_tree().create_timer(3.0).timeout
	SceneManager.change_scene_with_data(
		"res://tests/test_scene_b.tscn",
		{"test_key": "こんにちは"}
	)
```

3. Bのスクリプトに書く：

```gdscript
extends Node

func _ready() -> void:
	var data = SceneManager.consume_transfer_data()
	print("1回目に受け取った: ", data, "（期待値: {test_key: こんにちは}）")
	var again = SceneManager.consume_transfer_data()
	print("2回目に受け取った: ", again, "（期待値: {} 空っぽ）")
```

4. Aを開いて **F6**

- [ ] Bに遷移した
- [ ] 1回目にデータが取れて、2回目は空だった

---

## ステップ6：レビューする（10分）

### `IMPL_LOG_COMMON_INFRA.md` を読む

`res://docs/03_log/` にあるはずです。特に見るのは**「5. 指示書からの逸脱・迷った判断」**。

> **ここが「逸脱なし」の一言だけだったら要注意です。**
> 実装すれば必ず「指示書に書いていなかったから、こう解釈した」という判断が発生します。何も書いていないのは、逸脱がなかったのではなく**記録していないだけ**の可能性が高いです。

- [ ] 5番の欄を読んだ
- [ ] 書かれている判断に、違和感がないか考えた

### ここで立ち止まる（進行ゲート）

**14項目が通っても、すぐ次に進まないでください。** ここで一度考えます。

- [ ] Dictionaryでデータを持つやり方は、実際に書いてみてしんどくなかったか
- [ ] `GameStateKeys` を使う書き方は、面倒すぎないか
- [ ] 名前の解釈違いや、シグナルの発火漏れはないか

> **なぜここで止まる？**
> `GameManager` の上に、これから作る**全部の画面**が乗ります。
> 今なら直すのは1ファイルですが、10画面作ったあとで直すと10画面ぜんぶ直すことになります。
> 違和感があるなら、**進まずにここで直す**のが一番安いです。

---

## ステップ7：次のタスクへ

14項目を通過して、違和感もなければ、進行ゲート突破です。

次は `PLAN_UI_COMMON.md` から `EXEC_UI_COMMON.md` を書きます。

**そのとき用意するもの：**
- `PLAN_UI_COMMON.md`
- **Zivaが実際に書いた `game_manager.gd` などの実コード**
- `IMPL_LOG_COMMON_INFRA.md`

> **なぜ実コードが必要？**
> PLANはあくまで「こうしたい」という意図の記録です。実際のコードとは細かいところがズレます。
> ズレたまま次の指示書を書くと、「存在しない関数を呼べ」という指示をZivaに渡すことになります。
> だから毎回、実物を見てから書きます。

そのあとの流れはこうです。

```
UI共通パーツ   → 実装
タイトル→拠点  → 実装
拠点画面       → 実装
ポモドーロ最小 → 実装
      ↓
    MVP完成 ← ここで一度、実際に遊んでみる
```

MVPまで来たら、「ポモドーロを1周やると報酬がもらえる」が動きます。**そこが面白いかどうかを確かめてから**、戦闘やギルドに進んでください。

---

## 困ったときは

| こうなったら | こうする |
|---|---|
| `Balance` が null と言われる | Autoloadの並び順を確認。`Balance` が一番上にあるか |
| `GameStateKeys` が見つからないエラー | `scripts/utils/state_keys.gd` に `class_name GameStateKeys` があるか確認 → **Godotを再起動** |
| `.tres` を作ろうとしてもConfigクラスが出てこない | **Godotを再起動**。`class_name` は再起動後に認識されることがある |
| F6を押しても何も起きない | シーンを保存したか確認。未保存だと実行されない |
| 出力パネルが見当たらない | エディタ下部の「出力」タブ。閉じている場合は下端をドラッグして開く |
| 同じ場所を3回以上直している | **止める。** 設計に無理があるサイン |
| Zivaが頼んでいないものを作り始めた | 渡したファイルが3つだけか確認。PLANを渡すと余計なことをしがち |
| 【A】でいきなりコードを書き始めた | 「コードは書かないでください」を先頭に置いて再送。それでも書くならモデルを変える |
| 同じ修正を延々と繰り返す | 推論量を上げる → タスクを小さく切る → モデルを変える（付録参照） |
| エラーの意味が分からない | エラーメッセージをそのままコピーして相談してください |

---

## 付録：モデルの選び方と推論量の設定

（2026年8月時点の情報。モデルは入れ替わりが速いので、半年後には古くなっている前提で読んでください）

### 推論量（reasoning effort）とは

「どれくらい考えてから答えるか」の設定です。多く考えるほど正確ですが、遅くて高くなります。

**注意**：モデルによって段階の名前も数もバラバラです。同じ「high」でも意味が違います。

| モデル | 選べる段階 | デフォルト |
|---|---|---|
| GLM 5.2 | `high` / `max` の2段階のみ | **`max`**（何も指定しないと最大） |
| Gemini 3.5 Flash | `low` / `medium` / `high` | `medium` |
| Kimi K3 | — | **常に最大**（下げられない） |

### 用途別のおすすめ

| 場面 | 推論量 | 理由 |
|---|---|---|
| 【A】計画を書かせる | **高め**（GLM=`max` / Gemini=`high`） | 判断が要る。出力が短いので高くても総額は小さい |
| 【C】実装させる（今回の共通基盤） | **低め**（GLM=`high` / Gemini=`low`〜`medium`） | EXECがすでにコードに近く、判断の余地が少ない |
| 難しいタスク（戦闘画面など） | **高め** | 設計判断が多く発生する |
| うまくいかない・やり直しが多い | まず**上げてみる** | 考え不足が原因のことが多い |

> **GLM 5.2を使うときの注意**
> デフォルトが `max` なので、**何もしないと常に全力**です。トークンをかなり食います。
> 今回のような単純作業では `high` を明示的に指定したほうが安く済みます。
> ただしZ.ai公式は「コーディングには `max` 推奨」としているので、
> 品質が落ちるようなら `max` に戻してください。

> **Zivaの画面に推論量の設定が見当たらない場合**
> UIで公開されていないこともあります。その場合はデフォルト（GLMなら`max`）で動いています。
> 気にせず進めて構いません。

### モデルの使い分け（2026年8月時点）

| 役割 | おすすめ | 理由 |
|---|---|---|
| 【A】計画 | Gemini 3.5 Flash | エージェント性能が高い。出力が短いので高くても総額小 |
| 【C】実装 | **GLM 5.2** | Terminal-Bench 81.0が第三者検証済み。出力トークンが安い |
| 実装（もっと安く） | MiniMax M3 | 最安。ただしベンチマークは自社測定のみ |
| 避けたほうがいい | Kimi K3 | 高い上に推論量を下げられず、ループにハマると青天井 |

**コードを書く作業は出力が長い**ので、出力トークンが安いモデルを選ぶと効きます。
逆に**計画は出力が短い**ので、多少高いモデルを使っても総額は知れています。

### 「やり直しループ」にハマったときの対処

DeepSeek系などで、同じ修正を延々と繰り返すことがあります。順に試してください。

1. **推論量を上げる**（考え不足が原因のことが多い）
2. **タスクを小さく切る**（「5つ全部」ではなく「GameManagerだけ」）
3. **モデルを変える**
4. **3回直しても直らなければ止める**（`AGENTS.md`のルール。設計側の問題の可能性）

### モデルを分けて使うときの手順

計画と実装で別のモデルを使う場合、**会話が途切れます**。だから計画をファイル（`PRE_PLAN_◯◯.md`）に書かせておくことが必須になります。

```
1. 賢いモデルに切り替え → 【A】計画を書かせる
2. PRE_PLAN_◯◯.md が保存される
3. 安いモデルに切り替え
4. AGENTS.md + EXEC_◯◯.md + PRE_PLAN_◯◯.md を渡して実装させる
```

> **ただし共通基盤（今回）は分けないでください。**
> ここは全画面が乗る土台なので、モデル分割という新しい変数を持ち込むと、
> 問題が起きたときに原因の切り分けが難しくなります。
> **分けるのは次のタスク（UI共通パーツ）から**試すのがおすすめです。

---

## メモ：あとで対応すること（今はやらない）

忘れないための覚え書きです。**MVPが動くまでは手を付けないでください。**

- **Steam Rich Presence**（フレンド欄にポモドーロ状態を表示）
  → 仕様は `DATA_SCHEMA.md` 2-7 に確定済み。App ID取得後に実装
- **セーブの保存先は `user://saves/`**
  → `SaveManager` を実装するときに守ること。Steamクラウドセーブ対応のため
- **ローカルマルチ**
  → 通信を伴うものは実装が重い。Rich Presenceで「みんなでやってる感」は代替できる見込み
- **PLANが無い画面**（冒険選択・パーティ選択・設定・シナリオ）
  → 着手するタイミングでPLANから書く
