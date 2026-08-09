# 【作戦計画書】ポモドーロ最小ループ

第2層・作戦計画。PROJECT_STATUS.mdの推奨順序ステップ5。ここを完成させるとMVPが揃う。

---

## 1. スコープ

### 含む
- 加護選択 → 作業（フォーカス） → 振り返り → 休憩 → （次セット or 終了）の一連のループ
- セットを跨いだ進行管理（`set_index` / `total_sets`）
- 振り返りの文字数・時間判定によるskip処理
- 累計作業分がしきい値を跨いだことの記録と、拠点帰還時の宝箱付与
- 全セット終了時の報酬計算・GameManagerへの反映

### 含まない（後の段階で拡張）
- ストリーク・猶予日数・防衛チケット（DATA_SCHEMA.md 2-4）
- セッション履歴（記録画面、2-5）
- タイマー装飾（2-6）
- アプリを閉じた場合の中断・復帰処理（`paused` / `interrupted` 状態、`app_closed_at`）
- 日付変更時（毎朝4:00）の判定ロジック本体（加護選択の再表示判定のみ扱う）
- **宝箱の中身の抽選ロジック**（当面は`Balance`に定義した固定内容を入れる。乱数と`pity_counters`は中身が決まってから）

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
| 当日の累計作業分 | `cumulative_focus_minutes_today`。振り返り完了セットのみ加算 |
| 到達済みしきい値 | `reached_chest_thresholds`。同じしきい値で二重に宝箱を発生させないための記録 |
| 受け取り待ちの宝箱 | `unclaimed_chests`。到達したがまだ受け取っていない`chest_type`の一覧 |
| 振り返り記録一覧 | DATA_SCHEMA 2-2の形式に準拠 |
| セットごとのセッションタイトル | DATA_SCHEMA 2-7準拠。`set_titles`配列。Steam Rich Presence表示用 |

- `focus_duration_sec`等はAGENTS.mdの数値管理ルールに従い、`Balance.pomodoro`（`PomodoroConfig`）からセッション開始時に読み込む。ハードコード禁止。
- `PomodoroConfig`はプリセットを**`PomodoroPreset`の配列**として持つ（`short` 15/3・`standard` 25/5・`long` 50/10）。選択された`preset_id`に一致する`PomodoroPreset`から各秒数を読み込むこと。
- セット数・長休憩の分数・長休憩の挿入間隔はユーザーが変更可能。変更可能な範囲（最小／最大）も`PomodoroConfig`の`@export`から取得し、ハードコードしない。
- 加護ごとの宝箱スケジュール（DATA_SCHEMA 2-3）も`Balance.pomodoro`配下のデータとして扱う。

### 累計作業分の永続化について

`cumulative_focus_minutes_today`・`reached_chest_thresholds`・`unclaimed_chests`は**セッションを閉じても消えてはいけない**。よってこの3つだけは例外的に`GameManager`が持つ永続データに含める。

- 前2つは「その日」で持ち越す値。1日に複数回ポモドーロを起動しうるため（午前に40分・午後に60分やったら合計100分として扱う）。日付が変わる（毎朝4:00）とリセットする
- `unclaimed_chests`は受け取るまで保持する。**日付が変わってもリセットしない**（受け取る前に日を跨いで消えると、獲得したはずの宝箱が失われるため）

---

## 5. 各画面の責務

### 5-1. 加護選択（ProtectionSelectView）
- `light / middle / hard`から1つ選択させ、`selected_protection_type`にセット
- **選択画面には、その加護でいつ宝箱がもらえるかを表示する**（例：「50分で宝箱1つ」「25分ごとに宝箱＋100分で大きな宝箱」）。倍率ではなく宝箱のタイミングが加護の差なので、ここが選択の判断材料になる
- 1日1回・最初の作業開始前のみ表示。2回目以降のセットでは`PomodoroController`が自動でスキップし`FocusView`へ
- 選択後は当日変更不可。**「1日」の区切りは毎朝4:00**（`DATA_SCHEMA.md` 2-4で確定済み）。現在時刻が前回の加護選択時刻から見て次の4:00を跨いでいれば「別の日」と判定し、加護選択画面を再表示する

### 5-2. 作業（フォーカス）画面（FocusView）
- **作業開始前にセッションタイトルの入力欄を表示する**（DATA_SCHEMA 2-7）
  - 入力は**任意**。空のまま開始してよい
  - 2セット目以降は前セットのタイトルを初期値として引き継ぎ、変えたいときだけ編集する
  - 入力値は`set_titles[set_index]`に保存する
  - この欄は「フレンドに見える表示名」であることが分かる文言にする（`tr()`で囲む）
- `focus_duration_sec`のカウントダウンタイマーを表示
- タイマー完了で自動的に`ReflectionView`へ遷移し、状態を`reflection`に更新

