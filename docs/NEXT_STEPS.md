# 次にやること：**⑪ 作業場の復活（段階11の後半）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **仕様は `GAME_DESIGN.md` 9-3（作業場）。⚠ 人間の決定はまだ無い。⚠ §1-2 の3件を先に聞くこと。**

---

## 0. ⚠ 前のタスクは終わっている（**2026-08-25・段階10＝研究ボードの作り替え**）

**指示書は `docs/02_exec/EXEC_GUILD_RESEARCH_V2.md`。**
⚠ **ログの全項目が通っている**（⚠ **28本を1本ずつ回した。⚠ 赤は `unlock` の1本のみ＝平常値**）。
⚠ **画面（§7-3）とセーブ（§7-2）は未確認。⚠ `ja.csv` の再インポートが済むまで `scenario=layout` が赤を3本出す。**

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **機能の段階解放** | ⚠ **画面IDが8つ増えた** ／ ⚠ **引き金は `stages.json` の `unlocks`** ／ ⚠ **`E125`** |
| **パッシブ** | ⚠ **本番3キャラ × 5件＝15件** ／ ⚠ **`characters/<id>/passives.json` を3本新設** ／ ⚠ **レベル上限 30 → 100** ／ ⚠ **`E126`** ／ ⚠ **`react` が本番に2件** |
| **研究** | ⚠ **2ボード18ノード**（⚠ **枝は「戦闘」と「宝箱」**）／ ⚠ **上限は 8件 × +10 ＝ ちょうど 100** ／ ⚠ **`E127` `E128`** ／ ⚠ **`scenario=research`** ／ ⚠ **新しい `effect_type` が1つ（`chest_draw_bonus`）** |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **作業場は「廃止だけ」で通した。⚠ 画面とコードは残す**（2026-08-23。⚠ **このタスクで復活させる**）
4. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
5. ⚠ **ルーンの中身は `runes.json`（マスター7本目）に置く**（2026-08-24）
6. ⚠ **解放の単位は画面IDを増やす ／ 閉じている機能は「出さない」 ／ 引き金はステージのクリア**（2026-08-24）
7. ⚠ **パッシブは選ばない。⚠ 解放されたものが全部効く**（2026-08-25）
8. ⚠ **レベル100まで上げられるようにする**（2026-08-25。⚠ **`base_level_cap` 20 ＋ 研究8件 × 10 ＝ 100**）
9. ⚠ **研究の枝は「戦闘」と「宝箱」の2本。⚠ 作業場枝はこのタスクと同時に足す**（2026-08-25）
10. ⚠ **研究のボードは「1周クリアで次に切り替わる」を入れる**（2026-08-25。⚠ **今は2枚**）

### 0-3. ⚠ 研究で作った器（**このタスクで使う／壊さない**）

| 器 | 中身 |
|---|---|
| ⚠ **`board` / `category` / `milestone`** | ⚠ **`research.json` のノードの欄。⚠ 状態には1つも足していない**（⚠ **「今のボード」は都度計算＝`get_current_research_board()`**） |
| ⚠ **`GameManager.get_research_board_of()` / `is_research_board_open()` / `get_research_board_progress()`** | ⚠ **ボードの判定はこの3本だけ** |
| ⚠ **`get_research_chest_draw_bonus()`** | ⚠ **`_roll_chest_draw()` の `rolls` に乗る1行。⚠ 効果を足すときの前例** |
| ⚠ **`E127`** | ⚠ **`base_level_cap` ＋ 全 `level_cap_unlock` ≠ `max_character_level` で赤 |
| ⚠ **`E128`** | ⚠ **前提が存在しない ／ 前提が後のボードにある ／ `board` が1未満で赤** |
| ⚠ **研究画面のカテゴリ見出し** | ⚠ **画面に `if` を書いていない。⚠ `ja.csv` に `ui_research_category_<category>` を1行足せば見出しが増える** |

