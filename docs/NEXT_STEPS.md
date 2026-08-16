# 次にやること：**状態の検証手段（コンソール出力 ＋ テストシーン）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

---

## 0. 前のタスクは「入ったが、確かめていない」

**状態の器と `buff` / `dot`（段階3の前半）の実装が入った（2026-08-16）。** 指示書は **`docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE3A.md`**、決定台帳は **`docs/01_plan/PLAN_SKILL_TEMPLATE.md`**。

⚠ **通過したのはロード時検証だけ。**

```
[MasterDataLoader] skills validated: 18 entries, 0 errors, 0 warnings
```

⚠ **`EXEC_SKILL_TEMPLATE_PHASE3A.md` §13-B の11項目は1つも確認していない。** バフが乗るのか、DoT が3回発火するのか、独立スタックが2本並ぶのか、**どれも見ていない。**

入ったもの（詳細はEXEC。**ここには複製しない**）：

- **`scripts/systems/status_registry.gd`（新規・567行）** … 状態の器
- **`effects[].stack`（新設・省略不可）** … `independent` / `refresh`
- **`effects[].until`（新設）** … `charge_end` を実装。`skill_end` は語彙だけ
- **`BattleUnit.get_stat()` が「素 ＋ 状態の補正」を返すようになった** … F3 パネルも `scale_from` も `BattleFormula` も自動でバフ込みになる
- **検証用に3スキルへ効果を足した**（`skill_power_slash` / `skill_holy_ray` / `skill_wide_sweep`）。**スキルは18件のまま**

---

## 1. このタスク：**確かめる手段を作る**

⚠ **段階3の後半（購読・条件）を先に始めないこと。** 器が実機未検証のまま購読を乗せると、不具合が出たときに**どちらの層か切り分けられない。**

### なぜ「手段を作る」が1タスクになるのか

**状態の事故は全部無音。** 黙って剥がれる／二重に付く／消えない／最後の1発が落ちる。**どれもエラーが出ない。**

そして**状態は画面に何も出ない。** F3 パネルの3行目（`_format_statuses()`）が唯一の表示だが、⚠ **`Label` に書いているだけで `print` を1つも出していない。**

> ⚠ **実装役（MiniMax）は Godot エディタ内の Ziva の中で動いており、コンソールは読めるが `Label` のテキストは読めない。**
> **`print` に出さないかぎり、検証を渡せない。**

### やること

| # | やること | 誰が |
|---|---|---|
| **1** | **F3 パネルにキーを1本足し、状態の一覧をコンソールへ1回だけ吐く** | ⚠ **設計役**（`battle_debug_panel.gd` は280行） |
| **2** | **`tests/test_status_registry.gd` + `.tscn` を作る** | **実装役に渡してよい**（新規ファイル・`print` で結果が出る） |

⚠ **毎フレーム出さないこと。** 出力パネルが埋まると本物の異常が見えなくなる（`CLAUDE.md`「正常系に警告を付けない」と同じ理由）。

⚠ **キーの割り当ては既存と衝突させない。** 使用済みは `F3` / `1`〜`4` / `K` / `L` / `S` / `J` / `M` / `V` / `B`。⚠ **`F4` は `_unhandled_input` に届かない。**

### テストシーンで書くこと（**画面では見えないもの**）

⚠ **`StatusRegistry` / `BattleUnit` / `SkillResolver` は全部 `RefCounted`。シーンツリーを必要としない。** 直接叩ける。

