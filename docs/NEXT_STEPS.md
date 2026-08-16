# 次にやること：**通常攻撃をデータ化して、スキルと同じ経路に載せる（挙動不変）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

---

## 0. 前のタスクは終わっている（**全項目確認済み**）

**skills の複数ファイル化と検証用キャラ3体（2026-08-16・`30f0ab7`）。** 指示書は **`docs/02_exec/EXEC_SKILL_MULTIFILE.md`**。

- `skills.json` を消して**キャラ別に分割**し、**検証用キャラ3体**（`char_debug_status` / `_life` / `_mix`・**HP 9999 / atk 1 / crit_rate 0**）を足した
- `MasterDataLoader` が複数ファイルをマージし、**重複IDを赤で弾く**

**続けて「1キャラ＝1フォルダ」へ移した（人間の決定・`5f2ae43` の次）。**

```
resources/balance/master/characters/char_swordsman/skills.json   (6件)
resources/balance/master/characters/char_swordsman/nodes.json    (60件)
resources/balance/master/characters/char_swordsman/passives.json ← 実装する回にここへ
```

- **`character_nodes.json`（1784行・180件）と `skills_debug.json` を解体**し、6フォルダへ。**分割前後でデータは完全一致**（機械で突き合わせ済み）
- ⚠ **`characters.json`（能力値）は動かしていない。** `GameManager` が育成・装備・研究から何度も引いており、触ると挙動の話になる
- ⚠ **走査しない。** フォルダを増やしたら `MasterDataLoader` の `CHARACTER_DIRS_REQUIRED` に1行足す。**足し忘れるとそのキャラのスキルとノードが無音で消える**
- ⚠ **パッシブのファイルは作っていない**（実装がゼロのため。置き場だけ決めた）

⚠ **検証するときは `parties.json` の `members` を検証用3体に差し替えて再起動する。戻し忘れないこと。**

---

## 1. なぜ購読より先にこれをやるのか

**購読（段階3の後半①）の前に潰しておかないと、反射を書いた段になって初めて「効かない」と分かる。**

いま通常攻撃はこうなっている：

```
battle_controller._step_unit()（412〜434行）
  → BattleFormula.roll_crit() → _compute_damage() → target.take_damage() → _pop_damage()
```

⚠ **`SkillResolver` を1ミリも通っていない。** 結果：

- 段階1で作った**ダメージの介入点**（`_step_crit_override` / `_step_reduction`）が**通常攻撃に効かない**
- したがって**シールドも軽減も反射も「スキルにだけ効く」**という、説明のつかない仕様になる
- `delivery`（`melee` / `projectile` / `magic`）も付いていないので、**飛び道具の無効化（`cancel_by_delivery()`）が通常攻撃に効かない**

⚠ **`PLAN_SKILL_TEMPLATE.md` 10-4 は「通常攻撃は『攻撃した』合図を出す」としか書いていない。式の経路が2本あることに触れていない。** PLAN側の穴。

**そして人間の決定（2026-08-16）：通常攻撃もキャラごとに違う内容にしたい。** それは**データ化しない限り書けない**（いまは `attack_type` の1欄しか違いを持てない）。

⚠ **この2つは同じ工事。** 経路を1本にすると、通常攻撃は「効果1件のスキル」になり、キャラごとに `effects[]` を書けるようになる。

---

## 2. このタスク：**通常攻撃を `effects[]` で書けるようにする**

### ⚠ 完了条件は「挙動が1件も変わらない」

**段階1（器の付け替え）と同じ形にする。** データ化と経路の一本化までをやり、**ダメージの数字も攻撃間隔も1つも変えない。**

⚠ **キャラごとに違う通常攻撃を実際に書くのは次の回。** 一緒にやると、数字が変わったとき「移し替えのミス」か「意図した変更」か分からなくなる。

### やること

| # | やること | どこ |
|---|---|---|
| **1** | **通常攻撃をJSONで持つ**（味方3体・検証用3体・敵3体の**9件**） | `characters.json` / `enemies.json`（§3-1） |
| **2** | **検証を足す**（`effects[]` は見るが `target` は書かせない） | `skill_schema.gd`（536行） |
| **3** | **`_step_unit()` が `SkillResolver.resolve()` を呼ぶ形にする** | `battle_controller.gd`（1001行） |
| **4** | **表示を `_on_skill_effects_applied()` に一本化する** | 同上 |

