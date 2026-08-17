# EXEC — **ダメージ数値を種類で色分けする**

頭上に浮かぶ数字の色が「会心か否か」の2択しかなく、**毒（DoT）でダメージを受けているのか画面で分からない。**
種類（通常 ／ 会心 ／ **DoT** ／ **回復**）で色を分ける。

⚠ **「量に応じて」ではなく「種類で」分ける。** 毒 `2` と通常 `4` は量がほぼ同じなので、量で分けても今回の困りごとは解決しない。
⚠ **量による色分けは段階4（バランスの実測）でやる。この回ではやらない。**

⚠ **この回の本体は色ではなく「表示側に種類が流れていない」こと。** 色定数を足すだけでは DoT を判別できない。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **分ける種類** | **通常 ／ 会心 ／ DoT ／ 回復 の4種。** ⚠ 「味方が受けた／敵が受けた」「物理／魔法」は**やらない**（色の種類が倍になり、DoT との組み合わせで意味が読めなくなる） |
| **色の置き場所** | ⚠ **`Balance.adventure`（`AdventureConfig`）の `@export`。Inspector から触れる形にする**（**2026-08-17・実機検証のあとに変更**。§0-2）。当初は `unit_view.gd` の定数で実装した |
| **大きさ** | **DoT を少し小さく、回復は通常と同じ大きさ。** |

### 0-1. ⚠ `AGENTS.md` の「個別シーンで色を直接指定しない」との食い違い

`AGENTS.md`「Themeの扱い」は **「個別シーンで色やフォントを直接指定しない。`theme/main_theme.tres` に一元化」** と書いている。
この回は**それに従わない。** 理由：

1. あの条文の対象は「配色・フォント・**ボタン等の基本スタイル**」＝ Control の見た目であり、狙いは「Theme 1箇所を差し替えれば**全画面**に反映される」こと。ダメージポップの色は全画面に波及するUI装飾ではなく、**「毒＝この色」という意味の対応表**
2. 描くのは `unit_view.gd` **1ファイルだけ**なので、「1箇所を直せば全部変わる」は既に満たされている
3. **同じファイルに前例がある。** `unit_view.gd:8-10` の `COLOR_PARTY` / `COLOR_ENEMY` / `COLOR_BOSS` は「EXEC §5：本タスク限定の例外」として明記済み
4. 動的生成した `Label` に `add_theme_color_override` している以上、Theme 経由にするなら**カスタム型（`theme_type_variation`）を人間が Theme エディタで作る作業**が発生する。得るものに対して手数が重い
5. `Balance` の `.tres` に出すと、設計役は Godot を起動できないので**色を1つ試すたびに人間の Inspector 往復が要る**

**代償**：文面上の食い違いは残る。→ **§8 の宿題に1行足す**（段階4で `Balance` に出すか判断する）。

### 0-2. ⚠ 上の決定を、実機検証のあとに人間が覆した（2026-08-17）

**「あとで `.tres` から変更できるようにしておきたい（Godot 側から触りたい）」**という判断により、
**頭上に浮かぶ数値の色と大きさは `AdventureConfig` の `@export` に出した。**
⚠ **上の 0-1 の1〜3の理由より、「Inspector で色を試せること」を優先する。**

| | 置き場所 |
|---|---|
| **数値ポップの色・大きさ・動き（12欄）** | ⚠ **`Balance.adventure`**（`resources/balance/adventure_config.gd`） |
| 体の色（`COLOR_PARTY` / `COLOR_ENEMY` / `COLOR_BOSS`） | `unit_view.gd` の定数のまま（**この回では触らない**） |
| ジャストの色・大きさ | ⚠ **一緒に `AdventureConfig` へ出した。** 同じ `pop_label()` を通る仲間を半分だけ残すと、次に触る人が「どっちを直せばいいか」で迷う |

**新しい Config は作らない。** `AdventureConfig` は既に `Balance` に配線済み（`balance.tscn` の `adventure = ExtResource(...)`）で、
`adventure_config.gd:22-29` に書かれている「割り当てを1つ落とすと戦闘が起動しない」事故が起きない。

⚠ **`.tres` を作り直す作業は発生しない。** `.tres` は `@export` の既定値を書き出さないため、
`adventure_config.tres`（現在ほぼ空）はそのままで、Inspector に既定値付きで12欄が出る。

⚠ **`unit_view.gd` に `const` を残していない。** 2箇所に数値があると
「Inspector で直したのに変わらない」が起き、どちらが効いているか実機でしか分からなくなる。
⚠ **`Balance.adventure` が null のときのフォールバックも書いていない**（`battle_formula.gd` と同じ素読み）。

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-17**）

