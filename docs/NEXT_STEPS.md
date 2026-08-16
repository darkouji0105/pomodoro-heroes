# 次にやること：**skills を複数ファイル化（キャラ別 ＋ debug）＋ 枠を無視して撃つキー**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

---

## 0. 前のタスクは終わっている（**確認済み**）

**状態の器（段階3の前半）が、実機で確かめられた（2026-08-16）。** 指示書は **`docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE3A.md`**、決定台帳は **`docs/01_plan/PLAN_SKILL_TEMPLATE.md`**。

器の実装が入った時点では**ロード時検証しか通っていなかった**ので、確かめる手段を作る回を1つ挟んだ。結果は **13項目 NG 0件**（赤は「弾かれるのが正解」の3項目だけ）。

入ったもの（**ここには複製しない**）：

- **`tests/battle/test_status_registry.gd` + `.tscn`（新規フォルダ）** … 13項目。`0`キーや画面を使わず `print` だけで完結する
- **F3 パネルの `P` キー** … `snapshot()` を押した瞬間に1回だけ出す。**素の値 → 実効値**も並べて出す

⚠ **この2つはリリース前に消すもの**（`PROJECT_STATUS.md`の宿題に入れてある）。

---

## 1. このタスク：**skills.json を割る ＋ デバッグスキルを撃つ**

### なぜこの2つが1タスクなのか

⚠ **デバッグ用スキルを足す仕組みと、キャラごとに割る仕組みは同じもの**（`MasterDataLoader` が複数ファイルを読んでマージする）。**別々にやると同じものを2回作る。**

そして**段階3の後半（購読・条件）が乗ると1スキルが30〜50行になる。** いま18スキルで315行なので、**4人目のキャラで500行を超える。** 割るなら購読が乗る前。

### やること

| # | やること | 誰が |
|---|---|---|
| **1** | **`MasterDataLoader` が skills を複数ファイル読んでマージする**（末尾追記だけでは済まない。`_ensure_loaded()` の途中を触る） | ⚠ **設計役**（424行） |
| **2** | **`skills.json` をキャラ別 ＋ debug に割る**（`.gd` を触らない・IDは1つも変えない） | **実装役に渡してよい**（JSONの分割） |
| **3** | **枠を無視して任意のスキルを撃つキー**（`battle_controller.gd` 1001行 ＋ `battle_debug_panel.gd` 380行） | ⚠ **設計役**（どちらも200行超） |

### ⚠ 3番の壁（**先に読むこと**）

**`StatusRegistry.add()` を直接叩かないこと。** 通常経路（`_fire_skill()` → `SkillRuntime` → `resolve()` → 器）を通らないと、**配線の事故をデバッグ機能が隠す。**

その通常経路には**枠の壁がある**：

```
battle_controller._fire_skill()      … 634行
  → SkillActivation.blocked_reason() … 40行目で user.is_skill_ready(skill_id)
      → BattleUnit.is_skill_ready()   … skill_ids に無いIDは必ず false
```

⚠ **`skill_ids` は `GameManager.get_battle_skills()` からしか入らない**（`battle_controller.gd` 197行）。**そこは候補（`get_skill_candidates()`）で絞られるので、デバッグスキルは絶対に入ってこない。**

**どう抜けるかは §2 で人間が決める。** ⚠ **`SkillActivation.blocked_reason()` に「デバッグなら通す」を足すのは避けたい**（発動可否の一箇所化が、検証用の分岐で汚れる）。

---

## 2. 着手前に人間が決めること

- **ファイルの割り方**（`skills_char_swordsman.json` のようにキャラIDで割るか／`skills_swordsman.json` と短くするか。**`skills_debug.json` は別枠で1本**）
- **デバッグスキルの `user_character_id` をどうするか**（実在のキャラにするか、`char_debug` のような架空のIDにするか。⚠ **架空にすると射程のクロス検証（`_validate_all_skills()` 407〜419行）が `_cache_characters` に無いIDとして素通りする**）
- **枠の壁の抜け方**（下の3案）
- **キーの割り当て**（使用済みは `F3` / `1`〜`4` / `K` / `L` / `S` / `J` / `M` / `V` / `B` / **`P`**。⚠ **`F4` は `_unhandled_input` に届かない**）

### 枠の壁の抜け方（3案）

| 案 | やり方 | 代償 |
|---|---|---|
| **A** | `battle_controller` に `debug_fire_skill(skill_id)` を足し、**その場で `unit.skill_ids` に足してから** `_fire_skill()` を呼ぶ | 枠が3つ4つに増えたままになる（**スキルボタンの並びが変わる**。`_rebuild_skill_buttons()` を見ること） |
| **B** | 撃つ直前に足して、撃った直後に戻す | ⚠ **CD が `skill_cooldowns` に残る。** 次に押したとき `is_skill_ready()` が false になる（`skill_ids` に無いので `start_cooldown()` も効かない＝**戻し忘れと同じ絵になる**） |
| **C** | デバッグ専用のキャラを1体パーティに足し、そのキャラの候補にデバッグスキルを全部入れる | 味方が4人になる。**画面のレイアウトが3列前提**（`PROJECT_STATUS.md`） |

