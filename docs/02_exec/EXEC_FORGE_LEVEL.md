# EXEC_FORGE_LEVEL：鍛冶のレベル（回SYS-2）

> ⚠ 2026-10-09。⚠ 渡す先は自分。⚠ 値の正は `DECISIONS.md` `EQ-5`（⚠ この回で書き直す）。
> ⚠ 人間の裁き：「⚠ １あ　２い　３あ　４あ」→「⚠ ５い」

## 0. 決まったこと

| # | 裁き | 中身 |
|---|---|---|
| 1 | あ | ⚠ 経験値は**作る・鍛える1回ごとに同じ点**（⚠ 成功も失敗も・作るは装飾のくじも含む全レシピ） |
| 2 | い | ⚠ 補正は**全部の軸に決まった数を足す**（⚠ 装備の型に関係なし） |
| 3 | あ | ⚠ 装飾のパーツは数えない（⚠ 5い と合わせて「パーツの値には関係しない」だけの意味） |
| 4 | あ | ⚠ **最大 Lv10**・次までの点はだんだん増える ／ ⚠ 鍛冶場の右上に「Lv・次まで・いまの補正」／ ⚠ 上がったら画面の上の知らせ（`Toast`） |
| 5 | い | ⚠ **キャラ1人につき1回**（⚠ 着けている数に関係なし）＝⚠ 全キャラを強くする4本の1本（`EQ-10`） |

## 1. 器

- ⚠ 状態 `FORGE_EXP`（int・経験値の合計）。⚠ レベル・補正は Config から毎回計算（CLAUDE.md 4番）
- ⚠ 前のセーブ：⚠ 0（Lv1）。⚠ `load_state()` で `int()` に戻す
- ⚠ Config（`EquipmentConfig`・⚠ 値は**仮**）
  - `forge_level_exp_per_action`（1回の点）
  - `forge_level_exp_totals`（Lv2〜Lv10 に要る経験値の合計・長さ＝最大−1）
  - `forge_level_max_bonus`（Lv10 で足す量・軸ごと）。⚠ 途中のレベルは比例で切り捨て（Lv1＝0）

## 2. 口（`GameManager`）

- `get_forge_exp()` ／ `get_forge_level()` ／ `get_forge_level_max()` ／ `get_forge_exp_to_next()`（⚠ 最大なら 0）
- `get_forge_level_bonus(level = -1)`（⚠ 軸ごと）＝ ⚠ `get_effective_stats()` の7項目め
- `_add_forge_exp()`：⚠ 足す口は `forge_equipment_roll()`（払ったあと）と `start_craft()`（払ったあと）の2つだけ。⚠ 上がったら `forge_level_changed(level)`

## 3. 画面

- ⚠ 鍛冶場の右の列のいちばん上に紙（`ForgeLevelSheet`）：⚠ 「鍛冶の腕 Lv◯」・「次まで あと◯回」（⚠ 最大なら「最大」）・「全員 HP+◯ …」（⚠ 0 の軸は出さない）
- ⚠ 知らせ（`Toast`）：⚠ `forge_level_changed` を受けて「鍛冶の腕が Lv◯ に上がった」

## 4. 完了条件（`ui_flow`）

1. 鍛えると経験値が1増える（成功でも失敗でも）・作るを始めると1増える
2. 経験値が表の合計に届くとレベルが上がり、`get_effective_stats()` が補正の分だけ増える（⚠ 全キャラ同じ）
3. 鍛冶場の右上に Lv と次までが出る
4. 前のセーブ（`FORGE_EXP` の無い）を読むと Lv1・補正0
5. 上がったら知らせが出る
