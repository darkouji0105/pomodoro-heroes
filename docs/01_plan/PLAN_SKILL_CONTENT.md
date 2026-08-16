# 【作戦計画書】スキルの中身（3人 × 残り4個 ＝ 12個）

**第2層。第1層（ゲームの中身の正）は `GAME_DESIGN.md` 3-2 と 5-2。器の正は `PLAN_SKILL_TEMPLATE.md`。**

**このファイルは「どんなスキルを書くか」の決定台帳。** 器の形はここで決めない（`PLAN_SKILL_TEMPLATE.md` が持つ）。**逆に、スキル1個の中身を変えるときにあの決定台帳を書き換えなくて済むよう、中身はここに集める**（`PLAN_SKILL_TEMPLATE.md` 21章「担当外」で、そう決めてある）。

**このファイルにコードは載せない。** 実装は `EXEC_SKILL_CONTENT.md` が持つ。

---

## 0. 着手前に実コードを確認した結果（2026-08-16・`grep` 済み）

| 調べたもの | 結果 |
|---|---|
| `skills.json` | **6件**。全部 `unlock_level: 1`。`activation` / `target` / `effects[]` の形（段階1で付け替え済み） |
| `characters.json` の `skills[]` | **各キャラ2件**。⚠ **これが候補一覧で、配列の順序が画面の並び順**（`game_manager.gd` 67〜71行） |
| スキル選択画面 | ✅ **実在する**（`scenes/guild/skill_select_screen.gd`）。**6候補から2つ選ぶ画面が既にある** |
| 「Lv%d で解放」のグレー表示 | ✅ **実装済み**（`skill_select_screen.gd` 150〜153行 → `GameManager.get_skill_unlock_level()`）。⚠ **6件とも `unlock_level: 1` なので一度も表示されたことがない** |
| 装備の可否 | `game_manager.gd` 1931〜1934行。`unlock_level > level` なら弾く |
| ダメージ式 | `BattleFormula.damage()`：`floor(power × multiplier × 100 / (100 + defense))`。**除算。最低1** |
| 回復 | `SkillResolver._apply_heal()`。⚠ **全対象に同じ数値を配る**（対象ごとに計算し直さない）／⚠ **`of: "target"` は必ず 0.0**（`target` を渡していないため） |
| `attack_type: "true"` | 防御を 0 として扱う（`skill_resolver.gd` 247〜249行）。**利用者ゼロ** |
| `sort` の5値 | 全部実装済み。⚠ **`farthest` / `lowest_hp` / `highest_hp` は実機で1度も通っていない** |
| `scale_from` の変数 | 10軸（`GameManager.get_stat_keys()`）／`hp_current` `hp_lost` `hp_ratio` `hp_lost_ratio`／`distance`。`of` は `user` / `target` |
| レベル上限 | `base_level_cap` **10** ＋ `research.json` の `level_cap_unlock` **5 × 4** ＝ **最大30**。⚠ **Lv15 / Lv20 の解放には研究が要る** |
| キャラの素の能力値 | 剣士 `atk18 def6 hp120`（近接60・物理）／弓兵 `atk14 spd70 crit10`（射程300・物理）／僧侶 `mag16 mdef6`（射程250・魔法） |
| 割り振り可能な軸 | 剣士 `hp/atk/def`／弓兵 `hp/atk/atkspd`／僧侶 `hp/mag/mdef` |

---

## 1. このPLANのスコープ

| 取る | 取らない |
|---|---|
| **3人 × 4個 ＝ 12個**のスキルの中身 | スキルの器（`PLAN_SKILL_TEMPLATE.md`） |
| `unlock_level` の割り当て（Lv5 / 10 / 15 / 20） | **バランス調整**（`PLAN_IMPLEMENTATION.md` 3章） |
| 倍率・`scale_from` の**初期値** | 敵のスキル・パッシブ・ルーン |
| `name_key` と `ja.csv` の日本語 | 演出・アニメーション |

⚠ **「今の器で書けるものだけ」で12個を埋める。** 段階2（多段・遅延）・段階3（buff / dot）を待たない。

**待たない理由が2つある。**

