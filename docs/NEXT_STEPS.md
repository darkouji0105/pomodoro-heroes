# 次にやること：ギルドの研究

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、手順の型は`WORKFLOW.md`。

---

## なぜ研究が次なのか

**育成がレベル10で止まっている。**

`get_effective_level_cap()`は以下を返す実装になっている。

```
base_level_cap（character_config.tres・現在10）
  ＋ 解放済み level_cap_unlock ノードの effect_value 合計
```

研究ツリー（`RESEARCH_TREE`）が空なので、後半の合計はいま常に0。**全キャラがレベル10で頭打ちになる。**

裏を返すと、**接続はもう通っている。** 研究側でノードを`unlocked: true`にすれば、育成画面もGameManagerも1行も変えずに上限が伸びる。育成のときに`battle_controller.gd`が無変更で反映されたのと同じ構図。

```
戦闘で training_material を得る
  → 育成でレベルを上げる（いまレベル10で止まる）
  → 研究で上限を解放する ← ここ
  → さらにレベルを上げられる
  → もっと先のステージに挑める
```

もう1つ、**研究には`stat_boost_all`もある。** `get_stat_boost_all()`は実装済みで、`get_effective_stats()`が既に呼んでいる。**ノードを解放すれば全キャラのステータスに即反映される。** こちらも接続済み。

---

## 最初にやること

新しい会話を開いて、設計役（Claude）に以下を渡す。

1. `PROJECT_STATUS.md`
2. このファイル
3. `AGENTS.md`
4. `PLAN_GUILD_RESEARCH.md`（第2層。既にある）
5. `DATA_SCHEMA.md` の 4-4「研究」
6. **`EXEC_GUILD_TRAINING.md`**（直前のタスク。書き方を揃えるため）

そのうえで、**実コードを見せる。**

- `autoload/game_manager.gd`（`get_effective_level_cap` / `get_stat_boost_all` / `unlock_research_node`まわり）
- `autoload/balance.gd` と `character_config.gd`
- `scenes/guild/guild_screen.gd` と `.tscn`（研究画面への導線）
- **`scenes/guild/training_screen.gd` と `.tscn`**（同じ作りに揃えるため）
- `scripts/utils/state_keys.gd`
- `scenes/ui/components/primary_button.gd` / `resource_display.tscn`

**`PLAN_GUILD_RESEARCH.md`は実コードを見ずに書かれている可能性が高い。** 育成のPLANはスコープごと全面書き直しになった（スキル・装備を含む前提で書かれていたが、装備アイテムが1つも存在しなかった）。**突き合わせて、ズレがあればPLANを先に直す。**

---

## このタスクでいま分かっていること

### 実装済みで使えるもの

| もの | 状態 |
|---|---|
| `GameManager.get_effective_level_cap(id)` | **本実装済み。** `base_level_cap` ＋ 解放済みノードの合計 |
| `GameManager.get_stat_boost_all()` | **本実装済み。** `get_effective_stats()`が既に呼んでいる |
| `RESEARCH_TREE`の状態構造 | `state_keys.gd`に定数あり（`RESEARCH_UNLOCKED` / `RESEARCH_EFFECT_TYPE` / `RESEARCH_EFFECT_VALUE` / `RESEARCH_PREREQUISITES`）。中身は空 |
| `EFFECT_LEVEL_CAP_UNLOCK` / `EFFECT_STAT_BOOST_ALL` | `state_keys.gd`に定数だけある |
| 素材の増減 | `material_changed`シグナル。`add_material()`は残高を確認しないので要注意 |
| モーダル | `Modal.notify` / `Modal.confirm` |
| `GrowthFormula` | 式を`.tres`から評価する静的クラス。研究のコスト式にも使える |
| 育成画面 | 一覧⇄詳細を1シーンで切り替える形。**同じ作りにすると迷いが少ない** |

### 決めることになるはず

- **ノードの数と依存関係**（`prerequisites`）。第1弾は何個か
- **上限解放の刻み幅。** 1ノードで+5か+10か。**ここが育成の手触りを直接決める**
- 解放に使う素材の種類と数（`training_material`と同じでよいか、別を作るか）
- `stat_boost_all`の効果値
- ツリーの見た目（**縦1列か、分岐ありか**）
- ノード定義をどこに置くか（`research.json`を新規に作るか、`.tres`か）

**マスターデータの形式はJSONと決まっている**（`PROJECT_STATUS.md`決定済み）。ID で引く量産型データなので`resources/balance/master/research.json`が素直。

### スコープの目安

**第1弾は「上限解放ノードだけ」でもいい。** `stat_boost_all`は分けられる。

理由は、上限解放だけで「素材を使う → さらにレベルが上がる」が成立するから。**検証できないものは作らない。**

ただし`get_stat_boost_all()`は既に動くので、**ノードを1つ足すだけなら追加コストはほぼ無い。** ここは設計役と相談して決める。

### 見た目の注意

**ツリー表示に凝らない。** 育成画面と同じく、まずは縦に並んだリストで十分。線を引く・分岐を描くのはあとから足せる。

---

## 渡し方（育成のときと同じ）

### 完了条件はA章とB章に分ける

- **A章：`print`で結果が出るもの**（解放の成否・素材の増減・`get_effective_level_cap()`の戻り値）
- **B章：人間が画面を見て確認するもの**

**育成ではA章13項目が全部通ったあとで、B章の実機確認で「戻るボタンが2つ並ぶ」が見つかった。** A章が通ってもB章を省かない。

### 誰が書くか

**育成では実装役に投げず、設計役が`.gd`を全部書いた。** 結果、PRE_PLAN・レビュー・IMPL_LOGの4段階が不要になり、事故もゼロだった。

研究も**新規ファイル中心**なので同じ判断でよい。ただし`game_manager.gd`（884行）に手を入れるなら**必ず設計役が全文を書く**。原本をコピーして該当箇所だけ差し替える方式なら、既存関数が変質しない。

### 止まる条件（実装役を使う場合）

- 1つのファイルへの書き込みが2回失敗したら中止して報告
- 1つの症状に対して試す方法は2つまで
- 実装できなかったものは「未実装」と正直に書いてよい

---

## 検証手順を書くときの注意（育成での失敗）

EXECの人間向け手順に「再生してログで確認する」と書いたが、**その`print`に該当項目が含まれていなかった。** 通らない確認手順を指定していた。

**検証手順は、その出力が実在することを確かめてから書く。**

また、`initial_state_config.tres`を編集しても**セーブデータが既にあると反映されない**（`_init_from_config()`は`has_save()`が`false`のときしか呼ばれない）。研究の初期状態を`.tres`で試すときも同じ罠がある。

---

## 研究のあとの順番

1. **ショップ** — ゴールドの出口
2. **作業場** — 素材の出口。時間投資型
3. **パーティ選択** — 第2層から書く
4. **バランス調整** — ここで初めて実際に何日か使う

**装備・強化が入るまで、本格的な試用はしない。** 数値の調整もそれまで待つ。全部JSONか`.tres`なので後から変えられる。

---

## 溜まっている宿題（気が向いたら）

`PROJECT_STATUS.md`の「溜まっている宿題」を参照。特に以下は小さいのに効く。

- 受け取り報告で「宝箱を0個」と出るのを直す
- 拠点下部のレイアウト調整
- プロジェクト直下のゴミファイル（`bash`など）を削除
- `training_screen.gd`の`CHARACTER_IDS`が決め打ち。`MasterDataLoader`にキー一覧を返す関数が無いため
