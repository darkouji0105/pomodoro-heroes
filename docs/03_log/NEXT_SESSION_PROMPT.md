# 次のセッションに渡すプロンプト（2026-09-20 に書いた）

⚠ このファイルの下の「---」から先を、そのまま次のセッションの最初のメッセージに貼る。

---

main の e7c7fb6 から始めて。作業ツリーはクリーン。origin/main も e7c7fb6（push 済み）。

この回の題目：⚠⚠ **人間が選ぶ**（下の「次の候補」から）

先に読むもの
  AGENTS.md（毎回）
  CLAUDE.md（毎回。⚠ 9番・10番は 2026-09-20 に足した事故）
  docs/NEXT_STEPS.md §0-UI-N（難ダンジョンのモック v2・⚠ 3b〜3j が 09-20 の決定）→ §0-UI-M → §0-UI-C（覆さない決定の正）

⚠ push は聞かずにしてよい（2026-09-20・人間の許可）。⚠ main 以外へ押さない／強制 push しない／赤が残っているものは押さない

## ⚠ 直前の2日で入ったもの（⚠ 実機ではまだ1つも見ていない）

- **09-19**：⚠ マップの部品を共通化（`RunMapView`）／ ⚠ レリック選択を1枚に（`run_relic_select`）
- **09-19〜20**：⚠⚠ **難ダンジョンをモック v2 の形に**（`docs/03_log/dungeon_ui_mock_v2.html`・依頼書は `PRE_PLAN_DUNGEON_UI_MOCK.md`）
  - ⚠ 真鍮の札のマス／手描きの通路（罠は折れ線・見えない線は点線・菱形の台）／層の目盛り／区画の切れ目
  - ⚠ たいまつの明かり（⚠ 揺れの値は **Theme の `MAP_LIGHT_*`**。⚠ 周期 0 で止まる）／暗さ
  - ⚠ 拾いものは真ん中の窓（⚠ 「閉じる」は**下**）／ ⚠ 押したマスの近くに吹き出し（`SlotActionPopover`）
  - ⚠ 3人のHPはバー（`RunHpBar`・⚠ 削れたぶんが赤い帯で残る）／ ⚠ 遺物片は専用アイコン＋入手の演出
  - ⚠ 通路のできごとの窓は**閉じてから次のマスへ入る**（⚠ 段階20-d の「await しない」を覆した）
- **09-20 の人間の決定**：⚠ 素材は鞄の1枠に **10個**まで重なる ／ ⚠ 分岐は **2本の道が2〜4層**つづいて合流（⚠ いまは3層）／
  ⚠ 難ダンジョンの宝箱の中身は**合計3個**まで ／ ⚠ **荷物を落とす罠は作らない** ／ ⚠ シナリオでは右上のリソースを**出す**（難ダンジョンだけ消す）

## ⚠ 次の候補（⚠ 人間が選ぶ）

| | 中身 | 重さ | 補足 |
|---|---|---|---|
| A | ⚠⚠ **実機で見てもらう**（⚠ 09-19〜20 のぶん全部） | — | ⚠ 設計役は絵を見られない。⚠ ここが一番たまっている |
| B | ⚠⚠ **決定47：敵と戦利品の表を「層ごと」に個別調整**（⚠ 人間が単位を決めた） | 大 | ⚠ 着手の前に「いま敵と戦利品がどう決まっているか」を grep で取ってから設計を出す（台帳 §5-9-3） |
| C | ⚠ **共通モーダル**（決定39）。⚠ モックを人間が用意する | 中 | ⚠ 依頼書は `docs/03_log/PRE_PLAN_MODAL_UI_MOCK.md`。⚠ 決めてほしい6点あり |
| D | ⚠ **小さい掃除のまとめ** | 小 | ⚠ 下の「掃除の宿題」5件 |
| E | ⚠ 難ダンジョン以外の画面のモック（⚠ 冒険を選ぶ・編成・研究・拠点のショップ・作業場・装備・拠点・タイトル・設定） | 大 | ⚠ まだモックが無い |

## ✅ 掃除の宿題（⚠⚠ **2026-09-20 に候補 D として全部片付いた**・`NEXT_STEPS.md` §0-UI-O）

- ⚠⚠ **`DungeonEdgeLines` の移動と、⚠ マスの文言（たたかう／戦闘）は「やらない」と決まった**（人間・09-20）。
  ⚠ 09-19（§0-UI-M-1）の決定と食い違ったまま宿題に残っていたもの。⚠⚠ **もう宿題ではない。⚠ 触るなら合意を取り直す**
- ✅ 使われなくなったキー4本を消した（`62ec621`）
- ✅ `DungeonChest` → **`RunLootWindow`** に改名した（`05cf4eb`。⚠ uid はそのまま）
- ✅ `FLOOR_RUN.consumables` の欄を消した（`a1e0d4b`）／ ✅ `PROJECT_STATUS.md` の「現在地」を 09-20 まで進めた（`42b7c3c`）
- ⚠ 残り（⚠ 小さい）：⚠ 翻訳キー `ui_dungeon_chest_*` は改名していない ／ ⚠ `DUNGEON_EDGE_EFFECT_TRAP_BAG` の定数が残っている ／
  ⚠ `PLAN_SCENARIO_MAP.md` §7 に `consumables` の行が残っている（⚠ 台帳なので触っていない）

