import { DeliveryProviderBootstrap } from '../../../../backend/src/modules/delivery/dispatch/delivery-provider.bootstrap';
import { MarketScheduler } from '../../../../backend/src/modules/market/market.scheduler';

/**
 * Start-up writes that a server does once, and an isolate would do per request.
 *
 * On a server these hooks run when the process starts: `MarketScheduler`
 * upserts the mission catalogue (six writes) and `DeliveryProviderBootstrap`
 * makes sure a default carrier exists. Supabase starts a fresh isolate for
 * almost every request, so the same hooks would write to the database on
 * nearly every API call and add their latency to it.
 *
 * On the edge they are deferred: the originals are kept here and run once per
 * deployment through `POST /internal/cron/boot-seeds`, which the deploy script
 * calls. Both are idempotent, exactly as on a server. Set
 * `REEM_RUN_BOOT_SEEDS=true` to run them at every start instead.
 */
type Hook = (this: unknown) => Promise<void>;

const originals = {
  market: MarketScheduler.prototype.onModuleInit as Hook,
  delivery: DeliveryProviderBootstrap.prototype.onModuleInit as Hook,
};

export function deferBootSeeds(): void {
  if (process.env.REEM_RUN_BOOT_SEEDS === 'true') return;
  MarketScheduler.prototype.onModuleInit = async function deferredToDeploy() {};
  DeliveryProviderBootstrap.prototype.onModuleInit = async function deferredToDeploy() {};
}

export async function runBootSeeds(instances: { market: unknown; delivery: unknown }): Promise<void> {
  await originals.market.call(instances.market);
  await originals.delivery.call(instances.delivery);
}
