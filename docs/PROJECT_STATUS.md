# プロジェクト進捗状況 / 引き継ぎガイド

**新しい会話を始めるときは、まずこのファイルを見せること。**

**ただしゲームの中身は`GAME_DESIGN.md`が第1層の正。** このファイルが持つのは**実装の進捗・体制・過去の事故**であり、「何を作るか」ではない。**両方が食い違ったら`GAME_DESIGN.md`が正。**

---

## このゲームは何か

ポモドーロ（作業時間管理）をこなすと報酬がもらえる、拠点育成×簡易戦闘のハイブリッドゲーム。詳細は`CONCEPT.md`。

**設計原則（迷ったときの判断基準）**
- 「ポモドーロをやったらご褒美」という約束を裏切らない
- プレイヤーに「やって後悔した」と思わせない
- 頑張る楽しさを、素直に嬉しい手応えとして返す

---

## 現在地

**コアループが閉じた。** 働いて、報酬を得て、それを使って遊ぶところまで一周する。

```
ポモドーロで作業する
  → 加護のしきい値で宝箱、作業25分でスタミナポーション
  → 拠点に戻ると受け取り、モーダルで報告される
  → ポーションを飲んでスタミナを増やす
  → 冒険選択画面でステージに挑む（スタミナを消費）
  → 戦闘で素材とゴールドを得る
  → また次のポモドーロへ
```

**素材の使い道が2つ開いた。** 育成（レベルアップ）と研究（レベル上限の解放）が入り、2種類の素材にそれぞれ別の出口ができた。

```
戦闘で training_material と construction_material を得る
  → 育成で training_material を使ってレベルを上げる
  → 研究で construction_material を使って上限を解放する
  → さらにレベルを上げられる → もっと先のステージに挑める
```

**素材ごとに蛇口と出口が1対1で対応している。** どちらが足りていないかがプレイヤーに分かる形になった。

**ゴールドの出口も開いた。** ショップ（日替わり・固定ラインナップ）が入り、ゴールドで素材とスタミナポーションを買えるようになった。

```
戦闘で gold を得る
  → ショップで training_material / construction_material を買う
  → 育成・研究で使う（既に出口が繋がっている）
```

**在庫は毎朝4:00に戻る**（`GameDate`基準。ポモドーロ・ストリークと同じ区切り）。

**時間の出口も開いた。** 作業場（レシピ4つ・キュー1本）が入り、素材と待ち時間を払って別の素材を受け取れるようになった。

```
戦闘で素材を得る
  → 作業場に入れて待つ（30分・3時間）
  → 別の素材になって返ってくる（レートは1未満）
```

**ショップ（ゴールド・即時）と作業場（素材＋時間）が並んだ。** 「今すぐ買うか、待って交換するか」の選択が生まれている。

**装備が入り、輪が閉じた。** 作業場で武器を作り、装備し、戦闘のダメージが増えるところまで一周する。

```
作業場で建築素材20を30分かけて武器にする
  → 装備画面で剣士に装備する
  → get_effective_stats() がレベル＋研究＋装備を合成する
  → 戦闘のダメージが増える
```

**装備の第2弾で、装備が「個体」になった。** 5部位・`equipment_instances`・鍛冶が入り、同じ武器を2本持って2人に別々に着けられる。

```
ショップ／作業場／宝箱で装備を手に入れる
  → add_to_inventory() が eq_N として個体を1つ作る
  → 5部位（頭/上半身/下半身/武器/アクセサリー）のどれかに装備する
  → 鍛冶で等級を上げる（素材だけ・待ち時間なし・失敗しない）
  → 育成画面と戦闘のダメージが増える
```

**「渡す物が無い」で止まっていた3つ（ショップ・作業場・宝箱）が全部解消した。** 宝箱からも装備が出る。

**ステータス10軸が入り、戦闘の式が置き換わった（2026-08-15）。** 前半（器）と後半（式）の2回に分けて完了。

```
装備・研究・レベルで10軸が動く
  → get_effective_stats() が10軸を合成する
  → BattleUnit.create() が10軸を辞書のまま受け取る
  → BattleFormula が除算・物理/魔法・会心・攻撃間隔・CDを計算する
```

- **ダメージは除算**（`damage × 100 / (100 + def)`）。減算ではなくなった
- **物理と魔法がある**（`attack_type`）。`mdef`が生きている
- `atkspd`（攻撃間隔）・`haste`（CD短縮）・`crit_rate`／`crit_dmg`（会心）が効く
- 回復は`mag`参照（以前は`atk`参照だった）

**レベルの役割転換が2/3まで進んだ**（2026-08-15）。**割り振りポイント**（`character_nodes.json` 180件・`stat_node_screen`）と**スキル選択**（2枠・`skill_select_screen`）が入り、**残りはパッシブだけ**。

**レベルはもうステータスを伸ばさない**（`stat_growth_formula`が`"base"`）。伸ばすのは割り振り・研究・装備の3つ。

**次はパッシブ**。詳細は`NEXT_STEPS.md`。**その前に`skill_resolver.gd`のテンプレ決めが要る**（下記）。

**バランス調整は着手可能になった**（`PLAN_IMPLEMENTATION.md` 3章の12番）。`def`が除算になったため、敵HP・スキル倍率は全部意味が変わっている。**まだ一度も実測していない。**

| 層 | 状態 |
|---|---|
| 第1層：戦略計画 | ✅ 完了 |
| 第2層：作戦計画 | 🟡 一部完了（パーティ選択・トレーニング・設定・シナリオが未作成） |
| 第3層：実行指示書 | 🟡 進行中（下記） |

### 実装済み（第3層）

| タスク | EXEC | 状態 |
|---|---|---|
| 共通基盤（5つのAutoload） | `EXEC_COMMON_INFRA.md` | ✅ 完了（14項目） |
| UI共通パーツ（Theme・コンポーネント3つ） | `EXEC_UI_COMMON.md` | ✅ 完了（13項目） |
| タイトル→拠点（遷移とセーブ） | `EXEC_TITLE_TO_BASE.md` | ✅ 完了（14項目） |
| 拠点画面（下部） | `EXEC_BASE_SCREEN.md` | ✅ 完了（20項目） |
| ポモドーロ最小ループ | `EXEC_POMODORO_CORE_LOOP.md` | ✅ 完了（28項目） |
| スタミナポーション | `EXEC_STAMINA_POTION.md` | ✅ 完了（16項目） |
| ギルド画面・倉庫 | `EXEC_GUILD_WAREHOUSE.md` | ✅ 完了（20項目） |
| 戦闘フェーズ1（骨格） | `EXEC_BATTLE_CORE.md` | ✅ 完了（19項目） |
| 戦闘フェーズ2（スキル・ボス） | `EXEC_BATTLE_SKILLS.md` | ✅ 完了（17項目） |
| 戦闘：チャージスキル・3列レイアウト | （EXECなし。設計役が直接コードを書いた） | ✅ 完了 |
| 冒険選択画面 | `EXEC_ADVENTURE_SELECT.md` | ✅ 完了（14項目） |
| 汎用モーダル（本体） | `EXEC_MODAL.md` | ✅ 完了（12項目・設計役が書き直し） |
| モーダルの適用（受け取り報告・確認） | （EXECなし。設計役が直接コードを書いた） | ✅ 完了 |
| ギルド：育成（レベルアップ） | `EXEC_GUILD_TRAINING.md` | ✅ 完了（A章13項目・B章12項目。**実装役に投げず設計役が`.gd`を全部書いた**） |
| ギルド：研究（レベル上限の解放） | `EXEC_GUILD_RESEARCH.md` | ✅ 完了（画面15項目・ログ／同期の確認。**実装役を使わず設計役が`.gd`・`.tscn`・`.json`を全部書いた**） |
| ギルド：ショップ（日替わり・固定） | `EXEC_GUILD_SHOP.md` | ✅ 完了（画面15項目・ログ2項目・ファイル7項目。**実装役を使わず設計役が全部書いた。3回連続で事故ゼロ**） |
| ギルド：作業場（時間投資型の製作） | `EXEC_GUILD_WORKSHOP.md` | ✅ 完了（画面12項目・ログ7項目・ファイル6項目。**全項目一発で通った。4回連続で事故ゼロ**） |
| ギルド：装備（武器スロット・戦闘への反映） | `EXEC_GUILD_EQUIPMENT.md` | ✅ 完了（画面18項目・ログ8項目・ファイル6項目。**5回連続で事故ゼロ**。EXECにコードを載せない形式に変更） |
| ギルド：装備の第2弾（5部位・個体管理・鍛冶・宝箱） | `EXEC_GUILD_EQUIPMENT_V2.md` | ✅ 完了（コード8項目・ログ8項目・ファイル8項目・画面13項目。**6回連続で事故ゼロ**。設計役が全文を書く最後のタスク） |
| 検証用のものの削除 | （EXECなし。旧`NEXT_STEPS.md`4章） | ✅ 完了（`debug_instant` / 0Gスロット9件 / `weapon_debug_blade`。**Claude Codeで実施した最初の作業**） |
| 音の第1弾（共通基盤＋ポモドーロのアラーム） | `EXEC_SOUND.md` | ✅ 完了（音6項目・ログ4項目・ファイル5項目。**PLANから通しで作った最初のタスク**。第2層`PLAN_SOUND.md`を新設） |
| ステータス10軸（**器だけ。式は次回**） | `EXEC_STATS_10_AXES.md` | ✅ 完了（画面10項目・ログ5項目・セーブ4項目。**10軸の器・セーブv2・研究の`boost_all`を実数軸に限定**。戦闘の式は入っていない。検証用のデバッグオーバーレイを追加） |
| ステータス10軸の後半（**式を戦闘に反映**） | `EXEC_STATS_10_AXES_FORMULA.md` | ✅ 完了（画面12項目・ログ4項目。**`BattleUnit`を作り直し（位置引数を全廃）、`battle_formula.gd`を新設して式を1箇所に集約**。除算式・物理/魔法・`atkspd`・`haste`・会心・回復の`mag`参照） |
| レベルの役割転換①：**割り振りポイント** | `EXEC_LEVEL_ROLE_SHIFT.md` | ✅ 完了（`character_nodes.json` 180件・`stat_node_screen`新規・`GameManager`にノード関数7本。**`stat_growth_formula`が`"base"`になり、レベルではステータスが伸びなくなった**。セーブ`v3`） |
| レベルの役割転換②：**スキル解放と選択**（スコープA′） | `EXEC_SKILL_SELECT.md` | ✅ 完了（ログ2項目・セーブ4項目・画面13項目。**`battle_controller.gd`のマスター直読みを`get_battle_skills()`へ付け替えたのが本題**。`skill_select_screen`新規・`growth.skills.slots`に2枠。**`save_version`は3のまま**） |
| スキルの器の付け替え（**段階1**） | `EXEC_SKILL_TEMPLATE_PHASE1.md` | ✅ 完了（2026-08-16。`type`廃止・4軸へ。新規`skill_schema.gd`／`skill_activation.gd`、`skill_resolver.gd`を作り直し。**挙動不変**） |
| **スキルの中身12個**（3人 × Lv5/10/15/20） | `EXEC_SKILL_CONTENT.md` | ✅ 完了（2026-08-16。**`.gd`を1行も触らないタスク**。`skills.json` 6→18件・`characters.json`の候補6件×3人・`ja.csv` 12行。**段階1の受け口が全部初めて実コードを通った**） |
| **実行中のスキル層と `trigger`（段階2）** | `EXEC_SKILL_TEMPLATE_PHASE2.md` | ✅ 完了（2026-08-16。**`skill_runtime.gd` 新設**＝待ち行列1本・発火経路1本・取り消し3種。`resolve()` が対象IDを外から受け取る形に。`delivery`（種別タグ）を新設。**速射が2連射になった＝多段と遅延が実際に動いた**） |
| **状態の器と `buff` / `dot`（段階3の前半）** | `EXEC_SKILL_TEMPLATE_PHASE3A.md` | ✅ 完了（2026-08-16。**`status_registry.gd` 新設**。`stack` / `until` を新設、`BattleUnit.get_stat()` が補正込みに、`resolve()` の引数が5つに。⚠ **実装した回はロード時検証しか通っておらず、挙動は次の回で初めて確認した**） |
| **1キャラ＝1フォルダ**（skills / nodes） | （EXECなし。人間の決定） | ✅ 完了（2026-08-16。`character_nodes.json` 1784行と `skills_debug.json` を解体して6フォルダへ。**分割前後でデータ完全一致**） |
| **通常攻撃のデータ化**（スキルと同じ経路へ） | （EXECなし。人間の決定） | ✅ 完了（2026-08-16。`basic_attack` 9件・`_compute_damage()` 廃止。**挙動不変**） |
| **通常攻撃の個性付け**（範囲攻撃の解禁） | （EXECなし。人間の決定） | ✅ 完了（2026-08-16。`basic_attack` に `target` を省略可で解禁。⚠ **DPSの序列が変わった**） |
| **投射物**（着弾でダメージ・無効化の受け口） | （EXECなし。PLAN 6-7 / 6-8） | ✅ 完了（2026-08-16。`projectile_view.gd` 新設。**受け口3つの呼び出し元ゼロを埋めた**。⚠ **挙動が変わった**） |
| **状態の検証手段**（コンソール出力 ＋ テストシーン） | （EXECなし。旧`NEXT_STEPS.md`） | ✅ 完了（2026-08-16。F3 パネルに `P` キー＝`snapshot()` を1回だけ `print`・素の値→実効値も出す。**`tests/battle/` を新設**して `test_status_registry` 13項目。**NG 0件**） |
| **skills の複数ファイル化 ＋ 検証用キャラ3体** | `EXEC_SKILL_MULTIFILE.md` | ✅ 完了（2026-08-16。`skills.json`（18件）をキャラ別3ファイルへ分割し、`skills_debug.json`（18件）と検証用キャラ3体を新設。`MasterDataLoader` が複数ファイルをマージし**重複IDを赤で弾く**。**ログ・ファイル・画面の全項目が通った**。⚠ **設計役が全部書いた**（実装役に渡す予定を人間の判断で変更）） |

### 戦闘画面でできること

- 味方3人（剣士・弓兵・僧侶）のオートバトル。接近・通常攻撃・ターゲット自動選択
- 5ウェーブ連戦。ウェーブ間はHPとスキルのクールダウンを引き継ぎ、位置だけ左端に戻る
- **スキルは18候補**（キャラごとに6つ。Lv1×2 ＋ Lv5/10/15/20 で1つずつ解放）。**そこから2つ選んで持ち込み、手動発動**。クールダウン制
  - 単体／全体／HPの高い敵・低い敵・遠い敵を狙う・2体同時・単体回復・吸血・自傷・確定ダメージ・距離やHPや`def`/`mdef`でのスケールが入っている
