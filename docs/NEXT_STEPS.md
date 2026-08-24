# 次にやること：**③の残り — 本番キャラのパッシブ**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **仕様は `GAME_DESIGN.md` 5-4（パッシブ）。⚠ 人間の決定はまだ無い。⚠ §1-2 の3件を先に聞くこと。**

---

## 0. 前のタスクは終わっている（**2026-08-24・段階8 ルーン ＋ 段階9 機能の段階解放**）

**指示書は `docs/02_exec/EXEC_RUNES.md` と `EXEC_SCREEN_UNLOCK.md`。** ⚠ **どちらもログ・ファイル・画面の全項目が通っている**（⚠ **画面は人間が実機で操作済み**）。

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **プリセット** | ⚠ **2階層・参照方式**（`character_presets` ＋ `party_presets`）／ ⚠ **専用画面 `scenes/adventure/party_preset_screen`** |
| **ルーン** | ⚠ **`runes.json` を新設**（⚠ **マスター7本目・25件**）／ ⚠ **`items.json` が 64 → 89件** ／ ⚠ **ルーンはスキルの直前に `SkillRuntime.cast()` を通る** ／ ⚠ **`E123` `E124`** |
| **機能の段階解放** | ⚠ **画面IDが8つ増えた**（`equipment` / `training` / `warehouse` / `research` / `shop` / `workshop` ＋ 機能IDの `decoration` / `rune`）／ ⚠ **引き金は `stages.json` の `unlocks`** ／ ⚠ **`E125`** ／ ⚠ **「セーブを消しても消えない」を直した**（`reset_to_new_game()`） |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **作業場は「廃止だけ」で通した。⚠ 画面とコードは残す**（2026-08-23）
4. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
5. ⚠ **「焼く」と「適用」は向きが逆。⚠ 1つのボタンにまとめない**
6. ⚠ **ルーンの中身は `runes.json`（マスター7本目）に置く**（2026-08-24）
7. ⚠ **移動系ルーンは瞬間移動＋「秒でロック」**（2026-08-24。⚠ **`rune_move_lock_sec` = 1.2**）
8. ⚠ **移動量は装備画面のルーン枠の行で選ぶ**（2026-08-24。⚠ **保存先は `character_growth.<id>.rune_move`**）
9. ⚠ **ルーンのかけらは作らない。⚠ 入手は `F4` だけ**（2026-08-24）
10. ⚠ **解放の単位は画面IDを増やす ／ 閉じている機能は「出さない」 ／ 引き金はステージのクリア**（2026-08-24）
11. ⚠ **装備と育成と倉庫は `stage_1` で同時に開く**（2026-08-24。⚠ **9-5 は「装備 → 育成」だが導線が逆＝ズレ29**）
12. ⚠ **装飾（`stage_2`）とルーン（`stage_3`）は装備画面の「行」を出し分ける**（2026-08-24）

---

## 1. ⚠ このタスク：**本番キャラのパッシブ**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階3の残り。⚠ 仕様の正は `GAME_DESIGN.md` 5-4。⚠ 規模は「大」。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **段階12（バランス実測）より先に入れる。** ⚠ **あとで入れると戦闘の数値が全部ずれて、⚠ 実測をやり直すことになる**（人間の決定・2026-08-24）
- ⚠ **枠も画面もデータの置き場も全部揃っている。⚠ 中身が0件なだけ**（下の §1-1）
- ⚠ **残りは 段階10（研究の作り替え）／ 段階11の後半（作業場）／ 段階12（バランス実測）**

### 1-1. ⚠ いまの実装（**器は全部ある。本番の中身が0件**）

