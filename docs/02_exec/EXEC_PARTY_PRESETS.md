# EXEC — **パーティ選択画面とプリセット**（段階7）

`PLAN_IMPLEMENTATION.md` 3章の段階7。仕様の正は **`GAME_DESIGN.md` 5-5**（プリセット）と **13章「パーティ選択画面でできること」**、および **7-7 の末尾**（ルーンの移動量はキャラプリセットに含める）。

**このファイルには仕様の本文を書かない。** 決定と、実際に触る場所と、完了条件だけを書く。

---

## 0. 人間による決定事項（**本文と矛盾する場合こちらが優先**）

### 0-1. 前の回で決まっていたもの（2026-08-23・`NEXT_STEPS` §1-2）

| # | 決定 |
|---|---|
| **1** | **プリセットは10個**（固定本数。増やす仕組みは作らない） |
| **2** | **プリセットが持つのは「メンバー」「スキル枠」「装備」** |
| **3** | **専用画面を作る**（`adventure_select` の中を作り替えるのではない） |
| **4** | **切り替えは戦闘前でも拠点でもできる**（どちらか片方ではない） |

### 0-2. この回で決まったもの（2026-08-23・**着手前に確認した**）

⚠ **決定1・2 は `GAME_DESIGN.md` 5-5 と食い違って読めた**（5-5 は「2階層・参照方式」、口頭は平坦に読める）。**`EXEC_SKILL_SELECT.md` §12-6 と同じ形の事故になりかけたので、着手前に確認した。**

| # | 決定 |
|---|---|
| **5** | ⚠ **2階層で組む**（`GAME_DESIGN` 5-5 のまま）。⚠ **「10個」＝編成プリセットの数。「中身はメンバー・スキル枠・装備」＝参照先のキャラプリセットが持つもの**、と読む。**決定1・2 と矛盾しない** |
| **6** | ⚠ **キャラプリセットが持つのは 5-5 の4項目すべて**：**割り振りポイント（`nodes`）／スキル枠／パッシブ枠／装備一式**。⚠ **ルーンの移動量は器だけ用意し、今回は作らない**（段階8） |
| **7** | ⚠ **装備の取り合いは「奪う」。** 他のキャラが装備中の個体は**外してから着ける**。⚠ **何を誰から外したかを画面に出す**。⚠ **既に分解されて存在しない個体は、その枠だけ空にして続行**し、これも画面に出す |
| **8** | ⚠ **プリセットは「現在の状態を焼く」形。** 「保存」を押した時点の状態を書き写し、「適用」で書き戻す。⚠ **プリセットの中身を画面で1項目ずつ編集する機能は作らない**（ギルドの育成・装備画面がその役） |

### 0-3. 設計役が置いた前提（**違ったら言ってください。覆してよい**）

§13 に「僕が見ていない決め」として一覧にしてある。**そちらを見ること。**

---

## 1. 着手前に確認した実コード（2026-08-23・`grep` 済み）

⚠ **`NEXT_STEPS` §1-3 の前提が1つ実コードと違っていた**（**ズレ28**。§12 に報告）。

| | 事実 | どこ |
|---|---|---|
| ⚠ **装備は `inventory` を通らない** | `add_to_inventory()` は `_is_equipment_item()` なら `_create_equipment_instance()` を呼んで **early return** する | `game_manager.gd:472-483` |
| ⚠ **装備の一意キーは `instance_id`** | `eq_N` の形。採番は `next_equipment_instance_id` | `game_manager.gd:1451-1471` |
| ⚠ **`growth.equipment[slot]` は `instance_id` を持つ**（`item_id` ではない） | ⚠ **だからプリセットは `instance_id` を持てば一意に指せる。「同じ `item_id` の個体を区別できない」問題は存在しない** | `game_manager.gd:1736-1738` |
| **誰が装備しているか** | `_equipped_owner(instance_id)` が全 `character_growth` を舐めて返す。`""` なら未装備 | `game_manager.gd:1481-1495` |
| **枠の仕組みは1本** | `_slot_spec(kind)` がスキル枠とパッシブ枠を切り替える。⚠ **3種類目を作らないこと** | `game_manager.gd:2681-2694` |
| **割り振りポイント** | `nodes` は解放済みノードIDの配列。⚠ **総ポイントは `level - 1`（＋上限で+1）から引く**ので、レベルが下がることは無い | `game_manager.gd:2495-2514` |
| **振り直しは無料** | `reset_stat_nodes()` は `nodes` を空にするだけ | `game_manager.gd:2625` |
| **編成を書く唯一の口** | `set_party_member(index, character_id)`。⚠ **同じキャラが別の枠に居ると「交換」する** | `game_manager.gd:2787` |
| **編成の画面** | 専用画面は無く `adventure_select.gd` の `_build_party_row()`（60行）の中 | `adventure_select.gd:60-153` |
| **候補の変換表** | `_party_candidates` は「項目番号 → `character_id`」。⚠ **項目番号をIDに使わない** | `adventure_select.gd:28-31` |
| **プリセットは0件** | `GameStateKeys` にも `_empty_state_template()` にも該当のキーが無い | — |

---

## 2. 状態の設計

### 2-1. 増えるトップレベルキーは**2つだけ**

```
character_presets : {character_id: [キャラプリセット × CHARACTER_PRESET_COUNT]}
party_presets     : [編成プリセット × PARTY_PRESET_COUNT]
```

⚠ **`save_version` は 3 のまま上げない。** キーが増えるだけで、旧セーブは §2-4 の正規化で生える（`PLAN_IMPLEMENTATION.md:50`「キーが増えるだけのものは既存セーブで0埋め・空配列になればよい」／`EXEC_SKILL_SELECT.md` §9 と同じ理由）。

### 2-2. キャラプリセット（`character_presets.<character_id>[i]`）

```json
{
  "saved": true,
  "nodes": ["node_swordsman_atk_1"],
  "skills":   {"slots": ["skill_power_slash", ""]},
  "passives": {"slots": [""]},
  "equipment": {"head": null, "armor": "eq_3", "legs": null, "weapon": "eq_7", "accessory": null}
}
```

- ⚠ **`skills` / `passives` の内側のキーは `GROWTH_SKILL_SLOTS`（`"slots"`）を共用する。** 枠の仕組みが1本なので、キーも1本（`state_keys.gd:163-169` と同じ理由）
- ⚠ **`equipment` の値は `instance_id` か `null`。** `item_id` を入れない
- ⚠ **`saved` が `false` の枠は「空き」。** 中身は空のまま。⚠ **「中身が空かどうか」で空き判定をしないこと**（全部外した状態を焼いたら空になるが、それは保存済み）
- ⚠ **ルーンの移動量（段階8）はここに5つ目のキーとして入る。** 今回は作らない。⚠ **正規化（§2-4）が「知らないキーを捨てる」形になっていると、後から足したときに黙って消える。⚠ 知らないキーは残すこと**

### 2-3. 編成プリセット（`party_presets[i]`）

```json
{
  "saved": true,
  "slots": [
    {"character_id": "char_priest",    "preset_index": 0},
    {"character_id": "char_archer",    "preset_index": 2},
    {"character_id": "char_swordsman", "preset_index": 0}
  ]
}
```

- ⚠ **参照方式**（`GAME_DESIGN` 5-5）。**キャラ側のビルドを直すと、それを参照している全編成に反映される**
- ⚠ **`slots` は必ず `PARTY_SLOT_COUNT`（3）件で、`character_id` が重複しない**（`set_party_member()` の不変条件と揃える）
- ⚠ **`saved` が `false` なら `slots` は空配列**

### 2-4. 正規化（`_normalize_presets_from_save()`）

⚠ **`_sync_*_from_master()` の「毎回マスターで上書き」は真似ない**（編成と同じく、進捗ではなくプレイヤーの選択）。**やるのは形を揃えることと、指し先が消えたものを落とすことだけ。**

