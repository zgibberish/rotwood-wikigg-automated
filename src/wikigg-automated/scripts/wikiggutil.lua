--[[
    using ingame console:
    imgui:SetClipboardText(wikiggutil.Wikitext.PowersTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.GemsTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.GemsNavbox())
    imgui:SetClipboardText(wikiggutil.Wikitext.ConstructablesTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.BiomeExplorationRewardsTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.FoodTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.MasteriesTable())
]]

local wikiggutil = {}
wikiggutil.Const = {}
wikiggutil.Util = {}
wikiggutil.Data = {}
wikiggutil.Wikitext = {}

-- map specific words to specific pages
-- you can map different strings to the same page link
-- order matters, case sensitive
wikiggutil.Const.MAP_LINKS = {
    -- notice that "Focus Hits" is mapped before "Focus")
    {match = "Focus Hits"},
    {match = "Focus Hit", dest = "Focus Hits"},
    {match = "Focus", dest = "Focus Hits"},

    {match = "Critical Hits"},
    {match = "Critical Hit Chance", dest = "Critical Hits"},
    {match = "Critical Hit", dest = "Critical Hits"},
    {match = "Critical", dest = "Critical Hits"},

    {match = "Powers"},
    {match = "Runspeed"},
    {match = "Teffra"},
    {match = "Shield"},
    {match = "Perfect Dodg"},
    {match = "Quick Ris"},
    {match = "Traps"},
    {match = "Fortifying Ingot"},

    {match = "Mother Treek"},
    {match = "Owlitzer"},
    {match = "Enigmox"},
    {match = "Swarm"},
    {match = "Rook"},
    {match = "Shell Drake"},
    {match = "Grimhollow"},
}
wikiggutil.Const.ICON_SIZE_LARGE = 128 -- used for stuff like power/gems icons in tables
wikiggutil.Const.ICON_SIZE_MID = 64 -- food, constructables, masteries, etc
wikiggutil.Const.ICON_SIZE_SMALL = 24 -- used for stuff like ingredient icons
wikiggutil.Const.ICON_SIZE_SMALLER = 16 -- stuff like keybind icons in strings

--- string util functions
-- remove section from start to end index from a string
function wikiggutil.Util.StrRemove(str, idx_start, idx_end)
    return str:sub( 1, idx_start - 1 ) .. str:sub(idx_end + 1 )
end    
-- insert istr into str at idx
function wikiggutil.Util.StrInsertAt(str, istr, idx)
    return str:sub(1, idx-1) .. istr .. str:sub(idx)
end

-- turns every occurrence of "abc" in provided string into a link ( [[]] )
-- that shows "abc" and links to remap_table["abc"] (override) or just "abc".
function wikiggutil.Util.StrRemapLinks(str, remap_table)
    local lume = require "util.lume"

    local StrRemove = wikiggutil.Util.StrRemove
    local StrInsertAt = wikiggutil.Util.StrInsertAt
    local Link = wikiggutil.Wikitext.Link

    local operations = {
        -- idx_start
        -- idx_end
        -- replace_str
    }

    local function idx_already_has_operation(idx)
        -- checks if there's already replaced strings waiting to be applied
        -- at the specified index
        for _,o in ipairs(operations) do
            if idx >= o.idx_start and idx <= o.idx_end then return true end
        end
        return false
    end

    for _, entry in ipairs(remap_table) do
        local match, dest = entry.match, entry.dest
        local replace = dest
            and Link(match, dest)
            or Link(match)

        local findstartpos = 1
        local i, j
        repeat
            i, j = str:find(match, findstartpos)
            if i then
                if not idx_already_has_operation(i) then
                    table.insert(operations, {
                        idx_start = i,
                        idx_end = j,
                        replace_str = replace,
                    })
                end
                findstartpos = j + 1
            end
        until not i
    end

    -- important!! we have to operate from start to end of string
    operations = lume.sort(operations, function(a, b) return a.idx_start < b.idx_start end)

    -- apply all replace operations
    local offset = 0
    for _,o in ipairs(operations) do
        str = StrRemove(str, o.idx_start + offset, o.idx_end + offset)
        str = StrInsertAt(str, o.replace_str, o.idx_start + offset)
        local len_original = o.idx_end - o.idx_start + 1
        offset = offset + (o.replace_str:len() - len_original)
    end

    return str
end

function wikiggutil.Wikitext.Link(str, dest)
    if dest then
        return "[["..dest.."|"..str.."]]"
    end
    return "[["..str.."]]"
end

function wikiggutil.Wikitext.File(filename, size, constrain_height)
    local size_opt = ""
    if size then
        size_opt = "|"
        if constrain_height then size_opt = size_opt .. "x" end
        size_opt = size and size_opt..tostring(size).."px"
    end
    
    return "[[File:"..filename..size_opt.."]]"
end

function wikiggutil.Wikitext.FileLink(str, dest, filename, size)
    -- file (image) that is a clickable link to a specific destination
    local Link = wikiggutil.Wikitext.Link
    local link_str = Link(str, dest)
    local size_opt = size and "|"..tostring(size).."px" or ""
    return "[[File:"..filename..size_opt.."|link="..link_str.."]]"
end

