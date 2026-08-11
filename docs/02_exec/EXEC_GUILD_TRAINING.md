# 【実行指示書】ギルド - 育成（第1弾：レベルアップ）

第3層。対応する第2層は`PLAN_GUILD_TRAINING.md`（実コードと突き合わせて改訂済みの版）。

**この指示書は3者で分担する。自分の担当外のファイルには触らないこと。**

| 誰 | 担当するファイル |
|---|---|
| **人間** | `ja.csv` / `initial_state_config.tres` / `character_config.tres` / `guild_screen.gd`の1行差し替え |
| **設計役** | `game_manager.gd`（691行）/ `growth_formula.gd` / `workshop_config.gd` |
| **実装役** | `stages.json` / `characters.json` / `training_screen.tscn` / `training_screen.gd` |

---

## 1. このタスクで実現すること

戦闘で得た`training_material`を消費してキャラクターのレベルを上げ、**上げたステータスがそのまま戦闘に反映される**ところまで。

スキル選択と装備は**含まない**。ボタンだけ置いて`placeholder_screen`へ飛ばす。

---

## 2. 事故りやすい箇所（先に読むこと）

### 2-1. `MasterDataLoader`が返す数値は`float`

`get_character()`はJSONをそのまま返すため、`hp`は`120`ではなく`120.0`で来る。`battle_controller.gd`は`int()`で包んでいるので問題が出ていないだけ。

**`stats`を組み立てるときは必ず`int()`で包む。** 包み忘れると、セーブに`"hp": 128.0`と書かれる。

### 2-2. `get_effective_level_cap()`は現在かならず`0`を返す

`game_manager.gd` 505行は既に実装済みで、研究ツリー（現在は空）を走査して合計を返す。**このまま使うとレベル1で上限扱いになり、画面が何も操作できなくなる。** §5-3で書き換える。

### 2-3. `add_material()`は残高を確認しない

負数を渡せばマイナスまで減る。**必ず`get_material_count()`で確認してから減算する。**

### 2-4. `_state`のネストを直接書き換えない

`AGENTS.md`「状態アクセスのルール」。取り出したDictionaryを書き換えるのではなく、複製して変更し、`_state`へ代入し直す。`_copy_dict()`があるのでそれを使う。

### 2-5. キー名を文字列で書かない

`"level"`ではなく`GameStateKeys.GROWTH_LEVEL`。`state_keys.gd`に全部そろっている（`GROWTH_LEVEL` / `GROWTH_STATS` / `GROWTH_SKILLS` / `GROWTH_EQUIPMENT` / `STAT_HP` / `STAT_ATK` / `STAT_DEF` / `STAT_SPD` / `EQUIP_WEAPON` / `EQUIP_ARMOR` / `EQUIP_ACCESSORY`）。**新しい定数は追加しない。**

### 2-6. `state_keys.gd`は追記のみ

過去に既存定数が消えて全画面が起動不能になっている。**このタスクでは編集不要。**

---

## 3. 人間が先にやる作業

**ここが終わっていないと、実装役の作業がパースエラーや空表示で止まる。先に済ませること。**

### 3-1. `ja.csv`に翻訳キーを追加

| キー | 日本語（案） |
|---|---|
| `ui_res_training_material` | 修練の証 |
| `ui_training_title` | 育成 |
| `ui_training_level` | Lv.%d |
| `ui_training_level_up` | レベルアップ |
| `ui_training_cost` | 必要素材 |
| `ui_training_owned` | 所持 |
| `ui_training_max_level` | 研究で上限の解放が必要です |
| `ui_training_stat_hp` | HP |
| `ui_training_stat_atk` | 攻撃 |
| `ui_training_stat_def` | 防御 |
| `ui_training_stat_spd` | 速さ |
| `ui_training_skill` | スキル |
| `ui_training_equipment` | 装備 |
| `ui_nav_training_skill` | スキル |
| `ui_nav_training_equipment` | 装備 |

`ui_common_back`は既存。

### 3-2. `initial_state_config.tres`に初期素材を追加

**詳しい手順は§9に分けて書いた。** 先にそちらを実施すること。

### 3-3. `character_config.tres`の値を入れる

