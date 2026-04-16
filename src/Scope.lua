--!strict

local Scope = {}
Scope.__index = Scope

export type Scope = typeof(setmetatable({} :: {
	_connections: { any },
	_destroyed: boolean,
}, Scope))

function Scope.new(): Scope
	return setmetatable({
		_connections = {},
		_destroyed = false,
	}, Scope)
end

function Scope:Track(connection: any): any
	assert(type(connection) == "table" and type(connection.Disconnect) == "function", "Scope:Track(connection) expects a connection-like table")

	if self._destroyed then
		connection:Disconnect()
		return connection
	end

	table.insert(self._connections, connection)
	return connection
end

function Scope:Connect(signal: any, fn: (...any) -> (), priorityOrOptions: any?): any
	assert(type(signal) == "table" and type(signal.Connect) == "function", "Scope:Connect(signal, fn) expects a Signal instance")

	local connection = signal:Connect(fn, priorityOrOptions)
	self:Track(connection)
	return connection
end

function Scope:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return Scope
