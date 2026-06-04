const fs = require('fs');
const path = 'C:\\Users\\Administrator\\clawd\\agents\\workspace-gid\\data\\system\\nfp-12h-prep-2026-06-05-0746.json';
try {
  const j = JSON.parse(fs.readFileSync(path, 'utf8'));
  console.log('VALID JSON');
  console.log('Top keys:', Object.keys(j).join(','));
  console.log('Total keys (recursive):', JSON.stringify(j).length, 'chars');
} catch (e) {
  console.log('INVALID:', e.message);
  // Find approximate line
  const raw = fs.readFileSync(path, 'utf8');
  const lines = raw.split('\n');
  console.log('Lines:', lines.length);
  console.log('Last 3 lines:');
  for (let i = Math.max(0, lines.length - 3); i < lines.length; i++) {
    console.log((i+1) + ': ' + lines[i]);
  }
}
