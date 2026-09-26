# docs/ui — 画面デザインの資料（Claude Code 向け）

このフォルダは、画面を Godot で作り直すときの手本。

| ファイル | 中身 | Claude Code での使い方 |
| --- | --- | --- |
| `UI_GUIDE.md` | 決まり（方針・色・部品・印・画面一覧・Godot への移し方） | まず読む。迷ったらここが正 |
| `ui_tokens.json` | 色・フォント・寸法・ボタンの数値 | Theme（.tres）を作るときの数値の元 |
| `screenshots/*.png` | 全画面の見た目（1280×720、BelongingsWide だけ 1600×900） | 画像として読ませて、見た目を合わせる |
| `screens/*.html` | 全画面の静的HTML（中の数値・文言・並び） | 余白・字の大きさ・文言を確かめる |
| `ui-reference.html` | 部品の見本と変数 | 部品を作るときに見る |
| `index.html` | 画面一覧（サムネイルつき） | 人が見る用 |

## 進め方（おすすめの順）

1. **テーマを作る**：`ui_tokens.json` と `UI_GUIDE.md` の3章から、Godot の Theme を1つ作る（紙・革・真鍮・封蝋・素の StyleBox、ボタン5階層の type variation、フォント）。
2. **共通の部品を作る**：見出しの帯、施設の帯、紙（角飾りつき 9スライス）、紙の見出しタブ、台帳の行、判、しおり紐、説明の窓、確かめの窓、HPバー。
3. **画面を1枚ずつ作る**：1回の依頼で1画面。スクリーンショットとHTMLを両方渡す。
4. **見比べる**：Godot で撮った画面と `screenshots/` を並べて直す。

## Claude Code への頼み方（例）

最初に1回：

```
docs/ui/README.md と docs/ui/UI_GUIDE.md を読んで。
画面はこの決まりに合わせて作り直していく。まず ui_tokens.json から
Godot の Theme を resources/ui/theme.tres として作って。
ボタンは5階層（brass / leather / ghost / red / back）を type variation にする。
```

画面ごと：

```
docs/ui/screenshots/Character.png の画面を Godot で作って。
中の文言・並び・大きさは docs/ui/screens/Character.html を見る。
共通の部品（紙・紙のタブ・台帳の行）は作ってあるものを使う。
データは今の game_manager.gd から取る。[◯] になっている数値は仮のままでいい。
```

## 気をつけること

- モックの絵（キャラ、装備、広間、家具）はすべて仮。用意した画像に差し替える。
- 途中でやめたときの挙動とダンジョンの中の窓は、別の資料（DECISIONS.md など）に従う。モックにないものはそちらが正。
- HTML の数値や文言は見本。ゲームの値は実装側のデータを使う。
- スクリーンショットは Play 前の最初の状態。タブや場面の切り替えは、同じ画面の別ファイル（Nodes / Skills / Equip、LevelUpDone、ForgeResultFail など）で見る。
