# 【実行指示書】ギルド画面と倉庫（宝箱・インベントリ・図鑑）

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

拠点画面のチェストバッジから宝箱を開けられるようにし、**ポモドーロ → 宝箱 → 拠点が育つ**というループを閉じる。

---

## 0. 作業の進め方（このプロジェクト固有の制約・最初に読むこと）

過去のタスクで実際に起きた事故への対策。**守らないと同じ事故が起きる。**

### 0-1. ファイルの書き方

- **`edit_file` は使わない。** このプロジェクトでは動作しない
- **`create_file` に長い本文を渡さない。** トークン上限で失敗する。**1ファイルあたり150行を超えるものは、`bash` の追記で分割して書く**

```
cat >> "D:/pomodoro-heroes/（パス）" << 'EOF'
（本文・60行以内）
EOF
```

- **既存ファイルを `cat >` で上書きしない。** 追記は必ず `cat >>`
- **同じ内容を2回追記しない。** 過去に `@export` が重複してパースエラーになった事故がある
- **補助スクリプト（`.py` など）を作らない**
- **`sed` を使わない。** シェル依存で動作が保証されない

### 0-2. 書き終わったあと

- **読み返して誤字を直す作業をしない。** 誤字は人間が直す。修正作業に入らず、そこで止まること
- ただし**既存ファイルに追記した直後だけは `read` で開き、編集前の内容が残っていること・重複行がないことを確認する**（これは誤字チェックではなく破壊チェック）

### 0-3. 触らないもの

- `.tres` ファイル一切
- `res://autoload/` 配下すべて（**今回はGameManagerへの追加が不要**）
- `project.godot` の `[input]` セクション
- `res://theme/main_theme.tres`
- 既存の定数・関数・翻訳キーの削除・改名（追記のみ）

過去に `state_keys.gd` の既存定数が消えて全画面が起動不能になった事故がある。

---

## 前提・参照ドキュメント

- `AGENTS.md`：フォルダ構造・命名規則・状態構造の表・数値管理ルール
- `PLAN_GUILD_WAREHOUSE.md`：この実行指示書のもとになった第2層の作戦計画書

### 既存の実装状況（実コードで確認済み・推測しないこと）

| 対象 | 実際の状態 |
|---|---|
| `GameManager.get_state()` | `duplicate(true)`のスナップショットを返す |
| `GameManager.open_chest(chest_id)` | 実装済み。`opened`をtrueにし、`rewards`を反映して`bool`を返す。**中身は返さない** |
| `GameManager.get_pending_chest_count()` | `opened == false`の件数 |
| `GameManager.get_codex_entry(item_id)` | `{discovered, obtained_at}`を返す |
| `GameManager.pending_chests_changed` | `(pending_count: int)` |
| `GameManager.inventory_changed` | `(item_id: String)` |
| `INVENTORY`の構造 | `{item_id: {count, type, slot_position: {x,y}, properties}}` |
| `PENDING_CHESTS`の構造 | `[{chest_id, chest_type, source, obtained_at, opened, rewards}]` |
| `rewards`の構造 | `{gold, gems, stamina, materials, inventory}` |
| `CODEX`の構造 | `{item_id: {discovered, obtained_at}}` |
| `SceneManager.change_scene_with_data(path, data)` | 実装済み |
| `SceneManager.consume_transfer_data()` | 取り出すと同時に空になる |
| `res://scenes/ui/placeholder_screen.tscn` | 実装済み。`TransferKeys.SCREEN_ID`を受け取り画面名を出し分ける |
| `res://scenes/base/base_screen.gd` | `SCREEN_SCENES`の対応表を持つ。`SCREEN_GUILD`は`PLACEHOLDER_PATH`のまま |
| `PrimaryButton` / `ResourceDisplay` / `DialogBase` | 実装済み（`scenes/ui/components/`） |

**GameManagerへの追加は不要。** 既存の関数だけで足りる。

---

## 今回のタスク

### やること
- `TransferKeys` に定数追加
- ギルド画面（`guild_screen.tscn` / `.gd`）の新規作成
- 倉庫画面（`warehouse_screen.tscn` / `.gd`）の新規作成（3タブ）
- `base_screen.gd` の遷移先の差し替え（2箇所）
- `ja.csv` への追加

### やらないこと
- **インベントリのドラッグ&ドロップ**（`PLAN_GUILD_WAREHOUSE.md` 1章でスコープ外と確定）
- アイテムの使用・装備処理
- ギルドの倉庫以外のサブ画面の中身（ショップ・育成・研究・作業場）
- 宝箱の開封アニメーション・演出（結果はテキスト表示のみ）
- `GameManager` への関数追加
- `.tres` の編集

---

## 1. `TransferKeys` への追加

