--!strict
-- DataStore-backed player data with session locking, retries, autosave and safe shutdown.
--
-- Rules for other services:
--   * Read with DataService.Get(player). Never cache the table across yields for writing.
--   * Write only through DataService.Update(player, mutator). The mutator must not yield, which makes
--     "check balance then deduct" atomic.
--
-- For a large live game, ProfileStore (open source) is a battle-tested drop-in for this module.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Config.Progression)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local Remotes = ReplicatedStorage.Remotes

type PlayerData = Types.PlayerData
type SessionLock = { JobId: string, Time: number }
type SavedRecord = { Data: PlayerData?, SessionLock: SessionLock? }
type Profile = {
	Data: PlayerData,
	CanSave: boolean,
	Released: boolean,
}

local LOCK_EXPIRY = Progression.AutosaveInterval * 3
local LOAD_ATTEMPTS = 5
local RETRY_DELAY = 4

local DataService = {
	ProfileLoaded = Signal.new(), -- (player, data)
	Changed = Signal.new(), -- (player, data)
}

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(Progression.DataStoreName)
end)
if not storeOk then
	warn("[DataService] DataStores unavailable (publish the place to enable them):", store)
end

local profiles: { [Player]: Profile } = {}
local releasing: { [number]: boolean } = {}
local syncQueued: { [Player]: boolean } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return copy :: any
end

-- Fills keys added to the template after a player's data was first saved.
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function migrate(data: PlayerData)
	-- Example: if data.Version < 2 then <transform> data.Version = 2 end
	data.Version = Progression.Template.Version
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function loadAsync(player: Player): (boolean, PlayerData?)
	if not storeOk then
		return false, nil
	end
	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		-- After waiting out the retries, assume the other server crashed and take the lock.
		local force = attempt == LOAD_ATTEMPTS
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(record: SavedRecord?): SavedRecord?
				local current: SavedRecord = record or {}
				local lock = current.SessionLock
				if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_EXPIRY and not force then
					lockedElsewhere = true
					return nil
				end
				current.SessionLock = { JobId = game.JobId, Time = os.time() }
				return current
			end)
		end)
		if ok and not lockedElsewhere then
			local record = result :: SavedRecord?
			return true, if record then record.Data else nil
		elseif not ok then
			warn(`[DataService] Load attempt {attempt} failed for {player.UserId}: {result}`)
		end
		task.wait(RETRY_DELAY)
	end
	return false, nil
end

local function saveAsync(player: Player, profile: Profile, release: boolean): boolean
	if not storeOk or not profile.CanSave then
		return true
	end
	if release then
		profile.Released = true
	end
	local lostLock = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player.UserId), function(record: SavedRecord?): SavedRecord?
			-- An autosave that queued before the final release save must not re-take the lock.
			if profile.Released and not release then
				return nil
			end
			local current: SavedRecord = record or {}
			local lock = current.SessionLock
			if lock and lock.JobId ~= game.JobId then
				lostLock = true
				return nil
			end
			current.Data = profile.Data
			current.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return current
		end)
	end)
	if not ok then
		warn(`[DataService] Save failed for {player.UserId}: {err}`)
		return false
	end
	if lostLock then
		profile.CanSave = false
		if not release and player.Parent then
			player:Kick("Your data was opened in another server. Please rejoin.")
		end
		return false
	end
	return true
end

local function queueSync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local profile = profiles[player]
		if profile and player.Parent then
			Remotes.DataSync:FireClient(player, profile.Data)
		end
	end)
end

local function onPlayerAdded(player: Player)
	-- Rejoining the same server: wait for the previous session's release save.
	while releasing[player.UserId] do
		task.wait(0.1)
	end

	local ok, saved = loadAsync(player)
	local canSave = ok
	if not ok then
		if RunService:IsStudio() then
			warn("[DataService] Using temporary data; progress will NOT save. Enable Studio API access to test saving.")
		else
			-- Never play on default data: the next save would overwrite the player's real progress.
			player:Kick("We couldn't load your data. Please rejoin in a moment.")
			return
		end
	end

	local data: PlayerData = if saved then deepCopy(saved) else deepCopy(Progression.Template)
	reconcile(data :: any, Progression.Template :: any)
	migrate(data)

	local profile: Profile = { Data = data, CanSave = canSave, Released = false }
	if not player.Parent then
		saveAsync(player, profile, true)
		return
	end

	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, data)
	queueSync(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	releasing[player.UserId] = true
	saveAsync(player, profile, true)
	releasing[player.UserId] = nil
end

function DataService.Get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.Update(player: Player, mutator: (PlayerData) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	DataService.Changed:Fire(player, profile.Data)
	queueSync(player)
	return true
end

function DataService.WaitForData(player: Player, timeout: number): PlayerData?
	local deadline = os.clock() + timeout
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

function DataService.Start()
	Remotes.GetData.OnServerInvoke = function(player: Player)
		return DataService.WaitForData(player, 30)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Progression.AutosaveInterval)
			for player, profile in profiles do
				task.spawn(saveAsync, player, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			profiles[player] = nil
			pending += 1
			task.spawn(function()
				saveAsync(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while (pending > 0 or next(releasing) ~= nil) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