function wikiggutil.Wikitext.FormattedString(str)
    -- only need to convert these tags
    -- <p>: picture (not paragraph), single tag and does not close
    -- <#>: colors, does open and close
    -- can ignore/remove these cuz we dont really need them, and theyre not really used
    --   <s>: shadow
    --   <z>: text size
    --   <!>: link

    local StrRemove = wikiggutil.Util.StrRemove
    local StrInsertAt = wikiggutil.Util.StrInsertAt
    local File = wikiggutil.Wikitext.File

    local res = ""

    -- dummy playercontroller
    local playercontroller = {
        _GetInputTuple = function(self)
            -- (see playercontroller component script)
            return "keyboard", 1
        end,
        GetTexForControlName = function(self, control_key)
            return TheInput:GetTexForControlName(control_key, self:_GetInputTuple())
        end,
        GetInputImageAtlas = function(self)
            return TheInput:GetDeviceImageAtlas(self:_GetInputTuple())
        end
    }

    local j, k, sel, attr
    local spans = {} -- table that keeps track of openned tags so they can be closed at </>
    local findstartpos = 1
    repeat
        j, k, sel, attr = str:find("<([#!bBcCsSiIuUpPzZ/]?)([^>]*)>", findstartpos)
        if j then
            local validmarkup = false

            if sel == '/' then -- tag close
                local attr = table.remove(spans)
				local sel = table.remove(spans)
				local start_idx = table.remove(spans)
                
                if sel == "#" then
                    str = StrRemove(str, j, k)
                    str = StrInsertAt(str, "</font>", j)
                elseif sel == "s"
                    or sel == "z"
                    or sel == "!" then
                    str = StrRemove(str, j, k)
                end

            elseif sel == "p" then -- picture tag (special cuz it does not close)
                validmarkup = true

                local lowerattr = string.lower(attr)
                local img = string.match(lowerattr, [[img=['’]([^'’]+)]])
                local bind = string.match(attr, [[bind=['’]([^'’]+)]]) 
                local scale = string.match(lowerattr, [[scale=([%d.]+)]]) or 1
                scale = tonumber(scale)
                local file_scale = math.ceil(wikiggutil.Const.ICON_SIZE_SMALLER*scale)

                if bind then
                    img = playercontroller and playercontroller:GetTexForControlName(bind)
                    img = img or TheInput:GetTexForControlName(bind)
                    -- If we don't have a bound control, show nothing. Thus it's valid.
                    validmarkup = true
                end
                if img then
                    str = StrRemove(str, j, k)
                    local _, icon_base = string.match(img, "(.*)%/(.*).tex")
                    local filename = icon_base..".png"
                    -- filename prefix to avoid confusing these files with other 
                    -- simillarly named files, since they tend to be a bit generic
                    -- also added in extract images script
                    if bind then filename = "controlicons_"..filename end
                    str = StrInsertAt(str, File(filename, file_scale, (bind~=nil)), j)
                end
            else -- tag open for all other types
                sel = sel:lower()
                if (sel == "#") then
                    validmarkup = true

                    -- attr is the hex color code, or a UICOLORS color name
                    local uicolors_colorcode = rawget(UICOLORS, attr) and HexToStr(RGBToHex(UICOLORS[attr]))
                    if uicolors_colorcode then
                        uicolors_colorcode = uicolors_colorcode:sub(1, 6)
                    end
                    local colorcode = uicolors_colorcode or attr
                    local new_tag_str = "<font color=\'#"..colorcode.."\'>"

                    str = StrRemove(str, j, k)
                    str = StrInsertAt(str, new_tag_str, j)
                elseif sel == "s"
                    or sel == "z"
                    or sel == "!" then
                    validmarkup = true
                    str = StrRemove(str, j, k)
                end

                if validmarkup then
                    table.insert(spans, j-1)
                    table.insert(spans, sel)
                    table.insert(spans, attr)
                end
            end

            if not validmarkup then
                findstartpos = j + 1
            end
        end
    until not j

    return str
end

function wikiggutil.Wikitext.RewardToString(reward)
    local Consumable = require "defs.consumable"
    local Power = require "defs.powers"
    local Constructable = require "defs.constructable"
    local Cosmetic = require "defs.cosmetics.cosmetics"
    local Equipment = require "defs.equipment"    

    local File = wikiggutil.Wikitext.File
    local Link = wikiggutil.Wikitext.Link
    local FileLink = wikiggutil.Wikitext.FileLink

    local def = reward.def
    if def == nil then return "REWARD_HAS_NO_DEF" end

    if Power.Slots[def.slot] ~= nil then -- Power
        local icon = def.icon or ""
        local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
        local filename = icon_base..".png"
        
        local name = def:GetPrettyName()

        return File(filename, wikiggutil.Const.ICON_SIZE_SMALL)..Link(name)
    elseif Cosmetic.IsSlot(def.slot) then -- Cosmetic
        local slot = Cosmetic.Slots[def.slot]
        
        -- use icons we provide for the wiki
        -- (can be slightly edited versions of ingame icons)
        local icon = ""
        local name = def.name
        if slot == Cosmetic.Slots.PLAYER_TITLE then
            icon = "cosmetic_icon_"..slot..".png"
            name = STRINGS.COSMETICS.TITLES[string.upper(def.title_key)]
        elseif slot == Cosmetic.Slots.PLAYER_BODYPART then
            icon = "cosmetic_icon_"..slot..".png"
        else
            icon = "cosmetic_icon_generic.png"
        end

        return File(icon, wikiggutil.Const.ICON_SIZE_SMALL)..Link(name)
    elseif Constructable.IsSlot(def.slot) then -- Constructable
        local icon = def.icon or ""
        local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
        local filename = icon_base..".png"
        local name = def.pretty and def.pretty.name or def.name
        return File(filename, wikiggutil.Const.ICON_SIZE_SMALL)..Link(name)
    elseif def.slot == Consumable.Slots.MATERIALS then -- Consumable
        local name = def.pretty and def.pretty.name or def.name
    
        local icon = def.icon or ""
        local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
        local filename = icon_base..".png"

        local amount = reward.count

        local name_str = FileLink(name, nil, filename, wikiggutil.Const.ICON_SIZE_SMALL)
        local amount_str = "x"..tostring(amount)

        return name_str.." "..amount_str
    elseif def.slot == Equipment.Slots.WEAPON then -- Equipment
        return "STRING_NOT_IMPLEMENTED_Equipment"
    end

    return "UNRECOGNIZED_REWARD_TYPE"
