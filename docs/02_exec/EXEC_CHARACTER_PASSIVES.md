# EXEC_CHARACTER_PASSIVES.md — 本番キャラのパッシブ（段階3の残り）

**起点**：`9b93224`（`main`・マージ済み・push していない）
**仕様の正**：`GAME_DESIGN.md` 5-2 / 5-4
**前提**：`AGENTS.md` ／ `CLAUDE.md` ／ `NEXT_STEPS.md` §1

---

## 1. このタスクで入るもの

**本番3キャラに、レベルで解放されるパッシブを5個ずつ（計15件）入れる。**

⚠ **パッシブは「選ぶ」ものではない。⚠ 解放されたものが全部効く**（人間の決定1）。
⚠ **これは実コードの現状（1枠から選ぶ）と違う。⚠ 実装のほうを仕様に寄せる＝ズレ32。**

---

## 2. 人間の決定（**このEXECが本文と矛盾する場合、この章が優先される**）

| # | 決定 | 効く範囲 |
|---|---|---|
| **1** | ⚠ **解放された5個が全部効く**（候補から選ぶのではない） | `get_battle_passives()` ／ `skill_select_screen` ／ 枠の仕組みが死ぬ |
| **2** | ⚠ **レベル100まで上げられるようにする。⚠ 既存の数値を変えるだけ**（ノードを増やさない） | `character_config.gd` ／ `research.json` |
| **3** | ⚠ **`react`（購読）も使う** | パッシブ15件の中身 |
| **4** | ⚠ **`characters/<id>/passives.json` を新設する** | `master_data_loader.gd` ／ ズレ31が消える |
| **5** | ⚠ **スキル画面のパッシブ行は「選べない一覧」に変える** | `skill_select_screen.gd` ／ `ja.csv` |

---

## 3. 変えないもの（**触ると黙って壊れる**）

⚠ **`GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して、⚠ どれにも「置き換えろ」が無いことを確認済み**（`NEXT_STEPS` §2-2 の手順）。

- ⚠ **`_slot_spec()` に手を入れない。** ⚠ 枠の仕組みは1本。⚠ **`SLOT_KIND_PASSIVE` の枝も消さない**（状態の正規化が通る道）
- ⚠ **`GROWTH_PASSIVES`（状態のキー）を消さない。** ⚠ **セーブとキャラプリセットの5キーのうちの1つ。⚠ 消すと `_normalize_presets_from_save()` と `_plan_build()` が両方動く**
- ⚠ **`_step_passives()` / `_restore_passives()` / `_has_all_passive_statuses()` を触らない。** ⚠ **`BattleUnit.passive_ids` を埋める口を替えるだけで足りる**
- ⚠ **`E74`（`target.team` は `self` だけ）／ `E75`（`stack` は `refresh` だけ）／ `E76`（`trigger` は `cast` だけ）／ `host` は `unit` だけ** を緩めない
- ⚠ **`stat` に `hp` を書かない**（`status_registry.gd`。⚠ `max_hp` を再計算しない）
- ⚠ **`PASSIVE_SLOT_COUNT` の値を変えない**（1のまま。⚠ 参照する側が居なくなるだけ）
- ⚠ **`upgrade_part()` ／ ルーン ／ 装飾に一切触らない**

---

## 4. 実装（**9ファイル**）

### 4-1. マスターの読み込み — `scripts/systems/master_data_loader.gd`

⚠ **`passives.json` を `_cache_skills` と同じ辞書へマージする。**

理由：`_restore_passives()` → `_fire_skill()` → `MasterDataLoader.get_skill(passive_id)` を通るため、⚠ **パッシブが `get_skill()` で引けないと、戦闘側を触ることになる。**

- `_load_character_files()` に **ファイル名を複数受ける形**を足す（⚠ **2本目の関数を作らない**）
- ⚠ **`passives.json` は全ディレクトリで「無くてよい」扱い**（`required = false`）。⚠ **検証用キャラと敵は持たない**
- ⚠ **`skills.json` と `passives.json` にIDが重複したら赤**（⚠ **`_merge_id_map()` の既存の `push_error` がそのまま効く。⚠ 新しい番号を足さない**）
- ⚠ **41〜43行目のコメント**（「パッシブを実装する回にここへ置く」）を**実装に合わせて直す**＝**ズレ31が消える**

**新しい検証（`E126`）**：`characters.json` の `passives` に書いてあるIDが、⚠ **定義されていない**、または ⚠ **`activation` が `"passive"` でない**とき赤。
⚠ **理由**：`get_skill_candidates()` は定義の無いIDを黙って落とす。⚠ **片方だけ書いた事故が実戦まで出ない**（`NEXT_STEPS` §1-3）。

### 4-2. 戦闘に渡す確定版 — `autoload/game_manager.gd`

```
func get_battle_passives(character_id: String) -> Array:
	# ⚠ パッシブは選ばない。解放済みの候補が全部効く（人間の決定1・GAME_DESIGN 5-4）。
	# ⚠ get_battle_skills() を通さない（あちらは枠の話）。
	return get_skill_candidates(character_id, SLOT_KIND_PASSIVE)
