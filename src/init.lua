--!strict

local Signal = require(script.Signal)
local Scope = require(script.Scope)
local Connection = require(script.Connection)

(Signal :: any).Scope = Scope
(Signal :: any).Connection = Connection

return Signal
