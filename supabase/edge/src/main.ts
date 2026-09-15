import 'reflect-metadata';
import { installEdgePatches } from './runtime/patches';
import { prepareEnvironment } from './runtime/env';
import { serveWithDeno } from './runtime/deno-bridge';
import { keepIsolateWarm } from './runtime/keep-warm';

/**
 * Entry point of the `api` Edge Function.
 *
 * Order matters: the environment is translated before the application is
 * imported, because `ConfigModule.forRoot` validates `process.env` the moment
 * `AppModule` is evaluated.
 */
async function bootstrap(): Promise<void> {
  const startedAt = Date.now();
  // Not implemented on Supabase's runtime (it warns and returns zeros); only
  // meaningful locally.
  const cpuAtStart = process.env.REEM_BOOT_METRICS === 'true' ? safeCpuUsage() : null;
  const runtime = prepareEnvironment();
  installEdgePatches();

  const phases: string[] = [];
  const mark = (label: string, since: number) => phases.push(`${label} ${Date.now() - since}ms`);
  let t = Date.now();
  (await import('./runtime/boot-seeds')).deferBootSeeds();
  const { createEdgeApp } = await import('./edge-app');
  mark('load', t);
  t = Date.now();
  const app = await createEdgeApp(runtime);
  mark('compose', t);
  // Initialised, not listening: requests arrive through Deno.serve.
  t = Date.now();
  await app.init();
  mark('init', t);
  if (process.env.REEM_BOOT_METRICS === 'true') console.log(`[reem-api] boot phases: ${phases.join(', ')}`);
  serveWithDeno(
    app.getHttpAdapter().getInstance(),
    process.env.PORT ? Number(process.env.PORT) : undefined,
  );
  keepIsolateWarm();

  if (process.env.REEM_BOOT_METRICS === 'true') {
    // Cold starts are the one cost this deployment adds over a server; the
    // number is logged so it can be watched against the 2 s CPU budget.
    // On Supabase the platform logs each isolate's CPU itself.
    const cpu = cpuAtStart ? safeCpuUsage(cpuAtStart) : null;
    const cpuText = cpu && cpu.user + cpu.system > 0 ? `, ${Math.round((cpu.user + cpu.system) / 1000)}ms cpu` : '';
    console.log(`[reem-api] booted in ${Date.now() - startedAt}ms wall${cpuText}`);
  }
}

function safeCpuUsage(previous?: NodeJS.CpuUsage): NodeJS.CpuUsage | null {
  try {
    return process.cpuUsage(previous);
  } catch {
    return null;
  }
}

bootstrap().catch((error: unknown) => {
  // A function that failed to boot must still answer, or every request
  // hangs until the gateway times out and nobody sees why.
  const message = error instanceof Error ? `${error.message}\n${error.stack ?? ''}` : String(error);
  console.error(`[reem-api] boot failed: ${message.slice(0, 4000)}`);
  const deno = (globalThis as { Deno?: { serve(handler: () => Response): unknown } }).Deno;
  deno?.serve(
    () =>
      new Response(
        JSON.stringify({ statusCode: 503, error: 'Service Unavailable', message: 'The API failed to start' }),
        { status: 503, headers: { 'Content-Type': 'application/json' } },
      ),
  );
});
