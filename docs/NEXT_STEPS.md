# 次にやること：**⑨ 機能の段階解放**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **仕様は `GAME_DESIGN.md` 9-5（解放順）と 9-6（詰みの回避）。⚠ 人間の決定はまだ無い。⚠ §1-2 の3件を先に聞くこと。**

---

## 0. 前のタスクは終わっている（**2026-08-24・ルーン**）

**指示書は `docs/02_exec/EXEC_RUNES.md`。** ⚠ **ログ・ファイルの完了条件は通っている。⚠ 画面（§7-B の16項目）は人間の確認待ち。**

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **作業場の廃止** | ⚠ **`recipes.json` が 14件 → 0件** ／ ⚠ **画面もコードも消していない**（`GAME_DESIGN` 9-3 で復活予定） |
| **プリセット** | ⚠ **2階層・参照方式**（`character_presets` ＋ `party_presets`）／ ⚠ **専用画面 `scenes/adventure/party_preset_screen`** ／ ⚠ **入口は冒険選択と拠点の2つ** |
| **ルーン** | ⚠ **`runes.json` を新設**（⚠ **マスター7本目・25件**）／ ⚠ **`items.json` が 64 → 89件** ／ ⚠ **ルーンはスキルの直前に `SkillRuntime.cast()` を通る** ／ ⚠ **`E123` `E124`** |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **作業場は「廃止だけ」で通した。⚠ 画面とコードは残す**（2026-08-23）
4. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
5. ⚠ **「焼く」と「適用」は向きが逆。⚠ 1つのボタンにまとめない**
6. ⚠ **ルーンの中身は `runes.json`（マスター7本目）に置く**（2026-08-24。⚠ **設計役の推奨「`items.json` の欄」を覆した**）
7. ⚠ **移動系ルーンは瞬間移動＋「秒でロック」**（2026-08-24。⚠ **`PartConfig.rune_move_lock_sec` = 1.2**）
8. ⚠ **移動量は装備画面のルーン枠の行で選ぶ**（2026-08-24。⚠ **保存先はキャラプリセットの5つ目のキー `rune_move`**）
9. ⚠ **ルーンのかけらは作らない。⚠ 入手は `F4` だけ**（2026-08-24）

---

## 1. ⚠ このタスク：**機能の段階解放**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階9。⚠ 仕様の正は `GAME_DESIGN.md` 9-5 / 9-6。⚠ 規模は「小」。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **台帳が「器は早めに」と名指ししている**（`PLAN_IMPLEMENTATION.md` 3章の依存欄）。⚠ **後回しにするほど「全部 `true`」を前提にした画面が増える**
- ⚠ **段階12（バランス実測）の依存は 2026-08-24 に全部揃った**（5・6・8）。⚠ **順番を入れ替えて 12 を先にしてもよい。⚠ 判断は人間**
  - ⚠ **12 を先にする場合**：⚠ **実測は人間が遊ぶ必要があり、⚠ 解放順が入っていない状態＝全画面が最初から開いた状態で測ることになる**
- ⚠ **残りは 段階3のパッシブ（本番キャラが0件）／ 段階10（研究の作り替え）／ 段階11の後半（作業場の作り直し）**

### 1-1. ⚠ いまの実装（**器はあるが誰も閉じていない**）

| | 事実 |
|---|---|
| ⚠ **器は在る** | ⚠ **`GameStateKeys.UNLOCKED_SCREENS`（`state_keys.gd:25`）／ `GameManager.unlock_screen()`（`:542`）／ `is_screen_unlocked()`（`:549`）／ `screen_unlocked` シグナル** |
| ⚠ **起動時に全部 `true`** | ⚠ **`initial_state_config.tres` 由来。⚠ 閉じている画面が1つも無い** |
| ⚠ **画面IDは5つ** | ⚠ **`SCREEN_GUILD` / `SCREEN_ADVENTURE_SELECT` / `SCREEN_POMODORO` / `SCREEN_SETTINGS` / `SCREEN_SCENARIO`**（`state_keys.gd:234-238`） |
| ⚠ **9-5 の解放順は10段** | ⚠ **戦闘 → 装備 → 育成 → ポモドーロ → 装飾 → 研究 → ショップ → 拠点 → 作業場 → ルーン**。⚠ **画面IDの5つと1:1ではない**（⚠ **装備・育成・研究・ショップ・作業場は全部ギルドの中**） |
| ⚠ **`scenario_chapter` が無い** | ⚠ **`GAME_DESIGN` 9-5 は「`scenario_chapter` と紐づける」と書いているが、⚠ 状態にあるのは `story.current_chapter`** |
| ⚠ **作業場は入口を閉じてある** | ⚠ **`guild_screen.gd` が `visible = false`。⚠ 解放の仕組みとは別に閉じている**（⚠ **二重に閉じる形にしないこと**） |
| ⚠ **ルーンは 9-5 の最後** | ⚠ **装備画面のルーン枠の行を、⚠ 解放前は出さないのかどうかが未決**（§1-2 の2） |

