# 次のセッションに渡すプロンプト（2026-10-03・8つ目の版）

> ⚠ **この下の枠をそのままコピーして、次のセッションの1通目に貼る。**
> ⚠ 前の版（7つ目・決定49 の回）は**この版に置き換えた**。
>   ⚠ ダンジョンの形・回3-c・回3-d・回4・回4-b・回6（測る道具）が終わり、⚠ 回7・8・9 は人間が飛ばした（`NEXT_STEPS.md` §0-UI-BM 〜 §0-UI-BT）。
>   ⚠ ここからは**デモ版**（⚠ 人間「⚠ デモ版を作るにあたって、絵のアセットの追加などが必要になってくるから　⚠ あとキャラのスキルを考えたり」）。

---

```
main の最新から始めて。⚠ push は人間がする（⚠ 未送信のコミットが残っているかもしれない＝`git status -sb` で見るだけ・自分では押さない）。
作業ツリーは .claude/settings.json 以外クリーン。

## この回の題目：**デモ版＝キャラのスキル**（⚠ 人間「⚠ とりあえずスキルを」）

⚠ これまでの回は 34 / 34 で区切った（⚠ `docs/NEXT_STEPS.md` の一番上「進み具合」「いまの流れ」）。⚠ 回7・8・9 は飛ばした。
⚠ 数字（難ダンジョンのバランス）は**人間が遊んで・ルールを変えてから自分で手を入れる**（`DG-2`）＝⚠ 設計役は数字を決めない。
⚠ 測る道具は `scenario=dungeon_sim`（⚠ `runs=` `level=` `floors=` `speed=`・§0-UI-BT）。⚠ 人間が手を入れたあと「測って」と言われたら回す。

### ① まず「今のスキルの一覧と、スキルの仕組みで作れること」を表にする（⚠ 推測で書かない・`grep` で取る）

- ⚠ キャラごと：⚠ `resources/balance/master/characters.json` の `skills`（⚠ 6人ぶん・検証用を含む＝分けて書く）／ ⚠ パッシブ（⚠ ステータスノードの総ポイントで解放＝`DECISIONS.md` の `GR-*`・メモリ「パッシブはステータスノードで解放」）
- ⚠ スキルの中身：⚠ **キャラごとのファイル** `resources/balance/master/characters/<キャラ>/skills.json` と `passives.json`（⚠ `MasterDataLoader` が1つの辞書にまとめる・検証は 112 件）・⚠ 効果の型（ダメージ・回復・状態異常・召喚・チャージ・構え直し＝`phases`・範囲・追撃…）
- ⚠ 仕組みの台帳：⚠ `docs/01_plan/PLAN_SKILL_TEMPLATE.md`（⚠ 型）／ `PLAN_SKILL_CONTENT.md`（⚠ 中身）／ `docs/02_exec/EXEC_SKILL_AREA.md`。⚠ ⚠ **PLAN の値は古いことがある**＝実コード（`scripts/systems/skill_schema.gd`・`skill_activation.gd`・`skill_resolver.gd`・`skill_runtime.gd`・`status_registry.gd`・`scenes/adventure/battle_controller.gd`）で確かめる
- ⚠ 出すもの：⚠ 「キャラ × スキル × 何をするか」の表 ＋ ⚠ 「この仕組みで作れること／作れないこと」の短い一覧。⚠ **人間はそれを見て案を出す**（⚠ 設計役から案を押しつけない＝聞かれたら出す）

### ② SDキャラを骨で動かす器（⚠ 人間「⚠ 自分で書くんだが、SDキャラのアニメーションを使おうと思ってる　⚠ godot の bone でうごかす」）

- ⚠ **絵は人間が描く**（⚠ 素材待ち＝段階13）。⚠ 動かすのは Godot の骨（`Skeleton2D` / `Bone2D` ＋ `AnimationPlayer`）
- ⚠ 設計役がするのは**器の方針**：⚠ 今の戦闘で味方・敵が何で描かれているかを `grep` で取る（⚠ `BattleUnit` の見た目・`CharacterAvatar`・戦闘画面のユニットの描き方）→ ⚠ 「キャラ1人＝1つのシーン（パーツの絵・骨・動き）」をどこに差し込むかの**選択肢**を出す
  - ⚠ 決めること（例）：⚠ 動きの種類（待機・歩く・攻撃・スキル・被弾・倒れる…）／ ⚠ 戦闘の出来事（`BattleLog` の行・攻撃の合図）とどう結ぶか ／ ⚠ 絵の部位の分け方と大きさ（⚠ 人間が描くときの注文書）／ ⚠ 絵が無いキャラは今の見た目のまま
- ⚠ **器が変わる回**（⚠ 戦闘のユニットの見た目）＝⚠ 方針を出す → 人間が裁く → EXEC → 作る
- ⚠ ①と②のどちらを先にするかは**人間に聞く**（⚠ 「とりあえずスキル」なので①が先のつもりで準備してよい）

### ⚠ 選択肢は「1あ／1い」の形で出す（⚠ 人間はその形で答える）

## 読む順

1. `CLAUDE.md` ／ `AGENTS.md`
2. `docs/NEXT_STEPS.md` の上から「いまの流れ」「進み具合」と、⚠ 直近の節（§0-UI-BT 〜 §0-UI-BM）
3. `docs/DECISIONS.md` の ⚠ `DG-2`（数字は人間）／ ⚠ 育成・パッシブ・戦闘の行（`GR-*`・`BT-*`）／ ⚠ 決定47・49（深さ）
4. ⚠ `docs/01_plan/PLAN_SKILL_TEMPLATE.md` ／ `PLAN_SKILL_CONTENT.md` ／ `PLAN_BATTLE_SCREEN.md`（⚠ とっかかり・値は古いことがある）

## ここまでで決まっている作り方（⚠ 詳しくは DECISIONS.md）

- ⚠ 値（色・寸法）は `tools/theme_builder.gd` だけが持つ。⚠ `scenario=theme` を**2回**回す（⚠ 1回目は古いテーマを読む）。⚠ `theme_override_` は書かない（⚠ 色が要るなら型を足す）
- ⚠ 紙の上の字は `paper_theme.tres`（`PaperSheet` の中は自動で墨色）。⚠ 紙の上に**黒地の札**を置くなら `PAPER_LABEL_COLORS` に字の型を足す
- ⚠ 部品：`PaperSheet` `SheetHeading` `PaperTabs` `LedgerRow`（`compact`）`Stamp` `TiltedSheet` `CharacterAvatar` `BaseFacilityBar` `SlotActionPopover` `PulseFrame` `SpecialEffectCard` `PomodoroSettingsPanel` `FocusTool` `MiniWindow` ／ ⚠ 10-03 から `DepthGauge`（潜る深さ）・`RunSidePanel`（地図の左の板）・`RunPartyStrip` は `BoxContainer`（⚠ 縦にできる）
- ⚠ セーブの形が変わるなら **EXEC を書く**（`docs/02_exec/`・例：`EXEC_DUNGEON_SHAPE.md` `EXEC_EQUIP_DROP.md` `EXEC_BASE_NO_CAPACITY.md`）。⚠ 新しい最上位の鍵は `_empty_state_template()` に足す・⚠ 数は読み込みで `int()` に戻す
- ⚠ 撮影は `scenario=shot`（⚠ いま **56枚**・窓が出る・覆わない）。⚠ **窓を本当に小さくする枚（`53_mini_window`）とデバッグの窓の枚（`57`）は並びの最後**
- ⚠⚠ **押したら何が変わるか・どこへ移るか・押せるかは `scenario=ui_flow`**（⚠ ヘッドレス・いま **193項目**）。⚠ 画面を作ったら手を足して回す。⚠ `HUMAN_CHECK.md` に積むのは色・手応え・気づけるかだけ
- ⚠ 戦闘で何が起きたかは `user://logs/battle_last.jsonl`（`BattleLog`）で読める ／ ⚠ 戦闘を自動で回すなら `DungeonSimRunner`（`tests/debug_boot.gd`）の「スキルは撃てたら撃つ」の手が使える
- ⚠ 難ダンジョン：⚠ 1フロア 10層・500層まで・層は入口から数える（`get_dungeon_absolute_layer()`）／ ⚠ 深さの帯（`depth_bands`）／ ⚠ 敵の強さは `get_dungeon_enemy_stat_pct(stat)` ／ ⚠ 装備は拾った瞬間に等級（鞄の鍵 `item_id#等級`・`make_run_bag_key()` ほか）／ ⚠ 拠点に容量は無い（`BS-20`）
- ⚠ デバッグの窓（`tests/debug_overlay.gd`・[0]）：⚠ 「装備をもらう」・⚠ 10-03 から「ショップ 在庫を戻す」（`debug_restock_shops()`）

