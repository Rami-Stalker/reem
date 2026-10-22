import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  ReviewStatus,
  SalonStatus,
  SalonServiceLocation,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { Money } from '../../common/money';
import { buildMeta } from '../../common/dto/pagination.dto';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { searchKey } from '../search/arabic';
import {
  CreateClosureDto,
  ReplyToReviewDto,
  SalonQueryDto,
  SetWorkingHoursDto,
  UpsertSalonDto,
  UpsertSalonServiceDto,
} from './dto/salons.dto';
import {
  serializeSalon,
  serializeSalonCard,
  serializeSalonReview,
  serializeSalonService,
} from './salons.serializer';

/** The default week a new salon gets, so its calendar is never empty. */
const DEFAULT_HOURS = [
  { weekday: 0, isClosed: false, opensAt: '10:00', closesAt: '20:00' },
  { weekday: 1, isClosed: false, opensAt: '10:00', closesAt: '20:00' },
  { weekday: 2, isClosed: false, opensAt: '10:00', closesAt: '20:00' },
  { weekday: 3, isClosed: false, opensAt: '10:00', closesAt: '20:00' },
  { weekday: 4, isClosed: false, opensAt: '10:00', closesAt: '20:00' },
  { weekday: 5, isClosed: true, opensAt: '10:00', closesAt: '20:00' },
  { weekday: 6, isClosed: false, opensAt: '10:00', closesAt: '20:00' },
];

/**
 * The directory, and a salon's own management of itself.
 *
 * Appointments live next door in `AppointmentsService`: booking is the one
 * part of this feature with an invariant worth isolating, and mixing it into
 * the CRUD would bury it.
 *
 * ## Who may own a salon
 *
 * A `SELLER` — the same vetted account a boutique belongs to. There is no
 * `SALON` role, and that is the central integration decision of this feature:
 * the role enum is read by every guard, the permission matrix, the admin
 * console and the client's navigation map, and adding a value to it would
 * touch all four in order to say something SELLER already says. A woman who
 * runs a salon applies through the seller verification that exists.
 *
 * She is still a customer everywhere else. Owning a salon adds a workspace; it
 * takes nothing away.
 */
