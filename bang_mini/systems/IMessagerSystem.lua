--------------------------------------------------------------------
---@class IMessagerSystem : ISystem
--- A reactive system that reacts to messages getting added to an entity.
CLASS: IMessagerSystem( ISystem )
    :META {
        interface = true
    }

--- Called once a message is fired from <paramref name="entity"/>.
function IMessagerSystem:onMessage( world, entity, message )
end
