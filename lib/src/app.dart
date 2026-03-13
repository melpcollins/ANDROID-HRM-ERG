import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/session/workout_session_controller.dart';
import 'application/session/workout_session_state.dart';
import 'app/providers.dart';
import 'debug/mock_workout_debug_controller.dart';
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
  late final TextEditingController _powerErgPowerController;
  late final TextEditingController _powerErgMaxHrController;
  late final TextEditingController _powerErgDurationHoursController;
  late final TextEditingController _powerErgDurationMinutesController;
  late final TextEditingController _assessmentPowerController;
  late final TextEditingController _mockSteadyHrController;
  bool _showHrmDetails = true;
  bool _showTrainerDetails = true;
  bool _showWorkoutTypeOptions = true;

  @override
  void initState() {
    super.initState();
    _startingWattsController = TextEditingController(text: '70');
    _targetHrController = TextEditingController(text: '112');
    _durationHoursController = TextEditingController(text: '1');
    _durationMinutesController = TextEditingController(text: '0');
    _powerErgPowerController = TextEditingController(text: '180');
    _powerErgMaxHrController = TextEditingController(text: '150');
    _powerErgDurationHoursController = TextEditingController(text: '1');
    _powerErgDurationMinutesController = TextEditingController(text: '0');
    _assessmentPowerController = TextEditingController(text: '180');
    _mockSteadyHrController = TextEditingController(text: '135');
    _startingWattsController.addListener(_handleStartingWattsChanged);
    _targetHrController.addListener(_handleTargetHrChanged);
    _loadSavedHrErgDefaults();
  }

  @override
  void dispose() {
    _startingWattsController.removeListener(_handleStartingWattsChanged);
    _targetHrController.removeListener(_handleTargetHrChanged);
    _startingWattsController.dispose();
    _targetHrController.dispose();
    _durationHoursController.dispose();
    _durationMinutesController.dispose();
    _powerErgPowerController.dispose();
    _powerErgMaxHrController.dispose();
    _powerErgDurationHoursController.dispose();
    _powerErgDurationMinutesController.dispose();
    _assessmentPowerController.dispose();
    _mockSteadyHrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debugConfig = ref.watch(appDebugConfigProvider);
    final connectState = ref.watch(connectSetupControllerProvider);
    final connectController = ref.read(connectSetupControllerProvider.notifier);
    final sessionState = ref.watch(workoutSessionControllerProvider);
    final sessionController = ref.read(workoutSessionControllerProvider.notifier);
    MockWorkoutDebugState? mockState;
    MockWorkoutDebugController? mockController;
    if (debugConfig.useMockDevices) {
      mockState = ref.watch(mockWorkoutDebugControllerProvider);
      mockController = ref.read(mockWorkoutDebugControllerProvider.notifier);
    }

    final selectedType = sessionState.selectedWorkoutType;
    final canStart = _canStartWorkout(
      selectedType: selectedType,
      connectState: connectState,
      isRunning: sessionState.isRunning,
    );

    ref.listen(connectSetupControllerProvider, (previous, next) {
      if (previous?.hrStatus != ConnectionStatus.connected &&
          next.hrStatus == ConnectionStatus.connected &&
          _showHrmDetails) {
        setState(() {
          _showHrmDetails = false;
        });
      }

      if (previous?.trainerStatus != ConnectionStatus.connected &&
          next.trainerStatus == ConnectionStatus.connected &&
          _showTrainerDetails) {
        setState(() {
          _showTrainerDetails = false;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('HRM ERG')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (debugConfig.useMockDevices) ...[
            _buildMockControlsCard(
              context,
              mockState: mockState!,
              mockController: mockController!,
            ),
            const SizedBox(height: 16),
          ],
          _buildDeviceCards(
            context,
            connectState: connectState,
            connectController: connectController,
          ),
          const SizedBox(height: 16),
          _buildWorkoutTypeCard(
            context,
            selectedType: selectedType,
            sessionState: sessionState,
            sessionController: sessionController,
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

  bool _canStartWorkout({
    required WorkoutType selectedType,
    required connectState,
    required bool isRunning,
  }) {
    if (isRunning) {
      return false;
    }
    return connectState.hrStatus == ConnectionStatus.connected &&
        connectState.trainerStatus == ConnectionStatus.connected;
  }

  Widget _buildWorkoutTypeCard(
    BuildContext context, {
    required WorkoutType selectedType,
    required WorkoutSessionState sessionState,
    required sessionController,
  }) {
    if (!_showWorkoutTypeOptions || sessionState.isRunning) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            key: const ValueKey('selected-workout-type-row'),
            children: [
              Expanded(
                child: Text(
                  _workoutTypeLabel(selectedType),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!sessionState.isRunning)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showWorkoutTypeOptions = true;
                    });
                  },
                  child: const Text('Change'),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          key: const ValueKey('workout-type-options'),
          children: [
            _WorkoutTypeOption(
              label: 'HR-ERG',
              selected: selectedType == WorkoutType.hrErg,
              onTap: () => _selectWorkoutType(
                sessionController,
                WorkoutType.hrErg,
              ),
            ),
            const SizedBox(height: 8),
            _WorkoutTypeOption(
              label: 'Power-ERG',
              selected: selectedType == WorkoutType.powerErg,
              onTap: () => _selectWorkoutType(
                sessionController,
                WorkoutType.powerErg,
              ),
            ),
            const SizedBox(height: 8),
            _WorkoutTypeOption(
              label: 'Zone 2 Assessment',
              selected: selectedType == WorkoutType.zone2Assessment,
              onTap: () => _selectWorkoutType(
                sessionController,
                WorkoutType.zone2Assessment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectWorkoutType(
    WorkoutSessionController sessionController,
    WorkoutType type,
  ) {
    sessionController.selectWorkoutType(type);
    setState(() {
      _showWorkoutTypeOptions = false;
    });
  }

  String _workoutTypeLabel(WorkoutType type) {
    switch (type) {
      case WorkoutType.hrErg:
        return 'HR-ERG';
      case WorkoutType.powerErg:
        return 'Power-ERG';
      case WorkoutType.zone2Assessment:
        return 'Zone 2 Assessment';
    }
  }

  Widget _buildDeviceCards(
    BuildContext context, {
    required connectState,
    required connectController,
  }) {
    final hrSection = _DeviceSection(
      title: 'HR Monitor',
      status: connectState.hrStatus,
      selectedDeviceId: connectState.selectedHrId,
      devices: connectState.hrDevices,
      isScanning: connectState.scanningHr,
      error: connectState.hrError,
      isExpanded: _showHrmDetails,
      onToggleExpanded: () {
        setState(() {
          _showHrmDetails = !_showHrmDetails;
        });
      },
      onScan: connectController.scanHrMonitors,
      onReconnectSaved: connectController.reconnectHrMonitor,
      onConnect: connectController.connectHrMonitor,
      compact:
          connectState.hrStatus == ConnectionStatus.connected &&
          connectState.trainerStatus == ConnectionStatus.connected &&
          !_showHrmDetails &&
          !_showTrainerDetails,
    );

    final trainerSection = _DeviceSection(
      title: 'Trainer',
      status: connectState.trainerStatus,
      selectedDeviceId: connectState.selectedTrainerId,
      devices: connectState.trainerDevices,
      isScanning: connectState.scanningTrainer,
      error: connectState.trainerError,
      isExpanded: _showTrainerDetails,
      onToggleExpanded: () {
        setState(() {
          _showTrainerDetails = !_showTrainerDetails;
        });
      },
      onScan: connectController.scanTrainers,
      onReconnectSaved: connectController.reconnectTrainer,
      onConnect: connectController.connectTrainer,
      compact:
          connectState.hrStatus == ConnectionStatus.connected &&
          connectState.trainerStatus == ConnectionStatus.connected &&
          !_showHrmDetails &&
          !_showTrainerDetails,
    );

    final useCompactRow =
        connectState.hrStatus == ConnectionStatus.connected &&
        connectState.trainerStatus == ConnectionStatus.connected &&
        !_showHrmDetails &&
        !_showTrainerDetails;

    if (useCompactRow) {
      return Row(
        key: const ValueKey('compact-device-row'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: hrSection),
          const SizedBox(width: 12),
          Expanded(child: trainerSection),
        ],
      );
    }

    return Column(
      children: [
        hrSection,
        const SizedBox(height: 16),
        trainerSection,
      ],
    );
  }

  Widget _buildSetupCard(
    BuildContext context, {
    required WorkoutType selectedType,
    required bool canStart,
    required WorkoutSessionState sessionState,
    required sessionController,
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
              const Text('Control defaults: 10s HR average, 5s loop.'),
            ] else if (selectedType == WorkoutType.powerErg) ...[
              TextField(
                controller: _powerErgPowerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Power',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _powerErgMaxHrController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Heart Rate',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _powerErgDurationHoursController,
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
                      controller: _powerErgDurationMinutesController,
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
              const Text(
                'Protocol: 10 min ramp from 50% to 100%, then duration at 100%, 5 min at 60%. If HR rises above Max Heart Rate, power decreases by 5 W/min until HR settles back under the cap.',
              ),
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
                'Fixed protocol: 10 min ramp from 50% to 100%, 75 min at 100%, 5 min at 60%.',
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
    WorkoutSessionState sessionState,
    sessionController,
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
              label: 'HR Avg (10s)',
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
                label: sessionState.selectedWorkoutType == WorkoutType.powerErg
                    ? 'Max HR'
                    : 'Target HR',
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

  Widget _buildMockControlsCard(
    BuildContext context, {
    required MockWorkoutDebugState mockState,
    required MockWorkoutDebugController mockController,
  }) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mock Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Debug-only controls for emulator runs with USE_MOCK_DEVICES=true.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: mockController.connectHrMonitor,
                  child: const Text('Connect HR'),
                ),
                OutlinedButton(
                  onPressed: mockController.disconnectHrMonitor,
                  child: const Text('Disconnect HR'),
                ),
                OutlinedButton(
                  onPressed: mockController.connectTrainer,
                  child: const Text('Connect Trainer'),
                ),
                OutlinedButton(
                  onPressed: mockController.disconnectTrainer,
                  child: const Text('Disconnect Trainer'),
                ),
                OutlinedButton(
                  onPressed: mockController.reconnectTrainer,
                  child: const Text('Reconnect Trainer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mockSteadyHrController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mock Steady HR',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyMockSteadyHr(mockController),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    _applyMockSteadyHr(mockController);
                    mockController.emitSteadyHrNow();
                  },
                  child: const Text('Emit HR Now'),
                ),
                FilledButton(
                  onPressed: () {
                    _applyMockSteadyHr(mockController);
                    mockController.startSteadyScenario();
                  },
                  child: const Text('Steady'),
                ),
                FilledButton(
                  onPressed: () {
                    _applyMockSteadyHr(mockController);
                    mockController.startSlowRiseScenario();
                  },
                  child: const Text('Slow Rise'),
                ),
                FilledButton(
                  onPressed: () {
                    _applyMockSteadyHr(mockController);
                    mockController.startDropoutScenario();
                  },
                  child: const Text('Dropout'),
                ),
                OutlinedButton(
                  onPressed: mockController.reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Scenario: ${_scenarioLabel(mockState.scenario)}'),
            const SizedBox(height: 4),
            Text(mockState.statusMessage),
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
          loopSeconds: 5,
          duration: Duration(hours: durationHours, minutes: durationMinutes),
        ),
      );
      setState(() {
        _showWorkoutTypeOptions = false;
      });
      return;
    }

    if (selectedType == WorkoutType.powerErg) {
      final targetPower = int.tryParse(_powerErgPowerController.text.trim());
      final maxHr = int.tryParse(_powerErgMaxHrController.text.trim());
      final durationHours = int.tryParse(
        _powerErgDurationHoursController.text.trim(),
      );
      final durationMinutes = int.tryParse(
        _powerErgDurationMinutesController.text.trim(),
      );

      if (targetPower == null ||
          maxHr == null ||
          durationHours == null ||
          durationMinutes == null ||
          targetPower <= 0 ||
          maxHr <= 0 ||
          durationHours < 0 ||
          durationMinutes < 0 ||
          durationMinutes > 59 ||
          (durationHours == 0 && durationMinutes == 0)) {
        _showInvalidInput();
        return;
      }

      await sessionController.startWorkout(
        PowerErgConfig(
          targetPower: targetPower,
          maxHr: maxHr,
          activeDuration: Duration(
            hours: durationHours,
            minutes: durationMinutes,
          ),
        ),
      );
      setState(() {
        _showWorkoutTypeOptions = false;
      });
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
    setState(() {
      _showWorkoutTypeOptions = false;
    });
  }

  void _showInvalidInput() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter valid workout values.')),
    );
  }

  Future<void> _loadSavedHrErgDefaults() async {
    final store = ref.read(deviceSelectionStoreProvider);
    final savedStartingWatts = await store.getHrErgStartingWatts();
    final savedTargetHr = await store.getHrErgTargetHr();
    if (!mounted) {
      return;
    }

    if (savedStartingWatts != null && savedStartingWatts > 0) {
      _startingWattsController.text = '$savedStartingWatts';
    }
    if (savedTargetHr != null && savedTargetHr > 0) {
      _targetHrController.text = '$savedTargetHr';
    }
  }

  void _handleStartingWattsChanged() {
    final watts = int.tryParse(_startingWattsController.text.trim());
    if (watts == null || watts <= 0) {
      return;
    }
    _saveStartingWatts(watts);
  }

  void _handleTargetHrChanged() {
    final bpm = int.tryParse(_targetHrController.text.trim());
    if (bpm == null || bpm <= 0) {
      return;
    }
    _saveTargetHr(bpm);
  }

  Future<void> _saveStartingWatts(int watts) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveHrErgStartingWatts(watts);
  }

  Future<void> _saveTargetHr(int bpm) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveHrErgTargetHr(bpm);
  }

  void _applyMockSteadyHr(MockWorkoutDebugController mockController) {
    final bpm = int.tryParse(_mockSteadyHrController.text.trim());
    if (bpm == null || bpm <= 0) {
      _showInvalidInput();
      return;
    }
    mockController.setSteadyHr(bpm);
  }

  String _scenarioLabel(MockHrScenario scenario) {
    switch (scenario) {
      case MockHrScenario.idle:
        return 'Idle';
      case MockHrScenario.steady:
        return 'Steady';
      case MockHrScenario.slowRise:
        return 'Slow rise';
      case MockHrScenario.dropout:
        return 'Dropout';
    }
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

class _WorkoutTypeOption extends StatelessWidget {
  const _WorkoutTypeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.teal.shade50 : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Colors.teal
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: Colors.teal)
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
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
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onScan,
    required this.onReconnectSaved,
    required this.onConnect,
    this.compact = false,
  });

  final String title;
  final ConnectionStatus status;
  final String? selectedDeviceId;
  final List<BleDeviceInfo> devices;
  final bool isScanning;
  final String? error;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onScan;
  final Future<void> Function() onReconnectSaved;
  final Future<void> Function(String deviceId) onConnect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isConnected = status == ConnectionStatus.connected;
    final showDetails = !isConnected || isExpanded;
    final compactChipLabel = title == 'HR Monitor'
        ? 'HR-Connected'
        : 'TR-Connected';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!compact)
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (compact) const Spacer(),
                InkWell(
                  onTap: onToggleExpanded,
                  borderRadius: BorderRadius.circular(999),
                  child: Chip(
                    label: Text(
                      compact && isConnected
                          ? compactChipLabel
                          : isConnected
                          ? 'Connected'
                          : 'Disconnected',
                    ),
                    backgroundColor: isConnected
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                  ),
                ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              if (selectedDeviceId != null) ...[
                Text('Saved device: $selectedDeviceId'),
                const SizedBox(height: 8),
              ],
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
