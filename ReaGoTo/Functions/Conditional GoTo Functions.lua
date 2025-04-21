
_G_ConditionalJumps = _G_ConditionalJumps or {}
local ConditionalJumps = _G_ConditionalJumps

_G_AdaptiveParams = _G_AdaptiveParams or {}
local AdaptiveParams = _G_AdaptiveParams


-- Update param values, called by AdaptiveHost
-- Desde AdaptiveHost: SetAdaptiveParamValue(param_name, value)
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
    for _, rule in ipairs(ConditionalJumps) do
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
function PlaylistAndConditionalJumpUI(ctx)
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    local half_y = avail_y / 2

    local is_save = false

    -- Parte superior: regiones
    if reaper.ImGui_BeginChild(ctx, "RegionList", avail_x, half_y, true) then
        is_save = PlaylistTab(ProjConfigs[FocusedProj].playlists[ProjConfigs[FocusedProj].current]) or is_save
        reaper.ImGui_EndChild(ctx)
    end

    -- Parte inferior: condicionales
    if reaper.ImGui_BeginChild(ctx, "ConditionalJumps", avail_x, -FLT_MIN, true) then
        ConditionalJumpsUI(ctx)
        reaper.ImGui_EndChild(ctx)
    end

    return is_save
end


-- Conditional Jumps UI
function ConditionalJumpsUI(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Conditional Jumps')

    if reaper.ImGui_Button(ctx, '+') then
        table.insert(ConditionalJumps, { from = '', to = '', param = '', op = '>', value = '0' })
    end

    local playlist = ProjConfigs[FocusedProj] and ProjConfigs[FocusedProj].playlists and ProjConfigs[FocusedProj].playlists[ProjConfigs[FocusedProj].current]
    if not playlist then return end

    local region_names = {}
    for i, region in ipairs(playlist) do
        if region.name and region.name ~= '' then
            table.insert(region_names, region.name)
        end
    end

    for i = #ConditionalJumps, 1, -1 do
        local jump = ConditionalJumps[i]
        reaper.ImGui_PushID(ctx, i)

        reaper.ImGui_SetNextItemWidth(ctx, 100)
        if reaper.ImGui_BeginCombo(ctx, 'From##'..i, jump.from ~= '' and jump.from or 'Select region') then
            if reaper.ImGui_Selectable(ctx, 'Any', jump.from == 'Any') then
                jump.from = 'Any'
            end
            for _, name in ipairs(region_names) do
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
        reaper.ImGui_Text(ctx, '→')
        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_SetNextItemWidth(ctx, 100)
        if reaper.ImGui_BeginCombo(ctx, 'To##'..i, jump.to ~= '' and jump.to or 'Select region') then
            for _, name in ipairs(region_names) do
                if name ~= jump.from then
                    if reaper.ImGui_Selectable(ctx, name, jump.to == name) then
                        jump.to = name
                    end
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end

        reaper.ImGui_Text(ctx, 'if')
        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_SetNextItemWidth(ctx, 80)
        _, jump.param = reaper.ImGui_InputText(ctx, 'Param##'..i, jump.param or '')
        reaper.ImGui_SameLine(ctx)

        local operators = { '>', '<', '>=', '<=', '==', '!=' }
        reaper.ImGui_SetNextItemWidth(ctx, 40)
        if reaper.ImGui_BeginCombo(ctx, 'Op##'..i, jump.op or '>') then
            for _, op in ipairs(operators) do
                if reaper.ImGui_Selectable(ctx, op, jump.op == op) then
                    jump.op = op
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_SetNextItemWidth(ctx, 50)
        _, jump.value = reaper.ImGui_InputText(ctx, 'Value##'..i, tostring(jump.value or ''))
        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, 'Transition##'..i) then
            if jump.from and jump.from ~= "Any" then
                current_region = jump.from
                selected_target_region = jump.to
                reaper.ImGui_OpenPopup(ctx, '##renameinput')
            end
        end

        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, '🗑##'..i) then
            table.remove(ConditionalJumps, i)
            reaper.ImGui_PopID(ctx)
            goto continue
        end

        reaper.ImGui_PopID(ctx)
        ::continue::
    end
end
