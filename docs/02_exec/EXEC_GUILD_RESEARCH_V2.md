# 【実行指示書】研究ボードの作り替え（段階10）

**状態：着手中（2026-08-25）。** 第3層。仕様の正は `GAME_DESIGN.md` 9-1。前身は `EXEC_GUILD_RESEARCH.md`（第1弾＝レベル上限の解放）。

| 誰 | 担当 |
|---|---|
| **設計役** | `research.json` / `game_manager.gd` / `master_data_loader.gd` / `research_screen.gd` / `state_keys.gd` / `debug_boot.gd` / `debug_overlay.gd` / `ja.csv` |
| **人間** | ⚠ **`ja.csv` の再インポート**（設計役にはできない）／ ⚠ **§9 の画面確認** |
| **実装役（Ziva）** | ⚠ **§8 に切り出した「JSON と ja.csv だけ」の部分は渡せる形にしてある**（渡さず設計役が書いてもよい） |

`.tres` の編集は**不要**。⚠ **`base_level_cap` / `max_character_level` は `character_config.gd` の `@export` 既定値が効いている**（`.tres` に書き出されていない。`EXEC_CHARACTER_PASSIVES.md` §4-3 で実測済み）。

---

## 1. 人間の決定（2026-08-25・このタスクの前に取った）

| # | 決めたこと |
|---|---|
| **1** | ⚠ **枝は「戦闘」と「宝箱」の2本。⚠ ただし後から足しやすい形にする**（⚠ **作業場枝は段階11＝作業場の復活と同時**） |
| **2** | ⚠ **効果の種類は既存2つのまま＋`target_stat` を活用する**（⚠ **宝箱枝のぶんだけ1つ足す。§2 の自己決定1**） |
| **3** | ⚠ **レベル上限は 8件 × +10**（⚠ **`base_level_cap` 20 ＋ 80 ＝ ちょうど 100**） |
| **4** | ⚠ **「1周クリアで次のボードに切り替わる」を今回入れる** |

⚠ **決定1で `NEXT_STEPS` §1-2 の推奨（戦闘 / 生産 / 探索）は採らなかった。** ⚠ **`GAME_DESIGN` 9-1 のカテゴリ名（戦闘 / 作業場 / 宝箱）が正**（`NEXT_STEPS` §2-2 の型）。

---

## 2. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め**）

