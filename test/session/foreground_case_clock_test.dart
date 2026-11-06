import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/session/foreground_case_clock.dart';
import 'package:murdoku_app/ui/widgets/clue_panel_stub.dart';

class FakeStopwatch implements Stopwatch {
  Duration value = Duration.zero;
  bool running = false;

  void advance(Duration time) {
    if (running) value += time;
  }

  @override
  void start() => running = true;
  @override
  void stop() => running = false;
  @override
  void reset() => value = Duration.zero;
  @override
  bool get isRunning => running;
  @override
  Duration get elapsed => value;
  @override
  int get elapsedMilliseconds => value.inMilliseconds;
  @override
  int get elapsedMicroseconds => value.inMicroseconds;
  @override
  int get elapsedTicks => value.inMicroseconds;
  @override
  int get frequency => 1000000;
}

void main() {
  test('timer presentation handles zero, minutes and multi-hour durations', () {
    expect(CluePanelStub.formatElapsed(Duration.zero), '00:00');
    expect(
      CluePanelStub.formatElapsed(const Duration(minutes: 5, seconds: 2)),
      '05:02',
    );
    expect(
      CluePanelStub.formatElapsed(const Duration(hours: 2, minutes: 7)),
      '2:07:00',
    );
  });

  test('foreground only, repeated pause/resume never double counts', () {
    final watches = <FakeStopwatch>[];
    final clock = ForegroundCaseClock(
      accumulated: const Duration(seconds: 11),
      makeStopwatch: () {
        final watch = FakeStopwatch();
        watches.add(watch);
        return watch;
      },
    );
    clock.resume();
    clock.resume();
    watches.last.advance(const Duration(seconds: 3));
    expect(clock.elapsed, const Duration(seconds: 14));
    clock.pause();
    clock.pause();
    watches.last.advance(const Duration(seconds: 7));
    expect(clock.elapsed, const Duration(seconds: 14));
    clock.resume();
    watches.last.advance(const Duration(seconds: 2));
    expect(clock.elapsed, const Duration(seconds: 16));
  });

  test('solved clock freezes and new replay starts at zero', () {
    final watches = <FakeStopwatch>[];
    final clock = ForegroundCaseClock(
      makeStopwatch: () {
        final watch = FakeStopwatch();
        watches.add(watch);
        return watch;
      },
    );
    clock.resume();
    watches.last.advance(const Duration(minutes: 2));
    clock.solve();
    clock.resume();
    expect(clock.isRunning, isFalse);
    expect(clock.elapsed, const Duration(minutes: 2));
    clock.reset();
    expect(clock.elapsed, Duration.zero);
    clock.resume();
    watches.last.advance(const Duration(seconds: 5));
    expect(clock.elapsed, const Duration(seconds: 5));
  });
}