### 0-4. ⚠ 人間の既存セーブに起きること（**まだ起きていない**）

⚠ **今のセーブは `res_cap_1..4` を解放済み。⚠ 1件が +20 から +10 になったので、⚠ 実効レベル上限が 100 → 60 に下がる。**
⚠ **解放状態は失われない**（IDを改名していない）。⚠ **`res_cap_5..8` を解放し直せば 100 に戻る。⚠ 既にLv60超のキャラのレベルは下がらない**（⚠ **上限は `level_up_character()` の入口でしか見ない**）。

## 1. ⚠ このタスク：**作業場の復活**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階11の後半。⚠ 仕様の正は `GAME_DESIGN.md` 9-3。⚠ 規模は「中」。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **残りは 段階11の後半（これ）／ 段階12（バランス実測）だけ**
- ⚠ **段階12 を先にやると測り直しになる。⚠ 作業場は素材の出口と入口を両方増やす**（⚠ **研究を段階12より先に決めたのと同じ理由**）
- ⚠ **研究の作業場枝（決定9）も、⚠ 作業場が動いていないと足せない**

### 1-1. ⚠ いまの実装（**2026-08-25に確認**）

| | 事実 |
|---|---|
| ⚠ **レシピは0件** | ⚠ **`recipes.json` は `{"recipes": []}`。⚠ 14件は `EXEC_WORKSHOP_RETIRE.md` で全部消した** |
| ⚠ **画面とコードは残っている** | ⚠ **`scenes/guild/workshop_screen.tscn` / `.gd` は在る。⚠ `guild_screen.gd` の `WORKSHOP_PATH` は未使用のまま残してある** |
| ⚠ **ボタンは隠してある** | ⚠ **`guild_screen.tscn` の `WorkshopButton` が `visible = false`。⚠ `GUILD_SCENES` と `_nav_buttons` からも外してある** |
| ⚠ **画面IDは在るが誰も開かない** | ⚠ **`SCREEN_WORKSHOP` は在るのに、⚠ `stages.json` の `unlocks` に1度も出てこない**（⚠ **`scenario=unlock` がそれを名指しで出す**） |
| ⚠ **キューの器は生きている** | ⚠ **`start_craft()` / `collect_craft()` / `get_crafting_queue()` / `get_max_queue_slots()` / `_sync_recipes_from_master()`。⚠ 消していない** |
| ⚠ **素材の変換と装備の製作は廃止** | ⚠ **`GAME_DESIGN` 9-3。⚠ 復活させない** |

### 1-2. ⚠ 先に聞くこと（**着手前・3件**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **作業場で何を作れるようにするか。⚠ `GAME_DESIGN` 9-3 のデモ範囲は「中間素材の製作」と「装飾のランダム製作」の2つ** | ⚠ **両方。⚠ ただし中間素材を先に通す**（⚠ **既存のキューの器にそのまま乗る。⚠ くじは抽選テーブルが要る＝`chests.json` の `draw` を写せる**） |
| **2** | ⚠ **どのステージのクリアで開くか**（⚠ **`GAME_DESIGN` 9-5 の解放順では9番目＝ほぼ最後**） | ⚠ **`stage_3`。⚠ 本番ステージが3本しか無いので、⚠ ルーン・ショップと同じ段に足す**（⚠ **`stages.json` の `unlocks` に1行**） |
| **3** | ⚠ **研究の作業場枝を今回いっしょに足すか**（決定9） | ⚠ **足す。⚠ 製作時間の短縮とキュー本数の2件だけ**（⚠ **`get_max_queue_slots()` と `start_craft()` の `duration_sec` に乗る＝器が既にある**） |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`recipes.json` の形は `{"recipes": [...]}` で、⚠ 研究やアイテムと違って配列**（⚠ **`_index_by()` を通る**）
- ⚠ **`_sync_recipes_from_master()` の早期 return は外してある**（`EXEC_WORKSHOP_RETIRE.md` 決め1）。⚠ **戻さないこと**
- ⚠ **素材IDは `<系統>_material_<1..4>` で固定。⚠ 新しい素材を作らない**
- ⚠ **装飾を作るなら `add_to_inventory()` を通す**（⚠ **装備の個体を作る唯一の口。⚠ 直接 `inventory` を書くと静かに消える**）
- ⚠ **`_validate_balance_item_refs()`（E121）と `_validate_all_item_refs()`（E118）に、⚠ レシピの `inputs` / `outputs` を見る枝が既にある**（⚠ **新しい番号を足す前にそれを見る**）
- ⚠ **`scenario=layout` の `LAYOUT_SCENES` に作業場が入っていない。⚠ 1行足すこと**
- ⚠ **`guild_screen` にボタンを戻すと下段の並びが1つ増える。⚠ 「5個前提の並びに6個目」を踏んでいる**（§4）
- ⚠ **`crafting_queue` は時刻を持つ。⚠ JSONから戻すと `started_at` / `duration_sec` が `float` になる**（⚠ **`_normalize_crafting_queue()` が `int()` に戻している**）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが37回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 2件（下の 34・37）。⚠ 次に見つけたものは 38 番。**

