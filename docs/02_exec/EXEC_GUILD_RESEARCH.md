# 【実行指示書】ギルド - 研究（第1弾：レベル上限の解放）

**状態：✅ 完了。** §7・§8・§8-2すべて確認済み。

第3層。対応する第2層は`PLAN_GUILD_RESEARCH.md`（実コードと突き合わせて改訂済みの版）。

**このタスクは実装役を使わない。** `.gd`・`.tscn`・`.json`はすべて設計役が全文を書いた。

| 誰 | 担当するファイル |
|---|---|
| **人間** | `ja.csv` / `guild_screen.gd`の2行差し替え / 受け取ったファイルの保存 |
| **設計役** | `game_manager.gd`（1051行）/ `master_data_loader.gd` / `research_screen.gd` / `research_screen.tscn` / `research.json` |
| **実装役** | なし |

`character_config.tres`の編集は**不要**。研究は`.tres`を1つも使わない。

---

## 1. このタスクで実現すること

`construction_material`を消費して研究ノードを解放し、**レベル上限が10から15・20・25・30へ伸びる**ところまで。

同時に、`stat_boost_all`ノードを1つ解放して**全キャラのステータスが+3される**ところまで。

ツリーの分岐表示・線の描画は**含まない**。縦1列のリスト。

---

## 2. 事故りやすい箇所（先に読むこと）

### 2-1. `research_tree`は誰も初期化していなかった

`_empty_state_template()`は`RESEARCH_TREE: {}`を入れるだけで、マスターデータから流し込む処理がどこにも無い。**このままでは画面に1つも表示されない。**

`_sync_research_tree_from_master()`を新設し、`_ready()`と`load_state()`の両方から呼ぶ。§5-1に含めてある。

### 2-2. `unlock_research_node()`は空実装だった

`PLAN_GUILD_RESEARCH.md`旧版は「対応済み」と書いていたが、実際は`print`して`false`を返すだけだった。**書き込み側は1行も無かった。** 本実装は§5-1。

### 2-3. `_copy_dict()`は浅いコピー

`game_manager.gd` 112行の`_copy_dict()`は`.duplicate()`（浅い）。`_copy_dict(RESEARCH_TREE)`で取り出しても、**中のノードDictionaryは`_state`と同じ実体を指す。**

ノードを書き換えるときは、もう一段`duplicate(true)`してから変更して入れ直す。§5-1のコードはそうなっている。

### 2-4. `MasterDataLoader`が返す数値は`float`

`effect_value`・`cost_amount`・`sort_order`は**必ず`int()`で包む。** 包み忘れると`research_tree`に`5.0`が保存され、`get_effective_level_cap()`が`15.0`を返す。

### 2-5. `add_material()`は残高を確認しない

負数を渡せばマイナスまで減る。**必ず`get_material_count()`で確認してから減算する。**

### 2-6. `state_keys.gd`は編集不要

`NODE_UNLOCKED` / `NODE_EFFECT_TYPE` / `NODE_EFFECT_VALUE` / `NODE_TARGET_STAT` / `NODE_PREREQUISITES` / `EFFECT_LEVEL_CAP_UNLOCK` / `EFFECT_STAT_BOOST_ALL`が既にそろっている。**このタスクでは1文字も触らない。**

> `NEXT_STEPS.md`は定数名を`RESEARCH_UNLOCKED`等と書いているが、実際は`NODE_*`。**`NEXT_STEPS.md`側の誤記。**

### 2-7. モーダルによる確認は入れていない

`modal.gd`の`confirm()`の待ち方（`await`か、コールバックか）が未確認のため、**育成画面と同じく確認なしで即実行**にした。ボタンは条件を満たさないと押せないため、誤操作は「押せる状態のノードを押す」ときだけ起きる。

`Modal.confirm`の使い方を確認してから、`_on_unlock_pressed()`に足すのは後からできる。**このタスクの完了条件には含めない。**

---

## 3. 人間がやる作業