⚠ **1番以外は全部「200行超の既存ファイルの途中」。設計役が書く。**

---

## 3. 着手前に人間が決めること

### 3-1. ⚠ 置き場（**決定済み：エントリの中に書く**）

⚠ **新しいファイルもフォルダも要らない。** `characters.json` / `enemies.json` の各エントリの中に `basic_attack` を書く。

```
"char_swordsman": { ..., "basic_attack": { "effects": [ ... ] } }
"enemy_slime":    { ..., "basic_attack": { "effects": [ ... ] } }
```

- **ローダーの新しいパスが1つも要らない**（characters と enemies は既に読まれている）
- **敵3体の置き場問題が消える**（`enemy_slime` / `enemy_wolf` / `boss_slime_king`）
- **1ユニットの定義が1箇所に収まる**

⚠ **`characters/<id>/` フォルダには入れない。** あそこは「量が多くてキャラ別に閉じているもの」（スキル6件・ノード60件）の置き場で、**1ユニット1行の通常攻撃は能力値の隣にあるほうが読みやすい。**

### 3-2. ⚠ 検証をどう通すか

`SkillSchema.validate()` は **`target` を必須**にしている。通常攻撃は対象を**再選択してはいけない**（§4）ので、`target` を書く欄そのものが要らない。

| 案 | やり方 | 代償 |
|---|---|---|
| **A（推奨）** | `SkillSchema.validate_basic_attack()` を足し、**`_validate_effect()` を共用**する | 検証の入口が2つになる |
| B | `target` を書かせて無視する | ⚠ **「書いても効かない欄」は事故の元。** このプロジェクトで何度も刺さっている形 |

### 3-3. 通常攻撃に `delivery` を書くか

書けば**飛び道具の無効化が通常攻撃にも効く**ようになる（弓兵の矢を消す、など）。⚠ **挙動不変の範囲を出るので、今回は「欄だけ用意して使わない」か「最初から入れる」かを決めること。**

⚠ **推奨：最初から入れる**（`melee` / `projectile` / `magic`）。**この回で入れないと、次に触るのは購読の回になり、そこで挙動が変わると切り分けが増える。**

---

## 4. ⚠ 事故りやすい箇所（**先に読むこと**）

### 4-1. ⚠ **対象を再選択させない**

通常攻撃が狙うのは `unit.target_unit_id`（**歩いて近づいた相手**）。`SkillResolver.select_targets()` に選ばせると **`sort: nearest` で別人に当たりうる。**

**幸い、段階2で `resolve()` は対象IDを引数で受け取る形になっている**（`(skill_data, user, session, target_ids, registry)`）。**`[unit.target_unit_id]` をそのまま渡せばよい。**

### 4-2. ⚠ **会心を二重に振らない**

いま `_step_unit()` が `BattleFormula.roll_crit()` を呼び（427行）、`SkillResolver._apply_damage()` も**対象1体につき1回**呼ぶ（298行）。

⚠ **両方残すと乱数を振る回数が変わる。** `_step_unit()` 側を消すこと。

### 4-3. ⚠ **`atk_multiplier` を二重に掛けない**

`_compute_damage()` は `attacker.atk_multiplier` を `multiplier` として渡している（445行）。
`SkillResolver._apply_damage()` は `float(effect.multiplier) * user.atk_multiplier` を作る（295行）。

⚠ **JSONの `multiplier` は `1.0`。** `atk_multiplier` は resolver 側が掛けるので、**データに書かない。**

### 4-4. ⚠ **`SkillActivation` を通さない**

通すと `no_target` や `cooldown` で**通常攻撃が止まる**。射程判定は `_step_unit()` が既に持っている（422行）。⚠ **判定を2箇所にしない。**

### 4-5. ⚠ **攻撃間隔はCDではない**

`attack_timer` / `attack_interval_sec` はそのまま。**`skill_cooldowns` に載せないこと**（`S` キーのCDリセットで通常攻撃まで即撃ちになる）。

### 4-6. ⚠ **表示が二重に出ないこと**

`_pop_damage()` を直接呼ぶ行（430行）を消し、**`effects_applied` 経由に寄せる。** ⚠ **消し忘れるとダメージ表示が2つ重なって出る。**

---

## 5. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-16確認）

