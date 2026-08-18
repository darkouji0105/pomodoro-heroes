# 次にやること：**段階5 ＝ `phases[]` / `recast`（再発動・構え型）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**、**決定台帳は`docs/01_plan/PLAN_SKILL_TEMPLATE.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **着手前に `PLAN_SKILL_TEMPLATE.md` の 3-2（`phases[]` の形）と 8章（`activation`）を読むこと。** ここに写した以上のことは書いていない。

---

## 0. 前のタスクは終わっている（**全項目確認済み・2026-08-18**）

**前回 ＝ デバッグ起動シーンを1個にまとめる回。** 指示書は `docs/02_exec/EXEC_DEBUG_BOOT.md`。
その前 ＝ 検証の道具を入れ替える回（`docs/02_exec/EXEC_VERIFY_TOOLING.md`）。

### 0-1. ⚠ 検証のやり方が変わった（**ここが一番大きい**）

⚠ **`CLAUDE.md` の「Godotを起動できない。ゲームを動かして確かめられるのは人間だけ」は事実と違う**（直すかは人間の判断・§6）。

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path d:\pomodoro-heroes res://tests/debug_boot.tscn -- scenario=area
```

⚠ **これ1本で、編成・スキル枠・ステージ・撃つ合図まで全部自動で走る**（1回13秒）。⚠ **段階4で溶けた往復6回のうち5回が、これで消えた。**

| | 誰が取るか |
|---|---|
| ロード時の赤・黄（`skills validated:`） | ⚠ **設計役**（ヘッドレスで先に潰してから人間に渡す） |
| 戦闘中の赤 ／ 出力パネル | ⚠ **設計役**（`user://logs/godot.log` を直接読む） |
| `battle_last.jsonl` | ⚠ **設計役** |
| **画面**（表示・色・レイアウト） | ⚠ **人間だけ。絵は取れない** |

⚠ **設計役は `Start-Process` ＋ リダイレクトで実行し、`[System.IO.File]::ReadAllLines(path, UTF8)` で読む**（直接叩くと無音・`Get-Content` は化ける）。詳細は `AGENTS.md`「誰が取るか」。

### 0-2. ⚠ `tests/debug_boot` の使い方（**シーンは1個。増やさない**）

- ⚠ **シナリオを足すのは `SCENARIOS` に1行。** ⚠ **シーンを増やしたくなったら設計が間違っている合図**
- 1行が持つもの：`kind`（`battle` / ⚠ **`screen`＝窓あり専用**）・`stage_id` or `scene`・`party`・⚠ **`skills`**・⚠ **`fire`（撃つ順と下ごしらえ）**
- ⚠ **合図は「生きている敵全員の x が0.5秒動かない」＝全員が射程ぴったりに落ち着いた。** ⚠ **時間で書かない**
- ⚠ **セーブを絶対に書かない**（`set_party_member()` / `select_skill()` は本物の状態を触る）
- ⚠ **シナリオを足したら、人間に渡す前に全シナリオを1回ずつヘッドレスで回す**（前回、`training` を走らせずに渡して赤を踏んだ）

### 0-3. ⚠ 積み残し（**後回し。忘れないこと**）

| 積み残し | なぜ止めたか |
|---|---|
| **コンボ**（購読の `host: battle` 拡張 ＋ `combo_count`） | ⚠ **2026-08-17、人間の判断で後回し。**「見た目が整わないと検証が難しすぎる」 |
| **`point` の条件（オーラ）** | 真偽が「状態 × ユニットの対」ごとになり、今の `active` では足りない |
| ⚠ **範囲攻撃の巻き込みが画面から読めない** | ⚠ **同じ射程のユニットは同じ x に重なって停まるので数字が重なる。** 立ち位置をずらす仕組みが要る |

---

## 1. このタスク：**`phases[]` と `recast`**

### 1-1. ⚠ 台帳が決めていること（**`PLAN_SKILL_TEMPLATE.md` から写した分。これ以上は決まっていない**）

| | 決定 |
|---|---|
| `phases[]` | ⚠ **再発動の「段」。省略＝1段**（8章） |
| ネスト | ⚠ **3階層まで（skill → phase → effect）。単発スキルは2階層で書ける**（3-2） |
| `recast` | ⚠ **`recast: { window_sec }` ＋ `phases[]`**（8章の表） |
| `activation` | ⚠ **`activation` が正。`charge{}` は `activation: charge` のときだけ読む** |
| ⚠ **今の分岐** | ⚠ **`charge` 欄の有無で分岐している**（`battle_controller.gd` 493〜498行）。⚠ **軸（`activation`）を見る形に変える、と台帳が決めている** |
| 構えて再発動 | ⚠ **`recast` ＋ 状態（`host: unit`）＋ ダメージの介入点で書ける。器の追加は要らない**（8章） |

⚠ **`phases[]` の中身は `target` ＋ `effects`**（3-2 の例）。⚠ **`target` は段階1〜4で作ったものがそのまま入る。**

### 1-2. ⚠ 着手前に決めること（**台帳に無い。人間の判断が要る**）

