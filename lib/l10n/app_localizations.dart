import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Reem'**
  String get appTitle;

  /// Tagline under the logo on the splash screen
  ///
  /// In en, this message translates to:
  /// **'Where beauty meets social shopping'**
  String get splashTagline;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get stories;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Button on an error state
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Trailing action on a section header. Was hardcoded in seven widgets.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get viewAll;

  /// Expands truncated content
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// Closes a sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Applies filters
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Clears filters or a field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Home greeting before noon
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// Home greeting after noon
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// Home greeting in the evening
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// Auth screen heading
  ///
  /// In en, this message translates to:
  /// **'Welcome to Reem'**
  String get welcomeToReem;

  /// Returning-user heading
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signup;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account?'**
  String get signOutConfirm;

  /// Subtitle under the login heading
  ///
  /// In en, this message translates to:
  /// **'Sign in to shop, share and shine'**
  String get loginSubtitle;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Link
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgetPassword;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validEmailRequired;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Password length rule
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String passwordMinLength(int count);

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get confirmPasswordMismatch;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get productDetails;

  /// Primary product action
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// Primary product action
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get buyNow;

  /// Cart line action
  ///
  /// In en, this message translates to:
  /// **'Remove from cart'**
  String get removeFromCart;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// Adds to favourites
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get favorite;

  /// Already in favourites
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get unfavorite;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// Availability badge
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// Availability badge
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Today\'s offers'**
  String get todayOffers;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Best selling'**
  String get bestSeller;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'New arrivals'**
  String get newArrivals;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Picked for you'**
  String get recommended;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get trendingNow;

  /// Home rail subtitle
  ///
  /// In en, this message translates to:
  /// **'Most loved this week'**
  String get trendingSubtitle;

  /// Search field placeholder. Four different wordings existed before.
  ///
  /// In en, this message translates to:
  /// **'Search dresses, beauty, gifts…'**
  String get searchHint;

  /// How many sellers list this product
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seller} other{{count} sellers}}'**
  String sellersOffering(int count);

  /// Opens the list of competing offers
  ///
  /// In en, this message translates to:
  /// **'Compare prices'**
  String get comparePrices;

  /// Lowest offer on a product card
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String priceFrom(String price);

  /// Names the seller behind the shown offer
  ///
  /// In en, this message translates to:
  /// **'Sold by {seller}'**
  String soldBy(String seller);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get emptyCart;

  /// Empty state button
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get emptyCartAction;

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Checkout primary action
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// Validation message on checkout
  ///
  /// In en, this message translates to:
  /// **'Choose your governorate'**
  String get selectGovernorate;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get orderSummary;

  /// Shown when a basket spans several sellers
  ///
  /// In en, this message translates to:
  /// **'Your order is from {count} sellers and will arrive in separate parcels — with one delivery charge.'**
  String splitOrderNotice(int count);

  /// Delivery estimate
  ///
  /// In en, this message translates to:
  /// **'Arriving today'**
  String get etaSameDay;

  /// Delivery estimate
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Arriving within a day} other{Arriving within {count} days}}'**
  String etaDays(int count);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetails;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Order status'**
  String get orderStatus;

  /// Section title on a split order
  ///
  /// In en, this message translates to:
  /// **'Parcels'**
  String get parcels;

  /// Shipment tracking line
  ///
  /// In en, this message translates to:
  /// **'Tracking number {code}'**
  String trackingNumber(String code);

  /// Order action
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// Order action
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get reorder;

  /// Order action
  ///
  /// In en, this message translates to:
  /// **'Request a return'**
  String get requestReturn;

  /// Item count on an order card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// Stories rail title
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get moments;

  /// Story composer action
  ///
  /// In en, this message translates to:
  /// **'Share your moment'**
  String get shareMoment;

  /// Story composer action
  ///
  /// In en, this message translates to:
  /// **'Add a story'**
  String get addStory;

  /// Story composer action
  ///
  /// In en, this message translates to:
  /// **'Add your moment'**
  String get addMoment;

  /// Publish button
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// Comment field hint
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get writeComment;

  /// Opens the comment sheet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{View 1 comment} other{View all {count} comments}}'**
  String viewAllComments(int count);

  /// Counter label
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// Counter label
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// Follows a seller
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// Already following a seller
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// Profile stat
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Rewards and offers'**
  String get rewardsAndOffers;

  /// Counter label
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get coupons;

  /// Coupon count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 coupon} other{{count} coupons}}'**
  String couponsCount(int count);

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Add a coupon'**
  String get addCoupon;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Apply coupon'**
  String get applyCoupon;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'This coupon is not valid'**
  String get invalidCoupon;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Coupon applied'**
  String get usedCoupon;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Help centre'**
  String get helpCenter;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethods;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Appearance screen description
  ///
  /// In en, this message translates to:
  /// **'Choose how Reem looks on your device. Your choice is saved automatically.'**
  String get appearanceDescription;

  /// Theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Soft rose and daytime elegance'**
  String get themeLightSubtitle;

  /// Theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Deep plum with a rose glow'**
  String get themeDarkSubtitle;

  /// Theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Follows your device settings'**
  String get themeSystemSubtitle;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Light theme is on'**
  String get themeLightActive;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Dark theme is on'**
  String get themeDarkActive;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Following the system theme'**
  String get themeSystemActive;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Status badge
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get active;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get selectLanguage;

  /// Language option. The previous Arabic was ungrammatical.
  ///
  /// In en, this message translates to:
  /// **'Follow the device language'**
  String get followDeviceLanguage;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// Language name
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get ar;

  /// Language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get en;

  /// Generic success
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get success;

  /// Generic failure
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyFeed;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No stories right now'**
  String get emptyStories;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty'**
  String get emptyWishlist;

  /// Empty search state
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String emptySearch(String query);

  /// Network error state
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noConnection;

  /// Seller screen title
  ///
  /// In en, this message translates to:
  /// **'Store dashboard'**
  String get sellerDashboard;

  /// Seller screen title
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get myProducts;

  /// Seller screen title
  ///
  /// In en, this message translates to:
  /// **'My earnings'**
  String get myEarnings;

  /// Admin screen title
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminPanel;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminDashboard;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get adminOrders;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get adminProducts;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get adminAnalytics;

  /// Admin greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get adminWelcome;

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get adminTotalSales;

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get adminTotalOrders;

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Active users'**
  String get adminActiveUsers;

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Conversion rate'**
  String get adminConversion;

  /// Admin section
  ///
  /// In en, this message translates to:
  /// **'Recent orders'**
  String get adminRecentOrders;

  /// Admin action
  ///
  /// In en, this message translates to:
  /// **'Manage catalogue'**
  String get adminManageCatalog;

  /// Admin action
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get adminViewReports;

  /// Admin action
  ///
  /// In en, this message translates to:
  /// **'Back to the shop'**
  String get adminBackToShop;

  /// Screen-reader label for the back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a11yBack;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get a11yClose;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get a11ySearch;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get a11yCart;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get a11yNotifications;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get a11yProfile;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get a11yLike;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get a11yShare;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get a11ySave;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get a11yMore;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get a11yPlay;

  /// Login field label
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get emailOrPhone;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Email or phone is required'**
  String get emailOrPhoneRequired;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email or phone number'**
  String get validEmailOrPhone;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get validPhone;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameRequired;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// Password policy hint
  ///
  /// In en, this message translates to:
  /// **'Use upper and lower case letters, a number, and a symbol.'**
  String get passwordStrengthRule;

  /// Password strength
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordWeak;

  /// Password strength
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordGood;

  /// Password strength
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrong;

  /// Password meter caption
  ///
  /// In en, this message translates to:
  /// **'Password strength: {label}'**
  String passwordStrengthLabel(String label);

  /// Auth prompt
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// Auth gate title
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get signInRequired;

  /// Auth gate action
  ///
  /// In en, this message translates to:
  /// **'Sign in to checkout'**
  String get signInToCheckout;

  /// Auth alternative
  ///
  /// In en, this message translates to:
  /// **'Continue as a guest'**
  String get continueAsGuest;

  /// Confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutQuestion;

  /// Confirm dialog body
  ///
  /// In en, this message translates to:
  /// **'You can always sign back in.'**
  String get signBackInLater;

  /// OTP screen title
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get verifyYourPhone;

  /// OTP field label
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// OTP validation
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code.'**
  String get enterVerificationCode;

  /// OTP subtitle
  ///
  /// In en, this message translates to:
  /// **'We sent a one-time code to {phone}.'**
  String codeSentTo(String phone);

  /// OTP toast
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your phone.'**
  String get codeSent;

  /// OTP action
  ///
  /// In en, this message translates to:
  /// **'Resend the code'**
  String get resendCode;

  /// OTP progress
  ///
  /// In en, this message translates to:
  /// **'Requesting a one-time code…'**
  String get requestingCode;

  /// OTP action
  ///
  /// In en, this message translates to:
  /// **'Verify the code'**
  String get verifyCode;

  /// OTP toast
  ///
  /// In en, this message translates to:
  /// **'Verification complete.'**
  String get verificationComplete;

  /// OTP toast
  ///
  /// In en, this message translates to:
  /// **'Phone number verified.'**
  String get phoneVerified;

  /// Onboarding success
  ///
  /// In en, this message translates to:
  /// **'You are all set ✨'**
  String get allSet;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetYourPassword;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please sign in again.'**
  String get passwordUpdatedSignInAgain;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get securityTitle;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Secure account controls'**
  String get secureAccountControls;

  /// Section description
  ///
  /// In en, this message translates to:
  /// **'Manage sessions, devices, recovery, and checkout details.'**
  String get manageSecurityBlurb;

  /// Security section
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No active sessions.'**
  String get noActiveSessions;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Revoke the session'**
  String get revokeSession;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Log out everywhere'**
  String get logOutAll;

  /// Security section
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No devices yet.'**
  String get noDevicesYet;

  /// Device name fallback
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get unknownDevice;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Rename the device'**
  String get renameDevice;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Device updated.'**
  String get deviceUpdated;

  /// Device action
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get trust;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Remember this device'**
  String get rememberThisDevice;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Verify new devices'**
  String get verifyNewDevices;

  /// Toggle description
  ///
  /// In en, this message translates to:
  /// **'Flag new devices for verification.'**
  String get flagNewDevices;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'OTP on sensitive actions'**
  String get otpOnSensitive;

  /// Toggle description
  ///
  /// In en, this message translates to:
  /// **'Require an OTP for risky changes.'**
  String get otpOnSensitiveDescription;

  /// Security section
  ///
  /// In en, this message translates to:
  /// **'Linked accounts'**
  String get linkedAccounts;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Seller verification'**
  String get sellerVerification;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Submit for verification'**
  String get submitVerification;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Seller verification submitted.'**
  String get verificationSubmitted;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'No verification submitted'**
  String get noVerificationSubmitted;

  /// Section description
  ///
  /// In en, this message translates to:
  /// **'Submit business details to unlock seller trust.'**
  String get submitBusinessDetails;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Complete all required seller application fields.'**
  String get completeSellerFields;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get unverified;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Business address'**
  String get businessAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Business category'**
  String get businessCategory;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Commercial registration'**
  String get commercialRegistration;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get taxNumber;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Owner legal name'**
  String get ownerLegalName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Contact email'**
  String get contactEmail;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhone;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get bankName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Account holder'**
  String get accountHolder;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Warehouse address'**
  String get warehouseAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Shipping methods'**
  String get shippingMethods;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Product categories'**
  String get productCategories;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get yearsOfExperience;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Store description'**
  String get storeDescription;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Store logo URL'**
  String get storeLogoUrl;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Government ID URL'**
  String get governmentIdUrl;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Business license URL'**
  String get businessLicenseUrl;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Additional documents'**
  String get additionalDocuments;

  /// Guest screen title
  ///
  /// In en, this message translates to:
  /// **'Your guest profile'**
  String get guestProfile;

  /// Guest prompt
  ///
  /// In en, this message translates to:
  /// **'Your cart is safe. Sign in to place orders, save addresses, and track delivery.'**
  String get guestCartSafe;

  /// Guest benefit title
  ///
  /// In en, this message translates to:
  /// **'Save your progress'**
  String get saveYourProgress;

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Keep favorites, carts, orders, and recently viewed pieces.'**
  String get savedProgressBlurb;

  /// Guest benefit title
  ///
  /// In en, this message translates to:
  /// **'Use every device'**
  String get useEveryDevice;

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Continue from phone, web, or tablet securely.'**
  String get useEveryDeviceBlurb;

  /// Guest benefit title
  ///
  /// In en, this message translates to:
  /// **'Personal recommendations'**
  String get personalRecommendations;

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Get a home feed shaped around your taste and activity.'**
  String get personalRecommendationsBlurb;

  /// Guest benefit title
  ///
  /// In en, this message translates to:
  /// **'Checkout safely'**
  String get checkoutSafely;

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Keep orders, addresses, and payments protected.'**
  String get checkoutSafelyBlurb;

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Sync favorites, carts, and recommendations.'**
  String get syncBlurb;

  /// Onboarding subtitle
  ///
  /// In en, this message translates to:
  /// **'A few quick steps to a richer experience.'**
  String get quickSteps;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'My cart'**
  String get myCart;

  /// Empty cart body
  ///
  /// In en, this message translates to:
  /// **'Browse the shop and add something you love.'**
  String get browseAndAdd;

  /// Empty cart action
  ///
  /// In en, this message translates to:
  /// **'Keep browsing'**
  String get keepBrowsing;

  /// Cart action
  ///
  /// In en, this message translates to:
  /// **'Remove out-of-stock items'**
  String get removeOutOfStock;

  /// Cart section
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get savedForLater;

  /// Profile prompt
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeProfile;

  /// Profile praise
  ///
  /// In en, this message translates to:
  /// **'Your profile looks beautiful.'**
  String get profileLooksBeautiful;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Profile identity'**
  String get profileIdentity;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Account updated.'**
  String get accountUpdated;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Saved items'**
  String get savedItems;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Saved products'**
  String get savedProducts;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Saved sellers'**
  String get savedSellers;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get savedPosts;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get savedAddresses;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No saved items yet'**
  String get noSavedItems;

  /// Profile rail
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get recentlyViewed;

  /// Wishlist section
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Create a collection'**
  String get createCollection;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Shareable lists for products, sellers, and posts'**
  String get collectionsBlurb;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Your wishlist'**
  String get yourWishlist;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Wishlist link copied'**
  String get wishlistLinkCopied;

  /// Progress
  ///
  /// In en, this message translates to:
  /// **'Syncing your wishlist'**
  String get syncingWishlist;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Price drops and restocks stay on your radar'**
  String get priceDropsBlurb;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Stores you want to revisit'**
  String get storesToRevisit;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Your orders'**
  String get yourOrders;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Track, review and reorder'**
  String get trackReviewReorder;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Reviews and ratings'**
  String get reviewsAndRatings;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get pointsEarned;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get earned;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Redeemed'**
  String get redeemed;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetime;

  /// Reward state
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// Rewards description
  ///
  /// In en, this message translates to:
  /// **'Earn points on every order and review. Redeem them for coupons and perks.'**
  String get rewardsPointsBlurb;

  /// Referral title
  ///
  /// In en, this message translates to:
  /// **'Invite friends, earn rewards'**
  String get inviteFriends;

  /// Referral stat
  ///
  /// In en, this message translates to:
  /// **'Friends invited'**
  String get friendsInvited;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Invite code {code} copied — share it!'**
  String inviteCodeCopied(String code);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Support centre'**
  String get supportCentre;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Help and FAQ'**
  String get helpAndFaq;

  /// Support channel
  ///
  /// In en, this message translates to:
  /// **'Live chat'**
  String get liveChat;

  /// Support channel
  ///
  /// In en, this message translates to:
  /// **'Email us'**
  String get emailUs;

  /// Support channel
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// Support note
  ///
  /// In en, this message translates to:
  /// **'We usually reply within an hour'**
  String get replyWithinHour;

  /// Support action
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get startConversation;

  /// FAQ topic
  ///
  /// In en, this message translates to:
  /// **'Return policy'**
  String get returnPolicy;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'What is your returns policy?'**
  String get faqReturns;

  /// FAQ answer. The window is 7 days per the client brief, not 14.
  ///
  /// In en, this message translates to:
  /// **'Most items can be returned within 14 days. Open an order to start a return.'**
  String get faqReturnsAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do I track my order?'**
  String get faqTracking;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Open My orders from your profile to see live status and delivery updates.'**
  String get faqTrackingAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do loyalty points work?'**
  String get faqPoints;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'About Reem'**
  String get aboutReem;

  /// About screen
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// Placeholder title
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// Placeholder body
  ///
  /// In en, this message translates to:
  /// **'We are polishing this experience — it will be here soon.'**
  String get comingSoonBlurb;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'App preferences'**
  String get appPreferences;

  /// Screen-reader label for a tappable card
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String a11yOpen(String name);

  /// Profile completion hint
  ///
  /// In en, this message translates to:
  /// **'Next: {step}'**
  String nextStep(String step);

  /// About screen description
  ///
  /// In en, this message translates to:
  /// **'A premium social-commerce home for the pieces you love — shopping, discovery and community in one place.'**
  String get aboutReemBlurb;

  /// Account role
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get roleBuyer;

  /// Account role
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get roleSeller;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get statusInTransit;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// Mandatory self-declaration on the registration form (Q43/Q138 P1).
  ///
  /// In en, this message translates to:
  /// **'I declare that I am a woman and accept the Reem terms'**
  String get declaredFemaleLabel;

  /// Home greeting addressed to a signed-in shopper, by first name.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}'**
  String homeGreetingNamed(String name);

  /// Home greeting for a shopper who is not signed in.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeGreetingGuest;

  /// Home greeting supporting line.
  ///
  /// In en, this message translates to:
  /// **'A curated edit of fashion, beauty and gifts — chosen for you.'**
  String get homeGreetingSubtitle;

  /// Placeholder text in the home search bar.
  ///
  /// In en, this message translates to:
  /// **'Search dresses, perfume, gifts…'**
  String get homeSearchHint;

  /// Eyebrow above the stories rail.
  ///
  /// In en, this message translates to:
  /// **'Fresh today'**
  String get homeStoriesEyebrow;

  /// Label under the shopper's own story ring.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get homeYourStory;

  /// Title of the category showcase.
  ///
  /// In en, this message translates to:
  /// **'Shop by category'**
  String get homeShopByCategory;

  /// Eyebrow above the flash-deals section.
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get homeFlashDealsEyebrow;

  /// Title of the flash-deals section.
  ///
  /// In en, this message translates to:
  /// **'Flash deals'**
  String get homeFlashDeals;

  /// Eyebrow above the recommended products rail.
  ///
  /// In en, this message translates to:
  /// **'Picked for you'**
  String get homeRecommendedEyebrow;

  /// Eyebrow above the new-arrivals rail.
  ///
  /// In en, this message translates to:
  /// **'Just in'**
  String get homeNewArrivalsEyebrow;

  /// Eyebrow above the best-sellers rail.
  ///
  /// In en, this message translates to:
  /// **'Loved by many'**
  String get homeBestSellersEyebrow;

  /// Eyebrow above the continue-shopping rail.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get homeContinueShoppingEyebrow;

  /// Title of the continue-shopping rail.
  ///
  /// In en, this message translates to:
  /// **'Continue shopping'**
  String get homeContinueShopping;

  /// Eyebrow above the featured boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Handpicked sellers'**
  String get homeFeaturedStoresEyebrow;

  /// Title of the featured boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Featured boutiques'**
  String get homeFeaturedStores;

  /// Eyebrow above the recently-viewed rail.
  ///
  /// In en, this message translates to:
  /// **'Jump back in'**
  String get homeRecentlyViewedEyebrow;

  /// Title of the recently-viewed rail.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get homeRecentlyViewed;

  /// Eyebrow above the wishlist highlights rail.
  ///
  /// In en, this message translates to:
  /// **'You loved these'**
  String get homeWishlistEyebrow;

  /// Title of the wishlist highlights rail.
  ///
  /// In en, this message translates to:
  /// **'From your wishlist'**
  String get homeWishlist;

  /// Eyebrow above the nearby boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get homeNearbyEyebrow;

  /// Title of the nearby boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Boutiques nearby'**
  String get homeNearbyStores;

  /// Eyebrow above the main product grid on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeExploreEyebrow;

  /// Title above the main product grid on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Everything for you'**
  String get homeExploreTitle;

  /// Eyebrow above the social feed preview.
  ///
  /// In en, this message translates to:
  /// **'From your boutiques'**
  String get homeFeedEyebrow;

  /// Title above the social feed preview.
  ///
  /// In en, this message translates to:
  /// **'Latest posts'**
  String get homeFeedTitle;

  /// Interest chip on the home greeting.
  ///
  /// In en, this message translates to:
  /// **'New drops'**
  String get homeTasteNewDrops;

  /// Interest chip on the home greeting.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get homeTasteBeauty;

  /// Interest chip on the home greeting.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get homeTasteGifts;

  /// Label for the search filters control.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// Label above trending search suggestions.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// Label above the shopper's recent searches.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// Filter chip that clears the category filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Button that starts a reply to a comment.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// Label marking the signed-in shopper's own comment.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// Timestamp for something that happened seconds ago.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Placeholder in the comment input.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get addCommentHint;

  /// Button that spends loyalty points.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// Button that grants a permission, e.g. location.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// Badge on a boutique that is currently open.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get openNow;

  /// Badge on a boutique that is currently closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedNow;

  /// Badge on a time-limited promotion.
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get limitedTime;

  /// Eyebrow above the category showcase.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get homeCategoriesEyebrow;

  /// Eyebrow above the featured boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get homeFeaturedEyebrow;

  /// Title of the loyalty card on home.
  ///
  /// In en, this message translates to:
  /// **'Reem Rewards'**
  String get homeLoyaltyTitle;

  /// Subtitle of the loyalty card on home.
  ///
  /// In en, this message translates to:
  /// **'Earn rewards on every purchase ✨'**
  String get homeLoyaltySubtitle;

  /// Title of the location permission prompt on home.
  ///
  /// In en, this message translates to:
  /// **'Discover boutiques near you'**
  String get homeNearbyPromptTitle;

  /// Body of the location permission prompt on home.
  ///
  /// In en, this message translates to:
  /// **'Enable location for local pickup & nearby stores.'**
  String get homeNearbyPromptBody;

  /// Empty-state title for the social feed on home.
  ///
  /// In en, this message translates to:
  /// **'Your feed is warming up'**
  String get homeFeedEmptyTitle;

  /// Empty-state body for the social feed on home.
  ///
  /// In en, this message translates to:
  /// **'Follow boutiques you love to fill your feed with beautiful finds.'**
  String get homeFeedEmptyBody;

  /// Scarcity line on a flash deal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left} other{{count} left}}'**
  String flashDealAlmostGone(int count);

  /// Short label for a free-shipping coupon.
  ///
  /// In en, this message translates to:
  /// **'Free ship'**
  String get couponFreeShipping;

  /// Title of the wallet screen.
  ///
  /// In en, this message translates to:
  /// **'My wallet'**
  String get wallet;

  /// Label above the wallet balance figure.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get walletBalance;

  /// Q42 — the wallet balance cannot be withdrawn as cash.
  ///
  /// In en, this message translates to:
  /// **'Spendable inside Reem only'**
  String get walletNotWithdrawable;

  /// Title of the wallet transaction list.
  ///
  /// In en, this message translates to:
  /// **'Wallet activity'**
  String get walletStatement;

  /// Empty-state title on the wallet screen.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is empty'**
  String get walletEmptyTitle;

  /// Empty-state body on the wallet screen.
  ///
  /// In en, this message translates to:
  /// **'Refunds, gifts and converted points will appear here.'**
  String get walletEmptyBody;

  /// Shown when the wallet cannot load because the device is offline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Your balance will update when you reconnect.'**
  String get walletOffline;

  /// Wallet movement source: money back from a return.
  ///
  /// In en, this message translates to:
  /// **'Return refund'**
  String get walletSourceRefund;

  /// Wallet movement source: loyalty points turned into credit.
  ///
  /// In en, this message translates to:
  /// **'Points converted'**
  String get walletSourcePoints;

  /// Wallet movement source: a manual credit from the admin.
  ///
  /// In en, this message translates to:
  /// **'Compensation'**
  String get walletSourceCompensation;

  /// Wallet movement source: the customer added credit.
  ///
  /// In en, this message translates to:
  /// **'Top-up'**
  String get walletSourceTopUp;

  /// Wallet movement source: a campaign or gift credit.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get walletSourceGift;

  /// Wallet movement source: a price or order adjustment.
  ///
  /// In en, this message translates to:
  /// **'Price adjustment'**
  String get walletSourceAdjustment;

  /// Wallet movement source: credit spent on an order.
  ///
  /// In en, this message translates to:
  /// **'Order payment'**
  String get walletSourceOrder;

  /// Wallet movement source: a spend returned because the order was cancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get walletSourceOrderReversal;

  /// Wallet movement source: anything not otherwise named.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get walletSourceOther;

  /// Title of the loyalty points card.
  ///
  /// In en, this message translates to:
  /// **'Loyalty points'**
  String get loyaltyPoints;

  /// How many loyalty points the customer holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No points yet} =1{1 point} other{{count} points}}'**
  String loyaltyPointsCount(int count);

  /// Button that converts loyalty points into wallet credit.
  ///
  /// In en, this message translates to:
  /// **'Convert to credit'**
  String get loyaltyConvert;

  /// Q43 — explains the conversion rate.
  ///
  /// In en, this message translates to:
  /// **'Every 10 points = 5,000 SYP of credit'**
  String get loyaltyConvertHint;

  /// Shown when the chosen number of points is not a multiple of ten.
  ///
  /// In en, this message translates to:
  /// **'Points convert in multiples of ten.'**
  String get loyaltyNeedMultipleOfTen;

  /// Shown when the customer tries to convert more points than she holds.
  ///
  /// In en, this message translates to:
  /// **'You do not have enough points for that.'**
  String get loyaltyNotEnoughPoints;

  /// Confirmation after a successful points conversion.
  ///
  /// In en, this message translates to:
  /// **'{count} points added to your balance ✨'**
  String loyaltyConverted(int count);

  /// Title of the seller earnings screen.
  ///
  /// In en, this message translates to:
  /// **'My earnings'**
  String get sellerEarnings;

  /// Q25 — released funds a payout run will actually pay.
  ///
  /// In en, this message translates to:
  /// **'Ready for payout'**
  String get earningsAvailable;

  /// Q25 — payouts run weekly.
  ///
  /// In en, this message translates to:
  /// **'Transferred weekly'**
  String get earningsAvailableHint;

  /// Q24 — earned but still inside the return window.
  ///
  /// In en, this message translates to:
  /// **'In escrow'**
  String get earningsHeld;

  /// Q24 — explains why escrow money is not payable yet.
  ///
  /// In en, this message translates to:
  /// **'Until the return window closes'**
  String get earningsHeldHint;

  /// Q107 — funds held pending a dispute ruling.
  ///
  /// In en, this message translates to:
  /// **'Frozen — dispute'**
  String get earningsFrozen;

  /// Q107 — explains why disputed money is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Until the ruling'**
  String get earningsFrozenHint;

  /// Section title for lifetime totals.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get earningsLifetime;

  /// Lifetime total actually paid out to the seller.
  ///
  /// In en, this message translates to:
  /// **'Paid to you'**
  String get earningsLifetimePaid;

  /// Lifetime gross sales before commission.
  ///
  /// In en, this message translates to:
  /// **'Gross sales'**
  String get earningsLifetimeGross;

  /// Lifetime commission charged by the platform.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get earningsLifetimeCommission;

  /// Section title for calculated but unpaid payouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts in progress'**
  String get earningsPendingPayouts;

  /// Badge on a payout the general manager has approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get earningsPayoutApproved;

  /// Badge on a payout not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get earningsPayoutPending;

  /// Section title for the seller's ledger movements.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get earningsStatement;

  /// Empty-state title on the seller earnings screen.
  ///
  /// In en, this message translates to:
  /// **'No earnings yet'**
  String get earningsEmptyTitle;

  /// Empty-state body on the seller earnings screen.
  ///
  /// In en, this message translates to:
  /// **'Once your first order is delivered, your earnings appear here step by step.'**
  String get earningsEmptyBody;

  /// Shown when the earnings screen cannot load because the device is offline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Your earnings will update when you reconnect.'**
  String get earningsOffline;

  /// Ledger movement: a sub-order was settled.
  ///
  /// In en, this message translates to:
  /// **'Sale settled'**
  String get earningsMoveSale;

  /// Ledger movement: the return window closed.
  ///
  /// In en, this message translates to:
  /// **'Released from escrow'**
  String get earningsMoveReleased;

  /// Ledger movement: money was paid out.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get earningsMovePayout;

  /// Ledger movement: funds frozen when a dispute opened.
  ///
  /// In en, this message translates to:
  /// **'Frozen for a dispute'**
  String get earningsMoveFrozen;

  /// Ledger movement: a dispute was decided.
  ///
  /// In en, this message translates to:
  /// **'Dispute settled'**
  String get earningsMoveDisputeDone;

  /// Ledger movement: a refund was issued.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get earningsMoveRefund;

  /// Ledger movement: an earlier entry was reversed.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get earningsMoveReversal;

  /// Ledger movement: anything not otherwise named.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get earningsMoveOther;

  /// Title of the admin finance console.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get adminFinance;

  /// Subtitle of the admin finance console.
  ///
  /// In en, this message translates to:
  /// **'Ledger health, positions, and what needs a person'**
  String get adminFinanceSubtitle;

  /// Headline when the trial balance balances and reconciliation found nothing.
  ///
  /// In en, this message translates to:
  /// **'Books are sound'**
  String get financeSound;

  /// Explains what «sound» means.
  ///
  /// In en, this message translates to:
  /// **'Debits equal credits, and no account has drifted'**
  String get financeSoundHint;

  /// Headline when reconciliation found something.
  ///
  /// In en, this message translates to:
  /// **'Books need review'**
  String get financeUnsound;

  /// Headline when debits and credits disagree — money created or destroyed.
  ///
  /// In en, this message translates to:
  /// **'Trial balance is off'**
  String get financeNotBalanced;

  /// Label for the gap between total debits and total credits.
  ///
  /// In en, this message translates to:
  /// **'Discrepancy'**
  String get financeDiscrepancy;

  /// Label for total debits in the trial balance.
  ///
  /// In en, this message translates to:
  /// **'Total debit'**
  String get financeTotalDebit;

  /// Label for total credits in the trial balance.
  ///
  /// In en, this message translates to:
  /// **'Total credit'**
  String get financeTotalCredit;

  /// How many reconciliation findings there are.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 finding} other{{count} findings}}'**
  String financeFindings(int count);

  /// Section title for standing balances.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get financePositions;

  /// Total funds the platform holds.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get financeHeld;

  /// Total obligations on the platform.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get financeOwed;

  /// Held minus owed — solvency in one line.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get financeCoverage;

  /// Warning when coverage is negative.
  ///
  /// In en, this message translates to:
  /// **'Obligations exceed funds held'**
  String get financeCoverageShort;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Platform cash'**
  String get financePlatformCash;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Gateway receivable'**
  String get financeGatewayReceivable;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Courier cash in transit'**
  String get financeCourierInTransit;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Seller payable'**
  String get financeSellerPayable;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Seller escrow'**
  String get financeSellerEscrow;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Customer wallets'**
  String get financeCustomerWallets;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Held for disputes'**
  String get financeDisputeHeld;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Loyalty outstanding'**
  String get financeLoyaltyLiability;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Commission revenue'**
  String get financeCommissionRevenue;

  /// Section title listing couriers holding platform cash.
  ///
  /// In en, this message translates to:
  /// **'Courier cash'**
  String get financeCourierCash;

  /// Empty state for the courier cash section.
  ///
  /// In en, this message translates to:
  /// **'No courier is holding platform cash.'**
  String get financeCourierCashEmpty;

  /// Section title for disputes past their decision deadline.
  ///
  /// In en, this message translates to:
  /// **'Overdue disputes'**
  String get financeOverdueDisputes;

  /// How overdue a dispute is.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{due today} =1{1 day overdue} other{{count} days overdue}}'**
  String financeOverdueBy(int count);

  /// Empty state for the overdue disputes section.
  ///
  /// In en, this message translates to:
  /// **'No disputes are overdue.'**
  String get financeNoOverdue;

  /// Section title for the foreign-currency position.
  ///
  /// In en, this message translates to:
  /// **'FX position'**
  String get financeFx;

  /// Label for the exchange rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get financeFxRate;

  /// Assets minus liabilities in the foreign currency.
  ///
  /// In en, this message translates to:
  /// **'Net exposure'**
  String get financeFxExposure;

  /// What past currency conversions have cost or earned.
  ///
  /// In en, this message translates to:
  /// **'Conversion result'**
  String get financeFxResult;

  /// Button that pulls the exchange rate immediately.
  ///
  /// In en, this message translates to:
  /// **'Sync rate now'**
  String get financeFxSync;

  /// Shown when there is no rate to translate at.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate published yet.'**
  String get financeFxNone;

  /// Section title for the full account listing.
  ///
  /// In en, this message translates to:
  /// **'Trial balance'**
  String get financeTrialBalance;

  /// Table column header.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get financeAccount;

  /// Table column header.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get financeBalance;

  /// Reloads the current screen's data.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Title of the invoices list.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// Title of a single invoice document.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// Q51 — the customer's copy, covering the whole basket.
  ///
  /// In en, this message translates to:
  /// **'Order invoice'**
  String get invoiceCustomerCopy;

  /// Q51 — one seller's copy for their own parcel.
  ///
  /// In en, this message translates to:
  /// **'Seller invoice'**
  String get invoiceSellerCopy;

  /// Label for the invoice number.
  ///
  /// In en, this message translates to:
  /// **'Invoice no.'**
  String get invoiceNumber;

  /// Label for the issue date.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get invoiceIssuedAt;

  /// Label for the order number.
  ///
  /// In en, this message translates to:
  /// **'Order no.'**
  String get invoiceOrderNumber;

  /// Label above the recipient block.
  ///
  /// In en, this message translates to:
  /// **'Billed to'**
  String get invoiceBilledTo;

  /// Section title above the invoice lines.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get invoiceItems;

  /// Column header for the quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get invoiceQuantity;

  /// Label for the items subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get invoiceSubtotal;

  /// Label for the discount total.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get invoiceDiscount;

  /// Label for the shipping total.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get invoiceShipping;

  /// Label for the grand total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceTotal;

  /// Seller copy only — what the platform took (Q50).
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get invoiceCommission;

  /// Seller copy only — what is left after commission.
  ///
  /// In en, this message translates to:
  /// **'Seller net'**
  String get invoiceSellerNet;

  /// Q55 P1 — the client stated no fiscal requirement, so the document says so.
  ///
  /// In en, this message translates to:
  /// **'This is a commercial invoice, not a tax invoice.'**
  String get invoiceNoTax;

  /// Empty state on the invoices list.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get invoiceEmptyTitle;

  /// Q39 — an order that can still change is not invoiced yet.
  ///
  /// In en, this message translates to:
  /// **'Your invoice is issued once the order ships.'**
  String get invoiceEmptyBody;

  /// Label for the coupon code used.
  ///
  /// In en, this message translates to:
  /// **'Coupon'**
  String get invoiceCoupon;

  /// Title of the shipment tracking screen (Q64).
  ///
  /// In en, this message translates to:
  /// **'Track shipment'**
  String get trackShipment;

  /// Label for the tracking code.
  ///
  /// In en, this message translates to:
  /// **'Tracking code'**
  String get trackingCode;

  /// Badge on an express parcel (Q64).
  ///
  /// In en, this message translates to:
  /// **'Express'**
  String get trackExpress;

  /// Q64 — the delivery slot she chose.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for'**
  String get trackScheduledFor;

  /// When the parcel arrived.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get trackDeliveredAt;

  /// Q37 — how many times the courier has tried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 delivery attempt} other{{count} delivery attempts}}'**
  String trackAttempts(int count);

  /// Section title for the progress spine.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get trackJourney;

  /// Section title for the event list.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get trackHistory;

  /// Shown when a tracking code does not resolve.
  ///
  /// In en, this message translates to:
  /// **'No shipment matches that code.'**
  String get trackNotFound;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Order prepared'**
  String get shipStageCreated;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Assigned to a courier'**
  String get shipStageAssigned;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get shipStagePickedUp;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get shipStageInTransit;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get shipStageOutForDelivery;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get shipStageDelivered;

  /// Shipment stage (Q37).
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get shipStageFailed;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get shipStageReturning;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get shipStageReturned;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shipStageCancelled;

  /// Q55 — the courier's assignments for today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s round'**
  String get courierDay;

  /// Section title for parcels still open.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get courierOpen;

  /// Section title for closed parcels.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get courierDone;

  /// Empty state on the courier round.
  ///
  /// In en, this message translates to:
  /// **'Nothing assigned today'**
  String get courierEmptyTitle;

  /// Empty state body on the courier round.
  ///
  /// In en, this message translates to:
  /// **'Parcels appear here as soon as they are assigned to you.'**
  String get courierEmptyBody;

  /// Q55 — the cash amount due at the door.
  ///
  /// In en, this message translates to:
  /// **'To collect'**
  String get courierCollect;

  /// Badge on a parcel with nothing to collect.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get courierPrepaid;

  /// Q55 — «يتصل بالزبونة بضغطة».
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get courierCall;

  /// Q55 — «يشوف خريطة أو موقع».
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get courierNavigate;

  /// Q55 — «يؤكد استلام الطلب من البائع».
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get courierPickUp;

  /// Marks the parcel as on its way.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get courierStartDelivery;

  /// Completes the delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get courierDeliver;

  /// Q55 — records why it failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get courierFail;

  /// Q55 — «يرى ملاحظات التوصيل».
  ///
  /// In en, this message translates to:
  /// **'Delivery notes'**
  String get courierInstructions;

  /// Title of the delivery confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get courierDeliverTitle;

  /// Q55 — «يسجّل مبلغ التحصيل».
  ///
  /// In en, this message translates to:
  /// **'Amount collected'**
  String get courierCollectedAmount;

  /// Explains that an empty field means the full amount.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if you collected the full amount'**
  String get courierCollectedHint;

  /// Optional note on delivery.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get courierRecipientNote;

  /// Confirms the sheet's action.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get courierConfirm;

  /// Title of the failed-delivery sheet.
  ///
  /// In en, this message translates to:
  /// **'Why did it fail?'**
  String get courierFailTitle;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get failNoAnswer;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get failWrongAddress;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Customer refused'**
  String get failCustomerRefused;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get failPostponed;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Area unreachable'**
  String get failUnreachableArea;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get failOther;

  /// Primary sign-in button: a code on her SIM is the credential
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get signInWithCode;

  /// Subtitle on the phone-entry step
  ///
  /// In en, this message translates to:
  /// **'Enter your number and we will send you a code.'**
  String get signInSubtitle;

  /// Generic forward action
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Secondary sign-in path, only usable on a known device
  ///
  /// In en, this message translates to:
  /// **'Use my password instead'**
  String get usePasswordInstead;

  /// Explains why the password path can fall through to a code
  ///
  /// In en, this message translates to:
  /// **'A password only works on a device you have signed in from before.'**
  String get passwordOnlyOnKnownDevice;

  /// Shown when a correct password lands on an unenrolled handset
  ///
  /// In en, this message translates to:
  /// **'This device is new. We sent a code to your number to finish signing in.'**
  String get newDeviceCodeSent;

  /// The two digits she compares against the message
  ///
  /// In en, this message translates to:
  /// **'Match code'**
  String get matchCodeLabel;

  /// Anti-relay guidance beside the match code
  ///
  /// In en, this message translates to:
  /// **'Check that the message shows the same two digits. Reem will never ask you to read a code aloud.'**
  String get matchCodeHint;

  /// Where the code went, masked
  ///
  /// In en, this message translates to:
  /// **'Code sent to {destination}'**
  String codeSentToMasked(String destination);

  /// Resend cooldown
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendInSeconds(int seconds);

  /// Heading when a verified number has no account yet
  ///
  /// In en, this message translates to:
  /// **'Finish creating your account'**
  String get finishSignUp;

  /// Confirmation chip on the signup form
  ///
  /// In en, this message translates to:
  /// **'Number verified'**
  String get numberVerified;

  /// Label making it clear a password is not required
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get passwordOptional;

  /// Hint under the optional password field
  ///
  /// In en, this message translates to:
  /// **'You can skip this. You will sign in with a code each time.'**
  String get passwordOptionalHint;

  /// Title of the security centre
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityCentre;

  /// Subtitle of the security centre
  ///
  /// In en, this message translates to:
  /// **'Your devices, your sessions, and the ways back into your account.'**
  String get securityCentreSubtitle;

  /// Toggle row for the optional password credential
  ///
  /// In en, this message translates to:
  /// **'Password sign-in'**
  String get passwordSignIn;

  /// Password toggle state
  ///
  /// In en, this message translates to:
  /// **'On — usable on known devices only'**
  String get passwordEnabled;

  /// Password toggle state
  ///
  /// In en, this message translates to:
  /// **'Off — you sign in with a code'**
  String get passwordDisabled;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPassword;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get removePassword;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Change my number'**
  String get changeAccountNumber;

  /// Explains the two-sided phone change
  ///
  /// In en, this message translates to:
  /// **'We will send a code to your current number first, then to the new one.'**
  String get changeNumberExplainer;

  /// Step one of the phone change
  ///
  /// In en, this message translates to:
  /// **'Code sent to your current number'**
  String get currentNumberCode;

  /// Step three of the phone change
  ///
  /// In en, this message translates to:
  /// **'Code sent to the new number'**
  String get newNumberCode;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'New number'**
  String get newNumberLabel;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Your number was changed'**
  String get numberChanged;

  /// Post-change safety notice
  ///
  /// In en, this message translates to:
  /// **'Payouts are on hold until {date}'**
  String payoutsFrozenUntil(String date);

  /// Post-change notice
  ///
  /// In en, this message translates to:
  /// **'All other sessions were ended'**
  String get otherSessionsEnded;

  /// Security centre row
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get recoveryCodes;

  /// How many recovery codes are left
  ///
  /// In en, this message translates to:
  /// **'{count} unused'**
  String recoveryCodesRemaining(int count);

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Generate new codes'**
  String get generateRecoveryCodes;

  /// Shown above a freshly generated set
  ///
  /// In en, this message translates to:
  /// **'Write these down now. They are shown once, and generating a new set cancels the old one.'**
  String get recoveryCodesWarning;

  /// Entry point to support-mediated recovery
  ///
  /// In en, this message translates to:
  /// **'Lost your SIM?'**
  String get lostYourSim;

  /// Sets the expectation before she opens a recovery case
  ///
  /// In en, this message translates to:
  /// **'If your number is gone for good, we can review your account by hand. It takes several days on purpose.'**
  String get lostSimExplainer;

  /// The platform-held-data-only promise, stated to her
  ///
  /// In en, this message translates to:
  /// **'We will never ask for a photo of you or of an identity document.'**
  String get recoveryNoDocuments;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'A number we can reach you on now'**
  String get recoveryContactNumber;

  /// Heading above the evidence questions
  ///
  /// In en, this message translates to:
  /// **'What do you remember?'**
  String get recoveryQuestionsTitle;

  /// Hint above the evidence questions
  ///
  /// In en, this message translates to:
  /// **'Answer what you can. Nothing here is required.'**
  String get recoveryQuestionsHint;

  /// Evidence question
  ///
  /// In en, this message translates to:
  /// **'Roughly when did you join? (YYYY-MM)'**
  String get recoveryRegistrationMonth;

  /// Evidence question
  ///
  /// In en, this message translates to:
  /// **'When was your last order? (YYYY-MM)'**
  String get recoveryLastOrderMonth;

  /// Evidence question
  ///
  /// In en, this message translates to:
  /// **'Roughly what did it come to?'**
  String get recoveryLastOrderTotal;

  /// Evidence question
  ///
  /// In en, this message translates to:
  /// **'What is one of your devices called?'**
  String get recoveryDeviceLabel;

  /// Confirmation heading
  ///
  /// In en, this message translates to:
  /// **'We received your request'**
  String get recoverySubmitted;

  /// About the claim secret
  ///
  /// In en, this message translates to:
  /// **'Keep this reference. It is the only way to check on your request.'**
  String get recoveryKeepSecret;

  /// Banner shown to the owner while a case is open
  ///
  /// In en, this message translates to:
  /// **'Someone asked to move your account to another number.'**
  String get recoveryCaseOpenWarning;

  /// Cool-off warning
  ///
  /// In en, this message translates to:
  /// **'Your account moves on {date} unless you stop it.'**
  String recoveryCaseCoolOff(String date);

  /// The owner cancelling a recovery case
  ///
  /// In en, this message translates to:
  /// **'That was not me — stop it'**
  String get stopThisRequest;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'The request was stopped'**
  String get recoveryCaseCancelled;

  /// Section heading
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// Badge on the current session
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere else'**
  String get signOutEverywhere;

  /// Absolute session lifetime
  ///
  /// In en, this message translates to:
  /// **'Signed in until {date}'**
  String sessionExpiresOn(String date);

  /// Device state
  ///
  /// In en, this message translates to:
  /// **'Verified on this device'**
  String get deviceTrusted;

  /// Device state
  ///
  /// In en, this message translates to:
  /// **'Never signed in from here'**
  String get deviceNotVerified;

  /// The 24-hour SIM-swap delay, explained
  ///
  /// In en, this message translates to:
  /// **'This device is new. Sensitive changes unlock {date}.'**
  String newDeviceCooldown(String date);

  /// Step-up prompt heading
  ///
  /// In en, this message translates to:
  /// **'Verify it is you'**
  String get verifyToContinue;

  /// Action on the recovery form
  ///
  /// In en, this message translates to:
  /// **'Send the code'**
  String get sendCode;

  /// Copies a value to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Dismisses a dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Confirms a destructive or elevated action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Eyebrow above the home showcase, the section that presents products as posts.
  ///
  /// In en, this message translates to:
  /// **'Straight from the boutiques'**
  String get homeShowcaseEyebrow;

  /// Title of the home showcase section.
  ///
  /// In en, this message translates to:
  /// **'New in'**
  String get homeShowcaseTitle;

  /// One line of copy under the showcase title.
  ///
  /// In en, this message translates to:
  /// **'The newest pieces, told as stories — swipe, love, shop.'**
  String get homeShowcaseSubtitle;

  /// Showcase shape: products presented as social posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get homeShapePosts;

  /// Showcase shape: an editorial collage of tiles.
  ///
  /// In en, this message translates to:
  /// **'Mosaic'**
  String get homeShapeMosaic;

  /// Showcase shape: the two-column catalogue.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get homeShapeGrid;

  /// Like tally under a post. {count} is already formatted, e.g. 1.2K.
  ///
  /// In en, this message translates to:
  /// **'{count} loves'**
  String postLikesCount(String count);

  /// Link opening the comment sheet. {count} is already formatted.
  ///
  /// In en, this message translates to:
  /// **'View all {count} comments'**
  String postViewComments(String count);

  /// Tap target that expands a truncated post caption.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get postMore;

  /// Compact age of a post, in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String shortMinutesAgo(int count);

  /// Compact age of a post, in hours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String shortHoursAgo(int count);

  /// Compact age of a post, in days.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String shortDaysAgo(int count);

  /// Compact age of a post, in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count}w'**
  String shortWeeksAgo(int count);

  /// Title of the home rail carrying today's story frames from shops she follows.
  ///
  /// In en, this message translates to:
  /// **'Boutique stories'**
  String get homeBoutiqueStories;

  /// Caption on a category tile. {count} is already formatted, e.g. 1.2k.
  ///
  /// In en, this message translates to:
  /// **'{count} pieces'**
  String piecesCount(String count);

  /// Champagne ribbon on a post published in the last few days.
  ///
  /// In en, this message translates to:
  /// **'Just in'**
  String get justIn;

  /// Confirmation after adding a product to the cart from the feed.
  ///
  /// In en, this message translates to:
  /// **'Added to your bag'**
  String get addedToBag;

  /// Eyebrow over the seller home header.
  ///
  /// In en, this message translates to:
  /// **'Command centre'**
  String get sellerCommandCentre;

  /// Error title when the seller dashboard fails to load.
  ///
  /// In en, this message translates to:
  /// **'Dashboard unavailable'**
  String get sellerDashboardUnavailable;

  /// Tooltip on the seller header's chat shortcut.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// Title of the strip listing what the seller must act on today.
  ///
  /// In en, this message translates to:
  /// **'Needs you now'**
  String get sellerNeedsYou;

  /// Shown when the seller has no pending work.
  ///
  /// In en, this message translates to:
  /// **'All clear — nothing is waiting on you'**
  String get sellerAllClear;

  /// Alert tile: orders awaiting the seller's confirmation.
  ///
  /// In en, this message translates to:
  /// **'To confirm'**
  String get sellerPendingOrders;

  /// Alert tile: products close to selling out.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get sellerRunningLow;

  /// Alert tile: outstanding to-do items.
  ///
  /// In en, this message translates to:
  /// **'Open tasks'**
  String get sellerOpenTasks;

  /// Money taken over the selected period.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get sellerRevenue;

  /// Profit figure on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get sellerProfit;

  /// Profit margin percentage on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get sellerMargin;

  /// Caption under the trend arrow on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'vs. prior period'**
  String get sellerVsPrior;

  /// Revenue period selector.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// Revenue period selector.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// Revenue period selector.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// Revenue period selector.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get periodDaily;

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get periodYearly;

  /// Title of the revenue/orders chart.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get sellerSalesTrend;

  /// Title of the seller shortcut grid.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get sellerQuickActions;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get sellerAddProduct;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Manage orders'**
  String get sellerManageOrders;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get sellerAnalytics;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Create coupon'**
  String get sellerCreateCoupon;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get sellerAnnouncement;

  /// Link from the orders overview to the full order list.
  ///
  /// In en, this message translates to:
  /// **'Manage all'**
  String get sellerManageAll;

  /// Title of the seller's top products section.
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get sellerTopProducts;

  /// Title of the low-stock section.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get sellerLowStockTitle;

  /// Badge on a product with no stock left.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get sellerOutOfStock;

  /// Button that opens the stock adjustment flow.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get sellerRestock;

  /// Title of the store score section.
  ///
  /// In en, this message translates to:
  /// **'Store health'**
  String get sellerStorePerformance;

  /// Store score component.
  ///
  /// In en, this message translates to:
  /// **'Fulfillment'**
  String get sellerFulfillment;

  /// Store score component.
  ///
  /// In en, this message translates to:
  /// **'Responsiveness'**
  String get sellerResponsiveness;

  /// Store score component.
  ///
  /// In en, this message translates to:
  /// **'Product quality'**
  String get sellerProductQuality;

  /// Title of the conversion funnel section.
  ///
  /// In en, this message translates to:
  /// **'Conversion'**
  String get sellerConversionMetrics;

  /// Share of viewers who buy.
  ///
  /// In en, this message translates to:
  /// **'Conversion rate'**
  String get sellerConversionRate;

  /// Funnel step.
  ///
  /// In en, this message translates to:
  /// **'Product views'**
  String get sellerProductViews;

  /// Funnel step.
  ///
  /// In en, this message translates to:
  /// **'Cart adds'**
  String get sellerCartAdds;

  /// Funnel step.
  ///
  /// In en, this message translates to:
  /// **'Wishlist adds'**
  String get sellerWishlistAdds;

  /// Title of the AI insights section.
  ///
  /// In en, this message translates to:
  /// **'Smart insights'**
  String get sellerInsights;

  /// Title of the reviews section.
  ///
  /// In en, this message translates to:
  /// **'Recent reviews'**
  String get sellerRecentReviews;

  /// Title of the seller task list.
  ///
  /// In en, this message translates to:
  /// **'To-do list'**
  String get sellerTasks;

  /// Title of the goals section.
  ///
  /// In en, this message translates to:
  /// **'Store goals'**
  String get sellerGoals;

  /// Seller order pipeline: orders just placed.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get orderNew;

  /// Seller order pipeline: being prepared.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get orderProcessing;

  /// Seller order pipeline: packed, waiting for a courier.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get orderReady;

  /// Seller order pipeline: handed to the customer.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderDelivered;

  /// Seller order pipeline: cancelled before delivery.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderCancelled;

  /// Seller order pipeline: sent back after delivery.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get orderReturned;

  /// Status pill in the seller rail: the storefront is published.
  ///
  /// In en, this message translates to:
  /// **'Store is live'**
  String get sellerLiveStore;

  /// Seller settings group: the storefront itself.
  ///
  /// In en, this message translates to:
  /// **'Store management'**
  String get sellerGroupStore;

  /// Seller settings group: money and reporting.
  ///
  /// In en, this message translates to:
  /// **'Business & finance'**
  String get sellerGroupBusiness;

  /// Seller settings group: app preferences and account safety.
  ///
  /// In en, this message translates to:
  /// **'Preferences & security'**
  String get sellerGroupPreferences;

  /// Seller menu row: courier and delivery options.
  ///
  /// In en, this message translates to:
  /// **'Shipping settings'**
  String get sellerShippingSettings;

  /// Seller menu row: payout and payment methods.
  ///
  /// In en, this message translates to:
  /// **'Payment settings'**
  String get sellerPaymentSettings;

  /// Seller menu row: returns and store rules.
  ///
  /// In en, this message translates to:
  /// **'Store policies'**
  String get sellerStorePolicies;

  /// Seller menu row: statements and exports.
  ///
  /// In en, this message translates to:
  /// **'Financial reports'**
  String get sellerFinancialReports;

  /// Seller menu row and the title of the payout card.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal centre'**
  String get sellerWithdrawalCentre;

  /// Seller menu row: staff accounts on the store.
  ///
  /// In en, this message translates to:
  /// **'Team management'**
  String get sellerTeamManagement;

  /// Seller menu row: the store's billing plan.
  ///
  /// In en, this message translates to:
  /// **'Subscription & plan'**
  String get sellerSubscriptionPlan;

  /// Seller menu row: audit trail of store actions.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get sellerActivityLog;

  /// Seller menu row: a direct line to the platform team.
  ///
  /// In en, this message translates to:
  /// **'Seller support'**
  String get sellerSupport;

  /// Caption under the seller's withdrawable balance.
  ///
  /// In en, this message translates to:
  /// **'Available to withdraw'**
  String get sellerAvailableToWithdraw;

  /// Button that starts a payout.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get sellerWithdraw;

  /// Lifetime total already paid to the seller.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get sellerPaidOut;

  /// Commission and platform fees deducted.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get sellerFees;

  /// Earnings not yet available to withdraw.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get sellerPendingPayout;

  /// Button on the seller profile header.
  ///
  /// In en, this message translates to:
  /// **'Edit store'**
  String get sellerEditStore;

  /// Subscription badge on the seller profile. {plan} is the plan name.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan'**
  String sellerPlanBadge(String plan);

  /// Caption on the seller stats card. {year} is a four-digit year.
  ///
  /// In en, this message translates to:
  /// **'Selling since {year}'**
  String sellerMemberSince(String year);

  /// Rating line on the seller stats card; both values are pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count} reviews'**
  String sellerRatingSummary(String rating, String count);

  /// Version footer at the foot of the seller profile.
  ///
  /// In en, this message translates to:
  /// **'Seller platform · v{version}'**
  String sellerPlatformFooter(String version);

  /// Empty state on the seller's product list.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get sellerNoProductsYet;

  /// Empty-state body on the seller's product list.
  ///
  /// In en, this message translates to:
  /// **'Add your first piece and it will show up here.'**
  String get sellerNoProductsBlurb;

  /// Floating action on the seller's product list.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get sellerNewProduct;

  /// Product row menu action: open the edit form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sellerEditProduct;

  /// Product row menu action: put the listing live.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get sellerSetActive;

  /// Product row menu action: unpublish back to a draft.
  ///
  /// In en, this message translates to:
  /// **'Move to draft'**
  String get sellerMoveToDraft;

  /// Product row menu action: retire the listing.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sellerArchive;

  /// Stock line on a managed product row. {count} is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String sellerStock(String count);

  /// Seller/admin surface title: recent events.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get surfaceActivity;

  /// Seller surface title: the shop's buyers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get surfaceCustomers;

  /// Seller surface title: campaigns and promotions.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get surfaceMarketing;

  /// How many shoppers saved a listing. {count} is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{count} saves'**
  String savedCount(String count);

  /// Title of the product form when creating.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get formNewProduct;

  /// Title of the product form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get formEditProduct;

  /// Product form field: the listing name.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get formTitle;

  /// Validation on the product title field.
  ///
  /// In en, this message translates to:
  /// **'A title is required'**
  String get formTitleRequired;

  /// Product form field: the long copy.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get formDescription;

  /// Validation on the product description field.
  ///
  /// In en, this message translates to:
  /// **'A description is required'**
  String get formDescriptionRequired;

  /// Product form field: which department the piece belongs to.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get formCategory;

  /// Validation on the product category field.
  ///
  /// In en, this message translates to:
  /// **'A category is required'**
  String get formCategoryRequired;

  /// Product form field: the asking price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get formPrice;

  /// Validation on the product price field.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get formPriceInvalid;

  /// Product form field: units on hand.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get formStock;

  /// Validation on the product stock field.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity'**
  String get formStockInvalid;

  /// Product form field: draft, live or archived.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get formStatus;

  /// Product form toggle: pin the piece to the top of the shop.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get formFeatured;

  /// Product form toggle: let the piece appear in the social feed.
  ///
  /// In en, this message translates to:
  /// **'Show in feed'**
  String get formShowInFeed;

  /// Product form action: attach a picture.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get formAddImage;

  /// Product form action: add a size or colour option.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get formAddVariant;

  /// Primary button that creates the listing.
  ///
  /// In en, this message translates to:
  /// **'Publish product'**
  String get formPublishProduct;

  /// Confirmation after creating a listing.
  ///
  /// In en, this message translates to:
  /// **'Product published'**
  String get formProductCreated;

  /// Confirmation after editing a listing.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get formProductUpdated;

  /// Action that drafts the product description automatically.
  ///
  /// In en, this message translates to:
  /// **'Write with AI'**
  String get formAiDescription;

  /// Confirmation after the assistant fills the description.
  ///
  /// In en, this message translates to:
  /// **'Description drafted'**
  String get formAiDescriptionAdded;

  /// Action that proposes search tags for the listing.
  ///
  /// In en, this message translates to:
  /// **'Suggest tags'**
  String get formAiTags;

  /// Shown when the assistant returns no tags.
  ///
  /// In en, this message translates to:
  /// **'No tags suggested'**
  String get formNoTags;

  /// Shown when the assistant is invoked before the form has enough to work with.
  ///
  /// In en, this message translates to:
  /// **'Add a title and a category first'**
  String get formTitleCategoryFirst;

  /// Title of the full category browse screen.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// Tooltip on the admin app bar's settings shortcut.
  ///
  /// In en, this message translates to:
  /// **'Administrator settings'**
  String get adminSettings;

  /// Admin nav rail: the security section.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get adminSecurity;

  /// Admin section: browse and moderate accounts.
  ///
  /// In en, this message translates to:
  /// **'User management'**
  String get adminUserManagement;

  /// Admin section: seller applications and status.
  ///
  /// In en, this message translates to:
  /// **'Seller management'**
  String get adminSellerManagement;

  /// Admin section: the catalogue.
  ///
  /// In en, this message translates to:
  /// **'Product management'**
  String get adminProductManagement;

  /// Admin section: every order on the platform.
  ///
  /// In en, this message translates to:
  /// **'Order management'**
  String get adminOrderManagement;

  /// Admin section: ledger and payouts.
  ///
  /// In en, this message translates to:
  /// **'Financial management'**
  String get adminFinancialManagement;

  /// Admin section: commission rules and rates.
  ///
  /// In en, this message translates to:
  /// **'Commission management'**
  String get adminCommissionManagement;

  /// Admin section: business intelligence.
  ///
  /// In en, this message translates to:
  /// **'Reports and analytics'**
  String get adminReportsAndAnalytics;

  /// Admin section: generated reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReports;

  /// Admin section: review queues for reported content.
  ///
  /// In en, this message translates to:
  /// **'Moderation tools'**
  String get adminModerationTools;

  /// Admin section: the customer support queue.
  ///
  /// In en, this message translates to:
  /// **'Support management'**
  String get adminSupportManagement;

  /// Admin section: the record of administrative actions.
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get adminAuditLogs;

  /// Admin section: platform configuration.
  ///
  /// In en, this message translates to:
  /// **'System settings'**
  String get adminSystemSettings;

  /// Admin section: push and email campaigns.
  ///
  /// In en, this message translates to:
  /// **'Notification campaigns'**
  String get adminNotificationCampaigns;

  /// Admin section: campaign delivery and engagement.
  ///
  /// In en, this message translates to:
  /// **'Notification analytics'**
  String get adminNotificationAnalytics;

  /// Subtitle under an admin section title.
  ///
  /// In en, this message translates to:
  /// **'Operational controls, review queues, and live records.'**
  String get adminSectionSubtitle;

  /// Error state on an admin section.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this section.'**
  String get adminSectionUnavailable;

  /// Empty state after filtering an admin table.
  ///
  /// In en, this message translates to:
  /// **'No matching records found.'**
  String get adminNoMatchingRecords;

  /// Empty state for an admin panel with no rows.
  ///
  /// In en, this message translates to:
  /// **'No data yet.'**
  String get adminNoDataYet;

  /// Empty state for a leaderboard panel.
  ///
  /// In en, this message translates to:
  /// **'No ranked data yet.'**
  String get adminNoRankedData;

  /// Empty state for the audit stream.
  ///
  /// In en, this message translates to:
  /// **'No recent administrative activity.'**
  String get adminNoRecentActivity;

  /// Error title when the audit feed fails.
  ///
  /// In en, this message translates to:
  /// **'Audit stream unavailable'**
  String get adminAuditUnavailable;

  /// Action that reloads the audit feed.
  ///
  /// In en, this message translates to:
  /// **'Retry from audit logs'**
  String get adminRetryFromAudit;

  /// Tooltip on the admin table's search reset.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get adminClearSearch;

  /// Heading over the admin shortcut row.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get adminQuickActions;

  /// Heading over the admin audit feed.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get adminRecentActivity;

  /// Live count of signed-in users.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get adminOnlineNow;

  /// Filter on the seller management table.
  ///
  /// In en, this message translates to:
  /// **'Verified sellers only'**
  String get adminVerifiedSellersOnly;

  /// Placeholder listing the role values an admin can filter by.
  ///
  /// In en, this message translates to:
  /// **'USER, SELLER, ADMIN'**
  String get adminRoleFilterHint;

  /// Admin queue: seller applications awaiting a decision.
  ///
  /// In en, this message translates to:
  /// **'Seller review'**
  String get adminSellerReview;

  /// Admin queue: open support conversations.
  ///
  /// In en, this message translates to:
  /// **'Support queue'**
  String get adminSupportQueue;

  /// Admin queue: reported content.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get adminModeration;

  /// Admin shortcut to the finance console.
  ///
  /// In en, this message translates to:
  /// **'Financials'**
  String get adminFinancials;

  /// Admin shortcut to the customer list.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get adminCustomers;

  /// Admin shortcut to notification campaigns.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get adminCampaigns;

  /// Admin shortcut to notification analytics.
  ///
  /// In en, this message translates to:
  /// **'Notify analytics'**
  String get adminNotifyAnalytics;

  /// Title of the admin analytics screen.
  ///
  /// In en, this message translates to:
  /// **'Business intelligence'**
  String get adminBusinessIntelligence;

  /// Subtitle of the admin analytics screen.
  ///
  /// In en, this message translates to:
  /// **'Sales, revenue, conversion, cohorts, and live operations.'**
  String get adminAnalyticsSubtitle;

  /// Chart title: revenue over the selected range.
  ///
  /// In en, this message translates to:
  /// **'Revenue trend'**
  String get adminRevenueTrend;

  /// Chart title: the steps from view to purchase.
  ///
  /// In en, this message translates to:
  /// **'Conversion funnel'**
  String get adminConversionFunnel;

  /// Leaderboard: best-selling products.
  ///
  /// In en, this message translates to:
  /// **'Top products'**
  String get adminTopProducts;

  /// Leaderboard: best-performing sellers.
  ///
  /// In en, this message translates to:
  /// **'Seller performance'**
  String get adminSellerPerformance;

  /// Metric: revenue before deductions.
  ///
  /// In en, this message translates to:
  /// **'Gross revenue'**
  String get adminGrossRevenue;

  /// Metric: revenue after commission and fees.
  ///
  /// In en, this message translates to:
  /// **'Net revenue'**
  String get adminNetRevenue;

  /// Metric: mean value of an order.
  ///
  /// In en, this message translates to:
  /// **'Average order value'**
  String get adminAov;

  /// Metric: share of customers who order again.
  ///
  /// In en, this message translates to:
  /// **'Repeat rate'**
  String get adminRepeatRate;

  /// Metric: share of customers retained.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get adminRetentionRate;

  /// Action that downloads the analytics as a spreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Export Excel'**
  String get adminExportExcel;

  /// Action that downloads the analytics as a PDF.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get adminExportPdf;

  /// Action that opens the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'New campaign'**
  String get adminNewCampaign;

  /// Title of the campaign composer sheet.
  ///
  /// In en, this message translates to:
  /// **'New notification campaign'**
  String get adminNewCampaignTitle;

  /// Field label in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Campaign name'**
  String get adminCampaignName;

  /// Field label in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Notification title'**
  String get adminNotificationTitle;

  /// Field label in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get adminMessageBody;

  /// Field label: where the campaign is delivered.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get adminChannels;

  /// Action that sends a campaign now.
  ///
  /// In en, this message translates to:
  /// **'Run campaign'**
  String get adminRunCampaign;

  /// Confirmation after saving a campaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign created.'**
  String get adminCampaignCreated;

  /// Confirmation after starting a campaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign queued for delivery.'**
  String get adminCampaignQueued;

  /// Validation error in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Name, title, and body are required.'**
  String get adminCampaignFieldsRequired;

  /// Validation error in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Select at least one channel.'**
  String get adminSelectChannel;

  /// Validation error for the campaign schedule field.
  ///
  /// In en, this message translates to:
  /// **'Use an ISO schedule time.'**
  String get adminScheduleIsoHint;

  /// Confirms creating a new record.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Range chip on the admin analytics console.
  ///
  /// In en, this message translates to:
  /// **'Last {count} days'**
  String adminLastDays(int count);

  /// Title of the confirm dialog before a listing is removed.
  ///
  /// In en, this message translates to:
  /// **'Delete product?'**
  String get sellerDeleteProduct;

  /// Body of the delete-product confirm dialog. {title} is the listing name.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be permanently removed.'**
  String sellerDeleteProductBody(String title);

  /// Title of the sheet offering camera or gallery.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get mediaSourceTitle;

  /// Media picker: open the camera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get mediaFromCamera;

  /// Media picker: open the photo library.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get mediaFromGallery;

  /// Shown over a thumbnail while its bytes are in flight.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get mediaUploading;

  /// Shown over a thumbnail whose upload did not complete.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get mediaUploadFailed;

  /// Accessibility label for the delete control on a thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get mediaRemovePhoto;

  /// Badge on the first photo in a product gallery.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get mediaCoverBadge;

  /// Shown when the OS picker refuses to open, almost always a denied permission.
  ///
  /// In en, this message translates to:
  /// **'Could not open your photos. Check the app\'s photo permission in Settings.'**
  String get mediaPickFailed;

  /// Label above the product form's gallery field.
  ///
  /// In en, this message translates to:
  /// **'Product photos'**
  String get mediaProductGallery;

  /// Label above the story composer's media field.
  ///
  /// In en, this message translates to:
  /// **'Story image'**
  String get mediaStoryLabel;

  /// Shown when a form is submitted while an upload is still running.
  ///
  /// In en, this message translates to:
  /// **'Wait for the photos to finish uploading.'**
  String get mediaWaitForUploads;

  /// Helper text under a product gallery field.
  ///
  /// In en, this message translates to:
  /// **'The first photo is the cover. Up to {count} photos.'**
  String mediaGalleryHint(int count);

  /// Shown when the story composer is submitted with no media.
  ///
  /// In en, this message translates to:
  /// **'Choose an image for the story first.'**
  String get mediaStoryRequired;

  /// Seller application: the store's logo image.
  ///
  /// In en, this message translates to:
  /// **'Store logo'**
  String get storeLogo;

  /// Seller application: identity document upload.
  ///
  /// In en, this message translates to:
  /// **'Photo of your ID'**
  String get governmentIdDocument;

  /// Seller application: business licence upload.
  ///
  /// In en, this message translates to:
  /// **'Commercial register or licence'**
  String get businessLicenseDocument;

  /// Reassurance above the private document uploads.
  ///
  /// In en, this message translates to:
  /// **'Only you and the review team can open these. They never appear on your store.'**
  String get verificationDocumentsPrivate;

  /// How to photograph a document well.
  ///
  /// In en, this message translates to:
  /// **'Photograph each document in full, in good light.'**
  String get verificationDocumentsHint;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Your store'**
  String get verificationSectionStore;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Contact and addresses'**
  String get verificationSectionContact;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get verificationSectionDocuments;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get verificationSectionPayout;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Shipping and returns'**
  String get verificationSectionOperations;

  /// Example shipping methods, comma separated.
  ///
  /// In en, this message translates to:
  /// **'Courier, pickup, same-day'**
  String get shippingMethodsHint;

  /// Example product categories, comma separated.
  ///
  /// In en, this message translates to:
  /// **'Fashion, perfume, handmade'**
  String get productCategoriesHint;

  /// Shown when an application already exists.
  ///
  /// In en, this message translates to:
  /// **'You have applied before. Editing and submitting replaces that application.'**
  String get verificationResubmitNotice;

  /// Caption on a tile standing in for a document already uploaded.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get mediaDocumentAttached;

  /// Shown when the application is submitted mid-upload.
  ///
  /// In en, this message translates to:
  /// **'Wait for the documents to finish uploading.'**
  String get verificationUploadPending;

  /// Names the one field the application is missing.
  ///
  /// In en, this message translates to:
  /// **'«{field}» is required.'**
  String verificationFieldRequired(String field);

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get verificationStatusPending;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get verificationStatusUnderReview;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'More documents needed'**
  String get verificationStatusNeedsMoreDocuments;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'More information needed'**
  String get verificationStatusNeedsMoreInfo;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get verificationStatusApproved;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get verificationStatusRejected;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get verificationStatusSuspended;

  /// Media picker: open the device file browser (documents).
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get mediaFromFiles;

  /// Helper under a document picker that also accepts PDFs.
  ///
  /// In en, this message translates to:
  /// **'A clear photograph, or the original PDF.'**
  String get mediaDocumentsHint;

  /// Shown when a picked file exceeds the size ceiling before any upload starts.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than {size} MB.'**
  String mediaTooLarge(String size);

  /// Title of the chat attachment sheet.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo'**
  String get chatAttachTitle;

  /// Shown when a chat attachment upload fails.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be sent.'**
  String get chatAttachmentFailed;

  /// Title of the screen listing photos shared in a conversation.
  ///
  /// In en, this message translates to:
  /// **'Shared photos'**
  String get chatSharedMedia;

  /// Empty state for the shared-media screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been shared here yet.'**
  String get chatNoSharedMedia;

  /// Fallback text for a message that is only a photograph.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhotoMessage;

  /// Empty-state title inside a conversation with no messages yet.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation'**
  String get chatStartConversation;

  /// Empty-state body inside an empty conversation.
  ///
  /// In en, this message translates to:
  /// **'Ask about the piece, the size or the delivery — or send a photo or a voice note.'**
  String get chatStartConversationHint;

  /// Button in the empty conversation state that opens the attachment sheet.
  ///
  /// In en, this message translates to:
  /// **'Send a photo'**
  String get chatShareImage;

  /// Shown when microphone permission is refused.
  ///
  /// In en, this message translates to:
  /// **'Reem needs permission to use the microphone.'**
  String get voicePermissionDenied;

  /// Shown when the recorder fails to start.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start.'**
  String get voiceRecordFailed;

  /// Tooltip on the send button while recording.
  ///
  /// In en, this message translates to:
  /// **'Send the recording'**
  String get voiceSend;

  /// Tooltip on the microphone button in the composer.
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get voiceRecord;

  /// Message text carried alongside a voice attachment.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceMessage;

  /// Shown when a voice note cannot be played back.
  ///
  /// In en, this message translates to:
  /// **'This recording is unavailable.'**
  String get voiceUnavailable;

  /// Attachment sheet: pick a document from storage.
  ///
  /// In en, this message translates to:
  /// **'Send a file'**
  String get chatFromFiles;

  /// Shown when the OS has no handler for a downloaded attachment.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone can open this file.'**
  String get chatOpenFileFailed;

  /// Message text carried alongside a document attachment.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileMessage;

  /// Shown when fetching an attachment fails.
  ///
  /// In en, this message translates to:
  /// **'The file could not be downloaded.'**
  String get chatDownloadFailed;

  /// Title of the seller's order queue.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get sellerOrdersTitle;

  /// No description provided for @sellerOrdersTabNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get sellerOrdersTabNew;

  /// No description provided for @sellerOrdersTabPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get sellerOrdersTabPreparing;

  /// No description provided for @sellerOrdersTabReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get sellerOrdersTabReady;

  /// No description provided for @sellerOrdersTabShipping.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get sellerOrdersTabShipping;

  /// No description provided for @sellerOrdersTabReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get sellerOrdersTabReturns;

  /// No description provided for @sellerOrdersTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sellerOrdersTabCompleted;

  /// No description provided for @sellerOrdersOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get sellerOrdersOffline;

  /// No description provided for @sellerOrdersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this order'**
  String get sellerOrdersLoadFailed;

  /// No description provided for @sellerOrdersUpdated.
  ///
  /// In en, this message translates to:
  /// **'Order updated'**
  String get sellerOrdersUpdated;

  /// No description provided for @sellerOrdersEmptyNew.
  ///
  /// In en, this message translates to:
  /// **'No new orders'**
  String get sellerOrdersEmptyNew;

  /// No description provided for @sellerOrdersEmptyPreparing.
  ///
  /// In en, this message translates to:
  /// **'Nothing being prepared'**
  String get sellerOrdersEmptyPreparing;

  /// No description provided for @sellerOrdersEmptyReady.
  ///
  /// In en, this message translates to:
  /// **'Nothing ready to ship'**
  String get sellerOrdersEmptyReady;

  /// No description provided for @sellerOrdersEmptyShipping.
  ///
  /// In en, this message translates to:
  /// **'No parcels on the way'**
  String get sellerOrdersEmptyShipping;

  /// No description provided for @sellerOrdersEmptyReturns.
  ///
  /// In en, this message translates to:
  /// **'No returns'**
  String get sellerOrdersEmptyReturns;

  /// No description provided for @sellerOrdersEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed orders yet'**
  String get sellerOrdersEmptyCompleted;

  /// No description provided for @sellerOrdersEmptyNewBody.
  ///
  /// In en, this message translates to:
  /// **'Orders appear here the moment a customer buys from you.'**
  String get sellerOrdersEmptyNewBody;

  /// No description provided for @sellerOrdersEmptyReturnsBody.
  ///
  /// In en, this message translates to:
  /// **'Which is good news.'**
  String get sellerOrdersEmptyReturnsBody;

  /// No description provided for @sellerOrdersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Orders move here as they progress.'**
  String get sellerOrdersEmptyBody;

  /// No description provided for @sellerOrderActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get sellerOrderActionConfirm;

  /// No description provided for @sellerOrderActionReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to ship'**
  String get sellerOrderActionReady;

  /// No description provided for @sellerOrderActionHandOver.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get sellerOrderActionHandOver;

  /// No description provided for @sellerOrderActionDeliver.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get sellerOrderActionDeliver;

  /// No description provided for @sellerOrderActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get sellerOrderActionCancel;

  /// No description provided for @sellerOrderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Accepted — the order is now being prepared'**
  String get sellerOrderConfirmed;

  /// No description provided for @sellerOrderMarkedReady.
  ///
  /// In en, this message translates to:
  /// **'The order is ready to ship'**
  String get sellerOrderMarkedReady;

  /// No description provided for @sellerOrderHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Handover recorded'**
  String get sellerOrderHandedOver;

  /// No description provided for @sellerOrderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivery recorded'**
  String get sellerOrderDelivered;

  /// No description provided for @sellerOrderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled and the items returned to stock'**
  String get sellerOrderCancelled;

  /// No description provided for @sellerParcelStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get sellerParcelStatusNew;

  /// No description provided for @sellerParcelStatusAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your confirmation'**
  String get sellerParcelStatusAwaitingConfirmation;

  /// No description provided for @sellerParcelStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Being prepared'**
  String get sellerParcelStatusPreparing;

  /// No description provided for @sellerParcelStatusReadyToShip.
  ///
  /// In en, this message translates to:
  /// **'Ready to ship'**
  String get sellerParcelStatusReadyToShip;

  /// No description provided for @sellerParcelStatusHandedToCourier.
  ///
  /// In en, this message translates to:
  /// **'With the courier'**
  String get sellerParcelStatusHandedToCourier;

  /// No description provided for @sellerParcelStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get sellerParcelStatusInTransit;

  /// No description provided for @sellerParcelStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get sellerParcelStatusDelivered;

  /// No description provided for @sellerParcelStatusDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get sellerParcelStatusDeliveryFailed;

  /// No description provided for @sellerParcelStatusCancelledByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by the customer'**
  String get sellerParcelStatusCancelledByCustomer;

  /// No description provided for @sellerParcelStatusCancelledBySeller.
  ///
  /// In en, this message translates to:
  /// **'You cancelled it'**
  String get sellerParcelStatusCancelledBySeller;

  /// No description provided for @sellerParcelStatusRejectedOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Refused at the door'**
  String get sellerParcelStatusRejectedOnDelivery;

  /// No description provided for @sellerParcelStatusReturnRequested.
  ///
  /// In en, this message translates to:
  /// **'Return requested'**
  String get sellerParcelStatusReturnRequested;

  /// No description provided for @sellerParcelStatusReturnInTransit.
  ///
  /// In en, this message translates to:
  /// **'Return on its way'**
  String get sellerParcelStatusReturnInTransit;

  /// No description provided for @sellerParcelStatusReturned.
  ///
  /// In en, this message translates to:
  /// **'Return received'**
  String get sellerParcelStatusReturned;

  /// No description provided for @sellerParcelStatusExchangeInProgress.
  ///
  /// In en, this message translates to:
  /// **'Exchange in progress'**
  String get sellerParcelStatusExchangeInProgress;

  /// No description provided for @sellerParcelStatusExchanged.
  ///
  /// In en, this message translates to:
  /// **'Exchanged'**
  String get sellerParcelStatusExchanged;

  /// No description provided for @sellerParcelStatusRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund pending'**
  String get sellerParcelStatusRefundPending;

  /// No description provided for @sellerParcelStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get sellerParcelStatusRefunded;

  /// No description provided for @sellerParcelStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'In dispute'**
  String get sellerParcelStatusDisputed;

  /// No description provided for @sellerFulfilmentPlatformCourier.
  ///
  /// In en, this message translates to:
  /// **'Platform courier'**
  String get sellerFulfilmentPlatformCourier;

  /// No description provided for @sellerFulfilmentThirdParty.
  ///
  /// In en, this message translates to:
  /// **'Shipping company'**
  String get sellerFulfilmentThirdParty;

  /// No description provided for @sellerFulfilmentSelfShips.
  ///
  /// In en, this message translates to:
  /// **'You deliver it'**
  String get sellerFulfilmentSelfShips;

  /// No description provided for @sellerFulfilmentPickupPoint.
  ///
  /// In en, this message translates to:
  /// **'Pickup point'**
  String get sellerFulfilmentPickupPoint;

  /// No description provided for @sellerOrderCashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get sellerOrderCashOnDelivery;

  /// No description provided for @sellerOrderItemsToPack.
  ///
  /// In en, this message translates to:
  /// **'What to pack'**
  String get sellerOrderItemsToPack;

  /// No description provided for @sellerOrderStepPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order received'**
  String get sellerOrderStepPlaced;

  /// No description provided for @sellerOrderStepConfirmed.
  ///
  /// In en, this message translates to:
  /// **'You accepted it'**
  String get sellerOrderStepConfirmed;

  /// No description provided for @sellerOrderStepShipped.
  ///
  /// In en, this message translates to:
  /// **'Left for delivery'**
  String get sellerOrderStepShipped;

  /// No description provided for @sellerOrderStepDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get sellerOrderStepDelivered;

  /// No description provided for @sellerOrderCourierAssigned.
  ///
  /// In en, this message translates to:
  /// **'Courier assigned'**
  String get sellerOrderCourierAssigned;

  /// No description provided for @sellerOrderCourierPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting a courier'**
  String get sellerOrderCourierPending;

  /// No description provided for @sellerOrderItemsSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Items subtotal'**
  String get sellerOrderItemsSubtotal;

  /// No description provided for @sellerOrderDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get sellerOrderDiscount;

  /// No description provided for @sellerOrderCommission.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get sellerOrderCommission;

  /// No description provided for @sellerOrderNet.
  ///
  /// In en, this message translates to:
  /// **'Your net earnings'**
  String get sellerOrderNet;

  /// No description provided for @sellerOrderEscrowReleased.
  ///
  /// In en, this message translates to:
  /// **'These earnings are now available for payout.'**
  String get sellerOrderEscrowReleased;

  /// No description provided for @sellerOrderEscrowPending.
  ///
  /// In en, this message translates to:
  /// **'Earnings are counted after delivery and once the return window closes.'**
  String get sellerOrderEscrowPending;

  /// No description provided for @sellerOrderCallCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call the customer'**
  String get sellerOrderCallCustomer;

  /// No description provided for @sellerOrderAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get sellerOrderAddressCopied;

  /// No description provided for @sellerCancelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The items go back to your stock, and the customer is told the reason you write.'**
  String get sellerCancelSubtitle;

  /// No description provided for @sellerCancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get sellerCancelReasonLabel;

  /// No description provided for @sellerCancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Write a reason the customer will understand'**
  String get sellerCancelReasonHint;

  /// No description provided for @sellerCancelReasonTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write a reason of at least five characters'**
  String get sellerCancelReasonTooShort;

  /// No description provided for @sellerCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get sellerCancelConfirm;

  /// No description provided for @sellerCancelDismiss.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get sellerCancelDismiss;

  /// No description provided for @sellerCancelPresetOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get sellerCancelPresetOutOfStock;

  /// No description provided for @sellerCancelPresetSizeGone.
  ///
  /// In en, this message translates to:
  /// **'That size has run out'**
  String get sellerCancelPresetSizeGone;

  /// No description provided for @sellerCancelPresetPriceError.
  ///
  /// In en, this message translates to:
  /// **'The listed price was wrong'**
  String get sellerCancelPresetPriceError;

  /// No description provided for @sellerCancelPresetNoTime.
  ///
  /// In en, this message translates to:
  /// **'I cannot prepare it in time'**
  String get sellerCancelPresetNoTime;

  /// No description provided for @sellerDeliverTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get sellerDeliverTitle;

  /// No description provided for @sellerDeliverSubtitleCash.
  ///
  /// In en, this message translates to:
  /// **'Enter what you actually collected. Leave it empty if you collected the full amount.'**
  String get sellerDeliverSubtitleCash;

  /// No description provided for @sellerDeliverSubtitlePrepaid.
  ///
  /// In en, this message translates to:
  /// **'This order is prepaid — there is nothing to collect.'**
  String get sellerDeliverSubtitlePrepaid;

  /// No description provided for @sellerDeliverCollectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount collected'**
  String get sellerDeliverCollectedLabel;

  /// No description provided for @sellerDeliverCollectedHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if you collected the full amount'**
  String get sellerDeliverCollectedHint;

  /// No description provided for @sellerOrderEscrowOn.
  ///
  /// In en, this message translates to:
  /// **'Earnings become available once the return window closes on {date}.'**
  String sellerOrderEscrowOn(String date);

  /// Title of the checkout screen.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get checkoutDeliveryAddress;

  /// No description provided for @checkoutSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Your saved addresses'**
  String get checkoutSavedAddresses;

  /// No description provided for @checkoutNewAddress.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get checkoutNewAddress;

  /// No description provided for @checkoutUseThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Deliver here'**
  String get checkoutUseThisAddress;

  /// No description provided for @checkoutSaveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save this address for next time'**
  String get checkoutSaveAddress;

  /// No description provided for @checkoutRecipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient name'**
  String get checkoutRecipientName;

  /// No description provided for @checkoutRecipientPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get checkoutRecipientPhone;

  /// No description provided for @checkoutGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get checkoutGovernorate;

  /// No description provided for @checkoutDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get checkoutDistrict;

  /// No description provided for @checkoutDistrictOptional.
  ///
  /// In en, this message translates to:
  /// **'District (optional)'**
  String get checkoutDistrictOptional;

  /// No description provided for @checkoutCity.
  ///
  /// In en, this message translates to:
  /// **'City or town'**
  String get checkoutCity;

  /// No description provided for @checkoutAddressLine.
  ///
  /// In en, this message translates to:
  /// **'Detailed address'**
  String get checkoutAddressLine;

  /// No description provided for @checkoutAddressLineHint.
  ///
  /// In en, this message translates to:
  /// **'Street, building number, floor'**
  String get checkoutAddressLineHint;

  /// No description provided for @checkoutLandmark.
  ///
  /// In en, this message translates to:
  /// **'Nearby landmark (optional)'**
  String get checkoutLandmark;

  /// No description provided for @checkoutLandmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Opposite the pharmacy'**
  String get checkoutLandmarkHint;

  /// No description provided for @checkoutInstructions.
  ///
  /// In en, this message translates to:
  /// **'Delivery notes (optional)'**
  String get checkoutInstructions;

  /// No description provided for @checkoutInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Call before arriving'**
  String get checkoutInstructionsHint;

  /// No description provided for @checkoutRural.
  ///
  /// In en, this message translates to:
  /// **'This is a rural area'**
  String get checkoutRural;

  /// No description provided for @checkoutRuralHint.
  ///
  /// In en, this message translates to:
  /// **'The fee and the time differ from the city centre'**
  String get checkoutRuralHint;

  /// No description provided for @checkoutCoupon.
  ///
  /// In en, this message translates to:
  /// **'Discount coupon'**
  String get checkoutCoupon;

  /// No description provided for @checkoutCouponOptional.
  ///
  /// In en, this message translates to:
  /// **'Coupon code (optional)'**
  String get checkoutCouponOptional;

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get checkoutPaymentMethod;

  /// No description provided for @checkoutOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get checkoutOrderSummary;

  /// No description provided for @checkoutSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get checkoutDelivery;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get checkoutPlaceOrder;

  /// No description provided for @checkoutRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get checkoutRequired;

  /// No description provided for @checkoutInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get checkoutInvalidPhone;

  /// No description provided for @checkoutChooseGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Choose a governorate'**
  String get checkoutChooseGovernorate;

  /// No description provided for @checkoutChoosePayment.
  ///
  /// In en, this message translates to:
  /// **'Choose a payment method'**
  String get checkoutChoosePayment;

  /// No description provided for @checkoutTotalPending.
  ///
  /// In en, this message translates to:
  /// **'The final total is calculated when you place the order'**
  String get checkoutTotalPending;

  /// No description provided for @checkoutPlacedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your order {number} is confirmed'**
  String checkoutPlacedSuccess(String number);

  /// No description provided for @checkoutSplitNotice.
  ///
  /// In en, this message translates to:
  /// **'Your order is from {count} sellers and arrives in several parcels — with one delivery fee.'**
  String checkoutSplitNotice(String count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