1. ⚠ **器が「利用者ゼロの受け口」だらけのまま次の段に進むと、受け口が正しいかを一度も確かめずに段を積むことになる。** 段階1で足した `farthest` / `lowest_hp` / `highest_hp` / `attack_type: "true"` / HP派生 / `distance` / `of: target` は**全部、実機で1度も通っていない**（`NEXT_STEPS.md` 8章の宿題）
2. **スキル選択画面の「Lv%d で解放」も、候補が2個しかないので一度も出ていない。** 候補が6個になって初めて画面として成立する

> **段階2・段階3が入ったら、この12個は書き直してよい。** ⚠ **書き直しても壊れないのは、セーブがスキルIDしか持たないから**（`PLAN_SKILL_TEMPLATE.md` 18章）。**IDだけは改名しない。**

---

## 2. 役割軸（**中身を決める前に決める**）

⚠ **12個を思いつきで並べると、3人とも「単体に大ダメージ」が4個ずつになる。** 先に軸を決める。

| キャラ | 軸 | 割り振りとの噛み合わせ |
|---|---|---|
| **剣士** | **自分の体を賭ける**（自傷・低HPで伸びる・防御で殴る） | `hp` と `def` に振ったぶんが**攻撃力として返ってくる** |
| **弓兵** | **位置と対象の選び方**（一番弱いのを狩る・遠いほど強い・後衛を抜く） | `atkspd` に振ると手数系が伸びる |
| **僧侶** | **配り方**（全体か単体か・自分に返すか） | `mdef` に振ると攻撃も伸びる |

**この軸は「今の器で書けるもの」から引いた。** ⚠ **器が広がったら軸も変わってよい**（デバフが書けるようになれば僧侶の軸は変わる）。

⚠ **`GAME_DESIGN.md` 3-4 のコンボ（短CDが繋ぎ、長CDの強スキルは乗らない）に合わせて、CDは 6〜14 秒に散らす。** 全部同じCDにしない。

---

## 3. 12個の決定

**表記**：`atk × 1.2` は `scale_from` の項（`{ "source": "atk", "of": "user", "weight": 1.2 }`）。
**ダメージ ＝ multiplier × Σ(weight × 変数) × 100 / (100 + 防御)**（`PLAN_SKILL_TEMPLATE.md` 5-5-1）。

### 3-1. 剣士 `char_swordsman`

| Lv | ID | 日本語 | CD | `target` | `effects[]` |
|---|---|---|---|---|---|
| **5** | `skill_reckless_strike` | 捨て身の一撃 | 10.0 | 敵 `nearest` 1体 | ① `damage` 倍率 **3.4**・物理・`atk × 1.0`<br>② `damage` **`target: {team: self}`**・**`attack_type: "true"`**・倍率 **0.12**・`hp × 1.0` |
| **10** | `skill_last_stand` | 背水の刃 | 9.0 | 敵 `nearest` 1体 | `damage` 倍率 **1.6**・物理・`atk × 1.2 + hp_lost × 0.15` |
| **15** | `skill_shield_bash` | 盾撃 | 7.0 | 敵 `nearest` 1体 | `damage` 倍率 **1.5**・物理・`atk × 0.8 + def × 2.0` |
| **20** | `skill_helm_splitter` | 兜割り | 14.0 | 敵 **`highest_hp`** 1体 | `damage` 倍率 **2.2**・**`attack_type: "true"`**・`atk × 1.0` |

⚠ **`skill_reckless_strike` の②で使用者が死にうる。** `hp` は**最大HP**（`unit.gd` 101行で `max_hp = get_stat("hp")`）なので、**残HPが最大HPの12%未満なら自死する。** **これは仕様。**（`SkillActivation` は使用者の生死しか見ない。撃つ前に止める仕組みは作らない）

### 3-2. 弓兵 `char_archer`

| Lv | ID | 日本語 | CD | `target` | `effects[]` |
|---|---|---|---|---|---|
| **5** | `skill_finisher` | 追い討ち | 7.0 | 敵 **`lowest_hp`** 1体 | `damage` 倍率 **3.0**・物理・`atk × 1.0` |
| **10** | `skill_long_shot` | 遠矢 | 10.0 | 敵 `nearest` 1体 | `damage` 倍率 **2.0**・物理・`atk × 1.0 + distance × 0.08` |
| **15** | `skill_rapid_volley` | 速射 | 8.0 | 敵 `nearest` **2体** | `damage` 倍率 **1.3**・物理・`atk × 1.0 + atkspd × 1.5` |
| **20** | `skill_piercing_arrow` | 貫きの矢 | 13.0 | 敵 **`farthest`** 1体 | `damage` 倍率 **2.4**・**`attack_type: "true"`**・`atk × 1.0` |

