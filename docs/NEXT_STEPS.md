# 次にやること：ステータス10軸（**器だけ。式は次回**）

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

---

## 0. 前のタスクは終わった

**ポモドーロのアラーム音は完了した（2026-08-15）。** `SoundManager`（Autoload 6番目）が入り、作業終了と休憩終了でアラームが鳴る。実施結果は`EXEC_SOUND.md` §13。

**同じ作業をもう一度やらないこと。**

---

## 1. このタスクの範囲（**2回に分けた前半**）

`PLAN_IMPLEMENTATION.md` 3章の2番。**ただし1回では通さない。**

| | 今回 | 次回 |
|---|---|---|
| `_stat_keys()` を10本に | **○** | |
| `state_keys.gd`の`STAT_*`定数 | **○** | |
| `characters.json` / `enemies.json` / `items.json`に軸を追加 | **○** | |
| 育成画面・装備画面の表示（4行 → 10行） | **○** | |
| 研究の`boost_all`を実数軸だけに限る | **○** | |
| セーブを弾く（`SAVE_VERSION`） | **○** | |
| `def`/`mdef`の除算化 | | ○ |
| クリティカル抽選・`atkspd`・`haste`の反映 | | ○ |
| 物理／魔法の出し分け・`skills.json`の参照欄 | | ○ |
| `BattleUnit`の拡張 | | ○ |
| `StatConfig.tres`（上限値） | | ○ |

### なぜ分けたか

**1回でやると、実機で壊れたときに「軸追加が悪いのか式が悪いのか」を切り分けられない。**

さらに`def`を減算→除算にすると、既存の敵HP・`atk`の数値の意味が全部変わる（`GAME_DESIGN.md` 14章が「敵HP・スキル倍率は10軸が入ってから」と保留している）。**式まで一度に入れると、実機確認が「合っているか分からない」状態になる。**

今回の到達点は「**育成画面に10軸が並ぶ。戦闘は今まで通り動く**」。ここを確認してから次回に式を入れる。

---

## 2. ⚠ 着手前に読んだ結果（**PLANのズレは確認済み。信じてよい**）

**この節は実コードを`grep`で確認した結果。`PLAN_STATS_AND_FORMULAS.md`にはこれらが書かれていない。**

### 2-1. 「`_stat_keys()`に足せば全部追従する」は**半分しか本当ではない**

追従する（触らなくてよい）：

- `get_effective_stats()` / `get_instance_stats()` / `get_equipment_bonus()` / `_default_growth_for()` / `_recalc_stats()`
- ロード時の`int()`正規化（`game_manager.gd` 2153行。`_stat_keys()`をループしている）

**追従しない（ベタ書き。今回直す）：**

| 場所 | 中身 |
|---|---|
| `training_screen.gd` 112〜115行 | 4行ベタ書き |
| `equipment_screen.gd` 238〜244行 | `_stat_labels()`という**もう1本の4軸配列** |
| `battle_controller.gd` 152〜155行 | 4変数を取り出して`BattleUnit.new()`へ渡す（**今回は触らない。次回**） |

### 2-2. 研究の`boost_all`が％軸にも乗る（**PLANにも`GAME_DESIGN.md`にも記述が無い**）

`game_manager.gd` 916行が`boost_all`を**全キーに無条件で加算**している。10軸にすると研究の「全ステータス+3」が`crit_rate +3%` `haste +3%`にも乗る。

- [ ] **実数軸（`hp` `atk` `mag` `def` `mdef` `spd`）だけに限る。** ％軸のリストを`_stat_keys()`の隣に置く

### 2-3. `attack_interval_sec`と`cooldown_sec`は**直読みだった**（`PROJECT_STATUS.md` 329行の懸念は当たり）

- `battle_controller.gd` 165行 … `char_data.get("attack_interval_sec")`。**すぐ上の150行で`get_effective_stats()`を取っているのに、攻撃間隔だけマスターから読んでいる**
- 同 477行・599行 … `skill_data.get("cooldown_sec")`をskills.jsonから直読み。`haste`が入る場所が無い

