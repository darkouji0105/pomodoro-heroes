# EXEC_SKILL_SELECT.md — スキル解放と選択

`PLAN_IMPLEMENTATION.md` 3章の3番の残り（レベルの役割転換・第2弾）。仕様の正は `GAME_DESIGN.md` **3-2** と **5-2**。

**このファイルには仕様の本文を書かない。** 決定と、実際に触る場所と、完了条件だけを書く。

---

## 1. 人間による決定事項（2026-08-15・**本文と矛盾する場合こちらが優先**）

| 項目 | 決定 |
|---|---|
| **スコープ** | **A′**。付け替え ＋ `unlock_level` キー ＋ 解放判定まで。**スキル12個の中身は次回** |
| **`growth.skills` の構造** | `{"slots": ["", ""]}`。要素はスキルID、`""` が未選択 |
| **未選択時** | **マスターへフォールバックする。** 空の枠は候補の未使用先頭で埋めて戦闘に出す |
| **画面** | **新規画面** `skill_select_screen`。`training_screen` の既存 `skill_button` の飛び先を差し替える |
| **`save_version`** | **3 のまま上げない**（§9 に根拠） |
| **前回の宿題（`EXEC_LEVEL_ROLE_SHIFT.md` §4-4）** | **このタスクの最後にまとめて片付ける**（§10） |

---

## 2. 着手前に確認した実コード（2026-08-15・`grep` 済み）

`NEXT_STEPS.md` §2 の6項目は**すべて実コードと一致していた**（ズレなし）。追加で確認した事実：

| | 事実 |
|---|---|
| `battle_controller.gd` **139行** | `char_data` は `MasterDataLoader.get_character()`。**`stats` だけ `GameManager.get_effective_stats()` から来ていて（148行）、`skills` だけがマスター直読みで取り残されている**（164行）。**ここが本題** |
| `game_manager.gd` **1093-1095行** | `_default_growth_for()` に `GROWTH_SKILLS: {}` と、**「slots はスキル選択の実装時に入れる」というコメントが既にある**。今回そこを埋める |
| `GROWTH_SKILLS` の参照元 | **`game_manager.gd` 1095行の1箇所だけ**。読んでいるコードは無い |
| `MasterDataLoader` | `get_skill()` はあるが **`get_all_skills()` が無い**（`get_all_research_nodes()` / `get_all_character_nodes()` はある）。候補一覧は `characters.json` の `skills` 配列から引くので**新設は不要** |
| レベル上限 | `base_level_cap`＝**10**（`character_config.gd` 15行）＋ `research.json` の `level_cap_unlock` 4件×5 ＝ **30**。**「研究を全部解放」で Lv20 に到達できる**（検証可能） |

---

## 3. 触るファイルと担当

| ファイル | 行数 | 何をするか | 担当 |
|---|---|---|---|
| `resources/balance/master/skills.json` | 52 | `unlock_level` を6件に追加 | 設計役 |
| `scripts/utils/state_keys.gd` | — | 定数を1つ追加 | 設計役 |
| `autoload/game_manager.gd` | **2542** | 関数7本（うち1本は既存の空実装を置換） | **設計役**（200行超） |
| `scenes/adventure/battle_controller.gd` | **904** | **164行の1行付け替え** | **設計役**（200行超） |
| `scenes/guild/skill_select_screen.gd` / `.tscn` | 新規 | 選択画面 | **実装役に切り出せる**（`stat_node_screen` 194行と同規模の見込み） |
| `scenes/guild/training_screen.gd` | — | 51行の `bind` 差し替え | 設計役 |
| `localization/ja.csv` | — | キー追加 | 設計役（**再インポートは人間**） |

---

## 4. データ：`skills.json` に `unlock_level` を足す

**6件すべてに `"unlock_level": 1` を追加する。** 現状は1キャラ2個で、これが `GAME_DESIGN.md` 3-2 の「初期2個」にあたる。

