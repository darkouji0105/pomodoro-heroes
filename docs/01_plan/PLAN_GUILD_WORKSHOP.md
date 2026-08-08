# 【作戦計画書】ギルド - 作業場

第2層・作戦計画。

---

## 1. スコープ

### 含む
- レシピ解放状態の表示
- 製作キュー（時間投資型）の開始・進行表示・受け取り
- 製作完了アイテムのインベントリ反映

### 含まない
- 「ポモドーロ進行で素材製作が進む」仕組みの詳細ロジック（DATA_SCHEMA.md「未確定・要検討」に既出。今回は時間経過のみで完成する最小構成とする）

---

## 2. 画面構成（SCENES.mdより）

- 遷移元：ギルド画面
- レシピ一覧 → 製作開始 → キュー表示（進行中アイテムのリスト）

---

## 3. データ（DATA_SCHEMA.md 4-5より）

```json
{
  "recipes_unlocked": { "recipe_id": false },
  "crafting_queue": [
    {
      "queue_id": "string",
      "recipe_id": "string",
      "recipe_type": "equipment | furniture_goods",
      "started_at": "timestamp",
      "duration_sec": 0,
      "status": "in_progress | completed | collected",
      "output_item_id": "string"
    }
  ]
}
```

- `recipes_unlocked` / `crafting_queue`もGameManagerが保持する永続データに含める（倉庫・ショップ・育成・研究と同じ方針）

---

## 4. GameManagerへの反映（対応済み）

`PLAN_COMMON_INFRA.md`のGameManagerに以下を反映済み：
- 現在の製作キューを取得できる（`get_crafting_queue`）
- レシピの製作を開始できる。レシピ未解放・素材不足なら何もせず失敗を返す（`start_craft`）
- 完成した製作物を受け取り、インベントリへ反映できる。未完了なら何もせず失敗を返す（`collect_craft`）

- `start_craft`は所要時間を`Balance`（`WorkshopConfig`）のレシピ定義から取得し、開始時刻を記録してキューへ追加する
- 進行中→完了への切り替えは、画面を開いたタイミングで開始時刻と所要時間・現在時刻を比較して都度判定する（別途タイマー処理を常駐させない、ポーリング方式）
- `collect_craft`で受け取り済み状態に更新し、完成物をインベントリへ反映する

---

## 5. UIロジック概要

- レシピ一覧：`recipes_unlocked`がtrueのもののみ製作開始ボタンを表示
- キュー表示：各エントリの残り時間を`duration_sec - (現在時刻 - started_at)`で計算して表示
- `completed`状態のエントリには「受け取る」ボタンを表示し、タップで`collect_craft()`

---

## 6. 未確定・要決定

- 同時に進行できるキュー数の上限（無制限か、スロット制限があるか）。上限を設ける場合は`Balance`（`WorkshopConfig`）に`@export`で定義し、ハードコードしないこと
- レシピの解放条件（何をもって`recipes_unlocked`がtrueになるか：研究ツリー経由か、ストーリー進行か）
- ポモドーロ進行と連動した素材製作の仕組み（今回はスコープ外、後日別途検討）

---

## 7. 完了条件

- [ ] 解放済みレシピのみ製作開始ができる
- [ ] 製作開始後、時間経過で`in_progress`→`completed`に自動的に切り替わる（画面再訪時の判定でよい）
- [ ] `completed`状態のアイテムを受け取るとインベントリに反映され、`status`が`collected`になる

この計画書がそのまま第3層（実行指示書）のベースになる。
