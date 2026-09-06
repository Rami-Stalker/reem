import assert from 'node:assert/strict';
import test from 'node:test';
import { Category } from '@prisma/client';

import { CategoriesService } from './categories.service';

/**
 * The tree the seller's product form picks a leaf from.
 *
 * Two things about it can go quietly wrong, and both would be invisible until
 * a woman tried to list something: a node that should be selectable being
 * marked a branch (or the reverse), and a leaf losing the ancestry that tells
 * two same-named shelves apart. Both are pure assembly, so they are tested on
 * the prototype — no database, no DI.
 */
const service = Object.create(CategoriesService.prototype) as {
  assemble(rows: Category[]): TreeNode[];
  cache: unknown;
  tree(): Promise<TreeNode[]>;
  leaves(): Promise<(TreeNode & { path: string[] })[]>;
};

interface TreeNode {
  id: string;
  name_ar: string;
  is_leaf: boolean;
  children: TreeNode[];
  path: string[];
}

/** Only the columns the assembler reads; the rest never leave the row. */
function row(
  id: string,
  nameAr: string,
  level: number,
  parentId: string | null,
  sortOrder = 0,
): Category {
  return {
    id,
    parentId,
    level,
    slug: id,
    nameAr,
    nameEn: id,
    iconUrl: null,
    imageUrl: null,
    attributeSchema: null,
    isSensitive: false,
    returnsAllowed: true,
    sizeChartId: null,
    sortOrder,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  } as Category;
}

// ملابس › فساتين › فساتين سهرة, plus a second department that also sells
// evening dresses — the case a bare leaf name cannot disambiguate.
const rows = [
  row('clothing', 'ملابس', 0, null),
  row('occasion', 'مناسبات', 0, null, 1),
  row('dresses', 'فساتين', 1, 'clothing'),
  row('evening-c', 'فساتين سهرة', 2, 'dresses'),
  row('day', 'فساتين نهارية', 2, 'dresses'),
  row('evening-o', 'فساتين سهرة', 1, 'occasion'),
];

test('roots come back as roots and children hang off them', () => {
  const tree = service.assemble(rows);

  assert.equal(tree.length, 2);
  assert.deepEqual(
    tree.map((node) => node.id),
    ['clothing', 'occasion'],
  );

  const clothing = tree[0];
  assert.equal(clothing.children.length, 1);
  assert.equal(clothing.children[0].id, 'dresses');
  assert.equal(clothing.children[0].children.length, 2);
});

test('a node with children is not selectable, a node without one is', () => {
  const tree = service.assemble(rows);
  const clothing = tree[0];
  const dresses = clothing.children[0];

  assert.equal(clothing.is_leaf, false, 'a department is not a shelf');
  assert.equal(dresses.is_leaf, false, 'a section is not a shelf');
  assert.equal(dresses.children[0].is_leaf, true);
  assert.equal(dresses.children[1].is_leaf, true);

  // `POST /seller/products` takes a LEAF and refuses anything above it, so a
  // branch offered as pickable is a form that cannot be submitted.
  assert.equal(tree[1].children.length, 1);
  assert.equal(tree[1].is_leaf, false);
});

test('a leaf carries the ancestry that tells two same-named shelves apart', () => {
  const tree = service.assemble(rows);

  // Built by the walker in `leaves()`, mirrored here: the assembler seeds
  // `path` per node and the walker is what accumulates it.
  const crumbs: string[][] = [];
  const walk = (node: TreeNode, trail: string[]) => {
    const path = [...trail, node.name_ar];
    if (node.is_leaf) crumbs.push(path);
    else node.children.forEach((child) => walk(child, path));
  };
  tree.forEach((root) => walk(root, []));

  assert.deepEqual(crumbs, [
    ['ملابس', 'فساتين', 'فساتين سهرة'],
    ['ملابس', 'فساتين', 'فساتين نهارية'],
    ['مناسبات', 'فساتين سهرة'],
  ]);

  const evening = crumbs.filter((crumb) => crumb.at(-1) === 'فساتين سهرة');
  assert.equal(evening.length, 2);
  assert.notDeepEqual(evening[0], evening[1]);
});

test('an orphan whose parent is inactive is still reachable as a root', () => {
  // Otherwise deactivating one department would strand every shelf under it:
  // invisible in the tree, still attached to live products.
  const orphaned = rows.filter((entry) => entry.id !== 'dresses');
  const tree = service.assemble(orphaned);

  const ids = tree.map((node) => node.id).sort();
  assert.deepEqual(ids, ['clothing', 'day', 'evening-c', 'occasion']);
});
