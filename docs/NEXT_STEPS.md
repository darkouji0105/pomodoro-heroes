# 次にやること：**コンボ（`host: battle` の購読 ＋ `combo_count`）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**、**決定台帳は`docs/01_plan/PLAN_SKILL_TEMPLATE.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

これは**段階3の後半④-b＝段階3の最後の1つ**。①購読 → ②条件 → ③介入点3種 → ④-a変数表＋パッシブ → **④-b これ**。

---

## 0. 前のタスクは終わっている（**全項目確認済み**）

**段階3の後半④-a — 変数表の「戦闘」群 ＋ `stack` の上限 ＋ パッシブ（2026-08-17）。**

⚠ **④は範囲が広かったので人間の判断で2回に割った。** ④-a が終わり、**残りはコンボだけ。**

| 入ったもの | 中身 |
|---|---|
| 変数（戦闘） | `elapsed_sec` / `alive_count_ally` / `alive_count_enemy` / `wave_index` |
| 変数（状態） | ⚠ **`stack` は入れ子**：`{ "source": "stack", "status_id": "..." }`（前方一致にしない） |
| `stack` の上限 | ⚠ **`stack: "independent"` に `max_stack` が必須**（E69） |
| `of: "source"` | ⚠ **実装しないと決めて E68 で赤にした**（定数は残っている） |
| パッシブ | ⚠ **`activation: "passive"`。「発動の型が違うだけのスキル」** |

### 0-1. ⚠ パッシブの作りは「コンボの前例」になる（**読むこと**）

- ⚠ **定義は `skills.json` のまま。** 読み込みも検証もキャッシュも分けなかった。⚠ **設計役が当初「`passives.json` ＋ 専用キャッシュ」に分ける案を書き、そのせいで「敵はパッシブを持てない」という制約を自分で作った**（人間の指摘で撤回）
- ⚠ **分けたのは「枠」だけ**（`BattleUnit.passive_ids` ／ 育成のパッシブ枠）。**枠を分けたおかげで、`_try_enemy_skill()` も戦闘画面のボタンも `skill_ids` しか見ないので、弾く仕掛けが1つも要らなくなった**
- ⚠ **発動の経路はスキルと同じ `_fire_skill()` の1本。** 違うのは**引き金を引くのが誰か**だけ（味方＝ボタン ／ 敵＝攻撃拍 ／ **パッシブ＝`_step_passives()` の走査**）

> **コンボでも同じ判断をすること。「新しい層」を作らず、既存の経路に載せられないかを先に考える。**

### ⚠ 検証の道具（この回でも使う）

| 道具 | 使い方 |
|---|---|
| **`user://logs/battle_last.jsonl`** | 1行1イベント。実体は `C:/Users/<user>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/`。⚠ **戦闘を始めるたびに空にして書き直す。読む前に別の戦闘を始めないこと。** ⚠ **設計役はこのファイルを直接読める**（ファイルの完了条件は設計役が判定する。人間にやらせない） |
| **冒険選択の「編成」** | ⚠ **`parties.json` は触らない**。検証用3体はデバッグビルドでだけ候補に出る |
| **`stage_order.json` の `"debug"` 列** | 常設・スタミナも報酬もクリア記録も付かない。⚠ **本番の `"story"` は触らない** |
| `F3` パネル | `P` 状態一覧（**出力パネルに出る**）・`S` CDリセット・`1`〜`4` 速度（1x/2x/4x/8x・**一時停止は無い**）・`O` ログ・`K`/`L` 敵撃破・`J`/`M` 自傷・`V`/`B` 強制勝敗 |

検証用ステージ：`stage_dbg_enemy_skill` ／ `stage_dbg_condition` ／ `stage_dbg_intervene` ／ **`stage_dbg_passive`**

出る出来事：`battle_start` / `wave` / `cast` / `damage` / `heal` / `dot` / `react` / `status_add` / `status_end` / `status_clear` / `condition` / `intervene` / `result`。

```
battle_controller  … 入力と表示。ノードを触る唯一の層。⚠ 死亡の走査とパッシブの走査もここ
	  ↓ cast()（スキル・通常攻撃・購読・パッシブとも）
SkillRuntime       … 待ち行列。trigger・購読の配布と発火・中断
	  ↓ 効果1件ずつ（発火は _fire() の1本）
SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
	  ↓ host が none 以外
StatusRegistry     … 状態。寿命はスキルより長い

BattleLog          … 静的クラス。どの層からも呼べる（Autoload ではない）
```

