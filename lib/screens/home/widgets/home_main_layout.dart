import 'package:flutter/material.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/widgets/records_section.dart';
import 'package:foreignscan/widgets/scene_display.dart';
import 'package:foreignscan/widgets/scene_selector.dart';

class HomeMainLayout extends StatelessWidget {
  final HomeState homeState;
  final HomeViewModel homeViewModel;
  final SceneData selectedScene;
  final String? referenceImageUrl;
  final bool isReferenceLoading;
  final VoidCallback onCaptureClick;
  final VoidCallback onConfirmTransfer;
  final VoidCallback onTransferAll;

  const HomeMainLayout({
    super.key,
    required this.homeState,
    required this.homeViewModel,
    required this.selectedScene,
    required this.referenceImageUrl,
    required this.isReferenceLoading,
    required this.onCaptureClick,
    required this.onConfirmTransfer,
    required this.onTransferAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return _buildWideLayout();
        }

        if (constraints.maxWidth >= 768) {
          return _buildMediumLayout();
        }

        return _buildNarrowLayout();
      },
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SceneSelector(
                  scenes: homeState.scenes,
                  selectedIndex: homeState.selectedSceneIndex,
                  onSceneSelected: homeViewModel.selectScene,
                  panelWidth: 280,
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildSceneDisplay()),
              ],
            ),
          ),
        ),
        RecordsSection(
          records: homeState.inspectionRecords,
          currentPage: homeState.currentRecordPage,
          recordsPerPage: homeState.recordsPerPage,
          totalPages: homeState.totalPages,
          onPreviousPage: homeViewModel.previousRecordPage,
          onNextPage: homeViewModel.nextRecordPage,
        ),
      ],
    );
  }

  Widget _buildMediumLayout() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SceneSelector(
                  scenes: homeState.scenes,
                  selectedIndex: homeState.selectedSceneIndex,
                  onSceneSelected: homeViewModel.selectScene,
                  panelWidth: 240,
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildSceneDisplay()),
              ],
            ),
          ),
        ),
        RecordsSection(
          records: homeState.inspectionRecords,
          currentPage: homeState.currentRecordPage,
          recordsPerPage: homeState.recordsPerPage,
          totalPages: homeState.totalPages,
          onPreviousPage: homeViewModel.previousRecordPage,
          onNextPage: homeViewModel.nextRecordPage,
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 260,
              child: SceneSelector(
                scenes: homeState.scenes,
                selectedIndex: homeState.selectedSceneIndex,
                onSceneSelected: homeViewModel.selectScene,
                panelWidth: null,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 520, child: _buildSceneDisplay()),
            const SizedBox(height: 12),
            RecordsSection(
              records: homeState.inspectionRecords,
              currentPage: homeState.currentRecordPage,
              recordsPerPage: homeState.recordsPerPage,
              totalPages: homeState.totalPages,
              onPreviousPage: homeViewModel.previousRecordPage,
              onNextPage: homeViewModel.nextRecordPage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneDisplay() {
    return SceneDisplay(
      scene: selectedScene,
      onCaptureClick: onCaptureClick,
      onConfirmTransfer: onConfirmTransfer,
      onTransferAll: onTransferAll,
      referenceImageUrl: referenceImageUrl,
      isReferenceLoading: isReferenceLoading,
    );
  }
}
