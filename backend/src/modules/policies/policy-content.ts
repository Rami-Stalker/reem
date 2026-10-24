import { PolicyAudience, PolicyDocumentKind } from '@prisma/client';

/**
 * The eight documents, as the platform first publishes them.
 *
 * **This file is a starting point, not a source of truth.** The moment
 * `PolicyBootstrap` writes these rows the database owns them: an administrator
 * edits a policy in the console, publishes a version 2, and nothing here is
 * consulted again for that document. Which is the entire point of the
 * subsystem — the client asked to be able to change the terms without shipping
 * an app, and a policy that lives in a constant is a policy that needs a
 * release and a review queue to fix a typo in.
 *
 * What is written here is therefore the *first* issue of each: drafted from
 * how this platform actually behaves — seven days from delivery, ten per cent
 * on the post-discount item total, earnings held until the return window
 * closes, a removal that always carries a reason — rather than from a
 * boilerplate template that would describe some other marketplace. Every
 * number in the Arabic text below is a number the code enforces, and the two
 * have to be changed together.
 *
 * The Arabic is authoritative and the English is a courtesy translation; the
 * documents say so themselves, because a marketplace whose customers and
 * sellers are Syrian is not entering an English contract with them.
 */

export interface PolicySeedTranslation {
  readonly locale: string;
  readonly title: string;
  readonly summary: string;
  readonly body: string;
}

export interface PolicySeedDocument {
  readonly kind: PolicyDocumentKind;
  readonly slug: string;
  readonly audience: PolicyAudience;
  readonly sortOrder: number;
  readonly requiredForConsent: boolean;
  readonly icon: string;
  readonly translations: readonly PolicySeedTranslation[];
}

/**
 * The one line every document ends with, so that a reader who only skims
 * still learns the two things that matter procedurally: the Arabic governs,
 * and this text can change under her.
 */
const AR_FOOTER = `## تعديل هذه الوثيقة

قد نُحدّث هذه الوثيقة من وقت إلى آخر. كل تحديث يصدر كنسخة جديدة تحمل رقمها وتاريخ سريانها، والنسخة التي وافقتِ عليها تبقى محفوظة في حسابك مع تاريخ موافقتك عليها.

إذا كان التغيير جوهريًا — أي يمسّ حقوقك أو التزاماتك — فسنطلب موافقتك عليه صراحةً قبل متابعة استخدام التطبيق. أما التصحيحات اللغوية والتوضيحات فتُنشر مع إشعار داخل التطبيق دون أن نقطع عليك ما تفعلينه.

النص العربي هو النص المُلزِم. الترجمة الإنجليزية مُقدَّمة للتيسير فقط، وعند أي اختلاف يُعتمد العربي.`;

const EN_FOOTER = `## Changes to this document

We may update this document from time to time. Each update is issued as a new version with its own number and effective date, and the version you accepted stays recorded on your account together with the date you accepted it.

When a change is material — when it touches your rights or your obligations — we ask you to accept it explicitly before you carry on using the app. Wording fixes and clarifications are published with an in-app notice instead, without interrupting what you are doing.

The Arabic text is the binding one. This English translation is provided for convenience; where the two differ, the Arabic governs.`;

// ── 1. Customer terms ─────────────────────────────────────────────────────

const CUSTOMER_TERMS_AR = `## من نحن

«أوهارا» منصة تسوّق اجتماعية نسائية تجمع بائعات ومشتريات في مكان واحد. المنصة وسيط تقني: نحن نوفّر مكان العرض والطلب والدفع والمتابعة، أما عقد البيع نفسه فهو بينك وبين البائعة.

## من يحق له استخدام المنصة

- أوهارا منصة نسائية. عند إنشاء الحساب تُقرّين بأنك أنثى، وهذا الإقرار شرط لإتمام التسجيل.
- يجب أن تكوني قد أتممتِ 18 عامًا، أو أن تستخدمي المنصة بإشراف وليّ أمرك.
- الحساب شخصي. لا تُشاركي رمز الدخول الذي يصلك، ولا تسمحي لغيرك باستخدام حسابك.

## التسجيل والدخول

يتم الدخول برقم هاتفك عبر رمز تحقّق يصلك على واتساب. أنتِ مسؤولة عن أن يبقى الرقم تحت سيطرتك، وعن إبلاغنا فورًا إذا فقدتِ الشريحة أو الجهاز. تجدين في «الأمان» قائمة بالأجهزة التي دخلت إلى حسابك، ويمكنك إنهاء أي جلسة منها.

## البيانات التي تُدخلينها

عنوان التوصيل ورقم الهاتف واسم المستلمة تصل إلى البائعة وإلى شركة التوصيل لتنفيذ طلبك. أنتِ مسؤولة عن دقتها: عنوان ناقص يعني طردًا لا يصل، وتكاليف إعادته قد تُحتسب عليك.

## الطلب والدفع

- الأسعار معروضة بالليرة السورية الجديدة وتشمل ما هو مذكور في صفحة المنتج فقط. أجور التوصيل تُحتسب وتُعرض قبل تأكيد الطلب.
- طرق الدفع المتاحة هي الدفع عند الاستلام، والدفع من محفظتك داخل التطبيق. ما يتوفر منها يظهر لك عند إتمام الشراء.
- تأكيد الطلب لا يعني قبوله نهائيًا. يبقى للبائعة أن ترفضه إذا نفد المخزون أو تعذّر التنفيذ، ويُبلَّغ إليك ذلك مع سبب.
- إذا نفد المنتج بعد الطلب، يُلغى السطر المتعلق به ويُردّ ما دفعتِه عنه إلى محفظتك خلال مدة لا تتجاوز ثلاثة أيام عمل.

## الإلغاء والرفض عند الباب

- يمكنك إلغاء الطلب مجانًا ما دام لم يُسلَّم إلى شركة التوصيل.
- بعد خروج الطرد للتوصيل، يبقى الإلغاء ممكنًا لكن قد تُحتسب عليك أجور الشحن الفعلية.
- رفض استلام الطرد المدفوع عند الاستلام دون سبب، وتكراره، يؤثر على حسابك: قد نطلب منك تأكيدًا إضافيًا للطلب، أو دفعة مقدّمة، قبل قبول طلبات لاحقة بالدفع عند الاستلام. القرار قابل للمراجعة عبر الدعم.

## التقييمات والمحتوى

ما تنشرينه على المنصة — تقييم، تعليق، صورة، منشور — يخضع لـ«سياسة المحتوى والحذف». أنتِ مالكة ما تنشرينه، وتمنحيننا ترخيصًا بعرضه داخل المنصة وفي الترويج لها.

## الاستخدام المقبول

يُمنع، على سبيل المثال لا الحصر:

- انتحال شخصية غيرك أو إنشاء حسابات متعددة للتحايل على قيود المنصة.
- إساءة استخدام العروض والنقاط والكوبونات، أو الطلب بنيّة الرفض.
- التحرش بأي بائعة أو مستخدمة، أو جمع بيانات الآخرين.
- محاولة إتمام البيع خارج المنصة بعد التعرّف على البائعة من خلالها.

## إيقاف الحساب

قد نوقف الحساب مؤقتًا أو نُنهيه عند مخالفة جوهرية أو متكرّرة لهذه الشروط. نُبلغك بالسبب، ويحق لك الاعتراض عبر الدعم. إيقاف الحساب لا يُسقط حقوقك المالية المستحقة ولا التزاماتك القائمة.

## حذف حسابك

يمكنك طلب حذف حسابك في أي وقت. تُحذف بياناتك الشخصية وفق «سياسة الخصوصية»، مع الاحتفاظ بسجلات الطلبات والفواتير للمدة التي يفرضها القانون والمحاسبة.

## القانون الواجب التطبيق

تخضع هذه الشروط للقوانين النافذة في الجمهورية العربية السورية، ويُسعى إلى حلّ أي خلاف وديًّا عبر آلية الشكاوى والنزاعات قبل اللجوء إلى القضاء.

${AR_FOOTER}`;

