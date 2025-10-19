/// USB传输错误类型枚举
/// 消除字符串匹配，使用明确的错误类型
enum TransferErrorType {
  /// 没有数据需要传输
  noData,

  /// 权限被拒绝
  permissionDenied,

  /// USB设备未连接
  deviceNotConnected,

  /// 传输路径不可用
  pathNotAvailable,

  /// 文件复制失败
  fileCopyFailed,

  /// 传输验证失败
  verificationFailed,

  /// 通用传输错误
  transferFailed,

  /// 未知错误
  unknown;

  /// 获取用户友好的错误消息
  String get message {
    switch (this) {
      case TransferErrorType.noData:
        return '没有捕获的图片需要传输';
      case TransferErrorType.permissionDenied:
        return '未获得必要的权限进行USB传输，请在设置中授权';
      case TransferErrorType.deviceNotConnected:
        return '未检测到USB设备，请连接Windows设备';
      case TransferErrorType.pathNotAvailable:
        return '未找到可用的USB传输路径';
      case TransferErrorType.fileCopyFailed:
        return '文件复制失败，请检查存储空间';
      case TransferErrorType.verificationFailed:
        return '传输验证失败，部分文件可能未正确复制';
      case TransferErrorType.transferFailed:
        return 'USB传输失败';
      case TransferErrorType.unknown:
        return 'USB传输过程中发生未知错误';
    }
  }

  /// 从异常创建错误类型
  factory TransferErrorType.fromException(dynamic e) {
    final errorString = e.toString().toLowerCase();

    if (errorString.contains('permission')) {
      return TransferErrorType.permissionDenied;
    } else if (errorString.contains('device') || errorString.contains('connect')) {
      return TransferErrorType.deviceNotConnected;
    } else if (errorString.contains('path') || errorString.contains('directory')) {
      return TransferErrorType.pathNotAvailable;
    } else if (errorString.contains('copy') || errorString.contains('file')) {
      return TransferErrorType.fileCopyFailed;
    } else if (errorString.contains('verification')) {
      return TransferErrorType.verificationFailed;
    } else {
      return TransferErrorType.unknown;
    }
  }
}