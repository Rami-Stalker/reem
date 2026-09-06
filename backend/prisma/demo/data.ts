/**
 * The Arabic content dictionaries the demo dataset is generated from.
 *
 * Kept separate from the generators so the copy can be reviewed (and handed to
 * the client) without reading seeding code, and so a real catalog import later
 * replaces this file alone.
 */

// ─────────────────────────── People ───────────────────────────

export interface SellerSeed {
  name: string;
  username: string;
  phone: string;
  store: string;
  legalName: string;
  bio: string;
  city: string;
  governorate: string;
  categories: string[];
  level: 'BASIC' | 'VERIFIED' | 'PREMIUM';
  years: number;
}

/**
 * Nine additional boutiques on top of the three the foundation seed creates,
 * so price comparison, storefronts and the seller leaderboard all have real
 * spread. Phones are Syrian (+963) — the platform serves Syria.
 */
export const SELLERS: SellerSeed[] = [
  {
    name: 'رهف الشامي',
    username: 'rahaf_atelier',
    phone: '+963931000101',
    store: 'أتيليه رهف',
    legalName: 'رهف محمود الشامي',
    bio: 'فساتين سهرة وخطوبة مصمّمة يدوياً في قلب دمشق ✨',
    city: 'دمشق',
    governorate: 'دمشق',
    categories: ['dresses', 'abayas', 'skirts'],
    level: 'PREMIUM',
    years: 8,
  },
  {
    name: 'لمى الحلبي',
    username: 'lama_boutique',
    phone: '+963931000102',
    store: 'بوتيك لمى',
    legalName: 'لمى أحمد الحلبي',
    bio: 'تريكو وكنزات شتوية بخامات طبيعية — من حلب إلى كل سوريا 🧶',
    city: 'حلب',
    governorate: 'حلب',
    categories: ['knitwear', 'activewear', 'scarves'],
    level: 'VERIFIED',
    years: 5,
  },
  {
    name: 'جنى اللاذقاني',
    username: 'jana_bags',
    phone: '+963931000103',
    store: 'جنى للحقائب',
    legalName: 'جنى سامر اللاذقاني',
    bio: 'حقائب وأحذية أصلية بضمان الاستبدال خلال ٧ أيام 👜',
    city: 'اللاذقية',
    governorate: 'اللاذقية',
    categories: ['handbags', 'shoes'],
    level: 'VERIFIED',
    years: 6,
  },
  {
    name: 'ريما الحمصي',
    username: 'reema_beauty',
    phone: '+963931000104',
    store: 'ريما بيوتي',
    legalName: 'ريما خالد الحمصي',
    bio: 'مكياج ومستحضرات أصلية ١٠٠٪ مع فاتورة من الوكيل 💄',
    city: 'حمص',
    governorate: 'حمص',
    categories: ['face-makeup', 'lips', 'moisturisers'],
    level: 'PREMIUM',
    years: 7,
  },
  {
    name: 'سلمى الطرطوسي',
    username: 'salma_care',
    phone: '+963931000105',
    store: 'سلمى للعناية',
    legalName: 'سلمى عماد الطرطوسي',
    bio: 'عناية بالبشرة بمكوّنات طبيعية ووصفات مجرّبة 🌿',
    city: 'طرطوس',
    governorate: 'طرطوس',
    categories: ['moisturisers', 'cleansers', 'baby-skincare'],
    level: 'BASIC',
    years: 3,
  },
  {
    name: 'دانا العطّار',
    username: 'dana_parfum',
    phone: '+963931000106',
    store: 'دانا للعطور',
    legalName: 'دانا فادي العطّار',
    bio: 'عطور شرقية وفرنسية بتركيز عالٍ وثبات طويل 🌸',
    city: 'دمشق',
    governorate: 'ريف دمشق',
    categories: ['perfumes'],
    level: 'VERIFIED',
    years: 9,
  },
  {
    name: 'ميساء الورد',
    username: 'maysa_flowers',
    phone: '+963931000107',
    store: 'ميساء للورد والهدايا',
    legalName: 'ميساء نبيل الورد',
    bio: 'باقات ورد طبيعي وتنسيق هدايا المناسبات خلال ٢٤ ساعة 💐',
    city: 'دمشق',
    governorate: 'دمشق',
    categories: ['bouquets', 'graduation-gifts', 'ramadan-gifts'],
    level: 'VERIFIED',
    years: 4,
  },
  {
    name: 'هبة الحلواني',
    username: 'hiba_sweets',
    phone: '+963931000108',
    store: 'حلويات هبة',
    legalName: 'هبة وليد الحلواني',
    bio: 'شوكولا وعلب ضيافة محضّرة يومياً بمكوّنات فاخرة 🍫',
    city: 'حماة',
    governorate: 'حماة',
    categories: ['chocolate', 'candy-boxes'],
    level: 'BASIC',
    years: 2,
  },
  {
    name: 'آية الأم والطفل',
    username: 'aya_baby',
    phone: '+963931000109',
    store: 'آية للأم والطفل',
    legalName: 'آية رامي الخطيب',
    bio: 'كل ما تحتاجه الأم الجديدة — أطقم مواليد ومستلزمات يومية 🍼',
    city: 'السويداء',
    governorate: 'السويداء',
    categories: ['baby-sets', 'baby-shoes', 'baby-essentials'],
    level: 'VERIFIED',
    years: 5,
  },
];

