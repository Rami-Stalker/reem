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

  // ── The social platform ─────────────────────────────────────────────────
  //
  // `/compose` replaces `/add-post` and `/add-story` for everyone: one screen
  // that asks which format, because a post, a reel and a story are one object
  // with three shapes. The two older paths stay routed while the seller app
  // still links to them.
  static const compose = '/compose';
  static const socialFeed = '/community';
  static const reels = '/reels';
  static String contentDetailOf(String id) => '/content/$id';
  static const contentStudio = '/seller/content-studio';
  static const adminContent = '/admin/content';

  static const category = '/category/:category';

  /// One department, by slug. Assembled here for the same reason
  /// [productDetailsOf] is: the segment is easy to get wrong by hand.
  static String categoryOf(String slug) => '/category/$slug';
  static const categories = '/categories';

  static const orders = '/orders';

  /// Her orders, narrowed to one pile — `pending`, `processing`, `delivered`
  /// or `cancelled`, the same names the API filters by.
  static String ordersInBucket(String bucket) => '$orders?bucket=$bucket';
  static const productDetails = '/product-details';

  /// The product page for [id]. The id rides as a query parameter rather than
  /// a path segment, which is easy to get subtly wrong at each call site — so
  /// nobody assembles the string by hand.
  static String productDetailsOf(String id) => '$productDetails?id=$id';

  static const editProfile = '/edit-profile';
  static const userProfile = '/user/:id';
  static String userProfileOf(String id) => '/user/$id';

  /// Everything one boutique sells. Rendered by the shared collection screen,
  /// which already pages, switches shape and adds to the bag.
  static const sellerProducts = '/user/:id/products';
  static String sellerProductsOf(String id) => '/user/$id/products';

  /// The people behind a profile's counts. `kind` is `followers` or
  /// `following`.
  static const followList = '/user/:id/follows/:kind';
  static String followersOf(String id) => '/user/$id/follows/followers';
  static String followingOf(String id) => '/user/$id/follows/following';

  // Seller storefront management
  static const myProducts = '/seller/products';
  static const productForm = '/seller/products/form';
  static const sellerDashboard = '/seller/dashboard';
  static const sellerAnalytics = '/seller/analytics';
  static const sellerTrends = '/seller/trends';

  /// Seller Intelligence — phase two. Three siblings of the trends page: it
  /// says what the market is doing, these say what to do about it.
  static const sellerRadar = '/seller/radar';
  static const sellerProductIntelligence = '/seller/product-intelligence';
  static const sellerHealth = '/seller/health';

  /// What people are saying about her goods and her shop, and her public
  /// answer to it.
  static const sellerReviews = '/seller/reviews';

  /// Her return and exchange desk. `/seller/orders` shows a returning parcel;
  /// this is where the request on it is actually decided.
  static const sellerReturns = '/seller/returns';
  static String sellerReturnDetailFor(String id) => '/seller/returns/$id';
  static const sellerReturnDetail = '/seller/returns/:id';
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

  /// Reem AI Stylist. The bare path opens a new conversation; the `:id` form
  /// resumes one from her history.
  static const stylist = '/stylist';
  static const stylistConversation = '/stylist/c/:id';
  static String stylistConversationOf(String id) => '/stylist/c/$id';
  static const stylistOutfit = '/stylist/outfits/:id';
  static String stylistOutfitOf(String id) => '/stylist/outfits/$id';
  static const stylistPreferences = '/stylist/preferences';

  /// Reem Closet — her wardrobe. Everything under here is hers and hers only;
  /// there is no shareable form of any of these paths, deliberately.
  // ── Reem Market Evolution (phase four) ───────────────────────────────
  //
  // Full-screen, none of them in the shell's tab set. A bundle and a drop are
  // both *destinations* — she arrives from a card or a notification, looks at
  // one thing and leaves — and the wardrobe pages belong beside the closet
  // rather than beside the catalogue.
  static const marketBundles = '/market/bundles';
  static const marketBundle = '/market/bundles/:id';
  static String marketBundleOf(String id) => '/market/bundles/$id';
  static const marketDrops = '/market/drops';
  static const marketMissions = '/market/missions';
  static const marketWardrobe = '/market/wardrobe';
  static const marketResale = '/market/resale';
  static const sellerMarket = '/seller/market';

  static const closet = '/closet';
  static const closetToday = '/closet/today';
  static const closetLooks = '/closet/looks';
  static const closetLook = '/closet/looks/:id';
  static String closetLookOf(String id) => '/closet/looks/$id';
  static const closetItem = '/closet/items/:id';
  static String closetItemOf(String id) => '/closet/items/$id';
  static const closetAddItem = '/closet/add';
  static const closetGap = '/closet/gaps/:id';
  static String closetGapOf(String id) => '/closet/gaps/$id';

  /// Reem Rooms — Intent → Room → Decision → Purchase. The rooms list replaces
  /// the cart tab; `/cart` stays for the one-tap purchase that needs no
  /// deliberation.
  static const rooms = '/rooms';

  /// Where a shared invite lands.
  ///
  /// The slug is the credential — the server exchanges it for membership — so
  /// this sits outside the catalogue's id space and, deliberately, *before*
  /// `/rooms/:id` in the route table: `:id` is greedy and would otherwise
  /// match the literal segment `join` and try to open a room called "join".
  static const roomJoin = '/rooms/join/:slug';
  static String roomJoinOf(String slug) => '/rooms/join/$slug';

  static const room = '/rooms/:id';
  static String roomOf(String id) => '/rooms/$id';
  static const roomPlan = '/rooms/:id/plan';
  static String roomPlanOf(String id) => '/rooms/$id/plan';

  /// The options side by side, for one decision.
  static const roomCompare = '/rooms/:id/decisions/:decisionId/compare';
  static String roomCompareOf(String id, String decisionId) =>
      '/rooms/$id/decisions/$decisionId/compare';

  /// Reem Value — her standing. One screen, but the feature lives on the
  /// profile, on home, in the catalogue and in checkout; this is where she goes
  /// to read it, not where it is.
  static const value = '/value';

  /// Reem Visual Shopping. The bare path opens a new search; the `:id` form
  /// reopens one from her history — which still works after the photograph
  /// itself has been deleted, because the search is the descriptor and the
  /// matches, not the picture.
  static const visualSearch = '/visual-search';
  static const visualSearchSession = '/visual-search/s/:id';
  static String visualSearchSessionOf(String id) => '/visual-search/s/$id';

  static const orderDetail = '/order/:id';
  static String orderDetailOf(String id) => '/order/$id';

  /// Q55/Q63 P1 — the courier's round. Guarded by an active Courier row on
  /// the backend, not by role: there is no COURIER value in UserRole.
  static const courierDay = '/courier';

  /// Q64 — the tracking code is the credential, so this needs no session.
  static const shipmentTracking = '/track/:code';
  static String shipmentTrackingOf(String code) => '/track/$code';

  /// Q56 P1 — she asks for some or all of a parcel back. Keyed by seller
  /// order, not order: a two-boutique order is two parcels with two delivery
  /// dates and two windows.
  static const returnRequest = '/returns/request/:sellerOrderId';
  static String returnRequestOf(String sellerOrderId) =>
      '/returns/request/$sellerOrderId';

  /// Q51 — the documents raised against one order, and one of them.
  static const orderInvoices = '/order/:id/invoices';
  static String orderInvoicesOf(String id) => '/order/$id/invoices';
  static const invoice = '/invoice/:id';
  static String invoiceOf(String id) => '/invoice/$id';
  static const collection = '/collection/:key';
  static String collectionOf(String key) => '/collection/$key';

  /// What the shop has told her. Every bell in the app opens this.
  static const notifications = '/notifications';

  /// The toggles behind it. These used to sit on `/notifications` itself, so
  /// the four entrances that mean "read my notifications" all opened a page of
  /// switches and the notices themselves were unreachable.
  static const notificationPreferences = '/settings/notifications';
  static const addresses = '/addresses';
  static const paymentMethods = '/payment-methods';
  static const appearance = '/appearance';
  static const language = '/language';
  static const coupons = '/coupons';

  /// The reviews she has written. Distinct from `/seller/reviews`, which is
  /// the desk where a boutique answers the reviews written about her.
  static const myReviews = '/my-reviews';
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
  static const adminSellerApplications = '/admin/seller-applications';

  /// Q63 — the delivery companies desk. Carriers, coverage, and the parcels
  /// none of them accepted. No drivers: Reem does not run a fleet.
  static const adminDelivery = '/admin/delivery';
  static const adminFinancials = '/admin/financials';
  static const adminCommissions = '/admin/commissions';
  static const adminAnalytics = '/admin/analytics';
  static const adminTrends = '/admin/trends';
  static const adminReports = '/admin/reports';
  static const adminModeration = '/admin/moderation';
  static const adminSupport = '/admin/support';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminSystemSettings = '/admin/system-settings';

  /// Running Reem Value: the guarantee, the ladder, the cost, and the policy.
  static const adminValue = '/admin/value';
  static const adminCampaigns = '/admin/notification-campaigns';
  static const adminNotificationAnalytics = '/admin/notification-analytics';

  static const chats = '/chats';
  static const chatDetails = '/chat-details';
  static const calls = '/calls';
  static const chatMediaGallery = '/chat-media-gallery';
}