- **多段と遅延**（段階2）。弓兵の速射が**2体 × 2連射**（0.35秒あと）。⚠ **対象は撃った瞬間に確定するので、1発目で敵が死んでも2発目は同じ敵に出る**
- **チャージスキル**（剣士の横薙ぎ）。押している間ためて離すと発動。1.0秒でジャスト（±0.15秒）
- 最終ウェーブのボス（紫・1.5倍サイズ・`stat_overrides`）
- 勝敗判定、報酬反映、ステージクリア記録、リトライ
- ダメージ数値のポップアップ、チャージゲージ、ジャスト演出
- **10軸の式**（除算の防御・物理/魔法・`atkspd`・`haste`・会心）。会心は数字が大きく色が変わる
- **デバッグパネル**（`OS.is_debug_build()`時のみ。**F3で表示・画面の右上**）。1ユニット2行で10軸と実測ダメージを出す。`J`＝味方全員に物理の一撃／`M`＝魔法の一撃（**どちらも`BattleFormula`を通すので`def`と`mdef`の差が見える**）

### 汎用モーダルの使い方

`scripts/systems/modal.gd`（静的クラス。Autoloadではない）。

```gdscript
Modal.notify(self, "ui_base_save_completed")
Modal.notify(self, "ui_base_chest_received", [3])
var ok: bool = await Modal.confirm(self, "ui_title_back_confirm")
```

- 生の日本語を渡さない。翻訳キーのみ
- 閉じるまで残る。自動では消えない
- 同時に呼ばれたらキューに積まれ、順に出る
- 画面遷移で消える（**これは仕様**。前の画面の通知が次の画面に出ないため）
- `pause: true` を渡すとゲームを止める。戦闘中に使う場合のみ

### 未着手（第2層あり・EXECを書けば進める）

**キャラ強化ループの残り**（`PLAN_CHARACTER_GROWTH_LOOP.md`）。5部位・鍛冶は入った。**残っているのは宝石・ルーン（`parts`に刺さるもの）と、等級4〜10。** **決定事項の台帳であり、実装手順書ではない。** チェックが付いていない項目を先に決めること。

~~**ステータス10軸**（`PLAN_STATS_AND_FORMULAS.md`）~~ **✅ 完了（前半・後半とも）。**

⚠ **`PLAN_STATS_AND_FORMULAS.md`は実装とズレたまま。** 1章「`_stat_keys()`に足せば全部追従する」（追従するのは合成側だけ）／5章「ダメージ確定の直前」が1箇所前提（実際は2箇所あり、`battle_formula.gd`に集約した）／研究の`boost_all`の話が丸ごと無い。**このPLANを次に使うときは先に直すこと。**

**PLANは実コードを見ずに書かれている前提で扱う。** 育成・研究・ショップ・作業場・装備の**5回とも**、PLANの「対応済み」が事実と違っていた。EXECを書く前に必ず`grep`で突き合わせること。

### 未着手（第2層ごと無い・PLANから書く必要あり）

パーティ選択画面、トレーニングモード、設定画面、シナリオ画面、ポモドーロの記録画面／タイマー装飾／ストリーク、トースト（自動で消える通知）。

---

## 実装の体制

詳細な手順は`WORKFLOW.md`。実装役に渡すプロンプトの全文は`docs/PROMPT_IMPL.md`（**人間が使う運用メモ。実装役には読ませない**）。

| 誰 | 役割 |
|---|---|
| **あなた** | 判断・実機検証・`.tres`と定数ファイルの編集・コミット |
| **設計役**（Claude） | PLANとEXECを書く。**壊れやすいコードは自分で書いて渡す** |
| **レビュー役**（DeepSeek） | PRE_PLANとIMPL_LOGをレビューする |
| **実装役**（MiniMax / Ziva） | PRE_PLANを書き、実装する |

### 実装役に任せてよい範囲（実測で確定）

| 種類 | 任せてよいか |
|---|---|
| 新規ファイルの作成 | ✅ 安定している |
| JSONの作成 | ✅ 安定している |
| 既存ファイルの末尾への追記 | ✅ 安定している |
| **200行を超える既存ファイルの途中の書き換え** | ❌ 設計役が全文を書く |
| **画面を見る検証**（表示・クリック・遷移） | ❌ 人間が行う |
| `print`で結果が出る検証（戻り値・計算・状態） | ✅ 任せてよい |

**実装役の性質**：技術的な発見は鋭い（`tr()`が静的関数から呼べないこと、`mouse_filter = 3`が不正値であることなどを自力で突き止めた）。逆に**諦めない性質があり、できない課題を渡すと止まらない。** 能力ではなく、渡す仕事の切り分けの問題。

### 設計役が直接コードを書く範囲

- **200行を超える既存ファイルの変更**（`battle_controller.gd` / `base_screen.gd` など）
- **小さくて境界条件が多いもの**（`game_date.gd`の4時基準の日付判定）
- **状態機械やタイマーの整理**（`pomodoro.gd`のタイマーが3箇所から書き換えられていた件）

### 使うモデル

| モデル | 特徴 | 判定 |
|---|---|---|
| **MiniMax** | 迷った点を隠さず書く。実機で検証し、できなかった部分は正直に申告する | **採用** |
| Gemini | 難しい問題は解けるが、動かしていない項目に「検証済み」と書く | 不採用 |
| GPT Luna | 未検証を正直に空欄で返すが、実機検証を丸ごと省く | 保留 |

**設計役は現状Claudeのみ検証済み。** DeepSeekはPLANを書かせると既存の決定を確認せず矛盾した提案をする。

### 実測コスト

| タスク | 計画 | 実装 | 備考 |
|---|---|---|---|
| 拠点画面 | $0.13 | $0.38 | 差し戻し1回 |
| ポモドーロ最小ループ | $0.17 | $1.28 | 差し戻し2回・ループ発生 |
| スタミナポーション | $0.22 | $0.34 | — |
| ギルド・倉庫 | $0.22 | $0.80 | 差し戻しなし |
| 戦闘フェーズ1 | $0.28 | $1.10 | 検証7項目が未実施で返却 |
| 戦闘フェーズ2 | $0.30 | $1.60 | 実装が破綻。設計役が書き直した |
| 冒険選択画面 | $0.20 | $0.70 | 全項目未検証で返却（人間が実機で確認） |
| 汎用モーダル | $0.06 | $0.66 | 検証で破綻。設計役が書き直した |

**破綻した2回はどちらも「できない検証」を渡したことが引き金。** コストの問題は渡し方にある。

---

## AIに触らせないもの・ツール制約

**`AGENTS.md`に集約した。** ここには複製しない（片方だけ直して食い違うため）。

---

## Git

タスクが1つ完了して動作確認できたらコミットする。

- 壊れたら`git checkout HEAD -- <path>`で戻す
- **AIの作業後は必ず`git status`を見る。** 指示書に無いファイルが増えていないかがここで分かる。実際、`battle_controller_replacement.gd`という迷子のファイルをこれで発見した
- コミットしていない状態でAIに大きな作業をさせない

### コミットメッセージはAIが指示する（2026-08-15に追加）

**タスクが1つ終わったら、AIがコミットメッセージを1行提示する。あなたはそのままコミットする。**

- 形式：`feat(equipment): 武器スロット・装備の着脱・戦闘への反映`（日本語・`CLAUDE.md`の型）
- **AIは提示したメッセージを、この章の下の表に自分で追記する。** セッションをまたぐと会話が消えるため、
  「どのコミットが何のタスクだったか」を後から引けるのはここだけになる
- `git log --oneline`と突き合わせれば、**ドキュメントの「実装済み」と実際に入ったものの
  ズレ**（このプロジェクトで7回起きている）を、コード全文を読まずに検出できる

| コミット | タスク | EXEC |
|---|---|---|
| `51c09f6` | `feat(battle): 通常攻撃にキャラごとの個性を入れ、範囲攻撃を書けるようにする`（4ファイル。`basic_attack` に `target` を省略可で解禁。剣士＝重い一撃／弓兵＝最高DPS／僧侶＝範囲／狼＝速め／ボス＝重い単体） | （EXECなし。人間の決定） |
| `3fb91b9` | `feat(battle): 投射物を実際に飛ばす（着弾でダメージ・無効化の受け口を配線）`（9ファイル。新規は `projectile_view.gd`。`cast()` に `fixed_target_ids`、通常攻撃も待ち行列へ、`event:hit` の黄を停止）＋ `9b202ff`（解放済み参照に `is` を当てて落ちるのを修正） | （EXECなし。PLAN 6-7 / 6-8） |
| `03a0d8e` | `feat(battle): 通常攻撃をデータ化し、スキルと同じ経路に載せる（挙動不変）`（6ファイル。`basic_attack` 9件・`_compute_damage()` 廃止・`validate_basic_attack()` 新設） | （EXECなし。人間の決定） |
| `5d2d64c` | `refactor(master): 1キャラ＝1フォルダへ移す（skills / nodes・データは完全一致）`（14ファイル。`character_nodes.json` 1784行と `skills_debug.json` を解体して6フォルダへ。マージを `_load_character_files()` の1本に統合）＋ `2707ca1`（ノードのログのタイミングをコメントに記録） | （EXECなし。人間の決定） |
| `30f0ab7` | `feat(skill): skills をキャラ別に分割し、検証用キャラ3体×18スキルを追加`（10ファイル。`skills.json` を削除して4ファイルへ。`MasterDataLoader` にマージと重複IDの赤。`training_screen.gd` の `CHARACTER_IDS` に3行）＋ `85a3ea8`（再インポート）| `EXEC_SKILL_MULTIFILE.md` |
| `754e86d` | `docs(skill): 複数ファイル化と検証用キャラ3体の EXEC を起こす`（**コードは触っていない**） | `EXEC_SKILL_MULTIFILE.md` |
| `6cf1859` | `docs(next): 次タスクを「複数ファイル化 ＋ 検証用キャラ」に差し替え`（**コードは触っていない**） | — |
| `9e7d825` | `test(skill): 状態の器の検証手段（F3パネルの P キー ＋ テストシーン13項目）`（`battle_debug_panel.gd` に `P` キー、`tests/battle/` を新設。**13項目 NG 0件で段階3前半が実機で確認済みになった**） | （EXECなし） |
| `db7b1e7` | `feat(skill): 状態の器と buff/dot（段階3前半・stack と until）`（12ファイル。新規は `status_registry.gd`。`stack` / `until` を新設、`BattleUnit.get_stat()` が補正込みに、`resolve()` の引数が5つに。⚠ **この時点では通過したのがロード時検証のみで、挙動は次のコミットで初めて確認した**） | `EXEC_SKILL_TEMPLATE_PHASE3A.md` |
| `9bb357b` | `feat(skill): 実行中のスキル層と trigger（段階2・多段と遅延）`（9ファイル。新規は `skill_runtime.gd`。`resolve()` の引数が変わり、`delivery` を新設。速射が2連射に） | `EXEC_SKILL_TEMPLATE_PHASE2.md` |
| `b58a434` | `feat(skill): 3人ぶんの残り12スキルを追加（Lv5/10/15/20 解放）`（8ファイル。⚠ **`.gd` を1行も触っていない**。`skills.json` 6→18件・`characters.json`・`ja.csv` ＋ `PLAN_SKILL_CONTENT.md` / `EXEC_SKILL_CONTENT.md` 新設 ＋ `PROJECT_STATUS.md` / `NEXT_STEPS.md` を更新） | `EXEC_SKILL_CONTENT.md` |
| `078428d` | `docs(skill): PLAN の scale_from を省略不可に統一（実装との食い違いを解消）`（**コードは触っていない**） | `PLAN_SKILL_TEMPLATE.md` 5-2・17章 |
| `1704ee3` | `docs(status): 段階1の完了を反映・Git章にハッシュを記録・次タスクを段階2に差し替え`（**コードは触っていない**） | — |
| `4e4bd11` | `feat(skill): スキルの器を4軸に付け替え（段階1・対象選択と発動可否と介入点の受け口）`（実装本体・10ファイル。新規は `skill_schema.gd` / `skill_activation.gd`） | `EXEC_SKILL_TEMPLATE_PHASE1.md` |
| `e093c20` | `docs(skill): 段階1の EXEC に人間の決定4件を反映（実装役を使わない体制へ）`（**コードは触っていない**。決定1-5〜1-8と §2 の担当表） | `EXEC_SKILL_TEMPLATE_PHASE1.md` §1 |
| `7dd97d3` | `docs(skill): 段階1の EXEC を起こす（器の付け替え・挙動不変が完了条件）`（**コードは触っていない**。`EXEC_SKILL_TEMPLATE_PHASE1.md` の新設と、この表への追記のみ） | `EXEC_SKILL_TEMPLATE_PHASE1.md` |
| `0c09c6c` | `docs(skill): スキルのテンプレートを4軸＋2層で確定・スケール変数表を新設・介入点を2段構えに訂正`（**コードは触っていない**。`PLAN_SKILL_TEMPLATE.md` を決定へ格上げ、`GAME_DESIGN.md` に 3-4 コンボを新設、`NEXT_STEPS.md` を段階1に差し替え） | **EXECはまだ無い**（次に書く） |
| `eef8a92` | `docs(skill): スキルのテンプレートを3軸＋イベント発火の形で確定・次タスクを段階1に差し替え`（**コードは触っていない**） | — |
| `a6a8efd` | `docs(skill): スキルのテンプレート案を PLAN に起こす（未確定・別途議論）` | — |
| `7d6e300` | `docs(skill): スキル選択の完了をドキュメントへ反映・次タスクをパッシブに差し替え`（**コードは触っていない**。`EXEC_SKILL_SELECT.md` §10 の宿題6点） | `EXEC_SKILL_SELECT.md` §10 |
| `c44cc79` | `feat(skill): スキル候補の解放と2枠の選択・戦闘への反映`（**上と同じメッセージだが中身は別**。枠と装備スロットの紐づけを撤回したドキュメント2ファイルのみ） | `EXEC_SKILL_SELECT.md` §12-6 |
| `7f2deec` | `feat(skill): スキル候補の解放と2枠の選択・戦闘への反映`（実装本体・12ファイル） | `EXEC_SKILL_SELECT.md` |
| `2efc0a2` | スキルツリー関連とステータスの伸び方（割り振りポイント） | `EXEC_LEVEL_ROLE_SHIFT.md` |
| `a426e20` | ステータス10軸の器・セーブv2・検証用デバッグオーバーレイ | `EXEC_STATS_10_AXES.md` |

> 古いコミットは遡って埋めない。**今後のぶんだけ足す。**

---

## 次の会話で「何を見せるか」

| やりたいこと | 見せるファイル |
|---|---|
| 新しい会話を始める | このファイル + `NEXT_STEPS.md` |
| PLAN（第2層）を作る | このファイル + `AGENTS.md` + `SCENES.md` + `DATA_SCHEMA.md`該当章 + 同規模の既存PLAN |
| 実行指示書を一緒に書く | `AGENTS.md` + 該当`PLAN_◯◯.md` + **依存する実コード** |
| 実装をAIにさせる | `docs/PROMPT_IMPL.md`【C】の型で投げる |
| 実装結果をレビューしたい | `IMPL_LOG_◯◯.md` |

### 第3層を書くたびに守るルール

PLANは「意図」の記録であり、実際のコードとはズレる。**新しいEXECを書く前に、依存する実コードを必ず見せること。** ズレがあればPLAN側を先に直す。

旧`PLAN_BATTLE_SCREEN.md`は実コードを見ずに書かれていたため、存在しない育成データを前提にしていた。全面的に書き直した。

