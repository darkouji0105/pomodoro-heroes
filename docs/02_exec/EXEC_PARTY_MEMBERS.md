# EXEC — **パーティのメンバーを画面から入れ替える**

`parties.json` を書き換えて**再起動する**運用をやめ、**状態（セーブ）に3人を持たせて画面から差し替える。**

⚠ **本物の「パーティ選択画面」はこの回では作らない。** 第2層（PLAN）ごと無く、
`GAME_DESIGN.md` 907 の4項目（プリセット・メンバー差し替え・スキル選択・ポイント割り振り）のうち
**メンバー差し替えの1つだけ**をやる。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **スコープ** | **メンバー差し替えだけ。** 状態に `party_members` を3枠持たせ、候補から選んで入れ替える。スキル選択・ポイント割り振りは**既存のギルド画面のまま触らない** |
| **置き場所** | **冒険選択画面に足す。** 新画面を作らない（`adventure_select.gd` は246行で余地がある）。⚠ ギルドにも同じものを置かない（同じことをする場所を2つ作らない） |
| **`stages.json` の `party_id`** | **初期値にだけ使う。** セーブに `party_members` が無いときだけ `parties.json` から流し込み、**以降は状態が唯一の正**。⚠ `research_tree` の「毎回マスターで上書き」とは**逆**。`AGENTS.md`「マスターデータと状態を同期する型」を真似ないこと |
| **検証用の3体** | **`OS.is_debug_build()` のときだけ候補に出す。** 検証用ステージの「▼ 検証用」見出しと同じ型。**これで `parties.json` の差し替えが完全に不要になる**（この回の目的） |

### 0-1. ⚠ ドキュメントの決定を1つ覆している

[`PROJECT_STATUS.md:569`](../PROJECT_STATUS.md) に **「⚠ パーティの入れ替え機能も要らない。パーティは状態に入っておらず、
`parties.json` の `members` を書き換えて再起動すれば入れ替わる」** と明文で書かれている（2026-08-16）。

**この回でその決定を覆す。** 理由は、書かれたあとに**戻し忘れが2回表面化した**ため
（敵の回の検証／この EXEC を書いている時点でも `parties.json` は検証用3体のまま）。
⚠ **`PROJECT_STATUS.md` の該当行を書き換えること**（§8）。

### 0-2. 設計役が置いた前提（**違ったら言ってください**）

- **3枠固定・空き無し。** `PLAN_SKILL_TEMPLATE.md` 873「パーティ枠は3枠のまま。触らない」に従う。
  空き枠を許すと「2人で挑む」が書けてしまい、勝敗判定と座標の前提が増える
- **同じキャラを2枠に入れられない。** 育成データが共有されるので意味が無く、`party_0` / `party_1` の
  区別だけが残って紛らわしい。→ **既に別の枠に居るキャラを選んだら、その枠と交換する**
- **UI は `OptionButton` を3つ並べる。** ⚠ **モーダルを書かない**（`AGENTS.md` の実例：
  モーダルの検証で1タスク溶かしている）。`OptionButton` は Godot 内蔵で一覧のポップアップを持つ
- **`.tscn` を触らない。** 3枠はコードで生成して `StageList` の手前に差し込む。
  ⚠ `.tscn` を編集すると人間の作業が増える

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-17**）

| | 状態 |
|---|---|
| 編成画面 | **無い。** `scenes/guild/` の7画面に含まれない |
| メンバーの決まり方 | `stages.json` の `party_id` → `MasterDataLoader.get_party()` → `parties.json` の `members`。**完全にマスターデータ固定** |
| 読んでいる場所 | ⚠ **[`battle_controller.gd:176`](../../scenes/adventure/battle_controller.gd) の1箇所だけ**（`_spawn_party_units()`）。差し替えるのはここ1行で済む |
| セーブ | ⚠ **パーティの概念がゼロ。** `CHARACTER_GROWTH` はあるが「誰を出すか」は持っていない |
| `parties.json` | ⚠ **今この瞬間、検証用3体のまま**（`["char_debug_status", "char_debug_life", "char_debug_mix"]`）。本来は `["char_priest", "char_archer", "char_swordsman"]`（`PROJECT_STATUS.md:373`） |
| 全キャラを返す口 | ⚠ **無い。** `get_all_items()` / `get_all_recipes()` はあるが `get_all_characters()` が無い |
| `characters.json` の並び | `char_swordsman` → `char_archer` → `char_priest` → `char_debug_status` → `_life` → `_mix`。**検証用3体が末尾**なので、デバッグビルドの分岐が末尾を足すだけで済む |
| 旧セーブへの流し込み | ✅ 型が既にある。`_normalize_skill_slots_from_save()`（`game_manager.gd`）が「旧セーブは空なので、ここで枠が生える。**だから save_version は 3 のままでよい**」をやっている |

