--!strict

local Scope = {}

--- Dependencies
local types = require("./Types")
local external = require("./External")

local logger = require("./Components/Logger")
local runTime = require("./Components/RunTime")
local tableUtil = require("./Components/TableUtil")

--- Constants
local DEFAULT_OPTIONS: types.ScopeOptions = {
	attempts = 3,

	import = {
		requireIgnite = false,
	},

	boot = {
		freeze = false,
		preInit = false,
	},

	lifecycle = {
		preInit = "preInit",
		init = "init",
		start = "start",
	},
}

--- Types
export type PrivateScope = types.Scope & {
	_name: string,
	_status: "preload" | "started" | "completed",
	_options: types.ScopeOptions,
	_sorted: { [number]: { name: string, module: { [any]: any } } },
	_totalIndex: number,
	_timestamp: number,

	_watch: (self: PrivateScope) -> { [string]: { [any]: any } },
	_find: (self: PrivateScope, tag: string) -> { name: string, module: { [any]: any } },
	_getModule: (self: PrivateScope, name: string, waitForChild: boolean?) -> { [any]: any },
	_import: (self: PrivateScope, value: (string | { string })?, waitForChild: boolean?) -> ...any,
	add: (self: PrivateScope, graph: { ModuleScript }) -> (),
}

--- Constructor

--[=[
    Construct Scope instance.
    It reconciles the provided options with the default ones and initializes the internal state for module tracking.
    @param name string
    @param options ScopeOptions
    @return types.Scope
]=]
function Scope.new(name: string, options: types.ScopeOptions?)
	local self = ({} :: any) :: PrivateScope

	self._name = name
	self._sorted = {}
	self._options = tableUtil.reconcile(options or {}, DEFAULT_OPTIONS)

	self._totalIndex = 0
	self._timestamp = 0
	self._status = "preload"

	setmetatable(self :: any, {
		__index = Scope,
		__call = function(tbl, value: (string | { string })?, waitForChild: boolean?)
			return ((tbl :: any) :: PrivateScope):_import(value, waitForChild)
		end,
	})

	return (self :: any) :: types.Scope
end

--- Private

--[=[
    Returns a dictionary mapping all currently registered module names
    to their loaded instances. Useful for debugging or inspecting the scope's state.
    @return {[string]: any}
]=]
function Scope._watch(self: PrivateScope)
	local result = {}
	for _, event in ipairs(self._sorted) do
		result[event.name] = event.module
	end
	return result
end

--[=[
   Internal helper to find a module entry by name.
   @private
   @param name string
   @return table?
]=]
function Scope._find(self: PrivateScope, name: string)
	for _, event in ipairs(self._sorted) do
		if event.name == name then
			return event
		end
	end
	return nil :: any
end

--[=[
   Retrieves a module from the scope. Can yield if waitForChild is true.
   @private
   @param name string
   @param waitForChild boolean?
   @return any
]=]
function Scope._getModule(self: PrivateScope, name: string, waitForChild: boolean?)
	local event = self:_find(name)
	if not event and waitForChild then
		runTime.getSignal(self._name .. name):Wait()
		event = self:_find(name)
	end
	logger.assert(event ~= nil, `Module "{name}" not found in {self._name}.`, true)
	return event.module
end

--[=[
    Handles module imports. This is triggered when calling the scope object directly.
    @param value (string | {string})?
    @param waitForChild boolean? 
    @return ...any
]=]
function Scope._import(self: PrivateScope, value: (string | { string })?, waitForChild: boolean?): ...any
	local options = self._options
	if self._status == "preload" then
		logger.assert(
			options.import.requireIgnite :: boolean,
			`Cannot call ".import()" until {self._name} has been started.`,
			true
		)
	end

	if not value then
		return self:_watch()
	end

	local value_type = typeof(value)
	if value_type == "string" then
		return self:_getModule(value :: string, waitForChild)
	end

	logger.assert(value_type == "table", `Attempt to call multiple imports! Expected table; got "{value_type}".`, true)

	local result = {}
	for _, moduleName in ipairs(value :: { string }) do
		logger.assert(typeof(moduleName) == "string", `ModuleName must be a string; got "{typeof(moduleName)}" `, true)
		local m = self:_getModule(moduleName, waitForChild)
		table.insert(result, m)
	end
	return table.unpack(result)
end

--- Public

--[=[
    Adds and preloads modules into the scope.
    @param graph {ModuleScript}
]=]
function Scope.add(self: PrivateScope, graph: { ModuleScript })
	local options = self._options
	local boot = options.boot
	local lifecycle = options.lifecycle
	local callMethod = lifecycle.preInit

	for i, v in ipairs(graph) do
		local result = runTime.retryWithDelay(function()
			return runTime.preloadModuleScript(v)
		end, options.attempts)

		if not result then
			logger.logErrorNonFatal(`There was a problem loading the module {v.Name}.`, true)
			continue
		end

		if boot.preInit and typeof(result) == "table" then
			local callback = result[callMethod] :: (...any) -> ()
			if typeof(callback) == "function" then
				callback(result)
			end
		end

		self._totalIndex += 1
		self._sorted[i] = { name = v.Name, module = result }
		runTime.resolveSignal(self._name .. v.Name)
	end
end

--[=[
   Starts the scope lifecycle (init and start).
   @return Promise
]=]
function Scope.ignite(self: PrivateScope)
	local alreadyStarted = (self._status == "started" or self._status == "completed")

	if alreadyStarted then
		return external.Promise.reject("Already Started!")
	end

	local startTime = workspace:GetServerTimeNow()
	self._status = "started"
	local options = self._options

	if options.boot.freeze then
		table.freeze(self._sorted)
	end

	local initCall = options.lifecycle.init
	local startCall = options.lifecycle.start

	return external.Promise
		.new(function(resolve)
			local promises = {}
			for _, event in ipairs(self._sorted) do
				local module = event.module

				if typeof(module[initCall]) ~= "function" then
					continue
				end

				table.insert(
					promises :: any,
					external.Promise.new(function(r)
						module[initCall](module)
						debug.setmemorycategory(event.name)
						r()
					end)
				)
			end
			resolve(external.Promise.all(promises))
		end)
		:andThen(function()
			for _, event in ipairs(self._sorted) do
				local module = event.module
				if typeof(module[startCall]) ~= "function" then
					continue
				end

				task.spawn(function()
					module[startCall](module)
				end)
			end

			self._status = "completed"
			self._timestamp = (workspace:GetServerTimeNow() - startTime)
			runTime.resolveSignal(self._name .. "| global")

			return self._totalIndex, self._timestamp
		end)
end

return Scope
