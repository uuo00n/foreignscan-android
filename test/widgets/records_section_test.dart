import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/widgets/records_section.dart';

void main() {
  final records = <InspectionRecord>[
    InspectionRecord(
      id: 'record-1',
      sceneName: '机舱左侧点位',
      pointId: 'point-1',
      roomName: '机舱',
      imagePath: '',
      timestamp: DateTime(2026, 3, 24, 9, 30),
      status: '合格',
    ),
    InspectionRecord(
      id: 'record-2',
      sceneName: '尾舱右侧点位',
      pointId: 'point-2',
      roomName: '尾舱',
      imagePath: '',
      timestamp: DateTime(2026, 3, 23, 18, 0),
      status: '异常',
    ),
    InspectionRecord(
      id: 'record-3',
      sceneName: '配电箱点位',
      pointId: 'point-3',
      roomName: '机舱',
      imagePath: '',
      timestamp: DateTime(2026, 3, 22, 8, 0),
      status: '已上传',
    ),
  ];

  group('buildVisibleRecords', () {
    test('按关键字和状态筛选并按最新优先排序', () {
      final visible = buildVisibleRecords(
        records,
        query: '舱',
        statusFilter: RecordsStatusFilter.abnormal,
        sortOrder: RecordsSortOrder.latestFirst,
      );

      expect(visible.length, 1);
      expect(visible.single.id, 'record-2');
    });

    test('未检测筛选包含已上传记录并支持最早优先', () {
      final visible = buildVisibleRecords(
        records,
        statusFilter: RecordsStatusFilter.pending,
        sortOrder: RecordsSortOrder.oldestFirst,
      );

      expect(visible.length, 1);
      expect(visible.single.id, 'record-3');
    });
  });

  testWidgets('小屏记录页使用纵向列表而不是横向滑动卡片带', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 900,
            child: RecordsSection(records: records),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(find.byType(TextField).first);
    expect(searchField.textAlignVertical, TextAlignVertical.center);

    expect(find.text('搜索场景、房间或点位'), findsOneWidget);
    expect(find.text('左右滑动'), findsNothing);
    expect(find.text('机舱左侧点位'), findsOneWidget);
    expect(find.text('全部记录'), findsNothing);
    expect(find.text('记录预览'), findsNothing);
  });
}