---

## 1. このタスク：**コンボ**（PLAN 15章・仕様は `GAME_DESIGN.md` 3-4）

### 1-1. ⚠ 本体は「購読を `host: battle` に広げる」こと

**コンボは戦場そのものに乗るカウンター。** 誰か1人に宿るものではない。

⚠ **`StatusRegistry.add()` は既に `host: battle` を受け付ける**（`status_registry.gd:97`）。**器はもうある。**
⚠ **止まっているのは購読の側。** 下の 3 の表を見ること。

### 1-2. `combo_count` の変数

⚠ **`scale_from` と `condition` の両方に効く**（語彙は `scale_sources()` の1本）。
⚠ **1-1 と対。片方だけ作らないこと。**

### 1-3. ⚠ 決めが要るところ（**着手前に人間に出す**）

- **コンボが増える条件は何か**（攻撃を当てるたび？ 特定のスキルだけ？ 別々のキャラが続けたとき？）
- **どうやって減るか／切れるか**（時間切れ？ 被弾？ ⚠ **「読むと消費される」は変数表に入れられない**・下の 2-2）
- **上限はあるか**（⚠ **`stack` で上限を必須にした判断と揃えるか**）
- **`host: battle` の状態は誰の `active`（条件）を見るか**（⚠ 宿主が居ないので `of: "host"` が指す相手が決まらない）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ `host: battle` を通すべき箇所は **4つある**（E51 だけではない）

| 場所 | 今どうなっているか |
|---|---|
| `skill_schema.gd` の **E51** | 購読は `host: "unit"` 以外を**赤で弾く** |
| `skill_runtime.gd` の **`_notify()`** | ⚠ **`host_unit_id == ""` なら即 return**（`skill_runtime.gd:471`）。**`host: battle` は `host_unit_id` が空なので、器に載っても一生発火しない** |
| `status_registry.gd` の `_fill_condition()` | condition は `host: "unit"` 以外を赤で弾く |
| `status_registry.gd` の `_fire_intervals()` | 非 unit の dot を飛ばす |

⚠ **`_notify()` が本丸。** E51 だけ外すと「赤は消えたのに何も起きない」になり、**エラーが1つも出ない。**

### 2-2. ⚠ 変数表に「読むと値が変わるもの」を入れない（PLAN 5-5-4）

> **読んでも値が変わらないものだけを入れる。**

- ✅ 乱数は**入れてよい**（1発につき第1段で1回しか評価されない・PLAN 11-0）
- ❌ **「読むと消費される」コンボ**は変数にできない。⚠ **消費するなら「効果として減らす」形にする**（変数は読むだけ）

### 2-3. ⚠ 変数名のtypoは「黙って0」になる

**ロード時に全件突き合わせて `push_error`**（PLAN 5-5-4）。`scale_sources()` に足し忘れると、**なぜか弱いスキル**ができてエラーが出ない。

### 2-4. ⚠ 語彙は1本・評価器は2本（**④-a で危うく落としかけた**）

`scale_sources()` を `condition_sources()` が流用している。**`scale_sources()` に足すと、その瞬間に `condition` にも書けるようになる。**
評価器は別々の2本：**`SkillResolver._scale_variable()`** と **`StatusRegistry._condition_value()`**。
⚠ **片方に枝を足し忘れると `push_error` ＋ 0.0。赤は1行出るが戦闘は続く。**
⚠ **④-a では条件側の枝が2戦闘ぶん未検証のまま残りかけた。検証は必ず両方を通すこと。**

### 2-5. ⚠ 検証用データは「その値が実際に動くか」を先に確かめてから書く

**④-a で設計役が2回間違えた（どちらも人間が気づいた）。**

- **自分に付くバフを `of: "target"`（敵）で見ようとした** → 永遠に0
- **`char_debug_status` は `hp: 9999`** なので `hp_lost_ratio >= 0.5` の条件に到達できなかった

### 2-6. ⚠ 検証用の敵を作るときの定石

