![SignalX Logo](logo.png)

# SignalX

SignalX is an advanced event and messaging system for Roblox focused on developer experience, memory safety, and production debugging.

It improves on native signals by adding scoped cleanup, listener priorities, middleware, tags, replay-on-connect, and strong safety defaults.

## Overview

SignalX is designed as a structured messaging layer:

- Better API ergonomics for large codebases
- Automatic cleanup patterns to prevent leaks
- Built-in debug visibility
- Extensible middleware pipeline

Design priorities:

1. Developer experience
2. Safety
3. Debug visibility
4. Performance

## Features

- Priority listeners (`Connect(fn, 100)`)
- One-shot listeners (`Once`)
- Safe execution (`pcall` per listener)
- Middleware chain (`Use`)
- Tagged listeners and bulk disconnect (`DisconnectTag`)
- Scope-based cleanup (`Signal.Scope.new()`)
- Replay last payload on connect (`Connect(fn, { replay = true })`)
- Auto disconnect when instance is destroyed (`AutoDisconnect`)
- Deferred firing (`FireDeferred`)
- Listener warning threshold (`SetMaxListeners`)
- Debug logging (`EnableDebug`)

## Installation

Install with Wally:

```toml
[dependencies]
SignalX = "nsawill1405/signalx@0.1.0"
```

Then run:

```bash
wally install
```

Use in Roblox:

```lua
local Packages = game:GetService("ReplicatedStorage").Packages
local Signal = require(Packages.SignalX)
```

## Examples

### Basic usage

```lua
local Signal = require(Packages.SignalX)

local playerHit = Signal.new({ name = "PlayerHit" })
playerHit:Connect(function(player, damage)
	print(player.Name, damage)
end)

playerHit:Fire(game.Players:GetPlayers()[1], 15)
```

### Priority + once

```lua
local sig = Signal.new()

sig:Connect(function() print("Low") end, 0)
sig:Connect(function() print("High") end, 100)
sig:Once(function() print("Only once") end)

sig:Fire()
sig:Fire()
```

### Scope cleanup

```lua
local roundScope = Signal.Scope.new()
local roundEnded = Signal.new()

roundScope:Connect(roundEnded, function()
	print("Round ended")
end)

roundScope:Destroy() -- disconnects all tracked connections
```

### Middleware

```lua
local sig = Signal.new()

sig:Use(function(next, ...)
	print("Before")
	next(...)
	print("After")
end)

sig:Connect(function(message)
	print("Message:", message)
end)

sig:Fire("hello")
```

### Tagged listeners

```lua
local sig = Signal.new()

sig:Connect(function() end):Tag("UI")
sig:Connect(function() end):Tag("Combat")

sig:DisconnectTag("UI")
```

### Replay last fire

```lua
local sig = Signal.new()
sig:Fire("cached payload")

sig:Connect(function(value)
	print("Replayed:", value)
end, { replay = true })
```

## Benchmarks

SignalX includes an example benchmark script at:

- `examples/Benchmark.server.lua`

Benchmark guidance:

1. Run benchmark in an empty place.
2. Compare native `BindableEvent` and SignalX on your target device profile.
3. Measure connect cost, fire cost, and disconnect-all cost.

SignalX performance design choices:

- Array-based listener storage
- Dirty-sort only when needed
- Cached listener count
- Deferred compaction during active fire loops

## Why SignalX?

SignalX is not trying to be the largest feature set. It is focused on predictable, safe behavior in real Roblox projects where many systems communicate concurrently.

It gives teams a better default event layer by making cleanup easy, failures isolated, and runtime behavior observable.

## API Reference

### `Signal.new(config?)`

Create a signal.

- `config.name: string?`
- `config.maxListeners: number?`

### `signal:Connect(fn, priorityOrOptions?)`

Connect a listener.

- `priorityOrOptions` can be:
  - `number` (priority)
  - `{ priority, replay, once, tags, autoDisconnect }`

Returns a `Connection`.

### `signal:Once(fn, priorityOrOptions?)`

Connect and auto-disconnect after first execution.

### `signal:Fire(...args)`

Runs middleware and listeners immediately.

### `signal:FireDeferred(...args)`

Defers execution with `task.defer`.

### `signal:Wait()`

Yields current coroutine until next fire and returns payload.

### `signal:WaitAsync()`

Returns a wait handle with:

- `:andThen(callback)`
- `:await()`
- `:cancel()`

### `signal:DisconnectAll()`

Disconnect every listener.

### `signal:DisconnectTag(tag)`

Disconnect listeners that have `tag`.

### `signal:Use(middlewareFn)`

Add middleware (`function(next, ...args)`).

### `signal:EnableDebug(enabled?)`

Enable debug logging.

### `signal:SetName(name)`

Set signal display name in debug output.

### `signal:SetMaxListeners(count)`

Configure warning threshold for listener count.

### `signal:GetListenerCount()`

Returns the active listener count.

### `Connection`

- `connection:Disconnect()`
- `connection:Tag(tag)`
- `connection:HasTag(tag)`
- `connection:GetTag()`
- `connection:GetTags()`
- `connection:AutoDisconnect(instance)`
- `connection:IsConnected()`
- `connection:GetPriority()`

### `Scope`

- `local scope = Signal.Scope.new()`
- `scope:Track(connection)`
- `scope:Connect(signal, fn, priorityOrOptions?)`
- `scope:Destroy()`

## Testing

Scripts included:

- `test/Signal.unit.lua`
- `test/Signal.stress.lua`

The unit tests cover:

- Connect / Fire
- Once behavior
- Priority ordering
- Disconnect logic
- Scope cleanup
- Replay behavior

The stress test covers:

- 1000+ listeners
- Rapid fire loop
- Listener cleanup validation