⚠ **設計役が勝手に決めない。EXEC を書く前に聞くこと。**

1. ⚠ **`window_sec` の間に再発動しなかったらどうなるか**（そのまま終わる／最後の段が自動で出る／不発）
2. ⚠ **再発動はどう入力するか**（同じスキルボタンをもう一度／別のボタン）。⚠ **`debug_boot` は `_fire_skill()` を呼ぶだけなので、入力の形が決まらないと検証シナリオが書けない**
3. ⚠ **クールダウンはいつ回り始めるか**（1段目／最終段のあと）
4. ⚠ **段の途中で死んだらどうなるか**
5. ⚠ **`phases[]` と `charge` を同時に書けるか**

### 1-3. ⚠ 検証シナリオ（**`debug_boot` の表に1行足す**）

⚠ **`stage_dbg_area` を使い回すか、`stage_dbg_recast` を足すかは EXEC で決める。**
⚠ **`fire` は「1回撃って、`window_sec` の中でもう1回」を書けるようにする必要がある**（今の `fire` は1スキル1回しか撃たない）。⚠ **ここは `debug_boot` 側の改修になる。**

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ `phases` 省略の既存スキル全件を1ミリも変えない

⚠ **段階1〜4で毎回かけている完了条件。** ⚠ **`phases` が無いスキル（本番の全件）は今までどおり動くこと。**

### 2-2. ⚠ 既定値を作らない

⚠ **`origin` / `stack` / `scale_from` と同じ方針。** ⚠ **書き忘れがどちらに倒れても無音で挙動が変わる欄には既定値を作らず、ロード時に赤にする。**

### 2-3. ⚠ `MasterDataLoader` が返す数値は必ず `float`

⚠ **`window_sec` を `is int` で見ない。** ⚠ **`E69` はこれで9件を誤って赤にしていた**（`CLAUDE.md` 3番）。

### 2-4. ⚠ ドキュメントの「実装済み」を信じない

**ズレが12回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。読んだ結果ドキュメントが違っていたら報告する（勝手に直さない）。**

### 2-5. ⚠ E / W の次番号

⚠ **E80 まで使用済み → E81 から。** W12 まで使用済み。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-18確認）

| | 事実 |
|---|---|
| ⚠ ログの実体 | `C:/Users/admin/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl`。⚠ **戦闘のたびに上書き** |
| ⚠ 出力パネル | `.../logs/godot.log`。⚠ **保持5本。設計役が走らせると人間のログが1本消えるので、読む前に走らせない** |
| ⚠ `cast` の `targets` | `fixed_target_ids` しか入っていない（`skill_runtime.gd:132`）。⚠ **スキルでは常に空。巻き込んだ数は「同じ `t` の `damage`/`heal` の行数」で数える** |
| ロード時の正常な出力 | ⚠ **`skills validated: 59 entries, 0 errors, 1 warnings`**（黄1本は `skill_dbg_dot_odd` の端数＝**出るのが正解**） |
| 出る出来事 | `battle_start` / `wave` / `cast` / `damage` / `heal` / `dot` / `react` / `status_add` / `status_end` / `status_clear` / `condition` / `intervene` / `result` |
| スキルを撃つ | ⚠ **`battle_controller._fire_skill(user, skill_id, power_ratio) -> bool`**（`:879`）。**戻り値は「撃てたか」** |
| 検証用ステージ | `stage_dbg_enemy_skill` ／ `stage_dbg_condition` ／ `stage_dbg_intervene` ／ `stage_dbg_passive` ／ `stage_dbg_area` |
| ⚠ スキル枠 | **`SKILL_SLOT_COUNT` は 2**（`game_manager.gd:1773`） |
| ⚠ 編成 | ⚠ **状態が唯一の正**（`battle_controller.gd:176`）。⚠ **`stages.json` の `party_id` では決まらない**（`battle_session.gd:19`） |
| ⚠ ユニットの停まる位置 | **`距離 <= attack_range` で止まる**（`battle_controller.gd:601-627`）。⚠ **狙う相手は死ぬまで変えない** |
| ⚠ `range` の下限 | **`attack_range` より短く書けない**（`master_data_loader.gd:592`） |
| 行数 | `game_manager.gd` 3048 ／ `battle_controller.gd` 1371 ／ `status_registry.gd` 1121 ／ `skill_schema.gd` 1035 ／ `skill_resolver.gd` 696 ／ `skill_runtime.gd` 536 |

```
battle_controller  … 入力と表示。ノードを触る唯一の層
	  ↓ cast()
SkillRuntime       … 待ち行列。trigger・購読の配布と発火・中断
	  ↓ 効果1件ずつ
SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
	  ↓ host が none 以外
StatusRegistry     … 状態。寿命はスキルより長い

BattleLog          … 静的クラス。どの層からも呼べる（Autoload ではない）
```

---

