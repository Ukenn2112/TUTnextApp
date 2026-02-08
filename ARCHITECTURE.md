# TUTnext App - 项目架构文档

## 📱 项目概述

**TUTnext** 是多摩大学（Tama University）的非官方 iOS 应用，基于 SwiftUI 构建。该应用旨在为学生提供便捷的校园生活服务，包括课程表管理、校园巴士时刻表、作业管理和通知推送等功能。

### 核心功能

| 功能模块 | 描述 |
|---------|------|
| 📚 课程表 | 显示和管理学生选修课程的时间表 |
| 🚌 校园巴士 | 实时查看校园巴士时刻表 |
| 📝 作业管理 | 追踪作业截止日期和提交状态 |
| 🔔 通知推送 | 接收大学重要通知和休讲信息 |
| 📊 实时活动 | 支持 iOS 实时活动（Live Activities） |

---

## 🏗️ 整体架构

```
TUTnextApp/
├── tama/                          # 主应用模块
│   ├── Models/                    # 数据模型层
│   ├── Views/                     # 视图层
│   ├── Services/                  # 服务层（业务逻辑）
│   ├── Utilities/                 # 工具类
│   └── Resources/                  # 资源文件
├── TimetableWidget/               # 课程表小组件
├── BusWidget/                     # 巴士时刻表小组件
├── PrintShareExtension/           # 分享扩展
└── *.xcodeproj/                   # Xcode 项目配置
```

---

## 📂 目录结构详解

### 主应用模块 (tama/)

#### Models/ - 数据模型层

| 文件名 | 用途 |
|--------|------|
| `User.swift` | 用户信息数据模型 |
| `Semester.swift` | 学期信息模型 |
| `CourseModel.swift` | 课程数据模型 |
| `TimetableModels.swift` | 课程表相关模型 |
| `AssignmentModel.swift` | 作业/任务数据模型 |
| `BusScheduleModel.swift` | 巴士时刻表模型 |

#### Services/ - 服务层

| 文件名 | 用途 |
|--------|------|
| `APIService.swift` | 统一的 API 请求服务，处理所有网络通信 |
| `AuthService.swift` | 认证服务，管理用户登录状态 |
| `GoogleOAuthService.swift` | Google OAuth 认证流程处理 |
| `UserService.swift` | 用户信息服务 |
| `TimetableService.swift` | 课程表数据管理服务 |
| `BusScheduleService.swift` | 巴士时刻表服务 |
| `AssignmentService.swift` | 作业管理服务 |
| `NotificationService.swift` | 推送通知服务 |
| `HeaderService.swift` | HTTP 请求头管理服务 |
| `CookieService.swift` | Cookie 管理服务 |
| `CourseDetailService.swift` | 课程详情服务 |
| `CourseDetailModels.swift` | 课程详情数据模型 |
| `CourseColorService.swift` | 课程颜色配置服务 |
| `LanguageService.swift` | 语言设置服务 |
| `PrintSystemService.swift` | 打印系统服务 |
| `RatingService.swift` | 应用评分请求服务 |
| `NFCReader.swift` | NFC 读取功能 |
| `TeacherEmailListService.swift` | 教师邮箱列表服务 |

#### Views/ - 视图层

| 文件名 | 用途 |
|--------|------|
| `ContentView.swift` | 应用主视图，管理标签页导航 |
| `LoginView.swift` | 登录视图 |
| `HeaderView.swift` | 应用顶部导航栏 |
| `TabBarView.swift` | 底部标签栏 |
| `TimetableView.swift` | 课程表主视图 |
| `BusScheduleView.swift` | 巴士时刻表视图 |
| `AssignmentView.swift` | 作业列表视图 |
| `CourseDetailView.swift` | 课程详情视图 |

#### 核心文件

| 文件名 | 用途 |
|--------|------|
| `tamaApp.swift` | 应用入口点，配置全局服务 |
| `AppDelegate.swift` | 处理应用生命周期、URL 路由、通知注册 |
| `AppearanceManager.swift` | 管理应用外观（深色模式） |

---

## 🔧 小组件扩展 (Widget Extensions)

### TimetableWidget/ - 课程表小组件

| 文件名 | 用途 |
|--------|------|
| `TimetableWidget.swift` | 小组件配置和视图定义 |
| `TimetableWidgetBundle.swift` | 小组件包入口 |
| `TimetableWidgetDataProvider.swift` | 小组件数据提供器 |
| `TimetableWidgetLiveActivity.swift` | 实时活动支持 |

### BusWidget/ - 巴士时刻表小组件

| 文件名 | 用途 |
|--------|------|
| `BusWidget.swift` | 小组件配置和视图定义 |
| `BusWidgetBundle.swift` | 小组件包入口 |
| `BusWidgetDataProvider.swift` | 小组件数据提供器 |
| `BusWidgetLiveActivity.swift` | 实时活动支持 |
| `AppIntent.swift` | App Intent 配置（iOS 17+ 交互） |

