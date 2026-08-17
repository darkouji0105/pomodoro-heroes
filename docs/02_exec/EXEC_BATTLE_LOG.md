# EXEC — **戦闘ログ（`BattleLog`）**：検証の土台

⚠ **これはスキルのPLANの軸ではない。** 段階3の後半②（＝条件）の**前**に入れる、検証のための回。
**目的は機能追加ではない。**「画面を見ないと分からない」項目を「ファイルを読めば分かる」に移すこと。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **出す出来事** | **7種**（`cast` / `damage` / `heal` / `react` / `status_add` / `status_end` / `wave` / `result` / `dot`）。⚠ `fire`（効果1件ごと）は**出さない**。位置・移動も出さない |
| **⚠ 実装中に1種追加** | `status_clear`（件数だけ）。**実測で必要と分かった**（§6-B 12番の検証結果）。理由は §3-3 |
| **オン/オフ** | **両方**。`BattleLog.ENABLED` の const ＋ F3 パネルのキー（`O`） |
| **書き出し** | **節目 ＋ 上限自動 flush**。ウェーブ交代・戦闘終了・記録オフ操作で flush し、加えて未書き出しが `FLUSH_THRESHOLD`（200件）を超えたら自動 flush |

---

## 1. ⚠ 着手前の報告：NEXT_STEPS の記述を1点訂正（**直していない**）

NEXT_STEPS §3 は DoT のダメージを「`status_registry.gd:372`」と書いているが、
実際に `SkillResolver.resolve()` を呼んでいるのは **`status_registry.gd:413`**（`_fire_intervals()` の中）。
372行目は `_drop_dead_hosts()` の付近。**関数名で特定する分には影響しないが、行番号だけズレている。**

---

## 2. 出すもの

`user://logs/battle_last.jsonl` に **1行1イベント（JSON Lines）**。**戦闘の開始ごとに丸ごと上書きする。**

```
{"t":0.0,"ev":"battle_start","stage":"stage_1","party":"party_debug","waves":3}
{"t":0.0,"ev":"wave","wave":1,"total":3,"enemies":["enemy_1_0","enemy_1_1"]}
{"t":3.5,"ev":"cast","unit":"party_2","skill":"skill_dbg_react_thorns","targets":["party_2"]}
{"t":3.5,"ev":"status_add","status":"status_dbg_react_thorns","kind":"react","unit":"party_2","src":"party_2","life":"sec","dur":20.0}
{"t":5.0,"ev":"damage","src":"enemy_1_0","dst":"party_2","amount":12,"crit":false,"atk_type":"physical"}
{"t":5.0,"ev":"react","status":"status_dbg_react_thorns","event":"took_damage","unit":"party_2","src":"enemy_1_0","effects":1}
{"t":5.0,"ev":"cast","unit":"party_2","skill":"status_dbg_react_thorns#react:took_damage","targets":["enemy_1_0"]}
{"t":5.0,"ev":"damage","src":"party_2","dst":"enemy_1_0","amount":9,"crit":false,"atk_type":"physical"}
{"t":7.0,"ev":"dot","status":"status_dbg_dot_burn","src":"party_1","dst":"enemy_1_0","amount":4}
{"t":20.0,"ev":"status_end","status":"status_dbg_react_thorns","unit":"party_2","why":"expire"}
{"t":24.5,"ev":"result","victory":true,"wave":3,"total":3}
```

### 欄の決まり

- `t` … **戦闘中の経過秒**（`BATTLE_ACTIVE` の間だけ進む）。⚠ 実時間ではない。`Engine.time_scale` を上げると速く進むが、これは**中の時計と一致する側が正しい**
- `src` / `dst` … ユニットID。`amount` は `int`
- ⚠ `heal` には `crit` / `atk_type` を出さない（`results` が持っていない。NEXT_STEPS §3 の「後ろ2つはダメージのときだけ」）
- `why`（`status_end`）… `"expire"`（寿命切れ）／ `"host_dead"`（宿主が死んだ）

---

## 3. 実装（ファイル別）

### 3-1. `scripts/systems/battle_log.gd`（**新規・静的クラス**）

⚠ **Autoload にしない**（`AGENTS.md`：6つ以外は人間の承認が要る）。`MasterDataLoader` と同じ `class_name BattleLog extends RefCounted` の静的クラスにする。
これで `RefCounted` の3層（`SkillRuntime` / `SkillResolver` / `StatusRegistry`）からも、ノードである `battle_controller` からも同じ呼び方で書ける。**契約に触れない。**

```
const ENABLED: bool = true            # ⚠ リリース前に false → ファイルごと削除（宿題16）
const DIR_PATH   := "user://logs/"
const FILE_PATH  := DIR_PATH + "battle_last.jsonl"
const FLUSH_THRESHOLD: int = 200      # 未書き出しがこれを超えたら自動 flush
```