```

⚠ **これ1本だけ。`battle_controller.gd:299` は1行も変えない。**
⚠ **`get_selected_passives()`（4224行）は残す。⚠ 画面が「今なにが選ばれているか」を出さなくなるだけで、⚠ 状態の正規化からは呼ばれ続ける。**

### 4-3. レベル上限を100に届かせる（**決定2**）

| ファイル | 変更 |
|---|---|
| `resources/balance/character_config.gd` | `base_level_cap` の既定値 **10 → 20** |
| `resources/balance/master/research.json` | `res_cap_1..4` の `effect_value` **5 → 20**（4件） |

⚠ **20 + 4×20 = ちょうど 100。** ⚠ **`max_character_level`（100）と一致する。**
⚠ **`character_config.tres` にはこの欄が書き出されていないので、⚠ `.gd` の既定値がそのまま効く**（実測で確認済み。⚠ **人間の `.tres` 作業は不要**）。
⚠ **ノードを1件も増やさない**（⚠ **段階10「研究の作り替え」と衝突させない**）。

### 4-4. パッシブの中身 — `characters/<id>/passives.json` を**3本新設**

⚠ **15件。⚠ 帯は `GAME_DESIGN` 5-4（序盤＝スキル強化 ／ 中盤＝条件発動 ／ 終盤＝役割を深める）。**
⚠ **`unlock_level` は仕様どおり 20 / 40 / 60 / 80 / 100**（⚠ **決定2で全部届くようになる**）。

**全件に共通して必ず書く**：`user_character_id` ／ `activation: "passive"` ／ `target: {"team": "self"}` ／ 各効果に `host: "unit"` ・ `stack: "refresh"` ・ `duration_sec: 99999.0` ・ `status_id`。

#### char_swordsman（前衛・物理）

| Lv | id | 帯 | 中身 |
|---|---|---|---|
| 20 | `passive_sw_whetstone` | 序盤 | `buff` `atk_mult_pct: 10`（常時） |
| 40 | `passive_sw_last_wall` | 中盤 | `buff` `stat: "def"` `value: 25`、`condition: {source:"hp_ratio", of:"host", op:"lte", value:0.5}` |
| 60 | `passive_sw_thorn_mail` | 中盤（購読） | `react` `event: "took_damage"` → `damage` `multiplier: 0.4` `attack_type:"physical"` `scale_from:"def"` `target:{team:"source"}` |
| 80 | `passive_sw_bloodlust` | 終盤 | `buff` `stat:"atkspd"` `value: 15`、`condition: {source:"alive_count_enemy", of:"host", op:"lte", value:2}` |
| 100 | `passive_sw_vanguard` | 終盤 | `buff` `def +20` ＋ `buff` `mdef +20`（⚠ **効果2件・`status_id` は別々**） |

#### char_archer（弓・`atkspd` の例外持ち）

| Lv | id | 帯 | 中身 |
|---|---|---|---|
| 20 | `passive_ar_steady_aim` | 序盤 | `buff` `crit_rate +10`（常時） |
| 40 | `passive_ar_opening_shot` | 中盤 | `buff` `atk_mult_pct: 20`、`condition: {source:"elapsed_sec", of:"host", op:"lte", value:15}` |
| 60 | `passive_ar_follow_through` | 中盤（購読） | `react` `event: "dealt_damage"` → `damage` `multiplier: 0.35` `attack_type:"physical"` `scale_from:"atk"` `target:{team:"source"}` |
| 80 | `passive_ar_hunters_focus` | 終盤 | `buff` `crit_dmg +40`、`condition: {source:"alive_count_enemy", of:"host", op:"lte", value:2}` |
| 100 | `passive_ar_volley_master` | 終盤 | `buff` `atkspd +20`（常時。⚠ **役割＝手数を深める**） |

#### char_priest（回復役）

| Lv | id | 帯 | 中身 |
|---|---|---|---|
| 20 | `passive_pr_devotion` | 序盤 | `buff` `mag +12`（常時。⚠ **回復量は `mag` 依存**） |
| 40 | `passive_pr_triage` | 中盤 | `buff` `mag +25`、`condition: {source:"alive_count_ally", of:"host", op:"lte", value:2}` |
| 60 | `passive_pr_sanctuary` | 中盤 | `buff` `mdef +20`（常時） |
| 80 | `passive_pr_zeal` | 終盤 | `buff` `haste +15`、`condition: {source:"elapsed_sec", of:"host", op:"gte", value:30}` |
| 100 | `passive_pr_benediction` | 終盤 | `buff` `mag +20` ＋ `buff` `haste +10`（⚠ **効果2件**） |

⚠ **`react` は2件だけ**（剣士 Lv60 ／ 弓 Lv60）。
⚠ **理由**：⚠ **本番に前例が0件なので、⚠ 敵の `skill_edbg_react` / `skill_edbg_followup` で通っている形（`damage` → `target.team: "source"`）だけを写す。⚠ `react` の中で `buff` や `heal` を出す形は前例が無いので今回は書かない**（§8 の宿題へ）。

### 4-5. 候補の欄 — `resources/balance/master/characters.json`

⚠ **3キャラに `"passives": [...]`（5件）を足す。**
⚠ **欄を足すのと `passives.json` にエントリを置くのはセット**（`NEXT_STEPS` §1-3。⚠ **片方だけだと `E126` が出る＝そのための検証**）。

### 4-6. 画面 — `scenes/guild/skill_select_screen.gd`（**決定5**）

⚠ **`_build_slots()`（89行）のパッシブの行を、⚠ 枠の行から「選べない一覧」に差し替える。**

- ⚠ **`_build_slot_rows(SLOT_KIND_PASSIVE, ...)` の呼び出しをやめる**（⚠ **関数自体は消さない。⚠ スキルが使っている**）
- ⚠ **代わりに、そのキャラのパッシブ候補5件を `unlock_level` の順に並べる**
- ⚠ **解放済み** … 名前をそのまま出す
- ⚠ **未解放** … 名前と「Lv◯◯で解放」を出す（⚠ **`GameManager.get_skill_unlock_level()` が既にある**）
- ⚠ **ボタンにしない**（⚠ **押して何も起きない器を残さない**）
- ⚠ **139行の `ui_skill_select_passive_candidates_header` の枝も消す**（⚠ **候補一覧は「選ぶ側」の器。⚠ 一覧が2つ並ぶ**）

### 4-7. `localization/ja.csv`（**480行 → 514行**）

- `ui_battle_passive_<id>` × **15**
- `ui_status_ch_<status_id>` × **17**（⚠ **効果1件ごとに1つ。⚠ 無いと黄が出て戦闘のマスに「？」が出る**）
- `ui_skill_select_passive_header` ／ `ui_skill_select_passive_locked`（「Lv%dで解放」）
- ⚠ **UTF-8（BOMなし・LF）。⚠ 追記後の再インポートは人間の作業**

### 4-8. 検証 — `tests/debug_boot.gd`

- ⚠ **`SCENARIOS` に `passives` を1本足す**（⚠ **`KIND_BATTLE`。⚠ パッシブは戦闘の数値を変えるので `report` では足りない。⚠ ルーンと同じ判断**）
  - ⚠ **本番3キャラを編成に入れる**（⚠ **本番キャラで戦うシナリオは今まで無い**）
  - ⚠ **レベルを 20 / 40 / 60 / 80 / 100 に上げて、⚠ 付くパッシブの件数が 1→2→3→4→5 と増えることを出す**
  - ⚠ **`react` の2件は「実際に発火したか」を出す**（⚠ **`BattleLog.log_react` が既に在る**）
- ⚠ **`LAYOUT_SCENES` に `res://scenes/guild/skill_select_screen.tscn` を1行足す**（⚠ **候補が0件→5件になるので行が伸びる。⚠ 今まで測っていない**）
- ⚠ **足した検証は、メモリ上の状態を2箇所で壊して赤が出ることを確かめる**（⚠ **`git diff` を汚さない**）

