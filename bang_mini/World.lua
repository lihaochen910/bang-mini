--------------------------------------------------------------------
---@class World
-- World Usage
--[[
local world = World(
    {
        { SomeCuteSystem, true }, -- systemClass, isActive
        { 'AnotherSystem', false }, -- systemClassName, isActive
    }
)
]]
CLASS: World()

World.DIAGNOSTICS_MODE = true

-- Initialize the world!
---@param systems table List of systems and whether they are currently active in the world.
function World:__init( systems )
    assert( #systems > 0, 'Cannot create a world without any systems.' )
    
    --- The startup systems will be called the first time they are activated.
    --- We will keep the systems here even after they were deactivated.
    self._cachedEarlyStartupSystems = {}
    self._cachedStartupSystems = {}
    self._cachedExitSystems = {}
    
    self._cachedFixedExecuteSystems = {}
    self._cachedExecuteSystems = {}
    self._cachedLateExecuteSystems = {}
    
    -- This must be called by engine implementations of Bang to handle with rendering.
    self._cachedRenderSystems = {}
    
    -- Tracks down all the watchers id that require a notification operation.
    self._watchersTriggered = false

    -- Tracks down all the entities that received a message notification within the frame.
    self._entitiesTriggeredByMessage = false

    --- Tracks all registered systems across the world, regardless if they are active or not.
    --- Maps: System order id -> (IsActive, ContextId).
    self._systems = {}

    --- Used when fetching systems based on its unique identifier.
    --- Maps: System order id -> System instance.
    self._idToSystem = {}

    --- Maps: System type -> System id.
    self._typeToSystems = {}

    --- Set of systems that will be paused. See <see cref="IsPauseSystem(ISystem)"/> for more information.
    self._pauseSystems = {}

    --- Set of systems that will only be played once a pause occur.
    self._playOnPauseSystems = {}

    --- List of systems that will be resumed after a pause.
    --- These are the systems which were deactivated due to <see cref="Pause"/>.
    self._systemsToResume = {}

    --- List of <see cref="IStartupSystem"/> systems which were already initialized.
    --- We track this here rather than <see cref="_cachedStartupSystems"/> if a startup system
    --- happen to be deactivated.
    self._systemsInitialized = {}

    --- Maps all the context IDs with the context.
    --- We might add new ones if a system calls for a new context filter.
    self._contexts = {}

    --- Maps all the watcher IDs.
    --- Maps: Watcher Ids -> (Watcher, Systems that subscribe to this watcher).
    self._watchers = {}

    --- Maps all the messagers IDs.
    --- Maps: Messager Ids -> (Messager, Systems that subscribe to this messager).
    self._messagers = {}

    --- Cache all the unique contexts according to the component type.
    --- Maps: Component type index -> Context id.
    self._cacheUniqueContexts = {}

    --- Entities that exist within our world.
    --- TODO: Do we want some sort of object pooling here?
    --- Right now, if we remove entities, we will set the id to null.
    self._entities = {}

    --- Entities which have been temporarily deactivated in the world.
    self._deactivatedEntities = {}

    --- Entities that we will destroy within the world.
    self._pendingDestroyEntities = {}

    --- Systems which will be either activate or deactivated at the end of the frame.
    self._pendingActivateSystems = {}

    --- Entity count, used for generating the next id.
    self._nextEntityId = 0

    --- Whether the world has been queried to be on pause or not.
    --- See <see cref="Pause"/>.
    self._isPaused = false

    --- Whether the world is currently being exited, e.g. <see cref="Exit"/> was called.
    self._isExiting = false

    --- Map of all the components index across the world.
    self._componentsLookup = World.findLookupImplementation()

    --- This will map:
    ---  [System ID] => ([Notification => Entities], System)
    ---  This is so we can track any duplicate entities reported for watchers of multiple components.
    self._systemsToNotify = {}
    
    --- Same as <see cref="_systemsToNotify"/>, but ordered once the data is collected.
    self._orderedSystemsToNotify = {}
    
    --- This is used when DIAGNOSTICS_MODE is set to update reactive systems that were
    --- not triggered.
    self._reactiveTriggeredSystems = {}
    
    --- Reuse the same instance for ordering the notifications per system.
    self._orderedNotificationsPerSystem = {}

    self:initialize( systems )
end

function World:initialize( systems )
    local watchBuilder = {}
    local messageBuilder = {}

    for systemIndex, systemInfo in ipairs( systems ) do
        local systemT = systemInfo[ 1 ]
        local isActive = systemInfo[ 2 ]
        local systemClass
        if type( systemT ) == 'table' then
            systemClass = systemT
        elseif type( systemT ) == 'string' then
            systemClass = findClass( systemT )
        end

        local systemInstance = systemClass() -- ISystem ctor()

        local c = Context( self )
        c:initializeWithSystem( systemInstance )
        if self._contexts[ c:getId() ] then
            -- Grab the correct context reference when adding events to it.
            c = self._contexts[ c:getId() ]
        else
            self._contexts[ c:getId() ] = c
        end

        if World.isPlayOnPauseSystem( systemInstance ) then
            isActive = false
            table.insert( self._playOnPauseSystems, systemIndex )
        elseif World.isPauseSystem( systemInstance ) then
            table.insert( self._pauseSystems, systemIndex )
        end

        -- If this is a reactive system, get all the watch components.
        local componentWatchers = {}
        local componentWatchersMap = {}
        local watchers = self:_getWatchComponentsForSystem( systemInstance, c )
        if watchers then
            for _, watcher in ipairs( watchers ) do
                local watcherId = watcher:getId()

                -- Did we already created a watcher with the same id for another system?
                if not watchBuilder[ watcherId ] then
                    -- First time! You shall be allowed to access the context.
                    watcher:_subscribeToContext( c )
                    watchBuilder[ watcherId ] = {
                        watcher = watcher,
                        systems = {}
                    }
                end

                if isActive then
                    if not watchBuilder[ watcherId ].systems[ systemIndex ] then
                        watchBuilder[ watcherId ].systems[ systemIndex ] = systemInstance
                    end
                end

                if not componentWatchersMap[ watcherId ] then
                    table.insert( componentWatchers, watcherId )
                    componentWatchersMap[ watcherId ] = true
                end
            end
        end

        local messageWatcher
        local messager = self:_tryGetMessagerForSystem( systemInstance, c )
        if messager then
            local messagerId = messager:getId()
            if not messageBuilder[ messagerId ] then
                messager:_subscribeToContext( c )
                messageBuilder[ messagerId ] = {
                    messager = messager,
                    systems = {}
                }
            end

            if isActive then
                messageBuilder[ messagerId ].systems[ systemIndex ] = systemInstance
            end

            messageWatcher = messagerId
        end

        for watcherId, data in pairs( watchBuilder ) do
            self._watchers[ watcherId ] = data
        end

        for messagerId, data in pairs( messageBuilder ) do
            self._messagers[ messagerId ] = data
        end

        self._idToSystem[ systemIndex ] = systemInstance
        self._systems[ systemIndex ] = setmetatable(
            {
                contextId = c:getId(),
                watchers = componentWatchers,
                messager = messageWatcher,
                order = systemIndex,
                isActive = isActive,
                class = systemClass
            },
            { __mode = 'v' }
        )
    end

    for systemIndex, systemInstance in pairs( self._idToSystem ) do
        self._typeToSystems[ systemInstance:getClass() ] = systemIndex
    end

    for _, systemInfo in pairs( self._systems ) do
        if isSubclass( systemInfo.class, findClass( 'IEarlyStartupSystem' ) ) then
            table.insert( self._cachedEarlyStartupSystems, systemInfo )
        end
        if isSubclass( systemInfo.class, findClass( 'IStartupSystem' ) ) then
            table.insert( self._cachedStartupSystems, systemInfo )
        end
        if isSubclass( systemInfo.class, findClass( 'IExitSystem' ) ) then
            table.insert( self._cachedExitSystems, systemInfo )
        end
        if isSubclass( systemInfo.class, findClass( 'IFixedUpdateSystem' ) ) then
            table.insert( self._cachedFixedExecuteSystems, systemInfo )
        end
        if isSubclass( systemInfo.class, findClass( 'IUpdateSystem' ) ) then
            table.insert( self._cachedExecuteSystems, systemInfo )
        end
        if isSubclass( systemInfo.class, findClass( 'ILateUpdateSystem' ) ) then
            table.insert( self._cachedLateExecuteSystems, systemInfo )
        end
        if isSubclass( systemInfo.class, findClass( 'IRenderSystem' ) ) then
            table.insert( self._cachedRenderSystems, systemInfo )
        end
    end
end

function World:isAnyPendingWatchers()
    return self._watchersTriggered and #self._watchersTriggered > 0
end

function World:isPause()
    return self._isPaused
end

function World:isExiting()
    return self._isExiting
end

function World:getComponentsLookup()
    return self._componentsLookup
end

-- Add a new empty entity to the world. 
-- This will map the instance to the world.
-- Any components added after this entity has been created will be notified to any reactive systems.
function World:addEntity( components, id )
    components = components or {}
    local e = Entity( self, self:_checkEntityId( id ), components )
    self:_addEntity( e )
    return e
end

-- function World:addEntityWithId( id, components )
-- end

-- Add a single entity to the world. This will map the instance to the world.
-- Any components added after this entity has been created will be notified to any reactive systems.
---@param entity Entity
function World:_addEntity( entity )
    self._entities[ entity:getEntityId() ] = entity

    -- Track end of the entity lifetime.
    entity._onEntityDestroyed = entity._onEntityDestroyed + self:methodPointer( '_registerToRemove' )
    
    for _, context in pairs( self._contexts ) do
        context:_filterEntity( entity )
    end

    return self
end

-- This will take <paramref name="id"/> and provide an entity id
-- that has not been used by any other entity in the world.
function World:_checkEntityId( id )
    if id and self._entities[ id ] then
        id = 0 -- default id
    end

    if not id then
        -- Look for the next id available.
        id = self._nextEntityId
        self._nextEntityId = self._nextEntityId + 1

        while self._entities[ id ] or self._deactivatedEntities[ id ] do
            id = self._nextEntityId
            self._nextEntityId = self._nextEntityId + 1
        end

        return id
    end

    return id
end

-- Register that an entity must be removed in the end of the frame.
function World:_registerToRemove( id )
    table.insert( self._pendingDestroyEntities, id )
end

-- Destroy all the pending entities within the frame.
function World:_destroyPendingEntities( id )
    if #self._pendingDestroyEntities == 0 then
        return
    end

    for id in ipairs( self._pendingDestroyEntities ) do
        self:_removeEntity( id )
    end

    -- clear
    for i = 1, #self._pendingDestroyEntities do
         t[ i ] = nil
    end
end

-- Removes an entity with <paramref name="id"/> from the world.
function World:_activateOrDeactivatePendingSystems( id )
    if table.len( self._pendingActivateSystems ) == 0 then
        return
    end

    for id, activate in pairs( self._pendingActivateSystems ) do
        if activate then
            self:activateSystem( id, true )
        else
            self:deactivateSystem( id, true )
        end
    end

    -- clear
    for i = 1, #self._pendingDestroyEntities do
        self._pendingDestroyEntities[ i ] = nil
    end
end

-- Removes an entity with <paramref name="id"/> from the world.
function World:_removeEntity( id )
    if self._deactivatedEntities[ id ] then
        self._deactivatedEntities[ id ]:dispose()
        self._entities[ id ] = nil
        return
    end
    
    assert( not self._entities[ id ], 'Why are we removing an entity that has never been added?' )

    self._entities[ id ]:dispose()
    self._entities[ id ] = nil
end

-- Activates an entity in the world.
-- Only called by an <see cref="Entity"/>.
function World:_activateEntity( id )
    local e = self._deactivatedEntities[ id ]
    if e then
        self._entities[ id ] = e
        self._deactivatedEntities[ id ] = nil

        assert( not e:isDeactivated(), 'Entity {id} should have been activated when calling this.' )
        return true
    end

    return false
end

-- Deactivate an entity in the world.
-- Only called by an <see cref="Entity"/>.
function World:_deactivateEntity( id )
    local e = self._entities[ id ]
    if e then
        self._deactivatedEntities[ id ] = e
        self._entities[ id ] = nil

        assert( e:isDeactivated(), 'Entity {id} should have been deactivated when calling this.' )
        return true
    end

    return false
end

-- Get an entity with the specific id.
function World:getEntity( id )
    if self._deactivatedEntities[ id ] then
        -- We consider looking up deactivated entities for this call.
        return self._deactivatedEntities[ id ]
    end

    assert( self._entities[ id ], 'Expected to have entity with id: {id}.' )

    return self._entities[ id ]
end

-- Tries to get an entity with the specific id.
-- If the entity is no longer among us, return null.
function World:tryGetEntity( id )
    if self._entities[ id ] then
        return self._entities[ id ]
    end

    if self._deactivatedEntities[ id ] then
        return self._deactivatedEntities[ id ]
    end
end

-- This should be used very cautiously! I hope you know what you are doing.
-- It fetches all the entities within the world and return them.
function World:getAllEntities()
    local allEntities = {}
    for _, e in pairs( self._entities ) do
        table.insert( allEntities, e )
    end
    for _, e in pairs( self._deactivatedEntities ) do
        table.insert( allEntities, e )
    end
    return allEntities
end

-- Total of entities in the world. This is useful for displaying debug information.
function World:getEntityCount()
    return table.len( self._entities )
end

-- Whether a system is active within the world.
function World:isSystemActive( systemType )
    local systemId = self._typeToSystems[ systemType ]
    if not systemId then
        -- Most likely the system is simply not available.
        return false
    end

    return self._systems[ systemId ]:isActive()
end

-- Activate a system within our world.
function World:activateSystem( systemType, immediately )
    local systemId = self._typeToSystems[ systemType ]
    if not systemId then
        -- Most likely the system is simply not available.
        return false
    end

    if self._pendingActivateSystems[ systemId ] then
        local active = self._pendingActivateSystems[ systemId ]
        if active then
            -- System *will be* activated.
            return false
        end
    elseif self._systems[ systemId ].isActive then
        return false
    end

    if not immediately then
        self._pendingActivateSystems[ systemId ] = true
        return true
    end

    self._systems[ systemId ].isActive = true

    local system = self._idToSystem[ systemId ]
    local systemInfo = self._systems[ systemId ]
    local context = systemInfo.contextId
    local systemClass = systemInfo.class

    -- First, let the system know that it has been activated.
    if isSubclass( systemClass, findClass( 'IActivateAndDeactivateListenerSystem' ) ) then
        system:onActivated( self._contexts[ context ] )
    end

    if isSubclass( systemClass, findClass( 'IStartupSystem' ) ) then
        table.insert( self._cachedStartupSystems, systemInfo )

        if not self._systemsInitialized[ systemId ] then
            -- System has never started before. Start them here!
            system:start( self._contexts[ context ] )
            self._systemsInitialized[ systemId ] = true
        end
    end

    if isSubclass( systemClass, findClass( 'IUpdateSystem' ) ) then
        table.insert( self._cachedExecuteSystems, systemInfo )
    end
    if isSubclass( systemClass, findClass( 'ILateUpdateSystem' ) ) then
        table.insert( self._cachedLateExecuteSystems, systemInfo )
    end
    if isSubclass( systemClass, findClass( 'IFixedUpdateSystem' ) ) then
        table.insert( self._cachedFixedExecuteSystems, systemInfo )
    end
    if isSubclass( systemClass, findClass( 'IRenderSystem' ) ) then
        table.insert( self._cachedRenderSystems, systemInfo )
    end
    if isSubclass( systemClass, findClass( 'IExitSystem' ) ) then
        table.insert( self._cachedExitSystems, systemInfo )
    end
    if isSubclass( systemClass, findClass( 'IReactiveSystem' ) ) then
        for _, watcherId in ipairs( systemInfo.watchers ) do
            self._watchers[ watcherId ].systems[ systemId ] = system
        end
    end
    if isSubclass( systemClass, findClass( 'IMessagerSystem' ) ) then
        local messagerId = systemInfo.messager
        self._messagers[ messagerId ].systems[ systemId ] = system
    end

    return true
end

-- Deactivate a system within our world.
function World:deactivateSystem( systemType, immediately )
    local systemId = self._typeToSystems[ systemType ]
    if not systemId then
        -- Most likely the system is simply not available.
        return false
    end

    if self._pendingActivateSystems[ systemId ] then
        local active = self._pendingActivateSystems[ systemId ]
        if not active then
            -- System *will be* deactivated.
            return false
        end
    elseif not self._systems[ systemId ].isActive then
        -- System was already deactivated.
        return false
    end

    if not immediately then
        self._pendingActivateSystems[ systemId ] = false
        return true
    end

    self._systems[ systemId ].isActive = false

    local system = self._idToSystem[ systemId ]
    local systemInfo = self._systems[ systemId ]
    local contextId = systemInfo.contextId
    local systemClass = systemInfo.class

    -- Let the system know that it has been deactivated.
    if isSubclass( systemClass, findClass( 'IActivateAndDeactivateListenerSystem' ) ) then
        system:onDeactivated( self._contexts[ contextId ] )
    end

    -- table.remove( t, table.index( t, day ) )
    if isSubclass( systemClass, findClass( 'IStartupSystem' ) ) then
        table.remove( self._cachedStartupSystems, table.index( self._cachedStartupSystems, systemId ) )
    end
    if isSubclass( systemClass, findClass( 'IUpdateSystem' ) ) then
        table.remove( self._cachedExecuteSystems, table.index( self._cachedExecuteSystems, systemId ) )
    end
    if isSubclass( systemClass, findClass( 'ILateUpdateSystem' ) ) then
        table.remove( self._cachedLateExecuteSystems, table.index( self._cachedLateExecuteSystems, systemId ) )
    end
    if isSubclass( systemClass, findClass( 'IFixedUpdateSystem' ) ) then
        table.remove( self._cachedFixedExecuteSystems, table.index( self._cachedFixedExecuteSystems, systemId ) )
    end
    if isSubclass( systemClass, findClass( 'IRenderSystem' ) ) then
        table.remove( self._cachedRenderSystems, table.index( self._cachedRenderSystems, systemId ) )
    end
    if isSubclass( systemClass, findClass( 'IExitSystem' ) ) then
        table.remove( self._cachedExitSystems, table.index( self._cachedExitSystems, systemId ) )
    end
    if isSubclass( systemClass, findClass( 'IReactiveSystem' ) ) then
        for _, watcherId in ipairs( systemInfo.watchers ) do
            self._watchers[ watcherId ].systems[ systemId ] = nil
        end
    end
    if isSubclass( systemClass, findClass( 'IMessagerSystem' ) ) then
        local messagerId = systemInfo.messager
        self._messagers[ messagerId ].systems[ systemId ] = nil
    end

    return true
end

-- Pause all the set of systems that qualify in <see cref="IsPauseSystem"/>.
-- A paused system will no longer be called on any <see cref="Update"/> calls.
function World:pause()
    self._isPaused = true

    -- Start by activating all systems that wait for a pause.
    for id in ipairs( self._playOnPauseSystems ) do
        self:activateSystem( id )
    end

    for i = 1, #self._systemsToResume do
        self._systemsToResume[ i ] = nil
    end

    for id in ipairs( self._pauseSystems ) do
        if self._systems[ id ]:isActive() then
            table.insert( self._systemsToResume, id )
            self:deactivateSystem( id )
        end
    end
end

-- This will resume all paused systems.
function World:resume()
    self._isPaused = false

    for id in ipairs( self._systemsToResume ) do
        self:activateSystem( id )
    end

    for id in ipairs( self._playOnPauseSystems ) do
        if self._systems[ id ]:isActive() then
            table.insert( self._systemsToResume, id )
            self:deactivateSystem( id )
        end
    end
end

-- Activate all systems across the world.
-- TODO: Optimize?
function World:activateAllSystems()
    for _, systemInfo in pairs( self._systems ) do
        self:activateSystem( systemInfo.class )
    end
end

-- Deactivate all systems across the world.
---@param skip table
function World:deactivateAllSystems( skip )
    for id, systemInfo in pairs( self._systems ) do
        if not World.isSystemOfType( self._idToSystem[ id ], skip ) then
            self:deactivateSystem( systemInfo.class )
        end
    end
end

-- Returns whether a system inherits from a given type.
---@param types table
function World.isSystemOfType( system, types )
    for t in ipairs( types ) do
        if isSubclass( system:getClass(), t ) then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------
-- Call <see cref="GetUnique{T}(int)"/> from a generator instead.
function World:getUnique( componentType )
    return self:_getUnique( self._componentsLookup:id( componentType ) )
end

function World:_getUnique( componentIndex )
    local component = self:_tryGetUnique( componentIndex )
    if not component then
        error( "How do we not have a '{typeof(T).Name}' component within our world?" )
    end

    return component
end

-- Call <see cref="TryGetUnique{T}(int)"/> from a generator instead.
function World:tryGetUnique( componentType )
    return self:_tryGetUniqueEntity( self._componentsLookup:id( componentType ) )
end

-- Call <see cref="GetUniqueEntity{T}(int)"/> from a generator instead.
function World:getUniqueEntity( componentType )
    return self:_getUniqueEntity( self._componentsLookup:id( componentType ) )
end

function World:_getUniqueEntity( componentIndex )
    local e = self:_tryGetUniqueEntity( componentIndex )
    if not e then
        error( "How do we not have the unique component of type '{typeof(T).Name}' within our world?" )
    end

    return e
end

-- Call <see cref="TryGetUniqueEntity{T}(int)"/> from a generator instead.
function World:tryGetUniqueEntity( componentType )
    return self:_tryGetUniqueEntity( self._componentsLookup:id( componentType ) )
end

function World:_tryGetUniqueEntity( componentIndex )
    local contextId = self._cacheUniqueContexts[ componentIndex ]
    if not contextId then
        -- Get the context for acquiring the unique component.
        contextId = self:_getOrCreateContext( ContextAccessorFilter.anyOf, { componentIndex } )

        self._cacheUniqueContexts[ componentIndex ] = contextId
    end

    local context = self._contexts[ contextId ]

    -- We expect more than one entity if the remaining ones have been destroyed

    if World.DIAGNOSTICS_MODE then
        local nonDestroyedCount = 0
        if #context:getEntities() > 1 then
            for _, entity in pairs( context:getEntities() ) do
                if not entity:isDestroyed() then
                    nonDestroyedCount = nonDestroyedCount + 1
                end
            end

            assert( nonDestroyedCount == 1, 'Why are there more than one entity with an unique component?' )
        end
    end

    local e = context:getLastOrDefaultEntity()
    if not e or e:isDestroyed() then
        return nil
    else
        return e
    end
end

-- Retrieve a context for the specified filter and components.
---@param componentTypes table
function World:getEntitiesWith( componentTypes )
    return self:_getEntitiesWith( ContextAccessorFilter.allOf, componentTypes )
end

function World:_getEntitiesWith( filter, componentTypes )
    local componentsIndices = {}
    for componentType in ipairs( componentTypes ) do
        table.insert( componentsIndices, self._componentsLookup:id( componentType ) )
    end

    local id = self:_getOrCreateContext( filter, componentsIndices )
    return self._contexts[ id ]:getEntities()
end

-- Get or create a context id for the specified filter and components.
---@param filter ContextAccessorFilter
function World:_getOrCreateContext( filter, componentTypeIds )
    local index = Context.calculateContextId( filter, componentTypeIds )

    if self._contexts[ index ] then
        -- Context already exists within our cache. Just return the id.
        return index
    end

    -- Otherwise, we need to create a context for this.
    local context = Context( self, filter, componentTypeIds )
    context:initialize( filter, componentTypeIds )

    -- Otherwise, we need to introduce the context to the world! Filter each entity.
    for _, e in pairs( self._entities ) do
        context:_filterEntity( e )
    end

    for _, e in pairs( self._deactivatedEntities ) do
        context:_filterEntity( e )
    end

    -- Add new context to our cache.
    self._contexts[ context:getId() ] = context

    return context:getId()
end

-- This is very slow. It should get both the activate an deactivate entities.
-- Used when it is absolutely necessary to get both activate and deactivated entities on the filtering.
function World:getActivatedAndDeactivatedEntitiesWith( components )
    -- TODO:

end

--------------------------------------------------------------------
-- Call before create WorldAsset Entity Instances
-- World::ctor() -> EarlyStart -> CreateAllEntitiesFromAsset(optional) -> Start(first Update call)
function World:earlyStart()
    for _, systemInfo in ipairs( self._cachedEarlyStartupSystems ) do
        local systemInstance = self._idToSystem[ systemInfo.order ]
        systemInstance:earlyStart( self._contexts[ systemInfo.contextId ] )
    end
end

-- Call start on all systems.
-- This is called before any updates and will notify any reactive systems by the end of it.
function World:start()
    for _, systemInfo in ipairs( self._cachedStartupSystems ) do
        local systemInstance = self._idToSystem[ systemInfo.order ]
        systemInstance:start( self._contexts[ systemInfo.contextId ] )

        -- Track that this system has been started (only once).
        self._systemsInitialized[ systemInfo.order ] = true
    end

    self:_notifyReactiveSystems()
    self:_destroyPendingEntities()
    self:_activateOrDeactivatePendingSystems()
end

-- Call to end all systems.
-- This is called right before shutting down or switching scenes.
function World:exit()
    for _, systemInfo in ipairs( self._cachedExitSystems ) do
        local systemInstance = self._idToSystem[ systemInfo.order ]
        systemInstance:exit( self._contexts[ systemInfo.contextId ] )
    end
end

-- Calls update on all <see cref="IUpdateSystem"/> systems.
-- At the end of update, it will notify all reactive systems of any changes made to entities
-- they were watching.
-- Finally, it destroys all pending entities and clear all messages.
function World:update()
    for _, systemInfo in ipairs( self._cachedExecuteSystems ) do
        local systemInstance = self._idToSystem[ systemInfo.order ]
        systemInstance:update( self._contexts[ systemInfo.contextId ] )
    end

    self:_notifyReactiveSystems()
    self:_destroyPendingEntities()
    self:_activateOrDeactivatePendingSystems()

    -- Clear the messages after the update so we can persist messages sent during Start().
    self:_clearMessages()
end

function World:lateUpdate()
    for _, systemInfo in ipairs( self._cachedLateExecuteSystems ) do
        local systemInstance = self._idToSystem[ systemInfo.order ]
        systemInstance:lateUpdate( self._contexts[ systemInfo.contextId ] )
    end
end

-- Calls update on all <see cref="IFixedUpdateSystem"/> systems.
-- This will be called on fixed intervals.
function World:fixedUpdate()
    for _, systemInfo in ipairs( self._cachedFixedExecuteSystems ) do
        local systemInstance = self._idToSystem[ systemInfo.order ]
        systemInstance:fixedUpdate( self._contexts[ systemInfo.contextId ] )
    end
end

--------------------------------------------------------------------
-- Notify all reactive systems of any change that happened during the update.
-- TODO_Perf: There's tons of garbage cleanup here. We should be able to optimize a lot of it at some point.
function World:_notifyReactiveSystems()
    local watchersTriggered = {}
    if not self._watchersTriggered then
        -- Nothing to notified, just go away.
        return
    end

    for _, v in ipairs( self._watchersTriggered ) do
        table.insert( watchersTriggered, v )
    end
    self._watchersTriggered = false

    for k, _ in pairs( self._systemsToNotify ) do
        self._systemsToNotify[ k ] = nil
    end
    for i, _ in ipairs( self._orderedSystemsToNotify ) do
        self._orderedSystemsToNotify[ i ] = nil
    end

    -- First, iterate over each watcher and clean up their notification queue.
    for _, watcherId in ipairs( watchersTriggered ) do
        local watcher = self._watchers[ watcherId ].watcher
        local systems = self._watchers[ watcherId ].systems
        local currentNotifications = watcher:popNotifications()

        -- Pass that notification for each system that it targets.
        for systemIndex, system in pairs( systems ) do
            -- Ok, if no previous systems had any notifications, that's easy, just add right away.
            local notificationsAndSystem = self._systemsToNotify[ systemIndex ]
            if notificationsAndSystem then
                -- Otherwise, things got tricky... Let us start by checking the notification kind.
                for kind, currentEntities in pairs( currentNotifications ) do
                    -- If the system did not have this notification previously, that's easy, just add right away then!
                    local entities = notificationsAndSystem.notifications[ kind ]
                    if entities then
                        -- Uh-oh, we got a conflicting notification kind. Merge them into the entities for the notification.
                        for entityId, entity in pairs( currentEntities ) do
                            entities[ entityId ] = entity
                        end
                    else
                        notificationsAndSystem.notifications[ kind ] = currentEntities
                    end
                end
            else
                self._systemsToNotify[ systemIndex ] = {
                    notifications = currentNotifications,
                    system = system,
                    systemId = systemIndex
                }
            end
        end
    end

    if World.DIAGNOSTICS_MODE then
        for i, _ in ipairs( self._reactiveTriggeredSystems ) do
            self._reactiveTriggeredSystems[ i ] = nil
        end
    end

    -- Now, iterate over each watcher and actually notify the systems based on their pending notifications.
    -- This must be done *afterwards* since the reactive systems may add further notifications on their implementation.
    for systemId, notificationsAndSystem in pairs( self._systemsToNotify ) do
        table.insert( self._orderedSystemsToNotify, notificationsAndSystem )
    end

    for _, notificationsAndSystem in ipairs( self._orderedSystemsToNotify ) do
        local systemId = notificationsAndSystem.systemId
        local system = notificationsAndSystem.system

        -- Make sure we make this in order. Some components are added *and* removed in the same frame.
        -- If this is the case, make sure we first call remove and *then* add.
        for kind, _ in pairs( self._orderedNotificationsPerSystem ) do
            self._orderedNotificationsPerSystem[ i ] = nil
        end

        for kind, entities in pairs( notificationsAndSystem.notifications ) do
            if table.len( entities ) ~= 0 then
                if kind == WatcherNotificationKind.added then
                    system:onAdded( self, entities )
                elseif kind == WatcherNotificationKind.removed then
                    system:onRemoved( self, entities )
                elseif kind == WatcherNotificationKind.modified then
                    system:onModified( self, entities )
                elseif kind == WatcherNotificationKind.enabled then
                    system:onActivated( self, entities )
                elseif kind == WatcherNotificationKind.disabled then
                    system:onDeactivated( self, entities )
                end
            else
                -- This might happen if all the entities were destroyed and no longer relevante to be passed on.
                -- Skip notifying in such cases.
            end
        end
    end

    -- If the reactive systems triggered other operations, trigger that again.
    if self:isAnyPendingWatchers() then
        self:_notifyReactiveSystems()
    end
end

-- This will clear any messages received by the entities within a frame.
function World:_clearMessages()
    local entitiesTriggered = {}
    if not self._entitiesTriggeredByMessage then
        return
    end

    for _, v in ipairs( self._entitiesTriggeredByMessage ) do
        table.insert( entitiesTriggered, v )
    end
    self._entitiesTriggeredByMessage = false

    for _, entityId in ipairs( entitiesTriggered ) do
        if self._entities[ entityId ] then
            -- This will make sure that the entity has not been deleted.
            self._entities[ entityId ]:_clearMessages()
        end
    end
end

function World:_queueWatcherNotification( watcherId )
    if not self._watchersTriggered then
        self._watchersTriggered = {}
        table.insert( self._watchersTriggered, watcherId )
    end
end

function World:_notifyComponentBeforeRemoving( watcherId, entity, index )
    local data = self._watchers[ watcherId ]
    for _, system in pairs( data.systems ) do
        system:onBeforeRemoving( self, entity, index )
    end
end

function World:_notifyComponentBeforeReplacing( watcherId, entity, index )
    local data = self._watchers[ watcherId ]
    for _, system in pairs( data.systems ) do
        system:onBeforeModifying( self, entity, index )
    end
end

-- Notify that a message has been received for a <paramref name="entity"/>.
function World:_onMessage( entity )
    table.insert( self._entitiesTriggeredByMessage, entity:getEntityId() )
end

-- Notify that a message has been received for a <paramref name="entity"/>.
-- This will notify all systems immediately and clear the message at the end of the update.
function World:_onMessageDetail( messagerId, entity, message )
    self:_onMessage( entity )

    -- Immediately notify all systems tied to this messager.
    for _, systems in pairs( self._messagers[ messagerId ].systems ) do
        for _, system in ipairs( systems ) do
            system:onMessage( self, entity, message )
        end
    end
end

function World:_getWatchComponentsForSystem( system, context )
    local systemClass = system:getClass()
    if not isSubclass( systemClass, findClass( 'IReactiveSystem' ) ) then
        print( 'Watch attribute for a non-reactive system. Attribute will be dropped.' )
        return
    end
    
    local watchAttr = systemClass.__meta.watcher
    if not watchAttr or not isSubclass( watchAttr:getClass(), findClass( 'WatchAttr' ) ) then
        error( 'invalid watcher define.' )
        return
    end

    local watchers = {}
    for _, t in ipairs( watchAttr:getTypes() ) do
        local tClass
        if type( t ) == 'string' then
            tClass = findClass( t )
        elseif type( t ) == 'table' then
            tClass = t
        end
        
        if tClass:isInterface() then
            local interfaceId = self._componentsLookup:id( tClass )
            for _, v in ipairs( self._componentsLookup:getAllComponentIndexUnderInterface( tClass ) ) do
                if v ~= interfaceId then
                    table.insert( watchers, ComponentWatcher( self, context:getId(), v ) )
                end
            end
        else
            table.insert( watchers, ComponentWatcher( self, context:getId(), tClass ) )
        end
    end
    return watchers
end

function World:_tryGetMessagerForSystem( system, context )
    if not isSubclass( system, findClass( 'IMessagerSystem' ) ) then
        return
    end

    local systemClass = system:getClass()
    local messagerAttr = systemClass.__meta.messager
    if not messagerAttr or isSubclass( messagerAttr:getClass(), findClass( 'MessagerAttr' ) ) then
        -- invalid
        return
    end

    return MessageWatcher( self, context:getId(), messagerAttr:getTypes() )
end

-- This will first call all <see cref="IExitSystem"/> to cleanup each system.
-- It will then call Dispose on each of the entities on the world and clear all the collections.
function World:dispose()
    if self._isExiting then
        return
    end

    self._isExiting = true

    self:exit()

    for _, e in pairs( self._entities ) do
        e:dispose()
    end

    for entityId, _ in pairs( self._entities ) do
        self._entities[ entityId ] = nil
    end

    for entityId, _ in pairs( self._deactivatedEntities ) do
        self._deactivatedEntities[ entityId ] = nil
    end

    for _, c in pairs( self._contexts ) do
        c:dispose()
    end

    for contextId, _ in pairs( self._contexts ) do
        self._contexts[ contextId ] = nil
    end
end

--------------------------------------------------------------------
-- Cache the lookup implementation for this game.
World._cachedLookupImplementation = false

-- Look for an implementation for the lookup table of components.
function World.findLookupImplementation()
    return ComponentsLookup()
end

-- Returns whether a system is eligible to be paused.
-- This means that:
--   - it is an update system;
--   - it does not have the DoNotPauseAttribute.
function World.isPauseSystem( system )
    local systemClass = system:getClass()
    if systemClass.__meta[ 'includeOnPause' ] then
        return true
    end
    
    if isSubclass( systemClass, findClass( 'IRenderSystem' ) ) then
        -- do not pause render systems.
        return false
    end

    if systemClass.__meta[ 'doNotPause' ] then
        return false
    end

    if not isSubclass( systemClass, findClass( 'IFixedUpdateSystem' ) ) and
        not isSubclass( systemClass, findClass( 'IUpdateSystem' ) ) and
        not isSubclass( systemClass, findClass( 'ILateUpdateSystem' ) ) then
        -- only pause update systems.
        return false
    end

    return true
end

-- Returns whether a system is only expect to play when the game is paused.
-- This is useful when defining systems that still track the game stack, even if paused.
function World.isPlayOnPauseSystem( system )
    local systemClass = system:getClass()
    return systemClass.__meta[ 'onPause' ]
end
