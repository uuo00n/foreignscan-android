# ForeignScan - 智能防异物检测系统

ForeignScan 是一款基于 Flutter 开发的智能防异物检测系统，专门用于工业检测中的异物扫描和识别。该应用利用设备相机进行实时图像捕获和分析，帮助检测异物或异常情况，提高生产线质量控制效率。

## 功能特性

- **实时相机扫描**：使用设备相机进行实时异物检测
- **多场景检测**：支持多种检测场景的设置和管理
- **图像处理**：高效图像处理和分析功能
- **数据记录**：自动记录检测结果和历史数据
- **网络监控**：实时监控网络连接状态
- **WiFi通信**：通过WiFi将图像数据传输至处理服务器
- **检测结果展示**：直观显示异物检测结果
- **主题支持**：支持亮色和暗色主题
- **本地存储**：使用本地存储保存检测记录
- **离线工作能力**：支持在网络不稳定环境下工作

## 技术栈

- **框架**: Flutter ^3.9.2
- **语言**: Dart
- **状态管理**: Flutter Riverpod ^2.5.1
- **HTTP 客户端**: Dio ^5.7.0, HTTP
- **相机**: camera ^0.10.5
- **图像处理**: image ^4.2.0, image_picker ^1.1.2
- **网络信息**: network_info_plus ^7.0.0
- **设备信息**: device_info_plus ^10.1.0
- **本地存储**: shared_preferences ^2.2.3
- **缓存管理**: cached_network_image ^3.4.1, flutter_cache_manager ^3.4.1
- **日期格式化**: intl ^0.18.1

## 架构

### 项目结构

```
lib/
├── config/          # 应用配置和常量
│   ├── app_config.dart        # 应用配置
│   └── app_constants.dart     # 应用常量
├── core/            # 核心功能模块
│   ├── models/      # 核心数据模型
│   ├── providers/   # Riverpod 状态管理
│   ├── routes/      # 路由管理
│   │   └── app_router.dart    # 应用路由
│   ├── services/    # 业务服务
│   │   ├── camera_service.dart       # 相机服务
│   │   ├── detection_service.dart    # 检测服务
│   │   ├── image_service.dart        # 图像服务
│   │   ├── record_service.dart       # 记录服务
│   │   ├── scene_service.dart        # 场景服务
│   │   └── wifi_communication_service.dart # WiFi通信服务
│   ├── theme/       # 主题配置
│   │   └── app_theme.dart     # 应用主题
│   └── widgets/     # 通用组件
├── models/          # 数据模型
│   ├── detection_result.dart    # 检测结果模型
│   ├── inspection_record.dart   # 检查记录模型
│   ├── scene_data.dart          # 场景数据模型
│   └── verification_record.dart # 验证记录模型
├── screens/         # 页面组件
│   ├── camera_screen.dart           # 相机界面
│   ├── detection_result_screen.dart # 检测结果界面
│   ├── home_page.dart               # 主页
│   └── image_upload_screen.dart     # 图片上传界面
├── utils/           # 工具函数
│   ├── camera_manager.dart      # 相机管理工具
│   └── screen_utils.dart        # 屏幕工具类
├── widgets/         # 业务组件
│   ├── app_drawer.dart          # 应用抽屉组件
│   ├── records_section.dart     # 记录部分组件
│   ├── scene_display.dart       # 场景显示组件
│   ├── scene_selector.dart      # 场景选择器
│   ├── scene_tile.dart          # 场景瓦片组件
│   └── verification_list.dart   # 验证列表组件
└── main.dart        # 应用入口
```

### 核心功能

1. **相机管理**：封装相机初始化、预览、拍照功能，支持不同分辨率和相机设置
2. **WiFi通信**：通过WiFi将图像数据传输至处理服务器，支持断点续传和错误重试
3. **场景管理**：支持多种检测场景的配置和切换，适应不同的检测需求
4. **检测结果处理**：接收和解析服务器返回的检测结果，提供可视化展示
5. **状态管理**：使用 Riverpod 管理全局状态，确保应用状态一致性
6. **路由系统**：统一的页面导航系统，支持参数传递和返回值处理
7. **主题系统**：亮色/暗色主题支持，提供一致的视觉体验
8. **离线工作**：支持在网络不稳定环境下工作，数据本地缓存和同步
9. **数据服务**：场景管理、记录存储等服务，提供数据持久化

## 安装和运行

### 环境要求

- Flutter SDK ^3.9.2
- Android API 21+ (Android 5.0及以上)
- iOS 12.0及以上
- 设备需要相机和WiFi功能

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

## 使用指南

### 基本流程

1. **启动应用**：打开应用，进入主界面
2. **选择场景**：从可用的检测场景中选择适合当前检测需求的场景
3. **拍摄图像**：使用摄像头拍摄待检测物体
4. **传输数据**：应用将自动通过WiFi将图像传输至处理服务器
5. **查看结果**：检测完成后，查看异物检测结果
6. **保存记录**：系统会自动保存检测记录，可在历史记录中查看

### 网络设置

应用需要连接到处理服务器才能完成异物检测。请确保设备与服务器在同一WiFi网络下，或按照应用内提示配置网络连接。

### 离线模式

当网络不可用时，应用会自动进入离线模式，保存图像数据，待网络恢复后自动同步。

## 项目配置

### 应用配置项

在 `lib/config/app_config.dart` 中可以配置以下参数：

- **相机配置**：分辨率、镜头方向、音频
- **网络配置**：超时时间、重试次数、重试延迟、服务器地址
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
