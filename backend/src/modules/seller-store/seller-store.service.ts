import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  OfferStatus,
  Prisma,
  SellerStoreSettings,
  StoreTeamRole,
  StoreTeamStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { RETURN_WINDOW_DAYS } from '../returns/return-policy';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ActivityQueryDto,
  InviteTeamMemberDto,
  UpdateShippingSettingsDto,
  UpdateStorePoliciesDto,
} from './dto/seller-store.dto';

/** The shop's settings, or the defaults when she has never saved any. */
type Settings = Omit<SellerStoreSettings, 'id' | 'sellerId' | 'createdAt'>;

const DEFAULTS: Settings = {
  acceptsExchanges: true,
  exchangeNote: null,
  returnNote: null,
  careNote: null,
  customOrderNote: null,
  policiesUpdatedAt: null,
  shipsFromGovernorate: null,
  shipsFromArea: null,
  defaultHandlingDays: 1,
  offersPickup: false,
  pickupAddress: null,
  pickupHours: null,
  packagingNote: null,
  shippingUpdatedAt: null,
  updatedAt: new Date(0),
};

const TEAM_LIMIT = 10;

const ROLE_LABEL: Record<StoreTeamRole, string> = {
  [StoreTeamRole.MANAGER]: 'مديرة',
  [StoreTeamRole.ORDERS]: 'الطلبات',
  [StoreTeamRole.CATALOG]: 'المنتجات',
};

/**
 * The owner's side of the shop that is not selling: «سياسات المتجر»,
 * «إعدادات الشحن», «إدارة الفريق» and «سجل النشاط».
 */
