#!/opt/homebrew/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# ralph.sh — Ralph Loop V5.1 — 5-Agent Stateless Writing Pipeline
# Generic template: works for any book project with INSTRUCTION.md + PRD.md + STYLE_BIBLE.md
# Requires bash 4.0+. macOS: shebang uses /opt/homebrew/bin/bash (bash 5.x).
# ══════════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ./ralph.sh <chapter>               Full pipeline (skips completed phases)
#   ./ralph.sh <chapter> architect     Architect only
#   ./ralph.sh <chapter> researcher    Researcher only
#   ./ralph.sh <chapter> writer        Writer Stage 1 + 2
#   ./ralph.sh <chapter> writer1       Writer Stage 1 only
#   ./ralph.sh <chapter> writer2       Writer Stage 2 only
#   ./ralph.sh <chapter> editor        Editor only (with retry loop)
#   ./ralph.sh <chapter> reviewer      Reviewer only (editorial audit + corrections)
#   ./ralph.sh review_all              Review all chapters with existing files
#   ./ralph.sh <chapter> status        Show pipeline state for chapter N
#
# Flags:
#   --force    Re-run phase even if output files already exist
#   --model    Override model (default: claude-sonnet-4-6)
#   --dry-run  Show what would run without executing
#
# Examples:
#   ./ralph.sh 1                        # Full pipeline, Chapter 1
#   ./ralph.sh 1 researcher --force     # Re-research Chapter 1
#   ./ralph.sh 1 editor                 # Run Editor + retry loop
#   ./ralph.sh 1 reviewer               # Editorial audit, Chapter 1
#   ./ralph.sh review_all               # Review all existing chapters
#   ./ralph.sh 1 status                 # Check what's done
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
  echo "Error: ralph.sh requires bash 4.0+. Your bash: ${BASH_VERSION}"
  echo "Fix: /opt/homebrew/bin/bash ralph.sh $*"
  echo "  or: brew install bash && add /opt/homebrew/bin to PATH"
  exit 1
fi

# ─── CONFIG ────────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_RETRIES=3
DEFAULT_MODEL="claude-sonnet-4-6"
# Writer Stage 2 and Reviewer need long output — always use Sonnet or better
LONG_OUTPUT_MODEL="claude-sonnet-4-6"
LOG_DIR="${PROJECT_DIR}/.ralph_logs"

# ─── ARGS ──────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: ./ralph.sh <chapter_number|review_all> [phase] [--force] [--dry-run] [--model <model>]"
  echo "Phases: all | architect | researcher | writer | writer1 | writer2 | editor | reviewer | status"
  echo "Special: ./ralph.sh review_all  — runs reviewer on every chapter with existing files"
  exit 1
fi

CHAPTER="${1}"
PHASE="all"
FORCE=false
DRY_RUN=false
MODEL="${DEFAULT_MODEL}"

if [[ "${CHAPTER}" == "review_all" ]]; then
  PHASE="review_all"
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    all|architect|researcher|writer|writer1|writer2|editor|reviewer|status)
      PHASE="$1"; shift ;;
    --force)    FORCE=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --model)    MODEL="${2:?--model requires a value}"; shift 2 ;;
    *)          echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ─── FILE PATHS ────────────────────────────────────────────────────────────
STRUTTURA="${PROJECT_DIR}/chapter_${CHAPTER}_structure.md"
DOSSIER="${PROJECT_DIR}/dossier_chapter_${CHAPTER}.md"
DRAFT_PROSE="${PROJECT_DIR}/draft_prose_${CHAPTER}.md"
CHAPTER_FILE="${PROJECT_DIR}/chapter_${CHAPTER}.md"
FEEDBACK="${PROJECT_DIR}/feedback_loop.md"
ACTIVITY="${PROJECT_DIR}/activity.md"
INSTRUCTION="${PROJECT_DIR}/INSTRUCTION.md"
STYLE_BIBLE="${PROJECT_DIR}/STYLE_BIBLE.md"
PRD="${PROJECT_DIR}/PRD.md"
ORACLE="${PROJECT_DIR}/oracle_questions.md"
REVIEW="${PROJECT_DIR}/review_chapter_${CHAPTER}.md"
REWRITE_PLAN="${PROJECT_DIR}/rewrite_plan_chapter_${CHAPTER}.md"
BOOK_REWRITE_PLAN="${PROJECT_DIR}/BOOK_REWRITE_PLAN.md"

# ─── COLORS ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

