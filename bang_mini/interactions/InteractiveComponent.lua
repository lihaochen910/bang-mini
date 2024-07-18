--------------------------------------------------------------------
---@class InteractiveComponent : IComponent
--- Implements an interaction component which will be passed on to the entity.
CLASS: InteractiveComponent( IComponent )

function InteractiveComponent:__init()
    self._interaction = false
end

--- Calls the inner interaction component.
function InteractiveComponent:interact( world, interactor, interacted )
end
