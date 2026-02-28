import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_sar_app/models/contact.dart';
import 'package:meshcore_sar_app/providers/contacts_provider.dart';
import 'package:meshcore_sar_app/services/cayenne_lpp_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactsProvider.updateTelemetry', () {
    late ContactsProvider provider;
    late Uint8List publicKey;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = ContactsProvider();
      publicKey = Uint8List.fromList([
        0xAA,
        0xBB,
        0xCC,
        0xDD,
        0xEE,
        0xFF,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0x10,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x1A,
      ]);

      provider.addOrUpdateContact(
        Contact(
          publicKey: publicKey,
          type: ContactType.chat,
          flags: 0,
          outPathLen: 0,
          outPath: Uint8List(64),
          advName: 'Test Contact',
          lastAdvert: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          advLat: (46.0569 * 1e6).toInt(),
          advLon: (14.5058 * 1e6).toInt(),
          lastMod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      );
    });

    test('ignores telemetry GPS at 0,0 and keeps advert location', () {
      final lppData = CayenneLppParser.createGpsData(
        latitude: 0.0,
        longitude: 0.0,
      );

      provider.updateTelemetry(publicKey.sublist(0, 6), lppData);
      final updated = provider.findContactByKey(publicKey)!;

      expect(updated.telemetry, isNotNull);
      expect(updated.telemetry!.gpsLocation, isNull);
      expect(updated.displayLocation, isNotNull);
      expect(updated.displayLocation!.latitude, closeTo(46.0569, 0.000001));
      expect(updated.displayLocation!.longitude, closeTo(14.5058, 0.000001));
    });

    test('keeps valid telemetry GPS and uses it for display location', () {
      final lppData = CayenneLppParser.createGpsData(
        latitude: 45.0001,
        longitude: 13.9999,
      );

      provider.updateTelemetry(publicKey.sublist(0, 6), lppData);
      final updated = provider.findContactByKey(publicKey)!;

      expect(updated.telemetry, isNotNull);
      expect(updated.telemetry!.gpsLocation, isNotNull);
      expect(
        updated.telemetry!.gpsLocation!.latitude,
        closeTo(45.0001, 0.0001),
      );
      expect(
        updated.telemetry!.gpsLocation!.longitude,
        closeTo(13.9999, 0.0001),
      );
      expect(updated.displayLocation, isNotNull);
      expect(updated.displayLocation!.latitude, closeTo(45.0001, 0.0001));
      expect(updated.displayLocation!.longitude, closeTo(13.9999, 0.0001));
    });
  });
}
