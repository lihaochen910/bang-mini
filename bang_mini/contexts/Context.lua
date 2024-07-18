--------------------------------------------------------------------
---@class Context : Observer
--- Context is the pool of entities accessed by each system that defined it.
CLASS: Context( Observer )

---@param world _world
function Context:__init( world )

    --- World that it observes.
    self._world = world
    
    --- List of entities that will be fed to the system of this context.
    self._entities = {}

    --- List of entities that are tracked, yet deactivated.
    self._deactivatedEntities = setmetatable( {}, { __mode = 'v' } )

    --- Cached value of the immutable set of entities.
    self._cachedEntities = {}

    --- Track the target components and what kind of filter should be performed for each.
    self._targetComponentsIndex = false

    --- Track the kind of operation the system will perform for each of the components.
    --- This is saved as a hash set since we will be using this to check if a certain component is set.
    self._componentsOperationKind = false

    --- This will be fired when a component is added to an entity present in the system.
    self._onComponentAddedForEntityInContext = MiniDelegate()

    -- This will be fired when a component is removed from an entity present in the system.
    self._onComponentRemovedForEntityInContext = MiniDelegate()

    -- This will be fired when a component before remove from an entity present in the system.
    self._onComponentBeforeRemovingForEntityInContext = MiniDelegate()

    -- This will be fired when a component is modified from an entity present in the system.
    self._onComponentModifiedForEntityInContext = MiniDelegate()

    -- This will be fired when a component is before modify from an entity present in the system.
    self._onComponentBeforeModifyingForEntityInContext = MiniDelegate()

    -- This will be fired when an entity (which was previously disabled) gets enabled.
    self._onActivateEntityInContext = MiniDelegate()

    -- This will be fired when an entity (which was previously enabled) gets disabled.
    self._onDeactivateEntityInContext = MiniDelegate()

    -- This will be fired when a message gets added in an entity present in the system.
    self._onMessageSentForEntityInContext = MiniDelegate()
end

function Context:initializeWithSystem( system )
    local filters = self:_createFilterList( system )
    self._targetComponentsIndex = self:_createTargetComponents( filters )
    self._componentsOperationKind = self:_createAccessorKindComponents( filters )

    self._id = self:_calculateId()
end

function Context:initialize( filter, components )
    self._targetComponentsIndex = {}
    self._targetComponentsIndex[ filter ] = components
    self._componentsOperationKind = {}

    self._id = self:_calculateId()
end

function Context:getReadComponents()
    return self._componentsOperationKind[ ContextAccessorKind.read ]
end

function Context:getWriteComponents()
    return self._componentsOperationKind[ ContextAccessorKind.write ]
end

function Context:getId()
    return self._id
end

function Context:getLookup()
    return self._world:getComponentsLookup()
end

function Context:isNoFilter()
    return self._targetComponentsIndex[ ContextAccessorFilter.none ] ~= nil
end

-- Entities that are currently active in the context.
function Context:getEntities()
    return self._entities
end