| | 状態 |
|---|---|
| 数字を浮かべる場所 | `unit_view.gd` の `pop_label(text, color, font_size)` の1本。`pop_damage()` / `pop_just()` がそれを呼ぶ |
| 色の2択 | `unit_view.gd:71-75`。`is_crit` で `CRIT_COLOR`(32px) か `DAMAGE_COLOR`(22px) |
| 表示の入口 | `battle_controller.gd:853` `_on_skill_effects_applied()`。⚠ `StatusRegistry.effects_applied` と `SkillRuntime.effects_applied` の**両方がここ1本に繋がっている**（`battle_controller.gd:115-119`） |
| results の形 | `{ unit_id, amount, is_heal, is_crit }` ＋ ダメージのときだけ `{ source_unit_id, attack_type }`（`skill_resolver.gd:19-23`） |
| ⚠ **DoT の欄が無い** | `BattleLog` は `log_results(fired, src, dot_status_id)` の**引数**で外から区別している（`battle_log.gd:159`）。results 自体は DoT かどうかを持っていない |
| `resolve()` の呼び出し元 | **2箇所だけ**。`skill_runtime.gd:405`（通常）／ `status_registry.gd:629`（DoT） |
| `_pop_damage` の呼び出し元 | **4箇所**。`battle_controller.gd` 555（通常）／ 1149・1162・1183（⚠ F3 パネルの `J`/`M`＝デバッグ用の自傷。宿題16でリリース前に消す） |

### 1-1. ⚠ ドキュメントの誤りを1件見つけた（**直していない・報告のみ**）

**`NEXT_STEPS.md` §2-4「回復の数字は別経路」は誤り。**

- 引用元の `battle_controller.gd:919` は `_pop_just`（ジャスト成功）の注記であり、回復のことは書いていない
- 実際は `_on_skill_effects_applied()` が **`is_heal` を読まずに全 results を `_pop_damage()` に流している**（`battle_controller.gd:853-858`）
- つまり **回復量は今、ダメージと同じ黄色（`DAMAGE_COLOR`）で出ている**。`skill_resolver.gd:386` が `is_heal: true` を返しているのに、**誰も読んでいない**

→ **「回復を分ける」は追加仕様ではなく、既存の取りこぼしの修正**である。この回に含める（§0 の決定どおり）。

---

## 2. ⚠ 事故りやすい箇所

### 2-1. 既存4キーの名前も意味も変えない

`unit_id` / `amount` / `is_heal` / `is_crit` は `battle_controller` がそのまま読む（`skill_resolver.gd:19` の注記）。
**足すのは無害。変えるのが危険。**

### 2-2. 表示の経路を2本にしない

⚠ **DoT 専用の表示シグナルを足さないこと。** `StatusRegistry.effects_applied` と `SkillRuntime.effects_applied` は
**わざと同じ形にして `_on_skill_effects_applied` の1本に繋いである。** 経路が2本になると片方だけ直す事故になる。

### 2-3. 引数を増やすなら既定値を付ける

`_pop_damage` の呼び出し元は4箇所。既定値を付けないと3箇所が壊れる（`is_crit` が既にその形）。
`SkillResolver.resolve()` も同じ（呼び出し元2箇所）。

### 2-4. ラベルの親を変えない

`unit_view.gd:84` の注記のとおり、ラベルは**自分の子ではなく親コンテナに乗せている**。
とどめの一撃で `hide()` された瞬間に文字も消えるのを避けるため。**触らない。**

### 2-5. `ja.csv` に行を足さない

数値のみの表示は `tr()` を通さない（`AGENTS.md`）。**この回で `ja.csv` は1行も変えない。**

---

## 3. 実装（ファイル別）— **全部 設計役が書く**

⚠ **Ziva に出す分は無い。** 触るのは `.gd` 4ファイルだけで、JSON も `ja.csv` も `.tres` も変更しない。

⚠ **関数を足す前に `grep -n "func <名前>"`、足したあとにも `grep -n` で当たったか確認する**（`CLAUDE.md` 2番）。

### 3-1. `scripts/systems/skill_resolver.gd` — 戻り値に1欄足す

- `resolve()` に **第6引数 `is_dot: bool = false`** を足す（既定値必須）
- `_apply_damage()` にそのまま渡し、結果に **`"is_dot": is_dot`** を足す
- `_apply_heal()` の結果にも **`"is_dot": false`** を足す（**形を揃える**。読む側が `has()` を書かなくて済む）
- ファイル冒頭（19-23行）の「効果の結果の形」のコメントを**5キーに更新する**

⚠ **`is_dot` を書くのはここ1箇所だけ。** `StatusRegistry` 側で `fired` を後から書き換える形にしない（形を作る場所が2つになる）。