/**
 * Lightweight community accounts. They never place orders — they exist so that
 * likes, followers, story views and comment threads carry believable numbers
 * instead of the handful the eleven scripted shoppers could produce. Every
 * displayed counter in the demo dataset equals real rows; nothing is inflated.
 */
export const COMMUNITY_FIRST_NAMES = [
  'ياسمين', 'رهام', 'ملك', 'جودي', 'سيلين', 'ريتا', 'كنانة', 'وعد',
  'أروى', 'بتول', 'حلا', 'سارة', 'غنى', 'فرح', 'لارا', 'ميس',
  'نغم', 'هلا', 'ولاء', 'يارا',
];

export const COMMUNITY_FAMILY_NAMES = [
  'الأحمد', 'الخطيب', 'العمر', 'السيد', 'الحلبي', 'الشامي',
  'الحموي', 'الديري', 'العلي', 'الحسن',
];

export interface CustomerSeed {
  name: string;
  username: string;
  phone: string;
  bio: string;
  city: string;
  governorate: string;
  district: string;
  address: string;
  tier: 'Bronze' | 'Silver' | 'Gold' | 'Platinum';
}

export const CUSTOMERS: CustomerSeed[] = [
  {
    name: 'نور الدين',
    username: 'nour_shopper',
    phone: '+963932000201',
    bio: 'أحب الفساتين الكلاسيكية والعطور الشرقية',
    city: 'دمشق',
    governorate: 'دمشق',
    district: 'المالكي',
    address: 'شارع الجلاء، بناء ١٢، طابق ٣',
    tier: 'Gold',
  },
  {
    name: 'رنا خليل',
    username: 'rana_k',
    phone: '+963932000202',
    bio: 'مهتمة بالعناية بالبشرة والمنتجات الطبيعية',
    city: 'حلب',
    governorate: 'حلب',
    district: 'الفرقان',
    address: 'شارع النيل، مقابل الحديقة',
    tier: 'Silver',
  },
  {
    name: 'ليلى مراد',
    username: 'layla_m',
    phone: '+963932000203',
    bio: 'عروس ٢٠٢٦ — أجمع كل شي للعرس 💍',
    city: 'اللاذقية',
    governorate: 'اللاذقية',
    district: 'الصليبة',
    address: 'شارع بغداد، بناء الياسمين',
    tier: 'Platinum',
  },
  {
    name: 'هدى العلي',
    username: 'huda_ali',
    phone: '+963932000204',
    bio: 'أم لطفلين، أبحث دائماً عن العروض',
    city: 'حمص',
    governorate: 'حمص',
    district: 'الإنشاءات',
    address: 'شارع الحضارة، بناء ٧',
    tier: 'Silver',
  },
  {
    name: 'مريم قاسم',
    username: 'mariam_q',
    phone: '+963932000205',
    bio: 'طالبة جامعية، أحب القرطاسية والهدايا',
    city: 'دمشق',
    governorate: 'ريف دمشق',
    district: 'جرمانا',
    address: 'ساحة الرئيس، بناء ٢٢',
    tier: 'Bronze',
  },
  {
    name: 'سُها ناصر',
    username: 'suha_n',
    phone: '+963932000206',
    bio: 'مصمّمة ديكور، أتابع كل جديد',
    city: 'طرطوس',
    governorate: 'طرطوس',
    district: 'الكورنيش',
    address: 'شارع الثورة، بناء البحر',
    tier: 'Gold',
  },
  {
    name: 'دعاء الصالح',
    username: 'doaa_s',
    phone: '+963932000207',
    bio: 'أحب الهدايا المغلّفة بعناية 🎁',
    city: 'حماة',
    governorate: 'حماة',
    district: 'الحاضر',
    address: 'شارع العلمين، بناء ٥',
    tier: 'Bronze',
  },
  {
    name: 'رغد يوسف',
    username: 'raghad_y',
    phone: '+963932000208',
    bio: 'مهتمة بالموضة المحتشمة',
    city: 'دير الزور',
    governorate: 'دير الزور',
    district: 'الجورة',
    address: 'شارع تكايا، بناء ٩',
    tier: 'Silver',
  },
  {
    name: 'لين حدّاد',
    username: 'leen_h',
    phone: '+963932000209',
    bio: 'أحب الشوكولا أكثر من اللازم 🍫',
    city: 'السويداء',
    governorate: 'السويداء',
    district: 'المزرعة',
    address: 'الشارع العام، بناء ٣',
    tier: 'Bronze',
  },
  {
    name: 'تالا الأحمد',
    username: 'tala_a',
    phone: '+963932000210',
    bio: 'أجمع الإكسسوارات المميزة',
    city: 'دمشق',
    governorate: 'دمشق',
    district: 'الشعلان',
    address: 'شارع ٢٩ أيار، بناء ١٤',
    tier: 'Gold',
  },
  {
    name: 'شهد الخوري',
    username: 'shahd_k',
    phone: '+963932000211',
    bio: 'أطلب دائماً هدايا لأصدقائي',
    city: 'حلب',
    governorate: 'حلب',
    district: 'السليمانية',
    address: 'شارع الخندق، بناء ١٨',
    tier: 'Silver',
  },
];

