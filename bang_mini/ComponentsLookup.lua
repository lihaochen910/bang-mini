--------------------------------------------------------------------
---Implemented by generators in order to provide a mapping of all the types to their respective id.
---@class ComponentsLookup
CLASS: ComponentsLookup()

function ComponentsLookup:__init()
    --- Tracks the last id this particular implementation is tracking plus one.
    self._nextLookupId = 3

    --- Maps all the components to their unique id.
    self._componentsIndex = {}

    --- Maps all the messages to their unique id.
    self._messagesIndex = {}

    --- Tracks components and messages without a generator. This query will have a lower performance.
    self._untrackedIndices = {}

    self._nextUntrackedIndex = false
end

function ComponentsLookup:_countComponentsIndex()
    return table.len( self._componentsIndex )
end

function ComponentsLookup:_countMessagesIndex()
    return table.len( self._messagesIndex )
end

function ComponentsLookup:_countUntrackedIndices()
    return table.len( self.untrackedIndices )
end

--- Get the id for <paramref name="t"/> component type.
function ComponentsLookup:id( componentType )
    --local componentT = type( componentType )
    --if componentT == 'table' then
        assert(
            isSubclass( componentType, IComponent ) or
            isSubclass( componentType, IMessage ),
            'Why are we receiving a type that is not an IComponent?'
        )

        if isSubclass( componentType, IMessage ) and
            self._messagesIndex[ componentType ] then
            return self._messagesIndex[ componentType ]
        end

        if self._componentsIndex[ componentType ] then
            return self._componentsIndex[ componentType ]
        end

        if self._untrackedIndices[ componentType ] then
            return self._untrackedIndices[ componentType ]
        end
        
        return self:_addUntrackedIndexForComponentOrMessage( componentType )
    --end
end

function ComponentsLookup:totalIndices()
    return self:_countComponentsIndex() + self:_countMessagesIndex() + self:_countUntrackedIndices()
end

function ComponentsLookup:_addUntrackedIndexForComponentOrMessage( componentType )
    local id
    --if isSubclass( componentType, IStateMachineComponent ) then
    --    id = self:id( IStateMachineComponent )
    if isSubclass( componentType, InteractiveComponent ) then
        id = self:id( InteractiveComponent )
    end

    if id == nil then
        if not self._nextUntrackedIndex then
            self._nextUntrackedIndex = self:_countComponentsIndex() + self:_countMessagesIndex()
        end

        id = self._nextUntrackedIndex
        self._nextUntrackedIndex = self._nextUntrackedIndex + 1

        self._untrackedIndices[ componentType ] = id
    end
    
    return id
end

function ComponentsLookup:getAllComponentIndexUnderInterface( interfaceType )
    local result = {}
    for componentType, componentIndex in pairs( self._componentsIndex ) do
        if isSubclass( componentType, interfaceType ) then
            table.insert( result, { componentType, componentIndex } )
        end
    end
    return result
end