- **敵の `cooldown_sec` が `attack_interval_sec` より短いと、その敵は通常攻撃を1度もしない**（`_try_enemy_skill()` が true を返すと `_fire_basic_attack()` へ行かない）
- **敵はスキルを「射程内に入った最初の攻撃拍」でしか撃たない。** ⚠ **それより早く倒すと、そのスキルは一度も撃たれない**（④-a で復活が起きず「壊れた」と誤判定しかけた）

### 2-7. ⚠ 効果の中の欄に「知らない欄」の検出が無い

E26 が見ているのは**スキル直下**（`SKILL_FIELDS_KNOWN`）だけ。**効果の中の typo は今も無音で無視される。**

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-17確認）

| | 事実 |
|---|---|
| ⚠ 購読の制限 | **E51 が `host: "unit"` 以外を赤で弾く**（`skill_schema.gd`） |
| ⚠ **購読の発火** | **`_notify()` が `host_unit_id == ""` で即 return**（`skill_runtime.gd:471`）。⚠ **ここがコンボの本丸** |
| 状態の器 | ⚠ **`add()` は既に `host: battle` を受け付ける**（`status_registry.gd:97`）。`host_unit` に `null` が来る前提で書かれている |
| 変数の評価 | `SkillResolver._scale_variable(source, of, user, target, session, registry, status_id)` ／ `StatusRegistry._condition_value(cond, unit)` の**2本** |
| 変数の一覧 | `skill_schema.gd` の `scale_sources()`。**10軸は `GameManager.get_stat_keys()` から組み立てている** |
| `of` を読まない群 | `SkillSchema.SCALE_SOURCES_NO_OF`（`distance` / `elapsed_sec` / `wave_index`）。⚠ **例外の一覧はこの1本。足すときは必ずここに入れる** |
| 介入点 | ダメージ＝`skill_resolver.gd`（⚠ **2本とも `pass`・利用者ゼロ**）／ 回復＝`_step_heal_taken()` ／ 状態付与＝`_step_status_block()` ／ 死亡＝`_step_death()` |
| ⚠ DoT と購読 | **DoT の周期ダメージでは購読が発火しない**（`StatusRegistry` が `SkillRuntime` を通らない） |
| ⚠ 数字の実測 | 検証用キャラの `atk` は 1 だが**与ダメージは 4**。**絶対値で期待値を書かない。差で見る** |
| ⚠ ウェーブ交代 | **`status_clear` が味方の状態も捨てる**（ユニットを作り直さなくても消える） |
| 行数 | `game_manager.gd` **3048** ／ `battle_controller.gd` **1371** ／ `status_registry.gd` **1121** ／ `skill_schema.gd` **986** ／ `skill_resolver.gd` **650** ／ `skill_runtime.gd` 536 ／ `battle_log.gd` 313 ／ `unit.gd` **279** ／ `skill_select_screen.gd` **232** ／ `battle_session.gd` **80** ／ `skill_activation.gd` **52** |

---

## 4. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | `mode: area` ／ `phases[]` / `recast` ／ `spawn` ／ **`point` の条件（オーラ）** | 段階4〜6。⚠ **段階3はコンボで終わり** |
| その次 | **ダメージの介入点の利用者**（シールド・軽減・反射・貫通%・確定クリティカル） | 受け口は段階1からある。⚠ **4つのうちここだけ利用者ゼロ** |
| 3 | **バランスの実測** | 構造が出揃ってから |

---

## 5. 罠

### ドキュメントの「実装済み」を信じない

**ズレが11回起きている。** `grep`で関数の中身を見てから判断する。**勝手に直さず報告する。**

### PLAN の「保証される」も確かめる

⚠ **③で踏んだ。** PLAN 14-4 の「復活の『1回だけ』は全消しで自動保証される」は、実際には**「付与1回につき復活1回」**でしかなかった。**PLAN 11-1 / 14-4 は2026-08-17 に人間の承認を得て修正済み。**

### 関数を足す前に `grep` する

**足す前に `grep -n "func <名前>"`、足したあとにも `grep` で当たったか確認する。**

### ⚠ Windows の bash で `cat >>` すると追記分が CRLF になる

元が LF の JSON に混ざって壊れる。**JSON に追記したら改行コードを確かめる。**

### ⚠ 検証スクリプトの文字コード

