# 【作戦計画書】ギルド - 研究（実コード突き合わせ済み・改訂版）

**状態：✅ 実装完了。** 第3層は`EXEC_GUILD_RESEARCH.md`。実装後の差分は§12。

第2層・作戦計画。**旧版は実コードを見ずに書かれていたため全面改訂した。** 改訂の根拠は§0。

対応する第3層は`EXEC_GUILD_RESEARCH.md`（未執筆）。直前のタスクの型は`EXEC_GUILD_TRAINING.md`。

---

## 0. 旧版からの変更点（実コードとのズレ）

**突き合わせた実コード**：`game_manager.gd`（884行）/ `state_keys.gd` / `balance.gd` / `character_config.gd` / `training_screen.gd` / `training_screen.tscn` / `primary_button.gd`

| # | 旧版の記述 | 実際 | 対応 |
|---|---|---|---|
| **1** | §4「`unlock_research_node`は対応済み」 | **空実装。常に`false`を返す**（`game_manager.gd` 669行） | **§4を全面書き換え。本実装がこのタスクの中心。** |
| **2** | §3 状態のキー名 | `NEXT_STEPS.md`は`RESEARCH_UNLOCKED`等と書いているが、実際の定数は`NODE_UNLOCKED` / `NODE_EFFECT_TYPE` / `NODE_EFFECT_VALUE` / `NODE_PREREQUISITES` | §3の表記を実定数に合わせた |
| **3** | §3 JSONに`target_stat`が無い | `state_keys.gd`に`NODE_TARGET_STAT`があり、**`get_stat_boost_all()`が既に読んでいる**（702行） | §3に追加。`DATA_SCHEMA.md` 4-4も要追記（§9） |
| **4** | ノード定義の出所を書いていない | `_empty_state_template()`の`RESEARCH_TREE`は`{}`。**マスターデータから流し込む処理がどこにも無い。空のままでは何も表示できない** | §5に同期処理を新設 |
| **5** | §4「必要素材は`Balance`の`ResearchConfig`で定義」 | ノードごとにコストが違うため`.tres`の単一値では表せない。`ResearchConfig`の中身も未確認 | §6でコストを`research.json`側へ移した |
| **6** | シグナルの記述なし | 育成は`character_growth_changed`で画面を更新している。研究に相当するシグナルが無い | §4にシグナル追加を明記 |
| **7** | — | `_copy_dict()`は`.duplicate()`（**浅いコピー**）。ノードのDictionaryは参照が共有される | §4-3に注意として明記 |

**旧版§7の完了条件4項目のうち、3・4は実コードで既に満たされている。** 残るのは1・2（＝解放処理そのもの）。

---

## 1. スコープ

### 含む
- `research.json`（新規マスターデータ）によるノード定義
- 起動時・ロード時に`research_tree`をマスターデータと同期する処理
- **`unlock_research_node()`の本実装**（前提判定・素材消費・シグナル発火）
- 研究画面（縦1列のリスト表示・解放操作）
- ギルド画面からの導線差し替え

### 含まない
- ツリーの分岐表示・線の描画（縦1列で始める。あとから足せる）
- ノードの解放取り消し
- 育成画面側の変更（**1行も要らない。`get_effective_level_cap()`が既に参照している**）
- 戦闘側の変更（`get_effective_stats()`が既に`get_stat_boost_all()`を呼んでいる）

---

## 2. 画面構成

- 遷移元：ギルド画面（`guild_screen.gd`の`"research"`を`PLACEHOLDER_PATH`から差し替え）
- **1画面・スクロールのみ。詳細画面は作らない。**

育成画面は一覧⇄詳細を1シーンで切り替える形だが、研究はノードあたりの情報量が少ない（名前・効果・コスト・状態の4つ）ため、リストに全部載せてよい。

> **育成で出た不具合を持ち込まない。** 育成では詳細に`ToListButton`、外側に`BackButton`があり、詳細表示時に戻るボタンが2つ並んだ。研究は詳細を作らないので`BackButton`1つだけになる。

```
ResearchScreen (Control)
├── Background (ColorRect)
└── Margin (MarginContainer)
	└── Layout (VBoxContainer)
		├── TitleLabel (Label)
		├── MaterialLabel (Label)        所持素材
		├── CapLabel (Label)             現在の実効レベル上限
		├── Scroll (ScrollContainer)
		│   └── NodeList (VBoxContainer) ノード行をコードで生成
		├── NoticeLabel (Label)
		└── BackButton (PrimaryButton)
```

