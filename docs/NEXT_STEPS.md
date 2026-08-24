# 次にやること：**⑧ ルーン**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **仕様は `GAME_DESIGN.md` 7-7 にまとまっている。⚠ 人間に聞くのは §1-2 の3件だけ。**

---

## 0. 前のタスクは終わっている（**2026-08-23・パーティ選択画面とプリセット**）

**指示書は `docs/02_exec/EXEC_PARTY_PRESETS.md`。** ⚠ **ログ・ファイルの完了条件は通っている。⚠ 画面（§11-C の15項目）は人間の確認待ち。**

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **宝箱の1本化** | ⚠ **`chests.json` を新設**（マスター6本目・7件）／ ⚠ **`GameManager.grant_chest()` が積む唯一の口** ／ ⚠ **`E121` `E122` `W20`** |
| **作業場の廃止** | ⚠ **`recipes.json` が 14件 → 0件** ／ ⚠ **ギルドの「作業場」ボタンを `visible = false`** ／ ⚠ **画面もコードも消していない**（`GAME_DESIGN` 9-3 で復活予定） |
| **プリセット** | ⚠ **2階層・参照方式**（`character_presets` ＋ `party_presets`）／ ⚠ **専用画面 `scenes/adventure/party_preset_screen`** ／ ⚠ **入口は冒険選択と拠点の2つ** ／ ⚠ **E/W は増えていない** |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）
2. ⚠ **`target.range` は触らない**
3. ⚠ **素材IDは `<系統>_material_<1..4>` で固定**（2026-08-23）
4. ⚠ **状態の色は3つだけ。⚠ デバフも青**
5. ⚠ **作業場は「廃止だけ」で通した。⚠ 画面とコードは残す**（2026-08-23）
6. ⚠ **鍛冶のコストは式ではなく数値の配列** ／ ⚠ **分解は半分しか返さない**
7. ⚠ **プリセットは2階層**（2026-08-23。⚠ **口頭の「10個・メンバー/スキル枠/装備」は平坦に読めたが、⚠ `GAME_DESIGN` 5-5 の2階層で通した。⚠ 「10個」＝編成プリセットの数**）
8. ⚠ **キャラプリセットが持つのは 5-5 の4項目全部**（⚠ **割り振り・スキル枠・パッシブ枠・装備。⚠ ルーンの移動量が5つ目として入る**）
9. ⚠ **プリセットは装備も持ち、適用で着け替わる**（⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED = true`。⚠ `GAME_DESIGN` 5-5 と一致**）
   - ⚠ **この欄は2026-08-23に2回動いた**：⚠ **「装備プリセットはいったんやめる」で `false` → 実機で触ったあと「装備にも適用がいる」で `true` に戻した**。⚠ **定数と分岐を残してあるのはそのため**（⚠ **落ち着いたら消してよい。宿題**）
   - ⚠ **装備の取り合いは「奪う」＋何を動かしたか画面に出す**（⚠ **編成の3人の間で移るぶんは出さない**）
10. ⚠ **プリセットは「現在の状態を焼く」形。⚠ 中身を1項目ずつ編集する画面は作らない**（2026-08-23）
11. ⚠ **編成プリセットの「保存」は、参照先のビルドが空ならその場で焼く**（2026-08-23。⚠ **既に保存済みのビルドは触らない。⚠ これが無いと `ui_party_preset_ref_unsaved` で行き止まりになる**）
12. ⚠ **ビルドは育成画面・装備画面から「焼く」「適用」できる**（2026-08-23。⚠ **編成プリセットは3人まとめて当てる口で、⚠ 1人だけ当て直す口が別に要った**）
    - ⚠ **「焼く」と「適用」は向きが逆**（焼く＝現在→ビルド ／ 適用＝ビルド→現在）。⚠ **1つのボタンにまとめないこと**

---

## 1. ⚠ このタスク：**ルーン**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階8。⚠ 仕様の正は `GAME_DESIGN.md` 7-7。⚠ 依存の 3・4・7 は全部揃った。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **段階12（バランス実測）の唯一の未達依存がこれ**（`PLAN_IMPLEMENTATION.md:121`）
- ⚠ **移動量の置き場（キャラプリセット）が段階7で入った**（`GAME_DESIGN` 7-7「設定はキャラプリセットに含める」）。⚠ **これが無いままだと作り直しになるので、7 を先に通した**
- ⚠ **枠は既に開いている。何も刺さらないだけ**（下の §1-1）

### 1-1. ⚠ いまのルームの実装（**器はあるが中身が0件**）

| | 事実 |
|---|---|
| ⚠ **`part_kind: "rune"` のアイテムが0件** | ⚠ **`items.json` に1件も無い。⚠ 装飾は36件あるがルーンは0** |
| ⚠ **枠は開く** | ⚠ **`_part_slot_kinds()`（`game_manager.gd:2071`）。⚠ 武器＝位置2がルーン ／ アクセ＝位置2と3がルーン ／ 防具＝位置2がワイルド（ルーンは受けない）** |
| ⚠ **開く等級** | ⚠ **`PartConfig.part_slot_min_grades = [3,4,5,5,6,7,8,9]`。⚠ ルーン枠が開くのは等級5** |
| ⚠ **`PART_KIND_RUNE` は定義済み** | `game_manager.gd:145`。⚠ **`master_data_loader.gd:325` の種類の一覧にも入っている** |
| ⚠ **強化の仕組みが違う** | ⚠ **宝石・護符・紋章は「分解方式」（`get_upgraded_part_id()` / `upgrade_part()`）。⚠ ルーンは「同じものを重ねる」で、⚠ ロールが無い**（`GAME_DESIGN` 7-7 の表） |
| ⚠ **`parts` の要素は `{item_id, roll}`** | ⚠ **ルーンは `roll` を持たない。⚠ 型をどうするか決めが要る**（§1-2 の1） |
| ⚠ **移動量の置き場** | ⚠ **キャラプリセットに5つ目のキーとして入る**（`character_presets.<id>[i]`）。⚠ **正規化は知らないキーを消さないので、足せば残る**（実測済み） |
| ⚠ **入手経路** | ⚠ **`GAME_DESIGN` 7-7 は「ポモドーロ報酬のレアな枠」。⚠ ポモドーロの宝箱4件は `chests.json` にあり、いまは固定報酬だけで抽選が無い** |
| ⚠ **かけら** | ⚠ **5段階を超えた分は「ルーンのかけら」になり、好きなルーンと交換できる。⚠ 器が無い** |

### 1-2. ⚠ 人間に聞くこと（**3件。⚠ 先に聞いてから書く**）

1. ⚠ **`parts` の要素の型を変えるか。** ⚠ **いまは `{item_id, roll}`。ルーンは `roll` が無く代わりに「段階（重ねた回数）」を持つ。⚠ `{item_id, roll}` のまま `roll` を 0 にして段階を `item_id` の連番で表すか、⚠ `{item_id, stack}` を足すか**（⚠ **`PLAN_IMPLEMENTATION.md:51` は「`parts` の要素の型が変わる」を唯一の破壊的変更と呼んでいる**）
2. ⚠ **ルーンを何件作るか**（⚠ **移動系だけか、挙動を変えるものも入れるか**）
3. ⚠ **かけらを今回作るか**（⚠ **入手が「ポモドーロのレア枠」なので、被りが出るまで時間がかかる。⚠ 後回しにできる**）

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`part_kind` で `if` を分岐させないこと**（`game_manager.gd:2070` の注記）。⚠ **種類を足すときに触るのは `_part_slot_kinds()` の表だけ、という設計になっている。⚠ ルーンは強化の仕組みが違うので、ここを崩しにいきたくなる**
- ⚠ **`get_part_reject_reason()` が刺せるかの判定を1本で持っている。⚠ 2本目を作らない**
- ⚠ **`upgrade_part()` は「3個消して1個」の分解方式。⚠ ルーンに流用しないこと**（`GAME_DESIGN` 7-7 の表で明確に別系統）
- ⚠ **移動量をキャラプリセットに足したら、⚠ `_normalize_presets_from_save()` に1行足す**（⚠ **今は「知らないキーを残す」だけで、⚠ 中身の検証はしていない**）
- ⚠ **移動量は戦闘が読む。⚠ どこから引くかを1本に決める**（⚠ **`get_battle_skills()` と同じ形で `GameManager` に口を作る**）
- ⚠ **ルーンは戦闘の挙動そのものを変える。⚠ 検証は `debug_boot` の `KIND_BATTLE` の枝で見る**（⚠ **`materials` / `parts` の `report` の枝では足りない**）
- ⚠ **`.tres` にIDを書く欄を増やしたら `_validate_balance_item_refs()`（E121）に1行足す**

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが28回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 0件。⚠ 次に見つけたものは 29 番。**

⚠ **直近で直したもの**：⚠ **ズレ26**（`AGENTS.md` の `PENDING_CHESTS` の行）／ ⚠ **ズレ27**（段階8の依存に 7 を足した）／ ⚠ **ズレ28**（⚠ **「`inventory` は `item_id` がキーなので装備の個体を区別できない」は誤り。⚠ 装備は `inventory` を通らず、⚠ 一意キーは `instance_id`**）。**3件とも解消済み。**

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-23・プリセットの回）：口頭の決定が「平坦な10個」に読めたが、⚠ `GAME_DESIGN` 5-5 は「2階層・参照方式」と書いていた。⚠ 着手前に確認して2階層で通した。⚠ 平坦で作っていたら丸ごと作り直しだった。**

### 2-3. ⚠ `@export` を改名すると `.tres` の値が黙って消える

⚠ **`.tres` は `@export` の変数名をそのままキーにして保存している。⚠ 改名すると旧キーは孤児になり、⚠ 赤も黄も出ない。**
⚠ **実例：`ChestScheduleEntry.chest_type` は改名しなかった**（⚠ **`protection_*.tres` の7件が黙って空になるため**）。

### 2-4. ⚠ 大きな範囲の文字列置換をしない

⚠ **2026-08-23に `game_manager.gd` で715行を丸ごと消した**（⚠ **`--check-only` の `Parse Error` 42件で気づいた**）。
→ ⚠ **`Edit` で1箇所ずつ当てる。⚠ 範囲置換をするなら、⚠ 置換前後の行数を必ず比べる。**

### 2-5. ⚠ 「同じ形の判定」が散っていたら1本に寄せる

今ある1本ものは：
- ⚠ **`BattleSession.find_unit()`** ／ **`battle_controller._all_units()`**
- ⚠ **`StatusRegistry.entries_for()`**
- ⚠ **`GameManager.get_forge_material_tier()`**（等級 → 段階）
- ⚠ **`GameManager.add_to_inventory()`**（装備の個体を作る唯一の口。`CLAUDE.md` 8番）
- ⚠ **`GameManager.get_part_reject_reason()`**（⚠ **刺せるかの判定。⚠ ルーンでもここを通す**）
- ⚠ **`GameManager.get_equip_reject_reason()`**（⚠ **着けられるかの判定。⚠ `equip_instance()` と `apply_party_preset()` の両方が通る**）
- ⚠ **`GameManager.grant_chest()`**（宝箱を積む唯一の口）／ **`_roll_chest_draw()`**（抽選）
- ⚠ **`GameManager.set_party_member()`**（⚠ **編成を書き込む唯一の口。⚠ プリセットもここを通っている**）
- ⚠ **`GameManager.get_party_candidates()`**（⚠ **編成の候補。⚠ 2画面が読む**）
- ⚠ **`GameManager._plan_build()` / `_write_build()`**（⚠ **ビルドを当てる判定と書き込み。⚠ 編成プリセット（3人）とキャラ単体の適用が両方ここを通る**）
- ⚠ **`GameManager.format_apply_report()`**（⚠ **適用結果の文面。⚠ 適用の口が3つ＝パーティ選択・育成・装備**）

### 2-6. ⚠ E / W の次番号

⚠ **`E122` まで使用済み → `E123` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。
⚠ **プリセットの回では E も W も増やしていない**（⚠ **参照が切れるのは分解と改名のときだけで、⚠ 正規化で毎回洗う形にしたため**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-23確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | `C:/Users/admin/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl`。⚠ **戦闘のたびに上書き** |
| ⚠ 出力パネル | `.../logs/godot.log`。⚠ **保持5本。⚠ 読む前に自分でヘッドレスを走らせない** |
| ロード時の正常な出力 | ⚠ **`skills validated: 79 entries, 0 errors, 1 warnings`**（黄1本は `skill_dbg_dot_odd`＝**出るのが正解**）／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ ⚠ **`items validated: 64 entries, 0 errors`** ／ ⚠ **`balance item refs validated: 0 errors`** ／ ⚠ **`_sync_recipes_from_master() -> 0 recipes`**（作業場の廃止で 0。正常）／ ⚠ **`_normalize_presets_from_save() -> 10 fixed`**（⚠ **新規開始で器を10件作るため。⚠ 2回目は 0 fixed**） |
| ⚠ **素材** | ⚠ **16件**。`construction_material_1..4` ／ `training_material_1..4` ／ `forging_material_1..4` ／ `decor_material_1..4` |
| ⚠ **装備の等級** | ⚠ **1〜10**（`Balance.equipment.max_equipment_grade`）。⚠ コストは `forge_cost_by_grade`（9個の配列）。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]` |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`**。⚠ **等級3/4＝宝石 ／ 5＝特別枠（武器＝ルーン／防具＝ワイルド／アクセ＝ルーン×2）／ 6/7＝護符 ／ 8/9＝紋章**。⚠ **位置3はアクセサリーだけ開く**。⚠ **刺さる種類は部位ではなく枠で決まる**（`get_part_slot_defs()`） |
| ⚠ **装飾** | ⚠ **36件**（宝石・護符・紋章 × 軸 × 段階1〜4）。⚠ **ルーンは0件**（⚠ **枠は開くが何も刺さらない。⚠ このタスク**） |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない**（`add_to_inventory()` が装備だけ別の枝に抜ける）。⚠ **`character_growth.<id>.equipment[slot]` に入るのも `instance_id`** |
| ⚠ **装備の入手経路** | ⚠ **ステージの抽選ドロップ**（`stage_1/2/3` の宝箱・当たり率30%）／ ⚠ **`F4` のデバッグパネル**。⚠ **ショップは0件・ポモドーロの宝箱も0件** |
| ⚠ **宝箱** | ⚠ **`chests.json` に7件**（ポモドーロ4＝固定 ／ 戦闘3＝抽選）。⚠ **積む口は `grant_chest()` の1本**。⚠ **`pending_chests` は `{instance_id, chest_id, source, obtained_at, opened, rewards}`** |
| ⚠ **プリセット** | ⚠ **2階層。⚠ `character_presets` ＝ `{character_id: [{saved, nodes, skills, passives, equipment} × 3]}` ／ `party_presets` ＝ `[{saved, slots: [{character_id, preset_index} × 3]} × 10]`**。⚠ **中身の4キーは `GROWTH_*` と共用**。⚠ **画面は `scenes/adventure/party_preset_screen`。⚠ 入口は冒険選択と拠点の2つ** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **`stages.json` の `party_id` では決まらない**。⚠ **書く口は `set_party_member()` の1本**（⚠ **プリセットもここを通る**） |
| ⚠ **研究** | ⚠ **5ノード・縦1列**（⚠ **`category` は無い。⚠ 作り替えは段階10**） |
| ⚠ 座標の定数 | **`GROUND_Y = 240` ／ 味方 `PARTY_BASE_X=200` `STEP=100` ／ 敵 `ENEMY_BASE_X=900` `STEP=100`** |
| ⚠ **射程の段** | ⚠ **`60`（前衛）／ `180`（中衛）／ `300`（後衛）／ `420`（最後衛）** |
| ⚠ スキル枠 | **`SKILL_SLOT_COUNT` は 2**。⚠ **パッシブ枠もある**（`PASSIVE_SLOT_COUNT` は 1。⚠ **本番キャラのパッシブは0件**） |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **本番の編成** | ⚠ **`party_default` ＝ 僧侶(180) / 弓(300) / 剣士(60)** |
| ⚠ **画像素材が0件** | ⚠ **`assets/images/` は `.gitkeep` だけ** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「素材を全種類」「装飾を全種類」「装備を全種類 1個ずつ」「研究を全部解放」「セーブする」** |
| 行数 | `game_manager` **約4600** ／ `battle_controller` 1753 ／ `debug_boot` **約1620** ／ `master_data_loader` 992 ／ ⚠ **`adventure_select` 約320** ／ ⚠ **`party_preset_screen` 324** |

```
battle_controller  … 入力と表示。ノードを触る唯一の層
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
- ⚠ **赤黄を数えるときは行頭で絞る**（`^(ERROR|WARNING)`）。⚠ **スタックトレースの続き行を拾って誤検知する**
- ⚠ **今あるシナリオ（25本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / ⚠ **`presets`** / ⚠ **`layout`** / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除くこと＝24本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`layout` は「横にはみ出していないか」を数字で見る唯一の道具**（⚠ **絵は取れないが寸法は取れる**）。⚠ **器を足した回・件数を増やした回は必ず回すこと**（⚠ **この事故は3回踏んでいる**）。⚠ **手書きした `.tscn` が開くかもここで見る**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**（関数の中に決め打ちしない）
  - ⚠ **`add_child()` を `call_deferred` にすること。** ⚠ **`_ready()` の中から足すと弾かれ、⚠ 赤が1本出るだけで「全部0」というもっともらしい数字が出る**（2026-08-23に踏んだ）
