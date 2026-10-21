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
  /// **'About Reem'**
  String get aboutReem;

  /// About screen description
  ///
  /// In en, this message translates to:
  /// **'A premium social-commerce home for the pieces you love — shopping, discovery and community in one place.'**
  String get aboutReemBlurb;

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

  /// Shell action — coupons
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get actionCoupons;

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
  /// **'Last {count} days'**
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
  /// **'{count} fields'**
  String adminRecordNestedObject(int count);

  /// Summary of a list inside a console record.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
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
  /// **'{format} report ready — {count} rows'**
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
  /// **'{units} units'**
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
  /// **'Reem Stylist'**
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
  String analyticsUnitsSold(Object count);

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'App preferences'**
  String get appPreferences;

  /// Application name shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Reem'**
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
  /// **'Choose how Reem looks on your device. Your choice is saved automatically.'**
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
  /// **'I declare that I am a woman and accept the Reem terms'**
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

  /// Helper line under the Ask Reem field on Discover.
  ///
  /// In en, this message translates to:
  /// **'Describe the occasion or the feeling — “a summer wedding, something soft, under 60k”'**
  String get discoverAskHelper;

  /// Placeholder of the Ask Reem field on Discover.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get discoverAskHint;

  /// Label above the Discover question field, which opens the stylist with her question.
  ///
  /// In en, this message translates to:
  /// **'Ask Reem'**
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
  /// **'Cash on delivery, or from your Reem wallet. Never pay a boutique outside the app — an order paid outside it is not protected.'**
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
  /// **'Reem Rewards'**
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
  /// **'{count} points added to your balance ✨'**
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
  /// **'Check that the message shows the same two digits. Reem will never ask you to read a code aloud.'**
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
  /// **'Your phone is blocking Reem\'s notifications.'**
  String get notifPushBlocked;

  /// No description provided for @notifPushBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone is blocking Reem, so nothing below will reach you until you allow it in the system settings.'**
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
  /// **'You have {days} extra days on the window'**
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
  /// **'{points} points, {tier} tier'**
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
  /// **'{points} points'**
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
  /// **'Discount'**
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

  /// Rating line on the seller stats card; both values are pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count} reviews'**
  String sellerRatingSummary(String rating, String count);

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
  /// **'Add Reem to your authenticator'**
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
  /// **'Reem needs permission to use the microphone.'**
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
  /// **'Spendable inside Reem only'**
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
  /// **'Welcome to Reem'**
  String get welcomeToReem;

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
  /// **'{reshares} added · {products} pieces'**
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
  /// **'The documents that govern your use of Reem'**
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
  /// **'Please read and accept the following to keep using Reem.'**
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
  /// **'{count} accounts have signed this policy'**
  String adminPolicyAcceptedAny(String count);

  /// No description provided for @adminPolicyNoDraft.
  ///
  /// In en, this message translates to:
  /// **'No open draft. Start one to change the text.'**
  String get adminPolicyNoDraft;

  /// No description provided for @adminPolicyVersionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} versions'**
  String adminPolicyVersionsCount(String count);

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
