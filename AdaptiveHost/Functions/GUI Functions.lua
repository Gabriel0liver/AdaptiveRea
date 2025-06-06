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


function GuiMain(proj)
    local change 

    reaper.ImGui_Text(ctx, "Currently listening on:")
    reaper.ImGui_Text(ctx, "Address - " .. IPAddress)
    reaper.ImGui_Text(ctx, "Port - " .. Port)

    
    reaper.ImGui_PushItemWidth(ctx, reaper.ImGui_GetContentRegionAvail(ctx) * 0.5 - 2)
    change, proj.port = reaper.ImGui_InputInt(ctx, "##", proj.port, 0, 0, 0) -- Input for the port
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Set Port", reaper.ImGui_GetContentRegionAvail(ctx), 0) then -- Button to set the port
        Port = proj.port
        udp:close() -- Close the old socket
        udp = assert(socket.udp()) -- Create a new socket
        assert(udp:setsockname(IPAddress,Port)) -- Set the new IP and PORT
        udp:settimeout(0.0001) -- Set a low timeout
    end

    reaper.ImGui_Separator(ctx)

    if reaper.ImGui_Button(ctx, "Open Layers", -FLTMIN) then -- Button to open the script
        local command = reaper.NamedCommandLookup("_RScb2963420e188ce6e4cb5d9254e72061f9836b97")
        if command then
            reaper.Main_OnCommand(command, 0) -- Open the script
        else
            reaper.ShowMessageBox('Script not found. Please check the script ID.', 'Error', 0)
        end
    
    end
    if reaper.ImGui_Button(ctx, "Open GoTo", -FLTMIN) then -- Button to open the script
        local command = reaper.NamedCommandLookup("_RSb8ab157fb7d280e1fd656117c204a7f95dbb9782")
        if command then
            reaper.Main_OnCommand(command, 0) -- Open the script
        else
            reaper.ShowMessageBox('Script not found. Please check the script ID.', 'Error', 0)
        end
    
    end
    if reaper.ImGui_Button(ctx, "Open Scatterer", -FLTMIN) then -- Button to open the script
        local command = reaper.NamedCommandLookup("_RS2f2972589c8bf165a04d314777c833aa38d67b7f")
        if command then
            reaper.Main_OnCommand(command, 0) -- Open the script
        else
            reaper.ShowMessageBox('Script not found. Please check the script ID.', 'Error', 0)
        end
    
    end

    if change then
        SaveProjectSettings(proj, ProjConfigs[FocusedProj]) -- Save the project settings   
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


