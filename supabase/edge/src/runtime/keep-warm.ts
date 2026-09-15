import type { NextFunction, Request, Response } from 'express';

/**
 * Keeps a booted isolate serving requests instead of being dropped after one.
 *
 * Supabase's runtime retires an isolate as soon as it looks idle
 * ("EarlyDrop"), and booting the whole API costs ~0.8 s. While requests keep
 * arriving the isolate is asked to stay (`EdgeRuntime.waitUntil`, registered
 * from inside a request, where the runtime honours it); it lets go once it has
 * been quiet for `REEM_KEEPWARM_IDLE_MS` or has lived `REEM_KEEPWARM_MAX_MS`,
 * below the plan's wall-clock limit (150 s Free, 400 s Pro), so it retires
 * between requests rather than being killed during one.
 */
const IDLE_MS = Number(process.env.REEM_KEEPWARM_IDLE_MS ?? '45000');
const MAX_MS = Number(process.env.REEM_KEEPWARM_MAX_MS ?? '120000');
const DEBUG = () => process.env.REEM_KEEPWARM_DEBUG === 'true';

let inFlight = 0;
let served = 0;
let lastActivity = Date.now();
let holding = false;
const bornAt = Date.now();

function holdIsolate() {
  // Off by default: measured on Supabase, isolates are not reused across
  // requests even when held, so holding one only keeps its database
  // connection open. Kept for runtimes that do reuse (REEM_KEEPWARM=true).
  if (process.env.REEM_KEEPWARM !== 'true') return;
  if (holding) return;
  if (typeof EdgeRuntime === 'undefined' || typeof EdgeRuntime?.waitUntil !== 'function') return;
  holding = true;
  EdgeRuntime.waitUntil(
    new Promise<void>((resolve) => {
      const timer = setInterval(() => {
        if (inFlight > 0) return;
        const now = Date.now();
        if (now - lastActivity >= IDLE_MS || now - bornAt >= MAX_MS) {
          clearInterval(timer);
          holding = false;
          resolve();
        }
      }, 1000);
    }),
  );
}

export function trackRequests(req: Request, res: Response, next: NextFunction) {
  inFlight += 1;
  served += 1;
  lastActivity = Date.now();
  if (DEBUG()) {
    console.log(`[reem-api] request #${served} in this isolate (age ${Math.round((Date.now() - bornAt) / 1000)}s)`);
  }
  holdIsolate();
  let settled = false;
  const done = () => {
    if (settled) return;
    settled = true;
    inFlight -= 1;
    lastActivity = Date.now();
  };
  res.on('finish', done);
  res.on('close', done);
  next();
}

/** Kept for the boot path; the hold is taken on the first request. */
export function keepIsolateWarm(): void {
  holdIsolate();
}
