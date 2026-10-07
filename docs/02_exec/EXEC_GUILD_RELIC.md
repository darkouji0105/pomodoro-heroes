# EXEC_GUILD_RELIC：拠点の遺物（回HB-3）

> ⚠ 2026-10-07。⚠ 渡す先は自分。⚠ 値の正は `DECISIONS.md` `EQ-8`（⚠ この回で書き直す）。
> ⚠ 人間の裁き：「⚠ １　う　分解でたまる形に　２あ　３あ　４あ　５あ」

## 0. 読み方（設計役が決めた）

- ⚠ **捧げる＝分解**。⚠ 遺物の画面の祭壇で等級5以上の装備を選んで「捧げる」と、⚠ 分解と同じく素材が戻り、⚠ **その等級の遺物に点数が入る**
- ⚠ 持ち物の「分解」でも同じく点数が入る（⚠ 口は `dismantle_equipment()` の1本）
- ⚠ 鍛えるのに失敗しても貯まらない（⚠ 「分解でたまる形に」）
- ⚠ 等級5以上だけ（2あ）／ 育成の中のタブ（3あ）／ 名前は「遺物」（4あ）／ 軸は6つのまま（5あ）

## 1. 遺物（⚠ 値は仮）

| ID | 名前 | 等級 | 軸 | 1回の点数 |
|---|---|---|---|---|
| `grelic_power` | 力の遺物 | 5 | 攻撃（全員） | 1 |
| `grelic_life` | 命の遺物 | 6 | HP（全員） | 2 |
| `grelic_guard` | 守りの遺物 | 7 | 物理防御・魔法防御（全員） | 3 |
| `grelic_mend` | 癒しの遺物 | 8 | 受ける回復 +%（全員・戦闘のパッシブ） | 4 |
| `grelic_fortune` | 富の遺物 | 9 | 戦闘のゴールド +% | 5 |
| `grelic_treasure` | 宝の遺物 | 10 | 難ダンジョンの特殊効果の品の重み +% | 6 |

- ⚠ 段は 0〜10。⚠ 次の段に要る点数 `costs`（⚠ 段ごと・累計ではない）と、⚠ 段ごとの効き目の合計 `values`（⚠ 伸びは逓減）を JSON に持つ
- ⚠ セーブは遺物ごとの**点数の合計だけ**（⚠ 段は点数から毎回計算・CLAUDE.md 4番）

## 2. 置き場

- ⚠ マスター `resources/balance/master/guild_relics.json`（⚠ IDごとの表＝JSON・AGENTS.md）
- ⚠ 状態 `GameStateKeys.GUILD_RELICS`＝`{relic_id: int}`
- ⚠ 癒しの遺物の戦闘のパッシブは、⚠ 段ごとに `MasterDataLoader` が組み立てる（`grelic_mend_lv<n>`・`intervene.heal_taken_pct`）

## 3. コード

1. `GameManager`：`get_guild_relic_points()` / `get_guild_relic_level()` / `get_guild_relic_value()` / `get_guild_relic_next_cost()` / `get_guild_relic_of_grade()` / `get_offer_preview()` ／ `dismantle_equipment()` で点数を足す（⚠ 状態を変える前に判定を終える）／ シグナル `guild_relic_changed(relic_id)`
2. `get_effective_stats()` に遺物の加算（⚠ 6本目の項）
3. `get_guild_relic_passives()` → `battle_controller.gd` のパッシブの足し算に1行
4. `with_relic_gold_bonus(rewards)` → `battle_controller.gd` と `run_floor_auto()`（⚠ 結果画面と配る量を揃える）
5. 難ダンジョンの抽選：⚠ `_filter_drop_rows()` のあとで特殊効果の品の重みに倍率
6. 画面 `scenes/guild/guild_relic_screen`：⚠ 左に遺物6つ（段・点数・いま／次の効き目）／ ⚠ 右に祭壇（等級5以上・着けていない装備）→ 選ぶと「◯◯の遺物 +N点・戻る素材」→ 確かめの窓 →「捧げる」
7. 育成の中のタブに「遺物」（`BaseFacilityBar.GUILD_RELIC`・解放は鍛冶場と同じ）

## 4. 完了条件

### ログ（`ui_flow`）
1. 等級5の装備を捧げると力の遺物が +1 点・素材が戻る・装備が消える
2. 等級4以下は祭壇に出ない
3. 段が上がると全員の攻撃が上がる（`get_effective_stats()`）
4. 戦闘で癒しの遺物のパッシブがかかる（記録に状態の行）
5. 富の遺物でゴールドの報酬が増える（`with_relic_gold_bonus()`）
6. 育成の中のタブ「遺物」で遺物の画面

### 画面（`shot`）
- 遺物の画面（祭壇で1品選んだ姿）
