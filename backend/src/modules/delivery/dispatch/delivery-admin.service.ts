import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DeliveryProviderAccount, DeliveryProviderKind, Prisma } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { buildMeta } from '../../../common/dto/pagination.dto';
import { Money } from '../../../common/money';
import { DeliveryProviderRegistry } from '../providers/delivery-provider.registry';
import { ProviderCredentialsService } from '../providers/provider-credentials.service';
import {
  CreateDeliveryProviderDto,
  DispatchQueryDto,
  UpdateDeliveryProviderDto,
} from '../dto/delivery-provider.dto';

/** Keys that would be a secret if somebody pasted one into `config`. */
const SECRET_SHAPED = /(secret|token|password|api[_-]?key|private)/i;

/**
 * Carrier administration.
 *
 * The point of this service is that changing carrier is an operations act, not
 * a deployment: enabling a company, taking one out of a governorate it can no
 * longer serve, changing which one wins a tie, or turning everything off
 * during an incident are all rows. What it deliberately does **not** allow is
 * writing a credential into the database — `config` is refused if it looks
 * like it carries one, and the only thing an admin can say about a secret is
 * which environment variable holds it.
 */
@Injectable()
export class DeliveryAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: DeliveryProviderRegistry,
    private readonly credentials: ProviderCredentialsService,
  ) {}

  /** Adapters this build can serve — what an admin may choose between. */
  adapters() {
    return this.registry.list().map((provider) => ({
      code: provider.code,
      display_name: provider.displayName,
    }));
  }

  async list() {
    const accounts = await this.prisma.deliveryProviderAccount.findMany({
      orderBy: [{ priority: 'asc' }, { displayName: 'asc' }],
    });
    return accounts.map((account) => this.serialize(account));
  }

  async create(dto: CreateDeliveryProviderDto) {
    this.assertAdapter(dto.adapter ?? dto.code);
    this.assertNoSecrets(dto.config);

    const existing = await this.prisma.deliveryProviderAccount.findUnique({
      where: { code: dto.code },
    });
    if (existing) {
      throw new BadRequestException('A carrier with that code already exists');
    }

    const account = await this.prisma.deliveryProviderAccount.create({
      data: this.writeData(dto),
    });
    if (dto.is_default) await this.clearOtherDefaults(account.id);
    return this.serialize(account);
  }

  async update(id: string, dto: UpdateDeliveryProviderDto) {
    const current = await this.require(id);
    if (dto.adapter && dto.adapter !== current.adapter) this.assertAdapter(dto.adapter);
    this.assertNoSecrets(dto.config);

    const account = await this.prisma.deliveryProviderAccount.update({
      where: { id },
      data: this.writeData(dto, current),
    });
    if (dto.is_default) await this.clearOtherDefaults(account.id);
    return this.serialize(account);
  }

  /**
   * Turning a carrier on or off.
   *
   * Enabling is refused for an account the platform cannot actually reach —
   * an adapter that needs a base URL and has none, or a webhook-verified
   * carrier whose signing secret is not in the environment. A carrier that is
   * "on" and silently undispatchable is worse than one that is off, because
   * every parcel routed to it stops.
   */
  async setEnabled(id: string, enabled: boolean) {
    const account = await this.require(id);
    if (enabled) this.assertDispatchable(account);

    const updated = await this.prisma.deliveryProviderAccount.update({
      where: { id },
      data: { isEnabled: enabled },
    });
    return this.serialize(updated);
  }

  async remove(id: string) {
    const account = await this.require(id);
    const inFlight = await this.prisma.deliveryDispatch.count({
      where: {
        providerId: account.id,
        status: { notIn: ['DELIVERED', 'RETURNED', 'CANCELLED'] },
      },
    });
    if (inFlight > 0) {
      throw new BadRequestException(
        `${inFlight} parcel(s) are still with this carrier — disable it instead of deleting it`,
      );
    }
    await this.prisma.deliveryProviderAccount.delete({ where: { id } });
    return { deleted: true };
  }

  /** The ops queue: what is with a carrier, and what never got there. */
  async dispatches(query: DispatchQueryDto) {
    const where: Prisma.DeliveryDispatchWhereInput = {
      ...(query.provider ? { providerCode: query.provider } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.failed_only ? { externalDeliveryId: null, lastError: { not: null } } : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.deliveryDispatch.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.limit,
        include: {
          provider: { select: { displayName: true } },
          shipment: {
            select: {
              trackingCode: true,
              status: true,
              sellerOrder: { select: { number: true } },
            },
          },
        },
      }),
      this.prisma.deliveryDispatch.count({ where }),
    ]);

    return {
      data: rows.map((row) => ({
        id: row.id,
        provider: row.provider.displayName,
        provider_code: row.providerCode,
        order_number: row.shipment.sellerOrder.number,
        tracking_code: row.shipment.trackingCode,
        shipment_status: row.shipment.status.toLowerCase(),
        status: row.status.toLowerCase(),
        provider_status: row.providerStatus,
        external_delivery_id: row.externalDeliveryId,
        tracking_number: row.trackingNumber,
        fee:
          row.feeAmount && row.feeCurrency
            ? Money.of(row.feeAmount, row.feeCurrency).toJSON()
            : null,
        last_error: row.lastError,
        attempt_count: row.attemptCount,
        created_at: row.createdAt,
        delivered_at: row.deliveredAt,
      })),
      meta: buildMeta(query.page, query.limit, total, rows.length),
    };
  }

  /** The callbacks a carrier made about one parcel. */
  async events(dispatchId: string) {
    const rows = await this.prisma.deliveryWebhookEvent.findMany({
      where: { dispatchId },
      orderBy: { receivedAt: 'desc' },
      take: 50,
    });
    return rows.map((row) => ({
      id: row.id,
      status: row.status?.toLowerCase() ?? null,
      provider_status: row.providerStatus,
      signature_valid: row.signatureValid,
      error: row.error,
      received_at: row.receivedAt,
      processed_at: row.processedAt,
    }));
  }

  // ── internals ─────────────────────────────────────────────────────────

  private async require(id: string): Promise<DeliveryProviderAccount> {
    const account = await this.prisma.deliveryProviderAccount.findUnique({
      where: { id },
    });
    if (!account) throw new NotFoundException('Delivery provider not found');
    return account;
  }

  private assertAdapter(code: string): void {
    if (!this.registry.has(code)) {
      throw new BadRequestException(
        `This build has no adapter called "${code}". Available: ${this.registry
          .list()
          .map((provider) => provider.code)
          .join(', ')}`,
      );
    }
  }

  private assertNoSecrets(config?: Record<string, unknown> | null): void {
    if (!config) return;
    const offender = Object.keys(config).find((key) => SECRET_SHAPED.test(key));
    if (offender) {
      throw new BadRequestException(
        `"${offender}" looks like a credential. Put the value in an environment variable and name it in credential_env_keys.`,
      );
    }
  }

  private assertDispatchable(account: DeliveryProviderAccount): void {
    if (account.kind === DeliveryProviderKind.EXTERNAL_API) {
      const config = (account.config ?? {}) as { baseUrl?: string };
      if (!config.baseUrl) {
        throw new BadRequestException(
          'This carrier has no baseUrl in its config — it cannot be dispatched to yet',
        );
      }
      const credentials = this.credentials.resolve(account);
      if (!credentials.apiKey) {
        throw new BadRequestException(
          'This carrier has no API key in the environment — set it before enabling',
        );
      }
    }
    if (account.supportsWebhook && account.webhookAuth !== 'NONE') {
      const credentials = this.credentials.resolve(account);
      if (!credentials.webhookSecret) {
        throw new BadRequestException(
          'This carrier verifies callbacks but its signing secret is not in the environment',
        );
      }
    }
  }

  private async clearOtherDefaults(id: string): Promise<void> {
    await this.prisma.deliveryProviderAccount.updateMany({
      where: { id: { not: id }, isDefault: true },
      data: { isDefault: false },
    });
  }

  private writeData(
    dto: CreateDeliveryProviderDto | UpdateDeliveryProviderDto,
    current?: DeliveryProviderAccount,
  ): Prisma.DeliveryProviderAccountUncheckedCreateInput {
    return {
      code: dto.code ?? current?.code ?? '',
      // An account with no adapter named serves itself: the common case is a
      // code that *is* an adapter ("internal"), and anything else must say
      // which adapter speaks for it.
      adapter: dto.adapter ?? current?.adapter ?? dto.code ?? '',
      displayName: dto.display_name ?? current?.displayName ?? '',
      kind: dto.kind ?? current?.kind ?? DeliveryProviderKind.EXTERNAL_API,
      isEnabled: dto.is_enabled ?? current?.isEnabled ?? false,
      isDefault: dto.is_default ?? current?.isDefault ?? false,
      priority: dto.priority ?? current?.priority ?? 100,
      governorates: dto.governorates ?? current?.governorates ?? [],
      supportsQuote: dto.supports_quote ?? current?.supportsQuote ?? false,
      supportsCancel: dto.supports_cancel ?? current?.supportsCancel ?? false,
      supportsTracking: dto.supports_tracking ?? current?.supportsTracking ?? false,
      supportsWebhook: dto.supports_webhook ?? current?.supportsWebhook ?? false,
      webhookAuth: dto.webhook_auth ?? current?.webhookAuth ?? 'HMAC_SHA256',
      webhookSignatureHeader:
        dto.webhook_signature_header ?? current?.webhookSignatureHeader ?? null,
      config: (dto.config ?? current?.config ?? undefined) as Prisma.InputJsonValue,
      credentialEnvKeys: (dto.credential_env_keys ??
        current?.credentialEnvKeys ??
        undefined) as Prisma.InputJsonValue,
      courierId: dto.courier_id ?? current?.courierId ?? null,
    };
  }

  /**
   * What an admin screen may see.
   *
   * Credentials never appear — only whether each named variable is actually
   * set, which is the question ops needs answered ("is this carrier ready?")
   * without the answer being the key itself.
   */
  private serialize(account: DeliveryProviderAccount) {
    const named = (account.credentialEnvKeys ?? {}) as Record<string, string>;
    const resolved = this.credentials.resolve(account);

    return {
      id: account.id,
      code: account.code,
      adapter: account.adapter,
      display_name: account.displayName,
      kind: account.kind,
      is_enabled: account.isEnabled,
      is_default: account.isDefault,
      priority: account.priority,
      governorates: account.governorates,
      capabilities: {
        quote: account.supportsQuote,
        cancel: account.supportsCancel,
        tracking: account.supportsTracking,
        webhook: account.supportsWebhook,
      },
      webhook: {
        auth: account.webhookAuth,
        signature_header: account.webhookSignatureHeader,
        url: `/webhooks/delivery/${account.code}`,
      },
      config: account.config ?? {},
      credentials: Object.entries(named).map(([field, envKey]) => ({
        field,
        env_key: envKey,
        is_set: Boolean(resolved.extra[field]),
      })),
      adapter_available: this.registry.has(account.adapter),
      last_healthy_at: account.lastHealthyAt,
      last_error_at: account.lastErrorAt,
      last_error: account.lastError,
    };
  }
}
