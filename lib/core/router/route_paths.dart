abstract final class RoutePaths {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const authRequired = '/auth-required';
  static const register = '/register';
  /// The code step of the main sign-in journey.
  ///
  /// A real route rather than an imperative `Navigator.push`: GoRouter owns
  /// this app's stack and rebuilds it whenever auth state changes — which it
  /// does moments after the code is sent, when the guest session settles — and
  /// a pushed `MaterialPageRoute` is simply discarded by that rebuild. The
  /// symptom was the app bouncing back to Home with the code already sent.
  static const signInCode = '/login/code';
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
  static const phoneChange = '/security/phone';

  /// The last door, and unauthenticated by necessity: she cannot sign in, that
  /// is the whole premise of being here.
  static const accountRecovery = '/account-recovery';
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

  /// Her order queue, and one parcel inside it.
  static const sellerOrders = '/seller/orders';
  static const sellerOrderDetail = '/seller/orders/:id';
  static String sellerOrderDetailFor(String id) => '/seller/orders/$id';

  static const storyViewer = '/story-viewer';

  // Commerce
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const search = '/search';
  static const orderDetail = '/order/:id';
  static String orderDetailOf(String id) => '/order/$id';

  /// Q55/Q63 P1 — the courier's round. Guarded by an active Courier row on
  /// the backend, not by role: there is no COURIER value in UserRole.
  static const courierDay = '/courier';

  /// Q64 — the tracking code is the credential, so this needs no session.
  static const shipmentTracking = '/track/:code';
  static String shipmentTrackingOf(String code) => '/track/$code';

  /// Q51 — the documents raised against one order, and one of them.
  static const orderInvoices = '/order/:id/invoices';
  static String orderInvoicesOf(String id) => '/order/$id/invoices';
  static const invoice = '/invoice/:id';
  static String invoiceOf(String id) => '/invoice/$id';
  static const collection = '/collection/:key';
  static String collectionOf(String key) => '/collection/$key';
  static const notifications = '/notifications';
  static const addresses = '/addresses';
  static const paymentMethods = '/payment-methods';
  static const appearance = '/appearance';
  static const language = '/language';
  static const coupons = '/coupons';
  static const rewards = '/rewards';
  static const wallet = '/wallet';
  static const sellerEarnings = '/seller/earnings';

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
