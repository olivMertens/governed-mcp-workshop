# 🔐 Governed MCP on Azure — hands-on workshop

> ⚠️ **Work in progress.** Module 00 is built and checked offline only. Modules 01–07 and 99 are planned.
> Nothing has been validated on a real Azure subscription yet. Details: [what is available](docs/IMPLEMENTATION-STATUS.md).

Take one MCP server from **open** to **governed** on Azure, alone, in **your own non-production** subscription.
🇫🇷 [Version française](docs/fr/GETTING-STARTED.md)

![The workshop board: choose your workspace](assets/screenshots/start.en.png)

## 🚀 Use it in 5 steps

| | Step | What you do | What you should see |
|---|---|---|---|
| 1️⃣ | 🧭 **Choose** | Dev container, local terminal or Codespaces. One is enough. | The same tools in all three. |
| 2️⃣ | 📖 **Read** | Open the [board](#-open-the-board) or the module README. | One page per module, with a diagram. |
| 3️⃣ | 🛠️ **Prepare** | Run the module 00 checks. They only read. | `PASS` lines, then a private `.workshop` file. |
| 4️⃣ | ▶️ **Do** | Follow the module steps, one module at a time. | The result written under "What you should see". |
| 5️⃣ | ✅ **Validate, then clean up** | Run the published module's validator. Review cleanup before deleting anything. | Offline `PASS` does not prove Azure deployment. Module 00 preflight creates nothing. |

📸 This is the module 00 guide, not a deployed Azure result:

![Module 00 page with its architecture and security flow](assets/screenshots/module-00.en.png)

## 🗺️ Modules

| # | Module | Need it? | Status | Guide |
|---|---|---|---|---|
| 00 | 🧰 Prerequisites and environment | ✅ Required | 🟡 Built, offline checks only | [Open](modules/00-prerequisites/README.md) |
| 01 | 🔍 Discover MCP (no Azure) | ✅ Required | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#01--discover-mcp-no-azure) |
| 02 | 🔑 Server protected by a key (level 0) | ✅ Required | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#02--an-open-mcp-server-level-0) |
| 03 | 🪪 Microsoft Entra identity (level 1) | ✅ Required | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#03--identity-with-microsoft-entra-level-1) |
| 04 | 🚪 API Management as the only entry (level 2) | ✅ Required | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#04--api-management-as-the-only-entry-point-level-2) |
| 05 | 👤 On-Behalf-Of vs app-only (level 3) | ✅ Required | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#05--who-carries-the-rights-on-behalf-of-vs-app-only-level-3) |
| 06 | 📊 Observe and inventory (level 4) | ✅ Required | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#06--observe-and-inventory-level-4) |
| 07 | 🤖 Other clients (Foundry, Copilot Studio) | ➕ Optional | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#07--optional-other-clients) |
| 99 | 🧹 Clean up | ♻️ As soon as you create resources | ⚪ Planned | [Plan](docs/BUILD-PLAN.md#99--clean-up) |

> 💡 **Why only module 00 is a link to a guide?** It is the only implemented guide, but its Azure validation is still pending.
> The other rows link to their plan: what they will take, build, show and validate.

## 🧭 Open the board

| Where | How |
|---|---|
| 🌐 Copilot app | Ask: "Show the workshop build board." |
| 📄 No tool | Read the Markdown guides. Start with [GETTING-STARTED](docs/GETTING-STARTED.md). |

The board has three parts: **Start** (environment, overview, what exists) · **Main route** (modules in order,
optional ones are marked) · **References** (practice, governance, sources). Switch **EN / FR** at the top.

## 🧪 Try your MCP

Calls run in **your** MCP client (VS Code, Inspector…), never in the board. See the [practice guide](docs/PRACTICE.md).

### Agent 365 integration — Preview, optional

[Microsoft Agent 365 + API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365)
is a **planned facilitator demo**, not an implemented exercise.
API Management v2 supports inventory and server blocking; tool-level blocking requires the **AI Gateway tier (Preview)**.
Tenant-wide administrator consent is required. The core workshop does not request it.
See module 06 in the [governance guide](docs/LEARNING-GUIDE.md#06---observe-metadata-inventory-endpoints).

## 📐 Architecture

Each module has a diagram, with its security flow: [Mermaid guide](assets/architecture/STEPS.md) ·
[en français](assets/architecture/STEPS.fr.md) · [editable Draw.io source](assets/architecture/README.md).

| Icon | Meaning |
|---|---|
| 💡 | Tip |
| ⚠️ | Important to keep in mind |
| 🛑 | Danger: never do this |

## 🛡️ Safety

- 🧪 Non-production subscription and synthetic data only (Alice, Bob, Eve).
- 🔒 No secret, token or tenant ID in the repository.
- 🏷️ **Preview** features are labeled where used.
- 🎲 Names get a random suffix. This avoids collisions, **not** quota limits.
- 💸 Nothing is created in Azure without your approval of a reviewed plan.

## 🏗️ For authors

[`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md) · [`docs/PROGRESS.md`](docs/PROGRESS.md) ·
[`docs/COPILOT-RUNBOOK.md`](docs/COPILOT-RUNBOOK.md) · [`.github/copilot-instructions.md`](.github/copilot-instructions.md) ·
[hosting the guides](docs/HOSTING.md) · [verified sources](docs/sources.md) (last verified 2026-10-14).

## ⚖️ Disclaimer

Community workshop, not an official Microsoft product. Provided "as is" under the MIT License.
The official documentation linked in each module is the reference.
