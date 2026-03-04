import 'dart:io';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:device_info_plus/device_info_plus.dart';

class CameraService {
  final Logger _logger;

  CameraService(this._logger);

  /// 检查并请求相机权限
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();

      if (status.isGranted) {
        _logger.i('相机权限已授予');
        return true;
      } else if (status.isDenied) {
        _logger.w('相机权限被拒绝');
        return false;
      } else if (status.isPermanentlyDenied) {
        _logger.e('相机权限被永久拒绝，需要引导用户到设置页面');
        return false;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e('请求相机权限失败', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 检查相机权限状态
  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      _logger.e('检查相机权限失败', error: e);
      return false;
    }
  }

  /// 请求存储权限
  Future<bool> requestStoragePermission() async {
    try {
      PermissionStatus status;

      // Android 13+ 使用新的媒体权限
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        if (deviceInfo.version.sdkInt >= 33) {
          // Android 13+ 请求媒体权限（只请求图片写入权限即可）
          status = await Permission.photos.request();
        } else if (deviceInfo.version.sdkInt >= 30) {
          // Android 11-12 使用分区存储，不需要特殊权限
          status = PermissionStatus.granted;
        } else {
          // Android 10及以下 请求传统存储权限
          status = await Permission.storage.request();
        }
      } else {
        // iOS 请求照片权限
        status = await Permission.photos.request();
      }

      if (status.isGranted) {
        _logger.i('存储权限已授予');
        return true;
      } else if (status.isDenied) {
        _logger.w('存储权限被拒绝');
        return false;
      } else if (status.isPermanentlyDenied) {
        _logger.e('存储权限被永久拒绝，需要引导用户到设置页面');
        return false;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e('请求存储权限失败', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 获取可用相机列表
  Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      final cameras = await availableCameras();
      _logger.i('发现 ${cameras.length} 个相机');
      return cameras;
    } catch (e, stackTrace) {
      _logger.e('获取相机列表失败', error: e, stackTrace: stackTrace);
      throw Exception('获取相机列表失败: $e');
    }
  }

  /// 保存图片到应用目录
  Future<String> saveImageToAppDirectory(
    String imagePath, {
    required String folderName,
    String? customFileName,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(path.join(appDir.path, folderName));

      // 创建目录（如果不存在）
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 生成文件名
      final fileName =
          customFileName ??
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imagePath)}';
      final targetPath = path.join(targetDir.path, fileName);

      // 复制文件
      final sourceFile = File(imagePath);
      final savedFile = await sourceFile.copy(targetPath);

      _logger.i('保存图片到应用目录: $targetPath');
      return savedFile.path;
    } catch (e, stackTrace) {
      _logger.e('保存图片失败', error: e, stackTrace: stackTrace);
      throw Exception('保存图片失败: $e');
    }
  }

  /// 保存图片到共享目录（用于与桌面应用同步）
  Future<String> saveImageToSharedDirectory(
    String imagePath, {
    String? customFileName,
  }) async {
    try {
      // 多层回退策略：优先使用公共Pictures目录，其次应用私有目录
      Directory? baseDir;

      // 第一选择：获取Pictures公共目录（Android 10+兼容）
      try {
        final picturesDir = Directory('/storage/emulated/0/Pictures');
        if (await picturesDir.exists()) {
          // 检查是否有权限访问
          final testFile = File(path.join(picturesDir.path, '.test'));
          try {
            await testFile.create(recursive: false);
            await testFile.delete();
            baseDir = picturesDir;
          } catch (e) {
            _logger.d('无法写入Pictures目录: $e');
          }
        }
      } catch (e) {
        _logger.d('无法访问公共Pictures目录: $e');
      }

      // 第二选择：获取应用外部存储目录
      if (baseDir == null) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null && await externalDir.exists()) {
          baseDir = externalDir;
        }
      }

      // 第三选择：使用应用文档目录
      baseDir ??= await getApplicationDocumentsDirectory();

      final sharedDir = Directory(
        path.join(baseDir.path, 'ForeignScan', 'shared'),
      );

      // 创建目录（如果不存在）
      if (!await sharedDir.exists()) {
        await sharedDir.create(recursive: true);
      }

      // 生成文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          customFileName ??
          'foreignscan_$timestamp${path.extension(imagePath)}';
      final targetPath = path.join(sharedDir.path, fileName);

      // 复制文件
      final sourceFile = File(imagePath);
      final savedFile = await sourceFile.copy(targetPath);

      _logger.i('保存图片到共享目录: $targetPath');
      return savedFile.path;
    } catch (e, stackTrace) {
      _logger.e('保存图片到共享目录失败', error: e, stackTrace: stackTrace);
      throw Exception('保存图片到共享目录失败: $e');
    }
  }

  /// 压缩图片（如果需要）
  Future<File> compressImageIfNeeded(
    File imageFile, {
    int maxSizeBytes = 5 * 1024 * 1024, // 5MB
  }) async {
    try {
      final fileSize = await imageFile.length();

      if (fileSize <= maxSizeBytes) {
        _logger.d('图片大小合适，无需压缩: ${(fileSize / 1024).toStringAsFixed(2)}KB');
        return imageFile;
      }

      // 这里可以集成图片压缩逻辑
      _logger.i('图片需要压缩: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
      return imageFile;
    } catch (e, stackTrace) {
      _logger.e('图片压缩失败', error: e, stackTrace: stackTrace);
      return imageFile; // 如果压缩失败，返回原文件
    }
  }

  /// 验证图片文件
  Future<bool> validateImageFile(String imagePath) async {
    try {
      final file = File(imagePath);

      if (!await file.exists()) {
        _logger.e('图片文件不存在: $imagePath');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _logger.e('图片文件为空: $imagePath');
        return false;
      }

      const maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        _logger.e('图片文件过大: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
        return false;
      }

      _logger.d('图片文件验证通过: $imagePath');
      return true;
    } catch (e) {
      _logger.e('图片文件验证失败: $imagePath', error: e);
      return false;
    }
  }

  /// 获取图片信息
  Future<Map<String, dynamic>> getImageInfo(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileSize = await file.length();
      final fileName = path.basename(imagePath);
      final extension = path.extension(imagePath).toLowerCase();

      return {
        'path': imagePath,
        'name': fileName,
        'size': fileSize,
        'sizeKB': (fileSize / 1024).toStringAsFixed(2),
        'sizeMB': (fileSize / 1024 / 1024).toStringAsFixed(2),
        'extension': extension,
        'timestamp': await file.lastModified(),
      };
    } catch (e, stackTrace) {
      _logger.e('获取图片信息失败', error: e, stackTrace: stackTrace);
      throw Exception('获取图片信息失败: $e');
    }
  }

  /// 清理临时图片文件
  Future<void> cleanupTempImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync();

      int deletedCount = 0;
      for (final file in tempFiles) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith('temp_') || fileName.startsWith('capture_')) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      _logger.i('清理临时图片完成: 删除 $deletedCount 个文件');
    } catch (e, stackTrace) {
      _logger.e('清理临时图片失败', error: e, stackTrace: stackTrace);
    }
  }
}
