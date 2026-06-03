/// REST paths aligned with the Node.js backend modules.
abstract final class ApiEndpoints {
  // Auth
  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const authRefresh = '/auth/refresh-token';
  static const authMe = '/auth/me';
  static const authForgotPassword = '/auth/forgot-password';

  // Users & profile
  static const usersMe = '/users/me';
  static String userById(String id) => '/users/$id';

  // Feed & social
  static const postsFeed = '/posts/feed';
  static const posts = '/posts';
  static String postById(String id) => '/posts/$id';
  static String postLike(String id) => '/posts/$id/like';

  // Stories
  static const stories = '/stories';

  // Products
  static const products = '/products';
  static const productsTrending = '/products/trending';
  static String productById(String id) => '/products/$id';

  // Orders
  static const orders = '/orders';
  static String orderById(String id) => '/orders/$id';

  // Favorites
  static const favorites = '/favorites';
  static String favoriteByProduct(String productId) => '/favorites/$productId';

  // Chat
  static const chats = '/chats';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';

  // Settings
  static const addresses = '/addresses';
  static String addressById(String id) => '/addresses/$id';
  static const paymentMethods = '/payment-methods';
  static const coupons = '/coupons';
  static const rewards = '/rewards';
  static const notifications = '/notifications';

  // Admin
  static const adminStats = '/admin/stats';
  static const adminOrders = '/admin/orders';
  static const adminProducts = '/admin/products';
  static const adminUsers = '/admin/users';
  static const adminAnalytics = '/admin/analytics';
}
