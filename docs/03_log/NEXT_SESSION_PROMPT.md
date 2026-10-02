# 次のセッションに渡すプロンプト（2026-10-03・7つ目の版）

> ⚠ **この下の枠をそのままコピーして、次のセッションの1通目に貼る。**
> ⚠ 前の版（09-28〜10-03 に書き足してきたもの）は**この版に置き換えた**。
>   ⚠ 回UI-仕組み（①鍛冶〜⑧ノルマ札）が全部終わり、⚠ 見る回も 12回目まで済んだため（`NEXT_STEPS.md` §0-UI-BL）。

---

```
main の最新から始めて。⚠ push は人間がする（⚠ 未送信のコミットが残っているかもしれない＝`git status -sb` で見るだけ・自分では押さない）。
作業ツリーは .claude/settings.json 以外クリーン。

## この回の題目：**UI の作り直しの続き＝ダンジョンの形（決定49）**

⚠ 人間が別の AI と作った UI の手本一式を、⚠ 回に分けて Godot に写している途中。
⚠ 手本は `docs/pomodoro-heroes-ui-docs/docs/ui/`（⚠ README.md → UI_GUIDE.md → ui_tokens.json ／ screenshots/*.png ／ screens/*.html）。
⚠ 進み具合と回の並びは `docs/NEXT_STEPS.md` の一番上（「進み具合」「これからの回」）。⚠ **いまは UI 26 / 28 回（93%）・これからの回ぜんぶ 27 / 37（73%）**。
⚠ UI の残りは2回：⚠ **ダンジョンの形（決定49）** ／ ⚠ 組み替えの「ダンジョンのマップの残り」。

## ⚠⚠ 決定49 は「器が変わる」回＝⚠ **方針（選択肢）を先に出す → 人間が裁く → EXEC を書く → 作る**

- ⚠ 決定49：⚠ 「500層まで・10層ごとに出口・出口から再開・ノルマ札で入る」（⚠ 09-26 は**方針だけ**）。⚠ 覆す予定＝決定26（3階×25層）・28（区画5層）・48（わかれ道の後）。⚠ 決定11（入口のコスト）は 10-02 に `DG-1`（ノルマ札）で覆し済み
- ⚠ 手本：`screenshots/DungeonGate.png`（⚠ 坑道の縦図・10層ごとのつまみ・「31層から」・−10／+10／最深へ・次の出口・出るものの下限・持ち込み・ノルマ札）と `DungeonFork.png`（⚠ わかれ道）
- ⚠ まず**いまの難ダンジョンの器**を `grep` で取る（⚠ 推測で決めない）：⚠ `GameManager` の `start_dungeon_run()`・`descend_dungeon_floor()`・`get_dungeon_max_floors()`・`retreat_from_dungeon()`・`DungeonConfig` ／ ⚠ 帰還報告書（`NAV-14`）と最深の記録（`DUNGEON_BEST_FLOORS`・`EXEC_RUN_REPORT.md`）は**決定49 の「出口から再開」に使える**
- ⚠ 選択肢は「1あ／1い」の形で出す（⚠ 人間はその形で答える）

## 読む順

1. `CLAUDE.md` ／ `AGENTS.md`
2. `docs/NEXT_STEPS.md` の上から「これからの回」「進み具合」と、⚠ 直近の節（§0-UI-BL 〜 §0-UI-BC）
3. `docs/DECISIONS.md` の ⚠ 決定 11・26・28・48・49 ／ `DG-1` ／ `NAV-11`〜`NAV-16` ／ `EQ-1`〜`EQ-15` ／ `BS-13`・`BS-21`
4. ⚠ `docs/PLAN_HARD_DUNGEON.md`（⚠ 難ダンジョンの台帳の正）
5. 手本：`DungeonGate` と `DungeonFork`

## ここまでで決まっている作り方（⚠ 詳しくは DECISIONS.md）

- ⚠ 値（色・寸法）は `tools/theme_builder.gd` だけが持つ。⚠ `scenario=theme` を**2回**回す（⚠ 1回目は古いテーマを読む）。⚠ `theme_override_` は書かない（⚠ 色が要るなら型を足す）
- ⚠ 紙の上の字は `paper_theme.tres`（`PaperSheet` の中は自動で墨色）。⚠ 紙の上に**黒地の札**を置くなら `PAPER_LABEL_COLORS` に字の型を足す（⚠ 無いと墨が勝つ・10-02 の特殊効果の札で踏んだ）
- ⚠ 部品：`PaperSheet` `SheetHeading` `PaperTabs` `LedgerRow`（`compact`）`Stamp` `TiltedSheet` `CharacterAvatar` `BaseFacilityBar` `SlotActionPopover` `PulseFrame` ／ ⚠ 10-02 から `SpecialEffectCard`（★と黒地に金の札）`PomodoroSettingsPanel` `FocusTool` `MiniWindow`
- ⚠ 確かめの窓は紙（`MD-10`）・知らせの窓も `Modal.OPTION_PAPER` で紙にできる（⚠ 中身は `OPTION_CONTENT`）
- ⚠ 設定は `GameSettings`（`user://settings.cfg`・⚠ セーブと別）。⚠ 置き場所は **Engine のメタ**（`use_path()`）＝⚠ static 変数は途中で初期値に戻る（⚠ 検査が本物の設定を書いた）
- ⚠ セーブの形が変わるなら **EXEC を書く**（`docs/02_exec/`・例：`EXEC_CODEX_GRADES.md` `EXEC_RUN_REPORT.md` `EXEC_QUOTA_TICKET.md`）。⚠ 新しい最上位の鍵は `_empty_state_template()` に足す（⚠ `load_state()` はテンプレに在る鍵しか写さない）・⚠ 数は読み込みで `int()` に戻す
- ⚠ 撮影は `scenario=shot`（⚠ いま **55枚**・窓が出る・覆わない）。⚠ **窓を本当に小さくする枚（`53_mini_window`）とデバッグの窓の枚（`57`）は並びの最後**。⚠ ランを終わらせる・宝箱を積む枚は宝箱の枚より後ろ
- ⚠⚠ **押したら何が変わるか・どこへ移るか・押せるかは `scenario=ui_flow`**（⚠ ヘッドレス・いま **181項目**）。⚠ 画面を作ったら手を足して回す。⚠ `HUMAN_CHECK.md` に積むのは色・手応え・気づけるかだけ
- ⚠ ui_flow の下ごしらえ：⚠ 鍛冶は必ず成功 ／ ⚠ **効果音を止めている**（⚠ ヘッドレスで鳴らすと終了時に「resources still in use」の赤が出たり出なかったり）／ ⚠ 設定は検査用のファイル
- ⚠ 戦闘で何が起きたかは `user://logs/battle_last.jsonl`（`BattleLog`）で読める（⚠ 10-03 に追撃の発火をこれで確かめた）
- ⚠ デバッグの窓（`tests/debug_overlay.gd`・[0]）：⚠ 2列の小さなボタン ／ ⚠ 「装備をもらう」＝`grant_equipment(item_id, grade)`（⚠ 検査も使える）

