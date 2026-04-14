# Genesis Writing Framework

**G**enerative **E**ngine for **N**arrative & **E**ditorial **S**ystems via **I**terative **S**tructure

> Writing books with AI is not about handing creativity over to a machine. It is about designing a system that can take human imagination and turn it into a high-quality artifact.

## The Problem

AI does not write bad books because it is dumb. It writes bad books because we often ask it to do complex work with no architecture.

A naive prompt asking a language model to "write a chapter" is like asking a junior engineer to build a production system with one instruction and no scaffolding. The output is not completely wrong — it is just lifeless, generic, and subtly wrong in ways that compound over a long document.

The solution is not a better prompt. It is engineering.

## What This Framework Is

The Genesis Writing Framework is a stateless, multi-agent pipeline for producing long-form, high-quality written content with AI. It applies software engineering principles — decomposition, role separation, validation gates, feedback loops, and circuit breakers — to the problem of book-length writing.

Core concepts:

- **Decomposition**: A book is a hierarchy. Book → Parts → Chapters → Scenes → Beats. Each beat is an atomic unit small enough to generate, review, retry, and improve independently.
- **Role separation**: Four specialized agents handle distinct cognitive tasks. No agent does everything.
- **Stateless execution**: Every agent starts fresh. Memory lives on disk, not in context. This prevents context drift over long writing sessions.
- **Validation gates**: Every beat is scored before being committed. Outputs that fail are retried with specific feedback. The machine generates text; the architecture gives that text direction and quality.
- **Shadow Data**: The research layer produces dense, sensory micro-details — prices, smells, exact quotes, physical textures — that ground narrative in retrieved reality rather than model memory. This is the anti-hallucination strategy.

## The Ralph Loop

The production pipeline runs as a stateless agentic loop. Each agent reads only from disk, executes its task, writes output to disk, and exits. The next agent starts clean.

```
[ARCHITECT]   → chapter_X_structure.md (NUFs + Beat List)
      ↓
[RESEARCHER]  → dossier_chapter_X.md ([PUBLIC] / [SHADOW] / [CONFLICT])
      ↓
[WRITER S1]   → draft_prose_X.md (raw narrative, no formatting)
      ↓
[WRITER S2]   → chapter_X.md (final formatted prose)
      ↓
[EDITOR]      → scores NUFs (pass ≥ 8.5/10)
      ├── PASS → delete feedback_loop.md → COMMIT → [REVIEWER]
      └── FAIL → feedback_loop.md → WRITER S1 (clean context, max 3 retries)
                        ↑ Circuit Breaker on 3rd failure → escalate to human
      ↓ (on PASS)
[REVIEWER]    → scores across 6 dimensions (/60)
      ├── ≥ 48/60 → inline corrections → DONE
      ├── 36–47   → section rewrites   → DONE
      └── < 36    → rewrite_plan       → escalate to human
```

**Mantra:** *Statelessness is sanity. Context is liability. Backpressure is quality.*

## The Five Agents

| Agent | Role | Output |
|-------|------|--------|
| **The Architect** | System 2 strategist. Defines structure, NUFs, and beat list. Never writes prose. | `chapter_X_structure.md` |
| **The Researcher** | Forensic investigator. Extracts Shadow Data. No invention — only sourced facts. | `dossier_chapter_X.md` |
| **The Writer (Stage 1)** | Prose Engine. Transforms dossier into raw narrative following beat sequence. | `draft_prose_X.md` |
| **The Writer (Stage 2)** | Refinement Engine. Applies Style Bible to raw prose. Final formatted output. | `chapter_X.md` |
| **The Editor** | Quality gate. Scores NUFs, runs Anti-AI checklist. Generates repair instructions on fail. | `feedback_loop.md` (on fail) |
| **The Reviewer** | Senior editorial read. Tests whether prose shows or merely tells. Scores across 6 dimensions. | `review_chapter_X.md` |

## Narrative Utility Functions (NUFs)

The Architect defines measurable objectives for every chapter. Not vague goals — scorable ones. The Editor assigns 0, 0.5, or 1 to each NUF. Pass threshold: ≥ 8.5/10.

