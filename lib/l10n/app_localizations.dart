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

  /// Screen-reader label for the back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a11yBack;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get a11yCart;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get a11yClose;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get a11yLike;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get a11yMore;

  /// No description provided for @a11yMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get a11yMute;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get a11yNotifications;

  /// Screen-reader label for a tappable card
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String a11yOpen(String name);

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get a11yPlay;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get a11yProfile;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get a11ySave;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get a11ySearch;

  /// Screen-reader label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get a11yShare;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'About Ohara'**
  String get aboutOhara;

  /// About screen description
  ///
  /// In en, this message translates to:
  /// **'A premium social-commerce home for the pieces you love — shopping, discovery and community in one place.'**
  String get aboutOharaBlurb;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Account holder'**
  String get accountHolder;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Account updated.'**
  String get accountUpdated;

  /// Title of the screen where a customer applies for the verified badge
  ///
  /// In en, this message translates to:
  /// **'Account verification'**
  String get accountVerification;

  /// Shown to a verified account
  ///
  /// In en, this message translates to:
  /// **'The badge is on your name.'**
  String get accountVerificationApprovedBlurb;

  /// Label of the back-of-document upload
  ///
  /// In en, this message translates to:
  /// **'Document — back'**
  String get accountVerificationBack;

  /// Explains what verification is for
  ///
  /// In en, this message translates to:
  /// **'The badge beside your name says Ohara has checked who you are. Send a document and we will look at it.'**
  String get accountVerificationBlurb;

  /// Label of the document-type field
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get accountVerificationDocType;

  /// Hint under the document-type field
  ///
  /// In en, this message translates to:
  /// **'National ID, passport, commercial register…'**
  String get accountVerificationDocTypeHint;

  /// Label of the front-of-document upload
  ///
  /// In en, this message translates to:
  /// **'Document — front'**
  String get accountVerificationFront;

  /// Label of the legal-name field
  ///
  /// In en, this message translates to:
  /// **'Name on the document'**
  String get accountVerificationLegalName;

  /// Shown when the account has not proved its number yet
  ///
  /// In en, this message translates to:
  /// **'Verify your phone number first.'**
  String get accountVerificationNeedsPhone;

  /// Label of the free-text reason field
  ///
  /// In en, this message translates to:
  /// **'Why you are asking'**
  String get accountVerificationNote;

  /// Privacy note under the document uploads
  ///
  /// In en, this message translates to:
  /// **'Your documents are read only by the staff who review them, and by nobody else on Ohara.'**
  String get accountVerificationPrivacy;

  /// Resubmits a claim that was returned or refused
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get accountVerificationResubmit;

  /// Label of the selfie upload
  ///
  /// In en, this message translates to:
  /// **'A photo of you holding it'**
  String get accountVerificationSelfie;

  /// Confirmation after submitting
  ///
  /// In en, this message translates to:
  /// **'Sent. We will tell you as soon as it is reviewed.'**
  String get accountVerificationSent;

  /// Status of an approved claim
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get accountVerificationStatusApproved;

  /// Status of a claim returned for more information
  ///
  /// In en, this message translates to:
  /// **'We need something more'**
  String get accountVerificationStatusNeedsInfo;

  /// Status of a filed verification claim
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get accountVerificationStatusPending;

  /// Status of a refused claim
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get accountVerificationStatusRejected;

  /// Status of a badge that was granted and later revoked
  ///
  /// In en, this message translates to:
  /// **'Withdrawn by Ohara'**
  String get accountVerificationStatusRevoked;

  /// Status of a claim a reviewer has opened
  ///
  /// In en, this message translates to:
  /// **'Being reviewed'**
  String get accountVerificationStatusUnderReview;

  /// Submits the verification claim
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get accountVerificationSubmit;

  /// Cancels an open verification claim
  ///
  /// In en, this message translates to:
  /// **'Withdraw the request'**
  String get accountVerificationWithdraw;

  /// Confirmation after withdrawing
  ///
  /// In en, this message translates to:
  /// **'Request withdrawn.'**
  String get accountVerificationWithdrawn;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// How many achievements are earned [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{earned} of {total}'**
  String achievementsEarned(int earned, int total);

  /// Shell action — address book
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get actionAddresses;

  /// Shell action — analytics
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get actionAnalytics;

  /// Shell action — audit logs
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get actionAudit;

  /// Shell action — cart
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get actionCart;

  /// Shell action — chats
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get actionConversations;

  /// Shell action — her salon bookings
  ///
  /// In en, this message translates to:
  /// **'My appointments'**
  String get actionAppointments;

  /// Shell action — coupons
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get actionCoupons;

  /// Shell action — the salon owner's workspace
  ///
  /// In en, this message translates to:
  /// **'My salon'**
  String get actionSalonWorkspace;

  /// Shell action — the salons directory
  ///
  /// In en, this message translates to:
  /// **'Salons & beauty'**
  String get actionSalons;

  /// No description provided for @actionDidNotSave.
  ///
  /// In en, this message translates to:
  /// **'That didn’t save — check your connection and try again'**
  String get actionDidNotSave;

  /// Shell action — finance
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get actionFinance;

  /// Shell action — moderation queue
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get actionModeration;

  /// Shell action — compose a post
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get actionNewPost;

  /// Shell action — add a product
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get actionNewProduct;

  /// Shell action — notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get actionNotifications;

  /// Shell action — orders
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get actionOrders;

  /// Shell action — payment methods
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get actionPayments;

  /// Shell action — products
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get actionProducts;

  /// Shell action — reports
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get actionReports;

  /// Shell action — returns
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get actionReturns;

  /// Shell action — rewards
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get actionRewards;

  /// Shell action — search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Shell action — security settings
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get actionSecurity;

  /// Shell action — sellers
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get actionSellers;

  /// Shell action — settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// Shell action — storefront profile
  ///
  /// In en, this message translates to:
  /// **'Store profile'**
  String get actionStoreProfile;

  /// Shell action — AI stylist
  ///
  /// In en, this message translates to:
  /// **'Stylist'**
  String get actionStylist;

  /// Shell action — trend engine
  ///
  /// In en, this message translates to:
  /// **'Trend engine'**
  String get actionTrends;

  /// Shell action — users
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get actionUsers;

  /// Shell action — seller verification
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get actionVerification;

  /// Shell action — wishlist
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get actionWishlist;

  /// Status badge
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get active;

  /// Section heading
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// Blurb on the Activity tab's messages card
  ///
  /// In en, this message translates to:
  /// **'Your conversations with boutiques, and story shares.'**
  String get activityMessagesBlurb;

  /// Blurb on the Activity tab's notifications card
  ///
  /// In en, this message translates to:
  /// **'Price drops, order updates, seller replies, and rewards.'**
  String get activityNotificationsBlurb;

  /// Blurb on the Activity tab's orders card
  ///
  /// In en, this message translates to:
  /// **'Track purchases, delivery milestones, and returns.'**
  String get activityOrdersBlurb;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Placeholder in the comment input.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get addCommentHint;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Add a coupon'**
  String get addCoupon;

  /// Story composer action
  ///
  /// In en, this message translates to:
  /// **'Add your moment'**
  String get addMoment;

  /// Story composer action
  ///
  /// In en, this message translates to:
  /// **'Add a story'**
  String get addStory;

  /// Primary product action
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// Confirmation after adding a product to the cart from the feed.
  ///
  /// In en, this message translates to:
  /// **'Added to your bag'**
  String get addedToBag;

  /// Confirmation after filing an item into a collection
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String addedToCollection(String name);

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Additional documents'**
  String get additionalDocuments;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// Admin console section reviewing verification claims
  ///
  /// In en, this message translates to:
  /// **'Account verification'**
  String get adminAccountVerifications;

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

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Active users'**
  String get adminActiveUsers;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get adminAnalytics;

  /// Subtitle of the admin analytics screen.
  ///
  /// In en, this message translates to:
  /// **'Sales, revenue, conversion, cohorts, and live operations.'**
  String get adminAnalyticsSubtitle;

  /// Metric: mean value of an order.
  ///
  /// In en, this message translates to:
  /// **'Average order value'**
  String get adminAov;

  /// Confirm button on an admin action form.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get adminApply;

  /// Admin section: the record of administrative actions.
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get adminAuditLogs;

  /// Error title when the audit feed fails.
  ///
  /// In en, this message translates to:
  /// **'Audit stream unavailable'**
  String get adminAuditUnavailable;

  /// Pending badge above the seller review queue.
  ///
  /// In en, this message translates to:
  /// **'{count} awaiting review'**
  String adminAwaitingReview(String count);

  /// Admin action
  ///
  /// In en, this message translates to:
  /// **'Back to the shop'**
  String get adminBackToShop;

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

  /// Title of the admin analytics screen.
  ///
  /// In en, this message translates to:
  /// **'Business intelligence'**
  String get adminBusinessIntelligence;

  /// Confirmation after saving a campaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign created.'**
  String get adminCampaignCreated;

  /// Validation error in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Name, title, and body are required.'**
  String get adminCampaignFieldsRequired;

  /// Field label in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Campaign name'**
  String get adminCampaignName;

  /// Confirmation after starting a campaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign queued for delivery.'**
  String get adminCampaignQueued;

  /// Heading over the ordered list of findings on the admin dashboard.
  ///
  /// In en, this message translates to:
  /// **'What needs you today'**
  String get adminBriefing;

  /// Shown when the briefing came back with no findings, so a quiet week does not look like a broken screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you today — the last read found nothing worth your time.'**
  String get adminBriefingQuiet;

  /// Shown when the briefing request fails. Advisory, so it is stated plainly rather than as an error.
  ///
  /// In en, this message translates to:
  /// **'The briefing could not be read right now.'**
  String get adminBriefingUnavailable;

  /// Admin shortcut to notification campaigns.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get adminCampaigns;

  /// Field label: where the campaign is delivered.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get adminChannels;

  /// Tooltip on the admin table's search reset.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get adminClearSearch;

  /// Admin section: commission rules and rates.
  ///
  /// In en, this message translates to:
  /// **'Commission management'**
  String get adminCommissionManagement;

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

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Conversion rate'**
  String get adminConversion;

  /// Greeting on the admin home before noon
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get adminCourtGreetingMorning;

  /// Greeting on the admin home after noon
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get adminCourtGreetingEvening;

  /// Greeting with the operator's first name
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String adminCourtGreetingNamed(String greeting, String name);

  /// Admin home state sentence when the briefing is quiet
  ///
  /// In en, this message translates to:
  /// **'The house is calm — nothing is waiting for you today.'**
  String get adminCourtStateCalm;

  /// Admin home state sentence: how many findings the briefing holds
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One thing is waiting for you today} other{{count} things are waiting for you today}}'**
  String adminCourtStateWaiting(int count);

  /// How many of today's findings are critical
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{one of them urgent} other{{count} of them urgent}}'**
  String adminCourtStateUrgent(int count);

  /// Admin home state sentence when the briefing failed
  ///
  /// In en, this message translates to:
  /// **'Today\'s briefing could not be read — the doors below still show who is waiting.'**
  String get adminCourtStateUnknown;

  /// Placeholder of the admin home's jump-to-section field
  ///
  /// In en, this message translates to:
  /// **'Where to? Type the name of any section…'**
  String get adminCourtJumpHint;

  /// Jump palette: nothing matches the query
  ///
  /// In en, this message translates to:
  /// **'No section by that name.'**
  String get adminCourtJumpEmpty;

  /// The most important finding of the day
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get adminCourtNowTitle;

  /// Opens the screen a finding points to
  ///
  /// In en, this message translates to:
  /// **'Go there'**
  String get adminCourtNowOpen;

  /// The rest of today's findings
  ///
  /// In en, this message translates to:
  /// **'After that'**
  String get adminCourtThenTitle;

  /// Finding severity
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get adminCourtSeverityCritical;

  /// Finding severity
  ///
  /// In en, this message translates to:
  /// **'Worth a look'**
  String get adminCourtSeverityWarning;

  /// Finding severity
  ///
  /// In en, this message translates to:
  /// **'Opportunity'**
  String get adminCourtSeverityOpportunity;

  /// Admin home: the month's four metrics drawn as a rose
  ///
  /// In en, this message translates to:
  /// **'The market\'s pulse'**
  String get adminCourtPulseTitle;

  /// Explains how to read the rose
  ///
  /// In en, this message translates to:
  /// **'Each petal grows with its metric\'s trend this month; a red petal is falling.'**
  String get adminCourtPulseCaption;

  /// Screen-reader label of the rose
  ///
  /// In en, this message translates to:
  /// **'A rose of this month\'s trends'**
  String get adminCourtPulseSemantics;

  /// Admin home: the queues and rooms of the console
  ///
  /// In en, this message translates to:
  /// **'The doors'**
  String get adminCourtDoorsTitle;

  /// Admin rail group: users, verification, sellers
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get adminCourtGroupPeople;

  /// Admin rail group: products, orders, delivery
  ///
  /// In en, this message translates to:
  /// **'The market'**
  String get adminCourtGroupMarket;

  /// Admin rail group: support, moderation, content, reports
  ///
  /// In en, this message translates to:
  /// **'Trust and support'**
  String get adminCourtGroupTrust;

  /// Admin rail group: finance, commissions
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get adminCourtGroupMoney;

  /// Admin rail group: analytics, trends, value
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get adminCourtGroupInsight;

  /// Admin rail group: audit, policies, settings
  ///
  /// In en, this message translates to:
  /// **'The house'**
  String get adminCourtGroupHouse;

  /// Short label of the jump button in the admin rail and bar
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get adminCourtJumpShort;

  /// Explains the lit doors
  ///
  /// In en, this message translates to:
  /// **'A lit door has someone waiting behind it.'**
  String get adminCourtDoorsCaption;

  /// Under the count on a lit door
  ///
  /// In en, this message translates to:
  /// **'waiting for you'**
  String get adminCourtDoorWaiting;

  /// A queue door with an empty queue
  ///
  /// In en, this message translates to:
  /// **'Nobody waiting'**
  String get adminCourtDoorClear;

  /// A queue door whose backlog could not be read
  ///
  /// In en, this message translates to:
  /// **'Count unavailable'**
  String get adminCourtDoorUnknown;

  /// A door to a room that keeps no queue
  ///
  /// In en, this message translates to:
  /// **'Step in'**
  String get adminCourtDoorEnter;

  /// Admin home: recent audit events as a timeline
  ///
  /// In en, this message translates to:
  /// **'The day\'s thread'**
  String get adminCourtThreadTitle;

  /// Opens the audit log
  ///
  /// In en, this message translates to:
  /// **'Full log'**
  String get adminCourtThreadAll;

  /// Chart title: the steps from view to purchase.
  ///
  /// In en, this message translates to:
  /// **'Conversion funnel'**
  String get adminConversionFunnel;

  /// Admin shortcut to the customer list.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get adminCustomers;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminDashboard;

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

  /// Admin section: ledger and payouts.
  ///
  /// In en, this message translates to:
  /// **'Financial management'**
  String get adminFinancialManagement;

  /// Admin shortcut to the finance console.
  ///
  /// In en, this message translates to:
  /// **'Financials'**
  String get adminFinancials;

  /// Metric: revenue before deductions.
  ///
  /// In en, this message translates to:
  /// **'Gross revenue'**
  String get adminGrossRevenue;

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

  /// Range chip on the admin analytics console.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last day} other{Last {count} days}}'**
  String adminLastDays(int count);

  /// Button that fetches the next page of an admin queue.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminLoadMore;

  /// Admin action
  ///
  /// In en, this message translates to:
  /// **'Manage catalogue'**
  String get adminManageCatalog;

  /// Field label in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get adminMessageBody;

  /// Admin queue: reported content.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get adminModeration;

  /// Admin section: review queues for reported content.
  ///
  /// In en, this message translates to:
  /// **'Moderation tools'**
  String get adminModerationTools;

  /// Metric: revenue after commission and fees.
  ///
  /// In en, this message translates to:
  /// **'Net revenue'**
  String get adminNetRevenue;

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

  /// Empty state in the seller review queue.
  ///
  /// In en, this message translates to:
  /// **'No applications match this filter.'**
  String get adminNoApplications;

  /// Empty state for an admin panel with no rows.
  ///
  /// In en, this message translates to:
  /// **'No data yet.'**
  String get adminNoDataYet;

  /// Empty state after filtering an admin table.
  ///
  /// In en, this message translates to:
  /// **'No matching records found.'**
  String get adminNoMatchingRecords;

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

  /// Empty state for an admin section.
  ///
  /// In en, this message translates to:
  /// **'No {section} records yet.'**
  String adminNoRecordsYet(String section);

  /// Admin section: campaign delivery and engagement.
  ///
  /// In en, this message translates to:
  /// **'Notification analytics'**
  String get adminNotificationAnalytics;

  /// Admin section: push and email campaigns.
  ///
  /// In en, this message translates to:
  /// **'Notification campaigns'**
  String get adminNotificationCampaigns;

  /// Field label in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Notification title'**
  String get adminNotificationTitle;

  /// Admin shortcut to notification analytics.
  ///
  /// In en, this message translates to:
  /// **'Notify analytics'**
  String get adminNotifyAnalytics;

  /// Live count of signed-in users.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get adminOnlineNow;

  /// Admin section: every order on the platform.
  ///
  /// In en, this message translates to:
  /// **'Order management'**
  String get adminOrderManagement;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get adminOrders;

  /// Admin screen title
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminPanel;

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

  /// Admin section: the catalogue.
  ///
  /// In en, this message translates to:
  /// **'Product management'**
  String get adminProductManagement;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get adminProducts;

  /// Heading over the admin shortcut row.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get adminQuickActions;

  /// Hint under the commission rate box.
  ///
  /// In en, this message translates to:
  /// **'250 means 2.5%'**
  String get adminRateHint;

  /// Empty state inside the console record sheet.
  ///
  /// In en, this message translates to:
  /// **'This record carries no further detail.'**
  String get adminRecordNoDetails;

  /// Summary of a nested object inside a console record.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field} other{{count} fields}}'**
  String adminRecordNestedObject(int count);

  /// Summary of a list inside a console record.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String adminRecordItemCount(int count);

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

  /// Heading over the admin audit feed.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get adminRecentActivity;

  /// Admin section
  ///
  /// In en, this message translates to:
  /// **'Recent orders'**
  String get adminRecentOrders;

  /// Metric: share of customers who order again.
  ///
  /// In en, this message translates to:
  /// **'Repeat rate'**
  String get adminRepeatRate;

  /// Confirmation after generating a report [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{format} report ready — {count, plural, =1{1 row} other{{count} rows}}'**
  String adminReportGenerated(String format, int count);

  /// Admin section: generated reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReports;

  /// Admin section: business intelligence.
  ///
  /// In en, this message translates to:
  /// **'Reports and analytics'**
  String get adminReportsAndAnalytics;

  /// Metric: share of customers retained.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get adminRetentionRate;

  /// Action that reloads the audit feed.
  ///
  /// In en, this message translates to:
  /// **'Retry from audit logs'**
  String get adminRetryFromAudit;

  /// Chart title: revenue over the selected range.
  ///
  /// In en, this message translates to:
  /// **'Revenue trend'**
  String get adminRevenueTrend;

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

  /// Placeholder listing the role values an admin can filter by.
  ///
  /// In en, this message translates to:
  /// **'USER, SELLER, ADMIN'**
  String get adminRoleFilterHint;

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

  /// Action that sends a campaign now.
  ///
  /// In en, this message translates to:
  /// **'Run campaign'**
  String get adminRunCampaign;

  /// Validation error for the campaign schedule field.
  ///
  /// In en, this message translates to:
  /// **'Use an ISO schedule time.'**
  String get adminScheduleIsoHint;

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

  /// Admin nav rail: the security section.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get adminSecurity;

  /// Validation error in the campaign composer.
  ///
  /// In en, this message translates to:
  /// **'Select at least one channel.'**
  String get adminSelectChannel;

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

  /// Admin section: seller applications and status.
  ///
  /// In en, this message translates to:
  /// **'Seller management'**
  String get adminSellerManagement;

  /// Leaderboard: best-performing sellers.
  ///
  /// In en, this message translates to:
  /// **'Seller performance'**
  String get adminSellerPerformance;

  /// Admin queue: seller applications awaiting a decision.
  ///
  /// In en, this message translates to:
  /// **'Seller review'**
  String get adminSellerReview;

  /// Tooltip on the admin app bar's settings shortcut.
  ///
  /// In en, this message translates to:
  /// **'Administrator settings'**
  String get adminSettings;

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

  /// Admin section: the customer support queue.
  ///
  /// In en, this message translates to:
  /// **'Support management'**
  String get adminSupportManagement;

  /// Admin queue: open support conversations.
  ///
  /// In en, this message translates to:
  /// **'Support queue'**
  String get adminSupportQueue;

  /// Admin section: platform configuration.
  ///
  /// In en, this message translates to:
  /// **'System settings'**
  String get adminSystemSettings;

  /// Leaderboard: best-selling products.
  ///
  /// In en, this message translates to:
  /// **'Top products'**
  String get adminTopProducts;

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get adminTotalOrders;

  /// Admin metric
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get adminTotalSales;

  /// Admin section: browse and moderate accounts.
  ///
  /// In en, this message translates to:
  /// **'User management'**
  String get adminUserManagement;

  /// Analytics ranked list: pieces sold by a product or a boutique.
  ///
  /// In en, this message translates to:
  /// **'{units, plural, =1{1 unit} other{{units} units}}'**
  String adminUnitsSold(int units);

  /// Subtitle of the notification analytics screen.
  ///
  /// In en, this message translates to:
  /// **'What went out, down which channel, and how much of it landed.'**
  String get adminNotificationAnalyticsSubtitle;

  /// Metric: in-app notifications nobody has opened.
  ///
  /// In en, this message translates to:
  /// **'Unread in app'**
  String get adminUnreadInApp;

  /// Metric: notification deliveries that left the platform.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get adminNotificationsSent;

  /// Metric: notification deliveries that did not land.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get adminNotificationsFailed;

  /// Panel title: delivery counts split by channel and status.
  ///
  /// In en, this message translates to:
  /// **'Deliveries by channel'**
  String get adminDeliveriesByChannel;

  /// Panel title: campaign counts by status.
  ///
  /// In en, this message translates to:
  /// **'Campaigns by status'**
  String get adminCampaignsByStatus;

  /// Panel title: counts of sent/opened/clicked/failed.
  ///
  /// In en, this message translates to:
  /// **'Delivery events'**
  String get adminDeliveryEvents;

  /// Notification channel.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get adminChannelPush;

  /// Notification channel.
  ///
  /// In en, this message translates to:
  /// **'In app'**
  String get adminChannelInApp;

  /// Notification channel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminChannelEmail;

  /// Notification channel.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get adminChannelSms;

  /// Notification channel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get adminChannelWhatsapp;

  /// Admin nav item
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// Verification decision
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminVerificationApprove;

  /// The console action that approves or refuses a verification claim
  ///
  /// In en, this message translates to:
  /// **'Decide'**
  String get adminVerificationDecision;

  /// Verification decision that returns the claim to her
  ///
  /// In en, this message translates to:
  /// **'Ask for more'**
  String get adminVerificationNeedsInfo;

  /// Helper text under the reason field on a verification decision
  ///
  /// In en, this message translates to:
  /// **'She is shown exactly what you write here.'**
  String get adminVerificationReasonReaches;

  /// Verification decision
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get adminVerificationReject;

  /// Verification decision that withdraws a granted badge
  ///
  /// In en, this message translates to:
  /// **'Revoke the badge'**
  String get adminVerificationRevoke;

  /// Marks a verification claim as being reviewed
  ///
  /// In en, this message translates to:
  /// **'Take it'**
  String get adminVerificationUnderReview;

  /// Filter on the seller management table.
  ///
  /// In en, this message translates to:
  /// **'Verified sellers only'**
  String get adminVerifiedSellersOnly;

  /// Admin action
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get adminViewReports;

  /// Admin greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get adminWelcome;

  /// Title of the AI stylist screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Ohara Stylist'**
  String get aiStylistTitle;

  /// Filter chip that clears the category filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Onboarding success
  ///
  /// In en, this message translates to:
  /// **'You are all set ✨'**
  String get allSet;

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
  String analyticsUnitsSold(int count);

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'App preferences'**
  String get appPreferences;

  /// Application name shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Ohara'**
  String get appTitle;

  /// About screen
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Appearance screen description
  ///
  /// In en, this message translates to:
  /// **'Choose how Ohara looks on your device. Your choice is saved automatically.'**
  String get appearanceDescription;

  /// Applies filters
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Apply coupon'**
  String get applyCoupon;

  /// Language name
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get ar;

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

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get bankName;

  /// No description provided for @beTheFirstToComment.
  ///
  /// In en, this message translates to:
  /// **'Be the first to say what you think.'**
  String get beTheFirstToComment;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Best selling'**
  String get bestSeller;

  /// Empty cart body
  ///
  /// In en, this message translates to:
  /// **'Browse the shop and add something you love.'**
  String get browseAndAdd;

  /// No description provided for @browsingWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your bag, orders and saves'**
  String get browsingWithoutAccount;

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

  /// Seller application: business licence upload.
  ///
  /// In en, this message translates to:
  /// **'Commercial register or licence'**
  String get businessLicenseDocument;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Business license URL'**
  String get businessLicenseUrl;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// Primary product action
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get buyNow;

  /// Support channel
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Order action
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// Title of the full category browse screen.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

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
  /// **'Gifts'**
  String get categoryGifts;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Flowers, chocolate and occasion boxes'**
  String get categoryGiftsBlurb;

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
  /// **'Shoes'**
  String get categoryShoes;

  /// Category blurb [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Heels, flats and sandals'**
  String get categoryShoesBlurb;

  /// Fallback heading for a category page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryTitle;

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

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

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

  /// Opens the attachment menu [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttachments;

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

  /// Shown when fetching an attachment fails.
  ///
  /// In en, this message translates to:
  /// **'The file could not be downloaded.'**
  String get chatDownloadFailed;

  /// Message text carried alongside a document attachment.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileMessage;

  /// Attachment sheet: pick a document from storage.
  ///
  /// In en, this message translates to:
  /// **'Send a file'**
  String get chatFromFiles;

  /// Peer presence with a relative time
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String chatLastSeen(String when);

  /// Shown at the top of a conversation while an older page loads.
  ///
  /// In en, this message translates to:
  /// **'Loading earlier messages'**
  String get chatLoadOlder;

  /// Under a message of hers that failed to send.
  ///
  /// In en, this message translates to:
  /// **'Not sent · tap to try again'**
  String get chatMessageNotSent;

  /// Shown under a message the server refused
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get chatMessageFailed;

  /// Thread preview when nothing has been sent
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessagesYet;

  /// Empty state for the shared-media screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been shared here yet.'**
  String get chatNoSharedMedia;

  /// Peer presence
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get chatOnlineNow;

  /// Shown when the OS has no handler for a downloaded attachment.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone can open this file.'**
  String get chatOpenFileFailed;

  /// Attaches an order to a message [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get chatOrder;

  /// Fallback text for a message that is only a photograph.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhotoMessage;

  /// Attaches a product to a message [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get chatProduct;

  /// Resends a message that failed
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chatRetrySend;

  /// Marketplace safety note above the conversation list
  ///
  /// In en, this message translates to:
  /// **'Keep payments inside Ohara'**
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

  /// Snackbar when a chat message fails to send.
  ///
  /// In en, this message translates to:
  /// **'The message could not be sent'**
  String get chatSendFailed;

  /// Under a message of hers that is still on its way.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// Delivery status of a sent message [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatSent;

  /// Button in the empty conversation state that opens the attachment sheet.
  ///
  /// In en, this message translates to:
  /// **'Send a photo'**
  String get chatShareImage;

  /// Title of the screen listing photos shared in a conversation.
  ///
  /// In en, this message translates to:
  /// **'Shared photos'**
  String get chatSharedMedia;

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

  /// Records a voice note [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get chatVoice;

  /// Placeholder of the chat composer [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get chatWriteMessage;

  /// Date divider in a conversation for messages from yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

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

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

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

  /// No description provided for @checkoutCity.
  ///
  /// In en, this message translates to:
  /// **'City or town'**
  String get checkoutCity;

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

  /// No description provided for @checkoutDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get checkoutDelivery;

  /// No description provided for @checkoutDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get checkoutDeliveryAddress;

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

  /// No description provided for @checkoutGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get checkoutGovernorate;

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

  /// No description provided for @checkoutInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get checkoutInvalidPhone;

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

  /// No description provided for @checkoutNewAddress.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get checkoutNewAddress;

  /// No description provided for @checkoutOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get checkoutOrderSummary;

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get checkoutPaymentMethod;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get checkoutPlaceOrder;

  /// No description provided for @checkoutPlacedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your order {number} is confirmed'**
  String checkoutPlacedSuccess(String number);

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

  /// No description provided for @checkoutRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get checkoutRequired;

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

  /// No description provided for @checkoutSaveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save this address for next time'**
  String get checkoutSaveAddress;

  /// No description provided for @checkoutSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Your saved addresses'**
  String get checkoutSavedAddresses;

  /// No description provided for @checkoutSplitNotice.
  ///
  /// In en, this message translates to:
  /// **'Your order is from {count} sellers and arrives in several parcels — with one delivery fee.'**
  String checkoutSplitNotice(String count);

  /// No description provided for @checkoutSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get checkoutSubtotal;

  /// Title of the checkout screen.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutTotalPending.
  ///
  /// In en, this message translates to:
  /// **'The final total is calculated when you place the order'**
  String get checkoutTotalPending;

  /// No description provided for @checkoutUseThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Deliver here'**
  String get checkoutUseThisAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Clears filters or a field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Dismisses a dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

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

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// OTP toast
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your phone.'**
  String get codeSent;

  /// OTP subtitle
  ///
  /// In en, this message translates to:
  /// **'We sent a one-time code to {phone}.'**
  String codeSentTo(String phone);

  /// Where the code went, masked
  ///
  /// In en, this message translates to:
  /// **'Code sent to {destination}'**
  String codeSentToMasked(String destination);

  /// Collection page title — discounted pieces
  ///
  /// In en, this message translates to:
  /// **'All deals'**
  String get collectionDeals;

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

  /// Wishlist section
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Shareable lists for products, sellers, and posts'**
  String get collectionsBlurb;

  /// Empty state inside the save-to-collection sheet
  ///
  /// In en, this message translates to:
  /// **'You have no collections yet — make one and it appears here.'**
  String get collectionsEmptyHint;

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

  /// Counter label
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Commercial registration'**
  String get commercialRegistration;

  /// Opens the list of competing offers
  ///
  /// In en, this message translates to:
  /// **'Compare prices'**
  String get comparePrices;

  /// Profile prompt
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeProfile;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Complete all required seller application fields.'**
  String get completeSellerFields;

  /// Confirms a destructive or elevated action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get confirmPasswordMismatch;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

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

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// Auth alternative
  ///
  /// In en, this message translates to:
  /// **'Continue as a guest'**
  String get continueAsGuest;

  /// Generic forward action
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Copies a value to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Short label for a free-shipping coupon.
  ///
  /// In en, this message translates to:
  /// **'Free ship'**
  String get couponFreeShipping;

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

  /// Q55 — «يتصل بالزبونة بضغطة».
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get courierCall;

  /// Q55 — the cash amount due at the door.
  ///
  /// In en, this message translates to:
  /// **'To collect'**
  String get courierCollect;

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

  /// Confirms the sheet's action.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get courierConfirm;

  /// Q55 — the courier's assignments for today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s round'**
  String get courierDay;

  /// Completes the delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get courierDeliver;

  /// Title of the delivery confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get courierDeliverTitle;

  /// Section title for closed parcels.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get courierDone;

  /// Empty state body on the courier round.
  ///
  /// In en, this message translates to:
  /// **'Parcels appear here as soon as they are assigned to you.'**
  String get courierEmptyBody;

  /// Empty state on the courier round.
  ///
  /// In en, this message translates to:
  /// **'Nothing assigned today'**
  String get courierEmptyTitle;

  /// Q55 — records why it failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get courierFail;

  /// Title of the failed-delivery sheet.
  ///
  /// In en, this message translates to:
  /// **'Why did it fail?'**
  String get courierFailTitle;

  /// Q55 — «يرى ملاحظات التوصيل».
  ///
  /// In en, this message translates to:
  /// **'Delivery notes'**
  String get courierInstructions;

  /// Q55 — «يشوف خريطة أو موقع».
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get courierNavigate;

  /// Section title for parcels still open.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get courierOpen;

  /// Q55 — «يؤكد استلام الطلب من البائع».
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get courierPickUp;

  /// Badge on a parcel with nothing to collect.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get courierPrepaid;

  /// Optional note on delivery.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get courierRecipientNote;

  /// Marks the parcel as on its way.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get courierStartDelivery;

  /// Confirms creating a new record.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// Placeholder of the caption field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Say something about it…'**
  String get createCaptionHint;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Create a collection'**
  String get createCollection;

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

  /// Subtitle of the create-post screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Show a piece and tell her why it is worth it.'**
  String get createPostBody;

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

  /// Title of the create-post screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get createPostTitle;

  /// Publishes a story [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Share story'**
  String get createStoryAction;

  /// Validation for a malformed story link [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'That link does not look right'**
  String get createStoryBadLink;

  /// Subtitle of the create-story screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'A frame from today, gone in twenty-four hours.'**
  String get createStoryBody;

  /// Optional link field on the create-story screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get createStoryOptionalLink;

  /// Confirmation after publishing a story [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your story is live'**
  String get createStorySuccess;

  /// Title of the create-story screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get createStoryTitle;

  /// Step one of the phone change
  ///
  /// In en, this message translates to:
  /// **'Code sent to your current number'**
  String get currentNumberCode;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// Mandatory self-declaration on the registration form (Q43/Q138 P1).
  ///
  /// In en, this message translates to:
  /// **'I declare that I am a woman and accept the Ohara terms'**
  String get declaredFemaleLabel;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

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

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// Device state
  ///
  /// In en, this message translates to:
  /// **'Never signed in from here'**
  String get deviceNotVerified;

  /// Device state
  ///
  /// In en, this message translates to:
  /// **'Verified on this device'**
  String get deviceTrusted;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Device updated.'**
  String get deviceUpdated;

  /// Security section
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

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

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// Helper line under the Ask Ohara field on Discover.
  ///
  /// In en, this message translates to:
  /// **'Describe the occasion or the feeling — “a summer wedding, something soft, under 60k”'**
  String get discoverAskHelper;

  /// Placeholder of the Ask Ohara field on Discover.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get discoverAskHint;

  /// Label above the Discover question field, which opens the stylist with her question.
  ///
  /// In en, this message translates to:
  /// **'Ask Ohara'**
  String get discoverAskLabel;

  /// Tooltip of the send button on the Discover question field.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get discoverAskSend;

  /// Button on Discover that opens the plain keyword search.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get discoverByName;

  /// Eyebrow above the Discover title.
  ///
  /// In en, this message translates to:
  /// **'By what you need, not by aisle'**
  String get discoverEyebrow;

  /// Action on a closet-gap card on Discover.
  ///
  /// In en, this message translates to:
  /// **'See options'**
  String get discoverGapCta;

  /// Eyebrow of a closet-gap card on Discover.
  ///
  /// In en, this message translates to:
  /// **'A gap in your closet'**
  String get discoverGapEyebrow;

  /// Button on Discover that opens visual search.
  ///
  /// In en, this message translates to:
  /// **'Search with a photo'**
  String get discoverPhotoSearch;

  /// Heading above suggested questions on Discover.
  ///
  /// In en, this message translates to:
  /// **'Try asking'**
  String get discoverPromptsTitle;

  /// Action on an upcoming-room card on Discover.
  ///
  /// In en, this message translates to:
  /// **'Open the room'**
  String get discoverRoomCta;

  /// How far off a dated room is, on its Discover card.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Today} =1{Tomorrow} other{In {days} days}}'**
  String discoverRoomDays(int days);

  /// Heading above trending searches on Discover, shown to guests.
  ///
  /// In en, this message translates to:
  /// **'People are searching'**
  String get discoverTrendingTitle;

  /// Subtitle of the What's waiting section on Discover.
  ///
  /// In en, this message translates to:
  /// **'From your rooms and your closet'**
  String get discoverWaitingSubtitle;

  /// Heading of the section built from her dated rooms and closet gaps.
  ///
  /// In en, this message translates to:
  /// **'What\'s waiting for you'**
  String get discoverWaitingTitle;

  /// Closes a sheet
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get earned;

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

  /// Empty-state body on the seller earnings screen.
  ///
  /// In en, this message translates to:
  /// **'Once your first order is delivered, your earnings appear here step by step.'**
  String get earningsEmptyBody;

  /// Empty-state title on the seller earnings screen.
  ///
  /// In en, this message translates to:
  /// **'No earnings yet'**
  String get earningsEmptyTitle;

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

  /// Section title for lifetime totals.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get earningsLifetime;

  /// Lifetime commission charged by the platform.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get earningsLifetimeCommission;

  /// Lifetime gross sales before commission.
  ///
  /// In en, this message translates to:
  /// **'Gross sales'**
  String get earningsLifetimeGross;

  /// Lifetime total actually paid out to the seller.
  ///
  /// In en, this message translates to:
  /// **'Paid to you'**
  String get earningsLifetimePaid;

  /// Ledger movement: a dispute was decided.
  ///
  /// In en, this message translates to:
  /// **'Dispute settled'**
  String get earningsMoveDisputeDone;

  /// Ledger movement: funds frozen when a dispute opened.
  ///
  /// In en, this message translates to:
  /// **'Frozen for a dispute'**
  String get earningsMoveFrozen;

  /// Ledger movement: anything not otherwise named.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get earningsMoveOther;

  /// Ledger movement: money was paid out.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get earningsMovePayout;

  /// Ledger movement: a refund was issued.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get earningsMoveRefund;

  /// Ledger movement: the return window closed.
  ///
  /// In en, this message translates to:
  /// **'Released from escrow'**
  String get earningsMoveReleased;

  /// Ledger movement: an earlier entry was reversed.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get earningsMoveReversal;

  /// Ledger movement: a sub-order was settled.
  ///
  /// In en, this message translates to:
  /// **'Sale settled'**
  String get earningsMoveSale;

  /// Shown when the earnings screen cannot load because the device is offline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Your earnings will update when you reconnect.'**
  String get earningsOffline;

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

  /// Section title for calculated but unpaid payouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts in progress'**
  String get earningsPendingPayouts;

  /// Section title for the seller's ledger movements.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get earningsStatement;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

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

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Support channel
  ///
  /// In en, this message translates to:
  /// **'Email us'**
  String get emailUs;

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

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyFeed;

  /// Empty search state
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String emptySearch(String query);

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

  /// Language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get en;

  /// Button that grants a permission, e.g. location.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// OTP validation
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code.'**
  String get enterVerificationCode;

  /// Generic failure
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// Delivery estimate
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Arriving within a day} other{Arriving within {count} days}}'**
  String etaDays(int count);

  /// Delivery estimate
  ///
  /// In en, this message translates to:
  /// **'Arriving today'**
  String get etaSameDay;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Customer refused'**
  String get failCustomerRefused;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get failNoAnswer;

  /// Delivery failure reason.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get failOther;

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
  /// **'Wrong address'**
  String get failWrongAddress;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

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
  /// **'Cash on delivery, or from your Ohara wallet. Never pay a boutique outside the app — an order paid outside it is not protected.'**
  String get faqPaymentAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do loyalty points work?'**
  String get faqPoints;

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

  /// Adds to favourites
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get favorite;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// Validation message on an empty required field
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// Validation message when a field is below its minimum length
  ///
  /// In en, this message translates to:
  /// **'Too short'**
  String get fieldTooShort;

  /// File size on an attachment [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String fileSizeMegabytes(String size);

  /// Label for the search filters control.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

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

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Courier cash in transit'**
  String get financeCourierInTransit;

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
  /// **'Customer wallets'**
  String get financeCustomerWallets;

  /// Label for the gap between total debits and total credits.
  ///
  /// In en, this message translates to:
  /// **'Discrepancy'**
  String get financeDiscrepancy;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Held for disputes'**
  String get financeDisputeHeld;

  /// How many reconciliation findings there are.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 finding} other{{count} findings}}'**
  String financeFindings(int count);

  /// Section title for the foreign-currency position.
  ///
  /// In en, this message translates to:
  /// **'FX position'**
  String get financeFx;

  /// Assets minus liabilities in the foreign currency.
  ///
  /// In en, this message translates to:
  /// **'Net exposure'**
  String get financeFxExposure;

  /// Shown when there is no rate to translate at.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate published yet.'**
  String get financeFxNone;

  /// Label for the exchange rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get financeFxRate;

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

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Gateway receivable'**
  String get financeGatewayReceivable;

  /// Total funds the platform holds.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get financeHeld;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Loyalty outstanding'**
  String get financeLoyaltyLiability;

  /// Empty state for the overdue disputes section.
  ///
  /// In en, this message translates to:
  /// **'No disputes are overdue.'**
  String get financeNoOverdue;

  /// Headline when debits and credits disagree — money created or destroyed.
  ///
  /// In en, this message translates to:
  /// **'Trial balance is off'**
  String get financeNotBalanced;

  /// How overdue a dispute is.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{due today} =1{1 day overdue} other{{count} days overdue}}'**
  String financeOverdueBy(int count);

  /// Section title for disputes past their decision deadline.
  ///
  /// In en, this message translates to:
  /// **'Overdue disputes'**
  String get financeOverdueDisputes;

  /// Total obligations on the platform.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get financeOwed;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Platform cash'**
  String get financePlatformCash;

  /// Section title for standing balances.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get financePositions;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Seller escrow'**
  String get financeSellerEscrow;

  /// Account label.
  ///
  /// In en, this message translates to:
  /// **'Seller payable'**
  String get financeSellerPayable;

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

  /// Label for total credits in the trial balance.
  ///
  /// In en, this message translates to:
  /// **'Total credit'**
  String get financeTotalCredit;

  /// Label for total debits in the trial balance.
  ///
  /// In en, this message translates to:
  /// **'Total debit'**
  String get financeTotalDebit;

  /// Section title for the full account listing.
  ///
  /// In en, this message translates to:
  /// **'Trial balance'**
  String get financeTrialBalance;

  /// Headline when reconciliation found something.
  ///
  /// In en, this message translates to:
  /// **'Books need review'**
  String get financeUnsound;

  /// Heading when a verified number has no account yet
  ///
  /// In en, this message translates to:
  /// **'Finish creating your account'**
  String get finishSignUp;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// Toggle description
  ///
  /// In en, this message translates to:
  /// **'Flag new devices for verification.'**
  String get flagNewDevices;

  /// How much of a flash deal is left [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left} other{{count} left}}'**
  String flashAlmostGone(int count);

  /// Scarcity line on a flash deal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left} other{{count} left}}'**
  String flashDealAlmostGone(int count);

  /// Eyebrow over the flash deals rail [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get flashLimitedTime;

  /// Follows a seller
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// Follows a boutique [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followAction;

  /// Language option. The previous Arabic was ungrammatical.
  ///
  /// In en, this message translates to:
  /// **'Follow the device language'**
  String get followDeviceLanguage;

  /// Follow list - empty followers
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get followListEmptyFollowers;

  /// Follow list - empty following
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get followListEmptyFollowing;

  /// Profile stat
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// Already following a seller
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// Shown when already following [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingState;

  /// Link
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgetPassword;

  /// Whether the listing accepts returns
  ///
  /// In en, this message translates to:
  /// **'Accept returns'**
  String get formAcceptsReturns;

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

  /// Product form field: which department the piece belongs to.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get formCategory;

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

  /// Validation on the product category field.
  ///
  /// In en, this message translates to:
  /// **'A category is required'**
  String get formCategoryRequired;

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

  /// Title of the product form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get formEditProduct;

  /// Product form toggle: pin the piece to the top of the shop.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get formFeatured;

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

  /// Title of the product form when creating.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get formNewProduct;

  /// Shown when the assistant returns no tags.
  ///
  /// In en, this message translates to:
  /// **'No tags suggested'**
  String get formNoTags;

  /// Marks an optional field
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get formOptional;

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

  /// Product form section heading
  ///
  /// In en, this message translates to:
  /// **'Price and stock'**
  String get formPricingSection;

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

  /// Primary button that creates the listing.
  ///
  /// In en, this message translates to:
  /// **'Publish product'**
  String get formPublishProduct;

  /// Explains why the canonical fields are read-only
  ///
  /// In en, this message translates to:
  /// **'Other sellers list this product, so its page is shared. You can still change your price, stock and terms.'**
  String get formSharedProductLocked;

  /// Product form toggle: let the piece appear in the social feed.
  ///
  /// In en, this message translates to:
  /// **'Show in feed'**
  String get formShowInFeed;

  /// Stock keeping unit field
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get formSku;

  /// Product form field: draft, live or archived.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get formStatus;

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

  /// Product form field: the listing name.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get formTitle;

  /// Shown when the assistant is invoked before the form has enough to work with.
  ///
  /// In en, this message translates to:
  /// **'Add a title and a category first'**
  String get formTitleCategoryFirst;

  /// Validation on the product title field.
  ///
  /// In en, this message translates to:
  /// **'A title is required'**
  String get formTitleRequired;

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

  /// Referral stat
  ///
  /// In en, this message translates to:
  /// **'Friends invited'**
  String get friendsInvited;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameRequired;

  /// Full-screen gallery — close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get galleryClose;

  /// Product gallery — full screen action
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get galleryOpenPhoto;

  /// Product gallery — position announcement
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {count}'**
  String galleryPhotoPosition(int index, int count);

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Generate new codes'**
  String get generateRecoveryCodes;

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

  /// Home greeting before noon
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// Seller application: identity document upload.
  ///
  /// In en, this message translates to:
  /// **'Photo of your ID'**
  String get governmentIdDocument;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Government ID URL'**
  String get governmentIdUrl;

  /// Home greeting, evening — plain
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEveningKhair;

  /// Home greeting, evening — light
  ///
  /// In en, this message translates to:
  /// **'Evening light'**
  String get greetingEveningNour;

  /// Home greeting, evening — roses
  ///
  /// In en, this message translates to:
  /// **'A rosy evening'**
  String get greetingEveningWard;

  /// Home greeting, evening — jasmine
  ///
  /// In en, this message translates to:
  /// **'Jasmine evening'**
  String get greetingEveningYasmine;

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

  /// Home greeting, early hours — bright
  ///
  /// In en, this message translates to:
  /// **'Rise and shine'**
  String get greetingMorningFull;

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

  /// Home greeting, late night — plain
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get greetingNightFull;

  /// Home greeting, late night — warm
  ///
  /// In en, this message translates to:
  /// **'A lovely night'**
  String get greetingNightSahra;

  /// Explains what signing in adds, shown to a guest [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sign in to save pieces, follow boutiques and track your orders.'**
  String get guestBrowseBlurb;

  /// Guest prompt
  ///
  /// In en, this message translates to:
  /// **'Your cart is safe. Sign in to place orders, save addresses, and track delivery.'**
  String get guestCartSafe;

  /// Guest screen title
  ///
  /// In en, this message translates to:
  /// **'Your guest profile'**
  String get guestProfile;

  /// No description provided for @guestShopper.
  ///
  /// In en, this message translates to:
  /// **'Browsing as a guest'**
  String get guestShopper;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Help and FAQ'**
  String get helpAndFaq;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Help centre'**
  String get helpCenter;

  /// Tooltip on the eye that hides a password again
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Menu entry that opens the archive picker for an existing highlight
  ///
  /// In en, this message translates to:
  /// **'Add stories'**
  String get highlightAddStories;

  /// Empty state of the story archive picker
  ///
  /// In en, this message translates to:
  /// **'You have not published a story yet. Publish one and it will be waiting here.'**
  String get highlightArchiveEmpty;

  /// Title of the sheet that creates a highlight
  ///
  /// In en, this message translates to:
  /// **'New highlight'**
  String get highlightCreate;

  /// Menu entry that removes a highlight
  ///
  /// In en, this message translates to:
  /// **'Delete highlight'**
  String get highlightDelete;

  /// Confirmation before deleting a highlight
  ///
  /// In en, this message translates to:
  /// **'Delete «{name}»? The stories themselves stay where they are.'**
  String highlightDeleteConfirm(String name);

  /// Shown when an empty highlight is tapped
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get highlightEmptyOpen;

  /// Shown on her own empty highlights rail
  ///
  /// In en, this message translates to:
  /// **'Keep a story past its day — a size guide, a look, a delivery.'**
  String get highlightEmptyOwner;

  /// Hint under the highlight name field
  ///
  /// In en, this message translates to:
  /// **'Sizes, looks, deliveries…'**
  String get highlightNameHint;

  /// Label of the field naming a highlight
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get highlightNameLabel;

  /// The button that starts a new highlight, on the rail
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get highlightNew;

  /// Heading over the archive picker
  ///
  /// In en, this message translates to:
  /// **'Choose stories'**
  String get highlightPickStories;

  /// Menu entry on a highlight she owns
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get highlightRename;

  /// How many stories are selected in the picker
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing chosen} =1{1 chosen} other{{count} chosen}}'**
  String highlightSelected(int count);

  /// How many stories a highlight holds
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 story} other{{count} stories}}'**
  String highlightStoriesCount(int count);

  /// The rail of saved story collections on a profile
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Eyebrow above the best-sellers rail.
  ///
  /// In en, this message translates to:
  /// **'Loved by many'**
  String get homeBestSellersEyebrow;

  /// Title of the home rail carrying today's story frames from shops she follows.
  ///
  /// In en, this message translates to:
  /// **'Boutique stories'**
  String get homeBoutiqueStories;

  /// Eyebrow above the category showcase.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get homeCategoriesEyebrow;

  /// Title of the continue-shopping rail.
  ///
  /// In en, this message translates to:
  /// **'Continue shopping'**
  String get homeContinueShopping;

  /// Eyebrow above the continue-shopping rail.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get homeContinueShoppingEyebrow;

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

  /// Eyebrow above the featured boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get homeFeaturedEyebrow;

  /// Title of the featured boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Featured boutiques'**
  String get homeFeaturedStores;

  /// Eyebrow above the featured boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Handpicked sellers'**
  String get homeFeaturedStoresEyebrow;

  /// Empty-state body for the social feed on home.
  ///
  /// In en, this message translates to:
  /// **'Follow boutiques you love to fill your feed with beautiful finds.'**
  String get homeFeedEmptyBody;

  /// Empty-state title for the social feed on home.
  ///
  /// In en, this message translates to:
  /// **'Your feed is warming up'**
  String get homeFeedEmptyTitle;

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

  /// Title of the flash-deals section.
  ///
  /// In en, this message translates to:
  /// **'Flash deals'**
  String get homeFlashDeals;

  /// Eyebrow above the flash-deals section.
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get homeFlashDealsEyebrow;

  /// Home greeting for a shopper who is not signed in.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeGreetingGuest;

  /// Home greeting addressed to a signed-in shopper, by first name.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}'**
  String homeGreetingNamed(String name);

  /// Home greeting supporting line.
  ///
  /// In en, this message translates to:
  /// **'A curated edit of fashion, beauty and gifts — chosen for you.'**
  String get homeGreetingSubtitle;

  /// Subtitle of the loyalty card on home.
  ///
  /// In en, this message translates to:
  /// **'Earn rewards on every purchase ✨'**
  String get homeLoyaltySubtitle;

  /// Title of the loyalty card on home.
  ///
  /// In en, this message translates to:
  /// **'Ohara Rewards'**
  String get homeLoyaltyTitle;

  /// Eyebrow above the nearby boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get homeNearbyEyebrow;

  /// Nearby boutiques — badge for a shop elsewhere in the governorate
  ///
  /// In en, this message translates to:
  /// **'In your governorate'**
  String get homeNearbyInGovernorate;

  /// Nearby boutiques — badge for a shop in the same city
  ///
  /// In en, this message translates to:
  /// **'In your city'**
  String get homeNearbyInYourCity;

  /// Title of the nearby boutiques section.
  ///
  /// In en, this message translates to:
  /// **'Boutiques nearby'**
  String get homeNearbyStores;

  /// Nearby boutiques — section subtitle
  ///
  /// In en, this message translates to:
  /// **'Boutiques shipping from your governorate — they arrive sooner'**
  String get homeNearbySubtitle;

  /// Eyebrow above the new-arrivals rail.
  ///
  /// In en, this message translates to:
  /// **'Just in'**
  String get homeNewArrivalsEyebrow;

  /// Title of the recently-viewed rail.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get homeRecentlyViewed;

  /// Eyebrow above the recently-viewed rail.
  ///
  /// In en, this message translates to:
  /// **'Jump back in'**
  String get homeRecentlyViewedEyebrow;

  /// Eyebrow above the recommended products rail.
  ///
  /// In en, this message translates to:
  /// **'Picked for you'**
  String get homeRecommendedEyebrow;

  /// Placeholder text in the home search bar.
  ///
  /// In en, this message translates to:
  /// **'Search dresses, perfume, gifts…'**
  String get homeSearchHint;

  /// Showcase shape: the two-column catalogue.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get homeShapeGrid;

  /// Showcase shape: an editorial collage of tiles.
  ///
  /// In en, this message translates to:
  /// **'Mosaic'**
  String get homeShapeMosaic;

  /// Showcase shape: products presented as social posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get homeShapePosts;

  /// Title of the category showcase.
  ///
  /// In en, this message translates to:
  /// **'Shop by category'**
  String get homeShopByCategory;

  /// Eyebrow above the home showcase, the section that presents products as posts.
  ///
  /// In en, this message translates to:
  /// **'Straight from the boutiques'**
  String get homeShowcaseEyebrow;

  /// One line of copy under the showcase title.
  ///
  /// In en, this message translates to:
  /// **'The newest pieces, told as stories — swipe, love, shop.'**
  String get homeShowcaseSubtitle;

  /// Title of the home showcase section.
  ///
  /// In en, this message translates to:
  /// **'New in'**
  String get homeShowcaseTitle;

  /// Eyebrow above the stories rail.
  ///
  /// In en, this message translates to:
  /// **'Fresh today'**
  String get homeStoriesEyebrow;

  /// The news half of the one-line home greeting: how many boutiques have a live story.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One boutique posted a story today} other{{count} boutiques posted stories today}}'**
  String homeStoriesToday(int count);

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

  /// Interest chip on the home greeting.
  ///
  /// In en, this message translates to:
  /// **'New drops'**
  String get homeTasteNewDrops;

  /// Title of the wishlist highlights rail.
  ///
  /// In en, this message translates to:
  /// **'From your wishlist'**
  String get homeWishlist;

  /// Eyebrow above the wishlist highlights rail.
  ///
  /// In en, this message translates to:
  /// **'You loved these'**
  String get homeWishlistEyebrow;

  /// Label under the shopper's own story ring.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get homeYourStory;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// Availability badge
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'This coupon is not valid'**
  String get invalidCoupon;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Invite code {code} copied — share it!'**
  String inviteCodeCopied(String code);

  /// Referral title
  ///
  /// In en, this message translates to:
  /// **'Invite friends, earn rewards'**
  String get inviteFriends;

  /// Title of a single invoice document.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// Label above the recipient block.
  ///
  /// In en, this message translates to:
  /// **'Billed to'**
  String get invoiceBilledTo;

  /// Seller copy only — what the platform took (Q50).
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get invoiceCommission;

  /// Label for the coupon code used.
  ///
  /// In en, this message translates to:
  /// **'Coupon'**
  String get invoiceCoupon;

  /// Q51 — the customer's copy, covering the whole basket.
  ///
  /// In en, this message translates to:
  /// **'Order invoice'**
  String get invoiceCustomerCopy;

  /// Label for the discount total.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get invoiceDiscount;

  /// Q39 — an order that can still change is not invoiced yet.
  ///
  /// In en, this message translates to:
  /// **'Your invoice is issued once the order ships.'**
  String get invoiceEmptyBody;

  /// Empty state on the invoices list.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get invoiceEmptyTitle;

  /// Label for the issue date.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get invoiceIssuedAt;

  /// Section title above the invoice lines.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get invoiceItems;

  /// Q55 P1 — the client stated no fiscal requirement, so the document says so.
  ///
  /// In en, this message translates to:
  /// **'This is a commercial invoice, not a tax invoice.'**
  String get invoiceNoTax;

  /// Label for the invoice number.
  ///
  /// In en, this message translates to:
  /// **'Invoice no.'**
  String get invoiceNumber;

  /// Label for the order number.
  ///
  /// In en, this message translates to:
  /// **'Order no.'**
  String get invoiceOrderNumber;

  /// Column header for the quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get invoiceQuantity;

  /// Q51 — one seller's copy for their own parcel.
  ///
  /// In en, this message translates to:
  /// **'Seller invoice'**
  String get invoiceSellerCopy;

  /// Seller copy only — what is left after commission.
  ///
  /// In en, this message translates to:
  /// **'Seller net'**
  String get invoiceSellerNet;

  /// Label for the shipping total.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get invoiceShipping;

  /// Label for the items subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get invoiceSubtotal;

  /// Label for the grand total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceTotal;

  /// Title of the invoices list.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// Item count on an order card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// Champagne ribbon on a post published in the last few days.
  ///
  /// In en, this message translates to:
  /// **'Just in'**
  String get justIn;

  /// Timestamp for something that happened seconds ago.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Empty cart action
  ///
  /// In en, this message translates to:
  /// **'Keep browsing'**
  String get keepBrowsing;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetime;

  /// Counter label
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// Badge on a time-limited promotion.
  ///
  /// In en, this message translates to:
  /// **'Limited time'**
  String get limitedTime;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// Security section
  ///
  /// In en, this message translates to:
  /// **'Linked accounts'**
  String get linkedAccounts;

  /// Support channel
  ///
  /// In en, this message translates to:
  /// **'Live chat'**
  String get liveChat;

  /// Reward state
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Log out everywhere'**
  String get logOutAll;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// Subtitle under the login heading
  ///
  /// In en, this message translates to:
  /// **'Sign in to shop, share and shine'**
  String get loginSubtitle;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// Sets the expectation before she opens a recovery case
  ///
  /// In en, this message translates to:
  /// **'If your number is gone for good, we can review your account by hand. It takes several days on purpose.'**
  String get lostSimExplainer;

  /// Entry point to support-mediated recovery
  ///
  /// In en, this message translates to:
  /// **'Lost your SIM?'**
  String get lostYourSim;

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

  /// Confirmation after a successful points conversion.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point added to your balance ✨} other{{count} points added to your balance ✨}}'**
  String loyaltyConverted(int count);

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

  /// Loyalty tier line on the profile [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{tier} member'**
  String loyaltyTierMember(String tier);

  /// Section description
  ///
  /// In en, this message translates to:
  /// **'Manage sessions, devices, recovery, and checkout details.'**
  String get manageSecurityBlurb;

  /// Anti-relay guidance beside the match code
  ///
  /// In en, this message translates to:
  /// **'Check that the message shows the same two digits. Ohara will never ask you to read a code aloud.'**
  String get matchCodeHint;

  /// The two digits she compares against the message
  ///
  /// In en, this message translates to:
  /// **'Match code'**
  String get matchCodeLabel;

  /// Badge on the first photo in a product gallery.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get mediaCoverBadge;

  /// Caption on a tile standing in for a document already uploaded.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get mediaDocumentAttached;

  /// Helper under a document picker that also accepts PDFs.
  ///
  /// In en, this message translates to:
  /// **'A clear photograph, or the original PDF.'**
  String get mediaDocumentsHint;

  /// Media picker: open the camera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get mediaFromCamera;

  /// Media picker: open the device file browser (documents).
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get mediaFromFiles;

  /// Media picker: open the photo library.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get mediaFromGallery;

  /// Helper text under a product gallery field.
  ///
  /// In en, this message translates to:
  /// **'The first photo is the cover. Up to {count} photos.'**
  String mediaGalleryHint(int count);

  /// Picks a photo [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get mediaImage;

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

  /// Accessibility label for the delete control on a thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get mediaRemovePhoto;

  /// Title of the sheet offering camera or gallery.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get mediaSourceTitle;

  /// Label above the story composer's media field.
  ///
  /// In en, this message translates to:
  /// **'Story image'**
  String get mediaStoryLabel;

  /// Shown when the story composer is submitted with no media.
  ///
  /// In en, this message translates to:
  /// **'Choose an image for the story first.'**
  String get mediaStoryRequired;

  /// Shown when a picked file exceeds the size ceiling before any upload starts.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than {size} MB.'**
  String mediaTooLarge(String size);

  /// Shown over a thumbnail whose upload did not complete.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get mediaUploadFailed;

  /// Shown over a thumbnail while its bytes are in flight.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get mediaUploading;

  /// Picks a video [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaVideo;

  /// Shown when a form is submitted while an upload is still running.
  ///
  /// In en, this message translates to:
  /// **'Wait for the photos to finish uploading.'**
  String get mediaWaitForUploads;

  /// Menu group — account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get menuGroupAccount;

  /// Menu group — control
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get menuGroupControl;

  /// Menu group — governance
  ///
  /// In en, this message translates to:
  /// **'Governance'**
  String get menuGroupGovernance;

  /// Menu group — growth
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get menuGroupGrowth;

  /// Menu group — seller operations
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get menuGroupOperations;

  /// Menu group — rewards
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get menuGroupRewards;

  /// Menu group — risk
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get menuGroupRisk;

  /// Menu group — shopping
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get menuGroupShopping;

  /// Menu group — store
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get menuGroupStore;

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

  /// Tooltip on the seller header's chat shortcut.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// Stories rail title
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get moments;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'My cart'**
  String get myCart;

  /// Seller screen title
  ///
  /// In en, this message translates to:
  /// **'My earnings'**
  String get myEarnings;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// Seller screen title
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get myProducts;

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

  /// Bottom navigation — activity tab
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// Bottom navigation — cart tab
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// Bottom navigation — the buyer's closet tab (what she owns, is deciding on, and wants)
  ///
  /// In en, this message translates to:
  /// **'Closet'**
  String get navCloset;

  /// Bottom navigation — the buyer's discovery tab, opening on search
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// Bottom navigation — buyer home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation — the buyer's own profile tab
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navProfile;

  /// Bottom navigation — search tab
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Seller navigation — analytics
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navSellerAnalytics;

  /// Seller navigation — dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navSellerDashboard;

  /// Seller navigation — orders
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navSellerOrders;

  /// Seller navigation — products
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navSellerProducts;

  /// Seller navigation — store profile
  ///
  /// In en, this message translates to:
  /// **'My store'**
  String get navSellerStore;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'New arrivals'**
  String get newArrivals;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// Label of the field naming a new wishlist collection
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get newCollectionName;

  /// Shown when a correct password lands on an unenrolled handset
  ///
  /// In en, this message translates to:
  /// **'This device is new. We sent a code to your number to finish signing in.'**
  String get newDeviceCodeSent;

  /// The 24-hour SIM-swap delay, explained
  ///
  /// In en, this message translates to:
  /// **'This device is new. Sensitive changes unlock {date}.'**
  String newDeviceCooldown(String date);

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

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Profile completion hint
  ///
  /// In en, this message translates to:
  /// **'Next: {step}'**
  String nextStep(String step);

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No active sessions.'**
  String get noActiveSessions;

  /// The option that leaves a saved item filed under nothing
  ///
  /// In en, this message translates to:
  /// **'No collection'**
  String get noCollection;

  /// Explains what happens when no collection is chosen
  ///
  /// In en, this message translates to:
  /// **'Stays in your saved items.'**
  String get noCollectionBlurb;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noCommentsYet;

  /// Network error state
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noConnection;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No devices yet.'**
  String get noDevicesYet;

  /// Empty state for a collection with no products [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No pieces here yet'**
  String get noProductsFound;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No saved items yet'**
  String get noSavedItems;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'No verification submitted'**
  String get noVerificationSubmitted;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

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

  /// No description provided for @notifModeration.
  ///
  /// In en, this message translates to:
  /// **'Review outcomes'**
  String get notifModeration;

  /// No description provided for @notifModerationBlurb.
  ///
  /// In en, this message translates to:
  /// **'When a review decision on your content is reversed.'**
  String get notifModerationBlurb;

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

  /// No description provided for @notifPushBlocked.
  ///
  /// In en, this message translates to:
  /// **'Your phone is blocking Ohara\'s notifications.'**
  String get notifPushBlocked;

  /// No description provided for @notifPushBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone is blocking Ohara, so nothing below will reach you until you allow it in the system settings.'**
  String get notifPushBlockedBody;

  /// No description provided for @notifPushBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off'**
  String get notifPushBlockedTitle;

  /// No description provided for @notifPushOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get notifPushOpenSettings;

  /// No description provided for @notifPushUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are not available in this version.'**
  String get notifPushUnavailable;

  /// No description provided for @notifRooms.
  ///
  /// In en, this message translates to:
  /// **'Shopping rooms'**
  String get notifRooms;

  /// No description provided for @notifRoomsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Suggestions, votes and decisions in rooms you are in.'**
  String get notifRoomsBlurb;

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

  /// No description provided for @notifSocial.
  ///
  /// In en, this message translates to:
  /// **'Likes and comments'**
  String get notifSocial;

  /// No description provided for @notifSocialBlurb.
  ///
  /// In en, this message translates to:
  /// **'When someone likes, comments on or reshares your post.'**
  String get notifSocialBlurb;

  /// Confirmation after marking every notification read
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get notificationAllRead;

  /// Empty state body for the notification inbox
  ///
  /// In en, this message translates to:
  /// **'Order updates, seller replies and offers will appear here.'**
  String get notificationInboxEmptyBody;

  /// Empty state title for the notification inbox
  ///
  /// In en, this message translates to:
  /// **'Nothing new yet'**
  String get notificationInboxEmptyTitle;

  /// Error title when the notification inbox fails to load
  ///
  /// In en, this message translates to:
  /// **'Notifications could not load'**
  String get notificationInboxLoadFailed;

  /// Title of the customer's notification inbox
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationInboxTitle;

  /// Action that marks every notification as read
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationMarkAllRead;

  /// Title of the notification preferences screen
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationPreferencesTitle;

  /// No description provided for @notificationPrefsSaved.
  ///
  /// In en, this message translates to:
  /// **'Your notification preferences are saved'**
  String get notificationPrefsSaved;

  /// How many notifications are unread
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread} other{{count} unread}}'**
  String notificationUnreadCount(int count);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

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

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Your number was changed'**
  String get numberChanged;

  /// Confirmation chip on the signup form
  ///
  /// In en, this message translates to:
  /// **'Number verified'**
  String get numberVerified;

  /// Offline banner [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'You are offline — showing what was saved'**
  String get offlineShowingSaved;

  /// Advances to the next onboarding slide [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardContinue;

  /// Onboarding slide body about sharing [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Save pieces, write reviews and send your favourites to your friends.'**
  String get onboardShareBody;

  /// Onboarding slide title about sharing [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Share what you find'**
  String get onboardShareTitle;

  /// Onboarding slide body about shopping [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Dresses, beauty and gifts from Syrian boutiques, all in one place.'**
  String get onboardShopBody;

  /// Onboarding slide title about shopping [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'A boutique in your pocket'**
  String get onboardShopTitle;

  /// Skips the onboarding tour [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardSkip;

  /// Finishes onboarding [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get onboardStart;

  /// Onboarding slide body about stories [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Follow the shops you love and catch their stories the moment they post.'**
  String get onboardStoriesBody;

  /// Onboarding slide title about stories [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'See what is new today'**
  String get onboardStoriesTitle;

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

  /// Title of the cancel-order dialog [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get orderCancelTitle;

  /// Seller order pipeline: cancelled before delivery.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderCancelled;

  /// Seller order pipeline: handed to the customer.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderDelivered;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetails;

  /// Seller order pipeline: orders just placed.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get orderNew;

  /// Shown when an order cannot be loaded [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'This order could not be found'**
  String get orderNotFound;

  /// Order detail - privacy mask applied
  ///
  /// In en, this message translates to:
  /// **'Your name is hidden from the boutique'**
  String get orderPrivacyMaskOn;

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

  /// Seller order pipeline: sent back after delivery.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get orderReturned;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Order status'**
  String get orderStatus;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get orderSummary;

  /// Fallback title of an order page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderTitle;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// Orders list - empty state for a filter
  ///
  /// In en, this message translates to:
  /// **'Nothing in this pile'**
  String get ordersEmptyForFilter;

  /// Orders list - filter chip for every order
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ordersFilterAll;

  /// Post-change notice
  ///
  /// In en, this message translates to:
  /// **'All other sessions were ended'**
  String get otherSessionsEnded;

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

  /// Availability badge
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Owner legal name'**
  String get ownerLegalName;

  /// Section title on a split order
  ///
  /// In en, this message translates to:
  /// **'Parcels'**
  String get parcels;

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// Password toggle state
  ///
  /// In en, this message translates to:
  /// **'Off — you sign in with a code'**
  String get passwordDisabled;

  /// Password toggle state
  ///
  /// In en, this message translates to:
  /// **'On — usable on known devices only'**
  String get passwordEnabled;

  /// Password strength
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordGood;

  /// Password length rule
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String passwordMinLength(int count);

  /// Explains why the password path can fall through to a code
  ///
  /// In en, this message translates to:
  /// **'A password only works on a device you have signed in from before.'**
  String get passwordOnlyOnKnownDevice;

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

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Toggle row for the optional password credential
  ///
  /// In en, this message translates to:
  /// **'Password sign-in'**
  String get passwordSignIn;

  /// Password meter caption
  ///
  /// In en, this message translates to:
  /// **'Password strength: {label}'**
  String passwordStrengthLabel(String label);

  /// Password policy hint
  ///
  /// In en, this message translates to:
  /// **'Use upper and lower case letters, a number, and a symbol.'**
  String get passwordStrengthRule;

  /// Password strength
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrong;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please sign in again.'**
  String get passwordUpdatedSignInAgain;

  /// Password strength
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordWeak;

  /// Order payment - panel title
  ///
  /// In en, this message translates to:
  /// **'Finish paying'**
  String get paymentActionTitle;

  /// Order payment - verify action
  ///
  /// In en, this message translates to:
  /// **'Check the payment'**
  String get paymentCheckAgain;

  /// Order payment - verify succeeded
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get paymentConfirmed;

  /// Order payment - launch failed
  ///
  /// In en, this message translates to:
  /// **'Could not open the payment page'**
  String get paymentCouldNotOpen;

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

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethods;

  /// Order payment - open the gateway
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get paymentOpenGateway;

  /// Order payment - reference field
  ///
  /// In en, this message translates to:
  /// **'Transfer reference'**
  String get paymentReferenceLabel;

  /// Order payment - stored reference
  ///
  /// In en, this message translates to:
  /// **'Reference on file'**
  String get paymentReferenceOnFile;

  /// Order payment - empty reference
  ///
  /// In en, this message translates to:
  /// **'Enter the reference first'**
  String get paymentReferenceRequired;

  /// Order payment - reference stored
  ///
  /// In en, this message translates to:
  /// **'Reference received — we will confirm once it is matched'**
  String get paymentReferenceSaved;

  /// Order payment - submit reference
  ///
  /// In en, this message translates to:
  /// **'Send reference'**
  String get paymentReferenceSubmit;

  /// Order payment - verify returned pending
  ///
  /// In en, this message translates to:
  /// **'The payment has not reached us yet'**
  String get paymentStillPending;

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
  /// **'{count, plural, =1{From 1 order} other{From {count} orders}}'**
  String payoutFromOrders(int count);

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

  /// Post-change safety notice
  ///
  /// In en, this message translates to:
  /// **'Payouts are on hold until {date}'**
  String payoutsFrozenUntil(String date);

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get periodDaily;

  /// Revenue period selector.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

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

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// Revenue period selector.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// Chart granularity selector.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get periodYearly;

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

  /// Form field label
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// OTP toast
  ///
  /// In en, this message translates to:
  /// **'Phone number verified.'**
  String get phoneVerified;

  /// Caption on a category tile. {count} is already formatted, e.g. 1.2k.
  ///
  /// In en, this message translates to:
  /// **'{count} pieces'**
  String piecesCount(String count);

  /// Checkout primary action
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// Counter label
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get pointsEarned;

  /// Publish button
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// Second line of the closet strip under a feed post: saved looks the tagged piece would complete.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and finishes a saved look} other{and finishes {count} saved looks}}'**
  String postClosetCompletes(int count);

  /// Button on the closet strip under a feed post that opens her closet.
  ///
  /// In en, this message translates to:
  /// **'My closet'**
  String get postClosetOpen;

  /// Closet strip under a feed post when the tagged piece duplicates something she owns.
  ///
  /// In en, this message translates to:
  /// **'You already own one like it'**
  String get postClosetOwned;

  /// Closet strip under a feed post: how many of her own pieces the tagged product pairs with.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Goes with a piece in your closet} other{Goes with {count} pieces in your closet}}'**
  String postClosetPairs(int count);

  /// Like tally under a post. {count} is already formatted, e.g. 1.2K.
  ///
  /// In en, this message translates to:
  /// **'{count} loves'**
  String postLikesCount(String count);

  /// Tooltip for the overflow menu on a post card.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get postOptions;

  /// Tap target that expands a truncated post caption.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get postMore;

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

  /// Link opening the comment sheet. {count} is already formatted.
  ///
  /// In en, this message translates to:
  /// **'View all {count} comments'**
  String postViewComments(String count);

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Section label
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Price drops and restocks stay on your radar'**
  String get priceDropsBlurb;

  /// Lowest offer on a product card
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String priceFrom(String price);

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

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Product categories'**
  String get productCategories;

  /// Example product categories, comma separated.
  ///
  /// In en, this message translates to:
  /// **'Fashion, perfume, handmade'**
  String get productCategoriesHint;

  /// Under the size row: how often the selected size was kept. Percent is a whole number.
  ///
  /// In en, this message translates to:
  /// **'{size}: kept by {percent}% of the women who received this size'**
  String productFitKept(String size, int percent);

  /// Under the size row, when the selected size is often returned for fit.
  ///
  /// In en, this message translates to:
  /// **'{size}: often sent back for the size — only {percent}% kept it'**
  String productFitOftenReturned(String size, int percent);

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

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get productDetails;

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

  /// Rating and review count under a product title [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count, plural, =1{1 review} other{{count} reviews}}'**
  String productRatingSummary(String rating, int count);

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

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Bio field on the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// Validation message for an over-long bio [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'That is a little long'**
  String get profileBioTooLong;

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

  /// Edit profile - email validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get profileEmailInvalid;

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

  /// Name field on the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullName;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Profile identity'**
  String get profileIdentity;

  /// Error when a profile fails to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'This profile could not load'**
  String get profileLoadFailed;

  /// Location field on the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileLocation;

  /// Profile praise
  ///
  /// In en, this message translates to:
  /// **'Your profile looks beautiful.'**
  String get profileLooksBeautiful;

  /// Opens the seller store management [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Manage store'**
  String get profileManageStore;

  /// Validation message for a name that is too short [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get profileNameTooShort;

  /// Post count label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profilePosts;

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

  /// Submits the edit-profile form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSaveChanges;

  /// Fallback title of a profile page [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Confirmation after saving the profile [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your profile is saved'**
  String get profileUpdated;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// Onboarding subtitle
  ///
  /// In en, this message translates to:
  /// **'A few quick steps to a richer experience.'**
  String get quickSteps;

  /// Label above the shopper's recent searches.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// Profile rail
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get recentlyViewed;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Picked for you'**
  String get recommended;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'The request was stopped'**
  String get recoveryCaseCancelled;

  /// Cool-off warning
  ///
  /// In en, this message translates to:
  /// **'Your account moves on {date} unless you stop it.'**
  String recoveryCaseCoolOff(String date);

  /// Banner shown to the owner while a case is open
  ///
  /// In en, this message translates to:
  /// **'Someone asked to move your account to another number.'**
  String get recoveryCaseOpenWarning;

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

  /// Shown above a freshly generated set
  ///
  /// In en, this message translates to:
  /// **'Write these down now. They are shown once, and generating a new set cancels the old one.'**
  String get recoveryCodesWarning;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'A number we can reach you on now'**
  String get recoveryContactNumber;

  /// Evidence question
  ///
  /// In en, this message translates to:
  /// **'What is one of your devices called?'**
  String get recoveryDeviceLabel;

  /// About the claim secret
  ///
  /// In en, this message translates to:
  /// **'Keep this reference. It is the only way to check on your request.'**
  String get recoveryKeepSecret;

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

  /// The platform-held-data-only promise, stated to her
  ///
  /// In en, this message translates to:
  /// **'We will never ask for a photo of you or of an identity document.'**
  String get recoveryNoDocuments;

  /// Hint above the evidence questions
  ///
  /// In en, this message translates to:
  /// **'Answer what you can. Nothing here is required.'**
  String get recoveryQuestionsHint;

  /// Heading above the evidence questions
  ///
  /// In en, this message translates to:
  /// **'What do you remember?'**
  String get recoveryQuestionsTitle;

  /// Evidence question
  ///
  /// In en, this message translates to:
  /// **'Roughly when did you join? (YYYY-MM)'**
  String get recoveryRegistrationMonth;

  /// Confirmation heading
  ///
  /// In en, this message translates to:
  /// **'We received your request'**
  String get recoverySubmitted;

  /// Button that spends loyalty points.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// Rewards stat
  ///
  /// In en, this message translates to:
  /// **'Redeemed'**
  String get redeemed;

  /// Reloads the current screen's data.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Remember this device'**
  String get rememberThisDevice;

  /// Cart line action
  ///
  /// In en, this message translates to:
  /// **'Remove from cart'**
  String get removeFromCart;

  /// Cart action
  ///
  /// In en, this message translates to:
  /// **'Remove out-of-stock items'**
  String get removeOutOfStock;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get removePassword;

  /// Confirmation after taking an item out of a collection
  ///
  /// In en, this message translates to:
  /// **'Removed from {name}'**
  String removedFromCollection(String name);

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Rename the device'**
  String get renameDevice;

  /// Order action
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get reorder;

  /// Button that starts a reply to a comment.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// Support note
  ///
  /// In en, this message translates to:
  /// **'We usually reply within an hour'**
  String get replyWithinHour;

  /// Order action
  ///
  /// In en, this message translates to:
  /// **'Request a return'**
  String get requestReturn;

  /// OTP progress
  ///
  /// In en, this message translates to:
  /// **'Requesting a one-time code…'**
  String get requestingCode;

  /// OTP action
  ///
  /// In en, this message translates to:
  /// **'Resend the code'**
  String get resendCode;

  /// Resend cooldown
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendInSeconds(int seconds);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetYourPassword;

  /// Button on an error state
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

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

  /// How many of a line are already claimed
  ///
  /// In en, this message translates to:
  /// **'{count} already requested'**
  String returnAlreadyClaimed(int count);

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

  /// Item picker heading
  ///
  /// In en, this message translates to:
  /// **'Which pieces?'**
  String get returnChooseItems;

  /// Reason picker heading
  ///
  /// In en, this message translates to:
  /// **'Why is it going back?'**
  String get returnChooseReason;

  /// Evidence section
  ///
  /// In en, this message translates to:
  /// **'Her photographs'**
  String get returnEvidence;

  /// Why photos are required for a fault claim
  ///
  /// In en, this message translates to:
  /// **'At least one, because this moves money away from a boutique'**
  String get returnEvidenceHelper;

  /// Photo field label on a fault claim
  ///
  /// In en, this message translates to:
  /// **'Photographs of the problem'**
  String get returnEvidenceLabel;

  /// Validation: fault reason with no photo
  ///
  /// In en, this message translates to:
  /// **'Add at least one photograph showing the problem'**
  String get returnEvidenceRequired;

  /// Items section
  ///
  /// In en, this message translates to:
  /// **'What is coming back'**
  String get returnItems;

  /// Quantity stepper label on a return line
  ///
  /// In en, this message translates to:
  /// **'How many'**
  String get returnLineQuantity;

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

  /// Empty state when no line is returnable
  ///
  /// In en, this message translates to:
  /// **'Nothing in this parcel can go back'**
  String get returnNothingReturnable;

  /// Links a return to its parcel
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String returnParcelLabel(Object number);

  /// FAQ topic
  ///
  /// In en, this message translates to:
  /// **'Return policy'**
  String get returnPolicy;

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

  /// Button on an order parcel that opens the return form
  ///
  /// In en, this message translates to:
  /// **'Return or exchange'**
  String get returnRequestAction;

  /// Title of the customer's return request screen
  ///
  /// In en, this message translates to:
  /// **'Request a return'**
  String get returnRequestTitle;

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

  /// Validation: no item chosen
  ///
  /// In en, this message translates to:
  /// **'Choose at least one piece'**
  String get returnSelectAtLeastOne;

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

  /// Submits the return request
  ///
  /// In en, this message translates to:
  /// **'Send the request'**
  String get returnSubmit;

  /// Confirmation after submitting
  ///
  /// In en, this message translates to:
  /// **'Your request has arrived; the boutique will review it'**
  String get returnSubmitted;

  /// Blocks submit while uploads are in flight
  ///
  /// In en, this message translates to:
  /// **'Wait for the photographs to finish uploading'**
  String get returnUploadingWait;

  /// Shown when the window has passed
  ///
  /// In en, this message translates to:
  /// **'The return window for this parcel has closed'**
  String get returnWindowClosed;

  /// Deadline line
  ///
  /// In en, this message translates to:
  /// **'The return window closes {date}'**
  String returnWindowCloses(Object date);

  /// Extra days granted to this shopper
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{You have 1 extra day on the window} other{You have {days} extra days on the window}}'**
  String returnWindowExtraDays(int days);

  /// When the return window closes
  ///
  /// In en, this message translates to:
  /// **'You can ask until {date}'**
  String returnWindowUntil(String date);

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

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Reviews and ratings'**
  String get reviewsAndRatings;

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

  /// Body field of the review form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'What did you think?'**
  String get reviewsFieldBody;

  /// Title field of the review form [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get reviewsFieldTitle;

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

  /// Empty state body for reviews [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Be the first to say what you think.'**
  String get reviewsNoneBody;

  /// Empty state title for reviews [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get reviewsNoneTitle;

  /// Reviews list — banner over the viewer's own pending review
  ///
  /// In en, this message translates to:
  /// **'Your review is in — it appears publicly once it is checked'**
  String get reviewsPendingYours;

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

  /// Heading of the reviews section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsSectionTitle;

  /// Star rating tooltip [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String reviewsStarsCount(int count);

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

  /// Tag on a verified review
  ///
  /// In en, this message translates to:
  /// **'Verified purchase'**
  String get reviewsVerifiedBuyer;

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

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Revoke the session'**
  String get revokeSession;

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

  /// Applies an entered code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get rewardsApplyCode;

  /// Cashback that can be used now [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get rewardsAvailable;

  /// Label over the points balance [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Points available'**
  String get rewardsAvailablePoints;

  /// Screen-reader summary of the rewards balance [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{1 point, {tier} tier} other{{points} points, {tier} tier}}'**
  String rewardsBalanceSemantics(int points, String tier);

  /// Membership benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Member-only offers'**
  String get rewardsBenefitOffers;

  /// Membership benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Points on every order'**
  String get rewardsBenefitPoints;

  /// Membership benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards for every friend you invite'**
  String get rewardsBenefitReferrals;

  /// Bonus cashback label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get rewardsBonus;

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

  /// Confirmation after converting cashback [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your cashback is now a coupon'**
  String get rewardsCashbackConverted;

  /// Note under the cashback rate [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Paid back to your wallet after delivery'**
  String get rewardsCashbackNote;

  /// Cashback rate benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{rate}% cashback'**
  String rewardsCashbackRate(String rate);

  /// Claims an exclusive reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get rewardsClaim;

  /// Confirmation after applying a code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Code applied'**
  String get rewardsCodeApplied;

  /// Confirmation after copying a code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{code} copied'**
  String rewardsCodeCopied(String code);

  /// Shown when a code is rejected [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'That code did not work'**
  String get rewardsCodeInvalid;

  /// Converts cashback into a coupon [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Turn into a coupon'**
  String get rewardsConvertToCoupon;

  /// Tooltip on a copy button [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String rewardsCopyLabel(String label);

  /// Label of the customer referral code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get rewardsCustomerCode;

  /// Empty state body in the rewards list [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Keep shopping and offers will appear here.'**
  String get rewardsEmptyBody;

  /// Empty state title in the rewards list [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No rewards yet'**
  String get rewardsEmptyTitle;

  /// Placeholder of the code field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get rewardsEnterCode;

  /// Badge on a member-only reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get rewardsExclusive;

  /// Placeholder while a referral code is created [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get rewardsGenerating;

  /// Label of the code entry field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Have a code?'**
  String get rewardsHaveCode;

  /// Explains referrals [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'She gets a welcome offer, you get points.'**
  String get rewardsInviteBody;

  /// Heading of the referral section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get rewardsInviteTitle;

  /// How many friends were invited [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get rewardsInvited;

  /// Lifetime cashback [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Earned in total'**
  String get rewardsLifetime;

  /// Error when the rewards hub fails to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards could not load'**
  String get rewardsLoadFailed;

  /// Fallback description of a reward with no cost or value [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Member reward'**
  String get rewardsMemberReward;

  /// Points multiplier benefit [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{multiplier}x points on every order'**
  String rewardsMultiplier(String multiplier);

  /// Names the next tier up [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Next: {tier}'**
  String rewardsNextTier(String tier);

  /// Shown when there is no cashback to convert [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'No cashback to convert yet'**
  String get rewardsNoCashback;

  /// Shown when a reward costs more points than she holds [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Not enough points yet'**
  String get rewardsNotEnoughPoints;

  /// How many rewards are redeemable [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to redeem yet} =1{1 offer} other{{count} offers}}'**
  String rewardsOffersCount(int count);

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

  /// Cashback not yet released [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get rewardsPending;

  /// Points label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get rewardsPoints;

  /// Rewards description
  ///
  /// In en, this message translates to:
  /// **'Earn points on every order and review. Redeem them for coupons and perks.'**
  String get rewardsPointsBlurb;

  /// What a reward costs in points [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{1 point} other{{points} points}}'**
  String rewardsPointsCost(int points);

  /// Progress toward the next tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the way to {tier}'**
  String rewardsProgressToward(int percent, String tier);

  /// Redeems a reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get rewardsRedeem;

  /// Heading of the redeemable rewards section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get rewardsRedeemSection;

  /// Confirmation after redeeming a reward [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Redeemed — the code is in your coupons'**
  String get rewardsRedeemed;

  /// How many referrals paid out [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewarded'**
  String get rewardsRewarded;

  /// Label of the seller referral code [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your seller code'**
  String get rewardsSellerCode;

  /// Referrals held for review [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invite is being checked} other{{count} invites are being checked}}'**
  String rewardsSuspiciousChecks(int count);

  /// Note under the points multiplier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Earned automatically as you shop'**
  String get rewardsTierBonusNote;

  /// Membership line for a standard tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{tier} member'**
  String rewardsTierMember(String tier);

  /// Heading of the membership tier section [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your tier'**
  String get rewardsTierSection;

  /// Membership line for the top tier [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{tier} membership'**
  String rewardsTierVip(String tier);

  /// Title of the rewards screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewardsTitle;

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

  /// Shown when the rewards hub is unavailable [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rewards are not available right now'**
  String get rewardsUnavailable;

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

  /// Title of the sheet that files a saved product or post into a wishlist collection
  ///
  /// In en, this message translates to:
  /// **'Save to a collection'**
  String get saveToCollection;

  /// Subtitle of the save-to-collection sheet
  ///
  /// In en, this message translates to:
  /// **'Keep it loose, or file it where you will find it again.'**
  String get saveToCollectionBlurb;

  /// Guest benefit title
  ///
  /// In en, this message translates to:
  /// **'Save your progress'**
  String get saveYourProgress;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get savedAddresses;

  /// How many shoppers saved a listing. {count} is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{count} saves'**
  String savedCount(String count);

  /// Cart section
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get savedForLater;

  /// Profile section
  ///
  /// In en, this message translates to:
  /// **'Saved items'**
  String get savedItems;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get savedPosts;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Saved products'**
  String get savedProducts;

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Keep favorites, carts, orders, and recently viewed pieces.'**
  String get savedProgressBlurb;

  /// Profile tab
  ///
  /// In en, this message translates to:
  /// **'Saved sellers'**
  String get savedSellers;

  /// Bottom navigation label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Heading over the department chips [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Browse categories'**
  String get searchBrowseCategories;

  /// Label on a paid placement shown above search or category results.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get searchSponsored;

  /// Clears the search field [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// Clears the recent search history [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get searchClearAll;

  /// Eyebrow over the departments block [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get searchDiscoverEyebrow;

  /// Search field placeholder. Four different wordings existed before.
  ///
  /// In en, this message translates to:
  /// **'Search dresses, beauty, gifts…'**
  String get searchHint;

  /// Heading over recent searches [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'حقيبة'**
  String get searchTrendBags;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'فستان'**
  String get searchTrendDresses;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'سهرة'**
  String get searchTrendEvening;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'ورد'**
  String get searchTrendFlowers;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'هدية'**
  String get searchTrendGifts;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'حذاء'**
  String get searchTrendHeels;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'عطر'**
  String get searchTrendPerfume;

  /// Suggested search term [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'كريم'**
  String get searchTrendSkincare;

  /// Eyebrow over the trending block [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get searchTrendingEyebrow;

  /// Heading over trending search terms [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get searchTrendingNow;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Secure account controls'**
  String get secureAccountControls;

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

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get securityTitle;

  /// Expands truncated content
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// Validation message on checkout
  ///
  /// In en, this message translates to:
  /// **'Choose your governorate'**
  String get selectGovernorate;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get selectLanguage;

  /// Seller menu row: audit trail of store actions.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get sellerActivityLog;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get sellerAddProduct;

  /// Shown when the seller has no pending work.
  ///
  /// In en, this message translates to:
  /// **'All clear — nothing is waiting on you'**
  String get sellerAllClear;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get sellerAnalytics;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get sellerAnnouncement;

  /// Seller home greeting before noon
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get sellerBenchGreetingMorning;

  /// Seller home greeting after noon
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get sellerBenchGreetingEvening;

  /// Seller home greeting with the store's name
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String sellerBenchGreetingNamed(String greeting, String name);

  /// Label above today's revenue on the seller home
  ///
  /// In en, this message translates to:
  /// **'Today\'s takings'**
  String get sellerBenchTodayTakings;

  /// The monthly goal is met
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get sellerBenchGoalReached;

  /// The most important thing to do now on the seller home
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get sellerBenchStartHere;

  /// The rest of the seller's to-do list
  ///
  /// In en, this message translates to:
  /// **'After that'**
  String get sellerBenchThen;

  /// Seller home when nothing needs doing
  ///
  /// In en, this message translates to:
  /// **'Your shop is calm — nothing is waiting for you right now.'**
  String get sellerBenchCalm;

  /// Next action: confirm new orders
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One new order is waiting for you to confirm} other{{count} new orders are waiting for you to confirm}}'**
  String sellerBenchNewOrders(int count);

  /// Why confirming new orders matters
  ///
  /// In en, this message translates to:
  /// **'Every hour of waiting cools a customer\'s excitement.'**
  String get sellerBenchNewOrdersHint;

  /// Next action: hand ready orders to the courier
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One order is ready to ship} other{{count} orders are ready to ship}}'**
  String sellerBenchReadyOrders(int count);

  /// Why shipping ready orders matters
  ///
  /// In en, this message translates to:
  /// **'Hand them to the courier before the day ends.'**
  String get sellerBenchReadyOrdersHint;

  /// Next action: a product is out of stock
  ///
  /// In en, this message translates to:
  /// **'“{title}” has sold out'**
  String sellerBenchSoldOut(String title);

  /// Why restocking matters
  ///
  /// In en, this message translates to:
  /// **'Restock it so it does not drop out of search.'**
  String get sellerBenchSoldOutHint;

  /// Button to the seller's orders
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get sellerBenchOpenOrders;

  /// Button to the seller's products
  ///
  /// In en, this message translates to:
  /// **'Open products'**
  String get sellerBenchOpenProducts;

  /// Seller home: the order pipeline
  ///
  /// In en, this message translates to:
  /// **'The order seam'**
  String get sellerBenchSeamTitle;

  /// Explains the lit stages of the order pipeline
  ///
  /// In en, this message translates to:
  /// **'The lit stops are waiting on you.'**
  String get sellerBenchSeamCaption;

  /// Seller home: quick actions
  ///
  /// In en, this message translates to:
  /// **'Your tools'**
  String get sellerBenchToolsTitle;

  /// Seller home: best sellers and pieces running out
  ///
  /// In en, this message translates to:
  /// **'On the shelf'**
  String get sellerBenchRailTitle;

  /// Explains the rail
  ///
  /// In en, this message translates to:
  /// **'What sells, and what is about to run out.'**
  String get sellerBenchRailCaption;

  /// Swing tag on a best seller
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String sellerBenchTagSold(String count);

  /// Swing tag on a piece running low
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String sellerBenchTagLeft(String count);

  /// Swing tag on a sold-out piece
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get sellerBenchTagOut;

  /// Seller home: revenue chart
  ///
  /// In en, this message translates to:
  /// **'The rhythm of sales'**
  String get sellerBenchPatternTitle;

  /// Explains the revenue chart
  ///
  /// In en, this message translates to:
  /// **'Every pearl on the ribbon is a period; the gold one is now.'**
  String get sellerBenchPatternCaption;

  /// Screen-reader label of the revenue chart
  ///
  /// In en, this message translates to:
  /// **'Revenue over the selected period'**
  String get sellerBenchPatternSemantics;

  /// Seller home: the remaining panels
  ///
  /// In en, this message translates to:
  /// **'More about your shop'**
  String get sellerBenchMoreTitle;

  /// Product row menu action: retire the listing.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sellerArchive;

  /// Caption under the seller's withdrawable balance.
  ///
  /// In en, this message translates to:
  /// **'Available to withdraw'**
  String get sellerAvailableToWithdraw;

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

  /// No description provided for @sellerCancelPresetNoTime.
  ///
  /// In en, this message translates to:
  /// **'I cannot prepare it in time'**
  String get sellerCancelPresetNoTime;

  /// No description provided for @sellerCancelPresetOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get sellerCancelPresetOutOfStock;

  /// No description provided for @sellerCancelPresetPriceError.
  ///
  /// In en, this message translates to:
  /// **'The listed price was wrong'**
  String get sellerCancelPresetPriceError;

  /// No description provided for @sellerCancelPresetSizeGone.
  ///
  /// In en, this message translates to:
  /// **'That size has run out'**
  String get sellerCancelPresetSizeGone;

  /// No description provided for @sellerCancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Write a reason the customer will understand'**
  String get sellerCancelReasonHint;

  /// No description provided for @sellerCancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get sellerCancelReasonLabel;

  /// No description provided for @sellerCancelReasonTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write a reason of at least five characters'**
  String get sellerCancelReasonTooShort;

  /// No description provided for @sellerCancelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The items go back to your stock, and the customer is told the reason you write.'**
  String get sellerCancelSubtitle;

  /// Cart abandonment rate [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{rate}% left the cart'**
  String sellerCartAbandon(String rate);

  /// Funnel step.
  ///
  /// In en, this message translates to:
  /// **'Cart adds'**
  String get sellerCartAdds;

  /// Eyebrow over the seller home header.
  ///
  /// In en, this message translates to:
  /// **'Command centre'**
  String get sellerCommandCentre;

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

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Create coupon'**
  String get sellerCreateCoupon;

  /// Seller screen title
  ///
  /// In en, this message translates to:
  /// **'Store dashboard'**
  String get sellerDashboard;

  /// Error when the seller dashboard fails to load [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'The dashboard could not load'**
  String get sellerDashboardLoadFailed;

  /// Error title when the seller dashboard fails to load.
  ///
  /// In en, this message translates to:
  /// **'Dashboard unavailable'**
  String get sellerDashboardUnavailable;

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

  /// No description provided for @sellerDeliverCollectedHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if you collected the full amount'**
  String get sellerDeliverCollectedHint;

  /// No description provided for @sellerDeliverCollectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount collected'**
  String get sellerDeliverCollectedLabel;

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

  /// No description provided for @sellerDeliverTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get sellerDeliverTitle;

  /// Title of the seller earnings screen.
  ///
  /// In en, this message translates to:
  /// **'My earnings'**
  String get sellerEarnings;

  /// Product row menu action: open the edit form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sellerEditProduct;

  /// Button on the seller profile header.
  ///
  /// In en, this message translates to:
  /// **'Edit store'**
  String get sellerEditStore;

  /// Commission and platform fees deducted.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get sellerFees;

  /// Seller menu row: statements and exports.
  ///
  /// In en, this message translates to:
  /// **'Financial reports'**
  String get sellerFinancialReports;

  /// Store score component.
  ///
  /// In en, this message translates to:
  /// **'Fulfillment'**
  String get sellerFulfillment;

  /// No description provided for @sellerFulfilmentPickupPoint.
  ///
  /// In en, this message translates to:
  /// **'Pickup point'**
  String get sellerFulfilmentPickupPoint;

  /// No description provided for @sellerFulfilmentPlatformCourier.
  ///
  /// In en, this message translates to:
  /// **'Platform courier'**
  String get sellerFulfilmentPlatformCourier;

  /// No description provided for @sellerFulfilmentSelfShips.
  ///
  /// In en, this message translates to:
  /// **'You deliver it'**
  String get sellerFulfilmentSelfShips;

  /// No description provided for @sellerFulfilmentThirdParty.
  ///
  /// In en, this message translates to:
  /// **'Shipping company'**
  String get sellerFulfilmentThirdParty;

  /// Title of the goals section.
  ///
  /// In en, this message translates to:
  /// **'Store goals'**
  String get sellerGoals;

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

  /// Seller settings group: the storefront itself.
  ///
  /// In en, this message translates to:
  /// **'Store management'**
  String get sellerGroupStore;

  /// Title of the AI insights section.
  ///
  /// In en, this message translates to:
  /// **'Smart insights'**
  String get sellerInsights;

  /// Status pill in the seller rail: the storefront is published.
  ///
  /// In en, this message translates to:
  /// **'Store is live'**
  String get sellerLiveStore;

  /// Title of the low-stock section.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get sellerLowStockTitle;

  /// Link from the orders overview to the full order list.
  ///
  /// In en, this message translates to:
  /// **'Manage all'**
  String get sellerManageAll;

  /// Seller shortcut.
  ///
  /// In en, this message translates to:
  /// **'Manage orders'**
  String get sellerManageOrders;

  /// Profit margin percentage on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get sellerMargin;

  /// Caption on the seller stats card. {year} is a four-digit year.
  ///
  /// In en, this message translates to:
  /// **'Selling since {year}'**
  String sellerMemberSince(String year);

  /// Product row menu action: unpublish back to a draft.
  ///
  /// In en, this message translates to:
  /// **'Move to draft'**
  String get sellerMoveToDraft;

  /// Title of the strip listing what the seller must act on today.
  ///
  /// In en, this message translates to:
  /// **'Needs you now'**
  String get sellerNeedsYou;

  /// Floating action on the seller's product list.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get sellerNewProduct;

  /// Empty-state body on the seller's product list.
  ///
  /// In en, this message translates to:
  /// **'Add your first piece and it will show up here.'**
  String get sellerNoProductsBlurb;

  /// Empty state on the seller's product list.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get sellerNoProductsYet;

  /// Alert tile: outstanding to-do items.
  ///
  /// In en, this message translates to:
  /// **'Open tasks'**
  String get sellerOpenTasks;

  /// No description provided for @sellerOrderActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get sellerOrderActionCancel;

  /// No description provided for @sellerOrderActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get sellerOrderActionConfirm;

  /// No description provided for @sellerOrderActionDeliver.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get sellerOrderActionDeliver;

  /// No description provided for @sellerOrderActionHandOver.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get sellerOrderActionHandOver;

  /// No description provided for @sellerOrderActionReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to ship'**
  String get sellerOrderActionReady;

  /// No description provided for @sellerOrderAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get sellerOrderAddressCopied;

  /// No description provided for @sellerOrderAwaitingCustomerCode.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer\'s confirmation code'**
  String get sellerOrderAwaitingCustomerCode;

  /// No description provided for @sellerOrderCallCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call the customer'**
  String get sellerOrderCallCustomer;

  /// No description provided for @sellerOrderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled and the items returned to stock'**
  String get sellerOrderCancelled;

  /// No description provided for @sellerOrderCashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get sellerOrderCashOnDelivery;

  /// No description provided for @sellerOrderCommission.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get sellerOrderCommission;

  /// No description provided for @sellerOrderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Accepted — the order is now being prepared'**
  String get sellerOrderConfirmed;

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

  /// No description provided for @sellerOrderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivery recorded'**
  String get sellerOrderDelivered;

  /// No description provided for @sellerOrderDiscount.
  ///
  /// In en, this message translates to:
  /// **'Your discount'**
  String get sellerOrderDiscount;

  /// No description provided for @sellerOrderEscrowOn.
  ///
  /// In en, this message translates to:
  /// **'Earnings become available once the return window closes on {date}.'**
  String sellerOrderEscrowOn(String date);

  /// No description provided for @sellerOrderEscrowPending.
  ///
  /// In en, this message translates to:
  /// **'Earnings are counted after delivery and once the return window closes.'**
  String get sellerOrderEscrowPending;

  /// No description provided for @sellerOrderEscrowReleased.
  ///
  /// In en, this message translates to:
  /// **'These earnings are now available for payout.'**
  String get sellerOrderEscrowReleased;

  /// No description provided for @sellerOrderHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Handover recorded'**
  String get sellerOrderHandedOver;

  /// No description provided for @sellerOrderItemsSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Items subtotal'**
  String get sellerOrderItemsSubtotal;

  /// No description provided for @sellerOrderItemsToPack.
  ///
  /// In en, this message translates to:
  /// **'What to pack'**
  String get sellerOrderItemsToPack;

  /// No description provided for @sellerOrderMarkedReady.
  ///
  /// In en, this message translates to:
  /// **'The order is ready to ship'**
  String get sellerOrderMarkedReady;

  /// No description provided for @sellerOrderNet.
  ///
  /// In en, this message translates to:
  /// **'Your net earnings'**
  String get sellerOrderNet;

  /// No description provided for @sellerOrderStepConfirmed.
  ///
  /// In en, this message translates to:
  /// **'You accepted it'**
  String get sellerOrderStepConfirmed;

  /// No description provided for @sellerOrderStepDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get sellerOrderStepDelivered;

  /// No description provided for @sellerOrderStepPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order received'**
  String get sellerOrderStepPlaced;

  /// No description provided for @sellerOrderStepShipped.
  ///
  /// In en, this message translates to:
  /// **'Left for delivery'**
  String get sellerOrderStepShipped;

  /// No description provided for @sellerOrdersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Orders move here as they progress.'**
  String get sellerOrdersEmptyBody;

  /// No description provided for @sellerOrdersEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed orders yet'**
  String get sellerOrdersEmptyCompleted;

  /// No description provided for @sellerOrdersEmptyNew.
  ///
  /// In en, this message translates to:
  /// **'No new orders'**
  String get sellerOrdersEmptyNew;

  /// No description provided for @sellerOrdersEmptyNewBody.
  ///
  /// In en, this message translates to:
  /// **'Orders appear here the moment a customer buys from you.'**
  String get sellerOrdersEmptyNewBody;

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

  /// No description provided for @sellerOrdersEmptyReturns.
  ///
  /// In en, this message translates to:
  /// **'No returns'**
  String get sellerOrdersEmptyReturns;

  /// No description provided for @sellerOrdersEmptyReturnsBody.
  ///
  /// In en, this message translates to:
  /// **'Which is good news.'**
  String get sellerOrdersEmptyReturnsBody;

  /// No description provided for @sellerOrdersEmptyShipping.
  ///
  /// In en, this message translates to:
  /// **'No parcels on the way'**
  String get sellerOrdersEmptyShipping;

  /// No description provided for @sellerOrdersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this order'**
  String get sellerOrdersLoadFailed;

  /// No description provided for @sellerOrdersOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get sellerOrdersOffline;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get sellerOrdersStat;

  /// No description provided for @sellerOrdersTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sellerOrdersTabCompleted;

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

  /// No description provided for @sellerOrdersTabReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get sellerOrdersTabReturns;

  /// No description provided for @sellerOrdersTabShipping.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get sellerOrdersTabShipping;

  /// Title of the seller's order queue.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get sellerOrdersTitle;

  /// No description provided for @sellerOrdersUpdated.
  ///
  /// In en, this message translates to:
  /// **'Order updated'**
  String get sellerOrdersUpdated;

  /// Badge on a product with no stock left.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get sellerOutOfStock;

  /// Lifetime total already paid to the seller.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get sellerPaidOut;

  /// No description provided for @sellerParcelStatusAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your confirmation'**
  String get sellerParcelStatusAwaitingConfirmation;

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

  /// No description provided for @sellerParcelStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'In dispute'**
  String get sellerParcelStatusDisputed;

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

  /// No description provided for @sellerParcelStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get sellerParcelStatusNew;

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

  /// No description provided for @sellerParcelStatusRejectedOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Refused at the door'**
  String get sellerParcelStatusRejectedOnDelivery;

  /// No description provided for @sellerParcelStatusReturnInTransit.
  ///
  /// In en, this message translates to:
  /// **'Return on its way'**
  String get sellerParcelStatusReturnInTransit;

  /// No description provided for @sellerParcelStatusReturnRequested.
  ///
  /// In en, this message translates to:
  /// **'Return requested'**
  String get sellerParcelStatusReturnRequested;

  /// No description provided for @sellerParcelStatusReturned.
  ///
  /// In en, this message translates to:
  /// **'Return received'**
  String get sellerParcelStatusReturned;

  /// Seller menu row: payout and payment methods.
  ///
  /// In en, this message translates to:
  /// **'Payment settings'**
  String get sellerPaymentSettings;

  /// Alert tile: orders awaiting the seller's confirmation.
  ///
  /// In en, this message translates to:
  /// **'To confirm'**
  String get sellerPendingOrders;

  /// Earnings not yet available to withdraw.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get sellerPendingPayout;

  /// Subscription badge on the seller profile. {plan} is the plan name.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan'**
  String sellerPlanBadge(String plan);

  /// Version footer at the foot of the seller profile.
  ///
  /// In en, this message translates to:
  /// **'Seller platform · v{version}'**
  String sellerPlatformFooter(String version);

  /// Store score component.
  ///
  /// In en, this message translates to:
  /// **'Product quality'**
  String get sellerProductQuality;

  /// Funnel step.
  ///
  /// In en, this message translates to:
  /// **'Product views'**
  String get sellerProductViews;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get sellerProductsStat;

  /// Profit figure on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get sellerProfit;

  /// Title of the seller shortcut grid.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get sellerQuickActions;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get sellerRatingStat;

  /// Rating line on the seller stats card. {count} picks the plural; {countLabel} is the same count formatted compactly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{rating} · 1 review} other{{rating} · {countLabel} reviews}}'**
  String sellerRatingSummary(String rating, int count, String countLabel);

  /// Title of the reviews section.
  ///
  /// In en, this message translates to:
  /// **'Recent reviews'**
  String get sellerRecentReviews;

  /// No description provided for @sellerReplied.
  ///
  /// In en, this message translates to:
  /// **'The boutique replied'**
  String get sellerReplied;

  /// Store score component.
  ///
  /// In en, this message translates to:
  /// **'Responsiveness'**
  String get sellerResponsiveness;

  /// Button that opens the stock adjustment flow.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get sellerRestock;

  /// How many products are critically low [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece needs restocking} other{{count} pieces need restocking}}'**
  String sellerRestockNeeded(int count);

  /// The seller's returns desk
  ///
  /// In en, this message translates to:
  /// **'Returns and exchanges'**
  String get sellerReturnsTitle;

  /// Money taken over the selected period.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get sellerRevenue;

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

  /// Alert tile: products close to selling out.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get sellerRunningLow;

  /// Seller stat label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sellerSalesStat;

  /// Title of the revenue/orders chart.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get sellerSalesTrend;

  /// Product row menu action: put the listing live.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get sellerSetActive;

  /// Seller menu row: courier and delivery options.
  ///
  /// In en, this message translates to:
  /// **'Shipping settings'**
  String get sellerShippingSettings;

  /// Stock line on a managed product row. {count} is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String sellerStock(String count);

  /// Title of the store score section.
  ///
  /// In en, this message translates to:
  /// **'Store health'**
  String get sellerStorePerformance;

  /// Seller menu row: returns and store rules.
  ///
  /// In en, this message translates to:
  /// **'Store policies'**
  String get sellerStorePolicies;

  /// Seller menu row: the store's billing plan.
  ///
  /// In en, this message translates to:
  /// **'Subscription & plan'**
  String get sellerSubscriptionPlan;

  /// Seller menu row: a direct line to the platform team.
  ///
  /// In en, this message translates to:
  /// **'Seller support'**
  String get sellerSupport;

  /// Title of the seller task list.
  ///
  /// In en, this message translates to:
  /// **'To-do list'**
  String get sellerTasks;

  /// Seller menu row: staff accounts on the store.
  ///
  /// In en, this message translates to:
  /// **'Team management'**
  String get sellerTeamManagement;

  /// Title of the seller's top products section.
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get sellerTopProducts;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Seller verification'**
  String get sellerVerification;

  /// Caption under the trend arrow on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'vs. prior period'**
  String get sellerVsPrior;

  /// Funnel step.
  ///
  /// In en, this message translates to:
  /// **'Wishlist adds'**
  String get sellerWishlistAdds;

  /// Button that starts a payout.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get sellerWithdraw;

  /// Seller menu row and the title of the payout card.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal centre'**
  String get sellerWithdrawalCentre;

  /// No description provided for @sellersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seller} other{{count} sellers}}'**
  String sellersCount(num count);

  /// How many sellers list this product
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seller} other{{count} sellers}}'**
  String sellersOffering(int count);

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Action on the recovery form
  ///
  /// In en, this message translates to:
  /// **'Send the code'**
  String get sendCode;

  /// Absolute session lifetime
  ///
  /// In en, this message translates to:
  /// **'Signed in until {date}'**
  String sessionExpiresOn(String date);

  /// Security section
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPassword;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Confirmation after a profile update from settings [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Your profile is saved'**
  String get settingsProfileUpdated;

  /// Story composer action
  ///
  /// In en, this message translates to:
  /// **'Share your moment'**
  String get shareMoment;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Assigned to a courier'**
  String get shipStageAssigned;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shipStageCancelled;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Order prepared'**
  String get shipStageCreated;

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
  /// **'Picked up'**
  String get shipStagePickedUp;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get shipStageReturned;

  /// Shipment stage.
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get shipStageReturning;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Shipping methods'**
  String get shippingMethods;

  /// Example shipping methods, comma separated.
  ///
  /// In en, this message translates to:
  /// **'Courier, pickup, same-day'**
  String get shippingMethodsHint;

  /// Compact age of a post, in days.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String shortDaysAgo(int count);

  /// Compact age of a post, in hours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String shortHoursAgo(int count);

  /// Compact age of a post, in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String shortMinutesAgo(int count);

  /// Compact age of a post, in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count}w'**
  String shortWeeksAgo(int count);

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// Expands a truncated block [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// Tooltip on the eye that reveals a password
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Confirm dialog body
  ///
  /// In en, this message translates to:
  /// **'You can always sign back in.'**
  String get signBackInLater;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Auth gate title
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get signInRequired;

  /// Subtitle on the phone-entry step
  ///
  /// In en, this message translates to:
  /// **'Enter your number and we will send you a code.'**
  String get signInSubtitle;

  /// Auth gate action
  ///
  /// In en, this message translates to:
  /// **'Sign in to checkout'**
  String get signInToCheckout;

  /// No description provided for @signInToComment.
  ///
  /// In en, this message translates to:
  /// **'Sign in to comment'**
  String get signInToComment;

  /// Auth prompt
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

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

  /// Primary sign-in button: a code on her SIM is the credential
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get signInWithCode;

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

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere else'**
  String get signOutEverywhere;

  /// Confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutQuestion;

  /// Benefits of creating an account [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Create an account to checkout, message sellers and keep your favourites.'**
  String get signUpBenefitsBlurb;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signup;

  /// Heading over the boutique selling the shown offer
  ///
  /// In en, this message translates to:
  /// **'Sold by'**
  String get soldBy;

  /// Badge on a product with no stock [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get soldOut;

  /// Tagline under the logo on the splash screen
  ///
  /// In en, this message translates to:
  /// **'Where beauty meets social shopping'**
  String get splashTagline;

  /// Shown when a basket spans several sellers
  ///
  /// In en, this message translates to:
  /// **'Your order is from {count} sellers and will arrive in separate parcels — with one delivery charge.'**
  String splitOrderNotice(int count);

  /// Support action
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get startConversation;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// Order state
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get statusInTransit;

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

  /// Stock state label for low stock [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Only a few left'**
  String get stockLow;

  /// Stock state label [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get stockOut;

  /// The owner cancelling a recovery case
  ///
  /// In en, this message translates to:
  /// **'That was not me — stop it'**
  String get stopThisRequest;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Store description'**
  String get storeDescription;

  /// Seller application: the store's logo image.
  ///
  /// In en, this message translates to:
  /// **'Store logo'**
  String get storeLogo;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Store logo URL'**
  String get storeLogoUrl;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Stores you want to revisit'**
  String get storesToRevisit;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get stories;

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

  /// Section description
  ///
  /// In en, this message translates to:
  /// **'Submit business details to unlock seller trust.'**
  String get submitBusinessDetails;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Submit for verification'**
  String get submitVerification;

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// Generic success
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get success;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Support centre'**
  String get supportCentre;

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

  /// Guest benefit
  ///
  /// In en, this message translates to:
  /// **'Sync favorites, carts, and recommendations.'**
  String get syncBlurb;

  /// Progress
  ///
  /// In en, this message translates to:
  /// **'Syncing your wishlist'**
  String get syncingWishlist;

  /// Language option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get taxNumber;

  /// Theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Dark theme is on'**
  String get themeDarkActive;

  /// Theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Deep plum with a rose glow'**
  String get themeDarkSubtitle;

  /// Theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Light theme is on'**
  String get themeLightActive;

  /// Theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Soft rose and daytime elegance'**
  String get themeLightSubtitle;

  /// Theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Status
  ///
  /// In en, this message translates to:
  /// **'Following the system theme'**
  String get themeSystemActive;

  /// Theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Follows your device settings'**
  String get themeSystemSubtitle;

  /// Badge on the current session
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

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

  /// Date divider for today [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// Home rail title
  ///
  /// In en, this message translates to:
  /// **'Today\'s offers'**
  String get todayOffers;

  /// Summary row
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// TOTP enrolment: totpCodeLabel
  ///
  /// In en, this message translates to:
  /// **'Code from the app'**
  String get totpCodeLabel;

  /// TOTP enrolment: totpConfirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get totpConfirm;

  /// TOTP enrolment: totpConfirmed
  ///
  /// In en, this message translates to:
  /// **'Authenticator app is on'**
  String get totpConfirmed;

  /// TOTP enrolment: totpCopied
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get totpCopied;

  /// TOTP enrolment: totpCopySecret
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get totpCopySecret;

  /// TOTP enrolment: totpDisabled
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get totpDisabled;

  /// TOTP enrolment: totpEnabled
  ///
  /// In en, this message translates to:
  /// **'On — your app generates a code every 30 seconds'**
  String get totpEnabled;

  /// TOTP enrolment: totpEnrol
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get totpEnrol;

  /// TOTP enrolment: totpRequired
  ///
  /// In en, this message translates to:
  /// **'Required for your account'**
  String get totpRequired;

  /// TOTP enrolment: totpSecretHint
  ///
  /// In en, this message translates to:
  /// **'Copy it into Google Authenticator or similar. It is not shown again.'**
  String get totpSecretHint;

  /// TOTP enrolment: totpSecretLabel
  ///
  /// In en, this message translates to:
  /// **'Secret key'**
  String get totpSecretLabel;

  /// TOTP enrolment: totpSetupTitle
  ///
  /// In en, this message translates to:
  /// **'Add Ohara to your authenticator'**
  String get totpSetupTitle;

  /// TOTP enrolment: totpTitle
  ///
  /// In en, this message translates to:
  /// **'Authenticator app'**
  String get totpTitle;

  /// Q37 — how many times the courier has tried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 delivery attempt} other{{count} delivery attempts}}'**
  String trackAttempts(int count);

  /// When the parcel arrived.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get trackDeliveredAt;

  /// Badge on an express parcel (Q64).
  ///
  /// In en, this message translates to:
  /// **'Express'**
  String get trackExpress;

  /// Section title for the event list.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get trackHistory;

  /// Section title for the progress spine.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get trackJourney;

  /// Shown when a tracking code does not resolve.
  ///
  /// In en, this message translates to:
  /// **'No shipment matches that code.'**
  String get trackNotFound;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Track, review and reorder'**
  String get trackReviewReorder;

  /// Q64 — the delivery slot she chose.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for'**
  String get trackScheduledFor;

  /// Title of the shipment tracking screen (Q64).
  ///
  /// In en, this message translates to:
  /// **'Track shipment'**
  String get trackShipment;

  /// Title of the carrier administration screen.
  ///
  /// In en, this message translates to:
  /// **'Delivery companies'**
  String get adminDelivery;

  /// Subtitle of the carrier administration screen.
  ///
  /// In en, this message translates to:
  /// **'The companies that carry parcels, where each delivers, and what is stuck.'**
  String get adminDeliverySubtitle;

  /// Empty state for the carrier list.
  ///
  /// In en, this message translates to:
  /// **'No delivery company is registered yet.'**
  String get adminDeliveryNoProviders;

  /// Heading for the failed dispatch queue.
  ///
  /// In en, this message translates to:
  /// **'Parcels no carrier accepted'**
  String get adminDeliveryStuck;

  /// Empty state for the failed dispatch queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing is stuck — every parcel is with a carrier.'**
  String get adminDeliveryNothingStuck;

  /// Button that re-offers a parcel to its carrier.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminDeliveryRetry;

  /// Coverage tag for a carrier with no governorate list.
  ///
  /// In en, this message translates to:
  /// **'Everywhere'**
  String get adminDeliveryEverywhere;

  /// Tag for the default carrier.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get adminDeliveryDefault;

  /// Carrier priority tag.
  ///
  /// In en, this message translates to:
  /// **'Priority {value}'**
  String adminDeliveryPriority(int value);

  /// Subtitle for the internal courier provider.
  ///
  /// In en, this message translates to:
  /// **'In-house delivery team'**
  String get adminDeliveryInternalFleet;

  /// Shown when a carrier row names an adapter the build does not ship.
  ///
  /// In en, this message translates to:
  /// **'This build has no adapter called {adapter}'**
  String adminDeliveryAdapterMissing(String adapter);

  /// Label for the delivery company carrying a parcel.
  ///
  /// In en, this message translates to:
  /// **'Delivery company'**
  String get deliveryCarrier;

  /// Shown to a seller when a packed parcel has not been accepted by the carrier.
  ///
  /// In en, this message translates to:
  /// **'The delivery company has not accepted it yet — we keep trying.'**
  String get sellerOrderCarrierPendingRetry;

  /// Label for the delivery company's own tracking number.
  ///
  /// In en, this message translates to:
  /// **'Carrier tracking number'**
  String get deliveryCarrierTracking;

  /// Label for the tracking code.
  ///
  /// In en, this message translates to:
  /// **'Tracking code'**
  String get trackingCode;

  /// Shipment tracking line
  ///
  /// In en, this message translates to:
  /// **'Tracking number {code}'**
  String trackingNumber(String code);

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
  /// **'{days, plural, =0{Out today} =1{Out in 1 day} other{Out in {days} days}}'**
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
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
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
  /// **'{units, plural, =1{1 unit forecast} other{{units} units forecast}} {days, plural, =1{over 1 day} other{over {days} days}}'**
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
  /// **'{count, plural, =1{1 product rising} other{{count} products rising}}'**
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

  /// Label above trending search suggestions.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

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
  /// **'In stock: {inStock} of {total}'**
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
  /// **'{days, plural, =1{Forecast units over 1 day} other{Forecast units over {days} days}}'**
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
  /// **'Active: {scored} of {total} scored'**
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

  /// Device action
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get trust;

  /// Already in favourites
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get unfavorite;

  /// Device name fallback
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get unknownDevice;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get unverified;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

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

  /// Secondary sign-in path, only usable on a known device
  ///
  /// In en, this message translates to:
  /// **'Use my password instead'**
  String get usePasswordInstead;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Coupon applied'**
  String get usedCoupon;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email or phone number'**
  String get validEmailOrPhone;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validEmailRequired;

  /// Validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get validPhone;

  /// OTP field label
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// OTP toast
  ///
  /// In en, this message translates to:
  /// **'Verification complete.'**
  String get verificationComplete;

  /// How to photograph a document well.
  ///
  /// In en, this message translates to:
  /// **'Photograph each document in full, in good light.'**
  String get verificationDocumentsHint;

  /// Reassurance above the private document uploads.
  ///
  /// In en, this message translates to:
  /// **'Only you and the review team can open these. They never appear on your store.'**
  String get verificationDocumentsPrivate;

  /// Names the one field the application is missing.
  ///
  /// In en, this message translates to:
  /// **'«{field}» is required.'**
  String verificationFieldRequired(String field);

  /// Shown when an application already exists.
  ///
  /// In en, this message translates to:
  /// **'You have applied before. Editing and submitting replaces that application.'**
  String get verificationResubmitNotice;

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
  /// **'Shipping and returns'**
  String get verificationSectionOperations;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get verificationSectionPayout;

  /// Section header in the seller application.
  ///
  /// In en, this message translates to:
  /// **'Your store'**
  String get verificationSectionStore;

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get verificationStatusApproved;

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
  /// **'Pending'**
  String get verificationStatusPending;

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

  /// Seller verification status, as shown to the seller.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get verificationStatusUnderReview;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Seller verification submitted.'**
  String get verificationSubmitted;

  /// Shown when the application is submitted mid-upload.
  ///
  /// In en, this message translates to:
  /// **'Wait for the documents to finish uploading.'**
  String get verificationUploadPending;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// OTP action
  ///
  /// In en, this message translates to:
  /// **'Verify the code'**
  String get verifyCode;

  /// Toggle label
  ///
  /// In en, this message translates to:
  /// **'Verify new devices'**
  String get verifyNewDevices;

  /// Step-up prompt heading
  ///
  /// In en, this message translates to:
  /// **'Verify it is you'**
  String get verifyToContinue;

  /// OTP screen title
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get verifyYourPhone;

  /// Trailing action on a section header. Was hardcoded in seven widgets.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get viewAll;

  /// Opens the comment sheet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{View 1 comment} other{View all {count} comments}}'**
  String viewAllComments(int count);

  /// Snackbar action opening the wishlist
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewSaved;

  /// Opens the seller storefront
  ///
  /// In en, this message translates to:
  /// **'Visit the store'**
  String get visitStore;

  /// Title of the visual search screen [re-authored: original wording lost]
  ///
  /// In en, this message translates to:
  /// **'Search by photo'**
  String get visualSearchTitle;

  /// Message text carried alongside a voice attachment.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceMessage;

  /// Shown when microphone permission is refused.
  ///
  /// In en, this message translates to:
  /// **'Ohara needs permission to use the microphone.'**
  String get voicePermissionDenied;

  /// Tooltip on the microphone button in the composer.
  ///
  /// In en, this message translates to:
  /// **'Record a voice note'**
  String get voiceRecord;

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

  /// Shown when a voice note cannot be played back.
  ///
  /// In en, this message translates to:
  /// **'This recording is unavailable.'**
  String get voiceUnavailable;

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

  /// Empty-state body on the wallet screen.
  ///
  /// In en, this message translates to:
  /// **'Refunds, gifts and converted points will appear here.'**
  String get walletEmptyBody;

  /// Empty-state title on the wallet screen.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is empty'**
  String get walletEmptyTitle;

  /// Q42 — the wallet balance cannot be withdrawn as cash.
  ///
  /// In en, this message translates to:
  /// **'Spendable inside Ohara only'**
  String get walletNotWithdrawable;

  /// Shown when the wallet cannot load because the device is offline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Your balance will update when you reconnect.'**
  String get walletOffline;

  /// Wallet movement source: a price or order adjustment.
  ///
  /// In en, this message translates to:
  /// **'Price adjustment'**
  String get walletSourceAdjustment;

  /// Wallet movement source: a manual credit from the admin.
  ///
  /// In en, this message translates to:
  /// **'Compensation'**
  String get walletSourceCompensation;

  /// Wallet movement source: a campaign or gift credit.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get walletSourceGift;

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

  /// Wallet movement source: loyalty points turned into credit.
  ///
  /// In en, this message translates to:
  /// **'Points converted'**
  String get walletSourcePoints;

  /// Wallet movement source: money back from a return.
  ///
  /// In en, this message translates to:
  /// **'Return refund'**
  String get walletSourceRefund;

  /// Wallet movement source: the customer added credit.
  ///
  /// In en, this message translates to:
  /// **'Top-up'**
  String get walletSourceTopUp;

  /// Title of the wallet transaction list.
  ///
  /// In en, this message translates to:
  /// **'Wallet activity'**
  String get walletStatement;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Warehouse address'**
  String get warehouseAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// Returning-user heading
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Auth screen heading
  ///
  /// In en, this message translates to:
  /// **'Welcome to Ohara'**
  String get welcomeToOhara;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Wishlist link copied'**
  String get wishlistLinkCopied;

  /// Comment field hint
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get writeComment;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get yearsOfExperience;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Date rule between days in a conversation
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayLabel;

  /// Label marking the signed-in shopper's own comment.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Your orders'**
  String get yourOrders;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Your wishlist'**
  String get yourWishlist;

  /// No description provided for @a11yUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get a11yUnmute;

  /// No description provided for @composerPublished.
  ///
  /// In en, this message translates to:
  /// **'Published ✨'**
  String get composerPublished;

  /// No description provided for @composerPublishedForReview.
  ///
  /// In en, this message translates to:
  /// **'We have your post ✨ We will review it shortly and then everyone can see it.'**
  String get composerPublishedForReview;

  /// No description provided for @composerNeedsMedia.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or a clip first'**
  String get composerNeedsMedia;

  /// No description provided for @composerNeedsVideo.
  ///
  /// In en, this message translates to:
  /// **'A reel needs a video'**
  String get composerNeedsVideo;

  /// No description provided for @composerNeedsCaption.
  ///
  /// In en, this message translates to:
  /// **'Write something, or add a photo'**
  String get composerNeedsCaption;

  /// No description provided for @composerVideoTooLong.
  ///
  /// In en, this message translates to:
  /// **'That clip is longer than 30 seconds'**
  String get composerVideoTooLong;

  /// No description provided for @contentResharedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} added this to her page'**
  String contentResharedBy(String name);

  /// No description provided for @contentFromShopper.
  ///
  /// In en, this message translates to:
  /// **'From a shopper'**
  String get contentFromShopper;

  /// No description provided for @contentFromBoutique.
  ///
  /// In en, this message translates to:
  /// **'From a boutique'**
  String get contentFromBoutique;

  /// No description provided for @contentUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get contentUnderReview;

  /// No description provided for @contentAddToMyPage.
  ///
  /// In en, this message translates to:
  /// **'Add to my page'**
  String get contentAddToMyPage;

  /// No description provided for @contentShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get contentShare;

  /// No description provided for @contentReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get contentReply;

  /// No description provided for @contentReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String contentReplyingTo(String name);

  /// No description provided for @contentShowReplies.
  ///
  /// In en, this message translates to:
  /// **'Show {count} replies'**
  String contentShowReplies(int count);

  /// No description provided for @contentUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'This post is no longer available'**
  String get contentUnavailableTitle;

  /// No description provided for @contentUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, made private, or the story may have expired.'**
  String get contentUnavailableBody;

  /// No description provided for @socialFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get socialFeedTitle;

  /// No description provided for @socialFeedDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get socialFeedDiscover;

  /// No description provided for @socialFeedFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get socialFeedFollowing;

  /// No description provided for @socialFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get socialFeedEmptyTitle;

  /// No description provided for @socialFeedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share your look 🌸'**
  String get socialFeedEmptyBody;

  /// No description provided for @socialFeedFollowingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the boutiques you love'**
  String get socialFeedFollowingEmptyTitle;

  /// No description provided for @socialFeedFollowingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything new from the boutiques and women you follow shows up here.'**
  String get socialFeedFollowingEmptyBody;

  /// No description provided for @socialFeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Looks and stories from the women of Ohara'**
  String get socialFeedSubtitle;

  /// No description provided for @socialFeedStoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s stories'**
  String get socialFeedStoriesTitle;

  /// No description provided for @socialFeedStoriesEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Live now'**
  String get socialFeedStoriesEyebrow;

  /// No description provided for @socialFeedDiscoverEyebrow.
  ///
  /// In en, this message translates to:
  /// **'From the community'**
  String get socialFeedDiscoverEyebrow;

  /// No description provided for @socialFeedDiscoverHeading.
  ///
  /// In en, this message translates to:
  /// **'The latest looks'**
  String get socialFeedDiscoverHeading;

  /// No description provided for @socialFeedFollowingEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Just for you'**
  String get socialFeedFollowingEyebrow;

  /// No description provided for @socialFeedFollowingHeading.
  ///
  /// In en, this message translates to:
  /// **'From the women you follow'**
  String get socialFeedFollowingHeading;

  /// No description provided for @socialFeedShareLook.
  ///
  /// In en, this message translates to:
  /// **'Share your look'**
  String get socialFeedShareLook;

  /// No description provided for @socialFeedCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get socialFeedCaughtUp;

  /// No description provided for @socialFeedCaughtUpBody.
  ///
  /// In en, this message translates to:
  /// **'Come back soon — new looks arrive every day.'**
  String get socialFeedCaughtUpBody;

  /// No description provided for @socialFeedLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more posts'**
  String get socialFeedLoadMoreFailed;

  /// No description provided for @socialFeedGuestFollowingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your own little circle'**
  String get socialFeedGuestFollowingTitle;

  /// No description provided for @socialFeedGuestFollowingBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in and everything new from the boutiques and women you follow gathers here.'**
  String get socialFeedGuestFollowingBody;

  /// No description provided for @socialFeedExploreAction.
  ///
  /// In en, this message translates to:
  /// **'Explore the community'**
  String get socialFeedExploreAction;

  /// No description provided for @socialFeedBackToTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get socialFeedBackToTop;

  /// No description provided for @reelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get reelsTitle;

  /// No description provided for @reelsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reels yet'**
  String get reelsEmptyTitle;

  /// No description provided for @reelsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The first one could be yours 🎬'**
  String get reelsEmptyBody;

  /// No description provided for @composerTitle.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get composerTitle;

  /// No description provided for @contentAddToMyPageBody.
  ///
  /// In en, this message translates to:
  /// **'It will show on your page, and the boutique keeps the credit.'**
  String get contentAddToMyPageBody;

  /// No description provided for @contentAddToMyPagePreview.
  ///
  /// In en, this message translates to:
  /// **'Post preview'**
  String get contentAddToMyPagePreview;

  /// No description provided for @contentAddToMyPageCredit.
  ///
  /// In en, this message translates to:
  /// **'Originally hers — it stays in her name'**
  String get contentAddToMyPageCredit;

  /// No description provided for @contentAddToMyPageProduct.
  ///
  /// In en, this message translates to:
  /// **'Tagged with {title}'**
  String contentAddToMyPageProduct(String title);

  /// No description provided for @contentAddToMyPageNote.
  ///
  /// In en, this message translates to:
  /// **'Your note (optional)'**
  String get contentAddToMyPageNote;

  /// No description provided for @contentAddToMyPageNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What would you say about it?'**
  String get contentAddToMyPageNoteHint;

  /// No description provided for @contentAddToMyPageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add to my page'**
  String get contentAddToMyPageConfirm;

  /// No description provided for @composerMediaLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos or clip'**
  String get composerMediaLabel;

  /// No description provided for @composerMediaVideoHelp.
  ///
  /// In en, this message translates to:
  /// **'One clip, up to 30 seconds'**
  String get composerMediaVideoHelp;

  /// No description provided for @composerCaptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get composerCaptionLabel;

  /// No description provided for @composerCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about the look…'**
  String get composerCaptionHint;

  /// No description provided for @composerPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get composerPublish;

  /// No description provided for @composerAudience.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get composerAudience;

  /// No description provided for @composerAudiencePublic.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get composerAudiencePublic;

  /// No description provided for @composerAudienceFollowers.
  ///
  /// In en, this message translates to:
  /// **'My followers only'**
  String get composerAudienceFollowers;

  /// No description provided for @composerTagProducts.
  ///
  /// In en, this message translates to:
  /// **'Tag the piece'**
  String get composerTagProducts;

  /// No description provided for @composerTagProductsHelp.
  ///
  /// In en, this message translates to:
  /// **'Only pieces that were actually delivered to you'**
  String get composerTagProductsHelp;

  /// No description provided for @composerTagProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Once your first order arrives, your pieces show up here.'**
  String get composerTagProductsEmpty;

  /// No description provided for @studioTitle.
  ///
  /// In en, this message translates to:
  /// **'Content studio'**
  String get studioTitle;

  /// No description provided for @studioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What is working, and how far it went'**
  String get studioSubtitle;

  /// No description provided for @studioFormats.
  ///
  /// In en, this message translates to:
  /// **'Content performance'**
  String get studioFormats;

  /// No description provided for @studioFormatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing published yet'**
  String get studioFormatsEmpty;

  /// No description provided for @studioFormatPost.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get studioFormatPost;

  /// No description provided for @studioFormatStory.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get studioFormatStory;

  /// No description provided for @studioViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get studioViews;

  /// No description provided for @studioSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get studioSaves;

  /// No description provided for @studioProductClicks.
  ///
  /// In en, this message translates to:
  /// **'Product opens'**
  String get studioProductClicks;

  /// No description provided for @studioPublishedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} published'**
  String studioPublishedCount(int count);

  /// No description provided for @studioClickThrough.
  ///
  /// In en, this message translates to:
  /// **'{rate}% of views opened the product'**
  String studioClickThrough(String rate);

  /// No description provided for @studioReach.
  ///
  /// In en, this message translates to:
  /// **'Reach'**
  String get studioReach;

  /// No description provided for @studioReachEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody has added your posts yet'**
  String get studioReachEmpty;

  /// No description provided for @studioReachEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When a shopper adds your post to her page, you will see it here.'**
  String get studioReachEmptyBody;

  /// No description provided for @studioReshares.
  ///
  /// In en, this message translates to:
  /// **'Added to pages'**
  String get studioReshares;

  /// No description provided for @studioPromotersCount.
  ///
  /// In en, this message translates to:
  /// **'Shoppers'**
  String get studioPromotersCount;

  /// No description provided for @studioTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Most shared pieces'**
  String get studioTopProducts;

  /// No description provided for @studioPromoters.
  ///
  /// In en, this message translates to:
  /// **'Who shared your products'**
  String get studioPromoters;

  /// No description provided for @studioPromotersHelp.
  ///
  /// In en, this message translates to:
  /// **'Names show only for shoppers with a public page. The rest are counted without a name.'**
  String get studioPromotersHelp;

  /// No description provided for @studioPromotersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get studioPromotersEmpty;

  /// No description provided for @studioPromotersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The first shopper to add your post to her page shows up here.'**
  String get studioPromotersEmptyBody;

  /// No description provided for @studioPromoterAnonymous.
  ///
  /// In en, this message translates to:
  /// **'A shopper (private page)'**
  String get studioPromoterAnonymous;

  /// No description provided for @studioPromoterSummary.
  ///
  /// In en, this message translates to:
  /// **'Added: {reshares} · Pieces: {products}'**
  String studioPromoterSummary(int reshares, int products);

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View page'**
  String get viewProfile;

  /// No description provided for @adminContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Content moderation'**
  String get adminContentTitle;

  /// No description provided for @adminContentReported.
  ///
  /// In en, this message translates to:
  /// **'{count} reported'**
  String adminContentReported(int count);

  /// No description provided for @adminContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for review'**
  String get adminContentEmpty;

  /// No description provided for @adminContentNoCaption.
  ///
  /// In en, this message translates to:
  /// **'(no caption)'**
  String get adminContentNoCaption;

  /// No description provided for @adminContentFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminContentFilterAll;

  /// No description provided for @adminContentFilterReported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get adminContentFilterReported;

  /// No description provided for @adminContentFilterUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get adminContentFilterUnderReview;

  /// No description provided for @adminContentFilterRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get adminContentFilterRemoved;

  /// No description provided for @adminContentFilterCustomers.
  ///
  /// In en, this message translates to:
  /// **'From shoppers'**
  String get adminContentFilterCustomers;

  /// No description provided for @adminContentFilterSellers.
  ///
  /// In en, this message translates to:
  /// **'From boutiques'**
  String get adminContentFilterSellers;

  /// No description provided for @adminContentStateActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminContentStateActive;

  /// No description provided for @adminContentStateRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get adminContentStateRemoved;

  /// No description provided for @adminContentRemovedFor.
  ///
  /// In en, this message translates to:
  /// **'Removed for: {reason}'**
  String adminContentRemovedFor(String reason);

  /// No description provided for @adminContentRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this post'**
  String get adminContentRemoveTitle;

  /// No description provided for @adminContentRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The author receives a message with the reason you write here, so write it clearly and respectfully.'**
  String get adminContentRemoveBody;

  /// No description provided for @adminContentRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminContentRemoveConfirm;

  /// No description provided for @adminContentReinstateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reinstate this post'**
  String get adminContentReinstateTitle;

  /// No description provided for @adminContentReinstateBody.
  ///
  /// In en, this message translates to:
  /// **'Record why it is going back up.'**
  String get adminContentReinstateBody;

  /// No description provided for @adminContentReinstateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reinstate'**
  String get adminContentReinstateConfirm;

  /// No description provided for @adminContentReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminContentReasonLabel;

  /// No description provided for @adminContentReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. The photo does not meet our content policy…'**
  String get adminContentReasonHint;

  /// No description provided for @adminContentReasonTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write a clear reason (at least 10 characters)'**
  String get adminContentReasonTooShort;

  /// Title of the confirmation shown when a back gesture would abandon a half-filled form
  ///
  /// In en, this message translates to:
  /// **'Discard what you have written?'**
  String get discardChangesTitle;

  /// Body of the discard-changes confirmation
  ///
  /// In en, this message translates to:
  /// **'Leaving now throws away everything on this screen.'**
  String get discardChangesBody;

  /// Destructive action of the discard-changes confirmation
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChangesConfirm;

  /// Cancel action of the discard-changes confirmation
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get discardChangesKeep;

  /// Post menu: hide this one post from her feeds.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get postMenuNotInterested;

  /// No description provided for @postMenuNotInterestedDone.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see this post again.'**
  String get postMenuNotInterestedDone;

  /// Post menu: mute the author quietly.
  ///
  /// In en, this message translates to:
  /// **'Hide posts from {name}'**
  String postMenuMuteAuthor(String name);

  /// No description provided for @postMenuMuteAuthorDone.
  ///
  /// In en, this message translates to:
  /// **'Posts from {name} are hidden.'**
  String postMenuMuteAuthorDone(String name);

  /// No description provided for @postMenuReport.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get postMenuReport;

  /// No description provided for @productMenuReport.
  ///
  /// In en, this message translates to:
  /// **'Report this piece'**
  String get productMenuReport;

  /// No description provided for @postMenuCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get postMenuCopyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @postMenuViewAuthor.
  ///
  /// In en, this message translates to:
  /// **'Visit {name}\'s page'**
  String postMenuViewAuthor(String name);

  /// No description provided for @postMenuViewProduct.
  ///
  /// In en, this message translates to:
  /// **'View the piece'**
  String get postMenuViewProduct;

  /// No description provided for @postMenuRemoveFromMyPage.
  ///
  /// In en, this message translates to:
  /// **'Remove from my page'**
  String get postMenuRemoveFromMyPage;

  /// No description provided for @postMenuSave.
  ///
  /// In en, this message translates to:
  /// **'Save to favourites'**
  String get postMenuSave;

  /// No description provided for @postMenuUnsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get postMenuUnsave;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reports are private — nobody is told who sent one.'**
  String get reportSubtitle;

  /// No description provided for @reportReasonImmodest.
  ///
  /// In en, this message translates to:
  /// **'Immodest content'**
  String get reportReasonImmodest;

  /// No description provided for @reportReasonNotTheProduct.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t match the piece'**
  String get reportReasonNotTheProduct;

  /// No description provided for @reportReasonStolenPhoto.
  ///
  /// In en, this message translates to:
  /// **'Stolen photo'**
  String get reportReasonStolenPhoto;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or annoying'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or abuse'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonCounterfeit.
  ///
  /// In en, this message translates to:
  /// **'Counterfeit'**
  String get reportReasonCounterfeit;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you — our team will look at it.'**
  String get reportSent;

  /// No description provided for @productPickedDone.
  ///
  /// In en, this message translates to:
  /// **'Added to your page'**
  String get productPickedDone;

  /// No description provided for @productPickedPrivate.
  ///
  /// In en, this message translates to:
  /// **'Added — your page is private, so only you can see it.'**
  String get productPickedPrivate;

  /// No description provided for @productUnpickedDone.
  ///
  /// In en, this message translates to:
  /// **'Removed from your page'**
  String get productUnpickedDone;

  /// No description provided for @viewMyPage.
  ///
  /// In en, this message translates to:
  /// **'View my page'**
  String get viewMyPage;

  /// No description provided for @productPicksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added it to their page'**
  String productPicksCount(String count);

  /// No description provided for @profileTabReels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get profileTabReels;

  /// No description provided for @profileTabPicks.
  ///
  /// In en, this message translates to:
  /// **'Picks'**
  String get profileTabPicks;

  /// No description provided for @profileTabMyPicks.
  ///
  /// In en, this message translates to:
  /// **'My picks'**
  String get profileTabMyPicks;

  /// No description provided for @profileTabStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get profileTabStories;

  /// No description provided for @profilePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'This page is private'**
  String get profilePrivateTitle;

  /// No description provided for @profilePrivateBody.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t opened her page to others yet.'**
  String profilePrivateBody(String name);

  /// No description provided for @profileEmptyPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get profileEmptyPosts;

  /// No description provided for @profileEmptyReels.
  ///
  /// In en, this message translates to:
  /// **'No reels yet'**
  String get profileEmptyReels;

  /// No description provided for @profileEmptyStories.
  ///
  /// In en, this message translates to:
  /// **'No live stories right now'**
  String get profileEmptyStories;

  /// No description provided for @profileEmptyPicks.
  ///
  /// In en, this message translates to:
  /// **'Nothing added to this page yet'**
  String get profileEmptyPicks;

  /// No description provided for @profileEmptyPicksMine.
  ///
  /// In en, this message translates to:
  /// **'Tap «Add to my page» on any piece to show it here.'**
  String get profileEmptyPicksMine;

  /// No description provided for @profileEmptyPostsMine.
  ///
  /// In en, this message translates to:
  /// **'Share your first post, reel or story.'**
  String get profileEmptyPostsMine;

  /// No description provided for @myPageTitle.
  ///
  /// In en, this message translates to:
  /// **'My page'**
  String get myPageTitle;

  /// No description provided for @myPagePublicBody.
  ///
  /// In en, this message translates to:
  /// **'Your page is public — anyone can see your posts, reels and picks.'**
  String get myPagePublicBody;

  /// No description provided for @myPagePrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Your page is private — only you can see it.'**
  String get myPagePrivateBody;

  /// No description provided for @myPagePublicToggle.
  ///
  /// In en, this message translates to:
  /// **'Public page'**
  String get myPagePublicToggle;

  /// No description provided for @myPageMadePublic.
  ///
  /// In en, this message translates to:
  /// **'Your page is now public'**
  String get myPageMadePublic;

  /// No description provided for @myPageMadePrivate.
  ///
  /// In en, this message translates to:
  /// **'Your page is now private'**
  String get myPageMadePrivate;

  /// No description provided for @createSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to share?'**
  String get createSheetTitle;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get createPost;

  /// No description provided for @createPostHint.
  ///
  /// In en, this message translates to:
  /// **'Photos, a look, a piece you love'**
  String get createPostHint;

  /// No description provided for @createReel.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get createReel;

  /// No description provided for @createReelHint.
  ///
  /// In en, this message translates to:
  /// **'A short video, up to 30 seconds'**
  String get createReelHint;

  /// No description provided for @createStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get createStory;

  /// No description provided for @createStoryHint.
  ///
  /// In en, this message translates to:
  /// **'Gone in 24 hours'**
  String get createStoryHint;

  /// No description provided for @createTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createTooltip;

  /// No description provided for @createBrowseCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get createBrowseCommunity;

  /// No description provided for @createBrowseReels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get createBrowseReels;

  /// No description provided for @searchTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchTabAll;

  /// No description provided for @searchTabProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get searchTabProducts;

  /// No description provided for @searchTabBoutiques.
  ///
  /// In en, this message translates to:
  /// **'Boutiques'**
  String get searchTabBoutiques;

  /// No description provided for @searchTabShoppers.
  ///
  /// In en, this message translates to:
  /// **'Shoppers'**
  String get searchTabShoppers;

  /// No description provided for @searchTabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get searchTabPosts;

  /// No description provided for @searchNoResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for \"{query}\". Try another word.'**
  String searchNoResultsFor(String query);

  /// No description provided for @searchFollowersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} followers'**
  String searchFollowersCount(String count);

  /// No description provided for @postMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get postMenuDelete;

  /// No description provided for @postDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get postDeleteTitle;

  /// No description provided for @postDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears from your page and from every page it was added to. This can\'t be undone.'**
  String get postDeleteBody;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeleted;

  /// No description provided for @policiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Policies and terms'**
  String get policiesTitle;

  /// No description provided for @policiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The documents that govern your use of Ohara'**
  String get policiesSubtitle;

  /// No description provided for @policiesSectionForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get policiesSectionForYou;

  /// No description provided for @policiesSectionEveryone.
  ///
  /// In en, this message translates to:
  /// **'For everyone'**
  String get policiesSectionEveryone;

  /// No description provided for @policiesSectionSellers.
  ///
  /// In en, this message translates to:
  /// **'For sellers'**
  String get policiesSectionSellers;

  /// No description provided for @policiesSectionCustomers.
  ///
  /// In en, this message translates to:
  /// **'For shoppers'**
  String get policiesSectionCustomers;

  /// No description provided for @policiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No policies have been published yet'**
  String get policiesEmpty;

  /// No description provided for @policiesVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String policiesVersionLabel(String version);

  /// No description provided for @policiesEffectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'In force since {date}'**
  String policiesEffectiveFrom(String date);

  /// No description provided for @policiesAcceptedOn.
  ///
  /// In en, this message translates to:
  /// **'You accepted this on {date}'**
  String policiesAcceptedOn(String date);

  /// No description provided for @policiesAcceptedOlderVersion.
  ///
  /// In en, this message translates to:
  /// **'You accepted version {version} on {date}'**
  String policiesAcceptedOlderVersion(String version, String date);

  /// No description provided for @policiesNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted yet'**
  String get policiesNotAccepted;

  /// No description provided for @policiesRequiredBadge.
  ///
  /// In en, this message translates to:
  /// **'Signature required'**
  String get policiesRequiredBadge;

  /// No description provided for @policiesUpdatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get policiesUpdatedBadge;

  /// No description provided for @policiesMyConsents.
  ///
  /// In en, this message translates to:
  /// **'What I have agreed to'**
  String get policiesMyConsents;

  /// No description provided for @policiesMyConsentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every policy you accepted, and the day you accepted it'**
  String get policiesMyConsentsSubtitle;

  /// No description provided for @policiesReceiptsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not accepted any policy yet'**
  String get policiesReceiptsEmpty;

  /// No description provided for @policiesSourceRegistration.
  ///
  /// In en, this message translates to:
  /// **'At sign-up'**
  String get policiesSourceRegistration;

  /// No description provided for @policiesSourceReconsent.
  ///
  /// In en, this message translates to:
  /// **'After an update'**
  String get policiesSourceReconsent;

  /// No description provided for @policiesSourceSellerApplication.
  ///
  /// In en, this message translates to:
  /// **'When applying to sell'**
  String get policiesSourceSellerApplication;

  /// No description provided for @policiesHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get policiesHistoryTitle;

  /// No description provided for @policiesHistoryCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get policiesHistoryCurrent;

  /// No description provided for @policiesOpenVersion.
  ///
  /// In en, this message translates to:
  /// **'Read this version'**
  String get policiesOpenVersion;

  /// No description provided for @policiesArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'You are reading version {version}, which is no longer the current one.'**
  String policiesArchivedNotice(String version);

  /// No description provided for @policiesReadCurrent.
  ///
  /// In en, this message translates to:
  /// **'Read the current version'**
  String get policiesReadCurrent;

  /// No description provided for @policiesConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you carry on'**
  String get policiesConsentTitle;

  /// No description provided for @policiesConsentIntroNew.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept the following to keep using Ohara.'**
  String get policiesConsentIntroNew;

  /// No description provided for @policiesConsentIntroUpdated.
  ///
  /// In en, this message translates to:
  /// **'We have updated the following. Please read and accept them to carry on.'**
  String get policiesConsentIntroUpdated;

  /// No description provided for @policiesConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the documents above'**
  String get policiesConsentAgree;

  /// No description provided for @policiesConsentContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get policiesConsentContinue;

  /// No description provided for @policiesConsentFailed.
  ///
  /// In en, this message translates to:
  /// **'Your acceptance could not be recorded. Please try again.'**
  String get policiesConsentFailed;

  /// No description provided for @policiesConsentSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out instead'**
  String get policiesConsentSignOut;

  /// No description provided for @policiesConsentTapToRead.
  ///
  /// In en, this message translates to:
  /// **'Tap to read'**
  String get policiesConsentTapToRead;

  /// No description provided for @policiesConsentRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get policiesConsentRead;

  /// No description provided for @registerConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you accept:'**
  String get registerConsentIntro;

  /// No description provided for @registerConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the documents above'**
  String get registerConsentAgree;

  /// No description provided for @registerConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms and the privacy policy to create an account'**
  String get registerConsentRequired;

  /// No description provided for @sellerConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'By applying to sell you accept:'**
  String get sellerConsentIntro;

  /// No description provided for @sellerConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the documents above'**
  String get sellerConsentAgree;

  /// No description provided for @sellerConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the seller terms and the commissions policy to apply'**
  String get sellerConsentRequired;

  /// No description provided for @policiesLinkReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns and exchanges policy'**
  String get policiesLinkReturns;

  /// No description provided for @policiesLinkContent.
  ///
  /// In en, this message translates to:
  /// **'Content and removal policy'**
  String get policiesLinkContent;

  /// No description provided for @policiesLinkDisputes.
  ///
  /// In en, this message translates to:
  /// **'Complaints and disputes'**
  String get policiesLinkDisputes;

  /// No description provided for @checkoutPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'Placing this order means you accept the customer terms and the returns policy.'**
  String get checkoutPolicyNotice;

  /// No description provided for @adminPolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get adminPolicies;

  /// No description provided for @adminPoliciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit and publish the platform\'s policies. No app release needed.'**
  String get adminPoliciesSubtitle;

  /// No description provided for @adminPolicyStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminPolicyStatusDraft;

  /// No description provided for @adminPolicyStatusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPolicyStatusPublished;

  /// No description provided for @adminPolicyStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminPolicyStatusArchived;

  /// No description provided for @adminPolicyAudience.
  ///
  /// In en, this message translates to:
  /// **'Who must accept'**
  String get adminPolicyAudience;

  /// No description provided for @adminPolicyAudienceEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get adminPolicyAudienceEveryone;

  /// No description provided for @adminPolicyAudienceCustomer.
  ///
  /// In en, this message translates to:
  /// **'Shoppers'**
  String get adminPolicyAudienceCustomer;

  /// No description provided for @adminPolicyAudienceSeller.
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get adminPolicyAudienceSeller;

  /// No description provided for @adminPolicyRequiredForConsent.
  ///
  /// In en, this message translates to:
  /// **'Required at sign-up'**
  String get adminPolicyRequiredForConsent;

  /// No description provided for @adminPolicyVisible.
  ///
  /// In en, this message translates to:
  /// **'Shown in the app'**
  String get adminPolicyVisible;

  /// No description provided for @adminPolicyNewDraft.
  ///
  /// In en, this message translates to:
  /// **'New draft'**
  String get adminPolicyNewDraft;

  /// No description provided for @adminPolicyEditDraft.
  ///
  /// In en, this message translates to:
  /// **'Edit draft'**
  String get adminPolicyEditDraft;

  /// No description provided for @adminPolicyDiscardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get adminPolicyDiscardDraft;

  /// No description provided for @adminPolicyDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard this draft? Its text is not kept.'**
  String get adminPolicyDiscardConfirm;

  /// No description provided for @adminPolicyPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get adminPolicyPublish;

  /// No description provided for @adminPolicyPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish version {version}'**
  String adminPolicyPublishTitle(String version);

  /// No description provided for @adminPolicyRequiresReacceptance.
  ///
  /// In en, this message translates to:
  /// **'Ask everyone to accept again'**
  String get adminPolicyRequiresReacceptance;

  /// No description provided for @adminPolicyRequiresReacceptanceHint.
  ///
  /// In en, this message translates to:
  /// **'Turn this on only for a material change. Everyone it applies to is asked to sign again before they can carry on using the app.'**
  String get adminPolicyRequiresReacceptanceHint;

  /// No description provided for @adminPolicyChangeNote.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get adminPolicyChangeNote;

  /// No description provided for @adminPolicyChangeNoteHint.
  ///
  /// In en, this message translates to:
  /// **'One line, shown in the version history'**
  String get adminPolicyChangeNoteHint;

  /// No description provided for @adminPolicyTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminPolicyTitleField;

  /// No description provided for @adminPolicySummaryField.
  ///
  /// In en, this message translates to:
  /// **'One-line summary'**
  String get adminPolicySummaryField;

  /// No description provided for @adminPolicyBodyField.
  ///
  /// In en, this message translates to:
  /// **'The text'**
  String get adminPolicyBodyField;

  /// No description provided for @adminPolicyBodyHint.
  ///
  /// In en, this message translates to:
  /// **'## heading, - bullet, 1. numbered, **bold**, --- rule'**
  String get adminPolicyBodyHint;

  /// No description provided for @adminPolicyLocaleArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic (binding)'**
  String get adminPolicyLocaleArabic;

  /// No description provided for @adminPolicyLocaleEnglish.
  ///
  /// In en, this message translates to:
  /// **'English (courtesy)'**
  String get adminPolicyLocaleEnglish;

  /// No description provided for @adminPolicySaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get adminPolicySaved;

  /// No description provided for @adminPolicyPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPolicyPublished;

  /// No description provided for @adminPolicyDraftCreated.
  ///
  /// In en, this message translates to:
  /// **'Draft opened'**
  String get adminPolicyDraftCreated;

  /// No description provided for @adminPolicyDraftDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Draft discarded'**
  String get adminPolicyDraftDiscarded;

  /// No description provided for @adminPolicyPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get adminPolicyPreview;

  /// No description provided for @adminPolicyConsentSummary.
  ///
  /// In en, this message translates to:
  /// **'Acceptances'**
  String get adminPolicyConsentSummary;

  /// No description provided for @adminPolicyAcceptedCurrent.
  ///
  /// In en, this message translates to:
  /// **'{count} on the current version'**
  String adminPolicyAcceptedCurrent(String count);

  /// No description provided for @adminPolicyAcceptedAny.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No account has signed it yet} =1{1 account has signed this policy} other{{count} accounts have signed this policy}}'**
  String adminPolicyAcceptedAny(int count);

  /// No description provided for @adminPolicyNoDraft.
  ///
  /// In en, this message translates to:
  /// **'No open draft. Start one to change the text.'**
  String get adminPolicyNoDraft;

  /// No description provided for @adminPolicyVersionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 version} other{{count} versions}}'**
  String adminPolicyVersionsCount(int count);

  /// No description provided for @adminPolicyBodyTooShort.
  ///
  /// In en, this message translates to:
  /// **'The text is too short to publish'**
  String get adminPolicyBodyTooShort;

  /// No description provided for @adminPolicyPublishConfirm.
  ///
  /// In en, this message translates to:
  /// **'Publish this version? The current one is archived and cannot be restored — a change after this needs a new version.'**
  String get adminPolicyPublishConfirm;

  /// No description provided for @policiesLinkCommissions.
  ///
  /// In en, this message translates to:
  /// **'Commissions policy'**
  String get policiesLinkCommissions;

  /// No description provided for @policiesLinkCustomerTerms.
  ///
  /// In en, this message translates to:
  /// **'Customer terms of use'**
  String get policiesLinkCustomerTerms;

  /// No description provided for @composerPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'Publishing means you accept the content and removal policy.'**
  String get composerPolicyNotice;

  /// No description provided for @sellerEarningsPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'How the commission is calculated, and when your earnings are paid.'**
  String get sellerEarningsPolicyNotice;

  /// No description provided for @orderPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'A problem with this order? Start with the seller, then the complaints process.'**
  String get orderPolicyNotice;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add a piece'**
  String get closetAddPiece;

  ///
  ///
  /// In en, this message translates to:
  /// **'This page couldn’t open.'**
  String get closetPageLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'The photo is private — no one but you can see it.'**
  String get closetPhotoPrivate;

  ///
  ///
  /// In en, this message translates to:
  /// **'Photo of the piece'**
  String get closetPiecePhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'What is it?'**
  String get closetPieceWhat;

  ///
  ///
  /// In en, this message translates to:
  /// **'e.g. black leather jacket'**
  String get closetPieceWhatHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Type of piece'**
  String get closetPieceSlot;

  ///
  ///
  /// In en, this message translates to:
  /// **'Brand (optional)'**
  String get closetPieceBrandOptional;

  ///
  ///
  /// In en, this message translates to:
  /// **'Size (optional)'**
  String get closetPieceSizeOptional;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add to my closet'**
  String get closetAddToMyCloset;

  ///
  ///
  /// In en, this message translates to:
  /// **'Added to your closet.'**
  String get closetAdded;

  ///
  ///
  /// In en, this message translates to:
  /// **'The piece couldn’t be added.'**
  String get closetAddFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'The missing piece'**
  String get closetGapTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Suggestions couldn’t load.'**
  String get closetSuggestionsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Why this suggestion?'**
  String get closetWhySuggestion;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get closetNotInterested;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing fits right now'**
  String get closetNoMatchNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try again later — boutiques add new pieces every day.'**
  String get closetNoMatchNowBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces that suit your closet'**
  String get closetPiecesThatFit;

  ///
  ///
  /// In en, this message translates to:
  /// **'Got it — we won’t suggest it again.'**
  String get closetGapDismissed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Completes a look'**
  String get closetCompletesLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Goes with a piece you own} other{Goes with {count} pieces you own}}'**
  String closetPairsWithCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'A piece from my closet'**
  String get closetPieceTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get closetRemoveFavourite;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get closetAddFavourite;

  ///
  ///
  /// In en, this message translates to:
  /// **'The piece couldn’t open.'**
  String get closetPieceLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Times worn'**
  String get closetTimesWorn;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cost per wear'**
  String get closetCostPerWear;

  ///
  ///
  /// In en, this message translates to:
  /// **'Last worn'**
  String get closetLastWorn;

  ///
  ///
  /// In en, this message translates to:
  /// **'Wore it today'**
  String get closetWoreToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get closetDetails;

  ///
  ///
  /// In en, this message translates to:
  /// **'Size {size}'**
  String closetSizeValue(String size);

  ///
  ///
  /// In en, this message translates to:
  /// **'Suits'**
  String get closetSuitsLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'View in the boutique'**
  String get closetViewInShop;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get closetDeleteForever;

  ///
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get closetWornNever;

  ///
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get closetWornToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get closetWornYesterday;

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{a day ago} other{{days} days ago}}'**
  String closetWornDaysAgo(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{a month ago} other{{months} months ago}}'**
  String closetWornMonthsAgo(int months);

  ///
  ///
  /// In en, this message translates to:
  /// **'Back to the closet'**
  String get closetReturnToCloset;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shelve for the season'**
  String get closetShelveForSeason;

  ///
  ///
  /// In en, this message translates to:
  /// **'I no longer have it'**
  String get closetNoLongerOwn;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look'**
  String get closetLookTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look couldn’t open.'**
  String get closetLookLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'One piece ({slot}) and it’s ready.'**
  String closetLookOneShort(String slot);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} pieces short of ready.}}'**
  String closetLookManyShort(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Worn once.} other{Worn {count} times.}}'**
  String closetLookWornCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete the look'**
  String get closetDeleteLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not yours yet'**
  String get closetNotOwnedYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'Find the piece'**
  String get closetFindThePiece;

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove from the look'**
  String get closetRemoveFromLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'My looks'**
  String get closetMyLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your looks couldn’t load.'**
  String get closetLooksLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No looks yet'**
  String get closetNoLooksTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Put a look together from your pieces — if something’s missing, we’ll help you find it.'**
  String get closetNoLooksBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'See what you can wear'**
  String get closetSeeWhatToWear;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ready · worn once} other{Ready · worn {count} times}}'**
  String closetLookReadyWorn(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Ready to wear'**
  String get closetLookReady;

  ///
  ///
  /// In en, this message translates to:
  /// **'Wore it'**
  String get closetWoreIt;

  ///
  ///
  /// In en, this message translates to:
  /// **'Needs {slot} to be ready'**
  String closetLookShortOne(String slot);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} pieces short}}'**
  String closetLookShortMany(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get closetMissing;

  ///
  ///
  /// In en, this message translates to:
  /// **'What should I wear today?'**
  String get closetWhatToWearToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'We couldn’t suggest anything right now.'**
  String get closetTodayFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Done — logged for today.'**
  String get closetTodayLogged;

  ///
  ///
  /// In en, this message translates to:
  /// **'Saved to your looks.'**
  String get closetSavedToLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look couldn’t be saved.'**
  String get closetSaveLookFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Any occasion'**
  String get closetAnyOccasion;

  ///
  ///
  /// In en, this message translates to:
  /// **'No outfit could be made'**
  String get closetCannotDress;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing for this occasion'**
  String get closetNothingForOccasion;

  ///
  ///
  /// In en, this message translates to:
  /// **'You’re probably missing a whole category — try adding shoes or a bottom to your closet.'**
  String get closetCannotDressBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try removing the occasion filter, or add a piece that suits it.'**
  String get closetNothingForOccasionBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your closet couldn’t open.'**
  String get closetLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Want'**
  String get closetSpectrumWant;

  ///
  ///
  /// In en, this message translates to:
  /// **'Deciding'**
  String get closetSpectrumDeciding;

  ///
  ///
  /// In en, this message translates to:
  /// **'Own'**
  String get closetSpectrumOwn;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your closet is empty'**
  String get closetEmptyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add your pieces — what you bought on Ohara and what you already had. That’s how we learn what you’re missing and what you can wear.'**
  String get closetEmptyBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Bring in my purchases'**
  String get closetBringPurchases;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add a piece with a photo'**
  String get closetAddWithPhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added a piece from your orders.} other{Added {count} pieces from your orders.}}'**
  String closetBackfilled(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'No delivered orders yet.'**
  String get closetNoDeliveredOrders;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your purchases couldn’t be fetched right now.'**
  String get closetBackfillFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your pieces couldn’t be shown.'**
  String get closetItemsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'possible looks'**
  String get closetMetricPossibleLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'pieces'**
  String get closetMetricPieces;

  ///
  ///
  /// In en, this message translates to:
  /// **'saved looks'**
  String get closetMetricSavedLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'wears this month'**
  String get closetMetricWornThisMonth;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your pieces are here, but they don’t make a full outfit for this weather.'**
  String get closetCannotDressSeason;

  ///
  ///
  /// In en, this message translates to:
  /// **'You have {total} looks in all; {seasonal} suit {season}.'**
  String closetSeasonCapacity(int total, int seasonal, String season);

  ///
  ///
  /// In en, this message translates to:
  /// **'What your closet is missing'**
  String get closetWhatsMissing;

  ///
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get closetAll;

  ///
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get closetReasonBase;

  ///
  ///
  /// In en, this message translates to:
  /// **'One piece short'**
  String get closetReasonNearlyComplete;

  ///
  ///
  /// In en, this message translates to:
  /// **'A favourite look'**
  String get closetReasonFavouriteLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'Core piece for the occasion'**
  String get closetReasonCoreSlot;

  ///
  ///
  /// In en, this message translates to:
  /// **'You chose this piece before'**
  String get closetReasonAlreadyChosen;

  ///
  ///
  /// In en, this message translates to:
  /// **'Right for the season'**
  String get closetReasonSeasonFit;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your interest in the occasion'**
  String get closetReasonInterest;

  ///
  ///
  /// In en, this message translates to:
  /// **'The anchor piece'**
  String get closetReasonAnchorSlot;

  ///
  ///
  /// In en, this message translates to:
  /// **'You don’t own any'**
  String get closetReasonOwnsNone;

  ///
  ///
  /// In en, this message translates to:
  /// **'New looks unlocked'**
  String get closetReasonOutfitGain;

  ///
  ///
  /// In en, this message translates to:
  /// **'First complete look'**
  String get closetReasonFirstOutfit;

  ///
  ///
  /// In en, this message translates to:
  /// **'Looks unlocked'**
  String get closetReasonOutfitsUnlocked;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your complete looks now'**
  String get closetReasonOutfitsNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shelved pieces'**
  String get closetReasonShelved;

  ///
  ///
  /// In en, this message translates to:
  /// **'Out-of-season pieces'**
  String get closetReasonOutOfSeason;

  ///
  ///
  /// In en, this message translates to:
  /// **'Heavy wear'**
  String get closetReasonWear;

  ///
  ///
  /// In en, this message translates to:
  /// **'No alternative'**
  String get closetReasonSoleInSlot;

  ///
  ///
  /// In en, this message translates to:
  /// **'Times worn'**
  String get closetReasonWearCount;

  ///
  ///
  /// In en, this message translates to:
  /// **'Why are we suggesting this?'**
  String get closetWhyWeSuggest;

  ///
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get closetPriority;

  ///
  ///
  /// In en, this message translates to:
  /// **'My piece'**
  String get closetMyPiece;

  ///
  ///
  /// In en, this message translates to:
  /// **'{slot} · not worn yet'**
  String closetTileNeverWorn(String slot);

  ///
  ///
  /// In en, this message translates to:
  /// **'{slot} · a while ago'**
  String closetTileLongAgo(String slot);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{slot} · worn once} other{{slot} · worn {count} times}}'**
  String closetTileWornCount(String slot, int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'From your closet'**
  String get closetFromYourCloset;

  ///
  ///
  /// In en, this message translates to:
  /// **'You already have one in your closet.'**
  String get closetOwnOneAlready;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Goes with a piece you own.} other{Goes with {count} pieces you own.}}'**
  String closetPanelPairs(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{And completes a saved look.} other{And completes {count} saved looks.}}'**
  String closetPanelCompletes(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Open my closet'**
  String get closetOpenMyCloset;

  ///
  ///
  /// In en, this message translates to:
  /// **'It couldn’t be added.'**
  String get closetAddPairFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save as a look'**
  String get closetSaveAsLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get roomsCompareTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The comparison couldn’t be prepared.'**
  String get roomsCompareFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing to compare'**
  String get roomsCompareNothing;

  ///
  ///
  /// In en, this message translates to:
  /// **'A comparison needs at least two options.'**
  String get roomsCompareNeedsTwo;

  ///
  ///
  /// In en, this message translates to:
  /// **'Hide what’s the same'**
  String get roomsHideIdentical;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Alike in one thing} other{Alike in {count} things}}'**
  String roomsIdenticalCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The room is split — one vote.} other{The room is split — {count} votes.}}'**
  String roomsVotesSplit(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The room leans one way — one vote.} other{The room leans one way — {count} votes.}}'**
  String roomsVotesLeaning(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String roomsCommentCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Choose this'**
  String get roomsChooseThis;

  ///
  ///
  /// In en, this message translates to:
  /// **'Purchase plan'**
  String get roomsPlanTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The plan couldn’t load.'**
  String get roomsPlanFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get roomsNoPlanTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Settle the room’s decisions and we’ll put the plan together.'**
  String get roomsNoPlanBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get roomsPlanNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing is ready to buy yet.'**
  String get roomsPlanNothingNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get roomsPlanLater;

  ///
  ///
  /// In en, this message translates to:
  /// **'Kept in the plan — buy it when you’re ready.'**
  String get roomsPlanLaterBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get roomsPlanTotal;

  ///
  ///
  /// In en, this message translates to:
  /// **'{amount} over your budget'**
  String roomsOverBudget(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Under your budget'**
  String get roomsUnderBudget;

  ///
  ///
  /// In en, this message translates to:
  /// **'Within your budget'**
  String get roomsWithinBudget;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One piece couldn’t be priced} other{{count} pieces couldn’t be priced}}'**
  String roomsUnpriced(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get roomsNoLongerAvailable;

  ///
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get roomsPostpone;

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get roomsRemove;

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove the pieces that are no longer available before you continue.'**
  String get roomsRemoveUnavailableFirst;

  ///
  ///
  /// In en, this message translates to:
  /// **'Buy what’s ready now ({count})'**
  String roomsBuyNowCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Buy ({count})'**
  String roomsBuyCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomsRoomTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The invitation couldn’t open. The link may have expired — ask for a new one.'**
  String get roomsInviteFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Share the room'**
  String get roomsShareRoom;

  ///
  ///
  /// In en, this message translates to:
  /// **'The room couldn’t open.'**
  String get roomsRoomFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Link copied — anyone who opens it can advise and vote, but not buy.'**
  String get roomsLinkCopied;

  ///
  ///
  /// In en, this message translates to:
  /// **'No decisions yet'**
  String get roomsNoDecisionsTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'A decision is a question — “the dress”, “a gift for Mum”. Add one and start gathering options for it.'**
  String get roomsNoDecisionsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add a decision'**
  String get roomsAddDecision;

  ///
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get roomsSettled;

  ///
  ///
  /// In en, this message translates to:
  /// **'New decision'**
  String get roomsNewDecision;

  ///
  ///
  /// In en, this message translates to:
  /// **'A decision is a question that needs an answer — not a piece.'**
  String get roomsNewDecisionHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'e.g. The dress'**
  String get roomsNewDecisionHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get roomsAdd;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get roomsCancel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Surprise'**
  String get roomsSurprise;

  ///
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String roomsForRecipient(String name);

  ///
  ///
  /// In en, this message translates to:
  /// **'Every decision is settled'**
  String get roomsAllSettled;

  ///
  ///
  /// In en, this message translates to:
  /// **'{settled} of {total} decisions settled'**
  String roomsSettledOf(int settled, int total);

  ///
  ///
  /// In en, this message translates to:
  /// **'Budget: up to {amount}'**
  String roomsBudgetUpTo(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'See the plan'**
  String get roomsSeePlan;

  ///
  ///
  /// In en, this message translates to:
  /// **'Prepare the plan'**
  String get roomsPreparePlan;

  ///
  ///
  /// In en, this message translates to:
  /// **'Some decisions are still open.'**
  String get roomsDecisionsStillOpen;

  ///
  ///
  /// In en, this message translates to:
  /// **'My rooms'**
  String get roomsMyRooms;

  ///
  ///
  /// In en, this message translates to:
  /// **'New room'**
  String get roomsNewRoom;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your rooms couldn’t load.'**
  String get roomsLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No rooms yet'**
  String get roomsEmptyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'A room is a space for a buying decision — a wedding, a gift, a season. Gather options, ask your friends, decide. It isn’t a basket.'**
  String get roomsEmptyBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open your first room'**
  String get roomsOpenFirst;

  ///
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get roomsPurchased;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ready to buy'**
  String get roomsReadyToBuy;

  ///
  ///
  /// In en, this message translates to:
  /// **'One decision to go'**
  String get roomsOneDecisionLeft;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} decisions still open}}'**
  String roomsOpenDecisions(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No suggestions} =1{1 suggestion} other{{count} suggestions}}'**
  String roomsSuggestionCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get roomsOccasionWedding;

  ///
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get roomsOccasionEngagement;

  ///
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get roomsOccasionEvening;

  ///
  ///
  /// In en, this message translates to:
  /// **'Eid'**
  String get roomsOccasionEid;

  ///
  ///
  /// In en, this message translates to:
  /// **'Graduation'**
  String get roomsOccasionGraduation;

  ///
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get roomsOccasionBirthday;

  ///
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get roomsOccasionWork;

  ///
  ///
  /// In en, this message translates to:
  /// **'Everyday'**
  String get roomsOccasionDaily;

  ///
  ///
  /// In en, this message translates to:
  /// **'What are you shopping for?'**
  String get roomsShoppingFor;

  ///
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomsRoomName;

  ///
  ///
  /// In en, this message translates to:
  /// **'e.g. Rahaf’s wedding look'**
  String get roomsRoomNameHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Room type'**
  String get roomsRoomKind;

  ///
  ///
  /// In en, this message translates to:
  /// **'Who is the gift for?'**
  String get roomsGiftFor;

  ///
  ///
  /// In en, this message translates to:
  /// **'Occasion (optional)'**
  String get roomsOccasionOptional;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pick an occasion and we’ll open the decisions you’ll need.'**
  String get roomsOccasionHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open the room'**
  String get roomsOpenRoom;

  ///
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get roomsSuggestion;

  ///
  ///
  /// In en, this message translates to:
  /// **'You decided against it'**
  String get roomsDecidedAgainst;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Needs one piece} other{Needs {count} pieces}}'**
  String roomsNeedsPieces(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Opinions are split'**
  String get roomsOpinionsSplit;

  ///
  ///
  /// In en, this message translates to:
  /// **'Most lean one way'**
  String get roomsMajorityLeans;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get roomsAddOption;

  ///
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get roomsCompare;

  ///
  ///
  /// In en, this message translates to:
  /// **'I don’t want any'**
  String get roomsWantNothing;

  ///
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get roomsStatusSettled;

  ///
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get roomsStatusSkipped;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet'**
  String get roomsStatusNotChosen;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get roomsStatusOpen;

  ///
  ///
  /// In en, this message translates to:
  /// **'No options for this question'**
  String get roomsNoOptions;

  ///
  ///
  /// In en, this message translates to:
  /// **'Find a piece'**
  String get roomsFindPiece;

  ///
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get roomsDone;

  ///
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get roomsRestore;

  ///
  ///
  /// In en, this message translates to:
  /// **'Proposed for “{title}”'**
  String roomsProposedTo(String title);

  ///
  ///
  /// In en, this message translates to:
  /// **'It couldn’t be proposed.'**
  String get roomsProposeFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Which room?'**
  String get roomsWhichRoom;

  ///
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get roomsBack;

  ///
  ///
  /// In en, this message translates to:
  /// **'An answer to which question?'**
  String get roomsAnswerWhichQuestion;

  ///
  ///
  /// In en, this message translates to:
  /// **'The piece is added as a suggestion — nothing is bought until you choose it.'**
  String get roomsProposeHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No suggestions} =1{1 suggestion} other{{count} suggestions}}'**
  String roomsLiveSuggestionCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'New question'**
  String get roomsNewQuestion;

  ///
  ///
  /// In en, this message translates to:
  /// **'e.g. The shoes'**
  String get roomsNewQuestionHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'You have no open rooms'**
  String get roomsNoOpenRooms;

  ///
  ///
  /// In en, this message translates to:
  /// **'A room is a space for a buying decision — gather the options and decide.'**
  String get roomsWhatIsRoom;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open a room and add it'**
  String get roomsOpenAndAdd;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get roomsDefaultRoomTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get roomsDefaultDecisionTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'We opened a room for you and put the piece in it.'**
  String get roomsCreatedWithPiece;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'Just me'**
  String get roomsKindSolo;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'With friends'**
  String get roomsKindGroup;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get roomsKindGift;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'Occasion'**
  String get roomsKindOccasion;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'this decision'**
  String get roomsDecisionFallback;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'No decisions in the room yet'**
  String get roomsBlockerNoDecisions;

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'No suggestions for {title} yet'**
  String roomsBlockerEmpty(String title);

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'You haven’t chosen for {title} yet'**
  String roomsBlockerUnresolved(String title);

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'You picked more than needed for {title}'**
  String roomsBlockerOverPick(String title);

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'The piece chosen for {title} sold out'**
  String roomsBlockerUnavailable(String title);

  /// Rooms label.
  ///
  /// In en, this message translates to:
  /// **'Something is still missing'**
  String get roomsBlockerOther;

  ///
  ///
  /// In en, this message translates to:
  /// **'Standing and what it unlocks — and the guarantee it can’t be bought.'**
  String get valueAdminSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get valueAdminRefresh;

  ///
  ///
  /// In en, this message translates to:
  /// **'Gather evidence now'**
  String get valueAdminSweepNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Standing data couldn’t load.'**
  String get valueAdminDistributionFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Done — no profiles changed.} =1{Done — one profile recalculated.} other{Done — {count} profiles recalculated.}}'**
  String valueAdminSweepDone(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Gathering evidence failed.'**
  String get valueAdminSweepFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Standing can’t be bought'**
  String get valueAdminGuaranteeHolds;

  ///
  ///
  /// In en, this message translates to:
  /// **'Warning: spending alone now reaches the top tiers'**
  String get valueAdminGuaranteeBroken;

  ///
  ///
  /// In en, this message translates to:
  /// **'Someone who only buys and contributes nothing else reaches {ceiling} of 1000'**
  String valueAdminSpendingReach(int ceiling);

  ///
  ///
  /// In en, this message translates to:
  /// **'Lower the spending ceiling or raise the top-tier thresholds — otherwise the programme becomes a spending ladder by another name.'**
  String get valueAdminGuaranteeFix;

  ///
  ///
  /// In en, this message translates to:
  /// **'Tier distribution'**
  String get valueAdminDistributionTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{1 profile} other{{total} profiles}} — {unranked, plural, =0{all ranked} other{{unranked} not ranked yet}}'**
  String valueAdminDistributionSubtitle(int total, int unranked);

  ///
  ///
  /// In en, this message translates to:
  /// **'Cost and commitment'**
  String get valueAdminCostTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'What was actually spent, and the most that could be.'**
  String get valueAdminCostSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The cost report couldn’t load.'**
  String get valueAdminCostFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One benefit spends money with no ceiling — give it a budget.} other{{count} benefits spend money with no ceiling — give them a budget.}}'**
  String valueAdminUnbounded(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get valueAdminSpent;

  ///
  ///
  /// In en, this message translates to:
  /// **'Maximum commitment'**
  String get valueAdminMaxCommitment;

  ///
  ///
  /// In en, this message translates to:
  /// **'All standing from a single source'**
  String get valueAdminReasonSinglePillar;

  ///
  ///
  /// In en, this message translates to:
  /// **'Heavy contributions over a few days'**
  String get valueAdminReasonBurst;

  ///
  ///
  /// In en, this message translates to:
  /// **'Profiles worth a look'**
  String get valueAdminSuspectsTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not an accusation — unusual patterns, and a person decides.'**
  String get valueAdminSuspectsSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The list couldn’t load.'**
  String get valueAdminSuspectsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing stands out right now.'**
  String get valueAdminSuspectsNone;

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{{percent}% concentrated over 1 day} other{{percent}% concentrated over {days} days}}'**
  String valueAdminConcentration(int percent, int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'Freeze for now'**
  String get valueAdminFreezeAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Temporary freeze'**
  String get valueAdminFreezeTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Standing stops moving and benefits pause — nothing is lost. It all returns when you lift the freeze.'**
  String get valueAdminFreezeBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get valueAdminFreezeReason;

  ///
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get valueAdminFreezeConfirm;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get valueCancel;

  ///
  ///
  /// In en, this message translates to:
  /// **'My standing in Ohara'**
  String get valueTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your standing couldn’t load.'**
  String get valueLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Where your standing comes from'**
  String get valueSourcesTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your standing rests on six sides, not on spending alone.'**
  String get valueSourcesSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'What brings you closer to {tier}'**
  String valueCloserTo(String tier);

  ///
  ///
  /// In en, this message translates to:
  /// **'What your standing unlocks'**
  String get valueUnlocksTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Latest we counted'**
  String get valueRecentTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Just starting'**
  String get valueJustStarting;

  ///
  ///
  /// In en, this message translates to:
  /// **'Next tier: {tier}'**
  String valueNextTier(String tier);

  ///
  ///
  /// In en, this message translates to:
  /// **'The highest standing you reached is kept on record.'**
  String get valuePeakKept;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your tier is held for you even if things go quiet for a while.'**
  String get valueTierHeld;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your standing is paused for review — nothing has been lost.'**
  String get valueFrozen;

  ///
  ///
  /// In en, this message translates to:
  /// **'It’s yours.'**
  String get valueBenefitClaimed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Unlocks at a higher tier'**
  String get valueBenefitHigherTier;

  ///
  ///
  /// In en, this message translates to:
  /// **'Taken this period'**
  String get valueBenefitTakenThisPeriod;

  ///
  ///
  /// In en, this message translates to:
  /// **'Gone for this period'**
  String get valueBenefitSoldOut;

  ///
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get valueBenefitClaim;

  ///
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get valueBenefitActive;

  ///
  ///
  /// In en, this message translates to:
  /// **'How is standing built?'**
  String get valueHowBuiltTooltip;

  ///
  ///
  /// In en, this message translates to:
  /// **'The rules couldn’t load.'**
  String get valueRulesFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'How your standing is built'**
  String get valueHowBuiltTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your standing can’t be bought. Buying is one side of six, and it’s capped — someone who only buys never reaches the top tiers.'**
  String get valueHowBuiltBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'At the cap'**
  String get valuePillarCapped;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not known yet'**
  String get valuePillarUnknown;

  ///
  ///
  /// In en, this message translates to:
  /// **'{blurb} — not enough yet to judge.'**
  String valuePillarNotEnough(String blurb);

  ///
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get valuePolicyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Every change becomes a new version — simulated on real profiles before it goes live.'**
  String get valuePolicySubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'New version'**
  String get valuePolicyNewVersion;

  ///
  ///
  /// In en, this message translates to:
  /// **'Policies couldn’t load.'**
  String get valuePolicyLoadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Spending cap {ceiling} · half-life {days}d'**
  String valuePolicyRowSummary(int ceiling, int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get valuePolicySimulate;

  ///
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get valuePolicyActivate;

  ///
  ///
  /// In en, this message translates to:
  /// **'The simulation failed.'**
  String get valuePolicySimulateFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'{down} of {sampled} will drop a tier. That’s a change people will feel — make sure you mean it.'**
  String valuePolicyImpactDisruptive(int down, int sampled);

  ///
  ///
  /// In en, this message translates to:
  /// **'{up} will rise and {down} will drop, out of {sampled}.'**
  String valuePolicyImpact(int up, int down, int sampled);

  ///
  ///
  /// In en, this message translates to:
  /// **'Activate policy'**
  String get valuePolicyActivateTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Every profile will be recalculated under the new rules.\n\n{impact}'**
  String valuePolicyActivateBody(String impact);

  ///
  ///
  /// In en, this message translates to:
  /// **'Policy activated and everything recalculated.'**
  String get valuePolicyActivated;

  ///
  ///
  /// In en, this message translates to:
  /// **'Activation failed.'**
  String get valuePolicyActivateFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Sample of {sampled}: '**
  String valuePolicySimSample(int sampled);

  ///
  ///
  /// In en, this message translates to:
  /// **'Average change {delta}'**
  String valuePolicySimAverage(String delta);

  ///
  ///
  /// In en, this message translates to:
  /// **'Buying'**
  String get valuePillarCommerce;

  ///
  ///
  /// In en, this message translates to:
  /// **'Opinion'**
  String get valuePillarCraft;

  ///
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get valuePillarCommunity;

  ///
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get valuePillarAdvocacy;

  ///
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get valuePillarDiscovery;

  ///
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get valuePillarReliability;

  ///
  ///
  /// In en, this message translates to:
  /// **'New version from v{version}'**
  String valuePolicyNewFrom(int version);

  ///
  ///
  /// In en, this message translates to:
  /// **'Side weights'**
  String get valuePolicyWeights;

  ///
  ///
  /// In en, this message translates to:
  /// **'Relative — they don’t need to add up to 100.'**
  String get valuePolicyWeightsHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'Spending cap'**
  String get valuePolicyCeiling;

  ///
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{1 point} other{{points} points}}'**
  String valuePolicyPoints(int points);

  ///
  ///
  /// In en, this message translates to:
  /// **'Half-life'**
  String get valuePolicyHalfLife;

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String valuePolicyDays(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'Minimum evidence per side'**
  String get valuePolicyMinEvidence;

  ///
  ///
  /// In en, this message translates to:
  /// **'Why this change?'**
  String get valuePolicyWhy;

  ///
  ///
  /// In en, this message translates to:
  /// **'Someone else will read this a year from now'**
  String get valuePolicyWhyHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get valuePolicySaveDraft;

  ///
  ///
  /// In en, this message translates to:
  /// **'Saved as a draft — simulate it before activating.'**
  String get valuePolicySavedDraft;

  ///
  ///
  /// In en, this message translates to:
  /// **'Saving failed.'**
  String get valuePolicySaveFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'With these weights, someone who only buys reaches {ceiling} — into the top tiers.'**
  String valuePolicyRisky(int ceiling);

  ///
  ///
  /// In en, this message translates to:
  /// **'Someone who only buys reaches {ceiling} of 1000 — standing still can’t be bought.'**
  String valuePolicySafe(int ceiling);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your standing in Ohara'**
  String get valueCardTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Close to {tier}'**
  String valueCardCloseTo(String tier);

  ///
  ///
  /// In en, this message translates to:
  /// **'Rising'**
  String get valueCardRising;

  ///
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get valueCardSteady;

  /// Ohara Value console.
  ///
  /// In en, this message translates to:
  /// **' — tier “{rung}”'**
  String valueAdminSpendingRung(String rung);

  /// Ohara Value console.
  ///
  /// In en, this message translates to:
  /// **'; the top tier is “{rung}”.'**
  String valueAdminTopRung(String rung);

  ///
  ///
  /// In en, this message translates to:
  /// **'The look'**
  String get marketLookTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look couldn’t open.'**
  String get marketLookFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{From one shop — Ohara put them together because they go well.} other{From {count} shops — Ohara put them together because they go well.}}'**
  String marketLookFromShops(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'There are cheaper options'**
  String get marketCheaperOptions;

  ///
  ///
  /// In en, this message translates to:
  /// **'Same slot, another piece Ohara sees as close to it.'**
  String get marketCheaperOptionsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Look total'**
  String get marketLookTotal;

  ///
  ///
  /// In en, this message translates to:
  /// **'See the pieces'**
  String get marketSeePieces;

  ///
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String marketFromSeller(String name);

  ///
  ///
  /// In en, this message translates to:
  /// **'Save {amount}'**
  String marketSave(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Instead of {title} — {newPrice} instead of {oldPrice}'**
  String marketInsteadOf(String title, String newPrice, String oldPrice);

  ///
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get marketOccasionWedding;

  ///
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get marketOccasionEvening;

  ///
  ///
  /// In en, this message translates to:
  /// **'Eid'**
  String get marketOccasionEid;

  ///
  ///
  /// In en, this message translates to:
  /// **'Graduation'**
  String get marketOccasionGraduation;

  ///
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get marketOccasionWork;

  ///
  ///
  /// In en, this message translates to:
  /// **'Everyday'**
  String get marketOccasionDaily;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ready looks'**
  String get marketReadyLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get marketAll;

  ///
  ///
  /// In en, this message translates to:
  /// **'Looks couldn’t load.'**
  String get marketLooksFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No ready looks right now'**
  String get marketNoLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'Looks are built from available pieces that go together. Try another occasion or come back later.'**
  String get marketNoLooksBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get marketDrops;

  ///
  ///
  /// In en, this message translates to:
  /// **'Drops couldn’t load.'**
  String get marketDropsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No drop right now'**
  String get marketNoDrops;

  ///
  ///
  /// In en, this message translates to:
  /// **'When something lands that fits what you’re missing or your taste, you’ll see it here before everyone else.'**
  String get marketNoDropsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Live now'**
  String get marketLiveNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Worth doing'**
  String get marketMissionsTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Missions couldn’t load.'**
  String get marketMissionsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing to do right now'**
  String get marketNoMissions;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ohara only asks for something when it’s worth it and within reach.'**
  String get marketNoMissionsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get marketMissionDone;

  ///
  ///
  /// In en, this message translates to:
  /// **'{done} of {target}'**
  String marketMissionProgress(int done, int target);

  ///
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get marketNotNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pre-loved market'**
  String get marketResaleTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'For sale'**
  String get marketResaleBrowse;

  ///
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get marketResaleMine;

  ///
  ///
  /// In en, this message translates to:
  /// **'Listings couldn’t load.'**
  String get marketResaleFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'You have no listings'**
  String get marketNoOwnListings;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing for sale right now'**
  String get marketNoListings;

  ///
  ///
  /// In en, this message translates to:
  /// **'When Ohara finds a piece in your closet that isn’t being worn, she’ll suggest listing it here.'**
  String get marketNoOwnListingsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'The market fills up from other women’s closets. Come back later.'**
  String get marketNoListingsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Never worn} =1{Worn once} other{Worn {count} times}}'**
  String marketWornTimes(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get marketListingPublish;

  ///
  ///
  /// In en, this message translates to:
  /// **'Publish again'**
  String get marketListingRepublish;

  ///
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get marketListingWithdraw;

  ///
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get marketListingSold;

  ///
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get marketSellerTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Opportunities'**
  String get marketOpportunities;

  ///
  ///
  /// In en, this message translates to:
  /// **'Supply against demand in the categories you sell in.'**
  String get marketOpportunitiesBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'The market couldn’t be read.'**
  String get marketReadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No signal strong enough right now. Ohara only speaks when the data is enough.'**
  String get marketNoSignal;

  ///
  ///
  /// In en, this message translates to:
  /// **'Worth a drop'**
  String get marketWorthADrop;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your products with higher demand than usual.'**
  String get marketWorthADropBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Products couldn’t be read.'**
  String get marketProductsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'None of your products needs a special drop right now.'**
  String get marketNoDropCandidates;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your drops'**
  String get marketYourDrops;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your drops couldn’t load.'**
  String get marketYourDropsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'You haven’t launched a drop yet.'**
  String get marketNoOwnDrops;

  ///
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get marketConfidenceHigh;

  ///
  ///
  /// In en, this message translates to:
  /// **'Early'**
  String get marketConfidenceLow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Demand {demand} · stock {stock}'**
  String marketCandidateStats(int demand, int stock);

  ///
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get marketDropAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get marketDropDraft;

  ///
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get marketDropScheduled;

  ///
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get marketDropLive;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get marketDropEnded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get marketDropCancelled;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece · {status}} other{{count} pieces · {status}}}'**
  String marketDropSummary(int count, String status);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your closet after buying'**
  String get marketCareTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your closet couldn’t be read.'**
  String get marketCareFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Everything’s in its place'**
  String get marketCareAllGood;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing needs attention right now. We’ll tell you when a piece goes unworn.'**
  String get marketCareAllGoodBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces that need attention'**
  String get marketCareNeedsAttention;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get marketCarePieces;

  ///
  ///
  /// In en, this message translates to:
  /// **'In rotation'**
  String get marketCareInRotation;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cost per wear (SYP)'**
  String get marketCareCostPerWear;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cost per wear {amount}'**
  String marketCostPerWear(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Goes with: {titles}'**
  String marketGoesWith(String titles);

  ///
  ///
  /// In en, this message translates to:
  /// **'Suggested price {amount}'**
  String marketSuggestedPrice(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'List it for sale'**
  String get marketListForSale;

  ///
  ///
  /// In en, this message translates to:
  /// **'Edit listing'**
  String get marketEditListing;

  ///
  ///
  /// In en, this message translates to:
  /// **'List “{title}”'**
  String marketListTitle(String title);

  ///
  ///
  /// In en, this message translates to:
  /// **'Saved as a draft — no one sees it until you publish it.'**
  String get marketListDraftNote;

  ///
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get marketCondition;

  ///
  ///
  /// In en, this message translates to:
  /// **'New with tags'**
  String get marketConditionNew;

  ///
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get marketConditionExcellent;

  ///
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get marketConditionGood;

  ///
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get marketConditionFair;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get marketSaveDraft;

  ///
  ///
  /// In en, this message translates to:
  /// **'Saved as a draft. You can publish it from your listings.'**
  String get marketSavedDraft;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces from different shops, put together because they go well.'**
  String get marketReadyLooksBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Reading the market…'**
  String get marketReading;

  ///
  ///
  /// In en, this message translates to:
  /// **'No signal strong enough right now.'**
  String get marketNoSignalShort;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One opportunity in your categories, with supply against demand.} other{{count} opportunities in your categories, with supply against demand.}}'**
  String marketOpportunityCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One piece needs attention — care, styling or selling.} other{{count} pieces need attention — care, styling or selling.}}'**
  String marketCareSummary(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{From one shop — a complete look} other{From {count} shops — a complete look}}'**
  String marketLookFromShopsShort(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece} other{{count} pieces}}'**
  String marketPieceCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Early access'**
  String get marketEarlyAccess;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Because you’re missing something like this'**
  String get marketReasonOpenNeed;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Because you were looking for something like it'**
  String get marketReasonSearchedFor;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Because it suits the occasion you’re getting ready for'**
  String get marketReasonOccasion;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Because it’s close to your taste'**
  String get marketReasonTaste;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'From a shop you buy from'**
  String get marketReasonSellerCustomer;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'In rotation'**
  String get marketRotationActive;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Worn less lately'**
  String get marketRotationSlowing;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Sitting in the closet'**
  String get marketRotationDormant;

  /// Market label.
  ///
  /// In en, this message translates to:
  /// **'Never worn'**
  String get marketRotationUnworn;

  ///
  ///
  /// In en, this message translates to:
  /// **'My addresses'**
  String get settingsMyAddresses;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery addresses'**
  String get settingsDeliveryAddresses;

  ///
  ///
  /// In en, this message translates to:
  /// **'Where should we send your orders?'**
  String get settingsDeliveryAddressesSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add a new address'**
  String get settingsAddAddress;

  ///
  ///
  /// In en, this message translates to:
  /// **'Address added'**
  String get settingsAddressAdded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get settingsAddressUpdated;

  ///
  ///
  /// In en, this message translates to:
  /// **'This is now your default address'**
  String get settingsAddressNowDefault;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete address'**
  String get settingsDeleteAddressTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'“{label}” will be removed from your addresses.'**
  String settingsDeleteAddressBody(String label);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  ///
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get settingsKeep;

  ///
  ///
  /// In en, this message translates to:
  /// **'Address deleted'**
  String get settingsAddressDeleted;

  ///
  ///
  /// In en, this message translates to:
  /// **'That couldn’t be done right now'**
  String get settingsActionFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet'**
  String get settingsNoAddresses;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save an address now so it’s ready for your first order'**
  String get settingsNoAddressesBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get settingsCoupons;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your offers'**
  String get settingsYourOffers;

  ///
  ///
  /// In en, this message translates to:
  /// **'Apply an offer to your bag, or copy the code'**
  String get settingsYourOffersSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String settingsCouponPercentOff(String percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'{amount} off'**
  String settingsCouponAmountOff(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Minimum {amount}'**
  String settingsCouponMinimum(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Ends today'**
  String get settingsCouponEndsToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day left} other{{days} days left}}'**
  String settingsCouponDaysLeft(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'Last use'**
  String get settingsCouponLastUse;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} uses left}}'**
  String settingsCouponUsesLeft(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{code} applied — you saved {amount}'**
  String settingsCouponApplied(String code, String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your bag is empty — add something, then apply the offer'**
  String get settingsCouponEmptyBag;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your bag has two currencies — apply the offer at checkout'**
  String get settingsCouponTwoCurrencies;

  ///
  ///
  /// In en, this message translates to:
  /// **'The coupon couldn’t be applied'**
  String get settingsCouponApplyFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Just for you'**
  String get settingsCouponJustForYou;

  ///
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get settingsCouponCopyCode;

  ///
  ///
  /// In en, this message translates to:
  /// **'Code {code} copied'**
  String settingsCouponCopied(String code);

  ///
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get settingsCouponAppliedBadge;

  ///
  ///
  /// In en, this message translates to:
  /// **'Apply to my bag'**
  String get settingsCouponApplyToBag;

  ///
  ///
  /// In en, this message translates to:
  /// **'{code} applied — saving {discount}'**
  String settingsCouponAppliedSaving(String code, String discount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemove;

  ///
  ///
  /// In en, this message translates to:
  /// **'Continue to checkout'**
  String get settingsContinueToCheckout;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your bag now: {subtotal}'**
  String settingsBagNow(String subtotal);

  ///
  ///
  /// In en, this message translates to:
  /// **'No coupons available right now'**
  String get settingsNoCoupons;

  ///
  ///
  /// In en, this message translates to:
  /// **'We’ll let you know when a new offer arrives'**
  String get settingsNoCouponsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Coupons couldn’t load'**
  String get settingsCouponsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get settingsPaymentMethods;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pay when you order'**
  String get settingsPayAtOrder;

  ///
  ///
  /// In en, this message translates to:
  /// **'You choose the method at checkout'**
  String get settingsPayAtOrderSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Available methods'**
  String get settingsAvailableMethods;

  ///
  ///
  /// In en, this message translates to:
  /// **'We don’t store card details. Each order is paid when you place it, the way you choose.'**
  String get settingsNoCardsStored;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ohara wallet'**
  String get settingsOharaWallet;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pay the courier in cash on delivery'**
  String get settingsHintCod;

  ///
  ///
  /// In en, this message translates to:
  /// **'Collected by the delivery company'**
  String get settingsHintCourierCollect;

  ///
  ///
  /// In en, this message translates to:
  /// **'Taken from your balance straight away'**
  String get settingsHintWallet;

  ///
  ///
  /// In en, this message translates to:
  /// **'We open the payment page once the order is confirmed'**
  String get settingsHintMobileWallet;

  ///
  ///
  /// In en, this message translates to:
  /// **'A secure payment page — we don’t store your card'**
  String get settingsHintCard;

  ///
  ///
  /// In en, this message translates to:
  /// **'Transfer the amount, then send the reference from the order page'**
  String get settingsHintBankTransfer;

  ///
  ///
  /// In en, this message translates to:
  /// **'A local transfer, then send the receipt number from the order page'**
  String get settingsHintHawala;

  ///
  ///
  /// In en, this message translates to:
  /// **'Payment is confirmed before the order is prepared'**
  String get settingsHintConfirmedFirst;

  ///
  ///
  /// In en, this message translates to:
  /// **'No payment methods available right now'**
  String get settingsNoPaymentMethods;

  ///
  ///
  /// In en, this message translates to:
  /// **'Payment methods couldn’t load'**
  String get settingsPaymentMethodsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsAddressDefault;

  ///
  ///
  /// In en, this message translates to:
  /// **'Near {landmark}'**
  String settingsAddressNear(String landmark);

  ///
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get settingsMakeDefault;

  ///
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get settingsEdit;

  ///
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get settingsAddressHome;

  ///
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get settingsEditAddress;

  ///
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get settingsNewAddress;

  ///
  ///
  /// In en, this message translates to:
  /// **'Address name'**
  String get settingsAddressName;

  ///
  ///
  /// In en, this message translates to:
  /// **'Home, work, my parents’'**
  String get settingsAddressNameHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Recipient’s name'**
  String get settingsRecipientName;

  ///
  ///
  /// In en, this message translates to:
  /// **'Who receives the order'**
  String get settingsRecipientNameHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get settingsPhoneNumber;

  ///
  ///
  /// In en, this message translates to:
  /// **'City or town'**
  String get settingsCity;

  ///
  ///
  /// In en, this message translates to:
  /// **'Mezzeh, Jaramana, ...'**
  String get settingsCityHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsAddressLine;

  ///
  ///
  /// In en, this message translates to:
  /// **'Street, building, floor, flat number'**
  String get settingsAddressLineHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get settingsLandmark;

  ///
  ///
  /// In en, this message translates to:
  /// **'Near Al-Nour pharmacy'**
  String get settingsLandmarkHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delivery instructions (optional)'**
  String get settingsDeliveryNotes;

  ///
  ///
  /// In en, this message translates to:
  /// **'Call before arriving'**
  String get settingsDeliveryNotesHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Make it my default address'**
  String get settingsMakeMyDefault;

  ///
  ///
  /// In en, this message translates to:
  /// **'Checkout opens with it'**
  String get settingsMakeMyDefaultHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get settingsSaveChanges;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get settingsSaveAddress;

  ///
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get settingsGovernorate;

  ///
  ///
  /// In en, this message translates to:
  /// **'Choose a governorate'**
  String get settingsChooseGovernorate;

  ///
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get settingsDistrict;

  ///
  ///
  /// In en, this message translates to:
  /// **'Choose an area (optional)'**
  String get settingsChooseDistrict;

  ///
  ///
  /// In en, this message translates to:
  /// **'{name} · countryside'**
  String settingsDistrictRural(String name);

  ///
  ///
  /// In en, this message translates to:
  /// **'The governorate list couldn’t load'**
  String get settingsGovernoratesFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get settingsFieldRequired;

  ///
  ///
  /// In en, this message translates to:
  /// **'Too short'**
  String get settingsFieldTooShort;

  ///
  ///
  /// In en, this message translates to:
  /// **'Demand radar'**
  String get siDemandRadar;

  ///
  ///
  /// In en, this message translates to:
  /// **'Radar data couldn’t load.'**
  String get siRadarFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get siNoProducts;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add your first product and we’ll start reading the market for you.'**
  String get siNoProductsRadarBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Still gathering data'**
  String get siStillGathering;

  ///
  ///
  /// In en, this message translates to:
  /// **'The radar reads the market every night. Come back tomorrow.'**
  String get siStillGatheringBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'What to do now'**
  String get siWhatToDoNow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ordered by what matters most to your shop'**
  String get siWhatToDoNowSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Stock below demand'**
  String get siStockBelowDemand;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces selling well and running out'**
  String get siStockBelowDemandSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Rising categories'**
  String get siRisingCategories;

  ///
  ///
  /// In en, this message translates to:
  /// **'Demand for them is growing'**
  String get siRisingCategoriesSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Unmet demand'**
  String get siUnmetDemand;

  ///
  ///
  /// In en, this message translates to:
  /// **'Women searched and didn’t find the right thing'**
  String get siUnmetDemandSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Price movement'**
  String get siPriceMovement;

  ///
  ///
  /// In en, this message translates to:
  /// **'None left'**
  String get siOutOfStock;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece left} other{{count} pieces left}}'**
  String siUnitsLeft(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Lasts 1 day} other{Lasts {days} days}}'**
  String siCoverDays(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'You sell here'**
  String get siYouSellHere;

  ///
  ///
  /// In en, this message translates to:
  /// **'You don’t sell here'**
  String get siYouDontSellHere;

  ///
  ///
  /// In en, this message translates to:
  /// **'{searches} searches · {percent}% found nothing'**
  String siSearchMiss(int searches, int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'In your category'**
  String get siInYourCategory;

  ///
  ///
  /// In en, this message translates to:
  /// **'Product intelligence'**
  String get siProductIntelligence;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your products couldn’t be scored.'**
  String get siProductsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add your first product and we’ll tell you what it’s missing.'**
  String get siNoProductsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get siAverage;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String siProductCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing urgent. Ordered weakest first.'**
  String get siNothingUrgent;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One needs attention now.} other{{count} need attention now.}}'**
  String siUrgentCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Based on the last day} other{Based on the last {days} days}}'**
  String siWindowDays(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'Views: {views} · Orders: {orders}'**
  String siViewsOrders(int views, int orders);

  ///
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get siSoldOut;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more tip} other{and {count} more tips}}'**
  String siMoreAdvice(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Details couldn’t load.'**
  String get siDetailsFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get siNoDataYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'Too few yet'**
  String get siTooFewYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Compared with 1 similar product} other{Compared with {count} similar products}}'**
  String siComparedWith(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your price is close to the market.'**
  String get siPriceNearMarket;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your price is {percent}% above similar pieces.'**
  String siPriceAbove(int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your price is {percent}% below similar pieces.'**
  String siPriceBelow(int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'Your conversion is {yours}% against {median}% in the category.'**
  String siConversion(String yours, String median);

  ///
  ///
  /// In en, this message translates to:
  /// **'Shop health'**
  String get siShopHealth;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shop health couldn’t be calculated.'**
  String get siHealthFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'What raises your shop’s health'**
  String get siWhatRaisesHealth;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ordered by biggest impact'**
  String get siWhatRaisesHealthSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get siMetrics;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not enough yet'**
  String get siNotEnoughYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'These metrics don’t affect your shop’s health until there’s enough data'**
  String get siNotEnoughYetBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'What slipped'**
  String get siWhatSlipped;

  ///
  ///
  /// In en, this message translates to:
  /// **'Slipping products couldn’t be read right now.'**
  String get siSlippedFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Used to sell, then slowed — with one reason for each'**
  String get siWhatSlippedSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not enough orders to judge yet. Every order you complete makes the picture clearer.'**
  String get siHealthTooFewOrders;

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Based on your last day of orders.} other{Based on your last {days} days of orders.}}'**
  String siHealthWindow(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{1 point from last month} other{{points} points from last month}}'**
  String siMomentum(int points);

  ///
  ///
  /// In en, this message translates to:
  /// **'{blurb} — nothing to measure yet.'**
  String siDimensionUnmeasured(String blurb);

  ///
  ///
  /// In en, this message translates to:
  /// **'{blurb} — measured on {sample}, but still too few to count.'**
  String siDimensionTooFew(String blurb, int sample);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String siDays(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String siHours(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{value} of 5'**
  String siOutOfFive(String value);

  ///
  ///
  /// In en, this message translates to:
  /// **'Orders you accepted and completed'**
  String get siFactAccepted;

  ///
  ///
  /// In en, this message translates to:
  /// **'Orders delivered'**
  String get siFactDelivered;

  ///
  ///
  /// In en, this message translates to:
  /// **'You cancelled'**
  String get siFactCancelledBySeller;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancelled by the customer'**
  String get siFactCancelledByOthers;

  ///
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get siFactReturned;

  ///
  ///
  /// In en, this message translates to:
  /// **'Average prep (hours)'**
  String get siFactPrepHours;

  ///
  ///
  /// In en, this message translates to:
  /// **'Average shipping (hours)'**
  String get siFactShipHours;

  ///
  ///
  /// In en, this message translates to:
  /// **'Average reply (hours)'**
  String get siFactResponseHours;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shop rating'**
  String get siFactRating;

  ///
  ///
  /// In en, this message translates to:
  /// **'Number of reviews'**
  String get siFactReviewCount;

  ///
  ///
  /// In en, this message translates to:
  /// **'Hide the numbers'**
  String get siHideNumbers;

  ///
  ///
  /// In en, this message translates to:
  /// **'Show the numbers we counted'**
  String get siShowNumbers;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shop intelligence'**
  String get siShopIntelligence;

  ///
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get siCalculating;

  ///
  ///
  /// In en, this message translates to:
  /// **'Eight metrics for your shop'**
  String get siEightMetrics;

  ///
  ///
  /// In en, this message translates to:
  /// **'Still getting to know your shop'**
  String get siGettingToKnow;

  ///
  ///
  /// In en, this message translates to:
  /// **'What demand is growing for'**
  String get siDemandRadarSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'What your product pages are missing'**
  String get siProductIntelligenceSubtitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not measured yet'**
  String get siNotMeasuredYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent}% of health'**
  String siWeightOfHealth(int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get stylistNewChat;

  ///
  ///
  /// In en, this message translates to:
  /// **'My preferences'**
  String get stylistMyPreferences;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your preferences couldn’t load.'**
  String get stylistPreferencesFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Modesty'**
  String get stylistModesty;

  ///
  ///
  /// In en, this message translates to:
  /// **'Decides which pieces the app shows you.'**
  String get stylistModestyHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'Favourite colours'**
  String get stylistFavouriteColours;

  ///
  ///
  /// In en, this message translates to:
  /// **'We rank pieces in these colours higher, without hiding the rest.'**
  String get stylistFavouriteColoursHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'My sizes'**
  String get stylistMySizes;

  ///
  ///
  /// In en, this message translates to:
  /// **'Once we know them, we only show pieces actually available in your size.'**
  String get stylistMySizesHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get stylistBudget;

  ///
  ///
  /// In en, this message translates to:
  /// **'The figure you’re usually comfortable with.'**
  String get stylistBudgetHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'What we learned from your shopping'**
  String get stylistInferred;

  ///
  ///
  /// In en, this message translates to:
  /// **'This is what your choices say, not what you wrote.'**
  String get stylistInferredHelp;

  ///
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get stylistModestyUnspecified;

  ///
  ///
  /// In en, this message translates to:
  /// **'Full coverage'**
  String get stylistModestyFull;

  ///
  ///
  /// In en, this message translates to:
  /// **'Modest'**
  String get stylistModestyModest;

  ///
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get stylistModestyBalanced;

  ///
  ///
  /// In en, this message translates to:
  /// **'No limits'**
  String get stylistModestyExpressive;

  ///
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get stylistClothing;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get stylistShoes;

  ///
  ///
  /// In en, this message translates to:
  /// **'You set up to {amount}'**
  String stylistBudgetStated(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'and you usually buy between {min} and {max}'**
  String stylistBudgetTypical(String min, String max);

  ///
  ///
  /// In en, this message translates to:
  /// **'Not enough signals yet. Browse and look at products, and we’ll learn your taste.'**
  String get stylistNoSignalYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'Products you viewed'**
  String get stylistViewed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Products you saved'**
  String get stylistSaved;

  ///
  ///
  /// In en, this message translates to:
  /// **'Products you bought'**
  String get stylistPurchased;

  ///
  ///
  /// In en, this message translates to:
  /// **'Products you passed on'**
  String get stylistDismissed;

  ///
  ///
  /// In en, this message translates to:
  /// **'We refreshed our read of your taste.'**
  String get stylistTasteRefreshed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Couldn’t refresh — try again shortly.'**
  String get stylistTasteRefreshFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get stylistRefresh;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look couldn’t open.'**
  String get stylistLookFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'One or more pieces are no longer available. You can order the rest, or ask me for an alternative.'**
  String get stylistLookPartlyUnavailable;

  ///
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get stylistNoLongerAvailable;

  ///
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get stylistTotal;

  ///
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get stylistLookSaved;

  ///
  ///
  /// In en, this message translates to:
  /// **'Save the look'**
  String get stylistSaveLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look is saved to your closet.'**
  String get stylistLookSavedToCloset;

  ///
  ///
  /// In en, this message translates to:
  /// **'The look couldn’t be saved — try again.'**
  String get stylistLookSaveFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Tell me what you’re looking for…'**
  String get stylistComposerHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get stylistSend;

  ///
  ///
  /// In en, this message translates to:
  /// **'The message didn’t send'**
  String get stylistMessageFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open the look'**
  String get stylistOpenLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'Look total'**
  String get stylistLookTotal;

  ///
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get stylistSoldOut;

  ///
  ///
  /// In en, this message translates to:
  /// **'I like it'**
  String get stylistLike;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not for me'**
  String get stylistNotForMe;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ohara’s personal stylist'**
  String get stylistWelcomeTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Tell me about the occasion, the piece or the budget — I’ll line up options that Ohara’s sellers actually have, and tell you why I picked each one.'**
  String get stylistWelcomeBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try asking me:'**
  String get stylistTryAsking;

  ///
  ///
  /// In en, this message translates to:
  /// **'A complete look'**
  String get stylistCapLookTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'A dress, bag and shoes styled together'**
  String get stylistCapLookBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get stylistCapGiftsTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'By age, taste and budget'**
  String get stylistCapGiftsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Actually in stock'**
  String get stylistCapInStockTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Every piece comes from sellers’ current stock'**
  String get stylistCapInStockBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'New search'**
  String get visualNewSearch;

  ///
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get visualPickPhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'Photo search is still getting ready'**
  String get visualPreparing;

  ///
  ///
  /// In en, this message translates to:
  /// **'We’re analysing product photos so we can compare them with yours. Try again shortly.'**
  String get visualPreparingBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get visualRefresh;

  ///
  ///
  /// In en, this message translates to:
  /// **'Saw something you liked?'**
  String get visualSawSomething;

  ///
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of the piece — a screenshot from Instagram, TikTok or Pinterest, or one from your gallery — and we’ll find the closest thing in Ohara.'**
  String get visualSawSomethingBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your past searches'**
  String get visualPastSearches;

  ///
  ///
  /// In en, this message translates to:
  /// **'Photo search'**
  String get visualPhotoSearch;

  ///
  ///
  /// In en, this message translates to:
  /// **'The photo was deleted — the results are still here'**
  String get visualPhotoDeletedResultsKept;

  ///
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get visualTapToOpen;

  ///
  ///
  /// In en, this message translates to:
  /// **'Uploading the photo…'**
  String get visualUploading;

  ///
  ///
  /// In en, this message translates to:
  /// **'Analysing the photo and searching…'**
  String get visualAnalysing;

  ///
  ///
  /// In en, this message translates to:
  /// **'Comparing your photo with products actually on Ohara.'**
  String get visualComparing;

  ///
  ///
  /// In en, this message translates to:
  /// **'I didn’t find anything close'**
  String get visualNothingClose;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try a clearer photo, or write exactly what you want.'**
  String get visualNothingCloseBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Another photo'**
  String get visualAnotherPhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The closest piece} other{The {count} closest pieces}}'**
  String visualClosestCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'No offer is available for this piece right now.'**
  String get visualNoOffer;

  ///
  ///
  /// In en, this message translates to:
  /// **'Added to your bag'**
  String get visualAddedToBag;

  ///
  ///
  /// In en, this message translates to:
  /// **'It couldn’t be added to your bag.'**
  String get visualAddToBagFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete this search?'**
  String get visualDeleteTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The photo and results will be deleted for good and can’t be recovered.'**
  String get visualDeleteBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get visualDelete;

  ///
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get visualBack;

  ///
  ///
  /// In en, this message translates to:
  /// **'The photo and search were deleted.'**
  String get visualDeleted;

  ///
  ///
  /// In en, this message translates to:
  /// **'What I understood from the photo'**
  String get visualWhatISaw;

  ///
  ///
  /// In en, this message translates to:
  /// **'I couldn’t put the photo into words, but I’m searching for it visually.'**
  String get visualCouldntDescribe;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete the photo and search'**
  String get visualDeletePhotoAndSearch;

  ///
  ///
  /// In en, this message translates to:
  /// **'Photo deleted'**
  String get visualPhotoDeleted;

  ///
  ///
  /// In en, this message translates to:
  /// **'Inferred from the closest products, not from the photo itself'**
  String get visualInferredFromMatches;

  ///
  ///
  /// In en, this message translates to:
  /// **'Closest: {label}'**
  String visualClosestCategory(String label);

  ///
  ///
  /// In en, this message translates to:
  /// **'The photo isn’t very clear — results are approximate.'**
  String get visualLowConfidence;

  ///
  ///
  /// In en, this message translates to:
  /// **'Describe what you’d like to change…'**
  String get visualRefineHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Refine the search'**
  String get visualRefine;

  ///
  ///
  /// In en, this message translates to:
  /// **'I saw more than one piece in the photo'**
  String get visualSeveralPieces;

  ///
  ///
  /// In en, this message translates to:
  /// **'I guessed this piece from the photo’s layout — I’m not completely sure.'**
  String get visualRegionGuessed;

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent} percent similar'**
  String visualSimilaritySemantics(int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent}% similar'**
  String visualSimilarityBadge(int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'Search by photo'**
  String get visualSearchByPhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the piece, or pick a screenshot from Instagram, TikTok or Pinterest.'**
  String get visualSourceBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get visualTakePhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'In good light against a plain background'**
  String get visualTakePhotoHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'From your gallery'**
  String get visualFromGallery;

  ///
  ///
  /// In en, this message translates to:
  /// **'A screenshot or saved photo'**
  String get visualFromGalleryHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your photo is stored privately and deleted automatically after the search. No one else can see it.'**
  String get visualPrivacy;

  ///
  ///
  /// In en, this message translates to:
  /// **'Visually similar pieces'**
  String get visualSimilarRail;

  ///
  ///
  /// In en, this message translates to:
  /// **'Search with your photo'**
  String get visualSearchWithYourPhoto;

  ///
  ///
  /// In en, this message translates to:
  /// **'Coupon applied — saving {amount}'**
  String checkoutCouponApplied(String amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Arrives today'**
  String get checkoutEtaToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Arrives within a day} other{Arrives within {days} days}}'**
  String checkoutEtaDays(int days);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} shipments from {count} sellers}}'**
  String checkoutSplitShipments(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Shipments'**
  String get checkoutShipments;

  ///
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String checkoutNote(String note);

  ///
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get checkoutPayment;

  ///
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get checkoutSummary;

  ///
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get checkoutDiscount;

  ///
  ///
  /// In en, this message translates to:
  /// **'From wallet'**
  String get checkoutFromWallet;

  ///
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get checkoutTotal;

  ///
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get checkoutTracking;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get checkoutCancelOrder;

  ///
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get chatClearSearch;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get chatPause;

  ///
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get chatPlay;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add to a room'**
  String get productAddToRoom;

  ///
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  ///
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  ///
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get profileShare;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ask Ohara’s stylist'**
  String get homeAskStylist;

  ///
  ///
  /// In en, this message translates to:
  /// **'Tell me the occasion and your budget, and I’ll line up options in stock'**
  String get homeAskStylistBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{price} · {stock} in stock'**
  String createProductPriceStock(String price, int stock);

  ///
  ///
  /// In en, this message translates to:
  /// **'Notes for you'**
  String get intelligenceNotesForYou;

  ///
  ///
  /// In en, this message translates to:
  /// **'Landmark: {landmark}'**
  String checkoutLandmarkValue(String landmark);

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get orderStateDraft;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get orderStatePendingPayment;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStateConfirmed;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Partly shipped'**
  String get orderStatePartiallyShipped;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get orderStateShipped;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Partly delivered'**
  String get orderStatePartiallyDelivered;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStateDelivered;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Partly cancelled'**
  String get orderStatePartiallyCancelled;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStateCancelled;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get orderStateClosed;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get parcelStateNew;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the seller'**
  String get parcelStateAwaitingSeller;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Being prepared'**
  String get parcelStatePreparing;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Ready to ship'**
  String get parcelStateReadyToShip;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'With the courier'**
  String get parcelStateHandedToCourier;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get parcelStateInTransit;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get parcelStateDelivered;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get parcelStateDeliveryFailed;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'You cancelled'**
  String get parcelStateCancelledByYou;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by the seller'**
  String get parcelStateCancelledBySeller;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Refused on delivery'**
  String get parcelStateRejectedOnDelivery;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Return requested'**
  String get parcelStateReturnRequested;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Return on the way'**
  String get parcelStateReturnInTransit;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get parcelStateReturned;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Exchange in progress'**
  String get parcelStateExchangeInProgress;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Exchanged'**
  String get parcelStateExchanged;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Refund pending'**
  String get parcelStateRefundPending;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get parcelStateRefunded;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'In dispute'**
  String get parcelStateDisputed;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get payMethodCod;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Pay the courier'**
  String get payMethodCourierCollect;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Syriatel Cash'**
  String get payMethodSyriatelCash;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'MTN Cash'**
  String get payMethodMtnCash;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Sham Cash'**
  String get payMethodShamCash;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Bank card'**
  String get payMethodBankCard;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get payMethodBankTransfer;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Local transfer'**
  String get payMethodHawala;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Ohara wallet'**
  String get payMethodWallet;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get rawStatePending;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get rawStatePaid;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get rawStateFailed;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get rawStateRefunded;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get rawStateCreated;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Courier assigned'**
  String get rawStateAssigned;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get rawStatePickedUp;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get rawStateInTransit;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get rawStateOutForDelivery;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get rawStateDelivered;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get rawStateReturning;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get rawStateReturned;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get rawStateCancelled;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get productStateDraft;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get productStatePendingReview;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get productStateActive;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get productStateOutOfStock;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get productStatePaused;

  /// Order and listing status wording.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get productStateArchived;

  /// Password field visibility toggle.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// Password field visibility toggle.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'Opens in {when}'**
  String marketDropOpensIn(String when);

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'Open · ends in {when}'**
  String marketDropEndsIn(String when);

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get marketDropOpenNow;

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'Yours {when} before everyone'**
  String marketDropEarlyBy(String when);

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String marketPriceFrom(String price);

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String spanMinutes(int count);

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String spanHours(int count);

  /// Drop timing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String spanDays(int count);

  /// Shown in place of a server message that is not in the reader's language.
  ///
  /// In en, this message translates to:
  /// **'That didn’t go through. Please try again in a moment.'**
  String get errorRetryLater;

  /// Activity hub subtitle.
  ///
  /// In en, this message translates to:
  /// **'A soft luxury boutique shaped around your taste.'**
  String get experienceTaglineBuyer;

  /// Activity hub subtitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory, orders, customers, and growth in one fast workspace.'**
  String get experienceTaglineSeller;

  /// Activity hub subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enterprise control, governance, analytics, and operating health.'**
  String get experienceTaglineAdmin;

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get loyaltyTierRose;

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get loyaltyTierGold;

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get loyaltyTierPlatinum;

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get loyaltyTierDiamond;

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No coupons} =1{1 coupon} other{{count} coupons}}'**
  String homeLoyaltyCoupons(int count);

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not claimed yet} =1{1 claimed} other{{count} claimed}}'**
  String flashClaimed(int count);

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new} other{{count} new}}'**
  String notificationsNewCount(int count);

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No boutiques} =1{1 boutique} other{{count} boutiques}}'**
  String profileBoutiquesCount(int count);

  /// Count shown on a card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left} other{{count} left}}'**
  String sellerStockLeft(int count);

  /// Order timeline entry.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get orderTimelineCreated;

  /// Order timeline entry.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get orderTimelineConfirmed;

  /// Order timeline entry.
  ///
  /// In en, this message translates to:
  /// **'Sent to the sellers to prepare.'**
  String get orderTimelineConfirmedBody;

  /// Order timeline entry.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get orderTimelineCancelled;

  /// Order timeline entry.
  ///
  /// In en, this message translates to:
  /// **'The payment deadline passed.'**
  String get orderTimelinePaymentExpired;

  /// Room readiness blocker.
  ///
  /// In en, this message translates to:
  /// **'You haven’t chosen a piece yet'**
  String get roomsBlockerNothingChosen;

  /// Caption over lifetime profit, margin and orders on the revenue card.
  ///
  /// In en, this message translates to:
  /// **'Since you opened your shop'**
  String get sellerAllTimeTotals;

  /// Seller profile badge for the BASIC level.
  ///
  /// In en, this message translates to:
  /// **'Basic plan'**
  String get sellerPlanBasic;

  /// Seller profile badge for the VERIFIED level.
  ///
  /// In en, this message translates to:
  /// **'Verified plan'**
  String get sellerPlanVerified;

  /// Seller profile badge for the PREMIUM level.
  ///
  /// In en, this message translates to:
  /// **'Premium plan'**
  String get sellerPlanPremium;

  /// Seller order breakdown: a platform-funded coupon, shown as a note rather than a deduction.
  ///
  /// In en, this message translates to:
  /// **'A {amount} discount was paid by Ohara and doesn\'t come out of your earnings.'**
  String sellerOrderPlatformDiscountNote(String amount);

  /// Composer chip: a product post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get contentTypePost;

  /// Composer chip: a short video.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get contentTypeReel;

  /// Composer chip: a 24-hour story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get contentTypeStory;

  /// Composer chip: a time-limited offer.
  ///
  /// In en, this message translates to:
  /// **'Flash offer'**
  String get contentTypeFlashOffer;

  /// Composer chip: a curated collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get contentTypeCollection;

  /// Composer chip: a live stream.
  ///
  /// In en, this message translates to:
  /// **'Live stream'**
  String get contentTypeLiveStream;

  /// Content studio row: flash offers.
  ///
  /// In en, this message translates to:
  /// **'Flash offers'**
  String get studioFormatFlashOffers;

  /// Content studio row: collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get studioFormatCollections;

  /// Content studio row: live streams.
  ///
  /// In en, this message translates to:
  /// **'Live streams'**
  String get studioFormatLiveStreams;

  /// Content studio row for a content type the app does not know yet.
  ///
  /// In en, this message translates to:
  /// **'Other content'**
  String get studioFormatOther;

  /// Admin console status token INFO.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get adminStatusInfo;

  /// Admin console status token WARNING.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get adminStatusWarning;

  /// Admin console status token CRITICAL.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get adminStatusCritical;

  /// Admin console status token QUEUED.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get adminStatusQueued;

  /// Admin console status token SENT.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get adminStatusSent;

  /// Admin console status token FAILED.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get adminStatusFailed;

  /// Admin console status token SKIPPED.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get adminStatusSkipped;

  /// Admin console status token SCHEDULED.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get adminStatusScheduled;

  /// Admin console status token RUNNING.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get adminStatusRunning;

  /// Admin console status token COMPLETED.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get adminStatusCompleted;

  /// Admin console status token REFUNDED.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get adminStatusRefunded;

  /// Audit log entry name: Signed in.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get adminAuditLogin;

  /// Audit log entry name: Signed out.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get adminAuditLogout;

  /// Audit log entry name: Signed out everywhere.
  ///
  /// In en, this message translates to:
  /// **'Signed out everywhere'**
  String get adminAuditLogoutAll;

  /// Audit log entry name: Account created.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get adminAuditRegister;

  /// Audit log entry name: Phone change started.
  ///
  /// In en, this message translates to:
  /// **'Phone change started'**
  String get adminAuditPhoneChangeStarted;

  /// Audit log entry name: Phone change completed.
  ///
  /// In en, this message translates to:
  /// **'Phone change completed'**
  String get adminAuditPhoneChangeCompleted;

  /// Audit log entry name: Phone changed.
  ///
  /// In en, this message translates to:
  /// **'Phone changed'**
  String get adminAuditPhoneChanged;

  /// Audit log entry name: Recovery case opened.
  ///
  /// In en, this message translates to:
  /// **'Recovery case opened'**
  String get adminAuditRecoveryOpened;

  /// Audit log entry name: Recovery case submitted.
  ///
  /// In en, this message translates to:
  /// **'Recovery case submitted'**
  String get adminAuditRecoverySubmitted;

  /// Audit log entry name: Recovery: first approval.
  ///
  /// In en, this message translates to:
  /// **'Recovery: first approval'**
  String get adminAuditRecoveryFirstApproval;

  /// Audit log entry name: Recovery: second approval.
  ///
  /// In en, this message translates to:
  /// **'Recovery: second approval'**
  String get adminAuditRecoverySecondApproval;

  /// Audit log entry name: Recovery cooling off.
  ///
  /// In en, this message translates to:
  /// **'Recovery cooling off'**
  String get adminAuditRecoveryCoolingOff;

  /// Audit log entry name: Recovery completed.
  ///
  /// In en, this message translates to:
  /// **'Recovery completed'**
  String get adminAuditRecoveryCompleted;

  /// Audit log entry name: Recovery rejected.
  ///
  /// In en, this message translates to:
  /// **'Recovery rejected'**
  String get adminAuditRecoveryRejected;

  /// Audit log entry name: Recovery cancelled.
  ///
  /// In en, this message translates to:
  /// **'Recovery cancelled'**
  String get adminAuditRecoveryCancelled;

  /// Audit log entry name: Password reset requested.
  ///
  /// In en, this message translates to:
  /// **'Password reset requested'**
  String get adminAuditPasswordResetRequested;

  /// Audit log entry name: Password reset.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get adminAuditPasswordResetCompleted;

  /// Audit log entry name: Password turned off.
  ///
  /// In en, this message translates to:
  /// **'Password turned off'**
  String get adminAuditPasswordDisabled;

  /// Audit log entry name: Two-step verification on.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification on'**
  String get adminAuditTotpConfirmed;

  /// Audit log entry name: Recovery codes created.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes created'**
  String get adminAuditRecoveryCodesGenerated;

  /// Audit log entry name: Recovery code used.
  ///
  /// In en, this message translates to:
  /// **'Recovery code used'**
  String get adminAuditRecoveryCodeRedeemed;

  /// Audit log entry name: Sign-in codes revealed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in codes revealed'**
  String get adminAuditOtpCodesRevealed;

  /// Audit log entry name: Seller verification approved.
  ///
  /// In en, this message translates to:
  /// **'Seller verification approved'**
  String get adminAuditSellerVerificationApproved;

  /// Audit log entry name: Seller verification rejected.
  ///
  /// In en, this message translates to:
  /// **'Seller verification rejected'**
  String get adminAuditSellerVerificationRejected;

  /// Audit log entry name: Content removed.
  ///
  /// In en, this message translates to:
  /// **'Content removed'**
  String get adminAuditContentRemoved;

  /// Audit log entry name: Content reinstated.
  ///
  /// In en, this message translates to:
  /// **'Content reinstated'**
  String get adminAuditContentReinstated;

  /// Audit log entry name: Comment removed.
  ///
  /// In en, this message translates to:
  /// **'Comment removed'**
  String get adminAuditCommentRemoved;

  /// Audit log entry name: Wallet credited.
  ///
  /// In en, this message translates to:
  /// **'Wallet credited'**
  String get adminAuditWalletCredited;

  /// Audit log entry name: Wallet frozen.
  ///
  /// In en, this message translates to:
  /// **'Wallet frozen'**
  String get adminAuditWalletFrozen;

  /// Audit log entry name: Sessions revoked.
  ///
  /// In en, this message translates to:
  /// **'Sessions revoked'**
  String get adminAuditRevokeSessions;

  /// Audit log entry name: Cool-off started.
  ///
  /// In en, this message translates to:
  /// **'Cool-off started'**
  String get adminAuditCoolOffStarted;

  /// Audit log entry name: Sign-in & security.
  ///
  /// In en, this message translates to:
  /// **'Sign-in & security'**
  String get adminAuditAreaAuth;

  /// Audit log entry name: Account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminAuditAreaAccount;

  /// Admin report type: Sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get adminReportTypeSales;

  /// Admin report type: Sellers.
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get adminReportTypeSellers;

  /// Admin report type: Content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get adminReportTypeContent;

  /// Admin report type: Finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get adminReportTypeFinance;

  /// Admin report type: Users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminReportTypeUsers;

  /// Ohara Value standing rung: New.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get valueRungNew;

  /// Ohara Value standing rung: Known.
  ///
  /// In en, this message translates to:
  /// **'Known'**
  String get valueRungKnown;

  /// Ohara Value standing rung: Trusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get valueRungTrusted;

  /// Ohara Value standing rung: Insider.
  ///
  /// In en, this message translates to:
  /// **'Insider'**
  String get valueRungInsider;

  /// Ohara Value standing rung: Circle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get valueRungCircle;

  /// Audit log entry name.
  ///
  /// In en, this message translates to:
  /// **'Seller verification reviewed'**
  String get adminAuditReviewSellerVerification;

  /// Audit log entry recorded from an admin API request; the request line is in the details.
  ///
  /// In en, this message translates to:
  /// **'Admin action'**
  String get adminAuditAdminRequest;

  /// Her first name on its own line in the home hero, before the question.
  ///
  /// In en, this message translates to:
  /// **'{name},'**
  String homeAuraAddress(String name);

  /// Home hero first line when we have no name.
  ///
  /// In en, this message translates to:
  /// **'Welcome,'**
  String get homeAuraGuest;

  /// Home hero question, morning.
  ///
  /// In en, this message translates to:
  /// **'What are we wearing today?'**
  String get homeAuraQuestionMorning;

  /// Home hero question, midday.
  ///
  /// In en, this message translates to:
  /// **'Something to brighten your day?'**
  String get homeAuraQuestionMidday;

  /// Home hero question, evening.
  ///
  /// In en, this message translates to:
  /// **'What are you wearing tonight?'**
  String get homeAuraQuestionEvening;

  /// Home hero question, late night.
  ///
  /// In en, this message translates to:
  /// **'A quiet moment, just for you'**
  String get homeAuraQuestionNight;

  /// Label on the home hero's ask-the-stylist field.
  ///
  /// In en, this message translates to:
  /// **'Ask Ohara'**
  String get homeAskOhara;

  /// Rotating example inside the ask-Ohara field.
  ///
  /// In en, this message translates to:
  /// **'A navy evening dress under 50K'**
  String get homeAskExample1;

  /// Rotating example inside the ask-Ohara field.
  ///
  /// In en, this message translates to:
  /// **'A comfortable, polished work look'**
  String get homeAskExample2;

  /// Rotating example inside the ask-Ohara field.
  ///
  /// In en, this message translates to:
  /// **'A birthday gift for my sister'**
  String get homeAskExample3;

  /// Rotating example inside the ask-Ohara field.
  ///
  /// In en, this message translates to:
  /// **'What goes with beige shoes?'**
  String get homeAskExample4;

  /// Camera button on the ask-Ohara field.
  ///
  /// In en, this message translates to:
  /// **'Search by photo'**
  String get homeAskPhoto;

  /// Live chip on the home hero.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 boutique posted today} other{{count} boutiques posted today}}'**
  String homeBriefStories(int count);

  /// Live chip on the home hero with a running countdown.
  ///
  /// In en, this message translates to:
  /// **'A deal ends in {time}'**
  String homeBriefDealEnds(String time);

  /// Live chip on the home hero.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new notification} other{{count} new notifications}}'**
  String homeBriefUnread(int count);

  /// Live chip on the home hero.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece in your bag} other{{count} pieces in your bag}}'**
  String homeBriefBag(int count);

  /// Badge on the home's live strip.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get homePulseLive;

  /// Live strip line for a flash deal.
  ///
  /// In en, this message translates to:
  /// **'{title} — ends in {time}'**
  String homePulseDeal(String title, String time);

  /// Live strip line for a trending piece.
  ///
  /// In en, this message translates to:
  /// **'Most wanted right now: {title}'**
  String homePulseTrending(String title);

  /// Live strip line for a new arrival.
  ///
  /// In en, this message translates to:
  /// **'Just in: {title}'**
  String homePulseNew(String title);

  /// Home section title over the mood tiles.
  ///
  /// In en, this message translates to:
  /// **'What\'s the mood today?'**
  String get homeMoodTitle;

  /// Home section subtitle over the mood tiles.
  ///
  /// In en, this message translates to:
  /// **'Pick one and Ohara styles the whole look'**
  String get homeMoodSubtitle;

  /// Mood tile.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get homeMoodEvening;

  /// Mood tile.
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get homeMoodWedding;

  /// Mood tile.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get homeMoodWork;

  /// Mood tile.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get homeMoodCasual;

  /// Mood tile.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get homeMoodGift;

  /// Mood tile.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get homeMoodTravel;

  /// Question the evening mood tile asks the stylist.
  ///
  /// In en, this message translates to:
  /// **'I want an elegant evening look'**
  String get homeMoodPromptEvening;

  /// Question the wedding mood tile asks the stylist.
  ///
  /// In en, this message translates to:
  /// **'I need a look for a wedding'**
  String get homeMoodPromptWedding;

  /// Question the work mood tile asks the stylist.
  ///
  /// In en, this message translates to:
  /// **'A comfortable, polished work look'**
  String get homeMoodPromptWork;

  /// Question the casual mood tile asks the stylist.
  ///
  /// In en, this message translates to:
  /// **'A casual weekend look'**
  String get homeMoodPromptCasual;

  /// Question the gift mood tile asks the stylist.
  ///
  /// In en, this message translates to:
  /// **'I\'m looking for a special gift'**
  String get homeMoodPromptGift;

  /// Question the travel mood tile asks the stylist.
  ///
  /// In en, this message translates to:
  /// **'Comfortable, stylish travel clothes'**
  String get homeMoodPromptTravel;

  /// Eyebrow over the swipe deck.
  ///
  /// In en, this message translates to:
  /// **'Picked for you by Ohara'**
  String get homeDeckEyebrow;

  /// Title over the swipe deck.
  ///
  /// In en, this message translates to:
  /// **'Your taste, piece by piece'**
  String get homeDeckTitle;

  /// Hint under the swipe deck.
  ///
  /// In en, this message translates to:
  /// **'Swipe right for what you love, left to skip'**
  String get homeDeckHint;

  /// Swipe deck like button and stamp.
  ///
  /// In en, this message translates to:
  /// **'Love it'**
  String get homeDeckLike;

  /// Swipe deck skip button and stamp.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get homeDeckPass;

  /// Swipe deck open button.
  ///
  /// In en, this message translates to:
  /// **'View piece'**
  String get homeDeckOpen;

  /// Swipe deck position.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String homeDeckProgress(int current, int total);

  /// Swipe deck end card title.
  ///
  /// In en, this message translates to:
  /// **'That\'s today\'s picks'**
  String get homeDeckDoneTitle;

  /// Swipe deck end card body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing today? Ohara will learn from that.} =1{You loved 1 piece; it\'s in your likes.} other{You loved {count} pieces; they\'re in your likes.}}'**
  String homeDeckDoneBody(int count);

  /// Swipe deck end card button.
  ///
  /// In en, this message translates to:
  /// **'All picks'**
  String get homeDeckSeeAll;

  /// Swipe deck end card button.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get homeDeckRestart;

  /// Eyebrow over the category bento.
  ///
  /// In en, this message translates to:
  /// **'Ohara\'s world'**
  String get homeBentoEyebrow;

  /// Title over the category bento.
  ///
  /// In en, this message translates to:
  /// **'Wander the departments'**
  String get homeBentoTitle;

  /// Piece count on a category bento tile.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Coming soon} =1{1 piece} other{{count} pieces}}'**
  String homeBentoCount(int count);

  /// Button on a post ticket when nothing is in stock to add.
  ///
  /// In en, this message translates to:
  /// **'View the piece'**
  String get postOpenPiece;

  /// Order payment - reference sent back by finance
  ///
  /// In en, this message translates to:
  /// **'Finance could not match your reference: {reason}. Check it and send it again.'**
  String paymentReferenceRejected(String reason);

  /// Finance console - pending bank transfers and hawala
  ///
  /// In en, this message translates to:
  /// **'Transfers awaiting confirmation'**
  String get financePendingTransfers;

  /// Finance console - no pending transfers
  ///
  /// In en, this message translates to:
  /// **'No transfers are waiting to be matched.'**
  String get financePendingTransfersEmpty;

  /// Finance console - transfers failed to load
  ///
  /// In en, this message translates to:
  /// **'Could not load the transfers. Refresh to try again.'**
  String get financePendingTransfersError;

  /// Finance console - confirm a transfer
  ///
  /// In en, this message translates to:
  /// **'Confirm received'**
  String get financeTransferConfirm;

  /// Finance console - reject a transfer reference
  ///
  /// In en, this message translates to:
  /// **'Not matched'**
  String get financeTransferReject;

  /// Finance console - confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm this transfer?'**
  String get financeTransferConfirmTitle;

  /// Finance console - confirm dialog body
  ///
  /// In en, this message translates to:
  /// **'You are confirming that {amount} for order {order} has arrived. The order goes to its sellers straight away.'**
  String financeTransferConfirmBody(String amount, String order);

  /// Finance console - transfer confirmed
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed — the order is with its sellers'**
  String get financeTransferConfirmed;

  /// Finance console - transfer rejected
  ///
  /// In en, this message translates to:
  /// **'Reference sent back to the customer'**
  String get financeTransferRejected;

  /// Finance console - reject dialog title
  ///
  /// In en, this message translates to:
  /// **'Why could it not be matched?'**
  String get financeTransferRejectTitle;

  /// Finance console - reject reason field
  ///
  /// In en, this message translates to:
  /// **'Reason (shown to the customer)'**
  String get financeTransferRejectReason;

  /// Finance console - transfer without reference
  ///
  /// In en, this message translates to:
  /// **'No reference sent yet'**
  String get financeTransferNoReference;

  /// Finance console - transfer deadline
  ///
  /// In en, this message translates to:
  /// **'Stock held until {date}'**
  String financeTransferExpires(String date);

  /// Title of the reverse-SMS step, where she sends the code instead of receiving one
  ///
  /// In en, this message translates to:
  /// **'Verify with one message'**
  String get reverseSmsTitle;

  /// Why the reverse rail is safer, shown under the title
  ///
  /// In en, this message translates to:
  /// **'Send the message below from this number. Nothing is sent to you, so nobody can ask you to read a code out.'**
  String get reverseSmsExplainer;

  /// The receiver number the verification message is addressed to
  ///
  /// In en, this message translates to:
  /// **'To: {number}'**
  String reverseSmsSendTo(String number);

  /// Label above the exact SMS body she must send
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get reverseSmsBodyLabel;

  /// Button that opens the SMS composer prefilled with the verification message
  ///
  /// In en, this message translates to:
  /// **'Open Messages'**
  String get reverseSmsOpenMessages;

  /// Button she taps after sending the verification message
  ///
  /// In en, this message translates to:
  /// **'I have sent it'**
  String get reverseSmsIveSent;

  /// Shown while the app polls for the inbound verification message
  ///
  /// In en, this message translates to:
  /// **'Waiting for your message…'**
  String get reverseSmsWaiting;

  /// Tells her the outgoing verification SMS is billed to her
  ///
  /// In en, this message translates to:
  /// **'Charged at your operator\'s normal SMS rate.'**
  String get reverseSmsCost;

  /// Shown when she taps continue before the inbound message has been matched
  ///
  /// In en, this message translates to:
  /// **'Your message has not arrived yet. Give it a moment, then try again.'**
  String get reverseSmsNotYet;

  /// Shown when the SMS composer cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Could not open your messaging app. Send the message above manually.'**
  String get reverseSmsCouldNotOpen;

  /// Small eyebrow above the sign-in title
  ///
  /// In en, this message translates to:
  /// **'A space made for women'**
  String get authEyebrow;

  /// Word between two sign-in options
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// Reassurance at the foot of the sign-in screens
  ///
  /// In en, this message translates to:
  /// **'Your number is protected and never shared.'**
  String get authTrustNote;

  /// Caption under continue as guest
  ///
  /// In en, this message translates to:
  /// **'Browse the boutiques without an account'**
  String get authGuestCaption;

  /// Caption under the password sign-in option
  ///
  /// In en, this message translates to:
  /// **'On a phone you have used before'**
  String get authPasswordCaption;

  /// Hint above the six code cells
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get authCodeHint;

  /// Caption under lost your SIM
  ///
  /// In en, this message translates to:
  /// **'Recover your account with another number'**
  String get authLostSimCaption;

  /// Heading over the buyer / seller choice
  ///
  /// In en, this message translates to:
  /// **'How will you join Ohara?'**
  String get authSectionJoinAs;

  /// Caption on the buyer role card
  ///
  /// In en, this message translates to:
  /// **'Shop, follow and share'**
  String get authRoleBuyerHint;

  /// Caption on the seller role card
  ///
  /// In en, this message translates to:
  /// **'Open your boutique and sell'**
  String get authRoleSellerHint;

  /// Heading over the name fields
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get authSectionAboutYou;

  /// Heading over country and city
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get authSectionWhere;

  /// Heading over the optional password
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get authSectionSecurity;

  /// Heading over the declaration and terms
  ///
  /// In en, this message translates to:
  /// **'Your pledge'**
  String get authSectionPromise;

  /// Benefit of having an account
  ///
  /// In en, this message translates to:
  /// **'Check out easily and safely'**
  String get authBenefitCheckout;

  /// Benefit of having an account
  ///
  /// In en, this message translates to:
  /// **'Message sellers directly'**
  String get authBenefitChat;

  /// Benefit of having an account
  ///
  /// In en, this message translates to:
  /// **'Save everything you love'**
  String get authBenefitSaved;

  /// Subtitle on the forgot password screen
  ///
  /// In en, this message translates to:
  /// **'Enter your number and we will send you a code to set a new password.'**
  String get authForgotSubtitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get salonCategoryHair;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Nails'**
  String get salonCategoryNails;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Skin care'**
  String get salonCategorySkin;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get salonCategoryMakeup;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Lashes & brows'**
  String get salonCategoryLashesBrows;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Hair removal'**
  String get salonCategoryHairRemoval;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Massage & spa'**
  String get salonCategoryMassageSpa;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Bridal'**
  String get salonCategoryBridal;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Other services'**
  String get salonCategoryOther;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get salonStatusPending;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get salonStatusConfirmed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get salonStatusCompleted;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get salonStatusCancelled;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get salonStatusNoShow;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Waiting for the salon to confirm'**
  String get salonStatusHintPending;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Your appointment is booked'**
  String get salonStatusHintConfirmed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Visit completed'**
  String get salonStatusHintCompleted;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'This appointment was cancelled'**
  String get salonStatusHintCancelled;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'The salon recorded a no-show'**
  String get salonStatusHintNoShow;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'At the salon'**
  String get salonLocationInSalon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'At home'**
  String get salonLocationAtHome;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'At the salon or at home'**
  String get salonLocationBoth;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'You cancelled this appointment'**
  String get salonCancelledByCustomer;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'The salon cancelled this appointment'**
  String get salonCancelledBySalon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Cancelled automatically: it was not confirmed in time'**
  String get salonCancelledBySystem;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String salonDurationMinutes(int minutes);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get salonDurationOneHour;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'2 hours'**
  String get salonDurationTwoHours;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String salonDurationHours(int hours);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{hours} and a half'**
  String salonDurationAndHalf(String hours);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{hours} {minutes} min'**
  String salonDurationAndMinutes(String hours, int minutes);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get salonWeekdaySun;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get salonWeekdayMon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get salonWeekdayTue;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get salonWeekdayWed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get salonWeekdayThu;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get salonWeekdayFri;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get salonWeekdaySat;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get salonMonth1;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get salonMonth2;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get salonMonth3;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get salonMonth4;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get salonMonth5;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get salonMonth6;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get salonMonth7;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get salonMonth8;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get salonMonth9;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get salonMonth10;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get salonMonth11;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get salonMonth12;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get salonTimeAm;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get salonTimePm;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get salonToday;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get salonTomorrow;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'The day after tomorrow'**
  String get salonDayAfterTomorrow;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'In {days} days'**
  String salonInDays(int days);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salon details'**
  String get salonEditorTitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your details.'**
  String get salonEditorLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get salonEditorSectionProfile;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salon name'**
  String get salonEditorName;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get salonEditorTagline;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'e.g. Cuts, colour and hair care'**
  String get salonEditorTaglineHint;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get salonEditorAbout;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get salonEditorSectionLocation;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get salonEditorGovernorate;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get salonEditorCity;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get salonEditorArea;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get salonEditorAddress;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get salonEditorLandmark;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'e.g. Next to Al-Nour pharmacy'**
  String get salonEditorLandmarkHint;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get salonEditorLatitude;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get salonEditorLongitude;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Coordinates are optional, but with them customers can open your location on the map directly.'**
  String get salonEditorCoordsHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get salonEditorSectionContact;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get salonEditorPhone;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get salonEditorWhatsapp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Booking settings'**
  String get salonEditorSectionBooking;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Slot length'**
  String get salonEditorSlotLength;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get salonUnitMinute;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'How often a new slot starts — for example every half hour.'**
  String get salonEditorSlotLengthHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Earliest booking'**
  String get salonEditorLeadTime;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'The shortest time between booking and appointment, so you\'re not surprised by one five minutes away.'**
  String get salonEditorLeadTimeHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Book up to'**
  String get salonEditorHorizon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get salonUnitDay;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'How far ahead a customer can book.'**
  String get salonEditorHorizonHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Customers at the same time'**
  String get salonEditorCapacity;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'How many chairs you can work at in the same hour.'**
  String get salonEditorCapacityHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Late cancellation'**
  String get salonEditorLateCancel;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get salonUnitHour;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Cancelling closer to the appointment than this counts as a late cancellation.'**
  String get salonEditorLateCancelHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Home service'**
  String get salonEditorSectionHome;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'You go to the customer\'s home'**
  String get salonEditorHomeVisits;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Travel fee'**
  String get salonEditorTravelFee;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open the salon'**
  String get salonEditorCreate;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get salonSave;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Save and publish'**
  String get salonEditorSavePublish;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Hide from the directory'**
  String get salonEditorHide;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get salonFieldRequired;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get salonInvalidNumber;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Details saved'**
  String get salonEditorSaved;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save. Please try again.'**
  String get salonSaveFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Appointment details'**
  String get salonAppointmentDetails;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open this appointment.'**
  String get salonAppointmentLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get salonService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get salonAppointment;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get salonDuration;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get salonPrice;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Booking number'**
  String get salonBookingNumber;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get salonCustomer;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Home service'**
  String get salonHomeService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Customer\'s note'**
  String get salonCustomerNote;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salon\'s note'**
  String get salonSalonNote;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Message the salon'**
  String get salonMessageSalon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salon page'**
  String get salonPage;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Message the customer'**
  String get salonMessageCustomer;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get salonConfirmBooking;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Appointment confirmed'**
  String get salonAppointmentConfirmed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Visit recorded'**
  String get salonVisitRecorded;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Didn\'t show up'**
  String get salonMarkNoShow;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get salonRecorded;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get salonCancelAppointmentAction;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Rate the salon'**
  String get salonRateSalon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Cancel the appointment'**
  String get salonCancelAppointmentTitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this appointment?'**
  String get salonCancelConfirm;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled'**
  String get salonAppointmentCancelled;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review'**
  String get salonThanksForReview;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish that. Please try again.'**
  String get salonActionFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'How was your visit?'**
  String get salonHowWasVisit;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get salonLater;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get salonSend;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get salonMyBookings;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get salonUpcoming;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get salonPast;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your bookings.'**
  String get salonBookingsLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'You have no appointments'**
  String get salonNoAppointmentsYou;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No past appointments'**
  String get salonNoPastAppointments;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Find a salon and book your appointment in one tap.'**
  String get salonFindAndBook;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Finished appointments will appear here.'**
  String get salonPastHere;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Browse salons'**
  String get salonBrowseSalons;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Book your appointment'**
  String get salonBookYourAppointment;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the calendar.'**
  String get salonCalendarLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'This service is no longer available'**
  String get salonServiceUnavailable;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Choose another service from the salon page.'**
  String get salonPickAnotherService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Sign in to book'**
  String get salonSignInToBook;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Booking needs an account so we can confirm your appointment and remind you of it.'**
  String get salonSignInToBookBody;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Choose the address where you want the service.'**
  String get salonPickAddress;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t secure that time. Someone may have just booked it — try another time.'**
  String get salonBookingFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Choose the day'**
  String get salonPickDay;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the available days.'**
  String get salonDaysLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Choose the time'**
  String get salonPickTime;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Note for the salon (optional)'**
  String get salonNoteForSalon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'e.g. My hair is long, or I prefer a particular stylist'**
  String get salonNoteForSalonHint;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No free times this week. Try messaging the salon.'**
  String get salonNoSlotsWeek;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get salonClosed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the times.'**
  String get salonSlotsLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No free times on this day.'**
  String get salonNoSlotsDay;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'I want the service at home'**
  String get salonWantHomeService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Add an address'**
  String get salonAddAddress;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get salonPickATime;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get salonWorkingHours;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your hours.'**
  String get salonHoursLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No salon yet'**
  String get salonNoSalonYet;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open your salon first, then set your hours.'**
  String get salonOpenFirstHours;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Save hours'**
  String get salonSaveHours;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Closed days'**
  String get salonClosedDays;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Holidays or time off — booking is closed on these dates whatever the hours say.'**
  String get salonClosedDaysHelp;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No closed days.'**
  String get salonNoClosedDays;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Add a closed day'**
  String get salonAddClosedDay;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Hours saved'**
  String get salonHoursSaved;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save the hours.'**
  String get salonHoursSaveFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Closed day added'**
  String get salonClosedDayAdded;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t add the day.'**
  String get salonClosedDayAddFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Closed day removed'**
  String get salonClosedDayRemoved;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t remove the day.'**
  String get salonClosedDayRemoveFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get salonDayClosed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get salonDayOpen;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get salonFrom;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get salonTo;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Add a break'**
  String get salonAddBreak;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Break from'**
  String get salonBreakFrom;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Remove break'**
  String get salonRemoveBreak;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get salonRemove;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get salonAppointments;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get salonAwaitingConfirmation;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your appointments.'**
  String get salonQueueOpenError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open your salon first, and bookings will start coming in.'**
  String get salonOpenFirstBookings;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the appointments.'**
  String get salonQueueLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for you'**
  String get salonNothingPending;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments'**
  String get salonNoUpcoming;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'All bookings are confirmed.'**
  String get salonAllConfirmed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'As soon as a customer books, you\'ll see it here.'**
  String get salonFirstBookingHere;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm. Please try again.'**
  String get salonConfirmFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this salon'**
  String get salonNotFound;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'It may have closed or is no longer available.'**
  String get salonNotFoundBody;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get salonServices;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'The salon hasn\'t added its services yet'**
  String get salonNoServicesYet;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Message them to find out what they offer.'**
  String get salonMessageToAsk;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get salonOpeningHours;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get salonReviews;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Be the first to try it and leave one.'**
  String get salonNoReviews;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get salonCall;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get salonShare;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get salonOpenMap;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'The salon hasn\'t set its hours yet.'**
  String get salonNoHoursYet;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get salonCustomerFallback;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Verified visit'**
  String get salonVerifiedVisit;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salon\'s reply'**
  String get salonReply;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Services & prices'**
  String get salonServicesAndPrices;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your services.'**
  String get salonServicesLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open your salon first, then add your services.'**
  String get salonOpenFirstServices;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No services'**
  String get salonNoServices;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Add your first service with its price and duration, and booking goes live.'**
  String get salonAddFirstService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Add a service'**
  String get salonAddService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Service saved'**
  String get salonServiceSaved;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save the service.'**
  String get salonServiceSaveFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Service paused'**
  String get salonServicePaused;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Service resumed'**
  String get salonServiceResumed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t change the service\'s status.'**
  String get salonServiceToggleFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get salonPausedBadge;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get salonPackage;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get salonPause;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get salonResume;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'New service'**
  String get salonNewService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get salonEditService;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get salonServiceName;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get salonDescription;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get salonType;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get salonInvalidPrice;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Before discount'**
  String get salonBeforeDiscount;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Preparation time after'**
  String get salonBufferAfter;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Where it\'s done'**
  String get salonWhereDone;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'This is a package (several services together)'**
  String get salonIsPackage;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get salonNone;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'My salon'**
  String get salonMySalon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your salon.'**
  String get salonWorkspaceLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Open your salon on Ohara'**
  String get salonOpenOnOhara;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Introduce your salon, services and hours, and let customers book their appointments straight from the app.'**
  String get salonOpenOnOharaBody;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get salonStart;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get salonPublished;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get salonDraft;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get salonSuspended;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get salonRating;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'services'**
  String get salonStatServices;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'bookings'**
  String get salonStatBookings;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'reviews'**
  String get salonStatReviews;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Confirm bookings and record visits'**
  String get salonAppointmentsSubtitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Weekly hours and closed days'**
  String get salonHoursSubtitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Name, address, contact and booking settings'**
  String get salonDetailsSubtitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'See your page as a customer sees it'**
  String get salonPreviewAsCustomer;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No active services — nobody can book until you add one.'**
  String get salonNoActiveServices;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'You haven\'t set any hours — every day is closed.'**
  String get salonNoHoursSet;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Set hours'**
  String get salonSetHours;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Your salon isn\'t published yet — publish it to appear in the directory.'**
  String get salonNotPublished;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Publish the salon'**
  String get salonPublish;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Your salon is now published'**
  String get salonPublishedDone;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t publish the salon.'**
  String get salonPublishFailed;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salons & beauty'**
  String get salonsTitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get salonFilter;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the salons.'**
  String get salonsLoadError;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No salons yet'**
  String get salonsNoneYet;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'No salon matches these filters'**
  String get salonsNoMatch;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Soon you\'ll find salons and stylists here that you can book directly.'**
  String get salonsComingSoon;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Try widening the filters or changing the area.'**
  String get salonsWidenFilters;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Search for a salon or service'**
  String get salonsSearchHint;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get salonAll;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'By price'**
  String get salonByPrice;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Cuts, colour and care — book in the app and choose your time.'**
  String get salonsRailSubtitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get salonNew;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get salonFeatured;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Filter salons'**
  String get salonsFilterTitle;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'All areas'**
  String get salonAllAreas;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Any rating'**
  String get salonAnyRating;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get salonClearAll;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get salonShowResults;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Home services only'**
  String get salonHomeOnly;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Salons that come to your home'**
  String get salonHomeOnlyHint;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get salonBook;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{price} — paid at the salon'**
  String salonPricePaidAtSalon(String price);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Your rating: {rating} ★'**
  String salonYourRating(String rating);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Less than {hours} hours to go, so this is a late cancellation and the salon will see it. Are you sure?'**
  String salonLateCancelConfirm(int hours);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String salonSlotsCount(int count);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Travel fee {fee}'**
  String salonTravelFeeValue(String fee);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'You pay at the salon. Free cancellation up to {hours} hours before.'**
  String salonPayAtSalonFreeCancel(int hours);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{day}: closing time must be after opening.'**
  String salonHoursCloseAfterOpen(String day);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{day} break: the end must be after the start.'**
  String salonBreakEndAfterStart(String day);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Reviews ({count})'**
  String salonReviewsCount(int count);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{count} services'**
  String salonServicesCount(int count);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{count} active services'**
  String salonActiveServicesCount(int count);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{rating} ★ and up'**
  String salonRatingAtLeast(String rating);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String salonPriceFrom(String price);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Any price'**
  String get salonAnyPrice;

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Up to {amount}'**
  String salonPriceUpTo(String amount);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'Over {amount}'**
  String salonPriceOver(String amount);

  /// Salons
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String salonPriceRange(String min, String max);

  /// Delete account
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account and personal data'**
  String get deleteAccountSubtitle;

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete your account permanently?'**
  String get deleteAccountConfirmTitle;

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Your name, number, photo, addresses, saved cards, basket, wishlists, follows and notifications will be erased, and your posts and comments removed. Orders, invoices and payment records are kept anonymously because the law requires it, and reviews you wrote stay under \"Deleted account\". This cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deleteAccountConfirmButton;

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Your account can\'t be deleted yet'**
  String get deleteAccountBlockedTitle;

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Settle these first, then try again.'**
  String get deleteAccountBlockedHint;

  /// Account deletion blocker
  ///
  /// In en, this message translates to:
  /// **'Staff accounts are closed by an administrator.'**
  String get deletionBlockerStaff;

  /// Account deletion blocker
  ///
  /// In en, this message translates to:
  /// **'{count} of your orders are still in progress.'**
  String deletionBlockerOpenOrders(int count);

  /// Account deletion blocker
  ///
  /// In en, this message translates to:
  /// **'{count} orders from your shop are still in progress.'**
  String deletionBlockerOpenSales(int count);

  /// Account deletion blocker
  ///
  /// In en, this message translates to:
  /// **'Your wallet still holds a balance.'**
  String get deletionBlockerWallet;

  /// Account deletion blocker
  ///
  /// In en, this message translates to:
  /// **'{count} payouts to you are still pending.'**
  String deletionBlockerPayouts(int count);

  /// Account deletion blocker
  ///
  /// In en, this message translates to:
  /// **'{count} appointments are still upcoming.'**
  String deletionBlockerAppointments(int count);

  /// Account deletion
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// How many boutiques the basket's pieces come from
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 boutique} other{{count} boutiques}}'**
  String cartBoutiquesCount(int count);

  /// Checkout station: whether the boutique sees her full name
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get checkoutStepPrivacy;

  /// Under the public audience option
  ///
  /// In en, this message translates to:
  /// **'Everyone can see it'**
  String get composerAudiencePublicHint;

  /// Under the followers-only audience option
  ///
  /// In en, this message translates to:
  /// **'Only your followers'**
  String get composerAudienceFollowersHint;

  /// Heading over the row of people online in the inbox
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get chatsOnlineRail;

  /// Inbox section: conversations with unread messages
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get chatsSectionNew;

  /// Inbox section: conversations read already
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get chatsSectionEarlier;

  /// Over the suggested first questions in an empty conversation
  ///
  /// In en, this message translates to:
  /// **'Ask in one tap'**
  String get chatSuggestTitle;

  /// Suggested first question
  ///
  /// In en, this message translates to:
  /// **'Is this piece available?'**
  String get chatSuggestAvailable;

  /// Suggested first question
  ///
  /// In en, this message translates to:
  /// **'Which sizes are available?'**
  String get chatSuggestSizes;

  /// Suggested first question
  ///
  /// In en, this message translates to:
  /// **'How long does delivery take?'**
  String get chatSuggestDelivery;

  /// Shell action — her calendar of occasions
  ///
  /// In en, this message translates to:
  /// **'My occasions'**
  String get actionOccasions;

  /// Occasions: page title
  ///
  /// In en, this message translates to:
  /// **'My occasions'**
  String get occasionsTitle;

  /// Occasions: upcoming tab
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get occasionsUpcoming;

  /// Occasions: past tab
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get occasionsPast;

  /// Occasions: list failed to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your occasions'**
  String get occasionsLoadError;

  /// Occasions: empty upcoming list title
  ///
  /// In en, this message translates to:
  /// **'Nothing on the calendar yet'**
  String get occasionsEmptyTitle;

  /// Occasions: empty upcoming list body
  ///
  /// In en, this message translates to:
  /// **'Add a wedding, Eid or birthday and we\'ll help you get ready: your look, the salon, the gift — and a reminder before the day.'**
  String get occasionsEmptyBody;

  /// Occasions: empty past list title
  ///
  /// In en, this message translates to:
  /// **'No past occasions'**
  String get occasionsPastEmptyTitle;

  /// Occasions: empty past list body
  ///
  /// In en, this message translates to:
  /// **'Write down what you wore to past occasions, and we\'ll tell you before the same people see it twice.'**
  String get occasionsPastEmptyBody;

  /// Occasions: add action
  ///
  /// In en, this message translates to:
  /// **'Add an occasion'**
  String get occasionAdd;

  /// Occasions: editor title when creating
  ///
  /// In en, this message translates to:
  /// **'New occasion'**
  String get occasionNew;

  /// Occasions: editor title when editing
  ///
  /// In en, this message translates to:
  /// **'Edit occasion'**
  String get occasionEdit;

  /// Occasions: detail failed to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this occasion'**
  String get occasionLoadError;

  /// Occasions: kind picker label
  ///
  /// In en, this message translates to:
  /// **'What kind of day is it?'**
  String get occasionKindQuestion;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get occasionKindWedding;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get occasionKindEngagement;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Henna night'**
  String get occasionKindHenna;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Eid'**
  String get occasionKindEid;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get occasionKindBirthday;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Graduation'**
  String get occasionKindGraduation;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Evening out'**
  String get occasionKindEvening;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Family visit'**
  String get occasionKindFamilyVisit;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Work event'**
  String get occasionKindWork;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get occasionKindTravel;

  /// Occasion kind
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get occasionKindOther;

  /// Occasions: title field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get occasionTitleLabel;

  /// Occasions: title field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Sara\'s wedding'**
  String get occasionTitleHint;

  /// Occasions: date row label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get occasionDateLabel;

  /// Occasions: date row placeholder
  ///
  /// In en, this message translates to:
  /// **'Choose the day'**
  String get occasionDatePick;

  /// Occasions: time row label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get occasionTimeLabel;

  /// Occasions: optional field placeholder
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get occasionOptional;

  /// Occasions: clear a picked value
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get occasionClear;

  /// Occasions: circle field label
  ///
  /// In en, this message translates to:
  /// **'Who\'ll be there?'**
  String get occasionCircleLabel;

  /// Occasions: circle field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. my husband\'s family'**
  String get occasionCircleHint;

  /// Occasions: why the circle is asked
  ///
  /// In en, this message translates to:
  /// **'So we can tell you if they\'ve already seen your outfit'**
  String get occasionCircleHelper;

  /// Occasions: location field label
  ///
  /// In en, this message translates to:
  /// **'Place (optional)'**
  String get occasionLocationLabel;

  /// Occasions: note field label and section
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get occasionNoteLabel;

  /// Occasions: reminders switch
  ///
  /// In en, this message translates to:
  /// **'Countdown reminders'**
  String get occasionReminders;

  /// Occasions: reminders switch explanation
  ///
  /// In en, this message translates to:
  /// **'A week before, three days before, and the day before — in the daytime only'**
  String get occasionRemindersHint;

  /// Occasions: create button
  ///
  /// In en, this message translates to:
  /// **'Add occasion'**
  String get occasionCreate;

  /// Occasions: save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get occasionSave;

  /// Occasions: saved snackbar
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get occasionSaved;

  /// Occasions: write failed
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save — check your connection and try again'**
  String get occasionSaveFailed;

  /// Occasions: delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get occasionDelete;

  /// Occasions: delete confirm title
  ///
  /// In en, this message translates to:
  /// **'Delete this occasion?'**
  String get occasionDeleteTitle;

  /// Occasions: delete confirm body
  ///
  /// In en, this message translates to:
  /// **'Your look and your salon booking stay as they are.'**
  String get occasionDeleteBody;

  /// Occasions: countdown for a past day
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get occasionPassed;

  /// Occasions: countdown for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get occasionToday;

  /// Occasions: countdown for tomorrow
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get occasionTomorrow;

  /// Occasions: countdown
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{In 1 day} other{In {days} days}}'**
  String occasionInDays(int days);

  /// Occasions: progress under the bar
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} ready'**
  String occasionProgress(int done, int total);

  /// Occasions: every step done
  ///
  /// In en, this message translates to:
  /// **'You\'re all set ✨'**
  String get occasionAllReady;

  /// Occasions: next step
  ///
  /// In en, this message translates to:
  /// **'Next: choose your look'**
  String get occasionNextLook;

  /// Occasions: next step
  ///
  /// In en, this message translates to:
  /// **'Next: order the missing pieces'**
  String get occasionNextPieces;

  /// Occasions: next step
  ///
  /// In en, this message translates to:
  /// **'Next: book the salon'**
  String get occasionNextSalon;

  /// Occasions: next step
  ///
  /// In en, this message translates to:
  /// **'Next: the gift'**
  String get occasionNextGift;

  /// Occasions: nothing to do but wait
  ///
  /// In en, this message translates to:
  /// **'Waiting for the salon to confirm'**
  String get occasionNextWaiting;

  /// Occasions: past card look line
  ///
  /// In en, this message translates to:
  /// **'You wore: {look}'**
  String occasionWore(String look);

  /// Occasions: checklist heading
  ///
  /// In en, this message translates to:
  /// **'Getting ready'**
  String get occasionPlanTitle;

  /// Occasions: look step
  ///
  /// In en, this message translates to:
  /// **'Choose your look'**
  String get occasionStepLook;

  /// Occasions: look step done
  ///
  /// In en, this message translates to:
  /// **'Your look'**
  String get occasionStepLookDone;

  /// Occasions: look step hint
  ///
  /// In en, this message translates to:
  /// **'From the looks in your closet'**
  String get occasionStepLookHint;

  /// Occasions: missing pieces step
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your look is one piece short} other{Your look is {count} pieces short}}'**
  String occasionStepPieces(int count);

  /// Occasions: missing pieces hint
  ///
  /// In en, this message translates to:
  /// **'Order early so it arrives in time'**
  String get occasionStepPiecesHint;

  /// Occasions: missing pieces urgent hint
  ///
  /// In en, this message translates to:
  /// **'Delivery takes days — order today'**
  String get occasionStepPiecesUrgent;

  /// Occasions: salon step
  ///
  /// In en, this message translates to:
  /// **'Book the salon'**
  String get occasionStepSalon;

  /// Occasions: salon step done
  ///
  /// In en, this message translates to:
  /// **'Salon booked'**
  String get occasionStepSalonDone;

  /// Occasions: salon step pending
  ///
  /// In en, this message translates to:
  /// **'Salon requested'**
  String get occasionStepSalonWaiting;

  /// Occasions: salon step hint
  ///
  /// In en, this message translates to:
  /// **'Good hours go fast before big days'**
  String get occasionStepSalonHint;

  /// Occasions: salon step urgent hint
  ///
  /// In en, this message translates to:
  /// **'Only a few days left — book now'**
  String get occasionStepSalonUrgent;

  /// Occasions: salon pending hint
  ///
  /// In en, this message translates to:
  /// **'Waiting for the salon to confirm'**
  String get occasionStepSalonWaitingHint;

  /// Occasions: gift step
  ///
  /// In en, this message translates to:
  /// **'The gift'**
  String get occasionStepGift;

  /// Occasions: gift step done
  ///
  /// In en, this message translates to:
  /// **'Gift ready'**
  String get occasionStepGiftDone;

  /// Occasions: choose look action and sheet title
  ///
  /// In en, this message translates to:
  /// **'Choose a look'**
  String get occasionChooseLook;

  /// Occasions: change the chosen look
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get occasionChangeLook;

  /// Occasions: unlink the look
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get occasionRemoveLook;

  /// Occasions: go to the look to fill its gaps
  ///
  /// In en, this message translates to:
  /// **'Complete the look'**
  String get occasionCompleteLook;

  /// Occasions: look picker empty
  ///
  /// In en, this message translates to:
  /// **'Put a look together in your closet, then come back and choose it.'**
  String get occasionNoLooksBody;

  /// Occasions: go to the salon directory
  ///
  /// In en, this message translates to:
  /// **'Find a salon'**
  String get occasionFindSalon;

  /// Occasions: attach an existing appointment
  ///
  /// In en, this message translates to:
  /// **'Link a booking'**
  String get occasionLinkBooking;

  /// Occasions: detach the appointment
  ///
  /// In en, this message translates to:
  /// **'Unlink booking'**
  String get occasionUnlinkBooking;

  /// Occasions: linked appointment no longer live
  ///
  /// In en, this message translates to:
  /// **'Your booking at {salon} was cancelled'**
  String occasionSalonCancelled(String salon);

  /// Occasions: repeat warning heading
  ///
  /// In en, this message translates to:
  /// **'{circle} have seen this before'**
  String occasionRepeatTitle(String circle);

  /// Occasions: repeat warning — an occasion that passed
  ///
  /// In en, this message translates to:
  /// **'At {occasion}'**
  String occasionRepeatWorn(String occasion);

  /// Occasions: repeat warning — an occasion still to come
  ///
  /// In en, this message translates to:
  /// **'Also planned for {occasion}'**
  String occasionRepeatPlanned(String occasion);

  /// Occasions: repeat warning — same look
  ///
  /// In en, this message translates to:
  /// **'The very same look'**
  String get occasionRepeatSameLook;

  /// Occasions: repeat warning — shared pieces
  ///
  /// In en, this message translates to:
  /// **'Same pieces: {pieces}'**
  String occasionRepeatSamePieces(String pieces);

  /// Occasions: repeat warning footer
  ///
  /// In en, this message translates to:
  /// **'Want to change a piece, or is it fine?'**
  String get occasionRepeatHint;

  /// Occasions: list separator between piece names
  ///
  /// In en, this message translates to:
  /// **', '**
  String get occasionListSeparator;

  /// Occasions: past occasion look heading
  ///
  /// In en, this message translates to:
  /// **'What you wore'**
  String get occasionPastLookTitle;

  /// Occasions: past occasion without a look
  ///
  /// In en, this message translates to:
  /// **'You didn\'t record a look for this day. Add one so we can warn you before a repeat.'**
  String get occasionPastNoLook;

  /// Post menu: edit her own post, reel or story
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get postMenuEdit;

  /// Edit sheet title for her own content
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get contentEditTitle;

  /// Edit sheet: save button
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get contentEditSave;

  /// Snackbar after an edit
  ///
  /// In en, this message translates to:
  /// **'Your changes are saved'**
  String get contentEdited;

  /// Snackbar after an edit that sent the piece back to moderation
  ///
  /// In en, this message translates to:
  /// **'Saved — it\'s back with our team for a quick look before it shows again'**
  String get contentEditedUnderReview;

  /// Who watched her own story or reel
  ///
  /// In en, this message translates to:
  /// **'Seen by'**
  String get audienceTitle;

  /// Audience sheet: distinct viewers
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get audienceViewers;

  /// Audience sheet: total plays
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get audienceViews;

  /// Audience sheet: reactions
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get audienceReactions;

  /// Audience sheet: empty state title
  ///
  /// In en, this message translates to:
  /// **'Nobody has seen it yet'**
  String get audienceEmpty;

  /// Audience sheet: empty state body
  ///
  /// In en, this message translates to:
  /// **'When someone watches it, you\'ll find them here.'**
  String get audienceEmptyBody;

  /// Report sheet: free-text step for 'something else'
  ///
  /// In en, this message translates to:
  /// **'Tell us a little more'**
  String get reportDetailTitle;

  /// Report detail field label
  ///
  /// In en, this message translates to:
  /// **'What\'s wrong with it?'**
  String get reportDetailLabel;

  /// Report detail field hint
  ///
  /// In en, this message translates to:
  /// **'Optional — a few words help our team act faster'**
  String get reportDetailHint;

  /// Report detail: send button
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// Story menu: delete her own story
  ///
  /// In en, this message translates to:
  /// **'Delete story'**
  String get storyMenuDelete;

  /// Story menu: report somebody else's story
  ///
  /// In en, this message translates to:
  /// **'Report story'**
  String get storyMenuReport;

  /// Delete story confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete this story?'**
  String get storyDeleteTitle;

  /// Delete story confirmation body
  ///
  /// In en, this message translates to:
  /// **'It disappears for everyone straight away, and from any highlight it was in.'**
  String get storyDeleteBody;

  /// Snackbar after deleting a story
  ///
  /// In en, this message translates to:
  /// **'Story deleted'**
  String get storyDeleted;

  /// Story: open the tagged product
  ///
  /// In en, this message translates to:
  /// **'Shop this piece'**
  String get storyShopThis;

  /// Composer: a story made of photographs
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get composerStoryPhoto;

  /// Composer: a story that is one clip
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get composerStoryVideo;

  /// Fit: runs small
  ///
  /// In en, this message translates to:
  /// **'Runs small'**
  String get fitRunsSmall;

  /// Fit: true to size
  ///
  /// In en, this message translates to:
  /// **'True to size'**
  String get fitTrueToSize;

  /// Fit: runs large
  ///
  /// In en, this message translates to:
  /// **'Runs large'**
  String get fitRunsLarge;

  /// Fit summary verdict
  ///
  /// In en, this message translates to:
  /// **'Most say it runs small — consider a size up'**
  String get fitVerdictSmall;

  /// Fit summary verdict
  ///
  /// In en, this message translates to:
  /// **'Most say it is true to size'**
  String get fitVerdictTrue;

  /// Fit summary verdict
  ///
  /// In en, this message translates to:
  /// **'Most say it runs large — consider a size down'**
  String get fitVerdictLarge;

  /// Fit summary: no majority
  ///
  /// In en, this message translates to:
  /// **'Opinions differ on the fit'**
  String get fitOpinionsDiffer;

  /// Fit panel title
  ///
  /// In en, this message translates to:
  /// **'How it fits, from women who wore it'**
  String get fitPanelTitle;

  /// Fit panel: overall heading
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 woman said} other{{count} women said}}'**
  String fitEveryone(int count);

  /// Fit panel: near-me heading
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 woman your size} other{{count} women your size}}'**
  String fitLikeYou(int count);

  /// Fit panel: no near-me voices
  ///
  /// In en, this message translates to:
  /// **'No women your size have said yet'**
  String get fitLikeYouNone;

  /// Fit panel: suggested size
  ///
  /// In en, this message translates to:
  /// **'Women your size kept a {size} and said it fits'**
  String fitSuggestedSize(String size);

  /// Fit panel: prompt to set profile
  ///
  /// In en, this message translates to:
  /// **'See what women your size said'**
  String get fitSeeLikeYou;

  /// Review card: size that shipped
  ///
  /// In en, this message translates to:
  /// **'Bought: {size}'**
  String fitBoughtSize(String size);

  /// Review card: photo semantics
  ///
  /// In en, this message translates to:
  /// **'Open photo {index}'**
  String fitPhotoOpen(int index);

  /// Composer: fit question
  ///
  /// In en, this message translates to:
  /// **'How did it fit?'**
  String get fitQuestion;

  /// Composer: photos field
  ///
  /// In en, this message translates to:
  /// **'Photos of the piece (optional)'**
  String get fitPhotosLabel;

  /// Composer: photos privacy helper
  ///
  /// In en, this message translates to:
  /// **'Photograph the piece itself — there\'s no need to appear in it. Photos are shown to everyone once your review is approved.'**
  String get fitPhotosHelper;

  /// Composer: share fit switch
  ///
  /// In en, this message translates to:
  /// **'Use my height and size to match this review'**
  String get fitShareOnReview;

  /// Composer: share fit hint
  ///
  /// In en, this message translates to:
  /// **'They are never shown — they only help women your size find your review'**
  String get fitShareOnReviewHint;

  /// Composer: prompt to set profile
  ///
  /// In en, this message translates to:
  /// **'Add your height and size (never shown) to help women like you'**
  String get fitAddProfilePrompt;

  /// Reviews: set profile action
  ///
  /// In en, this message translates to:
  /// **'Add my size'**
  String get fitAddProfileShort;

  /// Fit profile: title and menu row
  ///
  /// In en, this message translates to:
  /// **'My size'**
  String get fitProfileTitle;

  /// Fit profile: load failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your size'**
  String get fitProfileLoadError;

  /// Fit profile: privacy note
  ///
  /// In en, this message translates to:
  /// **'Only you see this. Your height and size never appear on your reviews or anywhere else — we use them only to show you reviews from women like you, and to count the fit summary without names.'**
  String get fitProfilePrivacy;

  /// Fit profile: height field
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get fitHeightLabel;

  /// Fit profile: height hint
  ///
  /// In en, this message translates to:
  /// **'e.g. 162'**
  String get fitHeightHint;

  /// Fit profile: unit
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get fitCentimetres;

  /// Fit profile: height out of range
  ///
  /// In en, this message translates to:
  /// **'Enter a height between {min} and {max} cm'**
  String fitHeightInvalid(int min, int max);

  /// Fit profile: size picker
  ///
  /// In en, this message translates to:
  /// **'The size you usually wear'**
  String get fitUsualSizeLabel;

  /// Fit profile: share default
  ///
  /// In en, this message translates to:
  /// **'Use them for my reviews'**
  String get fitShareDefault;

  /// Fit profile: share default hint
  ///
  /// In en, this message translates to:
  /// **'So women your size can find your reviews. Nothing is shown. You can turn it off on any one review.'**
  String get fitShareDefaultHint;

  /// Fit profile: save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get fitProfileSave;

  /// Fit profile: saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get fitProfileSaved;

  /// Product reviews filter
  ///
  /// In en, this message translates to:
  /// **'Women my size'**
  String get reviewsFilterNearMe;

  /// Product reviews filter
  ///
  /// In en, this message translates to:
  /// **'With photos'**
  String get reviewsFilterPhotos;

  /// Near-me filter without a profile
  ///
  /// In en, this message translates to:
  /// **'Tell us your size first'**
  String get reviewsNearMeNeedsProfileTitle;

  /// Near-me filter without a profile
  ///
  /// In en, this message translates to:
  /// **'Add your height and size and we\'ll show reviews from women like you.'**
  String get reviewsNearMeNeedsProfileBody;

  /// Near-me filter empty
  ///
  /// In en, this message translates to:
  /// **'No reviews from women your size yet'**
  String get reviewsNearMeNoneTitle;

  /// Near-me filter empty
  ///
  /// In en, this message translates to:
  /// **'Be the first: your review will help the next woman your size.'**
  String get reviewsNearMeNoneBody;

  /// Photos filter empty
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get reviewsPhotosNoneTitle;

  /// Photos filter empty
  ///
  /// In en, this message translates to:
  /// **'Reviews with photos of the piece on will appear here.'**
  String get reviewsPhotosNoneBody;

  /// No description provided for @forYouRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from For You'**
  String get forYouRemove;

  /// No description provided for @forYouRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from For You — you won\'t see it there again.'**
  String get forYouRemoved;

  /// No description provided for @chatProductInquiry.
  ///
  /// In en, this message translates to:
  /// **'Asking about this piece'**
  String get chatProductInquiry;

  /// No description provided for @chatAskingAbout.
  ///
  /// In en, this message translates to:
  /// **'You\'re asking about'**
  String get chatAskingAbout;

  /// No description provided for @chatAskingAboutClear.
  ///
  /// In en, this message translates to:
  /// **'Remove the piece from the message'**
  String get chatAskingAboutClear;

  /// No description provided for @productAskBoutique.
  ///
  /// In en, this message translates to:
  /// **'Ask the boutique'**
  String get productAskBoutique;

  /// Unique views of a product page: one per person per day.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 view} other{{label} views}}'**
  String productStatViews(int count, String label);

  /// How many shoppers keep this product in their favourites.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In 1 favourites list} other{In {label} favourites lists}}'**
  String productStatSaves(int count, String label);

  /// Units of this product sold in orders that were not cancelled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sold} other{{label} sold}}'**
  String productStatSold(int count, String label);

  /// No description provided for @reviewsRatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap the stars to rate this piece'**
  String get reviewsRatePrompt;

  /// What the chosen number of stars means, shown under the stars in the review composer.
  ///
  /// In en, this message translates to:
  /// **'{stars, select, 1{Poor} 2{Fair} 3{Good} 4{Very good} 5{Excellent} other{}}'**
  String reviewsRatingMeaning(String stars);

  /// Screen-reader label for a review's stars.
  ///
  /// In en, this message translates to:
  /// **'Rated {stars} out of 5'**
  String reviewsRatedOutOfFive(int stars);

  /// No description provided for @mapPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pin your location'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a neighbourhood, street or landmark…'**
  String get mapPickerSearchHint;

  /// No description provided for @mapPickerMoveHint.
  ///
  /// In en, this message translates to:
  /// **'Move the map to put the pin at your door'**
  String get mapPickerMoveHint;

  /// No description provided for @mapPickerLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding you…'**
  String get mapPickerLocating;

  /// No description provided for @mapPickerReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the address…'**
  String get mapPickerReading;

  /// No description provided for @mapPickerDeliveryHere.
  ///
  /// In en, this message translates to:
  /// **'Delivery spot'**
  String get mapPickerDeliveryHere;

  /// No description provided for @mapPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get mapPickerConfirm;

  /// No description provided for @mapPickerUnknownPlace.
  ///
  /// In en, this message translates to:
  /// **'An unnamed spot on the map'**
  String get mapPickerUnknownPlace;

  /// No description provided for @mapPickerUnknownPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'That\'s fine — the pin is enough, and you can add the details next'**
  String get mapPickerUnknownPlaceHint;

  /// No description provided for @mapPickerOutsideSyria.
  ///
  /// In en, this message translates to:
  /// **'This spot is outside Syria — we only deliver inside Syria for now'**
  String get mapPickerOutsideSyria;

  /// No description provided for @mapPickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found — try a nearby name'**
  String get mapPickerNoResults;

  /// No description provided for @mapPickerMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get mapPickerMyLocation;

  /// No description provided for @mapPickerStreets.
  ///
  /// In en, this message translates to:
  /// **'Streets'**
  String get mapPickerStreets;

  /// No description provided for @mapPickerSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapPickerSatellite;

  /// No description provided for @mapPickerResetNorth.
  ///
  /// In en, this message translates to:
  /// **'Point north'**
  String get mapPickerResetNorth;

  /// No description provided for @mapPickerZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get mapPickerZoomIn;

  /// No description provided for @mapPickerZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mapPickerZoomOut;

  /// No description provided for @mapPickerRural.
  ///
  /// In en, this message translates to:
  /// **'Rural area'**
  String get mapPickerRural;

  /// No description provided for @mapPickerLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone'**
  String get mapPickerLocationOff;

  /// No description provided for @mapPickerLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'The app wasn\'t allowed to see your location'**
  String get mapPickerLocationDenied;

  /// No description provided for @mapPickerLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a fix — move the map by hand'**
  String get mapPickerLocationUnavailable;

  /// No description provided for @mapPickerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mapPickerOpenSettings;

  /// Location accuracy radius
  ///
  /// In en, this message translates to:
  /// **'±{meters} m'**
  String mapPickerAccuracy(int meters);

  /// No description provided for @mapPickerJumpTo.
  ///
  /// In en, this message translates to:
  /// **'Jump to a governorate'**
  String get mapPickerJumpTo;

  /// No description provided for @locationFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Pin your location on the map'**
  String get locationFieldTitle;

  /// No description provided for @locationFieldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Faster than typing — we\'ll fill the address for you'**
  String get locationFieldSubtitle;

  /// No description provided for @locationFieldOr.
  ///
  /// In en, this message translates to:
  /// **'or type the address yourself'**
  String get locationFieldOr;

  /// No description provided for @locationFieldChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get locationFieldChange;

  /// No description provided for @locationFieldRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the pin'**
  String get locationFieldRemove;

  /// No description provided for @locationFieldPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned on the map'**
  String get locationFieldPinned;

  /// No description provided for @locationFieldFilled.
  ///
  /// In en, this message translates to:
  /// **'We filled the address from the map — give it a quick look'**
  String get locationFieldFilled;

  /// No description provided for @locationFieldEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit the address details'**
  String get locationFieldEditDetails;

  /// No description provided for @locationFieldHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide the details'**
  String get locationFieldHideDetails;

  /// No description provided for @locationFieldGovernorateUnmatched.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t tell the governorate from the map — please pick it below'**
  String get locationFieldGovernorateUnmatched;

  /// No description provided for @locationFieldOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get locationFieldOpenInMaps;

  /// No description provided for @shopLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pin your place on the map'**
  String get shopLocationTitle;

  /// No description provided for @shopLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll fill the address, and clients will see exactly where you are'**
  String get shopLocationSubtitle;

  /// No description provided for @businessLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll write the business address from the map'**
  String get businessLocationSubtitle;

  /// No description provided for @mapPickerShopHere.
  ///
  /// In en, this message translates to:
  /// **'Your place'**
  String get mapPickerShopHere;

  /// No description provided for @mapPickerZoomCloser.
  ///
  /// In en, this message translates to:
  /// **'Zoom in to pin the exact door'**
  String get mapPickerZoomCloser;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add a piece'**
  String get closetActionAdd;

  ///
  ///
  /// In en, this message translates to:
  /// **'Today\'s outfit'**
  String get closetActionToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'Extra details'**
  String get closetAddExtras;

  ///
  ///
  /// In en, this message translates to:
  /// **'Name the piece and pick its type to save it.'**
  String get closetAddNeeds;

  ///
  ///
  /// In en, this message translates to:
  /// **'Uploading the photo…'**
  String get closetAddUploading;

  ///
  ///
  /// In en, this message translates to:
  /// **'Already logged as worn today.'**
  String get closetAlreadyWornToday;

  ///
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String closetBudgetRange(String min, String max);

  ///
  ///
  /// In en, this message translates to:
  /// **'Up to {max}'**
  String closetBudgetUpTo(String max);

  ///
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get closetClearFilters;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete this piece for good?'**
  String get closetDeleteConfirmTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The piece and its whole wear history will be erased and it will leave your looks. If you simply no longer own it, choose “No longer mine” to keep its history.'**
  String get closetDeleteConfirmBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Erases the piece and all its history'**
  String get closetDeleteHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Piece deleted.'**
  String get closetDeleted;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete this look?'**
  String get closetDeleteLookConfirmTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Only the look is deleted — its pieces stay in your closet.'**
  String get closetDeleteLookConfirmBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get closetDetailColours;

  ///
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get closetDetailMaterial;

  ///
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get closetDetailModesty;

  ///
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get closetDetailSeasons;

  ///
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get closetDetailSize;

  ///
  ///
  /// In en, this message translates to:
  /// **'Hide this suggestion?'**
  String get closetDismissConfirmTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'We won\'t suggest this gap again, even as your closet changes.'**
  String get closetDismissConfirmBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get closetFavouriteTag;

  ///
  ///
  /// In en, this message translates to:
  /// **'No pieces match'**
  String get closetFilterEmptyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try another word, or clear the filters to see your whole closet.'**
  String get closetFilterEmptyBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get closetFilterFavourites;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shelved'**
  String get closetFilterShelved;

  ///
  ///
  /// In en, this message translates to:
  /// **'Fit with your closet'**
  String get closetFitWithWardrobe;

  ///
  ///
  /// In en, this message translates to:
  /// **'From your stylist'**
  String get closetFromStylist;

  ///
  ///
  /// In en, this message translates to:
  /// **'Opens new outfits'**
  String get closetGapKindCoverage;

  ///
  ///
  /// In en, this message translates to:
  /// **'Completes a look'**
  String get closetGapKindLook;

  ///
  ///
  /// In en, this message translates to:
  /// **'For an occasion'**
  String get closetGapKindOccasion;

  ///
  ///
  /// In en, this message translates to:
  /// **'A replacement'**
  String get closetGapKindReplacement;

  ///
  ///
  /// In en, this message translates to:
  /// **'For the season'**
  String get closetGapKindSeason;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 outfit} other{+{count} outfits}}'**
  String closetGapUnlocks(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Worth buying'**
  String get closetGapsEyebrow;

  ///
  ///
  /// In en, this message translates to:
  /// **'How your closet works'**
  String get closetHowItWorks;

  ///
  ///
  /// In en, this message translates to:
  /// **'Every wear brings the cost per wear down.'**
  String get closetInsightCostFalls;

  ///
  ///
  /// In en, this message translates to:
  /// **'It\'s been over three months — maybe it\'s time for a new look with it.'**
  String get closetInsightForgotten;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not worn yet. Try styling it this week.'**
  String get closetInsightNeverWorn;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{A staple — worn {count} times.}}'**
  String closetInsightStaple(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Not worn yet'**
  String get closetLookNotWornYet;

  ///
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get closetLookPalette;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pieces} =1{1 piece} other{{count} pieces}}'**
  String closetLookPieceCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its piece} other{Its {count} pieces}}'**
  String closetLookPieces(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'No looks here yet'**
  String get closetLooksFilterEmpty;

  ///
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get closetLooksFilterReady;

  ///
  ///
  /// In en, this message translates to:
  /// **'Missing pieces'**
  String get closetLooksFilterShort;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 look is one piece away} other{{count} looks are one piece away}}'**
  String closetLooksOneAway(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} ready to wear now'**
  String closetLooksReadyOf(int ready, int total);

  ///
  ///
  /// In en, this message translates to:
  /// **'Manage this piece'**
  String get closetManageTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more idea} other{{count} more ideas}}'**
  String closetMoreIdeas(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get closetOptional;

  ///
  ///
  /// In en, this message translates to:
  /// **'Put together for you'**
  String get closetOriginComposed;

  ///
  ///
  /// In en, this message translates to:
  /// **'From your looks'**
  String get closetOriginSaved;

  ///
  ///
  /// In en, this message translates to:
  /// **'{value} / 100'**
  String closetPriorityOutOf(String value);

  ///
  ///
  /// In en, this message translates to:
  /// **'Every outfit you own suits the weather right now.'**
  String get closetPulseAllSeason;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your closet this {season}'**
  String closetPulseEyebrow(String season);

  ///
  ///
  /// In en, this message translates to:
  /// **'outfits you can wear now from your pieces'**
  String get closetPulseHeadline;

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent}% of your outfits suit the season'**
  String closetPulseReadiness(int percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'looks ready'**
  String get closetPulseReadyLooks;

  ///
  ///
  /// In en, this message translates to:
  /// **'season-ready'**
  String get closetPulseSeasonReady;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces you haven\'t worn in a while, or ever. One wear brings them back.'**
  String get closetRediscoverBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Rediscover'**
  String get closetRediscoverEyebrow;

  ///
  ///
  /// In en, this message translates to:
  /// **'Pieces waiting for you'**
  String get closetRediscoverTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'No longer yours?'**
  String get closetReleaseConfirmTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'It leaves your closet and looks; we keep its wear history so we can suggest a replacement when you need one.'**
  String get closetReleaseConfirmBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Sold or gave it away — we keep its history'**
  String get closetReleaseHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Removed from your closet.'**
  String get closetReleased;

  ///
  ///
  /// In en, this message translates to:
  /// **'Bring it back into your closet and suggestions'**
  String get closetReturnHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Back in your closet.'**
  String get closetReturned;

  ///
  ///
  /// In en, this message translates to:
  /// **'Its life in your closet'**
  String get closetRotationTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Search by name, brand or note'**
  String get closetSearchHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'{season} season'**
  String closetSeasonNow(String season);

  ///
  ///
  /// In en, this message translates to:
  /// **'Not for this season — hidden from suggestions'**
  String get closetShelveHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'Shelved for another season.'**
  String get closetShelved;

  ///
  ///
  /// In en, this message translates to:
  /// **'This piece is shelved and left out of today\'s suggestions.'**
  String get closetShelvedBanner;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing on the shelf'**
  String get closetShelvedEmpty;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 piece short} other{{count} pieces short}}'**
  String closetShortBy(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get closetShowAll;

  ///
  ///
  /// In en, this message translates to:
  /// **'Least worn'**
  String get closetSortLeastWorn;

  ///
  ///
  /// In en, this message translates to:
  /// **'Most worn'**
  String get closetSortMostWorn;

  ///
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get closetSortRecent;

  ///
  ///
  /// In en, this message translates to:
  /// **'Sort pieces'**
  String get closetSortTooltip;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add your pieces'**
  String get closetStepAddTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Bring in your Ohara purchases in one tap, or photograph what you own.'**
  String get closetStepAddBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'We put outfits together'**
  String get closetStepLooksTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Every morning we suggest what to wear from your own pieces, for the weather and the occasion.'**
  String get closetStepLooksBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'We tell you what\'s missing'**
  String get closetStepGapsTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'One piece can open many outfits — and we show you why.'**
  String get closetStepGapsBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 suggestion} other{{count} suggestions}}'**
  String closetSuggestionsEyebrow(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Forgotten'**
  String get closetTagForgotten;

  ///
  ///
  /// In en, this message translates to:
  /// **'Unworn'**
  String get closetTagUnworn;

  ///
  ///
  /// In en, this message translates to:
  /// **'Enlarge'**
  String get closetTapToEnlarge;

  ///
  ///
  /// In en, this message translates to:
  /// **'Best for today'**
  String get closetTodayBestMatch;

  ///
  ///
  /// In en, this message translates to:
  /// **'Today\'s pick'**
  String get closetTodayEyebrow;

  ///
  ///
  /// In en, this message translates to:
  /// **'All from your own pieces'**
  String get closetTodayFromYours;

  ///
  ///
  /// In en, this message translates to:
  /// **'Good morning, stylish'**
  String get closetTodayHello;

  ///
  ///
  /// In en, this message translates to:
  /// **'Idea {number}'**
  String closetTodayIdea(int number);

  ///
  ///
  /// In en, this message translates to:
  /// **'From your own pieces, for {season}'**
  String closetTodaySeason(String season);

  ///
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get closetUndo;

  ///
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that. Please try again.'**
  String get closetUpdateFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Compact view'**
  String get closetViewCompact;

  ///
  ///
  /// In en, this message translates to:
  /// **'Large view'**
  String get closetViewLarge;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pieces} =1{1 piece} other{{count} pieces}}'**
  String closetWardrobeEyebrow(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'My pieces'**
  String get closetWardrobeTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log the wear. Please try again.'**
  String get closetWearFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Logged “{title}” as worn today.'**
  String closetWearLogged(String title);

  ///
  ///
  /// In en, this message translates to:
  /// **'Wear removed.'**
  String get closetWearUndone;

  ///
  ///
  /// In en, this message translates to:
  /// **'Worn today'**
  String get closetWornTodayDone;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not worn yet'**
  String get closetWornNeverShort;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not worn in a while'**
  String get closetWornLongAgoShort;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Worn once} other{Worn {count} times}}'**
  String closetWornTimes(int count);

  /// Advertising plan name: free
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get adTierFree;

  /// Advertising plan name
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get adTierSilver;

  /// Advertising plan name
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get adTierGold;

  /// Advertising plan name
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get adTierDiamond;

  /// Badge on a boutique that pays for an advertising plan
  ///
  /// In en, this message translates to:
  /// **'{tier} store'**
  String storeTierBadge(String tier);

  /// Ad placement
  ///
  /// In en, this message translates to:
  /// **'Top of search'**
  String get adPlacementSearch;

  /// Ad placement
  ///
  /// In en, this message translates to:
  /// **'Category page'**
  String get adPlacementCategory;

  /// Ad placement
  ///
  /// In en, this message translates to:
  /// **'Top of the feed'**
  String get adPlacementFeedTop;

  /// Ad placement
  ///
  /// In en, this message translates to:
  /// **'Home spotlight'**
  String get adPlacementHomeSpotlight;

  /// adPlacementSearchHint
  ///
  /// In en, this message translates to:
  /// **'Above the results when shoppers search for pieces like yours'**
  String get adPlacementSearchHint;

  /// adPlacementCategoryHint
  ///
  /// In en, this message translates to:
  /// **'At the top of the shelf your piece belongs to'**
  String get adPlacementCategoryHint;

  /// adPlacementFeedTopHint
  ///
  /// In en, this message translates to:
  /// **'Your post pinned above every post in the community'**
  String get adPlacementFeedTopHint;

  /// adPlacementHomeSpotlightHint
  ///
  /// In en, this message translates to:
  /// **'The first thing shoppers see when they open the app'**
  String get adPlacementHomeSpotlightHint;

  /// adsCenterTitle
  ///
  /// In en, this message translates to:
  /// **'Ads Center'**
  String get adsCenterTitle;

  /// adsCenterSubtitle
  ///
  /// In en, this message translates to:
  /// **'Reach more women, and pay only for what you choose'**
  String get adsCenterSubtitle;

  /// adsEntryBody
  ///
  /// In en, this message translates to:
  /// **'Put your best pieces in front of more women'**
  String get adsEntryBody;

  /// adsYourPlan
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get adsYourPlan;

  /// adsActiveOf
  ///
  /// In en, this message translates to:
  /// **'{active} of {max} campaigns running'**
  String adsActiveOf(int active, int max);

  /// adsPlanEndsIn
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Ends today} =1{Ends tomorrow} other{Ends in {days} days}}'**
  String adsPlanEndsIn(int days);

  /// adsCreditLeft
  ///
  /// In en, this message translates to:
  /// **'{amount} ad credit left'**
  String adsCreditLeft(String amount);

  /// adsRecommendSaving
  ///
  /// In en, this message translates to:
  /// **'{tier} would have saved you {amount} last month'**
  String adsRecommendSaving(String tier, String amount);

  /// adsUpgrade
  ///
  /// In en, this message translates to:
  /// **'Upgrade your plan'**
  String get adsUpgrade;

  /// adsSeePlans
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get adsSeePlans;

  /// adsNewCampaign
  ///
  /// In en, this message translates to:
  /// **'New campaign'**
  String get adsNewCampaign;

  /// adsPerformance
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get adsPerformance;

  /// adsPerformanceCaption
  ///
  /// In en, this message translates to:
  /// **'Across all your campaigns'**
  String get adsPerformanceCaption;

  /// adsMetricSpend
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get adsMetricSpend;

  /// adsMetricReach
  ///
  /// In en, this message translates to:
  /// **'Women reached'**
  String get adsMetricReach;

  /// adsMetricClicks
  ///
  /// In en, this message translates to:
  /// **'Taps'**
  String get adsMetricClicks;

  /// adsMetricOrders
  ///
  /// In en, this message translates to:
  /// **'Orders from ads'**
  String get adsMetricOrders;

  /// adsMetricRevenue
  ///
  /// In en, this message translates to:
  /// **'Sales from ads'**
  String get adsMetricRevenue;

  /// adsMetricRoas
  ///
  /// In en, this message translates to:
  /// **'Return per lira spent'**
  String get adsMetricRoas;

  /// Return on ad spend multiplier
  ///
  /// In en, this message translates to:
  /// **'{value}×'**
  String adsRoasValue(String value);

  /// adsNotYet
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get adsNotYet;

  /// adsInsightAbove
  ///
  /// In en, this message translates to:
  /// **'Your ads are tapped more than average — keep going'**
  String get adsInsightAbove;

  /// adsInsightAverage
  ///
  /// In en, this message translates to:
  /// **'Your ads perform about average'**
  String get adsInsightAverage;

  /// adsInsightBelow
  ///
  /// In en, this message translates to:
  /// **'Fewer taps than average — try a stronger photo or a targeted audience'**
  String get adsInsightBelow;

  /// adsInsightNoData
  ///
  /// In en, this message translates to:
  /// **'Results appear once your ads have been seen'**
  String get adsInsightNoData;

  /// adsSuggestionsTitle
  ///
  /// In en, this message translates to:
  /// **'Smart picks to promote'**
  String get adsSuggestionsTitle;

  /// adsSuggestionsCaption
  ///
  /// In en, this message translates to:
  /// **'Chosen from your own views, favourites and sales'**
  String get adsSuggestionsCaption;

  /// adsReasonLoved
  ///
  /// In en, this message translates to:
  /// **'Loved, not yet bought'**
  String get adsReasonLoved;

  /// adsReasonBest
  ///
  /// In en, this message translates to:
  /// **'Your best seller'**
  String get adsReasonBest;

  /// adsReasonHidden
  ///
  /// In en, this message translates to:
  /// **'New and barely seen'**
  String get adsReasonHidden;

  /// adsReasonFresh
  ///
  /// In en, this message translates to:
  /// **'Fresh pick'**
  String get adsReasonFresh;

  /// adsCampaignsTitle
  ///
  /// In en, this message translates to:
  /// **'Your campaigns'**
  String get adsCampaignsTitle;

  /// adsNoCampaigns
  ///
  /// In en, this message translates to:
  /// **'No campaigns yet'**
  String get adsNoCampaigns;

  /// adsNoCampaignsBody
  ///
  /// In en, this message translates to:
  /// **'Start with one of the smart picks above — it takes a minute.'**
  String get adsNoCampaignsBody;

  /// adsStatusLive
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get adsStatusLive;

  /// adsStatusPaused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get adsStatusPaused;

  /// adsStatusEnded
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get adsStatusEnded;

  /// adsStatusScheduled
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get adsStatusScheduled;

  /// adsStatusUnpaid
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get adsStatusUnpaid;

  /// adsPause
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get adsPause;

  /// adsResume
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get adsResume;

  /// adsCampaignWhere
  ///
  /// In en, this message translates to:
  /// **'{placement} · {audience}'**
  String adsCampaignWhere(String placement, String audience);

  /// adsCampaignStats
  ///
  /// In en, this message translates to:
  /// **'{impressions} views · {clicks} taps'**
  String adsCampaignStats(String impressions, String clicks);

  /// adsCampaignReachOrders
  ///
  /// In en, this message translates to:
  /// **'{reach} women · {orders} orders'**
  String adsCampaignReachOrders(String reach, String orders);

  /// adsCampaignRevenue
  ///
  /// In en, this message translates to:
  /// **'{amount} in sales from this ad'**
  String adsCampaignRevenue(String amount);

  /// adsAudienceEveryone
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get adsAudienceEveryone;

  /// adsAudienceTargeted
  ///
  /// In en, this message translates to:
  /// **'Targeted'**
  String get adsAudienceTargeted;

  /// adsAudienceEveryoneHint
  ///
  /// In en, this message translates to:
  /// **'Every shopper, signed in or not'**
  String get adsAudienceEveryoneHint;

  /// adsAudienceTargetedHint
  ///
  /// In en, this message translates to:
  /// **'Only the women you choose — 20% cheaper'**
  String get adsAudienceTargetedHint;

  /// adsFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your ads'**
  String get adsFailed;

  /// adsPlansTitle
  ///
  /// In en, this message translates to:
  /// **'Advertising plans'**
  String get adsPlansTitle;

  /// adsPlansSubtitle
  ///
  /// In en, this message translates to:
  /// **'The more you invest, the further you reach'**
  String get adsPlansSubtitle;

  /// adsPlanPerMonth
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String adsPlanPerMonth(String price);

  /// adsPlanFreeLabel
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get adsPlanFreeLabel;

  /// adsPlanCredit
  ///
  /// In en, this message translates to:
  /// **'{amount} of ad credit included'**
  String adsPlanCredit(String amount);

  /// adsPlanBonus
  ///
  /// In en, this message translates to:
  /// **'{amount} more credit than you pay'**
  String adsPlanBonus(String amount);

  /// adsPlanDiscount
  ///
  /// In en, this message translates to:
  /// **'{percent}% off every campaign'**
  String adsPlanDiscount(int percent);

  /// adsPlanCampaigns
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 campaign at a time} other{{count} campaigns at once}}'**
  String adsPlanCampaigns(int count);

  /// adsPlanWeight
  ///
  /// In en, this message translates to:
  /// **'Shown {weight}× more often than free stores'**
  String adsPlanWeight(int weight);

  /// adsPlanTargetingNone
  ///
  /// In en, this message translates to:
  /// **'Ads shown to everyone'**
  String get adsPlanTargetingNone;

  /// adsPlanTargetingLocation
  ///
  /// In en, this message translates to:
  /// **'Target by governorate'**
  String get adsPlanTargetingLocation;

  /// adsPlanTargetingFull
  ///
  /// In en, this message translates to:
  /// **'Target followers, past buyers, interests and new shoppers'**
  String get adsPlanTargetingFull;

  /// adsPlanFollowers
  ///
  /// In en, this message translates to:
  /// **'Your followers hear about every new campaign'**
  String get adsPlanFollowers;

  /// adsPlanFeatured
  ///
  /// In en, this message translates to:
  /// **'First in «Featured stores», with your badge'**
  String get adsPlanFeatured;

  /// adsPlanPlacements
  ///
  /// In en, this message translates to:
  /// **'Placements: {list}'**
  String adsPlanPlacements(String list);

  /// Separator between items in an inline list
  ///
  /// In en, this message translates to:
  /// **', '**
  String get adsListSeparator;

  /// adsPlanCurrent
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get adsPlanCurrent;

  /// adsPlanRecommendedChip
  ///
  /// In en, this message translates to:
  /// **'Best for you'**
  String get adsPlanRecommendedChip;

  /// adsPlanSaving
  ///
  /// In en, this message translates to:
  /// **'Would have saved you {amount} last month'**
  String adsPlanSaving(String amount);

  /// adsPlanStartHint
  ///
  /// In en, this message translates to:
  /// **'Start with Silver: its credit is worth more than its price'**
  String get adsPlanStartHint;

  /// adsPlanChoose
  ///
  /// In en, this message translates to:
  /// **'Choose {tier}'**
  String adsPlanChoose(String tier);

  /// adsPlanRenew
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get adsPlanRenew;

  /// adsPlanQueued
  ///
  /// In en, this message translates to:
  /// **'{tier} starts on {date}'**
  String adsPlanQueued(String tier, String date);

  /// adsPlanConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {tier}?'**
  String adsPlanConfirmTitle(String tier);

  /// adsPlanConfirmBody
  ///
  /// In en, this message translates to:
  /// **'{price} for 30 days. The plan does not renew by itself.'**
  String adsPlanConfirmBody(String price);

  /// adsPlanConfirmUpgradeNote
  ///
  /// In en, this message translates to:
  /// **'Unused credit from your current plan carries over.'**
  String get adsPlanConfirmUpgradeNote;

  /// adsPlanSubscribed
  ///
  /// In en, this message translates to:
  /// **'Welcome to {tier}!'**
  String adsPlanSubscribed(String tier);

  /// adsConfirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get adsConfirm;

  /// adsErrorBalance
  ///
  /// In en, this message translates to:
  /// **'Your earnings balance doesn\'t cover this yet.'**
  String get adsErrorBalance;

  /// adsErrorLimit
  ///
  /// In en, this message translates to:
  /// **'Your plan’s campaign limit is reached — pause one or upgrade.'**
  String get adsErrorLimit;

  /// adsErrorFeedPost
  ///
  /// In en, this message translates to:
  /// **'Publish a public post featuring this piece first.'**
  String get adsErrorFeedPost;

  /// adsErrorLocked
  ///
  /// In en, this message translates to:
  /// **'This needs a higher plan.'**
  String get adsErrorLocked;

  /// adsComposerTitle
  ///
  /// In en, this message translates to:
  /// **'New campaign'**
  String get adsComposerTitle;

  /// adsStepProduct
  ///
  /// In en, this message translates to:
  /// **'The piece'**
  String get adsStepProduct;

  /// adsChooseProduct
  ///
  /// In en, this message translates to:
  /// **'Choose a piece to promote'**
  String get adsChooseProduct;

  /// adsChangeProduct
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get adsChangeProduct;

  /// adsPickProductTitle
  ///
  /// In en, this message translates to:
  /// **'Which piece?'**
  String get adsPickProductTitle;

  /// adsNoProducts
  ///
  /// In en, this message translates to:
  /// **'You have no live pieces to promote'**
  String get adsNoProducts;

  /// adsStepPlacement
  ///
  /// In en, this message translates to:
  /// **'Where it appears'**
  String get adsStepPlacement;

  /// adsStepAudience
  ///
  /// In en, this message translates to:
  /// **'Who sees it'**
  String get adsStepAudience;

  /// adsStepDuration
  ///
  /// In en, this message translates to:
  /// **'For how long'**
  String get adsStepDuration;

  /// adsDays
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String adsDays(int count);

  /// adsLockedNeeds
  ///
  /// In en, this message translates to:
  /// **'Needs {tier}'**
  String adsLockedNeeds(String tier);

  /// adsTargetGroups
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get adsTargetGroups;

  /// adsTargetGovernorates
  ///
  /// In en, this message translates to:
  /// **'Governorates'**
  String get adsTargetGovernorates;

  /// adsTargetFollowers
  ///
  /// In en, this message translates to:
  /// **'My followers'**
  String get adsTargetFollowers;

  /// adsTargetPastBuyers
  ///
  /// In en, this message translates to:
  /// **'Bought from me'**
  String get adsTargetPastBuyers;

  /// adsTargetInterested
  ///
  /// In en, this message translates to:
  /// **'Interested in this kind of piece'**
  String get adsTargetInterested;

  /// adsTargetNewShoppers
  ///
  /// In en, this message translates to:
  /// **'New shoppers'**
  String get adsTargetNewShoppers;

  /// adsReachTitle
  ///
  /// In en, this message translates to:
  /// **'Estimated reach'**
  String get adsReachTitle;

  /// adsReachValue
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 woman} other{{count} women}}'**
  String adsReachValue(int count);

  /// adsReachShare
  ///
  /// In en, this message translates to:
  /// **'{percent}% of all shoppers'**
  String adsReachShare(int percent);

  /// adsShareOfVoice
  ///
  /// In en, this message translates to:
  /// **'Your share of the slot'**
  String get adsShareOfVoice;

  /// adsShareOfVoiceHint
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Against 1 live campaign} other{Against {count} live campaigns}}'**
  String adsShareOfVoiceHint(int count);

  /// adsShareAlone
  ///
  /// In en, this message translates to:
  /// **'No competition right now'**
  String get adsShareAlone;

  /// adsPercent
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String adsPercent(int value);

  /// adsPriceLine
  ///
  /// In en, this message translates to:
  /// **'Placement for {duration}'**
  String adsPriceLine(String duration);

  /// adsPriceDiscount
  ///
  /// In en, this message translates to:
  /// **'{tier} plan discount'**
  String adsPriceDiscount(String tier);

  /// adsPriceCredit
  ///
  /// In en, this message translates to:
  /// **'Paid from ad credit'**
  String get adsPriceCredit;

  /// adsPriceToPay
  ///
  /// In en, this message translates to:
  /// **'From your earnings'**
  String get adsPriceToPay;

  /// adsMinus
  ///
  /// In en, this message translates to:
  /// **'−{amount}'**
  String adsMinus(String amount);

  /// adsFeedPostPinned
  ///
  /// In en, this message translates to:
  /// **'This post will be pinned:'**
  String get adsFeedPostPinned;

  /// adsFeedPostMissing
  ///
  /// In en, this message translates to:
  /// **'This placement pins one of your posts. Publish a post featuring this piece first.'**
  String get adsFeedPostMissing;

  /// adsCreatePost
  ///
  /// In en, this message translates to:
  /// **'Create a post'**
  String get adsCreatePost;

  /// adsUnlockWith
  ///
  /// In en, this message translates to:
  /// **'Unlock with {tier}'**
  String adsUnlockWith(String tier);

  /// adsLaunch
  ///
  /// In en, this message translates to:
  /// **'Launch · {amount}'**
  String adsLaunch(String amount);

  /// adsLaunchFree
  ///
  /// In en, this message translates to:
  /// **'Launch with your credit'**
  String get adsLaunchFree;

  /// adsLaunched
  ///
  /// In en, this message translates to:
  /// **'Your campaign is live ✨'**
  String get adsLaunched;

  /// adsQuoteFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t price this campaign'**
  String get adsQuoteFailed;

  /// Home section of boutiques' paid spotlight slots
  ///
  /// In en, this message translates to:
  /// **'Featured picks'**
  String get homeSpotlightTitle;

  /// homeSpotlightShop
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get homeSpotlightShop;

  /// homeSpotlightCardLabel
  ///
  /// In en, this message translates to:
  /// **'Sponsored: {product}, from {store}'**
  String homeSpotlightCardLabel(String product, String store);

  /// adsPayHow
  ///
  /// In en, this message translates to:
  /// **'How would you like to pay?'**
  String get adsPayHow;

  /// adsPayFromEarnings
  ///
  /// In en, this message translates to:
  /// **'From my earnings'**
  String get adsPayFromEarnings;

  /// adsPayEarningsBalance
  ///
  /// In en, this message translates to:
  /// **'Balance: {amount}'**
  String adsPayEarningsBalance(String amount);

  /// adsPayEarningsShort
  ///
  /// In en, this message translates to:
  /// **'Balance {amount} — not enough yet'**
  String adsPayEarningsShort(String amount);

  /// adsPayInstant
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get adsPayInstant;

  /// adsPayTransferHint
  ///
  /// In en, this message translates to:
  /// **'Send the amount, then enter the transaction number'**
  String get adsPayTransferHint;

  /// adsPayNoMethods
  ///
  /// In en, this message translates to:
  /// **'Payment by transfer is not set up yet — contact support'**
  String get adsPayNoMethods;

  /// adsPaymentBannerAwaiting
  ///
  /// In en, this message translates to:
  /// **'Your {tier} plan is waiting for your payment — tap to finish'**
  String adsPaymentBannerAwaiting(String tier);

  /// adsPaymentBannerReview
  ///
  /// In en, this message translates to:
  /// **'We received your {tier} payment number and are checking it'**
  String adsPaymentBannerReview(String tier);

  /// adsPaymentBannerRejected
  ///
  /// In en, this message translates to:
  /// **'We couldn’t match your {tier} payment — tap to see why'**
  String adsPaymentBannerRejected(String tier);

  /// adsPaymentTitle
  ///
  /// In en, this message translates to:
  /// **'Pay for your plan'**
  String get adsPaymentTitle;

  /// adsPaymentPlan
  ///
  /// In en, this message translates to:
  /// **'{tier} plan · 30 days'**
  String adsPaymentPlan(String tier);

  /// adsPaymentStepSend
  ///
  /// In en, this message translates to:
  /// **'Send {amount} by {method}'**
  String adsPaymentStepSend(String amount, String method);

  /// adsPaymentStepReference
  ///
  /// In en, this message translates to:
  /// **'Enter the transaction number you received'**
  String get adsPaymentStepReference;

  /// adsPaymentStepChange
  ///
  /// In en, this message translates to:
  /// **'Sent the wrong number? Send it again'**
  String get adsPaymentStepChange;

  /// adsPaymentReferenceField
  ///
  /// In en, this message translates to:
  /// **'Transaction number'**
  String get adsPaymentReferenceField;

  /// adsPaymentSend
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get adsPaymentSend;

  /// adsPaymentSent
  ///
  /// In en, this message translates to:
  /// **'Received — we’ll turn your plan on as soon as it’s matched'**
  String get adsPaymentSent;

  /// adsPaymentReviewTitle
  ///
  /// In en, this message translates to:
  /// **'Being checked'**
  String get adsPaymentReviewTitle;

  /// adsPaymentReviewBody
  ///
  /// In en, this message translates to:
  /// **'Transaction {reference} is with our finance team. You’ll get a notification the moment your plan is on.'**
  String adsPaymentReviewBody(String reference);

  /// adsPaymentRejectedTitle
  ///
  /// In en, this message translates to:
  /// **'We couldn’t match this payment'**
  String get adsPaymentRejectedTitle;

  /// adsPaymentHowLong
  ///
  /// In en, this message translates to:
  /// **'Payments are usually matched within a few working hours.'**
  String get adsPaymentHowLong;

  /// adsPaymentCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel this payment'**
  String get adsPaymentCancel;

  /// adsPaymentCopy
  ///
  /// In en, this message translates to:
  /// **'Copy payment details'**
  String get adsPaymentCopy;

  /// adsPaymentCopied
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get adsPaymentCopied;

  /// adsPaymentNothingOpen
  ///
  /// In en, this message translates to:
  /// **'No payment is waiting'**
  String get adsPaymentNothingOpen;

  /// adsErrorMethodUnavailable
  ///
  /// In en, this message translates to:
  /// **'This payment method isn’t available right now.'**
  String get adsErrorMethodUnavailable;

  /// adsErrorPurchaseInProgress
  ///
  /// In en, this message translates to:
  /// **'You already have a plan payment in progress.'**
  String get adsErrorPurchaseInProgress;

  /// adsErrorPurchaseClosed
  ///
  /// In en, this message translates to:
  /// **'This payment has already been decided.'**
  String get adsErrorPurchaseClosed;

  /// adsErrorReferenceRequired
  ///
  /// In en, this message translates to:
  /// **'Enter the transaction number you received.'**
  String get adsErrorReferenceRequired;

  /// adminAdsTitle
  ///
  /// In en, this message translates to:
  /// **'Advertising plans'**
  String get adminAdsTitle;

  /// adminAdsSummary
  ///
  /// In en, this message translates to:
  /// **'{plans} active plans · {revenue} ad revenue this month'**
  String adminAdsSummary(int plans, String revenue);

  /// adminAdsNoPending
  ///
  /// In en, this message translates to:
  /// **'No plan payments waiting to be matched.'**
  String get adminAdsNoPending;

  /// adminAdsReference
  ///
  /// In en, this message translates to:
  /// **'Transaction number: {reference}'**
  String adminAdsReference(String reference);

  /// adminAdsConfirmBody
  ///
  /// In en, this message translates to:
  /// **'Confirm that {amount} arrived from {seller}? Their {tier} plan turns on at once.'**
  String adminAdsConfirmBody(String amount, String seller, String tier);

  /// adminAdsConfirmed
  ///
  /// In en, this message translates to:
  /// **'Plan turned on, and the boutique was told'**
  String get adminAdsConfirmed;

  /// adminAdsInstructionsTitle
  ///
  /// In en, this message translates to:
  /// **'Where boutiques send plan payments'**
  String get adminAdsInstructionsTitle;

  /// adminAdsInstructionsHint
  ///
  /// In en, this message translates to:
  /// **'A method left empty is not offered'**
  String get adminAdsInstructionsHint;

  /// adminAdsInstructionsSave
  ///
  /// In en, this message translates to:
  /// **'Save payment details'**
  String get adminAdsInstructionsSave;

  /// adminAdsInstructionsSaved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get adminAdsInstructionsSaved;

  /// adsNotVerifiedTitle
  ///
  /// In en, this message translates to:
  /// **'Your store needs approval to advertise'**
  String get adsNotVerifiedTitle;

  /// adsNotVerifiedBody
  ///
  /// In en, this message translates to:
  /// **'Until your store is approved its page is closed to shoppers, so ads couldn’t reach them. Complete verification and every plan opens up.'**
  String get adsNotVerifiedBody;

  /// adsNotVerifiedAction
  ///
  /// In en, this message translates to:
  /// **'Complete verification'**
  String get adsNotVerifiedAction;

  /// adsErrorNotVerified
  ///
  /// In en, this message translates to:
  /// **'Your store must be approved before it can advertise.'**
  String get adsErrorNotVerified;

  /// Chip on a ranked feed card: chosen from what she likes and shops
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get feedReasonForYou;

  /// Chip on a ranked feed card: doing unusually well right now
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get feedReasonTrending;

  /// Chip on a ranked feed card: a good account she has not met yet
  ///
  /// In en, this message translates to:
  /// **'New voice'**
  String get feedReasonNewVoice;
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