**§5-1で`character_config.gd`に`@export`が3つ増える。** 設計役の作業が終わってから、Inspectorで以下を入力する。

| プロパティ | 値 |
|---|---|
| `level_up_material_id` | `training_material` |
| `base_level_up_cost` | `3` |
| `cost_growth_per_level` | `1.0` |
| `base_level_cap` | `10` |
| `stat_growth_formula` | `base + growth * (level - 1)` |
| `level_up_cost_formula` | `base + growth * (level - 1)` |

**式は文字列。前後に余計な空白や全角文字を入れないこと。**

### 3-4. `guild_screen.gd`の遷移先差し替え（**最後に**）

```gdscript
"training": PLACEHOLDER_PATH,
```
↓
```gdscript
"training": TRAINING_PATH,
```

および定数の追加：
```gdscript
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
```

さらに`_go_to_sub()`は`path == PLACEHOLDER_PATH`でのみ`change_scene_with_data`を使う分岐になっているため、**育成は`else`側（`change_scene`）を通る。修正不要。**

**この差し替えは`training_screen.tscn`が存在するようになってから行う。** 先にやると遷移先が無くエラーになる。

---

## 4. 実装役がやる作業

**新規ファイルの作成とJSONへの追記のみ。既存の`.gd`には一切触らないこと。**

### 4-1. `stages.json`に素材を追記

各ステージの`rewards.materials`に1キー足す。**`construction_material`と`gold`の値は変えない。**

| ステージ | 追加する値 |
|---|---|
| stage_1 | `"training_material": 2` |
| stage_2 | `"training_material": 4` |
| stage_3 | `"training_material": 6` |

例（stage_1）：
```json
"rewards": { "gold": 50, "materials": { "construction_material": 3, "training_material": 2 } }
```

`waves`には触らない。

### 4-2. `characters.json`に成長値を追記

各キャラに`growth_per_level`を追加する。**既存のキーは変えない。**

```json
"char_swordsman": {
  "name_key": "ui_battle_char_swordsman",
  "hp": 120, "atk": 18, "def": 6, "spd": 60,
  "attack_range": 60, "attack_interval_sec": 1.2,
  "skills": ["skill_power_slash", "skill_wide_sweep"],
  "growth_per_level": { "hp": 8, "atk": 2, "def": 1, "spd": 1 }
}
```

| キャラ | hp | atk | def | spd |
|---|---|---|---|---|
| `char_swordsman` | 8 | 2 | 1 | 1 |
| `char_archer` | 5 | 2 | 1 | 1 |
| `char_priest` | 4 | 1 | 1 | 1 |

### 4-3. `res://scenes/guild/training_screen.tscn`（新規）

**ノード構成をこのとおりに作る。名前を変えない**（`training_screen.gd`が`$`で参照する）。

```
TrainingScreen (Control)          ← script: training_screen.gd
├── Background (ColorRect)         color = (0.101961, 0.0784314, 0.0941176, 1)
└── Margin (MarginContainer)       上下左右 24
    └── Layout (VBoxContainer)
        ├── TitleLabel (Label)                    text = "ui_training_title"
        ├── MaterialLabel (Label)                 所持素材の表示
        ├── ListPanel (VBoxContainer)             キャラ一覧（中身はコードで生成）
        ├── DetailPanel (VBoxContainer)           visible = false
        │   ├── NameLabel (Label)
        │   ├── LevelLabel (Label)
        │   ├── StatsLabel (Label)                4項目を改行で1つのLabelに出す
        │   ├── CostLabel (Label)
        │   ├── NoticeLabel (Label)               上限到達時の案内。通常は空文字
        │   ├── LevelUpButton (PrimaryButton)     label_key = "ui_training_level_up"
        │   ├── SkillButton (PrimaryButton)       label_key = "ui_training_skill"
        │   ├── EquipButton (PrimaryButton)       label_key = "ui_training_equipment"
        │   └── ToListButton (PrimaryButton)      label_key = "ui_common_back"
        └── BackButton (PrimaryButton)            label_key = "ui_common_back"
```

