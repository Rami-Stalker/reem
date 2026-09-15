/**
 * Work that must outlive the response.
 *
 * On a server, a promise left running after `res.end()` simply finishes. An
 * edge isolate may be retired as soon as it has answered and looks idle, so
 * anything still in flight — a Realtime broadcast, an event listener's write —
 * is handed to `EdgeRuntime.waitUntil`, which keeps the isolate alive until it
 * settles. Under plain Deno or Node (local runs) the promise just runs.
 */
export function trackBackgroundWork(promise: Promise<unknown>): void {
  const settled = promise.catch(() => undefined);
  if (typeof EdgeRuntime !== 'undefined' && EdgeRuntime?.waitUntil) {
    EdgeRuntime.waitUntil(settled);
  }
}
