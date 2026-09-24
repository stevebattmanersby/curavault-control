import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdminScrollableTable reaches final row and rightmost column',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 1366,
            height: 768,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AdminCard(
                expandChild: true,
                header: const Text('User summaries'),
                child: AdminScrollableTable(
                  minWidth: 1320,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('User ID')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Last active')),
                      DataColumn(label: Text('Profiles')),
                      DataColumn(label: Text('Records')),
                      DataColumn(label: Text('Documents')),
                      DataColumn(label: Text('Appointments')),
                      DataColumn(label: Text('Medications')),
                      DataColumn(label: Text('Vaccinations')),
                    ],
                    rows: [
                      for (var i = 0; i < 40; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('usr_$i',
                                key: i == 0
                                    ? const Key('first-user-row')
                                    : i == 39
                                        ? const Key('final-user-row')
                                        : null)),
                            DataCell(Text('user$i@example.test')),
                            const DataCell(Text('2026-09-15')),
                            DataCell(Text('$i')),
                            DataCell(Text('${i + 1}')),
                            DataCell(Text('${i + 2}')),
                            DataCell(Text('${i + 3}')),
                            DataCell(Text('${i + 4}')),
                            DataCell(Text('${i + 5}',
                                key: i == 39
                                    ? const Key('final-rightmost-cell')
                                    : null)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('first-user-row')), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('final-user-row'))).top,
        greaterThan(768));

    await tester.drag(
        find.byType(AdminScrollableTable), const Offset(0, -2200));
    await tester.pumpAndSettle();

    final finalRowRect =
        tester.getRect(find.byKey(const Key('final-user-row')));
    expect(finalRowRect.top, lessThan(768));
    expect(finalRowRect.bottom, greaterThan(0));

    await tester.drag(
        find.byType(AdminScrollableTable), const Offset(-1200, 0));
    await tester.pumpAndSettle();

    final rightmostRect =
        tester.getRect(find.byKey(const Key('final-rightmost-cell')));
    expect(rightmostRect.left, lessThan(1366));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminScrollableTable smoke covers requested viewport sizes',
      (tester) async {
    for (final size in const [
      Size(1920, 1080),
      Size(1440, 900),
      Size(1366, 768),
      Size(1024, 768),
      Size(768, 1024),
      Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: AdminScrollableTable(
              minWidth: 900,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('A')),
                  DataColumn(label: Text('B')),
                  DataColumn(label: Text('C')),
                ],
                rows: [
                  for (var i = 0; i < 40; i++)
                    DataRow(cells: [
                      DataCell(Text('row-$i')),
                      DataCell(Text('mid-$i')),
                      DataCell(Text('end-$i')),
                    ]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'viewport ${size.width}x${size.height}');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
