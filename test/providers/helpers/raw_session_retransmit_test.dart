import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_sar_app/models/contact.dart';
import 'package:meshcore_sar_app/providers/helpers/raw_session_retransmit.dart';

class _Fragment {
  final int index;
  final Uint8List payload;

  _Fragment(this.index, this.payload);
}

Contact _buildContact({required int outPathLen}) {
  return Contact(
    publicKey: Uint8List.fromList(List<int>.generate(32, (i) => i)),
    type: ContactType.chat,
    flags: 0,
    outPathLen: outPathLen,
    outPath: Uint8List.fromList(List<int>.generate(8, (i) => i + 1)),
    advName: 'Requester',
    lastAdvert: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    advLat: 0,
    advLon: 0,
    lastMod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('serveCachedSessionFragments', () {
    test('returns false when sender callback is missing', () async {
      final ok = await serveCachedSessionFragments<_Fragment>(
        providerLabel: 'TestProvider',
        sessionId: 'deadbeef',
        requester: _buildContact(outPathLen: 1),
        fragments: [
          _Fragment(0, Uint8List.fromList([1])),
        ],
        maxDirectPayloadHops: 3,
        indexOf: (f) => f.index,
        encodeBinary: (f) => f.payload,
        sendRawPacket: null,
      );

      expect(ok, isFalse);
    });

    test('sends only requested indices and waits for ack', () async {
      final sent = <Uint8List>[];
      final waited = <int>[];
      final ok = await serveCachedSessionFragments<_Fragment>(
        providerLabel: 'TestProvider',
        sessionId: 'deadbeef',
        requester: _buildContact(outPathLen: 1),
        fragments: [
          _Fragment(0, Uint8List.fromList([10])),
          _Fragment(1, Uint8List.fromList([20])),
          _Fragment(2, Uint8List.fromList([30])),
        ],
        maxDirectPayloadHops: 3,
        indexOf: (f) => f.index,
        encodeBinary: (f) => f.payload,
        sendRawPacket:
            ({
              required contactPath,
              required contactPathLen,
              required payload,
            }) async {
              sent.add(payload);
            },
        waitForFragmentAck:
            ({
              required sessionId,
              required index,
              timeout = const Duration(seconds: 8),
            }) async {
              waited.add(index);
              return true;
            },
        requestedIndices: {1, 2},
      );

      expect(ok, isTrue);
      expect(sent.length, equals(2));
      expect(sent[0], equals(Uint8List.fromList([20])));
      expect(sent[1], equals(Uint8List.fromList([30])));
      expect(waited, equals([1, 2]));
    });

    test('fails when ack does not arrive', () async {
      final ok = await serveCachedSessionFragments<_Fragment>(
        providerLabel: 'TestProvider',
        sessionId: 'deadbeef',
        requester: _buildContact(outPathLen: 1),
        fragments: [
          _Fragment(0, Uint8List.fromList([1])),
        ],
        maxDirectPayloadHops: 3,
        indexOf: (f) => f.index,
        encodeBinary: (f) => f.payload,
        sendRawPacket:
            ({
              required contactPath,
              required contactPathLen,
              required payload,
            }) async {},
        waitForFragmentAck:
            ({
              required sessionId,
              required index,
              timeout = const Duration(seconds: 8),
            }) async {
              return false;
            },
      );

      expect(ok, isFalse);
    });

    test('fails when no requested index matches cached fragments', () async {
      final ok = await serveCachedSessionFragments<_Fragment>(
        providerLabel: 'TestProvider',
        sessionId: 'deadbeef',
        requester: _buildContact(outPathLen: 1),
        fragments: [
          _Fragment(0, Uint8List.fromList([1])),
        ],
        maxDirectPayloadHops: 3,
        indexOf: (f) => f.index,
        encodeBinary: (f) => f.payload,
        sendRawPacket:
            ({
              required contactPath,
              required contactPathLen,
              required payload,
            }) async {},
        requestedIndices: {99},
      );

      expect(ok, isFalse);
    });
  });
}
