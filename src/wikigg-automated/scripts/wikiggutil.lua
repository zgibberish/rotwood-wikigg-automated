--[[
    using ingame console:
    imgui:SetClipboardText(wikiggutil.Wikitext.PowersTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.GemsTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.GemsNavbox())
    imgui:SetClipboardText(wikiggutil.Wikitext.ConstructablesTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.BiomeExplorationRewardsTable())
    imgui:SetClipboardText(wikiggutil.Wikitext.FoodTable())
]]

local wikiggutil = {}
wikiggutil.Const = {}
wikiggutil.Util = {}
wikiggutil.Data = {}
wikiggutil.Wikitext = {}

-- map specific words to specific pages
-- you can map different strings to the same page link
wikiggutil.Const.MAP_LINKS = {
    -- (match : destination override)
    -- (matches are case sensitive)
    ["Focus"] = "Focus Hits",
    ["Critical"] = "Critical Hits",
    ["Runspeed"] = true,
    ["Teffra"] = true,
    ["Shield"] = true,
    ["Perfect Dodge"] = true,
    ["Quick Rise"] = true,
    ["Traps"] = true,
    ["Fortifying Ingots"] = true,
}
wikiggutil.Const.ICON_SIZE = 128 -- used for stuff like power/gems icons in tables
wikiggutil.Const.ICON_SIZE_CONSTRUCTABLES = 64
wikiggutil.Const.ICON_SIZE_SMALL = 24 -- used for stuff like ingredient icons (inline)

-- turns every occurrence of "abc" in provided string into a link ( [[]] )
-- that shows "abc" and links to remap_table["abc"] (override) or just "abc".
function wikiggutil.Util.str_remap_tolinks(str, remap_table)
    local Link = wikiggutil.Wikitext.Link

    local ret = ""..str

    for match, dest in pairs(remap_table) do
        local replace = (type(dest) == "string")
            and Link(match, dest)
            or Link(match)
        ret = string.gsub(ret, match, replace)
    end

    return ret
end

function wikiggutil.Wikitext.Link(str, dest)
    if dest then
        return "[["..dest.."|"..str.."]]"
    end
    return "[["..str.."]]"
end

function wikiggutil.Wikitext.File(filename, size)
    local size_opt = size and "|"..tostring(size).."px" or ""
    return "[[File:"..filename..size_opt.."]]"
end

function wikiggutil.Wikitext.FileLink(str, dest, filename, size)
    -- file (image) that is a clickable link to a specific destination
    local link_str = wikiggutil.Wikitext.Link(str, dest)
    local size_opt = size and "|"..tostring(size).."px" or ""
    return "[[File:"..filename..size_opt.."|link="..link_str.."]]"
end

