# 次にやること：**ダメージ数値を種類で色分けする**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、ルールは`AGENTS.md`と`CLAUDE.md`、**ゲームの中身は`GAME_DESIGN.md`**、**決定台帳は`docs/01_plan/PLAN_SKILL_TEMPLATE.md`**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **これは小さい回。** 段階3の後半③（介入点3種＋復活）の**前**に挟む。**③は回復・状態付与・死亡を扱う回で、画面で起きたことを種類で見分けたくなる回そのもの**だから、先に入れておくと③の検証が軽くなる。

---

## 0. 前のタスクは終わっている（**全項目確認済み**）

**段階3の後半② — 条件（2026-08-17・`5be8399`）。** 4回のテストプレイでログを直読して確認済み（`EXEC_SKILL_CONDITION.md` §9〜§12）。

**PLAN 10章の発火源4つが全部揃った**（自分の実行 `trigger` ／ 購読 ／ **条件** ／ 周期）。

- 条件は `effects[].condition{}` に書く。`buff` / `dot` / `react` に載る（**`host: unit` のみ**）
- **真である間だけ効く**（`active` フラグ）。真になった瞬間に別の状態を付ける形は採っていない
- ⚠ **`.gd` は4回のテストを通して1行も直していない。** 直したのは検証データだけ
- 検証用ステージ **`stage_dbg_condition`**（1波＝`enemy_dbg_cond` ／ 2波＝`enemy_dbg_dot` ＋ `enemy_dbg_buff`×2）

### ⚠ 検証の道具（この回でも使う）

| 道具 | 使い方 |
|---|---|
| **`user://logs/battle_last.jsonl`** | 1行1イベント。実体は `C:/Users/<user>/AppData/Roaming/Godot/app_userdata/pomodoro-heroes/logs/`。⚠ **戦闘を始めるたびに空にして書き直す。読む前に別の戦闘を始めないこと** |
| **冒険選択の「編成」** | ⚠ **`parties.json` はもう触らない**（2026-08-17・`76660bd`）。検証用3体はデバッグビルドでだけ候補に出る |
| **`stage_order.json` の `"debug"` 列** | 検証用ステージ。常設・スタミナも報酬もクリア記録も付かない。⚠ **本番の `"story"` は触らない** |
| `F3` パネル | `P` 状態一覧（**出力パネルに出る**）・`S` CDリセット・`1`〜`4` 速度（1x/2x/4x/8x・**一時停止は無い**）・`O` ログ・`K`/`L` 敵撃破・`J`/`M` 自傷・`V`/`B` 強制勝敗 |

出る出来事：`battle_start` / `wave` / `cast` / `damage` / `heal` / `dot` / `react` / `status_add` / `status_end` / `status_clear` / **`condition`** / `result`。

```
battle_controller  … 入力と表示。ノードを触る唯一の層
      ↓ cast()（スキル・通常攻撃・購読とも）
SkillRuntime       … 待ち行列。trigger・購読の配布と発火・中断
      ↓ 効果1件ずつ（発火は _fire() の1本）
SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
      ↓ host が none 以外
StatusRegistry     … 状態。寿命はスキルより長い

BattleLog          … 静的クラス。どの層からも呼べる（Autoload ではない）
```

---

## 1. このタスク：**ダメージ数値を種類で色分けする**

### なぜ要るか（**人間が実際に困った**）

条件の回の検証中、**「毒でダメージを受けているのか画面で分からない」**と言われた。

**数字は出ている。** DoT のダメージも通常のスキルと同じ `_pop_damage` を通る（`battle_controller.gd:115` のコメントのとおり）。
⚠ **問題は色が「会心か否か」の2択しかないこと**（`unit_view.gd:71`）。

```gdscript
func pop_damage(amount: int, is_crit: bool = false) -> void:
	if is_crit:
		pop_label(str(amount), CRIT_COLOR, CRIT_FONT_SIZE)
	else:
		pop_label(str(amount), DAMAGE_COLOR, DAMAGE_FONT_SIZE)
```

毒の `2` も通常攻撃の `4` も**まったく同じ色・同じ大きさ**で、しかも毒のほうが数字が小さいので埋もれる。

### ⚠ 「量に応じて」ではなく「種類で」分ける

