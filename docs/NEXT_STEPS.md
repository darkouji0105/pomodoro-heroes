# 次にやること：**⑫ バランス実測（最後の段階）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階12。⚠ 依存（5・6・8・10・11）は全部揃った。⚠ これが最後の段階。**
⚠ **仕様の正は `GAME_DESIGN.md`。⚠ 人間の決定はまだ無い。⚠ §1-2 を先に聞くこと。**

---

## 0. ⚠ 前のタスクは終わっている（**2026-08-25・段階11の後半＝作業場の復活**）

**指示書は `docs/02_exec/EXEC_WORKSHOP_REVIVE.md`。⚠ コミットは `7c47b5f`。**
⚠ **ログとファイルの項目は全部通っている**（⚠ **29本を1本ずつ回した**）。

### 0-0. ⚠ 前の回の人間の宿題（**まだ終わっていない・着手前に片付ける**）

1. ⚠ **`ja.csv` の再インポート**（⚠ **6行足した。⚠ Godot の FileSystem で `localization/ja.csv` を右クリック → 再インポート**）
   ⚠ **済んだかは `scenario=passives` の `ja.csv の再インポート:` の1行で分かる**（⚠ **今は `ui_research_category_workshop` を見ている**）
2. ⚠ **画面の12項目**（`EXEC_WORKSHOP_REVIVE.md` §5-C の C-1 〜 C-16）。⚠ **要点だけ挙げると：**
   - ⚠ ギルドのボタンが**6個**になり、⚠ **一番下が画面の外に出ていないか**
   - ⚠ 作業場のレシピが**3行**、⚠ 各行が「装飾素材 ×12 → 装飾（ランダム）」の形で、⚠ **`ui_` が生で出ていないか**
   - ⚠ 「作る」→ 残り時間が1秒ずつ減り、⚠ **行が二重に並ばないか**
   - ⚠ 「受け取る」→ **倉庫の持ち物に装飾が1個増え、⚠ 2回目は違うものが出るか**
   - ⚠ **F4 →「研究を全部解放」で、⚠ ボード2に「作業場」の見出しと2行が出て、⚠ 「製作時間 -20%」「同時製作 +1」と読めるか**
   - ⚠ **そのあと作業場の時間が 30:00 → 24:00 になり、⚠ 2本同時に作れるか**
3. ⚠ **そのあと1回セーブしてもらう**（⚠ **`save_slot_0.json` に `"duration_sec": 1440.0` のような `.0` が無いことを設計役が読む＝`EXEC_WORKSHOP_REVIVE` §5-B の B-8**）

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **パッシブ** | ⚠ **本番3キャラ × 5件＝15件** ／ ⚠ **レベル上限 30 → 100** ／ ⚠ **`E126`** |
| **研究** | ⚠ **2ボード18ノード**（⚠ **枝は「戦闘」と「宝箱」**）／ ⚠ **上限は 8件 × +10 ＝ ちょうど 100** ／ ⚠ **`E127` `E128`** ／ ⚠ **`scenario=research`** |
| **作業場** | ⚠ **装飾のくじ3レシピ**（⚠ **`recipes.json` に `draw` の欄が入った＝出るものが固定でないレシピ**）／ ⚠ **`stage_3` で解放＝ギルドのボタンが6個** ／ ⚠ **研究ボード2に `workshop` 枝2件＝18 → 20ノード** ／ ⚠ **`E129`** ／ ⚠ **`scenario=workshop`** |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
4. ⚠ **ルーンの中身は `runes.json`（マスター7本目）に置く**（2026-08-24）
5. ⚠ **解放の単位は画面IDを増やす ／ 閉じている機能は「出さない」 ／ 引き金はステージのクリア**（2026-08-24）
6. ⚠ **パッシブは選ばない。⚠ 解放されたものが全部効く**（2026-08-25）
7. ⚠ **レベル100まで上げられるようにする**（2026-08-25。⚠ **`base_level_cap` 20 ＋ 研究8件 × 10 ＝ 100**）
8. ⚠ **研究のボードは「1周クリアで次に切り替わる」**（2026-08-25。⚠ **今は2枚**）
9. ⚠ **作業場は「装飾のランダム製作」だけ入れる。⚠ 中間素材（研究用素材）は入れない**（2026-08-25。⚠ **5系統目の素材が要るため。⚠ 宿題36**）
10. ⚠ **作業場は `stage_3` のクリアで開く**（2026-08-25）
11. ⚠ **研究の作業場枝は「製作時間の短縮」と「キュー本数」の2件だけ**（2026-08-25。⚠ **変換レートは変換が廃止のため入れない＝ズレ38**）

