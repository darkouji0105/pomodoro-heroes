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
