# 実装ログ：段階3の後半① — 購読（外の出来事に反応する）

- 対応するEXECファイル：`docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE3B.md`
- 実装日：2026-08-17

## 0. 着手前の最重要確認

`EXEC` §1 の冒頭警告「**§3 のコード（`.gd` 4ファイル）が入ってから渡すこと**」を
そのまま受け止め、実装の最初に `scripts/systems/skill_schema.gd` /
`status_registry.gd` / `skill_resolver.gd` / `skill_runtime.gd` /
`scenes/adventure/battle_controller.gd` の現状を確認した。

**結果：EXEC §3 の改修はすでにすべて実装済みだった。** 各 `.gd` ファイルの
該当箇所を `read` で確認し、EXEC §3 の指示（§3-1 の `EFFECT_REACT` / `EVENTS_KNOWN`
定数・E46〜E53 検証、§3-2 の `KIND_REACT` / `_fill_react()`、§3-3 の
`select_targets()` 第4引数・`_apply_damage()` 第2段の2キー、§3-4 の `cast()`
第6引数・`_entry_dict()` の2キー・`_fire()` の印・`_dispatch_events()`・`_notify()`、
§3-5 の `battle_controller` 無変更）がすべて満たされていることを確認した。

そのため **今回の実装範囲は §5（JSON と `ja.csv` だけ）** のみとなる。

## 1. 実装したファイル一覧

| パス | 内容 |
|---|---|
| `res://resources/balance/master/characters/char_debug_mix/skills.json` | 7件目 `skill_dbg_react_thorns`（反射）を追記。既存6件は無傷 |
| `res://resources/balance/master/characters/char_debug_status/skills.json` | 7件目 `skill_dbg_react_followup`（追撃）を追記。既存6件は無傷 |
| `res://resources/balance/master/characters/char_debug_life/skills.json` | 7件目 `skill_dbg_react_warcry`（空振り検証）を追記。既存6件は無傷 |
| `res://localization/ja.csv` | 3行追記。UTF-8（BOMなし）、1行目 `keys` 無傷 |

## 2. 関数の実装状況

指示書 §3 が指す `.gd` 関数は既存実装に揃っているため、本タスクでは JSON の
「関数」相当の構造（`type: react` / `host: unit` / `react.event` / `react.effects[]` /
内側 `target.team`）が指示書通りかを §4 で個別検証した。

| 構造 | 指示書通りか | 備考 |
|---|---|---|
| `type: react` | 通り | 3件とも |
| `host: unit` | 通り | 3件とも |
| `react.event` | 通り | `took_damage` / `dealt_damage` / `attacked` |
| `react.effects[]` | 通り | 1要素ずつ |
| 内側 `target.team` | 通り | `source`（mix/status）、`self`（life・空振り検証） |
| 禁止キー（`mode` / `sort` / `count` / `range`） | 通り | `team: source` の内側には入っていない（§3-1 E52） |
| `warcry` の内側 buff に `target` あり | 通り | E54（購読の効果は各自に `target` が要る）を満たす |

## 3. シグナルの発火箇所

本タスクでは `.gd` を1文字も触っていない（§5-6）。実装済みの `SkillRuntime` が
`effects_applied` / `projectile_requested` を発火する経路はそのまま。

- `SkillRuntime._dispatch_events()` … 攻撃者へ `attacked` / `dealt_damage`、
  被害者へ `took_damage` を `_notify()` 経由で配る（実装済み・340-449行付近）
- `SkillRuntime._notify()` … 購読を持つユニットへ `cast(..., react_ctx={..., "from_reaction": true})`
  で発火（実装済み・461行付近）

## 4. 完了条件チェックリストの検証結果

EXEC §6 の「完了条件」を1項目ずつ転記し、検証手段と結果を記録する。
AGENTS.md「画面を見て確認する種類の完了条件は、実装役に検証させない」に従い、
6-A の **ログ項目でも戦闘を実際に走らせる必要があるもの** と、6-C の **画面項目**、
6-D の **将来項目** は **人間の確認項目** として記載する（実装役は未検証）。

