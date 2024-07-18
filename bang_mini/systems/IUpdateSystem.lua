--------------------------------------------------------------------
---@class IUpdateSystem : ISystem
--- A system that consists of a single update call.
CLASS: IUpdateSystem( ISystem )
    :META {
        interface = true
    }

--- Update method. Called once each frame.
function IUpdateSystem:update( context )
end