`res://scripts/utils/transfer_keys.gd` の**末尾に追記**する。既存の`SCREEN_ID`は変更しない。

```gdscript
# 倉庫画面を開いたときに最初に表示するタブ。
# 値は WarehouseScreen.TAB_* の文字列。
const WAREHOUSE_TAB: String = "warehouse_tab"
```

---

## 2. ギルド画面

`res://scenes/guild/guild_screen.tscn` / `.gd`（新規）

```
GuildScreen (Control)                    # full rect
├─ Background (ColorRect)                # Color(0.101961, 0.0784314, 0.0941176, 1)
└─ CenterContainer                       # full rect
    └─ Layout (VBoxContainer)
        ├─ TitleLabel (Label)            # text = "ui_nav_guild"
        ├─ WarehouseButton (primary_button.tscn)  # label_key = "ui_guild_warehouse"
        ├─ ShopButton (primary_button.tscn)       # label_key = "ui_guild_shop"
        ├─ TrainingButton (primary_button.tscn)   # label_key = "ui_guild_training"
        ├─ ResearchButton (primary_button.tscn)   # label_key = "ui_guild_research"
        ├─ WorkshopButton (primary_button.tscn)   # label_key = "ui_guild_workshop"
        └─ BackButton (primary_button.tscn)       # label_key = "ui_common_back"
```

> **中央寄せは `CenterContainer` に担当させること。** `Control` を `Control` の直下に置くと size が (0,0) になり、`anchors_preset` を書いても潰れる。過去に `DialogBase` で実際に踏んだ罠。

### 挙動

- 遷移先は**対応表1箇所に集約する**（`base_screen.gd` と同じ方式）

```gdscript
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const WAREHOUSE_PATH: String = "res://scenes/guild/warehouse_screen.tscn"

const GUILD_SCENES: Dictionary = {
	"warehouse": WAREHOUSE_PATH,
	"shop": PLACEHOLDER_PATH,
	"training": PLACEHOLDER_PATH,
	"research": PLACEHOLDER_PATH,
	"workshop": PLACEHOLDER_PATH,
}
```

- ボタンと`sub_screen_id`の対応も`Dictionary`かループで持たせ、5回同じコードを書かないこと
- 未実装画面へ飛ばすときは `SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: sub_screen_id})` を使う
  - `placeholder_screen` は `tr("ui_nav_" + screen_id)` で画面名を引くため、`ui_nav_shop` 等の翻訳キーが必要（§5で追加する）
- `BackButton` → `SceneManager.change_scene("res://scenes/base/base_screen.tscn")`
- **`get_tree().change_scene_to_file()` を直接呼ばない**

---

## 3. 倉庫画面

`res://scenes/guild/warehouse_screen.tscn` / `.gd`（新規）

### 3-1. シーン階層

```
WarehouseScreen (Control)                # full rect
├─ Background (ColorRect)
└─ Layout (VBoxContainer)                # full rect
    ├─ Header (HBoxContainer)
    │   ├─ TitleLabel (Label)            # text = "ui_guild_warehouse"
    │   └─ BackButton (primary_button.tscn)   # label_key = "ui_common_back"
    └─ Tabs (TabContainer)               # size_flags_vertical = EXPAND_FILL
        ├─ InventoryTab (ScrollContainer)
        │   └─ InventoryGrid (GridContainer)   # columns = 4
        ├─ CodexTab (ScrollContainer)
        │   └─ CodexList (VBoxContainer)
        └─ ChestTab (VBoxContainer)
            ├─ OpenAllButton (primary_button.tscn)  # label_key = "ui_warehouse_open_all"
            ├─ ChestScroll (ScrollContainer)
            │   └─ ChestList (VBoxContainer)
            └─ ResultLabel (Label)       # 開封結果のテキスト
```

- `TabContainer` の各タブ名は、子ノードの `name` がそのまま使われる。**タブ名を日本語で表示するため、`_ready()` で `Tabs.set_tab_title(i, tr("..."))` を呼ぶこと**
  - タブ0：`ui_warehouse_tab_inventory`
  - タブ1：`ui_warehouse_tab_codex`
  - タブ2：`ui_warehouse_tab_chest`
- `BackButton` → ギルド画面へ戻る

### 3-2. タブ識別子

```gdscript
const TAB_INVENTORY: String = "inventory"
const TAB_CODEX: String = "codex"
const TAB_CHEST: String = "chest"
```

`_ready()` で `SceneManager.consume_transfer_data()` を呼び、`TransferKeys.WAREHOUSE_TAB` があれば該当タブを選択する。無ければタブ0（インベントリ）のまま。

### 3-3. インベントリタブ

