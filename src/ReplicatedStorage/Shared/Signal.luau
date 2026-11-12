--!strict
-- Minimal signal. Unlike BindableEvent it passes tables by reference, and each handler runs in its own
-- thread so one erroring listener can't break the others.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = typeof(setmetatable({} :: { _handlers: { (...any) -> () } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	local handlers = self._handlers
	table.insert(handlers, handler)

	local connection = { Connected = true }
	function connection.Disconnect(this: any)
		if not this.Connected then
			return
		end
		this.Connected = false
		local index = table.find(handlers, handler)
		if index then
			table.remove(handlers, index)
		end
	end
	return connection :: any
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
