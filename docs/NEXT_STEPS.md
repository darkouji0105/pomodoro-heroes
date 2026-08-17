# 次にやること：**段階3の後半② — 条件（毎フレーム評価する発火源）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**、**決定台帳は`docs/01_plan/PLAN_SKILL_TEMPLATE.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **これはスキルのPLANの軸に戻る回。** 前2回（戦闘ログ・敵の管理）は、この回を追えるようにするための土台だった。

---

## 0. 前のタスクは終わっている（**全項目確認済み**）

**敵の管理を味方と同じにする（2026-08-17）。** 人間が画面を、設計役がログを確認済み（`IMPL_LOG_ENEMY_PARITY.md`）。

- 敵スキルは `resources/balance/master/**enemies/**<enemy_id>/skills.json`（`characters/` と同じ階層・同じ形）
- ⚠ `enemies.json` の `"skills"` は**そのまま装備枠**（味方の「候補一覧→選んだ2枠」の2段は無い）
- 敵は**攻撃間隔と同じ拍で、射程内でだけ、CDが空いたスキルを先頭から撃つ**（乱数なし＝ログが再現する）
- **検証用の敵6体**：`enemy_dbg_react` / `_followup` / `_buff` / `_dot` / `_heal` / `_ranged`（**1体1スキル**）
- ⚠ **敵視点の `team` 解決（`ally` が敵の仲間を指す）が初めて実際に通った。** `heal` の `dst` が全て `enemy_` であることをログで確認済み

### ⚠ 検証用ステージは「別枠」で常設（**この回で一番効く道具**）

```json
// stage_order.json … ⚠ "story" は触らない
{ "story": ["stage_1", "stage_2", "stage_3"], "debug": ["stage_dbg_enemy_skill"] }
```

- 冒険選択の**末尾**に「▼ 検証用」の見出しで出る（`OS.is_debug_build()` のときだけ）
- **常に解放。** 本編の解放の連鎖に入らない
- **`STAGE_TYPE_TRAINING` で入るので、スタミナも報酬もクリア記録も付かない**
- ⚠ **テストしたいこと1つにつきステージ1本。この回は `stage_dbg_condition` を足す**（`"debug"` 配列に1行）

### 検証はログを読む（画面を見ない）

`user://logs/battle_last.jsonl` に1行1イベント。実体は
`C:/Users/<user>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/`。
出る出来事：`battle_start` / `wave` / `cast` / `damage` / `heal` / `dot` / `react` / `status_add` / `status_end` / `status_clear` / `result`。

```
battle_controller  … 入力と表示。ノードを触る唯一の層
      ↓ cast()（スキル・通常攻撃・購読とも）
SkillRuntime       … 待ち行列。trigger・購読の配布と発火・中断
      ↓ 効果1件ずつ（発火は _fire() の1本）
SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
      ↓ host が none 以外
StatusRegistry     … 状態。寿命はスキルより長い

BattleLog          … 静的クラス。どの層からも呼べる（Autoload ではない）
```

---

## 1. このタスク：**条件（PLAN 10章の3つ目の発火源）**

### 発火源は4つあり、3つ目だけが無い

| 発火源 | きっかけ | 置き場所 | 状態 |
|---|---|---|---|
| 自分の実行 | `trigger`（6章） | `SkillRuntime` の待ち行列 | ✅ 済 |
| **購読** | 外の出来事 | `SkillRuntime._notify()` | ✅ 済（後半①） |
| **条件** | **毎フレーム評価する** | **状態の器** | ❌ **これ** |
| 周期 | 一定間隔 | `StatusRegistry._fire_intervals()` | ✅ 済（`dot` の `interval_sec`） |

### `host` × 条件 で何が書けるか（PLAN 10-1）

| 宿り先 | 条件で書けるもの |
|---|---|
| `unit` | **HP依存強化**（HPが半分以下の間だけ攻撃力up）・**スタック閾値** |
| `point` | **オーラ**（範囲内に居る間） |
| `battle` | 全体条件 |

### ⚠ なぜこの順で、なぜ土台を先に作ったか

**毎フレーム評価は、事故が全部無音になる。** 条件が一度も真にならなくても、常に真でも、
エラーは1つも出ない。**画面を見ても分からない。**
→ **`battle_last.jsonl` に「条件が真になった／偽に戻った」が出る形にすること**（§2-4）。

### 着手前に人間が決めること

- **条件の書き方**（`when` の欄を効果に足す ／ 状態に `condition` を持たせる ／ 両方）
- **どこまでやるか**（`unit` の HP依存だけ ／ `point` のオーラまで ／ スタック閾値まで）
  ⚠ **スタック閾値は宿題5（`stack` の5部品のうち4つが未実装）と正面衝突する。** 先に宿題5を片付けるか、この回では触らないかを決める