## 4. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | **段階6：`spawn`** | 召喚・分裂（⚠ **座標の規則が要る**） |
| 2 | **段階3の積み残し**：⚠ **コンボ** ／ **`point` の条件（オーラ）** | ⚠ **見た目が整ってから**（§0-3） |
| 3 | **見た目**（スプライト・エフェクト・⚠ **立ち位置をずらす**） | ⚠ **`assets/images/` は空。キャラは 64×64 の `ColorRect` 1枚** |
| 4 | **ダメージの介入点の利用者**（シールド・軽減・反射・貫通%・確定クリティカル） | ⚠ **4つの介入点のうちここだけ利用者ゼロ** |
| 5 | **バランスの実測** | 構造が出揃ってから |

---

## 5. 罠

### ⚠ 静的な突き合わせは実機の代わりにならない

⚠ **段階4で、ロード時検証を Python で真似て「OK」と言ったが実機では10件の赤が出た。**
→ ⚠ **ヘッドレスが使える今、真似る意味は無い。真似ずに走らせること。**

### 関数を足す前に `grep` する

**足す前に `grep -n "func <名前>"`、足したあとにも `grep` で当たったか確認する。**

### ⚠ Windows の bash で `cat >>` すると追記分が CRLF になる

元が LF の JSON に混ざって壊れる。**JSON に追記したら改行コードを確かめる。**

### ⚠ `_ready()` の中では root に `add_child()` も画面遷移もできない

`Parent node is busy ...` で弾かれる。⚠ **`call_deferred` を使う。** ⚠ **遷移の枝が2つある**（`change_scene` と `change_scene_with_data`）ことを忘れない。

### 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。** コンソールに流さない。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ `stages.json` だけトップレベルが半角スペース2つ）。`ja.csv`はUTF-8（BOMなし）。

---

## 6. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。**

### ⚠ 人間の判断待ち（**前回までに溜まったもの**）

1. ⚠ **`CLAUDE.md` の「Godotを起動できない」を直すか**
2. ⚠ **godot MCP の設定を消すか**（使えていない。設定だけ残っている）
3. ⚠ **`PROJECT_STATUS.md` に「④-a の完了記録『errors 0』は事実と違っていた」を残すか**
4. ⚠ **`tests/` の既存9件の棚卸し**（`my_test` `modal_test` `dummy_scene_a/b` `base_screen_debug` ほか）
5. **Ziva が作った `.bak` が7件残っている**

### ⚠ 道具まわり

6. ⚠ **`godot.log` は保持5本。設計役が走らせると人間のログが1本消える**
7. ⚠ **ロード時に赤が出たときの終了コードが未確認**（次に赤が出た回に見る）
8. ⚠ **`debug_boot` はセーブを読まない**（タイトルを通らないため）。⚠ **セーブ由来の不具合は再現しない**
9. ⚠ **`debug_boot` の `fire` は1スキル1回だけ。** ⚠ **`recast` の検証には改修が要る**（§1-3）

### 器の穴

10. ⚠ **購読は `host: unit` のみ**（コンボ・罠がまだ載らない）
11. ⚠ **`point` の条件（オーラ）は真偽が「状態 × ユニットの対」ごとになる**
12. ⚠ **`scale_from` は「和」しか書けない**
13. ⚠ **DoT の周期ダメージでは購読が発火しない**
14. ⚠ **`stack` の5部品のうち上限だけ入れた**（消え方・再付与・閾値は未実装）
15. ⚠ **効果の中の欄に「知らない欄」の検出が無い**（typo が無音）
16. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない**
17. **死亡中にCDが回る**
18. ⚠ **パッシブは `dispel` で剥がせない**
19. ⚠ **ダメージの介入点だけ利用者ゼロ**（`_step_crit_override` / `_step_reduction` は `pass`）
20. **`_find_unit()` が3ファイルに同じ形で3本ある**
21. ⚠ **`target.range` が未設定** ／ ⚠ **`atk_multiplier` が常に 1.0**
22. ⚠ **多段の2発目に投射物が出ない**

### 段階4で増えたもの

23. ⚠ **`origin`（`user` / `target`）。3つ目を足すときは `ORIGINS_KNOWN` に入れる**
24. ⚠ **`offset`（2次元化・PLAN 16章）はまだ無い**
25. ⚠ **`skill_arrow_rain`（矢の雨）は今も `sort: "all"`**（`area` にするとバランスが変わるので別タスク）
26. ⚠ **「誘導しない投射物」はまだ無い**
27. ⚠ **`area` の距離は1次元**（`absf(x - x)`）
28. ⚠ **範囲攻撃の巻き込みが画面から読めない**（数字が重なる）

### 片付け

29. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ ⚠ **`tests/debug_boot`**）
30. ⚠ **フォルダを増やしたら定数に1行足す**（`CHARACTER_DIRS_REQUIRED` / `ENEMY_DIRS_*`）
31. **状態のUIが無い**（F3 パネルと `P` キーだけ）

---

## 7. 終わったあと

**このファイルを、段階6（`spawn`）の内容に書き換える。**
⚠ **段階5の検証シナリオは `debug_boot` の `SCENARIOS` に残すこと**（消さない。次の段階で使い回す）。
