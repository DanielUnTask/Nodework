--!strict
--!optimize 2

--- Imports
local External = require("./External")

--- Types

export type ScopeOptions = {
	deep: boolean?,
	attempts: number?,
	predicate: ((module: ModuleScript) -> boolean)?,

	import: {
		requireIgnite: boolean?,
	},

	boot: {
		freeze: boolean?,
		preInit: boolean?,
	},

	lifecycle: {
		preInit: string?,
		init: string?,
		start: string?,
	},
}

export type Scope = <T...>(value: (string | { string })?, waitForChild: boolean) -> T... & {
	ignite: (self: Scope) -> External.Promise<number, number>,
}

export type Node = {
	to: (self: Node, scopeName: string) -> (),
}

export type Nodework = {
	register: (self: Nodework, scopeName: string, options: ScopeOptions?) -> (),
	addPath: (self: Nodework, path: string, order: { string }?, exclude: { string }?) -> Node,
	[string]: Scope,
}

return nil
