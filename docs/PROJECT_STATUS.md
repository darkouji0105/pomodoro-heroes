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

**「渡す物が無い」で止まっていた3つ（ショップ・作業場・宝箱）が全部解消した。**

> ⚠ **訂正（2026-08-23）：「宝箱からも装備が出る」は誤りだった。** 宝箱に装備を入れる**器**（`ChestContentConfig.equipment`）はあったが、**4件とも空で実データは0件**。装備が実際に宝箱から出るようになったのは**ステージの抽選ドロップを入れた回**（`EXEC_STAGE_DROPS.md`）。⚠ **`ChestContentConfig` はその後 `chests.json` に置き換わって削除済み**（`EXEC_CHEST_REGISTRY.md`）。

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
| **検証の道具の入れ替え**（⚠ **ゲームの中身は増えていない**） | `EXEC_VERIFY_TOOLING.md` | ✅ 完了（2026-08-18。⚠ **設計役が Godot をヘッドレスで起動できることが実測で判明**。`AGENTS.md` に「誰が取るか」を追記。⚠ **godot MCP は使えないままだが不要**） |
| **デバッグ起動シーンを1個にまとめる** | `EXEC_DEBUG_BOOT.md` | ✅ 完了（2026-08-18。`tests/debug_boot.tscn` / `.gd` 新規。⚠ **本番コードは1行も触っていない**。編成・スキル枠・ステージ・撃つ合図まで自動で走る＝**段階4で溶けた往復6回のうち5回が消えた**） |
| **範囲攻撃（段階4・`mode: area`）** | `EXEC_SKILL_AREA.md` | ✅ 完了（2026-08-18。`origin`（`user` / `target`）を新設、`select_targets()` を `pool_all` / `pool_in` に組み替え。E77〜E80。⚠ **④-a から入っていた `E69` のバグを発見して修正**（下記）） |
| **機能の段階解放**（段階9） | `EXEC_SCREEN_UNLOCK.md` | ✅ 完了（2026-08-24。⚠ **画面IDが8つ増え、⚠ `stages.json` の `unlocks` が引き金**。⚠ **`GAME_DESIGN` 9-5 の10段を4段に畳んだ＝本番ステージが3本しか無いため**。⚠ **E125**。⚠ **画面12項目まで通った。⚠ 装備も育成も閉じた状態で `stage_1` に勝てた**）／ ⚠ **同じ回で「セーブを消しても消えない」を直した**（`reset_to_new_game()`） |
| **ルーン**（段階8） | `EXEC_RUNES.md` | ✅ 完了（2026-08-24。⚠ **`runes.json` 新設＝マスター7本目・25件**。⚠ **バフ／デバフ／回復／シールドは既存の `SkillResolver` → `StatusRegistry` に乗せ、⚠ 移動だけ `battle_controller` が受ける**。⚠ **ステータスを1つも足さない装飾が初めて入った**。⚠ **画面16項目まで通った**） |
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
| `26beb3c` | `feat(balance): 測った数値を入れる（Lv100 が集中 160.9 → 39.9 時間・経験値素材を一本化）`（段階12の後半。4ファイル＋docs。⚠ **`.tres` / `ja.csv` / `.tscn` を1件も触っていない＝人間の Inspector 作業も再インポートも発生しない**。⚠ **`level_up_cost_formula` を線形 `base + growth * (level - 1)` から二次 `... * (level - 1) / 245.0` へ差し替え＝`GAME_DESIGN` 5-2 が名指しで指示していた置き換え。⚠ 効いているのは `.tres` ではなく `character_config.gd` の `@export` 既定値**。⚠ **1キャラ 5,148 → 1,595 個 / 3キャラ 15,444 → 4,785 個。⚠ `stage_2` で 160.9 → 39.9 時間**。⚠ **経験値素材を `training_material_1` に一本化＝`stage_2` x5・`stage_3` x6・ショップ2枠をまとめ買いへ。⚠ `stage_3` の `∞` が消えた**。⚠ **`research.json` を触っていないので `E127` はそのまま。⚠ 赤黄を1本も足していない**。⚠ **`construction_material_4` の入口は人間の決定で触っていない**） | `EXEC_BALANCE_TUNE.md` |
| `52eea88` | `feat(balance): 資源の収支を測る scenario=economy と宿題12の修正`（段階12。3ファイル。⚠ **数値は1つも直していない＝人間の決定「今回は測るだけ」**。⚠ **`.json` / `.tres` / `.csv` / `.tscn` を1件も触っていない**。⚠ **`scenario=economy`（31本目）が素材16件の入口と出口・1周で入るもの・Lv100までの周回数と集中時間・研究の総コストを出す**。⚠ **赤も黄も1本も足していない＝「出口が無い素材」は `print` で名指しするだけ。⚠ 赤にすると30本全部が赤になるため**。⚠ **測った結果：Lv100×3キャラに `training_material_1` が 15,444 個＝`stage_2` を 3,861 周＝集中 160.9 時間 ／ `training_material_2..4` と `decor_material_4` に出口が無い ／ `construction_material_4` の入口が daily ショップだけ（研究55個＝19日＋91,667G）**。⚠ **`load_state()` が `inventory` の `count` を `int()` に戻すようになった＝宿題12。⚠ 壊して確かめ、戻して平常値に戻ることを再実行で確認**） | `EXEC_BALANCE_ECONOMY.md` |
| `7c47b5f` | `feat(workshop): 作業場を装飾のランダム製作で復活・研究に作業場枝2件`（段階11の後半。14ファイル。⚠ **`recipes.json` 0件 → 3件。⚠ レシピに `draw`（抽選）の欄を足した＝出るものが固定でないレシピが初めて入った**。⚠ **抽選の本体を `_roll_weighted_table()` に切り出し、`_roll_chest_draw()`（宝箱枝のボーナスが乗る）と `_roll_recipe_draw()`（乗らない）の2本から呼ぶ**。⚠ **装飾36件だけ。ルーン25件はくじに入れていない**。⚠ **研究ボード2に `category: "workshop"` の2件＝18 → 20ノード。`level_cap_unlock` は増えないので `E127` は不変**。⚠ **`stage_3` の `unlocks` に `workshop`＝ギルドのボタンが5個から6個に戻った**。`E129`（`recipes.json` の `draw` の形）・`E118` に `draw.entries` の枝・`scenario=workshop`（30本目）・`LAYOUT_SCENES` に作業場。⚠ **`LAYOUT_SCENE_SHOW` にギルドの5ボタンを足した＝それまで `72 x 72` しか測れていなかった**。⚠ **`workshop_screen.tscn` の `MaterialLabel` が横に +344 はみ出していたのを `layout` が見つけて直した**。⚠ **中間素材（研究用素材）は入れていない＝5系統目の素材が要るため人間が見送った＝宿題36**） | `EXEC_WORKSHOP_REVIVE.md` |
| `f53e097` | `feat(research): 研究ボードを2ボード18ノードに作り替え・上限は8件×+10で100`（段階10。11ファイル。⚠ **枝は「戦闘」と「宝箱」＝`GAME_DESIGN` 9-1 のカテゴリ名を採り、`NEXT_STEPS` の推奨（戦闘/生産/探索）を採らなかった**。⚠ **ボードは1周クリアで切り替わる。`board` / `category` / `milestone` はマスターの欄で持ち、状態にはキーを1つも足していない**（「今のボード」は `get_current_research_board()` が都度計算＝セーブの移行が不要）。⚠ **レベル上限は 8件 × +10 で `base_level_cap` 20 と合わせてちょうど 100。既存セーブは `res_cap_1..4` 解放済みのため実効上限が一時的に 100 → 60 に下がる（解放状態は失われない）**。新しい `effect_type` は `chest_draw_bonus` の1つだけ・`E127`（上限の合計）・`E128`（前提とボードの整合）・`scenario=research`・`LAYOUT_SCENES` に研究画面・F4 の解放パス数をノード数基準に。⚠ **ゴールド払いと作業場枝は入れていない＝宿題34・35**） | `EXEC_GUILD_RESEARCH_V2.md` |
| `4130c8f` | `feat(passives): 本番キャラのパッシブ15件・レベル上限100・育成画面を2カラム`（段階3の残り。17ファイル。新規は `characters/<id>/passives.json` 3本＝**キャラのフォルダが3本目**。⚠ **パッシブは「選ぶ」のをやめ、解放されたものが全部効く＝`GAME_DESIGN` 5-2 / 5-4 に実装を寄せた（ズレ32）**。⚠ **`passives.json` は `_cache_skills` へマージ＝引き口は `get_skill()` の1本のまま**。⚠ **`react` が本番に初めて2件入った**（`passive_sw_thorn_mail` / `passive_ar_follow_through`）。⚠ **レベル上限 30 → 100**（`base_level_cap` 20 ＋ 研究4件 × 20＝ズレ33）。`get_battle_passives()` を枠を通さない形に・`_merge_character_files()` を切り出し・E126・`ja.csv` 480→514行・`debug_boot` に `passives` シナリオ。⚠ **育成画面の `DetailPanel` を `VBoxContainer` → `HBoxContainer`（2カラム）＝人間が実機で見つけた縦のはみ出し**。⚠ **`scenario=layout` が6シーンとも最小幅0を返していたのを修正（ズレ36）**） | `EXEC_CHARACTER_PASSIVES.md` |
| `2831c1a` | `fix(save): 「最初から」で状態を作り直す（セーブを消しても消えなかった穴）`（⚠ **人間が実機で発見**。`GameManager.reset_to_new_game()` 新設・`_ready()` の中身を `_build_new_game_state()` に切り出し・`title_screen` の新規開始の枝から呼ぶ。⚠ **`initial_state_config.tres` の `initially_unlocked_screens` を3件にしたのは人間**） | `EXEC_SCREEN_UNLOCK.md` §13 |
| `ead4a6d` | `feat(unlock): ステージのクリアで機能を段階解放（画面ID8つ＋stages.json の unlocks）`（段階9。10ファイル。⚠ **`state_keys` に画面IDを8つ**（`equipment`/`training`/`warehouse`/`research`/`shop`/`workshop` ＋ 機能IDの `decoration`/`rune`）。⚠ **引き金は `stages.json` の `unlocks`＝`.gd` に表を書かない**。`_sync_unlocked_screens_from_master()` / `get_all_screen_ids()` / `is_part_kind_unlocked()` を新設・E125・`F4` に「画面を全部解放」・`debug_boot` に `unlock` シナリオ） | `EXEC_SCREEN_UNLOCK.md` |
| `341d317` | `feat(runes): ルーン25件・スキルの直前に発動・移動量をキャラプリセットへ`（段階8。14ファイル。新規は `resources/balance/master/runes.json`＝**マスター7本目**。⚠ **ルーンは `SkillRuntime.cast()` をそのまま通す＝効果の種類を1つも増やしていない**。⚠ **移動だけ `battle_controller._fire_runes()` が受け、`rune_move_lock_sec` で自動移動を止める**。`merge_runes()` / `set_rune_move()` / `get_battle_runes()` を新設・`items.json` 64→89件・`ja.csv` 446→480行・E123 / E124・`debug_boot` に `runes` シナリオ） | `EXEC_RUNES.md` |
| `a58c8e4` | `feat(party): パーティ選択画面と2階層のプリセット`（段階7。新規は `scenes/adventure/party_preset_screen.gd` / `.tscn`。⚠ **`GAME_DESIGN` 5-5 の2階層・参照方式**。`character_presets` / `party_presets` を新設・`get_equip_reject_reason()` を切り出し・`_collect_party_candidates()` を `GameManager.get_party_candidates()` へ移動・`debug_boot` に `presets` シナリオ。⚠ **E/W は増やしていない**。⚠ **マスターデータを1件も触っていない**） | `EXEC_PARTY_PRESETS.md` |
| `128f25d` | `feat(battle): 召喚（spawn）を足し、専用配列と座標の規則を入れる`（段階6。18ファイル。新規は `resources/balance/master/summons.json` と `docs/02_exec/EXEC_SKILL_SPAWN.md`。`type: "summon"` を実装・`host: "spawn"` を赤に格上げ・`BattleSession.summon_units` と `find_unit()` 新設・E93〜E101 / W13） | `EXEC_SKILL_SPAWN.md` |
| `9df9546` | `feat(battle): 段（phases）と再発動（recast）を足し、構え中はCDを見ないようにする`（段階5。`phase_of()` / `phase_count()` 新設・`BattleUnit.recast_pending`・`BattleLog.log_recast()`・E81〜E92・`debug_boot` の `fire` に `gap` 欄） | `EXEC_SKILL_RECAST.md` |
| `ec386f7` | `test(verify): 操作のいらないデバッグ起動シーンを1個作り、検証をヘッドレスへ移す`（9ファイル。新規は `tests/debug_boot.tscn` / `.gd`。⚠ **本番コードは1行も触っていない**。⚠ **設計役が Godot をヘッドレスで起動できることが実測で判明し、`AGENTS.md` に「誰が取るか」を追記・`CLAUDE.md` の「起動できない」を修正**）⚠ **ブランチ `feat/debug-boot-verify-tooling` に切ってある** | `EXEC_VERIFY_TOOLING.md` / `EXEC_DEBUG_BOOT.md` |
| `a0433de` | `範囲スキル等`（段階4＝`mode: area`。⚠ **メッセージが型に沿っていない**。`origin` 新設・`select_targets()` の組み替え・E77〜E80・検証用データ一式） | `EXEC_SKILL_AREA.md` |
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
- ~~拠点下部のレイアウト調整（`ResourceRow`の`separation`、左端の見切れ）~~ **✅ 完了**（2026-08-23）。⚠ **原因は`separation`ではなく素材欄だった。** 素材16件・4桁で`MaterialsDisplay`の最小幅が564になり、`ResourceRow`全体が**1556**（画面幅1280）まで膨らんで下段が丸ごと左右にはみ出していた。⚠ **素材欄を`ResourceRow`から出して`ScrollContainer`（8列2段）に入れた**ので、最小幅が0になり**素材が増えても桁が増えても再発しない**。⚠ **数字は`-- scenario=layout`で取れる**
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

