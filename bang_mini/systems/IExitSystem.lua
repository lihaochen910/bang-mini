--------------------------------------------------------------------
---@class IExitSystem : ISystem
--- A system called when the world is shutting down.
CLASS: IExitSystem( ISystem )
    :META {
        interface = true
    }

--- Called when everything is turning off (this is your last chance).
function IExitSystem:exit( context )
end
