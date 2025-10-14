# ForeignScan - 智能防异物检测系统

ForeignScan 是一款基于 Flutter 开发的智能防异物检测系统，专门用于工业检测中的异物扫描和识别。该应用利用设备相机进行实时图像捕获和分析，帮助检测异物或异常情况。

## 功能特性

- **实时相机扫描**：使用设备相机进行实时异物检测
- **多场景检测**：支持多种检测场景的设置和管理
- **图像处理**：高效图像处理和分析功能
- **数据记录**：自动记录检测结果和历史数据
- **网络监控**：实时监控网络连接状态
- **数据传输**：支持检测结果的数据传输
- **主题支持**：支持亮色和暗色主题
- **本地存储**：使用本地存储保存检测记录

## 技术栈

- **框架**: Flutter 3.x
- **语言**: Dart
- **状态管理**: Riverpod
- **HTTP 客户端**: Dio
- **相机**: camera
- **网络监控**: connectivity_plus
- **本地存储**: shared_preferences
- **日志**: logger

## 架构

### 项目结构

```
lib/
├── config/          # 应用配置
├── core/            # 核心功能模块
│   ├── providers/   # Riverpod 状态管理
│   ├── routes/      # 路由管理
│   ├── services/    # 业务服务
│   ├── theme/       # 主题配置
│   └── widgets/     # 通用组件
├── models/          # 数据模型
├── screens/         # 页面组件
├── utils/           # 工具函数
├── widgets/         # 业务组件
└── main.dart        # 应用入口
```

### 核心功能

1. **相机管理**：封装相机初始化、预览、拍照功能
2. **状态管理**：使用 Riverpod 管理全局状态
3. **路由系统**：统一的页面导航系统
4. **主题系统**：亮色/暗色主题支持
5. **数据服务**：场景管理、记录存储等服务

## 安装和运行

### 环境要求

- Flutter SDK 3.x 或更高版本
- Android API 21+ 或 iOS 9.0+

### 安装步骤

1. 克隆项目

```bash
git clone <repository-url>
cd foreignscan
```

2. 安装依赖

```bash
flutter pub get
```

3. 运行应用

```bash
flutter run
```

### 构建应用

#### Android

```bash
flutter build apk --release
```

#### iOS

```bash
flutter build ios --release
```

## 项目配置

### 应用配置项

在 `lib/config/app_config.dart` 中可以配置以下参数：

- **相机配置**：分辨率、镜头方向、音频
- **网络配置**：超时时间、重试次数、重试延迟
- **图像配置**：最大尺寸、质量、最大文件大小
- **检测配置**：置信度阈值、最大检测对象数

## 开发指南

### 添加新页面

1. 在 `screens/` 目录下创建新页面
2. 在 `lib/core/routes/app_router.dart` 中添加路由定义
3. 使用 `AppRouter.navigateToXXX()` 进行页面跳转

### 添加新状态管理器

1. 在 `lib/core/providers/` 下创建新的 Provider
2. 按照 Riverpod 最佳实践定义状态
3. 在需要的组件中使用 `ref.watch()` 或 `ref.read()` 访问

### 主题定制

在 `lib/core/theme/app_theme.dart` 中可以自定义颜色和主题样式：

```dart

static const Color primaryColor = Color(0xFF2196F3);
static const Color secondaryColor = Color(0xFF03DAC6);
```

## 依赖说明

### 主要依赖

- `camera` - 相机功能
- `flutter_riverpod` - 状态管理
- `dio` - HTTP 请求
- `shared_preferences` - 本地数据存储
- `connectivity_plus` - 网络状态检测
- `image` - 图像处理
- `logger` - 日志记录

### 开发依赖

- `build_runner` - 代码生成
- `riverpod_generator` - Riverpod 代码生成
- `json_serializable` - JSON 序列化

## 已知问题和注意事项

- 应用需要相机权限
- Android 6.0+ 需要动态权限请求
- iOS 需要在 `Info.plist` 中添加相机使用说明

## 支持

如需技术支持或有疑问，请联系 uuo00_n@outlook.com