const CUSTOMER_TERMS_EN = `## Who we are

Ohara is a women's social shopping platform that brings sellers and shoppers together in one place. We are a technical intermediary: we provide the place to browse, order, pay and follow up, while the contract of sale itself is between you and the seller.

## Who may use the platform

- Ohara is a women's platform. When you create an account you declare that you are a woman, and that declaration is a condition of registering.
- You must be 18 or over, or use the platform under the supervision of your guardian.
- An account is personal. Do not share the sign-in code you receive, and do not let anyone else use your account.

## Registering and signing in

You sign in with your phone number using a verification code sent over WhatsApp. You are responsible for keeping that number under your control and for telling us immediately if you lose the SIM or the handset. Security settings list every device that has signed into your account, and you can end any of those sessions.

## The details you enter

Your delivery address, phone number and recipient name reach the seller and the courier so that your order can be fulfilled. You are responsible for their accuracy: an incomplete address means a parcel that never arrives, and the cost of returning it may be charged to you.

## Ordering and payment

- Prices are shown in new Syrian lira and include only what the product page states. Delivery charges are calculated and shown before you confirm.
- The available payment methods are cash on delivery and payment from your in-app wallet. Which of them you see is shown at checkout.
- Confirming an order is not final acceptance of it. A seller may still refuse it if stock has run out or it cannot be fulfilled, and you are told so with a reason.
- If an item sells out after you have ordered, that line is cancelled and whatever you paid for it is returned to your wallet within three working days at most.

## Cancelling, and refusing at the door

- You may cancel free of charge for as long as the parcel has not been handed to the courier.
- Once the parcel is out for delivery, cancelling is still possible but the actual shipping cost may be charged to you.
- Refusing a cash-on-delivery parcel without reason, repeatedly, affects your account: we may ask for an extra confirmation, or a deposit, before accepting further cash-on-delivery orders. That decision can be reviewed through support.

## Reviews and content

What you publish on the platform — a review, a comment, a photograph, a post — is governed by the Content and Removal Policy. You own what you publish, and you grant us a licence to display it inside the platform and in promoting it.

## Acceptable use

The following are prohibited, among others:

- Impersonating someone else, or creating multiple accounts to evade platform limits.
- Abusing offers, points or coupons, or ordering with the intention of refusing.
- Harassing any seller or user, or harvesting other people's data.
- Trying to complete a sale outside the platform after finding the seller through it.

## Suspension

We may suspend or close an account for a serious or repeated breach of these terms. You are told the reason, and you may appeal through support. Suspension does not extinguish money owed to you, nor obligations you have already incurred.

## Deleting your account

You may ask for your account to be deleted at any time. Your personal data is deleted in line with the Privacy Policy, while order records and invoices are retained for as long as law and accounting require.

## Governing law

These terms are governed by the laws in force in the Syrian Arab Republic. Any disagreement is first taken through the complaints and disputes process before any recourse to the courts.

${EN_FOOTER}`;

// ── 2. Seller terms ───────────────────────────────────────────────────────

const SELLER_TERMS_AR = `## طبيعة العلاقة

بفتحك متجرًا على أوهارا تصبحين بائعة مستقلة تستخدم المنصة لعرض بضاعتك وبيعها. أوهارا ليست طرفًا في عقد البيع ولا مالكةً للبضاعة، وإنما توفّر مكان العرض وأدوات الطلب والتحصيل والتوصيل.

## التوثيق قبل البيع

لا يُفعَّل المتجر قبل اكتمال التوثيق: السجل التجاري، هوية صاحبة النشاط، عنوان النشاط والمستودع، وبيانات الحساب البنكي الذي تُحوَّل إليه مستحقاتك. نراجع الطلب ونُبلغك بالقبول أو بالسبب عند الرفض، ويحق لنا طلب مستندات إضافية أو إعادة التحقق لاحقًا.

بياناتك البنكية ووثائقك تُستخدم للتحقق والتسوية فقط، ولا تُعرض على المشتريات.

## بضاعتك ومسؤوليتك عنها

- كل ما تعرضينه يجب أن يكون مملوكًا لك أو مرخّصًا لك ببيعه، ومطابقًا للقوانين النافذة.
- الصور والأوصاف والمقاسات والخامات يجب أن تمثّل المنتج الفعلي. الصورة المستعارة من متجر آخر مخالفة.
- أنتِ مسؤولة عن سلامة المنتج ومطابقته للمواصفات المعلنة، وعن أي ضرر ينشأ عن عيب فيه.
- يُمنع عرض المقلّد، والمنتجات الممنوعة قانونًا، وكل ما يخالف «سياسة المحتوى والحذف».

## المخزون والأسعار

المخزون المعروض يجب أن يكون متاحًا فعلًا. إلغاء الطلبات المتكرّر بسبب نفاد المخزون يخفّض تقييم متجرك وقد يؤدي إلى تقييد الظهور أو إيقاف المتجر. الأسعار تُعرض بالليرة السورية الجديدة، ولا يجوز تغيير سعر طلب بعد تأكيده.

## التجهيز والشحن

- تلتزمين بتجهيز الطلب خلال المدة المعلنة على متجرك، وبتسليمه إلى شركة التوصيل أو شحنه بنفسك بحسب ما اخترتِه.
- تحديث حالة الطلب في التطبيق التزام لا خيار: المشترية تتابع طردها من هناك.
- التأخير المتكرّر دون سبب يُعامل معاملة الإلغاء المتكرّر.

## العمولة والمستحقات

تُحتسب عمولة المنصة وفق «سياسة العمولات». مستحقاتك من كل طلب تبقى محجوزة حتى تسليم الطرد وانقضاء مهلة الإرجاع، ثم تُتاح للتسوية. أي نزاع مفتوح على الطلب يوقف الإفراج عن مستحقاته حتى يُحسم.

## الإرجاع والاستبدال

تلتزمين بـ«سياسة الإرجاع والاستبدال» كحدّ أدنى. يجوز أن تمنحي شروطًا أفضل منها، ولا يجوز أن تشترطي أقل. قرارك في طلب إرجاع يجب أن يصدر خلال المهلة المحددة ومع سبب واضح.

## المحتوى والتواصل

منشوراتك وقصصك ورسائلك مع المشتريات تخضع لـ«سياسة المحتوى والحذف». يُمنع توجيه المشتريات إلى الشراء خارج المنصة، ويُمنع استخدام بيانات المشتريات لأي غرض غير تنفيذ الطلب.

## الإيقاف وإنهاء المتجر

قد نُقيّد ظهور متجرك أو نوقفه عند مخالفة جوهرية أو متكرّرة، أو عند شبهة احتيال. نُبلغك بالسبب ويحق لك الاعتراض. عند الإيقاف تبقى ملزمةً بإتمام الطلبات القائمة، وتُسوّى مستحقاتك بعد انقضاء مهل الإرجاع والنزاعات المفتوحة.

## إغلاق المتجر باختيارك

يمكنك إغلاق متجرك متى شئتِ بعد إتمام الطلبات القائمة وتسوية المستحقات والالتزامات.

${AR_FOOTER}`;

