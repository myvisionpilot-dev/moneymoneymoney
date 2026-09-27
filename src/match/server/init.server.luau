--!strict
-- Match server entry point. Order matters: roster first, the run loop last.

local Delivery = require(script.Paths.Delivery)
local PathService = require(script.PathService)

PathService.register(Delivery)

require(script.RosterService).start()
require(script.SyncService).start()
require(script.DepositService).start()
PathService.start()
require(script.DebugService).start()
require(script.QuotaRunService).start()
