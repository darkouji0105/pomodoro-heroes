# EXEC：拠点の容量の判定を消す（回3-d・`BS-20`・`BS-10` の残り・`EQ-14`）

> ⚠⚠ **2026-10-03。⚠ 関数・Balance の欄・設定のファイルが消えるので `EXEC` を書く側。**
> ⚠ **値の正は `docs/DECISIONS.md`（`BS-20`・`BS-10`・`EQ-14`）。**

---

## 1. 人間の裁き（**そのまま。⚠ 覆さない**）

⚠ 人間：「⚠ あ　⚠ ２い　⚠ かぎってダンジョンの中のやつだよね」（⚠ 答え：⚠ いいえ・`INVENTORY_ORDER` は**拠点の持ち物の並び**）。

| | 人間の選択 |
|---|---|
| 1 どこまで消すか | ⚠⚠ **「あ」＝判定・捨てる・枠を買う・並べ替え・ページ・`InventoryConfig` と `Balance` の欄まで消す**（⚠ `autoload/balance.gd`・`balance.tscn` を触る＝許可に含む） |
| 2 セーブの `INVENTORY_ORDER` | ⚠ **「2い」＝鍵は残す**。⚠ 並び（入手順）を覚える用途にはそのまま使い、⚠ 「マスの数」と「空きマスの穴」をやめる |
| 前から決まっていること | ⚠ 消したら「捨てる」も消す（`EQ-14`・人間「⚠ 4あ」）。⚠ 装備は「素材にする」（分解）が残る |

---

## 2. ⚠⚠ いまの事実（**`grep` で取った・2026-10-03**）

| 事柄 | どこ |
|---|---|
| 判定（入らないなら止める） | ⚠ `open_chest()` ／ `purchase_shop_item()` ／ `unequip_instance()` ／ `collect_craft()` ／ `add_to_inventory()`（⚠ `_acceptable_count()` で入るぶんだけ）／ `retreat_from_dungeon()` と `deliver_floor_bag()`（⚠ 「満杯で置いてきた」＝`left_behind`） |
| 口 | ⚠ `get_inventory_free_slots()` ／ `can_accept_inventory()` ／ `_inventory_slots_needed*()` ／ `get_inventory_slot_max()` ／ `get_inventory_extra_slots()` ／ `expand_inventory()` と値段・断る理由 ／ `move_inventory_slot()` ／ `discard_inventory_slot()` ／ ページの5本 ／ `get_inventory_slot_layout()`（⚠ 穴つき）／ `get_inventory_slots_used()` ／ `_validate_inventory_config()`（E135） |
| 画面 | ⚠ 持ち物の右の紙の「捨てる」（`belongings_detail` → `warehouse_screen._on_discard_requested()`）だけ。⚠ 一覧は `get_inventory_slot_entries()` を読む |
| 設定 | ⚠ `InventoryConfig`（`resources/balance/configs/inventory_config.gd` / `.tres`）→ `Balance.inventory`（`balance.gd`・`balance.tscn`） |
| セーブ | ⚠ `INVENTORY_ORDER`（並び）・`INVENTORY_EXTRA_SLOTS`（買った枠） |
| 報告書 | ⚠ 「%s ×%d は持ち物が満杯で置いてきた」（`REPORT_LEFT_BEHIND`） |

⚠ ダンジョンの鞄（`DUNGEON_RUN.bag`・「鞄が満杯」）は**別の器**＝触らない。

---

## 3. ⚠ 変わるはずの数字

> ⚠ `grep get_inventory_free_slots` が **8 → 0 件**、⚠ 「捨てる」（`ui_warehouse_discard`）が **0 件**、
> ⚠ 報告書の「持ち物が満杯で置いてきた」が **0 件**、⚠ `Balance.inventory` が **0 件**になるはず。

---

## 4. 作り方

- ⚠ **判定を消す**：⚠ 上の6つの口から容量の判定を外す（⚠ ほかの判定はそのまま）。⚠ `add_to_inventory()` は渡された数をそのまま入れる
- ⚠ **持ち帰り**：⚠ 持ち帰る品は全部入る＝`left_behind` を戻り値と報告書から外す
- ⚠ **並び**：⚠ `get_inventory_slot_entries()` は `INVENTORY_ORDER` の順に、⚠ 無いものは後ろへ（⚠ 綴り順）。⚠ 長さの上限と空きマスの穴は持たない。⚠ 鍵は書かない（⚠ 書く口だった `move_inventory_slot()` を消す）＝前のセーブの並びはそのまま読む
- ⚠ **消す口**：§2 の「口」の行（⚠ `get_inventory_slot_entries()` と `_slot_entry_of_key()` は残す）
- ⚠ **捨てる**：⚠ 持ち物の右の紙の「捨てる」・確かめの窓・`ja.csv` の `ui_warehouse_discard*`
- ⚠ **設定**：⚠ `InventoryConfig` の `.gd` / `.tres` を消し、⚠ `Balance` の欄と `balance.tscn` の行を消す。⚠ 消したあと `uid_cache.bin` を消して `--import`（AGENTS.md）
- ⚠ **セーブ**：⚠ `INVENTORY_EXTRA_SLOTS` は鍵だけ残る（⚠ 読む人が居なくなる＝前のセーブを壊さないため。⚠ 「2い」と同じ扱い）
- ⚠ **検査**：⚠ `scenario=inventory` のマスを数える手を、⚠ 「何個入れても全部入る」に書き直す

---

## 5. 完了条件

| | 何で見るか |
|---|---|
| ログ | ⚠ §3 の4つの `grep` が 0 件 ／ ⚠ `inventory`：装備を 600 本入れても全部個体になる・宝箱は持ち物の数に関係なく開く ／ ⚠ `ui_flow`：持ち物の右の紙に「捨てる」が無い ／ ⚠ `--import` と全検査で赤0 |
| 画面 | ⚠ `shot` の持ち物（`32` `33`）・報告書（`49`） |

## 6. 止まる条件

- ⚠ `Balance` の欄を消したあと、⚠ ほかの Config が `null` になったら（⚠ AGENTS.md「移動したあとは Balance の各欄を読むシナリオを回す」）止めて報告