## ⚠⚠ 覆さないと決めたこと（⚠ 触るなら人間の合意を取る）

- ⚠ 見た目の値を持つのは `tools/theme_builder.gd` と `theme/main_theme.tres` だけ。⚠ `theme_override_` を書かない
- ⚠ ボタンは5階層。⚠ 戻るは全画面で左上・文字は「戻る」。⚠ **例外は窓**（⚠ 戦闘の結果窓・拾いもの＝下に「閉じる」）
- ⚠ 窓の縁と題の帯は全部のモーダル（`WindowPanel` / `WindowTitlePanel` / `WindowTitleLabel`）
- ⚠ 数値はスクリプトに直書きしない（⚠ Balance の Config か master の JSON）
- ⚠ 装備の個体は `add_to_inventory()` だけが作る ／ ⚠ 状態を変える前に全部の判定を終える
- ⚠ 器は別のまま：`FLOOR_RUN` と `DUNGEON_RUN` を1つにまとめない（台帳 §7）。⚠ 共有するのは「口」と「部品」だけ
- ⚠ 拒否仕様：戦闘プレビュー画面 ／ ボス画面（AGENTS.md）
- ⚠ バランスの数値は**調整のフェーズでまとめて決める**（⚠ 2026-09-19 の人間の決定）。⚠ 回復量は「とりあえずそのまま」（09-20）

## ⚠ 平常値（2026-09-20・実測）

`--import` 赤0 ／ `theme` 欠け0 ／ `layout` 0 ／ `area` 0 ／ `charge` 0 ／ `result` 0 ／ `result_defeat` 0 ／
`status_tone` 0 ／ `status_ui` 0 ／ `enemy_sp` 0 ／ `boss_sp` 0 ／ `dungeon` 0 ／ `dungeon_battle` 0 ／ `floor` 0 ／
`drops` 0 ／ `base_chest` 0 ／ `inventory` 0 ／ `economy` 0 ／ `gain` 0 ／ `glyphs` 0（⚠ 表 **49件**・NG 0・線画 **36枚**）

⚠ 黄は全シナリオで `skill_dbg_dot_odd` の1件（⚠ 前からある）。⚠ `floor` は+2件・`inventory` は+2件・`drops` は+1件（⚠ どれもわざと弾く検査）。
⚠⚠ 赤が出るのが正しいのは `workshop` 2（E129）と `unlock` 1（E125）。

⚠ 最小サイズ（⚠ 09-20 に動いたものだけ）：⚠ フロアのマップ **766 x 646** ／ ⚠ 難ダンジョンのマップ **1094 x 217** ／
⚠ 拾いもの **620 x 342**（⚠ 09-20 の実測。⚠ 前に書いてあった 316 は合わない）／ ⚠ レリック選択 **712 x 204** ／ ⚠ 商人 **888 x 320** ／ ⚠ 戦闘の HUD 581 x 145。

## ⚠ 実行環境

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path d:\pomodoro-heroes --import
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path d:\pomodoro-heroes res://tests/debug_boot.tscn -- scenario=dungeon
```

- ⚠ `Start-Process` ＋ `-RedirectStandardOutput` / `-RedirectStandardError` で実行し、⚠ `[System.IO.File]::ReadAllLines(path, UTF8)` で読む
- ⚠⚠ 新しい `class_name` を足したら必ず `--import` を先に。⚠ Godot は同時に起動できない（⚠ 数秒あけて順に）
- ⚠ 絵は取れない。⚠ 表示・色・活性・レイアウトは人間しか見られない。⚠ 位置と数は `get_global_rect()` などで数字にできる
- ⚠ `.tres` を手で書き換えない。⚠ Theme は `tools/theme_builder.gd` を直して `scenario=theme` を回す
- ⚠ コミットは日本語。⚠ 1つ入れるごとにコミット。⚠ **push は聞かずにしてよい**
- ⚠ 返信の最後に「人間がすべきこと」を書く（⚠ 無いときは「無し」と書く）

## ⚠ 直っていない弱いところ

- ⚠ **拾いものの窓を検査の中で開いて閉じられない**（⚠ 3通り試して「Lambda capture ... was freed」が6本。⚠ 原因未特定）。
  ⚠ 窓に遺物片の行が出ることは**人間が実機で見る**
- ⚠ シナリオからレリック選択を開く経路がヘッドレスで通っていない（⚠ layout は難ダンジョン側）
- ⚠ 吹き出し（`SlotActionPopover`）は外を押しても閉じない
- ⚠ `ResourceGainEffect.set_muted()` は `play()` に効かない
- ⚠ 通路の窓を閉じてから進む流れは**ヘッドレスで通せない**（⚠ 閉じるのは人だけ）