- **評価の頻度**（毎フレーム ／ 一定間隔で間引く）
  ⚠ **`StatusRegistry.tick()` は既に毎フレーム全件を回している。** 条件をそこに足すと、状態の件数 × 条件の重さになる

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ 「真になった瞬間」と「真である間」は別物

バフを**付けたり剥がしたり**するのか、**効果の値を毎フレーム変える**のかで実装が丸ごと違う。
⚠ **どちらかに決めてから書く。** 混ぜると「剥がれないバフ」と「二重に乗るバフ」が同時に出る。

### 2-2. ⚠ 式を2回評価しない（PLAN 11-0 の不変条件）

**ダメージは1回だけ計算され、以降は確定した数値として持ち回される。**
条件で威力を変えるとき、**確定後の数値を書き換えない。**

### 2-3. ⚠ 補正の組み直しを呼び忘れない

条件でバフが付いたり消えたりするなら、`StatusRegistry._rebuild_unit_mods()` を通すこと。
**状態を足しただけでは能力値に反映されない**（`clear_all()` で踏んだのと同じ形）。

### 2-4. ⚠ ログに出す（**毎フレーム出さない**）

`BattleLog` に `condition`（真偽が**変わったとき**だけ）を1行出す。
⚠ **毎フレーム出すと1戦で数万行になる。** 「変化した瞬間だけ」に絞ること。
⚠ 位置・移動を出さないのと同じ理由（`EXEC_BATTLE_LOG.md`）。

### 2-5. ⚠ `battle_controller` に条件を散らさない

`SkillActivation.blocked_reason()` が「今撃てるか」に答える唯一の場所（PLAN 12章）。
**発動条件と効果の条件を混ぜないこと。**

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-17確認）

| | 事実 |
|---|---|
| 状態の器 | `StatusRegistry`。`tick()` が毎フレーム全件を回し、`_drop_dead_hosts()` → 時計を進める → `_fire_intervals()` → `_expire()` → `_rebuild_touched()` の順 |
| 状態の1件が持つ欄 | `instance_id` / `status_id` / `kind` / `host` / `host_unit_id` / `host_x` / `source_unit_id` / `stack` / `life` / `duration_sec` / `elapsed` / `stat` / `value` / `damage_effect` / `interval_sec` / `fires_done` / `fires_total` / `react` / **`counter`（PLAN 13-1・⚠ 呼び出し元がまだ無い）** |
| 状態への問い合わせ口 | `query()` / `count()` / `has()` / `stat_mod()` / `bump_counter()`（**条件から使う想定で用意済み**） |
| 発火の1本道 | `SkillRuntime._fire()`。⚠ **`StatusRegistry._fire_intervals()` だけがここを通らない**（DoT・宿題17） |
| 変数表 | `SkillResolver` の `scale_from`。⚠ **`hp_lost` は既にある**（`skill_dbg_scale_sum` が使用）。⚠ `of: "source"` は未実装（宿題18） |
| 撃てるかの判定 | `SkillActivation.blocked_reason()` の1箇所 |
| 検証の道具 | **`battle_last.jsonl`** ／ **`"debug"` 列の検証用ステージ** ／ `F3` パネル（`P` 状態一覧・`S` CDリセット・`1`〜`4` 速度・`O` ログ） |
| 検証用キャラ | `char_debug_status` / `_life` / `_mix`（各7スキル）。⚠ **`parties.json` の `members` を差し替えて再起動。戻し忘れないこと**（前回**実際に戻し忘れた**） |
| 検証用の敵 | `enemy_dbg_*` 6体（`enemies/<id>/skills.json`）。⚠ **敵にも条件を持たせて検証できる** |
| ⚠ 候補一覧 | 味方にスキルを足すときは **`characters.json` の `"skills"` 配列にも足す**（`skills.json` だけでは画面に出ない） |
| ロード時検証 | `skills validated: 45 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 15 entries, 0 errors, 0 warnings`。⚠ **黄1本は `skill_dbg_dot_odd` の端数で、出るのが正解** |

### 行数

| ファイル | 行数 |
|---|---|
| `game_manager.gd` | **2832** |
| `battle_controller.gd` | **1209** |
| `skill_schema.gd` | **712** |
| `status_registry.gd` | **630** |
| `master_data_loader.gd` | **586** |
| `skill_resolver.gd` | 538 |
| `skill_runtime.gd` | **532** |
| `battle_debug_panel.gd` | 385 |
| `battle_log.gd` | 269 |
| `adventure_select.gd` | 246 |
| `unit.gd`（`BattleUnit`） | 251 |

---

## 4. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | **③＝介入点3種（回復・状態付与・死亡）＋ 復活** | ⚠ **死亡の介入点は全滅判定より先に置く**（PLAN 11-1） |
| その次 | **④＝変数表の追加 ＋ パッシブ ＋ コンボ** | 購読と条件の両方が要る |
| 3 | `mode: area` ／ `phases[]` / `recast` ／ `spawn` | |
| 4 | **バランスの実測** | 構造が出揃ってから |

