--!strict
--!optimize 2

local Task = {}
local Threads = {} :: { thread }

--- Types

--[=[
   @within Task
   @interface Task
   .spawn (self, callback, ...) -> thread
   .defer (self, callback, ...) -> thread
   .delay (self, delay, callback, ...) -> thread
]=]
export type Task = {
	spawn: (self: Task, callback: (...any) -> (), ...any) -> thread,
	defer: (self: Task, callback: (...any) -> (), ...any) -> thread,
	delay: (self: Task, delay: number, callback: (...any) -> (), ...any) -> thread,
}

--[=[
    @within Task
    @interface staticTask
    @private
    .Call (callback, ...) -> ()
    .Thread () -> thread
]=]
type staticTask = {
	Call: (callback: (...any) -> (), ...any) -> (),
	Thread: () -> thread,
}

--[=[
    @within Task
    @private
]=]
type PrivateTask = Task & staticTask

--- Private Methods

--[=[
    @within Task
    @private
    @param callback (...) -> ()
    @param args ...

    It calls the provided callback with its arguments
    and registers the current thread for later reuse.

    Is used internally to recycle coroutines and reduce
    the unnecessary creation of new threads.
    
    ```lua
    local Task = require(path.to.Task)
    -- Assumes this function is always executed inside a coroutine.
    Task.Call(function(message)
        print(message) -- output: Hello, world!
    end, "Hello, world!")
    ```
]=]
function Task.Call(callback: (...any) -> (), ...)
	callback(...)
	table.insert(Threads, coroutine.running())
end

--[=[
    @within Task
    @private
    @return thread

	Main coroutine loop used internally for thread recycling.
	This yields until a function + args are passed in, which are 
	then executed through `Call`

    ```lua
    local Task = require(path.to.Task)
    --- Starts the internal coroutine loop (does not return)
    task.spawn(Task.Thread)
    ```
]=]
function Task.Thread(): thread
	while true do
		Task.Call(coroutine.yield())
	end
end

--- Public Methods

--[=[
    @within Task
    @param callback (...) -> ()
    @param args ...
    @return thread

    Call a callback in parallel using `task.spawn`.
    Reuse an available thread if one exists; otherwise, create a new one.

    ```lua
    local Task = require(path.to.Task)
    Task:spawn(function(a, b)
        local result = a + b
        print(result) --- output: 8
    end, 3, 5)
    ```
]=]
function Task.spawn(self: PrivateTask, callback: (...any) -> (), ...): thread
	return task.spawn(table.remove(Threads) or task.spawn(self.Thread), callback, ...)
end

--[=[
    @within Task
    @param callback (...) -> ()
    @param args ...
    @return thread

    Schedule a callback for the next cycle of the scheduler using `task.defer`.
    Ideal for executing logic after the current frame without blocking the main flow.

    ```lua
    local Task = require(path.to.Task)
    local bind = Instance.new "BindableEvent"
    bind:Fire()
    Task:defer(function()
        bind:Destroy()
    end)
    ```
]=]
function Task.defer(self: PrivateTask, callback: (...any) -> (), ...): thread
	return task.defer(table.remove(Threads) or task.spawn(self.Thread), callback, ...)
end

--[=[
    @within Task
    @param delay number
    @param callback (...) -> ()
    @param args ...
    @return thread

    Call the callback after a specified time in seconds.
    Use `task.delay` and reuse threads to minimize the 
    cost of creating coroutines.

    ```lua
    local Task = require(path.to.Task)
    Task:delay(3, function(character)
        character:MoveTo(vector3.new(0, 5, 0))
    end, (localCharacter.Character or localPlayer.CharacterAdded:Wait()))
    ```
]=]
function Task.delay(self: PrivateTask, delay: number, callback: (...any) -> (), ...): thread
	return task.delay(delay, table.remove(Threads) or task.spawn(self.Thread), callback, ...)
end

return (Task :: any) :: Task