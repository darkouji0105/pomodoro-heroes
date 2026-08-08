class_name GameStateKeys
extends RefCounted

# GameManager.get_state() が返すDictionaryのトップレベルキー。
# DATA_SCHEMA.md の各項目に対応。文字列リテラルではなくこの定数経由で組み立てる。

const GOLD: String = "gold"
const GEMS: String = "gems"
const STAMINA: String = "stamina"
const MATERIALS: String = "materials"
const INVENTORY: String = "inventory"
const PENDING_CHESTS: String = "pending_chests"
const UNLOCKED_SCREENS: String = "unlocked_screens"
const SCENARIO_CHAPTER: String = "scenario_chapter"
const BOSS_UNLOCKED: String = "boss_unlocked"
const PITY_COUNTERS: String = "pity_counters"
const TOTAL_POMODORO_COMPLETED: String = "total_pomodoro_completed"
const LAST_POMODORO_END_AT: String = "last_pomodoro_end_at"
const SAVE_VERSION: String = "save_version"
const LAST_SAVED_AT: String = "last_saved_at"
const STORY: String = "story"
const TRAINING_MODE_UNLOCKED: String = "training_mode_unlocked"
const CODEX: String = "codex"
const DAILY_SHOP: String = "daily_shop"
const WEEKLY_SHOP: String = "weekly_shop"
const MONTHLY_SHOP: String = "monthly_shop"
const CHARACTER_GROWTH: String = "character_growth"
const RESEARCH_TREE: String = "research_tree"
const RECIPES_UNLOCKED: String = "recipes_unlocked"
const CRAFTING_QUEUE: String = "crafting_queue"
