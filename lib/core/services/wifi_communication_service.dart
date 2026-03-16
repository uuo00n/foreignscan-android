import 'dart:io';
import 'package:dio/dio.dart';
// Removed: import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:logger/logger.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WiFiCommunicationService {
  // 默认服务器 IP 和端口
  // 注意：这些默认值仅在用户未配置服务器地址时使用。
  // 实际运行时会通过 setServerAddress() 方法被 SharedPreferences 中用户保存的配置覆盖。
  static const String _defaultServerIP = '172.20.10.3';
  static const int _defaultPort = 8080;
  static const Duration _connectionTimeout = Duration(seconds: 10);

  final Logger _logger;
  final Dio _dio;
  String _serverIP = _defaultServerIP;
  int _port = _defaultPort;

  WiFiCommunicationService(this._logger)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: _connectionTimeout,
          receiveTimeout: _connectionTimeout,
        ),
      );

  /// Set the Windows server IP address and port
  void setServerAddress(String ip, int port) {
    _serverIP = ip;
    _port = port;
  }

  /// Get current WiFi network information
  Future<Map<String, dynamic>?> getWiFiInfo() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        _logger.w('Location permission not granted, skipping WiFi info');
        return null;
      }
      final info = NetworkInfo();
      final String? ssid = await info.getWifiName();
      final String? bssid = await info.getWifiBSSID();
      final String? ip = await info.getWifiIP();

      return {'ssid': ssid, 'bssid': bssid, 'ipAddress': ip};
    } catch (e) {
      _logger.e('Failed to get WiFi info: $e');
      return null;
    }
  }

  /// Test connection to Windows server
  Future<bool> testConnection() async {
    try {
      // 这里直接使用明确的 IP 和端口拼接 /ping（Go 后端提供），若连接失败请检查设备与服务器是否在同一局域网
      final response = await _dio.get('http://$_serverIP:$_port/ping');
      return response.statusCode == 200;
    } catch (e) {
      // 增强日志：输出当前尝试连接的地址，便于排查（例如端口是否为8080、IP是否正确）
      _logger.e('Connection test failed: $e, address=http://$_serverIP:$_port');
      return false;
    }
  }

  /// Send inspection record to Windows
  Future<bool> sendInspectionRecord(InspectionRecord record) async {
    try {
      final Map<String, dynamic> recordData = record.toJson();
      final response = await _dio.post(
        'http://$_serverIP:$_port/api/inspection-records',
        data: recordData,
        options: Options(
          contentType: 'application/json',
          sendTimeout: _connectionTimeout,
          receiveTimeout: _connectionTimeout,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Inspection record sent successfully: ${record.id}');
        return true;
      } else {
        _logger.w('Failed to send inspection record: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error sending inspection record: $e');
      return false;
    }
  }

  /// Send detection result to Windows
  Future<bool> sendDetectionResult(DetectionResult result) async {
    try {
      final Map<String, dynamic> resultData = result.toJson();
      final response = await _dio.post(
        'http://$_serverIP:$_port/api/detection-results',
        data: resultData,
        options: Options(
          contentType: 'application/json',
          sendTimeout: _connectionTimeout,
          receiveTimeout: _connectionTimeout,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Detection result sent successfully: ${result.id}');
        return true;
      } else {
        _logger.w('Failed to send detection result: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error sending detection result: $e');
      return false;
    }
  }

  /// 上传图片文件到服务器（用于批量同步等场景）
  /// 后端 Gin 处理器 UploadImage 期望的表单字段：
  /// - file: 图片文件
  /// - sceneId: 场景ID（可选，但建议提供以便归档到对应场景目录）
  Future<bool> uploadImage(
    String imagePath,
    String recordId, {
    String? sceneId,
  }) async {
    try {
      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        _logger.e('Image file does not exist: $imagePath');
        return false;
      }

      // Create multipart request
      final formData = FormData.fromMap({
        // 注意：后端字段名为 file，这里与后端保持一致
        'file': await MultipartFile.fromFile(
          imagePath,
          filename: 'record_$recordId.jpg',
        ),
        if (sceneId != null && sceneId.isNotEmpty) 'sceneId': sceneId,
        // 可选元数据：recordId（后端会忽略未知字段，但我们保留用于日志追踪）
        'recordId': recordId,
      });

      final response = await _dio.post(
        'http://$_serverIP:$_port/api/upload-image',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: Duration(seconds: 30), // Longer timeout for file upload
          receiveTimeout: Duration(seconds: 30),
        ),
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(2);
          _logger.d('Upload progress: $progress%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Image uploaded successfully: $recordId');
        return true;
      } else {
        _logger.w('Failed to upload image: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error uploading image: $e');
      return false;
    }
  }

  /// 直接上传相机拍摄的图片
  /// - 与后端 UploadImage 保持一致的字段命名（file, sceneId）
  /// - 通过查询参数 filename 指定自定义文件名，便于在服务器侧识别
  Future<Map<String, dynamic>?> uploadImageFromCamera(
    String imagePath, {
    String? sceneId,
  }) async {
    try {
      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        _logger.e('Image file does not exist: $imagePath');
        return null;
      }

      // 生成年月日时分秒格式，确保文件名唯一，避免缓存问题
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      // 生成文件名：年月日_时分秒_场景编号
      final fileName = sceneId != null
          ? '${dateStr}_${timeStr}_$sceneId.jpg'
          : '${dateStr}_${timeStr}_unknown.jpg';

      // 构建表单：与后端字段保持一致
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath, filename: fileName),
        if (sceneId != null && sceneId.isNotEmpty) 'sceneId': sceneId,
        // 附带自定义文件名作为额外参数（后端主要使用 query 中的 filename）
        'customFileName': fileName,
      });

      // 将文件名添加到URL中作为查询参数
      final response = await _dio.post(
        // 兼容路由：/api/upload-image 与 /api/upload 均指向同一处理器
        'http://$_serverIP:$_port/api/upload-image?filename=$fileName',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: Duration(seconds: 30),
          receiveTimeout: Duration(seconds: 30),
          headers: {
            'X-Custom-Filename': fileName, // 添加自定义文件名作为请求头
          },
        ),
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(2);
          _logger.d('Upload progress: $progress%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Camera image uploaded successfully');
        return response.data;
      } else {
        _logger.w('Failed to upload camera image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Error uploading camera image: $e');
      return null;
    }
  }

  /// Send multiple records at once
  Future<bool> sendMultipleRecords(List<InspectionRecord> records) async {
    try {
      final recordsData = records.map((record) => record.toJson()).toList();
      final response = await _dio.post(
        'http://$_serverIP:$_port/api/inspection-records/batch',
        data: recordsData,
        options: Options(
          contentType: 'application/json',
          sendTimeout: Duration(
            seconds: 30,
          ), // Longer timeout for batch operation
          receiveTimeout: Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Batch records sent successfully: ${records.length} records');
        return true;
      } else {
        _logger.w('Failed to send batch records: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error sending batch records: $e');
      return false;
    }
  }

  /// Send multiple detection results at once
  Future<bool> sendMultipleDetectionResults(
    List<DetectionResult> results,
  ) async {
    try {
      final resultsData = results.map((result) => result.toJson()).toList();
      final response = await _dio.post(
        'http://$_serverIP:$_port/api/detection-results/batch',
        data: resultsData,
        options: Options(
          contentType: 'application/json',
          sendTimeout: Duration(
            seconds: 30,
          ), // Longer timeout for batch operation
          receiveTimeout: Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i(
          'Batch detection results sent successfully: ${results.length} results',
        );
        return true;
      } else {
        _logger.w(
          'Failed to send batch detection results: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error sending batch detection results: $e');
      return false;
    }
  }

  /// Upload all records and associated images to Windows
  Future<Map<String, dynamic>> syncAllData({
    required List<InspectionRecord> records,
    required List<DetectionResult> detectionResults,
  }) async {
    final List<String> errors = [];
    final stats = {
      'totalRecords': records.length,
      'totalDetectionResults': detectionResults.length,
      'recordsSent': 0,
      'detectionResultsSent': 0,
      'imagesUploaded': 0,
      'errors': errors,
    };

    try {
      // Send detection results first
      if (detectionResults.isNotEmpty) {
        if (await sendMultipleDetectionResults(detectionResults)) {
          stats['detectionResultsSent'] = detectionResults.length;
        } else {
          errors.add('Failed to send detection results');
        }
      }

      // Send inspection records
      if (records.isNotEmpty) {
        if (await sendMultipleRecords(records)) {
          stats['recordsSent'] = records.length;
        } else {
          errors.add('Failed to send inspection records');
        }
      }

      // Upload images for records that have them
      for (final record in records) {
        if (record.imagePath.isNotEmpty) {
          if (await uploadImage(record.imagePath, record.id)) {
            stats['imagesUploaded'] = (stats['imagesUploaded'] as int) + 1;
          } else {
            errors.add('Failed to upload image for record ${record.id}');
          }
        }
      }

      _logger.i('Data sync completed. Stats: $stats');
      return stats;
    } catch (e) {
      _logger.e('Error during data sync: $e');
      errors.add('Error during sync: $e');
      return stats;
    }
  }

  /// Get the current server address
  String get serverAddress => 'http://$_serverIP:$_port';
}
