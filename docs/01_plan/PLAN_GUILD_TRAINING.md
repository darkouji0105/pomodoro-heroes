# 【作戦計画書】ギルド - 育成

第2層・作戦計画。**実コードと突き合わせて全面改訂した版。** 旧版は実コードを見ずに書かれており、以下がズレていた。

| 旧版の記述 | 実際 |
|---|---|
| 「保持責任をここで確定する」 | `AGENTS.md`で確定済み。`CHARACTER_GROWTH`も`state_keys.gd`に定義済み |
| `get_effective_level_cap()`を「呼び出す形にする」 | **既に実装済み。** ただし研究ツリーが空なので常に`0`を返す |
| スキル選択・装備を含む | 第1弾から外す（`NEXT_STEPS.md`のスコープ方針） |
| 完了条件が4項目 | A章／B章に分割する方式へ変更 |

---

## 1. スコープ

### 含む（第1弾）
- 育成画面（キャラクター一覧 → 個別ページ）
- レベルアップ（専用素材消費型）
- レベルアップに伴うステータス上昇と、その計算式の外出し
- レベル上限の暫定値（研究が無い状態でも機能する形）
- `GameManager`の育成ダミー関数の本実装

### 含まない
- スキル選択（候補が1キャラ2つしかなく、選ぶ意味が成立しない）
- 装備（`type: "equipment"`のアイテムが1つも存在しない）
- 研究ツリーそのもの（レベル上限の解放）
- スキル効果の発動ロジック（戦闘画面側）

**スキル・装備は画面にボタンだけ置き、押すと`placeholder_screen.tscn`へ遷移させる。**
`guild_screen.gd`が既に使っている方式をそのまま流用する。枠を先に用意しておくことで、後から入れるときにレイアウトを組み直さずに済む。

---

## 2. 画面構成

```
ギルド画面
  └─ 育成画面（新規）
       ├─ キャラクター一覧（3人）
       └─ 個別キャラページ
            ├─ 現在のレベル／ステータス
            ├─ レベルアップボタン（必要素材・所持数を表示）
            ├─ スキルボタン → placeholder_screen
            └─ 装備ボタン → placeholder_screen
```

**一覧と個別ページは同一シーン内で切り替える。** シーンを2つに分けない。新規ファイル1つで完結するため実装役に渡しやすく、`SceneManager`の履歴管理（現状ダミー扱い）にも依存しない。

遷移元の`guild_screen.gd`は`GUILD_SCENES["training"]`を新シーンのパスへ差し替える。**この差し替えは、新シーンが存在するようになってから人間が行う**（先に書くと遷移先が無くエラーになる）。

---

## 3. 育成データの保持責任（確定済み・参照のみ）

`AGENTS.md`のGameManager責務は既に「複数画面から参照される永続データ全般」であり、`CHARACTER_GROWTH`も状態構造の表に載っている。**この計画書で新たに決めることは無い。**

育成専用のAutoloadは追加しない（Autoloadは5つに固定）。

---

## 4. データ構造

`DATA_SCHEMA.md` 4-3に準拠する。第1弾で実際に値が入るのは`level`と`stats`のみ。

```
character_growth: {
  "char_swordsman": {
    "level": 3,
    "stats": { "hp": 136, "atk": 22, "def": 8, "spd": 62 },
    "skills":    { "slots": [] },          # 第1弾では空のまま
    "equipment": { "weapon": null, "armor": null, "accessory": null }
  }
}
```

**`skills`と`equipment`のキーは第1弾でも作る。** 後から足すとセーブデータの移行が必要になるため。

### 4-1. `stats`が持つのは「レベル由来の素の値」だけ

研究のボーナス（`get_stat_boost_all()`）や、将来の装備補正は**保存しない。**
表示・戦闘で使う最終値は、都度合成する`get_effective_stats(character_id)`から取る。

理由：保存値に外部要因を混ぜると、研究ノードの効果値を1つ変えただけで既存セーブの`stats`が実態とズレる。**素の値だけを保存すれば、後から要因が増えてもセーブデータの移行が要らない。**

```
get_effective_stats(id) = stats（保存値）
                        + get_stat_boost_all()（研究・現在は空）
                        + 装備補正（未実装・常に0）
```

**戦闘側は当面`stats`をそのまま読んでよい**（研究も装備も無いため差が出ない）。研究が入った時点で、戦闘側の参照を`get_effective_stats()`へ1行差し替える。**この1行は研究のタスクに含める。**

