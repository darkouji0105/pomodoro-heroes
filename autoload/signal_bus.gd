extends Node

# 画面間通信のグローバルシグナル中継。
# 循環参照を避けるため、画面同士は直接参照せずSignalBus経由で通知する。

signal pomodoro_session_completed(reward_data: Dictionary)
signal battle_finished(result_data: Dictionary)
signal facility_tapped(facility_id: String)
signal character_tapped(character_id: String)