**今回は直さない（式の回）。** ただし**`PROJECT_STATUS.md`の該当箇所を「確認済み・直読みだった」に更新すること。**

### 2-4. `stat_growth_formula`は`.tres`に書き出されていない（**PLAN 2章が警告した罠に既に当たっている**）

`GAME_DESIGN.md` 15章は「`"base + growth * (level - 1)"` → `"base"`」と書いているが、`character_config.tres`が持つのは`level_up_material_id` / `base_level_up_cost` / `cost_growth_per_level`の**3つだけ**。効いているのは`character_config.gd` 31行の`@export`初期値。

**Inspectorに項目が存在しないので、人間が開いても直せない。**

- [ ] **今回は変えない。** 割り振りポイント（3番）が入るまでレベルアップが完全に無意味になるため、レベルの役割転換と同じ回に入れる（`EXEC_STATS_10_AXES.md` §11）
- [ ] 変えるときは**`.gd`側の`@export`初期値**を直す。**`.tres`を書き換えようとしないこと。** 書き出されていないものは編集できない

### 2-5. ダメージ経路は2箇所ある（次回の話だが記録）

`battle_controller.gd` 397行と`skill_resolver.gd` 91行。`SkillResolver`は`static`の別ファイル。**PLAN 5章は1箇所前提で書かれている。**

### 2-6. `skills.json`に参照欄は**無い**（PLAN 4章「見て、無ければ追加」→ 無い）

`atk`/`mag`の参照欄も、物理／魔法の種別欄も無い。加えて**`skill_resolver.gd` 80行の回復量が`user.atk`参照**。僧侶の回復が攻撃力依存になっている。**次回の判断材料。今回は触らない。**

---

## 3. 既存セーブ：**捨てる**（決定済み）

`GAME_DESIGN.md` 14章の決定通り。移行処理は書かない。

### ⚠ `SAVE_VERSION`を上げるだけでは捨てられない

**`save_manager.gd` 56〜57行が、バージョン不一致を`push_warning`するだけで`continuing`している。**

```gdscript
if loaded_version != CURRENT_SAVE_VERSION:
	push_warning("... - continuing")   # ← 弾いていない
```

- [ ] ここを`return false`にする

### ⚠ `save_version`の出どころが**3箇所ある**

| 場所 | 現在 |
|---|---|
| `save_manager.gd` 5行 `CURRENT_SAVE_VERSION` | 1 |
| `initial_state_config.tres` 16行 `save_version` | 1（**書き出されている**） |
| `game_manager.gd` 197行 `_empty_state_template()` | 1（ベタ書き） |

**3つとも2にしないと、新規開始したセーブが旧バージョンとして弾かれる無限ループになる。** `.tres`の書き換えは**人間の作業**（`CLAUDE.md`）。

### 弾いたあとの挙動（確認済み）

`title_screen.gd` 24〜36行 … `load_game()`が`false` → モーダル`ui_title_load_failed`（本人が閉じるまで残る）→ 新規開始として`base_screen`へ遷移する。**`_init_default_state()`は通る。**

- [ ] **ただし古いセーブファイルは残ったまま。** 次回起動でも同じモーダルが出る。これを許容するか、弾いた時点で削除するかを決めること（**削除は取り返しがつかない。人間に聞く**）

---

## 4. データに足すもの

**軸は`GAME_DESIGN.md` 8-1が正。ここには一覧を書かない。**

新しく増えるのは6本：`mag` `mdef` `atkspd` `haste` `crit_rate` `crit_dmg`。