### 3-1. `ja.csv`に翻訳キーを追加

**追記の前に、既にあるキーでないか`grep`で確認すること**（`AGENTS.md`「2回書かない」）。

| キー | 日本語（案） |
|---|---|
| `ui_research_title` | 研究 |
| `ui_research_cap` | 現在のレベル上限 Lv.%d |
| `ui_research_cost` | 必要素材 |
| `ui_research_owned` | 所持 |
| `ui_research_unlock` | 解放する |
| `ui_research_unlocked` | 解放済み |
| `ui_research_locked` | %s の解放が必要です |
| `ui_research_effect_cap` | レベル上限 +%d |
| `ui_research_effect_stat` | 全ステータス +%d |
| `ui_research_empty` | 研究データが読み込めませんでした |
| `ui_research_cap_1` | 訓練場の拡張 |
| `ui_research_cap_2` | 実戦形式の導入 |
| `ui_research_cap_3` | 遠征訓練 |
| `ui_research_cap_4` | 秘伝書の解読 |
| `ui_research_stat_1` | 基礎体力の底上げ |

`ui_common_back`は既存。

**`ui_res_construction_material`が既にあるか確認する。** 倉庫画面で使っているはずだが、無ければ「建材」で追加する。**これが無いと素材名が空欄ではなくキー名のまま表示される。**

### 3-2. ファイルの保存

設計役から受け取ったものをそのまま置く。**中身を書き換えない。**

| ファイル | 置き場所 | 種別 |
|---|---|---|
| `game_manager.gd` | `res://autoload/game_manager.gd` | **全文差し替え** |
| `master_data_loader.gd` | `res://autoload/master_data_loader.gd` | **全文差し替え**（末尾追記済みの版） |
| `research.json` | `res://resources/balance/master/research.json` | 新規 |
| `research_screen.tscn` | `res://scenes/guild/research_screen.tscn` | 新規 |
| `research_screen.gd` | `res://scenes/guild/research_screen.gd` | 新規 |

`master_data_loader.gd`は`RefCounted`の静的クラスでAutoloadではないが、既存の置き場所に合わせること。**現在の実際のパスを確認してから上書きする。**

### 3-3. `guild_screen.gd`の遷移先差し替え（**最後に**）

定数を1つ追加：
```gdscript
const RESEARCH_PATH: String = "res://scenes/guild/research_screen.tscn"
```

`GUILD_SCENES`の1行を差し替え：
```gdscript
	"research": PLACEHOLDER_PATH,
```
↓
```gdscript
	"research": RESEARCH_PATH,
```

`_go_to_sub()`は`path == PLACEHOLDER_PATH`のときだけ`change_scene_with_data`を使う分岐なので、**研究は`else`側（`change_scene`）を通る。修正不要。**

**この差し替えは`research_screen.tscn`を保存してから行う。** 先にやると遷移先が無くエラーになる。

---

## 4. 決めた数値

### 4-1. ノード構成（縦1列・5ノード）

| node_id | 効果 | 前提 | コスト（`construction_material`） |
|---|---|---|---|
| `res_cap_1` | レベル上限 +5 | — | 20 |
| `res_cap_2` | レベル上限 +5 | `res_cap_1` | 40 |
| `res_stat_1` | 全ステータス +3 | `res_cap_1` | 30 |
| `res_cap_3` | レベル上限 +5 | `res_cap_2` | 70 |
| `res_cap_4` | レベル上限 +5 | `res_cap_3` | 110 |

実効レベル上限：10 → 15 → 20 → 25 → **30**

`res_stat_1`は`res_cap_1`を前提にして`res_cap_2`と並列に置いた。**1本道ではないことを最初から見せておく**ため（分岐の描画はしないが、依存の構造だけは使う）。

### 4-2. コスト素材は`construction_material`

`training_material`を研究にも使うと、レベルを上げるか上限を上げるかで同じ素材を奪い合う。**上限を解放しても上げる素材が無い、が起きる。**

