# 次のセッションに渡すプロンプト（2026-09-27 深夜・3つ目の版）

> ⚠ **この下の枠をそのままコピーして、次のセッションの1通目に貼る。**
> ⚠ 前の版（「宝箱の回」）は**この版に置き換えた**。
>   ⚠ 詰所・掲示板・宝箱で**回UI-組 が終わった**ため（`NEXT_STEPS.md` §0-UI-AS〜§0-UI-AU）。

---

```
main の最新（origin/main と同じ）から始めて。作業ツリーは .claude/settings.json 以外クリーン。

## この回の題目：**UI の作り直しの続き（回UI-仕組み の①＝鍛冶）**

⚠ 人間が別の AI と作った UI の手本一式を、⚠ 回に分けて Godot に写している途中。
⚠ 手本は `docs/pomodoro-heroes-ui-docs/docs/ui/`（⚠ README.md → UI_GUIDE.md → ui_tokens.json ／ screenshots/*.png ／ screens/*.html）。
⚠ 進み具合と回の並びは `docs/NEXT_STEPS.md` の一番上（「進み具合」「これからの回」）。⚠ **いまは UI 17 / 27 回（63%）・これからの回ぜんぶ 18 / 36（50%）**。

## ⚠⚠ 回UI-仕組み は「新しい仕組みが要る画面」＝ ⚠ **決定を先に出す**（⚠ 着手前に人間に裁いてもらう）

- ⚠ 並び（`NEXT_STEPS.md` の表）：⚠ ① 鍛冶（`EQ-5`〜`7`・`11`）② 記録 ③ 設定（`BS-13`）④ 帰還報告書 ⑤ 集中の道具 ⑥ 小窓 ⑦ 特殊効果 ⑧ ノルマ札
- ⚠ ①鍛冶の手本 `screenshots/Forge.png` ／ `ForgeResult.png` ／ `ForgeResultFail.png`（⚠ `screens/*.html` も）。⚠ いま鍛えるのは持ち物の右の紙の「鍛える」（`BS-16`）。⚠ 施設の帯の「鍛冶場」は作業場（`workshop_screen`）を開いている
- ⚠ まず `DECISIONS.md` の `EQ-n` を読み、⚠ **いまのコードで何が実装済みか**を `grep` で取る（⚠ `EQ` は「ほとんど未実装」と書かれている。⚠ 推測で決めない）
- ⚠ 器が変わるなら（⚠ 失敗のある鍛冶・等級つきで生まれる装備＝`EQ-13` など）⚠ **`EXEC` を書く側**
- ⚠ 選択肢は「1あ／1い」の形で出す（⚠ 人間はその形で答える）
- ⚠ 前の回の残り：⚠ **出撃届は仮の吹き出し**（⚠ 人間「⚠ モックが欲しいなら言って」）

## 読む順

1. `CLAUDE.md` ／ `AGENTS.md`（⚠ 09-27 に「押した結果も取れる」＝`scenario=ui_flow` の節が増えた）
2. `docs/NEXT_STEPS.md` の上から「これからの回」「進み具合」と、⚠ 直近の節（§0-UI-AU 〜 §0-UI-AP）
3. `docs/DECISIONS.md` の ⚠ `EQ-1`〜`EQ-14` ／ `NAV-6`〜`NAV-12` ／ `BS-9`・`BS-15`・`BS-16`・`BS-21` ／ `MD-10`・`MD-11` ／ `UI-10`〜`UI-17`
4. 手本：`screenshots/Forge*.png` と `screens/Forge*.html`

## ここまでで決まっている作り方（⚠ 詳しくは DECISIONS.md）

- ⚠ 値（色・寸法）は `tools/theme_builder.gd` だけが持つ。⚠ `scenario=theme` を**2回**回す（⚠ 1回目は古いテーマを読む）
- ⚠ 紙の上の字は `paper_theme.tres`（`PaperSheet` の中は自動で墨色）。⚠ 紙の上の小さな札は `UiButton.create_paper_choice()`（⚠ `UiButton` に `PaperChoice` を付けても木に入ると革に戻る）
- ⚠ 傾けたい紙は `TiltedSheet`（⚠ 幅は `holder.sheet.custom_minimum_size` に付ける。⚠ 器に付けると `_fit()` が上書きする）
- ⚠ 部品：`PaperSheet` `SheetHeading`（`ornament_below` `centered` `title_text`）`PaperTabs` `LedgerRow`（⚠ `compact`＝詰めた行・09-27）`Stamp`（`filled`）`TiltedSheet` `CharacterAvatar` `CharacterDossier`（育成の身上書）`BaseFacilityBar` `SlotActionPopover`
- ⚠ 確かめの窓は紙（`MD-10`）・判は `Modal.OPTION_STAMP`・長押しは `Modal.OPTION_HOLD`（`MD-11`）。⚠ 並びは `MD-4`「はいが左」
- ⚠ 撮影は `scenario=shot`（⚠ いま **33枚**。⚠ 窓が十数秒出る。⚠ 覆わない）。⚠ 画面ごとに撮った絵と手本の png を見比べる。⚠ 行に `"measure": [ノードのパス]` を書くと位置が出る
- ⚠⚠ **押したら何が変わるか・どこへ移るか・押せるかは `scenario=ui_flow`**（⚠ ヘッドレス・いま 74項目）。⚠ 画面を作ったら**手を足して回す**。⚠ `HUMAN_CHECK.md` に積むのは色・手応え・気づけるかだけ
- ⚠ `layout` は画面のパスの後ろに `#タブ` を付けるとそのタブで開く（⚠ 育成・持ち物）

## 気をつけること（⚠ ここまでで踏んだ）

- ⚠⚠ **ファイルの一部を perl で書き換えない**（⚠ 09-27 に `DECISIONS.md` を文字化けさせ、⚠ `tests/debug_boot.gd` を空にした＝どちらも戻した）。⚠ **編集の道具（Edit）を使う**
- ⚠ 行を押して画面を描き直すときは、⚠ 押された行が木から外れる（⚠ `LedgerRow` は先に入力を食べる形に直してある）
- ⚠ 撮影・検査の下ごしらえを2回呼ぶと「刺せない」で赤になる（⚠ 装飾の下ごしらえは1回だけ）
- ⚠ 施設の帯のある画面は、⚠ 中身が縦 720 に入りきらないと**帯の裏へ伸びて隠れる**（⚠ 詰所の1枚目で踏んだ）。⚠ 撮った絵で下端を見る
- ⚠ 吹き出し（`SlotActionPopover`）は、⚠ 作り直したばかりの札を相手にすると位置が取れない（⚠ 開くときは作り直さない）
- ⚠ 押したボタン自身を渡したいときはラムダで掴まない（⚠ 作った時点の値＝null を取る）。⚠ 作ってから `pressed.connect(f.bind(button))`

## 次の回（⚠ NEXT_STEPS の表のとおり）

- ⚠ 回UI-組 は終わった（⚠ 育成・持ち物・詰所・掲示板・宝箱）。⚠ いまは **回UI-仕組み**（⚠ ①鍛冶から）
- ⚠ そのあと：⚠ 仕組みの回（鍛冶・記録・設定 ほか）→ ⚠ ダンジョンの形（決定49）
- ⚠ **回3-d**（⚠ 拠点の容量の判定を消す・`BS-20`）は器が変わる＝`EXEC` を書く側

## 残っているもの（⚠ 片づけなくてよい）

- ⚠ `HUMAN_CHECK.md` の未確認 **2件**（⚠ 詰所の「並べ替える」に気づけるか ／ 宝箱の札が浮かび上がる手応え）＝ ⚠ あと1件で見る回
- ⚠ `assets/fonts/segoe-ui-emoji.ttf` の扱いは人間が「⚠ まだ」
- ⚠ 地図のマスの絵は**仮**でよい（人間「⚠ 仮の絵でいい」）

## 止まる条件・書き方（`CLAUDE.md` のまま）

- ⚠ 大きい変更は方針を出して合意を取ってから ／ ⚠ 1つの症状に2手まで ／ ⚠ 1回＝1通し・終わったら push まで
- ⚠ 返信の最後に「⚠ 人間がすべきこと」と ⚠ **進み具合（％）** を書く（⚠ 無ければ「無し」）
```
