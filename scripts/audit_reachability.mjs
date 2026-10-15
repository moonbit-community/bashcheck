#!/usr/bin/env node
/**
 * Audit production reachability using MoonBit's compiler-resolved references.
 * Function values (suite registrations), methods and initializer references are
 * edges, not just syntactic calls. Tests and generated derivations are excluded.
 * Target-specific declarations are merged by source location, with no allowlist.
 */
import { execFile } from 'node:child_process';
import { readFileSync, unlinkSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const execute = promisify(execFile);
const processOptions = { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 };

async function moon(...args) {
  const { stdout } = await execute('moon', ['ide', ...args], processOptions);
  return JSON.parse(stdout);
}

async function runMoon(...args) {
  const { stdout, stderr } = await execute('moon', args, processOptions);
  if (args[0] !== 'check') process.stdout.write(stdout);
  process.stderr.write(stderr);
}

// Keep at most four IDE processes running, and consume results in input order.
async function mapConcurrent(values, operation) {
  const results = new Array(values.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(4, values.length) }, async () => {
    while (next < values.length) {
      const index = next++;
      results[index] = await operation(values[index]);
    }
  }));
  return results;
}

function testPath(path) {
  return ['_test.mbt', '_wbtest.mbt', '.mbt.md'].some(suffix => path.endsWith(suffix));
}

function locationKey(path, line, column) {
  return JSON.stringify([path, line, column]);
}

async function audit(target, internalOnly) {
  await runMoon('check', '--target', target);
  await runMoon('ide', 'gen-symbols', '--no-check', '--target', target);
  const symbolPath = join(ROOT, 'symbols.jsonl');
  let symbols;
  try {
    symbols = readFileSync(symbolPath, 'utf8').split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));
  } finally {
    unlinkSync(symbolPath);
  }
  const text = new Map();
  const nodes = [];
  for (const symbol of symbols) {
    const path = symbol.path;
    if (!symbol.pkg.startsWith('moonbit-community/bashcheck') || testPath(path)) continue;
    if (!text.has(path)) text.set(path, readFileSync(join(ROOT, path), 'utf8').split(/\r?\n/));
    const [start, , end] = symbol.range;
    const body = text.get(path).slice(start - 1, end).join('\n');
    if (!['0x1000', '0x1001', '0x800'].includes(symbol.tag) || !/\bfn\b/.test(body)) continue;
    // Compiler-generated derive/extend methods have no fn source declaration.
    nodes.push({ ...symbol, name: symbol.kind.slice(1).join('::'), body });
  }
  const byLocation = new Map(nodes.map((node, index) => [
    locationKey(node.path, ...node.name_range.slice(0, 2)), index,
  ]));
  const byFile = new Map();
  const edges = nodes.map(() => new Set());
  const roots = new Set();
  nodes.forEach((node, index) => {
    if (!byFile.has(node.path)) byFile.set(node.path, []);
    byFile.get(node.path).push(index);
    if (node.path === 'main.mbt') roots.add(index);
  });
  function owner(path, line) {
    for (const index of byFile.get(path) ?? []) {
      const [start, , end] = nodes[index].range;
      if (start <= line && line <= end) return index;
    }
    return undefined;
  }
  function addReferences(index, refs) {
    for (const ref of refs ?? []) {
      const path = isAbsolute(ref.path) ? relative(ROOT, ref.path) : ref.path;
      if (ref.is_test || testPath(path) || !text.has(path)) continue;
      const line = Number(ref.range.split(':')[0]);
      const source = owner(path, line);
      if (source === undefined) {
        // Initializers and explicit trait implementations can execute without
        // a direct function call at the use site.
        roots.add(index);
      } else {
        edges[source].add(index);
      }
    }
  }
  const lenses = await mapConcurrent([...byFile.keys()], async path => [
    path, await moon('codelens', path, '--no-check', '--target', target),
  ]);
  for (const [path, entries] of lenses) {
    for (const { command } of entries) {
      if (command.command !== 'moonbit.action.goToLocations') continue;
      const args = command.arguments;
      const [line, column] = args[1].split('-')[0].split(':').map(Number);
      const index = byLocation.get(locationKey(path, line, column));
      if (index !== undefined) addReferences(index, args[2]);
    }
  }
  const publicNodes = nodes.flatMap((node, index) => node.tag === '0x1001' ? [index] : []);
  const outside = await mapConcurrent(publicNodes, async index => {
    const node = nodes[index];
    const [line, column] = node.name_range;
    return [index, await moon('find-references', '--loc', `${node.path}:${line}:${column}`,
      '--json', '--no-check', '--target', target)];
  });
  for (const [index, refs] of outside) {
    addReferences(index, refs);
    const ownDirectory = dirname(join(ROOT, nodes[index].path));
    nodes[index].has_external_refs = (refs ?? []).some(ref =>
      !ref.is_test && dirname(ref.path) !== ownDirectory);
    // Test-only external references still require visibility until migration.
    nodes[index].has_any_external_refs = (refs ?? []).some(ref =>
      dirname(ref.path) !== ownDirectory || ref.is_test);
  }
  const live = new Set(roots);
  const pending = [...roots];
  while (pending.length > 0) {
    for (const index of edges[pending.pop()]) {
      if (!live.has(index)) {
        live.add(index);
        pending.push(index);
      }
    }
  }
  if (internalOnly) return nodes.filter(node => node.tag === '0x1001' && !node.has_any_external_refs);
  return nodes.filter((_, index) => !live.has(index));
}

function parseArguments(args) {
  const options = { targets: [], json: false, internalOnly: false };
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === '-h' || arg === '--help') {
      console.log('Usage: node scripts/audit_reachability.mjs [--target wasm|native] [--json] [--internal-only]\n' +
        'Repeat --target to select backends; the default audits both wasm and native.\n' +
        '--internal-only reports exports whose references are entirely production-local.');
      return undefined;
    }
    if (arg === '--json') options.json = true;
    else if (arg === '--internal-only') options.internalOnly = true;
    else if (arg === '--target' || arg.startsWith('--target=')) {
      const target = arg === '--target' ? args[++index] : arg.slice('--target='.length);
      if (!['wasm', 'native'].includes(target)) throw new Error('--target requires wasm or native');
      options.targets.push(target);
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  if (options.targets.length === 0) options.targets = ['wasm', 'native'];
  return options;
}

function compareRows(left, right) {
  for (const [a, b] of [[left.path, right.path], [left.name_range[0], right.name_range[0]], [left.name, right.name]]) {
    if (a < b) return -1;
    if (a > b) return 1;
  }
  return 0;
}

async function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }
  if (!options) return;
  let dead;
  for (const target of options.targets) {
    const found = new Map((await audit(target, options.internalOnly)).map(node => [
      JSON.stringify([node.path, node.name_range[0], node.name]), node,
    ]));
    // A declaration is unreachable only when it is unreachable on every target.
    dead = dead === undefined ? found : new Map([...dead].filter(([key]) => found.has(key)));
  }
  const rows = [...dead.values()].sort(compareRows);
  if (options.json) console.log(JSON.stringify(rows, null, 2));
  else {
    for (const node of rows) console.log(`${node.path}:${node.name_range[0]}: unreachable ${node.name}`);
    console.log(`${rows.length} unreachable production functions`);
  }
  process.exitCode = rows.length > 0 ? 1 : 0;
}

try {
  await main();
} catch (error) {
  console.error(error.stderr || error.stdout || error.message);
  process.exitCode = 1;
}