---

## 2. ⚠ 一番の事故どころ：`party_id` が「効かない欄」になる

`stages.json` の `party_id` は**戦闘のメンバーを決めなくなる。** 残るのは `BattleLog` の見出しだけ。

⚠ **JSON にコメントは書けない。** 将来だれかが `stages.json` の `party_id` を書き換えて
「変わらない」で悩む。→ **`battle_controller.gd` の該当箇所と `BattleSession.party_id` の宣言に
⚠ コメントを書き、`PROJECT_STATUS.md` の宿題にも足すこと**（§8）。

⚠ **`party_id` を消さないのは人間の決定**（将来「このステージは固定メンバー」をやりたくなったときに戻せるように）。
**勝手に消さないこと。**

---

## 3. 実装（ファイル別）— **全部 設計役が書く**

⚠ **関数を足す前に `grep -n "func <名前>"`、足したあとにも `grep -n` で当たったか確認する**（`CLAUDE.md` 2番）。

### 3-1. `scripts/utils/state_keys.gd`

トップレベルのキーを1つ。

```gdscript
# パーティの編成（character_id の配列・3枠固定）。
# ⚠ 持つのはIDだけ（CLAUDE.md 4番）。能力値はマスターから毎回引き直す。
# ⚠ 代償：リリース後に character_id を改名できない。改名すると編成が黙って既定に戻る。
const PARTY_MEMBERS: String = "party_members"

# 編成の枠数。⚠ PLAN_SKILL_TEMPLATE 873「3枠のまま。触らない」。
const PARTY_SLOT_COUNT: int = 3
```

### 3-2. `scripts/systems/master_data_loader.gd`（587行）

`get_all_characters()` を1本足す。⚠ **`get_all_items()` と同じ形にすること**（2本目の書き方を作らない）。

```gdscript
# 全キャラの定義。⚠ 並び順は characters.json の記述順（Godot 4 の Dictionary は
#   挿入順を保つ）。順が乱れると、編成の候補が押すたびに入れ替わる。
static func get_all_characters() -> Dictionary:
	_ensure_loaded()
	return _cache_characters.duplicate(true)
```

### 3-3. `autoload/game_manager.gd`（2832行）

#### (a) `_empty_state_template()` に1行

```gdscript
		GameStateKeys.PARTY_MEMBERS: [],
```

⚠ **空配列で始めること。** ここに既定の3体を書くと、`parties.json` と**2箇所に初期値**ができる。

#### (b) `_ensure_party_members_from_master()` を足す

```gdscript
# セーブに編成が無い／壊れているときだけ、parties.json から流し込む。
#
# ⚠ research_tree / shop / recipes の「毎回マスターで上書き」とは逆（AGENTS.md
#   「マスターデータと状態を同期する型」を真似ないこと）。編成は進捗ではなく
#   プレイヤーの選択なので、毎回上書きすると入れ替えが起動のたびに巻き戻る。
# ⚠ _normalize_skill_slots_from_save() と同じ位置づけ。旧セーブでもここで生えるので
#   save_version は 3 のままでよい。
# ⚠ マスターに無い character_id が混ざっていたら、その1枠だけ直さず全体を既定に戻す。
#   半端に埋めると「知らないキャラが1人だけ居る」状態が残る。
const DEFAULT_PARTY_ID: String = "party_default"
```

やること：

1. `_state[PARTY_MEMBERS]` が `Array` で、要素が `PARTY_SLOT_COUNT` 件で、
   全部が `MasterDataLoader.get_character()` で引ける文字列で、**重複が無い**なら何もしない
