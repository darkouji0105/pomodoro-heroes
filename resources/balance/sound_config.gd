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