end

function wikiggutil.Data.GetPowerDefs()
    local Power = require "defs.powers"
    local PowerDropManager = require "components.powerdropmanager"
    local lume = require "util.lume"

    local all_defs = Power:GetAllPowers()
    all_defs = PowerDropManager:FilterByDroppable(all_defs)
    -- not droppable but still obtainable in game from ???? npc
    table.insert(all_defs, Power.FindPowerByName("max_health_wanderer"))

    -- grouped by category, sorted by name
    local sorted_categories = {}
    for k,_ in pairs(Power.Categories) do table.insert(sorted_categories, k) end
    sorted_categories = lume.sort(sorted_categories)
    local sorted_powers = {}
    for _,category in ipairs(sorted_categories) do
        local buffer = lume.filter(all_defs, function(def) return def.power_category == category end)
        buffer = lume.sort(buffer, function(a,b) return a.pretty.name < b.pretty.name end)
        for _,def in ipairs(buffer) do table.insert(sorted_powers, def) end
    end

    return sorted_powers
end

function wikiggutil.Wikitext.PowersTable()
    local Power = require "defs.powers"
    local itemforge = require "defs.itemforge"
    local lume = require "util.lume"
    
    local File = wikiggutil.Wikitext.File
    local MAP_LINKS = wikiggutil.Const.MAP_LINKS
    local StrRemapLinks = wikiggutil.Util.StrRemapLinks

    local powers = wikiggutil.Data.GetPowerDefs()
   
    local out = ""
    -- table start
    out = out.."{| class=\"wikitable sortable mw-collapsible\" style=\"width: 95%\"\n"
    out = out.."|-\n"
    out = out.."! style=\"width: 148px\" | Icon "
    out = out.."!! style=\"width: 20%\" | Name "
    out = out.."!! Description "
    out = out.."!! style=\"width: 10%\" | Tiers (Rarities) "
    out = out.."!! style=\"width: 8%\" | Category "
    out = out.."\n\n"

    for _,def in ipairs(powers) do
        -- get all rarities of power in ascending order
        local rarities = {}
        for i,rarity in ipairs(Power.Rarities._ordered_keys) do
            if def.tuning[rarity] ~= nil then
                table.insert(rarities, rarity)
            end
        end
        
        out = out.."|-\n"

        -- turns this
        -- images/ui_ftf_power_icons3/icon_shield_powers_shield_to_health.tex
        -- into this
        -- icon_shield_powers_shield_to_health.png
        local icon = def.icon or ""
        local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
        local filename = icon_base..".png"
        if #rarities > 1 then out = out.."| rowspan="..tostring(#rarities).." " end
        out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_LARGE).."\n"

        local name = def:GetPrettyName()
        local code_name = def.name or ""
        if #rarities > 1 then out = out.."| rowspan="..tostring(#rarities).." " end
        out = out.."| "..name.."<br><code>"..code_name.."</code>\n"

        -- multiple descriptions for multiple rarities
        local desc_strings = {}
        for _,rarity in ipairs(rarities) do
            local pwr = itemforge.CreatePower(def, rarity)
            local desc = Power.GetDescForPower(pwr)
            desc = desc:gsub("%b<>", "") -- strip out <> formatting (see kstring.lua)

            -- make specific words links to their own page
            desc = StrRemapLinks(desc, MAP_LINKS)

            table.insert(desc_strings, desc)
        end
        out = out.."| "..desc_strings[1].."\n"

        local rarities_formatted = rarities
        rarities_formatted = lume.map(rarities, function(r)
            local ret = r
            ret = string.lower(ret)
            ret = string.first_to_upper(ret)
            return ret
        end)
        local rarities_str = table.concat(rarities_formatted, ", ")
        if #rarities > 1 then out = out.."| rowspan="..tostring(#rarities).." " end
        out = out.."| "..rarities_str.."\n"

        local category = def.power_category or ""
        category = string.lower(category)
        category = string.first_to_upper(category)
        -- category = "[["..category.."]]"
        if #rarities > 1 then out = out.."| rowspan="..tostring(#rarities).." " end
        out = out.."| "..category.."\n"
        
        if #desc_strings > 1 then
            for i=2,#desc_strings do
                out = out.."|- \n"
                out = out.."| "..desc_strings[i].."\n"
            end
        end

        out = out.."\n"
    end

    out = out.."|}" -- table end

    return out
