

-- =====================================================================
-- Routes (managed in-game by admins via /truckroute commands)
--
-- This list is intentionally empty. Routes created at runtime are
-- persisted in `routes.json` (file path configurable via
-- Config.Admin.persistFile) and merged into Config.Routes on boot.
--
-- Admin commands (default ace flag: oxlyn.truckjob.admin):
--   /truckroute pickup                  capture current pos as pickup
--   /truckroute delivery                capture current pos as delivery (auto-saves)
--   /truckroute cancel                  drop in-progress capture
--   /truckroute list                    list saved routes
--   /truckroute remove <id|index>       delete a saved route
--   /truckroute level <id|index> <N>    pin min level (override auto-balance)
--   /truckroute price <id|index> <N>    pin payment
--   /truckroute difficulty <id|index> <easy|medium|hard>
--   /truckroute auto <id|index>         clear overrides
--   /truckroute bonus                   start a manual bonus event
--
-- Pricing, required level and difficulty are auto-computed from the
-- pickup/delivery distance (see Config.AutoBalance).
-- =====================================================================
Config.Routes = {}

