# OpenTDF for ttt

An admin console for [OpenTDF](https://opentdf.io), inside the [ttt](https://github.com/eugenioenko/ttt) terminal editor.

OpenTDF is an open source system for attribute-based access control and data-centric encryption. Data is protected with attributes, such as a classification, a department or a region, and the platform decides who can decrypt it from the entitlements each person or service has. This plugin connects ttt to an OpenTDF platform so you can browse and manage its policy, key access servers and keys, and test access decisions without leaving the editor.

## Requirements

- **ttt newer than v1.9.0.** The plugin uses `ttt.text` and focusing plugin tabs, which are on ttt `main` and ship in the first release after v1.9.0. Until then, build ttt from `main`.
- **An OpenTDF platform** and its identity provider. The [opentdf/platform](https://github.com/opentdf/platform) repository explains how to start one locally with Docker Compose, which serves the platform on `http://localhost:8080` and Keycloak on `http://localhost:8888`.
- **A client that can manage policy**, with a client ID and secret. On the local platform that is `opentdf` / `secret`.

Persistent sidebar highlighting and a vertical connection menu icon use ttt's optional `active_id` and `menu_icon` widget fields. Builds without them use the default highlighting and icon.

## Install

In ttt, open the command palette (**Ctrl+P**), run **Plugins: Install from URL** and enter:

```
https://github.com/eugenioenko/ttt-opentdf
```

The plugin is not in the community registry yet, so searching the **Plugins** panel does not find it. To install it by hand instead, clone it into ttt's plugins folder and restart ttt:

```sh
git clone https://github.com/eugenioenko/ttt-opentdf ~/.config/ttt/plugins/opentdf
```

Update it later with **Plugins: Update**.

### Permissions

ttt asks you to approve these once:

| Permission | Why |
|------------|-----|
| `network.http` | Call the platform's APIs and get a token from its identity provider. |
| `storage` | Remember the connection and settings between sessions. |
| `panel.sidebar` | Show the **OpenTDF** panel in the sidebar. |
| `panel.editor` | Open lists, detail pages and forms in editor tabs. |
| `commands` | Add the `OpenTDF: …` commands to the command palette. |

## Connect

Open the **OpenTDF** sidebar panel and click **Add Connection**, or run **OpenTDF: Add Connection**. Give it a name and fill in:

- **Platform URL**, for example `http://localhost:8080`.
- **Client ID**, for example `opentdf` on the local platform.
- **Client secret** (optional when saving). Check **Save client secret** to remember it between sessions. Otherwise it is only used for this session, and the plugin asks for it when connecting again.

Save as many connections as you need. **OpenTDF: Connection…**, or the centered **Connect…** button near the top of the disconnected sidebar, opens the saved connections list. Navigation links appear after connecting. Use **New Connection** above the table to add one. Select a row and click **Connect** at the bottom right, or press Enter on the row. Each row has a **⋮** menu with **Edit…** and **Delete**. Saving works without a running platform or a client secret.

There is no identity provider URL to enter: the plugin reads the token endpoint from the platform's `/.well-known/opentdf-configuration` and requests a token with the client credentials grant. The token stays in memory and is renewed before it expires.

Saved connections and any remembered client secrets are stored in plain text in ttt's plugin storage, `~/.config/ttt/state/plugins/opentdf.json`. Existing single-connection settings are migrated automatically.

The connection row's **⋮** menu lists your saved connections for quick switching and marks the active one. A divider precedes **Manage Connections…**, followed by another divider and **Disconnect** while connected. Disconnect clears the session token and stops automatic reconnection, keeping the saved connection. Switching to another connection closes the previous connection's tabs and clears its cached data. The panel's header **⋮** menu also has **Reconnect**, **Disconnect** and **Refresh Counts**.

## Settings

**OpenTDF: Settings…** (also in the panel's **⋮** menu) sets how many items a list loads per page: 10, 20, 50 (the default) or 100.

## Using it

The sidebar lists every view with its item count. Click one, or press Enter on it, to open it in an editor tab with focus in the tab. Each namespace, attribute, value, server, key or mapping you open gets its own tab too, and opening it again switches to that tab.

New and Edit forms open in their own tab with the cursor in the first field, so you can start typing right away. Saving or **Cancel** closes the form and returns to the tab you opened it from. Short forms, such as renaming or editing labels, open as dialogs.

Every view also has a command: **OpenTDF: Namespaces**, **OpenTDF: Attributes**, **OpenTDF: Actions**, **OpenTDF: Registered Resources**, **OpenTDF: Subject Mappings**, **OpenTDF: Condition Sets**, **OpenTDF: KAS & Keys**, **OpenTDF: Entitlements** and **OpenTDF: Decision**.

## What you can manage

- **Namespaces**, **attributes** and their **values**: create, edit labels, deactivate.
- **Actions**: standard and custom, per namespace. Create, rename, delete.
- **Registered resources** and their values, with the actions on attribute values each value stands for in decisions.
- **Subject mappings** and **condition sets**: which subjects get which actions on an attribute value, built from subject sets, groups and conditions.
- **Key access servers and keys**: create servers and keys, rotate keys, set the base key, view a key's public PEM. New keys default to **Public key only**, where you paste the public PEM; such a key cannot be the base key, since the platform has no private key for it. **Config root key** and **Provider root key** need the private key already wrapped, pasted as base64.
- **Entitlements** and **Decision** (authorization v2): what an entity is entitled to, and permit or deny for an entity, an action and a set of attribute values.

## Development

ttt loads a plugin from one Lua file, so the source lives in `src/` as modules and `scripts/build.py` bundles them into `init.lua`. Edit `src/`, never `init.lua`, then rebuild:

```sh
scripts/build.py           # writes init.lua
scripts/build.py --check   # fails when init.lua is out of date
stylua src tests           # format (settings in .stylua.toml)
lua tests/connections.lua   # connection lifecycle and persistence tests (Lua 5.1+)
```

A module's name is its path: `src/features/kas/store.lua` is `require("features.kas.store")`, and a folder's `init.lua` is the folder itself. `ttt.*` modules resolve as usual, and the bundle runs `src/main.lua`.

```
src/
  main.lua          registers the features, sidebar and commands
  core/             api client, state, services, utilities
  components/       widgets built on the ttt widget API (tables, forms, dialogs, filters)
  shared/           pieces several features use (labels, conditions, pickers)
  app/              router, navigation, sidebar, connection and settings dialogs
  features/<name>/  one folder per view: store, commands, pages, forms
```

A feature exposes `{ id, root }` from its `init.lua`. `Router.show` opens a detail page in its own tab and `Router.open_form` opens a form in one; `Router.close_form` closes it and returns to the tab it came from. When two modules need each other, require the second inside the function that uses it, since a `require` cycle at load time is an error.

Build pages from named local functions, not nested inline closures, and wire callbacks with `U.bind(fn, ...)`, which passes its bound arguments first and the caller's after them. Measure display text with `ttt.text.width`, not `#s`. Runtime errors point at lines in `init.lua`; each module starts with a `-- src/…` comment there.

`scripts/seed.sh` fills a local platform with sample namespaces, attributes, values, servers, keys and actions, and `scripts/seed-mappings.sh` adds subject mappings on `acme.com` so Entitlements and Decision have results. Both read `PLATFORM`, `OIDC`, `CLIENT_ID` and `CLIENT_SECRET`, default to the local platform, and need `curl`, `jq` and `openssl`.

## License

MIT
