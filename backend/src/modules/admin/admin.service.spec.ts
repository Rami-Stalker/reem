import assert from 'node:assert/strict';
import test from 'node:test';
import { AdminService } from './admin.service';

const service = Object.create(AdminService.prototype) as {
  formatTrend(current: number, previous: number): string;
  formatPointTrend(current: number, previous: number): string;
};

test('formatTrend reports positive, negative, and zero baselines', () => {
  assert.equal(service.formatTrend(150, 100), '+50%');
  assert.equal(service.formatTrend(75, 100), '-25%');
  assert.equal(service.formatTrend(0, 0), '+0%');
  assert.equal(service.formatTrend(42, 0), '+100%');
});

test('formatPointTrend reports percentage-point movement', () => {
  assert.equal(service.formatPointTrend(12.25, 10), '+2.3%');
  assert.equal(service.formatPointTrend(9.9, 10), '-0.1%');
});
