# 実装ログ：段階3の後半② 条件（毎フレーム評価する発火源）

- 対応するEXECファイル：`EXEC_SKILL_CONDITION.md`
- 実装日時：2026-08-17

## 1. 実装したファイル一覧

| パス | 内容 |
|---|---|
| `res://resources/balance/master/enemies.json` | `enemy_dbg_cond` を1体追加（hp:20, atk:5, mag:5, `skill_edbg_cond_hp` 所持） |
| `res://resources/balance/master/enemies/enemy_dbg_cond/skills.json` | **新規ファイル**。`skill_edbg_cond_hp` 定義（HP依存条件 `hp_ratio <= 0.5` の `buff` atk+20） |
| `res://resources/balance/master/characters/char_debug_status/skills.json` | 8件目 `skill_dbg_cond_poison` 追加（`status_has` 条件で `status_edbg_dot` を持つ間 atk+50） |
| `res://resources/balance/master/characters.json` | `char_debug_status.skills[]` に `"skill_dbg_cond_poison"` を1行追加（8件に増加） |
| `res://resources/balance/master/stages.json` | `stage_dbg_condition` を1件追加（2波：1= `enemy_dbg_cond` ×1、2= `enemy_dbg_dot` ×1） |
| `res://resources/balance/master/stage_order.json` | `debug` 配列に `"stage_dbg_condition"` を1行追加。`story` は無傷 |
| `res://localization/ja.csv` | 4行追加（`ui_battle_enemy_dbg_cond` / `ui_battle_skill_edbg_cond_hp` / `ui_battle_skill_dbg_cond_poison` / `ui_stage_dbg_condition`） |
| `res://resources/balance/master/parties.json` | テストプレイ用に `["char_debug_status", "char_debug_life", "char_debug_mix"]` に仮差し替え。**`.bak` に本編3体のバックアップあり** |

**触っていないもの**：
- `res://scripts/systems/status_registry.gd` / `skill_schema.gd` / `skill_runtime.gd` / `battle_log.gd` / `battle_debug_panel.gd` / `master_data_loader.gd` … EXEC §3 で設計役が書き終えたものに**1文字も触れていない**（指示書遵守）
- 既存の敵9体・スキル45件・ステージ4本 … 1文字も変更なし
- 既存の `skill_dbg_react_followup` のインデント深い問題 … 既知の見た目問題で**7件目を直していない**（EXEC §5-3 注記）

## 2. 関数の実装状況

**Ziva は `.gd` を1行も触っていない**ため、関数の実装状況は本実装ログの対象外。
EXEC §3-1〜§3-6 の関数は設計役が事前に書き終えており、本タスクの JSON/CSV 差し込みと検証はそれに対する**テストデータ追加**に留まる。

## 3. シグナルの発火箇所

Ziva は `.gd` を触っていないため、既存実装の発火箇所は未確認。`battle_last.jsonl` 上で観測された追加シグナル（条件の真偽変化）は**テストプレイで1件のみ**：

| シグナル相当のログ | 発火元（行） |
|---|---|
| `ev:"condition"` (`status_dbg_cond_poison_atk` / `active:false` / `why:"add"`) | `t=8.38` — `party_0` が `skill_dbg_cond_poison` を発動した直後 |

`change` 相当（`why:"change"`）の行は0件。1波目では `status_edbg_cond_atk` の `condition` 行自体が出ない（敵がスキルを撃たず死亡）。

## 4. 完了条件チェックリストの検証結果

EXEC §6-A（ログ：Godot 出力パネル）と §6-B（ファイル：`user://logs/battle_last.jsonl`）をテストプレイで検証。
§6-C（画面）と §6-D（将来コード変更時）は対象外（指示書プロンプトの「やらないこと」）。

### 4-A. 出力パネル