### 3-2. `scripts/systems/status_registry.gd` — DoT の発火に `true` を渡す

`_fire_intervals()`（629行）の `SkillResolver.resolve(one, source, _session, [host_id], self)` に **`, true`** を足す1行だけ。

⚠ `skill_runtime.gd:405` は**触らない**（既定値 `false` で正しい）。

### 3-3. `resources/balance/adventure_config.gd` — 色と大きさを Inspector に出す（§0-2）

末尾に `@export` を12欄足す。**新しい `.gd` も `.tres` も作らない。**

| 欄 | 既定値 |
|---|---|
| `pop_damage_color` / `pop_damage_font_size` | `Color(1.0, 0.85, 0.3)` / `22` |
| `pop_crit_color` / `pop_crit_font_size` | `Color(1.0, 0.55, 0.25)` / `32` |
| **`pop_dot_color`** / **`pop_dot_font_size`** | **`Color(0.75, 0.45, 0.95)`（紫）/ `18`** |
| **`pop_heal_color`** / **`pop_heal_font_size`** | **`Color(0.4, 0.95, 0.5)`（緑）/ `22`** |
| `pop_just_color` / `pop_just_font_size` | `Color(1.0, 0.95, 0.55)` / `30` |
| `pop_rise_px` / `pop_duration_sec` | `48.0` / `0.6` |

⚠ **既定値は移す前の `unit_view.gd` の定数と同じ値にする。** 移設と値変更を同時にやらない
（画面が変わったときに、移設のせいか値のせいか分からなくなる）。

### 3-4. `scenes/adventure/unit_view.gd` — 定数を捨てて Balance から引く、回復の口

- ⚠ **`DAMAGE_COLOR` / `CRIT_COLOR` / `JUST_COLOR` と3つの `*_FONT_SIZE`、`DAMAGE_RISE_PX` / `DAMAGE_DURATION_SEC` を消す**（§0-2）。`COLOR_PARTY` / `COLOR_ENEMY` / `COLOR_BOSS` は残す
- `pop_damage(amount, is_crit = false, **is_dot = false**)` に**第3引数を足す**（既定値必須）
  - 優先順：**`is_dot` → `is_crit` → 通常**。⚠ DoT は会心しない想定だが、両方立ったら **DoT を優先**する（種類のほうが情報として上）
- **`pop_heal(amount)` を新設**する。`pop_label()` に `Balance.adventure.pop_heal_*` を渡す1行
- `pop_label()` の tween も `Balance.adventure.pop_rise_px` / `pop_duration_sec` から引く

### 3-5. `scenes/adventure/battle_controller.gd` — results を読み分ける

- `_pop_damage(target, amount, is_crit = false, **is_dot = false**)` に第4引数を足す（既定値必須。**555 / 1149 / 1162 / 1183 は無変更**）
- **`_pop_heal(target, amount)` を新設**する（`_pop_damage` と同じ形。`view.has_method("pop_heal")` で守る）
- `_on_skill_effects_applied()` を**分岐させる**：

```gdscript
if bool(r.get("is_heal", false)):
    _pop_heal(target, int(r.get("amount", 0)))
else:
    _pop_damage(target, int(r.get("amount", 0)), bool(r.get("is_crit", false)), bool(r.get("is_dot", false)))
```

⚠ **`is_heal` を先に見る。** 将来 HoT（継続回復）が来たら `is_heal` と `is_dot` が両方立つが、**回復として出すのが正しい。**

---

## 4. 変えないもの

- `ja.csv`（1行も足さない）／ `.tres` ／ `main_theme.tres` ／ JSON 一式
- `pop_label()` の中身とラベルの親（§2-4）
- `pop_just()` と `JUST_COLOR` / `JUST_FONT_SIZE`
- `BattleLog.log_results()` の引数（`dot_status_id` はログ側の区別として残す。**`is_dot` と役割が重なるが、統合しない**——ログは `status_id` そのものが要る）
- `battle_controller.gd` の 555 / 1149 / 1162 / 1183

---

## 5. 完了条件 — **ログ**（Godot の出力パネル）

1. 戦闘を開始したとき、**赤いエラー（parse error / Invalid call）が1つも出ないこと。** 特に `resolve()` と `pop_damage()` の引数の数
2. 起動時の検証が**前回と同じであること**：`skills validated: 47 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 16 entries, 0 errors, 0 warnings`
   ⚠ **黄1本（`skill_dbg_dot_odd` の端数）は出るのが正解。**
3. ⚠ `[SkillResolver] resolve() に効果が N 件来た` の警告が**新たに出ないこと**（引数を足した際の渡し間違いの検出）

---

## 6. 完了条件 — **ファイル**（`user://logs/battle_last.jsonl`）