- `GameManager.get_state()` の `INVENTORY` を走査し、`InventoryGrid` にエントリを動的生成する
- 各エントリは `VBoxContainer` で、アイテム名と個数を表示する
  - アイテム名：`tr("ui_res_" + item_id)`（素材と同じ規約。**新しい接頭辞を作らないこと**）
  - 個数：`ITEM_COUNT` の値。数値のみなので `tr()` 不要
- **`inventory_changed` を購読し、変化があったらそのタブを作り直す**
  - 差分更新にしないのは、グリッドの位置管理が今回スコープ外のため。**作り直しでよい**
- 空のときは「アイテムがありません」（`ui_warehouse_empty`）を1行表示する

### 3-4. 図鑑タブ

- `GameManager.get_state()` の `CODEX` を走査し、`CodexList` に1行ずつ生成する
- `CODEX_DISCOVERED` が `true` → `tr("ui_res_" + item_id)` を表示
- `false` → `tr("ui_warehouse_undiscovered")`（「？？？」等）を表示
- 空のときは `ui_warehouse_empty` を表示

> **武器がまだ存在しないため、現状はポーション等が数件並ぶだけになる。** これは正常。図鑑フラグが自動で立つ仕組みが動いていることの確認が目的。

### 3-5. 宝箱タブ

**ここが今回の本命。**

- `GameManager.get_state()` の `PENDING_CHESTS` のうち `CHEST_OPENED == false` のものだけを `ChestList` に並べる
- 各行は `HBoxContainer` で、宝箱の種類名と「開ける」ボタンを持つ
  - 種類名：`tr("ui_pomodoro_chest_" + chest_type)`（**ポモドーロで定義済みのキーを使い回す**。`ui_pomodoro_chest_generic` / `_bonus_small` / `_bonus_medium` / `_bonus_large`）
- 空のときは `ui_warehouse_no_chest` を表示し、`OpenAllButton` を `disabled` にする

#### 開封処理（重要）

**`open_chest()` は中身を返さない。** よって以下の順で行う。

1. **開封の前に**、その宝箱の `CHEST_REWARDS` を `get_state()` から読んでおく
2. `GameManager.open_chest(chest_id)` を呼ぶ
3. 戻り値が `true` なら、手順1で読んでおいた `rewards` を整形して `ResultLabel` に表示する
4. `false` なら何もしない（`push_warning` のみ）

**`open_chest()` のシグネチャを変更しないこと。** 既存の呼び出し元に影響するため。

#### 結果の表示形式

`rewards` の各項目のうち、**値が0または空でないものだけ**を並べる。

```
建築素材 ×10
```

- `REWARD_GOLD` / `REWARD_GEMS` / `REWARD_STAMINA` → `tr("ui_res_gold")` 等 + ` ×` + 値
- `REWARD_MATERIALS` → 各 `material_id` について `tr("ui_res_" + material_id)` + ` ×` + 値
- `REWARD_INVENTORY` → 各 `item_id` について `tr("ui_res_" + item_id)` + ` ×` + 値
- 複数ある場合は改行で並べる

#### 「すべて開ける」

- 未開封の宝箱をすべて開け、獲得したものを**合算して** `ResultLabel` に表示する
- 1件ずつ `open_chest()` を呼ぶ。まとめて処理する新しい関数を作らないこと

#### 更新

- `pending_chests_changed` を購読し、宝箱タブの一覧を作り直す
- 開封後、拠点画面に戻るとチェストバッジの件数が減っていること

---

## 4. `base_screen.gd` の変更

**2箇所だけ変更する。他は触らない。**

### 4-1. `SCREEN_SCENES` の差し替え

```gdscript
	GameStateKeys.SCREEN_GUILD: "res://scenes/guild/guild_screen.tscn",
```

他の4画面は `PLACEHOLDER_PATH` のまま。

### 4-2. チェストバッジの遷移先

現在は `_go_to_screen(GameStateKeys.SCREEN_GUILD)` を呼んでギルド画面へ行く。
**倉庫の宝箱タブへ直接遷移するように変更する。**

```gdscript
func _on_chest_badge_pressed() -> void:
	SceneManager.change_scene_with_data(
		"res://scenes/guild/warehouse_screen.tscn",
		{TransferKeys.WAREHOUSE_TAB: "chest"}
	)
```

バッジを押したのに別のタブが開くのは導線として不自然なため。

---

## 5. `ja.csv` への追加

**UTF-8（BOMなし）で保存し、編集後に再インポートすること。**
**`cat >>` で追記すること。`cat >` で上書きしない。**
**追記後、`read` で開いて既存の行がすべて残っていることを確認すること。**