| # | ズレ | 直すなら |
|---|---|---|
| ⚠ **34** | ⚠ **`skill_schema.gd:330` のコメント「`of` を読まない source」は `scale_from` にしか当てはまらない。** ⚠ **`condition` は同じ source でも `of` が必須** | ⚠ **未着手。⚠ コメント側か、⚠ `condition` 側で `of` を任意にするか** |
| ⚠ **36** | ⚠ **`scenario=layout` が6シーンとも `最小幅 0` を返していた** | ⚠ **済**（⚠ **一番外側の `Container` を `SCREEN_SIZE` 基準で測る**） |
| ⚠ **37** | ⚠ **`ja.csv` の再インポートの合図が「前の回のキー」を見ていた**（⚠ **`scenario=passives` の1行**）。⚠ **その回に足したキーが未インポートでも「済んでいる」と答える** | ⚠ **その回のキーに差し替えて回避した**（今は `ui_research_board`）。⚠ **根治するなら「`ja.csv` の行数」と「翻訳の件数」を突き合わせる形にする** |

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-25・研究の回）：⚠ `NEXT_STEPS` §1-2 が枝を「戦闘 / 生産 / 探索」と推奨していたが、⚠ `GAME_DESIGN` 9-1 のカテゴリは「戦闘 / 作業場 / 宝箱」だった。⚠ 着手前に気づいて仕様側を採った。**

### 2-3. ⚠ 定数は名前ではなく値を見る

⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_enemy"` ではなく `"alive_count_enemy"`。⚠ 名前を JSON に書いてロード時に赤3本・戦闘中に毎フレームの赤3886本を出した**（2026-08-25）。

### 2-4. ⚠ `@export` を改名すると `.tres` の値が黙って消える

⚠ **実例：`ChestScheduleEntry.chest_type`**（⚠ **`protection_*.tres` の7件が黙って空になる**）。

### 2-5. ⚠ 大きな範囲の文字列置換をしない

⚠ **2026-08-23に `game_manager.gd` で715行を丸ごと消した。** → ⚠ **`Edit` で1箇所ずつ当てる。**

### 2-6. ⚠ 「同じ形の判定」が散っていたら1本に寄せる