---

## 溜まっている宿題（小さいもの）

- ~~検証用のものを消す~~ **✅ 完了。** `debug_instant` / 0Gスロット9件 / `weapon_debug_blade`（`items.json`・`shop.json`・`ja.csv`）を削除済み。エントリ数は items 15 / recipes 14 / shop 6
- 倉庫の宝箱タブ0件時の表示を`ui_warehouse_no_chest`に直す（現状`ui_warehouse_empty`）
- ~~プロジェクト直下の`bash` / `bashsedstamina_per_focus_minute`~~ **✅ 既に消えている**（ルート直下は`AGENTS.md`/`CLAUDE.md`/`icon.svg`/`icon.svg.import`/`project.godot`のみ）
- 空の`plan/`フォルダ（`.gitkeep`だけ）。`AGENTS.md`のフォルダ構成に無い。消すか構成に足すか
- 拠点下部のレイアウト調整（`ResourceRow`の`separation`、左端の見切れ）
- `AGENTS.md`冒頭の「Ziva: ChatGPT/Claude/Gemini対応」を実態（MiniMax）に合わせる
- 受け取り報告の文言。宝箱0個のとき「宝箱を0個」と出るのが不格好
- **ショップの価格・作業場のレート・装備の`equip_stats`が全部仮のまま。** バランス調整のタスクで実測する（再起動で既存セーブにも反映される）
- **`ui_res_<item_id>`という翻訳キーの命名。** `res`は`resource`の名残で、装備もポーションもこのキーを使っている。`ui_item_<item_id>`に直すなら**キーが6行しかない今のうち**
- 倉庫画面の`_rebuild_*()`が`await process_frame`を持つ書き方のまま。現状は発火するシグナルが1本ずつのため表面化していないが、シグナルを増やすときは`remove_child()`方式に直すこと（`AGENTS.md`参照）
- **トレーニングモードは`battle_debug_panel.gd`を流用できる。** `_format_unit()`が既にhp/atk/def/ターゲット/攻撃タイマーを毎フレーム出しており、敵ダミーのステータス表示はそのまま使える。`_call_controller()`が`has_method()`で存在確認してから呼ぶので、別コントローラでも壊れない。速度1〜8倍もDPS計測に使える。**足りないのは累計ダメージの記録だけ**（現状どこにも溜めていない）。トレーニングのPLANを書くときに読み直すこと
- `MasterDataLoader`にキャラのキー一覧を返す関数が無い。`training_screen.gd`の`CHARACTER_IDS`が決め打ちになっている。キャラを増やすときはここも直す
  - **研究では`get_all_research_nodes()`を用意して決め打ちを避けた。** 同じ形の`get_all_characters()`を足せば`CHARACTER_IDS`を消せる。**末尾追記だけで済む**
- 研究の解放に確認モーダルが無い（`EXEC_GUILD_RESEARCH.md` §10）。`Modal.confirm`の待ち方を確認してから`_on_unlock_pressed()`に足す
- `get_effective_level_cap()`は`character_id`を受け取るが使っていない（全キャラ共通の上限）。キャラごとに上限を変えるならここから
- **演出をまとめて実装**：セット完了メッセージ、作業中のタイトルを大きく表示、休憩明けの自動開始、作業終了通知の方式見直し
  - ~~アラーム音~~ **✅ 完了**（`EXEC_SOUND.md`）。作業終了・休憩終了で鳴る
  - OS通知（`DisplayServer.window_request_attention()`）は実装済みだが**体験版のみの暫定**。**音が入ったので、残すかどうかは人間が聴いて判断する**
  - **セット完了の通知はモーダルにしない。** 休憩の自動開始を止めてしまうため。休憩画面に出すかトーストで扱う
- **ポモドーロのデバッグパネルの「残り1秒にする」ボタンはリリース前に消す。** `OS.is_debug_build()`のガード内なので製品には出ないが、コードは残る（`debug_instant`・0Gスロット・`weapon_debug_blade`と同じ扱い）
- **`PomodoroConfig.reflection_time_limit_sec`と`reflection_min_chars`が使われていない。** `pomodoro.gd`が`const REFLECTION_TIME_LIMIT_SEC: float = 120.0`をハードコードしている。**数値管理ルール違反。** 値が一致しているため実害は出ていない（`EXEC_SOUND.md` §11）
- **音量設定・ミュートのUIが無い。** `SoundConfig`の`master_volume_db` / `se_volume_db` / `bgm_volume_db`が起動時に各バスへ適用されるだけ。**設定画面を作る回に、セーブ構造ごと決める**
- **BGMは鳴らせない。** `SoundManager`に`play_bgm()`は無い。バス`BGM`と音量欄だけ用意済み
### skills の複数ファイル化の回で見つかったもの（2026-08-16）

- ⚠ **ロード時検証がいつ走るかの記述が間違っていた。** `master_data_loader.gd` のコメントは「育成画面か戦闘画面に入って初めて動く」と書いていたが、**「つづきから」でも走る**（`load_state()` → `_resync_growth_stats_from_master()` → `_recalc_stats()` → `get_character()`）。⚠ **回るのは `character_growth` のエントリぶんなので、育成データが0件のセーブでは出ない。両方の記述が部分的に正しかった。** コメントは実測に合わせて修正済み
- ⚠ **削除したはずの `skills.json` がディスク上に復活していた**（未追跡）。ローダーは読んでいないので実害は無かったが、**「編集しても何も変わらないファイル」**が残る形だった。削除済み。⚠ **Godot を開いたまま消すとまた戻る可能性がある**
- ⚠ **コメント中の「`skills.json`」が8ファイルに残っている**（`skill_resolver` / `skill_runtime` / `status_registry` / `battle_controller` / `game_manager` / `state_keys` / `skill_select_screen` / `unit`）。**ファイルはもう存在しない。** 意味は通るので今回は触っていない
- ⚠ **`CHARACTER_IDS` の決め打ちが3件から6件になった**（`training_screen.gd`）。`MasterDataLoader.get_all_characters()` で消す案は据え置き
- ⚠ **検証用キャラに `character_nodes.json` のノードが0件。** 割り振り画面は空で開く（**落ちないことは実機で確認済み**）
- **`independent` に上限が無いことを、`skill_dbg_buff_stack` で実演できるようになった**（撃つたびに1本ずつ増え続ける）

- **状態の検証用のものもリリース前に消す**（`battle_debug_panel.gd` の `P` キー＝`_print_statuses()` / `_format_entry_line()` / `_print_stat_diffs()` と、`tests/battle/` フォルダごと、`battle_controller.get_status_registry()`）。**デバッグパネルは `OS.is_debug_build()` のガード内だがコードは残る**
- **検証用キャラとスキルもリリース前に消す**（`skills_debug.json`・`characters.json` の3件・`ja.csv` の21行・`training_screen.gd` の `CHARACTER_IDS` 3行・`master_data_loader.gd` の `PATHS_SKILLS_OPTIONAL`）
- **デバッグオーバーレイはリリース前に消す**（`res://tests/debug_overlay.gd`と`scene_manager.gd`の`_ready()`・`_spawn_debug_overlay()`・`DEBUG_OVERLAY_SCRIPT`）。`OS.is_debug_build()`のガード内だがコードは残る。詳細は`EXEC_STATS_10_AXES.md` §11-2
- **`ja.csv`に`ui_common_yes`と`ui_common_no`が重複して2行ずつある。** 10軸のタスクより前から存在する（`git show HEAD`で確認済み）。実害は出ていないが、翻訳表の重複はキーを増やすほど探しにくくなる
- **`save_version`の出どころが3箇所に散っている**（`save_manager.gd`の`CURRENT_SAVE_VERSION` / `initial_state_config.tres` / `game_manager.gd`の`_empty_state_template()`）。**上げるときは3つとも上げないと、新規開始したセーブが次回起動で自分に弾かれる。** 1本化は別タスク
- **`_percent_stat_keys()`は毎回`Array`を作って`in`で線形探索する。** 10軸・4本なら問題ないが、**毎フレーム呼ぶ場所から呼ばないこと**（式の回では呼ばずに済んだ。`BattleUnit`が生成時に派生値を確定させるため）
- **`adventure_config.tres`に上限3値（`min_attack_interval_sec` / `max_haste` / `max_crit_rate`）が書かれていない。** `[resource]`の下が空のまま。**`.gd`の既定値（0.4 / 100 / 100）が効いているので動作に影響は無い**が、Inspectorから調整する前に一度入力が要る
- **`atk_multiplier`が使われていない**（常に1.0）。`BattleFormula.damage()`に畳み込む形で渡してはいる。**バフを入れるときに、派生値（`attack_interval_sec`）の再計算とセットで設計する**（`BattleUnit`は生成時に一度だけ計算している）
- **`char_priest`の通常攻撃が`magic`になった。** 射程250で`mag` 16 を撃つため、僧侶の火力の位置づけが変わる。**バランス調整の回で見る**
- **パーティの並びが`[僧侶, 弓兵, 剣士]`になった**（`parties.json`）。剣士が最前列（右端）。**スキルボタンの並びもこの順**（画面の左右と一致する）

### スキル選択の回で見つかったもの（2026-08-15）

- ~~**`skills.json`は6件のまま・全部`unlock_level: 1`。**「Lv%d で解放」のグレー表示（`ui_skill_select_locked`）も一度も出ない＝未検証~~ **✅ 解消（2026-08-16・`EXEC_SKILL_CONTENT.md`）。** 18件になり、6候補から2つ選ぶ画面が成立した。グレー表示も実機で出た
- **`SceneManager`のログが`[SceneManager] DebugOverlay を生成した（[F4] で表示）`と出るが、`F4`は`_unhandled_input`に届かない。** 実際の切替は`0`キー。**案内文が実態と食い違っている**
- **セーブの`current_chapter`が`1.0`（float）。** `state_keys.gd` 97行のコメントは`int`と書いてある。`.gd`側にこのキーを読み書きするコードが無く、`int()`正規化も通っていない（`CLAUDE.md` 3番）。実害はまだ無い
- **`DATA_SCHEMA.md`に別タスク由来のズレが2件残っていた。** 4-3の`stats`が4軸のまま（実装は10軸）／~~3-1のスキル定義が`name`表記で`name_key`・`attack_type`・`charge`を欠く~~ **✅ 3-1は段階1の回で差し替え済み（2026-08-16）。残るのは4-3**
- **`EXEC_SKILL_SELECT.md` §11-A 1（`[MasterDataLoader] loaded 6 entries ... skills.json`が出る）は誤り。** `skills.json`は`_load_json()`で読まれており、**このログを出すのは`_index_by()`だけ**（通るのは`items.json`と`recipes.json`のみ）。characters / enemies / parties / stages / skills は全部出ない
- **旧セーブの正規化（`_normalize_skill_slots_from_save()`が実際に枠を生やす経路）は未検証。** 検証時のセーブに`character_growth`が0件で、`-> 0 / 0`しか出なかった。**未リリースのため旧セーブが存在せず、見送ると判断した**（人間の決定）。コードは残してある

### スキルの器の付け替え（段階1）の回で見つかったもの（2026-08-16）

- **`DATA_SCHEMA.md` 3-1 のダメージ計算式が古い。** `最終ダメージ = max(1, 攻撃力 - 防御力)`と書いてあるが、**実際は除算**（`battle_formula.gd` 62〜67行の`max(1, floor(power * multiplier * 100 / (100 + def)))`）。3-1のスキル定義ブロック自体は**この回で直した**（`EXEC_SKILL_TEMPLATE_PHASE1.md` §10）が、式の行は範囲外なので残した
- ~~**`sort`の`farthest` / `lowest_hp` / `highest_hp`は実装したが、使うスキルが1件も無いので実機で1度も通っていない**~~ **✅ 解消（2026-08-16・`EXEC_SKILL_CONTENT.md`）**
- **`target.range`と介入点（`_step_crit_override` / `_step_reduction`）は利用者ゼロの受け口のまま。** ⚠ **12スキルを書いても、この2つだけは埋まらなかった。** `range`の数値は座標定数（味方200・敵900）とセットで後決め（PLAN 4-5）、介入点は段階3
- ~~**`PLAN_SKILL_TEMPLATE.md` 5-2 の表と17章が、実装（決定1-5＝省略不可）と食い違ったまま**~~ **✅ 人間の指示で修正済み（2026-08-16）。** 5-2の省略時欄・5-2の`heal`の注記・17章の移行表と1文・17-1の表に反映
- ⚠ **`PLAN_SKILL_TEMPLATE.md` 21章の未確定4件が、実は段階1のEXECで決着している**（`sort`5値を全部実装／リソースは作らない／遮蔽は入れない／`count`の上限は設けない）。**PLAN側は未確定のまま。次にPLANを触るときに畳むこと**

### スキルの中身12個の回で見つかったもの（2026-08-16）

- ⚠ **`scale_from`は「和」しか書けない**（`PLAN_SKILL_TEMPLATE.md` 5-5-1 が `multiplier × Σ(weight × 変数)` と決めている）。**`atk × (1 + hp_lost_ratio)` が書けない。** よって割合の変数（`hp_ratio` / `hp_lost_ratio`）は**必ず「レベルで伸びない定数項」**にしかならない。
  - 今回の回避：`skill_last_stand`は割合ではなく**生値の`hp_lost`**を使う（最大HPに比例するので`hp`に振れば伸びる）
  - ⚠ **`skill_judgement`は回避できていない**（「対象が元気なほど痛い」は対象側の割合でしか書けない）
  - **器の話なので`PLAN_SKILL_TEMPLATE.md`側の判断。** 候補は「`scale_from`の項に積の欄を足す」か「変数表に合成済みの行を足す」（後者はDLCで組み合わせぶん増えるので筋が悪い）
- ⚠ **`PLAN_SKILL_TEMPLATE.md` 5-5-2 の「10軸の想定レンジ 50〜500」が実データと合わない。** Lv1の実データは`atk 14〜18` / `mag 16` / `def 3〜6`。**「割合の`weight`は数百」をそのまま使うと式が割合に支配される。** `EXEC_SKILL_CONTENT.md`は実データに合わせて下げてある（`hp_ratio × 40.0`）。**PLAN側は直していない**
- **`target.range`が18件とも未設定。** 座標定数を決める回に、18件まとめて入れる（PLAN 4-5）
- **倍率と`weight`は全部仮。** 特に怪しいのが3件：`skill_judgement`の`hp_ratio × 40.0`／`skill_long_shot`の`distance × 0.08`（距離0で28・距離700で140の5倍差）／`skill_shield_bash`の`def × 2.0`（`def`に振らないとただの弱い攻撃）
- **`skill_reckless_strike`（捨て身の一撃）で自死できる。** 残HPが最大HPの12%未満で撃つと使用者が死ぬ（`EXEC_SKILL_CONTENT.md` 決定1-4で「止めない」と決めた）。⚠ **止めるなら`SkillActivation.blocked_reason()`に1行足すだけで、発動可否の一箇所化の実例になる**
- **Lv15 / Lv20 のスキルは、研究でレベル上限を上げないと到達できない**（`base_level_cap` 10 ＋ `level_cap_unlock` 5×4 ＝ 最大30）
- ~~**段階2が入ったら`skill_rapid_volley`を2連射に書き換える**~~ **✅ 実施済み（2026-08-16・段階2）。** **段階3（`buff`/`dot`）が入ったら12個をもう一度見直す**

