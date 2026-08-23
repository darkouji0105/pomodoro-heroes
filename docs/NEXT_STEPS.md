# 次にやること：**⑦ パーティ選択画面とプリセット**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **「何をやるか」も「どこまでやるか」も決まっている**（§1-0・§1-2）。⚠ **人間に聞くことは無い。**

---

## 0. 前のタスクは終わっている（**2026-08-23・作業場の廃止**）

**指示書は `docs/02_exec/EXEC_WORKSHOP_RETIRE.md`。** ⚠ **ログ・ファイルの完了条件は全部通っている。⚠ 画面（§4-D の5項目）は人間の確認待ち。**

### 0-1. ⚠ 直近3回で入ったもの（**全件は `PROJECT_STATUS.md`**）

| 回 | 入ったもの |
|---|---|
| **抽選ドロップ** | ⚠ **ステージの宝箱**（`EXEC_STAGE_DROPS`）／ ⚠ **重み＋抽選回数の形** ／ ⚠ **`E120` `W19`** |
| **宝箱の1本化** | ⚠ **`chests.json` を新設**（マスター6本目・7件）／ ⚠ **`GameManager.grant_chest()` が積む唯一の口** ／ ⚠ **`ChestContentConfig` を削除** ／ ⚠ **`E121` `E122` `W20`** |
| **作業場の廃止** | ⚠ **`recipes.json` が 14件 → 0件** ／ ⚠ **ギルドの「作業場」ボタンを `visible = false`** ／ ⚠ **`_sync_recipes_from_master()` の早期 return を外した** ／ ⚠ **画面もコードも消していない**（`GAME_DESIGN` 9-3 で復活予定） |

### 0-2. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）
2. ⚠ **`target.range` は触らない**
3. ⚠ **素材IDは `<系統>_material_<1..4>` で固定**（2026-08-23。⚠ **段階1を無印に戻す案は却下。⚠ `get_forge_material_id()` が「接頭辞＋段階」で組み立てているため**）
4. ⚠ **状態の色は3つだけ。⚠ デバフも青**
5. ⚠ **作業場は「廃止だけ」で通した**（2026-08-23。⚠ **中間素材も装飾のくじも作っていない**）
6. ⚠ **作業場の画面とコードは残す**（2026-08-23。⚠ **`GAME_DESIGN` 9-3 で復活予定。⚠ 掘削も `crafting_queue` を使う**）
7. ⚠ **鍛冶のコストは式ではなく数値の配列**
8. ⚠ **分解は半分しか返さない**
9. ⚠ **プリセットは10個・中身はメンバーとスキル枠と装備・専用画面を作る・切り替えは戦闘前でも拠点でも**（2026-08-23。⚠ **§1-2**）

---

## 1. ⚠ このタスク：**パーティ選択画面とプリセット**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階7。⚠ `GAME_DESIGN.md` 7-7 の末尾（「設定はキャラプリセットに含める」）。**

### 1-0. ⚠ なぜ次がこれなのか（**2026-08-23・人間が⑦で確定させた**）

⚠ **台帳では段階8（ルーン）が段階12（バランス実測）の唯一の未達依存**で、そちらが本命に見える。**それでも 7 を先に置いた理由：**

- ⚠ **`GAME_DESIGN` 7-7 が「移動系ルーンの移動量はキャラプリセットに含める」と書いている。** ⚠ **プリセットが無いままルーンを実装すると、移動量の置き場が無く作り直しになる**
- ⚠ **これは前回と同じ形の事故。** 前々回、⚠ **`GAME_DESIGN` 6-4 を読まずに枠を実装して丸ごと作り直しになった**
- ⚠ **段階7 は「中」・段階8 は「大」。** 小さいほうを先に通して、⚠ **大きいほうを1回で通す**

> ⚠ **台帳（`PLAN_IMPLEMENTATION.md` 3章）は段階8の依存を「3, 4」と書いており、7 が入っていない。** ⚠ **これはズレの可能性がある（§2-1 のズレ27）。⚠ 人間が「8を先」と決めるならそれでよい。**

### 1-1. ⚠ いまの編成の実装（**これを置き換える**）

