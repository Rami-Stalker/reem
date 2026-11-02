import { StoreTeamRole } from '@prisma/client';

/** The header a team member's app sends while working inside a shop. */
export const STORE_HEADER = 'x-ohara-store';

/**
 * What each team role may reach while acting for the shop, as path prefixes.
 *
 * Money is absent from every list on purpose: payouts, payment settings,
 * advertising spend and the team itself stay with the owner, whatever role
 * she gives anyone.
 */
const SHARED = ['/media'];
const ORDERS = [
  '/seller/orders',
  '/returns',
  '/chats',
  '/seller/customers',
];
const CATALOG = [
  '/seller/products',
  '/seller/offers',
  '/products',
  '/categories',
  '/ai/generate',
];
const MANAGER_ONLY = [
  '/seller/store-settings',
  '/seller/coupons',
  '/seller/posts',
  '/seller/stories',
  '/seller/content',
  '/content',
  '/seller/commerce',
  '/seller/intelligence',
  '/seller/market',
  '/reputation/seller',
  '/trends/seller',
  '/promotions',
  '/analytics/seller',
];

const ALLOWED: Record<StoreTeamRole, readonly string[]> = {
  [StoreTeamRole.ORDERS]: [...SHARED, ...ORDERS],
  [StoreTeamRole.CATALOG]: [...SHARED, ...CATALOG],
  [StoreTeamRole.MANAGER]: [...SHARED, ...ORDERS, ...CATALOG, ...MANAGER_ONLY],
};

/** Never reachable as the shop, whatever the role. */
const NEVER = ['/finance', '/ads', '/seller/team', '/auth', '/users', '/seller/activity'];

export function mayActFor(role: StoreTeamRole, path: string): boolean {
  const clean = path.split('?')[0];
  const within = (prefix: string) =>
    clean === prefix || clean.startsWith(`${prefix}/`);
  if (NEVER.some(within)) return false;
  return ALLOWED[role].some(within);
}
