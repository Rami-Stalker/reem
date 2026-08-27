export function enumValue(value: unknown) {
  return typeof value === 'string' ? value.toUpperCase() : value;
}

export function enumArray(value: unknown) {
  if (!Array.isArray(value)) return value;
  return value.map(enumValue);
}
