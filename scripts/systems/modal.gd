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

# 窓の追加の指定（2026-09-08・段階⑤-③・台帳の決定39）。
#
# ⚠ 位置引数を増やさずに Dictionary にしてある（⚠ 3つとも「使わない呼び出し」のほうが多い）。
# ⚠ 綴りを呼ぶ側に書かせないための定数。⚠ `ModalDialog.setup()` が同じキーで読む。
const OPTION_TITLE: String = "title"          # 窓の見出し（⚠ 翻訳済みの文字列）
const OPTION_CONTENT: String = "content"      # 窓の中に入れる Control（⚠ 1つだけ）
const OPTION_CLOSE_LABEL: String = "close_label_key"  # 閉じるボタンの翻訳キー
# ⚠⚠ 2026-09-21（決定 `MD-3` / `MD-5` / `MD-6`）。⚠ 値は `ModalDialog.WIDTH_*` / `DIM_*`。
const OPTION_WIDTH: String = "width"                  # 窓の幅（小・中・大）
const OPTION_DIM: String = "dim"                      # 暗幕の濃さ（なし・60%・72%）
const OPTION_DANGER: String = "danger"                # ⚠ 実行のボタンを赤に（取り返しのつかない確認）
const OPTION_CONFIRM_LABEL: String = "confirm_label_key"  # ⚠ 「はい」の文言（⚠ 「消す」「捨てる」など）

# ⚠ 呼ぶ側が綴りを書かないための持ち出し（⚠ `ModalDialog` の定数と同じ字）。
const WIDTH_TINY: String = ModalDialog.WIDTH_TINY
const WIDTH_SMALL: String = ModalDialog.WIDTH_SMALL
const WIDTH_MEDIUM: String = ModalDialog.WIDTH_MEDIUM
const WIDTH_LARGE: String = ModalDialog.WIDTH_LARGE
const DIM_NONE: String = ModalDialog.DIM_NONE
const DIM_NORMAL: String = ModalDialog.DIM_NORMAL
const DIM_HEAVY: String = ModalDialog.DIM_HEAVY

static var _current: ModalDialog = null
static var _queue: Array = []
static var _queue_scene: Node = null
# ⚠⚠ 窓が続けて出るときの間（ミリ秒・決定 `MD-8`）。⚠ 値は Theme（`Window/queue_gap_ms`）。
#   ⚠ **ツリーに入っている窓からしか引けない**（⚠ 積んであるだけの窓は `@onready` が null）。
#   ⚠ だから「出したとき」に控えておく（⚠ 2026-09-21 に `base_chest` が赤になって気づいた）。
static var _queue_gap_ms_cache: int = 0


# 通知。閉じるまで残る。
#
# 生成したダイアログを返す。閉じるまで待ちたい場合は
#   var d := Modal.notify(self, "key")
#   if d != null:
#       await d.closed
# と書く。戻り値を使わなくてよい呼び出しのほうが多いので、
# await を強制しない形にしている。
static func notify(
	caller: Node,
	message_key: String,
	format_args: Array = [],
	pause: bool = false,
	options: Dictionary = {}
) -> ModalDialog:
	return _enqueue(caller, message_key, format_args, false, pause, options)


# 確認。await で結果を受け取る。
# 「いいえ」「閉じる」「Escape」「画面遷移で消えた」はすべて false。
static func confirm(
	caller: Node,
	message_key: String,
	format_args: Array = [],
	pause: bool = false,
	options: Dictionary = {}
) -> bool:
	var dlg: ModalDialog = _enqueue(caller, message_key, format_args, true, pause, options)
	if dlg == null:
		# 表示できなかった場合は「いいえ」と同じ扱いにする。
		# ここで永久に待たせると、呼び出し側の await の先が実行されない。
		return false
	return await dlg.closed


# ダイアログの実体を作って、表示するかキューに積む。
# 作った実体を返す（confirm がこれを待つ）。
static func _enqueue(
	caller: Node,
	message_key: String,
	format_args: Array,
	is_confirm: bool,
	pause: bool,
	options: Dictionary = {}
) -> ModalDialog:
	if caller == null:
		push_warning("[Modal] caller is null")
		_free_option_content(options)
		return null
	var tree: SceneTree = caller.get_tree()
	if tree == null:
		push_warning("[Modal] caller.get_tree() is null")
		_free_option_content(options)
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		push_warning("[Modal] current_scene is null")
		_free_option_content(options)
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
		"options": options,
	}

	if _current_is_alive():
		_queue.append(item)
	else:
		_show(item)
	return dlg


