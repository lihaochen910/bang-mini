--------------------------------------------------------------------
-- Filter Usage
--[[
CLASS: SomeCuteSystem( IUpdateSystem )
	:META {
	    -- TODO: using 'attributes' field
		filters = {
			FilterAttr( {
				filter = ContextAccessorFilter.allOf, -- [optional] default is allOf
				kind = ContextAccessorKind.read | ContextAccessorKind.write, -- [optional] default is read&write
				types = {
					MyLuaComponent -- or string ComponentName 'MyLuaComponent'
				} -- required type is array
			} ),
			FilterAttr( {
			    SomeCuteComponent,
				"AnotherComponent"
			} ),
			FilterAttr(
			    SomeCuteComponent,
				"AnotherComponent"
			)
		}
	}
]]

------@class FilterAttr
--- Indicates characteristics of a system that was implemented on our ECS system.
--- This must be implemented by all the systems that inherits from <see cref="ISystem"/>.
CLASS: FilterAttr()
    :MODEL {
        Field 'kind' :enum( ContextAccessorKind );
        Field 'filter' :enum( ContextAccessorFilter );
        Field 'types' :array();
    }

-- Creates a system filter with custom accessors.
function FilterAttr:__init( ... )
    local data
    if select( '#', ... ) == 1 then
        data = select( 1, ... )
    else
        data = { ... }
    end
    assert( type( data ) == 'table' )
    local filter = data.filter and data.filter or ContextAccessorFilter.allOf
    local kind = data.kind and data.kind or ( ContextAccessorKind.readwrite )

    --- This is the kind of accessor that will be made on this component.
    --- This can be leveraged once we parallelize update frames (which we don't yet), so don't bother with this just yet.
    self._kind = kind
    
    --- This is how the system will filter the entities. See <see cref="ContextAccessorFilter"/>.
    self._filter = filter
    
    --- System will target all the entities that has all this set of components.
    self._types = data.types and data.types or data
end

function FilterAttr:getFilter()
    return self._filter
end

function FilterAttr:getKind()
    return self._kind
end

function FilterAttr:getTypes()
    return self._types
end
