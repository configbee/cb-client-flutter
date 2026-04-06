import 'package:flutter/widgets.dart';
import 'client.dart';
import 'models/cb_status.dart';

// ---------------------------------------------------------------------------
// ConfigbeeProvider
// ---------------------------------------------------------------------------

/// Provides a [ConfigbeeClient] to the widget tree via [InheritedWidget].
///
/// Wrap your app (or a subtree) with this widget and access the client
/// anywhere below using [ConfigbeeProvider.of].
///
/// ```dart
/// void main() {
///   final cb = ConfigbeeClient.init(ConfigbeeClientParams(...));
///   runApp(ConfigbeeProvider(client: cb, child: const MyApp()));
/// }
/// ```
class ConfigbeeProvider extends InheritedWidget {
  final ConfigbeeClient client;

  const ConfigbeeProvider({
    required this.client,
    required super.child,
    super.key,
  });

  /// Returns the nearest [ConfigbeeClient] from the widget tree.
  /// Throws if no [ConfigbeeProvider] is found.
  static ConfigbeeClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ConfigbeeProvider>();
    assert(provider != null,
        'No ConfigbeeProvider found. Did you wrap your app with ConfigbeeProvider?');
    return provider!.client;
  }

  /// Returns the nearest [ConfigbeeClient] without subscribing to updates,
  /// or `null` if none is found.
  static ConfigbeeClient? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ConfigbeeProvider>()?.client;
  }

  @override
  bool updateShouldNotify(ConfigbeeProvider oldWidget) =>
      client != oldWidget.client;
}

// ---------------------------------------------------------------------------
// ConfigbeeBuilder
// ---------------------------------------------------------------------------

/// Rebuilds its subtree whenever the Configbee status or config values change.
///
/// Requires a [ConfigbeeProvider] ancestor, or pass [client] directly.
///
/// ```dart
/// ConfigbeeBuilder(
///   builder: (context, status, client) {
///     if (status != CbStatus.active) return const CircularProgressIndicator();
///     return Text(client.getText('welcome') ?? 'Hello!');
///   },
/// )
/// ```
class ConfigbeeBuilder extends StatefulWidget {
  final Widget Function(
      BuildContext context, CbStatus status, ConfigbeeClient client) builder;

  /// Optional explicit client. Falls back to [ConfigbeeProvider.of] if null.
  final ConfigbeeClient? client;

  const ConfigbeeBuilder({
    required this.builder,
    super.key,
    this.client,
  });

  @override
  State<ConfigbeeBuilder> createState() => _ConfigbeeBuilderState();
}

class _ConfigbeeBuilderState extends State<ConfigbeeBuilder> {
  late ConfigbeeClient _client;
  late CbStatus _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = widget.client ?? ConfigbeeProvider.of(context);
    _status = _client.status;
    _client.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _client.configStream.listen((_) {
      if (mounted) setState(() => _status = _client.status);
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _status, _client);
}

// ---------------------------------------------------------------------------
// ConfigbeeFlag
// ---------------------------------------------------------------------------

/// Shows [onEnabled] when a feature flag is `true`, [onDisabled] otherwise.
/// Automatically rebuilds on config updates.
///
/// Requires a [ConfigbeeProvider] ancestor, or pass [client] directly.
///
/// ```dart
/// ConfigbeeFlag(
///   flagKey: 'new_checkout',
///   onEnabled: const NewCheckoutPage(),
///   onDisabled: const OldCheckoutPage(),
///   onLoading: const CircularProgressIndicator(),
/// )
/// ```
class ConfigbeeFlag extends StatefulWidget {
  final String flagKey;
  final Widget onEnabled;
  final Widget onDisabled;

  /// Shown while [CbStatus] is [CbStatus.initializing]. Defaults to an empty box.
  final Widget? onLoading;

  /// Optional explicit client. Falls back to [ConfigbeeProvider.of] if null.
  final ConfigbeeClient? client;

  const ConfigbeeFlag({
    required this.flagKey,
    required this.onEnabled,
    required this.onDisabled,
    super.key,
    this.onLoading,
    this.client,
  });

  @override
  State<ConfigbeeFlag> createState() => _ConfigbeeFlagState();
}

class _ConfigbeeFlagState extends State<ConfigbeeFlag> {
  late ConfigbeeClient _client;
  late CbStatus _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = widget.client ?? ConfigbeeProvider.of(context);
    _status = _client.status;
    _client.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _client.configStream.listen((_) {
      if (mounted) setState(() => _status = _client.status);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == CbStatus.initializing) {
      return widget.onLoading ?? const SizedBox.shrink();
    }
    return (_client.getFlag(widget.flagKey) == true)
        ? widget.onEnabled
        : widget.onDisabled;
  }
}

// ---------------------------------------------------------------------------
// ConfigbeeLifecycleObserver
// ---------------------------------------------------------------------------

/// Mixin for [State] classes that want lifecycle hooks tied to the app
/// foreground/background state.
///
/// Override [onConfigbeeAppResumed] and/or [onConfigbeeAppPaused] to add
/// custom logic (e.g. force-refresh on resume).
///
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with WidgetsBindingObserver, ConfigbeeLifecycleObserver {
///   @override
///   ConfigbeeClient get configbeeClient => ConfigbeeProvider.of(context);
/// }
/// ```
mixin ConfigbeeLifecycleObserver<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  ConfigbeeClient get configbeeClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onConfigbeeAppResumed();
    } else if (state == AppLifecycleState.paused) {
      onConfigbeeAppPaused();
    }
  }

  /// Called when the app returns to the foreground. Override to add custom logic.
  void onConfigbeeAppResumed() {}

  /// Called when the app goes to the background. Override to add custom logic.
  void onConfigbeeAppPaused() {}
}
