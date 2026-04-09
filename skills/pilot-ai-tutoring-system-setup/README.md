# AI Tutoring System Setup

An adaptive tutoring pipeline where a content curator organizes learning materials, a tutor delivers personalized lessons, and an assessment agent evaluates understanding. The three agents form a feedback loop -- gap analysis from assessments feeds back to the curator so the curriculum adapts to each learner in real time.

**Difficulty:** Intermediate | **Agents:** 3

## Roles

### content-curator (Content Curator)
Organizes learning materials by topic and difficulty, maintains a knowledge graph of prerequisites, and selects appropriate content for each learner's level. Adjusts curriculum based on gap analysis from the assessor.

**Skills:** pilot-archive, pilot-discover, pilot-dataset

### tutor (Tutor Agent)
Delivers personalized lessons, answers questions, provides explanations adapted to the learner's pace, and tracks progress through the curriculum. Routes complex questions and receives tailored materials from the curator.

**Skills:** pilot-chat, pilot-task-router, pilot-receipt

### assessor (Assessment Agent)
Creates quizzes and exercises, grades submissions, identifies knowledge gaps, and sends progress reports back to the curator for curriculum adjustment. Alerts the tutor when a learner is struggling.

**Skills:** pilot-metrics, pilot-alert, pilot-audit-log

## Data Flow

```
content-curator --> tutor     : lesson materials and curriculum (port 1002)
tutor           --> assessor  : learner responses and progress (port 1002)
assessor        --> content-curator : gap analysis and adaptation signals (port 1002)
```

## Setup

Replace `<your-prefix>` with a unique name for your deployment (e.g. `edubot`).

### 1. Install skills on each server

```bash
# On server 1 (content curator)
clawhub install pilot-archive pilot-discover pilot-dataset
pilotctl set-hostname <your-prefix>-content-curator

# On server 2 (tutor agent)
clawhub install pilot-chat pilot-task-router pilot-receipt
pilotctl set-hostname <your-prefix>-tutor

# On server 3 (assessment agent)
clawhub install pilot-metrics pilot-alert pilot-audit-log
pilotctl set-hostname <your-prefix>-assessor
```

### 2. Establish trust

Agents are private by default. Each pair that communicates must exchange handshakes. When both sides send a handshake, trust is auto-approved -- no manual step needed.

```bash
# content-curator <-> tutor (lesson delivery)
# On content-curator:
pilotctl handshake <your-prefix>-tutor "setup: ai-tutoring-system"
# On tutor:
pilotctl handshake <your-prefix>-content-curator "setup: ai-tutoring-system"

# tutor <-> assessor (learner responses)
# On tutor:
pilotctl handshake <your-prefix>-assessor "setup: ai-tutoring-system"
# On assessor:
pilotctl handshake <your-prefix>-tutor "setup: ai-tutoring-system"

# assessor <-> content-curator (gap analysis feedback loop)
# On assessor:
pilotctl handshake <your-prefix>-content-curator "setup: ai-tutoring-system"
# On content-curator:
pilotctl handshake <your-prefix>-assessor "setup: ai-tutoring-system"
```

### 3. Verify

```bash
pilotctl trust
```

## Try It

After setup is complete, run these commands to see data flowing between your agents:

```bash
# On <your-prefix>-content-curator -- publish lesson material:
pilotctl publish <your-prefix>-tutor lesson-material '{"learner_id":"student-042","topic":"linear-algebra","difficulty":"intermediate","lesson":"matrices-intro","prerequisites_met":true,"content_url":"/lessons/matrices-intro.md"}'

# On <your-prefix>-tutor -- publish learner response:
pilotctl publish <your-prefix>-assessor learner-response '{"learner_id":"student-042","topic":"linear-algebra","lesson":"matrices-intro","answers":[{"q":"determinant_2x2","answer":"ad-bc","correct":true},{"q":"inverse_exists","answer":"det!=0","correct":true},{"q":"eigenvalue_def","answer":"unsure","correct":false}],"time_spent_sec":840}'

# On <your-prefix>-assessor -- publish gap analysis:
pilotctl publish <your-prefix>-content-curator gap-analysis '{"learner_id":"student-042","topic":"linear-algebra","mastery":0.67,"gaps":["eigenvalues","eigenvectors"],"recommendation":"introduce_eigenvalue_basics","confidence":0.85}'

# On <your-prefix>-content-curator -- subscribe to gap analysis:
pilotctl subscribe gap-analysis
```
