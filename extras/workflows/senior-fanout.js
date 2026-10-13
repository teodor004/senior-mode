export const meta = {
  name: 'senior-fanout',
  description: 'senior-mode: execute approved work packages in parallel, adversarially review, bounded fix loop',
  phases: [
    { title: 'Execute', detail: 'one worktree agent per work package' },
    { title: 'Review', detail: 'adversarial review of all WP branches' },
    { title: 'Fix', detail: 'bounded fix loop on blocker/major findings' },
  ],
}

// args (passed by Claude from plan.md JSON block):
// { slug, baseSha, maxFixRounds?: 2, wps: [{ id, title, agent, model, effort, wpText, testCommand, agentType? }] }
// agentType (optional) runs the WP as a custom subagent: 'senior-mode:implementer-complex' (plugin install)
// or 'implementer-complex' (manual install). Omit it to use the default workflow agent.
// NOTE: Date.now()/Math.random() throw inside workflows - do not use them.
const A = args || {}
const maxFix = A.maxFixRounds ?? 2
const asType = wp => (wp.agentType ? { agentType: wp.agentType } : {})

const resultSchema = {
  type: 'object',
  required: ['wp', 'status', 'branch', 'tests'],
  properties: {
    wp: { type: 'string' },
    status: { type: 'string', enum: ['done', 'partial', 'blocked'] },
    branch: { type: 'string' },
    head_sha: { type: 'string' },
    worktree_path: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    tests: { type: 'object', properties: { command: { type: 'string' }, passed: { type: 'boolean' }, summary: { type: 'string' } } },
    deviations: { type: 'array', items: { type: 'string' } },
  },
}

const reviewSchema = {
  type: 'object',
  required: ['verdict', 'findings'],
  properties: {
    verdict: { type: 'string', enum: ['approve', 'request_changes', 'block'] },
    findings: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' }, severity: { type: 'string' }, wp: { type: 'string' },
      file: { type: 'string' }, claim: { type: 'string' }, evidence: { type: 'string' }, fix: { type: 'string' } } } },
  },
}

const wpPrompt = (wp, extra = '') => `You are executing ONE work package (${wp.id}) for senior-mode run "${A.slug}".
Act as the "${wp.agent}" role. BASE_SHA: ${A.baseSha}
${extra}
First run: git merge-base --is-ancestor ${A.baseSha} HEAD || git checkout -B "$(git rev-parse --abbrev-ref HEAD)" ${A.baseSha}
Edit ONLY the owned files listed. Run: ${wp.testCommand}. Commit your work in your worktree. Never push or merge.
Report worktree_path as the output of: git rev-parse --show-toplevel
WORK PACKAGE:
${wp.wpText}
Return JSON matching the schema.`

phase('Execute')
log(`senior-fanout: ${A.wps.length} work packages`)
let results = await pipeline(A.wps, wp =>
  agent(wpPrompt(wp), {
    label: wp.id,
    schema: resultSchema,
    model: wp.model,
    effort: wp.effort,
    isolation: 'worktree',        // WPs mutate files in parallel; unchanged worktrees are auto-removed
    ...asType(wp),
  }),
)
results = results.filter(Boolean)

phase('Review')
const review = await agent(
  `Adversarially review these senior-mode WP branches against their acceptance criteria. Read-only: use git diff ${A.baseSha}..<branch>.
Branches: ${JSON.stringify(results.map(r => ({ wp: r.wp, branch: r.branch, tests: r.tests })))}
Every blocker/major finding needs concrete evidence.`,
  { label: 'adversarial-review', schema: reviewSchema, model: 'opus', effort: 'high' }, // opus/high per the routing policy
)

phase('Fix')
let open = (review?.findings || []).filter(f => f.severity === 'blocker' || f.severity === 'major')
for (let round = 1; round <= maxFix && open.length > 0; round++) {
  const byWp = [...new Set(open.map(f => f.wp))]
  const fixes = await pipeline(byWp, id => {
    const wp = A.wps.find(w => w.id === id)
    const r = results.find(x => x.wp === id)
    if (!wp || !r) return null
    // the WP branch is still checked out in its worktree, so `git switch` to it would fail - work there instead
    const where = r.worktree_path ? `at ${r.worktree_path}` : '(find it with `git worktree list`)'
    return agent(
      wpPrompt(wp, `FIX ROUND ${round}. Before anything else, cd into the worktree that has branch ${r.branch} checked out ${where}.
Fix ONLY these findings:\n${JSON.stringify(open.filter(f => f.wp === id))}`),
      { label: `${id}-fix-${round}`, schema: resultSchema, model: wp.model, effort: wp.effort, ...asType(wp) },
    )
  })
  for (const f of fixes.filter(Boolean)) {
    const i = results.findIndex(x => x.wp === f.wp)
    if (i >= 0) results[i] = { ...results[i], ...f }
  }
  log(`fix round ${round}: ${fixes.filter(Boolean).length} WPs updated`)
  const recheck = await agent(
    `Re-check ONLY these previously reported findings on the updated branches and report which remain: ${JSON.stringify(open)}`,
    { label: `recheck-${round}`, schema: reviewSchema, model: 'opus', effort: 'high' },
  )
  open = (recheck?.findings || []).filter(f => f.severity === 'blocker' || f.severity === 'major')
}

return { slug: A.slug, results, openFindings: open, gate: open.length === 0 && results.every(r => r.tests?.passed) ? 'passed' : 'failed' }
