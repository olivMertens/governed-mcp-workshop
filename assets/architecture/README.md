# Editable workshop architecture

`workshop.drawio` is the single architecture source: nine modules, with one English and one French page each.
`NN.en.svg` / `NN.fr.svg` and matching PNGs are generated, not hand-edited.
`STEPS.md` and `STEPS.fr.md` contain the same components, edges and ownership boundaries as Mermaid.
Start with [the step-by-step guide](STEPS.md), not this authoring reference.
All views are **planned targets**, not evidence of deployed infrastructure.
Dashed frames identify the labeled local, identity or Azure workload boundary. Numbered lanes are linked views
of the same stage, not additional copies of a deployed resource. Request, identity, observation and administration
are distinct flows. Module 05 shows Storage; Graph requires a separate token for its own audience.

Maintainers editing these diagrams follow [the architecture diagram skill](../../.github/skills/architecture-diagram-author/SKILL.md),
which the module builder loads when a module changes a depicted architecture.

## Reproduce the exports

Python 3, the Python `playwright` package and an existing Chromium or Edge installation are required for PNGs.
Install the package with `python -m pip install playwright==1.62.0`. No dependency or browser is installed automatically.
SVG-only generation and `--check` use only the Python standard library.
The local renderer supports the source's plain text, square rectangles, dashed boundaries, embedded SVG icons,
parent offsets and explicitly anchored orthogonal routing. Unsupported styles fail instead of being dropped.
This is a small mxGraph renderer, not a general replacement for the draw.io exporter.
Draw.io Desktop was unavailable when these exports were created; Edge rasterizes the generated SVG offline.

```powershell
python .\scripts\render-architecture.py --browser 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
```

```bash
python3 ./scripts/render-architecture.py --browser "$(command -v chromium)"
```

Choose your actual browser executable. `--svg-only` checks/regenerates the SVGs when no browser is available,
but **does not refresh PNGs**. Regenerate both before publishing. Review PNGs and the board after layout edits.
Use `python .\scripts\render-architecture.py --check` for read-only consistency checks without a browser.
PNGs contain their source SVG's SHA-256 digest; stale pairs fail rather than silently passing.
Checks cover full orthogonal segments, unrelated-box crossings, edge intersections/overlaps, 16-pixel parallel
clearance, perpendicular arrow approaches, text capacity and self-contained icons.

The same command regenerates both Mermaid guides. `--check` also rejects stale Mermaid text.
Mermaid preserves graph relationships, source labels and boundaries, not the exact pixel positions or product icons.
GitHub renders its native Mermaid blocks. The board and static portal match each published block to its
generated SVG, retaining the verified icons and routing without loading a Mermaid library or external service.
Unknown Mermaid blocks fail explicitly; this is not a general-purpose diagram editor.
Each module offers its Mermaid source in a closed-by-default section with a copy button.
The module 99 READMEs also embed the matching generated block in a disclosure for GitHub readers.
When changing its architecture, copy the regenerated module 99 block from each `STEPS` guide to its README;
`node --test scripts/site.test.mjs` rejects drift in either language.
After changing architecture, regenerate, inspect the PNGs and check both languages before committing.

## Portable README callouts

Use GitHub alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
Keep blank quoted lines (`>`) between paragraphs, lists and fenced code.
Both GitHub and the shared board/presenter renderer preserve these blocks.
The app adds a decorative icon, translated type label and distinct color to each alert.
Normal quotes stay blockquotes; arbitrary HTML remains inert text.
Use the [clean-up guide](../../modules/99-cleanup/README.md) as the bilingual example.
These formatting changes do not prove deployment or successful clean-up.

All non-Mermaid fenced blocks use the shared copy control in the app, including JSON and plain text.
Code is copied verbatim, without translation or execution. Shell blocks remind readers to review commands
and replace placeholders in their own terminal. Clipboard failures show an explicit manual-copy message.
The [Azure context guide](../../docs/DEPLOYMENT.md) provides guarded read-only inspection commands and portal links;
results and credentials remain in the participant's terminal, never in the shared UI.

## Icon provenance

