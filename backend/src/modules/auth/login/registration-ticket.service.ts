import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';

/** Fifteen minutes: long enough to type a name and a city, short enough that a
 *  ticket left in a log is worthless by the time anyone reads it. */
const TICKET_TTL_SECONDS = 15 * 60;

const AUDIENCE = 'reem:registration';

export interface RegistrationTicketClaims {
  /** The number whose control was just proved. */
  phone: string;
  /** The challenge that proved it — the audit link between the two steps. */
  otp_request_id: string;
}

/**
 * The bridge between "she proved she holds this number" and "she filled in the
 * signup form".
 *
 * Registration on Ohara is OTP-first: the number is verified *before* the
 * account exists, which is the opposite of the old flow where an account was
 * created for any number anybody typed and verification came later, if at all.
 * That old ordering let one person register every number in a contact list —
 * squatting accounts belonging to women who had never heard of the platform,
 * and permanently blocking them from signing up under their own number.
 *
 * The ticket carries the proof forward across the two requests. It is signed
 * rather than stored because it is worth nothing on its own: it names a number,
 * and the register endpoint still refuses if an account already exists on it.
 * Single use falls out of that — once the account exists, replaying the ticket
 * gets a conflict.
 */
@Injectable()
export class RegistrationTicketService {
  private readonly logger = new Logger(RegistrationTicketService.name);
  private readonly secret: string;

  constructor(
    private readonly jwt: JwtService,
    config: ConfigService,
  ) {
    this.secret = config.get<string>('jwt.accessSecret') as string;
  }

  async issue(claims: RegistrationTicketClaims): Promise<{
    registration_ticket: string;
    expires_in: number;
  }> {
    const registration_ticket = await this.jwt.signAsync(
      { phone: claims.phone, orid: claims.otp_request_id },
      {
        secret: this.secret,
        audience: AUDIENCE,
        expiresIn: TICKET_TTL_SECONDS,
      },
    );
    return { registration_ticket, expires_in: TICKET_TTL_SECONDS };
  }

  /**
   * Returns the number the ticket vouches for, or null.
   *
   * Null for every failure mode — expired, wrong audience, wrong signature,
   * malformed — because the caller has exactly one thing to do with any of
   * them, and telling a client which one it was only helps someone probing.
   */
  async verify(ticket: string): Promise<RegistrationTicketClaims | null> {
    try {
      const payload = await this.jwt.verifyAsync<{
        phone?: unknown;
        orid?: unknown;
      }>(ticket, { secret: this.secret, audience: AUDIENCE });
      if (typeof payload.phone !== 'string' || payload.phone.length === 0) {
        return null;
      }
      return {
        phone: payload.phone,
        otp_request_id:
          typeof payload.orid === 'string' ? payload.orid : '',
      };
    } catch {
      return null;
    }
  }
}