### 1-2. ⚠ 先に聞くこと（**着手前・3件**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **解放の単位**。⚠ **画面ID（5つ）を増やしてギルドの中も個別に閉じるか、⚠ ギルドの中は別の仕組み（ボタンの活性）にするか** | ⚠ **画面IDを増やす**（⚠ **`ui_nav_` の綴り合わせが機械的に効く。⚠ `AGENTS.md`「`screen_id` と対応するキーは綴りを揃える」**） |
| **2** | ⚠ **閉じている機能を「見せて押せない」のか「出さない」のか** | ⚠ **出さない**（⚠ **9-5 の狙いは「順番に見せる」。⚠ 灰色のボタンが10個並ぶと最初の画面が最も複雑になる**） |
| **3** | ⚠ **何が解放の引き金か**。⚠ **`story.current_chapter` か、⚠ ステージのクリアか** | ⚠ **ステージのクリア**（⚠ **`story.stages.<id>.cleared` は既に在る。⚠ 章は本数が少なく刻めない**） |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`initial_state_config.tres` はセーブが在ると読まれない**（`AGENTS.md`「マスターデータと状態を同期する型」）。⚠ **既存セーブは全部 `true` のまま来る。⚠ 「新規開始だけ閉じる」のか「既存も閉じ直す」のかを決める**
- ⚠ **`SceneManager` は解放を見ていない。** ⚠ **閉じた画面へ直接遷移できてしまう経路が残る**（⚠ **`base_screen` のボタンを消しても、⚠ 戦闘結果やモーダルからの遷移が別に在る**）
- ⚠ **`UNLOCKED_SCREENS` を読んでいる画面がどれかを先に `grep` する**（⚠ **読んでいない画面が在ると、⚠ そこだけ閉じない**）
- ⚠ **`GAME_DESIGN` 9-6「詰みの回避」を同時に見る**（⚠ **閉じた結果、資源の入口が全部塞がる組み合わせを作らない**）
- ⚠ **`debug_overlay`（`F4`）は解放を無視して配る。⚠ そのままでよい**（⚠ **検証用**）
- ⚠ **`scenario=layout` を必ず回す**（⚠ **ナビのボタンが減ると器の幅が変わる。⚠ この事故は3回踏んでいる**）

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

⚠ **`E124` まで使用済み → `E125` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

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
- ⚠ **今あるシナリオ（26本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / ⚠ **`runes`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝25本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`runes` は戦闘を回す**（⚠ **ルーンは挙動を変えるので `report` では足りない**）
- ⚠ **`layout` は「横にはみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **`add_child()` を `call_deferred` にすること**
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**（⚠ **どちらも意図的に壊している**）
  - ⚠ **`ja.csv` を再インポートするまでは、⚠ さらに15本の黄が出る**（`ui_status_ch_st_rune_*` の3キー × 出てくる回数）。⚠ **再インポートは人間の作業**
- ⚠ **1本あたり10〜20秒。⚠ 25本で8分ほど。分けて回すこと**
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

7. ⚠ **ルーンのかけらが無い**（⚠ **段階5で重ねられない**）／ ⚠ **ルーンの本番入手経路が無い**（⚠ **`F4` だけ**）
8. ⚠ **本番キャラのパッシブが0件**（⚠ **枠と `get_battle_passives()` はある。⚠ 段階3の残り**）
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
⚠ **残っているのは 段階3のパッシブ・段階9・段階10・段階11の後半・段階12。⚠ 段階12 は依存が全部揃っている。**