| # | 決めたこと | なぜ |
|---|---|---|
| **1** | ⚠ **新しい `effect_type` は `chest_draw_bonus` の1つだけ**（⚠ **抽選回数 +N**） | ⚠ **決定1で宝箱枝を作る以上、宝箱に効く効果が1つも無いと枝が空になる。⚠ ドロップ率・高等級確率（`weight`）は入れない＝`_roll_chest_draw()` の1行に乗るものだけ** |
| **2** | ⚠ **ボードは「マスターの欄」で表す。⚠ 状態にキーを1つも足さない** | ⚠ **`board` / `category` / `milestone` を `research.json` のノードに足し、⚠ 「今どのボードか」は都度計算する**（＝未解放ノードを持つ最小のボード）。⚠ **`_sync_research_tree_from_master()` の型（進捗だけ状態）を崩さない。⚠ セーブの移行が要らない** |
| **3** | ⚠ **ボードは2枚。⚠ ボード1に上限8件を全部載せる** | ⚠ **上限を2周目に散らすと、⚠ パッシブの Lv100 がボード2クリアまで永久に来ない。⚠ 3枚目以降は JSON に足すだけ** |
| **4** | ⚠ **ノードIDは1つも改名しない。⚠ `res_cap_1..4` と `res_stat_1` は再利用**（⚠ **`res_cap_1..4` の `effect_value` は 20 → 10**） | ⚠ **`_sync_research_tree_from_master()` はマスターから消えたIDの進捗を捨てる**（`NEXT_STEPS` §1-3） |
| **5** | ⚠ **コスト素材を `construction_material_1..3` に分散し、⚠ ボード2の終盤だけ `_4`** | ⚠ **`GAME_DESIGN` 9-1「ノードごとに要求する種類を変えて競合を分散させる」。⚠ 入手経路を確かめた**：`_1`＝stage_1..2 ／ `_2`＝stage_2..3 ／ `_3`＝stage_3 ／ ⚠ **`_4` は月替わりショップだけ**（⚠ **だから最後の2件にしか置かない**） |
| **6** | ⚠ **ゴールド払いは入れない** | ⚠ **`unlock_research_node()` は素材1種類だけを見る形。⚠ 通貨を足すと判定と画面が両方増える。⚠ `GAME_DESIGN` 9-1「コストはゴールドと各種資源」の未達として §10 の宿題に載せる** |
| **7** | ⚠ **新しい検証を2本足す（`E127` / `E128`）** | ⚠ **`E127`＝上限の合計が 100 でない ／ `E128`＝前提が存在しない or 後のボードを指している。⚠ どちらも「赤も黄も出ずに詰む」形の穴**（§6） |
| **8** | ⚠ **`scenario=research` を1本足す**（`kind: "report"`） | ⚠ **ボードの切り替えと実効上限は画面を見なくても数字で取れる。⚠ 28本になる**（⚠ **`training` を除いて回すのは28本**） |
| **9** | ⚠ **研究画面のヘッダの素材表示を「そのボードで使う素材を全部」に変える** | ⚠ **`_primary_material_id()` は「研究で使う素材が1種類である前提」で書かれている。⚠ 自己決定5でその前提が消える** |
| **10** | ⚠ **`RESEARCH_MAX_PASSES`（F4）を定数からノード数基準に変える** | ⚠ **20 固定。⚠ ボードを足すと前提の連なりが 20 を超えうる**（⚠ **超えると「F4 を押したのに全部解放されない」形で無音に壊れる**） |

---

## 3. ⚠ 変えないもの（**触ると黙って壊れる**）

- ⚠ **`base_level_cap`（20）＋ 全 `level_cap_unlock` の合計 ＝ `max_character_level`（100）。⚠ `E127` で恒久的に見張る**
- ⚠ **ノードIDを改名しない**（自己決定4）
- ⚠ **素材IDは `<系統>_material_<1..4>`。⚠ 新しい素材を作らない**
- ⚠ **`unlock_research_node()` が解放の唯一の口。⚠ 2本目を作らない**
- ⚠ **`_sync_research_tree_from_master()` の型**（進捗だけ残し、定義は毎回上書き）
- ⚠ **状態を変える前に全部の判定を終える**（`CLAUDE.md` 6番）。⚠ **ボードの判定は素材の判定より前・状態を触る前**
- ⚠ **`MasterDataLoader` が返す数値は `float`。⚠ `int()` で包む**
- ⚠ **再描画に `await` を持たせない**（`remove_child()` → `queue_free()`）

---

## 4. ノード構成（**18件・2ボード**）

⚠ **`level_cap_unlock` は 8件 × +10 ＝ 80。⚠ 20 ＋ 80 ＝ 100。**

### 4-1. ボード1「戦いの基礎」（12件）