---

## 5. 実装の順番（**赤が出る順に潰す**）

1. `character_config.gd` ＋ `research.json`（**上限100**）
2. `master_data_loader.gd`（**`passives.json` を読む ＋ `E126`**）
3. `passives.json` × 3 ＋ `characters.json` の欄 ＋ `ja.csv`
4. `game_manager.get_battle_passives()`
5. `skill_select_screen.gd`
6. `debug_boot.gd`

⚠ **3 の前に 2 を入れると `E126` が15件出る。⚠ それが正しい**（⚠ **検証が効いていることの確認になる**）。

---

## 6. 完了条件

⚠ **同じことを2箇所に書かない。⚠ 誰が取るかは `AGENTS.md`「誰が取るか」。**

### §0 事前チェック（**設計役・人間に渡す前に終わっている**）

- 全シナリオ（⚠ **`training` を除く26本＋新しい `passives` ＝ 27本**）をヘッドレスで1回ずつ回す
- ⚠ **赤の平常値 0本。⚠ ただし `unlock` は1本が正常**
- ⚠ **黄の平常値 1本（`skill_dbg_dot_odd`）。⚠ `drops` と `parts` はもう1本ずつ多いのが正常**
- `--check-only --script` で `skill_select_screen.gd` に `Parse Error` が無い