### 作業場の廃止で足した宿題（2026-08-23・`EXEC_WORKSHOP_RETIRE.md`）

- ~~⚠ **作業場が空のまま残っている**~~ ✅ **復活した**（2026-08-25・`EXEC_WORKSHOP_REVIVE`。⚠ **装飾のランダム製作3レシピ・`stage_3` で解放**）
- ⚠ **素材の変換経路が消えた。** `GAME_DESIGN` 9-3 は「ショップに一本化」と書いているが、**`shop.json` に変換に相当する枠があるかは未確認。** 段階12（バランス実測）の前に見ること
- ⚠ **`_sync_recipes_from_master()` の「読めない」保険が `MasterDataLoader` 側の赤だけのまま**（早期 return を外したため。`EXEC_WORKSHOP_RETIRE.md` 決め1）。⚠ **レシピが3件になったので0件に戻れば異常だと分かるが、⚠ それを見る検証は足していない**
- ~~⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用のまま残っている**~~ ✅ **解消**（2026-08-25。`GUILD_SCENES` に戻した）

### 作業場の復活で足した宿題（2026-08-25・`EXEC_WORKSHOP_REVIVE.md`）

36. ⚠ **`GAME_DESIGN` 9-3 の「中間素材の製作」が入っていない。** ⚠ **`GAME_DESIGN.md:84` の資源表は「研究用素材 ← 作業場（中間素材として製作）／→ 研究ボードの解放」と書いているが、⚠ これは5系統目の素材を必要とし、「素材IDは `<系統>_material_<1..4>` で固定・新しい素材を作らない」と正面から食い違う。⚠ 人間が「装飾のくじだけ」を選んだ**（2026-08-25）。⚠ **段階12で `construction_material_4` の入手量を測ってから、⚠ 新設するか研究のコストを組み替えるかを決める**
37. ⚠ **`decor_material_4` を使うレシピが無い**（月替わりショップだけの入手のため、段階12の後に判断する）
38. ⚠ **くじの数値が全部「勘」**（投入12個・30分/90分/3時間・重み 10/3/2）→ ⚠ **宿題22に合流**
39. ⚠ **`crafting_queue` の `output_item_id` / `recipe_type` が `draw` レシピでは `""` になる。** ⚠ **どちらも誰も読んでいない欄。⚠ 次にセーブの形を触る回で消すか判断する**
40. ⚠ **作業場のアップグレード（`GAME_DESIGN` 9-3「建築素材で作業場自体をアップグレード」）が無い。** ⚠ **キュー本数は研究の枝で伸ばす形にした**
41. ⚠ **掘削（`GAME_DESIGN` 9-3-1）はデモ範囲外のまま**
42. ⚠ **ズレ38**：⚠ **`GAME_DESIGN` 9-1 の作業場カテゴリに「変換レート」が残っている。⚠ 同じファイルの 9-3 と 2章が「変換は廃止」と書いており、上げるレートが存在しない**（⚠ **勝手に直していない**）
43. ~~⚠ **`load_state()` が `inventory` の `count` を `int()` に戻していない。** ⚠ **`materials` / `character_growth` / `crafting_queue` / `equipment_instances` は戻しているのに、⚠ ここだけ素通り**（`game_manager.gd:5331` 付近）。⚠ **セーブに `"count": 5.0` と書かれる**（⚠ **2026-08-25に実セーブで確認。⚠ 装飾36件のうち33件**）。⚠ **表示と判定は壊れない**（⚠ **`get_item_count()` / `_remove_from_inventory()` / `use_stamina_potion()` は全部 `int()` を通している。⚠ 一度でも増減すると int に戻る**）。⚠ **`CLAUDE.md` 3番の症状**~~ ✅ **直した**（2026-08-25・`52eea88`・段階12の回。⚠ **`materials` の隣に同じ形で4行。⚠ `count` だけ直し、`type` / `slot_position` / `properties` は触っていない**。⚠ **`scenario=economy` の末尾に検証の枝がある＝`load_state()` に `count: 5.0` を直接渡して型を見る**）
- ⚠ **`scenario=workshop` は赤が2本出るのが正解**（⚠ **`E129` をわざと2箇所で出している。⚠ `unlock` が1本出すのと同じ形**）
- ~~⚠ **`AGENTS.md`「GameManagerの状態構造」の `PENDING_CHESTS` の行が実装と違う**（ズレ26）~~ ✅ **直した**（2026-08-23・`EXEC_PARTY_PRESETS` の回。⚠ **`PARTY_MEMBERS` / `CHARACTER_PRESETS` / `PARTY_PRESETS` の3行も足した**）