- **`MasterDataLoader` は float を返す。読むときは必ず `int()` で包む**（`CLAUDE.md` 3番）
- 次回スキル12個を足すときは、この値を `5` / `10` / `15` / `20` にする。**コードは触らなくてよい状態にしておくのが A′ の目的**
- **解放レベルは `skills.json` に持たせる。** `character_nodes.json` のような別ファイルは作らない（6→18件でファイルを分ける規模ではなく、スキル1件の情報が2ファイルに割れるほうが害が大きい）

> **スキルIDを改名できなくなる。** セーブが持つのは選んだIDだけで、倍率もCDも解放レベルも `skills.json` から毎回引くため（`CLAUDE.md` 7番）。

---

## 5. 状態：`growth.skills` の構造

```json
"skills": { "slots": ["skill_power_slash", ""] }
```

- `slots[0]`＝スキル1、`slots[1]`＝スキル2。**表示順を安定させるために配列で持つ**
- ⚠ **枠は装備スロットに対応しない。** スキルはそのまま持ち込むだけで、武器・アクセサリーとの紐づきは**ルーン側だけの話**（2026-08-15に人間が確認）
- `""` は未選択
- **トップレベルの `skills` は Dictionary のまま変わらない。** 既存セーブの `{}` は §6-1 の正規化で `{"slots": ["", ""]}` になる

`state_keys.gd` に追加する定数（`GROWTH_NODES` の下）：

```gdscript
# growth.skills の中身。{"slots": [skill_id, skill_id]}。
# slots[0]=スキル1、slots[1]=スキル2。枠は装備スロットに対応しない。
# 中身はスキルIDだけ。倍率・CD・解放レベルは skills.json から毎回引く。
# 代償として、リリース後にスキルIDを改名できない。
const GROWTH_SKILL_SLOTS: String = "slots"
```

**枠数（2）は `.tres` に置かない。** バランス数値ではなく構造（装備スロットの `_equip_slots()` と同じ扱い）。`GameManager` に `SKILL_SLOT_COUNT` を持ち、将来3枠にするときはこの1箇所を直す。**枠に名前は無いので、画面は番号で並べる。**

---

## 6. `game_manager.gd` の変更

### 6-1. 正規化（既存2箇所に追記）

`_normalize_skill_slots(growth: Dictionary) -> Dictionary` を新設し、**`skills` を必ず `{"slots": [長さ=スロット数の配列]}` の形にして返す。**

- `{}` → `{"slots": ["", ""]}`
- 配列が短い／長い → スロット数に合わせて詰める・切る
- **呼ぶ場所は `_default_growth_for()`（1087行の戻り値）と `load_state()` の2箇所。** `_resync_growth_stats_from_master()` と同じ位置に置く

> これで旧セーブが**次の起動で黙って追従する**（`AGENTS.md`「マスターデータと状態を同期する型」）。**`save_version` を上げなくてよい理由がこれ。**

### 6-2. 新設する関数（7本）

| 関数 | 戻り値 | 中身 |
|---|---|---|
| `get_skill_slot_count() -> int` | 2 | `SKILL_SLOT_COUNT` を返すだけ。画面が枠数を決め打ちしないために公開する |
| `get_skill_candidates(character_id) -> Array` | スキルIDの配列 | `characters.json` の `skills` 配列を順に見て、`int(skills.json の unlock_level) <= 現在レベル` のものだけ返す。**配列の順序が画面の並び順**（`allocatable_stats` と同じ思想） |
| `get_all_skill_candidates(character_id) -> Array` | 同上 | **レベルで絞らない全候補**。画面が「未解放」を灰色で見せるために要る |
| `get_selected_skills(character_id) -> Array` | 長さ2 | 保存された `slots` をそのまま返す（**空欄は埋めない**）。画面が「未選択」を表示するために要る |
| `get_battle_skills(character_id) -> Array` | 長さ≤2 | **確定版。** `get_selected_skills()` の空欄を `get_skill_candidates()` の**未使用の先頭**で埋め、`""` を除いて返す。**戦闘とスキルボタンはこれだけを見る** |
| `can_select_skill(character_id, slot_index, skill_id) -> bool` | | **判定のみ。状態を触らない**（`can_unlock_stat_node()` と同じ形） |
| `select_skill(character_id, slot_index, skill_id) -> bool` | | **既存の空実装（1728行）を置き換える。シグネチャが `slot_id` → `slot_index` に変わるが、呼び出し元は0件なので影響なし** |
| `clear_skill_slot(character_id, slot_index) -> bool` | | 枠を `""` に戻す |

