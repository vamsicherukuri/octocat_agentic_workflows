# Hooks, Skills & Copilot CLI SDK: A Unified Demo

**Audience:** Customer-facing  
**Runtime:** ~30 minutes (full) · ~15 minutes (abbreviated)  
**Setup required:** Local VS Code clone, app running (`make dev`), Copilot CLI installed

---

## The Story

> "A new engineer joins the OctoCAT Supply team. There is a real feature request on the board: the system needs to track **Delivery Vehicles** - each branch owns a fleet of vans and needs to manage them through the API. But this team doesn't just ship code. They ship *governed*, *consistent*, *well-tested* code at speed."

This demo follows one feature from start to finish across three layers of the Copilot platform:

| Act | Layer | Capability | Business Value |
|-----|-------|------------|----------------|
| 1 | Governance | **Agent Hooks** | Every AI action is auditable and reversible |
| 2 | Consistency | **Agent Skills** | Institutional knowledge, automatically applied |
| 3 | Scale | **Copilot CLI SDK** | What took a sprint now takes minutes |

Each act builds directly on the previous. By the end, the audience has seen a single realistic feature delivered end-to-end - with governance, quality, and speed all working together.

---

## Prerequisites

Before the demo:

1. Clone the repo and run `make dev` to confirm the app is up at `http://localhost:3000` and `http://localhost:5137`.
2. Confirm you are in VS Code Agent Mode (not Chat or Edit).
3. Enable the `chat.useAgentSkills` setting in VS Code:
   - Open Settings (`Ctrl/Cmd + ,`) → search `chat.useAgentSkills` → toggle on.
4. Install the Copilot CLI:
   ```bash
   npm install -g @github/copilot-cli
   ```
   Then authenticate: `gh auth login`
5. Have `.github/hooks/hooks.json` open in a tab, ready to show.
6. Have `.github/skills/api-endpoint/SKILL.md` open in a second tab, ready to show.

---

## Act 1: Governance with Agent Hooks (~8 min)

### Talking Point

> "Before we write a single line of code, I want to show you something the platform can do that most teams don't even know exists. Agent Hooks let you attach arbitrary logic to Copilot's lifecycle - before a session, when a prompt fires, and when a session ends. Think of it as a programmable safety net around all AI-generated work."

### Step 1: Show the Hooks Configuration

Open `.github/hooks/hooks.json` and walk through it:

```jsonc
{
  "version": 1,
  "hooks": {
    "sessionStart": [ ... ],      // fires when agent mode opens
    "UserPromptSubmit": [ ... ],  // fires on every prompt
    "Stop": [ ... ]               // fires when the session ends
  }
}
```

Point out three things:
- **Cross-platform**: each hook has both `bash` and `powershell` variants - it works on any developer machine.
- **Composable**: you can chain as many hooks as you want in each event.
- **Lightweight**: this is just a JSON file checked in to `.github/hooks/` - no infrastructure to manage.

### Step 2: Show Audit Logging in Action

1. Open Copilot Chat → switch to **Agent** mode.
2. Send this prompt:
   ```
   What frameworks are used in this project?
   ```
3. When the agent responds, open a terminal and run:
   ```bash
   cat .agent.log
   ```
4. Show the timestamped entries - one for session start, one capturing the prompt text, one for stop.

**Talking point:**
> "Every prompt this engineer submits is now captured with a timestamp. You can pipe this to Splunk, Datadog, your SIEM - wherever your compliance team needs it. Zero developer friction because it's invisible to them."

### Step 3: Enable Checkpoint Commits

Now enable the auto-commit hook to show the second use case.

1. In `.github/hooks/hooks.json`, uncomment the checkpoint block inside `Stop`:

   ```jsonc
   {
     "type": "command",
     "bash": ".github/hooks/checkpoint-commit.sh",
     "cwd": ".",
     "timeoutSec": 10
   }
   ```

2. Explain what `checkpoint-commit.sh` does - it runs `git add -A` and creates a timestamped commit automatically when the agent session ends.

