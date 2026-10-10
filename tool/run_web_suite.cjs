// Reads an external licensed suite and supplies raw JSON text to Dart JavaScript.
const fs = require('node:fs');
const path = require('node:path');
const suite = process.argv[2];
if (!suite) {
  console.error('Pass the external JSON Schema Test Suite directory.');
  process.exit(64);
}
const published = new Set(['draft3', 'draft4', 'draft6', 'draft7', 'draft2019-09', 'draft2020-12']);
function files(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? files(target) : target.endsWith('.json') ? [target] : [];
  }).sort();
}
const fixtures = files(path.join(suite, 'tests')).map(file => ({
  path: path.relative(suite, file).replaceAll('\\', '/'),
  source: fs.readFileSync(file, 'utf8'),
})).filter(file => published.has(file.path.split('/')[1]));
const remotes = files(path.join(suite, 'remotes')).map(file => ({
  uri: 'http://localhost:1234/' + path.relative(path.join(suite, 'remotes'), file).replaceAll('\\', '/'),
  source: fs.readFileSync(file, 'utf8'),
}));
globalThis.schemaSuiteInput = JSON.stringify({files: fixtures, remotes});
globalThis.self = globalThis;
Object.defineProperty(globalThis, 'schemaSuiteResult', {set(raw) {
  const result = JSON.parse(raw);
  result.node = process.version;
  fs.writeFileSync('build/web_conformance_results.json', JSON.stringify(result, null, 2) + '\n');
  for (const failure of [...result.failures, ...result.blocked].slice(0, 100)) {
    console.error(JSON.stringify(failure));
  }
  console.log(`Counts: ${JSON.stringify(result.counts)}; failures: ${result.failures.length}; blocked: ${result.blocked.length}; files: ${result.files}`);
  process.exitCode = result.failures.length ? 1 : result.blocked.length ? 2 : 0;
}});
require(path.resolve('build/run_web_suite.js'));
