# 次にやること：**⑩ 研究ボードの作り替え**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **仕様は `GAME_DESIGN.md` 9-1（研究）。⚠ 人間の決定はまだ無い。⚠ §1-2 の3件を先に聞くこと。**

---

## 0. ⚠ 前のタスクは終わっている（**2026-08-25・段階3の残り＝本番キャラのパッシブ**）

**指示書は `docs/02_exec/EXEC_CHARACTER_PASSIVES.md`。**
⚠ **ログ・ファイル・画面の全項目が通っている**（⚠ **画面は人間が実機で操作済み**）。
⚠ **`ja.csv` の再インポートも済んでいる。⚠ 黄は1本（`skill_dbg_dot_odd`）に戻った。**
⚠ **実機の `battle_last.jsonl` で、⚠ ヘッドレスでは証明できなかった項目が埋まった**（下の §0-3）。

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **ルーン** | ⚠ **`runes.json`＝マスター7本目・25件** ／ ⚠ **`SkillRuntime.cast()` をそのまま通る** ／ ⚠ **`E123` `E124`** |
| **機能の段階解放** | ⚠ **画面IDが8つ増えた** ／ ⚠ **引き金は `stages.json` の `unlocks`** ／ ⚠ **`E125`** |
| **パッシブ** | ⚠ **本番3キャラ × 5件＝15件** ／ ⚠ **`characters/<id>/passives.json` を3本新設**（⚠ **`_cache_skills` へマージ＝引き口は `get_skill()` の1本のまま**） ／ ⚠ **レベル上限 30 → 100** ／ ⚠ **`E126`** ／ ⚠ **`react` が本番に初めて2件入った** |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **作業場は「廃止だけ」で通した。⚠ 画面とコードは残す**（2026-08-23）
4. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
5. ⚠ **ルーンの中身は `runes.json`（マスター7本目）に置く**（2026-08-24）
6. ⚠ **移動系ルーンは瞬間移動＋「秒でロック」**（`rune_move_lock_sec` = 1.2）
7. ⚠ **解放の単位は画面IDを増やす ／ 閉じている機能は「出さない」 ／ 引き金はステージのクリア**（2026-08-24）
8. ⚠ **パッシブは選ばない。⚠ 解放されたものが全部効く**（2026-08-25。⚠ **`PASSIVE_SLOT_COUNT` は 1 のまま残っているが誰も読まない**）
9. ⚠ **レベル100まで上げられるようにする。⚠ 既存の数値を変えるだけ**（2026-08-25。⚠ **`base_level_cap` 20 ＋ 研究4件 × 20 ＝ 100。⚠ このタスクで研究を作り替えると、⚠ この計算が崩れる。§1-3**）
10. ⚠ **パッシブの定義は `characters/<id>/passives.json`**（2026-08-25）
11. ⚠ **スキル画面のパッシブ行は「選べない一覧」**（2026-08-25）

### 0-3. ⚠ 実機で取れたもの（**2026-08-25・人間が `stage_3` を5ウェーブ完走**）

| 取れたもの | 中身 |
|---|---|
| ⚠ **剣士（Lv60）に3件付いた** | `whetstone` / `last_wall` / `thorn_mail`。⚠ **弓と神官は Lv20 未満で0件＝正常** |
| ⚠ **`thorn_mail` の反撃が 56回発火** | ⚠ **`react` が実戦で効いている** |
| ⚠ **`last_wall`（HP半分以下）が `true` 6回 / `false` 7回** | ⚠ **ヘッドレスでは条件が成立せず証明できなかった項目**（`EXEC_CHARACTER_PASSIVES` A-6） |
| ⚠ **各パッシブが x5（ウェーブごとに付け直し）** | ⚠ **`status_clear` のあと `_step_passives()` が張り直す正常な形。⚠ 積み上がっていない** |

### 0-4. ⚠ 育成画面を2カラムにした（**2026-08-25・人間が実機で見つけた縦のはみ出し**）

⚠ **`DetailPanel` が `VBoxContainer` → `HBoxContainer`（`InfoColumn` ＋ `ActionColumn`）。**
⚠ **左＝名前・レベル・ステータス10軸・コスト・案内 ／ 右＝ボタン7段（プリセット行を含む）。**
⚠ **原因は `stats_label` が10軸を `"
".join()` で1行ずつ入れていること**（⚠ **テキスト15行＋ボタン7段が1本の `VBox` に縦積み**）。
⚠ **`@onready` の10本と `_build_preset_row()` の差し込み先が `ActionColumn` に変わった。**

