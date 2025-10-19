import 'dart:io';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'usb_transfer_service.dart';
import '../core/providers/usb_transfer_provider.dart';

/// 相机集成服务 - 拍照并自动传输到Windows
/// Linus原则：一个函数只做一件事，但要做好
class CameraIntegrationService {
  static final Logger _logger = Logger();

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isTransferEnabled = true;

  final USBTransferService _usbTransferService;

  CameraIntegrationService(this._usbTransferService);

  /// 初始化相机
  Future<bool> initializeCamera() async {
    try {
      // 检查权限
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _logger.e('相机权限被拒绝');
        return false;
      }

      // 检查存储权限
      final storagePermission = await Permission.storage.request();
      if (!storagePermission.isGranted) {
        _logger.w('存储权限被拒绝，可能影响文件保存');
      }

      // 获取可用相机
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _logger.e('未找到可用相机');
        return false;
      }

      // 选择后置相机
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // 创建相机控制器
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      // 初始化相机
      await _controller!.initialize();
      _isInitialized = true;

      _logger.i('相机初始化成功');
      return true;
    } catch (e) {
      _logger.e('相机初始化失败', error: e);
      return false;
    }
  }

  /// 拍照并传输
  Future<String?> captureAndTransfer() async {
    if (!_isInitialized || _controller == null) {
      _logger.e('相机未初始化');
      return null;
    }

    try {
      // 拍照
      final XFile photo = await _controller!.takePicture();
      final String photoPath = photo.path;

      _logger.i('拍照成功: $photoPath');

      // 获取当前时间戳
      final DateTime timestamp = DateTime.now();

      // 保存到DCIM目录（确保Windows端可以访问）
      final String? savedPath = await _saveToDCIM(photoPath, timestamp);
      if (savedPath == null) {
        _logger.e('保存到DCIM目录失败');
        return null;
      }

      // 如果启用了传输，发送到Windows
      if (_isTransferEnabled) {
        final bool transferSuccess = await _usbTransferService.sendImageMetadata(
          savedPath,
          timestamp,
        );

        if (transferSuccess) {
          _logger.i('图片元数据传输成功');
        } else {
          _logger.w('图片元数据传输失败，但文件已保存');
        }
      }

      return savedPath;
    } catch (e) {
      _logger.e('拍照或传输失败', error: e);
      return null;
    }
  }

  /// 批量传输现有图片
  Future<int> transferExistingImages() async {
    try {
      final dcimPath = await _getDCIMPath();
      if (dcimPath == null) {
        _logger.e('无法获取DCIM目录');
        return 0;
      }

      final directory = Directory(dcimPath);
      int transferredCount = 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final filePath = entity.path;
          final ext = path.extension(filePath).toLowerCase();

          // 只处理图片文件
          if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') {
            final stat = await entity.stat();

            // 发送元数据到Windows
            final success = await _usbTransferService.sendImageMetadata(
              filePath,
              stat.modified,
            );

            if (success) {
              transferredCount++;
              _logger.i('传输成功: ${path.basename(filePath)}');
            } else {
              _logger.w('传输失败: ${path.basename(filePath)}');
            }

            // 避免传输过快，稍作延迟
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }

      _logger.i('批量传输完成，共传输 $transferredCount 个文件');
      return transferredCount;
    } catch (e) {
      _logger.e('批量传输失败', error: e);
      return 0;
    }
  }

  /// 获取相机控制器
  CameraController? getController() => _controller;

  /// 检查相机是否已初始化
  bool isInitialized() => _isInitialized;

  /// 设置传输开关
  void setTransferEnabled(bool enabled) {
    _isTransferEnabled = enabled;
    _logger.i('传输开关: ${enabled ? "开启" : "关闭"}');
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      _logger.i('相机资源已释放');
    }
  }

  // 私有方法

  Future<String?> _saveToDCIM(String tempPath, DateTime timestamp) async {
    try {
      final dcimPath = await _getDCIMPath();
      if (dcimPath == null) {
        return null;
      }

      // 创建时间戳文件名
      final timestampStr = timestamp.toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'foreignscan_$timestampStr.jpg';
      final targetPath = path.join(dcimPath, fileName);

      // 复制文件到DCIM目录
      final tempFile = File(tempPath);
      final targetFile = await tempFile.copy(targetPath);

      _logger.i('文件已保存到DCIM: $targetPath');
      return targetFile.path;
    } catch (e) {
      _logger.e('保存到DCIM失败', error: e);
      return null;
    }
  }

  Future<String?> _getDCIMPath() async {
    try {
      // Android标准DCIM路径
      final externalStorage = await getExternalStorageDirectory();
      if (externalStorage != null) {
        // 通常路径: /storage/emulated/0/DCIM/Camera
        final dcimPath = path.join(
          externalStorage.parent.parent.parent.parent.path,
          'DCIM',
          'Camera',
        );

        final dcimDir = Directory(dcimPath);
        if (await dcimDir.exists()) {
          return dcimPath;
        }

        // 如果Camera目录不存在，创建它
        await dcimDir.create(recursive: true);
        return dcimPath;
      }

      // 回退到应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final customDcim = path.join(appDir.path, 'DCIM', 'Camera');
      final customDir = Directory(customDcim);

      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }

      return customDcim;
    } catch (e) {
      _logger.e('获取DCIM路径失败', error: e);
      return null;
    }
  }
}

/// Provider定义
final cameraIntegrationServiceProvider = Provider<CameraIntegrationService>((ref) {
  final usbService = ref.watch(usbTransferServiceProvider);
  return CameraIntegrationService(usbService);
});