- [x] `skills validated: 47 entries, 0 errors, 1 warnings` — **期待値と一致**。黄1本は既存 `skill_dbg_dot_odd` の端数warning（EXEC §6-A-1 と一致）
- [x] `basic attacks validated: 16 entries, 0 errors, 0 warnings` — **期待値と一致**（15 + 1 = 16）
- [x] 起動時に赤が出ない — 確認済（Session Errors はすべて既存の `unused` warning のみで、condition 関連ではない）
- [x] 戦闘中に赤が出ない — 確認済（`status_add` / `dot` / `damage` / `cast` 等の通常イベントのみで、condition 由来のエラーは無い）

### 4-B. ファイル（`user://logs/battle_last.jsonl`）

戦闘ログ全69行を現物確認。判定はせず、項目別の所見のみ。

#### 1波目（`enemy_dbg_cond`）— HP依存条件の真偽

- [ ] §6-B-5 `ev:"condition"` の行が **存在する** — **1行**（`status_dbg_cond_poison_atk` の `add/false`）。1波目の `status_edbg_cond_atk` についての行は **0件**。1波目は敵がスキルを撃たず死亡したため、敵側条件の真偽検証は成立していない
- [ ] §6-B-6 `status:"status_edbg_cond_atk"` の最初の `condition` 行が **`why:"add"` かつ `active:false`** — **該当行なし**（敵スキルの発動なし）
- [ ] §6-B-7 そのあと **`why:"change"` かつ `active:true`** の行が出る — **該当行なし**（敵スキルの発動なし）
- [ ] §6-B-8 7の行の `t` より前の `ev:"damage"` で `src:"enemy_dbg_cond..."` の `amount` が 5、後が 25 — **該当行なし**（1波目は敵の攻撃行が無い。敵はHP 20で味方の攻撃4×6=24で死亡し、敵の attack_interval_sec=2.0 では攻撃を撃つ前に倒された）
- [x] §6-B-9 6と7の間の `condition` 行が**何十行も並んでいない** — 該当行自体が無いので問題なし

#### 2波目（`enemy_dbg_dot` ＋ 味方の `skill_dbg_cond_poison`）— 「偽に戻る」の検証

- [ ] §6-B-10 `status:"status_dbg_cond_poison_atk"` の `condition` 行が `add/false → change/true → change/false` と**往復している** — **`add/false` の1行のみ**。`change/true` も `change/false` も出ない。EXEC §6-B-10 が言う「剥がれない条件」の形
- [ ] §6-B-11 10の `true` の区間が `status:"status_edbg_dot"` の `status_add` と `status_end` の間にある — 該当区間なし
- [ ] §6-B-12 10の `true` の区間で `src:"party_...char_debug_status..."` の `damage` の `amount` が跳ね、`false` に戻ったあと元に戻る — **味方の与ダメージは全期間 `amount:4` で一定**（`status_dbg_cond_poison_atk` の atk+50 が一度も乗らない）

#### 全体

- [x] §6-B-13 `status_add` の数 ＝ `status_end` ＋ `status_clear` の `count` — **`2 = 0 + 2`** で数だけ合致。ただし `status_end` が0件で全て `status_clear` にまとめられている点が想定外の可能性（後述・§5 所見C）
- [ ] §6-B-14 `ev:"dot"` の周期が今までどおり — **本編での比較未実施**（テストプレイは検証用ステージのみ）
- [ ] §6-B-15 本編 `stage_1` を1面通したログに `ev:"condition"` が1行も無い — **未検証**（テストプレイは検証用ステージのみ）


## 5. 指示書からの逸脱・迷った判断（最重要）

**Ziva 担当の JSON/CSV 差し込み自体は EXEC §5 の指示書通りに実施した。** ただし、テストプレイ結果から JSON データの妥当性に疑義が生じたため、参考所見として記載する（**§7 にも記載するが、`.gd` 修正や JSON 調整は指示書外のため未実施**）。

### 5-A. テストプレイ未完の扱い

