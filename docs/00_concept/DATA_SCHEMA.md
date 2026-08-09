# データスキーマ

各画面（箱）ごとのセーブデータ構造。Godot実装時はAutoload（GameManager等）が保持する想定。

---

## 1. 拠点（共通データ）

全画面から参照される、いわばSingle Source of Truth。

```json
{
  "gold": 0,
  "gems": 0,
  "stamina": { "current": 20, "max": 100 },
  "potion_focus_remainder": 0,
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
	  "chest_type": "generic | bonus_small | bonus_medium | bonus_large",
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

### スタミナとポーション（決定済み）

**スタミナ＝その日に遊べる時間**であり、ゲーム体験の総量に直結する。よって**加護によって差をつけない。** 長く働かないと遊べない、という設計は`CONCEPT.md`の「やって後悔したと思わせない」に反するため。

| 項目 | 値 |
|---|---|
| 初期値 | `current: 20` / `max: 100` |
| ポモドーロ報酬 | スタミナを直接付与せず、**スタミナポーション**を配る |
| ポーション獲得量 | **作業25分につき1個**（加護によらず一律） |
| ポーション1個の回復量 | **50** |

**ポーション方式にした理由**

- 「5/100」より「ポーション×2 獲得」のほうが増えた実感が出る。獲得が数えられる名詞になる
- ストックできるので、満タンでも報酬が消えない
- 冒険に行く直前に飲むかどうか、というプレイヤーの判断が1つ増える

**ポーションは上限を超えて回復できる**（例：60のときに飲むと110になる）

- `max`はあくまで自然回復の上限であり、自分で貯めたポーションを飲んだぶんは超えてよい
- 上限で切り捨てると「満タン近くで飲むと損」が頻繁に起き、原則に反するため
- 自然回復・その他の`add_stamina()`は従来どおり`max`で切り捨てる

**端数は持ち越す**

- 作業60分なら2個（50分ぶん）で、残り10分は`potion_focus_remainder`に繰り越す
- 次回のセッションで加算し、25分に達した時点で1個になる
- 日付が変わってもリセットしない（切り捨てで損する感覚をなくすため）

### 宝箱の種類（chest_type）

| chest_type | 中身 | 主な入手元 |
|---|---|---|
| `generic` | 汎用素材（建築素材など）を少量 | ポモドーロの途中報酬。進捗の実感を切らさないためのもの |
| `bonus_small` / `bonus_medium` / `bonus_large` | 良いもの（レア素材・レシピ・装飾等）。sizeで中身の量・質が変わる | ポモドーロの加護しきい値到達（1日1個） |

**宝箱の中身の原則（厳守）**

- **スタミナなど「今日遊べる量」に影響するものを入れない。** 遊べる時間に差がつくと、短く切り上げた人が損をするため
- **特定の加護でしか手に入らないアイテムを作らない。** ハード限定のレアアイテムがあると、ライトを選んだ人が「取り逃した」と感じる
- 加護による差は**量だけ**でつける。ハードは地味な素材が大量に手に入る。ライトにも同じ種類が、少なく入る
- 向いているもの：レシピ、研究の解放素材、装備、育成素材、拠点の装飾。どれも「今日遊べる時間」には影響せず、**長く続けた人ほど拠点が育っている**という形で差が出る
- 具体的な中身・抽選テーブルは未確定。当面はどちらも建築素材で埋め、`Balance`の`.tres`から調整する
- `pity_counters`はボーナス宝箱の中身抽選に使う想定（一定回数ハズレたら確定で当たる救済）。仕組みだけ用意し、実際の抽選は中身が決まってから

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
  "reached_chest_thresholds": [25, 50],
  "unclaimed_chests": ["generic", "generic"],
  "set_titles": ["string"],
  "paused_at": null,
  "app_closed_at": null
}
```

- `set_titles`：セットごとのセッションタイトル（Steam Rich Presence表示用。下記2-7参照）。`set_index`に対応する配列。未入力のセットは空文字列
- `reached_chest_thresholds`：**その日すでに到達したしきい値（分）の一覧**。同じしきい値で二重に宝箱を発生させないための記録。日付が変わる（毎朝4:00）とリセットする
- `unclaimed_chests`：**到達したが、まだ受け取っていない宝箱の`chest_type`一覧**。ポモドーロ中は宝箱をここに積むだけで、実際の付与は拠点へ戻ったときにまとめて行う（下記2-3）。日付が変わってもリセットしない（受け取る前に日を跨いでも消えないようにするため）

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