| 直すもの | どうする |
|---|---|
| キーが無い／型が違う | 空の器（`saved: false`）で埋める |
| 件数が足りない／多い | `CHARACTER_PRESET_COUNT` / `PARTY_PRESET_COUNT` に合わせて詰める・切る |
| マスターに無い `character_id` のキャラプリセット | ⚠ **その `character_id` のエントリごと落とす** |
| `nodes` にマスターに無いノードID | その要素だけ落とす |
| `skills` / `passives` の枠 | ⚠ **`_normalize_slots()` を使い回す。2本目を書かない** |
| `equipment` に `equipment_instances` に無い `instance_id` | ⚠ **`null` に戻す**（分解された個体。`_normalize_equipment_from_save()` と同じ扱い） |
| 編成プリセットの `slots` が3件でない／`character_id` が重複／`preset_index` が範囲外 | ⚠ **その1件を `saved: false` に戻す**（半端に直さない。`_ensure_party_members_from_master()` と同じ流儀） |
| 知らないキー | ⚠ **残す**（§2-2 の最後） |

- **直した件数を `print` で1行**（`_normalize_skill_slots_from_save()` と同じ形）
- ⚠ **`push_warning` を出さない。** 装備を分解したら参照が切れるのは**正常系**（`NEXT_STEPS` §4「正常系に警告を付けない」）
- **呼ぶ場所は2箇所**：`_ready()` の `_ensure_party_members_from_master()` の**直後**と、`load_state()` の `_normalize_equipment_from_save()` の**直後**
  - ⚠ **`load_state()` では `_normalize_equipment_from_save()` より後でなければならない**（消えた個体の判定に `equipment_instances` の正規化済みの姿が要る）
  - ⚠ **片方だけにしないこと。** `_ready()` だけだと「ロードでプリセットが空」、`load_state()` だけだと「新規開始で空」。**どちらもエラーが出ない**（`EXEC_PARTY_MEMBERS.md` §4-1 と同じ穴）

### 2-5. ⚠ 改名できないIDが増える

⚠ **`CLAUDE.md` 4番に足すもの**：プリセットは `character_id` / ノードID / スキルID / パッシブID を持つ。**改名するとそのプリセットの該当部分が黙って落ちる**（§2-4）。`instance_id` は状態側の採番なので改名の対象ではない。

⚠ **`E123` は使わない。** 「マスターに無いIDが混ざる」のは改名か分解のときだけで、正規化で落ちる。**検証を1本足すより、毎回洗うほうが安い**（`NEXT_STEPS` §1-3 の「どちらか決めること」への回答）。⚠ **番号は温存する。次に足す検証が `E123`。**

---

## 3. 触るファイルと担当

| ファイル | 何をするか | 担当 |
|---|---|---|
| `scripts/utils/state_keys.gd` | 定数を9つ追加（§4） | 設計役 |
| `autoload/game_manager.gd`（3940行） | 定数3・関数10（§5） | 設計役 |
| `scenes/adventure/party_preset_screen.gd` / `.tscn` | **新規**（§6） | 設計役 |
| `scenes/adventure/adventure_select.gd` | 導線を1本（§7-1） | 設計役 |
| `scenes/base/base_screen.gd` | 導線を1本（§7-2） | 設計役 |
| `localization/ja.csv` | 15行追記（§8）。⚠ **再インポートは人間** | 設計役 |
| `tests/debug_boot.gd` | `SCENARIOS` に `presets` を1行（§9） | 設計役 |
| `AGENTS.md` | 状態構造の表に2行 ＋ ⚠ **ズレ26 の `PENDING_CHESTS` の行も直す**（§12） | 設計役 |

⚠ **触らないファイル**：`.tres` 全部 ／ `characters.json` ／ `parties.json` ／ `stages.json` ／ `battle_controller.gd` ／ ギルドの7画面 ／ `save_manager.gd`。

⚠ **新しい `class_name` を作らない**（画面は `extends Control`）。**実装を前半・後半に割る必要は無い**（`NEXT_STEPS` §4）。

---

## 4. `state_keys.gd`（追記のみ）

```gdscript
# ============================================================
# プリセット（2階層。GAME_DESIGN.md 5-5 / EXEC_PARTY_PRESETS.md）
# ============================================================

# キャラプリセット：{character_id: [{saved, nodes, skills, passives, equipment}]}
# ⚠ 編成プリセットは「誰の、どの番号か」を参照で持つ（GAME_DESIGN 5-5）。
#   キャラ側を直すと、それを参照している全編成に反映される。
# ⚠ equipment の値は instance_id（item_id ではない）。個体は1つしか無いので、
#   適用したときに他のキャラから外れる（EXEC_PARTY_PRESETS.md 決定7）。
# ⚠ 中身はIDだけ。効果値はマスターから毎回引く（CLAUDE.md 4番）。
#   代償として character_id / ノードID / スキルID / パッシブID を改名できない。
# ⚠ ルーンの移動量（段階8）がここに5つ目のキーとして入る。正規化は知らないキーを消さない。
const CHARACTER_PRESETS: String = "character_presets"

# 編成プリセット：[{saved, slots: [{character_id, preset_index} × PARTY_SLOT_COUNT]}]
const PARTY_PRESETS: String = "party_presets"

# プリセット1件の中身
const PRESET_SAVED: String = "saved"
const PRESET_NODES: String = "nodes"
const PRESET_SKILLS: String = "skills"
const PRESET_PASSIVES: String = "passives"
const PRESET_EQUIPMENT: String = "equipment"

# 編成プリセットの1枠
const PRESET_SLOTS: String = "slots"
const PRESET_CHARACTER_ID: String = "character_id"
const PRESET_INDEX: String = "preset_index"
```

⚠ **`PRESET_SKILLS` / `PRESET_PASSIVES` の内側のキーは `GROWTH_SKILL_SLOTS` を使い回す。** 定数を増やさないこと。
⚠ **件数の定数（10 / 3）はここに置かない。** バランス数値ではなく構造なので `GameManager` 側（`SKILL_SLOT_COUNT` と同じ扱い。§5-1）。

---

## 5. `game_manager.gd`

### 5-1. 定数

```gdscript
# 編成プリセットの本数（人間の決定・2026-08-23。固定本数。増やす仕組みは作らない）。
# ⚠ .tres に置かない。バランス数値ではなく構造（SKILL_SLOT_COUNT と同じ扱い）。
const PARTY_PRESET_COUNT: int = 10

# 1キャラあたりのキャラプリセットの枠数。
# ⚠ 3 は設計役が置いた数（§13 の 1）。GAME_DESIGN 5-5 は「キャラごとに複数」としか書いていない。
const CHARACTER_PRESET_COUNT: int = 3
```

### 5-2. 新設する関数（10本）

| 関数 | 戻り値 | 中身 |
|---|---|---|
| `get_party_preset_count()` | `int` | `PARTY_PRESET_COUNT`。⚠ **画面が 10 と書かないために公開する** |
| `get_character_preset_count()` | `int` | `CHARACTER_PRESET_COUNT` |
| `get_party_presets()` | `Array` | 10件の複製。⚠ **参照を返さない** |
| `get_character_presets(character_id)` | `Array` | 3件の複製。⚠ **無ければ空の器3件を返す**（画面が件数を数えられるように） |
| `save_character_preset(character_id, index)` | `bool` | ⚠ **現在の `growth` から `nodes` / `skills` / `passives` / `equipment` を焼く**（決定8） |
| `save_party_preset(index, slots)` | `bool` | `slots` は `[{character_id, preset_index} × 3]`。⚠ **画面が渡す**（§6-3） |
| `clear_party_preset(index)` | `bool` | `saved: false` に戻す |
| `get_party_preset_apply_report(index)` | `Dictionary` | ⚠ **判定だけ。状態を触らない**（`can_unlock_stat_node()` と同じ形）。§5-4 |
| `apply_party_preset(index)` | `Dictionary` | ⚠ **適用。戻り値は §5-4 と同じ形** |
| `_normalize_presets_from_save()` | `void` | §2-4 |

⚠ **`clear_character_preset()` は作らない。** キャラプリセットは上書きだけで足りる（消す動機が無く、消せると編成プリセットの参照だけが宙に浮く）。

### 5-3. `save_character_preset()` が焼くもの

```
nodes     … get_stat_nodes(character_id)
skills    … get_selected_skills(character_id)              ⚠ get_battle_skills() ではない
passives  … get_selected_passives(character_id)
equipment … 5部位ぶん get_equipped_instance_id()。"" は null に直す
```

