class EventEmitter {
  final Map<String, List<Function>> _callbacks = {};

  void on(String event, Function callback) {
    (_callbacks[event] ??= []).add(callback);
  }

  void off(String event, Function callback) {
    _callbacks[event]?.remove(callback);
  }

  void emit(String event, [dynamic data]) {
    final cbs = _callbacks[event];
    if (cbs != null) {
      for (final cb in List.from(cbs)) {
        try {
          cb(data);
        } catch (_) {}
      }
    }
  }

  void clear() => _callbacks.clear();
}