// ─────────────────────────── Catalog ───────────────────────────

export type VariantKind =
  | 'clothing'
  | 'shoes'
  | 'baby-shoes'
  | 'shade'
  | 'volume'
  | 'colour'
  | 'none';

export interface LeafSpec {
  /** Image search keywords — see `media.ts`. */
  topic: string;
  /** ASCII stem used to build unique product slugs. */
  stem: string;
  /** Arabic noun phrases; combined with a qualifier to title a product. */
  bases: string[];
  qualifiers: string[];
  /** Price band, in **new** Syrian pounds, for the cheapest live offer. */
  price: [number, number];
  variants: VariantKind;
  /** Extra `attributes` JSON written onto the canonical product. */
  attributes?: Record<string, string[]>;
  /** Sentence appended to every description in this leaf. */
  note: string;
}

export const LEAVES: Record<string, LeafSpec> = {
  dresses: {
    topic: 'dress,elegant',
    stem: 'dress',
    bases: ['فستان سهرة', 'فستان ميدي', 'فستان ماكسي', 'فستان كوكتيل', 'فستان زفاف', 'فستان يومي', 'فستان مطرّز', 'فستان كلوش'],
    qualifiers: ['حريري', 'بنقشة الورد', 'بأكمام منفوخة', 'مطرّز باليد', 'بقصّة الحورية', 'بلون الشامبانيا', 'بحزام مخصّر', 'من الشيفون'],
    price: [6_000, 25_000],
    variants: 'clothing',
    attributes: {
      material: ['حرير طبيعي', 'شيفون', 'ساتان', 'كريب'],
      sleeve_length: ['كم طويل', 'كم قصير', 'بدون أكمام', 'كم ثلاثة أرباع'],
    },
    note: 'القياسات حسب جدول المقاسات، والغسيل الجاف مفضّل.',
  },
  abayas: {
    topic: 'abaya,modest fashion',
    stem: 'abaya',
    bases: ['عباية يومية', 'عباية سهرة', 'عباية كلوش', 'جلابية مطرّزة', 'عباية بحزام', 'طقم محتشم', 'عباية كيمونو'],
    qualifiers: ['بقماش الكريب الكوري', 'بتطريز ذهبي', 'بلون الفحمي', 'بأكمام واسعة', 'بخامة صيفية', 'بتفاصيل دانتيل', 'بلون الرملي'],
    price: [7_000, 22_000],
    variants: 'clothing',
    attributes: { material: ['كريب كوري', 'نيدا', 'لينن'] },
    note: 'خامة لا تشف ولا تحتاج كي.',
  },
  knitwear: {
    topic: 'knitwear,sweater',
    stem: 'knit',
    bases: ['كنزة تريكو', 'كارديجان', 'بلوفر', 'طقم تريكو', 'جاكيت صوف', 'كنزة ياقة عالية'],
    qualifiers: ['من الكشمير', 'بلون اللافندر', 'بغرزة الضفيرة', 'فضفاض', 'بخامة الميرينو', 'بلون الكريمي'],
    price: [5_000, 18_000],
    variants: 'clothing',
    attributes: { material: ['كشمير', 'صوف ميرينو', 'أكريليك ناعم'] },
    note: 'يُغسل باليد بماء بارد للحفاظ على النعومة.',
  },
  skirts: {
    topic: 'skirt,fashion',
    stem: 'skirt',
    bases: ['تنورة ماكسي', 'تنورة ميدي', 'تنورة بليسيه', 'تنورة جينز', 'تنورة كلوش'],
    qualifiers: ['بنقشة زهور', 'بلون الزيتي', 'مطبّعة', 'بخصر مطاطي', 'بطبقتين'],
    price: [3_500, 9_000],
    variants: 'clothing',
    attributes: { material: ['قطن', 'بوليستر ناعم', 'جينز'] },
    note: 'مبطّنة بالكامل.',
  },
  activewear: {
    topic: 'activewear,sportswear',
    stem: 'active',
    bases: ['طقم رياضي', 'ليقنز رياضي', 'بيجاما قطنية', 'طقم منزلي', 'تيشيرت رياضي'],
    qualifiers: ['بخامة تتنفس', 'بلون الوردي الفاتح', 'بقصّة مريحة', 'مقاوم للتمدد', 'بخامة قطنية ١٠٠٪'],
    price: [3_000, 8_000],
    variants: 'clothing',
    attributes: { material: ['قطن مطاطي', 'بوليستر رياضي'] },
    note: 'مناسب للرياضة وللبيت.',
  },
  handbags: {
    topic: 'handbag,purse',
    stem: 'bag',
    bases: ['حقيبة يد', 'حقيبة كتف', 'حقيبة سهرة', 'حقيبة ظهر', 'حقيبة صغيرة', 'حقيبة تسوق'],
    qualifiers: ['من الجلد الطبيعي', 'بسلسلة ذهبية', 'مطرّزة باللؤلؤ', 'بلون الكاراميل', 'بتصميم كلاسيكي', 'بجيوب متعددة'],
    price: [4_500, 18_000],
    variants: 'colour',
    attributes: { material: ['جلد طبيعي', 'جلد صناعي فاخر', 'قماش مبطّن'] },
    note: 'تأتي بكيس حماية قماشي.',
  },
  shoes: {
    topic: 'womens shoes,heels',
    stem: 'shoe',
    bases: ['حذاء كعب عالٍ', 'حذاء سهرة', 'بوت شتوي', 'حذاء رياضي', 'صندل صيفي', 'باليرينا'],
    qualifiers: ['من الساتان', 'بكعب مريح', 'بلون الأسود اللامع', 'بنعل طبي', 'بتفاصيل معدنية', 'بلون البيج'],
    price: [6_000, 19_000],
    variants: 'shoes',
    attributes: { material: ['جلد طبيعي', 'ساتان', 'شامواه'] },
    note: 'القياس مطابق للجدول الأوروبي.',
  },
  jewellery: {
    topic: 'jewellery,necklace',
    stem: 'jewel',
    bases: ['عقد', 'أسوارة', 'طقم مجوهرات', 'خاتم', 'حلق', 'سلسال'],
    qualifiers: ['مطلي بالذهب الوردي', 'بحجر الزركون', 'بتصميم متعدد الطبقات', 'من الفضة ٩٢٥', 'بحرف مخصّص', 'باللؤلؤ الطبيعي'],
    price: [2_000, 12_000],
    variants: 'none',
    attributes: { material: ['فضة ٩٢٥', 'ستانلس ستيل مطلي', 'نحاس مطلي'] },
    note: 'لا يسبّب حساسية ولا يتغيّر لونه بسرعة.',
  },
  scarves: {
    topic: 'scarf,silk',
    stem: 'scarf',
    bases: ['وشاح حريري', 'شال شتوي', 'إيشارب', 'وشاح مطبوع'],
    qualifiers: ['بنقشة هندسية', 'بلون الوردي الترابي', 'من الحرير الطبيعي', 'بحواف مطرّزة'],
    price: [1_200, 4_500],
    variants: 'colour',
    attributes: { material: ['حرير', 'قطن', 'صوف خفيف'] },
    note: 'مناسب لكل الفصول.',
  },
  'face-makeup': {
    topic: 'makeup,cosmetics',
    stem: 'face',
    bases: ['كريم أساس', 'باودر', 'بلاشر', 'كونسيلر', 'هايلايتر', 'برايمر'],
    qualifiers: ['بتغطية كاملة', 'بلمسة ساتان', 'مقاوم للماء', 'للبشرة الدهنية', 'بمفعول مطفي', 'بإشراقة طبيعية'],
    price: [1_500, 7_000],
    variants: 'shade',
    attributes: { skin_type: ['دهنية', 'جافة', 'مختلطة', 'كل أنواع البشرة'] },
    note: 'خالٍ من البارابين ومناسب للبشرة الحساسة.',
  },
  lips: {
    topic: 'lipstick,beauty',
    stem: 'lip',
    bases: ['أحمر شفاه', 'ملمّع شفاه', 'مثبّت شفاه', 'قلم تحديد شفاه', 'بلسم شفاه'],
    qualifiers: ['بمفعول مطفي', 'بلمسة لامعة', 'ثابت ١٢ ساعة', 'مرطّب بزبدة الشيا', 'بدرجة الورد القديم'],
    price: [900, 3_500],
    variants: 'shade',
    note: 'لا يجفّف الشفاه ولا يترك أثراً على الكوب.',
  },
  moisturisers: {
    topic: 'skincare,cream',
    stem: 'moist',
    bases: ['كريم مرطّب', 'سيروم', 'كريم ليلي', 'مرطّب بعامل حماية', 'كريم عيون'],
    qualifiers: ['بحمض الهيالورونيك', 'بفيتامين سي', 'بالنياسيناميد', 'بخلاصة الورد الدمشقي', 'للبشرة الحساسة'],
    price: [1_800, 6_500],
    variants: 'volume',
    attributes: { skin_type: ['حساسة', 'جافة', 'مختلطة'] },
    note: 'مُختبر تحت إشراف طبي.',
  },
  cleansers: {
    topic: 'face wash,skincare',
    stem: 'clean',
    bases: ['غسول وجه', 'مقشّر لطيف', 'ماء ميسيلار', 'تونر', 'صابونة طبيعية'],
    qualifiers: ['برغوة خفيفة', 'بخلاصة الشاي الأخضر', 'بدون كحول', 'للبشرة المعرّضة للحبوب', 'بزيت الأرغان'],
    price: [1_200, 4_200],
    variants: 'volume',
    note: 'يناسب الاستخدام اليومي صباحاً ومساءً.',
  },
  perfumes: {
    topic: 'perfume,fragrance bottle',
    stem: 'parfum',
    bases: ['عطر نسائي', 'ماء عطر', 'عطر زيتي', 'مسك أبيض', 'عطر شرقي'],
    qualifiers: ['بروائح الفانيلا والعنبر', 'بثبات ١٢ ساعة', 'بنفحات الياسمين الدمشقي', 'بعبير الورد والعود', 'صيفي منعش'],
    price: [4_000, 22_000],
    variants: 'volume',
    note: 'التركيز عالٍ، ترذاذ واحد يكفي.',
  },
  bouquets: {
    topic: 'flower bouquet,roses',
    stem: 'bouquet',
    bases: ['باقة ورد جوري', 'بوكيه مناسبات', 'صندوق ورد', 'باقة ورد مجفّف', 'ترتيبة زهور'],
    qualifiers: ['بلون الوردي والأبيض', 'مع بطاقة إهداء', 'بتنسيق فاخر', 'مع شوكولا', 'بورد طبيعي طازج'],
    price: [1_500, 6_000],
    variants: 'none',
    note: 'التوصيل خلال ٢٤ ساعة داخل المحافظة.',
  },
  'wall-art': {
    topic: 'wall art,frame',
    stem: 'art',
    bases: ['لوحة جدارية', 'طقم لوحات', 'لوحة خط عربي', 'إطار مزخرف'],
    qualifiers: ['بألوان ترابية', 'بإطار خشبي', 'بطباعة عالية الدقة', 'بتصميم مودرن'],
    price: [2_000, 8_000],
    variants: 'none',
    note: 'يأتي جاهزاً للتعليق.',
  },
  chocolate: {
    topic: 'chocolate,dessert',
    stem: 'choco',
    bases: ['علبة شوكولا', 'شوكولا بالحشوة', 'ترافل', 'شوكولا داكنة', 'ميدالية شوكولا'],
    qualifiers: ['بالبندق', 'بالفستق الحلبي', 'بنسبة كاكاو ٧٠٪', 'محضّرة يدوياً', 'بتغليف هدية'],
    price: [900, 4_500],
    variants: 'none',
    note: 'يُحفظ في مكان بارد وجاف.',
  },
  'candy-boxes': {
    topic: 'candy box,gift sweets',
    stem: 'candy',
    bases: ['علبة ضيافة', 'صينية حلويات', 'علبة ملبّس', 'طقم ضيافة مناسبات'],
    qualifiers: ['بتغليف مخملي', 'للأعراس', 'للمواليد', 'بتنسيق ذهبي'],
    price: [1_500, 6_000],
    variants: 'none',
    note: 'يمكن إضافة اسم المناسبة على العلبة.',
  },
  'graduation-gifts': {
    topic: 'graduation gift',
    stem: 'grad',
    bases: ['صندوق تخرّج', 'هدية تخرّج', 'باقة تخرّج', 'طقم تهنئة'],
    qualifiers: ['مع قبعة تخرّج', 'بتغليف أكاديمي', 'مع بطاقة مخصّصة', 'مع ورد وشوكولا'],
    price: [2_000, 9_000],
    variants: 'none',
    note: 'يمكن طباعة الاسم والتاريخ.',
  },
  'newborn-gifts': {
    topic: 'newborn gift,baby',
    stem: 'newborn',
    bases: ['صندوق مولود', 'هدية استقبال', 'سلة مواليد', 'طقم تهنئة بالمولود'],
    qualifiers: ['بلون سماوي', 'بلون وردي', 'مع بطانية قطنية', 'مع بطاقة اسم المولود'],
    price: [2_500, 9_000],
    variants: 'none',
    note: 'كل القطع قطنية ومناسبة لبشرة المولود.',
  },
  'ramadan-gifts': {
    topic: 'ramadan gift,lantern',
    stem: 'ramadan',
    bases: ['صندوق رمضان', 'فانوس مزيّن', 'طقم ضيافة رمضاني', 'هدية عيد'],
    qualifiers: ['بتصميم شرقي', 'مع تمر وشوكولا', 'بإضاءة خافتة', 'بتغليف ذهبي'],
    price: [1_800, 8_000],
    variants: 'none',
    note: 'متوفّر بكميات محدودة قبل المناسبة.',
  },
  notebooks: {
    topic: 'notebook,stationery',
    stem: 'note',
    bases: ['دفتر مخطط', 'مفكرة يومية', 'أجندة سنوية', 'دفتر رسم'],
    qualifiers: ['بغلاف صلب', 'بورق ١٢٠ غرام', 'بتصميم زهري', 'بحلقات معدنية'],
    price: [400, 1_600],
    variants: 'none',
    note: 'الورق سميك لا يسمح بتسريب الحبر.',
  },
  'desk-accessories': {
    topic: 'desk accessories,stationery',
    stem: 'desk',
    bases: ['طقم أقلام', 'منظّم مكتب', 'حامل أقلام', 'طقم قرطاسية'],
    qualifiers: ['بلون الوردي', 'من الأكريليك', 'بتصميم بسيط', 'مع ملصقات'],
    price: [600, 3_000],
    variants: 'none',
    note: 'هدية عملية للطالبات والموظفات.',
  },
  'baby-sets': {
    topic: 'baby clothes,newborn',
    stem: 'babyset',
    bases: ['طقم مولود', 'بيجاما أطفال', 'طقم ٣ قطع', 'أفرول قطني'],
    qualifiers: ['قطن ١٠٠٪', 'بلون محايد', 'بأزرار سهلة', 'بتطريز لطيف'],
    price: [1_500, 5_000],
    variants: 'clothing',
    attributes: { material: ['قطن عضوي', 'قطن ممشّط'] },
    note: 'خامة لا تهيّج بشرة الطفل.',
  },
  'baby-shoes': {
    topic: 'baby shoes',
    stem: 'babyshoe',
    bases: ['حذاء مولود', 'حذاء أطفال', 'جزمة صغيرة'],
    qualifiers: ['بنعل طري', 'بلون الأبيض', 'بشريط لاصق', 'مبطّن بالفرو'],
    price: [1_200, 3_800],
    variants: 'baby-shoes',
    note: 'خفيف ولا يعيق حركة القدم.',
  },
  'baby-skincare': {
    topic: 'baby lotion,baby care',
    stem: 'babycare',
    bases: ['كريم أطفال', 'زيت تدليك', 'غسول لطيف', 'كريم تسلّخات'],
    qualifiers: ['بدون عطور', 'بخلاصة البابونج', 'مناسب من اليوم الأول', 'مختبر من أطباء الجلدية'],
    price: [900, 3_200],
    variants: 'volume',
    note: 'مناسب للاستخدام اليومي.',
  },
  'baby-essentials': {
    topic: 'baby essentials,nursery',
    stem: 'babyess',
    bases: ['حقيبة أمومة', 'بطانية قطنية', 'طقم مناديل قماشية', 'مريلة طعام'],
    qualifiers: ['بجيوب معزولة', 'بلون هادئ', 'قابلة للغسل', 'مقاومة للماء'],
    price: [700, 3_000],
    variants: 'none',
    note: 'قابل للغسل في الغسالة.',
  },
};

