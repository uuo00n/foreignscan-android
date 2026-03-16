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
}
