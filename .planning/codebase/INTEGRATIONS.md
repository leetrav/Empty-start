---
last_mapped_commit: 6f440382c859c661470b893f825089a887807d82
last_mapped_at: 2026-10-08
---
# External Integrations

**Analysis Date:** 2026-10-08

## APIs & External Services

**Editor and development automation:**
- Godot MCP Native - Exposes project, scene, script, editor, and runtime-debugging tools over MCP for AI-assisted development; enabled through `project.godot` and defined by `addons/godot_mcp/plugin.cfg`.
  - SDK/Client: Native GDScript implementation in `addons/godot_mcp/`; no separate game SDK or Node.js runtime dependency is required.
  - Auth: No game authentication. Plugin supports optional MCP HTTP auth in `addons/godot_mcp/mcp_server_native.gd`; no project-specific token configuration was detected.
  - Transport: Plugin supports HTTP and stdio in `addons/godot_mcp/native_mcp/mcp_server_core.gd`; documented default HTTP port is 9080 in `addons/godot_mcp/mcp_server_native.gd`.
- Godot editor/runtime debugger bridge - MCP development tooling communicates with Godot's editor and runtime probe through `addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd` and `addons/godot_mcp/runtime/mcp_runtime_probe.gd`; `MCPRuntimeProbe` is listed as an autoload in `project.godot`.

**Game-facing third-party services:**
- Not detected. Game code under `core/`, `systems/`, and `ui/` contains no identified analytics, account, cloud, platform SDK, or remote game API integration.

## Data Storage

**Databases:**
- None detected; no database engine, connection string, or database client appears in game configuration or runtime code.

**File Storage:**
- Local Godot user data - Settings are stored at `user://settings.cfg` by `core/autoload/settings_manager.gd`; save resources are stored at `user://savegame.res` by `core/autoload/save_manager.gd`.
- Bundled game resources - Static configuration and content use Godot `.tres` resources under `data/` and assets under `assets/`.

**Caching:**
- Godot built-in resource cache - Runtime resources use `ResourceLoader`; save loading explicitly requests `CACHE_MODE_IGNORE` in `core/autoload/save_manager.gd`.

## Authentication & Identity

**Auth Provider:**
- None for the game. Player identity selection is local game data, represented in `core/save/save_data.gd` and managed through the game's identity flow.
- MCP plugin authentication is an optional development-server feature; disabled by default in `addons/godot_mcp/mcp_server_native.gd` and not used as player auth.

## Monitoring & Observability

**Error Tracking:**
- External service: None detected.
- Development diagnostics: Godot MCP debugger bridge and runtime probe in `addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd` and `addons/godot_mcp/runtime/mcp_runtime_probe.gd`.

**Logs:**
- Godot built-in output and `push_error`/`push_warning` calls; for example, persistence diagnostics are emitted by `core/autoload/save_manager.gd`.
- MCP plugin logs are handled by its native server implementation under `addons/godot_mcp/`.

## CI/CD & Deployment

**Hosting:**
- Not detected; no deployment or hosting configuration is present.

**CI Pipeline:**
- Not detected; no repository CI configuration was found.

## Environment Configuration

**Required env vars:**
- None detected for the game runtime.
- MCP HTTP auth token is optional plugin configuration, not a required environment variable; see `addons/godot_mcp/mcp_server_native.gd`.

**Secrets location:**
- No game secrets configuration was detected. `.gitignore` excludes local `.env` files and key files.

## Webhooks & Callbacks

**Incoming:**
- Game webhooks: None detected.
- MCP development interface: The optional Godot MCP plugin exposes local HTTP or stdio MCP transport; HTTP implementation is in `addons/godot_mcp/native_mcp/mcp_http_server.gd` and stdio implementation is in `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`.

**Outgoing:**
- Game callbacks or remote service calls: None detected.
- MCP client communication is development tooling traffic, not a game-service integration.

---

*Integration audit: 2026-10-08*