| 見るもの | 期待 |
|---|---|
| `stack: refresh` を2回かける | **1本のまま**。寿命が最初の値に戻る |
| `stack: independent` を2回かける | **2本になる**。⚠ **寿命がそれぞれ別**（同時に消えない） |
| 同じ `status_id` を**別の付与者**が `refresh` でかける | **2本になる**（同一性のキーは3つ組） |
| `duration 6` × `interval 2` | **ちょうど3回**発火 |
| ⚠ `duration 4` × `interval 2` | **2回発火。最後の1発が落ちないこと**（時計を1本にした理由） |
| ⚠ `duration 5` × `interval 2` | **2回発火**（端数は切り捨て） |
| ⚠ 1フレームに大きい `delta` を渡す（速度8倍相当） | **跨いだぶん全部発火する**（`while` になっているか） |
| ⚠ **付与者を殺してから `tick()`** | **DoT が止まらない**（PLAN 7-2） |
| ⚠ **宿主を殺してから `tick()`** | **状態が消え、補正も消える** |
| `set_stat_mods()` 後の `get_stat()` / `attack_interval_sec` | 変わる。⚠ **剥がすと元の値に戻る**（`atkspd` バフで累積しないこと） |
| `stat: "hp"` の buff | **赤で弾かれ、付かない** |
| `stack` を書かない buff | **赤で弾かれ、付かない** |
| `duration_sec` と `until` の両方を書く | **赤で弾かれ、付かない** |

⚠ **`BattleSession` が要る。** `StatusRegistry` は `unit_id` からユニットを引くのに使う。空のセッションにユニットを2体入れる形でよい。

⚠ **期待値と実測を両方 `print` すること。** 「OK」だけ出す形にすると、比較が合っているかを人間が確かめられない。

---

## 2. 着手前に人間が決めること

- **コンソール出力に割り当てるキー**（未使用の英字。`P` / `T` / `G` あたり）
- **テストシーンの置き場所**（`tests/` 直下でよいか。⚠ **新しいフォルダは Claude Code 側からのみ作る**）
- **失敗したときにどうするか**（`push_error` で赤を出すか、`print` に `NG` と出すだけにするか）

### 体制

**⚠ この回は実装役（MiniMax）を使ってよい。** 直近9タスクは設計役が全部書いていたが、**このタスクは「新規ファイル」と「`print` で結果が出る検証」だけ**で、`WORKFLOW.md`「実装役に渡してよい仕事」の ✅ にきれいに収まる。

⚠ **ただし §1 の1番（`battle_debug_panel.gd`・280行の途中の書き換え）は設計役が書く。** 渡すのは §1 の2番だけ。

⚠ **渡さないもの**：チャージの押しっぱなし・ジャスト・リトライ（**入力の質そのものが検証対象**）。**画面を見る検証は人間だけ**（`WORKFLOW.md`【8】）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-16確認）

| | 事実 |
|---|---|
| `status_registry.gd` | **567行**。`add()` / `tick()` / `clear_all()` / `clear_for_unit()` / `end_charge()` / `stat_mod()` / `query()` / `count()` / `has()` / `bump_counter()` / `size()` / `snapshot()` / `reset()` |
| ⚠ 器の中断 | `tick()` の先頭で**宿主が死んだ状態を毎フレーム捨てる**。⚠ **付与者の生死は見ない**（`SkillRuntime` と正反対） |
| ⚠ 器の時計 | **`elapsed` の1本だけ**。発火は `elapsed >= (fires_done + 1) × interval_sec`、消滅は `elapsed >= duration_sec`。**別々のカウントダウンを持たせないこと** |
| ⚠ 補正の持ち方 | `BattleUnit._stat_mods`。⚠ **`StatusRegistry._rebuild_unit_mods()` が毎回ゼロから組み直して `set_stat_mods()` で丸ごと渡す。`+=` / `-=` を書かない** |
| `BattleUnit.get_stat()` | **素 ＋ 補正**を返し、`maxi(0, ...)` で0未満にしない。素の値は `get_base_stat()` |
| `BattleUnit.refresh_derived()` | `max_hp` / `speed` / `attack_interval_sec` を計算し直す。⚠ **`_base_attack_interval_sec` を使う**（`create()` が保持するようになった） |
| ⚠ `SkillResolver.resolve()` | 引数は `(skill_data, user, session, target_ids, registry)` の**5つ**。⚠ **`registry` の型は `RefCounted`**（`StatusRegistry` と書くと相互参照でパースエラーを踏みうる） |
| `resolve()` の呼び出し元 | **`skill_runtime.gd` と `status_registry.gd` の2箇所だけ** |
| `SkillRuntime` | `_init(session, registry)` / `reset(session, registry)` になった。⚠ **この層は器を触らない。`_fire()` が `resolve()` へ中継するだけ** |
| `battle_debug_panel.gd` | **280行**。`_format_unit()` が1ユニットにつき2〜3行。3行目が状態（0件なら出さない）。⚠ **`print` は1つも無い** |
| 使用済みのキー | `F3` / `1`〜`4` / `K` / `L` / `S`（CDリセット）/ `J` / `M` / `V` / `B` |
| ⚠ `F4` | `_unhandled_input` に届かない。`F2`・`0`・英字キーは届く |
| `tests/` の前例 | `test_common_infra.gd` / `test_ui_common.gd` / `modal_test.gd`（どれも `.gd` + `.tscn` の組） |
| ロード時検証のログ | `[MasterDataLoader] skills validated: 18 entries, 0 errors, 0 warnings` ⚠ **これが唯一の `print`** |
| 検証用に効果を足したスキル | `skill_power_slash`（atk +6 / 8秒 / refresh）・`skill_holy_ray`（dot 0.3 / 6秒 / 2秒間隔 / independent）・`skill_wide_sweep`（def +20 / `until: charge_end` / refresh）。**全部 Lv1** |

