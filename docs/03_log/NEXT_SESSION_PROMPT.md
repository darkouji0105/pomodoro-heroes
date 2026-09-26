# 次のセッションに渡すプロンプト（2026-09-27 版）

> ⚠ **この下の枠をそのままコピーして、次のセッションの1通目に貼る。**
> ⚠ 前の版（2026-09-26・「UI の作り直し一式を読んで計画を立てる回」）は**この版に置き換えた**。
>   ⚠ 計画は合意済みで、⚠ 回UI-1〜UI-4 の5枚目（商人）まで終わったため。

---

```
main の最新（origin/main と同じ）から始めて。作業ツリーは .claude/settings.json 以外クリーン。

## この回の題目：**UI の作り直しの続き（回UI-4 の6枚目＝確かめの窓）**

⚠ 人間が別の AI と作った UI の手本一式を、⚠ 回に分けて Godot に写している途中。
⚠ 手本は `docs/pomodoro-heroes-ui-docs/docs/ui/`（⚠ README.md → UI_GUIDE.md → ui_tokens.json ／ screenshots/*.png ／ screens/*.html）。
⚠ 進み具合と回の並びは `docs/NEXT_STEPS.md` の一番上（「進み具合」「これからの回」）。⚠ **いまは UI 9 / 27 回（33%）**。

## 読む順

1. `CLAUDE.md` ／ `AGENTS.md`
2. `docs/NEXT_STEPS.md` の上から「これからの回」「進み具合」と、⚠ 直近の節（§0-UI-AL 〜 §0-UI-X）
3. `docs/DECISIONS.md` の ⚠ `UI-10`〜`UI-17` ／ `NAV-6`〜`NAV-8` ／ `RUN-10`〜`RUN-16` ／ 決定 `48-g` `48-h` ／ `MD-n`
4. 手本：`screenshots/Confirm.png` と `screens/Confirm.html`（⚠ 次の回）

## ここまでで決まっている作り方（⚠ 詳しくは DECISIONS.md）

- ⚠ 値（色・寸法）は `tools/theme_builder.gd` だけが持つ。⚠ `scenario=theme` を**2回**回す（⚠ 1回目は古いテーマを読むので赤が出ることがある）
- ⚠ 紙の上の字は `paper_theme.tres`（`PaperSheet` の中は自動で墨色）。⚠ 紙の上で Ghost ボタンは使わない（⚠ 字が明るすぎる＝`PaperChoice`）
- ⚠ 傾けたい紙は `TiltedSheet` ／ `RelicCard`（⚠ Container は子の回転を0に戻すので、並べない器で包む）
- ⚠ 部品：`PaperSheet` `SheetHeading` `PaperTabs` `LedgerRow` `Stamp` `FacilityBar` `BaseFacilityBar` `RunMenuButton` `RunRelicListWindow` `TornPaperPanel` `MapLegend` `TiltedSheet` `RelicCard`
- ⚠ 撮影は `scenario=shot`（⚠ いま 23枚。⚠ 窓が十数秒出る。⚠ 覆わない）。⚠ 画面ごとに撮った絵と手本の png を見比べる
- ⚠ 確かめの窓は ⚠ **`MD-4`「はいが左」のまま**（⚠ 手本は逆だが人間「8い」で決定が勝つ）

## 次の回（⚠ NEXT_STEPS の表のとおり）

- ⚠ 回UI-4 の残り：⚠ **確かめの窓** → タイトル → ポモドーロ
- ⚠ そのあと：⚠ 組み替え（育成・持ち物・詰所・掲示板・宝箱）→ ⚠ 仕組みの回（鍛冶・記録・設定 ほか）→ ⚠ ダンジョンの形（決定49）

## 残っているもの（⚠ 片づけなくてよい）

- ⚠ `HUMAN_CHECK.md` の未確認 **1件**（⚠ 商人の値札の「買う」）
- ⚠ `assets/fonts/segoe-ui-emoji.ttf` の扱いは人間が「⚠ まだ」
- ⚠ 地図のマスの絵は**仮**でよい（人間「⚠ 仮の絵でいい」）

## 止まる条件・書き方（`CLAUDE.md` のまま）

- ⚠ 大きい変更は方針を出して合意を取ってから ／ ⚠ 1つの症状に2手まで ／ ⚠ 1回＝1通し・終わったら push まで
- ⚠ 返信の最後に「⚠ 人間がすべきこと」と ⚠ **進み具合（％）** を書く（⚠ 無ければ「無し」）
```
