--------------------------------------------------------------------
---@class IActivateAndDeactivateListenerSystem : ISystem
--- This is used for tracking when the system gets manually activated and deactivated.
CLASS: IActivateAndDeactivateListenerSystem( ISystem )
    :META {
        interface = true
    }

--- Called once the system is activated. For now, this is not called on startup (should we?).
function IActivateAndDeactivateListenerSystem:onActivated( context )
end

--- Called once the system is deactivated.
function IActivateAndDeactivateListenerSystem:onDeactivated( context )
end
