# 【作戦計画書】ポモドーロ最小ループ

第2層・作戦計画。PROJECT_STATUS.mdの推奨順序ステップ5。ここを完成させるとCHECKPOINTS.mdのMVPが揃う想定。

---

## 1. スコープ

### 含む
- 加護選択 → 作業（フォーカス） → 振り返り → 休憩 → （次セット or 終了）の一連のループ
- セットを跨いだ進行管理（`set_index` / `total_sets`）
- 振り返りの文字数・時間判定によるskip処理
- 全セット終了時の報酬計算・GameManagerへの反映

### 含まない（後の段階で拡張）
- ストリーク・猶予日数・防衛チケット（DATA_SCHEMA.md 2-4）
- セッション履歴（記録画面、2-5）
- タイマー装飾（2-6）
- アプリを閉じた場合の中断・復帰処理（`paused` / `interrupted` 状態、`app_closed_at`）
- 日付変更時（毎朝4:00）の判定ロジック

---

## 2. 画面構成・遷移（SCENES.mdより）

```
拠点 → ポモドーロ
        └─ 加護選択（1日1回・最初の作業開始前のみ）
             └─ 作業（フォーカス）
                  └─ 振り返り入力
                       └─ 休憩（自動遷移）
                            ├─ 次セットへ（作業に戻る）
                            └─ 全セット終了 → 拠点へ戻る（結果反映）
```

- 4画面は毎回`SceneManager.change_scene()`で独立シーン遷移するのではなく、`res://scenes/pomodoro/pomodoro.tscn`を親として、中の`CurrentViewContainer`に子ビューを差し替える方式を推奨（タイマーを親側で継続させ、休憩のバックグラウンド自動開始を成立させるため）。
- 拠点⇔ポモドーロの出入りのみ`SceneManager`経由。

---

## 3. シーン階層案

```
res://scenes/pomodoro/pomodoro.tscn
Pomodoro (Control)
├─ CurrentViewContainer (Control)
│   ├─ ProtectionSelectView（1日1回のみ表示、それ以外はスキップ）
│   ├─ FocusView
│   ├─ ReflectionView
│   └─ BreakView
└─ PomodoroController（スクリプトのみ。セッション進行の状態機械）
```

---

## 4. ランタイムデータ（DATA_SCHEMA.md 2-1, 2-2を最小化）

`PomodoroController`が保持する想定（GameManagerには持たせない。理由：セッション中の一時データであり、拠点共通データのSingle Source of Truthに含める必要がないため）。

| 項目 | 内容 |
|---|---|
| プリセット | `short` / `standard` / `long` |
| 進行状態 | `protection_select` / `focus` / `reflection` / `break` / `completed` |
| 現在のセット番号 | 0から開始 |
| 総セット数 | プリセットに応じて決まる |
| 作業時間（秒） | セッション開始時に`Balance.pomodoro`の該当`PomodoroPreset`からコピー |
| 短い休憩時間（秒） | 同上 |
| 長い休憩時間（秒） | 同上 |
| 長い休憩に入る間隔 | 同上 |
| 選んだ加護の種類 | `light` / `middle` / `hard` |
| 振り返り記録一覧 | DATA_SCHEMA 2-2の形式に準拠 |
| セットごとのセッションタイトル | DATA_SCHEMA 2-7準拠。`set_titles`配列。Steam Rich Presence表示用 |

- `focus_duration_sec`等はAGENTS.mdの数値管理ルールに従い、`Balance.pomodoro`（`PomodoroConfig`）からセッション開始時に読み込む。ハードコード禁止。
- `PomodoroConfig`はプリセットを**`PomodoroPreset`の配列**として持つ（`short` 15/3・`standard` 25/5・`long` 50/10）。選択された`preset_id`に一致する`PomodoroPreset`から各秒数を読み込むこと。`PomodoroConfig`直下に`focus_duration_sec`が1つだけある構造ではない（`PLAN_COMMON_INFRA.md` 2章参照）。
- セット数・長休憩の分数・長休憩の挿入間隔はユーザーが変更可能。変更可能な範囲（最小／最大）も`PomodoroConfig`の`@export`から取得し、ハードコードしない。
- 加護のしきい値・倍率（DATA_SCHEMA 2-3）も同様に`Balance.pomodoro`（PomodoroConfig）配下のデータとして扱う（`PLAN_COMMON_INFRA.md`に追記済み）。

---

## 5. 各画面の責務

### 5-1. 加護選択（ProtectionSelectView）
- `light / middle / hard`から1つ選択させ、`PomodoroSession.selected_protection_type`にセット
- 1日1回・最初の作業開始前のみ表示。2回目以降のセットでは`PomodoroController`が自動でスキップし`FocusView`へ
- 選択後は当日変更不可。**「1日」の区切りは毎朝4:00**（`DATA_SCHEMA.md` 2-4で確定済み）。現在時刻が前回の加護選択時刻から見て次の4:00を跨いでいれば「別の日」と判定し、加護選択画面を再表示する

### 5-2. 作業（フォーカス）画面（FocusView）
- **作業開始前にセッションタイトルの入力欄を表示する**（DATA_SCHEMA 2-7）
  - 入力は**任意**。空のまま開始してよい
  - 2セット目以降は前セットのタイトルを初期値として引き継ぎ、変えたいときだけ編集する（毎セット打ち直させない）
  - 入力値は`set_titles[set_index]`に保存する
  - この欄は「フレンドに見える表示名」であることが分かる文言にする（`tr()`で囲む）
- `PomodoroSession.focus_duration_sec`のカウントダウンタイマーを表示
- タイマー完了で自動的に`ReflectionView`へ遷移し、`status`を`reflection`に更新