const SELLER_TERMS_EN = `## The nature of the relationship

By opening a shop on Ohara you become an independent seller using the platform to display and sell your goods. Ohara is not a party to the contract of sale and does not own the goods; it provides the place to display them and the tools to order, collect payment and deliver.

## Verification before selling

A shop is not activated until verification is complete: commercial registration, the owner's identity document, the business and warehouse addresses, and the bank account your earnings are transferred to. We review the application and tell you the outcome, with a reason if it is refused. We may ask for further documents or re-verification later.

Your bank details and documents are used for verification and settlement only, and are never shown to shoppers.

## Your goods, and your responsibility for them

- Everything you list must be owned by you or licensed to you to sell, and must comply with the law in force.
- Photographs, descriptions, sizes and materials must represent the actual product. A photograph borrowed from another shop is a breach.
- You are responsible for the safety of the product and for its conformity with what you advertised, and for any harm arising from a defect in it.
- Counterfeit goods, goods prohibited by law, and anything contrary to the Content and Removal Policy may not be listed.

## Stock and prices

Stock shown must actually be available. Repeatedly cancelling orders for lack of stock lowers your shop's rating and may lead to reduced visibility or suspension. Prices are shown in new Syrian lira, and the price of an order may not be changed after it is confirmed.

## Preparation and shipping

- You undertake to prepare an order within the time your shop advertises and to hand it to the courier, or ship it yourself, according to what you have chosen.
- Updating the order's status in the app is an obligation, not an option: the shopper follows her parcel from there.
- Repeated delay without cause is treated the same way as repeated cancellation.

## Commission and earnings

The platform's commission is calculated under the Commissions Policy. Your earnings from each order are held until the parcel is delivered and the return window has passed, and are then available for settlement. An open dispute on an order holds its earnings until it is resolved.

## Returns and exchanges

You are bound by the Returns and Exchanges Policy as a floor. You may offer better terms than it; you may not require less. Your decision on a return request must be given within the stated period and with a clear reason.

## Content and communication

Your posts, stories and messages with shoppers are governed by the Content and Removal Policy. Directing shoppers to buy outside the platform is prohibited, as is using shopper data for any purpose other than fulfilling the order.

## Suspension and closure

We may restrict your shop's visibility or suspend it for a serious or repeated breach, or on suspicion of fraud. You are told the reason and may appeal. While suspended you remain obliged to complete outstanding orders, and your earnings are settled once return windows and open disputes have closed.

## Closing your shop

You may close your shop whenever you wish, once outstanding orders are complete and earnings and obligations are settled.

${EN_FOOTER}`;

// ── 3. Privacy ────────────────────────────────────────────────────────────

const PRIVACY_AR = `## ما الذي نجمعه

- **ما تُعطيننا إياه**: رقم هاتفك، اسمك، مدينتك، عناوين التوصيل، وما تكتبينه في المنشورات والتقييمات والمحادثات. وللبائعات: وثائق التوثيق وبيانات الحساب البنكي.
- **ما ينشأ عن استخدامك**: طلباتك وفواتيرك، مفضّلاتك، عمليات البحث، ما تتصفّحينه، ورصيد محفظتك ونقاطك.
- **ما يخصّ جهازك**: نوع الجهاز، نظامه، إصدار التطبيق، عنوان الإنترنت، ومُعرّف الإشعارات. نُسجّل الدخول والأجهزة لحماية حسابك.
- **الصور التي ترفعينها للبحث البصري**: تُستخدم للبحث ثم تُحذف بعد مدة محدودة؛ ما يبقى هو وصف رقمي لا يمكن استرجاع الصورة منه.

## لماذا نجمعها

لتنفيذ طلباتك، ولتسجيل دخولك والتحقق من هويتك، ولمنع الاحتيال وإساءة الاستخدام، ولترتيب ما يُعرض عليك، ولإرسال إشعارات عن طلباتك، وللوفاء بالتزاماتنا المحاسبية والقانونية.

## مع من نشاركها

- **البائعة**: اسم المستلمة، رقم الهاتف، وعنوان التوصيل — للطلب الذي اشترَيْته منها، ولهذا الغرض وحده.
- **شركة التوصيل**: البيانات اللازمة لإيصال الطرد.
- **مزوّد رسائل واتساب**: رقمك، لإرسال رمز التحقق.
- **مزوّد الإشعارات**: مُعرّف جهازك، لإيصال الإشعار.
- **الجهات الرسمية**: عند طلب قانوني ملزم.

**لا نبيع بياناتك الشخصية، ولا نشاركها لأغراض إعلانية خارج المنصة.**

## ما لا نصل إليه

لا نحتفظ بكلمة مرورك كنص، ولا نصل إلى صور هاتفك إلا ما تختارينه أنتِ للرفع، ولا نقرأ محادثاتك إلا حين تُحيلينها إلينا في نزاع أو بلاغ.

## مدة الاحتفاظ

نحتفظ ببياناتك ما دام حسابك قائمًا. بعد حذف الحساب تُحذف بياناتك الشخصية، وتبقى سجلات الطلبات والفواتير والقيود المالية للمدة التي يفرضها القانون، وتبقى سجلات الأمان لمدة محدودة لمنع إساءة الاستخدام.

## حقوقك

- الاطلاع على بياناتك وتصحيحها من «إعدادات الحساب».
- الاطلاع على السياسات التي وافقتِ عليها وتاريخ كل موافقة.
- إدارة الأجهزة والجلسات وإنهاء أي منها.
- التحكم بالإشعارات من إعداداتها.
- طلب حذف حسابك وبياناتك.

لأي طلب يخصّ بياناتك، افتحي تذكرة عبر الدعم داخل التطبيق.

## الأطفال

المنصة ليست موجّهة لمن هم دون 18 عامًا، ولا نجمع بياناتهم عن قصد.

## الأمان

نحمي الاتصال بالتشفير، ونربط الجلسة بجهازك، ونسجّل محاولات الدخول. لا يوجد نظام محصّن تمامًا؛ إذا وقع خرق يمسّ بياناتك، نُبلغك ونُبلغ الجهة المختصة وفق ما يقتضيه القانون.

${AR_FOOTER}`;

