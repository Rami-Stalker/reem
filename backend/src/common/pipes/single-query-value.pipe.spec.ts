import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { SingleQueryValuePipe } from './single-query-value.pipe';

const pipe = new SingleQueryValuePipe();

test('a repeated named query parameter is a 400, not a crash', () => {
  assert.throws(
    () => pipe.transform(['a', 'b'], { type: 'query', data: 'q', metatype: String }),
    BadRequestException,
  );
});

test('a single value passes through unchanged', () => {
  assert.equal(pipe.transform('a', { type: 'query', data: 'q', metatype: String }), 'a');
});

test('a parameter declared as an array may repeat', () => {
  const ids = ['1', '2'];
  assert.equal(pipe.transform(ids, { type: 'query', data: 'ids', metatype: Array }), ids);
});

test('whole-query DTOs and bodies are left to the validation pipe', () => {
  const body = ['x'];
  assert.equal(pipe.transform(body, { type: 'body', metatype: Object }), body);
  const query = { q: ['a', 'b'] };
  assert.equal(pipe.transform(query, { type: 'query', metatype: Object }), query);
});