- `Background`は`anchors_preset = 15`で全面に広げる
- `PrimaryButton`は`res://scenes/ui/components/primary_button.tscn`をインスタンス化する（**`Button`を直接置かない**）
- **色・フォントを個別指定しない。** `main_theme.tres`に任せる（`AGENTS.md`「Themeの扱い」）
- `ColorRect`にThemeは効かないため、`Background`の色指定だけは例外として直書きしてよい

### 4-4. `res://scenes/guild/training_screen.gd`（新規）

`class_name TrainingScreen extends Control`。

**やること**

1. `_ready()`で`MasterDataLoader`から全キャラを取得し、`ListPanel`にボタンを並べる
   - **キャラ数を3で決め打ちしない。** `characters.json`のキーを走査する
   - `MasterDataLoader`にキー一覧を返す関数は無い。`char_swordsman` / `char_archer` / `char_priest`の3つを**このファイル内の`const CHARACTER_IDS: Array[String]`に置く**（一覧取得APIの追加は今回のスコープ外。**ここは決め打ちしてよい唯一の箇所**）
   - ボタンのラベルは`tr(char_data["name_key"])`
2. ボタンを押したら`_show_detail(character_id)`。`ListPanel`を隠し`DetailPanel`を出す
3. `_show_detail()`が表示する内容
   - `NameLabel`：`tr(name_key)`
   - `LevelLabel`：`tr("ui_training_level") % level`
   - `StatsLabel`：`GameManager.get_effective_stats(id)`の4項目を改行区切り
   - `CostLabel`：`GameManager.get_level_up_cost(id)`の`amount`と、`GameManager.get_material_count()`の所持数
   - `NoticeLabel`：上限到達時のみ`tr("ui_training_max_level")`、それ以外は`""`
   - `LevelUpButton.disabled`：**上限到達 または 素材不足のとき`true`**
4. `LevelUpButton`：`GameManager.level_up_character(id)`を呼ぶ。戻り値は見なくてよい（表示更新はシグナル経由）
5. `SkillButton` / `EquipButton`：
   ```gdscript
   SceneManager.change_scene_with_data(PLACEHOLDER_PATH, {TransferKeys.SCREEN_ID: "training_skill"})
   ```
   （装備は`"training_equipment"`）
6. `ToListButton`：`DetailPanel`を隠して`ListPanel`を出す
7. `BackButton`：`SceneManager.change_scene("res://scenes/guild/guild_screen.tscn")`
8. シグナル接続
   - `GameManager.character_growth_changed` → 表示中のキャラなら`_show_detail()`をやり直す
   - `GameManager.material_changed` → 所持数の表示を更新する

**注意**

- **`GameManager._state`を直接読まない。** 必ず関数経由
- **数値をハードコードしない。** コスト・上限はすべて`GameManager`から取る
- **生の日本語を書かない。** すべて`tr()`
- `PLACEHOLDER_PATH`は`guild_screen.gd`と同じ`"res://scenes/ui/placeholder_screen.tscn"`

---

## 5. 設計役が書くもの（実装役は触らない）

**このファイル群は設計役が全文を渡す。実装役は受け取って保存するだけ。自分で書き換えない。**

### 5-1. `character_config.gd`

`@export`を3つ**末尾に追記**する。既存3つは変えない。

```gdscript
@export var base_level_cap: int = 10
@export var stat_growth_formula: String = "base + growth * (level - 1)"
@export var level_up_cost_formula: String = "base + growth * (level - 1)"
```

### 5-2. `res://scripts/utils/growth_formula.gd`（新規・静的クラス）

`Expression`で式を評価する。パース失敗・実行失敗のときは警告を出して`fallback`を返す。**式が壊れていてもゲームが止まらないこと**が要件。

- `static func evaluate(formula: String, vars: Dictionary, fallback: float) -> float`
- 空文字は即`fallback`
- 戻り値が数値でなければ`fallback`
- `push_warning`は出すが`push_error`は出さない（`.tres`の編集ミスは想定内のため）

### 5-3. `game_manager.gd`（691行・全文差し替え）

