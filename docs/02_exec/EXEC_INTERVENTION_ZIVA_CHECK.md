# Ziva への指示 — **介入点3種の回の「画面を使わない検証」**

## ⚠ 最初に読むこと

> **実装は完了している。コードもデータも入っている。**
> **このファイルの仕事は「検証」だけ。1行もコードを書かないこと。**

⚠ **ズレを見つけても直さないこと。** このプロジェクトは「AIが良かれと思って直した結果、何が原因だったか分からなくなる」を実際に踏んでいる。
**見つけたものは §4 の書式で報告する。直すのは人間の判断。**

⚠ **`.gd` / `.json` / `.csv` を1文字も編集しない。** 読むだけ。

---

## 0. この回で何が入ったか（**背景。作業ではない**）

戦闘の「介入点」を3つ足した（回復・状態の付与・死亡）。それぞれに利用者を1件ずつ付けた。

| 介入点 | 利用者 | 器の書き方 |
|---|---|---|
| 死亡 | **復活** | `buff` の `on_death: { revive_hp_ratio: 0.3 }` |
| 状態の付与 | **免疫** | `buff` の `block_status: ["status_dbg_dot_long"]` |
| 回復 | **被回復低下** | `buff` の `heal_taken_pct: -50` |

⚠ **この3つの欄は `buff` にしか書けない**（新設。`type` の種類は増えていない）。

検証用の敵3体（`enemy_dbg_revive` / `enemy_dbg_immune` / `enemy_dbg_recv`）と
ステージ `stage_dbg_intervene` が入っている。

---

## 1. ⚠ **やらないこと**（先に書く。ここを踏むと時間が溶ける）

| やらないこと | 理由 |
|---|---|
| **戦闘を始める** | 編成とステージ選択の画面操作が要る。**ヘッドレスで再現しようとしないこと** |
| **`stage_dbg_intervene` に入る** | 同上。**人間がやる** |
| **`user://logs/battle_last.jsonl` を読む** | 戦闘を1回終わらせないと中身が無い。⚠ **しかも戦闘のたびに上書きされるので、君が戦闘を始めると人間の検証結果が消える** |
| **色・数字・HPバーを目で見る** | 画面の項目。**人間がやる** |
| **Inspector を開く** | 同上 |
| **テストシーンを作る・`tests/` に足す** | この回のスコープ外 |
| **`.gd` を直す・`print` を足す** | 切り分けのために本番コードを書き換えない |

> **過去の実例**：画面を見る種類の完了条件12項目のうち8項目を実装役に渡した結果、
> ヘッドレスでクリックを再現しようとして $0.66 を消費し、実装が中断した。

---

## 2. 作業A — **プロジェクトを開いて、出力パネルを読む**

**やること**：Godot でプロジェクトを実行し、**タイトル画面が出た時点で止める。**
⚠ **「つづきから」も「はじめから」も押さない。戦闘に入らない。**

起動時にマスターデータの検証が走るので、それだけを読む。

| # | 見るもの | 期待 |
|---|---|---|
| A-1 | **赤いエラー（parse error / Invalid call / Cyclic reference）** | ⚠ **1つも出ないこと。** 出たら全文を報告 |
| A-2 | `skills validated: ...` の行 | **`50 entries, 0 errors, 1 warnings`**（⚠ **前回は 47 件。敵スキル3件で 50**） |
| A-3 | A-2 の **`1 warnings` の中身** | ⚠ **`skill_dbg_dot_odd` の端数の警告1本だけが正解。** 別の内容の黄が出ていたら全文を報告 |
| A-4 | `basic attacks validated: ...` の行 | **`19 entries, 0 errors, 0 warnings`**（⚠ **前回は 16 件。敵3体で 19**） |
| A-5 | `[StatusRegistry]` で始まる赤 | ⚠ **1つも出ないこと。** 特に `buff の stat が10軸に無い` が出たら報告（介入だけを持つ buff が弾かれている） |
| A-6 | `[SkillSchema]` / `[MasterDataLoader]` の赤・黄 | A-2〜A-4 に含まれないものが出たら全文を報告 |

⚠ **件数が期待とズレていたら、それ自体が報告対象。** 数を合わせようとしてファイルを触らないこと。

---

## 3. 作業B — **ファイルを読んで突き合わせる**（実行しない）

**全部「読むだけ」。** ⚠ **どれか1つでも食い違ったら、その場で直さず §4 に書く。**

ここで見るのは全部「**エラーが1つも出ないのに黙って壊れる**」種類のもの。

### B-1. 敵スキルのフォルダの登録漏れ

`scripts/systems/master_data_loader.gd` の **`ENEMY_DIRS_OPTIONAL`** に並んでいるフォルダ名と、
`resources/balance/master/enemies/` の実フォルダが**過不足なく一致**すること。

⚠ **走査していないので、フォルダを足して定数に書き忘れると、その敵のスキルが無音で消える。**
⚠ この回で `enemy_dbg_revive` / `enemy_dbg_immune` / `enemy_dbg_recv` の3行が増えているはず。

