--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.SignalX)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[SignalX Unit] " .. message, 2)
	end
end

local function runConnectFireTest()
	local sig = Signal.new()
	local hit = false

	sig:Connect(function(payload)
		hit = payload == "ok"
	end)

	sig:Fire("ok")
	expect(hit, "Connect/Fire should invoke listener")
end

local function runOnceTest()
	local sig = Signal.new()
	local calls = 0

	sig:Once(function()
		calls += 1
	end)

	sig:Fire()
	sig:Fire()
	expect(calls == 1, "Once should only execute one time")
end

local function runPriorityTest()
	local sig = Signal.new()
	local order = {}

	sig:Connect(function()
		table.insert(order, "low")
	end, 0)
	sig:Connect(function()
		table.insert(order, "high")
	end, 100)

	sig:Fire()
	expect(order[1] == "high" and order[2] == "low", "Priority should execute highest first")
end

local function runDisconnectTest()
	local sig = Signal.new()
	local calls = 0

	local connection = sig:Connect(function()
		calls += 1
	end)

	sig:Fire()
	connection:Disconnect()
	sig:Fire()
	expect(calls == 1, "Disconnected listener should not be called")
end

local function runScopeCleanupTest()
	local sig = Signal.new()
	local scope = Signal.Scope.new()
	local calls = 0

	scope:Connect(sig, function()
		calls += 1
	end)

	sig:Fire()
	scope:Destroy()
	sig:Fire()

	expect(calls == 1, "Scope:Destroy() should disconnect tracked listeners")
end

local function runReplayTest()
	local sig = Signal.new()
	local replayedValue = nil

	sig:Fire("cached")
	sig:Connect(function(value)
		replayedValue = value
	end, {
		replay = true,
	})

	task.wait()
	expect(replayedValue == "cached", "Replay should invoke new listener with last payload")
end

local function runTagTest()
	local sig = Signal.new()
	local uiCalls = 0
	local combatCalls = 0

	sig:Connect(function()
		uiCalls += 1
	end):Tag("UI")

	sig:Connect(function()
		combatCalls += 1
	end):Tag("Combat")

	sig:DisconnectTag("UI")
	sig:Fire()

	expect(uiCalls == 0, "DisconnectTag should remove matching listeners")
	expect(combatCalls == 1, "DisconnectTag should not remove non-matching listeners")
end

local function run()
	runConnectFireTest()
	runOnceTest()
	runPriorityTest()
	runDisconnectTest()
	runScopeCleanupTest()
	runReplayTest()
	runTagTest()
end

run()
print("[SignalX Unit] All tests passed")