### 5-3. 振り返り入力画面（ReflectionView）
- テキスト入力＋制限時間120秒のタイマーを表示
- 確定条件：20文字以上 かつ 120秒以内に確定操作
- 条件を満たさない場合は`skipped: true`として記録し、報酬・累計時間・宝箱しきい値判定には一切カウントしない（DATA_SCHEMA 2-2準拠）
- 確定・skip問わず`reflections`配列に1件追記し、`BreakView`へ遷移
- **確定した（`skipped: false`の）場合のみ、そのセットの作業分を`cumulative_focus_minutes_today`に加算し、宝箱しきい値の判定を行う**（下記6-1）

### 5-4. 休憩画面（BreakView）
- `set_index`が`long_break_interval`の倍数なら`long_break_sec`、それ以外は`short_break_sec`を使用
- バックグラウンドで自動的にカウントダウン開始（画面を閉じても進行する想定。ただしアプリ終了時の復帰処理自体は今回スコープ外）
- カウントダウン終了時：
  - `set_index + 1 < total_sets` → `set_index`を+1して`FocusView`へ戻る
  - `set_index + 1 >= total_sets` → 全セット終了処理へ（6-2）

---

## 6. 報酬の処理

### 6-1. しきい値到達の記録（セットごと）

**この時点では宝箱を付与しない。記録だけを行う。** 実際の付与は拠点へ戻ったときにまとめて行う（6-2）。

振り返りが確定したタイミングで以下を行う：

1. そのセットの作業分を`cumulative_focus_minutes_today`に加算する
2. 選択中の加護の`chest_schedule`を走査し、以下の両方を満たすエントリを探す
   - `threshold_min <= cumulative_focus_minutes_today`
   - `reached_chest_thresholds`に未記録
3. 該当するものそれぞれについて、`reached_chest_thresholds`に`threshold_min`を、`unclaimed_chests`に`chest_type`を追記する
4. 画面上で「宝箱を獲得した（拠点で受け取れる）」ことを知らせる（演出の詳細は実装時に決める）

- 1セットで複数のしきい値を跨ぐ可能性がある（長いプリセットの場合）。**その場合は跨いだぶんすべてを記録する**
- `skipped: true`のセットは加算も判定も行わない

### 6-2. 拠点へ戻るときの処理（報酬の受け取り）

**全セット完走でも、途中でやめた場合でも、この経路を通る。分岐を作らないこと。** 途中終了を特別扱いすると、片方だけ報酬が消えるバグが入り込む。

1. `reflections`のうち`skipped: false`のセットの作業分を集計する
2. 集計した作業分に`stamina_per_focus_minute`を掛けてスタミナ量を算出し、`reward_data`としてまとめる
   - **gold・素材は当面0とする。** 換算レートとランダム性はループが実際に回るようになってから設計する
   - **加護による倍率は掛けない。** 加護で差がつくのは宝箱のみ（DATA_SCHEMA 2-3）
3. `GameManager.apply_pomodoro_rewards(reward_data)`を呼び出す
   - 内部でスタミナの反映、`total_pomodoro_completed`のインクリメント、`last_pomodoro_end_at`の更新、`SignalBus.pomodoro_session_completed(reward_data)`の発火までまとめて行われる
4. `unclaimed_chests`の中身を順に`GameManager.add_pending_chest()`へ渡し、配り終えたら`unclaimed_chests`を空にする
   - 宝箱の中身は`Balance`（`PomodoroConfig`）に`chest_type`ごとの固定内容として定義する。抽選は今回入れない
5. `SceneManager.change_scene()`で拠点画面へ戻る

拠点に戻ると、下部のスタミナ表示が増え、宝箱を獲得していれば`ChestBadge`が点灯している状態になる。**これがコアループの手応えとして機能する。**

- 2セットだけで切り上げても、そこまでのスタミナと、跨いだしきい値の宝箱は確実に受け取れる（`CONCEPT.md`「ポモドーロを中断しても報酬をゼロにせず、経過時間に応じた部分報酬にする」）
- `unclaimed_chests`は受け取り終えるまで空にしない。受け取る前にアプリを閉じても、次に拠点へ戻ったときに受け取れる

## 6-3. Steam Rich Presence 用の状態公開（先行対応）

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

- ~~「当日」の判定基準~~ → **決定済み：毎朝4:00を日付の区切りとする**（`DATA_SCHEMA.md` 2-4のストリーク判定と同一基準）
  - 判定は`scripts/utils/`配下の共通ヘルパー（`game_date.gd` / `class_name GameDate`）に切り出し、ポモドーロ・ストリーク・ショップのリフレッシュ判定から共用する
