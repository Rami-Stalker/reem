// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ريم';

  @override
  String get splashTagline => 'حيث يلتقي الجمال بالتسوّق الاجتماعي';

  @override
  String get home => 'الرئيسية';

  @override
  String get feed => 'المنشورات';

  @override
  String get search => 'البحث';

  @override
  String get cart => 'السلة';

  @override
  String get profile => 'حسابي';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get orders => 'الطلبات';

  @override
  String get stories => 'الستوريات';

  @override
  String get add => 'أضيفي';

  @override
  String get save => 'حفظ';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get send => 'إرسال';

  @override
  String get verify => 'تأكيد';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get retry => 'حاولي مرة أخرى';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get seeMore => 'عرض المزيد';

  @override
  String get done => 'تم';

  @override
  String get apply => 'تطبيق';

  @override
  String get clear => 'مسح';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get goodAfternoon => 'مساء الخير';

  @override
  String get goodEvening => 'مساء الخير';

  @override
  String get welcomeToReem => 'مرحباً بكِ في ريم';

  @override
  String get welcomeBack => 'مرحباً بعودتكِ';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signup => 'إنشاء حساب';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirm => 'هل تريدين تسجيل الخروج؟';

  @override
  String get loginSubtitle => 'سجّلي دخولكِ للتسوّق والمشاركة والتألّق ✨';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get phone => 'رقم الموبايل';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get forgetPassword => 'نسيتِ كلمة المرور؟';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get emailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get validEmailRequired => 'أدخلي بريداً إلكترونياً صالحاً';

  @override
  String get phoneRequired => 'رقم الموبايل مطلوب';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String passwordMinLength(int count) {
    return 'لا تقلّ عن $count محارف';
  }

  @override
  String get confirmPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get products => 'المنتجات';

  @override
  String get productDetails => 'تفاصيل المنتج';

  @override
  String get addToCart => 'أضيفي إلى السلة';

  @override
  String get buyNow => 'اشتري الآن';

  @override
  String get removeFromCart => 'إزالة من السلة';

  @override
  String get wishlist => 'المفضّلة';

  @override
  String get favorite => 'حفظ';

  @override
  String get unfavorite => 'محفوظ';

  @override
  String get quantity => 'الكمية';

  @override
  String get outOfStock => 'نفد المخزون';

  @override
  String get inStock => 'متوفّر';

  @override
  String get todayOffers => 'عروض اليوم';

  @override
  String get bestSeller => 'الأكثر مبيعاً';

  @override
  String get newArrivals => 'وصل حديثاً';

  @override
  String get recommended => 'مختارة لكِ';

  @override
  String get trendingNow => 'الأكثر رواجاً';

  @override
  String get trendingSubtitle => 'الأكثر حباً هذا الأسبوع';

  @override
  String get searchHint => 'ابحثي عن فساتين، مكياج، هدايا…';

  @override
  String sellersOffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بائعة',
      many: '$count بائعة',
      few: '$count بائعات',
      two: 'بائعتان',
      one: 'بائعة واحدة',
      zero: 'لا يوجد بائعات',
    );
    return '$_temp0';
  }

  @override
  String get comparePrices => 'قارني الأسعار';

  @override
  String priceFrom(String price) {
    return 'ابتداءً من $price';
  }

  @override
  String soldBy(String seller) {
    return 'من $seller';
  }

  @override
  String get checkout => 'إتمام الشراء';

  @override
  String get emptyCart => 'سلّتكِ فارغة';

  @override
  String get emptyCartAction => 'ابدئي التسوّق';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get discount => 'الخصم';

  @override
  String get delivery => 'التوصيل';

  @override
  String get total => 'الإجمالي';

  @override
  String get placeOrder => 'تأكيد الطلب';

  @override
  String get selectGovernorate => 'اختاري المحافظة';

  @override
  String get deliveryAddress => 'عنوان التوصيل';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get orderSummary => 'ملخّص الطلب';

  @override
  String splitOrderNotice(int count) {
    return 'طلبكِ من $count بائعات وسيصلكِ على عدة شحنات — بأجرة توصيل واحدة.';
  }

  @override
  String get etaSameDay => 'يصلكِ اليوم بإذن الله';

  @override
  String etaDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يصلكِ خلال $count يوماً',
      few: 'يصلكِ خلال $count أيام',
      two: 'يصلكِ خلال يومين',
      one: 'يصلكِ خلال يوم',
    );
    return '$_temp0';
  }

  @override
  String get myOrders => 'طلباتي';

  @override
  String get orderDetails => 'تفاصيل الطلب';

  @override
  String get orderStatus => 'حالة الطلب';

  @override
  String get parcels => 'الشحنات';

  @override
  String trackingNumber(String code) {
    return 'رقم التتبّع $code';
  }

  @override
  String get cancelOrder => 'إلغاء الطلب';

  @override
  String get reorder => 'اطلبيه مجدداً';

  @override
  String get requestReturn => 'طلب إرجاع';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة',
      many: '$count قطعة',
      few: '$count قطع',
      two: 'قطعتان',
      one: 'قطعة واحدة',
      zero: 'لا قطع',
    );
    return '$_temp0';
  }

  @override
  String get moments => 'لحظاتكن';

  @override
  String get shareMoment => 'شاركي لحظتكِ';

  @override
  String get addStory => 'أضيفي ستوري';

  @override
  String get addMoment => 'أضيفي لحظتكِ';

  @override
  String get post => 'نشر';

  @override
  String get writeComment => 'اكتبي تعليقاً…';

  @override
  String viewAllComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض كل التعليقات ($count)',
      few: 'عرض التعليقات $count',
      two: 'عرض التعليقين',
      one: 'عرض تعليق واحد',
    );
    return '$_temp0';
  }

  @override
  String get likes => 'الإعجابات';

  @override
  String get comments => 'التعليقات';

  @override
  String get follow => 'متابعة';

  @override
  String get following => 'تتابعينها';

  @override
  String get followers => 'المتابِعات';

  @override
  String get rewards => 'المكافآت';

  @override
  String get rewardsAndOffers => 'المكافآت والعروض';

  @override
  String get points => 'النقاط';

  @override
  String get coupons => 'الكوبونات';

  @override
  String couponsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كوبون',
      many: '$count كوبوناً',
      few: '$count كوبونات',
      two: 'كوبونان',
      one: 'كوبون واحد',
      zero: 'لا كوبونات',
    );
    return '$_temp0';
  }

  @override
  String get addCoupon => 'أضيفي كوبوناً';

  @override
  String get applyCoupon => 'تطبيق الكوبون';

  @override
  String get invalidCoupon => 'هذا الكوبون غير صالح';

  @override
  String get usedCoupon => 'تم تطبيق الكوبون';

  @override
  String get account => 'الحساب';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get support => 'الدعم';

  @override
  String get helpCenter => 'مركز المساعدة';

  @override
  String get contactSupport => 'تواصلي مع الدعم';

  @override
  String get faq => 'الأسئلة الشائعة';

  @override
  String get addresses => 'العناوين';

  @override
  String get paymentMethods => 'طرق الدفع';

  @override
  String get appearance => 'المظهر';

  @override
  String get appearanceDescription =>
      'اختاري كيف يظهر تطبيق ريم على جهازكِ. يُحفظ تفضيلكِ تلقائياً.';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeLightSubtitle => 'وردي ناعم وأناقة النهار';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeDarkSubtitle => 'بنفسجي عميق ولمسات وردية متوهّجة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeSystemSubtitle => 'يتبع إعدادات جهازكِ';

  @override
  String get themeLightActive => 'المظهر الفاتح مفعّل';

  @override
  String get themeDarkActive => 'المظهر الداكن مفعّل';

  @override
  String get themeSystemActive => 'يتبع مظهر النظام';

  @override
  String get preview => 'معاينة';

  @override
  String get active => 'مفعّل';

  @override
  String get language => 'اللغة';

  @override
  String get selectLanguage => 'اختاري لغتكِ';

  @override
  String get followDeviceLanguage => 'اتّبعي لغة الجهاز';

  @override
  String get systemLanguage => 'النظام';

  @override
  String get ar => 'العربية';

  @override
  String get en => 'الإنجليزية';

  @override
  String get success => 'تم بنجاح';

  @override
  String get error => 'حدث خطأ ما';

  @override
  String get emptyFeed => 'لا يوجد شيء هنا بعد';

  @override
  String get emptyStories => 'لا ستوريات حالياً';

  @override
  String get emptyWishlist => 'مفضّلتكِ فارغة';

  @override
  String emptySearch(String query) {
    return 'لا نتائج لـ«$query»';
  }

  @override
  String get noConnection => 'لا يوجد اتصال بالإنترنت';

  @override
  String get sellerDashboard => 'لوحة متجري';

  @override
  String get myProducts => 'عروضي';

  @override
  String get myEarnings => 'أرباحي';

  @override
  String get adminPanel => 'لوحة الإدارة';

  @override
  String get adminDashboard => 'لوحة التحكم';

  @override
  String get adminOrders => 'الطلبات';

  @override
  String get adminProducts => 'المنتجات';

  @override
  String get adminUsers => 'المستخدمات';

  @override
  String get adminAnalytics => 'التحليلات';

  @override
  String get adminWelcome => 'مرحباً بعودتكِ';

  @override
  String get adminTotalSales => 'إجمالي المبيعات';

  @override
  String get adminTotalOrders => 'إجمالي الطلبات';

  @override
  String get adminActiveUsers => 'المستخدمات النشطات';

  @override
  String get adminConversion => 'معدّل التحويل';

  @override
  String get adminRecentOrders => 'أحدث الطلبات';

  @override
  String get adminManageCatalog => 'إدارة الكتالوج';

  @override
  String get adminViewReports => 'عرض التقارير';

  @override
  String get adminBackToShop => 'العودة للمتجر';

  @override
  String get a11yBack => 'رجوع';

  @override
  String get a11yClose => 'إغلاق';

  @override
  String get a11ySearch => 'بحث';

  @override
  String get a11yCart => 'السلة';

  @override
  String get a11yNotifications => 'الإشعارات';

  @override
  String get a11yProfile => 'الملف الشخصي';

  @override
  String get a11yLike => 'إعجاب';

  @override
  String get a11yShare => 'مشاركة';

  @override
  String get a11ySave => 'حفظ';

  @override
  String get a11yMore => 'خيارات أخرى';

  @override
  String get a11yPlay => 'تشغيل';

  @override
  String get emailOrPhone => 'البريد أو رقم الموبايل';

  @override
  String get emailOrPhoneRequired => 'البريد أو رقم الموبايل مطلوب';

  @override
  String get validEmailOrPhone => 'أدخلي بريداً أو رقم موبايل صالحاً';

  @override
  String get validPhone => 'أدخلي رقم موبايل صالحاً';

  @override
  String get fullNameRequired => 'الاسم الكامل مطلوب';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get country => 'الدولة';

  @override
  String get city => 'المدينة';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get passwordStrengthRule =>
      'استخدمي أحرفاً كبيرة وصغيرة ورقماً ورمزاً.';

  @override
  String get passwordWeak => 'ضعيفة';

  @override
  String get passwordGood => 'جيدة';

  @override
  String get passwordStrong => 'قوية';

  @override
  String passwordStrengthLabel(String label) {
    return 'قوة كلمة المرور: $label';
  }

  @override
  String get signInToContinue => 'سجّلي الدخول للمتابعة';

  @override
  String get signInRequired => 'يلزم تسجيل الدخول';

  @override
  String get signInToCheckout => 'سجّلي الدخول لإتمام الشراء';

  @override
  String get continueAsGuest => 'المتابعة كضيفة';

  @override
  String get signOutQuestion => 'تسجيل الخروج؟';

  @override
  String get signBackInLater => 'يمكنكِ العودة وتسجيل الدخول في أي وقت.';

  @override
  String get verifyYourPhone => 'تأكيد رقم موبايلكِ';

  @override
  String get verificationCode => 'رمز التحقق';

  @override
  String get enterVerificationCode => 'أدخلي رمز التحقق.';

  @override
  String codeSentTo(String phone) {
    return 'أرسلنا رمزاً لمرة واحدة إلى $phone.';
  }

  @override
  String get codeSent => 'أُرسل رمز التحقق إلى موبايلكِ.';

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String get requestingCode => 'جارٍ طلب رمز لمرة واحدة…';

  @override
  String get verifyCode => 'تأكيد الرمز';

  @override
  String get verificationComplete => 'تم التحقق بنجاح.';

  @override
  String get phoneVerified => 'تم تأكيد رقم الموبايل.';

  @override
  String get allSet => 'كل شيء جاهز ✨';

  @override
  String get resetYourPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get passwordUpdatedSignInAgain =>
      'تم تحديث كلمة المرور. سجّلي الدخول من جديد.';

  @override
  String get securityTitle => 'الخصوصية والأمان';

  @override
  String get secureAccountControls => 'أدوات حماية الحساب';

  @override
  String get manageSecurityBlurb =>
      'أديري الجلسات والأجهزة والاسترداد وتفاصيل الدفع.';

  @override
  String get sessions => 'الجلسات';

  @override
  String get noActiveSessions => 'لا جلسات نشطة.';

  @override
  String get revokeSession => 'إنهاء الجلسة';

  @override
  String get revoke => 'إنهاء';

  @override
  String get logOutAll => 'تسجيل الخروج من كل الأجهزة';

  @override
  String get devices => 'الأجهزة';

  @override
  String get noDevicesYet => 'لا أجهزة بعد.';

  @override
  String get unknownDevice => 'جهاز غير معروف';

  @override
  String get deviceName => 'اسم الجهاز';

  @override
  String get renameDevice => 'إعادة تسمية الجهاز';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get deviceUpdated => 'تم تحديث الجهاز.';

  @override
  String get trust => 'موثوق';

  @override
  String get rememberThisDevice => 'تذكّري هذا الجهاز';

  @override
  String get verifyNewDevices => 'التحقق من الأجهزة الجديدة';

  @override
  String get flagNewDevices => 'طلب تحقق عند دخول جهاز جديد.';

  @override
  String get otpOnSensitive => 'رمز تحقق للإجراءات الحساسة';

  @override
  String get otpOnSensitiveDescription =>
      'طلب رمز تحقق قبل التغييرات الحسّاسة.';

  @override
  String get linkedAccounts => 'الحسابات المرتبطة';

  @override
  String get link => 'ربط';

  @override
  String get unlink => 'فك الربط';

  @override
  String get connected => 'مرتبط';

  @override
  String get notConnected => 'غير مرتبط';

  @override
  String get sellerVerification => 'توثيق البائعة';

  @override
  String get submitVerification => 'إرسال طلب التوثيق';

  @override
  String get verificationSubmitted => 'تم إرسال طلب التوثيق.';

  @override
  String get noVerificationSubmitted => 'لم يُرسل طلب توثيق';

  @override
  String get submitBusinessDetails =>
      'أرسلي بيانات نشاطكِ للحصول على علامة التوثيق.';

  @override
  String get completeSellerFields =>
      'أكملي جميع الحقول المطلوبة في طلب البائعة.';

  @override
  String get verified => 'موثّقة';

  @override
  String get unverified => 'غير موثّقة';

  @override
  String get businessName => 'اسم النشاط';

  @override
  String get businessAddress => 'عنوان النشاط';

  @override
  String get businessCategory => 'فئة النشاط';

  @override
  String get commercialRegistration => 'السجل التجاري';

  @override
  String get taxNumber => 'الرقم الضريبي';

  @override
  String get ownerLegalName => 'الاسم القانوني للمالكة';

  @override
  String get contactEmail => 'بريد التواصل';

  @override
  String get contactPhone => 'هاتف التواصل';

  @override
  String get bankName => 'اسم المصرف';

  @override
  String get accountHolder => 'صاحبة الحساب';

  @override
  String get iban => 'رقم الآيبان';

  @override
  String get warehouseAddress => 'عنوان المستودع';

  @override
  String get shippingMethods => 'طرق الشحن';

  @override
  String get productCategories => 'فئات المنتجات';

  @override
  String get yearsOfExperience => 'سنوات الخبرة';

  @override
  String get storeDescription => 'وصف المتجر';

  @override
  String get storeLogoUrl => 'رابط شعار المتجر';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get governmentIdUrl => 'رابط صورة الهوية';

  @override
  String get businessLicenseUrl => 'رابط رخصة النشاط';

  @override
  String get additionalDocuments => 'مستندات إضافية';

  @override
  String get guestProfile => 'ملفكِ كضيفة';

  @override
  String get guestCartSafe =>
      'سلّتكِ محفوظة. سجّلي الدخول لتأكيد الطلبات وحفظ العناوين وتتبّع التوصيل.';

  @override
  String get saveYourProgress => 'احفظي تقدّمكِ';

  @override
  String get savedProgressBlurb =>
      'احتفظي بالمفضّلة والسلة والطلبات والقطع التي تصفّحتِها.';

  @override
  String get useEveryDevice => 'من أي جهاز';

  @override
  String get useEveryDeviceBlurb =>
      'تابعي من الموبايل أو الويب أو التابلت بأمان.';

  @override
  String get personalRecommendations => 'توصيات تخصّكِ';

  @override
  String get personalRecommendationsBlurb =>
      'صفحة رئيسية مبنية على ذوقكِ ونشاطكِ.';

  @override
  String get checkoutSafely => 'ادفعي بأمان';

  @override
  String get checkoutSafelyBlurb => 'طلباتكِ وعناوينكِ ودفعاتكِ محميّة.';

  @override
  String get syncBlurb => 'مزامنة المفضّلة والسلة والتوصيات.';

  @override
  String get quickSteps => 'خطوات سريعة لتجربة أغنى.';

  @override
  String get myCart => 'سلّتي';

  @override
  String get browseAndAdd => 'تصفّحي المتجر وأضيفي ما يعجبكِ.';

  @override
  String get keepBrowsing => 'تابعي التصفّح';

  @override
  String get removeOutOfStock => 'إزالة غير المتوفّر';

  @override
  String get savedForLater => 'محفوظ لاحقاً';

  @override
  String get completeProfile => 'أكملي ملفكِ الشخصي';

  @override
  String get profileLooksBeautiful => 'ملفكِ يبدو رائعاً.';

  @override
  String get profileIdentity => 'بيانات الملف';

  @override
  String get accountUpdated => 'تم تحديث الحساب.';

  @override
  String get savedItems => 'المحفوظات';

  @override
  String get savedProducts => 'منتجات محفوظة';

  @override
  String get savedSellers => 'بائعات محفوظات';

  @override
  String get savedPosts => 'منشورات محفوظة';

  @override
  String get savedAddresses => 'العناوين المحفوظة';

  @override
  String get noSavedItems => 'لا محفوظات بعد';

  @override
  String get recentlyViewed => 'شاهدتِها مؤخراً';

  @override
  String get collections => 'المجموعات';

  @override
  String get newCollection => 'مجموعة جديدة';

  @override
  String get createCollection => 'إنشاء مجموعة';

  @override
  String get collectionsBlurb =>
      'قوائم قابلة للمشاركة للمنتجات والبائعات والمنشورات';

  @override
  String get yourWishlist => 'مفضّلتكِ';

  @override
  String get wishlistLinkCopied => 'تم نسخ رابط المفضّلة';

  @override
  String get syncingWishlist => 'جارٍ مزامنة مفضّلتكِ';

  @override
  String get priceDropsBlurb => 'تنبيهات انخفاض السعر وعودة التوفّر';

  @override
  String get storesToRevisit => 'متاجر تودّين العودة إليها';

  @override
  String get yourOrders => 'طلباتكِ';

  @override
  String get trackReviewReorder => 'تتبّعي وقيّمي وأعيدي الطلب';

  @override
  String get achievements => 'الإنجازات';

  @override
  String get reviewsAndRatings => 'التقييمات والمراجعات';

  @override
  String get pointsEarned => 'النقاط المكتسبة';

  @override
  String get earned => 'مكتسبة';

  @override
  String get redeemed => 'مستبدَلة';

  @override
  String get lifetime => 'الإجمالي';

  @override
  String get locked => 'مقفلة';

  @override
  String get rewardsPointsBlurb =>
      'اكسبي نقاطاً مع كل طلب وتقييم، واستبدليها بكوبونات ومزايا.';

  @override
  String get inviteFriends => 'ادعي صديقاتكِ واكسبي مكافآت';

  @override
  String get friendsInvited => 'صديقات مدعوّات';

  @override
  String get codeCopied => 'تم نسخ الرمز';

  @override
  String inviteCodeCopied(String code) {
    return 'تم نسخ رمز الدعوة $code — شاركيه!';
  }

  @override
  String get supportCentre => 'مركز الدعم';

  @override
  String get helpAndFaq => 'المساعدة والأسئلة الشائعة';

  @override
  String get liveChat => 'محادثة مباشرة';

  @override
  String get emailUs => 'راسلينا بالبريد';

  @override
  String get call => 'اتصلي';

  @override
  String get replyWithinHour => 'نردّ عادةً خلال ساعة';

  @override
  String get startConversation => 'ابدئي محادثة';

  @override
  String get returnPolicy => 'سياسة الإرجاع';

  @override
  String get faqReturns => 'ما سياسة الإرجاع لديكم؟';

  @override
  String get faqReturnsAnswer =>
      'يمكن إرجاع معظم القطع خلال 7 أيام من الاستلام. افتحي الطلب لبدء الإرجاع.';

  @override
  String get faqTracking => 'كيف أتتبّع طلبي؟';

  @override
  String get faqTrackingAnswer =>
      'افتحي «طلباتي» من ملفكِ لمتابعة الحالة وتحديثات التوصيل.';

  @override
  String get faqPoints => 'كيف تعمل نقاط الولاء؟';

  @override
  String get aboutReem => 'عن ريم';

  @override
  String appVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get comingSoon => 'قريباً';

  @override
  String get comingSoonBlurb => 'نُحسّن هذه التجربة — ستصلكِ قريباً.';

  @override
  String get appPreferences => 'تفضيلات التطبيق';

  @override
  String a11yOpen(String name) {
    return 'فتح $name';
  }

  @override
  String nextStep(String step) {
    return 'التالي: $step';
  }

  @override
  String get aboutReemBlurb =>
      'بيت راقٍ للتسوّق الاجتماعي يجمع القطع التي تحبّينها — تسوّق واكتشاف ومجتمع في مكان واحد.';

  @override
  String get roleBuyer => 'زبونة';

  @override
  String get roleSeller => 'بائعة';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusProcessing => 'قيد التجهيز';

  @override
  String get statusInTransit => 'بالطريق';

  @override
  String get statusDelivered => 'تم التسليم';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get declaredFemaleLabel =>
      'أُقرّ بأنني أنثى، وأوافق على شروط استخدام ريم';

  @override
  String homeGreetingNamed(String name) {
    return 'أهلاً $name';
  }

  @override
  String get homeGreetingGuest => 'أهلاً فيكِ';

  @override
  String get homeGreetingSubtitle =>
      'مختارات أنيقة من الأزياء والجمال والهدايا — منتقاة لكِ.';

  @override
  String get homeSearchHint => 'ابحثي عن فستان، عطر، هدية…';

  @override
  String get homeStoriesEyebrow => 'جديد اليوم';

  @override
  String get homeYourStory => 'ستوريتك';

  @override
  String get homeShopByCategory => 'تسوّقي حسب القسم';

  @override
  String get homeFlashDealsEyebrow => 'لوقت محدود';

  @override
  String get homeFlashDeals => 'عروض سريعة';

  @override
  String get homeRecommendedEyebrow => 'منتقاة لكِ';

  @override
  String get homeNewArrivalsEyebrow => 'وصل حديثاً';

  @override
  String get homeBestSellersEyebrow => 'الأكثر محبة';

  @override
  String get homeContinueShoppingEyebrow => 'أهلاً بعودتكِ';

  @override
  String get homeContinueShopping => 'أكملي تسوّقكِ';

  @override
  String get homeFeaturedStoresEyebrow => 'بائعات مختارات';

  @override
  String get homeFeaturedStores => 'بوتيكات مميّزة';

  @override
  String get homeRecentlyViewedEyebrow => 'شاهدتِها مؤخراً';

  @override
  String get homeRecentlyViewed => 'آخر ما تصفّحتِ';

  @override
  String get homeWishlistEyebrow => 'أعجبتكِ';

  @override
  String get homeWishlist => 'من مفضّلتكِ';

  @override
  String get homeNearbyEyebrow => 'قريبة منكِ';

  @override
  String get homeNearbyStores => 'بوتيكات قريبة';

  @override
  String get homeExploreEyebrow => 'اكتشفي';

  @override
  String get homeExploreTitle => 'كل ما يناسبكِ';

  @override
  String get homeFeedEyebrow => 'من البائعات';

  @override
  String get homeFeedTitle => 'أحدث المنشورات';

  @override
  String get homeTasteNewDrops => 'وصل حديثاً';

  @override
  String get homeTasteBeauty => 'الجمال';

  @override
  String get homeTasteGifts => 'هدايا';

  @override
  String get filters => 'الفلاتر';

  @override
  String get trending => 'الأكثر رواجاً';

  @override
  String get recent => 'بحثتِ عنه مؤخراً';

  @override
  String get all => 'الكل';

  @override
  String get reply => 'ردّي';

  @override
  String get you => 'أنتِ';

  @override
  String get justNow => 'الآن';

  @override
  String get addCommentHint => 'اكتبي تعليقاً…';

  @override
  String get redeem => 'استبدلي';

  @override
  String get enable => 'تفعيل';

  @override
  String get openNow => 'مفتوح الآن';

  @override
  String get closedNow => 'مغلق';

  @override
  String get limitedTime => 'لوقت محدود';

  @override
  String get homeCategoriesEyebrow => 'تصفّحي';

  @override
  String get homeFeaturedEyebrow => 'اكتشفي';

  @override
  String get homeLoyaltyTitle => 'مكافآت ريم';

  @override
  String get homeLoyaltySubtitle => 'اكسبي نقاطاً مع كل عملية شراء ✨';

  @override
  String get homeNearbyPromptTitle => 'اكتشفي بوتيكات قريبة منكِ';

  @override
  String get homeNearbyPromptBody =>
      'فعّلي الموقع لعرض البوتيكات القريبة ونقاط الاستلام.';

  @override
  String get homeFeedEmptyTitle => 'فيدكِ يستعدّ';

  @override
  String get homeFeedEmptyBody =>
      'تابعي البوتيكات التي تحبّينها ليمتلئ فيدكِ بكل ما يعجبكِ.';

  @override
  String flashDealAlmostGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت $count قطعة',
      few: 'بقيت $count قطع',
      two: 'بقيت قطعتان',
      one: 'بقيت قطعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get couponFreeShipping => 'شحن مجاني';

  @override
  String get wallet => 'محفظتي';

  @override
  String get walletBalance => 'رصيدكِ';

  @override
  String get walletNotWithdrawable => 'يُستخدم داخل ريم فقط';

  @override
  String get walletStatement => 'حركات المحفظة';

  @override
  String get walletEmptyTitle => 'محفظتكِ فارغة الآن';

  @override
  String get walletEmptyBody =>
      'سيظهر هنا رصيد المرتجعات والهدايا والنقاط المحوّلة.';

  @override
  String get walletOffline => 'لا يوجد اتصال. سنحدّث رصيدكِ عند عودة الشبكة.';

  @override
  String get walletSourceRefund => 'قيمة مرتجع';

  @override
  String get walletSourcePoints => 'تحويل نقاط ولاء';

  @override
  String get walletSourceCompensation => 'تعويض من الإدارة';

  @override
  String get walletSourceTopUp => 'شحن رصيد';

  @override
  String get walletSourceGift => 'هدية';

  @override
  String get walletSourceAdjustment => 'تسوية سعر';

  @override
  String get walletSourceOrder => 'دفع طلب';

  @override
  String get walletSourceOrderReversal => 'إلغاء طلب';

  @override
  String get walletSourceOther => 'حركة';

  @override
  String get loyaltyPoints => 'نقاط الولاء';

  @override
  String loyaltyPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا نقاط بعد',
    );
    return '$_temp0';
  }

  @override
  String get loyaltyConvert => 'حوّلي إلى رصيد';

  @override
  String get loyaltyConvertHint => 'كل ١٠ نقاط = ٥٬٠٠٠ ل.س رصيد';

  @override
  String get loyaltyNeedMultipleOfTen => 'النقاط تُحوَّل بمضاعفات العشرة.';

  @override
  String get loyaltyNotEnoughPoints => 'نقاطكِ لا تكفي لهذا التحويل.';

  @override
  String loyaltyConverted(int count) {
    return 'تم تحويل $count نقطة إلى رصيدكِ ✨';
  }

  @override
  String get sellerEarnings => 'أرباحي';

  @override
  String get earningsAvailable => 'جاهز للسحب';

  @override
  String get earningsAvailableHint => 'يُحوَّل أسبوعياً';

  @override
  String get earningsHeld => 'قيد الضمان';

  @override
  String get earningsHeldHint => 'حتى انتهاء مدة الإرجاع';

  @override
  String get earningsFrozen => 'مجمّد لنزاع';

  @override
  String get earningsFrozenHint => 'حتى صدور القرار';

  @override
  String get earningsLifetime => 'الإجمالي منذ البداية';

  @override
  String get earningsLifetimePaid => 'استلمتِه';

  @override
  String get earningsLifetimeGross => 'إجمالي المبيعات';

  @override
  String get earningsLifetimeCommission => 'عمولة المنصة';

  @override
  String get earningsPendingPayouts => 'دفعات قيد التحويل';

  @override
  String get earningsPayoutApproved => 'معتمدة';

  @override
  String get earningsPayoutPending => 'بانتظار الاعتماد';

  @override
  String get earningsStatement => 'كشف الحساب';

  @override
  String get earningsEmptyTitle => 'لا أرباح بعد';

  @override
  String get earningsEmptyBody =>
      'عند تسليم أول طلب ستظهر أرباحكِ هنا خطوة بخطوة.';

  @override
  String get earningsOffline =>
      'لا يوجد اتصال. سنحدّث أرباحكِ عند عودة الشبكة.';

  @override
  String get earningsMoveSale => 'مبيعات طلب';

  @override
  String get earningsMoveReleased => 'تحرير من الضمان';

  @override
  String get earningsMovePayout => 'تحويل أرباح';

  @override
  String get earningsMoveFrozen => 'تجميد لنزاع';

  @override
  String get earningsMoveDisputeDone => 'تسوية نزاع';

  @override
  String get earningsMoveRefund => 'استرداد';

  @override
  String get earningsMoveReversal => 'قيد عكسي';

  @override
  String get earningsMoveOther => 'حركة';

  @override
  String get adminFinance => 'المالية';

  @override
  String get adminFinanceSubtitle =>
      'سلامة الدفاتر والمراكز المالية والمهام العالقة';

  @override
  String get financeSound => 'الدفاتر سليمة';

  @override
  String get financeSoundHint => 'المدين يساوي الدائن، ولا انحراف في أي حساب';

  @override
  String get financeUnsound => 'الدفاتر تحتاج مراجعة';

  @override
  String get financeNotBalanced => 'الميزان غير متوازن';

  @override
  String get financeDiscrepancy => 'الفارق';

  @override
  String get financeTotalDebit => 'إجمالي المدين';

  @override
  String get financeTotalCredit => 'إجمالي الدائن';

  @override
  String financeFindings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملاحظة',
      few: '$count ملاحظات',
      two: 'ملاحظتان',
      one: 'ملاحظة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get financePositions => 'المراكز المالية';

  @override
  String get financeHeld => 'ما نملكه';

  @override
  String get financeOwed => 'ما ندين به';

  @override
  String get financeCoverage => 'التغطية';

  @override
  String get financeCoverageShort => 'التزاماتنا تفوق ما نملك';

  @override
  String get financePlatformCash => 'نقد المنصة';

  @override
  String get financeGatewayReceivable => 'ذمة مزوّد الدفع';

  @override
  String get financeCourierInTransit => 'نقد لدى المندوبين';

  @override
  String get financeSellerPayable => 'مستحقات البائعات';

  @override
  String get financeSellerEscrow => 'ضمان البائعات';

  @override
  String get financeCustomerWallets => 'محافظ الزبونات';

  @override
  String get financeDisputeHeld => 'مجمّد لنزاعات';

  @override
  String get financeLoyaltyLiability => 'التزام نقاط الولاء';

  @override
  String get financeCommissionRevenue => 'إيراد العمولة';

  @override
  String get financeCourierCash => 'كاش لدى المندوبين';

  @override
  String get financeCourierCashEmpty => 'لا كاش معلّق لدى أي مندوب.';

  @override
  String get financeOverdueDisputes => 'نزاعات تجاوزت المهلة';

  @override
  String financeOverdueBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'متأخر $count يوماً',
      few: 'متأخر $count أيام',
      two: 'متأخر يومين',
      one: 'متأخر يوماً',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String get financeNoOverdue => 'لا نزاعات متأخرة.';

  @override
  String get financeFx => 'مركز العملة الأجنبية';

  @override
  String get financeFxRate => 'سعر الصرف';

  @override
  String get financeFxExposure => 'صافي الانكشاف';

  @override
  String get financeFxResult => 'نتيجة التحويلات';

  @override
  String get financeFxSync => 'تحديث السعر الآن';

  @override
  String get financeFxNone => 'لم يُنشر سعر صرف بعد.';

  @override
  String get financeTrialBalance => 'ميزان المراجعة';

  @override
  String get financeAccount => 'الحساب';

  @override
  String get financeBalance => 'الرصيد';

  @override
  String get refresh => 'تحديث';

  @override
  String get invoices => 'الفواتير';

  @override
  String get invoice => 'الفاتورة';

  @override
  String get invoiceCustomerCopy => 'فاتورة الطلب';

  @override
  String get invoiceSellerCopy => 'فاتورة البائعة';

  @override
  String get invoiceNumber => 'رقم الفاتورة';

  @override
  String get invoiceIssuedAt => 'تاريخ الإصدار';

  @override
  String get invoiceOrderNumber => 'رقم الطلب';

  @override
  String get invoiceBilledTo => 'إلى';

  @override
  String get invoiceItems => 'التفاصيل';

  @override
  String get invoiceQuantity => 'الكمية';

  @override
  String get invoiceSubtotal => 'المجموع';

  @override
  String get invoiceDiscount => 'الخصم';

  @override
  String get invoiceShipping => 'التوصيل';

  @override
  String get invoiceTotal => 'الإجمالي';

  @override
  String get invoiceCommission => 'عمولة المنصة';

  @override
  String get invoiceSellerNet => 'صافي البائعة';

  @override
  String get invoiceNoTax => 'هذه فاتورة تجارية وليست فاتورة ضريبية.';

  @override
  String get invoiceEmptyTitle => 'لا فواتير بعد';

  @override
  String get invoiceEmptyBody => 'تصدر الفاتورة عند شحن طلبكِ.';

  @override
  String get invoiceCoupon => 'كوبون';

  @override
  String get trackShipment => 'تتبّع الشحنة';

  @override
  String get trackingCode => 'رمز التتبّع';

  @override
  String get trackExpress => 'توصيل سريع';

  @override
  String get trackScheduledFor => 'موعد التسليم';

  @override
  String get trackDeliveredAt => 'سُلّمت في';

  @override
  String trackAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاولة تسليم',
      few: '$count محاولات تسليم',
      two: 'محاولتا تسليم',
      one: 'محاولة تسليم واحدة',
    );
    return '$_temp0';
  }

  @override
  String get trackJourney => 'مسار الشحنة';

  @override
  String get trackHistory => 'سجل التتبّع';

  @override
  String get trackNotFound => 'لم نجد شحنة بهذا الرمز.';

  @override
  String get shipStageCreated => 'تم تجهيز الطلب';

  @override
  String get shipStageAssigned => 'أُسندت لمندوبة';

  @override
  String get shipStagePickedUp => 'استلمها المندوب';

  @override
  String get shipStageInTransit => 'في الطريق';

  @override
  String get shipStageOutForDelivery => 'خرجت للتسليم';

  @override
  String get shipStageDelivered => 'تم التسليم';

  @override
  String get shipStageFailed => 'تعذّر التسليم';

  @override
  String get shipStageReturning => 'قيد الإرجاع';

  @override
  String get shipStageReturned => 'تم الإرجاع';

  @override
  String get shipStageCancelled => 'ملغاة';

  @override
  String get courierDay => 'طلبات اليوم';

  @override
  String get courierOpen => 'قيد التنفيذ';

  @override
  String get courierDone => 'أُنجزت اليوم';

  @override
  String get courierEmptyTitle => 'لا طلبات اليوم';

  @override
  String get courierEmptyBody => 'ستظهر الطلبات هنا فور إسنادها إليكِ.';

  @override
  String get courierCollect => 'للتحصيل';

  @override
  String get courierPrepaid => 'مدفوع مسبقاً';

  @override
  String get courierCall => 'اتصال';

  @override
  String get courierNavigate => 'الخريطة';

  @override
  String get courierPickUp => 'استلمت الطلب';

  @override
  String get courierStartDelivery => 'خرجت للتسليم';

  @override
  String get courierDeliver => 'تم التسليم';

  @override
  String get courierFail => 'تعذّر التسليم';

  @override
  String get courierInstructions => 'ملاحظات التوصيل';

  @override
  String get courierDeliverTitle => 'تأكيد التسليم';

  @override
  String get courierCollectedAmount => 'المبلغ المحصّل';

  @override
  String get courierCollectedHint => 'اتركيه فارغاً إن حصّلتِ المبلغ كاملاً';

  @override
  String get courierRecipientNote => 'ملاحظة';

  @override
  String get courierConfirm => 'تأكيد';

  @override
  String get courierFailTitle => 'سبب تعذّر التسليم';

  @override
  String get failNoAnswer => 'لم يرد أحد';

  @override
  String get failWrongAddress => 'العنوان خاطئ';

  @override
  String get failCustomerRefused => 'رفضت الزبونة الاستلام';

  @override
  String get failPostponed => 'طلبت التأجيل';

  @override
  String get failUnreachableArea => 'المنطقة غير آمنة أو يصعب الوصول';

  @override
  String get failOther => 'سبب آخر';

  @override
  String get signInWithCode => 'الدخول برمز';

  @override
  String get signInSubtitle => 'أدخلي رقمك وسنرسل لكِ رمزًا.';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get usePasswordInstead => 'استخدام كلمة المرور بدلاً من ذلك';

  @override
  String get passwordOnlyOnKnownDevice =>
      'كلمة المرور تعمل فقط على جهاز سبق أن سجّلتِ الدخول منه.';

  @override
  String get newDeviceCodeSent =>
      'هذا الجهاز جديد. أرسلنا رمزًا إلى رقمك لإكمال تسجيل الدخول.';

  @override
  String get matchCodeLabel => 'رمز المطابقة';

  @override
  String get matchCodeHint =>
      'تأكّدي أن الرسالة تحمل الرقمين نفسهما. لن يطلب منك فريق ريم قراءة الرمز أبدًا.';

  @override
  String codeSentToMasked(String destination) {
    return 'أرسلنا الرمز إلى $destination';
  }

  @override
  String resendInSeconds(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get finishSignUp => 'أكملي إنشاء حسابكِ';

  @override
  String get numberVerified => 'تم تأكيد الرقم';

  @override
  String get passwordOptional => 'كلمة المرور (اختيارية)';

  @override
  String get passwordOptionalHint =>
      'يمكنك تخطّيها. ستسجّلين الدخول برمز في كل مرة.';

  @override
  String get securityCentre => 'الأمان';

  @override
  String get securityCentreSubtitle =>
      'أجهزتك وجلساتك والطرق التي تعيدكِ إلى حسابكِ.';

  @override
  String get passwordSignIn => 'الدخول بكلمة المرور';

  @override
  String get passwordEnabled => 'مفعّلة — على الأجهزة المعروفة فقط';

  @override
  String get passwordDisabled => 'غير مفعّلة — تسجّلين الدخول برمز';

  @override
  String get setPassword => 'تعيين كلمة مرور';

  @override
  String get removePassword => 'إزالة كلمة المرور';

  @override
  String get changeAccountNumber => 'تغيير رقم حسابي';

  @override
  String get changeNumberExplainer =>
      'سنرسل رمزًا إلى رقمك الحالي أولاً، ثم إلى الرقم الجديد.';

  @override
  String get currentNumberCode => 'أرسلنا رمزًا إلى رقمك الحالي';

  @override
  String get newNumberCode => 'أرسلنا رمزًا إلى الرقم الجديد';

  @override
  String get newNumberLabel => 'الرقم الجديد';

  @override
  String get numberChanged => 'تم تغيير رقم حسابكِ';

  @override
  String payoutsFrozenUntil(String date) {
    return 'التحويلات المالية موقوفة حتى $date';
  }

  @override
  String get otherSessionsEnded => 'تم إنهاء بقية الجلسات';

  @override
  String get recoveryCodes => 'رموز الاستعادة';

  @override
  String recoveryCodesRemaining(int count) {
    return '$count غير مستخدم';
  }

  @override
  String get generateRecoveryCodes => 'توليد رموز جديدة';

  @override
  String get recoveryCodesWarning =>
      'دوّنيها الآن. تُعرض مرة واحدة فقط، وتوليد مجموعة جديدة يلغي القديمة.';

  @override
  String get lostYourSim => 'فقدتِ شريحتك؟';

  @override
  String get lostSimExplainer =>
      'إن فقدتِ رقمك نهائيًا، يمكننا مراجعة حسابكِ يدويًا. تستغرق المراجعة عدة أيام عن قصد.';

  @override
  String get recoveryNoDocuments =>
      'لن نطلب منك صورة شخصية ولا صورة عن أي وثيقة هوية.';

  @override
  String get recoveryContactNumber => 'رقم يمكننا التواصل معكِ عليه الآن';

  @override
  String get recoveryQuestionsTitle => 'ماذا تتذكّرين؟';

  @override
  String get recoveryQuestionsHint => 'أجيبي عمّا تستطيعين. لا شيء هنا إلزامي.';

  @override
  String get recoveryRegistrationMonth => 'متى انضممتِ تقريبًا؟ (سنة-شهر)';

  @override
  String get recoveryLastOrderMonth => 'متى كان آخر طلب لك؟ (سنة-شهر)';

  @override
  String get recoveryLastOrderTotal => 'كم كانت قيمته تقريبًا؟';

  @override
  String get recoveryDeviceLabel => 'ما اسم أحد أجهزتك؟';

  @override
  String get recoverySubmitted => 'استلمنا طلبكِ';

  @override
  String get recoveryKeepSecret =>
      'احتفظي بهذا الرمز. إنه الطريقة الوحيدة لمتابعة طلبكِ.';

  @override
  String get recoveryCaseOpenWarning => 'طلب أحدهم نقل حسابكِ إلى رقم آخر.';

  @override
  String recoveryCaseCoolOff(String date) {
    return 'سيُنقل حسابكِ في $date ما لم توقفي ذلك.';
  }

  @override
  String get stopThisRequest => 'لستُ أنا — أوقفي الطلب';

  @override
  String get recoveryCaseCancelled => 'تم إيقاف الطلب';

  @override
  String get activeSessions => 'الجلسات النشطة';

  @override
  String get thisDevice => 'هذا الجهاز';

  @override
  String get signOutEverywhere => 'تسجيل الخروج من كل الأجهزة الأخرى';

  @override
  String sessionExpiresOn(String date) {
    return 'الجلسة سارية حتى $date';
  }

  @override
  String get deviceTrusted => 'مُوثّق على هذا الجهاز';

  @override
  String get deviceNotVerified => 'لم يتم تسجيل الدخول من هنا';

  @override
  String newDeviceCooldown(String date) {
    return 'هذا الجهاز جديد. التغييرات الحساسة تُفتح $date.';
  }

  @override
  String get verifyToContinue => 'تأكّدي من هويتك';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get copy => 'نسخ';

  @override
  String get close => 'إغلاق';

  @override
  String get confirm => 'تأكيد';

  @override
  String get homeShowcaseEyebrow => 'مباشرةً من البوتيكات';

  @override
  String get homeShowcaseTitle => 'وصل حديثاً';

  @override
  String get homeShowcaseSubtitle =>
      'أحدث القطع تُروى كحكايات — تصفّحي، أحبّي، تسوّقي.';

  @override
  String get homeShapePosts => 'منشورات';

  @override
  String get homeShapeMosaic => 'موزاييك';

  @override
  String get homeShapeGrid => 'شبكة';

  @override
  String postLikesCount(String count) {
    return '$count إعجاب';
  }

  @override
  String postViewComments(String count) {
    return 'عرض كل التعليقات ($count)';
  }

  @override
  String get postMore => 'المزيد';

  @override
  String shortMinutesAgo(int count) {
    return '$count د';
  }

  @override
  String shortHoursAgo(int count) {
    return '$count س';
  }

  @override
  String shortDaysAgo(int count) {
    return '$count ي';
  }

  @override
  String shortWeeksAgo(int count) {
    return '$count أ';
  }

  @override
  String get homeBoutiqueStories => 'ستوريات البوتيكات';

  @override
  String piecesCount(String count) {
    return '$count قطعة';
  }

  @override
  String get justIn => 'وصل حديثاً';

  @override
  String get addedToBag => 'أُضيفت إلى سلّتك';

  @override
  String get sellerCommandCentre => 'مركز الإدارة';

  @override
  String get sellerDashboardUnavailable => 'لوحة الإدارة غير متاحة';

  @override
  String get messages => 'الرسائل';

  @override
  String get sellerNeedsYou => 'يحتاج انتباهكِ الآن';

  @override
  String get sellerAllClear => 'كل شيء تمام — لا شيء ينتظركِ';

  @override
  String get sellerPendingOrders => 'بانتظار التأكيد';

  @override
  String get sellerRunningLow => 'أوشك على النفاد';

  @override
  String get sellerOpenTasks => 'مهام مفتوحة';

  @override
  String get sellerRevenue => 'الإيرادات';

  @override
  String get sellerProfit => 'الربح';

  @override
  String get sellerMargin => 'هامش الربح';

  @override
  String get sellerVsPrior => 'مقارنةً بالفترة السابقة';

  @override
  String get periodToday => 'اليوم';

  @override
  String get periodWeek => 'الأسبوع';

  @override
  String get periodMonth => 'الشهر';

  @override
  String get periodYear => 'السنة';

  @override
  String get periodDaily => 'يومي';

  @override
  String get periodWeekly => 'أسبوعي';

  @override
  String get periodMonthly => 'شهري';

  @override
  String get periodYearly => 'سنوي';

  @override
  String get sellerSalesTrend => 'منحنى المبيعات';

  @override
  String get sellerQuickActions => 'إجراءات سريعة';

  @override
  String get sellerAddProduct => 'إضافة منتج';

  @override
  String get sellerManageOrders => 'إدارة الطلبات';

  @override
  String get sellerAnalytics => 'التحليلات';

  @override
  String get sellerCreateCoupon => 'إنشاء كوبون';

  @override
  String get sellerAnnouncement => 'إعلان';

  @override
  String get sellerManageAll => 'إدارة الكل';

  @override
  String get sellerTopProducts => 'الأكثر مبيعاً';

  @override
  String get sellerLowStockTitle => 'مخزون منخفض';

  @override
  String get sellerOutOfStock => 'نفد المخزون';

  @override
  String get sellerRestock => 'إعادة التوريد';

  @override
  String get sellerStorePerformance => 'صحة المتجر';

  @override
  String get sellerFulfillment => 'تنفيذ الطلبات';

  @override
  String get sellerResponsiveness => 'سرعة الرد';

  @override
  String get sellerProductQuality => 'جودة المنتجات';

  @override
  String get sellerConversionMetrics => 'معدّل التحويل';

  @override
  String get sellerConversionRate => 'نسبة التحويل';

  @override
  String get sellerProductViews => 'مشاهدات المنتجات';

  @override
  String get sellerCartAdds => 'إضافات للسلة';

  @override
  String get sellerWishlistAdds => 'إضافات للمفضّلة';

  @override
  String get sellerInsights => 'رؤى ذكية';

  @override
  String get sellerRecentReviews => 'آخر التقييمات';

  @override
  String get sellerTasks => 'قائمة المهام';

  @override
  String get sellerGoals => 'أهداف المتجر';

  @override
  String get orderNew => 'جديدة';

  @override
  String get orderProcessing => 'قيد التجهيز';

  @override
  String get orderReady => 'جاهزة للشحن';

  @override
  String get orderDelivered => 'تم التسليم';

  @override
  String get orderCancelled => 'ملغاة';

  @override
  String get orderReturned => 'مُرتجعة';

  @override
  String get sellerLiveStore => 'المتجر يعمل';

  @override
  String get sellerGroupStore => 'إدارة المتجر';

  @override
  String get sellerGroupBusiness => 'الأعمال والمالية';

  @override
  String get sellerGroupPreferences => 'التفضيلات والأمان';

  @override
  String get sellerShippingSettings => 'إعدادات الشحن';

  @override
  String get sellerPaymentSettings => 'إعدادات الدفع';

  @override
  String get sellerStorePolicies => 'سياسات المتجر';

  @override
  String get sellerFinancialReports => 'التقارير المالية';

  @override
  String get sellerWithdrawalCentre => 'مركز السحب';

  @override
  String get sellerTeamManagement => 'إدارة الفريق';

  @override
  String get sellerSubscriptionPlan => 'الاشتراك والباقة';

  @override
  String get sellerActivityLog => 'سجلّ النشاط';

  @override
  String get sellerSupport => 'دعم البائعات';

  @override
  String get sellerAvailableToWithdraw => 'متاح للسحب';

  @override
  String get sellerWithdraw => 'سحب';

  @override
  String get sellerPaidOut => 'المدفوع';

  @override
  String get sellerFees => 'العمولات';

  @override
  String get sellerPendingPayout => 'قيد الانتظار';

  @override
  String get sellerEditStore => 'تعديل المتجر';

  @override
  String sellerPlanBadge(String plan) {
    return 'باقة $plan';
  }

  @override
  String sellerMemberSince(String year) {
    return 'تبيع منذ $year';
  }

  @override
  String sellerRatingSummary(String rating, String count) {
    return '$rating · $count تقييم';
  }

  @override
  String sellerPlatformFooter(String version) {
    return 'منصّة البائعات · إصدار $version';
  }

  @override
  String get sellerNoProductsYet => 'لا توجد منتجات بعد';

  @override
  String get sellerNoProductsBlurb => 'أضيفي أول قطعة وستظهر هنا.';

  @override
  String get sellerNewProduct => 'منتج جديد';

  @override
  String get sellerEditProduct => 'تعديل';

  @override
  String get sellerSetActive => 'نشر';

  @override
  String get sellerMoveToDraft => 'نقل إلى المسودّات';

  @override
  String get sellerArchive => 'أرشفة';

  @override
  String sellerStock(String count) {
    return '$count في المخزون';
  }

  @override
  String get surfaceActivity => 'النشاط';

  @override
  String get surfaceCustomers => 'الزبونات';

  @override
  String get surfaceMarketing => 'التسويق';

  @override
  String savedCount(String count) {
    return '$count حفظ';
  }

  @override
  String get formNewProduct => 'منتج جديد';

  @override
  String get formEditProduct => 'تعديل المنتج';

  @override
  String get formTitle => 'العنوان';

  @override
  String get formTitleRequired => 'العنوان مطلوب';

  @override
  String get formDescription => 'الوصف';

  @override
  String get formDescriptionRequired => 'الوصف مطلوب';

  @override
  String get formCategory => 'القسم';

  @override
  String get formCategoryRequired => 'القسم مطلوب';

  @override
  String get formPrice => 'السعر';

  @override
  String get formPriceInvalid => 'أدخلي سعراً صحيحاً';

  @override
  String get formStock => 'المخزون';

  @override
  String get formStockInvalid => 'أدخلي كميّة صحيحة';

  @override
  String get formStatus => 'الحالة';

  @override
  String get formFeatured => 'مميّز';

  @override
  String get formShowInFeed => 'إظهار في المنشورات';

  @override
  String get formAddImage => 'إضافة صورة';

  @override
  String get formAddVariant => 'إضافة خيار';

  @override
  String get formPublishProduct => 'نشر المنتج';

  @override
  String get formProductCreated => 'تم نشر المنتج';

  @override
  String get formProductUpdated => 'تم حفظ التعديلات';

  @override
  String get formAiDescription => 'اكتبي بالذكاء الاصطناعي';

  @override
  String get formAiDescriptionAdded => 'تمّت كتابة الوصف';

  @override
  String get formAiTags => 'اقتراح وسوم';

  @override
  String get formNoTags => 'لا توجد وسوم مقترحة';

  @override
  String get formTitleCategoryFirst => 'أضيفي العنوان والقسم أولاً';

  @override
  String get categories => 'الأقسام';

  @override
  String get adminSettings => 'إعدادات المشرِفة';

  @override
  String get adminSecurity => 'الأمان';

  @override
  String get adminUserManagement => 'إدارة المستخدمات';

  @override
  String get adminSellerManagement => 'إدارة البائعات';

  @override
  String get adminProductManagement => 'إدارة المنتجات';

  @override
  String get adminOrderManagement => 'إدارة الطلبات';

  @override
  String get adminFinancialManagement => 'الإدارة المالية';

  @override
  String get adminCommissionManagement => 'إدارة العمولات';

  @override
  String get adminReportsAndAnalytics => 'التقارير والتحليلات';

  @override
  String get adminReports => 'التقارير';

  @override
  String get adminModerationTools => 'أدوات الإشراف';

  @override
  String get adminSupportManagement => 'إدارة الدعم';

  @override
  String get adminAuditLogs => 'سجلّات التدقيق';

  @override
  String get adminSystemSettings => 'إعدادات النظام';

  @override
  String get adminNotificationCampaigns => 'حملات الإشعارات';

  @override
  String get adminNotificationAnalytics => 'تحليلات الإشعارات';

  @override
  String get adminSectionSubtitle =>
      'أدوات تشغيلية، وقوائم مراجعة، وسجلّات حيّة.';

  @override
  String get adminSectionUnavailable => 'تعذّر تحميل هذا القسم.';

  @override
  String get adminNoMatchingRecords => 'لا توجد سجلّات مطابقة.';

  @override
  String get adminNoDataYet => 'لا توجد بيانات بعد.';

  @override
  String get adminNoRankedData => 'لا توجد بيانات مرتّبة بعد.';

  @override
  String get adminNoRecentActivity => 'لا يوجد نشاط إداري حديث.';

  @override
  String get adminAuditUnavailable => 'تعذّر تحميل سجلّ التدقيق';

  @override
  String get adminRetryFromAudit => 'أعيدي المحاولة من سجلّات التدقيق';

  @override
  String get adminClearSearch => 'مسح البحث';

  @override
  String get adminQuickActions => 'إجراءات سريعة';

  @override
  String get adminRecentActivity => 'النشاط الأخير';

  @override
  String get adminOnlineNow => 'متصلات الآن';

  @override
  String get adminVerifiedSellersOnly => 'البائعات الموثّقات فقط';

  @override
  String get adminRoleFilterHint => 'مستخدمة، بائعة، مشرِفة';

  @override
  String get adminSellerReview => 'مراجعة البائعات';

  @override
  String get adminSupportQueue => 'قائمة الدعم';

  @override
  String get adminModeration => 'الإشراف';

  @override
  String get adminFinancials => 'المالية';

  @override
  String get adminCustomers => 'الزبونات';

  @override
  String get adminCampaigns => 'الحملات';

  @override
  String get adminNotifyAnalytics => 'تحليلات الإشعارات';

  @override
  String get adminBusinessIntelligence => 'ذكاء الأعمال';

  @override
  String get adminAnalyticsSubtitle =>
      'المبيعات والإيرادات والتحويل والفئات والعمليات الحيّة.';

  @override
  String get adminRevenueTrend => 'منحنى الإيرادات';

  @override
  String get adminConversionFunnel => 'قمع التحويل';

  @override
  String get adminTopProducts => 'أفضل المنتجات';

  @override
  String get adminSellerPerformance => 'أداء البائعات';

  @override
  String get adminGrossRevenue => 'الإيراد الإجمالي';

  @override
  String get adminNetRevenue => 'الإيراد الصافي';

  @override
  String get adminAov => 'متوسط قيمة الطلب';

  @override
  String get adminRepeatRate => 'نسبة التكرار';

  @override
  String get adminRetentionRate => 'نسبة الاحتفاظ';

  @override
  String get adminExportExcel => 'تصدير Excel';

  @override
  String get adminExportPdf => 'تصدير PDF';

  @override
  String get adminNewCampaign => 'حملة جديدة';

  @override
  String get adminNewCampaignTitle => 'حملة إشعارات جديدة';

  @override
  String get adminCampaignName => 'اسم الحملة';

  @override
  String get adminNotificationTitle => 'عنوان الإشعار';

  @override
  String get adminMessageBody => 'نصّ الرسالة';

  @override
  String get adminChannels => 'قنوات الإرسال';

  @override
  String get adminRunCampaign => 'تشغيل الحملة';

  @override
  String get adminCampaignCreated => 'تم إنشاء الحملة.';

  @override
  String get adminCampaignQueued => 'الحملة في قائمة الإرسال.';

  @override
  String get adminCampaignFieldsRequired =>
      'الاسم والعنوان والنصّ حقول مطلوبة.';

  @override
  String get adminSelectChannel => 'اختاري قناة إرسال واحدة على الأقل.';

  @override
  String get adminScheduleIsoHint => 'استخدمي صيغة وقت ISO للجدولة.';

  @override
  String get create => 'إنشاء';

  @override
  String adminLastDays(int count) {
    return 'آخر $count يوم';
  }

  @override
  String get sellerDeleteProduct => 'حذف المنتج؟';

  @override
  String sellerDeleteProductBody(String title) {
    return 'سيُحذف «$title» نهائياً.';
  }

  @override
  String get mediaSourceTitle => 'أضيفي صورة';

  @override
  String get mediaFromCamera => 'التقطي صورة';

  @override
  String get mediaFromGallery => 'اختاري من المعرض';

  @override
  String get mediaUploading => 'جارٍ الرفع…';

  @override
  String get mediaUploadFailed => 'تعذّر الرفع';

  @override
  String get mediaRemovePhoto => 'إزالة الصورة';

  @override
  String get mediaCoverBadge => 'الغلاف';

  @override
  String get mediaPickFailed =>
      'تعذّر فتح الصور. تأكّدي من إذن الصور في إعدادات التطبيق.';

  @override
  String get mediaProductGallery => 'صور المنتج';

  @override
  String get mediaStoryLabel => 'صورة القصة';

  @override
  String get mediaWaitForUploads => 'انتظري انتهاء رفع الصور.';

  @override
  String mediaGalleryHint(int count) {
    return 'أول صورة هي الغلاف. حتى $count صور.';
  }

  @override
  String get mediaStoryRequired => 'اختاري صورة القصة أولاً.';

  @override
  String get storeLogo => 'شعار المتجر';

  @override
  String get governmentIdDocument => 'صورة الهوية الشخصية';

  @override
  String get businessLicenseDocument => 'السجل التجاري أو الرخصة';

  @override
  String get verificationDocumentsPrivate =>
      'لا يفتحها أحد سواكِ وفريق المراجعة، ولا تظهر في متجركِ أبداً.';

  @override
  String get verificationDocumentsHint => 'صوّري كل مستند كاملاً وبإضاءة جيدة.';

  @override
  String get verificationSectionStore => 'متجركِ';

  @override
  String get verificationSectionContact => 'التواصل والعناوين';

  @override
  String get verificationSectionDocuments => 'المستندات';

  @override
  String get verificationSectionPayout => 'الحساب البنكي';

  @override
  String get verificationSectionOperations => 'الشحن والإرجاع';

  @override
  String get shippingMethodsHint => 'مندوب، استلام من المتجر، توصيل بنفس اليوم';

  @override
  String get productCategoriesHint => 'أزياء، عطور، مشغولات يدوية';

  @override
  String get verificationResubmitNotice =>
      'لديكِ طلب سابق. التعديل والإرسال يستبدلانه.';

  @override
  String get mediaDocumentAttached => 'مرفق';

  @override
  String get verificationUploadPending => 'انتظري انتهاء رفع المستندات.';

  @override
  String verificationFieldRequired(String field) {
    return '«$field» مطلوب.';
  }

  @override
  String get verificationStatusPending => 'في الانتظار';

  @override
  String get verificationStatusUnderReview => 'قيد المراجعة';

  @override
  String get verificationStatusNeedsMoreDocuments => 'بحاجة إلى مستندات إضافية';

  @override
  String get verificationStatusNeedsMoreInfo => 'بحاجة إلى معلومات إضافية';

  @override
  String get verificationStatusApproved => 'موثّقة';

  @override
  String get verificationStatusRejected => 'مرفوضة';

  @override
  String get verificationStatusSuspended => 'موقوفة';

  @override
  String get mediaFromFiles => 'اختاري ملفاً';

  @override
  String get mediaDocumentsHint => 'صورة واضحة، أو ملف PDF الأصلي.';

  @override
  String mediaTooLarge(String size) {
    return 'هذا الملف أكبر من $size ميغابايت.';
  }

  @override
  String get chatAttachTitle => 'أرفقي صورة';

  @override
  String get chatAttachmentFailed => 'تعذّر إرسال الصورة.';

  @override
  String get chatSharedMedia => 'الصور المتبادلة';

  @override
  String get chatNoSharedMedia => 'لم تُشارَك أي صورة هنا بعد.';

  @override
  String get chatPhotoMessage => 'صورة';

  @override
  String get chatStartConversation => 'ابدئي المحادثة';

  @override
  String get chatStartConversationHint =>
      'اسألي عن القطعة أو المقاس أو التوصيل، أو أرسلي صورة أو ملاحظة صوتية.';

  @override
  String get chatShareImage => 'أرسلي صورة';

  @override
  String get voicePermissionDenied => 'يحتاج ريم إذن استخدام الميكروفون.';

  @override
  String get voiceRecordFailed => 'تعذّر بدء التسجيل.';

  @override
  String get voiceSend => 'أرسلي التسجيل';

  @override
  String get voiceRecord => 'سجّلي ملاحظة صوتية';

  @override
  String get voiceMessage => 'ملاحظة صوتية';

  @override
  String get voiceUnavailable => 'هذا التسجيل غير متاح.';

  @override
  String get chatFromFiles => 'أرسلي ملفاً';

  @override
  String get chatOpenFileFailed =>
      'لا يوجد تطبيق على هذا الهاتف يفتح هذا الملف.';

  @override
  String get chatFileMessage => 'ملف';

  @override
  String get chatDownloadFailed => 'تعذّر تنزيل الملف.';

  @override
  String get sellerOrdersTitle => 'طلباتي';

  @override
  String get sellerOrdersTabNew => 'جديدة';

  @override
  String get sellerOrdersTabPreparing => 'قيد التجهيز';

  @override
  String get sellerOrdersTabReady => 'جاهزة';

  @override
  String get sellerOrdersTabShipping => 'بالطريق';

  @override
  String get sellerOrdersTabReturns => 'مرتجعات';

  @override
  String get sellerOrdersTabCompleted => 'منتهية';

  @override
  String get sellerOrdersOffline => 'لا يوجد اتصال بالإنترنت';

  @override
  String get sellerOrdersLoadFailed => 'تعذّر فتح الطلب';

  @override
  String get sellerOrdersUpdated => 'تم تحديث الطلب';

  @override
  String get sellerOrdersEmptyNew => 'لا طلبات جديدة';

  @override
  String get sellerOrdersEmptyPreparing => 'لا شيء قيد التجهيز';

  @override
  String get sellerOrdersEmptyReady => 'لا شيء جاهز للشحن';

  @override
  String get sellerOrdersEmptyShipping => 'لا شحنات بالطريق';

  @override
  String get sellerOrdersEmptyReturns => 'لا مرتجعات';

  @override
  String get sellerOrdersEmptyCompleted => 'لا طلبات منتهية بعد';

  @override
  String get sellerOrdersEmptyNewBody =>
      'ستظهر الطلبات هنا فور أن تشتري زبونة منكِ.';

  @override
  String get sellerOrdersEmptyReturnsBody => 'وهذا خبر جيد.';

  @override
  String get sellerOrdersEmptyBody => 'ستنتقل الطلبات إلى هنا مع تقدّمها.';

  @override
  String get sellerOrderActionConfirm => 'قبول الطلب';

  @override
  String get sellerOrderActionReady => 'جاهز للشحن';

  @override
  String get sellerOrderActionHandOver => 'سلّمتُه للتوصيل';

  @override
  String get sellerOrderActionDeliver => 'تم التسليم';

  @override
  String get sellerOrderActionCancel => 'إلغاء الطلب';

  @override
  String get sellerOrderConfirmed => 'قبلتِ الطلب، صار قيد التجهيز';

  @override
  String get sellerOrderMarkedReady => 'الطلب جاهز للشحن';

  @override
  String get sellerOrderHandedOver => 'سُجّل خروج الطلب للتوصيل';

  @override
  String get sellerOrderDelivered => 'سُجّل التسليم';

  @override
  String get sellerOrderCancelled => 'أُلغي الطلب وأُعيدت القطع للمخزون';

  @override
  String get sellerParcelStatusNew => 'طلب جديد';

  @override
  String get sellerParcelStatusAwaitingConfirmation => 'بانتظار تأكيدكِ';

  @override
  String get sellerParcelStatusPreparing => 'قيد التجهيز';

  @override
  String get sellerParcelStatusReadyToShip => 'جاهز للشحن';

  @override
  String get sellerParcelStatusHandedToCourier => 'مع المندوب';

  @override
  String get sellerParcelStatusInTransit => 'بالطريق';

  @override
  String get sellerParcelStatusDelivered => 'تم التسليم';

  @override
  String get sellerParcelStatusDeliveryFailed => 'فشل التسليم';

  @override
  String get sellerParcelStatusCancelledByCustomer => 'ألغته الزبونة';

  @override
  String get sellerParcelStatusCancelledBySeller => 'ألغيتِه';

  @override
  String get sellerParcelStatusRejectedOnDelivery => 'رفضت الاستلام';

  @override
  String get sellerParcelStatusReturnRequested => 'طلب إرجاع';

  @override
  String get sellerParcelStatusReturnInTransit => 'المرتجع بالطريق';

  @override
  String get sellerParcelStatusReturned => 'وصل المرتجع';

  @override
  String get sellerParcelStatusExchangeInProgress => 'قيد الاستبدال';

  @override
  String get sellerParcelStatusExchanged => 'تم الاستبدال';

  @override
  String get sellerParcelStatusRefundPending => 'قيد الاسترداد';

  @override
  String get sellerParcelStatusRefunded => 'تم الاسترداد';

  @override
  String get sellerParcelStatusDisputed => 'قيد النزاع';

  @override
  String get sellerFulfilmentPlatformCourier => 'مندوب المنصة';

  @override
  String get sellerFulfilmentThirdParty => 'شركة شحن';

  @override
  String get sellerFulfilmentSelfShips => 'توصيل بنفسكِ';

  @override
  String get sellerFulfilmentPickupPoint => 'استلام من نقطة';

  @override
  String get sellerOrderCashOnDelivery => 'الدفع عند الاستلام';

  @override
  String get sellerOrderItemsToPack => 'ما يجب تجهيزه';

  @override
  String get sellerOrderStepPlaced => 'وصل الطلب';

  @override
  String get sellerOrderStepConfirmed => 'أكّدتِ الاستلام';

  @override
  String get sellerOrderStepShipped => 'خرج للتوصيل';

  @override
  String get sellerOrderStepDelivered => 'تم التسليم';

  @override
  String get sellerOrderCourierAssigned => 'أُسند لمندوب';

  @override
  String get sellerOrderCourierPending => 'بانتظار مندوب';

  @override
  String get sellerOrderItemsSubtotal => 'إجمالي القطع';

  @override
  String get sellerOrderDiscount => 'حسم';

  @override
  String get sellerOrderCommission => 'عمولة المنصة';

  @override
  String get sellerOrderNet => 'صافي أرباحكِ';

  @override
  String get sellerOrderEscrowReleased => 'أصبحت هذه الأرباح متاحة للتحويل.';

  @override
  String get sellerOrderEscrowPending =>
      'تُحتسب الأرباح بعد التسليم وانتهاء مهلة الإرجاع.';

  @override
  String get sellerOrderCallCustomer => 'اتصلي بالزبونة';

  @override
  String get sellerOrderAddressCopied => 'نُسخ العنوان';

  @override
  String get sellerCancelSubtitle =>
      'ستُعاد القطع إلى مخزونكِ، وستصل الزبونة رسالة بالسبب الذي تكتبينه.';

  @override
  String get sellerCancelReasonLabel => 'السبب';

  @override
  String get sellerCancelReasonHint => 'اكتبي سبباً واضحاً للزبونة';

  @override
  String get sellerCancelReasonTooShort => 'اكتبي سبباً من خمسة أحرف على الأقل';

  @override
  String get sellerCancelConfirm => 'تأكيد الإلغاء';

  @override
  String get sellerCancelDismiss => 'تراجع';

  @override
  String get sellerCancelPresetOutOfStock => 'الكمية غير متوفرة';

  @override
  String get sellerCancelPresetSizeGone => 'المقاس المطلوب نفد';

  @override
  String get sellerCancelPresetPriceError => 'خطأ في السعر المعروض';

  @override
  String get sellerCancelPresetNoTime => 'لا أستطيع التجهيز بالوقت المطلوب';

  @override
  String get sellerDeliverTitle => 'تأكيد التسليم';

  @override
  String get sellerDeliverSubtitleCash =>
      'اكتبي المبلغ الذي استلمتِه فعلاً. اتركيه فارغاً إذا استلمتِ المبلغ كاملاً.';

  @override
  String get sellerDeliverSubtitlePrepaid =>
      'الطلب مدفوع مسبقاً، لا يوجد مبلغ للتحصيل.';

  @override
  String get sellerDeliverCollectedLabel => 'المبلغ المُحصّل';

  @override
  String get sellerDeliverCollectedHint =>
      'اتركيه فارغاً إذا استلمتِ المبلغ كاملاً';

  @override
  String sellerOrderEscrowOn(String date) {
    return 'تُتاح الأرباح بعد انتهاء مهلة الإرجاع في $date.';
  }

  @override
  String get checkoutTitle => 'إتمام الطلب';

  @override
  String get checkoutDeliveryAddress => 'عنوان التوصيل';

  @override
  String get checkoutSavedAddresses => 'عناوينكِ المحفوظة';

  @override
  String get checkoutNewAddress => 'عنوان جديد';

  @override
  String get checkoutUseThisAddress => 'التوصيل إلى هنا';

  @override
  String get checkoutSaveAddress => 'احفظي هذا العنوان لطلباتكِ القادمة';

  @override
  String get checkoutRecipientName => 'اسم المستلِمة';

  @override
  String get checkoutRecipientPhone => 'رقم الهاتف';

  @override
  String get checkoutGovernorate => 'المحافظة';

  @override
  String get checkoutDistrict => 'المنطقة';

  @override
  String get checkoutDistrictOptional => 'المنطقة (اختياري)';

  @override
  String get checkoutCity => 'المدينة أو البلدة';

  @override
  String get checkoutAddressLine => 'العنوان بالتفصيل';

  @override
  String get checkoutAddressLineHint => 'الشارع، رقم البناء، الطابق';

  @override
  String get checkoutLandmark => 'أقرب معلم (اختياري)';

  @override
  String get checkoutLandmarkHint => 'مقابل الصيدلية';

  @override
  String get checkoutInstructions => 'ملاحظات للتوصيل (اختياري)';

  @override
  String get checkoutInstructionsHint => 'اتصلي قبل الوصول';

  @override
  String get checkoutRural => 'المنطقة ريفية';

  @override
  String get checkoutRuralHint => 'أجرة التوصيل ومدّته تختلفان عن مركز المدينة';

  @override
  String get checkoutCoupon => 'كوبون الحسم';

  @override
  String get checkoutCouponOptional => 'رمز الكوبون (اختياري)';

  @override
  String get checkoutPaymentMethod => 'طريقة الدفع';

  @override
  String get checkoutOrderSummary => 'ملخّص الطلب';

  @override
  String get checkoutSubtotal => 'المجموع الفرعي';

  @override
  String get checkoutDelivery => 'التوصيل';

  @override
  String get checkoutPlaceOrder => 'تأكيد الطلب';

  @override
  String get checkoutRequired => 'هذا الحقل مطلوب';

  @override
  String get checkoutInvalidPhone => 'اكتبي رقم هاتف صحيحاً';

  @override
  String get checkoutChooseGovernorate => 'اختاري المحافظة';

  @override
  String get checkoutChoosePayment => 'اختاري طريقة الدفع';

  @override
  String get checkoutTotalPending => 'يُحتسب المجموع النهائي عند تأكيد الطلب';

  @override
  String checkoutPlacedSuccess(String number) {
    return 'تم تأكيد طلبكِ $number';
  }

  @override
  String checkoutSplitNotice(String count) {
    return 'طلبكِ من $count بائعات، وسيصلكِ على عدة شحنات — بأجرة توصيل واحدة.';
  }
}
