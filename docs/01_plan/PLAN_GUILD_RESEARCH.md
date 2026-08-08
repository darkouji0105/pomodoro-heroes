# 【作戦計画書】ギルド - 研究

第2層・作戦計画。

---

## 1. スコープ

### 含む
- 研究ツリーの表示（ノード・前提条件・解放状態）
- ノード解放処理（素材消費）
- 実効レベル上限・全キャラステータス上昇の計算ロジック（都度計算、保存はしない）

### 含まない
- 育成画面側でのレベル上げ操作そのもの（育成画面の計画書側）
- 戦闘画面でのステータス反映の詳細（Unit生成時に本計画書の計算結果を使う、という接続のみ扱う）

---

## 2. 画面構成（SCENES.mdより）

- 遷移元：ギルド画面
- ツリー全体をスクロール／パンで閲覧できるビュー1画面を想定

---

## 3. データ（DATA_SCHEMA.md 4-4より）

```json
{
  "research_tree": {
    "node_id": {
      "unlocked": false,
      "effect_type": "level_cap_unlock | stat_boost_all",
      "effect_value": 0,
      "prerequisites": ["node_id"]
    }
  }
}
```

- `research_tree`は`PLAN_GUILD_TRAINING.md`と同じ方針で、GameManagerが保持する永続データに含める

---

## 4. GameManagerへの反映（対応済み）

`PLAN_COMMON_INFRA.md`のGameManagerに以下を反映済み：
- 研究ツリー全体を取得できる（`get_research_tree`）
- 研究ノードを解放できる。前提未解放・素材不足なら何もせず失敗を返す（`unlock_research_node`）
- 指定キャラクターの実効レベル上限を計算して取得できる（`get_effective_level_cap`）
- 全キャラ共通のステータス上昇量を計算して取得できる（`get_stat_boost_all`）

- `get_effective_level_cap` / `get_stat_boost_all`は保存された値を返すのではなく、`research_tree`を都度走査して計算する（DATA_SCHEMA 4-4「実効レベル上限は都度計算」に準拠）
- `unlock_research_node`は以下を確認してから解放する：
  1. `prerequisites`が全て`unlocked: true`か
  2. 必要素材（`Balance`の`ResearchConfig`で定義）を十分持っているか
  条件を満たさない場合は何もせずfalseを返す

---

## 5. UIロジック概要

- 各ノードの表示状態：
  - 前提未解放（グレーアウト・解放不可）
  - 前提解放済み・未解放（解放可能、素材コスト表示）
  - 解放済み（達成表示）
- ノードタップで解放確認 → `unlock_research_node()`呼び出し

---

## 6. 未確定・要決定

- 研究ツリーのノード数・具体的な効果値（DATA_SCHEMA.md「未確定・要検討」に既出）
- `stat_boost_all`の適用先（戦闘のUnit生成時にどの計算式のどこへ加算するか）は`PLAN_BATTLE_SCREEN.md`側との接続確認が必要
  - 暫定方針：`PLAN_BATTLE_SCREEN.md` 6章「味方Unit」の生成時に、育成データの`stats`へ加算してから`Unit`に反映する（装備補正と同じタイミング）。確定は戦闘のEXEC執筆時
- ツリーのレイアウト（一直線／分岐ツリー等）の具体的なUI構成

---

## 7. 完了条件

- [ ] 前提未解放のノードは解放操作ができない
- [ ] 素材が十分な状態でノードをタップすると解放され、`unlocked: true`になる
- [ ] `get_effective_level_cap()`が、解放済みノードのeffect_value合計を正しく返す
- [ ] 育成画面のレベル上げ判定が、この計算結果を参照して上限チェックしている

この計画書がそのまま第3層（実行指示書）のベースになる。
