# 次にやること：**⑫-b 測った数値を入れる（バランス調整）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **段階12（バランス実測）は終わっている。⚠ これはその後半＝「測った値を実際に入れる回」**（⚠ **人間が「今回は測るだけ。直すのは次の回」と決めた**）。
⚠ **入力は `docs/02_exec/EXEC_BALANCE_ECONOMY.md` §9-2（測った結果）と §9-3（直す値の一覧）。⚠ 先に読むこと。**
⚠ **仕様の正は `GAME_DESIGN.md`。⚠ 人間の決定はまだ無い。⚠ §1-2 を先に聞くこと。**

---

## 0. ⚠ 前のタスクは終わっている（**2026-08-25・段階12＝バランス実測**）

**指示書は `docs/02_exec/EXEC_BALANCE_ECONOMY.md`。⚠ コミットは `52eea88`。**
⚠ **ログとファイルの項目は全部通っている**（⚠ **30本を1本ずつ回した**）。⚠ **画面の項目は3つだけ**（§0-2）。

### 0-0. ⚠ 何が入ったか

- ⚠ **`scenario=economy`（31本目）**。⚠ **戦闘を回さない（`kind: "report"`）**
  - ⚠ **素材16件の入口と出口 ／ 1周で入るもの ／ Lv100までの周回数と集中時間 ／ 研究の総コスト ／ ゴールドの入口**
  - ⚠ **赤も黄も1本も足していない。⚠ 「出口が無い素材」は `print` で名指しするだけ**（⚠ **赤にすると30本全部が赤になるため**）
  - ⚠ **末尾に宿題43の検証枝がある**（⚠ **`load_state()` に `count: 5.0` を直接渡して型を見る＝UIから到達できない経路**）
- ⚠ **`load_state()` が `inventory` の `count` を `int()` に戻すようになった**（⚠ **宿題43。⚠ `count` だけ。⚠ `type` / `slot_position` / `properties` は触っていない**）
- ⚠ **数値は1つも直していない。⚠ `.json` / `.tres` / `.csv` / `.tscn` を1件も触っていない**

### 0-1. ⚠ 測って分かったこと（**このタスクの入力**・全文は `EXEC_BALANCE_ECONOMY.md` §9-2）

| # | 分かったこと |
|---|---|
| **1** | ⚠ **Lv100 が遠すぎる。⚠ 3キャラで `training_material_1` が 15,444 個 ＝ `stage_2` を 3,861 周 ＝ スタミナ 19,305 ＝ **集中 160.9 時間**（⚠ **1周5スタミナ・入口はポモドーロのポーションだけ＝集中25分で+50**） |
| **2** | ⚠ **`training_material_2` / `_3` / `_4` に出口が1つも無い**（⚠ **レベルアップが `level_up_material_id` の1件しか使わない**）。⚠ **`stage_3` は `training_material_1` を1個も落とさないので、⚠ 進むほど育成が止まる** |
| **3** | ⚠ **`decor_material_4` にも出口が無い**（⚠ **装飾の段階が4止まり。⚠ 作業場のレシピも `_1..3` だけ**） |
| **4** | ⚠ **`construction_material_4` の入口が daily ショップだけ**（⚠ **x3 を 5000G・在庫1。⚠ 研究が55個要求 ＝ 19日 ＋ 91,667G ＝ `stage_3` 764周ぶんのゴールド**） |
| **5** | ⚠ **`construction_material_3` は 230 個要って `stage_3` が 1個/周 ＝ 230 周** |
| **6** | ⚠ **宝箱は3割の周でしか出ない**（⚠ **ハズレ枠の `weight` が 70**）。⚠ **研究を全部解放すると 0.30 → 0.91 個/周** |
| **7** | ⚠ **入口が無い素材は0件**（⚠ **穴は出口の側にある**） |

### 0-2. ⚠ 前の回の人間の宿題（**⚠ 1件だけ残っている**）

⚠ **`EXEC_BALANCE_ECONOMY.md` §5-C の3項目と §5-B の B-5 が未了。**
⚠ **`F4` →「装飾を全種類」→「セーブする」→ アプリを閉じて開き直す → もう一度「セーブする」。⚠ そのあと設計役が `save_slot_0.json` を読み、⚠ `"count"` に `.0` が0件であることを見る。**
⚠ **ログ側（`scenario=economy` の末尾）では既に `count = 5 (int)` を確認済みで、⚠ 壊すと `5.0 (float)` に戻ることも確かめてある。⚠ 実セーブでの確認だけが残っている。**