人間の最初の言い方は「**ダメージに応じて**色を変える」だったが、**量で分けても今回の困りごとは解決しない。**
毒が `2`、通常が `4` で**量がほぼ同じ**だから。**分けるべきは種類。**

⚠ **量による色分けは段階4の「バランスの実測」のときに効く**（`GAME_DESIGN.md` 14章）。**この回ではやらない。**

### 着手前に人間が決めること

- **どの種類に分けるか**（通常 ／ 会心 ／ **DoT** ／ 回復 ／ 味方が受けた・敵が受けたの別 ／ 物理と魔法の別）
- **色をどこに置くか**
  ⚠ `AGENTS.md` は「**個別シーンで色を直接指定しない。`theme/main_theme.tres` に一元化**」と言っている。
  だが `unit_view.gd` は既に `DAMAGE_COLOR` / `CRIT_COLOR` / `JUST_COLOR` を**スクリプト内の定数で持っている**。
  **既存に合わせるのか、`Balance` の `.tres` に出すのかを決める**（数値管理ルール的には `.tres` が筋だが、色は数値調整とは別物）
- **大きさも変えるか**（今は `DAMAGE_FONT_SIZE` / `CRIT_FONT_SIZE` / `JUST_FONT_SIZE` の3つ）

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ 表示側に「DoT かどうか」がまだ流れていない（**この回の本体**）

`_on_skill_effects_applied()`（`battle_controller.gd:853`）は results から **`amount` と `is_crit` しか読んでいない。**

```gdscript
_pop_damage(target, int(r.get("amount", 0)), bool(r.get("is_crit", false)))
```

results の形は `{ unit_id, amount, is_heal, is_crit }` ＋ ダメージのときだけ `{ source_unit_id, attack_type }`。
⚠ **「DoT か」を示す欄が無い。** `BattleLog` は `log_results(fired, src, dot_status_id)` の**引数**で外から区別している。

→ **`SkillResolver` の戻り値に1欄足すことになる。**
⚠ **既存の4キー（`unit_id` / `amount` / `is_heal` / `is_crit`）の名前も意味も変えないこと**（`skill_resolver.gd:19` の注記。`battle_controller` がそのまま読む）。**足すのは無害。**

### 2-2. ⚠ 表示の経路を2本にしない

`StatusRegistry.effects_applied` と `SkillRuntime.effects_applied` は**わざと同じ形にして、`_on_skill_effects_applied` の1本に繋いである**（`battle_controller.gd:115-119`）。
⚠ **DoT 専用の表示シグナルを足さないこと。** 経路が2本になると、片方だけ直す事故になる。

### 2-3. ⚠ `_pop_damage` の呼び出し元は4箇所ある

`battle_controller.gd` の **555 / 1149 / 1162 / 1183**。
⚠ **引数を増やすなら既定値を付ける**（`is_crit` が既にその形）。付けないと3箇所が壊れる。
⚠ 1149 / 1162 / 1183 は **F3 パネルの `J` / `M`（デバッグ用の自傷）** 経路。**リリース前に消すもの**（宿題16）。

### 2-4. ⚠ 回復の数字は別経路

`_pop_damage` とは経路を分けてある（`battle_controller.gd:919` の注記）。**回復も色分けするなら、そちらも見ること。**

### 2-5. ⚠ 数字は `tr()` を通さない

数値のみの表示は翻訳しない（`AGENTS.md`）。**`ja.csv` に行を足す必要は無い**（「ジャスト」のような文字を足すなら別）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-17確認）