**`CapLabel`を置くのが要点。** 「解放したら上限がいくつになったか」がその場で見えないと、研究の手応えが育成画面まで行かないと分からない。

---

## 3. データ

### 3-1. 状態（`GameManager._state.research_tree`）

```json
{
  "research_tree": {
	"node_id": {
	  "unlocked": false,
	  "effect_type": "level_cap_unlock | stat_boost_all",
	  "effect_value": 0,
	  "target_stat": "all",
	  "prerequisites": ["node_id"]
	}
  }
}
```

- キーはすべて`GameStateKeys`の`NODE_*`定数経由で書く（`state_keys.gd`に既存。**追加不要**）
- `target_stat`は省略可。省略時は`"all"`として扱われ、`get_effective_stats()`が4ステータス全部に加算する（`game_manager.gd` 511-517行）
- `effect_type`に入る値は`EFFECT_LEVEL_CAP_UNLOCK` / `EFFECT_STAT_BOOST_ALL`

### 3-2. マスターデータ（`res://resources/balance/master/research.json`・新規）

```json
{
  "res_cap_1": {
	"name_key": "ui_research_cap_1",
	"effect_type": "level_cap_unlock",
	"effect_value": 5,
	"prerequisites": [],
	"cost_material_id": "construction_material",
	"cost_amount": 20,
	"sort_order": 1
  }
}
```

`unlocked`は**マスターデータに書かない。** 状態側だけが持つ。

`sort_order`を持たせるのは、表示順をDictionaryの列挙順に頼らないため。

### 3-3. 状態とマスターの関係

`get_effective_level_cap()`は`_state`の`effect_type` / `effect_value`を読む（689-690行）ため、**状態側にも効果値の複製が必要**。ただし`research.json`を正としてこうする：

- 起動時・ロード時に`research.json`の内容を`research_tree`へ流し込む
- **`unlocked`だけは既存の値を残す。** それ以外（`effect_type` / `effect_value` / `target_stat` / `prerequisites`）は毎回マスターで上書きする

これで効果値を調整したとき、**既存セーブにも次の起動で反映される。** `initial_state_config.tres`を編集してもセーブがあると反映されない罠（`EXEC_GUILD_TRAINING.md` §9）を、研究では最初から踏まない形にする。

---

## 4. GameManagerへの変更

**旧版の「対応済み」は誤り。** 実際に必要な変更は以下。

| 対象 | 状態 | 内容 |
|---|---|---|
| `get_research_tree()` | ✅ 実装済み | 変更なし |
| `get_effective_level_cap(id)` | ✅ 実装済み | **変更なし。** `base_level_cap` + 解放済みノード合計 |
| `get_stat_boost_all()` | ✅ 実装済み | **変更なし** |
| `unlock_research_node(id)` | ❌ **空実装** | **本実装する（§4-3）** |
| `get_research_unlock_cost(id)` | ❌ 無い | **新規。** `{material_id, amount}`を返す。育成の`get_level_up_cost()`と同じ形 |
| `can_unlock_research_node(id)` | ❌ 無い | **新規。** 前提が全部解放済みかを返す（画面のボタン活性判定用） |
| `_sync_research_tree_from_master()` | ❌ 無い | **新規（private）。** §3-3の流し込み |
| `research_node_unlocked(node_id)` | ❌ 無い | **シグナル追加。** 育成の`character_growth_changed`に対応 |
| `_ready()` | — | 末尾で`_sync_research_tree_from_master()`を呼ぶ |
| `load_state()` | — | `_state`反映後に`_sync_research_tree_from_master()`を呼ぶ |

### 4-1. コスト定数の公開

育成が`LEVEL_UP_COST_MATERIAL_ID` / `LEVEL_UP_COST_AMOUNT`を`const`で公開しているのと同じ形にする。呼び出し側が文字列リテラルを書かなくて済む。

```gdscript
const RESEARCH_COST_MATERIAL_ID: String = "material_id"
const RESEARCH_COST_AMOUNT: String = "amount"
```

### 4-2. `MasterDataLoader`