| | 事実 |
|---|---|
| ⚠ **本番3キャラに `passives` の欄が無い** | ⚠ **`characters.json` の `char_swordsman` / `char_archer` / `char_priest` に欄そのものが無い。⚠ 無いのは正常系で警告も出ない**（`get_all_skill_candidates()`） |
| ⚠ **検証用は2件ある** | ⚠ **`char_debug_status` の `passive_dbg_atk` / `passive_dbg_cond_alive`**（⚠ **`characters/char_debug_status/skills.json` の中**） |
| ⚠ **置き場はキャラのフォルダの `skills.json`** | ⚠ **`activation: "passive"` のエントリとして置く。⚠ `passives.json` という別ファイルは作られていない**（⚠ **`master_data_loader.gd` のコメントは「パッシブを実装する回にここへ置く」と書いているが、⚠ 実際は `skills.json` に同居している＝ズレの候補。§1-3**） |
| ⚠ **枠は1つ** | ⚠ **`PASSIVE_SLOT_COUNT = 1`**（`game_manager.gd:3009`） |
| ⚠ **選ぶ画面はある** | ⚠ **`skill_select_screen.gd:89` が `SLOT_KIND_PASSIVE` の行を作っている。⚠ 入口は育成 → キャラ → 「スキル」** |
| ⚠ **空の枠は埋めない** | ⚠ **`get_battle_passives()` は候補の先頭で埋めない**（⚠ **スキルと違う唯一の点。⚠ 埋めると「外したつもりのパッシブが勝手に付く」**） |
| ⚠ **戦闘での掛け直しは実装済み** | ⚠ **`battle_controller._step_passives()` が「宿主に付いているか」で撃ち直す**（⚠ **他人に付く形にすると無限に付け直す＝`E74` が `target.team` を `self` に限定している**） |
| ⚠ **`ja.csv` は4行だけ** | ⚠ **`ui_battle_passive_*`。⚠ 全部検証用** |
| ⚠ **解放順に入っていない** | ⚠ **`GAME_DESIGN` 9-5 の10段にパッシブは無い。⚠ 育成が開けば選べる**（段階9で `training` は `stage_1`） |

### 1-2. ⚠ 先に聞くこと（**着手前・3件**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **1キャラに候補を何件作るか**（⚠ **枠は1つなので、⚠ 候補が2件以上ないと「選ぶ」意味が無い**） | ⚠ **3件 × 3キャラ ＝ 9件**（⚠ **`unlock_level` で刻める。⚠ スキルが1キャラ6件なので釣り合う**） |
| **2** | ⚠ **中身は常時バフだけにするか、⚠ 条件付き（`condition`）や購読（`react`）も使うか** | ⚠ **常時バフ ＋ 条件付きを使う。⚠ 購読は使わない**（⚠ **`react` は本番スキルに0件で、⚠ パッシブで初めて入れると「動かないのがバグか仕様か」を切り分けられない。⚠ §1-3**） |
| **3** | ⚠ **`passives.json` を新設するか、⚠ `skills.json` に同居させるか** | ⚠ **同居させる**（⚠ **検証用2件が既にそうなっている。⚠ ファイルを増やすと `master_data_loader` の読み込みが1本増える。⚠ ただし `master_data_loader.gd` のコメントは新設する前提で書かれている＝ズレ**） |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`E74`：パッシブの `target.team` は `self` だけ。** ⚠ **他人に付ける形は書けない**（⚠ **`_step_passives()` が相手の死亡ごとに撃ち直して無限に付け直す**）
- ⚠ **`E73` / `E92`：パッシブに `cooldown_sec` / `charge` / `recast` / `phases` は書けない**（⚠ **撃つものではない**）
- ⚠ **`duration_sec` は長い値を入れる**（⚠ **検証用は `99999.0`。⚠ `until` を使う形は本番で前例が無い**）
- ⚠ **`stat` に `hp` は書けない**（`status_registry.gd`。⚠ **`max_hp` を再計算しないため**）
- ⚠ **`status_id` ごとに `ui_status_ch_<status_id>` が要る**（⚠ **無いと黄が出て、⚠ 戦闘のマスに「？」が出る**）
- ⚠ **`characters.json` に `passives` の欄を足すと `get_all_skill_candidates()` が拾い始める**（⚠ **欄を足すのと `skills.json` にエントリを置くのはセット。⚠ 片方だけだと候補に出るのに定義が無い＝落ちる**）
- ⚠ **`_slot_spec()` に手を入れない**（⚠ **枠の仕組みは1本。⚠ `PASSIVE_SLOT_COUNT` を増やすなら数値だけ**）
- ⚠ **戦闘の数値が動く。** ⚠ **`debug_boot` の既存シナリオの damage が変わりうる**（⚠ **本番キャラを使うシナリオが在るか先に確認する**）
- ⚠ **`scenario=layout` を回す**（⚠ **候補が増えると `skill_select_screen` の行が伸びる**）