### A. ログ（**設計役が `godot.log` を読む**）

| # | 見るもの |
|---|---|
| A-1 | `skills validated: 94 entries, 0 errors, 1 warnings`（⚠ **79 + 15**） |
| A-2 | `items` 89 / `runes` 25 / `basic attacks` 19 / `balance item refs 0 errors` が**変わっていない** |
| A-3 | ⚠ **`E126` が0件**（⚠ **`characters.json` の欄と `passives.json` が揃っている**） |
| A-4 | `scenario=passives`：Lv20/40/60/80/100 で `passive_ids` が **1 / 2 / 3 / 4 / 5 件** |
| A-5 | `scenario=passives`：⚠ **`passive_sw_thorn_mail` と `passive_ar_follow_through` の `react` が実際に発火した行が出る** |
| A-6 | `scenario=passives`：⚠ **条件付き4件が、条件を満たさない間は値0・満たすと値が乗る** |
| A-7 | ⚠ **`ui_status_ch_` の黄が0本**（⚠ **19件ぶん追記できている**） |
| A-8 | `scenario=layout`：⚠ **`skill_select_screen` が横にはみ出していない** |
| A-9 | ⚠ **`get_effective_level_cap()` が研究を全解放した状態で 100 を返す** |
| A-10 | ⚠ **既存シナリオの damage が変わっていない**（⚠ **本番キャラを使うのは `lineup` だけで、⚠ Lv1 のままなのでパッシブは1件も付かない＝実測で確認済み**） |

