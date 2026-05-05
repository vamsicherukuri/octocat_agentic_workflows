---
name: ADO Work Item Orchestrator
description: |
  Triggered when Azure DevOps "Delegate to GitHub Copilot" creates a draft
  pull request containing an Azure DevOps work item reference (AB#<id>).
  Reads the full work item details via the ADO MCP server and runs the
  OctoCAT Tech Lead Orchestrator pipeline. Code changes are produced on a
  clean branch and a new pull request is created. The originating ADO draft
  PR is commented on to point at the new PR.

on:
  pull_request:
    types: [opened, labeled]

if: "${{ github.event.pull_request.draft == true }}"

permissions:
  contents: read
  issues: read
  pull-requests: read

network:
  allowed:
    - defaults
    - node

tools:
  github:
    toolsets: [default]
  edit:
  bash: [":*"]

mcp-servers:
  azure-devops:
    # NOTE: Confirm the correct ADO MCP container image for your environment.
    # Microsoft's ADO MCP server: https://github.com/microsoft/azure-devops-mcp
    # Replace the image below with the one registered in your container registry.
    container: "ghcr.io/microsoft/azure-devops-mcp:latest"
    env:
      AZURE_DEVOPS_ORG_URL: "${{ secrets.AZURE_DEVOPS_ORG_URL }}"
      AZURE_DEVOPS_TOKEN: "${{ secrets.AZURE_DEVOPS_TOKEN }}"
      AZURE_DEVOPS_PROJECT: "${{ secrets.AZURE_DEVOPS_PROJECT }}"
    allowed:
      - get_work_item
      - get_work_item_comments
      - get_work_item_revisions

safe-outputs:
  create-pull-request:
    title-prefix: "[ADO] "
    draft: false
  add-comment:
    max: 3
---

# ADO Work Item → Orchestrator → Pull Request

You are the **OctoCAT Tech Lead Orchestrator**. This workflow was triggered
because Azure DevOps delegated a work item to GitHub Copilot. The delegation
created a draft pull request (PR #`${{ github.event.pull_request.number }}`)
whose body contains the work item description and an `AB#<id>` reference.

## Step 1 — Extract the ADO work item ID and read the PR body

Use bash to extract the ADO work item ID from the pull request body. The body
will contain a reference like `AB#123` or a full Azure DevOps URL containing
the work item ID. Also capture the PR title and full body text as the initial
requirements brief.

```bash
PR_BODY=$(gh pr view ${{ github.event.pull_request.number }} --json body -q '.body')
echo "$PR_BODY"

# Extract AB# reference (format: AB#<number>)
ADO_WORK_ITEM_ID=$(echo "$PR_BODY" | grep -oP 'AB#\K[0-9]+' | head -1)
echo "ADO Work Item ID: $ADO_WORK_ITEM_ID"
```

If no `AB#` reference is found, fall back to using the PR title and body
directly as the requirements brief (the PR body from ADO delegation already
contains the work item description).

## Step 2 — Retrieve the full ADO work item via MCP

Use the **azure-devops MCP server** (`get_work_item` tool) to fetch the
complete work item record for the ID you extracted. Capture:

- Title / Summary
- Description and acceptance criteria
- Work item type (User Story, Bug, Task, Feature, etc.)
- Priority, iteration path, tags
- Any parent or linked work items (Epic, Feature)
- The most recent comments (`get_work_item_comments`)
- Change history if relevant (`get_work_item_revisions`)

If the MCP call fails (permissions, unavailable, missing secrets), use the
PR title and body as the sole requirements brief and proceed — do not stop.
Document the fallback in the final PR description.

## Step 3 — Comment on the originating ADO draft PR

Before starting the orchestration pipeline, post a comment on the original
ADO-delegated draft PR (`${{ github.event.pull_request.number }}`) explaining
that the Tech Lead Orchestrator has taken over and a new PR will be created.

Use the GitHub tools to add a comment:

> **🤖 OctoCAT Tech Lead Orchestrator activated.**
> The full development pipeline is now running. A new pull request will be
> created with the implementation when the pipeline completes.
> ADO Work Item: AB#`<id>`

## Step 4 — Switch to the default branch for a clean orchestration run

Checkout the default branch (`${{ github.event.repository.default_branch }}`)
so the orchestrator starts from a clean, up-to-date state. All code changes
will be committed to a new feature branch created by the orchestrator.

```bash
git fetch origin ${{ github.event.repository.default_branch }}
git checkout ${{ github.event.repository.default_branch }}
git pull origin ${{ github.event.repository.default_branch }}
```

## Step 5 — Run the Tech Lead Orchestrator

Treat the ADO work item contents (title, description, acceptance criteria,
and type) as the **user request** that initiates the full orchestration
pipeline. Apply the complete Tech Lead Orchestrator protocol below
(intake → phased pipeline → quality gate → final build).

When the orchestrator would normally ask the user clarifying questions, make
the most reasonable assumption based on the work item contents and document
every assumption in the final PR description — there is no interactive user
in this workflow.

{{#runtime-import .github/agents/orchestrator.agent.md}}

## Step 6 — Deliver the result as a Pull Request

When the pipeline completes (or after a maximum of 3 quality retry cycles),
use the `create-pull-request` safe output to open a single pull request
containing all code, migration, test, and documentation changes. The PR body
**must** include:

1. **ADO work item link**: `AB#<id>` and the work item title/summary.
2. **Orchestrator Final Build Declaration**: the `✅ BUILD COMPLETE` block
   from the Tech Lead Orchestrator spec, or the current **Pipeline State**
   block plus a description of any remaining blocker if it did not complete.
3. **Files changed**: grouped by phase (Architecture / Development / Quality).
4. **Deployment notes**: migrations to run, env vars to set, Swagger
   regeneration needed, etc.
5. **Assumptions**: every assumption made because no interactive user was
   available.
6. **Reference to originating PR**: "Replaces draft PR #`<number>` created
   by ADO Copilot delegation."

After the new PR is created, close the originating ADO draft PR
(#`${{ github.event.pull_request.number }}`) with a comment pointing at the
new PR number.

## Safety and constraints

- Use **only** the `azure-devops` MCP server for ADO data. Do not write back
  to ADO work items from this workflow.
- Do not include ADO credentials, tokens, or MCP server config in the PR
  body, commit messages, or logs.
- All repository write operations must go through the `create-pull-request`
  safe output — do not push directly to main or protected branches.
- Follow every OctoCAT convention in the embedded orchestrator spec:
  parameterized SQL, `@swagger` JSDoc on routes, repository pattern,
  `NotFoundError` / `ValidationError` / `ConflictError`, camelCase ↔
  snake_case mapping, Vitest for tests, React Query + Tailwind on the
  frontend.
- Branch naming for the new PR: `ado/<work-item-id>/<short-slug>` where
  `<short-slug>` is a 3-5 word kebab-case summary of the work item title.
