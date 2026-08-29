class_name SoundEntry
extends Resource

# 音1つぶんの定義。SoundConfig.entries の要素。

@export var sound_id: String = ""
@export var stream: AudioStream = null

# 音源ごとの音量補正。素材の音量差をコードを触らずに吸収するためのもの。
@export var volume_db: float = 0.0
