# EXEC_WORKSHOP_RETIRE — 作業場の廃止

**段階11の前半**（`PLAN_IMPLEMENTATION.md` 3章）／ **`GAME_DESIGN.md` 9-3**／ 指示元は `NEXT_STEPS.md` §1。

**このタスクは「廃止だけ」。** 中間素材も装飾のくじも作らない。`recipes.json` は空になる。
**画面とコードは残す。** ギルドの「作業場」ボタンだけ隠す（`GAME_DESIGN` 9-3 で復活予定）。

---

## 1. 何をするか

| # | 対象 | 変更 |
|---|---|---|
| **A** | `resources/balance/master/recipes.json` | 14件を全削除し `{ "recipes": [] }` にする |
| **B** | `autoload/game_manager.gd` | `_sync_recipes_from_master()` の `master.is_empty()` 早期 return を外す（**§2 の決め1**） |
| **C** | `scenes/guild/guild_screen.gd` | `GUILD_SCENES` と `_nav_buttons` から `workshop` を外す |
| **D** | `scenes/guild/guild_screen.tscn` | `WorkshopButton` に `visible = false` を足す |
| **E** | `docs/PROJECT_STATUS.md` | 宿題を足す（§6） |
| **F** | `docs/NEXT_STEPS.md` / `docs/PLAN_IMPLEMENTATION.md` | 次のタスクへ／段階11の状態列を1行 |

---

## 2. 僕が自分で決めたもの（**人間が見ていない決め**）

> ⚠ **この章がこのEXECの本体。** 以下は `NEXT_STEPS.md` §1 に書かれていなかった判断。
> **違うと思ったら差し戻してよい。**

### 決め1（**大きい**）：`_sync_recipes_from_master()` の早期 return を外す

**現状のコード**（`game_manager.gd:3623-3627`）：

```gdscript
var master: Dictionary = MasterDataLoader.get_all_recipes()
if master.is_empty():
	push_warning("[GameManager] _sync_recipes_from_master: recipes.json が空か読み込めない")
	return
```

`recipes.json` を空にすると **この分岐に入って何もせずに戻る。**
その結果、`NEXT_STEPS` §1-3 が予想していた挙動は**どちらも起きない**（→ §5 のズレ24・25）。

**外す**と決めた。理由は3つ：

1. **決定5「進行中のキューは黙って落とすまま」が、外さないと成立しない。** early return だと `_normalize_crafting_queue()` に到達せず、既存セーブのキューが残り続ける
2. **`CLAUDE.md` 4番「状態にマスターデータを複製しない」に反する。** `recipes_unlocked` に消えたレシピIDが14件残り続ける
3. **「読めない」の保険は既に別の場所にある。** `MasterDataLoader._index_by()` は `root.is_empty()` のとき `push_error("empty or unreadable: ...")` を出す（`master_data_loader.gd:796-798`）。**GameManager 側の警告は二重で、しかも「意図的に空」と「壊れている」を区別できない**

`push_warning` の行も**消す**。`AGENTS.md`「正常系に警告を付けない」に従い、意図的に空の状態で毎回黄を出さないため。

> **代償**：`recipes.json` のファイル自体が壊れて読めなくなったとき、GameManager 側は黙って0件で流す。
> **ただし `MasterDataLoader` 側が赤（`empty or unreadable`）を出すので無音にはならない。**

### 決め2：`WORKSHOP_PATH` 定数と `workshop_button` の `@onready` は残す

`GUILD_SCENES` / `_nav_buttons` からは外すが、**定数とノード参照は消さない。**
復活（`GAME_DESIGN` 9-3）で1行ずつ戻すだけにするため。GDScript は未使用の `const` に警告を出さない。
**なぜ外れているのかをコメントに書く**（消し忘れと見分けるため）。

### 決め3：`E123` / `W21` を使わない（**新しい検証を足さない**）

「廃止だけ」の範囲外のため。`E118` の `recipes.json` の枝も**そのまま残す**（0件になるだけで、復活時に自動で効く）。

### 決め4：既存セーブのキューを捨てるときの黄は残す

`_normalize_crafting_queue()` の `push_warning("レシピが無いキューを捨てた: ...")` は残す。
**新規セーブでは出ない**（キューが空のため）。既存セーブで製作中のものがあった人にだけ1回出る。
決定5「黙って落とす」に対して警告が1本出るが、**データが消える側なので記録が残るほうがよい**と判断した。

### 決め5：`ja.csv` は1行も触らない

決定「`ui_guild_workshop_*` 10行を消さない」に加えて、**`ui_guild_workshop`（ボタンの表示名）と `ui_nav_workshop` も残す。**
`.tscn` の `label_key` が参照したままなので、消すとボタンにキー名が出る（隠していても復活時に踏む）。

### 決め6：Ziva に渡せる部分は**無い**