`construction_material`は現在ステージ報酬で溜まる一方で出口が無い。ここが最初の出口になる。

> **後で競合しうる。** `construction_material`は本来「拠点の建設」の名前。作業場・拠点拡張を作るときに、研究と取り合いにならないか見直すこと。専用の`research_material`に分けるなら`stages.json`への追加が要る。

### 4-3. 刻み幅は+5

`character_config.tres`の`level_up_cost_formula`は`base + growth * (level - 1)`、`base_level_up_cost = 3`・`cost_growth_per_level = 1.0`。レベル`L`から1つ上げるコストは`training_material`が`L + 2`個。

| 区間 | 必要な`training_material` |
|---|---|
| Lv10 → 15 | 70 |
| Lv15 → 20 | 95 |

ステージ3の`training_material`は1周6個。**1ノードぶんの育成に12周前後。** +10にすると1ノードで25周相当になり、解放した実感が薄れる。

---

## 5. 設計役が書いたもの

### 5-1. `game_manager.gd`（884行 → 1051行・全文差し替え）

**原本をコピーして該当箇所だけ差し替えた。既存の関数は1つも変質していない。**

| 対象 | 内容 |
|---|---|
| `research_node_unlocked(node_id)` | **シグナル追加** |
| `RESEARCH_COST_MATERIAL_ID` / `RESEARCH_COST_AMOUNT` | 定数追加。`get_level_up_cost()`と同じ形 |
| `RESEARCH_NODE_COST_MATERIAL_ID` / `RESEARCH_NODE_COST_AMOUNT` | 定数追加。`research.json`側のキー |
| `_ready()` | 末尾で`_sync_research_tree_from_master()`を呼ぶ |
| `unlock_research_node(id)` | **本実装** |
| `get_research_unlock_cost(id)` | 新規 |
| `can_unlock_research_node(id)` | 新規。前提だけを見る（素材は見ない） |
| `_prerequisites_met(node)` | 新規（private） |
| `_sync_research_tree_from_master()` | 新規（private） |
| `load_state()` | `_state`反映の直後に`_sync_research_tree_from_master()`を呼ぶ |
| `get_research_tree()` / `get_effective_level_cap()` / `get_stat_boost_all()` | **変更なし** |

**`unlock_research_node()`の判定順**

```
1. ノードが research_tree に存在するか   → 無ければ false
2. 既に unlocked か                      → true なら false（二重消費の防止）
3. prerequisites が全て unlocked か       → 1つでも false なら false
4. 素材が足りているか                     → 足りなければ false
--- ここから状態を変える。以降に失敗する分岐を作らない ---
5. unlocked = true にして _state へ代入し直す
6. add_material(material_id, -amount)
7. research_node_unlocked.emit(node_id)
```

**3を4より先に行う。** 逆にすると、前提未解放のノードで「素材不足」と表示され画面の説明と食い違う。

**5を6より先に行う。** `add_material()`が`material_changed`を発火し、それを受けた画面が再描画する。順序が逆だと、解放前の状態で1度描き直される。

**`_sync_research_tree_from_master()`の仕様**

- `research.json`の全ノードを`research_tree`へ流し込む
- **`unlocked`だけは既存の値を残す**
- `effect_type` / `effect_value` / `target_stat` / `prerequisites`は毎回マスターデータで上書きする

これで`research.json`の効果値を調整すると、**既存セーブにも次の起動で反映される。** `initial_state_config.tres`を編集してもセーブがあると反映されない罠（`EXEC_GUILD_TRAINING.md` §9）を、研究では最初から踏まない形にした。

> **`research.json`から消えたノードは`research_tree`からも消える。** ノードIDを改名すると解放状態が失われる。リリース後は改名しないこと。

### 5-2. `master_data_loader.gd`（143行 → 179行・末尾追記のみ）

`get_stage_order()`と同じ形にそろえた。**既存の関数・定数・`static var`には一切触っていない。**

