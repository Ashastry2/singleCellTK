# Prompt Log

A verbatim record of every prompt given to the AI agent working on this branch
(`agentic_ai_workshop`). Maintained as a standing rule: **every new user prompt is appended
here verbatim, unedited, before or alongside the work it triggers.**

Purpose: reproducibility. Anyone reading the resulting commits should be able to see exactly
what was asked, in what order, so the provenance of every design decision is traceable back
to a human instruction. The design decisions themselves are recorded separately as ADRs in
[`docs/adr/`](docs/adr/).

Format: newest session at the bottom. Within a session, prompts are numbered in the order
received. Text is reproduced exactly as typed, including typos and URLs.

---

## Session 1 — 2026-07-31

Agent: Claude Code (Opus 5). Working directory:
`~/Downloads/Claude/PneumoPath/Agentic_AI_workshop_07312026/singlecelltk_refactor`.

### Prompt 1.1

> We are in the planning phase right now. I have a github repo - https://github.com/Ashastry2/singleCellTK and I would like to improve documentation, write better tests, find if there are exisiting bugs and come up with improvement suggestions. You can use these skills - https://github.com/seandavi/ai-agent-skills/blob/6117255f15afa291c3ac1a01583697b92812bfd9/SKILLS.md. You will use architectural design record for recording design decisions in this project. For the documentation, start with the exisiting documentation and find how they can be improved. You can also identify ways to reduce external package dependencies. Also add documentation and agent guidelines for someone who is trying to add a new tool or a function to the toolkit.

### Prompt 1.2

> Also document all prompts to prompts.md

### Prompt 1.3

> Actually you are allowed to do push to the github https://github.com/Ashastry2/singleCellTK/tree/agentic_ai_workshop

### Prompt 1.4

> Okay go ahead. Use sub-agents as needed and do each step as a step by step process and then write a handoff document for the next step.

---

### Clarifying questions asked by the agent, and the answers given

These were answered through a multiple-choice prompt rather than free text, so they are
recorded as question/answer pairs rather than verbatim quotes.

| Question | Answer |
| --- | --- |
| The repo isn't cloned locally yet and this working directory is empty. How should I get the code? | Clone into this directory |
| What form should the deliverables take? | Local commits on a branch (later amended by Prompt 1.3 to: push to `agentic_ai_workshop`) |
| singleCellTK is huge (~200 R files, 100+ dependencies, full install takes a long time). How deep should the first pass go? | Static-only first — audit by reading and static tools, no Bioconductor install; runtime testing deferred |
| Which of these should the first pass prioritize? | Documentation improvement; Contributor guide + agent guidelines |

The remaining items from Prompt 1.1 — bug hunting, test expansion, and dependency
reduction — were explicitly deferred to a second pass on the basis of these answers. They
are scoped with evidence in `docs-audit/next-pass.md` rather than implemented in session 1.