| | 事実 |
|---|---|
| 数字を浮かべる場所 | `unit_view.gd` の `pop_label(text, color, font_size)` の1本。`pop_damage()` / `pop_just()` がそれを呼ぶ |
| ⚠ ラベルの親 | **自分の子ではなく親コンテナに乗せている。** とどめの一撃で `hide()` された瞬間に文字も消えるのを避けるため（`unit_view.gd:84` の注記）。**変えないこと** |
| 色と大きさの定数 | `unit_view.gd` に `DAMAGE_COLOR` / `CRIT_COLOR` / `JUST_COLOR`、`DAMAGE_FONT_SIZE` / `CRIT_FONT_SIZE` / `JUST_FONT_SIZE` |
| DoT の通り道 | `StatusRegistry._fire_intervals()` → `SkillResolver.resolve()` → `effects_applied` → `_on_skill_effects_applied()` → `_pop_damage()` |
| ダメージの式 | `BattleFormula.damage()` ＝ `max(1, floor(power × multiplier × 100 / (100 + defense)))`。**防御は除算** |
| ⚠ 数字の実測 | 検証用キャラの `atk` は 1 だが**与ダメージは 4**（研究・装備が乗る）。敵 `atk` 5 → **4**（味方の `def` が 4）。**絶対値で期待値を書かないこと。差で見る** |
| 行数 | `game_manager.gd` **2956** ／ `battle_controller.gd` **1215** ／ `skill_schema.gd` **805** ／ `status_registry.gd` **849** ／ `master_data_loader.gd` **597** ／ `skill_resolver.gd` 548 ／ `skill_runtime.gd` 536 ／ `battle_debug_panel.gd` 390 ／ `adventure_select.gd` **360** ／ `battle_log.gd` 290 ／ `unit_view.gd` 約120 ／ `battle_formula.gd` 67 |

---

## 4. このあと来るもの（**このタスクではやらない**）

| 順 | 実装するもの | なぜその順か |
|---|---|---|
| **次** | **③＝介入点3種（回復・状態付与・死亡）＋ 復活** | ⚠ **死亡の介入点は全滅判定より先に置く**（PLAN 11-1） |
| その次 | **④＝変数表の追加 ＋ パッシブ ＋ コンボ** | 購読と条件の両方が要る |
| 3 | `mode: area` ／ `phases[]` / `recast` ／ `spawn` ／ **`point` の条件（オーラ）** | |
| 4 | **バランスの実測**（⚠ ここで「量による色分け」も効く） | 構造が出揃ってから |

---

## 5. 罠

### ドキュメントの「実装済み」を信じない

**ズレが10回起きている。** `grep`で関数の中身を見てから判断する。**勝手に直さず報告する。**

### 関数を足す前に `grep` する

既にある `_exit_tree()` を見ずに2本目を宣言してパースエラーになった。
**足す前に `grep -n "func <名前>"`、足したあとにも `grep` で当たったか確認する。**

### ⚠ Windows の bash で `cat >>` すると追記分が CRLF になる

元が LF の JSON に混ざって壊れる。**JSON に追記したら改行コードを確かめる。**

### ⚠ `battle_last.jsonl` は戦闘のたびに上書きされる（**条件の回で踏んだ**）

本編を回してログを読むつもりが、そのあと検証用ステージに入って**消えた。**
**読む前に別の戦闘を始めないこと。**

### ⚠ 検証データの数字を「意図」と書く前に、射程と時間を計算する（**条件の回で2回踏んだ**）

- **近接（射程50）の敵を、射程300の味方の前に置いた** → 射程に入る前に死んでスキルを撃たなかった
- **敵を2体にしたら状態が2件付き**、1件目が切れても2件目が残って条件が偽に戻らなかった
- ⚠ **条件バフが効くと味方が強くなり、戦闘が短くなり、検証の窓が縮む**（負のフィードバック）。
  「敵のHPを増やす」で押し切ろうとすると、増やすほど強化後の火力で削られるので効きが鈍い

### 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。** コンソールに流さない。

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ `stages.json` だけトップレベルが半角スペース2つ）。`ja.csv`はUTF-8（BOMなし）。

### Godotを起動できない（設計役）

⚠ **「動きました」と書かない。** 完了条件は「ログ」「ファイル」「画面」の3つに分け、**同じことを2箇所に書かない。**
⚠ **`battle_last.jsonl` で判定できる項目は「ファイル」に書く。**
⚠ **ただしこの回は「色」なので、画面の項目が多くなるのが正しい。** 無理にファイルへ寄せないこと。

---

## 6. 引き継いだ宿題

