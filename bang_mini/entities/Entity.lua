--------------------------------------------------------------------
---@class Entity
--- An entity is a collection of components within the world.
--- This supports hierarchy (parent, children).
CLASS: Entity()

function Entity:__init( world, id, components )
    assert( world )

    --- Fired whenever a new component is added.
    self._onComponentAdded = MiniDelegate()

    --- Fired whenever a new component is removed.
    --- This will send the entity, the component id that was just removed and
    --- whether this was caused by a destroy.
    self._onComponentRemoved = MiniDelegate()
    self._onComponentBeforeRemoving = MiniDelegate()

    --- Fired whenever any component is replaced.
    self._onComponentModified = MiniDelegate()
    self._onComponentBeforeModifying = MiniDelegate()

    --- Fired when the entity gets destroyed.
    self._onEntityDestroyed = MiniDelegate()

    --- Fired when the entity gets activated, so it gets filtered
    --- back in the context listeners.
    self._onEntityActivated = MiniDelegate()

    --- Fired when the entity gets deactivated, so it is filtered out
    --- from its context listeners.
    self._onEntityDeactivated = MiniDelegate()

    --- Notifies listeners when a particular component has been modified.
    self._trackedComponentsModified = MiniDelegate()

    --- Keeps track of callbacks from all the modifiable components.
    self._modifiableComponentsCallback = MiniDelegate()

    --- Entity unique identifier.
    self._entityId = id

    --- Components lookup. Unique per world that the entity was created.
    self._world = world

    self._lookup = world:getComponentsLookup()

    --- Whether this entity has been destroyed (and probably recycled) or not.
    self._isDestroyed = false

    --- Whether this entity has been deactivated or not.
    self._isDeactivated = false

    --- Maybe we want to expand this into various reasons an entity was deactivated?
    --- For now, track whether it was deactivated due to the parent.
    self._wasDeactivatedFromParent = false

    --- Keeps track of all the components that are currently present.
    ---     [ Component id => bool ]
    self._availableComponents = {}

    -- TODO: I guess this can be an array. Eventually.
    self._components = {}

    self._parent = false

    --- All the children tracked by the entity.
    --- Maps:
    ---   [Child id => Child name]
    self._children = false

    --- All the children tracked by the entity.
    --- Maps:
    ---   [Child name => Child id]
    self._childrenPerName = {}

    self._cachedChildren = false

    --- This will be fired when a message gets sent to the entity.
    self._onMessage = MiniDelegate()

    --- Track message components. This will be added within an update.
    self._messages = {}

    self:_initializeComponents( components )
end

function Entity:getEntityId()
    return self._entityId
end

function Entity:getComponentsLookup()
    return self._lookup
end

function Entity:isDeactivated()
    return self._isDeactivated
end

function Entity:isDestroyed()
    return self._isDestroyed
end

--- This is used for editor and serialization.
--- TODO: Optimize this. For now, this is okay since it's only used once the entity is serialized.
function Entity:getComponents()
    local result = {}
    for componentId, component in pairs( self._components ) do
        if self._availableComponents[ componentId ] then
            table.insert( result, component )
        end
    end
    return result
end

-- TODO: Optimize this. For now, this is okay since it's only used once the entity is initialized.
function Entity:getComponentIndices()
    local result = {}
    for componentId, component in pairs( self._components ) do
        if self._availableComponents[ componentId ] then
            table.insert( result, componentId )
        end
    end
    return result
end

--- Set an entity so it belongs to the world.
function Entity:_initializeComponents( components )
    -- Subscribe to each of the components that are modifiable and 
    -- register the component as available.
    for _, component in ipairs( components ) do
        local key = self._lookup:id( component:getClass() )

        -- TODO: IStateMachineComponent
        -- TODO: IModifiableComponent
        
        self:_addComponentInternal( component, component:getClass(), key )
    end

    if World.DIAGNOSTICS_MODE then
        self:_checkForRequiredComponents()
    end
end

