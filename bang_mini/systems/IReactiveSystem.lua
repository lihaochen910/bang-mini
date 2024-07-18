--------------------------------------------------------------------
---@class IReactiveSystem : ISystem
--- A reactive system that reacts to changes of certain components.
CLASS: IReactiveSystem( ISystem )
    :META {
        interface = true
    }

--- This is called at the end of the frame for all entities that were added one of the target.
--- components.
--- This is not called if the entity died.
function IReactiveSystem:onAdded( world, entities )
end

--- This is called at the end of the frame for all entities that removed one of the target.
--- components.
function IReactiveSystem:onRemoved( world, entities )
end

--- This is called at the end of the frame for all entities that modified one of the target.
--- components.
--- This is not called if the entity died.
function IReactiveSystem:onModified( world, entities )
end

--- [Optional] This is called when an entity gets enabled.
function IReactiveSystem:onActivated( world, entities )
end

--- [Optional] This is called when an entity gets disabled. Called if an entity was
--- previously disabled.
function IReactiveSystem:onDeactivated( world, entities )
end

--- [Optional]
function IReactiveSystem:onBeforeRemoving( world, entity, index )
end

--- [Optional]
function IReactiveSystem:onBeforeModifying( world, entity, index )
end
