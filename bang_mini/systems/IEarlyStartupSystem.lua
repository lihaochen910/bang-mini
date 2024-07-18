--------------------------------------------------------------------
---@class IEarlyStartupSystem : ISystem
--- A system only called once before the world starts.
CLASS: IEarlyStartupSystem( ISystem )
    :META {
        interface = true
    }

--- This is called before CreateAllEntities call.
function IEarlyStartupSystem:earlyStart( context )
end
