import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthProvider } from '@prisma/client';
import { createPublicKey, verify as verifySignature } from 'crypto';
import { SocialAuthDto } from './dto/social-auth.dto';

interface SocialIdentity {
  provider: AuthProvider;
  providerUserId: string;
  email?: string;
  emailVerified: boolean;
  name?: string;
}

interface JwtHeader {
  alg?: string;
  kid?: string;
}

interface JwtPayload {
  sub?: string;
  iss?: string;
  aud?: string | string[];
  exp?: number;
  email?: string;
  email_verified?: boolean | string;
  name?: string;
}

@Injectable()
export class SocialIdentityService {
  constructor(private readonly config: ConfigService) {}

  async verify(dto: SocialAuthDto): Promise<SocialIdentity> {
    if (dto.id_token) {
      return this.verifyIdToken(dto.provider, dto.id_token);
    }

    // Local/mobile development fallback. Production must use provider tokens.
    if (
      this.config.get<string>('nodeEnv') !== 'production' &&
      dto.provider_user_id
    ) {
      return {
        provider: dto.provider,
        providerUserId: dto.provider_user_id,
        email: dto.email,
        emailVerified: Boolean(dto.email),
        name: dto.name,
      };
    }

    throw new BadRequestException('Provider id_token is required');
  }

  private async verifyIdToken(
    provider: AuthProvider,
    token: string,
  ): Promise<SocialIdentity> {
    const [encodedHeader, encodedPayload, encodedSignature] = token.split('.');
    if (!encodedHeader || !encodedPayload || !encodedSignature) {
      throw new UnauthorizedException('Invalid provider token');
    }

    const header = parseJwtPart<JwtHeader>(encodedHeader);
    const payload = parseJwtPart<JwtPayload>(encodedPayload);
    const config = this.providerConfig(provider);

    if (header.alg !== 'RS256' || !header.kid || !payload.sub) {
      throw new UnauthorizedException('Invalid provider token');
    }
    if (payload.iss !== config.issuer) {
      throw new UnauthorizedException('Invalid provider issuer');
    }
    if (!audienceAllowed(payload.aud, config.audiences)) {
      throw new UnauthorizedException('Invalid provider audience');
    }
    if (!payload.exp || payload.exp * 1000 < Date.now()) {
      throw new UnauthorizedException('Provider token has expired');
    }

    const jwk = await this.findSigningKey(config.jwksUrl, header.kid);
    const publicKey = createPublicKey({ key: jwk, format: 'jwk' });
    const verified = verifySignature(
      'RSA-SHA256',
      Buffer.from(`${encodedHeader}.${encodedPayload}`),
      publicKey,
      base64UrlToBuffer(encodedSignature),
    );

    if (!verified) {
      throw new UnauthorizedException('Invalid provider token signature');
    }

    return {
      provider,
      providerUserId: payload.sub,
      email: payload.email,
      emailVerified:
        payload.email_verified === true || payload.email_verified === 'true',
      name: payload.name,
    };
  }

  private providerConfig(provider: AuthProvider) {
    if (provider === AuthProvider.GOOGLE) {
      return {
        issuer: 'https://accounts.google.com',
        jwksUrl: 'https://www.googleapis.com/oauth2/v3/certs',
        audiences: splitCsv(this.config.get<string>('social.googleClientIds')),
      };
    }

    return {
      issuer: 'https://appleid.apple.com',
      jwksUrl: 'https://appleid.apple.com/auth/keys',
      audiences: splitCsv(this.config.get<string>('social.appleClientIds')),
    };
  }

  private async findSigningKey(jwksUrl: string, kid: string) {
    const response = await fetch(jwksUrl);
    if (!response.ok) {
      throw new UnauthorizedException('Could not verify provider token');
    }
    const jwks = (await response.json()) as {
      keys?: Array<Record<string, string>>;
    };
    const key = jwks.keys?.find((candidate) => candidate.kid === kid);
    if (!key) throw new UnauthorizedException('Unknown provider signing key');
    return key;
  }
}

function parseJwtPart<T>(part: string): T {
  return JSON.parse(base64UrlToBuffer(part).toString('utf8')) as T;
}

function base64UrlToBuffer(input: string): Buffer {
  const padded = input.replace(/-/g, '+').replace(/_/g, '/');
  return Buffer.from(padded, 'base64');
}

function splitCsv(value?: string): string[] {
  return (value ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function audienceAllowed(
  actual: string | string[] | undefined,
  allowed: string[],
): boolean {
  if (allowed.length === 0) return false;
  const actualAudiences = Array.isArray(actual) ? actual : actual ? [actual] : [];
  return actualAudiences.some((audience) => allowed.includes(audience));
}
