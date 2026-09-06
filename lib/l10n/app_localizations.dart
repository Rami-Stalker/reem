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

  /// Home greeting, early hours — plain
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorningKhair;

  /// Home greeting, early hours — light
  ///
  /// In en, this message translates to:
  /// **'Morning light'**
  String get greetingMorningNour;

  /// Home greeting, early hours — roses
  ///
  /// In en, this message translates to:
  /// **'A rosy morning'**
  String get greetingMorningWard;

  /// Home greeting, early hours — jasmine
  ///
  /// In en, this message translates to:
  /// **'Jasmine morning'**
  String get greetingMorningYasmine;

  /// Home greeting, early hours — bright
  ///
  /// In en, this message translates to:
  /// **'Rise and shine'**
  String get greetingMorningFull;

  /// Home greeting, midday — plain
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingMiddaySaeed;

  /// Home greeting, midday — warm
  ///
  /// In en, this message translates to:
  /// **'Have a lovely day'**
  String get greetingMiddayTab;

  /// Home greeting, midday — roses
  ///
  /// In en, this message translates to:
  /// **'A rosy afternoon'**
  String get greetingMiddayWard;

  /// Home greeting, evening — light
  ///
  /// In en, this message translates to:
  /// **'Evening light'**
  String get greetingEveningNour;

  /// Home greeting, evening — plain
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEveningKhair;

  /// Home greeting, evening — jasmine
  ///
  /// In en, this message translates to:
  /// **'Jasmine evening'**
  String get greetingEveningYasmine;

  /// Home greeting, evening — roses
  ///
  /// In en, this message translates to:
  /// **'A rosy evening'**
  String get greetingEveningWard;

  /// Home greeting, late night — warm
  ///
  /// In en, this message translates to:
  /// **'A lovely night'**
  String get greetingNightSahra;

  /// Home greeting, late night — plain
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get greetingNightFull;

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

  /// Heading over the boutique selling the shown offer
  ///
  /// In en, this message translates to:
  /// **'Sold by'**
  String get soldBy;

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

  /// Title of the customer's notification inbox
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationInboxTitle;

  /// Empty state title for the notification inbox
  ///
  /// In en, this message translates to:
  /// **'Nothing new yet'**
  String get notificationInboxEmptyTitle;

  /// Empty state body for the notification inbox
  ///
  /// In en, this message translates to:
  /// **'Order updates, seller replies and offers will appear here.'**
  String get notificationInboxEmptyBody;

  /// Error title when the notification inbox fails to load
  ///
  /// In en, this message translates to:
  /// **'Notifications could not load'**
  String get notificationInboxLoadFailed;

  /// Action that marks every notification as read
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationMarkAllRead;

  /// Confirmation after marking every notification read
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationAllRead;

  /// How many notifications are unread
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread} other{{count} unread}}'**
  String notificationUnreadCount(int count);

  /// Title of the notification preferences screen
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationPreferencesTitle;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @actionDidNotSave.
  ///
  /// In en, this message translates to:
  /// **'That didn’t save — check your connection and try again'**
  String get actionDidNotSave;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get adminActionChangeRole;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Homepage curation'**
  String get adminActionCuration;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Decide case'**
  String get adminActionDecideCase;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Decide report'**
  String get adminActionDecideReport;

  /// Confirmation after an admin action succeeds.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get adminActionDone;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Edit setting'**
  String get adminActionEditSetting;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'New commission rule'**
  String get adminActionNewRule;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'New setting'**
  String get adminActionNewSetting;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Restore account'**
  String get adminActionRestoreAccount;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Change settlement status'**
  String get adminActionSetCommissionStatus;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get adminActionSetStatus;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Suspend account'**
  String get adminActionSuspendAccount;

  /// Governance action offered on a record in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Triage ticket'**
  String get adminActionTriage;

  /// Tooltip on the per-row action menu.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get adminActions;

  /// Confirm button on an admin action form.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get adminApply;

  /// Pending badge above the seller review queue.
  ///
  /// In en, this message translates to:
  /// **'{count} awaiting review'**
  String adminAwaitingReview(String count);

  /// Section heading in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get adminBankDetails;

  /// Section heading in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Business details'**
  String get adminBusinessDetails;

  /// Summary chip above the commissions console.
  ///
  /// In en, this message translates to:
  /// **'Commission rules'**
  String get adminCommissionRules;

  /// Section heading in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get adminContactDetails;

  /// Heading above the seller review decision form.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get adminDecision;

  /// Prefix for numbered extra documents in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get adminDocAttachment;

  /// Document button in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Business licence'**
  String get adminDocBusinessLicense;

  /// Document button in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Identity document'**
  String get adminDocGovernmentId;

  /// Document button in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Store logo'**
  String get adminDocStoreLogo;

  /// Section heading in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get adminDocuments;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Account holder'**
  String get adminFieldAccountHolder;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get adminFieldBankName;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Business address'**
  String get adminFieldBusinessAddress;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get adminFieldCategory;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Commercial registration'**
  String get adminFieldCommercialRegistration;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Featured on the homepage'**
  String get adminFieldFeatured;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get adminFieldIban;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Legal name'**
  String get adminFieldLegalName;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get adminFieldPriority;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Rate (basis points)'**
  String get adminFieldRateBps;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminFieldReason;

  /// Validation message naming the empty field.
  ///
  /// In en, this message translates to:
  /// **'{field} is required.'**
  String adminFieldRequired(String field);

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Resolution note'**
  String get adminFieldResolution;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminFieldRole;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get adminFieldRuleName;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Seller tier'**
  String get adminFieldSellerTier;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Sensitive value'**
  String get adminFieldSensitive;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Setting key'**
  String get adminFieldSettingKey;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get adminFieldSettingValue;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Visible in the feed'**
  String get adminFieldShowInFeed;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get adminFieldTaxId;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Warehouse address'**
  String get adminFieldWarehouseAddress;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get adminFieldWebsite;

  /// Field label in an admin console action form.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get adminFieldYearsExperience;

  /// The unfiltered choice above an admin queue.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminFilterAll;

  /// Validation message on the system setting form.
  ///
  /// In en, this message translates to:
  /// **'The value must be valid JSON.'**
  String get adminInvalidJson;

  /// Validation message on the commission rule form.
  ///
  /// In en, this message translates to:
  /// **'Enter a rate between 0 and 5000 basis points.'**
  String get adminInvalidRate;

  /// Hint under the system setting value box.
  ///
  /// In en, this message translates to:
  /// **'A JSON value, for example: true, 12, or an object'**
  String get adminJsonHint;

  /// Button that fetches the next page of an admin queue.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminLoadMore;

  /// Empty state in the seller review queue.
  ///
  /// In en, this message translates to:
  /// **'No applications match this filter.'**
  String get adminNoApplications;

  /// Empty state for an admin section.
  ///
  /// In en, this message translates to:
  /// **'No {section} records yet.'**
  String adminNoRecordsYet(String section);

  /// Summary chip above the commissions console.
  ///
  /// In en, this message translates to:
  /// **'Pending commission'**
  String get adminPendingCommission;

  /// Support ticket priority in the admin console.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get adminPriorityHigh;

  /// Support ticket priority in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get adminPriorityLow;

  /// Support ticket priority in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get adminPriorityNormal;

  /// Support ticket priority in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get adminPriorityUrgent;

  /// Hint under the commission rate box.
  ///
  /// In en, this message translates to:
  /// **'250 means 2.5%'**
  String get adminRateHint;

  /// Heading above the JSON dump in the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Raw record'**
  String get adminRawRecord;

  /// Helper under the seller review reason box.
  ///
  /// In en, this message translates to:
  /// **'The applicant is told what you write here.'**
  String get adminReasonReachesApplicant;

  /// Validation on the seller review reason.
  ///
  /// In en, this message translates to:
  /// **'Write a reason of at least three characters.'**
  String get adminReasonRequired;

  /// Section heading in a seller application.
  ///
  /// In en, this message translates to:
  /// **'Review history'**
  String get adminReviewHistory;

  /// Shown when the operator lacks the review permission.
  ///
  /// In en, this message translates to:
  /// **'You can read this application but not decide it.'**
  String get adminReviewNotPermitted;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminRoleAdmin;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Content moderator'**
  String get adminRoleContentModerator;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get adminRoleCustomer;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Finance admin'**
  String get adminRoleFinanceAdmin;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Operations admin'**
  String get adminRoleOperationsAdmin;

  /// Campaign audience field.
  ///
  /// In en, this message translates to:
  /// **'Role segment (optional)'**
  String get adminRoleSegment;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get adminRoleSeller;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Super admin'**
  String get adminRoleSuperAdmin;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Support agent'**
  String get adminRoleSupport;

  /// Staff or account role name in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Support admin'**
  String get adminRoleSupportAdmin;

  /// Campaign scheduling field.
  ///
  /// In en, this message translates to:
  /// **'Schedule time (optional)'**
  String get adminScheduleTime;

  /// Search hint in the seller review queue.
  ///
  /// In en, this message translates to:
  /// **'Search by business, registration, or contact'**
  String get adminSearchApplications;

  /// Title of the seller verification review queue.
  ///
  /// In en, this message translates to:
  /// **'Seller applications'**
  String get adminSellerApplications;

  /// Subtitle of the seller review queue.
  ///
  /// In en, this message translates to:
  /// **'Documents, business details, and the decision that lets her sell.'**
  String get adminSellerApplicationsSubtitle;

  /// Count line above an admin queue.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String adminShowingCount(int shown, int total);

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminStatusActive;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminStatusApproved;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminStatusArchived;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get adminStatusClosed;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get adminStatusDismissed;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminStatusDraft;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get adminStatusEarned;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get adminStatusEscalated;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get adminStatusNotSubmitted;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminStatusOpen;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get adminStatusOutOfStock;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get adminStatusPaid;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminStatusPending;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminStatusRejected;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get adminStatusResolved;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get adminStatusReversed;

  /// Status token shown in the admin console.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get adminStatusReviewing;

  /// Badge on an account an administrator has disabled.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get adminStatusSuspended;

  /// Confirm button on the seller review form.
  ///
  /// In en, this message translates to:
  /// **'Submit decision'**
  String get adminSubmitDecision;

  /// Carts holding this seller's goods
  ///
  /// In en, this message translates to:
  /// **'Open carts'**
  String get analyticsActiveCarts;

  /// Explains the open-carts figure
  ///
  /// In en, this message translates to:
  /// **'Carts holding your goods that have not been ordered yet.'**
  String get analyticsActiveCartsHint;

  /// Customer metric
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get analyticsActiveCustomers;

  /// Customer metric
  ///
  /// In en, this message translates to:
  /// **'Average customer spend'**
  String get analyticsAverageCustomer;

  /// Sales metric
  ///
  /// In en, this message translates to:
  /// **'Average order'**
  String get analyticsAverageOrder;

  /// Revenue line
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get analyticsCollected;

  /// Conversion metric
  ///
  /// In en, this message translates to:
  /// **'Conversion'**
  String get analyticsConversionOverall;

  /// Analytics section heading
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get analyticsCustomersSection;

  /// Analytics empty state
  ///
  /// In en, this message translates to:
  /// **'Nothing happened in this window'**
  String get analyticsEmpty;

  /// Analytics empty state body
  ///
  /// In en, this message translates to:
  /// **'Try a longer window, or publish a product so the counting can start.'**
  String get analyticsEmptyBlurb;

  /// Analytics error state
  ///
  /// In en, this message translates to:
  /// **'Analytics could not be loaded'**
  String get analyticsFailed;

  /// Funnel heading
  ///
  /// In en, this message translates to:
  /// **'The path to a sale'**
  String get analyticsFunnel;

  /// Funnel helper
  ///
  /// In en, this message translates to:
  /// **'From viewing a product to placing an order.'**
  String get analyticsFunnelHint;

  /// Revenue line
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get analyticsGross;

  /// Explains multi-currency totals
  ///
  /// In en, this message translates to:
  /// **'Amounts in different currencies are never added together.'**
  String get analyticsMultiCurrencyHint;

  /// Revenue line
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get analyticsNet;

  /// Customer metric
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get analyticsNewCustomers;

  /// Analytics section heading
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get analyticsOrdersSection;

  /// Sales metric
  ///
  /// In en, this message translates to:
  /// **'Revenue-bearing'**
  String get analyticsPaidOrders;

  /// Analytics range option
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get analyticsPeriodMonth;

  /// Analytics range option
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get analyticsPeriodQuarter;

  /// Analytics range option
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get analyticsPeriodWeek;

  /// Analytics range option
  ///
  /// In en, this message translates to:
  /// **'A year'**
  String get analyticsPeriodYear;

  /// Revenue line
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get analyticsRefunds;

  /// Customer metric
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get analyticsRepeatCustomers;

  /// Customer metric
  ///
  /// In en, this message translates to:
  /// **'Repeat rate'**
  String get analyticsRepeatRate;

  /// Retention metric
  ///
  /// In en, this message translates to:
  /// **'Came back within a month'**
  String get analyticsRetention30;

  /// Retention metric
  ///
  /// In en, this message translates to:
  /// **'Came back within a week'**
  String get analyticsRetention7;

  /// Analytics section heading
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get analyticsRevenueSection;

  /// Realtime section heading
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get analyticsToday;

  /// Realtime metric
  ///
  /// In en, this message translates to:
  /// **'Orders today'**
  String get analyticsTodayOrders;

  /// Product table heading
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get analyticsTopProducts;

  /// Sales metric
  ///
  /// In en, this message translates to:
  /// **'All orders'**
  String get analyticsTotalOrders;

  /// Chart heading
  ///
  /// In en, this message translates to:
  /// **'The trend'**
  String get analyticsTrend;

  /// Chart metric toggle
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get analyticsTrendOrders;

  /// Chart metric toggle
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get analyticsTrendRevenue;

  /// Units sold on a product row
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String analyticsUnitsSold(Object count);

  /// Message-the-seller action on a product
  ///
  /// In en, this message translates to:
  /// **'Ask about this piece'**
  String get askAboutThisPiece;

  /// No description provided for @averageYouGive.
  ///
  /// In en, this message translates to:
  /// **'Your average'**
  String get averageYouGive;

  /// No description provided for @beTheFirstToComment.
  ///
  /// In en, this message translates to:
  /// **'Be the first to say what you think.'**
  String get beTheFirstToComment;

  /// No description provided for @browsingWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your bag, orders and saves'**
  String get browsingWithoutAccount;

  /// Caption on an order-context thread
  ///
  /// In en, this message translates to:
  /// **'About an order'**
  String get chatContextOrder;

  /// Caption on a product-context thread
  ///
  /// In en, this message translates to:
  /// **'About a product'**
  String get chatContextProduct;

  /// Caption on a support thread
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get chatContextSupport;

  /// No description provided for @chatDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get chatDelivered;

  /// Peer presence with a relative time
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String chatLastSeen(String when);

  /// Thread preview when nothing has been sent
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessagesYet;

  /// Peer presence
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get chatOnlineNow;

  /// Marketplace safety note above the conversation list
  ///
  /// In en, this message translates to:
  /// **'Keep payments inside Reem'**
  String get chatSafetyNote;

  /// Body of the marketplace safety note
  ///
  /// In en, this message translates to:
  /// **'A boutique will never ask you to pay outside the app. Report anyone who does.'**
  String get chatSafetyNoteBody;

  /// No description provided for @chatSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get chatSeen;

  /// Chat creation failure
  ///
  /// In en, this message translates to:
  /// **'The conversation could not be opened'**
  String get chatStartFailed;

  /// Peer is composing a message
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get chatTyping;

  /// Fallback name for a thread with no title
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatUntitled;

  /// Inbox empty state action
  ///
  /// In en, this message translates to:
  /// **'Browse the boutiques'**
  String get chatsEmptyAction;

  /// Inbox empty state body
  ///
  /// In en, this message translates to:
  /// **'Ask a boutique about a piece, a size or an order — the conversation will appear here.'**
  String get chatsEmptyMessage;

  /// Inbox empty state shown to a seller
  ///
  /// In en, this message translates to:
  /// **'When a shopper asks about a piece or an order, her message lands here.'**
  String get chatsEmptyMessageSeller;

  /// Inbox empty state title
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatsEmptyTitle;

  /// Inbox error title
  ///
  /// In en, this message translates to:
  /// **'The conversations could not be loaded'**
  String get chatsLoadFailed;

  /// Inbox search empty body
  ///
  /// In en, this message translates to:
  /// **'No conversation matches “{query}”.'**
  String chatsSearchEmptyMessage(String query);

  /// Inbox search empty title
  ///
  /// In en, this message translates to:
  /// **'Nothing matched'**
  String get chatsSearchEmptyTitle;

  /// Inbox search field hint
  ///
  /// In en, this message translates to:
  /// **'Search a name or a message'**
  String get chatsSearchHint;

  /// Inbox subtitle
  ///
  /// In en, this message translates to:
  /// **'Your conversations with the boutiques you shop from'**
  String get chatsSubtitle;

  /// Inbox subtitle shown to a seller
  ///
  /// In en, this message translates to:
  /// **'Your conversations with the women who shop from you'**
  String get chatsSubtitleSeller;

  /// Title of the conversations inbox
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatsTitle;

  /// No description provided for @codAwaitingBanner.
  ///
  /// In en, this message translates to:
  /// **'This order is waiting for its confirmation code.'**
  String get codAwaitingBanner;

  /// No description provided for @codConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm the order'**
  String get codConfirmAction;

  /// No description provided for @codConfirmDispatchFailed.
  ///
  /// In en, this message translates to:
  /// **'The code could not be sent. Try again.'**
  String get codConfirmDispatchFailed;

  /// No description provided for @codConfirmFallback.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to the delivery number \\\\u2014 enter it to confirm the order.'**
  String get codConfirmFallback;

  /// No description provided for @codConfirmLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get codConfirmLater;

  /// No description provided for @codConfirmResend.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get codConfirmResend;

  /// No description provided for @codConfirmResent.
  ///
  /// In en, this message translates to:
  /// **'The code is on its way'**
  String get codConfirmResent;

  /// No description provided for @codConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your order'**
  String get codConfirmTitle;

  /// No description provided for @codConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your order is confirmed'**
  String get codConfirmed;

  /// No description provided for @codEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codEnterCode;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get deleteComment;

  /// No description provided for @deleteCommentBody.
  ///
  /// In en, this message translates to:
  /// **'This removes it for everyone.'**
  String get deleteCommentBody;

  /// No description provided for @faqContactSeller.
  ///
  /// In en, this message translates to:
  /// **'How do I reach a boutique?'**
  String get faqContactSeller;

  /// No description provided for @faqContactSellerAnswer.
  ///
  /// In en, this message translates to:
  /// **'Open the product, the store, or your order and tap “Message the boutique”. Your conversations are kept under Messages.'**
  String get faqContactSellerAnswer;

  /// No description provided for @faqPayment.
  ///
  /// In en, this message translates to:
  /// **'How do I pay?'**
  String get faqPayment;

  /// No description provided for @faqPaymentAnswer.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery, or from your Reem wallet. Never pay a boutique outside the app — an order paid outside it is not protected.'**
  String get faqPaymentAnswer;

  /// Whether the listing accepts returns
  ///
  /// In en, this message translates to:
  /// **'Accept returns'**
  String get formAcceptsReturns;

  /// Change the chosen category
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get formCategoryChange;

  /// Heading for category-driven attribute fields
  ///
  /// In en, this message translates to:
  /// **'What this category asks for'**
  String get formCategoryDetails;

  /// Category picker empty state
  ///
  /// In en, this message translates to:
  /// **'No category by that name'**
  String get formCategoryEmpty;

  /// Category picker error
  ///
  /// In en, this message translates to:
  /// **'Categories could not be loaded'**
  String get formCategoryFailed;

  /// Submit blocked by missing attributes
  ///
  /// In en, this message translates to:
  /// **'Fill in what this category asks for'**
  String get formCategoryNeedsDetails;

  /// Category picker call to action
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get formCategoryPick;

  /// Category picker search field
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get formCategorySearch;

  /// Optional compare-at price
  ///
  /// In en, this message translates to:
  /// **'Price before discount'**
  String get formComparePrice;

  /// Generic required-field error
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get formFieldRequired;

  /// Days before handover
  ///
  /// In en, this message translates to:
  /// **'Handling days'**
  String get formHandlingDays;

  /// Product form section heading
  ///
  /// In en, this message translates to:
  /// **'Product identity'**
  String get formIdentitySection;

  /// Product form section heading
  ///
  /// In en, this message translates to:
  /// **'Selling terms'**
  String get formListingTerms;

  /// Whether the item is produced per order
  ///
  /// In en, this message translates to:
  /// **'Made to order'**
  String get formMadeToOrder;

  /// Lower bound on a single order
  ///
  /// In en, this message translates to:
  /// **'Minimum order quantity'**
  String get formMinOrderQty;

  /// Explains the moderation step
  ///
  /// In en, this message translates to:
  /// **'A new product goes through a short review before customers see it.'**
  String get formNewListingReview;

  /// Marks an optional field
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get formOptional;

  /// Product form section heading
  ///
  /// In en, this message translates to:
  /// **'Price and stock'**
  String get formPricingSection;

  /// Explains why the canonical fields are read-only
  ///
  /// In en, this message translates to:
  /// **'Other sellers list this product, so its page is shared. You can still change your price, stock and terms.'**
  String get formSharedProductLocked;

  /// Stock keeping unit field
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get formSku;

  /// Variant name field
  ///
  /// In en, this message translates to:
  /// **'Option name'**
  String get formVariantName;

  /// Variant price field
  ///
  /// In en, this message translates to:
  /// **'Its price'**
  String get formVariantPrice;

  /// Variants section helper
  ///
  /// In en, this message translates to:
  /// **'Leave this empty for a single-option product.'**
  String get formVariantsHint;

  /// Variants section heading
  ///
  /// In en, this message translates to:
  /// **'Options — size and colour'**
  String get formVariantsTitle;

  /// No description provided for @guestShopper.
  ///
  /// In en, this message translates to:
  /// **'Browsing as a guest'**
  String get guestShopper;

  /// Button that opens a chat with a seller
  ///
  /// In en, this message translates to:
  /// **'Message the boutique'**
  String get messageSeller;

  /// Button on an order parcel
  ///
  /// In en, this message translates to:
  /// **'Message about this order'**
  String get messageSellerAboutOrder;

  /// No description provided for @myReviews.
  ///
  /// In en, this message translates to:
  /// **'My reviews'**
  String get myReviews;

  /// No description provided for @myReviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven’t written a review yet'**
  String get myReviewsEmpty;

  /// No description provided for @myReviewsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'See your orders'**
  String get myReviewsEmptyAction;

  /// No description provided for @myReviewsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'After a parcel arrives, tell the next woman whether it was worth it.'**
  String get myReviewsEmptyBody;

  /// No description provided for @myReviewsFailed.
  ///
  /// In en, this message translates to:
  /// **'Your reviews could not be loaded'**
  String get myReviewsFailed;

  /// No description provided for @myReviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you have said about a piece or a boutique'**
  String get myReviewsSubtitle;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noCommentsYet;

  /// No description provided for @notifActivity.
  ///
  /// In en, this message translates to:
  /// **'From the boutiques you follow'**
  String get notifActivity;

  /// No description provided for @notifChannels.
  ///
  /// In en, this message translates to:
  /// **'How we reach you'**
  String get notifChannels;

  /// No description provided for @notifCommerce.
  ///
  /// In en, this message translates to:
  /// **'Your orders and offers'**
  String get notifCommerce;

  /// No description provided for @notifEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get notifEmail;

  /// No description provided for @notifEmailBlurb.
  ///
  /// In en, this message translates to:
  /// **'Receipts, account notices and longer updates.'**
  String get notifEmailBlurb;

  /// No description provided for @notifOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers and coupons'**
  String get notifOffers;

  /// No description provided for @notifOffersBlurb.
  ///
  /// In en, this message translates to:
  /// **'Discounts, coupons and rewards.'**
  String get notifOffersBlurb;

  /// No description provided for @notifOrders.
  ///
  /// In en, this message translates to:
  /// **'Order updates'**
  String get notifOrders;

  /// No description provided for @notifOrdersBlurb.
  ///
  /// In en, this message translates to:
  /// **'Payment, packing, shipping and delivery.'**
  String get notifOrdersBlurb;

  /// No description provided for @notifPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notifPush;

  /// No description provided for @notifPushBlurb.
  ///
  /// In en, this message translates to:
  /// **'Message alerts, order updates and offers.'**
  String get notifPushBlurb;

  /// No description provided for @notifSellerPosts.
  ///
  /// In en, this message translates to:
  /// **'New posts'**
  String get notifSellerPosts;

  /// No description provided for @notifSellerPostsBlurb.
  ///
  /// In en, this message translates to:
  /// **'When a boutique you follow shares something.'**
  String get notifSellerPostsBlurb;

  /// No description provided for @notifSellerStories.
  ///
  /// In en, this message translates to:
  /// **'New stories'**
  String get notifSellerStories;

  /// No description provided for @notifSellerStoriesBlurb.
  ///
  /// In en, this message translates to:
  /// **'Fresh stories from the boutiques you follow.'**
  String get notifSellerStoriesBlurb;

  /// No description provided for @notifSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get notifSms;

  /// No description provided for @notifSmsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Delivery and account messages that cannot wait.'**
  String get notifSmsBlurb;

  /// No description provided for @notificationPrefsSaved.
  ///
  /// In en, this message translates to:
  /// **'Your notification preferences are saved'**
  String get notificationPrefsSaved;

  /// No description provided for @notificationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Preferences could not load'**
  String get notificationsLoadFailed;

  /// No description provided for @notificationsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading preferences'**
  String get notificationsLoading;

  /// Approved request heading
  ///
  /// In en, this message translates to:
  /// **'Approved — the money is on its way'**
  String get payoutApprovedTitle;

  /// Frozen payout explanation
  ///
  /// In en, this message translates to:
  /// **'Withdrawals are paused to protect your account. This lifts on its own {date}.'**
  String payoutBlockedFrozen(Object date);

  /// Frozen payout, no date
  ///
  /// In en, this message translates to:
  /// **'Withdrawals are paused to protect your account.'**
  String get payoutBlockedFrozenNoDate;

  /// Nothing released explanation
  ///
  /// In en, this message translates to:
  /// **'Nothing is ready yet. Earnings become available once a parcel is delivered and its return window closes.'**
  String get payoutBlockedNothing;

  /// Cancel a pending withdrawal
  ///
  /// In en, this message translates to:
  /// **'Cancel the request'**
  String get payoutCancelAction;

  /// Cancel confirmation body
  ///
  /// In en, this message translates to:
  /// **'The amount returns to your available balance, and you can ask for it again whenever you like.'**
  String get payoutCancelBlurb;

  /// Cancel confirmation title
  ///
  /// In en, this message translates to:
  /// **'Cancel this withdrawal?'**
  String get payoutCancelConfirm;

  /// Cancel success
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled'**
  String get payoutCancelled;

  /// Claimable amount label
  ///
  /// In en, this message translates to:
  /// **'What this request covers'**
  String get payoutClaimable;

  /// How many sales the request covers
  ///
  /// In en, this message translates to:
  /// **'From {count} orders'**
  String payoutFromOrders(Object count);

  /// Open request card heading
  ///
  /// In en, this message translates to:
  /// **'A withdrawal is being reviewed'**
  String get payoutPendingTitle;

  /// Primary withdrawal action
  ///
  /// In en, this message translates to:
  /// **'Request it'**
  String get payoutRequestAction;

  /// Explains that requesting is not being paid
  ///
  /// In en, this message translates to:
  /// **'The request goes to the platform for approval. Nothing is transferred until it is approved.'**
  String get payoutRequestBlurb;

  /// Withdrawal confirmation title
  ///
  /// In en, this message translates to:
  /// **'Withdraw {amount}?'**
  String payoutRequestConfirm(Object amount);

  /// Withdrawal card heading
  ///
  /// In en, this message translates to:
  /// **'Request a withdrawal'**
  String get payoutRequestTitle;

  /// Withdrawal request success
  ///
  /// In en, this message translates to:
  /// **'Your request is in. We will tell you when it is approved.'**
  String get payoutRequested;

  /// When the request was made
  ///
  /// In en, this message translates to:
  /// **'Requested on {date}'**
  String payoutRequestedOn(Object date);

  /// Archive a listing
  ///
  /// In en, this message translates to:
  /// **'Remove from the shop'**
  String get productArchive;

  /// Archive confirmation body
  ///
  /// In en, this message translates to:
  /// **'Customers will no longer see it, and past orders on it are untouched.'**
  String get productArchiveBlurb;

  /// Archive confirmation title
  ///
  /// In en, this message translates to:
  /// **'Remove “{title}” from the shop?'**
  String productArchiveQuestion(Object title);

  /// Archive success
  ///
  /// In en, this message translates to:
  /// **'Removed from the shop'**
  String get productArchived;

  /// No description provided for @productChooseOption.
  ///
  /// In en, this message translates to:
  /// **'Choose {axis}'**
  String productChooseOption(Object axis);

  /// No description provided for @productChooseSeller.
  ///
  /// In en, this message translates to:
  /// **'Choose a boutique'**
  String get productChooseSeller;

  /// No description provided for @productDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get productDetailsSection;

  /// No description provided for @productOffersFrom.
  ///
  /// In en, this message translates to:
  /// **'{count} boutiques list this'**
  String productOffersFrom(Object count);

  /// Pause a listing
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get productPause;

  /// Publish a listing
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get productPublish;

  /// No description provided for @productRelated.
  ///
  /// In en, this message translates to:
  /// **'You may also like'**
  String get productRelated;

  /// Stock adjustment action
  ///
  /// In en, this message translates to:
  /// **'Adjust stock'**
  String get productRestock;

  /// Stock delta field
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get productRestockAmount;

  /// Stock adjustment success
  ///
  /// In en, this message translates to:
  /// **'Stock updated'**
  String get productStockUpdated;

  /// No description provided for @productUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This piece is not available right now'**
  String get productUnavailable;

  /// Return action
  ///
  /// In en, this message translates to:
  /// **'Accept the return'**
  String get returnActionApprove;

  /// Return action
  ///
  /// In en, this message translates to:
  /// **'Exchange instead of refunding'**
  String get returnActionExchange;

  /// Return action
  ///
  /// In en, this message translates to:
  /// **'The replacement arrived'**
  String get returnActionExchangeDelivered;

  /// Return action
  ///
  /// In en, this message translates to:
  /// **'Mark it on its way'**
  String get returnActionInTransit;

  /// Return action
  ///
  /// In en, this message translates to:
  /// **'I have it back'**
  String get returnActionReceive;

  /// Return action
  ///
  /// In en, this message translates to:
  /// **'Refuse the request'**
  String get returnActionReject;

  /// Approve sheet title
  ///
  /// In en, this message translates to:
  /// **'Accept the return'**
  String get returnApproveTitle;

  /// Cost bearer
  ///
  /// In en, this message translates to:
  /// **'The customer'**
  String get returnBearerCustomer;

  /// Cost bearer default
  ///
  /// In en, this message translates to:
  /// **'By the reason given'**
  String get returnBearerDefault;

  /// Cost bearer
  ///
  /// In en, this message translates to:
  /// **'The platform'**
  String get returnBearerPlatform;

  /// Cost bearer
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get returnBearerSeller;

  /// Evidence section
  ///
  /// In en, this message translates to:
  /// **'Her photographs'**
  String get returnEvidence;

  /// Items section
  ///
  /// In en, this message translates to:
  /// **'What is coming back'**
  String get returnItems;

  /// Evidence empty
  ///
  /// In en, this message translates to:
  /// **'She attached no photographs'**
  String get returnNoEvidence;

  /// Optional note field
  ///
  /// In en, this message translates to:
  /// **'A note (optional)'**
  String get returnNoteOptional;

  /// Links a return to its parcel
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String returnParcelLabel(Object number);

  /// Quantity prefix on a return line
  ///
  /// In en, this message translates to:
  /// **'Qty {count}'**
  String returnQuantity(Object count);

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'Changed her mind'**
  String get returnReasonChangedMind;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'Damaged in transit'**
  String get returnReasonDamagedInTransit;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'The item is faulty'**
  String get returnReasonDefective;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'Delivered late'**
  String get returnReasonLateDelivery;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'Not as described'**
  String get returnReasonNotAsDescribed;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'Another reason'**
  String get returnReasonOther;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'The size did not fit'**
  String get returnReasonSizeIssue;

  /// Return reason
  ///
  /// In en, this message translates to:
  /// **'The wrong item arrived'**
  String get returnReasonWrongItem;

  /// Receive sheet title
  ///
  /// In en, this message translates to:
  /// **'Receiving the item'**
  String get returnReceiveTitle;

  /// Refund breakdown line
  ///
  /// In en, this message translates to:
  /// **'The goods'**
  String get returnRefundGoods;

  /// Explains who settles
  ///
  /// In en, this message translates to:
  /// **'The platform pays the refund once you confirm you have the item.'**
  String get returnRefundIsPlatforms;

  /// Refund quote label
  ///
  /// In en, this message translates to:
  /// **'Expected refund'**
  String get returnRefundQuote;

  /// Explains an unsettled quote
  ///
  /// In en, this message translates to:
  /// **'An estimate the server recalculates — not a final figure yet.'**
  String get returnRefundQuoteHint;

  /// Settled refund label
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get returnRefundSettled;

  /// Refund breakdown line
  ///
  /// In en, this message translates to:
  /// **'Return shipping'**
  String get returnRefundShipping;

  /// Reject sheet helper
  ///
  /// In en, this message translates to:
  /// **'The customer reads this, and so does anyone reviewing a dispute.'**
  String get returnRejectHint;

  /// Reject sheet field
  ///
  /// In en, this message translates to:
  /// **'Why are you refusing?'**
  String get returnRejectReason;

  /// Reject validation
  ///
  /// In en, this message translates to:
  /// **'Give a clear reason — at least 5 characters'**
  String get returnRejectTooShort;

  /// Receive sheet toggle
  ///
  /// In en, this message translates to:
  /// **'Put it back in stock'**
  String get returnRestock;

  /// Receive sheet helper
  ///
  /// In en, this message translates to:
  /// **'Leave this off if the item cannot be sold again.'**
  String get returnRestockHint;

  /// Approve sheet question
  ///
  /// In en, this message translates to:
  /// **'Who pays the return leg?'**
  String get returnShippingBearer;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get returnStatusApproved;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'Withdrawn by the customer'**
  String get returnStatusCancelled;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'Exchanged'**
  String get returnStatusExchanged;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'On its way back'**
  String get returnStatusInTransit;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'In your hands'**
  String get returnStatusReceived;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get returnStatusRefunded;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get returnStatusRejected;

  /// Return status
  ///
  /// In en, this message translates to:
  /// **'Awaiting your decision'**
  String get returnStatusRequested;

  /// Deadline line
  ///
  /// In en, this message translates to:
  /// **'The return window closes {date}'**
  String returnWindowCloses(Object date);

  /// Empty state, awaiting tab
  ///
  /// In en, this message translates to:
  /// **'Nothing is awaiting settlement'**
  String get returnsEmptyAwaiting;

  /// Empty state, closed tab
  ///
  /// In en, this message translates to:
  /// **'Nothing has closed yet'**
  String get returnsEmptyClosed;

  /// Empty state, open tab
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting on you'**
  String get returnsEmptyOpen;

  /// Empty state body, open tab
  ///
  /// In en, this message translates to:
  /// **'When a customer asks to send something back, it appears here.'**
  String get returnsEmptyOpenBody;

  /// Returns error state
  ///
  /// In en, this message translates to:
  /// **'Returns could not be loaded'**
  String get returnsFailed;

  /// Returns queue tab
  ///
  /// In en, this message translates to:
  /// **'Awaiting settlement'**
  String get returnsTabAwaiting;

  /// Returns queue tab
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get returnsTabClosed;

  /// Returns queue tab
  ///
  /// In en, this message translates to:
  /// **'Waiting on you'**
  String get returnsTabOpen;

  /// Action success
  ///
  /// In en, this message translates to:
  /// **'The request was updated'**
  String get returnsUpdated;

  /// No description provided for @reviewAboutShop.
  ///
  /// In en, this message translates to:
  /// **'About the boutique'**
  String get reviewAboutShop;

  /// No description provided for @reviewPending.
  ///
  /// In en, this message translates to:
  /// **'Being reviewed'**
  String get reviewPending;

  /// No description provided for @reviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Not published'**
  String get reviewRejected;

  /// Tag on a shop review
  ///
  /// In en, this message translates to:
  /// **'About the shop'**
  String get reviewsAboutShop;

  /// Remove an existing reply
  ///
  /// In en, this message translates to:
  /// **'Remove your reply'**
  String get reviewsDeleteReply;

  /// Edit an existing reply
  ///
  /// In en, this message translates to:
  /// **'Edit your reply'**
  String get reviewsEditReply;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get reviewsEmptyAll;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'When a customer rates something of yours, or the shop itself, it appears here.'**
  String get reviewsEmptyAllBody;

  /// Empty state for the unanswered filter
  ///
  /// In en, this message translates to:
  /// **'You have answered everything'**
  String get reviewsEmptyUnanswered;

  /// Reviews error state
  ///
  /// In en, this message translates to:
  /// **'Reviews could not be loaded'**
  String get reviewsFailed;

  /// Review filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reviewsFilterAll;

  /// Review filter
  ///
  /// In en, this message translates to:
  /// **'Waiting on you'**
  String get reviewsFilterUnanswered;

  /// Reply success
  ///
  /// In en, this message translates to:
  /// **'Your reply is published'**
  String get reviewsReplied;

  /// Write a reply
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reviewsReplyAction;

  /// Reply field label
  ///
  /// In en, this message translates to:
  /// **'Write your reply'**
  String get reviewsReplyField;

  /// Reply sheet helper
  ///
  /// In en, this message translates to:
  /// **'Your reply appears publicly under the review.'**
  String get reviewsReplyHint;

  /// Reply removal success
  ///
  /// In en, this message translates to:
  /// **'Your reply was removed'**
  String get reviewsReplyRemoved;

  /// Tag on a verified review
  ///
  /// In en, this message translates to:
  /// **'Verified purchase'**
  String get reviewsVerifiedBuyer;

  /// No description provided for @reviewsWritten.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews} =1{1 review} other{{count} reviews}}'**
  String reviewsWritten(num count);

  /// Label above the seller's answer
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get reviewsYourReply;

  /// No description provided for @sellerOrderAwaitingCustomerCode.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer\'s confirmation code'**
  String get sellerOrderAwaitingCustomerCode;

  /// No description provided for @sellerReplied.
  ///
  /// In en, this message translates to:
  /// **'The boutique replied'**
  String get sellerReplied;

  /// The seller's returns desk
  ///
  /// In en, this message translates to:
  /// **'Returns and exchanges'**
  String get sellerReturnsTitle;

  /// Profile menu row
  ///
  /// In en, this message translates to:
  /// **'Reviews and replies'**
  String get sellerReviewsMenu;

  /// The seller's review desk
  ///
  /// In en, this message translates to:
  /// **'Reviews and replies'**
  String get sellerReviewsTitle;

  /// No description provided for @sellersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seller} other{{count} sellers}}'**
  String sellersCount(num count);

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @signInToComment.
  ///
  /// In en, this message translates to:
  /// **'Sign in to comment'**
  String get signInToComment;

  /// No description provided for @signInToInteract.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join in'**
  String get signInToInteract;

  /// No description provided for @signInToInteractBody.
  ///
  /// In en, this message translates to:
  /// **'Likes, saves and comments belong to your account, so they travel with you.'**
  String get signInToInteractBody;

  /// No description provided for @signInToManageSecurely.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep this safe across your devices'**
  String get signInToManageSecurely;

  /// Auth prompt title for chat
  ///
  /// In en, this message translates to:
  /// **'Sign in to message the boutique'**
  String get signInToMessage;

  /// Auth prompt body for chat
  ///
  /// In en, this message translates to:
  /// **'Conversations are tied to your account, so you keep them across your devices.'**
  String get signInToMessageBody;

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{yesterday} other{{count} days ago}}'**
  String timeAgoDays(int count);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{an hour ago} other{{count} hours ago}}'**
  String timeAgoHours(int count);

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{a minute ago} other{{count} minutes ago}}'**
  String timeAgoMinutes(int count);

  /// Product alert chip
  ///
  /// In en, this message translates to:
  /// **'Carts abandoned'**
  String get trendAlertCartAbandon;

  /// Product alert chip
  ///
  /// In en, this message translates to:
  /// **'Low conversion'**
  String get trendAlertLowConversion;

  /// Product alert chip
  ///
  /// In en, this message translates to:
  /// **'Overstocked'**
  String get trendAlertOverstock;

  /// Product alert chip
  ///
  /// In en, this message translates to:
  /// **'Sold out, demand live'**
  String get trendAlertSoldOut;

  /// Product alert chip
  ///
  /// In en, this message translates to:
  /// **'Out in {days} days'**
  String trendAlertStockOutIn(int days);

  /// Product alert chip
  ///
  /// In en, this message translates to:
  /// **'Stock running out'**
  String get trendAlertStockRisk;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Average trend score'**
  String get trendAverageScore;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Cart adds'**
  String get trendCartAdds;

  /// Forecast confidence bar label
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get trendConfidence;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Cart conversion'**
  String get trendConversion;

  /// Day count
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String trendDaysValue(int days);

  /// Dismisses an insight or a demand signal
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get trendDismiss;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get trendFavorites;

  /// Forecast line on a product card
  ///
  /// In en, this message translates to:
  /// **'{units} units forecast over {days} days'**
  String trendForecastLine(int units, int days);

  /// Collapses the metrics behind an insight
  ///
  /// In en, this message translates to:
  /// **'Hide the numbers'**
  String get trendHideEvidence;

  /// Marks an insight as actioned
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get trendMarkDone;

  /// Metric label on a shared product page
  ///
  /// In en, this message translates to:
  /// **'Your sales'**
  String get trendMyUnits;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get trendOrders;

  /// Suffix on a trend score change
  ///
  /// In en, this message translates to:
  /// **' pts'**
  String get trendPointsSuffix;

  /// Leaderboard position
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}'**
  String trendRankValue(int rank);

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get trendRevenue;

  /// Metric hint
  ///
  /// In en, this message translates to:
  /// **'{count} products rising'**
  String trendRisingCount(int count);

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Search appearances'**
  String get trendSearchHits;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Searches'**
  String get trendSearches;

  /// Expands the metrics behind an insight
  ///
  /// In en, this message translates to:
  /// **'Show the numbers'**
  String get trendShowEvidence;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Cooling'**
  String get trendStageCooling;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Declining'**
  String get trendStageDeclining;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Dormant'**
  String get trendStageDormant;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Emerging'**
  String get trendStageEmerging;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Peaking'**
  String get trendStagePeaking;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Rising'**
  String get trendStageRising;

  /// Trend stage
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get trendStageSteady;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get trendStock;

  /// Stock-out due today
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get trendToday;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get trendUnits;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Units sold'**
  String get trendUnitsSold;

  /// Unmet demand status
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get trendUnmetAcknowledged;

  /// Unmet demand status
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get trendUnmetAddressed;

  /// Unmet demand status
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get trendUnmetDismissed;

  /// Unmet demand status
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get trendUnmetOpen;

  /// Unmet demand status
  ///
  /// In en, this message translates to:
  /// **'Sourcing'**
  String get trendUnmetSourcing;

  /// Unmet demand summary
  ///
  /// In en, this message translates to:
  /// **'{searches} searches · {missRate}% with no suitable result'**
  String trendUnmetSummary(int searches, int missRate);

  /// Secondary conversion figure
  ///
  /// In en, this message translates to:
  /// **'view to cart {rate}'**
  String trendViewToCart(String rate);

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get trendViews;

  /// Trend look-back selector
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get trendWindow14;

  /// Trend look-back selector
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get trendWindow30;

  /// Trend look-back selector
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get trendWindow7;

  /// Admin empty state body
  ///
  /// In en, this message translates to:
  /// **'The nightly run has not happened yet, or there is not enough activity. You can run it now from the recompute button.'**
  String get trendsAdminEmptyBody;

  /// Admin empty state title
  ///
  /// In en, this message translates to:
  /// **'No analysis results yet'**
  String get trendsAdminEmptyTitle;

  /// Admin trend dashboard title
  ///
  /// In en, this message translates to:
  /// **'Market intelligence'**
  String get trendsAdminTitle;

  /// Footer stating when the figures were produced
  ///
  /// In en, this message translates to:
  /// **'Computed on {date} — refreshed once a day'**
  String trendsAsOf(String date);

  /// Admin categories heading
  ///
  /// In en, this message translates to:
  /// **'Category trends'**
  String get trendsCategories;

  /// Admin categories hint
  ///
  /// In en, this message translates to:
  /// **'Ranked by trend score, with in-stock coverage'**
  String get trendsCategoriesHint;

  /// Category supply line
  ///
  /// In en, this message translates to:
  /// **'{inStock} of {total} products in stock'**
  String trendsCategorySupply(int inStock, int total);

  /// Admin colours heading
  ///
  /// In en, this message translates to:
  /// **'Colour trends'**
  String get trendsColours;

  /// Admin colours hint
  ///
  /// In en, this message translates to:
  /// **'Share of demand per colour, now against the previous window'**
  String get trendsColoursHint;

  /// Admin declining heading
  ///
  /// In en, this message translates to:
  /// **'Declining products'**
  String get trendsDeclining;

  /// Admin declining hint
  ///
  /// In en, this message translates to:
  /// **'Largest drop in trend score'**
  String get trendsDecliningHint;

  /// Admin forecast heading
  ///
  /// In en, this message translates to:
  /// **'Demand forecast'**
  String get trendsDemandForecast;

  /// Admin forecast hint
  ///
  /// In en, this message translates to:
  /// **'Platform total over the coming days'**
  String get trendsDemandForecastHint;

  /// Seller demand panel heading
  ///
  /// In en, this message translates to:
  /// **'Demand signals'**
  String get trendsDemandSignals;

  /// Seller demand panel hint
  ///
  /// In en, this message translates to:
  /// **'Interest in your products, separately from what sold'**
  String get trendsDemandSignalsHint;

  /// Emerging section heading
  ///
  /// In en, this message translates to:
  /// **'Emerging products'**
  String get trendsEmerging;

  /// Emerging section hint
  ///
  /// In en, this message translates to:
  /// **'Demand accelerating before they become best sellers'**
  String get trendsEmergingHint;

  /// Seller empty state body
  ///
  /// In en, this message translates to:
  /// **'The trend engine needs about a week of activity before it can spot a direction. Keep listing, and results will appear here.'**
  String get trendsEmptyBody;

  /// Seller empty state title
  ///
  /// In en, this message translates to:
  /// **'The engine has not collected enough data yet'**
  String get trendsEmptyTitle;

  /// Trend error state
  ///
  /// In en, this message translates to:
  /// **'Trend analysis could not be loaded'**
  String get trendsFailed;

  /// Seller forecast heading
  ///
  /// In en, this message translates to:
  /// **'Sales forecast'**
  String get trendsForecast;

  /// Seller forecast hint
  ///
  /// In en, this message translates to:
  /// **'Built from your sales history, with how much to believe it'**
  String get trendsForecastHint;

  /// Shown when the forecast method is INSUFFICIENT_DATA
  ///
  /// In en, this message translates to:
  /// **'There is not enough sales history yet to build a forecast. It will appear here automatically after about two weeks of activity.'**
  String get trendsForecastInsufficient;

  /// Forecast provenance line
  ///
  /// In en, this message translates to:
  /// **'Method: {method} · confidence {confidence}%'**
  String trendsForecastMethod(String method, int confidence);

  /// Forecast headline label
  ///
  /// In en, this message translates to:
  /// **'Forecast units over {days} days'**
  String trendsForecastUnitsLabel(int days);

  /// Opportunity kind label
  ///
  /// In en, this message translates to:
  /// **'Category gap'**
  String get trendsGapCategory;

  /// Opportunity kind label
  ///
  /// In en, this message translates to:
  /// **'Price gap'**
  String get trendsGapPrice;

  /// Opportunity kind label
  ///
  /// In en, this message translates to:
  /// **'Unmet search'**
  String get trendsGapSearch;

  /// Conversion section heading
  ///
  /// In en, this message translates to:
  /// **'Low conversion alerts'**
  String get trendsLowConversion;

  /// Conversion section hint
  ///
  /// In en, this message translates to:
  /// **'High views that are not turning into orders'**
  String get trendsLowConversionHint;

  /// Admin insight feed heading
  ///
  /// In en, this message translates to:
  /// **'Market insights'**
  String get trendsMarketInsights;

  /// Admin insight feed hint
  ///
  /// In en, this message translates to:
  /// **'Readings computed from the platform own figures'**
  String get trendsMarketInsightsHint;

  /// Search miss rate
  ///
  /// In en, this message translates to:
  /// **'{rate}% no result'**
  String trendsMissRate(int rate);

  /// Count suffix when a list is truncated
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String trendsOfTotal(int total);

  /// Admin opportunities heading
  ///
  /// In en, this message translates to:
  /// **'Market opportunities'**
  String get trendsOpportunities;

  /// Admin opportunities hint
  ///
  /// In en, this message translates to:
  /// **'Where there is demand with no assortment behind it'**
  String get trendsOpportunitiesHint;

  /// Admin headline heading
  ///
  /// In en, this message translates to:
  /// **'Overall trends'**
  String get trendsOverall;

  /// Admin headline hint
  ///
  /// In en, this message translates to:
  /// **'Platform activity for the window, against the one before it'**
  String get trendsOverallHint;

  /// Admin price bands heading
  ///
  /// In en, this message translates to:
  /// **'Price band trends'**
  String get trendsPriceBands;

  /// Admin price bands hint
  ///
  /// In en, this message translates to:
  /// **'Where demand is moving in price'**
  String get trendsPriceBandsHint;

  /// Seller insight feed heading
  ///
  /// In en, this message translates to:
  /// **'What to do today'**
  String get trendsRecommendedActions;

  /// Seller insight feed hint
  ///
  /// In en, this message translates to:
  /// **'Findings computed from your shop data, most important first'**
  String get trendsRecommendedActionsHint;

  /// Admin action that re-runs the nightly pipeline
  ///
  /// In en, this message translates to:
  /// **'Recompute analysis'**
  String get trendsRecompute;

  /// Admin search heading
  ///
  /// In en, this message translates to:
  /// **'Search trends'**
  String get trendsSearches;

  /// Admin search hint
  ///
  /// In en, this message translates to:
  /// **'What customers search for most, and how often it misses'**
  String get trendsSearchesHint;

  /// Admin sellers heading
  ///
  /// In en, this message translates to:
  /// **'Seller performance'**
  String get trendsSellerPerformance;

  /// Admin sellers hint
  ///
  /// In en, this message translates to:
  /// **'Growth, with cancellation and return rates beside it'**
  String get trendsSellerPerformanceHint;

  /// Seller quality line
  ///
  /// In en, this message translates to:
  /// **'cancelled {cancel}% · returned {returns}%'**
  String trendsSellerQuality(int cancel, int returns);

  /// Seller trend dashboard title
  ///
  /// In en, this message translates to:
  /// **'Trend engine'**
  String get trendsSellerTitle;

  /// Stage distribution panel title
  ///
  /// In en, this message translates to:
  /// **'Products across the demand curve'**
  String get trendsStageDistribution;

  /// Stage distribution footnote
  ///
  /// In en, this message translates to:
  /// **'{scored} active of {total} scored products'**
  String trendsStageScored(int scored, int total);

  /// Stock section heading
  ///
  /// In en, this message translates to:
  /// **'Stock opportunities'**
  String get trendsStockOpportunities;

  /// Stock section hint
  ///
  /// In en, this message translates to:
  /// **'Live demand with stock running out or already gone'**
  String get trendsStockOpportunitiesHint;

  /// Trending section heading
  ///
  /// In en, this message translates to:
  /// **'Trending products'**
  String get trendsTrending;

  /// Trending section hint
  ///
  /// In en, this message translates to:
  /// **'Highest trend score in the selected window'**
  String get trendsTrendingHint;

  /// Admin unmet demand heading
  ///
  /// In en, this message translates to:
  /// **'Unmet demand'**
  String get trendsUnmetDemand;

  /// Admin unmet demand hint
  ///
  /// In en, this message translates to:
  /// **'Searches that returned nothing customers wanted'**
  String get trendsUnmetDemandHint;

  /// Opens the seller storefront
  ///
  /// In en, this message translates to:
  /// **'Visit the store'**
  String get visitStore;

  /// Onboarding slide title about shopping [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'A boutique in your pocket'**
  String get onboardShopTitle;

  /// Onboarding slide body about shopping [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Dresses, beauty and gifts from Syrian boutiques, all in one place.'**
  String get onboardShopBody;

  /// Onboarding slide title about stories [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'See what is new today'**
  String get onboardStoriesTitle;

  /// Onboarding slide body about stories [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Follow the shops you love and catch their stories the moment they post.'**
  String get onboardStoriesBody;

  /// Onboarding slide title about sharing [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Share what you find'**
  String get onboardShareTitle;

  /// Onboarding slide body about sharing [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Save pieces, write reviews and send your favourites to your friends.'**
  String get onboardShareBody;

  /// Skips the onboarding tour [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardSkip;

  /// Advances to the next onboarding slide [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardContinue;

  /// Finishes onboarding [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get onboardStart;

  /// Fallback heading for a category page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryTitle;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Dresses'**
  String get categoryDresses;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Evening, occasion and everyday'**
  String get categoryDressesBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Makeup and skincare'**
  String get categoryBeautyBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Fragrance'**
  String get categoryFragrance;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Perfumes and mists'**
  String get categoryFragranceBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Bags'**
  String get categoryBags;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Handbags, clutches and totes'**
  String get categoryBagsBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get categoryShoes;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Heels, flats and sandals'**
  String get categoryShoesBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Jewellery'**
  String get categoryJewellery;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Gold, silver and everyday pieces'**
  String get categoryJewelleryBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get categoryAccessories;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Scarves, belts and the finishing touch'**
  String get categoryAccessoriesBlurb;

  /// Category name [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryGifts;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Flowers, chocolate and occasion boxes'**
  String get categoryGiftsBlurb;

  /// Heading over trending search terms [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get searchTrendingNow;

  /// Eyebrow over the trending block [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get searchTrendingEyebrow;

  /// Heading over the department chips [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Browse categories'**
  String get searchBrowseCategories;

  /// Eyebrow over the departments block [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get searchDiscoverEyebrow;

  /// Heading over recent searches [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// Clears the recent search history [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get searchClearAll;

  /// Clears the search field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'فستان'**
  String get searchTrendDresses;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'عطر'**
  String get searchTrendPerfume;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'حقيبة'**
  String get searchTrendBags;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'حذاء'**
  String get searchTrendHeels;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'هدية'**
  String get searchTrendGifts;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'ورد'**
  String get searchTrendFlowers;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'كريم'**
  String get searchTrendSkincare;

  /// Empty state for a collection with no products [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No pieces here yet'**
  String get noProductsFound;

  /// Fallback title of a profile page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Opens the edit-profile screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// Title of the edit-profile screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// Name field on the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullName;

  /// Bio field on the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// Location field on the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileLocation;

  /// Submits the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSaveChanges;

  /// Validation message for a name that is too short [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get profileNameTooShort;

  /// Validation message for an over-long bio [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'That is a little long'**
  String get profileBioTooLong;

  /// Confirmation after saving the profile [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your profile is saved'**
  String get profileUpdated;

  /// Follower count label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowers;

  /// Following count label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// Post count label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profilePosts;

  /// Opens the seller store management [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Manage store'**
  String get profileManageStore;

  /// Error when a profile fails to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'This profile could not load'**
  String get profileLoadFailed;

  /// Explains what signing in adds, shown to a guest [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sign in to save pieces, follow boutiques and track your orders.'**
  String get guestBrowseBlurb;

  /// Benefits of creating an account [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Create an account to checkout, message sellers and keep your favourites.'**
  String get signUpBenefitsBlurb;

  /// How many achievements are earned [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{earned} of {total}'**
  String achievementsEarned(int earned, int total);

  /// Loyalty tier line on the profile [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{tier} member'**
  String loyaltyTierMember(String tier);

  /// Confirmation after a profile update from settings [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your profile is saved'**
  String get settingsProfileUpdated;

  /// Heading of the reviews section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsSectionTitle;

  /// Opens the review composer [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get reviewsWriteAction;

  /// Short label for writing a review [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get reviewsWriteShort;

  /// Title field of the review form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get reviewsFieldTitle;

  /// Body field of the review form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'What did you think?'**
  String get reviewsFieldBody;

  /// Submits a review [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Post review'**
  String get reviewsSubmit;

  /// Confirmation after posting a review [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Thank you — your review is posted'**
  String get reviewsSubmitted;

  /// Empty state title for reviews [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get reviewsNoneTitle;

  /// Empty state body for reviews [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Be the first to say what you think.'**
  String get reviewsNoneBody;

  /// Error title when reviews fail to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Reviews could not load'**
  String get reviewsUnavailable;

  /// Badge on a review left by a confirmed buyer [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Verified purchase'**
  String get reviewsVerified;

  /// Star rating tooltip [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String reviewsStarsCount(int count);

  /// Rating and review count under a product title [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count, plural, =1{1 review} other{{count} reviews}}'**
  String productRatingSummary(String rating, int count);

  /// Fallback title of an order page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderTitle;

  /// Shown when an order cannot be loaded [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'This order could not be found'**
  String get orderNotFound;

  /// Title of the cancel-order dialog [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get orderCancelTitle;

  /// Body of the cancel-order dialog [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'The sellers will be told and nothing will be shipped.'**
  String get orderCancelBody;

  /// Confirms cancelling an order [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get orderCancelConfirm;

  /// Dismisses the cancel-order dialog [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get orderCancelKeep;

  /// Title of the create-post screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get createPostTitle;

  /// Subtitle of the create-post screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Show a piece and tell her why it is worth it.'**
  String get createPostBody;

  /// Publishes a post [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createPostAction;

  /// Attaches a product to a post [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Tag a product'**
  String get createPostAddProduct;

  /// Label of the featured-product field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Featured product'**
  String get createPostFeatured;

  /// Loading label while the seller products load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Loading your products'**
  String get createPostLoadingProducts;

  /// Validation when a post has no caption [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Write a caption first'**
  String get createPostNeedsCaption;

  /// Validation when a post has no product [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Choose a product first'**
  String get createPostNeedsProduct;

  /// Empty state when the seller has nothing to tag [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get createPostNoProducts;

  /// Empty state body on the create-post screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Add a product to your store, then post about it.'**
  String get createPostNoProductsBody;

  /// Confirmation after publishing a post [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your post is live'**
  String get createPostSuccess;

  /// Placeholder of the caption field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Say something about it…'**
  String get createCaptionHint;

  /// Title of the create-story screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get createStoryTitle;

  /// Subtitle of the create-story screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'A frame from today, gone in twenty-four hours.'**
  String get createStoryBody;

  /// Publishes a story [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Share story'**
  String get createStoryAction;

  /// Optional link field on the create-story screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get createStoryOptionalLink;

  /// Validation for a malformed story link [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'That link does not look right'**
  String get createStoryBadLink;

  /// Confirmation after publishing a story [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your story is live'**
  String get createStorySuccess;

  /// Picks a photo [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get mediaImage;

  /// Picks a video [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaVideo;

  /// Placeholder of the chat composer [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get chatWriteMessage;

  /// Opens the attachment menu [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttachments;

  /// Attaches a product to a message [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get chatProduct;

  /// Attaches an order to a message [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get chatOrder;

  /// Records a voice note [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get chatVoice;

  /// Delivery status of a sent message [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatSent;

  /// Date divider for today [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// File size on an attachment [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String fileSizeMegabytes(String size);

  /// Badge on a product with no stock [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get soldOut;

  /// Stock state label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get stockOut;

  /// Stock state label for low stock [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Only a few left'**
  String get stockLow;

  /// Eyebrow over the flash deals rail [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get flashLimitedTime;

  /// How much of a flash deal is left [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left} other{{count} left}}'**
  String flashAlmostGone(int count);

  /// Follows a boutique [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followAction;

  /// Shown when already following [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingState;

  /// Expands a truncated block [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// Offline banner [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'You are offline — showing what was saved'**
  String get offlineShowingSaved;

  /// Default confirm button of a dialog [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dialogConfirm;

  /// Default dismiss button of an informational dialog [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get dialogGotIt;

  /// Title of the AI stylist screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Reem Stylist'**
  String get aiStylistTitle;

  /// Title of a stylist outfit page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'The look'**
  String get stylistOutfitTitle;

  /// Title of the stylist preferences screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your style'**
  String get stylistPreferencesTitle;

  /// Title of the visual search screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Search by photo'**
  String get visualSearchTitle;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sellerSalesStat;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get sellerOrdersStat;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get sellerProductsStat;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get sellerRatingStat;

  /// Error when the seller dashboard fails to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'The dashboard could not load'**
  String get sellerDashboardLoadFailed;

  /// Cart abandonment rate [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{rate}% left the cart'**
  String sellerCartAbandon(String rate);

  /// How many products are critically low [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece needs restocking} other{{count} pieces need restocking}}'**
  String sellerRestockNeeded(int count);

  /// Empty state in an admin section with no actions [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Nothing to do here yet'**
  String get adminSectionNoActions;

  /// Shown when an admin section has no create action [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Nothing can be created here'**
  String get adminSectionNoCreate;

  /// Confirmation after generating a report [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{format} report ready — {count} rows'**
  String adminReportGenerated(String format, int count);

  /// Title of the rewards screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewardsTitle;

  /// Error when the rewards hub fails to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards could not load'**
  String get rewardsLoadFailed;

  /// Shown when the rewards hub is unavailable [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards are not available right now'**
  String get rewardsUnavailable;

  /// Label over the points balance [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Points available'**
  String get rewardsAvailablePoints;

  /// Points label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get rewardsPoints;

  /// Screen-reader summary of the rewards balance [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{points} points, {tier} tier'**
  String rewardsBalanceSemantics(int points, String tier);

  /// Heading of the membership tier section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your tier'**
  String get rewardsTierSection;

  /// Membership line for a standard tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{tier} member'**
  String rewardsTierMember(String tier);

  /// Membership line for the top tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{tier} membership'**
  String rewardsTierVip(String tier);

  /// Label for the highest tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Top tier'**
  String get rewardsTopTier;

  /// Shown when no higher tier remains [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'You are at the top tier'**
  String get rewardsTopTierUnlocked;

  /// Names the next tier up [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Next: {tier}'**
  String rewardsNextTier(String tier);

  /// Progress toward the next tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the way to {tier}'**
  String rewardsProgressToward(int percent, String tier);

  /// Points multiplier benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{multiplier}x points on every order'**
  String rewardsMultiplier(String multiplier);

  /// Note under the points multiplier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Earned automatically as you shop'**
  String get rewardsTierBonusNote;

  /// Cashback rate benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{rate}% cashback'**
  String rewardsCashbackRate(String rate);

  /// Note under the cashback rate [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Paid back to your wallet after delivery'**
  String get rewardsCashbackNote;

  /// Membership benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Points on every order'**
  String get rewardsBenefitPoints;

  /// Membership benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Member-only offers'**
  String get rewardsBenefitOffers;

  /// Membership benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards for every friend you invite'**
  String get rewardsBenefitReferrals;

  /// Heading of the redeemable rewards section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get rewardsRedeemSection;

  /// How many rewards are redeemable [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to redeem yet} =1{1 offer} other{{count} offers}}'**
  String rewardsOffersCount(int count);

  /// Empty state title in the rewards list [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No rewards yet'**
  String get rewardsEmptyTitle;

  /// Empty state body in the rewards list [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Keep shopping and offers will appear here.'**
  String get rewardsEmptyBody;

  /// Redeems a reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get rewardsRedeem;

  /// Claims an exclusive reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get rewardsClaim;

  /// Confirmation after redeeming a reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Redeemed — the code is in your coupons'**
  String get rewardsRedeemed;

  /// Badge on a member-only reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get rewardsExclusive;

  /// Fallback description of a reward with no cost or value [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Member reward'**
  String get rewardsMemberReward;

  /// What a reward costs in points [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String rewardsPointsCost(int points);

  /// Shown when a reward costs more points than she holds [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Not enough points yet'**
  String get rewardsNotEnoughPoints;

  /// Cashback section label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get rewardsCashback;

  /// Explains cashback [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'A share of what you spend, back in your wallet.'**
  String get rewardsCashbackBody;

  /// Cashback that can be used now [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get rewardsAvailable;

  /// Cashback not yet released [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get rewardsPending;

  /// Lifetime cashback [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Earned in total'**
  String get rewardsLifetime;

  /// Bonus cashback label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get rewardsBonus;

  /// Converts cashback into a coupon [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Turn into a coupon'**
  String get rewardsConvertToCoupon;

  /// Confirmation after converting cashback [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your cashback is now a coupon'**
  String get rewardsCashbackConverted;

  /// Shown when there is no cashback to convert [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No cashback to convert yet'**
  String get rewardsNoCashback;

  /// Heading of the referral section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get rewardsInviteTitle;

  /// Explains referrals [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'She gets a welcome offer, you get points.'**
  String get rewardsInviteBody;

  /// Label of the customer referral code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get rewardsCustomerCode;

  /// Label of the seller referral code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your seller code'**
  String get rewardsSellerCode;

  /// Placeholder while a referral code is created [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get rewardsGenerating;

  /// Tooltip on a copy button [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String rewardsCopyLabel(String label);

  /// Confirmation after copying a code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{code} copied'**
  String rewardsCodeCopied(String code);

  /// How many friends were invited [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get rewardsInvited;

  /// How many referrals paid out [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewarded'**
  String get rewardsRewarded;

  /// Referrals held for review [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invite is being checked} other{{count} invites are being checked}}'**
  String rewardsSuspiciousChecks(int count);

  /// Label of the code entry field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Have a code?'**
  String get rewardsHaveCode;

  /// Placeholder of the code field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get rewardsEnterCode;

  /// Applies an entered code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get rewardsApplyCode;

  /// Confirmation after applying a code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Code applied'**
  String get rewardsCodeApplied;

  /// Shown when a code is rejected [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'That code did not work'**
  String get rewardsCodeInvalid;

  /// Shown when a rewards action needs the network [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'You are offline — this needs a connection'**
  String get rewardsOfflineHint;

  /// Retries a rewards action [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rewardsOfflineRetry;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'سهرة'**
  String get searchTrendEvening;

  /// Bottom navigation — buyer home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation — search tab
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Bottom navigation — cart tab
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// Bottom navigation — activity tab
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// Bottom navigation — profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Seller navigation — dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navSellerDashboard;

  /// Seller navigation — products
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navSellerProducts;

  /// Seller navigation — orders
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navSellerOrders;

  /// Seller navigation — analytics
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navSellerAnalytics;

  /// Seller navigation — store profile
  ///
  /// In en, this message translates to:
  /// **'My store'**
  String get navSellerStore;

  /// Shell action — AI stylist
  ///
  /// In en, this message translates to:
  /// **'Stylist'**
  String get actionStylist;

  /// Shell action — search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Shell action — cart
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get actionCart;

  /// Shell action — add a product
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get actionNewProduct;

  /// Shell action — compose a post
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get actionNewPost;

  /// Shell action — moderation queue
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get actionModeration;

  /// Shell action — reports
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get actionReports;

  /// Shell action — orders
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get actionOrders;

  /// Shell action — wishlist
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get actionWishlist;

  /// Shell action — rewards
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get actionRewards;

  /// Shell action — coupons
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get actionCoupons;

  /// Shell action — address book
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get actionAddresses;

  /// Shell action — payment methods
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get actionPayments;

  /// Shell action — notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get actionNotifications;

  /// Shell action — settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// Shell action — returns
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get actionReturns;

  /// Shell action — chats
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get actionConversations;

  /// Shell action — analytics
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get actionAnalytics;

  /// Shell action — trend engine
  ///
  /// In en, this message translates to:
  /// **'Trend engine'**
  String get actionTrends;

  /// Shell action — storefront profile
  ///
  /// In en, this message translates to:
  /// **'Store profile'**
  String get actionStoreProfile;

  /// Shell action — seller verification
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get actionVerification;

  /// Shell action — security settings
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get actionSecurity;

  /// Shell action — users
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get actionUsers;

  /// Shell action — sellers
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get actionSellers;

  /// Shell action — products
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get actionProducts;

  /// Shell action — finance
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get actionFinance;

  /// Shell action — audit logs
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get actionAudit;

  /// Menu group — shopping
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get menuGroupShopping;

  /// Menu group — rewards
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get menuGroupRewards;

  /// Menu group — account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get menuGroupAccount;

  /// Menu group — seller operations
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get menuGroupOperations;

  /// Menu group — growth
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get menuGroupGrowth;

  /// Menu group — store
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get menuGroupStore;

  /// Menu group — governance
  ///
  /// In en, this message translates to:
  /// **'Governance'**
  String get menuGroupGovernance;

  /// Menu group — risk
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get menuGroupRisk;

  /// Menu group — control
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get menuGroupControl;

  /// Nearby boutiques — badge for a shop in the same city
  ///
  /// In en, this message translates to:
  /// **'In your city'**
  String get homeNearbyInYourCity;

  /// Nearby boutiques — badge for a shop elsewhere in the governorate
  ///
  /// In en, this message translates to:
  /// **'In your governorate'**
  String get homeNearbyInGovernorate;

  /// Nearby boutiques — section subtitle
  ///
  /// In en, this message translates to:
  /// **'Boutiques shipping from your governorate — they arrive sooner'**
  String get homeNearbySubtitle;

  /// Confirmation after bookmarking a post
  ///
  /// In en, this message translates to:
  /// **'Saved to your wishlist'**
  String get postSaved;

  /// Confirmation after un-bookmarking a post
  ///
  /// In en, this message translates to:
  /// **'Removed from your wishlist'**
  String get postUnsaved;

  /// Snackbar action opening the wishlist
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewSaved;

  /// Collection page title — featured
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get collectionFeatured;

  /// Collection page title — most loved
  ///
  /// In en, this message translates to:
  /// **'Most loved'**
  String get collectionMostLoved;

  /// Collection page title — top rated
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get collectionTopRated;

  /// Collection page title — discounted pieces
  ///
  /// In en, this message translates to:
  /// **'All deals'**
  String get collectionDeals;

  /// Product gallery — position announcement
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {count}'**
  String galleryPhotoPosition(int index, int count);

  /// Product gallery — full screen action
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get galleryOpenPhoto;

  /// Full-screen gallery — close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get galleryClose;

  /// Reviews list — banner over the viewer's own pending review
  ///
  /// In en, this message translates to:
  /// **'Your review is in — it appears publicly once it is checked'**
  String get reviewsPendingYours;

  /// Edit profile - recovery email field
  ///
  /// In en, this message translates to:
  /// **'Recovery email'**
  String get profileRecoveryEmail;

  /// Edit profile - recovery email helper
  ///
  /// In en, this message translates to:
  /// **'Used to get your account back if you lose your number'**
  String get profileRecoveryEmailHint;

  /// Edit profile - email validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get profileEmailInvalid;

  /// Follow list - empty following
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get followListEmptyFollowing;

  /// Follow list - empty followers
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get followListEmptyFollowers;

  /// Orders list - filter chip for every order
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ordersFilterAll;

  /// Orders list - empty state for a filter
  ///
  /// In en, this message translates to:
  /// **'Nothing in this pile'**
  String get ordersEmptyForFilter;

  /// Order payment - panel title
  ///
  /// In en, this message translates to:
  /// **'Finish paying'**
  String get paymentActionTitle;

  /// Order payment - open the gateway
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get paymentOpenGateway;

  /// Order payment - online rail hint
  ///
  /// In en, this message translates to:
  /// **'We will open {method} to take the payment, then come back and check.'**
  String paymentGatewayHint(String method);

  /// Order payment - manual rail hint
  ///
  /// In en, this message translates to:
  /// **'Transfer the amount via {method}, then enter the reference here so finance can match it.'**
  String paymentManualHint(String method);

  /// Order payment - reference field
  ///
  /// In en, this message translates to:
  /// **'Transfer reference'**
  String get paymentReferenceLabel;

  /// Order payment - submit reference
  ///
  /// In en, this message translates to:
  /// **'Send reference'**
  String get paymentReferenceSubmit;

  /// Order payment - reference stored
  ///
  /// In en, this message translates to:
  /// **'Reference received — we will confirm once it is matched'**
  String get paymentReferenceSaved;

  /// Order payment - empty reference
  ///
  /// In en, this message translates to:
  /// **'Enter the reference first'**
  String get paymentReferenceRequired;

  /// Order payment - verify returned pending
  ///
  /// In en, this message translates to:
  /// **'The payment has not reached us yet'**
  String get paymentStillPending;

  /// Order payment - verify action
  ///
  /// In en, this message translates to:
  /// **'Check the payment'**
  String get paymentCheckAgain;

  /// Order payment - launch failed
  ///
  /// In en, this message translates to:
  /// **'Could not open the payment page'**
  String get paymentCouldNotOpen;

  /// Order payment - stored reference
  ///
  /// In en, this message translates to:
  /// **'Reference on file'**
  String get paymentReferenceOnFile;

  /// Order payment - verify succeeded
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get paymentConfirmed;

  /// Checkout - privacy mask toggle
  ///
  /// In en, this message translates to:
  /// **'Hide my full name from the boutique'**
  String get checkoutPrivacyMask;

  /// Checkout - privacy mask explanation
  ///
  /// In en, this message translates to:
  /// **'The boutique sees only your first name. The courier still needs your details to deliver.'**
  String get checkoutPrivacyMaskHint;

  /// Order detail - privacy mask applied
  ///
  /// In en, this message translates to:
  /// **'Your name is hidden from the boutique'**
  String get orderPrivacyMaskOn;
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
