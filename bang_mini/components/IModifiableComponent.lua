--------------------------------------------------------------------
---@class IModifiableComponent : IComponent
--- A special type of component that can be modified.
CLASS: IModifiableComponent( IComponent )
    :META {
        interface = true
    }

--- Subscribe to receive notifications when the component gets modified.
function IModifiableComponent:subscribe( notification )
    
end

--- Unsubscribe to stop receiving notifications when the component gets modified.
function IModifiableComponent:unsubscribe( notification )

end