## 1. ⚠ このタスク：**研究ボードの作り替え**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階10。⚠ 仕様の正は `GAME_DESIGN.md` 9-1。⚠ 規模は「中」。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **残りは 段階10（これ）／ 段階11の後半（作業場）／ 段階12（バランス実測）だけ**
- ⚠ **段階12 は依存（5・6・8）が全部揃っており、⚠ パッシブが入って戦闘の中身も出揃った。⚠ いつでも始められる**
- ⚠ **研究は「レベル上限」を握っている器なので、⚠ 段階12（実測）より先に形を決めておくほうが安い**（⚠ **あとで刻みを変えると実測をやり直す**）

### 1-1. ⚠ いまの実装

| | 事実 |
|---|---|
| ⚠ **5ノード・縦1列** | ⚠ **`res_cap_1..4`（`level_cap_unlock`）＋ `res_stat_1`（`stat_boost_all`）。⚠ `category` の欄が無い** |
| ⚠ **上限は 20 ＋ 4×20 ＝ 100** | ⚠ **`character_config.gd` の `base_level_cap`（20）と `research.json` の `effect_value`（20 × 4件）。⚠ 2026-08-25 に 10 と 5 から変えた** |
| ⚠ **効果は2種類だけ** | ⚠ **`level_cap_unlock` / `stat_boost_all`**（`game_manager.gd`） |
| ⚠ **素材は1種類** | ⚠ **`construction_material_1` だけ。⚠ コストは 20 / 40 / 30 / 70 / 110** |
| ⚠ **マスターから流し込み直す型** | ⚠ **`_sync_research_tree_from_master()`。⚠ 進捗（`unlocked`）だけ残し、⚠ 効果値と前提は毎回上書き。⚠ JSONを直すと既存セーブにも次の起動で効く** |
| ⚠ **解放の口は1本** | ⚠ **`GameManager.unlock_research_node()`（前提と素材を判定する）** |
| ⚠ **`F4` に「研究を全部解放」がある** | ⚠ **`tests/debug_overlay.gd`。⚠ 素材を先に配らないと1件も解放されない** |

### 1-2. ⚠ 先に聞くこと（**着手前・3件**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **`category`（枝）を何本にするか。⚠ `GAME_DESIGN` 9-1 は「戦闘カテゴリ」と書いているが本数を決めていない** | ⚠ **3本**（⚠ **戦闘 / 生産 / 探索。⚠ キャラの割り振りが3枝なので形が揃う**） |
| **2** | ⚠ **効果の種類を増やすか**（⚠ **今は `level_cap_unlock` / `stat_boost_all` の2つだけ**） | ⚠ **増やす。⚠ ただし「既にある器に乗るもの」だけ**（⚠ **素材の取得量・製作時間・スタミナ上限など。⚠ 戦闘の挙動を変える効果は入れない＝スキルとパッシブと重なる**） |
| **3** | ⚠ **レベル上限の刻みをどうするか** | ⚠ **`level_cap_unlock` を4件より増やし、⚠ 1件あたりを小さくする**（⚠ **今は1件で +20 と粗い。⚠ ただし合計はちょうど 100 に保つこと。§1-3**） |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **レベル上限の合計を 100 からずらさない。** ⚠ **`base_level_cap`（20）＋ 全 `level_cap_unlock` の合計 ＝ `max_character_level`（100）。⚠ ずれるとパッシブの Lv100 が永久に解放されない**（⚠ **2026-08-25 に直したばかりの穴**）
- ⚠ **ノードIDを改名しない。** ⚠ **`_sync_research_tree_from_master()` はマスターから消えたIDの進捗を捨てる。⚠ 赤も黄も出ない**
- ⚠ **`_validate_balance_item_refs()`（E121）に1行足す**（⚠ **`.tres` にIDを書く欄を増やしたとき**）
- ⚠ **素材IDは `<系統>_material_<1..4>` で固定。⚠ 新しい素材を作らない**
- ⚠ **`scenario=layout` を必ず回す**（⚠ **ノードが5件から増えると研究画面が縦にも横にも伸びる**。⚠ **`LAYOUT_SCENES` に研究画面が入っているか先に見ること**）
- ⚠ **`F4` の「研究を全部解放」は前提を辿るループ。⚠ 枝が3本になっても素材が足りれば通る**（⚠ **`RESEARCH_MAX_PASSES` の値を確認すること**）
- ⚠ **`tests/debug_boot.gd` の `_apply_levels()` が研究を全解放して Lv100 まで上げている。⚠ 研究を作り替えるとここが通らなくなりうる**（⚠ **`scenario=passives` が最初に壊れる**）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが36回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 1件（下の 34）。⚠ 次に見つけたものは 37 番。**
⚠ **段階3（パッシブ）の回で4件見つかった**：

