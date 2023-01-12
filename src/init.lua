local Class = require(script.Class)
local AirFlow = Class:create("AirFlow")

function AirFlow:constructor(super, body: Model)
	self.body = body
end

return AirFlow