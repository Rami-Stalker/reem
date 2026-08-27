import assert from 'node:assert/strict';
import test from 'node:test';
import { validatePayloadAgainstSchema } from './content-type-registry.service';

test('commerce content payload validation accepts configured schemas', () => {
  const schema = {
    type: 'object',
    required: ['caption', 'hashtags'],
    properties: {
      caption: { type: 'string' },
      hashtags: { type: 'array', items: { type: 'string' } },
    },
  };

  assert.deepEqual(
    validatePayloadAgainstSchema(schema, {
      caption: 'New collection just landed',
      hashtags: ['new', 'summer'],
    }),
    [],
  );
});

test('commerce content payload validation reports missing and invalid fields', () => {
  const schema = {
    type: 'object',
    required: ['headline'],
    properties: {
      headline: { type: 'string' },
      discount: { type: 'number' },
      products: { type: 'array', items: { type: 'string' } },
    },
  };

  assert.deepEqual(
    validatePayloadAgainstSchema(schema, {
      discount: '25',
      products: ['a', 42],
    }),
    [
      { path: 'headline', message: 'Required field is missing' },
      { path: 'discount', message: 'Expected number, received string' },
      { path: 'products.1', message: 'Expected string, received integer' },
    ],
  );
});
