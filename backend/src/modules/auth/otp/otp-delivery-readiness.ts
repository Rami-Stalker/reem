import { Inject, Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpTransportKind } from '@prisma/client';
import { DeliveryOrchestrator } from './delivery.orchestrator';
import { parseOtpTestAccounts, testAccountsActive } from './otp-test-accounts';
import { OTP_TRANSPORTS, OtpTransport } from './otp-transport';
import { ReverseSmsService } from './syrotp/reverse-sms.service';

/**
 * Checks at start-up that a one-time code can actually reach somebody.
 *
 * Environment validation already refuses a production boot with no provider
 * credentials. This checks the other half, which lives in the database: the
 * transport chain in `otp_transport_routes`. Credentials for SMS are no use if
 * operations disabled the SMS route last week, and the symptom — every sign-in
 * answering "code sent" while nothing is sent — is indistinguishable from a
 * slow network until somebody reads the delivery report.
 *
 * Production refuses to start without a usable route. Anywhere else it says
 * which transports are live and carries on, because the dev inbox is how a
 * developer signs in.
 */
@Injectable()
export class OtpDeliveryReadiness implements OnApplicationBootstrap {
  private readonly logger = new Logger(OtpDeliveryReadiness.name);

  constructor(
    private readonly orchestrator: DeliveryOrchestrator,
    @Inject(OTP_TRANSPORTS) private readonly transports: OtpTransport[],
    private readonly reverse: ReverseSmsService,
    private readonly config: ConfigService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    if (this.config.get<string>('nodeEnv') === 'test') return;

    // A configured reverse rail is a way in on its own: she proves the number
    // by messaging a receiver this deployment owns, so a deployment that has
    // one needs no outbound transport at all. Said first because this is the
    // intended shape now, and a boot log that only ever lists transports would
    // read as "no OTP delivery" on exactly the deployments that work best.
    if (this.reverse.isUsable()) {
      this.logger.log(
        `OTP delivery: reverse SMS (SYROTP)${
          this.reverse.isPrimary() ? ' — primary' : ' — fallback only'
        }`,
      );
      if (this.reverse.isPrimary()) return;
    }

    const chain = await this.orchestrator.chain();
    const usable = chain
      .map((route) => route.transport)
      .filter((kind) =>
        this.transports.some((t) => t.kind === kind && t.isConfigured()),
      );
    const reachesHandset = usable.filter((kind) => kind !== OtpTransportKind.OPS_CONSOLE);

    if (reachesHandset.length > 0) {
      this.logger.log(`OTP delivery chain: ${usable.join(' → ')}`);
      return;
    }

    const message =
      'No enabled OTP route has a configured provider ' +
      `(enabled routes: ${chain.map((r) => r.transport).join(', ') || 'none'}). ` +
      'Sign-in codes cannot reach a handset.';
    const testAccounts = parseOtpTestAccounts(
      this.config.get<string>('otpDelivery.testAccounts'),
      this.config.get<string>('otpDelivery.testAccountsUntil'),
    );
    if (testAccountsActive(testAccounts)) {
      this.logger.warn(
        `${message} Only the ${testAccounts.codes.size} fixed test account(s) can sign in, ` +
          `until ${testAccounts.until?.toISOString()}.`,
      );
      return;
    }
    if (this.config.get<string>('nodeEnv') === 'production') {
      throw new Error(message);
    }
    this.logger.warn(
      `${message} Development only: codes are readable through the dev inbox or log echo when enabled.`,
    );
  }
}
