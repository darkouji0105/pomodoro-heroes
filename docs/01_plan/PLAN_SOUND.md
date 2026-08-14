# 【作戦計画書】音（第1弾：ポモドーロのアラーム）

**第2層。第1層（ゲームの中身の正）は`GAME_DESIGN.md`。実装順は`PLAN_IMPLEMENTATION.md` 3章の1番。**

このプロジェクトで**音についての設計書は本ファイルが最初**。以降、SE・BGMを足すときもこのファイルに追記する。

---

## 0. 着手前に実コードを確認した結果（2026-08-14）

**`grep`で確認済み。ドキュメントとのズレは無かった（1件を除く。9章）。**

| 調べたもの | 結果 |
|---|---|
| `AudioStreamPlayer` / `AudioServer` / `volume_db` / `.ogg` `.wav` `.mp3` | **`.gd`・`.tscn`に0件** |
| `assets/sounds/` | **存在するが空** |
| `project.godot`のAutoload | 5つのみ。音のAutoloadは無い |
| `project.godot`のバス構成 | **記述なし**（`default_bus_layout.tres`も無い＝Master1本のデフォルト） |
| `PomodoroConfig` | 音関連の`@export`は**無い** |

**音の仕組みは完全にゼロ。** 既存の何かに乗せることはできない。

> **この表は「着手前」の記録。その後（同日）、人間が以下を投入済み。**
> - `default_bus_layout.tres`（プロジェクト直下・`SE` / `BGM` の2本を`Master`へ送る構成）
> - `assets/sounds/alarm_focus_end.wav` / `alarm_break_end.wav`（インポート済み。**ただし`loop_mode`の修正が要る。10-3参照**）
>
> **コード側（Autoload・`SoundConfig`・呼び出し）は未着手のまま。**

---

## 1. スコープ

### 含む

- **音を鳴らす共通の仕組み**（Autoload `SoundManager` ＋ `SoundConfig`）
- **AudioBusを3本切る**（`Master` / `SE` / `BGM`）。**音量UIは作らない**
- **作業終了のアラーム**（`State.FOCUS`のタイマー終了時）
- **休憩終了のアラーム**（`State.BREAK`のタイマー終了時）
- 音源が未設定でも**落ちない**こと

### 含まない

| 項目 | 理由 |
|---|---|
| 音量設定・ミュートのUI | 設定画面は第2層ごと存在しない。セーブ構造にも手が入る |
| BGM | `DEMO_CHECKLIST.md`の音の章。バスだけ先に用意する |
| 戦闘SE・UI SE | 同上。**仕組みができるので、後は呼ぶ行を足すだけになる** |
| 音源そのものの調達 | **人間が用意して入れる**（3章） |
| 音量・音色・長さの調整 | **聴かないと決められない。実装後に別の会話で人間が決める** |

### スコープの決定（人間）

**スコープB（共通の仕組み＋作業終了＋休憩終了）＋AudioBus3本を今回切る。** 2026-08-14に決定。

- **A（最小・作業終了だけ）を採らない理由**：休憩終了で鳴らないと「ボタン待ちで止まったまま気づかない」が残る（6章参照）。また1音だけ直書きすると、次にSEが来たとき全部やり直しになる
- **C（音量設定まで）を採らない理由**：「他と独立していて小さい」という前提が崩れる
- **バスを先に切る理由**：後で設定画面を作るときにバスを切り直すと、**既存の全再生コードを見直す羽目になる**

---

## 2. Autoloadを1つ増やす（**人間の承認が要る**）

`AGENTS.md`は「AIは5つ以外のAutoloadを勝手に追加しない」と定めている。**本PLANの合意＝この追加の承認**として扱う。

| Autoload名 | 責務 |
|---|---|
| `SoundManager` | 効果音の再生。IDを受け取り、`Balance.sound`から音源を引いて鳴らす |

### 登録順（厳守）

```
1. Balance
2. GameManager
3. SaveManager
4. SceneManager
5. SignalBus
6. SoundManager   ← 追加。必ず最後
```

**`SoundManager`は`Balance.sound`を参照するため、`Balance`より後でなければならない。** 末尾に足せば条件を満たす。

