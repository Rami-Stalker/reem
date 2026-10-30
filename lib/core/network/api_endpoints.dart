/// REST paths aligned with the Node.js backend modules.
abstract final class ApiEndpoints {
  // Auth
  static const authLogin = '/auth/login';
  static const authGuest = '/auth/guest';
  static const authRegister = '/auth/register';
  static const authRefresh = '/auth/refresh-token';
  static const authLogout = '/auth/logout';
  static const authLogoutAll = '/auth/logout-all';
  static const authMe = '/auth/me';
  static const authForgotPassword = '/auth/forgot-password';
  static const authOtpRequest = '/auth/otp/request';
  static const authOtpVerify = '/auth/otp/verify';

  /// The main door. `start` sends a code to whatever number she typed —
  /// answering identically whether or not it has an account — and `verify`
  /// either signs her in or hands back a ticket to create the account.
  static const authOtpLoginStart = '/auth/otp/login/start';
  static const authOtpLoginVerify = '/auth/otp/login/verify';

  /// Step two on the reverse rail. Takes no code — she sent one instead.
  static const authOtpLoginReverse = '/auth/otp/login/reverse';

  /// Polled while she is away in her messaging app. Spends no attempt.
  static const authOtpReverseStatus = '/auth/otp/reverse/status';
  static const authResetPassword = '/auth/reset-password';
  static const authAccount = '/auth/account';
  static const authAccountPassword = '/auth/account/password';
  static const authAccountDeletion = '/auth/account/deletion';
  static const authAccountDelete = '/auth/account/delete';
  static const authSecurity = '/auth/security';

  /// Moving the account to another number. Three steps, because the number
  /// being *left* has to be proved too — one code on the incoming number is
  /// exactly what a SIM swapper can produce.
  static const authPhoneChangeStart = '/auth/account/phone/start';
  static const authPhoneChangePending = '/auth/account/phone/pending';
  static String authPhoneChangeVerifyCurrent(String id) =>
      '/auth/account/phone/$id/verify-current';
  static String authPhoneChangeConfirm(String id) =>
      '/auth/account/phone/$id/confirm';
  static String authPhoneChange(String id) => '/auth/account/phone/$id';

  /// Step-up: a second factor before a sensitive action.
  static const authStepUpRequest = '/auth/step-up/request';
  static const authStepUpVerify = '/auth/step-up/verify';

  /// Written-down single-use codes, and an authenticator app.
  static const authRecoveryCodes = '/auth/recovery/codes';
  static const authTotpEnroll = '/auth/totp/enroll';
  static const authTotpConfirm = '/auth/totp/confirm';

  /// The last door: the SIM is gone. Unauthenticated by necessity.
  static const authRecoveryCases = '/auth/recovery/cases';
  static String authRecoveryCaseStatus(String id) =>
      '/auth/recovery/cases/$id/status';
  static String authRecoveryCaseCancel(String id) =>
      '/auth/recovery/cases/$id/cancel';
  /// Registers this install's public key. Public: a visitor's device exists
  /// before her account does, and holding a key proves nothing by itself.
  static const authDeviceKeys = '/auth/device-keys';
  static const authDevices = '/auth/devices';
  static String authDevice(String id) => '/auth/devices/$id';
  // `authTrustDevice` is gone with the route behind it. Declaring a device
  // trusted took nothing but a live session and a device id, which made
  // "trusted device" a claim the client could simply assert. Trust is now
  // earned by completing a code on the device, and by nothing else.
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

  /// The pieces she added to her page — empty, with `is_private`, while a
  /// customer's page is closed to the viewer.
  static String userPicks(String id) => '/users/$id/picks';

  // Feed & social (customer interactions)
  static const postsFeed = '/posts/feed';
  static const postsSaved = '/posts/saved';
  // A bare posts-collection constant used to sit here. Nothing referenced it
  // and the backend serves no such route: `PostsController` has `feed`,
  // `saved`, `seller/:sellerId` and `:id`, and no bare listing. A declared
  // path that resolves to nothing is an invitation to build a screen on it.
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

  // «توثيق الحساب» — the badge, and the claim behind it.
  static const accountVerification = '/account-verification';
  static const adminAccountVerifications = '/admin/account-verifications';
  static String adminAccountVerification(String id) =>
      '/admin/account-verifications/$id';

  // «الأبرز» — the stories kept on a page past their day.
  static const highlightsMine = '/highlights/me';
  static const highlightsArchive = '/highlights/me/archive';
  static const highlights = '/highlights';
  static const highlightsOrder = '/highlights/order';
  static String highlightsOf(String userId) => '/highlights/$userId';
  static String highlightDetail(String id) => '/highlights/detail/$id';
  static String highlightById(String id) => '/highlights/$id';
  static String highlightItems(String id) => '/highlights/$id/items';
  static String highlightItem(String id, String contentId) =>
      '/highlights/$id/items/$contentId';
  static String storyView(String id) => '/stories/$id/view';
  static String storyReact(String id) => '/stories/$id/react';

