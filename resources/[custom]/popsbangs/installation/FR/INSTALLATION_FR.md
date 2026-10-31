# Guide d'Installation — oxlyn-popsbangs (Français)

Bienvenue dans le guide d'installation du système **oxlyn-popsbangs** (Système avancé de Pops & Bangs, Anti-Lag, Deux-Temps / Two-Step, Flammes colorées et Clapets d'échappement motorisés).

---

## 1. Démarrage dans `server.cfg`

Ajoutez cette ligne dans votre fichier `server.cfg` après vos frameworks et inventaires :

```cfg
ensure oxlyn-popsbangs
```

> **Note :** Si vous utilisez `ox_inventory`, veillez à ce que `ox_inventory` démarre avant `oxlyn-popsbangs`.

---

## 2. Installation de la Base de Données (SQL)

Si vous utilisez **ESX** avec la table `items` standard dans votre base de données :

1. Ouvrez votre logiciel de gestion de base de données (HeidiSQL, phpMyAdmin, etc.).
2. Sélectionnez votre base de données FiveM.
3. Exécutez le fichier SQL fourni : [`items_esx.sql`](file:///d:/basecleanscript/txData/ESXLegacy_C15A8D.base/resources/[standalone]/oxlyn-popsbangs/installation/FR/items_esx.sql).

---

## 3. Configuration de l'Inventaire

### Option A : `ox_inventory`
1. Ouvrez le fichier `ox_inventory/data/items.lua`.
2. Copiez le contenu du fichier [`ox_inventory_items.lua`](file:///d:/basecleanscript/txData/ESXLegacy_C15A8D.base/resources/[standalone]/oxlyn-popsbangs/installation/FR/ox_inventory_items.lua) et collez-le à l'intérieur de la table `Item list`.
3. Copiez toutes les images contenues dans le dossier `html/img/` de ce script vers `ox_inventory/web/images/`.
4. Redémarrez `ox_inventory`.

### Option B : `qb-inventory` / `qb-core`
1. Ouvrez `qb-core/shared/items.lua`.
2. Copiez le contenu de [`qbcore_items.lua`](file:///d:/basecleanscript/txData/ESXLegacy_C15A8D.base/resources/[standalone]/oxlyn-popsbangs/installation/FR/qbcore_items.lua).
3. Copiez les images de `html/img/` vers `qb-inventory/html/images/`.

---

## 4. Fonctionnement et Utilisation

### A. Les Échappements Colorés
1. Montez à bord d'un véhicule à la place conducteur (moteur allumé ou éteint, véhicule à l'arrêt).
2. Utilisez l'un des items d'échappement (ex : `popsbangs_exhaust_cyan`).
3. La barre d'atelier s'affiche avec le montage étape par étape (5 phases sonores et visuelles).
4. À la fin du temps, l'échappement est monté et vos flammes prennent la couleur sélectionnée.

### B. Le Kit Anti-Lag
1. Utilisez l'item `popsbangs_antilag_kit` dans le véhicule.
2. Une fois la barre de montage terminée, le sélecteur de niveau s'affiche :
   - Utilisez les flèches `←` et `→` ou les touches `1`, `2`, `3`, `4` pour sélectionner la puissance (`Street`, `Sport`, `Extreme`, `Brutal`).
   - Appuyez sur `Entrée` pour valider votre choix.
3. Pour retirer l'anti-lag, utilisez l'item `popsbangs_antilag_remover`.

### C. La Télécommande des Clapets d'Échappement
- Utilisez l'item `popsbangs_valve_control` dans le véhicule ou tapez la commande **/valve**.
- Une télécommande interactive apparaît à l'écran.
- Cliquez sur **Open** (clapets ouverts : son fort et flammes libres) ou **Close** (clapets fermés : son atténué, échappement discret).
- Appuyez sur **Échap** pour fermer la télécommande.

---

## 5. Commandes Utiles (Admin & Joueur)

| Commande | Rôle | Description |
|---|---|---|
| `/installpops [niveau]` | Réglage | Règle le niveau de pops du véhicule (ex : `/installpops 2` ou `/installpops 0` pour désactiver). |
| `/antilag` | Bascule | Active ou désactive le module anti-lag / turbo sur votre véhicule. |
| `/valve` | Télécommande | Ouvre la télécommande de contrôle des clapets d'échappement. |
| `/givepops [id]` | Admin | Donne un ensemble complet d'items du script au joueur ciblé. |

---

## 6. Personnalisation dans `config/`

- **`config/config.lua`** : Réglages généraux, niveaux de puissance, son, gestion des métiers (ex : mécano uniquement via `Config.Items.jobs`).
- **`config/exhausts.lua`** : Liste des échappements, couleurs RGB personnalisées et effets de fumée noire.
- **`config/flames.lua`** : Tailles, intensités lumineuses, réactivité météo et types de flammes.
- **`config/audio.lua`** : Réglages des fréquences sonores, résonance acoustique et réverbération.