### 0-3. ⚠ 作業場で作った器（**このタスクで数値を触る／壊さない**）

| 器 | 中身 |
|---|---|
| ⚠ **`recipes.json` の `draw`** | ⚠ **`{rolls, entries:[{item_id, weight, count}]}`。⚠ 形は `chests.json` の `draw` と同じ** |
| ⚠ **`GameManager._roll_weighted_table()`** | ⚠ **抽選の本体はここ1本だけ。⚠ 宝箱もレシピもこれを通る。⚠ ボーナスの類は一切見ない** |
| ⚠ **`_roll_chest_draw()` / `_roll_recipe_draw()`** | ⚠ **前者だけ `get_research_chest_draw_bonus()` が乗る。⚠ 混ぜないこと** |
| ⚠ **`get_research_craft_speed_percent()` / `get_research_craft_slot_bonus()`** | ⚠ **乗る先は `start_craft()` の `duration_sec` と `get_max_queue_slots()` の各1箇所だけ** |
| ⚠ **`_research_effect_total(effect_type)`** | ⚠ **解放済みノードの `effect_value` を合計する1本。⚠ 効果を足すときはこれを使う** |
| ⚠ **`E129`** | ⚠ **`outputs` も `draw` も無い ／ `draw.entries` が空 ／ `item_id` が `""` ／ `weight` の合計が0以下** |

---

## 1. ⚠ このタスク：**バランス実測**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階12。⚠ 規模は未定（⚠ **§1-2 の答え次第**）。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **これしか残っていない**（⚠ **段階13＝SDキャラとアニメーションは「専用の会話」で別枠**）
- ⚠ **数値が全部「勘」で入っている**（⚠ **§5 の「数値が全部『勘』」に5項目。⚠ 今回さらに3項目増えた**）
- ⚠ **`def` が除算式になったので、⚠ 既存の全数値の意味が変わっている**（`GAME_DESIGN` 8-2-1）

### 1-1. ⚠ いまの実装（**2026-08-25に確認**）

| | 事実 |
|---|---|
| ⚠ **勘で入っている数値の置き場** | ⚠ **`resources/balance/*.tres`（⚠ **設計役は直せない。人間の作業**）と ⚠ **`resources/balance/master/*.json`（⚠ **設計役が直せる**） |
| ⚠ **測る道具が無い** | ⚠ **`scenario=drops` が1000回の分布を出すのと、⚠ `scenario=workshop` が1000回の分布を出すだけ。⚠ 「Lv1からどれだけ回せば Lv100 になるか」を出す道具は無い** |
| ⚠ **本番ステージが3本しかない** | ⚠ **`stage_1` / `stage_2` / `stage_3` × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **育成素材が線形** | ⚠ **`3 + 1.0×(level-1)`。⚠ Lv100 まで約 5,148 個要る**（宿題7） |
| ⚠ **`construction_material_4` の入口が月替わりショップだけ** | ⚠ **研究ノード2件（`res2_stat_crit_1` / `res2_stat_4`）と `res2_craft_2` が要求する** |

### 1-2. ⚠ 先に聞くこと（**着手前**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **「実測」を何でやるか。⚠ ヘッドレスで数字を出すのか、⚠ 人間が遊んで体感で決めるのか** | ⚠ **まずヘッドレスで「1周回すと何が何個入るか」の表を出す**（⚠ **`scenario=economy` を1本足す**）。⚠ **体感はそのあと** |
| **2** | ⚠ **何を測るか。⚠ 全部やると大きすぎる** | ⚠ **3つに絞る：①戦闘が何秒で終わるか ②Lv100 までの周回数 ③素材の入口と出口の収支**（⚠ **装飾の出目・ルーンの効果量は後回し**） |
| **3** | ⚠ **数値を直す範囲。⚠ `.tres` は人間しか直せない** | ⚠ **今回は `master/*.json` だけ直す**（⚠ **`.tres` を直す必要が出たら、⚠ 値の一覧を人間に渡す形にする**） |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`.tres` は設計役が直せない**（⚠ **`pomodoro_config` / `character_config` / `workshop_config` / `part_config` など**）。⚠ **人間に渡す形を先に決める**
- ⚠ **`initial_state_config.tres` はセーブがあると読まれない**（⚠ **`master/*.json` を直すと既存セーブにも次の起動で反映されるが、⚠ `.tres` は反映されない**）
- ⚠ **`scenario=drops` と `scenario=workshop` は「意図的に赤黄を出す」枝を持っている**（⚠ **平常値を変えないこと**）
- ⚠ **シナリオを足すときは `SCENARIOS` と `_ready()` の `elif` の2箇所**（⚠ **`REPORT_*` の定数と合わせて3箇所**）
- ⚠ **戦闘を回すシナリオは1本10〜20秒。⚠ 「1000回戦わせる」を書くと終わらない**（⚠ **分布は `_roll_*` を直接叩く形にする＝`drops` と `workshop` がそうしている**）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが38回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 3件（下の 34・37・38）。⚠ 次に見つけたものは 39 番。**

