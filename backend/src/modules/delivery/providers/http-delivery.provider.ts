import { Injectable, Logger } from '@nestjs/common';
import {
  Currency,
  DeliveryProviderAccount,
  ShipmentStatus,
  WebhookAuthScheme,
} from '@prisma/client';
import { createHmac, timingSafeEqual } from 'node:crypto';

import {
  CancelDeliveryInput,
  CreateDeliveryInput,
  DeliveryAddress,
  CreateDeliveryResult,
  DeliveryProvider,
  DeliveryStatusResult,
  DeliveryWebhookEventInput,
  QuoteInput,
  QuoteResult,
  TrackingCheckpoint,
  TrackingResult,
  WebhookRequest,
  WebhookVerdict,
} from './delivery-provider.interface';
import {
  toCanonicalStatus,
  toFailureReason,
} from './delivery-status.map';
import { ProviderCredentialsService } from './provider-credentials.service';

/**
 * What an `EXTERNAL_API` account's `config` column holds.
 *
 * Every field is optional because a carrier's documentation arrives later than
 * the integration does: an account with no `baseUrl` is simply not dispatchable
 * yet, and says so, rather than failing at the first parcel.
 */
export interface HttpProviderConfig {
  baseUrl?: string;
  /** Path templates. `{id}` is replaced by the carrier's delivery id. */
  createPath?: string;
  cancelPath?: string;
  statusPath?: string;
  trackingPath?: string;
  quotePath?: string;
  /** Defaults: POST create, POST cancel, GET status/tracking, POST quote. */
  methods?: Partial<
    Record<'create' | 'cancel' | 'status' | 'tracking' | 'quote', string>
  >;
  /** `Authorization: Bearer {apiKey}` unless overridden. */
  authHeader?: string;
  authScheme?: string;
  /** Extra static headers. Never put a secret here — name an env var instead. */
  headers?: Record<string, string>;
  /** Header the carrier reads an idempotency key from. */
  idempotencyHeader?: string;
  timeoutMs?: number;
  retries?: number;
  /** Where to read each field out of the carrier's JSON, as dotted paths. */
  fieldPaths?: {
    externalDeliveryId?: string;
    trackingNumber?: string;
    trackingUrl?: string;
    labelUrl?: string;
    status?: string;
    fee?: string;
    feeCurrency?: string;
    collectedAmount?: string;
    failureReason?: string;
    failureNote?: string;
    occurredAt?: string;
    estimatedDeliveryAt?: string;
    checkpoints?: string;
    events?: string;
    eventId?: string;
    quoteAmount?: string;
    quoteCurrency?: string;
    quoteEtaMinutes?: string;
  };
  /** The carrier's own words, mapped onto Reem's. */
  statusMap?: Record<string, string>;
  failureMap?: Record<string, string>;
  /** Body template keys, for carriers whose field names differ wildly. */
  fieldNames?: Record<string, string>;
  /** Sandbox escape hatch: accept unsigned callbacks. Never in production. */
  allowUnsignedWebhooks?: boolean;
}

const DEFAULT_TIMEOUT_MS = 10_000;
const DEFAULT_RETRIES = 2;

/** Values that must never reach a log line or a stored payload. */
const SECRET_KEYS =
  /^(authorization|x-api-key|api[-_]?key|secret|token|signature|password)$/i;

/**
 * The adapter every HTTP delivery company starts as.
 *
 * It is deliberately configuration-driven rather than carrier-specific: until
 * a real carrier's documentation is in hand, what can honestly be built is the
 * *shape* of the conversation — a create call, a cancel call, a status read, a
 * tracking read, an optional quote, and a signed callback — with the pieces
 * that differ (paths, field names, status words) in a row instead of in code.
 *
 * When a carrier's docs arrive there are two honest options, and both are
 * cheap: fill in this account's `config`, or subclass this class and override
 * the two or three methods whose payloads do not fit. Nothing outside this
 * folder changes either way.
 */
@Injectable()
export class HttpDeliveryProvider implements DeliveryProvider {
  readonly code = 'http_generic';
  readonly displayName = 'HTTP delivery company';

  protected readonly logger = new Logger(HttpDeliveryProvider.name);

  constructor(protected readonly credentials: ProviderCredentialsService) {}

  // ── Outbound ──────────────────────────────────────────────────────────

