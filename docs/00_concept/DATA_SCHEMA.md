# データスキーマ

各画面（箱）ごとのセーブデータ構造。Godot実装時はAutoload（GameManager等）が保持する想定。

---

## 1. 拠点（共通データ）

全画面から参照される、いわばSingle Source of Truth。

```json
{
  "gold": 0,
  "gems": 0,
  "stamina": { "current": 0, "max": 10 },
  "materials": {
    "construction_material": 0
  },
  "inventory": {
    "item_id": {
      "count": 0,
      "type": "equipment | consumable | key_item | gift",
      "slot_position": { "x": 0, "y": 0 },
      "properties": {}
    }
  },
  "pending_chests": [
    {
      "chest_id": "string",
      "chest_type": "string",
      "source": "dungeon | story | event | pomodoro | shop",
      "obtained_at": "timestamp",
      "opened": false,
      "rewards": { "gold": 0, "gems": 0, "materials": {}, "inventory": {} }
    }
  ],
  "unlocked_screens": {
    "guild": true,
    "adventure_select": true,
    "pomodoro": true,
    "settings": true,
    "scenario": true
  },
  "scenario_chapter": 1,
  "boss_unlocked": false,
  "pity_counters": {
    "reward_type_id": { "count_since_last_rare": 0, "pity_threshold": 0 }
  },
  "total_pomodoro_completed": 0,
  "last_pomodoro_end_at": "timestamp",
  "save_version": 1,
  "last_saved_at": "timestamp"
}
```

---

## 2. ポモドーロ

### 2-1. 進行中セッション
```json
{
  "session_id": "string",
  "preset": "short | standard | long",
  "status": "protection_select | focus | reflection | break | paused | completed | interrupted",
  "set_index": 0,
  "total_sets": 4,
  "focus_duration_sec": 1500,
  "short_break_sec": 300,
  "long_break_sec": 1800,
  "long_break_interval": 4,
  "selected_protection_type": "light | middle | hard",
  "cumulative_focus_minutes_today": 0,
  "set_titles": ["string"],
  "paused_at": null,
  "app_closed_at": null
}
```

- `set_titles`：セットごとのセッションタイトル（Steam Rich Presence表示用。下記2-7参照）。`set_index`に対応する配列。未入力のセットは空文字列

### 2-2. 振り返り
```json
{
  "reflections": [
    {
      "set_index": 0,
      "text": "string",
      "char_count": 0,
      "confirmed": false,
      "confirmed_at": null,
      "skipped": false
    }
  ]
}
```
- 20文字未満、または120秒以内に確定しなかった場合 `skipped: true`
- `skipped: true` のセットは報酬・累計時間・ストリークに一切カウントしない

### 2-3. 加護（マスターデータ・参照専用）
```json
{
  "light":  { "threshold_min": 50,  "bonus_multiplier": 5.0, "after_multiplier": 1.0 },
  "middle": { "threshold_min": 100, "bonus_multiplier": 2.0, "after_multiplier": 1.3 },
  "hard":   { "threshold_min": 100, "before_multiplier": 0.8, "after_multiplier": 1.6 }
}
```
- 1日1回、最初の作業開始前に選択（選択後は当日変更不可）
- しきい値は「正常に振り返りまで完了したセット」の累計作業時間（分）のみで判定

### 2-4. ストリーク・猶予日数・防衛チケット
```json
{
  "streak": {
    "current_streak_days": 0,
    "last_completed_date": "date",
    "grace_days_setting": 0,
    "consecutive_missed_days": 0,
    "defense_tickets": [
      { "obtained_at": "timestamp", "expires_at": "timestamp", "used": false }
    ]
  }
}
```

**日付変更時（毎朝4:00）の判定順序**
1. 前日の完了セットが0 → `consecutive_missed_days` を+1
2. `consecutive_missed_days <= grace_days_setting` → 猶予範囲内、チケット消費なしで維持
3. 猶予を超えている → 有効な防衛チケットを1枚自動消費して維持（最低保証報酬1セット分を付与、加護ボーナスは乗らない）
4. 猶予もチケットもない → ストリークリセット
5. 完了セットが1以上ある日は `consecutive_missed_days` を0にリセット

- 防衛チケットは連続7・14・21日達成ごとに1枚獲得、獲得から30日間有効、複数枚ストック可

### 2-5. セッション履歴（記録画面）
```json
{
  "session_history": [
    {
      "session_id": "string",
      "date": "date",
      "sets_completed": 0,
      "total_focus_minutes": 0,
      "reward_given": { "gold": 0, "stamina": 0, "materials": {} }
    }
  ]
}
```
※ 中断セッション（アプリを閉じて5分の猶予超過）は `stamina` 加算・加護しきい値判定には反映するが、この履歴配列には追加しない。

### 2-6. タイマー装飾
```json
{
  "pomodoro_decorations": {
    "owned_items": ["deco_item_id"],
    "equipped": { "background": null, "costume": null }
  }
}
```
- `construction_material`（拠点と共通）を消費して購入
- マルチプレイ共有は体験版では実装しない（Steam Rich Presenceによる状態表示は「共有」には該当しない。データのやり取りを伴わず、自分の状態を文字列で出すだけのため。2-7参照）

