import 'package:camera/camera.dart';
import 'package:logger/logger.dart';

class CameraManager {
  static List<CameraDescription> cameras = [];

  static Future<void> initialize() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      // 使用日志系统而不是print
      Logger().e('相机初始化失败', error: e);
    }
  }

  static bool hasCameras() {
    return cameras.isNotEmpty;
  }

  static CameraDescription? getFirstCamera() {
    return cameras.isNotEmpty ? cameras[0] : null;
  }
}