### 体制

**§1 の2番（JSONの分割）だけ実装役に渡せる。** 1番と3番は**200行超の既存ファイルの途中の書き換え**なので設計役が書く（`WORKFLOW.md`）。

⚠ **画面を見る検証は人間だけ。** スキルボタンの並び・押した見た目は実装役に渡さない。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-16確認）

| | 事実 |
|---|---|
| `master_data_loader.gd` | **424行**。`DIR_PATH = "res://resources/balance/master/"`。`PATH_CHARACTERS` / `PATH_ENEMIES` / `PATH_PARTIES` / `PATH_STAGES` / `PATH_SKILLS` の5本 |
| `_ensure_loaded()` | **66〜80行**。5ファイルを `_load_json()` で読み、**最終行で `_validate_all_skills()`**。⚠ **この順序が要件**（射程のクロス検証が `_cache_characters` を読むため） |
| `_load_json()` | **load() 方式 → 失敗したら FileAccess 方式**。⚠ **1本目で決まったモードを以降も使う**（`_load_mode`）。**成功時は何も出さない** |
| ⚠ 検証が走る時刻 | `master_data_loader.gd` 380〜382行のコメントは「**育成画面か戦闘画面に入って初めて動く**」と言っている。⚠ **前回の`NEXT_STEPS`は「タイトルの『つづきから』でしか出ない」と書いていた。どちらが正しいか実機で確かめること**（食い違いを見つけたら報告する。勝手に直さない） |
| `_cache_skills` | **平坦な `Dictionary`**（`skill_id` → データ）。⚠ **入れ子になっていない。マージは `merge()` 1回で足りる** |
| `get_skill()` / `get_all_skills()` | 117行 / 386行。どちらも `_ensure_loaded()` を先に呼ぶ。**返すのは `duplicate(true)`** |
| ロード時検証のログ | `[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings`（**422行**）。件数は `_cache_skills.size()`。⚠ **マージすれば自動で合計になる。1本のまま保つこと** |
| `skills.json` | **315行 / 18件**。各スキルに `user_character_id`（`char_swordsman` / `char_archer` / `char_priest`） |
| ⚠ 重複ID | **今は1ファイルなので起きない。** マージすると**あとから読んだほうが黙って勝つ**。⚠ **赤で弾くこと** |
| `_fire_skill()` | `battle_controller.gd` **634行**。`(user, skill_id, power_ratio)`。⚠ **撃てなかったら CD を回さない**（決定1-6） |
| `SkillActivation.blocked_reason()` | **52行の静的クラス**。`no_session` / `not_active` / `user_dead` / `skill_not_found` / `cooldown` / `no_target`。⚠ **`skill_ids` に無いIDは `cooldown` として返る**（`is_skill_ready()` が false を返すため） |
| `unit.skill_ids` の出どころ | `battle_controller.gd` **197行**。`GameManager.get_battle_skills(character_id)` **だけ**。⚠ **`characters.json` の `skills` を直接読まないこと**（選択が反映されなくなる） |
| `get_battle_skills()` | `game_manager.gd` **1875行**。選択済み → 候補で絞る → 空の枠を候補の先頭で埋める。⚠ **候補（`get_skill_candidates()`）に無いIDは必ず落ちる** |
| `battle_debug_panel.gd` | **380行**（`P` キーで＋100行した）。`_unhandled_input` の `match key.keycode` に1本足す形 |
| 使用済みのキー | `F3` / `1`〜`4` / `K` / `L` / `S` / `J` / `M` / `V` / `B` / **`P`（状態の一覧）** |
| `tests/` の前例 | `tests/battle/test_status_registry.gd`（**13項目・`RefCounted` だけで完結**）／`test_common_infra.gd`／`test_ui_common.gd` |

### 行数

| ファイル | 行数 |
|---|---|
| `game_manager.gd` | **2832** |
| `battle_controller.gd` | **1001** |
| `status_registry.gd` | **567** |
| `skill_schema.gd` | 536 |
| `skill_resolver.gd` | 519 |
| `master_data_loader.gd` | **424** |
| `battle_debug_panel.gd` | **380** |
| `skill_runtime.gd` | 358 |
| `tests/battle/test_status_registry.gd` | 359 |
| `unit.gd`（`BattleUnit`） | 236 |
| `battle_formula.gd` | 67 |
| `skill_activation.gd` | 52 |
| `skills.json` | **315** |

---

## 4. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | **段階3の後半**（購読・条件・回復/状態付与/死亡の介入点・パッシブ・コンボ・復活） | 器が確かめられ、デバッグスキルで狙って撃てるようになってから乗せる |
| 3 | `mode: area` | |
| 4 | `phases[]` / `recast` | |
| 5 | `spawn` | ⚠ 座標の規則が要る |

---

## 5. 罠

### ドキュメントの「実装済み」を信じない

**ズレが8回起きている。** `grep`で関数の中身を見てから判断する。読んだ結果ドキュメントが間違っていたら、**勝手に直さず報告する。**

⚠ **§3 に「どちらが正しいか分からない」と書いた行が1つある**（検証が走る時刻）。**そこは実機で確かめてから完了条件に書くこと。**