```
ui_guild_warehouse,倉庫
ui_guild_shop,ショップ
ui_guild_training,育成
ui_guild_research,研究
ui_guild_workshop,作業場
ui_nav_warehouse,倉庫
ui_nav_shop,ショップ
ui_nav_training,育成
ui_nav_research,研究
ui_nav_workshop,作業場
ui_warehouse_tab_inventory,持ち物
ui_warehouse_tab_codex,図鑑
ui_warehouse_tab_chest,宝箱
ui_warehouse_open_all,すべて開ける
ui_warehouse_empty,なにもありません
ui_warehouse_undiscovered,？？？
ui_warehouse_no_chest,受け取れる宝箱はありません
ui_warehouse_opened,開けました
```

- `ui_nav_*` は未実装画面が `tr("ui_nav_" + screen_id)` で引くために必要
- `ui_guild_*` と `ui_nav_*` で同じ日本語が重複するが、**用途が異なる**（前者はギルド画面のボタン、後者は未実装画面の見出し）。統合しないこと
- `ui_res_gold` / `ui_res_stamina` / `ui_res_construction_material` / `ui_res_stamina_potion` / `ui_common_back` / `ui_nav_guild` / `ui_pomodoro_chest_*` は**すでに存在する。追加しないこと**

---

## 動作確認手順（完了条件）

1. 拠点画面のギルドボタンからギルド画面へ遷移する
2. ギルド画面に6つのボタン（倉庫・ショップ・育成・研究・作業場・戻る）が日本語で表示される
3. 「戻る」で拠点画面へ戻る
4. ショップ・育成・研究・作業場を押すと未実装画面へ遷移し、**画面名が「ショップ（未実装）」のようにボタンごとに変わる**
5. ギルド画面の「倉庫」から倉庫画面へ遷移する
6. 倉庫画面のタブが「持ち物 / 図鑑 / 宝箱」と日本語で表示され、切り替えられる
7. 持ち物タブに、所持しているアイテム（建築素材・スタミナポーション等）が名前と個数で表示される
8. 図鑑タブに、入手済みアイテムの名前が表示される（未入手があれば「？？？」）
9. **拠点画面のチェストバッジを押すと、倉庫画面の宝箱タブが開いた状態で表示される**
10. 宝箱タブに未開封の宝箱が種類名（「ボーナス宝箱（小）」等）で並ぶ
11. 「開ける」を押すと宝箱が一覧から消え、**獲得した中身が「建築素材 ×10」のような形で表示される**
12. 開封後に拠点画面へ戻ると、チェストバッジの件数が減っている（0件なら非表示）
13. 開封で得た素材が拠点下部の建築素材の数値に反映されている
14. 「すべて開ける」で未開封の宝箱がまとめて開き、合算した中身が表示される
15. 宝箱が0件のとき「受け取れる宝箱はありません」が表示され、「すべて開ける」が`disabled`になっている
16. 画面遷移がすべて `SceneManager` 経由であることを `grep` で確認できる（`change_scene_to_file()` の直接呼び出しが `scene_manager.gd` 以外に無い）
17. 遷移先のシーンパスが対応表1箇所にまとまっており、ボタンごとに直書きされていないことをコードレビューで確認できる
18. `ja.csv` に18行が追加され、**既存のキーがすべて残っている**ことを`read`で確認できる。画面にキー名（`ui_warehouse_*` 等）がそのまま出ていない
19. `transfer_keys.gd` に `WAREHOUSE_TAB` が追加され、**既存の `SCREEN_ID` が残っている**
20. `IMPL_LOG_TEMPLATE.md`の型に沿って `res://docs/03_log/IMPL_LOG_GUILD_WAREHOUSE.md` が生成されている

### 宝箱を用意する方法

宝箱が0件で検証できない場合は、ポモドーロ画面のデバッグパネル（デバッグ実行時に左上に出る）で「分を加算」に `45` を入れて押し、「このフェーズを終わらせる」で拠点へ戻ると宝箱が1つ手に入る。**加護を選んでいないと宝箱が積まれないので注意すること。**

### 検証について

**「コードを確認した」「ロジック上正しい」は動作確認ではない。** 実際に動かし、「何をしたら何と表示されたか」を書くこと。

完了条件は**このファイルから項目番号ごと文言ごとそのまま転記**し、1項目ずつ検証すること。要約・言い換え・統合をしないこと。

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名はsnake_case、`class_name`とノード名はPascalCase、シグナルは過去形
- 状態のキーは文字列リテラルではなく `GameStateKeys` の定数を使う（**ネストしたキーも含む**）
- 全ての表示テキストは `tr()`（または`auto_translate`が効く`text`への翻訳キー）を経由する
- 色・フォントは個別シーンにハードコードせず、Theme経由にする（背景の`ColorRect`は例外）
- 画面遷移は必ず `SceneManager` 経由
- **エラー回避のために型指定・命名規則・状態アクセスのルールを緩めない。** `class_name`が認識されない場合はGodotエディタを再起動する
- Autoloadを追加しない（5つ固定）
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
