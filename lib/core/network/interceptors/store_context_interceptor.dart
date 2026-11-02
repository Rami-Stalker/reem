import 'package:dio/dio.dart';

/// Which shop the signed-in account is working for right now, if any.
///
/// Set while a team member has a shop open («متاجر بشتغل فيها») and cleared
/// when she leaves it. A plain holder rather than a provider because the
/// network client is built once, outside the widget tree, and every request
/// it sends must agree on the answer.
abstract final class StoreActingContext {
  static String? _storeId;

  static String? get storeId => _storeId;

  static void enter(String storeId) => _storeId = storeId;

  static void leave() => _storeId = null;
}

/// Adds `x-ohara-store` while a shop is open, so the server runs the request
/// as that shop within her team role.
class StoreContextInterceptor extends Interceptor {
  const StoreContextInterceptor();

  static const header = 'x-ohara-store';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final store = StoreActingContext.storeId;
    if (store != null) options.headers[header] = store;
    handler.next(options);
  }
}