@Injectable()
export class SalonsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rates: ExchangeRateService,
  ) {}

  // ── The directory ────────────────────────────────────────────────────────

  async list(query: SalonQueryDto) {
    const where = await this.directoryWhere(query);

    const [rows, total] = await Promise.all([
      this.prisma.salon.findMany({
        where,
        orderBy: this.orderFor(query.sort),
        skip: query.skip,
        take: query.limit,
        include: {
          // Only what a card prints: the live menu's prices, for «من …».
          services: {
            where: { isActive: true },
            select: { price: true, currency: true },
          },
        },
      }),
      this.prisma.salon.count({ where }),
    ]);

    return {
      data: rows.map((salon) => serializeSalonCard(salon)),
      pagination: buildMeta(query.page, query.limit, total, rows.length),
    };
  }

  /**
   * One salon's page.
   *
   * Its own owner sees it in any state — she has to be able to look at a draft
   * she is still filling in. Everybody else sees only a live one, and a
   * suspended salon is 404 to a shopper rather than a page explaining that it
   * has been suspended.
   */
  async detail(idOrSlug: string, viewerId?: string) {
    const salon = await this.prisma.salon.findFirst({
      where: this.isUuid(idOrSlug) ? { id: idOrSlug } : { slug: idOrSlug },
      include: {
        owner: true,
        media: { orderBy: { sortOrder: 'asc' } },
        services: {
          where: { isActive: true },
          orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        },
        hours: { orderBy: { weekday: 'asc' } },
        closures: {
          where: { date: { gte: new Date(Date.now() - 86_400_000) } },
          orderBy: { date: 'asc' },
        },
      },
    });

    if (!salon) throw new NotFoundException('Salon not found');
    if (salon.status !== SalonStatus.ACTIVE && salon.ownerId !== viewerId) {
      throw new NotFoundException('Salon not found');
    }
    return serializeSalon(salon);
  }

  async reviews(salonId: string, page: number, limit: number) {
    const where = {
      salonId,
      status: ReviewStatus.APPROVED,
    } satisfies Prisma.SalonReviewWhereInput;

    const [rows, total] = await Promise.all([
      this.prisma.salonReview.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: { user: true },
      }),
      this.prisma.salonReview.count({ where }),
    ]);

    return {
      data: rows.map(serializeSalonReview),
      pagination: buildMeta(page, limit, total, rows.length),
    };
  }

  /**
   * The filter sheet's vocabulary, with live counts.
   *
   * Counts rather than a bare list, because a filter that returns nothing is a
   * filter that should not have been offered — and in a young directory most
   * of them will be empty for a while.
   */
  async categories() {
    const rows = await this.prisma.salonService.groupBy({
      by: ['category'],
      where: { isActive: true, salon: { status: SalonStatus.ACTIVE } },
      _count: { _all: true },
    });
    const counts = new Map(rows.map((row) => [row.category, row._count._all]));
    return {
      categories: SALON_CATEGORIES.map((category) => ({
        key: category,
        services_count: counts.get(category) ?? 0,
      })),
    };
  }

  /** The localities the directory actually has salons in. */
  async areas() {
    const rows = await this.prisma.salon.groupBy({
      by: ['governorate', 'city'],
      where: { status: SalonStatus.ACTIVE },
      _count: { _all: true },
      orderBy: { _count: { governorate: 'desc' } },
    });
    return {
      areas: rows.map((row) => ({
        governorate: row.governorate,
        city: row.city,
        salons_count: row._count._all,
      })),
    };
  }

  // ── Owning one ───────────────────────────────────────────────────────────

  /** Her salon, or null. The workspace asks this before drawing anything. */
  async mine(ownerId: string) {
    const salon = await this.prisma.salon.findFirst({
      where: { ownerId },
      include: {
        owner: true,
        media: { orderBy: { sortOrder: 'asc' } },
        services: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
        hours: { orderBy: { weekday: 'asc' } },
        closures: { orderBy: { date: 'asc' } },
      },
    });
    return salon ? serializeSalon(salon) : null;
  }

  /**
   * Create or update her salon.
   *
   * One per account in this release. A chain with three branches is a real
   * business — and it is also three calendars, three menus and a staff model
   * this feature does not have yet, so the honest answer today is one.
   */
  async upsert(user: AuthUser, dto: UpsertSalonDto) {
    this.assertMayOwn(user);

    const existing = await this.prisma.salon.findFirst({
      where: { ownerId: user.id },
      select: { id: true },
    });

    const data = {
      name: dto.name.trim(),
      tagline: dto.tagline?.trim() || null,
      about: dto.about?.trim() || null,
      governorate: dto.governorate.trim(),
      city: dto.city.trim(),
      district: dto.district?.trim() || null,
      addressLine: dto.address_line.trim(),
      landmark: dto.landmark?.trim() || null,
      latitude: dto.latitude ?? null,
      longitude: dto.longitude ?? null,
      phone: dto.phone?.trim() || null,
      whatsapp: dto.whatsapp?.trim() || null,
      logoUrl: dto.logo_url?.trim() || null,
      coverUrl: dto.cover_url?.trim() || null,
      ...(dto.slot_minutes === undefined ? {} : { slotMinutes: dto.slot_minutes }),
      ...(dto.lead_minutes === undefined ? {} : { leadMinutes: dto.lead_minutes }),
      ...(dto.horizon_days === undefined ? {} : { horizonDays: dto.horizon_days }),
      ...(dto.concurrent_capacity === undefined
        ? {}
        : { concurrentCapacity: dto.concurrent_capacity }),
      ...(dto.cancellation_hours === undefined
        ? {}
        : { cancellationHours: dto.cancellation_hours }),
      ...(dto.home_service === undefined ? {} : { homeService: dto.home_service }),
      homeServiceFee:
        dto.home_service_fee === undefined
          ? undefined
          : new Prisma.Decimal(dto.home_service_fee),
      ...(dto.currency === undefined ? {} : { currency: dto.currency }),
      // SUSPENDED is an operator's word; a salon may move between DRAFT and
      // ACTIVE and nowhere else.
      ...(dto.status === SalonStatus.DRAFT || dto.status === SalonStatus.ACTIVE
        ? { status: dto.status }
        : {}),
    };

    if (existing) {
      const salon = await this.prisma.salon.update({
        where: { id: existing.id },
        data,
      });
      return this.mine(user.id) ?? serializeSalon(salon);
    }

    const created = await this.prisma.$transaction(async (tx) => {
      const salon = await tx.salon.create({
        data: {
          ...data,
          ownerId: user.id,
          slug: await this.uniqueSlug(tx, dto.name),
          // A new salon opens as a draft. Publishing is a decision she makes
          // once the menu and the hours are real, and a directory full of
          // empty salons is worse than a small one.
          status: data.status ?? SalonStatus.DRAFT,
        },
      });
      await tx.salonWorkingHours.createMany({
        data: DEFAULT_HOURS.map((day) => ({ ...day, salonId: salon.id })),
      });
      return salon;
    });

    return this.mine(user.id) ?? serializeSalon(created);
  }

  async upsertService(
    user: AuthUser,
    serviceId: string | null,
    dto: UpsertSalonServiceDto,
  ) {
    const salon = await this.requireOwned(user);

    const currency = dto.currency ?? salon.currency;
    const price = new Prisma.Decimal(dto.price);
    const compareAt =
      dto.compare_at_price === undefined
        ? null
        : new Prisma.Decimal(dto.compare_at_price);

    // Normalised so the directory can sort and filter a mixed-currency menu by
    // price. Same reason `SellerOffer.priceSyp` exists, and through the same
    // service, so a salon and a boutique are converted at one rate.
    const priceSyp = (await this.rates.toSyp(Money.of(price, currency)))
      .toPrisma();

    const data = {
      salonId: salon.id,
      name: dto.name.trim(),
      description: dto.description?.trim() || null,
      category: dto.category,
      price,
      currency,
      compareAtPrice: compareAt,
      priceSyp,
      durationMinutes: dto.duration_minutes,
      bufferMinutes: dto.buffer_minutes ?? 0,
      location: dto.location ?? SalonServiceLocation.IN_SALON,
      imageUrl: dto.image_url?.trim() || null,
      isPackage: dto.is_package ?? false,
      isActive: dto.is_active ?? true,
      sortOrder: dto.sort_order ?? 0,
    };

    // A service that travels needs a salon that travels, or a customer is
    // offered a home visit the salon never agreed to.
    if (
      (data.location === SalonServiceLocation.AT_HOME ||
        data.location === SalonServiceLocation.BOTH) &&
      !salon.homeService
    ) {
      throw new BadRequestException(
        'Enable home service on the salon before offering a service at home',
      );
    }

    const service = await this.prisma.$transaction(async (tx) => {
      const row = serviceId
        ? await tx.salonService.update({
            where: { id: serviceId },
            data,
          })
        : await tx.salonService.create({ data });

      if (dto.package_service_ids) {
        await tx.salonPackageItem.deleteMany({ where: { packageId: row.id } });
        const members = dto.package_service_ids.filter((id) => id !== row.id);
        if (members.length > 0) {
          // Only her own services, so a package cannot quietly cite another
          // salon's menu.
          const owned = await tx.salonService.findMany({
            where: { id: { in: members }, salonId: salon.id },
            select: { id: true },
          });
          await tx.salonPackageItem.createMany({
            data: owned.map((member, index) => ({
              packageId: row.id,
              serviceId: member.id,
              sortOrder: index,
            })),
          });
        }
      }

      await this.refreshServicesCount(tx, salon.id);
      return row;
    });

    return serializeSalonService(service);
  }

  /**
   * Take a service off the menu.
   *
   * Deactivation, never deletion: the foreign key from `appointments` is
   * `RESTRICT`, because a booking must keep pointing at the thing it was
   * booked for. A woman's Thursday does not disappear because the salon
   * reorganised its price list on Tuesday.
   */
  async deactivateService(user: AuthUser, serviceId: string) {
    const salon = await this.requireOwned(user);
    const service = await this.prisma.salonService.findFirst({
      where: { id: serviceId, salonId: salon.id },
      select: { id: true },
    });
    if (!service) throw new NotFoundException('Service not found');

    await this.prisma.$transaction(async (tx) => {
      await tx.salonService.update({
        where: { id: service.id },
        data: { isActive: false },
      });
      await this.refreshServicesCount(tx, salon.id);
    });
    return { id: service.id, is_active: false };
  }

  /** The whole week at once. A partial timetable update is how a salon ends up
   * open on a day it meant to close. */
  async setHours(user: AuthUser, dto: SetWorkingHoursDto) {
    const salon = await this.requireOwned(user);

    const seen = new Set<number>();
    for (const day of dto.days) {
      if (seen.has(day.weekday)) {
        throw new BadRequestException(`Weekday ${day.weekday} listed twice`);
      }
      seen.add(day.weekday);
      if (!day.is_closed && day.closes_at <= day.opens_at) {
        throw new BadRequestException(
          `Weekday ${day.weekday} closes before it opens`,
        );
      }
    }

    await this.prisma.$transaction(async (tx) => {
      for (const day of dto.days) {
        await tx.salonWorkingHours.upsert({
          where: {
            salonId_weekday: { salonId: salon.id, weekday: day.weekday },
          },
          create: {
            salonId: salon.id,
            weekday: day.weekday,
            isClosed: day.is_closed ?? false,
            opensAt: day.opens_at,
            closesAt: day.closes_at,
            breakStartsAt: day.break_starts_at ?? null,
            breakEndsAt: day.break_ends_at ?? null,
          },
          update: {
            isClosed: day.is_closed ?? false,
            opensAt: day.opens_at,
            closesAt: day.closes_at,
            breakStartsAt: day.break_starts_at ?? null,
            breakEndsAt: day.break_ends_at ?? null,
          },
        });
      }
    });

    return this.mine(user.id);
  }

  async addClosure(user: AuthUser, dto: CreateClosureDto) {
    const salon = await this.requireOwned(user);
    const date = new Date(`${dto.date}T00:00:00.000Z`);
    await this.prisma.salonClosure.upsert({
      where: { salonId_date: { salonId: salon.id, date } },
      create: { salonId: salon.id, date, reason: dto.reason?.trim() || null },
      update: { reason: dto.reason?.trim() || null },
    });
    return { date: dto.date, reason: dto.reason ?? null };
  }

  async removeClosure(user: AuthUser, date: string) {
    const salon = await this.requireOwned(user);
    await this.prisma.salonClosure.deleteMany({
      where: { salonId: salon.id, date: new Date(`${date}T00:00:00.000Z`) },
    });
    return { date, removed: true };
  }

  /** The salon's answer under a review. At most one, edited in place. */
  async replyToReview(user: AuthUser, reviewId: string, dto: ReplyToReviewDto) {
    const salon = await this.requireOwned(user);
    const review = await this.prisma.salonReview.findFirst({
      where: { id: reviewId, salonId: salon.id },
      select: { id: true },
    });
    if (!review) throw new NotFoundException('Review not found');

    const updated = await this.prisma.salonReview.update({
      where: { id: review.id },
      data: { salonReply: dto.body.trim(), salonRepliedAt: new Date() },
      include: { user: true },
    });
    return serializeSalonReview(updated);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /**
   * The salon this account owns, or a refusal.
   *
   * Every owner-side write goes through here, so ownership is checked once
   * rather than in each of the nine handlers that need it.
   */
  async requireOwned(user: AuthUser) {
    const salon = await this.prisma.salon.findFirst({
      where: { ownerId: user.id },
    });
    if (!salon) {
      throw new NotFoundException('You do not have a salon yet');
    }
    return salon;
  }

  private assertMayOwn(user: AuthUser) {
    // A seller, or staff acting on her behalf. Deliberately not "anybody with
    // an account": a salon in the directory is a business the platform is
    // answerable for, and seller verification is the process that vets one.
    const allowed: UserRole[] = [
      UserRole.SELLER,
      UserRole.ADMIN,
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
    ];
    if (!allowed.includes(user.role)) {
      throw new ForbiddenException(
        'Apply to sell on Reem before opening a salon',
      );
    }
  }

  private async refreshServicesCount(
    tx: Prisma.TransactionClient,
    salonId: string,
  ) {
    const servicesCount = await tx.salonService.count({
      where: { salonId, isActive: true },
    });
    await tx.salon.update({ where: { id: salonId }, data: { servicesCount } });
  }

  private orderFor(sort?: string): Prisma.SalonOrderByWithRelationInput[] {
    switch (sort) {
      case 'reviews':
        return [{ reviewsCount: 'desc' }, { rating: 'desc' }];
      case 'newest':
        return [{ createdAt: 'desc' }];
      default:
        // Featured first, then the best reviewed. A salon with no reviews yet
        // sorts under one with them, which is the honest order for a directory
        // whose whole purpose is trust.
        return [
          { isFeatured: 'desc' },
          { rating: 'desc' },
          { reviewsCount: 'desc' },
        ];
    }
  }

  private async directoryWhere(
    query: SalonQueryDto,
  ): Promise<Prisma.SalonWhereInput> {
    const and: Prisma.SalonWhereInput[] = [{ status: SalonStatus.ACTIVE }];

    if (query.governorate) and.push({ governorate: query.governorate });
    if (query.city) and.push({ city: query.city });
    if (query.home_service) and.push({ homeService: true });
    if (query.min_rating !== undefined) {
      and.push({ rating: { gte: query.min_rating } });
    }

    // Every service filter is a relation filter on the *same* service, not on
    // the salon: "a nail service under 50,000" must be one service that is
    // both, and splitting them across two `some` clauses would match a salon
    // with expensive nails and a cheap haircut.
    const service: Prisma.SalonServiceWhereInput = { isActive: true };
    let hasServiceFilter = false;
    if (query.category) {
      service.category = query.category;
      hasServiceFilter = true;
    }
    if (query.min_price !== undefined || query.max_price !== undefined) {
      service.priceSyp = {
        ...(query.min_price !== undefined ? { gte: query.min_price } : {}),
        ...(query.max_price !== undefined ? { lte: query.max_price } : {}),
      };
      hasServiceFilter = true;
    }
    if (hasServiceFilter) and.push({ services: { some: service } });

    if (query.q?.trim()) {
      const term = query.q.trim();
      // Folded and transliterated, so «صالون» and «صالون» with a different
      // hamza match — the same key `reem_search_key` builds for the catalogue.
      // Matched in JavaScript against the same helper rather than in SQL,
      // because the directory is small and a raw query here would need the
      // function to exist on every database this runs against.
      const folded = searchKey(term);
      and.push({
        OR: [
          { name: { contains: term, mode: 'insensitive' } },
          { tagline: { contains: term, mode: 'insensitive' } },
          { city: { contains: term, mode: 'insensitive' } },
          { governorate: { contains: term, mode: 'insensitive' } },
          { services: { some: { name: { contains: term, mode: 'insensitive' } } } },
          ...(folded && folded !== term.toLowerCase()
            ? [{ name: { contains: folded, mode: 'insensitive' as const } }]
            : []),
        ],
      });
    }

    return { AND: and };
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    );
  }

  /**
   * A readable, stable, unique slug.
   *
   * Arabic names transliterate through the same helper the catalogue search
   * uses, so «صالون لمى» becomes `salwn-lma` rather than a row of percent
   * escapes in a shared link.
   */
  private async uniqueSlug(
    tx: Prisma.TransactionClient,
    name: string,
  ): Promise<string> {
    const base =
      searchKey(name)
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 40) || 'salon';

    for (let attempt = 0; attempt < 50; attempt += 1) {
      const candidate = attempt === 0 ? base : `${base}-${attempt + 1}`;
      const clash = await tx.salon.findUnique({
        where: { slug: candidate },
        select: { id: true },
      });
      if (!clash) return candidate;
    }
    // Fifty salons called the same thing is not a case worth a nicer answer.
    return `${base}-${Date.now().toString(36)}`;
  }
}

/** The filter vocabulary, in the order the sheet draws it. */
export const SALON_CATEGORIES = [
  'HAIR',
  'NAILS',
  'SKIN',
  'MAKEUP',
  'LASHES_BROWS',
  'HAIR_REMOVAL',
  'MASSAGE_SPA',
  'BRIDAL',
  'OTHER',
] as const;
