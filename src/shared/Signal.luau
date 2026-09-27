--!strict
-- Minimal typed signal. Handlers run in their own thread so one error can't break the caller.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { (T...) -> () } = {}

	local function connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		table.insert(handlers, handler)
		local function disconnect(_connection: Connection)
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
		return { Disconnect = disconnect }
	end

	local function fire(_self: Signal<T...>, ...: T...)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return { Connect = connect, Fire = fire }
end

return Signal