| | 事実 |
|---|---|
| 通常攻撃 | `battle_controller._step_unit()` **412〜434行**。射程内なら `attack_timer += delta`、`attack_interval_sec` を超えたら1発 |
| 通常攻撃の式 | `_compute_damage()` **440〜448行**。`BattleFormula.damage(get_power(t), get_defense(t), atk_multiplier, crit_dmg, is_crit)`。⚠ **`t` は `attacker.attack_type`** |
| 等価なJSON | `{ "type": "damage", "multiplier": 1.0, "attack_type": <キャラの attack_type>, "scale_from": "atk" または "mag" }`。⚠ **`get_power()` は物理なら `atk`・魔法なら `mag`** |
| `SkillResolver.resolve()` | 引数は `(skill_data, user, session, target_ids, registry)` の**5つ**。⚠ **`registry` の型は `RefCounted`** |
| 結果の形 | `{ "unit_id", "amount", "is_heal", "is_crit" }`（`skill_resolver.gd` **321行**） |
| 表示の経路 | `_on_skill_effects_applied()`（**659行**）が `SkillRuntime` と `StatusRegistry` の両方の `effects_applied` を受ける |
| ⚠ F3 パネルの `dmg` | `_format_damage_to_target()` が **`BattleFormula.damage()` を直接呼ぶ**（`battle_debug_panel.gd`）。⚠ **resolver を通らないので、挙動不変の突き合わせに使える独立した基準になる** |
| 敵 | **3体だけ**（`enemy_slime` / `enemy_wolf` / `boss_slime_king`）。`attack_type` はいずれも `physical` |
| 味方 | 剣士・弓兵は `physical`、**僧侶は `magic`**（射程250で `mag` 16 を撃つ） |
| 検証用キャラ | 3体とも `physical` / `attack_range` 300 / `attack_interval_sec` 2.0 |
| `SkillSchema.validate()` | **174行**。`target` は必須。`_validate_effect()` は **302行**（効果1件ぶん・**共用できる**） |
| スキルの置き場 | `characters/<character_id>/skills.json`（6キャラ × 6件＝**36件**）。ノードは同じフォルダの `nodes.json`（3キャラ × 60件＝**180件**） |
| ロード時検証のログ | `[MasterDataLoader] skills validated: 36 entries, 0 errors, 1 warnings`。⚠ **黄1本は `skill_dbg_dot_odd` の端数（出るのが正解）** |
| ロード時検証のタイミング | ⚠ **「つづきから」で出る**（`load_state()` → `_resync_growth_stats_from_master()` → `get_character()`）。⚠ **育成データが0件のセーブでは出ず、育成か戦闘に入るまで出ない** |

### 行数

| ファイル | 行数 |
|---|---|
| `game_manager.gd` | **2832** |
| `battle_controller.gd` | **1001** |
| `status_registry.gd` | **567** |
| `skill_schema.gd` | 536 |
| `skill_resolver.gd` | 519 |
| `master_data_loader.gd` | **457** |
| `battle_debug_panel.gd` | 380 |
| `skill_runtime.gd` | 358 |
| `unit.gd`（`BattleUnit`） | 236 |
| `battle_formula.gd` | **67** |
| `skill_activation.gd` | 52 |

---

## 6. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | **キャラごとに違う通常攻撃を実際に書く** | 経路が1本になってから。⚠ **数字が変わるのはここから** |
| その次 | **段階3の後半①＝購読**（反射・追撃・撃破強化・マーク・コンボ） | ⚠ **横断ルール「反応から生まれた行動は、さらなる反応を生まない」と `target.team: source` を初回に含める**（PLAN 10-2 / 10-3） |
| その次 | **段階3の後半②＝条件**（オーラ・HP依存強化・スタック閾値） | 購読が固まってから |
| その次 | **段階3の後半③＝介入点3種**（回復・状態付与・死亡）＋ 復活 | ⚠ **死亡の介入点は全滅判定より先に置く**（PLAN 11-1）。戦闘が終わってから復活する事故が無音で起きる |
| その次 | **変数表の追加**（`elapsed_sec` / `stack:<id>` / `combo_count`）＋ パッシブ ＋ コンボ | 購読と条件の両方が要る |
| 5 | `mode: area` ／ `phases[]` / `recast` ／ `spawn` | |

---

## 7. 罠

### ドキュメントの「実装済み」を信じない