### 4-2. 遅延初期化（保存しない既定値）

`get_character_growth(id)`は、エントリが無ければ`characters.json`の基本値から既定値（`level: 1`）を組み立てて返す。**この時点では`_state`に書き込まない。**

- レベル1のキャラはセーブデータに現れない
- 初めてレベルアップした時点で初めて書き込まれる
- **キャラクターを追加したら、何もしなくても既定値で出てくる**（`initial_state`にもセーブ移行にも手を入れなくてよい）

---

## 5. 数値と計算式の置き場所

`AGENTS.md`の数値管理ルール（ハードコード禁止）に従う。**式そのものも調整対象とする。**

### 5-1. キャラごとの伸び幅 → `characters.json`

IDで引く量産型データなのでJSON側（`resources/balance/master/`）。

```json
"char_swordsman": {
  "hp": 120, "atk": 18, "def": 6, "spd": 60,
  "growth_per_level": { "hp": 8, "atk": 2, "def": 1, "spd": 1 }
}
```

`growth_per_level`が無いキャラは全項目0として扱う（レベルを上げても伸びないだけで、エラーにしない）。

### 5-2. 式と全体設定 → `character_config.tres`

```
level_up_material_id  : String   （未確定・§8参照）
base_level_up_cost    : int
cost_growth_per_level : float
base_level_cap        : int      （新規。研究が無い間の上限）
stat_growth_formula   : String   既定 "base + growth * (level - 1)"
level_up_cost_formula : String   既定 "base + growth * (level - 1)"
```

**式は文字列として持ち、Godotの`Expression`クラスで評価する。** Inspectorで書き換えるだけで、コードに触らず線形から二次・指数へ変更できる。

使える変数：

| 式 | 変数 |
|---|---|
| `stat_growth_formula` | `base`（`characters.json`の基本値）／`growth`（`growth_per_level`の該当値）／`level` |
| `level_up_cost_formula` | `base`（`base_level_up_cost`）／`growth`（`cost_growth_per_level`）／`level`（現在レベル） |

### 5-3. 評価は専用ヘルパーに閉じる

`scripts/utils/growth_formula.gd`（静的クラス。Autoloadにしない）。

- `evaluate(formula: String, vars: Dictionary, fallback: float) -> float`
- パースまたは実行に失敗したら`push_warning`を出して`fallback`を返す
- **式が壊れていてもゲームは止まらない**（`.tres`を人間が編集する以上、typoは必ず起きる）
- 呼び出し側は`GameManager`のみ。画面側から式を評価しない

**このファイルは設計役が書く。** 境界条件（空文字・ゼロ除算・非数値の戻り）が多いため。

---

## 6. GameManagerへの変更

**`game_manager.gd`は691行。`WORKFLOW.md`の基準により、この差分は設計役が全文を書く。** 実装役には渡さない。

### 6-1. 本実装にするもの

| 関数 | 内容 |
|---|---|
| `get_character_growth(id)` | エントリが無ければ既定値を組み立てて返す（§4-2） |
| `level_up_character(id)` | 素材が足りていれば消費してレベル＋1、`stats`を再計算。上限到達時と素材不足時は**何もせず`false`** |
| `get_effective_level_cap(id)` | **既存実装を書き換え。** `Balance.character.base_level_cap` + 研究ノード合計 |

### 6-2. 新規に足すもの

| 関数 | 内容 |
|---|---|
| `get_level_up_cost(id)` | `{material_id, amount}`を返す。画面はこれを表示に使う |
| `get_effective_stats(id)` | 保存値＋研究＋装備の合成（§4-1） |
| `_default_growth_for(id)` | private。`characters.json`から既定値を組み立てる |
| `_recalc_stats(id, level)` | private。`stat_growth_formula`で4項目を再計算 |

### 6-3. シグナル

`character_growth_changed(character_id: String)` を追加する。画面はこれを受けて再描画する。

**`AGENTS.md`の「GameManagerのシグナル」表にも追記が必要。** 片方だけ直すと食い違う。

### 6-4. 素材の消費

減算専用の関数は無いため`add_material(id, -amount)`を使う。**`add_material()`は残高を確認しないので、`level_up_character()`の中で必ず先に`get_material_count()`で確認する。** 確認前に減算しない。