  async createDelivery(
    account: DeliveryProviderAccount,
    input: CreateDeliveryInput,
  ): Promise<CreateDeliveryResult> {
    const config = this.configOf(account);
    const body = this.createBody(input, config);

    const response = await this.call(account, {
      path: config.createPath ?? '/deliveries',
      method: config.methods?.create ?? 'POST',
      body,
      idempotencyKey: input.idempotencyKey,
    });

    const externalId = this.read(response, config.fieldPaths?.externalDeliveryId, [
      'id',
      'delivery_id',
      'deliveryId',
      'data.id',
      'result.id',
    ]);
    if (!externalId) {
      throw new Error(
        'The carrier accepted the delivery but returned no identifier for it',
      );
    }

    const feeAmount = this.read(response, config.fieldPaths?.fee, [
      'fee',
      'price',
      'cost',
      'data.fee',
    ]);
    const feeCurrency = this.readString(response, config.fieldPaths?.feeCurrency, [
      'currency',
      'fee_currency',
      'data.currency',
    ]);

    return {
      externalDeliveryId: String(externalId),
      trackingNumber: this.readString(response, config.fieldPaths?.trackingNumber, [
        'tracking_number',
        'trackingNumber',
        'awb',
        'data.tracking_number',
      ]),
      trackingUrl: this.readString(response, config.fieldPaths?.trackingUrl, [
        'tracking_url',
        'trackingUrl',
        'data.tracking_url',
      ]),
      labelUrl: this.readString(response, config.fieldPaths?.labelUrl, [
        'label_url',
        'labelUrl',
      ]),
      status:
        toCanonicalStatus(
          this.readString(response, config.fieldPaths?.status, [
            'status',
            'state',
            'data.status',
          ]),
          config.statusMap,
        ) ?? ShipmentStatus.ASSIGNED,
      providerStatus: this.readString(response, config.fieldPaths?.status, [
        'status',
        'state',
        'data.status',
      ]),
      fee:
        feeAmount != null
          ? {
              amount: String(feeAmount),
              currency: this.currencyOf(feeCurrency, input.currency),
            }
          : null,
      raw: this.redact(response),
    };
  }

  async cancelDelivery(
    account: DeliveryProviderAccount,
    input: CancelDeliveryInput,
  ): Promise<void> {
    const config = this.configOf(account);
    await this.call(account, {
      path: (config.cancelPath ?? '/deliveries/{id}/cancel').replace(
        '{id}',
        encodeURIComponent(input.externalDeliveryId),
      ),
      method: config.methods?.cancel ?? 'POST',
      body: { reason: input.reason ?? 'cancelled_by_merchant' },
    });
  }

  async getDeliveryStatus(
    account: DeliveryProviderAccount,
    externalDeliveryId: string,
  ): Promise<DeliveryStatusResult> {
    const config = this.configOf(account);
    const response = await this.call(account, {
      path: (config.statusPath ?? '/deliveries/{id}').replace(
        '{id}',
        encodeURIComponent(externalDeliveryId),
      ),
      method: config.methods?.status ?? 'GET',
    });

    const providerStatus = this.readString(response, config.fieldPaths?.status, [
      'status',
      'state',
      'data.status',
    ]);

    return {
      status:
        toCanonicalStatus(providerStatus, config.statusMap) ??
        ShipmentStatus.IN_TRANSIT,
      providerStatus,
      occurredAt: this.readDate(response, config.fieldPaths?.occurredAt, [
        'updated_at',
        'timestamp',
        'data.updated_at',
      ]),
      failureReason: toFailureReason(
        this.readString(response, config.fieldPaths?.failureReason, [
          'failure_reason',
          'reason',
        ]),
        config.failureMap,
      ),
      failureNote: this.readString(response, config.fieldPaths?.failureNote, [
        'failure_note',
        'note',
      ]),
      collectedAmount: this.readString(response, config.fieldPaths?.collectedAmount, [
        'collected_amount',
        'cod_collected',
      ]),
      trackingNumber: this.readString(response, config.fieldPaths?.trackingNumber, [
        'tracking_number',
        'awb',
      ]),
      raw: this.redact(response),
    };
  }

