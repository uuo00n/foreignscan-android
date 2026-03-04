import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/local_cache_service.dart';
import 'package:foreignscan/core/services/scene_service.dart';

final detectionServiceProvider = Provider<DetectionService>((ref) {
  // 中文注释：注入 Logger、Dio、SharedPreferences 与本地图片缓存服务
  return DetectionService(
    ref.read(loggerProvider),
    ref.read(dioProvider),
    ref.watch(sharedPreferencesProvider.future),
    ref.read(localCacheServiceProvider),
    ref.read(sceneServiceProvider),
  );
});

final detectionResultsProvider = FutureProvider<List<DetectionResult>>((
  ref,
) async {
  final service = ref.read(detectionServiceProvider);
  return await service.getDetectionResults();
});

final currentDetectionProvider = StateProvider<DetectionResult?>((ref) => null);

class DetectionService {
  final Logger _logger;
  final Dio _dio;
  final Future<SharedPreferences> _prefs;
  final LocalCacheService _cache;
  final SceneService _sceneService;

  DetectionService(
    this._logger,
    this._dio,
    this._prefs,
    this._cache,
    this._sceneService,
  );

  static const String _detectionsKey = 'detection_results_cache';
  static const String _detectionDetailsKey = 'detection_details_map_cache';

  Future<List<DetectionResult>> getDetectionResults() async {
    try {
      _logger.d('获取检测结果列表');

      // 中文注释：调用后端真实接口 /api/detections（baseUrl 已包含 /api）
      final response = await _dio.get('/detections');

      // 中文注释：兼容后端不同返回结构（数组或包裹在 data/detections 字段中）
      final data = response.data;
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['detections'] is List) {
        list = data['detections'] as List<dynamic>;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else {
        // 中文注释：不符合预期时返回空列表，避免崩溃
        _logger.w('检测结果返回结构未知，按空列表处理');
        return const [];
      }

      return list.map((raw) {
        final Map<String, dynamic> json = raw as Map<String, dynamic>;
        // 中文注释：后端 detections 结构与前端模型不一致，这里进行适配映射
        final id = (json['id']?.toString() ?? '');
        final createdAt = json['createdAt']?.toString();
        final timestamp = createdAt != null
            ? DateTime.tryParse(createdAt) ?? DateTime.now()
            : DateTime.now();
        final items = (json['items'] as List?) ?? const [];

        // 图片URL优先使用 processedPath（服务端已绘制框），否则使用 sourcePath
        String rel =
            (json['processedPath']?.toString() ??
                    json['sourcePath']?.toString() ??
                    '')
                .trim();
        rel = rel.replaceAll('\\', '/');
        final rootBase = _dio.options.baseUrl.replaceFirst(
          RegExp(r'/api/?$'),
          '',
        );
        final imageUrl = rel.isNotEmpty ? _joinUrl(rootBase, rel) : '';

        // 将 items 映射为 issues（坐标信息缺少原图尺寸，这里不绘制框，将尺寸设为0，仅用于数量与列表展示）
        final List<DetectionIssue> issues = items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final cls = item['class']?.toString() ?? 'unknown';
          final conf = (item['confidence'] is num)
              ? (item['confidence'] as num).toDouble()
              : null;
          return DetectionIssue(
            id: 'item_${id}_$idx',
            type: IssueType.unknown,
            description: '检测到对象: $cls',
            x: 0,
            y: 0,
            width: 0,
            height: 0,
            severity: _severityFromConfidence(conf),
            confidence: conf,
            metadata: item,
          );
        }).toList();

        return DetectionResult(
          id: id,
          sceneName: '',
          imagePath: imageUrl,
          timestamp: timestamp,
          issues: issues,
          status: DetectionStatus.completed,
          detectionType: json['modelName']?.toString(),
          confidence:
              (json['summary'] is Map && (json['summary']['avgScore'] is num))
              ? (json['summary']['avgScore'] as num).toDouble()
              : null,
          metadata: {
            'objectCount': items.length,
            'processedPath': json['processedPath'],
            'sourcePath': json['sourcePath'],
            'sceneId': json['sceneId'],
          },
        );
      }).toList();
    } catch (e, stackTrace) {
      _logger.e('获取检测结果失败', error: e, stackTrace: stackTrace);
      // 中文注释：失败时抛出异常，调用方按错误态处理
      throw Exception('获取检测结果失败: $e');
    }
  }

  /// 混合本地/网络的检测结果获取：
  /// - 优先尝试网络；失败则回退到本地缓存
  /// - 成功从网络获取后，下载并缓存图片到本地，更新本地缓存JSON
  Future<List<DetectionResult>> getDetectionResultsHybrid({
    bool forceNetwork = false,
  }) async {
    try {
      // 中文注释：尝试网络获取（forceNetwork仅用于调用方语义表达，失败仍自动回退本地）
      final networkList = await getDetectionResults();

      // 中文注释：为每条检测结果补充场景名称（通过 sceneId 映射）
      List<DetectionResult> withScene = networkList;
      try {
        final scenes = await _sceneService.getScenes();
        final Map<String, String> sceneNameById = {
          for (final s in scenes) s.id: s.name,
        };
        withScene = networkList.map((r) {
          final rawSceneId = r.metadata?['sceneId'];
          // 兼容后端不同 sceneId 结构（字符串或 {Hex: "..."}）
          final sceneId = (rawSceneId is Map && rawSceneId['Hex'] != null)
              ? rawSceneId['Hex'].toString()
              : rawSceneId?.toString() ?? '';
          final name = sceneNameById[sceneId] ?? '未知场景';
          return r.copyWith(sceneName: name);
        }).toList();
      } catch (_) {
        // 场景映射失败时保持原列表
      }

      // 图片离线缓存：将 http/https 图片下载到本地并替换路径
      List<DetectionResult> cachedList = withScene;
      try {
        cachedList = await _cache.cacheRecordImages<DetectionResult>(
          records: withScene,
          getImagePath: (r) => r.imagePath,
          getIdOrKey: (r) => r.id.isNotEmpty
              ? r.id
              : r.timestamp.millisecondsSinceEpoch.toString(),
          copyWithImagePath: (r, newPath) => r.copyWith(imagePath: newPath),
        );
      } catch (_) {
        // 图片缓存失败不影响主流程
      }

      // 更新本地缓存（JSON）
      await saveDetectionResults(cachedList);
      return cachedList;
    } catch (e) {
      // 网络失败：读取本地缓存兜底
      final local = await readDetectionResults();
      if (local.isNotEmpty) return local;
      // 若本地也没有，则抛出原始错误
      throw Exception('获取检测结果失败(网络+本地均不可用): $e');
    }
  }

  Future<void> saveDetectionResults(List<DetectionResult> list) async {
    final prefs = await _prefs;
    final json = DetectionResult.toJsonList(list);
    await prefs.setString(_detectionsKey, json);
  }

  Future<List<DetectionResult>> readDetectionResults() async {
    final prefs = await _prefs;
    final json = prefs.getString(_detectionsKey);
    if (json == null || json.isEmpty) return const <DetectionResult>[];
    return DetectionResult.fromJsonList(json);
  }

  Future<DetectionResult> getDetectionResult(String resultId) async {
    try {
      _logger.d('获取检测结果详情: $resultId');

      // 中文注释：若后端提供按 ID 查询的接口，则调用；否则由上层改为按 imageId 查询
      final response = await _dio.get('/detections/$resultId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return DetectionResult.fromJson(data);
      }
      throw Exception('返回结构异常');
    } catch (e, stackTrace) {
      _logger.e('获取检测结果详情失败', error: e, stackTrace: stackTrace);
      throw Exception('获取检测结果详情失败: $e');
    }
  }

  // 中文注释：按图片ID获取该图片的检测详情列表
  Future<List<DetectionIssue>> getDetectionsByImage(String imageId) async {
    try {
      _logger.d('按图片查询检测详情: imageId=$imageId');

      final response = await _dio.get('/images/$imageId/detections');
      final data = response.data;

      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['detections'] is List) {
        list = data['detections'] as List<dynamic>;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else {
        _logger.w('图片检测详情返回结构未知，按空列表处理');
        return const [];
      }

      final List<DetectionIssue> issues = [];
      for (final raw in list) {
        final Map<String, dynamic> json = raw as Map<String, dynamic>;
        if (json['items'] is List) {
          final List items = json['items'] as List;
          for (final it in items) {
            final Map<String, dynamic> item = it as Map<String, dynamic>;
            final bbox = item['bbox'] as Map<String, dynamic>?;
            final conf = (item['confidence'] is num)
                ? (item['confidence'] as num).toDouble()
                : null;
            issues.add(
              DetectionIssue(
                id: item['id']?.toString() ?? '',
                type: IssueType.unknown,
                description: '检测到对象: ${item['class'] ?? 'unknown'}',
                x: (bbox?['x'] is num) ? (bbox!['x'] as num).toDouble() : 0,
                y: (bbox?['y'] is num) ? (bbox!['y'] as num).toDouble() : 0,
                width: (bbox?['width'] is num)
                    ? (bbox!['width'] as num).toDouble()
                    : 0,
                height: (bbox?['height'] is num)
                    ? (bbox!['height'] as num).toDouble()
                    : 0,
                severity: _severityFromConfidence(conf),
                confidence: conf,
                metadata: item,
              ),
            );
          }
        } else {
          final bbox = json['bbox'] as Map<String, dynamic>?;
          final conf = (json['confidence'] is num)
              ? (json['confidence'] as num).toDouble()
              : null;
          issues.add(
            DetectionIssue(
              id: json['id']?.toString() ?? '',
              type: IssueType.unknown,
              description: '检测到对象: ${json['class'] ?? 'unknown'}',
              x: (bbox?['x'] is num) ? (bbox!['x'] as num).toDouble() : 0,
              y: (bbox?['y'] is num) ? (bbox!['y'] as num).toDouble() : 0,
              width: (bbox?['width'] is num)
                  ? (bbox!['width'] as num).toDouble()
                  : 0,
              height: (bbox?['height'] is num)
                  ? (bbox!['height'] as num).toDouble()
                  : 0,
              severity: _severityFromConfidence(conf),
              confidence: conf,
              metadata: json,
            ),
          );
        }
      }
      return issues;
    } catch (e, stackTrace) {
      _logger.e('按图片查询检测详情失败', error: e, stackTrace: stackTrace);
      throw Exception('按图片查询检测详情失败: $e');
    }
  }

  /// 中文注释：按图片ID获取最新的一条检测结果摘要（包含模型、图片、summary等）
  Future<DetectionResult?> getLatestDetectionByImage(String imageId) async {
    try {
      final response = await _dio.get('/images/$imageId/detections');
      final data = response.data;
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['detections'] is List) {
        list = data['detections'] as List<dynamic>;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else {
        // 网络请求返回格式不符合预期，尝试读取本地缓存
        return await _getCachedDetectionDetail(imageId);
      }

      if (list.isEmpty) {
        // 列表为空，也尝试读取本地缓存（可能之前有数据）
        return await _getCachedDetectionDetail(imageId);
      }

      // 选择最新一条（按 createdAt 排序，缺失时取第一条）
      list.sort((a, b) {
        final ma = a as Map<String, dynamic>;
        final mb = b as Map<String, dynamic>;
        final ta =
            DateTime.tryParse(ma['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb =
            DateTime.tryParse(mb['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      final json = list.first as Map<String, dynamic>;

      final id = (json['id']?.toString() ?? imageId);
      final createdAt = json['createdAt']?.toString();
      final timestamp = createdAt != null
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now();
      final items = (json['items'] as List?) ?? const [];
      String rel =
          (json['processedPath']?.toString() ??
                  json['sourcePath']?.toString() ??
                  '')
              .trim()
              .replaceAll('\\', '/');
      final rootBase = _dio.options.baseUrl.replaceFirst(
        RegExp(r'/api/?$'),
        '',
      );
      final imageUrl = rel.isNotEmpty ? _joinUrl(rootBase, rel) : '';

      final List<DetectionIssue> issues = items.asMap().entries.map((entry) {
        final item = entry.value as Map<String, dynamic>;
        final bbox = item['bbox'] as Map<String, dynamic>?;
        final conf = (item['confidence'] is num)
            ? (item['confidence'] as num).toDouble()
            : null;
        return DetectionIssue(
          id: 'item_${id}_${entry.key}',
          type: IssueType.unknown,
          description: '检测到对象: ${item['class'] ?? 'unknown'}',
          x: (bbox?['x'] is num) ? (bbox!['x'] as num).toDouble() : 0,
          y: (bbox?['y'] is num) ? (bbox!['y'] as num).toDouble() : 0,
          width: (bbox?['width'] is num)
              ? (bbox!['width'] as num).toDouble()
              : 0,
          height: (bbox?['height'] is num)
              ? (bbox!['height'] as num).toDouble()
              : 0,
          severity: _severityFromConfidence(conf),
          confidence: conf,
          metadata: item,
        );
      }).toList();

      final result = DetectionResult(
        id: id,
        sceneName: '',
        imagePath: imageUrl,
        timestamp: timestamp,
        issues: issues,
        status: DetectionStatus.completed,
        detectionType: json['modelName']?.toString(),
        confidence:
            (json['summary'] is Map && (json['summary']['avgScore'] is num))
            ? (json['summary']['avgScore'] as num).toDouble()
            : null,
        metadata: {
          'objectCount': items.length,
          'processedPath': json['processedPath'],
          'sourcePath': json['sourcePath'],
          'sceneId': json['sceneId'],
          'iouThreshold': json['iouThreshold'],
          'confidenceThreshold': json['confidenceThreshold'],
          'inferenceTimeMs': json['inferenceTimeMs'],
        },
      );

      // 缓存最新的检测详情
      await _cacheDetectionDetail(imageId, result);

      // 中文注释：尝试缓存检测结果图片（若为网络图片）
      if (imageUrl.isNotEmpty &&
          (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
        try {
          final localPath = await _cache.ensureCachedImage(
            url: imageUrl,
            subdir: 'detections',
            filename: 'detection_${id}_image.jpg',
          );
          if (localPath != null) {
            // 更新 result 中的图片路径为本地路径并再次保存到详情缓存
            final updatedResult = result.copyWith(imagePath: localPath);
            await _cacheDetectionDetail(imageId, updatedResult);
            return updatedResult;
          }
        } catch (_) {
          // 图片缓存失败不影响主流程
        }
      }

      return result;
    } catch (e) {
      // 网络请求失败，尝试读取本地缓存
      _logger.w('获取检测详情网络请求失败，尝试读取本地缓存: $e');
      return await _getCachedDetectionDetail(imageId);
    }
  }

  // 缓存检测详情
  Future<void> _cacheDetectionDetail(
    String imageId,
    DetectionResult result,
  ) async {
    try {
      final prefs = await _prefs;
      final String? jsonStr = prefs.getString(_detectionDetailsKey);
      Map<String, dynamic> cacheMap = {};
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          cacheMap = jsonDecode(jsonStr);
        } catch (_) {}
      }

      cacheMap[imageId] = result.toJson();
      await prefs.setString(_detectionDetailsKey, jsonEncode(cacheMap));
    } catch (e) {
      _logger.w('缓存检测详情失败: $e');
    }
  }

  // 读取本地缓存的检测详情
  Future<DetectionResult?> _getCachedDetectionDetail(String imageId) async {
    try {
      final prefs = await _prefs;
      final String? jsonStr = prefs.getString(_detectionDetailsKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final Map<String, dynamic> cacheMap = jsonDecode(jsonStr);
      final data = cacheMap[imageId];
      if (data != null) {
        return DetectionResult.fromJson(data);
      }
    } catch (e) {
      _logger.w('读取检测详情缓存失败: $e');
    }
    return null;
  }

  // 中文注释：根据置信度映射严重程度
  IssueSeverity _severityFromConfidence(double? conf) {
    if (conf == null) return IssueSeverity.medium;
    if (conf >= 0.8) return IssueSeverity.high;
    if (conf >= 0.5) return IssueSeverity.medium;
    return IssueSeverity.low;
  }

  // 中文注释：将根地址与相对路径拼接为完整URL
  String _joinUrl(String base, String relative) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final r = relative.startsWith('/') ? relative : '/$relative';
    return '$b$r';
  }

  Future<DetectionResult> performDetection({
    required String imagePath,
    required String detectionType,
    String? sceneName,
  }) async {
    try {
      _logger.d('执行检测: $detectionType, 图片: $imagePath');

      // 中文注释：如需实时检测接口，可按后端定义改造；此方法暂保留（真实项目中一般由服务端异步生成检测结果）
      return _generateMockDetectionResult(
        imagePath: imagePath,
        detectionType: detectionType,
        sceneName: sceneName ?? '未知场景',
      );
    } catch (e, stackTrace) {
      _logger.e('检测失败', error: e, stackTrace: stackTrace);
      throw Exception('检测失败: $e');
    }
  }

  Future<void> updateDetectionResult(DetectionResult result) async {
    try {
      _logger.d('更新检测结果: ${result.id}');

      // 中文注释：如后端提供更新接口，按需启用；这里暂不调用以避免误写
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e, stackTrace) {
      _logger.e('更新检测结果失败', error: e, stackTrace: stackTrace);
      throw Exception('更新检测结果失败: $e');
    }
  }

  Future<void> deleteDetectionResult(String resultId) async {
    try {
      _logger.d('删除检测结果: $resultId');

      // 中文注释：如后端提供删除接口，按需启用；这里暂不调用以避免误删
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e, stackTrace) {
      _logger.e('删除检测结果失败', error: e, stackTrace: stackTrace);
      throw Exception('删除检测结果失败: $e');
    }
  }

  DetectionResult _generateMockDetectionResult({
    required String imagePath,
    required String detectionType,
    required String sceneName,
  }) {
    final now = DateTime.now();
    final issues = [
      DetectionIssue(
        id: 'issue_1_${now.millisecondsSinceEpoch}',
        type: IssueType.foreignObject,
        description: '检测到金属异物',
        x: 0.6,
        y: 0.4,
        width: 0.08,
        height: 0.08,
        severity: IssueSeverity.high,
        confidence: 0.85,
      ),
      DetectionIssue(
        id: 'issue_2_${now.millisecondsSinceEpoch}',
        type: IssueType.damage,
        description: '检测到表面损伤',
        x: 0.3,
        y: 0.7,
        width: 0.06,
        height: 0.06,
        severity: IssueSeverity.medium,
        confidence: 0.72,
      ),
    ];

    return DetectionResult(
      id: 'result_${now.millisecondsSinceEpoch}',
      sceneName: sceneName,
      imagePath: imagePath,
      timestamp: now,
      issues: issues,
      status: DetectionStatus.completed,
      detectionType: detectionType,
      confidence: 0.85,
      metadata: {
        'detectionModel': 'YOLOv8',
        'processingTime': 1200, // ms
        'imageSize': {'width': 1920, 'height': 1080},
      },
    );
  }
}

// 检测状态提供者
final detectionProcessingProvider = StateProvider<bool>((ref) => false);

// 检测错误提供者
final detectionErrorProvider = StateProvider<String?>((ref) => null);
