--!strict
local TableUtils = {}

--- Dependencies
local logger = require("./Logger")

--- Public

--[=[
    @param src { ModuleScript }
    @param priority { string }
    @return { ModuleScript }
]=]
function TableUtils.sort(src: { ModuleScript }, priority: { string }): { [number]: ModuleScript }
	local mapping = {}
	local watch = {}

	for _, v in ipairs(src) do
		watch[v.Name] = v
	end

	for _, name in ipairs(priority) do
		local v = watch[name]
		if v and not table.find(mapping, v) then
			table.insert(mapping, v)
		end
	end

	for _, v in ipairs(src) do
		if not table.find(mapping, v) then
			table.insert(mapping, v)
		end
	end

	return mapping
end

--[=[
    @param src { ModuleScript }
    @param excludeKeys { string }
    @return { ModuleScript }
]=]
function TableUtils.exclude(src: { ModuleScript }, excludeKeys: { string }): { ModuleScript }
	local graph = {}
	for _, v in ipairs(src) do
		if table.find(excludeKeys, v.Name) then
			continue
		end
		table.insert(graph, v)
	end
	return graph
end

--[=[
    @param t T
    @param deep boolean?
    @return T
]=]
function TableUtils.copy<T>(t: T, deep: boolean?): T
	if not deep then
		return (table.clone(t :: any) :: any) :: T
	end
	local function DeepCopy(tbl: { any })
		local tCopy = table.clone(tbl)
		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = DeepCopy(v)
			end
		end
		return tCopy
	end
	return DeepCopy(t :: any) :: T
end

--[=[
    @param src S
    @param template T
    @return S & T
]=]
function TableUtils.reconcile<S, T>(src: S, template: T): S & T
	logger.assert(type(src) == "table", "First argument must be a table", true)
	logger.assert(type(template) == "table", "Second argument must be a table", true)

	local tbl = table.clone(src :: any)

	for k, v in template :: any do
		local sv = (src :: any)[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = TableUtils.copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = TableUtils.reconcile(sv, v)
			else
				tbl[k] = TableUtils.copy(sv, true)
			end
		end
	end

	return (tbl :: any) :: S & T
end

return TableUtils