| # | ズレ | 直すなら |
|---|---|---|
| ⚠ **34** | ⚠ **`skill_schema.gd:330` のコメント「`of` を読まない source」は `scale_from` にしか当てはまらない。** ⚠ **`condition` は同じ source でも `of` が必須** | ⚠ **未着手。⚠ コメント側か、⚠ `condition` 側で `of` を任意にするか** |
| ⚠ **37** | ⚠ **`ja.csv` の再インポートの合図が「前の回のキー」を見ていた**（⚠ **`scenario=passives` の1行**） | ⚠ **その回のキーに差し替えて回避している**（今は `ui_research_category_workshop`）。⚠ **根治するなら「`ja.csv` の行数」と「翻訳の件数」を突き合わせる形にする** |
| ⚠ **38** | ⚠ **`GAME_DESIGN` 9-1 の作業場カテゴリに「変換レート」が残っている。⚠ 同じファイルの 9-3 と 2章（`:104`）が「変換は廃止・ショップに一本化」と書いており、⚠ 上げるレートが存在しない** | ⚠ **未着手。⚠ 9-1 の表の3つ目を消す** |

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-25・作業場の回）：⚠ `GAME_DESIGN` 9-3 と `:84` の資源表が「中間素材＝5系統目の素材」を前提にしており、⚠ 「新しい素材を作らない」という守りと正面から食い違っていた。⚠ 着手前に気づいて人間に聞き、⚠ 仕様側を採らずに見送った**（⚠ **前の回は仕様側を採った。⚠ どちらを採るかは人間が決める**）。

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
- ⚠ **`GameManager.get_part_reject_reason()`** ／ **`get_equip_reject_reason()`** ／ **`grant_chest()`**
- ⚠ **`GameManager._roll_weighted_table()`**（⚠ **抽選の本体はここ1本だけ。⚠ `_roll_chest_draw()` と `_roll_recipe_draw()` が呼ぶ**）
- ⚠ **`GameManager.set_party_member()`** ／ **`get_party_candidates()`**
- ⚠ **`GameManager._plan_build()` / `_write_build()`** ／ **`format_apply_report()`**
- ⚠ **`GameManager.get_battle_skills()` / `get_battle_passives()` / `get_battle_runes()`**
- ⚠ **`GameManager.unlock_research_node()`** ／ **`get_research_board_of()`** ／ **`_research_effect_total()`**
- ⚠ **`GameManager.start_craft()` / `collect_craft()`**
- ⚠ **`MasterDataLoader.rune_skill_data()`** ／ **`_merge_character_files()`**

### 2-7. ⚠ E / W の次番号