@Injectable()
export class SellerStoreService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // ── Policies and shipping ───────────────────────────────────────────────

  private async settings(sellerId: string): Promise<Settings> {
    const row = await this.prisma.sellerStoreSettings.findUnique({
      where: { sellerId },
    });
    return row ?? DEFAULTS;
  }

  async policies(sellerId: string) {
    return serializePolicies(await this.settings(sellerId));
  }

  async updatePolicies(sellerId: string, dto: UpdateStorePoliciesDto) {
    const data: Prisma.SellerStoreSettingsUpdateInput = {
      ...(dto.accepts_exchanges !== undefined && {
        acceptsExchanges: dto.accepts_exchanges,
      }),
      ...(dto.exchange_note !== undefined && { exchangeNote: dto.exchange_note }),
      ...(dto.return_note !== undefined && { returnNote: dto.return_note }),
      ...(dto.care_note !== undefined && { careNote: dto.care_note }),
      ...(dto.custom_order_note !== undefined && {
        customOrderNote: dto.custom_order_note,
      }),
      policiesUpdatedAt: new Date(),
    };
    const saved = await this.prisma.sellerStoreSettings.upsert({
      where: { sellerId },
      create: { sellerId, ...(data as Prisma.SellerStoreSettingsCreateWithoutSellerInput) },
      update: data,
    });
    return serializePolicies(saved);
  }

  async shipping(sellerId: string) {
    const [settings, zones] = await Promise.all([
      this.settings(sellerId),
      this.zones(),
    ]);
    return { ...serializeShipping(settings), platform_rates: zones };
  }

  async updateShipping(sellerId: string, dto: UpdateShippingSettingsDto) {
    if (dto.offers_pickup === true && dto.pickup_address === null) {
      throw new BadRequestException('اكتبي عنوان الاستلام من المحل');
    }
    const data: Prisma.SellerStoreSettingsUpdateInput = {
      ...(dto.ships_from_governorate !== undefined && {
        shipsFromGovernorate: dto.ships_from_governorate,
      }),
      ...(dto.ships_from_area !== undefined && {
        shipsFromArea: dto.ships_from_area,
      }),
      ...(dto.default_handling_days !== undefined && {
        defaultHandlingDays: dto.default_handling_days,
      }),
      ...(dto.offers_pickup !== undefined && { offersPickup: dto.offers_pickup }),
      ...(dto.pickup_address !== undefined && {
        pickupAddress: dto.pickup_address,
      }),
      ...(dto.pickup_hours !== undefined && { pickupHours: dto.pickup_hours }),
      ...(dto.packaging_note !== undefined && {
        packagingNote: dto.packaging_note,
      }),
      shippingUpdatedAt: new Date(),
    };

    const saved = await this.prisma.$transaction(async (tx) => {
      const row = await tx.sellerStoreSettings.upsert({
        where: { sellerId },
        create: {
          sellerId,
          ...(data as Prisma.SellerStoreSettingsCreateWithoutSellerInput),
        },
        update: data,
      });
      if (row.offersPickup && !row.pickupAddress) {
        throw new BadRequestException('اكتبي عنوان الاستلام من المحل');
      }
      // «طبّقيها على كل منتجاتي»: the new preparation time on every listing
      // she has, not only the ones she adds from now on.
      let updatedListings = 0;
      if (dto.apply_to_listings && dto.default_handling_days !== undefined) {
        const result = await tx.sellerOffer.updateMany({
          where: { sellerId, status: { not: OfferStatus.ARCHIVED } },
          data: { handlingDays: dto.default_handling_days },
        });
        updatedListings = result.count;
      }
      return { row, updatedListings };
    });

    return {
      ...serializeShipping(saved.row),
      platform_rates: await this.zones(),
      updated_listings: saved.updatedListings,
    };
  }

  /** The preparation time a new listing starts with. */
  async defaultHandlingDays(sellerId: string): Promise<number> {
    const row = await this.prisma.sellerStoreSettings.findUnique({
      where: { sellerId },
      select: { defaultHandlingDays: true },
    });
    return row?.defaultHandlingDays ?? 1;
  }

  /** What a shopper reads about the shop: policies and how it ships. */
  async publicInfo(sellerId: string) {
    const seller = await this.prisma.user.findFirst({
      where: { id: sellerId, role: UserRole.SELLER },
      select: { id: true },
    });
    if (!seller) throw new NotFoundException('المتجر غير موجود');
    const settings = await this.settings(sellerId);
    const shipping = serializeShipping(settings);
    return {
      policies: serializePolicies(settings),
      shipping: {
        ships_from_governorate: shipping.ships_from_governorate,
        ships_from_area: shipping.ships_from_area,
        default_handling_days: shipping.default_handling_days,
        offers_pickup: shipping.offers_pickup,
        pickup_address: shipping.offers_pickup ? shipping.pickup_address : null,
        pickup_hours: shipping.offers_pickup ? shipping.pickup_hours : null,
        packaging_note: shipping.packaging_note,
      },
    };
  }

  private async zones() {
    const rows = await this.prisma.shippingZone.findMany({
      where: { isActive: true, district: null },
      orderBy: [{ baseFee: 'asc' }, { governorate: 'asc' }],
    });
    return rows.map((zone) => ({
      governorate: zone.governorate,
      is_rural: zone.isRural,
      fee: Money.of(zone.baseFee, zone.currency ?? Currency.SYP).toJSON(),
      eta_hours_min: zone.etaHoursMin,
      eta_hours_max: zone.etaHoursMax,
    }));
  }

  // ── Team ────────────────────────────────────────────────────────────────

  async team(storeId: string) {
    const rows = await this.prisma.sellerTeamMember.findMany({
      where: { storeId, status: { not: StoreTeamStatus.REMOVED } },
      orderBy: [{ status: 'asc' }, { invitedAt: 'desc' }],
      include: {
        member: { select: { id: true, name: true, username: true, imageUrl: true, phone: true } },
      },
    });
    return rows.map((row) => ({
      id: row.id,
      role: row.role.toLowerCase(),
      status: row.status.toLowerCase(),
      invited_at: row.invitedAt.toISOString(),
      accepted_at: row.acceptedAt?.toISOString() ?? null,
      member: {
        id: row.member.id,
        name: row.member.name,
        username: row.member.username,
        image_url: row.member.imageUrl,
        phone: row.member.phone,
      },
    }));
  }

  async invite(storeId: string, dto: InviteTeamMemberDto) {
    const member = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
      select: { id: true, role: true, deletedAt: true },
    });
    if (!member || member.deletedAt) {
      throw new NotFoundException({
        code: 'NO_ACCOUNT',
        message:
          'ما في حساب على هالرقم. اطلبي منها تسجّل بالتطبيق أولاً وبعدين ادعيها.',
      });
    }
    if (member.id === storeId) {
      throw new BadRequestException('هاد رقمكِ أنتِ — ادعي حدا تاني');
    }
    if (member.role !== UserRole.CUSTOMER) {
      throw new BadRequestException(
        'هالحساب متجر أو حساب إدارة — الفريق بيكون من حسابات شخصية',
      );
    }

    const active = await this.prisma.sellerTeamMember.count({
      where: { storeId, status: { not: StoreTeamStatus.REMOVED } },
    });
    const existing = await this.prisma.sellerTeamMember.findUnique({
      where: { storeId_memberId: { storeId, memberId: member.id } },
    });
    if (existing && existing.status !== StoreTeamStatus.REMOVED) {
      throw new ConflictException('هي بالفريق أو عندها دعوة من قبل');
    }
    if (active >= TEAM_LIMIT) {
      throw new BadRequestException(`الحد الأقصى للفريق ${TEAM_LIMIT} أعضاء`);
    }

    const row = existing
      ? await this.prisma.sellerTeamMember.update({
          where: { id: existing.id },
          data: {
            role: dto.role,
            status: StoreTeamStatus.INVITED,
            invitedAt: new Date(),
            acceptedAt: null,
            removedAt: null,
          },
        })
      : await this.prisma.sellerTeamMember.create({
          data: { storeId, memberId: member.id, role: dto.role },
        });

    const store = await this.storeName(storeId);
    await this.notifications.notifyAccount({
      userId: member.id,
      title: `دعوة للانضمام لفريق ${store}`,
      body: `${store} بدها ياكِ بفريقها (${ROLE_LABEL[dto.role]}). افتحي «متاجر بشتغل فيها» لتقبلي.`,
      data: {
        kind: 'store_team_invite',
        store_id: storeId,
        membership_id: row.id,
        deep_link: 'reem://store-memberships',
      },
    });

    return (await this.team(storeId)).find((m) => m.id === row.id);
  }

  async changeRole(storeId: string, id: string, role: StoreTeamRole) {
    const row = await this.ownRow(storeId, id);
    await this.prisma.sellerTeamMember.update({
      where: { id: row.id },
      data: { role },
    });
    return (await this.team(storeId)).find((m) => m.id === row.id);
  }

  async remove(storeId: string, id: string) {
    const row = await this.ownRow(storeId, id);
    await this.prisma.sellerTeamMember.update({
      where: { id: row.id },
      data: { status: StoreTeamStatus.REMOVED, removedAt: new Date() },
    });
    if (row.status === StoreTeamStatus.ACTIVE) {
      const store = await this.storeName(storeId);
      await this.notifications.notifyAccount({
        userId: row.memberId,
        title: `ما عدتِ بفريق ${store}`,
        body: 'انشال وصولكِ لهالمتجر.',
        data: {
          kind: 'store_team_removed',
          store_id: storeId,
          deep_link: 'reem://store-memberships',
        },
      });
    }
    return { removed: true };
  }

  private async ownRow(storeId: string, id: string) {
    const row = await this.prisma.sellerTeamMember.findUnique({ where: { id } });
    if (!row || row.storeId !== storeId || row.status === StoreTeamStatus.REMOVED) {
      throw new NotFoundException('العضوة غير موجودة بالفريق');
    }
    return row;
  }

  private async storeName(storeId: string) {
    const store = await this.prisma.user.findUnique({
      where: { id: storeId },
      select: { name: true },
    });
    return store?.name ?? 'متجر';
  }

  // ── Her memberships, from the member's side ─────────────────────────────

  async memberships(memberId: string) {
    const rows = await this.prisma.sellerTeamMember.findMany({
      where: {
        memberId,
        status: { in: [StoreTeamStatus.INVITED, StoreTeamStatus.ACTIVE] },
      },
      orderBy: { invitedAt: 'desc' },
      include: {
        store: { select: { id: true, name: true, username: true, imageUrl: true } },
      },
    });
    return rows.map((row) => ({
      id: row.id,
      role: row.role.toLowerCase(),
      status: row.status.toLowerCase(),
      invited_at: row.invitedAt.toISOString(),
      store: {
        id: row.store.id,
        name: row.store.name,
        username: row.store.username,
        image_url: row.store.imageUrl,
      },
    }));
  }

  async respond(memberId: string, id: string, accept: boolean) {
    const row = await this.prisma.sellerTeamMember.findUnique({ where: { id } });
    if (!row || row.memberId !== memberId || row.status !== StoreTeamStatus.INVITED) {
      throw new NotFoundException('الدعوة غير موجودة أو انتهت');
    }
    await this.prisma.sellerTeamMember.update({
      where: { id },
      data: accept
        ? { status: StoreTeamStatus.ACTIVE, acceptedAt: new Date() }
        : { status: StoreTeamStatus.REMOVED, removedAt: new Date() },
    });
    return this.memberships(memberId);
  }

  async leave(memberId: string, id: string) {
    const row = await this.prisma.sellerTeamMember.findUnique({ where: { id } });
    if (!row || row.memberId !== memberId || row.status === StoreTeamStatus.REMOVED) {
      throw new NotFoundException('ما إنتِ بهالفريق');
    }
    await this.prisma.sellerTeamMember.update({
      where: { id },
      data: { status: StoreTeamStatus.REMOVED, removedAt: new Date() },
    });
    return this.memberships(memberId);
  }

  // ── Activity ────────────────────────────────────────────────────────────

  /**
   * «سجل النشاط» — what was done on the shop and by whom: her own sign-ins
   * and money actions, and every change she or her team made to the shop.
   */
  async activity(storeId: string, query: ActivityQueryDto) {
    const take = query.limit ?? 30;
    const before = query.before ? new Date(query.before) : undefined;
    const rows = await this.prisma.auditLog.findMany({
      where: {
        AND: [
          {
            OR: [
              { actorId: storeId },
              { metadata: { path: ['store_id'], equals: storeId } },
            ],
          },
          before ? { createdAt: { lt: before } } : {},
          // The money trail writes its own detailed entry for the same
          // request the shop's trail already recorded; one line per act.
          { category: { not: 'finance' } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      include: { actor: { select: { id: true, name: true } } },
    });
    const page = rows.slice(0, take);
    return {
      data: page.map((row) => {
        const metadata = (row.metadata ?? {}) as Record<string, unknown>;
        return {
          id: row.id,
          action: row.action,
          category: row.category,
          outcome: row.outcome,
          severity: row.severity.toLowerCase(),
          target_type: row.targetType,
          target_id: row.targetId,
          actor: row.actor
            ? { id: row.actor.id, name: row.actor.name, is_owner: row.actor.id === storeId }
            : null,
          device: deviceOf(row.userAgent),
          created_at: row.createdAt.toISOString(),
          via_team: metadata['store_id'] === storeId && row.actorId !== storeId,
        };
      }),
      has_more: rows.length > take,
      next_before: page.length ? page[page.length - 1].createdAt.toISOString() : null,
    };
  }
}

function serializePolicies(settings: Settings) {
  return {
    /// The platform's guarantee; a shop adds to it, never below it.
    platform_return_days: RETURN_WINDOW_DAYS,
    accepts_exchanges: settings.acceptsExchanges,
    exchange_note: settings.exchangeNote,
    return_note: settings.returnNote,
    care_note: settings.careNote,
    custom_order_note: settings.customOrderNote,
    updated_at: settings.policiesUpdatedAt?.toISOString() ?? null,
  };
}

function serializeShipping(settings: Settings) {
  return {
    ships_from_governorate: settings.shipsFromGovernorate,
    ships_from_area: settings.shipsFromArea,
    default_handling_days: settings.defaultHandlingDays,
    offers_pickup: settings.offersPickup,
    pickup_address: settings.pickupAddress,
    pickup_hours: settings.pickupHours,
    packaging_note: settings.packagingNote,
    updated_at: settings.shippingUpdatedAt?.toISOString() ?? null,
  };
}

/** «آيفون», «أندرويد», «متصفح» — enough to recognise a device, no more. */
function deviceOf(userAgent: string | null): string | null {
  if (!userAgent) return null;
  const ua = userAgent.toLowerCase();
  if (ua.includes('iphone') || ua.includes('ios')) return 'ios';
  if (ua.includes('android')) return 'android';
  if (ua.includes('dart')) return 'app';
  return 'web';
}
