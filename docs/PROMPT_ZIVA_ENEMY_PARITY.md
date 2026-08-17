# Ziva に渡すプロンプト（敵の管理を味方と同じにする — JSON と `ja.csv` ＋ テストプレイ）

**渡すファイル（4点セット・`AGENTS.md` の規約どおり）**

1. `AGENTS.md`
2. `docs/02_exec/EXEC_ENEMY_PARITY.md`
3. `docs/02_exec/IMPL_LOG_TEMPLATE.md`
4. （PRE_PLAN は無し。**設計・実装方針は EXEC に確定済み**）

---

## 以下をそのまま貼る

`AGENTS.md` と `docs/02_exec/EXEC_ENEMY_PARITY.md` を読んでから着手すること。

### あなたの担当は「§5 とテストプレイ」

このタスクの `.gd` 3ファイル（`master_data_loader.gd` / `battle_controller.gd` ほか）は
**すでに書き終わっている。** 敵のスキル読み込み・敵のクールダウン・敵が撃つ処理は入っている。
**データが無いので、いま動かしても敵は今まで通り通常攻撃しかしない。**

**あなたが触るのは次のファイルだけ。**

| ファイル | やること |
|---|---|
| `resources/balance/master/enemies.json` | 検証用の敵6体を足す（EXEC §5-1 をそのまま） |
| `resources/balance/master/enemies/<敵ID>/skills.json` | **6ファイル新規作成**（EXEC §5-2）。⚠ フォルダ6つの新設は**人間が承認済み** |
| `resources/balance/master/stages.json` | `stage_dbg` を1件足す（EXEC §5-3） |
| `localization/ja.csv` | 13行足す（EXEC §5-5） |

⚠ **`.gd` を1文字も触らないこと。** 「JSON に合わせてコード側も直す」は不要。
直す必要があると思ったら、**直さずに報告して止まること。**
⚠ **`stage_order.json` は触らない**（人間が差し替える）。
⚠ **既存の敵3体・ステージ3件・スキル39件を1文字も変えない。**

### JSON の中身は EXEC §5 に全文がある

**考えて書かない。コピーする。** 能力値・倍率・寿命・IDはすべて決定済みで、
**`status_id` はあとから改名できない**（`CLAUDE.md` 4番）。

⚠ **`user_character_id` に敵のIDを書くのは正しい**（EXEC §5-0）。欄名を変えないこと。

### 差し込み方（⚠ `edit_file` はこのプロジェクトで動かない）

`enemies.json` と `stages.json` はどちらも末尾が

```
	}
}
```

の形で終わっている。**最後の `}` を削り、手前のエントリに `,` を足してから `cat >>` で追記し、最後に `}` を戻す。**

⚠ **ファイル全体を閉じる最後の `}` を戻し忘れないこと。** JSON が壊れると、
起動時にマスターデータが全部読めなくなる。

⚠ **`create_file` に長文を一度に渡さない**（トークン上限で失敗する）。`enemies.json` の6体は
**2〜3体ずつに分けて追記する。**

---

## テストプレイと報告（ここまでやる）

### 手順

1. **`ja.csv` を再インポート**（FileSystem で右クリック → 再インポート）
2. **人間に `stage_order.json` の差し替えを頼む。**`"stage_1"` → `"stage_dbg"`。
   ⚠ **自分で書き換えないこと。** 検証が終わったら人間が戻す
3. **F5 で実行 → 冒険 → 一覧の先頭の検証用ステージに入る**
4. **5ウェーブ最後まで進める**（詰まったら F3 → `V` で強制勝利。ただし**4波目までは通すこと**）
5. 戦闘が終わったら**タイトルまで戻るかウィンドウを閉じる**（ログが書き出される）

### 報告する内容（**下の2つだけ。画面の見た目は報告しなくてよい**）

**① 出力パネル（EXEC 6-A）** — 次の2行をそのまま貼る。

```
[MasterDataLoader] skills validated: ?? entries, ? errors, ? warnings
[MasterDataLoader] basic attacks validated: ?? entries, ? errors, ? warnings
```

⚠ 期待値は **skills 45 / 0 errors / 1 warnings**、**basic attacks 15 / 0 errors / 0 warnings**。
⚠ **黄1本は `skill_dbg_dot_odd` の端数で、出るのが正解。** 黄が2本以上なら**そのメッセージも貼る**。
赤が1つでも出たら**そこで止めて報告する。**

**② 戦闘ログ（EXEC 6-B）** — 次のファイルを開いて、下の表を埋める。

```
C:/Users/<ユーザー名>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/battle_last.jsonl
```

1行1イベントの JSON。**該当する行を1本ずつコピーして貼ること**（「出ていました」ではなく現物）。

| 見るもの | 探し方 | 貼るもの |
|---|---|---|
| 敵が自分で撃ったか | `"ev":"cast"` で `"unit":"enemy_` | 1行 |
| 繰り返し撃っているか | 同じ敵の `cast` の件数 | 件数 |
| **敵の回復の行き先** | `"ev":"heal"` | **全部の行** |
| 敵の反射 | `"ev":"react"` の前後2行ずつ | 5行 |
| 敵の追撃 | `#react:dealt_damage` を含む `cast` の前後2行 | 5行 |
| 敵のDoT | `"ev":"dot"` | 2行と、その直後の行 |
| 敵のバフ | `"ev":"status_add"` で `"unit":"enemy_` | 1行 |
| 状態の釣り合い | `status_add` の件数 ／ `status_end` の件数 ／ `status_clear` の `count` の合計 | 3つの数字 |

⚠ **判定はしなくてよい。行をそのまま貼れば設計役が判定する。**
⚠ **「動きました」と書かない。** 貼った行が根拠になる。

### やらないこと

- **画面の見た目の確認**（投射物が飛ぶか・ダメージ数値が出るか）は**人間の担当**。再現しようとして時間を使わないこと
- **`.gd` の修正**
- **バランスの調整**（強すぎ・弱すぎは報告だけ）
- 1つの症状に**3手目を試さない**（`AGENTS.md`「切り分けは2手まで」）。2手で直らなければ止めて報告する

---

## 最後に

`docs/03_log/IMPL_LOG_ENEMY_PARITY.md` を `IMPL_LOG_TEMPLATE.md` の型で生成する。
**「5. 指示書からの逸脱・迷った判断」を空欄にしないこと。**
