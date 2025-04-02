-- @noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName, reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
    --- Smaller Font for smaller widgets
    FontTiny = reaper.ImGui_CreateFont('sans-serif', 12) 
    reaper.ImGui_Attach(ctx, FontTiny)
end

function GroupSelector(groups)
    -- calculate positions
    local _
    -- tabs
    if reaper.ImGui_BeginTabBar(ctx, 'Groups', reaper.ImGui_TabBarFlags_Reorderable() | reaper.ImGui_TabBarFlags_AutoSelectNewTabs() ) then
        local is_save
        for group_key, group in ipairs(groups) do
            local open, keep = reaper.ImGui_BeginTabItem(ctx, ('%s###tab%d'):format(group.name, group_key), false) -- Start each tab
            ToolTip(UserConfigs.tooltips,'This is a scatterer Group. Right click to rename/delete.')        

            -- Popup to rename
            if reaper.ImGui_BeginPopupContextItem(ctx) then 
                RenameGroupPopUp(group)
                if reaper.ImGui_Button(ctx, 'Delete Group',-FLTMIN) then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    table.remove(groups,group_key)
                    is_save = true
                end
                reaper.ImGui_EndPopup(ctx)
            end

            -- Show takes inside this group
            if open then
                GroupTab(group)
                reaper.ImGui_EndTabItem(ctx) 
            end
        end
        -- Add Group
        if reaper.ImGui_TabItemButton(ctx, '+', reaper.ImGui_TabItemFlags_Trailing() | reaper.ImGui_TabItemFlags_NoTooltip()) then -- Start each tab
            table.insert(groups,CreateNewGroup('G'..#groups+1))
            is_save = true
        end
        ToolTip(UserConfigs.tooltips,'Create a new Scatterer Group.')        

        local buttonText = ProjConfigs[FocusedProj].playing and 'Stop Scatterer' or 'Start Scatterer'
        if reaper.ImGui_Button(ctx, buttonText) then
            ProjConfigs[FocusedProj].playing = not ProjConfigs[FocusedProj].playing
        end

        reaper.ImGui_SameLine(ctx)
        is_save, ProjConfigs[FocusedProj].start_on_play = reaper.ImGui_Checkbox(ctx, 'Start on Play', ProjConfigs[FocusedProj].start_on_play)

        if is_save then -- Save settings
            SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj])
        end
        
        reaper.ImGui_EndTabBar(ctx)
    end
end

function GroupTab(group)
    local is_save -- if something changed than save

    is_save, group.parameter_value = reaper.ImGui_SliderDouble(ctx, "Parameter value", group.parameter_value, 0, 1)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(), 0)
    reaper.ImGui_Text(ctx, "Spawn Rate:  " .. math.floor(group.spawnrate) .. "%")
    local open = reaper.ImGui_TreeNode(ctx, "Spawn Rate Curve")
    if open then
        local curve_editor_height = 75
        local change = ce_draw(ctx, group.curve, 'target', -FLTMIN, curve_editor_height, {group.parameter_value})
        if change then -- if the curve was changed need to update the value, as it could have change (if change the Y for the current X)
            --target.is_update_ce = true
        end
        is_save = is_save or change

        reaper.ImGui_TreePop(ctx)
    end

    group.spawnrate = ce_evaluate_curve(group.curve,group.parameter_value)*100

    reaper.ImGui_PopStyleVar(ctx)
    --is_save, group.spawnrate = reaper.ImGui_SliderInt(ctx, "Spawn Rate", group.spawnrate, 0, 100, "%d%%")

    local change_min, v_min = reaper.ImGui_InputInt(ctx, 'Min Interval ms', group.min, 1, 100)
    local change_max, v_max = reaper.ImGui_InputInt(ctx, 'Max Interval ms', group.max, 1, 100)

    if change_min or change_max then
        group.min = v_min
        group.max = v_max
        is_save = true
    end

    local text = (group.mode == 0 and 'Random') or (group.mode == 1 and 'Shuffle') 
    local open = reaper.ImGui_BeginCombo(ctx, '##ComboMode', text)
    ToolTip(UserConfigs.tooltips,'Scatterer group mode')        
    if open then
        if reaper.ImGui_Selectable(ctx, 'Random', false) then
            group.mode = 0
            is_save = true
        end
        if reaper.ImGui_Selectable(ctx, 'Shuffle', false) then
            group.mode = 1
            is_save = true
        end
        reaper.ImGui_EndCombo(ctx)
    end

    SelectNotesModal(group)
    if reaper.ImGui_Button(ctx, "Select Notes", -FLTMIN) then
        reaper.ImGui_OpenPopup(ctx, 'SelectNotes')
    end

    if reaper.ImGui_Button(ctx, "Add Tracks To Sampler", -FLTMIN) then
        AddTracksToSampler(ProjConfigs[FocusedProj])
    end
    
    -- Each note
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    local line_size = reaper.ImGui_GetTextLineHeight(ctx)
    local ci_size = 55 --chance_input_size
    if reaper.ImGui_BeginChild(ctx, 'GroupSelect', -FLTMIN, avail_y-line_size*2, true) then
        for k, v in pairs(group.sel_notes) do
            reaper.ImGui_Text(ctx, v.note)
        end
        reaper.ImGui_EndChild(ctx)
    end

    is_save = change or is_save
    if is_save then -- Save settings
        SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj])
    end

