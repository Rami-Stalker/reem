import assert from 'node:assert/strict';
import test from 'node:test';
import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { MessageQueryDto } from './dto/chat.dto';

/**
 * The message-list query, run through the *real* global pipe.
 *
 * Opening a conversation failed for everyone: the app always sends
 * `?limit=50`, and `limit = 50` (no type annotation) was recorded as `Object`,
 * so implicit conversion left the string `"50"` alone and `@IsInt` refused it.
 * The integration spec calls the service directly and never saw it.
 */
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: { enableImplicitConversion: true },
});

function query(raw: Record<string, string>): Promise<MessageQueryDto> {
  return pipe.transform(raw, {
    type: 'query',
    metatype: MessageQueryDto as never,
  }) as Promise<MessageQueryDto>;
}

test('the query string the app sends is accepted and converted', async () => {
  const dto = await query({ limit: '50' });
  assert.equal(dto.limit, 50);
  assert.equal(dto.page, 1);
});

test('scrolling back with a cursor is accepted', async () => {
  const dto = await query({
    limit: '30',
    before: '2026-10-30T00:00:00.000Z',
  });
  assert.equal(dto.limit, 30);
  assert.equal(dto.before, '2026-10-30T00:00:00.000Z');
});

test('page arrives as a number too', async () => {
  const dto = await query({ page: '2', limit: '20' });
  assert.equal(dto.page, 2);
});

test('limits outside 1..100 are still refused', async () => {
  await assert.rejects(query({ limit: '0' }));
  await assert.rejects(query({ limit: '101' }));
  await assert.rejects(query({ limit: 'abc' }));
});