| 対象 | 内容 |
|---|---|
| `get_character_growth(id)` | エントリが無ければ`_default_growth_for(id)`を返す。**`_state`に書き込まない** |
| `level_up_character(id)` | 本実装。上限・素材を確認してから消費・レベル加算・`stats`再計算・シグナル発火 |
| `get_effective_level_cap(id)` | `Balance.character.base_level_cap` + 研究ノード合計に書き換え |
| `get_level_up_cost(id)` | 新規。`{material_id, amount}`を返す |
| `get_effective_stats(id)` | 新規。保存値 + `get_stat_boost_all()` |
| `_default_growth_for(id)` | 新規（private）。`MasterDataLoader.get_character()`から組み立て。**全項目`int()`** |
| `_recalc_stats(id, level)` | 新規（private）。`stat_growth_formula`で4項目を再計算 |
| `character_growth_changed(character_id)` | シグナル追加 |
| `load_state()` | `character_growth`の`level`・`stats`4項目に`int()`キャストを追加 |
| `_ready()`の`print` | **`materials`を出力に追加する。** 現状は`gold`/`stamina`/`unlocked_screens`しか出ておらず、初期素材が入ったかログで確認できない |

### 5-4. `workshop_config.gd`

`@export var level_up_material_id`を削除（`CharacterConfig`と重複しているコピペ事故）。

### 5-5. `AGENTS.md`

「GameManagerのシグナル」表に`character_growth_changed`を追記。**片方だけ直すと食い違う。**

---

## 6. 作業の順番

1. 人間：§3-1（`ja.csv`）、§9（初期素材）
2. 設計役：§5-1〜5-4のファイルを渡す
3. 人間：§3-3（`character_config.tres`の値入力）
4. 実装役：§4-1〜4-4
5. 人間：§3-4（`guild_screen.gd`の1行差し替え）
6. 人間：実機で§8のB章を確認

**3を飛ばすと、式が空文字になりステータスが伸びない。**

---

## 7. 完了条件A章：実装役が`print`で確認する

**この文言をそのまま`IMPL_LOG`に転記し、1項目ずつ結果を改行してから書くこと。**

- [ ] A-1. `GameManager.get_character_growth("char_swordsman")`が、未育成の状態で`level: 1`と`characters.json`どおりの`stats`（hp 120 / atk 18 / def 6 / spd 60）を返す
- [ ] A-2. A-1の直後に`GameManager.get_state()`を見ても、`character_growth`が空`{}`のままである
- [ ] A-3. `typeof()`で確認して、A-1が返す`level`と`stats`の4項目がすべて`TYPE_INT`である
- [ ] A-4. 素材が足りている状態で`level_up_character("char_swordsman")`が`true`を返し、`level`が2になる
- [ ] A-5. A-4の後、`stats.hp`が128、`stats.atk`が20になっている（`base + growth * (level - 1)`）
- [ ] A-6. A-4の後、`get_material_count("training_material")`が`get_level_up_cost()`の`amount`だけ減っている
- [ ] A-7. 素材を0にした状態で`level_up_character()`が`false`を返し、`level`も素材も変化しない
- [ ] A-8. `get_effective_level_cap("char_swordsman")`が、研究ツリーが空でも`10`を返す（**`0`ではない**）
- [ ] A-9. レベルが10の状態で`level_up_character()`が`false`を返し、素材が減らない
- [ ] A-10. `stat_growth_formula`に壊れた文字列（例：`"base + *"`）を入れても、警告が出るだけでクラッシュせず、フォールバック値が返る
- [ ] A-11. `growth_per_level`を持たないキャラを`characters.json`に一時的に足しても、`level_up_character()`が`true`を返しクラッシュしない（確認後その一時キャラは削除する）
- [ ] A-12. `MasterDataLoader.get_stage("stage_1")`の`rewards.materials`に`training_material: 2`が含まれている
- [ ] A-13. `MasterDataLoader.get_character("char_archer")`の`growth_per_level.hp`が5である

---

## 8. 完了条件B章：人間が実機で確認する

**実装役はここを転記するだけ。検証しないこと。** ヘッドレスでは原理的に確認できない。

