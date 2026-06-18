import { Request } from 'express';

export interface RequestContext {
  ipAddress?: string;
  userAgent?: string;
  deviceId?: string;
  deviceName?: string;
  platform?: string;
  appVersion?: string;
  fingerprint?: string;
}

const firstHeader = (value: string | string[] | undefined) =>
  Array.isArray(value) ? value[0] : value;

export function requestContextFrom(req: Request): RequestContext {
  const forwardedFor = firstHeader(req.headers['x-forwarded-for']);
  const clientIp = forwardedFor?.split(',')[0]?.trim() || req.ip;

  return {
    ipAddress: clientIp,
    userAgent: firstHeader(req.headers['user-agent']),
    deviceId: firstHeader(req.headers['x-reem-device-id']),
    deviceName: firstHeader(req.headers['x-reem-device-name']),
    platform: firstHeader(req.headers['x-reem-platform']),
    appVersion: firstHeader(req.headers['x-reem-app-version']),
    fingerprint: firstHeader(req.headers['x-reem-device-fingerprint']),
  };
}
