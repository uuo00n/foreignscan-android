class AppConfig {
  static const String appName = '智能防异物检测系统';
  static const String appVersion = '1.0.0';
  
  // 相机配置
  static const CameraConfig camera = CameraConfig();
  
  // 网络配置
  static const NetworkConfig network = NetworkConfig();
  
  // 图片配置
  static const ImageConfig image = ImageConfig();
  
  // 检测配置
  static const DetectionConfig detection = DetectionConfig();
}

class CameraConfig {
  const CameraConfig();
  
  static const String resolution = 'high';
  static const String lensDirection = 'back';
  static const bool enableAudio = false;
}

class NetworkConfig {
  const NetworkConfig();
  
  static const Duration timeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
}

class ImageConfig {
  const ImageConfig();
  
  static const int maxWidth = 1920;
  static const int maxHeight = 1080;
  static const int quality = 85;
  static const int maxSizeBytes = 5 * 1024 * 1024; // 5MB
}

class DetectionConfig {
  const DetectionConfig();
  
  static const double confidenceThreshold = 0.5;
  static const int maxObjectsPerImage = 10;
  static const List<String> supportedFormats = ['jpg', 'jpeg', 'png'];
}