const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..');
const workflowPath = path.join(repoRoot, '.github', 'workflows', 'check-bsc-hardfork-bytecode.yml');
const scriptPath = path.join(repoRoot, 'scripts', 'check-bsc-hardfork-bytecode.ts');
const lintWorkflowPath = path.join(repoRoot, '.github', 'workflows', 'lint-pr.yml');
const unitTestWorkflowPath = path.join(repoRoot, '.github', 'workflows', 'unit-test.yml');
const checkGenesisWorkflowPath = path.join(repoRoot, '.github', 'workflows', 'check-genesis.yml');
const workflowPaths = [workflowPath, unitTestWorkflowPath, checkGenesisWorkflowPath];

test('workflow binds PR-derived inputs through env instead of inline shell interpolation', () => {
  const workflow = fs.readFileSync(workflowPath, 'utf8');

  assert.match(workflow, /env:\s*\n\s+HARDFORK:\s+\$\{\{\s*steps\.extract_pr_description\.outputs\.hardfork\s*\}\}/);
  assert.match(workflow, /BSC_URL:\s+\$\{\{\s*steps\.extract_pr_description\.outputs\.bsc\s*\}\}/);
  assert.doesNotMatch(workflow, /export HARDFORK=\$\{\{/);
  assert.doesNotMatch(workflow, /export BSC_URL=\$\{\{/);
});

test('bytecode check script avoids shell-based execSync for git operations', () => {
  const script = fs.readFileSync(scriptPath, 'utf8');

  assert.match(script, /execFileSync/);
  assert.doesNotMatch(script, /execSync\(`/);
});

test('workflows use maintained official action majors and avoid deprecated set-output plumbing', () => {
  for (const currentWorkflowPath of workflowPaths) {
    const workflow = fs.readFileSync(currentWorkflowPath, 'utf8');

    assert.doesNotMatch(workflow, /actions\/checkout@master/);
    assert.doesNotMatch(workflow, /actions\/cache@v3/);
    assert.doesNotMatch(workflow, /::set-output/);
  }

  const hardforkWorkflow = fs.readFileSync(workflowPath, 'utf8');
  assert.match(hardforkWorkflow, /actions\/github-script@v8/);
});

test('lint workflow pins the semantic PR action to an immutable commit', () => {
  const workflow = fs.readFileSync(lintWorkflowPath, 'utf8');

  assert.match(workflow, /amannn\/action-semantic-pull-request@[0-9a-f]{40}/);
  assert.doesNotMatch(workflow, /amannn\/action-semantic-pull-request@v4\.5\.0/);
});
