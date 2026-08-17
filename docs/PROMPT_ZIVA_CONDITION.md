# Ziva に渡すプロンプト（段階3の後半② 条件 — JSON と `ja.csv` ＋ テストプレイ）

**渡すのはこのファイル1つだけ。** `AGENTS.md` は Ziva が自動で読む。

---

## 以下をそのまま貼る

着手前に `docs/02_exec/EXEC_SKILL_CONDITION.md` を読むこと。**特に §5 が担当範囲で、書く中身の全文がそこにある。**
実装ログの型は `docs/02_exec/IMPL_LOG_TEMPLATE.md` にある（最後に使う）。
**それ以外の `docs/` 配下は読まないこと**（`AGENTS.md` の規約）。

### あなたの担当は「§5 とテストプレイ」

このタスクの `.gd` 6ファイル（`status_registry.gd` / `skill_schema.gd` / `skill_runtime.gd` /
`battle_log.gd` / `battle_debug_panel.gd` / `master_data_loader.gd`）は**すでに書き終わっている。**
条件（毎フレーム評価する発火源）の仕組みは入っている。
**データが無いので、いま動かしても条件を持つ状態が1つも存在せず、何も起きない。**

**あなたが触るのは次のファイルだけ。**

| ファイル | やること |
|---|---|
| `resources/balance/master/enemies.json` | 検証用の敵 `enemy_dbg_cond` を**1体**足す（EXEC §5-1） |
| `resources/balance/master/enemies/enemy_dbg_cond/skills.json` | **新規フォルダ＋新規ファイル**（EXEC §5-2）。⚠ `enemies/` 配下のフォルダ新設は**人間が承認済み** |
| `resources/balance/master/characters/char_debug_status/skills.json` | **8件目**のスキルを足す（EXEC §5-3） |
| `resources/balance/master/characters.json` | `char_debug_status` の `"skills"` 配列に**1行**（EXEC §5-4） |
| `resources/balance/master/stages.json` | `stage_dbg_condition` を1件足す（EXEC §5-5） |
| `resources/balance/master/stage_order.json` | `"debug"` 配列に1行（EXEC §5-6）。⚠ **`"story"` は1文字も触らない** |
| `localization/ja.csv` | **4行**足す（EXEC §5-7） |

⚠ **`.gd` を1文字も触らないこと。** 「JSON に合わせてコード側も直す」は不要。
直す必要があると思ったら、**直さずに報告して止まること。**
⚠ **既存のスキル45件・敵9体・ステージ4本を1文字も変えない**（上の表で「足す」と書いたもの以外）。
⚠ **`parties.json` は触らない**（人間が差し替える。下記の手順2）。

### JSON の中身は EXEC §5 に全文がある

**考えて書かない。コピーする。** 能力値・倍率・寿命・IDはすべて決定済みで、
**`status_id` はあとから改名できない**（`CLAUDE.md` 4番）。

⚠ **`condition` の中の `status_id` は、その効果の `status_id` とは別物**（見たい相手の状態のID）。
`skill_dbg_cond_poison` の `condition.status_id` は **`status_edbg_dot`** で正しい。書き換えないこと。

⚠ **`user_character_id` に敵のIDを書くのは正しい。** 欄名を変えないこと。

⚠ **`enemy_dbg_cond` の `hp` が 20、`atk` が 5 なのは意図。**
他の検証用の敵（`hp: 80`）と揃えようとしないこと。**揃えると条件が真になるまでに何十秒もかかる。**

⚠ **`char_debug_status/skills.json` の7件目（`skill_dbg_react_followup`）だけインデントが1タブ深い。**
既知の見た目の問題。**真似しないこと。既存の7件は直さないこと。**

### 差し込み方（⚠ `edit_file` はこのプロジェクトで動かない）

`enemies.json` / `characters.json` / `stages.json` / `char_debug_status/skills.json` はどれも末尾が

```
	}
}
```

の形で終わっている。**最後の `}` を削り、手前のエントリに `,` を足してから `cat >>` で追記し、最後に `}` を戻す。**

- `enemies/enemy_dbg_cond/skills.json` は**新規ファイル**。フォルダを作って丸ごと書く
- `stage_order.json` は3行しかないので**丸ごと書き直す**
- `characters.json` は**配列に1行足すだけ**なので、`"skill_dbg_react_followup"` の行に `,` を付けて次の行を入れる

⚠ **ファイル全体を閉じる最後の `}` を戻し忘れないこと。** JSON が壊れると、
起動時にマスターデータが全部読めなくなる。

⚠ **`cat >>` で追記すると追記分が CRLF になる**（前回踏んだ）。元が LF のファイルに混ざると壊れる。
**追記したら改行コードを確かめること。**