⚠ **`distance` は `of` を読まない**（`skill_resolver.gd` 372〜375行）。`user` と**その効果の対象**の距離。書いても無視されるので**書かない。**

### 3-3. 僧侶 `char_priest`

| Lv | ID | 日本語 | CD | `target` | `effects[]` |
|---|---|---|---|---|---|
| **5** | `skill_mend` | 集中治療 | 6.0 | 味方 **`lowest_hp`** 1体 | `heal` 倍率 **2.2**・`mag × 1.0` |
| **10** | `skill_drain_life` | 吸命 | 9.0 | 敵 `nearest` 1体 | ① `damage` 倍率 **1.6**・魔法・`mag × 1.0`<br>② `heal` **`target: {team: self}`**・倍率 **0.8**・`mag × 1.0` |
| **15** | `skill_purge_wave` | 浄化の波動 | 12.0 | 敵 `all` | `damage` 倍率 **1.0**・魔法・`mag × 0.7 + mdef × 1.5` |
| **20** | `skill_judgement` | 裁きの雷 | 14.0 | 敵 `nearest` 1体 | `damage` 倍率 **1.4**・魔法・`mag × 1.2 + (hp_ratio **of: target**) × 40.0` |

⚠ **`heal` に `attack_type` を書かない**（`PLAN_SKILL_TEMPLATE.md` 5-2。回復が攻撃力依存だった事故の再発防止）。
⚠ **`heal` の `scale_from` に `of: "target"` を書かない。** `_apply_heal()` は対象を渡さないので**必ず 0.0 になる**（無音でゼロ）。

### 3-4. これで埋まる「利用者ゼロの受け口」

| 受け口 | 埋める人 |
|---|---|
| `sort: lowest_hp` | `skill_finisher` / `skill_mend` |
| `sort: highest_hp` | `skill_helm_splitter` |
| `sort: farthest` | `skill_piercing_arrow` |
| `attack_type: "true"` | `skill_reckless_strike` ② / `skill_helm_splitter` / `skill_piercing_arrow` |
| `scale_from` の HP派生 | `skill_last_stand`（`hp_lost`）／`skill_judgement`（`hp_ratio`） |
| `scale_from` の `distance` | `skill_long_shot` |
| `scale_from` の `of: "target"` | `skill_judgement` |
| `count` が 2 以上 | `skill_rapid_volley` |
| 効果ごとの `target` 上書き | `skill_reckless_strike` ②／`skill_drain_life` ② |
| 1スキルに効果2つ | `skill_reckless_strike` / `skill_drain_life` |
| 単体回復 | `skill_mend` |
| 「Lv%d で解放」のグレー表示 | 12件すべて |

**残る受け口は `target.range` だけ**（下記 5-1）。

---

## 4. `unlock_level` の割り当て（決定）

**`GAME_DESIGN.md` 5-2 のとおり Lv5 / 10 / 15 / 20 に1個ずつ。既存2件は `unlock_level: 1` のまま。**

| キャラ | 1 | 1 | 5 | 10 | 15 | 20 |
|---|---|---|---|---|---|---|
| 剣士 | 強撃 | 横薙ぎ | 捨て身の一撃 | 背水の刃 | 盾撃 | 兜割り |
| 弓兵 | 狙撃 | 矢の雨 | 追い討ち | 遠矢 | 速射 | 貫きの矢 |
| 僧侶 | 癒しの光 | 聖光 | 集中治療 | 吸命 | 浄化の波動 | 裁きの雷 |

⚠ **`characters.json` の `skills[]` の順序が画面の並び順**（`game_manager.gd` 68行）。**上の表の左から右の順に並べる**（`unlock_level` 昇順）。並び順と解放順が食い違うと、グレーの行が間に挟まって読みにくい。

⚠ **Lv15 / Lv20 は研究でレベル上限を上げないと到達できない**（`base_level_cap` 10 ＋ `level_cap_unlock` 5×4）。**実機確認の手順に影響する**（EXEC の完了条件で扱う）。

---

## 5. 未確定として残すもの

### 5-1. `target.range` は今回も全件省略する（決定）

