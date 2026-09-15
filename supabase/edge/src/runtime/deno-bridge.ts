import inject from 'light-my-request';
import type { RequestListener } from 'node:http';

/**
 * Serves the Express application through `Deno.serve`.
 *
 * Supabase's runtime routes requests to a warm isolate only when the isolate
 * serves them with `Deno.serve`. The API used to `listen()` through the
 * `node:http` compatibility layer, which the runtime treats as a one-shot: every
 * request booted a fresh copy of the whole API (~0.8 s) and the previous copy
 * was dropped. Here the Web `Request` is handed to Express in memory — the
 * same `(req, res)` Express receives from a socket — and its answer becomes the
 * `Response`. Nothing above this file can tell the difference.
 */
const HOP_BY_HOP = new Set(['connection', 'keep-alive', 'transfer-encoding', 'upgrade', 'proxy-connection']);

type DenoServe = (
  options: { port?: number; hostname?: string; onListen?: () => void },
  handler: (request: Request) => Promise<Response>,
) => unknown;

export function serveWithDeno(handler: RequestListener, port?: number): void {
  const deno = (globalThis as { Deno?: { serve: DenoServe } }).Deno;
  if (!deno) throw new Error('Deno.serve is not available in this runtime');

  deno.serve({ ...(port ? { port } : {}), onListen: () => undefined }, async (request) => {
    const url = new URL(request.url);
    const headers: Record<string, string> = {};
    request.headers.forEach((value, key) => {
      headers[key] = value;
    });
    const hasBody = request.method !== 'GET' && request.method !== 'HEAD' && request.body !== null;
    const payload = hasBody ? Buffer.from(await request.arrayBuffer()) : undefined;

    const response = await inject(handler as never, {
      method: request.method as never,
      url: `${url.pathname}${url.search}`,
      headers,
      payload,
      remoteAddress: headers['x-forwarded-for']?.split(',')[0]?.trim() || '127.0.0.1',
    });

    const outgoing = new Headers();
    for (const [key, value] of Object.entries(response.headers)) {
      if (value === undefined || HOP_BY_HOP.has(key.toLowerCase())) continue;
      if (Array.isArray(value)) value.forEach((item) => outgoing.append(key, String(item)));
      else outgoing.set(key, String(value));
    }
    const noBody = request.method === 'HEAD' || response.statusCode === 204 || response.statusCode === 304;
    return new Response(noBody ? null : new Uint8Array(response.rawPayload), {
      status: response.statusCode,
      headers: outgoing,
    });
  });
}