`recipes.json` は「空にする」だけで判断が要らず、`game_manager.gd` の変更と**同じタスクで通す必要がある**（片方だけ入ると挙動が変わる）。`ja.csv` は触らない。**分割しない。**

---

## 3. §1-3 の「予想できている落ち」4つの結論

| # | 予想 | 実コードで確かめた結果 |
|---|---|---|
| **1** | `_sync_recipes_from_master()` が `recipes_unlocked` を空にする／ログが `-> 0 recipes` | ⚠ **違う。早期 return で print に到達しない**（→ **ズレ24**）。**決め1で外す**。外したあとは予想どおり `-> 0 recipes (unlocked=0, skipped=0)` が出る |
| **2** | `_normalize_crafting_queue()` が既存キューを黙って落とす | ⚠ **違う。呼ばれない**（→ **ズレ25**）。**決め1で呼ばれるようになる**。落とすときは黄が1本出る（**決め4**） |
| **3** | `_index_by()` が空配列でどう振る舞うか未確認 | ✅ **確認済み。安全。** `{ "recipes": [] }` は `root.is_empty()` が `false`（キーが1つある）／`list` は `Array` → **ループ0回で空 Dictionary を返す。赤は出ない。** `print("loaded 0 entries from ...recipes.json")` だけ出る（`master_data_loader.gd:794-817`） |
| **4** | `E118` の `recipes.json` の枝が0件になる。素通りにならないか | ✅ **枝は0件になるが、`E118` 自体は生きている。** `stages` / `shop` / `research` / `chests` / 装飾（`E119`）の枝は全部残る。§4-B で**2箇所壊して確かめる** |

---

## 4. 完了条件

### §0 事前チェック（**設計役・人間に渡す前に終わっている**）

- 全23シナリオをヘッドレスで1回ずつ回し、**新しい赤が0件**であること
- `--check-only --script` で `game_manager.gd` / `guild_screen.gd` の `Parse Error` が0件であること
- 編集直後に `grep` で当たったことを確認（`CLAUDE.md` 2番）

### A. ログ（**設計役が `godot.log` を読む**）

