# EXEC — **ルーン**（段階8）

前提は `docs/NEXT_STEPS.md` §1。仕様の正は `docs/GAME_DESIGN.md` 7-5 / 7-7。
装飾の本体は `docs/02_exec/EXEC_DECORATION.md`（⚠ **ルーンはそこの4種類目**）。直前の回は `EXEC_PARTY_PRESETS.md`。

⚠ **この回で初めて「装飾が戦闘の挙動を変える」。** ⚠ 宝石・護符・紋章は `part_stat` / `part_base` / `part_roll_max` でステータスに乗るだけだったが、⚠ **ルーンは1つも足さない。受け口が別に要る。**

⚠ **人間が画面で見て変わるのは3つ**：⚠ **等級5以上の武器・アクセにルーンが刺さること／⚠ 移動系ルーンの移動量を装備画面で選べること／⚠ スキルを撃つとルーンが先に発動すること。**

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**）

### 0-1. ⚠ `NEXT_STEPS` §1-2 の3つ（2026-08-24）

| # | 決めたこと |
|---|---|
| **1** | ⚠ **`parts` の型は変えない。** ⚠ **段階は `item_id` の連番**（`part_rune_move_1` 〜 `_5`）。⚠ **要素は `{item_id, roll}` のままで、⚠ ルーンの `roll` は 0 固定**。⚠ **重ねる＝上位IDに置き換える** |
| **2** | ⚠ **全種類入れる**：⚠ **バフ／デバフ／移動／回復／シールド**（⚠ **5種 × 5段階 ＝ 25件**） |
| **3** | ⚠ **「ルーンのかけら」は作らない。** ⚠ **入手は `F4` のデバッグパネル** |

### 0-2. ⚠ この回で決まったもの（2026-08-24・**着手前に確認した**）

| # | 決めたこと | 中身 |
|---|---|---|
| **4** | ⚠ **ルーンの中身は `runes.json` を新設して置く**（⚠ **マスター7本目**） | ⚠ **設計役の推奨は「`items.json` の欄」だったが覆された。** ⚠ **`items.json` は ID と `part_kind` だけ、⚠ 挙動（CD・効果・移動量）は `runes.json`。**<br>⚠ **代償：宿題1「マスターが6本目になった」が未判断のまま7本目になる**（§10 に書く） |
| **5** | ⚠ **移動したあとは「秒でロック」** | ⚠ **瞬間移動させ、⚠ その後 `rune_move_lock_sec` のあいだ `_step_unit()` の移動の枝だけを止める**（⚠ **攻撃はできる**）。⚠ **秒は `PartConfig`（`.tres`）で調整する**（⚠ **`GAME_DESIGN` 7-5 が「実装時に触ってから決める」と書いていた箇所**） |
| **6** | ⚠ **移動量は装備画面のルーン枠の行で選ぶ** | ⚠ **刺す・外すと同じ場所。⚠ 導線が1本になる。⚠ 保存先はキャラプリセットの5つ目のキー**（`GAME_DESIGN` 7-7） |

---

## 0-3. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め・要確認**）

⚠ **重い順。⚠ ここが「毎回それで助かっている」一覧。**

| # | 決めたこと | なぜそうしたか |
|---|---|---|
| **1** | ⚠ **ルーンの発動は `SkillRuntime.cast()` をそのまま通す**（⚠ **2本目の発火経路を作らない**） | ⚠ **`cast()` は `skill_data` を引数で受け、⚠ `MasterDataLoader` を引き直さない**（`skill_runtime.gd:109-119`。⚠ **実コードで確認**）。⚠ **だから `runes.json` から組み立てた辞書をそのまま渡せる。**<br>→ ⚠ **バフ・デバフ・回復・シールドは `SkillResolver` → `StatusRegistry` の既存の1本に乗る。⚠ 状態のマス・`BattleLog`・回復のポップも自動で付く**（⚠ **人間の指示「重なるなら流用し、2本目を作らない」**） |
| **2** | ⚠ **クールダウンは `BattleUnit.skill_cooldowns` を使う。⚠ キーはルーンの `item_id`** | ⚠ **`skill_cooldowns` は文字列をキーにした Dictionary**（`unit.gd:109`）。⚠ **`start_cooldown()` / `is_skill_ready()` がそのまま効く。⚠ 「ルーンごとに固有のクールダウン」（`GAME_DESIGN` 7-5）に器を1つも足さずに済む**<br>⚠ **`haste` は通す**（`BattleFormula.cooldown()`）。⚠ **スキルと違う扱いにしない** |
| **3** | ⚠ **ルーンは `part_stat: ""` / `part_base: 0` / `part_roll_max: 0`。⚠ 加算の判定は「`part_stat` が空か」で分ける** | ⚠ **`_add_part_stats()` は `part_stat` が10軸に無いと `W18` の黄を出す**（`game_manager.gd:1596`）。⚠ **そのままだと戦闘のたびにルーンぶんの黄が出る。**<br>⚠ **`part_kind == "rune"` で分岐しない**（`NEXT_STEPS` §1-3・`game_manager.gd:2039`）。⚠ **「加算の欄を持たない装飾は足さない」という書き方にすれば、⚠ 種類を足しても効く** |
| **4** | ⚠ **段階を上げる操作は `merge_runes()` を新設する。⚠ `upgrade_part()` に相乗りしない** | ⚠ **`NEXT_STEPS` §1-3 が名指しで禁じている**（⚠ **`upgrade_part()` は素材を払う分解方式。⚠ `GAME_DESIGN` 7-7 の表で明確に別系統**）。<br>⚠ **`get_upgraded_part_id()` はルーンで `""` を返す**（⚠ **返さないと `part_rune__2` を組み立てて赤が出る**）。⚠ **分け方は `part_kind` ではなく「`runes.json` にエントリが在るか」** |
| **5** | ⚠ **上げ先は `runes.json` の `next_id` 欄で持つ**（⚠ **IDを組み立てない**） | ⚠ **装飾の `get_upgraded_part_id()` は `part_<種類>_<軸>_<段階>` を組み立てているが、⚠ ルーンには「軸」が無い**（決め3 で `part_stat` が空）。⚠ **組み立てを壊すより、⚠ 行き先を欄で持つほうが1行で済む。⚠ 段階5には `next_id` を書かない** |
| **6** | ⚠ **重ねるのは「同じ段階を `rune_merge_count`（既定2）個」** | ⚠ **`GAME_DESIGN` 7-7 は「同じものを重ねる」としか書いていない。⚠ 個数は数値なので `PartConfig`（`.tres`）に置く**（数値管理ルール）。⚠ **段階5で重ねようとしたら理由キーを返して止める**（⚠ **かけらは決定3 で今回作らない**） |
| **7** | ⚠ **紐付けは「武器のルーン枠 → スキル枠1」「アクセのルーン枠2つ → スキル枠2」** | ⚠ **`GAME_DESIGN` 7-5 の「武器＝スキル1、アクセサリー＝スキル2」。**<br>⚠ **スキル枠の並びは `get_battle_skills()` が返す配列の添字**（`game_manager.gd:3854`）。⚠ **`SKILL_SLOT_COUNT` は 2 なので過不足なく対応する。⚠ アクセは枠が2つあるので、⚠ スキル2には最大2件のルーンが乗る** |
| **8** | ⚠ **通常攻撃ではルーンを発動しない** | ⚠ **7-5 が紐づけているのはスキル1と2。⚠ 通常攻撃は `_fire_basic_attack()` を通り `_fire_skill()` を通らない**（`battle_controller.gd:924`）。⚠ **足すと攻撃の拍ごとに発動判定が走る** |
| **9** | ⚠ **移動は `effects` で表さない。⚠ `runes.json` の `move` 欄で持ち、⚠ `battle_controller` が受ける** | ⚠ **効果の種類を増やすと `SkillSchema` の `EFFECT_TYPES_*` に手が入り、⚠ ロード時検証が全件に効く欄が1つ増える**（⚠ **`skill_schema.gd:119`「効果の種類は増えていない。`EFFECT_TYPES_*` に何も足さないこと」**）。<br>⚠ **座標を触るのは `battle_controller` だけ**（`_step_unit()`）。⚠ **`SkillResolver` は「時間も段も知らない」層なので、⚠ 位置も知らせない** |
| **10** | ⚠ **移動量は符号つきの1つの数**（⚠ **前進＝正／後退＝負**） | ⚠ **決定2 でルーンは5種類。⚠ 「前進」と「後退」を別の種類にすると6種類になる。**<br>⚠ **段階が上がると選択肢が増える**（`GAME_DESIGN` 7-7）を、⚠ **`move.choices` の件数で表す**（段階1は1つ、段階5は6つ） |
| **11** | ⚠ **移動量の保存先は `character_growth.<id>.rune_move` ＝ `{ルーンのitem_id: 符号つきの距離}`** | ⚠ **キャラプリセットの5つ目のキーは `GROWTH_*` と共用する**（⚠ **段階7で4キーとも共用にしてある。`EXEC_PARTY_PRESETS` §17-3 の2**）。⚠ **装備の個体ではなくキャラに持たせる**（⚠ **`GAME_DESIGN` 7-7「設定はキャラプリセットに含める」。⚠ 個体に持たせるとプリセットで切り替わらない**） |
| **12** | ⚠ **`runes.json` の検証は `SkillSchema.validate()` を流用する**（⚠ **足場を足して呼ぶ**） | ⚠ **効果の検証（E1〜E26 ＋ 効果ごとの数十本）を2本目に書かない。⚠ `user_character_id` などスキル専用の必須欄は、⚠ 検証のためだけに埋めて渡す**（⚠ **`runes.json` に書かせない**） |
| **13** | ⚠ **`F4` に「ルーンを全種類」ボタンを足さない** | ⚠ **`_grant_all_parts()` が `item_type == "part"` を全部配る**（`debug_overlay.gd:261`）。⚠ **ルーンは装飾の4種類目なので、⚠ 既存のボタンで25件とも配られる。⚠ 決定3 は満たされる。⚠ ボタンを増やすと入口が2つになる** |
| **14** | ⚠ **数値は全部「勘」** | ⚠ **CD・効果量・移動距離・ロック秒・重ねる個数。⚠ 装飾のときと同じ立場**（`EXEC_DECORATION` §0-3 の13）。⚠ **`runes.json` と `part_config.gd` の2箇所に集めてある。§10 の宿題に載せる** |

