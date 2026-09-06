import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { VisualSearchStatus, VisualTryOnStatus } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { MediaService } from '../../media/media.service';

export interface RetentionSweep {
  queryImagesDeleted: number;
  tryOnImagesDeleted: number;
}

/**
 * The clock that makes the privacy promise real.
 *
 * A retention policy that is written down and not executed is not a policy. So
 * this is a job, it runs on a short interval, it deletes bytes off the disk
 * rather than hiding rows, and it is the only thing in the platform that
 * deletes a photograph its uploader never asked to delete.
 *
 * ── What survives a sweep, and why that is the right line ────────────────
 *
 * The **photograph** goes. The **session** stays: its descriptor, the
 * attributes read from it, and the products it matched. That distinction is
 * deliberate and it is the difference between a feature that respects her and
 * one that is merely forgetful.
 *
 *  - A 184-float descriptor is not a picture of anybody. It cannot be turned
 *    back into her screenshot, it identifies no person in the frame, and it
 *    carries no metadata. Keeping it is what lets her reopen last week's
 *    search, refine it in words, and get an answer without uploading again.
 *  - The photograph is the sensitive artefact, and its functional life ends
 *    when the search does. A day is generous for "let her scroll back to what
 *    she uploaded this morning"; two hours is right for a photograph of her
 *    body, which is why try-on has its own, shorter hand.
 *
 * `DELETE /visual-search/sessions/:id` is the same operation on demand: this
 * is the platform's floor, not her ceiling.
 */
@Injectable()
export class VisualRetentionService {
  private readonly logger = new Logger(VisualRetentionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
  ) {}

  /**
   * Every fifteen minutes, not nightly.
   *
   * The unit being deleted is a photograph somebody uploaded an hour ago, and
   * the gap between "the retention window says it is gone" and "it is actually
   * gone" is the part of the promise that can be broken. Fifteen minutes keeps
   * that gap smaller than any window this feature offers.
   */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async scheduled(): Promise<void> {
    await this.sweep();
  }

  async sweep(now = new Date()): Promise<RetentionSweep> {
    const summary: RetentionSweep = { queryImagesDeleted: 0, tryOnImagesDeleted: 0 };

    // ── Search query images ─────────────────────────────────────────────
    const sessions = await this.prisma.visualSearchSession.findMany({
      where: {
        queryAssetId: { not: null },
        imageExpiresAt: { lte: now },
      },
      select: { id: true, queryAssetId: true },
      take: 500,
    });

    for (const session of sessions) {
      try {
        if (session.queryAssetId) await this.media.purge(session.queryAssetId);
        await this.prisma.visualSearchSession.update({
          where: { id: session.id },
          data: {
            queryAssetId: null,
            imageExpiresAt: null,
            // The session is not failed and not deleted — the descriptor still
            // answers refinements. `EXPIRED` says exactly what happened: the
            // picture is gone and the search remains.
            status: VisualSearchStatus.EXPIRED,
          },
        });
        summary.queryImagesDeleted += 1;
      } catch (error) {
        this.logger.warn(
          `Could not expire the query image on session ${session.id}: ${String(error)}`,
        );
      }
    }

    // ── Try-on images ───────────────────────────────────────────────────
    const tryOns = await this.prisma.visualTryOnRequest.findMany({
      where: {
        expiresAt: { lte: now },
        OR: [{ sourceAssetId: { not: null } }, { resultAssetId: { not: null } }],
      },
      select: { id: true, sourceAssetId: true, resultAssetId: true, status: true },
      take: 500,
    });

    for (const request of tryOns) {
      try {
        if (request.sourceAssetId) await this.media.purge(request.sourceAssetId);
        if (request.resultAssetId) await this.media.purge(request.resultAssetId);
        await this.prisma.visualTryOnRequest.update({
          where: { id: request.id },
          data: {
            sourceAssetId: null,
            resultAssetId: null,
            // A request that never rendered keeps its own status; one that did
            // becomes REVOKED, because the result no longer exists and calling
            // it READY would be a link to nothing.
            status:
              request.status === VisualTryOnStatus.READY
                ? VisualTryOnStatus.REVOKED
                : request.status,
          },
        });
        summary.tryOnImagesDeleted += 1;
      } catch (error) {
        this.logger.warn(
          `Could not expire the images on try-on ${request.id}: ${String(error)}`,
        );
      }
    }

    if (summary.queryImagesDeleted || summary.tryOnImagesDeleted) {
      this.logger.log(
        `Retention: deleted ${summary.queryImagesDeleted} query image(s) and ` +
          `${summary.tryOnImagesDeleted} try-on image(s).`,
      );
    }
    return summary;
  }
}