--- This will check whether the entity has all the required components when set to the world.
function Entity:_checkForRequiredComponents()
    -- TODO:
end

--- Whether this entity has a component of type T.
function Entity:hasComponent( componentType )
    local componentLuaType = type( componentType )
    if componentLuaType == 'table' then
        return self:hasComponentWithIndex( self:getComponentIndex( componentType ) )
    elseif componentLuaType == 'string' then
        return self:hasComponentWithIndex( self:getComponentIndex( findClass( componentType ) ) )
    elseif componentLuaType == 'number' then
        return self:hasComponentWithIndex( componentType )
    end

    error( 'invalid arg: componentType for Entity:hasComponent( componentType )' )
end

function Entity:hasComponentWithIndex( componentId )
    return self._availableComponents[ componentId ] == true
end

--- Checks whether an entity has a data attached to -- component or message.
function Entity:hasComponentOrMessage( index )
    return self:hasComponentWithIndex( index ) or self:hasMessageWithIndex( index )
end

--- Try to get a component of type T. If none, returns false and null.
function Entity:tryGetComponent( componentType )
    if self:hasComponent( componentType ) then
        return self:getComponent( componentType )
    end
end

---  Fetch a component of type T. If the entity does not have that component, this method will assert and fail.
function Entity:getComponent( componentType )
    local componentIndex
    local t = type( componentType )
    if t == 'table' then
        componentIndex = self:getComponentIndex( componentType )
    elseif t == 'string' then
        componentIndex = self:getComponentIndex( findClass( componentType ) )
    elseif t == 'number' then
        componentIndex = componentType
    end
    
    assert( self:hasComponentWithIndex( componentIndex ), string.format( "The entity doesn't have a component of type '%s' with index: %d, maybe you should 'TryGetComponent'?", tostring( componentType ), componentIndex ) )
    return self._components[ componentIndex ]
end

--- Add an empty component only once to the entity.
function Entity:addComponentOnce( componentType )
    if not self._lookup or self:hasComponent( componentType ) then
        assert( self._lookup, 'Method not implemented for unitialized components.' )
        return false
    end

    local c = componentType()

    local index = self:getComponentIndex( componentType )
    self:addComponentWithIndex( c, index )
end

--- Add a component <paramref name="component"/> of type <paramref name="componentType"/>.
function Entity:addComponent( component )
    return self:addComponentWithIndex( component, self:getComponentIndex( component:getClass() ) )
end

function Entity:addComponentWithIndex( component, index )
    if self._isDestroyed then
        -- TODO: Assert? The entity has been destroyed, so it's a no-op.
        return false
    end

    if self:hasComponent( index ) then
        print( 'Why are we adding a component to an entity that already has one? Call ReplaceComponent(c) instead.' )
        return false
    end

    self:_addComponentInternal( component, component:getClass(), index )
    self:_notifyAndSubscribeOnComponentAdded( index, component )

    return true
end

--- Removes component of type <paramref name="t"/>.
--- Do nothing if <paramref name="componentType"/> is not owned by this entity.
function Entity:removeComponent( componentType )
    self:removeComponentWithIndex( self:getComponentIndex( componentType ) )
end

function Entity:removeComponentWithIndex( index )
    if not self:hasComponent( index ) then
        -- Redundant operation, just do a no-operation.
        return false
    end

    -- TODO: IModifiableComponent

    -- Check whether this removal will cause the entity to be destroyed.
    -- If no components are left, there is no use for this to exist.
    local destroyAfterRemove = table.len( self._components ) == 0 and not self._isDestroyed

    self._onComponentBeforeRemoving( self, index, destroyAfterRemove )

    self._components[ index ] = nil
    self._availableComponents[ index ] = false

    self._onComponentRemoved( self, index, destroyAfterRemove )
    if self._parent then
        self._parent:_untrackComponent( index, self._onParentModified )
    end

    if destroyAfterRemove then
        self:destroy()
    end

    return true
end

