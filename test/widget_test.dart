import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmacist_dashboard/main.dart';
import 'package:pharmacist_dashboard/screens/login_screen.dart';
import 'package:pharmacist_dashboard/providers/providers.dart';

void main() {
  testWidgets('App boots to LoginScreen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const PharmaDashApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