**ズレが9回起きている**（直近は `master_data_loader.gd` のコメントが「育成画面か戦闘画面に入って初めて動く」と書いていた件。**実際は「つづきから」でも走る**）。`grep`で関数の中身を見てから判断する。**勝手に直さず報告する。**

### 編集したら`grep`で当たったことを確認する

「戦闘だけ反映されない」で1タスク溶かした事故がある。⚠ **今回は `battle_controller.gd` の途中を触るので、まさにその形。**

### 正常系に警告を付けない

⚠ **対象0体・射程外・死亡は全部正常系。** 毎フレーム走るので、警告を出すと出力パネルが埋まる。

### `MasterDataLoader`が返す数値は`float`

`int()`で包み忘れるとセーブに`.0`が乗る。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ。** `ja.csv`はUTF-8（BOMなし）。

### Godotを起動できない（設計役）

⚠ **「動きました」と書かない。** 完了条件は「ログ」「ファイル」「画面」の3つに分け、**同じことを2箇所に書かない。**

---

## 8. 検証の道具

**戦闘画面は `F3` でデバッグパネル**（速度1〜8倍・`K`敵1体撃破・`L`全滅・`J`物理の一撃・`M`魔法の一撃・`V`強制勝利・`B`強制敗北・`S`CDリセット・**`P`状態の一覧をコンソールへ**）。

⚠ **挙動不変の突き合わせは F3 パネルの `dmg` を使う。** あれは `BattleFormula` を直接呼んでいて **resolver を通らない**ので、**「パネルの表示値」と「実際に飛ぶダメージ」が一致すれば経路の移し替えが正しい**と言える。⚠ **会心のときだけ数字が大きくなるのは正常**（パネルは非会心のみ）。

**`tests/battle/test_status_registry.tscn`** … 器の13項目。⚠ **今回も通ること**（器は触らない）。

**検証用キャラ3体**（`parties.json` の `members` を差し替えて再起動）。⚠ **atk 1 なので通常攻撃のダメージは 1。挙動不変の確認には本編パーティを使うこと。**

---

## 9. このタスクでやらないこと

- **キャラごとに違う通常攻撃を実際に書く**（次の回。⚠ **今回は挙動不変**）
- **購読・条件・介入点3種・復活・パッシブ・コンボ**
- **通常攻撃に `trigger` や多段を持たせる**（`SkillRuntime` に載せない。⚠ **通常攻撃は待ち行列に入れない**）
- **`attack_interval_sec` を `cooldown_sec` に寄せる**（§4-5）
- **`mode: area`**（段階4）／**`phases[]` / `recast`**（段階5）／**`spawn`**（段階6）
- **バランス調整**

---

## 10. 引き継いだ宿題

`PROJECT_STATUS.md`にもあるが、**この回に関係しそうなものだけ**。

1. ⚠ **`atk_multiplier` が常に 1.0 で、使っている場所が無い**（§4-3）。⚠ **今回この値が2箇所を通るので、意味を決めるならこの回**
2. ⚠ **`SkillResolver.resolve()` の `registry` が `RefCounted` 型**（相互参照を避けるため）
3. ⚠ **`scale_from` は「和」しか書けない**（PLAN 5-5-1）。**器の穴。PLAN側で決める**
4. ⚠ **PLAN 5-2 の効果の欄の表に `delivery` / `stack` / `status_id` / `until` が無い**
5. ⚠ **PLAN 10-4 が式の二重経路に触れていない**（このタスクの発端）。**PLAN側を直すこと**
6. **`_find_unit()` が3ファイルに同じ形で3本ある**（`skill_resolver` / `skill_runtime` / `status_registry`）
7. **死亡中にCDが回る。** PLAN 14-4 の推奨は「停止」
8. **`target.range` が18件とも未設定**（座標定数とセットで後決め）
9. ⚠ **コメント中の「`skills.json`」が8ファイルに残っている**（ファイルはもう無い）
10. **`CHARACTER_IDS` の決め打ちが6件になった**（`training_screen.gd`）
11. **状態のUIが無い**（F3 パネルの3行目と `P` キーだけ）
12. **検証用のものはリリース前に消す**（デバッグオーバーレイ・デバッグパネル・`P` キー・`tests/battle/`・`skills_debug.json`・検証用キャラ3体・`PATHS_SKILLS_OPTIONAL`）

---

## 11. 終わったあと

**このファイルを、次のタスク（キャラごとに違う通常攻撃を書く）の内容に書き換える。**