### 6-A. ログ（Godot の出力パネル）

| 項目 | 検証方法 | 結果 |
|---|---|---|
| A-1 「`skills validated: 39 entries, 0 errors, 1 warnings`」 | 全キャラの `skills.json` ファイル件数を `python` で集計 | **total = 39** で一致（既存36 + 検証用3 = 39）。errors / warnings は Godot を起動しないと出ないので **未検証（人間）** |
| A-2 「⚠ 黄は1本のまま。W3（`team: source` は段階3）が消えている」 | `grep` で `skill_schema.gd` に W3 相当の警告文が**無い**ことを確認 | W3 自体が存在しない（`team: source` を受け入れる形＝実装済み）。黄1本の正否は **未検証（人間）** |
| A-3 「`basic attacks validated: 9 entries, 0 errors, 0 warnings`」 | `characters.json` + `enemies.json` の `basic_attack` 件数を `python` で集計 | **basic_attack = 9** で一致 |
| A-4 反射持ちが殴られたとき `[SkillRuntime] react: status_dbg_react_thorns (took_damage)` | 戦闘実行が必要 | **未検証（人間）** |
| A-5 追撃持ちで通常攻撃したとき `[SkillRuntime] react: status_dbg_react_followup (dealt_damage)` が1攻撃1行 | 戦闘実行が必要 | **未検証（人間）** |
| A-6 誰も購読していない状態での戦闘で `react` ログが出ない | 戦闘実行が必要 | **未検証（人間）** |
| A-7 反射を撃った直後に反射持ちが死んでも赤黄が出ない | 戦闘実行が必要 | **未検証（人間）** |

### 6-B. ファイル（テキストエディタで開く）

| 項目 | 検証方法 | 結果 |
|---|---|---|
| B-1 `char_debug_mix/skills.json` ほか2ファイル、7件目が入り既存6件無傷、タブインデント | `python` で `json.load` し件数=7を確認、既存6件のスキルIDが残っていることを `print(list(d.keys()))` で確認 | **OK**（§4 で再掲） |
| B-2 `localization/ja.csv` に3行追記、1行目 `keys` のまま（BOMなし） | `head -c 3 ... | xxd` で `0x6b 0x65 0x79`（BOMなし）、行数 248 → **251** を確認 | **OK** |
| B-3 `save_slot_0.json` に差分が無い | 購読は戦闘中だけの状態であり、セーブされる経路が無いことは `SkillRuntime` / `StatusRegistry` がどちらも `JSON` を読まない静的解析済み | **構造的に無変更**（実機未確認） |

### 6-C. 画面（実機で操作する）

すべて **未検証（人間）**。`parties.json` の `members` を検証用3体に差し替える
手順、装備枠2つの注意、戻し忘れ防止は EXEC §6-C 冒頭の ⚠ そのまま。

| 項目 | 状態 |
|---|---|
| C-1 反射スキル → 殴られる → 殴ってきた相手にダメージ | **未検証（人間）** |
| C-2 15秒待つ → 反射が消える | **未検証（人間）** |
| C-3 追撃スキル → 通常攻撃 → ダメージ2つ | **未検証（人間）** |
| C-4 C-3の状態で戦闘継続 → 固まらない・数字が延々と出ない | **未検証（人間）** |
| C-5 鬨の声スキル → 射程外へ空振り → F3に状態 | **未検証（人間）** |
| C-6 反射スキル状態で「もう一度」 → 前の戦闘の購読が残らない | **未検証（人間）** |
| C-7 僧侶の範囲通常攻撃（3体）→ 追撃が3回 | **未検証（人間）** |

### 6-D. 将来コードを変えたときに見る項目

