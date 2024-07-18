--------------------------------------------------------------------
-- MessagerAttribute Usage
--[[
CLASS: SomeCuteMessagerSystem( IMessagerSystem )
	:META {
	    messager = MessagerAttr( SomeCuteMessage, "AnotherMessage" )
	}
]]

------@class MessagerAttr
--- Marks a messager attribute for a system.
--- This must be implemented by all the systems that inherit <see cref="IMessagerSystem"/>.
CLASS: MessagerAttr()
    :MODEL {
        Field 'types' :array();
    }

function MessagerAttr:__init( ... )
    local data
    if select( '#', ... ) == 1 then
        data = select( 1, ... )
    else
        data = { ... }
    end
    assert( type( data ) == 'table' )
    
    --- System will target all the entities that has all this set of components.
    self._types = data.types and data.types or data
end

function MessagerAttr:getTypes()
    return self._types
end