### 行数

| ファイル | 行数 |
|---|---|
| `game_manager.gd` | **2832** |
| `battle_controller.gd` | **1001** |
| `status_registry.gd` | **567** |
| `skill_schema.gd` | 536 |
| `skill_resolver.gd` | 519 |
| `skill_runtime.gd` | 358 |
| `battle_debug_panel.gd` | 280 |
| `unit.gd`（`BattleUnit`） | 235 |
| `battle_formula.gd` | 67 |
| `skill_activation.gd` | 52 |

---

## 4. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | **skills を複数ファイル化（キャラ別 ＋ debug）＋ 枠を無視して撃つキー** | ⚠ **デバッグ用スキルを足す仕組みと分割の仕組みが同じもの**（複数ファイルを読んでマージする）。別々にやると2回作る |
| **その次** | **段階3の後半**（購読・条件・回復/状態付与/死亡の介入点・パッシブ・コンボ・復活） | 器が確かめられてから乗せる |
| 4 | `mode: area` | |
| 5 | `phases[]` / `recast` | |
| 6 | `spawn` | ⚠ 座標の規則が要る |

---

## 5. 罠

### ドキュメントの「実装済み」を信じない

**ズレが8回起きている。** `grep`で関数の中身を見てから判断する。読んだ結果ドキュメントが間違っていたら、**勝手に直さず報告する。**

⚠ **今回はそのズレが起きやすい回。** 器の実装は入ったが**挙動を1つも確かめていない**ので、「実装済み」と「動く」の差がそのまま残っている。**テストシーンはその差を埋めるために書く。**

### 編集したら`grep`で当たったことを確認する

「戦闘だけ反映されない」で1タスク溶かした事故がある。

### 正常系に警告を付けない

⚠ **対象0体・宿主の死・ウェーブ交代の全消しは全部正常系。** 出力パネルが埋まると本物の異常が見えなくなる。**コンソール出力も毎フレームにしないこと。**

### `MasterDataLoader`が返す数値は`float`

`int()`で包み忘れるとセーブに`.0`が乗る。⚠ **`duration_sec` / `interval_sec` / `elapsed` は float のままでよいが、`value` と `fires_done` / `fires_total` は `int()`。**

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ。** `ja.csv`はUTF-8（BOMなし）。

### Godotを起動できない（設計役）

⚠ **設計役は Godot を起動できない。実装役（Ziva の中）はコンソールを読めるが、画面は見えない。**
**「動きました」と書かない。** 完了条件は「ログ」「ファイル」「画面」の3つに分け、**同じことを2箇所に書かない。**

⚠ **完了条件に書くログは、実際に`print`があるものだけにする。**

---

## 6. 検証の道具

**デバッグオーバーレイが全画面の右上に常駐している**（`res://tests/debug_overlay.gd`）。`0`キーで表示切替。