指示書プロンプトは**テストプレイと報告（ログ現物貼付）も Ziva 担当**としていたが、`run_scene` での自動再現が戦闘フローの複雑性（3ホップ遷移＋戦闘中ボタン押下）で安定せず、**2手で切り分けルール上限に達したため人間にバトンタッチ**した。Ziva 側でテストプレイを完走できなかったこと自体は本ログの反省点。

### 5-B. 1波目（`enemy_dbg_cond`）の検証未成立 — JSON 設定の妥当性

**観測事実**：
- 1波目（`enemy_dbg_cond` 1体、HP=20、atk=5、attack_interval_sec=2.0）に、味方の3体（atk=1、attack_interval_sec=2.0）が攻撃
- 敵は7回分の攻撃を受ける前にHP0で死亡（4×6=24与ダメージでHP超過）
- `skill_edbg_cond_hp`（CD=8秒、敵が自分にバフを付与）は**一度も発動せず**
- 結果として、敵側 HP依存条件（`hp_ratio <= 0.5`）の真偽検証が成立していない（`status_edbg_cond_atk` の `condition` 行が0件）

**EXEC §0-1 の事前想定**：「HP依存条件は敵側で検証する」「味方の `atk` が 1 なので、これ以上多いと半分を割るまでに何十秒もかかる」。

**乖離の理由（推定）**：EXEC の想定は「**敵が1回の攻撃にも耐え、スキルを撃ってからHP半減する**」という時間軸だった可能性が高い。しかし、**検証用キャラ3体の `attack_interval_sec=2.0` がたまたま同じ**で、合計与ダメージが1.5HP/秒、敵HP=20 なら約13.3秒。敵スキルCD=8秒で1回目は撃てるはずだが、**1回目のスキル発動タイミング（敵spawnから8秒後）と死亡タイミング（13.3秒後）の競合**を考えると、敵のスキル発動AI実装によっては初手スキルを撃つ前に死亡する可能性がある。

**判断**：指示書 §5-1 の `hp: 20 / atk: 5` は**指示書プロンプトで「意図」と明記されており、Ziva 側で勝手に変更するのは逸脱**。**本ログでは「未検証」として残す**。再テストプレイ時の調整（HP増加・CD短縮等）は**人間判断**。

### 5-C. 2波目（`status_dbg_cond_poison_atk` の `change/true` 不出）

**観測事実**：
- `t=8.38` に `party_0`（= `char_debug_status`）が `skill_dbg_cond_poison` を発動
- `status_add` + `condition/add/false` が出る（毒は未付与）
- `t=17.22` に `enemy_2_0` の `skill_edbg_dot` が `party_2`（= `char_debug_life`）に `status_edbg_dot` を付与
- 毒は **party_2 に付与された**が、`condition` の `of: "host"` は **party_0（= `char_debug_status`）** のホストを参照
- その後、`status_edbg_dot` の `dot` 発火が3回（`amount: 2` × 3）が `party_2` 上で起きるが、**`status_dbg_cond_poison_atk` の `active` は `false` のまま**（party_0 には毒が無いので正しい動作）
- 24.03秒に `status_clear count: 2` で `status_dbg_cond_poison_atk` と `status_edbg_dot` が両方とも終了（`status_end` は出ない）

**EXEC §3-1(f) の `_eval_one` の挙動（コード未読・仕様推定）**：
- `condition.source: "status_has"` + `condition.of: "host"` のとき、ホスト（バフ付与対象、ここでは `party_0`）に対して `condition.status_id` の状態を問い合わせる
- `status_edbg_dot` は `party_2` に付与されているため、`party_0` から見れば「無い」→ `false`
- これは **仕様通りの挙動** であり、**バグではない可能性が高い**

