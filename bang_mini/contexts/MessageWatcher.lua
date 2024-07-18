--------------------------------------------------------------------
---@class MessageWatcher
--- A context may have a collection of watchers.
CLASS: MessageWatcher()

function MessageWatcher:__init( world, contextId, targetMessages )
    self._world = world

    self._targetMessages = {}
    for _, t in ipairs( targetMessages ) do
        local id = world:getComponentsLookup():id( t )
        table.insert( self._targetMessages, id )
    end

    -- Calculate the hash based on the target messages and the context id.
    local messagesHash = HashExtensions.getHashCodeImpl( self._targetMessages )
    self._id = HashExtensions.GetHasCode( contextId, messagesHash )
end

function MessageWatcher:_subscribeToContext( context )
    context._onMessageSentForEntityInContext = context._onMessageSentForEntityInContext + self:methodPointer( '_onMessageSent' )
end

function MessageWatcher:_onMessageSent( e, index, message )
    if not self._targetMessages[ index ] then
        return
    end

    self._world:onMessage( self._id, e, message )
end