| | 事実 |
|---|---|
| ⚠ **専用画面が無い** | ⚠ **`scenes/adventure/adventure_select.gd`（358行）の中にある。⚠ `_build_party_row()` が `OptionButton` を3つ並べているだけ** |
| ⚠ **枠の数** | ⚠ **`GameStateKeys.PARTY_SLOT_COUNT`**。⚠ **状態が唯一の正。⚠ `stages.json` の `party_id` では決まらない** |
| ⚠ **書き込む口** | ⚠ **`GameManager.set_party_member(slot_index, character_id)` の1本** |
| ⚠ **読む口** | ⚠ **`GameManager.get_party_members()`** |
| ⚠ **候補の並び** | ⚠ **`_collect_party_candidates()`。⚠ `characters.json` の記述順のまま。⚠ 検証用キャラを混ぜる分岐があり、リリース前に消す（宿題16）** |
| ⚠ **プリセットは0件** | ⚠ **状態にもマスターにも器が無い。⚠ `GameStateKeys` に該当の定数が無い** |
| ⚠ **本番の編成** | ⚠ **`party_default` ＝ 僧侶(180) / 弓(300) / 剣士(60)** |

### 1-2. ⚠ 人間の決定（**2026-08-23。⚠ 聞き直さない**）

⚠ **このタスクは仕様が `GAME_DESIGN` に1行しか無い。⚠ 以下は口頭で決まったもので、⚠ `GAME_DESIGN` には書かれていない。**

| # | 決定 |
|---|---|
| **1** | ⚠ **プリセットは10個**（⚠ **固定本数。⚠ 増やす仕組みは作らない**） |
| **2** | ⚠ **プリセットが持つのは「メンバー」「スキル枠」「装備」の3つ** |
| **3** | ⚠ **専用画面を作る**（⚠ **`adventure_select` の中を作り替えるのではない**） |
| **4** | ⚠ **切り替えは戦闘前でも拠点でもできる**（⚠ **どちらか片方ではない**） |

⚠ **新しいフォルダは作らない。** ⚠ **`scenes/adventure/` に置く**（`AGENTS.md` のフォルダ構造では「冒険選択・戦闘」。⚠ **1画面でしか使わないパーツは同じフォルダに置く**）。

⚠ **ルーンの移動量（段階8）はこの器に後から足す。** ⚠ **`GAME_DESIGN` 7-7 が「設定はキャラプリセットに含める」と書いているため、⚠ 4つ目の欄が入る前提で組むこと**（⚠ **今回は作らない**）。

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`_build_party_row()` は `queue_free()` + `remove_child()` の形になっている**（`adventure_select.gd:64-67`）。⚠ **`await` を持たせないこと**（`CLAUDE.md` 5番）
- ⚠ **`_party_candidates` は「`OptionButton` の項目番号 → `character_id`」の変換表。⚠ 項目番号をそのままIDに使わない**（`adventure_select.gd:141` の注記）
- ⚠ **プリセットを状態に足すなら `GameStateKeys` に定数を足し、⚠ `AGENTS.md`「GameManagerの状態構造」の表にも1行足す**（⚠ **前回この追記が漏れてズレ26になった**）
- ⚠ **プリセットに `character_id` を持たせると、⚠ IDの改名で黙って壊れる**（`CLAUDE.md` 4番）。⚠ **`_sync_*_from_master()` と同じ型で毎回洗うか、⚠ 検証（`E123`）を足すか決めること**
- ⚠ **「装備も持つ」（決定2）が一番重い。** ⚠ **装備は既に `character_growth[<id>].equipment` が持っている**（`{head, armor, legs, weapon, accessory}`）。⚠ **プリセット側にも持たせると二重管理になる。⚠ 「プリセットが正」ではなく「適用したときに `character_growth` へ書き込む」形にすること**
- ⚠ **装備の個体は1個ずつしか無い。** ⚠ **2つのプリセットが同じ装備を指せてしまう。⚠ 適用したときにどう振る舞うか（片方から外れる／弾く／黙って上書き）を先に決める。⚠ 状態を変える前に全部の判定を終えること**（`CLAUDE.md` 6番）
- ⚠ **装備を指すキーを決める。** ⚠ **`inventory` は `item_id` がキーで、⚠ 同じ `item_id` の個体が複数あると区別できない**（⚠ **`add_to_inventory()` の実装を先に読むこと。`CLAUDE.md` 8番**）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが26回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは3件**（⚠ **2026-08-23に見つけたもの。⚠ まだ直していない**）：