  // Seller — stories authoring + analytics
  static const sellerStories = '/seller/stories';
  static String sellerStoryById(String id) => '/seller/stories/$id';
  static String sellerStoryAnalytics(String id) =>
      '/seller/stories/$id/analytics';
  static String sellerStoryViewers(String id) => '/seller/stories/$id/viewers';

  // ── The content platform ────────────────────────────────────────────────
  //
  // One surface for posts, reels and stories, authored by boutiques and by
  // shoppers alike. `/posts/*` and `/stories/*` above still answer their
  // original contract — they are adapters over these same tables — so a
  // handset running the old build keeps working while this one moves.
  //
  // Feeds are **cursor**-paged, not offset: a feed grows at the head, so page
  // two of an offset query shows rows page one already showed. The envelope is
  // `{data, pagination: {limit, has_next_page, next_cursor}}`.
  static const contentFeed = '/content/feed';
  static const contentReels = '/content/reels';
  static const contentFollowing = '/content/following';
  static const contentStories = '/content/stories';
  static const contentSaved = '/content/saved';
  static String contentByUser(String userId) => '/content/users/$userId';
  static String contentStoriesByUser(String userId) =>
      '/content/users/$userId/stories';
  static String contentByProduct(String productId) =>
      '/content/products/$productId';

  /// What she may tag: her live listings if she is a boutique, the pieces
  /// actually delivered to her if she is a shopper.
  static const contentTaggableProducts = '/content/taggable-products';

  // Authoring — role-neutral. What a role may publish is decided by the
  // content type's `audiences`, not by the route.
  static const content = '/content';
  static const contentMine = '/content/mine';
  static String contentMineById(String id) => '/content/mine/$id';
  static String contentById(String id) => '/content/$id';
  static String contentPublish(String id) => '/content/$id/publish';
  static String contentArchive(String id) => '/content/$id/archive';

  // Interactions
  static String contentLike(String id) => '/content/$id/like';
  static String contentSave(String id) => '/content/$id/save';
  static String contentShare(String id) => '/content/$id/share';

  /// «أضيفي إلى صفحتي» — POST to add, DELETE to take it back off.
  static String contentReshare(String id) => '/content/$id/reshare';

  static String contentComments(String id) => '/content/$id/comments';
  static String contentCommentReplies(String commentId) =>
      '/content/comments/$commentId/replies';
  static String contentComment(String commentId) =>
      '/content/comments/$commentId';
  static String contentReport(String id) => '/content/$id/report';
  static String contentViewers(String id) => '/content/$id/viewers';

  /// The post menu's quiet options — private to her, never a report.
  static String contentHide(String id) => '/content/$id/hide';
  static String contentMuteAuthor(String userId) =>
      '/content/authors/$userId/mute';
  static const contentMuted = '/content/muted';
  static String contentCommentReport(String commentId) =>
      '/content/comments/$commentId/report';

  /// Impressions, watch time, product clicks.
  static String contentEvents(String id) => '/content/$id/events';

  // Seller — content analytics
  static const sellerContentOverview = '/seller/content/analytics/overview';
  static const sellerContentReshares = '/seller/content/analytics/reshares';

  /// The women promoting her products. Named only where their own page is
  /// public — the server decides, and never sends a name it should not.
  static const sellerContentPromoters = '/seller/content/analytics/promoters';
  static String sellerContentAnalytics(String id) =>
      '/seller/content/analytics/content/$id';

  // Admin — moderation
  static const adminContent = '/admin/content';
  static const adminContentReports = '/admin/content/reports';
  static String adminContentHistory(String id) => '/admin/content/$id/history';
  static String adminContentRemove(String id) => '/admin/content/$id/remove';
  static String adminContentReinstate(String id) =>
      '/admin/content/$id/reinstate';
  static String adminContentCommentRemove(String commentId) =>
      '/admin/content/comments/$commentId/remove';

  /// «حسابي عام» — opening or closing her page.
  static const usersProfileVisibility = '/users/me/profile-visibility';

  // Content type registry — what formats exist and who may publish them.
  static const contentTypes = '/content-types';

  // Products (public browse)
  static const products = '/products';
  static const productsTrending = '/products/trending';
  static String productById(String id) => '/products/$id';

  // Product social — the post gestures on a product. Like and pick are desired
  // states (PUT / DELETE), so the outbox may replay them safely.
  static const productEngagementBatch = '/products/engagement/batch';
  static String productLike(String id) => '/products/$id/like';
  static String productShare(String id) => '/products/$id/share';
  static String productPick(String id) => '/products/$id/pick';
  static String productComments(String id) => '/products/$id/comments';
  static String productComment(String id, String commentId) =>
      '/products/$id/comments/$commentId';
  static String productReport(String id) => '/products/$id/report';

  // Discovery (collections, recommendations, similar)
  static const discoveryHome = '/discovery/home';

  /// The editorial home page — banners, categories, deals, her cart, her
  /// points. Distinct from [discoveryHome], which is the product-collection
  /// feed underneath it.
  static const homeContent = '/discovery/home-content';

