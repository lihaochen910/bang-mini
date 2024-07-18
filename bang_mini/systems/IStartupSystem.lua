--------------------------------------------------------------------
---@class IStartupSystem : ISystem
--- A system only called once when the world starts.
CLASS: IStartupSystem( ISystem )
    :META {
        interface = true
    }

--- This is called before any <see cref="IUpdateSystem.Update(Context)"/> call.
function IStartupSystem:start( context )
end
