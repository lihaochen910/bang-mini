--------------------------------------------------------------------
---@class ComponentWatcher
--- A context may have a collection of watchers.
CLASS: ComponentWatcher()

-- A watcher will target a single component.
function ComponentWatcher:__init( world, contextId, targetComponent )
    self._world = world
    
    if type( targetComponent ) == 'table' then
        self._targetComponent = world:getComponentsLookup():id( targetComponent )
    elseif type( targetComponent ) == 'number' then
        self._targetComponent = targetComponent
    end

    self._id = HashExtensions.getHashCode( contextId, self._targetComponent )
    
    --- Tracks the total of entities to notify.
    --- This will make sure that, even if the same entity has an operation multiple times,
    --- it will only be passed on once per update.
    --- Maps:
    ---  [Notification kind -> [Entity id, Entity]]
    self._entitiesToNotify = false
end

function ComponentWatcher:getId()
    return self._id
end

-- Get the entities that will be notified.
-- This will immediately clear the notification list.
function ComponentWatcher:popNotifications()
    if self._entitiesToNotify then

        -- We will only filter entities that have not been destroyed or are being passed over to a 
        -- remove watch system.
        local result = {}
        for kind, dict in pairs( self._entitiesToNotify ) do
            result[ kind ] = {}
            
            for entityId, entity in pairs( dict ) do
                if not entity:isDestroyed() or kind == WatcherNotificationKind.removed then
                    result[ kind ][ entityId ] = entity
                end
            end
        end

        self._entitiesToNotify = false

        return result
    else
        error( 'Why are we getting the entities for an empty notification?' )
    end
end

function ComponentWatcher:_queueEntityNotification( kind, entity )
    if not self._entitiesToNotify then
        self._entitiesToNotify = {}
    end

    if not self._entitiesToNotify[ kind ] then
        self._entitiesToNotify[ kind ] = {}

        self._world:_queueWatcherNotification( self._id )
    end

    -- Only add each entity once to our notification list.
    if not self._entitiesToNotify[ kind ][ entity:getEntityId() ] then
        self._entitiesToNotify[ kind ][ entity:getEntityId() ] = entity
    end
end

function ComponentWatcher:_subscribeToContext( context )
    context._onComponentAddedForEntityInContext = context._onComponentAddedForEntityInContext + self:methodPointer( '_onEntityComponentAdded' )
    context._onComponentRemovedForEntityInContext = context._onComponentRemovedForEntityInContext + self:methodPointer( '_onEntityComponentRemoved' )
    context._onComponentBeforeRemovingForEntityInContext = context._onComponentBeforeRemovingForEntityInContext + self:methodPointer( '_onEntityComponentBeforeRemoving' )
    context._onComponentModifiedForEntityInContext = context._onComponentModifiedForEntityInContext + self:methodPointer( '_onEntityComponentReplaced' )
    context._onComponentBeforeModifyingForEntityInContext = context._onComponentBeforeModifyingForEntityInContext + self:methodPointer( '_onEntityComponentBeforeReplacing' )

    context._onActivateEntityInContext = context._onActivateEntityInContext + self:methodPointer( '_onEntityActivated' )
    context._onDeactivateEntityInContext = context._onDeactivateEntityInContext + self:methodPointer( '_onEntityDeactivated' )
end

function ComponentWatcher:_onEntityComponentAdded( e, index )
    if index ~= self._targetComponent then
        return
    end

    self:_queueEntityNotification( WatcherNotificationKind.added, e )
end

function ComponentWatcher:_onEntityComponentRemoved( e, index, causedByDestroy )
    if index ~= self._targetComponent then
        return
    end

    if e:isDestroyed() then
        -- entity has already been notified prior to this call.
        return
    end

    if self._entitiesToNotify and
        self._entitiesToNotify[ WatcherNotificationKind.added ] and
        self._entitiesToNotify[ WatcherNotificationKind.added ][ e:getEntityId() ] then
        -- This was previously added. But now it's removed! So let's clean up this list.
        -- We do this here because the order matters. If it was removed then added, we want to keep both.
        self._entitiesToNotify[ WatcherNotificationKind.added ][ e:getEntityId() ] = nil
    end

    self:_queueEntityNotification( WatcherNotificationKind.removed, e )
end

function ComponentWatcher:_onEntityComponentBeforeRemoving( e, index, causedByDestroy )
    if index ~= self._targetComponent then
        return
    end

    if e:isDestroyed() then
        -- entity has already been notified prior to this call.
        return
    end

    self._world:_notifyComponentBeforeRemoving( self._id, e, index )
end

function ComponentWatcher:_onEntityComponentReplaced( e, index )
    if index ~= self._targetComponent then
        return
    end

    self:_queueEntityNotification( WatcherNotificationKind.modified, e )
end

function ComponentWatcher:_onEntityComponentBeforeReplacing( e, index )
    if index ~= self._targetComponent then
        return
    end

    self._world:_notifyComponentBeforeReplacing( self._id, e, index )
end

function ComponentWatcher:_onEntityActivated( e )
    self:_queueEntityNotification( WatcherNotificationKind.enabled, e )
end

function ComponentWatcher:_onEntityDeactivated( e )
    if self._entitiesToNotify and
        self._entitiesToNotify[ WatcherNotificationKind.added ] and
        self._entitiesToNotify[ WatcherNotificationKind.added ][ e:getEntityId() ] then
        -- This entity was literally just added this frame. For such scenario, don't trigger Added *or* Deactivated.
        -- It was born into anonymity. Leave it that way.
        self._entitiesToNotify[ WatcherNotificationKind.added ][ e:getEntityId() ] = nil
        return
    end

    self:_queueEntityNotification( WatcherNotificationKind.disabled, e )
end

function ComponentWatcher:_onFinish()
    self._entitiesToNotify = nil
end