  /// Everything her profile centre renders, in one call.
  static const profileOverview = '/users/me/overview';
  static const discoveryRecommended = '/discovery/recommended';

  /// «إزالة من المختارة لكِ» — POST removes, DELETE is its «تراجع».
  static String discoveryRecommendedDismiss(String productId) =>
      '/discovery/recommended/$productId/dismiss';
  static String discoveryCollection(String key) =>
      '/discovery/collections/$key';
  static String discoveryCategory(String category) =>
      '/discovery/category/$category';

  /// The catalogue's category tree. Public, because it drives the buyer's
  /// browse rails as much as the seller's product form — and because a leaf's
  /// UUID is the only thing `POST /seller/products` accepts.
  static const categories = '/categories';
  static const categoryLeaves = '/categories?leaves=true';
  static String categoryById(String id) => '/categories/$id';
  static String discoverySeller(String sellerId) =>
      '/discovery/seller/$sellerId';
  static String discoverySimilar(String productId) =>
      '/discovery/products/$productId/similar';

  // Seller — product management
  static const sellerProducts = '/seller/products';

  /// The seller's own catalog listing. It is served by the *offers* controller,
  /// not `/seller/products`: since the central-catalog split a seller does not
  /// own products, they own offers on them, so the list is offers with their
  /// product nested (which is exactly what `ManagedProductModel` parses).
  static const sellerOffers = '/seller/offers';

  /// Everything a seller owns about a listing — price, stock, currency,
  /// fulfilment terms and its published status — is a property of her OFFER,
  /// not of the shared catalogue entry. These five used to be spelled
  /// `/seller/products/:id/status` and `/seller/products/:id/stock`, routes
  /// that ceased to exist when offers were split out: publishing, restocking
  /// and deleting a listing had all been answering 404 since.
  static String sellerOfferById(String id) => '/seller/offers/$id';
  static String sellerOfferStock(String id) => '/seller/offers/$id/stock';
  static const sellerOffersLowStock = '/seller/offers/low-stock';

  /// The canonical catalogue entry — title, description, category, gallery.
  /// Editable only while she is the sole seller listing it.
  static String sellerProductById(String id) => '/seller/products/$id';
  static String sellerProductVariants(String id) =>
      '/seller/products/$id/variants';
  static String sellerProductVariant(String id, String variantId) =>
      '/seller/products/$id/variants/$variantId';

  // Seller commerce command centre
  static const sellerCommerceOverview = '/seller/commerce/overview';

  // The seller's order queue — the screen she works a sale from (Q37/Q57).
  static const sellerOrders = '/seller/orders';
  static String sellerOrderById(String id) => '/seller/orders/$id';
  static String sellerOrderConfirm(String id) => '/seller/orders/$id/confirm';
  static String sellerOrderReady(String id) => '/seller/orders/$id/ready';
  static String sellerOrderHandOver(String id) => '/seller/orders/$id/hand-over';
  static String sellerOrderDeliver(String id) => '/seller/orders/$id/deliver';
  static String sellerOrderCancel(String id) => '/seller/orders/$id/cancel';

  // Search
  static const search = '/search';
  static const searchProducts = '/search/products';
  static const searchSellers = '/search/sellers';
  static const searchPosts = '/search/posts';
  static const searchUsers = '/search/users';
  static const searchSuggestions = '/search/suggestions';
  static const searchTrending = '/search/trending';
  static const searchRecent = '/search/recent';
  static String searchRecentById(String id) => '/search/recent/$id';

  /// A tap on a search result — the click-through half of Search Intelligence.
  static const searchClicks = '/search/clicks';

  /// A tap on a paid slot, credited to the offer that paid for it.
  static const sponsoredClicks = '/sponsored/clicks';

  // «مركز الإعلانات» — a boutique's own advertising.
  static const adsPlans = '/ads/plans';
  static const adsSubscribe = '/ads/plans/subscribe';
  static const adsQuote = '/ads/quote';
  static const adsSuggestions = '/ads/suggestions';
  static const adsOverview = '/ads/overview';
  static const adsGovernorates = '/ads/audience/governorates';
  static const adsCampaigns = '/ads/campaigns';
  static String adsCampaignStatus(String id) => '/ads/campaigns/$id/status';
  static const adsPaymentOptions = '/ads/plans/payment-options';
  static const adsPurchases = '/ads/plans/purchases';
  static String adsPurchaseReference(String id) =>
      '/ads/plans/purchases/$id/reference';
  static String adsPurchaseCancel(String id) =>
      '/ads/plans/purchases/$id/cancel';

  // Finance's half of plan payments.
  static const adminAdsSummary = '/ads/admin/summary';
  static const adminAdsPurchases = '/ads/admin/purchases';
  static String adminAdsPurchaseConfirm(String id) =>
      '/ads/admin/purchases/$id/confirm';
  static String adminAdsPurchaseReject(String id) =>
      '/ads/admin/purchases/$id/reject';
  static const adminAdsPaymentInstructions = '/ads/admin/payment-instructions';

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