今ある1本ものは：
- ⚠ **`BattleSession.find_unit()`** ／ **`battle_controller._all_units()`** ／ **`StatusRegistry.entries_for()`**
- ⚠ **`GameManager.get_forge_material_tier()`** ／ **`add_to_inventory()`**（装備の個体を作る唯一の口）
- ⚠ **`GameManager.get_part_reject_reason()`** ／ **`get_equip_reject_reason()`** ／ **`grant_chest()`** ／ **`_roll_chest_draw()`**
- ⚠ **`GameManager.set_party_member()`** ／ **`get_party_candidates()`**
- ⚠ **`GameManager._plan_build()` / `_write_build()`** ／ **`format_apply_report()`**
- ⚠ **`GameManager.get_battle_skills()` / `get_battle_passives()` / `get_battle_runes()`**
- ⚠ **`GameManager.unlock_research_node()`**（⚠ **研究の解放の唯一の口**）／ ⚠ **`get_research_board_of()`**（⚠ **ボードの唯一の口**）
- ⚠ **`GameManager.start_craft()` / `collect_craft()`**（⚠ **このタスクで触る**）
- ⚠ **`MasterDataLoader.rune_skill_data()`** ／ **`_merge_character_files()`**

### 2-7. ⚠ E / W の次番号

⚠ **`E128` まで使用済み → `E129` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-25確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | ⚠ **`C:\Users\admin\AppData\Roaming\Godot\app_userdata\pomodoro-heroes\logs\`**（⚠ **`user://`。⚠ プロジェクト直下ではない**）。`battle_last.jsonl`（戦闘のたびに上書き）／ `godot.log`（保持5本） |
| ⚠ **セーブの実体** | ⚠ **`...\app_userdata\pomodoro-heroes\saves\save_slot_0.json`**（⚠ **`user://saves/` の下。⚠ 直下ではない**） |
| ロード時の正常な出力 | `skills validated: 94 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ `items validated: 89 entries, 0 errors` ／ `runes validated: 25 entries, 0 errors` ／ `balance item refs validated: 0 errors` ／ ⚠ **`_sync_research_tree_from_master() -> 18 nodes`** ／ ⚠ **`level cap validated: 20 + 80 (8 nodes) = 100, 0 errors`** ／ `_sync_recipes_from_master() -> 0 recipes` |
| ⚠ **マスターは7本** | ⚠ **`items` / `stages` / `shop` / `research` / `recipes` / `chests` / `runes`**（⚠ **`characters` `enemies` は配下にフォルダを持つ。⚠ フォルダの中は `skills.json` / `nodes.json` / `passives.json` の3本**） |
| ⚠ **レベル** | ⚠ **上限 100**（⚠ **`base_level_cap` 20 ＋ 研究 `level_cap_unlock` 8件 × 10**）。⚠ **`max_character_level` も 100**。⚠ **`E127` が起動のたびに突き合わせる**。⚠ **育成素材は線形（`3 + 1.0×(level-1)`）で Lv100 まで約 5,148 個要る** |
| ⚠ **研究** | ⚠ **2ボード18ノード**（⚠ **ボード1＝12件・ボード2＝6件**）。⚠ **枝は `combat` と `chest`**。⚠ **効果は `level_cap_unlock` / `stat_boost_all`（`target_stat` で軸1本にも乗る）／ `chest_draw_bonus` の3種類**。⚠ **ボードは「前のボードを全部解放するまで出さない」** |
| ⚠ **作業場** | ⚠ **レシピ0件・ボタンは `visible = false`・画面とコードは残っている**（§1-1） |
| ⚠ **パッシブ** | ⚠ **本番3キャラ × 5件＝15件。⚠ Lv20/40/60/80/100 で解放。⚠ 解放されたものが全部効く（選ばない）**。⚠ **置き場は `characters/<id>/passives.json`**。⚠ **`react` は2件** |
| ⚠ **パッシブの縛り** | ⚠ **`E74` `target.team` は `self` だけ ／ `E75` `stack` は `refresh` だけ ／ `E76` `trigger` は `cast` だけ ／ `host` は `unit` だけ ／ `stat` に `hp` は書けない ／ `cooldown_sec` `charge` `recast` `phases` は書けない** |
| ⚠ **`condition` の書き方** | ⚠ **`source` に書けるのは 10軸 ＋ `hp_current` `hp_lost` `hp_ratio` `hp_lost_ratio` `elapsed_sec` `alive_count_ally` `alive_count_enemy` `wave_index` `stack` `status_has`**（⚠ **`distance` は除く**）。⚠ **`of` は必ず書く**（⚠ **ズレ34**） |
| ⚠ **`react` の出来事** | ⚠ **`attacked` / `dealt_damage` / `took_damage` の3つだけ**。⚠ **反応先は `target: {"team": "source"}`** |
| ⚠ **素材** | ⚠ **16件**。`construction_` / `training_` / `forging_` / `decor_` × `_1..4`。⚠ **`_4` はどのステージからも落ちない**（⚠ **月替わりショップだけ**） |
| ⚠ **装備の等級** | ⚠ **1〜10**。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]` |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`** |
| ⚠ **装飾** | ⚠ **61件**（宝石12・護符8・紋章16 ／ ルーン25） |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない** |
| ⚠ **プリセット** | ⚠ **2階層。⚠ `character_presets` の5キー（`nodes` `skills` `passives` `equipment` `rune_move`）。⚠ `passives` は誰も読まない欄** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **書く口は `set_party_member()` の1本** |
| ⚠ 座標の定数 | **`GROUND_Y = 240` ／ 味方 `PARTY_BASE_X=200` `STEP=100` ／ 敵 `ENEMY_BASE_X=900` `STEP=100`** |
| ⚠ **射程の段** | ⚠ **`60`（前衛）／ `180`（中衛）／ `300`（後衛）／ `420`（最後衛）** |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「素材を全種類」「装飾を全種類」「装備を全種類 1個ずつ」「研究を全部解放」「セーブする」** |
| 行数 | `game_manager` **約5100** ／ `battle_controller` **約1800** ／ `debug_boot` **約2200** ／ `master_data_loader` **約1300** |

```
battle_controller  … 入力と表示。ノードを触る唯一の層。⚠ ルーンの発火もここ（_fire_runes）
					 ⚠ パッシブの掛け直しもここ（_step_passives → _restore_passives）
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
- ⚠ **今あるシナリオ（29本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / `runes` / `unlock` / `passives` / ⚠ **`research`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝28本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` / `unlock` / `research` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`runes` と `passives` は戦闘を回す**（⚠ **どちらも挙動を変えるので `report` では足りない**）
- ⚠ **`layout` は「はみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **排他で切り替わる器は `LAYOUT_SCENE_SHOW` に1行足す**
  - ⚠ **`add_child()` を `call_deferred` にすること**
  - ⚠ **測るのは一番外側の `Container`。⚠ ルートを測ると必ず 0 が返る**（ズレ36）
  - ⚠ **基準は `SCREEN_SIZE`（1280 x 720）。⚠ ヘッドレスの viewport（1280 x 1280）を使わないこと**
  - ⚠ **`ScrollContainer` の中は測れない**（⚠ **研究画面のノード18件は縦に伸びるが `364 x 208` としか出ない。⚠ 縦は人間しか見られない**）
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**（⚠ **どちらも意図的に壊している**）
- ⚠ **赤の平常値は 0本。⚠ ただし `unlock` は 1本出るのが正解**（⚠ **`E125` を意図的に出している**）
- ⚠ **`ja.csv` を触った回は、⚠ 再インポートが済むまで `layout` が赤を出す。⚠ 済んだかは `scenario=passives` の `ja.csv の再インポート:` の1行で分かる**
  - ⚠ **合図が見るキーは、⚠ その回に足したキーへ必ず差し替えること**（⚠ **ズレ37。⚠ 今は `ui_research_board`**）
- ⚠ **1本あたり10〜20秒。⚠ 28本で9分ほど。⚠ 14本ずつ2回に分けて回すこと**
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
  - ⚠ **報告の枝は `_ready()` の `elif` にも1行要る**（⚠ **`REPORT_*` の定数と2箇所**）
  - ⚠ **関数を足すときは、⚠ 差し込む先の関数が「次の `func` までどこまでか」を見てから**（⚠ **2026-08-25に `_report_unlock()` の途中へ差し込んだ**）
- ⚠ **足した検証が本当に赤を出すか、2箇所で壊して確かめる**（⚠ **`E127` `E128` は `research.json` を一時的に壊して確かめ、⚠ 必ず戻して平常値に戻ったことを再実行で確認した**）
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **ただし `LAYOUT_SCENES` に入れた画面は `layout` が実際に開くので、⚠ そちらのほうが強い**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 全シナリオを回している最中にコードを触らない

⚠ **2026-08-23に `game_manager.gd` を編集し、赤560本の偽陽性を出した。**
→ ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない。⚠ `.md` はよい。**

### ⚠ 測る道具が「0」や「全部同じ数字」を返したら、まずその道具を疑う

⚠ **2026-08-25**：⚠ **`scenario=layout` が6シーンとも `最小幅 0` を返していたのに流した**（ズレ36）。
→ ⚠ **もっともらしい 0 を信じない。**

### ⚠ 「済んだか」を見る合図は、その回のものを見ているか確かめる（**2026-08-25**）

⚠ **`ja.csv` の再インポートの合図が、⚠ 前の回に足したキーを見たままだった。⚠ 今回のキーは未インポートなのに「済んでいる」と答えた**（ズレ37）。

### ⚠ 関数を足すときは「次の `func` まで」を見る（**2026-08-25**）

⚠ **`_report_unlock()` の末尾だと思った `print` の後ろに、まだ90行あった。⚠ 途中に新しい関数を差し込み、⚠ `scenario=research` が画面IDの報告まで出した。**

### ⚠ 定数は名前ではなく値を見る（**2026-08-25**）

⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_count_enemy"`。⚠ 名前を JSON に書いて赤3886本を出した。**

