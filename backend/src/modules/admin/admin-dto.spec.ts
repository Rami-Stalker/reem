import assert from 'node:assert/strict';
import test from 'node:test';
import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import {
  AdminListQueryDto,
  UpdateProductAdminDto,
  UpdateUserAdminDto,
  UpsertSystemSettingDto,
} from './dto/admin.dto';

/**
 * The admin DTOs, run through the *real* global pipe.
 *
 * `POST /admin/system-settings` had never worked. `value` carried no
 * class-validator decorator, and `main.ts` configures the pipe with
 * `whitelist` and `forbidNonWhitelisted` — which does not merely strip such a
 * property, it rejects the whole request with
 * `400 property value should not exist`. Nothing caught it because nothing
 * called the route: it was an endpoint with no screen behind it.
 *
 * So these tests build the pipe with the same options `main.ts` uses rather
 * than asserting against the decorators in isolation. A DTO that validates in
 * a vacuum and 400s in production is the exact failure being guarded against.
 */
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: { enableImplicitConversion: true },
});

function through<T>(
  metatype: new () => T,
  body: Record<string, unknown>,
): Promise<T> {
  return pipe.transform(body, {
    type: 'body',
    metatype: metatype as never,
  }) as Promise<T>;
}

test('a system setting keeps its value through the whitelist pipe', async () => {
  const dto = await through(UpsertSystemSettingDto, {
    key: 'delivery.rural_surcharge',
    value: { amount: '5000', currency: 'SYP' },
    sensitive: false,
  });

  assert.equal(dto.key, 'delivery.rural_surcharge');
  assert.deepEqual(dto.value, { amount: '5000', currency: 'SYP' });
  assert.equal(dto.sensitive, false);
});

test('a scalar setting value survives too', async () => {
  for (const value of [true, 12, 'حلب']) {
    const dto = await through(UpsertSystemSettingDto, {
      key: 'some.key',
      value,
    });
    assert.deepEqual(dto.value, value);
  }
});

test('a user update carries the reason the audit entry needs', async () => {
  const dto = await through(UpdateUserAdminDto, {
    role: 'finance_admin',
    reason: 'Joins the finance team',
  });

  // The DTO uppercases the role so the console can send what it reads back.
  assert.equal(dto.role, 'FINANCE_ADMIN');
  assert.equal(dto.reason, 'Joins the finance team');
});

test('product curation accepts the homepage flags', async () => {
  const dto = await through(UpdateProductAdminDto, {
    status: 'active',
    is_featured: true,
    show_in_feed: false,
    reason: 'Autumn edit',
  });

  assert.equal(dto.status, 'ACTIVE');
  assert.equal(dto.is_featured, true);
  assert.equal(dto.show_in_feed, false);
});

test('a list query carries page, limit, search and a status filter', async () => {
  const dto = await pipe.transform(
    { page: '2', limit: '50', q: 'ريم', status: 'pending' },
    { type: 'query', metatype: AdminListQueryDto as never },
  );

  assert.equal(dto.page, 2);
  assert.equal(dto.limit, 50);
  assert.equal(dto.q, 'ريم');
  assert.equal(dto.status, 'PENDING');
});

test('the list query still refuses a limit that would page the whole table', async () => {
  await assert.rejects(
    () =>
      pipe.transform(
        { limit: '5000' },
        { type: 'query', metatype: AdminListQueryDto as never },
      ),
    (error: unknown) => {
      // The pipe's own message is generic; what it refused is in the response.
      const response = (error as { getResponse(): { message: string[] } })
        .getResponse();
      assert.ok(
        response.message.some((line) => line.includes('limit')),
        `expected a complaint about limit, got ${JSON.stringify(response.message)}`,
      );
      return true;
    },
  );
});