⚠ **`get_battle_skills()` を焼かないこと。** あれは未選択の枠を候補の先頭で埋めた**確定版**で、焼くと「選んでいないものが選んだことになる」。**プリセットは「未選択」も含めてそのまま持つ。**

### 5-4. 適用（**このタスクの本題**）

⚠ **状態を変える前に全部の判定を終える**（`CLAUDE.md` 6番）。⚠ **`get_party_preset_apply_report()` と `apply_party_preset()` は同じ判定を2本書かない。** `apply_party_preset()` が先に `get_party_preset_apply_report()` を呼び、`ok` が `false` なら何もせず返す。

戻り値の形：

```gdscript
{
  "ok": bool,
  "reason": String,      # ok が false のときだけ。翻訳キー
  "members": Array,      # 適用後の3人（character_id）
  "conflicts": Array,    # [{from_character_id, to_character_id, slot, instance_id}] … 奪ったもの
  "missing": Array,      # [{character_id, slot, instance_id}] … 個体が消えていて空にしたもの
  "nodes_skipped": Array # [{character_id, reason}] … ポイント不足などで nodes を当てなかったキャラ
}
```

**判定（この順で。1つでも欠けたら `ok: false` で即返す）**

1. `index` が `0..PARTY_PRESET_COUNT-1` か
2. その編成プリセットが `saved` か（`ui_party_preset_unsaved`）
3. `slots` が3件で、`character_id` が全部マスターに居て、重複が無いか
4. 参照先のキャラプリセットが3件とも `saved` か（`ui_party_preset_ref_unsaved`）

**ここから「当てられるものを数える」（まだ状態を触らない）**

5. 各キャラの `nodes`：⚠ **合計コストが `get_stat_node_total_points()` を超えていないか**、⚠ **前提条件がその集合の中で閉じているか**。⚠ **どちらか欠けたら、そのキャラの `nodes` だけ当てない**（`nodes_skipped` に積む）。**プリセット全体は弾かない**
   > ⚠ **レベルを上げてから焼いたプリセットを、別のキャラに当てることは無い**（キャラプリセットはキャラごとなので）。**それでも判定が要るのは、`character_nodes.json` のコストを後から上げた場合に破綻するため。**
6. 各キャラの `equipment` の `instance_id`：`equipment_instances` に無ければ `missing` に積み、その枠は `null` にする
7. 残った `instance_id` の現在の持ち主を `_equipped_owner()` で引く。⚠ **プリセットの3人以外が持っていれば `conflicts` に積む**（決定7＝奪う）
   > ⚠ **編成の3人の間で移るぶんは積まない**（§13 の 11）。3人とも同じ適用でビルドを当て直しているので、焼いたときの意図どおり。⚠ **積むと、普通の切り替えのたびにメッセージが出る。**
8. ⚠ **同じ `instance_id` を2人が要求していたら、枠の若いほうが勝つ。** 負けたほうは `missing` ではなく `conflicts` に積み、`from_character_id` に相手を入れる
   > ⚠ **キャラプリセットは独立に焼けるので、これは正常に起こりうる**（剣士のビルド2と弓のビルド1が同じ指輪を指す）。**赤を出さない。**

**ここから状態を変える（`apply_party_preset()` だけ）**

9. ⚠ **奪う側を先に外す。** `conflicts` と、当てる本人の5部位ぶんを `unequip_instance()` で全部外してから着ける。⚠ **外す前に着けると `_equipped_owner()` が別人を返して `equip_instance()` が弾かれる**（`game_manager.gd:1728-1731`）
10. 編成を書く：⚠ **`set_party_member(i, character_id)` を枠0→1→2 の順に3回。**
    > ⚠ **`set_party_member()` は交換をするが、目標の3人が互いに違えば、この順で呼べば必ず目標どおりになる**（枠0を確定させると、以降の交換は枠1以上しか触らない）。⚠ **直接 `_state[PARTY_MEMBERS]` を書かないこと**（書く口は1本）
11. 各キャラに `nodes`（`nodes_skipped` に居ないキャラだけ）／`skills`／`passives`／`equipment` を当てる
    - ⚠ **`nodes` は `unlock_stat_node()` を1つずつ呼ばない。** 呼ぶ順で前提条件に引っかかる。**検証（5）を通した配列をそのまま `growth[GROWTH_NODES]` に書く**
    - ⚠ **`skills` / `passives` は `select_skill()` を呼ばない。** あれは「別の枠に居たら交換」をするので、配列をそのまま当てるのと結果が変わる。**`_normalize_slots()` を通した配列をそのまま書く**
    - ⚠ **`equipment` は `equip_instance()` を通す**（装備品か・部位が合うか・他人が持っていないかを見る唯一の口。ここだけは通す）
12. ⚠ **`character_growth_changed` は1キャラにつき1回にまとめる。** `_write_growth()` を部位ごとに呼ぶと5本飛び、⚠ **`await` を持つ倉庫画面が二重に並ぶ**（`AGENTS.md`「再描画は await を持たせない」）

⚠ **シグナルは足さない。** 適用後に画面が自分で描き直す（`set_party_member()` の注記と同じ）。⚠ **`party_changed` を足すのは、編成を聞く画面が3つ目になったとき。**

---

## 6. 画面（`scenes/adventure/party_preset_screen`）

⚠ **新しいフォルダを作らない。** `scenes/adventure/`（`AGENTS.md` のフォルダ構造では「冒険選択・戦闘」。1画面でしか使わないので画面のフォルダに置く）。

⚠ **`GAME_DESIGN` 13章「パーティ選択画面でできること」に従う**：プリセットの選択 ／ メンバーの差し替え ／ スキル選択・ポイント割り振りの変更 ／ ⚠ **装備の変更はできない（ギルドで行う）**。
> ⚠ **「プリセットの適用で装備が変わる」ことは 13章と矛盾しない。** ⚠ **禁じられているのは「この画面で装備を選ぶ欄を出すこと」。⚠ 装備の一覧・付け替えのUIをこの画面に作らないこと**（§13 の 4）。

### 6-1. 構成

```
[タイトル]                                    ui_party_preset_title
[編成プリセット]                              ui_party_preset_presets_header
  行 × PARTY_PRESET_COUNT
    [Label 編成%d] [Label 中身の要約 or 空き] [適用] [保存] [消す]
[いまの編成]                                  ui_party_preset_members_header
  行 × PARTY_SLOT_COUNT
    [OptionButton キャラ] [OptionButton ビルド%d] [焼く]
[Label メッセージ]                            ← 適用結果（奪った・消えていた）
[戻る]
```

- ⚠ **枠数を `10` / `3` と書かない。** `GameManager.get_party_preset_count()` / `get_character_preset_count()` / `GameStateKeys.PARTY_SLOT_COUNT` を回す
- ⚠ **モーダルを書かない**（`AGENTS.md` の実例：モーダルの検証で1タスク溶かしている）。**メッセージは Label に出す**
- ⚠ **再描画に `await` を持たせない。** `remove_child()` してから `queue_free()`（`CLAUDE.md` 5番）
- ⚠ **`OptionButton` の項目番号を `character_id` に使わない。** `adventure_select.gd:28-31` と**同じ変換表を持つ**
- ⚠ **候補の集め方は `adventure_select._collect_party_candidates()` と同じ**（`characters.json` の記述順・`OS.is_debug_build()` で検証用3体）。⚠ **2本目を書かず、`adventure_select.gd` から `GameManager` に移す**（§7-3）
- **等幅の列**：`.tscn` の `Scroll` に `horizontal_scroll_mode = 0`。⚠ **これが無いと子の `SIZE_EXPAND_FILL` が効かない**（`EXEC_SKILL_SELECT.md` §8-2。実機で1回踏んでいる）

### 6-2. 「いまの編成」の3行

- **キャラの `OptionButton`** … 押したら `GameManager.set_party_member(slot_index, id)` → 3行とも作り直す（`adventure_select` と同じ）
- **ビルドの `OptionButton`** … ⚠ **押しただけでは状態を触らない。** 「編成プリセットを保存したときに、どの番号を参照するか」と「焼く先」を決めるだけ
  > ⚠ **`EXEC_SKILL_SELECT.md` §8-1 と同じ形**（枠を押しただけでは状態を触らず、`▶` が動くだけ）。**あそこで「押す＝解除」にして踏んでいる。**