| 関数 | 役割 |
|---|---|
| `is_on()` | `ENABLED and _runtime_on`。**全ての `log_*` の先頭でこれを見る**（呼び出し側でガードを書かせない） |
| `begin_battle(stage_id, party_id, total_waves)` | 時計を0に戻し、**ファイルを空にして** `battle_start` を書く |
| `advance(delta)` | 時計を進める。`battle_controller._process()` の戦闘中だけから呼ぶ |
| `set_runtime_on(on) -> bool` | F3 の `O` キー用。**オフにするとき先に flush する**（途中で終わったファイルを残さない） |
| `flush()` | 溜めた行を追記して配列を空にする |
| `log_cast` / `log_results` / `log_react` / `log_status_add` / `log_status_end` / `log_wave` / `log_result` | 差し込み先が1行で済む形にする |

- `log_results(results, src_fallback, dot_status_id = "")` … `results` を回して `is_heal` で `heal` と `damage` に振り分ける。`dot_status_id` が空でなければ `damage` の代わりに `dot` を出す。⚠ **`results` の形を知る場所をここ1箇所に閉じる**（3箇所に同じループを書かない）
- 書き出しは `DirAccess.make_dir_recursive_absolute()` → 初回は `WRITE`（＝空にする）、以降は `READ_WRITE` + `seek_end`（＝追記）
- ⚠ `tr()` を呼ばない（静的関数から呼べない・`AGENTS.md`）。そもそも画面に出さない

### 3-2. `scripts/systems/skill_runtime.gd`（510行）— **3箇所**

| 場所 | 差すもの |
|---|---|
| `cast()`（`cast_id` を採番した直後） | `BattleLog.log_cast(user.unit_id, skill_id, fixed_target_ids)` |
| `_fire()`（`SkillResolver.resolve()` の直後・`from_reaction` の判定より前） | `BattleLog.log_results(results, user.unit_id)` |
| `_notify()`（**いまの `print` を置き換える**） | `BattleLog.log_react(...)`。⚠ **`print` は消す**（§2-4） |

⚠ `_fire()` に差すのは `results` を受け取ったあと。**`SkillResolver` には一切触らない**（`_apply_damage()` は DoT からも呼ばれる static。ここに差すと観測点と発火点を取り違える）。

### 3-3. `scripts/systems/status_registry.gd`（608行）— **4箇所**

| 場所 | 差すもの |
|---|---|
| `add()`（**`return true` の直前**。⚠ 弾かれた効果を記録しない） | `BattleLog.log_status_add(...)` |
| `_expire()`（捨てると決めた要素ごと） | `BattleLog.log_status_end(..., "expire")` |
| `_drop_dead_hosts()`（捨てると決めた要素ごと） | `BattleLog.log_status_end(..., "host_dead")` |
| `_fire_intervals()`（`SkillResolver.resolve()` の結果を `results` に足す所） | `BattleLog.log_results(res, source_id, status_id)` ＝ **`dot`** |

⚠ **`_drop_dead_hosts()` を入れて9箇所目になった。** 入れないと「宿主が死んで状態が消えた」が無音になり、`status_add` だけが残って寿命の追跡が切れる。`why` で `_expire()` と区別できる。
⚠ **`clear_all()` は「件数だけ」1行出す**（`status_clear`）。当初は「1件ずつ出すと埋もれる」を理由に**何も出さない**としていたが、実測すると `status_add` が2件・`status_end` が0件になった。ウェーブ交代の `clear_all()` で消えたためで、**ログだけ読むと「付いた状態が永久に残っている」ように見える。** ②＝条件で一番困る形なので、件数1行に落とす（1件ずつは出さない）。

### 3-4. `scenes/adventure/battle_controller.gd`（1129行）— **5箇所**

| 場所 | 差すもの |
|---|---|
| `_ready()`（`_enter_wave_intro()` の直前） | `BattleLog.begin_battle(...)` |
| `_init_session()`（リトライ。`_init_party_units()` の直後） | 同上。⚠ **忘れるとリトライ2回目のログが1回目に continue する** |
| `_process()`（状態ガードの内側・クールダウンより前） | `BattleLog.advance(delta)` |
| `_spawn_current_wave_enemies()`（末尾） | `BattleLog.log_wave(...)` |
| `_enter_wave_clear()`（`_status.clear_all()` の直後）／ `_show_result()`（先頭） | `log_result()` ＋ `flush()` |
| `_exit_tree()`（**既存の関数に足す**。`Engine.time_scale = 1.0` と同じ関数） | `flush()`。⚠ 節目だけだと「戻る」・シーン遷移・通常終了で溜めたぶんが丸ごと消える |

⚠ `_show_result()` は勝利と敗北の**両方**が通る唯一の場所。`_enter_victory()` / `_enter_defeat()` の2箇所に書かない。

### 3-5. `scenes/adventure/battle_debug_panel.gd`（380行）— **2箇所**

- `_unhandled_input()` に `KEY_O` を足し、`BattleLog.set_runtime_on(not BattleLog.is_on())` を呼ぶ
- `_help_label` に `"[O] 戦闘ログの記録 On/Off"` を1行足す

