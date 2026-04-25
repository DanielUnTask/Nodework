![Logo](/imgs/nodework.png)
A powerful game framework for the Roblox platform.

Nodework focuses on simple modular architecture while remaining lightweight and flexible.
Instead of enforcing a strict framework structure, Nodework gives you tools to build your own architecture using containers, lifecycles, and paths.

[Wally Package](https://wally.run/package/danieluntask/nodework?version=0.0.8)

# Getting Started
First, register a container and define the paths where modules should be loaded.
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nodework = require(ReplicatedStorage.Packages.Nodework)

Nodework:register("Services")

Nodework:addPath(
    "server/Services", -- ServerScriptService.Services
    { "PlayerService", "DataService" }, -- Priority
    { "AnyService" } -- Excluded modules
):to("Services")

Nodework.Services:ignite()
    :andThen(function(totalIndex: number, timestamp: number)
        print(`Services loaded in {timestamp}.`)
        print(`Total modules: {totalIndex}`)
    end)
    :catch(warn)
```
### When ignite() runs, will:
- Load all modules
- Execute lifecycle methods ("Init and Start")
- Make modules accessible

# Path
Nodework resolves folders using path prefixes that map.
### Available prefixes
```luau
local ACCEPTABLE_SERVICES = {
	SERVER = "ServerScriptService",
	CLIENT = "PlayerScripts",
	SHARED = "ReplicatedStorage",
	SERVERSTORAGE = "ServerStorage",
}
```
### Example
```lua
"server/pathToFolder"
"client/pathToFolder"
"shared/pathToFolder"
"serverstorage/pathToFolder"
```
### Deep Paths
You can reference nested folders.
```lua
"server/Source/Modules"
-- ServerScriptService.Source.Modules

"serverstorage/Source/Services"
-- ServerStorage.Source.Services

"shared/packages"
-- ReplicatedStorage.packages
```

# Lifecycle
Nodework modules can implement lifecycle methods that will be executed automatically.

### Default order:
- preInit (optional)
- init
- start

### Example module
```lua
local ExampleService = {}

function ExampleService:preInit() -- It runs before ignite
    print("Pre initialization")
end

function ExampleService:init()
    print("Initializing service")
end

function ExampleService:start()
    print("Service started")
end

return ExampleService
```

### Usage Example
```lua
local ServiceExample = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nodework = require(ReplicatedStorage.Packages.Nodework)

local Signal = Nodework.components("Signal", true)
local ComponentsList = Nodework.components()

function ServiceExample:start()
   local OtherService = Nodework.services("OtherService")
   OtherService:something()
end

function ServiceExample:init()
   print("Service initialized")
end

return ServiceExample
```

# Accessing Modules
After ignite() completes, modules can be retrieved from their container.

```lua
local PlayerService = Nodework.services("PlayerService")
PlayerService:CreatePlayer()
```

# Options
Nodework behavior can be customized with options.
```lua
local Options = {
    deep = true,  -- Scan all descendants for modules
	attempts = 3, 	-- Maximum attempts to load a module

    -- Optional filter to decide if a ModuleScript should be loaded
    predicate = function(moduleScript: ModuleScript)
        -- Only include modules whose name ends with "Service"
       return moduleScript.Name:match(Service$) ~= nil
    end

	import = {
		requireIgnite = false, -- Prevent requiring modules before ignite()
	},

	boot = {
		freeze = false, -- Freeze module tables after ignite
		preInit = false, -- Enable preInit lifecycle
	},

	lifecycle = {
		preInit = "preInit",
		init = "init",
		start = "start",
	},
}
```

# API
### register
Registers a new module container.
```lua
Nodework:register(containerName, options?)
```
Example:
```lua
Nodework:register("services", {
    deep = true
})
```
### addPath
Adds a path where Nodework will search for modules.
```lua
Nodework:addPath(path, priority?, exclude?)
```
Example:
```lua
Nodework:addPath("server/Services", { "PlayerService" }, { "TestService" })
```
- priority Modules to load first
- exclude Modules to ignore

### to
Assigns the path to a container.
```lua
Nodework:addPath("server/Services"):to("Services")
```

### ignite
Starts the loading process and runs lifecycle methods. (init & start)
```lua
Nodework.Services:ignite()
```
Returns a Promise.

### retrieving modules
Get a module from a container.
```lua
Nodework.Services("DataService")
```
Example:
```lua
local DataService = Nodework.services("DataService")
```