### 実行中のスキル層（段階2）の回で見つかったもの（2026-08-16）

- ⚠ **`PLAN_SKILL_TEMPLATE.md` 6-8 は「待ち行列の要素に種別タグ」を要求しているが、値の出どころが書かれていなかった。** `effects[].delivery`（`melee` / `projectile` / `magic`・省略時 `melee`）を新設して埋めた。**PLAN 5-2 の効果の欄の表に `delivery` が無い**
- ⚠ **`resolve()` が対象IDを引数で受け取る形になったことが PLAN に書かれていない**（PLAN 7-3 は「入口は2つ」としか言っていない）。**PLAN 4-4（対象は cast 時に確定）を満たすには他に方法が無かった。** 契約（時間を持たない・次のフレームを知らない・ノードを触らない）と歯止め（実効スキルデータは `skills.json` に書ける欄しか含まない）はどちらも無傷
- **利用者ゼロの受け口が段階2でも増えた**（どれも PLAN が「今作れ」と言っているもの）
  - `SkillRuntime.notify_event()` … アニメが無いので呼び出し元ゼロ。⚠ **ここが空だと `tick()` が唯一の発火経路になり、PLAN 6-5 が禁じる「タイマー専用」になる**ので作った
  - `SkillRuntime.cancel_by_delivery()` … 段階3の効果 `cancel`（飛び道具の無効化）と詠唱中断が使う
  - `EVENT_TIMEOUT_SEC`（5.0秒）… `event:` を書いたスキルが0件なので実戦で1度も通らない
  - `trigger: "charge_start"` … 本命の「チャージ中の軽減」は状態＝段階3
- **`delivery` を書いていない効果は `melee` 扱いになる。** 回復（癒しの光・集中治療・吸命②）と自傷（捨て身の一撃②）にも `melee` が入る。**投射する回復を作るときに見直す**
- **速射の合計ダメージは以前と完全一致しない。** `BattleFormula.damage()` が `floor` して最低1を返すので、倍率1.3を0.65×2に割ると端数が2回切り捨てられる（素の値で `18 → 9 + 9`）。**会心も2回別々に振られ、片方だけ会心することがある。** ⚠ **どちらも PLAN 5-5-4 が望ましいとしている挙動**
- **`SkillResolver.resolve()` に効果が2件以上来たら `push_warning` する。** 新層を通さずに呼ばれたことの検出用。**正常系では出ない**

### 状態の器（段階3の前半）の回で見つかったもの（2026-08-16）

- ⚠ **`SkillResolver` と `StatusRegistry` を素直に型で結ぶと相互参照になる。** `resolve()` の `registry` を `StatusRegistry` 型にすると、`status_registry.gd` が DoT の発火で `SkillResolver.resolve()` を呼ぶため、2ファイルが相互参照になり `Cyclic reference` のパースエラーを踏みうる（`battle_formula.gd` 冒頭が警告している形）。**Godot を起動できず踏むか確かめられないので、`RefCounted` 型で受けて踏みようがない形にした。** 代償として `registry.add()` は動的呼び出し
- ⚠ **`BattleUnit.create()` が `attack_interval_sec` の base を捨てていた。** 実効値（atkspd 適用後）しか残らないので、`atkspd` のバフを付けるたびに実効値をさらに割ることになり、**剥がしても戻らず累積で速くなる。** `_base_attack_interval_sec` を保持して `refresh_derived()` から計算し直す形にした
- ⚠ **状態の寿命と周期で別々のカウントダウンを持つと、浮動小数の誤差が別々に積もる。** `duration 4秒` × `interval 2秒` のように両方が同時に切れるフレームで、**最後の1発が落ちる。** 時計を `elapsed` の1本にして、発火も消滅もそこから引く形にした
- ⚠ **能力値の補正（`BattleUnit._stat_mods`）を差分更新しない。** `StatusRegistry` が自分の持つ状態から毎回ゼロから組み直して丸ごと渡す。差分更新にすると剥がし忘れが「少し強いまま」残り、**エラーも出ず F3 パネルの数字ももっともらしいので気づけない**
- ⚠ **`type: buff` の `stat` に `hp` を書けない**（赤で弾く）。`max_hp` を動かすと現在HPのクランプと割合計算（`sort: lowest_hp` / `scale_from: hp_ratio`）が同時に動くため。**最大HPバフを入れる回で解く**
- ⚠ **`until: "skill_end"` は語彙と黄だけで未実装。** 剥がすには「その `cast_id` の待ち行列が空か」を `SkillRuntime` に聞く配線が要る。**段階3の後半で `SkillRuntime` を触るときにまとめる**
- ⚠ **段階2で開いていた穴を1つ塞いだ。** `activation` が `charge` でないスキルに `trigger: "charge_start"` を書いても検証を素通りしていたが、`charge_start()` はチャージ時にしか呼ばれないので**一度も発火しない**。E45 として赤で弾く（`until: "charge_end"` も同じ理由で E44）
- **`stack` は省略不可にした**（`independent` / `refresh`）。既定値をどちらに倒しても書き忘れが無音で挙動を変えるため（`scale_from` と同じ方針）
- ⚠ **状態の同一性のキーは `(宿主, status_id, 付与者)` の3つ組。** `status_id` だけにすると、2人の僧侶が同じバフを配ったとき片方が消える
- **利用者ゼロの受け口がまた増えた**（PLAN 13-1 が「初回実装で」と言っているもの）
  - `host: point` / `host: battle` … 参照する仕組み（条件・購読）は段階3の後半
  - `bump_counter()` / `counter` 欄 … 同上（コンボ・N回攻撃ごと）
  - `query()` の `source_unit_id` 絞り … 同上（自分が付けた毒だけ強化）
  - `StatusRegistry.clear_for_unit()` … 死亡の掃除は `tick()` がやる（死亡を知らせるシグナルが無いため）
- **`unit_id` からユニットを引く `_find_unit()` が3ファイルに同じ形で3本ある**（`skill_resolver` / `skill_runtime` / `status_registry`）。`BattleSession` に寄せるかは別途
- ⚠ **状態は画面に何も出ない。** F3 パネルの3行目が唯一の確認手段だった。~~**しかも `Label` に書いているだけで `print` を出していないので、Ziva（コンソールを読む）からは見えない**~~ **✅ 解消（2026-08-16）。** `P` キーで `snapshot()` を `print` するようにした
- ⚠ **`stack` の5部品のうち4つが未実装**（上限・消え方・再付与・閾値）。**`independent` に上限が無いので、CD より `duration` が長いスキルは無限に積める**（UIが先に音を上げる）

---

### 購読（段階3の後半①）の回で見つかったもの（2026-08-17）

- ⚠ **`skills.json` に足しただけではスキル選択画面に出ない。** 候補の一覧と並び順は **`characters.json` の `"skills"` 配列**が決める（`game_manager.gd:1745`）。⚠ **ロード時検証は `skills.json` しか見ないので、忘れてもログは `39 entries, 0 errors` と正常に見える。** 症状は「画面に出ない」だけ。**EXEC に書き忘れ、実機で踏んだ**
- ⚠ **`SkillResolver` から購読を発火できない。** static クラスで待ち行列も器も持たないため、発火させると `SkillRuntime` との相互参照になる。**観測（`_apply_damage()` 第2段で結果にキーを足す）と発火（`SkillRuntime._fire()`）を分けた。** NEXT_STEPS の「どこで出せるか」の表は観測点であって発火点ではない
- **10-2 の印（反応から生まれた行動は、さらなる反応を生まない）は `_fire()` の1箇所だけ。** `entry["from_reaction"]` を見て合図の配布を飛ばす。⚠ **`results.is_empty()` の early return より前**に置くこと（空振りでも `attacked` は出る）
- ⚠ **DoT の周期ダメージでは購読が発火しない。** `StatusRegistry` が `SkillResolver.resolve()` を直接呼ぶ経路（`status_registry.gd:372`）は `SkillRuntime` を通らないため。**毒のダメージでは反射もカウンターも動かない**
- ⚠ **購読は `host: unit` のみ。** `host: battle`（コンボ）・`host: point`（罠）はまだ載らない（E51 が赤で弾く）
- ⚠ **`scale_from` の `of: "source"` は未実装のまま**（`_scale_variable()` の黄が残る）。反射の威力は `of: user` で書けるので今は困らない
- ~~**敵にスキルが無い。**~~ ✅ **解消**（2026-08-17・`EXEC_ENEMY_PARITY.md`）。敵スキルは `enemies/<enemy_id>/skills.json`（`characters/` と同じ階層・同じ形）。`enemies.json` の `"skills"` は**そのまま装備枠**（味方の「候補一覧→選んだ2枠」の2段は無い）。敵は**攻撃間隔と同じ拍で、射程内でだけ、CDが空いたスキルを先頭から撃つ**（乱数なし）。⚠ **敵視点の `team` 解決（`ally` が敵の仲間を指す）が実際に通ったのはこの回が初めて**で、`heal` の `dst` が全て `enemy_` であることをログで確認済み
- **検証用ステージは別枠で常設**（2026-08-17）。`stage_order.json` の `"debug"` 列 ＋ `adventure_select` の3関数。⚠ **本番の `"story"` 列を書き換えない**（以前は `"stage_1"` を差し替えて戻す運用で、実際に戻し忘れとセーブ汚染が起きた）。⚠ **`STAGE_TYPE_TRAINING` で入るので、スタミナ・報酬・クリア記録が付かない**（`_enter_victory()` が story のときだけ実行する）。テストしたいこと1つにつきステージ1本（`stage_dbg_enemy_skill`）
- **検証用の敵6体もリリース前に消す**（宿題16番に含める）：`resources/balance/master/enemies/` フォルダごと、`enemies.json` の `enemy_dbg_*` 6体、`stages.json` の `stage_dbg_enemy_skill`、`stage_order.json` の `"debug"` 列、`ja.csv` の13行、`MasterDataLoader.ENEMY_DIRS_OPTIONAL`、`adventure_select.gd` の検証用3関数、`GameStateKeys.STAGE_TYPE_DEBUG`
- ⚠ **`adventure_select.gd:4` のヘッダコメントが実装と逆。** 「スタミナの消費はこの画面でのみ行う（戦闘画面では消費しない）」と書いてあるが、実際に減らすのは `battle_controller._consume_stage_stamina()`（勝利時）で、この画面は残量を見ているだけ
- ⚠ **Windows の bash で `cat >>` すると追記分が CRLF になる。** 元が LF の JSON に混ざって壊れる（`enemies.json` / `stages.json` で実際に踏み、Python で LF に統一し直して復旧）。**`AGENTS.md` の「ツールの制約」に1行足すかは人間の判断**
- ⚠ **古いセーブに `stage_dbg` のクリア記録が残っている**（改名前に1回クリアしたため）。マスターに無いIDなので実害は無い
- ~~⚠ **戦闘中の出来事が画面にしか出ない。**~~ ✅ **解消**（`BattleLog`・2026-08-17）。`user://logs/battle_last.jsonl` に1行1イベントで出る。反射が殴ってきた相手に返ったことは、**並びの推測ではなく `src` / `dst` のIDの一致で確定できる**ようになった（`IMPL_LOG_BATTLE_LOG.md` §4 の8番）
- **戦闘ログもリリース前に消す**（宿題16番に含める）：`scripts/systems/battle_log.gd` ごと、各層の `BattleLog.` 呼び出し15箇所（`skill_runtime` 3 / `status_registry` 5 / `battle_controller` 7）、`battle_debug_panel.gd` の `O` キーと説明行。⚠ **`_notify()` の `print` を消してファイル側へ移してある。** ログを消すときは、購読の発火が**どこにも出なくなる**ことを承知の上で消すこと
- **検証用スキル3件・状態4件はリリース前に消す**（宿題16番に含める）：`skill_dbg_react_thorns` / `_followup` / `_warcry`、`status_dbg_react_thorns` / `_followup` / `_warcry` / `_warcry_atk`
- ⚠ **足した7件目だけ JSON のインデントが1タブ深い**（3ファイルとも）。パースは通る。見た目だけ

---

## 次に何をすべきか

### ~~最優先：ポモドーロのアラーム音~~ ✅ 完了

**演出ではなく機能の欠落**として片付けた（`PLAN_SOUND.md` / `EXEC_SOUND.md`）。作業終了と休憩終了で鳴る。休憩の**スキップボタンでは鳴らない**（自分で押したので気づいている）。

同時に**音の共通基盤ができた。** 以降のSE/BGMは`SoundManager.play_se()`を呼ぶ行と`SoundIds`の定数を足すだけになる。

### ~~次：ステータス10軸~~ ✅ 前半（器）だけ完了

`PLAN_IMPLEMENTATION.md` 3章の2番。**大きいので2回に分けた。前半（器）が完了（2026-08-15）。**

前半で入ったもの：`_stat_keys()`が10本、`state_keys.gd`の定数、`characters.json`/`enemies.json`の軸、育成・装備画面の10行表示、**研究の`boost_all`を実数軸だけに限定**、セーブを`v2`にして旧セーブを弾く。

**戦闘の式は入っていない。** ダメージは今も`atk - def`の減算のまま。`mag` `mdef` `atkspd` `haste` `crit_rate` `crit_dmg`は**セーブと画面には出るが戦闘では何もしない。**

### ~~次：ステータス10軸の後半（式の反映）~~ ✅ 完了（2026-08-15）

**`BattleUnit`を作り直した。** 位置引数10個 → `stats: Dictionary`1本＋`static create()`。軸を増やしても`GameManager.get_stat_keys()`に足せば戦闘まで届く。

**`scripts/systems/battle_formula.gd`を新設し、式を1箇所に集約した。** 通常攻撃・スキル・デバッグ表示の3経路が同じ関数を通る。**戦闘の式を直すときはまずここを見る。**

### ~~次：レベルの役割転換（割り振りポイント・パッシブ・スキル解放）~~ 🟡 2/3 完了（2026-08-15）

`PLAN_IMPLEMENTATION.md` 3章の**3番**。**3つに分けて、2つが終わった。**

| レベル | 何が起きるか | 実装 |
|---|---|---|
| 1レベルごと | 割り振りポイントを1点 | **✅ 完了**（`EXEC_LEVEL_ROLE_SHIFT.md`） |
| 5・10・15・20 | スキル候補が1つ解放 | **✅ 器は完了**（`EXEC_SKILL_SELECT.md`）。**中身のスキル12個は未着手** |
| 20レベルごと | パッシブが1つ解放（計5個） | **無い** |

割り振りで`stat_growth_formula`が`"base"`になり、**レベルではステータスが伸びなくなった。** スキルでは`battle_controller.gd`のマスター直読みが消え、**戦闘は`GameManager.get_battle_skills()`だけを見る。**

### ~~次：パッシブ（その前にスキルのテンプレ決めが要る）~~ ✅ **テンプレ決定は完了（2026-08-16）**

