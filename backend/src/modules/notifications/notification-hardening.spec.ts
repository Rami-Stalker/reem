import 'reflect-metadata';
import assert from 'node:assert/strict';
import test from 'node:test';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { SessionStatus } from '@prisma/client';
import {
  CreateCampaignDto,
  DispatchNotificationDto,
  RegisterPushTokenDto,
  TrackNotificationEventDto,
} from './dto/notification-engine.dto';
import { liveTokenWhere } from './notifications.service';

/**
 * The guards around who gets a push and what an operator may send.
 *
 * Validation runs the way the global pipe runs it, so a case that passes here
 * is a request the API would accept.
 */

function errors<T extends object>(cls: new () => T, body: object): string[] {
  const instance = plainToInstance(cls, body, {
    enableImplicitConversion: true,
  });
  return validateSync(instance, {
    whitelist: true,
    forbidNonWhitelisted: true,
  }).flatMap((error) => [
    error.property,
    ...(error.children ?? []).map((child) => `${error.property}.${child.property}`),
  ]);
}

const dispatch = {
  channels: ['push'],
  title: 'عرض',
  body: 'خصم اليوم',
};

test('a push only goes to a signed-in session on a live account', () => {
  const where = liveTokenWhere('user-1');
  assert.equal(where.userId, 'user-1');
  assert.equal(where.enabled, true);
  assert.deepEqual(where.user, { disabledAt: null });
  assert.deepEqual(where.OR, [
    { sessionId: null },
    { session: { status: SessionStatus.ACTIVE } },
  ]);
});

test('a campaign link must stay inside the app', () => {
  const base = { ...dispatch, name: 'حملة' };
  assert.deepEqual(
    errors(CreateCampaignDto, { ...base, deep_link: 'reem://coupons' }),
    [],
  );
  for (const link of [
    'https://evil.example/login',
    'javascript:alert(1)',
    'reem://home\n<script>',
  ]) {
    assert.ok(
      errors(CreateCampaignDto, { ...base, deep_link: link }).includes('deep_link'),
      link,
    );
  }
});

test('a schedule must be a real instant', () => {
  const base = { ...dispatch, name: 'حملة' };
  assert.deepEqual(
    errors(CreateCampaignDto, { ...base, scheduled_at: '2026-11-01T09:00:00Z' }),
    [],
  );
  assert.ok(
    errors(CreateCampaignDto, { ...base, scheduled_at: 'tomorrow' }).includes(
      'scheduled_at',
    ),
  );
});

test('recipients are account ids, not arbitrary strings', () => {
  assert.ok(
    errors(DispatchNotificationDto, { ...dispatch, user_ids: ['1 OR 1=1'] }).includes(
      'user_ids',
    ),
  );
  assert.deepEqual(
    errors(DispatchNotificationDto, {
      ...dispatch,
      user_ids: ['6f1c9b8e-6a0e-4c43-9a51-1f0f7d0f8e11'],
    }),
    [],
  );
});

test('a segment is validated field by field', () => {
  assert.deepEqual(
    errors(DispatchNotificationDto, {
      ...dispatch,
      segment: { roles: ['customer'], inactive_days: 30 },
    }),
    [],
  );
  const bad = errors(DispatchNotificationDto, {
    ...dispatch,
    segment: { roles: ['ROOT'], inactive_days: -5 },
  });
  assert.ok(bad.includes('segment.roles'));
  assert.ok(bad.includes('segment.inactive_days'));
});

test('a dispatch must name at least one channel', () => {
  assert.ok(
    errors(DispatchNotificationDto, { ...dispatch, channels: [] }).includes('channels'),
  );
});

test('a read receipt can only be one of the four events', () => {
  assert.deepEqual(errors(TrackNotificationEventDto, { event: 'opened' }), []);
  assert.ok(
    errors(TrackNotificationEventDto, { event: 'hacked' }).includes('event'),
  );
});

test('a push token names a provider the platform speaks', () => {
  assert.deepEqual(
    errors(RegisterPushTokenDto, { token: 'abc', provider: 'fcm' }),
    [],
  );
  assert.ok(
    errors(RegisterPushTokenDto, { token: 'abc', provider: 'anything' }).includes(
      'provider',
    ),
  );
});
