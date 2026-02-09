# TUTnext 重构任务计划

## 🎯 重构目标
- Modern SwiftUI (iOS 17+)
- 液态玻璃设计 (Glassmorphism)
- 模块化架构
- 代码规范化

## 📋 任务清单

### Phase 1: 项目结构重构
- [x] 创建模块化目录结构
- [x] 重构 Core 层 (Networking, Auth, Storage)
- [x] 统一错误处理
- [x] 创建 Base 组件

### Phase 2: UI/UX 重构
- [x] 液态玻璃主题系统
- [x] 统一 Button, Card, Modal 组件
- [x] 暗色模式优化
- [x] 动效系统
- [x] Views 层重构 ✅ (LoginView, WelcomeView, TimetableView, BusScheduleView, AssignmentView, UserSettingsView)

### Phase 3: 功能模块重构
- [x] Auth 模块 (OAuth, Session)
- [x] Timetable 模块
- [x] BusSchedule 模块
- [x] Assignment 模块
- [x] Notification 模块 ✅

### Phase 4: Widgets 重构
- [ ] TimetableWidget (iOS 17+)
- [ ] BusWidget (iOS 17+)

### Phase 5: 测试与优化
- [ ] 单元测试覆盖
- [ ] 性能优化
- [ ] 内存泄漏检测

## 🔧 技术规范

### 依赖版本
- iOS 17.0+
- Swift 5.9+
- Xcode 15+

### 架构模式
- MVVM + Coordinator
- Repository Pattern
- Dependency Injection
