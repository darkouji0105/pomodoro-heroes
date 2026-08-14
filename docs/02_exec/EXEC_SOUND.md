# 【実行指示書】音（第1弾：ポモドーロのアラーム）

**状態：未着手。**

第3層。対応する第2層は`PLAN_SOUND.md`（実コードと突き合わせ済み）。

**このタスクは実装役を使わない。** `pomodoro.gd`が383行＝200行超のため、`WORKFLOW.md`「実装役に渡してよい仕事」により設計役が書く。新規ファイルも同じ会話で書いたほうが整合が取れる。

| 誰 | 担当するファイル |
|---|---|
| **人間** | `.wav`のLoop修正 / `sound_config.tres`の作成とInspector割当 / Autoload登録 / `AGENTS.md`・`PROJECT_STATUS.md`の更新 / 実機で聴く |
| **設計役** | `sound_manager.gd` / `sound_config.gd` / `sound_entry.gd` / `sound_ids.gd`（新規4本）/ `balance.gd`（1行追加）/ `pomodoro.gd`（4箇所） |
| **実装役** | なし |

**`ja.csv`の編集は不要。** 今回追加する表示テキストはデバッグパネルのボタン1つだけで、既存のデバッグパネルと同じく`tr()`を通さない（開発者向けでリリースビルドには出ない）。

---

## 1. このタスクで実現すること

**作業タイマーと休憩タイマーが0になった瞬間にアラームが鳴る**ところまで。

同時に、**以降のSE/BGMが「呼ぶ行を足すだけ」になる共通の仕組み**（`SoundManager`）を作る。

音量設定UI・BGM・戦闘SE・UI SEは**含まない**。

---

## 2. 事故りやすい箇所（先に読むこと）

### 2-1. 休憩の**スキップボタンでは鳴らさない**

**今回いちばん間違えやすい箇所。** 休憩終了とスキップは**どちらも`_go_to_next_set()`を通る**。

```
タイマーが0になった  → _on_timer_finished() → State.BREAK → _go_to_next_set()
スキップボタンを押した → _on_break_skipped()               → _go_to_next_set()
```

**`_go_to_next_set()`や`_switch_view()`の中に再生を置くと、スキップしたときにも鳴る。** 自分で押したのだから鳴らしてはいけない。**`_on_timer_finished()`の`State.BREAK`分岐にだけ置く。**

### 2-2. `.wav`が**ループ状態で取り込まれている**（人間が直す）

`assets/sounds/*.wav.import`の`edit/loop_mode`が**`1`（Forward）**になっている。**このままだとアラームが鳴り止まない。**

`.wav`に`smpl`チャンクがあるとGodotが自動でこうする。**AIは`.import`を書かない。** 3-1で人間が直す。

### 2-3. `project.godot`に`audio/buses/...`の行は**出ない**

`res://default_bus_layout.tres`はGodotの**既定パス**なので、`project.godot`には書き出されない。**行が無いことを「バスが無い」と判断しないこと。** バスの実体は**プロジェクト直下の`default_bus_layout.tres`**（確認済み・`SE`と`BGM`が`Master`へ送られている）。

### 2-4. `.tres`は`@export`の既定値を書き出さない

`sound_config.gd`の`@export`には**すべて初期値を書いてある**。人間が`sound_config.tres`を作って音源を割り当てて保存すれば、`entries`の行だけが書き出される。**それで正しい。**

### 2-5. Autoloadの登録順を崩さない

`SoundManager`は`_ready()`で`Balance.sound`を読む。**`Balance`より後**でなければ`null`になる。**必ず末尾（6番目）に登録する。**

### 2-6. モーダルが`paused`にしても鳴るようにする

`ModalDialog`は`pause: true`のとき`get_tree().paused = true`にする。Autoloadも既定では止まるため、`SoundManager`と各`AudioStreamPlayer`に`process_mode = Node.PROCESS_MODE_ALWAYS`を設定する。**現状ポモドーロからその経路は無いが、将来SEを足したときに「モーダル中だけ鳴らない」で悩まないため。**

### 2-7. `state_keys.gd`は編集不要

音はセーブに何も足さない。`GameStateKeys`も`TransferKeys`も触らない。

### 2-8. `pomodoro.gd`のタイマー変数を直接書き換えない

冒頭6〜9行目のコメントのとおり、`time_left_sec` / `is_timer_active`を書き換えてよいのは`_start_phase_timer()` / `_stop_phase_timer()` / `_process()`のみ。**デバッグの「残り1秒」も`_start_phase_timer(1.0)`を呼ぶ形で書く。**