### ⚠ 人間しかできない作業は、済んだかを設計役が観測できる形にする

⚠ **`ja.csv` の再インポートも `.tres` の編集も設計役にはできない。**
→ ⚠ **`scenario=passives` に「再インポート: まだ／済んでいる」の1行がある**（⚠ **`scenario=unlock` が `.tres` について同じことをしている**）。

### ⚠ 検証で在庫を「減らすために操作を繰り返す」書き方をしない

⚠ **2026-08-24**：⚠ **`while count > 1: merge_runes()` が150回回り、出力が数万行になった。**
→ ⚠ **在庫を整えるときは一度に配る／一度に減らす。**

### ⚠ 件数を増やす回では、既存の「集計」も見る

⚠ **2026-08-24**：⚠ **`scenario=parts` の「IDと欄の綴りが一致しないもの N 件」に、⚠ ルーン25件が全部数えられた。**

### ⚠ Bash ツールに PowerShell の書き方を渡さない

⚠ **ヒアストリング（`@'...'@`）を渡してコミットメッセージの先頭に `@` が入った。⚠ Bash では heredoc（`<< 'EOF'`）。**

### ⚠ `.tscn` を触らずコードでノードを足すときは、隣の兄弟の `size_flags` を見る

⚠ **5個前提の並びに6個目を足して、拠点の下段が丸ごと左右にはみ出した。**