### 0-3. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
4. ⚠ **解放の単位は画面IDを増やす ／ 閉じている機能は「出さない」 ／ 引き金はステージのクリア**（2026-08-24）
5. ⚠ **パッシブは選ばない。⚠ 解放されたものが全部効く**（2026-08-25）
6. ⚠ **レベル100まで上げられるようにする**（2026-08-25。⚠ **`base_level_cap` 20 ＋ 研究8件 × 10 ＝ 100**）
7. ⚠ **作業場は「装飾のランダム製作」だけ。⚠ 中間素材は入れない**（2026-08-25）
8. ⚠ **バランス実測は「測るだけ」。⚠ 数値を直すのは次の回**（2026-08-25。⚠ **＝このタスク**）
9. ⚠ **測るのは「素材の収支」と「Lv100までの周回数」の2つだけ。⚠ 戦闘の秒数と装飾の出目は後回し**（2026-08-25）

---

## 1. ⚠ このタスク：**測った数値を入れる**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階12の後半。⚠ 規模は未定（⚠ **§1-2 の答え次第**）。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **前の回が「測るだけ」で終わっており、⚠ 一覧が既にできている**（`EXEC_BALANCE_ECONOMY.md` §9-3）
- ⚠ **穴が3つ見つかっている**（§0-1 の 2・3・4）。⚠ **どれも数値では直らず、器か仕様の判断が要る**
- ⚠ **これが片付くと、残りは 段階13（SDキャラとアニメーション＝専用の会話）だけ**

### 1-1. ⚠ いまの実装（**2026-08-25に確認**）

| | 事実 |
|---|---|
| ⚠ **数値の置き場は3つ** | ⚠ **① `resources/balance/master/*.json`（設計役が直せる）／ ② `resources/balance/*.gd` の `@export` 既定値（**設計役が直せる**）／ ③ `.tres` に実際に書かれた行（**人間だけ**）** |
| ⚠ **`.tres` 13本のうち値の行を持つのは6本だけ** | ⚠ **`character_config` / `initial_state_config` / `pomodoro_config` / `protection_*` / `sound_config`。⚠ 残り6本（`adventure` / `equipment` / `part` / `research` / `shop` / `workshop`）は `script = ...` の1行だけ＝**効いているのは `.gd` の既定値**（⚠ **ズレ39**） |
| ⚠ **人間しか直せない数値は4件だけ** | ⚠ **`base_level_up_cost`（3）／ `cost_growth_per_level`（1.0）／ `level_up_material_id` ／ `initial_state_config.tres` の初期値**（⚠ **`initial_state` はセーブがあると読まれない**） |
| ⚠ **`master/*.json` を直すと既存セーブにも次の起動で反映される** | ⚠ **`_sync_research_tree_from_master()` / `_sync_recipes_from_master()` / `_sync_shop_from_master()` が流し込み直すため**（`AGENTS.md`「マスターデータと状態を同期する型」） |
| ⚠ **測る道具は `scenario=economy`** | ⚠ **直したあとに同じシナリオを回せば、⚠ 前後の数字を並べられる** |

