# 次のセッションに渡すプロンプト（2026-09-27 夜の版）

> ⚠ **この下の枠をそのままコピーして、次のセッションの1通目に貼る。**
> ⚠ 前の版（2026-09-27・「確かめの窓から続ける回」）は**この版に置き換えた**。
>   ⚠ 確かめの窓・タイトル・ポモドーロ（回UI-4 の残り）と、育成・持ち物（回UI-組 の2つ）が終わったため。

---

```
main の最新（origin/main と同じ）から始めて。作業ツリーは .claude/settings.json 以外クリーン。

## この回の題目：**UI の作り直しの続き（回UI-組 の3つ目＝詰所）**

⚠ 人間が別の AI と作った UI の手本一式を、⚠ 回に分けて Godot に写している途中。
⚠ 手本は `docs/pomodoro-heroes-ui-docs/docs/ui/`（⚠ README.md → UI_GUIDE.md → ui_tokens.json ／ screenshots/*.png ／ screens/*.html）。
⚠ 進み具合と回の並びは `docs/NEXT_STEPS.md` の一番上（「進み具合」「これからの回」）。⚠ **いまは UI 14 / 27 回（52%）・これからの回ぜんぶ 15 / 36（42%）**。

## ⚠⚠ 詰所は答えが出ている（⚠ 方針の相談は要らない。⚠ すぐ作ってよい）

⚠ 決定 `NAV-11`（⚠ 未実装）。⚠ 人間の答え：「⚠ 1い　⚠ 2あ　⚠ 3い」。

- ⚠ 手本 `screenshots/Barracks.png` ／ `screens/Barracks.html`：⚠ 傾いた身上書カード3枚（写真・名前・役割・Lv・HP・主な値・スキル・ビルド／上がれるなら「昇級できる」の判／「開く ›」で育成へ）＋ ⚠ 下の左に出撃届 ＋ ⚠ 下の右に編成の控え
- ⚠ **1い**：⚠ 出撃届は「並べ替える」を押してから2つの枠を押すと入れ替わる。⚠ 候補の差し替えは無し（⚠ 検証用キャラは入れられない）
- ⚠ **2あ**：⚠ カードの「ビルド」の行を押すと番号が1つ進む（⚠ 控えに残すときの参照先。⚠ 状態は変えない）。⚠ 「焼く」は詰所から外す（⚠ 育成の概要にある）
- ⚠ **3い**：⚠ 控えは **8件の札**（⚠ `GameManager.PARTY_PRESET_COUNT` を 10 → 8。⚠ 9・10番に残した分は消える＝⚠ 読み込み側で落ちないか確かめる）。⚠ 札を押すと吹き出しで「呼ぶ／残す／消す」
- ⚠ 入れない：写真（顔の絵待ち）／ 3人のひとこと（台詞のデータが無い）／ 留め針
- ⚠ 今の画面は `scenes/adventure/party_preset_screen.gd`（⚠ 入口は2つ＝施設の帯と冒険の選択。⚠ `RETURN_PATH` で戻り先が変わる）

## 読む順

1. `CLAUDE.md` ／ `AGENTS.md`（⚠ 09-27 に「押した結果も取れる」＝`scenario=ui_flow` の節が増えた）
2. `docs/NEXT_STEPS.md` の上から「これからの回」「進み具合」と、⚠ 直近の節（§0-UI-AR 〜 §0-UI-AM）
3. `docs/DECISIONS.md` の ⚠ `NAV-6`〜`NAV-11` ／ `GR-4`〜`GR-6` ／ `BS-9`・`BS-15`・`BS-16` ／ `MD-10`・`MD-11` ／ `UI-10`〜`UI-17`
4. 手本：`screenshots/Barracks.png` と `screens/Barracks.html`

## ここまでで決まっている作り方（⚠ 詳しくは DECISIONS.md）

- ⚠ 値（色・寸法）は `tools/theme_builder.gd` だけが持つ。⚠ `scenario=theme` を**2回**回す（⚠ 1回目は古いテーマを読む）
- ⚠ 紙の上の字は `paper_theme.tres`（`PaperSheet` の中は自動で墨色）。⚠ 紙の上の小さな札は `UiButton.create_paper_choice()`（⚠ `UiButton` に `PaperChoice` を付けても木に入ると革に戻る）
- ⚠ 傾けたい紙は `TiltedSheet`（⚠ 幅は `holder.sheet.custom_minimum_size` に付ける。⚠ 器に付けると `_fit()` が上書きする）
- ⚠ 部品：`PaperSheet` `SheetHeading`（`ornament_below` `centered` `title_text`）`PaperTabs` `LedgerRow` `Stamp`（`filled`）`TiltedSheet` `CharacterAvatar` `CharacterDossier`（育成の身上書）`BaseFacilityBar` `SlotActionPopover`
- ⚠ 確かめの窓は紙（`MD-10`）・判は `Modal.OPTION_STAMP`・長押しは `Modal.OPTION_HOLD`（`MD-11`）。⚠ 並びは `MD-4`「はいが左」
- ⚠ 撮影は `scenario=shot`（⚠ いま **31枚**。⚠ 窓が十数秒出る。⚠ 覆わない）。⚠ 画面ごとに撮った絵と手本の png を見比べる
- ⚠⚠ **押したら何が変わるか・どこへ移るか・押せるかは `scenario=ui_flow`**（⚠ ヘッドレス・いま 35項目）。⚠ 詰所を作ったら**手を足して回す**。⚠ `HUMAN_CHECK.md` に積むのは色・手応え・気づけるかだけ
- ⚠ `layout` は画面のパスの後ろに `#タブ` を付けるとそのタブで開く（⚠ 育成・持ち物）

## 気をつけること（⚠ この回で踏んだ）

- ⚠⚠ **ファイルの一部を perl で書き換えない**（⚠ 09-27 に `DECISIONS.md` を文字化けさせ、⚠ `tests/debug_boot.gd` を空にした＝どちらも戻した）。⚠ **編集の道具（Edit）を使う**
- ⚠ 行を押して画面を描き直すときは、⚠ 押された行が木から外れる（⚠ `LedgerRow` は先に入力を食べる形に直してある）
- ⚠ 撮影・検査の下ごしらえを2回呼ぶと「刺せない」で赤になる（⚠ 装飾の下ごしらえは1回だけ）

## 次の回（⚠ NEXT_STEPS の表のとおり）

- ⚠ 回UI-組 の残り：⚠ **詰所** → 掲示板 → 届いた宝箱
- ⚠ そのあと：⚠ 仕組みの回（鍛冶・記録・設定 ほか）→ ⚠ ダンジョンの形（決定49）
- ⚠ **回3-d**（⚠ 拠点の容量の判定を消す・`BS-20`）は器が変わる＝`EXEC` を書く側

## 残っているもの（⚠ 片づけなくてよい）

- ⚠ `HUMAN_CHECK.md` の未確認 **0件**
- ⚠ `assets/fonts/segoe-ui-emoji.ttf` の扱いは人間が「⚠ まだ」
- ⚠ 地図のマスの絵は**仮**でよい（人間「⚠ 仮の絵でいい」）

## 止まる条件・書き方（`CLAUDE.md` のまま）

- ⚠ 大きい変更は方針を出して合意を取ってから（⚠ 詰所は答えが出ている）／ ⚠ 1つの症状に2手まで ／ ⚠ 1回＝1通し・終わったら push まで
- ⚠ 返信の最後に「⚠ 人間がすべきこと」と ⚠ **進み具合（％）** を書く（⚠ 無ければ「無し」）
```