### 6-5. `load_state()`の型キャスト（見落とすと必ず壊れる）

現在の`load_state()`は gold / gems / stamina / materials 等しか`int()`していない。**JSONから復元した`character_growth`は`level`も`stats`も全てfloatになる。**

`character_growth`用のキャストブロックを追加する：

```
for character_id in character_growth:
    level を int()
    stats の hp / atk / def / spd を int()
```

これを入れないと、セーブ→ロード後に`hp: 136.0`と表示され、レベル比較もずれる。

---

## 7. UIロジック概要

### キャラクター一覧
- `characters.json`のキーを走査して並べる（**3人と決め打ちしない**。キャラ追加に自動で対応するため）
- 各行に名前（`name_key`を`tr()`）と現在レベルを表示

### 個別ページ
- `get_character_growth()`と`get_effective_stats()`から現在値を表示
- レベルアップボタンの下に「必要素材：◯◯ × N（所持 M）」を表示
- **素材が足りないときはボタンを無効化する。** 押せてから失敗するより、押せないほうが親切
- **上限に達しているときは「研究で解放が必要」と案内して無効化する**
- 成功したら`character_growth_changed`を受けて表示を更新
- 素材の所持数は`material_changed`シグナルでも更新する

### スキル・装備
- ボタンのみ。`SceneManager.change_scene_with_data(PLACEHOLDER_PATH, {TransferKeys.SCREEN_ID: ...})`
- `screen_id`と対応する翻訳キーが要る。**`ja.csv`の追記は人間が行う**（AIに触らせない）

---

## 8. レベルアップ用素材

### 8-1. 素材そのものが存在しない（このタスクで作る）

`stages.json`の報酬は現在`construction_material`のみ。**レベルアップ用素材は1つも存在せず、入手経路も無い。** IDを決めるだけでは足りず、以下4つが揃わないと完了条件B-11（育成後のステータスで戦う）を検証できない。

| やること | 場所 | 誰が |
|---|---|---|
| 素材ID `training_material` を定義 | — | 決定済み（下記） |
| ステージ報酬に追加 | `resources/balance/master/stages.json` | 実装役（JSON追記なので可） |
| 翻訳キー `ui_res_training_material` | `localization/ja.csv` | **人間**（AIに触らせない） |
| 動作確認用の初期所持 | `InitialStateConfig`（`.tres`） | **人間** |

**素材IDは`training_material`。** 既存の`construction_material`と綴りの流儀を揃える（`mat_`等の接頭辞を付けない）。`AGENTS.md`の規約により、翻訳キーは`"ui_res_" + material_id`で機械的に引ける状態を保つ。

### 8-2. ステージ報酬への追記

各ステージの`rewards.materials`に1行足すだけ。**既存の`construction_material`は変えない。**

```json
"rewards": { "gold": 50, "materials": { "construction_material": 3, "training_material": 2 } }
```

| ステージ | `training_material` |
|---|---|
| stage_1 | 2 |
| stage_2 | 4 |
| stage_3 | 6 |

`GameManager.apply_battle_rewards()`は`gold`と`materials`のみを処理する実装になっているため、**この追記だけで反映される。**

### 8-3. 初期所持を必ず入れる

`InitialStateConfig.starting_materials`に`training_material: 50`を入れる。

**これが無いと、育成画面を触るたびに戦闘を1回勝つ必要が出る。** 検証の回転が落ちる。リリース前に0へ戻す。

### 8-4. `WorkshopConfig`の重複フィールドを削除する

`level_up_material_id`が`CharacterConfig`と`WorkshopConfig`の両方に存在する。**作業場側は明らかにコピペ事故。**

→ `workshop_config.gd`から`@export var level_up_material_id`を削除し、`CharacterConfig`に一本化する。`.tres`側に値が入っていれば消えるが、育成では参照しないので影響しない。

### 8-5. 仮の数値（人間が`.tres`で決める）

| 項目 | 仮の値 | 根拠 |
|---|---|---|
| `base_level_up_cost` | 3 | レベル1→2で3個。stage_1を2回勝てば上がる |
| `cost_growth_per_level` | 1.0 | 線形。レベル10までの累計が1キャラ約63個 |
| `base_level_cap` | 10 | 研究が入るまでの暫定 |
| `growth_per_level`（剣士） | hp 8 / atk 2 / def 1 / spd 1 | §5-1 |