- ⚠ **ズレ24・25**（⚠ **このファイルの前の版の §1-3。⚠ 作業場の廃止で解消済み**）
- ⚠ **ズレ26 — `AGENTS.md`「GameManagerの状態構造」の `PENDING_CHESTS` の行。** ⚠ **表は `{chest_id, chest_type, ...}` だが実装は `{instance_id, chest_id, ...}`**（`state_keys.gd:96`）。⚠ **`chest_type` は `ChestScheduleEntry`（`.tres`）の `@export` 名であって状態のキーではない。⚠ 次に `AGENTS.md` を触る回で直す**
- ⚠ **ズレ27（未確定）— `PLAN_IMPLEMENTATION.md` 3章の段階8の依存に 7 が無い。** ⚠ **`GAME_DESIGN` 7-7 は「移動量はキャラプリセットに含める」と書いている**（§1-0）

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例：⚠ 6-4 を読まずに枠を実装して丸ごと作り直しになった。⚠ しかも「変えないもの」に台帳が「置き換えろ」と言っている値を書いて保護した。**

### 2-3. ⚠ `@export` を改名すると `.tres` の値が黙って消える

⚠ **`.tres` は `@export` の変数名をそのままキーにして保存している。⚠ `.gd` 側で改名すると旧キーは孤児になり、⚠ 新しい欄は既定値になる。⚠ 赤も黄も出ない。**
⚠ **実例：`ChestScheduleEntry.chest_type` は改名しなかった**（⚠ **`protection_*.tres` の7件が黙って空になり、加護の宝箱が一切もらえなくなるため**）。

### 2-4. ⚠ 大きな範囲の文字列置換をしない

⚠ **2026-08-23に `game_manager.gd` で「関数の頭から別の関数の頭まで」を置換し、⚠ 715行を丸ごと消した**（⚠ **`--check-only` の `Parse Error` 42件で気づいた**）。
→ ⚠ **`Edit` で1箇所ずつ当てる。⚠ 範囲置換をするなら、⚠ 置換前後の行数を必ず比べる。**

### 2-5. ⚠ 「同じ形の判定」が散っていたら1本に寄せる

今ある1本ものは：
- ⚠ **`BattleSession.find_unit()`** ／ **`battle_controller._all_units()`**
- ⚠ **`StatusRegistry.entries_for()`**
- ⚠ **`GameManager.get_forge_material_tier()`**（等級 → 段階）
- ⚠ **`GameManager.add_to_inventory()`**（装備の個体を作る唯一の口。`CLAUDE.md` 8番）
- ⚠ **`GameManager.get_part_reject_reason()`**（刺せるかの判定）
- ⚠ **`GameManager.grant_chest()`**（⚠ **宝箱を積む唯一の口。ポモドーロも戦闘もここを通る**）
- ⚠ **`GameManager._roll_chest_draw()`**（抽選）
- ⚠ **`GameManager.set_party_member()`**（⚠ **編成を書き込む唯一の口。⚠ プリセットもここを通すこと**）

### 2-6. ⚠ E / W の次番号

