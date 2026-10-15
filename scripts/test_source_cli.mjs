#!/usr/bin/env node
/**
 * Real-file CLI regressions with static ShellCheck 0.11.0 source baselines.
 * CI requires no oracle. --oracle compares against a locally installed 0.11.0,
 * with intentional duplicate-policy differences recorded in e2etests/README.md.
 * Both targets run actual processes.
 */
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const CODES = '1090,1091,1092,1093,1094,2086,2154';

function parseArguments(args) {
  const options = { target: 'native', oracle: false };
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === '-h' || arg === '--help') {
      console.log('Usage: node scripts/test_source_cli.mjs [--target wasm|native] [--oracle]\n' +
        'Run real-file source CLI regressions (default: native).\n' +
        '--oracle also compares against local ShellCheck 0.11.0, with documented duplicate-policy differences.');
      return undefined;
    }
    if (arg === '--oracle') options.oracle = true;
    else if (arg === '--target' || arg.startsWith('--target=')) {
      const target = arg === '--target' ? args[++index] : arg.slice('--target='.length);
      if (!['wasm', 'native'].includes(target)) throw new Error('--target requires wasm or native');
      options.target = target;
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  return options;
}

function sortPositions(rows) {
  return rows.toSorted((left, right) => {
    for (let index = 0; index < left.length; index++) {
      if (left[index] < right[index]) return -1;
      if (left[index] > right[index]) return 1;
    }
    return 0;
  });
}

function runProcess(executable, args, { cwd = ROOT, stdin, timeout = 120_000 } = {}) {
  return new Promise((resolve, reject) => {
    const child = execFile(executable, args, {
      cwd, encoding: 'utf8', timeout, killSignal: 'SIGKILL', maxBuffer: 64 * 1024 * 1024,
    }, (error, stdout, stderr) => {
      if (error && (typeof error.code !== 'number' || error.killed)) reject(error);
      else resolve({ status: error ? error.code : 0, stdout, stderr });
    });
    child.stdin.end(stdin);
  });
}