### B. ファイル（**設計役が読む**）

| # | 見るもの |
|---|---|
| B-1 | `save_slot_0.json`：⚠ **`character_growth.<id>.passives` が今までと同じ形で残っている**（⚠ **決定1でも状態は消さない**） |
| B-2 | `save_slot_0.json`：⚠ **`level` と `stats` の値に `.0` が付いていない**（`CLAUDE.md` 3番） |
| B-3 | `character_presets` の5キーが揃ったまま（⚠ **`passives` を含む**） |

### C. 画面（**人間だけ**）

| # | 操作 | 見えるべきもの |
|---|---|---|
| C-1 | 育成 → 剣士 → 「スキル」 | ⚠ **パッシブが「選ぶ枠」ではなく一覧で並ぶ。⚠ 5件。⚠ 押しても何も起きるボタンが無い** |
| C-2 | 同上（Lv1のまま） | ⚠ **5件とも「Lv20で解放」「Lv40で解放」…と出ている** |
| C-3 | 剣士を Lv20 まで上げて同じ画面 | ⚠ **1件目だけ名前が出て、⚠ 残り4件は「Lv◯◯で解放」のまま** |
| C-4 | 研究を全部解放 → 育成 | ⚠ **レベル上限が 100 と出る** |
| C-5 | Lv20 の剣士で `stage_1` を戦う | ⚠ **戦闘のマスにパッシブの状態が1つ付いている**（⚠ **「？」ではなく文字が出る**） |
| C-6 | そのまま被弾する（Lv60 以上） | ⚠ **`passive_sw_thorn_mail` の反撃ダメージが敵に出る** |
| C-7 | 育成 → キャラ → 「適用」（ビルド） | ⚠ **今までどおり動く**（⚠ **パッシブの欄が死んでも壊れていない**） |
| C-8 | 拠点・装備・パーティ選択の各画面 | ⚠ **横にはみ出していない** |

### D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- `characters.json` の `passives` に存在しないIDを書く → **`E126` が1件**
- `passives.json` に `activation: "instant"` を書く → **`E126` が1件**
- `skills.json` と `passives.json` に同じIDを書く → **既存の重複エラーが1件**

---

## 7. Ziva に切り出せる範囲（**JSON と `ja.csv` だけ**）

⚠ **§4-4（`passives.json` × 3）・§4-5（`characters.json` の欄）・§4-7（`ja.csv`）は、⚠ `.gd` を1行も触らずに書ける。**
⚠ **渡すもの**：`AGENTS.md` ＋ このファイルの §4-4 / §4-5 / §4-7 ＋ `IMPL_LOG_TEMPLATE.md` ＋ ⚠ **見本として `characters/char_debug_status/skills.json` の `passive_dbg_*` 2件と `enemies/enemy_dbg_react/skills.json`**。
⚠ **渡す前に §4-1（`E126`）を先に入れておくこと。⚠ 検証が無い状態で書かせると、⚠ 綴り違いが黙って通る。**

---

## 8. このタスクで増える宿題

- ⚠ **`GROWTH_PASSIVES`（状態）とキャラプリセットの `passives` が、⚠ 誰も読まない欄として残る**（⚠ **消すとセーブの移行が要るので残した**）
- ⚠ **`PASSIVE_SLOT_COUNT` ／ `_slot_spec()` のパッシブの枝 ／ `get_selected_passives()` ／ `select_skill()` のパッシブ経路が、⚠ 画面から到達できなくなる**
- ⚠ **`ui_skill_select_passive_slot` ／ `ui_skill_select_passive_candidates_header` の2行が未使用になる**
- ⚠ **`react` の中で `buff` / `heal` を出す形が、⚠ まだ本番に0件**
- ⚠ **Lv100 までの育成素材が、⚠ 今の線形式（`3 + 1.0×(level-1)`）で約 5,148 個要る**（⚠ **`GAME_DESIGN` 5-2 が「差し替える」と言っている式。⚠ 段階12で効いてくる**）
- ⚠ **研究の上限ノードが1件あたり +20 になり、⚠ 刻みが粗くなった**（⚠ **段階10の作り替えで戻す前提**）
- ⚠ **パッシブの数値15件ぶんが全部「勘」**

