import { Prisma } from '@prisma/client';

/** Just enough of a Prisma client to walk the category table. */
type CategoryReader = {
  category: {
    findUnique(args: {
      where: Prisma.CategoryWhereUniqueInput;
      select: { id: true };
    }): Promise<{ id: string } | null>;
    findMany(args: {
      where: Prisma.CategoryWhereInput;
      select: { id: true };
    }): Promise<{ id: string }[]>;
  };
};

/**
 * A category and every category beneath it, for the three-level tree (Q26).
 *
 * Products hang off leaves. So "أزياء" or "ملابس" — a root and a department —
 * own no products directly, and any query that matches `category.slug` alone
 * answers with an empty shelf for every tile above leaf level. Discovery did
 * exactly that, which is why tapping a department on the home page opened
 * nothing; `products.byCategory` had this walk inline and got it right. One
 * copy now, so the two cannot disagree again.
 *
 * Returns `[]` for a slug no category carries, which callers turn into a 404.
 */
export async function categorySubtreeIds(
  prisma: CategoryReader,
  slug: string,
): Promise<string[]> {
  const root = await prisma.category.findUnique({
    where: { slug },
    select: { id: true },
  });
  if (!root) return [];

  const children = await prisma.category.findMany({
    where: { parentId: root.id },
    select: { id: true },
  });
  if (children.length === 0) return [root.id];

  const grandchildren = await prisma.category.findMany({
    where: { parentId: { in: children.map((child) => child.id) } },
    select: { id: true },
  });

  return [
    root.id,
    ...children.map((child) => child.id),
    ...grandchildren.map((child) => child.id),
  ];
}