**`AGENTS.md`のAutoload表と登録順も、実装後に更新すること**（本PLANの合意後、EXECの人間作業に含める）。

### なぜ画面ごとに`AudioStreamPlayer`を置かないか

- 画面遷移で再生中のノードごと消える。アラームは**遷移の直前に鳴る**（6章）ので、遷移で切れる置き方は選べない
- SE/BGMが来たとき、置き場所が画面ごとにバラける

---

## 3. 音源ファイル（**人間が用意する**）

### 決定

**音源はユーザーが用意して`assets/sounds/`に置く。** AIは音源を生成しない。

- **置き場所は`assets/sounds/`の直下。** 既に存在して空なので、**新規フォルダの作成は不要**
- サブフォルダ（`se/` `bgm/`）は切らない。2ファイルしか置かないため。BGMが来た時点で再検討する
- ファイル名は**snake_case**（`AGENTS.md`の命名規則）

| ファイル | 用途 |
|---|---|
| `assets/sounds/alarm_focus_end.wav` | 作業終了 |
| `assets/sounds/alarm_break_end.wav` | 休憩終了 |

**同じファイルを両方に割り当ててもよい**（1本だけ用意して両方に差す運用を許す）。`SoundConfig`は音源を別々に持つので、後から差し替えられる。

### 形式とインポート

- **短いSEは`.wav`を推奨。** Godotのインポート設定で「Loop」を**オフ**にすること（`.wav`は既定でループが有効になることがある）
- `.ogg`でも動く。長さの目安は**1〜2秒**
- **インポートはGodot上の作業なので人間が行う。** AIは`.import`ファイルを書かない

### 音源が無くても止まらないこと（重要）

**`SoundConfig`の音源欄が空でも、ゲームは落ちず、警告を出して先に進む。** こうすることで「音源探し」と「実装」を分離でき、素材が揃うまで実装が止まらない。

---

## 4. データ

### 4-1. `SoundConfig`（新規・`res://resources/balance/sound_config.gd`）

数値は`Balance`経由でアクセスする（`AGENTS.md`の数値管理ルール）。`Balance`に`@export var sound: SoundConfig`を1行足す。

```gdscript
class_name SoundConfig
extends Resource

@export var entries: Array[SoundEntry] = []
@export var se_player_count: int = 4
@export var master_volume_db: float = 0.0
@export var se_volume_db: float = 0.0
@export var bgm_volume_db: float = 0.0
```

- `se_player_count`：同時発音数。アラームだけなら1で足りるが、後のUI SEで連打すると音が切れるため4本のプールを持つ
- `*_volume_db`：起動時に各バスへ適用する初期音量。**設定画面が来たらここが既定値になる**

### 4-2. `SoundEntry`（新規・`res://resources/balance/sound_entry.gd`）

```gdscript
class_name SoundEntry
extends Resource

@export var sound_id: String = ""
@export var stream: AudioStream = null
@export var volume_db: float = 0.0
```

- `volume_db`は**音源ごとの補正**。素材の音量差をコードを触らず吸収するため

### 4-3. `SoundIds`（新規・`res://scripts/utils/sound_ids.gd`）

文字列リテラルを書かない方針（`GameStateKeys` / `TransferKeys`と同じ形）。

```gdscript
class_name SoundIds

const ALARM_FOCUS_END: String = "alarm_focus_end"
const ALARM_BREAK_END: String = "alarm_break_end"
```

### 4-4. `.tres`の罠（**この罠で既に1件死んでいる**）

**`.tres`は`@export`の既定値と同じ値を書き出さない。**

- 実測：`pomodoro_config.tres`には`reflection_time_limit_sec`も`potion_focus_minutes_per_unit`も**行が存在しない**。`.gd`側に初期値が書いてあるので動いているだけ
- したがって**`.gd`側の`@export`には必ず初期値を書く**（上記のコードは全て初期値付き）
- `sound_config.tres`を人間がInspectorで作り、**音源を割り当てて保存**すれば、`entries`の行は書き出される

### 4-5. セーブには何も足さない

**音量はセーブしない。** 設定画面が無いので変更手段が無く、持つ意味がない。設定画面を作る回にセーブ構造を決める（8章）。

---

## 5. `SoundManager`の仕様