### バランス実測の回で足した宿題（2026-08-25・`EXEC_BALANCE_ECONOMY.md`）

44. ⚠ **測った結果を数値に反映していない**（⚠ **人間の決定「今回は測るだけ」**）。⚠ **直す値の一覧は `EXEC_BALANCE_ECONOMY.md` §9-3。⚠ (a) 人間しか入れられない4件 ／ (b) 次の回に設計役が入れられる10件 ／ (c) 器の変更が要る3件 に分けてある**
45. ~~⚠ **Lv100 が遠すぎる**（⚠ **3キャラで `training_material_1` が 15,444 個＝`stage_2` を 3,861 周＝スタミナ 19,305＝集中 160.9 時間**）~~ ✅ **直した**（2026-08-25・`26beb3c`・`EXEC_BALANCE_TUNE`。⚠ **`character_config.tres` は触っていない。⚠ 直したのは `.gd` の `level_up_cost_formula` の既定値＝線形から二次へ**。⚠ **1キャラ 1,595 個 / 3キャラ 4,785 個＝`stage_2` で 39.9 時間・`stage_3` で 33.3 時間**）
46. ~~⚠ **`training_material_2` / `_3` / `_4` に出口が1つも無い**~~ ⚠ **人間の決定で「`training_material_1` に一本化」した**（2026-08-25・`26beb3c`）。⚠ **`stage_3` の `∞`（このステージでは上がらない）は消えた**。⚠ **代わりに `_2..4` は入口も出口も無くなった＝宿題52へ引き継ぐ**
47. ⚠ **`decor_material_4` に出口が1つも無い**（⚠ **装飾の段階が4止まり＝`max_part_tier`。⚠ 作業場のレシピも `_1..3` だけ**）。⚠ **`GAME_DESIGN` 111行は「装飾 等級1〜5」と言っているが、⚠ `max_part_tier` を5にすると `game_manager.gd:2503` が段階5の装飾アイテム（`part_*_5` 36件）を `items.json` に要求する＝数値ではなくコンテンツ追加になる**（2026-08-25に確認）
	- ⚠ **人間の決定（2026-08-25）：⚠ やるときは `max_part_tier` を **5** にする**（⚠ **作業場に4本目のレシピを足す案は採らない**）。⚠ **ただしこの回ではやらない**
	- ⚠ **「36件」は誤り＝ズレ40。⚠ 非ルーンの装飾は **9通り × 4段階 = 36件**（宝石3・護符2・紋章4）なので、⚠ 段階5で増えるのは **9件**（`ja.csv` も9行）。⚠ `part_config.tres` は `script = ...` の1行だけ＝**上限も配列2本も設計役が直せる**（⚠ `part_config.gd:35` のコメント自身が手順を書いている）
	- ⚠ **出口の本体は作業場ではなく段階上げ。⚠ `decor_material_4` を払う場面は「段階4→5」しか設計上存在しない**（`part_config.gd:47` ／ `game_manager.gd:2550`）
48. ⚠ **`construction_material_4` の入口が daily ショップだけ**（⚠ **x3 を 5000G・在庫1。⚠ 研究が 55 個要求＝19日＋91,667G。⚠ `stage_3` は 120 G/周なので 764 周ぶんのゴールド**）
49. ⚠ **`GAME_DESIGN` 4-1 の「周回ステージ（素材系／装飾系）」と「スキップ周回」が実装に1件も無い**（⚠ **`stages.json` はシナリオ3本だけ**）。⚠ **段階12 は「作らない・測るだけ」にしたので未決のまま**
50. ⚠ **①「戦闘が何秒で終わるか」を測っていない**（⚠ **人間の決定で後回し。⚠ `def` が除算式になった影響はまだ数字で見ていない**）／ ⚠ **装飾の出目72個とルーンの効果量20個も未測**
51. ⚠ **ズレ39**：⚠ **`NEXT_STEPS` §1-1 / §3 の「数値は `.tres`（設計役は直せない）」が半分しか当たっていない。⚠ 13本の `.tres` のうち値の行を持つのは6本で、⚠ `adventure` / `equipment` / `part` / `research` / `shop` / `workshop` の6本は `script = ...` の1行だけ＝効いているのは `.gd` の `@export` 既定値**（⚠ **`equipment_config.gd` と `part_config.gd` のコメント自身がそう書いている**）。⚠ **同じズレで「`_4` は月替わりショップだけ」も違う。⚠ `shop.json` に `weekly` / `monthly` のキーが無く `daily` しかない**（⚠ **勝手に直していない**）

### バランス調整の回で足した宿題（2026-08-25・`EXEC_BALANCE_TUNE.md`）

52. ⚠ **`training_material_2` / `_3` / `_4` が入口も出口も無い状態になった**（⚠ **一本化の代償。⚠ `items.json` に定義だけが残っている**）。⚠ **`scenario=economy` の `⚠ 入口が0件のもの` が **0件 → 3件** に変わった＝これが新しい平常値**。⚠ **IDを消していないのは、⚠ 「レベル帯で要求素材を変える」器を将来入れる余地を残すため**
53. ⚠ **`shop.json` の `slot_id` 12 が `decor_material_4` を 5000G で売っているが、⚠ この素材には出口が無い**（宿題47の裏側）。⚠ **買うと死に資源になる。⚠ 出口を作るか枠を替えるかは未決**
54. ⚠ **`scenario=drops` は `chests.json` しか見ておらず、⚠ `stages.json` の固定報酬を読んでいない**（2026-08-25に確認）。⚠ **ステージの固定報酬が変わったことを見る道具は `scenario=economy` の「1周で入るもの」の行だけ**
55. ⚠ **`economy` の `⚠ Lv1 の突き合わせ` は式の差し替えを検出できない**（⚠ **Lv1 は線形でも二次でも 3 個になるため**）。⚠ **「Lv50 の突き合わせ」を1行足すと効くようになる（足していない）**
56. ⚠ **鍛冶・装飾・宝箱・ショップ価格の「勘の数値」（宿題24〜30）は今回も動かしていない**（⚠ **`economy` が前後を出せる対象ではないため。⚠ 測る道具そのものが無い＝宿題50**）

### 通しで遊ぶ回で足した宿題（2026-08-25・`EXEC_PLAYTHROUGH.md`）

57. ⚠ **`load_state()` の `int()` 一覧に `STORY` が無い。⚠ セーブに `"current_chapter": 1.0` と `"stars": 0.0`（3ステージぶん）が残る**（2026-08-25に実測）。⚠ **実害はセーブの形だけ**（⚠ **`stars` は書くとき `game_manager.gd:5476` が `int()` を通すのでクリアし直せば戻る。⚠ `current_chapter` は初期化以外で誰も読まない**）。⚠ **`CLAUDE.md` #3 と同じ形なので、⚠ 放っておくと次に踏む**
58. ⚠ **`stage_2` をクリアするまでスタミナの入口が1つも無い**（⚠ **ポモドーロが開くのが `stage_2` のクリアのため**）。⚠ **初期スタミナ 20 ＝ **4周**で `stage_1` と `stage_2` を抜ける必要がある**（⚠ **負けた周は `refund_stamina` で戻るので、⚠ 減るのは勝った周だけ**）。⚠ **通しで本当に詰まるかは `EXEC_PLAYTHROUGH` §5-C の C-2〜C-4 で観測する**

⚠ **⑫-c（残った穴の器）は人間の決定で見送り**（2026-08-25）。⚠ **`decor_material_4` の出口＝宿題47 ／ `training_material_2..4`＝宿題52 ／ `slot_id` 12＝宿題53 のまま残す。**
⚠ **ルーンの入口（宿題9）・戦闘結果の宝箱表示（宿題23）・周回とスキップ（宿題49）も、⚠ 同じ日に人間が「やらない」と決めた。**
⚠ **ただし宿題49 は同じ日のうちに覆った**（⚠ **下の「シナリオの作り替えを決める回」を見ること**）。