---

## 1. 着手前に確認した実コード（2026-08-24・**`grep` 済み**）

| | 事実 | 実コード |
|---|---|---|
| **A** | ⚠ **ルーン枠はもう開いている。刺さるものが0件なだけ** | ⚠ **`_part_slot_kinds()`（`game_manager.gd:2071`）。⚠ 武器＝位置2 ／ アクセ＝位置2と3。⚠ `part_slot_min_grades` で等級5から** |
| **B** | ⚠ **`SkillRuntime.cast()` は `skill_data` を引数で受ける** | ⚠ **`skill_runtime.gd:109`。⚠ `MasterDataLoader` を引き直す行が1つも無い。⚠ **だから登録していない辞書でも撃てる** |
| **C** | ⚠ **シールドは効果の種類ではない** | ⚠ **`buff` の `intervene.shield_hp`**（`status_registry.gd:462`）。⚠ **残量は `counter` に入る。⚠ 2本目の置き場が無い** |
| **D** | ⚠ **デバフも効果の種類ではない** | ⚠ **`buff` の `stat` / `value` に負を入れる**（`status_registry.gd:364-382`）。⚠ **`hp` は禁止。⚠ 状態の色は3つで、デバフも青**（人間の決定4） |
| **E** | ⚠ **回復は `heal` 効果がそのまま使える** | ⚠ **`skill_resolver.gd:587`。⚠ `target: {team: "self"}` は効果ごとの上書きで既に実績がある**（`skill_drain_life`） |
| **F** | ⚠ **移動の受け口は無い** | ⚠ **`_step_unit()`（`battle_controller.gd:889-891`）が射程外なら毎フレーム `unit.x += dir * speed * delta`。⚠ 後退させても即歩き直す**（⚠ **`GAME_DESIGN` 7-5 の⚠ のとおり**） |
| **G** | ⚠ **`_add_part_stats()` は `part_stat` が10軸に無いと黄を出す** | ⚠ **`game_manager.gd:1596`。⚠ ルーンをそのまま置くと戦闘のたびに黄が出る**（決め3） |
| **H** | ⚠ **`get_upgraded_part_id()` は欄からIDを組み立てる** | ⚠ **`game_manager.gd:2329-2347`。⚠ `part_stat` が空だと `part_rune__2` になり、⚠ `push_error` が出る**（決め4・5） |
| **I** | ⚠ **`_normalize_presets_from_save()` は知らないキーを消さない** | ⚠ **`_normalize_character_preset()` は `entry` を作り直さず足りないものだけ足す**（`game_manager.gd:3675`）。⚠ **段階7で `rune_move` が残ることを実測済み。⚠ 中身の検証はまだ無い** |
| **J** | ⚠ **`F4` の「装飾を全種類」はルーンも配る** | ⚠ **`debug_overlay.gd:261`。⚠ `item_type == "part"` で回している**（決め13） |
| **K** | ⚠ **`_index_by()` が使い回せる** | ⚠ **`master_data_loader.gd:794`。⚠ `chests.json` と同じ形で `runes.json` を読める** |

⚠ **ドキュメントのズレは0件。⚠ `NEXT_STEPS` §1-1 と §3 の記述は実コードと一致していた**（§12）。

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ 新しい `class_name` を作らない

⚠ **`PartConfig` は既に在る**（`.godot/global_script_class_cache.cfg` に登録済み）。⚠ **`@export` を足すだけなら人間がエディタを通さなくても動く**（⚠ **`.tres` は既定値を書き出さないので、⚠ 追加した欄は `.gd` の既定値が効く**）。
→ ⚠ **この回は実装を前半・後半に割らない。⚠ 新しい `class_name` を作らないこと。**

### 2-2. ⚠ `part_kind` で `if` を分岐させない

⚠ **`game_manager.gd:2039` の注記。⚠ 種類を見てよいのは `_part_slot_kinds()` と `E119` の2箇所だけ。**
→ ⚠ **加算するかは「`part_stat` が空か」（決め3）。⚠ 段階の上げ方は「`runes.json` にエントリが在るか」（決め4）。⚠ どちらも欄で分ける。**