⚠ **戦闘のたびに上書きされる。読む前に別の戦闘を始めないこと。**
⚠ **色は `battle_last.jsonl` では判定できない。ここに書くのは「今回の変更でログが壊れていないこと」だけ。**

4. `stage_dbg_condition` を1回戦って終わらせたあと、`dot` 行が**従来どおり出ていること**（`status` 欄にステータスIDが入っている）
5. `damage` 行と `heal` 行が**従来どおり出ていること**。⚠ **行の形が変わっていないこと**（`is_dot` はログには出さない）

---

## 7. 完了条件 — **画面**（実機で操作する。⚠ **この回はここが本体**）

**準備**：冒険選択 →「編成」で**検証用3体**を選ぶ → `stage_dbg_condition` に入る。

6. **1波（`enemy_dbg_cond`）で、通常攻撃のダメージが従来どおり黄色（`DAMAGE_COLOR`）で出ること。** 大きさも従来どおり
7. **会心が出たとき、従来どおり橙色で大きく跳ねること**（`CRIT_COLOR` / 32px）。⚠ 会心は確率なので、出るまで数回見る
8. **2波（`enemy_dbg_dot` が居る）で、毒のダメージが紫色で出ること。** ⚠ **通常攻撃の黄色と同じ画面に並んだとき、一目で別物と分かること**
9. **毒の数字が、通常のダメージより少し小さいこと**（18px 対 22px）
10. **僧侶の回復が緑色で出ること。** ⚠ **今まで黄色で出ていた**（§1-1）。**ここが変わったことを確認する**
11. **回復の数字の大きさが、通常のダメージと同じであること**
12. **とどめの一撃の数字が、対象が消えたあとも最後まで読めること**（§2-4 の親の話が壊れていないこと）
13. **F3 →「4」で速度8倍にしても、毒の数字が色を保ったまま複数回浮かぶこと**（`_fire_intervals()` の while が回る経路）
14. **F3 → `J` / `M`（自傷）の数字が、従来どおり黄色で出ること**（既定値が効いていることの確認。⚠ 紫になっていたら第4引数の渡し間違い）
15. **チャージのジャスト成功の文字が、従来どおり淡い黄色で出ること**（`pop_just` に手を入れていないことの確認）

16. **Inspector で `adventure_config.tres` を開くと、`pop_` で始まる欄が12個見えること**（§0-2）。⚠ 既定値が入っている状態で見えるのが正解。**空欄や黒（`Color(0,0,0,0)`）になっていたら `@export` の書き方を疑う**
17. **`pop_dot_color` を Inspector で別の色に変えて保存し、戦闘に入ると毒の数字がその色で出ること。** ⚠ **これがこの回の追加分の本体**（`unit_view.gd` を触らずに色を変えられること）
18. **`pop_damage_font_size` を大きくすると、通常のダメージだけが大きくなること**（DoT と回復は変わらない）

### 7-1. ⚠ 色そのものの良し悪しは人間が決める

紫（DoT）と緑（回復）は設計役が置いた**たたき台**。
⚠ **紫は `COLOR_BOSS`（`Color(0.6, 0.3, 0.8)`）と系統が近い。** ボスの体色と毒の数字が同じ画面に出たときに紛らわしければ、
**Inspector で `pop_dot_color` を変えるだけでよい**（§0-2 以降、コードを触る必要は無い）。

⚠ **`COLOR_BOSS` のほうは `unit_view.gd` の定数のまま**なので、そちらを変えたい場合はコードになる。

---

## 8. 終わったあとに足す宿題（`PROJECT_STATUS.md`）

⚠ **書き換えるかは人間の判断。** 設計役は勝手に触らない。

- **NEW：戦闘の数値ポップの色は `Balance.adventure`（`AdventureConfig`）で持っている**（§0-2）。`main_theme.tres` ではない。⚠ **`AGENTS.md`「個別シーンで色を直接指定しない」の対象外という整理**であり、`AGENTS.md` 側に1行足すかは人間の判断
- **NEW：`unit_view.gd` の `COLOR_PARTY` / `COLOR_ENEMY` / `COLOR_BOSS`（体の色）だけ定数のまま残っている。** 色の置き場所が2箇所ある状態。**Inspector から体の色も触りたくなったら `AdventureConfig` に移す**
- **NEW：`NEXT_STEPS.md` §2-4「回復の数字は別経路」は誤りだった**（§1-1）。回復も `_on_skill_effects_applied` → `_pop_damage` を通っており、**この回まで黄色で出ていた**
- **NEW：`BattleLog` の `dot_status_id`（引数）と results の `is_dot`（欄）が二重になった。** ログは `status_id` そのものが要るため統合していない。**片方だけ直す事故に注意**
