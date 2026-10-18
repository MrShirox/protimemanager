import 'package:flutter/material.dart';
import '../models/chrono_entry.dart';
import '../services/work_sessions.dart';

class ChronoProvider extends ChangeNotifier {
  final WorkSessions store;
  String? error;
  bool _disposed = false;

  ChronoProvider(this.store) {
    store.addListener(_changed);
  }
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  ChronoSession? get current => store.active;
  bool get hasActive => current != null;
  bool get isPaused => current?.isPausedAt(store.now()) ?? false;
  bool get isRunning => hasActive && !isPaused;
  bool get isBusy => store.busy;
  String? get loadError => store.loadError;
  Duration get elapsed => current?.workedDuration(store.now()) ?? Duration.zero;
  int get currentPauseSecs {
    if (!isPaused) return 0;
    return store.now().difference(current!.pauses.last.start).inSeconds;
  }

  List<ChronoSession> get todaySessions => store.portions(store.now());
  int get todayWorkedMinutes => store.dayMinutes(store.now());

  Future<void> _run(Future<void> Function() operation) async {
    if (isBusy) return;
    error = null;
    try {
      await operation();
    } on WorkTimeException catch (e) {
      error = e.message;
    } catch (_) {
      error =
          'Enregistrement impossible. Réessaie : les horaires précédents sont conservés.';
    }
    _changed();
  }

  Future<void> start() => _run(store.start);
  Future<void> pause({int? minutes}) =>
      _run(() => store.pause(minutes: minutes));
  Future<void> resumePause() => _run(store.resume);
  Future<void> stop() => _run(store.stop);
  Future<void> retry() => _run(store.reload);

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_changed);
    super.dispose();
  }
}
