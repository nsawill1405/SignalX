--!strict

local Connection = require(script.Parent.Connection)
local Middleware = require(script.Parent.Middleware)

type MiddlewareFn = Middleware.MiddlewareFn
type ConnectionType = Connection.Connection

export type ConnectOptions = {
	priority: number?,
	replay: boolean?,
	once: boolean?,
	tags: { string }?,
	autoDisconnect: Instance?,
}

export type SignalConfig = {
	name: string?,
	maxListeners: number?,
}

local DEFAULT_MAX_LISTENERS = 250
local DEFAULT_SIGNAL_NAME = "SignalX"

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: {
	_listeners: { ConnectionType },
	_middleware: { MiddlewareFn },
	_debug: boolean,
	_name: string,
	_listenerCount: number,
	_nextId: number,
	_needsSort: boolean,
	_isFiring: boolean,
	_pendingCompaction: boolean,
	_maxListeners: number,
	_warnedForMaxListeners: boolean,
	_lastArgs: any?,
	_hasLastFire: boolean,
}, Signal))

local function shallowCopy<T>(source: T): T
	local destination = {}
	for key, value in pairs(source :: any) do
		(destination :: any)[key] = value
	end
	return destination :: any
end

local function parseConnectOptions(priorityOrOptions: any?): (number, ConnectOptions)
	local priority = 0
	local options: ConnectOptions = {}

	if type(priorityOrOptions) == "number" then
		priority = priorityOrOptions
	elseif type(priorityOrOptions) == "table" then
		local raw = priorityOrOptions :: any
		if type(raw.priority) == "number" then
			priority = raw.priority
		end

		options.replay = raw.replay == true
		options.once = raw.once == true

		if type(raw.tags) == "table" then
			options.tags = raw.tags
		end
		if typeof(raw.autoDisconnect) == "Instance" then
			options.autoDisconnect = raw.autoDisconnect
		end
	end

	return priority, options
end

local function formatLocation(connection: ConnectionType): string
	local source = connection._source
	local line = connection._line

	-- We only resolve stack info when debug mode is used.
	if source == nil then
		local okSource, sourceResult = pcall(debug.info, connection._fn, "s")
		if okSource and type(sourceResult) == "string" then
			source = sourceResult
		else
			source = "<unknown>"
		end
		connection._source = source

		local okLine, lineResult = pcall(debug.info, connection._fn, "l")
		if okLine and type(lineResult) == "number" then
			line = lineResult
			connection._line = lineResult
		end
	end

	if source ~= nil and line ~= nil then
		return string.format("%s:%d", source, line)
	elseif source ~= nil then
		return source
	end

	return "<unknown>"
end

-- Fast-path small arg counts to avoid table.unpack in tight loops.
local function pcallWithPackedArgs(fn: (...any) -> (), packedArgs: any): (boolean, any)
	local n = packedArgs.n
	if n == 0 then
		return pcall(fn)
	elseif n == 1 then
		return pcall(fn, packedArgs[1])
	elseif n == 2 then
		return pcall(fn, packedArgs[1], packedArgs[2])
	elseif n == 3 then
		return pcall(fn, packedArgs[1], packedArgs[2], packedArgs[3])
	elseif n == 4 then
		return pcall(fn, packedArgs[1], packedArgs[2], packedArgs[3], packedArgs[4])
	end

	return pcall(fn, table.unpack(packedArgs, 1, n))
end

function Signal.new(config: (SignalConfig | string)?): Signal
	local name = DEFAULT_SIGNAL_NAME
	local maxListeners = DEFAULT_MAX_LISTENERS

	if type(config) == "string" then
		name = config
	elseif type(config) == "table" then
		local rawConfig = config :: SignalConfig
		if type(rawConfig.name) == "string" and rawConfig.name ~= "" then
			name = rawConfig.name
		end

		if type(rawConfig.maxListeners) == "number" and rawConfig.maxListeners > 0 then
			maxListeners = math.floor(rawConfig.maxListeners)
		end
	end

	local self = setmetatable({
		_listeners = {},
		_middleware = {},
		_debug = false,
		_name = name,
		_listenerCount = 0,
		_nextId = 1,
		_needsSort = false,
		_isFiring = false,
		_pendingCompaction = false,
		_maxListeners = maxListeners,
		_warnedForMaxListeners = false,
		_lastArgs = nil,
		_hasLastFire = false,
	}, Signal)

	return self
end

