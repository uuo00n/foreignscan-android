import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/services/record_service.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
import 'package:foreignscan/core/services/style_image_service.dart';
import 'package:foreignscan/core/services/local_cache_service.dart';
import 'package:foreignscan/core/providers/app_providers.dart'; // 引入全局Provider定义，包含localCacheServiceProvider
import 'package:foreignscan/models/style_image.dart';
import 'package:logger/logger.dart';

// Home页面状态提供者
final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    ref.read(sceneServiceProvider),
    ref.read(recordServiceProvider),
  );
});

// 场景数据提供者
final scenesProvider = FutureProvider<List<SceneData>>((ref) async {
  final service = ref.read(sceneServiceProvider);
  return await service.getScenes();
});

// 当前选中场景的样式图（模板参考图）列表提供者
final styleImagesForSelectedSceneProvider = FutureProvider.autoDispose<List<StyleImage>>((ref) async {
  final homeState = ref.watch(homeViewModelProvider);
  final styleService = ref.read(styleImageServiceProvider);
  final cacheService = ref.read(localCacheServiceProvider);

  if (homeState.scenes.isEmpty) {
    return <StyleImage>[];
  }

  final selectedScene = homeState.scenes[homeState.selectedSceneIndex];
  final images = await styleService.getStyleImagesByScene(selectedScene.id);

  // 预缓存：若存在首张样式图，先将其下载到本地，便于拍摄时离线查看
  if (images.isNotEmpty) {
    final first = images.first;
    final remoteUrl = styleService.buildImageUrl(first);
    // 子目录：style_images/<sceneId>；文件名：<styleId>_<filename或style.jpg>
    final filename = '${first.id}_${first.filename ?? 'style.jpg'}';
    await cacheService.ensureCachedImage(
      url: remoteUrl,
      subdir: 'style_images/${selectedScene.id}',
      filename: filename,
    );
  }

  return images;
});

// 当前选中场景的首张样式图的完整URL（用于 SceneDisplay 的模板参考图）
final referenceImageUrlProvider = FutureProvider.autoDispose<String?>((ref) async {
  // 中文说明：
  // 1) 优先读取样式图列表（在线时），若有数据则计算首张图的本地缓存路径并返回；
  // 2) 若无数据（离线/加载中/错误），则直接在本地 style_images/<sceneId>/ 目录中查找已有缓存文件作为兜底；
  final homeState = ref.watch(homeViewModelProvider);
  final styleImagesAsync = ref.watch(styleImagesForSelectedSceneProvider);
  final styleService = ref.read(styleImageServiceProvider);
  final cacheService = ref.read(localCacheServiceProvider);

  // 没有场景数据则直接返回 null
  if (homeState.scenes.isEmpty) {
    return null;
  }
  final selectedScene = homeState.scenes[homeState.selectedSceneIndex];

  // 情况一：样式图列表可用且非空（通常为在线场景）
  if (styleImagesAsync.hasValue) {
    final images = styleImagesAsync.value ?? const <StyleImage>[];
    if (images.isNotEmpty) {
      final first = images.first;
      final remoteUrl = styleService.buildImageUrl(first);
      // 计算本地路径并优先返回本地缓存
      final filename = '${first.id}_${first.filename ?? 'style.jpg'}';
      final localPath = await cacheService.buildLocalPath(
        subdir: 'style_images/${selectedScene.id}',
        filename: filename,
      );
      final file = File(localPath);
      if (file.existsSync()) {
        return localPath; // 本地已缓存，优先返回
      }
      return remoteUrl; // 兜底返回网络URL
    }
  }

  // 情况二：无样式图数据（离线/加载中/错误）—> 本地兜底：从 style_images/<sceneId>/ 中找首个文件
  final cached = await cacheService.findFirstFileInSubdir('style_images/${selectedScene.id}');
  return cached; // 可能为 null；UI 层需做无图兜底处理
});

// 检测记录提供者
final recordsProvider = FutureProvider<List<InspectionRecord>>((ref) async {
  final service = ref.read(recordServiceProvider);
  return await service.getRecords();
});

// Logger提供者
final loggerProvider = Provider<Logger>((ref) {
  return Logger();
});

// WiFi通信服务提供者
final wifiServiceProvider = Provider<WiFiCommunicationService>((ref) {
  return WiFiCommunicationService(ref.read(loggerProvider));
});

