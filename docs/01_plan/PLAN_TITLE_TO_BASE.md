# 【作戦計画書】タイトル→拠点画面（遷移のみ）

第2層・作戦計画。PROJECT_STATUS.mdの推奨順序ステップ3。

---

## 1. スコープ

### 含む
- タイトル画面の最小構成（開始ボタン1つ）
- `SaveManager.has_save()`によるセーブ有無判定と、それに応じたボタン表示切り替え
- ロード分岐（セーブあり→`load_game()`、なし→新規状態のまま）
- 拠点画面への遷移（`SceneManager`経由）

### 含まない（後回し）
- タイトル画面の演出・アニメーション
- クレジット表示、設定画面へのアクセス等の付随機能（SCENES.md上、タイトル画面からの遷移先は拠点のみと読み取れるため）
- 複数セーブスロット対応（1セーブのみを前提とする）

---

## 2. シーン階層案

```
res://scenes/title/Title.tscn
Title (Control)
├─ TitleLabel
└─ StartButton   # ラベルは「はじめから」/「つづきから」で出し分け
```

---

## 3. 起動フロー

1. `_ready()`で`SaveManager.has_save()`を確認
2. `true`なら`StartButton`のテキストを「つづきから」、`false`なら「はじめから」に設定
3. `StartButton`押下時：
   - `has_save() == true` → `SaveManager.load_game()`を呼び、GameManagerの状態を復元
   - `has_save() == false` → 何もしない（GameManagerは新規開始時のデフォルト状態のまま）
4. `SceneManager.change_scene("res://scenes/base/Base.tscn")`で拠点画面へ遷移

---

## 4. 未確定・要決定

- **新規開始時のGameManagerデフォルト値**（gold, stamina.max, unlocked_screens初期状態等）をどこで定義するか
  - CLAUDE.mdの数値管理ルールに従うなら、GameManager内にハードコードせず`Balance`側（または専用の`InitialStateConfig`）に定義するのが望ましい。現状`PLAN_COMMON_INFRA.md`には未記載 → 追記候補
- `load_game()`が失敗した場合（セーブデータ破損等）のエラー処理・フォールバック
- タイトル画面から拠点以外への遷移（設定画面など）が今後必要になるか

---

## 5. 完了条件

- [ ] セーブが存在しない状態で起動すると「はじめから」ボタンが表示される
- [ ] ボタン押下で`Base.tscn`へ`SceneManager`経由で遷移する（`change_scene_to_file()`を直接呼ばない）
- [ ] セーブがある状態で起動すると「つづきから」ボタンが表示され、押下で`GameManager`の状態がロード済みの内容になっている
