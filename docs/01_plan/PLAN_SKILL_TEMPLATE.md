# 【作戦計画書】スキルのテンプレート

**第2層。第1層（ゲームの中身の正）は`GAME_DESIGN.md` 3-2 と 5-4。実装順は`PLAN_IMPLEMENTATION.md` 3章の3番の残り。**

**このファイルは「スキルとパッシブの効果をどう表すか」の決定台帳。** スキル12個（3人×4個）とパッシブ15個（3人×5個）を書き始める前に、**器の形をここで確定させる。**

**このファイルにコードは載せない。** 実装は`EXEC_◯◯.md`が持つ。

> ## ⚠ 現状は**たたき台**。確定していない（2026-08-15）
>
> **2章の「決定」を含め、まだ人間の合意を取っていない。** スキルのテンプレは
> **チャージ式など戦闘の他の仕組みと絡む**ため、**専用の会話で議論して固める**と決まった。
>
> **この会話で決めたのは「2欄に割る方向」と「体数は名前に含める」の2点だけ。**
> 3〜5章の一覧と移行表は、その方向で書くとどうなるかを見せるための**素案**。
>
> **議論で扱うと分かっているもの**：
> - **チャージ式**（現在 `battle_controller` が `multiplier` に畳み込んでいる。6章）
> - 他の戦闘の仕組みとの絡み
>
> **議論が終わったら、このブロックを消して「決定」に格上げする。**

---

## 0. 着手前に実コードを確認した結果（2026-08-15・`grep`済み）

| 調べたもの | 結果 |
|---|---|
| `skill_resolver.gd` | **109行**。`static func resolve()` が `type` で `match` する形 |
| 動く `type` | **`single` / `aoe` / `heal` の3つだけ** |
| `buff` / `dot` / `projectile` | **stub**。39〜41行で `push_warning` して空配列を返す |
| `SkillResolver` の呼び出し元 | **1箇所だけ**（`battle_controller.gd` 603行） |
| `skills.json` | **6件**。全部 `unlock_level: 1` |
| `BattleSession.get_alive_units(team)` | 64行。**チーム単位でしか取れない**。距離順・HP順の取得は無い |
| `BattleUnit` の実体 | ⚠ **`scripts/systems/unit.gd`**（185行）。`battle_unit.gd` は無い |
| `battle_formula.gd` | 67行・static4本。**条件を評価する層は無い** |

---

## 1. 何が問題か

**`type` が2つの軸を1本に潰している。**

| 今の `type` | 対象の選び方 | 効果の種類 |
|---|---|---|
| `single` | 最も近い敵1体 | ダメージ |
| `aoe` | **敵全員固定** | ダメージ |
| `heal` | **味方全員固定** | 回復 |

このため、**組み合わせを変えたいだけの場合でも新しい `type` が要る。**

書けないもの：**単体回復**・前方2体・貫通・自分だけに効く効果。

> **`aoe` は「範囲」ではなく「敵全員」。** 名前が実装より広く見えるのも、この潰れ方が原因。

---

## 2. 決定：`type` を `target` と `effect` の2欄に割る（2026-08-15）

```json
"target": "enemy_all",
"effect": "damage"
```

- **`target`** … 誰に効くか。**体数は名前に含める**
- **`effect`** … 何をするか

**`type` は廃止する。** 残さない。

- `skills.json` は**マスターデータ専用**で、セーブは**スキルIDしか持たない**（`DATA_SCHEMA.md` 4-3）。**欄の名前を変えてもセーブは壊れない**
- 読んでいるのは `skill_resolver.gd` の1箇所だけ
- ⚠ **改名できないのはスキルID。欄の名前ではない**（`CLAUDE.md` 4番）

### なぜ体数を別欄（`target_count`）にしなかったか

**2欄で足りるから。** `target_count` を足すと「`enemy_all` に `target_count: 2` が書かれたらどうするか」という**組み合わせの矛盾**を毎回potentially検証することになる。名前に含めれば、**書けない組み合わせは最初から書けない。**

代償として、**体数を変えるたびに `target` の値が1つ増える。** 3体・4体が要るまでは増やさない。

---

## 3. `target` の一覧

| 値 | 対象 |
|---|---|
| `enemy_nearest` | 敵の生存者のうち、`user.x` に**最も近い1体** |
| `enemy_nearest_2` | 同じく**近い順に2体**（前方2体・貫通はこれで表す） |
| `enemy_all` | 敵の生存者**全員** |
| `ally_all` | 味方の生存者**全員**（**使用者を含む**） |
| `ally_lowest_hp` | 味方の生存者のうち、**HP割合が最も低い1体**（単体回復） |
| `self` | **使用者のみ** |

### 決めておくこと（実装時に迷わないため）

- **距離は `abs(t.x - user.x)` の1次元。** ユニットは `x` しか持たない（`unit.gd` 59行）
- **`ally_lowest_hp` は「割合」で比べる**（`hp / max_hp`）。絶対値だと `max_hp` の大きい前衛が常に選ばれる
- **同率のときは配列の先頭を採る。** 並び順は `parties.json`（現在は `[僧侶, 弓兵, 剣士]`）
- **`enemy_nearest_2` は、生存者が2体未満なら**いる分だけに当てる。空振りにしない
- **対象が0体なら何もせず空配列を返す**（今の `_resolve_single()` / `_resolve_aoe()` と同じ挙動を保つ）
- ⚠ **`BattleSession` には距離順・HP順の取得が無い。** `get_alive_units()` はチーム単位。**並べ替えは `SkillResolver` 側でやる**（`BattleSession` に寄せない。セッションは器のまま保つ）

---

## 4. `effect` の一覧