  /// The transfer reference for a bank or hawala payment she has already sent.
  static String paymentReference(String id) => '/payments/$id/reference';

  // Orders & checkout
  static const orders = '/orders';
  static const ordersCheckout = '/orders/checkout';
  static String orderById(String id) => '/orders/$id';
  static String orderTimeline(String id) => '/orders/$id/timeline';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderCodConfirmation(String id) => '/orders/$id/cod-confirmation';
  static String orderCodConfirmationResend(String id) =>
      '/orders/$id/cod-confirmation/resend';
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

  /// Her review desk: everything said about her goods and her shop, merged,
  /// and the public answer she may write under each one.
  static const myReviews = '/reputation/me/reviews';

  /// «تقييمات من بمقاسي» — how a piece fits, overall and for women like her.
  static String productFit(String productId) =>
      '/reputation/products/$productId/fit';

  /// «مقاساتي» — her height and usual size. Hers alone.
  static const fitProfile = '/fit-profile';
  static const sellerReviewDesk = '/reputation/seller/reviews';
  static String sellerReviewReply(String id) =>
      '/reputation/seller/reviews/$id/reply';
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

  // Ohara AI Stylist — the conversational assistant. Separate from the rails
  // above: those answer "what should this shelf show", this answers a sentence.
  static const stylistBootstrap = '/ai/stylist/bootstrap';
  static const stylistConversations = '/ai/stylist/conversations';
  static String stylistConversation(String id) =>
      '/ai/stylist/conversations/$id';
  static String stylistMessages(String conversationId) =>
      '/ai/stylist/conversations/$conversationId/messages';
  static const stylistOutfits = '/ai/stylist/outfits';
  static String stylistOutfit(String id) => '/ai/stylist/outfits/$id';
  static const stylistRecommendations = '/ai/stylist/recommendations';
  static String stylistRecommendationFeedback(String id) =>
      '/ai/stylist/recommendations/$id/feedback';
  static const stylistPreferences = '/ai/stylist/preferences';
  static const stylistPreferencesRefresh = '/ai/stylist/preferences/refresh';

  // Ohara Closet — her wardrobe. Not under `/ai`: nothing here is generated.
  // A gap is arithmetic over her own rows, and the only route that reaches the
  // catalog at all is `closetGapSuggestions`.
  static const closet = '/closet';
  static const closetSettings = '/closet/settings';
  static const closetBackfill = '/closet/backfill';

  static const closetItems = '/closet/items';
  static String closetItem(String id) => '/closet/items/$id';
  static const closetItemsCatalog = '/closet/items/catalog';
  static const closetItemsPersonal = '/closet/items/personal';
  static String closetItemStatus(String id) => '/closet/items/$id/status';
  static String closetItemWear(String id) => '/closet/items/$id/wear';

  static const closetLooks = '/closet/looks';
  static String closetLook(String id) => '/closet/looks/$id';
  static String closetLookItems(String id) => '/closet/looks/$id/items';
  static String closetLookWear(String id) => '/closet/looks/$id/wear';
  static String closetLookFromStylist(String outfitId) =>
      '/closet/looks/from-stylist/$outfitId';

  static const closetGaps = '/closet/gaps';
  static const closetGapsRefresh = '/closet/gaps/refresh';
  static String closetGapSuggestions(String id) =>
      '/closet/gaps/$id/suggestions';
  static String closetGapDismiss(String id) => '/closet/gaps/$id/dismiss';
  static String closetGapRestore(String id) => '/closet/gaps/$id/restore';

  /// "هل بتناسب خزانتي؟" — asked from a product page.
  static String closetPairing(String productId) => '/closet/pairing/$productId';

  static const closetToday = '/closet/today';

  // Ohara Value — her standing. Note the absence of an "earn" or "redeem"
  // endpoint: standing is computed from evidence the platform already holds,
  // and nothing a client sends can move it. Claiming a benefit costs nothing,
  // which is why it is `claim` and not `redeem`.
  static const value = '/value';
  static const valueBadge = '/value/badge';
  static const valueEvents = '/value/events';
  static const valueRules = '/value/rules';
  static const valueBenefits = '/value/benefits';
  static const valueBenefitClaim = '/value/benefits/claim';
  static String valueGrantUse(String id) => '/value/benefits/grants/$id/use';

  // Ohara Rooms — Intent → Room → Decision → Purchase.
  //
  // Read the verbs: propose, choose, skip, reject, stage. Not one of them is
  // "add to cart", and there is no route that buys something that was never
  // chosen — `roomPlan` refuses a room with open decisions and names them.
  static const rooms = '/rooms';
  static String room(String id) => '/rooms/$id';
  static String roomTimeline(String id) => '/rooms/$id/timeline';

  static String roomMembers(String id) => '/rooms/$id/members';
  static String roomMember(String id, String memberId) =>
      '/rooms/$id/members/$memberId';
  static String roomLeave(String id) => '/rooms/$id/leave';
  static String roomShare(String id) => '/rooms/$id/share';
  static String roomJoin(String slug) => '/rooms/join/$slug';

