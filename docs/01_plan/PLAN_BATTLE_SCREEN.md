# 【作戦計画書】戦闘画面（本番用）

第2層・作戦計画。データスキーマ（`DATA_SCHEMA.md` 3-1）を元に、本番実装用の作戦計画として書き直す。プロトタイプ資料（`godot_battle_plan_revised.md`）の設計思想（Unitクラス分離・delta加算方式）は踏襲するが、**本計画書が正**としてそのまま第3層のベースになる。プロトタイプ資料の記述と本計画書が食い違う場合は、必ず本計画書を優先すること。

---

## 1. スコープ

### 含む
- 戦闘画面のアーキテクチャ方針（ロジック層とシーンツリーの分離）
- `BattleSession`の進行管理（ウェーブ進行・勝敗判定）
- 味方／敵Unitの生成ロジック
- オートバトル（移動・通常攻撃）＋手動スキル発動のハイブリッド処理
- ダメージ計算共通式
- 戦闘中／結果の2状態の切り替え

### 含まない（別スコープ・拒否仕様）
- パーティ選択画面そのもの（別の作戦計画書。ここでは「パーティが確定した状態で戦闘が始まる」ことのみ前提とする）
- 戦闘プレビュー画面（AGENTS.md拒否仕様）
- 独立した「ボス画面」（AGENTS.md拒否仕様。最終ウェーブのボスは通常ステージ内部の演出として扱う。DATA_SCHEMA.md 3-1に明記済み）
- 詳細な敵AI・行動パターン分岐（ターゲットは「毎フレーム最も近い敵対ユニット」の自動選択のみ）
- リザルト画面の演出・アニメーション詳細

---

## 2. 画面構成（SCENES.mdより）

- 遷移元：パーティ選択画面（パーティ確定後）
- 状態：**戦闘中／結果**の2状態のみ
- 敗北時：ステージを最初からやり直す（DATA_SCHEMA 3-1準拠。ウェーブ途中からの再開はしない）

---

## 3. アーキテクチャ方針

- **ロジック層とシーンツリー（表示）を分離する**（DATA_SCHEMA 3-1の方針通り）
  - `Unit`は`Node`を継承しない`RefCounted`として実装し、純粋なデータ＋振る舞い（`take_damage` / `heal` / スキル発動判定等）のみを持つ
  - 表示側（HPバー、エフェクト、位置）は`Unit`の状態を購読して同期する別ノード（例：`UnitView`）が担当し、直接`Unit`の内部値を書き換えない
- `BattleSession`（進行管理データ）は`battle.tscn`のコントローラースクリプトが保持する。GameManagerには持たせない（戦闘中のみ存在する一時データであり、拠点共通データのSingle Source of Truthに含める必要がないため。DATA_SCHEMA 3-1のUnit構造にも同様の理由が明記されている）

---

## 4. シーン階層案

```
res://scenes/adventure/battle.tscn
Battle (Node2D)
├─ BattleController（スクリプトのみ。BattleSessionを保持し進行を管理）
├─ PartyUnitsContainer
│   └─ UnitView（party_units数ぶん動的生成）
├─ EnemyUnitsContainer
│   └─ UnitView（enemy_units数ぶん動的生成）
├─ SkillButtons（手動発動用UI。クールダウン表示付き）
└─ ResultView（勝敗結果表示。通常は非表示、victory/defeat確定時に表示）
```

---

## 5. 戦闘開始時のデータ受け取り

- `battle.tscn`の`_ready()`で`SceneManager.consume_transfer_data()`を呼び、`party_id` / `stage_id` / `stage_type`を取得する
- これらを元に、育成データ（4-3）とウェーブデータ（マスターデータ）を引いて`BattleSession`を初期化する

## 6. Unit生成ロジック

### 味方Unit
- 生成元：育成データ（DATA_SCHEMA.md 4-3「育成」の`stats` / `equipment` / `skills.slots.selected_skill_id`）
- 戦闘開始時に、選択されたパーティメンバー分だけ`Unit`インスタンスを生成し、`party_units`に格納
- 装備による補正（`atk_multiplier`等）もこの時点で計算済みの値として`Unit`に反映する

### 敵Unit
- 生成元：ウェーブデータ（DATA_SCHEMA.md 3-1「ウェーブデータ」）の`enemy_type_id` + `stat_overrides`
- `enemy_type_id`からマスターデータ（ステータス基本値）を引き、`stat_overrides`があれば上書きする
- `is_boss: true`のユニットは通常ユニットと同じ`Unit`構造を使う（見た目・演出面のみ区別する想定）

---

## 7. 戦闘ループ（オートバトル）

- 毎フレーム、生存中の各Unitについて：
  1. `target_unit_id`が無効（対象死亡等）なら、最も近い敵対ユニットを再選択
  2. `attack_range`内なら`attack_timer`を進め、タイマー到達で通常攻撃（ダメージ計算式適用）
  3. 範囲外なら`x`座標を対象に向けて移動
- ダメージ計算共通式：`最終ダメージ = max(1, 攻撃力 - 防御力)`、`攻撃力 = 素のATK × atk_multiplier`（DATA_SCHEMA 3-1準拠）
- HP変動は必ず`Unit.take_damage()` / `Unit.heal()`経由。呼び出し元から`hp`を直接書き換えない