---

## 3. 人間がやる作業

### 3-1. `.wav`のLoop Modeを直す（**最優先。これをやらないと鳴り止まない**）

1. FileSystemで`assets/sounds/alarm_focus_end.wav`を選択 → **インポート**タブ
2. **Loop Mode** を `Disabled` に変更
3. 「再インポート」を押す
4. `alarm_break_end.wav`も同じ手順で

**確認**：`assets/sounds/alarm_focus_end.wav.import`をテキストエディタで開き、`edit/loop_mode=0`になっていること。

### 3-2. ファイルの保存（設計役から受け取る）

| パス | 内容 |
|---|---|
| `res://autoload/sound_manager.gd` | 新規 |
| `res://resources/balance/sound_config.gd` | 新規 |
| `res://resources/balance/sound_entry.gd` | 新規 |
| `res://scripts/utils/sound_ids.gd` | 新規 |
| `res://autoload/balance.gd` | 1行追加（13行 → 14行） |
| `res://scenes/pomodoro/pomodoro.gd` | 4箇所の変更（383行 → 約400行） |

**`.uid`ファイルは作らない。** Godotが自動生成する。

**保存後、`class_name`が認識されないエラーが出たらGodotを再起動する**（`AGENTS.md`「エラーを理由にルールを緩めない」）。型指定を`Node`に落とす回避をしないこと。

### 3-3. `sound_config.tres`を作る

1. FileSystemで`res://resources/balance/`を右クリック → 新規 → リソース → **`SoundConfig`** を選ぶ
2. ファイル名は **`sound_config.tres`**（snake_case）
3. Inspectorで`Entries`の配列サイズを **2** にする
4. 各要素に **`SoundEntry`** を新規作成し、下表のとおり設定する

| # | `Sound Id` | `Stream` | `Volume Db` |
|---|---|---|---|
| 0 | `alarm_focus_end` | `res://assets/sounds/alarm_focus_end.wav` | `0.0` |
| 1 | `alarm_break_end` | `res://assets/sounds/alarm_break_end.wav` | `0.0` |

**`Sound Id`の綴りは`sound_ids.gd`の定数と1文字も違ってはいけない。** 違うと「unknown sound_id」の警告が出て無音になる。

5. 保存する

### 3-4. `balance.tscn`に割り当てる

1. `res://autoload/balance.tscn`を開く
2. ルートノードのInspectorに **`Sound`** の欄が増えているので、`sound_config.tres`をドラッグして割り当てる
3. 保存する

**この割当を忘れると、起動時に`[Sound] Balance.sound is not assigned.`の警告が出て一切鳴らない。**

### 3-5. Autoloadを登録する

Project Settings → Autoload タブで追加する。

| 項目 | 値 |
|---|---|
| Path | `res://autoload/sound_manager.gd` |
| Node Name | `SoundManager` |

**必ず一番下（6番目）に置く。** 登録後、`project.godot`の`[autoload]`が次の並びになっていること。

```
Balance="*res://autoload/balance.tscn"
GameManager="*res://autoload/game_manager.gd"
SaveManager="*res://autoload/save_manager.gd"
SceneManager="*res://autoload/scene_manager.gd"
SignalBus="*res://autoload/signal_bus.gd"
SoundManager="*res://autoload/sound_manager.gd"
```

### 3-6. ドキュメントを更新する（実装が通ってから）

- **`AGENTS.md`**：「Autoload（シングルトン）一覧」の表に`SoundManager`を追加し、「AIはこの5つ以外」を **6つ** に直す。「Autoloadの登録順」にも`6. SoundManager`を追加する
- **`PROJECT_STATUS.md`**：宿題を2件追加する
  - `PomodoroConfig.reflection_time_limit_sec`と`reflection_min_chars`が使われていない（`pomodoro.gd`が`const`でハードコード）。**数値管理ルール違反。今回は直さない**
  - デバッグパネルの「残り1秒にする」ボタンは**リリース前に消す**（`debug_instant`・0Gスロット・`weapon_debug_blade`と同じ扱い）

---

## 4. 決めた数値

| 項目 | 値 | 根拠 |
|---|---|---|
| `se_player_count` | `4` | アラームだけなら1で足りるが、後のUI SEで連打すると音が切れる |
| `master_volume_db` | `0.0` | 起動時に各バスへ適用する初期値。**聴いてから人間が調整する** |
| `se_volume_db` | `0.0` | 同上 |
| `bgm_volume_db` | `0.0` | 同上。BGMは今回鳴らさないが、バスへの適用だけ先に通しておく |
| `SoundEntry.volume_db` | `0.0` | 音源ごとの補正。素材の音量差をコードを触らず吸収する |

