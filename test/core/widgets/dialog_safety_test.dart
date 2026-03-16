import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/core/widgets/dialog_safety.dart';

void main() {
  test('popIfMounted 传入 null 时无异常', () {
    expect(() => DialogSafety.popIfMounted(null), returnsNormally);
  });

  testWidgets('popIfMounted 关闭弹窗且不影响宿主页面', (tester) async {
    late BuildContext hostContext;
    BuildContext? dialogContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const Text('host-page');
            },
          ),
        ),
      ),
    );

    final dialogFuture = showDialog<void>(
      context: hostContext,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const AlertDialog(title: Text('test-dialog'));
      },
    );

    await tester.pumpAndSettle();
    expect(find.text('test-dialog'), findsOneWidget);

    DialogSafety.popIfMounted(dialogContext);
    await tester.pumpAndSettle();
    await dialogFuture;

    expect(find.text('test-dialog'), findsNothing);
    expect(find.text('host-page'), findsOneWidget);

    DialogSafety.popIfMounted(hostContext);
    await tester.pumpAndSettle();
    expect(find.text('host-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