### 2-3. ⚠ `MasterDataLoader` が返す数値は必ず `float`

⚠ **`CLAUDE.md` 3番。⚠ `cooldown_sec` / `move.choices` / `value` を `int()` `float()` で包み忘れると、⚠ セーブの `rune_move` に `120.0` が書かれる。**

### 2-4. ⚠ 状態を変える前に全部の判定を終える

⚠ **`merge_runes()` / `set_rune_move()` は `CLAUDE.md` 6番の形。⚠ `# --- ここから状態を変える ---` を書く。**

### 2-5. ⚠ ネストした Dictionary は複製してから書き戻す

⚠ **`character_growth.<id>.rune_move` は入れ子。⚠ `AGENTS.md`「状態アクセスのルール」。**

### 2-6. ⚠ 件数を増やす回では既存の器の型を先に見る

⚠ **この事故は3回踏んでいる**（`NEXT_STEPS` §4）。⚠ **装備画面のルーン枠の行に `OptionButton` を1つ足す。⚠ 隣の兄弟の `size_flags` を必ず見る。⚠ `scenario=layout` を必ず回す。**

### 2-7. ⚠ E / W の次番号

⚠ **`E122` まで使用済み → `E123` から。** ⚠ **`W20` まで → `W21` から**（`W3` `W6` `W7` は欠番）。

---

## 3. 実装（ファイル別）

### 3-A. `resources/balance/master/runes.json` … **新規**（25件・**マスター7本目**）

⚠ **形は `chests.json` と揃える**（`{"runes": [ {...}, ... ]}`。⚠ **`_index_by()` で `rune_id` をキーに組み替える**）。

```json
{
  "runes": [
	{
	  "rune_id": "part_rune_shield_1",
	  "next_id": "part_rune_shield_2",
	  "cooldown_sec": 20.0,
	  "target": { "team": "self" },
	  "effects": [
		{
		  "type": "buff", "host": "unit", "status_id": "st_rune_shield",
		  "duration_sec": 8.0, "stack": "refresh",
		  "intervene": { "shield_hp": 40 }
		}
	  ]
	}
  ]
}
```

| 欄 | 中身 |
|---|---|
| `rune_id` | ⚠ **`items.json` の `item_id` と同じ。⚠ 突き合わせは `E124`** |
| `next_id` | ⚠ **重ねた先。⚠ 段階5には書かない**（決め5） |
| `cooldown_sec` | ⚠ **ルーン固有のCD**（`GAME_DESIGN` 7-5） |
| `target` / `effects` | ⚠ **スキルとまったく同じ語彙**（決め1・12）。⚠ **移動系には書かない** |
| `move` | ⚠ **`{"choices": [符号つきの距離...]}`。⚠ 移動系だけ**（決め9・10） |

⚠ **5種類の中身**（⚠ **数値は全部「勘」＝決め14**）：

| 種類 | ID | CD | 中身（段階1 → 5） |
|---|---|---|---|
| **バフ** | `part_rune_buff_<1..5>` | 14.0 | ⚠ **自分に `atk` +6 / +10 / +15 / +21 / +28**（`duration_sec: 6.0` / `stack: refresh` / `status_id: st_rune_buff`） |
| **デバフ** | `part_rune_debuff_<1..5>` | 16.0 | ⚠ **近くの敵に `def` −5 / −9 / −14 / −20 / −27**（`target: {team:"enemy", mode:"area", origin:"user", radius:150}` / `status_id: st_rune_debuff`） |
| **回復** | `part_rune_heal_<1..5>` | 18.0 | ⚠ **自分を回復。`multiplier` 0.6 / 1.0 / 1.5 / 2.1 / 2.8（`scale_from: "atk"`）** |
| **シールド** | `part_rune_shield_<1..5>` | 20.0 | ⚠ **`intervene.shield_hp` 40 / 70 / 110 / 160 / 220**（`duration_sec: 8.0` / `status_id: st_rune_shield`） |
| **移動** | `part_rune_move_<1..5>` | 10.0 | ⚠ **`move.choices`：`[60]` / `[-60,60]` / `[-60,60,120]` / `[-120,-60,60,120]` / `[-180,-120,-60,60,120,180]`** |

- ⚠ **`origin: "user"` には `sort` / `range` を書けない**（E78）。⚠ **`radius` の中が0体なら空振りする（正常系）**
- ⚠ **`stat` に `hp` は書けない**（`status_registry.gd:371`。⚠ `max_hp` を再計算しないため）
- ⚠ **インデントはタブ**（⚠ **トップレベルだけ半角スペース2つ＝`chests.json` と同じ**）

### 3-B. `resources/balance/master/items.json` … **+25件**（⚠ **Ziva に渡せる部分。§9**）

```json
{
	"item_id": "part_rune_shield_1",
	"storage": "inventory",
	"item_type": "part",
	"part_kind": "rune",
	"part_tier": 1,
	"part_stat": "",
	"part_base": 0,
	"part_roll_max": 0,
	"sort_order": 120
}
```

- ⚠ **`sort_order` は 120〜144**（⚠ **106〜119 は `EXEC_DECORATION` §3-A が「宝石を5軸に戻す」用に空けてある。⚠ 埋めない**）
- ⚠ **並びは 種類 → 段階**（バフ 120-124 ／ デバフ 125-129 ／ 移動 130-134 ／ 回復 135-139 ／ シールド 140-144）
- ⚠ **`part_stat` / `part_base` / `part_roll_max` は「空・0・0」を必ず書く**（⚠ **欄ごと省くと `E119` が「欄が欠けている」と言えなくなる**）

### 3-C. `resources/balance/part_config.gd` … **+3欄**

```gdscript
@export var max_rune_tier: int = 5
@export var rune_merge_count: int = 2
@export var rune_move_lock_sec: float = 1.2
```

- ⚠ **`max_part_tier`（4）は触らない。⚠ 装飾とルーンは段階の上限が違う**（⚠ **装飾は装飾素材と1:1で4、⚠ ルーンは `GAME_DESIGN` 7-7 で5**）
- ⚠ **`.tres` は既定値を書き出さない。⚠ 効いているのはこの `.gd` の値**（⚠ **人間の再生成は要らない**）

### 3-D. `scripts/systems/master_data_loader.gd` … **`runes.json` の読み込み ＋ `E123` `E124` ＋ `E119` に1枝**

| # | 出すもの |
|---|---|
| **E123** | ⚠ **`runes.json` の形が不正**（⚠ **赤**） |
| **E124** | ⚠ **`items.json` のルーンと `runes.json` が食い違う**（⚠ **赤・両方向**） |

- ⚠ **`_ensure_runes_loaded()` / `get_rune()` / `get_all_runes()` を `chests` と同じ形で足す**（⚠ **`_index_by(_load_json(PATH_RUNES), "runes", "rune_id", PATH_RUNES)`**）
- ⚠ **`E123` が見るもの**：⚠ **`cooldown_sec` が正の数値／⚠ `effects` と `move` の少なくとも一方が在る／⚠ `move` があるなら `choices` が空でない数値の配列で `0` を含まない／⚠ `next_id` があるなら `items.json` に在ってルーンで段階が+1／⚠ 知らない欄が無い**
- ⚠ **`effects` があるときは `SkillSchema.validate()` に足場を付けて渡す**（決め12）：

