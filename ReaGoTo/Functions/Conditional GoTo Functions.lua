_G.ConditionalJumps = _G.ConditionalJumps or {}

_G_AdaptiveParams = _G_AdaptiveParams or {}
local AdaptiveParams = _G_AdaptiveParams

-- Update param values, called by AdaptiveHost
function SetAdaptiveParamValue(param_name, value)
    AdaptiveParams[param_name] = tonumber(value)
end

-- Checks, such as 'a > 0.5'
function EvaluateCondition(param_value, op, value)
    if op == ">" then return param_value > value
    elseif op == "<" then return param_value < value
    elseif op == ">=" then return param_value >= value
    elseif op == "<=" then return param_value <= value
    elseif op == "==" then return param_value == value
    elseif op == "!=" or op == "~=" then return param_value ~= value
    else return false end
end

-- Check, perform jumps
function CheckConditionalJumps(current_region)
    for _, rule in ipairs(_G.ConditionalJumps or {}) do
        if rule.from == current_region then
            local param_value = AdaptiveParams[rule.param]
            if param_value and EvaluateCondition(param_value, rule.op, tonumber(rule.value)) then
                GoTo("goto" .. GetRegionIndexByName(rule.to), 0)
                return true
            end
        end
    end
end

-- Divided UI: Top half, regions, same as regular GoTo. Bottom half, conditional jumps.
function PlaylistAndConditionalJumpUI(playlist, ctx)
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    local half_y = avail_y / 2

    local is_save = false

    -- Top half: Region list
    if reaper.ImGui_BeginChild(ctx, "RegionList", avail_x, half_y, true) then
        is_save = PlaylistTab(playlist) or is_save
        reaper.ImGui_EndChild(ctx)
    end

    -- Bottom half: Conditional jumps
    if reaper.ImGui_BeginChild(ctx, "ConditionalJumps", avail_x, -FLTMIN, true) then
        ConditionalJumpsUI(ctx, playlist)
        reaper.ImGui_EndChild(ctx)
    end

    return is_save
end

-- Conditional Jumps UI
function ConditionalJumpsUI(ctx, playlist)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Conditional Jumps')

    if reaper.ImGui_Button(ctx, '+') then
        _G.ConditionalJumps[#_G.ConditionalJumps + 1] = {
            from = '',
            to = '',
            param = '',
            op = '>',
            value = '0',
        }
    end

    if not playlist then return end
    
     -- Gather region names for 'from'
     local from_names = {}
     for i = 0, reaper.CountProjectMarkers(0) - 1 do
         local _, isrgn, _, _, name = reaper.EnumProjectMarkers(i)
         if isrgn == true and name and name ~= '' then
             table.insert(from_names, name)
         end
     end
 
     -- Gather all region/marker names from the project for 'to'
     local to_names = {}
     for i = 0, reaper.CountProjectMarkers(0) - 1 do
         local _, _, _, _, name = reaper.EnumProjectMarkers(i)
         if name and name ~= '' then
             table.insert(to_names, name)
         end
     end
 
     for i = #_G.ConditionalJumps, 1, -1 do
         local jump = _G.ConditionalJumps[i]
 
         reaper.ImGui_PushID(ctx, i)
 
         -- FROM region (no arrow button)
         reaper.ImGui_SetNextItemWidth(ctx, 60)
         if reaper.ImGui_BeginCombo(ctx, '##From'..i, jump.from ~= '' and jump.from or 'Any', reaper.ImGui_ComboFlags_NoArrowButton()) then
             if reaper.ImGui_Selectable(ctx, 'Any', jump.from == 'Any') then
                 jump.from = 'Any'
             end
             for _, name in ipairs(from_names) do
                 if reaper.ImGui_Selectable(ctx, name, jump.from == name) then
                     jump.from = name
                     if jump.to == name then
                         jump.to = ''
                     end
                 end
             end
             reaper.ImGui_EndCombo(ctx)
         end
 
         reaper.ImGui_SameLine(ctx)
         reaper.ImGui_Text(ctx, 'to')
         reaper.ImGui_SameLine(ctx)
 
         -- TO region or marker (excluding same as FROM)
         reaper.ImGui_SetNextItemWidth(ctx, 60)
         if reaper.ImGui_BeginCombo(ctx, '##To'..i, jump.to ~= '' and jump.to or '', reaper.ImGui_ComboFlags_NoArrowButton()) then
             for _, name in ipairs(to_names) do
                 if name ~= jump.from then
                     if reaper.ImGui_Selectable(ctx, name, jump.to == name) then
                         jump.to = name
                     end
                 end
             end
             reaper.ImGui_EndCombo(ctx)
         end
 
         reaper.ImGui_SameLine(ctx)
         reaper.ImGui_Text(ctx, 'if')
         reaper.ImGui_SameLine(ctx)

        -- PARAM name input
        reaper.ImGui_SetNextItemWidth(ctx, 20)
        _, jump.param = reaper.ImGui_InputText(ctx, '##Param'..i, jump.param or '')
        reaper.ImGui_SameLine(ctx)

        -- OPERATOR combo (no arrow button)
        local operators = { '>', '<', '>=', '<=', '==', '!=' }
        reaper.ImGui_SetNextItemWidth(ctx, 20)
        if reaper.ImGui_BeginCombo(ctx, '##Op'..i, jump.op or '>', reaper.ImGui_ComboFlags_NoArrowButton()) then
            for _, op in ipairs(operators) do
                if reaper.ImGui_Selectable(ctx, op, jump.op == op) then
                    jump.op = op
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        -- VALUE input
        reaper.ImGui_SetNextItemWidth(ctx, 20)
        _, jump.value = reaper.ImGui_InputText(ctx, '##Value'..i, tostring(jump.value or ''))
        reaper.ImGui_SameLine(ctx)

        -- Transition and Delete buttons
        if reaper.ImGui_Button(ctx, 'Transition##'..i) then
            if jump.from and jump.from ~= "Any" then
                current_region = jump.from
                selected_target_region = jump.to
                reaper.ImGui_OpenPopup(ctx, '##renameinput')
            end
        end

        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'X##'..i) then
            table.remove(_G.ConditionalJumps, i)
            reaper.ImGui_PopID(ctx)
            goto continue
        end

        reaper.ImGui_PopID(ctx)
        ::continue::
    end
end