| sort | node_id | cat | 効果 | 前提 | コスト | 印 |
|---|---|---|---|---|---|---|
| 1 | `res_cap_1` | combat | 上限 +10 | — | `construction_material_1` x20 | |
| 2 | `res_stat_1` | combat | 全ステ +3 | `res_cap_1` | `construction_material_1` x30 | |
| 3 | `res_cap_2` | combat | 上限 +10 | `res_cap_1` | `construction_material_1` x40 | |
| 4 | `res_cap_3` | combat | 上限 +10 | `res_cap_2` | `construction_material_1` x70 | |
| 5 | `res_stat_atk_1` | combat | `atk` +8 | `res_cap_2` | `construction_material_2` x10 | |
| 6 | `res_cap_4` | combat | 上限 +10 | `res_cap_3` | `construction_material_1` x110 | |
| 7 | `res_stat_2` | combat | 全ステ +5 | `res_cap_4` | `construction_material_2` x25 | ⚠ **中間** |
| 8 | `res_cap_5` | combat | 上限 +10 | `res_stat_2` | `construction_material_2` x40 | |
| 9 | `res_cap_6` | combat | 上限 +10 | `res_cap_5` | `construction_material_2` x70 | |
| 10 | `res_cap_7` | combat | 上限 +10 | `res_cap_6` | `construction_material_3` x20 | |
| 11 | `res_cap_8` | combat | 上限 +10 | `res_cap_7` | `construction_material_3` x40 | ⚠ **最後** |
| 12 | `res_chest_1` | chest | 抽選回数 +1 | `res_stat_2` | `construction_material_2` x30 | |

⚠ **`sort_order` はカテゴリの中の並び。⚠ 画面は `category` → `sort_order` の順に並べるので、⚠ 宝箱枝の1件は戦闘枝の12件の下に出る。**

⚠ **`res_stat_2` を中間に置いたのは、⚠ ここが Lv60（上限 +40 まで済み）に当たるため。**
⚠ **`res_cap_8` を最後に置くと、⚠ ボード1のクリア＝Lv100 到達＝パッシブが全部揃う。**

### 4-2. ボード2「深める研究」（6件）

⚠ **上限ノードを1件も置かない**（自己決定3）。

| sort | node_id | cat | 効果 | 前提 | コスト | 印 |
|---|---|---|---|---|---|---|
| 1 | `res2_stat_hp_1` | combat | `hp` +30 | — | `construction_material_2` x60 | |
| 2 | `res2_stat_def_1` | combat | `def` +8 | `res2_stat_hp_1` | `construction_material_3` x30 | |
| 3 | `res2_chest_1` | chest | 抽選回数 +1 | `res2_stat_hp_1` | `construction_material_3` x40 | |
| 4 | `res2_stat_3` | combat | 全ステ +8 | `res2_stat_def_1` | `construction_material_3` x60 | ⚠ **中間** |
| 5 | `res2_stat_crit_1` | combat | `crit_rate` +5 | `res2_stat_3` | `construction_material_4` x15 | |
| 6 | `res2_stat_4` | combat | 全ステ +10 | `res2_stat_crit_1` | `construction_material_4` x30 | ⚠ **最後** |

⚠ **効果量は全部「勘」。⚠ 段階12（バランス実測）で見る。⚠ 宿題22 に1行足す。**

### 4-3. ボードの切り替え規則

- ⚠ **ボードNは、⚠ ボードN-1 の全ノードが解放されるまで「出さない・解放できない」**
- ⚠ **「今のボード」＝ 未解放ノードを持つ最小の `board`。⚠ 全部解放済みなら最大の `board`**
- ⚠ **状態には持たない**（自己決定2）

---

## 5. 実装（**7ファイル**）

### 5-A. `resources/balance/master/research.json`（全文差し替え）

§4 の18件。⚠ **足す欄は `board`（int）・`category`（String）・`milestone`（`""` / `"mid"` / `"final"`）の3つ。**
⚠ **`unlocked` は書かない**（状態側だけが持つ）。⚠ **インデントはタブ。**

### 5-B. `scripts/utils/state_keys.gd`

- ⚠ **`EFFECT_CHEST_DRAW_BONUS: String = "chest_draw_bonus"` を1行足す**（`EFFECT_STAT_BOOST_ALL` の隣）
- ⚠ **状態のキーは1つも増えない**（自己決定2）。⚠ **`AGENTS.md` の表は直さない**

### 5-C. `autoload/game_manager.gd`

