import 'package:flutter/material.dart';

class ScreenUtils {
  static ScreenUtils? _instance;
  static ScreenUtils get instance {
    _instance ??= ScreenUtils._();
    return _instance!;
  }
  
  ScreenUtils._();
  
  late MediaQueryData _mediaQueryData;
  late double width;
  late double height;
  late double statusBarHeight;
  late double bottomBarHeight;
  late double textScaleFactor;
  late Orientation orientation;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    width = _mediaQueryData.size.width;
    height = _mediaQueryData.size.height;
    statusBarHeight = _mediaQueryData.padding.top;
    bottomBarHeight = _mediaQueryData.padding.bottom;
    textScaleFactor = _mediaQueryData.textScaleFactor;
    orientation = _mediaQueryData.orientation;
  }

  /// 根据屏幕宽度适配尺寸
  double setWidth(double width) {
    return width * (this.width / 375.0); // 375为iPhone6/7/8的屏幕宽度
  }

  /// 根据屏幕高度适配尺寸
  double setHeight(double height) {
    return height * (this.height / 812.0); // 812为iPhone6/7/8的屏幕高度
  }

  /// 根据屏幕宽度适配字体大小
  double setSp(double fontSize) {
    return fontSize * (this.width / 375.0);
  }

  /// 获取屏幕比例
  double get scaleWidth => width / 375.0;
  
  /// 获取屏幕高度比例
  double get scaleHeight => height / 812.0;
  
  /// 判断是否为平板
  bool get isTablet => width >= 600;
  
  /// 判断是否为大屏手机
  bool get isLargeScreen => width >= 414; // iPhone Plus and larger

  /// 获取安全区域
  EdgeInsets get padding => _mediaQueryData.padding;
}

/// 便捷的工具类扩展
extension ScreenExtension on num {
  /// 适配宽度
  double get w => ScreenUtils.instance.setWidth(this.toDouble());
  
  /// 适配高度
  double get h => ScreenUtils.instance.setHeight(this.toDouble());
  
  /// 适配字体大小
  double get sp => ScreenUtils.instance.setSp(this.toDouble());
  
  /// 按比例缩放
  double get r => this.toDouble() * ScreenUtils.instance.scaleWidth;
}