**加護は報酬倍率ではなく「その日どのタイミングで宝箱がもらえるか」を決めるもの。**

```json
{
  "light":  {
	"chest_schedule": [
	  { "threshold_min": 45,  "chest_type": "bonus_small" }
	]
  },
  "middle": {
	"chest_schedule": [
	  { "threshold_min": 45,  "chest_type": "generic" },
	  { "threshold_min": 90,  "chest_type": "bonus_medium" }
	]
  },
  "hard":   {
	"chest_schedule": [
	  { "threshold_min": 45,  "chest_type": "generic" },
	  { "threshold_min": 90,  "chest_type": "generic" },
	  { "threshold_min": 135, "chest_type": "generic" },
	  { "threshold_min": 180, "chest_type": "bonus_large" }
	]
  }
}
```

**設計意図**

| 累計作業分 | ライト | ミドル | ハード |
|---|---|---|---|
| 45分 | **ボーナス（小）** | 汎用 | 汎用 |
| 90分 | — | **ボーナス（中）** | 汎用 |
| 135分 | — | — | 汎用 |
| 180分 | — | — | **ボーナス（大）** |

| 加護 | 性格 |
|---|---|
| ライト | 短く切り上げる日向け。**最も早く確実にボーナスへ届く**のが価値。中身は控えめ |
| ミドル | 標準。90分でボーナスに届く。ハードより早く手堅い |
| ハード | 1日がかりの作業日向け。45分ごとに汎用宝箱が入るため途中で折れにくい。180分到達時の中身が最も良い |

**しきい値は1セッションではなく「その日の累計作業分」で判定する。** 朝に100分、夜に80分やれば合計180分としてハードのボーナスに届く。1回のセッションで180分やる必要はない。

**同じ45分の地点で、ライトはボーナス宝箱を、ハードは汎用宝箱を受け取る。** 加護の差が「同じ時間で何を受け取るか」の差として現れるため、選択の判断が分かりやすい。

- **報酬倍率（`bonus_multiplier` / `before_multiplier` / `after_multiplier`）は廃止した。** 倍率という見えない仕組みより「宝箱が何個・いつ開くか」のほうがプレイヤーから見て分かりやすく、`CONCEPT.md`の「頑張る楽しさを素直に嬉しい手応えとして返す」に沿うため
- 毎分のスタミナ報酬は加護によらず一定。加護で差がつくのは宝箱だけ
- ライトが不利にならない理由：ライトは45分でボーナス宝箱に届くが、ハードは同じ位置づけのものを得るのに180分かかる。**早さがライトの価値、中身の良さがハードの価値**
- ミドルのボーナスを90分に置いているのは、ハードと同じ180分にするとミドルがハードの下位互換になるため（宝箱の数も中身もハードが上回ってしまう）
- 1日1回、最初の作業開始前に選択（選択後は当日変更不可）
- しきい値は「正常に振り返りまで完了したセット」の累計作業時間（分）のみで判定する（2-2準拠）

**宝箱を受け取るタイミング（決定済み）**

宝箱は**拠点画面へ戻ったときにまとめて受け取る。** ポモドーロの最中には付与しない。

1. 振り返りが確定するたびに`cumulative_focus_minutes_today`を加算し、`chest_schedule`のしきい値を跨いだか判定する
2. 跨いでいれば`reached_chest_thresholds`に記録し、対応する`chest_type`を`unclaimed_chests`に積む（**この時点では`add_pending_chest()`を呼ばない**）
3. ポモドーロを終えて拠点画面へ戻るとき、`unclaimed_chests`の中身を順に`GameManager.add_pending_chest()`へ渡し、配り終えたら空にする

