import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'application/connect/connect_setup_controller.dart';
import 'application/connect/connect_setup_state.dart';
import 'application/session/workout_session_controller.dart';
import 'application/session/workout_session_state.dart';
import 'app/providers.dart';
import 'debug/mock_workout_debug_controller.dart';
import 'domain/models/ble_device_info.dart';
import 'domain/models/connection_status.dart';
import 'domain/models/workout_config.dart';
import 'domain/models/workout_summary.dart';
import 'domain/models/workout_type.dart';

const String _placeholderSupportEmail = 'support@example.com';
const String _placeholderPrivacyUrl = 'https://example.com/privacy-policy';
const String _appDisplayName = 'Zone 2 Cycling by Heart';

enum _AppMenuAction {
  support,
  hrErgInfo,
  powerErgInfo,
  zone2AssessmentInfo,
  exportDiagnostics,
  appInfo,
}

class HrmErgApp extends StatelessWidget {
  const HrmErgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appDisplayName,
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
  bool _showWorkoutSetup = true;

  @override
  void initState() {
    super.initState();
    _startingWattsController = TextEditingController(text: '70');
    _targetHrController = TextEditingController(text: '112');
    _durationHoursController = TextEditingController(text: '1');
    _durationMinutesController = TextEditingController(text: '0');
    _powerErgPowerController = TextEditingController(text: '140');
    _powerErgMaxHrController = TextEditingController(text: '125');
    _powerErgDurationHoursController = TextEditingController(text: '1');
    _powerErgDurationMinutesController = TextEditingController(text: '0');
    _assessmentPowerController = TextEditingController(text: '180');
    _mockSteadyHrController = TextEditingController(text: '135');
    _startingWattsController.addListener(_handleStartingWattsChanged);
    _targetHrController.addListener(_handleTargetHrChanged);
    _durationHoursController.addListener(_handleHrErgDurationChanged);
    _durationMinutesController.addListener(_handleHrErgDurationChanged);
    _powerErgPowerController.addListener(_handlePowerErgTargetPowerChanged);
    _powerErgMaxHrController.addListener(_handlePowerErgMaxHrChanged);
    _powerErgDurationHoursController.addListener(
      _handlePowerErgDurationChanged,
    );
    _powerErgDurationMinutesController.addListener(
      _handlePowerErgDurationChanged,
    );
    _assessmentPowerController.addListener(_handleAssessmentPowerChanged);
    _loadSavedWorkoutDefaults();
  }

