# UNIPA Android アプリ API リバースエンジニアリング

> **対象ファイル**: `unipa.xapk` (com.jast.gakuen.up.sm.unipa, v1.1.17)
> **解析ツール**: jadx (decompile)
> **調査日**: 2026-03-27

---

## 概要

UNIPA は大学向けスマートフォンアプリ（Universal Passport）。バックエンドとの通信は主に **2種類** に分かれる：

1. **REST API**（`/webapi/` プレフィックス）— JSON over HTTP POST
2. **レガシー Servlet**（`/faces/up/` プレフィックス）— HTML/WebView ベース

ベース URL は初回起動時にユーザーが手動入力し、`SharedPreferences` の `INITIAL_URL` に保存される。

---

## HTTP 共通仕様

### リクエスト

```
Method:        POST
Content-Type:  application/json; charset=UTF-8
User-Agent:    Android
Cookie:        JSESSIONID（CookieManager で自動管理）
ReadTimeout:   60,000 ms
ConnectTimeout: 5,000 ms
```

ボディは **JSON → URLエンcode** されて送信される（`*` → `%2a`、`-` → `%2d`）。

### 共通リクエストラッパー（HttpRequestDTO）

すべての REST API 呼び出しは以下の構造でラップされる：

```json
{
  "productCd": "ap",
  "subProductCd": "apa",
  "loginUserId": "学籍番号またはユーザーID",
  "encryptedLoginPassword": "暗号化パスワード",
  "plainLoginPassword": null,
  "langCd": "ja",
  "data": { ... }
}
```

### 共通レスポンス（HttpResponseDTO）

```json
{
  "responseCode": 200,
  "statusDto": {
    "success": true,
    "messageList": []
  },
  "data": { ... },
  "langCd": "ja"
}
```

レスポンスボディは **URL デコード後** に JSON パースされる。

---

## REST API エンドポイント一覧

### 1. ライセンスチェック

```
POST {INITIAL_URL}/webapi/core/up/InitProcResource/checkLicense
```

**用途**: URL 入力後にサーバーの有効性を確認する
**呼び出し元**: `InputUrlActivity`

**リクエスト（`data` フィールド）**:
```json
{
  "productCd": "ap"
}
```

**レスポンス（成功時）**: アプリタイプを `"RX"` に設定してログイン画面へ遷移

---

### 2. ログイン

```
POST {INITIAL_URL}/webapi/up/pk/Pky001Resource/login
```

**用途**: ユーザー認証
**呼び出し元**: `RxLoginActivity`, `RxJkwrActivity`, `RxJugyoDetailActivity`

**リクエスト（`data` フィールド、LoginRequestDTO）**:
```json
{
  "loginUserId": "学籍番号",
  "plainLoginPassword": "平文パスワード",
  "encryptedLoginPassword": null,
  "judgeLoginPossibleFlg": false,
  "deviceId": "Android デバイス ID",
  "autoLoginAuthCd": ""
}
```

**レスポンス（`data` フィールド、LoginUserInfotDTO）**:
```json
{
  "userId": "学籍番号",
  "encryptedPassword": "暗号化済みパスワード（以後使い回す）",
  "gaksekiCd": "学籍コード",
  "name": "氏名",
  "nameKana": "氏名カナ",
  "nameEng": "英語名",
  "nameDisp": "表示名",
  "userName": "ユーザー名",
  "userShkbtKbn": "Student | Parent",
  "shokuinUserKbn": "職員区分",
  "jinjiCd": "人事コード",
  "kanriNo": 0,
  "menuPtnCd": "メニューパターンコード",
  "langCd": "ja",
  "validKikanStartDatetime": null,
  "validKikanEndDatetime": null
}
```

---

### 3. ログアウト（通常）

```
POST {INITIAL_URL}/webapi/up/pk/Pky002Resource/logout
```

**用途**: 通常ログアウト（Shibboleth 非使用時）
**呼び出し元**: `RxJkwrActivity`
**リクエスト**: なし（HttpRequestDTO の `data` フィールドなし）

---

### 4. ログアウト（Shibboleth）

```
POST {INITIAL_URL}/webapi/up/pk/Pky002Resource/logout_shibboleth
```

