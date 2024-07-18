--------------------------------------------------------------------
-- RequiresAttribute Usage
--[[
CLASS: SomeCuteComponent( IComponent )
	:META {
	    requires = RequiresAttr(
            SomeCuteComponent,
            "AnotherComponent"
        )
	}
]]

------@class RequiresAttr
--- Marks a component as requiring other components when being added to an entity.
--- This is an attribute that tells that a given data requires another one of the same type.
--- For example: a component requires another component when adding it to the entity,
--- or a system requires another system when adding it to a world.
--- If this is for a system, it assumes that the system that depends on the other one comes first.
CLASS: RequiresAttr()
    :MODEL {
        Field 'types' :array();
    }

function RequiresAttr:__init( ... )
    local data
    if select( '#', ... ) == 1 then
        data = select( 1, ... )
    else
        data = { ... }
    end
    assert( type( data ) == 'table' )

    self._types = data.types and data.types or data
end

function RequiresAttr:getTypes()
    return self._types
end
