--!strict

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable({} :: {
	_signal: any,
	_fn: (...any) -> (),
	_priority: number,
	_connected: boolean,
	_once: boolean,
	_id: number,
	_tags: { [string]: boolean },
	_tagList: { string },
	_autoDisconnectConnections: { RBXScriptConnection },
	_source: string?,
	_line: number?,
}, Connection))

local function resolveDebugLocation(fn: (...any) -> ()): (string?, number?)
	local source: string? = nil
	local line: number? = nil

	local okSource, sourceResult = pcall(function()
		return debug.info(fn, "s")
	end)
	if okSource and type(sourceResult) == "string" then
		source = sourceResult
	end

	local okLine, lineResult = pcall(function()
		return debug.info(fn, "l")
	end)
	if okLine and type(lineResult) == "number" then
		line = lineResult
	end

	return source, line
end

function Connection.new(signal: any, fn: (...any) -> (), priority: number, once: boolean, id: number): Connection
	local source, line = resolveDebugLocation(fn)

	local self = setmetatable({
		_signal = signal,
		_fn = fn,
		_priority = priority,
		_connected = true,
		_once = once,
		_id = id,
		_tags = {},
		_tagList = {},
		_autoDisconnectConnections = {},
		_source = source,
		_line = line,
	}, Connection)

	return self
end

function Connection:IsConnected(): boolean
	return self._connected
end

function Connection:GetPriority(): number
	return self._priority
end

function Connection:GetTag(): string?
	return self._tagList[1]
end

function Connection:GetTags(): { string }
	local result = table.create(#self._tagList)
	for i, tag in ipairs(self._tagList) do
		result[i] = tag
	end
	return result
end

function Connection:HasTag(tag: string): boolean
	return self._tags[tag] == true
end

function Connection:Tag(tag: string): Connection
	assert(type(tag) == "string" and tag ~= "", "Connection:Tag(tag) expects a non-empty string")

	if not self._tags[tag] then
		self._tags[tag] = true
		table.insert(self._tagList, tag)
	end

	return self
end

local function disconnectAutoConnections(self: Connection)
	for _, rbxsConnection in ipairs(self._autoDisconnectConnections) do
		if rbxsConnection.Connected then
			rbxsConnection:Disconnect()
		end
	end
	table.clear(self._autoDisconnectConnections)
end

function Connection:AutoDisconnect(instance: Instance): Connection
	assert(typeof(instance) == "Instance", "Connection:AutoDisconnect(instance) expects a Roblox Instance")

	if not self._connected then
		return self
	end

	local autoConnection: RBXScriptConnection
	local destroyingSignal = (instance :: any).Destroying
	if typeof(destroyingSignal) == "RBXScriptSignal" then
		autoConnection = destroyingSignal:Connect(function()
			self:Disconnect()
		end)
	else
		autoConnection = instance.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:Disconnect()
			end
		end)
	end

	table.insert(self._autoDisconnectConnections, autoConnection)
	return self
end

function Connection:_cleanup()
	disconnectAutoConnections(self)
	table.clear(self._tags)
	table.clear(self._tagList)
end

function Connection:Disconnect()
	if not self._connected then
		return
	end

	self._connected = false
	self:_cleanup()

	local signal = self._signal
	self._signal = nil
	if signal ~= nil then
		signal:_removeConnection(self)
	end
end

return Connection
