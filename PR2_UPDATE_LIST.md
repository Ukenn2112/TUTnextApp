# PR #2 更新リスト - TUTnextApp V3.0 整体リファクタリング

## 概要
このPRは、TUTnextAppの大規模なリファクタリングを実施し、アプリの構造、データ管理、UI/UXを全面的に改善しました。

**変更統計:**
- 変更ファイル数: 110ファイル
- 追加: 8,823行
- 削除: 10,589行
- コミット数: 43コミット

---

## 主要な変更点

### 1. データ管理の刷新 🗄️

#### UserDefaultsからSwiftDataへの移行
- **目的**: キャッシュとデータ永続化を改善
- **影響範囲**: 時間割データ、バススケジュール、教室変更記録、課程色設定、印刷アップロード記録
- **新規追加**:
  - `Shared/CachedDataModels.swift` - キャッシュデータモデル（CachedTimetable、CachedBusSchedule、RoomChangeRecord、CourseColorRecord、PrintUploadRecord）
  - `Shared/SharedModelContainer.swift` - アプリとウィジェット間の共有データ管理

#### UserDefaultsからKeychainへのセキュアデータ移行
- **目的**: ユーザーデータのセキュリティ向上
- **影響**: センシティブなユーザー情報の保存方法を改善

#### AppDefaultsの導入
- **目的**: アプリ設定のデフォルト値管理を統一
- **変更**: UserDefaultsからAppDefaultsへの移行を実施

### 2. アーキテクチャの改善 🏗️

#### ファイル構造の再編成
- **新規ディレクトリ**:
  - `tama/App/` - アプリのメインファイルを集約
  - `tama/Core/Errors/` - エラー処理の統一
  - `tama/Core/Extensions/` - 拡張機能の整理

#### 新規ファイル追加
- `tama/App/AppDelegate.swift` (228行) - アプリデリゲート機能の分離
- `tama/App/ContentView.swift` (217行) - メインビューの分離
- `tama/Core/Errors/APIError.swift` - APIエラー処理の統一
- `tama/Core/Extensions/Data+Extensions.swift` - Dataの拡張機能
- `tama/Core/Extensions/Notification+Names.swift` - 通知名の定数管理
- `tama/Core/Extensions/String+URLEncoding.swift` - URL エンコーディング拡張

#### 古いファイルの削除
- `tama/AppDelegate.swift` (173行削除) → 新しいファイル構造に移行
- `tama/AppearanceManager.swift` (130行削除) → 外観管理の改善版に置き換え
- `tama/ContentView.swift` (171行削除) → 新しいファイル構造に移行

### 3. ウィジェット機能の改善 📱

#### BusWidgetのリファクタリング
- **変更内容**:
  - `BusWidget.swift`: 310行追加、856行削除（大幅な簡素化）
  - `BusWidgetDataProvider.swift`: データ取得ロジックの改善
  - バススケジュールデータにCodableを使用
  - スケジュールタイプ判定と表示名取得の簡素化
- **削除**:
  - `BusWidgetBundle.swift` (17行) - 不要な機能を削除
  - `BusWidgetLiveActivity.swift` (419行) - Live Activity機能の削除

#### TimetableWidgetのリファクタリング
- **変更内容**:
  - `TimetableWidget.swift`: 495行追加、580行削除（コードの最適化）
  - `TimetableWidgetDataProvider.swift`: キャッシングとエラーハンドリングの改善
  - CourseModelの構造改善（MARKコメントの追加）
- **削除**:
  - `TimetableWidgetBundle.swift` (17行) - 不要な機能を削除
  - `TimetableWidgetLiveActivity.swift` (72行) - Live Activity機能の削除

### 4. UI/UX の改善 🎨

#### カラーパレットの統一
- 全体的なカラーパレットを統一し、UI要素の色を改善
- 時間割とバススケジュールの視覚表現を向上
- 選択されたルートタイプの色のカスタマイズ

#### ダークモード設定の強化
- 新しいダークモード設定画面を追加
- AppearanceManagerの外観適用メソッドを改善
- DarkModeSettingsViewとUserSettingsViewから背景素材を削除し、外観の一貫性を向上

#### 新しいUI コンポーネント
- `MailComposerView` - メール作成ビューの追加
- `DarkModeSettingsView` - ダークモード設定専用ビュー
- `UserSettingsView`のレイアウト改善

### 5. 機能の改善 ⚙️