- **「焼く」** … `save_character_preset(character_id, 選んでいる番号)`。⚠ **押した行のキャラだけ**
- ⚠ **未保存の番号も選べる**（焼く先として要る）。**ラベルに「（空き）」を付ける**

### 6-3. 編成プリセットの行

| ボタン | やること |
|---|---|
| **適用** | `apply_party_preset(index)` → 戻り値をメッセージに出す（§6-4）→ 全部作り直す |
| **保存** | ⚠ **「いまの編成」3行の（キャラ, ビルド番号）をそのまま `save_party_preset(index, slots)` に渡す**（決定8＝現在の状態を焼く） |
| **消す** | `clear_party_preset(index)` |

- **要約の表示** … `保存済み` なら3人の名前（`tr(name_key)`）＋ビルド番号。`未保存` なら `ui_party_preset_empty`
- ⚠ **「適用」を `disabled` にするのは「未保存」のときだけ。** ⚠ **参照先のビルドが未保存かどうかで `disabled` を出し分けない**（押して理由が出るほうが分かる。判定は `get_party_preset_apply_report()` の `reason`）

### 6-4. 適用結果のメッセージ

⚠ **黙って強くなったり弱くなったりさせない**（決定7）。

```
ok: false        → tr(reason)
conflicts が空でない → tr("ui_party_preset_taken") % [相手の名前, 装備の名前]  を1件1行
missing が空でない   → tr("ui_party_preset_missing") % [キャラ名, 部位名]      を1件1行
nodes_skipped が空でない → tr("ui_party_preset_nodes_skipped") % キャラ名
全部空            → tr("ui_party_preset_applied")
```

---

## 7. 導線（**決定4：戦闘前でも拠点でも**）

⚠ **画面は1つ。導線が2本**（`EXEC_PARTY_MEMBERS.md` §0 の「ギルドにも同じものを置かない」は**同じ実装を2つ作るな**という意味であって、入口を2つにするなという意味ではない）。

### 7-1. 冒険選択（戦闘前）

⚠ **`_build_party_row()` の `OptionButton` 3つを消して、ボタン1つに置き換える**（決定3「専用画面を作る」）。

- ⚠ **`_make_party_slot()` / `_on_party_slot_selected()` / `_collect_party_candidates()` / `_party_candidates` を消す**（画面側へ移る。§7-3）
- **残すのは**：`ui_adventure_party` の見出し ＋ **いまの3人の名前を並べた Label** ＋ **「編成」ボタン**（押すと `party_preset_screen` へ）
- ⚠ **`_add_stage_row()` / `_add_debug_stage_row()` / `_stage_rows` を触らない**
- ⚠ **`.tscn` を触らない。** コードで作って `StageList` の手前に差し込む形は変えない

### 7-2. 拠点

⚠ **`base_screen.tscn` を触らない。** `NavigationButtons` に**コードで `PrimaryButton` を1つ足す**（`adventure_select._build_party_row()` と同じ形）。

- ⚠ **`UNLOCKED_SCREENS` に新しい `screen_id` を足さない。** この画面は `skill_select_screen` と同じ「下位画面」で、解放の対象ではない（段階9で見直す）
- ⚠ **`_screen_paths`（`base_screen.gd:20`）に足さないこと。** あれは `screen_id` → パスの表で、解放判定を通る道

### 7-3. `_collect_party_candidates()` を `GameManager` へ移す

⚠ **2画面が同じ候補一覧を要るようになったので、1本に寄せる**（`NEXT_STEPS` §2-5「同じ形の判定が散っていたら1本に寄せる」）。

```gdscript
# 編成に出せるキャラ。並び順は characters.json の記述順。
# ⚠ 検証用の3体はデバッグビルドでだけ出す。⚠ リリース前にこの分岐を消す（宿題16）。
# ⚠ 「所持しているキャラだけ」の概念はまだ無い。将来ここで絞る。
func get_party_candidates() -> Array[String]:
```

⚠ **`adventure_select.gd` 側は消す。** ⚠ **編集後に `grep -n "_collect_party_candidates" scenes/` が 0件であることを確認する**（`CLAUDE.md` 2番）。

---

## 8. `localization/ja.csv`（15行・末尾に追記）

⚠ **UTF-8（BOMなし・LF）。⚠ 再インポートは人間。**
⚠ **`ui_party_preset_` は新しい接頭辞**（§13 の 3）。画面名（`party_preset_screen`）と綴りを揃える（`ui_skill_select_` と同じ流儀）。

```
ui_party_preset_title,パーティ編成
ui_party_preset_presets_header,編成プリセット
ui_party_preset_members_header,いまの編成
ui_party_preset_slot,編成%d
ui_party_preset_build,ビルド%d
ui_party_preset_empty,空き
ui_party_preset_apply,適用
ui_party_preset_save,保存
ui_party_preset_burn,焼く
ui_party_preset_applied,適用しました
ui_party_preset_unsaved,このプリセットは空です
ui_party_preset_ref_unsaved,参照しているビルドが空です
ui_party_preset_taken,%s から %s を外しました
ui_party_preset_missing,%s の%sが見つかりませんでした
ui_party_preset_nodes_skipped,%s の割り振りは当てられませんでした
```

⚠ **足さないもの**：`ui_common_back`（既にある・15行目）／ キャラ名（`ui_battle_char_*` は6件とも既にある）／ 部位名（`ui_equipment_slot_*` を使い回す。⚠ **在ることを `grep` で確かめてから使う**）。

---

## 9. `tests/debug_boot.gd`（`SCENARIOS` に1行）

⚠ **シーンを増やさない。** `materials` / `parts` / `drops` と同じ `KIND_REPORT` の枝。⚠ **プリセットは戦闘に1行も出ない**（適用した結果が戦闘に出るだけ）。

```gdscript
"presets": {
    "kind": KIND_REPORT,
    "report": REPORT_PRESETS,
    "note": "プリセット2階層 / 焼く→適用 / 装備の取り合い（奪う）/ 正規化",
},
```

- `REPORT_PRESETS` の定数を1つ、`_report_presets()` を1本足す（⚠ **`_ready()` の `elif` に1行**）
- ⚠ **`SaveManager` を呼ばない**（`debug_boot.gd:526-528`）

`_report_presets()` が出すもの（**§11-A がこれを読む**）：

1. 器の件数（`get_party_preset_count()` / `get_character_preset_count()` / 各キャラのプリセット件数）
2. 焼く → 中身を出す（⚠ **`nodes` / `skills` / `passives` / `equipment` の4項目が入っているか**）
3. **取り合い**：⚠ **キャラAに装備を着け、キャラBのプリセットに同じ `instance_id` を書いてから適用**し、`conflicts` が1件出て**Aから外れている**ことを出す
4. **消えた個体**：⚠ **焼いたあとに `dismantle_equipment()` して適用**し、`missing` が1件出て**その枠が空**になることを出す
5. **正規化**：⚠ **`character_presets` を2通りに壊してから `_normalize_presets_from_save()` を呼び、直った件数を出す**
   - ⚠ **壊し方は2箇所**（`NEXT_STEPS` §3-1「足した検証は2箇所で壊して確かめる」）：**(a) 件数を1件に減らす ／ (b) `equipment` に `eq_99999`（存在しない個体）を入れる**
   - ⚠ **本番のデータを一時的に壊すのではなく、シナリオの中でメモリ上の状態を壊す。** ⚠ **だから `git diff` は最初から空のまま**（元に戻す作業が要らない）

---

## 10. ⚠ 事故りやすい箇所