end

function SelectNotesModal(group)
    if reaper.ImGui_BeginPopupModal(ctx, 'SelectNotes', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_BeginChild(ctx, 'SelectNotes', 100, 400, true)
            local allNotes = group.all_notes
            for k, v in ipairs(allNotes) do
                local _
                _, v.selected = reaper.ImGui_Selectable(ctx, v.note, v.selected)
                    
            end
        reaper.ImGui_EndChild(ctx)
        if( reaper.ImGui_Button(ctx, 'Close', -FLTMIN) ) then
            reaper.ImGui_CloseCurrentPopup(ctx)
            AddNotes(group)
        end
        reaper.ImGui_EndPopup(ctx)
    end
end

function RenameGroupPopUp(group)
    reaper.ImGui_Text(ctx, 'Edit group name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, group.name = reaper.ImGui_InputText(ctx, "##renameinput", group.name)
    -- Enter
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function RenameTakePopUp(group, k, take_name)
    reaper.ImGui_Text(ctx, 'Edit take name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        TempName = take_name -- Temporary holds the name as the user writes
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, TempName = reaper.ImGui_InputText(ctx, "##renameinput", TempName)
    -- remove button
    if reaper.ImGui_Button(ctx, 'Remove Take', -FLTMIN) then
        -- get if this take exist in the shuffle table
        local retval, used_idx = TableHaveValue(group.used_idx, group[k])
        if used_idx then
            table.remove(group.used_idx,used_idx) -- remove from the main table
        end
        -- remove from the main table
        table.remove(group,k) -- remove from the main table
        -- che
        if retval then table.remove(group.used_idx, used_idx) end -- remove from the shuffle table ( if is there )
        return true
    end
    -- Show Child
    reaper.ImGui_Separator(ctx)
    
    -- Enter close popup
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function MenuBar()
    local function DockBtn()
        local reval_dock =  reaper.ImGui_IsWindowDocked(ctx)
        local dock_text =  reval_dock and  'Undock' or 'Dock'
    
        if reaper.ImGui_MenuItem(ctx,dock_text ) then
            if reval_dock then -- Already Docked
                SetDock = 0
            else -- Not docked
                SetDock = -3 -- Dock to the right 
            end
        end
    end
    
    local _

    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Settings') then
            _, UserConfigs.only_focus_project = reaper.ImGui_MenuItem(ctx, 'Only Focused Project', optional_shortcutIn, UserConfigs.only_focus_project)
            ToolTip(true, 'Only trigger at the focused project, if more project are open they will consume less resources.')

            _, UserConfigs.add_markers = reaper.ImGui_MenuItem(ctx, 'Add Markers When Trigger', optional_shortcutIn, UserConfigs.add_markers)
            ToolTip(true, 'Mostly to debug where it is triggering the goto action.')

            _, UserConfigs.tooltips = reaper.ImGui_MenuItem(ctx, 'Show tooltips', optional_shortcutIn, UserConfigs.tooltips)


            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_BeginMenu(ctx, 'Advanced') then
                reaper.ImGui_Text(ctx, 'Compensate Defer. Default is 2')
                _, UserConfigs.compensate = reaper.ImGui_InputDouble(ctx, '##CompensateValueinput', UserConfigs.compensate, 0, 0, '%.2f')
                UserConfigs.compensate = UserConfigs.compensate > 1 and UserConfigs.compensate or 1 
                ToolTip(true, 'Compensate the defer instability. The bigger the compensation the earlier it will change before the loop end. The shorter more chances to not get the loop section, the muting/unmutting take some time to work, so it is better to do it a little earlier. NEVER SMALLER THAN 1!!')

                reaper.ImGui_EndMenu(ctx)
            end

            if reaper.ImGui_BeginMenu(ctx, 'Reaper Settings') then
                ---- Buffering
                reaper.ImGui_Text(ctx, 'Audio > Buffering')

                reaper.ImGui_Text(ctx, 'Media Buffer Size:')
                local change, num = reaper.ImGui_InputInt(ctx, '##Buffersize', reaper.SNM_GetIntConfigVar( 'workbufmsex', 0 ), 0, 0, 0)
                ToolTip(true, 'Lower Buffer will process the change of takes/change mute state faster, higher buffer settings will result in bigger delays at project changes. For manipulating with audio items in live scenarios I recommend leaving at 0\n\nREAPER Definition: Media buffering uses RAM and CPU to avoid having to wait for disk IO. For systems with slower disks this should be set higher. Zero disables buffering. Default 1200 ')
                if change then
                    reaper.SNM_SetIntConfigVar( 'workbufmsex', num )
                end
                ----
                reaper.ImGui_Text(ctx, 'Media Buffer Size with take FX :')
                local change, num = reaper.ImGui_InputInt(ctx, '##FxBuffersize', reaper.SNM_GetIntConfigVar( 'workbuffxuims', 0 ), 0, 0, 0)
                ToolTip(true, 'Buffer size when per-take FX are showing.\n\nREAPER Definition: When per-take FX are showing, use a lower media buffer to minimize lag between audio playback and the visual response of the plugin. Default 200')
                if change then
                    reaper.SNM_SetIntConfigVar( 'workbuffxuims', num )
                end
                ----
                local render_configs = reaper.SNM_GetIntConfigVar('workrender', 0)
                local is_anticipate = GetNbit(render_configs,0)

                local retval, new_v = reaper.ImGui_Checkbox(ctx, 'Anticipate FX', is_anticipate)
                if retval then
                    local render_val = ChangeBit(render_configs, 0, (new_v and 1 or 0)) -- 1 bit is the anticipate value
                    reaper.SNM_SetIntConfigVar('workrender', render_val)
                end
                ToolTip(true, 'Render FX ahead. The lower the value more in real time the modifications will take effect, higher values spare more CPU. For live situations manipulating tracks with FX I recommend the lowest as possible. \n\n REAPER Definition: Use spare CPU to render FX ahead of time. This is beneficial regardless of CPU count, but may need to be disabled for use with some plug-ins(UAD). Default: ON')

                if is_anticipate then
                    reaper.ImGui_Text(ctx, 'Anticipate FX Size :')
                    local change, num = reaper.ImGui_InputInt(ctx, '##Renderahead', reaper.SNM_GetIntConfigVar( 'renderaheadlen', 0 ), 0, 0, 0)
                    ToolTip(true, 'Render FX ahead. The lower the value more in real time the modifications will take effect, higher values spare more CPU. For live situations manipulating tracks with FX I recommend the lowest as possible. \n\n REAPER Definition: Use spare CPU to render FX ahead of time. This is beneficial regardless of CPU count, but may need to be disabled for use with some plug-ins(UAD). Default: 200')
                    if change then
                        reaper.SNM_SetIntConfigVar( 'renderaheadlen', num )
                    end
                end
                
                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end

        _, GuiSettings.Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, GuiSettings.Pin)

        DockBtn()

        reaper.ImGui_EndMenuBar(ctx)
    end
end