### 6-3. `can_select_skill()` が弾く条件

**状態を変える前に全部判定を終える**（`CLAUDE.md` 6番）。

1. `character_id` の育成データが引けない
2. `slot_index` が範囲外
3. `skill_id` が `skills.json` に無い
4. その `skill_id` の `user_character_id` が `character_id` と違う
5. `int(unlock_level) > 現在レベル`（**未解放**）

### 6-4. 同じスキルを別の枠に入れたら「入れ替え」にする

**同じスキルが2枠に並ぶのを防ぐため。** 弾いて何も起きないより、入れ替わるほうが操作として自然。

**`select_skill()` は、選んだ `skill_id` が既に別の枠に入っている場合、2つの枠を交換する。**

- 例：`slots = ["A", "B"]` で 枠0 に `B` を選ぶ → `["B", "A"]`
- 専用の `swap_skill_slots()` は作らない。**画面から並べ替えれば自然に入れ替わる**ため、関数が2本あると同じことを2通りで書けてしまう

> **枠の順番自体に効果の差は無い**（§5）。並べ替えは表示順の都合。

### 6-5. シグナル

**`character_growth_changed(character_id)` を発火する。** 新しいシグナルは足さない（`AGENTS.md` のシグナル表どおり、スキルの変化はこれに含まれる）。

---

## 7. 戦闘の付け替え（**このタスクの本題**）

`scenes/adventure/battle_controller.gd` **164行**：

```gdscript
# 変更前
var skill_list: Array = char_data.get("skills", [])
# 変更後
var skill_list: Array = GameManager.get_battle_skills(character_id)
```

- **`char_data` は残す**（`BattleUnit.create()` に渡している。155行）。消さないこと
- コメントを添える：`stats` が `get_effective_stats()` から来ているのと同じ理由で、`skills` も状態から引く

### ⚠ 編集直後にやること（事故の再発防止）

```
grep -n "get_battle_skills" scenes/adventure/battle_controller.gd   → 1件であること
grep -n 'char_data.get("skills"' scenes/adventure/battle_controller.gd → 0件であること
```

**「差し替えを当てたつもりで当たっておらず、戦闘だけ反映されない」で1タスク溶かした事故がある**（`CLAUDE.md` 2番）。

`_build_skill_buttons()`（416行）は `unit.skill_ids` を回すだけなので**触らない。上が正しければ戦闘UIは追従する。**

---

## 8. 画面

### 8-1. `skill_select_screen`（新規・`stat_node_screen` と同じ形）

- `TransferKeys.CHARACTER_ID` で対象を受け取る
- 購読は `character_growth_changed` の**1本だけ**（素材を触らないので `material_changed` は飛ばない）
- **枠の行を上に2つ**（「スキル1」「スキル2」。**枠数は `get_skill_slot_count()` から引く。2 と書かない**）
- **1行 = [枠を選ぶボタン][外すボタン] の2つ。** 枠を押すと「次に選んだスキルの行き先」が変わる（`▶` が付く）。**枠を押しただけでは状態を触らない**
  > **当初は「枠を押すと解除」と書いていたが、実装時に分けた。** 行き先を変えるだけのつもりで選択が消えるため。解除は「外す」側に独立させる
- **候補の一覧をその下に。** `get_all_skill_candidates()` を回し、`get_skill_candidates()` に含まれないものは `disabled` にして解放レベルを併記
- 押したら `GameManager.select_skill(_character_id, 選択中の枠, skill_id)`。**戻り値は見ない**（`character_growth_changed` で描画し直される）
- **枠数を `2` と決め打ちしない。** `GameManager.get_skill_slot_count()` を回す

