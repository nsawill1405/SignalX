--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.SignalX)

local LISTENER_COUNT = 1000
local FIRE_COUNT = 5000

local function benchmarkSignalX()
	local sig = Signal.new({ name = "Benchmark" })
	local sink = 0

	local connectStart = os.clock()
	for _ = 1, LISTENER_COUNT do
		sig:Connect(function(value)
			sink += value
		end)
	end
	local connectElapsed = os.clock() - connectStart

	local fireStart = os.clock()
	for _ = 1, FIRE_COUNT do
		sig:Fire(1)
	end
	local fireElapsed = os.clock() - fireStart

	local disconnectStart = os.clock()
	sig:DisconnectAll()
	local disconnectElapsed = os.clock() - disconnectStart

	return {
		connectSeconds = connectElapsed,
		fireSeconds = fireElapsed,
		disconnectSeconds = disconnectElapsed,
		sink = sink,
	}
end

local function benchmarkBindableEvent()
	local bindable = Instance.new("BindableEvent")
	local sink = 0
	local listenerConnections = table.create(LISTENER_COUNT)

	local connectStart = os.clock()
	for i = 1, LISTENER_COUNT do
		listenerConnections[i] = bindable.Event:Connect(function(value)
			sink += value
		end)
	end
	local connectElapsed = os.clock() - connectStart

	local fireStart = os.clock()
	for _ = 1, FIRE_COUNT do
		bindable:Fire(1)
	end
	local fireElapsed = os.clock() - fireStart

	local disconnectStart = os.clock()
	for _, connection in ipairs(listenerConnections) do
		connection:Disconnect()
	end
	local disconnectElapsed = os.clock() - disconnectStart

	bindable:Destroy()

	return {
		connectSeconds = connectElapsed,
		fireSeconds = fireElapsed,
		disconnectSeconds = disconnectElapsed,
		sink = sink,
	}
end

local signalXResult = benchmarkSignalX()
local bindableResult = benchmarkBindableEvent()

print(string.format("[SignalX Benchmark] listeners=%d fires=%d", LISTENER_COUNT, FIRE_COUNT))
print(string.format("SignalX   connect=%.6fs fire=%.6fs disconnect=%.6fs sink=%d", signalXResult.connectSeconds, signalXResult.fireSeconds, signalXResult.disconnectSeconds, signalXResult.sink))
print(string.format("Bindable  connect=%.6fs fire=%.6fs disconnect=%.6fs sink=%d", bindableResult.connectSeconds, bindableResult.fireSeconds, bindableResult.disconnectSeconds, bindableResult.sink))
