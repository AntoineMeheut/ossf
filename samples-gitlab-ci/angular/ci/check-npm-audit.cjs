'use strict';
const fs = require('node:fs');
const data = JSON.parse(fs.readFileSync('reports/npm-audit.json', 'utf8'));
const code = Number(process.argv[2]);
const findings = data.vulnerabilities;
const count = data.metadata?.vulnerabilities?.total;
if (data.error || data.auditReportVersion !== 2 || !findings || Array.isArray(findings) ||
    typeof findings !== 'object' || !data.metadata?.dependencies?.total ||
    count !== Object.keys(findings).length ||
    Object.values(findings).some(v => !['info', 'low', 'moderate', 'high', 'critical'].includes(v.severity)) ||
    !(code === 0 || (code === 1 && count > 0))) {
  throw new Error('npm audit failed or returned an incomplete report');
}
console.log(`npm audit completed: ${count} vulnerable package entries; DefectDojo enforces release policy`);
