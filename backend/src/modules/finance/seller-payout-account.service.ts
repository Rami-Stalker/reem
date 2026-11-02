import { BadRequestException, Injectable } from '@nestjs/common';
import { PayoutMethod, SellerPayoutAccount } from '@prisma/client';

import { openText, sealText } from '../../common/crypto/sealed-text';
import { PrismaService } from '../../prisma/prisma.service';
import { SavePayoutAccountDto } from './dto/finance.dto';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';

/** Where one payout is sent, as the payout row snapshots it. */
export interface PayoutDestination {
  method: PayoutMethod;
  /** Masked, for her: «شام كاش · ••••4567». */
  label: string;
  /** The full number, sealed, for whoever pays it. */
  sealed: string;
}

/**
 * «إعدادات الدفع» — the one place a boutique says where she is paid.
 *
 * Two rails only, by decision: a Sham Cash wallet or a Visa card. Every
 * withdrawal request snapshots the account as it is at that moment, so
 * editing it later never redirects money already on its way.
 */
@Injectable()
export class SellerPayoutAccountService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: FinancialAuditService,
  ) {}

  async get(sellerId: string) {
    const account = await this.prisma.sellerPayoutAccount.findUnique({
      where: { sellerId },
    });
    return account ? serializePayoutAccount(account) : null;
  }

  async save(sellerId: string, dto: SavePayoutAccountDto) {
    const existing = await this.prisma.sellerPayoutAccount.findUnique({
      where: { sellerId },
    });
    const holderName = dto.holder_name.replace(/\s+/g, ' ').trim();

    let data: {
      method: PayoutMethod;
      holderName: string;
      shamCashNumber: string | null;
      cardLast4: string | null;
      cardSealed: string | null;
    };
    if (dto.method === PayoutMethod.SHAM_CASH) {
      data = {
        method: PayoutMethod.SHAM_CASH,
        holderName,
        shamCashNumber: normaliseShamCash(dto.sham_cash_number),
        cardLast4: null,
        cardSealed: null,
      };
    } else {
      const typed = dto.card_number?.replace(/[\s-]/g, '') ?? '';
      // An edit that keeps the card she already saved sends no number.
      const keep =
        typed.length === 0 &&
        existing?.method === PayoutMethod.VISA &&
        existing.cardSealed !== null;
      if (!keep) assertVisa(typed);
      data = {
        method: PayoutMethod.VISA,
        holderName,
        shamCashNumber: null,
        cardLast4: keep ? existing.cardLast4 : typed.slice(-4),
        cardSealed: keep ? existing.cardSealed : sealText(typed),
      };
    }

    const saved = await this.prisma.sellerPayoutAccount.upsert({
      where: { sellerId },
      create: { sellerId, ...data },
      update: data,
    });

    await this.audit.record({
      action: FinancialAction.PayoutAccountChanged,
      actorId: sellerId,
      subjectId: saved.id,
      subjectType: 'seller_payout_account',
      before: existing ? labelOf(existing) : null,
      after: labelOf(saved),
      reason: existing ? 'updated by the seller' : 'added by the seller',
    });

    return serializePayoutAccount(saved);
  }

  async remove(sellerId: string) {
    const existing = await this.prisma.sellerPayoutAccount.findUnique({
      where: { sellerId },
    });
    if (!existing) return { removed: false };
    await this.prisma.sellerPayoutAccount.delete({ where: { sellerId } });
    await this.audit.record({
      action: FinancialAction.PayoutAccountChanged,
      actorId: sellerId,
      subjectId: existing.id,
      subjectType: 'seller_payout_account',
      before: labelOf(existing),
      after: null,
      reason: 'removed by the seller',
    });
    return { removed: true };
  }

  /** What a payout requested now would be sent to, or null for nowhere. */
  async destinationFor(sellerId: string): Promise<PayoutDestination | null> {
    const account = await this.prisma.sellerPayoutAccount.findUnique({
      where: { sellerId },
    });
    if (!account) return null;
    const full =
      account.method === PayoutMethod.SHAM_CASH
        ? account.shamCashNumber
        : openText(account.cardSealed);
    if (!full) return null;
    return {
      method: account.method,
      label: labelOf(account),
      sealed: sealText(`${account.holderName} · ${full}`),
    };
  }
}

export function serializePayoutAccount(account: SellerPayoutAccount) {
  return {
    method: account.method.toLowerCase(),
    holder_name: account.holderName,
    /// Never the whole number: the last four are enough to recognise it.
    masked: maskedOf(account),
    label: labelOf(account),
    updated_at: account.updatedAt.toISOString(),
  };
}

function maskedOf(account: SellerPayoutAccount): string {
  const tail =
    account.method === PayoutMethod.SHAM_CASH
      ? (account.shamCashNumber ?? '').slice(-4)
      : (account.cardLast4 ?? '');
  return `•••• ${tail}`;
}

function labelOf(account: SellerPayoutAccount): string {
  const name = account.method === PayoutMethod.SHAM_CASH ? 'شام كاش' : 'فيزا';
  return `${name} · ${maskedOf(account)}`;
}

/**
 * A Sham Cash wallet is reached by its phone number or its account code.
 * The phone is kept in the 09… form the wallet itself shows.
 */
export function normaliseShamCash(raw: string | undefined): string {
  const compact = (raw ?? '').replace(/[\s-]/g, '');
  const phone = compact.replace(/^(\+?963|00963)/, '0');
  if (/^09\d{8}$/.test(phone)) return phone;
  if (/^[A-Za-z0-9]{6,32}$/.test(compact) && !/^\+/.test(compact)) {
    return compact;
  }
  throw new BadRequestException({
    code: 'INVALID_SHAM_CASH',
    message: 'اكتبي رقم محفظة شام كاش (09xxxxxxxx) أو رمز الحساب كما يظهر بالتطبيق',
  });
}

/** A Visa card: 13, 16 or 19 digits, starting with 4, passing Luhn. */
export function assertVisa(digits: string): void {
  const valid =
    /^4\d{12}(\d{3}){0,2}$/.test(digits) && luhn(digits);
  if (!valid) {
    throw new BadRequestException({
      code: 'INVALID_VISA',
      message: 'رقم بطاقة الفيزا غير صحيح — تأكّدي من الأرقام الـ16 المكتوبة على البطاقة',
    });
  }
}

function luhn(digits: string): boolean {
  let sum = 0;
  let double = false;
  for (let i = digits.length - 1; i >= 0; i--) {
    let d = digits.charCodeAt(i) - 48;
    if (double) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    double = !double;
  }
  return sum % 10 === 0;
}
