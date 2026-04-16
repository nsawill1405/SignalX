--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.SignalX)

local demoSignal = Signal.new({
	name = "DemoSignal",
	maxListeners = 32,
})

demoSignal:EnableDebug()

demoSignal:Use(function(next, ...)
	print("[Middleware] before")
	next(...)
	print("[Middleware] after")
end)

demoSignal:Connect(function(message)
	print("[Priority 0]", message)
end, 0):Tag("Demo")

demoSignal:Connect(function(message)
	print("[Priority 100]", message)
end, 100)

demoSignal:Once(function()
	print("[Once] this prints only once")
end)

local roundScope = Signal.Scope.new()
roundScope:Connect(demoSignal, function(message)
	print("[Scope listener]", message)
end)

demoSignal:Fire("first fire")
demoSignal:Fire("second fire")

roundScope:Destroy() -- scope listener no longer receives events

demoSignal:Fire("after scope destroy")

demoSignal:DisconnectTag("Demo")
demoSignal:Fire("after DisconnectTag('Demo')")
