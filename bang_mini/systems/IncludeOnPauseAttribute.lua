--------------------------------------------------------------------
-- IncludeOnPauseAttribute Usage
--[[
CLASS: SomeCuteSystem( IUpdateSystem )
	:META {
	    includeOnPause = true
	}
]]

------@class IncludeOnPauseAttr
--- Indicates that a system will be included when the world is paused.
--- This will override <see cref="DoNotPauseAttribute"/>.
CLASS: IncludeOnPauseAttr()
