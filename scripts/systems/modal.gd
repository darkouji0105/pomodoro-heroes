class_name Modal
extends RefCounted

# 汎用モーダルの静的な呼び出し口（PLAN_MODAL.md）。
# Autoload にはしない（AGENTS.md のAutoload5つ固定ルール）。
#
# 【設計上いちばん大事な点】
# ダイアログの実体は「表示するとき」ではなく「積むとき」に作る。
#
# 表示時に作る形にすると、confirm() が待つ相手を _current から取ることになり、
# すでに別のモーダルが出ているときに「前のモーダルが閉じた瞬間」に
# await が返ってしまう。確認ダイアログがまだ画面に出ていないのに
# false が返り、呼び出し側が先へ進む。
# 積むときに実体を作れば、待つ相手が最初から確定する。

const MODAL_SCENE: PackedScene = preload("res://scenes/ui/components/modal_dialog.tscn")

static var _current: ModalDialog = null
static var _queue: Array = []
static var _queue_scene: Node = null


# 通知。閉じるまで残る。
#
# 生成したダイアログを返す。閉じるまで待ちたい場合は
#   var d := Modal.notify(self, "key")
#   if d != null:
#       await d.closed
# と書く。戻り値を使わなくてよい呼び出しのほうが多いので、
# await を強制しない形にしている。
static func notify(caller: Node, message_key: String, format_args: Array = [], pause: bool = false) -> ModalDialog:
	return _enqueue(caller, message_key, format_args, false, pause)


# 確認。await で結果を受け取る。
# 「いいえ」「閉じる」「Escape」「画面遷移で消えた」はすべて false。
static func confirm(caller: Node, message_key: String, format_args: Array = [], pause: bool = false) -> bool:
	var dlg: ModalDialog = _enqueue(caller, message_key, format_args, true, pause)
	if dlg == null:
		# 表示できなかった場合は「いいえ」と同じ扱いにする。
		# ここで永久に待たせると、呼び出し側の await の先が実行されない。
		return false
	return await dlg.closed


# ダイアログの実体を作って、表示するかキューに積む。
# 作った実体を返す（confirm がこれを待つ）。
static func _enqueue(caller: Node, message_key: String, format_args: Array, is_confirm: bool, pause: bool) -> ModalDialog:
	if caller == null:
		push_warning("[Modal] caller is null")
		return null
	var tree: SceneTree = caller.get_tree()
	if tree == null:
		push_warning("[Modal] caller.get_tree() is null")
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		push_warning("[Modal] current_scene is null")
		return null

	# シーンが変わっていたら、前の画面のキューを捨てる。
	# 拠点で積んだ通知が戦闘画面で出てくると意味が分からない。
	if _queue_scene != null and _queue_scene != current_scene:
		_discard_queue()
	_queue_scene = current_scene

	var dlg: ModalDialog = MODAL_SCENE.instantiate()
	var item: Dictionary = {
		"dialog": dlg,
		"caller": caller,
		"message_key": message_key,
		"format_args": format_args,
		"is_confirm": is_confirm,
		"pause": pause,
	}

	if _current_is_alive():
		_queue.append(item)
	else:
		_show(item)
	return dlg


static func _show(item: Dictionary) -> void:
	var caller: Node = item.get("caller")
	if caller == null or not is_instance_valid(caller):
		_free_item(item)
		return
	var tree: SceneTree = caller.get_tree()
	if tree == null:
		_free_item(item)
		return
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		_free_item(item)
		return

	var dlg: ModalDialog = item.get("dialog")
	if dlg == null or not is_instance_valid(dlg):
		return

	# 翻訳は表示の直前に行う。キューに積まれている間に
	# 翻訳表が差し替わっても、出るときの内容が使われる。
	var translated: String = TranslationServer.translate(str(item.get("message_key", "")))
	var format_args: Array = item.get("format_args", [])
	var message: String = translated
	if not format_args.is_empty():
		message = translated % format_args

	_current = dlg
	_queue_scene = current_scene
	current_scene.add_child(dlg)
	dlg.closed.connect(_on_current_closed, CONNECT_ONE_SHOT)
	dlg.setup(message, bool(item.get("is_confirm", false)), bool(item.get("pause", false)))


# closed は _close() の中で emit される。emit の直後に次を表示しようとすると、
# 前のノードがまだ親にぶら下がったままで add_child が
# 「Parent node is busy setting up children」になる。
# 1フレーム遅らせて、破棄が終わってから次を出す。
static func _on_current_closed(_result: bool) -> void:
	_current = null
	_drain_queue.call_deferred()


static func _drain_queue() -> void:
	if _queue.is_empty():
		return
	if _current_is_alive():
		return
	var item: Dictionary = _queue.pop_front()

	var caller: Node = item.get("caller")
	if caller == null or not is_instance_valid(caller):
		_free_item(item)
		_discard_queue()
		return
	var tree: SceneTree = caller.get_tree()
	if tree == null:
		_free_item(item)
		_discard_queue()
		return
	var current_scene: Node = tree.current_scene
	if current_scene == null or _queue_scene != current_scene:
		_free_item(item)
		_discard_queue()
		return

	_show(item)


# キューを捨てる。積まれたまま表示されなかったダイアログは
# ツリーに入っていないので、queue_free ではなく free で解放する。
# 放置すると確認ダイアログを待っている await が永久に戻らないため、
# closed(false) を発火してから解放する。
static func _discard_queue() -> void:
	for item in _queue:
		if item is Dictionary:
			_free_item(item)
	_queue.clear()


static func _free_item(item: Dictionary) -> void:
	var dlg: Variant = item.get("dialog")
	if dlg == null or not (dlg is ModalDialog) or not is_instance_valid(dlg):
		return
	var d: ModalDialog = dlg
	if not d.is_inside_tree():
		d.emit_closed_once(false)
		d.free()


static func _current_is_alive() -> bool:
	return _current != null and is_instance_valid(_current)