- [ ] B-1. ギルド画面の「育成」ボタンから育成画面へ遷移する
- [ ] B-2. キャラクター一覧に3人が名前つきで並ぶ
- [ ] B-3. キャラクターを選ぶと詳細が表示され、レベルとステータス4項目が出る
- [ ] B-4. 必要素材の数と所持数が表示される
- [ ] B-5. レベルアップボタンを押すと、画面を出入りせずにその場で表示が更新される
- [ ] B-6. 素材が足りないとき、レベルアップボタンが押せない状態になっている
- [ ] B-7. レベル10のとき、案内が表示されボタンが押せない
- [ ] B-8. スキル・装備ボタンで未実装画面へ遷移する
- [ ] B-9. 戻るボタンでギルド画面へ戻る
- [ ] B-10. レベルアップ後にセーブし、再起動してもレベルとステータスが保持されている
- [ ] B-11. レベルを上げたキャラで戦闘に入ると、育成後のステータスで戦う（F3のデバッグパネルでhp/atkを確認する）
- [ ] B-12. ステージクリア後、`training_material`が増えている

**B-11とB-12が通れば「素材の使い道」が閉じる。ここがこのタスクの本題。**

---

## 9. 【人間向け】`starting_materials`に初期素材を入れる手順

`InitialStateConfig.starting_materials`は型指定のない`Dictionary`。Godot 4のInspectorでの操作が分かりにくいので手順を分けて書く。

**なぜ入れるのか**：これが無いと、育成画面を触るたびに戦闘を1回勝つ必要がある。検証の回転が落ちる。**リリース前に0へ戻す。**

### 手順

1. Godotエディタで`res://resources/balance/initial_state_config.tres`を**クリックして選択**する。ダブルクリックしない
2. Inspectorに`Starting Materials`という項目が出る。左の三角を開く
3. 既存の項目に`construction_material`があるはず。**その値は変えない**
4. `Add Key/Value Pair`（または`+`）を押す
5. 追加された行の**キー側**の型ドロップダウンを`String`にし、`training_material`と入力する
6. **値側**の型ドロップダウンを`int`にし、`50`と入力する
   - **ここが一番間違えやすい。** `float`のままだと`50.0`が入る。`add_material()`が`int()`で包むので即座には壊れないが、セーブに`50.0`と書かれる
7. Inspector上部（`.tres`名の横）に変更マークが出ていることを確認する
8. **`Ctrl+S`で保存する。** 保存しないと反映されない

### 反映されたことをどう確認するか

**`_ready()`の`print`には`materials`が含まれていない。** 出力に素材が出ないのは正常であり、失敗の証拠にはならない。

| 時期 | 確認方法 |
|---|---|
| **§5より前** | 拠点画面でセーブし、`user://saves/save_slot_0.json`をテキストエディタで開いて`materials`に`training_material`があるか見る |
| **§5より後** | 起動時のログに`materials={...}`が出る（§5-3で`print`に追加する） |

セーブファイルの実際の場所（Windows）：
`%APPDATA%\Godot\app_userdata\<プロジェクト名>\saves\save_slot_0.json`

### 反映されないときの切り分け

**推測で断定しない。順に見る。**

| 症状 | 見るところ |
|---|---|
| セーブに`training_material`が無い | **セーブデータが既にあると`initial_state`は使われない。** `save_slot_0.json`を削除して新規開始する |
| `Starting Materials`がInspectorに出ない | `initial_state_config.tres`ではなく別の`.tres`を選んでいる。`balance.tscn`の`initial_state`欄が指す先を確認する |
| 値が`50.0`になっている | 手順6の型指定。その行を削除して入れ直す |

**セーブデータの存在が一番よくある原因。** `SaveManager.has_save()`が`true`だと`_init_from_config()`はそもそも呼ばれない。

---

## 10. 実装役への報告要求

**プロンプト（`PROMPT_IMPL.md`【C】）に以下を必ず含めること。**

1. 実機未検証と正直に書いてよい。埋めなくてよい
2. 未実装と書いてよい。できなかったと報告するのは失敗ではない
3. 1ファイルへの書き込みが2回失敗したら中止。1つの症状に試す方法は2つまで（方法を変えても回数に数える）
4. 変更・作成したファイルの一覧を表で報告する
5. **B章は転記だけして、検証しないでください**
6. **§5のファイル（`game_manager.gd` / `growth_formula.gd` / `character_config.gd` / `workshop_config.gd`）には触らないでください**
