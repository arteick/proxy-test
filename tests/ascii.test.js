import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RAMP, glyphIndex, cellFade } from '../src/ascii.js';

test('яркость выбирает глиф от пробела до самого плотного', () => {
  assert.equal(glyphIndex(0), 0);
  assert.equal(glyphIndex(1), RAMP.length - 1);
  assert.equal(glyphIndex(-5), 0);
  assert.equal(glyphIndex(7), RAMP.length - 1);
  assert.ok(glyphIndex(0.5) > glyphIndex(0.2));
});

test('с расстоянием символы сглаживаются в сплошной цвет', () => {
  assert.equal(cellFade(1, 5, 20), 0);
  assert.equal(cellFade(50, 5, 20), 1);
  assert.ok(cellFade(12, 5, 20) > cellFade(8, 5, 20));
});