| 対象 | 内容 |
|---|---|
| `RESEARCH_NODE_BOARD` / `_CATEGORY` / `_MILESTONE` | ⚠ **定数追加**（`RESEARCH_NODE_COST_*` の隣。⚠ マスター側のキーなので `GameStateKeys` には置かない） |
| `get_research_board_of(node_id)` | ⚠ **新規。⚠ ボード番号を引く唯一の口** |
| `get_current_research_board()` | ⚠ **新規。§4-3 の規則** |
| `is_research_board_open(board)` | ⚠ **新規。`board <= get_current_research_board()`** |
| `unlock_research_node()` | ⚠ **判定を1つ足す**（下記） |
| `get_research_chest_draw_bonus()` | ⚠ **新規。解放済み `chest_draw_bonus` の合計** |
| `_roll_chest_draw()` | ⚠ **`rolls` に上の戻り値を足す1行だけ**（⚠ **抽選の本体は触らない**） |
| `_validate_level_cap_total()` | ⚠ **新規（`E127`）。`_ready()` の `_sync_research_tree_from_master()` の直後に呼ぶ** |

**`unlock_research_node()` の判定順（⚠ 状態を触る前に全部終える）**

```
1. ノードが research_tree に存在するか      → 無ければ false
2. 既に unlocked か                          → true なら false
3. ⚠ ボードが開いているか（新規）            → 閉じていれば false
4. prerequisites が全て unlocked か           → false なら false
5. 素材が足りているか                        → 足りなければ false
--- ここから状態を変える ---
6. unlocked = true にして _state へ代入し直す
7. add_material(material_id, -amount)
8. research_node_unlocked.emit(node_id)
```

⚠ **3を4より先に置く。** ⚠ **前提を満たしていてもボードが閉じていれば解放できない、が正しい順**（⚠ **逆にすると「前提は済んでいるのに素材不足と出る」に戻る**）。

### 5-D. `scripts/systems/master_data_loader.gd`

⚠ **`_validate_all_item_refs()` の `research.json` の枝に `E128` を足す**（⚠ **`cost_material_id` を見ている既存のループの中。⚠ 2本目のループを作らない**）。

| 番号 | 出す条件 | 色 |
|---|---|---|
| **`E128`** | ⚠ **`prerequisites` のIDが `research.json` に無い** ／ ⚠ **前提が自分より後のボードにある** ／ ⚠ **`board` が1未満** | 赤 |

⚠ **理由：どちらも「押せないノードが1件出るだけ」で赤も黄も出ずに詰む**（`GameManager._prerequisites_met()` の `push_warning` は解放を試した瞬間にしか出ない）。

### 5-E. `scenes/guild/research_screen.gd`

- ⚠ **描くのは「今のボード」のノードだけ**（§4-3）
- ⚠ **カテゴリごとに見出しを1行出す**（`ui_research_category_<category>`）。⚠ **カテゴリが増えたら見出しは自動で増える＝画面に `if` を書かない**（決定1「後から足しやすく」）
- ⚠ **中間・最後のノードに印を出す**（`ui_research_milestone_mid` / `_final`）
- ⚠ **ヘッダに「ボードN・解放 x/y」の1行を足す**（⚠ **切り替わったことが画面で分かる唯一の場所**）
- ⚠ **ヘッダの素材表示を、⚠ そのボードで使う素材の全種類に変える**（自己決定9）
- ⚠ **並びは `category` → `sort_order`。⚠ ノードIDを決め打ちしない**
- ⚠ **`_effect_text()` に `chest_draw_bonus` の枝を足す**
- ⚠ **`_build_node_list()` の作り直しを `remove_child()` → `queue_free()` にする**（⚠ **今は `queue_free()` だけ。⚠ `research_node_unlocked` と `material_changed` が1回の解放で続けて飛ぶ＝行が二重に並ぶ形**。⚠ `AGENTS.md`「再描画は await を持たせない」）

