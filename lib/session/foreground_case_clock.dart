// ignore_for_file: prefer_initializing_formals
// Public constructor arguments are intentionally held in private mutable fields.

/// An additive, monotonic foreground-only clock. Wall-clock time, UI rebuilds
/// and timers never determine accumulated solving time.
class ForegroundCaseClock {
  ForegroundCaseClock({
    Duration accumulated = Duration.zero,
    bool solved = false,
    Stopwatch Function()? makeStopwatch,
  }) : _accumulated = accumulated,
       _solved = solved,
       _makeStopwatch = makeStopwatch ?? Stopwatch.new;

  final Stopwatch Function() _makeStopwatch;
  Duration _accumulated;
  bool _solved;
  Stopwatch? _active;

  bool get isRunning => _active != null;
  bool get isSolved => _solved;
  Duration get elapsed => _accumulated + (_active?.elapsed ?? Duration.zero);

  void resume() {
    if (_solved || isRunning) return;
    _active = _makeStopwatch()..start();
  }

  void pause() {
    final active = _active;
    if (active == null) return;
    active.stop();
    _accumulated += active.elapsed;
    _active = null;
  }

  void solve() {
    pause();
    _solved = true;
  }

  void reset() {
    pause();
    _accumulated = Duration.zero;
    _solved = false;
  }
}