### 編集したら`grep`で当たったことを確認する

「戦闘だけ反映されない」で1タスク溶かした事故がある。

### リリース後にIDを改名しない

⚠ **このタスクは「IDを保ったままファイルを割る」もの。** 1つでも改名すると、**スキル選択の保存（`growth.skills.slots`）が黙って落ちる**（`get_battle_skills()` が候補で絞るため、エラーは出ずに候補の先頭に置き換わる）。

### 正常系に警告を付けない

⚠ **デバッグスキルのファイルが無いのは正常系**（リリース時は消す）。**「読めなかった」で赤を出さないこと。** ⚠ **ただし重複IDは赤。**

### `MasterDataLoader`が返す数値は`float`

`int()`で包み忘れるとセーブに`.0`が乗る。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ。** `ja.csv`はUTF-8（BOMなし）。

### Godotを起動できない（設計役）

⚠ **設計役は Godot を起動できない。実装役（Ziva の中）はコンソールを読めるが、画面は見えない。**
**「動きました」と書かない。** 完了条件は「ログ」「ファイル」「画面」の3つに分け、**同じことを2箇所に書かない。**

⚠ **完了条件に書くログは、実際に`print`があるものだけにする。**

---

## 6. 検証の道具

**デバッグオーバーレイが全画面の右上に常駐している**（`res://tests/debug_overlay.gd`）。`0`キーで表示切替。

戦闘画面は**`F3`でデバッグパネル**（右上・速度1〜8倍・`K`敵1体撃破・`L`全滅・`J`味方全員に物理の一撃・`M`同じく魔法・`V`強制勝利・`B`強制敗北・`S`CDリセット・**`P`状態の一覧をコンソールへ**）。

**`tests/battle/test_status_registry.tscn`** … 器の13項目。⚠ **このタスクで `MasterDataLoader` を触ったあとも、これが通ること**（器そのものは触らないので通るはず。通らなくなったら触りすぎている）。

⚠ **スキルは18候補あるが、1キャラ2枠しか持ち込めない。** ギルドのスキル選択画面で先に付け替えること。⚠ **このタスクの3番は、まさにその制約を外すためのもの。**

---

## 7. このタスクでやらないこと

- **段階3の後半**（購読・条件・介入点3種・パッシブ・コンボ・復活）
- **スキルの中身を足す**（デバッグ用は別。**製品のスキルは18件のまま**）
- **`characters.json` / `enemies.json` / `parties.json` / `stages.json` の分割**（skills だけ。⚠ **仕組みは使い回せる形にしておくこと**）
- **IDの改名・整理**（§5）
- **バランス調整**
- **`mode: area`**（段階4）／**`phases[]` / `recast`**（段階5）／**`spawn`**（段階6）

---

## 8. 引き継いだ宿題

`PROJECT_STATUS.md`にもあるが、**この回に関係しそうなものだけ**。

1. ⚠ **`SkillResolver.resolve()` の `registry` が `RefCounted` 型**（相互参照を避けるため）。`add()` の呼び違いを静的に捕まえられない
2. ⚠ **`type: buff` の `stat` に `hp` を書けない。** **最大HPバフを入れる回で解く**
3. ⚠ **`until: "skill_end"` が未実装**（語彙と黄だけ）。**段階3の後半で `SkillRuntime` を触るときにまとめる**
4. ⚠ **`stack` の5部品のうち4つが未実装**（上限・消え方・再付与・閾値）。**`independent` に上限が無いので、CDより duration が長いスキルは無限に積める**
5. ⚠ **状態のUIが無い**（F3 パネルの3行目と `P` キーだけ）。**独立スタックはUIが先に音を上げる**
6. **`_find_unit()` が3ファイルに同じ形で3本ある**（`skill_resolver` / `skill_runtime` / `status_registry`）
7. **死亡中にCDが回る。** PLAN 14-4 の推奨は「停止」
8. ⚠ **`scale_from` は「和」しか書けない**（PLAN 5-5-1）。**器の穴。PLAN側で決める**
9. ⚠ **PLAN 5-2 の効果の欄の表に `delivery` / `stack` / `status_id` / `until` が無い**
10. **`target.range` が18件とも未設定**（座標定数とセットで後決め）。⚠ **分割してもここは埋まらない**
11. **`MasterDataLoader` にキャラのキー一覧を返す関数が無い**（`training_screen.gd` の `CHARACTER_IDS` が決め打ち）。⚠ **キャラ別にファイルを割るなら、この決め打ちと同じ問題が増える。`get_all_characters()` を足すかを一緒に考える**
12. **レベル上限が30が天井**。⚠ **パッシブの Lv40 以降が到達できない**
13. **検証用のものはリリース前に消す**（デバッグオーバーレイ・戦闘/ポモドーロのデバッグパネル・`get_status_registry()`・`P` キー・`tests/battle/`・**このタスクで作るデバッグスキルと撃つキー**）

---

## 9. 終わったあと

**このファイルを、次のタスク（段階3の後半：購読・条件・介入点3種・パッシブ・コンボ）の内容に書き換える。**
