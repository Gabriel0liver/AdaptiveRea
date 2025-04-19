--@noindex
function main_loop()
    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)
    ----------- Pre GUI area
    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end

    CheckProjects()
    
    if FirstLoop then
        StartListener()
        FirstLoop = false
    end

    ------------ Window management area
    --- Flags
    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    if GuiSettings.Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    -- Set window configs Size Dock Font
    reaper.ImGui_SetNextWindowSize(ctx, Gui_W_init, Gui_H_init, reaper.ImGui_Cond_Once())-- Set the size of the windows at start.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    if SetDock then 
        reaper.ImGui_SetNextWindowDockID(ctx, SetDock)
        if SetDock== 0 then
            reaper.ImGui_SetNextWindowSize(ctx, Gui_W_init, Gui_H_init)
        end
        SetDock = nil
    end
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 200, 250, 6000, 6000)
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font
    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    -- Updates the variables used in the script
    Gui_W, Gui_H = reaper.ImGui_GetWindowSize(ctx)
    --[[     CTRL = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
        SHIFT = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())
        ALT = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) ]]

    RecieveOSC()

    if visible then
        MenuBar()
        local _ --  values I will throw away
        --- GUI MAIN: 
        GuiMain(ProjConfigs[FocusedProj])

        reaper.ImGui_End(ctx)
    end 
    
    
    -- OpenPopups() 
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()
    --emo.PopStyle(ctx)

    if open then
        reaper.defer(main_loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

--- Check for each project if need to trigger Alternate

function StartListener()
-- Get UDP
    Port = ProjConfigs[FocusedProj].port or Port
    udp = assert(socket.udp())
    assert(udp:setsockname(IPAddress,Port)) -- Set IP and PORT
    udp:settimeout(0.0001) -- Dont forget to set a low timeout! udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.

end

function CheckProjects()
    local projects_opened = {} -- to check if some project closed
    -- Check if some project opened
    for check_proj in enumProjects() do
        local check = false
        for proj, project_table in pairs(ProjConfigs) do
            if proj == check_proj then -- project already have a configs 
                check = true
                break
            end             
        end 
        local project_path = GetFullProjectPath(check_proj)
        if not check or ProjPaths[check_proj] ~= project_path then -- new project detected // project without cofigs (new tab or user opened a project)
            LoadProjectSettings(check_proj)
            ProjPaths[check_proj] = project_path
        end
        table.insert(projects_opened, check_proj)
    end

    -- Check if some project closed
    for proj, proj_table in pairs(ProjConfigs) do
        if not TableHaveValue(projects_opened,proj) then
            ProjConfigs[proj] = nil-- if closed remove from ProjConfigs. configs should be saved as user uses
            ProjPaths[proj] = nil
        end
    end

    FocusedProj = reaper.EnumProjects( -1 )
end

