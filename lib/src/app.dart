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

class DeviceSetupScreen extends ConsumerWidget {
  const DeviceSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectSetupControllerProvider);
    final controller = ref.read(connectSetupControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DeviceSection(
            title: 'Heart Rate Monitor',
            status: state.hrStatus,
            selectedDeviceId: state.selectedHrId,
            devices: state.hrDevices,
            isScanning: state.scanningHr,
            error: state.hrError,
            onScan: controller.scanHrMonitors,
            onReconnectSaved: controller.reconnectHrMonitor,
            onConnect: controller.connectHrMonitor,
          ),
          const SizedBox(height: 16),
          _DeviceSection(
            title: 'Wattbike Trainer',
            status: state.trainerStatus,
            selectedDeviceId: state.selectedTrainerId,
            devices: state.trainerDevices,
            isScanning: state.scanningTrainer,
            error: state.trainerError,
            onScan: controller.scanTrainers,
            onReconnectSaved: controller.reconnectTrainer,
            onConnect: controller.connectTrainer,
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
