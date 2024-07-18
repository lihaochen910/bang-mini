--------------------------------------------------------------------
-- UniqueAttribute Usage
--[[
CLASS: SomeCuteComponent( IComponent )
	:META {
	    unique = true
	}
]]

------@class UniqueAttr
--- Marks a component as unique within our world.
--- We should not expect two entities with the same component if it is declared as unique.
CLASS: UniqueAttr()
