export const RAMP = ' .:-=+*#%@';

export function glyphIndex(lum, n = RAMP.length) {
  const l = Math.min(1, Math.max(0, lum));
  return Math.round(l * (n - 1));
}

// 0 вблизи (символы видны), 1 вдали (сплошной цвет)
export function cellFade(dist, near, far) {
  const t = Math.min(1, Math.max(0, (dist - near) / (far - near)));
  return t * t * (3 - 2 * t);
}
