import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/services/record_service.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
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

  HomeViewModel(this._sceneService, this._recordService) : super(const HomeState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      final scenes = await _sceneService.getScenes();
      final records = await _recordService.getRecords();
      
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

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> refreshData() async {
    await _initializeData();
  }
}