function wikiggutil.Data.GetPowerDefs()
    local Power = require "defs.powers"
    local lume = require "util.lume"
    local PowerDropManager = require "components.powerdropmanager"

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
    -- (gibberish)
    --NOTES
    --[[
        extract and upload power icons
        + get rotwood textool (https://github.com/zgibberish/rwtextool)
        $ git clone https://github.com/zgibberish/rwtextool
        $ python -m venv rwtextool/venv
        $ source rwtextool/venv/bin/activate
        $ pip install PyTexturePacker pillow
        + get data.zip from game files
        $ unzip data.zip "images/ui_ftf_power_icons*" 
        $ find images/ui_ftf_power_icons*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
        $ find images/*.* | xargs rm # remove tex and atlas files
        $ find images/ui_ftf_power_icons*/* | xargs -I {} mv {} images/ # move all pngs out
        $ find images/*/ -type d | xargs rm -r # remove remaining folders
        + upload the whole images/ folder to wiki.gg
    ]]

    
    local Power = require "defs.powers"
    local itemforge = require "defs.itemforge"
    local str_remap_tolinks = wikiggutil.Util.str_remap_tolinks
    local MAP_LINKS = wikiggutil.Const.MAP_LINKS

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
        out = out.."| "..wikiggutil.Wikitext.File(filename, wikiggutil.Const.ICON_SIZE).."\n"

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
            desc = str_remap_tolinks(desc, MAP_LINKS)

            table.insert(desc_strings, desc)
        end
        out = out.."| "..desc_strings[1].."\n"

        local rarities_formatted = rarities
        -- local rarities_formatted = lume.map(rarities, function(r) return "[["..r.."]]" end)
        local rarities_str = table.concat(rarities_formatted, ", ")
        if #rarities > 1 then out = out.."| rowspan="..tostring(#rarities).." " end
        out = out.."| "..rarities_str.."\n"

        local category = def.power_category or ""
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
    -- (gibberish)
    --NOTES
    --[[
        extract and upload gem icons
        + get rotwood textool (https://github.com/zgibberish/rwtextool)
        $ git clone https://github.com/zgibberish/rwtextool
        $ python -m venv rwtextool/venv
        $ source rwtextool/venv/bin/activate
        $ pip install PyTexturePacker pillow
        + get data.zip from game files
        $ unzip data.zip "images/icons_inventory*" 
        $ find images/icons_inventory*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
        $ find images/*.* | xargs rm # remove tex and atlas files
        $ find images/*/icon_gem_* | xargs -I {} mv {} images/ # move all pngs out
        $ find images/*/ -type d | xargs rm -r # remove remaining folders
        + upload the whole images/ folder to wiki.gg
    ]]

    local Power = require "defs.powers" -- read gem effect stats from gem power
    local itemutil = require"util.itemutil"
    local Link = wikiggutil.Wikitext.Link
    local MAP_LINKS = wikiggutil.Const.MAP_LINKS
    local str_remap_tolinks = wikiggutil.Util.str_remap_tolinks

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
        out = out.."| "..wikiggutil.Wikitext.File(filename, wikiggutil.Const.ICON_SIZE).."\n"

        local name = def.pretty and def.pretty.name or ""
        local code_name = def.name or ""
        local name_formatted = Link(name).."<br><code>"..code_name.."</code>"
        out = out.."| "..name_formatted.."\n"

        local desc = def.pretty and def.pretty.slotted_desc or ""
        desc = desc:gsub("%b<>", "") -- strip out <> formatting (see kstring.lua)
        -- make specific words links to their own page
        desc = str_remap_tolinks(desc, MAP_LINKS)
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
    local EquipmentGem = require "defs.equipmentgems.equipmentgem"
    local lume = require "util.lume"
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
function wikiggutil.Data:GetConstructables(filtertags)
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
    -- (gibberish)
    --NOTES
    --[[
        extract and upload prop icons
        + get rotwood textool (https://github.com/zgibberish/rwtextool)
        $ git clone https://github.com/zgibberish/rwtextool
        $ python -m venv rwtextool/venv
        $ source rwtextool/venv/bin/activate
        $ pip install PyTexturePacker pillow
        + get data.zip from game files
        $ unzip data.zip "images/inv_town_decoration*" 
        $ find images/inv_town_decoration*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
        $ find images/*.* | xargs rm # remove tex and atlas files
        $ find images/*/town_prop_* | xargs -I {} mv {} images/ # move all pngs out
        $ find images/*/ -type d | xargs rm -r # remove remaining folders
        + upload the whole images/ folder to wiki.gg

        + For ingredient icons just upload all icons_inventory tex :/
    ]]

    local lume = require "util.lume"
    local Constructable = require "defs.constructable"
    local Consumable = require"defs.consumable"
    local FileLink = wikiggutil.Wikitext.FileLink

    -- this is so janky but i managed to make it work, i am so proud of myself now
    -- (see screens/town/craftscreenmulti.lua -> function CraftSinglePanel:_AddTabs())
    local UpvalueHacker = require("tools.upvaluehacker")
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

        local defs = wikiggutil.Data:GetConstructables(tab.tags)
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
            out = out.."| "..wikiggutil.Wikitext.File(filename, wikiggutil.Const.ICON_SIZE_CONSTRUCTABLES).."\n"

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
    local Consumable = require"defs.consumable"
    local Power = require"defs.powers"
    local Constructable = require"defs.constructable"
    local Cosmetic = require "defs.cosmetics.cosmetics"
    local Equipment = require "defs.equipment"
    local File = wikiggutil.Wikitext.File
    local Link = wikiggutil.Wikitext.Link
    local FileLink = wikiggutil.Wikitext.FileLink

    local locations_ordered = Biomes.location_unlock_order
    local all_progression_rewards = wikiggutil.Data.GetBiomeExplorationRewards()

    local out = ""
    out = out.."{| class=\"wikitable\"\n" -- table start
    out = out.."|-\n"
    out = out.."! Location !! Level !! Rewards\n\n"

    local function formatted_reward_string(reward)
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
        reward_strings[0] = formatted_reward_string(endless_reward)
        for idx_lvl=1,max_level do
            local individual_reward_strings = {}
            local reward_group = rewards[idx_lvl]
            local individual_rewards = reward_group:GetRewards()
            for _,reward in ipairs(individual_rewards) do
                table.insert(individual_reward_strings, formatted_reward_string(reward))
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
-- (gibberish)
    --NOTES
    --[[
        extract and upload food icons
        + get rotwood textool (https://github.com/zgibberish/rwtextool)
        $ git clone https://github.com/zgibberish/rwtextool
        $ python -m venv rwtextool/venv
        $ source rwtextool/venv/bin/activate
        $ pip install PyTexturePacker pillow
        + get data.zip from game files
        $ unzip data.zip "images/icons_inventory*" 
        $ find images/icons_inventory*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
        $ find images/*.* | xargs rm # remove tex and atlas files
        $ find images/*/*food_cooked* | xargs -I {} mv {} images/ # move all pngs out
        $ find images/*/ -type d | xargs rm -r # remove remaining folders
        + upload the whole images/ folder to wiki.gg

        get temp item icon too if needed
        $ unzip data.zip "images/icons_ftf.*" 
        $ python rwtextool/src/tex2img.py -A images/icons_ftf.tex
        $ find images/*.* | xargs rm # remove tex and atlas files
        $ mv images/icons_ftf/item_temp.png images/ # move png out
        $ find images/*/ -type d | xargs rm -r # remove remaining folders
        + upload the whole images/ folder to wiki.gg
    ]]

    local Consumable = require"defs.consumable"
    local Power = require"defs.powers"
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
        out = out.."| "..File(filename, wikiggutil.Const.ICON_SIZE_CONSTRUCTABLES).."\n"

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

return wikiggutil