  static String roomDecisions(String id) => '/rooms/$id/decisions';
  static String roomDecision(String id, String decisionId) =>
      '/rooms/$id/decisions/$decisionId';
  static String roomDecisionOrder(String id) => '/rooms/$id/decisions/order';
  static String roomDecisionSkip(String id, String decisionId) =>
      '/rooms/$id/decisions/$decisionId/skip';

  static String roomCandidates(String id, String decisionId) =>
      '/rooms/$id/decisions/$decisionId/candidates';
  static String roomCandidate(String id, String candidateId) =>
      '/rooms/$id/candidates/$candidateId';
  static String roomCandidateChoose(String id, String candidateId) =>
      '/rooms/$id/candidates/$candidateId/choose';
  static String roomCandidateUnchoose(String id, String candidateId) =>
      '/rooms/$id/candidates/$candidateId/unchoose';
  static String roomCandidateReject(String id, String candidateId) =>
      '/rooms/$id/candidates/$candidateId/reject';
  static String roomCandidateShortlist(String id, String candidateId) =>
      '/rooms/$id/candidates/$candidateId/shortlist';
  static String roomCandidateVote(String id, String candidateId) =>
      '/rooms/$id/candidates/$candidateId/vote';

  static String roomCompare(String id, String decisionId) =>
      '/rooms/$id/decisions/$decisionId/compare';

  static String roomComments(String id) => '/rooms/$id/comments';
  static String roomComment(String id, String commentId) =>
      '/rooms/$id/comments/$commentId';

  static String roomPlan(String id) => '/rooms/$id/plan';
  static String roomPlanItemStage(String id, String planId, String itemId) =>
      '/rooms/$id/plan/$planId/items/$itemId/stage';
  static String roomPlanItemQuantity(String id, String planId, String itemId) =>
      '/rooms/$id/plan/$planId/items/$itemId/quantity';
  static String roomPlanItem(String id, String planId, String itemId) =>
      '/rooms/$id/plan/$planId/items/$itemId';
  static String roomPlanCheckout(String id, String planId) =>
      '/rooms/$id/plan/$planId/checkout';

  // Running the programme. A policy is drafted, simulated against the live
  // population, and only then activated — three endpoints rather than one PUT,
  // because retuning what a standing means should not be a single careless save.
  static const adminValueDistribution = '/admin/value/distribution';
  static const adminValueCost = '/admin/value/cost';
  static const adminValueGrants = '/admin/value/grants';
  static const adminValueSuspects = '/admin/value/suspects';
  static String adminValueProfile(String userId) =>
      '/admin/value/profiles/$userId';
  static String adminValueFreeze(String userId) =>
      '/admin/value/profiles/$userId/freeze';
  static String adminValueUnfreeze(String userId) =>
      '/admin/value/profiles/$userId/unfreeze';
  static const adminValuePolicies = '/admin/value/policies';
  static String adminValuePolicySimulate(String id) =>
      '/admin/value/policies/$id/simulate';
  static String adminValuePolicyActivate(String id) =>
      '/admin/value/policies/$id/activate';
  static const adminValueSweep = '/admin/value/sweep';
  static const adminValueRecompute = '/admin/value/recompute';

  // Ohara Visual Shopping — search and shop by photograph. The image is posted
  // to `visualSearches` directly rather than through `mediaUploads` first: the
  // server has to be the one that decides the bytes are private, re-encodes
  // them and stamps a retention clock on them, and a two-step flow would leave
  // an uploaded photograph with nobody responsible for it.
  static const visualSearchBootstrap = '/visual-search/bootstrap';
  static const visualSearches = '/visual-search/searches';
  static const visualSessions = '/visual-search/sessions';
  static String visualSession(String id) => '/visual-search/sessions/$id';
  static String visualRefine(String id) => '/visual-search/sessions/$id/refine';
  static String visualLook(String id) => '/visual-search/sessions/$id/look';
  static String visualResultFeedback(String id) =>
      '/visual-search/results/$id/feedback';
  static String visualSimilarProducts(String productId) =>
      '/visual-search/products/$productId/similar';
  static const visualTryOnCapability = '/visual-search/try-on/capability';
  static const visualTryOn = '/visual-search/try-on';
  static String visualTryOnRequest(String id) => '/visual-search/try-on/$id';

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
  static String chatThread(String chatId) => '/chats/$chatId';
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
  static const couponsValidate = '/coupons/validate';
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

  // Wallet and finance (Q41–Q43, Q107)
  static const wallet = '/ledger/wallet';
  static const walletTransactions = '/ledger/wallet/transactions';
  static const loyaltyConvert = '/finance/loyalty/convert';
  static const disputes = '/finance/disputes';
  static const sellerEarnings = '/finance/seller/earnings';