| | 内容 |
|---|---|
| **10-1** | ⚠ **`GAME_DESIGN` 5-5 は2階層。** 平坦に作ると `DEMO_CHECKLIST:180`（キャラ側を直すと全編成に反映）が満たせず作り直しになる。⚠ **§0-2 の決定5 が根拠** |
| **10-2** | ⚠ **プリセットの `equipment` は `instance_id`。** `item_id` を入れると、同じ装備の2本目と区別できなくなる（⚠ **ズレ28。§12**） |
| **10-3** | ⚠ **適用は判定を全部終えてから状態を触る**（`CLAUDE.md` 6番）。⚠ **奪う側を先に外さないと `equip_instance()` が弾かれる** |
| **10-4** | ⚠ **`set_party_member()` を通す**（編成を書く唯一の口）。⚠ **`_state[PARTY_MEMBERS]` を直接書かない** |
| **10-5** | ⚠ **`select_skill()` / `unlock_stat_node()` を1件ずつ呼ばない。** どちらも「交換」「前提条件」で結果が呼ぶ順に依存する。⚠ **検証を通した配列をそのまま書く** |
| **10-6** | ⚠ **`get_battle_skills()` を焼かない**（§5-3）。未選択が選択済みになる |
| **10-7** | ⚠ **`character_growth_changed` を1キャラ1回にまとめる。** 5本飛ばすと倉庫画面が二重に並ぶ |
| **10-8** | ⚠ **`_normalize_presets_from_save()` を `_ready()` と `load_state()` の両方から呼ぶ。** 片方だけだと片方が空になり、⚠ **どちらもエラーが出ない** |
| **10-9** | ⚠ **正規化は知らないキーを消さない。** 段階8のルーンの移動量がここに入る |
| **10-10** | ⚠ **`push_warning` を出さない。** 分解で参照が切れるのは正常系 |
| **10-11** | ⚠ **`OptionButton` の項目番号を `character_id` に使わない**（`adventure_select.gd:141`） |
| **10-12** | ⚠ **大きな範囲の文字列置換をしない。** `Edit` で1箇所ずつ（`NEXT_STEPS` §2-4。715行消した事故） |
| **10-13** | ⚠ **`ja.csv` は UTF-8（BOMなし）。** 再インポートは人間 |
| **10-14** | ⚠ **この画面に装備の一覧・付け替えUIを作らない**（`GAME_DESIGN` 13章） |

---

## 11. 完了条件

⚠ **「どこを見るか」で3つに分ける。⚠ 同じことを2箇所に書かない。⚠ ログとファイルは設計役・画面は人間**（`AGENTS.md`「誰が取るか」）。

### 11-0. 事前チェック（**設計役・人間に渡す前に終わっている**）

- ✅ `--check-only --script` で新規・変更した `.gd` の `Parse Error` が **0件**（⚠ **`Identifier not found` は Autoload 未読み込み。構文エラーではない**）
- ✅ ⚠ **全シナリオ24本（`training` を除く。⚠ `presets` と `layout` が増えて22 → 24本）をヘッドレスで1回ずつ回し、`^(ERROR|WARNING)` で絞った赤黄が増えていない**
  - ⚠ **実測（2026-08-23・レイアウトを直したあとに回し直した）：23本が「黄1本」・`drops` だけ「黄2本」。⚠ 赤は0本**
  - ⚠ **正常な黄は `skill_dbg_dot_odd`**。⚠ **`drops` の2本目は `grant_chest: chests.json に無い chest_id`（意図的に呼んでいる）**
  - ⚠ **`training` を回さない**（窓あり専用・終わらない。⚠ **2026-08-23に10分溶かしている**）

### 11-A. ログ（設計役が `godot.log` を読む）

⚠ **画面に出ない内部の値と、UIから到達できない経路だけ。**

1. 起動時に `[GameManager] init complete.` が出て、赤が出ない
2. `[GameManager] _normalize_presets_from_save() -> N fixed (...)` が出る。⚠ **新規開始では 10 fixed**（器を作ったぶん）。⚠ **2回目以降は 0 fixed**（形が正しい＝空振りする）
3. `scenario=presets` で `_report_presets()` が §9 の1〜5を全部出す
4. **取り合い**（§9 の3）：`conflicts` が **1件**で、`from_character_id` が元の持ち主。⚠ **適用後にその持ち主の当該スロットが `""` になっている**
5. **消えた個体**（§9 の4）：`missing` が **1件**で、⚠ **適用後にその枠が `null`**。⚠ **赤も黄も出ない**
6. **正規化**（§9 の5）：⚠ **2通りの壊し方それぞれで、直した件数が 0 でない**
7. `apply_party_preset()` の失敗が理由つきで出る（`-> false (ui_party_preset_ref_unsaved)` 等）

### 11-B. ファイル（`save_slot_0.json` をテキストエディタで開く）

8. `"character_presets"` と `"party_presets"` が入っている
9. `"party_presets"` が **10件**、各キャラの `"character_presets"` が **3件**
10. 焼いた編成プリセットの `slots` が **3件**で、⚠ **`{"character_id": ..., "preset_index": ...}` の形**（⚠ **キャラの中身が複製されていないこと。ここが「参照方式」の確認**）
11. キャラプリセットの `equipment` の値が **`eq_N` の文字列か `null`**（⚠ **`item_id` になっていたら §10-2**）
12. ⚠ **数値に `.0` が付いていない**（`preset_index` が `0.0` なら `int()` 漏れ・`CLAUDE.md` 3番）
13. `"save_version"` が **3 のまま**

### 11-C. 画面（**人間が実機で操作する**）

⚠ **観測できる合図で書いてある。時間では書いていない。**

14. **冒険選択**を開くと、⚠ **`OptionButton` 3つではなく、3人の名前と「編成」ボタン**が出る
15. **拠点**の下の並びに「編成」ボタンが増えている。⚠ **押すと 14 と同じ画面が開く**
16. 画面に **編成プリセットが10行**、**「いまの編成」が3行**出る。⚠ **10行とも「空き」と読める**
17. 「いまの編成」のキャラを選び直すと**その枠の表示が変わる**。⚠ **既に別の枠に居るキャラを選ぶと2つの枠が入れ替わる**（同じキャラが2枠に並ばない）
18. **ギルド → 育成でスキルを1つ選び、装備を1つ着けてから**この画面に戻り、1行目の「焼く」→ 編成プリセット1行目の「保存」を押すと、⚠ **1行目が「空き」から3人の名前に変わる**
19. **ギルドでスキルと装備を変えてから**戻って「適用」を押すと、⚠ **18 で焼いた状態に戻っている**（ギルドの育成・装備画面で確認する）
20. ⚠ **他のキャラに着けた装備を指すプリセットを適用すると、「◯◯ から □□ を外しました」がメッセージに出る**。⚠ **ギルドでそのキャラを見ると本当に外れている**
21. ⚠ **ギルドで装備を分解してから適用すると、「◯◯ の××が見つかりませんでした」が出て、その部位だけ空**（他の部位は着く）
22. ⚠ **空きのプリセットの「適用」は押せない**（`disabled`）
23. ⚠ **参照しているビルドが空のプリセットの「適用」は押せて、押すと理由が出る**（何も変わらない）
24. **キャラのビルドを別の番号で2つ焼き、2つの編成プリセットが同じキャラの違う番号を指す**状態にして交互に適用すると、⚠ **スキルと装備が両方とも切り替わる**
25. ⚠ **1つのビルドを2つの編成プリセットから参照させ、そのビルドを焼き直すと、両方の編成に反映される**（⚠ **これが「参照方式」の本題。`DEMO_CHECKLIST:180`**）
26. そのまま `stage_1` に挑むと、⚠ **適用した3人が、適用したスキルで出てくる**
27. 拠点に戻る／ゲームを終了して起動し直しても、⚠ **プリセットが残っている**
28. ⚠ **この画面に装備を選ぶ欄が無い**（`GAME_DESIGN` 13章）

### 11-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

⚠ **UIから到達できない。**

- `party_presets` を手で 3件に減らしてロード → 10件に戻る
- `slots` に同じ `character_id` を2つ書いてロード → その1件だけ `saved: false` に戻る
- `preset_index` に `9` を書いてロード → その1件だけ `saved: false` に戻る
- `character_presets` にマスターに無い `character_id` を書いてロード → そのエントリごと消える
- キャラプリセットに知らないキー（`"rune_move"`）を書いてロード → ⚠ **残る**（段階8の器）
- `character_nodes.json` のコストを上げてから適用 → `nodes_skipped` に積まれ、⚠ **他の3項目は当たる**

---

## 12. ⚠ ドキュメントのズレ（**報告。勝手に直さない**）