- ⚠ **`drops` は黄が1本多く出るのが正解**（`grant_chest("chest_that_does_not_exist")` を意図的に呼ぶ）
- ⚠ **1本あたり10〜20秒。⚠ 23本で7分ほど。分けて回すこと**
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
- ⚠ **足した検証が本当に赤を出すか、2箇所で壊して確かめる。⚠ 壊すのはメモリ上の状態にすること**（⚠ **`presets` がその形。⚠ データファイルを壊さないので `git diff` が最初から空のまま**）
- ⚠ **人間に渡す前に、全シナリオを1回ずつ回す**（`training` を除く23本）
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **`Identifier not found` は Autoload 未読み込みで構文エラーではない**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 口頭の決定と `GAME_DESIGN` が食い違って読めた

⚠ **§2-2。⚠ 着手前に確認する。⚠ `EXEC_SKILL_SELECT.md` §12-6 と同じ形の事故になりかけた。**

### ⚠ 大きな範囲の文字列置換で715行消した／`@export` の改名で `.tres` が黙って空になる

⚠ **§2-4 ／ §2-3。**

### ⚠ 新しい `class_name` は、エディタを1回通すまで認識されない

⚠ **参照する側を、⚠ 人間がエディタを通すまで書かない。⚠ 実装を前半・後半に割る。**
⚠ **確かめ方**：`grep -c "<クラス名>" .godot/global_script_class_cache.cfg`
⚠ **プリセットの回は `class_name` を作らなかったので割らずに済んだ。**

