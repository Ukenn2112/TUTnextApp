<img src="https://github.com/user-attachments/assets/00d24c9a-c77b-45d2-9171-0cd9af5ae049" align="left" width="65"> <h1>TUTnext for swiftUI App</h1>
<a href="https://apps.apple.com/cn/app/tutnext/id6742843580?itscg=30200&itsct=apps_box_badge&mttnsubad=6742843580" style="display: inline-block;">
<img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/ja-jp?releaseDate=1742083200" alt="App Store" align="right" style="width: 204px; height: 62px; vertical-align: middle; object-fit: contain;" />
</a>
## TUTnext非公式アプリ<br>多摩大生のキャンパスライフを強力サポート！

このアプリは、多摩大学の学生生活をより便利で充実したものにするための非公式アプリです。大学からの重要なお知らせや、困ったときに役立つ情報、そして学びを深めるための様々な機能を搭載しています。

T-NEXTアカウントでログインすると、以下の機能が使用できます。

<img src="https://github.com/user-attachments/assets/7b0e5291-62f8-4206-a7ab-b1df951cd150" align="left" width="165">
<img src="https://github.com/user-attachments/assets/345bb80d-1b3a-4886-809c-573c7aed0e31" align="left" width="165">
<img src="https://github.com/user-attachments/assets/0d65d4f8-d276-44a5-8bf9-49df38fb9952" align="left" width="165">
<img src="https://github.com/user-attachments/assets/22fc0e5f-b856-402f-a9d8-e9eb199c4e5b" align="left" width="165">
<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>

### 【主な機能】

1. **履修科目時間割** — 履修している講義の時間割を自動で表示。時間割管理の手間を省き、授業への集中をサポートします。
2. **講義情報** — 各講義に関する詳細情報（シラバス、教室情報など）を簡単に確認できます。
3. **スクールバス時刻表** — 最新のスクールバス時刻表をいつでもどこでもチェック。通学の計画がスムーズに立てられます。
4. **課題・締切管理** — 課題の提出期限や詳細情報を一元管理。提出漏れを防ぎ、計画的な学習を支援します。
5. **大学からのお知らせ** — 大学からの重要なお知らせ（休講情報、イベント情報など）をプッシュ通知で受信。見逃しを防ぎます。

---

## プロジェクト構成

本プロジェクトはSwiftUI + MVVMアーキテクチャで構築されており、4つのビルドターゲットで構成されています。

### ディレクトリ構造

