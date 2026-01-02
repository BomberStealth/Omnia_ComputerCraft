-- ============================================
-- INVENTORY - Gestione inventario turtle
-- ============================================

local config = require("config")

local inventory = {}

-- ============================================
-- INFORMAZIONI SLOT
-- ============================================

-- Ottieni info su uno slot
function inventory.getSlotInfo(slot)
    slot = slot or turtle.getSelectedSlot()
    local detail = turtle.getItemDetail(slot)
    
    if detail then
        return {
            name = detail.name,
            count = detail.count,
            damage = detail.damage,
            slot = slot
        }
    end
    
    return nil
end

-- Ottieni tutti gli item nell'inventario
function inventory.getAll()
    local items = {}
    
    for slot = 1, 16 do
        local info = inventory.getSlotInfo(slot)
        if info then
            table.insert(items, info)
        end
    end
    
    return items
end

-- Conta spazio libero totale
function inventory.getFreeSpace()
    local free = 0
    
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            free = free + 64
        else
            local detail = turtle.getItemDetail(slot)
            if detail then
                free = free + (64 - detail.count)
            end
        end
    end
    
    return free
end

-- Conta slot vuoti
function inventory.getEmptySlots()
    local empty = 0
    
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            empty = empty + 1
        end
    end
    
    return empty
end

-- ============================================
-- RICERCA ITEM
-- ============================================

-- Trova slot con un item specifico
function inventory.find(itemName)
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == itemName then
            return slot, detail.count
        end
    end
    return nil
end

-- Trova tutti gli slot con un item specifico
function inventory.findAll(itemName)
    local slots = {}
    
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == itemName then
            table.insert(slots, {
                slot = slot,
                count = detail.count
            })
        end
    end
    
    return slots
end

-- Conta totale di un item
function inventory.count(itemName)
    local total = 0
    
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == itemName then
            total = total + detail.count
        end
    end
    
    return total
end

-- ============================================
-- SELEZIONE
-- ============================================

-- Seleziona slot con item specifico
function inventory.select(itemName)
    local slot = inventory.find(itemName)
    if slot then
        turtle.select(slot)
        return true
    end
    return false
end

-- Seleziona primo slot non vuoto
function inventory.selectNonEmpty()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            return true, slot
        end
    end
    return false
end

-- Seleziona primo slot vuoto
function inventory.selectEmpty()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            turtle.select(slot)
            return true, slot
        end
    end
    return false
end

-- ============================================
-- ORGANIZZAZIONE
-- ============================================

-- Compatta inventario (unisci stack)
function inventory.compact()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            for targetSlot = 1, slot - 1 do
                if turtle.getItemCount(targetSlot) > 0 then
                    if turtle.compareTo(targetSlot) then
                        turtle.transferTo(targetSlot)
                        if turtle.getItemCount(slot) == 0 then
                            break
                        end
                    end
                end
            end
        end
    end
    turtle.select(1)
end

-- Sposta tutti gli item di un tipo in uno slot
function inventory.consolidate(itemName)
    local targetSlot = nil
    
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == itemName then
            if not targetSlot then
                targetSlot = slot
            else
                turtle.select(slot)
                turtle.transferTo(targetSlot)
            end
        end
    end
    
    turtle.select(1)
    return targetSlot
end

-- ============================================
-- DROP / SUCK
-- ============================================

-- Droppa tutto l'inventario
function inventory.dropAll(direction)
    direction = direction or "front"
    
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            if direction == "up" then
                turtle.dropUp()
            elseif direction == "down" then
                turtle.dropDown()
            else
                turtle.drop()
            end
        end
    end
    
    turtle.select(1)
end

-- Droppa item specifico
function inventory.drop(itemName, count, direction)
    direction = direction or "front"
    local dropped = 0
    
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == itemName then
            turtle.select(slot)
            local toDrop = count and math.min(count - dropped, detail.count) or detail.count
            
            local success
            if direction == "up" then
                success = turtle.dropUp(toDrop)
            elseif direction == "down" then
                success = turtle.dropDown(toDrop)
            else
                success = turtle.drop(toDrop)
            end
            
            if success then
                dropped = dropped + toDrop
                if count and dropped >= count then
                    break
                end
            end
        end
    end
    
    turtle.select(1)
    return dropped
end

-- Prendi item da chest
function inventory.suck(count, direction)
    direction = direction or "front"
    
    inventory.selectEmpty()
    
    if direction == "up" then
        return turtle.suckUp(count)
    elseif direction == "down" then
        return turtle.suckDown(count)
    else
        return turtle.suck(count)
    end
end

-- ============================================
-- FUEL
-- ============================================

-- Trova fuel nell'inventario
function inventory.findFuel()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then  -- Test senza consumare
            return slot
        end
    end
    return nil
end

-- Refuel da inventario
function inventory.refuel(amount)
    local refueled = 0
    
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then
            local count = turtle.getItemCount(slot)
            local toUse = amount and math.min(amount - refueled, count) or count
            
            if turtle.refuel(toUse) then
                refueled = refueled + toUse
                if amount and refueled >= amount then
                    break
                end
            end
        end
    end
    
    turtle.select(1)
    return refueled
end

-- ============================================
-- VERIFICA MATERIALI
-- ============================================

-- Verifica se abbiamo abbastanza materiali
function inventory.hasEnough(requirements)
    for itemName, required in pairs(requirements) do
        local available = inventory.count(itemName)
        if available < required then
            return false, itemName, required - available
        end
    end
    return true
end

-- Lista materiali mancanti
function inventory.getMissing(requirements)
    local missing = {}
    
    for itemName, required in pairs(requirements) do
        local available = inventory.count(itemName)
        if available < required then
            missing[itemName] = required - available
        end
    end
    
    return missing
end

-- ============================================
-- DEBUG
-- ============================================

function inventory.print()
    print("=== Inventory ===")
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail then
            print(string.format("[%2d] %s x%d", slot, detail.name, detail.count))
        end
    end
    print("=================")
end

return inventory