const PRIVACY_EN = `## What we collect

- **What you give us**: your phone number, name, city, delivery addresses, and what you write in posts, reviews and conversations. For sellers: verification documents and bank details.
- **What your use produces**: your orders and invoices, your favourites, your searches, what you browse, and your wallet and points balances.
- **What relates to your device**: device type, operating system, app version, IP address and notification identifier. Sign-ins and devices are recorded to protect your account.
- **Photographs you upload for visual search**: used for the search and then deleted after a limited period; what remains is a numeric descriptor from which the photograph cannot be reconstructed.

## Why we collect it

To fulfil your orders, to sign you in and verify your identity, to prevent fraud and abuse, to order what is shown to you, to send you notices about your orders, and to meet our accounting and legal obligations.

## Who we share it with

- **The seller**: the recipient's name, phone number and delivery address — for the order you placed with her, and for that purpose alone.
- **The courier**: what is needed to deliver the parcel.
- **The WhatsApp messaging provider**: your number, to send the verification code.
- **The push provider**: your device identifier, to deliver the notification.
- **Authorities**: on a binding legal request.

**We do not sell your personal data, and we do not share it for advertising outside the platform.**

## What we cannot reach

We do not store your password as text, we do not reach your phone's photographs beyond the ones you choose to upload, and we do not read your conversations except when you refer them to us in a dispute or a report.

## Retention

We keep your data for as long as your account exists. After deletion your personal data is removed, while order records, invoices and financial entries are retained for as long as the law requires, and security records for a limited period to prevent abuse.

## Your rights

- See and correct your data from Account settings.
- See the policies you have accepted and the date of each acceptance.
- Manage your devices and sessions and end any of them.
- Control notifications from their settings.
- Ask for your account and data to be deleted.

For any request about your data, open a ticket through in-app support.

## Children

The platform is not intended for anyone under 18, and we do not knowingly collect their data.

## Security

We protect the connection with encryption, bind the session to your device, and record sign-in attempts. No system is perfectly secure; if a breach affects your data we will tell you, and tell the competent authority, as the law requires.

${EN_FOOTER}`;

// ── 4. Returns ────────────────────────────────────────────────────────────

const RETURNS_AR = `## المهلة

يحقّ لك طلب إرجاع المنتج **خلال 7 أيام من تاريخ تسليم الطرد إليك**. تُحتسب المهلة من لحظة التسليم المسجّلة في التطبيق، وقد تكون أطول إذا كانت مرتبة حسابك تمنحك مهلة إضافية — تظهر لك المهلة الفعلية على صفحة الطلب.

## شروط قبول الإرجاع

- أن يكون المنتج بحالته الأصلية، غير مستعمل، وبكامل ملحقاته وبطاقاته وتغليفه.
- أن يُطلَب الإرجاع من صفحة الطلب داخل التطبيق، لا عبر البائعة مباشرة.
- أن يُرفَق دليل مصوَّر عندما يكون سبب الطلب عيبًا أو خطأ في الإرسال أو عدم مطابقة أو تلفًا أثناء النقل.

## ما لا يُقبل إرجاعه بتغيير الرأي

- الملابس الداخلية وملابس السباحة.
- مستحضرات التجميل والعناية الشخصية بعد فتح غلافها.
- المنتجات المصنوعة أو المفصّلة حسب الطلب.
- الأصناف التي تُعلن صفحتها صراحةً أنها غير قابلة للإرجاع.

**هذا الاستثناء يخصّ تغيير الرأي وحده.** إذا وصل المنتج معيبًا أو مخالفًا لوصفه أو تالفًا، فهو قابل للإرجاع في جميع الأحوال.

## من يتحمّل أجور الإرجاع

- **البائعة**، إذا كان السبب عيبًا في المنتج، أو إرسال صنف خطأ، أو عدم مطابقة للوصف.
- **المنصة أو شركة التوصيل**، إذا وقع التلف أثناء النقل أو تأخّر التسليم تأخّرًا جوهريًا.
- **المشترية**، إذا كان السبب تغيير الرأي.

## المسار الزمني

1. تفتحين طلب الإرجاع من صفحة الطلب وتختارين السبب والكمية.
2. تردّ البائعة بالقبول أو الرفض **خلال 48 ساعة**. عدم الرد خلال المهلة يُحيل الطلب إلى فريق أوهارا.
3. عند القبول تُرتَّب إعادة الطرد، ويُفحَص عند الاستلام.
4. يُصرَف المبلغ **خلال 3 أيام عمل** من قبول الإرجاع أو من استلام البضاعة، أيهما أبعد.

## كيف يُردّ المبلغ

- ما دُفع من المحفظة يعود إلى المحفظة.
- ما دُفع عند الاستلام يعود إلى محفظتك داخل التطبيق، أو نقدًا إذا طلبتِ ذلك عبر الدعم.
- أجور التوصيل الأصلية تُردّ فقط عندما يكون سبب الإرجاع من البائعة أو من النقل.

## الاستبدال

الاستبدال متاح ضمن المهلة وبالشروط نفسها، بشرط توفّر المقاس أو اللون البديل. فرق السعر — إن وُجد — يُحصَّل أو يُردّ حسب اتجاهه.

## إذا رُفض طلبك

الرفض يصدر مع سبب مكتوب. إذا لم تقتنعي به، يمكنك تصعيد الطلب إلى فريق أوهارا من صفحة الطلب نفسها، ويُنظر فيه وفق «آلية الشكاوى والنزاعات».

${AR_FOOTER}`;

const RETURNS_EN = `## The window

You may ask to return a product **within 7 days of the parcel being delivered to you**. The window runs from the delivery recorded in the app, and may be longer if your account standing grants extra days — the actual window is shown on the order page.

## Conditions

- The product must be in its original condition, unused, with all its accessories, tags and packaging.
- The return must be requested from the order page in the app, not directly with the seller.
- Photographic evidence must be attached when the reason is a defect, a wrong item, a mismatch with the description, or damage in transit.

## What cannot be returned on a change of mind

- Underwear and swimwear.
- Cosmetics and personal care products once opened.
- Made-to-order or custom-made products.
- Items whose page states explicitly that they cannot be returned.

**This exclusion applies to a change of mind only.** A product that arrives defective, not as described, or damaged can be returned in every case.

## Who bears the return shipping

- **The seller**, where the reason is a defect, a wrong item, or a mismatch with the description.
- **The platform or the courier**, where the damage happened in transit or delivery was materially late.
- **The buyer**, where the reason is a change of mind.

## The timeline

1. You open a return request from the order page and choose the reason and the quantity.
2. The seller answers, accepting or refusing, **within 48 hours**. No answer within that time sends the request to the Ohara team.
3. On acceptance the parcel's return is arranged, and it is inspected on receipt.
4. The money is issued **within 3 working days** of acceptance or of the goods being received, whichever is later.

## How the money comes back

- What was paid from the wallet returns to the wallet.
- What was paid on delivery returns to your in-app wallet, or in cash if you ask support for that.
- The original delivery charge is refunded only where the reason lies with the seller or with the carriage.

## Exchanges

An exchange is available within the same window and on the same conditions, provided the alternative size or colour is in stock. Any price difference is collected or refunded accordingly.

## If your request is refused

A refusal is issued with a written reason. If you are not satisfied with it you can escalate from the same order page, and it is considered under the Complaints and Disputes process.

${EN_FOOTER}`;

