# ConfigBee Flutter SDK
Dynamic feature flags and configuration management for Flutter applications.

[Website](https://configbee.com) | [Documentation](https://docs.configbee.com) | [Flutter SDK Docs](https://docs.configbee.com/client-sdks/flutter/)

## About

The ConfigBee Flutter SDK lets you integrate feature flags and remote configuration into your Flutter app. Control your app's behavior without redeploying.

### Key Features

- 🚀 Easy integration with Flutter (iOS, Android, Web, Desktop)
- 🎯 User targeting with custom properties
- 🔄 Real-time feature flag updates via Server-Sent Events (SSE)
- 📊 Multiple value types (boolean flags, numbers, text, JSON)
- 🧩 Flutter-native widgets: `ConfigbeeProvider`, `ConfigbeeBuilder`, `ConfigbeeFlag`
- 💾 Local caching for offline support
- ⚡ Automatic retry and fallback mechanisms

## Status

> ⚠️ **This SDK is currently in alpha.** APIs may change before the stable release.

## Installation

```bash
flutter pub add configbee_flutter
```

> 💡 If the above doesn't install the latest version, specify it explicitly:
> ```bash
> flutter pub add 'configbee_flutter:^0.0.1-alpha.1'
> ```

## Usage

> 📖 For the full documentation, visit **[docs.configbee.com/client-sdks/flutter/](https://docs.configbee.com/client-sdks/flutter/)** [![Documentation](https://img.shields.io/badge/docs-configbee.com-blue)](https://docs.configbee.com/client-sdks/flutter/)

```dart
import 'package:configbee_flutter/configbee_flutter.dart';

void main() {
  final cb = ConfigbeeClient.init(
    ConfigbeeClientParams(
      accountId: "YOUR_ACCOUNT_ID",
      projectId: "YOUR_PROJECT_ID",
      environmentId: "YOUR_ENVIRONMENT_ID",
    ),
  );
  runApp(ConfigbeeProvider(client: cb, child: const MyApp()));
}
```

### `ConfigbeeFlag` — declarative flag-based widget switching

```dart
ConfigbeeFlag(
  flagKey: 'new_checkout_ui',
  onEnabled: const NewCheckoutPage(),
  onDisabled: const OldCheckoutPage(),
  onLoading: const CircularProgressIndicator(),
)
```

### `ConfigbeeBuilder` — reactive access to all config values

```dart
ConfigbeeBuilder(
  builder: (context, status, client) {
    if (status != CbStatus.active) return const CircularProgressIndicator();
    return Text(client.getText('welcome_message') ?? 'Welcome!');
  },
)
```

### Direct client access

```dart
final cb = ConfigbeeProvider.of(context);

bool? isEnabled = cb.getFlag('new_feature');
num? maxRetries = cb.getNumber('max_retries');
String? apiEndpoint = cb.getText('api_endpoint');
Map<String, dynamic>? theme = cb.getJson('theme_config');
```

### Targeting

```dart
// On login
cb.setTargetProperties({'user_id': '12345', 'plan': 'premium'});

// On logout
cb.unsetTargetProperties();
```

## Platform Support

| Platform | Supported |
|----------|-----------|
| Android  | ✅ |
| iOS      | ✅ |
| Web      | ✅ |
| macOS    | ✅ |
| Windows  | ✅ |
| Linux    | ✅ |

## Resources

- [Full Documentation](https://docs.configbee.com/client-sdks/flutter/)
- [ConfigBee Website](https://configbee.com)
- [ConfigBee Platform](https://platform.configbee.com)
- [NOTICE](https://github.com/configbee/cb-client-flutter/blob/main/NOTICE)
- [LICENSE](https://github.com/configbee/cb-client-flutter/blob/main/LICENSE)
