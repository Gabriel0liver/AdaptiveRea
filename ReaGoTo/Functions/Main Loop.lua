--@noindex
function main_loop()
    ----------- Pre GUI area
    CheckProjects()
    CheckSmoothSeek()
    MIDIInput = GetMIDIInput() -- Global variable with the MIDI from current loop

    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx) and not TableHaveAnything(PreventKeys) then 
        PassKeys()
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
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font
    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)
    -- Updates the variables used in the script
    Gui_W, Gui_H = reaper.ImGui_GetWindowSize(ctx)
    if visible then
        AnimationValues()
        MenuBar()
        local _ --  values I will throw away
        --- GUI MAIN: 
        PlaylistSelector(ProjConfigs[FocusedProj].playlists)
        -- Trigger Buttons
        TriggerButtons(ProjConfigs[FocusedProj].playlists)
        reaper.ImGui_End(ctx)
    end 
    
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()
    --demo.PopStyle(ctx)
    GoToCheck()  -- Check if need change playpos (need to be after the user input). If ProjConfigs[proj].is_triggered then change the playpos at last moment possible.

    if open then
        reaper.defer(main_loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function GetCurrentRegionName(proj)
    local pos = reaper.GetPlayStateEx(proj)&1 == 1 and reaper.GetPlayPositionEx(proj) or reaper.GetCursorPositionEx(proj)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(proj)
    local total = num_markers + num_regions

    for i = 0, total - 1 do
        local retval, isrgn, rgn_start, rgn_end, name, idx = reaper.EnumProjectMarkers2(proj, i)
        if isrgn and pos >= rgn_start and pos <= rgn_end then
            return name
        end
    end
    return nil -- Not currently in a region
end


function GetRegionNameFromIndex(region_index)
    local num_markers, num_regions = reaper.CountProjectMarkers(FocusedProj)
    for i = 0, num_markers + num_regions - 1 do
        local retval, is_region, pos, rgnend, name, idx = reaper.EnumProjectMarkers2(FocusedProj, i)
        if retval and is_region and idx == region_index then
            return name -- Return region name
        end
    end
    return nil
end

function GetRegionIndexByName(region_name)
    for i = 0, reaper.CountProjectMarkers(0) - 1 do
        local _, isrgn, _, _, regionName, index = reaper.EnumProjectMarkers(i)
        if isrgn and regionName == region_name then
            return index
        end
    end
    return nil
end


function GetRegionStartTime(region_name)
    local num_markers, num_regions = reaper.CountProjectMarkers(FocusedProj)
    for i = 0, num_markers + num_regions - 1 do
        local retval, is_region, pos, rgnend, name, idx = reaper.EnumProjectMarkers2(FocusedProj, i)
        if retval and is_region and name == region_name then
            return pos -- Return region start time
        end
    end
    return nil
end

function GetRegionEndTime(region_name)
    local num_markers, num_regions = reaper.CountProjectMarkers(0) -- Markers & Regions in project

    for i = 0, num_markers + num_regions - 1 do
        local retval, is_region, start_time, end_time, name, marker_index = reaper.EnumProjectMarkers(i)
        
        if retval and is_region and name == region_name then
            return end_time
        end
    end

    return nil -- If region not found
end

function GetAllRegionNamesExceptCurrent(proj, current)
    local region_names = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(proj)
    local total = num_markers + num_regions

    for i = 0, total - 1 do
        local retval, isrgn, _, _, name = reaper.EnumProjectMarkers2(proj, i)
        if isrgn and name and name ~= "" and name ~= current then
            table.insert(region_names, name)
        end
    end

    return region_names
end

played_transitions = played_transitions or {}
last_region = nil

--- Check for each project if need to trigger goto
function GoToCheck()
    ReadMem()

    local proj_t = (UserConfigs.only_focus_project and {ProjConfigs[FocusedProj]}) or ProjConfigs -- if only_focus_project will be a table with the focused project only else will do for all open projectes
    for proj, project_table in pairs(proj_t) do
        -- Get play pos/state
        local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
        local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
        local time = reaper.time_precise()

        -- if stopped
        if project_table.oldisplay and not is_play then
            if project_table.stop_trigger then -- Cancel triggers
                project_table.is_triggered = false
            end
            -- Reset playlist position for each playlist
            for playlist_idx,playlist in ipairs(project_table.playlists) do
                if playlist.reset then
                    playlist.reset_n = LimitNumber(playlist.reset_n,0,#playlist) -- In case user deleted some playlist, update maximum and min value of reset_n
                    if playlist.reset_playhead then
                        GoTo('goto'..playlist.reset_n, proj)
                    else -- maybe create a goto flag for select 
                        playlist.reset_n = LimitNumber(playlist.reset_n,0,#playlist) -- In case user deleted some playlist, update maximum and min value of reset_n
                        playlist.current = playlist.reset_n
                        --- Create the loop around the region ( user testing )
                        local region = playlist[playlist.current]
                        if type(region) ~= 'table' or not region.type == 'region' then goto dontloop end
                        local guid = region.guid -- region guid
                        local retval, marker_id = reaper.GetSetProjectInfo_String( proj, 'MARKER_INDEX_FROM_GUID:'..guid, '', false )
                        if not( marker_id == '') then   -- better safe than sorry
                            local _, _, rgpos, rgnend, _, _ = reaper.EnumProjectMarkers2( proj, marker_id )
                            if region.loop then
                                local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, rgpos, rgnend, false) -- proj, isSet, isLoop, start, end, allowautoseek
                            elseif region.type == 'region' then -- not looping a region will remove loop regions (maybe only if the loop region is in the region position/range)
                                local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, 0, 0, false) -- proj, isSet, isLoop, start, end, allowautoseek
                            end
                        end
                        ::dontloop::
                    end
                end
            end
        end
    
        -- if playing and is_triggered then search the next Trigger point 
        if is_play and (project_table.is_triggered or project_table.is_force_goto) and project_table.oldtime then
 
            ---- Play variables
            local is_repeat =  reaper.GetSetRepeat( -1 ) == 1 -- query = -1 
            local loop_start, loop_end -- loop position , loop end position  
            if is_repeat then
                loop_start, loop_end = reaper.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
                is_repeat = loop_start ~= loop_end-- Does it have an area selected? does it have repeat on ? 
            end
            local is_inside_loop = is_repeat and pos <= loop_end and pos >= loop_start
            -- If markers get triggers overides
            local delta =  time - project_table.oldtime -- for defer instability estimation
            -- Estimate next defer cycle position, check if is after the loop end. Always estimate a little longer to compensate for defer instability. This can cause to trigger twice. Use a variable that reset each loop start to prevent that.
            local playrate = reaper.Master_GetPlayRate(proj)
            local defer_in_proj_sec = (delta * UserConfigs.compensate) * playrate -- how much project sec each defer loop runs. avarage.


            -- (Transitions: Data Verification and Note insertion)
            ------------------------------------------

            if project_table.is_triggered or proj_table.is_force_goto then

                local goto_region_index = tonumber(project_table.is_triggered:match("goto(%d+)"))
                local goto_region_name = GetRegionNameFromIndex(goto_region_index)
                local goto_region_start = GetRegionStartTime(goto_region_name)
    
                -- reaper.ShowConsoleMsg("GoToCheck: Index = " .. tostring(goto_region_index) .. ", Name = " .. tostring(goto_region_name) .. ", Start = " .. tostring(goto_region_start) .. "\n")
                -- reaper.ShowConsoleMsg("current_region = " .. tostring(current_region) .. "\n")
    
                local current_region_name = GetCurrentRegionName(proj, pos)
                if last_region ~= current_region_name then
                    played_transitions = {}
                    last_region = current_region_name
                end
                current_region = current_region_name
                    
    
                if goto_region_name and goto_region_start then

                    if current_region == goto_region_name then
                        return
                    end

                    if transitions[current_region] and transitions[current_region][goto_region_name] then
                        local transition_data = transitions[current_region][goto_region_name][1]

                        if transition_data and transition_data.track and transition_data.note and transition_data.octave then
                            local transition_key = current_region .. "->" .. goto_region_name

                            -- Verify: Note already inserted for this transition?
                            if not played_transitions[transition_key] then
                                InsertMIDINote(transition_data.track, transition_data.note, transition_data.octave, goto_region_start)

                                -- Mark transition as already inserted
                                played_transitions[transition_key] = true

                                reaper.defer(
                                    function()
                                        RemoveMIDINotesAfterPlayback(transition_data.track, goto_region_start, GetRegionEndTime(goto_region_name))
                                    end)

                            else
                                -- reaper.ShowConsoleMsg("Note already inserted\n")
                            end
                        else
                            -- reaper.ShowConsoleMsg("No transition data in transitions[" .. tostring(current_region) .. "][" .. tostring(goto_region_name) .. "]\n")
                        end
                    else
                        reaper.ShowConsoleMsg("No registered transitions for " .. tostring(current_region) .. "\n")
                    end
                else
                    reaper.ShowConsoleMsg("Couldn't find start of region of index " .. tostring(goto_region_index) .. "\n")
                end
            end

            ------------------------------------------


            --- functions
            local function proj_position_in_defer_range(trigger_point, ignore_smooth)        
                local is_trigger_before = (trigger_point < pos) -- Trigger point is at the start of a loop.

                local is_trigger -- should it trigger the GoTo function?
                if not SmoothSettings.is_smoothseek or ignore_smooth then
                    local distance = defer_in_proj_sec -- distance the trigger needs to be from the current position/loop start to trigger.
        
                    if not is_trigger_before then
                        is_trigger = ((pos + distance) >= trigger_point) -- calculate based on triggering point after current position
                    else
                        is_trigger = (loop_start + (distance - (loop_end - pos))) >= trigger_point  -- calculate based on triggering point before current position and after loop start
                    end
                else
                    local max_distance = SmoothSettings.min_time + defer_in_proj_sec -- minimum distance to trigger 
                    local min_distance = SmoothSettings.min_time  -- minimum distance to trigger (there is a bug in reaper and smooth seek, if change the position before 200-250ms before the bar/marker it wont trigger, and can even break a loop)
                    
                    if not is_trigger_before then
                        is_trigger = (pos + max_distance >= trigger_point) and (pos + min_distance < trigger_point) -- calculate based on triggering point after current position
                    else
                        --is_trigger = ((loop_start + (max_distance - (loop_end - pos))) >= trigger_point) and (((trigger_point - loop_start) + (loop_end-pos)) > min_distance)  -- because smooth seek trigger at regions ends and it needs to be 250ms triggered before it makes markers (250ms after the loop start) impossible. trying to trigger them will break the REAPER loop, another bug, best to remove this than break options. 
                    end
                end
                return is_trigger
            end

            local function get_closest_marker(proj,pos,indentifier)
                local marker_point, marker_name, marker_distance
                local found_loop_marker
                -- Loop markers
                for retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber in enumMarkers2(proj, 1) do
                    -- Marks outside range
                    if is_inside_loop and mark_pos > loop_end then
                        break
                    end 

                    -- Get the next marker
                    if mark_pos > pos and name:match('^'..indentifier) then -- Loop each marker (improve with a binary search later)
                        marker_point = mark_pos
                        marker_name = name
                        marker_distance = mark_pos - pos
                        break  -- if have the next marker then it already had the opportunity of having the loop repeat 
                    end

                    -- If loop/repeat is ON then get the closest goto marker from the loop start
                    if is_inside_loop and not found_loop_marker and mark_pos >= loop_start and name:match('^'..indentifier) then
                        found_loop_marker = true
                        marker_point = mark_pos
                        marker_name = name
                        marker_distance = (loop_end - pos) + (mark_pos - loop_start)
                    end
                end 
                return marker_point, marker_name, marker_distance 
            end

            ---------- Find Force Marker, force marker are not trigger points
            if project_table.is_force_goto and not project_table.is_triggered then
                local force_pos, force_name, force_distance = get_closest_marker(proj,pos,project_table.force_identifier)
                if force_pos and proj_position_in_defer_range(force_pos, true) then  -- Check if the force marker is inside range
                    project_table.is_triggered = GetCommand(project_table.force_identifier,force_name) -- it might return false, but to be here  project_table.is_triggered needs to be false so it wont cancel triggered commands
                end 
            end
            
            if not project_table.is_triggered then goto notrigger end 

            --------------------------------------- Find Trigger Points
            -------------------------- Markers

            local marker_name, marker_point, marker_distance -- name of the next marker,  position of the next marker ( to compare with next unit ), saves the distance to trigger using markers (to compare with grids)
            if project_table.is_marker then
                marker_point, marker_name, marker_distance = get_closest_marker(proj,pos,project_table.identifier)
            end
            ------------------------ Unit
            -- check if passed by any unit and increase the counter
            local unit_point, unit_distance -- position to trigger, distance until trigger
            if project_table.grid.is_grid then
                local pos_qn = reaper.TimeMap2_timeToQN( proj, pos )
                local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( proj, pos_qn )
                if project_table.grid.unit == 'bar' then             
                    unit_point = reaper.TimeMap_QNToTime( qnMeasureEnd )
                else
                    local unit_in_qn = project_table.grid.unit * 4 
                    local measure_pos_qn = pos_qn - qnMeasureStart -- qn over that measure
                    local next_qn = QuantizeUpwards(measure_pos_qn, unit_in_qn) + qnMeasureStart
                    unit_point = reaper.TimeMap_QNToTime( next_qn )                    
                end
                unit_distance = unit_point - pos
            end

            ---------------------- Compare marker and unit get closest. Get trigger_point.
            local trigger_point -- valid point from next unit/marker, to be checked if is in range
            if marker_point and unit_point then
                trigger_point = marker_distance < unit_distance and marker_point or unit_point
            else 
                trigger_point = marker_point or unit_point
            end

            ------- Change Player position if needed (Try to change as close to the marker as possible)
            if trigger_point then -- only if there is something to trigger to comapre to
                if proj_position_in_defer_range(trigger_point) then
                    -- check for trigger overies 
                    if marker_name then
                        project_table.is_triggered = GetCommand(project_table.identifier,marker_name) or project_table.is_triggered
                    end
                    -- Goto ! 
                    GoTo(project_table.is_triggered, proj)
                    
                    ---- Add Markers at the trigger position for debugging mostly
                    if UserConfigs.add_markers then
                        reaper.AddProjectMarker(proj, false, pos, 0, '', 0) -- debug when it is happening
                    end
                end
            end
            ::notrigger:: -- if it enter this scope with no trigger but with force option on. but didnt found any force marker in range
        elseif UserConfigs.trigger_when_paused and not is_play and project_table.is_triggered then -- receive goto orders when paused
            GoTo(project_table.is_triggered,proj)
        end

        -- Remove played transition notes in this region.
        if current_region then
            local region_start = GetRegionStartTime(current_region)
            local region_end = GetRegionEndTime(current_region)
        
            if region_start and region_end then
                for from_region, targets in pairs(transitions) do
                    if targets[current_region] then
                        local transition = targets[current_region][1]
                        if transition and transition.track then
                            RemoveMIDINotesAfterPlayback(transition.track, region_start, region_end)
                        end
                    end
                end
            end
        end
        

        -- Update values
        project_table.oldtime = time
        project_table.oldpos = pos
        project_table.oldisplay = is_play

    end
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



    for check_proj in enumProjects() do
        --- Check if all regions are available 
        for playlist_key, playlist in ipairs(ProjConfigs[check_proj].playlists) do
            for rgn_k, region_table in ipairs_reverse(playlist) do   
                local retval, marker_id = reaper.GetSetProjectInfo_String( check_proj, 'MARKER_INDEX_FROM_GUID:'..region_table.guid, '', false )
                if marker_id == '' then 
                    table.remove(playlist,rgn_k)
                end
            end
        end
        -- if smooth seek then force reagoto proj_settings to match smooth seek (to be on the grid/marker)
        if SmoothSettings.is_smoothseek then
            if SmoothSettings.is_bar then
                if not ProjConfigs[check_proj].grid.is_grid then
                    ProjConfigs[check_proj].grid.is_grid = true
                end

                if ProjConfigs[check_proj].grid.unit ~= 'bar' then
                    ProjConfigs[check_proj].grid.unit = 'bar'
                end

                if ProjConfigs[check_proj].is_marker then
                    ProjConfigs[check_proj].is_marker = false
                end
            else
                if not ProjConfigs[check_proj].is_marker then
                    ProjConfigs[check_proj].is_marker = true
                end

                if ProjConfigs[check_proj].grid.is_grid then
                    ProjConfigs[check_proj].grid.is_grid = false
                end
            end
        end
    end
    FocusedProj = reaper.EnumProjects( -1 )
end

function CheckSmoothSeek()
    local smoothseek = reaper.SNM_GetIntConfigVar('smoothseek', 0)
    SmoothSettings.is_smoothseek = GetNbit(smoothseek,0)
    SmoothSettings.is_bar = not GetNbit(smoothseek,1)
end

-- Insert MIDI note of a given pitch (note + octave), in a given track; at the start of a given region
function InsertMIDINote(track_name, note, octave, region_start)

    local track_count = reaper.CountTracks(0)
    local track_found = false
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetTrackName(track, "")
        if name == track_name then
            track_found = true

            local midi_item = reaper.CreateNewMIDIItemInProj(track, region_start, region_start + 1, false)
            local take = reaper.GetMediaItemTake(midi_item, 0)
            if not take then
                reaper.ShowConsoleMsg("Couldn't find valid take\n")
                return
            end

            -- MIDI note conversion
            local note_map = { ["C"] = 0, ["C#"] = 1, ["D"] = 2, ["D#"] = 3, ["E"] = 4, ["F"] = 5, ["F#"] = 6, ["G"] = 7, ["G#"] = 8, ["A"] = 9, ["A#"] = 10, ["B"] = 11 }
            local midi_note = (note_map[note] or 0) + ((tonumber(octave) + 1) * 12)
            midi_note = math.max(0, math.min(127, midi_note))

            -- Insert MIDI note
            local ppq_start = reaper.MIDI_GetPPQPosFromProjTime(take, region_start)
            local ppq_end = ppq_start + 120 -- Always this length for now
            reaper.MIDI_InsertNote(take, false, false, ppq_start, ppq_end, 0, midi_note, 100, true)

            reaper.MIDI_Sort(take)
            reaper.UpdateArrange()
            break
        end
    end

    if not track_found then
        reaper.ShowConsoleMsg("Couldn't find track " .. track_name .. "\n")
    end
end


function RemoveMIDINotesAfterPlayback(track_name, region_start, region_end)
    local play_pos = reaper.GetPlayPosition()

    if play_pos < region_start or play_pos > region_end then
        return -- Only if within region
    end

    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetTrackName(track, "")

        if name == track_name then
            local item_count = reaper.CountTrackMediaItems(track)

            for j = item_count - 1, 0, -1 do
                local item = reaper.GetTrackMediaItem(track, j)
                local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

                -- Delete only if already played and within current region
                if item_pos >= region_start and item_pos <= region_end and play_pos > item_pos then
                    reaper.DeleteTrackMediaItem(track, item)
                    -- reaper.ShowConsoleMsg("Note deleted in " .. item_pos .. "\n")
                end
            end

            reaper.UpdateArrange()
        end
    end
end