### 1-2. ⚠ 先に聞くこと（**着手前**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **Lv100 の 160 時間をどう縮めるか**（§0-1 の 1） | ⚠ **`stage_2` の `training_material_1` を増やすのではなく、⚠ `cost_growth_per_level` を下げるか式を変える**（⚠ **人間しか直せない2行なので、⚠ 値を決めてもらってから設計役が `economy` で検算する形にする**）。⚠ **目安を先に決める：「Lv100 まで集中何時間か」** |
| **2** | ⚠ **`training_material_2..4` の出口をどうするか**（§0-1 の 2） | ⚠ **レベル帯で要求する素材を変える**（例：Lv1-25 は `_1`、26-50 は `_2`…）。⚠ **`level_up_material_id` が1件しか持てないので器の変更が要る。⚠ 消す選択肢もある** |
| **3** | ⚠ **`construction_material_4` の入口をどうするか**（§0-1 の 4） | ⚠ **`stage_3` の報酬に少量入れる**（⚠ **最小の変更。⚠ `stages.json` だけで済む**）。⚠ **周回ステージを作るのは規模が別物** |
| **4** | ⚠ **どこまでを1回でやるか** | ⚠ **①（数値だけ）を1回、②③（器の変更）を別の回に分ける。⚠ 「1タスク=1つの通し」を守る** |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`.tres` の4件は設計役が直せない。⚠ 値の一覧を人間に渡す形にする**（⚠ **`EXEC_BALANCE_ECONOMY.md` §9-3 (a) がその形**）
- ⚠ **`initial_state_config.tres` はセーブがあると読まれない**（⚠ **人間が直しても既存セーブには効かない**）
- ⚠ **`MasterDataLoader` が返す数値は必ず `float`。⚠ `int()` で包み忘れるとセーブに `.0` が乗る**（⚠ **数値を触る回なので今回いちばん踏みやすい**）
- ⚠ **数値を直したら `scenario=economy` を回し直して前後を並べる**（⚠ **「直したつもり」を残さない**）
- ⚠ **`E127`（`base_level_cap` 20 ＋ `level_cap_unlock` 8件×10 ＝ 100）を壊さない**（⚠ **研究のコストは直してよいが `effect_value` の合計は動かさない**）
- ⚠ **`scenario=drops` と `scenario=workshop` は「意図的に赤黄を出す」枝を持っている**（⚠ **平常値を変えないこと**）
- ⚠ **`recipes.json` / `research.json` / `shop.json` の分布を変えたら、⚠ `workshop` と `research` と `drops` の期待値の行も変わる**（⚠ **完了条件に「前の数字」を書き写さない**）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが39回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 4件（下の 34・37・38・39）。⚠ 次に見つけたものは 40 番。**

| # | ズレ | 直すなら |
|---|---|---|
| ⚠ **34** | ⚠ **`skill_schema.gd:330` のコメント「`of` を読まない source」は `scale_from` にしか当てはまらない。** ⚠ **`condition` は同じ source でも `of` が必須** | ⚠ **未着手。⚠ コメント側か、⚠ `condition` 側で `of` を任意にするか** |
| ⚠ **37** | ⚠ **`ja.csv` の再インポートの合図が「前の回のキー」を見ていた**（⚠ **`scenario=passives` の1行**） | ⚠ **その回のキーに差し替えて回避している**（今は `ui_research_category_workshop`）。⚠ **根治するなら「`ja.csv` の行数」と「翻訳の件数」を突き合わせる形にする** |
| ⚠ **38** | ⚠ **`GAME_DESIGN` 9-1 の作業場カテゴリに「変換レート」が残っている。⚠ 同じファイルの 9-3 と 2章（`:104`）が「変換は廃止・ショップに一本化」と書いており、⚠ 上げるレートが存在しない** | ⚠ **未着手。⚠ 9-1 の表の3つ目を消す** |
| ⚠ **39** | ⚠ **「数値は `.tres`（設計役は直せない）」が半分しか当たっていない**（§1-1）。⚠ **同じズレで「`_4` は月替わりショップだけ」も違う。⚠ `shop.json` に `weekly` / `monthly` のキーが無く `daily` しかない** | ⚠ **未着手。⚠ このファイルの §1-1 は既に実体に合わせて書いてある** |

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-25・実測の回）：⚠ `GAME_DESIGN` 4-1 の「周回ステージ」「スキップ周回」が実コードに1件も無かった。⚠ 仕様側を採ると「新ステージを作る回」に化けるため、⚠ 着手前に人間に聞いて見送った**（⚠ **作業場の回と同じ形で2回目**）。

### 2-3. ⚠ 定数は名前ではなく値を見る

⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_enemy"` ではなく `"alive_count_enemy"`。⚠ 名前を JSON に書いてロード時に赤3本・戦闘中に毎フレームの赤3886本を出した**（2026-08-25）。

### 2-4. ⚠ `@export` を改名すると `.tres` の値が黙って消える

