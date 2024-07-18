--------------------------------------------------------------------
---@class IInteraction
--- An interaction is any logic which will be immediately sent to another entity.
CLASS: IInteraction()
    :META {
        interface = true
    }

--- Contract immediately performed once <paramref name="interactor"/> interacts with <paramref name="interacted"/>.
function IInteraction:interact( world, interactor, interacted )
end
