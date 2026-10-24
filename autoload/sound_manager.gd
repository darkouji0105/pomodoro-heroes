extends Node

# SoundManager
# 効果音の再生。Autoloadとして登録する（必ず末尾＝Balanceより後）。
#
# ⚠⚠ 口は2本（2026-10-24・回SE-1・人間「⚠ １あ」）：
#   play_battle_se(id) … 戦闘の音。⚠ バス SE_Battle ／ ⚠ 一時停止で止まる ／ ⚠ 戦闘を出たら stop_battle_se()
#   play_ui_se(id)     … それ以外（ボタン・窓・ポモドーロ）。⚠ バス SE_UI ／ ⚠ 一時停止中も鳴る（窓の音）
#   ⚠ 2本とも SE の下につながる＝設定の「効果音」のつまみが両方に効く。
#
# ⚠ 音の台帳は master/sounds.json（「２あ」）。⚠ 数値（同時発音数・既定の間引き）は Balance.sound（SoundConfig）。
# ⚠ 鳴らした記録（_history）を持つ＝検査は音を出さずに「呼ばれたか」を見る（set_muted）。
#
# 【落ちないこと】
# 音源が未設定でも、バスが無くても、警告を出して先へ進む。
# 素材の用意とコードの実装を分離するため。バス作成は人間の作業なので、
# 「実装が先・バスが後」の状態が必ず一度は発生する。
# そこで無音になると、原因が音源なのかバスなのか切り分けられない。

const MASTER_BUS_NAME: String = "Master"
const SE_BUS_NAME: String = "SE"
const BGM_BUS_NAME: String = "BGM"
const SE_BATTLE_BUS_NAME: String = "SE_Battle"
const SE_UI_BUS_NAME: String = "SE_UI"

const KIND_BATTLE: String = MasterDataLoader.SOUND_KIND_BATTLE
const KIND_UI: String = MasterDataLoader.SOUND_KIND_UI

# ⚠ 鳴らした記録の長さ（検査用）。
const HISTORY_SIZE: int = 64

var _config: SoundConfig = null
var _sounds: Dictionary = {} # { sound_id: 台帳の1行 }
var _streams: Dictionary = {} # { res のパス: AudioStream }（⚠ 初めて鳴らすときに読む）
var _players: Dictionary = {} # { kind: Array[AudioStreamPlayer] }
var _next_player_index: Dictionary = {} # { kind: int }
var _last_played: Dictionary = {} # { sound_id: { "msec": int, "frame": int } }
var _history: Array[Dictionary] = [] # [{ id, kind, msec }]
var _muted: bool = false


func _ready() -> void:
	# モーダルが get_tree().paused = true にしても鳴らせるようにする。
	# ⚠ 戦闘のプレイヤーだけ個別に PAUSABLE にする（_build_players）。
	process_mode = Node.PROCESS_MODE_ALWAYS

	_config = Balance.sound
	if _config == null:
		push_warning("[Sound] Balance.sound is not assigned. all sounds are disabled")
		return

	_build_sound_table()
	_apply_bus_volumes()
	_build_players(KIND_BATTLE, _config.battle_player_count, SE_BATTLE_BUS_NAME, Node.PROCESS_MODE_PAUSABLE)
	_build_players(KIND_UI, _config.se_player_count, SE_UI_BUS_NAME, Node.PROCESS_MODE_ALWAYS)

	print("[Sound] ready. sounds=%d battle_players=%d ui_players=%d" % [
		_sounds.size(), (_players[KIND_BATTLE] as Array).size(), (_players[KIND_UI] as Array).size()
	])


# --- 公開関数 ---

# 戦闘の音を1回鳴らす。sound_id は SoundIds の定数（⚠ 台帳の kind が battle のもの）。
func play_battle_se(sound_id: String) -> void:
	_play(KIND_BATTLE, sound_id)


