# TUTnextApp V3.0 変更履歴

## バージョン 3.0.0 (2026-02-18)

### 🎉 主要なアップデート

このバージョンは、TUTnextAppの大規模なリファクタリングを含む重要なアップデートです。

### ✨ 新機能

- **SwiftDataの統合**: キャッシュとデータ永続化のためにSwiftDataを採用
- **Keychain統合**: センシティブなユーザーデータのセキュリティ向上
- **ダークモード設定画面**: 新しい専用のダークモード設定UI
- **改善されたウィジェット**: 時間割ウィジェットとバスウィジェットの最適化
- **SwiftLint導入**: コード品質とスタイルの統一

### 🔄 変更点

#### データ管理
- UserDefaultsからSwiftDataへの移行
- UserDefaultsからKeychainへのセキュアデータ移行
- AppDefaultsによる設定管理の統一

#### アーキテクチャ
- ファイル構造の整理と再編成
  - `tama/App/` ディレクトリの追加
  - `tama/Core/Errors/` ディレクトリの追加
  - `tama/Core/Extensions/` ディレクトリの追加
- 新しいエラーハンドリングシステム
- 拡張機能の整理と最適化

#### UI/UX
- カラーパレットの統一
- ダークモード設定の改善
- メニューシート管理の改善
- ログイン画面のUI改善
- バススケジュール表示の改善

### 🐛 バグ修正

- ウィジェットデータ取得のエラーハンドリング改善
- キャッシュの有効性確認ロジックの修正
- スレッドセーフティの問題を解決

### 🗑️ 削除された機能

- Live Activity機能（BusWidget、TimetableWidget）
  - 将来のバージョンで再実装予定

### 📝 ドキュメント

- README.mdの大幅な更新（150行以上追加）
- アーキテクチャドキュメントの充実
- セットアップ手順の詳細化

### 🔧 技術的な変更

#### 追加されたファイル
- `Shared/CachedDataModels.swift` - データモデル定義
- `Shared/SharedModelContainer.swift` - 共有データコンテナ
- `tama/App/AppDelegate.swift` - アプリデリゲート
- `tama/App/ContentView.swift` - メインビュー
- `tama/Core/Errors/APIError.swift` - APIエラー定義
- `tama/Core/Extensions/Data+Extensions.swift`
- `tama/Core/Extensions/Notification+Names.swift`
- `tama/Core/Extensions/String+URLEncoding.swift`
- `.swiftlint.yml` - SwiftLint設定

#### 削除されたファイル
- `.cursor/rules/swiftui-guidelines.mdc`
- `BusWidget/BusWidgetBundle.swift`
- `BusWidget/BusWidgetLiveActivity.swift`
- `TimetableWidget/TimetableWidgetBundle.swift`
- `TimetableWidget/TimetableWidgetLiveActivity.swift`
- `tama/AppDelegate.swift` (旧版)
- `tama/AppearanceManager.swift` (旧版)
- `tama/ContentView.swift` (旧版)

#### 主要な変更
- `BusWidget/BusWidget.swift`: 大幅なリファクタリング（+310/-856行）
- `TimetableWidget/TimetableWidget.swift`: 最適化（+495/-580行）
- `PrintShareExtension/ShareViewController.swift`: 改善（+103/-147行）
- `README.md`: ドキュメント充実（+159/-9行）

### 📊 変更統計

- **変更ファイル数**: 110ファイル
- **追加行数**: 8,823行
- **削除行数**: 10,589行
- **コミット数**: 43コミット
- **純削減**: 1,766行（コードベースの簡素化）

### 🔐 セキュリティ

- Keychainを使用したセンシティブデータの保護
- APIエラーハンドリングの改善
- データ検証の強化

### 📱 互換性

- **iOS**: iOS 15.0以降
- **Swift**: Swift 5.x
- **Xcode**: Xcode 14.0以降推奨

### 🚀 パフォーマンス

- SwiftDataによる効率的なキャッシング
- ウィジェットのデータ取得最適化
- 不要なコードの削除による全体的なパフォーマンス向上

### 📦 マイグレーション

既存ユーザーへの注意点:
- 初回起動時に自動的にデータ移行が実行されます
- レガシーUserDefaultsデータは自動的にクリーンアップされます
- データ損失はありませんが、初回起動時に若干時間がかかる場合があります

### 🙏 謝辞

このバージョンの開発にご協力いただいた皆様に感謝いたします。

---

詳細な変更内容については、[PR2_UPDATE_LIST.md](./PR2_UPDATE_LIST.md)をご覧ください。

**関連PR**: [#2 Refactor/claude](https://github.com/Ukenn2112/TUTnextApp/pull/2)