- ~~加護の報酬倍率~~ → **廃止。宝箱スケジュールに置き換え済み**（DATA_SCHEMA 2-3）
- スタミナ換算レート（`stamina_per_focus_minute`）の具体値 → 今回は仮値で置き、ループを回してから調整する
- 加護のしきい値（45 / 90 / 135 / 180分）が実際に到達可能かどうか → 実際に使ってみて調整する。特にハード（180分）は1日がかりの想定
- 宝箱の中身の具体的な配分 → 当面は汎用素材で埋める。レア素材・レシピ・装飾が実装されてから設計する
- 休憩画面のバックグラウンド進行を、アプリを閉じたままどこまで許容するか（今回は「画面を閉じずにいる前提」で進める）
- セッションタイトルの文字数上限（Rich Presenceは表示幅が限られるため、20〜30文字程度で切る想定。値は`Balance.pomodoro`に`@export`で持たせる）
- Rich Presence表示のデフォルト（初期状態でオンかオフか）— 設定画面の設計時に決定
- 宝箱獲得時の演出（トースト表示か、専用のポップアップか）

---

## 8. GameManager／Balanceへの追記

### GameManager
- `apply_pomodoro_rewards(reward_data: Dictionary) -> void`（実装済み）
- **追加が必要**：`cumulative_focus_minutes_today` / `reached_chest_thresholds` / `unclaimed_chests`の保持と更新（4章の理由による）

### Balance.pomodoro（PomodoroConfig）
- **既存の`gold_per_focus_minute` / `materials_per_focus_minute`は残すが、値は0のままにする**（後で使うため削除はしない）
- `stamina_per_focus_minute`に仮値を入れる
- **`protection_light` / `middle` / `hard`の構造を変更**：倍率フィールドを廃止し、宝箱スケジュール（`{threshold_min, chest_type}`の配列）を持たせる
- `chest_type`ごとの中身（固定）を定義する
- プリセット配列（`PomodoroPreset`）に実際の秒数を入れる（`short` 15/3・`standard` 25/5・`long` 50/10）
- ユーザー設定可能範囲（セット数・長休憩の分数・長休憩の挿入間隔の最小／最大）に値を入れる

**現状`pomodoro_config.tres`は完全に空**（`presets`が空配列、加護3種が未割り当て、換算レートが全部0）。このままではプリセットが見つからず作業時間が0秒になるため、第3層で必ず値を入れること。

---

## 9. 完了条件（このチェックポイントのゴール）

- [ ] 加護選択 → 作業 → 振り返り → 休憩のループが、ダミーの短い秒数設定で1周する
- [ ] 加護選択画面に、その加護の宝箱タイミングが表示される
- [ ] 振り返りで20文字未満または120秒超過の場合、`skipped: true`として記録され、次のセットに進める
- [ ] `skipped: true`のセットは`cumulative_focus_minutes_today`に加算されない
- [ ] 累計作業分がしきい値を跨ぐと`unclaimed_chests`に積まれる（この時点ではまだ`add_pending_chest()`は呼ばれない）
- [ ] 同じしきい値で二重に宝箱が積まれない
- [ ] 1セットで複数のしきい値を跨いだ場合、跨いだぶんすべてが積まれる
- [ ] 拠点へ戻ると`unclaimed_chests`の中身が`add_pending_chest()`で付与され、`ChestBadge`が点灯し、`unclaimed_chests`が空になる
- [ ] `total_sets`到達で全セット終了処理に入り、拠点画面へ戻る
- [ ] **途中でやめて拠点へ戻った場合も、そこまでのスタミナと宝箱が受け取れる**（完走時と同じ経路を通っている）
- [ ] 拠点画面のスタミナ表示が報酬分だけ増えている
- [ ] `total_pomodoro_completed`が1回のセッションで1増える
- [ ] 作業開始前にセッションタイトルを入力でき、未入力のままでも開始できる
- [ ] 2セット目のタイトル入力欄に、前セットのタイトルが初期値として入っている
- [ ] `get_presence_status()`が現在の状態・タイトル・経過/残り分を返し、**振り返りテキストを含んでいない**ことをprintで確認できる

この計画書がそのまま第3層（実行指示書）のベースになる。

---

## 更新履歴
- 初版：加護選択〜休憩の最小ループを定義
- **改訂（加護の仕組みを倍率から宝箱へ変更）**：
  - 6章を全面改訂。報酬倍率の適用を廃止し、しきい値到達時の宝箱付与（6-1）とセッション終了時のスタミナ付与（6-2）に分離した
  - **宝箱は拠点へ戻ったときにまとめて受け取る方式に決定。** ポモドーロ中はしきい値到達を記録するだけ（6-1）、付与は拠点帰還時（6-2）。全セット完走でも途中終了でも同じ経路を通し、分岐を作らない
  - 報酬をスタミナのみとし、gold・素材は当面0とする方針を明記
  - `cumulative_focus_minutes_today` / `reached_chest_thresholds` / `unclaimed_chests`をGameManager側の永続データに含める理由を4章に追記
  - 加護選択画面に宝箱タイミングを表示する要件を5-1に追加
  - 8章に「`pomodoro_config.tres`が現状完全に空」である事実を明記
  - 完了条件を宝箱の付与検証を含む形に差し替え