function Entity:replaceComponent( component, forceReplace )
    forceReplace = forceReplace or false
    self:replaceComponentWithIndex( component, self:getComponentIndex( component:getClass() ), forceReplace )
end

function Entity:replaceComponentWithIndex( component, index, forceReplace )
    if self._isDestroyed then
        -- TODO: Assert? The entity has been destroyed, so it's a no-op.
        return false;
    end

    if not self:hasComponentWithIndex( index ) then
        print( 'Why are we replacing a component to an entity that does not have one? Call AddComponent(c) instead.' )
        return false
    end

    -- component Equals
    -- TODO: i think that should be skip equals work in Lua
    --local existComponent = self:getComponent( index )
    --if not forceReplace and IComponent.equals( existComponent, component ) then
    --    -- Don't bother replacing if both components have the same value.
    --    return false
    --end

    -- If this is a modifiable component, unsubscribe from it before actually replacing it.
    -- TODO: IModifiableComponent

    self._onComponentBeforeModifying( self, index )
    self._components[ index ] = component

    -- TODO: IParentRelativeComponent

    self:_notifyOnComponentReplaced( index, component )
    return true
end

function Entity:addOrReplaceComponent( component )
    local index = self:getComponentIndex( component:getClass() )
    if self:hasComponentWithIndex( index ) then
        self:replaceComponentWithIndex( component, index )
    else
        self:addComponentWithIndex( component, index )
    end
end

function Entity:getComponentIndex( componentType )
    assert( self._lookup, 'Why are we modifying an entity without setting it to the world?' )
    return self._lookup:id( componentType )
end

--- This simply adds a component to our lookup table. This won't do anything fancy other than
--- booking it, if it happens to exceed the components length.
function Entity:_addComponentInternal( component, componentType, index )
    -- NOTE: i think dont need do that in Lua.
    -- if #self._availableComponents <= index then
    --     -- We might hit the scenario when a component that was not previously taken into account is added.
    --     -- This may happen for components not tracked by a generator, usually when there is a project that
    --     -- adds extra components. This shouldn't happen in the shipped engine, for example.

    --     -- Double the lookup size.

    -- end

    self._components[ index ] = component
    self._availableComponents[ index ] = true
end

--- When adding a component:
---   1. If this is a modifiable component, we must subscribe to the new component.
---   2. If this is a state machine component, start it up.
---   3. Notify subscribers that the component has been added.
---   4. If this is a component that relies on the parent, make sure we are
---      tracking the parent changes.
function Entity:_notifyAndSubscribeOnComponentAdded( index, component )
    assert( self._world )
    assert( self._lookup )

    -- TODO: IStateMachineComponent

    self._onComponentAdded( self, index )

    -- TODO: IsRelative

end

--- When changing a component:
---   1. If this is a modifiable component, we have replaced the component with a new object.
---      Make sure we subcribe to the new component.
---   2. If this is a state machine component, start it up.
---   3. Notify subscribers that the component has been modified.
---   4. Notify any children about the value change.
function Entity:_notifyOnComponentReplaced( index, component )
    assert( self._world )
    assert( self._lookup )

    -- TODO: IStateMachineComponent

    -- Now, notify all contexts that are observing this change.
    self._onComponentModified( self, index )

    -- Finally, notify any children who is listening to notifications.
    if self._trackedComponentsModified[ index ] then
        self._trackedComponentsModified[ index ]( index, component )
    end
end

function Entity:_getModifiableComponentCallback( index )
    if self._modifiableComponentsCallback[ index ] then
        return self._modifiableComponentsCallback[ index ]
    end

    local callback = function() self._onComponentModified( self, inedx ) end
    self._modifiableComponentsCallback[ index ] = callback

    return callback
end

function Entity:_removeOnComponentModifiable( index )
    if self._modifiableComponentsCallback[ index ] then
        local callback = self._modifiableComponentsCallback[ index ]
        self._modifiableComponentsCallback[ index ] = nil
        return callback
    end
end

