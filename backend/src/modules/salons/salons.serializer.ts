import {
  Appointment,
  Address,
  Salon,
  SalonClosure,
  SalonMedia,
  SalonReview,
  SalonService,
  SalonWorkingHours,
  User,
} from '@prisma/client';
import { Money } from '../../common/money';
import { serializePublicUser } from '../../common/serializers/user.serializer';

/**
 * The wire shapes for «الصالونات والجمال».
 *
 * Two rules carried over from the rest of this API, because a client that has
 * to learn a second dialect for one feature is a client that will get it
 * wrong:
 *
 *  - **snake_case keys.** Every response on this platform is snake_case.
 *  - **Money as `{ amount, currency }`.** Never a bare number. An appointment
 *    is paid at the chair rather than here, but the figure she was quoted is
 *    still money and still needs to say what currency it is in.
 */

/**
 * The two shapes a salon is loaded in.
 *
 * A card needs only enough of the menu to say «من …», and the directory query
 * selects exactly that — two columns for twenty salons rather than the whole
 * price list for each. A page needs the menu itself. Typing them separately is
 * what lets the card serializer be reused by the page without the page's query
 * being forced on the directory.
 */
type SalonPriceRow = Pick<SalonService, 'price' | 'currency'>;

type SalonCardRow = Salon & {
  services?: SalonPriceRow[];
};

type SalonWithRelations = SalonCardRow & {
  owner?: User | null;
  media?: SalonMedia[];
  services?: SalonService[];
  hours?: SalonWorkingHours[];
  closures?: SalonClosure[];
};

export function serializeSalonService(service: SalonService) {
  const price = Money.of(service.price, service.currency);
  const compareAt = service.compareAtPrice
    ? Money.of(service.compareAtPrice, service.currency)
    : null;

  return {
    id: service.id,
    salon_id: service.salonId,
    name: service.name,
    description: service.description,
    category: service.category,
    price: price.toJSON(),
    compare_at_price: compareAt?.toJSON() ?? null,
    /// True only when the salon is genuinely running an offer. A compare-at at
    /// or below the asking price is a data error rather than a deal, and the
    /// card must not draw a discount badge for one.
    has_offer: Boolean(
      service.compareAtPrice &&
        service.compareAtPrice.greaterThan(service.price),
    ),
    duration_minutes: service.durationMinutes,
    buffer_minutes: service.bufferMinutes,
    location: service.location,
    image_url: service.imageUrl,
    is_package: service.isPackage,
    is_active: service.isActive,
    sort_order: service.sortOrder,
  };
}

export function serializeSalonHours(hours: SalonWorkingHours) {
  return {
    weekday: hours.weekday,
    is_closed: hours.isClosed,
    opens_at: hours.opensAt,
    closes_at: hours.closesAt,
    break_starts_at: hours.breakStartsAt,
    break_ends_at: hours.breakEndsAt,
  };
}

export function serializeSalonMedia(media: SalonMedia) {
  return {
    id: media.id,
    url: media.url,
    type: media.type,
    blur_hash: media.blurHash,
    sort_order: media.sortOrder,
  };
}

/** The directory card: enough to choose from, not enough to book with. */
export function serializeSalonCard(salon: SalonCardRow) {
  return {
    id: salon.id,
    slug: salon.slug,
    name: salon.name,
    tagline: salon.tagline,
    status: salon.status,
    governorate: salon.governorate,
    city: salon.city,
    district: salon.district,
    logo_url: salon.logoUrl,
    cover_url: salon.coverUrl,
    rating: salon.rating,
    reviews_count: salon.reviewsCount,
    services_count: salon.servicesCount,
    home_service: salon.homeService,
    is_featured: salon.isFeatured,
    /// The cheapest live service, so a card can say «من ٢٥٬٠٠٠ ل.س» without
    /// the client pulling the whole menu for every salon in a list.
    price_from:
      salon.services && salon.services.length > 0
        ? Money.of(
            salon.services.reduce(
              (lowest, service) =>
                service.price.lessThan(lowest) ? service.price : lowest,
              salon.services[0].price,
            ),
            salon.services[0].currency,
          ).toJSON()
        : null,
  };
}

