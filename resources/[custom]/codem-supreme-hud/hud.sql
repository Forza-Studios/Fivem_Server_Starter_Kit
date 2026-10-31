-- ===========================
-- Codem HUD - Database Schema
-- Run this SQL if Config.AutoSql = false
-- ===========================

-- Table: codem_player_stress (ESX only - QBCore uses metadata)
CREATE TABLE IF NOT EXISTS `codem_player_stress` (
    `identifier` varchar(60) NOT NULL,
    `stress` int(11) NOT NULL DEFAULT 0,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: codem_hud_presets
CREATE TABLE IF NOT EXISTS `codem_hud_presets` (
    `id` varchar(50) NOT NULL,
    `identifier` varchar(60) NOT NULL,
    `name` varchar(100) NOT NULL,
    `settings` longtext NOT NULL,
    `source` varchar(10) NOT NULL DEFAULT 'local',
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_presets_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: codem_vehicle_mods
CREATE TABLE IF NOT EXISTS `codem_vehicle_mods` (
    `plate` varchar(12) NOT NULL,
    `current_mod` varchar(20) DEFAULT 'comfort',
    `installed_mods` text DEFAULT '[\"comfort\",\"drift\"]',
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: codem_vehicle_nitro
CREATE TABLE IF NOT EXISTS `codem_vehicle_nitro` (
    `plate` varchar(12) NOT NULL,
    `level` int(11) DEFAULT 100,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: codem_music_playlists
CREATE TABLE IF NOT EXISTS `codem_music_playlists` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(60) NOT NULL,
    `owner_name` varchar(100) DEFAULT 'Unknown',
    `name` varchar(100) NOT NULL,
    `cover_url` text DEFAULT NULL,
    `likes` int(11) NOT NULL DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_likes` (`likes`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: codem_music_playlist_songs
CREATE TABLE IF NOT EXISTS `codem_music_playlist_songs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `playlist_id` int(11) NOT NULL,
    `url` text NOT NULL,
    `title` varchar(255) NOT NULL,
    `artist` varchar(255) DEFAULT 'Unknown',
    `thumbnail` text DEFAULT NULL,
    `duration` int(11) DEFAULT 0,
    `position` int(11) DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_playlist` (`playlist_id`),
    KEY `idx_playlist_position` (`playlist_id`, `position`),
    CONSTRAINT `codem_music_playlist_songs_ibfk_1` FOREIGN KEY (`playlist_id`) REFERENCES `codem_music_playlists` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: codem_music_playlist_likes
CREATE TABLE IF NOT EXISTS `codem_music_playlist_likes` (
    `playlist_id` int(11) NOT NULL,
    `identifier` varchar(60) NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`playlist_id`, `identifier`),
    KEY `idx_identifier` (`identifier`),
    CONSTRAINT `codem_music_playlist_likes_ibfk_1` FOREIGN KEY (`playlist_id`) REFERENCES `codem_music_playlists` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