log()     { echo -e "${BLUE}[RALPH]${NC} $*"; }
ok()      { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*" >&2; }
info()    { echo -e "${DIM}    $*${NC}"; }
divider() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${CYAN}  $*${NC}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════${NC}\n"; }

# ─── HELPERS ───────────────────────────────────────────────────────────────
file_exists()  { [[ -f "$1" ]]; }
should_run()   { ! file_exists "$1" || $FORCE; }
timestamp()    { date '+%Y-%m-%d %H:%M:%S'; }

log_run() {
  local phase="$1"
  mkdir -p "$LOG_DIR"
  echo "${LOG_DIR}/chapter_${CHAPTER}_${phase}_$(date +%Y%m%d_%H%M%S).log"
}

export CLAUDE_CODE_MAX_OUTPUT_TOKENS="32000"
CLAUDE_SETTINGS='{"env":{"CLAUDE_CODE_MAX_OUTPUT_TOKENS":"32000"}}'

run_claude() {
  local prompt="$1"
  local log_file="${2:-/dev/null}"

  if $DRY_RUN; then
    echo -e "${DIM}[DRY-RUN] Would invoke claude -p with model=${MODEL}${NC}"
    echo -e "${DIM}          Prompt preview: $(echo "$prompt" | head -3 | tr '\n' ' ')...${NC}"
    return 0
  fi

  claude -p "$prompt" \
    --permission-mode bypassPermissions \
    --model "$MODEL" \
    --add-dir "$PROJECT_DIR" \
    --settings "$CLAUDE_SETTINGS" \
    2>&1 | tee "$log_file"
}

# ─── STATUS ────────────────────────────────────────────────────────────────
show_status() {
  echo ""
  echo -e "${BOLD}Chapter ${CHAPTER} — Pipeline Status${NC}"
  echo "────────────────────────────────────────────────────"

  check_file() {
    local label="$1"; local file="$2"
    if file_exists "$file"; then
      local lines; lines=$(wc -l < "$file" | tr -d ' ')
      local size; size=$(wc -c < "$file" | awk '{printf "%.1f KB", $1/1024}')
      ok "$label"
      info "${file##*/} — ${lines} lines, ${size}"
    else
      warn "$label"
      info "${file##*/} — NOT FOUND"
    fi
  }

  check_file "Architect  (structure)" "$STRUTTURA"
  check_file "Researcher (dossier)  " "$DOSSIER"
  check_file "Writer S1  (draft)    " "$DRAFT_PROSE"
  check_file "Writer S2  (chapter)  " "$CHAPTER_FILE"

  if file_exists "$FEEDBACK"; then
    warn "Editor     — feedback_loop.md exists (chapter needs revision)"
    info "Run: ./ralph.sh ${CHAPTER} editor"
  else
    ok "Editor     — No feedback (clean state)"
  fi

  if file_exists "$ACTIVITY"; then
    local entries; entries=$(grep -c "^## Circuit Breaker" "$ACTIVITY" 2>/dev/null || echo 0)
    [[ $entries -gt 0 ]] && warn "Circuit Breaker — ${entries} event(s) logged in activity.md"
  fi

  if file_exists "$REVIEW"; then
    ok "Reviewer   — review_chapter_${CHAPTER}.md exists"
    file_exists "$REWRITE_PLAN" && warn "Reviewer   — rewrite_plan_chapter_${CHAPTER}.md exists (full rewrite needed)"
  else
    warn "Reviewer   — No review (run: ./ralph.sh ${CHAPTER} reviewer)"
  fi

  echo ""
  echo -e "${DIM}Logs: ${LOG_DIR}/${NC}"
  echo ""
}

# ─── ARCHITECT ─────────────────────────────────────────────────────────────
run_architect() {
  local MODEL="${LONG_OUTPUT_MODEL:-$MODEL}"
  divider "🏛️  ARCHITECT — Chapter ${CHAPTER}"

  if ! should_run "$STRUTTURA"; then
    ok "Structure exists. Skipping (--force to override)."
    info "$STRUTTURA"
    return 0
  fi

  local prev=$((CHAPTER - 1))
  local prev_context=""
  file_exists "${PROJECT_DIR}/chapter_${prev}.md" && \
    prev_context="- Skim previous chapter for narrative continuity: ${PROJECT_DIR}/chapter_${prev}.md"

  local log_file; log_file=$(log_run "architect")
  log "Running Architect... (log: ${log_file##*/})"

  local PROMPT
  PROMPT=$(cat <<ENDPROMPT
You are THE ARCHITECT — System 2 strategist for this book project.
You do not write prose. You write Specs, Beat Lists, and Narrative Utility Functions (NUFs).

## Read These Files First (in this order)
1. Read ${INSTRUCTION} — your role definition, NUF format, and pipeline rules
2. Read ${PRD} — the full book vision, chapter structure, and success criteria
3. Read ${STYLE_BIBLE} — voice, tone, and the quality bar
${prev_context}

## Your Task
Design Chapter ${CHAPTER} so it passes both quality gates:
- EDITOR: NUF scoring ≥ 8.5/10
- REVIEWER: editorial score ≥ 48/60 across 6 dimensions

## Output: Write EXACTLY This File Using the Write Tool
${STRUTTURA}

CRITICAL: Use the Write tool to save to disk. Do NOT print to stdout.

## Required Structure (derive specifics from INSTRUCTION.md NUF format)

### NUFs (Goal Scoring)
Define at least 3 NUFs from the INSTRUCTION.md NUF template.
Each NUF states what the reader must be able to do, feel, or know after reading.
Format per INSTRUCTION.md.

### BEAT LIST
5–8 beats. Each beat:
- Title and core question
- Audience tag (from INSTRUCTION.md beat tagging convention)
- Word count target (800–1200 words per beat)
- Key facts the Researcher must find (derive from PRD chapter goals)

### REVIEWER READINESS NOTES
- Tension points (≥2): where the narrative must create genuine stakes
- Key chains to make explicit (e.g., cause → consequence → reader action)
- Risk proportionality guards: if any risk or cost is mentioned, state the balancing context

### RESEARCHER BRIEF
Exact search queries for the Researcher.
- Web search terms
- Document types to prioritize
- Specific facts, dates, names, or numbers to hunt for

### TARGET
Word count: per PRD.md chapter length preference
Opening hook strategy: one sentence
Closing beat promise: one sentence

## After Writing
Use the Write tool to save the file. Then print ONLY: "ARCHITECT DONE ✓"
ENDPROMPT
)

  local output exit_code=0
  output=$(run_claude "$PROMPT" "$log_file") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    err "Architect: claude exited with code ${exit_code}. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
  $DRY_RUN && { ok "[DRY-RUN] Would write: $STRUTTURA"; return 0; }

  if echo "$output" | grep -q "ARCHITECT DONE" || file_exists "$STRUTTURA"; then
    ok "Structure written: $STRUTTURA"
  else
    err "Architect: claude ran but did not write structure. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
}

# ─── RESEARCHER ────────────────────────────────────────────────────────────
run_researcher() {
  local MODEL="${LONG_OUTPUT_MODEL:-$MODEL}"
  divider "🕵️  RESEARCHER — Chapter ${CHAPTER}"

  if ! should_run "$DOSSIER"; then
    ok "Dossier exists. Skipping (--force to override)."
    info "$DOSSIER"
    return 0
  fi

  if ! $DRY_RUN && ! file_exists "$STRUTTURA"; then
    err "Structure not found. Run: ./ralph.sh ${CHAPTER} architect"
    exit 1
  fi

  local log_file; log_file=$(log_run "researcher")
  log "Running Researcher... (log: ${log_file##*/})"

  local oracle_line=""
  file_exists "$ORACLE" && oracle_line="4. Read ${ORACLE} — check existing answers before searching"

  local PROMPT
  PROMPT=$(cat <<ENDPROMPT
You are THE RESEARCHER — Forensic investigator for this book project.
Prime directive: No invention. No narrative. Only sourced, triangulated facts.
If you cannot find a fact, mark it [UNVERIFIED: description] — never guess.

## Read These Files First
1. Read ${STRUTTURA} — focus on the RESEARCHER BRIEF section for exact queries
2. Read ${INSTRUCTION} — your role definition and verification rules
3. Read ${PRD} — understand the book's topic, angle, and audience
${oracle_line}

## Fractal Search Protocol (execute all 4 loops)

### Loop 1 — Macro (Baseline)
Web search for the foundational context of each beat topic.
Get dates, names, key events right. Wikipedia for the frame.
Extract: exact quotes, dates, named people, institutions.

### Loop 2 — Pivot (Specific)
Web search for specific events, people, places, and institutions from the RESEARCHER BRIEF.
Look for primary sources: interviews, official documents, archived journalism.
Minimum 3 distinct searches. Aim for 5–6 for a thorough dossier.

### Loop 3 — Sensory (Shadow Data)
Hunt specifically for micro-details that make prose feel real:
- Prices, costs, wages (exact figures with year)
- Durations, distances, quantities
- Physical descriptions: what things looked like, smelled like, sounded like
- Direct quotes from real people
- Weather, time of day, specific locations

### Loop 4 — Triangulation
Cross-reference every key claim across ≥2 independent sources.
Flag conflicts as [CONFLICT: source A says X, source B says Y].
Add any unanswerable questions to ${ORACLE}.

## Output: Write EXACTLY This File Using the Write Tool
${DOSSIER}

CRITICAL: Use the Write tool to save to disk. Do NOT print to stdout.

## Required Format (three sections ONLY — no narrative prose)

### [PUBLIC]
General facts: historical context, public records, published sources.
Format: **Source:** [URL or publication] | **Fact:** [verbatim or precise paraphrase]

### [SHADOW]
Sensory micro-details: prices, smells, sounds, weather, direct quotes, physical descriptions.
Format: **Source:** [URL or publication] | **Detail:** [exact sensory or numerical detail]

### [CONFLICT]
Contradictions between sources. Use tables when comparing.
Format: | Claim | Source A | Source B | Resolution |

## After Writing
Use the Write tool to save the file. Then print ONLY: "RESEARCHER DONE ✓ ([N] facts collected)"
ENDPROMPT
)

  local output exit_code=0
  output=$(run_claude "$PROMPT" "$log_file") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    err "Researcher: claude exited with code ${exit_code}. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
  $DRY_RUN && { ok "[DRY-RUN] Would write: $DOSSIER"; return 0; }

  if echo "$output" | grep -q "RESEARCHER DONE" || file_exists "$DOSSIER"; then
    ok "Dossier written: $DOSSIER"
    echo "$output" | grep "RESEARCHER DONE" || true
  else
    err "Researcher: claude ran but did not write dossier. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
}

# ─── WRITER STAGE 1 ────────────────────────────────────────────────────────
run_writer1() {
  local MODEL="${LONG_OUTPUT_MODEL:-$MODEL}"
  divider "✍️  WRITER Stage 1 — Chapter ${CHAPTER} (Prose Engine)"

  if ! should_run "$DRAFT_PROSE"; then
    ok "Draft prose exists. Skipping (--force to override)."
    info "$DRAFT_PROSE"
    return 0
  fi

  if ! $DRY_RUN && ! file_exists "$DOSSIER"; then
    err "Dossier not found. Run: ./ralph.sh ${CHAPTER} researcher"
    exit 1
  fi

  local feedback_directive=""
  if file_exists "$FEEDBACK"; then
    warn "feedback_loop.md found — Writer will address Editor feedback."
    feedback_directive="CRITICAL FIRST STEP: Read ${FEEDBACK} before writing anything. Address every point listed."
  fi

  local log_file; log_file=$(log_run "writer1")
  log "Running Writer Stage 1... (log: ${log_file##*/})"

  local PROMPT
  PROMPT=$(cat <<ENDPROMPT
You are THE WRITER — Stage 1 Prose Engine for this book project.

## Read These Files (in order — stateless, read everything fresh)
${feedback_directive:+0. ${feedback_directive}}
1. Read ${STYLE_BIBLE} — your persona (§ Persona section), voice rules, forbidden patterns, and sensory mandate
2. Read ${STRUTTURA} — NUFs, BEAT LIST, and REVIEWER READINESS NOTES (your full specification)
3. Read ${DOSSIER} — ALL facts come exclusively from here. Invent nothing.
4. Read ${INSTRUCTION} — anti-patterns and forbidden vocabulary for this project

## Activate Your Persona
Before writing the first word, read the § Persona section of STYLE_BIBLE.md.
Read the activation phrase. Inhabit it. Every sentence must come from that voice.

## Stage 1 Task: Write the Raw Narrative
Follow the BEAT LIST from structure exactly. Cover every beat in sequence.
Execute the REVIEWER READINESS NOTES: hit every tension point, every key chain.
Output is raw narrative prose — no fenced formatting yet. Stage 2 handles structure.

## Mandatory Rules

### Sentence Rhythm (Non-Negotiable)
Vary sentence length within every paragraph.
Short sentences (≤8 words) must alternate with long ones (20–30 words).
If all sentences in a paragraph are within 3 words of each other: rewrite it.

### Sensory Grounding
Every scene must contain ≥1 physical detail from the [SHADOW] section of the dossier.
Prices, smells, sounds, temperatures, direct quotes — these are what make prose feel real.
No abstract observation without a sensory anchor within 2 paragraphs.

### Forbidden Patterns (Editor will reject on sight)
- "As we know..." / "It's important to note..." / "Needless to say..."
- Bullet-point prose in narrative sections
- Any claim not present in the dossier
- Generic observations without specific sourced detail
- Persona-specific forbidden moves listed in STYLE_BIBLE.md § Persona

### Paragraph Function Typing
Every paragraph serves ONE function. Use this mix per scene:
- Tension (1/scene, at open): create stakes
- Explain (2–3/scene): teach how something works
- Demonstrate (1–2/scene): evidence — quote, number, case detail
- Concede (≥1/scene, MANDATORY): acknowledge a trade-off or limitation
- Synthesize (1/scene, at close): connect the dots

### Counter-Objections (Mandatory)
≥2 counter-objections per chapter. State each objection in its strongest form.
Respond with evidence from the dossier. Acknowledge residual uncertainty.

### If You Hit the Token Limit
Stop at a clean beat boundary. Write [CONTINUE: next beat is "Beat X: description"]
Do NOT summarize remaining beats.

## Output: Write EXACTLY This File Using the Write Tool
${DRAFT_PROSE}

CRITICAL: Use the Write tool to save to disk. Do NOT print to stdout.
After writing, print ONLY: "WRITER STAGE 1 DONE ✓ (~[word count] words, beats covered: [X/Y])"
ENDPROMPT
)

  local output exit_code=0
  output=$(run_claude "$PROMPT" "$log_file") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    err "Writer S1: claude exited with code ${exit_code}. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
  $DRY_RUN && { ok "[DRY-RUN] Would write: $DRAFT_PROSE"; return 0; }

  if echo "$output" | grep -q "WRITER STAGE 1 DONE" || file_exists "$DRAFT_PROSE"; then
    ok "Draft prose written: $DRAFT_PROSE"
    echo "$output" | grep "WRITER STAGE 1 DONE" || true
  else
    err "Writer S1: claude ran but did not write draft prose. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
}

# ─── WRITER STAGE 2 ────────────────────────────────────────────────────────
run_writer2() {
  local MODEL="${LONG_OUTPUT_MODEL:-$MODEL}"
  divider "✍️  WRITER Stage 2 — Chapter ${CHAPTER} (Refinement Engine)"

  if ! should_run "$CHAPTER_FILE"; then
    ok "Chapter file exists. Skipping (--force to override)."
    info "$CHAPTER_FILE"
    return 0
  fi

  if ! $DRY_RUN && ! file_exists "$DRAFT_PROSE"; then
    err "Draft prose not found. Run: ./ralph.sh ${CHAPTER} writer1"
    exit 1
  fi

  local log_file; log_file=$(log_run "writer2")
  log "Running Writer Stage 2... (log: ${log_file##*/})"

  local PROMPT
  PROMPT=$(cat <<ENDPROMPT
You are THE WRITER — Stage 2 Refinement Engine for this book project.
Task: Transform raw prose into the final formatted chapter.

## Read These Files (in order — stateless)
1. Read ${STYLE_BIBLE} — all formatting rules, voice rules, Anti-AI checklist
2. Read ${DRAFT_PROSE} — the narrative to refine (do not change the substance)
3. Read ${STRUTTURA} — verify NUFs are satisfied and all beats are covered

## Your Task
Apply the STYLE_BIBLE rules to the raw prose. Do not change the substance — only refine.

Key checks:
- Does the prose still sound like the persona (§ Persona) after refinement? If it drifted to generic AI voice, rewrite.
- Are all sentences from the Anti-AI checklist clean?
- Does every scene have a physical sensory detail?
- Do all paragraph functions match the mix (Tension / Explain / Demonstrate / Concede / Synthesize)?
- Are all forbidden patterns removed?

## Footer Comment (add at end of file)
\`\`\`
<!-- WORD COUNT: ~X -->
<!-- PERSONA CHECK: [does the chapter sound like the persona?] Pass/Fail — reason -->
<!-- NUF CHECK: [list each NUF with ✅ or ⚠️] -->
<!-- ANTI-AI CHECK: [any flags from the checklist?] -->
\`\`\`

## Output: Write EXACTLY This File Using the Write Tool
${CHAPTER_FILE}

CRITICAL: Use the Write tool to save to disk. Do NOT print to stdout.
After writing, print ONLY: "WRITER STAGE 2 DONE ✓ (~[word count] words)"
ENDPROMPT
)

  local output exit_code=0
  output=$(run_claude "$PROMPT" "$log_file") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    err "Writer S2: claude exited with code ${exit_code}. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
  $DRY_RUN && { ok "[DRY-RUN] Would write: $CHAPTER_FILE"; return 0; }

  if echo "$output" | grep -q "WRITER STAGE 2 DONE" || file_exists "$CHAPTER_FILE"; then
    ok "Chapter written: $CHAPTER_FILE"
    echo "$output" | grep "WRITER STAGE 2 DONE" || true
  else
    err "Writer S2: claude ran but did not write chapter file. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
}

# ─── EDITOR ────────────────────────────────────────────────────────────────
run_editor() {
  local MODEL="${LONG_OUTPUT_MODEL:-$MODEL}"
  divider "⚖️  EDITOR — Chapter ${CHAPTER} (NUF Audit + Stop-Hook)"

  if ! $DRY_RUN && ! file_exists "$CHAPTER_FILE"; then
    err "Chapter file not found. Run: ./ralph.sh ${CHAPTER} writer"
    exit 1
  fi

  if ! $DRY_RUN && ! file_exists "$STRUTTURA"; then
    err "Structure not found. Cannot score without NUF definitions."
    exit 1
  fi

  if $DRY_RUN; then
    ok "[DRY-RUN] Would score: $CHAPTER_FILE against NUFs in structure"
    ok "[DRY-RUN] Would write: $FEEDBACK (on FAIL) or delete it (on PASS)"
    return 0
  fi

  local retry=0

  while [ $retry -lt $MAX_RETRIES ]; do
    [[ $retry -gt 0 ]] && divider "⚖️  EDITOR — Retry $retry of $((MAX_RETRIES - 1))"

    local log_file; log_file=$(log_run "editor_r${retry}")
    log "Running Editor... (log: ${log_file##*/})"

    local PROMPT
    PROMPT=$(cat <<ENDPROMPT
You are THE EDITOR — Quality Gate for this book project.
You do not write. You score, block, and generate repair instructions.

## Read These Files (stateless — read everything fresh)
1. Read ${STRUTTURA} — NUF definitions (the contract the Writer must satisfy)
2. Read ${STYLE_BIBLE} — the quality standard and Anti-AI checklist
3. Read ${CHAPTER_FILE} — the chapter to audit

## NUF Scoring
Score each NUF from structure: 0 (not achieved), 0.5 (partially achieved), 1 (fully achieved).
Sum the scores. Pass threshold = 8.5/10. Adjust denominator to number of NUFs × 2.

## STYLE_BIBLE Audit (run every item from the checklist)
Report style failures as warnings. The NUF score is the only pass/fail criterion.
Style issues go into feedback_loop.md for the Writer to fix on retry.

Key checks (derive specifics from STYLE_BIBLE):
□ Sentence rhythm: no paragraph with all sentences within 3 words of each other
□ Sensory grounding: ≥1 physical detail from [SHADOW] dossier per scene
□ Paragraph function mix: ≥1 Concede paragraph per scene (mandatory)
□ Forbidden patterns: none of the banned phrases from STYLE_BIBLE
□ Persona consistency: prose sounds like the persona (§ Persona), not generic AI
□ Counter-objections: ≥2 per chapter, evidence-based, uncertainty acknowledged
□ No invented facts: every claim traceable to dossier

## Verdict

### If PASS (NUF score ≥ 8.5):
Print: "EDITOR PASS ✓ Score: X.X/10"
Print NUF breakdown.
Delete feedback_loop.md if it exists: use Bash to run: rm -f ${FEEDBACK}

### If FAIL (NUF score < 8.5):
Print: "EDITOR FAIL ✗ Score: X.X/10"
Print NUF breakdown with failure reasons.
Use Write tool to write ${FEEDBACK} with:

#### Missing NUFs
[For each NUF < 1.0: what was expected, what was found, exact quote showing the gap]

#### Aesthetic Violations
[Exact quotes from the chapter that violate STYLE_BIBLE rules]

#### Persona Drift
[If the chapter sounds like generic AI rather than the persona: quote the passages and explain the drift]

#### Repair Instructions
[Numbered, specific, actionable changes for the Writer. Categorize: Content / Voice / Structure]

Then print: "FAIL: <promise>BLOCKED: [top reason in one sentence]</promise>"
ENDPROMPT
)

    local output
    output=$(run_claude "$PROMPT" "$log_file" 2>&1 || true)
    echo "$output"

    if echo "$output" | grep -q "EDITOR PASS"; then
      ok "Chapter ${CHAPTER} PASSED ✓"
      [[ -f "$FEEDBACK" ]] && rm -f "$FEEDBACK" && info "feedback_loop.md removed."
      return 0

    elif echo "$output" | grep -q "EDITOR FAIL"; then
      retry=$((retry + 1))

      if [ $retry -ge $MAX_RETRIES ]; then
        err "Circuit Breaker: Chapter ${CHAPTER} failed ${MAX_RETRIES} consecutive Editor reviews."
        {
          echo ""
          echo "## Circuit Breaker — Chapter ${CHAPTER} — $(timestamp)"
          echo "Failed ${MAX_RETRIES} consecutive Editor reviews."
          echo ""
          echo "### Last Editor Output"
          echo "$output"
          echo ""
          echo "### Action Required"
          echo "Is this a structural problem (NUF definitions in structure unachievable)?"
          echo "Or a style problem (STYLE_BIBLE rule contradicting the persona)?"
          echo "Review structure NUFs and STYLE_BIBLE § Persona before continuing."
        } >> "$ACTIVITY"
        warn "Circuit Breaker logged to: $ACTIVITY"
        warn "Manual intervention required."
        exit 2
      fi

      warn "Editor returned FAIL. Retrying Writer (attempt $retry of $((MAX_RETRIES - 1)))..."
      FORCE=true run_writer1
      FORCE=true run_writer2
      FORCE=false

    else
      err "Editor produced unexpected output. Manual review required."
      info "Log: $log_file"
      exit 1
    fi
  done
}

# ─── REVIEWER ──────────────────────────────────────────────────────────────
run_reviewer() {
  local MODEL="${LONG_OUTPUT_MODEL:-$MODEL}"
  divider "📋  REVIEWER — Chapter ${CHAPTER} (Editorial Audit + Corrections)"

  if ! should_run "$REVIEW"; then
    ok "Review exists. Skipping (--force to override)."
    info "$REVIEW"
    return 0
  fi

  if ! $DRY_RUN && ! file_exists "$CHAPTER_FILE"; then
    err "Chapter file not found. Run: ./ralph.sh ${CHAPTER} writer"
    exit 1
  fi

  local log_file; log_file=$(log_run "reviewer")
  log "Running Reviewer... (log: ${log_file##*/})"

  local structure_line=""
  file_exists "$STRUTTURA" && structure_line="- Read ${STRUTTURA} — NUFs and BEAT LIST (original spec)"

  local PROMPT
  PROMPT=$(cat <<ENDPROMPT
You are THE REVIEWER — Senior editor for this book project.
You read like the skeptical target reader described in PRD.md.
You test whether the text shows or merely tells.

## Mandatory First Steps (stateless — read everything fresh)
1. Read ${PRD} — target reader, tone, success criteria, enemy
2. Read ${STYLE_BIBLE} — voice rules, persona, forbidden patterns
${structure_line}
3. Read ${CHAPTER_FILE} — the chapter to review

## Score Across 6 Dimensions (/10 each = 60 total)
1. Narrative & Structure — does the chapter build, turn, and land?
2. Language, Style & Voice — does it sound like the persona from STYLE_BIBLE § Persona?
3. Factual Accuracy — are all claims traceable? Any red flags?
4. Audience Alignment — does the PRD target reader get what they need?
5. Sensory & Emotional Engagement — does the reader feel it, or just read it?
6. Originality & Angle — does this chapter earn its place? Does it surprise?

## Decision Thresholds
- Score ≥ 48/60 → REVIEWER_PASS_MINOR: apply inline corrections to ${CHAPTER_FILE}
- Score 36–47/60 → REVIEWER_CORRECTIONS: rewrite identified paragraphs in ${CHAPTER_FILE}
- Score < 36/60 → REVIEWER_REWRITE: write ${REWRITE_PLAN}, do not touch ${CHAPTER_FILE}

## Mandatory In Every Review (regardless of score)
- ≥5 paragraph rewrites with: Original / Rewritten / Why format
- Persona audit: does the chapter sound like the persona, or has it drifted?
- Counter-objection check: ≥2 present? Strongest form? Evidence-based response?
- Litmus test: "Would the reader finish thinking 'I lived this' or 'I was told this'?"

## Output Files

### Always write: ${REVIEW}
Structure:
  1. Executive Summary (max 10 lines — verdict immediately)
  2. Score: X/60 → [decision code]
  3. Detailed Findings by section (quote exact text, not paraphrases)
  4. Persona Audit (does the chapter sound like the persona?)
  5. Counter-Objection Check
  6. Priority Improvements: Critical / Important / Optional
  7. Rewritten Paragraphs (≥5, Original / Rewritten / Why)
  8. Verdict: [decision code + one-line reason]

### If REVIEWER_PASS_MINOR:
Apply corrections directly to ${CHAPTER_FILE} using the Edit tool.
Print: "REVIEWER PASS ✓ Score: X/60 — Minor corrections applied"

### If REVIEWER_CORRECTIONS:
Rewrite identified paragraphs in ${CHAPTER_FILE} using the Edit tool.
Print: "REVIEWER CORRECTIONS ✓ Score: X/60 — [N] paragraphs rewritten"

### If REVIEWER_REWRITE:
Write ${REWRITE_PLAN} with:
  ## Root Cause Analysis
  ## New Beat List Recommendation
  ## Researcher Gaps (specific missing facts)
  ## Writer Anti-Patterns (exact failure modes from this draft)
Do NOT modify ${CHAPTER_FILE}.
Print: "REVIEWER REWRITE NEEDED ✗ Score: X/60 — rewrite plan written"
ENDPROMPT
)

  local output exit_code=0
  output=$(run_claude "$PROMPT" "$log_file") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    err "Reviewer: claude exited with code ${exit_code}. Check log: ${log_file##*/}"
    [[ -f "$log_file" && -s "$log_file" ]] && { warn "Log tail:"; tail -5 "$log_file" >&2; }
    exit 1
  fi
  $DRY_RUN && { ok "[DRY-RUN] Would write: $REVIEW"; return 0; }

  if file_exists "$REVIEW"; then
    local verdict_line; verdict_line=$(grep -m1 "^REVIEWER " <<<"$output" || true)
    [[ -n "$verdict_line" ]] && ok "$verdict_line" || ok "Review written: $REVIEW"
  else
    err "Reviewer failed to produce review file. Check log: $log_file"
    exit 1
  fi
}

# ─── REVIEW ALL ─────────────────────────────────────────────────────────────
run_review_all() {
  divider "📋  REVIEWER — All Chapters (Book-Wide Editorial Audit)"

  local chapters_found=()
  local rewrite_count=0 pass_count=0

  for ch in $(seq 1 50); do
    file_exists "${PROJECT_DIR}/chapter_${ch}.md" && chapters_found+=("$ch")
  done

  if [[ ${#chapters_found[@]} -eq 0 ]]; then
    warn "No chapter files found in ${PROJECT_DIR}."
    exit 0
  fi

  log "Found ${#chapters_found[@]} chapters to review: ${chapters_found[*]}"
  echo ""

  for ch in "${chapters_found[@]}"; do
    CHAPTER="$ch"
    STRUTTURA="${PROJECT_DIR}/chapter_${CHAPTER}_structure.md"
    CHAPTER_FILE="${PROJECT_DIR}/chapter_${CHAPTER}.md"
    REVIEW="${PROJECT_DIR}/review_chapter_${CHAPTER}.md"
    REWRITE_PLAN="${PROJECT_DIR}/rewrite_plan_chapter_${CHAPTER}.md"
    run_reviewer
    file_exists "$REWRITE_PLAN" && rewrite_count=$((rewrite_count + 1)) || pass_count=$((pass_count + 1))
  done

  echo ""
  divider "📋  REVIEWER — Book-Wide Summary"
  ok "Chapters reviewed: ${#chapters_found[@]}"
  ok "  PASS / corrections: ${pass_count}"
  [[ $rewrite_count -gt 0 ]] && err "  Full rewrites needed: ${rewrite_count}"

  if [[ $rewrite_count -ge 3 ]]; then
    warn "⚠️  ${rewrite_count} chapters need full rewrite. Generating ${BOOK_REWRITE_PLAN}..."
    local log_file; log_file=$(log_run "book_rewrite_plan")

    local rewrite_list=""
    for ch in "${chapters_found[@]}"; do
      local rp="${PROJECT_DIR}/rewrite_plan_chapter_${ch}.md"
      file_exists "$rp" && rewrite_list+="- Chapter ${ch}: ${rp}\n"
    done

    local PROMPT
    PROMPT=$(cat <<ENDPROMPT
You are THE REVIEWER synthesizing a book-level rewrite plan.

Read PRD.md for context.
Read each rewrite plan listed below and synthesize cross-chapter patterns.

Rewrite plans to read:
$(printf '%b' "$rewrite_list")

Write ${BOOK_REWRITE_PLAN} with:
  # Book Rewrite Plan
  ## Executive Summary
  ## Cross-Chapter Failure Patterns (problems appearing in ≥2 chapters)
  ## Recommended Structural Changes
  ## Pipeline Diagnosis (Writer failure? Researcher gaps? Architect NUF errors? Persona mismatch?)
  ## Suggested Action Plan (ordered: fix first → can wait → parallel)

After writing, print: "BOOK_REWRITE_PLAN DONE ✓"
ENDPROMPT
)
    run_claude "$PROMPT" "$log_file" || true
    file_exists "$BOOK_REWRITE_PLAN" && ok "Book rewrite plan: $BOOK_REWRITE_PLAN"
  fi

  log "Review complete. Check review_chapter_X.md files for per-chapter findings."
}

# ─── FULL PIPELINE ─────────────────────────────────────────────────────────
run_full_pipeline() {
  log "Starting full pipeline — Chapter ${CHAPTER}"
  log "Model: ${MODEL} (long output: ${LONG_OUTPUT_MODEL})"
  log "Force: ${FORCE}"
  log "Project: ${PROJECT_DIR}"
  echo ""

  run_architect
  run_researcher
  run_writer1
  run_writer2
  run_editor
  run_reviewer

  echo ""
  ok "Pipeline complete — Chapter ${CHAPTER}"
  echo ""
  show_status
}

# ─── MAIN ──────────────────────────────────────────────────────────────────
cd "$PROJECT_DIR"

FORCE_STR=""; $FORCE && FORCE_STR=" | FORCE"
DRYRUN_STR=""; $DRY_RUN && DRYRUN_STR=" | DRY-RUN"

echo ""
echo -e "${BOLD}Ralph Loop V5.1 — 5-Agent Stateless Writing Pipeline${NC}"
echo -e "  Chapter: ${BOLD}${CHAPTER}${NC} | Phase: ${BOLD}${PHASE}${NC} | Model: ${BOLD}${MODEL}${NC}${FORCE_STR}${DRYRUN_STR}"
echo ""

case "$PHASE" in
  all)         run_full_pipeline ;;
  architect)   run_architect ;;
  researcher)  run_researcher ;;
  writer)      run_writer1; run_writer2 ;;
  writer1)     run_writer1 ;;
  writer2)     run_writer2 ;;
  editor)      run_editor ;;
  reviewer)    run_reviewer ;;
  review_all)  run_review_all ;;
  status)      show_status ;;
  *)
    err "Unknown phase: ${PHASE}"
    echo "Valid phases: all | architect | researcher | writer | writer1 | writer2 | editor | reviewer | status"
    exit 1
    ;;
esac
