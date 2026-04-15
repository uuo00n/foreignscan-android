import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class FeatureMatchScore {
  final int matchedFeatureCount;
  final int keypointsA;
  final int keypointsB;
  final double similarityPercent;
  final String similarityLevel;

  const FeatureMatchScore({
    required this.matchedFeatureCount,
    required this.keypointsA,
    required this.keypointsB,
    required this.similarityPercent,
    required this.similarityLevel,
  });
}

final class FeatureMatchException implements Exception {
  final int errorCode;
  final String message;

  const FeatureMatchException(this.errorCode, this.message);

  @override
  String toString() =>
      'FeatureMatchException(code: $errorCode, message: $message)';
}

final class FeatureMatchService {
  static const String _androidLibraryName = 'liborb_matcher.so';

  late final ffi.DynamicLibrary _dynamicLibrary;
  late final _NativeFeatureCompareDart _featureCompare;

  FeatureMatchService() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持原生特征匹配，本功能仅支持 Android。');
    }

    _dynamicLibrary = ffi.DynamicLibrary.open(_androidLibraryName);
    _featureCompare = _dynamicLibrary
        .lookup<ffi.NativeFunction<_NativeFeatureCompareNative>>(
          'feature_compare_images',
        )
        .asFunction<_NativeFeatureCompareDart>();
  }

  static String similarityLevelForPercent(double similarityPercent) {
    if (similarityPercent >= 15.0) {
      return '极高';
    }
    if (similarityPercent >= 10.0) {
      return '高';
    }
    if (similarityPercent >= 0.1) {
      return '较低';
    }
    return '极低';
  }

  FeatureMatchScore comparePair({
    required String capturedPath,
    required String referencePath,
    double ratioThreshold = 0.7,
    int maxFeatures = 2000,
  }) {
    final capturedFile = File(capturedPath);
    final referenceFile = File(referencePath);
    if (!capturedFile.existsSync()) {
      throw FeatureMatchException(1001, '拍摄图不存在: $capturedPath');
    }
    if (!referenceFile.existsSync()) {
      throw FeatureMatchException(1002, '参考图不存在: $referencePath');
    }

    final capturedNative = capturedPath.toNativeUtf8();
    final referenceNative = referencePath.toNativeUtf8();
    final out = calloc<_NativeFeatureScore>();

    try {
      final resultCode = _featureCompare(
        capturedNative,
        referenceNative,
        ratioThreshold,
        maxFeatures,
        out,
      );

      if (resultCode != 0) {
        throw FeatureMatchException(
          resultCode,
          _errorMessageForCode(resultCode),
        );
      }

      return FeatureMatchScore(
        matchedFeatureCount: out.ref.matchedFeatureCount,
        keypointsA: out.ref.keypointsA,
        keypointsB: out.ref.keypointsB,
        similarityPercent: out.ref.similarityPercent,
        similarityLevel: similarityLevelForPercent(out.ref.similarityPercent),
      );
    } finally {
      calloc.free(capturedNative);
      calloc.free(referenceNative);
      calloc.free(out);
    }
  }

  Future<FeatureMatchScore> comparePairAsync({
    required String capturedPath,
    required String referencePath,
    double ratioThreshold = 0.7,
    int maxFeatures = 2000,
  }) async {
    if (!File(capturedPath).existsSync()) {
      throw FeatureMatchException(1001, '拍摄图不存在: $capturedPath');
    }
    if (!File(referencePath).existsSync()) {
      throw FeatureMatchException(1002, '参考图不存在: $referencePath');
    }

    return compute(
      _comparePairInIsolate,
      _FeatureCompareRequest(
        capturedPath: capturedPath,
        referencePath: referencePath,
        ratioThreshold: ratioThreshold,
        maxFeatures: maxFeatures,
      ),
    );
  }

  String _errorMessageForCode(int code) {
    switch (code) {
      case 1:
        return '原生特征匹配参数非法';
      case 2:
        return '原生特征匹配无法读取拍摄图';
      case 3:
        return '原生特征匹配无法读取参考图';
      case 4:
        return '原生特征匹配预处理失败';
      case 5:
        return '原生特征匹配 OpenCV 处理异常';
      case 6:
        return '原生特征匹配未知异常';
      default:
        return '原生特征匹配未知错误码: $code';
    }
  }
}

final class _NativeFeatureScore extends ffi.Struct {
  @ffi.Int32()
  external int matchedFeatureCount;

  @ffi.Int32()
  external int keypointsA;

  @ffi.Int32()
  external int keypointsB;

  @ffi.Float()
  external double similarityPercent;
}

typedef _NativeFeatureCompareNative =
    ffi.Int32 Function(
      ffi.Pointer<Utf8> capturedPath,
      ffi.Pointer<Utf8> referencePath,
      ffi.Double ratioThreshold,
      ffi.Int32 maxFeatures,
      ffi.Pointer<_NativeFeatureScore> outScore,
    );

typedef _NativeFeatureCompareDart =
    int Function(
      ffi.Pointer<Utf8> capturedPath,
      ffi.Pointer<Utf8> referencePath,
      double ratioThreshold,
      int maxFeatures,
      ffi.Pointer<_NativeFeatureScore> outScore,
    );

class _FeatureCompareRequest {
  final String capturedPath;
  final String referencePath;
  final double ratioThreshold;
  final int maxFeatures;

  const _FeatureCompareRequest({
    required this.capturedPath,
    required this.referencePath,
    required this.ratioThreshold,
    required this.maxFeatures,
  });
}

FeatureMatchScore _comparePairInIsolate(_FeatureCompareRequest req) {
  final service = FeatureMatchService();
  return service.comparePair(
    capturedPath: req.capturedPath,
    referencePath: req.referencePath,
    ratioThreshold: req.ratioThreshold,
    maxFeatures: req.maxFeatures,
  );
}
