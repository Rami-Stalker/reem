/// REST paths aligned with the Node.js backend modules.
abstract final class ApiEndpoints {
  // Auth
  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const authRefresh = '/auth/refresh-token';
  static const authLogout = '/auth/logout';
  static const authLogoutAll = '/auth/logout-all';
  static const authSocial = '/auth/social';
  static const authMe = '/auth/me';
  static const authForgotPassword = '/auth/forgot-password';
  static const authOtpRequest = '/auth/otp/request';
  static const authOtpVerify = '/auth/otp/verify';
  static const authResetPassword = '/auth/reset-password';
  static const authAccount = '/auth/account';
  static const authAccountPassword = '/auth/account/password';
  static const authAccountLink = '/auth/account/link';
  static String authAccountUnlink(String provider) =>
      '/auth/account/link/$provider';
  static const authSecurity = '/auth/security';
  static const authDevices = '/auth/devices';
  static String authDevice(String id) => '/auth/devices/$id';
  static String authTrustDevice(String id) => '/auth/devices/$id/trust';
  static const authSessions = '/auth/sessions';
  static String authSession(String id) => '/auth/sessions/$id';
  static const authSellerVerification = '/auth/seller-verification';
  static const authSellerVerificationMe = '/auth/seller-verification/me';

  // Experience metadata
  static const experienceMe = '/experience/me';

  // Users & profile
  static const usersMe = '/users/me';
  static String userById(String id) => '/users/$id';
  static String userFollow(String id) => '/users/$id/follow';
  static String userFollowers(String id) => '/users/$id/followers';
  static String userFollowing(String id) => '/users/$id/following';

  // Feed & social (customer interactions)
  static const postsFeed = '/posts/feed';
  static const postsSaved = '/posts/saved';
  static const posts = '/posts';
  static String postById(String id) => '/posts/$id';
  static String postsBySeller(String sellerId) => '/posts/seller/$sellerId';
  static String postLike(String id) => '/posts/$id/like';
  static String postSave(String id) => '/posts/$id/save';
  static String postShare(String id) => '/posts/$id/share';
  static String postComments(String id) => '/posts/$id/comments';
  static String postComment(String id, String commentId) =>
      '/posts/$id/comments/$commentId';

  // Seller — posts authoring
  static const sellerPosts = '/seller/posts';
  static String sellerPostById(String id) => '/seller/posts/$id';

  // Stories (customer)
  static const stories = '/stories';
  static String storyView(String id) => '/stories/$id/view';
  static String storyReact(String id) => '/stories/$id/react';

  // Seller — stories authoring + analytics
  static const sellerStories = '/seller/stories';
  static String sellerStoryById(String id) => '/seller/stories/$id';
  static String sellerStoryAnalytics(String id) =>
      '/seller/stories/$id/analytics';
  static String sellerStoryViewers(String id) => '/seller/stories/$id/viewers';

  // Products (public browse)
  static const products = '/products';
  static const productsTrending = '/products/trending';
  static String productById(String id) => '/products/$id';

  // Discovery (collections, recommendations, similar)
  static const discoveryHome = '/discovery/home';
  static const discoveryRecommended = '/discovery/recommended';
  static String discoveryCollection(String key) =>
      '/discovery/collections/$key';
  static String discoveryCategory(String category) =>
      '/discovery/category/$category';
  static String discoverySeller(String sellerId) =>
      '/discovery/seller/$sellerId';
  static String discoverySimilar(String productId) =>
      '/discovery/products/$productId/similar';

  // Seller — product management
  static const sellerProducts = '/seller/products';
  static String sellerProductById(String id) => '/seller/products/$id';
  static String sellerProductStatus(String id) => '/seller/products/$id/status';
  static String sellerProductStock(String id) => '/seller/products/$id/stock';
  static String sellerProductVariants(String id) =>
      '/seller/products/$id/variants';
  static String sellerProductVariant(String id, String variantId) =>
      '/seller/products/$id/variants/$variantId';

  // Search
  static const search = '/search';
  static const searchProducts = '/search/products';
  static const searchSellers = '/search/sellers';
  static const searchPosts = '/search/posts';
  static const searchSuggestions = '/search/suggestions';
  static const searchTrending = '/search/trending';
  static const searchRecent = '/search/recent';
  static String searchRecentById(String id) => '/search/recent/$id';

  // Cart
  static const cart = '/cart';
  static const cartItems = '/cart/items';
  static String cartItemById(String id) => '/cart/items/$id';

  // Delivery
  static const deliveryGovernorates = '/delivery/governorates';
  static const deliveryQuote = '/delivery/quote';

  // Payments
  static const paymentMethodsCatalog = '/payments/methods';
  static const payments = '/payments';
  static String paymentById(String id) => '/payments/$id';
  static String paymentVerify(String id) => '/payments/$id/verify';
  static String paymentRetry(String id) => '/payments/$id/retry';

  // Orders & checkout
  static const orders = '/orders';
  static const ordersCheckout = '/orders/checkout';
  static String orderById(String id) => '/orders/$id';
  static String orderTimeline(String id) => '/orders/$id/timeline';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderReorder(String id) => '/orders/$id/reorder';