| # | ズレ | 直すなら |
|---|---|---|
| ⚠ **32** | ⚠ **実装は「パッシブを1枠から選ぶ」だったが、⚠ 仕様（`GAME_DESIGN` 5-2 / 5-4）は「解放されたものが全部効く」** | ⚠ **済**（⚠ **実装を仕様に寄せた。⚠ 仕様は1文字も変えていない**） |
| ⚠ **33** | ⚠ **デモの実効レベル上限が 30 しか無く、⚠ 仕様の Lv40/60/80/100 に永久に届かなかった** | ⚠ **済**（⚠ **20 ＋ 4×20 ＝ 100**） |
| ⚠ **34** | ⚠ **`skill_schema.gd:330` のコメント「`of` を読まない source」は `scale_from` にしか当てはまらない。** ⚠ **`condition` は同じ source でも `of` が必須で、⚠ 書かないと赤になる** | ⚠ **未着手。⚠ コメント側か、⚠ `condition` 側で `of` を任意にするか** |
| ⚠ **35** | ⚠ **`master_data_loader.gd` のコメントが「パッシブは `passives.json` に置く」と書いていた（旧ズレ31）** | ⚠ **済**（⚠ **実装をコメントに合わせた**） |
| ⚠ **36** | ⚠ **`scenario=layout` の `LAYOUT_SCENES` が6シーンとも `最小幅 0` を返していた＝横も縦も何も測れていなかった。** ⚠ **画面のルートが素の `Control` で、⚠ 子の `MarginContainer` はアンカー配置なので最小サイズが伝わらない。⚠ さらに基準がヘッドレスの viewport（1280 x 1280）で、⚠ 実機の 1280 x 720 と高さが違った** | ⚠ **済**（⚠ **一番外側の `Container` を測り、⚠ `SCREEN_SIZE`＝1280 x 720 を基準に縦横の両方を見る**） |

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-25・パッシブの回）：⚠ `NEXT_STEPS` §1-2 が「候補3件」を推奨していたが、⚠ `GAME_DESIGN` 5-4 は「1キャラ5個」だった。⚠ 着手前に気づいて5件で通した。**

### 2-3. ⚠ 定数は名前ではなく値を見る

⚠ **2026-08-25に踏んだ**：⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_enemy"` ではなく `"alive_count_enemy"`。⚠ 名前のほうを JSON に書いて、⚠ ロード時に赤3本・戦闘中に毎フレームの赤3886本を出した。**
→ ⚠ **`grep "const SCALE_" ` で右辺を見ること。**

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
- ⚠ **`GameManager.get_battle_skills()` / `get_battle_passives()` / `get_battle_runes()`**（⚠ **戦闘に渡す確定版。⚠ `get_battle_passives()` だけ枠を通らない＝解放済み全件**）
- ⚠ **`GameManager.unlock_research_node()`**（⚠ **研究の解放の唯一の口。⚠ このタスクで触る**）
- ⚠ **`MasterDataLoader.rune_skill_data()`** ／ **`_merge_character_files()`**（⚠ **キャラ別ファイルを読む唯一の口。⚠ `skills.json` と `passives.json` が通る**）

### 2-7. ⚠ E / W の次番号