### 5-F. `localization/ja.csv`（§8-2 に全文）

⚠ **UTF-8（BOMなし・LF）。⚠ 再インポートは人間の作業。**

### 5-G. `tests/debug_boot.gd` / `tests/debug_overlay.gd`

- ⚠ **`SCENARIOS` に `research` を1本足す**（`kind: "report"`）
  - ⚠ **素材を配る → 解放できなくなるまで回す → ボードが切り替わることと実効上限を出す**
  - ⚠ **`base_level_cap` ＋ 上限ノードの合計 ＝ `max_character_level` を数字で出す**
- ⚠ **`LAYOUT_SCENES` に `res://scenes/guild/research_screen.tscn` を1行足す**（⚠ **`NEXT_STEPS` §1-3。⚠ 今まで1度も測っていない**）
- ⚠ **`RESEARCH_MAX_PASSES` をノード数基準に変える**（自己決定10）

---

## 6. ⚠ 足した検証を壊して確かめる（**2箇所ずつ**）

⚠ **`git diff` を汚さない。⚠ 壊したら必ず戻し、⚠ 平常値に戻ったことを再実行で確認する。**

| 番号 | 壊し方1 | 壊し方2 |
|---|---|---|
| **`E127`** | ⚠ **`res_cap_1` の `effect_value` を 10 → 9**（合計 99） | ⚠ **`res_cap_8` を消す**（合計 70） |
| **`E128`** | ⚠ **`res2_stat_hp_1` の前提に `res_cap_8` ではなく存在しないIDを書く** | ⚠ **`res_cap_1` の前提に `res2_stat_4`（後のボード）を書く** |

---

## 7. 完了条件

### 7-1. ログ（**設計役が取る**）

- [ ] L-1. 起動ログに `_sync_research_tree_from_master() -> 18 nodes (unlocked=0)` が出る
- [ ] L-2. ⚠ **赤の平常値0本・黄の平常値1本に戻っている**（27本＋`research`＝28本）
- [ ] L-3. ⚠ **`scenario=research` が「ボード1 → ボード2」と切り替わることを出す**
- [ ] L-4. ⚠ **`scenario=research` が `base_level_cap 20 + 上限ノード 80 = 100 / max 100 → 一致` を出す**
- [ ] L-5. ⚠ **`scenario=passives` が壊れていない**（⚠ **3キャラが Lv100・パッシブ5件ずつ**）
- [ ] L-6. ⚠ **`scenario=layout` が研究画面を測っており、⚠ 1280 x 720 を超えていない**
- [ ] L-7. ⚠ **`E127` `E128` が §6 の4通りで赤を出し、⚠ 戻すと平常値に戻る**

### 7-2. ファイル（**設計役が取る**）

- [ ] F-1. ⚠ **`save_slot_0.json` の `research_tree` が18件で、⚠ `effect_value` が `10` であって `10.0` でない**
- [ ] F-2. ⚠ **`research_tree` に `board` / `category` / `milestone` が入っていない**（⚠ **状態にキーを足していないこと**）

### 7-3. 画面（**人間だけ**）

