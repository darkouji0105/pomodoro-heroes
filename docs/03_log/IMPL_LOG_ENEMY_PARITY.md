# 実装ログ：敵の管理を味方と同じにする（敵がスキルを持ち、自分で撃つ）

- 対応するEXECファイル：`EXEC_ENEMY_PARITY.md`
- 実装日時：2026-08-17

## 0. 担当範囲

EXEC §5 とテストプレイ担当のうち、本ログは **§5（JSON と `ja.csv` の差し込みのみ）を担当** した記録。
`.gd` への変更はゼロ。テストプレイとログ貼付は **`playtest` サブエージェントが本プランで利用不可** だったため、**未実施（ユーザー判断により停止）**。

## 1. 実装したファイル一覧

| パス | 内容 |
|---|---|
| `res://resources/balance/master/enemies.json` | 検証用6体（`enemy_dbg_react` / `enemy_dbg_followup` / `enemy_dbg_buff` / `enemy_dbg_dot` / `enemy_dbg_heal` / `enemy_dbg_ranged`）を追加。既存の3体（`enemy_slime` / `enemy_wolf` / `boss_slime_king`）は1文字も変更していない |
| `res://resources/balance/master/enemies/enemy_dbg_react/skills.json` | 新規作成（反射スキル） |
| `res://resources/balance/master/enemies/enemy_dbg_followup/skills.json` | 新規作成（追撃スキル） |
| `res://resources/balance/master/enemies/enemy_dbg_buff/skills.json` | 新規作成（自己バフスキル） |
| `res://resources/balance/master/enemies/enemy_dbg_dot/skills.json` | 新規作成（DoTスキル） |
| `res://resources/balance/master/enemies/enemy_dbg_heal/skills.json` | 新規作成（仲間回復スキル） |
| `res://resources/balance/master/enemies/enemy_dbg_ranged/skills.json` | 新規作成（投射物スキル） |
| `res://resources/balance/master/stages.json` | `stage_dbg` を1件追加。既存の3ステージは1文字も変更していない |
| `res://localization/ja.csv` | 13行追加（敵名6 / スキル名6 / `ui_stage_dbg` 1）。BOM無し・LF、CSV構文は維持 |

**触っていないファイル**：`stage_order.json`（人間担当、指示書通り）／既存3ステージ・既存39スキル・既存敵3体を含む `enemies.json` の3体／全 `.gd` ファイル。

## 2. 関数の実装状況

該当なし（`.gd` への変更ゼロ）。

## 3. シグナルの発火箇所

該当なし。

## 4. 完了条件チェックリストの検証結果

EXEC §6（完了条件）のうち、**§6-A（ログ） と §6-B（戦闘ログ）はテストプレイ未実施のため未検証**。
検証できる範囲で以下のみ確認:

- [x] JSON 構文の妥当性: `enemies.json` / `stages.json` / 6つの `skills.json` を `python -c 'import json; json.load(open(...))'` で確認済み。すべて valid
- [x] 既存3体・3ステージが変更されていないこと: キーの一覧に `enemy_slime` / `enemy_wolf` / `boss_slime_king` / `stage_1` / `stage_2` / `stage_3` がそのまま残存
- [x] 検証用6体が追加されていること: `enemies.json` のキー一覧に `enemy_dbg_*` が6件、`stages.json` のキー一覧に `stage_dbg` が追加
- [x] 13行が `ja.csv` に追加されていること: 各キーがバイト列として存在することを確認（repr 経由の文字化けは表示のみで、UTF-8 バイト列は正常）
- [ ] 起動ログの2行（EXEC 6-A）: **未検証**。`run_scene` で起動ログの取得を試みたが、ユーザー判断で停止
- [ ] `battle_last.jsonl` の各行（EXEC 6-B）: **未検証**
- [ ] 画面確認（EXEC 6-C）: **人間の担当**として未実施

## 5. 指示書からの逸脱・迷った判断（最重要）

### 5-1. 改行コードの修復（逸脱あり・要報告）

EXEC §5-6 の手順では `cat >>` で追記する指示だったが、Windows 環境の bash で `cat << 'EOF'` を実行したところ **追加分が CRLF で書き込まれた**。`enemies.json` は元々が LF だったため CRLF が混ざり、`stages.json` は元々が CRLF だったため行の区切りが CRLF 前提で壊れた（`stage_3` の `}` の後が CRLF の途中で切れて次の `}` が直接結合）。

- **対応**: すべての追記後に Python 経由でファイルを読み込み、CRLF → LF に統一してから JSON 構文を検証した。`stages.json` は `stage_3` の `}` の後に `,` が無い／余計な `}` が出現する／末尾に `}` が無い、といった複数の不整合が出たため、行ごとに分解して正しい形（37行目を `  }` → `  },`、38行目 `}` を削除、49行目 `  },` → `  }`、末尾に `}` 追加）に組み直した
- **結果**: 最終形は `enemies.json` / `stages.json` とも LF、JSON 構文 valid、キー一覧が指示書と一致
- **影響**: ⚠ `AGENTS.md` の「**`edit_file` は使用しない**」「**`create_file` に長文を一度に渡さない**」は守られているが、「**`bash` での cat 追記は改行コードが環境依存**」という今回固有の落とし穴を踏まえる必要があった。次回は最初から Python 経由で追記すれば安全