2. 1つでも欠けたら `MasterDataLoader.get_party(DEFAULT_PARTY_ID)` の `members` で丸ごと置き直す
3. それも取れなければ `push_error` して**空のまま**（戦闘側が空で赤を出す。黙って既定を捏造しない）
4. 直したときだけ `print` を1行（`_sync_research_tree_from_master()` と同じ流儀）

呼ぶ場所は**2箇所**：

- `_ready()` の `_sync_research_tree_from_master()` の**手前**
- `load_state()` の `_normalize_skill_slots_from_save()` の**直後**

⚠ **片方だけにしないこと。** `_ready()` だけだと「ロードしたら編成が空」、
`load_state()` だけだと「新規開始で編成が空」になる。**どちらもエラーが出ない。**

#### (c) `get_party_members() -> Array`

```gdscript
# 編成の3枠。⚠ 複製を返す（get_state() と同じ理由。返した配列を書き換えられると
#   「必ず関数経由」が構造的に守れなくなる）。
func get_party_members() -> Array:
	var members: Variant = _state.get(GameStateKeys.PARTY_MEMBERS, [])
	if not (members is Array):
		return []
	return (members as Array).duplicate(true)
```

#### (d) `set_party_member(index: int, character_id: String) -> bool`

⚠ **状態を変える前に全部の判定を終える**（`CLAUDE.md` 6番）。

```
1. index が 0..PARTY_SLOT_COUNT-1 か             … 違えば push_error して false
2. character_id がマスターに居るか               … 居なければ push_error して false
3. 今の3枠を複製して取り出す（件数が違えば false）
4. その枠が既に同じキャラなら、何もせず true      … ⚠ 「変わらない」も成功
5. そのキャラが別の枠 j に居るなら、i と j を交換する
   居なければ i を置き換える
6. ここで初めて _state へ代入し直す（複製を代入・AGENTS.md）
```

⚠ **5 の交換を「入れ替え先を空にする」で済ませないこと。** 空き枠を作らないのが不変条件（§0-2）。
⚠ **シグナルは足さない。** 購読者が冒険選択の1画面しかないので、押したハンドラの中で
描き直すほうが安い。⚠ **将来パーティ選択画面を作って購読者が2つになったときに `party_changed` を足す**
（そのとき `AGENTS.md` のシグナル表にも1行足す）。

### 3-4. `scenes/adventure/battle_controller.gd`（1209行）

`_spawn_party_units()`（176行付近）の**3行だけ**差し替える。

```gdscript
	# 編成は状態が唯一の正（EXEC_PARTY_MEMBERS.md）。
	# ⚠ MasterDataLoader.get_party() を読まないこと。stages.json の party_id は
	#   もう戦闘のメンバーを決めない（初期値にだけ使う）。両方読むと編成が
	#   2箇所にある状態になり、どちらが効いているか実機でしか分からなくなる。
	var members: Array = GameManager.get_party_members()
	if members.is_empty():
		push_error("[Battle] 編成が空（GameManager.get_party_members()）")
		return
```

⚠ **`for i: int in range(members.size())` から下は1行も触らない。**
⚠ **`_session.party_id` は残す**（`BattleLog` の見出し）。`BattleSession.party_id` の宣言に
「⚠ ログの見出しにしか使わない。メンバーは決めない」の1行を足す。

### 3-5. `scenes/adventure/adventure_select.gd`（246行）

`_ready()` の `_build_stage_list()` の**手前**に `_build_party_row()` を足す。

```gdscript
# 編成の3枠（EXEC_PARTY_MEMBERS.md）。
#
# ⚠ .tscn を触らずコードで作り、StageList の手前に差し込む。
# ⚠ モーダルを書かないこと。OptionButton が一覧のポップアップを内蔵している。
# ⚠ 再描画に await を持たせない（AGENTS.md）。押したその場で3つとも作り直す。
func _build_party_row() -> void:
```

やること：

