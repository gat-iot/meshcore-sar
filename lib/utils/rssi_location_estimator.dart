import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Estimate distance from RSSI using the log-distance path loss model.
///
/// For LoRa at ~900 MHz:
/// - Path loss exponent (n) ≈ 2.7-3.5 for outdoor environments
/// - Reference distance: 1m, reference RSSI: -30 dBm (typical LoRa at 1m)
///
/// Formula: distance = 10 ^ ((txPower - rssi) / (10 * n))
/// We use a simplified form with empirical constants for LoRa mesh.
class RssiLocationEstimator {
  /// Estimate distance in meters from RSSI value.
  ///
  /// Returns null if RSSI is not usable.
  static double? estimateDistanceMeters(int rssiDbm) {
    // RSSI values above -30 are unrealistic for LoRa
    if (rssiDbm > -20 || rssiDbm < -140) return null;

    // Log-distance path loss model parameters for LoRa outdoor
    const double referenceRssi = -30.0; // RSSI at 1 meter
    const double pathLossExponent = 3.0; // outdoor mixed terrain

    final distance = math.pow(
      10.0,
      (referenceRssi - rssiDbm) / (10.0 * pathLossExponent),
    ).toDouble();

    // Clamp to reasonable range (10m - 50km)
    return distance.clamp(10.0, 50000.0);
  }

  /// Offset a point by a distance and bearing.
  ///
  /// Uses Haversine inverse to compute the destination point.
  static LatLng offsetPoint(
    LatLng origin,
    double distanceMeters,
    double bearingDegrees,
  ) {
    const double earthRadius = 6371000.0; // meters
    final lat1 = origin.latitude * math.pi / 180.0;
    final lon1 = origin.longitude * math.pi / 180.0;
    final bearing = bearingDegrees * math.pi / 180.0;
    final angularDistance = distanceMeters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  /// Estimate a contact's location based on the last-hop repeater position
  /// and the received signal strength.
  ///
  /// Returns null if estimation is not possible (no repeater location or RSSI).
  ///
  /// Uses a deterministic bearing derived from the contact's public key hash
  /// so the same contact always appears in the same direction from the repeater.
  static LatLng? estimateFromRepeater({
    required LatLng repeaterLocation,
    required int rssiDbm,
    required List<int> contactPublicKey,
  }) {
    final distance = estimateDistanceMeters(rssiDbm);
    if (distance == null) return null;

    // Deterministic bearing from contact key so position is stable
    final keyHash = contactPublicKey.fold<int>(0, (a, b) => a ^ b);
    final bearing = (keyHash % 360).toDouble();

    return offsetPoint(repeaterLocation, distance, bearing);
  }
}
