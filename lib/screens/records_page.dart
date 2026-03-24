import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/home_providers.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/core/widgets/app_bar_actions.dart';
import 'package:foreignscan/core/widgets/error_widget.dart';
import 'package:foreignscan/core/widgets/loading_widget.dart';
import 'package:foreignscan/widgets/records_section.dart';

class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeViewModel = ref.read(homeViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        leading: const AppBarBackButton(),
        title: const AppBarTitle(title: '拍摄记录'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: homeState.isLoading
          ? const LoadingWidget(message: '正在加载拍摄记录...')
          : homeState.errorMessage != null
          ? ErrorWidgetCustom(
              message: homeState.errorMessage!,
              onRetry: homeViewModel.refreshData,
            )
          : SafeArea(
              child: RecordsSection(records: homeState.inspectionRecords),
            ),
    );
  }
}