  @override
  void dispose() {
    _startingWattsController.removeListener(_handleStartingWattsChanged);
    _targetHrController.removeListener(_handleTargetHrChanged);
    _durationHoursController.removeListener(_handleHrErgDurationChanged);
    _durationMinutesController.removeListener(_handleHrErgDurationChanged);
    _powerErgPowerController.removeListener(_handlePowerErgTargetPowerChanged);
    _powerErgMaxHrController.removeListener(_handlePowerErgMaxHrChanged);
    _powerErgDurationHoursController.removeListener(
      _handlePowerErgDurationChanged,
    );
    _powerErgDurationMinutesController.removeListener(
      _handlePowerErgDurationChanged,
    );
    _assessmentPowerController.removeListener(_handleAssessmentPowerChanged);
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
    final sessionController = ref.read(
      workoutSessionControllerProvider.notifier,
    );
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
    ref.listen(workoutSessionControllerProvider, (previous, next) {
      if (previous?.isRunning != true && next.isRunning && _showWorkoutSetup) {
        setState(() {
          _showWorkoutSetup = false;
        });
      }

      if (previous?.isRunning == true &&
          !next.isRunning &&
          !_showWorkoutSetup) {
        setState(() {
          _showWorkoutSetup = true;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(_appDisplayName),
        actions: [
          PopupMenuButton<_AppMenuAction>(
            onSelected: (action) {
              unawaited(_handleAppMenuAction(action, connectState));
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.support,
                child: Text('Support'),
              ),
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.hrErgInfo,
                child: Text('About HR-ERG'),
              ),
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.powerErgInfo,
                child: Text('About Power-ERG'),
              ),
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.zone2AssessmentInfo,
                child: Text('About Zone 2 Assessment'),
              ),
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.exportDiagnostics,
                child: Text('Export diagnostics'),
              ),
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.appInfo,
                child: Text('App info'),
              ),
            ],
          ),
        ],
      ),
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
          _buildBleReadinessCard(
            context,
            connectState: connectState,
            connectController: connectController,
          ),
          if (connectState.readinessChecked &&
              (!connectState.permissionsGranted ||
                  !connectState.bluetoothEnabled))
            const SizedBox(height: 16),
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

  Future<void> _handleAppMenuAction(
    _AppMenuAction action,
    ConnectSetupState connectState,
  ) async {
    switch (action) {
      case _AppMenuAction.support:
        return _showSupportSheet(connectState);
      case _AppMenuAction.hrErgInfo:
        return _showWorkoutInfoSheet(WorkoutType.hrErg);
      case _AppMenuAction.powerErgInfo:
        return _showWorkoutInfoSheet(WorkoutType.powerErg);
      case _AppMenuAction.zone2AssessmentInfo:
        return _showWorkoutInfoSheet(WorkoutType.zone2Assessment);
      case _AppMenuAction.exportDiagnostics:
        return _exportDiagnostics();
      case _AppMenuAction.appInfo:
        return _showAppInfoSheet();
    }
  }

  Future<void> _showSupportSheet(ConnectSetupState connectState) async {
    final appInfo = ref.read(appInfoProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Support',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('Version: ${appInfo.versionLabel}'),
                  const SizedBox(height: 8),
                  Text(
                    'Saved HR monitor: ${_savedDeviceSummary(connectState.selectedHrName, connectState.selectedHrId)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved trainer: ${_savedDeviceSummary(connectState.selectedTrainerName, connectState.selectedTrainerId)}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Export diagnostics includes recent runtime events and the last 20 workout sessions. BLE names and IDs are only included if you explicitly export the file.',
                  ),
                  const SizedBox(height: 12),
                  const Text('Support email: $_placeholderSupportEmail'),
                  const SizedBox(height: 4),
                  const Text('Privacy policy: $_placeholderPrivacyUrl'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_exportDiagnostics());
                    },
                    child: const Text('Export diagnostics'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAppInfoSheet() async {
    final appInfo = ref.read(appInfoProvider);
    final diagnosticsStore = ref.read(diagnosticsStoreProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App info',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('App: ${appInfo.appName}'),
                Text('Package: ${appInfo.packageName}'),
                Text('Version: ${appInfo.versionLabel}'),
                Text('Platform: ${appInfo.platform}'),
                Text('OS: ${appInfo.operatingSystemVersion}'),
                Text('Phone model: ${appInfo.phoneModel}'),
                if (appInfo.androidApiLevel != null)
                  Text('Android API: ${appInfo.androidApiLevel}'),
                const SizedBox(height: 8),
                Text(
                  'Diagnostics path: ${diagnosticsStore.rootPath ?? 'in-memory only'}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorkoutInfoSheet(WorkoutType type) async {
    final info = _workoutInfo(type);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info.title,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    info.summary,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  for (final paragraph in info.paragraphs) ...[
                    const SizedBox(height: 12),
                    Text(paragraph),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportDiagnostics() async {
    final exporter = ref.read(diagnosticsExporterProvider);
    final telemetry = ref.read(appTelemetryProvider);
    final diagnosticsStore = ref.read(diagnosticsStoreProvider);

    unawaited(
      telemetry.track(
        'diagnostics_export_attempt',
        properties: const <String, Object?>{'trigger': 'support_menu'},
      ),
    );
    unawaited(
      diagnosticsStore.recordRuntimeEvent(
        'diagnostics_export_attempt',
        data: const <String, Object?>{'trigger': 'support_menu'},
      ),
    );

    try {
      final exportFile = await exporter.buildExportFile();
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(exportFile.path)],
          subject: '$_appDisplayName diagnostics export',
          text:
              '$_appDisplayName diagnostics export. This file is only created after explicit user action.',
        ),
      );
      unawaited(
        telemetry.track(
          'diagnostics_export_result',
          properties: <String, Object?>{
            'trigger': 'support_menu',
            'result': result.status.name,
          },
        ),
      );
      unawaited(
        diagnosticsStore.recordRuntimeEvent(
          'diagnostics_export_result',
          data: <String, Object?>{
            'trigger': 'support_menu',
            'result': result.status.name,
            'file_path': exportFile.path,
          },
        ),
      );

      if (!mounted) {
        return;
      }
      final message = switch (result.status) {
        ShareResultStatus.success => 'Diagnostics ready to share.',
        ShareResultStatus.dismissed =>
          'Share sheet dismissed. The diagnostics file is still saved locally.',
        ShareResultStatus.unavailable =>
          'Share result unavailable. The diagnostics file is still saved locally.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      unawaited(
        telemetry.recordError(
          Exception('diagnostics_export_failed'),
          stackTrace,
          reason: 'diagnostics_export_failed',
          properties: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
      unawaited(
        diagnosticsStore.recordRuntimeEvent(
          'diagnostics_export_failed',
          data: <String, Object?>{'error': error.toString()},
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to export diagnostics right now.'),
        ),
      );
    }
  }

  String _savedDeviceSummary(String? name, String? id) {
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    if (id != null && id.trim().isNotEmpty) {
      return id;
    }
    return 'Not selected';
  }

  _WorkoutInfoContent _workoutInfo(WorkoutType type) {
    switch (type) {
      case WorkoutType.hrErg:
        return const _WorkoutInfoContent(
          title: 'About HR-ERG',
          summary:
              'A heart-rate driven endurance ride that adjusts trainer power to keep you near your target HR.',
          paragraphs: <String>[
            'HR-ERG is the most heart-rate-driven workout in the app. You choose a starting wattage, a target heart rate, and a ride duration. The ride begins at your chosen starting power and then the trainer is adjusted over time to steer your effort toward the selected heart-rate target.',
            'The controller uses a 10-second rolling heart-rate average and a 5-second control loop. That means the app smooths out noisy beat-to-beat changes before deciding whether to nudge power up or down. If your average heart rate sits below target, resistance can rise. If it drifts above target, resistance can back off.',
            'This mode is designed for steady aerobic work where heart rate is the main anchor rather than a fixed watt target. It is especially useful on days when fatigue, temperature, hydration, or accumulated training load make your usual power numbers less reliable than your actual physiological response.',
            'During the final 5 minutes, the workout moves into cooldown and the target is lowered to an easy recovery level. If fresh heart-rate data disappears or the trainer connection becomes unstable, the workout pauses until the signal is usable again.',
          ],
        );
      case WorkoutType.powerErg:
        return const _WorkoutInfoContent(
          title: 'About Power-ERG',
          summary:
              'A structured ERG workout with a target power, warmup ramp, and heart-rate ceiling.',
          paragraphs: <String>[
            'Power-ERG is built around a power target, but it still watches heart rate to stop the session from getting too expensive aerobically. You set a target power, a maximum heart rate, and the active ride duration.',
            'The workout starts with a 10-minute warmup ramp from 50% of target power up to 100%. It then holds the target power for the chosen duration, followed by a 5-minute cooldown at 60% of target power.',
            'While you are in the active block, the app checks your rolling heart-rate average. If heart rate rises above the maximum you set, the app gradually reduces power at a fixed rate until heart rate settles back under the cap. This lets you aim at a power target without ignoring what your body is telling you that day.',
            'Use Power-ERG when you want a more structured session than HR-ERG, but still want protection against drifting too far above your intended aerobic range.',
          ],
        );
      case WorkoutType.zone2Assessment:
        return const _WorkoutInfoContent(
          title: 'About Zone 2 Assessment',
          summary:
              'A fixed protocol designed to help you judge aerobic durability and steady-state tolerance.',
          paragraphs: <String>[
            'Zone 2 Assessment is the most standardized workout in the app. You choose one assessment power and then complete a fixed 90-minute protocol so the summary can evaluate how stable your heart-rate response stays over a long steady ride.',
            'The protocol is a 10-minute ramp from 50% of assessment power to 100%, followed by 75 minutes at the chosen power, then a 5-minute cooldown at 60%. Because the structure is fixed, the post-ride summary can compare early and late portions of the session more consistently than in a freer ride.',
            'This mode is useful when you want to test whether a steady power still behaves like true Zone 2 for you. If heart rate drifts upward too much over time, the workout summary can help you see that the effort may be too high for long aerobic work.',
            'For the cleanest result, use a power that you believe is near your upper steady aerobic range and aim to complete the session without interruptions. If heart-rate or trainer data goes stale, the app pauses until the signal is stable again.',
          ],
        );
    }
  }

  bool _canStartWorkout({
    required WorkoutType selectedType,
    required connectState,
    required bool isRunning,
  }) {
    if (isRunning) {
      return false;
    }
    if (!connectState.permissionsGranted || !connectState.bluetoothEnabled) {
      return false;
    }
    return connectState.hrStatus == ConnectionStatus.connected &&
        connectState.trainerStatus == ConnectionStatus.connected;
  }

  Widget _buildBleReadinessCard(
    BuildContext context, {
    required ConnectSetupState connectState,
    required ConnectSetupController connectController,
  }) {
    if (!connectState.readinessChecked ||
        (connectState.permissionsGranted && connectState.bluetoothEnabled)) {
      return const SizedBox.shrink();
    }

    final String title;
    final String body;
    final List<Widget> actions;

    if (!connectState.permissionsGranted) {
      title = 'Bluetooth Access Needed';
      body = connectState.permissionPermanentlyDenied
          ? 'Bluetooth permissions are blocked. Open system settings, grant access, then return here.'
          : 'Bluetooth permissions are required before the app can scan, reconnect, or start a ride.';
      actions = <Widget>[
        FilledButton(
          onPressed: connectState.permissionPermanentlyDenied
              ? connectController.openSystemSettings
              : connectController.requestBleAccess,
          child: Text(
            connectState.permissionPermanentlyDenied
                ? 'Open settings'
                : 'Grant access',
          ),
        ),
        if (connectState.permissionPermanentlyDenied)
          OutlinedButton(
            onPressed: connectController.refreshBleReadiness,
            child: const Text('Check again'),
          ),
      ];
    } else {
      title = 'Bluetooth Is Off';
      body =
          'Turn Bluetooth on in Android settings, then tap Check again before scanning or reconnecting devices.';
      actions = <Widget>[
        FilledButton(
          onPressed: connectController.refreshBleReadiness,
          child: const Text('Check again'),
        ),
      ];
    }

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
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
              onTap: () =>
                  _selectWorkoutType(sessionController, WorkoutType.hrErg),
            ),
            const SizedBox(height: 8),
            _WorkoutTypeOption(
              label: 'Power-ERG',
              selected: selectedType == WorkoutType.powerErg,
              onTap: () =>
                  _selectWorkoutType(sessionController, WorkoutType.powerErg),
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

  Future<void> _selectWorkoutType(
    WorkoutSessionController sessionController,
    WorkoutType type,
  ) async {
    sessionController.selectWorkoutType(type);
    await _saveSelectedWorkoutType(type);
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
      selectedDeviceName: connectState.selectedHrName,
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
      onDisconnect: connectController.disconnectHrMonitor,
      onConnect: connectController.connectHrMonitor,
      helperText:
          'HR straps can take a couple of scans to wake up. Wear the strap first and moisten the contacts if it does not appear right away.',
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
      selectedDeviceName: connectState.selectedTrainerName,
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
      onDisconnect: connectController.disconnectTrainer,
      onConnect: connectController.connectTrainer,
      helperText:
          'If the trainer connects but shows no response, wait a moment and try Reconnect saved once.',
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
      children: [hrSection, const SizedBox(height: 16), trainerSection],
    );
  }

  Widget _buildSetupCard(
    BuildContext context, {
    required WorkoutType selectedType,
    required bool canStart,
    required WorkoutSessionState sessionState,
    required sessionController,
  }) {
    final showSetupDetails = _showWorkoutSetup || !sessionState.isRunning;
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
                    onPressed: () async {
                      setState(() {
                        _showWorkoutSetup = true;
                      });
                      await sessionController.stopWorkout();
                    },
                    child: const Text('Stop'),
                  ),
              ],
            ),
            if (showSetupDetails) ...[
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
            ],
            if (sessionState.error != null) ...[
              const SizedBox(height: 12),
              Text(
                sessionState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (showSetupDetails) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: canStart
                      ? () => _startWorkout(selectedType)
                      : null,
                  child: const Text('Start'),
                ),
              ),
            ],
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
        sessionState.provisionalSummary == null &&
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
              value: sessionState.currentHr == null || !sessionState.hrFresh
                  ? '--'
                  : '${sessionState.currentHr} bpm',
            ),
            if (sessionState.targetHr != null)
              _MetricRow(
                label: sessionState.selectedWorkoutType == WorkoutType.powerErg
                    ? 'Max HR'
                    : 'Target HR',
                value: '${sessionState.targetHr} bpm',
              ),
            _MetricRow(
              label: 'Power (10s avg)',
              value: sessionState.displayPower == null
                  ? '--'
                  : '${sessionState.displayPower} W',
            ),
            if (sessionState.currentCadence != null)
              _MetricRow(
                label: 'Cadence',
                value: '${sessionState.currentCadence} rpm',
              ),
            if (sessionState.selectedWorkoutType == WorkoutType.powerErg &&
                sessionState.activeConfig is PowerErgConfig)
              _MetricRow(
                label: 'Target Power',
                value:
                    '${(sessionState.activeConfig as PowerErgConfig).targetPower} W',
              ),
            if (sessionState.provisionalSummary != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                sessionState.selectedWorkoutType == WorkoutType.powerErg
                    ? 'Provisional Aerobic Drift'
                    : 'Provisional Durability',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _SummaryContent(
                summary: sessionState.provisionalSummary!,
                colorizeInterpretation: true,
                showPowerFade:
                    sessionState.selectedWorkoutType != WorkoutType.powerErg,
              ),
            ],
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
            ] else if (sessionState.selectedWorkoutType ==
                    WorkoutType.powerErg &&
                sessionState.isRunning) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: sessionState.activeConfig is! PowerErgConfig
                        ? null
                        : () => sessionController.updatePowerErgTargetPower(
                            (sessionState.activeConfig as PowerErgConfig)
                                    .targetPower -
                                5,
                          ),
                    child: const Text('Power -5'),
                  ),
                  OutlinedButton(
                    onPressed: sessionState.activeConfig is! PowerErgConfig
                        ? null
                        : () => sessionController.updatePowerErgTargetPower(
                            (sessionState.activeConfig as PowerErgConfig)
                                    .targetPower +
                                5,
                          ),
                    child: const Text('Power +5'),
                  ),
                ],
              ),
            ],
            if (sessionState.summary != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                sessionState.selectedWorkoutType == WorkoutType.powerErg
                    ? 'Power-ERG Result'
                    : 'Summary',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _SummaryContent(
                summary: sessionState.summary!,
                colorizeInterpretation:
                    sessionState.selectedWorkoutType == WorkoutType.powerErg,
                showPowerFade:
                    sessionState.selectedWorkoutType != WorkoutType.powerErg,
              ),
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
                OutlinedButton(
                  onPressed: mockController.pauseTrainerTelemetry,
                  child: const Text('Trainer Stall'),
                ),
                OutlinedButton(
                  onPressed: mockController.resumeTrainerTelemetry,
                  child: const Text('Trainer Resume'),
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
    final sessionController = ref.read(
      workoutSessionControllerProvider.notifier,
    );
    await _saveSelectedWorkoutType(selectedType);
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

    final assessmentPower = int.tryParse(
      _assessmentPowerController.text.trim(),
    );
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

  Future<void> _loadSavedWorkoutDefaults() async {
    final store = ref.read(deviceSelectionStoreProvider);
    final savedStartingWatts = await store.getHrErgStartingWatts();
    final savedTargetHr = await store.getHrErgTargetHr();
    final savedHrErgDurationHours = await store.getHrErgDurationHours();
    final savedHrErgDurationMinutes = await store.getHrErgDurationMinutes();
    final savedPowerErgTargetPower = await store.getPowerErgTargetPower();
    final savedPowerErgMaxHr = await store.getPowerErgMaxHr();
    final savedPowerErgDurationHours = await store.getPowerErgDurationHours();
    final savedPowerErgDurationMinutes = await store
        .getPowerErgDurationMinutes();
    final savedAssessmentPower = await store.getAssessmentPower();
    final savedWorkoutTypeName = await store.getSelectedWorkoutType();
    if (!mounted) {
      return;
    }

    if (savedStartingWatts != null && savedStartingWatts > 0) {
      _startingWattsController.text = '$savedStartingWatts';
    }
    if (savedTargetHr != null && savedTargetHr > 0) {
      _targetHrController.text = '$savedTargetHr';
    }
    if (savedHrErgDurationHours != null && savedHrErgDurationHours >= 0) {
      _durationHoursController.text = '$savedHrErgDurationHours';
    }
    if (savedHrErgDurationMinutes != null &&
        savedHrErgDurationMinutes >= 0 &&
        savedHrErgDurationMinutes <= 59) {
      _durationMinutesController.text = '$savedHrErgDurationMinutes';
    }
    if (savedPowerErgTargetPower != null && savedPowerErgTargetPower > 0) {
      _powerErgPowerController.text = '$savedPowerErgTargetPower';
    }
    if (savedPowerErgMaxHr != null && savedPowerErgMaxHr > 0) {
      _powerErgMaxHrController.text = '$savedPowerErgMaxHr';
    }
    if (savedPowerErgDurationHours != null && savedPowerErgDurationHours >= 0) {
      _powerErgDurationHoursController.text = '$savedPowerErgDurationHours';
    }
    if (savedPowerErgDurationMinutes != null &&
        savedPowerErgDurationMinutes >= 0 &&
        savedPowerErgDurationMinutes <= 59) {
      _powerErgDurationMinutesController.text = '$savedPowerErgDurationMinutes';
    }
    if (savedAssessmentPower != null && savedAssessmentPower > 0) {
      _assessmentPowerController.text = '$savedAssessmentPower';
    }

    final savedWorkoutType = _parseWorkoutType(savedWorkoutTypeName);
    if (savedWorkoutType != null) {
      ref
          .read(workoutSessionControllerProvider.notifier)
          .selectWorkoutType(savedWorkoutType);
      setState(() {
        _showWorkoutTypeOptions = false;
      });
    }
  }

  void _handleStartingWattsChanged() {
    final watts = int.tryParse(_startingWattsController.text.trim());
    if (watts == null || watts <= 0) {
      return;
    }
    _saveSelectedWorkoutType(WorkoutType.hrErg);
    _saveStartingWatts(watts);
  }

  void _handleTargetHrChanged() {
    final bpm = int.tryParse(_targetHrController.text.trim());
    if (bpm == null || bpm <= 0) {
      return;
    }
    _saveSelectedWorkoutType(WorkoutType.hrErg);
    _saveTargetHr(bpm);
  }

  void _handleHrErgDurationChanged() {
    final hours = int.tryParse(_durationHoursController.text.trim());
    final minutes = int.tryParse(_durationMinutesController.text.trim());
    _saveSelectedWorkoutType(WorkoutType.hrErg);
    if (hours != null && hours >= 0) {
      _saveHrErgDurationHours(hours);
    }
    if (minutes != null && minutes >= 0 && minutes <= 59) {
      _saveHrErgDurationMinutes(minutes);
    }
  }

  void _handlePowerErgTargetPowerChanged() {
    final watts = int.tryParse(_powerErgPowerController.text.trim());
    if (watts == null || watts <= 0) {
      return;
    }
    _saveSelectedWorkoutType(WorkoutType.powerErg);
    _savePowerErgTargetPower(watts);
  }

  void _handlePowerErgMaxHrChanged() {
    final bpm = int.tryParse(_powerErgMaxHrController.text.trim());
    if (bpm == null || bpm <= 0) {
      return;
    }
    _saveSelectedWorkoutType(WorkoutType.powerErg);
    _savePowerErgMaxHr(bpm);
  }

  void _handlePowerErgDurationChanged() {
    final hours = int.tryParse(_powerErgDurationHoursController.text.trim());
    final minutes = int.tryParse(
      _powerErgDurationMinutesController.text.trim(),
    );
    _saveSelectedWorkoutType(WorkoutType.powerErg);
    if (hours != null && hours >= 0) {
      _savePowerErgDurationHours(hours);
    }
    if (minutes != null && minutes >= 0 && minutes <= 59) {
      _savePowerErgDurationMinutes(minutes);
    }
  }

  void _handleAssessmentPowerChanged() {
    final watts = int.tryParse(_assessmentPowerController.text.trim());
    if (watts == null || watts <= 0) {
      return;
    }
    _saveSelectedWorkoutType(WorkoutType.zone2Assessment);
    _saveAssessmentPower(watts);
  }

  Future<void> _saveStartingWatts(int watts) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveHrErgStartingWatts(watts);
  }

  Future<void> _saveTargetHr(int bpm) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveHrErgTargetHr(bpm);
  }

  Future<void> _saveHrErgDurationHours(int hours) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveHrErgDurationHours(hours);
  }

  Future<void> _saveHrErgDurationMinutes(int minutes) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveHrErgDurationMinutes(minutes);
  }

  Future<void> _savePowerErgTargetPower(int watts) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.savePowerErgTargetPower(watts);
  }

  Future<void> _savePowerErgMaxHr(int bpm) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.savePowerErgMaxHr(bpm);
  }

  Future<void> _savePowerErgDurationHours(int hours) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.savePowerErgDurationHours(hours);
  }

  Future<void> _savePowerErgDurationMinutes(int minutes) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.savePowerErgDurationMinutes(minutes);
  }

  Future<void> _saveAssessmentPower(int watts) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveAssessmentPower(watts);
  }

  Future<void> _saveSelectedWorkoutType(WorkoutType type) async {
    final store = ref.read(deviceSelectionStoreProvider);
    await store.saveSelectedWorkoutType(type.name);
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

  WorkoutType? _parseWorkoutType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    for (final type in WorkoutType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return null;
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
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.teal.shade50 : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          unawaited(onTap());
        },
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
  const _SummaryContent({
    required this.summary,
    this.colorizeInterpretation = false,
    this.showPowerFade = true,
  });

  final WorkoutSummary summary;
  final bool colorizeInterpretation;
  final bool showPowerFade;

  @override
  Widget build(BuildContext context) {
    if (!summary.analysisAvailable) {
      return Text(summary.analysisMessage ?? 'Analysis unavailable.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPowerFade && summary.powerFadePercent != null)
          _MetricRow(
            label: 'Power Fade',
            value: '${summary.powerFadePercent!.toStringAsFixed(1)}%',
          ),
        _MetricRow(
          label: 'Aerobic Drift',
          value: '${summary.aerobicDriftPercent!.toStringAsFixed(1)}%',
          valueColor: colorizeInterpretation
              ? _durabilityColor(summary.aerobicDriftPercent)
              : null,
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
          Text(
            summary.interpretation!,
            style: colorizeInterpretation
                ? TextStyle(
                    color: _durabilityColor(summary.aerobicDriftPercent),
                    fontWeight: FontWeight.w700,
                  )
                : null,
          ),
        ],
        if (summary.zone2Estimate != null) ...[
          const SizedBox(height: 6),
          Text(summary.zone2Estimate!.interpretation),
        ],
      ],
    );
  }

  Color? _durabilityColor(double? driftPercent) {
    if (driftPercent == null) {
      return null;
    }
    if (driftPercent < 3) {
      return Colors.green.shade700;
    }
    if (driftPercent <= 5) {
      return Colors.orange.shade800;
    }
    return Colors.red.shade700;
  }
}

