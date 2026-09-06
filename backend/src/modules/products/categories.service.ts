import { Injectable, NotFoundException } from '@nestjs/common';
import { Category } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeCategory } from '../../common/serializers';

type CategoryNode = ReturnType<typeof serializeCategory> & {
  is_leaf: boolean;
  sort_order: number;
  children: CategoryNode[];
};

/**
 * The catalog's category tree.
 *
 * It had no reader at all, which is how the seller's product form ended up
 * asking a woman to type a category slug by hand into a free-text box while
 * `POST /seller/products` demanded the UUID of a LEAF category. Nothing she
 * could type would have worked. The tree is small, changes rarely, and is
 * read on every product form, so it is cached in process for a minute rather
 * than re-walked per keystroke.
 */
@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  private cache: { at: number; tree: CategoryNode[] } | null = null;
  private static readonly TTL_MS = 60_000;

  async tree(): Promise<CategoryNode[]> {
    const fresh = this.cache && Date.now() - this.cache.at < CategoriesService.TTL_MS;
    if (fresh) return this.cache!.tree;

    const rows = await this.prisma.category.findMany({
      where: { isActive: true },
      orderBy: [{ level: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
    });

    const tree = this.assemble(rows);
    this.cache = { at: Date.now(), tree };
    return tree;
  }

  /** Every leaf, flattened, each carrying the path a picker shows as a crumb. */
  async leaves() {
    const tree = await this.tree();
    const out: (CategoryNode & { path: string[] })[] = [];

    const walk = (node: CategoryNode, trail: string[]) => {
      const path = [...trail, node.name_ar];
      if (node.is_leaf) out.push({ ...node, path });
      else node.children.forEach((child) => walk(child, path));
    };

    tree.forEach((root) => walk(root, []));
    return out;
  }

  /**
   * One category, with the attribute schema it actually governs by. A null
   * schema means "inherit", so the answer is the nearest ancestor that defines
   * one — resolving it here keeps that rule in a single place instead of in
   * every client that wants to render the extra fields (Q27 P2).
   */
  async detail(id: string) {
    const category = await this.prisma.category.findUnique({
      where: { id },
      include: { sizeChart: true },
    });
    if (!category || !category.isActive) {
      throw new NotFoundException('Category not found');
    }

    const children = await this.prisma.category.count({
      where: { parentId: id, isActive: true },
    });

    return {
      ...serializeCategory(category),
      is_leaf: children === 0,
      attribute_schema: await this.resolveSchema(category),
      size_chart: category.sizeChart
        ? {
            id: category.sizeChart.id,
            slug: category.sizeChart.slug,
            name_ar: category.sizeChart.nameAr,
            name_en: category.sizeChart.nameEn,
            columns: category.sizeChart.columns,
            rows: category.sizeChart.rows,
          }
        : null,
    };
  }

  private async resolveSchema(category: Category): Promise<unknown> {
    let current: Category | null = category;
    // The tree is three levels deep; the guard is against a cycle, not depth.
    for (let hop = 0; current && hop < 8; hop += 1) {
      if (current.attributeSchema !== null) return current.attributeSchema;
      if (!current.parentId) return null;
      current = await this.prisma.category.findUnique({
        where: { id: current.parentId },
      });
    }
    return null;
  }

  private assemble(rows: Category[]): CategoryNode[] {
    const nodes = new Map<string, CategoryNode>();
    for (const row of rows) {
      nodes.set(row.id, {
        ...serializeCategory(row),
        is_leaf: true,
        sort_order: row.sortOrder,
        children: [],
      });
    }

    const roots: CategoryNode[] = [];
    for (const row of rows) {
      const node = nodes.get(row.id)!;
      const parent = row.parentId ? nodes.get(row.parentId) : undefined;
      if (parent) {
        parent.is_leaf = false;
        parent.children.push(node);
      } else {
        roots.push(node);
      }
    }
    return roots;
  }
}
