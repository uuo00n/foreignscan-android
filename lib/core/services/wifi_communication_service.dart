import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
// Removed: import 'package:wifi_info_flutter/wifi_info_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WiFiCommunicationService {
  static const String _defaultServerIP = '172.20.10.3'; // Default Windows IP
  static const int _defaultPort = 8080; // Default port
  static const Duration _connectionTimeout = Duration(seconds: 10);

  final Logger _logger;
  final Dio _dio;
  String _serverIP = _defaultServerIP;
  int _port = _defaultPort;

  WiFiCommunicationService(this._logger) 
      : _dio = Dio(BaseOptions(
          connectTimeout: _connectionTimeout,
          receiveTimeout: _connectionTimeout,
        ));

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
      
      return {
        'ssid': ssid,
        'bssid': bssid,
        'ipAddress': ip,
      };
    } catch (e) {
      _logger.e('Failed to get WiFi info: $e');
      return null;
    }
  }

  /// Test connection to Windows server
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('http://$_serverIP:$_port/ping');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Connection test failed: $e');
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

  /// Upload image file to server
  Future<bool> uploadImage(String imagePath, String recordId) async {
    try {
      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        _logger.e('Image file does not exist: $imagePath');
        return false;
      }

      // Create multipart request
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: 'record_$recordId.jpg',
        ),
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
  
  /// Upload image directly from camera
  Future<Map<String, dynamic>?> uploadImageFromCamera(String imagePath, {String? sceneId}) async {
    try {
      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        _logger.e('Image file does not exist: $imagePath');
        return null;
      }

      // 生成年月日格式
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      
      // 生成文件名：年月日+场景编号
      final fileName = sceneId != null 
          ? '${dateStr}_${sceneId}.jpg' 
          : '${dateStr}_unknown.jpg';

      // Create multipart request
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
        'customFileName': fileName, // 添加自定义文件名作为额外参数
      });

      // 将文件名添加到URL中作为查询参数
      final response = await _dio.post(
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
          sendTimeout: Duration(seconds: 30), // Longer timeout for batch operation
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
  Future<bool> sendMultipleDetectionResults(List<DetectionResult> results) async {
    try {
      final resultsData = results.map((result) => result.toJson()).toList();
      final response = await _dio.post(
        'http://$_serverIP:$_port/api/detection-results/batch',
        data: resultsData,
        options: Options(
          contentType: 'application/json',
          sendTimeout: Duration(seconds: 30), // Longer timeout for batch operation
          receiveTimeout: Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Batch detection results sent successfully: ${results.length} results');
        return true;
      } else {
        _logger.w('Failed to send batch detection results: ${response.statusCode}');
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