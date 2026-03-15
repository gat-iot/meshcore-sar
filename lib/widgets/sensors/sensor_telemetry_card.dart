import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../../models/contact.dart';
import '../../providers/sensors_provider.dart';
import '../../utils/location_formats.dart';

class SensorMetricOption {
  final String key;
  final String label;

  const SensorMetricOption({required this.key, required this.label});
}

List<SensorMetricOption> sensorMetricOptionsFor(Contact? contact) {
  final telemetry = contact?.telemetry;
  final options = <SensorMetricOption>[
    if (telemetry?.batteryMilliVolts != null)
      const SensorMetricOption(key: 'voltage', label: 'Voltage'),
    if (telemetry?.batteryPercentage != null)
      const SensorMetricOption(key: 'battery', label: 'Battery'),
    if (telemetry?.temperature != null)
      const SensorMetricOption(key: 'temperature', label: 'Temperature'),
    if (telemetry?.humidity != null)
      const SensorMetricOption(key: 'humidity', label: 'Humidity'),
    if (telemetry?.pressure != null)
      const SensorMetricOption(key: 'pressure', label: 'Pressure'),
    if (telemetry?.gpsLocation != null)
      const SensorMetricOption(key: 'gps', label: 'GPS'),
  ];

  final extraSensorData = telemetry?.extraSensorData;
  if (extraSensorData != null) {
    for (final key in extraSensorData.keys) {
      options.add(
        SensorMetricOption(
          key: _extraFieldKey(key),
          label: _formatExtraFieldLabel(key),
        ),
      );
    }
  }

  return options;
}

Set<String> sensorMetricKeysFor(Contact? contact) {
  return sensorMetricOptionsFor(contact).map((option) => option.key).toSet();
}

Map<String, int> sensorDefaultFieldSpans(Iterable<String> fieldKeys) {
  final spans = <String, int>{};
  if (fieldKeys.contains('gps')) {
    spans['gps'] = 2;
  }
  return spans;
}

class SensorTelemetryCard extends StatelessWidget {
  final Contact? contact;
  final SensorRefreshState state;
  final Set<String> visibleFields;
  final Map<String, int> fieldSpans;
  final Future<void> Function()? onRemove;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onCustomize;
  final EdgeInsetsGeometry margin;
  final String emptyMetricsMessage;

  const SensorTelemetryCard({
    super.key,
    required this.contact,
    required this.state,
    required this.visibleFields,
    required this.fieldSpans,
    this.onRemove,
    this.onRefresh,
    this.onCustomize,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.emptyMetricsMessage =
        'All fields are hidden. Use Visible fields to choose what to show.',
  });