- `PATH_RESEARCH` / `_cache_research` / `_research_loaded`
- `get_research_node(node_id)` — 1件引く
- `get_all_research_nodes()` — 全件返す。`GameManager`の同期処理が使う
- `_ensure_research_loaded()` — 遅延ロード。`_ensure_loaded()`には組み込まない

**`get_all_research_nodes()`を用意したのが要点。** キー一覧を返す関数が無いと、呼び出し側でノードIDを決め打ちすることになる。`training_screen.gd`の`CHARACTER_IDS`と同じ問題を繰り返さない。

### 5-3. `research.json`（新規）

§4-1の5ノード。`unlocked`は**書かない**（状態側だけが持つ）。

### 5-4. `research_screen.tscn` / `research_screen.gd`（新規）

```
ResearchScreen (Control)          ← script: research_screen.gd
├── Background (ColorRect)
└── Margin (MarginContainer)       上下左右 24
	└── Layout (VBoxContainer)
		├── TitleLabel (Label)      text = "ui_research_title"
		├── MaterialLabel (Label)   所持素材
		├── CapLabel (Label)        現在の実効レベル上限
		├── Scroll (ScrollContainer)
		│   └── NodeList (VBoxContainer)   ノード行をコードで生成
		├── NoticeLabel (Label)
		└── BackButton (PrimaryButton)     label_key = "ui_common_back"
```

**`CapLabel`を置いたのが要点。** 解放して上限がいくつになったかがその場で見えないと、育成画面へ行くまで手応えが分からない。

**戻るボタンは1つだけ。** 育成では詳細に`ToListButton`、外側に`BackButton`があり、詳細表示時に2つ並ぶ不具合が出た。研究は詳細を作らないのでこれが起きない。

`ja.csv`にキーが無い場合はキー名がそのまま表示される（`AGENTS.md`の許容方針）。**空欄にはならない。**

---

## 6. 作業の順番

1. 人間：§3-1（`ja.csv`）
2. 人間：§3-2（ファイルの保存）
3. 人間：§7（起動ログ）を確認
4. 人間：§3-3（`guild_screen.gd`の差し替え）
5. 人間：§8を実機で確認
6. 人間：§8-2（マスターと状態の同期）を確認

**1を飛ばすと画面に翻訳キーがそのまま並ぶ。** 動作はするので、後から足してもよい。

---

## 7. 完了条件：ログで確認する

**実装役を使わないため、人間がGodotの出力パネルで確認する。**

**画面を操作すれば分かることはここに書かない。** §8にだけ書く。ここに残すのは、画面に出ない内部の値だけ。

- [ ] L-1. 起動ログに`[GameManager] _sync_research_tree_from_master() -> 5 nodes (unlocked=0)`が出る

**`0 nodes`だったときの切り分け（2手まで）**

| | 見るところ |
|---|---|
| 1 | `research.json`が`res://resources/balance/master/`に置かれているか。パスの綴り |
| 2 | 出力に`[MasterDataLoader] load() returned null`か`FileAccess.open failed`が出ていないか |

3つ目に進まず報告すること。

---

## 8. 完了条件：画面で確認する

**ここがこのタスクの本体。** §7が通っても省かないこと。

- [ ] S-1. ギルド画面の「研究」ボタンから研究画面へ遷移する
- [ ] S-2. ノードが5つ、縦に並んで表示される
- [ ] S-3. 各ノードに効果・必要素材・所持数が出ている
- [ ] S-4. 前提未解放のノードは「◯◯の解放が必要です」が出て、ボタンが押せない
- [ ] S-5. 素材が足りないノードのボタンが押せない状態になっている
- [ ] S-6. 解放可能なノードのボタンを押すと、**画面を出入りせずに**その場で「解放済み」に変わる
- [ ] S-7. 同時に`CapLabel`の上限表示が10から15へ変わる
- [ ] S-8. 同時に所持素材の表示が20減っている
- [ ] S-9. 次のノード（`res_cap_2`・`res_stat_1`）が押せる状態に変わっている
- [ ] S-10. 一覧が長くなってもスクロールできる
- [ ] S-11. 戻るボタンでギルド画面へ戻る。**戻るボタンが2つ並んでいない**
- [ ] S-12. 育成画面へ行くと、レベル10のキャラが**さらにレベルを上げられる**
- [ ] S-13. `res_stat_1`解放後、育成画面のステータス4項目がそれぞれ+3されて表示される
- [ ] S-14. セーブして再起動しても解放状態が保持されている
- [ ] S-15. 上限を上げたキャラで戦闘に入ると、育成後のステータスで戦う（F3のデバッグパネルで確認）