⚠ **`E126` まで使用済み → `E127` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-25確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | ⚠ **`C:\Users\admin\AppData\Roaming\Godot\app_userdata\pomodoro-heroes\logs\`**（⚠ **`user://`。⚠ プロジェクト直下ではない**）。`battle_last.jsonl`（戦闘のたびに上書き）／ `godot.log`（保持5本） |
| ロード時の正常な出力 | ⚠ **`skills validated: 94 entries, 0 errors, 18 warnings`**（⚠ **黄18本のうち17本は `ja.csv` 再インポート待ち。⚠ 済めば1本に戻る**）／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ `items validated: 89 entries, 0 errors` ／ `runes validated: 25 entries, 0 errors` ／ `balance item refs validated: 0 errors` ／ `_sync_recipes_from_master() -> 0 recipes` ／ `_normalize_presets_from_save() -> 10 fixed`（新規開始。2回目は 0 fixed） |
| ⚠ **マスターは7本** | ⚠ **`items` / `stages` / `shop` / `research` / `recipes` / `chests` / `runes`**（⚠ **`characters` `enemies` は配下にフォルダを持つ。⚠ フォルダの中は `skills.json` / `nodes.json` / `passives.json` の3本**） |
| ⚠ **レベル** | ⚠ **上限 100**（⚠ **`base_level_cap` 20 ＋ 研究 `level_cap_unlock` 4件 × 20**）。⚠ **`max_character_level` も 100**。⚠ **育成素材は線形（`3 + 1.0×(level-1)`）で Lv100 まで約 5,148 個要る＝`GAME_DESIGN` 5-2 が「差し替える」と言っている式** |
| ⚠ **パッシブ** | ⚠ **本番3キャラ × 5件＝15件。⚠ Lv20/40/60/80/100 で解放。⚠ 解放されたものが全部効く（選ばない）**。⚠ **置き場は `characters/<id>/passives.json`。⚠ `_cache_skills` へマージされるので `get_skill()` で引ける**。⚠ **`react` は2件**（`passive_sw_thorn_mail` ＝ `took_damage` ／ `passive_ar_follow_through` ＝ `dealt_damage`） |
| ⚠ **パッシブの縛り** | ⚠ **`E74` `target.team` は `self` だけ ／ `E75` `stack` は `refresh` だけ ／ `E76` `trigger` は `cast` だけ ／ `host` は `unit` だけ ／ `stat` に `hp` は書けない ／ `cooldown_sec` `charge` `recast` `phases` は書けない** |
| ⚠ **`condition` の書き方** | ⚠ **`source` に書けるのは 10軸 ＋ `hp_current` `hp_lost` `hp_ratio` `hp_lost_ratio` `elapsed_sec` `alive_count_ally` `alive_count_enemy` `wave_index` `stack` `status_has`**（⚠ **`distance` は除く**）。⚠ **`of` は必ず書く**（⚠ **ズレ34**） |
| ⚠ **`react` の出来事** | ⚠ **`attacked` / `dealt_damage` / `took_damage` の3つだけ**（⚠ **`event:hit` は `trigger` 側の別の一覧**）。⚠ **反応先は `target: {"team": "source"}`** |
| ⚠ **研究** | ⚠ **5ノード・縦1列**（⚠ **`category` は無い。⚠ 作り替えがこのタスク**）。⚠ **効果は `level_cap_unlock` / `stat_boost_all` の2種類** |
| ⚠ **素材** | ⚠ **16件**。`construction_` / `training_` / `forging_` / `decor_` × `_1..4` |
| ⚠ **装備の等級** | ⚠ **1〜10**。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]` |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`** |
| ⚠ **装飾** | ⚠ **61件**（宝石12・護符8・紋章16 ／ ルーン25） |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない** |
| ⚠ **プリセット** | ⚠ **2階層。⚠ `character_presets` の5キー（`nodes` `skills` `passives` `equipment` `rune_move`）。⚠ `passives` は誰も読まない欄になった** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **書く口は `set_party_member()` の1本** |
| ⚠ 座標の定数 | **`GROUND_Y = 240` ／ 味方 `PARTY_BASE_X=200` `STEP=100` ／ 敵 `ENEMY_BASE_X=900` `STEP=100`** |
| ⚠ **射程の段** | ⚠ **`60`（前衛）／ `180`（中衛）／ `300`（後衛）／ `420`（最後衛）** |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「素材を全種類」「装飾を全種類」「装備を全種類 1個ずつ」「研究を全部解放」「セーブする」** |
| 行数 | `game_manager` **約5000** ／ `battle_controller` **約1800** ／ `debug_boot` **約2100** ／ `master_data_loader` **約1250** |

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
- ⚠ **今あるシナリオ（28本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / `runes` / `unlock` / ⚠ **`passives`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝27本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` / `unlock` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`runes` と `passives` は戦闘を回す**（⚠ **どちらも挙動を変えるので `report` では足りない**）
- ⚠ **`passives` は本番3キャラを Lv100 まで上げてから戦う**（⚠ **本番キャラを使う2本目のシナリオ。⚠ 1本目は `lineup`＝Lv1 のまま**）
- ⚠ **`layout` は「はみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **排他で切り替わる器（育成の「一覧」と「詳細」など）は `LAYOUT_SCENE_SHOW` に1行足す。⚠ 開いた直後の姿だけでは縦に長いほうを見逃す**
  - ⚠ **`add_child()` を `call_deferred` にすること**
  - ⚠ **測るのは一番外側の `Container`。⚠ ルートを測ると必ず 0 が返る**（ズレ36）
  - ⚠ **基準は `SCREEN_SIZE`（1280 x 720）。⚠ ヘッドレスの viewport（1280 x 1280）を使わないこと**
  - ⚠ **数字は下限。⚠ `_show_detail()` のような実行時に埋まるラベルはヘッドレスでは空のまま**（⚠ **育成の縦のはみ出しは、⚠ 道具を直したあとでも捕まらなかった。⚠ 実機でしか出ない**）
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**（⚠ **どちらも意図的に壊している**）
- ⚠ **赤の平常値は 0本。⚠ ただし `unlock` は 1本出るのが正解**（⚠ **`E125` を意図的に出している**）
- ⚠ **`ja.csv` を触った回は、⚠ 再インポートが済むまで黄が増え `layout` が赤を出す。⚠ 済んだかは `scenario=passives` の `ja.csv の再インポート:` の1行で分かる**
- ⚠ **1本あたり10〜20秒。⚠ 27本で9分ほど。⚠ 13〜14本ずつ2回に分けて回すこと**
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
- ⚠ **足した検証が本当に赤を出すか、2箇所で壊して確かめる**（⚠ **`presets` と `parts` はメモリ上の状態を壊す形。⚠ `E126` はマスターを一時的に壊して確かめ、⚠ 必ず戻して平常値に戻ったことを再実行で確認した**）
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **`Identifier not found` は Autoload 未読み込みで構文エラーではない**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 全シナリオを回している最中にコードを触らない

⚠ **2026-08-23に `game_manager.gd` を編集し、赤560本の偽陽性を出した。**
→ ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない。⚠ `.md` はよい。**

### ⚠ 測る道具が「0」や「全部同じ数字」を返したら、まずその道具を疑う

⚠ **2026-08-25**：⚠ **`scenario=layout` が6シーンとも `最小幅 0` を返していたのに、⚠ 「開いた」だけ見て流した。**
⚠ **横も縦も1回も測れていなかった**（ズレ36）。⚠ **その結果、育成画面の縦のはみ出しを人間が実機で見つけることになった。**
→ ⚠ **もっともらしい 0 を信じない。⚠ 前の回にも同じ形で踏んでいる。**

### ⚠ 定数は名前ではなく値を見る（**2026-08-25**）

⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_count_enemy"`。⚠ 名前を JSON に書いて赤3886本を出した。**

