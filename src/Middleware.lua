--!strict

local Middleware = {}

export type MiddlewareFn = (nextFn: (...any) -> (), ...any) -> ()
export type MiddlewareErrorHandler = (index: number, message: string) -> ()

function Middleware.run(
	chain: { MiddlewareFn },
	terminal: (...any) -> (),
	onError: MiddlewareErrorHandler?,
	...
)
	local function dispatch(index: number, ...)
		local middleware = chain[index]
		if middleware == nil then
			terminal(...)
			return
		end

		local nextCalled = false
		local function nextFn(...)
			if nextCalled then
				if onError ~= nil then
					onError(index, "next() was called more than once")
				end
				return
			end

			nextCalled = true
			dispatch(index + 1, ...)
		end

		local ok, err = pcall(middleware, nextFn, ...)
		if not ok then
			if onError ~= nil then
				onError(index, tostring(err))
			end
			dispatch(index + 1, ...)
		end
	end

	dispatch(1, ...)
end

return Middleware