# それ以外の音を1回鳴らす。sound_id は SoundIds の定数（⚠ 台帳の kind が ui のもの）。
func play_ui_se(sound_id: String) -> void:
	_play(KIND_UI, sound_id)


# ⚠ 回SE-1 より前からある口。⚠ play_ui_se() と同じ。
func play_se(sound_id: String) -> void:
	play_ui_se(sound_id)


# ⚠ 戦闘の音を全部止める。⚠ 戦闘の画面を出るとき（battle_controller._exit_tree）に呼ぶ。
func stop_battle_se() -> void:
	for player: AudioStreamPlayer in _players.get(KIND_BATTLE, []):
		player.stop()


func has_sound(sound_id: String) -> bool:
	return _sounds.has(sound_id)


# ⚠ 検査用：⚠ true のあいだは記録だけ取り、音は出さない
#   （⚠ ヘッドレスで鳴らすと終了時に「resources still in use」の赤が出る・2026-10-02）。
func set_muted(muted: bool) -> void:
	_muted = muted


# ⚠ 検査用：⚠ 鳴らした（⚠ 間引きを通った）記録。⚠ 古い順。
func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func clear_history() -> void:
	_history.clear()
	_last_played.clear()


# 設定の音量を変えたあとに呼ぶ（2026-09-28・設定の画面）。
func refresh_volumes() -> void:
	if _config == null:
		return
	_apply_bus_volumes()


# --- 内部 ---

func _play(kind: String, sound_id: String) -> void:
	if _config == null:
		return

	if not _sounds.has(sound_id):
		push_warning("[Sound] unknown sound_id: %s" % sound_id)
		return

	var row: Dictionary = _sounds[sound_id]
	var row_kind: String = str(row.get(MasterDataLoader.SOUND_KIND, ""))
	if row_kind != kind:
		push_warning("[Sound] %s is kind '%s' but played as '%s'" % [sound_id, row_kind, kind])
		return

	if _is_throttled(kind, sound_id, row):
		return

	var now_msec: int = Time.get_ticks_msec()
	_last_played[sound_id] = { "msec": now_msec, "frame": Engine.get_process_frames() }
	_history.append({ "id": sound_id, "kind": kind, "msec": now_msec })
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()

	if _muted:
		return

	var files: Array = row.get(MasterDataLoader.SOUND_FILES, [])
	if files.is_empty():
		push_warning("[Sound] no files for sound_id: %s" % sound_id)
		return
	var stream: AudioStream = _stream_of(str(files[randi() % files.size()]))
	if stream == null:
		return

	var player: AudioStreamPlayer = _pick_player(kind)
	if player == null:
		push_warning("[Sound] no player available for sound_id: %s" % sound_id)
		return

	var jitter: float = float(row.get(MasterDataLoader.SOUND_PITCH_JITTER, 0.0))
	player.stream = stream
	player.volume_db = float(row.get(MasterDataLoader.SOUND_VOLUME_DB, 0.0))
	player.pitch_scale = 1.0 + (randf_range(-jitter, jitter) if jitter > 0.0 else 0.0)
	player.play()
	# ⚠ 戦闘の音は数が多いのでログに出さない。
	if kind == KIND_UI:
		print("[Sound] play se=%s" % sound_id)


# ⚠ 同じフレームの2回目は必ず弾く。⚠ それ以外は min_interval_sec（実時間）で弾く。
func _is_throttled(kind: String, sound_id: String, row: Dictionary) -> bool:
	if not _last_played.has(sound_id):
		return false
	var last: Dictionary = _last_played[sound_id]
	if int(last["frame"]) == Engine.get_process_frames():
		return true
	var default_sec: float = _config.battle_min_interval_sec if kind == KIND_BATTLE else _config.ui_min_interval_sec
	var interval_sec: float = float(row.get(MasterDataLoader.SOUND_MIN_INTERVAL_SEC, default_sec))
	return interval_sec > 0.0 and Time.get_ticks_msec() - int(last["msec"]) < int(interval_sec * 1000.0)