end

function wikiggutil.Data.GetGemDefs()
    local EquipmentGem = require "defs.equipmentgems.equipmentgem"
    local lume = require "util.lume"

    local all_defs = EquipmentGem.GetAllGems()
    -- filter out all hidden gems
    all_defs = lume.filter(all_defs, function(def) return not def.hide end)

    -- grouped by type, sorted by name
    local sorted_types = {}
    for k,_ in pairs(EquipmentGem.Type) do table.insert(sorted_types, k) end
    sorted_types = lume.sort(sorted_types)
    local sorted_gems = {}
    for _,gtype in ipairs(sorted_types) do
        local buffer = lume.filter(all_defs, function(def) return def.gem_type == gtype end)
        buffer = lume.sort(buffer, function(a,b) return a.pretty.name < b.pretty.name end)
        for _,def in ipairs(buffer) do table.insert(sorted_gems, def) end
    end

    return sorted_gems
end

function wikiggutil.Wikitext.GemsTable()
    local Power = require "defs.powers" -- read gem effect stats from gem power
    local itemutil = require "util.itemutil"

    local File = wikiggutil.Wikitext.File
    local Link = wikiggutil.Wikitext.Link
    local MAP_LINKS = wikiggutil.Const.MAP_LINKS
    local StrRemapLinks = wikiggutil.Util.StrRemapLinks

    local gems = wikiggutil.Data.GetGemDefs()

    local out = ""
    out = out.."{| class=\"wikitable\"\n" -- table start
    out = out.."|-\n"
    out = out.."! Icon !! Name !! Description !! α !! β !! γ !! Slot Match Bonus !! Type\n\n"

    for _,def in ipairs(gems) do
        out = out.."|-\n" 
        
        local icon = def.icon or ""
        local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
        local filename = icon_base..".png"
        out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_LARGE).."\n"

        local name = def.pretty and def.pretty.name or ""
        local code_name = def.name or ""
        local name_formatted = Link(name).."<br><code>"..code_name.."</code>"
        out = out.."| "..name_formatted.."\n"

        local desc = def.pretty and def.pretty.slotted_desc or ""
        desc = desc:gsub("%b<>", "") -- strip out <> formatting (see kstring.lua)
        -- make specific words links to their own page
        desc = StrRemapLinks(desc, MAP_LINKS)
        out = out.."| "..desc.."\n"

        local stat_str = {}
        local stat_str_bonus = nil

        local get_stats_from_gemdef = (
            (not def.tags.hide_stats)
            and def.stat_mods
            and (next(def.stat_mods) ~= nil)
        )

        local get_stats_from_power = (
            (not def.tags.hide_stats)
            and def.usage_data
            and def.usage_data.power_on_equip
        )

        if get_stats_from_gemdef then
            local stat_mods = def.stat_mods
            local stat_id = nil
            for id,val in pairs(stat_mods) do
                stat_id = id
                break
            end
            for i,val in ipairs(stat_mods[stat_id]) do
                stat_str[i] = itemutil.GetFormattedEquipmentStatValue(stat_id, val, true)
            end

            local slot_bonus = def.stat_mods_slot_bonus
            if slot_bonus then
                for stat_id,bonus in pairs(slot_bonus) do
                    stat_str_bonus = itemutil.GetFormattedEquipmentStatValue(stat_id, bonus, true)
                end
            end
        elseif get_stats_from_power then
            local gem_pow_def = Power.FindPowerByName(def.usage_data.power_on_equip)

            -- e.g: "damage_bonus" (for use in code)
            local var_inst = nil
            -- NOTE: all gem powers's tuning values are in the COMMON rarity
            -- (also see widgets/ftf/equipmentdescriptionwidget.lua)
            for id, stat_data in pairs(gem_pow_def.tuning[Power.Rarity.COMMON]) do
                var_inst = stat_data
                break
			end

            -- e.g: "Backstab Damage" (for displaying pretty effect name)
            -- but is currently unused in the table atm
            local stat_name = STRINGS.ITEMS.GEMS[def.name].stat_name
            
			local stacks = gem_pow_def.stacks_per_usage_level
            for i,val in ipairs(stacks) do
                stat_str[i] = var_inst:GetPrettyForStacks(val)
            end

            local bonus = gem_pow_def.slot_bonus_stacks
            if bonus then
                stat_str_bonus = var_inst:GetFormattedSlotBonusString(bonus)
            end
        end
        
        out = out.."| "..(stat_str[1] or "").."\n"
        out = out.."| "..(stat_str[2] or "").."\n"
        out = out.."| "..(stat_str[3] or "").."\n"
        out = out.."| "..(stat_str_bonus or "").."\n"

        local gem_type = def.gem_type or ""
        local gem_type_pretty = STRINGS.GEMS.SLOT_TYPE[gem_type] or ""
        -- (gibberish)
        --TODO: make the gem type a link to specific pages about them?
        -- (make_link())
        out = out.."| "..gem_type_pretty.."\n"

        out = out.."\n"
    end

    out = out.."|}" -- table end

    return out