### スキル（手動発動）
- `SkillButtons`から該当キャラのスキルをトリガー
- `cooldown_remaining > 0`の間は発動不可（UI側もボタンをdisabled表示）
- 発動後、スキル定義（DATA_SCHEMA 3-1「スキル定義」）の`cooldown_sec`で`cooldown_remaining`をリセット
- スキルタイプ（single / aoe / heal / buff / dot / projectile）ごとの効果適用ロジックは、`Unit`側ではなく専用の`SkillResolver`（`scripts/systems/skill_resolver.gd`）に集約する（Unitを純粋なデータに保つため）。`BattleController`は`SkillResolver`を呼ぶだけにする

---

## 8. ウェーブ進行・勝敗判定

- ウェーブクリア条件：そのウェーブの敵を全滅させる
- ウェーブ間は味方のHP・バフ・スキルクールダウンを**リセットしない**（連戦。DATA_SCHEMA 3-1準拠）
- 死亡した味方は復活しない
- 全ウェーブ（5ウェーブ固定）クリア → `state = victory`
- 味方全滅 → `state = defeat` → ステージを最初からやり直す（`BattleSession`を再初期化して`wave_intro`から再開。途中セーブはしない）

---

## 9. 結果処理

- `state`が`victory`または`defeat`になった時点で`ResultView`を表示
- `victory`の場合、`result.rewards`（gold / materials）を`GameManager.apply_battle_rewards(result_data)`に渡して反映する
  - **`SignalBus.battle_finished(result_data)`の発火はGameManager側で行う。戦闘画面から直接発火しないこと**（ポモドーロ報酬と同じく、二重発火を防ぐため発火元をGameManagerに一本化する）
  - `defeat`の場合は`apply_battle_rewards()`を呼ばない
- **経験値（exp）は報酬に含めない**：レベル上げは専用素材消費型で、育成データにexpフィールドが存在しないため（DATA_SCHEMA.md 4-3準拠）。戦闘での成長はレベルアップ用素材のドロップとして`materials`で表現する
- 結果確認後、`SceneManager.change_scene()`で冒険選択画面（または拠点）へ戻る

---

## 10. マスターデータの扱い

- スキル定義・ウェーブデータ・敵基本ステータスは「マスターデータ・参照専用」（DATA_SCHEMA 3-1準拠）
- 数値であっても、これらはAGENTS.mdの「数値管理ルール」が指す“ゲームバランス調整用の数値”に該当するため、スクリプトへのハードコードは避け、Resource（`.tres`）として`resources/balance/`配下に置くのが望ましい
- 読み込み方式（決定済み）：`Balance`の`@export`ではなく、専用の`MasterDataLoader`が`res://resources/balance/master/`配下の`.tres`を読み込む。IDで引く量産型データであり、Inspectorで1つずつ差し替える`Balance`の運用に合わないため
  - `MasterDataLoader`はAutoloadにはしない（Autoloadは5つに固定するルールのため）。`scripts/systems/`配下の静的クラス／`RefCounted`として実装し、`BattleController`が必要時に呼び出す

---

## 11. 未確定・要決定（対応状況の反映）

- ~~育成データ（DATA_SCHEMA 4-3）の保持責任~~ → `PLAN_GUILD_TRAINING.md`で確定。GameManagerが持つ永続データに含める方針とした
- ~~GameManagerへの追記候補：戦闘報酬の反映~~ → `PLAN_COMMON_INFRA.md`に反映済み。戦闘の結果報酬をまとめて反映できる（`apply_battle_rewards`）
- ~~マスターデータ（スキル・ウェーブ・敵ステータス）の読み込み方式・置き場所~~ → 決定済み（上記10章。`MasterDataLoader` + `res://resources/balance/master/`）
- ~~戦闘報酬のexpの扱い~~ → 決定済み。expは廃止し、素材ドロップのみとする（DATA_SCHEMA 4-3の素材消費型レベルアップと整合）
- ~~`battle_finished`の発火元~~ → 決定済み。GameManager（`apply_battle_rewards`内）に一本化
- スキルタイプ（aoe / dot / buff等）ごとの効果適用の詳細ロジック（集約先は`SkillResolver`に決定済みだが、各タイプの具体的な計算式は未確定）
- `projectile`スキルの当たり判定方式（弾速・命中タイミング）は未確定 → `PROJECT_STATUS.md`「横断的な未確定事項一覧」参照

※ パーティ・ステージ情報の受け渡しは`PLAN_COMMON_INFRA.md`に追記済み（`SceneManager.change_scene_with_data()` / `consume_transfer_data()`）。戦闘画面が受け取るデータの中身は以下を想定：
- `party_id`：挑むパーティのID
- `stage_id`：挑むステージのID
- `stage_type`：`story`または`training`

---

## 12. 完了条件（このチェックポイントのゴール）

- [ ] ダミーの1パーティ・1ステージ（1ウェーブのみ）で、オートバトルが自動的に進行し、敵を全滅させると`victory`になる
- [ ] スキルボタンを押すとスキルが発動し、クールダウン中は再発動できない
- [ ] 味方が全滅すると`defeat`になり、ステージが最初から再開される
- [ ] 5ウェーブ構成のダミーステージで、ウェーブ間にHP・クールダウンがリセットされないことを確認できる
- [ ] `victory`確定時、`GameManager.apply_battle_rewards()`が呼ばれ、その内部から`SignalBus.battle_finished`が正しい`result_data`で発火することをprintで確認できる（戦闘画面側からは発火していないこと）

この計画書がそのまま第3層（実行指示書）のベースになる。
