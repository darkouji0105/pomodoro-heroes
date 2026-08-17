# 実装ログ：**戦闘ログ（`BattleLog`）**

- 対応するEXECファイル：`docs/02_exec/EXEC_BATTLE_LOG.md`
- 実装日時：2026-08-17
- 実装者：Claude（設計役が直接実装。Ziva に渡した部分は無い＝JSON も `ja.csv` も触らないタスクだったため）

---

## 1. 実装したファイル一覧

| パス | 内容 |
|---|---|
| `res://scripts/systems/battle_log.gd` | **新規・約240行。** 静的クラス（`class_name BattleLog extends RefCounted`）。Autoload は増やしていない |
| `res://scripts/systems/skill_runtime.gd` | 3箇所に差し込み。`_notify()` の `print` を**削除**してファイル側へ移した |
| `res://scripts/systems/status_registry.gd` | 5箇所に差し込み（当初4＋実測後に `clear_all()` を追加） |
| `res://scenes/adventure/battle_controller.gd` | 7箇所（開始・リトライ・時計・ウェーブ・交代flush・結果・`_exit_tree`） |
| `res://scenes/adventure/battle_debug_panel.gd` | `O` キーと説明行 |
| `res://docs/02_exec/EXEC_BATTLE_LOG.md` | 新規。実測で判明した2点を本文に反映済み |

⚠ `.json` / `ja.csv` / `.tres` は**1行も触っていない。**

---

## 2. 関数の実装状況

| 関数 | 指示書通りか | 変更・逸脱があれば理由 |
|---|---|---|
| `BattleLog.is_on()` / `begin_battle()` / `advance()` / `flush()` / `write()` | 通り | - |
| `BattleLog.set_runtime_on()` | **戻り値を変更** | EXEC では `-> bool` と書いたが、呼び出し側（F3 パネル）が戻り値を使わないため `-> void` にした |
| `BattleLog.log_status_clear()` | **後から追加** | EXEC に無い。実測で必要と分かった（§4 の12番・§5-3） |
| `SkillRuntime.cast()` / `_fire()` / `_notify()` | 通り | - |
| `StatusRegistry.add()` / `_expire()` / `_drop_dead_hosts()` / `_fire_intervals()` | 通り | - |
| `StatusRegistry.clear_all()` | **追加** | 上記 `log_status_clear()` の呼び出し元 |
| `BattleController._exit_tree()` | **既存関数へ追記** | 新規に `func _exit_tree()` を足して**パースエラー**を出した（§5-2）。既存の `Engine.time_scale = 1.0` と同じ関数に寄せた |

---

## 3. シグナルの発火箇所

**この回では追加も変更もしていない。** `effects_applied` / `projectile_requested` の発火箇所は購読の回のまま。
ログは全て静的関数の直接呼び出しで、シグナルを経由しない（3層がノードツリーを知らない契約を保つため）。

---

## 4. 完了条件チェックリストの検証結果

⚠ **実測に使ったファイル**：`C:/Users/admin/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl`（`stage_3`・5ウェーブ・**917行**・最後は `V` による強制勝利）。

### 6-A. ログ（Godot の出力パネル）

- [x] 1：`[BattleLog] user://logs/battle_last.jsonl -> C:/Users/.../logs/battle_last.jsonl` が `godot.log` の40行目に**1回だけ**出ている
- [x] 2：`[SkillRuntime] react:` が**0件**（`react` は19件ファイル側に出ている）
- [x] 3：人間が実機で確認（`O` で off / on が出た）
- [x] 4：赤なし

### 6-B. ファイル（設計役がファイルを読んで判定）