Retrieved 2026-10-14. The first lookup was [az-icons.com](https://az-icons.com/), a **community mirror** of the
July 2026 Azure architecture pack, not a Microsoft publisher. The six service SVGs below were resolved from its
live catalog and checked against the official V24 archive's service filenames.
Azure/Entra product names, shapes, colors and aspect ratios are preserved.

| Local asset | Exact download URL | Official identity / archive path |
|---|---|---|
| `../icons/functions.svg` | https://az-icons.com/export/icons/8b069a95919b7f5970c80ece71383a0e.svg | `compute/10029-icon-service-Function-Apps.svg` |
| `../icons/apim.svg` | https://az-icons.com/export/icons/99492b56c1a8226f1544ca8a15aa5325.svg | `integration/10042-icon-service-API-Management-Services.svg` |
| `../icons/storage.svg` | https://az-icons.com/export/icons/675ad8e4daebee40114a4fe36033257c.svg | `storage/10086-icon-service-Storage-Accounts.svg` |
| `../icons/insights.svg` | https://az-icons.com/export/icons/b888cbfe0812148dec98d29c2b828988.svg | `management + governance/00012-icon-service-Application-Insights.svg` |
| `../icons/subscription.svg` | https://az-icons.com/export/icons/0aafefc9b33aac44c821b22d06bc4170.svg | `general/10002-icon-service-Subscriptions.svg` |
| `../icons/api-center.svg` | https://az-icons.com/export/icons/edfa983b9ec57a0b810f46055e20ac7a.svg | `web/03291-icon-service-API-Center.svg` |
| `../icons/entra.svg` | https://tomkiljo.github.io/ms-icons/icons/Microsoft_Entra_architecture_icons/Microsoft%20Entra%20color%20icons%20SVG/Microsoft%20Entra%20ID%20color%20icon.svg | Microsoft Entra ID, color icon, October 2023 pack |
| `../icons/azure.svg` | https://tomkiljo.github.io/ms-icons/icons/Azure_UX_Patterns_icons/azure.svg | Azure logo, UX collection, retrieval date above; not a claimed V24 service icon |
| `../icons/microsoft.svg` | https://tomkiljo.github.io/ms-icons/icons/Azure_UX_Patterns_icons/microsoft-square.svg | Microsoft four-square logo, UX collection, retrieval date above; not a Graph or Microsoft 365 icon |

The priority catalog lacks the exact Entra ID and corporate logo variants used here.
Fallback [MsiconsCollections](https://aka.ms/MsiconsCollections) resolved to
[Microsoft Icon Collections](https://tomkiljo.github.io/ms-icons/); its rendered index links these exact paths.

Retrieved 2026-10-16, for the module 07 service list in the board (not used in the diagrams):

| Local asset | Exact download URL | Official identity / archive path |
|---|---|---|
| `../icons/foundry-agent-service.svg` | https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V24.zip (az-icons.com lookup: https://az-icons.com/export/icons/2104c885475f575147fe7f0fbdcf6552.svg) | `ai + machine learning/038470523-icon-service-Foundry-Agent-Service.svg`, extracted unchanged from the official archive |
| `../icons/copilot-studio.svg` | https://download.microsoft.com/download/498606aa-6d27-4f13-aa5c-1401078c153b/Power-Platform-icons-scalable.zip | `CopilotStudio_scalable.svg`, official Power Platform pack, December 2025 update |

az-icons.com located the Foundry icon; the committed file is the official archive's copy. Copilot Studio is not an
Azure service: az-icons.com has no entry, and MsiconsCollections only offers a generic Copilot logo, which must not be
relabeled. The [Power Platform icons](https://learn.microsoft.com/power-platform/guidance/icons) page supplies it.

## Usage and trademarks

Microsoft owns these product icons and logos. Azure, Entra and Power Platform icons are permitted in architecture,
training and documentation under their linked terms; they are **not relicensed under this repository's MIT license**.
The corporate Azure/Microsoft logos are identifying brand assets from the UX collection and remain subject to
Microsoft's trademark guidelines, not a blanket license granted by this repository. Review permission for your
distribution context before publication or any marketing use. The logos identify technologies, not this workshop.
This independent workshop is not Microsoft-endorsed. Do not use its board as Microsoft corporate branding.

## Sources

- [Official Azure icon terms and update history](https://learn.microsoft.com/azure/architecture/icons/).
- [Official Azure V24 archive](https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V24.zip).
- [Official Entra icon terms and October 2023 pack](https://learn.microsoft.com/entra/architecture/architecture-icons).
- [Official Power Platform icon terms and pack](https://learn.microsoft.com/power-platform/guidance/icons).
- [Microsoft trademark and brand guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks).
- [Workshop build plan](../../docs/BUILD-PLAN.md) and [source register](../../docs/sources.md).
- [GitHub diagram rendering](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams).

Last verified: 2026-10-14.