- [ ] `characters.json` の3キャラ全部に6本
- [ ] `enemies.json` の3体全部に`mag`と`mdef`（**片方だけだと`mdef`が死に軸**。PLAN 7章）
- [ ] `items.json` の`equip_stats` … **書かなくてよい**。`get_instance_stats()`が`.get(key, 0)`なので無い軸は0
- [ ] `ja.csv` に6本の表示名（`ui_training_stat_mag`など。**既存4本は`ui_training_stat_*`の形**）

### 数値で迷ったときの原則

- **`％`系は`int`で持つ**（`crit_rate: 25` ＝ 25%）。`float`だと`.0`が乗る
- **`growth_per_level`に％系を入れない**（レベル100で勝手に100%に達する。PLAN 4章）
- **剣士にも`mag`の基礎値を持たせる。0にしない**（PLAN 4章。0だと`mag`参照スキルが1つ付いた瞬間に破綻する）
- **`crit_dmg`の基礎値を0にしない。** 0だと会心が「ダメージ0」になる（式の回で効いてくる）
- **具体値は未決**（`GAME_DESIGN.md` 14章）。**仮の値を入れて、仮であることをコメントに書く**

---

## 5. 罠

### `MasterDataLoader`が返す数値は必ず`float`

`int()`で包み忘れるとセーブに`"crit_rate": 25.0`と書かれる。**`_default_growth_for()`と`_recalc_stats()`は既に`int()`で包んである**（`_stat_keys()`ループなので追従する）。

### 編集したら`grep`で当たったことを確認する

`_stat_labels()`という**2本目の4軸配列**があるように、同じ形の配列が他にもある可能性がある。

- [ ] 作業後に`grep -rn "STAT_SPD" --include=*.gd .`を打ち、**4軸のまま残っている箇所が無いこと**を確認する

### インデントはタブ

`.gd`はタブ。`.json`は既存ファイルに合わせる（**タブで書かれている**）。

### `ja.csv`はUTF-8（BOMなし）

BOMが付くと1行目が`﻿keys`になり全滅する。**編集後のGodotでの再インポートは人間の作業。**

### Godotを起動できない

**動かして確かめられるのは人間だけ。「動きました」と書かない。**

---

## 6. 完了条件

### 人間が確かめること（画面）

1. 育成画面のステータス表示が**10行**になっている
2. 装備画面のステータス表示も**10行**になっている（装備の性能欄も同じ）
3. **戦闘が今まで通り動く**（ダメージの数字が変わっていない。式は次回なので変わったら間違い）
4. 旧セーブがある状態で「つづきから」を押すと、読み込み失敗のモーダルが出て新規開始になる

### ログ

1. `load_state`が**旧セーブで`false`を返している**（`push_warning`のバージョン不一致メッセージが出る）
2. `_default_growth_for()`が組み立てた`stats`のキーが10個

### ファイル（セーブ）

1. 新しく保存したセーブの`character_growth.<id>.stats`に**キーが10個**ある
2. **`.0`が付いた数値が1つも無い**
3. `save_version`が**2**

---

## 7. このタスクでやらないこと

- **`def`/`mdef`の除算化**（次回）
- **クリティカル・`atkspd`・`haste`の戦闘への反映**（次回）
- **`BattleUnit`の拡張**（次回。**現在10個の位置引数。6本足すと16個になるので、構造ごと見直す**）
- `StatConfig.tres`（上限値。使う側が無いうちは作らない）
- 敵HP・スキル倍率のバランス調整（`GAME_DESIGN.md` 14章。**式が入ってから**）
- 等級10・`parts`の種類つき・割り振りポイント（`PLAN_IMPLEMENTATION.md` 3章の3・4番）

---

## 8. 終わったあと

**同じ2番の後半＝式の反映。** `def`/`mdef`の除算、クリティカル抽選、`atkspd`と`haste`。**`BattleUnit`の作り直しが本体になる。**

上の2-3・2-5・2-6に、次回に必要な調査結果を既に書いてある。**もう一度`grep`し直さなくてよい。**

**このファイルを、そのタスクの内容に書き換える。**
