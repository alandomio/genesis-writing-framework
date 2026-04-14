# R.A.L.P.H. V5: Writing Specialist Specification

## 1. Cycle Architecture (The Stateless Core)

The Ralph Wiggum cycle is based on **Rigorous Statelessness** and **Deterministic Backpressure**. Every iteration "kills" the previous process to clean the context (Dumb Zone avoidance) and is reborn reading only the "Truth on Disk" (File System Memory).

## 2. Role Definitions and NUFs (Narrative Utility Functions)

### 🏛️ The Architect (`architect.md`)
- **Responsibility:** Translates the macro vision into quantifiable micro-objectives.
- **Innovation:** Defines **Narrative Utility Functions (NUFs)** for every chapter.
- **Output:** `chapter_X_structure.md` containing:
    - `## NUFs (Goal Scoring)`: e.g. `utility(narrative): Luca discovers the betrayal -> score += 1`.
    - `## BEAT LIST`: Logical sequence of actions.

### 🕵️ The Researcher (`researcher.md`)
- **Responsibility:** Extraction of **Shadow Data** (shadow data that anchors reality).
- **Pivot Protocol:** Mandatory triangulation on 3 axes (Official, Neutral, Contrarian).
- **Output:** `dossier_chapter_X.md` (dense textual database).

### ✍️ The Writer (DSR — Dual-Stage Refinement)
Solves the *Task Coupling Dilemma* by separating creativity and structure into two stateless sub-phases:

1. **Stage 1 (Prose Engine):** Transforms the Dossier into dense narrative prose (Novel style). Focus: rhythm and actions. Saves in `draft_prose_X.md`.
2. **Stage 2 (Refinement Engine):** "Compiles" the prose into the final format, applying the `STYLE_BIBLE.md`. Saves in `chapter_X.md`.

### ⚖️ The Editor (`editor.md`)
- **Responsibility:** Executes the **System 2 Audit** and manages the **Stop-Hook**.
- **NUF Scoring:** Assigns a score (0, 0.5, 1) to each objective defined by the Architect.
- **Pass Threshold:** Requires an overall score >= 8.5/10.

## 3. Backpressure Protocol and Stop-Hook

### The Stop-Hook Mechanism
If the NUF score is below threshold or aesthetic errors (AI patterns) are detected, the Editor emits a block signal:
`FAIL: <promise>BLOCKED: [Technical Reason]</promise>` → **Exit Code 2**.
The bash script intercepts the exit, prevents the commit, and reinjects the error log into the next "clean" Writer iteration.

### Feedback Artifact
The Editor generates a temporary file `feedback_loop.md` describing:
1. **Missing NUFs:** Which narrative objectives were not achieved.
2. **Aesthetic Violations:** AI patterns or Style Bible violations detected.

The Writer must read this file at the beginning of the next loop to correct course.

## 4. Dynamic Evolution (Circuit Breaker)

If a Beat fails 3 consecutive times:

1. **Block Analysis:** The Editor writes in `activity.md` whether the problem is logical (Architect/Researcher) or stylistic (Writer).
2. **Safe-Fail:** The system requires human intervention to modify the `STYLE_BIBLE` rules or the NUF objectives, preventing infinite loops.

## 5. OPERATIONAL MANTRA

> "Statelessness is sanity. Context is liability. Backpressure is quality."