⚠ **実例：`ChestScheduleEntry.chest_type`**（⚠ **`protection_*.tres` の7件が黙って空になる**）。
⚠ **`.tres` に行が無い `@export` は改名しても消えるものが無い**（§1-1）が、⚠ **画面と JSON が綴りを参照している**ので同じく改名しないこと。

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
- ⚠ **`debug_boot._economy_sources()` / `_economy_sinks()`**（⚠ **対になっている。⚠ 片方だけ直さないこと**）

### 2-7. ⚠ E / W の次番号

⚠ **`E129` まで使用済み → `E130` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-25確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | ⚠ **`C:\Users\admin\AppData\Roaming\Godot\app_userdata\pomodoro-heroes\logs\`**（⚠ **`user://`。⚠ プロジェクト直下ではない**）。`battle_last.jsonl`（戦闘のたびに上書き）／ `godot.log`（保持5本） |
| ⚠ **セーブの実体** | ⚠ **`...\app_userdata\pomodoro-heroes\saves\save_slot_0.json`**（⚠ **`user://saves/` の下。⚠ 直下ではない**） |
| ロード時の正常な出力 | `skills validated: 94 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ `items validated: 89 entries, 0 errors` ／ `runes validated: 25 entries, 0 errors` ／ `balance item refs validated: 0 errors` ／ `_sync_research_tree_from_master() -> 20 nodes` ／ `level cap validated: 20 + 80 (8 nodes) = 100, 0 errors` ／ `_sync_recipes_from_master() -> 3 recipes (unlocked=3, skipped=0)` ／ `_sync_shop_from_master('daily') -> 13 slots` |
| ⚠ **マスターは7本** | ⚠ **`items` / `stages` / `shop` / `research` / `recipes` / `chests` / `runes`**（⚠ **`characters` `enemies` は配下にフォルダを持つ。⚠ フォルダの中は `skills.json` / `nodes.json` / `passives.json` の3本**） |
| ⚠ **数値の置き場** | ⚠ **§1-1 の表。⚠ `.tres` に行があるのは6本だけ**（ズレ39） |
| ⚠ **レベル** | ⚠ **上限 100**（⚠ **`base_level_cap` 20 ＋ 研究 `level_cap_unlock` 8件 × 10**）。⚠ **`E127` が起動のたびに突き合わせる**。⚠ **式は `base + growth * (level - 1)`（`base=3` / `growth=1.0`）＝ Lv100 まで **5,148 個**／3キャラで **15,444 個** |
| ⚠ **スタミナ** | ⚠ **1周 5**（`adventure_config.gd`）。⚠ **入口はポモドーロのポーションだけ**（⚠ **集中25分で1個・1個 +50 ＝ 集中1分あたり0.4周**）。⚠ **時間で回復しない** |
| ⚠ **研究** | ⚠ **2ボード20ノード**（⚠ **ボード1＝12件・ボード2＝8件**）。⚠ **枝は `combat` / `chest` / `workshop`**。⚠ **効果は `level_cap_unlock` / `stat_boost_all` / `chest_draw_bonus` / `craft_speed_bonus` / `craft_slot_bonus` の5種類**。⚠ **総コスト 790 個**（`construction_material_1..4`） |
| ⚠ **作業場** | ⚠ **装飾のくじ3レシピ**（`craft_part_1..3`）。⚠ **投入は `decor_material_1..3` ×12。⚠ 30分/90分/3時間**。⚠ **`stage_3` のクリアで開く**。⚠ **キューは1本（研究で+1）** |
| ⚠ **パッシブ** | ⚠ **本番3キャラ × 5件＝15件。⚠ Lv20/40/60/80/100 で解放。⚠ 解放されたものが全部効く（選ばない）** |
| ⚠ **`condition` の書き方** | ⚠ **`source` に書けるのは 10軸 ＋ `hp_current` `hp_lost` `hp_ratio` `hp_lost_ratio` `elapsed_sec` `alive_count_ally` `alive_count_enemy` `wave_index` `stack` `status_has`**（⚠ **`distance` は除く**）。⚠ **`of` は必ず書く**（⚠ **ズレ34**） |
| ⚠ **`react` の出来事** | ⚠ **`attacked` / `dealt_damage` / `took_damage` の3つだけ** |
| ⚠ **素材** | ⚠ **16件**。`construction_` / `training_` / `forging_` / `decor_` × `_1..4`。⚠ **入口が無いものは0件。⚠ 出口が無いものが4件**（`training_material_2..4` / `decor_material_4`） |
| ⚠ **装備の等級** | ⚠ **1〜10**。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]`。⚠ **コストは `[8,12,16,20,24,28,32,36,40]`** |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`** |
| ⚠ **装飾** | ⚠ **61件**（宝石12・護符8・紋章16 ／ ルーン25）。⚠ **くじに入るのは前の36件だけ**。⚠ **段階上げは `[10,20,40]`・壊すと `[3,5,10,20]`** |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **書く口は `set_party_member()` の1本** |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス**。⚠ **報酬は 50 / 80 / 120 G。⚠ 宝箱は3割の周でしか出ない**（⚠ **周回ステージもスキップ周回も無い＝宿題49**） |
| ⚠ **ショップ** | ⚠ **`daily` の13枠だけ**（⚠ **`shop.json` に `weekly` / `monthly` のキーが無い＝ズレ39**）。⚠ **`_4` 系の素材はここでしか買えない**（x3 を 5000G・在庫1） |
| ⚠ **画面の解放** | ⚠ **`stage_1` → `guild` `equipment` `training` `warehouse` ／ `stage_2` → `pomodoro` `decoration` ／ `stage_3` → `research` `shop` `rune` `workshop`** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「ゴールド・ジェム・スタミナ」「素材を全種類」「消費アイテムを全種類」「装備を全種類 1個ずつ」「装飾を全種類」「研究を全部解放」「画面を全部解放」「製作をすぐ完了させる」「セーブする」** |
| 行数 | `game_manager` **約5200** ／ `battle_controller` **約1800** ／ `debug_boot` **約2800** ／ `master_data_loader` **約1350** |

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
- ⚠ **今あるシナリオ（31本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / `runes` / `unlock` / `passives` / `research` / `workshop` / ⚠ **`economy`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝30本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` / `unlock` / `research` / `workshop` / `economy` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`economy` は数値を直したら必ず回す**（⚠ **前後の数字を並べる唯一の道具**）
  - ⚠ **`_economy_sources()` と `_economy_sinks()` は対。⚠ 入口か出口を1つ足したら両方を見る**
  - ⚠ **末尾の宿題43の枝は状態を丸ごと入れ替える。⚠ 何かを足すならその前に置くこと**
