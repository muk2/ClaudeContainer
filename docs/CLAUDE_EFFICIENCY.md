# Maximizing Claude Efficiency
**How to reduce usage, cost, and friction while getting better results**

This guide explains how to use Claude efficiently—especially for coding, debugging, and architecture work—so you don’t burn through usage limits unnecessarily.

---

## 1. Choose the Right Model

This is the single biggest cost lever.

### Recommended defaults
- **Claude Sonnet**  
  Use for day-to-day coding, refactors, debugging, explanations, and reviews.
- **Claude Opus**  
  Use only for deep reasoning, architecture, or complex multi-step design.

### Rule of thumb
If a competent engineer could answer the question in under **2 minutes**, do **not** use Opus.

---

## 2. Minimize Context (Tokens = Money)

Claude charges heavily for **input tokens**. More context = more cost.

### Avoid
- Pasting entire repositories
- Sending full Dockerfiles, configs, or logs
- Re-sending the same context repeatedly

### Do instead
- Paste **only the relevant file**
- Limit to **specific line ranges**
- Share **only the failing function**
- Provide **last 20–50 lines of logs**

Example:
```
Focus ONLY on src/main.rs lines 120–180.
Ignore all other files.
```

---

## 3. Explicitly Limit Output Length

Claude defaults to verbosity unless constrained.

Always include at least one of:
- “Bullet points only”
- “Max 10 lines”
- “One paragraph maximum”
- “No explanation”

Example:
```
Return ONLY the corrected code.
No commentary.
```

This alone can cut usage by **30–50%**.

---

## 4. Disable Reasoning Narration

Claude often explains its thinking unless told not to.

Use:
```
Do not explain your reasoning.
Only provide the final answer.
```

For code:
```
Provide the solution without explanation.
```

---

## 5. Reuse Context Instead of Re-Sending It

Every token you paste is charged again.

### Efficient pattern
1. First message:
   ```
   Remember this context for later steps:
   <context>
   ```
2. Follow-ups:
   ```
   Using the same context, now do X
   ```

Only re-send context when it actually changes.

---

## 6. Break Large Tasks Into Stages

### Inefficient
> “Analyze everything and fully implement the best solution.”

### Efficient
1. “Summarize the problem in 5 bullets”
2. “Propose 2 approaches”
3. “Implement approach #1”

Smaller prompts = less wasted output.

---

## 7. Use Claude for Thinking, Not Execution

Claude is expensive at **mechanical work**.

### Best uses
- Architecture decisions
- Debugging logic
- Reviewing diffs
- Explaining failures
- Choosing between approaches

### Do locally instead
- Running builds/tests
- Formatting code
- Linting
- Dependency installs
- Large refactors

Run tools locally, then ask Claude to **interpret results**, not simulate them.

---

## 8. Containers: What They Help With (and What They Don’t)

Docker / Podman containers **do not reduce token usage directly**.

### They help by
- Avoiding repeated setup explanations
- Letting you test fixes locally
- Reducing back-and-forth debugging
- Speeding up “try → fix → retry” loops

### They do NOT help with
- Token cost
- Usage limits
- Model pricing

Efficiency still comes from prompt discipline.

---

## 9. Use a Low-Token Prompt Template

```text
You are a senior engineer.
Task: <one sentence>
Constraints:
- Bullet points only
- Max 8 bullets
- No explanations unless asked
- Assume I know the basics
Input:
<minimal input>
```

---

## 10. Warning Signs You’re Wasting Usage

If you hit limits quickly, check for:
- Overusing large models
- Long pasted contexts
- Repeating the same information
- Unbounded answers
- Asking Claude to do things your computer can do faster

---

## 11. Cost-Efficient Mental Model

Think of Claude as:
- A **decision engine**
- A **reviewer**
- A **debugging partner**

Not as:
- A shell
- A compiler
- A linter
- A CI system

---

## TL;DR Rules

- Smaller context beats better prompts
- Short answers beat perfect answers
- Local execution beats simulation
- Sonnet first, Opus only when needed
- Always cap output length

**Efficiency = discipline, not tooling.**
