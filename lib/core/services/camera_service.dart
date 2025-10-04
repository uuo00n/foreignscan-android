import 'dart:io';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
  Future<String> saveImageToAppDirectory(String imagePath, {
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
      final fileName = customFileName ?? 
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

  /// 压缩图片（如果需要）
  Future<File> compressImageIfNeeded(File imageFile, {
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