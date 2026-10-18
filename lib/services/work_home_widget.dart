import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'work_sessions.dart';

bool get supportsWorkWidget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

@pragma('vm:entry-point')
Future<void> workWidgetAction(Uri? uri) async {
  _actions = _actions
      .then((_) => _performWidgetAction(uri))
      .catchError((Object error) {
    debugPrint('Widget action failed: $error');
  });
  await _actions;
}

Future<void> _actions = Future.value();

Future<void> _performWidgetAction(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri?.scheme != 'protime' || uri?.host != 'work') return;
  final store = WorkSessions(startTicker: false);
  try {
    await store.ready;
    if (store.loadError != null) throw StateError(store.loadError!);
    switch (uri!.queryParameters['action']) {
      case 'start':
        await store.start();
      case 'stop':
        await store.stop();
      case 'pause':
        final minutes = int.tryParse(uri.queryParameters['minutes'] ?? '');
        if (![20, 30, 45, 50, 60].contains(minutes)) return;
        await store.pause(minutes: minutes);
      default:
        return;
    }
    await publishWorkWidget(store);
  } catch (_) {
    await HomeWidget.saveWidgetData(
        'work_error', 'Action non enregistrée. Ouvre ProTimeManager.');
    await HomeWidget.updateWidget(androidName: 'WorkWidgetProvider');
  } finally {
    store.dispose();
  }
}

Future<void> publishWorkWidget(WorkSessions store) async {
  if (!supportsWorkWidget) return;
  final session = store.active;
  final last = store.sessions.isEmpty ? null : store.sessions.last;
  await HomeWidget.saveWidgetData(
      'work_snapshot',
      jsonEncode({
        'start': (session ?? last)?.startTime.millisecondsSinceEpoch,
        'end': (session ?? last)?.endTime?.millisecondsSinceEpoch,
        'active': session != null,
        'pauseEnd': session?.isPausedAt(store.now()) == true
            ? session!.pauses.last.end?.millisecondsSinceEpoch
            : null,
      }));
  await HomeWidget.saveWidgetData('work_error', '');
  await HomeWidget.updateWidget(androidName: 'WorkWidgetProvider');
}

/// Publish only after persistence changes, never once per stopwatch tick.
void connectWorkWidget(WorkSessions store) {
  if (!supportsWorkWidget) return;
  String? previous;
  Future<void> queue = Future.value();
  store.addListener(() {
    if (store.loading || store.busy || store.loadError != null) return;
    final key = store.sessions.map((s) => '${s.id}:${s.revision}').join(',');
    if (key == previous) return;
    previous = key;
    queue =
        queue.then((_) => publishWorkWidget(store)).catchError((Object error) {
      previous = null;
      debugPrint('Widget update failed: $error');
    });
  });
}
