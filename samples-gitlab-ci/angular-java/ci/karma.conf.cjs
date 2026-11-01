// Optional adapter for Angular's Karma builder. Keep the project's test suites.
const { createRequire } = require('node:module');
const projectRequire = createRequire(require('node:path').resolve(process.cwd(), 'package.json'));
module.exports = config => config.set({
  frameworks: ['jasmine'],
  plugins: ['karma-jasmine', 'karma-chrome-launcher', 'karma-coverage'].map(p => projectRequire(p)),
  reporters: ['progress', 'coverage'],
  browsers: ['ChromeHeadlessCI'],
  customLaunchers: { ChromeHeadlessCI: { base: 'ChromeHeadless', flags: ['--no-sandbox'] } },
  coverageReporter: { dir: require('node:path').resolve(process.cwd(), 'coverage'), subdir: '.', reporters: [{ type: 'lcovonly' }, { type: 'text-summary' }] },
  singleRun: true,
});