`research.json`を読む関数が要る。**現在の`MasterDataLoader`には`get_character()` / `get_stage()`しか確認できていない。** 実ファイルを見ないとどちらか確定できない：

- (a) `get_research_node(id)` / `get_all_research_nodes()`を追記する
- (b) 汎用のファイル指定APIが既にあれば、それを使う

**EXECを書く前に`master_data_loader.gd`を読むこと**（§10）。

> `MasterDataLoader`が返す数値は**`float`**（`EXEC_GUILD_TRAINING.md` §2-1）。`effect_value`・`cost_amount`は**必ず`int()`で包む**。包み忘れると`research_tree`に`5.0`が保存され、レベル上限が`15.0`になる。

### 4-3. `unlock_research_node()`の判定順

```
1. ノードが research_tree に存在するか        → 無ければ false（push_warning）
2. 既に unlocked か                           → true なら false（二重消費の防止）
3. prerequisites が全て unlocked か           → 1つでも false なら false
4. get_material_count() >= cost_amount か     → 足りなければ false
--- ここまで通ってから初めて状態を変える ---
5. add_material(material_id, -amount)
6. unlocked = true にして _state へ代入し直す
7. research_node_unlocked.emit(node_id)
```

**3と4の順序を入れ替えない。** 前提未解放のノードで素材判定に入ると、画面側の表示（「素材不足」なのか「前提未解放」なのか）と食い違う。

**注意（実コードから）**

- `add_material()`は残高を確認しない。**必ず4で確認してから減算する**（`game_manager.gd` 168行）
- **`_copy_dict()`は浅いコピー。** `_copy_dict(RESEARCH_TREE)`で取り出しても、中のノードDictionaryは`_state`と同じ実体を指す。ノードを書き換えるときは`(tree[node_id] as Dictionary).duplicate(true)`でもう一段複製してから変更し、`tree`に入れ直す。`level_up_character()`が`get_character_growth()`（複製を返す）を経由しているのと同じ理由
- `_state`のネストを直接書き換えない（`AGENTS.md`「状態アクセスのルール」）

---

## 5. UIロジック

各ノード行の状態は3つ。**育成と同じく「押せてから失敗する」より「押せない」を選ぶ。**

| 状態 | 表示 | ボタン |
|---|---|---|
| 前提未解放 | 効果とコストを出す。前提ノード名を添える | `disabled = true` |
| 解放可能 | 効果・コスト・所持数 | `disabled = false` |
| 素材不足 | 同上（所持数で分かる） | `disabled = true` |
| 解放済み | 効果のみ。達成表示 | `disabled = true` |

- ノード押下 → `Modal.confirm`で確認 → `unlock_research_node()`
- **戻り値は見ない。** 成功なら`research_node_unlocked`シグナルで引き直す（育成の`_on_character_growth_changed`と同じ経路）
- `GameManager.material_changed`にも接続する。戦闘報酬で素材が増えたときに追従させるため
- 表示テキストはすべて`tr()`。生の日本語を書かない

---

## 6. 数値（第1弾）

**ここは人間が決める。以下は根拠つきの推奨値。**

### 6-1. ノード構成：縦1列・5ノード

| node_id | effect_type | effect_value | prerequisites | コスト |
|---|---|---|---|---|
| `res_cap_1` | `level_cap_unlock` | 5 | （なし） | `construction_material` 20 |
| `res_cap_2` | `level_cap_unlock` | 5 | `res_cap_1` | `construction_material` 40 |
| `res_cap_3` | `level_cap_unlock` | 5 | `res_cap_2` | `construction_material` 70 |
| `res_cap_4` | `level_cap_unlock` | 5 | `res_cap_3` | `construction_material` 110 |
| `res_stat_1` | `stat_boost_all` | 3 | `res_cap_1` | `construction_material` 30 |

実効上限は 10 → 15 → 20 → 25 → **30**。

### 6-2. 刻み幅は+10ではなく+5

`character_config.tres`の`level_up_cost_formula`は`base + growth * (level - 1)`、`base_level_up_cost = 3`・`cost_growth_per_level = 1.0`。したがってレベル`L`から1つ上げるコストは`training_material`が`L + 2`個。

