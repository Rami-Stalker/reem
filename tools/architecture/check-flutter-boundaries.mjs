import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const sourceRoots = ['lib'];

const domainImportBaseline = new Set([
  'lib/features/profile/domain/entities/achievement.dart',
  'lib/features/seller_dashboard/domain/entities/seller_misc.dart',
  'lib/features/seller_dashboard/domain/entities/seller_orders_summary.dart',
]);

const forbiddenDomainImportFragments = [
  'package:flutter',
  'package:flutter_riverpod',
  'package:dio',
  'package:go_router',
  '/data/',
  '../data/',
  '../../data/',
  '/presentation/',
  '../presentation/',
  '../../presentation/',
];

const files = sourceRoots
  .flatMap((dir) => walk(path.join(root, dir)))
  .filter((file) => file.endsWith('.dart'))
  .map((file) => normalize(path.relative(root, file)));

const enforcedViolations = [];
const advisory = {
  presentationInfrastructureImports: [],
  debugPrints: [],
  modelInheritance: [],
  largeFiles: [],
};

for (const file of files) {
  const absolute = path.join(root, file);
  const text = fs.readFileSync(absolute, 'utf8');
  const lines = text.split(/\r?\n/);

  if (file.includes('/domain/')) {
    for (const [index, line] of lines.entries()) {
      if (!line.trimStart().startsWith('import ')) continue;
      const forbidden = forbiddenDomainImportFragments.find((fragment) =>
        line.includes(fragment),
      );
      if (forbidden && !domainImportBaseline.has(file)) {
        enforcedViolations.push({
          file,
          line: index + 1,
          rule: 'domain-must-not-import-framework-or-infrastructure',
          detail: line.trim(),
        });
      }
    }
  }

  if (file.includes('/presentation/')) {
    const importsInfrastructure = lines.some(
      (line) =>
        line.trimStart().startsWith('import ') &&
        (line.includes('/data/') ||
          line.includes('../data/') ||
          line.includes('../../data/') ||
          line.includes('_impl.dart')),
    );
    if (importsInfrastructure) advisory.presentationInfrastructureImports.push(file);
  }

  lines.forEach((line, index) => {
    if (line.includes('print(') || line.includes('debugPrint(')) {
      advisory.debugPrints.push({ file, line: index + 1 });
    }
  });

  if (/class\s+\w+Model\s+extends\s+\w+/.test(text)) {
    advisory.modelInheritance.push(file);
  }

  if (lines.length > 500) {
    advisory.largeFiles.push({ file, lines: lines.length });
  }
}

printReport(enforcedViolations, advisory);

if (enforcedViolations.length > 0) {
  process.exitCode = 1;
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const next = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(next);
    return entry.isFile() ? [next] : [];
  });
}

function normalize(value) {
  return value.replaceAll(path.sep, '/');
}

function printReport(violations, debt) {
  console.log('Flutter architecture fitness check');
  console.log(`Enforced violations: ${violations.length}`);
  for (const violation of violations) {
    console.log(
      `- ${violation.rule}: ${violation.file}:${violation.line} ${violation.detail}`,
    );
  }

  console.log('\nDebt queues (advisory, burn down incrementally):');
  console.log(
    `- Presentation imports infrastructure: ${debt.presentationInfrastructureImports.length}`,
  );
  debt.presentationInfrastructureImports.slice(0, 12).forEach((file) => {
    console.log(`  - ${file}`);
  });

  console.log(`- Debug prints: ${debt.debugPrints.length}`);
  debt.debugPrints.slice(0, 12).forEach((entry) => {
    console.log(`  - ${entry.file}:${entry.line}`);
  });

  console.log(`- DTO/model inheritance files: ${debt.modelInheritance.length}`);
  debt.modelInheritance.slice(0, 12).forEach((file) => {
    console.log(`  - ${file}`);
  });

  console.log(`- Large Dart files over 500 lines: ${debt.largeFiles.length}`);
  debt.largeFiles
    .sort((a, b) => b.lines - a.lines)
    .slice(0, 12)
    .forEach((entry) => {
      console.log(`  - ${entry.file} (${entry.lines} lines)`);
    });
}
