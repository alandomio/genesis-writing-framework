# The Validator: LLM-as-a-Judge Editor Guidelines

This document defines how the **Validation Gate** works within the Ralph Wiggum Loop (Validation Phase) for generative writing projects.

Instead of entrusting correction to the human or blind heuristic scripts, the entire draft is "judged" by a separate LLM agent (typically a reasoner-class model like Claude Sonnet or equivalent).

## DUAL-STAGE REFINEMENT (DSR) AND SCORING (0–10)

The Validation Gate is no longer a single block — it is split into two sequential passes (Dual-Stage Refinement) to separate cognitive load:

### STAGE 1: Structural and Logical Coherence (The Incorruptible Critic)

The Critic agent analyzes only logic, adherence to the narrative plan, and verifies that the JSON Dossier directives have been respected 100%. Only when Stage 1 passes does the draft proceed to the stylistic layer.

### STAGE 2: Stylistic Refinement (Anti-AI Hair-Splitter)

Receiving the draft from Stage 1, the agent applies a **base score of 10**, deducting points through three severe penalties. If the final score drops below **8.5/10**, stylistic validation fails.

#### 1. Formatting and AI Pattern Penalty (−3 points)
- **Hidden Lists:** Use of the "Rule of 3" (e.g.: "He was tired, hungry and alone.").
- **Structural Symmetry:** Conclusions with moral lectures ("In the end, we learned that...").
- **Fluff / Filler:** Redundant adjectives or adverbs.

*Action:* Deduct points and request disassembly of the sentence.

#### 2. Abstract Vocabulary Penalty (−3 points)
- AI Bureaucratic language: "Multifaceted", "Holistic", "Journey (metaphorical)".
- The prose appears as a report instead of sensory narration.

*Action:* Deduct points, impose exclusive use of active verbs and physical lexicon.

#### 3. Rhythmic Variance Penalty — Gary Provost (−4 points)
- Syllabic uniformity or "Lullaby" effect (excessive hypotaxis).

*Action:* Require "staccato" sequences fused with long sentences.

### DYNAMIC EVOLUTION (Safe-Fail Mechanism)

**Critical:** If the Judge rejects the output for multiple iterations (e.g. 3 consecutive times) on the exact same problem without any progress, it must annotate the dead end in an external file (`progress.md`), indicating a recommended "Dynamic Specification Evolution". The goal is to prevent infinite loops where a utopian narrative schema causes perpetual iterations and budget waste.

## EXAMPLE PROMPT FOR THE JUDGE

To insert into the validation script (e.g. `ralph_validate.py`):

```markdown
You are the Aesthetic Reviewer (Stage 2: Anti-AI Hair-Splitter).
The draft you receive is already structurally correct. Your sole objective is to deconstruct and destroy generic AI prose.
Evaluate by applying penalties for AI Patterns, Abstract Vocabulary, and Rhythmic Variance.
Provide the score using the format `<score>X.X</score>`.
In case of failure (`< 8.5`), indicate corrections in the `<feedback>` block.
**Antiloop Safety:** If you notice that a specific aesthetic feedback has been ignored for 3 consecutive iterations, record a warning or "suggestion" in `progress.md` to enable dynamic rule evolution.
```