  /// Q69 P1's second half — asking to be paid. Creating a request moves no
  /// money: approving and releasing it stay with the platform (Q62).
  static const sellerPayouts = '/finance/seller/payouts';
  static const sellerPayoutAvailability =
      '/finance/seller/payouts/availability';
  static String sellerPayoutCancel(String id) =>
      '/finance/seller/payouts/$id/cancel';
  static const adminFinanceOverview = '/finance/admin/overview';
  static const adminFxSync = '/finance/admin/fx/sync';
  static const adminPendingTransfers = '/payments/admin/transfers';
  static String adminConfirmTransfer(String id) =>
      '/payments/admin/transfers/$id/confirm';
  static String adminRejectTransfer(String id) =>
      '/payments/admin/transfers/$id/reject';

  // Invoices (Q51 — one per order, one per seller)
  static String invoicesForOrder(String orderId) => '/invoices/order/$orderId';
  static String invoiceById(String id) => '/invoices/$id';
  static String issueSellerInvoice(String sellerOrderId) =>
      '/invoices/seller-order/$sellerOrderId';

  // Returns and exchanges (Q56 P1, Q67 P1, Q37 P2)
  //
  // The whole subsystem existed on the server with no client at all: a seller
  // could watch a parcel come back on her order queue and had no way to accept
  // it, refuse it, or say she had it in her hands.
  static const returns = '/returns';
  static const sellerReturns = '/returns/seller';
  static String returnById(String id) => '/returns/$id';
  static String returnEligibility(String sellerOrderId) =>
      '/returns/eligibility/$sellerOrderId';
  static String returnCancel(String id) => '/returns/$id/cancel';
  static String returnApprove(String id) => '/returns/$id/approve';
  static String returnReject(String id) => '/returns/$id/reject';
  static String returnInTransit(String id) => '/returns/$id/in-transit';
  static String returnReceive(String id) => '/returns/$id/receive';
  static String returnExchange(String id) => '/returns/$id/exchange';
  static String returnExchangeDelivered(String id) =>
      '/returns/$id/exchange-delivered';

  // Shipment tracking (Q64) — the tracking code is the credential, so this
  // one needs no session.
  static String shipmentTrack(String trackingCode) =>
      '/shipments/track/$trackingCode';

  // Courier app (Q55)
  static const courierToday = '/shipments/courier/today';
  static String shipmentPickUp(String id) => '/shipments/$id/pick-up';
  static String shipmentOutForDelivery(String id) =>
      '/shipments/$id/out-for-delivery';
  static String shipmentDeliver(String id) => '/shipments/$id/deliver';
  static String shipmentFail(String id) => '/shipments/$id/fail';
  static const notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const notificationsReadAll = '/notifications/read-all';
  static const notificationPreferences = '/notifications/preferences';
  static const notificationsUnreadCount = '/notifications/unread-count';

  /// Where this handset can be reached, and where to stop reaching it.
  ///
  /// The unregister is a POST rather than a DELETE because the token is
  /// several hundred characters and belongs nowhere near a URL: a query
  /// string is the one part of a request every proxy on the way writes into
  /// its access log.
  static const pushTokens = '/notifications/push-tokens';
  static const pushTokenUnregister = '/notifications/push-tokens/unregister';

  // Media uploads
  //
  // One file per request, multipart, with `purpose` alongside it. Uploading is
  // separate from creating the product or story the file belongs to on
  // purpose: a woman who loses signal on submit should not lose four
  // photographs with it.
  static const mediaUploads = '/media/uploads';

  /// Private assets — verification documents — are never on the public mount.
  static String mediaFile(String id) => '/media/$id/file';

  // Admin
  static const adminStats = '/admin/stats';

  // ── Delivery companies (Q63) ──────────────────────────────────────────
  //
  // Ohara does not run drivers: parcels are carried by delivery companies, and
  // these routes are the operations desk for them. The app never talks to a
  // carrier — only to Ohara, which holds every credential.
  static const adminDeliveryProviders = '/admin/delivery/providers';
  static String adminDeliveryProviderEnable(String id) =>
      '/admin/delivery/providers/$id/enable';
  static String adminDeliveryProviderDisable(String id) =>
      '/admin/delivery/providers/$id/disable';
  static const adminDeliveryDispatches = '/admin/delivery/dispatches';
  static String adminDeliveryDispatchRetry(String id) =>
      '/admin/delivery/dispatches/$id/retry';
  static const adminOrders = '/admin/orders';
  static const adminProducts = '/admin/products';
  static const adminUsers = '/admin/users';
  static const adminSellers = '/admin/sellers';
  static const adminAnalytics = '/admin/analytics';