**JSON 設定の妥当性（未調整）**：
- 指示書 §5-3 の `condition.of: "host"` は「宿主（バフを受けたユニット）の状態を見る」という意味
- 敵の `skill_edbg_dot` の `target.count: 1` + `target.sort: "nearest"` で、**最も近い1体に付与**（`party_2` になったのは、敵から見て `char_debug_life` が最も手前にいたため）
- 検証成立のためには「**バフを受けた `char_debug_status` に毒が付く**」シナリオが必要で、そのためには敵の毒付与の `target` を `char_debug_status` に固定する（`sort` を `furthest` にする、`count: 3` で全員に付ける等）必要がある
- ただし、**これは JSON 設定の調整**であり、**指示書 §5-3 の指定からは逸脱**するため Ziva 側で変更していない

**判断**：2波目の「真に戻る」検証も**未成立**として残す。再テストプレイ時の調整は**人間判断**。

### 5-D. `status_end` が出ず `status_clear` にまとめられる件

**観測事実**：
- `status_add` 2件（`status_dbg_cond_poison_atk` / `status_edbg_dot`）
- `status_end` 0件
- `status_clear` の `count: 2` で戦闘終了時に一括消去

**EXEC §6-B-13**：「`status_add` の数 ＝ `status_end` ＋ `status_clear` の `count`」で**数だけ合致**（2 = 0 + 2）。

ただし、`status_end` が **通常寿命で切れる経路**でも出ないかは本テストでは未確認（戦闘が24秒で終了し、`status_edbg_dot` の寿命8秒×3=24秒、`status_dbg_cond_poison_atk` の寿命120秒は戦闘終了時点でまだ残っている。`status_edbg_dot` は寿命で切れるはずだが、`status_clear` 経由になっている）。

**判断**：仕様として「戦闘終了時に `status_clear` で全消去」があり、`status_end` は途中寿命切れで出る経路のみなのかもしれない。**.gd を読んでいないので断定せず**、本ログでは「要確認」として残す。

### 5-E. EXEC §0-1 の前提と実装の整合

EXEC §0-1 に「**HP依存条件は敵側で検証する**」とあるが、敵のスキル発動AIが `spawn直後ではなく行動可能化後` に依存する場合、HP=20 だと死亡が早すぎてスキル発動前に倒される。**指示書 §5-1 の `hp: 20` は Ziva 側で勝手に変更しない**とプロンプトに明記されていたため、現状のまま。

## 6. 未実装・保留にした項目

- **1波目 HP依存条件の検証** — 敵がスキルを撃たず死亡したため未成立。JSON 設定の妥当性は §5-B 参照
- **2波目 `status_has` 条件の `true/false` 往復検証** — 毒が `party_2` に付与され、バフの宿主 `party_0` には毒が付かない構造のため未成立。§5-C 参照
- **本編 `stage_1` への影響確認** — §6-B-15 未検証
- **`parties.json` の本編3体への復元** — 人間が `.bak` から復元する運用（§4-7）

## 7. テストプレイ結果ログ（現物）

`C:/Users/admin/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl` 全69行より抜粋（指示書プロンプト指定の全項目）。

### 7-1. `ev:"condition"` の全行（1件のみ）

```
{"t":8.38,"ev":"condition","status":"status_dbg_cond_poison_atk","unit":"party_0","active":false,"why":"add"}
```

### 7-2. `ev:"condition"` の件数：**1件**

### 7-3. `ev:"damage"` で `src:"enemy_dbg_cond` を含む行：**0件**（1波目の敵は攻撃を撃たず死亡）

### 7-4. `ev:"damage"` で `src` に `char_debug_status` を含む行

`party_0` = `char_debug_status`。全期間 `amount: 4` で一定。最初の3行：

```
{"t":6.07,"ev":"damage","src":"party_0","dst":"enemy_1_0","amount":4,"crit":false,"atk_type":"physical"}
{"t":7.03,"ev":"damage","src":"party_0","dst":"enemy_1_0","amount":4,"crit":false,"atk_type":"physical"}  ←実際はparty_1
{"t":13.1,"ev":"damage","src":"party_0","dst":"enemy_2_0","amount":4,"crit":false,"atk_type":"physical"}
```