export const BRANDS = [
  { slug: 'sham-couture', nameAr: 'شام كوتور', nameEn: 'Sham Couture', isVerified: true },
  { slug: 'rose-damascus', nameAr: 'وردة دمشق', nameEn: 'Rose of Damascus', isVerified: true },
  { slug: 'aleppo-knit', nameAr: 'حياكة حلب', nameEn: 'Aleppo Knit', isVerified: false },
  { slug: 'lattakia-leather', nameAr: 'جلود اللاذقية', nameEn: 'Lattakia Leather', isVerified: true },
  { slug: 'nour-beauty', nameAr: 'نور بيوتي', nameEn: 'Nour Beauty', isVerified: true },
  { slug: 'jasmin-parfum', nameAr: 'ياسمين باروفان', nameEn: 'Jasmin Parfum', isVerified: false },
  { slug: 'petit-baby', nameAr: 'بوتي بيبي', nameEn: 'Petit Baby', isVerified: false },
];

export const COLOURS = [
  'وردي فاتح',
  'أسود',
  'بيج',
  'كحلي',
  'زيتي',
  'كاراميل',
  'أبيض كريمي',
  'عنابي',
];

export const SHADES = [
  'درجة ٠١ فاتح',
  'درجة ٠٢ طبيعي',
  'درجة ٠٣ متوسط',
  'درجة ٠٤ عسلي',
  'درجة ٠٥ غامق',
];

