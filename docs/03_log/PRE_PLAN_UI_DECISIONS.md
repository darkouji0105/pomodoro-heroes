# 決めるべき UI の一覧（画像に書き出してもらうための台帳）

> **人間の指示（2026-09-07）**：
> 「UIを、これからほかのAIと相談して画像に書き出してもらうつもり
> すべてのUIそれでいったん決めたい
> だからきめるべきUIをリストアップして、今のページから全部見れるようにして、あとリストも作って」

**このファイルの「中身」の欄は、実コード（`.tscn` / `.gd`）から機械的に取った。**
設計ドキュメントから写していない（CLAUDE.md 1番「ドキュメントの『実装済み』を信じない」）。
**推測で書いた欄には「未確認」と明記してある。**

---

## 0. どこで実物を見るか

**拠点 →「UIテスト」**（`OS.is_debug_build()` のときだけ出る）。
**本番の画面はすべてここから見られる**（2026-09-07 に確認。それまではポモドーロの4ビューだけ欠けていた）。

| 段 | 中身 |
|---|---|
| **上段** | そのまま開ける画面 **19枚**（`PLAIN_SCENES`） |
| **中段** | 先に状態を作ってから開く **5枚**（ダンジョンのマップ・宝箱・レリック・ショップ・戦闘） |
| **埋め込み** | **ポモドーロの4ビュー**（戻るボタンが無いので遷移させず、その場に並べている） |
| **部品カタログ** | ボタン ／ ResourceDisplay ／ 等級10色のマス ／ モーダル2種 |
| **全アイテム** | カテゴリごと。**装備は 11種 × 等級1〜10 = 110マス**、他は等級順 |
| **その他** | ボタンの4状態 ／ 効いている音量の値 ／ SEを鳴らす |

---

## 1. 絵を描く人へ渡す前提（実測）

| | |
|---|---|
| **基準の画面サイズ** | **1280 x 720** |
| **日本語フォント** | `NotoSansJP-VariableFont_wght.ttf`（16,732字）。**絵文字は1文字も無い** |
| **絵文字フォント** | `segoe-ui-emoji.ttf` をフォールバックに接続。**1,274字しか無い**（COLR/CPAL のカラー絵文字） |
| **無い絵文字（豆腐になる）** | ⚔ 🗡 🛡 🧪 🏹 🪖 🪵 🧱 🛏 ⛑ 📿 🏅 🎖 🤺 🦄 |
| **画像アセット** | **1枚も使っていない。** すべて四角・文字・絵文字で組んである |
| **アイテムの見た目** | 40px の角丸四角。**中央＝種類の絵文字（20px）／ 左上＝品の1文字（11px）／ 右下＝段数（10px）／ 背景＝等級の色** |
| **等級の色（10段）** | 灰 → 白緑 → 緑 → 青 → 濃青 → 青紫 → 紫 → 桃 → 橙 → 金（`icon_config.gd`） |
| **配色・フォント** | `theme/main_theme.tres` に一元化。**個別シーンで色を直接指定しない**（AGENTS.md） |
| **文字** | すべて `ja.csv` 経由（`tr()`）。画面に日本語を直接書かない |

---

## 2. 画面（本番・27枚）

「最小」は `scenario=layout` の実測（`get_combined_minimum_size()`）。**基準は 1280 x 720。**
「—」は測定リスト（`LAYOUT_SCENES`）に入っていないもの＝**まだ測っていない**。

### 2-1. 入口・拠点

| # | 画面 | パス | 直下の構成 | 最小 | 決めるべきこと |
|---|---|---|---|---|---|
| 1 | タイトル | `title/title_screen.tscn` | Background / TitleLabel / ButtonContainer / ErrorLabel | — | ロゴの扱い（いまは文字だけ）／ ボタン3つの並び |
| 2 | 拠点 | `base/base_screen.tscn` | Background / Layout | — | **下段のボタンが7個ある**（UIテストを含む）。並べ方 |
| 3 | ギルド | `guild/guild_screen.tscn` | Background / CenterContainer | 104 x 312 | 5つの入口の並べ方 |
| 4 | 未実装の代替 | `ui/placeholder_screen.tscn` | Background / Layout | — | そのままでよいか |

### 2-2. ポモドーロ

