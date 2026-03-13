import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'domain/models/ble_device_info.dart';
import 'domain/models/connection_status.dart';
import 'domain/models/workout_config.dart';
import 'domain/models/workout_summary.dart';
import 'domain/models/workout_type.dart';

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
  late final TextEditingController _durationHoursController;
  late final TextEditingController _durationMinutesController;
  late final TextEditingController _assessmentPowerController;

  @override
  void initState() {
    super.initState();
    _startingWattsController = TextEditingController(text: '140');
    _targetHrController = TextEditingController(text: '135');
    _durationHoursController = TextEditingController(text: '1');
    _durationMinutesController = TextEditingController(text: '0');
    _assessmentPowerController = TextEditingController(text: '180');
  }

  @override
  void dispose() {
    _startingWattsController.dispose();
    _targetHrController.dispose();
    _durationHoursController.dispose();
    _durationMinutesController.dispose();
    _assessmentPowerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectState = ref.watch(connectSetupControllerProvider);
    final connectController = ref.read(connectSetupControllerProvider.notifier);
    final sessionState = ref.watch(workoutSessionControllerProvider);
    final sessionController = ref.read(workoutSessionControllerProvider.notifier);

    final selectedType = sessionState.selectedWorkoutType;
    final canStart =
        connectState.hrStatus == ConnectionStatus.connected &&
        connectState.trainerStatus == ConnectionStatus.connected &&
        !sessionState.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('HRM ERG')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<WorkoutType>(
                    segments: const [
                      ButtonSegment(
                        value: WorkoutType.hrErg,
                        label: Text('HR-ERG'),
                      ),
                      ButtonSegment(
                        value: WorkoutType.zone2Assessment,
                        label: Text('Zone 2 Assessment'),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: sessionState.isRunning
                        ? null
                        : (selection) {
                            sessionController.selectWorkoutType(selection.first);
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DeviceSection(
            title: 'HR Monitor',
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
            title: 'Trainer',
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
          _buildSetupCard(
            context,
            selectedType: selectedType,
            canStart: canStart,
            sessionState: sessionState,
            sessionController: sessionController,
          ),
          const SizedBox(height: 16),
          _buildLiveCard(context, sessionState, sessionController),
        ],
      ),
    );
  }

  Widget _buildSetupCard(
    BuildContext context, {
    required WorkoutType selectedType,
    required bool canStart,
    required dynamic sessionState,
    required dynamic sessionController,
  }) {
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
                    'Workout Setup',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (sessionState.isRunning)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => sessionController.stopWorkout(),
                    child: const Text('Stop'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedType == WorkoutType.hrErg) ...[
              TextField(
                controller: _startingWattsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Starting Watts',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetHrController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Heart Rate',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationHoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration Hours',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _durationMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration Minutes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Control defaults: 60s HR average, 20s loop.'),
            ] else ...[
              TextField(
                controller: _assessmentPowerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Assessment Power',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fixed protocol: 10 min at 80%, 75 min at 100%, 5 min at 60%.',
              ),
            ],
            if (sessionState.error != null) ...[
              const SizedBox(height: 12),
              Text(
                sessionState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: canStart ? () => _startWorkout(selectedType) : null,
                child: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCard(
    BuildContext context,
    dynamic sessionState,
    dynamic sessionController,
  ) {
    if (!sessionState.isRunning &&
        !sessionState.isCompleted &&
        sessionState.summary == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _MetricRow(label: 'Status', value: sessionState.statusLabel),
            _MetricRow(
              label: 'Countdown',
              value: _formatDuration(sessionState.remainingDuration),
            ),
            _MetricRow(
              label: 'HR',
              value: sessionState.currentHr == null
                  ? '--'
                  : '${sessionState.currentHr} bpm',
            ),
            _MetricRow(
              label: 'HR Avg (60s)',
              value: sessionState.averageHr == null
                  ? '--'
                  : '${sessionState.averageHr!.toStringAsFixed(1)} bpm',
            ),
            _MetricRow(
              label: 'Power',
              value: sessionState.currentPower == null
                  ? '--'
                  : '${sessionState.currentPower} W',
            ),
            if (sessionState.targetHr != null)
              _MetricRow(
                label: 'Target HR',
                value: '${sessionState.targetHr} bpm',
              ),
            if (sessionState.selectedWorkoutType == WorkoutType.hrErg &&
                sessionState.isRunning) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: sessionState.targetHr == null
                        ? null
                        : () => sessionController.updateHrErgTargetHr(
                              sessionState.targetHr! - 5,
                            ),
                    child: const Text('Target -5'),
                  ),
                  OutlinedButton(
                    onPressed: sessionState.targetHr == null
                        ? null
                        : () => sessionController.updateHrErgTargetHr(
                              sessionState.targetHr! + 5,
                            ),
                    child: const Text('Target +5'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MetricRow(
                label: 'Last Adjustment',
                value: sessionState.lastAdjustmentWatts == null
                    ? '--'
                    : '${sessionState.lastAdjustmentWatts} W',
              ),
            ],
            if (sessionState.summary != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Summary',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _SummaryContent(summary: sessionState.summary!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startWorkout(WorkoutType selectedType) async {
    final sessionController = ref.read(workoutSessionControllerProvider.notifier);
    if (selectedType == WorkoutType.hrErg) {
      final startingWatts = int.tryParse(_startingWattsController.text.trim());
      final targetHr = int.tryParse(_targetHrController.text.trim());
      final durationHours = int.tryParse(_durationHoursController.text.trim());
      final durationMinutes = int.tryParse(
        _durationMinutesController.text.trim(),
      );

      if (startingWatts == null ||
          targetHr == null ||
          durationHours == null ||
          durationMinutes == null ||
          durationHours < 0 ||
          durationMinutes < 0 ||
          durationMinutes > 59 ||
          (durationHours == 0 && durationMinutes == 0)) {
        _showInvalidInput();
        return;
      }

      await sessionController.startWorkout(
        HrErgConfig(
          startingWatts: startingWatts,
          targetHr: targetHr,
          loopSeconds: 20,
          duration: Duration(hours: durationHours, minutes: durationMinutes),
        ),
      );
      return;
    }

    final assessmentPower = int.tryParse(_assessmentPowerController.text.trim());
    if (assessmentPower == null || assessmentPower <= 0) {
      _showInvalidInput();
      return;
    }

    await sessionController.startWorkout(
      Zone2AssessmentConfig(assessmentPower: assessmentPower),
    );
  }

  void _showInvalidInput() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter valid workout values.')),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '--';
    }

    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.analysisAvailable) {
      return Text(summary.analysisMessage ?? 'Analysis unavailable.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricRow(
          label: 'Power Fade',
          value: '${summary.powerFadePercent!.toStringAsFixed(1)}%',
        ),
        _MetricRow(
          label: 'Aerobic Drift',
          value: '${summary.aerobicDriftPercent!.toStringAsFixed(1)}%',
        ),
        if (summary.zone2Estimate != null)
          _MetricRow(
            label: 'Estimated Zone 2',
            value: summary.zone2Estimate!.isRange
                ? '${summary.zone2Estimate!.lowerWatts}-${summary.zone2Estimate!.upperWatts} W'
                : '${summary.zone2Estimate!.lowerWatts} W',
          ),
        if (summary.zone2Estimate != null)
          _MetricRow(
            label: 'Confidence',
            value: summary.zone2Estimate!.confidence,
          ),
        if (summary.interpretation != null) ...[
          const SizedBox(height: 6),
          Text(summary.interpretation!),
        ],
        if (summary.zone2Estimate != null) ...[
          const SizedBox(height: 6),
          Text(summary.zone2Estimate!.interpretation),
        ],
      ],
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
    final isConnected = status == ConnectionStatus.connected;
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
                Chip(
                  label: Text(isConnected ? 'Connected' : 'Disconnected'),
                  backgroundColor: isConnected
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                ),
              ],
            ),
            if (selectedDeviceId != null) ...[
              const SizedBox(height: 8),
              Text('Saved device: $selectedDeviceId'),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: isScanning ? null : () => onScan(),
                  child: Text(isScanning ? 'Scanning...' : 'Scan'),
                ),
                FilledButton(
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