```gdscript
var probe: Dictionary = {
	"name_key": "ui_res_" + rune_id,
	"user_character_id": rune_id,   # ⚠ 検証のための足場。runes.json には書かせない
	"unlock_level": 1,
	"cooldown_sec": cooldown_sec,
	"activation": "instant",
	"target": entry.get("target", {}),
	"effects": entry.get("effects", []),
}
```

- ⚠ **`E124`**：⚠ **`items.json` に `part_kind: "rune"` が在るのに `runes.json` に無い／⚠ その逆／⚠ `runes.json` の `rune_id` が `items.json` でルーンでない**
- ⚠ **`E119` の枝**：⚠ **ルーンのときは `part_stat == ""` / `part_base == 0` / `part_roll_max == 0` を要求し、⚠ 段階は `1〜max_rune_tier`。⚠ IDの綴りの検証（`part_%s_%s_%d`）はルーンには当てない**（⚠ **軸が無いため。⚠ 代わりに `E124` が突き合わせる**）
- ⚠ **`runes validated: N entries, X errors` を1行 `print` する**（⚠ **`items` の行に混ぜない。⚠ ファイルが別なので出所が読めなくなる**）

### 3-E. `scripts/utils/state_keys.gd` … 定数

| 定数 | 値 |
|---|---|
| `GROWTH_RUNE_MOVE` | `"rune_move"` |

- ⚠ **プリセットの5つ目のキーは `GROWTH_*` と共用**（決め11。⚠ **段階7の4キーと同じ扱い**）
- ⚠ **`runes.json` の欄名は `GameManager` の定数で持つ**（⚠ **`ITEM_MASTER_*` と同じ形。⚠ `GameStateKeys` は状態のキーだけ**）

### 3-F. `autoload/game_manager.gd` … 本体

| 関数 | 中身 |
|---|---|
| **変更** `_add_part_stats()` | ⚠ **`part_stat` が空なら黙って飛ばす**（決め3）。⚠ **`W18` は出さない** |
| **変更** `get_upgraded_part_id()` | ⚠ **`runes.json` にエントリが在るなら `""`**（決め4）。⚠ **赤を出さずに返す** |
| **新設** `get_rune_definition(item_id) -> Dictionary` | ⚠ **`MasterDataLoader.get_rune()` を通し、⚠ 数値を `float()` `int()` で包む** |
| **新設** `get_rune_move_choices(item_id) -> Array[int]` | ⚠ **`move.choices`。⚠ 移動系でなければ空** |
| **新設** `get_rune_move(character_id, item_id) -> int` | ⚠ **選んである移動量。⚠ 未設定なら `choices` の先頭**（⚠ **「選んでいないと動かない」を作らない**） |
| **新設** `set_rune_move(character_id, item_id, distance) -> bool` | ⚠ **`choices` に無い値は弾く。⚠ `character_growth_changed` を出す** |
| **新設** `get_battle_runes(character_id) -> Dictionary` | ⚠ **`{skill_id: [ルーンの payload ...]}`。⚠ 戦闘が読む唯一の口**（決め7。⚠ **`get_battle_skills()` と同じ形**） |
| **新設** `get_rune_merge_reject_reason(item_id) -> String` | ⚠ **重ねられない理由の翻訳キー。⚠ `""` なら重ねられる** |
| **新設** `merge_runes(item_id) -> bool` | ⚠ **同じルーンを `rune_merge_count` 個消して `next_id` を1個**（決め6） |
| **変更** `save_character_preset()` | ⚠ **`rune_move` も焼く**（5つ目のキー） |
| **変更** `_plan_build()` / `_write_build()` | ⚠ **`rune_move` を運ぶ**（⚠ **適用の口3つが全部ここを通る**） |
| **変更** `_normalize_character_preset()` | ⚠ **`rune_move` を検証する1行**（`NEXT_STEPS` §1-3。⚠ **Dictionary でない／ルーンでないキー／`choices` に無い値 を落とす**） |
| **変更** `_normalize_growth_from_save()` 相当 | ⚠ **`character_growth` 側にも同じ形で1行**（⚠ **プリセットだけ洗って本体を洗わないと、⚠ 片方だけ壊れたまま残る**） |

#### ⚠ `get_battle_runes()` の中身（**決め7**）

```
スキル枠の並び = get_battle_skills(character_id)      # 添字0 = スキル1、1 = スキル2
装備の武器      に刺さっているルーン → スキル枠1
装備のアクセサリ に刺さっているルーン → スキル枠2（最大2件）
```

- ⚠ **刺さっているかは `get_part_entries(instance_id)` を通す**（⚠ **開いていない枠は返ってこない。⚠ 判定を2本目に書かない**）
- ⚠ **1件の payload**：`{item_id, skill_data, cooldown_sec, move}`（⚠ **`skill_data` は `MasterDataLoader` が組み立てたもの。⚠ 画面側では作らない**）
- ⚠ **スキル枠が1つしか無いキャラでは、⚠ アクセのルーンは誰にも紐づかない**（⚠ **黙って落とす。⚠ 正常系なので黄を出さない**）

#### ⚠ `_add_part_stats()` に足す3行（**決め3**）

```gdscript
# ステータスを足さない装飾（ルーン）。加算の欄を持たないものは黙って飛ばす。
# ⚠ part_kind で分岐しないこと（game_manager.gd:2039 の注記）。
#   「加算の欄があるか」だけを見れば、種類を足しても効く。
if stat_key == "":
	continue
```

⚠ **置く場所は `result.has(stat_key)` の `W18` より上**（⚠ **下に置くと黄が出てから飛ばすことになる**）。

### 3-G. `scripts/systems/unit.gd` … **+2欄**

```gdscript
var rune_payloads: Dictionary = {}   # {skill_id: [payload...]}（決め7）
var move_lock_sec: float = 0.0       # 0より大きいあいだ自動移動しない（決定5）
```

- ⚠ **`tick_cooldowns()` と同じ場所で `move_lock_sec` を減らす**（⚠ **`_process` から2本目のtickを足さない**）
- ⚠ **敵と召喚は空のまま**（⚠ **ルーンは装備から来る**）

### 3-H. `scenes/adventure/battle_controller.gd` … 発火と移動

- ⚠ **`_init_party_units()` で `unit.rune_payloads = GameManager.get_battle_runes(character_id)` を入れる**（⚠ **`skill_ids` を入れている場所の隣**）
- ⚠ **`_fire_skill()` の中、⚠ `blocked_reason()` を通ったあと・⚠ `_skill_runtime.cast()` の直前に `_fire_runes(user, skill_id)` を1行**（`GAME_DESIGN` 7-5「発動タイミングはスキルの直前」）
- ⚠ **`_fire_runes()` の中身**：

```
そのスキルに紐づく payload を順に
  CD が空いていなければ飛ばす（スキルは撃てる）
  move があれば   … unit.x を動かし、move_lock_sec を立てる
  effects があれば … _skill_runtime.cast(user, payload.item_id, payload.skill_data, 1.0, [])
  user.start_cooldown(payload.item_id, BattleFormula.cooldown(cooldown_sec, haste))
```