**音量の調整は別の会話で行う。** 聴かないと決められない（`PROJECT_STATUS.md`「音とアニメーションの扱い」）。

---

## 5. 設計役が書くもの

### 5-1. `res://scripts/utils/sound_ids.gd`（新規）

```gdscript
class_name SoundIds

# 音のID。文字列リテラルを書かないための定数置き場。
# GameStateKeys / TransferKeys と同じ役割。
#
# ここの値と sound_config.tres の Sound Id は完全に一致していなければならない。
# 一致しないと play_se() が「unknown sound_id」の警告を出して無音になる。

const ALARM_FOCUS_END: String = "alarm_focus_end"
const ALARM_BREAK_END: String = "alarm_break_end"
```

### 5-2. `res://resources/balance/sound_entry.gd`（新規）

```gdscript
class_name SoundEntry
extends Resource

# 音1つぶんの定義。SoundConfig.entries の要素。

@export var sound_id: String = ""
@export var stream: AudioStream = null

# 音源ごとの音量補正。素材の音量差をコードを触らずに吸収するためのもの。
@export var volume_db: float = 0.0
```

### 5-3. `res://resources/balance/sound_config.gd`（新規）

```gdscript
class_name SoundConfig
extends Resource

# 音の数値調整用Config。Balance経由でアクセスする（AGENTS.md 数値管理ルール）。
#
# .tres は @export の既定値と同じ値を書き出さないため、
# ここには必ず初期値を書いておくこと。

@export var entries: Array[SoundEntry] = []

# 同時発音数。アラームだけなら1で足りるが、後のUI SEで連打すると音が切れる。
@export var se_player_count: int = 4

# 起動時に各バスへ適用する初期音量。設定画面を作るときはここが既定値になる。
@export var master_volume_db: float = 0.0
@export var se_volume_db: float = 0.0
@export var bgm_volume_db: float = 0.0
```

### 5-4. `res://autoload/sound_manager.gd`（新規）

```gdscript
extends Node

# SoundManager
# 効果音の再生。Autoloadとして登録する（必ず末尾＝Balanceより後）。
#
# 音源も数値もここには書かない。すべて Balance.sound（SoundConfig）が持つ。
#
# 【落ちないこと】
# 音源が未設定でも、バスが無くても、警告を出して先へ進む。
# 素材の用意とコードの実装を分離するため。バス作成は人間の作業なので、
# 「実装が先・バスが後」の状態が必ず一度は発生する。
# そこで無音になると、原因が音源なのかバスなのか切り分けられない。

const MASTER_BUS_NAME: String = "Master"
const SE_BUS_NAME: String = "SE"
const BGM_BUS_NAME: String = "BGM"

var _config: SoundConfig = null
var _entries: Dictionary = {} # { sound_id: SoundEntry }
var _se_players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0


func _ready() -> void:
	# モーダルが get_tree().paused = true にしても鳴らせるようにする。
	process_mode = Node.PROCESS_MODE_ALWAYS

	_config = Balance.sound
	if _config == null:
		push_warning("[Sound] Balance.sound is not assigned. all sounds are disabled")
		return

	_build_entry_table()
	_apply_bus_volumes()
	_build_se_players()

	print("[Sound] ready. entries=%d players=%d bus=%s" % [
		_entries.size(), _se_players.size(), _resolve_se_bus_name()
	])


# --- 公開関数 ---

# 効果音を1回鳴らす。sound_id は SoundIds の定数を渡すこと。
func play_se(sound_id: String) -> void:
	if _config == null:
		return

	if not _entries.has(sound_id):
		push_warning("[Sound] unknown sound_id: %s" % sound_id)
		return

	var entry: SoundEntry = _entries[sound_id]
	if entry.stream == null:
		push_warning("[Sound] stream is not set for sound_id: %s" % sound_id)
		return

	var player: AudioStreamPlayer = _pick_player()
	if player == null:
		push_warning("[Sound] no player available for sound_id: %s" % sound_id)
		return

	player.stream = entry.stream
	player.volume_db = entry.volume_db
	player.play()
	print("[Sound] play se=%s" % sound_id)


# --- 内部 ---

func _build_entry_table() -> void:
	for entry in _config.entries:
		if entry == null:
			push_warning("[Sound] null entry in SoundConfig.entries")
			continue
		if entry.sound_id == "":
			push_warning("[Sound] entry with empty sound_id is skipped")
			continue
		if _entries.has(entry.sound_id):
			push_warning("[Sound] duplicated sound_id: %s" % entry.sound_id)
			continue
		_entries[entry.sound_id] = entry


func _build_se_players() -> void:
	var count: int = maxi(1, _config.se_player_count)
	var bus_name: String = _resolve_se_bus_name()

	for i in count:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SePlayer%d" % i
		player.bus = bus_name
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_se_players.append(player)


# バスが無い環境でも鳴るように Master へ逃がす。
func _resolve_se_bus_name() -> String:
	if AudioServer.get_bus_index(SE_BUS_NAME) == -1:
		push_warning("[Sound] bus \"%s\" not found. falling back to \"%s\"" % [SE_BUS_NAME, MASTER_BUS_NAME])
		return MASTER_BUS_NAME
	return SE_BUS_NAME


# 空いているプレイヤーを優先し、全部埋まっていたら順番に上書きする。
func _pick_player() -> AudioStreamPlayer:
	if _se_players.is_empty():
		return null

	for player in _se_players:
		if not player.playing:
			return player

	var fallback: AudioStreamPlayer = _se_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _se_players.size()
	return fallback


func _apply_bus_volumes() -> void:
	_set_bus_volume(MASTER_BUS_NAME, _config.master_volume_db)
	_set_bus_volume(SE_BUS_NAME, _config.se_volume_db)
	_set_bus_volume(BGM_BUS_NAME, _config.bgm_volume_db)


func _set_bus_volume(bus_name: String, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("[Sound] bus not found: %s" % bus_name)
		return
	AudioServer.set_bus_volume_db(index, volume_db)
```

