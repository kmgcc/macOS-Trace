# Xcode Coding Agents and MCP

Use when Xcode's project/build/test context may help investigate or verify a performance issue. This is an optional integration path; Instruments traces remain the source of profiling evidence.

## Choose the right boundary

- Use the coding agent already available in the host (Codex, Antigravity, or another configured client) for source inspection, edits, and task coordination.
- If that client exposes Xcode MCP tools, use them for the Xcode-specific actions they support, such as project/build/test context or app verification. First inspect the actual tool descriptions and permissions available in that session; MCP capabilities vary by Xcode release and client.
- Use `xctrace` and Instruments for timelines, samples, hitches, allocations, and resource attribution. A build/test MCP result is not a performance trace and does not prove runtime behavior.
- Keep project-owned build scripts, device/process rules, test gates, and user-data safeguards in force even when an MCP tool can perform an action.

## Xcode 27 MCP preview

Xcode 27 release notes describe a preview `xcrun mcp-server` experience that can operate without an open workspace and can grant a code-signed agent access to projects under an approved directory tree. Treat this as preview functionality and check the release notes/help for the installed build.

Discover commands before using them:

```text
xcrun mcp-server --help
xcrun mcp-server status
xcrun mcpbridge --help
```

The documented enable path is `sudo xcrun mcp-server enable`; it changes host-level configuration and requires administrator authorization. Do not enable, disable, approve agents, allow folders, or clear permissions as part of an ordinary profiling run. If a user explicitly wants to configure the server, explain the scope and let the host's permission flow handle authorization. Do not use the preview's unsafe allow-all option for normal interactive development. Some settings may require relaunching Xcode or restarting the host to take effect.

The local command-line help describes `mcpbridge` as the stdio MCP entry point for an agent client. Check its installed help and the client's own configuration instructions rather than copying a guessed config block. Do not assume a `start` subcommand or a particular permission model: command names and behavior can differ between Xcode builds. Use only subcommands shown by the installed tool. Enabling the server also does not automatically connect every agent; configure and inspect the client separately.

## Apple-authored agent skills

Xcode 27 release notes mention exporting Apple's coding-agent skills for Codex when they are not available automatically. Check the current Xcode release notes and `xcrun agent skills --help` before exporting; this is separate from installing macOS-Trace and should not overwrite a user's existing skill collection without reviewing the destination.
