// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Reem';

  @override
  String get splashTagline => 'Where beauty meets social shopping';

  @override
  String get home => 'Home';

  @override
  String get feed => 'Feed';

  @override
  String get search => 'Search';

  @override
  String get cart => 'Cart';

  @override
  String get profile => 'Profile';

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Settings';

  @override
  String get orders => 'Orders';

  @override
  String get stories => 'Stories';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get send => 'Send';

  @override
  String get verify => 'Verify';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Try again';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get viewAll => 'See all';

  @override
  String get seeMore => 'See more';

  @override
  String get done => 'Done';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get welcomeToReem => 'Welcome to Reem';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get login => 'Log in';

  @override
  String get signIn => 'Sign in';

  @override
  String get signup => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get logout => 'Log out';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Sign out of your account?';

  @override
  String get loginSubtitle => 'Sign in to shop, share and shine';

  @override
  String get fullName => 'Full name';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone number';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get forgetPassword => 'Forgot your password?';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get validEmailRequired => 'Enter a valid email';

  @override
  String get phoneRequired => 'Phone number is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String passwordMinLength(int count) {
    return 'At least $count characters';
  }

  @override
  String get confirmPasswordMismatch => 'Passwords do not match';

  @override
  String get products => 'Products';

  @override
  String get productDetails => 'Product details';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get buyNow => 'Buy now';

  @override
  String get removeFromCart => 'Remove from cart';

  @override
  String get wishlist => 'Wishlist';

  @override
  String get favorite => 'Save';

  @override
  String get unfavorite => 'Saved';

  @override
  String get quantity => 'Quantity';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get inStock => 'In stock';

  @override
  String get todayOffers => 'Today\'s offers';

  @override
  String get bestSeller => 'Best selling';

  @override
  String get newArrivals => 'New arrivals';

  @override
  String get recommended => 'Picked for you';

  @override
  String get trendingNow => 'Trending now';

  @override
  String get trendingSubtitle => 'Most loved this week';

  @override
  String get searchHint => 'Search dresses, beauty, gifts…';

  @override
  String sellersOffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sellers',
      one: '1 seller',
    );
    return '$_temp0';
  }

  @override
  String get comparePrices => 'Compare prices';

  @override
  String priceFrom(String price) {
    return 'From $price';
  }

  @override
  String soldBy(String seller) {
    return 'Sold by $seller';
  }

  @override
  String get checkout => 'Checkout';

  @override
  String get emptyCart => 'Your cart is empty';

  @override
  String get emptyCartAction => 'Start shopping';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get delivery => 'Delivery';

  @override
  String get total => 'Total';

  @override
  String get placeOrder => 'Place order';

  @override
  String get selectGovernorate => 'Choose your governorate';

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get orderSummary => 'Order summary';

  @override
  String splitOrderNotice(int count) {
    return 'Your order is from $count sellers and will arrive in separate parcels — with one delivery charge.';
  }

  @override
  String get etaSameDay => 'Arriving today';

  @override
  String etaDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Arriving within $count days',
      one: 'Arriving within a day',
    );
    return '$_temp0';
  }

  @override
  String get myOrders => 'My orders';

  @override
  String get orderDetails => 'Order details';

  @override
  String get orderStatus => 'Order status';

  @override
  String get parcels => 'Parcels';

  @override
  String trackingNumber(String code) {
    return 'Tracking number $code';
  }

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get reorder => 'Order again';

  @override
  String get requestReturn => 'Request a return';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get moments => 'Moments';

  @override
  String get shareMoment => 'Share your moment';

  @override
  String get addStory => 'Add a story';

  @override
  String get addMoment => 'Add your moment';

  @override
  String get post => 'Post';

  @override
  String get writeComment => 'Write a comment…';

  @override
  String viewAllComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View all $count comments',
      one: 'View 1 comment',
    );
    return '$_temp0';
  }

  @override
  String get likes => 'Likes';

  @override
  String get comments => 'Comments';

  @override
  String get follow => 'Follow';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String get rewards => 'Rewards';

  @override
  String get rewardsAndOffers => 'Rewards and offers';

  @override
  String get points => 'Points';

  @override
  String get coupons => 'Coupons';

  @override
  String couponsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coupons',
      one: '1 coupon',
    );
    return '$_temp0';
  }

  @override
  String get addCoupon => 'Add a coupon';

  @override
  String get applyCoupon => 'Apply coupon';

  @override
  String get invalidCoupon => 'This coupon is not valid';

  @override
  String get usedCoupon => 'Coupon applied';

  @override
  String get account => 'Account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get preferences => 'Preferences';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Help centre';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get faq => 'FAQ';

  @override
  String get addresses => 'Addresses';

  @override
  String get paymentMethods => 'Payment methods';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceDescription =>
      'Choose how Reem looks on your device. Your choice is saved automatically.';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightSubtitle => 'Soft rose and daytime elegance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkSubtitle => 'Deep plum with a rose glow';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemSubtitle => 'Follows your device settings';

  @override
  String get themeLightActive => 'Light theme is on';

  @override
  String get themeDarkActive => 'Dark theme is on';

  @override
  String get themeSystemActive => 'Following the system theme';

  @override
  String get preview => 'Preview';

  @override
  String get active => 'On';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Choose your language';

  @override
  String get followDeviceLanguage => 'Follow the device language';

  @override
  String get systemLanguage => 'System';

  @override
  String get ar => 'Arabic';

  @override
  String get en => 'English';

  @override
  String get success => 'Done';

  @override
  String get error => 'Something went wrong';

  @override
  String get emptyFeed => 'Nothing here yet';

  @override
  String get emptyStories => 'No stories right now';

  @override
  String get emptyWishlist => 'Your wishlist is empty';

  @override
  String emptySearch(String query) {
    return 'No results for “$query”';
  }

  @override
  String get noConnection => 'No internet connection';

  @override
  String get sellerDashboard => 'Store dashboard';

  @override
  String get myProducts => 'My listings';

  @override
  String get myEarnings => 'My earnings';

  @override
  String get adminPanel => 'Admin panel';

  @override
  String get adminDashboard => 'Dashboard';

  @override
  String get adminOrders => 'Orders';

  @override
  String get adminProducts => 'Products';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminAnalytics => 'Analytics';

  @override
  String get adminWelcome => 'Welcome back';

  @override
  String get adminTotalSales => 'Total sales';

  @override
  String get adminTotalOrders => 'Total orders';

  @override
  String get adminActiveUsers => 'Active users';

  @override
  String get adminConversion => 'Conversion rate';

  @override
  String get adminRecentOrders => 'Recent orders';

  @override
  String get adminManageCatalog => 'Manage catalogue';

  @override
  String get adminViewReports => 'View reports';

  @override
  String get adminBackToShop => 'Back to the shop';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yClose => 'Close';

  @override
  String get a11ySearch => 'Search';

  @override
  String get a11yCart => 'Cart';

  @override
  String get a11yNotifications => 'Notifications';

  @override
  String get a11yProfile => 'Profile';

  @override
  String get a11yLike => 'Like';

  @override
  String get a11yShare => 'Share';

  @override
  String get a11ySave => 'Save';

  @override
  String get a11yMore => 'More options';

  @override
  String get a11yPlay => 'Play';

  @override
  String get emailOrPhone => 'Email or phone';

  @override
  String get emailOrPhoneRequired => 'Email or phone is required';

  @override
  String get validEmailOrPhone => 'Enter a valid email or phone number';

  @override
  String get validPhone => 'Enter a valid phone number';

  @override
  String get fullNameRequired => 'Full name is required';

  @override
  String get firstName => 'First name';

  @override
  String get country => 'Country';

  @override
  String get city => 'City';

  @override
  String get lastName => 'Last name';

  @override
  String get passwordStrengthRule =>
      'Use upper and lower case letters, a number, and a symbol.';

  @override
  String get passwordWeak => 'Weak';

  @override
  String get passwordGood => 'Good';

  @override
  String get passwordStrong => 'Strong';

  @override
  String passwordStrengthLabel(String label) {
    return 'Password strength: $label';
  }

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get signInRequired => 'Sign in required';

  @override
  String get signInToCheckout => 'Sign in to checkout';

  @override
  String get continueAsGuest => 'Continue as a guest';

  @override
  String get signOutQuestion => 'Sign out?';

  @override
  String get signBackInLater => 'You can always sign back in.';

  @override
  String get verifyYourPhone => 'Verify your phone';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get enterVerificationCode => 'Enter the verification code.';

  @override
  String codeSentTo(String phone) {
    return 'We sent a one-time code to $phone.';
  }

  @override
  String get codeSent => 'Verification code sent to your phone.';

  @override
  String get resendCode => 'Resend the code';

  @override
  String get requestingCode => 'Requesting a one-time code…';

  @override
  String get verifyCode => 'Verify the code';

  @override
  String get verificationComplete => 'Verification complete.';

  @override
  String get phoneVerified => 'Phone number verified.';

  @override
  String get allSet => 'You are all set ✨';

  @override
  String get resetYourPassword => 'Reset your password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get changePassword => 'Change password';

  @override
  String get updatePassword => 'Update password';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get passwordUpdatedSignInAgain =>
      'Password updated. Please sign in again.';

  @override
  String get securityTitle => 'Privacy and security';

  @override
  String get secureAccountControls => 'Secure account controls';

  @override
  String get manageSecurityBlurb =>
      'Manage sessions, devices, recovery, and checkout details.';

  @override
  String get sessions => 'Sessions';

  @override
  String get noActiveSessions => 'No active sessions.';

  @override
  String get revokeSession => 'Revoke the session';

  @override
  String get revoke => 'Revoke';

  @override
  String get logOutAll => 'Log out everywhere';

  @override
  String get devices => 'Devices';

  @override
  String get noDevicesYet => 'No devices yet.';

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get deviceName => 'Device name';

  @override
  String get renameDevice => 'Rename the device';

  @override
  String get rename => 'Rename';

  @override
  String get deviceUpdated => 'Device updated.';

  @override
  String get trust => 'Trust';

  @override
  String get rememberThisDevice => 'Remember this device';

  @override
  String get verifyNewDevices => 'Verify new devices';

  @override
  String get flagNewDevices => 'Flag new devices for verification.';

  @override
  String get otpOnSensitive => 'OTP on sensitive actions';

  @override
  String get otpOnSensitiveDescription => 'Require an OTP for risky changes.';

  @override
  String get linkedAccounts => 'Linked accounts';

  @override
  String get link => 'Link';

  @override
  String get unlink => 'Unlink';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not connected';

  @override
  String get sellerVerification => 'Seller verification';

  @override
  String get submitVerification => 'Submit for verification';

  @override
  String get verificationSubmitted => 'Seller verification submitted.';

  @override
  String get noVerificationSubmitted => 'No verification submitted';

  @override
  String get submitBusinessDetails =>
      'Submit business details to unlock seller trust.';

  @override
  String get completeSellerFields =>
      'Complete all required seller application fields.';

  @override
  String get verified => 'Verified';

  @override
  String get unverified => 'Not verified';

  @override
  String get businessName => 'Business name';

  @override
  String get businessAddress => 'Business address';

  @override
  String get businessCategory => 'Business category';

  @override
  String get commercialRegistration => 'Commercial registration';

  @override
  String get taxNumber => 'Tax number';

  @override
  String get ownerLegalName => 'Owner legal name';

  @override
  String get contactEmail => 'Contact email';

  @override
  String get contactPhone => 'Contact phone';

  @override
  String get bankName => 'Bank name';

  @override
  String get accountHolder => 'Account holder';

  @override
  String get iban => 'IBAN';

  @override
  String get warehouseAddress => 'Warehouse address';

  @override
  String get shippingMethods => 'Shipping methods';

  @override
  String get productCategories => 'Product categories';

  @override
  String get yearsOfExperience => 'Years of experience';

  @override
  String get storeDescription => 'Store description';

  @override
  String get storeLogoUrl => 'Store logo URL';

  @override
  String get website => 'Website';

  @override
  String get governmentIdUrl => 'Government ID URL';

  @override
  String get businessLicenseUrl => 'Business license URL';

  @override
  String get additionalDocuments => 'Additional documents';

  @override
  String get guestProfile => 'Your guest profile';

  @override
  String get guestCartSafe =>
      'Your cart is safe. Sign in to place orders, save addresses, and track delivery.';

  @override
  String get saveYourProgress => 'Save your progress';

  @override
  String get savedProgressBlurb =>
      'Keep favorites, carts, orders, and recently viewed pieces.';

  @override
  String get useEveryDevice => 'Use every device';

  @override
  String get useEveryDeviceBlurb =>
      'Continue from phone, web, or tablet securely.';

  @override
  String get personalRecommendations => 'Personal recommendations';

  @override
  String get personalRecommendationsBlurb =>
      'Get a home feed shaped around your taste and activity.';

  @override
  String get checkoutSafely => 'Checkout safely';

  @override
  String get checkoutSafelyBlurb =>
      'Keep orders, addresses, and payments protected.';

  @override
  String get syncBlurb => 'Sync favorites, carts, and recommendations.';

  @override
  String get quickSteps => 'A few quick steps to a richer experience.';

  @override
  String get myCart => 'My cart';

  @override
  String get browseAndAdd => 'Browse the shop and add something you love.';

  @override
  String get keepBrowsing => 'Keep browsing';

  @override
  String get removeOutOfStock => 'Remove out-of-stock items';

  @override
  String get savedForLater => 'Saved for later';

  @override
  String get completeProfile => 'Complete your profile';

  @override
  String get profileLooksBeautiful => 'Your profile looks beautiful.';

  @override
  String get profileIdentity => 'Profile identity';

  @override
  String get accountUpdated => 'Account updated.';

  @override
  String get savedItems => 'Saved items';

  @override
  String get savedProducts => 'Saved products';

  @override
  String get savedSellers => 'Saved sellers';

  @override
  String get savedPosts => 'Saved posts';

  @override
  String get savedAddresses => 'Saved addresses';

  @override
  String get noSavedItems => 'No saved items yet';

  @override
  String get recentlyViewed => 'Recently viewed';

  @override
  String get collections => 'Collections';

  @override
  String get newCollection => 'New collection';

  @override
  String get createCollection => 'Create a collection';

  @override
  String get collectionsBlurb =>
      'Shareable lists for products, sellers, and posts';

  @override
  String get yourWishlist => 'Your wishlist';

  @override
  String get wishlistLinkCopied => 'Wishlist link copied';

  @override
  String get syncingWishlist => 'Syncing your wishlist';

  @override
  String get priceDropsBlurb => 'Price drops and restocks stay on your radar';

  @override
  String get storesToRevisit => 'Stores you want to revisit';

  @override
  String get yourOrders => 'Your orders';

  @override
  String get trackReviewReorder => 'Track, review and reorder';

  @override
  String get achievements => 'Achievements';

  @override
  String get reviewsAndRatings => 'Reviews and ratings';

  @override
  String get pointsEarned => 'Points earned';

  @override
  String get earned => 'Earned';

  @override
  String get redeemed => 'Redeemed';

  @override
  String get lifetime => 'Lifetime';

  @override
  String get locked => 'Locked';

  @override
  String get rewardsPointsBlurb =>
      'Earn points on every order and review. Redeem them for coupons and perks.';

  @override
  String get inviteFriends => 'Invite friends, earn rewards';

  @override
  String get friendsInvited => 'Friends invited';

  @override
  String get codeCopied => 'Code copied';

  @override
  String inviteCodeCopied(String code) {
    return 'Invite code $code copied — share it!';
  }

  @override
  String get supportCentre => 'Support centre';

  @override
  String get helpAndFaq => 'Help and FAQ';

  @override
  String get liveChat => 'Live chat';

  @override
  String get emailUs => 'Email us';

  @override
  String get call => 'Call';

  @override
  String get replyWithinHour => 'We usually reply within an hour';

  @override
  String get startConversation => 'Start a conversation';

  @override
  String get returnPolicy => 'Return policy';

  @override
  String get faqReturns => 'What is your returns policy?';

  @override
  String get faqReturnsAnswer =>
      'Most items can be returned within 14 days. Open an order to start a return.';

  @override
  String get faqTracking => 'How do I track my order?';

  @override
  String get faqTrackingAnswer =>
      'Open My orders from your profile to see live status and delivery updates.';

  @override
  String get faqPoints => 'How do loyalty points work?';

  @override
  String get aboutReem => 'About Reem';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get comingSoonBlurb =>
      'We are polishing this experience — it will be here soon.';

  @override
  String get appPreferences => 'App preferences';

  @override
  String a11yOpen(String name) {
    return 'Open $name';
  }

  @override
  String nextStep(String step) {
    return 'Next: $step';
  }

  @override
  String get aboutReemBlurb =>
      'A premium social-commerce home for the pieces you love — shopping, discovery and community in one place.';

  @override
  String get roleBuyer => 'Buyer';

  @override
  String get roleSeller => 'Seller';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusInTransit => 'In transit';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get declaredFemaleLabel =>
      'I declare that I am a woman and accept the Reem terms';

  @override
  String homeGreetingNamed(String name) {
    return 'Hello $name';
  }

  @override
  String get homeGreetingGuest => 'Welcome';

  @override
  String get homeGreetingSubtitle =>
      'A curated edit of fashion, beauty and gifts — chosen for you.';

  @override
  String get homeSearchHint => 'Search dresses, perfume, gifts…';

  @override
  String get homeStoriesEyebrow => 'Fresh today';

  @override
  String get homeYourStory => 'Your story';

  @override
  String get homeShopByCategory => 'Shop by category';

  @override
  String get homeFlashDealsEyebrow => 'Limited time';

  @override
  String get homeFlashDeals => 'Flash deals';

  @override
  String get homeRecommendedEyebrow => 'Picked for you';

  @override
  String get homeNewArrivalsEyebrow => 'Just in';

  @override
  String get homeBestSellersEyebrow => 'Loved by many';

  @override
  String get homeContinueShoppingEyebrow => 'Welcome back';

  @override
  String get homeContinueShopping => 'Continue shopping';

  @override
  String get homeFeaturedStoresEyebrow => 'Handpicked sellers';

  @override
  String get homeFeaturedStores => 'Featured boutiques';

  @override
  String get homeRecentlyViewedEyebrow => 'Jump back in';

  @override
  String get homeRecentlyViewed => 'Recently viewed';

  @override
  String get homeWishlistEyebrow => 'You loved these';

  @override
  String get homeWishlist => 'From your wishlist';

  @override
  String get homeNearbyEyebrow => 'Near you';

  @override
  String get homeNearbyStores => 'Boutiques nearby';

  @override
  String get homeExploreEyebrow => 'Explore';

  @override
  String get homeExploreTitle => 'Everything for you';

  @override
  String get homeFeedEyebrow => 'From your boutiques';

  @override
  String get homeFeedTitle => 'Latest posts';

  @override
  String get homeTasteNewDrops => 'New drops';

  @override
  String get homeTasteBeauty => 'Beauty';

  @override
  String get homeTasteGifts => 'Gifts';

  @override
  String get filters => 'Filters';

  @override
  String get trending => 'Trending';

  @override
  String get recent => 'Recent';

  @override
  String get all => 'All';

  @override
  String get reply => 'Reply';

  @override
  String get you => 'You';

  @override
  String get justNow => 'Just now';

  @override
  String get addCommentHint => 'Add a comment…';

  @override
  String get redeem => 'Redeem';

  @override
  String get enable => 'Enable';

  @override
  String get openNow => 'Open now';

  @override
  String get closedNow => 'Closed';

  @override
  String get limitedTime => 'Limited time';

  @override
  String get homeCategoriesEyebrow => 'Browse';

  @override
  String get homeFeaturedEyebrow => 'Discover';

  @override
  String get homeLoyaltyTitle => 'Reem Rewards';

  @override
  String get homeLoyaltySubtitle => 'Earn rewards on every purchase ✨';

  @override
  String get homeNearbyPromptTitle => 'Discover boutiques near you';

  @override
  String get homeNearbyPromptBody =>
      'Enable location for local pickup & nearby stores.';

  @override
  String get homeFeedEmptyTitle => 'Your feed is warming up';

  @override
  String get homeFeedEmptyBody =>
      'Follow boutiques you love to fill your feed with beautiful finds.';

  @override
  String flashDealAlmostGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left',
      one: '1 left',
    );
    return '$_temp0';
  }

  @override
  String get couponFreeShipping => 'Free ship';

  @override
  String get wallet => 'My wallet';

  @override
  String get walletBalance => 'Your balance';

  @override
  String get walletNotWithdrawable => 'Spendable inside Reem only';

  @override
  String get walletStatement => 'Wallet activity';

  @override
  String get walletEmptyTitle => 'Your wallet is empty';

  @override
  String get walletEmptyBody =>
      'Refunds, gifts and converted points will appear here.';

  @override
  String get walletOffline =>
      'You are offline. Your balance will update when you reconnect.';

  @override
  String get walletSourceRefund => 'Return refund';

  @override
  String get walletSourcePoints => 'Points converted';

  @override
  String get walletSourceCompensation => 'Compensation';

  @override
  String get walletSourceTopUp => 'Top-up';

  @override
  String get walletSourceGift => 'Gift';

  @override
  String get walletSourceAdjustment => 'Price adjustment';

  @override
  String get walletSourceOrder => 'Order payment';

  @override
  String get walletSourceOrderReversal => 'Order cancelled';

  @override
  String get walletSourceOther => 'Movement';

  @override
  String get loyaltyPoints => 'Loyalty points';

  @override
  String loyaltyPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
      zero: 'No points yet',
    );
    return '$_temp0';
  }

  @override
  String get loyaltyConvert => 'Convert to credit';

  @override
  String get loyaltyConvertHint => 'Every 10 points = 5,000 SYP of credit';

  @override
  String get loyaltyNeedMultipleOfTen => 'Points convert in multiples of ten.';

  @override
  String get loyaltyNotEnoughPoints =>
      'You do not have enough points for that.';

  @override
  String loyaltyConverted(int count) {
    return '$count points added to your balance ✨';
  }

  @override
  String get sellerEarnings => 'My earnings';

  @override
  String get earningsAvailable => 'Ready for payout';

  @override
  String get earningsAvailableHint => 'Transferred weekly';

  @override
  String get earningsHeld => 'In escrow';

  @override
  String get earningsHeldHint => 'Until the return window closes';

  @override
  String get earningsFrozen => 'Frozen — dispute';

  @override
  String get earningsFrozenHint => 'Until the ruling';

  @override
  String get earningsLifetime => 'All time';

  @override
  String get earningsLifetimePaid => 'Paid to you';

  @override
  String get earningsLifetimeGross => 'Gross sales';

  @override
  String get earningsLifetimeCommission => 'Platform commission';

  @override
  String get earningsPendingPayouts => 'Payouts in progress';

  @override
  String get earningsPayoutApproved => 'Approved';

  @override
  String get earningsPayoutPending => 'Awaiting approval';

  @override
  String get earningsStatement => 'Statement';

  @override
  String get earningsEmptyTitle => 'No earnings yet';

  @override
  String get earningsEmptyBody =>
      'Once your first order is delivered, your earnings appear here step by step.';

  @override
  String get earningsOffline =>
      'You are offline. Your earnings will update when you reconnect.';

  @override
  String get earningsMoveSale => 'Sale settled';

  @override
  String get earningsMoveReleased => 'Released from escrow';

  @override
  String get earningsMovePayout => 'Payout';

  @override
  String get earningsMoveFrozen => 'Frozen for a dispute';

  @override
  String get earningsMoveDisputeDone => 'Dispute settled';

  @override
  String get earningsMoveRefund => 'Refund';

  @override
  String get earningsMoveReversal => 'Reversal';

  @override
  String get earningsMoveOther => 'Movement';

  @override
  String get adminFinance => 'Finance';

  @override
  String get adminFinanceSubtitle =>
      'Ledger health, positions, and what needs a person';

  @override
  String get financeSound => 'Books are sound';

  @override
  String get financeSoundHint =>
      'Debits equal credits, and no account has drifted';

  @override
  String get financeUnsound => 'Books need review';

  @override
  String get financeNotBalanced => 'Trial balance is off';

  @override
  String get financeDiscrepancy => 'Discrepancy';

  @override
  String get financeTotalDebit => 'Total debit';

  @override
  String get financeTotalCredit => 'Total credit';

  @override
  String financeFindings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count findings',
      one: '1 finding',
    );
    return '$_temp0';
  }

  @override
  String get financePositions => 'Positions';

  @override
  String get financeHeld => 'Held';

  @override
  String get financeOwed => 'Owed';

  @override
  String get financeCoverage => 'Coverage';

  @override
  String get financeCoverageShort => 'Obligations exceed funds held';

  @override
  String get financePlatformCash => 'Platform cash';

  @override
  String get financeGatewayReceivable => 'Gateway receivable';

  @override
  String get financeCourierInTransit => 'Courier cash in transit';

  @override
  String get financeSellerPayable => 'Seller payable';

  @override
  String get financeSellerEscrow => 'Seller escrow';

  @override
  String get financeCustomerWallets => 'Customer wallets';

  @override
  String get financeDisputeHeld => 'Held for disputes';

  @override
  String get financeLoyaltyLiability => 'Loyalty outstanding';

  @override
  String get financeCommissionRevenue => 'Commission revenue';

  @override
  String get financeCourierCash => 'Courier cash';

  @override
  String get financeCourierCashEmpty => 'No courier is holding platform cash.';

  @override
  String get financeOverdueDisputes => 'Overdue disputes';

  @override
  String financeOverdueBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
      zero: 'due today',
    );
    return '$_temp0';
  }

  @override
  String get financeNoOverdue => 'No disputes are overdue.';

  @override
  String get financeFx => 'FX position';

  @override
  String get financeFxRate => 'Rate';

  @override
  String get financeFxExposure => 'Net exposure';

  @override
  String get financeFxResult => 'Conversion result';

  @override
  String get financeFxSync => 'Sync rate now';

  @override
  String get financeFxNone => 'No exchange rate published yet.';

  @override
  String get financeTrialBalance => 'Trial balance';

  @override
  String get financeAccount => 'Account';

  @override
  String get financeBalance => 'Balance';

  @override
  String get refresh => 'Refresh';

  @override
  String get invoices => 'Invoices';

  @override
  String get invoice => 'Invoice';

  @override
  String get invoiceCustomerCopy => 'Order invoice';

  @override
  String get invoiceSellerCopy => 'Seller invoice';

  @override
  String get invoiceNumber => 'Invoice no.';

  @override
  String get invoiceIssuedAt => 'Issued';

  @override
  String get invoiceOrderNumber => 'Order no.';

  @override
  String get invoiceBilledTo => 'Billed to';

  @override
  String get invoiceItems => 'Items';

  @override
  String get invoiceQuantity => 'Qty';

  @override
  String get invoiceSubtotal => 'Subtotal';

  @override
  String get invoiceDiscount => 'Discount';

  @override
  String get invoiceShipping => 'Shipping';

  @override
  String get invoiceTotal => 'Total';

  @override
  String get invoiceCommission => 'Platform commission';

  @override
  String get invoiceSellerNet => 'Seller net';

  @override
  String get invoiceNoTax => 'This is a commercial invoice, not a tax invoice.';

  @override
  String get invoiceEmptyTitle => 'No invoices yet';

  @override
  String get invoiceEmptyBody => 'Your invoice is issued once the order ships.';

  @override
  String get invoiceCoupon => 'Coupon';

  @override
  String get trackShipment => 'Track shipment';

  @override
  String get trackingCode => 'Tracking code';

  @override
  String get trackExpress => 'Express';

  @override
  String get trackScheduledFor => 'Scheduled for';

  @override
  String get trackDeliveredAt => 'Delivered';

  @override
  String trackAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count delivery attempts',
      one: '1 delivery attempt',
    );
    return '$_temp0';
  }

  @override
  String get trackJourney => 'Journey';

  @override
  String get trackHistory => 'History';

  @override
  String get trackNotFound => 'No shipment matches that code.';

  @override
  String get shipStageCreated => 'Order prepared';

  @override
  String get shipStageAssigned => 'Assigned to a courier';

  @override
  String get shipStagePickedUp => 'Picked up';

  @override
  String get shipStageInTransit => 'In transit';

  @override
  String get shipStageOutForDelivery => 'Out for delivery';

  @override
  String get shipStageDelivered => 'Delivered';

  @override
  String get shipStageFailed => 'Delivery failed';

  @override
  String get shipStageReturning => 'Returning';

  @override
  String get shipStageReturned => 'Returned';

  @override
  String get shipStageCancelled => 'Cancelled';

  @override
  String get courierDay => 'Today\'s round';

  @override
  String get courierOpen => 'In progress';

  @override
  String get courierDone => 'Completed today';

  @override
  String get courierEmptyTitle => 'Nothing assigned today';

  @override
  String get courierEmptyBody =>
      'Parcels appear here as soon as they are assigned to you.';

  @override
  String get courierCollect => 'To collect';

  @override
  String get courierPrepaid => 'Prepaid';

  @override
  String get courierCall => 'Call';

  @override
  String get courierNavigate => 'Map';

  @override
  String get courierPickUp => 'Picked up';

  @override
  String get courierStartDelivery => 'Out for delivery';

  @override
  String get courierDeliver => 'Delivered';

  @override
  String get courierFail => 'Failed';

  @override
  String get courierInstructions => 'Delivery notes';

  @override
  String get courierDeliverTitle => 'Confirm delivery';

  @override
  String get courierCollectedAmount => 'Amount collected';

  @override
  String get courierCollectedHint =>
      'Leave empty if you collected the full amount';

  @override
  String get courierRecipientNote => 'Note';

  @override
  String get courierConfirm => 'Confirm';

  @override
  String get courierFailTitle => 'Why did it fail?';

  @override
  String get failNoAnswer => 'No answer';

  @override
  String get failWrongAddress => 'Wrong address';

  @override
  String get failCustomerRefused => 'Customer refused';

  @override
  String get failPostponed => 'Postponed';

  @override
  String get failUnreachableArea => 'Area unreachable';

  @override
  String get failOther => 'Other';

  @override
  String get signInWithCode => 'Sign in with a code';

  @override
  String get signInSubtitle => 'Enter your number and we will send you a code.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get usePasswordInstead => 'Use my password instead';

  @override
  String get passwordOnlyOnKnownDevice =>
      'A password only works on a device you have signed in from before.';

  @override
  String get newDeviceCodeSent =>
      'This device is new. We sent a code to your number to finish signing in.';

  @override
  String get matchCodeLabel => 'Match code';

  @override
  String get matchCodeHint =>
      'Check that the message shows the same two digits. Reem will never ask you to read a code aloud.';

  @override
  String codeSentToMasked(String destination) {
    return 'Code sent to $destination';
  }

  @override
  String resendInSeconds(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get finishSignUp => 'Finish creating your account';

  @override
  String get numberVerified => 'Number verified';

  @override
  String get passwordOptional => 'Password (optional)';

  @override
  String get passwordOptionalHint =>
      'You can skip this. You will sign in with a code each time.';

  @override
  String get securityCentre => 'Security';

  @override
  String get securityCentreSubtitle =>
      'Your devices, your sessions, and the ways back into your account.';

  @override
  String get passwordSignIn => 'Password sign-in';

  @override
  String get passwordEnabled => 'On — usable on known devices only';

  @override
  String get passwordDisabled => 'Off — you sign in with a code';

  @override
  String get setPassword => 'Set a password';

  @override
  String get removePassword => 'Remove password';

  @override
  String get changeAccountNumber => 'Change my number';

  @override
  String get changeNumberExplainer =>
      'We will send a code to your current number first, then to the new one.';

  @override
  String get currentNumberCode => 'Code sent to your current number';

  @override
  String get newNumberCode => 'Code sent to the new number';

  @override
  String get newNumberLabel => 'New number';

  @override
  String get numberChanged => 'Your number was changed';

  @override
  String payoutsFrozenUntil(String date) {
    return 'Payouts are on hold until $date';
  }

  @override
  String get otherSessionsEnded => 'All other sessions were ended';

  @override
  String get recoveryCodes => 'Recovery codes';

  @override
  String recoveryCodesRemaining(int count) {
    return '$count unused';
  }

  @override
  String get generateRecoveryCodes => 'Generate new codes';

  @override
  String get recoveryCodesWarning =>
      'Write these down now. They are shown once, and generating a new set cancels the old one.';

  @override
  String get lostYourSim => 'Lost your SIM?';

  @override
  String get lostSimExplainer =>
      'If your number is gone for good, we can review your account by hand. It takes several days on purpose.';

  @override
  String get recoveryNoDocuments =>
      'We will never ask for a photo of you or of an identity document.';

  @override
  String get recoveryContactNumber => 'A number we can reach you on now';

  @override
  String get recoveryQuestionsTitle => 'What do you remember?';

  @override
  String get recoveryQuestionsHint =>
      'Answer what you can. Nothing here is required.';

  @override
  String get recoveryRegistrationMonth =>
      'Roughly when did you join? (YYYY-MM)';

  @override
  String get recoveryLastOrderMonth => 'When was your last order? (YYYY-MM)';

  @override
  String get recoveryLastOrderTotal => 'Roughly what did it come to?';

  @override
  String get recoveryDeviceLabel => 'What is one of your devices called?';

  @override
  String get recoverySubmitted => 'We received your request';

  @override
  String get recoveryKeepSecret =>
      'Keep this reference. It is the only way to check on your request.';

  @override
  String get recoveryCaseOpenWarning =>
      'Someone asked to move your account to another number.';

  @override
  String recoveryCaseCoolOff(String date) {
    return 'Your account moves on $date unless you stop it.';
  }

  @override
  String get stopThisRequest => 'That was not me — stop it';

  @override
  String get recoveryCaseCancelled => 'The request was stopped';

  @override
  String get activeSessions => 'Active sessions';

  @override
  String get thisDevice => 'This device';

  @override
  String get signOutEverywhere => 'Sign out everywhere else';

  @override
  String sessionExpiresOn(String date) {
    return 'Signed in until $date';
  }

  @override
  String get deviceTrusted => 'Verified on this device';

  @override
  String get deviceNotVerified => 'Never signed in from here';

  @override
  String newDeviceCooldown(String date) {
    return 'This device is new. Sensitive changes unlock $date.';
  }

  @override
  String get verifyToContinue => 'Verify it is you';

  @override
  String get sendCode => 'Send the code';

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get homeShowcaseEyebrow => 'Straight from the boutiques';

  @override
  String get homeShowcaseTitle => 'New in';

  @override
  String get homeShowcaseSubtitle =>
      'The newest pieces, told as stories — swipe, love, shop.';

  @override
  String get homeShapePosts => 'Posts';

  @override
  String get homeShapeMosaic => 'Mosaic';

  @override
  String get homeShapeGrid => 'Grid';

  @override
  String postLikesCount(String count) {
    return '$count loves';
  }

  @override
  String postViewComments(String count) {
    return 'View all $count comments';
  }

  @override
  String get postMore => 'more';

  @override
  String shortMinutesAgo(int count) {
    return '${count}m';
  }

  @override
  String shortHoursAgo(int count) {
    return '${count}h';
  }

  @override
  String shortDaysAgo(int count) {
    return '${count}d';
  }

  @override
  String shortWeeksAgo(int count) {
    return '${count}w';
  }

  @override
  String get homeBoutiqueStories => 'Boutique stories';

  @override
  String piecesCount(String count) {
    return '$count pieces';
  }

  @override
  String get justIn => 'Just in';

  @override
  String get addedToBag => 'Added to your bag';

  @override
  String get sellerCommandCentre => 'Command centre';

  @override
  String get sellerDashboardUnavailable => 'Dashboard unavailable';

  @override
  String get messages => 'Messages';

  @override
  String get sellerNeedsYou => 'Needs you now';

  @override
  String get sellerAllClear => 'All clear — nothing is waiting on you';

  @override
  String get sellerPendingOrders => 'To confirm';

  @override
  String get sellerRunningLow => 'Running low';

  @override
  String get sellerOpenTasks => 'Open tasks';

  @override
  String get sellerRevenue => 'Revenue';

  @override
  String get sellerProfit => 'Profit';

  @override
  String get sellerMargin => 'Margin';

  @override
  String get sellerVsPrior => 'vs. prior period';

  @override
  String get periodToday => 'Today';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get periodDaily => 'Daily';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get periodYearly => 'Yearly';

  @override
  String get sellerSalesTrend => 'Sales trend';

  @override
  String get sellerQuickActions => 'Quick actions';

  @override
  String get sellerAddProduct => 'Add product';

  @override
  String get sellerManageOrders => 'Manage orders';

  @override
  String get sellerAnalytics => 'Analytics';

  @override
  String get sellerCreateCoupon => 'Create coupon';

  @override
  String get sellerAnnouncement => 'Announcement';

  @override
  String get sellerManageAll => 'Manage all';

  @override
  String get sellerTopProducts => 'Best sellers';

  @override
  String get sellerLowStockTitle => 'Low stock';

  @override
  String get sellerOutOfStock => 'Out of stock';

  @override
  String get sellerRestock => 'Restock';

  @override
  String get sellerStorePerformance => 'Store health';

  @override
  String get sellerFulfillment => 'Fulfillment';

  @override
  String get sellerResponsiveness => 'Responsiveness';

  @override
  String get sellerProductQuality => 'Product quality';

  @override
  String get sellerConversionMetrics => 'Conversion';

  @override
  String get sellerConversionRate => 'Conversion rate';

  @override
  String get sellerProductViews => 'Product views';

  @override
  String get sellerCartAdds => 'Cart adds';

  @override
  String get sellerWishlistAdds => 'Wishlist adds';

  @override
  String get sellerInsights => 'Smart insights';

  @override
  String get sellerRecentReviews => 'Recent reviews';

  @override
  String get sellerTasks => 'To-do list';

  @override
  String get sellerGoals => 'Store goals';

  @override
  String get orderNew => 'New';

  @override
  String get orderProcessing => 'Processing';

  @override
  String get orderReady => 'Ready';

  @override
  String get orderDelivered => 'Delivered';

  @override
  String get orderCancelled => 'Cancelled';

  @override
  String get orderReturned => 'Returned';

  @override
  String get sellerLiveStore => 'Store is live';

  @override
  String get sellerGroupStore => 'Store management';

  @override
  String get sellerGroupBusiness => 'Business & finance';

  @override
  String get sellerGroupPreferences => 'Preferences & security';

  @override
  String get sellerShippingSettings => 'Shipping settings';

  @override
  String get sellerPaymentSettings => 'Payment settings';

  @override
  String get sellerStorePolicies => 'Store policies';

  @override
  String get sellerFinancialReports => 'Financial reports';

  @override
  String get sellerWithdrawalCentre => 'Withdrawal centre';

  @override
  String get sellerTeamManagement => 'Team management';

  @override
  String get sellerSubscriptionPlan => 'Subscription & plan';

  @override
  String get sellerActivityLog => 'Activity log';

  @override
  String get sellerSupport => 'Seller support';

  @override
  String get sellerAvailableToWithdraw => 'Available to withdraw';

  @override
  String get sellerWithdraw => 'Withdraw';

  @override
  String get sellerPaidOut => 'Paid out';

  @override
  String get sellerFees => 'Fees';

  @override
  String get sellerPendingPayout => 'Pending';

  @override
  String get sellerEditStore => 'Edit store';

  @override
  String sellerPlanBadge(String plan) {
    return '$plan plan';
  }

  @override
  String sellerMemberSince(String year) {
    return 'Selling since $year';
  }

  @override
  String sellerRatingSummary(String rating, String count) {
    return '$rating · $count reviews';
  }

  @override
  String sellerPlatformFooter(String version) {
    return 'Seller platform · v$version';
  }

  @override
  String get sellerNoProductsYet => 'No products yet';

  @override
  String get sellerNoProductsBlurb =>
      'Add your first piece and it will show up here.';

  @override
  String get sellerNewProduct => 'New product';

  @override
  String get sellerEditProduct => 'Edit';

  @override
  String get sellerSetActive => 'Publish';

  @override
  String get sellerMoveToDraft => 'Move to draft';

  @override
  String get sellerArchive => 'Archive';

  @override
  String sellerStock(String count) {
    return '$count in stock';
  }

  @override
  String get surfaceActivity => 'Activity';

  @override
  String get surfaceCustomers => 'Customers';

  @override
  String get surfaceMarketing => 'Marketing';

  @override
  String savedCount(String count) {
    return '$count saves';
  }

  @override
  String get formNewProduct => 'New product';

  @override
  String get formEditProduct => 'Edit product';

  @override
  String get formTitle => 'Title';

  @override
  String get formTitleRequired => 'A title is required';

  @override
  String get formDescription => 'Description';

  @override
  String get formDescriptionRequired => 'A description is required';

  @override
  String get formCategory => 'Category';

  @override
  String get formCategoryRequired => 'A category is required';

  @override
  String get formPrice => 'Price';

  @override
  String get formPriceInvalid => 'Enter a valid price';

  @override
  String get formStock => 'Stock';

  @override
  String get formStockInvalid => 'Enter a valid quantity';

  @override
  String get formStatus => 'Status';

  @override
  String get formFeatured => 'Featured';

  @override
  String get formShowInFeed => 'Show in feed';

  @override
  String get formAddImage => 'Add photo';

  @override
  String get formAddVariant => 'Add variant';

  @override
  String get formPublishProduct => 'Publish product';

  @override
  String get formProductCreated => 'Product published';

  @override
  String get formProductUpdated => 'Changes saved';

  @override
  String get formAiDescription => 'Write with AI';

  @override
  String get formAiDescriptionAdded => 'Description drafted';

  @override
  String get formAiTags => 'Suggest tags';

  @override
  String get formNoTags => 'No tags suggested';

  @override
  String get formTitleCategoryFirst => 'Add a title and a category first';

  @override
  String get categories => 'Categories';

  @override
  String get adminSettings => 'Administrator settings';

  @override
  String get adminSecurity => 'Security';

  @override
  String get adminUserManagement => 'User management';

  @override
  String get adminSellerManagement => 'Seller management';

  @override
  String get adminProductManagement => 'Product management';

  @override
  String get adminOrderManagement => 'Order management';

  @override
  String get adminFinancialManagement => 'Financial management';

  @override
  String get adminCommissionManagement => 'Commission management';

  @override
  String get adminReportsAndAnalytics => 'Reports and analytics';

  @override
  String get adminReports => 'Reports';

  @override
  String get adminModerationTools => 'Moderation tools';

  @override
  String get adminSupportManagement => 'Support management';

  @override
  String get adminAuditLogs => 'Audit logs';

  @override
  String get adminSystemSettings => 'System settings';

  @override
  String get adminNotificationCampaigns => 'Notification campaigns';

  @override
  String get adminNotificationAnalytics => 'Notification analytics';

  @override
  String get adminSectionSubtitle =>
      'Operational controls, review queues, and live records.';

  @override
  String get adminSectionUnavailable => 'Unable to load this section.';

  @override
  String get adminNoMatchingRecords => 'No matching records found.';

  @override
  String get adminNoDataYet => 'No data yet.';

  @override
  String get adminNoRankedData => 'No ranked data yet.';

  @override
  String get adminNoRecentActivity => 'No recent administrative activity.';

  @override
  String get adminAuditUnavailable => 'Audit stream unavailable';

  @override
  String get adminRetryFromAudit => 'Retry from audit logs';

  @override
  String get adminClearSearch => 'Clear search';

  @override
  String get adminQuickActions => 'Quick actions';

  @override
  String get adminRecentActivity => 'Recent activity';

  @override
  String get adminOnlineNow => 'Online now';

  @override
  String get adminVerifiedSellersOnly => 'Verified sellers only';

  @override
  String get adminRoleFilterHint => 'USER, SELLER, ADMIN';

  @override
  String get adminSellerReview => 'Seller review';

  @override
  String get adminSupportQueue => 'Support queue';

  @override
  String get adminModeration => 'Moderation';

  @override
  String get adminFinancials => 'Financials';

  @override
  String get adminCustomers => 'Customers';

  @override
  String get adminCampaigns => 'Campaigns';

  @override
  String get adminNotifyAnalytics => 'Notify analytics';

  @override
  String get adminBusinessIntelligence => 'Business intelligence';

  @override
  String get adminAnalyticsSubtitle =>
      'Sales, revenue, conversion, cohorts, and live operations.';

  @override
  String get adminRevenueTrend => 'Revenue trend';

  @override
  String get adminConversionFunnel => 'Conversion funnel';

  @override
  String get adminTopProducts => 'Top products';

  @override
  String get adminSellerPerformance => 'Seller performance';

  @override
  String get adminGrossRevenue => 'Gross revenue';

  @override
  String get adminNetRevenue => 'Net revenue';

  @override
  String get adminAov => 'Average order value';

  @override
  String get adminRepeatRate => 'Repeat rate';

  @override
  String get adminRetentionRate => 'Retention';

  @override
  String get adminExportExcel => 'Export Excel';

  @override
  String get adminExportPdf => 'Export PDF';

  @override
  String get adminNewCampaign => 'New campaign';

  @override
  String get adminNewCampaignTitle => 'New notification campaign';

  @override
  String get adminCampaignName => 'Campaign name';

  @override
  String get adminNotificationTitle => 'Notification title';

  @override
  String get adminMessageBody => 'Message body';

  @override
  String get adminChannels => 'Channels';

  @override
  String get adminRunCampaign => 'Run campaign';

  @override
  String get adminCampaignCreated => 'Campaign created.';

  @override
  String get adminCampaignQueued => 'Campaign queued for delivery.';

  @override
  String get adminCampaignFieldsRequired =>
      'Name, title, and body are required.';

  @override
  String get adminSelectChannel => 'Select at least one channel.';

  @override
  String get adminScheduleIsoHint => 'Use an ISO schedule time.';

  @override
  String get create => 'Create';

  @override
  String adminLastDays(int count) {
    return 'Last $count days';
  }

  @override
  String get sellerDeleteProduct => 'Delete product?';

  @override
  String sellerDeleteProductBody(String title) {
    return '“$title” will be permanently removed.';
  }

  @override
  String get mediaSourceTitle => 'Add a photo';

  @override
  String get mediaFromCamera => 'Take a photo';

  @override
  String get mediaFromGallery => 'Choose from gallery';

  @override
  String get mediaUploading => 'Uploading…';

  @override
  String get mediaUploadFailed => 'Upload failed';

  @override
  String get mediaRemovePhoto => 'Remove photo';

  @override
  String get mediaCoverBadge => 'Cover';

  @override
  String get mediaPickFailed =>
      'Could not open your photos. Check the app\'s photo permission in Settings.';

  @override
  String get mediaProductGallery => 'Product photos';

  @override
  String get mediaStoryLabel => 'Story image';

  @override
  String get mediaWaitForUploads => 'Wait for the photos to finish uploading.';

  @override
  String mediaGalleryHint(int count) {
    return 'The first photo is the cover. Up to $count photos.';
  }

  @override
  String get mediaStoryRequired => 'Choose an image for the story first.';

  @override
  String get storeLogo => 'Store logo';

  @override
  String get governmentIdDocument => 'Photo of your ID';

  @override
  String get businessLicenseDocument => 'Commercial register or licence';

  @override
  String get verificationDocumentsPrivate =>
      'Only you and the review team can open these. They never appear on your store.';

  @override
  String get verificationDocumentsHint =>
      'Photograph each document in full, in good light.';

  @override
  String get verificationSectionStore => 'Your store';

  @override
  String get verificationSectionContact => 'Contact and addresses';

  @override
  String get verificationSectionDocuments => 'Documents';

  @override
  String get verificationSectionPayout => 'Bank account';

  @override
  String get verificationSectionOperations => 'Shipping and returns';

  @override
  String get shippingMethodsHint => 'Courier, pickup, same-day';

  @override
  String get productCategoriesHint => 'Fashion, perfume, handmade';

  @override
  String get verificationResubmitNotice =>
      'You have applied before. Editing and submitting replaces that application.';

  @override
  String get mediaDocumentAttached => 'Attached';

  @override
  String get verificationUploadPending =>
      'Wait for the documents to finish uploading.';

  @override
  String verificationFieldRequired(String field) {
    return '«$field» is required.';
  }

  @override
  String get verificationStatusPending => 'Pending';

  @override
  String get verificationStatusUnderReview => 'Under review';

  @override
  String get verificationStatusNeedsMoreDocuments => 'More documents needed';

  @override
  String get verificationStatusNeedsMoreInfo => 'More information needed';

  @override
  String get verificationStatusApproved => 'Approved';

  @override
  String get verificationStatusRejected => 'Rejected';

  @override
  String get verificationStatusSuspended => 'Suspended';

  @override
  String get mediaFromFiles => 'Choose a file';

  @override
  String get mediaDocumentsHint => 'A clear photograph, or the original PDF.';

  @override
  String mediaTooLarge(String size) {
    return 'This file is larger than $size MB.';
  }

  @override
  String get chatAttachTitle => 'Attach a photo';

  @override
  String get chatAttachmentFailed => 'The photo could not be sent.';

  @override
  String get chatSharedMedia => 'Shared photos';

  @override
  String get chatNoSharedMedia => 'Nothing has been shared here yet.';

  @override
  String get chatPhotoMessage => 'Photo';

  @override
  String get chatStartConversation => 'Start the conversation';

  @override
  String get chatStartConversationHint =>
      'Ask about the piece, the size or the delivery — or send a photo or a voice note.';

  @override
  String get chatShareImage => 'Send a photo';

  @override
  String get voicePermissionDenied =>
      'Reem needs permission to use the microphone.';

  @override
  String get voiceRecordFailed => 'Recording could not start.';

  @override
  String get voiceSend => 'Send the recording';

  @override
  String get voiceRecord => 'Record a voice note';

  @override
  String get voiceMessage => 'Voice note';

  @override
  String get voiceUnavailable => 'This recording is unavailable.';

  @override
  String get chatFromFiles => 'Send a file';

  @override
  String get chatOpenFileFailed => 'No app on this phone can open this file.';

  @override
  String get chatFileMessage => 'File';

  @override
  String get chatDownloadFailed => 'The file could not be downloaded.';

  @override
  String get sellerOrdersTitle => 'My orders';

  @override
  String get sellerOrdersTabNew => 'New';

  @override
  String get sellerOrdersTabPreparing => 'Preparing';

  @override
  String get sellerOrdersTabReady => 'Ready';

  @override
  String get sellerOrdersTabShipping => 'On the way';

  @override
  String get sellerOrdersTabReturns => 'Returns';

  @override
  String get sellerOrdersTabCompleted => 'Completed';

  @override
  String get sellerOrdersOffline => 'No internet connection';

  @override
  String get sellerOrdersLoadFailed => 'Could not open this order';

  @override
  String get sellerOrdersUpdated => 'Order updated';

  @override
  String get sellerOrdersEmptyNew => 'No new orders';

  @override
  String get sellerOrdersEmptyPreparing => 'Nothing being prepared';

  @override
  String get sellerOrdersEmptyReady => 'Nothing ready to ship';

  @override
  String get sellerOrdersEmptyShipping => 'No parcels on the way';

  @override
  String get sellerOrdersEmptyReturns => 'No returns';

  @override
  String get sellerOrdersEmptyCompleted => 'No completed orders yet';

  @override
  String get sellerOrdersEmptyNewBody =>
      'Orders appear here the moment a customer buys from you.';

  @override
  String get sellerOrdersEmptyReturnsBody => 'Which is good news.';

  @override
  String get sellerOrdersEmptyBody => 'Orders move here as they progress.';

  @override
  String get sellerOrderActionConfirm => 'Accept order';

  @override
  String get sellerOrderActionReady => 'Ready to ship';

  @override
  String get sellerOrderActionHandOver => 'Handed over';

  @override
  String get sellerOrderActionDeliver => 'Delivered';

  @override
  String get sellerOrderActionCancel => 'Cancel order';

  @override
  String get sellerOrderConfirmed =>
      'Accepted — the order is now being prepared';

  @override
  String get sellerOrderMarkedReady => 'The order is ready to ship';

  @override
  String get sellerOrderHandedOver => 'Handover recorded';

  @override
  String get sellerOrderDelivered => 'Delivery recorded';

  @override
  String get sellerOrderCancelled =>
      'Order cancelled and the items returned to stock';

  @override
  String get sellerParcelStatusNew => 'New order';

  @override
  String get sellerParcelStatusAwaitingConfirmation =>
      'Awaiting your confirmation';

  @override
  String get sellerParcelStatusPreparing => 'Being prepared';

  @override
  String get sellerParcelStatusReadyToShip => 'Ready to ship';

  @override
  String get sellerParcelStatusHandedToCourier => 'With the courier';

  @override
  String get sellerParcelStatusInTransit => 'On the way';

  @override
  String get sellerParcelStatusDelivered => 'Delivered';

  @override
  String get sellerParcelStatusDeliveryFailed => 'Delivery failed';

  @override
  String get sellerParcelStatusCancelledByCustomer =>
      'Cancelled by the customer';

  @override
  String get sellerParcelStatusCancelledBySeller => 'You cancelled it';

  @override
  String get sellerParcelStatusRejectedOnDelivery => 'Refused at the door';

  @override
  String get sellerParcelStatusReturnRequested => 'Return requested';

  @override
  String get sellerParcelStatusReturnInTransit => 'Return on its way';

  @override
  String get sellerParcelStatusReturned => 'Return received';

  @override
  String get sellerParcelStatusExchangeInProgress => 'Exchange in progress';

  @override
  String get sellerParcelStatusExchanged => 'Exchanged';

  @override
  String get sellerParcelStatusRefundPending => 'Refund pending';

  @override
  String get sellerParcelStatusRefunded => 'Refunded';

  @override
  String get sellerParcelStatusDisputed => 'In dispute';

  @override
  String get sellerFulfilmentPlatformCourier => 'Platform courier';

  @override
  String get sellerFulfilmentThirdParty => 'Shipping company';

  @override
  String get sellerFulfilmentSelfShips => 'You deliver it';

  @override
  String get sellerFulfilmentPickupPoint => 'Pickup point';

  @override
  String get sellerOrderCashOnDelivery => 'Cash on delivery';

  @override
  String get sellerOrderItemsToPack => 'What to pack';

  @override
  String get sellerOrderStepPlaced => 'Order received';

  @override
  String get sellerOrderStepConfirmed => 'You accepted it';

  @override
  String get sellerOrderStepShipped => 'Left for delivery';

  @override
  String get sellerOrderStepDelivered => 'Delivered';

  @override
  String get sellerOrderCourierAssigned => 'Courier assigned';

  @override
  String get sellerOrderCourierPending => 'Awaiting a courier';

  @override
  String get sellerOrderItemsSubtotal => 'Items subtotal';

  @override
  String get sellerOrderDiscount => 'Discount';

  @override
  String get sellerOrderCommission => 'Platform commission';

  @override
  String get sellerOrderNet => 'Your net earnings';

  @override
  String get sellerOrderEscrowReleased =>
      'These earnings are now available for payout.';

  @override
  String get sellerOrderEscrowPending =>
      'Earnings are counted after delivery and once the return window closes.';

  @override
  String get sellerOrderCallCustomer => 'Call the customer';

  @override
  String get sellerOrderAddressCopied => 'Address copied';

  @override
  String get sellerCancelSubtitle =>
      'The items go back to your stock, and the customer is told the reason you write.';

  @override
  String get sellerCancelReasonLabel => 'Reason';

  @override
  String get sellerCancelReasonHint =>
      'Write a reason the customer will understand';

  @override
  String get sellerCancelReasonTooShort =>
      'Write a reason of at least five characters';

  @override
  String get sellerCancelConfirm => 'Confirm cancellation';

  @override
  String get sellerCancelDismiss => 'Go back';

  @override
  String get sellerCancelPresetOutOfStock => 'Out of stock';

  @override
  String get sellerCancelPresetSizeGone => 'That size has run out';

  @override
  String get sellerCancelPresetPriceError => 'The listed price was wrong';

  @override
  String get sellerCancelPresetNoTime => 'I cannot prepare it in time';

  @override
  String get sellerDeliverTitle => 'Confirm delivery';

  @override
  String get sellerDeliverSubtitleCash =>
      'Enter what you actually collected. Leave it empty if you collected the full amount.';

  @override
  String get sellerDeliverSubtitlePrepaid =>
      'This order is prepaid — there is nothing to collect.';

  @override
  String get sellerDeliverCollectedLabel => 'Amount collected';

  @override
  String get sellerDeliverCollectedHint =>
      'Leave empty if you collected the full amount';

  @override
  String sellerOrderEscrowOn(String date) {
    return 'Earnings become available once the return window closes on $date.';
  }

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutDeliveryAddress => 'Delivery address';

  @override
  String get checkoutSavedAddresses => 'Your saved addresses';

  @override
  String get checkoutNewAddress => 'New address';

  @override
  String get checkoutUseThisAddress => 'Deliver here';

  @override
  String get checkoutSaveAddress => 'Save this address for next time';

  @override
  String get checkoutRecipientName => 'Recipient name';

  @override
  String get checkoutRecipientPhone => 'Phone number';

  @override
  String get checkoutGovernorate => 'Governorate';

  @override
  String get checkoutDistrict => 'District';

  @override
  String get checkoutDistrictOptional => 'District (optional)';

  @override
  String get checkoutCity => 'City or town';

  @override
  String get checkoutAddressLine => 'Detailed address';

  @override
  String get checkoutAddressLineHint => 'Street, building number, floor';

  @override
  String get checkoutLandmark => 'Nearby landmark (optional)';

  @override
  String get checkoutLandmarkHint => 'Opposite the pharmacy';

  @override
  String get checkoutInstructions => 'Delivery notes (optional)';

  @override
  String get checkoutInstructionsHint => 'Call before arriving';

  @override
  String get checkoutRural => 'This is a rural area';

  @override
  String get checkoutRuralHint =>
      'The fee and the time differ from the city centre';

  @override
  String get checkoutCoupon => 'Discount coupon';

  @override
  String get checkoutCouponOptional => 'Coupon code (optional)';

  @override
  String get checkoutPaymentMethod => 'Payment method';

  @override
  String get checkoutOrderSummary => 'Order summary';

  @override
  String get checkoutSubtotal => 'Subtotal';

  @override
  String get checkoutDelivery => 'Delivery';

  @override
  String get checkoutPlaceOrder => 'Place order';

  @override
  String get checkoutRequired => 'This field is required';

  @override
  String get checkoutInvalidPhone => 'Enter a valid phone number';

  @override
  String get checkoutChooseGovernorate => 'Choose a governorate';

  @override
  String get checkoutChoosePayment => 'Choose a payment method';

  @override
  String get checkoutTotalPending =>
      'The final total is calculated when you place the order';

  @override
  String checkoutPlacedSuccess(String number) {
    return 'Your order $number is confirmed';
  }

  @override
  String checkoutSplitNotice(String count) {
    return 'Your order is from $count sellers and arrives in several parcels — with one delivery fee.';
  }
}