| # | 見るもの |
|---|---|
| **A-1** | `[MasterDataLoader] loaded 0 entries from res://resources/balance/master/recipes.json` が出る |
| **A-2** | `[GameManager] _sync_recipes_from_master() -> 0 recipes (unlocked=0, skipped=0)` が出る |
| **A-3** | `_sync_recipes_from_master: recipes.json が空か読み込めない` の**黄が出ない** |
| **A-4** | ロード時の既定の出力が変わっていない：`items validated: 64 entries, 0 errors` ／ `skills validated: 79 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ `balance item refs validated: 0 errors` |
| **A-5** | `E118` の赤が0件（`recipes.json` の枝が消えても、他の枝で赤が出ない＝データ側は健全） |

### B. `E118` が生きていることの確認（**一時的にデータを壊す・2箇所**）

⚠ **確認後は必ず元に戻す。`git diff` が空になることを確かめる。**

| # | 壊す場所 | 期待 |
|---|---|---|
| **B-1** | `stages.json` の `stage_1` の `rewards.materials` のキーを1つ `construction_material_1` → `construction_material_9` に変える | `E118` の赤が1本出る（`stages.json (stage_1)`） |
| **B-2** | `research.json` のどれか1ノードの `cost_material_id` を実在しないIDに変える | `E118` の赤が1本出る（`research.json (<node_id>)`） |

### C. ファイル（**設計役が読む**）

| # | 見るもの |
|---|---|
| **C-1** | `resources/balance/master/recipes.json` が `{ "recipes": [] }` の1件のみ。JSON として妥当（`python -m json.tool` が通る） |
| **C-2** | `grep -c "recipe_id" resources/balance/master/recipes.json` が **0** |
| **C-3** | `guild_screen.gd` の `GUILD_SCENES` に `workshop` が無い（`grep -n '"workshop"' scenes/guild/guild_screen.gd` が **0件**）。`WORKSHOP_PATH` の定義行は**残っている** |
| **C-4** | `guild_screen.tscn` の `WorkshopButton` ブロックに `visible = false` がある |
| **C-5** | `localization/ja.csv` が**1バイトも変わっていない**（`git diff --stat` に出ない）。CR は `python -c "print(open('localization/ja.csv','rb').read().count(b'\x0d'))"` で **0** |
| **C-6** | `scenes/guild/workshop_screen.gd` / `.tscn` / `resources/balance/workshop_config.*` が**消えていない** |

### D. 画面（**人間だけ**）

⚠ **観測できる合図で書く。時間で書かない。**

| # | すること | 見るもの |
|---|---|---|
| **D-1** | 拠点 → ギルドを開く | ボタンが **5個**（倉庫／ショップ／育成／研究／戻る）。**「作業場」が並んでいない。空白も空行も残っていない** |
| **D-2** | ギルドの各ボタンを1つずつ押す | 4つとも従来どおりの画面へ遷移する。**押しても何も起きないボタンが無い** |
| **D-3** | ギルド → 倉庫 → 戻る → ギルド | 戻ったときもボタンは5個のまま（`_ready()` が2回目でも同じ） |
| **D-4** | 既存セーブでロードして拠点へ | **赤いエラーダイアログが出ない。** 素材・所持金・装備の表示が従来どおり |
| **D-5** | 倉庫・ショップ・育成・研究を一巡する | **どこにも `ui_guild_workshop` のようなキー名が生で出ていない** |

> **将来コードを変えたときに見る項目**（UIから到達できないので人間の確認項目にしない）：
> `start_craft("convert_con_to_tra")` を直接呼ぶと `false (recipe not found)` を返す／
> `get_available_recipes()` が空配列を返す。

---

## 5. ⚠ ドキュメントのズレ（**報告のみ・勝手に直さない**）

`NEXT_STEPS` §2-1 の通し番号の続き。**前回までで23件、未報告0件。今回3件。**

### ズレ24 — `NEXT_STEPS.md` §1-3

> 「`_sync_recipes_from_master()` が `recipes_unlocked` を空にする。起動ログが `-> 0 recipes (unlocked=0, skipped=0)` になる（赤ではない。正常）」

**実コードは違う。** `game_manager.gd:3625-3627` に `master.is_empty()` の早期 return があり、
**`print` に到達しない。`recipes_unlocked` も空にならない。** 出るのは `push_warning`（黄）1本。

→ **決め1で外す。外したあとは §1-3 の記述どおりになる。**

### ズレ25 — `NEXT_STEPS.md` §1-3

> 「`_normalize_crafting_queue()` が既存のキューを黙って落とす」

**ズレ24 の早期 return により、そもそも呼ばれない。**
さらに、落とすときは `push_warning("レシピが無いキューを捨てた: ...")` が出るので**「黙って」でもない**（`game_manager.gd:3672`）。

→ **決め1で呼ばれるようになる。黄は残す（決め4）。**

### ズレ26 — `AGENTS.md`「GameManagerの状態構造」表（**今回の領域外**）

> `PENDING_CHESTS` … `[{chest_id, chest_type, source, obtained_at, opened, rewards}]`

**実装は `{instance_id, chest_id, source, obtained_at, opened, rewards}`**（`state_keys.gd:96` に `CHEST_INSTANCE_ID = "instance_id"`）。
表には `instance_id` が無く、代わりに**存在しない `chest_type` が載っている**（`chest_type` は `ChestScheduleEntry`（`.tres`）側の `@export` 名であって、状態のキーではない）。

**前回の宝箱1本化（`EXEC_CHEST_REGISTRY`）で `AGENTS.md` への追記が漏れたもの。**
→ **今回は触らない。次に `AGENTS.md` を触る回で直す。**

---

## 6. `PROJECT_STATUS.md` へ足す宿題

1. **作業場が空のまま残っている。** 画面とコード（`workshop_screen` / `CRAFTING_QUEUE` / `WorkshopConfig` / `start_craft()` / `collect_craft()`）は動くが、`recipes.json` が0件で**到達経路が無い**。復活は `GAME_DESIGN` 9-3（中間素材の製作＋装飾のランダム製作）
2. **素材の変換経路が消えた。** `GAME_DESIGN` 9-3 は「ショップに一本化」と書いているが、**`shop.json` に変換に相当する枠があるかは未確認**。段階12（バランス実測）の前に見ること
3. **`_sync_recipes_from_master()` の「読めない」保険が `MasterDataLoader` 側の赤だけになった**（決め1）。`recipes.json` を復活させる回で、GameManager 側にも戻すか判断する
4. **`guild_screen.gd` の `WORKSHOP_PATH` が未使用のまま残っている**（決め2）。復活しないと決めたら消す
5. **ズレ26**（`AGENTS.md` の `PENDING_CHESTS` の表が実装と違う）

---

## 7. 変えないもの

⚠ **`NEXT_STEPS` §2-2 に従い、`GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確認済み。**

- `scenes/guild/workshop_screen.gd` / `.tscn`
- `resources/balance/workshop_config.gd` / `.tres` ／ `autoload/balance.gd` の `@export var workshop` ／ `balance.tscn` の `ExtResource`
- `GameStateKeys.CRAFTING_QUEUE` / `RECIPES_UNLOCKED` と関連定数
- `GameManager.start_craft()` / `collect_craft()` / `get_available_recipes()` / `_normalized_recipe()` / `get_max_queue_slots()` / `_craft_duration_default()`
- `MasterDataLoader.get_recipe()` / `get_all_recipes()` / `PATH_RECIPES` ／ `_validate_all_item_refs()` の `recipes.json` の枝
- `localization/ja.csv` **全行**
- `tests/debug_boot.gd` の `SCENARIOS` 23本