// ── 5. Commissions ────────────────────────────────────────────────────────

const COMMISSIONS_AR = `## ما هي العمولة

العمولة هي حصة المنصة من كل عملية بيع تتم عبرها. لا يوجد اشتراك شهري ولا رسم على فتح المتجر؛ لا تُحتسب العمولة إلا على بيع تمّ فعلًا.

## على ماذا تُحتسب

تُحتسب على **قيمة الأصناف بعد الخصم**، أي بعد الكوبونات والتخفيضات. **لا تشمل أجور التوصيل**، ولا أي رسم تحصّله جهة أخرى.

## النسبة

النسبة الافتراضية **10٪**. قد تختلف بحسب الفئة أو مستوى المتجر وفق جدول العمولات المعلن في لوحة البائعة، وتُطبَّق دائمًا النسبة السارية لحظة تأكيد الطلب. النسبة المحتسبة على كل طلب تظهر لك في تفاصيله وفي كشف الأرباح.

## متى تُقتطع ومتى تُصرف أرباحك

1. عند تأكيد الطلب تُحسب العمولة وتُثبَّت على الطلب؛ تغيير النسبة لاحقًا لا يمسّ طلبًا سابقًا.
2. بعد تسليم الطرد تبدأ مهلة الإرجاع، وتبقى مستحقاتك محجوزة طوالها.
3. بانقضاء مهلة الإرجاع دون طلب إرجاع أو نزاع مفتوح، يُفرَج عن صافي مستحقاتك وتدخل دورة التسوية.

الحجز ليس تأخيرًا إداريًا: هو ما يجعل ردّ المال إلى المشترية ممكنًا دون مطالبتك باسترداده بعد أن يكون قد وصلك.

## الإرجاع والإلغاء

عند إرجاع صنف أو إلغاء طلب، تُعكس عمولته بالكامل أو بنسبة ما أُرجع منه. لا تتحمّلين عمولة على بيع لم يتم.

## أجور التوصيل

أجور التوصيل ليست إيرادًا لك ولا وعاءً للعمولة. تُحصَّل وتُسدَّد لشركة التوصيل، ويظهر تفصيلها في الطلب.

## الرسوم الاختيارية

الترويج المدفوع وإبراز المنتجات والمشاركة في الحملات خدمات اختيارية برسوم معلنة قبل الشراء. لا تُخصم تلقائيًا ولا علاقة لها بالعمولة.

## الخصم من المستحقات

قد تُخصم من مستحقاتك: أجور إرجاع تتحمّلينها، أو تعويض حُكم به في نزاع، أو مبالغ حُصّلت خطأً. كل خصم يُبيَّن سببه في كشف أرباحك.

## تغيير النسب

أي تعديل على جدول العمولات يُعلَن قبل سريانه بمدة لا تقلّ عن **30 يومًا**، ولا يسري على الطلبات المؤكّدة قبل تاريخ السريان.

${AR_FOOTER}`;

const COMMISSIONS_EN = `## What the commission is

The commission is the platform's share of each sale made through it. There is no monthly subscription and no fee to open a shop; commission is charged only on a sale that actually happened.

## What it is calculated on

It is calculated on the **item value after discount**, that is after coupons and reductions. It **does not include delivery charges**, nor any fee collected by another party.

## The rate

The default rate is **10%**. It may differ by category or shop tier according to the commission table published in the seller dashboard, and the rate in force at the moment the order is confirmed is always the one applied. The rate charged on each order appears in its details and in your earnings statement.

## When it is taken, and when you are paid

1. When an order is confirmed the commission is calculated and fixed to it; a later change of rate does not touch an earlier order.
2. Once the parcel is delivered the return window begins, and your earnings are held for its duration.
3. When the return window passes with no return request and no open dispute, your net earnings are released and enter the settlement cycle.

The hold is not an administrative delay: it is what makes refunding a buyer possible without asking you to give back money that has already reached you.

## Returns and cancellations

When an item is returned or an order cancelled, its commission is reversed in full or in proportion to what was returned. You never bear commission on a sale that did not complete.

## Delivery charges

Delivery charges are not your revenue and are not a base for commission. They are collected and paid to the courier, and are itemised on the order.

## Optional fees

Paid promotion, featured placement and campaign participation are optional services with fees stated before purchase. They are never deducted automatically and have nothing to do with the commission.

## Deductions from earnings

The following may be deducted from your earnings: return shipping you bear, compensation awarded in a dispute, or amounts collected in error. Every deduction states its reason in your earnings statement.

## Changes to the rates

Any change to the commission table is announced at least **30 days** before it takes effect, and does not apply to orders confirmed before the effective date.

${EN_FOOTER}`;

// ── 6. Disputes ───────────────────────────────────────────────────────────

