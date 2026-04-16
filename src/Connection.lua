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
	_tags: { [string]: boolean }?,
	_tagList: { string }?,
	_autoDisconnectConnections: { RBXScriptConnection }?,
	_source: string?,
	_line: number?,
}, Connection))

function Connection.new(signal: any, fn: (...any) -> (), priority: number, once: boolean, id: number): Connection
	local self = setmetatable({
		_signal = signal,
		_fn = fn,
		_priority = priority,
		_connected = true,
		_once = once,
		_id = id,
		_tags = nil,
		_tagList = nil,
		_autoDisconnectConnections = nil,
		_source = nil,
		_line = nil,
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
	local tagList = self._tagList
	if tagList == nil then
		return nil
	end
	return tagList[1]
end

function Connection:GetTags(): { string }
	local tagList = self._tagList
	if tagList == nil then
		return {}
	end

	local result = table.create(#tagList)
	for i, tag in ipairs(tagList) do
		result[i] = tag
	end
	return result
end

function Connection:HasTag(tag: string): boolean
	local tags = self._tags
	return tags ~= nil and tags[tag] == true
end

function Connection:Tag(tag: string): Connection
	assert(type(tag) == "string" and tag ~= "", "Connection:Tag(tag) expects a non-empty string")

	local tags = self._tags
	local tagList = self._tagList
	if tags == nil then
		tags = {}
		tagList = {}
		self._tags = tags
		self._tagList = tagList
	end

	if not tags[tag] then
		tags[tag] = true
		table.insert(tagList :: { string }, tag)
	end

	return self
end

local function disconnectAutoConnections(self: Connection)
	local autoConnections = self._autoDisconnectConnections
	if autoConnections == nil then
		return
	end

	for _, rbxsConnection in ipairs(autoConnections) do
		if rbxsConnection.Connected then
			rbxsConnection:Disconnect()
		end
	end
	table.clear(autoConnections)
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

	local autoConnections = self._autoDisconnectConnections
	if autoConnections == nil then
		autoConnections = {}
		self._autoDisconnectConnections = autoConnections
	end
	table.insert(autoConnections, autoConnection)
	return self
end

function Connection:_cleanup()
	disconnectAutoConnections(self)

	local tags = self._tags
	if tags ~= nil then
		table.clear(tags)
	end

	local tagList = self._tagList
	if tagList ~= nil then
		table.clear(tagList)
	end
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
