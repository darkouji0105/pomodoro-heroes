class_name SoundIds

# 音のID。文字列リテラルを書かないための定数置き場。
# GameStateKeys / TransferKeys と同じ役割。
#
# ここの値と sound_config.tres の Sound Id は完全に一致していなければならない。
# 一致しないと play_se() が「unknown sound_id」の警告を出して無音になる。

const ALARM_FOCUS_END: String = "alarm_focus_end"
const ALARM_BREAK_END: String = "alarm_break_end"