`res://autoload/sound_manager.gd`（新規）。

### 公開関数

| 関数 | 動作 |
|---|---|
| `play_se(sound_id: String) -> void` | IDに対応する音源を鳴らす。**これだけ** |

### 内部の動き

1. `_ready()`で`Balance.sound`を読み、`entries`を`{sound_id: SoundEntry}`のDictionaryに展開する
2. `se_player_count`個の`AudioStreamPlayer`を生成し、`bus = "SE"`を設定して子に持つ
3. `_ready()`で`master_volume_db` / `se_volume_db` / `bgm_volume_db`を各バスへ適用する
4. `play_se()`はプールから**再生中でないプレイヤー**を探して鳴らす。全部埋まっていたら最初の1本を上書きする

### 落ちない条件（**全てpush_warningを出して`return`する**）

| 状況 | 動作 |
|---|---|
| `Balance.sound`が未割当 | 警告を出し、以降`play_se()`は何もしない |
| 知らない`sound_id` | 警告を出して`return` |
| `stream`が`null`（音源未設定） | 警告を出して`return` |
| バス`SE`が存在しない（バス未作成） | 警告を出し、`Master`にフォールバックする |

**最後の1つが重要。** バス作成は人間の作業なので、実装が先に入ってバスが後になる状態が必ず一度は発生する。そこで音が全く鳴らないと、原因が音源なのかバスなのか切り分けられない。

### ログ

`play_se()`が実際に再生したとき、**1回につき1行**print する。

```
[Sound] play se=alarm_focus_end
```

**二重再生の確認はこの行数で行う**（10章）。

---

## 6. 鳴らす場所（実コードに突き合わせ済み）

`scenes/pomodoro/pomodoro.gd`（383行）。

### 6-1. 作業終了

**既に`_notify_focus_finished()`（233行目）が存在し、`DisplayServer.window_request_attention()`を呼んでいる。** 新しいフックは要らない。この関数に1行足す。

```
_process() で time_left_sec <= 0
  → is_timer_active = false
  → _on_timer_finished()
      └ State.FOCUS: _notify_focus_finished()   ← ここで鳴らす
                     _switch_view(State.REFLECTION)
```

**120秒の猶予は`_switch_view(State.REFLECTION)`の中の`_start_phase_timer(REFLECTION_TIME_LIMIT_SEC)`（138行目）で始まる。** 上記の位置なら**猶予の開始より前**に鳴るので、「猶予の開始と同時に鳴る」は自動的に満たされる。

### 6-2. 休憩終了

`_on_timer_finished()`の`State.BREAK`分岐に`_notify_break_finished()`（新設）を足し、その中で鳴らす。

**⚠ `_on_break_skipped()`（スキップボタン）では鳴らさない。** 自分で押したので終わったことは分かっている。**同じ`_go_to_next_set()`を通るので、`_go_to_next_set()`や`_switch_view()`の中に置くとスキップ時にも鳴る。** ここが今回いちばん間違えやすい箇所。

### 6-3. 休憩終了で鳴らす必要がある理由（実測）

**休憩明けの自動開始は実装されていない。** 休憩終了 → `_go_to_next_set()` → `_switch_view(State.FOCUS)` と進むが、**タイマーは開始ボタン待ちで止まる**（132行目のコメント「ここではタイマーを走らせない」）。

つまり**休憩終了に気づかないとセッションが止まりっぱなしになる。** 作業終了と同格の機能欠落。

### 6-4. 一時停止・バックグラウンドの分岐は不要

- **ポーズ機能は実装されていない。** `project.godot`に`pomodoro_pause_toggle`（Pキー）が登録済みだが、**`.gd`のどこからも参照されていない**（grep 0件）
- `get_tree().paused`を触るのは`ModalDialog`だけ。ポモドーロ側からモーダルを`pause: true`で出す経路は無い
- したがって**「鳴らす条件の分岐」は今回不要。** ポーズを実装する回に、ポーズ中のタイマーごと再検討する

### 6-5. 二重再生のリスク

`_on_timer_finished()`を呼ぶのは`_process()`とデバッグパネルの`_on_debug_skip_phase()`の2箇所のみ。**どちらも`is_timer_active = false`にしてから1回だけ呼ぶ。** 現状の構造では二重発火しない。10章のログで確認する。