| 区間 | 必要な`training_material`合計 |
|---|---|
| Lv10 → 15 | 12+13+14+15+16 = **70** |
| Lv15 → 20 | 17+18+19+20+21 = **95** |

ステージ3の`training_material`が1周6個なので、**1ノード解放ぶんの育成に12周前後**かかる。**+10にすると1ノードで25周相当になり、ノードを解放した実感が薄れる。** +5なら4ノードで段階が4回来る。

### 6-3. コスト素材は`construction_material`

`training_material`ではなく`construction_material`を使う。理由：

- **`construction_material`には現在いっさい出口が無い。** ステージ報酬で溜まる一方
- `training_material`を研究にも使うと、**レベルを上げるか上限を上げるかで同じ素材を奪い合う。** 上限を解放しても上げる素材が無い、という状態が起きる
- 蛇口と出口が1対1で対応し、どちらの素材が足りていないかが分かりやすい

> ただし`construction_material`は本来「拠点の建設」の名前。**後で作業場・拠点拡張と競合する可能性がある。** 専用の`research_material`を新設する案もあるが、ステージ報酬への追加（`stages.json`）が必要になる。**人間の判断項目。**

### 6-4. `stat_boost_all`を1つだけ含める

`get_stat_boost_all()`は本実装済みで、`get_effective_stats()`が既に呼んでいる。**ノードを1つ足すだけで検証できる。** `target_stat`を省略して`"all"`にすれば、hp/atk/def/spd 全部に+3。

「検証できないものは作らない」に反しない。**効果が育成画面のステータス表示に即出る**ため、むしろ`target_stat`の経路を1回通しておく価値がある。

---

## 7. 完了条件A章：`print`で確認する

- [ ] A-1. 起動直後に`get_research_tree()`が5ノードを返し、全て`unlocked: false`
- [ ] A-2. A-1の各ノードの`effect_value`が`typeof()`で`TYPE_INT`（`5.0`ではない）
- [ ] A-3. `get_effective_level_cap("char_swordsman")`が`10`を返す（未解放時）
- [ ] A-4. `unlock_research_node("res_cap_2")`が`false`を返す（前提`res_cap_1`が未解放）。素材が減らない
- [ ] A-5. 素材不足の状態で`unlock_research_node("res_cap_1")`が`false`。素材が減らない
- [ ] A-6. 素材が足りる状態で`unlock_research_node("res_cap_1")`が`true`。`unlocked: true`になる
- [ ] A-7. A-6の後、`get_material_count("construction_material")`が`cost_amount`だけ減っている
- [ ] A-8. A-6の後、`get_effective_level_cap("char_swordsman")`が`15`を返す
- [ ] A-9. A-6の直後にもう一度`unlock_research_node("res_cap_1")`を呼ぶと`false`。**素材が二重に減らない**
- [ ] A-10. `res_cap_1`解放後は`unlock_research_node("res_cap_2")`が素材次第で`true`になる
- [ ] A-11. `res_stat_1`を解放すると`get_stat_boost_all()`が`{"all": 3}`を返す
- [ ] A-12. A-11の後、`get_effective_stats("char_swordsman")`の4項目がそれぞれ+3されている
- [ ] A-13. 存在しない`node_id`を渡しても`false`が返るだけでクラッシュしない
- [ ] A-14. `research.json`の`effect_value`を5から7に書き換えて再起動すると、**既存セーブでも**`get_effective_level_cap()`が`17`になる（§3-3の同期）
- [ ] A-15. A-14の再起動後も、解放済みノードの`unlocked`が`true`のまま残っている

**A-14とA-15が同期処理の本体。** 片方だけ通っても意味がない。

---

## 8. 完了条件B章：人間が実機で確認する

**実装役はここを転記するだけ。検証しないこと。**