### 5-2. `stages.json` の途中修復の必要性

EXEC の指示は「末尾の `}` を消し、最後の `}` に `,` を付けてから `cat >>` で追記し、最後に `}` を戻す」だった。`enemies.json` では `python` で末尾2文字を消して `,` を追加 → `cat >>` → 末尾 `}` を戻す、という流れで成功した。`stages.json` でも同じ手順を踏んだが、5-1 の CRLF 問題で行の構造が崩れ、JSON として壊れた。修復手順は5-1の通り。

### 5-3. `skills.json` の作成は `create_file` を使用

EXEC §5-2 は「`enemies/<id>/skills.json` は新規ファイルなので、フォルダを作って丸ごと書く」と指示していた。`create_file` ツールはフォルダ自動作成に対応したため、6ファイルすべて `create_file` で生成（LF、BOMなし、JSON構文valid）。

### 5-4. `user_character_id` には敵IDを書いた

EXEC §5-0 の指示通り、敵スキルの `user_character_id` には敵ID（例: `"user_character_id": "enemy_dbg_react"`）をそのまま書いた。欄名を変更していない。

### 5-5. テストプレイの未実施

ユーザー判断により、テストプレイとログ貼付は **未実施**。
playtest サブエージェントは basic プランでは利用不可、`run_scene` はクリック操作での戦闘進行の再現が困難（戦闘は複数ウェーブ・複数ユニットの相互作用があり、UI 経由でしか再現できない）。実行するとコストだけ溶けて実装側の判定材料が出ないため、ユーザー判断で停止した。

## 6. 未実装・保留にした項目

| 項目 | 理由 |
|---|---|
| `ja.csv` の再インポート | Godotエディタ側の操作（FileSystem で右クリック → 再インポート）であり、Ziva の自動操作範囲外。人間の手順 |
| `stage_order.json` の `"stage_1"` → `"stage_dbg"` への差し替え | EXEC §5-4 が「**Ziva は触らない。人間が手で1行差し替える**」と明記 |
| 起動ログ（EXEC 6-A: `skills validated: 45 entries, 0 errors, 1 warnings` / `basic attacks validated: 15 entries, 0 errors, 0 warnings`）の取得と貼付 | テストプレイ未実施のため未取得 |
| `battle_last.jsonl` の各行（EXEC 6-B）の抽出と貼付 | テストプレイ未実施のため未取得 |
| 画面の見た目（投射物・ダメージ数値）の確認 | EXEC §6-C として人間の担当。Ziva はヘッドレスで再現不可 |
| `IMPL_LOG_ENEMY_PARITY.md` の §6（完了条件）の各項目 | 本ログの §4 に転記した通り大半が未検証。本ファイルは JSON 差し込みまでで停止 |

## 7. 次の担当への引き継ぎ事項

- `stage_order.json` を `"stage_1"` → `"stage_dbg"` に差し替えてから F5
- `ja.csv` を再インポートしてから F5
- 起動時の出力パネルから `[MasterDataLoader] skills validated: ...` と `[MasterDataLoader] basic attacks validated: ...` の2行を原文ママで取得
- 冒険 → 「検証用ステージ」→ 5ウェーブ戦闘を進める（4波目までは通し、詰まったら F3 → `V`）
- 戦闘ログ `C:/Users/<ユーザー名>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl` を `EXEC_ENEMY_PARITY.md` §6-B の表に従って抽出
- 検証後、`stage_order.json` を必ず元に戻す
- 検証完了後、`PROJECT_STATUS.md` の宿題16に `enemies/` フォルダ・検証用6体・`stage_dbg`・`ja.csv` の6行・`MasterDataLoader.ENEMY_DIRS_OPTIONAL` を追加、宿題13に `ENEMY_DIRS_REQUIRED` の罠を追記

---

# 追記：`.gd` 側と検証結果（設計役・2026-08-17）

⚠ **上の §0〜§7 は Ziva の記録（JSON と `ja.csv` のみ）。以下は別担当の追記で、上を打ち消す箇所がある。**
⚠ **§4 と §6 の「テストプレイ未実施・未検証」は、そのあと人間が実施して解消した**（下の A-4）。§7 の引き継ぎ事項も消化済み。

## A-1. `.gd` の実装（設計役が担当。Ziva は1行も触っていない）

| パス | 内容 |
|---|---|
| `res://scripts/systems/master_data_loader.gd` | `DIR_ENEMIES` / `ENEMY_DIRS_REQUIRED`（空）/ `ENEMY_DIRS_OPTIONAL`（6体）。`_load_character_files()` が敵のフォルダも回す |
| `res://scenes/adventure/battle_controller.gd` | 敵へのスキル割り当て／敵のクールダウン／`_try_enemy_skill()`／`_fire_skill()` を `-> bool` に／報酬とクリア記録を story 限定に |
| `res://scenes/adventure/adventure_select.gd` | 検証用ステージの別枠3関数（§9） |
| `res://scripts/utils/state_keys.gd` | `STAGE_TYPE_DEBUG` |