Example:
```
utility(narrative): Reader discovers the protagonist's betrayal → score += 1
utility(factual): Bread price in Rome circa 79 AD cited with source → score += 1
utility(emotional): Reader feels the class tension of the Aventine → score += 1
```

This turns "is this good?" into an engineering question: "which objectives were not met, and why?"

## Dual-Stage Refinement (DSR)

LLMs cannot be simultaneously creative and correctly formatted. The Dual-Stage Refinement decouples these concerns:

- **Stage 1 (Prose Engine)**: Focus on narrative. Rhythm, action, dialogue, sensory detail. No word limits, no formatting constraints. Output: raw prose.
- **Stage 2 (Refinement Engine)**: Apply the Style Bible. Remove AI tells. Meet format and length targets. Output: final chapter.

Separating these stages dramatically improves output quality.

## Project File Structure

Every book project uses this layout:

```
books/<book-slug>/
├── PRD.md                  # Book product requirements (vision, audience, enemy, success criteria)
├── INSTRUCTION.md          # Pipeline configuration (all 5 agents, NUF format, workflow)
├── STYLE_BIBLE.md          # Voice rules, banned patterns, Anti-AI checklist, persona activation
├── oracle_questions.md     # Open questions only the human can answer
├── activity.md             # Session log, Circuit Breaker records
├── ralph.sh                # Pipeline runner (bash)
├── chapter_X_structure.md  # Architect output: NUFs + Beat List
├── dossier_chapter_X.md    # Researcher output: [PUBLIC] / [SHADOW] / [CONFLICT]
├── draft_prose_X.md        # Writer Stage 1 output (temp)
├── chapter_X.md            # Writer Stage 2 output (final)
├── feedback_loop.md        # Editor repair instructions (on fail, deleted on pass)
└── review_chapter_X.md     # Reviewer output
```

## Repository Contents

```
genesis-writing-framework/
├── README.md                          # This file
├── GENESIS.md                         # Framework overview (G.E.N.E.S.I.S.)
├── RALPH_WRITING_SPEC.md              # Ralph Loop V5 specification
├── PROJECT_KICKSTART_PROTOCOL.md      # New project onboarding protocol
├── ralph/
│   └── prompts/
│       ├── architect.md               # Architect agent prompt
│       ├── researcher.md              # Researcher agent prompt
│       ├── writer.md                  # Writer agent prompt (DSR)
│       └── editor.md                  # Editor agent prompt (Stop-Hook)
├── .claude/
│   └── skills/
│       └── new-book/
│           ├── SKILL.md               # Claude Code skill: bootstrap a new book
│           └── ralph.sh               # 5-agent stateless pipeline runner
└── memories/
    ├── framework.md                   # Multi-agent framework reference
    ├── llm-as-judge.md                # LLM validation guidelines
    └── narrative-personas.md          # Writer persona catalog
```

## Getting Started

### 1. Bootstrap a new book project

If you use [Claude Code](https://claude.ai/claude-code), install the `new-book` skill and run:

```
/new-book <your book idea>
```

The skill will walk you through an 8-question interview, generate all configuration files, and run the first chapter through the full Ralph Loop.

### 2. Run the pipeline manually

```bash
cd books/<your-book>
./ralph.sh 1              # Full pipeline, Chapter 1
./ralph.sh 1 architect    # Architect only
./ralph.sh 1 researcher   # Researcher only
./ralph.sh 1 writer       # Writer Stage 1 + 2
./ralph.sh 1 editor       # Editor + retry loop
./ralph.sh 1 reviewer     # Reviewer only
./ralph.sh 1 status       # Check pipeline state
./ralph.sh review_all     # Review all existing chapters
```

### 3. Where the creativity actually is

The AI does not make the decisions that matter. You do: the voice, the tone, the angle, what the book is against, what it promises. You define the enemy, the persona, the sensory texture.

The AI generates text. The architecture gives that text direction, quality, and meaning.

## Requirements

- `claude` CLI (`claude-code`)
- bash 4.0+ (macOS: `brew install bash`)
- Claude API access (Sonnet-class model recommended)

## License

MIT