1. ⚠ **多段の2発目に投射物が出ない**（`skill_rapid_volley` の `delay:0.35`）
2. ⚠ **`x is Node and is_instance_valid(x)` の順序が逆な箇所が3つ**（`battle_controller.gd` 163 / 251 / 493行付近）
3. ⚠ **僧侶の範囲攻撃は `sort: all` なので射程外にも当たる**
4. ⚠ **`atk_multiplier` が常に 1.0**
5. ⚠ **`stack` の5部品のうち4つが未実装**（上限・消え方・再付与・閾値）。⚠ **条件の回で `status_count` を作らなかったのはこれが理由**（上限が無いまま閾値が書けると、一度真になったら二度と偽に戻らない）
6. ⚠ **`scale_from` は「和」しか書けない**
7. ⚠ **PLAN 5-2 の効果の欄の表に `delivery` / `stack` / `status_id` / `until` / `condition` が無い**
8. ⚠ **PLAN 10-4 が式の二重経路に触れていない**
9. **`_find_unit()` が3ファイルに同じ形で3本ある**
10. **死亡中にCDが回る**
11. ⚠ **`target.range` が47件とも未設定**
12. ⚠ **コメント中の「`skills.json`」が8ファイルに残っている**
13. ⚠ **フォルダを増やしたら定数に1行足す**（キャラ＝`CHARACTER_DIRS_REQUIRED` ／ 敵＝`ENEMY_DIRS_REQUIRED`（今は空）／ 検証用は `*_OPTIONAL`）
14. **`adventure_config.tres` が空**
15. **状態のUIが無い**（F3 パネルと `P` キーだけ）
16. **検証用のものはリリース前に消す**（デバッグオーバーレイ・デバッグパネル・`P`キー・`tests/battle/`・検証用キャラ3体・検証用スキルと状態・**戦闘ログ一式**・**検証用の敵7体と `enemies/` フォルダ**・**`"debug"` 列と `adventure_select` の3関数**・**`adventure_select._collect_party_candidates()` の `OS.is_debug_build()` 分岐**（⚠ 編成の行そのものは残す）・**`stage_dbg_condition`**）
17. ⚠ **DoT の周期ダメージでは購読が発火しない**（`StatusRegistry` が `SkillRuntime` を通らない）
18. ⚠ **`scale_from` の `of: "source"` が未実装**
19. ⚠ **購読は `host: unit` のみ**（コンボ・罠はまだ載らない）
20. ⚠ **足した7件目だけ JSON のインデントが1タブ深い**（3ファイル・見た目だけ）
21. **戦闘ログの完了条件15（落ちた戦闘）が未検証**
22. ⚠ **`adventure_select.gd:4` のヘッダコメントが実装と逆**（スタミナを減らすのは `battle_controller._consume_stage_stamina()`）
23. **購読から生まれた `cast` の `targets` が空配列**（対象が確定する前にログを出しているため）
24. **古いセーブに `stage_dbg` のクリア記録が残っている**（改名前のID。マスターに無いので実害なし）
25. ⚠ **`AGENTS.md` の「ツールの制約」に CRLF の話を足すかは人間の判断**
26. ⚠ **NEW：`stages.json` の `party_id` は戦闘のメンバーを決めない**（`BattleLog` の見出しだけ）。書き換えても何も起きない。将来「このステージは固定メンバー」をやるなら読む側を戻す
27. ⚠ **NEW：`CLAUDE.md` 4番の「リリース後にIDを改名できない」に `character_id` が加わった**（改名すると編成が黙って既定に戻る）
28. ⚠ **NEW：`status_add` の数え方。** 「切れてから付け直す」は `refresh` の貼り直しではなく**毎回が新しい件**。**同じ `status`+`unit`+`src` でまとめて数えてはいけない。** 引くのは「生きている間に上書きされた回数」だけ
29. ⚠ **NEW：条件が偽の間の DoT は発火が失われる**（時計は進む）。「止まる」ほうが自然な効果を作りたくなったら、`elapsed` を止める2本目の時計ではなく **`interval` の基準を別に持つ形**で設計し直す
30. ⚠ **NEW：`point` の条件（オーラ）は真偽が「状態 × ユニットの対」ごとになる。** 記憶の持ち方もログの持ち方も、今の `active`（状態1件につき1つ）では足りない
31. **NEW：所持キャラの概念が無い。** 編成の候補に全キャラが出る
32. **NEW：`party_changed` シグナルを足していない**（購読者が冒険選択の1画面だけのため）。**パーティ選択画面を作るときに足す**（そのとき `AGENTS.md` のシグナル表にも1行）
33. **NEW：Ziva が作った `.bak` が7件残っている**（`localization/` と `resources/balance/master/` 配下）。**消すのは人間の判断**

---

## 7. 終わったあと

**このファイルを、次のタスク（③＝介入点3種＋復活）の内容に書き換える。**