export const VOLUMES = ['٣٠ مل', '٥٠ مل', '١٠٠ مل'];
export const CLOTHING_SIZES = ['S', 'M', 'L', 'XL'];
export const SHOE_SIZES = ['36', '37', '38', '39', '40', '41'];
export const BABY_SHOE_SIZES = ['17', '18', '19', '20', '21'];

// ─────────────────────────── Copy ───────────────────────────

export const REVIEW_TITLES = [
  'تجربة ممتازة',
  'يستحق كل ليرة',
  'وصل أسرع مما توقعت',
  'جودة أعلى من الصور',
  'راضية جداً',
  'جيد لكن…',
  'سأطلب مرة ثانية',
];

export const REVIEW_BODIES_POSITIVE = [
  'المنتج مطابق تماماً للوصف والتغليف كان أنيق جداً. البائعة ردّت على أسئلتي بسرعة.',
  'الجودة ممتازة والسعر مناسب مقارنة بالسوق. أنصح فيه بشدة 💕',
  'وصل خلال يومين وبحالة ممتازة. أكيد رح أطلب مرة ثانية.',
  'اللون بالحقيقة أحلى من الصورة، والقياس مضبوط حسب الجدول.',
  'خدمة رائعة من البائعة، وغلّفته لي كهدية بدون أي تكلفة إضافية.',
  'استخدمته لأسبوع والنتيجة واضحة. سعيدة بالطلب.',
];

