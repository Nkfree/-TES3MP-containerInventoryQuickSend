local onContainerTimestamp = {}
local onObjectActivateIdx = {}

-- Mark uniqueIndex and cellDescription of recently activated object
local function OnObjectActivateValidator(eventStatus, pid, cellDescription, objects, players)
    -- Check if the activated entity is an object
    if next(objects) then
        -- Store uniqueIndex of the first found object into player specific table
        for _, object in pairs(objects) do
            onObjectActivateIdx[pid] = { uniqueIndex = object.uniqueIndex, cellDesc = cellDescription}
            break
        end
    end
end

-- Mark timestamp of OnContainer event if the container's uniqueIndex matches player's recently activated
local function OnContainerValidator(eventStatus, pid, cellDescription, objects)

    for _, object in pairs(objects) do
        if onObjectActivateIdx[pid] and object.uniqueIndex == onObjectActivateIdx[pid].uniqueIndex then
            onContainerTimestamp[pid] = os.time()
            break
        end
    end
end

-- Modify OnPlayerInventory behaviour only if the current timestamp matches the one marked by OnContainer event above
-- and specifically if the item is to be added in the inventory
local function OnPlayerInventoryValidator(eventStatus, pid)
    -- Slightly edited version of BasePlayer:SaveInventory()
    local action = tes3mp.GetInventoryChangesAction(pid)
    local itemChangesCount = tes3mp.GetInventoryChangesSize(pid)
    local currentTime = os.time()
    
    local drawState = tes3mp.GetDrawState(pid)
    if drawState == 1 then
        return customEventHooks.makeEventStatus(true, true)
    end

    if action == enumerations.inventory.ADD and currentTime == onContainerTimestamp[pid] then

        tes3mp.LogMessage(enumerations.log.INFO, "Saving " .. itemChangesCount .. " item(s) to inventory with action " ..
        tableHelper.getIndexByValue(enumerations.inventory, action))

        for index = 0, itemChangesCount - 1 do
            local itemRefId = tes3mp.GetInventoryItemRefId(pid, index)

            if itemRefId ~= "" then

                local item = {
                    refId = itemRefId,
                    count = tes3mp.GetInventoryItemCount(pid, index),
                    charge = tes3mp.GetInventoryItemCharge(pid, index),
                    enchantmentCharge = tes3mp.GetInventoryItemEnchantmentCharge(pid, index),
                    soul = tes3mp.GetInventoryItemSoul(pid, index)
                }
                
                tes3mp.LogAppend(enumerations.log.INFO, "- id: " .. item.refId .. ", count: " .. item.count ..
                    ", charge: " .. item.charge .. ", enchantmentCharge: " .. item.enchantmentCharge ..
                    ", soul: " .. item.soul)
                
                inventoryHelper.addItem(Players[pid].data.inventory, item.refId, item.count, item.charge, item.enchantmentCharge, item.soul)
                
                -- Disables all menus; hides cursor and hud
                -- Note: as side effect removes the item that would stay attached to player's cursor - the item gets added to player's inventory and removed from container
                logicHandler.RunConsoleCommandOnPlayer(pid, "ToggleMenus")
                -- Re-enable cursor and hud
                -- Note: Unfortunately this doesn't re-activate the container window - do it below
                logicHandler.RunConsoleCommandOnPlayer(pid, "ToggleMenus")
                -- Activate the container window for player
                -- Note: All these happen in the background and are not visible to player
                logicHandler.ActivateObjectForPlayer(pid, onObjectActivateIdx[pid].cellDesc, onObjectActivateIdx[pid].uniqueIndex)


                if logicHandler.IsGeneratedRecord(item.refId) then

                    local recordStore = logicHandler.GetRecordStoreByRecordId(item.refId)

                    if recordStore ~= nil then
                        Players[pid]:AddLinkToRecord(recordStore.storeType, item.refId)
                    end
                end
            end
        end

        Players[pid]:QuicksaveToDrive()
        -- disable default handler and custom handlers
        return customEventHooks.makeEventStatus(false, false)
    end
end

customEventHooks.registerValidator("OnContainer", OnContainerValidator)
customEventHooks.registerValidator("OnObjectActivate", OnObjectActivateValidator)
customEventHooks.registerValidator("OnPlayerInventory", OnPlayerInventoryValidator)