- ⚠ **`layout` は「はみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **排他で切り替わる器・段階解放で消える器は `LAYOUT_SCENE_SHOW` に1行足す**
  - ⚠ **測るのは一番外側の `Container`。⚠ ルートを測ると必ず 0 が返る**（ズレ36）
  - ⚠ **基準は `SCREEN_SIZE`（1280 x 720）。⚠ ヘッドレスの viewport（1280 x 1280）を使わないこと**
  - ⚠ **`ScrollContainer` の中は測れない**（⚠ **縦は人間しか見られない**）
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**（⚠ **どちらも意図的に壊している**）
- ⚠ **赤の平常値は 0本。⚠ ただし `unlock` は 1本（`E125`）・`workshop` は 2本（`E129`）出るのが正解**
- ⚠ **`ja.csv` を触った回は、⚠ 再インポートが済むまで研究画面の効果が「？」になる。⚠ 済んだかは `scenario=passives` の `ja.csv の再インポート:` の1行で分かる**
  - ⚠ **合図が見るキーは、⚠ その回に足したキーへ必ず差し替えること**（⚠ **ズレ37。⚠ 今は `ui_research_category_workshop`**）
- ⚠ **1本あたり10〜20秒。⚠ 30本で9分ほど。⚠ 10本ずつ3回に分けて回すこと**（⚠ **PowerShell ツールの既定タイムアウトは2分。⚠ `timeout` を伸ばすこと**）
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
  - ⚠ **報告の枝は `_ready()` の `elif` にも1行要る**（⚠ **`REPORT_*` の定数と合わせて3箇所**）
  - ⚠ **関数を足すときは、⚠ 差し込む先の関数が「次の `func` までどこまでか」を見てから**