- ⚠ **`_step_unit()` の移動の枝に `move_lock_sec` の条件を足す**（決定5）。⚠ **攻撃の枝には足さない**
- ⚠ **移動は画面の外に出さない**（⚠ **`clampf` を掛ける。⚠ 範囲は定数で持つ**）
- ⚠ **CD中でもスキルは撃てる**（⚠ **ルーンが撃てないだけ。⚠ `blocked_reason()` にルーンの条件を足さない**）
- ⚠ **`BattleLog` に1行出す**（⚠ **`print` を増やさない。`NEXT_STEPS` §4**）

### 3-I. `scenes/guild/equipment_screen.gd` … ルーン枠の行に `[移動量 ▼]`（**決定6**）

- ⚠ **刺さっているのが移動系のときだけ `OptionButton` を1つ足す**（⚠ **`get_rune_move_choices()` が空なら出さない**）
- ⚠ **選ぶと `set_rune_move()`。⚠ 判定は画面に書かない**
- ⚠ **隣の兄弟の `size_flags` を見てから足す**（§2-6）
- ⚠ **表示は `+120` / `-60` の形**（⚠ **符号を必ず出す。⚠ 前進か後退かが読めなくなる**）

### 3-J. `scenes/guild/warehouse_screen.gd` … ルーンは `[重ねる]`

- ⚠ **`get_upgraded_part_id()` が `""` を返すルーンでは `[段階を上げる]` を出さない**（決め4。⚠ **既存の分岐がそのまま効く**）
- ⚠ **代わりに `get_rune_merge_reject_reason()` が `""` のときだけ `[重ねる]` を出す**
- ⚠ **段階5では出さない**（⚠ **かけらは決定3 で今回作らない**）

### 3-K. `localization/ja.csv` … **+34行**（⚠ **Ziva に渡せる部分。§9**）

| キー | 件数 | 値 |
|---|---|---|
| `ui_res_part_rune_<種類>_<1..5>` | 25 | ⚠ **例：`ui_res_part_rune_shield_1,守りのルーン①`** |
| `ui_status_ch_st_rune_buff` / `_debuff` / `_shield` | 3 | ⚠ **漢字1文字：`攻` / `弱` / `盾`** |
| `ui_part_slot_kind_rune` | — | ⚠ **既に在る**（`EXEC_DECORATION` §13-5） |
| `ui_part_rune_move` | 1 | ⚠ **移動量** |
| `ui_part_rune_merge` | 1 | ⚠ **重ねる** |
| `ui_part_reject_rune_max` | 1 | ⚠ **これ以上重ねられません** |
| `ui_part_reject_rune_stock` | 1 | ⚠ **同じルーンが%d個要ります** |
| `ui_part_reject_rune_kind` | 1 | ⚠ **重ねられない装飾です** |
| `ui_part_rune_move_format` | 1 | ⚠ **%+d** |

- ⚠ **名前の付け方**：⚠ **`力のルーン` / `弱めのルーン` / `踏み込みのルーン` / `癒しのルーン` / `守りのルーン` ＋ 丸数字①〜⑤**
- ⚠ **UTF-8（BOMなし）・LF。⚠ 再インポートは人間**（§7）

### 3-L. `tests/debug_boot.gd` … **`SCENARIOS` に1行**

| シナリオ | `kind` | 見るもの |
|---|---|---|
| ⚠ **`runes`** | ⚠ **`KIND_BATTLE`** | ⚠ **ルーンが本当に戦闘の挙動を変えているか**（`NEXT_STEPS` §1-3。⚠ **`report` の枝では足りない**） |

- ⚠ **`parts` の `report` にはルーン25件の一覧を足す**（⚠ **ID / 段階 / CD / 効果の種類 / `move.choices` / `next_id` / `tr()` の戻り**）
- ⚠ **`runes` が出すもの**：
  1. ⚠ **編成のキャラに装備を着け、⚠ ルーン枠に5種類を刺す**（⚠ **等級5以上の武器とアクセを `F4` と同じ経路で用意する**）
  2. ⚠ **`get_battle_runes()` が返す紐付け**（⚠ **スキル1に武器の1件、スキル2にアクセの2件**）
  3. ⚠ **スキルを撃つ → ⚠ 状態が付く（`shield_left` / `stat_mod`）／⚠ HPが増える／⚠ `x` が動く**
  4. ⚠ **移動のロック**（⚠ **後退した直後の `x` と、⚠ ロックが切れたあとの `x`**）
  5. ⚠ **CD中に撃つと、⚠ ルーンは発動せずスキルだけ出る**
  6. ⚠ **ルーンを1つも刺していないキャラでは、⚠ 撃っても何も増えない**（⚠ **回帰**）
- ⚠ **`layout` は器を足したので必ず回す**（§2-6）

### 3-M. 触らないファイル

⚠ **`skill_schema.gd` ／ `skill_resolver.gd` ／ `skill_runtime.gd` ／ `status_registry.gd` ／ `battle_formula.gd` ／ `battle_session.gd`**（⚠ **決め1・9。⚠ 効果の種類を増やさない**）
⚠ **本番スキルの JSON 全件 ／ `characters.json` ／ `enemies.json` ／ `stages.json` ／ `shop.json` ／ `chests.json` ／ `recipes.json`**（⚠ **入手はデバッグパネルだけ＝決定3**）
⚠ **`equipment_config.gd` ／ `part_config.tres`**（⚠ **`.gd` の既定値だけで足りる**）

---

## 4. 変えないもの

- ⚠ **`parts` の要素は `{item_id, roll}`。⚠ ルーンの `roll` は 0**（決定1）
- ⚠ **`PART_SLOT_COUNT = 8` ／ `part_slot_min_grades = [3,4,5,5,6,7,8,9]` ／ `_part_slot_kinds()` の表**（⚠ **枠はもう開いている**）
- ⚠ **`upgrade_part()` / `dismantle_part()` / `attach_part()` / `detach_part()` の中身**（⚠ **ルーンも刺す・外すは同じ口を通る**）
- ⚠ **`get_part_reject_reason()`**（⚠ **ルーンもここを通る。⚠ 2本目を作らない**）
- ⚠ **効果の種類（`EFFECT_TYPES_*`）**
- ⚠ **`ChestScheduleEntry.chest_type` の `@export` 名**
- ⚠ **`PRESET_EQUIPMENT_ENABLED`**（⚠ **宿題のまま。⚠ この回で消さない**）

---

## 5. 完了条件 — **§0 事前チェック**（⚠ **設計役・ヘッドレス。⚠ 人間に渡す前に終わっている**）

1. ⚠ **全シナリオ（既存24 ＋ 新規 `runes` の25本）で `ERROR:` / `SCRIPT ERROR:` / `Parse Error` が1行も出ないこと**（⚠ **`training` を除く。⚠ 分けて回す**）
2. ⚠ **`items validated: 89 entries, 0 errors`**（⚠ **64 ＋ ルーン25**）
3. ⚠ **`runes validated: 25 entries, 0 errors`**
4. ⚠ **黄は既知の1本（`skill_dbg_dot_odd`）だけ**（⚠ **`drops` と `parts` はもう1本多いのが正解**）
   - ⚠ **`ja.csv` を再インポートするまでは、さらに15本の黄が出る**（`ui_status_ch_st_rune_*`）。⚠ **再インポートは人間の作業**（§7-A）。⚠ **実測は §13-2 / §13-6 の1**
