import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../../backend/src/prisma/prisma.service';

export interface IdentityLink {
  authUserId: string;
  userId: string;
}

/**
 * `reem_supabase.identity_links` — which Supabase auth user is which Ohara user.
 *
 * The table lives outside `public` on purpose: Prisma's schema does not know
 * it, so the backend running on its own server never sees it and its
 * migrations never fight it. Row Level Security reads it through
 * `reem_supabase.current_user_id()` to turn `auth.uid()` into a Ohara user id.
 *
 * One auth user per Ohara user and one Ohara user per auth user: both columns
 * are unique, and `link` replaces whichever side was bound before.
 */
@Injectable()
export class IdentityLinkRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findByAuthUser(authUserId: string): Promise<IdentityLink | null> {
    const rows = await this.prisma.$queryRaw<Array<{ auth_user_id: string; user_id: string }>>`
      SELECT auth_user_id::text, user_id::text
        FROM reem_supabase.identity_links
       WHERE auth_user_id = ${authUserId}::uuid`;
    return rows[0] ? { authUserId: rows[0].auth_user_id, userId: rows[0].user_id } : null;
  }

  async findByUser(userId: string): Promise<IdentityLink | null> {
    const rows = await this.prisma.$queryRaw<Array<{ auth_user_id: string; user_id: string }>>`
      SELECT auth_user_id::text, user_id::text
        FROM reem_supabase.identity_links
       WHERE user_id = ${userId}::uuid`;
    return rows[0] ? { authUserId: rows[0].auth_user_id, userId: rows[0].user_id } : null;
  }

  async link(authUserId: string, userId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.$executeRaw`
        DELETE FROM reem_supabase.identity_links
         WHERE user_id = ${userId}::uuid AND auth_user_id <> ${authUserId}::uuid`,
      this.prisma.$executeRaw`
        INSERT INTO reem_supabase.identity_links (auth_user_id, user_id)
        VALUES (${authUserId}::uuid, ${userId}::uuid)
        ON CONFLICT (auth_user_id)
        DO UPDATE SET user_id = EXCLUDED.user_id, linked_at = now()`,
    ]);
  }

  async unlinkAuthUser(authUserId: string): Promise<void> {
    await this.prisma.$executeRaw`
      DELETE FROM reem_supabase.identity_links WHERE auth_user_id = ${authUserId}::uuid`;
  }
}