**用途**: Shibboleth 認証使用時のログアウト
**呼び出し元**: `RxJkwrActivity`

**リクエスト（`data` フィールド、LoginRequestDTO の一部）**:
```json
{
  "deviceId": "デバイス ID",
  "autoLoginAuthCd": "自動ログイン認証コード"
}
```

---

### 5. 初期設定取得

```
POST {INITIAL_URL}/webapi/up/ap/Apa001Resource/firstSetting
```

**用途**: ログイン後の初期設定・通知フラグ・INI ファイル値取得
**呼び出し元**: `RxLoginActivity`, `RxConfigActivity`

**リクエスト（`data` フィールド、InitInfoRequestDTO）**:
```json
{
  "deviceId": "デバイス ID",
  "token": "FCM トークン",
  "keijiNoticeFlg": false,
  "jugyoNoticeFlg": false,
  "productIniFileDtoList": [
    {
      "productCd": "AP",
      "section": "ATTEND_PUSH",
      "key": "PUSH_USE_FLAG"
    },
    {
      "productCd": "AP",
      "section": "ATTEND_PUSH",
      "key": "PUSH_USE_FLAG_PARENT"
    }
  ]
}
```

**レスポンス（`data` フィールド、InitInfoDTO）**:
```json
{
  "autoLoginAuthCd": "自動ログイン認証コード（Shibboleth 用）",
  "maxJigenNo": 6,
  "productIniFileDtoList": [
    {
      "productCd": "AP",
      "section": "ATTEND_PUSH",
      "key": "PUSH_USE_FLAG",
      "value": "1"
    }
  ]
}
```

---

### 6. FCM プッシュトークン更新

```
POST {INITIAL_URL}/webapi/up/ap/Apa003Resource/putTokenInfo
```

**用途**: FCM（Firebase Cloud Messaging）デバイストークンの登録・更新
**呼び出し元**: `UnipaFirebaseMessagingService`, `RxConfigActivity`

**リクエスト（`data` フィールド、InitInfoRequestDTO の一部）**:
```json
{
  "deviceId": "デバイス ID",
  "token": "新しい FCM トークン"
}
```

---

### 7. 時間割・掲示メニュー情報取得

```
POST {INITIAL_URL}/webapi/up/ap/Apa004Resource/getJugyoKeijiMenuInfo
```

**用途**: 時間割一覧と未読掲示件数を取得（メイン画面の初期ロード）
**呼び出し元**: `RxJkwrActivity`

**リクエスト（`data` フィールド、JugyoKeijiMenuRequestDTO）**:
```json
{
  "kaikoNendo": 2025,
  "gakkiNo": 1,
  "deviceId": "デバイス ID",
  "autoLoginAuthCd": ""
}
```

**レスポンス（`data` フィールド、JugyoKeijiMenuInfoDTO）**:
```json
{
  "nendo": 2025,
  "gakkiNo": 1,
  "gakkiName": "前期",
  "maxGakkiNo": 2,
  "maxJigenNo": 6,
  "keijiCnt": 3,
  "funcIdList": ["Apa004", "Apa008", "Apa009"],
  "jgkmDtoList": [
    {
      "nendo": 2025,
      "jugyoCd": "XXXXXXXX",
      "kaikoNendo": 2025,
      "gakkiNo": 1,
      "kaikoYobi": 1,
      "jigenNo": 1,
      "jugyoName": "授業名",
      "jugyoKbn": "通常",
      "kyoinName": "教員名",
      "kyostName": "教室名",
      "jugyoStartTime": "09:00",
      "jugyoEndTime": "10:30",
      "keijiMidokCnt": 0
    }
  ]
}
```

**フィールド説明**:
| フィールド | 説明 |
|---|---|
| `kaikoYobi` | 曜日（1=月, 2=火, 3=水, 4=木, 5=金, 6=土, 7=日） |
| `jigenNo` | 時限番号（1〜最大時限数） |
| `jugyoKbn` | 授業区分 |
| `keijiMidokCnt` | 未読掲示件数 |
| `funcIdList` | 利用可能機能ID（`Apa004`=時間割, `Apa008`=出席, `Apa009`=シラバス） |

---

### 8. 授業詳細取得

```
POST {INITIAL_URL}/webapi/up/ap/Apa004Resource/getJugyoDetailInfo
```

