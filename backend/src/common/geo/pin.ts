/**
 * A map pin as it arrives on a request: two optional numbers that only mean
 * something together.
 *
 * Half a pin is no pin. A latitude without its longitude cannot take a
 * courier anywhere, so rather than store a coordinate that points at a line
 * across the planet, both are dropped.
 */
export interface PinInput {
  latitude?: number | null;
  longitude?: number | null;
}

export interface Pin {
  latitude: number | null;
  longitude: number | null;
}

export function pinOf(input: PinInput): Pin {
  const { latitude, longitude } = input;
  if (
    typeof latitude === 'number' &&
    typeof longitude === 'number' &&
    Number.isFinite(latitude) &&
    Number.isFinite(longitude)
  ) {
    return { latitude, longitude };
  }
  return { latitude: null, longitude: null };
}

/** True when the request said anything about the pin, to set or to clear. */
export function mentionsPin(input: PinInput): boolean {
  return input.latitude !== undefined || input.longitude !== undefined;
}