- **全セット完走でも途中でやめた場合でも、拠点へ戻る経路は同じ。** 分岐を作らないこと。途中終了を特別扱いすると、片方だけ報酬が消えるバグが入り込む
- 2セットだけで切り上げても、そこまでで跨いだしきい値のぶんは確実に受け取れる（`CONCEPT.md`「ポモドーロを中断しても報酬をゼロにせず、経過時間に応じた部分報酬にする」）
- `unclaimed_chests`は受け取るまで消さない。受け取る前にアプリを閉じたり日を跨いだりしても、次に拠点へ戻ったときに受け取れる

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
3. 猶予を超えている → 有効な防衛チケットを1枚自動消費して維持（最低保証報酬1セット分を付与）
4. 猶予もチケットもない → ストリークリセット
5. 完了セットが1以上ある日は `consecutive_missed_days` を0にリセット

- 防衛チケットは連続7・14・21日達成ごとに1枚獲得、獲得から30日間有効、複数枚ストック可
- 日付変更時に`reached_chest_thresholds`と`cumulative_focus_minutes_today`もリセットする。**`unclaimed_chests`はリセットしない**（未受け取りの宝箱が消えてしまうため）

### 2-5. セッション履歴（記録画面）
```json
{
  "session_history": [
	{
	  "session_id": "string",
	  "date": "date",
	  "sets_completed": 0,
	  "total_focus_minutes": 0,
	  "reward_given": { "potions": 0, "chests": ["chest_type"] }
	}
  ]
}
```
※ 中断セッション（アプリを閉じて5分の猶予超過）は `stamina` 加算・宝箱しきい値判定には反映するが、この履歴配列には追加しない。

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

- ポーション獲得レート（作業25分で1個）とポーション1個の回復量（50）の調整。実際に遊んでから見直す
- 宝箱（generic / bonus_*）の中身の具体的な配分と抽選テーブル
- ストーリーステージ／トレーニングモード以外のstamina_cost設定値の具体的な数値
- 作業場の「ポモドーロ進行で素材製作が進む」仕組みの詳細ロジック
- シナリオ・設定画面のデータ構造（後回し）
- 研究ツリーのノード数・具体的な効果値

## 更新履歴
- 追記：2-7「セッションタイトル・Steam Rich Presence」を追加。セットごとのタイトル入力（前セットから引き継ぎ・任意入力）と、振り返り内容を絶対に外部表示しないプライバシー制約を明記
- 改訂（整合性レビュー反映）：戦闘報酬から`exp`を削除。3-1の参照先を`PLAN_BATTLE_SCREEN.md`に変更。冒険選択にステージ範囲（1〜10）とスタミナ消費の呼び出し規約を明記
- **改訂（加護の仕組みを倍率から宝箱へ変更）**：
  - 2-3を全面改訂。報酬倍率（`bonus_multiplier` / `before_multiplier` / `after_multiplier`）を廃止し、「加護ごとの宝箱スケジュール（`chest_schedule`）」に置き換えた。倍率という見えない仕組みより、宝箱が何個いつ開くかのほうが分かりやすいため
  - 宝箱を`generic`（汎用素材・途中報酬）と`bonus_*`（しきい値到達・1日1個）の2系統に分け、1章の`chest_type`に定義を追加
  - 2-1に`reached_chest_thresholds`（その日到達済みのしきい値）と`unclaimed_chests`（受け取り待ちの宝箱）を追加
  - **宝箱は拠点画面へ戻ったときにまとめて受け取る方式に決定**（ポモドーロ中は積むだけ）。全セット完走でも途中終了でも同じ経路を通し、分岐を作らない
  - スタミナ上限を`max: 100` / 初期`current: 20`に変更し、大きく取る理由を1章に明記（報酬が上限で切り捨てられて損をした気分にならないようにするため）
  - 2-5の`reward_given`を、実態に合わせて`stamina`と`chests`のみに変更（goldと素材は当面0のため）
- **改訂（スタミナをポーション方式に変更）**：
  - ポモドーロ報酬をスタミナ直接付与から**スタミナポーション**に変更。作業25分につき1個、**加護によらず一律**
  - 理由：スタミナは「その日に遊べる時間」に直結するため、加護で差をつけると長く働かないと遊べない設計になる。加護の差は宝箱の中身だけでつける
  - ポーションは**上限を超えて回復できる**（満タン近くで飲んでも損しない）。自然回復は従来どおり`max`で切り捨てる
  - 端数を`potion_focus_remainder`として持ち越す（日付が変わってもリセットしない）
  - 宝箱の中身の原則を明記：遊べる量に影響するものを入れない、加護限定アイテムを作らない、差は量だけでつける
