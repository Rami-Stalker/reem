import { Injectable, UnauthorizedException } from '@nestjs/common';
import { normalizePhone } from '../../../../backend/src/common/phone/phone';
import { supabaseRuntime } from '../runtime/env';
import { SupabaseHttp } from '../supabase/supabase-http';

export interface SupabaseIdentity {
  authUserId: string;
  /** E.164, as the backend stores it (`+9639…`). */
  phone: string;
}

interface GoTrueUser {
  id: string;
  phone?: string | null;
  phone_confirmed_at?: string | null;
  banned_until?: string | null;
}

/**
 * The slice of Supabase Auth the API talks to.
 *
 * `identify` asks Auth itself — `GET /auth/v1/user` with the caller's token —
 * rather than verifying the JWT locally. It is one request at sign-in, and in
 * exchange it answers the questions a signature check cannot: whether the
 * session was revoked a second ago, and whether the phone on the account is
 * the one that was actually confirmed by a code.
 */
@Injectable()
export class SupabaseAuthClient {
  constructor(private readonly http: SupabaseHttp) {}

  async identify(accessToken: string): Promise<SupabaseIdentity> {
    if (!accessToken || accessToken.length > 4096) {
      throw new UnauthorizedException({ code: 'SUPABASE_TOKEN_REQUIRED', message: 'A Supabase session is required' });
    }
    const response = await this.http.request('/auth/v1/user', {
      bearer: accessToken,
      headers: { apikey: supabaseRuntime().publishableKey || supabaseRuntime().secretKey },
    });
    if (response.status === 401 || response.status === 403) {
      throw new UnauthorizedException({ code: 'SUPABASE_SESSION_INVALID', message: 'The Supabase session is not valid' });
    }
    if (!response.ok) {
      throw new UnauthorizedException({ code: 'SUPABASE_AUTH_UNAVAILABLE', message: 'Could not confirm the Supabase session' });
    }

    const user = (await response.json()) as GoTrueUser;
    const phone = user.phone ? normalizePhone(`+${user.phone.replace(/^\+/, '')}`) : null;
    if (!user.id || !phone || !user.phone_confirmed_at) {
      // Only a number confirmed by a code proves anything here. An account
      // created some other way (an email, an admin invite) is not an identity
      // this platform recognises.
      throw new UnauthorizedException({
        code: 'SUPABASE_PHONE_UNCONFIRMED',
        message: 'Sign in with a confirmed phone number',
      });
    }
    return { authUserId: user.id, phone };
  }

  /** Revokes every session of an auth user by removing it. */
  async deleteUser(authUserId: string): Promise<void> {
    const response = await this.http.request(`/auth/v1/admin/users/${encodeURIComponent(authUserId)}`, {
      method: 'DELETE',
    });
    if (!response.ok && response.status !== 404) {
      throw new Error(`Supabase refused to delete auth user ${authUserId}: ${response.status}`);
    }
  }

  /** Keeps the auth user's number in step with a phone change made in the API. */
  async updatePhone(authUserId: string, phone: string): Promise<void> {
    await this.http.expectOk(`/auth/v1/admin/users/${encodeURIComponent(authUserId)}`, {
      method: 'PUT',
      json: { phone: phone.replace(/^\+/, ''), phone_confirm: true },
    });
  }
}