function Signal:_logDebug(message: string)
	if self._debug then
		print(string.format("[SignalX] %s", message))
	end
end

function Signal:_warnThresholdIfNeeded()
	if self._listenerCount > self._maxListeners and not self._warnedForMaxListeners then
		self._warnedForMaxListeners = true
		warn(string.format(
			"[SignalX] '%s' has %d listeners. Consider disconnecting stale listeners or raising maxListeners.",
			self._name,
			self._listenerCount
		))
	elseif self._listenerCount <= self._maxListeners then
		self._warnedForMaxListeners = false
	end
end

function Signal:_sortListenersIfNeeded()
	if not self._needsSort then
		return
	end

	table.sort(self._listeners, function(a: ConnectionType, b: ConnectionType)
		if a._priority == b._priority then
			return a._id < b._id
		end
		return a._priority > b._priority
	end)

	self._needsSort = false
end

function Signal:_compactListeners()
	local listeners = self._listeners
	local compacted = table.create(self._listenerCount)
	local writeIndex = 0

	for index = 1, #listeners do
		local connection = listeners[index]
		if connection._connected then
			writeIndex += 1
			compacted[writeIndex] = connection
		end
	end

	self._listeners = compacted
	self._listenerCount = writeIndex
	self._pendingCompaction = false
	self:_warnThresholdIfNeeded()
end

function Signal:_invokeConnection(connection: ConnectionType, packedArgs: any)
	if not connection._connected then
		return
	end

	if connection._once then
		connection:Disconnect()
	end

	local ok, err = pcallWithPackedArgs(connection._fn, packedArgs)
	if not ok then
		warn(string.format("[SignalX] Listener error in '%s': %s", self._name, tostring(err)))
	end
end

function Signal:_dispatchListeners(packedArgs: any)
	self:_sortListenersIfNeeded()

	if self._debug then
		self:_logDebug(string.format("Fired '%s' (%d listeners)", self._name, self._listenerCount))
	end

	self._isFiring = true
	local listeners = self._listeners
	local stopAt = #listeners

	for index = 1, stopAt do
		local connection = listeners[index]
		if connection ~= nil and connection._connected then
			if self._debug then
				self:_logDebug(string.format("-> %s", formatLocation(connection)))
			end
			self:_invokeConnection(connection, packedArgs)
		end
	end

	self._isFiring = false

	if self._pendingCompaction then
		self:_compactListeners()
	end
end

function Signal:_removeConnection(connection: ConnectionType)
	if self._isFiring then
		-- Removing in-place while iterating is expensive and bug-prone; compact after fire finishes.
		self._pendingCompaction = true
		self._listenerCount = math.max(0, self._listenerCount - 1)
		self:_warnThresholdIfNeeded()
		return
	end

	for index, current in ipairs(self._listeners) do
		if current == connection then
			table.remove(self._listeners, index)
			self._listenerCount = math.max(0, self._listenerCount - 1)
			break
		end
	end

	self:_warnThresholdIfNeeded()
end

function Signal:Connect(fn: (...any) -> (), priorityOrOptions: any?): ConnectionType
	assert(type(fn) == "function", "Signal:Connect(fn, priorityOrOptions) expects a function")

	local priority, options = parseConnectOptions(priorityOrOptions)
	local connection = Connection.new(self, fn, priority, options.once == true, self._nextId)
	self._nextId += 1

	table.insert(self._listeners, connection)
	self._listenerCount += 1
	self._needsSort = true
	self:_warnThresholdIfNeeded()

	if options.tags ~= nil then
		for _, tag in ipairs(options.tags) do
			if type(tag) == "string" and tag ~= "" then
				connection:Tag(tag)
			end
		end
	end

	if options.autoDisconnect ~= nil then
		connection:AutoDisconnect(options.autoDisconnect)
	end

	if options.replay == true and self._hasLastFire and self._lastArgs ~= nil then
		local replayArgs = self._lastArgs
		task.defer(function()
			if connection._connected then
				self:_invokeConnection(connection, replayArgs)
			end
		end)
	end

	return connection
end

function Signal:Once(fn: (...any) -> (), priorityOrOptions: any?): ConnectionType
	local options: any = {}
	if type(priorityOrOptions) == "number" then
		options.priority = priorityOrOptions
	elseif type(priorityOrOptions) == "table" then
		options = shallowCopy(priorityOrOptions)
	end
	options.once = true
	return self:Connect(fn, options)
end