### B-2. 敵が持つスキルIDの実在

`resources/balance/master/enemies.json` の各エントリの **`"skills"` 配列**に書かれたIDが、
**その敵のフォルダの `skills.json` のキーとして実在**すること。

| 敵 | 期待するID |
|---|---|
| `enemy_dbg_revive` | `skill_edbg_revive` |
| `enemy_dbg_immune` | `skill_edbg_immune` |
| `enemy_dbg_recv` | `skill_edbg_recv_down` |

⚠ **敵の `"skills"` はそのまま装備枠**（味方のような「候補から2つ選ぶ」の2段が無い）。**IDが違うと無音で撃たない。**

### B-3. ⚠ **免疫が指している status_id の実在**（**ここが一番大事**）

`enemies/enemy_dbg_immune/skills.json` の **`block_status`** に書かれている
**`status_dbg_dot_long`** が、
`characters/char_debug_status/skills.json` の **`skill_dbg_dot_long`** の
**`status_id` として実在**すること（綴りが1文字も違わないこと）。

⚠ **ここが typo だと、免疫は「何も弾かない状態」として静かに成立する。**
**エラーは1つも出ず、画面では「免疫が効いていない」ようにしか見えない。**

### B-4. 翻訳キーの実在

次の7キーが `localization/ja.csv` に**1件ずつ**あること（**0件でも2件でも報告**）。

```
ui_battle_enemy_dbg_revive
ui_battle_enemy_dbg_immune
ui_battle_enemy_dbg_recv
ui_battle_skill_edbg_revive
ui_battle_skill_edbg_immune
ui_battle_skill_edbg_recv_down
ui_stage_dbg_intervene
```

⚠ **JSON 側の `name_key` と綴りが一致**していること。
⚠ **`ja.csv` に CR（`\r`）が1つも無く、先頭にBOMが無いこと。**
BOM が付くと1行目のキーが `﻿keys` になり**全滅**する。

### B-5. ステージの参照

- `resources/balance/master/stages.json` の **`stage_dbg_intervene`** の各波の `enemy_type_id` が、全部 `enemies.json` に実在すること
  （1波＝`enemy_dbg_revive` ／ 2波＝`enemy_dbg_immune` ／ 3波＝`enemy_dbg_heal` ＋ `enemy_dbg_recv` ＋ `enemy_dbg_buff`）
- `stage_order.json` の **`"debug"` 列**に `stage_dbg_intervene` が入っていること
- ⚠ **`"story"` 列が `["stage_1", "stage_2", "stage_3"]` のままであること**（**触られていないことの確認**）

### B-6. 介入の欄が buff 以外に付いていないか

`on_death` / `block_status` / `heal_taken_pct` の3語を**リポジトリ全体で検索**し、
`.json` の中では**必ず `"type": "buff"` かつ `"host": "unit"` の効果の中にだけ**あること。

⚠ `dot` / `react` / `damage` / `heal` の中にあったら報告。

### B-7. インデント

この回で足した／触った `.json` が**タブインデント**であること
（⚠ **`stages.json` だけはトップレベルが半角スペース2つ**。それが元の形なので**正常**）。

---

## 4. 報告の書式

**作業Aと作業Bの結果を、次の形で1つずつ書く。**

```
A-2  OK    skills validated: 50 entries, 0 errors, 1 warnings
A-3  NG    黄が2本出た。2本目は「〜」（全文）
B-3  OK    block_status の "status_dbg_dot_long" は skill_dbg_dot_long の status_id と一致
```

- ⚠ **「確認しました」「問題ありません」だけで済ませないこと。** **実際に読んだ値を書く**（例：「`50 entries` と出た」）
- ⚠ **NG は直さずに報告する。** 直すのは人間の判断
- ⚠ **原因を「環境の問題」と結論づけないこと。** 観測した事実だけ書く
- ⚠ **1つの症状に対して試す方法は2つまで。** 3つ目に進まず、そこで止めて報告する

## 5. 実装ログ

**`res://docs/03_log/IMPL_LOG_INTERVENTION_ZIVA_CHECK.md` を `IMPL_LOG_TEMPLATE.md` の型で生成する。**

⚠ 「5. 指示書からの逸脱・迷った判断」を空欄にしないこと。**判断が要らなかったなら「要らなかった」と、その理由を書く。**

---

## 6. ⚠ この検証が通っても、まだ終わっていない

**ここで確認できるのは「データが繋がっていること」までで、「介入点が実際に効くこと」は確認できない。**

残りは人間がやる：

| 誰が | 何を |
|---|---|
| **人間** | `stage_dbg_intervene` を3波とも戦い、`battle_last.jsonl` の `intervene` 行を読む |
| **人間** | 画面で「復活する」「毒が付かない」「回復の数字が半分」を見る |

⚠ **君が戦闘を始めると `battle_last.jsonl` が上書きされ、人間の検証がやり直しになる。**