## 気をつけること（⚠ ここまでで踏んだ）

- ⚠⚠ **ファイルの一部を perl で書き換えない**（⚠ 文字化け・空にした前例）。⚠ **編集の道具（Edit）を使う**。⚠ 字下げの数が違うと当たらない＝⚠ 当たらなかったら読み直す
- ⚠ 書き換えたら `git diff | grep "^-func"` で消えた関数を見る（⚠ 引数を変えただけでも出る＝残っているか `grep` で確かめる）
- ⚠ 押したボタン・行を押している最中に作り直さない（⚠ `_rebuild.call_deferred()`）
- ⚠ ラムダで掴まない（⚠ `bind` を使う・CLAUDE.md 10番）
- ⚠ 施設の帯のある画面は縦 720 に収まるか撮った絵で下端を見る
- ⚠ 新しい入口を作るときは**そこへ行けるか**を見る（⚠ 10-03：⚠ ノルマ札を足したのにショップが第3話まで出ず、⚠ 難ダンジョンに入れなかった＝人間が見つけた）
- ⚠ 同じ瞬間に出る数字は重なる（⚠ 10-03：⚠ 追撃の数字が元の数字の真上に出て見えなかった＝同じフレームで数えてずらす形に直した）

## 残っているもの（⚠ 片づけなくてよい）

- ⚠ `HUMAN_CHECK.md` の未確認 **0件**（⚠ 10-03 の見る回・12回目で全部済み）
- ⚠ 報告の残り：⚠ `shot` の「Lambda capture ... was freed」が出たり出なかったりする（⚠ 32→33 の間・§0-UI-AX・2手で止めた）
- ⚠ 回ごとの残り（⚠ `NEXT_STEPS.md` の各節）：⚠ 鍛冶の腕（`EQ-5`）／ 作業場の中身はまだ紙でない ／ 遺物（`EQ-8`）／ 日ごとの集中の履歴（⚠ 記録しない）／ 小窓の「話しかける」と広間 ／ 手に入れる集中の道具 ／ ノルマ札の「ポモドーロ90分で+1」（⚠ 入れていない）／ 特殊効果の値・宝箱の重み・ノルマ札の値段は**仮**
- ⚠ **回3-d**（⚠ 拠点の容量の判定を消す・`BS-20`）は器が変わる＝`EXEC` を書く側
- ⚠ `assets/fonts/segoe-ui-emoji.ttf` の扱いは人間が「⚠ まだ」／ ⚠ 地図のマスの絵は**仮**でよい

## 止まる条件・書き方（`CLAUDE.md` のまま）

- ⚠ 大きい変更は方針を出して合意を取ってから ／ ⚠ 1つの症状に2手まで ／ ⚠ 1回＝1通し・終わったら**コミットまで**（⚠ push は人間）
- ⚠ 返信の最後に「⚠ 人間がすべきこと」と ⚠ **進み具合（％）** を書く（⚠ 無ければ「無し」）
```
