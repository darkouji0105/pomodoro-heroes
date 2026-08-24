# EXEC — **機能の段階解放**（段階9）

前提は `docs/NEXT_STEPS.md` §1。仕様の正は `docs/GAME_DESIGN.md` 9-5（解放順）と 9-6（詰みの回避）。直前の回は `EXEC_RUNES.md`。

⚠ **器はもう在る。⚠ 誰も閉じていないだけ。** ⚠ **`UNLOCKED_SCREENS` / `unlock_screen()` / `is_screen_unlocked()` / `screen_unlocked` シグナルは全部揃っていて、⚠ [base_screen.gd:102](../../scenes/base/base_screen.gd#L102) が既に `btn.visible` で出し分けている。**

⚠ **この回で増えるのは「閉じる対象」と「開く引き金」の2つだけ。**

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-24）

| # | 決めたこと | 中身 |
|---|---|---|
| **1** | ⚠ **解放の単位は「画面IDを増やす」** | ⚠ **ギルドの中も個別の `screen_id` にして、⚠ `UNLOCKED_SCREENS` で一律に閉じる。⚠ 判定を2本にしない**（⚠ **`ui_nav_<screen_id>` の綴り合わせが機械的に効く＝`AGENTS.md`**） |
| **2** | ⚠ **閉じている機能は「出さない」** | ⚠ **灰色で見せない。⚠ 9-5 の狙いは「順番に見せる」こと** |
| **3** | ⚠ **引き金はステージのクリア** | ⚠ **`story.stages.<id>.cleared`。⚠ `story.current_chapter` は使わない** |
| **4** | ⚠ **装備と育成は同時に開く** | ⚠ **9-5 は「装備 → 育成」だが、⚠ 装備画面へは育成画面からしか入れない**（ズレ29）。⚠ **導線を変えずに 9-5 の狙い（拾ったものがすぐ強さになる）を満たす** |
| **5** | ⚠ **装飾とルーンも同じフラグで「行を出さない」** | ⚠ **どちらも画面ではなく装備画面の中の行**（ズレ30）。⚠ **`screen_id` を「機能ID」として使う** |
| **6** | ⚠ **倉庫は装備と同時に開く** | ⚠ **9-5 の10段に倉庫が無い。⚠ 宝箱を開けるのは倉庫だけなので、⚠ 閉じたままだと `GAME_DESIGN` 9-6「詰みの回避」に正面からぶつかる** |

---

## 0-1. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め・要確認**）

⚠ **重い順。**

| # | 決めたこと | なぜそうしたか |
|---|---|---|
| **1** | ⚠ **どのステージで何が開くかは `stages.json` の `unlocks` 欄で持つ**（⚠ **`.gd` に表を書かない**） | ⚠ **引き金（ステージ）と対象（機能）が同じ行に並ぶ。⚠ ステージが増えれば刻みも自動で増える**（⚠ **いまは本番3本しかない＝§0-1 の2**）。<br>⚠ **`.tres` に置かない**：⚠ **`E118` / `E125` の網に入らず、⚠ 改名が無音で壊れる**（⚠ **`EXEC_CHEST_REGISTRY` が `pomodoro_config.tres` から `chests.json` へ移したのと同じ理由**） |
| **2** | ⚠ **4段に畳む**（⚠ **9-5 は10段だが、⚠ 引き金が4つしか無い**） | ⚠ **本番ステージは `stage_1` / `stage_2` / `stage_3` の3本だけ。⚠ 「最初から」を足しても4つ。**<br>⚠ **9-5 の相対順は崩さずに畳む**（§2 の表）。⚠ **ステージが増えたら `unlocks` を分けるだけで刻める** |
| **3** | ⚠ **`unlocked_screens` は状態に持ち続け、⚠ 起動時に「クリア済みから流し込み直す」** | ⚠ **`AGENTS.md`「マスターデータと状態を同期する型」。⚠ 研究ツリーと同じ形。**<br>⚠ **完全な都度計算にしない**：⚠ **既存セーブは5画面が `true` で入っている。⚠ 都度計算にすると、⚠ 遊んでいた人の画面が次の起動で消える**（⚠ **一度開いたものは閉じない**） |
| **4** | ⚠ **同期は `unlock_screen()` を通す**（⚠ **`_state` を直接書かない**） | ⚠ **`screen_unlocked` シグナルが飛ぶのはあの1本だけ。⚠ 直接書くと拠点が追従しない** |
| **5** | ⚠ **`workshop` は `unlocks` に1度も書かない** | ⚠ **作業場は廃止中で `.tscn` 側が `visible = false`（`EXEC_WORKSHOP_RETIRE`）。⚠ 二重に閉じる形にすると、⚠ 復活させるときにどちらを開けばよいか読めなくなる**（§9 の宿題） |
| **6** | ⚠ **拠点（9-5 の #8）は閉じない** | ⚠ **`base_screen` はハブで、⚠ 閉じると何も操作できなくなる。⚠ 9-5 の「拠点」は `GAME_DESIGN` 10章の建設のことで、⚠ その画面はまだ無い**（§9 の宿題） |
| **7** | ⚠ **`settings` と `scenario` は最初から開ける** | ⚠ **どちらも 9-5 の10段に無い。⚠ 中身が `placeholder_screen` なので閉じても開けても見えるものは変わらない** |
| **8** | ⚠ **`E125` を新設する** | ⚠ **`unlocks` に知らない `screen_id` を書くと、⚠ 「クリアしても開かない」形で無音に壊れる。⚠ `E118` を足した回と同じ判断** |
| **9** | ⚠ **`F4` に「画面を全部解放」を足す** | ⚠ **解放を入れると、⚠ 新規セーブから装備画面へ行くのに `stage_1` を倒す必要が出る。⚠ 検証のたびに戦うのは現実的でない**（⚠ **`tests/` は検証用。§9 の宿題「リリース前に消す」に足す**） |
| **10** | ⚠ **どのステージで何が開くかは「勘」** | ⚠ **ステージが3本しか無いので選択肢がほぼ無いが、⚠ 本数が増えたら見直す前提。§9 の宿題** |

---

## 1. 着手前に確認した実コード（2026-08-24・**`grep` 済み**）

| | 事実 | 実コード |
|---|---|---|
| **A** | ⚠ **`is_screen_unlocked()` を読んでいるのは1箇所だけ** | ⚠ **[base_screen.gd:102](../../scenes/base/base_screen.gd#L102) の `btn.visible = GameManager.is_screen_unlocked(screen_id)`。⚠ 既に「出さない」形**（決定2 と一致） |
| **B** | ⚠ **画面IDは5つ** | ⚠ **`SCREEN_GUILD` / `SCREEN_ADVENTURE_SELECT` / `SCREEN_POMODORO` / `SCREEN_SETTINGS` / `SCREEN_SCENARIO`**（`state_keys.gd:234-238`） |
| **C** | ⚠ **起動時に5つとも `true`** | ⚠ **`initial_state_config.tres` の `initially_unlocked_screens`** |
| **D** | ⚠ **ギルドの中は `sub_screen_id` で、⚠ 解放を1つも見ていない** | ⚠ **`guild_screen.gd:26-31` の `GUILD_SCENES`（`warehouse` / `shop` / `training` / `research`）。⚠ `workshop` は `.tscn` で `visible = false`** |
| **E** | ⚠ **装備画面へは育成画面からしか入れない** | ⚠ **[training_screen.gd:292](../../scenes/guild/training_screen.gd#L292)。⚠ ギルドに装備のボタンは無い**（ズレ29） |
| **F** | ⚠ **クリアを書く口は1本** | ⚠ **`GameManager.mark_stage_cleared()`（`:5082`）。⚠ 呼ぶのは [battle_controller.gd:1630](../../scenes/adventure/battle_controller.gd#L1630) の1箇所** |
| **G** | ⚠ **本番ステージは3本** | ⚠ **`stage_order.json` の `story`。⚠ 引き金は最大4つ（「最初から」込み）**（§0-1 の2） |
| **H** | ⚠ **ステージの解放は別の仕組み** | ⚠ **`adventure_select.gd:230` が「1つ前がクリア済みか」で判定。⚠ `unlocked_screens` を見ていない。⚠ 触らない** |
| **I** | ⚠ **`settings` と `scenario` は `placeholder_screen` に飛ぶ** | ⚠ **`base_screen.gd:21-22`** |

---

## 2. 解放の表（**`stages.json` の `unlocks`**）

| 引き金 | 開くもの（`screen_id`） | 9-5 の段 |
|---|---|---|
| ⚠ **最初から**（`initial_state_config.tres`） | `adventure_select` ／ `settings` ／ `scenario` | ⚠ **#1 戦闘** |
| ⚠ **`stage_1` クリア** | `guild` ／ `equipment` ／ `training` ／ `warehouse` | ⚠ **#2 装備・#3 育成**（決定4・6） |
| ⚠ **`stage_2` クリア** | `pomodoro` ／ `decoration` | ⚠ **#4 ポモドーロ・#5 装飾** |
| ⚠ **`stage_3` クリア** | `research` ／ `shop` ／ `rune` | ⚠ **#6 研究・#7 ショップ・#10 ルーン** |
| — | ⚠ **`workshop` は1度も開かない**（§0-1 の5） | #9 作業場 |
| — | ⚠ **拠点（#8）は閉じない**（§0-1 の6） | #8 拠点 |

⚠ **相対順は 9-5 のまま。⚠ 畳んだだけ**（§0-1 の2）。

---

## 3. 実装（ファイル別）

### 3-A. `scripts/utils/state_keys.gd` … **画面IDを7つ足す**

```gdscript
const SCREEN_EQUIPMENT: String = "equipment"
const SCREEN_TRAINING: String = "training"
const SCREEN_WAREHOUSE: String = "warehouse"
const SCREEN_RESEARCH: String = "research"
const SCREEN_SHOP: String = "shop"
const SCREEN_WORKSHOP: String = "workshop"
# ⚠ 画面ではなく「機能」。装備画面の中の行を出し分ける（決定5）。
const SCREEN_DECORATION: String = "decoration"
const SCREEN_RUNE: String = "rune"
```

- ⚠ **`training` / `warehouse` / `research` / `shop` / `workshop` は `guild_screen.gd` の `sub_screen_id` と同じ綴り**（⚠ **既にその文字列で書かれている。⚠ 定数に寄せるだけ**）
- ⚠ **`ui_nav_<screen_id>` で引ける形を保つ**（`AGENTS.md`）

### 3-B. `resources/balance/master/stages.json` … **`unlocks` を3行**

```json
"stage_1": { ..., "unlocks": ["guild", "equipment", "training", "warehouse"] }
```

- ⚠ **`stage_2` … `["pomodoro", "decoration"]` ／ `stage_3` … `["research", "shop", "rune"]`**
- ⚠ **デバッグステージには書かない**（⚠ **書くと `debug_boot` を回すたびに解放が進む**）
- ⚠ **トップレベルのインデントだけ半角スペース2つ**（⚠ **このファイルの既存の書き方**）

### 3-C. `resources/balance/initial_state_config.tres` … ⚠ **人間の作業**

⚠ **`initially_unlocked_screens` を `["guild","adventure_select","pomodoro","settings","scenario"]` → ⚠ `["adventure_select","settings","scenario"]` にする**（⚠ **`guild` と `pomodoro` を外す**）。

- ⚠ **`.tres` の直接編集は設計役にはできない**（`CLAUDE.md`「触ってよいもの・悪いもの」）。⚠ **Inspector で配列から2件消してもらう**（§7-A）
- ⚠ **これをやらないと、⚠ 新規開始でギルドとポモドーロが最初から開いたままになる**（⚠ **`stages.json` 側は「足す」ことしかしない**）

### 3-D. `autoload/game_manager.gd` … 同期の1本

| 関数 | 中身 |
|---|---|
| **新設** `_sync_unlocked_screens_from_master()` | ⚠ **クリア済みステージの `unlocks` を全部 `unlock_screen()` に通す。⚠ 既に `true` のものは何もしない** |
| **新設** `get_stage_unlocks(stage_id) -> Array[String]` | ⚠ **`stages.json` の `unlocks`。⚠ 画面もローダーもここを通す** |
| **変更** `mark_stage_cleared()` | ⚠ **末尾で `_sync_unlocked_screens_from_master()` を呼ぶ**（⚠ **クリアした瞬間に開く**） |
| **変更** `_ready()` / ロード後 | ⚠ **`_sync_research_tree_from_master()` の隣で1回呼ぶ** |

- ⚠ **`unlock_screen()` を通すこと**（§0-1 の4。⚠ **`screen_unlocked` が飛ぶのはあの1本だけ**）
- ⚠ **一度開いたものを閉じない**（§0-1 の3）。⚠ **`unlocked_screens` から消す枝を書かない**
- ⚠ **`print` を1行出す**（⚠ **`_sync_recipes_from_master()` と同じ形。⚠ 完了条件がこれを見る**）

### 3-E. `scripts/systems/master_data_loader.gd` … **`E125`**

| # | 出すもの |
|---|---|
| **E125** | ⚠ **`stages.json` の `unlocks` に知らない `screen_id` がある**（⚠ **赤**） |

- ⚠ **見るもの**：⚠ **`unlocks` が Array か／⚠ 要素が `GameStateKeys` の画面IDの一覧に在るか**
- ⚠ **画面IDの一覧は `GameManager` が返す1本を通す**（⚠ **`get_all_screen_ids()`。⚠ 定数の並びを2箇所に書かない**）
- ⚠ **`_validate_all_item_refs()` の中に足す**（⚠ **行を増やさない。⚠ `stages.json` を既に見ている**）

### 3-F. `scenes/guild/guild_screen.gd` … ボタンごとに出し分け

- ⚠ **`_nav_buttons` を回して `visible = GameManager.is_screen_unlocked(sub_id)`**（⚠ **`base_screen.gd:102` と同じ1行**）
- ⚠ **`sub_screen_id` の文字列リテラルを `GameStateKeys` の定数に置き換える**
- ⚠ **`workshop_button` は触らない**（§0-1 の5。⚠ **`.tscn` の `visible = false` のまま**）
- ⚠ **`screen_unlocked` を購読して再描画する**（⚠ **ギルドを開いたままクリアすることは無いが、⚠ 拠点と同じ形に揃える**）

### 3-G. `scenes/guild/training_screen.gd` … 「装備」ボタンを出し分け

- ⚠ **`is_screen_unlocked(SCREEN_EQUIPMENT)` で `visible`**
- ⚠ **決定4 で同時に開くので普段は必ず出る。⚠ ステージが増えて刻んだときに効く**

### 3-H. `scenes/guild/equipment_screen.gd` … 装飾とルーンの行を出し分け（**決定5**）

- ⚠ **枠の行（`_create_part_rows()`）で、⚠ その枠に刺さる種類が全部閉じているなら行ごと出さない**
- ⚠ **判定は1本にする**：⚠ **`GameManager.is_part_kind_unlocked(kind)`**（⚠ **`rune` → `SCREEN_RUNE` ／ それ以外 → `SCREEN_DECORATION`**）
  - ⚠ **`part_kind` で `if` を分けているように見えるが、⚠ これは「種類 → 機能ID」の表であって挙動の分岐ではない。⚠ `_part_slot_kinds()` と同じ立場**（⚠ **表を1つ足すだけ**）
- ⚠ **`[刺す]` の一覧（`_rebuild_part_items()`）も同じ判定を通す**

### 3-I. `tests/debug_overlay.gd` … 「画面を全部解放」（**§0-1 の9**）

- ⚠ **`get_all_screen_ids()` を回して `unlock_screen()`**
- ⚠ **`workshop` も開ける**（⚠ **`.tscn` 側で閉じているので画面には出ない。⚠ それでよい**）

### 3-J. `tests/debug_boot.gd` … **`SCENARIOS` に1行**

| シナリオ | `kind` | 見るもの |
|---|---|---|
| ⚠ **`unlock`** | ⚠ **`KIND_REPORT`** | ⚠ **解放が段階的に進むか。⚠ 戦闘を回さない** |

⚠ **`scenario=unlock` が出すもの**：

1. ⚠ **新規開始の `unlocked_screens`**（⚠ **`adventure_select` / `settings` / `scenario` の3つだけ**）
2. ⚠ **`stage_1` → `stage_2` → `stage_3` の順にクリアさせ、⚠ そのつど開いた `screen_id` の差分**
3. ⚠ **`workshop` が最後まで開かないこと**
4. ⚠ **一度開いたものが閉じないこと**（⚠ **クリアを取り消しても開いたまま**）
5. ⚠ **`stages.json` の `unlocks` 全件と、⚠ 画面IDの一覧の突き合わせ**
6. ⚠ **足した検証が本当に出るか**（⚠ **2箇所で壊す。⚠ メモリ上の状態だけ**）

⚠ **`layout` も回す**（⚠ **ナビのボタンが減ると器の幅が変わる。⚠ この事故は3回踏んでいる**）。

### 3-K. `localization/ja.csv` … ⚠ **0行**（**足さない**）

⚠ **`grep` した結果、必要なキーは全部在った**（`AGENTS.md`「書く前の確認を手順に入れる」）：

- ⚠ **`ui_nav_warehouse` / `_shop` / `_training` / `_research` / `_workshop`**（⚠ **ギルドの5つ。⚠ 既に在る**）
- ⚠ **`ui_nav_training_equipment`（装備）**（⚠ **育成画面のボタンが既に使っている**）
- ⚠ **`decoration` / `rune` は名前を出す場所が無い**（⚠ **ボタンではなく「行を出すか出さないか」なので**）

⚠ **`ui_nav_equipment` は作らない。⚠ 使う場所が無い定数とキーを増やさない。**

### 3-L. 触らないファイル

⚠ **`adventure_select.gd`**（⚠ **ステージの解放は別の仕組み。§1 の H**）
⚠ **`workshop_screen.gd` / `guild_screen.tscn` の `WorkshopButton`**（§0-1 の5）
⚠ **戦闘のコード全部**（⚠ **`mark_stage_cleared()` の呼び出し1行も変えない**）
⚠ **`runes.json` / `items.json` / `part_config.gd`**（⚠ **段階8の成果物**）

---

## 4. 変えないもの

- ⚠ **`UNLOCKED_SCREENS` の形**（`{screen_id: bool}`）／ ⚠ **`unlock_screen()` が書き込む唯一の口**
- ⚠ **`screen_unlocked` シグナル**
- ⚠ **`mark_stage_cleared()` を呼ぶ場所**（⚠ **`battle_controller.gd:1630` の1箇所**）
- ⚠ **ステージの解放判定**（`adventure_select.gd:230`）
- ⚠ **`base_screen.gd:102` の1行**（⚠ **既に正しい。⚠ 触らない**）

---

## 5. 完了条件 — **§0 事前チェック**（⚠ **設計役・ヘッドレス。⚠ 人間に渡す前に終わっている**）

1. ⚠ **全シナリオ（既存25 ＋ 新規 `unlock` の26本）で `ERROR:` / `Parse Error` が1行も出ないこと**（`training` を除く）
   - ⚠ **例外：`unlock` は赤が1本出るのが正解**（⚠ **§6-D の12 で `E125` をわざと出している。⚠ `drops` が黄を1本多く出すのと同じ形**）
2. ⚠ **`items validated: 89 entries, 0 errors` ／ `runes validated: 25 entries, 0 errors`**（⚠ **変わっていないこと**）
3. ⚠ **`E125` が0件**
4. ⚠ **黄が増えていないこと**（⚠ **`ja.csv` 再インポート前の15本は §13-6 のとおり**）
5. ⚠ **触った `.gd` 全部で `--check-only --script` が `Parse Error` 0件**

---

## 6. 完了条件 — **ログ / ファイル**（⚠ **設計役が読む。⚠ 人間の仕事は無い**）

### 6-A. 解放が進むか（`scenario=unlock`）

1. ⚠ **新規開始で開いているのは3つだけ**（`adventure_select` / `settings` / `scenario`）
2. ⚠ **`stage_1` クリア → `guild` `equipment` `training` `warehouse` の4つが増える**
3. ⚠ **`stage_2` クリア → `pomodoro` `decoration` の2つが増える**
4. ⚠ **`stage_3` クリア → `research` `shop` `rune` の3つが増える**
5. ⚠ **`workshop` は最後まで `false`**
6. ⚠ **`screen_unlocked` が、⚠ 新しく開いた件数ぶんだけ飛ぶ**（⚠ **既に開いているものでは飛ばない**）
7. ⚠ **クリアを取り消してから同期しても、⚠ 開いたものが閉じない**

### 6-B. 突き合わせ

8. ⚠ **`stages.json` の `unlocks` に書いた `screen_id` が全部、画面IDの一覧に在る**
9. ⚠ **画面IDのうち `unlocks` に1度も出てこないもの＝`workshop` と、⚠ 最初から開く3つだけ**

### 6-C. ファイル

10. ⚠ **`ja.csv` の行数と、⚠ キーの重複0件**
11. ⚠ **`stages.json` が JSON として読める**（⚠ **`unlocks` を足した3件**）

### 6-D. ⚠ 足した検証が本当に出るか（**2箇所で壊す。⚠ 壊すのはメモリ上の状態**）

12. ⚠ **`unlocks` に知らない `screen_id` を混ぜる → `E125` が赤を出す**（⚠ **`items validated: 89 entries, 0 errors` が `1 errors` に変わる**。⚠ **壊すのは `MasterDataLoader._cache_stages` だけ。⚠ `stages.json` は触らない**）
13. ⚠ **`unlocked_screens` から1件消してから同期 → クリア済みなら開き直る**（⚠ **同期が本当に効いていること**）

---

## 7. 完了条件 — **画面**（⚠ **人間だけ**）

### 7-A. ⚠ 先にやってもらうこと

- [ ] ⚠ **`initial_state_config.tres` の `initially_unlocked_screens` から `guild` と `pomodoro` を消す**（§3-C。⚠ **Inspector で配列の2件を削除**）
- [ ] ⚠ **`ja.csv` の再インポート**（⚠ **段階8のぶんも含めてここで1回**）
- [ ] ⚠ **タイトルから「最初から」で新規開始する**（⚠ **既存セーブでは確かめられない。⚠ 一度開いたものは閉じないため**）

### 7-B. ⚠ 見るもの

- [ ] ⚠ **新規開始の拠点に、⚠ 「冒険」だけが出ている**（⚠ **ギルドもポモドーロも出ていない**）
- [ ] ⚠ **`stage_1` を勝つと、⚠ 拠点に戻った時点でギルドが出ている**（⚠ **画面を出入りしなくても出るか**）
- [ ] ⚠ **ギルドの中に「倉庫」「育成」が出て、⚠ 「研究」「ショップ」が出ていない**
- [ ] ⚠ **育成 → キャラを選ぶと「装備」ボタンが出る**
- [ ] ⚠ **装備画面で、⚠ 等級3以上の装備に宝石枠の行が出ていない**（⚠ **装飾は `stage_2` まで閉じている**）
- [ ] ⚠ **`stage_2` を勝つと、⚠ 拠点にポモドーロが出て、⚠ 装備画面に宝石枠・護符枠・紋章枠の行が出る**
- [ ] ⚠ **その時点でもルーン枠の行だけ出ていない**
- [ ] ⚠ **`stage_3` を勝つと、⚠ ギルドに研究とショップが出て、⚠ 装備画面にルーン枠の行が出る**
- [ ] ⚠ **作業場は最後まで出ない**
- [ ] ⚠ **拠点の下段が横にはみ出していない**（⚠ **ボタンが減る回**）
- [ ] ⚠ **`F4` の「画面を全部解放」を押すと、⚠ 拠点に戻った時点で全部出る**
- [ ] ⚠ **⚠ 新規開始で `stage_1` に勝てるか**（⚠ **装備も育成も閉じた状態で戦うことになる。⚠ 勝てないなら §2 の表を見直す＝`GAME_DESIGN` 9-6「詰みの回避」**）

---

## 8. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- ⚠ **ステージを増やしたとき**：⚠ **`unlocks` を分けて刻めるか**（§0-1 の2）
- ⚠ **作業場を復活させるとき**：⚠ **`.tscn` の `visible = false` を戻し、⚠ `unlocks` に `workshop` を足す**（⚠ **2箇所ある。§0-1 の5**）
- ⚠ **拠点の建設画面を作るとき**：⚠ **9-5 の #8 の置き場**
- ⚠ **セーブを跨いだとき**：⚠ **`save_version` を上げるかどうか**（⚠ **キーは増えないので今回は上げない**）

---

## 9. 終わったあとに足す宿題（`PROJECT_STATUS.md`）

1. ⚠ **どのステージで何が開くかが「勘」**（⚠ **ステージが3本しか無いので選択肢がほぼ無い**）
2. ⚠ **9-5 の10段のうち「拠点」（#8）の置き場が無い**（⚠ **`GAME_DESIGN` 10章の建設画面がまだ無い**）
3. ⚠ **作業場は2箇所で閉じている**（⚠ **`.tscn` の `visible = false` と、⚠ `unlocks` に書かないこと**）
4. ⚠ **`F4` の「画面を全部解放」はリリース前に消す**
5. ⚠ **ズレ29・ズレ30 を `GAME_DESIGN` 9-5 に反映するか**（⚠ **勝手に直していない**）
6. ⚠ **`settings` と `scenario` が `placeholder_screen` のまま**

---

## 10. コミットメッセージ

```
feat(unlock): ステージのクリアで機能を段階解放（画面ID7つ＋stages.json の unlocks）
```

---

## 11. ⚠ ドキュメントのズレ（**報告。勝手に直さない**）

| # | ズレ |
|---|---|
| ⚠ **29** | ⚠ **`GAME_DESIGN` 9-5 は「装備 → 育成」の順だが、⚠ 装備画面へは育成画面からしか入れない**（[training_screen.gd:292](../../scenes/guild/training_screen.gd#L292)）。⚠ **順どおりに解放すると装備に到達できない。⚠ 決定4 で「同時に開く」にした** |
| ⚠ **30** | ⚠ **9-5 の10段のうち、画面として閉じられるのは6つだけ。** ⚠ **装飾（#5）とルーン（#10）は装備画面の中の行 ／ 拠点（#8）は常に居るハブ ／ 倉庫はどの段にも無い。⚠ 決定5・6 で埋めた** |

⚠ **どちらも `GAME_DESIGN.md` は直していない。⚠ 直すなら人間の指示が要る**（§9 の宿題5）。

---

## 12. ⚠ 実施結果（**2026-08-24・設計役がヘッドレスで実行して判定**）

### 12-1. ⚠ 触ったファイル（**10本。新規1本**）

| ファイル | 中身 |
|---|---|
| ⚠ **`docs/02_exec/EXEC_SCREEN_UNLOCK.md`**（新規） | この指示書 |
| `scripts/utils/state_keys.gd` | ⚠ **画面ID8つ**（⚠ **`workshop` を含めたので7つではなく8つ**） |
| `resources/balance/master/stages.json` | ⚠ **`unlocks` を3行** |
| `autoload/game_manager.gd` | ⚠ **`get_all_screen_ids()` / `get_stage_unlocks()` / `_sync_unlocked_screens_from_master()` / `is_part_kind_unlocked()` ＋ `STAGE_MASTER_UNLOCKS` ＋ 呼び出し3箇所** |
| `scripts/systems/master_data_loader.gd` | ⚠ **`E125`** |
| `scenes/guild/guild_screen.gd` | ⚠ **ボタンごとの出し分け ＋ 文字列リテラルを定数へ** |
| `scenes/guild/training_screen.gd` | ⚠ **「装備」ボタンの出し分け** |
| `scenes/guild/equipment_screen.gd` | ⚠ **枠の行と刺せる一覧の出し分け** |
| `tests/debug_overlay.gd` | ⚠ **「画面を全部解放」** |
| `tests/debug_boot.gd` | ⚠ **`scenario=unlock` ＋ `LAYOUT_SCENES` に `guild_screen.tscn`** |

⚠ **`localization/ja.csv` は0行**（§3-K。⚠ **必要なキーが全部在った**）。
⚠ **`docs/PROJECT_STATUS.md` にも宿題と実装済みの行を足した。**

### 12-2. ⚠ §5 事前チェックの結果

| # | 項目 | 結果 |
|---|---|---|
| 1 | 全シナリオ（**26本**・`training` を除く） | ✅ **`red=0`（25本）** ／ ⚠ **`unlock` だけ `red=1`（意図的・§6-D の12）** |
| 2 | `items validated` / `runes validated` | ✅ **`89 entries, 0 errors` ／ `25 entries, 0 errors`**（⚠ **変わっていない**） |
| 3 | `E125` | ✅ **0件**（⚠ **壊したときだけ1件**） |
| 4 | 黄 | ⚠ **平常 `16`**（⚠ **既知の1本 ＋ `ja.csv` 未再インポートの15本**）／ ⚠ **`parts` と `drops` だけ `17`**（⚠ **どちらも意図的**） |
| 5 | `--check-only --script`（8ファイル） | ✅ **`Parse Error` 0件** |

### 12-3. ⚠ §6-A / §6-B の実測（`scenario=unlock`）

```
--- 画面IDの一覧（GAME_DESIGN.md 9-5 の解放順）---
  13 件: [adventure_select, guild, equipment, training, warehouse, pomodoro,
          decoration, research, shop, workshop, rune, settings, scenario]

--- stages.json の unlocks ---
  stage_1    -> ["guild", "equipment", "training", "warehouse"]
  stage_2    -> ["pomodoro", "decoration"]
  stage_3    -> ["research", "shop", "rune"]
  ⚠ unlocks に1度も出てこないもの: ["adventure_select", "workshop", "settings", "scenario"]

--- 段階的に開くか ---
  最初            [adventure_select, guild, pomodoro, settings, scenario]
  ⚠ initial_state_config.tres がまだ直っていない: [guild, pomodoro] が最初から開いている
  stage_1 クリア -> +["equipment", "training", "warehouse"]
  stage_2 クリア -> +["decoration"]
  stage_3 クリア -> +["research", "shop", "rune"]
  workshop は開いたか -> false
```

| # | 項目 | 結果 |
|---|---|---|
| 1 | 新規開始で3つだけ | ⚠ **まだ5つ。⚠ `.tres` が人間の作業だから**（§7-A の1つ目。⚠ **その行が数字で出るようにした**） |
| 2 | `stage_1` で4つ増える | ⚠ **3つ増えた**（⚠ **`guild` が `.tres` で既に開いているため。⚠ 直せば4つになる**） |
| 3 | `stage_2` で2つ増える | ⚠ **1つ増えた**（⚠ **同上。`pomodoro` が既に開いている**） |
| 4 | `stage_3` で3つ増える | ✅ **`research` `shop` `rune`** |
| 5 | `workshop` は開かない | ✅ **`false`** |
| 6 | `screen_unlocked` が新しく開いた件数ぶんだけ | ✅ **`_sync_unlocked_screens_from_master() -> 3 / 1 / 3 opened`** |
| 7 | クリアを取り消しても閉じない | ✅ **§6-D の13（b）** |
| 8 | `unlocks` の `screen_id` が全部一覧に在る | ✅ **`E125` が0件** |
| 9 | `unlocks` に出てこないのは4つだけ | ✅ **最初から開く3つ ＋ `workshop`** |

### 12-4. ⚠ §6-D の実測（**3箇所で壊した**）

| # | 壊したもの | 結果 |
|---|---|---|
| 12 | ⚠ **`_cache_stages["stage_1"].unlocks` に知らない `screen_id`**（⚠ **メモリ上のキャッシュだけ**） | ✅ **`items validated: 89 entries, 0 errors` → `1 errors`。⚠ `E125` の赤が1本出た。⚠ 戻したら元に戻った** |
| 13-a | ⚠ **`unlocked_screens` から `shop` を消す** | ✅ **`false` → 同期 → `true`**（⚠ **同期が本当に効いている**） |
| 13-b | ⚠ **`stage_3` のクリアを消して同期** | ✅ **`rune=true shop=true`**（⚠ **一度開いたものは閉じない**） |

⚠ **3件とも `git diff` にデータファイルの変更は入っていない。**

### 12-5. ⚠ `scenario=layout`

- ✅ **`guild_screen.tscn` を `LAYOUT_SCENES` に足して「開いた（最小幅 0）」**
- ✅ **拠点の下段は `ResourceRow` 1064 / `NavigationButtons` 536（画面幅 1280）。⚠ はみ出していない**
- ⚠ **測っているのは「全部開いている状態」。⚠ ボタンが減ったときの幅は測っていない**（⚠ **減るぶんには溢れないので、⚠ §7-B の目視で足りる**）

### 12-6. ⚠ 正直に書くこと

1. ⚠ **§6-A の1〜3 は「まだ通っていない」。** ⚠ **`initial_state_config.tres` は `.tres` なので設計役には直せない**（`CLAUDE.md`）。
   ⚠ **人間が §7-A の1つ目をやると通る。⚠ 通ったかどうかが `scenario=unlock` の1行に出るようにした**（「`initial_state_config.tres` は直っている」）。
2. ⚠ **`scenario=unlock` は赤が1本出る。** ⚠ **`E125` をわざと出しているぶん**（⚠ **`drops` が黄を1本多く出すのと同じ形**）。⚠ **`unlock` で赤が2本以上出たら本物。**
3. ⚠ **画面のコードは「パースと、`layout` で開くこと」までしか確かめていない。** ⚠ **ボタンが本当に消えるかは人間しか見られない**（§7-B）。
4. ⚠ **新規開始で `stage_1` に勝てるかを確かめていない。** ⚠ **装備も育成も閉じた状態で戦うことになる**（§7-B の最後）。⚠ **勝てないなら §2 の表を見直す＝`GAME_DESIGN` 9-6「詰みの回避」。**
5. ⚠ **既存セーブでは §7-B が確かめられない。** ⚠ **一度開いたものは閉じないので、⚠ 新規開始が要る**（§7-A の3つ目）。

### 12-7. ⚠ 実装中に自分で決めたもの（**§0-1 に無いもの・後出し**）

| # | 決めたこと | なぜ |
|---|---|---|
| **11** | ⚠ **画面IDは8つ足した**（⚠ **§3-A に書いた7つ ＋ `workshop`**） | ⚠ **`guild_screen.gd` の `sub_screen_id` に `workshop` が既に在り、⚠ 定数に寄せる以上そこだけ文字列リテラルを残せない** |
| **12** | ⚠ **`ja.csv` を1行も足さなかった** | ⚠ **`grep` したら `ui_nav_warehouse` 〜 `_workshop` と `ui_nav_training_equipment` が全部在った。⚠ 使う場所が無い `ui_nav_equipment` を作らない** |
| **13** | ⚠ **`scenario=unlock` に「`.tres` が直っているか」の行を足した** | ⚠ **設計役が直せない作業の結果を、⚠ 人間が数字で確かめられるようにするため。⚠ 「やったつもり」で先に進むのを防ぐ** |
| **14** | ⚠ **`LAYOUT_SCENES` に `guild_screen.tscn` を足した** | ⚠ **段階9でボタンの出し分けを足した画面。⚠ 「器を足した回・件数を変えた回は必ず `layout` を回す」の対象** |
| **15** | ⚠ **`E125` の破壊テストで赤を1本出すことにした**（⚠ **`unlock` の `red=0` を諦めた**） | ⚠ **`E125` が本当に出るかは、⚠ 実際に出させないと分からない。⚠ `drops` に前例がある（黄）**。⚠ **代償：`unlock` の赤の平常値が 1 になる**（§12-6 の2） |