end

function wikiggutil.Wikitext.GemsNavbox()
    local lume = require "util.lume"
    local EquipmentGem = require "defs.equipmentgems.equipmentgem"

    local Link = wikiggutil.Wikitext.Link

    local out = ""
    out = out.."{{Navbox\n" -- navbox start
    out = out.."| title = "..Link("Gems").."\n"
    out = out.."| state = uncollapsed\n\n"

    local gems = wikiggutil.Data.GetGemDefs()

    local sorted_types = {}
    for k,_ in pairs(EquipmentGem.Type) do table.insert(sorted_types, k) end
    sorted_types = lume.sort(sorted_types)

    local def_groups = {}
    local def_groups_gemtypes = {} -- table to map def_groups idx to gem type
    for _,gemtype in ipairs(sorted_types) do
        local gems_of_type = lume.filter(gems, function(def) return def.gem_type == gemtype end)
        if next(gems_of_type) ~= nil then
            table.insert(def_groups, gems_of_type)
            def_groups_gemtypes[#def_groups] = gemtype
        end
    end

    for group_idx,group in ipairs(def_groups) do
        local gemtype = def_groups_gemtypes[group_idx]
        local gemtype_pretty = STRINGS.GEMS.SLOT_TYPE[gemtype] or gemtype

        out = out.."| group"..tostring(group_idx).." = "..gemtype_pretty.."\n"
        out = out.."| list"..tostring(group_idx).." = "

        for i,def in ipairs(group) do
            local name = def.pretty and def.pretty.name or ""
            out = out..Link(name)
            
            local is_last_item = (i == #group)
            if not is_last_item then
                out = out.." • "
            end
        end

        out = out.."\n\n"
    end

    out = out.."}}\n" -- navbox end
    out = out.."<noinclude>[[Category:Navigation templates|{{PAGENAME}}]]</noinclude>\n"

    return out
end

-- town decors
function wikiggutil.Data.GetConstructables(filtertags)
    -- returns number indexed table so it can be easily sorted after
    -- (the key is the same as item.name anyway)
    -- filtertags is table of tags to include
    -- returns all items if no filtertags given

    local Constructable = require "defs.constructable"

    local all_items = {}
    local ordered_slots = shallowcopy(Constructable.GetOrderedSlots())
    for _, slot in ipairs(ordered_slots) do 
		local slot_items = Constructable.Items[slot]
        for key,item in pairs(slot_items) do
            all_items[key] = item
        end
	end

    local function item_has_tags_any(item, filtertags)
        for _,tag in ipairs(filtertags) do
            if item.tags[tag] then return true end
        end
        return false
    end

    local picked_items = {}
    for _,item in pairs(all_items) do
        if item_has_tags_any(item, filtertags) then
            table.insert(picked_items, item)
        end
    end

    return picked_items
end

function wikiggutil.Wikitext.ConstructablesTable()
    local lume = require "util.lume"
    local Constructable = require "defs.constructable"
    local Consumable = require "defs.consumable"

    local File = wikiggutil.Wikitext.File
    local FileLink = wikiggutil.Wikitext.FileLink

    -- this is so janky but i managed to make it work, i am so proud of myself now
    -- (see screens/town/craftscreenmulti.lua -> function CraftSinglePanel:_AddTabs())
    local UpvalueHacker = require "tools.upvaluehacker"
    local CraftScreenMulti = require "screens.town.craftscreenmulti"
    local CraftSinglePanel = UpvalueHacker.GetUpvalue(CraftScreenMulti._ctor, "CraftSinglePanel")
    local dummy_CSP = {
        tab_buttons = {},
        tabs = {
            SetTabSpacing = function(self) return self end,
            Layout = function(self) return self end,
            AddTextTab = function() return { -- dummy tabwidget
                SetStarIcon = function(self) return self end,
                AddClaimableIcon = function(self) return self end,
                category = nil,
                tags = nil,
                tab_idx = nil,
            } end,
        },
        GetOrderedTabs = function(self)
            local ordered_tabwidgets = {}
            for category,tabwidget in pairs(self.tab_buttons) do
                table.insert(ordered_tabwidgets, tabwidget)
            end
            ordered_tabwidgets = lume.sort(ordered_tabwidgets, function(a,b)
                return a.tab_idx < b.tab_idx
            end)

            local res = {}
            for _,tabwidget in ipairs(ordered_tabwidgets) do
                table.insert(res, {
                    category = tabwidget.category,
                    tags = tabwidget.tags
                })
            end

            return res
        end,
    }
    CraftSinglePanel._AddTabs(dummy_CSP)
    local tabs = dummy_CSP:GetOrderedTabs()

    local tab_keys_ordered = {}
    local all_tab_items = {}
    for _,tab in ipairs(tabs) do
        table.insert(tab_keys_ordered, tab.category)

        local defs = wikiggutil.Data.GetConstructables(tab.tags)
        defs = lume.sort(defs, function(a,b) return a.pretty.name < b.pretty.name end)

        all_tab_items[tab.category] = defs
    end

    local out = ""
    out = out.."{| class=\"wikitable\"\n" -- table start
    out = out.."|-\n"
    out = out.."! Icon !! Name !! Ingredients !! Grid Size !! First Craft Bounty\n\n"

    for _,tab_key in ipairs(tab_keys_ordered) do
        local tab_items = all_tab_items[tab_key]

        -- tab key row
        out = out.."|-\n" 
        out = out.."! colspan=5 | "..tab_key.."\n"

        for _,def in ipairs(tab_items) do
            out = out.."|-\n" -- row

            local icon = def.icon or ""
            local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
            local filename = icon_base..".png"
            out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_MID).."\n"

            local name = def.pretty and def.pretty.name or ""
            out = out.."| "..name.."\n"

            local ingredient_strings = {}
            if def.ingredients ~= nil then
                for ingredient_key,amount in pairs(def.ingredients) do
                    local ingredient_def = Consumable.FindItem(ingredient_key)
                    local name = ingredient_def.pretty and ingredient_def.pretty.name or ingredient_key

                    local icon = ingredient_def.icon or ""
                    local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
                    local filename = icon_base..".png"

                    local name_str = FileLink(name, nil, filename, wikiggutil.Const.ICON_SIZE_SMALL)
                    local amount_str = "x"..tostring(amount)

                    local str = name_str.." "..amount_str
                    table.insert(ingredient_strings, str)
                end
            end
            local formatted_ingredients = table.concat(ingredient_strings, ", ")
            out = out.."| "..formatted_ingredients.."\n"

            local gridsize_w = def.gridsize and def.gridsize.w or 1
	        local gridsize_h = def.gridsize and def.gridsize.h or 1
            local gridsize_text = tostring(gridsize_w).."x"..tostring(gridsize_h)
            out = out.."| "..gridsize_text.."\n"

            local reward_id, amount = Constructable.GetFirstCraftBounty(def)
	        local reward_def = Consumable.FindItem(reward_id)
            local name = reward_def.pretty and reward_def.pretty.name or reward_id
            local icon = reward_def.icon or ""
            local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
            local filename = icon_base..".png"
            local name_str = FileLink(name, nil, filename, wikiggutil.Const.ICON_SIZE_SMALL)
            local amount_str = "x"..tostring(amount)
            local craft_bounty_str = name_str.." "..amount_str
            out = out.."| "..craft_bounty_str.."\n"
        end

        out = out.."\n"
    end

    out = out.."|}" -- table end

    return out
end

function wikiggutil.Data.GetBiomeExplorationRewards()
    local MetaProgress = require "defs.metaprogression.metaprogress"
    local all_rewards = MetaProgress.Items[MetaProgress.Slots.BIOME_EXPLORATION]
    return all_rewards -- the wikitext function will handle sorting out this data
end

function wikiggutil.Wikitext.BiomeExplorationRewardsTable()
    local Biomes = require "defs.biomes"

    local Link = wikiggutil.Wikitext.Link
    local RewardToString = wikiggutil.Wikitext.RewardToString

    local locations_ordered = Biomes.location_unlock_order
    local all_progression_rewards = wikiggutil.Data.GetBiomeExplorationRewards()

    local out = ""
    out = out.."{| class=\"wikitable\"\n" -- table start
    out = out.."|-\n"
    out = out.."! Location !! Level !! Rewards\n\n"

    for _,location_def in ipairs(locations_ordered) do
        -- every location's biome exploration rewards (progressionmotherseed)
        --   will generally include the following:
        -- + endless_reward (type: MetaProgress.Reward)
        -- + rewards (type: number indexed table of MetaProgress.RewardGroup,
        --   each item includes multiple MetaProgress.Reward (s))

        -- - MetaProgress.Reward can be of different types
        --   (Power, Cosmetic, Constructable, Consumable).
        -- and they dont make it clear what type a Reward is, you just gotta
        --   check it's slot (reward.def.slot)
        --   (see function MetaProgress.Reward:UnlockRewardForPlayer
        --   in metareward.lua for more details).

        -- for this one i will collect all data first before writing them out to a table

        local progression = all_progression_rewards[location_def.id]

        local endless_reward = progression.endless_reward
        local rewards = progression.rewards
        local max_level = #progression.rewards -- (e.g: 5)
        local rows = max_level+1 -- 1 more row for endless reward

        -- number indexed table, starting from 0 (0 is for endless reward)
        -- containing formatted reward strings, wikitext ready
        local reward_strings = {}
        reward_strings[0] = RewardToString(endless_reward)
        for idx_lvl=1,max_level do
            local individual_reward_strings = {}
            local reward_group = rewards[idx_lvl]
            local individual_rewards = reward_group:GetRewards()
            for _,reward in ipairs(individual_rewards) do
                table.insert(individual_reward_strings, RewardToString(reward))
            end
            reward_strings[idx_lvl] = table.concat(individual_reward_strings, ", ")
        end

        -- generate table

        local location_name_pretty = location_def.pretty and location_def.pretty.name or location_def.id
        out = out.."|-".."\n"
        out = out.."| rowspan="..tostring(rows).." "
        out = out.."| "..Link(location_name_pretty).."\n"

        for idx_lvl=1,max_level do
            if idx_lvl > 1 then
                out = out.."|-".."\n"
            end

            out = out.."| "..tostring(idx_lvl).."\n"
            out = out.."| "..reward_strings[idx_lvl].."\n"
        end
        out = out.."|-".."\n"
        out = out.."| ".."∞".."\n"
        out = out.."| "..reward_strings[0].."\n"

        out = out.."\n"
    end

    out = out.."|}" -- table end

    return out
end

function wikiggutil.Data.GetFoodDefs()
    -- return number indexed, sorted table (by pretty name) of all food
    local Food = require "defs.food"
    local lume = require "util.lume"

    local all_defs = Food.GetAllItems()
    all_defs = lume.sort(all_defs, function(a, b)
        local name_a = a.pretty and a.pretty.name or a.name
        local name_b = b.pretty and b.pretty.name or b.name
        return name_a < name_b
    end)

    return all_defs
end

function wikiggutil.Wikitext.FoodTable()
    local Consumable = require "defs.consumable"
    local Power = require "defs.powers"
    local File = wikiggutil.Wikitext.File
    local Link = wikiggutil.Wikitext.Link
    local FileLink = wikiggutil.Wikitext.FileLink

    local all_defs = wikiggutil.Data.GetFoodDefs()

    local out = ""
    out = out.."{| class=\"wikitable sortable\"\n" -- table start
    out = out.."|-\n"
    out = out.."! Icon !! Name !! Description !! Power !! Ingredients !! Purchasable period (days) || Stock available || Restock cooldown (days)\n\n"

    for _,def in ipairs(all_defs) do
        out = out.."|-\n" -- row

        local icon = def.icon or ""
        local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
        local filename = icon_base..".png"
        out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_MID).."\n"

        local name = def.pretty and def.pretty.name or ""
        out = out.."| "..name.."\n"
        
        local desc = def.pretty and def.pretty.desc or ""
        out = out.."| "..desc.."\n"

        local power_def = Power.FindPowerByName(def.power)
        do
            local icon = power_def.icon or ""
            local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
            local filename = icon_base..".png"

            local name = power_def:GetPrettyName()

            out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_SMALL)..Link(name).."\n"
        end

        local ingredient_strings = {}
        if def.ingredients ~= nil then
            for _,ingredient in ipairs(def.ingredients) do
                local ingredient_key = ingredient.name
                local amount = ingredient.count
                local ingredient_def = Consumable.FindItem(ingredient_key)
                local name = ingredient_def.pretty and ingredient_def.pretty.name or ingredient_key

                local icon = ingredient_def.icon or ""
                local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
                local filename = icon_base..".png"

                local name_str = FileLink(name, nil, filename, wikiggutil.Const.ICON_SIZE_SMALL)
                local amount_str = "x"..tostring(amount)

                local str = name_str.." "..amount_str
                table.insert(ingredient_strings, str)
            end
        end
        local formatted_ingredients = table.concat(ingredient_strings, ", ")
        out = out.."| "..formatted_ingredients.."\n"

        
        if def.menu_data then -- the ones without stock and cooldown are permanent dishes
            -- (explanation from food.lua)
            -- time_available: min and max of how many days the food will be available for purchase
            local time_available = def.menu_data.time_available
            local time_available_str = tostring(time_available[1])
            if time_available[1] ~= time_available[2] then
                time_available_str = time_available_str.."-"..tostring(time_available[2])
            end

            -- num_available: min and max of how many times the food can be bought when it is on the menu
            local num_available = def.menu_data.num_available
            local num_available_str = tostring(num_available[1])
            if num_available[1] ~= num_available[2] then
                num_available_str = num_available_str.."-"..tostring(num_available[2])
            end

            -- menu_cooldown: how many days before the food can be added to the menu again
            local menu_cooldown = def.menu_data.menu_cooldown
            local menu_cooldown_str = tostring(menu_cooldown[1])
            if menu_cooldown[1] ~= menu_cooldown[2] then
                menu_cooldown_str = menu_cooldown_str.."-"..tostring(menu_cooldown[2])
            end

            out = out.."| style=\"text-align:center;\" "
            out = out.."| "..time_available_str.."\n"
            out = out.."| style=\"text-align:center;\" "
            out = out.."| "..num_available_str.."\n"
            out = out.."| style=\"text-align:center;\" "
            out = out.."| "..menu_cooldown_str.."\n"
        else
            out = out.."| colspan=3 style=\"text-align:center;\" | ".."Permanent Food".."\n"
        end
        
    end

    out = out.."|}" -- table end

    return out
