-- ===========================================================================
--  oxlyn-popsbangs — Importation SQL pour ESX (Français)
-- ===========================================================================

INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
    ('popsbangs_antilag_kit', 'Kit Anti-Lag', 5, 0, 1),
    ('popsbangs_antilag_remover', 'Kit de retrait Anti-Lag', 3, 0, 1),
    ('popsbangs_valve_control', 'Télécommande Clapet Échappement', 1, 0, 1),
    ('popsbangs_exhaust_stock', 'Échappement Inox (Origine)', 10, 0, 1),
    ('popsbangs_exhaust_cobalt', 'Échappement Bleu Cobalt', 10, 0, 1),
    ('popsbangs_exhaust_cyan', 'Échappement Cyan', 10, 0, 1),
    ('popsbangs_exhaust_turquoise', 'Échappement Turquoise', 10, 0, 1),
    ('popsbangs_exhaust_emerald', 'Échappement Vert Émeraude', 10, 0, 1),
    ('popsbangs_exhaust_lime', 'Échappement Vert Lime', 10, 0, 1),
    ('popsbangs_exhaust_ruby', 'Échappement Rouge Rubis', 10, 0, 1),
    ('popsbangs_exhaust_orange', 'Échappement Orange', 10, 0, 1),
    ('popsbangs_exhaust_yellow', 'Échappement Jaune', 10, 0, 1),
    ('popsbangs_exhaust_gold', 'Échappement Or', 10, 0, 1),
    ('popsbangs_exhaust_copper', 'Échappement Cuivre', 10, 0, 1),
    ('popsbangs_exhaust_amethyst', 'Échappement Violet Améthyste', 10, 0, 1),
    ('popsbangs_exhaust_magenta', 'Échappement Rose Magenta', 10, 0, 1),
    ('popsbangs_exhaust_pearl', 'Échappement Blanc Perle', 10, 0, 1),
    ('popsbangs_exhaust_black', 'Échappement Fumée Noire', 10, 0, 1)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `weight` = VALUES(`weight`);