  async getTracking(
    account: DeliveryProviderAccount,
    externalDeliveryId: string,
  ): Promise<TrackingResult> {
    const config = this.configOf(account);
    const response = await this.call(account, {
      path: (config.trackingPath ?? '/deliveries/{id}/tracking').replace(
        '{id}',
        encodeURIComponent(externalDeliveryId),
      ),
      method: config.methods?.tracking ?? 'GET',
    });

    const rows = this.readArray(response, config.fieldPaths?.checkpoints, [
      'checkpoints',
      'events',
      'history',
      'data.checkpoints',
    ]);

    const checkpoints: TrackingCheckpoint[] = rows.flatMap((row) => {
      const providerStatus = this.readString(row, config.fieldPaths?.status, [
        'status',
        'state',
      ]);
      const status = toCanonicalStatus(providerStatus, config.statusMap);
      const at = this.readDate(row, config.fieldPaths?.occurredAt, [
        'timestamp',
        'at',
        'created_at',
      ]);
      if (!status) return [];
      return [
        {
          status,
          providerStatus,
          note: this.readString(row, undefined, ['note', 'description']),
          at: at ?? new Date(),
        },
      ];
    });

    const latest = checkpoints.at(-1);
    return {
      status: latest?.status ?? ShipmentStatus.IN_TRANSIT,
      trackingNumber: this.readString(response, config.fieldPaths?.trackingNumber, [
        'tracking_number',
        'awb',
      ]),
      trackingUrl: this.readString(response, config.fieldPaths?.trackingUrl, [
        'tracking_url',
      ]),
      estimatedDeliveryAt: this.readDate(
        response,
        config.fieldPaths?.estimatedDeliveryAt,
        ['eta', 'estimated_delivery_at'],
      ),
      checkpoints,
    };
  }

  async calculateDeliveryFee(
    account: DeliveryProviderAccount,
    input: QuoteInput,
  ): Promise<QuoteResult> {
    const config = this.configOf(account);
    const response = await this.call(account, {
      path: config.quotePath ?? '/quotes',
      method: config.methods?.quote ?? 'POST',
      body: {
        pickup: input.pickup,
        dropoff: input.dropoff,
        express: input.isExpress,
        declared_value: input.declaredValue ?? undefined,
        weight_grams: input.weightGrams ?? undefined,
        currency: input.currency,
      },
    });

    const amount = this.read(response, config.fieldPaths?.quoteAmount, [
      'amount',
      'fee',
      'price',
      'data.amount',
    ]);
    if (amount == null) {
      throw new Error('The carrier returned a quote with no amount');
    }

    const etaRaw = this.read(response, config.fieldPaths?.quoteEtaMinutes, [
      'eta_minutes',
      'eta',
    ]);

    return {
      amount: String(amount),
      currency: this.currencyOf(
        this.readString(response, config.fieldPaths?.quoteCurrency, ['currency']),
        input.currency,
      ),
      etaMinutes: typeof etaRaw === 'number' ? etaRaw : null,
    };
  }

  // ── Inbound ───────────────────────────────────────────────────────────

  async handleWebhook(
    account: DeliveryProviderAccount,
    request: WebhookRequest,
  ): Promise<WebhookVerdict> {
    const config = this.configOf(account);
    const signatureValid = this.verifySignature(account, config, request);

    if (!signatureValid) {
      // Parsed anyway, and recorded, so an integration whose signature scheme
      // is wrong can be diagnosed from the event log rather than from silence.
      // The orchestrator refuses to *apply* an unverified event.
      return { signatureValid: false, events: this.parseEvents(request.body, config) };
    }

    return {
      signatureValid: true,
      events: this.parseEvents(request.body, config),
    };
  }

  protected parseEvents(
    body: unknown,
    config: HttpProviderConfig,
  ): DeliveryWebhookEventInput[] {
    const rows = this.readArray(body, config.fieldPaths?.events, [
      'events',
      'data',
      'items',
    ]);
    const candidates = rows.length > 0 ? rows : [body];

    return candidates.flatMap((row) => {
      const externalDeliveryId = this.readString(
        row,
        config.fieldPaths?.externalDeliveryId,
        ['delivery_id', 'deliveryId', 'id', 'order_id', 'reference'],
      );
      const providerStatus = this.readString(row, config.fieldPaths?.status, [
        'status',
        'state',
        'event',
      ]);
      const status = toCanonicalStatus(providerStatus, config.statusMap);
      if (!externalDeliveryId || !status) return [];

      return [
        {
          externalEventId: this.readString(row, config.fieldPaths?.eventId, [
            'event_id',
            'eventId',
            'id',
          ]),
          externalDeliveryId,
          status,
          providerStatus,
          occurredAt: this.readDate(row, config.fieldPaths?.occurredAt, [
            'timestamp',
            'occurred_at',
            'created_at',
          ]),
          failureReason: toFailureReason(
            this.readString(row, config.fieldPaths?.failureReason, [
              'failure_reason',
              'reason',
            ]),
            config.failureMap,
          ),
          failureNote: this.readString(row, config.fieldPaths?.failureNote, [
            'note',
            'message',
          ]),
          collectedAmount: this.readString(
            row,
            config.fieldPaths?.collectedAmount,
            ['collected_amount', 'cod_collected'],
          ),
          trackingNumber: this.readString(row, config.fieldPaths?.trackingNumber, [
            'tracking_number',
            'awb',
          ]),
        },
      ];
    });
  }