⚠ **`E129` まで使用済み → `E130` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-25確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | ⚠ **`C:\Users\admin\AppData\Roaming\Godot\app_userdata\pomodoro-heroes\logs\`**（⚠ **`user://`。⚠ プロジェクト直下ではない**）。`battle_last.jsonl`（戦闘のたびに上書き）／ `godot.log`（保持5本） |
| ⚠ **セーブの実体** | ⚠ **`...\app_userdata\pomodoro-heroes\saves\save_slot_0.json`**（⚠ **`user://saves/` の下。⚠ 直下ではない**） |
| ロード時の正常な出力 | `skills validated: 94 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ `items validated: 89 entries, 0 errors` ／ `runes validated: 25 entries, 0 errors` ／ `balance item refs validated: 0 errors` ／ ⚠ **`_sync_research_tree_from_master() -> 20 nodes`** ／ ⚠ **`level cap validated: 20 + 80 (8 nodes) = 100, 0 errors`** ／ ⚠ **`_sync_recipes_from_master() -> 3 recipes (unlocked=3, skipped=0)`** |
| ⚠ **マスターは7本** | ⚠ **`items` / `stages` / `shop` / `research` / `recipes` / `chests` / `runes`**（⚠ **`characters` `enemies` は配下にフォルダを持つ。⚠ フォルダの中は `skills.json` / `nodes.json` / `passives.json` の3本**） |
| ⚠ **レベル** | ⚠ **上限 100**（⚠ **`base_level_cap` 20 ＋ 研究 `level_cap_unlock` 8件 × 10**）。⚠ **`E127` が起動のたびに突き合わせる**。⚠ **育成素材は線形（`3 + 1.0×(level-1)`）で Lv100 まで約 5,148 個要る** |
| ⚠ **研究** | ⚠ **2ボード20ノード**（⚠ **ボード1＝12件・ボード2＝8件**）。⚠ **枝は `combat` / `chest` / `workshop`**。⚠ **効果は `level_cap_unlock` / `stat_boost_all`（`target_stat` で軸1本にも乗る）／ `chest_draw_bonus` / `craft_speed_bonus` / `craft_slot_bonus` の5種類**。⚠ **ボードは「前のボードを全部解放するまで出さない」** |
| ⚠ **作業場** | ⚠ **装飾のくじ3レシピ**（`craft_part_1..3`）。⚠ **投入は `decor_material_1..3` ×12。⚠ 30分/90分/3時間。⚠ 出るのは装飾36件のいずれか1個**（⚠ **ルーンは出ない**）。⚠ **`stage_3` のクリアで開く**。⚠ **キューは1本（研究で+1）** |
| ⚠ **パッシブ** | ⚠ **本番3キャラ × 5件＝15件。⚠ Lv20/40/60/80/100 で解放。⚠ 解放されたものが全部効く（選ばない）**。⚠ **置き場は `characters/<id>/passives.json`**。⚠ **`react` は2件** |
| ⚠ **パッシブの縛り** | ⚠ **`E74` `target.team` は `self` だけ ／ `E75` `stack` は `refresh` だけ ／ `E76` `trigger` は `cast` だけ ／ `host` は `unit` だけ ／ `stat` に `hp` は書けない ／ `cooldown_sec` `charge` `recast` `phases` は書けない** |
| ⚠ **`condition` の書き方** | ⚠ **`source` に書けるのは 10軸 ＋ `hp_current` `hp_lost` `hp_ratio` `hp_lost_ratio` `elapsed_sec` `alive_count_ally` `alive_count_enemy` `wave_index` `stack` `status_has`**（⚠ **`distance` は除く**）。⚠ **`of` は必ず書く**（⚠ **ズレ34**） |
| ⚠ **`react` の出来事** | ⚠ **`attacked` / `dealt_damage` / `took_damage` の3つだけ**。⚠ **反応先は `target: {"team": "source"}`** |
| ⚠ **素材** | ⚠ **16件**。`construction_` / `training_` / `forging_` / `decor_` × `_1..4`。⚠ **`_4` はどのステージからも落ちない**（⚠ **月替わりショップだけ**） |
| ⚠ **装備の等級** | ⚠ **1〜10**。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]` |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`** |
| ⚠ **装飾** | ⚠ **61件**（宝石12・護符8・紋章16 ／ ルーン25）。⚠ **くじに入るのは前の36件だけ** |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない** |
| ⚠ **プリセット** | ⚠ **2階層。⚠ `character_presets` の5キー（`nodes` `skills` `passives` `equipment` `rune_move`）。⚠ `passives` は誰も読まない欄** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **書く口は `set_party_member()` の1本** |
| ⚠ 座標の定数 | **`GROUND_Y = 240` ／ 味方 `PARTY_BASE_X=200` `STEP=100` ／ 敵 `ENEMY_BASE_X=900` `STEP=100`** |
| ⚠ **射程の段** | ⚠ **`60`（前衛）／ `180`（中衛）／ `300`（後衛）／ `420`（最後衛）** |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **画面の解放** | ⚠ **`stage_1` → `guild` `equipment` `training` `warehouse` ／ `stage_2` → `pomodoro` `decoration` ／ `stage_3` → `research` `shop` `rune` `workshop`** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「素材を全種類」「装飾を全種類」「装備を全種類 1個ずつ」「研究を全部解放」「画面を全部解放」「セーブする」** |
| 行数 | `game_manager` **約5200** ／ `battle_controller` **約1800** ／ `debug_boot` **約2400** ／ `master_data_loader` **約1350** |

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
- ⚠ **今あるシナリオ（30本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / `runes` / `unlock` / `passives` / `research` / ⚠ **`workshop`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝29本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` / `unlock` / `research` / `workshop` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`runes` と `passives` は戦闘を回す**（⚠ **どちらも挙動を変えるので `report` では足りない**）
- ⚠ **`layout` は「はみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **排他で切り替わる器・段階解放で消える器は `LAYOUT_SCENE_SHOW` に1行足す**（⚠ **ギルドはこれを足すまで `72 x 72` しか測れていなかった＝2026-08-25**）
  - ⚠ **`add_child()` を `call_deferred` にすること**
  - ⚠ **測るのは一番外側の `Container`。⚠ ルートを測ると必ず 0 が返る**（ズレ36）
  - ⚠ **基準は `SCREEN_SIZE`（1280 x 720）。⚠ ヘッドレスの viewport（1280 x 1280）を使わないこと**
  - ⚠ **`ScrollContainer` の中は測れない**（⚠ **縦は人間しか見られない**）
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**（⚠ **どちらも意図的に壊している**）
- ⚠ **赤の平常値は 0本。⚠ ただし `unlock` は 1本（`E125`）・`workshop` は 2本（`E129`）出るのが正解**
- ⚠ **`ja.csv` を触った回は、⚠ 再インポートが済むまで研究画面の効果が「？」になる。⚠ 済んだかは `scenario=passives` の `ja.csv の再インポート:` の1行で分かる**
  - ⚠ **合図が見るキーは、⚠ その回に足したキーへ必ず差し替えること**（⚠ **ズレ37。⚠ 今は `ui_research_category_workshop`**）