⚠ ここの `print`（切り替えた結果の1行）は残す。**押した本人への返事であり、毎フレーム出るものではない**（`_set_time_scale()` と同じ扱い）。§2-4 が禁じているのは正常系で流れ続ける `print`。

---

## 4. ⚠ 事故りやすい箇所

| | 内容 |
|---|---|
| 4-1 | **`SkillResolver` に書かせない。** `results` を受け取る側で書く |
| 4-2 | **毎フレーム `FileAccess` を開かない。** 節目 ＋ 上限自動 flush |
| 4-3 | **正常系に `print` を増やさない。** `_notify()` の `print` は**消してファイルへ移す** |
| 4-4 | **`Autoload` を増やさない。** 静的クラス |
| 4-5 | **時計は `battle_controller` から貰う。** 3層は時間を知らない（契約）。`Time.get_ticks_msec()` を使うと速度8倍のとき中の時計とズレる |
| 4-6 | **リトライで `begin_battle()` を呼び直す。** 呼ばないと前の戦闘の続きに見える |

---

## 5. Ziva に渡せる部分 — **無い**

この回は **JSON も `ja.csv` も1行も触らない。** 新しいスキル・状態・翻訳キーを足さないため。
触るのは `.gd` 5ファイルのみで、うち3ファイルが200行超（`battle_controller` 1129 / `status_registry` 608 / `skill_runtime` 510）。**全て設計役が書く。**

---

## 6. 完了条件

### 6-A. ログ（Godot の出力パネル）

1. 戦闘に入ると `[BattleLog] user://logs/battle_last.jsonl -> <実際のフルパス>` が**1回だけ**出る（このパスを 6-B で開く）
2. 反射・追撃が起きても、コンソールに `[SkillRuntime] react:` が**もう出ない**（ファイル側へ移したため）
3. `O` を押すと `[BattleLog] 記録 off` / もう一度押すと `[BattleLog] 記録 on` が出る
4. 戦闘中に赤（`push_error`）が出ない

### 6-B. ファイル（`battle_last.jsonl` をテキストエディタで開く）

5. **1行1JSON**になっている（配列の `[` `]` が無い・行の途中で改行されていない）
6. `t` が上から下へ**単調増加**している
7. 1行目が `battle_start`、2行目が `wave`（`wave:1`）
8. **反射**：`ev:"damage"` で `dst` が味方の直後に、`ev:"react"` が出て、その `src` が**直前の `damage` の `src` と一致する**。さらにその直後の `ev:"damage"` の `dst` が**同じユニットID**（⚠ これが「殴ってきた相手に返ったか」の確定。購読の回で推測に頼った所）
9. **追撃**：`ev:"cast"` の `skill` に `#react:dealt_damage` を含む行がある
10. **空振り**：対象0体で撃った回でも `ev:"cast"` が出ている
11. **DoT**：`ev:"dot"` が `interval_sec` の間隔で並び、`status` が入っている。⚠ **その直後に `react` が出ていないこと**（＝宿題17「DoT で購読が発火しない」がログ上で確認できる。**これは現状の仕様であり、この回で直さない**）
12. `status_add` の数が、`status_end`（`why` は `expire` か `host_dead`）と `status_clear` の `count` の合計と**釣り合う**。⚠ 「`status_add` と `status_end` が対で並ぶ」ではない。ウェーブ交代で消えたぶんは `status_clear` に入る
13. **ウェーブ交代**：`wave:2` の行があり、その前で `t` が飛んでいない（交代中は時計が止まる＝同じ値が続く）
14. 最終行が `ev:"result"` で `victory` が正しい
15. **落ちた戦闘**：`V`（強制勝利）を押さずにウィンドウを×で閉じても、200件を超えたぶんは書かれている

### 6-C. 画面（実機で操作する）

16. F3 パネルの説明に `[O] 戦闘ログの記録 On/Off` の行が増えている
17. `4`（速度8倍）でウェーブを1本流しても、記録ありで**目に見えて重くならない**
18. 戦闘の見た目（ダメージ数値・投射物・勝敗）が**この回の前と変わらない**

### 6-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- `BattleLog.ENABLED = false` にすると `.jsonl` が1行も増えない
- `user://logs/` が無い状態から起動しても作られる
- `begin_battle()` を呼ばずに `log_*` を呼んでも落ちない

---

## 7. この回でやらないこと

- `fire`（効果1件ごと）・位置・移動の記録
- 宿題17（DoT で購読が発火しない）の修正。**ログに見えるようにするだけ**
- ログを読む側の道具（集計スクリプト・テスト）
- 敵の管理（次のタスク）・②＝条件

---

## 8. 宿題に足すもの（`PROJECT_STATUS.md`）

- 16番（リリース前に消すもの）に **`scripts/systems/battle_log.gd` と各層の `BattleLog.` 呼び出し・F3 の `O` キー**を追記する。⚠ 宿題16には既に「戦闘ログ」の語がある。**二重に書かず、消す対象のファイル名を足す形にする**
