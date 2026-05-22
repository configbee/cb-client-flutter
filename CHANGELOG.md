## 0.0.2

* Feat: SDK-managed rollouts via content modifiers — supports `PERCENTAGE_HASH`, `ASSIGNMENT_MATCH`, `MATCH_ANY`, and `MATCH_ALL` modifier evaluation.
* Feat: SDK tracing — sends `client-ready`, `stream-connected`, and `client-state-updated` events to the trace endpoint with a persistent `visitorId`.
* Fix: Resolve Flutter analyzer warnings (`catchError` return type, pubspec dependency sort order).

## 0.0.1

* **Initial Release:** Official promotion out of alpha.
* **Core Features:** Includes `ConfigbeeProvider`, `ConfigbeeBuilder`, and `ConfigbeeFlag` widgets for remote configuration.
* **Platform Support:** Full Web and Mobile support out of the box, featuring native browser HTTP caching and optimized conditional imports.

## 0.0.1-alpha.2

* fix(web): using conditional import for path_provider. This marks Web platform support in pub.dev

## 0.0.1-alpha.1

* Fix: Use browser native HTTP cache on web instead of in-memory MemCacheStore, enabling persistent caching across page refreshes via CDN Cache-Control headers.
* Fix: Call `WidgetsFlutterBinding.ensureInitialized()` before `ConfigbeeClient.init()` in example app.
* Refactor: Simplify example app using `ConfigbeeProvider`, `ConfigbeeBuilder`, and `ConfigbeeFlag` widgets.

## 0.0.1-alpha.0

* Initial alpha release.
