/**
 * The words a customer reads on an order's timeline.
 *
 * Every one of these used to be an English string literal at its call site —
 * `title: 'Out for delivery'` in the shipments service, `'Order accepted'` in
 * the seller's, `'Return approved'` in returns — and all of them are rendered
 * verbatim in «تتبّع الطلب» and in the parcel's history. So the one screen a
 * woman opens to find out where her parcel is spoke English, in an app that is
 * Arabic everywhere else.
 *
 * They live here rather than at the call sites because they are a vocabulary,
 * not incidental text: the same event has to read the same way whether it was
 * reported by a courier tapping «سلّمت», by a delivery company's webhook, or by
 * the seller's own screen — three code paths that were each writing their own
 * wording.
 *
 * The client also derives a label from the event's `to_status` and prefers it,
 * which is what makes the rows already in the database read Arabic too. These
 * constants are what everything written from now on says.
 */
export const OrderEventCopy = {
  // ── The order itself ────────────────────────────────────────────────────
  orderCreated: 'تم إنشاء الطلب',
  orderPlaced: (number: string) => `تم تسجيل الطلب ${number}`,
  subOrderCreated: 'تم إنشاء طلب البائعة',
  awaitingSeller: (seller: string) => `بانتظار تأكيد ${seller}`,
  orderConfirmed: 'تم تأكيد الطلب',
  sentToSellers: 'أُرسل إلى البائعات للتجهيز',

  // ── Payment ─────────────────────────────────────────────────────────────
  paymentReceived: 'تم استلام الدفعة',
  paymentConfirmed: (provider: string) => `تم تأكيد الدفع عبر ${provider}`,
  paymentCleared: (method: string) => `تمت تسوية الدفع — ${method}`,

  // ── Fulfilment ──────────────────────────────────────────────────────────
  orderAccepted: 'قبلت البائعة الطلب',
  sellerPreparing: 'بدأت البائعة بتجهيز الطرد',
  readyToShip: 'الطرد جاهز للشحن',
  onItsWay: 'الطرد بالطريق',
  collectedByCourier: 'استلم المندوب الطرد',
  courierHasParcel: 'الطرد مع المندوب',
  collectedByCarrier: 'استلمت شركة التوصيل الطرد',
  carrierHasParcel: 'الطرد مع شركة التوصيل',
  outForDelivery: 'خارج للتسليم',
  onTheWayToCustomer: 'في الطريق إليكِ',
  outForDeliveryToday: 'الطرد خارج للتسليم اليوم',
  delivered: 'تم التسليم',
  assignedToCourier: (courier: string) => `أُسند إلى ${courier}`,

  // ── Trouble ─────────────────────────────────────────────────────────────
  deliveryFailed: 'تعذّر التسليم',
  refusedAtDoor: 'رُفض الطرد عند الاستلام',
  comingBack: 'الطرد عائد',
  carrierReturning: 'شركة التوصيل تعيد الطرد',
  backWithSeller: 'عاد الطرد إلى البائعة',
  carrierReturned: 'أعادت شركة التوصيل الطرد',
  cancelledBySeller: 'ألغت البائعة الطلب',

  // ── Returns and exchanges ───────────────────────────────────────────────
  returnRequested: 'طلب إرجاع',
  returnApproved: 'تمت الموافقة على الإرجاع',
  returnRefused: 'رُفض طلب الإرجاع',
  returnWithdrawn: 'تم سحب طلب الإرجاع',
  returnOnItsWayBack: 'الإرجاع بالطريق',
  returnReceived: 'استلمت البائعة الإرجاع',
  exchangeInProgress: 'الاستبدال قيد التنفيذ',
  partialRefundIssued: 'تم استرداد جزئي',
  returnRefunded: (returnNumber: string, parcel: string) =>
    `تم استرداد قيمة الإرجاع ${returnNumber} — ${parcel}`,
  disputeOpened: 'فُتح نزاع',
} as const;