戦闘画面は**`F3`でデバッグパネル**（右上・速度1〜8倍・`K`敵1体撃破・`L`全滅・`J`味方全員に物理の一撃・`M`同じく魔法・`V`強制勝利・`B`強制敗北・**`S`CDリセット**）。**ユニット1体につき2〜3行**（3行目は状態。0件なら出ない）。

⚠ **`S`（CDリセット）が独立スタックの確認手段になる。** `skill_holy_ray` は CD 12秒 / DoT 6秒なので、普通は重ならない。`S` を押して2連続で撃つと同じ敵に2本並ぶ。

⚠ **スキルは18候補あるが、1キャラ2枠しか持ち込めない。** 検証するスキルはギルドのスキル選択画面で先に付け替えること。
⚠ **Lv15 / Lv20 のスキルは、研究でレベル上限を上げないと選べない**（`base_level_cap` 10）。**今回の検証用3スキルは全部 Lv1。**
⚠ **ロード時のログはタイトルの「つづきから」でしか出ない。**

---

## 7. このタスクでやらないこと

- **段階3の後半**（購読・条件・介入点3種・パッシブ・コンボ・復活）
- **skills の複数ファイル化**（次のタスク）
- **`host: point` / `host: battle` の検証**（参照する仕組みが段階3の後半なので、まだ見るものが無い）
- **`until: "skill_end"`**（剥がす配線が無い。書くと黄が出て飛ばされる）
- **`bump_counter()` の検証**（呼び出し元がゼロ）
- **バランス調整**（検証用に足した `value: 6` / `multiplier: 0.3` / `value: 20` は暫定値）
- **`mode: area`**（段階4）／**`phases[]` / `recast`**（段階5）／**`spawn`**（段階6）

---

## 8. 引き継いだ宿題

`PROJECT_STATUS.md`にもあるが、**この回に関係しそうなものだけ**。

1. ⚠ **`SkillResolver.resolve()` の `registry` が `RefCounted` 型**（相互参照を避けるため）。**`add()` の呼び違いを静的に捕まえられない。** 状態を作る経路が増えるときに見直す
2. ⚠ **`type: buff` の `stat` に `hp` を書けない。** `max_hp` を動かすと現在HPのクランプと割合計算が同時に動く。**最大HPバフを入れる回で解く**
3. ⚠ **`until: "skill_end"` が未実装**（語彙と黄だけ）。**段階3の後半で `SkillRuntime` を触るときにまとめる**
4. ⚠ **`stack` の5部品のうち4つが未実装**（上限・消え方・再付与・閾値）。**`independent` に上限が無いので、CDより duration が長いスキルは無限に積める**
5. ⚠ **状態のUIが無い**（F3 パネルの3行目だけ）。**独立スタックはUIが先に音を上げる**
6. **`_find_unit()` が3ファイルに同じ形で3本ある**（`skill_resolver` / `skill_runtime` / `status_registry`）
7. **死亡中にCDが回る。** PLAN 14-4 の推奨は「停止」
8. ⚠ **`scale_from` は「和」しか書けない**（PLAN 5-5-1）。`atk × (1 + hp_lost_ratio)` が書けない。**器の穴。PLAN側で決める**
9. ⚠ **PLAN 5-2 の効果の欄の表に `delivery` / `stack` / `status_id` / `until` が無い**
10. **`target.range` が18件とも未設定**（座標定数とセットで後決め）
11. **`skill_reckless_strike`（捨て身の一撃）で自死できる**
12. **レベル上限が30が天井**（`base_level_cap` 10 ＋ 研究 5×4）。⚠ **パッシブの Lv40 以降が到達できない**
13. **検証用のものはリリース前に消す**（デバッグオーバーレイ・戦闘/ポモドーロのデバッグパネル・`get_status_registry()`・今回作るコンソール出力とテストシーン）

---

## 9. 終わったあと

**このファイルを、次のタスク（skills の複数ファイル化 ＋ 枠を無視して撃つキー）の内容に書き換える。**