  // Favorites
  static const favorites = '/favorites';
  static const favoritesOverview = '/favorites/overview';
  static const wishlistCollections = '/favorites/collections';
  static String favoriteByProduct(String productId) => '/favorites/$productId';
  static String favoriteSeller(String sellerId) =>
      '/favorites/sellers/$sellerId';
  static String favoritePost(String postId) => '/favorites/posts/$postId';
  static String wishlistCollectionItems(String collectionId) =>
      '/favorites/collections/$collectionId/items';
  static String wishlistCollectionItem(String collectionId, String itemId) =>
      '/favorites/collections/$collectionId/items/$itemId';
  static String wishlistCollectionShare(String collectionId) =>
      '/favorites/collections/$collectionId/share';
  static String wishlistShared(String token) => '/favorites/shared/$token';

  // Reputation
  static String productReviews(String productId) =>
      '/reputation/products/$productId/reviews';
  static String sellerReviews(String sellerId) =>
      '/reputation/sellers/$sellerId/reviews';
  static String sellerReputation(String sellerId) =>
      '/reputation/sellers/$sellerId';
  static const trustedSellerVerification =
      '/reputation/seller/trusted-verification';
  static const adminReviewModeration = '/reputation/admin/reviews';
  static const adminReviewModerationQueue =
      '/reputation/admin/moderation-queue';

  // AI Assistant
  static const aiProductRecommendations = '/ai/recommendations/products';
  static const aiSellerRecommendations = '/ai/recommendations/sellers';
  static const aiSearchSuggestions = '/ai/search/suggestions';
  static const aiHomeFeed = '/ai/home-feed';
  static const aiBehaviorMe = '/ai/behavior/me';
  static const aiGenerateProductDescription =
      '/ai/generate/product-description';
  static const aiGenerateTags = '/ai/generate/tags';
  static String aiSimilarProducts(String productId) =>
      '/ai/products/$productId/similar';

  // Commissions
  static const commissionSellerEarnings = '/commissions/seller/earnings';
  static const commissionSellerTransactions =
      '/commissions/seller/transactions';
  static const commissionAdminRules = '/commissions/admin/rules';
  static const commissionAdminReports = '/commissions/admin/reports';
  static const commissionAdminPayoutsCalculate =
      '/commissions/admin/payouts/calculate';
  static String commissionAdminPayout(String id) =>
      '/commissions/admin/payouts/$id';

  // Chat
  static const chats = '/chats';
  static const chatSearch = '/chats/search';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';
  static String chatRead(String chatId) => '/chats/$chatId/read';
  static String chatReports(String chatId) => '/chats/$chatId/reports';
  static String chatBlock(String userId) => '/chats/blocks/$userId';

  // Analytics & BI
  static const analyticsEvents = '/analytics/events';
  static const analyticsDashboard = '/analytics/dashboard';
  static const analyticsSales = '/analytics/sales';
  static const analyticsRevenue = '/analytics/revenue';
  static const analyticsProducts = '/analytics/products';
  static const analyticsSellers = '/analytics/sellers';
  static const analyticsCustomers = '/analytics/customers';
  static const analyticsConversion = '/analytics/conversion';
  static const analyticsFunnel = '/analytics/funnel';
  static const analyticsRetention = '/analytics/retention';
  static const analyticsCohorts = '/analytics/cohorts';
  static const analyticsRealtime = '/analytics/realtime';
  static const analyticsExport = '/analytics/export';

  // Settings
  static const addresses = '/addresses';
  static String addressById(String id) => '/addresses/$id';
  static const paymentMethods = '/payment-methods';
  static const coupons = '/coupons';
  static const rewards = '/rewards';
  static const rewardsHistory = '/rewards/history';
  static const membershipSummary = '/rewards/membership';
  static const membershipRewards = '/rewards/membership/rewards';
  static String membershipRewardRedeem(String id) =>
      '/rewards/membership/rewards/$id/redeem';
  static const cashbackRedeem = '/rewards/cashback/redeem';
  static const referralsMe = '/referrals/me';
  static const referralsApply = '/referrals/apply';
  static const referralsCodes = '/referrals/codes';
  static const referralsAnalytics = '/referrals/analytics';
  static const notifications = '/notifications';

  // Admin
  static const adminStats = '/admin/stats';
  static const adminOrders = '/admin/orders';
  static const adminProducts = '/admin/products';
  static const adminUsers = '/admin/users';
  static const adminSellers = '/admin/sellers';
  static const adminAnalytics = '/admin/analytics';
  static const adminFinancials = '/admin/financials';
  static const adminCommissions = commissionAdminReports;
  static const adminReports = '/admin/reports';
  static const adminModeration = '/admin/moderation';
  static const adminSupport = '/admin/support';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminSystemSettings = '/admin/system-settings';
  static const notificationAdminAnalytics = '/notifications/admin/analytics';
  static const notificationAdminCampaigns = '/notifications/admin/campaigns';
  static const notificationAdminDispatch = '/notifications/admin/dispatch';
  static String notificationAdminCampaignRun(String id) =>
      '/notifications/admin/campaigns/$id/run';
}
