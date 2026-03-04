import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:foreignscan/core/providers/camera_providers.dart';
import 'package:foreignscan/core/widgets/loading_widget.dart';
import '../core/widgets/error_widget.dart';
import 'package:foreignscan/core/theme/app_theme.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // 添加闪光灯状态
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusIndicatorOffset;
  bool _focusLocked = false;
  bool _zoomInitialized = false;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _startZoomOnScale = 1.0;
  bool _showZoomSlider = true;
  Timer? _zoomApplyTicker;
  double _lastAppliedZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      // 检查相机权限
      final hasPermission = await ref
          .read(cameraServiceProvider)
          .requestCameraPermission();

      if (!mounted) return; // 检查widget是否已被销毁

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要相机权限才能拍照'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 初始化相机
      if (mounted) {
        ref.read(cameraControllerProvider.notifier).refreshCamera();
      }
    } catch (e) {
      debugPrint('初始化相机错误: $e');
    }
  }

  @override
  void dispose() {
    ref.read(cameraControllerProvider.notifier).disposeCamera();
    _zoomApplyTicker?.cancel();
    super.dispose();
  }

  void _startZoomTicker(CameraController controller) {
    _zoomApplyTicker?.cancel();
    _zoomApplyTicker = Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) async {
      final z = _currentZoom.clamp(_minZoom, _maxZoom);
      if ((z - _lastAppliedZoom).abs() < 0.01) return;
      _lastAppliedZoom = z;
      try {
        await controller.setZoomLevel(z);
      } catch (_) {}
    });
  }

  void _stopZoomTicker() {
    _zoomApplyTicker?.cancel();
    _zoomApplyTicker = null;
  }

  Future<void> _takePicture() async {
    try {
      // 获取当前相机控制器
      final controller = ref.read(cameraControllerProvider).value;

      if (controller != null) {
        // 中文注释：
        // 不再在“自动模式”下强行切换到常亮（torch），而是遵循控制器的自动策略：
        // - 如果当前为 FlashMode.auto，保持自动模式，由系统根据环境光决定是否触发闪光
        // - 如果当前为 FlashMode.off 或 FlashMode.torch，按用户选择执行，无需临时切换

        // 拍照
        final imagePath = await ref
            .read(cameraControllerProvider.notifier)
            .takePicture();

        // 中文注释：
        // 需求变更：拍摄完成后自动关闭闪光灯，避免“常亮（torch）”持续点亮影响使用。
        // 行为说明：无论当前是 auto/torch/off，拍完后都统一设置为 off，UI 同步更新。
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (e) {
          debugPrint('拍摄后关闭闪光灯失败: $e');
        }
        if (mounted) {
          setState(() {
            _flashMode = FlashMode.off;
          });
        }

        if (mounted && imagePath != null) {
          // 直接返回拍摄的照片路径
          Navigator.pop(context, imagePath);
        }
      } else {
        // 相机控制器为空，直接拍照
        final imagePath = await ref
            .read(cameraControllerProvider.notifier)
            .takePicture();

        // 中文注释：
        // 即便读取时控制器为 null，拍照底层仍可能成功，此处尝试关闭闪光灯（若控制器可用）。
        final afterController = ref.read(cameraControllerProvider).value;
        if (afterController != null) {
          try {
            await afterController.setFlashMode(FlashMode.off);
          } catch (e) {
            debugPrint('拍摄后关闭闪光灯失败(控制器空分支): $e');
          }
        }
        if (mounted) {
          setState(() {
            _flashMode = FlashMode.off;
          });
        }

        if (mounted && imagePath != null) {
          Navigator.pop(context, imagePath);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    final cameras = await ref.read(availableCamerasProvider.future);
    if (cameras.length <= 1) return;

    // 显示切换中提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在切换相机...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    }

    final currentIndex = ref.read(selectedCameraProvider);
    final nextIndex = (currentIndex + 1) % cameras.length;

    // 强制重新初始化相机
    await ref.read(cameraControllerProvider.notifier).switchCamera(nextIndex);

    // 如果相机初始化失败，尝试再次切换
    final cameraState = ref.read(cameraControllerProvider);
    if (cameraState is AsyncError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('相机切换失败，正在重试...'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // 短暂延迟后再次尝试
      await Future.delayed(const Duration(milliseconds: 500));
      await ref.read(cameraControllerProvider.notifier).refreshCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final camerasAsync = ref.watch(availableCamerasProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('拍摄照片'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // 禁用自动添加的返回按钮
        actions: [
          camerasAsync.when(
            data: (cameras) {
              if (cameras.length > 1) {
                return IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  onPressed: _switchCamera,
                  tooltip: '切换相机',
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: cameraState.when(
        loading: () =>
            const LoadingWidget(message: '正在初始化相机...', color: Colors.white),
        error: (error, stackTrace) => ErrorWidgetCustom(
          message: '相机初始化失败: $error',
          onRetry: () =>
              ref.read(cameraControllerProvider.notifier).refreshCamera(),
          icon: Icons.camera_alt,
        ),
        data: (controller) {
          if (controller == null) {
            return ErrorWidgetCustom(
              message: '无法访问相机设备',
              onRetry: () =>
                  ref.read(cameraControllerProvider.notifier).refreshCamera(),
              icon: Icons.camera_alt,
            );
          }

          if (!_zoomInitialized) {
            () async {
              try {
                final min = await controller.getMinZoomLevel();
                final max = await controller.getMaxZoomLevel();
                setState(() {
                  _minZoom = min;
                  _maxZoom = max;
                  _currentZoom = _minZoom;
                  _zoomInitialized = true;
                });
                await controller.setZoomLevel(_currentZoom);
              } catch (_) {}
            }();
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(
                      controller,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) async {
                                  final offset = Offset(
                                    details.localPosition.dx /
                                        constraints.maxWidth,
                                    details.localPosition.dy /
                                        constraints.maxHeight,
                                  );
                                  try {
                                    await controller.setFocusPoint(offset);
                                  } catch (_) {}
                                  try {
                                    await controller.setExposurePoint(offset);
                                  } catch (_) {}
                                  setState(() {
                                    _focusIndicatorOffset =
                                        details.localPosition;
                                    _focusLocked = false;
                                  });
                                },
                                onLongPressStart: (details) async {
                                  final localPos = details.localPosition;
                                  final offset = Offset(
                                    localPos.dx / constraints.maxWidth,
                                    localPos.dy / constraints.maxHeight,
                                  );
                                  try {
                                    await controller.setFocusPoint(offset);
                                  } catch (_) {}
                                  try {
                                    await controller.setExposurePoint(offset);
                                  } catch (_) {}
                                  try {
                                    await controller.setFocusMode(
                                      FocusMode.locked,
                                    );
                                  } catch (_) {}
                                  try {
                                    await controller.setExposureMode(
                                      ExposureMode.locked,
                                    );
                                  } catch (_) {}
                                  setState(() {
                                    _focusIndicatorOffset = localPos;
                                    _focusLocked = true;
                                  });
                                },
                                onScaleStart: (details) {
                                  _startZoomOnScale = _currentZoom;
                                  setState(() {
                                    _showZoomSlider = true;
                                  });
                                  _startZoomTicker(controller);
                                },
                                onScaleUpdate: (details) async {
                                  final target =
                                      (_startZoomOnScale * details.scale).clamp(
                                        _minZoom,
                                        _maxZoom,
                                      );
                                  final z = target.toDouble();
                                  if ((z - _currentZoom).abs() > 0.001) {
                                    setState(() {
                                      _currentZoom = z;
                                    });
                                  }
                                  if (!_showZoomSlider) {
                                    setState(() {
                                      _showZoomSlider = true;
                                    });
                                  }
                                },
                                onScaleEnd: (_) async {
                                  _stopZoomTicker();
                                  try {
                                    final finalZoom = _currentZoom.clamp(
                                      _minZoom,
                                      _maxZoom,
                                    );
                                    setState(() {
                                      _currentZoom = finalZoom;
                                    });
                                    await controller.setZoomLevel(finalZoom);
                                  } catch (_) {}
                                },
                              ),
                              Positioned(
                                left: 12,
                                top: 0,
                                bottom: 0,
                                child: SafeArea(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 已移除左侧倍数文本展示，改为在拍摄按钮下方统一显示
                                      Container(
                                        width: 56,
                                        height: 280,
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                                  trackHeight: 6,
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                        enabledThumbRadius: 12,
                                                      ),
                                                ),
                                            child: Slider(
                                              min: _minZoom,
                                              max: _maxZoom,
                                              value: _currentZoom.clamp(
                                                _minZoom,
                                                _maxZoom,
                                              ),
                                              onChangeStart: (_) {
                                                _startZoomTicker(controller);
                                              },
                                              onChanged: (v) {
                                                setState(() {
                                                  _currentZoom = v;
                                                  _showZoomSlider = true;
                                                });
                                              },
                                              onChangeEnd: (v) async {
                                                _stopZoomTicker();
                                                try {
                                                  await controller.setZoomLevel(
                                                    v,
                                                  );
                                                } catch (_) {}
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_focusIndicatorOffset != null)
                                Positioned(
                                  left: _focusIndicatorOffset!.dx - 20,
                                  top: _focusIndicatorOffset!.dy - 20,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 1.2, end: 1.0),
                                    duration: const Duration(milliseconds: 250),
                                    builder: (context, scale, child) {
                                      return AnimatedOpacity(
                                        opacity: 0.9,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: _focusLocked
                                                    ? AppTheme.successColor
                                                    : Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 右侧控制面板
              Positioned(
                right: 30,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 闪光灯控制
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : (_flashMode == FlashMode.auto
                                      ? Icons.flash_auto
                                      : Icons.flash_on),
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () async {
                            // 循环切换闪光灯模式
                            setState(() {
                              _flashMode = _flashMode == FlashMode.off
                                  ? FlashMode.auto
                                  : (_flashMode == FlashMode.auto
                                        ? FlashMode.torch
                                        : FlashMode.off);
                            });

                            // 应用闪光灯设置
                            await controller.setFlashMode(_flashMode);
                          },
                          tooltip: '闪光灯控制',
                        ),
                      ),

                      // 拍照按钮
                      FloatingActionButton(
                        onPressed: () async {
                          await _takePicture();
                          final c = ref.read(cameraControllerProvider).value;
                          if (c != null) {
                            final double logicalMax = _maxZoom < 4.0
                                ? _maxZoom
                                : 4.0;
                            double next = _currentZoom + 1.0;
                            if (next > logicalMax - 1e-6) {
                              next = 1.0;
                            } else if (next > logicalMax) {
                              next = logicalMax;
                            }
                            setState(() {
                              _currentZoom = next;
                            });
                            try {
                              await c.setZoomLevel(
                                next.clamp(_minZoom, _maxZoom),
                              );
                            } catch (_) {}
                          }
                        },
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        child: const Icon(Icons.camera, size: 32),
                      ),
                      const SizedBox(height: 16),
                      // 变焦倍数展示：形状、大小、间距与拍照按钮保持一致
                      GestureDetector(
                        onTap: () async {
                          final c = ref.read(cameraControllerProvider).value;
                          if (c != null) {
                            final double logicalMax = _maxZoom < 4.0
                                ? _maxZoom
                                : 4.0;
                            double next = _currentZoom + 1.0;
                            if (next > logicalMax - 1e-6) {
                              next = 1.0;
                            } else if (next > logicalMax) {
                              next = logicalMax;
                            }
                            setState(() {
                              _currentZoom = next;
                            });
                            try {
                              await c.setZoomLevel(
                                next.clamp(_minZoom, _maxZoom),
                              );
                            } catch (_) {}
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${_currentZoom.toStringAsFixed(1)}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 返回按钮
              Positioned(
                top: 40,
                left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