end

function wikiggutil.Data.GetMasteries(mastery_type)
    -- returns SORTED number indexed table so it can be easily sorted after
    -- (the key is the same as item.name anyway)
    -- returns all items if no mastery_type given

    local Mastery = require "defs.mastery.mastery"

    local all_items = {}
    local ordered_slots = shallowcopy(Mastery.GetOrderedSlots())
    for _, slot in ipairs(ordered_slots) do 
		local slot_items = Mastery.Items[slot]
        for key,item in pairs(slot_items) do
            table.insert(all_items, item)
        end
	end

    local picked_items

    if not mastery_type then
        picked_items = all_items
    else
        picked_items = {}
        for _,item in ipairs(all_items) do
            if item.mastery_type == mastery_type then
                table.insert(picked_items, item)
            end
        end
    end

    local lume = require "util.lume"
    picked_items = lume.sort(picked_items, function(a, b)
        return a.order < b.order -- property of a mastery def
    end)

    return picked_items
end

function wikiggutil.Wikitext.MasteriesTable()
    --NOTE (PLEASE READ): mastery strings has many special elements
    -- so text from this generated table WILL NEED MANUAL CLEANUP
    -- before pushing to wiki

    local Mastery = require "defs.mastery.mastery"
    local lume = require "util.lume"
    local itemforge = require "defs.itemforge"

    local MAP_LINKS = wikiggutil.Const.MAP_LINKS
    local File = wikiggutil.Wikitext.File
    local StrRemapLinks = wikiggutil.Util.StrRemapLinks
    local FormattedString = wikiggutil.Wikitext.FormattedString
    local RewardToString = wikiggutil.Wikitext.RewardToString

    local UpvalueHacker = require "tools.upvaluehacker"
    local MasteryScreenMulti = require "screens.town.masteryscreenmulti"
    local MasterySinglePanel = UpvalueHacker.GetUpvalue(MasteryScreenMulti._ctor, "MasterySinglePanel")
    
    local dummy_player = CreateEntity() -- will be removed after this section
    dummy_player:AddComponent("unlocktracker")
    dummy_player.components.unlocktracker.IsWeaponTypeUnlocked = function(self, id)
        return true
    end

    local dummy_panel = {
        GetOwningPlayer = function(self) return dummy_player end,
        ShouldShowMastery = function(self) return true end,
        tab_buttons = {},
        tabs = {
            num_tabs = 0,
            SetTabSpacing = function(self) return self end,
            Layout = function(self) return self end,
            AddTextTab = function(tab_self, icon, size)
                tab_self.num_tabs = tab_self.num_tabs + 1
                local ret
                ret = { -- dummy tabwidget
                    icon = icon,
                    icon_size = size,
                    SetToolTip = function(ret_self, tooltip) ret_self.tooltip = tooltip; return ret_self end,
                    SetStarIcon = function(ret_self) return ret_self end,
                    AddClaimableIcon = function(ret_self) return ret_self end,
                    category = nil, -- mastery_type
                    tab_idx = tab_self.num_tabs,
                }
                return ret
            end,
        },
        GetOrderedTabs = function(self)
            local ordered_tabwidgets = {}
            for category,tabwidget in pairs(self.tab_buttons) do
                table.insert(ordered_tabwidgets, tabwidget)
            end
            ordered_tabwidgets = lume.sort(ordered_tabwidgets, function(a,b)
                return a.tab_idx < b.tab_idx
            end)

            local res = {}
            for _,tabwidget in ipairs(ordered_tabwidgets) do
                table.insert(res, {
                    category = tabwidget.category,
                    tooltip = tabwidget.tooltip,
                })
            end

            return res
        end,
    }
    MasterySinglePanel._RefreshTabs(dummy_panel)
    local tabs = dummy_panel:GetOrderedTabs()
    dummy_player:Remove()

    local tab_keys_ordered = {}
    local tab_keys_pretty = {}
    local all_tab_items = {}
    for _,tab in ipairs(tabs) do
        table.insert(tab_keys_ordered, tab.category)
        tab_keys_pretty[tab.category] = tab.tooltip

        local defs = wikiggutil.Data.GetMasteries(tab.category)
        all_tab_items[tab.category] = defs
    end

    -- d_view(tab_keys_ordered)
    -- d_view(all_tab_items)
    
    local out = ""
    out = out.."{| class=\"wikitable sortable\"\n" -- table start
    out = out.."|-\n"
    out = out.."! Icon !! Name !! Description !! Max Progress !! Rewards !! Difficulty\n\n"

    for _,tab_key in ipairs(tab_keys_ordered) do
        local tab_items = all_tab_items[tab_key]
       
        -- tab key row
        out = out.."|-\n" 
        out = out.."! colspan=6 | "..tab_keys_pretty[tab_key].."\n"

        for _,def in ipairs(tab_items) do
            out = out.."|-\n" -- row

            local icon = def.icon or ""
            local _, icon_base = string.match(icon, "(.*)%/(.*).tex")
            local filename = icon_base..".png"
            out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_MID).."\n"

            local name = def.pretty and def.pretty.name or ""
            name = FormattedString(name)
            out = out.."| "..name.."\n"

            local mastery_inst = itemforge.CreateMastery(def)
            local desc = Mastery.GetDesc(mastery_inst) -- fill in tuning placeholders in desc strings
            desc = StrRemapLinks(desc, MAP_LINKS)
            desc = FormattedString(desc)
            out = out.."| "..desc.."\n"

            local max_progress = def.max_progress
            out = out.."| "..tostring(max_progress).."\n"

            local reward_strings = {}
            -- table ({}) of MetaProgress.Reward
            for _,reward in ipairs(def.rewards) do
                table.insert(reward_strings, RewardToString(reward))
            end
            local rewards_string = table.concat(reward_strings, ", ")
            out = out.."| "..rewards_string.."\n"
            
            local difficulty = def.difficulty
            difficulty = string.lower(difficulty)
            difficulty = string.first_to_upper(difficulty)
            out = out.."| "..difficulty.."\n"
        end

        out = out.."\n"
    end

    out = out.."|}" -- table end

    return out
end

return wikiggutil