- **マージは1本のまま。** 敵用に2本目を書かなかった（味方と敵でスキルIDが重複したときの赤が、片方だけ効く形になるため）
- **判定は1箇所のまま。** `_try_enemy_skill()` は `_fire_skill()` の戻り値を見るだけで、`SkillActivation.blocked_reason()` を呼んでいない
- **敵は攻撃間隔と同じ拍で、射程内でだけ撃つ。** 乱数なし（`skill_ids` の先頭から最初に撃てたもの）＝ログが再現する

## A-2. 初稿からの設計変更（人間の決定）

**検証用ステージの出し方を「`stage_order.json` の差し替え」から「`"debug"` 列の常設」へ変えた**（EXEC §9）。
1回目の検証で `spend_stamina(5)` と `mark_stage_cleared('stage_dbg')` がセーブに入ったのが直接の理由。
あわせて `stage_dbg` → **`stage_dbg_enemy_skill`** に改名（テストしたいこと1つにステージ1本）。

## A-3. Ziva の報告への回答（§5-1 の CRLF）

**この落とし穴は本物。** `AGENTS.md` は「追記は `bash` の `cat >>`」と書いているが、**Windows の bash では追記分が CRLF になり、元が LF のファイルに混ざる。**
Ziva の対処（Python で LF に統一し直す）で最終形は正しくなっており、**現物の JSON は valid・起動時の検証も 0 errors。**
⚠ **`AGENTS.md` の「ツールの制約」に1行足すかは人間の判断**（勝手に直していない）。

## A-4. 完了条件の検証結果（**§4 の未検証を置き換える**）

### 6-A ログ（人間が実行・出力パネルの原文）

- [x] 1：`skills validated: 45 entries, 0 errors, 1 warnings`（39＋6。⚠ 黄1本は `skill_dbg_dot_odd` の端数で正解）
- [x] 2：`basic attacks validated: 15 entries, 0 errors, 0 warnings`（9＋6）
- [x] 3・4：赤なし

### 6-B ファイル（設計役が `battle_last.jsonl` 435行を読んで判定）

- [x] 5：敵6体すべてが自分のスキルを撃った（`skill_edbg_react` / `_followup` / `_buff` / `_dot` / `_heal` / `_ranged`）
- [x] 6：`_heal` 6回・`_ranged` 3回・`_buff` 2回＝**クールダウンが回っている**
- [x] **7（この回の当たり所）**：`heal` 全8行の `dst` が `enemy_`。**敵視点の `team` 解決が正しい。この経路が実際に通ったのは初めて**
- [x] 8：`damage src=party_0` → `react src=party_0` → `damage dst=party_0`（敵の反射が殴ってきた相手に返った）
- [x] 9：`#react:` の cast の直後に `react` が続く箇所が**0件**＝10-2 の印が敵側でも効いている
- [x] 10：`dot` の `dst` が `party_2`・2秒間隔で3発。⚠ **直後に `react` 無し**＝宿題17の現状どおり（**直していない**）
- [x] 11：`status_add unit=enemy_3_0 kind=buff`
- [x] 12：`status_add` 5 ＝ `status_end` 4 ＋ `status_clear` 1。**宿題22（`status_clear` 追加後の実測）もここで解消**

### 6-C 画面（人間が実施）

- [x] 13〜17：**全項目確認済み**（別枠の行から入れる／本編の並びと解放が不変／検証用は報酬もクリア記録も付かない／敵の投射物が飛ぶ／敵のスキルでダメージ数値が出る）

### 副産物

- `status_end` の `why` が **`expire` 2件・`host_dead` 2件**とも出た（前回0件だった経路）
- 回復役は相方が死んだあと**自分だけを回復**している（`sort: "all"` が生存者だけを拾えている）

## A-5. 検証のあと戻したもの

- `resources/balance/master/parties.json` … **検証用3体 → `char_priest` / `char_archer` / `char_swordsman`**。⚠ **Ziva の担当外だが戻し忘れていた**（設計役が戻した）
- `stage_order.json` … **戻す運用そのものを廃止**（§9）

## A-6. 未実装・保留（Ziva の §6 に足すもの）

| 項目 | 理由 |
|---|---|
| 本編3体（`enemy_slime` ほか）にスキルを載せること | EXEC §7 の「やらないこと」。仕組みは効く |
| 敵の**選択AI**（誰を狙うか） | 今まで通り「一番近い相手」。EXEC §7 |
| 宿題17（DoT で購読が発火しない） | ログに見えるようにしただけ。**直していない** |
| 戦闘ログの完了条件15（落ちた戦闘） | この回でも正常終了だったため未検証のまま |
