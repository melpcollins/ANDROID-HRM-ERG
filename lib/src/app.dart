import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'domain/models/ble_device_info.dart';
import 'domain/models/connection_status.dart';

class HrmErgApp extends StatelessWidget {
  const HrmErgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRM ERG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const DeviceSetupScreen(),
    );
  }
}

class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  late final TextEditingController _startingWattsController;
  late final TextEditingController _targetHrController;

  @override
  void initState() {
    super.initState();
    _startingWattsController = TextEditingController(text: '100');
    _targetHrController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _startingWattsController.dispose();
    _targetHrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectState = ref.watch(connectSetupControllerProvider);
    final connectController = ref.read(connectSetupControllerProvider.notifier);

    final sessionState = ref.watch(ergSessionControllerProvider);
    final sessionController = ref.read(ergSessionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DeviceSection(
            title: 'Heart Rate Monitor',
            status: connectState.hrStatus,
            selectedDeviceId: connectState.selectedHrId,
            devices: connectState.hrDevices,
            isScanning: connectState.scanningHr,
            error: connectState.hrError,
            onScan: connectController.scanHrMonitors,
            onReconnectSaved: connectController.reconnectHrMonitor,
            onConnect: connectController.connectHrMonitor,
          ),
          const SizedBox(height: 16),
          _DeviceSection(
            title: 'Wattbike Trainer',
            status: connectState.trainerStatus,
            selectedDeviceId: connectState.selectedTrainerId,
            devices: connectState.trainerDevices,
            isScanning: connectState.scanningTrainer,
            error: connectState.trainerError,
            onScan: connectController.scanTrainers,
            onReconnectSaved: connectController.reconnectTrainer,
            onConnect: connectController.connectTrainer,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ERG Control',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _startingWattsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Starting Watts',
                      hintText: 'e.g. 150',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetHrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target Heart Rate',
                      hintText: 'e.g. 135',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final startingWatts = int.tryParse(
                            _startingWattsController.text.trim(),
                          );
                          final targetHr = int.tryParse(
                            _targetHrController.text.trim(),
                          );

                          if (startingWatts == null || targetHr == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter valid integers for watts and target HR.',
                                ),
                              ),
                            );
                            return;
                          }

                          await sessionController.startSession(
                            startingWatts: startingWatts,
                            targetHr: targetHr,
                          );
                        },
                        child: const Text('Start'),
                      ),
                      OutlinedButton(
                        onPressed: sessionState.isRunning
                            ? sessionController.stopSession
                            : null,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                  if (sessionState.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      sessionState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (sessionState.isRunning)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Session (1-min averages)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: 'Heart Rate (avg 60s)',
                      value: sessionState.averageHr == null
                          ? '--'
                          : '${sessionState.averageHr!.toStringAsFixed(1)} bpm',
                    ),
                    _MetricRow(
                      label: 'Current Power (avg 60s)',
                      value: sessionState.averagePower == null
                          ? '--'
                          : '${sessionState.averagePower!.toStringAsFixed(1)} W',
                    ),
                    _MetricRow(
                      label: 'Target HR',
                      value: '${sessionState.targetHr ?? '--'} bpm',
                    ),
                    _MetricRow(
                      label: 'Latest Power Command',
                      value: '${sessionState.currentPower ?? '--'} W',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.title,
    required this.status,
    required this.selectedDeviceId,
    required this.devices,
    required this.isScanning,
    required this.error,
    required this.onScan,
    required this.onReconnectSaved,
    required this.onConnect,
  });

  final String title;
  final ConnectionStatus status;
  final String? selectedDeviceId;
  final List<BleDeviceInfo> devices;
  final bool isScanning;
  final String? error;
  final Future<void> Function() onScan;
  final Future<void> Function() onReconnectSaved;
  final Future<void> Function(String deviceId) onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_statusLabel(status))),
              ],
            ),
            const SizedBox(height: 8),
            if (selectedDeviceId != null)
              Text('Saved device: $selectedDeviceId'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: isScanning ? null : () => onScan(),
                  child: Text(isScanning ? 'Scanning...' : 'Scan'),
                ),
                OutlinedButton(
                  onPressed: selectedDeviceId == null
                      ? null
                      : () => onReconnectSaved(),
                  child: const Text('Reconnect saved'),
                ),
              ],
            ),
            if (error != null && error!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (devices.isEmpty)
              const Text('No devices yet. Tap Scan.')
            else
              ...devices.map(
                (device) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name),
                  subtitle: Text(device.id),
                  trailing: selectedDeviceId == device.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: () => onConnect(device.id),
                          child: const Text('Connect'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.scanning:
        return 'Scanning';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting';
    }
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