### 2-7. セッションタイトル・Steam Rich Presence

```json
{
  "rich_presence": {
    "enabled": true,
    "current_set_title": "string",
    "last_used_title": "string"
  }
}
```

**仕様**

- セッションタイトルは**セットごとに入力できる**。作業（フォーカス）開始前に入力欄を表示する
- 2セット目以降は`last_used_title`（前セットのタイトル）を入力欄の初期値として引き継ぐ。変更しなければそのまま次のセットでも使われる（毎セット打ち直す手間を避けるため）
- **入力は任意**。未入力（空文字列）の場合は汎用表示にフォールバックする
- `enabled: false`（設定画面でオフ）の場合、Rich Presenceを一切送信しない

**表示フォーマット**

| 状態 | タイトルあり | タイトルなし |
|---|---|---|
| 作業中 | `{title} — 3セット目 経過7分 / 残り18分` | `集中中 — 3セット目 経過7分 / 残り18分` |
| 振り返り中 | `振り返り中` | 同左 |
| 休憩中 | `休憩中 — 残り4分` | 同左 |
| セッション外 | （Rich Presenceをクリア） | 同左 |

- 経過時間と残り時間の**両方**を表示する
- 表示文字列自体はSteamworks側のローカライズトークンとして定義し、ゲーム側からは`steam_display`キーとパラメータ（title / set_index / elapsed_min / remain_min）のみを送る

**プライバシー上の制約（厳守）**

- **振り返り（2-2）の入力内容は絶対にRich Presenceに含めない。** 業務内容など、本人が公開を意図しないテキストが入りうるため
- Rich Presenceに載せてよいのは、ユーザーが表示用と認識して入力した`set_titles`と、時間・セット数のみ
- 設定画面でオフにできること（デフォルトはオン／オフのどちらかを設定画面の設計時に決定）

**実装上の注意**

- `PomodoroController`は、外部（Steam連携層）から現在の状態を取得できる公開関数（例：`get_presence_status() -> Dictionary`）を持つこと。内部状態をprivateに閉じ込めない
- Steam連携そのもの（GodotSteam導入・API呼び出し）は体験版のMVP範囲外。本項はデータ構造と取得口だけ先に用意しておくためのもの

---

## 3. 冒険選択画面

```json
{
  "story": {
    "current_chapter": 1,
    "stages": {
      "stage_1": { "cleared": false, "stars": 0 }
    },

    "stamina_cost_per_stage": 1
  },
  "training_mode_unlocked": true
}
```
- ステージは体験版で1〜10面を想定（`stage_1`〜`stage_10`）。`DEMO_CHECKLIST.md`「ストーリーステージ1〜10面が選択できる」に対応
- ステージ挑戦時に`GameManager.spend_stamina(stamina_cost_per_stage)`を呼び、失敗（スタミナ不足）なら挑戦させない
※ ダンジョン・戦闘プレビュー・ボスは体験版スコープ外のため未定義。

---

## 3-1. 戦闘画面

戦闘方式：**オートバトル（移動・通常攻撃は自動）＋ スキルは手動発動（クールダウン制）**のハイブリッド。
ロジック層とシーンツリー（表示）は分離する（`Unit`は`Node`を継承しない`RefCounted`）。詳細実装は`PLAN_BATTLE_SCREEN.md`を参照（`godot_battle_plan_revised.md`はプロトタイプ資料であり、本番実装の根拠には使わない）。

### 戦闘セッション（BattleSession）
```json
{
  "battle_id": "string",
  "stage_type": "story | training",
  "stage_id": "string",
  "party_id": "string",
  "state": "wave_intro | battle_active | wave_clear | victory | defeat",
  "current_wave": 1,
  "total_waves": 5,
  "party_units": ["Unit..."],
  "enemy_units": ["Unit..."],
  "result": {
    "victory": false,
    "waves_cleared": 0,
    "rewards": { "gold": 0, "materials": {} }
  }
}
```
- 報酬に経験値（exp）は含めない。レベル上げは専用素材消費型のため（下記4-3準拠）、戦闘での成長はレベルアップ用素材のドロップとして`materials`で表現する
- ウェーブ間はパーティのHP・バフ・クールダウンを**リセットしない**（連戦）
- 死亡した味方は復活しない
- 敗北時はステージを最初からやり直す

### ユニット（Unit・戦闘中のみ存在する実行時データ）
```json
{
  "unit_id": "string",
  "team": "party | enemy",
  "unit_name": "string",
  "hp": 0,
  "max_hp": 0,
  "atk": 0,
  "def": 0,
  "atk_multiplier": 1.0,
  "attack_range": 0,
  "speed": 0,
  "x": 0.0,
  "target_unit_id": null,
  "attack_timer": 0.0,
  "is_boss": false,
  "skills": [
    { "skill_id": "string", "cooldown_remaining": 0.0 }
  ]
}
```
- 味方Unitは、育成データ（`DATA_SCHEMA.md` 4-3 育成のstats/equipment）から戦闘開始時に生成する
- HP変動は必ず`take_damage`/`heal`経由。直接`hp`を書き換えない
- ターゲットは「毎フレーム最も近い敵対ユニット」を自動選択