- [ ] S-1. 研究画面に**ボード1の12件だけ**が並び、⚠ **ボード2の6件は出ていない**
- [ ] S-2. ⚠ **「戦闘」「宝箱」の見出しが出ており、⚠ 宝箱の下に1件だけ並ぶ**
- [ ] S-3. ⚠ **中間（`res_stat_2`）と最後（`res_cap_8`）に印が出ている**
- [ ] S-4. ⚠ **ヘッダに「ボード1・解放 0/12」が出ており、⚠ 1件解放すると 1/12 になる**
- [ ] S-5. ⚠ **ヘッダの素材が4種類ぶんではなく、⚠ そのボードで使う3種類（`_1` `_2` `_3`）出ている**
- [ ] S-6. ⚠ **解放すると画面を出入りせずにその場で「解放済み」に変わり、⚠ 行が二重に並ばない**
- [ ] S-7. ⚠ **`F4` →「素材を全種類」→「研究を全部解放」で18件とも解放され、⚠ 画面がボード2に切り替わる**
- [ ] S-8. ⚠ **全解放後、育成画面で Lv100 まで上げられる**
- [ ] S-9. ⚠ **上限表示が Lv.100 になっている**
- [ ] S-10. ⚠ **縦にも横にもはみ出していない**（⚠ **`scenario=layout` は `ScrollContainer` の中を測れない＝ここは人間しか見られない**）
- [ ] S-11. ⚠ **戻るボタンが1つだけで、ギルド画面へ戻る**
- [ ] S-12. ⚠ **セーブして再起動しても解放状態とボードが保たれている**

### 7-4. UIから到達できない項目（**人間は確認しない**）

| 経路 | 期待 |
|---|---|
| 閉じているボードのノードを `unlock_research_node()` | `false`。素材が減らない |
| 解放済みノードを再度 | `false`（既存） |
| 存在しない `node_id` | `false`・警告のみ（既存） |

---

## 8. ⚠ Ziva に渡せる形（**JSON と `ja.csv` だけ**）

⚠ **§8-1（`research.json` 全文）と §8-2（`ja.csv` の追記行）だけを渡せば、⚠ `.gd` を1行も触らずに済む。**
⚠ **ただし §5-C 〜 §5-G が入るまで、⚠ `board` / `category` / `milestone` は誰も読まない欄になる**（⚠ **順番は §8-3**）。

### 8-1. `research.json`

⚠ **§4 の表がそのまま中身。⚠ 実ファイルを正とする。**

### 8-2. `ja.csv` の追記（**新規21行**）

| キー | 日本語 |
|---|---|
| `ui_research_board` | ボード%d・解放 %d/%d |
| `ui_research_category_combat` | 戦闘 |
| `ui_research_category_chest` | 宝箱 |
| `ui_research_milestone_mid` | ★ 中間 |
| `ui_research_milestone_final` | ★★ 最後 |
| `ui_research_effect_stat_axis` | %s +%d |
| `ui_research_effect_chest_draw` | 宝箱の抽選回数 +%d |
| `ui_research_cap_5` | 実戦派遣 |
| `ui_research_cap_6` | 古戦場の記録 |
| `ui_research_cap_7` | 大陸の兵法書 |
| `ui_research_cap_8` | 極意の伝授 |
| `ui_research_stat_2` | 総合強化計画 |
| `ui_research_stat_atk_1` | 武器の研磨 |
| `ui_research_chest_1` | 宝箱の目利き |
| `ui_research_b2_hp_1` | 体力増強 |
| `ui_research_b2_def_1` | 防具の改良 |
| `ui_research_b2_chest_1` | 宝物庫の整理 |
| `ui_research_b2_stat_3` | 総合強化計画II |
| `ui_research_b2_crit_1` | 急所の研究 |
| `ui_research_b2_stat_4` | 総合強化計画III |
| `ui_research_locked_board` | 前のボードを全て解放すると開きます |

⚠ **`ui_res_construction_material_1..4` は既存**（⚠ **無いとキー名がそのまま出る**）。

### 8-3. 作業の順番

1. `research.json`（§8-1）
2. `state_keys.gd` の1行（§5-B）
3. `game_manager.gd`（§5-C）… ⚠ **ここまでで `scenario=research` が通る**
4. `master_data_loader.gd`（§5-D）… ⚠ **`E128`**
5. `research_screen.gd`（§5-E）
6. `ja.csv`（§8-2）→ ⚠ **人間の再インポート**
7. `debug_boot.gd` / `debug_overlay.gd`（§5-G）
8. §6（壊して確かめる）→ 全シナリオ28本

---

## 8-4. ⚠ 実施結果（**2026-08-25・設計役**）

