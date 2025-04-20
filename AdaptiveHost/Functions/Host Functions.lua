function RecieveOSC()
    local message = osc.Receive(udp) --receive the osc messahe

    local scripts = {"layersv2", "gotov2" ,"scatter"}

    for k, v in ipairs(message) do
        if v.address == 'play' then
            reaper.Main_OnCommand(40044, 0) -- Play
        elseif v.address == 'stop' then
            reaper.Main_OnCommand(1016, 0) -- Stop
        elseif v.address == 'bpm' then
            reaper.SetCurrentBPM(0, v.values[1], true) -- Set the BPM
        elseif v.address == 'param' then -- Set a parameter
        for i = 1, #scripts do --send the parameter to the each scripts gmem
            local script = scripts[i]
            reaper.gmem_attach(script) -- Attach to the script
            reaper.gmem_write(0, 1) --set first value to 1 (unread)
            reaper.gmem_write(1, v.values[2]) --store parameter value
            reaper.gmem_write(2, #v.values[1]) -- store parameter name length
            for i = 1, #v.values[1] do
                reaper.gmem_write(2+i, v.values[1]:byte(i)) -- store parameter name
            end
        end
           
        end
    end
end



function CreateProjectConfigTable(project)
    local is_play = reaper.GetPlayStateEx(project)&1 == 1
    local t = {
        groups = {},
        playing = false,
        oldpos = (is_play and reaper.GetPlayPositionEx( project )) or reaper.GetCursorPositionEx(project), 
        oldtime = reaper.time_precise(),
        oldisplay = is_play,
        is_loopchanged = false, -- If true then the script alternated the items in this loop
        port = 9004, -- Port for the project
    }   
    return t
end