**用途**: 授業コマのタップ時に出席情報・掲示一覧・メモを取得
**呼び出し元**: `RxJugyoDetailActivity`

**リクエスト（`data` フィールド、JugyoDetailInfoRequestDTO）**:
```json
{
  "nendo": 2025,
  "jugyoCd": "XXXXXXXX",
  "kaikoNendo": 2025,
  "gakkiNo": 1,
  "kaikoYobi": 1,
  "jigenNo": 1,
  "jugyoKbn": "通常"
}
```

**レスポンス（`data` フィールド、JugyoDetailInfoDTO）**:
```json
{
  "jgkmInfoDto": {
    "jugyoStartTime": "09:00",
    "jugyoEndTime": "10:30"
  },
  "attInfoDtoList": [
    {
      "shusekiKaisu": 10,
      "kessekiKaisu": 1,
      "chikokKaisu": 0,
      "sotaiKaisu": 0,
      "koketsuKaisu": 0,
      "mitourokuKaisu": 0
    }
  ],
  "keijiInfoDtoList": [
    {
      "keijiNo": 123456,
      "subject": "掲示タイトル",
      "keijiAppendDate": "2025-04-01T00:00:00.000Z"
    }
  ],
  "jugyoMemo": "個人メモ内容",
  "syuKetuKanriFlg": true,
  "syllabusPubFlg": true,
  "shukketsuNoDataCountDispFlg": false
}
```

**フィールド説明**:
| フィールド | 説明 |
|---|---|
| `shusekiKaisu` | 出席回数 |
| `kessekiKaisu` | 欠席回数 |
| `chikokKaisu` | 遅刻回数 |
| `sotaiKaisu` | 早退回数 |
| `koketsuKaisu` | 公欠回数 |
| `mitourokuKaisu` | 未登録回数 |
| `syuKetuKanriFlg` | 出欠管理フラグ |
| `syllabusPubFlg` | シラバス公開フラグ |

---

### 9. 授業メモ保存

```
POST {INITIAL_URL}/webapi/up/ap/Apa004Resource/setJugyoMemoInfo
```

**用途**: 授業コマに個人メモを保存
**呼び出し元**: `RxJugyoMemoActivity`

**リクエスト（`data` フィールド、JugyoMenoInfoRequestDTO）**:
```json
{
  "nendo": 2025,
  "jugyoCd": "XXXXXXXX",
  "jugyoMemo": "メモの内容テキスト"
}
```

**レスポンス**: 成功時に前画面へ戻る（`data` フィールドなし）

---

## レガシー Servlet エンドポイント

これらは WebView またはフォーム送信で使われる旧来のエンドポイント。

### 10. URL チェック

```
GET/POST {INITIAL_URL}/faces/up/ap/SmartphoneAppUrlCheck
```

**用途**: アプリの接続先 URL が有効かチェック
**呼び出し元**: `ReqAppServletAsync`（旧実装 EX 系）

---

### 11. Shibboleth 認証情報取得

```
GET/POST {INITIAL_URL}/faces/up/ap/AppShibbolethInfoReturn
```

**用途**: Shibboleth SSO 認証に使用するリンク URL・ボタン名を取得
**呼び出し元**: `RxLoginActivity`（ログイン画面初期化時）

**レスポンス（Map 形式）**:
```json
{
  "authManageList": [
    {
      "shibbolethBtnName": "〇〇大学 SSO ログイン",
      "shibbolethLinkUrl": "https://..."
    }
  ]
}
```

---

### 12. スマートフォンアプリ共通画面

```
GET {INITIAL_URL}/faces/up/ap/SmartphoneAppCommon?jsonData={URLエンコードJSON}
```

**用途**: 旧実装（EX 系）でのWebView ナビゲーション
**呼び出し元**: 旧 `JkwrActivity`, `WebViewActivity`

---

## WebView 自動ログイン

WebView で各機能画面を開く際は、以下の URL に JSON をクエリパラメータとして渡す：

```
GET {INITIAL_URL}/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo={URLエンコードJSON}&deviceKbn=3
```

