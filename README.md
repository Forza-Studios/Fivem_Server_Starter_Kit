Beginner-Friendly FIVEM Starter Kit

## What is this repository?

This is a **curated collection of FIVEM resources** sourced from public repositories available on the web. It is compiled specifically for **beginners** who are starting out with FIVEM server creation and want a well-organized, production-ready resource set.

All resources in this repo are **sourced from public repositories available on the web** — bundled together so new developers can focus on building their server rather than spending hours hunting for compatible libraries.

---

> ⚠️ **IMPORTANT LEGAL WARNING — READ BEFORE USING** ⚠️
>
> **These resources come from public web sources** and are provided here for **TESTING AND RESEARCH ONLY**.
>
> - Many resources are available through **multiple licensing tiers**: free demo, paid support, or commercial licenses
> - You can **safely test** these resources in a local/dev environment (this repo itself) before committing to use them
> - **DO NOT** use these resources on a **public production server** without proper licensing/permission
> - Violating licensing terms can lead to **DMCA takedown claims**, server strikes, and **legal action**
> - When ready, **purchase proper licenses** from the official source maintainers
>
> Always check each resource's `LICENSE` file and official repository for their specific terms before deploying to production.

## Project Agenda — Resource Sections

### Overview

The repository is organized into **7 logical sections**, each covering a different aspect of FIVEM server development:

| Section | Purpose |
|---|---|
| `[assets]` | Custom textures, IPLs, and visual assets |
| `[cfx-default]` | DX framework essentials |
| `[custom]` | Server UI, loading screens, and branding |
| `[npwd]` | Multiplayer web panel for admin management |
| `[ox]` | OxCore library ecosystem (the backbone) |
| `[qbx]` | Qbox ecosystem — jobs, admin, economy, management |
| `[standalone]` | Utilities, voice, IPLs, and helpers |
| `[vehicles]` | Custom vehicle models |
| `[voice]` | Voice chat systems |

---

### 1. `[assets]` — Custom Visual Assets

Custom textures, IPL (Interior Pictures Library), and visual elements.


  A customizable texture library for vehicle and UI theming.

---

### 2. `[cfx-default]` — DX Essentials

Default DX framework configuration folder.


  Standard local module structure.

---

### 3. `[custom]` — Server Branding & UX


  Admin UI component.

  Custom loading screen with client-side and server-side scripts.

  Shared Lua library for utilities, formatting, and helpers.

  UI popups and visual notifications.

---

### 4. `[npwd]` — Multiplayer Web Admin Panel

**NPWD (Now Playground)** is a client-server web panel for managing your FIVEM server.


  Original NPWD web admin panel.

  QBox-branded NPWD panel integration.

---

### 5. `[ox]` — OxCore Ecosystem (Backend Libraries)

OxCore is the **most popular open-source FIVEM framework** — a resource library providing shared functionality across many plugins.


  Vehicle door locking/unlocking system.

  In-game fuel system for vehicles.

  Advanced inventory system with containers, bags, and slots.

  **Core library** — logging, UI, configuration, localization, and utilities. *Required dependency.*

  MySQL database wrapper with UI for management.

  Target system with custom web UI for interactive targeting.
- **[ox_inventory], [ox_lib], [ox_mysql], [ox_target], [ox_doorlock], [ox_fuel]**  
  All OxCore resources share the same locale structure and configuration patterns.

---

### 6. `[qbx]` — Qbox Ecosystem (Application Layer)

QBox is a **framework built on OxCore** that provides full server applications including admin systems, economy, jobs, and management tools.

---

### 7. `[standalone]` — Utilities & Extras


  Custom interior pictures library.

  Audio module.
 
  Mobile phone hacking mechanic.

---

### 8. `[vehicles]` — Custom Vehicle Models


  Custom Pony car model with `.yft` stream and `.ytd` textures.

---

### 9. `[voice]` — Voice Chat


  Open-source radio/voice chat system.

  Push-to-talk voice chat with custom UI.

---

## Getting Started (Beginner Checklist)

### 1. Install required dependencies

```bash
git clone https://github.com/qbox-community/qbx-core.git qbx_core
git clone https://github.com/Qbase-OX/ox_lib.git ox_lib
git clone https://github.com/QBaseOX/ox_mysql.git ox_mysql
```

### 2. Start the server

```bash
ensure ox_lib
ensure ox_mysql
ensure qbx_core
ensure qbx_adminmenu
```

### 3. Customize

Edit the `config/` and `locales/` folders in `qbx_core` to match your server's branding, language, and preferences.

### 4. Add resources one by one

- Add **one** new resource at a time
- Test on a local test server first
- Check the `fxmanifest.lua` file for dependencies

---

## Notes for New Developers

1. **Read the README** in each resource's folder before adding it
2. **Check dependencies** — many Qbox/Ox resources require `ox_lib` or `qbx_core`
3. **Local config** folders must be preserved — never overwrite them
4. **fxmanifest.lua** is your entry point — understand what `provides`, `scripts`, and `shared` do
5. All resources here are from **public repositories** — check their respective GitHub pages for licensing and support

---

*This repository is compiled by the community for beginners. All resource authors retain copyright to their original work.*