| | 内容 |
|---|---|
| 見出し | `Label` に `tr("ui_adventure_party")` |
| 枠 | `OptionButton` を `PARTY_SLOT_COUNT` 個。⚠ **`item_selected` を `bind(index)` で繋ぐ** |
| 候補 | `MasterDataLoader.get_all_characters()` の**記述順**。⚠ **`OS.is_debug_build()` でなければ `char_debug_` で始まるIDを飛ばす** |
| 表示名 | `tr(char_data["name_key"])` |
| 選択中 | `GameManager.get_party_members()[index]` の位置を `selected` に |
| 差し込み | `stage_list.get_parent().add_child(box)` → `move_child(box, stage_list.get_index())` |

ハンドラ：

```gdscript
func _on_party_slot_selected(item_index: int, slot_index: int) -> void:
	# character_id は候補の並びから引く。⚠ item_index をそのまま character_id に
	#   使わないこと（デバッグビルドかどうかで候補の件数が変わる）。
	# 交換が起きるので、押した枠以外も変わる。3つとも作り直す。
```

⚠ **`_add_stage_row()` / `_add_debug_stage_row()` を触らない。**
⚠ **`_stage_rows` に編成の行を入れない**（あれは解放判定に使う辞書）。

### 3-6. `resources/balance/master/parties.json`

**本編3体に戻す。**

```json
{
  "party_default": { "members": ["char_priest", "char_archer", "char_swordsman"] }
}
```

⚠ **並びは `PROJECT_STATUS.md:373` のとおり `[僧侶, 弓兵, 剣士]`**（剣士が最前列＝右端。
スキルボタンの並びもこの順で、画面の左右と一致する）。**勝手に並べ替えないこと。**

⚠ **戻すのは、条件の回（`EXEC_SKILL_CONDITION.md`）の検証が終わってから。**
この回が入れば、検証用3体は**画面から選べる**ので `parties.json` を二度と触らなくてよくなる。

### 3-7. `localization/ja.csv` に1行

```
ui_adventure_party,編成
```

⚠ キャラ名の翻訳キー（`ui_battle_char_swordsman` 等・6件）は**すでに全部ある**。足さない。

### 3-8. ⚠ 触らないファイル

`.tscn` 全部 ／ `stages.json` ／ `skill_resolver.gd` ／ `unit.gd` ／ ギルドの7画面。

---

## 4. ⚠ 事故りやすい箇所

| | 内容 |
|---|---|
| **4-1** | ⚠ **`_ensure_party_members_from_master()` を `_ready()` と `load_state()` の両方から呼ぶ。** 片方だけだと「新規開始で空」か「ロードで空」のどちらかになり、**どちらもエラーが出ない** |
| **4-2** | ⚠ **`research_tree` の同期の型を真似ない。** 毎回マスターで上書きすると、入れ替えが起動のたびに巻き戻る。**空のときだけ流し込む** |
| **4-3** | ⚠ **`get_party_members()` は複製を返す。** 参照を返すと呼び出し側から `_state` を直接書き換えられ、「必ず関数経由」が構造的に破れる（`AGENTS.md`） |
| **4-4** | ⚠ **`set_party_member()` は状態を触る前に全部の判定を終える**（`CLAUDE.md` 6番）。途中で1枠だけ書いてから弾くと、重複した編成が残る |
| **4-5** | ⚠ **候補の `item_index` を `character_id` に読み替える表を持つこと。** デバッグビルドかどうかで候補の件数が変わるので、`item_index` をIDの代わりに使うと**本番ビルドで別のキャラが選ばれる** |
| **4-6** | ⚠ **再描画に `await` を持たせない**（`AGENTS.md`）。交換が起きると押した枠以外も変わるので、3つとも作り直す。`remove_child()` してから `queue_free()` する |
| **4-7** | ⚠ **`stages.json` の `party_id` が効かない欄になる**（§2）。コメントを2箇所に書き、宿題にも足す |
| **4-8** | ⚠ **`ja.csv` は UTF-8（BOMなし）。** 編集後は人間が再インポート |

---

## 5. Ziva に渡せる部分

**無い。** JSON の変更は `parties.json` の1行と `ja.csv` の1行だけで、
どちらも `.gd` 側の変更と同時に効かないと確認できない。**この回は設計役が全部書く。**

---

## 6. 完了条件

### 6-A. ログ（Godot の出力パネル）