function Signal:DisconnectAll()
	for _, connection in ipairs(self._listeners) do
		if connection._connected then
			connection._connected = false
			connection:_cleanup()
			connection._signal = nil
		end
	end

	table.clear(self._listeners)
	self._listenerCount = 0
	self._needsSort = false
	self._pendingCompaction = false
	self._warnedForMaxListeners = false
end

function Signal:DisconnectTag(tag: string)
	assert(type(tag) == "string" and tag ~= "", "Signal:DisconnectTag(tag) expects a non-empty string")

	for _, connection in ipairs(self._listeners) do
		if connection._connected and connection:HasTag(tag) then
			connection:Disconnect()
		end
	end
end

function Signal:Use(middlewareFn: MiddlewareFn): Signal
	assert(type(middlewareFn) == "function", "Signal:Use(middlewareFn) expects a middleware function")
	table.insert(self._middleware, middlewareFn)
	return self
end

function Signal:Fire(...)
	local packedArgs = table.pack(...)
	self._hasLastFire = true
	self._lastArgs = packedArgs

	if self._listenerCount == 0 and #self._middleware == 0 then
		return
	end

	if #self._middleware == 0 then
		self:_dispatchListeners(packedArgs)
		return
	end

	Middleware.run(
		self._middleware,
		function(...)
			self:_dispatchListeners(table.pack(...))
		end,
		function(index: number, message: string)
			warn(string.format("[SignalX] Middleware error in '%s' (index %d): %s", self._name, index, message))
		end,
		table.unpack(packedArgs, 1, packedArgs.n)
	)
end

function Signal:FireDeferred(...)
	local packedArgs = table.pack(...)
	task.defer(function()
		self:Fire(table.unpack(packedArgs, 1, packedArgs.n))
	end)
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	assert(thread ~= nil, "Signal:Wait() must be called from a running coroutine")

	local connection: ConnectionType?
	connection = self:Connect(function(...)
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
		task.spawn(thread :: thread, ...)
	end)

	return coroutine.yield()
end

function Signal:WaitAsync()
	local waiter = {
		_resolved = false,
		_canceled = false,
		_args = nil,
		_callbacks = {},
		_connection = nil,
	} :: any

	function waiter:andThen(callback: (...any) -> ())
		assert(type(callback) == "function", "Signal:WaitAsync():andThen(callback) expects a function")

		if self._canceled then
			return self
		end

		if self._resolved then
			local packed = self._args
			task.defer(callback, table.unpack(packed, 1, packed.n))
		else
			table.insert(self._callbacks, callback)
		end

		return self
	end

	function waiter:await()
		if self._resolved then
			local packed = self._args
			return table.unpack(packed, 1, packed.n)
		end

		local thread = coroutine.running()
		assert(thread ~= nil, "Signal:WaitAsync():await() must run inside a coroutine")

		self:andThen(function(...)
			task.spawn(thread :: thread, ...)
		end)

		return coroutine.yield()
	end

	function waiter:cancel()
		if self._canceled then
			return
		end

		self._canceled = true
		if self._connection ~= nil then
			self._connection:Disconnect()
			self._connection = nil
		end
		table.clear(self._callbacks)
	end

	local connection = self:Connect(function(...)
		if waiter._canceled then
			return
		end

		waiter._resolved = true
		waiter._args = table.pack(...)

		if waiter._connection ~= nil then
			waiter._connection:Disconnect()
			waiter._connection = nil
		end

		local callbacks = waiter._callbacks
		waiter._callbacks = {}
		for _, callback in ipairs(callbacks) do
			task.defer(callback, table.unpack(waiter._args, 1, waiter._args.n))
		end
	end)

	waiter._connection = connection
	return waiter
end

function Signal:EnableDebug(enabled: boolean?): Signal
	self._debug = enabled ~= false
	return self
end

function Signal:DisableDebug(): Signal
	self._debug = false
	return self
end

function Signal:SetName(name: string): Signal
	assert(type(name) == "string" and name ~= "", "Signal:SetName(name) expects a non-empty string")
	self._name = name
	return self
end

function Signal:SetMaxListeners(maxListeners: number): Signal
	assert(type(maxListeners) == "number" and maxListeners > 0, "Signal:SetMaxListeners(maxListeners) expects a positive number")
	self._maxListeners = math.floor(maxListeners)
	self:_warnThresholdIfNeeded()
	return self
end

function Signal:GetName(): string
	return self._name
end

function Signal:GetListenerCount(): number
	return self._listenerCount
end

return Signal