func _stream_of(file: String) -> AudioStream:
	var path: String = MasterDataLoader.SOUND_FILES_DIR + file
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("[Sound] failed to load: %s" % path)
		return null
	_streams[path] = stream
	return stream


# ⚠ 台帳を読み、⚠ 書き間違い（kind・ファイルが無い）をここで黄にする（⚠ 鳴らす瞬間まで待たない）。
func _build_sound_table() -> void:
	var all: Dictionary = MasterDataLoader.get_all_sounds()
	for id: String in all:
		var row: Dictionary = all[id]
		var kind: String = str(row.get(MasterDataLoader.SOUND_KIND, ""))
		if kind != KIND_BATTLE and kind != KIND_UI:
			push_warning("[Sound] sounds.json: %s has unknown kind '%s'" % [id, kind])
			continue
		var files: Variant = row.get(MasterDataLoader.SOUND_FILES, [])
		if not (files is Array) or (files as Array).is_empty():
			push_warning("[Sound] sounds.json: %s has no files" % id)
			continue
		for file: Variant in files:
			var path: String = MasterDataLoader.SOUND_FILES_DIR + str(file)
			if not ResourceLoader.exists(path):
				push_warning("[Sound] sounds.json: %s file not found: %s" % [id, path])
		_sounds[id] = row


func _build_players(kind: String, count: int, bus_name: String, mode: Node.ProcessMode) -> void:
	var list: Array[AudioStreamPlayer] = []
	var bus: String = _resolve_bus_name(bus_name)
	for i in maxi(1, count):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "%sPlayer%d" % [kind.capitalize(), i]
		player.bus = bus
		player.process_mode = mode
		add_child(player)
		list.append(player)
	_players[kind] = list
	_next_player_index[kind] = 0


# バスが無い環境でも鳴るように SE → Master の順に逃がす。
func _resolve_bus_name(bus_name: String) -> String:
	for candidate: String in [bus_name, SE_BUS_NAME]:
		if AudioServer.get_bus_index(candidate) != -1:
			if candidate != bus_name:
				push_warning("[Sound] bus \"%s\" not found. falling back to \"%s\"" % [bus_name, candidate])
			return candidate
	push_warning("[Sound] bus \"%s\" not found. falling back to \"%s\"" % [bus_name, MASTER_BUS_NAME])
	return MASTER_BUS_NAME


# 空いているプレイヤーを優先し、全部埋まっていたら順番に上書きする。
func _pick_player(kind: String) -> AudioStreamPlayer:
	var list: Array = _players.get(kind, [])
	if list.is_empty():
		return null

	for player: AudioStreamPlayer in list:
		if not player.playing:
			return player

	var index: int = int(_next_player_index[kind])
	_next_player_index[kind] = (index + 1) % list.size()
	return list[index]


func _apply_bus_volumes() -> void:
	_set_bus_volume(MASTER_BUS_NAME, _config.master_volume_db, GameSettings.KEY_MASTER)
	_set_bus_volume(SE_BUS_NAME, _config.se_volume_db, GameSettings.KEY_SE)
	_set_bus_volume(BGM_BUS_NAME, _config.bgm_volume_db, GameSettings.KEY_BGM)


# ⚠ 基準の音量（`SoundConfig`）に、⚠ 遊ぶ人の設定の割合（`GameSettings`・0〜100%）を掛ける。⚠ 0% は消音。
func _set_bus_volume(bus_name: String, volume_db: float, setting_key: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("[Sound] bus not found: %s" % bus_name)
		return
	var pct: int = GameSettings.volume_pct(setting_key)
	AudioServer.set_bus_mute(index, pct <= 0)
	AudioServer.set_bus_volume_db(index, volume_db + (linear_to_db(float(pct) / 100.0) if pct > 0 else 0.0))
