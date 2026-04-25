--!strict
local Logger = {}

local function messageConstructor(message: string, includeTraceback: boolean?, ...)
	local expandedMessage = string.format(message, ...)
	if includeTraceback then
		local traceback = debug.traceback(nil, 4)
		expandedMessage ..= `\n--- Stack Trace ---\n{traceback}`
	end
	return expandedMessage
end

function Logger.logError(message: string, includeTraceback: boolean?, ...)
	error(messageConstructor(message, includeTraceback, ...))
end

function Logger.logErrorNonFatal(message: string, includeTraceback: boolean?, ...)
	task.spawn(error, messageConstructor(message, includeTraceback, ...), 0)
end

function Logger.logWarn(message: string, includeTraceback: boolean?, ...)
	warn(messageConstructor(message, includeTraceback, ...))
end

function Logger.logInfo(message: string, includeTraceback: boolean?, ...)
	print(messageConstructor(message, includeTraceback, ...))
end

function Logger.assert(condition: boolean, message: string, includeTraceback: boolean?, ...)
	assert(condition, messageConstructor(message, includeTraceback, ...))
end

return Logger