- ⚠ **足した検証が本当に効くか、2箇所で壊して確かめる。⚠ 壊したら必ず戻し、平常値に戻ったことを再実行で確認する**
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **ただし Autoload が読まれないため `Identifier not found: GameManager / Balance / SceneManager` は必ず出る。⚠ これは無視してよい**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 全シナリオを回している最中にコードを触らない

⚠ **2026-08-23に `game_manager.gd` を編集し、赤560本の偽陽性を出した。**
→ ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない。⚠ `.md` はよい。**

### ⚠ 測る道具が「0」や「全部同じ数字」を返したら、まずその道具を疑う（**2026-08-25に2回目**）

⚠ **1回目**：⚠ `scenario=layout` が6シーンとも `最小幅 0` を返していたのに流した（ズレ36）。
⚠ **2回目**：⚠ **ギルドが `72 x 72` を返していた。⚠ 段階解放で5個とも `visible = false` のため、⚠ 見出しと戻るだけを測っていた。**
→ ⚠ **もっともらしい小さい数字を信じない。**
→ ⚠ **`economy` はこの形に対して「Lv1 の突き合わせ 実装 3 / 式 3 -> 一致」の1行を持っている。⚠ 同じ形の検証を新しい道具にも入れること。**

### ⚠ 既存の器を「そのまま呼ぶ」前に、中に何が乗っているか見る（**2026-08-25**）

⚠ **`_roll_chest_draw()` の中に `get_research_chest_draw_bonus()` が入っていた。⚠ 作業場のくじからそのまま呼んでいたら、⚠ 宝箱の研究が作業場にも黙って効いていた**（⚠ **赤も黄も出ない**）。
→ ⚠ **抽選の本体を `_roll_weighted_table()` に切り出し、⚠ ボーナスは呼ぶ側に置いた。**
→ ⚠ **`economy` も同じ理由で「研究0件のとき」を先に測ってから解放している。⚠ 順番を入れ替えると素の値が二度と取れない。**

### ⚠ 上限を返す関数が、その時点の状態を見ていることがある（**2026-08-25**）

⚠ **`get_effective_level_cap()` は研究を解放するまで 20 を返す。⚠ そのまま「Lv100 までの表」を作ると「Lv20 までの表」になる。**
→ ⚠ **上限で測りたいときは `Balance.character.max_character_level` を使う。**

### ⚠ 「済んだか」を見る合図は、その回のものを見ているか確かめる（**2026-08-25**）

⚠ **`ja.csv` の再インポートの合図が、⚠ 前の回に足したキーを見たままだった**（ズレ37）。

### ⚠ 画面の完了条件に「待つ」を書かない（**2026-08-25**）

⚠ **作業場の回で「30分待つ」を書き、人間の確認がそこで止まった。**
→ ⚠ **待ち時間のある機能は、`F4` に飛ばすボタンを同じ回で用意する**（⚠ **「製作をすぐ完了させる」がその答え**）。

### ⚠ 検証で在庫を「減らすために操作を繰り返す」書き方をしない

⚠ **2026-08-24**：⚠ **`while count > 1: merge_runes()` が150回回り、出力が数万行になった。**
→ ⚠ **在庫を整えるときは一度に配る／一度に減らす。**
→ ⚠ **同じ理由で `economy` は `level_up_character()` を99回回さず、式を直接99回評価している。**

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

### ⚠ 人間の判断待ち（**このタスクで効くもの**）

1. ⚠ **Lv100 が集中 160.9 時間**（宿題45）。⚠ **元は `character_config.tres` の2行＝人間しか直せない**
2. ⚠ **`training_material_2..4` に出口が無い**（宿題46）。⚠ **器の変更が要る**
3. ⚠ **`decor_material_4` に出口が無い**（宿題47）。⚠ **装飾の段階が4止まり**
4. ⚠ **`construction_material_4` の入口が daily ショップだけ**（宿題48）。⚠ **研究55個＝19日＋91,667G**
5. ⚠ **`GAME_DESIGN` 4-1 の周回ステージ・スキップ周回が実装に無い**（宿題49）
6. ⚠ **①戦闘の秒数と装飾の出目を測っていない**（宿題50）
7. ⚠ **マスターファイルが7本目になった** ／ ⚠ **キャラのフォルダも3本目になった**
8. ⚠ **`W16`（知らない欄）を赤に上げるか** ／ ⚠ **godot MCP の設定を消すか** ／ ⚠ **`tests/` の既存9件の棚卸し** ／ ⚠ **Ziva の `.bak` が7件残っている**
9. ⚠ **`ja.ja.translation` が縮んだ理由が不明**（⚠ **再インポートで作り直される。⚠ どのコミットにも含めていない**）