---
## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが28回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 0件。⚠ 次に見つけたものは 29 番。**
⚠ **ルーンの回では1件も見つからなかった**（⚠ **`NEXT_STEPS` §1-1 と §3 が実コードと全部一致していた**）。

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-22・装飾の回）：⚠ `PART_SLOT_GRADES = [5, 10]` を「変えないもの」に書いて保護したが、⚠ `GAME_DESIGN` 6-4 が置き換えろと言っていた。⚠ 人間が画面で見つけるまで気づかなかった。**

### 2-3. ⚠ `@export` を改名すると `.tres` の値が黙って消える

⚠ **`.tres` は `@export` の変数名をそのままキーにして保存している。⚠ 改名すると旧キーは孤児になり、⚠ 赤も黄も出ない。**
⚠ **実例：`ChestScheduleEntry.chest_type`**（⚠ **`protection_*.tres` の7件が黙って空になる**）。

### 2-4. ⚠ 大きな範囲の文字列置換をしない

⚠ **2026-08-23に `game_manager.gd` で715行を丸ごと消した。**
→ ⚠ **`Edit` で1箇所ずつ当てる。⚠ 範囲置換をするなら、⚠ 置換前後の行数を必ず比べる。**

### 2-5. ⚠ 「同じ形の判定」が散っていたら1本に寄せる

今ある1本ものは：
- ⚠ **`BattleSession.find_unit()`** ／ **`battle_controller._all_units()`** ／ **`StatusRegistry.entries_for()`**
- ⚠ **`GameManager.get_forge_material_tier()`** ／ **`add_to_inventory()`**（装備の個体を作る唯一の口）
- ⚠ **`GameManager.get_part_reject_reason()`**（⚠ **刺せるかの判定。⚠ ルーンもここを通る**）
- ⚠ **`GameManager.get_equip_reject_reason()`** ／ **`grant_chest()`** ／ **`_roll_chest_draw()`**
- ⚠ **`GameManager.set_party_member()`** ／ **`get_party_candidates()`**
- ⚠ **`GameManager._plan_build()` / `_write_build()`** ／ **`format_apply_report()`**
- ⚠ **`GameManager.get_battle_skills()` / `get_battle_passives()` / `get_battle_runes()`**（⚠ **戦闘に渡す確定版。⚠ 同じ形**）
- ⚠ **`GameManager.get_rune_merge_reject_reason()`** ／ **`_valid_rune_move()`**（⚠ **正規化と適用の両方が通る**）
- ⚠ **`MasterDataLoader.rune_skill_data()`**（⚠ **ルーンの辞書を組み立てる唯一の口。⚠ 検証も撃つときも通る**）

### 2-6. ⚠ E / W の次番号