### 8-2. 真似する場所（`stat_node_screen` から）

| | どこ |
|---|---|
| 再描画で `remove_child()` してから `queue_free()` | `_clear()`（158行あたり）。**`await` を持たせない** |
| 等幅の列 | `.tscn` の `Scroll` に `horizontal_scroll_mode = 0`。**これが無いと子の `SIZE_EXPAND_FILL` が効かない**（実機で1回踏んでいる） |
| 「押せてから失敗する」より「押せない」 | `button.disabled` を先に決める |

### 8-3. 導線

`scenes/guild/training_screen.gd` **51行**：

```gdscript
# 変更前
skill_button.pressed.connect(_go_to_placeholder.bind(SCREEN_ID_SKILL))
# 変更後
skill_button.pressed.connect(_on_skill_pressed)
```

`_on_skill_pressed()` は `_on_stat_node_pressed()`（176行）を真似て `TransferKeys.CHARACTER_ID` を渡す。**`SKILL_SELECT_PATH` 定数を `STAT_NODE_PATH`（25行）の隣に置く。**

---

## 9. `save_version` は 3 のまま

**上げない。**

- `skills` キーは既に全セーブに存在し、**中身が `{}` から `{"slots": [...]}` に増えるだけ**
- 旧セーブは §6-1 の正規化がロード時に埋める
- `save_manager.gd` 7行は触らない

---

## 10. このタスクの最後に片付ける宿題

`EXEC_LEVEL_ROLE_SHIFT.md` §4-4 の未了分。**スキルぶんの更新と一緒に1回で書く。**

- [x] `GAME_DESIGN.md` **14章の未決を削除**（4件削除・スキル12個の内容を追加）
- [x] `GAME_DESIGN.md` **15章**（`select_skill()` と `stat_growth_formula` を実装済みに）
  - ⚠ **15章は「更新履歴」ではなく「実装上の注意（既存コードとの接続）」。** このファイルに更新履歴の節は存在しない
- [x] `DATA_SCHEMA.md`（4-3 の `skills` を全面改訂・3-1 に `unlock_level`・5章から2行を移動・更新履歴）
- [x] `PROJECT_STATUS.md`（現在地・実装済み表2行・Git章の表2行・宿題7件・次のタスク・更新履歴）
- [x] `PLAN_IMPLEMENTATION.md` 3章（**状態列を新設**。表に完了を記録する欄が無かった）
- [x] `NEXT_STEPS.md` を**次のタスク（テンプレ決定 → パッシブ）**に書き換える

---

## 11. 完了条件

**「どこを見るか」で3つに分ける**（`AGENTS.md`）。**同じことを2箇所に書かない。**

### 11-A. ログ（Godot の出力パネル）

画面に出ない内部の値と、UIから到達できない経路だけ。

1. 起動時、`[MasterDataLoader] loaded 6 entries from ...skills.json` が出る（件数が減っていない）
2. **旧セーブ**（`skills` が `{}`）をロードしたとき、`[GameManager] _normalize_skill_slots_from_save() -> N / N entries normalized` が出て、**左のN（直した件数）がセーブに入っているキャラ数と一致する**
3. **新しく保存したセーブ**をもう一度ロードすると、同じ行の左のNが **0** になる（正規化が2回目で空振りする＝形が正しい）
4. `select_skill()` の失敗が理由つきで出る（`-> false (already in this slot)` 等）

### 11-B. セーブファイル（`save_slot_0.json` をテキストエディタで開く）

1. `character_growth` の各キャラに `"skills": {"slots": ["", ""]}` がある
2. スキルを1つ選んで保存すると `"slots": ["skill_power_slash", ""]` になる。**`slots` の中身はIDの文字列だけで、倍率・CD・`unlock_level` が複製されていない**
3. `"save_version": 3` のまま
4. **数値に `.0` が付いていない**（`unlock_level` はセーブに書かれないはずだが、書かれていたら §4 の `int()` 漏れ）