class _WorkoutInfoContent {
  const _WorkoutInfoContent({
    required this.title,
    required this.summary,
    required this.paragraphs,
  });

  final String title;
  final String summary;
  final List<String> paragraphs;
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.title,
    required this.status,
    required this.selectedDeviceId,
    required this.selectedDeviceName,
    required this.devices,
    required this.isScanning,
    required this.error,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onScan,
    required this.onReconnectSaved,
    required this.onDisconnect,
    required this.onConnect,
    this.helperText,
    this.compact = false,
  });

  final String title;
  final ConnectionStatus status;
  final String? selectedDeviceId;
  final String? selectedDeviceName;
  final List<BleDeviceInfo> devices;
  final bool isScanning;
  final String? error;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onScan;
  final Future<void> Function() onReconnectSaved;
  final Future<void> Function() onDisconnect;
  final Future<void> Function(String deviceId) onConnect;
  final String? helperText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isConnected = status == ConnectionStatus.connected;
    final canDisconnect =
        selectedDeviceId != null &&
        status != ConnectionStatus.disconnected &&
        !isScanning;
    final showDetails = !isConnected || isExpanded;
    final compactChipLabel = title == 'HR Monitor'
        ? 'HR-Connected'
        : 'TR-Connected';
    final statusLabel = compact && isConnected
        ? compactChipLabel
        : _statusLabel(title, status);
    final statusColor = _statusColor(status);
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
                if (compact)
                  Expanded(
                    child: InkWell(
                      onTap: onToggleExpanded,
                      borderRadius: BorderRadius.circular(999),
                      child: _CompactStatusPill(
                        label: statusLabel,
                        backgroundColor: statusColor,
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: onToggleExpanded,
                    borderRadius: BorderRadius.circular(999),
                    child: Chip(
                      label: Text(statusLabel),
                      backgroundColor: statusColor,
                    ),
                  ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              if (selectedDeviceId != null) ...[
                Text('Saved device: ${_savedDeviceLabel()}'),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                  OutlinedButton(
                    onPressed: canDisconnect ? () => onDisconnect() : null,
                    child: const Text('Disconnect'),
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
              if (helperText != null && helperText!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  helperText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (devices.isEmpty)
                Text(
                  title == 'HR Monitor'
                      ? 'No devices yet. Tap Scan and give the strap a few seconds to wake up.'
                      : 'No devices yet. Tap Scan.',
                )
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

  String _statusLabel(String title, ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.scanning:
        return 'Scanning';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.connectedNoData:
        return title == 'HR Monitor'
            ? 'Connected (no HR data)'
            : 'Connected (no response)';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting';
    }
  }

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green.shade100;
      case ConnectionStatus.connectedNoData:
        return Colors.amber.shade100;
      case ConnectionStatus.scanning:
        return Colors.blue.shade100;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return Colors.orange.shade100;
      case ConnectionStatus.disconnected:
        return Colors.red.shade100;
    }
  }

  String _savedDeviceLabel() {
    final friendlyName = selectedDeviceName?.trim();
    if (friendlyName != null && friendlyName.isNotEmpty) {
      return friendlyName;
    }
    return selectedDeviceId ?? '';
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({
    required this.label,
    required this.backgroundColor,
  });

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