### ⚠ 器の穴（**大きいものだけ**）

10. ⚠ **ルーンのかけらが無い** ／ ⚠ **ルーンの本番入手経路が無い**（`F4` だけ）
11. ⚠ **`GROWTH_PASSIVES`（状態）とキャラプリセットの `passives` が、誰も読まない欄として残っている**
12. ⚠ **`crafting_queue` の `output_item_id` / `recipe_type` が `draw` レシピでは `""` になる**（⚠ **どちらも誰も読んでいない欄**）
13. ⚠ **作業場のアップグレードが無い** ／ ⚠ **掘削（9-3-1）はデモ範囲外**
14. ⚠ **`react` の中で `buff` / `heal` を出す形が本番に0件** ／ ⚠ **`host: point` が本番に0件**
15. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない** ／ ⚠ **`party_changed` シグナルが無い**
16. ⚠ **等級10の「部位固有のパッシブ」が未実装** ／ ⚠ **護符が宝石と仕組み上同じ**
17. ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない** ／ ⚠ **パッシブが戦闘画面のどこにも一覧で出ない**
18. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
19. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
20. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
21. ⚠ **オーラの範囲が画面に描かれない** ／ ⚠ **状態の色が3つしかない** ／ ⚠ **状態の残り時間がマスに出ない**
22. ⚠ **研究にゴールド払いが無い**（⚠ **`GAME_DESIGN` 9-1 は「ゴールドと各種資源」と言っている**）
23. ⚠ **研究の宝箱枝が「抽選回数」だけ**（⚠ **ドロップ率・高等級の確率＝`weight` に乗る効果が無い**）／ ⚠ **ボードは2枚しか無い**

### ⚠ 数値が全部「勘」（**このタスクの本体**・一覧は `EXEC_BALANCE_ECONOMY.md` §9-3）

24. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**（⚠ **`equipment_config.gd`＝設計役が直せる**）
25. ⚠ **装飾の `part_base` / `part_roll_max` 72個** ／ ⚠ **段階上げ `[10,20,40]` と壊す `[3,5,10,20]`**（⚠ **`part_config.gd`＝設計役が直せる**）
26. ⚠ **ルーンの CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ ロック秒 ／ 重ねる個数**
27. ⚠ **パッシブ15件の効果量** ／ ⚠ **研究20件の効果量とコスト**（⚠ **合計 790 個**）
28. ⚠ **宝箱の中身と `weight`**（⚠ **ハズレが 70 ＝ 3割しか出ない**）
29. ⚠ **作業場のくじ**（⚠ **投入12個 ／ 30分・90分・3時間 ／ 重み 10/3/2**）
30. ⚠ **ショップの価格13枠** ／ ⚠ **装備の `equip_stats`**
31. ⚠ **レベルアップの式と係数**（⚠ **`character_config.tres` の2行＝人間しか直せない**）

### ⚠ 表示の穴

32. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
33. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**
34. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
35. ⚠ **`weapon_steel_sword` がどこからも出ない** ／ ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**
36. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（意図的）

### 片付け

37. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
38. ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**
39. ⚠ **`ui_skill_select_passive_slot` と `ui_skill_select_passive_candidates_header` の2行が未使用**
40. ⚠ **共有部品 `BuildPresetRow` を作れていない**（⚠ **育成と装備に同じ行が2本ある**）
41. ⚠ **`pomodoro_config.gd` の `gold_per_focus_minute` / `stamina_per_focus_minute` / `materials_per_focus_minute` が誰も読まない欄**（⚠ **報酬はポーションと宝箱の経路に一本化されている**）

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **数値を直したら `scenario=economy` を回し直し、⚠ 前後の数字を EXEC に並べる。**
⚠ **これが終わると、残りは 段階13（SDキャラとアニメーション＝専用の会話）だけ。**