- ⚠ **1本あたり10〜20秒。⚠ 29本で9分ほど。⚠ 10本ずつ3回に分けて回すこと**（⚠ **PowerShell ツールの既定タイムアウトは2分。⚠ `timeout` を伸ばすこと**）
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
  - ⚠ **報告の枝は `_ready()` の `elif` にも1行要る**（⚠ **`REPORT_*` の定数と合わせて3箇所**）
  - ⚠ **関数を足すときは、⚠ 差し込む先の関数が「次の `func` までどこまでか」を見てから**（⚠ **2026-08-25に `_report_unlock()` の途中へ差し込んだ**）
- ⚠ **足した検証が本当に赤を出すか、2箇所で壊して確かめる**（⚠ **`E129` は `MasterDataLoader._cache_recipes` を一時的に壊して確かめ、⚠ 必ず戻して平常値に戻ったことを再実行で確認した。⚠ `recipes.json` そのものは触っていない＝`git diff` が最初から空**）
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **ただし Autoload が読まれないため `Identifier not found: GameManager` は必ず出る。⚠ これは無視してよい**。⚠ **`LAYOUT_SCENES` に入れた画面は `layout` が実際に開くので、⚠ そちらのほうが強い**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 全シナリオを回している最中にコードを触らない

⚠ **2026-08-23に `game_manager.gd` を編集し、赤560本の偽陽性を出した。**
→ ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない。⚠ `.md` はよい。**

### ⚠ 測る道具が「0」や「全部同じ数字」を返したら、まずその道具を疑う（**2026-08-25に2回目**）

⚠ **1回目**：⚠ `scenario=layout` が6シーンとも `最小幅 0` を返していたのに流した（ズレ36）。
⚠ **2回目**：⚠ **ギルドが `72 x 72` を返していた。⚠ 段階解放で5個とも `visible = false` のため、⚠ 見出しと戻るだけを測っていた。⚠ 「5個前提の並びに6個目」を見るための道具が、その姿を測れていなかった。**
→ ⚠ **もっともらしい小さい数字を信じない。**

### ⚠ 既存の器を「そのまま呼ぶ」前に、中に何が乗っているか見る（**2026-08-25**）

⚠ **`_roll_chest_draw()` の中に `get_research_chest_draw_bonus()` が入っていた。⚠ 作業場のくじからそのまま呼んでいたら、⚠ 宝箱の研究が作業場にも黙って効いていた**（⚠ **赤も黄も出ない**）。
→ ⚠ **抽選の本体を `_roll_weighted_table()` に切り出し、⚠ ボーナスは呼ぶ側に置いた。**

### ⚠ 「済んだか」を見る合図は、その回のものを見ているか確かめる（**2026-08-25**）

