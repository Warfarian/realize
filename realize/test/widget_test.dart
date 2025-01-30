// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:realize/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mock camera
    final cameras = [
      CameraDescription(
        name: 'Mock Camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      ),
    ];

    // Build our app and trigger a frame
    await tester.pumpWidget(MyApp(cameras: cameras));

    // Verify that the app starts with permission request
    expect(find.text('Camera and microphone permissions are required'), findsOneWidget);
    expect(find.text('Grant Permissions'), findsOneWidget);
  });
}