**`PLAN_SKILL_TEMPLATE.md` 4-5 が「数値は座標定数とセットで後決め」としている。** 座標定数（味方 `x=200/300/400`・敵 `x=900〜`・**最短500**）が未決のまま数値を入れると、**遠隔ですら初期位置から届かないスキルができる。**

- **12件とも `range` を書かない（＝無制限）**
- ⚠ **代償：剣士（`attack_range` 60）のスキルが画面端から届く非対称が残る。** これは今もそうなので**新しい事故ではない**
- **座標定数を決める回に、18件まとめて `range` を入れる**（宿題）

### 5-2. 倍率と `weight` は仮（決定）

**バランス調整は `PLAN_IMPLEMENTATION.md` 3章の別枠。** このPLANが保証するのは「桁が壊れていないこと」だけ。

⚠ **特に怪しいのが3件**（EXEC の事故りやすい箇所に名指しで書く）。

| スキル | 何が怪しいか |
|---|---|
| `skill_judgement` | `hp_ratio` は 0.0〜1.0。`weight 40.0` は**レベルで伸びない定数項**。Lv20 の `mag` が40を超えると存在感が消える |
| `skill_long_shot` | `distance` も同じ（0〜700 × 0.08 で最大 +56） |
| `skill_shield_bash` | 剣士の素の `def` は 6。**`def` に振らないとただの弱い攻撃**。振ったときだけ強い |

### 5-3. ⚠ 器の穴：`scale_from` は「和」しか書けない（**報告。勝手に直していない**）

**`PLAN_SKILL_TEMPLATE.md` 5-5-1 は `multiplier × Σ(weight × 変数)` と決めている。積が書けない。**

> **`atk × (1 + hp_lost_ratio)`（＝「失ったHPに応じて攻撃力が伸びる」）が書けない。**

**割合の変数（`hp_ratio` / `hp_lost_ratio`）は、必ず「レベルで伸びない定数項」にしかならない。**

- **今回の回避**：`skill_last_stand` は割合ではなく**生値の `hp_lost`** を使う。`hp_lost` は最大HPに比例するので、`hp` に振れば伸びる
- ⚠ **`skill_judgement` は回避できていない**（「対象が元気なほど痛い」は対象側の割合でしか書けない）。**5-2 の怪しい3件に入っている理由がこれ**
- **穴の埋め方の候補**（⚠ **このPLANでは決めない。器の話なので `PLAN_SKILL_TEMPLATE.md` 側の判断**）：
  - `scale_from` の項に `mul: true` のような欄を足して積の項を許す
  - 変数表に「積み済みの合成変数」を足す（`atk_x_hp_lost_ratio` のような行）。⚠ **DLCで組み合わせぶん増えるので筋が悪い**

### 5-4. 決めていないもの

- **敵にスキルを持たせるか**（`PLAN_SKILL_TEMPLATE.md` 12-2。器としては追加ゼロだが、AIが別EXEC）
- **`skill_reckless_strike` の自死を止めるか**（3-1）。⚠ 止めるなら `SkillActivation` に条件が1本増える＝**発動可否の一箇所化に効く実例になる**ので、止めると決めるのは安い
- **ルーン（スキル発動時の追加挙動）との対応**（`GAME_DESIGN.md` 7-5）。**スキル1／スキル2の枠に紐づくので、候補が6個になっても変わらない**
- **段階2・段階3が入ったあと、どの12個を書き直すか**

---

## 6. 完了条件（**このPLANは設計のみ**）

- [x] 役割軸を3人ぶん決めた（2章）
- [x] 12個の中身（`target` / `effects[]` / 倍率 / `scale_from` / CD）
- [x] `unlock_level` の割り当てと**並び順の規則**（4章）
- [x] `range` を省略する決定とその代償（5-1）
- [x] 倍率が仮であること、特に怪しい3件（5-2）
- [x] ⚠ **器の穴（積が書けない）を発見して報告した**（5-3）
- [x] 段階2・段階3で書き直してよい／IDだけ改名しない（1章）

**実装は `EXEC_SKILL_CONTENT.md`。**

---

## 7. 更新履歴

- **初版（2026-08-16）**：段階2の前に「今の器で書けるスキル12個」を書くフェーズを挟む決定。⚠ **`scale_from` が積を書けない穴を発見**（5-3）
