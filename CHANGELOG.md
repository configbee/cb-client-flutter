## 0.0.1-alpha.1

* Fix: Use browser native HTTP cache on web instead of in-memory MemCacheStore, enabling persistent caching across page refreshes via CDN Cache-Control headers.
* Fix: Call `WidgetsFlutterBinding.ensureInitialized()` before `ConfigbeeClient.init()` in example app.
* Refactor: Simplify example app using `ConfigbeeProvider`, `ConfigbeeBuilder`, and `ConfigbeeFlag` widgets.

## 0.0.1-alpha.0

* Initial alpha release.