---

## 9. 実施結果（**2026-08-25・設計役がヘッドレスで取ったものだけ**）

### 9-1. §0 事前チェック（**通っている**）

⚠ **27本（`training` を除く全部）を1本ずつ回した。**

| | 結果 |
|---|---|
| 赤 | ⚠ **`unlock` の1本だけ**（`E125`＝平常値）。⚠ **他26本は0** |
| 黄 | ⚠ **18本が平常値になった**（`skill_dbg_dot_odd` の1本 ＋ ⚠ **`ui_status_ch_*` の17本**）。⚠ **`parts` と `drops` はもう1本ずつ多い（19本）＝これも平常** |
| `--check-only --script` | ⚠ **`skill_select_screen.gd` に `Parse Error` なし**（⚠ **`Identifier not found: SceneManager` は Autoload 未読み込み**） |

⚠ **黄の平常値が 1本 → 18本 に増えた。⚠ 17本は `ja.csv` の再インポートが済むと消える**（下の 9-3）。

### 9-2. A章（ログ）の結果

| # | 結果 |
|---|---|
| A-1 | ⚠ **`skills validated: 94 entries, 0 errors, 18 warnings`**（79 + 15） |
| A-2 | ⚠ **`items` 89 / `runes` 25 / `basic attacks` 19 / `balance item refs 0 errors` が変わっていない** |
| A-3 | ⚠ **`E126` 0件** |
| A-4 | ⚠ **3キャラとも `Lv20:1件 Lv40:2件 Lv60:3件 Lv80:4件 Lv100:5件`** |
| A-5 | ⚠ **`status_ar_follow_through`（`dealt_damage`）19回 ／ `status_sw_thorn_mail`（`took_damage`）8回**。⚠ **`"ev":"react"` の行で取れた** |
| A-6 | ⚠ **条件が false→true に転じた行を確認**：`opening_shot`（開幕＝`true`、15秒後に `false`）／ `bloodlust` と `hunters_focus`（t=16.87 に敵2体以下で `true`）。⚠ **`last_wall` / `triage` / `zeal` はこの戦闘で条件が成立せず `false` のまま＝正常系**（⚠ **同じ経路を通っているが「成立した」実測は無い**） |
| A-7 | ⚠ **通っていない。⚠ `ja.csv` 再インポート待ち**（9-3） |
| A-8 | ⚠ **`skill_select_screen.tscn` は開いた。⚠ ただし測定値が「最小幅 0」で、⚠ 再インポート前は赤が5本出る**（9-3） |
| A-9 | ⚠ **研究を全解放した状態で Lv100 まで上がった**（⚠ **上限が 100 に届いていることの実測**） |
| A-10 | ⚠ **本番キャラを使う既存シナリオは `lineup` だけ。⚠ Lv1 のままなのでパッシブは1件も付かない。⚠ `lineup` は赤0・黄18で変化なし** |

### 9-3. ⚠ 人間の作業が1つ残っている（**`ja.csv` の再インポート**）

⚠ **`ja.csv` を 480 → 514行にしたが、再インポートは設計役にはできない**（`CLAUDE.md`）。**未了の間、次の2つが出る**：

- ⚠ **黄が17本**（`ui_status_ch_*` が翻訳表に無い ＝ 戦闘のマスに「？」が出る）
- ⚠ **`scenario=layout` が赤5本**（⚠ **`tr()` がキー文字列をそのまま返し、`%d` が無いまま `%` を当てる**。⚠ **既存の `_lock_text()` と同じ書き方なので、⚠ コード側は house style どおり**）

