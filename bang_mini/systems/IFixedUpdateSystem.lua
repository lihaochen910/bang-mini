--------------------------------------------------------------------
---@class IFixedUpdateSystem : ISystem
--- A system called in fixed intervals.
CLASS: IFixedUpdateSystem( ISystem )
    :META {
        interface = true
    }

--- Update calls that will be called in fixed intervals.
function IFixedUpdateSystem:fixedUpdate( context )
end