### 6-6. デバッグ：「残り1秒にする」ボタンを足す（人間の要望・2026-08-14）

**25分待たないとアラームが聴けないのでは検証にならない。** 既存のデバッグパネル（`_build_debug_panel()`・294行目〜）にボタンを1つ足す。

| ボタン | 動作 | 何のため |
|---|---|---|
| 既存「このフェーズを終わらせる」 | `time_left_sec = 0` にして`_on_timer_finished()`を**直接呼ぶ** | フェーズ遷移の検証 |
| **新規「残り1秒にする」** | `time_left_sec = 1.0` にするだけ。**あとは`_process()`が自然に0にする** | **アラームの検証** |

**わざと別のボタンにする。** 既存のスキップは`_process()`を通らずに`_on_timer_finished()`を直接呼ぶため、**本番と同じ経路を通っていない。** 音の確認は`_process()`が0にする経路で行う必要がある。

仕様：

- `is_timer_active`が`false`のとき（＝作業開始ボタン待ち）は、既存のスキップと同じく`print`して`return`する
- `time_left_sec`と`is_timer_active`を書き換えてよいのは`_start_phase_timer()` / `_stop_phase_timer()` / `_process()`のみ、という[pomodoro.gd:6-9](../../scenes/pomodoro/pomodoro.gd#L6-L9)の決まりに従い、**`_start_phase_timer(1.0)`を呼ぶ形にする**（直接代入しない）
- `OS.is_debug_build()`のガードは既存パネルが持っているので、そのまま中に足せばよい

**⚠ これは検証用なのでリリース前に消す。** `CLAUDE.md`「検証用のものは増やしたら宿題に書く」に従い、9章に記録する。

---

## 7. AudioBus（**人間がGodot上で作る**）

Audioパネルで3本にし、`default_bus_layout.tres`として保存する。

| # | バス名 | 送り先 |
|---|---|---|
| 0 | `Master` | — |
| 1 | `SE` | Master |
| 2 | `BGM` | Master |

- **バス名は大文字。** `SoundManager`は`"SE"`で引く
- 保存すると`project.godot`に`audio/buses/default_bus_layout`の行が入る
- エフェクト（リバーブ等）は付けない

---

## 8. 未確定として残すもの

| 項目 | いつ決めるか |
|---|---|
| 音量・音色・長さ | **実装後に人間が聴いて決める。別の会話で行う** |
| 音量設定UI・ミュート | 設定画面を作る回。そのときセーブ構造も決める |
| BGMの再生（ループ・フェード・画面切替時の継続） | BGMを入れる回。`play_bgm()`は今回作らない |
| ウィンドウ非フォーカス時に鳴らすか | 現状は鳴る。OS通知の方式見直し（`PROJECT_STATUS.md`の宿題）と一緒に決める |
| `window_request_attention()`を残すか | 音が入った後、人間が実機で判断する。**今回は残す** |

---

## 9. 併せて直さないもの（宿題に送る）

**実コード確認で見つけたズレ。今回は直さない**（`CLAUDE.md`「ついでにこれもをやらない」）。

- **`PomodoroConfig.reflection_time_limit_sec`（既定120）が使われていない。** `pomodoro.gd`は`const REFLECTION_TIME_LIMIT_SEC: float = 120.0`をハードコードしている。`reflection_min_chars`も未使用。**`AGENTS.md`の数値管理ルール違反。** 現状は値が一致しているため実害は出ていない
- → `PROJECT_STATUS.md`の宿題に追加する

**今回増やす検証用のもの（リリース前に消す）**：

- **ポモドーロのデバッグパネルの「残り1秒にする」ボタン**（6-6）。`OS.is_debug_build()`のガード内なのでリリースビルドには出ないが、**コードは残る**
- → `PROJECT_STATUS.md`の宿題に追加する（`debug_instant`・0Gスロット・`weapon_debug_blade`と同じ扱い）

---

## 10. 完了条件

**「ログ」「ファイル」「音（人間が聴く）」の3つに分ける。同じことを2箇所に書かない。**

### 10-1. 音（人間が実機で確かめる）

**確認の道具**：デバッグパネルの**「残り1秒にする」**（6-6）。25分・5分を待たずに、**本番と同じ`_process()`の経路で**0秒到達を再現できる。「このフェーズを終わらせる」は経路が違うので音の確認に使わない。

1. 作業タイマーが0になった瞬間にアラームが鳴る
2. 鳴ってから振り返り入力の画面が出るまでに、気づける余地がある
3. 休憩タイマーが0になった瞬間にアラームが鳴る
4. **休憩のスキップボタンを押したときは鳴らない**
5. 音量が過大でない（**調整は別の会話でよい**）

### 10-2. ログ（Godotの出力パネル）

1. 作業終了1回につき`[Sound] play se=alarm_focus_end`が**1行だけ**出る（**二重再生していない**）
2. 休憩終了1回につき`[Sound] play se=alarm_break_end`が**1行だけ**出る
3. 音源を割り当てない状態で起動すると、再生時に警告が出て**ゲームは続行する**

### 10-3. ファイル（テキストエディタで開く）

1. `project.godot`の`[autoload]`に`SoundManager`が**6番目**に入っている
2. **プロジェクト直下**に`default_bus_layout.tres`があり、`SE`と`BGM`が`Master`へ送られている
   - ⚠ **`project.godot`に`audio/buses/default_bus_layout`の行は出ない。** `res://default_bus_layout.tres`がGodotの既定パスであり、**既定値と同じ設定は書き出されない**ため。`.tres`が既定値を書かないのと同じ罠。行が無いことを不具合と判断しないこと
3. `sound_config.tres`に`entries`が書き出されており、`stream`のパスが`assets/sounds/`を指している
4. `assets/sounds/`に音源と`.import`が揃っている
5. **`.import`の`edit/loop_mode`が`0`（Disabled）である**
   - ⚠ **`.wav`に`smpl`チャンクがあると`1`（Forward）で取り込まれ、アラームが鳴り止まなくなる。** 実際に1回起きた（2026-08-14）。修正はGodotのインポートタブで`Loop Mode`を`Disabled`にして再インポート（**人間の作業**）

### 10-4. 将来コードを変えたときに見る項目（**UIから到達できないので人間の確認項目にしない**）

- 存在しない`sound_id`を`play_se()`に渡しても落ちない
- `Balance.sound`が未割当でも落ちない
- バス`SE`が無いとき`Master`で鳴る

---

## 11. 誰が何を書くか

| 対象 | 誰が |
|---|---|
| `autoload/sound_manager.gd`（新規） | 設計役 |
| `resources/balance/sound_config.gd` / `sound_entry.gd`（新規） | 設計役 |
| `scripts/utils/sound_ids.gd`（新規） | 設計役 |
| `autoload/balance.gd`への1行追加 | 設計役（13行の小さいファイル） |
| **`scenes/pomodoro/pomodoro.gd`の書き換え** | **設計役が全文を書く**（383行＝200行超。`WORKFLOW.md`「実装役に渡してよい仕事」） |
| Autoload登録・バス作成・音源配置・インポート・`.tres`作成・Inspector割当 | **人間** |
| 実機で聴く | **人間** |

**Godotを起動できないので、鳴ったかどうかを確かめられるのは人間だけ。** EXECには「どこを見れば／聴けば確認できるか」だけを書く。

---

## 12. EXECを書く前に読む必要があるファイル

- `scenes/pomodoro/pomodoro.gd`（全文。書き換えるため）
- `autoload/balance.gd`
- `resources/balance/pomodoro_config.gd` と `pomodoro_config.tres`（`.tres`の書き出され方の実例）
- `scripts/utils/state_keys.gd`（定数クラスの書き方を揃えるため）

---

## 13. 更新履歴

- 初版（2026-08-14）：音の第2層として新設。スコープB（共通の仕組み＋作業終了＋休憩終了）＋AudioBus3本で人間が決定。音源はユーザーが用意する形に決定
- 追記（2026-08-14・人間の承認時）：1〜7章の決定事項をすべて承認。**デバッグパネルに「残り1秒にする」ボタンを足す**要望を6-6として追加し、10-1の確認手段・9章の宿題に反映