### 5-5. `res://autoload/balance.gd`（1行追加）

末尾に1行足すだけ。既存の行は触らない。

```gdscript
@export var adventure: AdventureConfig
@export var sound: SoundConfig
```

### 5-6. `res://scenes/pomodoro/pomodoro.gd`（4箇所）

**既存383行のうち、下記4箇所だけを変える。他は1文字も触らない。**

#### 変更1：作業終了で鳴らす（233行目付近）

変更前：

```gdscript
func _notify_focus_finished() -> void:
	DisplayServer.window_request_attention()
	print("[Pomodoro] focus finished - requested window attention")
```

変更後：

```gdscript
func _notify_focus_finished() -> void:
	SoundManager.play_se(SoundIds.ALARM_FOCUS_END)
	DisplayServer.window_request_attention()
	print("[Pomodoro] focus finished - requested window attention")
```

**この位置は`_switch_view(State.REFLECTION)`の直前＝振り返り120秒が始まる前。** 「猶予の開始と同時に鳴る」を自動的に満たす。

#### 変更2：休憩終了で鳴らす（169〜170行目付近）

変更前：

```gdscript
		State.BREAK:
			_go_to_next_set()
```

変更後：

```gdscript
		State.BREAK:
			_notify_break_finished()
			_go_to_next_set()
```

**⚠ `_go_to_next_set()`の中に入れないこと。** スキップボタン（`_on_break_skipped()`）も同じ関数を通るため、押したときにも鳴ってしまう（2-1）。

#### 変更3：`_notify_break_finished()`を新設（`_notify_focus_finished()`の直後）

```gdscript
# 休憩終了を知らせる。休憩明けは自動開始せず「開始」ボタン待ちで止まるため、
# ここで気づけないとセッションが止まりっぱなしになる。
# スキップボタン経由では鳴らさない（自分で押したので終わりは分かっている）。
func _notify_break_finished() -> void:
	SoundManager.play_se(SoundIds.ALARM_BREAK_END)
	DisplayServer.window_request_attention()
	print("[Pomodoro] break finished - requested window attention")
```

#### 変更4：デバッグパネルに「残り1秒にする」を足す

`_build_debug_panel()`の`skip_button`を追加している箇所の**直後**に足す。

```gdscript
	var one_sec_button: Button = Button.new()
	one_sec_button.text = "残り1秒にする"
	one_sec_button.pressed.connect(_on_debug_one_second)
	panel.add_child(one_sec_button)
```

ハンドラは`_on_debug_skip_phase()`の直後に足す。

```gdscript
# 残り1秒にする。アラームの確認用。
# 「このフェーズを終わらせる」は _on_timer_finished() を直接呼ぶため
# _process() を通らず、本番と同じ経路にならない。音の確認にはこちらを使う。
func _on_debug_one_second() -> void:
	if not is_timer_active:
		print("[Debug] タイマーが動いていません（開始ボタン待ちの可能性）")
		return
	_start_phase_timer(1.0)
	print("[Debug] 残り1秒にしました")
```

