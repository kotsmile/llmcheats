# Development Flow — fast flow (bugs and hotfixes)

## 5. Fast flow — bugs and hotfixes

The full flow compressed to what a defect actually needs. Target duration:
**minutes to hours, not days** (§7, `devflow/4-never-skip.md`).

### F1. Scope — *whoever caught it*
- Reproduction, blast radius (who is affected, is data at risk), severity.
- Decision: hotfix now vs. scheduled fix. Data-loss or security ⇒ now.

### F2. Infra inspection — *devops*
- **First question: is this code or infra?** Check system health before
  blaming the code: recent deploys, resource saturation, dependency outages,
  certificate/quota expiry. Half of "bugs" are infra events; a code fix for an
  infra problem wastes the release *and* leaves the problem.
- **Artifact:** one paragraph: what was ruled out and how.

### F3. Development — *developer*
- If a human operator is not watching live: post the fix plan in **one
  sentence** and get an ack before coding (same rule as §3.6 in
  `devflow/2-full-flow.md`, compressed).
- The smallest change that fixes the defect. No opportunistic refactoring in
  a hotfix — that's a follow-up ticket.
- **A test that reproduces the bug is written first** and fails before the fix,
  passes after. This is the one non-negotiable test of the fast flow.

### F4. Testing — *developer*
- The new reproduction test; the suite of the affected area; **regression
  check of adjacent flows**; and an explicit re-check of the *original
  reported problem* on a stand or locally composed stack — the fix must be
  observed fixing it, not inferred.

### F5. Security approval — *security auditor*
- Scaled to the diff: a five-minute read for a typo-level fix; a real review
  the moment the fix touches auth, input handling, SQL, secrets, or PII.
- May be the same person as the developer on a small team — then it is a
  deliberate second pass with the `webapp/5-security.md` checklist, not a skipped
  step.

### F6. DevOps approval — *devops*
- Deploy safety: does the fix carry a migration (hotfixes should almost never),
  config change, or restart ordering? Is rollback still one command?

### F7. Release — *devops* (if applicable)
- Standard mechanism, then **watch it land**: error rate and the original
  symptom, for at least a few minutes. A hotfix that isn't verified in
  production is a hypothesis.
- Backport/forward-port: make sure the fix is on the main branch, not only on
  the release branch.
