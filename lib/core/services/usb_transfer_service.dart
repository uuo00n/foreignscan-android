import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:foreignscan/models/scene_data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class UsbTransferService {
  final Logger _logger;

  UsbTransferService(this._logger);

  /// Transfers captured images and timestamps to Windows via USB/MTP
  /// This method collects all captured images and their metadata then simulates
  /// the transfer to a Windows device via USB connection
  Future<bool> transferToWindows({
    required List<SceneData> scenes,
    required String targetDirectory,
    bool cleanupAfterTransfer = true,
  }) async {
    try {
      // First check if we have the necessary permissions
      final permissionsGranted = await _checkStoragePermission();
      if (!permissionsGranted) {
        _logger.e('没有必要的权限进行USB传输。请在设置中开启存储权限。');
        // Provide a more user-friendly error
        throw Exception('没有必要的存储权限，请在设置中开启权限后重试');
      }

      _logger.i('开始USB传输过程，目标目录: $targetDirectory');
      
      // Create target directory if it doesn't exist
      final targetDir = Directory(targetDirectory);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Collect all captured images and their metadata
      final capturedScenes = scenes.where((scene) => scene.capturedImage != null).toList();
      
      if (capturedScenes.isEmpty) {
        _logger.w('没有捕获的图片需要传输');
        return true; // Consider no data to transfer as successful operation
      }

      _logger.i('找到 ${capturedScenes.length} 个包含图片的场景准备传输');

      // Create a metadata file containing timestamp and scene information
      final metadata = await _createMetadataFile(capturedScenes, targetDir);
      
      // Copy all captured images to the target directory
      await _copyImagesToTarget(capturedScenes, targetDir);

      _logger.i('USB传输完成，共传输 ${capturedScenes.length} 张图片和 1 个元数据文件');
      
      // 清空传输目录中的临时文件
      if (cleanupAfterTransfer) {
        await cleanupTransferDirectory(targetDirectory);
      }
      
      return true;
    } catch (e, stackTrace) {
      _logger.e('USB传输失败', error: e, stackTrace: stackTrace);
      // Provide specific error message for permission-related issues
      if (e.toString().contains('Permission') || e.toString().contains('Storage')) {
        _logger.e('可能是权限问题，请检查应用权限设置');
      }
      return false;
    }
  }

  /// Creates a metadata file containing information about captured images
  Future<String> _createMetadataFile(List<SceneData> scenes, Directory targetDir) async {
    try {
      final metadata = <String, dynamic>{
        'transfer_timestamp': DateTime.now().toIso8601String(),
        'total_captured_scenes': scenes.length,
        'scenes': scenes.map((scene) {
          return {
            'id': scene.id,
            'name': scene.name,
            'image_path': scene.capturedImage,
            'image_filename': path.basename(scene.capturedImage!),
            'capture_time': scene.captureTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'transfer_time': DateTime.now().toIso8601String(),
          };
        }).toList(),
      };

      final metadataContent = JsonEncoder.withIndent('  ').convert(metadata);
      final metadataFile = File('${targetDir.path}/transfer_metadata.json');
      await metadataFile.writeAsString(metadataContent);

      _logger.i('元数据文件创建成功: ${metadataFile.path}');
      return metadataFile.path;
    } catch (e, stackTrace) {
      _logger.e('创建元数据文件失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Copies captured images to the target directory
  Future<void> _copyImagesToTarget(List<SceneData> scenes, Directory targetDir) async {
    try {
      for (int i = 0; i < scenes.length; i++) {
        final scene = scenes[i];
        if (scene.capturedImage != null) {
          final sourceFile = File(scene.capturedImage!);
          
          // Check if source file exists
          if (!await sourceFile.exists()) {
            _logger.w('源图片文件不存在: ${scene.capturedImage}');
            continue;
          }

          // Create a filename with scene info and timestamp
          final originalExtension = path.extension(scene.capturedImage!);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newFileName = 'scene_${scene.id}_${scene.name}_${timestamp}${originalExtension}';
          final targetFile = File('${targetDir.path}/$newFileName');

          // Copy the file
          await sourceFile.copy(targetFile.path);
          _logger.d('图片复制完成 ($i+1/${scenes.length}): ${sourceFile.path} -> ${targetFile.path}');
        }
      }
    } catch (e, stackTrace) {
      _logger.e('复制图片文件失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Alternative transfer method that simulates MTP connection
  /// This would be used when actual MTP connection is established
  Future<bool> transferViaMtpSimulation({
    required List<SceneData> scenes,
    required String devicePath,
  }) async {
    try {
      _logger.i('开始MTP模拟传输，设备路径: $devicePath');
      
      // In a real implementation, this would connect to the MTP device
      // For simulation, we'll copy files to the simulated device path
      final success = await transferToWindows(
        scenes: scenes,
        targetDirectory: devicePath,
      );
      
      if (success) {
        _logger.i('MTP模拟传输成功');
      } else {
        _logger.e('MTP模拟传输失败');
      }
      
      return success;
    } catch (e, stackTrace) {
      _logger.e('MTP模拟传输过程中出现错误', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Checks if USB device is connected and accessible
  /// This method simulates device detection
  Future<bool> isUsbDeviceConnected() async {
    try {
      // Check storage permissions first
      final permissionGranted = await _checkStoragePermission();
      if (!permissionGranted) {
        _logger.w('存储权限未授予，无法访问USB设备。请在设置中开启权限。');
        return false;
      }

      // In a real implementation, this would check for actual USB/MTP devices
      // For simulation, we'll return true to allow testing
      _logger.d('检查USB设备连接状态...');
      
      // This is where we would normally check for connected USB devices
      // On Android, we might use a plugin like usb_serialport or similar
      return true;
    } catch (e) {
      _logger.e('检查USB设备连接时出错', error: e);
      // Provide more specific error info
      if (e.toString().contains('Permission')) {
        _logger.e('权限错误，请检查应用权限设置');
      }
      return false;
    }
  }

  /// Check if storage permission is granted
  Future<bool> _checkStoragePermission() async {
    try {
      PermissionStatus status;
      
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use the newer photo/media permissions
        // For Android 11-12 (API 30-32), use MANAGE_EXTERNAL_STORAGE for full access
        // For older versions, use the legacy storage permission
        
        // Get Android API level
        int androidApiLevel = await _getAndroidApiLevel();
        
        if (androidApiLevel >= 33) { // Android 13+
          // For Android 13+, request media permissions instead of full storage access
          _logger.d('Android 13+ detected (API $androidApiLevel), requesting media permissions');
          
          // Try photos permission first
          status = await Permission.photos.request();
          _logger.d('Photos permission status: ${status}');
          
          if (!status.isGranted) {
            _logger.w('Photos permission denied, attempting to request storage permission');
            status = await Permission.storage.request();
            _logger.d('Storage permission status: ${status}');
          }
        } else if (androidApiLevel >= 30) { // Android 11-12 (Scoped Storage)
          // For Android 11+, MANAGE_EXTERNAL_STORAGE permission is needed for full access
          _logger.d('Android 11+ detected (API $androidApiLevel), requesting manage external storage permission');
          status = await Permission.manageExternalStorage.request();
          _logger.d('Manage external storage permission status: ${status}');
          
          if (!status.isGranted) {
            _logger.w('Manage external storage permission denied, falling back to storage permission');
            status = await Permission.storage.request();
            _logger.d('Storage permission status: ${status}');
          }
        } else {
          // For older Android versions, traditional storage permission
          _logger.d('Older Android version (API $androidApiLevel), requesting traditional storage permission');
          status = await Permission.storage.request();
          _logger.d('Storage permission status: ${status}');
        }
      } else if (Platform.isIOS) {
        // For iOS, request photos permission
        status = await Permission.photos.request();
        _logger.d('iOS photos permission status: ${status}');
      } else {
        // For other platforms, try the storage permission
        status = await Permission.storage.request();
        _logger.d('Non-Android platform storage permission status: ${status}');
      }
      
      if (status.isGranted) {
        _logger.d('存储权限已授予');
        return true;
      } else if (status.isDenied) {
        _logger.w('存储权限被拒绝，请在设置中手动开启');
        return false;
      } else if (status.isPermanentlyDenied) {
        _logger.e('存储权限被永久拒绝，需要引导用户到设置页面');
        // Optionally open app settings
        openAppSettings();
        return false;
      } else if (status.isLimited) {
        _logger.d('存储权限被限制（仅部分允许）');
        return true; // For limited access, we can still proceed with media access
      }
      
      _logger.w('未知的权限状态: ${status}');
      return false;
    } catch (e) {
      _logger.e('检查存储权限时出错', error: e);
      return false;
    }
  }
  
  /// Get Android API level from device info
  Future<int> _getAndroidApiLevel() async {
    try {
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int apiLevel = androidInfo.version.sdkInt;
        _logger.d('Detected Android API level: $apiLevel');
        return apiLevel;
      } else {
        // For non-Android platforms, return a default
        return 30; // Default to Android 11 behavior
      }
    } catch (e) {
      _logger.e('解析Android API级别时出错: $e');
      return 30; // Default to Android 11 behavior
    }
  }

  /// Request necessary permissions for USB/MTP access
  Future<bool> requestUsbPermissions() async {
    try {
      _logger.d('请求USB/MTP相关权限...');
      
      List<Permission> permissions = [];
      
      // Depending on the Android version, request appropriate permissions
      if (Platform.isAndroid) {
        int androidApiLevel = await _getAndroidApiLevel();
        
        if (androidApiLevel >= 33) { // Android 13+
          // Android 13+ requires media permissions instead of full storage access
          _logger.d('Android 13+ detected (API $androidApiLevel), requesting media permissions');
          permissions.add(Permission.photos);
          permissions.add(Permission.videos);
        } else if (androidApiLevel >= 30) { // Android 11-12 (Scoped Storage)
          // Android 11+ may need MANAGE_EXTERNAL_STORAGE for full access
          _logger.d('Android 11+ detected (API $androidApiLevel), requesting manage external storage permission');
          permissions.add(Permission.manageExternalStorage);
        } else {
          // For older Android versions
          _logger.d('Older Android version (API $androidApiLevel), requesting storage permission');
          permissions.add(Permission.storage);
        }
      } else if (Platform.isIOS) {
        // For iOS, request photos permission
        _logger.d('iOS detected, requesting photos permission');
        permissions.add(Permission.photos);
      } else {
        // For other platforms
        _logger.d('Non-Android platform, requesting storage permission');
        permissions.add(Permission.storage);
      }

      // Request all permissions
      Map<Permission, PermissionStatus> statuses = await permissions.request();

      bool allGranted = true;
      for (final entry in statuses.entries) {
        if (!entry.value.isGranted) {
          _logger.w('权限被拒绝: ${entry.key} (状态: ${entry.value})');
          allGranted = false;
        } else {
          _logger.d('权限已授予: ${entry.key}');
        }
      }

      if (allGranted) {
        _logger.i('所有必要权限已授予');
      } else {
        _logger.w('部分权限被拒绝，功能可能受限');
        // Show user-friendly message about permissions
        _logger.w('请在应用设置中手动开启必要的权限以正常使用USB传输功能');
      }

      return allGranted;
    } catch (e, stackTrace) {
      _logger.e('请求USB权限时出错', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets list of available USB storage devices
  /// Returns paths where files can be transferred
  Future<List<String>> getAvailableTransferPaths() async {
    try {
      // In a real implementation, this would scan for connected USB/MTP devices
      // For simulation, return a list of possible paths
      final paths = <String>[];
      
      // Simulated Windows paths
      paths.add('/storage/emulated/0/USB_TRANSFER'); // Simulated path
      
      // Add any connected MTP devices in real implementation
      _logger.d('可用传输路径: $paths');
      
      return paths;
    } catch (e) {
      _logger.e('获取可用传输路径时出错', error: e);
      return [];
    }
  }

  /// Prepares data package for transfer
  /// Collects all necessary files and creates a transfer package
  Future<Map<String, dynamic>> prepareTransferPackage(List<SceneData> scenes) async {
    try {
      final capturedScenes = scenes.where((scene) => scene.capturedImage != null).toList();
      final filesToTransfer = <String>[];
      
      // Add metadata file path
      filesToTransfer.add('transfer_metadata.json');
      
      // Add image files
      for (final scene in capturedScenes) {
        if (scene.capturedImage != null) {
          filesToTransfer.add(path.basename(scene.capturedImage!));
        }
      }

      final transferPackage = <String, dynamic>{
        'scenes_count': capturedScenes.length,
        'files_count': filesToTransfer.length,
        'files': filesToTransfer,
        'estimated_size': await _calculateEstimatedSize(capturedScenes),
        'timestamp': DateTime.now().toIso8601String(),
      };

      _logger.i('传输包准备完成: ${transferPackage['scenes_count']} 个场景, '
                '${transferPackage['files_count']} 个文件, '
                '预计大小: ${transferPackage['estimated_size']} bytes');
      
      return transferPackage;
    } catch (e, stackTrace) {
      _logger.e('准备传输包时出错', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Calculates estimated size of files to be transferred
  Future<int> _calculateEstimatedSize(List<SceneData> scenes) async {
    try {
      int totalSize = 0;
      
      for (final scene in scenes) {
        if (scene.capturedImage != null) {
          final file = File(scene.capturedImage!);
          if (await file.exists()) {
            totalSize += await file.length();
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      _logger.e('计算文件大小时出错', error: e);
      return 0;
    }
  }
  
  /// 清空传输目录中的临时文件
  /// 在传输成功后调用，清理传输过程中产生的临时文件
  Future<void> cleanupTransferDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      
      // 检查目录是否存在
      if (!await directory.exists()) {
        _logger.w('清理目录不存在: $directoryPath');
        return;
      }
      
      _logger.i('开始清理传输目录: $directoryPath');
      
      // 获取目录中的所有文件
      final entities = await directory.list().toList();
      int deletedCount = 0;
      
      // 删除所有文件
      for (final entity in entities) {
        if (entity is File) {
          await entity.delete();
          deletedCount++;
          _logger.d('已删除文件: ${entity.path}');
        }
      }
      
      _logger.i('传输目录清理完成，共删除 $deletedCount 个文件');
    } catch (e, stackTrace) {
      _logger.e('清理传输目录失败', error: e, stackTrace: stackTrace);
    }
  }
}