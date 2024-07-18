--------------------------------------------------------------------
---@class Observer
--- Base class for context. This shares implementation for any other class that decides to tweak
--- the observer behavior (which hasn't happened yet).
CLASS: Observer()

function Observer:__init( world )
    --- World that it observes.
    self._world = world

    --- Entities that are currently watched in the world.
    self._entities = {}
end

-- Unique id of the context. 
-- This is used when multiple systems share the same context.
function Observer:getId()
end


function Observer:getLookup()
    self._world:getComponentsLookup()
end

function Observer:getEntities()
    return self._entities
end

-- Filter an entity and observe any changes that happen to its components.
function Observer:_filterEntity( entity )
end

-- React to an entity that had some of its components added.
function Observer:_onEntityComponentAdded( e, index )
end

-- React to an entity that had some of its components removed.
function Observer:_onEntityComponentRemoved( e, index, causedByDestroy )
end

function Observer:_onEntityComponentBeforeRemove( e, index, causedByDestroy )
end
