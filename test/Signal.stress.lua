--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.SignalX)

local LISTENER_COUNT = 2000
local FIRE_COUNT = 2000

local sig = Signal.new({
	name = "StressSignal",
	maxListeners = LISTENER_COUNT + 100,
})

local hits = 0

for _ = 1, LISTENER_COUNT do
	sig:Connect(function()
		hits += 1
	end)
end

for _ = 1, FIRE_COUNT do
	sig:Fire()
end

local expectedHits = LISTENER_COUNT * FIRE_COUNT
if hits ~= expectedHits then
	error(string.format("[SignalX Stress] hit mismatch expected=%d got=%d", expectedHits, hits))
end

sig:DisconnectAll()
if sig:GetListenerCount() ~= 0 then
	error("[SignalX Stress] listeners were not fully cleaned up")
end

print(string.format("[SignalX Stress] PASS listeners=%d fires=%d", LISTENER_COUNT, FIRE_COUNT))
