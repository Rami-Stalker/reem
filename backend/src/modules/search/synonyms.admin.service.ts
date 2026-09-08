import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UnmetDemandStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { searchKey } from './arabic';
import { SynonymsService } from './synonyms.service';

/**
 * The merchandiser's side of the thesaurus.
 *
 * The loop this closes: `TrendSignalService` has been recording every search
 * that returned nothing since the trends work, and until now that list had
 * nowhere to go. A term with real volume and no results is usually not a gap
 * in the catalogue — it is a word the catalogue does not use. `unanswered()`
 * puts those terms in front of somebody who can say what they mean.
 */
@Injectable()
export class SynonymsAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly synonyms: SynonymsService,
  ) {}

  async list() {
    const groups = await this.prisma.searchSynonymGroup.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        terms: { orderBy: { createdAt: 'asc' } },
        createdBy: { select: { id: true, name: true } },
      },
    });
    return groups.map((group) => this.serialize(group));
  }

  async create(input: { terms: string[]; note?: string; actorId: string }) {
    const terms = this.normalise(input.terms);
    if (terms.length < 2) {
      throw new BadRequestException(
        'A synonym group needs at least two distinct words — one word is not a synonym of anything',
      );
    }
    await this.assertUnclaimed(terms.map((t) => t.key));

    const group = await this.prisma.searchSynonymGroup.create({
      data: {
        note: input.note ?? null,
        createdById: input.actorId,
        terms: { create: terms.map((t) => ({ term: t.term, termKey: t.key })) },
      },
      include: {
        terms: { orderBy: { createdAt: 'asc' } },
        createdBy: { select: { id: true, name: true } },
      },
    });

    this.synonyms.invalidate();
    return this.serialize(group);
  }

  async addTerm(groupId: string, term: string) {
    await this.requireGroup(groupId);
    const [normalised] = this.normalise([term]);
    if (!normalised) {
      throw new BadRequestException('That word has nothing to match on');
    }
    await this.assertUnclaimed([normalised.key], groupId);

    await this.prisma.searchSynonymTerm.create({
      data: { groupId, term: normalised.term, termKey: normalised.key },
    });
    this.synonyms.invalidate();
    return this.get(groupId);
  }

  async removeTerm(groupId: string, termId: string) {
    await this.requireGroup(groupId);
    const deleted = await this.prisma.searchSynonymTerm.deleteMany({
      where: { id: termId, groupId },
    });
    if (deleted.count === 0) throw new NotFoundException('Term not found');
    this.synonyms.invalidate();
    return this.get(groupId);
  }

  async setActive(groupId: string, isActive: boolean) {
    await this.requireGroup(groupId);
    await this.prisma.searchSynonymGroup.update({
      where: { id: groupId },
      data: { isActive },
    });
    this.synonyms.invalidate();
    return this.get(groupId);
  }

  async remove(groupId: string) {
    await this.requireGroup(groupId);
    await this.prisma.searchSynonymGroup.delete({ where: { id: groupId } });
    this.synonyms.invalidate();
    return { message: 'Synonym group deleted' };
  }

  /**
   * Terms the catalogue never answered, loudest first, minus the ones the
   * thesaurus already covers.
   *
   * The source is `UnmetDemandSignal`, not the raw event stream: the trends
   * run already aggregates zero-result searches nightly into a rolling window
   * with a miss rate and a demand score, and re-counting the same events here
   * would produce a second, quieter number that disagreed with the buying
   * team's screen.
   *
   * A term reaching this list is one of two things, and the merchandiser is
   * the one who can tell them apart: a genuine hole in the catalogue — which
   * belongs to the buyers and is already on their screen — or a word for
   * something the shop stocks under another name, which is one click from
   * being fixed here.
   *
   * `display` is folded through `searchKey` for the comparison rather than
   * trusting `termKey`, which is the trends module's own normal form and not
   * this one.
   */
  async unanswered(limit: number) {
    const signals = await this.prisma.unmetDemandSignal.findMany({
      where: { status: UnmetDemandStatus.OPEN, zeroResults: { gt: 0 } },
      orderBy: { demandScore: 'desc' },
      take: limit * 3,
      select: {
        display: true,
        searches: true,
        zeroResults: true,
        missRate: true,
        demandScore: true,
        suggestedCategory: { select: { slug: true, nameAr: true } },
      },
    });

    const covered = new Set(
      (
        await this.prisma.searchSynonymTerm.findMany({
          select: { termKey: true },
        })
      ).map((term) => term.termKey),
    );

    return signals
      .map((signal) => ({ signal, key: searchKey(signal.display) }))
      .filter(({ key }) => key.length > 0 && !covered.has(key))
      .slice(0, limit)
      .map(({ signal, key }) => ({
        term: signal.display,
        key,
        searches: signal.searches,
        zero_results: signal.zeroResults,
        miss_rate: signal.missRate,
        demand_score: signal.demandScore,
        suggested_category: signal.suggestedCategory
          ? {
              slug: signal.suggestedCategory.slug,
              name: signal.suggestedCategory.nameAr,
            }
          : null,
      }));
  }

  private async get(groupId: string) {
    const group = await this.prisma.searchSynonymGroup.findUnique({
      where: { id: groupId },
      include: {
        terms: { orderBy: { createdAt: 'asc' } },
        createdBy: { select: { id: true, name: true } },
      },
    });
    if (!group) throw new NotFoundException('Synonym group not found');
    return this.serialize(group);
  }

  private async requireGroup(groupId: string) {
    const group = await this.prisma.searchSynonymGroup.findUnique({
      where: { id: groupId },
      select: { id: true },
    });
    if (!group) throw new NotFoundException('Synonym group not found');
    return group;
  }

  /**
   * A word already in another group is refused rather than moved.
   *
   * The unique key on `term_key` would refuse it anyway, with a database error
   * nobody can act on. Saying which group holds it turns that into a decision:
   * the merchandiser either meant to extend that group, or the two groups are
   * really one.
   */
  private async assertUnclaimed(keys: string[], allowGroupId?: string) {
    const clash = await this.prisma.searchSynonymTerm.findFirst({
      where: {
        termKey: { in: keys },
        ...(allowGroupId ? { groupId: { not: allowGroupId } } : {}),
      },
      include: { group: { select: { id: true, note: true } } },
    });
    if (clash) {
      throw new BadRequestException(
        `«${clash.term}» already belongs to the group «${
          clash.group.note ?? clash.group.id
        }». A word can only mean one thing — extend that group instead.`,
      );
    }
  }

  /** Trims, folds, and drops anything that leaves no key or repeats one. */
  private normalise(terms: string[]): { term: string; key: string }[] {
    const seen = new Set<string>();
    const out: { term: string; key: string }[] = [];
    for (const raw of terms) {
      const term = raw.trim();
      const key = searchKey(term);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      out.push({ term, key });
    }
    return out;
  }

  private serialize(group: {
    id: string;
    note: string | null;
    isActive: boolean;
    createdAt: Date;
    terms: { id: string; term: string; termKey: string }[];
    createdBy?: { id: string; name: string } | null;
  }) {
    return {
      id: group.id,
      note: group.note,
      is_active: group.isActive,
      created_at: group.createdAt.toISOString(),
      created_by: group.createdBy
        ? { id: group.createdBy.id, name: group.createdBy.name }
        : null,
      terms: group.terms.map((term) => ({
        id: term.id,
        term: term.term,
        key: term.termKey,
      })),
    };
  }
}
