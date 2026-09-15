import { BadRequestException, Injectable } from '@nestjs/common';
import { OtpPurpose } from '@prisma/client';
import { OtpService } from '../../../../backend/src/modules/auth/otp.service';
import { isLoginProof, spendLoginProof } from './supabase-login-proof';

/**
 * `OtpService`, accepting a Supabase login proof in place of a sign-in code.
 *
 * Only for `LOGIN`, only for a proof minted in this request for this number
 * (see `supabase-login-proof.ts`). Every other purpose — step-up, phone
 * change, password reset, recovery — and every ordinary code goes to the
 * backend's implementation unchanged.
 */
@Injectable()
export class SupabaseAwareOtpService extends OtpService {
  override async consume(phone: string, purpose: OtpPurpose, code: string, clientNonce?: string) {
    if (isLoginProof(code)) {
      if (purpose === OtpPurpose.LOGIN && spendLoginProof(phone, code)) {
        return undefined as unknown as Awaited<ReturnType<OtpService['consume']>>;
      }
      throw new BadRequestException({ code: 'INVALID_OTP', message: 'Invalid OTP' });
    }
    return super.consume(phone, purpose, code, clientNonce);
  }
}