-- Get the single entity present in the context.
-- This assumes that the context targets a unique component.
-- TODO: Add flag that checks for unique components within this context.
function Context:getEntity()
    assert( #self._entities > 0 )
    return self._entities[ 1 ]
end

function Context:getLastOrDefaultEntity()
    return self._entities[ #self._entities ]
end

-- Whether the context has any entity active.
function Context:hasAnyEntity()
    return #self._entities > 0
end

-- This gets the context unique identifier.
-- This is important to get it right since it will be reused across different systems.
-- It assumes that we won't get more than 1000 components declared. If this changes (oh! hello!), maybe we should
-- reconsider this code.
function Context:_calculateId()
    local allComponents = {}
    
    -- Dictionaries by themselves do not guarantee any ordering.
    local targetComponentsIndexKeys = {}
    for k, _ in pairs( self._targetComponentsIndex ) do
        table.insert( targetComponentsIndexKeys, k )
    end
    table.sort( targetComponentsIndexKeys )

    for _, filter in ipairs( targetComponentsIndexKeys ) do
        local collection = self._targetComponentsIndex[ filter ]
        -- Add the filter identifier. This is negative so the hash can uniquely identify them.
        table.insert( allComponents, -filter )

        -- Sum one to the value so we are not ignoring 0-indexed components.
        table.sort( collection )
        for _, c in ipairs( collection ) do
            table.insert( allComponents, c + 1 )
        end
    end

    return HashExtensions.getHashCodeImpl( allComponents )
end

-- Perf: Calculate the context id. This is used to calculate whether it is necessary to create a new context
-- if there is already an existing one.
function Context.calculateContextId( filter, components )
    local allComponents = {}

    -- Add the filter identifier. This is negative so the hash can uniquely identify them.
    allComponents[ 1 ] = -filter
    table.sort( components )

    for i, _ in ipairs( components ) do
        -- Sum one to the value so we are not ignoring 0-indexed components.
        allComponents[ i + 1 ] = components[ i ] + 1
    end

    return HashExtensions.getHashCodeImpl( allComponents )
end

function Context:_createFilterList( system )
    local lookup = function( klass )
        if type( klass ) == 'string' then
            klass = findClass( klass )
        end
        if not klass:isInterface() then
            return { self:getLookup():id( klass ) }
        end
        local result = {}
        local allComponents = self:getLookup():getAllComponentIndexUnderInterface( klass )
        for _, v in ipairs( allComponents ) do
            table.insert( result, v[ 2 ] ) -- [1] componentClass, [2] componentId
        end
        return result
    end
    
    local systemClass = system:getClass()

    -- First, grab all the filters of the system.
    local filters = systemClass.__meta.filters
    local builder = {}
    
    -- Now, for each filter, populate our set of files.
    for _, filterAttr in ipairs( filters ) do
        
        local componentLookupIds = {}
        for _, t in ipairs( filterAttr:getTypes() ) do
            local lookupResult = lookup( t )
            for _, t2 in ipairs( lookupResult ) do
                table.insert( componentLookupIds, t2 )
            end
        end

        table.insert( builder, {
            filter = filterAttr,
            componentLookupIds = componentLookupIds
        } )
    end

    return builder
end

-- Create a list of which components we will be watching for when adding a new entity according to a
-- <see cref="ContextAccessorFilter"/>.
function Context:_createTargetComponents( filters )
    local builder = {}

    for _, filterData in ipairs( filters ) do
        local filterKind = filterData.filter:getFilter()
        -- Keep track of empty contexts.
        if filterKind == ContextAccessorFilter.none then
            builder[ filterKind ] = {}
            -- continue
        else
            if #filterData.componentLookupIds == 0 then
                -- No-op, this is so we can watch for the accessor kind.
                -- continue
            else
                -- We might have already added components for the filter for another particular kind of target,
                -- so check if it has already been added in a previous filter.
                if not builder[ filterKind ] then
                    builder[ filterKind ] = table.simplecopy( filterData.componentLookupIds )
                else
                    for _, c in ipairs( filterData.componentLookupIds ) do
                        table.insert( builder[ filterKind ], c )
                    end
                end
            end
        end
    end

    return builder
end

function Context:_createAccessorKindComponents( filters )  
    local builder = {}

    -- Initialize both fields as empty, if there is none.
    builder[ ContextAccessorKind.read ] = {}
    builder[ ContextAccessorKind.write ] = {}

    for _, filterData in ipairs( filters ) do
        
        if #filterData.componentLookupIds == 0 or filterData.filter:getFilter() == ContextAccessorFilter.noneOf then
            -- No-op, this will never be consumed by the system.
            -- continue
        else
            local kind = filterData.filter:getKind()
            if kind == ContextAccessorKind.write or
                kind == ContextAccessorKind.readwrite then
                -- If this is a read/write, just cache it as a write operation.
                -- Not sure if we can do anything with the information of a read...?
                kind = ContextAccessorKind.write
            end

            -- We might have already added components for the filter for another particular kind of target,
            -- so check if it has already been added in a previous filter.
            if #builder[ kind ] == 0 then
                builder[ kind ] = table.simplecopy( filterData.componentLookupIds )
            else
                for _, c in ipairs( filterData.componentLookupIds ) do
                    table.insert( builder[ kind ], c )
                end
            end
        end
    end

    return builder
end

-- Filter an entity for the first time in this context.
-- This is called when the entity is first created an set into the world.
function Context:_filterEntity( entity )
    if self:isNoFilter() then
        -- No entities are caught by this context.
        return
    end

    entity._onComponentAdded = entity._onComponentAdded + self:methodPointer( '_onEntityComponentAdded' )
    entity._onComponentRemoved = entity._onComponentRemoved + self:methodPointer( '_onEntityComponentRemoved' )

    if self:_doesEntityMatch( entity ) then
        entity._onComponentBeforeRemoving = entity._onComponentBeforeRemoving + self._onComponentBeforeRemovingForEntityInContext
        entity._onComponentRemoved = entity._onComponentRemoved + self._onComponentRemovedForEntityInContext
        entity._onComponentBeforeModifying = entity._onComponentBeforeModifying + self._onComponentBeforeModifyingForEntityInContext
        entity._onComponentModified = entity._onComponentModified + self._onComponentModifiedForEntityInContext
        
        entity._onMessage = entity._onMessage + self._onMessageSentForEntityInContext
        
        entity._onEntityActivated = entity._onEntityActivated + self:methodPointer( '_onEntityActivated' )
        entity._onEntityDeactivated = entity._onEntityDeactivated + self:methodPointer( '_onEntityDeactivated' )
        
        if not self._onComponentAddedForEntityInContext:isEmpty() then
            if not entity:isDeactivated() then
                -- TODO: Optimize this? We must notify all the reactive systems
                -- that the entity has been added.
                for _, componentId in ipairs( entity:getComponentIndices() ) do
                    self._onComponentAddedForEntityInContext( entity, componentId )
                end
            end

            entity._onComponentAdded = entity._onComponentAdded + self._onComponentAddedForEntityInContext
        end

        if not entity:isDeactivated() then
            self._entities[ entity:getEntityId() ] = entity
            self._cachedEntities = false
        end
    end
end

-- Returns whether the entity matches the filter for this context.
function Context:_doesEntityMatch( e )
    if self._targetComponentsIndex[ ContextAccessorFilter.noneOf ] then
        for _, componentId in ipairs( self._targetComponentsIndex[ ContextAccessorFilter.noneOf ] ) do
            if e:hasComponentOrMessage( componentId ) then
                return false
            end
        end
    end

    if self._targetComponentsIndex[ ContextAccessorFilter.allOf ] then
        for _, componentId in ipairs( self._targetComponentsIndex[ ContextAccessorFilter.allOf ] ) do
            if not e:hasComponentOrMessage( componentId ) then
                return false
            end
        end
    end

    if self._targetComponentsIndex[ ContextAccessorFilter.anyOf ] then
        for _, componentId in ipairs( self._targetComponentsIndex[ ContextAccessorFilter.anyOf ] ) do
            if e:hasComponentOrMessage( componentId ) then
                return true
            end
        end

        return false
    end

    return true
end

function Context:_onEntityComponentAdded( e, index )
    if e:isDestroyed() then
        return
    end

    self:_onEntityModified( e, index )
end

function Context:_onEntityComponentRemoved( e, index, causedByDestroy )
    if e:isDestroyed() then

        if not self:_isWatchingEntity( e:getEntityId() ) then
            return
        end

        if not self:_doesEntityMatch( e ) then
            -- The entity was just destroyed, don't bother filtering it.
            -- Destroy it immediately.
            self:_stopWatchingEntity( e, index, true )
        end

        return
    end

    self:_onEntityModified( e, index )
end

function Context:_onEntityComponentBeforeRemove( e, index, causedByDestroy )
end

function Context:_onEntityActivated( e )
    if not self._entities[ e:getEntityId() ] then
        self._entities[ e:getEntityId() ] = e
        self._cachedEntities = false

        self._onActivateEntityInContext( e )

        self._deactivatedEntities[ e:getEntityId() ] = nil
    end
end

function Context:_onEntityDeactivated( e )
    if self._entities[ e:getEntityId() ] then
        self._entities[ e:getEntityId() ] = nil
        self._cachedEntities = false

        self._onDeactivateEntityInContext( e )

        self._deactivatedEntities[ e:getEntityId() ] = e
    end
end

function Context:_onEntityModified( e, index )
    local isFiltered = self:_doesEntityMatch( e )
    local isWatchingEntity = self:_isWatchingEntity( e:getEntityId() )

    if not isWatchingEntity and isFiltered then
        self:_startWatchingEntity( e, index )
    elseif isWatchingEntity and not isFiltered then
        self:_stopWatchingEntity( e, index, false )
    end
end

function Context:_isWatchingEntity( entityId )
    return self._entities[ entityId ] ~= nil or self._deactivatedEntities[ entityId ] ~= nil
end

-- Tries to get a unique entity, if none is available, returns null
function Context:tryGetUniqueEntity()
    if table.len( self._entities ) == 1 then
        for _, e in pairs( self._entities ) do
            -- return first!
            return e
        end
    else
        return nil
    end
end

function Context:_startWatchingEntity( entity, index )
    -- Add any watchers from now on.
    entity._onComponentAdded = entity._onComponentAdded + self._onComponentAddedForEntityInContext
    entity._onComponentBeforeRemoving = entity._onComponentBeforeRemoving + self._onComponentBeforeRemovingForEntityInContext
    entity._onComponentRemoved = entity._onComponentRemoved + self._onComponentRemovedForEntityInContext
    entity._onComponentBeforeModifying = entity._onComponentBeforeModifying + self._onComponentBeforeModifyingForEntityInContext
    entity._onComponentModified = entity._onComponentModified + self._onComponentModifiedForEntityInContext
    
    entity._onMessage = entity._onMessage + self._onMessageSentForEntityInContext
    
    entity._onEntityActivated = entity._onEntityActivated + self:methodPointer( '_onEntityActivated' )
    entity._onEntityDeactivated = entity._onEntityDeactivated + self:methodPointer( '_onEntityDeactivated' )
    
    if not entity:isDeactivated() then
        -- Notify immediately of the new added component.
        self._onComponentAddedForEntityInContext( entity, index )

        self._entities[ entity:getEntityId() ] = entity
        self._cachedEntities = false
    else
        self._deactivatedEntities[ entity:getEntityId() ] = entity
    end
end

function Context:_stopWatchingEntity( entity, index, causedByDestroy )
    -- Remove any watchers.
    entity._onComponentAdded = entity._onComponentAdded - self._onComponentAddedForEntityInContext
    entity._onComponentBeforeRemoving = entity._onComponentBeforeRemoving - self._onComponentBeforeRemovingForEntityInContext
    entity._onComponentRemoved = entity._onComponentRemoved - self._onComponentRemovedForEntityInContext
    entity._onComponentBeforeModifying = entity._onComponentBeforeModifying - self._onComponentBeforeModifyingForEntityInContext
    entity._onComponentModified = entity._onComponentModified - self._onComponentModifiedForEntityInContext
    
    entity._onMessage = entity._onMessage - self._onMessageSentForEntityInContext
    
    entity._onEntityActivated = entity._onEntityActivated - self:methodPointer( '_onEntityActivated' )
    entity._onEntityDeactivated = entity._onEntityDeactivated - self:methodPointer( '_onEntityDeactivated' )

    if not entity:isDeactivated() then
        -- Notify immediately of the removed component.
        self._onComponentRemovedForEntityInContext( entity, index )
    else
        assert( not self._entities[ entity:getEntityId() ], 'Why is a deactivate entity is in the collection?' )
        self._deactivatedEntities[ entity:getEntityId() ] = nil
    end

    self._entities[ entity:getEntityId() ] = nil
    self._cachedEntities = false
end

function Context:dispose()
    self._onComponentAddedForEntityInContext:clear()
    self._onComponentAddedForEntityInContext = nil
    self._onComponentModifiedForEntityInContext:clear()
    self._onComponentModifiedForEntityInContext = nil
    self._onComponentRemovedForEntityInContext:clear()
    self._onComponentRemovedForEntityInContext = nil

    self._onActivateEntityInContext:clear()
    self._onActivateEntityInContext = nil
    self._onDeactivateEntityInContext:clear()
    self._onDeactivateEntityInContext = nil
    self._onMessageSentForEntityInContext:clear()
    self._onMessageSentForEntityInContext = nil

    self._entities = nil
end