**S-12がこのタスクの本題。** 育成の詰まりが解けたことはここでしか確認できない。

---

## 8-2. 完了条件：マスターと状態の同期を確認する

**この1件だけは画面の操作では出せない。** `research.json`を書き換えて再起動する必要がある。

1. 研究画面の`CapLabel`の数値をメモする
2. `research.json`の`res_cap_1`の`effect_value`を`5` → `7`に書き換えて保存する
3. **Godotエディタごと再起動する**（`.json`の再インポートを効かせるため）
4. 研究画面を開く

- [ ] M-1. `CapLabel`がメモした値**+2**になっている（マスターの変更が既存セーブに反映された）
- [ ] M-2. `res_cap_1`が**「解放済み」のまま**である（解放状態が失われていない）
- [ ] M-3. `effect_value`を`5`に戻して再起動すると、元の数値に戻る

**M-1とM-2は両方通って初めて意味がある。** 片方だけでは同期の半分しか確認できていない。

**M-1で数値が変わらないとき**は、エディタを再起動していないか、`.json`が再インポートされていない。FileSystemパネルで`research.json`を右クリック →「再インポート」。ここまでで止めて報告すること。

---

## 8-3. UIから到達できない項目（人間は確認しない）

**以下は画面から実行できない。** 将来コードを変えたときに見る保険であって、今回の確認項目ではない。

| 経路 | 期待する挙動 |
|---|---|
| 解放済みノードを再度`unlock_research_node()` | `false`。ログに`already unlocked`。素材が二重に減らない |
| 存在しない`node_id`を渡す | `false`。警告のみでクラッシュしない |
| `prerequisites`に存在しないIDが書かれている | `false`。警告のみ。**解放できてしまうより解放できないほうが安全** |
| `effect_value`が`float`のまま保存される | 起きない。`_sync_research_tree_from_master()`が`int()`で包む |

**ボタンは条件を満たさないと押せないため、上の1つ目と2つ目は画面から起こせない。**

---

## 9. 併せて直すもの

| ファイル | 内容 |
|---|---|
| `DATA_SCHEMA.md` 4-4 | `target_stat`を追記。**実コードにあるのにスキーマに無い** |
| `AGENTS.md`「GameManagerのシグナル」 | `research_node_unlocked`を追記。**`character_growth_changed`も未追記のまま**（`EXEC_GUILD_TRAINING.md` §5-5の積み残し）。2つまとめて足す |
| `NEXT_STEPS.md` | 次のタスク（ショップ）の内容に書き換える |
| `PROJECT_STATUS.md` | 「次に何をすべきか」を更新。研究の項を「完了」へ |

**上記4件はすべて反映済み**（研究の完了時点）。

---

## 10. このタスクで残した宿題

- **`Modal.confirm`による解放確認**（§2-7）。`modal.gd`のAPIを確認してから`_on_unlock_pressed()`に足す
- **ツリーの分岐表示。** 依存関係のデータは既にあるので、線を引く実装だけ後から足せる
- **`construction_material`の競合**（§4-2）。作業場・拠点拡張を作るときに見直す
- `get_effective_level_cap()`は`character_id`を使っていない（全キャラ共通の上限）。キャラごとに上限を変えるならここから