### シナリオの作り替えを決める回で足した宿題（2026-08-25・`PLAN_SCENARIO_MAP.md` / `PLAN_RESOURCE_FLOW.md`）

⚠ **この回はコードを1行も書いていない。⚠ 実コードを `grep` して見つけたものだけ。**

59. ⚠ **ジェムに本番の入口も出口も1つも無い**（⚠ **`PLAN_RESOURCE_FLOW.md` §3**）。⚠ **`open_chest()` は `gems` を読む枝を持つが `chests.json` に `gems` を持つエントリが0件。⚠ `_spend_currency()` は `gems` を扱えるが `shop.json` の13枠は全部 `"currency_type": "gold"`。⚠ `apply_battle_rewards()` も `apply_pomodoro_rewards()` も `gems` を読まない。⚠ つまり `F4` 以外で1つも増えず、⚠ 増やしても使い道が1つも無い**
60. ⚠ **`apply_pomodoro_rewards({})` が空の Dictionary で呼ばれている**（`pomodoro.gd:259`）。⚠ **関数側は `gold` / `stamina` / `materials` を読む枝を全部持っているのに、⚠ 渡されるものが空なので1つも通らない。⚠ ポモドーロが実際に配っているのはポーション（`grant_stamina_potions()`）と加護の宝箱（`claim_pending_chests()`）だけ**。⚠ **宿題32「`pomodoro_config.gd` の `gold_per_focus_minute` / `stamina_per_focus_minute` / `materials_per_focus_minute` が誰も読まない欄」の正体がこれ**
61. ⚠ **ゴールドの入口がステージの固定報酬1本・出口がショップ1本しかない**（⚠ **`PLAN_RESOURCE_FLOW.md` §2**）。⚠ **`open_chest()` は `gold` を読むが `chests.json` に `gold` を持つエントリが0件。⚠ 研究にゴールド払いが無い（宿題21）・鍛冶も装飾も作業場も素材払い**

⚠ **宿題49（周回ステージ・スキップ周回）は「やらない」から「やる」へ戻った。** ⚠ **`DISCUSSION_scenario_map.md` の前提「周回は瞬時にスキップし結果だけ受け取る」を採用したため**（⚠ **`PLAN_SCENARIO_MAP.md` §1-1**）。
⚠ **宿題23（戦闘結果に宝箱が出ない）は、⚠ シナリオの作り替えで「マップ上に出る」に吸収される見込み**（⚠ **`PLAN_SCENARIO_MAP.md` §4-2 の5**）。
⚠ **宿題58（`stage_2` までスタミナの入口が無い）は、⚠ ポモドーロをフロア1へ前倒しする決定で閉じる見込み**（⚠ **`PLAN_SCENARIO_MAP.md` §8**）。

### 段階14 の実装で足した宿題（2026-08-25）

62. ⚠ **ホバーで説明が出る共有部品が無い**（⚠ **人間の要望・2026-08-25**）。⚠ **`scenes/ui/components/` に置く「マウスを乗せたら説明が出る」部品を作る。⚠ レリック専用にしないこと（2画面以上で使い回すものは `components/`＝`AGENTS.md`）**
	- ⚠ **最初に効くのはレリックの選択画面**（⚠ **いま名前と「3人全員／1人だけ」しか出ず、⚠ 何が起きるか分からないまま選ぶことになる＝`EXEC_SCENARIO_RELIC.md` §5 の申し送り5**）
	- ⚠ **同じ穴が他にもある**：⚠ **研究のノード／装飾の効果／スキルの候補／ショップの商品。⚠ どれも「名前だけ出ていて中身が分からない」**
	- ⚠ **説明文をどこに持つかも一緒に決める**（⚠ **`relics.json` に欄を足すのか、⚠ `ja.csv` に `ui_<id>_desc` の規則で置くのか。⚠ 後者なら器を増やさずに済む**）
	- ⚠ **段階14 の中ではやらない**（人間の指示「後で作ったほうがいい」）

### 機能の段階解放の回で足した宿題（2026-08-24・`EXEC_SCREEN_UNLOCK.md`）

- ⚠ **「セーブを消しても消えない」を直した**（⚠ **人間が実機で発見**）。⚠ **`GameManager._state` を作るのは `_ready()` と `load_state()` の2箇所だけで、⚠ リセットする口が無かった。⚠ `reset_to_new_game()` を新設し、⚠ タイトルの「新規開始」の枝から呼ぶようにした**（`EXEC_SCREEN_UNLOCK` §13）
  - ⚠ **「新規開始か」を決めているのは `title_screen._on_start_pressed()` の1箇所だけ。⚠ 2本目を作らないこと**
  - ⚠ **オートセーブが入ると、この枝の意味が変わる**（⚠ **いまは `SaveButton` を押したときだけ保存される**）

- ⚠ **どのステージで何が開くかが「勘」。** ⚠ **本番ステージが `stage_1` / `stage_2` / `stage_3` の3本しか無く、⚠ 引き金が4つ（「最初から」込み）しか作れないので、⚠ `GAME_DESIGN` 9-5 の10段を4段に畳んである**（`EXEC_SCREEN_UNLOCK` §2）。⚠ **ステージが増えたら `stages.json` の `unlocks` を分けるだけで刻める**
- ⚠ **9-5 の「拠点」（#8）の置き場が無い。** ⚠ **`base_screen` はハブなので閉じられない。⚠ `GAME_DESIGN` 10章の建設画面がまだ無い**
- ~~⚠ **作業場が2箇所で閉じている**~~ ✅ **両方戻した**（2026-08-25・`EXEC_WORKSHOP_REVIVE`。⚠ **`.tscn` の `visible = false` を消し、⚠ `stage_3` の `unlocks` に足した。⚠ 閉じ方は `_refresh_unlocked()` の1箇所だけになった**）
- ⚠ **`F4` の「画面を全部解放」はリリース前に消す**（⚠ **宿題32の一覧に入る**）
- ⚠ **`settings` と `scenario` が `placeholder_screen` のまま。** ⚠ **中身が無いので閉じても開けても見えるものが変わらず、最初から開けてある**
- ⚠ **ズレ29 と ズレ30 を `GAME_DESIGN` 9-5 に反映していない**（⚠ **勝手に直していない。`EXEC_SCREEN_UNLOCK` §11**）
  - ⚠ **ズレ29**：⚠ **9-5 は「装備 → 育成」の順だが、⚠ 装備画面へは育成画面からしか入れない。⚠ 決定4 で「同時に開く」にした**
  - ⚠ **ズレ30**：⚠ **9-5 の10段のうち画面として閉じられるのは6つだけ。⚠ 装飾（#5）とルーン（#10）は装備画面の中の行 ／ 拠点（#8）はハブ ／ 倉庫はどの段にも無い**
- ⚠ **`scenario=unlock` は赤が1本出るのが正解**（⚠ **`E125` をわざと出している。⚠ `drops` が黄を1本多く出すのと同じ形**）

### ルーンの回で足した宿題（2026-08-24・`EXEC_RUNES.md`）

- ⚠ **マスターファイルが7本目になった**（`runes.json`）。⚠ **6本目（`chests.json`）の判断が未了のまま増えた**
- ⚠ **ルーンのかけらが無い。** ⚠ **段階5で重ねようとすると `ui_part_reject_rune_max` で止まる**（`GAME_DESIGN` 7-7 は「超えた分はかけらになる」）。⚠ **そのためルーンは倉庫で「壊す」も出さない**（⚠ **装飾素材に戻すと `decor_material_5` という存在しないIDが要る**）
- ⚠ **ルーンの本番入手経路が無い。** ⚠ **`F4` の「装飾を全種類」だけ**（⚠ **7-7 の「ポモドーロ報酬のレアな枠」は未実装。⚠ `chests.json` のポモドーロ4件は固定報酬で抽選が無い**）
- ⚠ **ルーンの数値が全部「勘」**（⚠ **CD 5個 ／ 効果量 20個 ／ 移動距離 16個 ／ `rune_move_lock_sec` ／ `rune_merge_count`**）
- ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない**（⚠ **スキルのボタンにはゲージが在る**）
- ⚠ **`scenario=parts` は黄が1本多く出るのが正解**（⚠ **刺さっているルーンのIDをわざと壊して `W18` を出している**）

### パーティ選択画面とプリセットの回で足した宿題（2026-08-23・`EXEC_PARTY_PRESETS.md`）