**`webApiLoginInfo` の内容（WebViewLoginRequestDTO）**:
```json
{
  "userId": "学籍番号",
  "password": null,
  "encryptedPassword": "暗号化済みパスワード",
  "funcId": "画面機能ID",
  "formId": "フォームID",
  "paramaterMap": {},
  "deviceId": "デバイス ID（Shibboleth 時）",
  "autoLoginAuthCd": "認証コード（Shibboleth 時）"
}
```

### funcId / formId 対応表

| funcId | formId | 機能 |
|---|---|---|
| `Bsd507` | `Bsd50701` | 掲示板一覧 |
| `Bsd507` | `Bsd50702` | 掲示板詳細（keijiNo, keijiTorkDate を paramaterMap に渡す） |
| `Atb505` | `Atb50501` | 出席管理 |
| `Kmh506` | `Kmh50601` | シラバス検索 |
| `Pkx523` | `Pkx52301` | シラバス詳細（nendo, jugyoCd を paramaterMap に渡す） |

---

## 暗号化仕様

### パスワードハッシュ（サーバー保存用）
- アルゴリズム: `PBKDF2WithHmacSHA256`
- 反復回数: 10,000 回
- 出力長: 256 bit
- ソルト長: 20 bytes
- Base64 エンコードして保存
- 識別プレフィックス: `{GCRPT}`

### AES 暗号化（ローカル保存用）
- アルゴリズム: `AES/CBC/PKCS5Padding`
- 鍵長: 128 bit
- デフォルト鍵（ハードコード）: `1a 9d a7 ee 27 da 54 82 2b 6d c0 13 12 d7 fe e3`
- IV（ハードコード）: `88 c9 fe c9 32 17 ce c2 f2 40 8f 51 7c a8 dc 32`

### RSA（通信用）
- 鍵サイズ: 2048 bit
- 分割暗号化: 入力が長い場合は245バイト単位で分割処理

---

## ローカル DB（SQLite）

以下のエンティティが Room Database で管理される：

| テーブル | 説明 |
|---|---|
| `SmaJkwrEntity` | 時間割データのキャッシュ |
| `SmaJgkmColorEntity` | 授業コマ色設定 |
| `SmaPerSchdlEntity` | 個人スケジュール |

---

## アプリ設定キー（SharedPreferences）

| キー | 説明 |
|---|---|
| `INITIAL_URL` | サーバーベース URL |
| `INITIAL_USERID` | ログインユーザーID |
| `INITIAL_PASSWORD` | 暗号化パスワード |
| `INITIAL_LANGCODE` | 言語コード（`ja`） |
| `DEVICE_ID` | Android デバイス ID |
| `TOKEN` | FCM プッシュトークン |
| `AUTO_LOGIN_AUTH_CD` | Shibboleth 自動ログイン認証コード |
| `GAKUSEKI_CD` | 学籍コード |
| `DISPLAY_NAME` | 表示名（日本語） |
| `DISPLAY_NAME_EN` | 表示名（英語） |
| `USER_SHKBT_KBN` | ユーザー種別（`Student` / `Parent`） |
| `CURRENT_NENDO` | 現在の年度 |
| `CURRENT_GAKKI_NO` | 現在の学期番号 |
| `MAX_JIGEN` | 最大時限数 |
| `INITIALIZED_FLG` | 初期化完了フラグ |
| `NOTICE` | 通知有効フラグ |
| `NOTICE_JUGYO_START` | 授業開始通知フラグ |
| `JUGYO_NOTICE_FLG` | 授業通知機能有効フラグ |

---

## プッシュ通知（FCM）

- サービスクラス: `UnipaFirebaseMessagingService`
- トークン更新時 → `Apa003Resource/putTokenInfo` を自動呼び出し
- 通知チャネル ID: `UniversalPassport`
- 通知種別: `BIVE`（バイブ）、`SOUND`（サウンド）、`NOTICE`（通知）

---

## 依存ライブラリ（主要）

- **Retrofit 代替**: 独自 `HttpSend`（`AsyncTask` + `HttpURLConnection`）
- **JSON**: Jackson (`com.fasterxml.jackson.databind.ObjectMapper`)
- **DB**: AndroidX Room
- **通知**: Firebase Cloud Messaging
- **HTML パーサ**: Jsoup
- **コルーチン**: Kotlinx Coroutines
