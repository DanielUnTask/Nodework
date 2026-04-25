--!strict
local Nodework = {}

--- Dependencies
local Types = require("@self/Types")
local Scope = require("@self/Scope")
local Logger = require("@self/Components/Logger")
local RunTime = require("@self/Components/RunTime")
local External = require("@self/External")
local TableUtil = require("@self/Components/TableUtil")

--- Types
export type Promise<T...> = External.Promise<T...>
export type PromiseConstructor = External.PromiseConstructor

--- Variables
local Scopes = {}

--- Public
function Nodework:register(scopeName: string, options: Types.ScopeOptions?)
	Logger.assert(not Scopes[scopeName], `A scope with the same name was found; {scopeName}`)
	local scope = Scope.new(scopeName, options)
	Scopes[scopeName] = scope
	self[scopeName] = scope
end

function Nodework:addPath(path: string, order: { string }?, exclude: { string }?)
	local parent = RunTime.resolvePath(path)
	return {
		to = function(_, scopeName: string)
			local scope = Scopes[scopeName] :: Scope.PrivateScope
			local modules = RunTime.getModuleTable(parent, scope._options.deep :: boolean, scope._options.predicate)
			local sources = TableUtil.exclude(modules, exclude or {})
			local graph = TableUtil.sort(sources, order or {})
			scope:add(graph)
		end,
	}
end

return (Nodework :: any) :: Types.Nodework