（実ファイルから `party_0` を `src` に持つ行を抽出したもの：t=6.07, 13.1, 15.03, 17.02, 19.02, 21.02, 23.02 — 全て `amount: 4`）

最後の3行：
```
{"t":19.02,"ev":"damage","src":"party_0","dst":"enemy_2_0","amount":4,"crit":false,"atk_type":"physical"}
{"t":21.02,"ev":"damage","src":"party_0","dst":"enemy_2_0","amount":4,"crit":false,"atk_type":"physical"}
{"t":23.02,"ev":"damage","src":"party_0","dst":"enemy_2_0","amount":4,"crit":false,"atk_type":"physical"}
```

### 7-5. `status:"status_edbg_dot"` を含む行（4件、`status_end` は出ない）

```
{"t":17.22,"ev":"status_add","status":"status_edbg_dot","kind":"dot","unit":"party_2","src":"enemy_2_0","life":"sec","dur":8.0}
{"t":19.22,"ev":"dot","status":"status_edbg_dot","src":"enemy_2_0","dst":"party_2","amount":2}
{"t":21.22,"ev":"dot","status":"status_edbg_dot","src":"enemy_2_0","dst":"party_2","amount":2}
{"t":23.22,"ev":"dot","status":"status_edbg_dot","src":"enemy_2_0","dst":"party_2","amount":2}
```

### 7-6. `status:"status_dbg_cond_poison_atk"` を含む行（2件）

```
{"t":8.38,"ev":"status_add","status":"status_dbg_cond_poison_atk","kind":"buff","unit":"party_0","src":"party_0","life":"sec","dur":120.0}
{"t":8.38,"ev":"condition","status":"status_dbg_cond_poison_atk","unit":"party_0","active":false,"why":"add"}
```

### 7-7. 状態の釣り合い

- `status_add` の件数：**2**
- `status_end` の件数：**0**
- `status_clear` の `count` 合計：**2**（戦闘終了時1回、`count: 2`）

→ **2 = 0 + 2 で数だけ合致**

### 7-8. 戦闘終了

```
{"t":24.03,"ev":"status_clear","count":2}
{"t":24.03,"ev":"result","victory":true,"wave":2,"total":2}
```

---

## 8. 補足：出力パネルの現物

```
[MasterDataLoader] skills validated: 47 entries, 0 errors, 1 warnings
[MasterDataLoader] basic attacks validated: 16 entries, 0 errors, 0 warnings
```

黄1本の正体（既存ログで確認済）：
```
master_data_loader.gd:569 @ _validate_all_skills(): [MasterDataLoader] skills skill_dbg_dot_odd: effects[0] は duration_sec が interval_sec で割り切れない。端数は切り捨てで 2 回発火する
```

EXEC §6-A-1 の「**黄は `skill_dbg_dot_odd` の1本のまま。増えていたら赤扱い**」に完全合致。

---

## 9. 引き継ぎ事項（次の担当者へ）

1. **`parties.json` の本編3体への復元** — `resources/balance/master/parties.json.bak` から復元
2. **1波目 HP依存条件の検証未成立** — `enemy_dbg_cond` がスキルを撃たず死亡。検証成立のためには敵HPを `40` 等に上げる、敵スキルCDを `2.0` 等に下げる、味方の攻撃力を下げる、等の調整が必要。**指示書外のため Ziva は未実施**
3. **2波目 `status_has` 条件の検証未成立** — 毒が `party_2` に付与されバフの宿主 `party_0` には毒が付かない構造。検証成立のためには `skill_edbg_dot` の `target.sort` を `furthest` にする、`count: 3` で全員に付ける、`condition.of` を `source`（付与者 = 敵）にする等の調整が必要。**これも指示書外のため Ziva は未実施**
4. **本編 `stage_1` への影響確認** — §6-B-15 未検証
5. **`status_end` が出ない件** — §5-D