const DISPUTES_AR = `## قبل أن تفتحي نزاعًا

معظم المشكلات تُحلّ في رسالة واحدة. ابدئي بمراسلة البائعة من صفحة الطلب: المحادثة مرتبطة بالطلب، وما يُكتب فيها يصل إلى فريق أوهارا إذا صار الأمر نزاعًا، فلا تحتاجين إلى إعادة الشرح.

## متى يُفتح النزاع

- إذا لم تردّ البائعة خلال **48 ساعة**.
- إذا رُفض طلب الإرجاع ولم يقنعك السبب.
- إذا لم يصل الطرد بعد انقضاء مدة التوصيل المعلنة بـ**7 أيام**.
- إذا وصل الطرد ناقصًا أو مخالفًا لما طلبتِه.

يُفتح النزاع من صفحة الطلب، **خلال 14 يومًا** من التسليم أو من تاريخ التسليم المتوقّع.

## ما الذي يجب أن يرافق النزاع

- رقم الطلب والصنف موضوع الشكوى.
- صور واضحة، وفيديو فتح الطرد إن وُجد — وهو أقوى دليل في حالات النقص والتلف.
- ما تطلبينه: استرداد، استبدال، أو إتمام التسليم.

## المهل

| المرحلة | المهلة |
| --- | --- |
| ردّ البائعة على الشكوى | 48 ساعة |
| القرار الأول من فريق أوهارا | 7 أيام عمل |
| الاعتراض على القرار | 7 أيام من إبلاغك به |
| القرار النهائي | 7 أيام عمل من الاعتراض |

الحالات التي تحتاج فحصًا أو تحقّقًا من شركة التوصيل قد تستغرق أطول، ويُبلَّغ إليك ذلك مع سببه.

## كيف يُتّخذ القرار

ننظر في سجل الطلب داخل النظام — التوقيتات، حالة الشحنة، ما كُتب في المحادثة — وفي الأدلة المرفقة من الطرفين. لا نُرجّح طرفًا على آخر بحكم صفته؛ الأدلة والسجل هما ما يُبنى عليه، ويُبلَّغ الطرفان بالقرار وسببه.

## أثر النزاع على المال

فتح نزاع على طلب يوقف الإفراج عن مستحقات البائعة منه حتى يُحسم. عند صدور القرار يُنفَّذ فورًا: استرداد إلى محفظة المشترية، أو إفراج عن المستحقات للبائعة، أو تسوية جزئية بينهما.

## الاعتراض

لكل طرف حق الاعتراض مرة واحدة على القرار الأول، بشرط تقديم معطى جديد لم يُنظر فيه. يراجع الاعتراضَ شخص غير الذي أصدر القرار الأول.

## إساءة استخدام النظام

فتح نزاعات كيدية، أو تقديم أدلة مُصطنعة، أو ادّعاء عدم الاستلام مع ثبوت خلافه، مخالفة جوهرية تستوجب تقييد الحساب أو إيقافه، ولا تمنع المطالبة بالتعويض.

${AR_FOOTER}`;

const DISPUTES_EN = `## Before you open a dispute

Most problems are settled in one message. Start by messaging the seller from the order page: the conversation is attached to the order, and what is written in it reaches the Ohara team if the matter becomes a dispute, so you never have to explain twice.

## When a dispute may be opened

- If the seller has not answered within **48 hours**.
- If a return request was refused and the reason does not satisfy you.
- If the parcel has not arrived **7 days** after the advertised delivery period.
- If the parcel arrived incomplete or different from what you ordered.

A dispute is opened from the order page, **within 14 days** of delivery or of the expected delivery date.

## What a dispute must carry

- The order number and the item complained of.
- Clear photographs, and an unboxing video if there is one — the strongest evidence in cases of shortage or damage.
- What you are asking for: a refund, an exchange, or completion of delivery.

## The clocks

| Stage | Time |
| --- | --- |
| Seller's reply to the complaint | 48 hours |
| First decision by the Ohara team | 7 working days |
| Appeal against the decision | 7 days from being told |
| Final decision | 7 working days from the appeal |

Cases needing an inspection or a check with the courier may take longer, and you are told so and why.

## How a decision is made

We look at the order's record inside the system — the timings, the shipment's status, what was written in the conversation — and at the evidence both sides attached. Neither side is preferred for what it is; the evidence and the record are what a decision is built on, and both sides are told the decision and its reason.

## What a dispute does to the money

Opening a dispute on an order holds the seller's earnings from it until it is resolved. When the decision is issued it is carried out at once: a refund to the buyer's wallet, a release of earnings to the seller, or a partial settlement between them.

## Appeals

Each side may appeal the first decision once, provided it brings something new that was not considered. An appeal is reviewed by someone other than whoever made the first decision.

## Abusing the process

Opening vexatious disputes, submitting fabricated evidence, or claiming non-delivery where the contrary is established is a serious breach that warrants restricting or suspending the account, and does not preclude a claim for compensation.

${EN_FOOTER}`;

// ── 7. Liability ──────────────────────────────────────────────────────────

const LIABILITY_AR = `## الخلاصة أولًا

أوهارا منصة وسيطة. عقد البيع بينك وبين البائعة، والبائعة مسؤولة عن بضاعتها. مسؤولية أوهارا هي عن المنصة نفسها وعن الخدمات التي تقدّمها بذاتها: الطلب، والتحصيل، وحجز المال، والتوثيق، وفضّ النزاع.

## ما تضمنه أوهارا

- أن يكون كل طلب مسجّلًا بحالته وتوقيتاته، وأن يكون هذا السجل متاحًا للطرفين.
- أن تبقى مستحقات البائعة محجوزة حتى التسليم وانقضاء مهلة الإرجاع، فلا يُطالَب أحد بمال غادر بالفعل.
- أن تُوثَّق كل بائعة قبل البيع، وأن يُتاح الإبلاغ عن أي متجر أو منتج.
- أن يُنظر في كل نزاع وفق مهل معلنة وقرار مسبَّب.

## ما لا تضمنه أوهارا

- ملاءمة المنتج لذوقك أو لمقاسك، ما دام مطابقًا لوصفه وصوره.
- دقة ما تكتبه البائعة عن بضاعتها؛ هي المسؤولة عنه، ونحن نتصرّف عند ثبوت المخالفة.
- أن تبقى الخدمة متاحة دون انقطاع؛ قد تتوقّف لصيانة أو لعطل خارج سيطرتنا.

## مسؤولية البائعة

- مطابقة المنتج لوصفه وصوره ومقاساته وخاماته.
- سلامة المنتج وقانونية بيعه، وأي ضرر ينشأ عن عيب فيه.
- التجهيز في الوقت المعلن والتسليم إلى الجهة الناقلة.
- الالتزام بسياستَي الإرجاع والمحتوى.

## مسؤولية المشترية

- دقة العنوان ورقم الهاتف واسم المستلمة.
- التواجد لاستلام الطرد أو ترتيب من يستلمه.
- فحص الطرد عند الاستلام والإبلاغ عن أي نقص أو تلف ظاهر فور اكتشافه.
- استخدام المنتج وفق تعليماته.

## شركة التوصيل

التوصيل تُنفّذه شركات مستقلة. التلف أو الفقد أثناء النقل يُعالَج عبر آلية النزاعات، وتتولّى أوهارا متابعته مع الشركة الناقلة نيابةً عن الطرفين.

## حدود المسؤولية

في جميع الأحوال، لا تتجاوز مسؤولية أوهارا المالية تجاه أي طرف عن طلب واحد **قيمة ذلك الطلب مضافًا إليها أجور توصيله**. ولا تُسأل أوهارا عن الأضرار غير المباشرة أو الأرباح الفائتة.

لا يُقصد بهذا البند إسقاط أي حق لا يجيز القانون النافذ إسقاطه.

## القوة القاهرة

لا يُسأل أي طرف عن تأخّر أو إخلال سببه ظرف خارج عن سيطرته المعقولة، على أن يُبلَّغ الطرف الآخر في أقرب وقت ممكن.

${AR_FOOTER}`;