static func _show(item: Dictionary) -> void:
	# ⚠⚠ 型付きの変数へ先に入れない（2026-09-16）。⚠ 呼び出し元が既に消えていると、
	#   ⚠ `is_instance_valid()` で確かめる前の**代入そのもの**が赤になる
	#   （⚠ "Trying to assign invalid previously freed instance"）。
	var caller_value: Variant = item.get("caller")
	# ⚠ `is` も消えたインスタンスには使えない（⚠ "Left operand of 'is' is a previously freed instance"）。
	#   ⚠ 生きているかを先に見る（⚠ `is_instance_valid()` は消えていても安全）。
	if not is_instance_valid(caller_value) or not (caller_value is Node):
		_free_item(item)
		return
	var caller: Node = caller_value
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
	# ⚠⚠ 呼んだノードが別の窓（⚠ 倉庫の窓）の中にいれば、⚠ その窓に出す（2026-09-15）。
	#   ⚠ current_scene に付けると、⚠ 別窓で押した確認がゲームの窓の後ろに出る。
	var caller_window: Window = caller.get_window()
	if caller_window != null and caller_window != tree.root:
		caller_window.add_child(dlg)
	else:
		current_scene.add_child(dlg)
	# ⚠ ツリーに入った今なら Theme を引ける。⚠ 次に閉じるときのために控える（決定 `MD-8`）。
	_queue_gap_ms_cache = dlg.queue_gap_ms()
	dlg.closed.connect(_on_current_closed, CONNECT_ONE_SHOT)
	dlg.setup(
		message,
		bool(item.get("is_confirm", false)),
		bool(item.get("pause", false)),
		item.get("options", {})
	)


# closed は _close() の中で emit される。emit の直後に次を表示しようとすると、
# 前のノードがまだ親にぶら下がったままで add_child が
# 「Parent node is busy setting up children」になる。
# 1フレーム遅らせて、破棄が終わってから次を出す。
# ⚠⚠ 閉じてから次を出すまでに間を置く（2026-09-21・決定 `MD-8`）。
#   ⚠ 間が無いと「窓は残ったまま中身だけ替わった」ように見えて、⚠ 次の知らせに気づかない
#   （⚠ 09-20 の「⚠ 地味すぎてわからない」と同じ失敗）。
# ⚠ 値は Theme（`Window/queue_gap_ms`）。⚠ ここに数字を書かない。
static func _on_current_closed(_result: bool) -> void:
	var gap_ms: int = _queue_gap_ms()
	_current = null
	if _queue.is_empty() or gap_ms <= 0:
		_drain_queue.call_deferred()
		return
	var tree: SceneTree = _queue_scene.get_tree() if is_instance_valid(_queue_scene) else null
	if tree == null:
		_drain_queue.call_deferred()
		return
	# ⚠ `timeout` は名前付きの関数につなぐ（⚠ 無名関数は捕まえた相手が消えると赤になる）。
	tree.create_timer(float(gap_ms) / 1000.0).timeout.connect(_drain_queue)


# ⚠ 間の長さ。⚠ 出したときに控えた値を返す（⚠ 上の `_queue_gap_ms_cache` の注記）。
static func _queue_gap_ms() -> int:
	return _queue_gap_ms_cache


static func _drain_queue() -> void:
	if _queue.is_empty():
		return
	if _current_is_alive():
		return
	var item: Dictionary = _queue.pop_front()

	# ⚠ 上の `_show()` と同じ理由で、⚠ 確かめてから型付きの変数へ入れる。
	var caller_value: Variant = item.get("caller")
	# ⚠ 上の `_show()` と同じ。⚠ 生きているかを先に見てから `is` を使う。
	if not is_instance_valid(caller_value) or not (caller_value is Node):
		_free_item(item)
		_discard_queue()
		return
	var caller: Node = caller_value
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
	# ⚠ 窓に入れる前の中身は、⚠ 誰の子でもない＝⚠ 捨てないと漏れる。
	_free_option_content(item.get("options", {}))


# 窓に入らなかった中身を解放する。⚠ ツリーに入っていないので queue_free ではなく free。
static func _free_option_content(options: Dictionary) -> void:
	var content: Variant = options.get(OPTION_CONTENT, null)
	if content is Node and is_instance_valid(content as Node) and not (content as Node).is_inside_tree():
		(content as Node).free()


static func _current_is_alive() -> bool:
	return _current != null and is_instance_valid(_current)