- [ ] B-1. ギルド画面の「研究」ボタンから研究画面へ遷移する
- [ ] B-2. ノードが5つ、縦に並んで表示される
- [ ] B-3. 各ノードに効果・コスト・所持数が出ている
- [ ] B-4. 前提未解放のノードのボタンが押せない状態になっている
- [ ] B-5. 素材が足りないノードのボタンが押せない状態になっている
- [ ] B-6. 解放可能なノードを押すと確認モーダルが出る
- [ ] B-7. 解放すると、**画面を出入りせずに**その場で表示が「解放済み」に変わる
- [ ] B-8. 同時に`CapLabel`の実効レベル上限が更新される
- [ ] B-9. 同時に所持素材の表示が減っている
- [ ] B-10. 次のノードが「解放可能」に変わっている
- [ ] B-11. 戻るボタンでギルド画面へ戻る。**戻るボタンが2つ並んでいない**
- [ ] B-12. 育成画面へ行くと、レベル10のキャラが**さらにレベルを上げられる**
- [ ] B-13. `res_stat_1`解放後、育成画面のステータス4項目がそれぞれ+3されて表示される
- [ ] B-14. セーブして再起動しても解放状態が保持されている

**B-12がこのタスクの本題。** 育成の詰まりが解けたことがここでしか確認できない。

---

## 9. 併せて直すもの

| ファイル | 内容 |
|---|---|
| `DATA_SCHEMA.md` 4-4 | `target_stat`を追記。**実コードにあるのにスキーマに無い** |
| `AGENTS.md`「GameManagerのシグナル」 | `research_node_unlocked`を追記。**`character_growth_changed`も未追記のまま**（`EXEC_GUILD_TRAINING.md` §5-5の積み残し）。2つまとめて足す |
| `PROJECT_STATUS.md` | 研究完了後に「次にやること」を更新 |

---

## 10. EXECを書く前に読む必要があるファイル

**今回の突き合わせで、以下が未確認のまま残っている。EXEC執筆前に実物を見ること。**

| ファイル | 何を確認するか |
|---|---|
| `autoload/master_data_loader.gd` | **§4-2の分岐がここで決まる。** JSONの読み込み方・キャッシュの持ち方・`get_*`の命名 |
| `scenes/guild/guild_screen.gd` / `.tscn` | `"research"`の遷移先差し替え箇所。育成と同じ`_go_to_sub()`の分岐か |
| `resources/balance/research_config.gd` | `balance.gd`が`@export var research: ResearchConfig`を持っている。**中身が未確認。** §6-3でコストをJSONへ移したので、使わないなら空のままでよいか判断する |
| `resources/balance/master/*.json`のどれか1つ | `research.json`の書式（インデント・キー順）を既存に揃えるため |
| `scripts/utils/modal.gd` | `Modal.confirm`の戻り値の受け方（`await`か、コールバックか） |

**`guild_screen.gd`は`NEXT_STEPS.md`で「渡す」と指定されていたが、今回の資料に含まれていなかった。**

---

## 11. 誰が書くか

`NEXT_STEPS.md`の判断どおり、**設計役が`.gd`を全部書く。**

| 誰 | ファイル |
|---|---|
| **人間** | `ja.csv` / `guild_screen.gd`の1行差し替え / §6の数値決定 |
| **設計役** | `game_manager.gd`（884行・全文差し替え） / `master_data_loader.gd` / `research_screen.gd` |
| **実装役** | `research.json` / `research_screen.tscn` |

`game_manager.gd`は884行で、§4の変更が5箇所に散る。**原本をコピーして該当箇所だけ差し替える方式で、設計役が全文を出す。** 育成のとき（691行）はこの方式で事故がゼロだった。

---

## 12. 実装後にこの計画から変わった点

| 項目 | 計画 | 実装 |
|---|---|---|
| ノード数 | 5（`res_cap_1`〜`4` ＋ `res_stat_1`） | 同じ |
| `res_stat_1`の前提 | 記載なし | `res_cap_1`。`res_cap_2`と並列に置き、1本道でないことを見せた |
| 解放の確認モーダル | §5に「`Modal.confirm`で確認」 | **入れていない。** `modal.gd`のAPIが未確認のため。育成と同じくボタンの活性で防ぐ。宿題として残した |
| 完了条件の分け方 | A章／B章 | **ログ／画面／同期の3つ。** 実装役を使わない体制ではA章／B章が機能せず、16項目中10項目が重複した |
| `MasterDataLoader` | (a)追記か(b)既存API利用か未確定 | **(a)。** `get_research_node()` / `get_all_research_nodes()`を末尾追記 |
| `ResearchConfig` | 使うか未確定 | **使わない。** コストは`research.json`に持たせた。`balance.gd`の`@export`は空のまま |

**§6の数値はそのまま採用した。** 変更なし。
