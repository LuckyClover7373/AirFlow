local Engine = require(script.Parent.Components.Engine)

local newPlane = Engine(workspace.Plane)
for i, v in pairs(workspace.Plane.Wings:GetChildren()) do
    newPlane:addAero(v)
end