| # | 内容 | どうする |
|---|---|---|
| **26** | `AGENTS.md`「GameManagerの状態構造」の `PENDING_CHESTS` の行が `{chest_id, chest_type, ...}` だが、実装は `{instance_id, chest_id, ...}`（`state_keys.gd:96`） | ⚠ **この回で直す**（`AGENTS.md` を触る回になったため。`NEXT_STEPS` §2-1 の指示どおり） |
| **27** | `PLAN_IMPLEMENTATION.md:117` の段階8の依存が「3, 4」で **7 が無い**。`GAME_DESIGN` 7-7 は「移動量はキャラプリセットに含める」 | ⚠ **この回で「3, 4, 7」に直す**（段階7を通す回なので、依存が実在したことが確定した） |
| **28** | ⚠ **新規。** `NEXT_STEPS` §1-3 が「`inventory` は `item_id` がキーで、同じ `item_id` の個体を区別できない」と書いているが、⚠ **装備は `inventory` を通らない**（`add_to_inventory()` が early return）。⚠ **一意キーは `instance_id`** | ⚠ **`NEXT_STEPS` を書き換える回（§14）で直す。⚠ 実装は `instance_id` で組む** |

⚠ **未報告のズレは 0件。⚠ 次に見つけたものは 29 番。**

---

## 13. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め**）

⚠ **覆してよい。**

| # | 決めたこと | なぜ | 覆すと何が変わるか |
|---|---|---|---|
| **1** | ⚠ **キャラプリセットは1キャラ3枠** | `GAME_DESIGN` 5-5 は「キャラごとに複数」としか書いていない。編成が10本なので、3枠あれば組み合わせは足りる | `CHARACTER_PRESET_COUNT` の1行。⚠ **画面の行数が変わるだけ** |
| **2** | ⚠ **プリセットに名前を付けられない**（`編成1` / `ビルド1` の自動名） | 文字入力欄（`LineEdit`）を足すと、翻訳・保存・文字数制限が付いてくる。⚠ **規模を「中」に収めるため** | ⚠ **`ja.csv` の2行と `LineEdit` が要る。宿題に足してある**（§14） |
| **3** | ⚠ **翻訳キーの接頭辞を `ui_party_preset_` にした**（新しい領域） | `AGENTS.md` の接頭辞表に無い。画面名と綴りを揃える `ui_skill_select_` の流儀に寄せた | `ja.csv` の15行と画面の `tr()` |
| **4** | ⚠ **`GAME_DESIGN` 13章の「装備の変更はできない」を「装備を選ぶ欄を出さない」と読んだ** | ⚠ **決定2「プリセットは装備を持つ」と両立させるため。** 適用で装備が変わることまで禁じると、決定2 が成立しない | ⚠ **禁じるなら、プリセットから `equipment` を落とすことになる**（＝決定2 の取り消し） |
| **5** | ⚠ **`nodes` が当てられないときはそのキャラの `nodes` だけ飛ばし、プリセット全体は弾かない** | 全部弾くと「装備は当てたかったのに何もできない」になる | 「1つでも欠けたら全部弾く」に寄せられる |
| **6** | ⚠ **同じ個体を2人が要求したら、枠の若いほうが勝つ** | 決めておかないと結果が `Dictionary` の順に依存する | 「後ろが勝つ」にもできる。⚠ **どちらでも「決めてある」ことが重要** |
| **7** | ⚠ **`clear_character_preset()` を作らない**（上書きだけ） | 消せると、編成プリセットの参照だけが宙に浮く | 関数1本と画面のボタン1つ |
| **8** | ⚠ **拠点の導線をコード生成のボタンにした**（`.tscn` を触らない） | ⚠ **`.tscn` を触ると人間の作業が増える**（`EXEC_PARTY_MEMBERS.md` §0-2 と同じ判断） | 人間が Inspector で並べ直すなら `.tscn` に置ける |
| **9** | ⚠ **`E123` を使わず、正規化で洗う形にした** | ⚠ **`NEXT_STEPS` §1-3 が「どちらか決めること」と書いていた。** 検証を1本足すより毎回洗うほうが安い。**番号は温存した** | ⚠ **検証を足すなら `E123`** |
| **10** | ⚠ **`_collect_party_candidates()` を `GameManager` へ移した** | 2画面が同じ一覧を要るようになった（`NEXT_STEPS` §2-5） | ⚠ **移さないと候補の集め方が2本になる** |
| **11** | ⚠ **奪ったと報告するのは「編成の外のキャラから取るとき」だけ**（実装中に決めた。§5-4 の 7） | ⚠ **編成の3人の間で移るのは、3人とも同じ適用でビルドを当て直しているので焼いたときの意図どおり。** 積むと普通の切り替えのたびにメッセージが出る | 決定7 を文字どおり取るなら3人の間でも報告する。⚠ **1行（`not (owner in members)`）** |
| **12** | ⚠ **プリセットの中身のキーを `GROWTH_*` と共用した**（`PRESET_NODES` 等を新設しなかった） | 同じ値の定数を2組並べると片方だけ直したときに黙ってズレる。⚠ **おかげで `_normalize_slots()` をプリセットにもそのまま当てられた** | 別のキーにするなら定数4つと正規化の書き分けが要る |
| **13** | ⚠ **`get_equip_reject_reason()` を切り出し、`equip_instance()` を書き換えた** | 適用側が同じ判定を2本書かないため（`get_part_reject_reason()` と同じ形） | ⚠ **`equip_instance()` の失敗ログの文言が変わった**（理由は同じ） |
| **14** | ⚠ **`TransferKeys.RETURN_PATH` を足した** | 入口が2つあるので「戻る」の帰り先を来た側が渡す | 常に拠点へ帰す形にもできる |

---

## 14. 宿題に足すもの（`PROJECT_STATUS.md`）

- ⚠ **新**：**プリセットに名前を付けられない**（自動名。§13 の 2）
- ⚠ **新**：**キャラプリセットを消せない**（上書きだけ。§13 の 7）
- ⚠ **新**：⚠ **ルーンの移動量の欄が空**（段階8でキャラプリセットに5つ目のキーとして入る）
- ⚠ **新**：⚠ **`party_changed` シグナルをまだ足していない。** 編成を聞く画面が3つ目になったら足す（そのとき `AGENTS.md` のシグナル表にも1行）
- ⚠ **新**：⚠ **`CLAUDE.md` 4番の「改名できないID」に、プリセット経由で `character_id` / ノードID / スキルID / パッシブID が加わった**
- **宿題16**（リリース前に消すもの）：⚠ **`adventure_select._build_party_row()` の分岐** → ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**に**書き換える**（移動したため）
- ⚠ **ズレ28 を `NEXT_STEPS` に反映**（§12）

---

## 15. コミットメッセージ

```
feat(party): パーティ選択画面と2階層のプリセット
```

⚠ **`PROJECT_STATUS.md` の Git章の表に追記すること。**
⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階7の状態列を1行だけ直す**（完了の記録はあそこ1箇所）。

---

## 16. Ziva に渡せる部分

⚠ **無い。**

JSON の変更が**0件**（マスターデータを1つも触らない）。`ja.csv` の15行だけが単独で切り出せるが、⚠ **画面のコードと同時でないと「キーがそのまま表示される」以外に確認しようが無い**。**この回は設計役が全部書く。**

---

## 17. 実施結果（2026-08-23）

⚠ **画面は見ていない**（ヘッドレスは描画がダミー）。⚠ **以下は「取れたものだけ」。**

### 17-1. 触ったファイル

| ファイル | 変更 |
|---|---|
| `scripts/utils/state_keys.gd` | `CHARACTER_PRESETS` / `PARTY_PRESETS` / `PRESET_SAVED` / `PRESET_SLOTS` / `PRESET_CHARACTER_ID` / `PRESET_INDEX`（⚠ **中身の4キーは `GROWTH_*` を共用。§13 の 12**） |
| `scripts/utils/transfer_keys.gd` | `RETURN_PATH` |
| `autoload/game_manager.gd` | 定数・関数を追加。⚠ **`equip_instance()` を `get_equip_reject_reason()` 経由に書き換え**。**3940 → 約4600行** |
| `scenes/adventure/party_preset_screen.gd` / `.tscn` | **新規**（324行） |
| `scenes/adventure/adventure_select.gd` | ⚠ **`OptionButton` 3つ → 名前の表示＋「編成」ボタン**。⚠ **候補の一覧を `GameManager` へ移した** |
| `scenes/base/base_screen.gd` | 「編成」ボタンをコード生成で1つ |
| `localization/ja.csv` | **18行追記**（⚠ **`ui_party_preset_*` 17行 ＋ `ui_nav_party_preset`**。⚠ **§8 の15行から3行増えた**：`ui_party_preset_clear` / `ui_party_preset_broken` / `ui_nav_party_preset`） |
| `tests/debug_boot.gd` | `SCENARIOS` に `presets` ＋ `_report_presets()` ＋ `_character_outside_party()` / `_owner_of()` |

