import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_sar_app/providers/connection_provider.dart';

void main() {
  group('ConnectionProvider channel slot occupancy', () {
    test('treats non-zero secret as configured', () {
      expect(
        ConnectionProvider.channelHasConfiguredSecret(Uint8List(16)),
        isFalse,
      );
      expect(
        ConnectionProvider.channelHasConfiguredSecret(
          Uint8List.fromList([1, ...List<int>.filled(15, 0)]),
        ),
        isTrue,
      );
    });

    test('treats duplicate hashtag channels as conflicts', () {
      expect(
        ConnectionProvider.isDuplicateChannelName(
          requestedName: '#sar',
          existingName: '#sar',
        ),
        isTrue,
      );
    });

    test('allows private channels with the same name to coexist', () {
      expect(
        ConnectionProvider.isDuplicateChannelName(
          requestedName: 'Ops',
          existingName: 'Ops',
        ),
        isFalse,
      );
    });
  });
}