| 値 | 内容 | 状態 |
|---|---|---|
| `damage` | ダメージ。**`attack_type`（`physical` / `magic`）を見る** | 実装済み |
| `heal` | 回復。**常に `mag` 参照。`attack_type` の欄を作らない** | 実装済み |
| `buff` | 一定時間ステータスを変える | **先送り**（7章） |
| `dot` | 一定時間ダメージを与え続ける | **先送り**（7章） |

**`heal` に `attack_type` を作らない**のは既存の決定（`skill_resolver.gd` 88行のコメント）。回復が攻撃力依存だった事故を直したときのもの。**戻さないこと。**

---

## 5. 今の6件の移行表

**`skills.json` の6件は、この表のとおりに書き換えれば挙動が変わらない。**

| スキルID | 今の `type` | → `target` | → `effect` | 備考 |
|---|---|---|---|---|
| `skill_power_slash` | `single` | `enemy_nearest` | `damage` | |
| `skill_wide_sweep` | `aoe` | `enemy_all` | `damage` | `charge` あり |
| `skill_snipe` | `single` | `enemy_nearest` | `damage` | |
| `skill_arrow_rain` | `aoe` | `enemy_all` | `damage` | |
| `skill_healing_light` | `heal` | `ally_all` | `heal` | `attack_type` は無し |
| `skill_holy_ray` | `aoe` | `enemy_all` | `damage` | `attack_type: magic` |

**挙動は1件も変わらない。** これは器の付け替えだけのタスクにできる。

---

## 6. `SkillResolver` に教えないもの（**既存の前例を守る**）

**`battle_controller.gd` 598〜603行が、チャージ倍率を `multiplier` に畳み込んでから渡している。**

```
effective["multiplier"] = 素の multiplier × power_ratio
SkillResolver.resolve(effective, user, _session)
```

**`SkillResolver` は「チャージ」という概念を知らない。** 倍率が違うスキルを解いているだけ。

**この形を崩さないこと。** 時間・入力・演出が絡むものは `battle_controller` 側で解いて、resolver には**確定した数値だけ**渡す。

---

## 7. 先送りするもの（**理由つき**）

### `buff` / `dot` → **パッシブの回に一緒に作る**

この2つに要るのは**「効果が時間持続する層」**。**パッシブの条件発動（HP半分以下で…）が要求する層と同じもの。**

- `BattleUnit` は `static create()` で `attack_interval_sec` などの派生値を**生成時に確定させ、戦闘中に変わる想定が無い**（`unit.gd` 78行）
- **持続効果を入れるなら、この再計算を設計に含める必要がある**
- `atk_multiplier` は**常に 1.0** だが、`BattleFormula.damage()` まで渡っている。**バフの受け口として既にある**

**2回に分けて作る意味が無い。** パッシブの層ができてから `buff` / `dot` を乗せる。

### `projectile` → **`target` / `effect` の話ではない**

飛翔時間という**3つ目の軸**。`charge` と同じく **resolver の外**（`battle_controller` 側）で解くほうが筋がよい。**この回では扱わない。**

### stub は消さない

`skill_resolver.gd` の `match` から `"buff", "dot", "projectile"` の分岐は**残す**（`push_warning` して空配列を返す今の形）。**消すと「未実装」が見えなくなる。**

---

## 8. 未確定として残すもの

- **スキル12個（3人×4個）の中身と `unlock_level` の割り当て**（Lv5/10/15/20 に1個ずつでよいか）
- **`enemy_nearest_3` 以上が要るか。** 要るまで足さない
- **敵がスキルを使うか。** 現在 `skills.json` の6件は全部 `user_character_id` が味方。**`target` の `enemy_` / `ally_` は「使用者から見た敵味方」**として定義しておけば、敵が使っても向きが反転して通る
- **`buff` の効果値をどこに持たせるか**（`multiplier` を流用するか、別欄にするか）。パッシブの回で決める

---

## 9. 併せて直さないもの（宿題に送る）

- **`DATA_SCHEMA.md` 3-1 のスキル定義が古い。** `name` 表記のままで `name_key` / `attack_type` / `charge` を欠く。**この回で `target` / `effect` に書き換えるときに一緒に直す**
- **`aoe` という名前が実装（敵全員）より広く見える問題**は、`enemy_all` への移行で自然に解消する
- レベル上限が**30が天井**（`base_level_cap` 10 ＋ `research.json` の `level_cap_unlock` 5×4）。**パッシブの Lv40 以降が到達できない。** スキル側には影響しないが、パッシブの回で必ず解く

---

## 10. 完了条件（**この回は設計のみ。コードは書かない**）

このファイルに以下が書かれていること。

- [x] `target` の一覧と、境界の扱い（0体・不足・同率）
- [x] `effect` の一覧
- [x] 今の6件の移行表（**挙動が変わらないことが表で読める**）
- [x] 先送りするものと、その理由
- [x] `SkillResolver` に教えないものの線引き

**実装（`skills.json` の書き換えと `skill_resolver.gd` の作り直し）は別タスク。** EXECを起こしてから着手する。

---

## 11. EXECを書く前に読む必要があるファイル

- `scripts/systems/skill_resolver.gd`（109行・全文）
- `scripts/systems/unit.gd`（185行。**`BattleUnit` の実体。ファイル名が違う**）
- `scripts/systems/battle_session.gd` の `get_alive_units()`（64行）
- `scenes/adventure/battle_controller.gd` 585〜615行（**呼び出し元と `charge` の畳み込み**）
- `resources/balance/master/skills.json`（6件・全文）

---

## 12. 更新履歴

- **初版（2026-08-15）**：`type` を `target` + `effect` の2欄に割ることを決定。体数は `target` の名前に含める（`target_count` は作らない）。`buff` / `dot` はパッシブの回へ、`projectile` は `battle_controller` 側へ先送り
