import 'package:flutter/material.dart';

class DialogSafety {
  const DialogSafety._();

  static void popIfMounted(
    BuildContext? dialogContext, {
    Object? result,
    bool useRootNavigator = true,
  }) {
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }

    final navigator = Navigator.of(
      dialogContext,
      rootNavigator: useRootNavigator,
    );
    if (!navigator.canPop()) {
      return;
    }

    navigator.pop(result);
  }

  static void popDialogIfMounted(
    BuildContext? dialogContext, {
    Object? result,
    bool useRootNavigator = true,
  }) {
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }

    final route = ModalRoute.of(dialogContext);
    // 仅允许关闭当前仍在栈顶的弹窗路由，避免误 pop 页面路由
    if (route is! PopupRoute<dynamic> || !route.isCurrent) {
      return;
    }

    final navigator = Navigator.of(
      dialogContext,
      rootNavigator: useRootNavigator,
    );
    if (!navigator.canPop()) {
      return;
    }

    navigator.pop(result);
  }
}