⚠ **`ja.csv` の再インポートの合図が、⚠ 前の回に足したキーを見たままだった**（ズレ37）。

### ⚠ 関数を足すときは「次の `func` まで」を見る（**2026-08-25**）

⚠ **`_report_unlock()` の末尾だと思った `print` の後ろに、まだ90行あった。**

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
5. ⚠ **`ja.ja.translation` が縮んだ理由が不明**（⚠ **段階11のコミットには含めていない。⚠ 再インポートで作り直される**）
6. ⚠ **素材の変換経路が消えたまま**（⚠ **`GAME_DESIGN` 9-3 は「ショップに一本化」と言っている。⚠ `shop.json` に相当する枠があるかは未確認**）
7. ⚠ **Lv100 までの育成素材が約 5,148 個要る**（⚠ **線形式のまま。⚠ このタスクで効く**）
8. ⚠ **中間素材（研究用素材）を入れるか**（⚠ **宿題36。⚠ 5系統目の素材が要る。⚠ このタスクで `construction_material_4` の入手量を測ってから決める**）

### ⚠ 器の穴（**大きいものだけ**）

9. ⚠ **ルーンのかけらが無い** ／ ⚠ **ルーンの本番入手経路が無い**（`F4` だけ。⚠ **作業場のくじにも入れていない**）
10. ⚠ **`GROWTH_PASSIVES`（状態）とキャラプリセットの `passives` が、誰も読まない欄として残っている** ／ ⚠ **`PASSIVE_SLOT_COUNT` / `_slot_spec()` のパッシブの枝 / `get_selected_passives()` / `select_skill()` のパッシブ経路が画面から到達できない**
11. ⚠ **`crafting_queue` の `output_item_id` / `recipe_type` が `draw` レシピでは `""` になる**（⚠ **どちらも誰も読んでいない欄**）
12. ⚠ **作業場のアップグレードが無い**（⚠ **`GAME_DESIGN` 9-3「建築素材で作業場自体をアップグレード」。⚠ キュー本数は研究の枝にした**）／ ⚠ **掘削（9-3-1）はデモ範囲外**
13. ⚠ **`react` の中で `buff` / `heal` を出す形が本番に0件** ／ ⚠ **`host: point` が本番に0件**
14. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない** ／ ⚠ **`party_changed` シグナルが無い**
15. ⚠ **等級10の「部位固有のパッシブ」が未実装** ／ ⚠ **護符が宝石と仕組み上同じ**
16. ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない** ／ ⚠ **パッシブが戦闘画面のどこにも一覧で出ない**
17. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
18. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
19. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
20. ⚠ **オーラの範囲が画面に描かれない** ／ ⚠ **状態の色が3つしかない** ／ ⚠ **状態の残り時間がマスに出ない**
21. ⚠ **研究にゴールド払いが無い**（⚠ **`GAME_DESIGN` 9-1 は「ゴールドと各種資源」と言っている**）
22. ⚠ **研究の宝箱枝が「抽選回数」だけ**（⚠ **ドロップ率・高等級の確率＝`weight` に乗る効果が無い**）／ ⚠ **ボードは2枚しか無い**

### ⚠ 数値が全部「勘」（**このタスクの本体**）

23. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**
24. ⚠ **装飾の `part_base` / `part_roll_max` 72個 ＋ `part_config.tres` の7個**
25. ⚠ **ルーンの CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ ロック秒 ／ 重ねる個数**
26. ⚠ **パッシブ15件の効果量** ／ ⚠ **研究20件の効果量とコスト**
27. ⚠ **宝箱の中身と `weight`**
28. ⚠ **作業場のくじ**（⚠ **投入12個 ／ 30分・90分・3時間 ／ 重み 10/3/2**）
29. ⚠ **ショップの価格** ／ ⚠ **装備の `equip_stats`**

### ⚠ 表示の穴

30. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
31. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**
32. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
33. ⚠ **`weapon_steel_sword` がどこからも出ない** ／ ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**
34. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（意図的）

### 片付け

35. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
36. ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**
37. ⚠ **`ui_skill_select_passive_slot` と `ui_skill_select_passive_candidates_header` の2行が未使用**
38. ⚠ **共有部品 `BuildPresetRow` を作れていない**（⚠ **育成と装備に同じ行が2本ある**）

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **段階12 が終わると、残りは 段階13（SDキャラとアニメーション＝専用の会話）だけ。**