  protected verifySignature(
    account: DeliveryProviderAccount,
    config: HttpProviderConfig,
    request: WebhookRequest,
  ): boolean {
    if (account.webhookAuth === WebhookAuthScheme.NONE) {
      // Only if the account says so out loud. An unsigned callback is a public
      // endpoint that can mark any parcel delivered — and on a cash order that
      // is money.
      return config.allowUnsignedWebhooks === true;
    }

    const secret = this.credentials.resolve(account).webhookSecret;
    if (!secret) return false;

    const header = account.webhookSignatureHeader ?? 'x-signature';
    const received = this.headerValue(request.headers, header);
    if (!received) return false;

    if (account.webhookAuth === WebhookAuthScheme.SHARED_SECRET) {
      return this.constantTimeEquals(received.trim(), secret);
    }

    const raw = request.rawBody;
    if (!raw) return false;
    const digest = createHmac('sha256', secret).update(raw).digest('hex');
    // Carriers variously send the bare hex or prefix it with the algorithm.
    const candidate = received.includes('=')
      ? received.slice(received.indexOf('=') + 1)
      : received;
    return this.constantTimeEquals(candidate.trim().toLowerCase(), digest);
  }

  // ── Transport ─────────────────────────────────────────────────────────

  /**
   * One HTTP call, with the four things production needs: a timeout, bounded
   * retries on failures that can be retried, an idempotency key so a retry
   * cannot create a second parcel, and a redacted record of what was sent.
   */
  protected async call(
    account: DeliveryProviderAccount,
    request: {
      path: string;
      method: string;
      body?: unknown;
      idempotencyKey?: string;
    },
  ): Promise<unknown> {
    const config = this.configOf(account);
    if (!config.baseUrl) {
      throw new Error(
        `Carrier ${account.code} has no baseUrl configured — add it before dispatching`,
      );
    }

    const credentials = this.credentials.resolve(account);
    const url = `${config.baseUrl.replace(/\/$/, '')}${request.path}`;
    const timeout = config.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    const retries = Math.max(0, config.retries ?? DEFAULT_RETRIES);

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(config.headers ?? {}),
    };
    if (credentials.apiKey) {
      headers[config.authHeader ?? 'Authorization'] =
        `${config.authScheme ?? 'Bearer'} ${credentials.apiKey}`.trim();
    }
    if (request.idempotencyKey) {
      headers[config.idempotencyHeader ?? 'Idempotency-Key'] =
        request.idempotencyKey;
    }