### 5-3. 振り返り入力画面（ReflectionView）
- テキスト入力＋制限時間120秒のタイマーを表示
- 確定条件：20文字以上 かつ 120秒以内に確定操作
- 条件を満たさない場合は`skipped: true`として記録し、報酬・累計時間・加護しきい値判定には一切カウントしない（DATA_SCHEMA 2-2準拠）
- 確定・skip問わず`reflections`配列に1件追記し、`BreakView`へ遷移

### 5-4. 休憩画面（BreakView）
- `set_index`が`long_break_interval`の倍数なら`long_break_sec`、それ以外は`short_break_sec`を使用
- バックグラウンドで自動的にカウントダウン開始（画面を閉じても進行する想定。ただしアプリ終了時の復帰処理自体は今回スコープ外）
- カウントダウン終了時：
  - `set_index + 1 < total_sets` → `set_index`を+1して`FocusView`へ戻る
  - `set_index + 1 >= total_sets` → 全セット終了処理へ（6章）

---

## 6. セッション終了時の処理

1. `reflections`のうち`skipped: false`のセットのみを対象に、`cumulative_focus_minutes_today`相当を集計
2. `selected_protection_type`に応じた倍率（`Balance.pomodoro`内の加護データ）を適用して最終報酬（gold / stamina / materials）を計算し、`reward_data`としてまとめる
3. `GameManager.apply_pomodoro_rewards(reward_data)`を呼び出す
   - 内部でgold/stamina/materialsの反映、`total_pomodoro_completed`のインクリメント、`last_pomodoro_end_at`の更新、`SignalBus.pomodoro_session_completed(reward_data)`の発火までまとめて行われる（`PLAN_COMMON_INFRA.md`参照）
4. `SceneManager.change_scene()`で拠点画面へ戻る

---

## 6-2. Steam Rich Presence 用の状態公開（先行対応）

Steam連携そのものは体験版MVPのスコープ外だが、**あとから外付けできる形**にしておく。実装が進んでから内部状態を掘り返すのは手戻りが大きいため。

- `PomodoroController`は、現在の状態を外部から取得できる公開関数を持つこと：

```gdscript
func get_presence_status() -> Dictionary:
    # 返す内容（DATA_SCHEMA 2-7の表示フォーマットに対応）:
    #   status:       "focus" | "reflection" | "break" | "none"
    #   title:        set_titles[set_index]（未入力なら空文字列）
    #   set_index:    現在のセット番号（表示は1始まり）
    #   total_sets:   総セット数
    #   elapsed_min:  現在フェーズの経過分
    #   remain_min:   現在フェーズの残り分
```

- **振り返り（`reflections`）のテキストは絶対に含めないこと。** 業務内容など本人が公開を意図しないテキストが入りうるため（DATA_SCHEMA 2-7のプライバシー制約）
- この関数はSteam連携層のほか、将来的な通知やウィジェット表示にも使える汎用の口として設計する
- 状態をprivate変数に閉じ込めず、この関数経由で常に取り出せる状態を保つ

---

## 7. 未確定・要決定

- ~~「当日」の判定基準~~ → **決定済み：毎朝4:00を日付の区切りとする**（`DATA_SCHEMA.md` 2-4のストリーク判定と同一基準。両者で基準がズレると「ストリークは繋がっているのに加護が選び直せる」等の不整合が起きるため、必ず同じ判定関数を使うこと）
  - 判定は`scripts/utils/`配下の共通ヘルパー（例：`game_date.gd` / `class_name GameDate`）に切り出し、ポモドーロ・ストリーク・ショップのリフレッシュ判定から共用する
- 休憩画面のバックグラウンド進行を、アプリを閉じたままどこまで許容するか（今回は「画面を閉じずにいる前提」で進める）
- セッションタイトルの文字数上限（Rich Presenceは表示幅が限られるため、20〜30文字程度で切る想定。値は`Balance.pomodoro`に`@export`で持たせる）
- Rich Presence表示のデフォルト（初期状態でオンかオフか）— 設定画面の設計時に決定

---

## 8. GameManager／Balanceへの追記（対応済み）

`PLAN_COMMON_INFRA.md`に以下を追記済み：

- **GameManager**：`apply_pomodoro_rewards(reward_data: Dictionary) -> void`
  - `add_gold` / `add_stamina` / `add_material`を内部で呼び出し、`total_pomodoro_completed`・`last_pomodoro_end_at`を更新した上で`SignalBus.pomodoro_session_completed(reward_data)`を発火
- **Balance.pomodoro（PomodoroConfig）**：加護のしきい値・倍率、報酬換算レート、プリセット配列（`PomodoroPreset`）、ユーザー設定可能範囲を`@export`で保持

---

## 9. 完了条件（このチェックポイントのゴール）

- [ ] 加護選択 → 作業 → 振り返り → 休憩のループが、ダミーの短い秒数設定で1周する
- [ ] 振り返りで20文字未満または120秒超過の場合、`skipped: true`として記録され、次のセットに進める
- [ ] `total_sets`到達で全セット終了処理に入り、拠点画面へ戻る
- [ ] セッション終了時、拠点画面のリソース表示（gold等）が報酬分だけ増えている
- [ ] `total_pomodoro_completed`が1回のセッションで1増える
- [ ] 作業開始前にセッションタイトルを入力でき、未入力のままでも開始できる
- [ ] 2セット目のタイトル入力欄に、前セットのタイトルが初期値として入っている
- [ ] `get_presence_status()`が現在の状態・タイトル・経過/残り分を返し、**振り返りテキストを含んでいない**ことをprintで確認できる

この計画書がそのまま第3層（実行指示書）のベースになる。
