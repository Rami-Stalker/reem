import { Module } from '@nestjs/common';
import { AiStylistModule } from '../ai-stylist/ai-stylist.module';
import { ClosetController } from './closet.controller';
import { ClosetService } from './closet.service';
import { ClosetIntakeService } from './closet-intake.service';
import { ClosetGapService } from './gaps/closet-gap.service';
import { ClosetItemService } from './items/closet-item.service';
import { ClosetLookService } from './looks/closet-look.service';
import { ClosetSuggestionService } from './suggestions/closet-suggestion.service';
import { ClosetTodayService } from './today/today.service';

/**
 * Ohara Closet.
 *
 * The wardrobe layer: what she owns, what she puts together with it, what it is
 * short of, and what to wear today. Sits above the catalog rather than beside
 * it — every other commerce module in this application answers "what can she
 * buy", and this one answers "what does she have", from which the first question
 * gets a much better answer.
 *
 * ── What it deliberately does not own ────────────────────────────────────
 *
 * No search, no ranking, no notion of a live offer, and no language model. A
 * gap becomes a `StyleBrief` and is answered by `AiStylistModule`'s existing
 * `ProductRetrievalService` and `rankProducts`, with `scorePairing` riding on
 * top as a bounded adjustment. That import is the whole integration, and it buys
 * a guarantee worth more than the code it saved: a closet suggestion cannot show
 * a product the stylist would refuse to show, because the modesty filter, the
 * purchasable predicate and the relaxation ladder are enforced once for both.
 *
 * ── Where the next features attach ───────────────────────────────────────
 *
 * The seams are already cut, and all four are new *writers* into tables that
 * exist rather than new tables:
 *
 *  - **Photo intake.** `VisualSearchModule` already turns a photograph into a
 *    perceptual descriptor and a set of matched products. Pointing it at
 *    `ClosetItemService.addPersonal` turns "صوّري خزانتك" into a bulk import,
 *    and the colours it detects land in the same `colours` array the lexicon
 *    fills today.
 *  - **Try-on.** `VisualTryOnRequest` takes a product and a photo of her; a
 *    `ClosetLook` is a resolved set of products and owned pieces, which is the
 *    same input with more of it.
 *  - **Trend-aware gaps.** `ProductTrendScore` and `TrendForecast` are keyed by
 *    product and category; a sixth rule in `gap-engine.ts` could raise the
 *    priority of a slot that is climbing. It would be arithmetic over rows, like
 *    the five that are there.
 *  - **Shared looks.** `ClosetLook` is already the shape a post would need. Note
 *    what is *not* shareable and should not become so: the item inventory. See
 *    the note on `ClosetController`.
 */
@Module({
  // For `ProductRetrievalService`, `rankProducts` and the style profile. The
  // stylist module exports the first and the last; the ranker is a pure
  // function and is imported directly.
  imports: [AiStylistModule],
  controllers: [ClosetController],
  providers: [
    ClosetService,
    ClosetItemService,
    ClosetLookService,
    ClosetGapService,
    ClosetSuggestionService,
    ClosetTodayService,
    ClosetIntakeService,
  ],
  // `ClosetItemService` and `ClosetSuggestionService` are exported for the
  // product page's "already in your closet" badge and its pairing panel, which
  // are served by the products module.
  exports: [ClosetService, ClosetItemService, ClosetSuggestionService],
})
export class ClosetModule {}