### ⚠ 「書かなくてよい欄」の話が、どの入口に効くのかを確かめる（**2026-08-25**）

⚠ **`SCALE_SOURCES_NO_OF` は「`of` を読まない source」と書いてあるが、⚠ それは `scale_from` の話（W12）。⚠ `condition` は同じ source でも `of` が必須。⚠ 落として赤を出した**（ズレ34）。

### ⚠ 人間しかできない作業は、済んだかを設計役が観測できる形にする

⚠ **`ja.csv` の再インポートも `.tres` の編集も設計役にはできない。⚠ そのままだと「やったつもり」で先に進む。**
→ ⚠ **`scenario=passives` に「再インポート: まだ／済んでいる」の1行を作った**（⚠ **`scenario=unlock` が `.tres` について同じことをしている**）。

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
⚠ **パッシブの回も `class_name` を作らなかったので割らずに済んだ。**

### ⚠ 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。**（⚠ **`tests/` は例外。あちらは `print` が出口**）

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ トップレベルだけ半角スペース2つのファイルが在る＝`stages.json` / `chests.json` / `runes.json`）。`ja.csv`はUTF-8（BOMなし・LF）。

---

## 5. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここは判断待ちと大きい穴だけ。

### ⚠ 人間の判断待ち

1. ⚠ **マスターファイルが7本目になった**（`runes.json`。⚠ **6本目＝`chests.json` の判断が未了のまま増えた**）／ ⚠ **キャラのフォルダも3本目になった**（`passives.json`）
2. ⚠ **射程の段のルールが `EXEC_BATTLE_LINEUP.md` にしか書いていない**
3. ⚠ **`W16`（知らない欄）を赤に上げるか**
4. ⚠ **godot MCP の設定を消すか** ／ **`tests/` の既存9件の棚卸し** ／ **Ziva の `.bak` が7件残っている**
5. ⚠ **`ja.ja.translation` が縮んだ理由が不明**
6. ⚠ **作業場をいつ復活させるか** ／ ⚠ **素材の変換経路が消えたまま**
7. ⚠ **Lv100 までの育成素材が約 5,148 個要る**（⚠ **線形式のまま。⚠ `GAME_DESIGN` 5-2 は「差し替える」と言っている。⚠ 段階12で効く**）