- ⚠ **`PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**（`game_manager.gd`）。⚠ **いまは `true`＝`GAME_DESIGN` 5-5 と一致**。⚠ **2026-08-23の1セッションで2回動いた欄なので残してある**（「いったんやめる」で `false` → 「装備にも適用がいる」で `true`）。⚠ **落ち着いたら定数ごと消してよい**
  - ⚠ **`false` のあいだに焼いたビルドは `equipment` が5部位とも `null` で残る。⚠ それを適用すると裸になる。⚠ 焼き直しが要る**（⚠ **「装備を焼かなかった」と「何も装備していない」を区別する術が無く、コード側では直せない**）
- ⚠ **`[ビルドN ▼][焼く][適用]` の行が育成と装備の2画面に重複している**（各30行）。⚠ **`AGENTS.md`「2画面以上で使い回すパーツは `components/`」から外れている。** ⚠ **切り出さなかったのは、新しい `class_name` が `.godot/global_script_class_cache.cfg` に載らず、人間がエディタを1回通すまでヘッドレスで検証できないため**（`NEXT_STEPS` §4）。⚠ **判定と文面は `GameManager` に1本化済み。⚠ 次にエディタを通したあと `scripts/components/build_preset_row.gd` へ切り出すこと**
- ⚠ **プリセットに名前を付けられない**（`編成1` / `ビルド1` の自動名）。文字入力欄を足すと翻訳・保存・文字数制限が付いてくるので落とした（`EXEC_PARTY_PRESETS` §13 の 2）
- ⚠ **キャラプリセットを消せない**（上書きだけ）。消せると編成プリセットの参照だけが宙に浮くため（同 §13 の 7）
- ⚠ **ルーンの移動量の欄が空。** 段階8でキャラプリセットに5つ目のキーとして入る。⚠ **正規化は知らないキーを消さない**（消すと後から足した欄が黙って落ちる）
- ⚠ **`party_changed` シグナルをまだ足していない。** 編成を聞く画面が3つ目になったら足す（そのとき `AGENTS.md` のシグナル表にも1行）
- ⚠ **`CLAUDE.md` 4番の「リリース後に改名できないID」に、プリセット経由で `character_id` / ノードID / スキルID / パッシブID が加わった**（改名するとそのプリセットの該当部分が黙って落ちる）
- ⚠ **宿題16（リリース前に消すもの）の行き先が変わった。** `adventure_select._build_party_row()` の `OS.is_debug_build()` 分岐 → ⚠ **`GameManager.get_party_candidates()` の分岐**（2画面が要るようになったので移した）
- ⚠ **`equip_instance()` の失敗ログの文言が変わった**（`get_equip_reject_reason()` に切り出した。理由の中身は同じ）
- ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（外のキャラから奪うときだけ出す。`EXEC_PARTY_PRESETS` §13 の 11）

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

### ダメージ数値の色分けの回で見つかったもの（2026-08-17・`408acfe`）

- **戦闘の数値ポップの色は `Balance.adventure`（`AdventureConfig`）で持っている**（`adventure_config.gd:82-106` の12欄）。`main_theme.tres` ではない。⚠ **`AGENTS.md`「個別シーンで色を直接指定しない」の対象外という整理**（あの条文の対象は Control の基本スタイルで、狙いは「Theme 1箇所で全画面が変わる」こと。ここで要るのは「毒＝この色」という意味の対応表）。**`AGENTS.md` 側に1行足すかは人間の判断**
- ⚠ **`unit_view.gd` の `COLOR_PARTY` / `COLOR_ENEMY` / `COLOR_BOSS`（体の色）だけ定数のまま残っている。** 色の置き場所が2箇所ある状態。**Inspector から体の色も触りたくなったら `AdventureConfig` に移す**
- ⚠ **`NEXT_STEPS.md` §2-4「回復の数字は別経路」は誤りだった。** 回復も `_on_skill_effects_applied` → `_pop_damage` を通っており、**この回まで黄色で出ていた**（`skill_resolver.gd` が `is_heal: true` を返しているのに誰も読んでいなかった）。**「回復を分ける」は追加仕様ではなく既存の取りこぼしの修正**
- ⚠ **`BattleLog` の `dot_status_id`（`log_results()` の引数）と results の `is_dot`（欄）が二重になった。** ログは `status_id` そのものが要るため統合していない。**片方だけ直す事故に注意**

### 介入点3種（段階3の後半③）の回で見つかったもの（2026-08-17）

- ⚠ **`PLAN_SKILL_TEMPLATE.md` 11-1 は「全滅判定より先」としか書いていないが、それだけでは足りない。** `StatusRegistry._drop_dead_hosts()` が `tick()` の**先頭**で「宿主が死んだ状態」を捨てるため、**通常攻撃で死ぬと復活の状態が走査に着く前に消える。** 走査を `_status.tick()` の前に動かしても、DoT で死ぬ経路は `tick()` の**中**なので鏡写しに壊れる。→ **`_drop_dead_hosts()` に「死亡の介入点をまだ通していない宿主の状態は捨てない」を足して解決**（`BattleUnit.death_handled`）。**死亡の介入点は「全滅判定より先」かつ「状態の掃除より先」の2条件が要る。PLAN 側の穴**
- ⚠ **PLAN 14-4 の「復活は『1回だけ』が全消しで自動保証される。カウンター不要」は不正確**（**実機で敵が無限復活して踏んだ**）。保証されるのは**「付与1回につき復活1回」**であって「1戦闘に1回」ではない。**付与元がCDを回して撃ち直せば何度でも復活する。** 検証データは `cooldown_sec: 999.0` で回避した。**本編で「1戦闘に1回だけ復活するボス」を作るなら、CDを戦闘より長くするか、PLANが「不要」と言ったカウンターを持たせるかの判断が要る**
- ⚠ **敵の `cooldown_sec` が `attack_interval_sec` より短いと、その敵は通常攻撃を1度もしない。** `_try_enemy_skill()` が true を返すと `_fire_basic_attack()` へ行かないため（`battle_controller.gd:531`）。**エラーは出ず「なぜか殴ってこない敵」になる。** 検証用の敵を作るときの定石
- ⚠ **免疫は「付けさせない」であって「既に付いているものを剥がす」ではない。** 免疫が付く前に入った状態は最後まで残る。**実機で「効いていない」と誤判定した**（実際は `intervene` が後続を弾いていた）。⚠ **敵はスキルを「射程内に入った最初の攻撃拍」でしか撃たない**ので、プレイヤーのほうが先に撃てる。`enemy_dbg_immune` の `attack_interval_sec` を 0.5 にして窓を縮めたが、**開幕に押すと今も先を越せる**
- ⚠ **効果の中の欄に「知らない欄」の検出が無い。** E26（`skill_schema.gd`）はスキル直下しか見ない。**`on_dead` のような typo は今も無音で無視される**（E63 で「介入の欄が1つも無い buff」は赤になるが、typo そのものは捕まらない）
- ⚠ **`buff` の介入の欄が3つ兄弟で並んでいる**（`on_death` / `block_status` / `heal_taken_pct`）。**4つ目が来たら `intervene{}` の入れ子に畳むこと**
- ⚠ **「死亡時発動」（死んだら他の効果を撃つ）と「他人の蘇生」はまだ書けない。** 前者は `react` に `event:died` を足す形、後者は死者を対象に取れないため（PLAN 14-4）。**この回で書けるのは自己復活だけ**
- ⚠ **死亡中もCDは回る**（既出の宿題10番と同じもの）。PLAN 14-4 は「推奨：死亡中は停止」としているが**この回では触っていない**
- **検証用の敵3体（`enemy_dbg_revive` / `enemy_dbg_immune` / `enemy_dbg_recv`）とステージ `stage_dbg_intervene` はリリース前に消す**（宿題16番に含める）
- ⚠ **`ja.csv` に重複キーが2件ある**（`ui_common_yes` / `ui_common_no` が各2行）。**`AGENTS.md`「キーの重複を作らない」に反している。** ⚠ **Ziva が検証中に見つけたが、指示範囲外なので直していない**（正しい判断）。実害は「後の行が勝つ」だけで表示は壊れていない。**消すのは人間の判断**
- **「画面を使わない検証」は Ziva に切り出せる**（`EXEC_INTERVENTION_ZIVA_CHECK.md` ＋ `IMPL_LOG_INTERVENTION_ZIVA_CHECK.md`）。**起動時のロード時検証と、データの静的な突き合わせ**が対象。⚠ **「やらないこと」を先頭に書き、`battle_last.jsonl` を読ませないこと**（戦闘を始めると人間の検証結果が消える）。**この型は次回以降も使える**

### 変数表 ＋ パッシブ（段階3の後半④-a）の回で見つかったもの（2026-08-17）

**器・語彙**

- ⚠ **`activation` に `passive` が増えた**（語彙の追加はこの1つだけ）。⚠ **`recast` / `toggle` は今も器だけ**（段階5以降）
- ⚠ **パッシブは「発動の型が違うだけのスキル」。** 定義は `skills.json`、読み込みも検証もキャッシュも既存のまま。⚠ **設計役は当初 `passives.json` ＋ 専用キャッシュに分ける案を書いたが、分けたせいで「敵はパッシブを持てない」という制約を自分で作っていた**（人間の指摘で撤回）。**分けなければ制約自体が存在しない**
- ⚠ **枠が2種類になった**（スキル枠 ／ パッシブ枠）。`game_manager.gd` の枠の仕組みは `_slot_spec(kind)` で一般化してある。⚠ **3種類目を足すときは関数をもう一式作らず、`_slot_spec()` に1行足すこと**
- ⚠ **「定義を分ける」と「枠を分ける」は別の話。** 分けたのは**枠だけ**で、定義・読み込み・検証・発動の経路はスキルと同じ1本
- ⚠ **別枠にしたおかげで「弾く仕掛け」が2つとも要らなくなった。** `_try_enemy_skill()` も戦闘画面のボタンも `skill_ids` しか見ないので、`passive_ids` に置けば自動で外れる。⚠ **`SkillActivation` に `REASON_PASSIVE` を作らないこと**（混ぜて後段で弾く形に戻さない）
- ⚠ **`BattleUnit.is_skill_ready()` は `skill_ids` と `passive_ids` の両方を見るが、`start_cooldown()` は `skill_ids` だけ**（意図的な非対称）。⚠ **揃えるとパッシブがCDを持つ／`is_skill_ready` 側を戻すとパッシブが `REASON_COOLDOWN` で無音で止まる**
- ⚠ **`of` を読まない source が3つになった**（`distance` / `elapsed_sec` / `wave_index`）。`SkillSchema.SCALE_SOURCES_NO_OF` に集約してある。**4つ目を足すときは必ずこの配列に入れること**
- ⚠ **`scale_from` の `of: "source"` は「実装しない」と決めて E68 で赤にした。** 定数 `SCALE_OF_SOURCE` は残っている。**将来実装するなら E68 を消すところから**
- ⚠ **`stack` の上限（`max_stack`）だけ入れた。残り3つ（消え方・再付与・閾値）は未実装のまま。** ⚠ **`stack: "independent"` には `max_stack` が必須**（E69）。**必須をやめると `stack:<状態ID>` の閾値が一度真になったら二度と偽に戻らない**

**パッシブの挙動**

- ⚠ **パッシブは `dispel` で剥がせない**（走査が次フレームで戻すため）。**「パッシブ無効」を作るなら別の状態として設計する**
- ⚠ **パッシブ枠だけ「未選択なら空」。** スキル枠は候補の先頭が勝手に入る（`get_battle_skills()` の `fill_empty`）。**挙動が2つに分かれている**
- ⚠ **敵はパッシブ枠を持たない。** `enemies.json` の `"passives"` 配列がそのまま装備枠（味方の「候補→選んだ枠」の2段を真似ない）
- ⚠ **`AGENTS.md` の「GameManagerの状態構造」の表の `CHARACTER_GROWTH` 行に `passives` を足すかは未対応**（人間の判断）

**実測で判明したこと（ドキュメントを直した分）**

- ⚠ **ウェーブ交代では `status_clear` が味方の状態も捨てる**（実測：`{"ev":"status_clear","count":7}`）。**ユニットを作り直さなくても状態は消える。** 設計役は「`party_units` は作り直さないから味方のパッシブは消えない」と EXEC に書いていたが**誤り**で、実測で訂正した
- ⚠ **検証用キャラ `char_debug_status` は `hp: 9999` なので、HP割合を条件にした検証が成立しない**（`hp_lost_ratio >= 0.5` に到達できない）。**人間の指摘で `alive_count_enemy` を条件にする形へ差し替えた**
- ⚠ **`scale_from` と `condition` は語彙が同じで評価器が別**（`SkillResolver._scale_variable()` ／ `StatusRegistry._condition_value()`）。**片方に枝を足し忘れても赤が1行出るだけで戦闘は続く。** 検証は必ず両方を通すこと（この回は条件側が2戦闘ぶん未検証のまま残りかけた）
- ⚠ **設計役の検証データの組み方で2回ミスをした**：自分に付くバフを `of: "target"` で見ようとした／到達できない条件を書いた。**どちらも人間が気づいた。** 検証用データは「その値が実際に動くか」を先に確かめてから書くこと

**片付け**

- **検証用のもの（`stage_dbg_passive` ／ `passive_dbg_atk` ／ `passive_dbg_cond_alive` ／ `passive_edbg_def` ／ `passive_edbg_revive_mark` ／ `skill_dbg_scale_battle`）はリリース前に消す**
- ⚠ **`ja.csv` の重複キー（`ui_common_yes` / `ui_common_no`）は削除済み**（2026-08-17・人間の承認あり）。**281キー・重複なし**

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
- ~~⚠ **パーティの入れ替え機能も要らない。** パーティは状態に入っておらず、`parties.json` の `members` を書き換えて再起動すれば入れ替わる~~
  → ⚠ **この決定は覆した（2026-08-17・`76660bd`）。** 書いたあとに**戻し忘れが2回表面化した**（敵の回の検証／条件の回の着手時点）。**編成は状態（セーブ）に入り、冒険選択画面から入れ替える**（`EXEC_PARTY_MEMBERS.md`）
- ⚠ **`MasterDataLoader` は重複IDを赤で弾き、先に読んだほうを残す**（後勝ちにすると無音で片方が消える）。**`skills_debug.json` は「無いのが正常」**

~~**検証時の手順**：`parties.json` の `members` を `["char_debug_status", "char_debug_life", "char_debug_mix"]` に差し替えて再起動。⚠ **戻し忘れると本編の検証が全部おかしくなる。**~~
→ **今は冒険選択画面の「編成」で選ぶ（2026-08-17）。`parties.json` は触らない。** 検証用3体はデバッグビルドでだけ候補に出る。

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

### ~~次：**段階3の後半① — 購読**~~ ✅ **完了（2026-08-17）**

反射・追撃が動く。**10-2「反応から生まれた行動は、さらなる反応を生まない」**の印と **10-3 `target.team: "source"`** を初回に含めた。

### ~~次：**戦闘ログ ＋ 敵の管理を味方と同じにする**~~ ✅ **完了（2026-08-17・`9b8de97`）**

**`user://logs/battle_last.jsonl`（1行1イベント）と、`enemies/<id>/skills.json`。**
⚠ **この2つが無ければ次の「条件」は検証できなかった。** 条件は事故が全部無音になる回で、
**画面を見ても分からない。** ログを先に作ったのが効いた。

