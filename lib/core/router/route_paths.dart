abstract final class RoutePaths {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const otpVerification = '/otp-verification';

  static const home = '/home';
  static const activity = '/activity';
  static const favorites = '/favorites';
  static const settings = '/settings';
  static const profile = '/profile';
  static const accountSettings = '/account-settings';
  static const deviceManagement = '/devices';
  static const securitySettings = '/security';
  static const sellerVerification = '/seller-verification';

  static const addPost = '/add-post';
  static const addStory = '/add-story';

  static const category = '/category/:category';
  static const categories = '/categories';

  static const orders = '/orders';
  static const productDetails = '/product-details';

  static const editProfile = '/edit-profile';
  static const userProfile = '/user/:id';
  static String userProfileOf(String id) => '/user/$id';

  // Seller storefront management
  static const myProducts = '/seller/products';
  static const productForm = '/seller/products/form';
  static const sellerDashboard = '/seller/dashboard';
  static const sellerCustomers = '/seller/customers';
  static const sellerMarketing = '/seller/marketing';
  static const sellerAnalytics = '/seller/analytics';
  static const sellerStore = '/seller/store';

  static const storyViewer = '/story-viewer';

  // Commerce
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const search = '/search';
  static const orderDetail = '/order/:id';
  static String orderDetailOf(String id) => '/order/$id';
  static const collection = '/collection/:key';
  static String collectionOf(String key) => '/collection/$key';
  static const notifications = '/notifications';
  static const addresses = '/addresses';
  static const paymentMethods = '/payment-methods';
  static const appearance = '/appearance';
  static const language = '/language';
  static const coupons = '/coupons';
  static const rewards = '/rewards';

  static const likeSheet = '/like-sheet';
  static const commentSheet = '/comment-sheet';

  static const admin = '/admin';
  static const adminOrders = '/admin/orders';
  static const adminProducts = '/admin/products';
  static const adminUsers = '/admin/users';
  static const adminSellers = '/admin/sellers';
  static const adminFinancials = '/admin/financials';
  static const adminCommissions = '/admin/commissions';
  static const adminAnalytics = '/admin/analytics';
  static const adminReports = '/admin/reports';
  static const adminModeration = '/admin/moderation';
  static const adminSupport = '/admin/support';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminSystemSettings = '/admin/system-settings';
  static const adminCampaigns = '/admin/notification-campaigns';
  static const adminNotificationAnalytics = '/admin/notification-analytics';

  static const chats = '/chats';
  static const chatDetails = '/chat-details';
  static const videoCall = '/video-call';
  static const calls = '/calls';
  static const chatProfile = '/chat-profile';
  static const chatMediaGallery = '/chat-media-gallery';
  static const storyShareChat = '/story-share-chat';
}
