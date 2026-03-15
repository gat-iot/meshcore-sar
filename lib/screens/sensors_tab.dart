import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../providers/connection_provider.dart';
import '../providers/contacts_provider.dart';
import '../providers/sensors_provider.dart';
import '../widgets/sensors/sensor_telemetry_card.dart';

class SensorsTab extends StatefulWidget {
  const SensorsTab({super.key});

  @override
  State<SensorsTab> createState() => _SensorsTabState();
}

class _SensorsTabState extends State<SensorsTab> {
  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    _scheduleMinuteTicker();
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    super.dispose();
  }

  void _scheduleMinuteTicker() {
    _minuteTicker?.cancel();

    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final delay = nextMinute.difference(now);

    _minuteTicker = Timer(delay, () {
      if (!mounted) return;
      context.read<SensorsProvider>().clearExpiredRefreshStates();
      setState(() {});
      _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        context.read<SensorsProvider>().clearExpiredRefreshStates();
        setState(() {});
      });
    });
  }

  Future<void> _showAddSensorSheet(BuildContext context) async {
    final sensorsProvider = context.read<SensorsProvider>();
    final contactsProvider = context.read<ContactsProvider>();
    final candidates = sensorsProvider.availableCandidates(contactsProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (candidates.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No eligible nodes available. Discover a relay or node first.',
              ),
            ),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const ListTile(
                title: Text(
                  'Add sensor node',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Pick a relay or node to watch in Sensors.'),
              ),
              ...candidates.map(
                (contact) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFDDEAF8),
                    child: Icon(
                      _typeIcon(contact),
                      color: const Color(0xFF1E4F7A),
                    ),
                  ),
                  title: Text(contact.displayName),
                  subtitle: _SensorCandidatePreview(contact: contact),
                  isThreeLine: true,
                  onTap: () async {
                    await sensorsProvider.addSensor(contact);
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${contact.displayName} added to Sensors',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMetricSelector(
    BuildContext context,
    String publicKeyHex,
    Contact? contact,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer<SensorsProvider>(
        builder: (context, sensorsProvider, child) {
          final visibleFields = sensorsProvider.visibleFieldsFor(publicKeyHex);
          final options = sensorMetricOptionsFor(contact);
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  'Visible fields',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which values appear on sensor cards.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ...options.map((option) {
                  final visible = visibleFields.contains(option.key);
                  final span = sensorsProvider.fieldSpanFor(
                    publicKeyHex,
                    option.key,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            selected: visible,
                            label: Text(option.label),
                            onSelected: (value) {
                              sensorsProvider.toggleMetric(
                                publicKeyHex,
                                option.key,
                                value,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(value: 1, label: Text('1x')),
                            ButtonSegment<int>(value: 2, label: Text('2x')),
                          ],
                          selected: <int>{span},
                          onSelectionChanged: (selection) {
                            sensorsProvider.setFieldSpan(
                              publicKeyHex,
                              option.key,
                              selection.first,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshAll(BuildContext context) async {
    await context.read<SensorsProvider>().refreshAll(
      contactsProvider: context.read<ContactsProvider>(),
      connectionProvider: context.read<ConnectionProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSensorSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer2<SensorsProvider, ContactsProvider>(
        builder: (context, sensorsProvider, contactsProvider, child) {
          final watchedKeys = sensorsProvider.watchedSensorKeys;

          return RefreshIndicator(
            onRefresh: () => _refreshAll(context),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (watchedKeys.isEmpty)
                  const _EmptySensorsState()
                else
                  ...watchedKeys.map((key) {
                    Contact? contact;
                    for (final entry in contactsProvider.contacts) {
                      if (entry.publicKeyHex == key) {
                        contact = entry;
                        break;
                      }
                    }
                    return SensorTelemetryCard(
                      contact: contact,
                      state: sensorsProvider.stateFor(key),
                      visibleFields: sensorsProvider.visibleFieldsFor(key),
                      fieldSpans: {
                        for (final field in sensorsProvider.visibleFieldsFor(
                          key,
                        ))
                          field: sensorsProvider.fieldSpanFor(key, field),
                      },
                      onRemove: () async {
                        await sensorsProvider.removeSensor(key);
                      },
                      onCustomize: () =>
                          _showMetricSelector(context, key, contact),
                      onRefresh: () => sensorsProvider.refreshSensor(
                        publicKeyHex: key,
                        contactsProvider: contactsProvider,
                        connectionProvider: context.read<ConnectionProvider>(),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SensorCandidatePreview extends StatelessWidget {
  final Contact contact;

  const _SensorCandidatePreview({required this.contact});

  @override
  Widget build(BuildContext context) {
    final telemetry = contact.telemetry;
    final previewLines = <String>[
      '${contact.type.displayName} • ${contact.publicKeyShort}',
      if (telemetry?.batteryPercentage != null)
        'Battery ${telemetry!.batteryPercentage!.toStringAsFixed(0)}% • '
            'Temp ${telemetry.temperature?.toStringAsFixed(1) ?? '--'}°C',
      if (telemetry?.gpsLocation != null)
        'GPS ${telemetry!.gpsLocation!.latitude.toStringAsFixed(3)}, '
            '${telemetry.gpsLocation!.longitude.toStringAsFixed(3)}',
    ];

    if (previewLines.length == 1) {
      previewLines.add('No telemetry preview available yet');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: previewLines
          .take(3)
          .map(
            (line) => Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
          )
          .toList(),
    );
  }
}

class _EmptySensorsState extends StatelessWidget {
  const _EmptySensorsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFDDEAF8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_outlined,
              size: 40,
              color: Color(0xFF1E4F7A),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No sensor nodes added',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Use + to add discovered relays or nodes. Pull down to refresh telemetry after adding them.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _typeIcon(Contact contact) {
  if (contact.isSensor) {
    return Icons.sensors;
  }
  if (contact.isRepeater) {
    return Icons.router;
  }
  if (contact.isChat) {
    return Icons.person;
  }
  return Icons.device_hub;
}
