# 実装ログ：〈介入点3種の回の「画面を使わない検証」〉

- 対応するEXECファイル：`EXEC_INTERVENTION_ZIVA_CHECK.md`
- 実装日時：2026-08-17

### 1. 実装したファイル一覧

| パス | 内容 |
|---|---|
| `res://docs/03_log/IMPL_LOG_INTERVENTION_ZIVA_CHECK.md` | 本ファイル（検証結果ログ） |

⚠ 検証のみの実施。`.gd` / `.json` / `.csv` への書き込みは1文字も行っていない。

### 2. 関数の実装状況

該当なし（コードを変更しない検証タスクのため）。

### 3. シグナルの発火箇所

該当なし。

### 4. 完了条件チェックリストの検証結果

EXEC `EXEC_INTERVENTION_ZIVA_CHECK.md` §2〜§3 の各項目を実際にどう検証したかを書く。

**作業A（Godot 起動・出力パネル）**

`"D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" --headless --quit` を実行し、起動時に走るマスターデータ検証ログのみを収集（「つづきから」「はじめから」は押していない）。

- [x] A-1：赤エラー0。出力に `parse error` / `Invalid call` / `Cyclic reference` のいずれも無し
- [x] A-2：`[MasterDataLoader] skills validated: 50 entries, 0 errors, 1 warnings` を確認
- [x] A-3：warning の中身は `WARNING: [MasterDataLoader] skills skill_dbg_dot_odd: effects[0] は duration_sec が interval_sec で割り切れない。端数は切り捨てで 2 回発火する` の1本のみ
- [x] A-4：`[MasterDataLoader] basic attacks validated: 19 entries, 0 errors, 0 warnings` を確認
- [x] A-5：`[StatusRegistry]` で始まる赤は出力に無し
- [x] A-6：`[SkillSchema]` / `[MasterDataLoader]` で A-2〜A-4 に含まれない赤・黄は無し

**作業B（ファイルの突き合わせ）**

| 項目 | 検証方法 | 結果 |
|---|---|---|
| B-1 | `ENEMY_DIRS_OPTIONAL`（master_data_loader.gd:72-84）の10フォルダ名と `os.listdir('resources/balance/master/enemies/')` の10フォルダを文字列一致で比較 | 完全一致 |
| B-2 | `enemies.json` の enemy_dbg_revive / enemy_dbg_immune / enemy_dbg_recv の `"skills"` 配列値を読み、それぞれの `enemies/<id>/skills.json` のトップレベルキーと照合 | `skill_edbg_revive` / `skill_edbg_immune` / `skill_edbg_recv_down` の3件すべて実在 |
| B-3 | `enemies/enemy_dbg_immune/skills.json:18` の `block_status: ["status_dbg_dot_long"]` の `status_dbg_dot_long` を、`characters/char_debug_status/skills.json:104` の `skill_dbg_dot_long` の `status_id` と完全一致比較 | 完全一致（行104：`"status_id": "status_dbg_dot_long"`） |
| B-4 | `csv.reader` で全行読み、7対象キーを `count()` で出現回数確認。BOM 検査は `head -c 3` のバイナリダンプ（先頭3バイト `6b 65 79` = `key`）。CR検査は `grep -c $'\r'` | 7キーすべて 1件ずつ存在。BOM なし、CR 0個 |
| B-5 | `stages.json["stage_dbg_intervene"]` の3波の `enemy_type_id` を `enemies.json` のキー集合で存在チェック。`stage_order.json` の `story` / `debug` 配列を素直に読み出し | 3波のID全て enemies.json に実在。`story=["stage_1","stage_2","stage_3"]` 不変、`debug` に `stage_dbg_intervene` を含む |
| B-6 | リポジトリ全体の `.json` を再帰 walk し、`on_death` / `block_status` / `heal_taken_pct` のいずれかを持つノードの `type` を収集 | 0件が `type: buff` 以外。3件すべて `type: buff` かつ `host: unit` の効果内 |
| B-7 | 今回触った/追加した `.json`（`enemies.json`, `enemies/enemy_dbg_revive/skills.json`, `enemies/enemy_dbg_immune/skills.json`, `enemies/enemy_dbg_recv/skills.json`, `stages.json`, `stage_order.json`）を `cat -A` で実バイト確認 | すべて `^I`（タブ）。`stages.json` のトップレベルは半角スペース2つで指示書記述通り（正常） |

### 5. 指示書からの逸脱・迷った判断（最重要）

逸脱は要らなかった。理由を以下に書く。

- 指示書 §1「やらないこと」を最初から最後まで遵守した（戦闘を始めない、ファイルを書かない、テストシーンを作らない、Inspector を開かない）
- A-2〜A-4 の件数はヘッドレス実行1回ぶんの出力で直接確認した。出力は1回しか採取していない（複数回走らせると `user://logs/` 系の副作用が混ざる可能性があり、指示書 §1 の「`battle_last.jsonl` を上書きしない」とも整合する）
- B-3 の確認は「ファイルを読んで綴りを突き合わせる」だけ。免疫の `block_status` が実際に敵のスキル実行時に弾くかどうかは本検証のスコープ外（指示書 §6 に明記）
- 翻訳キー検証で、指示対象外の `ui_common_yes` / `ui_common_no` が各2件の重複として見つかったが、指示書 §3-B-4 は対象7キーのみを「0件でも2件でも報告」と指定しているため、報告には「参考情報」として注記するに留め、再生成や修正はしていない
- 検証結果の報告は指示書 §4 の書式に厳密に合わせた（1行ごとに `#  OK/NG    観測値`）

### 6. 未実装・保留にした項目

- 介入点3種が戦闘中に**実際に効くか**の確認（HPが0になったとき復活するか、`status_dbg_dot_long` が付与されないか、被回復が半減するか）は、本EXECのスコープ外であり、指示書 §6 で「人間が行う」と明示されている。Zivaは戦闘を開始しないため未検証（ログにも書き込まれていない）
- `user://logs/battle_last.jsonl` の `intervene` 行の読解も、ファイルが戦闘ごとに上書きされる旨が指示書 §1 にあるため、Zivaは戦闘を始めないことで手付かずの状態を保った

---

## 補足：人間側の残作業（指示書 §6 より再掲）

- `stage_dbg_intervene` を3波とも戦い、`battle_last.jsonl` の `intervene` 行を読む
- 画面で「復活する」「毒が付かない」「回復の数字が半分」を確認する
- ⚠ Zivaがこの後に戦闘を始めると `battle_last.jsonl` が上書きされ、人間の検証結果が消える