  /// The morning briefing: what the marketplace thinks somebody should look at
  /// today, each row carrying its evidence and an action.
  static const adminBriefing = '/admin/intelligence/briefing';
  static const adminFinancials = '/admin/financials';
  /// The console's commission screen reads `/admin/commissions` — rules,
  /// ledger entries and the pending total in one payload — rather than
  /// `/commissions/admin/reports`, because that is the shape the rule and
  /// ledger actions on this screen write back to.
  static const adminCommissions = '/admin/commissions';
  static const adminCommissionRules = '/admin/commissions/rules';
  static String adminCommissionLedger(String id) => '/admin/commissions/$id';
  static const adminReports = '/admin/reports';
  static String adminReport(String id) => '/admin/reports/$id';
  static const adminModeration = '/admin/moderation';
  static String adminModerationCase(String id) => '/admin/moderation/$id';
  static const adminSupport = '/admin/support';
  static String adminSupportTicket(String id) => '/admin/support/$id';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminSystemSettings = '/admin/system-settings';
  static String adminUser(String id) => '/admin/users/$id';
  static String adminProduct(String id) => '/admin/products/$id';
  static const adminSellerApplications = '/admin/seller-applications';
  static String adminSellerApplication(String id) =>
      '/admin/seller-applications/$id';
  static String adminSellerApplicationReview(String id) =>
      '/admin/seller-applications/$id/review';
  static const notificationAdminAnalytics = '/notifications/admin/analytics';
  static const notificationAdminCampaigns = '/notifications/admin/campaigns';
  static const notificationAdminDispatch = '/notifications/admin/dispatch';
  static String notificationAdminCampaignRun(String id) =>
      '/notifications/admin/campaigns/$id/run';

  // ── Ohara Trend Engine ──────────────────────────────────────────────────
  //
  // Two trees, not one parameterised by role. `/trends/seller/*` is always
  // scoped to the caller on the server and accepts no seller id, so there is
  // no path here by which one seller could ask for another's numbers.
  static const trendsSellerOverview = '/trends/seller/overview';
  static const trendsSellerProducts = '/trends/seller/products';
  static String trendsSellerProduct(String id) => '/trends/seller/products/$id';
  static const trendsSellerForecast = '/trends/seller/forecast';
  static const trendsSellerInsights = '/trends/seller/insights';
  static String trendsSellerInsight(String id) =>
      '/trends/seller/insights/$id';

  /// Ohara Intelligence (phase three). Optional auth: a signed-out visitor
  /// gets catalogue facts, a signed-in shopper gets what applies to her.
  static String intelligenceNotes(String productId) =>
      '/intelligence/products/$productId/notes';
  static String intelligenceFit(String productId) =>
      '/intelligence/products/$productId/fit';
  static String intelligenceRelated(String productId) =>
      '/intelligence/products/$productId/related';

  // ── Ohara Market Evolution (phase four) ───────────────────────────────
  //
  // The shopper's half. Drops, bundles and the resale market take optional
  // auth — signed out shows what is open to everyone, signed in adds what she
  // was invited to — and everything about her own wardrobe requires it.
  static const marketDrops = '/market/drops';
  static String marketDropOpened(String id) => '/market/drops/$id/opened';
  static const marketBundles = '/market/bundles';
  static String marketBundle(String id) => '/market/bundles/$id';
  static String marketBundleAlternatives(String id) =>
      '/market/bundles/$id/alternatives';
  static String marketBundleCheckoutLines(String id) =>
      '/market/bundles/$id/checkout-lines';
  static const marketWardrobeSummary = '/market/wardrobe/summary';
  static const marketWardrobeAttention = '/market/wardrobe/attention';
  static String marketWardrobeItem(String id) => '/market/wardrobe/items/$id';
  static String marketWardrobeResale(String id) =>
      '/market/wardrobe/items/$id/resale';
  static const marketResale = '/market/resale';
  static const marketResaleMine = '/market/resale/mine';
  static String marketResaleListing(String id) => '/market/resale/$id';
  static String marketResaleStatus(String id) => '/market/resale/$id/status';
  static const marketMissions = '/market/missions';
  static String marketMissionDecline(String key) =>
      '/market/missions/$key/decline';

  /// The seller's half. Same rule as seller intelligence below: no seller id
  /// in any path, because the server reads it from the token.
  static const sellerMarketDrops = '/seller/market/drops';
  static const sellerMarketDropCandidates = '/seller/market/drops/candidates';
  static String sellerMarketDropAudience(String id) =>
      '/seller/market/drops/$id/audience';
  static String sellerMarketDropStatus(String id) =>
      '/seller/market/drops/$id/status';
  static String sellerMarketDropPerformance(String id) =>
      '/seller/market/drops/$id/performance';
  static const sellerMarketOpportunities = '/seller/market/opportunities';

  static const adminMarketOpportunities = '/admin/market/opportunities';
  static const adminMarketSignals = '/admin/market/signals';

  // ── Seller Intelligence (phase two) ──────────────────────────────────
  //
  // No seller id in any of these: the server reads it from the token and the
  // routes take no parameter for it, which is what makes it impossible for a
  // caller to ask about somebody else's shop.
  static const sellerIntelligenceDeclining = '/seller/intelligence/declining';
  static String sellerIntelligenceDiagnosis(String id) =>
      '/seller/intelligence/products/$id/diagnosis';
  static const sellerIntelligenceRadar = '/seller/intelligence/radar';
  static const sellerIntelligenceProducts = '/seller/intelligence/products';
  static String sellerIntelligenceProduct(String id) =>
      '/seller/intelligence/products/$id';
  static const sellerIntelligenceHealth = '/seller/intelligence/health';
  static const sellerIntelligenceHealthHistory =
      '/seller/intelligence/health/history';
  static const sellerIntelligenceSnapshot =
      '/seller/intelligence/health/snapshot';