- 検証用の敵6体（`enemy_dbg_*`・1体1スキル）
- **`stage_order.json` の `"debug"` 列**（常設・スタミナも報酬もクリア記録も付かない）。テストしたいこと1つにつきステージ1本

### ~~次：**パーティのメンバーを画面から入れ替える**~~ ✅ **完了（2026-08-17・`76660bd`）**

**`parties.json` を書き換えて再起動する運用をやめた**（戻し忘れを2回踏んだため）。
状態に `party_members`（`character_id` の3枠）を持ち、**冒険選択画面の「編成」で入れ替える。**
検証用3体はデバッグビルドでだけ候補に出るので、**差し替えも戻しも二度と要らない。**

⚠ **`stages.json` の `party_id` は戦闘のメンバーを決めなくなった**（`BattleLog` の見出しだけ）。書き換えても何も起きない。
⚠ **`CLAUDE.md` 4番の「リリース後にIDを改名できない」に `character_id` が加わった**（改名すると編成が黙って既定に戻る）。

### ~~次：**段階3の後半② — 条件（毎フレーム評価する発火源）**~~ ✅ **完了（2026-08-17・`5be8399`）**

**PLAN 10章の発火源4つが全部揃った**（自分の実行 / 購読 / **条件** / 周期）。
指示書は `EXEC_SKILL_CONDITION.md`。**`.gd` は4回のテストを通して1行も直していない**（直したのは検証データだけ）。

- **条件は `buff` / `dot` / `react` に書ける**（`host: unit` のみ）。**真である間だけ効く**形にした
- ⚠ **`_rebuild_unit_mods()` がゼロから組み直す設計なので、絞り込み1行で二重掛けと剥がし残りが構造的に起きない**
- ⚠ **`active` を書くのは `add()` と `_eval_conditions()` の2箇所だけ。** 読む側3箇所は bool を読むだけ
- ⚠ **件数を返す `status_count` は作らなかった。** 作ると宿題5（`stack` の上限が未実装）のまま閾値が書けてしまい、**一度真になったら二度と偽に戻らない**状態ができる
- **ログは付いた時点（`add`）と真偽が変わった瞬間（`change`）だけ。** 1戦59秒で7行

**実測で取れた証拠**：偽→真 ／ 真→偽（毒の `expire` の**0.05秒後**）／ 能力値が **4→54→4** と往復 ／
**同じ `cast` で作られた3件が別々の真偽を返す** ／ 本編 `stage_1`（965行）に `condition` が**0行**。

### ~~次：**ダメージ数値を種類で色分けする**~~ ✅ **完了（2026-08-17・`408acfe`）**

通常＝黄 ／ 会心＝橙 ／ **DoT＝紫** ／ **回復＝緑**。⚠ **色と大きさは `Balance.adventure`（`AdventureConfig`）の `@export` 12欄**で、`main_theme.tres` ではない。
⚠ **回復は `is_heal` を誰も読んでおらず、この回まで黄色で出ていた**（追加仕様ではなく既存の取りこぼしの修正だった）。

