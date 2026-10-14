# Module 01 - Sources and reuse

The server bootstrap follows the official C# SDK getting-started pattern:
[SDK v2.2.0, commit 6fa3825973949a9c4f0cd8af344e15a8db09dc35](https://github.com/modelcontextprotocol/csharp-sdk/tree/6fa3825973949a9c4f0cd8af344e15a8db09dc35).
The workshop changes that pattern to expose fixed synthetic service health instead of Echo,
disable logging providers rather than log payload-bearing SDK events, and include a typed local validation client.
The health logic, checks, wrappers and participant explanations are workshop additions.
No upstream documentation, full application or Inspector source is copied.

The SDK is transitioning licenses: Apache-2.0 for new/consented contributions, MIT for
un-relicensed contributions, CC-BY-4.0 for documentation. Its complete upstream notice is retained
in [csharp-sdk-LICENSE.txt](csharp-sdk-LICENSE.txt). The repository's MIT license does not replace those terms.
Copyright (c) 2024-2026 Model Context Protocol a Series of LF Projects, LLC.

NuGet dependencies are exactly pinned in `server/Workshop.LocalMcp.csproj`, with transitive versions
and content hashes in `server/packages.lock.json`. Packages retain their own license metadata.
Inspector is used as tooling at version 2.9.0; it is not vendored.
The unversioned C# documentation site currently redirects to v1. This module uses the v2.2.0 source/API instead.

Last verified: 2026-10-14.