async function main(options) {
  const build = await runProcess('moon', ['build', '--target', options.target]);
  process.stdout.write(build.stdout);
  process.stderr.write(build.stderr);
  assert.equal(build.status, 0, 'moon build failed');
  const artifact = join(ROOT, '_build', options.target, 'debug', 'build',
    `bashcheck.${options.target === 'native' ? 'exe' : 'wasm'}`);
  const command = options.target === 'native' ? [artifact] : ['moonrun', artifact];
  if (options.oracle) {
    const version = await runProcess('shellcheck', ['--version']);
    assert.equal(version.status, 0, version.stderr);
    assert.ok(version.stdout.includes('version: 0.11.0'), version.stdout);
  }
  const work = mkdtempSync(join(tmpdir(), 'bashcheck-source-'));
  try {
    function write(name, text) {
      const path = join(work, name);
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, text, 'utf8');
    }
    function run(args, executable = command, stdin = undefined) {
      return runProcess(executable[0], [...executable.slice(1), ...args], { cwd: work, stdin });
    }
    let cases = 0;
    function positions(output) {
      return sortPositions(JSON.parse(output).map(diagnostic => [
        diagnostic.code, diagnostic.file, diagnostic.line, diagnostic.column,
      ]));
    }
    async function check(label, args, expected, { rc = false, oracleExpected = expected } = {}) {
      const flags = [...(rc ? [] : ['--norc']), '-fjson', `-i${CODES}`, ...args];
      const result = await run(flags);
      assert.equal(result.stderr, '', `${label}: ${result.stderr}`);
      assert.deepEqual(positions(result.stdout), sortPositions(expected), `${label}: ${result.stdout}`);
      assert.equal(result.status, expected.length > 0 ? 1 : 0, label);
      if (options.oracle) {
        const reference = await run(flags, ['shellcheck']);
        assert.equal(reference.stderr, '', `${label}: ${reference.stderr}`);
        assert.deepEqual(positions(reference.stdout), sortPositions(oracleExpected),
          `${label}: ${reference.stdout}`);
        // Compare exact end positions and severity too, retaining every row.
        // Intentional duplicate/alias cases spell out their oracle arrays above.
        // OS error text and fix precedence are implementation-specific.
        const signature = ({ file, line, column, endLine, endColumn, level, code }) =>
          ({ file, line, column, endLine, endColumn, level, code });
        const diagnostics = JSON.parse(result.stdout);
        const expectedReference = oracleExpected.map(([code, file, line, column]) => {
          const matches = diagnostic => diagnostic.code === code &&
            diagnostic.line === line && diagnostic.column === column;
          const diagnostic = diagnostics.find(d => d.file === file && matches(d)) ??
            diagnostics.find(matches);
          assert.ok(diagnostic, `${label}: missing oracle diagnostic ${code} ${file}:${line}:${column}`);
          return signature({ ...diagnostic, file });
        });
        const sorted = rows => rows.toSorted((a, b) =>
          JSON.stringify(a).localeCompare(JSON.stringify(b)));
        assert.deepEqual(sorted(JSON.parse(reference.stdout).map(signature)),
          sorted(expectedReference), label);
        assert.equal(reference.status, result.status, label);
      }
      cases++;
    }
    write("main.sh", "#!/bin/bash\nsource lib.sh\necho \"$bar\"\n");
    write("lib.sh", "bar=\"hello world\"\necho $bar\n");
    await check("default permission", ["main.sh"], [[1091, "main.sh", 2, 8], [2154, "main.sh", 3, 7]]);
    await check("a does not allow files", ["-a", "main.sh"], [[1091, "main.sh", 2, 8], [2154, "main.sh", 3, 7]]);
    await check("load without source diagnostics", ["-x", "main.sh"], []);
    await check("a+x source diagnostics", ["-ax", "main.sh"], [[2086, "lib.sh", 2, 6]]);
    await check("explicit input permits source", ["main.sh", "lib.sh"], [[2086, "lib.sh", 2, 6]]);
    await check("explicit input with a", ["-a", "main.sh", "lib.sh"], [[2086, "lib.sh", 2, 6]], { oracleExpected: [[2086, "lib.sh", 2, 6], [2086, "lib.sh", 2, 6]] });
    write("functions.sh", "fill() { bar=\"hello world\"; }\n");
    write("call.sh", "#!/bin/bash\nsource functions.sh\nfill\necho \"$bar\"\n");
    await check("sourced function changes caller state", ["-x", "call.sh"], []);
    write("sub/main.sh", "#!/bin/bash\nsource sibling.sh\necho \"$bar\"\n");
    write("sub/sibling.sh", "bar=ok\n");
    await check("no implicit script directory", ["-x", "sub/main.sh"], [[1091, "sub/main.sh", 2, 8], [2154, "sub/main.sh", 3, 7]]);
    await check("CLI SCRIPTDIR", ["-x", "-P", "SCRIPTDIR", "sub/main.sh"], []);
    write("other/sibling.sh", "echo $1\n");
    await check("CLI path precedes script directory", ["-ax", "-P", "other:SCRIPTDIR", "sub/main.sh"], [[2086, "other/sibling.sh", 1, 6], [2154, "sub/main.sh", 3, 7]], { oracleExpected: [[2086, "other/sibling.sh", 1, 6], [2086, "other/sibling.sh", 1, 6], [2154, "sub/main.sh", 3, 7], [2154, "sub/main.sh", 3, 7]] });
    write("direct.sh", "bar=ok\n");
    write("other/direct.sh", "echo $1\n");
    write("direct-main.sh", "#!/bin/bash\nsource direct.sh\necho \"$bar\"\n");
    await check("direct path precedes CLI path", ["-ax", "-P", "other", "direct-main.sh"], []);
    write("annotated.sh", "#!/bin/bash\n# shellcheck source-path=other\nsource sibling.sh\n");
    await check("file source-path", ["-ax", "annotated.sh"], [[2086, "other/sibling.sh", 1, 6]]);
    await check("CLI path precedes directive", ["-ax", "-P", "sub", "annotated.sh"], []);
    write("dynamic.sh", "#!/bin/bash\nsource \"$1\"\n");
    await check("dynamic source", ["-x", "dynamic.sh"], [[1090, "dynamic.sh", 2, 8]]);
    write("my lib.sh", "bar=ok\nsource leaf.sh\n");
    write("leaf.sh", "baz=ok\n");
    write("override.sh", "#!/bin/bash\n# shellcheck source=\"my lib.sh\"\nsource \"$1\"\necho \"$bar $baz\"\n");
    await check("space override does not leak to nested source", ["-x", "override.sh"], []);
    write("null.sh", "#!/bin/bash\nsource /dev/null\n");
    await check("dev null is an empty script", ["null.sh"], []);
    write("broken.sh", "for f; do\n");
    write("bad-main.sh", "#!/bin/bash\nsource broken.sh\n");
    await check("source syntax error", ["-x", "bad-main.sh"], [[1094, "bad-main.sh", 2, 8]]);
    write("cycle.sh", "#!/bin/bash\nsource ./cycle.sh\n");
    await check("normalized cycle", ["-x", "cycle.sh"], []);
    symlinkSync("cycle.sh", join(work, "alias.sh"));
    write("symlink-main.sh", "#!/bin/bash\nsource alias.sh\n");
    await check("symlink cycle", ["-x", "symlink-main.sh"], []);
    write("deny.sh", "#!/bin/bash\nsource lib.sh\n# shellcheck external-sources=false\nsource lib.sh\n");
    await check("cached text does not bypass permissions", ["-ax", "deny.sh"], [[2086, "lib.sh", 2, 6], [1091, "deny.sh", 4, 8]], { oracleExpected: [[2086, "lib.sh", 2, 6], [2086, "lib.sh", 2, 6], [1091, "deny.sh", 4, 8], [1091, "deny.sh", 4, 8]] });
    write("suppress.sh", "#!/bin/bash\ntrue\n# shellcheck disable=SC2086\nsource lib.sh\necho $1\n");
    await check("include suppression respects file identity", ["-ax", "suppress.sh"], [[2086, "suppress.sh", 5, 6]]);
    write("lib.sh", "bar=\"hello world\"\n# shellcheck disable=SC2086\necho $bar\necho $1\n");
    await check("source local suppression", ["-ax", "main.sh"], [[2086, "lib.sh", 4, 6]]);
    write("suppressed-lib.sh", "# shellcheck disable=SC2086\nprintf '%s\\n' $1\n");
    write("same-offsets.sh", "#!/bin/bash\nsource suppressed-lib.sh\necho $1\n");
    await check("source suppression never disables caller offsets", ["-ax", "same-offsets.sh"], [[2086, "same-offsets.sh", 3, 6]]);
    write("inside-if.sh", "#!/bin/bash\nif true; then\nsource leaf-warning.sh\nfi\n");
    write("leaf-warning.sh", "echo $1\n");
    await check("nested include diagnostics", ["-ax", "inside-if.sh"], [[2086, "leaf-warning.sh", 1, 6]]);
    write("compound-deny.sh", "#!/bin/bash\ntrue\n# shellcheck external-sources=false\nif true; then\nsource leaf-warning.sh\nfi\n");
    await check("compound permission directive encloses source", ["-ax", "compound-deny.sh"], [[1091, "compound-deny.sh", 5, 8]]);
    write("repeat-scope.sh", "#!/bin/bash\ntrue\n# shellcheck disable=SC2086\nsource leaf-warning.sh\nsource leaf-warning.sh\n");
    await check("include directive does not spill across item boundary", ["-ax", "repeat-scope.sh"], [[2086, "leaf-warning.sh", 1, 6]]);
    write("config/.shellcheckrc", "external-sources=true\nsource-path=SCRIPTDIR\n");
    write("config/main.sh", "#!/bin/bash\nsource sibling.sh\necho \"$bar\"\n");
    write("config/sibling.sh", "bar=ok\n");
    await check("rc applies before source resolution", ["config/main.sh"], [], { rc: true });
    write("config/main.sh", "#!/bin/bash\n# shellcheck external-sources=false\nsource sibling.sh\n");
    await check("file permission overrides rc and CLI", ["-x", "config/main.sh"], [[1091, "config/main.sh", 3, 8]], { rc: true });
    // 100 source frames; the input frame is not a source frame.
    for (let depth = 0; depth < 102; depth++) {
      write(`chain/${depth}.sh`, depth === 101 ? "true\n" : `source chain/${depth + 1}.sh\n`);
    }
    write("depth.sh", "#!/bin/bash\nsource chain/0.sh\n");
    await check("depth limit", ["-ax", "depth.sh"], [[1093, "chain/99.sh", 1, 8]]);
    await check("depth diagnostic hidden without a", ["-x", "depth.sh"], []);
    await check("depth diagnostic severity filter", ["-ax", "-Swarning", "depth.sh"], []);
    write("chain/99.sh", "# shellcheck disable=SC1093\nsource chain/100.sh\n");
    await check("depth diagnostic local suppression", ["-ax", "depth.sh"], []);
    write("depth.sh", "#!/bin/bash\n# shellcheck disable=SC1093\nsource chain/0.sh\n");
    await check("depth diagnostic include suppression", ["-ax", "depth.sh"], []);
    write("depth.sh", "#!/bin/bash\nsource chain/0.sh\n");
    write("chain/99.sh", "true\n");
    await check("depth before limit", ["-ax", "depth.sh"], []);
    write("positions.sh", '#!/bin/bash\necho "$foo $foobar ${baz}"\necho \'$literal\'"\\$escaped $actual"\necho "first\n$multiline ${last}\n"\n');
    await check("quoted escaped and multiline variable positions", ["positions.sh"], [
      [2154, "positions.sh", 2, 7], [2154, "positions.sh", 2, 12], [2154, "positions.sh", 2, 20],
      [2154, "positions.sh", 3, 27], [2154, "positions.sh", 5, 1], [2154, "positions.sh", 5, 12],
    ]);
    write("warnings.sh", 'echo $1\necho $2\n');
    write("repeat.sh", '#!/bin/bash\nsource warnings.sh\nsource warnings.sh\n');
    const once = [[2086, "warnings.sh", 1, 6], [2086, "warnings.sh", 2, 6]];
    await check("repeated source deduplicates but preserves separate locations", ["-ax", "repeat.sh"], once);
    write("another.sh", '#!/bin/bash\nsource warnings.sh\n');
    await check("deduplication spans explicit inputs", ["-ax", "repeat.sh", "another.sh"], once, { oracleExpected: [...once, ...once] });
    await check("repeated explicit input", ["warnings.sh", "warnings.sh"], once, { oracleExpected: [...once, ...once] });
    symlinkSync("warnings.sh", join(work, "warning-alias.sh"));
    const aliasRows = once.map(row => [row[0], "warning-alias.sh", row[2], row[3]]);
    write("source-alias.sh", '#!/bin/bash\nsource warnings.sh\nsource warning-alias.sh\n');
    await check("sourced symlink aliases", ["-ax", "source-alias.sh"], once, { oracleExpected: [
      ...once, ...aliasRows, ...once, ...aliasRows,
    ] });
    await check("explicit path and symlink aliases", ["warnings.sh", "./warnings.sh", "warning-alias.sh"], once, { oracleExpected: [
      ...once, ...once.map(row => [row[0], "./warnings.sh", row[2], row[3]]),
      ...once.map(row => [row[0], "warning-alias.sh", row[2], row[3]]),
    ] });
    write("lib.sh", "bar=\"hello world\"\n\techo $bar");
    const tty = await run(['--norc', '-ax', '-i2086', '-W0', '--color=never', 'main.sh']);
    assert.ok(tty.stdout.includes('In lib.sh line 2:') && tty.stdout.includes('\techo $bar'), tty.stdout);
    const diff = await run(['--norc', '-ax', '-i2086', '-fdiff', 'main.sh']);
    assert.ok(diff.stdout.includes('--- a/lib.sh') && diff.stdout.includes('+\techo "$bar"') &&
      diff.stdout.includes('\\ No newline at end of file'), diff.stdout);
    write('twice.sh', '#!/bin/bash\nsource lib.sh\nsource ./lib.sh\n');
    symlinkSync("lib.sh", join(work, "lib-alias.sh"));
    for (const format of ['json', 'json1', 'tty', 'diff']) {
      const repeated = await run(['--norc', '-ax', '-i2086', '-W0', '--color=never', `-f${format}`,
        'twice.sh', 'lib.sh', './lib.sh', 'lib-alias.sh']);
      assert.equal(repeated.status, 1, format);
      assert.equal(repeated.stderr, '', format);
      if (format === 'json' || format === 'json1') {
        const parsed = JSON.parse(repeated.stdout);
        const diagnostics = format === 'json' ? parsed : parsed.comments;
        assert.equal(diagnostics.length, 1, repeated.stdout);
        assert.equal(diagnostics[0].fix.replacements.length, 2, repeated.stdout);
      } else if (format === 'tty') {
        assert.equal(repeated.stdout.split('SC2086').length - 1, 1, repeated.stdout);
        assert.equal(repeated.stdout.split('In lib.sh line 2:').length - 1, 1, repeated.stdout);
      } else {
        assert.equal(repeated.stdout.split('--- a/lib.sh').length - 1, 1, repeated.stdout);
        assert.equal(repeated.stdout.split('+\techo "$bar"').length - 1, 1, repeated.stdout);
        assert.ok(!repeated.stdout.includes('""$bar""'), repeated.stdout);
      }
    }
    const quiet = await run(['--norc', '-fquiet', 'lib.sh', 'missing-input.sh']);
    assert.equal(quiet.status, 1);
    assert.equal(quiet.stdout, '');
    assert.equal(quiet.stderr, '');
    console.log(`${cases} source baselines and 7 formatter/quiet checks passed (${options.target})`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

let options;
try {
  options = parseArguments(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  process.exitCode = 2;
}
if (options) {
  try {
    await main(options);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
