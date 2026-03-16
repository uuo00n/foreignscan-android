class AppConstants {
  // 路由名称
  static const String routeHome = '/home';
  static const String routeCamera = '/camera';
  static const String routeDetectionResult = '/detection-result';
  static const String routeImageUpload = '/image-upload';
  static const String routeSettings = '/settings';
  static const String routeRecords = '/records';
  static const String routeRecordDetail = '/record-detail';

  // 存储键名
  static const String keyDetectionRecords = 'detection_records';
  static const String keyAppSettings = 'app_settings';
  static const String keyCameraSettings = 'camera_settings';

  // 错误代码
  static const String errorCameraInit = 'CAMERA_INIT_ERROR';
  static const String errorImageCapture = 'IMAGE_CAPTURE_ERROR';
  static const String errorNetwork = 'NETWORK_ERROR';
  static const String errorStorage = 'STORAGE_ERROR';
  static const String errorValidation = 'VALIDATION_ERROR';

  // 检测类型
  static const String detectionTypeScene1 = 'scene1';
  static const String detectionTypeScene2 = 'scene2';
  static const String detectionTypeScene3 = 'scene3';
  static const String detectionTypeScene4 = 'scene4';

  static const List<String> detectionTypes = [
    detectionTypeScene1,
    detectionTypeScene2,
    detectionTypeScene3,
    detectionTypeScene4,
  ];

  // UI 常量
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double borderRadius = 12.0;
  static const double elevation = 4.0;

  // 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackbarDuration = Duration(seconds: 3);

  // 文件路径
  static const String folderDetectionImages = 'detection_images';
  static const String folderTempImages = 'temp_images';
}