- [x] 5：`^{"t":.*}$` に**外れる行が0**。917行すべてが1行1JSON
- [x] 6：`t` の**逆行なし**（917行を走査）
- [x] 7：1行目 `battle_start`、2行目 `wave`（`wave:1`）
- [x] **8（この回の本命）**：491〜495行が `damage src=enemy_2_2 dst=party_2` → `react src=enemy_2_2` → `cast status_dbg_react_thorns#react:took_damage` → `damage src=party_2 dst=enemy_2_2`。**反射が殴ってきた相手に返ったことが、並びの推測ではなくIDの一致で確定した。** 同じ形が19回すべてで成立
- [ ] 9：**未検証。** `#react:dealt_damage`（追撃）が0件。`char_debug_status` のスキルを撃っていないため。⚠ **不具合ではない**
- [x] 10：`"targets":[]` の `cast` が21件出ている
- [ ] 11：**未検証。** `dot` が0件。DoT スキルを撃っていないため。⚠ **不具合ではない**
- [x] 12：**ここで欠陥を1件見つけた。** `status_add` 2件に対し `status_end` が**0件**だった。原因はウェーブ交代の `clear_all()` を意図的にログしていなかったこと（付与 t=82.28・寿命15秒に対し、t=84.85 でウェーブ3に入って消えていた）。**ログだけ読むと「付いた状態が永久に残っている」ように見える。** → `status_clear`（件数だけ1行）を追加して対処。**⚠ この修正後の実測はまだ無い**
- [x] 13：`wave:2` が303行目にあり、直前が `t=41.61` → `t=41.65`。**飛んでいない**（交代中は時計が止まる）
- [x] 14：最終行 `{"t":134.94,"ev":"result","victory":true,"wave":5,"total":5}`
- [ ] 15：**未検証。** 今回は正常終了したため。`_exit_tree()` の flush は入れた（§5-2）

### 6-C. 画面（人間が実機で確認）

- [x] 16・17・18：**人間が全項目確認済み**（2026-08-17）

---

## 5. 指示書からの逸脱・迷った判断（最重要）

### 5-1. `JSON.stringify()` の `sort_keys` を切った

初稿は既定のまま呼んでいたため、キーが**アルファベット順に並び替えられ**、`t` と `ev` が行の途中に埋もれた（`{"amount":3,"atk_type":...,"t":4.13}`）。
1行1イベントにする目的は目で追えることなので、`JSON.stringify(row, "", false)` に変更した。**EXEC の見本の並びが正。**

### 5-2. `_exit_tree()` を新規に足してパースエラーを出した

`battle_controller.gd` には既に `_exit_tree()`（`Engine.time_scale` の復帰）があり、2本目を宣言して
`Function "_exit_tree" has the same name as a previously declared function` になった。既存関数に寄せて解決。
**原因は、足す前に `grep func _exit_tree` をしなかったこと**（`CLAUDE.md` の「編集したら grep」は編集**後**の確認だが、この事故は**前**の確認が要る形だった）。

### 5-3. `clear_all()` に「何も出さない」→「件数だけ出す」へ変更

EXEC 初稿は「1件ずつ出すと数十行出て埋もれる」を理由に**何も出さない**としていた。
実測すると `status_add` だけが残って寿命の追跡が切れることが分かったため、**件数1行**という中間に落とした。
⚠ 1件ずつは今も出していない。

### 5-4. `_drop_dead_hosts()` を差し込み先に追加した（合意は8箇所→9箇所）

人間との合意時点の一覧には無かったが、入れないと「宿主が死んで状態が消えた」が無音になる。
`why: "host_dead"` で `_expire()` と区別できる形にした。**実測でも `host_dead` が出ることを確認済み**（前回の89行の測定）。

### 5-5. `react` から生まれた `cast` の `targets` が空配列になる

`log_cast()` は `cast()` の入口（対象が確定する前）で出しているため、購読から生まれた発動は `"targets":[]` になる。
実際に誰に当たったかは直後の `damage` 行の `dst` で分かるので**そのままにした**。
⚠ `targets` を埋めるには `_make_entry()` の後にログを移す必要があり、そうすると効果の数だけ `cast` が出て多段で水増しされる。**「発動1回＝cast 1行」を優先した。**

### 5-6. 時計を `Engine.time_scale` に乗せた

`t` は実時間ではなく戦闘内の経過秒（`_process` の `delta` の累積）。速度8倍にすると `t` も8倍で進む。
**中の時計（クールダウン・DoT の周期・状態の寿命）と同じ尺度に揃える方を選んだ。** 実時間と突き合わせたい用事は今のところ無い。

---

## 6. 未実装・保留にした項目

| | 内容 |
|---|---|
| 1 | **完了条件 9・11・15 が未検証。** 追撃・DoT・落ちた戦闘。⚠ **不具合ではなく、その経路を通す操作をしていないだけ。** 次に検証用キャラのスキルを一通り撃つ回で自然に埋まる |
| 2 | **`status_clear` 追加後の実測が無い。** 次の起動時に `status_add` の数が `status_end` ＋ `status_clear` の `count` と釣り合うかを見る（完了条件12の新しい文言） |
| 3 | ログを読む側の道具（集計スクリプト・テスト）は作っていない（EXEC §7 の通り） |
| 4 | 宿題17（DoT で購読が発火しない）は**直していない。** ログに見えるようにしただけ |