### ⚠ 件数を増やす回では、既存の器の型を先に見る

⚠ **3件の前提で組まれた `HBoxContainer` に12件入れて横に溢れた**（⚠ **`GridContainer` 4列に直した**）。
⚠ **2026-08-23にもう1回踏んだ**：⚠ **拠点の `NavigationButtons` の既存5個は全部 `size_flags_horizontal = 3` なのに、⚠ コードで足した6個目に付け忘れて文字がはみ出した**（⚠ **`.tscn` を触らずコードでノードを足すときは、⚠ 隣の兄弟の `size_flags` を必ず見ること**）。

### ⚠ 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。**（⚠ **`tests/` は例外。あちらは `print` が出口**）
⚠ **確率で起きるもの・操作で普通に起きるものに黄を出さない**（⚠ **例：装備を分解するとプリセットの参照が切れるが、⚠ これは正常系なので `push_warning` を出していない**）。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ `stages.json` だけトップレベルが半角スペース2つ／⚠ `recipes.json` は空なので半角スペース2つ）。`ja.csv`はUTF-8（BOMなし・LF）。

---

## 5. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここは判断待ちと大きい穴だけ。

### ⚠ 人間の判断待ち

1. ⚠ **マスターファイルが6本目になった**（`chests.json`）
2. ⚠ **射程の段のルールが `EXEC_BATTLE_LINEUP.md` にしか書いていない**
3. ⚠ **`W16`（知らない欄）を赤に上げるか**
4. ⚠ **godot MCP の設定を消すか** ／ **`tests/` の既存9件の棚卸し** ／ **Ziva の `.bak` が7件残っている**
5. ⚠ **`ja.ja.translation` が 20427 → 8631 バイトに縮んだ理由が不明**（⚠ **キーの欠落は無いことを実測で確認済み**）
6. ⚠ **作業場をいつ復活させるか** ／ ⚠ **素材の変換経路が消えたまま**

