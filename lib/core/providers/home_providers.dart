import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/services/record_service.dart';
import 'package:foreignscan/core/services/usb_transfer_service.dart';

import 'app_providers.dart';

// Home页面状态提供者
final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    ref.read(sceneServiceProvider),
    ref.read(recordServiceProvider),
    ref.read(usbTransferServiceProvider),
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
  final UsbTransferService _usbTransferService;

  HomeViewModel(this._sceneService, this._recordService, this._usbTransferService) : super(const HomeState()) {
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
          return scene.copyWith(
            capturedImage: imagePath,
            captureTime: DateTime.now(), // Set the capture time to now
            isTransferred: false, // Mark as not transferred since new image was captured
            transferTime: null, // Clear transfer time
          );
        }
        return scene;
      }).toList();
      
      state = state.copyWith(scenes: updatedScenes);
      
      await _sceneService.updateSceneImage(sceneId, imagePath);
    } catch (e) {
      state = state.copyWith(errorMessage: '更新场景图片失败: $e');
    }
  }

  /// Transfers captured images and timestamps via USB to Windows
  Future<bool> transferViaUsb({String? specificSceneId}) async {
    try {
      // Request necessary permissions first
      final permissionsGranted = await _usbTransferService.requestUsbPermissions();
      if (!permissionsGranted) {
        state = state.copyWith(errorMessage: '未获得必要的权限进行USB传输，请在设置中授权');
        return false;
      }

      // Check if USB device is connected
      final isDeviceConnected = await _usbTransferService.isUsbDeviceConnected();
      if (!isDeviceConnected) {
        state = state.copyWith(errorMessage: '未检测到USB设备，请连接Windows设备');
        return false;
      }

      // Get available transfer paths
      final transferPaths = await _usbTransferService.getAvailableTransferPaths();
      if (transferPaths.isEmpty) {
        state = state.copyWith(errorMessage: '未找到可用的USB传输路径');
        return false;
      }

      // Select the first available path (in real implementation, user might choose)
      final targetPath = transferPaths.first;

      // Filter scenes based on whether we're transferring all scenes or a specific one
      final scenesToTransfer = specificSceneId != null
          ? state.scenes.where((scene) => scene.id == specificSceneId).toList()
          : state.scenes;

      // Prepare the transfer package to show progress
      final transferPackage = await _usbTransferService.prepareTransferPackage(scenesToTransfer);
      
      // Perform the actual transfer
      final success = await _usbTransferService.transferToWindows(
        scenes: scenesToTransfer,
        targetDirectory: targetPath,
      );

      if (success) {
        // Update scenes to mark them as transferred
        final updatedScenes = state.scenes.map((scene) {
          if (specificSceneId != null) {
            // Only update the specific scene
            if (scene.id == specificSceneId) {
              return scene.copyWith(
                isTransferred: true,
                transferTime: DateTime.now(),
              );
            }
          } else {
            // Update all scenes that have captured images
            if (scene.capturedImage != null) {
              return scene.copyWith(
                isTransferred: true,
                transferTime: DateTime.now(),
              );
            }
          }
          return scene;
        }).toList();

        // Update the state with transferred scenes
        state = state.copyWith(scenes: updatedScenes);

        // Add a record of the successful transfer
        final transferRecord = InspectionRecord(
          id: 'transfer_${DateTime.now().millisecondsSinceEpoch}',
          sceneName: specificSceneId != null ? '单场景传输' : '批量传输',
          imagePath: '',
          timestamp: DateTime.now(),
          status: '传输成功',
        );
        await addInspectionRecord(transferRecord);
        
        // Clear error message if transfer was successful
        if (state.errorMessage?.contains('传输') == true) {
          state = state.copyWith(errorMessage: null);
        }
        
        return true;
      } else {
        state = state.copyWith(errorMessage: 'USB传输失败');
        return false;
      }
    } catch (e, stackTrace) {
      state = state.copyWith(errorMessage: 'USB传输过程中发生错误: $e');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> refreshData() async {
    await _initializeData();
  }
}