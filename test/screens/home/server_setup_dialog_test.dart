import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/screens/home/widgets/server_setup_dialog.dart';

void main() {
  testWidgets('测试连接成功后返回配置结果并关闭弹窗', (tester) async {
    late BuildContext rootContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              rootContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final dialogFuture = showServerSetupDialog(
      context: rootContext,
      initialIp: '',
      initialPort: null,
      onTestConnection: (ip, port) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return ip == '192.168.1.50' && port == 8080;
      },
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '192.168.1.50');
    await tester.enterText(find.byType(TextField).at(1), '8080');

    await tester.tap(find.text('测试连接并保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final result = await dialogFuture;
    await tester.pump(const Duration(milliseconds: 350));
    expect(result, isNotNull);
    expect(result!.ip, '192.168.1.50');
    expect(result.port, 8080);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击稍后再说返回 null', (tester) async {
    late BuildContext rootContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              rootContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final dialogFuture = showServerSetupDialog(
      context: rootContext,
      initialIp: '',
      initialPort: null,
      onTestConnection: (_, __) async => true,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();

    final result = await dialogFuture;
    await tester.pump(const Duration(milliseconds: 350));
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('异步测试期间宿主卸载不应抛异常', (tester) async {
    late BuildContext rootContext;
    final completer = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              rootContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final dialogFuture = showServerSetupDialog(
      context: rootContext,
      initialIp: '',
      initialPort: null,
      onTestConnection: (_, __) => completer.future,
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '192.168.1.50');
    await tester.enterText(find.byType(TextField).at(1), '8080');
    await tester.tap(find.text('测试连接并保存'));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    completer.complete(true);
    await tester.pumpAndSettle();

    await dialogFuture.timeout(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });
}
