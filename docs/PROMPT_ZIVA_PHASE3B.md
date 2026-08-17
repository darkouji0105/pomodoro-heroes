# Ziva に渡すプロンプト（段階3の後半① — 購読／JSON と ja.csv だけ）

**渡すファイル（4点セット・AGENTS.md の規約どおり）**

1. `AGENTS.md`
2. `docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE3B.md`
3. `docs/02_exec/IMPL_LOG_TEMPLATE.md`
4. （PRE_PLAN は無し。**このタスクは設計・実装方針が EXEC に確定済み**）

---

## 以下をそのまま貼る

`AGENTS.md` と `docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE3B.md` を読んでから着手すること。

### あなたの担当は「§5 だけ」

このタスクの `.gd` 4ファイル（`skill_schema.gd` / `status_registry.gd` /
`skill_resolver.gd` / `skill_runtime.gd`）は**すでに書き終わっている。**

**あなたが触るのは次の4ファイルだけ。**

| ファイル | やること |
|---|---|
| `resources/balance/master/characters/char_debug_mix/skills.json` | 7件目を足す（EXEC §5-1 のブロックをそのまま） |
| `resources/balance/master/characters/char_debug_status/skills.json` | 7件目を足す（EXEC §5-2） |
| `resources/balance/master/characters/char_debug_life/skills.json` | 7件目を足す（EXEC §5-3） |
| `localization/ja.csv` | 3行を足す（EXEC §5-4） |

⚠ **`.gd` を1文字も触らないこと。** 「JSON に合わせてコード側も直す」は不要。
直す必要があると思ったら、**直さずに報告して止まること。**

### JSON の中身は EXEC §5-1〜5-3 に全文がある

**考えて書かない。コピーする。** 倍率・寿命・`status_id` はすべて決定済みで、
`status_id` は**あとから改名できない**（`CLAUDE.md` 4番）。

### 差し込み方（⚠ `edit_file` はこのプロジェクトで動かない）

3つの `skills.json` はどれも末尾が

```
	}
}
```

の2行で終わっている。**最終行を削り、手前の `\t}` に `,` を足してから `cat >>` で追記する。**
手順は EXEC §5-5 にコマンドごと書いてある。

⚠ **ファイル全体を閉じる最後の `}` を戻し忘れないこと。** JSON が壊れると、
そのキャラのスキルが**全部**無音で消える（エラーは1つも出ない）。

### `ja.csv`

- **追記前に `grep` で同じキーが無いことを確認する**（`AGENTS.md`「2回書かない」）
- **UTF-8（BOMなし）。** BOM が付くと1行目が `﻿keys` になり翻訳が全滅する
- 再インポートは**人間がやる**。あなたはやらない

### 書き終えたあとの確認（あなたがやる範囲）

1. `grep -n "skill_dbg_react_thorns" resources/balance/master/characters/char_debug_mix/skills.json`
   が**0件でないこと**（3ファイルとも同様に確認する）
2. 各 `skills.json` の**キーが7個あること**（`grep -c '^\t"skill_' <ファイル>` が `7`）
3. `grep -n "ui_battle_skill_dbg_react_" localization/ja.csv` が**3件**
4. `head -1 localization/ja.csv` が `keys` で始まっていること（BOM が付いていない）
5. インデントがタブであること（`grep -n "^    " <ファイル>` が**0件**）

⚠ **Godot を起動して動かそうとしないこと。**
EXEC §6-A（ログ）と §6-C（画面）は**人間が実機で確認する項目**であり、
あなたの担当ではない。ヘッドレスで再現しようとすると必ず時間を溶かす。

### 止まる条件

- **1ファイルへの書き込みが2回失敗したら中止して報告する**（方法を変えても回数に数える）
- 1つの症状に対して試すのは**2手まで**。3手目に進まず報告する
- **JSON が壊れたと思ったら、直そうとせず `git diff` を出して報告する**

### 最後に

`docs/02_exec/IMPL_LOG_TEMPLATE.md` の型に沿って
`docs/03_log/IMPL_LOG_SKILL_TEMPLATE_PHASE3B.md` を生成すること。

⚠ **「5. 指示書からの逸脱・迷った判断」を空欄にしない。**
差し込み位置・カンマの扱いで必ず判断が要る。何をどう判断したか書くこと。