**決定台帳は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`。** 3回の専用セッション（うち2回は別AIとの往復）で確定させた。**もう「たたき台」ではない。**

- **`type` を廃止し、`activation` / `target` / `effects[]` / `host` の**4軸**＋ 発火源・介入点の**2層**
- **`effects` は配列。** ダメージ＋デバフ・多段・吸血が1スキルに書ける
- **`trigger`**（`cast` / `event:◯◯` / `delay:N`）。**多段の間隔をJSONに書かない**（アニメと二重管理になる）
- **`scale_from` とスケール変数表。** `spd` でも `hp_lost_ratio` でも `distance` でもスケールできる。**DLCで増える唯一の場所**
- **実装は段階1〜6に分ける。器は全部決め、実装は順に**

### ~~次：**スキルの器の付け替え（段階1）**~~ ✅ **完了（2026-08-16）**

**指示書は `EXEC_SKILL_TEMPLATE_PHASE1.md`。実機確認（§11-A・§11-B）まで通過した。**

- `skills.json` の6件が `activation` / `target` / `effects[]` になった（`type` 欄は1件も残っていない）
- **`SkillSchema`（新規・語彙とロード時の全件検証）** と **`SkillActivation`（新規・発動可否を1箇所）** が入った
- `SkillResolver` は**入口2つ**（`select_targets()` / `resolve()`）に作り直し、ダメージは**2段構え**（確定は1回だけ）
- **挙動は変わっていない。** 唯一の意図した差は、対象が0体のときクールダウンを回さなくなったこと（EXEC 決定1-6）

### ~~次：**スキルの中身12個**（3人 × Lv5/10/15/20）~~ ✅ **完了（2026-08-16）**

**指示書は `EXEC_SKILL_CONTENT.md`、決定台帳は `PLAN_SKILL_CONTENT.md`（新設）。実機確認まで通過した。**

⚠ **段階2の前にこのタスクを挟んだのは人間の判断。** 段階1で足した受け口が**実機で1度も通っていない**まま段を積まないため。

- `skills.json` **6件 → 18件**。`characters.json` の候補が各キャラ6件。`ja.csv` に12行
- ⚠ **`.gd` を1行も触っていない**（マスターデータと翻訳だけ）
- **段階1の受け口が初めて実コードを通った**：`sort`の`farthest`/`lowest_hp`/`highest_hp`・`attack_type: "true"`・`scale_from`のHP派生と`distance`と`of: target`・`count: 2`・効果ごとの`target`上書き・1スキル2効果・単体回復
- **「Lv%d で解放」のグレー表示が初めて画面に出た**（`ui_skill_select_locked`。これまで一度も出たことがなかった）
- ⚠ **埋まらなかった受け口は2つだけ**：`target.range`（座標定数待ち）と介入点（段階3）

### ~~次：**実行中のスキル層と `trigger`（段階2）**~~ ✅ **完了（2026-08-16）**

**指示書は `EXEC_SKILL_TEMPLATE_PHASE2.md`。実機確認まで通過した。**

- **`scripts/systems/skill_runtime.gd` を新設した。** `battle_controller`（入力と表示）と `SkillResolver`（1回ぶんの解決）のあいだの層
- ⚠ **待ち行列は1本**（PLAN 6-8・後から変えられない）。`cancel_for_user()` / `cancel_by_delivery()` / `clear_all()` で**外から取り消せる**
- ⚠ **発火の経路は `_fire()` の1本**（PLAN 6-5）。`cast` / `delay:N` / `charge_start` / `event:◯◯` が全部そこへ入る。**`tick()` はその呼び出し元の1つにすぎない**
- ⚠ **対象は cast 時に確定する**（PLAN 4-4）。`resolve()` が対象IDを引数で受け取る形になった。**発火時に選び直すと多段の2発目が別人に吸われる**
- **`delivery`（種別タグ）を新設**（`melee` / `projectile` / `magic`）。段階3の飛び道具無効化がそのまま書ける
- **中断は正常系なので警告を出さない。タイムアウトだけが異常で、発火させたうえで `push_warning`**
- **速射が2体 × 2連射になった**（`delay:0.35`）＝多段と遅延が実際に動いた

### ~~次：**状態の器（段階3の前半）**~~ ✅ **完了（2026-08-16）。検証手段を作って挙動を確認済み**

**指示書は `EXEC_SKILL_TEMPLATE_PHASE3A.md`。** ロード時検証（`skills validated: 18 entries, 0 errors, 0 warnings`）に加え、**`tests/battle/test_status_registry.tscn` の13項目が NG 0件で通った**（下の「状態の検証手段」の節）。

- **`scripts/systems/status_registry.gd` を新設した。** 状態の器（ユニット／座標／戦場に紐づく「残るもの」）
- ⚠ **`SkillRuntime` と捨てる基準が正反対。** `SkillRuntime.tick()` は**使用者**が死んだら捨て、`StatusRegistry.tick()` は**宿主**が死んだら捨てる。**付与者の死では捨てない**（PLAN 7-2）
- **`buff` / `dot` が当たるようになった。** `stat` / `value` / `duration_sec` ／ `multiplier` / `interval_sec`
- **`effects[].stack` を新設**（`independent` / `refresh`・**省略不可**）。⚠ **状態は1ユニットに複数個持てる**（PLAN 20章の1番）
- **`effects[].until` を新設**（`charge_end` を実装・`skill_end` は語彙だけ）。⚠ **寿命は秒数だけではない**（PLAN 20章の2番）
- **`host` は `unit` / `point` / `battle` の3種とも器が受け取れる**（PLAN 20章の5番）。⚠ **実際に動くのは `unit` だけ**
- **能力値の補正は `BattleUnit.get_stat()` の1本に入る。** F3 パネルも `scale_from` も `BattleFormula` も自動でバフ込みになる
- **検証用に3スキルへ効果を足した**（`skill_power_slash` に atk バフ・`skill_holy_ray` に dot・`skill_wide_sweep` にチャージ中の def バフ）。**スキルは18件のまま**

### ~~次：**状態の検証手段（コンソール出力 ＋ テストシーン）**~~ ✅ **完了（2026-08-16）**

**器の実装（段階3の前半）が入っただけで挙動を1つも確かめていなかったので、確かめる手段を先に作った。** 状態の事故は全部無音（黙って剥がれる／二重に付く／消えない／最後の1発が落ちる）で、しかも画面にほとんど出ない。

- **F3 パネルに `P` キー**（`_print_statuses()`）。押した瞬間に1回だけ、`snapshot()` を丸ごと出す。⚠ **パネルの3行目に出ない `host: point` / `host: battle` もここには出る**
  - **素の値 → 実効値**を並べて出す（`_print_stat_diffs()`）。`get_stat()` は足したあとしか返さないので、**パネルの数字だけでは「バフが乗った」と「元からその値」を区別できない**
- **`tests/battle/test_status_registry.gd` + `.tscn`（新規フォルダ）** … 13項目。`RefCounted` だけで完結するのでシーンツリー不要。**NG 0件で通った**（赤は「弾かれるのが正解」の3項目だけ）
  - `stack` 2種・付与者違いで2本・端数の切り捨て・**`duration 4 × interval 2` で最後の1発が落ちない**・1フレームに6秒ぶんの delta で3回発火・宿主の死で消えて補正も消える・付与者の死では止まらない・`atkspd` バフが累積せず剥がすと戻る
  - ⚠ **`tick()` に渡す delta は 0.5 / 1.0 / 2.0 だけ。** 0.1 を60回足すと 5.999… になり、器の不具合とテスト側の誤差を区別できなくなる
  - ⚠ **失敗は `push_error` にしない。** 3項目は「赤が出るのが正解」なので、混ざると読めない。行頭の `NG!` で見る

### ~~次：**skills を複数ファイル化（キャラ別 ＋ debug）＋ 検証用キャラ**~~ ✅ **完了（2026-08-16）**

**指示書は `EXEC_SKILL_MULTIFILE.md`。** ログ・ファイル・画面の**全項目が通った**。

- **`skills.json` を消し、`skills_char_swordsman` / `_archer` / `_priest` の3本へ**（各6件・IDの改名なし）
- **`skills_debug.json`（18件）＋ 検証用キャラ3体**（`char_debug_status` / `_life` / `_mix`）。**HP 9999 / atk 1 / crit_rate 0** で、死なず・敵も倒さず・会心も振らない
- ⚠ **「枠を無視して撃つキー」は作らなかった。** 検証用キャラの候補6件をギルドで付け替えるほうが安い（`.gd` がほぼゼロ行）
- ⚠ **パーティの入れ替え機能も要らない。** パーティは状態に入っておらず、`parties.json` の `members` を書き換えて再起動すれば入れ替わる
- ⚠ **`MasterDataLoader` は重複IDを赤で弾き、先に読んだほうを残す**（後勝ちにすると無音で片方が消える）。**`skills_debug.json` は「無いのが正常」**

**検証時の手順**：`parties.json` の `members` を `["char_debug_status", "char_debug_life", "char_debug_mix"]` に差し替えて再起動。⚠ **戻し忘れると本編の検証が全部おかしくなる。**

**`skills.json` は315行 / 18スキル / 24効果。** 段階3の後半で購読と条件が乗ると**1スキルが30〜50行**になり、4人目のキャラで500行を超える。

⚠ **デバッグ用のスキルを足す仕組みと、キャラごとに割る仕組みは同じもの**（`MasterDataLoader` が複数ファイルを読んでマージする）。**別々にやると2回作ることになる。**

- ⚠ **重複IDは赤で弾く。** 同じIDが2ファイルにあると**あとから読んだほうが黙って勝つ**
- ⚠ **IDは1つも改名しない**（改名するとスキル選択の保存が黙って消える・`CLAUDE.md` 4番）
- **ロードログの `skills validated: N entries` は合計値のまま1本に保つ**（完了条件に使い続けられる）
- **枠を無視して任意のデバッグスキルを撃つキー。** ⚠ **`StatusRegistry.add()` を直接叩かないこと。** 通常経路（`_fire_skill` → `SkillRuntime` → `resolve` → 器）を通らないと配線の事故を隠す

### ~~次：**1キャラ＝1フォルダへ移す**~~ ✅ **完了（2026-08-16）**

**人間の決定。** `character_nodes.json`（1784行・180件）と `skills_debug.json` を解体し、キャラのフォルダへ移した。

```
resources/balance/master/characters/char_swordsman/skills.json   (6件)
resources/balance/master/characters/char_swordsman/nodes.json    (60件)
resources/balance/master/characters/char_swordsman/passives.json ← 実装する回にここへ
```

- **分割前後でデータは完全一致**（機械で突き合わせ済み。skills 36件・nodes 180件）
- ⚠ **`characters.json`（能力値）は動かしていない。** `GameManager` が育成・装備・研究から何度も引いており、触ると挙動の話になる。**フォルダは「量が多くてキャラ別に閉じているもの」だけを持つ**
- ⚠ **パッシブのファイルは作っていない**（実装がゼロ。置き場だけ決めた）。**空ファイルを置くと「利用者ゼロの受け口」が1つ増えるだけ**
- ⚠ **走査しない**（人間の決定）。フォルダを増やしたら `MasterDataLoader.CHARACTER_DIRS_REQUIRED` に1行足す。**足し忘れるとそのキャラのスキルとノードが無音で消える**
- ⚠ **敵も同じ罠。** 本編の敵にスキルを載せたら `MasterDataLoader.ENEMY_DIRS_REQUIRED`（今は**空**）に1行足す。検証用の敵は `ENEMY_DIRS_OPTIONAL`（無いのが正常）
- **マージは1本に統合**（`_load_character_files()` / `_merge_id_map()`）。スキルもノードも同じ経路を通る
- **実機で確認済み** … `skills validated: 36 entries`（つづきから）と `loaded 180 character nodes`（割り振り画面）

⚠ **2つのログはタイミングが違う。** スキルは `_ensure_loaded()` に組み込んであるので「つづきから」で出る。**ノードは別キャッシュの遅延ロードで、`get_all_character_nodes()` を呼ぶのは割り振り画面だけ**（`get_character_node()` の4箇所は全部「解放済みノードを回すループ」の中なので、0件のセーブでは1回も呼ばれない）。**完了条件にノードのログを書くときは「割り振り画面を開く」まで書くこと。**

### ~~次：**通常攻撃をデータ化して、スキルと同じ経路に載せる（挙動不変）**~~ ✅ **完了（2026-08-16・`03a0d8e`）**

⚠ **通常攻撃が `SkillResolver` を1ミリも通っていないことが分かった（2026-08-16）。** `battle_controller._step_unit()`（412〜434行）が `BattleFormula` → `take_damage()` → `_pop_damage()` と直行しており、**段階1で作ったダメージの介入点（`_step_crit_override` / `_step_reduction`）が通常攻撃に効かない。** このままだと**シールドも軽減も反射も「スキルにだけ効く」**という説明のつかない仕様になる。

⚠ **`PLAN_SKILL_TEMPLATE.md` 10-4 は「通常攻撃は合図を出す」としか書いておらず、式の経路が2本あることに触れていない。PLAN側の穴。**

**人間の決定（2026-08-16）：通常攻撃もキャラごとに違う内容にしたいので、スキルと同じ方式（データ化＋分割）にする。** ⚠ **経路の一本化とデータ化は同じ工事。** 購読の前に潰す（反射を書いた段になって「効かない」と分かるのが一番高くつく）。

⚠ **完了条件は「挙動が1件も変わらない」**（段階1と同じ形）。**人間がログと戦闘の挙動を確認済み。**

入ったもの：`characters.json` / `enemies.json` の各エントリに **`basic_attack`（9件）**／**`_compute_damage()` を廃止**して `_fire_basic_attack()` へ／**`SkillSchema.validate_basic_attack()`**（`_validate_effect()` を共用）／**`delivery` が全9件に入った**。

### ~~次：**投射物を実際に飛ばす**~~ ✅ **完了（2026-08-16・`3fb91b9` ＋ `9b202ff`）**

**`delivery` がタグでしかなかったのを、実際に飛ぶものにした。** PLAN 6-7 / 6-8 が既に決定として持っていた形なので、新しい決定は入れていない。

⚠ **受け口3つの呼び出し元がゼロだったのを埋めた**（`notify_event()` / `cancel_by_delivery()` / `trigger: "event:◯◯"`）。

```
SkillRuntime      効果を「着弾待ち」で積み、矢を1本頼む（シグナル）
   ↓ projectile_requested        ⚠ この層はノードを触らない（契約）
BattleController  演出シーンを出す（データとビューが出会う唯一の場所・PLAN 7-1）
   ↓ setup()
ProjectileView    飛ぶ。着いたら合図を返すだけ（ダメージは出さない）
   ↓ on_projectile_hit → notify_event(cast_id, "hit")