  bool get _showsMenu =>
      onRefresh != null || onCustomize != null || onRemove != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final telemetry = contact?.telemetry;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = contact == null || telemetry == null
        ? const <_MetricCardData>[]
        : _buildMetricCards(l10n, telemetry, contact!);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerLow,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            contact?.displayName ?? 'Unavailable node',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (state == SensorRefreshState.timeout)
                            const _InlineAlertBadge(label: 'No response'),
                        ],
                      ),
                      if (telemetry != null) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${_formatTelemetryDateTime(telemetry.timestamp)} • ${_formatTelemetryTime(telemetry.timestamp)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (state == SensorRefreshState.refreshing)
                              const _InlineStateMeta(
                                label: 'Refreshing',
                                color: Color(0xFF266AC2),
                                spinning: true,
                              ),
                            if (state == SensorRefreshState.success)
                              const _InlineStateMeta(
                                label: 'Updated',
                                color: Color(0xFF218B63),
                                icon: Icons.check_circle,
                              ),
                            if (state == SensorRefreshState.unavailable)
                              const _InlineStateMeta(
                                label: 'Unavailable',
                                color: Color(0xFFB13B55),
                                icon: Icons.error_outline,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (_showsMenu)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'refresh' && onRefresh != null) {
                        await onRefresh!();
                      } else if (value == 'remove' && onRemove != null) {
                        await onRemove!();
                      } else if (value == 'customize' && onCustomize != null) {
                        onCustomize!();
                      }
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];
                      if (onRefresh != null) {
                        items.add(
                          PopupMenuItem<String>(
                            value: 'refresh',
                            child: Text(l10n.refresh),
                          ),
                        );
                      }
                      if (onCustomize != null) {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'customize',
                            child: Text('Customize fields'),
                          ),
                        );
                      }
                      if (onRemove != null) {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                        );
                      }
                      return items;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (contact == null)
              const Text(
                'This node is no longer available in the contact list.',
              )
            else if (telemetry == null)
              const Text(
                'No telemetry received yet. Use Refresh from the menu or pull down to fetch it.',
              )
            else if (metrics.isEmpty)
              Text(emptyMetricsMessage)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final compactWidth = (constraints.maxWidth - spacing) / 2;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: metrics
                        .map(
                          (metric) => _MetricTile(
                            data: metric,
                            width:
                                (fieldSpans[metric.fieldKey] == 2 ||
                                    metric.wide)
                                ? constraints.maxWidth
                                : compactWidth,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<_MetricCardData> _buildMetricCards(
    AppLocalizations l10n,
    dynamic telemetry,
    Contact contact,
  ) {
    final items = <_MetricCardData>[];

    if (visibleFields.contains('voltage') &&
        telemetry.batteryMilliVolts != null) {
      items.add(
        _MetricCardData(
          fieldKey: 'voltage',
          icon: Icons.bolt,
          label: l10n.voltage,
          value: '${(telemetry.batteryMilliVolts! / 1000).toStringAsFixed(3)}V',
          accent: const Color(0xFF0A7D61),
        ),
      );
    }
    if (visibleFields.contains('battery') &&
        telemetry.batteryPercentage != null) {
      items.add(
        _MetricCardData(
          fieldKey: 'battery',
          icon: Icons.battery_5_bar,
          label: l10n.battery,
          value: '${telemetry.batteryPercentage!.toStringAsFixed(0)}%',
          accent: const Color(0xFF4B8E2F),
        ),
      );
    }
    if (visibleFields.contains('temperature') &&
        telemetry.temperature != null) {
      items.add(
        _MetricCardData(
          fieldKey: 'temperature',
          icon: Icons.thermostat,
          label: l10n.temperature,
          value: '${telemetry.temperature!.toStringAsFixed(1)}°C',
          accent: const Color(0xFFC76821),
        ),
      );
    }
    if (visibleFields.contains('humidity') && telemetry.humidity != null) {
      items.add(
        _MetricCardData(
          fieldKey: 'humidity',
          icon: Icons.water_drop,
          label: l10n.humidity,
          value: '${telemetry.humidity!.toStringAsFixed(1)}%',
          accent: const Color(0xFF246BB2),
        ),
      );
    }
    if (visibleFields.contains('pressure') && telemetry.pressure != null) {
      items.add(
        _MetricCardData(
          fieldKey: 'pressure',
          icon: Icons.compress,
          label: l10n.pressure,
          value: '${telemetry.pressure!.toStringAsFixed(1)} hPa',
          accent: const Color(0xFF6B4BAE),
        ),
      );
    }
    if (visibleFields.contains('gps') && telemetry.gpsLocation != null) {
      items.add(
        _MetricCardData(
          fieldKey: 'gps',
          icon: Icons.place,
          label: l10n.gpsTelemetry,
          value:
              '${telemetry.gpsLocation!.latitude.toStringAsFixed(5)}, ${telemetry.gpsLocation!.longitude.toStringAsFixed(5)}',
          accent: const Color(0xFFAA3F57),
          wide: true,
          mapLocation: LatLng(
            telemetry.gpsLocation!.latitude,
            telemetry.gpsLocation!.longitude,
          ),
          secondaryValue: formatPlusCode(
            telemetry.gpsLocation!.latitude,
            telemetry.gpsLocation!.longitude,
          ),
        ),
      );
    }
    if (telemetry.extraSensorData != null) {
      for (final entry in telemetry.extraSensorData!.entries) {
        final fieldKey = _extraFieldKey(entry.key);
        if (!visibleFields.contains(fieldKey)) {
          continue;
        }
        final metric = _buildExtraMetricCardData(entry.key, entry.value);
        if (metric != null) {
          items.add(metric);
        }
      }
    }

    return items;
  }

  _MetricCardData? _buildExtraMetricCardData(String rawKey, dynamic value) {
    final metricKey = _parseMetricKey(rawKey);
    final label = _formatExtraFieldLabel(rawKey);

    switch (metricKey.baseKey) {
      case 'altitude':
        final meters = _asDouble(value);
        if (meters == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.terrain_outlined,
          label: label,
          value: '${_formatNumber(meters, maxFractionDigits: 1)} m',
          accent: const Color(0xFF7A5C3E),
        );

      case 'illuminance':
        final lux = _asDouble(value);
        if (lux == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.light_mode_outlined,
          label: label,
          value: '${_formatNumber(lux, maxFractionDigits: 0)} lx',
          secondaryValue:
              '~${_formatNumber(_approxDaylightIrradiance(lux), maxFractionDigits: 1)} W/m2 daylight',
          accent: const Color(0xFFC17B1D),
        );

      case 'presence':
        final isPresent = _asBool(value);
        if (isPresent == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.sensor_occupied_outlined,
          label: label,
          value: isPresent ? 'Detected' : 'Clear',
          accent: const Color(0xFFAA3F57),
        );

      case 'digital_input':
        final isHigh = _asBool(value);
        if (isHigh == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.input_outlined,
          label: label,
          value: isHigh ? 'High' : 'Low',
          accent: const Color(0xFF3A6D8C),
        );

      case 'digital_output':
        final isHigh = _asBool(value);
        if (isHigh == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.output_outlined,
          label: label,
          value: isHigh ? 'High' : 'Low',
          accent: const Color(0xFF4B7B5A),
        );

      case 'analog_input':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.tune,
          label: label,
          value: _formatNumber(reading, maxFractionDigits: 3),
          accent: const Color(0xFF5A6C84),
        );

      case 'analog_output':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.tune,
          label: label,
          value: _formatNumber(reading, maxFractionDigits: 3),
          accent: const Color(0xFF4B7785),
        );

      case 'accelerometer':
        final vector = _asVector3(value);
        if (vector == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.vibration_outlined,
          label: label,
          value:
              'X ${_formatNumber(vector.x)} • Y ${_formatNumber(vector.y)} • Z ${_formatNumber(vector.z)} g',
          secondaryValue:
              '|a| ${_formatNumber(_vectorMagnitude(vector), maxFractionDigits: 2)} g',
          accent: const Color(0xFF5A4C99),
          wide: true,
        );

      case 'gyrometer':
        final vector = _asVector3(value);
        if (vector == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.threed_rotation,
          label: label,
          value:
              'X ${_formatNumber(vector.x)} • Y ${_formatNumber(vector.y)} • Z ${_formatNumber(vector.z)} deg/s',
          secondaryValue:
              '|w| ${_formatNumber(_vectorMagnitude(vector), maxFractionDigits: 2)} deg/s',
          accent: const Color(0xFF6C4F96),
          wide: true,
        );

      case 'generic_sensor':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.sensors,
          label: label,
          value: _formatNumber(reading, maxFractionDigits: 2),
          accent: const Color(0xFF3E657C),
        );

      case 'current':
        final amps = _asDouble(value);
        if (amps == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.electric_bolt,
          label: label,
          value: _formatCurrent(amps),
          accent: const Color(0xFF1C7C54),
        );

      case 'frequency':
        final hz = _asDouble(value);
        if (hz == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.graphic_eq,
          label: label,
          value: _formatFrequency(hz),
          accent: const Color(0xFF2C6BA0),
        );

      case 'percentage':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.percent,
          label: label,
          value: '${_formatNumber(reading, maxFractionDigits: 1)}%',
          accent: const Color(0xFF4B8E2F),
        );

      case 'concentration':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.bubble_chart_outlined,
          label: label,
          value: '${_formatNumber(reading, maxFractionDigits: 0)} ppm',
          accent: const Color(0xFF4D6D9A),
        );

      case 'power':
        final watts = _asDouble(value);
        if (watts == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.flash_on_outlined,
          label: label,
          value: _formatPower(watts),
          accent: const Color(0xFFB5622E),
        );

      case 'speed':
        final metersPerSecond = _asDouble(value);
        if (metersPerSecond == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.air,
          label: label,
          value: '${_formatNumber(metersPerSecond, maxFractionDigits: 2)} m/s',
          accent: const Color(0xFF2B78A0),
        );

      case 'distance':
        final meters = _asDouble(value);
        if (meters == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.straighten,
          label: label,
          value: _formatDistance(meters),
          accent: const Color(0xFF577590),
        );

      case 'energy':
        final kwh = _asDouble(value);
        if (kwh == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.battery_charging_full,
          label: label,
          value: _formatEnergy(kwh),
          accent: const Color(0xFF9C6644),
        );

      case 'direction':
        final degrees = _asDouble(value);
        if (degrees == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.explore_outlined,
          label: label,
          value: '${_formatNumber(degrees, maxFractionDigits: 0)} deg',
          secondaryValue: _formatCardinalDirection(degrees),
          accent: const Color(0xFF8A5A44),
        );

      case 'unixtime':
        final seconds = _asInt(value);
        if (seconds == null) return null;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        ).toLocal();
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.schedule,
          label: label,
          value: _formatTelemetryDateTime(timestamp),
          secondaryValue: _formatTelemetryTime(timestamp),
          accent: const Color(0xFF6B7280),
          wide: true,
        );

      case 'colour':
        final color = _asRgb(value);
        if (color == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.palette_outlined,
          label: label,
          value:
              '#${color.r.toRadixString(16).padLeft(2, '0').toUpperCase()}${color.g.toRadixString(16).padLeft(2, '0').toUpperCase()}${color.b.toRadixString(16).padLeft(2, '0').toUpperCase()}',
          secondaryValue: 'R ${color.r} • G ${color.g} • B ${color.b}',
          accent: Color.fromARGB(255, color.r, color.g, color.b),
          wide: true,
        );

      case 'switch':
        final isOn = _asBool(value);
        if (isOn == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: isOn ? Icons.toggle_on : Icons.toggle_off,
          label: label,
          value: isOn ? 'On' : 'Off',
          accent: const Color(0xFF4B7B5A),
        );

      case 'voltage':
        final volts = _asDouble(value);
        if (volts == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.bolt,
          label: label,
          value: '${_formatNumber(volts, maxFractionDigits: 3)} V',
          accent: const Color(0xFF0A7D61),
        );
    }

    switch (metricKey.baseKey) {
      case 'co2':
      case 'tvoc':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.bubble_chart_outlined,
          label: label,
          value: '${_formatNumber(reading, maxFractionDigits: 0)} ppm',
          accent: const Color(0xFF4D6D9A),
        );

      case 'pm25':
      case 'pm10':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.grain,
          label: label,
          value: '${_formatNumber(reading, maxFractionDigits: 1)} ug/m3',
          accent: const Color(0xFF7A6C5D),
        );

      case 'uv':
        final reading = _asDouble(value);
        if (reading == null) return null;
        return _MetricCardData(
          fieldKey: _extraFieldKey(rawKey),
          icon: Icons.wb_sunny_outlined,
          label: label,
          value: _formatNumber(reading, maxFractionDigits: 1),
          accent: const Color(0xFFC17B1D),
        );
    }

    if (value is num) {
      return _MetricCardData(
        fieldKey: _extraFieldKey(rawKey),
        icon: Icons.sensors,
        label: label,
        value: _formatNumber(value, maxFractionDigits: 2),
        accent: const Color(0xFF3E657C),
      );
    }

    return _MetricCardData(
      fieldKey: _extraFieldKey(rawKey),
      icon: Icons.sensors,
      label: label,
      value: '$value',
      accent: const Color(0xFF3E657C),
      wide: value is Map,
    );
  }

  double _approxDaylightIrradiance(double lux) {
    return lux / 120.0;
  }

  String _formatCurrent(double amps) {
    final absolute = amps.abs();
    if (absolute < 1.0) {
      return '${_formatNumber(amps * 1000, maxFractionDigits: 1)} mA';
    }
    return '${_formatNumber(amps, maxFractionDigits: 3)} A';
  }

  String _formatPower(double watts) {
    final absolute = watts.abs();
    if (absolute < 1.0) {
      return '${_formatNumber(watts * 1000, maxFractionDigits: 1)} mW';
    }
    return '${_formatNumber(watts, maxFractionDigits: 2)} W';
  }

  String _formatFrequency(double hertz) {
    final absolute = hertz.abs();
    if (absolute >= 1000000) {
      return '${_formatNumber(hertz / 1000000, maxFractionDigits: 2)} MHz';
    }
    if (absolute >= 1000) {
      return '${_formatNumber(hertz / 1000, maxFractionDigits: 2)} kHz';
    }
    return '${_formatNumber(hertz, maxFractionDigits: 0)} Hz';
  }

  String _formatDistance(double meters) {
    final absolute = meters.abs();
    if (absolute < 1.0) {
      return '${_formatNumber(meters * 1000, maxFractionDigits: 0)} mm';
    }
    if (absolute >= 1000.0) {
      return '${_formatNumber(meters / 1000, maxFractionDigits: 2)} km';
    }
    return '${_formatNumber(meters, maxFractionDigits: 2)} m';
  }

  String _formatEnergy(double kilowattHours) {
    final absolute = kilowattHours.abs();
    if (absolute < 1.0) {
      return '${_formatNumber(kilowattHours * 1000, maxFractionDigits: 1)} Wh';
    }
    return '${_formatNumber(kilowattHours, maxFractionDigits: 3)} kWh';
  }

  String _formatCardinalDirection(double degrees) {
    const points = <String>['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % points.length;
    return points[index];
  }

  String _formatNumber(num value, {int maxFractionDigits = 2}) {
    final absolute = value.abs();
    final digits = absolute >= 100
        ? 0
        : absolute >= 10
        ? math.min(maxFractionDigits, 1)
        : maxFractionDigits;
    final text = value.toStringAsFixed(digits);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  _Vector3? _asVector3(dynamic value) {
    if (value is! Map) return null;
    final x = _asDouble(value['x']);
    final y = _asDouble(value['y']);
    final z = _asDouble(value['z']);
    if (x == null || y == null || z == null) return null;
    return _Vector3(x: x, y: y, z: z);
  }

  _RgbColor? _asRgb(dynamic value) {
    if (value is! Map) return null;
    final red = _asInt(value['r']);
    final green = _asInt(value['g']);
    final blue = _asInt(value['b']);
    if (red == null || green == null || blue == null) return null;
    return _RgbColor(r: red, g: green, b: blue);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return null;
  }

  double _vectorMagnitude(_Vector3 vector) {
    return math.sqrt(
      vector.x * vector.x + vector.y * vector.y + vector.z * vector.z,
    );
  }

  String _formatTelemetryTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatTelemetryDateTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _InlineStateMeta extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool spinning;

  const _InlineStateMeta({
    required this.label,
    required this.color,
    this.icon,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinning)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.7,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAlertBadge extends StatelessWidget {
  final String label;

  const _InlineAlertBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFC17B1D).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFFC17B1D),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _MetricCardData data;
  final double width;

  const _MetricTile({required this.data, required this.width});

  Future<void> _showExpandedMap(BuildContext context) async {
    final location = data.mapLocation;
    if (location == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) {
          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.label),
                  Text(
                    data.value,
                    style: Theme.of(pageContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.secondaryValue != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      data.secondaryValue!,
                      style: Theme.of(pageContext).textTheme.bodyMedium,
                    ),
                  ),
                Expanded(
                  child: flutter_map.FlutterMap(
                    options: flutter_map.MapOptions(
                      initialCenter: location,
                      initialZoom: 15,
                    ),
                    children: [
                      flutter_map.TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.meshcore.sar.meshcore_sar_app',
                      ),
                      flutter_map.MarkerLayer(
                        markers: [
                          flutter_map.Marker(
                            point: location,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on,
                              color: data.accent,
                              size: 34,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: data.accent.withValues(alpha: 0.14)),
      ),
      child: data.mapLocation == null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricIcon(accent: data.accent, icon: data.icon),
                const SizedBox(width: 10),
                Expanded(child: _MetricText(data: data)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricIcon(accent: data.accent, icon: data.icon),
                    const SizedBox(width: 10),
                    Expanded(child: _MetricText(data: data)),
                  ],
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showExpandedMap(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 104,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            flutter_map.FlutterMap(
                              options: flutter_map.MapOptions(
                                initialCenter: data.mapLocation!,
                                initialZoom: 14,
                                interactionOptions:
                                    const flutter_map.InteractionOptions(
                                      flags: flutter_map.InteractiveFlag.none,
                                    ),
                              ),
                              children: [
                                flutter_map.TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.meshcore.sar.meshcore_sar_app',
                                ),
                                flutter_map.MarkerLayer(
                                  markers: [
                                    flutter_map.Marker(
                                      point: data.mapLocation!,
                                      width: 32,
                                      height: 32,
                                      child: Icon(
                                        Icons.location_on,
                                        color: data.accent,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_in_full,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Open map',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  final Color accent;
  final IconData icon;

  const _MetricIcon({required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: accent, size: 18),
    );
  }
}

class _MetricText extends StatelessWidget {
  final _MetricCardData data;

  const _MetricText({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: data.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        if (data.secondaryValue != null) ...[
          const SizedBox(height: 4),
          Text(
            data.secondaryValue!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCardData {
  final String fieldKey;
  final IconData icon;
  final String label;
  final String value;
  final String? secondaryValue;
  final Color accent;
  final bool wide;
  final LatLng? mapLocation;

  const _MetricCardData({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.value,
    this.secondaryValue,
    required this.accent,
    this.wide = false,
    this.mapLocation,
  });
}

class _ParsedMetricKey {
  final String baseKey;
  final int? channel;

  const _ParsedMetricKey({required this.baseKey, this.channel});
}

class _Vector3 {
  final double x;
  final double y;
  final double z;

  const _Vector3({required this.x, required this.y, required this.z});
}

class _RgbColor {
  final int r;
  final int g;
  final int b;

  const _RgbColor({required this.r, required this.g, required this.b});
}

String _extraFieldKey(String label) {
  return 'extra:$label';
}

String _formatExtraFieldLabel(String rawKey) {
  final metricKey = _parseMetricKey(rawKey);
  final label =
      _knownMetricLabels[metricKey.baseKey] ??
      _fallbackMetricLabel(metricKey.baseKey);
  if (metricKey.channel != null) {
    return '$label (ch ${metricKey.channel})';
  }
  return label;
}

const List<String> _knownMetricBaseKeys = <String>[
  'generic_sensor',
  'digital_output',
  'digital_input',
  'analog_output',
  'analog_input',
  'accelerometer',
  'illuminance',
  'concentration',
  'percentage',
  'direction',
  'frequency',
  'distance',
  'altitude',
  'humidity',
  'pressure',
  'temperature',
  'gyrometer',
  'unixtime',
  'presence',
  'current',
  'voltage',
  'colour',
  'switch',
  'energy',
  'power',
  'speed',
  'pm25',
  'pm10',
  'tvoc',
  'co2',
  'rpm',
  'cond',
  'uv',
];

const Map<String, String> _knownMetricLabels = <String, String>{
  'accelerometer': 'Accelerometer',
  'altitude': 'Altitude',
  'analog_input': 'Analog input',
  'analog_output': 'Analog output',
  'co2': 'CO2',
  'colour': 'Color',
  'concentration': 'Concentration',
  'cond': 'Conductivity',
  'current': 'Current',
  'digital_input': 'Digital input',
  'digital_output': 'Digital output',
  'direction': 'Direction',
  'distance': 'Distance',
  'energy': 'Energy',
  'frequency': 'Frequency',
  'generic_sensor': 'Generic sensor',
  'gyrometer': 'Gyrometer',
  'humidity': 'Humidity',
  'illuminance': 'Illuminance',
  'percentage': 'Percentage',
  'pm10': 'PM10',
  'pm25': 'PM2.5',
  'power': 'Power',
  'presence': 'Presence',
  'pressure': 'Pressure',
  'rpm': 'RPM',
  'speed': 'Speed',
  'switch': 'Switch',
  'temperature': 'Temperature',
  'tvoc': 'TVOC',
  'unixtime': 'Time',
  'uv': 'UV index',
  'voltage': 'Voltage',
};

_ParsedMetricKey _parseMetricKey(String rawKey) {
  for (final baseKey in _knownMetricBaseKeys) {
    if (rawKey == baseKey) {
      return _ParsedMetricKey(baseKey: baseKey);
    }
    if (rawKey.startsWith('${baseKey}_')) {
      final channel = int.tryParse(rawKey.substring(baseKey.length + 1));
      if (channel != null) {
        return _ParsedMetricKey(baseKey: baseKey, channel: channel);
      }
    }
  }

  final parts = rawKey.split('_');
  if (parts.length > 1) {
    final channel = int.tryParse(parts.last);
    if (channel != null) {
      return _ParsedMetricKey(
        baseKey: parts.sublist(0, parts.length - 1).join('_'),
        channel: channel,
      );
    }
  }

  return _ParsedMetricKey(baseKey: rawKey);
}

String _fallbackMetricLabel(String rawKey) {
  return rawKey
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