⚠ **`E125` まで使用済み → `E126` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-24確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | `.../pomodoro-heroes/logs/battle_last.jsonl`（⚠ **戦闘のたびに上書き**）／ `.../logs/godot.log`（⚠ **保持5本。⚠ 読む前に自分でヘッドレスを走らせない**） |
| ロード時の正常な出力 | ⚠ **`skills validated: 79 entries, 0 errors, 1 warnings`**（黄1本は `skill_dbg_dot_odd`＝**出るのが正解**）／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ ⚠ **`items validated: 89 entries, 0 errors`** ／ ⚠ **`runes validated: 25 entries, 0 errors`** ／ ⚠ **`balance item refs validated: 0 errors`** ／ ⚠ **`_sync_recipes_from_master() -> 0 recipes`** ／ ⚠ **`_normalize_presets_from_save() -> 10 fixed`**（新規開始。2回目は 0 fixed） |
| ⚠ **マスターは7本** | ⚠ **`items` / `stages` / `shop` / `research` / `recipes` / `chests` / `runes`**（⚠ **`characters` `enemies` は配下にフォルダを持つ**） |
| ⚠ **素材** | ⚠ **16件**。`construction_` / `training_` / `forging_` / `decor_` × `_1..4` |
| ⚠ **装備の等級** | ⚠ **1〜10**。⚠ コストは `forge_cost_by_grade`（9個）。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]` |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`**。⚠ **等級3/4＝宝石 ／ 5＝特別枠（武器＝ルーン／防具＝ワイルド／アクセ＝ルーン×2）／ 6/7＝護符 ／ 8/9＝紋章**。⚠ **刺さる種類は部位ではなく枠で決まる** |
| ⚠ **装飾** | ⚠ **61件**（⚠ **宝石12・護符8・紋章16 ＝ 段階1〜4 ／ ⚠ ルーン25 ＝ 5種 × 段階1〜5**） |
| ⚠ **ルーン** | ⚠ **バフ／デバフ／移動／回復／シールド × 5段階**。⚠ **ステータスを1つも足さない**（`part_stat` が空）。⚠ **挙動は `runes.json`。⚠ 撃つのは `SkillRuntime.cast()`＝スキルとまったく同じ経路**。⚠ **CDは `BattleUnit.skill_cooldowns` にルーンの `item_id` をキーで入る** |
| ⚠ **ルーンの紐付け** | ⚠ **武器のルーン枠 → スキル枠1 ／ アクセのルーン枠2つ → スキル枠2**（`get_battle_runes()`）。⚠ **通常攻撃では発動しない** |
| ⚠ **ルーンの段階上げ** | ⚠ **`merge_runes()`＝同じものを `rune_merge_count`（2）個で1つ上。⚠ 素材を払わない**。⚠ **`upgrade_part()`（分解方式）はルーンで必ず `false`**。⚠ **段階5では `ui_part_reject_rune_max`**（⚠ **かけらが無い**） |
| ⚠ **移動量** | ⚠ **`character_growth.<id>.rune_move` ＝ `{ルーンのitem_id: 符号つきの距離}`**。⚠ **キャラプリセットの5つ目のキー**。⚠ **正が前進・負が後退**。⚠ **移動後は `PartConfig.rune_move_lock_sec`（1.2秒）だけ自動移動が止まる** |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない** |
| ⚠ **入手経路** | ⚠ **装備＝ステージの抽選ドロップ ＋ `F4`**／⚠ **装飾＝ステージ報酬・ショップ・`F4`**／⚠ **ルーン＝`F4` だけ**（⚠ **`GAME_DESIGN` 7-7 の「ポモドーロのレア枠」は未実装**） |
| ⚠ **プリセット** | ⚠ **2階層。⚠ `character_presets` ＝ `{character_id: [{saved, nodes, skills, passives, equipment, rune_move} × 3]}` ／ `party_presets` ＝ `[{saved, slots: [{character_id, preset_index} × 3]} × 10]`** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **書く口は `set_party_member()` の1本** |
| ⚠ **研究** | ⚠ **5ノード・縦1列**（⚠ **`category` は無い。⚠ 作り替えは段階10**） |
| ⚠ 座標の定数 | **`GROUND_Y = 240` ／ 味方 `PARTY_BASE_X=200` `STEP=100` ／ 敵 `ENEMY_BASE_X=900` `STEP=100`** ／ ⚠ **移動系ルーンの端 `RUNE_MOVE_MIN_X=40` `MAX_X=1240`** |
| ⚠ **射程の段** | ⚠ **`60`（前衛）／ `180`（中衛）／ `300`（後衛）／ `420`（最後衛）** |
| ⚠ スキル枠 | **`SKILL_SLOT_COUNT` は 2**。⚠ **パッシブ枠は 1。⚠ 本番キャラのパッシブは0件** |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「素材を全種類」「装飾を全種類」（⚠ **ルーンもここで配られる**）「装備を全種類 1個ずつ」「研究を全部解放」「セーブする」** |
| 行数 | `game_manager` **約5000** ／ `battle_controller` **約1800** ／ `debug_boot` **約2000** ／ `master_data_loader` **約1180** |

```
battle_controller  … 入力と表示。ノードを触る唯一の層。⚠ ルーンの発火もここ（_fire_runes）
	  ↓ cast()
SkillRuntime       … 待ち行列。trigger・購読の配布と発火・中断
	  ↓ 効果1件ずつ
SkillResolver      … 1つの効果を確定した対象に当てる。時間も段も知らない
	  ↓ host が none 以外
StatusRegistry     … 状態。寿命はスキルより長い

BattleLog          … 静的クラス。どの層からも呼べる（Autoload ではない）
```

