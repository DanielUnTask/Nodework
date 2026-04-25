--!strict
--!optimize 2

local Packages = script.Parent

--- Requires
local Task = require(Packages.Task)

--- Internal error function used after signal destruction
local function MAKE_ERROR()
	error("Cannot fire a deleted signal", 2)
end

local error_signal = {
	Wait = MAKE_ERROR,
	Fire = MAKE_ERROR,
	Once = MAKE_ERROR,
	Connect = MAKE_ERROR,
	Destroy = MAKE_ERROR,
	DisconnectAll = MAKE_ERROR,
}

--- Types

--[=[
    @within Signal
    @private
    .Callback (T...) -> ()
]=]
type Callback<T... = ()> = (T...) -> ()

--[=[
    @within Signal
    @interface StaticSignal
    .proxy RBXScriptConnection?
    .next Connection
    previous Connection
]=]
type StaticSignal<T... = ()> = {
	Proxy: RBXScriptConnection?,
	Next: PrivateConnection<T...>,
	Previous: PrivateConnection<T...>,
}

--[=[
	@within Signal
	@interface StaticConnection	
	.Once boolean
	.Connected boolean
	.Thread thread
	.Function Callback<T...>
]=]
type StaticConnection<T... = ()> = {
	Once: boolean,
	Connected: boolean,
	Thread: thread,
	Function: Callback<T...>,
}

--[=[
    @within Signal
	@interface Identity
	.Wait (self) -> T...,
	.Fire (self, T...) -> (),
	.Once (self, Callback<T...>) -> Connection<T...>
	.Connect (self, Callback<T...>) -> Connection<T...>
	.DisconnectAll (self) -> ()
	.Destroy (self) -> ()
]=]
export type Identity<T... = ()> = {
	Wait: (self: Identity<T...>) -> T...,
	Fire: (self: Identity<T...>, T...) -> (),
	Once: (self: Identity<T...>, Callback<T...>) -> Connection<T...>,
	Connect: (self: Identity<T...>, Callback<T...>) -> Connection<T...>,
	DisconnectAll: (self: Identity<T...>) -> (),
	Destroy: (self: Identity<T...>) -> (),
}

--[=[
   @within Signal
   @interface Connection
   .DisconnectAll (self) -> ()
	.Destroy (self) -> ()
]=]
export type Connection<T... = ()> = {
	Disconnect: (self: Connection<T...>) -> (),
	Destroy: (self: Connection<T...>) -> (),
}

--[=[
    @within Signal
	@private
]=]
type PrivateSignal<T... = ()> = Identity<T...> & StaticSignal<T...>

--[=[
    @within Signal
	@private
]=]
type PrivateConnection<T... = ()> = Connection<T...> & StaticConnection<T...> & StaticSignal<T...>

--- Connection
local Connection = {}
Connection.__index = Connection

function Connection.Disconnect<T...>(self: PrivateConnection<T...>)
	if not self.Connected then
		return
	end
	self.Connected = false
	self.Previous.Next = self.Next
	self.Next.Previous = self.Previous
end

Connection.Destroy = Connection.Disconnect

--- Signal
local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Identity<T...>
	local self = setmetatable({}, Signal) :: any
	self.Previous = self :: any
	self.Next = self :: any
	return self :: Identity<T...>
end

function Signal.wrap<T...>(scriptSignal: RBXScriptSignal): Identity<T...>
	assert(
		typeof(scriptSignal) == "RBXScriptSignal",
		"Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(scriptSignal)
	)
	local signal = (Signal.new() :: any) :: PrivateSignal<T...>
	signal.Proxy = scriptSignal:Connect(function(...)
		signal:Fire(...)
	end)
	return (signal :: any) :: Identity<T...>
end

function Signal.Wait<T...>(self: PrivateSignal<T...>): T...
	local connection = (setmetatable({}, Connection) :: any) :: PrivateConnection<T...>
	connection.Previous = self.Previous
	connection.Next = self :: any
	connection.Once = true
	connection.Connected = true
	connection.Thread = coroutine.running()
	self.Previous.Next = connection
	self.Previous = connection
	return coroutine.yield()
end

function Signal.Fire<T...>(self: PrivateSignal, ...: T...)
	local connection = (self.Next :: any) :: PrivateConnection<T...>
	while connection ~= self :: any do
		local nextConnection = connection.Next :: PrivateConnection<T...>
		if connection.Connected then
			if connection.Function then
				Task:defer(connection.Function, ...)
			else
				task.spawn(connection.Thread, ...)
			end
			if connection.Once then
				connection:Disconnect()
			end
		end
		connection = nextConnection
	end
end

function Signal.Once<T...>(self: PrivateSignal<T...>, callback: Callback<T...>): Connection<T...>
	local connection = (setmetatable({}, Connection) :: any) :: PrivateConnection<T...>
	connection.Previous = self.Previous
	connection.Next = self :: any
	connection.Once = true
	connection.Connected = true
	connection.Function = callback
	self.Previous.Next = connection
	self.Next = connection
	return (connection :: any) :: Connection<T...>
end

function Signal.Connect<T...>(self: PrivateSignal<T...>, callback: Callback<T...>): Connection<T...>
	local connection = (setmetatable({}, Connection) :: any) :: PrivateConnection<T...>
	connection.Previous = self.Previous
	connection.Next = self :: any
	connection.Connected = true
	connection.Function = callback
	self.Previous.Next = connection
	self.Next = connection
	return (connection :: any) :: Connection<T...>
end

function Signal.DisconnectAll<T...>(self: PrivateSignal<T...>)
	local connection = (self.Next :: any) :: PrivateConnection<T...>
	while connection ~= (self :: any) do
		local nexConnection = connection.Next
		if connection.Connected then
			connection:Disconnect()
			if connection.Thread and coroutine.status(connection.Thread) == "suspended" then
				warn(debug.traceback(connection.Thread, "signal disconnected; yielded thread cancelled", 2))
				task.cancel(connection.Thread)
			end
		end
		connection = nexConnection
	end
end

function Signal.Destroy<T...>(self: PrivateSignal<T...>)
	self:DisconnectAll()
	local _proxy = self.Proxy :: RBXScriptConnection
	if _proxy and _proxy.Connected then
		task.defer(function()
			_proxy:Disconnect()
		end)
	end
	setmetatable(self, {
		__index = error_signal,
		__newindex = function()
			error("Attempt to modify a destroyed signal.", 2)
		end,
	})
end

return {
	new = Signal.new,
	wrap = Signal.wrap,
}