### ~~その次：**段階3の後半③＝介入点3種（回復・状態付与・死亡）＋ 復活**~~ ✅ **完了（2026-08-17）**

**PLAN 11章の「割り込む場所は4つ」のうち3つが埋まった。** ⚠ **残るはダメージだけ**（`_step_crit_override` / `_step_reduction` は**今も `pass`**・利用者ゼロ）。

| 介入点 | 利用者 | 器の書き方 |
|---|---|---|
| 死亡 | **復活** | `buff` の `on_death: { revive_hp_ratio }` |
| 状態の付与 | **免疫** | `buff` の `block_status: [status_id]` |
| 回復 | **被回復増減** | `buff` の `heal_taken_pct`（負なら低下・**和**で積む） |

⚠ **この3欄は `buff` にしか書けない**（`type` の種類は増えていない）。⚠ **`stat`/`value` を持たない buff を許した**ので、ロード時検証 **E63〜E67** を足して「何もしない buff」を赤にしてある。

**実測で取れた証拠**：`intervene kind:death` の `detail:"18"` ＝ `floor(60×0.3)` ／ `status_end`(`revive_clear`) が `intervene` の**直後**（PLAN 14-4 の「発火 → 全消し」）／ 同一キャストの回復が **20 / 10 / 20** ／ 免疫が `intervene kind:status` で2件弾いた。

### ~~次：**段階3の後半④＝変数表の追加 ＋ パッシブ ＋ コンボ**~~ 🟡 **④は2回に割った。④-a 完了（2026-08-17）**

⚠ **範囲が広かったので人間の判断で2回に割った。**

| 回 | 中身 | 状況 |
|---|---|---|
| **④-a** | 変数表の「戦闘」4つ ／ `stack` の変数と**上限** ／ `of: "source"` を赤に ／ **パッシブ** | ✅ **完了（2026-08-17）** |
| **④-b** | **コンボ**（購読の `host: battle` 拡張 ＋ `combo_count`） | ⬜ **次。`NEXT_STEPS.md` を見ること** |

**④-a で入ったもの**：`elapsed_sec` / `alive_count_ally` / `alive_count_enemy` / `wave_index` / `stack`（入れ子の `{ "source": "stack", "status_id": "..." }`）／ `max_stack`（`independent` に必須）／ `activation: "passive"` ＋ パッシブ枠 ＋ `_step_passives()` の走査。

**実測で取れた証拠**：`skill_dbg_scale_battle` の威力が **62 → 76 → 99 → 52 → 72** と動き、**スタック+1だけの差が +20**（weight 20.0）／ **`wave_index` +1・スタック −3 の差が −47**（期待 −47）。⚠ **絶対値ではなく差で判定した。**
`skill_dbg_buff_stack` を **51回撃って積まれたのは各波5件**（`max_stack: 5`）。
復活の全消しで消えたパッシブが **同じフレーム（t=7.38）で戻った**（`intervene` → `status_end`(`revive_clear`) → `cast` → `status_add`）。
条件付きパッシブが **敵2体→偽 / 1体→真** に切り替わった（`condition ... active:true why:"change"`）。

⚠ **コンボ（④-b）は `host: battle`。** 購読が今も `host: unit` のみ（E51）なので、**そこを広げるのが本体**。⚠ **`combo_count` の変数と対なので、片方だけ作らないこと。**

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

> ⚠ **廃止まで入った（2026-08-23・`EXEC_WORKSHOP_RETIRE.md`）。** `recipes.json` は 14件 → **0件**。ギルドの「作業場」ボタンは `visible = false` で隠してある。⚠ **画面もコードも消していない**（`workshop_screen` / `CRAFTING_QUEUE` / `WorkshopConfig` / `start_craft()` / `collect_craft()`）。**次の回で中間素材の製作と装飾のランダム製作を入れて復活させる。**

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

---

## 範囲攻撃（段階4）と検証の道具の入れ替えで分かったこと（2026-08-18）

### ⚠ 過去の完了記録が事実と違っていた（**13回目のズレ**）

⚠ **④-a（`EXEC_SKILL_TEMPLATE_PHASE3A.md`）の完了記録「`errors` は 0」は満たされていなかった。** 段階4の実機で `10 errors` が出て初めて分かった。

- 内訳：**1件**は段階4のミス（`range: 200` が `attack_range`(300) より短い・`master_data_loader.gd:592` のクロス検証を見落とし）／⚠ **9件は ④-a から入っていた `E69` のバグ**
- ⚠ **`E69` は `if not (raw_max is int)` と書いていた。JSON の `5` は Godot では `5.0`（float）で来るので常に偽になり、`max_stack` を正しく書いてある9件が全部赤になっていた**（`CLAUDE.md` 3番そのもの）。`_is_num()` ＋ `floor` 比較に修正済み
- ⚠ **実害はロード時の赤だけ**（実行時の上限は `status_registry.gd:204` が `int()` で包んでいて効いていた）
- ⚠ **教訓：ロード時検証の「0 errors」を、実機で1度も見ずに完了と記録していた。** 今後は**ヘッドレスで必ず1回通してから完了と書く**

### ⚠ 検証の体制が変わった（**一番大きい**）

⚠ **`CLAUDE.md` の「Godotを起動できない。ゲームを動かして確かめられるのは人間だけ」は事実と違っていた。修正済み。**

| | 誰が取るか |
|---|---|
| ロード時の赤・黄（`skills validated:`） | ⚠ **設計役**（ヘッドレス・1回4秒。人間に渡す前に潰す） |
| 戦闘中の赤 ／ 出力パネル | ⚠ **設計役**（`user://logs/godot.log` を直読み） |
| `battle_last.jsonl` | ⚠ **設計役** |
| **画面**（表示・色・レイアウト） | ⚠ **人間だけ。絵は取れない** |

- ⚠ **画面の絵は取れない。** ヘッドレスは描画がダミーで、`--write-movie` はアクセス違反で落ちる（`Parameter "t" is null`）
- ⚠ **godot MCP はツールが1つも見えず使えない。** ⚠ **上が動くので不要。設定（`.claude.json`）は残してある**
- ⚠ **`AGENTS.md` に「誰が取るか」の節を追記した。** 「どこを見るかで3章に分ける」決定自体は変えていない

### ⚠ 道具まわりの罠（**実測で踏んだもの**）

- ⚠ **`godot.log` は保持5本。設計役がヘッドレスを走らせると人間のログが1本消える。** 読む前に走らせない
- ⚠ **Godot の出力をコンソールに直接流しても1行も返らない**（GUIアプリ）。`Start-Process` ＋ リダイレクトで取る
- ⚠ **`Get-Content` は既定ANSI。** ログも `ja.csv` も `[System.IO.File]::ReadAllLines(path, UTF8)` で読む
- ⚠ **`--quit-after` で切ると `battle_last.jsonl` が途中で終わる**（エラーは1つも出ない）。**行数で判定するなら `result` の行が出ているかを先に見る**
- ⚠ **`_ready()` の中では root に `add_child()` も画面遷移もできない**（`Parent node is busy ...`）。`call_deferred` を使う。⚠ **遷移の枝は2つある**（`change_scene` と `change_scene_with_data`）。**片方だけ直して人間が赤を踏んだ**
- ⚠ **シナリオを足したら、人間に渡す前に全シナリオを1回ずつヘッドレスで回すこと**（`training` を走らせずに渡して赤を踏んだ）

### ⚠ `tests/debug_boot` について

- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**（`tests/` には既にデバッグ用が9件散らばっている＝棚卸しが宿題）
- ⚠ **セーブを絶対に書かない。** `set_party_member()` / `select_skill()` は本物の状態を触るので、保存すると人間の編成とスキル枠が黙って変わる
- ⚠ **合図は「生きている敵全員の x が0.5秒動かない」＝全員が射程ぴったりに落ち着いた。時間で書かない**
  - ⚠ **初稿は「味方が殴られたら」だったが弱かった。** 最初に殴ってきたのは射程300の置物で、狼はまだ歩いていた。**殴られたことは配置を保証しない**
- ⚠ **同じ `skill` を2行書けば2回撃つ**（`_fired` はインデックス）。⚠ **行ごとに `gap` 欄で間隔を上書きできる**（段階5で追加）
- ⚠ **`skill` が空の行は「下ごしらえだけの行」**（段階6で追加）。⚠ **`prepare` だけ書きたいときは必ず空にすること。** 書かないと `_find_user()` が null で赤を出す
- ⚠ **`prepare` は `damage_party` と `kill_party` の2つ**（`kill_party` は段階6で追加）
- ⚠ **セーブを読まない**（タイトルを通らないため）。**セーブ由来の不具合は再現しない**

### ⚠ 段階4で増えた器の宿題

