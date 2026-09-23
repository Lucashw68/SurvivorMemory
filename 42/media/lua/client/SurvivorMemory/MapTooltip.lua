SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.MapTooltip = SurvivorMemory.MapTooltip or {}
local Tooltip = SurvivorMemory.MapTooltip

Tooltip.WHITE = { r = 0.94, g = 0.94, b = 0.92 }
Tooltip.MUTED = { r = 0.70, g = 0.73, b = 0.75 }
Tooltip.ACCENT = { r = 0.89, g = 0.78, b = 0.52 }

-- Category illustrations from B42, not a query of the remembered world object.
local importantTextures = {
    GENERATOR = "Item_Generator",
    GAS_PUMP = "location_shop_fossoil_01_12",
    WOOD_STOVE = "appliances_cooking_01_16",
}
function Tooltip.importantIcon(kind)
    local name = importantTextures[kind]
    local texture = name and getTexture(name) or nil
    -- Same trimmed, cached icon as B42's moveables/context menus. Drawing the
    -- full world-tile canvas would make a stove/pump look tiny in a 32px slot.
    return texture and texture:splitIcon() or nil
end

-- Wrap complete UTF-8 codepoints, including scripts that do not use spaces.
-- Prefer word boundaries, but split a long name when needed to stay on screen.
function Tooltip.wrap(text, font, width)
    local result, line = {}, ""
    local function fits(value) return getTextManager():MeasureStringX(font, value) <= width end
    for word in tostring(text or ""):gmatch("%S+") do
        local joined = line == "" and word or line .. " " .. word
        if fits(joined) then line = joined
        else
            if line ~= "" then result[#result + 1] = line; line = "" end
            for character in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                if line ~= "" and not fits(line .. character) then
                    result[#result + 1] = line; line = ""
                end
                line = line .. character
            end
        end
    end
    if line ~= "" or #result == 0 then result[#result + 1] = line end
    return result
end

local function measureRow(row, width)
    local font = row.title and UIFont.Medium or UIFont.Small
    local offset = row.icon and 38 or 0
    local lines = Tooltip.wrap(row.text, font, width - 24 - offset)
    local detail = row.detail and Tooltip.wrap(row.detail, UIFont.Small, width - 24 - offset) or {}
    local height = #lines * getTextManager():getFontHeight(font)
        + #detail * getTextManager():getFontHeight(UIFont.Small) + (#detail > 0 and 3 or 0)
    return { row = row, lines = lines, detail = detail, font = font, offset = offset,
        height = math.max(height, row.icon and 32 or 0) + 8 + (row.divider and 9 or 0) }
end

function Tooltip.layout(rows, mapWidth, mapHeight)
    local width = 240
    for _, row in ipairs(rows) do
        local font = row.title and UIFont.Medium or UIFont.Small
        local content = getTextManager():MeasureStringX(font, row.text)
        if row.detail then content = math.max(content, getTextManager():MeasureStringX(UIFont.Small, row.detail)) end
        width = math.max(width, content + 24 + (row.icon and 38 or 0))
    end
    width = math.max(64, math.min(width, 400, mapWidth - 12))
    local blocks, height = {}, 16
    local footerHeight = getTextManager():getFontHeight(UIFont.Small) + 8
    for index, row in ipairs(rows) do
        local block = measureRow(row, width)
        local reserve = index < #rows and footerHeight or 0
        if height + block.height + reserve > mapHeight - 12 then
            local remaining = 0
            for hidden = index, #rows do remaining = remaining + (rows[hidden].count or 1) end
            local omitted = measureRow({ text = getText("IGUI_SM_MoreTooltipEntries", remaining),
                color = Tooltip.MUTED }, width)
            if height + omitted.height <= mapHeight - 12 then
                blocks[#blocks + 1] = omitted; height = height + omitted.height
            end
            break
        end
        blocks[#blocks + 1] = block
        height = height + block.height
    end
    return { width = width, height = height, blocks = blocks }
end

function Tooltip.draw(map, rows, x, y)
    local layout = Tooltip.layout(rows, map.width, map.height)
    x = math.max(6, math.min(x + 14, map.width - layout.width - 6))
    y = math.max(6, math.min(y + 14, map.height - layout.height - 6))
    map:drawRect(x, y, layout.width, layout.height, 0.96, 0.055, 0.06, 0.065)
    map:drawRectBorder(x, y, layout.width, layout.height, 0.85, 0.42, 0.40, 0.32)
    local top = y + 8
    for _, block in ipairs(layout.blocks) do
        local row = block.row
        if row.divider then
            map:drawRect(x + 12, top + 2, layout.width - 24, 1, 0.4, 0.55, 0.52, 0.43)
            top = top + 9
        end
        if row.icon then map:drawTextureScaledAspect(row.icon, x + 12, top, 32, 32, 1, 1, 1, 1) end
        local lineY, color = top, row.color or Tooltip.WHITE
        for _, line in ipairs(block.lines) do
            map:drawText(line, x + 12 + block.offset, lineY, color.r, color.g, color.b, 1, block.font)
            lineY = lineY + getTextManager():getFontHeight(block.font)
        end
        lineY = lineY + 3
        for _, line in ipairs(block.detail) do
            map:drawText(line, x + 12 + block.offset, lineY,
                Tooltip.MUTED.r, Tooltip.MUTED.g, Tooltip.MUTED.b, 1, UIFont.Small)
            lineY = lineY + getTextManager():getFontHeight(UIFont.Small)
        end
        top = top + block.height - (row.divider and 9 or 0)
    end
    return layout
end

return Tooltip