| # | 画面 | パス | 直下の構成 | 最小 | 決めるべきこと |
|---|---|---|---|---|---|
| 5 | ポモドーロ（器） | `pomodoro/pomodoro.tscn` | Background / CurrentViewContainer / QuitButton | — | 4ビューの切り替わり方 |
| 6 | 加護を選ぶ | `pomodoro/protection_select_view.tscn` | TitleLabel / VBoxContainer | — | 3択の見せ方（ライト・ミドル・ハード） |
| 7 | 集中中 | `pomodoro/focus_view.tscn` | SetLabel / TimerLabel / InstructionLabel / TitleEdit / StartButton | — | **人間の宿題「作業中のタイトルを大きく」**。タイマーの大きさ |
| 8 | 休憩 | `pomodoro/break_view.tscn` | TypeLabel / TimerLabel / SkipButton | — | 集中中との差の付け方 |
| 9 | 振り返り | `pomodoro/reflection_view.tscn` | TitleLabel / TimerLabel / InstructionLabel / ReflectionEdit / WarningLabel / CompleteButton | — | 入力欄の大きさ／警告の出し方 |

### 2-3. ギルド（育てる・作る・買う）

| # | 画面 | パス | 直下の構成 | 最小 | 決めるべきこと |
|---|---|---|---|---|---|
| 10 | 倉庫 | `guild/warehouse_screen.tscn` | Background / Layout | **1036 x 388** | **横がいちばん広い**（1280 中 1036）。マス目 20列 × 5行 × 5ページ ／ 3タブ（持ち物・図鑑・宝箱） |
| 11 | 育成 | `guild/training_screen.tscn` | Background / Margin | 289 x 436 | レベル・必要素材の並べ方 |
| 12 | ステータスのノード | `guild/stat_node_screen.tscn` | Background / Margin | — | ツリーの描き方 |
| 13 | スキル選択 | `guild/skill_select_screen.tscn` | Background / Margin | 383 x 500 | 枠と候補の見せ方 |
| 14 | 装備 | `guild/equipment_screen.tscn` | Background / Margin | **889 x 527** | **5部位 ＋ 装飾7枠**。枠の空き／中身の見せ方 |
| 15 | 研究 | `guild/research_screen.tscn` | Background / Margin | 371 x 208 | ツリー ／ **確認モーダルが無い**（宿題） |
| 16 | 作業場 | `guild/workshop_screen.tscn` | Background / Tick(Timer) / Margin | 120 x 207 | 製作キューと残り時間 |
| 17 | ショップ | `guild/shop_screen.tscn` | Background / Margin | 177 x 208 | 日替わり・週替わり・月替わりの3枠 |

### 2-4. 冒険（シナリオ側）

| # | 画面 | パス | 直下の構成 | 最小 | 決めるべきこと |
|---|---|---|---|---|---|
| 18 | 冒険を選ぶ | `adventure/adventure_select.tscn` | Background / Layout | 368 x **708** | **縦が 720 にほぼ届いている**。ステージが増えたらはみ出す |
| 19 | 編成プリセット | `adventure/party_preset_screen.tscn` | Background / Margin | 473 x 352 | 3枠 × プリセット |
| 20 | フロアのマップ | `adventure/floor_map.tscn` | Background / ChestPopup / Layout | 524 x 464 | ノードの見せ方 |
| 21 | フロアのレリック | `adventure/floor_relic_select.tscn` | Background / Layout | 400 x 212 | 3択の見せ方 |
| 22 | フロアのショップ | `adventure/floor_shop.tscn` | Background / Layout | 361 x 252 | 品と回復の並び |
| 23 | 戦闘 | `adventure/battle.tscn` | Background / PartyUnitsContainer(Node2D) / EnemyUnitsContainer(Node2D) / HUD(CanvasLayer) / ResultView | — | **唯一 Node2D を使う画面**。HUD・スキルボタン・結果画面 |

### 2-5. 難ダンジョン

| # | 画面 | パス | 直下の構成 | 最小 | 決めるべきこと |
|---|---|---|---|---|---|
| 24 | ダンジョンのマップ | `adventure/dungeon_map.tscn` | Background / Layout | 524 x 196 | **25層・ノード63・通路104本**。台帳の決定37「マップを真ん中に」が未着手 |
| 25 | 宝箱／拾いもの | `adventure/dungeon_chest.tscn` | Background / Layout | 412 x 272 | 拾い待ちと鞄の2つのマス目 |
| 26 | レリック選択 | `adventure/dungeon_relic_select.tscn` | Background / Layout | 329 x 114 | 3択 ＋ 誰に付けるか |
| 27 | ダンジョンのショップ | `adventure/dungeon_shop.tscn` | Background / Layout | 244 x 260 | 品 ＋ 鞄の枠・たいまつ |

