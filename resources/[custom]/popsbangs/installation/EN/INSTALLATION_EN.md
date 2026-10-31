# Installation Guide — oxlyn-popsbangs (English)

Welcome to the installation guide for **oxlyn-popsbangs** (Advanced Pops & Bangs, Anti-Lag, Two-Step / Launch Control, Colored Backfire Flames & Motorized Exhaust Cutout Valves).

---

## 1. Startup in `server.cfg`

Add this line to your `server.cfg` after your core framework and inventory resources:

```cfg
ensure oxlyn-popsbangs
```

> **Note:** If you are using `ox_inventory`, ensure that `ox_inventory` starts before `oxlyn-popsbangs`.

---

## 2. Database Installation (SQL)

If you use **ESX** with the standard database `items` table:

1. Open your database administration tool (HeidiSQL, phpMyAdmin, Navicat, etc.).
2. Select your FiveM database.
3. Run the SQL file provided: [`items_esx.sql`](file:///d:/basecleanscript/txData/ESXLegacy_C15A8D.base/resources/[standalone]/oxlyn-popsbangs/installation/EN/items_esx.sql).

---

## 3. Inventory Configuration

### Option A: `ox_inventory`
1. Open `ox_inventory/data/items.lua`.
2. Copy the content of [`ox_inventory_items.lua`](file:///d:/basecleanscript/txData/ESXLegacy_C15A8D.base/resources/[standalone]/oxlyn-popsbangs/installation/EN/ox_inventory_items.lua) and paste it into the `Item list` table.
3. Copy all images inside the `html/img/` folder of this resource into `ox_inventory/web/images/`.
4. Restart `ox_inventory`.

### Option B: `qb-inventory` / `qb-core`
1. Open `qb-core/shared/items.lua`.
2. Copy the content of [`qbcore_items.lua`](file:///d:/basecleanscript/txData/ESXLegacy_C15A8D.base/resources/[standalone]/oxlyn-popsbangs/installation/EN/qbcore_items.lua).
3. Copy all images from `html/img/` into `qb-inventory/html/images/`.

---

## 4. Usage & Gameplay Guide

### A. Colored Exhaust Lines
1. Sit in the driver seat of a vehicle (stationary).
2. Use one of the exhaust items (e.g. `popsbangs_exhaust_cyan`).
3. The interactive workshop installation progress bar will display with 5 mechanical sound & visual phases.
4. When complete, the exhaust is mounted and your backfire flames will burn in the selected color.

### B. Anti-Lag Kit (Pops & Bangs Tuning)
1. Use the `popsbangs_antilag_kit` item while in the vehicle.
2. Once the mechanical installation completes, the Level Selector UI appears:
   - Use Arrow Keys `←` and `→` or numeric keys `1`, `2`, `3`, `4` to select the tune stage (`Street`, `Sport`, `Extreme`, `Brutal`).
   - Press `Enter` to confirm your selection.
3. To uninstall anti-lag and return to stock, use the `popsbangs_antilag_remover` item.

### C. Exhaust Valve Remote Control
- Use the `popsbangs_valve_control` item or type **/valve** in chat.
- A wireless keyfob remote control UI appears on screen.
- Click **Open** (valves open: loud aggressive tone, maximum backfire pops and flames) or **Close** (valves closed: quiet, muted exhaust note).
- Press **Escape** or backspace to close the remote UI.

---

## 5. In-Game Commands (Players & Admins)

| Command | Permission | Description |
|---|---|---|
| `/installpops [level]` | Player / Admin | Set vehicle pops level manually (e.g., `/installpops 2` or `/installpops 0` to disable). |
| `/antilag` | Player | Toggle the anti-lag / pops module on or off for your vehicle. |
| `/valve` | Player | Opens the exhaust cutout valve remote control. |
| `/givepops [id]` | Admin | Gives a complete package of all script items to the target player ID. |

---

## 6. Configuration in `config/`

- **`config/config.lua`**: General settings, tune levels, volume, job restrictions (e.g. mechanic-only install via `Config.Items.jobs`).
- **`config/exhausts.lua`**: Exhaust catalog, custom RGB flame colors, black smoke particles.
- **`config/flames.lua`**: Flame scale, light intensity, weather reactivity, and flame types.
- **`config/audio.lua`**: Sound frequencies, acoustic resonance, and reverb properties.