--- Destroy the entity from the world.
--- This will notify all components that it will be removed from the entity.
--- At the end of the update of the frame, it will wipe this entity from the world.
--- However, if someone still holds reference to an <see cref="Entity"/> (they shouldn't),
--- they might see a zombie entity after this.
function Entity:destroy()
    for componentId, _ in pairs( self._components ) do
        self:_notifyRemovalOnDestroy( componentId )
    end

    self._isDestroyed = true

    self._onEntityDestroyed( self._entityId )
end

--- Replace all the components of the entity. This is useful when you want to reuse
--- the same entity id with new components.
---@param components table Components that will be placed in this entity.
---@param children table Children in the world that will now have this entity as a parent.
---@param wipe bool Whether we want to wipe all trace of the current entity, including *destroying its children*.
function Entity:replace( components, children, wipe )
    local replacedComponents = {}

    for componentId, component in pairs( self._components ) do
        local index = self:getComponentIndex( component:getClass() )
        replacedComponents[ index ] = true

        if self:hasComponent( index ) then
            self:replaceComponent( component, index, true )
        else
            self:addComponent( component, index )
        end
    end

    if wipe then
        for componentId, _ in pairs( self._components ) do
            if replacedComponents[ componentId ] then
                -- continue
            else
                -- TODO: Cache and optimize components that must be kept during r?
                -- As of today, a replace should happen so now and then that I will keep it like that for now.
                if self:hasComponent( componentId ) and
                    self._components[ componentId ]:getClass().__meta.keepOnReplace then
                    -- continue
                else
                    self:removeComponent( componentId )
                end
            end
        end
    end

    if wipe and self._children then
        local previousChildren = table.simplecopy( self._children )
        for _, c in ipairs( previousChildren ) do
            -- Crush and destroy the child dreams.
            self:removeChild( c )

            local e = self._world:getEntity( c )
            e:destroy()
        end
    end

    for entityId, entityName in pairs( self._children ) do
        self:addChild( entityId, entityName )
    end
end

--- Dispose the entity.
--- This will unparent and remove all components.
--- It also removes subscription from all their contexts or entities.
function Entity:dispose()
    self:unparent()

    for componentId, _ in pairs( self._components ) do
        self:removeComponent( componentId )
    end

    self._onComponentAdded:clear()
    self._onComponentAdded = nil
    self._onComponentModified:clear()
    self._onComponentModified = nil
    self._onComponentBeforeModifying:clear()
    self._onComponentBeforeModifying = nil
    self._onComponentRemoved:clear()
    self._onComponentRemoved = nil
    self._onComponentBeforeRemoving:clear()
    self._onComponentBeforeRemoving = nil

    self._onEntityDestroyed:clear()
    self._onEntityDestroyed = nil
    self._onEntityActivated:clear()
    self._onEntityActivated = nil
    self._onEntityDeactivated:clear()
    self._onEntityDeactivated = nil

    self._onMessage:clear()
    self._onMessage = nil

    self._trackedComponentsModified:clear()
    self._modifiableComponentsCallback:clear()

    -- gc
    -- GC.SuppressFinalize(this);
end

function Entity:_activateFromParent( _ )
    if not self._wasDeactivatedFromParent then
        return
    end
       
    self:activate()
end

function Entity:isActivateWithParent()
    return self._wasDeactivatedFromParent
end

function Entity:setActivateWithParent()
    self._wasDeactivatedFromParent = true
end

--- Marks an entity as active if it isn't already.
function Entity:activate()
    if not self._isDeactivated then
        -- Already active.
        return
    end

    self._isDeactivated = false
    self._wasDeactivatedFromParent = false

    self._world:_activateEntity( self._entityId )

    self._onEntityActivated( self )
end

function Entity:_deactivateFromParent( _ )
    if self._isDeactivated then
        return
    end

    self._wasDeactivatedFromParent = true
    self:deactivate()
end

--- Marks an entity as deactivated if it isn't already.
function Entity:deactivate()
    if self._isDeactivated then
        -- Already deactivated.
        return
    end

    self._isDeactivated = true

    self._world:_deactivateEntity( self._entityId )

    self._onEntityDeactivated( self )
end

--- Notify that a component will be removed on the end of the frame due to a <see cref="Destroy(int)"/>.
function Entity:_notifyRemovalOnDestroy( index )
    if self._isDestroyed then
        -- Entity was already destroyed, so we already notified any listeners.
        return false
    end

    if not self:hasComponent( index ) then
        -- Redundant operation, just do a no-operation.
        return false
    end

    self._onComponentBeforeRemoving( self, index, true )
    
    -- Right now, I can't think of any other notifications that need to be notified as soon as 
    -- the entity gets destroyed.
    -- The rest of cleanup should be dealt with in the actual Dispose(), called by World at the
    -- end of the frame.
    self._onComponentRemoved( self, index, true )

    return true
end

--------------------------------------------------------------------
--- Entity Family

--- Unique id of all the children of the entity.
function Entity:getChildren()
    return self._children
end

--- This is the unique id of the parent of the entity.
--- Null if none (no parent).
function Entity:getParent()
    if self._parent then
        return self._parent:getEntityId()
    end
end

--- Try to fetch a child with a <paramref name="id"/> identifier
function Entity:tryFetchChild( id )
    assert( self._children and self._children[ id ], 'Why are we fetching a child entity that is not a child?' )
    return self._world:tryGetEntity( id )
end

--- Try to fetch a child with a <paramref name="name"/> identifier
function Entity:tryFetchChildByName( name )
    if self._childrenPerName and self._childrenPerName[ name ] then
        return self._world:tryGetEntity( self._childrenPerName[ name ] )
    end
end

--- Try to fetch the parent entity.
function Entity:tryFetchParent()
    if not self._world or not self._parent or self._isDestroyed then
        return nil
    end

    self._world:tryGetEntity( self._parent )
end

--- This fetches a child with a given component.
function Entity:tryFetchChildWithComponent( componentType )
    for childId, _ in pairs( self._children ) do
        local child = self._world:tryGetEntity( childId )
        if child and child:hasComponent( componentType ) then
            return child
        end
    end
end

--- Track whenever a component of index <paramref name="index"/> gets modified.
--- This is used by the entity's children in order to track a component changes.
function Entity:_trackComponent( index, notification )
    if self._trackedComponentsModified[ index ] then
        self._trackedComponentsModified[ index ] = self._trackedComponentsModified[ index ] + notification
    else
        self._trackedComponentsModified[ index ] = MiniDelegate()
    end
end

function Entity:_untrackComponent( index, notification )
    if not self._trackedComponentsModified[ index ] then
        return
    end

    self._trackedComponentsModified[ index ] = self._trackedComponentsModified[ index ] - notification

    if self._trackedComponentsModified[ index ]:isEmpty() then
        self._trackedComponentsModified[ index ] = nil
    end
end

--- Assign an existing entity as a child.
function Entity:addChild( id, name )
    assert( self._world )

    if self._children and self._children[ id ] then
        -- Child was already added!
        return
    end

    if not self._children then
        self._children = {}
    end

    self._children[ id ] = name

    -- Bookkeep name!
    if name then
        if not self._childrenPerName then
            self._childrenPerName = {}
        end

        self._childrenPerName[ name ] = id
    end

    self._cachedChildren = false

    local child = self._world:getEntity( id )

    -- child calls Unparent() once its destroyed.
    -- child.OnEntityDestroyed += RemoveChild;
    child:reparent( self )
end

--- Try to fetch a child with a <paramref name="idOrName"/> entity identifier.
function Entity:hasChild( idOrName )
    if type( idOrName ) == 'number' then
        if self._children then
            return self._children[ idOrName ] ~= nil
        end
    elseif type( idOrName ) == 'string' then
        if self._childrenPerName then
            return self._childrenPerName[ idOrName ] ~= nil
        end
    end
end

--- Remove a child from the entity.
function Entity:removeChild( idOrName )
    if type( idOrName ) == 'number' then
        assert( self._world )

        if not self._children then
            return
        end

        if self._isDestroyed then
            -- If the parent has been destroyed, it's likely that this triggered the child code path.
            -- Do not remove the child.
            return
        end

        if not self._children[ idOrName ] then
            -- Child was already removed!
            return
        end

        self._children[ idOrName ] = nil
        self._cachedChildren = false

        local child = self._world:tryGetEntity( idOrName )
        if child then
            child:unparent()
        end

        return true

    elseif type( idOrName ) == 'string' then
        if self._childrenPerName and self._childrenPerName[ idOrName ] then
            self:removeChild( self._childrenPerName[ idOrName ] )
            return true
        end
    end

    return false
end

--- Set the parent of this entity.
function Entity:reparent( parent )
    assert( self._lookup )

    if parent == self._parent then
        -- Parent is already the same!
        return
    end

    if parent._isDestroyed then
        -- New parent is dead! Immediate suicide.
        self:destroy()
        return
    end

    self:unparent()

    if not parent then
        -- Dismiss any notifications.
        return
    end
    
    self._parent = parent

    -- TODO: RelativeComponents

    parent._onEntityDestroyed = parent._onEntityDestroyed + self:methodPointer( 'destroy' )
    parent._onEntityActivated = parent._onEntityActivated + self:methodPointer( '_activateFromParent' )
    parent._onEntityDeactivated = parent._onEntityDeactivated + self:methodPointer( '_deactivateFromParent' )
    parent:addChild( self._entityId )
end

--- This will remove a parent of the entity.
--- It untracks all the tracked components and removes itself from the parent's children.
function Entity:unparent()
    assert( self._lookup )

    if not self._parent then
        return
    end

    -- TODO: RelativeComponents

    self._parent._onEntityDestroyed = self._parent._onEntityDestroyed - self:methodPointer( 'destroy' )
    self._parent._onEntityActivated = self._parent._onEntityActivated - self:methodPointer( '_activateFromParent' )
    self._parent._onEntityDeactivated = self._parent._onEntityDeactivated - self:methodPointer( '_deactivateFromParent' )
    self._parent:removeChild( self._entityId )
    self._parent = false
end

function Entity:_onParentModified( index, component )
    -- TODO: IParentRelativeComponent
end

--------------------------------------------------------------------
--- Entity Message

--- Whether entity has a message of type <typeparamref name="T"/>.
--- This should be avoided since it highly depends on the order of the systems
--- being fired and can lead to several bugs.
--- For example, if we check for that on the state machine, it will depend on the order
--- of the entities in the world.
function Entity:hasMessage( messageType )
    return self:hasMessageWithIndex( self:getComponentIndex( messageType ) )
end

function Entity:hasMessageWithIndex( index )
    return self._messages[ index ] ~= nil
end

--- Sends a message of type <typeparamref name="T"/> for any system watching it.
function Entity:sendMessage( msg )
    local index = self:getComponentIndex( msg:getClass() )
    self:sendMessageWithIndex( index, msg )
end

function Entity:sendMessageWithIndex( index, msg )
    assert( self._world )

    self._messages[ index ] = true

    -- Notify messagers. We only use the message to notify all the messagers,
    -- but we will not save any of its data afterwards.
    self._onMessage( self, index, msg )

    -- Notify world that a message has been sent for this entity.
    self._world:_onMessage( self )
end

--- Clear all pending messages.
function Entity:_clearMessages()
    -- We no longer send notification to systems upon clearing messages.
    -- Filters should NOT track messages, this just has too much overhead.
    for k, _ in pairs( self._messages ) do
        self._messages[ k ] = nil
    end
end

--- This removes a message from the entity. This is used when the message must be removed within
--- this frame.
function Entity:removeMessage( messageIndex )
    local removed = self._messages[ messageIndex ] ~= nil

    self._messages[ messageIndex ] = nil
    self._onComponentRemoved( self, messageIndex, false )

    return removed
end
