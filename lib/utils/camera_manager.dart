import 'package:camera/camera.dart';

class CameraManager {
  static List<CameraDescription> cameras = [];

  static Future<void> initialize() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('相机初始化失败: $e');
    }
  }

  static bool hasCameras() {
    return cameras.isNotEmpty;
  }

  static CameraDescription? getFirstCamera() {
    return cameras.isNotEmpty ? cameras[0] : null;
  }
}