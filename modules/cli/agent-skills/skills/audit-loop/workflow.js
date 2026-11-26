export const meta = {
  name: 'audit-loop',
  description: 'Per-domain audit of code or docs: a reviewer model and an implementer model go back and forth until the reviewer finds no violation',
  phases: [
    { title: 'Audit', detail: 'the reviewer audits each domain' },
    { title: 'Converge', detail: 'the implementer fixes or disputes, the reviewer rules, until no violation remains' },
  ],
}

// args, filled in by the skill that runs this (audit-loop for code, docs-audit-loop for text):
// {
//   project: 'one line on what the project is',
//   root: '/abs/path/to/the/worktrees',          // each domain works in `${root}/${key}`
//   base: 'main',                                // the branch the worktrees were cut from
//   prefix: 'audit',                             // branches are `${prefix}/${key}`
//   auditBrief: 'how the reviewer sweeps a domain and what counts as a finding',
//   fixBrief: 'what a fix must come with',
//   closeBrief: 'what the reviewer checks before closing a fixed finding',
//   reviewer: 'claude-mythos-5-2[1m]',
//   implementer: 'claude-opus-5-5[1m]',
//   maxRounds: 20,                               // a backstop against a loop that never converges
//   guides: ['~/.claude/skills/write-rust/SKILL.md', ...],  // read before starting
//   gate: ['cargo fmt --all --check', ...],      // run green before the implementer answers
//   outOfScope: 'what is not a finding in this project (e.g. tunings that need corpus scores)',
//   domains: [{ key: 'engine', files: 'src/engine.rs, ...', focus: 'what to look hardest at' }],
// }
const A = args
const MAX_ROUNDS = A.maxRounds ?? 20
const PREFIX = A.prefix ?? 'audit'

const FINDING = {
  type: 'object',
  properties: {
    id: { type: 'string', description: 'stable id like ENGINE-3; never reuse one' },
    severity: { type: 'string', enum: ['wrong', 'improve'], description: 'wrong = a defect: a bug, unsoundness, a reachable panic, a swallowed error, a false claim, a broken rule; improve = correct but costly, unidiomatic or harder to read than it needs to be' },
    file: { type: 'string' },
    line: { type: 'integer' },
    title: { type: 'string' },
    scenario: { type: 'string', description: 'concretely what goes wrong: the trigger and its result, or the text and how it misleads or breaks a rule' },
    fix: { type: 'string' },
  },
  required: ['id', 'severity', 'file', 'line', 'title', 'scenario', 'fix'],
}

const AUDIT_SCHEMA = {
  type: 'object',
  properties: {
    findings: { type: 'array', items: FINDING },
    fine: { type: 'string', description: 'counts of candidates judged fine, by category' },
    not_covered: { type: 'string' },
  },
  required: ['findings', 'fine', 'not_covered'],
}

const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    responses: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          action: { type: 'string', enum: ['fixed', 'disputed'] },
          commits: { type: 'array', items: { type: 'string' }, description: 'short hashes and subjects' },
          note: { type: 'string', description: 'what changed and why it is right, or why the finding is wrong, with evidence' },
          outside_scope_files: { type: 'array', items: { type: 'string' } },
        },
        required: ['id', 'action', 'commits', 'note', 'outside_scope_files'],
      },
    },
    gate_passed: { type: 'boolean' },
    gate_notes: { type: 'string', description: 'which gate commands ran and any failures' },
  },
  required: ['responses', 'gate_passed', 'gate_notes'],
}

const REREVIEW_SCHEMA = {
  type: 'object',
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          status: { type: 'string', enum: ['closed', 'reopened'], description: 'closed = the fix is right or the dispute convinced; reopened = not right yet' },
          note: { type: 'string' },
        },
        required: ['id', 'status', 'note'],
      },
    },
    new_findings: { type: 'array', items: FINDING, description: 'regressions the diff introduced, or a clear defect missed before; not churn' },
    satisfied: { type: 'boolean' },
  },
  required: ['verdicts', 'new_findings', 'satisfied'],
}

const common = (d) => `You are working on ${A.project} in the git worktree ${A.root}/${d.key}, on branch ${PREFIX}/${d.key}, cut from ${A.base}. Work ONLY in that directory: cd there first, and never touch the main checkout or another worktree. The CLAUDE.md files that apply are the project's rules. Before starting, read: ${A.guides.join(', ')}.

Domain: ${d.key}
Files in scope: ${d.files}
Focus: ${d.focus}`

const show = (fs) => JSON.stringify(fs, null, 1)

