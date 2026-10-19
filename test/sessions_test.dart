import 'package:flutter_test/flutter_test.dart';
import 'package:m_admin/features/sessions/screens/sessions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionRow Lifecycle & Status Resolution', () {
    test('recentStatus correctly identifies blocked attempt on device', () {
      final now = DateTime.now();
      final blocked = SessionRow(
        userId: 'user_1',
        userName: 'Abebe Kebede',
        deviceId: 'device_abc',
        blockedCount: 2,
        lastBlockedAt: now,
      );

      expect(blocked.isCurrentBlocked, isTrue);
      expect(blocked.recentStatus, equals(DeviceRecentStatus.blocked));
    });

    test('recentStatus resolves connected when device updated after blocked attempt', () {
      final base = DateTime.now();
      final blockedAt = base.subtract(const Duration(hours: 2));
      final updatedAt = base.subtract(const Duration(minutes: 10));

      final connected = SessionRow(
        userId: 'user_2',
        userName: 'Almaz Ayana',
        deviceId: 'device_xyz',
        updatedAt: updatedAt,
        blockedCount: 1,
        lastBlockedAt: blockedAt,
      );

      expect(connected.isCurrentConnected, isTrue);
      expect(connected.recentStatus, equals(DeviceRecentStatus.connected));
    });

    test('recentStatus resolves ready to pair when unbound after admin reset', () {
      final base = DateTime.now();
      final resetAt = base.subtract(const Duration(minutes: 5));

      final ready = SessionRow(
        userId: 'user_3',
        userName: 'Dawit Tsige',
        deviceId: '',
        resetCount: 1,
        lastResetAt: resetAt,
      );

      expect(ready.isCurrentReadyToPair, isTrue);
      expect(ready.recentStatus, equals(DeviceRecentStatus.reset));
    });
  });

  group('SessionFilter Enum', () {
    test('contains expected filter options in priority order', () {
      expect(SessionFilter.values, contains(SessionFilter.blockedAuth));
      expect(SessionFilter.values, contains(SessionFilter.locked));
      expect(SessionFilter.values, contains(SessionFilter.readyToPair));
      expect(SessionFilter.values, contains(SessionFilter.all));
    });
  });
}