const LIABILITY_EN = `## The short version

Ohara is an intermediary platform. The contract of sale is between you and the seller, and the seller is responsible for her goods. Ohara's responsibility is for the platform itself and for the services it provides in its own right: ordering, collection, holding the money, verification, and resolving disputes.

## What Ohara guarantees

- That every order is recorded with its state and its timings, and that this record is available to both sides.
- That a seller's earnings are held until delivery and the end of the return window, so that nobody is asked for money that has already left.
- That every seller is verified before selling, and that any shop or product can be reported.
- That every dispute is considered within published time limits and decided with a stated reason.

## What Ohara does not guarantee

- That a product will suit your taste or your size, so long as it matches its description and photographs.
- The accuracy of what a seller writes about her goods; she is responsible for that, and we act when a breach is established.
- Uninterrupted availability of the service; it may stop for maintenance or for a failure outside our control.

## The seller's responsibility

- That the product matches its description, photographs, sizes and materials.
- The safety of the product and the legality of selling it, and any harm arising from a defect in it.
- Preparing within the advertised time and handing over to the carrier.
- Compliance with the returns and content policies.

## The buyer's responsibility

- The accuracy of the address, phone number and recipient name.
- Being present to receive the parcel, or arranging someone to receive it.
- Inspecting the parcel on receipt and reporting any shortage or visible damage as soon as it is found.
- Using the product according to its instructions.

## The courier

Delivery is carried out by independent companies. Damage or loss in transit is handled through the disputes process, and Ohara pursues it with the carrier on behalf of both sides.

## Limits of liability

In every case, Ohara's financial liability to any party in respect of a single order does not exceed **the value of that order plus its delivery charge**. Ohara is not liable for indirect loss or for lost profit.

Nothing in this clause is intended to exclude a right that the law in force does not permit to be excluded.

## Force majeure

Neither party is liable for delay or failure caused by circumstances beyond its reasonable control, provided the other party is told as soon as possible.

${EN_FOOTER}`;

// ── 8. Content ────────────────────────────────────────────────────────────

const CONTENT_AR = `## ما الذي تشمله هذه السياسة

كل ما يُنشر على أوهارا: المنشورات والريلز والقصص، التعليقات والردود، صور المنتجات وأوصافها، التقييمات، أسماء المتاجر وصورها، والرسائل بين المستخدمات.

## قاعدة الاحتشام

أوهارا مساحة نسائية، والالتزام بالاحتشام شرط لا استثناء فيه:

- يُمنع العُري أو ما يقاربه.
- الملابس الداخلية وملابس السباحة تُعرَض على مانيكان أو مسطّحة، **لا على جسد**.
- يُمنع التركيز على مناطق الجسد بما يخرج المحتوى عن غرضه التجاري.
- إظهار الوجه اختيار شخصي، ولا يُشترط لنشر أي محتوى.

## ملكية ما تنشرينه

أنتِ مالكة محتواك. بنشره تمنحين أوهارا ترخيصًا غير حصري بعرضه داخل المنصة وفي الترويج لها، ويسقط هذا الترخيص عند حذف المحتوى — عدا النسخ التي يفرض القانون أو النزاع القائم الاحتفاظ بها.

لا تنشري ما لا تملكين حقوقه: صورة متجر آخر، تصميمًا لغيرك، أو مقطعًا موسيقيًا مرخّصًا.

## الممنوع

- الإساءة والتحرش والتهديد، وخطاب الكراهية على أساس الدين أو العِرق أو الأصل.
- نشر بيانات شخصية لغيرك: رقم، عنوان، صورة، محادثة خاصة.
- السلع الممنوعة قانونًا، والمقلّدة، والمنتجات الطبية التي تحتاج ترخيصًا.
- الادّعاءات الطبية أو العلاجية غير المثبَتة.
- التقييمات المدفوعة أو المزيّفة، والحسابات الوهمية لرفع تقييم متجر.
- الروابط التي تدعو إلى الشراء خارج المنصة.
- المحتوى المسيء للأطفال بأي شكل.

## المراجعة والإبلاغ

ينشر المحتوى فورًا في الحالة العامة، ويخضع للمراجعة عند الإبلاغ عنه أو عند التقاطه آليًا. لكل مستخدمة أن تُبلغ عن أي محتوى من القائمة «…» بجانبه، والبلاغ سرّي.

## الحذف

- **كل إزالة تصدر بسبب مذكور.** لا يُحذف محتوى في صمت.
- تصلك الإزالة إشعارًا يبيّن القاعدة المخالَفة.
- يحق لك الاعتراض خلال **14 يومًا**، ويراجعه شخص غير الذي قرّر الإزالة.
- المحتوى المخالف مخالفةً جسيمة — محتوى يمسّ الأطفال، أو تهديد صريح — يُزال فورًا ويُبلَّغ عنه الجهات المختصة عند الاقتضاء.

## حذفك أنتِ لمحتواك

يمكنك حذف أي منشور أو تعليق أو تقييم لك في أي وقت، ويختفي من المنصة فورًا.

ما لا يُحذف بحذف المنشور: سجلات الطلبات والفواتير والقيود المالية المرتبطة بعملية بيع تمّت، وسجلات النزاعات القائمة، ونسخ الإشراف المحتفَظ بها لمدة محدودة لمنع إعادة نشر المخالف.

## حذف الحساب

عند حذف حسابك يُزال محتواك العام من المنصة. تبقى السجلات التي يفرض القانون أو المحاسبة الاحتفاظ بها، وتبقى التقييمات التي كتبتِها على متاجر أخرى بصيغة مجهولة الهوية إن كانت جزءًا من سمعة متجر قائم.

## تكرار المخالفة

تتدرّج الإجراءات: إزالة المحتوى، ثم تقييد النشر، ثم تقييد الظهور، ثم إيقاف الحساب. المخالفة الجسيمة تُوجب الإيقاف من أول مرة.

${AR_FOOTER}`;

const CONTENT_EN = `## What this policy covers

Everything published on Ohara: posts, reels and stories, comments and replies, product photographs and descriptions, reviews, shop names and images, and messages between users.

## The modesty rule

Ohara is a women's space, and modesty is a condition with no exceptions:

- Nudity, or anything approaching it, is prohibited.
- Underwear and swimwear are shown on a mannequin or laid flat, **never on a body**.
- Framing that dwells on parts of the body, beyond the commercial purpose of the image, is prohibited.
- Showing your face is a personal choice and is never required to publish anything.

## Ownership of what you publish

You own your content. By publishing it you grant Ohara a non-exclusive licence to display it inside the platform and in promoting the platform. That licence ends when you delete the content — other than copies the law or a live dispute requires us to keep.

Do not publish what you do not hold the rights to: another shop's photograph, someone else's design, or licensed music.

## What is prohibited

- Abuse, harassment and threats, and hate speech on grounds of religion, race or origin.
- Publishing another person's personal data: a number, an address, a photograph, a private conversation.
- Goods prohibited by law, counterfeits, and medical products requiring a licence.
- Unproven medical or therapeutic claims.
- Paid or fake reviews, and sham accounts used to raise a shop's rating.
- Links inviting a purchase outside the platform.
- Content that harms children in any form.

## Review and reporting

Content is published immediately in the ordinary case, and is reviewed when it is reported or flagged automatically. Any user may report any content from the «…» menu beside it, and a report is confidential.

## Removal

- **Every removal is issued with a stated reason.** Nothing is removed in silence.
- A removal reaches you as a notice naming the rule that was broken.
- You may appeal within **14 days**, and the appeal is reviewed by someone other than whoever decided the removal.
- Gravely violating content — anything harming children, or an explicit threat — is removed immediately and reported to the authorities where appropriate.

## Deleting your own content

You may delete any post, comment or review of yours at any time, and it disappears from the platform at once.

What deleting a post does not delete: order records, invoices and financial entries tied to a completed sale, records of live disputes, and moderation copies retained for a limited period to stop violating content being reposted.

## Deleting your account

When your account is deleted your public content is removed from the platform. Records that law or accounting requires us to keep remain, and reviews you wrote about other shops remain in anonymised form where they form part of a live shop's reputation.

## Repeat breaches

The response escalates: removing the content, then restricting publishing, then restricting visibility, then suspending the account. A grave breach warrants suspension the first time.

${EN_FOOTER}`;

