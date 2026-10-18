class_name ResearchConfig
extends Resource

# 研究ツリー関連の数値調整用Config（最小スケルトン）。
# 詳細なノード構成・解放コストは各ギルドEXECで拡張する。

@export var unlock_material_id: String
@export var base_unlock_cost: int

# ⚠⚠ 10-18（回UI-1018-7・web版の手本 `04_research_*.png`）。
# ⚠ 次のボードを開くのに、前のボードで開く割合（%・切り上げ）。⚠ 12件なら 8（⚠ 手本「ボード1を8つ開くと開く」・人間「い」）。
@export var board_open_pct: int = 66
# ⚠ ボードを全部開いたときの「完成の報酬」（⚠ 宝石・素材・金で仮＝人間「あ」）。⚠ {ボード番号: {gold, gems, materials: {素材ID: 数}}}。
#   ⚠ 仲間・称号は無い（⚠ できたらこの表に欄を足す）。
@export var board_rewards: Dictionary = {
	1: {"gold": 300, "gems": 50, "materials": {"forging_material_2": 20, "training_material_2": 20}},
	2: {"gold": 600, "gems": 100, "materials": {"forging_material_3": 20, "training_material_3": 20}},
}
# ⚠ 自動で研究の「素材を残す」の札（⚠ 手本 残さない／10／30／50）と、はじめの値。
@export var auto_keep_choices: Array[int] = [0, 10, 30, 50]
@export var auto_keep_default: int = 10