⚠ **マスターデータ（`.json`）と `.tres` は1件も触っていない。**

### 17-2. `grep` による確認

```
grep -rn "_collect_party_candidates" scenes/ → 0件（コメント1件のみ）
python で4スペース字下げを数える → 変更した7ファイルすべて 0 件
ja.csv → BOM なし・CR 0・427行 → 445行
```

### 17-3. ⚠ 実装中に見つけたこと（**指示書からの逸脱**）

1. ⚠ **「奪った」と報告する範囲を狭めた**（§13 の 11）。⚠ **最初の検証では編成の中のキャラで試して `conflicts=0` が出た。⚠ 検証のほうが間違いで、⚠ 編成の外のキャラで試すよう直した**
2. ⚠ **プリセットの中身のキーを `GROWTH_*` と共用した**（§13 の 12）。⚠ **おかげで `_normalize_slots()` をそのまま当てられた**
3. ⚠ **`get_equip_reject_reason()` を切り出した**（§13 の 13）。⚠ **`equip_instance()` の失敗ログの文言が変わった**
4. ⚠ **`_normalize_presets_from_save()` の完了条件を直した。** ⚠ **新規開始は `0 fixed` ではなく `10 fixed`**（器を10件作るため）。⚠ **2回目が `0 fixed`**（§11-A の 2）

### 17-3-1. ⚠ 人間が画面を見て出た指摘（2026-08-23・**2件とも直した**）

| | 症状 | 原因 | 直し方 |
|---|---|---|---|
| **1** | ⚠ **拠点の文字がはみ出して「編成」が見えない** | ⚠ **`NavigationButtons` の既存5個は全部 `size_flags_horizontal = 3` なのに、⚠ コードで足した6個目に付け忘れた**（`base_screen.tscn:120` 他）。6個目だけ内容ぶんの幅を取り、残り5個が押し潰される。⚠ **`ja.csv` 未再インポートで `ui_nav_party_preset`（19文字）がそのまま出ていたことが幅を押し広げた主因** | ⚠ **`Control.SIZE_EXPAND_FILL` を付けて6等分にした ＋ `clip_text = true`**（翻訳が効くまでの保険） |
| **2** | ⚠ **編成プリセットの行で、どのビルドを指しているか読めない** | ⚠ **`_summarize()` が `僧侶(1)` と括弧の数字だけにしていた** | ⚠ **`僧侶 ビルド1 / 弓兵 ビルド3 / 剣士 ビルド1` にした。⚠ 「いまの編成」の `OptionButton` と同じ `ui_party_preset_build` を使い回し、呼び方を2通り作らない** |

| **3** | ⚠ **拠点の下段が丸ごと左右にはみ出して、両端のボタンが切れる**（⚠ **1 を直したあとも残った。⚠ 別の原因**） | ⚠ **素材16件・4桁で `MaterialsDisplay` の最小幅が 564 になり、⚠ `ResourceRow` 全体が 1556（画面幅 1280）まで膨らんでいた**。⚠ **親の `BottomLayout` ごと 1556 になるので、⚠ ナビ6個はその 1556 を等分し、器ごと中央寄せで左右に 138px ずつはみ出す**。⚠ **ナビ行は被害者で、原因は素材欄** | ⚠ **素材欄を `ResourceRow` から出し、⚠ `ScrollContainer`（8列2段・縦スクロール無し）に入れた**。⚠ **最小幅が 0 になるので、素材が増えても桁が増えても再発しない**（⚠ **人間の決定・2026-08-23**） |

⚠ **3 は `separation` の問題ではなかった**（宿題に「`ResourceRow` の `separation`」と書かれていたが、⚠ **32→8 にしても 168px しか減らず、必要な 276px に届かない**）。⚠ **数字を測ってから直した**（下の §17-3-2）。

### 17-3-3. ⚠ 人間が実機で一通り触って出た指摘（2026-08-23・**3件とも入れた**）

#### ⚠ 指摘の原因が違っていたので訂正した

人間の見立ては「**装備されていない部位があると保存できないのでは**」だったが、⚠ **ログの証拠は違う**：

```
save_character_preset('char_priest', 1) -> true (... equipment={ "head": <null>, ... 5部位とも null })
apply_party_preset(0) -> false (ui_party_preset_ref_unsaved)
```

⚠ **装備が5部位とも空でも保存は成功している。⚠ 装備は1つも関係していない。** 本当の原因は**番号のズレ**：

| ログ | 何が起きたか |
|---|---|
| `save_character_preset('char_swordsman', 1)` | 焼いたのは**ビルド2**（`index = 1`） |
| `save_party_preset(0) -> [{swordsman, 0}, {priest, 0}, {archer, 0}]` | 編成が参照しているのは**全員ビルド1**（`index = 0`） |

⚠ **参照先のビルド1が空なので適用が通らない。⚠ しかも画面のどこにも「先にビルドを焼け」と書いていないので抜け出せない**（`apply_party_preset(0) -> false` が**8回**続いている）。⚠ **2階層の一番痛いところが出た。**

#### 入れた3件