    let lastError: Error | undefined;
    for (let attempt = 0; attempt <= retries; attempt += 1) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeout);
      try {
        const response = await fetch(url, {
          method: request.method,
          headers,
          body: request.body === undefined ? undefined : JSON.stringify(request.body),
          signal: controller.signal,
        });
        const text = await response.text();
        const payload = text ? this.parseJson(text) : null;

        if (response.ok) return payload;

        // 4xx is the carrier's answer, not a hiccup: retrying it wastes time
        // and can duplicate work on a carrier with sloppy idempotency.
        const message = `${account.code} answered ${response.status} for ${request.method} ${request.path}`;
        if (response.status < 500 && response.status !== 429) {
          throw new Error(`${message}: ${this.summarise(payload ?? text)}`);
        }
        lastError = new Error(message);
      } catch (error) {
        const err = error as Error;
        if (err.name === 'AbortError') {
          lastError = new Error(
            `${account.code} did not answer within ${timeout}ms`,
          );
        } else {
          lastError = err;
        }
        // A refusal the carrier stated is final; only transport faults retry.
        if (!/did not answer|fetch failed|ECONN|network|answered 5|answered 429/i.test(lastError.message)) {
          throw lastError;
        }
      } finally {
        clearTimeout(timer);
      }

      if (attempt < retries) {
        await this.backoff(attempt);
      }
    }

    throw lastError ?? new Error(`${account.code} could not be reached`);
  }

  private async backoff(attempt: number): Promise<void> {
    const base = 250 * 2 ** attempt;
    const jitter = Math.floor(Math.random() * 100);
    await new Promise((resolve) => setTimeout(resolve, base + jitter));
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  protected configOf(account: DeliveryProviderAccount): HttpProviderConfig {
    return (account.config ?? {}) as HttpProviderConfig;
  }

  private createBody(
    input: CreateDeliveryInput,
    config: HttpProviderConfig,
  ): Record<string, unknown> {
    const names = config.fieldNames ?? {};
    const key = (field: string, fallback: string) => names[field] ?? fallback;

    return {
      [key('reference', 'reference')]: input.reference,
      [key('pickup', 'pickup')]: this.address(input.pickup),
      [key('dropoff', 'dropoff')]: this.address(input.dropoff),
      [key('codAmount', 'cod_amount')]: input.codAmount ?? undefined,
      [key('currency', 'currency')]: input.currency,
      [key('declaredValue', 'declared_value')]: input.declaredValue ?? undefined,
      [key('itemCount', 'item_count')]: input.itemCount,
      [key('weightGrams', 'weight_grams')]: input.weightGrams ?? undefined,
      [key('isExpress', 'express')]: input.isExpress,
      [key('scheduledFor', 'scheduled_for')]:
        input.scheduledFor?.toISOString() ?? undefined,
      [key('notes', 'notes')]: input.notes ?? undefined,
    };
  }

  /** An address as an HTTP API expects to read it: snake_case, no nulls. */
  private address(address: DeliveryAddress): Record<string, unknown> {
    return {
      name: address.name,
      phone: address.phone,
      governorate: address.governorate,
      city: address.city,
      district: address.district ?? undefined,
      address_line: address.addressLine,
      landmark: address.landmark ?? undefined,
      latitude: address.latitude ?? undefined,
      longitude: address.longitude ?? undefined,
      notes: address.notes ?? undefined,
    };
  }

  private parseJson(text: string): unknown {
    try {
      return JSON.parse(text);
    } catch {
      return { raw: text.slice(0, 2000) };
    }
  }

  private summarise(payload: unknown): string {
    const text =
      typeof payload === 'string' ? payload : JSON.stringify(this.redact(payload));
    return text.slice(0, 300);
  }

  /** Strips anything that looks like a credential before it is logged or stored. */
  protected redact(value: unknown, depth = 0): unknown {
    if (depth > 6 || value == null) return value;
    if (Array.isArray(value)) {
      return value.slice(0, 50).map((item) => this.redact(item, depth + 1));
    }
    if (typeof value !== 'object') return value;

    const out: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      out[key] = SECRET_KEYS.test(key) ? '[redacted]' : this.redact(item, depth + 1);
    }
    return out;
  }

  private headerValue(
    headers: Record<string, string | string[] | undefined>,
    name: string,
  ): string | undefined {
    const target = name.toLowerCase();
    for (const [key, value] of Object.entries(headers)) {
      if (key.toLowerCase() !== target) continue;
      return Array.isArray(value) ? value[0] : value;
    }
    return undefined;
  }

  private constantTimeEquals(a: string, b: string): boolean {
    const left = Buffer.from(a);
    const right = Buffer.from(b);
    if (left.length !== right.length) return false;
    return timingSafeEqual(left, right);
  }

  private currencyOf(raw: string | null | undefined, fallback: Currency): Currency {
    const value = String(raw ?? '').toUpperCase();
    return value === Currency.USD || value === Currency.SYP
      ? (value as Currency)
      : fallback;
  }

  protected read(
    source: unknown,
    path: string | undefined,
    fallbacks: string[],
  ): unknown {
    for (const candidate of [path, ...fallbacks].filter(Boolean) as string[]) {
      const value = candidate
        .split('.')
        .reduce<unknown>(
          (acc, part) =>
            acc && typeof acc === 'object'
              ? (acc as Record<string, unknown>)[part]
              : undefined,
          source,
        );
      if (value !== undefined && value !== null) return value;
    }
    return undefined;
  }

  protected readString(
    source: unknown,
    path: string | undefined,
    fallbacks: string[],
  ): string | null {
    const value = this.read(source, path, fallbacks);
    return value == null ? null : String(value);
  }

  protected readDate(
    source: unknown,
    path: string | undefined,
    fallbacks: string[],
  ): Date | null {
    const value = this.read(source, path, fallbacks);
    if (value == null) return null;
    const date = new Date(String(value));
    return Number.isNaN(date.getTime()) ? null : date;
  }

  protected readArray(
    source: unknown,
    path: string | undefined,
    fallbacks: string[],
  ): unknown[] {
    const value = this.read(source, path, fallbacks);
    return Array.isArray(value) ? value : [];
  }
}