## 気をつけること（⚠ ここまでで踏んだ）

- ⚠⚠ **ファイルの一部を perl で書き換えない**（⚠ 文字化け・空にした前例）。⚠ **編集の道具（Edit）を使う**。⚠ 字下げの数が違うと当たらない＝⚠ 当たらなかったら読み直す
- ⚠ 書き換えたら `git diff | grep "^-func"` で消えた関数を見る（⚠ 引数を変えただけでも出る＝残っているか `grep` で確かめる）
- ⚠ 押したボタン・行を押している最中に作り直さない（⚠ `_rebuild.call_deferred()`）／ ⚠ ラムダで掴まない（⚠ `bind`）
- ⚠ ノードを別の親へ移したら、⚠ `$道` で引いている所が壊れる（⚠ 10-03：地図の紙を左の板と並べたとき `$Layout/MapSheet/...` を直した）
- ⚠ `HBoxContainer` は向きを変えられない（⚠ 10-03 に赤6本）＝⚠ 向きを変えるなら `BoxContainer`
- ⚠ `enemies.json` はシナリオと難ダンジョンで共通（⚠ 難ダンジョンだけ強くするなら `DungeonConfig` のつまみ＝10-03）
- ⚠ 撮影は窓が覆われると「1枚も描かれなかった」の赤が出る（⚠ 10-03 に1回）

## 残っているもの（⚠ 片づけなくてよい）

- ⚠ `HUMAN_CHECK.md` の未確認 **0件**（⚠ 10-03 の見る回・13回目で全部済み）
- ⚠ 報告の残り：⚠ `shot` の「Lambda capture ... was freed」が出たり出なかったりする（§0-UI-AX）／ ⚠ `inventory_window` の古い検査「④ タブが4つ」（⚠ 3枚が正しい・回9 の一覧）
- ⚠ 飛ばした回（⚠ 回7 シナリオの実機確認・回8 floor のバランス・回9 リリース前の片付け）の中身は `NEXT_STEPS.md` の表に残っている
- ⚠ 作る側の装備（`EQ-11`・`EQ-13` の「高いコストのランダムな製作」）／ 鍛冶の腕（`EQ-5`）／ 遺物（`EQ-8`）は未実装

## 止まる条件・書き方（`CLAUDE.md` のまま）

- ⚠ 大きい変更は方針を出して合意を取ってから ／ ⚠ 1つの症状に2手まで ／ ⚠ 1回＝1通し・終わったら**コミットまで**（⚠ push は人間）
- ⚠ 返信の最後に「⚠ 人間がすべきこと」と ⚠ **進み具合（％）** を書く（⚠ 無ければ「無し」）
```
