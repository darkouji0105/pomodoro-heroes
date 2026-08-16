# EXEC_SKILL_MULTIFILE.md — skills の複数ファイル化（キャラ別 ＋ debug）＋ 検証用キャラ3体

**第3層（実行指示書）。** 共通ルールは `AGENTS.md`、現在地は `PROJECT_STATUS.md`、次の1タスクは `NEXT_STEPS.md`、決定台帳は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`。

**このタスクの目的は2つ。**

1. **`skills.json`（315行）をキャラ別に割る。** 段階3の後半で購読と条件が乗ると1スキルが30〜50行になり、4人目のキャラで500行を超える。**割るなら購読が乗る前。**
2. **検証用のキャラ3体とスキル18件を作る。** 段階3の後半を検証するとき、製品の18スキルだけでは踏めない組み合わせがある。

⚠ **この2つは同じ仕組み**（`MasterDataLoader` が複数ファイルを読んでマージする）。別々にやると同じものを2回作る。

---

## 1. 人間による決定事項（2026-08-16・**本文と矛盾する場合こちらが優先**）

### 1-1.【体制】⚠ **人間の指示で変更：設計役が全部書いた（2026-08-16）**

**当初は §5〜§7（JSONと`ja.csv`）を実装役（MiniMax / Ziva）に渡す予定だったが、人間の判断で設計役が全部書いた。**

⚠ **したがって §2 の担当欄の「実装役」は実施されていない。** この指示書を後から読む人が「実装役が書いたもの」と誤解しないよう、担当欄はそのまま残してある（**当初の計画の記録**）。

**実際に書いたもの（設計役）：** §4 の3ファイル・§5 の18件・§6 の3件・§7 の21行・§8・§9。

### 1-2.【決定】検証用キャラは**3体**。1体につき候補6件、合計18スキル

1キャラ2枠は変わらない。**3体×6件を用意し、`parties.json` の `members` を3体とも差し替えて使う。**

⚠ **4人目にしない。** パーティごと入れ替えるので、人数も座標もレイアウトも本編と同じまま。

### 1-3.【決定】パーティの入れ替え機能は作らない

パーティは状態（セーブ）に入っていない。`stages.json` の `party_id` → `parties.json` の `members` をマスターから毎回引き直している。

**`parties.json` の1行を書き換えてゲームを再起動すれば入れ替わる。** ⚠ **`parties.json` は人間が手で直す。実装役に書き換えさせない**（本番データ）。

### 1-4.【決定】デバッグステージは作らない

ステージの解放判定が `stage_order.json` の並び順で「1つ前をクリアしたか」を見ている（`adventure_select.gd` 85行）。**デバッグステージを先頭に入れると本編の `stage_1` がその後ろに回る。**

### 1-5.【決定】「枠を無視して撃つキー」は作らない

検証用キャラの候補6件をギルドのスキル選択画面で付け替え、`S`（CDリセット）で連打する形でまかなう。**付け替えの往復がつらくなったら次の回で足す。**

### 1-6.【決定】ファイル名はキャラIDそのまま

`skills_char_swordsman.json` / `skills_char_archer.json` / `skills_char_priest.json` / `skills_debug.json`。

⚠ **短縮しない**（`skills_swordsman.json` にすると `user_character_id` と綴りが揃わず、機械的に対応が取れなくなる）。

### 1-7.【決定】検証用キャラは**死なず・敵を倒さない**性能にする

HP 9999 / atk 1 / mag 1。⚠ **検証中に死んだり敵を倒してウェーブが進んだりすると、状態の観察が途中で切れる。**

⚠ **`crit_rate` は 0。** 会心が抽選されるとダメージがフレームごとにぶれ、DoT の発火回数を合計値で確かめられなくなる。

### 1-8.【決定】倍率・寿命・周期は**検証しやすさ優先**。バランスは見ない

検証用なので `value: 50` のような極端な値を使う。**製品のスキル18件の数値は1つも変えない。**

---

## 2. 触るファイルと担当

| ファイル | 何をするか | 担当 |
|---|---|---|
| `resources/balance/master/skills_char_swordsman.json` | **新規**。`skills.json` から剣士の6件を移す | ⚠ **設計役**（見本） |
| `resources/balance/master/skills_char_archer.json` | **新規**。弓兵の6件を移す | **実装役** |
| `resources/balance/master/skills_char_priest.json` | **新規**。僧侶の6件を移す | **実装役** |
| `resources/balance/master/skills_debug.json` | **新規**。検証用18件（§5） | **実装役** |
| `resources/balance/master/skills.json` | **削除** | **実装役** |
| `resources/balance/master/characters.json` | **3件追記**（§6） | **実装役** |
| `localization/ja.csv` | **21行追記**（§7） | **実装役** |
| `scripts/systems/master_data_loader.gd` | 複数ファイルを読んでマージ（§8） | ⚠ **設計役** |
| `scenes/guild/training_screen.gd` | `CHARACTER_IDS` に3行（§9） | ⚠ **設計役** |
| `resources/balance/master/parties.json` | **触らない**（人間が検証時に手で1行差し替える） | **人間** |

⚠ **`scenes/` `autoload/` `resources/balance/*.tres` は1つも触らない。**

### ⚠ 順番の落とし穴（**必ず読むこと**）

**`skills.json` の削除（実装役）と、マージの実装（設計役）は同じコミットに入れる。**

| もし | 起きること |
|---|---|
| マージを先に入れて `skills.json` が残っている | **18件が全部「重複ID」で赤**（分割ファイルと元ファイルの両方に居るため） |
| 分割を先に入れてマージがまだ | **スキルが1件も読めない**。戦闘のスキルボタンが消える |

**実装役の作業が終わったら、設計役の §8 が入るまで実機で確認しない。**

---

## 3. 着手前に確認した実コード（2026-08-16・`grep` 済み）

| | 事実 |
|---|---|
| `_ensure_loaded()` | `master_data_loader.gd` **66〜80行**。5ファイルを `_load_json()` で読み、**最終行で `_validate_all_skills()`**。⚠ **この順序が要件**（射程のクロス検証が `_cache_characters` を読む） |
| `_load_json()` | **load() 方式 → 失敗したら FileAccess 方式**。⚠ **1本目で決まったモードを以降も使う**（`_load_mode`）。**成功時は何も出さない** |
| `_cache_skills` | **平坦な `Dictionary`**（`skill_id` → データ）。**入れ子でない** |
| ロード時検証のログ | `[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings`（**422行**）。件数は `_cache_skills.size()` |
| ⚠ キャッシュ | `_cache_loaded` は **static**。**JSONを書き換えたらゲームの再起動が要る** |
| `SKILL_FIELDS_KNOWN` | `skill_schema.gd` **140行**。`name_key` / `user_character_id` / `unlock_level` / `cooldown_sec` / `activation` / `charge` / `target` / `effects` / `phases`。⚠ **これ以外を書くと赤**（E26） |
| `CHARGE_FIELDS_REQUIRED` | **146行**。`just_sec` / `just_window_sec` / `min_ratio` / `just_bonus` |
| ⚠ E44 / E45 | `until: "charge_end"` と `trigger: "charge_start"` は **`activation: "charge"` のスキルにしか書けない**（赤） |
| ⚠ `stack` | `buff` / `dot` に**省略不可**（`independent` / `refresh`） |
| ⚠ `scale_from` | `damage` / `dot` / `heal` に**省略不可** |
| ⚠ `duration_sec` と `until` | **どちらか一方だけ**（両方書くと赤） |
| ⚠ `stat: "hp"` | `buff` には**書けない**（赤） |
| `parties.json` | **`party_default` 1件のみ**。`members` は `["char_priest", "char_archer", "char_swordsman"]` |
| 人数 | `battle_controller.gd` 163行は **`members.size()` でループ**。3はハードコードされていない |
| ⚠ セーブ | `game_manager.gd` **915行** `get_character_growth()` は**エントリが無ければ `characters.json` から既定値を組み立てる**（910〜914行に明記）。⚠ **セーブを触らずに済む** |
| ⚠ 育成画面 | `training_screen.gd` **15〜19行** の `CHARACTER_IDS` が決め打ち3件。⚠ **ここに足さないと育成画面に出ず、スキル選択画面に到達できない** |
| ⚠ 割り振り画面 | `character_nodes.json` は180件・全部 `character_id` 付き。**検証用キャラのノードは0件になる** |

---

## 4. 分割（§4-1 は設計役が先に書く。実装役は §4-2 から）

### 4-1. 見本：`skills_char_swordsman.json`（**設計役**）

`skills.json` から `user_character_id` が `char_swordsman` の6件を、**中身を1文字も変えずに**移す。

```
skill_power_slash / skill_wide_sweep / skill_reckless_strike /
skill_last_stand / skill_shield_bash / skill_helm_splitter
```

トップレベルは `skills.json` と同じ形（`{ "skill_id": { ... } }` の平坦な辞書）。**新しい階層を作らない。**

### 4-2. 実装役がやること

**`skills_char_swordsman.json` を見本にして、同じ形で2本作る。**

| ファイル | 中身 | 件数 |
|---|---|---|
| `skills_char_archer.json` | `user_character_id` が `char_archer` のもの | **6** |
| `skills_char_priest.json` | `user_character_id` が `char_priest` のもの | **6** |

**移し終わったら `skills.json` を削除する。**

⚠ **中身を1文字も変えない。** 倍率も `weight` も `cooldown_sec` も `unlock_level` も、**改行位置とインデント（タブ）も**そのまま。

⚠ **IDを1つも改名しない。** 改名すると**スキル選択の保存（`growth.skills.slots`）が黙って落ちる**（候補で絞られ、エラーが出ずに候補の先頭に置き換わる）。

⚠ **6 + 6 + 6 = 18。** 移し終えたら**元の `skills.json` と `grep -c '"user_character_id"'` で件数を突き合わせること。**

---

## 5. `skills_debug.json`（**新規・18件**・実装役）

### 5-0. 全件に共通で書くもの

| 欄 | 値 | なぜ |
|---|---|---|
| `unlock_level` | **1** | Lv1で18件すべてが候補に出る。研究でレベル上限を上げなくてよい |
| `cooldown_sec` | **1.0** | 連打して確かめるため |
| `name_key` | `ui_battle_<skill_id>` | ⚠ **`ja.csv` に同じ綴りで足すこと**（§7） |

⚠ **`user_character_id` は3体に6件ずつ割る。** 偏らせないこと（1キャラ2枠なので、6件を超えると付け替えでしか届かない）。

### 5-1. `char_debug_status` の6件（**状態の器そのもの**）

| # | `skill_id` | `target` | 効果 | 何を見るか |
|---|---|---|---|---|
| 1 | `skill_dbg_buff_refresh` | `self` | `buff` / `atk` `+50` / `duration_sec: 20` / `refresh` | **2回撃っても1本のまま**。寿命が20秒に戻る |
| 2 | `skill_dbg_buff_stack` | `self` | `buff` / `atk` `+50` / `duration_sec: 20` / `independent` | **撃つたびに増える**。⚠ **上限が無いので積み放題**（宿題4番の実演） |
| 3 | `skill_dbg_buff_atkspd` | `self` | `buff` / `atkspd` `+100` / `duration_sec: 10` / `refresh` | **攻撃間隔が半分**になり、**剥がすと元に戻る**（累積しない） |
| 4 | `skill_dbg_debuff_def` | `enemy` / `all` | `buff` / `def` `-50` / `duration_sec: 20` / `refresh` | **負の値**。⚠ **`get_stat()` が 0 で切る**ので、`def` は 0 未満にならない |
| 5 | `skill_dbg_dot_long` | `enemy` / `nearest` / `count: 1` | `dot` / `duration_sec: 30` / `interval_sec: 1` / `independent` | **30発**。長く残るので `P` キーで何度も覗ける |
| 6 | `skill_dbg_dot_odd` | `enemy` / `nearest` / `count: 1` | `dot` / `duration_sec: 5` / `interval_sec: 2` / `independent` | **2発**（端数は切り捨て）。⚠ **ロード時に黄が出るのが正解**（割り切れない） |

### 5-2. `char_debug_life` の6件（**寿命と剥がれ方**）

| # | `skill_id` | `target` | 効果 | 何を見るか |
|---|---|---|---|---|
| 7 | `skill_dbg_charge_guard` | `enemy` / `nearest` / `count: 1` | ⚠ **`activation: "charge"`**。`damage` ＋ `buff` / `def` `+50` / `trigger: "charge_start"` / `until: "charge_end"` / `refresh`（`target` は `self`） | **ためている間だけ付き、離すと剥がれる**。⚠ **`charge{}` の4欄が要る** |
| 8 | `skill_dbg_dot_once` | `enemy` / `nearest` / `count: 1` | `dot` / `duration_sec: 2` / `interval_sec: 2` / `independent` | **1発**。⚠ **発火と寿命切れが同じフレーム。落ちないこと** |
| 9 | `skill_dbg_dot_all` | `enemy` / `all` | `dot` / `duration_sec: 10` / `interval_sec: 2` / `independent` | **宿主が複数**。敵の数だけ別々に走る |
| 10 | `skill_dbg_buff_ally` | `ally` / `all` | `buff` / `atk` `+30` / `duration_sec: 15` / `refresh` | **味方3人に同時に付く**。付与者は1人 |
| 11 | `skill_dbg_dot_self` | `self` | `dot` / `duration_sec: 10` / `interval_sec: 2` / `independent` | **宿主＝付与者**。自分が減る |
| 12 | `skill_dbg_buff_short` | `self` | `buff` / `atk` `+50` / `duration_sec: 1` / `refresh` | **1秒で消える。** 切れる瞬間を `P` で見る |

### 5-3. `char_debug_mix` の6件（**組み合わせ・多段・回復**）

| # | `skill_id` | `target` | 効果 | 何を見るか |
|---|---|---|---|---|
| 13 | `skill_dbg_mix_all` | `enemy` / `nearest` / `count: 1` | `damage` ＋ `buff`（`self` / `atk` `+30` / 10秒 / `refresh`）＋ `dot`（10秒 / 2秒） | **1スキルに3種類**。効果は1件ずつ解かれる |
| 14 | `skill_dbg_delay` | `enemy` / `nearest` / `count: 1` | `damage` ＋ `damage` / `trigger: "delay:1.0"` | **1秒あとに2発目**。⚠ **対象は撃った瞬間に確定する**（1発目で死んでも2発目は同じ敵に出る） |
| 15 | `skill_dbg_delay_buff` | `self` | `buff` / `trigger: "delay:2.0"` / `atk` `+50` / 10秒 / `refresh` | **2秒あとに状態が付く**（遅延と器の組み合わせ） |
| 16 | `skill_dbg_drain` | `enemy` / `nearest` / `count: 1` | `damage` ＋ `heal`（`target` は `self`） | **吸血**。⚠ **効果ごとの `target` 上書き**が効くこと |
| 17 | `skill_dbg_true` | `enemy` / `nearest` / `count: 1` | `damage` / `attack_type: "true"` | **防御を0として扱う**。#4 のデバフと並べると差が見える |
| 18 | `skill_dbg_scale_sum` | `enemy` / `nearest` / `count: 1` | `damage` / `scale_from` は**配列**（`atk` ＋ `hp_lost`） | **和で合成される**。⚠ **積は書けない**（宿題9番） |

### 5-4. ⚠ 書き間違えると**赤で落ちる**もの（ロード時検証が捕まえる）

- `stack` を書かない（`buff` / `dot`）
- `scale_from` を書かない（`damage` / `dot` / `heal`）
- `duration_sec` と `until` を**両方**書く
- `stat` に `hp` を書く
- `activation` が `charge` でないのに `until: "charge_end"` / `trigger: "charge_start"` を書く（E44 / E45）
- `SKILL_FIELDS_KNOWN` に無い欄をスキル直下に書く（E26）
- `attack_type` の綴り違い（`physical` / `magic` / `true` のみ）
- **同じ `skill_id` が2ファイルにある**（§8 で足す検証）

### 5-5. ⚠ 書き間違えても**黙って動く**もの（検証が捕まえない）

- **`user_character_id` の綴り違い** … そのキャラの候補に出ないだけ。**エラーは出ない**
- **`name_key` と `ja.csv` の綴り違い** … 画面にキー名（`ui_battle_...`）がそのまま出る
- **`value` の符号** … `+50` のつもりで `-50` を書いても通る
- **`interval_sec` が `duration_sec` より大きい** … 0発になる（`floor` で 0）

---

## 6. `resources/balance/master/characters.json`（**3件追記**・実装役）

**既存の3件は1文字も触らない。** 末尾に3件足す。

### 6-1. 3体に共通の値

| 欄 | 値 | なぜ |
|---|---|---|
| `hp` | **9999** | ⚠ **検証中に死なせない** |
| `atk` / `mag` | **1** | ⚠ **敵を倒してウェーブを進ませない** |
| `def` / `mdef` | **0** | 受けるダメージが素で見える |
| `atkspd` / `haste` | **0** | #3 のバフの効き目を見るため |
| `crit_rate` | **0** | ⚠ **会心が乱数なのでダメージがぶれる** |
| `crit_dmg` | **150** | 既存3体と同じ |
| `spd` | **60** | 動けないと射程に入らない |
| `attack_type` | `"physical"` | |
| `attack_range` | **300** | 近づかなくても届く |
| `attack_interval_sec` | **2.0** | ⚠ **#3 で半分になるのを見るため。短くしない** |
| `allocatable_stats` | `["hp", "atk", "def"]` | 割り振り画面が要求する |
| `growth_per_level` | `{ "hp": 1, "atk": 1, "def": 1, "spd": 1 }` | 形を揃えるだけ（レベルではもう伸びない） |

### 6-2. 3体

| `character_id` | `name_key` | `skills`（候補6件） |
|---|---|---|
| `char_debug_status` | `ui_battle_char_debug_status` | §5-1 の6件（#1〜#6） |
| `char_debug_life` | `ui_battle_char_debug_life` | §5-2 の6件（#7〜#12） |
| `char_debug_mix` | `ui_battle_char_debug_mix` | §5-3 の6件（#13〜#18） |

⚠ **`skills[]` の順序が候補の並び順になり、未選択の枠は先頭から埋まる。** 表の順で書くこと。

---

## 7. `localization/ja.csv`（**21行追記**・実装役）

**キャラ3行 ＋ スキル18行。** 末尾に足す。

- キャラ … `ui_battle_char_debug_status,検証用（状態）` のような形
- スキル … `ui_battle_skill_dbg_buff_refresh,再付与バフ` のような形。**§5 の表の「何を見るか」が分かる短い日本語**

⚠ **`ja.csv` は UTF-8（BOMなし）。** BOM が付くと1行目が `﻿keys` になり**全滅**する。

⚠ **キーの重複を作らない。** 足す前に `grep` で無いことを確認する。

⚠ **編集後は Godot で再インポートが要る**（人間の作業）。

---

## 8. `scripts/systems/master_data_loader.gd`（**設計役**）

**やること：`_ensure_loaded()` が skills を複数ファイル読んでマージする。**

| | 要件 |
|---|---|
| 読む対象 | `skills_char_swordsman` / `skills_char_archer` / `skills_char_priest` / `skills_debug` |
| ⚠ 重複ID | **赤で弾く。** 何もしないと**あとから読んだほうが黙って勝つ** |
| ⚠ ファイルが無い | **正常系。警告を出さない**（`skills_debug.json` はリリース前に消す） |
| ⚠ ログ | `skills validated: %d entries` は**合計値のまま1本に保つ**（完了条件に使い続けられる） |
| ⚠ 位置 | `_validate_all_skills()` は**引き続き `_ensure_loaded()` の最終行**（`_cache_characters` を読むため） |
| ⚠ `_load_json()` | **既存のまま使う。** load() 方式と FileAccess 方式の切り替えを2本目に書かない |

⚠ **`get_skill()` / `get_all_skills()` の外から見える形は変えない。** 呼び出し元（`battle_controller` / `skill_select_screen` / `GameManager`）を1つも触らずに済むこと。

---

## 9. `scenes/guild/training_screen.gd`（**設計役**）

`CHARACTER_IDS`（15〜19行）に3行足す。

⚠ **足さないと育成画面に出ず、スキル選択画面に到達できない＝スキルを付け替えられない。**

⚠ **これは決め打ちを1つ増やす行為。** 宿題1番（`MasterDataLoader.get_all_characters()` を足して決め打ちごと消す）はこのタスクではやらない。**`PROJECT_STATUS.md` に残す。**

---

## 10. 事故りやすい箇所（**名指し**）

### 10-1. ⚠ 順番（§2 の落とし穴）

**分割・削除・マージは同じコミット。** 片方だけ入れると「全部重複で赤」か「スキルが1件も出ない」。

### 10-2. ⚠ JSON のインデントはタブ

既存ファイルはタブ。スペースを混ぜない。

### 10-3. ⚠ `ja.csv` の BOM

UTF-8（BOMなし）。付くと1行目から全滅する。

### 10-4. ⚠ スキルIDを改名しない

`growth.skills.slots` が黙って落ちる（`CLAUDE.md` 4番）。

### 10-5. ⚠ 編集したら `grep` で当たったことを確認する

```
grep -c '"user_character_id"' resources/balance/master/skills_char_*.json
grep -c '"user_character_id"' resources/balance/master/skills_debug.json
```

**6 / 6 / 6 / 18** になること。⚠ **「差し替えたつもりで当たっていない」で1タスク溶かした事故がある。**

### 10-6. ⚠ `parties.json` を書き換えない

**実装役は触らない。** 人間が検証時に手で差し替える。

---

## 11. 完了条件

### 11-A. ログ（**出力パネル**）

1. `[MasterDataLoader] skills validated: 36 entries, 0 errors, 0 warnings` **以外**の件数が出たら NG（18 ＋ 18 ＝ **36**）
   - ⚠ **`0 warnings` にならない可能性がある。** §5-1 の #6（`duration 5` × `interval 2`）は**割り切れないので黄が出るのが正解**。その場合は `0 errors, 1 warnings` が正
2. `skill id not found` が1つも出ないこと
3. **重複IDの赤が出ないこと**
4. ⚠ **検証用ファイルを消したときに `18 entries` に戻ること**（`skills_debug.json` をリネームして再起動する。**赤も黄も出ないこと**）

⚠ **このログがいつ出るかを先に確かめること。** `master_data_loader.gd` 380〜382行のコメントは「**育成画面か戦闘画面に入って初めて動く**」と言っているが、過去の `NEXT_STEPS.md` は「タイトルのつづきから」と書いていた。**どちらが正しいか実機で確かめ、食い違っていたら報告する（勝手に直さない）。**

### 11-B. ファイル（**テキストエディタで開く**）

5. `resources/balance/master/` に `skills.json` が**無い**こと
6. `skills_char_swordsman` / `_archer` / `_priest` が**各6件**、`skills_debug` が**18件**
7. 分割前後で**スキルIDの集合が完全に一致**すること（18件・1つも増減・改名なし）
8. `characters.json` の既存3件が**1文字も変わっていない**こと
9. `ja.csv` が UTF-8（BOMなし）で、**21行増えている**こと

### 11-C. 画面（⚠ **人間が実機で操作する**）

⚠ **先に `parties.json` の `members` を `["char_debug_status", "char_debug_life", "char_debug_mix"]` に差し替えてゲームを再起動する。**

10. ギルドの育成画面に**検証用キャラ3体が出る**（既存3体と合わせて6体）
11. ⚠ **割り振り画面を検証用キャラで開いても落ちない**（ノードが0件。**空で開くのが正解**）
12. スキル選択画面で、検証用キャラの候補が**6件とも出る**（Lv1で全部選べる。グレーが1つも無い）
13. 戦闘に入ると**検証用キャラ3人**が並び、スキルボタンが**3列**出る
14. `ja.csv` のキーが引けている（画面に `ui_battle_...` がそのまま出ていない）
15. **#1 と #2 の違い**：`P` を押して、`refresh` は1本のまま／`independent` は撃つたびに増えること
16. **#3**：撃つ前と後で、F3 パネル1行目の攻撃間隔が **2.00 → 1.00** になり、10秒後に戻ること
17. **#7**：ためている間だけ `def` バフが付き、**離すと剥がれる**こと（`P` で確認）
18. **#14**：1秒あとに2発目のダメージが出ること
19. ⚠ **`parties.json` を元に戻して再起動すると、本編が元どおり動く**こと（スキルボタンが本編の2枠×3人に戻る）

### 11-D. 将来コードを変えたときに見る項目（⚠ **人間の確認項目ではない**）

- 同じ `skill_id` を2ファイルに書くと赤が出る
- `skills_debug.json` が無くても赤も黄も出ない
- `skills_char_*.json` を1つ消すと、そのキャラの候補が空になる（**戦闘でスキルボタンが出ない**）

---

## 12. このタスクでやらないこと

- **段階3の後半**（購読・条件・介入点3種・パッシブ・コンボ・復活）
- **枠を無視して撃つキー**（決定1-5）
- **パーティ選択画面**（決定1-3）／**デバッグステージ**（決定1-4）
- **枠を2つから増やす**（セーブ構造）
- **製品のスキル18件の中身の変更**（**数値も倍率も1つも触らない**）
- **`characters.json` / `enemies.json` / `parties.json` / `stages.json` の分割**（skills だけ）
- **`MasterDataLoader.get_all_characters()` の新設**（宿題1番）
- **`target.range` を埋める**（座標定数とセットで後決め）
- **バランス調整**（⚠ **検証用キャラが出ている間の数字は測っても意味が無い**）

---

## 13. 宿題に送るもの（`PROJECT_STATUS.md` に足す）

1. **検証用のものが増えた** … `skills_debug.json`・`characters.json` の3件・`ja.csv` の21行・`training_screen.gd` の `CHARACTER_IDS` 3行。**リリース前に消す**
2. ⚠ **`CHARACTER_IDS` の決め打ちが3件から6件になった。** `get_all_characters()` で消す案は据え置き（宿題1番）
3. ⚠ **検証用キャラに `character_nodes.json` のノードが0件。** 割り振り画面が空で開く
4. ⚠ **`independent` に上限が無い**（#2 で実演できるようになった）。**UIが先に音を上げる**
5. **`parties.json` の差し替えは手作業。** 戻し忘れると本編の検証が全部おかしくなる
6. ⚠ **コメントの「`skills.json`」が5ファイルに残っている**（`skill_resolver` / `skill_runtime` / `status_registry` / `battle_controller` / `game_manager` / `state_keys` / `skill_select_screen` / `unit`）。**ファイルはもう存在しない。** 意味は通るので今回は触っていない。**次にその周辺を触るときに直す**

---

## 14. コミットメッセージ

```
feat(skill): skills をキャラ別に分割し、検証用キャラ3体×18スキルを追加
```

⚠ **分割・削除・マージ・`CHARACTER_IDS` を1つのコミットに入れる**（§2 の落とし穴）。
