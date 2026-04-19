import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/core/services/local_cache_service.dart';
import 'package:foreignscan/core/services/style_image_service.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocalCacheService extends LocalCacheService {
  final Future<String?> Function({
    required String url,
    required String subdir,
    required String filename,
  })
  onEnsureCachedImage;

  _FakeLocalCacheService({required this.onEnsureCachedImage}) : super(Dio());

  @override
  Future<String?> ensureCachedImage({
    required String url,
    required String subdir,
    required String filename,
  }) {
    return onEnsureCachedImage(url: url, subdir: subdir, filename: filename);
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> responsesBySuffix;
  final Set<String> failingSuffixes;

  _FakeHttpClientAdapter({
    required this.responsesBySuffix,
    this.failingSuffixes = const <String>{},
  });

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    for (final suffix in failingSuffixes) {
      if (path.endsWith(suffix)) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'fake network error for $suffix',
        );
      }
    }

    for (final entry in responsesBySuffix.entries) {
      if (path.endsWith(entry.key)) {
        return ResponseBody.fromString(
          jsonEncode(entry.value),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }
    }

    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      message: 'no fake response for $path',
    );
  }
}

void main() {
  group('StyleImageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('getStyleImagesByScene 在线成功后可离线读取缓存', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080/api'));
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        responsesBySuffix: <String, Map<String, dynamic>>{
          '/style-images/point/point-1': <String, dynamic>{
            'success': true,
            'styleImage': <String, dynamic>{
              'id': 'style-1',
              'pointId': 'point-1',
              'filename': 'a.jpg',
              'accessPath': '/uploads/styles/point-1/a.jpg',
            },
          },
        },
      );

      final prefs = SharedPreferences.getInstance();
      final service = StyleImageService(
        prefs,
        dio,
        _FakeLocalCacheService(
          onEnsureCachedImage:
              ({
                required String url,
                required String subdir,
                required String filename,
              }) async => '/tmp/$filename',
        ),
      );

      final online = await service.getStyleImagesByScene('point-1');
      expect(online, hasLength(1));
      expect(online.first.id, 'style-1');

      dio.httpClientAdapter = _FakeHttpClientAdapter(
        responsesBySuffix: const <String, Map<String, dynamic>>{},
        failingSuffixes: const <String>{'/style-images/point/point-1'},
      );

      final offline = await service.getStyleImagesByScene('point-1');
      expect(offline, hasLength(1));
      expect(offline.first.id, 'style-1');
    });

    test('warmupStyleImagesForScenes 返回正确统计（含失败点位）', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080/api'));
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        responsesBySuffix: <String, Map<String, dynamic>>{
          '/style-images/point/point-1': <String, dynamic>{
            'success': true,
            'styleImage': <String, dynamic>{
              'id': 'style-1',
              'pointId': 'point-1',
              'filename': 'a.jpg',
              'accessPath': '/uploads/styles/point-1/a.jpg',
            },
          },
          '/style-images/point/point-2': <String, dynamic>{
            'success': true,
            'styleImage': <String, dynamic>{
              'id': 'style-2',
              'pointId': 'point-2',
              'filename': 'b.jpg',
              'accessPath': '/uploads/styles/point-2/b.jpg',
            },
          },
        },
      );

      final prefs = SharedPreferences.getInstance();
      final service = StyleImageService(
        prefs,
        dio,
        _FakeLocalCacheService(
          onEnsureCachedImage:
              ({
                required String url,
                required String subdir,
                required String filename,
              }) async {
                if (subdir.endsWith('point-2')) {
                  return null;
                }
                return '/tmp/$filename';
              },
        ),
      );

      final result = await service.warmupStyleImagesForScenes(<SceneData>[
        SceneData(id: 'point-1', name: '点位1'),
        SceneData(id: 'point-2', name: '点位2'),
      ]);

      expect(result.totalScenes, 2);
      expect(result.cachedScenes, 1);
      expect(result.failedScenes, 1);
      expect(result.failedSceneIds, <String>['point-2']);
    });
  });
}