**すべて後から変えられる。** 手触りの確認は研究が入ってから（`PROJECT_STATUS.md`の方針）。

---

## 8-6. 残る未確定

| 論点 | 状態 |
|---|---|
| スキルスロットの解放条件 | 第1弾スコープ外。スキル実装時に持ち越し |
| 装備が`atk_multiplier`をどう変えるか | 同上。戦闘側は`1.0`固定で待っている |
| 弓兵・僧侶の`growth_per_level` | 人間が決める |

**`PROJECT_STATUS.md`「横断的な未確定事項一覧」にも反映すること。**

---

## 9. 完了条件

**A章とB章に分けて書く。** EXECにはこの文言をそのまま転記する。

### A章：実装役が`print`で確認する

- [ ] A-1. `get_character_growth("char_swordsman")`が、未育成の状態で`level: 1`と`characters.json`の基本値どおりの`stats`を返す
- [ ] A-2. A-1の直後に`get_state()`を見ても、`character_growth`が空のままである（既定値が保存されていない）
- [ ] A-3. 素材が足りている状態で`level_up_character()`が`true`を返し、`level`が1増える
- [ ] A-4. A-3の後、`stats`の4項目が`stat_growth_formula`どおりの値になっている
- [ ] A-5. A-3の後、素材の所持数が`get_level_up_cost()`の`amount`だけ減っている
- [ ] A-6. 素材が不足している状態で`level_up_character()`が`false`を返し、`level`も素材も変化しない
- [ ] A-7. `get_effective_level_cap()`が、研究ツリーが空でも`base_level_cap`の値を返す（**0ではない**）
- [ ] A-8. レベルが上限に達している状態で`level_up_character()`が`false`を返し、素材が減らない
- [ ] A-9. `character_growth`を含む状態を`load_state()`で復元した後、`level`と`stats`の各値が`int`である（`typeof()`で確認）
- [ ] A-10. `stat_growth_formula`に壊れた文字列を入れても、警告が出るだけでクラッシュしない
- [ ] A-11. `characters.json`に`growth_per_level`が無いキャラでも、レベルアップが`true`を返しクラッシュしない

### B章：人間が実機で確認する

**実装役はここを転記するだけ。検証しない。**

- [ ] B-1. ギルド画面の「育成」ボタンから育成画面へ遷移する
- [ ] B-2. キャラクター一覧に3人が名前つきで並ぶ
- [ ] B-3. キャラクターを選ぶと個別ページが表示され、レベルとステータス4項目が出る
- [ ] B-4. 必要素材と所持数が表示される
- [ ] B-5. レベルアップボタンを押すと、その場で表示が更新される（画面を出入りしなくてよい）
- [ ] B-6. 素材が足りないとき、レベルアップボタンが押せない状態になっている
- [ ] B-7. 上限に達しているとき、案内が表示されボタンが押せない
- [ ] B-8. スキル・装備ボタンを押すと未実装画面へ遷移する
- [ ] B-9. 戻るボタンでギルド画面へ戻る
- [ ] B-10. レベルアップ後にセーブし、ゲームを再起動してもレベルとステータスが保持されている
- [ ] B-11. レベルを上げたキャラで戦闘に入ると、育成後のステータスで戦う

**B-11は戦闘側との接続確認。ここが通れば「素材の使い道」が実際に閉じる。**

---

## 10. EXECを書く前に必要なもの

- [x] `battle_controller.gd`の味方生成部分 — **確認済み。** 147〜154行がキーごとのフォールバックになっており、`stats`に4項目を書けば戦闘側は無変更で反映される
- [x] レベルアップ用素材の扱い — **§8で確定**
- [ ] `MasterDataLoader`（`characters.json`と`stages.json`の読み出し方。`GameManager`から静的に呼べるか）
- [ ] `InitialStateConfig`（`starting_materials`の型）

**残り2つは`GameManager`の差分を書くときに要る。** どちらも設計役が書く範囲なので、EXECの着手自体は止めない。

### 確認済みの副作用（記録）

遅延初期化で既定値を返すようにすると、`battle_controller.gd` 148行の`has_growth`は**常に`true`になる。** 中身は`characters.json`と同値なので挙動は変わらないが、「育成データが無い場合」の経路は今後実行されなくなる。**壊れてはいないが、テストされない分岐が残る**ことは記録しておく。
