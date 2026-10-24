class_name SoundConfig
extends Resource

# 音の数値調整用Config。Balance経由でアクセスする（AGENTS.md 数値管理ルール）。
#
# .tres は @export の既定値と同じ値を書き出さないため、
# ここには必ず初期値を書いておくこと。

# ⚠⚠ 2026-10-24（回SE-1・人間「⚠ ２－１あ」）から読まない。⚠ 音の台帳は master/sounds.json へ移した。
#   ⚠ sound_config.tres に中身が残っているので欄だけ残す（⚠ 消すと .tres の読み込みで黄が出る）。
@export var entries: Array[SoundEntry] = []

# 同時発音数。⚠ それ以外（UI・ポモドーロ）の口＝SoundManager.play_ui_se()。
@export var se_player_count: int = 4

# ⚠ 戦闘の口（SoundManager.play_battle_se()）の同時発音数（回SE-1）。⚠ 当たりが重なるので多め。
@export var battle_player_count: int = 10

# ⚠ 同じ音を最低何秒空けるか（台帳の min_interval_sec を省いたときの値・回SE-1）。
#   ⚠ 実時間（倍速でも縮まない）。⚠ 0 でも「同じフレームに2回」は1回にまとめる。
@export var battle_min_interval_sec: float = 0.05
@export var ui_min_interval_sec: float = 0.0

# 起動時に各バスへ適用する初期音量。設定画面を作るときはここが既定値になる。
@export var master_volume_db: float = 0.0
@export var se_volume_db: float = 0.0
@export var bgm_volume_db: float = 0.0
