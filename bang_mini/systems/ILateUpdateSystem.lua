--------------------------------------------------------------------
---@class ILateUpdateSystem : ISystem
--- A system that consists of a single late_update call.
CLASS: ILateUpdateSystem( ISystem )
    :META {
        interface = true
    }

--- LateUpdate method. Called after Update method.
function ILateUpdateSystem:lateUpdate( context )
end