**Talking point:**
> "This is a 'save game' for AI-generated code. The agent produces a large batch of changes. Before the developer has even reviewed them, there is a reversible commit in the history. If anything looks wrong, `git reset` and you're back. No work is ever lost - and you have a clean record of exactly what each AI session produced."

### Transition

> "We have governance in place. Now let's actually build the feature. But here's the challenge: this codebase has established patterns - specific ways of doing models, repositories, routes, migrations, tests. How does a new engineer - or an AI agent - know all of that?"

---

## Act 2: Consistency with Agent Skills (~12 min)

### Talking Point

> "Skills are the answer to the consistency problem. A Skill is a folder of instructions, examples, and reference material that Copilot loads automatically when the task matches. Think of it as encoding your team's institutional knowledge once, and then every developer - and every AI session - has access to it."

### Step 1: Show the Skill Structure

Open `.github/skills/api-endpoint/SKILL.md` and walk through it:

- **YAML frontmatter**: `name`, `description` - this is how Copilot knows when to load the skill automatically.
- **Architecture Overview**: shows the layered pattern (Routes → Repository → Database).
- **Workflow Steps**: step-by-step guide Copilot follows, not a developer.
- **References folder**: point to the supporting files:
  - `references/database-conventions.md`
  - `references/error-handling.md`
  - `references/swagger-patterns.md`
  - `references/testing-patterns.md`

**Talking point:**
> "Notice this is plain markdown. Your senior engineers write this once. After that, every junior developer and every AI agent that touches this codebase produces code that looks like it was written by your best engineer. This is institutional knowledge at scale."

Also contrast with Custom Instructions:

| | Agent Skills | Custom Instructions |
|---|---|---|
| **Portability** | VS Code, Copilot CLI, Coding Agent | VS Code and GitHub.com only |
| **Content** | Instructions + scripts + examples | Instructions only |
| **Loading** | On-demand when relevant | Always applied |
| **Standard** | Open standard (agentskills.io) | VS Code-specific |

> "Skills travel with your code - they work whether your developer is in VS Code, using the CLI, or handing off to the Copilot Coding Agent on GitHub.com."

### Step 2: Generate the DeliveryVehicle Entity

1. Open a new Copilot Chat → **Agent** mode.
2. Enter this prompt:
   ```
   Add a new API endpoint for a new Entity called 'DeliveryVehicle'. Vehicles belong to branches.
   ```
3. Let the agent run. Point out while it works:
   - It detected the `api-endpoint` skill automatically from the description match.
   - It is generating: a TypeScript model, a repository class, Express.js routes, a database migration, seed data, and unit tests.
   - It is following the exact same patterns as every other entity in the codebase.

### Step 3: Review the Generated Artifacts

After the agent completes, walk through the generated files side-by-side with an existing entity (e.g., `delivery.ts`). Point out:

- **Naming conventions** match exactly - `deliveryVehiclesRepo.ts`, not some variation.
- **Foreign key relationship**: `branchId` linking to `branches.table`, matching the existing schema conventions.
- **Swagger annotations**: Complete OpenAPI documentation generated automatically.
- **Error handling**: Uses the same custom error classes as the rest of the codebase.
- **Tests**: Unit tests created and passing before you even reviewed the code.

**Optional:** Open Swagger UI at `http://localhost:3000/api-docs` to show the new endpoints live.

### Step 4: Show the Checkpoint Commit

Open Source Control or run `git log --oneline -3` in the terminal:

```
abc1234 [Checkpoint-commit] 2026-04-17 14:32:11
def5678 Previous commit
...
```

> "The hook from Act 1 ran automatically when the session ended. We have a clean, timestamped record of exactly what this AI session produced. If the code review reveals a problem, one `git reset` takes us back. No detective work needed."

### Transition

> "We just shipped a complete, production-quality feature from a single sentence. Now imagine the rest of the API. Some routes don't have tests. If this team has 15 route files and needs 80% test coverage on all of them, how do they get there without spending a sprint on it?"

---

## Act 3: Scale with the Copilot CLI SDK (~10 min)

### Talking Point

> "This is where the Copilot CLI SDK changes the game. The CLI is not just a chat interface at the command line - it has a `/fleet` command that can launch multiple specialized agents in parallel, each with their own context, each working on a different file simultaneously."