### ログ・ファイル

| 項目 | 結果 |
|---|---|
| **L-1** | ⚠ **通った**。`_sync_research_tree_from_master() -> 18 nodes (unlocked=0)` |
| **L-2** | ⚠ **通った**。⚠ **28本すべて回した**（`training` を除く）。⚠ **赤は `unlock` の1本のみ ／ 黄は1本、⚠ `parts` `drops` だけ2本**＝平常値 |
| **L-3** | ⚠ **通った**。`最初の今のボード -> 1` → `ボード1を 12件 解放 -> 今のボード 2` |
| **L-4** | ⚠ **通った**。`base_level_cap 20 + level_cap_unlock 8件 80 = 100 / max_character_level 100 -> 一致` |
| **L-5** | ⚠ **通った**。⚠ **3キャラとも `Lv100 passives=5`（Lv20:1件 → Lv100:5件）** |
| **L-6** | ⚠ **通った**。`research_screen.tscn 最小 364 x 208（基準 1280 x 720）` |
| **L-7** | ⚠ **通った**（§6 の4通り）。⚠ **戻して再実行し、平常値に戻ったことを確認済み** |
| **F-1 / F-2** | ⚠ **未取得。⚠ 人間が1回セーブしたあとに設計役が読む**（⚠ **`debug_boot` は保存しないため、ヘッドレスでは取れない**） |

⚠ **`scenario=layout` は今この時点で赤を3本出す。⚠ `ja.csv` の再インポート待ちであり、⚠ 再インポート後は0本になる**（⚠ **`scenario=passives` の「再インポート: まだ／済んでいる」が合図**）。

### ⚠ 人間の既存セーブに起きること（**先に知らせる**）

⚠ **今のセーブは `res_cap_1..4` を解放済み。⚠ 1件あたりが +20 から +10 になるので、⚠ 実効レベル上限が 100 → 60 に下がる。**
⚠ **解放状態は失われない**（IDを改名していないため）。⚠ **`res_cap_5..8` を解放し直せば 100 に戻る。**
⚠ **既にそれより上のレベルのキャラは、レベルが下がることはない**（⚠ **上限は `level_up_character()` の入口でしか見ない**）。⚠ **上げられなくなるだけ。**

### ⚠ 途中で踏んだこと

1. ⚠ **`_report_research()` を `_report_unlock()` の途中に差し込んだ**（⚠ **末尾だと思った `print` の後ろに、まだ本体が90行あった**）。⚠ **`scenario=research` が画面IDの報告まで出したので気づいた。⚠ 関数を足すときは、次の `func` までを見てから差し込むこと**
2. ⚠ **`ja.csv` の再インポートの合図が「前の回のキー」を見ていた**（⚠ **`ui_skill_select_passive_locked`）。⚠ その回に足したキーが未インポートでも「済んでいる」と答える。⚠ 合図のキーを `ui_research_board` に差し替えた**（⚠ **ズレ37**）

---

## 9. ⚠ このタスクで残す宿題

- ⚠ **ゴールド払いが無い**（自己決定6。⚠ `GAME_DESIGN` 9-1「コストはゴールドと各種資源」の未達）
- ⚠ **作業場枝が無い**（決定1。⚠ 段階11＝作業場の復活と同時）
- ⚠ **宝箱枝が「抽選回数」だけ。⚠ ドロップ率・高等級確率（`weight`）は入れていない**
- ⚠ **ボード3以降が無い**（⚠ **JSON に足すだけで増える形にはなっている**）
- ⚠ **効果量18件が全部「勘」**（⚠ **宿題22 に足す**）
- ⚠ **`scenario=layout` は `ScrollContainer` の中を測れない**（⚠ **研究画面のはみ出しは人間しか見られない**）
- ⚠ **`Modal.confirm` による解放確認は今回も入れない**（前身 §10 から継続）
