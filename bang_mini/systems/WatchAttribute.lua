--------------------------------------------------------------------
-- WatchAttribute Usage
--[[
CLASS: SomeCuteReactiveSystem( IReactiveSystem )
	:META {
	    -- TODO: do we need watcher is a table?
	    watcher = WatchAttr( "SomeCuteComponent", AnotherComponent )
	}
]]

------@class WatchAttr
--- Indicates a watcher attribute for a system.
--- This must be implemented by all the systems that inherit <see cref="IReactiveSystem"/>.
CLASS: WatchAttr()

function WatchAttr:__init( ... )
    local data
    if select( '#', ... ) == 1 and select( 1, ... ).types then
        data = select( 1, ... )
    else
        data = { ... }
    end
    assert( type( data ) == 'table' )

    --- System will target all the entities that has all this set of components.
    self._types = data.types and data.types or data
end

function WatchAttr:getTypes()
    return self._types
end