export const REVIEW_BODIES_MIXED = [
  'المنتج جيد بشكل عام، بس التوصيل تأخر يومين عن الموعد.',
  'الجودة منيحة للسعر، لكن التغليف كان بسيط.',
  'القياس أصغر شوي من المتوقع، خذي قياس أكبر.',
  'المنتج حلو بس اللون أفتح شوي من الصورة.',
];

export const POST_CAPTIONS = [
  'وصلنا اليوم 😍 كمية محدودة وبأسعار الافتتاح',
  'ثلاث طرق لتنسيق هالقطعة لإطلالة نهارية ☀️',
  'الأكثر طلباً هالأسبوع 💕 شكراً لثقتكن',
  'تفاصيل الخامة عن قرب — الجودة يلي بتحكي عن حالها ✨',
  'جهّزنا لكن تشكيلة المناسبات كاملة 🎁',
  'سؤال متكرر: نعم، التوصيل لكل المحافظات 🚚',
  'قبل وبعد التنسيق — شو رأيكن؟',
  'خصم خاص لمتابعاتنا لمدة ٤٨ ساعة فقط ⏰',
  'قصة نجاح: هالقطعة نفدت مرتين ورجعت بالطلب 🙌',
  'من كواليس التصوير — كل قطعة بتنتقى بعناية',
];