// Home页面状态
class HomeState {
  final int selectedSceneIndex;
  final int currentRecordPage;
  final int recordsPerPage;
  final bool isLoading;
  final String? errorMessage;
  final List<SceneData> scenes;
  final List<InspectionRecord> inspectionRecords;

  const HomeState({
    this.selectedSceneIndex = 0,
    this.currentRecordPage = 0,
    this.recordsPerPage = 4,
    this.isLoading = false,
    this.errorMessage,
    this.scenes = const [],
    this.inspectionRecords = const [],
  });

  HomeState copyWith({
    int? selectedSceneIndex,
    int? currentRecordPage,
    int? recordsPerPage,
    bool? isLoading,
    String? errorMessage,
    List<SceneData>? scenes,
    List<InspectionRecord>? inspectionRecords,
  }) {
    return HomeState(
      selectedSceneIndex: selectedSceneIndex ?? this.selectedSceneIndex,
      currentRecordPage: currentRecordPage ?? this.currentRecordPage,
      recordsPerPage: recordsPerPage ?? this.recordsPerPage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      scenes: scenes ?? this.scenes,
      inspectionRecords: inspectionRecords ?? this.inspectionRecords,
    );
  }

  int get totalPages {
    return inspectionRecords.isEmpty 
        ? 0 
        : (inspectionRecords.length / recordsPerPage).ceil();
  }
}

// Home页面状态管理器
class HomeViewModel extends StateNotifier<HomeState> {
  final SceneService _sceneService;
  final RecordService _recordService;

  HomeViewModel(this._sceneService, this._recordService) : super(const HomeState());

  Future<void> initializeData({bool forceOffline = false}) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      final scenes = await _sceneService.getScenes(forceOffline: forceOffline);
      final records = await _recordService.getRecords(forceOffline: forceOffline);
      
      state = state.copyWith(
        scenes: scenes,
        inspectionRecords: records,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '数据加载失败: $e',
      );
    }
  }

  void selectScene(int index) {
    if (index >= 0 && index < state.scenes.length) {
      state = state.copyWith(selectedSceneIndex: index);
    }
  }

  void nextRecordPage() {
    if (state.currentRecordPage < state.totalPages - 1) {
      state = state.copyWith(currentRecordPage: state.currentRecordPage + 1);
    }
  }

  void previousRecordPage() {
    if (state.currentRecordPage > 0) {
      state = state.copyWith(currentRecordPage: state.currentRecordPage - 1);
    }
  }

  Future<void> addInspectionRecord(InspectionRecord record) async {
    try {
      await _recordService.addRecord(record);
      
      final updatedRecords = List<InspectionRecord>.from(state.inspectionRecords);
      updatedRecords.insert(0, record);
      
      state = state.copyWith(inspectionRecords: updatedRecords);
    } catch (e) {
      state = state.copyWith(errorMessage: '添加记录失败: $e');
    }
  }

  Future<void> updateSceneImage(String sceneId, String imagePath) async {
    try {
      final updatedScenes = state.scenes.map((scene) {
        if (scene.id == sceneId) {
          return scene.copyWith(capturedImage: imagePath);
        }
        return scene;
      }).toList();
      
      state = state.copyWith(scenes: updatedScenes);
      
      await _sceneService.updateSceneImage(sceneId, imagePath);
    } catch (e) {
      state = state.copyWith(errorMessage: '更新场景图片失败: $e');
    }
  }

  /// 更新场景的传输状态（例如上传成功后标记为已传输）
  Future<void> updateSceneTransferStatus(String sceneId, bool isTransferred) async {
    try {
      // 更新内存中的场景列表
      final updatedScenes = state.scenes.map((scene) {
        if (scene.id == sceneId) {
          return scene.copyWith(
            isTransferred: isTransferred,
            transferTime: isTransferred ? DateTime.now() : null,
          );
        }
        return scene;
      }).toList();

      state = state.copyWith(scenes: updatedScenes);

      // 持久化到本地缓存
      await _sceneService.updateSceneTransferStatus(sceneId, isTransferred);
    } catch (e) {
      state = state.copyWith(errorMessage: '更新场景传输状态失败: $e');
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> refreshData({bool forceOffline = false}) async {
    await initializeData(forceOffline: forceOffline);
  }
}