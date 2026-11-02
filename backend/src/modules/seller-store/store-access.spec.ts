import assert from 'node:assert/strict';
import test from 'node:test';
import { StoreTeamRole } from '@prisma/client';

import { mayActFor } from './store-access';

/**
 * «إدارة الفريق» — what each role may reach while working for a shop. The
 * rule that matters most is the negative one: no role ever reaches money.
 */
test('an orders member works orders, returns and chats — not products', () => {
  assert.equal(mayActFor(StoreTeamRole.ORDERS, '/seller/orders'), true);
  assert.equal(mayActFor(StoreTeamRole.ORDERS, '/seller/orders/abc/confirm'), true);
  assert.equal(mayActFor(StoreTeamRole.ORDERS, '/chats/abc/messages'), true);
  assert.equal(mayActFor(StoreTeamRole.ORDERS, '/seller/offers'), false);
  assert.equal(mayActFor(StoreTeamRole.ORDERS, '/seller/store-settings/policies'), false);
});

test('a catalog member works listings — not orders', () => {
  assert.equal(mayActFor(StoreTeamRole.CATALOG, '/seller/offers/abc'), true);
  assert.equal(mayActFor(StoreTeamRole.CATALOG, '/seller/products'), true);
  assert.equal(mayActFor(StoreTeamRole.CATALOG, '/seller/orders'), false);
});

test('a manager reaches the shop, and still never its money or team', () => {
  for (const path of [
    '/seller/orders',
    '/seller/offers',
    '/seller/coupons',
    '/seller/store-settings/shipping',
    '/seller/posts',
  ]) {
    assert.equal(mayActFor(StoreTeamRole.MANAGER, path), true, path);
  }
  for (const role of Object.values(StoreTeamRole)) {
    for (const path of [
      '/finance/seller/earnings',
      '/finance/seller/payout-account',
      '/finance/seller/payouts',
      '/ads/plans/subscribe',
      '/seller/team',
      '/seller/activity',
      '/auth/logout',
      '/users/me',
    ]) {
      assert.equal(mayActFor(role, path), false, `${role} ${path}`);
    }
  }
});

test('a prefix is a whole segment, not a substring', () => {
  assert.equal(mayActFor(StoreTeamRole.ORDERS, '/seller/ordersx'), false);
  assert.equal(mayActFor(StoreTeamRole.CATALOG, '/productsfoo'), false);
});