5. ⚠ **触った `.gd` 全部で `--check-only --script` が `Parse Error` 0件**

---

## 6. 完了条件 — **ログ / ファイル**（⚠ **設計役が読む。⚠ 人間の仕事は無い**）

### 6-A. 紐付けと発動（`scenario=runes`）

1. ⚠ **`get_battle_runes()` が スキル枠1に武器の1件、⚠ スキル枠2にアクセの2件を返す**
2. ⚠ **スキル1を撃つと、⚠ `BattleLog` にルーンの `cast` がスキルより**先に**出る**
3. ⚠ **シールドのルーンで `shield_left` が 0 → 40 以上になる**
4. ⚠ **バフのルーンで `stat_mod(atk)` が 0 → 正になる**
5. ⚠ **回復のルーンで HP が増える**（⚠ **先に削ってから撃つ**）
6. ⚠ **デバフのルーンで、⚠ `radius` の中の敵の `stat_mod(def)` が負になる**
7. ⚠ **移動のルーンで `x` が `choices` で選んだぶんだけ動く**

### 6-B. ロックとクールダウン

8. ⚠ **後退した直後の `x` と、⚠ `rune_move_lock_sec` を過ぎたあとの `x` が違う**（⚠ **ロックが切れたら歩き直す＝正解**）
9. ⚠ **ロック中に攻撃の拍が来ると殴る**（⚠ **止まるのは移動だけ**）
10. ⚠ **CD中にもう一度撃つと、⚠ スキルの `cast` は出てルーンの `cast` は出ない**
11. ⚠ **ルーンを刺していないキャラで撃つと、⚠ ルーンの `cast` が1本も出ない**

### 6-C. 重ねる・移動量・プリセット（`scenario=parts` / `presets`）

12. ⚠ **`merge_runes('part_rune_shield_1')` … 在庫が2個減って `part_rune_shield_2` が1個増える**
13. ⚠ **在庫1個で呼ぶと `ui_part_reject_rune_stock`**（⚠ **状態が変わっていないこと**）
14. ⚠ **段階5で呼ぶと `ui_part_reject_rune_max`**
15. ⚠ **`upgrade_part('part_rune_shield_1')` が `false`。⚠ 赤が出ないこと**（決め4）
16. ⚠ **`set_rune_move()` … `choices` に在る値は通り、⚠ 無い値は弾かれる**
17. ⚠ **`get_rune_move()` … 未設定なら `choices` の先頭を返す**
18. ⚠ **キャラプリセットを焼くと `rune_move` が入り、⚠ 適用で戻る**
19. ⚠ **ルーンを刺しても `get_effective_stats()` が1つも動かない**（決め3。⚠ **黄も出ないこと**）

### 6-D. ファイル

20. ⚠ **`items.json` が 89件。⚠ `sort_order` の重複が0件**
21. ⚠ **`runes.json` が 25件。⚠ `next_id` が段階5にだけ無い**
22. ⚠ **`ja.csv` が 480行。⚠ BOM無し・CR無し・キーの重複0件**
23. ⚠ **`save_slot_0.json` に `rune_move` が `int` で入る**（⚠ **`120.0` になっていないこと。`CLAUDE.md` 3番**）

### 6-E. ⚠ 足した検証が本当に出るか（**2箇所で壊す。⚠ 壊すのはメモリ上の状態**）

24. ⚠ **`rune_move` に `choices` に無い値を直接書き込む → ⚠ 正規化が落とす**
25. ⚠ **刺さっているルーンの `item_id` を存在しないIDに書き換える → ⚠ `get_battle_runes()` がその1件だけ落とす**（⚠ **他のルーンは残ること**）

---

## 7. 完了条件 — **画面**（⚠ **人間だけ**）

### 7-A. ⚠ 先にやってもらうこと

- [ ] ⚠ **`ja.csv` の再インポート**（FileSystem で右クリック → 再インポート、または Godot 再起動）
- [ ] ⚠ **`F4` →「素材を全種類」→「装飾を全種類」→「装備を全種類 1個ずつ」**（⚠ **ルーンは「装飾を全種類」で配られる＝決め13**）

### 7-B. ⚠ 見るもの

- [ ] ⚠ **倉庫の持ち物タブにルーン25種が並ぶ**（⚠ **名前が出る。⚠ `ui_res_part_rune_...` が生で出ていないこと**）
- [ ] ⚠ **ルーンの行に `[段階を上げる]` が**出ず**、⚠ `[重ねる]` が出る**
- [ ] ⚠ **`[重ねる]` を押すと段階が1つ上のルーンに変わる**（⚠ **2個消えて1個になる**）
- [ ] ⚠ **段階⑤のルーンには `[重ねる]` が出ない**
- [ ] ⚠ **装備画面で、⚠ 等級5以上の武器に「ルーン枠」の行が出る**（⚠ **アクセは2行**）
- [ ] ⚠ **その枠に宝石を刺そうとすると一覧に出ない／押せない**
- [ ] ⚠ **移動のルーンを刺すと、⚠ その行に `[移動量 ▼]` が出る**
- [ ] ⚠ **`[移動量 ▼]` の選択肢が、⚠ 段階①で1つ・段階⑤で6つ**
- [ ] ⚠ **選ぶと表示が変わり、⚠ 画面を出入りしても選んだ値が残る**
- [ ] ⚠ **移動以外のルーンには `[移動量 ▼]` が出ない**
- [ ] ⚠ **装備画面・倉庫・拠点が横にはみ出していない**（⚠ **器を1つ足した回**）
- [ ] ⚠ **戦闘でスキルを撃つと、⚠ 撃つ前に盾／攻／弱のマスが付く**
- [ ] ⚠ **移動のルーンを刺したキャラが、⚠ スキルを撃った瞬間に前後へ跳ぶ**
- [ ] ⚠ **跳んだあと少し止まってから、⚠ また敵に向かって歩き出す**
- [ ] ⚠ **ルーンを刺していないキャラのステータスが1つも変わっていない**
- [ ] ⚠ **移動量を選んだあと拠点で「セーブする」→ `save_slot_0.json` の `rune_move` が `120` の形**（⚠ **`120.0` になっていないこと。`CLAUDE.md` 3番**）。⚠ **設計役は保存できないのでここだけ人間**（§13-5 の23）

---

## 8. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- ⚠ **スキル枠を3つに増やしたとき**：⚠ **`get_battle_runes()` の紐付けが枠1と2のままでよいか**
- ⚠ **ルーン枠を防具にも開いたとき**：⚠ **どのスキルに紐づくか決まっていない**
- ⚠ **かけらを入れるとき**：⚠ **段階5で重ねたときの行き先**（⚠ **今は `ui_part_reject_rune_max` で止める**）
- ⚠ **敵にルーンを持たせるとき**：⚠ **`_try_enemy_skill()` も `_fire_skill()` を通るので発動する。⚠ `rune_payloads` が空なだけ**

---

## 9. Ziva に渡せる部分

⚠ **`.gd` を1行も触らない部分。⚠ `AGENTS.md` ＋ この §3-B ＋ §3-K の4点セットで渡せる。**

- ⚠ **`items.json` に25件**（§3-B）
- ⚠ **`ja.csv` に34行**（§3-K）