### ⚠ 器の穴（**大きいものだけ**）

0. ⚠ **どのステージで何が開くかが「勘」**（⚠ **9-5 の10段を4段に畳んである**）／ ⚠ **作業場が2箇所で閉じている**
8. ⚠ **ルーンのかけらが無い** ／ ⚠ **ルーンの本番入手経路が無い**（`F4` だけ）
9. ⚠ **`GROWTH_PASSIVES`（状態）とキャラプリセットの `passives` が、誰も読まない欄として残っている**（⚠ **消すとセーブの移行が要るので残した**）／ ⚠ **`PASSIVE_SLOT_COUNT` / `_slot_spec()` のパッシブの枝 / `get_selected_passives()` / `select_skill()` のパッシブ経路が画面から到達できない**
10. ⚠ **`react` の中で `buff` / `heal` を出す形が本番に0件**（⚠ **前例が `damage` → `target.team: "source"` だけ**）／ ⚠ **`host: point` が本番に0件**
11. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない**
12. ⚠ **`party_changed` シグナルが無い**
13. ⚠ **等級10の「部位固有のパッシブ」が未実装** ／ ⚠ **護符が宝石と仕組み上同じ**
14. ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない** ／ ⚠ **パッシブが戦闘画面のどこにも一覧で出ない**（⚠ **状態のマスに漢字が出るだけ**）
15. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
16. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
17. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
18. ⚠ **オーラの範囲が画面に描かれない** ／ ⚠ **状態の色が3つしかない**（デバフが青）／ ⚠ **状態の残り時間がマスに出ない**

### ⚠ 数値が全部「勘」

19. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**
20. ⚠ **装飾の `part_base` / `part_roll_max` 72個 ＋ `part_config.tres` の7個**
21. ⚠ **ルーンの CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ ロック秒 ／ 重ねる個数**
22. ⚠ **パッシブ15件の効果量**（⚠ **2026-08-25。⚠ 条件のしきい値も含む**）／ ⚠ **研究の上限ノードが1件 +20 と粗い**
23. ⚠ **宝箱の中身と `weight`**

### ⚠ 表示の穴

24. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
25. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**
26. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
27. ⚠ **`weapon_steel_sword` がどこからも出ない** ／ ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**
28. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（意図的）

### 片付け

29. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
30. ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**（⚠ **落ち着いたら消してよい**）
31. ⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用** ／ ⚠ **`ja.csv` の `ui_guild_workshop*` 12行も残してある**
32. ⚠ **`ui_skill_select_passive_slot` と `ui_skill_select_passive_candidates_header` の2行が未使用になった**（2026-08-25）
33. ⚠ **共有部品 `BuildPresetRow` を作れていない**（⚠ **育成と装備に同じ行が2本ある**）

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **残っているのは 段階11の後半（作業場）・段階12（バランス実測）。**
⚠ **段階12 は依存が全部揃っている。⚠ 戦闘の中身（スキル・パッシブ・ルーン・装飾）は出揃った。**
