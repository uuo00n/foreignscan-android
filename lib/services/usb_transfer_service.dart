import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

/// USB传输服务 - 通过ADB桥接实现双向通讯
/// Linus原则：用简单方案解决复杂问题
class USBTransferService {
  static final Logger _logger = Logger();
  static const int serverPort = 8080;
  static const String windowsHost = 'localhost';
  static const String metadataEndpoint = '/api/metadata';

  HttpServer? _server;
  bool _isRunning = false;
  String? _localIP;

  /// 启动文件服务器
  Future<bool> startFileServer() async {
    try {
      if (_isRunning) {
        _logger.w('文件服务器已在运行');
        return true;
      }

      // 获取本机IP地址
      _localIP = await _getLocalIP();
      _logger.i('本地IP地址: $_localIP');

      // 获取DCIM目录路径
      final dcimPath = await _getDCIMPath();
      if (dcimPath == null) {
        _logger.e('无法获取DCIM目录路径');
        return false;
      }

      // 创建静态文件处理器
      final staticHandler = createStaticHandler(
        dcimPath,
        defaultDocument: 'index.html',
        listDirectories: true,
      );

      // 创建API处理器
      final apiHandler = _createAPIHandler();

      // 组合处理器
      final handler = Cascade()
          .add(staticHandler)
          .add(apiHandler)
          .handler;

      // 启动服务器
      _server = await serve(handler, _localIP!, serverPort);
      _isRunning = true;

      _logger.i('文件服务器启动成功: http://$_localIP:$serverPort');
      _logger.i('DCIM目录: $dcimPath');

      return true;
    } catch (e) {
      _logger.e('启动文件服务器失败', error: e);
      return false;
    }
  }

