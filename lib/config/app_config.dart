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
  
  // 后端 API 基础地址（注意：在真机上不可使用 localhost，需要填写宿主机的局域网IP，例如 http://192.168.1.100:3000/api）
  // 已根据你的后端地址修改为 172.20.10.3:3000
  static const String apiBaseUrl = 'http://172.20.10.3:3000/api';

  static const Duration timeout = Duration(seconds: 10);
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