⚠ **`ja.csv` は UTF-8（BOMなし）。** BOM が付くと1行目が壊れて翻訳が全滅する。

---

## テストプレイと報告（ここまでやる）

⚠ **このタスクは事故が全部無音になる。** 条件が一度も真にならなくても、常に真でも、
エラーは1つも出ず、画面を見ても分からない。**だから下のログを現物で貼ることが検証の本体。**

### 手順

1. **`ja.csv` を再インポート**（FileSystem で右クリック → 再インポート）
2. **人間に `resources/balance/master/parties.json` の `members` の差し替えを頼む。**
   検証用3体（`char_debug_status` / `char_debug_life` / `char_debug_mix`）にする。
   ⚠ **自分で書き換えないこと。** 検証が終わったら人間が戻す
3. **F5 で実行 → 冒険 → 一覧の末尾「▼ 検証用」の `検証用・条件` に入る**
4. **1波目**（`enemy_dbg_cond`）… **何も押さずに、敵を倒しきるまで待つ**。
   ⚠ **敵の HP が半分を割ったあとも10秒ほど戦わせること**（条件が真になった後のダメージが要る）
5. **2波目**（`enemy_dbg_dot`）… 波が変わったら、**`char_debug_status` の「毒への備え」を1回だけ押す。**
   そのあとは**何も押さずに30秒ほど待つ**（敵の毒が付いて、切れて、また付くのを見る）
6. 戦闘が終わったら**タイトルまで戻るかウィンドウを閉じる**（ログが書き出される）

### 報告する内容（**下の2つだけ。画面の見た目は報告しなくてよい**）

**① 出力パネル** — 次の2行をそのまま貼る。

```
[MasterDataLoader] skills validated: ?? entries, ? errors, ? warnings
[MasterDataLoader] basic attacks validated: ?? entries, ? errors, ? warnings
```

⚠ 期待値は **skills 47 / 0 errors / 1 warnings**、**basic attacks 16 / 0 errors / 0 warnings**。
⚠ **黄1本は `skill_dbg_dot_odd` の端数で、出るのが正解。** 黄が2本以上なら**そのメッセージも貼る**。
赤が1つでも出たら**そこで止めて報告する。**

**② 戦闘ログ** — 次のファイルを開いて、下の表を埋める。

```
C:/Users/<ユーザー名>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl
```

1行1イベントの JSON。**該当する行を1本ずつコピーして貼ること**（「出ていました」ではなく現物）。

| 見るもの | 探し方 | 貼るもの |
|---|---|---|
| **条件の行があるか** | `"ev":"condition"` | **全部の行**（多くても十数行のはず） |
| 条件の行が多すぎないか | `"ev":"condition"` の**件数** | 件数の数字 |
| **敵の与ダメージの変化** | `"ev":"damage"` で `"src":"enemy_dbg_cond` を含む行 | **最初の3行と最後の3行** |
| 味方の与ダメージの変化 | `"ev":"damage"` で `"src"` に `char_debug_status` を含む行 | **最初の3行と最後の3行** |
| 敵の毒 | `"status":"status_edbg_dot"` を含む行 | **全部の行** |
| 味方の条件付きバフ | `"status":"status_dbg_cond_poison_atk"` を含む行 | **全部の行** |
| 状態の釣り合い | `status_add` の件数 ／ `status_end` の件数 ／ `status_clear` の `count` の合計 | 3つの数字 |
| **本編に影響が無いか** | 本編の `stage_1` を1面通したあとのログに `"ev":"condition"` が何行あるか | 件数の数字（**0 が正解**） |

⚠ **判定はしなくてよい。行をそのまま貼れば設計役が判定する。**
⚠ **「動きました」と書かない。** 貼った行が根拠になる。

⚠ **`"ev":"condition"` が1行も無い場合も、そのまま「0行」と報告すること。**
**これが一番あり得る結果で、一番重要な情報。** 勝手に原因を探して `.gd` を触らないこと。

### やらないこと

- **画面の見た目の確認**（敵のダメージ数値が跳ねるか・`F3` → `P` の表示）は**人間の担当**。
  再現しようとして時間を使わないこと
- **`.gd` の修正**
- **バランスの調整**（強すぎ・弱すぎは報告だけ）
- 1つの症状に**3手目を試さない**（`AGENTS.md`「切り分けは2手まで」）。2手で直らなければ止めて報告する

---

## 最後に

`docs/03_log/IMPL_LOG_SKILL_CONDITION.md` を `docs/02_exec/IMPL_LOG_TEMPLATE.md` の型で生成する。
**「5. 指示書からの逸脱・迷った判断」を空欄にしないこと。**