  /// 停止文件服务器
  Future<void> stopFileServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      _logger.i('文件服务器已停止');
    }
  }

  /// 发送图片元数据到Windows端
  Future<bool> sendImageMetadata(String imagePath, DateTime timestamp) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        _logger.e('文件不存在: $imagePath');
        return false;
      }

      final metadata = {
        'path': imagePath,
        'filename': file.uri.pathSegments.last,
        'timestamp': timestamp.toIso8601String(),
        'size': await file.length(),
        'relativePath': await _getRelativePath(imagePath),
      };

      _logger.i('发送图片元数据: ${metadata['filename']}');

      // 通过ADB端口转发发送到Windows
      return await _sendToWindows('image_metadata', metadata);
    } catch (e) {
      _logger.e('发送图片元数据失败', error: e);
      return false;
    }
  }

  /// 请求USB权限（兼容性方法）
  Future<bool> requestUsbPermissions() async {
    try {
      // 检查必要权限
      final permissions = [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ];

      for (final permission in permissions) {
        final status = await permission.request();
        if (!status.isGranted) {
          _logger.w('权限被拒绝: $permission');
          return false;
        }
      }

      _logger.i('USB权限获取成功');
      return true;
    } catch (e) {
      _logger.e('请求USB权限失败', error: e);
      return false;
    }
  }

  /// 检查USB设备是否连接（兼容性方法）
  Future<bool> isUsbDeviceConnected() async {
    try {
      // 检查ADB连接状态
      return await _checkADBConnection();
    } catch (e) {
      _logger.e('检查USB设备连接失败', error: e);
      return false;
    }
  }

  /// 获取可用传输路径（兼容性方法）
  Future<List<String>> getAvailableTransferPaths() async {
    try {
      final dcimPath = await _getDCIMPath();
      if (dcimPath != null) {
        return [dcimPath];
      }
      return [];
    } catch (e) {
      _logger.e('获取传输路径失败', error: e);
      return [];
    }
  }

  /// 准备传输包（兼容性方法）
  Future<Map<String, dynamic>> prepareTransferPackage(List<dynamic> scenes) async {
    try {
      final package = {
        'scenes': scenes,
        'timestamp': DateTime.now().toIso8601String(),
        'total_files': scenes.length,
      };

      _logger.i('传输包准备完成: ${scenes.length} 个场景');
      return package;
    } catch (e) {
      _logger.e('准备传输包失败', error: e);
      return {};
    }
  }

  /// 传输到Windows（兼容性方法）
  Future<bool> transferToWindows({
    required List<dynamic> scenes,
    required String targetDirectory,
  }) async {
    try {
      _logger.i('开始传输到Windows: ${scenes.length} 个场景');

      int successCount = 0;
      for (final scene in scenes) {
        try {
          // 提取场景数据
          final sceneData = scene as Map<String, dynamic>;
          final imagePath = sceneData['imagePath'] as String?;
          final timestamp = sceneData['timestamp'] != null
              ? DateTime.parse(sceneData['timestamp'])
              : DateTime.now();

          if (imagePath != null) {
            // 发送图片元数据
            final success = await sendImageMetadata(imagePath, timestamp);
            if (success) {
              successCount++;
            }
          }
        } catch (e) {
          _logger.e('传输场景失败: $e');
        }
      }

      _logger.i('传输完成: $successCount/${scenes.length} 成功');
      return successCount > 0;
    } catch (e) {
      _logger.e('传输到Windows失败', error: e);
      return false;
    }
  }

  /// 检查ADB连接状态
  Future<bool> _checkADBConnection() async {
    try {
      // 这里可以实现实际的ADB连接检查
      // 目前返回服务器运行状态作为参考
      return _isRunning;
    } catch (e) {
      return false;
    }
  }

  /// 获取文件内容
  Future<Uint8List?> getFileContent(String relativePath) async {
    try {
      final dcimPath = await _getDCIMPath();
      if (dcimPath == null) return null;

      final filePath = '$dcimPath/$relativePath';
      final file = File(filePath);

      if (await file.exists()) {
        return await file.readAsBytes();
      }

      _logger.e('文件不存在: $filePath');
      return null;
    } catch (e) {
      _logger.e('获取文件内容失败', error: e);
      return null;
    }
  }

  /// 检查服务状态
  bool isRunning() => _isRunning;

  /// 获取服务器地址
  String? getServerAddress() => _isRunning ? 'http://$_localIP:$serverPort' : null;

  // 私有方法

  Handler _createAPIHandler() {
    final router = Router();

    router.get('/api/status', _handleStatus);
    router.post('/api/metadata', _handleMetadata);
    router.get('/api/file/<path|.*>', _handleFileRequest);
    router.get('/api/images', _handleImageList);

    return router.call;
  }

  Future<Response> _handleStatus(Request request) async {
    return Response.ok(jsonEncode({
      'status': 'running',
      'serverAddress': getServerAddress(),
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  Future<Response> _handleMetadata(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      _logger.i('收到元数据请求: $data');

      // 处理元数据（可以扩展为保存到数据库等）
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      _logger.e('处理元数据失败', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleFileRequest(Request request) async {
    try {
      final path = request.url.pathSegments.skip(2).join('/'); // Skip 'api' and 'file'
      if (path.isEmpty) {
        return Response.notFound('文件路径不能为空');
      }

      final content = await getFileContent(path);
      if (content == null) {
        return Response.notFound('文件不存在: $path');
      }

      // 根据文件扩展名设置MIME类型
      final mimeType = _getMimeType(path);

      return Response.ok(
        content,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': content.length.toString(),
        },
      );
    } catch (e) {
      _logger.e('处理文件请求失败', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleImageList(Request request) async {
    try {
      final dcimPath = await _getDCIMPath();
      if (dcimPath == null) {
        return Response.internalServerError(
          body: jsonEncode({'error': '无法获取DCIM目录'}),
        );
      }

      final directory = Directory(dcimPath);
      final images = <Map<String, dynamic>>[];

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final path = entity.path;
          final ext = path.toLowerCase();

          if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') ||
              ext.endsWith('.png') || ext.endsWith('.mp4')) {
            final stat = await entity.stat();
            final relativePath = path.replaceFirst('$dcimPath/', '');

            images.add({
              'filename': entity.uri.pathSegments.last,
              'relativePath': relativePath,
              'size': stat.size,
              'modified': stat.modified.toIso8601String(),
            });
          }
        }
      }

      // 按修改时间排序，最新的在前
      images.sort((a, b) => b['modified'].compareTo(a['modified']));

      return Response.ok(jsonEncode({
        'images': images,
        'count': images.length,
      }));
    } catch (e) {
      _logger.e('获取图片列表失败', error: e);
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<String?> _getLocalIP() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } catch (e) {
      _logger.e('获取本地IP失败', error: e);
      return '0.0.0.0';
    }
  }

  Future<String?> _getDCIMPath() async {
    try {
      // 优先使用外部存储
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final dcimPath = '${directory.parent.parent.parent.parent.path}/DCIM/Camera';
        final dcimDir = Directory(dcimPath);
        if (await dcimDir.exists()) {
          return dcimPath;
        }
      }

      // 回退到应用目录
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    } catch (e) {
      _logger.e('获取DCIM路径失败', error: e);
      return null;
    }
  }

  Future<String> _getRelativePath(String fullPath) async {
    final dcimPath = await _getDCIMPath();
    if (dcimPath != null && fullPath.startsWith(dcimPath)) {
      return fullPath.substring(dcimPath.length + 1);
    }
    return fullPath;
  }

  Future<bool> _sendToWindows(String type, Map<String, dynamic> data) async {
    try {
      // 通过ADB端口转发发送到Windows
      final url = 'http://$windowsHost:$serverPort$metadataEndpoint';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('发送到Windows失败', error: e);
      return false;
    }
  }

  String _getMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}