### ⚠ 新しい `class_name` は、エディタを1回通すまで認識されない

⚠ **確かめ方**：`grep -c "<クラス名>" .godot/global_script_class_cache.cfg`

### ⚠ 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。**（⚠ **`tests/` は例外。あちらは `print` が出口**）

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ トップレベルだけ半角スペース2つのファイルが在る＝`stages.json` / `chests.json` / `runes.json` / `recipes.json`）。`ja.csv`はUTF-8（BOMなし・LF）。

---

## 5. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここは判断待ちと大きい穴だけ。

### ⚠ 人間の判断待ち

1. ⚠ **マスターファイルが7本目になった**（`runes.json`。⚠ **6本目＝`chests.json` の判断が未了のまま増えた**）／ ⚠ **キャラのフォルダも3本目になった**（`passives.json`）
2. ⚠ **射程の段のルールが `EXEC_BATTLE_LINEUP.md` にしか書いていない**
3. ⚠ **`W16`（知らない欄）を赤に上げるか**
4. ⚠ **godot MCP の設定を消すか** ／ **`tests/` の既存9件の棚卸し** ／ **Ziva の `.bak` が7件残っている**
5. ⚠ **`ja.ja.translation` が縮んだ理由が不明**
6. ⚠ **素材の変換経路が消えたまま**（⚠ **`GAME_DESIGN` 9-3 は「ショップに一本化」と言っている**）
7. ⚠ **Lv100 までの育成素材が約 5,148 個要る**（⚠ **線形式のまま。⚠ 段階12で効く**）