export const CONTENT_ONLY_CAPTIONS = [
  'دليل سريع: كيف تختارين العطر المناسب لبشرتك؟ 🌸',
  'نصائح للعناية بالتريكو حتى يبقى كالجديد 🧶',
  'ألوان موسم هذا العام — وكيف تنسّقينها',
  'أسئلتكن عن الاستبدال والإرجاع، جاوبناها كلها هنا',
];

export const COMMENTS = [
  'شو أحلاه 😍 كم السعر؟',
  'متوفر قياس M؟',
  'طلبته من عندكن وكان أحلى بالحقيقة 💕',
  'بتوصلوا لحلب؟',
  'أول مرة أشوف هالتصميم، رائع!',
  'كم يوم بياخد التوصيل؟',
  'الله يوفقكن، خدمة ممتازة 🙏',
  'في نفس القطعة بلون تاني؟',
  'حجزت واحدة 🙋‍♀️',
  'الجودة تستاهل السعر فعلاً',
];

export const CHAT_THREADS: { buyer: string[]; seller: string[] }[] = [
  {
    buyer: ['مرحباً، هالقطعة متوفرة بقياس M؟', 'ممتاز، وكم بتكلف الشحن لدمشق؟'],
    seller: ['أهلاً فيكِ 🌸 نعم متوفرة', 'الشحن ١٥ ألف ومجاني فوق ٣٠٠ ألف'],
  },
  {
    buyer: ['طلبي رقم كم صار؟ 😊', 'تمام شكراً إلكن'],
    seller: ['طلبك خرج مع المندوب اليوم', 'بيوصلك بكرا إن شاء الله 🚚'],
  },
  {
    buyer: ['بدي أبدّل القياس، ممكن؟'],
    seller: ['أكيد، الاستبدال متاح خلال ٧ أيام 💕'],
  },
];