### 11-C. 画面（実機で操作する）

1. 育成画面の「スキル」ボタンを押すと、**プレースホルダではなくスキル選択画面**が開く
2. 枠が**2つ**表示され、「スキル1」「スキル2」と読める（**武器・アクセサリーの表記が出ていないこと**）
3. 候補が**そのキャラのスキルだけ**出る（剣士の画面に狙撃が出ない）
4. Lv1 の状態で、候補2個が押せる
5. 枠1に `▶` が付いている状態で候補を押すと、**枠1の表示が変わる**
6. **枠2を押すと `▶` が枠2へ移る**（このとき選択済みのスキルは消えない）
7. **枠1に入っているスキルを枠2に入れると、2つが入れ替わる**（枠1が空にならない）
8. 「外す」を押すと枠が「未選択」に戻る。**未選択の枠の「外す」は押せない**
9. 戻ると育成画面に戻る
9. **デバッグオーバーレイで「素材を全種類」→「研究を全部解放」→ レベルを上げると、Lv20 まで上がる**（上限30）
10. **⭐ 戦闘に出すと、スキルボタンが選んだ2個になる**（このタスクの本題）
11. **何も選ばずに戦闘に出しても、スキルボタンが2個出る**（マスターへのフォールバック）
12. スキルを1つだけ選んで戦闘に出すと、**選んだものが左、フォールバックが右**に出る

### 11-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

UIから到達できない。

- 存在しないスキルIDを `select_skill()` に渡す → `false`
- 他キャラのスキルIDを渡す → `false`
- `slot_index` に `-1` / `5` を渡す → `false`
- `skills.json` からIDを消す → その枠が空扱いになり、フォールバックが効く

---

## 12. 実施結果（2026-08-15）

**Godot を起動していないため、動作は確認していない。** 以下は「何をどこに書いたか」だけ。検証は §11 を人間が実施する。

### 12-1. 触ったファイル

| ファイル | 変更 |
|---|---|
| `resources/balance/master/skills.json` | 6件すべてに `"unlock_level": 1` |
| `scripts/utils/state_keys.gd` | `GROWTH_SKILL_SLOTS`（131行の下） |
| `autoload/game_manager.gd` | 定数3・関数12。**2542 → 2838行** |
| `scenes/adventure/battle_controller.gd` | **172行**を `GameManager.get_battle_skills()` に付け替え |
| `scenes/guild/skill_select_screen.gd` / `.tscn` | **新規**（204行） |
| `scenes/guild/training_screen.gd` | 導線差し替え・死にコード削除 |
| `localization/ja.csv` | 4行追記（末尾） |

### 12-2. `grep` による確認（§7 の手順どおり実施）

```
grep -n "get_battle_skills" scenes/adventure/battle_controller.gd   → 172行に1件（170行はコメント）
grep -n 'char_data.get("skills"' scenes/adventure/battle_controller.gd → 0件
grep -n "char_data" scenes/adventure/battle_controller.gd            → 141/142/157行に残存（BattleUnit.create へ渡す分）
grep -rn '"skills"' --include=*.gd .                                  → 実コードは get_all_skill_candidates() の1箇所のみ
```

**`characters.json` の `skills` を読むコードは `get_all_skill_candidates()` だけになった。** 戦闘からの直読みは消えている。

字下げのタブ確認：**変更した5ファイルすべてで4スペース字下げ0件。**

### 12-3. 指示書からの逸脱（**空欄にしない**）