### ⚠ 器の穴（**大きいものだけ**）

0. ⚠ **どのステージで何が開くかが「勘」**（⚠ **9-5 の10段を4段に畳んである**）／ ⚠ **作業場が2箇所で閉じている**（⚠ **このタスク**）
8. ⚠ **ルーンのかけらが無い** ／ ⚠ **ルーンの本番入手経路が無い**（`F4` だけ）
9. ⚠ **`GROWTH_PASSIVES`（状態）とキャラプリセットの `passives` が、誰も読まない欄として残っている** ／ ⚠ **`PASSIVE_SLOT_COUNT` / `_slot_spec()` のパッシブの枝 / `get_selected_passives()` / `select_skill()` のパッシブ経路が画面から到達できない**
10. ⚠ **`react` の中で `buff` / `heal` を出す形が本番に0件** ／ ⚠ **`host: point` が本番に0件**
11. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない**
12. ⚠ **`party_changed` シグナルが無い**
13. ⚠ **等級10の「部位固有のパッシブ」が未実装** ／ ⚠ **護符が宝石と仕組み上同じ**
14. ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない** ／ ⚠ **パッシブが戦闘画面のどこにも一覧で出ない**
15. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
16. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
17. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
18. ⚠ **オーラの範囲が画面に描かれない** ／ ⚠ **状態の色が3つしかない** ／ ⚠ **状態の残り時間がマスに出ない**
34. ⚠ **研究にゴールド払いが無い**（⚠ **`GAME_DESIGN` 9-1 は「ゴールドと各種資源」と言っている。⚠ `unlock_research_node()` は素材1種類だけを見る**）
35. ⚠ **研究の宝箱枝が「抽選回数」だけ**（⚠ **ドロップ率・高等級の確率＝`weight` に乗る効果が無い**）／ ⚠ **ボードは2枚しか無い**

### ⚠ 数値が全部「勘」

19. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**
20. ⚠ **装飾の `part_base` / `part_roll_max` 72個 ＋ `part_config.tres` の7個**
21. ⚠ **ルーンの CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ ロック秒 ／ 重ねる個数**
22. ⚠ **パッシブ15件の効果量** ／ ⚠ **研究18件の効果量とコスト**（⚠ **2026-08-25。⚠ 上限の刻みは +10 に均した**）
23. ⚠ **宝箱の中身と `weight`**

### ⚠ 表示の穴

24. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
25. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**
26. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
27. ⚠ **`weapon_steel_sword` がどこからも出ない** ／ ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**
28. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（意図的）

### 片付け

29. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
30. ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**
31. ⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用** ／ ⚠ **`ja.csv` の `ui_guild_workshop*` 12行も残してある**（⚠ **このタスクで戻す**）
32. ⚠ **`ui_skill_select_passive_slot` と `ui_skill_select_passive_candidates_header` の2行が未使用**
33. ⚠ **共有部品 `BuildPresetRow` を作れていない**（⚠ **育成と装備に同じ行が2本ある**）

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **残っているのは 段階12（バランス実測）だけ。⚠ 依存は全部揃っている。**