---

## 3. 部品（2画面以上で使い回すもの）

| 部品 | パス | いまの姿 | 決めるべきこと |
|---|---|---|---|
| **ItemIcon** | `ui/components/item_icon.tscn` | 40px の角丸四角。絵文字（中央20px）＋1文字（左上11px）＋段数（右下10px）＋等級色 | **画像に置き換えるのか、この形を正とするのか** |
| **ItemSlot** | `ui/components/item_slot.tscn` | ItemIcon ＋ 装備中の印「E」＋ ツールチップ。空きマスは薄く | 空きマスの見せ方 ／ **ツールチップと下のドロップダウンが二重に出る** |
| **ItemGrid** | `.gd` のみ | マス目の器。列数は画面が決める | 1行の数 |
| **ItemDetail** | `.gd` のみ | 詳細の文章（名前・性能・枠・説明） | 何行まで出すか |
| **ItemDetailPopup** | `.gd` のみ（2026-09-07 新設） | **ホバーでカーソルの右に出るドロップダウン**。左上にアイコン | 幅・余白・背景 |
| **PrimaryButton** | `ui/components/primary_button.tscn` | Button ＋ 翻訳キー | **4状態（通常・押下・ホバー・不活性）の色** |
| **ResourceDisplay** | `ui/components/resource_display.tscn` | アイコン ＋ 数値（`current/max` も） | **アイコンが未設定**（`icon_texture` が空） |
| **ModalDialog** | `ui/components/modal_dialog.tscn` | 暗幕 ＋ 中央のパネル ＋ ボタン | **台帳の決定39「ウィンドウ形式に」が未着手** |
| **DialogBase** | `ui/components/dialog_base.tscn` | モーダルの土台 | 同上 |
| **UnitView** | `adventure/unit_view.tscn` | Body(ColorRect) / GlyphLabel / HpBar / ShieldBar / StatusChips / NameLabel | **戦闘のキャラ。いまは色の四角＋絵文字** |

---

## 4. まだ無い UI（作るところから決める）

| | 中身 | アセット |
|---|---|---|
| **設定画面** | **1つも無い。** 音量・ミュートの UI（`SoundConfig` の値が起動時に効くだけ）。**セーブ構造ごと決める回が要る** | 要らない |
| **研究の確認モーダル** | 解放時に確認が無い | 要らない |
| **ポモドーロの演出** | セット完了の知らせ ／ 作業中のタイトルを大きく ／ 休憩明けの自動開始 | 要らない |
| **リソース獲得の演出** | **デモまで作った**（`tests/resource_gain_demo.tscn`）。飛ぶルート5種・複数飛ばし・設定7項目。**どれを採るか未決** | 要らない |
| **BGM** | `play_bgm()` が無い（バスと音量欄だけ在る） | **要る（音源）** |
| **SDキャラ** | 段階13。戦闘のユニットが色の四角のまま | **要る（絵）** |

---

## 5. 共通で決めたいこと（画面をまたぐもの）

1. **配色**（`theme/main_theme.tres` の1箇所で全画面に効く）
2. **等級の10色**（アイテム・宝箱の両方が使う。4点は宝箱のレアリティと共有）
3. **ボタンの4状態**（通常・ホバー・押下・不活性）
4. **余白と角丸**（いまアイコンの角丸だけ Config にある＝`icon_corner_radius`）
5. **アイコンを画像にするか**（画像にするなら `ItemIcon` の作りごと変わる）
6. **モーダルの形**（全画面の暗幕か、ウィンドウか＝決定39）
7. **フォントの大きさの段**（見出し・本文・数値でいくつ使うか）

---

## 6. 取れていないこと（正直に）

- **画面の絵は取れない。** ヘッドレスは描画がダミーで、`--write-movie` は落ちる。**見た目は人間だけが見られる**
- **測っていない画面が5枚ある**（タイトル・拠点・ポモドーロ・ステータスのノード・戦闘）。`LAYOUT_SCENES` に入っていない
- **「決めるべきこと」の欄は提案**。実コードから取ったのは「パス・直下の構成・最小サイズ」の3つだけ
- `docs/` の他のファイルは読んでいない（指示されたもの以外は読まない決まり）。**台帳側に別の決定が書かれている可能性がある**
