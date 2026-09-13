import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuru_syougi/main.dart';

void main() {
  testWidgets('盤面が9x9のマスと初期配置の駒を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('先手番'), findsOneWidget);
    // 歩(先手9枚+後手9枚)・玉/王など、初期配置の駒記号が表示されていること
    expect(find.text('歩'), findsNWidgets(18));
    expect(find.text('玉'), findsOneWidget);
    expect(find.text('王'), findsOneWidget);
    expect(find.text('飛'), findsNWidgets(2));
    expect(find.text('角'), findsNWidgets(2));
  });

  testWidgets('先手の歩をタップすると移動先がハイライトされ、タップで移動できる',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 盤面上の全81マスの GestureDetector を取得（投了ボタンなど盤外の
    // GestureDetector と混同しないよう GridView 配下に限定する）
    final squares = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    );
    expect(squares, findsNWidgets(81));

    // 先手の歩(7段目=下から2段目, 中央付近)をタップして選択
    // row=6,col=4 -> index = 6*9+4 = 58
    await tester.tap(squares.at(58));
    await tester.pump();

    // 移動後: row=5,col=4 -> index = 5*9+4 = 49 をタップして移動実行
    await tester.tap(squares.at(49));
    await tester.pump();

    // 手番が後手に切り替わっていること
    expect(find.text('後手番'), findsOneWidget);

    // CPU（後手）の着手タイマーが発火するまで進め、後片付け時に
    // タイマーが残ったままにならないようにする。
    await tester.pump(const Duration(seconds: 1));
  });
}
