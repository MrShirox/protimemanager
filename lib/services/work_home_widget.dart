import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'work_sessions.dart';

bool get supportsWorkWidget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The Android widget reads the SQLite database itself (see
/// WorkWidgetProvider.kt) and performs its actions natively, so the app only
/// has to ask it to redraw after a change.
Future<void> refreshWorkWidget() async {
  if (!supportsWorkWidget) return;
  await HomeWidget.updateWidget(androidName: 'WorkWidgetProvider');
}

/// Refresh only after persistence changes, never once per stopwatch tick.
void connectWorkWidget(WorkSessions store) {
  if (!supportsWorkWidget) return;
  String? previous;
  Future<void> queue = Future.value();
  store.addListener(() {
    if (store.loading || store.busy || store.loadError != null) return;
    final key = store.sessions.map((s) => '${s.id}:${s.revision}').join(',');
    if (key == previous) return;
    previous = key;
    queue = queue.then((_) => refreshWorkWidget()).catchError((Object error) {
      previous = null;
      debugPrint('Widget update failed: $error');
    });
  });
}