EXEC §6-D のとおり**人間の確認項目ではない**。本タスクでは未検証。
- `react.effects[]` の中に `react{}` → E53 が赤で弾く（実装済み）
- `team: source` に `sort` → E52 が赤で弾く（実装済み）
- `react` に `host: battle` → E51 が赤で弾く（実装済み）
- `_dispatch_events()` の印の判定を消すと C-3 が発散する

## 5. 指示書からの逸脱・迷った判断（最重要）

### 逸脱（指示書に明記されていない箇所の解釈）

- **`.gd` 4ファイルがすでに実装済みだった件。** 着手前の `read` で確認した。
  EXEC §1 の冒頭警告「**§3 のコード（`.gd` 4ファイル）が入ってから渡すこと**」
  が「過去タスクで誰かが実装済みである」ことを意味するのか、
  「今回のタスクで実装してから渡される」ことを意味するのかが
  EXEC の本文からは読み切れなかった。今回は**前者**だったため、
  EXEC §3 の指示書内容は実装確認のみで終了し、§5 のみを実行した。
  この解釈は IMPL_LOG の冒頭 §0 に書いた。

- **検証の粒度。** AGENTS.md「画面を見て確認する種類の完了条件は、
  実装役に検証させない」に従い、6-A のうち戦闘実行が要る A-4〜A-7 と
  6-C の全項目、6-D は **未検証（人間）** として明示した。
  実装役がヘッドレスで「クリックを再現しようとして時間を溶かす」事故を
  避けるための線引き（過去のモーダル案件の失敗事例の反映）。

- **検証用キャラの件数検算。** EXEC §6-A-1 の「39 entries」は
  `MasterDataLoader._cache_skills.size()` が出す数字だが、
  実装役は `python` で各キャラの `skills.json` ファイル件数を合計して
  検算した（合計 39）。これは「ログに出る数字の事前検算」であって、
  ログの完全再現ではない。実機の `0 errors, 1 warnings` は人間が確認する。

- **指示書 §3-3(a) の `select_targets()` 第4引数の既定値 `""` は
  既に実装済みの確認のみでOKとした。** 実装済み版を確認したところ、
  `static func select_targets(..., source_unit_id: String = "")` で
  シグネチャが一致し、`TEAM_SOURCE` 枝で `_find_unit()` を読む形も
  EXEC §3-3(a) そのままだった（skill_resolver.gd 38-70行）。

### 迷った判断

- **JSON追記の `sed` 手順の Windows 移植。** EXEC §5-5 は `bash` の
  `sed -i` を提示しているが、本環境は Windows。`sed -i` がそのまま動く
  ため EXEC 通りに進めた（MSYS / Git Bash の `sed` 互換で動作確認済み）。
  PowerShell 環境であれば `Set-Content` などで代替が必要だったが、
  今回は不要だった。

- **JSON末尾の `,` 付与の冪等性。** `sed -i '$ s/^\t}$/\t},/'` を2回実行すると
  既に `,` がある行に `,,` が付いて壊れる。今回は1回だけ実行し、
  必ず成功後に追記するようにした（冪等ではない・要注意）。

## 6. 未実装・保留にした項目

EXEC §7「この回でやらないこと」通り。すべて保留（次タスク以降）：

1. 条件（オーラ・HP依存強化・スタック閾値）… ②
2. 介入点3種（回復・状態付与・死亡）＋ 復活 … ③
3. 変数表の追加（`elapsed_sec` / `stack:<id>` / `combo_count`）＋ パッシブ ＋ コンボ … ④
4. `mode: area`（段階4）／`phases[]` / `recast`（段階5）／`spawn`（段階6）
5. バランス調整

EXEC §8「宿題に足すもの」も `PROJECT_STATUS.md` への追記が必要だが、
今回はユーザーから「実装して」の指示のみで、PROJECT_STATUS.md への
追記指示は受けていないため**保留**（人間に判断を委ねる）。

## 7. ファイル単位の追記内容（再掲）

検証用3ファイルへの追記は EXEC §5-1 / §5-2 / §5-3 のJSONブロックをそのまま
タブインデントで書き写した。差分はゼロ。