⚠ **`runes.json`（§3-A）は渡さない。⚠ 効果の語彙が `SkillSchema` と結びついていて、⚠ 間違うと赤が25本出る。**

---

## 10. 終わったあとに足す宿題（`PROJECT_STATUS.md`）

1. ⚠ **マスターファイルが7本目になった**（⚠ **宿題1 が未判断のまま増えた。決定4**）
2. ⚠ **ルーンのかけらが無い**（⚠ **段階5で重ねられない。決定3**）
3. ⚠ **本番の入手経路が無い**（⚠ **`GAME_DESIGN` 7-7 は「ポモドーロ報酬のレアな枠」。⚠ `chests.json` のポモドーロ4件は固定報酬で抽選が無い**）
4. ⚠ **数値が全部「勘」**（⚠ **CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ ロック秒 ／ 重ねる個数**）
5. ⚠ **移動のロック中であることが画面に出ない**
6. ⚠ **ルーンのCDが画面に出ない**（⚠ **スキルのボタンにはゲージが在る**）
7. ⚠ **`PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**（⚠ **段階7からの持ち越し**）

---

## 11. コミットメッセージ

```
feat(runes): ルーン25件・スキルの直前に発動・移動量をキャラプリセットへ
```

---

## 12. ⚠ ドキュメントのズレ（**報告。勝手に直さない**）

⚠ **この回で見つけたズレは 0件。** ⚠ **`NEXT_STEPS` §1-1 と §3 の記述は、⚠ `grep` した実コードと全部一致していた**（⚠ **枠の位置・開く等級・`PART_KIND_RUNE` の定義・`parts` の型・正規化の挙動**）。
⚠ **未報告のズレは 0件のまま。⚠ 次に見つけたものは 29 番。**

---

## 13. ⚠ 実施結果（**2026-08-24・設計役がヘッドレスで実行して判定**）

### 13-1. ⚠ 触ったファイル（**14本。新規2本**）

| ファイル | 中身 |
|---|---|
| ⚠ **`resources/balance/master/runes.json`**（新規） | ⚠ **25件。マスター7本目** |
| ⚠ **`docs/02_exec/EXEC_RUNES.md`**（新規） | この指示書 |
| `resources/balance/master/items.json` | ⚠ **64 → 89件**（`sort_order` 120〜144） |
| `localization/ja.csv` | ⚠ **446 → 480行** |
| `resources/balance/part_config.gd` | ⚠ **`max_rune_tier` / `rune_merge_count` / `rune_move_lock_sec`** |
| `scripts/systems/master_data_loader.gd` | ⚠ **`runes.json` の読み込み ＋ `rune_skill_data()` ＋ `E123` `E124` ＋ `E119` に枝** |
| `scripts/utils/state_keys.gd` | ⚠ **`GROWTH_RUNE_MOVE`** |
| `autoload/game_manager.gd` | ⚠ **ルーンの章（9本）＋ `_add_part_stats()` / `get_upgraded_part_id()` / `get_part_dismantle_refund()` / 焼く / `_write_build()` / 正規化2本** |
| `scripts/systems/unit.gd` | ⚠ **`rune_payloads` / `move_lock_sec` / `is_rune_ready()` / `start_rune_cooldown()`** |
| `scripts/systems/battle_log.gd` | ⚠ **`log_rune()`** |
| `scenes/adventure/battle_controller.gd` | ⚠ **`_fire_runes()` ＋ 移動ロック ＋ 割り当て ＋ `RUNE_MOVE_MIN_X/MAX_X`** |
| `scenes/guild/equipment_screen.gd` | ⚠ **`[移動量 ▼]`** |
| `scenes/guild/warehouse_screen.gd` | ⚠ **`[重ねる]`**（⚠ **ルーンは「壊す」も「段階を上げる」も出さない**） |
| `tests/debug_boot.gd` | ⚠ **`scenario=runes` ＋ `_apply_runes()` ＋ `parts` にルーンの章 ＋ `dump_each_fire`** |

⚠ **`docs/NEXT_STEPS.md` / `docs/PLAN_IMPLEMENTATION.md` / `AGENTS.md` も直した**（⚠ **§6 と §12 の指示どおり**）。

### 13-2. ⚠ §5 事前チェックの結果

| # | 項目 | 結果 |
|---|---|---|
| 1 | 全シナリオ（**25本**・`training` を除く） | ✅ **`red=0`（25本とも）** |
| 2 | `items validated` | ✅ **`89 entries, 0 errors`** |
| 3 | `runes validated` | ✅ **`25 entries, 0 errors`** |
| 4 | 黄 | ⚠ **平常 `16`**（⚠ **既知の1本 ＋ 下の 13-6 の15本**）／ ⚠ **`parts` と `drops` だけ `17`**（⚠ **どちらも意図的に壊しているぶん**） |
| 5 | `--check-only --script`（7ファイル） | ✅ **`Parse Error` 0件**（`Identifier not found: Balance` / `GameManager` / `SceneManager` は Autoload 未読み込み） |

### 13-3. ⚠ §6-A / §6-B の実測（`scenario=runes`）

⚠ **紐付け**（⚠ **武器＝スキル1 ／ アクセ＝スキル2**）：

```
char_debug_mix    skills=[narrow, wide]  runes={narrow:[shield_1], wide:[buff_5, move_5]}
char_debug_life   skills=[far, heal]     runes={far:[heal_5],      heal:[debuff_5]}
char_debug_status skills=[...]           runes={}          ← 1つも刺していない（回帰）
```

⚠ **`battle_last.jsonl`**（⚠ **ルーンの行がスキルの効果と同じ `t` に出ている**）：

| # | 項目 | 実測 |
|---|---|---|
| 1 | 紐付け | ✅ 上の3行 |
| 2 | ルーンがスキルより先 | ✅ **`status_add(st_rune_shield)` → `rune` の順で `t=4.94`** |
| 3 | シールド | ✅ **`st_rune_shield` が `party_0` に付く（`dur=8.0`）／ `t=12.94` に `expire`** |
| 4 | バフ | ✅ **`st_rune_buff` が `party_0` に付く（`dur=6.0`）／ `t=15.96` に `expire`** |
| 5 | 回復 | ✅ **`heal src=party_1 dst=party_1 amount=112`**（⚠ **先に削ってから撃った**） |
| 6 | デバフ | ✅ **`st_rune_debuff` が `enemy_1_2` と `enemy_1_3` の2体に付く**（⚠ **`radius` の中だけ**） |
| 7 | 移動 | ✅ **`{"ev":"rune","rune":"part_rune_move_5","move":-120,"x":383.26}`**（⚠ **撃つ前 503.26 → 383.26。ちょうど −120**） |
| 8 | ロック | ✅ **`t=9.96` に 383.4 → `t=12.46` に 461.6**（⚠ **1.2秒のロックが切れたあと歩き直している**） |
| 9 | ロック中も殴る | ✅ **移動の枝にだけ条件を足した**（⚠ **コードで確認。⚠ ログでは分離できていない**） |
| 10 | CD中は乗らない | ✅ **`t=15.08` に narrow をもう一度撃つと、⚠ スキルは出て `rune` の行が1本も出ない**（⚠ **シールドのCDは20秒**） |
| 11 | 刺していないキャラ | ✅ **`runes={}`**（⚠ **上の3行目**） |

### 13-4. ⚠ §6-C の実測（`scenario=parts`）

| # | 項目 | 実測 |
|---|---|---|
| 12 | 重ねる | ✅ **`merge_runes('part_rune_shield_1') -> true`（段階1 303 → 301 ／ 段階2 300 → 301。⚠ 2個で1個）** |
| 13 | 在庫不足 | ✅ **在庫1個で `false` / `ui_part_reject_rune_stock`（⚠ 在庫は1のまま）** |
| 14 | 段階5 | ✅ **`false` / `ui_part_reject_rune_max`** |
| 15 | 分解方式で上がらない | ✅ **`upgrade_part('part_rune_shield_1') -> false (上げ先が無い)`。⚠ 赤なし** |
| 16 | 移動量の判定 | ✅ **`set_rune_move(120) -> true` ／ `set_rune_move(999) -> false`（120 のまま）／ 宝石に対して `false`** |
| 17 | 未設定の既定 | ✅ **`choices` の先頭（`-180`）** |
| 18 | プリセット | ✅ **焼いた `rune_move = {"part_rune_move_5": 120}` ／ 60 に変えて適用 → `120` に戻る** |
| 19 | ステータスを足さない | ✅ **刺す前と刺した後の `get_instance_stats()` が完全に同じ。⚠ `W18` の黄も出ない** |
| — | ルーンを壊す | ✅ **`get_part_dismantle_refund() -> {}`**（⚠ **かけらの器が無いので素材にならない。§13-5 の2**） |
| — | 刺す判定 | ✅ **アクセのルーン枠にルーン → `''` ／ 宝石 → `ui_part_reject_kind`** |

### 13-5. ⚠ §6-D / §6-E の実測

| # | 項目 | 実測 |
|---|---|---|
| 20 | `items.json` | ✅ **89件 ／ `sort_order` の重複 0件** |
| 21 | `runes.json` | ✅ **25件 ／ `next_id` が無いのは段階5の5件だけ**（⚠ **`E123` が段階の+1も見ている**） |
| 22 | `ja.csv` | ✅ **480行 ／ BOM無し ／ CR無し ／ キーの重複 0件** |
| 23 | セーブの型 | ⚠ **取れていない。** ⚠ **`debug_boot` は保存しないため**（`CLAUDE.md` の制約）。⚠ **`set_rune_move(distance: int)` で型は閉じているが、⚠ 実物は人間が保存したあとに見る**（§7-B に足した） |
| 24 | 正規化を壊す | ✅ **`{move_5: 777, gem_atk_1: 60}` を書き込む → 正規化後 `{}`**（⚠ **範囲外の値も、ルーンでないキーも落ちた**） |
| 25 | 刺さっているIDを壊す | ✅ **`get_battle_runes()` が `before=2 → after=1`**（⚠ **壊した1件だけ落ちて、⚠ 隣のルーンは残った**）／ ⚠ **`W18` の黄が1本出る** |

⚠ **どちらもメモリ上の状態だけを壊している。⚠ `git diff` にデータファイルの変更は入っていない。**

### 13-6. ⚠ 正直に書くこと

1. ⚠ **`ja.csv` を再インポートするまで、黄が15本多く出る。**
   ⚠ **`E123` が `TranslationServer.translate("ui_status_ch_st_rune_*")` を見ており、⚠ CSV に行は足したが `.translation` が古いため。**
   ⚠ **`ja.csv` の再インポートは人間の作業**（`CLAUDE.md`）。⚠ **§7-A の1つ目を済ませれば 1本（既知の `skill_dbg_dot_odd`）に戻るはず。⚠ 戻らなかったら報告してください。**
2. ⚠ **ルーンは「壊す」ボタンが出ない。** ⚠ **`GAME_DESIGN` 7-7 では余りが「かけら」になるが、⚠ かけらは決定3 で作っていない。**
   ⚠ **装飾素材を返す形にすると `decor_material_5` という存在しないIDが要るので、⚠ 返さない側に倒した**（§10 の宿題2）。
3. ⚠ **§6-B の9（ロック中も殴る）は、⚠ コードでしか確かめていない。** ⚠ **移動の枝にだけ条件を足したことは読めるが、⚠ 「ロック中に攻撃の拍が来た」瞬間をログで分離できていない。**
4. ⚠ **画面のコードは「パースと、`layout` で開くこと」までしか確かめていない。** ⚠ **`[移動量 ▼]` と `[重ねる]` が本当に出るかは人間しか見られない**（§7-B）。
5. ⚠ **`scenario=layout` は、ルーンを刺していない状態で装備画面を開いている。** ⚠ **`[移動量 ▼]` が並んだときの幅は測れていない**（§7-B の「横にはみ出していない」で見てもらう）。

### 13-7. ⚠ 実装中に自分で決めたもの（**§0-3 に無いもの・後出し**）

| # | 決めたこと | なぜ |
|---|---|---|
| **15** | ⚠ **ルーンは倉庫で「壊す」も出さない**（§13-6 の2） | ⚠ **`decor_material_5` が存在しないため。⚠ `get_part_dismantle_refund()` がルーンで空を返す** |
| **16** | ⚠ **`_normalize_skill_slots_from_save()` にも `rune_move` の1行を足した** | ⚠ **プリセットだけ洗って `character_growth` 本体を洗わないと、⚠ 片方だけ壊れたまま残る** |
| **17** | ⚠ **`runes.json` の `radius` は 250**（⚠ **150 から上げた**） | ⚠ **150 だと検証の立ち位置（敵まで180）で1体も入らなかった。⚠ 空振りは正常系なので赤も黄も出ない**（§4 の罠に足した） |
| **18** | ⚠ **`presets` シナリオの「知らないキー `rune_move` が残る」を書き換えた** | ⚠ **段階7の時点の検証。⚠ 段階8で器ができたので、⚠ いまは「Dictionary でなければ `{}` に直る」を見ている** |
| **19** | ⚠ **`debug_boot` に `dump_each_fire` を足した**（⚠ **既定 `false`**） | ⚠ **移動系ルーンは撃った瞬間に跳ぶので、⚠ 合図・静止・決着の3点では跳んだことが1つも残らない。⚠ 既定を `false` にしてあるので既存シナリオの出力は1行も変わらない** |


---

## 14. ⚠ 画面の確認が通った（**2026-08-24・人間が実機で操作**）

⚠ **§7-B の16項目が全部 OK。** ⚠ **§7-A の2つ（`ja.csv` の再インポート・`F4` で配る）も済んでいる。**

- ⚠ **再インポートが効いたことは数字でも確認できた**：⚠ **黄の平常値が 16本 → 1本**（⚠ **`ui_status_ch_st_rune_*` の15本が消えた。⚠ 残る1本は `skill_dbg_dot_odd` で出るのが正解**）
- ⚠ **§12-6 に「通っていない」と書いた5件のうち、⚠ 4と5（画面のコード・`[移動量 ▼]` が並んだときの幅）はこれで解消。**
- ⚠ **残っているのは §12-6 の3（ロック中に殴れることをログで分離できていない）だけ。** ⚠ **画面で見て問題が出なかったので、⚠ 宿題にも上げない。**

⚠ **段階8は完了。** ⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列は 2026-08-24 に ✅ にしてある。**