async function runDomain(d) {
  const audit = await agent(`${common(d)}

ROLE: reviewer. Do not edit files. Read whatever else you need to judge what you find, but report only findings in the files in scope.

${A.auditBrief}

Contested style choices are not findings. Not findings in this project: ${A.outOfScope}

Nothing is left for the owner: you make every call, and report only violations you want fixed. Use ids ${d.key.toUpperCase()}-1, -2, ...`, { label: `audit:${d.key}`, phase: 'Audit', model: A.reviewer, schema: AUDIT_SCHEMA })
  if (!audit) return { domain: d.key, error: 'audit agent failed' }

  const all = new Map()
  for (const f of audit.findings) all.set(f.id, { ...f, status: 'open', thread: [] })
  log(`${d.key}: ${audit.findings.length} findings`)

  let round = 0
  let satisfied = audit.findings.length === 0
  while (!satisfied && round < MAX_ROUNDS) {
    round++
    const open = [...all.values()].filter(f => f.status === 'open')
    const impl = await agent(`${common(d)}

ROLE: implementer, round ${round}. A reviewer audited this domain. Answer every open finding below: fix it, or dispute it with evidence (code, a test, the compiler) when you are confident it is wrong. Hold the line when you are right; concede plainly when you are not. Nothing is left for the owner: every finding ends fixed or disputed, and the reviewer rules on disputes.

${A.fixBrief}

Stay in the files in scope; if a fix must touch another file, keep it minimal and list it in outside_scope_files. Comments and docs follow the CLAUDE.md voices.

Commit each logical fix on its own on this branch, in the commit style CLAUDE.md sets, with \`git -c commit.gpgsign=false commit\`: the owner's merge re-signs. Never add CLAUDE.md or .claude/, never push.

Before answering, run the gate in the worktree and get it green, never by loosening a test:
${A.gate.map(c => `- \`${c}\``).join('\n')}

Open findings, each with its thread so far:
${show(open)}`, { label: `impl:${d.key}:r${round}`, phase: 'Converge', model: A.implementer, schema: IMPL_SCHEMA })
    if (!impl) { log(`${d.key}: implementer failed in round ${round}`); break }
    for (const r of impl.responses) {
      const f = all.get(r.id)
      if (f) f.thread.push({ round, by: 'implementer', ...r })
    }

    const rr = await agent(`${common(d)}

ROLE: reviewer, round ${round}. You audited this domain; the implementer has answered. Do not edit files. Read \`git log ${A.base}..HEAD\` and \`git diff ${A.base}...HEAD\`, run what you need, and rule on each open finding:
- closed: the fix is right (${A.closeBrief}), or the dispute convinced you
- reopened: not right yet; say exactly what is wrong and what would close it

Nothing is left for the owner: you make the final call on every finding, disputes included. Hold your ground where you are right and concede where you were shown wrong. List new_findings only for regressions the diff introduced or a clear defect you missed, not churn or style. Set satisfied=true only when no violation remains: every finding closed and new_findings empty. Implementer's gate: passed=${impl.gate_passed}; ${impl.gate_notes}

Findings under review, each with its thread:
${show(open.map(f => all.get(f.id)))}`, { label: `review:${d.key}:r${round}`, phase: 'Converge', model: A.reviewer, schema: REREVIEW_SCHEMA })
    if (!rr) { log(`${d.key}: reviewer failed in round ${round}`); break }
    for (const v of rr.verdicts) {
      const f = all.get(v.id)
      if (!f) continue
      f.thread.push({ round, by: 'reviewer', status: v.status, note: v.note })
      f.status = v.status === 'reopened' ? 'open' : v.status
    }
    for (const nf of rr.new_findings) {
      if (all.has(nf.id)) nf.id = `${nf.id}-r${round}`
      all.set(nf.id, { ...nf, status: 'open', thread: [] })
    }
    const stillOpen = [...all.values()].filter(f => f.status === 'open').length
    satisfied = rr.satisfied && stillOpen === 0
    log(`${d.key}: round ${round}, ${stillOpen} open, satisfied=${satisfied}`)
  }
  if (!satisfied) log(`${d.key}: stopped after ${round} rounds with violations open`)

  return {
    domain: d.key,
    branch: `${PREFIX}/${d.key}`,
    rounds: round,
    satisfied,
    fine: audit.fine,
    not_covered: audit.not_covered,
    findings: [...all.values()].map(f => ({ id: f.id, severity: f.severity, file: f.file, line: f.line, title: f.title, status: f.status, last: f.thread.slice(-2) })),
  }
}

phase('Audit')
return await parallel(A.domains.map(d => () => runDomain(d)))
