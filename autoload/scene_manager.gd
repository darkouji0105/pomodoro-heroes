extends Node

# 画面遷移の一元管理。
# 各シーンのスクリプトから get_tree().change_scene_to_file() を直接呼ばせない。

var _transfer_data: Dictionary = {}
var _history: Array[String] = []

# ⚠ ここから _spawn_debug_overlay() の終わりまでは検証用。リリース前に消す。
# 消すのはこの _ready() と _spawn_debug_overlay()、それと res://tests/debug_overlay.gd の3つだけ。
#
# 画面を持たない Autoload の中でいちばん「画面の器」に近いのが SceneManager なので、
# ここに置いている。新しい Autoload を足すと project.godot と登録順のルール
# （AGENTS.md「Autoloadの登録順」）を触ることになり、消すときの手数が増える。
const DEBUG_OVERLAY_SCRIPT: GDScript = preload("res://tests/debug_overlay.gd")


func _ready() -> void:
	# ⚠⚠ 演出の面は**リリースでも要る**ので、⚠ デバッグの早期 return より前に作る
	#   （2026-09-09。⚠ 下の `if` の後ろに書くと、⚠ 製品版で演出が黙って出なくなる）。
	# ⚠ 理由は DebugOverlay と同じ：⚠ root に付けるので画面が入れ替わっても残る。
	#   ⚠ Autoload を増やさずに「全画面から呼べる1つ」を用意するための置き場。
	_spawn_resource_gain_effect.call_deferred()
	# ⚠ 通貨3つの表示も画面をまたいで常駐させる（2026-09-09・人間の指示
	#   「⚠ ページをまたぐコンポーネントにするところからだと思う」）。
	_spawn_resource_hud.call_deferred()
	# ⚠ 画面の上の小さな知らせ（2026-10-07・`Toast`）。⚠ リリースでも要る。
	_spawn_toast.call_deferred()
	# ⚠ 遊ぶ人の設定の「全画面」（2026-09-28・`GameSettings`・`BS-13`）。⚠ リリースでも要る＝デバッグの早期 return より前。
	_apply_display_setting.call_deferred()

	if not OS.is_debug_build():
		return
	# root の子として足す。current_scene ではなく root に付けるので、
	# change_scene_to_file() で画面が入れ替わってもオーバーレイは残る。
	#
	# call_deferred なのは、Autoload の _ready() の時点では
	# root の構築（メインシーンの追加）がまだ終わっていないため。
	_spawn_debug_overlay.call_deferred()


# ⚠ リソースが増えたときの演出の面（2026-09-09）。⚠ 検証用ではない。消さないこと。
func _spawn_resource_gain_effect() -> void:
	ResourceGainEffect.spawn_into(get_tree().root)
	print("[SceneManager] ResourceGainEffect を生成した")


# ⚠ 右上の通貨（2026-09-09）。⚠ 検証用ではない。消さないこと。
func _apply_display_setting() -> void:
	GameSettings.apply_display()


func _spawn_toast() -> void:
	var _toast: Toast = Toast.spawn_into(get_tree().root)


func _spawn_resource_hud() -> void:
	ResourceHud.spawn_into(get_tree().root)
	print("[SceneManager] ResourceHud を生成した")


func _spawn_debug_overlay() -> void:
	# スクリプトが CanvasLayer を継承しているので、.new() で CanvasLayer が返る。
	var overlay: CanvasLayer = DEBUG_OVERLAY_SCRIPT.new()
	overlay.name = "DebugOverlay"
	get_tree().root.add_child(overlay)
	print("[SceneManager] DebugOverlay を生成した（[F4] で表示）")

func change_scene(scene_path: String) -> void:
	print("[SceneManager] change_scene -> %s" % scene_path)
	_return_stack.clear()
	_return_provider = Callable()
	_record_history()
	# ⚠ 右上の通貨は既定で出す（2026-09-09）。⚠ 隠したい画面が自分の `_ready()` で消す。
	#   ⚠ ここで戻さないと、⚠ ポモドーロから抜けたあと通貨が消えたままになる。
	ResourceHud.set_shown(true)
	# ⚠ 画面を移るたびに自動セーブ（2026-10-05・回P-1・⚠ 遊んでいる最中だけ＝`SaveManager.autosave()`）。
	SaveManager.autosave()
	get_tree().change_scene_to_file(scene_path)


# ⚠⚠ 寄り道（2026-10-06・拠点の遷移の見直し・`NAV-18`）。
#   ⚠ 「育成 → 鍛冶場 → 戻る」で本部へ飛ばされ、⚠ キャラ・タブ・依頼を選び直していた。
#   ⚠ 寄り道で開くときは**戻り先（画面と、そこへ渡すデータ）を積む**。⚠ 開いた画面の「戻る」は `go_back_or()` で積んだ先へ。
#   ⚠ 積んだものは**ふつうの遷移（`change_scene*`）で全部捨てる**＝⚠ 施設の帯・出撃・タイトルで切れる（⚠ 古い戻り先が残らない）。
#   ⚠ 入れ子は積み重なる（⚠ 記録 → 育成 → 鍛冶場 → 戻る → 育成 → 戻る → 記録）。
var _return_stack: Array[Dictionary] = []
const _RETURN_PATH_KEY: String = "path"
const _RETURN_DATA_KEY: String = "data"


