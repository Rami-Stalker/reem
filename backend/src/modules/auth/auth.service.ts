import { prisma } from '../../lib/prisma.js';
import { ConflictError, NotFoundError, UnauthorizedError } from '../../lib/errors.js';
import { hashPassword, verifyPassword } from '../../lib/password.js';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../../lib/jwt.js';
import { authResponse, serializeUser } from '../../utils/serializers.js';

function usernameFromEmail(email: string): string {
  const base = email.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '_').toLowerCase();
  return `${base}_${Math.floor(Math.random() * 9999)}`;
}

async function issueTokens(userId: string, email: string, role: string) {
  const access_token = signAccessToken({ sub: userId, email, role });
  const refresh_token = signRefreshToken(userId);

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 7);

  await prisma.refreshToken.create({
    data: {
      token: refresh_token,
      userId,
      expiresAt,
    },
  });

  return { access_token, refresh_token };
}

export class AuthService {
  static async register(name: string, email: string, password: string) {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictError('Email already registered');
    }

    const passwordHash = await hashPassword(password);
    let username = usernameFromEmail(email);
    while (await prisma.user.findUnique({ where: { username } })) {
      username = usernameFromEmail(email);
    }

    const user = await prisma.user.create({
      data: {
        name,
        email,
        username,
        passwordHash,
        imageUrl: `https://i.pravatar.cc/150?u=${encodeURIComponent(email)}`,
        isVerified: true,
      },
    });

    const tokens = await issueTokens(user.id, user.email, user.role);
    return authResponse(user, tokens);
  }

  static async login(email: string, password: string) {
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const valid = await verifyPassword(password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const tokens = await issueTokens(user.id, user.email, user.role);
    return authResponse(user, tokens);
  }

  static async refresh(refreshToken: string) {
    const payload = verifyRefreshToken(refreshToken);

    const stored = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: true },
    });

    if (!stored || stored.expiresAt < new Date() || stored.userId !== payload.sub) {
      throw new UnauthorizedError('Invalid refresh token');
    }

    await prisma.refreshToken.delete({ where: { id: stored.id } });

    const tokens = await issueTokens(
      stored.user.id,
      stored.user.email,
      stored.user.role,
    );
    return authResponse(stored.user, tokens);
  }

  static async me(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundError('User not found');
    return { user: serializeUser(user) };
  }

  static async forgotPassword(email: string) {
    const user = await prisma.user.findUnique({ where: { email } });
    if (user) {
      // Production: send email with reset link (nodemailer / SendGrid)
      console.info(`[dev] Password reset requested for ${email}`);
    }
    return { message: 'If that email exists, a reset link has been sent.' };
  }
}