1. **枠の操作を2ボタンに分けた**（§8-1 に反映済み）。「枠を押す＝解除」だと行き先の切り替えができない
2. **枠を装備スロット名の配列にしたが、あとで撤回した。** 当初 `_skill_slots()` が `EQUIP_WEAPON` / `EQUIP_ACCESSORY` を返す形にした（`GAME_DESIGN.md` 3-2 の記述に従った）。**人間の指摘で `SKILL_SLOT_COUNT: int = 2` に差し替えた**（§12-6）
3. **`_skill_select_error()` の判定を §6-3 の5条件から6条件に増やした。** `user_character_id` が合っていても `characters.json` の候補一覧に無ければ弾く。ここを緩めると「選べたのに戦闘に出ない」が起きる（`get_battle_skills()` は候補一覧で絞るため）
4. **「外す」の翻訳キーを作らず、`ui_equipment_unequip` を使い回した**（`AGENTS.md`「同じ意味のテキストは既存キーを使い回す」）
5. **`training_screen.gd` から `PLACEHOLDER_PATH` / `SCREEN_ID_SKILL` / `_go_to_placeholder()` を削除した。** 今回の差し替えで呼び出し元が0件になったため。**この画面から `placeholder_screen` へ飛ぶ導線は無くなった**
6. `select_skill()` の**シグネチャを `slot_id` → `slot_index` に変え、戻り値を `void` → `bool` にした**（§6-2 のとおり。呼び出し元は0件だった）

### 12-4. 人間の作業（**AI にはできない**）

- [ ] **`ja.csv` の再インポート**（FileSystem で右クリック → 再インポート、または Godot 再起動）。**これをしないと画面にキー名がそのまま出る**
- [ ] `skill_select_screen.tscn` が正しく開くか（新規 `.tscn` を手書きしているため、ノードパスの取り違えはここで出る）
- [ ] §11 の検証（ログ・セーブファイル・画面）

### 12-5. コミットメッセージ

```
feat(skill): スキル候補の解放と2枠の選択・戦闘への反映
```

**`PROJECT_STATUS.md` の Git章の表に追記すること**（§10 の宿題に含む）。

### 12-6. 枠と装備スロットの紐づけを撤回した（2026-08-15・人間の指摘）

**初回の実装では、枠を「対応する装備スロット」として持たせていた**（`_skill_slots()` が `EQUIP_WEAPON` / `EQUIP_ACCESSORY` を返し、画面に「武器」「アクセサリー」と表示していた）。

根拠にしたのは `GAME_DESIGN.md` **3-2 の2行目**：

> スキル1は武器スロット、スキル2はアクセサリースロットに対応する（ルーンとの紐づき。7章参照）

**人間の指摘により、これは誤りと確認した。** スキルはそのまま2つ持ち込むだけで、武器・アクセサリーとの対応は**ルーン側だけの話**。

直したもの：

| | 変更前 | 変更後 |
|---|---|---|
| `game_manager.gd` | `_skill_slots() -> Array[String]`（装備スロット名） | **`const SKILL_SLOT_COUNT: int = 2`** |
| | `get_skill_slots()` | **削除** |
| 画面のラベル | `ui_equipment_slot_weapon` / `_accessory` の使い回し | **`ui_skill_select_slot`（`スキル%d`）を新設** |
| `state_keys.gd` のコメント | 「slots[0]=武器スロット」 | 「slots[0]=スキル1。枠は装備スロットに対応しない」 |

**セーブの構造は変わっていない**（`{"slots": ["", ""]}` のまま）。変わったのは枠の呼び名と、コード上で装備スロットの定数を参照していた点だけ。

**`GAME_DESIGN.md` 3-2 は人間の指示で修正済み（2026-08-15）。**

- 「スキル1は武器スロット、スキル2はアクセサリースロットに対応する」の行を**削除**
- 代わりに「**スキルの枠に装備スロットの意味は無い**」を明記
- **紐づきの記述は 7-5（ルーン側）にだけ置く。** そこには既に「武器＝スキル1、アクセサリー＝スキル2に紐づく」があり、**向きはルーン→スキル**。3-2 はそれを参照するだけにした
- **なぜ間違えたかを 3-2 に注記として残した。** 削除しただけだと、同じ行がまた書き戻される

> `grep -n "スキル1は武器" docs/GAME_DESIGN.md` → 注記の1件のみ（本文からは消えている）。
