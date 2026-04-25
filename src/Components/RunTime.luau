--!strict
--!optimize 2

local RunTimeLib = {}

--- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--- Dependencies
local logger = require("./Logger")
local external = require("../External")

--- Constants
local IS_CLIENT = RunService:IsClient()
local ACCEPTABLE_SERVICES = {
	SERVER = "ServerScriptService",
	CLIENT = "PlayerScripts",
	SHARED = "ReplicatedStorage",
	SERVERSTORAGE = "ServerStorage",
}

--- Variables
local Signals = {} :: { [string]: external.Signal<...any> }

--- Private
local function resolveService(serviceName: string)
	local serviceClass = ACCEPTABLE_SERVICES[serviceName:upper()]
	logger.assert(serviceClass, `Invalid service: "{serviceName}" is not allowed.`, true)

	if serviceClass == "PlayerScripts" then
		logger.assert(IS_CLIENT, `Attempted to access PlayerScripts from the server.`, true)
		return Players.LocalPlayer:WaitForChild("PlayerScripts")
	end

	local invalid = IS_CLIENT and (serviceClass == "ServerStorage" or serviceClass == "ServerScriptService")
	logger.assert(not invalid, `Attempted to access server-only service: {serviceClass}.`, true)

	return game:GetService(serviceClass)
end

--- Public
function RunTimeLib.resolvePath(path: string)
	local segments = path:split("/")
	local service = resolveService(segments[1])

	local current = service
	for i = 2, #segments do
		current = current:WaitForChild(segments[i])
	end
	return current
end

function RunTimeLib.getSignal(tag: string)
	local signal = Signals[tag]
	if not signal then
		signal = external.Signal.new()
		Signals[tag] = signal
	end
	return signal
end

function RunTimeLib.resolveSignal(tag: string)
	local signal = Signals[tag]
	if signal then
		Signals[tag] = nil
		signal:Fire()
		task.defer(function()
			signal:Destroy()
		end)
	end
end

function RunTimeLib.preloadModuleScript(moduleScript: ModuleScript): { [any]: any }
	local startTime = workspace:GetServerTimeNow()
	local success, value = pcall(require, moduleScript :: any)
	local endTime = math.floor((workspace:GetServerTimeNow() - startTime) * 1000)
	if not success then
		logger.logError(`Failed to preload {moduleScript.Name}; {endTime}ms; {value}`, true)
	end
	return value :: any
end

function RunTimeLib.getModuleTable(
	parent: Instance,
	deep: boolean,
	predicateFn: ((module: ModuleScript) -> boolean)?
): { ModuleScript }
	local objects = (deep and parent:GetDescendants() or parent:GetChildren()) :: { Instance }
	local modules = {}

	for _, moduleScript in ipairs(objects) do
		if moduleScript:IsA("ModuleScript") then
			if typeof(predicateFn) == "function" and not predicateFn(moduleScript) then
				continue
			end

			table.insert(modules, moduleScript :: ModuleScript)
		end
	end

	return modules
end

function RunTimeLib.retryWithDelay<T>(callback: () -> T, max_attemps: number?): T
	local attemps = 0
	local maxAttemps = max_attemps or 3
	local success, result

	while not success and attemps < maxAttemps do
		success = pcall(function()
			result = callback()
		end)

		if not success then
			attemps += 1
			task.wait(2)
		end
	end

	if not success then
		logger.logWarn(`An error occurred while trying to execute the callback: {result}`, true)
	end

	return result
end

return RunTimeLib
