--!strict
-- Per-player token bucket. `rate` tokens refill per second, up to `burst`.

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { Tokens: number, Last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { _rate: number, _burst: number, _buckets: { [Player]: Bucket } },
	RateLimiter
))

function RateLimiter.new(rate: number, burst: number): RateLimiter
	local self = setmetatable({ _rate = rate, _burst = burst, _buckets = {} }, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self._buckets[player] = nil
	end)
	return self
end

function RateLimiter.Check(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { Tokens = self._burst, Last = now }
		self._buckets[player] = bucket
	end
	bucket.Tokens = math.min(self._burst, bucket.Tokens + (now - bucket.Last) * self._rate)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

return RateLimiter