```
TUTnextApp/
├── tama/                         # メインアプリターゲット
│   ├── App/                      # アプリのエントリーポイント
│   │   ├── tamaApp.swift         #   @main アプリ起動定義
│   │   ├── AppDelegate.swift     #   AppDelegate（プッシュ通知等のライフサイクル管理）
│   │   └── ContentView.swift     #   ルートビュー（タブ切り替え等）
│   │
│   ├── Core/                     # アプリ全体で共有される基盤コード
│   │   ├── Errors/
│   │   │   └── APIError.swift    #   API通信エラーの定義
│   │   └── Extensions/
│   │       ├── Data+Extensions.swift      # Data型の拡張メソッド
│   │       └── Notification+Names.swift   # 通知名の定数定義
│   │
│   ├── Models/                   # データモデル（構造体・列挙型）
│   │   ├── AssignmentModel.swift #   課題データモデル
│   │   ├── BusScheduleModel.swift#   バス時刻表データモデル
│   │   ├── CourseDetailModels.swift #  講義詳細データモデル
│   │   ├── CourseModel.swift     #   講義データモデル
│   │   ├── PrintModels.swift     #   印刷システムデータモデル
│   │   ├── RoomChange.swift      #   教室変更データモデル
│   │   ├── Semester.swift        #   学期データモデル
│   │   ├── Teacher.swift         #   教員データモデル
│   │   ├── TimetableModels.swift #   時間割データモデル
│   │   └── User.swift            #   ユーザーデータモデル
│   │
│   ├── Services/                 # ビジネスロジック・外部通信サービス
│   │   ├── Network/              #   ネットワーク通信の基盤
│   │   │   ├── APIService.swift  #     API通信の共通処理
│   │   │   ├── CookieService.swift #   Cookie管理
│   │   │   └── HeaderService.swift #   HTTPヘッダー管理
│   │   ├── Auth/                 #   認証関連
│   │   │   ├── AuthService.swift #     T-NEXTログイン認証
│   │   │   ├── AuthError.swift   #     認証エラー定義
│   │   │   ├── GoogleOAuthService.swift # Google OAuth連携
│   │   │   └── UserService.swift #     ユーザー情報管理
│   │   ├── Timetable/            #   時間割関連
│   │   │   ├── TimetableService.swift   # 時間割データ取得
│   │   │   ├── CourseDetailService.swift # 講義詳細取得
│   │   │   ├── CourseColorService.swift  # 講義の色分け管理
│   │   │   ├── TimetableError.swift     # 時間割エラー定義
│   │   │   └── CourseDetailError.swift   # 講義詳細エラー定義
│   │   ├── Assignment/           #   課題管理
│   │   │   └── AssignmentService.swift  # 課題データ取得
│   │   ├── Bus/                  #   スクールバス
│   │   │   └── BusScheduleService.swift # バス時刻表データ取得
│   │   ├── Print/                #   印刷システム
│   │   │   └── PrintSystemService.swift # 印刷サービス連携
│   │   ├── Teacher/              #   教員情報
│   │   │   └── TeacherEmailListService.swift # 教員メールアドレス取得
│   │   ├── Notification/         #   プッシュ通知
│   │   │   └── NotificationService.swift    # 通知の登録・受信処理
│   │   ├── Device/               #   デバイス機能
│   │   │   ├── LanguageService.swift    # 多言語対応
│   │   │   └── NFCReader.swift          # NFC読み取り機能
│   │   └── AppServices/          #   アプリ全般サービス
│   │       ├── AppearanceManager.swift  # ダークモード等の外観管理
│   │       └── RatingService.swift      # App Store評価リクエスト
│   │
│   ├── ViewModels/               # ViewModel（View用のデータ・ロジック管理）
│   │   ├── AssignmentViewModel.swift       # 課題画面のViewModel
│   │   ├── BusScheduleViewModel.swift      # バス時刻表画面のViewModel
│   │   ├── CourseDetailViewModel.swift      # 講義詳細画面のViewModel
│   │   ├── LoginViewModel.swift            # ログイン画面のViewModel
│   │   ├── PrintSystemViewModel.swift      # 印刷画面のViewModel
│   │   ├── TeacherEmailListViewModel.swift # 教員一覧画面のViewModel
│   │   ├── TimetableViewModel.swift        # 時間割画面のViewModel
│   │   └── UserSettingsViewModel.swift     # 設定画面のViewModel
│   │
│   ├── Views/                    # UI画面（SwiftUI View）
│   │   ├── Components/           #   再利用可能なUI部品
│   │   │   ├── AssignmentCardView.swift  # 課題カードコンポーネント
│   │   │   ├── HeaderView.swift         # ヘッダーコンポーネント
│   │   │   ├── SafariWebView.swift      # アプリ内ブラウザ
│   │   │   └── TabBarView.swift         # タブバーコンポーネント
│   │   ├── Timetable/            #   時間割関連画面
│   │   │   ├── TimetableView.swift      # 時間割表示画面
│   │   │   └── CourseDetailView.swift   # 講義詳細画面
│   │   ├── Assignment/           #   課題関連画面
│   │   │   └── AssignmentView.swift     # 課題一覧画面
│   │   ├── Bus/                  #   バス関連画面
│   │   │   └── BusScheduleView.swift    # バス時刻表画面
│   │   ├── Auth/                 #   認証関連画面
│   │   │   └── LoginView.swift          # ログイン画面
│   │   ├── Settings/             #   設定関連画面
│   │   │   └── UserSettingsView.swift   # ユーザー設定画面
│   │   ├── Print/                #   印刷関連画面
│   │   │   └── PrintSystemView.swift    # 印刷システム画面
│   │   └── Teacher/              #   教員関連画面
│   │       └── TeacherEmailListView.swift # 教員メールアドレス一覧画面
│   │
│   ├── Resources/                # リソースファイル
│   │   ├── Assets.xcassets/      #   画像・色などのアセット
│   │   ├── AppIcon.icon/         #   アプリアイコン（SVG素材）
│   │   ├── Info.plist            #   アプリ設定（権限・URL Scheme等）
│   │   ├── Config.xcconfig       #   ビルド設定（API URL等の環境変数）
│   │   ├── Localizable.xcstrings #   多言語翻訳ファイル
│   │   ├── PrivacyInfo.xcprivacy #   プライバシーマニフェスト
│   │   ├── tama.entitlements     #   アプリの権限設定（App Groups等）
│   │   ├── en.lproj/             #   英語ローカライズ
│   │   ├── ja.lproj/             #   日本語ローカライズ
│   │   ├── ko.lproj/             #   韓国語ローカライズ
│   │   └── zh-Hans.lproj/        #   簡体字中国語ローカライズ
│   │
│   └── Preview Content/          # Xcodeプレビュー用アセット
│
├── BusWidget/                    # バス時刻表ウィジェット（ホーム画面用）
│   ├── BusWidgetBundle.swift     #   ウィジェットバンドル定義
│   ├── BusWidget.swift           #   ウィジェットUI・タイムライン
│   ├── BusWidgetDataProvider.swift #  データプロバイダー
│   ├── BusWidgetLiveActivity.swift # ライブアクティビティ対応
│   ├── AppIntent.swift           #   ウィジェットインテント定義
│   └── Assets.xcassets/          #   ウィジェット用アセット
│
├── TimetableWidget/              # 時間割ウィジェット（ホーム画面用）
│   ├── TimetableWidgetBundle.swift    # ウィジェットバンドル定義
│   ├── TimetableWidget.swift          # ウィジェットUI・タイムライン
│   ├── TimetableWidgetDataProvider.swift # データプロバイダー
│   ├── TimetableWidgetLiveActivity.swift # ライブアクティビティ対応
│   └── Assets.xcassets/               # ウィジェット用アセット
│
├── PrintShareExtension/          # 印刷共有エクステンション（共有シートから印刷）
│   ├── ShareViewController.swift #   共有シートのViewController
│   ├── PrintShareExtension.entitlements # 権限設定
│   └── Info.plist                #   エクステンション設定
│
├── tama.xcodeproj/               # Xcodeプロジェクトファイル
│   ├── project.pbxproj           #   プロジェクト設定（ターゲット・ビルド設定等）
│   └── xcshareddata/xcschemes/   #   共有スキーム
│
├── BusWidgetExtension.entitlements       # バスウィジェットの権限設定
├── TimetableWidgetExtension.entitlements # 時間割ウィジェットの権限設定
└── README.md                     # このファイル
```

### 技術スタック

| カテゴリ | 技術 |
|---------|------|
| UI フレームワーク | SwiftUI |
| アーキテクチャ | MVVM（Model-View-ViewModel） |
| 対応言語 | 日本語・英語・韓国語・中国語（簡体字） |
| ウィジェット | WidgetKit（バス時刻表・時間割） |
| 通知 | APNs（Apple Push Notification service） |
| 認証 | T-NEXTアカウント / Google OAuth |

### 【注意事項】

- このアプリは非公式アプリです。公式な情報については、大学の公式ウェブサイトやT-NEXTをご確認ください。
- アプリの利用にはT-NEXTアカウントが必要です。