⚠ **`E122` まで使用済み → `E123` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-23確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **前々回この取り違えで1タスク溶けた**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | `C:/Users/admin/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl`。⚠ **戦闘のたびに上書き** |
| ⚠ 出力パネル | `.../logs/godot.log`。⚠ **保持5本。⚠ 読む前に自分でヘッドレスを走らせない** |
| ロード時の正常な出力 | ⚠ **`skills validated: 79 entries, 0 errors, 1 warnings`**（黄1本は `skill_dbg_dot_odd` の端数＝**出るのが正解**）／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ ⚠ **`items validated: 64 entries, 0 errors`** ／ ⚠ **`balance item refs validated: 0 errors`** ／ ⚠ **`_sync_recipes_from_master() -> 0 recipes (unlocked=0, skipped=0)`**（⚠ **作業場の廃止で 0 になった。正常**） |
| ⚠ **素材** | ⚠ **16件**。`construction_material_1..4`（木材/石材/鉄材/金材）／ `training_material_1..4`（修練/鍛錬/練達/極意の証）／ `forging_material_1..4`（鍛冶の欠片/塊/結晶/極）／ `decor_material_1..4`（飾り石/玉/晶/極） |
| ⚠ **素材が触れる場所**（**全部**） | ⚠ **`items.json` ／ `stages.json` の `rewards.materials` ／ `shop.json` ／ `research.json` ／ `chests.json` の `rewards.materials` と `draw`** ／ ⚠ **`recipes.json` は0件になったが枝は残っている** ／ ⚠ **`.tres` は `initial_state_config` ・ `character_config.level_up_material_id` ・ `research_config.unlock_material_id` ・ `shop_config.item_pool` の4つ** ／ ⚠ **`.gd` の直書きは `state_keys.gd` の `ITEM_FORGING_MATERIAL_PREFIX` と `ITEM_DECOR_MATERIAL_PREFIX` だけ**（⚠ **`E121` が全部見る**） |
| ⚠ **装備の等級** | ⚠ **1〜10**（`Balance.equipment.max_equipment_grade`）。⚠ コストは `forge_cost_by_grade`（9個の配列）。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]` |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `PartConfig.part_slot_min_grades = [3,4,5,5,6,7,8,9]`**。⚠ **等級3/4＝宝石 ／ 5＝特別枠（武器＝ルーン／防具＝ワイルド／アクセ＝ルーン×2）／ 6/7＝護符 ／ 8/9＝紋章**。⚠ **位置3はアクセサリーだけ開く**。⚠ **刺さる種類は部位ではなく枠で決まる**（`get_part_slot_defs()`） |
| ⚠ **等級10** | ⚠ **枠は開かない。⚠ 「部位固有のパッシブ」が開く予定だが未実装**（`GAME_DESIGN` 6-4） |
| ⚠ **装飾** | ⚠ **36件**（宝石・護符・紋章 × 軸 × 段階1〜4）。⚠ **ルーンは0件**（⚠ **枠は開くが何も刺さらない**） |
| ⚠ **装備の入手経路** | ⚠ **ステージの抽選ドロップ**（`stage_1/2/3` の宝箱・当たり率30%）／ ⚠ **`F4` のデバッグパネル**。⚠ **作業場のレシピ10件は廃止で消えた。⚠ ショップは0件・ポモドーロの宝箱も0件** |
| ⚠ **宝箱** | ⚠ **`chests.json` に7件**（ポモドーロ4＝固定 ／ 戦闘3＝抽選）。⚠ **積む口は `GameManager.grant_chest()` の1本**。⚠ **`pending_chests` は `{instance_id, chest_id, source, obtained_at, opened, rewards}`**（⚠ **`instance_id` が一意ID・`chest_id` が種類。⚠ `AGENTS.md` の表はズレ26で古い**） |
| ⚠ **レシピ** | ⚠ **0件**（⚠ **`{ "recipes": [] }`。⚠ 作業場は画面もコードも残っているが到達経路が無い**） |
| ⚠ **研究** | ⚠ **5ノード・縦1列**（⚠ **`category` は無い。⚠ 作り替えは段階10**） |
| ⚠ 座標の定数 | **`GROUND_Y = 240` ／ 味方 `PARTY_BASE_X=200` `STEP=100` ／ 敵 `ENEMY_BASE_X=900` `STEP=100`** |
| ⚠ **射程の段** | ⚠ **`60`（前衛）／ `180`（中衛）／ `300`（後衛）／ `420`（最後衛）** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **`stages.json` の `party_id` では決まらない**。⚠ **専用画面は無く `adventure_select.gd` の `_build_party_row()` の中にある**（⚠ **§1-1 に詳細**） |
| ⚠ スキル枠 | **`SKILL_SLOT_COUNT` は 2**。⚠ **パッシブ枠もある**（⚠ **本番キャラのパッシブは0件。検証用の `passive_dbg_*` だけ**） |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス** |
| ⚠ **本番の編成** | ⚠ **`party_default` ＝ 僧侶(180) / 弓(300) / 剣士(60)** |
| ⚠ **本番スキルの表示名** | ⚠ **剣士＝`強撃` / `横薙ぎ` ／ 僧侶＝`聖光`** |
| ⚠ **画像素材が0件** | ⚠ **`assets/images/` は `.gitkeep` だけ** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「素材を全種類」「装飾を全種類」「装備を全種類 1個ずつ」「研究を全部解放」「セーブする」** |
| 行数 | `game_manager` 3940 ／ `battle_controller` 1753 ／ `debug_boot` 1452 ／ `master_data_loader` 992 ／ ⚠ **`adventure_select` 358** |

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
- ⚠ **CR を数えるのに `grep -c $'\r'` を使わない**（⚠ **Git Bash では全行に誤ヒットする。⚠ `python -c "print(open(p,'rb').read().count(b'\x0d'))"` を使う**）
- ⚠ **警告とエラーは `-RedirectStandardError` のほう**（⚠ **`push_warning` / `push_error` は stdout に出ない**）
- ⚠ **赤黄を数えるときは行頭で絞る**（`^(ERROR|WARNING)`）。⚠ **スタックトレースの続き行（`at: push_warning ...`）を拾って誤検知する**
- ⚠ **今あるシナリオ（23本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 2026-08-23に10分回して確認した。⚠ 全シナリオを回すときは除くこと**）
- ⚠ **`materials` / `parts` / `drops` は戦闘を回さない**（`kind: "report"`）。⚠ **戦闘に出ない器を足したときはこの形を使う**
- ⚠ **`drops` は `grant_chest("chest_that_does_not_exist")` を意図的に呼ぶので黄が1本出る**（⚠ **出るのが正解**）
- ⚠ **1本あたり10〜20秒。⚠ 22本で7分ほどかかる。分けて回すこと**
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
- ⚠ **足した検証が本当に赤を出すか、データを一時的に壊して確かめる。⚠ しかも2箇所で確かめる。⚠ 確かめたら必ず元に戻し、`git diff` が空になることを見る**
- ⚠ **人間に渡す前に、全シナリオを1回ずつ回す**（`training` を除く22本）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 大きな範囲の文字列置換で715行消した

⚠ **§2-4。⚠ `Edit` で1箇所ずつ当てる。**

### ⚠ `@export` の改名で `.tres` の値が黙って消える

⚠ **§2-3。**

### ⚠ `.tres` は `E118` の網に入っていない

⚠ **`E121`（`GameManager._validate_balance_item_refs()`）が見るようになった。⚠ `.tres` にIDを書く欄を増やしたら、⚠ ここに1行足すこと。**

### ⚠ `.tres` を消すとき、`ext_resource` が孤児になる

⚠ **`chest_content_config.gd` を消したとき、⚠ `pomodoro_config.tres` に参照だけ残っていた。⚠ 残したまま `.gd` を消すと `Parse Error`。⚠ 先に `.tres` 側の1行を消す。**

### ⚠ Godot は保存時に `ext_resource` へ `uid` を書き足す

⚠ **「`uid` を書かない」というルールがあるが、⚠ エディタが自分で付ける。⚠ 手で消しても次の保存でまた付く。⚠ 付いた `uid` が最新なら落ちない。**

### ⚠ 新しい `class_name` は、エディタを1回通すまで認識されない

⚠ **参照する側（`balance.gd` の `@export` など）を、⚠ 人間がエディタを通すまで書かない。⚠ 実装を前半・後半に割る。**
⚠ **確かめ方**：`grep -c "<クラス名>" .godot/global_script_class_cache.cfg`

### ⚠ `--check-only --script` は Autoload を読まない

⚠ **`Identifier not found: Balance` / `: SceneManager` は構文エラーではない。⚠ `Parse Error` が0件なら通っている。**

### ⚠ 件数を増やす回では、既存の器の型を先に見る

⚠ **3件の前提で組まれた `HBoxContainer` に12件入れて横に溢れた**（⚠ **`GridContainer` 4列に直した**）。

### ⚠ 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。**（⚠ **`tests/` は例外。あちらは `print` が出口**）
⚠ **確率で起きるもの（抽選のハズレなど）は特に出さない。⚠ ログが埋まる。**
⚠ **「意図的に空のデータ」に毎回黄を出さない**（⚠ **作業場の廃止で `_sync_recipes_from_master()` の `push_warning` を消したのはこれ**）。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ `stages.json` だけトップレベルが半角スペース2つ／⚠ **`recipes.json` は空になったので半角スペース2つ**）。`ja.csv`はUTF-8（BOMなし・LF）。

---

## 5. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここは判断待ちと大きい穴だけ。

### ⚠ 人間の判断待ち

1. ⚠ **マスターファイルが6本目になった**（⚠ **`chests.json`。⚠ 5本目の `summons.json` から続く判断**）
2. ⚠ **射程の段のルールが `EXEC_BATTLE_LINEUP.md` にしか書いていない**
3. ⚠ **`W16`（知らない欄）を赤に上げるか**
4. ⚠ **godot MCP の設定を消すか** ／ **`tests/` の既存9件の棚卸し** ／ **Ziva の `.bak` が7件残っている**
5. ⚠ **`ja.ja.translation` が 20427 → 8631 バイトに縮んだ理由が不明**（⚠ **キーの欠落は無いことを実測で確認済み**）
6. ⚠ **作業場をいつ復活させるか**（⚠ **`recipes.json` が0件のまま。⚠ 画面もコードも生きている**）
7. ⚠ **素材の変換経路が消えた。** ⚠ **`GAME_DESIGN` 9-3 は「ショップに一本化」と書いているが、⚠ `shop.json` に変換に相当する枠があるかは未確認**

### ⚠ 器の穴（**大きいものだけ**）

8. ⚠ **本番キャラのパッシブが0件**（⚠ **枠と `get_battle_passives()` はある**）
9. ⚠ **ルーンが0件**（⚠ **武器・アクセサリーの特別枠が空のまま。⚠ 段階8**）
10. ⚠ **プリセットが0件**（⚠ **状態にもマスターにも器が無い。⚠ このタスク**）
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
21. ⚠ **`W18` が未実測**（⚠ **正規の経路では「刺さっているのに加算できない」状態を作れない**）

### ⚠ 数値が全部「勘」

22. ⚠ **等級4〜10の鍛冶コスト7個** ／ ⚠ **分解の返却率 0.5**
23. ⚠ **装飾の `part_base` / `part_roll_max` 72個 ＋ `part_config.tres` の7個**
24. ⚠ **宝箱の中身と `weight`**（⚠ **戦闘3件が全部30%で同じ。⚠ 進行度で美味しさが変わらない**）
25. ⚠ **段階④の入口がショップだけ** ／ ⚠ **`decor_material_4` も同じ**

### ⚠ 表示の穴

26. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **gold と materials しか並べていない。⚠ 宝箱も出ない**）
27. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**（⚠ **`sort_order` ではない**）
28. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
29. ⚠ **`weapon_steel_sword` がどこからも出ない**（⚠ **`items.json` と `ja.csv` にはある**）
30. ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**（⚠ **中身は `chest_id` を指す。⚠ 改名すると `.tres` 7件が黙って空になる**）

### 片付け

31. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ ⚠ **`ui_status_ch_*` の45行** ／ ⚠ **`_collect_party_candidates()` の検証用キャラの分岐**）
32. ⚠ **フォルダを増やしたら定数に1行足す**（`CHARACTER_DIRS_REQUIRED` / `ENEMY_DIRS_*`）
33. ⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用のまま残っている**（⚠ **復活で1行ずつ戻すため意図的に残した**）
34. ⚠ **`ja.csv` の `ui_guild_workshop*` 12行は残してある**（⚠ **`.tscn` の `label_key` が参照したまま。⚠ 消すと復活時に踏む**）

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **次は段階8（ルーン）が本命**（⚠ **段階12＝バランス実測の唯一の未達依存**）。⚠ **段階3のパッシブ・段階9・段階10 も未着手のまま。**