### Step 1: Show the Agents Involved

Before running the CLI, open the two agent files in VS Code to explain the orchestration:

**`.github/agents/api-coverage-looper.agent.md`**
> "This is the orchestrator. It scans all the route files, identifies which ones lack test files, and hands each one off to a specialist agent."

**`.github/agents/api-test-writer.agent.md`**
> "This is the specialist. It receives a single route file, writes tests until 80% coverage is achieved, verifies they pass, and hands back to the looper."

Point out the `handoffs` section in both files - this is how agents coordinate without sharing a bloated context window.

### Step 2: Launch the Fleet from the CLI

Open a terminal and navigate to the project root:

```bash
copilot
```

Inside the Copilot CLI session:

1. Type `yolo` to allow all commands *(narrate: "In a real environment you'd review permissions - we're using `yolo` here to keep the demo moving. Note the risk.")*
2. Type `/agent` and select **API Coverage Looper** from the list.
3. Type:
   ```
   /fleet complete coverage
   ```

Show the output as multiple agent threads start firing in parallel.

**Talking point:**
> "Each agent in the fleet has its own clean context window. They don't share state, they don't pollute each other's reasoning. The looper orchestrates; the writers execute. This is the same pattern used by autonomous systems at scale - just running locally on the developer's machine."

### Step 3: Return to VS Code

While the fleet runs in the terminal:

1. Switch back to VS Code.
2. Open the original agent session (it is still running in the background).
3. Point out that you can work on something else entirely while the fleet runs.

After agents complete, show the terminal output - a final report of which routes now have tests and what coverage was achieved.

**Optional:** Run `make test` to show all tests passing.

### Step 4: Show the Audit Trail

Open `.agent.log`:

```bash
cat .agent.log
```

Every agent session - the looper, each writer invocation - is captured with timestamps. The governance layer from Act 1 covered all of this automatically.

**Talking point:**
> "We turned on audit logging before we started. Every AI action across every parallel agent was recorded. Your compliance team has a complete trail. No additional tooling required."

---

## Closing: The Full Picture

Bring it back to the story:

> "One engineer. One feature request. In 30 minutes, we shipped a complete, tested, documented API endpoint - then covered the entire API with tests in parallel. And every step of that was governed, auditable, and reversible."

| What we did | Why it matters |
|-------------|----------------|
| Hooks captured every AI action | Compliance without friction |
| Skills applied institutional knowledge automatically | Consistency without senior engineers reviewing every PR |
| CLI fleet ran parallel agents | Velocity without compromising quality |

### The Compounding Effect

These three capabilities are most powerful together:
- **Without Hooks**: the audit trail disappears when you close VS Code.
- **Without Skills**: generated code drifts from your standards over time.
- **Without the CLI**: you can only work on one thing at a time.

Together they form a platform layer that makes AI-assisted development **safe enough to trust at enterprise scale**.

---

## Frequently Asked Questions

**Q: Do Skills require any special backend infrastructure?**  
No. They are markdown files in `.github/skills/`. They work in any repo, on any machine, and in Codespaces.

**Q: Can hooks call external systems?**  
Yes. The hook command can call any script, which can in turn call a REST API, write to a database, post to Slack - anything the shell can do.

**Q: Is the CLI fleet feature GA?**  
The Copilot CLI and `/fleet` capability is available to users with a Copilot subscription. Check the [GitHub Changelog](https://github.blog/changelog/) for the latest availability status.

**Q: What is the agentskills.io standard?**  
It is an open standard for defining agent skills that works across multiple AI tools - not just GitHub Copilot. A skill defined in `.github/skills/` works in VS Code, the Copilot CLI, and the Copilot Coding Agent without modification.

---

## Related Walkthroughs

- [Agent Hooks](./agent-hooks.md) - Full hooks reference
- [Agent Skills](./agent-skills.md) - Full skills reference
- [Ralph Loop](./ralph-loop.md) - Full fleet/looper patterns
- [Custom Agents](./custom-agents.md) - BDD Specialist and API Specialist agents
- [Agentic Workflows](./agentic-workflows.md) - Hooks in CI/CD pipelines