func open_detour(scene_path: String, data: Dictionary, return_path: String, return_data: Dictionary = {}) -> void:
	print("[SceneManager] open_detour -> %s (return %s)" % [scene_path, return_path])
	_return_stack.push_back({_RETURN_PATH_KEY: return_path, _RETURN_DATA_KEY: return_data.duplicate(true)})
	_go_keeping_returns(scene_path, data)


# ⚠ 寄り道から戻る。⚠ 積んでいなければ `default_path` へ（⚠ 施設の帯から来たときの今までの戻り先）。
#   ⚠ `override` は戻り先のデータに上書きする（⚠ 昇級のあと「ノードへ」のように戻るタブだけ変えたいとき）。
func go_back_or(default_path: String, override: Dictionary = {}) -> void:
	if _return_stack.is_empty():
		if override.is_empty():
			change_scene(default_path)
		else:
			change_scene_with_data(default_path, override)
		return
	var entry: Dictionary = _return_stack.pop_back()
	var data: Dictionary = (entry.get(_RETURN_DATA_KEY, {}) as Dictionary).duplicate(true)
	data.merge(override, true)
	print("[SceneManager] go_back_or -> %s" % str(entry.get(_RETURN_PATH_KEY, "")))
	_go_keeping_returns(str(entry.get(_RETURN_PATH_KEY, default_path)), data)


# ⚠ 同じ施設の中でタブが別の画面になっているもの（⚠ 鍛冶場の「鍛える」⇔「作る」）。⚠ 戻り先を捨てない。
func swap_scene(scene_path: String, data: Dictionary = {}) -> void:
	_go_keeping_returns(scene_path, data)


func has_return() -> bool:
	return not _return_stack.is_empty()


# ⚠⚠ いまの画面の「戻ってきたときの姿」（2026-10-07）。⚠ 右上の通貨・見出しの素材の「＋」は画面の状態を知らないので、
#   ⚠ 画面が自分の `_ready()` で口を預けておく（⚠ 預けていなければ空＝今までどおり素の姿で開き直す）。
#   ⚠ 画面を移るたびに捨てる（⚠ 前の画面の口を呼ばない）。⚠ 入手先の窓（`ItemSourceWindow.open()`）が使う。
var _return_provider: Callable = Callable()


# ⚠⚠ 画面の覚え（2026-10-07・回UI-便 H）：⚠ タブ・並べ替え・絞り込みを、画面を出て戻っても同じに。
#   ⚠ 遊んでいるあいだだけ（⚠ セーブには書かない＝起動し直すと既定）。⚠ 鍵は `TransferKeys.MEMORY_*`。
#   ⚠ 渡されたデータ（寄り道から戻る・入手先の窓から戻る）があればそちらが勝つ（⚠ 画面の側で先に見る）。
var _ui_memory: Dictionary = {}


func remember(key: String, value: Variant) -> void:
	_ui_memory[key] = value


func recall(key: String, fallback: Variant) -> Variant:
	return _ui_memory.get(key, fallback)


func set_return_data_provider(provider: Callable) -> void:
	_return_provider = provider


func current_return_data() -> Dictionary:
	if not _return_provider.is_valid():
		return {}
	var data: Variant = _return_provider.call()
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func _go_keeping_returns(scene_path: String, data: Dictionary) -> void:
	_transfer_data = data.duplicate(true)
	_return_provider = Callable()
	_record_history()
	ResourceHud.set_shown(true)
	SaveManager.autosave()
	get_tree().change_scene_to_file(scene_path)

func go_back() -> void:
	# 履歴管理は最小実装（ダミー扱い。PLANで「実装時に決める」と未確定のため）
	print("[SceneManager] go_back (dummy history)")
	if _history.is_empty():
		print("[SceneManager] no history to go back to")
		return
	var prev: String = _history.pop_back()
	get_tree().change_scene_to_file(prev)

func change_scene_with_data(scene_path: String, data: Dictionary) -> void:
	# _transfer_dataをセットしてからchange_sceneと同様の遷移を行う
	print("[SceneManager] change_scene_with_data -> %s, data=%s" % [scene_path, data])
	_transfer_data = data.duplicate(true)
	_return_stack.clear()
	_return_provider = Callable()
	_record_history()
	# ⚠ 右上の通貨は既定で出す（2026-09-09）。⚠ 隠したい画面が自分の `_ready()` で消す。
	#   ⚠ ここで戻さないと、⚠ ポモドーロから抜けたあと通貨が消えたままになる。
	ResourceHud.set_shown(true)
	# ⚠ 画面を移るたびに自動セーブ（2026-10-05・回P-1・⚠ 遊んでいる最中だけ＝`SaveManager.autosave()`）。
	SaveManager.autosave()
	get_tree().change_scene_to_file(scene_path)

func consume_transfer_data() -> Dictionary:
	# 取り出すと同時に_transfer_dataを空にする（次の遷移に前回データが混ざらないようにするため）
	var data: Dictionary = _transfer_data.duplicate(true)
	_transfer_data.clear()
	print("[SceneManager] consume_transfer_data -> %s (now empty: %s)" % [data, _transfer_data])
	return data

func _record_history() -> void:
	var tree: SceneTree = get_tree()
	if tree.current_scene != null:
		var path: String = tree.current_scene.scene_file_path
		if path != "":
			_history.push_back(path)
