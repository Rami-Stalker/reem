import { Injectable } from '@nestjs/common';
import { AuthProvider, Prisma, User } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/** Data-access for the auth module — isolates persistence from business logic. */
@Injectable()
export class AuthRepository {
  constructor(private readonly prisma: PrismaService) {}

  findByPhone(phone: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  findLinkedAccount(provider: AuthProvider, providerUserId: string) {
    return this.prisma.linkedAccount.findUnique({
      where: {
        provider_providerUserId: {
          provider,
          providerUserId,
        },
      },
      include: { user: true },
    });
  }

  async usernameTaken(username: string): Promise<boolean> {
    const count = await this.prisma.user.count({ where: { username } });
    return count > 0;
  }

  create(data: Prisma.UserCreateInput): Promise<User> {
    return this.prisma.user.create({ data });
  }

  linkAccount(data: {
    userId: string;
    provider: AuthProvider;
    providerUserId: string;
    email?: string;
    displayName?: string;
  }) {
    return this.prisma.linkedAccount.upsert({
      where: {
        provider_providerUserId: {
          provider: data.provider,
          providerUserId: data.providerUserId,
        },
      },
      update: {
        userId: data.userId,
        email: data.email,
        displayName: data.displayName,
        lastUsedAt: new Date(),
      },
      create: {
        userId: data.userId,
        provider: data.provider,
        providerUserId: data.providerUserId,
        email: data.email,
        displayName: data.displayName,
        lastUsedAt: new Date(),
      },
    });
  }
}