export const COUPONS = [
  { code: 'WELCOME10', title: 'خصم ١٠٪ لأول طلب', percent: 10, days: 60 },
  { code: 'EID25', title: 'خصم ٢٥٪ بمناسبة العيد', percent: 25, days: 20 },
  { code: 'FREESHIP', title: 'شحن مجاني على طلبك', percent: 0, amountOff: 150, days: 45 },
  { code: 'BEAUTY15', title: 'خصم ١٥٪ على العناية والمكياج', percent: 15, days: 30 },
  { code: 'VIP30', title: 'خصم ٣٠٪ لعضوات البلاتينيوم', percent: 30, days: 90 },
];

export const NOTIFICATIONS: {
  title: string;
  body: string;
  type: 'order' | 'promo' | 'follow' | 'like' | 'comment' | 'coupon' | 'system' | 'payment';
}[] = [
  { title: 'تم شحن طلبك', body: 'طلبك في الطريق إليك وسيصل خلال يومين 🚚', type: 'order' },
  { title: 'عرض اليوم', body: 'خصم يصل إلى ٣٠٪ على تشكيلة المناسبات ⏰', type: 'promo' },
  { title: 'كوبون جديد', body: 'استخدمي WELCOME10 واحصلي على خصم ١٠٪', type: 'coupon' },
  { title: 'متابعة جديدة', body: 'بدأت إحدى المتسوقات بمتابعة متجرك', type: 'follow' },
  { title: 'إعجاب بمنشورك', body: 'حصل منشورك على تفاعل كبير اليوم 💕', type: 'like' },
  { title: 'تعليق جديد', body: 'وصلك تعليق جديد على أحد منشوراتك', type: 'comment' },
  { title: 'تم تأكيد الدفع', body: 'استلمنا دفعتك بنجاح، شكراً لك', type: 'payment' },
  { title: 'تحديث سياسة الإرجاع', body: 'أصبح بإمكانك طلب الإرجاع خلال ٧ أيام', type: 'system' },
];

export const SUPPORT_TICKETS = [
  { subject: 'لم يصل طلبي في الموعد', category: 'orders', priority: 'HIGH' as const },
  { subject: 'استفسار عن سياسة الاستبدال', category: 'returns', priority: 'NORMAL' as const },
  { subject: 'مشكلة في إتمام الدفع', category: 'payments', priority: 'URGENT' as const },
  { subject: 'طلب تعديل عنوان التوصيل', category: 'orders', priority: 'NORMAL' as const },
  { subject: 'كيف أصبح بائعة على المنصة؟', category: 'sellers', priority: 'LOW' as const },
];

export const SEARCH_QUERIES = [
  'فستان سهرة',
  'عباية كريب',
  'عطر ياسمين',
  'حقيبة جلد',
  'كريم مرطب',
  'باقة ورد',
  'هدية تخرج',
  'طقم مولود',
  'أحمر شفاه مطفي',
  'تريكو كشمير',
  'شوكولا فستق',
  'دفتر مخطط',
];