### スキル定義（マスターデータ・参照専用）
```json
{
  "skill_id": {
    "name": "string",
    "type": "single | aoe | heal | buff | dot | projectile",
    "multiplier": 1.0,
    "cooldown_sec": 3.0,
    "user_character_id": "string"
  }
}
```
- ダメージ計算共通式：`最終ダメージ = max(1, 攻撃力 - 防御力)`、`攻撃力 = 素のATK × atk_multiplier`

### ウェーブデータ（マスターデータ・ステージごと）
```json
{
  "stage_id": {
    "waves": [
      {
        "wave_index": 1,
        "enemies": [
          { "enemy_type_id": "string", "count": 3, "stat_overrides": {} }
        ]
      },
      {
        "wave_index": 5,
        "enemies": [
          { "enemy_type_id": "boss_id", "is_boss": true, "stat_overrides": { "hp": 500, "atk": 40, "def": 20 } },
          { "enemy_type_id": "string", "count": 2 }
        ]
      }
    ]
  }
}
```
- 全ウェーブ共通で5ウェーブ構成、最終ウェーブにボス（＝拒否仕様の「ボス画面」とは別物。通常ステージ内部の演出）
- ウェーブクリア条件：そのウェーブの敵を全滅させる

---

## 4. ギルド

### 4-1. 倉庫（インベントリ・図鑑・宝箱）
インベントリ・宝箱は拠点（共通データ）側で保持。図鑑のみギルド側。
```json
{
  "codex": {
    "weapon_id": { "discovered": false, "obtained_at": null }
  }
}
```

### 4-2. ショップ
```json
{
  "daily_shop": {
    "refresh_at": "timestamp",
    "line_up": [
      {
        "slot_id": 0,
        "item_id": "string",
        "cost": { "currency_type": "gold", "amount": 0 },
        "stock_limit": 0,
        "purchased_count": 0
      }
    ]
  },
  "weekly_shop": { "refresh_at": "timestamp", "line_up": [] },
  "monthly_shop": { "refresh_at": "timestamp", "line_up": [] }
}
```
※ イベント交換所・DLCショップは体験版スコープ外。

### 4-3. 育成（キャラ詳細）
```json
{
  "character_id": {
    "level": 1,
    "stats": { "hp": 0, "atk": 0, "def": 0, "spd": 0 },
    "skills": {
      "slots": [
        {
          "slot_id": 0,
          "selected_skill_id": null,
          "available_options": ["skill_id_a", "skill_id_b", "skill_id_c"]
        }
      ]
    },
    "equipment": { "weapon": null, "armor": null, "accessory": null }
  }
}
```
- レベル上げは専用素材消費型（expフィールドなし）
- レベル上限は個別キャラではなく研究ツリー側で管理

### 4-4. 研究
```json
{
  "research_tree": {
    "node_id": {
      "unlocked": false,
      "effect_type": "level_cap_unlock | stat_boost_all",
      "effect_value": 0,
      "prerequisites": ["node_id"]
    }
  }
}
```
- キャラの実効レベル上限は「解放済みlevel_cap_unlockノードのeffect_value合計」として都度計算（保存はしない）

### 4-5. 作業場
```json
{
  "recipes_unlocked": { "recipe_id": false },
  "crafting_queue": [
    {
      "queue_id": "string",
      "recipe_id": "string",
      "recipe_type": "equipment | furniture_goods",
      "started_at": "timestamp",
      "duration_sec": 0,
      "status": "in_progress | completed | collected",
      "output_item_id": "string"
    }
  ]
}
```
- 製作は時間投資型（即時完成ではない）
- 素材製作はポモドーロ進行によっても進む（詳細ロジックは未確定）

---

## 未確定・要検討として残っている項目

※ 複数ファイルにまたがる論点は`PROJECT_STATUS.md`「横断的な未確定事項一覧」に集約している。ここにはこのファイル固有のものだけを残す。

- ストーリーステージ／トレーニングモード以外のstamina_cost設定値の具体的な数値
- 作業場の「ポモドーロ進行で素材製作が進む」仕組みの詳細ロジック
- シナリオ・設定画面のデータ構造（後回し）
- 研究ツリーのノード数・具体的な効果値

## 更新履歴
- 追記：2-7「セッションタイトル・Steam Rich Presence」を追加。セットごとのタイトル入力（前セットから引き継ぎ・任意入力）と、振り返り内容を絶対に外部表示しないプライバシー制約を明記
- 改訂（整合性レビュー反映）：戦闘報酬から`exp`を削除（4-3の素材消費型レベルアップと矛盾していたため）。3-1の参照先を`godot_battle_plan_revised.md`から`PLAN_BATTLE_SCREEN.md`に変更。冒険選択にステージ範囲（1〜10）とスタミナ消費の呼び出し規約を明記