### ⚠ 器の穴（**大きいものだけ**）

7. ⚠ **ルーンが0件**（⚠ **このタスク**）／ ⚠ **かけらの器が無い**
8. ⚠ **本番キャラのパッシブが0件**（⚠ **枠と `get_battle_passives()` はある。⚠ 段階3の残り**）
9. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない**（上書きだけ）
10. ⚠ **`party_changed` シグナルが無い**（⚠ **編成を聞く画面が3つ目になったら足す**）
11. ⚠ **等級10の「部位固有のパッシブ」が未実装**（⚠ **枠ではないので別の仕組みが要る**）
12. ⚠ **護符が宝石と仕組み上同じ**（⚠ **軸で割って見分けている暫定。⚠ 回避が10軸に無い**）
13. ⚠ **購読は `host: unit` のみ** ／ ⚠ **`host: battle` は誰も読まない**
14. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
15. ⚠ **`stack` の5部品のうち上限だけ入れた**
16. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
17. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
18. ⚠ **オーラの範囲が画面に描かれない**
19. ⚠ **状態の色が3つしかない**（デバフが青）／ ⚠ **状態の残り時間がマスに出ない**
20. ⚠ **本番スキルに `react` と `host: point` が0件**
21. ⚠ **`W18` が未実測**

### ⚠ 数値が全部「勘」

22. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**
23. ⚠ **装飾の `part_base` / `part_roll_max` 72個 ＋ `part_config.tres` の7個**
24. ⚠ **宝箱の中身と `weight`**（⚠ **戦闘3件が全部30%で同じ**）
25. ⚠ **段階④の入口がショップだけ**

### ⚠ 表示の穴

26. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
27. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**（⚠ **`sort_order` ではない**）
28. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
29. ⚠ **`weapon_steel_sword` がどこからも出ない**
30. ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**（⚠ **改名すると `.tres` 7件が黙って空になる**）
31. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（⚠ **外のキャラから奪うときだけ出す。意図的**）

### 片付け

32. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` の45行 ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
33. ⚠ **フォルダを増やしたら定数に1行足す**（`CHARACTER_DIRS_REQUIRED` / `ENEMY_DIRS_*`）
34. ⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用のまま残っている** ／ ⚠ **`ja.csv` の `ui_guild_workshop*` 12行も残してある**

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **段階8 が入ると段階12（バランス実測）の依存が全部揃う。** ⚠ **段階3のパッシブ・段階9・段階10・段階11の後半 も未着手のまま。**
