# OpenTDF for ttt

An admin console for [OpenTDF](https://opentdf.io), inside the [ttt](https://github.com/eugenioenko/ttt) terminal editor.

OpenTDF is an open source system for attribute-based access control and data-centric encryption. Data is protected with attributes, such as a classification, a department or a region. The platform decides who can decrypt it from the entitlements each person or service has. This plugin connects ttt to an OpenTDF platform, so you can browse and manage its policy, its key access servers and keys, and test access decisions without leaving the editor.

## Features

The **OpenTDF** sidebar panel lists what you can open. Each view opens in an editor tab, and so does each namespace, attribute, value, server or key you open from it (opening one again focuses its tab):

- **Namespaces**: search, filter by state, create, edit labels, deactivate. A namespace's page has tabs for its attributes and actions.
- **Attributes**: attributes on the left and the selected attribute's values on the right. Filter by namespace, state or text. Create attributes and values, edit labels, deactivate.
- **Actions**: standard and custom actions, filtered by namespace. Create, rename, delete.
- **Registered Resources**: resources on the left and the selected resource's values on the right. Create resources with their values, rename, edit labels, delete. Each value holds the actions on attribute values it stands for in decisions.
- **Subject Mappings**: which subjects get which actions on an attribute value. Create and edit them with an existing condition set or a new one, change actions, edit labels, delete.
- **Condition Sets**: subject condition sets, built with nested subject sets, groups and conditions that stack down the page. A condition set's page lists the subject mappings that use it.
- **KAS & Keys**: key access servers on the left and their keys on the right, or every key under **All keys**. Filter keys by algorithm or text. Create servers and keys, rotate keys, set the base key, and view a key's public PEM.
- **Entitlements**: the attribute values and actions an entity is entitled to (authorization v2).
- **Decision**: permit or deny for an entity, an action and a resource's attribute values (authorization v2), either for all values together or for each value separately.

Lists page through the platform 50 items at a time. Change the page size (10, 20, 50 or 100) under **Settings…** in the panel menu or with the `OpenTDF: Settings…` command.

## Running a platform

You need a running OpenTDF platform and its identity provider. The [opentdf/platform](https://github.com/opentdf/platform) repository has the instructions for starting one locally with Docker Compose, which brings up the platform on `http://localhost:8080` and Keycloak on `http://localhost:8888`. See [opentdf.io](https://opentdf.io) for the concepts and the full documentation.

## Install

Clone the repository and link it into ttt's plugins folder, then restart ttt:

```sh
git clone https://github.com/eugenioenko/ttt-opentdf.git
ln -s "$PWD/ttt-opentdf" ~/.config/ttt/plugins/opentdf
```

ttt asks you to approve the permissions on first start. The plugin uses `network.http` (to reach the platform and its identity provider), `storage` (to remember the connection and settings), `panel.sidebar`, `panel.editor` and `commands`.

Open the **OpenTDF** sidebar panel and pick **Set up connection…**. Enter the platform URL and a client that can manage policy (for the local platform, `opentdf` / `secret`). The token endpoint comes from the platform's `.well-known/opentdf-configuration`, so there is no identity provider URL to fill in.

The client secret is saved in plain text in ttt's plugin storage (`~/.config/ttt/state/plugins/opentdf.json`).

## Keys

Keys created here use the **Public key only** mode by default: paste the public PEM. A public-key-only key can't be the base key, because the platform has no private key to decrypt with. The **Config root key** and **Provider root key** modes need the private key already wrapped (by the platform's root key, or by a key provider), pasted as base64.

## Sample data

`scripts/seed.sh` fills a local platform with enough namespaces, attributes, values, servers, keys and actions to page through. `scripts/seed-mappings.sh` then adds subject mappings on `acme.com` for the `opentdf` and `opentdf-sdk` clients, so Entitlements and Decision have results. Both read `PLATFORM`, `OIDC`, `CLIENT_ID` and `CLIENT_SECRET`, and default to the local platform. They need `curl`, `jq` and `openssl`.

## Development

ttt loads a plugin from a single Lua file, so the source lives in `src/` as modules and `scripts/build.py` bundles them into `init.lua`. Edit `src/`, never `init.lua`, and rebuild:

```sh
scripts/build.py           # writes init.lua
scripts/build.py --check   # fails when init.lua is out of date
```

A module's name is its path: `src/features/kas/store.lua` is `require("features.kas.store")`, and a folder's `init.lua` is the folder itself, so `src/features/kas/init.lua` is `require("features.kas")`. `ttt.*` modules resolve as usual. The bundle runs `src/main.lua`.

```
src/
  main.lua          registers the features, sidebar and commands
  core/             api client, state, services, utilities
  components/       generic widgets built on the ttt widget API (tables, forms, dialogs, filters)
  shared/           pieces several features use (labels, entity picker)
  app/              router, navigation, sidebar, connection and settings dialogs
  features/<name>/  one folder per screen: store, commands, pages
```

A feature exposes `{ id, root }` from its `init.lua`; `Router.show` opens a detail page in its own tab and `Router.push` adds a step, like a form, inside the current one. Its `store` holds the lists and state, `commands` the dialogs and API calls, and each `*_page.lua` renders one page. When two modules need each other (commands that open a detail page, a detail page that runs commands), require the second one inside the function that uses it: a `require` cycle at load time is an error.

Pages and components are built from named local functions instead of nested inline closures, so `M.page` reads as an outline. Callbacks are wired with `U.bind(fn, ...)`, which passes its bound arguments first and the caller's after them: `on_click = U.bind(Commands.new_value, a)`, `render = U.bind(render, page, a)`. Functions used as callbacks therefore take their context first and the panel or event arguments last.

Runtime errors point at lines in `init.lua`. Each module starts with a `-- src/…` comment there, so search upward from the line to find the source file.

Format with `stylua src` (settings in `.stylua.toml`).

## Requirements

The plugin uses widget features that are not in a ttt release yet: the `pager` and `tabs` widgets, `open_tab` IDs and `on_close`, table `on_activate`, `inset`, `loading` and `empty`, list `badge_right` and `inset`, hstack `align`, keyvalue `muted_keys`, bordered and titled inputs, scroll views that fit their content to their width, `ttt.debounce` and `crypto.base64_*`. Until they ship, build ttt from the `feat/plugin-pager` branch.

## License

MIT