### 3-1. ⚠ 検証の道具（**人間に頼る前にこれを回す**）

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path d:\pomodoro-heroes res://tests/debug_boot.tscn -- scenario=area
```

- ⚠ **`Start-Process` ＋ `-RedirectStandardOutput` / `-RedirectStandardError` で実行する**（直接叩くと1行も返らない）
- ⚠ **読むのは `[System.IO.File]::ReadAllLines(path, UTF8)`**（`Get-Content` は化ける）
- ⚠ **警告とエラーは `-RedirectStandardError` のほう**（`push_warning` / `push_error` は stdout に出ない）
- ⚠ **赤黄を数えるときは行頭で絞る**（`^(ERROR|WARNING)`）
- ⚠ **今あるシナリオ（27本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / `runes` / ⚠ **`unlock`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝26本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`runes` は戦闘を回す**（⚠ **ルーンは挙動を変えるので `report` では足りない**）
- ⚠ **`layout` は「横にはみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **`add_child()` を `call_deferred` にすること**
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**（⚠ **どちらも意図的に壊している**）
- ⚠ **赤の平常値は 0本。⚠ ただし `unlock` は 1本出るのが正解**（⚠ **`E125` を意図的に出している。⚠ 2本以上出たら本物**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` / `unlock` は戦闘を回さない**（`kind: "report"`）
- ⚠ **1本あたり10〜20秒。⚠ 26本で8分ほど。⚠ 13本ずつ2回に分けて回すこと**（⚠ **1回で回すとツールの2分の上限に当たる。⚠ 背景で走らせる**）
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
- ⚠ **足した検証が本当に赤を出すか、2箇所で壊して確かめる。⚠ 壊すのはメモリ上の状態にすること**（⚠ **`presets` と `parts` がその形。⚠ `git diff` が最初から空のまま**）
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **`Identifier not found` は Autoload 未読み込みで構文エラーではない**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 全シナリオを回している最中にコードを触らない

⚠ **2026-08-23に `game_manager.gd` を編集し、赤560本の偽陽性を出した。**
→ ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない。⚠ `.md` はよい。**

### ⚠ 検証で在庫を「減らすために操作を繰り返す」書き方をしない

⚠ **2026-08-24に踏んだ**：⚠ **`while count > 1: merge_runes()` と書いたら、⚠ 前の章が300個配っていたので150回回り、⚠ 出力が数万行になった。**
→ ⚠ **在庫を整えるときは `_remove_from_inventory()` で一度に減らす。**

### ⚠ 検証は「既定値と違う値」で試す

⚠ **2026-08-24に踏んだ**：⚠ **`set_rune_move()` に `choices` の先頭と同じ値を渡してしまい、⚠ 「効いた」のか「もともとその値だった」のか読めなかった。**

### ⚠ 範囲の効果は、実際に届く距離で試す

⚠ **2026-08-24に踏んだ**：⚠ **デバフのルーンを `radius: 150` で作ったが、⚠ 検証の立ち位置では敵まで 180 あって1体も入らなかった。⚠ 空振りは正常系なので赤も黄も出ない。**

### ⚠ Bash ツールに PowerShell の書き方を渡さない

⚠ **ヒアストリング（`@'...'@`）を渡してコミットメッセージの先頭に `@` が入った。⚠ Bash では heredoc（`<< 'EOF'`）。**

### ⚠ `.tscn` を触らずコードでノードを足すときは、隣の兄弟の `size_flags` を見る

⚠ **5個前提の並びに6個目を足して、拠点の下段が丸ごと左右にはみ出した。**

### ⚠ 新しい `class_name` は、エディタを1回通すまで認識されない

⚠ **参照する側を、⚠ 人間がエディタを通すまで書かない。⚠ 実装を前半・後半に割る。**
⚠ **確かめ方**：`grep -c "<クラス名>" .godot/global_script_class_cache.cfg`
⚠ **ルーンの回は `class_name` を作らなかったので割らずに済んだ**（⚠ **`PartConfig` に `@export` を足しただけ**）。

