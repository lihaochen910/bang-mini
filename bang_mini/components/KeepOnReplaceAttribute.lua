--------------------------------------------------------------------
-- KeepOnReplaceAttribute Usage
--[[
CLASS: SomeCuteComponent( IComponent )
	:META {
	    keepOnReplace = true
	}
]]

------@class KeepOnReplaceAttr
--- Marks components that must be kept on an entity
--- <see cref="Bang.Entities.Entity.Replace(IComponent[], List{ValueTuple{int, string}}, bool)"/> operation.
CLASS: KeepOnReplaceAttr()
