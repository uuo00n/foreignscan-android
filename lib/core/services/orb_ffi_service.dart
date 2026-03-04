import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

final class OrbPairScore {
  final int goodMatches;
  final int keypointsA;
  final int keypointsB;
  final double similarity;

  const OrbPairScore({
    required this.goodMatches,
    required this.keypointsA,
    required this.keypointsB,
    required this.similarity,
  });
}

final class OrbFfiException implements Exception {
  final int errorCode;
  final String message;

  const OrbFfiException(this.errorCode, this.message);

  @override
  String toString() => 'OrbFfiException(code: $errorCode, message: $message)';
}

final class OrbFfiService {
  static const String _androidLibraryName = 'liborb_matcher.so';

  late final ffi.DynamicLibrary _dynamicLibrary;
  late final _NativeOrbCompareDart _orbCompare;

  OrbFfiService() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持 ORB FFI，本功能仅支持 Android。');
    }

    _dynamicLibrary = ffi.DynamicLibrary.open(_androidLibraryName);
    _orbCompare = _dynamicLibrary
        .lookup<ffi.NativeFunction<_NativeOrbCompareNative>>(
          'orb_compare_images',
        )
        .asFunction<_NativeOrbCompareDart>();
  }

  OrbPairScore comparePair({
    required String capturedPath,
    required String referencePath,
    int distanceThreshold = 50,
    int maxFeatures = 2000,
  }) {
    final capturedFile = File(capturedPath);
    final referenceFile = File(referencePath);
    if (!capturedFile.existsSync()) {
      throw OrbFfiException(1001, '拍摄图不存在: $capturedPath');
    }
    if (!referenceFile.existsSync()) {
      throw OrbFfiException(1002, '参考图不存在: $referencePath');
    }

    final capturedNative = capturedPath.toNativeUtf8();
    final referenceNative = referencePath.toNativeUtf8();
    final out = calloc<_OrbScoreNative>();

    try {
      final resultCode = _orbCompare(
        capturedNative,
        referenceNative,
        distanceThreshold,
        maxFeatures,
        out,
      );

      if (resultCode != 0) {
        throw OrbFfiException(resultCode, _errorMessageForCode(resultCode));
      }

      return OrbPairScore(
        goodMatches: out.ref.goodMatches,
        keypointsA: out.ref.keypointsA,
        keypointsB: out.ref.keypointsB,
        similarity: out.ref.similarity,
      );
    } finally {
      calloc.free(capturedNative);
      calloc.free(referenceNative);
      calloc.free(out);
    }
  }

  String _errorMessageForCode(int code) {
    switch (code) {
      case 1:
        return '原生 ORB 参数非法';
      case 2:
        return '原生 ORB 无法读取拍摄图';
      case 3:
        return '原生 ORB 无法读取参考图';
      case 4:
        return '原生 ORB 灰度转换失败';
      case 5:
        return '原生 ORB OpenCV 处理异常';
      case 6:
        return '原生 ORB 未知异常';
      default:
        return '原生 ORB 未知错误码: $code';
    }
  }
}

final class _OrbScoreNative extends ffi.Struct {
  @ffi.Int32()
  external int goodMatches;

  @ffi.Int32()
  external int keypointsA;

  @ffi.Int32()
  external int keypointsB;

  @ffi.Float()
  external double similarity;
}

typedef _NativeOrbCompareNative =
    ffi.Int32 Function(
      ffi.Pointer<Utf8> capturedPath,
      ffi.Pointer<Utf8> referencePath,
      ffi.Int32 distanceThreshold,
      ffi.Int32 maxFeatures,
      ffi.Pointer<_OrbScoreNative> outScore,
    );

typedef _NativeOrbCompareDart =
    int Function(
      ffi.Pointer<Utf8> capturedPath,
      ffi.Pointer<Utf8> referencePath,
      int distanceThreshold,
      int maxFeatures,
      ffi.Pointer<_OrbScoreNative> outScore,
    );