### ⚠ 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。**（⚠ **`tests/` は例外。あちらは `print` が出口**）

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ トップレベルだけ半角スペース2つのファイルが在る＝`stages.json` / `chests.json` / `runes.json`）。`ja.csv`はUTF-8（BOMなし・LF）。

---

## 5. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここは判断待ちと大きい穴だけ。

### ⚠ 人間の判断待ち

1. ⚠ **マスターファイルが7本目になった**（`runes.json`。⚠ **6本目＝`chests.json` の判断が未了のまま増えた**）
2. ⚠ **射程の段のルールが `EXEC_BATTLE_LINEUP.md` にしか書いていない**
3. ⚠ **`W16`（知らない欄）を赤に上げるか**
4. ⚠ **godot MCP の設定を消すか** ／ **`tests/` の既存9件の棚卸し** ／ **Ziva の `.bak` が7件残っている**
5. ⚠ **`ja.ja.translation` が縮んだ理由が不明**（⚠ **キーの欠落は無いことを実測で確認済み**）
6. ⚠ **作業場をいつ復活させるか** ／ ⚠ **素材の変換経路が消えたまま**

### ⚠ 器の穴（**大きいものだけ**）

0. ⚠ **どのステージで何が開くかが「勘」**（⚠ **段階9。⚠ 本番ステージが3本しか無く、⚠ 9-5 の10段を4段に畳んである。⚠ 実機で詰まらなかったので、⚠ ステージが増えるまで触らなくてよい**）／ ⚠ **9-5 の「拠点」（#8）の置き場が無い** ／ ⚠ **作業場が2箇所で閉じている**（⚠ **`.tscn` の `visible = false` と `unlocks` に書かないこと**）

7. ⚠ **ルーンのかけらが無い**（⚠ **段階5で重ねられない**）／ ⚠ **ルーンの本番入手経路が無い**（⚠ **`F4` だけ**）
8. ⚠ **本番キャラのパッシブが0件**（⚠ **このタスク**）
9. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない**（上書きだけ）
10. ⚠ **`party_changed` シグナルが無い**
11. ⚠ **等級10の「部位固有のパッシブ」が未実装**
12. ⚠ **護符が宝石と仕組み上同じ**（⚠ **軸で割って見分けている暫定**）
13. ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない**
14. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
15. ⚠ **`stack` の5部品のうち上限だけ入れた**
16. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
17. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
18. ⚠ **オーラの範囲が画面に描かれない**
19. ⚠ **状態の色が3つしかない**（デバフが青）／ ⚠ **状態の残り時間がマスに出ない**
20. ⚠ **本番スキルに `react` と `host: point` が0件**
21. ⚠ **`W18` が実測できた**（2026-08-24。⚠ **`parts` シナリオで意図的に壊して黄を確認済み**）

### ⚠ 数値が全部「勘」

22. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**
23. ⚠ **装飾の `part_base` / `part_roll_max` 72個 ＋ `part_config.tres` の7個**
24. ⚠ **ルーンの CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ ロック秒 ／ 重ねる個数**
25. ⚠ **宝箱の中身と `weight`** ／ ⚠ **段階④の入口がショップだけ**

### ⚠ 表示の穴

26. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
27. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**
28. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
29. ⚠ **`weapon_steel_sword` がどこからも出ない**
30. ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**
31. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（意図的）

### 片付け

32. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` の45行 ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
33. ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**（⚠ **1日に2回動いた欄。⚠ 落ち着いたら消してよい**）
34. ⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用のまま残っている** ／ ⚠ **`ja.csv` の `ui_guild_workshop*` 12行も残してある**
35. ⚠ **共有部品 `BuildPresetRow` を作れていない**（⚠ **育成と装備に同じ行が2本ある。⚠ `class_name` の制約で見送った**）

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **残っているのは 段階10（研究の作り替え）・段階11の後半（作業場）・段階12（バランス実測）。**
⚠ **段階12 は依存が全部揃っている。⚠ このタスク（パッシブ）が入ると、⚠ 戦闘の中身が出揃う。**