⚠ **済んだかどうかを設計役が観測できる合図を作った**：`scenario=passives` の
`[DebugBoot] ja.csv の再インポート: まだ／済んでいる` の1行。
⚠ **「済んでいる」に変わったら、⚠ `layout` の赤5本と黄17本が同時に消えるのが正解。**

### 9-4. ⚠ 足した検証を2箇所で壊して確かめた

| 壊したもの | 出た赤 |
|---|---|
| `characters.json` の `passives` に存在しないIDを書く | ⚠ **`characters char_swordsman: passives の 'passive_sw_typo_does_not_exist' が定義されていない`** |
| `passives.json` の `activation` を `instant` にする | ⚠ **`characters char_priest: passives の 'passive_pr_devotion' は activation が 'instant'`** |

⚠ **どちらも元に戻し、⚠ 平常値（赤0・黄18）に戻ったことを再実行で確認した。**

### 9-5. ⚠ 実装中に踏んだ落ち（**次に同じことをしないため**）

1. ⚠ **`SkillSchema` の定数名を値だと思って書いた。** ⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_count_enemy"`。⚠ `"alive_enemy"` と書いて赤3本＋毎フレームの赤3886本を出した**
   → ⚠ **定数は名前ではなく `const` の右辺を見ること。**
2. ⚠ **`condition` は `of` が必須。** ⚠ **`SCALE_SOURCES_NO_OF`（`distance` / `elapsed_sec` / `wave_index`）は「`of` を読まない」と書いてあるが、⚠ それは `scale_from` の話（W12）で、⚠ `condition` 側は書かないと赤になる**
   → ⚠ **ズレの候補。§10 に上げた。**
3. ⚠ **`GameManager.get_character_level()` は存在しない**（⚠ **`get_character_growth(id).get(GROWTH_LEVEL)` を使う**）
4. ⚠ **`battle_last.jsonl` は `C:\Users\admin\AppData\Roaming\Godot\app_userdata\pomodoro-heroes\logs\` にある**（⚠ **`NEXT_STEPS` §3 の「`.../pomodoro-heroes/logs/`」はプロジェクト直下と読めるが、⚠ 実体は `user://`＝ここ**）

---

## 10. ⚠ 見つけたズレ（**報告のみ。勝手に直していない**）

| # | ズレ | 直すなら |
|---|---|---|
| ⚠ **32** | ⚠ **実装は「パッシブを1枠から選ぶ」だったが、⚠ `GAME_DESIGN` 5-2 / 5-4 は「20レベルごとに1つ解放（計5個）」＝全部効く。** ⚠ **今回、実装のほうを仕様に寄せた**（人間の決定1） | ⚠ **済**（⚠ **仕様は1文字も変えていない**） |
| ⚠ **33** | ⚠ **デモの実効レベル上限が 30 しか無く、⚠ 仕様の Lv40/60/80/100 に永久に届かなかった**（`base_level_cap` 10 ＋ 研究 4×5） | ⚠ **済**（⚠ **決定2で 20 ＋ 4×20 = 100 にした**） |
| ⚠ **34** | ⚠ **`skill_schema.gd:330` のコメント「`of` を読まない source」は `scale_from` にしか当てはまらない。** ⚠ **`condition` は同じ source でも `of` が必須で、⚠ 書かないと赤になる** | ⚠ **コメント側**（⚠ **または `condition` 側で `of` を任意にする。⚠ 未着手**） |
| ⚠ **35** | ⚠ **`master_data_loader.gd` のコメントが「パッシブは `passives.json` に置く」と書いていた（ズレ31）** | ⚠ **済**（⚠ **実装をコメントに合わせた＝決定4**） |

---

## 11. 人間が実機で確認したあと（**2026-08-25**）

### 11-1. ⚠ 実機のログで A-6 と A-7 が埋まった

⚠ **`ja.csv` の再インポートが済み、黄が 18 → 1本（`skill_dbg_dot_odd`）に戻った＝A-7 通過。**
⚠ **`godot.log` は赤0本。**