#### 時間割機能
- 時間割データ取得機能の改善
- キャッシュの有効性を確認するリトライ機能を追加
- CourseDetailViewとCourseDetailViewModelのリファクタリング

#### バススケジュール機能
- `BusScheduleView`のパディング計算を改善
- ピンメッセージの表示を追加
- `BusRouteTypeSelector`の色設定を改善

#### 学期情報
- 学期情報の年度表示を更新

#### メニュー機能
- `MoreMenuButton`のシート管理を改善
- MenuSheet列挙型を導入

#### ログイン機能
- `LoginViewModel`にNFCリーダーの変更を伝播させる機能を追加
- LoginViewのUIを改善

### 6. 印刷共有拡張機能 🖨️

#### ShareViewControllerのリファクタリング
- `PrintShareExtension/ShareViewController.swift`: 103行追加、147行削除
- 機能性とエラーハンドリングの改善
- コードの簡素化と最適化

### 7. 開発環境の整備 🛠️

#### SwiftLint導入
- 新規追加: `.swiftlint.yml` (78行)
- コード品質とスタイルの統一を図る

#### .gitignoreの更新
- 2行追加、1行削除
- ビルド成果物やキャッシュファイルの管理を改善

#### プロジェクト設定
- `tama.xcodeproj/project.pbxproj`の更新
- スキーム管理の調整

### 8. ドキュメントの充実 📚

#### README.mdの大幅な更新
- 159行追加、9行削除
- アプリの機能説明、セットアップ手順、アーキテクチャの詳細を追加

### 9. レガシーコードのクリーンアップ 🧹

#### 不要なファイルの削除
- `.cursor/rules/swiftui-guidelines.mdc` (36行) - 開発ルールファイルの削除
- 各種LiveActivity関連ファイルの削除
- 古いAppDelegate、AppearanceManager、ContentViewの削除

#### データクリーンアップ
- AppDelegateにレガシーUserDefaultsデータのクリーンアップ機能を追加

---

## 技術的な詳細

### データ管理の変更

**Before:**
- UserDefaultsでキャッシュデータを管理
- データの永続化が不安定
- スレッドセーフティの問題

**After:**
- SwiftDataを使用した堅牢なデータ管理
- SharedModelContainerでアプリとウィジェット間のデータ共有
- スレッドセーフなモデルコンテキストアクセス
- 改善されたエラーハンドリングとロギング

### サービスの更新

以下のサービスがSwiftDataを利用するように更新されました:
- `TimetableService`
- `BusScheduleService`
- `CourseColorService`
- その他のデータサービス

---

## セキュリティとパフォーマンスの改善

1. **セキュリティ**:
   - Keychainへの移行によるセンシティブデータの保護強化
   - APIエラー処理の統一と改善

2. **パフォーマンス**:
   - SwiftDataによる効率的なデータキャッシング
   - ウィジェットのデータ取得ロジック最適化
   - 不要なコードの削除による全体的なパフォーマンス向上

3. **保守性**:
   - SwiftLintの導入によるコード品質の向上
   - ファイル構造の整理による可読性の向上
   - MARKコメントの追加による理解しやすいコード

---

## マイグレーション対応

- レガシーUserDefaultsデータからの自動移行機能
- 既存ユーザーのデータ損失を防ぐクリーンアップ処理
- スムーズなアップグレード体験の提供

---

## 破壊的変更

このリファクタリングには以下の破壊的変更が含まれています:
1. Live Activity機能の削除（BusWidget、TimetableWidget）
2. データストレージの変更（UserDefaults → SwiftData/Keychain）
3. ファイル構造の大幅な変更

---

## まとめ

このPR #2は、TUTnextAppの V3.0 として、アプリの基盤を大幅に強化する包括的なリファクタリングを実施しました。データ管理の近代化、コード品質の向上、UI/UXの改善により、より安定した保守しやすいアプリケーションとなりました。

**主な成果:**
- ✅ 最新のSwiftData採用による堅牢なデータ管理
- ✅ セキュリティの向上（Keychain統合）
- ✅ コード品質の向上（SwiftLint導入、コード削減）
- ✅ ウィジェット機能の最適化
- ✅ UI/UXの統一と改善
- ✅ 詳細なドキュメント整備

---

**作成日**: 2026-02-19
**対象PR**: [#2 Refactor/claude](https://github.com/Ukenn2112/TUTnextApp/pull/2)
**マージ日**: 2026-02-18