---

## 🔌 分享扩展 (PrintShareExtension)

| 文件名 | 用途 |
|--------|------|
| `ShareViewController.swift` | iOS 分享扩展控制器，处理分享内容 |

---

## 🔐 认证流程

```
用户登录流程：
1. 用户点击登录 → LoginView
2. Google OAuth 认证 → GoogleOAuthService
3. 获取访问令牌 → AuthService
4. 保存会话 → CookieService / UserService
5. 更新 UI 状态 → ContentView
```

### 关键认证组件

- **Google OAuth**: 使用 Google 登录获取授权码
- **URL Scheme**: `tama://` 支持深层链接
- **反向客户端 ID**: 用于处理 OAuth 回调

---

## 📡 API 通信架构

```
┌─────────────────────────────────────────────────┐
│                   Views                          │
│              (ContentView, etc.)                 │
└─────────────────────┬───────────────────────────┘
                      │ Notification / Observable
                      ▼
┌─────────────────────────────────────────────────┐
│                  Services                        │
│   (APIService, TimetableService, etc.)          │
└─────────────────────┬───────────────────────────┘
                      │ URLRequest
                      ▼
┌─────────────────────────────────────────────────┐
│                APIService                        │
│   - HTTP headers (HeaderService)                │
│   - Cookies (CookieService)                     │
│   - Error handling                              │
└─────────────────────┬───────────────────────────┘
                      │ HTTPS
                      ▼
┌─────────────────────────────────────────────────┐
│              T-NEXT Backend                       │
└─────────────────────────────────────────────────┘
```

---

## 🔔 通知系统

### 通知类型

1. **远程通知（Push Notifications）**
   - 大学公告、休讲信息
   - 作业截止提醒
   - 通过 `NotificationService` 管理

2. **本地通知（Local Notifications）**
   - 应用内定时提醒
   - 通过 `NotificationCenter` 调度

3. **实时活动（Live Activities）**
   - 课程表更新
   - 巴士时刻变更
   - 支持小组件实时更新

### 通知权限流程

```
App Launch → checkAuthorizationStatus()
    ↓
[Not Determined] → requestAuthorization()
    ↓
[Authorized/Denied] → syncNotificationStatusWithServer()
```

---

## 🎨 主题与外观

- **AppearanceManager**: 管理深色模式切换
- **LanguageService**: 管理多语言支持
- **CourseColorService**: 为不同课程配置显示颜色

---

## 🔄 数据流

### 单向数据流

```
Model → Service → View → User Action → Service → API
```

### 状态管理

- `@State` / `@StateObject`: 局部状态
- `EnvironmentObject`: 全局服务注入
- `Observable`: SwiftUI 5.0+ 响应式状态

---

## 📱 标签页导航

```
┌─────────────────────────────────────┐
│           HeaderView                 │
│    (导航栏 + 登录状态 + 搜索)         │
├─────────┬─────────┬─────────────────┤
│   🚌    │   📚    │      📝         │
│  巴士   │  课程表  │      作业        │
│ Tab 0   │  Tab 1  │     Tab 2       │
└─────────┴─────────┴─────────────────┘
```

---

## 🧪 测试与调试

### 调试标记

```swift
print("Module: Function name")
```

### URL 调试

```
tama://timetable      → 打开课程表
tama://print          → 打开打印系统
```

---

## 📦 依赖管理

- **SwiftUI**: Apple 原生 UI 框架
- **SwiftData**: 本地数据持久化（iOS 17+）
- **WidgetKit**: 小组件开发
- **ActivityKit**: 实时活动支持

---

## 🚀 构建配置

### Target 配置

| Target | 用途 |最低 iOS 版本 |
|--------|------|-------------|
| tama | 主应用 | iOS 15.0 |
| TimetableWidget | 课程表小组件 | iOS 15.0 |
| BusWidget | 巴士小组件 | iOS 15.0 |
| PrintShareExtension | 分享扩展 | iOS 15.0 |

---

## 📝 开发规范

### 文件命名

- **View 文件**: `XxxView.swift`
- **Model 文件**: `XxxModel.swift`
- **Service 文件**: `XxxService.swift`
- **Widget 文件**: `XxxWidget.swift`

### 编码风格

- 使用 **SwiftUI** 声明式 UI
- 遵循 **Apple Swift API Design Guidelines**
- 注释使用 **日文/英文** 混合（项目特性）

---

## 🔗 相关链接

- **App Store**: [TUTnext](https://apps.apple.com/cn/app/tutnext/id6742843580)
- **项目仓库**: [GitHub](https://github.com/Ukenn2112/TUTnextApp)

---

## 📄 许可证

本项目为非官方应用，使用前请参阅 [README.md](./README.md) 中的注意事项。