⚠ **`battle_last.jsonl`（`stage_3` を5ウェーブ完走・569行）から**：

| | 中身 |
|---|---|
| 剣士（Lv60）に3件 | `whetstone` / `last_wall` / `thorn_mail`。⚠ **弓と神官は Lv20 未満で0件＝正常** |
| ⚠ **`thorn_mail` の反撃が 56回発火**（`took_damage`） | ⚠ **`react` が実戦で効いている** |
| ⚠ **`last_wall` が `true` 6回 / `false` 7回** | ⚠ **ヘッドレスでは条件が成立せず証明できていなかった項目（A-6 の残り）。⚠ 実機で埋まった** |
| 各パッシブが x5 | ⚠ **ウェーブごとの `status_clear` のあと `_step_passives()` が張り直す正常な形。⚠ 積み上がっていない** |

⚠ **`triage`（味方2人以下）と `zeal`（30秒経過）は、まだ「成立した」実測が無い。** ⚠ **同じ経路を通っているが、条件が起きる戦闘をまだしていない。**

### 11-2. ⚠ 育成画面が縦にはみ出していた（**人間が実機で発見**）

⚠ **原因**：`_refresh_detail()` が `stats_label` に10軸を `"\n".join()` で1行ずつ入れており、
⚠ **テキスト15行 ＋ ボタン7段が1本の `VBoxContainer` に縦積みされていた**（720px に入らない）。

⚠ **直し（人間の決定・2カラム）**：

- `DetailPanel` を **`VBoxContainer` → `HBoxContainer`**
- ⚠ **左 `InfoColumn`** … `NameLabel` / `LevelLabel` / `StatsLabel` / `CostLabel` / `NoticeLabel`（⚠ **`autowrap_mode` を付けた**）
- ⚠ **右 `ActionColumn`** … ボタン5個 ＋ ⚠ **プリセット行の差し込み先もこちら**
- ⚠ **`@onready` 10本のパスと `_build_preset_row()` / `move_child()` の相手を差し替えた**
- ⚠ **縦は `576 → 436`**（⚠ **ヘッドレスの下限値。⚠ 実機の10行はここに乗っていない**）

⚠ **合計ではなく「左右の高いほう」になったのが効いている。**

### 11-3. ⚠ 検証の道具が壊れていた（**ズレ36**）

⚠ **`scenario=layout` の `LAYOUT_SCENES` は、6シーンとも `最小幅 0` を返していた。⚠ 横も縦も1回も測れていない。**

| | 中身 |
|---|---|
| 原因1 | ⚠ **画面のルートが素の `Control`。⚠ 子の `MarginContainer` はアンカー配置なので `get_combined_minimum_size()` が常に 0** |
| 原因2 | ⚠ **基準がヘッドレスの viewport（**1280 x 1280**）。⚠ 実機は 1280 x 720 で高さが違う** |
| 原因3 | ⚠ **開いた直後の姿しか測っていない。⚠ 育成は「一覧」と「詳細」が排他で、⚠ 縦に長いのは詳細のほう** |

⚠ **直した**：一番外側の `Container` を測る ／ `SCREEN_SIZE`（1280 x 720）を基準に縦横の両方を見る ／ `LAYOUT_SCENE_SHOW` の表で排他の器を開いてから測る。

⚠ **ただし、この件は道具を直したあとでも捕まらない。** ⚠ **ヘッドレスでは `_show_detail()` が走らず、`StatsLabel` も `NoticeLabel` もプリセット行も空のまま。⚠ 実機でしか出ない。**

⚠ **私は前の回で `skill_select_screen` を足したとき「最小幅 0」を見ていたのに流した。** ⚠ **「もっともらしい 0 を信じない」は前の回にも同じ形で踏んでいる。**

### 11-4. ⚠ 全シナリオを回し直した（**27本**）

⚠ **赤0本（`unlock` の1本だけが平常値）／ 黄1本（`drops` と `parts` は2本）。⚠ 再インポート後の正しい平常値に戻った。**