**`time_left_sec`を直接代入しない。** 冒頭6〜9行目の決まりに従い`_start_phase_timer()`を通す（2-8）。

---

## 6. 作業の順番

1. **人間**：3-1（`.wav`のLoop修正）
2. **設計役**：5-1〜5-3の新規3ファイルを書く（`class_name`が先に無いと5-4がパースエラーになる）
3. **人間**：保存 → Godotを再起動して`class_name`を認識させる
4. **設計役**：5-4（`sound_manager.gd`）と5-5（`balance.gd`）を書く
5. **人間**：保存 → 3-3（`sound_config.tres`作成）→ 3-4（`balance.tscn`に割当）→ 3-5（Autoload登録）
6. **設計役**：5-6（`pomodoro.gd`の4箇所）
7. **人間**：§7〜§9で確認する
8. **人間**：3-6（ドキュメント更新）→ コミット

**5より前に6をやらない。** `SoundManager`がAutoloadに無い状態で`pomodoro.gd`が`SoundManager.play_se()`を書くと、識別子が見つからずパースエラーになる。

---

## 7. 完了条件：音（人間が実機で確かめる）

**確認の道具**：デバッグパネルの**「残り1秒にする」**。25分・5分を待たずに、**本番と同じ`_process()`の経路で**0秒到達を再現できる。「このフェーズを終わらせる」は経路が違うので音の確認に使わない。

1. 作業タイマーが0になった瞬間にアラームが鳴る
2. 鳴ってから振り返り入力の画面が出るまでに、気づける余地がある
3. 休憩タイマーが0になった瞬間にアラームが鳴る
4. **休憩のスキップボタンを押したときは鳴らない**
5. 音量が過大でない（**調整は別の会話でよい**）
6. **アラームが鳴り止む**（ループしていない。3-1をやっていれば満たされる）

---

## 8. 完了条件：ログ（Godotの出力パネル）

1. 作業終了1回につき`[Sound] play se=alarm_focus_end`が**1行だけ**出る（**二重再生していない**）
2. 休憩終了1回につき`[Sound] play se=alarm_break_end`が**1行だけ**出る
3. 音源を割り当てない状態で起動すると、再生時に警告が出て**ゲームは続行する**
4. 起動時に`[Sound] ready. entries=2 players=4 bus=SE`が出る（**`bus=Master`と出たらバスを読めていない**）

---

## 9. 完了条件：ファイル（テキストエディタで開く）

1. `project.godot`の`[autoload]`に`SoundManager`が**6番目**に入っている
2. **プロジェクト直下**に`default_bus_layout.tres`があり、`SE`と`BGM`が`Master`へ送られている
   - ⚠ **`project.godot`に`audio/buses/default_bus_layout`の行は出ない**（2-3）。行が無いことを不具合と判断しないこと
3. `sound_config.tres`に`entries`が書き出されており、`stream`のパスが`assets/sounds/`を指している
4. `assets/sounds/`に音源と`.import`が揃っている
5. **`.import`の`edit/loop_mode`が`0`（Disabled）である**

---

## 10. UIから到達できない項目（人間は確認しない）

**将来コードを変えたときに見る項目。** 画面から実行できないので完了条件にしない。

- 存在しない`sound_id`を`play_se()`に渡しても落ちない
- `Balance.sound`が未割当でも落ちない
- バス`SE`が無いとき`Master`で鳴る
- `entries`に同じ`sound_id`が2つあると警告が出て後者が無視される

---

## 11. 併せて直さないもの

- **`PomodoroConfig.reflection_time_limit_sec`と`reflection_min_chars`が使われていない。** `pomodoro.gd`が`const REFLECTION_TIME_LIMIT_SEC: float = 120.0`をハードコードしている。**数値管理ルール違反だが今回は直さない**（`CLAUDE.md`「ついでにこれもをやらない」）。3-6で宿題に追加する

---

## 12. このタスクで残した宿題

- デバッグパネルの「残り1秒にする」ボタンは**リリース前に消す**
- 音量設定UI・ミュート（設定画面を作る回に、セーブ構造ごと決める）
- BGMの再生（`play_bgm()`は今回作らない。バスだけ用意済み）
- 戦闘SE・UI SE（`SoundManager.play_se()`を呼ぶ行と`SoundIds`の定数を足すだけ）
- ウィンドウ非フォーカス時に鳴らすか、`window_request_attention()`を残すか（音を聴いてから人間が判断する）