⚠ **Windows PowerShell の `Get-Content` は既定が ANSI。** `ja.csv` を読むと**途中までしか読めず**、「キーが無い」と誤判定する（④-a で1度踏んだ）。**`[System.IO.File]::ReadAllLines(path, [System.Text.Encoding]::UTF8)` を使うこと。**

### ⚠ `battle_last.jsonl` は戦闘のたびに上書きされる

**読む前に別の戦闘を始めないこと。**

### 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。** コンソールに流さない。
⚠ **④-a で `condition` の黄を1本入れかけて取り消した**（条件は `of` が必須なので、正しい書き方のたびに黄が出るところだった）。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ `stages.json` だけトップレベルが半角スペース2つ）。`ja.csv`はUTF-8（BOMなし）。

### Godotを起動できない（設計役）

⚠ **「動きました」と書かない。** 完了条件は「ログ」「ファイル」「画面」の3つに分け、**同じことを2箇所に書かない。**
⚠ **「ファイル」（`battle_last.jsonl`）は設計役が直接読んで判定する。人間にやらせない。**
⚠ **「ログ」と静的な突き合わせは Ziva に切り出せる**（`EXEC_INTERVENTION_ZIVA_CHECK.md` が型。**「やらないこと」を先頭に書き、`battle_last.jsonl` を読ませない**）。

---

## 6. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここには**この回に関係するものだけ**を写す。

### 器の穴（この回で埋まりうるもの）

1. ⚠ **購読は `host: unit` のみ**（コンボ・罠がまだ載らない）← **この回の本体**
2. ⚠ **`point` の条件（オーラ）は真偽が「状態 × ユニットの対」ごとになる。** 今の `active`（状態1件につき1つ）では足りない。⚠ **`host: battle` にも同じ問題が出るか先に考えること**
3. ⚠ **`scale_from` は「和」しか書けない**（`multiplier × Σ(weight × 変数)`）。`atk × (1 + hp_lost_ratio)` が書けない
4. ⚠ **DoT の周期ダメージでは購読が発火しない**
5. ⚠ **`stack` の5部品のうち、上限だけ入れた。** 消え方・再付与・閾値は未実装

### 器の作り

6. ⚠ **ダメージの介入点だけ利用者ゼロ**（`_step_crit_override` / `_step_reduction` は `pass`）
7. ⚠ **`buff` の介入の欄が3つ兄弟。4つ目が来たら `intervene{}` の入れ子に畳む**
8. ⚠ **効果の中の欄に「知らない欄」の検出が無い**（typo が無音）
9. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない**
10. **死亡中にCDが回る**（PLAN 14-4 は「推奨：死亡中は停止」）
11. ⚠ **パッシブは `dispel` で剥がせない**（走査が次フレームで戻す）
12. ⚠ **`is_skill_ready()` は `skill_ids` と `passive_ids` の両方を見るが、`start_cooldown()` は `skill_ids` だけ**（意図的な非対称。揃えると壊れる）
13. **`_find_unit()` が3ファイルに同じ形で3本ある**
14. ⚠ **`target.range` が未設定** ／ ⚠ **`atk_multiplier` が常に 1.0**
15. ⚠ **多段の2発目に投射物が出ない**（`skill_rapid_volley` の `delay:0.35`）

### 片付け

16. **検証用のものはリリース前に消す**（⚠ **`stage_dbg_passive` とパッシブ4件・`skill_dbg_scale_battle` が増えた**）
17. ⚠ **フォルダを増やしたら定数に1行足す**（`CHARACTER_DIRS_REQUIRED` / `ENEMY_DIRS_*`）。**足し忘れると無音で消える**
18. **状態のUIが無い**（F3 パネルと `P` キーだけ）
19. **Ziva が作った `.bak` が7件残っている**。**消すのは人間の判断**
20. ⚠ **`AGENTS.md` に足すか人間が判断するもの**：CRLF の話 ／ **`CHARACTER_GROWTH` の表に `passives` を足すか** ／ **PowerShell の文字コードの話**

---

## 7. 終わったあと

**このファイルを、次のタスク（`mode: area` ／ `phases[]` ／ `spawn` ／ `point` の条件）の内容に書き換える。**
⚠ **コンボが終われば段階3は完了。** 次からは段階4以降。