---

## 5. 罠

### ドキュメントの「実装済み」を信じない

**ズレが10回起きている。** `grep`で関数の中身を見てから判断する。**勝手に直さず報告する。**

### 関数を足す前に `grep` する（**戦闘ログの回で踏んだ**）

既にある `_exit_tree()` を見ずに2本目を宣言し、`Function "_exit_tree" has the same name as a previously declared function` でパースエラーになった。
**足す前に `grep -n "func <名前>"`、足したあとにも `grep` で当たったか確認する。**

### ⚠ Windows の bash で `cat >>` すると追記分が CRLF になる（**敵の回で踏んだ**）

元が LF の JSON に混ざって壊れる。**JSON に追記したら改行コードを確かめる。**

### 検証用のデータを戻し忘れる（**敵の回で踏んだ**）

`parties.json` の `members` が検証用3体のまま残っていた。**ステージ側は別枠にして戻す運用を無くしたが、パーティはまだ差し替え式。**

### 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。** コンソールに流さない。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ `stages.json` だけトップレベルが半角スペース2つ）。`ja.csv`はUTF-8（BOMなし）。

### Godotを起動できない（設計役）

⚠ **「動きました」と書かない。** 完了条件は「ログ」「ファイル」「画面」の3つに分け、**同じことを2箇所に書かない。**
⚠ **`battle_last.jsonl` で判定できる項目は「ファイル」に書く。** 画面の項目が減るだけ人間の手間が減る。

---

## 6. 引き継いだ宿題

1. ⚠ **多段の2発目に投射物が出ない**（`skill_rapid_volley` の `delay:0.35`）
2. ⚠ **`x is Node and is_instance_valid(x)` の順序が逆な箇所が3つ**（`battle_controller.gd` 163 / 251 / 493行付近）
3. ⚠ **僧侶の範囲攻撃は `sort: all` なので射程外にも当たる**
4. ⚠ **`atk_multiplier` が常に 1.0**
5. ⚠ **`stack` の5部品のうち4つが未実装**（上限・消え方・再付与・閾値）。⚠ **この回の「スタック閾値」と正面衝突する**
6. ⚠ **`scale_from` は「和」しか書けない**
7. ⚠ **PLAN 5-2 の効果の欄の表に `delivery` / `stack` / `status_id` / `until` が無い**
8. ⚠ **PLAN 10-4 が式の二重経路に触れていない**
9. **`_find_unit()` が3ファイルに同じ形で3本ある**
10. **死亡中にCDが回る**
11. ⚠ **`target.range` が45件とも未設定**
12. ⚠ **コメント中の「`skills.json`」が8ファイルに残っている**
13. ⚠ **フォルダを増やしたら定数に1行足す**（キャラ＝`CHARACTER_DIRS_REQUIRED` ／ **敵＝`ENEMY_DIRS_REQUIRED`（今は空）**）
14. **`adventure_config.tres` が空**
15. **状態のUIが無い**（F3 パネルと `P` キーだけ）
16. **検証用のものはリリース前に消す**（デバッグオーバーレイ・デバッグパネル・`P`キー・`tests/battle/`・検証用キャラ3体・検証用スキル3件と状態4件・**戦闘ログ一式**・**検証用の敵6体と `enemies/` フォルダ**・**`"debug"` 列と `adventure_select` の3関数**）
17. ⚠ **DoT の周期ダメージでは購読が発火しない**（`StatusRegistry` が `SkillRuntime` を通らない）。**ログでは「`dot` の直後に `react` が出ない」ことで見える**
18. ⚠ **`scale_from` の `of: "source"` が未実装**
19. ⚠ **購読は `host: unit` のみ**（コンボ・罠はまだ載らない）
20. ⚠ **足した7件目だけ JSON のインデントが1タブ深い**（3ファイル・見た目だけ）
21. **戦闘ログの完了条件15（落ちた戦闘）が未検証**。⚠ 9（追撃）と11（DoT）は敵の回で確認済み
22. ⚠ **`adventure_select.gd:4` のヘッダコメントが実装と逆**（スタミナを減らすのは `battle_controller._consume_stage_stamina()`）
23. **購読から生まれた `cast` の `targets` が空配列**（対象が確定する前にログを出しているため）。⚠ **実際に当たった相手は直後の `damage` 行の `dst` で分かる**
24. **古いセーブに `stage_dbg` のクリア記録が残っている**（改名前のID。マスターに無いので実害なし）
25. ⚠ **`AGENTS.md` の「ツールの制約」に CRLF の話を足すかは人間の判断**

---

## 7. 終わったあと

**このファイルを、次のタスク（③＝介入点3種＋復活）の内容に書き換える。**
