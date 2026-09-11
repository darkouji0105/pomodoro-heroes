@tool
class_name UiButton
extends Button

# ボタンの4階層（2026-09-07）。⚠ `PrimaryButton` を置き換えたもの。
#
# ⚠ 見た目（色・角丸・余白）はこのスクリプトに1つも書かない。
#   ⚠ 持っているのは `theme/main_theme.tres` だけ。⚠ 値を変えるときは
#   `tools/build_theme.gd` を直して回し直す（AGENTS.md「Themeの扱い」）。
#
# ⚠ 既定は SECONDARY（静かな側）。⚠ PRIMARY を既定にしない。
#   ⚠ 指定し忘れたボタンが全部主張してしまうため。
# ⚠ SECONDARY は `theme_type_variation` を空にする＝基底 `Button` の見た目。
#   ⚠ こうすると素の `Button.new()` も同じ見た目になり、差し替え漏れが静かな側に倒れる。

enum Variant {
	SECONDARY, # 並列の選択肢（既定）
	PRIMARY, # ギルド側の主要動作。⚠ 1画面に1個まで
	GHOST, # 戻る・閉じる
	DANGER, # 危険・不可逆（冒険側）
}

# ⚠ Variant -> Theme の型 variation 名。⚠ 名前は `build_theme.gd` と揃えること。
const VARIATION_NAMES: Dictionary = {
	Variant.SECONDARY: &"",
	Variant.PRIMARY: &"PrimaryButton",
	Variant.GHOST: &"GhostButton",
	Variant.DANGER: &"DangerButton",
}

@export var variant: Variant = Variant.SECONDARY:
	set(value):
		variant = value
		_apply_variation()

# ボタンに表示するテキスト。tr()で翻訳を通す（AGENTS.md命名規則）。
# label_key に翻訳キーを入れると、tr()を通した文字列が text に反映される。
# 空のままにすれば、使う側が text プロパティを直接書き換えられる。
@export var label_key: String = "":
	set(value):
		label_key = value
		if is_inside_tree():
			text = tr(label_key)


# ⚠ `_init()` でも当てる理由：⚠ GDScript は宣言時の初期値代入で setter を呼ばない。
#   ⚠ `UiButton.new()` だけだと variation が空のまま `_ready()` まで残り、
#   ⚠ その間のサイズ計算（`get_combined_minimum_size()` など）が素の見た目で走る。
func _init() -> void:
	_apply_variation()


func _ready() -> void:
	# ⚠ シーンから読み込んだ場合はここで確定する（`_init()` の後に @export が入るため）。
	_apply_variation()
	if label_key != "":
		text = tr(label_key)


# ⚠ 生成しながら階層とラベルを渡す口（2026-09-07）。
# ⚠ `UiButton.create(UiButton.Variant.PRIMARY, "ui_forge")` と書ける。
# ⚠ 既定引数があるので `UiButton.create()` でも動く。
static func create(p_variant: Variant = Variant.SECONDARY, p_label_key: String = "") -> UiButton:
	var button: UiButton = UiButton.new()
	button.variant = p_variant
	button.label_key = p_label_key
	return button


func _apply_variation() -> void:
	theme_type_variation = VARIATION_NAMES.get(variant, &"")


# ⚠⚠ 面ぜんぶを押せるようにする「当たり」（2026-09-11）。
#
# ⚠ カードや一覧の行は**面ぜんぶが押せる**（人間のモック）。⚠ `PanelContainer` は
#   押せず、⚠ `Button` は器ではないので中身を並べられない。⚠ そこで透明なボタンを
#   面に重ねる（⚠ `PanelContainer` は子を全面に伸ばす）。
#
# ⚠⚠ **必ず中身を全部足し終わってから呼ぶこと。** ⚠ 当たりは**一番下に敷く**ので、
#   ⚠ 中身の器を `MOUSE_FILTER_PASS` にして押下を下へ通す必要があり、
#   ⚠ ここで在る子にしか当てられない。
# ⚠⚠ 一番上に重ねてはいけない（⚠ 2026-09-11 に踏んだ）。⚠ 上に置くと、
#   ⚠ 面の中に置いた本物のボタン（⚠ スキルの「外す」）が押せなくなる。
#   ⚠ 逆に下に敷いただけだと、⚠ 中身の器（既定は `MOUSE_FILTER_STOP`）が
#   ⚠ 押下を食べて**面が押せなくなる**＝⚠ 「枠を押しても行き先が変わらない」不具合になった。
# ⚠ `BaseButton` と `OptionButton` は `STOP` のまま残す（⚠ 自分で受け取るもの）。
static func attach_hit(panel: PanelContainer, handler: Callable) -> Button:
	var hit: Button = Button.new()
	hit.name = "Hit"
	hit.theme_type_variation = &"HitButton"
	if handler.is_valid():
		hit.pressed.connect(handler)
	panel.add_child(hit)
	panel.move_child(hit, 0)
	_pass_through(panel, hit)
	return hit


static func _pass_through(node: Node, hit: Button) -> void:
	for child: Node in node.get_children():
		if child == hit:
			continue
		if child is BaseButton:
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_pass_through(child, hit)