/** The salon's own page. */
export function serializeSalon(salon: SalonWithRelations) {
  return {
    ...serializeSalonCard(salon),
    about: salon.about,
    address_line: salon.addressLine,
    landmark: salon.landmark,
    latitude: salon.latitude,
    longitude: salon.longitude,
    phone: salon.phone,
    whatsapp: salon.whatsapp,
    /// Who to open a chat with. The salon has no inbox of its own — a message
    /// about an appointment goes to the woman who owns it, through the chat
    /// that already exists.
    owner: salon.owner ? serializePublicUser(salon.owner) : null,
    slot_minutes: salon.slotMinutes,
    lead_minutes: salon.leadMinutes,
    horizon_days: salon.horizonDays,
    concurrent_capacity: salon.concurrentCapacity,
    cancellation_hours: salon.cancellationHours,
    home_service_fee: salon.homeServiceFee
      ? Money.of(salon.homeServiceFee, salon.currency).toJSON()
      : null,
    appointments_count: salon.appointmentsCount,
    media: (salon.media ?? []).map(serializeSalonMedia),
    services: (salon.services ?? []).map(serializeSalonService),
    hours: (salon.hours ?? []).map(serializeSalonHours),
    closures: (salon.closures ?? []).map((closure) => ({
      date: closure.date.toISOString().slice(0, 10),
      reason: closure.reason,
    })),
  };
}

type AppointmentWithRelations = Appointment & {
  salon?: Salon | null;
  customer?: User | null;
  address?: Address | null;
  review?: SalonReview | null;
};

export function serializeAppointment(appointment: AppointmentWithRelations) {
  return {
    id: appointment.id,
    reference: appointment.reference,
    status: appointment.status,
    salon_id: appointment.salonId,
    salon: appointment.salon ? serializeSalonCard(appointment.salon) : null,
    /// Present on the salon's own queue and absent from the customer's copy —
    /// she knows who she is, and her own contact details do not belong in a
    /// response she can hand to somebody else.
    customer: appointment.customer
      ? serializePublicUser(appointment.customer)
      : null,
    service_id: appointment.serviceId,
    service_name: appointment.serviceName,
    duration_minutes: appointment.durationMinutes,
    price: Money.of(appointment.price, appointment.currency).toJSON(),
    starts_at: appointment.startsAt.toISOString(),
    ends_at: appointment.endsAt.toISOString(),
    at_home: appointment.atHome,
    address: appointment.address
      ? {
          id: appointment.address.id,
          label: appointment.address.label,
          governorate: appointment.address.governorate,
          city: appointment.address.city,
          address_line: appointment.address.addressLine,
          landmark: appointment.address.landmark,
        }
      : null,
    customer_note: appointment.customerNote,
    salon_note: appointment.salonNote,
    confirmed_at: appointment.confirmedAt?.toISOString() ?? null,
    completed_at: appointment.completedAt?.toISOString() ?? null,
    cancelled_at: appointment.cancelledAt?.toISOString() ?? null,
    cancelled_by: appointment.cancelledBy,
    cancellation_reason: appointment.cancellationReason,
    cancelled_late: appointment.cancelledLate,
    /// What the client draws its buttons from, so the two can never disagree
    /// about whether an appointment can still be cancelled. The server decides;
    /// the screen renders.
    can_cancel:
      appointment.status === 'PENDING' || appointment.status === 'CONFIRMED',
    can_review: appointment.status === 'COMPLETED' && !appointment.review,
    review: appointment.review
      ? serializeSalonReview(appointment.review)
      : null,
    created_at: appointment.createdAt.toISOString(),
  };
}

export function serializeSalonReview(
  review: SalonReview & { user?: User | null },
) {
  return {
    id: review.id,
    salon_id: review.salonId,
    appointment_id: review.appointmentId,
    rating: review.rating,
    body: review.body,
    /// Always true here, and stated rather than implied: a salon review can
    /// only be written from a COMPLETED appointment, so there is no such thing
    /// as an unverified one on this half of the platform.
    verified: true,
    user: review.user ? serializePublicUser(review.user) : null,
    salon_reply: review.salonReply,
    salon_replied_at: review.salonRepliedAt?.toISOString() ?? null,
    created_at: review.createdAt.toISOString(),
  };
}