// ── The catalogue ─────────────────────────────────────────────────────────

/**
 * The eight, in the order the policy centre shows them.
 *
 * `requiredForConsent` is true for four of them and that is a deliberate
 * minimum: a signup screen that demands eight separate signatures is a screen
 * nobody reads. The two sets of terms, privacy, and — for a seller — the
 * commissions she is about to be charged are the ones a person genuinely needs
 * to have agreed to. The rest are published, linked from where they matter,
 * and can be made mandatory from the console without a deploy.
 */
export const POLICY_SEED: readonly PolicySeedDocument[] = [
  {
    kind: PolicyDocumentKind.CUSTOMER_TERMS,
    slug: 'customer-terms',
    audience: PolicyAudience.CUSTOMER,
    sortOrder: 10,
    requiredForConsent: true,
    icon: 'terms',
    translations: [
      {
        locale: 'ar',
        title: 'شروط استخدام العميل',
        summary: 'حقوقك والتزاماتك كمشترية على أوهارا: الحساب، الطلب، الدفع، الإلغاء.',
        body: CUSTOMER_TERMS_AR,
      },
      {
        locale: 'en',
        title: 'Customer Terms of Use',
        summary:
          'Your rights and obligations as a shopper on Ohara: account, ordering, payment, cancellation.',
        body: CUSTOMER_TERMS_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.SELLER_TERMS,
    slug: 'seller-terms',
    audience: PolicyAudience.SELLER,
    sortOrder: 20,
    requiredForConsent: true,
    icon: 'storefront',
    translations: [
      {
        locale: 'ar',
        title: 'شروط استخدام البائع',
        summary: 'شروط فتح متجر على أوهارا: التوثيق، البضاعة، التجهيز، المستحقات.',
        body: SELLER_TERMS_AR,
      },
      {
        locale: 'en',
        title: 'Seller Terms of Use',
        summary:
          'The terms for opening a shop on Ohara: verification, goods, fulfilment, earnings.',
        body: SELLER_TERMS_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.PRIVACY,
    slug: 'privacy',
    audience: PolicyAudience.EVERYONE,
    sortOrder: 30,
    requiredForConsent: true,
    icon: 'privacy',
    translations: [
      {
        locale: 'ar',
        title: 'سياسة الخصوصية',
        summary: 'ما الذي نجمعه من بياناتك، ولماذا، ومع من نشاركه، وكيف تتحكمين به.',
        body: PRIVACY_AR,
      },
      {
        locale: 'en',
        title: 'Privacy Policy',
        summary:
          'What data we collect, why, who we share it with, and how you control it.',
        body: PRIVACY_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.RETURNS,
    slug: 'returns',
    audience: PolicyAudience.EVERYONE,
    sortOrder: 40,
    requiredForConsent: false,
    icon: 'returns',
    translations: [
      {
        locale: 'ar',
        title: 'سياسة الإرجاع والاستبدال',
        summary: 'سبعة أيام من الاستلام، ومن يتحمّل الأجور، وكيف يعود المبلغ إليك.',
        body: RETURNS_AR,
      },
      {
        locale: 'en',
        title: 'Returns and Exchanges Policy',
        summary:
          'Seven days from delivery, who bears the shipping, and how the money comes back.',
        body: RETURNS_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.COMMISSIONS,
    slug: 'commissions',
    audience: PolicyAudience.SELLER,
    sortOrder: 50,
    requiredForConsent: true,
    icon: 'commission',
    translations: [
      {
        locale: 'ar',
        title: 'سياسة العمولات',
        summary: 'كم تأخذ المنصة، على ماذا تُحتسب، ومتى تُصرف أرباح متجرك.',
        body: COMMISSIONS_AR,
      },
      {
        locale: 'en',
        title: 'Commissions Policy',
        summary:
          "What the platform takes, what it is calculated on, and when your shop's earnings are paid.",
        body: COMMISSIONS_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.DISPUTES,
    slug: 'disputes',
    audience: PolicyAudience.EVERYONE,
    sortOrder: 60,
    requiredForConsent: false,
    icon: 'dispute',
    translations: [
      {
        locale: 'ar',
        title: 'آلية الشكاوى والنزاعات',
        summary: 'كيف تُرفع الشكوى، وما المهل، وكيف يُتّخذ القرار ويُعترض عليه.',
        body: DISPUTES_AR,
      },
      {
        locale: 'en',
        title: 'Complaints and Disputes',
        summary:
          'How a complaint is raised, the time limits, and how a decision is made and appealed.',
        body: DISPUTES_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.LIABILITY,
    slug: 'liability',
    audience: PolicyAudience.EVERYONE,
    sortOrder: 70,
    requiredForConsent: false,
    icon: 'liability',
    translations: [
      {
        locale: 'ar',
        title: 'مسؤولية المنصة والبائع',
        summary: 'أين تنتهي مسؤولية أوهارا وأين تبدأ مسؤولية البائعة والمشترية.',
        body: LIABILITY_AR,
      },
      {
        locale: 'en',
        title: 'Platform and Seller Liability',
        summary:
          "Where Ohara's responsibility ends and the seller's and buyer's begin.",
        body: LIABILITY_EN,
      },
    ],
  },
  {
    kind: PolicyDocumentKind.CONTENT,
    slug: 'content',
    audience: PolicyAudience.EVERYONE,
    sortOrder: 80,
    requiredForConsent: false,
    icon: 'content',
    translations: [
      {
        locale: 'ar',
        title: 'سياسة المحتوى والحذف',
        summary: 'ما الذي يُنشر وما الذي يُزال، ولماذا، وكيف تعترضين على إزالة.',
        body: CONTENT_AR,
      },
      {
        locale: 'en',
        title: 'Content and Removal Policy',
        summary:
          'What may be published and what is removed, why, and how to appeal a removal.',
        body: CONTENT_EN,
      },
    ],
  },
];
