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
const Scopes = {} :: { [string]: Scope.PrivateScope }

--- Public
function Nodework:register(scopeName: string, options: Types.ScopeOptions?)
	Logger.assert(not Scopes[scopeName], `A scope with the same name was found; {scopeName}`)
	const scope = Scope.new(scopeName, options)
	Scopes[scopeName] = scope
	RunTime.resolveSignal(`{scopeName}_wait_scope`)
end

function Nodework:addPath(path: string, order: { string }?, exclude: { string }?)
	local parent = RunTime.resolvePath(path)
	return {
		to = function(_, scopeName: string)
			const scope = Scopes[scopeName] :: Scope.PrivateScope
			const modules = RunTime.getModuleTable(parent :: any, scope._options.predicate)
			const sources = TableUtil.exclude(modules, exclude or {})
			const graph = TableUtil.sort(sources, order or {})
			scope:add(graph)
		end,
	}
end

function Nodework:wait(scopeName: string): Scope.PrivateScope
	RunTime.getSignal(`{scopeName}_wait_scope`):Wait()
	return Scopes[scopeName] :: Scope.PrivateScope
end

setmetatable(Nodework, {
	__index = function(_, key: string)
		local scope = Scopes[key]
		if scope then
			return scope
		end
		return Scopes[key]
	end,
})

return (Nodework :: any) :: Types.Nodework