  static const trendsAdminOverview = '/trends/admin/overview';
  static const trendsAdminCategories = '/trends/admin/categories';
  static const trendsAdminAttributes = '/trends/admin/attributes';
  static const trendsAdminColors = '/trends/admin/colors';
  static const trendsAdminPrices = '/trends/admin/prices';
  static const trendsAdminProducts = '/trends/admin/products';
  static String trendsAdminProduct(String id) => '/trends/admin/products/$id';
  static const trendsAdminSearch = '/trends/admin/search';
  static const trendsAdminUnmetDemand = '/trends/admin/unmet-demand';
  static String trendsAdminUnmetDemandItem(String id) =>
      '/trends/admin/unmet-demand/$id';
  static const trendsAdminForecast = '/trends/admin/forecast';
  static const trendsAdminSellers = '/trends/admin/sellers';
  static const trendsAdminOpportunities = '/trends/admin/opportunities';
  static const trendsAdminInsights = '/trends/admin/insights';
  static String trendsAdminInsight(String id) => '/trends/admin/insights/$id';
  static const trendsAdminRuns = '/trends/admin/runs';
  static const trendsAdminRecompute = '/trends/admin/recompute';

  // ── Policies, terms and consent ───────────────────────────────────────
  //
  // The reads are open: a woman reads the terms *before* she has an account,
  // and the signup form has to name the documents while there is no session to
  // ask with. `policyAccept` is the only one here that needs one.
  static const policies = '/policies';

  /// What an account of this kind has to sign before it exists.
  /// `role` is `buyer` or `seller`.
  static const policiesRequired = '/policies/required';

  /// What this account still owes a signature on. Usually empty.
  static const policiesPending = '/policies/pending';

  /// Her receipts: which policy, which version, which day.
  static const policiesAcceptances = '/policies/acceptances';
  static const policiesAccept = '/policies/accept';
  static String policyDocument(String slug) => '/policies/$slug';

  /// One issue by id, archived ones included — so a receipt can be opened
  /// against the text it was signed against rather than against today's.
  static String policyVersion(String id) => '/policies/versions/$id';

  // Admin — the policy desk. Behind `policy:manage`.
  static const adminPolicies = '/admin/policies';
  static const adminPolicyConsentSummary = '/admin/policies/consent-summary';
  static String adminPolicyDocument(String id) => '/admin/policies/$id';
  static String adminPolicyVersions(String id) => '/admin/policies/$id/versions';
  static String adminPolicyVersion(String versionId) =>
      '/admin/policies/versions/$versionId';
  static String adminPolicyVersionPublish(String versionId) =>
      '/admin/policies/versions/$versionId/publish';

  // ── الصالونات والجمال ───────────────────────────────────
  //
  // A directory, a calendar, and the bookings made against it. Reading is open
  // to a guest exactly as the catalogue is — a woman compares salons before she
  // has any reason to make an account.
  static const salons = '/salons';
  static const salonCategories = '/salons/categories';
  static const salonAreas = '/salons/areas';

  /// Reachable by id **or by slug**, which is what a shared link carries.
  static String salon(String idOrSlug) => '/salons/$idOrSlug';
  static String salonReviews(String id) => '/salons/$id/reviews';

  /// Free start times for one service on one day.
  static String salonAvailability(String id) => '/salons/$id/availability';

  /// Which of the next few days have anything free at all.
  static String salonOpenDays(String id) => '/salons/$id/open-days';
  static String salonBook(String id) => '/salons/$id/appointments';

  /// «حجوزاتي», and one of them.
  static const appointments = '/appointments';
  static String appointment(String id) => '/appointments/$id';
  static String appointmentCancel(String id) => '/appointments/$id/cancel';
  static String appointmentReview(String id) => '/appointments/$id/review';

  // The salon's own side. Behind `salon:manage`.
  static const salonMine = '/salons/mine';
  static const salonServices = '/salons/services';
  static String salonService(String id) => '/salons/services/$id';
  static const salonHours = '/salons/hours';
  static const salonClosures = '/salons/closures';
  static String salonClosure(String date) => '/salons/closures/$date';
  static String salonQueue(String id) => '/salons/$id/queue';
  static String salonReviewReply(String reviewId) =>
      '/salons/reviews/$reviewId/reply';
  static String appointmentConfirm(String id) => '/appointments/$id/confirm';
  static String appointmentComplete(String id) => '/appointments/$id/complete';
  static String appointmentNoShow(String id) => '/appointments/$id/no-show';

  // «مناسباتي». Every route is hers alone.
  static const occasions = '/occasions';
  static String occasion(String id) => '/occasions/$id';
  static String occasionStep(String id, String key) =>
      '/occasions/$id/steps/$key';
}