1. 起動時に `[GameManager] init complete.` が出て、赤が出ない
2. **セーブを消して新規開始**したとき、編成を直した旨の `print` が1行だけ出る（既定を流し込んだ）
3. **既存のセーブでロード**したとき、同じ `print` が1行だけ出る（旧セーブに `party_members` が無いため）
4. 一度入れ替えたあと再起動したとき、**その `print` が出ない**（⚠ 出たら、毎回マスターで上書きしている＝4-2）

### 6-B. ファイル（`save_slot_0.json` をテキストエディタで開く）

5. `"party_members"` が**3件の文字列配列**で入っている
6. 画面で入れ替えた結果がそのまま入っている（⚠ **`"save_version"` は `3` のまま**。上がっていたら誤り）
7. 同じ `character_id` が2つ入っていない
8. `battle_last.jsonl` の `battle_start` 行の `party` が **`"party_default"` のまま**（⚠ 見出しなので変わらないのが正しい）

### 6-C. 画面（実機で操作する）

9. 冒険選択の**ステージ一覧の上**に「編成」と3つの選択ボタンが出る
10. ボタンを押すと候補の一覧がポップアップし、**デバッグビルドでは検証用3体（`検証用（状態）` 等）が末尾に並ぶ**
11. 別のキャラを選ぶと**その枠の表示が変わる**。⚠ **既に別の枠に居るキャラを選ぶと、2つの枠が入れ替わる**
12. 同じキャラが2枠に並ぶことがない（11 を何度か繰り返して確認）
13. そのまま `stage_1` に挑むと、**選んだ3人が出てくる**（並び・スキルボタンも選んだ順）
14. 検証用3体を選んで `検証用・条件` に入ると、**`parties.json` を触らずに検証ができる**（⚠ **この回の目的**）
15. 拠点に戻って冒険選択に入り直しても、**選んだ編成が残っている**
16. ゲームを終了して起動し直しても、**選んだ編成が残っている**

### 6-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- `save_slot_0.json` の `party_members` を手で `["char_swordsman"]`（1件）に書き換えてロードすると、既定に戻る
- `party_members` にマスターに無いIDを入れてロードすると、**1枠だけ直さず全体が既定に戻る**
- `parties.json` の `party_default` を消すと `push_error` が出て編成が空になる（黙って捏造しない）
- **本番ビルドでは検証用3体が候補に出ない**

---

## 7. この回でやらないこと

- **パーティ選択画面**（プリセット・スキル選択・ポイント割り振り）。⚠ 第2層（PLAN）ごと無い
- **編成プリセット**（`GAME_DESIGN.md` 329）
- **所持キャラの概念**。⚠ 今は全キャラが候補。「まだ仲間になっていないキャラ」は将来ここで絞る
- **枠数の変更**（3枠のまま）
- `stages.json` の `party_id` を消すこと
- `party_changed` シグナルの追加（購読者が1つしかない）

---

## 8. 宿題に足すもの（`PROJECT_STATUS.md`）

- ⚠ **`PROJECT_STATUS.md:569` の「パーティの入れ替え機能も要らない」を書き換える**（§0-1）。
  併せて572行の「検証時は `parties.json` を差し替えて再起動」も**画面から選ぶ**に直す
- ⚠ **新**：`stages.json` の `party_id` は**戦闘のメンバーを決めない**（`BattleLog` の見出しだけ）。
  書き換えても何も起きない。将来「このステージは固定メンバー」をやるなら、ここを読む側を戻す
- ⚠ **新**：`CLAUDE.md` 4番の「リリース後にIDを改名できない」に **`character_id`** が加わった
  （改名すると編成が黙って既定に戻る）
- ⚠ **新**：**所持キャラの概念が無い。** 全キャラが編成の候補に出る
- ⚠ **新**：`party_changed` シグナルを足していない。**パーティ選択画面を作るときに足す**
  （そのとき `AGENTS.md` のシグナル表にも1行）
- 宿題16（リリース前に消すもの）に **`adventure_select._build_party_row()` の `OS.is_debug_build()` 分岐**を足す
  （⚠ 編成の行そのものは残す。消すのは検証用3体を候補に出す分岐だけ）
