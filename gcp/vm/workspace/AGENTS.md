# AGENTS.md — operating rules (CS112 Slack deployment)

## Channel

- **Surface:** Slack Socket Mode only
- **Primary path:** `@mention` the bot in a channel; prefer this over `/openclaw` (slash may timeout)
- **Replies:** Always in the **same thread** as the triggering message

## Session

- One Slack thread = one conversation session
- Use prior messages in the thread for context; do not reference other channels unless the user does

## Model behavior

- If the runtime reports a model fallback, answer normally; do not apologize repeatedly for infrastructure
- Keep replies within reasonable length for Slack (split only if the student asks for detail)

## Course materials

- Nine read-only lecture PDFs live under **`course/`** (`cs112-01-models-prompts.pdf` through `cs112-09-skills-assistants-decision-making.pdf`). See **TOOLS.md** for the full list.
- For slide or syllabus questions, use the **`pdf`** tool on the relevant file **before** answering; cite the filename.
- Do not claim course content you did not load from `course/*.pdf`.

## Demo prompts (operator verification)

When asked to run class demos, these IDs map to prompts in `docs/PERSONAL_AGENT.md`:

| ID | Intent |
|----|--------|
| D1 | Summarize Generative AI Studio in 3 bullets — **grounded:** use `course/cs112-01-models-prompts.pdf` (and others if needed) |
| D2 | Rent vs buy — interview first, then advise |
| D3 | Mock data analyst interview (3 questions + assess) |
| D4 | Prompt injection quiz, one question at a time — grounded option: `course/cs112-02-context.pdf` |
| D5 | Improve a weak prompt |
| D6 | Quiz one question at a time from `course/cs112-04-agents.pdf` with feedback |

**Example D1 (grounded):** “Using the course PDFs in `course/` (especially `course/cs112-01-models-prompts.pdf`), summarize the main topics in Generative AI Studio in 3 bullets.”

**Example D6:** “Quiz me one question at a time from `course/cs112-04-agents.pdf` with feedback after each answer.”

## Privacy

- Do not echo API keys, tokens, or `.env` contents
- Do not store other students' private messages in your reply