| | 指摘 | 入れたもの |
|---|---|---|
| **1** | ⚠ **装備プリセットはいったんやめる**（⚠ **同じ日に取り消された。下の §17-3-4**） | ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED = false`**。⚠ **作業場の廃止と同じ形**（コードも状態のキーも消さず、入口だけ閉じる）。⚠ **`false` のとき `apply_party_preset()` は装備に「触らない」**（「空にする」ではない。⚠ **空の計画で上書きすると、プリセットを当てるたびに裸になる**） |
| **2** | ⚠ **スキルのプリセットは育成でも焼けるように** | ⚠ **`training_screen` の詳細に `[ビルド1 ▼][焼く]` の行を1本**（`.tscn` は触らずコード生成）。⚠ **プリセットが持つ3項目（割り振り・スキル枠・パッシブ枠）はどれもこの画面の配下で決まるので、焼くのもここが自然** |
| **3** | ⚠ **行き止まりを直す**（人間の決定・2026-08-23） | ⚠ **`save_party_preset()` が、参照先のビルドが未保存ならその場で焼く。⚠ 既に保存済みのビルドは触らない**（⚠ **他の編成が参照しているものを黙って上書きすると、⚠ 「1つ直せば全編成に反映」が「1つ壊せば全編成が壊れる」に反転する**） |

⚠ **`GAME_DESIGN` 5-5 は「キャラプリセットは装備一式を持つ」と書いたまま。⚠ 止めているのは「いったん」であって仕様を書き換えたのではない**（⚠ **`docs/` は指示されたもの以外触らない。⚠ 直すなら人間の指示が要る**）。

#### 検証（`scenario=presets` で取れたもの）

- ⚠ **空の参照先を「保存」が焼く**：`char_priest[2]` が `saved=false` → `save_party_preset(1)` → `saved=true` → ⚠ **そのまま適用して `ok=true`**（`ref_unsaved` で弾かれない）
- ⚠ **装備に触らない**：⚠ **`eq_1` を着けてから適用し、⚠ 適用後も `weapon = 'eq_1'` のまま**（⚠ **外れないことが正解**）。`conflicts=0` / `missing=0`
- ⚠ **焼いた `equipment` は5部位とも `null`**
- 正規化の5項目は変わらず通る

### 17-3-4. ⚠ 装備を元に戻した（2026-08-23・**同じ日に2回動いた**）

⚠ **人間が実機で一通り通したあと「装備にも適用がいる」。⚠ §17-3-3 の 1（いったんやめる）を取り消し、⚠ `PRESET_EQUIPMENT_ENABLED = true` に戻した。**

- ⚠ **いまは `GAME_DESIGN` 5-5 と一致している**（食い違いは解消。⚠ **`docs/` は結局1行も直さずに済んだ**）
- ⚠ **定数と分岐は残してある。** ⚠ **1セッションで2回動いた欄だから**。⚠ **落ち着いたら定数ごと消してよい（宿題）**
- ⚠ **`false` のあいだに焼いたビルドは `equipment` が5部位とも `null`。⚠ そのまま適用すると裸になる。⚠ 焼き直しが要る**
  - ⚠ **コード側では直せない**：⚠ **「装備を焼かなかった」と「何も装備していない」は、状態を見ても区別がつかない**（どちらも `null` 5つ）。⚠ **人間に焼き直してもらうしかない**

⚠ **検証（`scenario=presets`）は装備ありの枝に戻り、全部通った**：⚠ **焼いた `equipment` に `eq_1` ／ 取り合い `conflicts=1`（`char_debug_status` から外して `char_priest` へ）／ 消えた個体 `missing=1` ＋ 枠が空 ／ 正規化の5項目**。

⚠ **この回で決定が反転したのは2件目**（1件目は §0-2 の決定5＝平坦 → 2階層）。⚠ **どちらも「実物を触ってから決まった」もので、⚠ 先に聞いても出てこなかった。**

### 17-3-5. ⚠ 「適用」ボタン＝キャラ単体で当てる口を足した（2026-08-23）

⚠ **人間の指摘「装備にも適用がいる」＝適用ボタンが要る。⚠ 編成プリセットは3人まとめて当てる口しか無く、⚠ 1人だけ当て直す口が無かった。**

| | 入れたもの |
|---|---|
| **口** | ⚠ **`GameManager.apply_character_preset(character_id, index)` ＋ `get_character_preset_apply_report()`**。⚠ **編成は触らない**（`set_party_member()` を呼ばない） |
| **共通化** | ⚠ **判定を2本書かないため、編成プリセット側から `_plan_build()` と `_write_build()` を切り出して両方が通るようにした**。⚠ **`together`（一緒に組み替えるキャラ）が3人か1人かだけが違う** |
| **文面** | ⚠ **`GameManager.format_apply_report()` に1本化**（適用の口が3つになったため）。⚠ **`party_preset_screen._format_report()` は消して、こちらを呼ぶ** |
| **画面** | ⚠ **育成に「適用」を追加**（既にあった「焼く」の隣）／ ⚠ **装備に `[ビルドN ▼][焼く][適用]` の行を新設** |

⚠ **「焼く」と「適用」は向きが逆**（焼く＝現在→ビルド ／ 適用＝ビルド→現在）。⚠ **1つのボタンにまとめないこと。**

#### ⚠ 共有部品にしなかった理由（**AGENTS.md の原則から外れている**）

⚠ **同じ行が2画面（育成・装備）にある。⚠ `AGENTS.md`「2画面以上で使い回すパーツは `components/`」に照らすと切り出すべき。**

⚠ **切り出さなかったのは、`class_name` を新しく作ると `.godot/global_script_class_cache.cfg` に載らず、⚠ 人間がエディタを1回通すまで実行時に解決されないため**（`NEXT_STEPS` §4 の罠。⚠ **実際にキャッシュを見て `BuildPresetRow` が無いことを確認した**）。⚠ **その状態では設計役がヘッドレスで検証できず、⚠ 「通っていないものを人間に渡さない」に反する。**

- ⚠ **判定と文面（substance）は `GameManager` に1本化してある。⚠ 各画面に残っているのは器の組み立て30行だけ**
- ⚠ **宿題に足してある**：⚠ **人間がエディタを通したあと、`scripts/components/build_preset_row.gd` へ切り出す**

#### 検証（`scenario=presets` / `scenario=layout`）

- ⚠ **空きのビルドを当てる → `reason=ui_party_preset_unsaved`。⚠ 赤を出さない**（正常系）
- ⚠ **ビルドを当てる → `ok=true` / `members=["char_priest"]`（1人だけ）／ ⚠ 編成は `["char_priest","char_archer","char_swordsman"]` のまま＝触っていない**
- ⚠ **画面4枚（パーティ選択・冒険選択・育成・装備）が全部開く**（⚠ **`layout` シナリオに育成と装備を足した。⚠ コードでノードを足しているので、開かないとパスの取り違えが出ない**）

### 17-3-2. ⚠ 横のはみ出しを数字で測る道具を足した（`scenario=layout`）

⚠ **この事故は3回目**（素材12件で `HBoxContainer` が溢れた／ナビに6個目を足して押し潰した／今回）。⚠ **絵は取れないが寸法は取れる**ので、`debug_boot` に `KIND_REPORT` の枝を1本足した。

- ⚠ **`get_combined_minimum_size().x` が画面幅を超えている器を名指しする**
- ⚠ **測る前に素材を16種類・4桁にする**（⚠ **初期状態は2件しかなく、⚠ 「手元では収まっていた」で見逃す**）
- ⚠ **手書きした `.tscn` が開くかも見る**（`party_preset_screen.tscn` / `adventure_select.tscn`）。⚠ **人間の確認項目から1件減った**
- ⚠ **踏んだ罠**：⚠ **`add_child()` を `call_deferred` にしないと `_ready()` の中で弾かれ、⚠ 赤が1本出るだけで「全部0」というもっともらしい数字が出る**

| 器 | 直す前 | 直した後 |
|---|---|---|
| `Layout` の最小幅 | ⚠ **1556**（画面幅 +276） | **960** |
| `ResourceRow` | 1556 | **1064** |
| `MaterialsScroll` | —（`ResourceRow` の中に 564） | ⚠ **0**（箱に入ったので押し広げない） |
| `NavigationButtons` | 536（⚠ **器ごと 1556 に伸ばされていた**） | 536 |
| 下段の高さ | 216 | 224 |

⚠ **1 は `NEXT_STEPS` §4「件数を増やす回では、既存の器の型を先に見る」を踏んだ**（⚠ **3件前提の `HBoxContainer` に12件入れて溢れた事故と同じ形。⚠ 今回は5個前提の並びに6個目を足した**）。
⚠ **「ビルドの種類は番号が読めれば足りる」は人間の決定**（2026-08-23。⚠ **中身の要約もビルドの名前も足さない。⚠ 名前は宿題のまま＝§13 の 2**）。
⚠ **`--check-only --script` は2ファイルとも `Parse Error` 0件。⚠ 画面のスクリプトなので全シナリオの結果は変わらない**（`debug_boot` の `report` / `battle` の枝はどちらも読み込まない）。

### 17-4. ⚠ ヘッドレスで取れたもの

| | 結果 |
|---|---|
| `--check-only --script`（7ファイル） | ⚠ **`Parse Error` 0件**（`Identifier not found: Balance` / `SceneManager` / `GameManager` は Autoload 未読み込み） |
| `scenario=presets` | ⚠ **器 10件 / 3件 ／ 焼いた中身の4項目 ／ 取り合い `conflicts=1`＋持ち主が移った ／ 消えた個体 `missing=1`＋枠が空 ／ 正規化を2箇所で壊して両方直った ／ 知らないキー `rune_move` が残った ／ 壊した編成プリセットが `saved: false` に戻った** |
| 全シナリオ（`training` を除く23本） | ⚠ **§0 の事前チェックに結果を書く** |

### 17-5. ⚠ 人間の作業（**AI にはできない**）

- [ ] ⚠ **`ja.csv` の再インポート**（FileSystem で右クリック → 再インポート、または Godot 再起動）。⚠ **これをしないと画面にキー名がそのまま出る**
- [ ] ⚠ **`party_preset_screen.tscn` が正しく開くか**（新規 `.tscn` を手書きしているため、ノードパスの取り違えはここで出る）
- [ ] §11-C の検証（15項目）

---

## 18. この回でやらないこと

- ⚠ **ルーンの移動量**（段階8）。⚠ **器だけ用意し、キーは足さない**
- ⚠ **プリセットの中身を画面で1項目ずつ編集する機能**（決定8）
- ⚠ **プリセットの名前**（§13 の 2）
- ⚠ **`party_changed` シグナル**
- ⚠ **所持キャラの概念**（今は全キャラが候補）
- ⚠ **枠数の変更**（3枠のまま）
- ⚠ **`UNLOCKED_SCREENS` への登録**（段階9）