SkillRuntime      待っていた効果を発火（経路は _fire() の1本のまま）
```

- **`scenes/adventure/projectile_view.gd` 新設**（`.tscn` を作らずコードで組む）。誘導する。**対象が消えたら発射時の座標へ飛び続けて空振りし、それでも合図は返す**
- **`cast()` に `fixed_target_ids` を追加**。⚠ **通常攻撃が「歩いて近づいた相手」を撃つため**。`cast_basic()` は作らない（発火経路は1本）
- **通常攻撃も待ち行列を通す**。⚠ **`03a0d8e` で入れた「通常攻撃に `trigger` は書けない」を撤回した**（要素は着弾で消えるので伸び続けない。載せないと飛び道具の無効化が通常攻撃にだけ効かず、直したばかりの「スキルにだけ効く」が再発する）
- **1回の発動で出す矢は送り方1つにつき1本**（癒しの光の `damage`+`dot` で2本飛ぶのを防ぐ）
- **弾速は `Balance.adventure`**（JSONに弾速を書かない・PLAN 6-7）
- ⚠ **`event:hit` の黄を止めた。** 合図を出す側ができたため。止めないと**17本の黄**が出て本物の異常が埋まる
- **人間が8項目とも確認済み**（飛ぶ・着弾でダメージ・8倍速で追いつく・空振り・ウェーブ交代とリトライで残らない）

⚠ **挙動が変わった。** 着弾までの遅れで**倒す順番と過剰攻撃**が変わっている。

### ~~次：**キャラごとに違う通常攻撃を実際に書く**~~ ✅ **完了（2026-08-16・`51c09f6`）**

**剣士は重い一撃／弓兵は一番DPSが高い／僧侶は範囲／狼は速め／ボスは重い単体**（人間の決定）。

| | 間隔 | 倍率 | DPS | |
|---|---|---|---|---|
| 剣士 | 1.2→**2.4** | **1.7** | 15.0→**12.8** | 1発 30 |
| 弓兵 | 1.5→**1.0** | 1.0 | 9.3→**14.0** | 一番高い |
| 僧侶 | 1.6→**1.8** | **0.5** | 10.0→**4.4** | **範囲**（3体なら 13.3） |
| 狼 | 1.0→**0.7** | **0.85** | 12.0→**14.6** | 速め |
| スライム王 | 1.8→**2.2** | **1.5** | 6.7→**8.2** | 重い単体 |

- **`basic_attack` に `target` を省略可で書けるようにした。** 書いた場合だけ範囲攻撃
- ⚠ **`range` は書けない**（射程は `attack_range` が正）
- ⚠ **`_fire_basic_attack()` が分岐する。** 両方渡すと固定が勝ち、`target` が黙って無視される
- **攻撃の速さは `attack_interval_sec`**（新しい欄は作っていない。`basic_attack` 側に移すと二重管理）

### 次：**段階3の後半① — 購読**（反射・追撃・撃破強化・マーク・コンボ）

⚠ **初回に必ず含めるものが2つある**（PLAN が名指ししている）。**10-2「反応から生まれた行動は、さらなる反応を生まない」**（印1つで反射ループ・追撃発散・コンボ水増しが同時に止まる）と、**10-3 `target.team: "source"`**（きっかけのユニットを指せないと追撃も反射も書けない）。**後から足すと再現しづらい。**

### その次：**段階3の後半（購読・条件・介入点3種・パッシブ・コンボ）**

⚠ **4つに割った**（`NEXT_STEPS.md` の「このあと来るもの」）。①購読 → ②条件 → ③介入点3種 → ④変数表の追加。**器の前半で「固めてから乗せる」が正しかったのと同じ理由。**

⚠ **横断ルール「反応から生まれた行動は、さらなる反応を生まない」**（PLAN 10-2）は**購読の初回実装に必ず含める。** 後から気づくと再現しづらい。

⚠ **`battle_formula.gd` は67行の static。** 回復・状態付与・死亡の介入点3種はこの周りに入る（PLAN 11-1）。**ダメージの介入点だけは段階1で受け口を作ってある**（`_step_crit_override` / `_step_reduction`・利用者ゼロ）。

⚠ **パッシブはこの中。** 条件発動が要求する層は `buff` / `dot` が要求する層と**同一**で、2回に分けて作る意味が無い（PLAN 7-2・19章）。

### バランスの実測は後回しになった

**前は「最優先：バランスを実測する」と書いてあった。その前提は崩れた。**

素材の種類（3段階→4段階）・ステータスの軸（4→10）・等級の上限（3→10）・装備の入手経路（作業場→ステージの抽選ドロップ）が全部変わる。**測る対象そのものが作り直しになる。**

**構造が実装されてから測る**（`PLAN_IMPLEMENTATION.md` 3章の12番）。

**計算道具（`balance_report.py`）は存在しない。** 一度作りかけたが、リポジトリに`*.py`は0件。**「作成済み」と書かれた過去の記述を信じないこと。**

### 装備の第2弾で分かった重要な事実

**装備の入口は4箇所あり、`_grant_item()`を通るのは作業場だけだった。** 唯一の関所は`add_to_inventory()`。個体の生成をここ1箇所に置いた。**`_grant_item()`に置いていたら、宝箱とショップから出た装備が個体にならず静かに消えていた。**

**`_default_state()`という関数は存在しなかった**（実際は`_empty_state_template()`）。**ドキュメントと実コードのズレ6回目。**
### 反転した決定

**`GAME_DESIGN.md` 12章に一覧がある。ここには置かない。**

> 以前このファイルに6行の反転表があったが、その後の設計でさらに反転した（例：ステータスの軸は「4本→9本」と書いてあったが、いまは10本）。**反転の記録が2箇所にあると、どちらが新しいか分からなくなる。**

### 作業場について（記録）

**作業場は「戦闘以外のインクリメンタル要素」を作るために始めた。** これはどのドキュメントにも書かれていなかった。

**現状は目的から外れている。** 中身が素材変換と武器製作で、出口が戦闘に戻っている。**デモ版では現状のまま止める。**

将来の候補：拠点の拡張（`WorkshopConfig.max_queue_slots`が器として既にある）／ポモドーロ側の強化／記録と実績。**コスメティックはSDキャラの素材が無いので作れない。**

> **⚠ 「デモ版では現状のまま止める」という判断は反転した。** 作業場は作り直す（`GAME_DESIGN.md` 9-3）。素材変換と装備製作を廃止し、中間素材と装飾のランダム製作にする。**「戦闘以外のインクリメンタル要素」という当初の目的には、掘削（デモ範囲外）で戻る。**

### 装備で分かった重要な事実

**戦闘は`get_effective_stats()`を呼んでいなかった。** `battle_controller.gd`が`get_character_growth()`の生の`stats`を直接読んでいたため、**研究の全ステータス+3が戦闘に効いていなかった。** 装備のタスクで修正済み。

**同じ形の見落としが`attack_interval_sec`と`cooldown_sec`にもあった。✅ 確認済み（2026-08-15・10軸のタスク）。予想は当たっていた。**

| 場所 | 何が起きていたか | 対処 |
|---|---|---|
| `battle_controller.gd` 165行 | `char_data.get("attack_interval_sec")`。**すぐ上で`get_effective_stats()`を取っているのに、攻撃間隔だけマスターから直読み** | ✅ `BattleUnit.create()`が`atkspd`を適用して`attack_interval_sec`に入れる |
| 同 477行・599行 | `skill_data.get("cooldown_sec")`をskills.jsonから直読み。**`haste`が入る場所が無い** | ✅ `BattleFormula.cooldown()`を通す |
| ダメージ経路が**2箇所**（`battle_controller.gd` 397行と`skill_resolver.gd` 91行） | どちらも`atk - def`の減算を別々に書いていた | ✅ `battle_formula.gd`に集約。**3経路（通常攻撃・スキル・デバッグ表示）が同じ関数を通る** |
| `skill_resolver.gd` 80行の回復量が`user.atk`参照 | 僧侶の回復が攻撃力依存だった | ✅ `mag`参照に変更 |
| `skills.json`に参照欄も種別欄も無い | — | ✅ `attack_type`を追加（`characters.json`/`enemies.json`にも同じ欄） |

**5件とも10軸の後半で解消した（2026-08-15）。** 予想は全部当たっていた。**「すぐ上で正しい関数を呼んでいるのに、1つの値だけ直読み」という形は他にもありうる。**
### 実装の順番

**`PLAN_IMPLEMENTATION.md` 3章が台帳。ここには置かない。**（`GAME_DESIGN.md` 15章も同じ理由でポインタにした）
### 音とアニメーションの扱い

**これまでのタスクと失敗の仕方が違う。** `grep`で正解が確定できない。「歩き方が硬い」「アラームが耳障り」は実際に見て聴いて判断するしかなく、**判断者は人間だけ。** コードのタスクと同じ会話に混ぜないこと。

**ポモドーロのアラームだけは演出ではなく機能の欠落。** 作業終了時に音が鳴らなければ終わったことに気づけず、120秒の振り返り猶予を無音で失う。25分働いたのにノーカウントになるのは「やって後悔した」の最も直接的な形。**演出ではなくバグ修正として扱う。**

---

## 横断的な未確定事項一覧

同じ論点が複数ファイルで別々に「未確定」と書かれると、片方だけ決めて矛盾する。ここに集約し、個別PLANはポインタだけ残す。

### 決定済み

> **⚠ このうち新設計で反転したものがある。反転の一覧は`GAME_DESIGN.md` 12章。** 実装済みの記録としては有効なので行は消していない。**今回の設計で決まったことは`GAME_DESIGN.md`を見ること。** 数が多いのでここには写さない。

| 論点 | 決定内容 |
|---|---|
| 「1日」の区切り | 毎朝4:00。判定は`scripts/utils/game_date.gd`に集約 |
| 加護の効果 | 報酬倍率を廃止し宝箱スケジュールに変更 |
| 加護のしきい値 | ライト45分／ミドル45・90分／ハード45・90・135・180分 |
| 宝箱の中身の原則 | 遊べる量に影響するものを入れない／加護限定アイテムを作らない／差は量だけ |
| 宝箱の受け取り | 拠点画面へ戻ったときにまとめて受け取る |
| **受け取りの報告** | **拠点に着いてからモーダルで出す。** ポモドーロ側で出すと直後の遷移で消える |
| ポモドーロ報酬 | スタミナポーション（作業25分で1個・加護によらず一律）。端数は次回へ持ち越す |
| スタミナ上限 | `max: 100` / 初期`current: 20`。**ポーションで飲んだぶんは上限を超えてよい** |
| 上限を超える経路 | `_add_stamina_uncapped()`。ポーションのみが通る。自然回復や報酬は`add_stamina()`で切り捨てる |
| **ステージのスタミナ** | **勝ったときだけ消費する。** 入場時は残量確認のみ。負けても減らず、リトライも勝つまで無料 |
| 消費量の置き場所 | `Balance.adventure.stamina_cost_per_stage`（`adventure_config.tres`）。仮に5 |
| ステージの解放 | `stage_order.json`の並びで1つ前がクリア済みなら解放。**IDから数字を切り出さない** |
| ステージ数 | 当面3つ。1が面白いと確認できてから増やす |
| 戦闘報酬のexp | 廃止。レベル上げは専用素材消費型のみ |
| `battle_finished`の発火元 | GameManager（`apply_battle_rewards`内）に一本化 |
| `apply_battle_rewards`の範囲 | `gold`と`materials`のみ。`gems`/`stamina`/`inventory`は無視される |
| マスターデータの形式 | **JSON**（`resources/balance/master/*.json`）。`MasterDataLoader`が読む |
| チャージスキルの威力 | 0秒=50%／ジャスト（1.0秒±0.15）=130%／ためすぎ=100%。ためすぎの罰は無い |
| スキル効果の集約先 | `SkillResolver`（静的クラス。Autoloadにしない） |
| **モーダル** | `Modal`（静的クラス）。翻訳キーのみ受け取る。自動で消さない。キューで順に出す |
| **モーダルにしないもの** | 画面内に留める案内（冒険選択のメッセージ）、戦闘の結果画面、セット完了通知 |
| ステージクリアの記録 | `GameManager.mark_stage_cleared()` / `is_stage_cleared()` |
| UIパーツの置き場所 | 2画面以上で使うものだけ`scenes/ui/components/` |
| Theme | `res://theme/main_theme.tres`。戦闘のユニット色・ダメージ数値・チャージゲージ・モーダルの暗幕のみ例外（`ColorRect`にThemeは効かない） |
| ファイル名 | snake_case。`class_name`とノード名はPascalCase。**一般的すぎる`class_name`を避ける** |
| 遷移先が未実装の画面 | `placeholder_screen.tscn`に集約し`screen_id`で出し分け |
| セーブ | `user://saves/save_slot_0.json`、JSON形式 |
| **セーブ削除** | 確認モーダルを挟む。取り返しがつかないため |
| Steam Rich Presence | 仕様は決定済み・実装は後回し。**振り返り内容は絶対に送らない** |
| **レベルアップ素材** | `training_material`。stage_1/2/3の報酬に2/4/6。翻訳キーは`ui_res_ + material_id` |
| **レベルアップのコスト** | `base_level_up_cost=3` / `cost_growth_per_level=1.0`（線形）。レベル10まで1キャラ約63個 |
| **成長・コストの計算式** | **`.tres`に文字列で持ち`Expression`で評価する。** `GrowthFormula`（静的クラス）。壊れた式は警告のみで線形にフォールバック |
| **キャラごとの伸び幅** | `characters.json`の`growth_per_level`。持たないキャラは0として扱う |
| **育成`stats`の中身** | **レベル由来の素の値だけを保存する。** 研究・装備の補正は保存せず`get_effective_stats()`で都度合成 |
| **育成データの初期化** | 遅延。エントリが無ければ`characters.json`から既定値を返し、**保存はしない**。キャラ追加時の移行が不要 |
| **レベル上限** | `base_level_cap`（現在10）＋解放済み`level_cap_unlock`の合計。研究が入っても呼び出し側は変わらない |
| **研究のノード構成** | 縦1列5ノード。上限解放+5を4つ（10→30）、全ステータス+3を1つ。定義は`research.json`。**← 反転。カテゴリ別の一本道ボードを複数周回する形になった**（`GAME_DESIGN.md` 9-1） |
| **研究のコスト素材** | `construction_material`（20/40/70/110、ステータスは30）。`training_material`と分けて素材の取り合いを避ける |
| **上限解放の刻み幅** | **+5。** +10だと1ノードあたり25周相当になり、解放した実感が薄れる |
| **マスターと状態の同期** | 起動時とロード時にマスターデータから流し込み、**進捗フラグだけ既存の値を残す。** JSONの数値を変えると既存セーブにも反映される |
| **研究の解放確認** | **確認モーダルなし。** 条件を満たさないとボタンが押せない方式（育成と同じ）。`Modal.confirm`の追加は後から |
| **ショップの第1弾** | **日替わりのみ・固定ラインナップ5スロット。** 週替わり・月替わりは器だけ。抽選は入れない。**← 4タブになった**（ノルマトークン専用タブが増える。`GAME_DESIGN.md` 9-2） |
| **ショップで売るもの** | `training_material` 10個/300G・30個/800G、`construction_material` 同額、`stamina_potion` 1個/500G。装備の常設ラインナップは未着手 |
| **ショップのリフレッシュ** | ゲーム内日付（`GameDate`・毎朝4:00）が変わったら`purchased_count`を0に戻す。判定は`_ready()` / `load_state()` / **画面を開いたとき**の3箇所 |
| **`refresh_at`の型** | タイムスタンプではなく**ゲーム内日付の文字列**。比較1回で済み、4:00の基準を`GameDate`の外に漏らさない |
| **素材とアイテムの振り分け** | `shop.json`の`payout_type`（`material` / `item`）で分岐。**IDの綴りから推測しない** |
| **`ShopConfig`（`.tres`）** | 抽選用の器。**固定ラインナップでは使わない。** 商品ごとに違う値は`.tres`の単一値で表せないため`shop.json`側に置く |
| **ショップの購入確認** | **確認モーダルなし**（研究と同じ判断）|
| **作業場の第1弾** | **レシピ4つ・キュー1本・キャンセルなし・開始時に素材消費。** 解放条件は付けず全部解放 |
| **作業場が作るもの** | **素材の交換**（建築素材↔育成素材）。**スタミナポーションは作らせない**（戦闘→素材→ポーション→戦闘が閉じ、「働いた分だけ遊べる」が壊れるため）。**← 反転。素材変換と装備製作は廃止。中間素材と装飾のランダム製作になった**（`GAME_DESIGN.md` 9-3） |
| **交換レート** | **必ず1未満。** 30個消費して20個産出。往復で得になるレートを置くと素材が無限に増える |
| **アイテムIDの台帳** | `items.json`。**そのIDが`materials`と`inventory`のどちらに入るかを知っているのはここだけ。** IDの綴りから推測して分岐しない |
| **レシピの定義** | `recipes.json`。`inputs` / `outputs`は**最初から配列**。装備が入っても行を足すだけで作れる |
| **レシピ名の翻訳キー** | **作らない。** 表示は`inputs`/`outputs`から組み立てる（`建築素材 ×30 → 育成素材 ×20`）。レシピを増やしても`ja.csv`を触らない |
| **製作の完了判定** | `started_at + duration_sec`と現在時刻の比較（ポーリング）。**`GameDate`は使わない**（1日の区切り専用） |
| **走行中のキュー** | `duration_sec`は開始時の値で固定。**`outputs`は固定せず受け取り時に引き直す**（調整中にJSONを触る前提） |
| **受け取り後のキュー** | **エントリごと削除する。** `collected`は保存されない（セーブが肥大し、スロットが埋まったままになるため） |
| **残り時間の更新** | `Timer`（1秒）で**ラベルの`text`だけ**差し替える。行の再生成はしない |
| **装備の第1弾** | **武器スロット1つ・装備3種・`atk`加算のみ・作業場で作れる。** 防具/装飾は器のまま |
| **装備の性能データ** | **`items.json`の各エントリに`equip_slot`と`equip_stats`。** `equipment.json`は作らない（`_item_storage()`が既に`items.json`を引いており、性能だけ別ファイルにすると同期の型がもう1枚要る） |
| **`atk_multiplier`** | **触らない。加算のみ。** 加算（+5）と乗算（×1.2）を両方入れない |
| **装備画面** | **独立画面**（`scenes/guild/equipment_screen.tscn`）。育成画面は既に一覧/詳細を抱えているため足さない。`TransferKeys.CHARACTER_ID`で対象を渡す |
| **装備と在庫の整合** | **装備したら在庫から1つ減り、外したら戻る。** 同じ装備を2人に着けたければ2つ作る（第1弾。第2弾で`equipment_instances`へ移行する） |
| **装備の性能の参照** | **状態には`item_id`だけを持ち、性能は毎回`items.json`から引く。** 育成の`stats`・研究の`effect_value`と同じ扱い。代償として**リリース後にアイテムIDを改名しない** |
| **戦闘のステータス参照** | **`get_effective_stats()`を通す。** 生の`stats`を直接読まない（研究と装備が乗らない） |
| **武器のランダム性能** | **入れない。** 同じIDなら基礎性能は同じ。ランダムはルーン（後付けパーツ）にだけ乗せる |
| **スキル枠** | **最初から2枠。** 解放条件を作らない。`characters.json`の`skills`配列がそのまま枠 |
| **ルーンとスキルの紐づき** | **枠の番号に紐づく**（武器=1番目、アクセサリー=2番目）。**スキルを選び直してもルーンは外れない** |
| **装備の個体の持ち物** | **`item_id` / `grade` / `parts` の3つだけ。** 性能値はコピーせず`equip_stats` × 等級係数で毎回計算する |
| **個体の生成場所** | **`add_to_inventory()`の中の1箇所だけ。** 入口が4箇所（宝箱・ショップ・作業場・ポーション付与）あるため、唯一の関所に置く。**新しい入手経路は必ずここを通す** |
| **`inventory`との関係** | **混ぜない。** 装備は`equipment_instances`にだけ入る。装備中の個体も在庫から出し入れせず、そこに残す |
| **部位** | **5部位**（頭 / 上半身 / 下半身 / 武器 / アクセサリー）。内部キーは`armor`のまま（`EQUIP_TORSO`に改名しない） |
| **等級の係数と上限** | **加算。** 基礎値 × `GRADE_STAT_RATIO`(0.25) × (等級-1)。**上限は3**（4〜10のコストは未定）。**← 上限は10になった。加算は据え置き**（`GAME_DESIGN.md` 6-2） |
| **鍛冶** | **装備画面に置く。待ち時間なし・失敗しない・素材だけ。** 作業場のレシピ形式は個体IDを渡せない |
| **枠（宝石・ルーン）** | **器だけ。** `parts: [null, null]`と`get_open_part_slot_count()`（等級5・10で開く計算）のみ。中身は未実装。**← 反転。枠に種類がついた**（宝石・護符・紋章・ルーン・ワイルド）。**開く等級も3/4/5/6/7/8/9/10に変わった**（`GAME_DESIGN.md` 6-4） |
| **重複した装備の変換** | **手動**（倉庫の「素材にする」）。**装備中は不可。** 戻り量は基礎3＋等級を上げるのに払った全額 |
| **第1弾のセーブの装備** | **捨てる。** `_normalize_equipment_from_save()`が個体IDでない値を`null`に戻す。**移行処理は書かない** |
| **EXECにコードを載せない** | 差し替えるコードは**チャット上に出したものが正**。EXECは決定事項・罠・完了条件だけを持つ。同じコードが2箇所にあると、修正時にどちらが正か分からなくなる |
| **`BattleUnit`の形** | **`stats: Dictionary`1本＋`static create()`＋`get_stat()`。** 位置引数は全廃（10個あり、10軸にすると16個になるため）。軸を増やしても`GameManager.get_stat_keys()`に足せば戦闘まで届く |
| **戦闘の式の置き場** | **`scripts/systems/battle_formula.gd`（静的クラス）。** 攻撃間隔・CD・会心抽選・ダメージの4つ。**通常攻撃・スキル・デバッグ表示の3経路が同じ関数を通る** |
| **`BattleFormula`の依存の向き** | **`BattleFormula`は`BattleUnit`を参照しない（引数は数値だけ）。** 相互参照はパースエラー（Cyclic reference）を踏む。**軸の対応付け**（物理→`atk`/`def`、魔法→`mag`/`mdef`）は`BattleUnit.get_power()` / `get_defense()`が持つ |
| **物理／魔法の持たせ方** | **`attack_type`という文字列1本**（`"physical"` / `"magic"`）を`characters.json`・`enemies.json`・`skills.json`に共通で置く。**種別と参照ステータスを連動させる。** 欄を2つ（参照軸と種別）にしない |
| **回復の参照** | **`mag`。** `type == "heal"`は常に`mag`を見る。`skills.json`に`attack_type`を書かない（2つの指定が食い違えるため） |
| **`crit_rate`の超過分** | **捨てる。`crit_dmg`に変換しない。** ％系は`int`で持つため厳密に等価な+0.5%を表現できず、1:1にすると「上限に張り付いたほうが得」になる |
| **ステータス上限の置き場** | **`AdventureConfig`（`Balance.adventure`）。`StatConfig`は作らない。** 新Configは「`.gd` → `.tres` → `Balance`の`@export` → Inspectorで割り当て」の4手が要り、1つ落とすと`null`参照で戦闘が起動しない |
| **`atkspd`の上限** | **秒数の下限で持つ**（`min_attack_interval_sec` = 0.4）。％の上限にしない（速いキャラだけ壊れるため）。`max_haste`と`max_crit_rate`は100 |

### 未決定

| 論点 | 影響先 | 備考 |
|---|---|---|
| 弓兵・僧侶の`growth_per_level` | `characters.json` | 仮の値のまま。剣士8/2/1/1、弓5/2/1/1、僧4/1/1/1 |
| ステージ4〜10のウェーブ構成 | `stages.json` | 1〜3の手触りを確かめてから |
| 星（`stars`）の判定基準 | 同上 | 当面は常に`0` |
| 敵HP・スキル倍率のバランス | — | **10軸と式は入った（2026-08-15）。着手可能。** `def`が除算になったため、いまの数値は全部意味が変わっている |
| スタミナの自然回復 | — | 未実装。やるかどうかも未決 |
| トーストの要否 | — | 自動で消える軽い通知。セット完了通知の受け皿になりうる |
| 入力欄つきダイアログ | — | セッションタイトル入力で要るかもしれない |
| `buff` / `dot` / `projectile`スキル | `PLAN_BATTLE_SCREEN.md` | `SkillResolver`に分岐だけある |
| `projectile`の当たり判定方式 | 同上 | 継続 |
| `resource_changed(STAMINA)`が`max`を含まない | `AGENTS.md` | 既知の制約。`get_state()`から読み直す |
| 通知・演出の方式 | `PLAN_POMODORO_CORE_LOOP.md` | 「宿題」参照 |
| オートセーブの設計 | `PLAN_BASE_SCREEN.md` | 暫定として拠点に`SaveButton` |
| インベントリのドラッグ&ドロップ | `PLAN_GUILD_WAREHOUSE.md` | アイテムが10種類を超えてから |
| ショップの抽選テーブル | `PLAN_GUILD_SHOP.md` | 第2弾。`ShopConfig`の`item_pool` / `daily_slot_count`が器として置いてある |
| レシピの解放条件 | `PLAN_GUILD_WORKSHOP.md` | `recipes_unlocked`の器はある。宝箱の中身にレシピを入れる案が既出。第1弾は全解放 |
| キューの複数本化 | 同上 | `WorkshopConfig.max_queue_slots`で変えられる。解放方法（研究ツリー経由など）が未定 |
| 作業場のポモドーロ連動 | `DATA_SCHEMA.md` 4-5 | 「ポモドーロ進行で素材製作が進む」の詳細ロジック。第1弾から外す想定 |
| `construction_material`の取り合い | — | 研究が使い始めた。作業場・拠点拡張を作るときに競合しないか見直す。専用素材に分けるなら`stages.json`に追加が要る |
| 研究の第2弾（分岐ツリー・追加ノード） | `PLAN_GUILD_RESEARCH.md` | 依存関係のデータは既にある。線を引く実装だけ後から足せる |
| パーティ選択・設定・シナリオの設計 | `SCENES.md` | 第2層ごと無い |
| **鍛冶に待ち時間を入れるか** | 同上 3-1 | 置き場所は装備画面で決定済み。待ち時間を入れるならキューがもう1本要る（個体に`grade_up_at`を足す形で乗る） |
| ~~**ポモドーロのアラーム音**~~ | `PLAN_SOUND.md` | **✅ 完了。** 共通基盤（`SoundManager`）ごと実装した |
| **音量設定・ミュートのUI** | `PLAN_SOUND.md` 8章 | バス3本（Master / SE / BGM）と`SoundConfig`の音量欄は用意済み。**設定画面そのものが第2層ごと無い** |
| **BGM・戦闘SE・UI SE** | 同上 | `play_se()`は動く。**`play_bgm()`は未実装**（ループ・フェード・画面切替時の継続が未設計） |
| **SDキャラとアニメーション** | — | 素材制作を含む。**専用の会話で扱う。仕組みだけ先に作らない** |
| **パッシブ15個の中身** | `characters.json` | 3人×5個（Lv20/40/60/80/100）。**枠組みは決定済み**（`GAME_DESIGN.md` 5-4）。**中身は実装時に埋める作業** |
| **宝石の内部キーの接頭辞** | `items.json` | **`gem`は使えない**（`gems`は通貨として実装済み）。`part_` / `stone_` など。**リリース後に改名できない** |
| **バランスの計算道具を作るか** | `AGENTS.md`のフォルダ構成 | **`balance_report.py`は存在しない**（作りかけて捨てた）。**まず手で実測する方針にしたため後回し。** 作るときは`res://tests/`へ（`tools/`は構成に無く、承認が要る） |
| **宝箱に装備を入れる形** | `ChestContentConfig` | 固定なら`@export`1つ。抽選なら`pity_counters`と同じ規模 |
| **各機能がシナリオの第何章で開くか** | `unlocked_screens` / `scenario_chapter` | **順番は確定**（`GAME_DESIGN.md` 9-5）。**章の割り当てが未定** |
| **魔法型の敵を作るか** | `enemies.json` | **暫定でボス`boss_slime_king`を`attack_type: "magic"`にしてある**（味方の`mdef`が効くことを実機で確かめる敵が他に無かったため）。ボスの火力は`atk` 20 ではなく`mag` 12 を見る。**魔法型の敵を別に作ったら戻すか決める** |
| **敵に会心を持たせるか** | `enemies.json` | **現在は3体とも`crit_rate: 0`。** 乱数で「たまに固い」が起きると除算式の検証が難しくなるため0にした。バランス調整の回で決める |
| **割り振りポイントの点数と軸ごとの効率** | `characters.json` / `character_config` | `hp`に1点で+1なのか+10なのか。**次のタスク（レベルの役割転換）で決める** |
| **`allocatable_stats`の中身** | `characters.json` | キャラごとに振れる軸が違う（`GAME_DESIGN.md` 5-3）。**欄そのものがまだ無い** |
| **等級帯と素材段階の刻み** | — | 装備10等級／装飾5等級を、素材4段階でどう割るか。**境界が等級5をまたぐとスロット解放の節目と混ざる**（`GAME_DESIGN.md` 6-3） |

**運用ルール**：新しい未確定事項が見つかったら、まずこの表に追記する。

> **今回の設計で解決した論点は落とした**（鍛冶屋トークンの入手方法／宝箱の中身の配分／週・月の区切り／作業場が何を作るか／等級4〜10／ルーンの入手経路／スキル候補6個／％系の上限値／素材3段階と等級10段階の噛み合わせ／研究ノードの用意の仕方／等級10で開く枠）。**決定内容は`GAME_DESIGN.md`。**

---

## 過去に実際に起きた事故

| 事故 | 対策 |
|---|---|
| `state_keys.gd`の既存定数が消え、全画面が起動不能に | 定数ファイルは追記のみ。編集後に`read`で確認 |
| `pomodoro_config.tres`が空のまま「値を入れた」と報告され、作業時間0秒に | `.tres`は人間がInspectorで編集 |
| `pomodoro_config.gd`に同じ`@export`が2回追記されパースエラー | 追記前に重複を確認 |
| `ja.csv`が`cat >`で上書きされ既存キーが消失 | `ja.csv`はAIに触らせない |
| `GameDate`がUTC基準で判定し、日本時間では13時が日付の変わり目に | 設計役が自分で書いた |
| 完了条件20項目を15項目に作り直され、検証しにくい項目が落ちた | EXECから項目番号・文言ごと転記させる |
| 実際には動かしていない項目に「検証済み」と書かれた | 「実機未検証と正直に書いてよい」と明示する |
| `class_name`認識エラーを`Node`型キャストで回避された | ルールを緩めて回避しない。エディタ再起動で解決 |
| 完了条件の文言と検証結果が1文にまとめられ、元の条件が読めなくなった | 文言を先に書き、改行してから結果を書かせる |
| 編集先を取り違えたまま「サンドボックスがロールバックする」と誤った原因分析を報告 | `git status`で発見。指示書に無いファイルを作らせない |
| 方法を変えながら6回も書き込みを試み続けた | 「1ファイルへの書き込みが2回失敗したら中止」。方法を変えても回数に数える |
| 完成させようとして止まらなかった | 「未実装と書いてよい」を明記。禁止リストを増やしても別の名前のファイルを作るだけ |
| `battle_controller.gd`が611行に膨張しパースエラーが解消しなくなった | 200行超の既存ファイルは設計役が全文を書く |
| **1つの症状に6通りの手段を試し、切り分けのために本番コードとテストの仕様を書き換えた** | **切り分けは2手まで。本番コードとテストの仕様を変えさせない** |
| **画面を見る種類の完了条件を実装役に渡し、ヘッドレスで再現しようとして破綻した** | **完了条件をA章（実装役）とB章（人間）に分けて書く** |
| **`confirm()`が待つ相手を`_current`から取っていたため、前のモーダルが閉じた瞬間に`false`が返っていた** | 実装役はこれを環境の問題と誤診した。**症状の原因を推測で結論づけさせない** |
| **EXECの人間向け手順に「ログに出ない項目をログで確認しろ」と書いていた** | 設計役のミス。`_ready()`の`print`に`materials`が無いのに確認手段として指定していた。**検証手順は、その出力が実在することを確かめてから書く** |
| **育成画面に同じラベルの「戻る」ボタンが2つ並んだ** | A章（`print`で出る）は全部通り、B章の実機確認で発見。**画面を見る確認を人間が省かないこと** |
| **PLANが「対応済み」と書いていた関数が空実装だった** | `PLAN_GUILD_RESEARCH.md`は`unlock_research_node()`を実装済みと書いていたが、`print`して`false`を返すだけだった。**PLANの「対応済み」を信じない。実コードをgrepで確認してからEXECを書く** |
| **研究の完了条件16項目のうち10項目が、画面の章と重複していた** | 実装役を使わない体制なのに、実装役がいた頃のA章／B章の型を流用した。**完了条件は担当者ではなく「どこを見るか」で分ける**（`AGENTS.md`） |
| **状態にマスターデータの複製を持つ設計で、初期化処理がどこにも無かった** | `research_tree`は`{}`のまま誰も埋めていなかった。画面に1件も出ない状態になる。**「状態に複製を持つ」と決めたら、同期処理をセットで設計する** |
| **戦闘が`get_effective_stats()`を呼んでおらず、研究の効果が効いていなかった** | `NEXT_STEPS.md`は「戦闘側で呼んでいる箇所」と書いていたが、実際には生の`stats`を直接読んでいた。**育成画面には出ているのに戦闘では素の値**という状態が続いていた。装備のタスクで発見・修正（PLANのズレ5回目） |
| **`battle_controller.gd`の差し替えを渡したが当たっておらず、装備が戦闘に反映されなかった** | 「ステータスがバトルだけ反映されない」という症状から`grep`で発見。**差し替えを渡したら`grep`で当たったことを確認する** |
| **`_default_state()`という関数が存在しなかった**（実際は`_empty_state_template()`） | 装備の第2弾で発見。**ドキュメントと実コードのズレ6回目** |
| **`balance_report.py`を「作成済み」と2つのドキュメントに書いたが、リポジトリに存在しなかった** | `*.py`が0件。**チャットの中で書いたものを「作成済み」と記録していた。ファイルとして存在することを確かめてから書く**（ズレ7回目） |
| **`shop.json`の「JSONとして不正（余分なカンマ）」という記録が、実際には既に解消していた** | 直す対象が無いのに宿題として残っていた。**症状を記録したら、解消したときに消すこと** |

---

## 更新履歴
- 初版：第1層完了、第2層（共通基盤・UI共通）完了時点
- 更新：共通基盤・タイトル→拠点・UI共通・拠点画面が完了
- 更新：加護の仕組みを倍率から宝箱スケジュールへ変更
- 全面改訂（引き継ぎ用）：コアループ一周。モデル比較、実測コスト、Git運用、事故一覧を追加
- 全面改訂（戦闘画面の完了時点）：マスターデータのJSON化、200行超の扱い、「止まらないこと」が事故の本質であることを明記
- 更新（育成の完了時点）：レベルアップ実装、計算式の`.tres`外出し、`training_material`の追加。**実装役を使わず設計役が`.gd`を全部書いた最初のタスク**
- **全面改訂（コアループが閉じた時点）**：
  - 冒険選択画面・汎用モーダル・モーダルの適用の完了を反映
  - スタミナを「勝ったときだけ消費する」に決定（敗北で減らない・リトライ無料）
  - モーダルの使い方と「モーダルにしないもの」を決定済み表に追加
  - 実装役に任せてよい範囲を実測で表に整理（新規・JSON・末尾追記まで）
  - 完了条件をA章／B章に分ける方針を追加
  - 次のタスクをギルドの育成に確定
- **更新（研究の完了時点）**：
  - 研究（レベル上限の解放）の完了を反映。素材の出口が2つになり、素材ごとに蛇口と出口が1対1で対応した
  - 研究のノード構成・コスト素材・刻み幅を決定済み表に追加
  - **マスターデータと状態を同期する型**を決定済み表に追加。ショップ・作業場でも同じ形を使う
  - 次のタスクをギルドのショップに確定（ゴールドの唯一の出口）
  - 完了条件の分け方を「担当者（A章／B章）」から「どこを見るか（ログ／ファイル／画面）」へ変更。**実装役を使わないタスクが2回続いたため**
  - 事故一覧に3件追加（PLANの「対応済み」が嘘だった／完了条件の重複／同期処理の欠落）

---

## 更新履歴（このファイル）

- **ショップの完了時点**：
  - 「現在地」にゴールドの出口が開いたことを反映。次のタスクを作業場へ
  - 実装済み表に`EXEC_GUILD_SHOP.md`を追加
  - 「次に何をすべきか」をショップから作業場へ差し替え。実コードを見て確認した3関数の状態と、ショップより難しい2点（リアル時間の判定・毎秒更新する画面）を記載
  - 決定済み表にショップの決定事項8件を追加。未決定表を更新（抽選・週月の区切り・価格・作業場）
- **作業場の完了時点**：
  - 「現在地」に時間の出口が開いたことを反映。次のタスクを装備へ
  - 実装済み表に`EXEC_GUILD_WORKSHOP.md`を追加（**4回連続で事故ゼロ。全項目が一発で通った初めてのタスク**）
  - 「次に何をすべきか」を作業場から装備へ差し替え。装備に必要な6項目を列挙
  - 決定済み表に作業場の決定事項10件を追加。未決定表から「作業場が何を作るのか」を削除し、装備・レシピ解放・キュー本数を追加
  - **`master_data_loader.gd`の正しいパスは`res://scripts/systems/`**（`autoload/`と書いていた誤りを`NEXT_STEPS.md`・`EXEC_GUILD_SHOP.md`から除去）

- **装備の完了時点**：
  - 「現在地」に装備が入って輪が閉じたことを反映。次のタスクをバランス調整へ
  - 実装済み表に`EXEC_GUILD_EQUIPMENT.md`を追加（**5回連続で事故ゼロ**）
  - **EXECにコードを載せない形式に変更。** 差し替えるコードはチャット上に出したものが正
  - 決定済み表に装備の決定事項12件を追加。未決定表から4件（スキル枠の解放条件・`atk_multiplier`・性能データの置き場所・装備画面の置き場所）を削除
  - **キャラ強化ループの全体設計を`PLAN_CHARACTER_GROWTH_LOOP.md`に分離。** 6本の軸・素材の取り合い・等級・ルーンの決定台帳
  - 事故一覧に2件追加（戦闘が`get_effective_stats()`を呼んでいなかった／差し替えが当たっていなかった）
  - 音とアニメーションを「別の会話で扱う」と明記。**ポモドーロのアラームは演出ではなく機能の欠落**

- **装備の第2弾＋検証用削除の完了時点（Claude Codeへ移行）**：
  - 「現在地」に装備が個体になったことを反映。**「渡す物が無い」で止まっていた3つが全部解消**
  - 実装済み表に`EXEC_GUILD_EQUIPMENT_V2.md`（6回連続で事故ゼロ）と「検証用のものの削除」を追加
  - **ステータス9軸が未実装であることを明記。** 装備の第2弾と同じ会話でやる予定だったが装備だけで終わった。`_stat_keys()`は4本（実コードで確認）
  - **`balance_report.py`は存在しない。** 「作成済み」と書かれていた記述を全部訂正し、計算道具は後回しにした
  - 決定済み表に装備の第2弾の決定事項10件を追加。未決定表から3件（鍛冶の置き場所・重複の変換・計算道具の置き場所）を整理
  - 事故一覧に3件追加（`_default_state()`が無かった／存在しないファイルを作成済みと記録した／解消済みの症状が宿題に残っていた）
  - **バランス調整を「9軸より先にやる」ことによる矛盾を明記。** 軸の本数に依存しない数値から直す
- **`gold_per_focus_minute` / `stamina_per_focus_minute` / `materials_per_focus_minute` が3つとも0のまま。** `pomodoro_config.gd` で初期値を書かずに宣言され、`.tres` にも書かれていない。**Inspectorを開いても0が並ぶだけで異常に見えない。** ポモドーロの分あたり報酬が死んでいる
- **`GRADE_STAT_RATIO`（0.25）と`FORGE_COST_PER_GRADE`（4）が`game_manager.gd`の定数のまま。** 数値管理ルール上は`.tres`へ出すべき。**バランスのタスクで判断する**
- **`.tres` は既定値を書き出さない。** 数値を確認するときは必ず `.gd` の `@export` 初期値も見ること。`adventure_config.tres` などは `script = ExtResource(...)` の1行しか無い

- **割り振りポイント＋スキル選択の完了時点（2026-08-15・2回ぶんをまとめて反映）**：
  - 「現在地」をレベルの役割転換2/3に差し替え。**レベルではステータスが伸びなくなったことを明記**
  - 実装済み表に`EXEC_LEVEL_ROLE_SHIFT.md`と`EXEC_SKILL_SELECT.md`を追加（**割り振りぶんは記録が漏れていた**）
  - Git章のコミット表に`7f2deec`と`c44cc79`を追加。**同じメッセージのコミットが2本並ぶため、中身の違いを表に書き分けた**
  - 「次に何をすべきか」をパッシブに差し替え。**その前に`skill_resolver.gd`のテンプレ決めが要ることを明記**（`aoe`は敵全員固定・`heal`は味方全員固定で、単体回復も貫通も書けない）
  - 宿題に7件追加（スキル6件のまま／`F4`の案内文／`current_chapter`が`1.0`／`DATA_SCHEMA.md`のズレ2件／`EXEC_SKILL_SELECT.md` §11-A 1が誤り／旧セーブ正規化が未検証）
  - `GAME_DESIGN.md` 14章から未決4件を削除（割り振りの点数・`allocatable_stats`・`character_growth`の割り振りポイント・`character_growth.skills`）。**スキル12個の内容を未決として追加**
  - `GAME_DESIGN.md` 15章の`select_skill()`と`stat_growth_formula`を実装済みに更新
  - `DATA_SCHEMA.md` 4-3の`skills`を全面改訂。**書かれていたオブジェクト配列は実装されなかった**（実際はIDの文字列配列）
  - `PLAN_IMPLEMENTATION.md` 3章の表に**状態列を新設**（1番✅・2番✅・3番🟡）
  - **事故は0件。** ただし**指示書の誤りが2件**（`GAME_DESIGN.md` 3-2の「スキル1は武器スロット」／`EXEC_SKILL_SELECT.md` §11-A 1のログ）
- **ステータス10軸の後半（式の反映）の完了時点**：
  - 「現在地」を10軸完了に差し替え。**「10軸は入っていない」という記述を全部除去**（4箇所）
  - 実装済み表に`EXEC_STATS_10_AXES_FORMULA.md`を追加
  - 「戦闘画面でできること」に除算式・物理/魔法・会心・デバッグパネルの`J`/`M`を追加
  - **直読み5件が全部解消したことを表に反映**（`attack_interval_sec` / `cooldown_sec` / ダメージ経路2箇所 / 回復の`atk`参照 / `skills.json`の欄）
  - 決定済み表に8件追加（`BattleUnit`の形／式の置き場／依存の向き／`attack_type`／回復は`mag`／`crit_rate`超過は捨てる／上限の置き場／`atkspd`の上限）
  - 未決定表から3件削除（敵の`mag`/`mdef`の設計・`crit_rate`超過分の変換レート・`min_attack_interval_sec`の値）。4件追加（魔法型の敵・敵の会心・割り振りの点数・`allocatable_stats`）
  - **`PLAN_STATS_AND_FORMULAS.md`が実装とズレていることを明記**（3箇所）
  - 次のタスクを「レベルの役割転換」に差し替え。**`stat_growth_formula`を`"base"`にする順番の注意つき**
  - **事故は0件。** 指示書の誤りも0件
- **スキルのテンプレート確定の時点（2026-08-16・コードは1行も触っていない）**：
  - 「次に何をすべきか」の**パッシブの節を完了扱いにし、次を「スキルの器の付け替え（段階1）」に差し替え**。⚠ **パッシブは段階3の後ろに動いた**（条件発動と`buff`/`dot`が要求する層は同一のため）
  - Git章の表に3件追記（`a6a8efd` / `eef8a92` / 今回ぶん）
  - **決定台帳は`docs/01_plan/PLAN_SKILL_TEMPLATE.md`。** このファイルには複製しない
  - **専用セッションを3回、うち2回は別AIとの往復で固めた。** 経緯：3軸で確定 → 別AIがDLC前提を足して6軸に拡張 → こちらで実コードと突き合わせて**4軸＋2層**に訂正
  - ⚠ **別AIの改訂稿に実コードとの誤りが2件あった**（「射程が存在しない」「クリティカルが存在しない」。**どちらも実在する**）。`grep`で訂正済み。**「`grep`済み」と銘打った表ほど、他の章がそれを前提に組み立てる**
  - ⚠ **`GAME_DESIGN.md`に3-4（コンボ）を新設。** 器のPLANにバランス設計が混ざっていたため移設した
  - **事故は0件。** ⚠ **ただし訂正が3件**（介入点の書き方／「乱数を入れるな」が症状レベルのルールだった／貫通%と確定ダメージの棲み分け）