- ⚠ **`origin`（`user` / `target`）が増えた。3つ目を足すときは `ORIGINS_KNOWN` に入れる**
- ⚠ **`offset`（2次元化・PLAN 16章）はまだ無い。**「敵の団の少し手前で爆発」が書けない
- ⚠ **`area` の距離は1次元**（`absf(x - x)`）
- ⚠ **`skill_arrow_rain`（矢の雨）は今も `sort: "all"`。** `area` にするとバランスが変わるので別タスク
- ⚠ **「誘導しない投射物」はまだ無い**（対象選択とは別の層）
- ⚠ **`cast` の `targets` はスキルでは常に空**（`fixed_target_ids` しか入らない・`skill_runtime.gd:132`）。**巻き込んだ数は「同じ `t` の `damage`/`heal` の行数」で数える**
- ⚠ **範囲攻撃の巻き込みが画面から読めない。** 同じ射程のユニットは同じ x に重なって停まるので数字が重なる。⚠ **立ち位置をずらす仕組みが要る**

### 片付け（**リリース前に消すものが増えた**）

- ⚠ **`tests/debug_boot.tscn` / `debug_boot.gd`**
- ⚠ **`stage_dbg_area` ／ `skill_dbg_area_narrow` `_wide` `_far` `_heal`**
- ⚠ **`tests/` の既存9件の棚卸し**（`my_test` / `modal_test` / `dummy_scene_a` / `dummy_scene_b` / `base_screen_debug` / `pomodoro_core_loop_debug` / `test_ui_common` / `test_common_infra` / `battle/test_status_registry`）

---

### 段（phases）と再発動（recast・段階5）の回で見つかったもの（2026-08-18・`9df9546`）

**人間の決定**

- ⚠ **`window_sec` が切れたら「そのまま終わる」。** 最終段を自動で出さない・巻き戻さない
- ⚠ **再発動は同じスキルボタンをもう一度押す**（ボタンを増やさない）
- ⚠ **クールダウンは1段目のあとに回り始める。** ⚠ **代わりに「構え中だけCDを見ない」を `blocked_reason()` に1本入れた。** ⚠ **窓のぶんCDが先食いされる**（最終段のあとに伸びない）
- ⚠ **段の途中で死んだら構えを捨てる。復活しても戻らない**
- ⚠ **`phases[]` と `charge` は同時に書けない**（ロード時に赤）

**器・語彙**

- ⚠ **段を取り出すのは `SkillSchema.phase_of()` 1本。`phases` が無ければ引数をそのまま返す**（複製もしない）。⚠ **分岐を各所に散らさないための構造。3箇所に書くと必ず1箇所だけ直す事故になる**
- ⚠ **構えを捨てる経路が4本ある**（窓切れ・死亡・ウェーブ交代・リトライ）。⚠ **5本目を作るときは4本全部を見直すこと**
- ⚠ **`activation: toggle` は黄のまま**（段階5では実装しない）
- ⚠ **`phases` の段ごとに `charge` を書けない。** 必要になったら「段ごとの倍率の畳み方」を先に決める
- ⚠ **構え中の見た目が無い**（ボタンの文字が `▶3.0` に変わるだけ。色もゲージも出ない）

**実測で判明したこと**

- ⚠ **台帳の「`charge` 欄の有無で分岐している」（PLAN 8章・旧 `NEXT_STEPS` §1-1）は実コードと違っていた。** もう `activation` で分岐している。⚠ **設計役は勝手に直さず報告した（台帳は未修正）**
- ⚠ **検証用スキルは `characters.json` の候補一覧にも足さないと枠に入らない**（`game_manager.gd:2129`）。`skills.json` だけでは `is not a candidate` で弾かれる
- ⚠ **`attack_type: physical` では段の違いが数値に出ない**（敵の `def` で両段とも `amount: 1` に潰れた）。⚠ **段や分岐を数値で見たいなら `"true"`**
- ⚠ **`_update_skill_buttons()` はCD残りでボタンを `disabled` にしていた。** 判定を通しても押せず、再発動が無音でできない状態だった

---

### 召喚（spawn・段階6）の回で見つかったもの（2026-08-21）

**人間の決定（7件）**

- ⚠ **座標は JSON で指定する**（効果の `offset_x`・必須欄）。⚠ **前衛・後衛どちらもあり得る。符号は「敵に向かう向きが正」**（味方は `+x`、敵は `-x` が敵方向なので、チームで反転してから足す）
- ⚠ **召喚は頭数に入らない。専用配列 `BattleSession.summon_units` を作った。** → ⚠ **`is_party_wiped()` / `is_wave_cleared()` は1行も触っていない**（混ざりようがない）
- ⚠ **`duration_sec` 切れは死亡ではない**（静かに消える）。⚠ **HPが0なら普通の死亡**（復活の介入点も通る）。⚠ **召喚者が死んだら召喚も消える**
- ⚠ **発動者は召喚ユニット自身。本体に何も戻さない。** `caster` 欄（PLAN 12-2）は作っていない
- ⚠ **同時数の上限を作らない**（下の「残っている穴」を見ること）
- ⚠ **ウェーブ交代とリトライで両方消える**
- ⚠ **`type: "summon"` が正。`host: "spawn"` は赤**（W6 を E93 に格上げ。⚠ **`HOST_SPAWN` の定数は PLAN 9章の分類語として残してある**）

**器・語彙**

- ⚠ **マスターファイルが5本目になった**（`summons.json`）。⚠ **`enemies.json` と分けたのは設計役の判断で、人間の確認待ち**（`EXEC_SKILL_SPAWN.md` §0-1 の1）
- ⚠ **`summons.json` のエントリの形は `enemies.json` の1件と同じ。** ⚠ **`skills` / `passives` は書けない**（E101）
- ⚠ **`results` に `kind` を持つ1件が流れるようになった**（召喚だけ）。⚠ **表示（`_on_skill_effects_applied`）と記録（`log_results`）の両方で先に弾くこと。** 片方だけだと `amount: 0` の damage の行が出る
- ⚠ **走査に召喚を通すのは `battle_controller._all_units()` 1本**（味方 → 敵 → 召喚の順）。⚠ **並びを変えると同じ入力で違うログが出る**
- ⚠ **召喚を消す経路は5本**（期限切れ・召喚者の死亡・召喚自身の死亡・ウェーブ交代・リトライ）。⚠ **出口は `_remove_summon()` の1本に閉じてある**
- ⚠ **`unit_id` は `summon_<通し番号>`。番号は再利用しない**

**実測で判明したこと**

- ⚠ **`_find_unit()` の複製が4本あり（宿題20）、うち3本が `summon_units` を知らずに置いていかれた。** ⚠ **症状は「`cast` の行だけ出て `damage` が1本も出ない」。エラーは1つも出ない**
  → ⚠ **`BattleSession.find_unit()` を1本作って4本とも寄せた（宿題20は解消）。新しい配列を足したら直すのはこの1本だけ。**
- ⚠ **後衛の召喚は敵に狙われない**（味方より後ろに立つので `nearest` で選ばれない）。⚠ **「狙われる母集団に入っているか」は画面から確かめられないので、支援される側（回復が5本＝味方3＋召喚2）から取った**（人間の指摘）
- ⚠ **内部クラス（`debug_boot.gd` の `Driver`）から外側の `const` を参照できない。** `PREPARE_*` の値は外側の const と Driver のリテラルの2箇所に分かれている。**綴りを揃えること**

**残っている穴**

- ⚠ **召喚の同時数に上限が無い**（人間の決定）。⚠ **CDの短い召喚スキルを1本書くと無限に増え、フレームレートと選抜の母集団が同時に育つ。エラーは1つも出ない**（検証用スキルは `cooldown_sec: 20.0` にして踏まないようにしてある）
- ⚠ **PLAN 14-5 の2欄（敵に狙われるか／味方の支援対象になるか）がまだ無い。今はどちらも「入る」で固定。** → ⚠ **ゾンビ型（支援を吸わない使い捨ての召喚）はまだ書けない**
- ⚠ **召喚はスキルもパッシブも持てない**（通常攻撃だけ）。⚠ **持たせるときは `caster`（PLAN 12-2）と発動判断（AI）を先に決めること**
- ⚠ **召喚スキルにも意味の無い `target` を書かされる**（`blocked_reason()` が `target` を要求するため。書いた `target` は選抜されるだけで当たらない）
- ⚠ **召喚の x が既存のユニットと重なりうる**（下の「立ち位置」と同じ枠）
- ⚠ **`W6` が欠番になった**（`W7` に続いて2件目）。⚠ **E は E101 まで／W は W13 まで使用済み**

**片付け（リリース前に消すもの）**

- ⚠ **`resources/balance/master/summons.json`（`summon_dbg_guard`）／ `skill_dbg_summon` ／ `ja.csv` の2行**
- ⚠ **消すときは `MasterDataLoader` の `PATH_SUMMONS` / `_cache_summons` / `get_summon()` / `has_summon()` / `_validate_all_summons()` も一緒に**
