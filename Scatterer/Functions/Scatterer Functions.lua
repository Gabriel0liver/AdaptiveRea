function AddNotes(group)
    for k, v in ipairs(group.all_notes) do
        if v.selected then
            local n = v
            n.number = k-1
            group.sel_notes[k-1] = n
        else
            group.sel_notes[k-1] = nil
        end
    end
end

function Scatter(proj)
    local now = reaper.time_precise()
    if proj.playing then
        for group_idx, group in ipairs(proj.groups) do
            group.next_time = group.next_time or 0
            if (group.spawnrate > 0) and (now >= group.next_time) then
                if(group.min <= group.max) then
                    local multiplier = group.spawnrate/100
                    local min = math.floor(group.min / multiplier) 
                    local max = math.floor(group.max / multiplier)
                    group.next_time = now + math.random(min, max) / 1000
                else
                    group.next_time = now + group.min / 1000
                end
                
                if group.mode == 0 then
                    PlayRandomNote(group)
                elseif group.mode == 1 then
                    PlayShuffleNote(group)
                end
            end
        end
    end
end

function ReadMem()
    reaper.gmem_attach("Scatterer") -- Attach to the gmem
    if reaper.gmem_read(0) == 1 then
        local groups = ProjConfigs[FocusedProj].groups

        
        local length = reaper.gmem_read(2)  -- Read parameter string length
        local str = ""
        for i = 1, length do
            str = str .. string.char(reaper.gmem_read(2 + i)) --Read parameter string
        end

        -- Find the parameter in the table
        for group_idx, group in ipairs(groups) do
            if group.name == str then
                group.parameter_value = reaper.gmem_read(1) -- Read Parameter value
            end
        end
        reaper.gmem_write(0, 0) -- Reset the memory
    end
end

function PlayRandomNote(group)

    --[[
    local random_val = math.random(add) - 1 -- make it start at 0
            -- get idx on the table
            local chance_add = 0
            for k, v in ipairs(group) do
                chance_add = chance_add + v.chance
                if random_val < chance_add then 
                    sel_idx = k
                    break
                end
            end
    ]]

    local notes = {}
    for k in pairs(group.sel_notes) do
        notes[#notes+1] = k
    end
    local randomNoteK = notes[math.random(#notes)]
    local note = group.sel_notes[randomNoteK]
    if note then
        reaper.StuffMIDIMessage(0, 9*16, note.number, 100);
        reaper.StuffMIDIMessage(0, 8*16, note.number, 100);
    end
end

function PlayShuffleNote(group)
    --if shuffle list is empty fill again
    if next(group.shuffle_list) == nil then
        group.shuffle_list = TableCopy(group.sel_notes)
    end
    
    --put notes into numbered array
    local notes = {}
    for k in pairs(group.shuffle_list) do
        notes[#notes+1] = k
    end
    --get random note
    local randomNoteK = notes[math.random(#notes)]
    local note = group.shuffle_list[randomNoteK]
    
    --play note
    if note then
        group.shuffle_list[randomNoteK] = nil --remove note from available notes
        reaper.StuffMIDIMessage(0, 9*16, note.number, 100);
        reaper.StuffMIDIMessage(0, 8*16, note.number, 100);
    end
end

function AddTracksToSampler(proj,group)
    local initial_note = 0

    if proj.sampler_track == nil or not reaper.ValidatePtr(proj.sampler_track, "MediaTrack*") then --Create sampler track folder if it does not exist
        local idx = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(idx, true) --InsertTrackAtIndex
        proj.sampler_track = reaper.GetTrack(0, idx) --GetTrack

        reaper.GetSetMediaTrackInfo_String(proj.sampler_track, "P_NAME", "Sampler Track", true) --Change name
        reaper.SetMediaTrackInfo_Value(proj.sampler_track, "I_FOLDERDEPTH", 1) -- Set as a folder track
        reaper.SetMediaTrackInfo_Value(proj.sampler_track, "I_FOLDERCOMPACT", 2) -- Set folder as collapsed
        reaper.UpdateArrange()

    end

    for i = 1, reaper.CountSelectedMediaItems(-1) do
        --get src
        local item = reaper.GetSelectedMediaItem(-1, i-1)
        local tk = reaper.GetActiveTake(item)
        local src = reaper.GetMediaItemTake_Source(tk)
        local filenamebuf = reaper.GetMediaSourceFileName(src, "")
        filenamebuf = filenamebuf:gsub("\\", "/")
        local parent_src = reaper.GetMediaSourceParent(src)

        --create track
        local subtrack_idx = reaper.GetMediaTrackInfo_Value(proj.sampler_track, "IP_TRACKNUMBER") --Get folder index
        reaper.InsertTrackAtIndex(subtrack_idx, true) --InsertTrackAtIndex
        local subtrack = reaper.GetTrack(0, subtrack_idx)
        reaper.SetMediaTrackInfo_Value(subtrack, "I_FOLDERDEPTH", 0) -- Set as a child tracks
        -- Set track to record MIDI input from Virtual MIDI Keyboard
        reaper.SetMediaTrackInfo_Value(subtrack, "I_RECINPUT", 6080) -- All MIDI inputs (4096 = MIDI, 63 = all channels)
        reaper.SetMediaTrackInfo_Value(subtrack, "I_RECMODE", 0) -- Set to record MIDI
        reaper.SetMediaTrackInfo_Value(subtrack, "I_RECARM", 1) -- Arm track for recording

        --Set sample track name
        local name = filenamebuf
        name = name:gsub('%\\','/')
        if name then name = name:reverse():match('(.-)/') end
        if name then name = name:reverse() end
        reaper.GetSetMediaTrackInfo_String(subtrack, "P_NAME", group.all_notes[proj.starting_note+i-1].note .. " - " .. name, true) --Change name

        --add samplomatic
        reaper.TrackFX_AddByName(subtrack, 'ReaSamplomatic5000', false, -1000)
        reaper.TrackFX_SetNamedConfigParm(subtrack, 0, 'FILE0', filenamebuf)

        -- Set the Note Range to Selected note
        reaper.TrackFX_SetParamNormalized(subtrack, 0, 3, (proj.starting_note + i-2)/128)
        reaper.TrackFX_SetParamNormalized(subtrack, 0, 4, (proj.starting_note + i-2)/128)
        
    end
end

-------------------
-- Group Operations
-------------------
---
---
function CreatePointTable()
    return {ce_point(0,0), ce_point(1,1)}
end

function Add_ChildTakes(take_table) -- TODO check if item from the take is already at this take_table , can only focus on one.
    for item in enumSelectedItems(FocusedProj) do
        local take = reaper.GetActiveTake(item)
        if not TableHaveValue(take_table.child_takes,take) then -- check if THIS child take table already have this take (makes no sense to have duplicates in child takes)
            --check if the new item from the sel take is already at this take_table (with another take) , can only focus on one, delete the older.
            local new_child_item = reaper.GetMediaItemTake_Item(take)
            for child_idx, child_take in ipairs_reverse(take_table.child_takes) do
                if reaper.GetMediaItemTake_Item(child_take) == new_child_item then 
                    table.remove(take_table.child_takes,child_idx)
                end
            end
            -- add take
            table.insert(take_table.child_takes, take)
        end
    end    
end

function Set_ChildTakes(take_table)
    Delete_ChildTakes(take_table)
    Add_ChildTakes(take_table)
end

function Delete_ChildTakes(take_table)
    take_table.child_takes = {}    
end

function CreateNewGroup(name)
    local default_table = {name = name,
                            parameter_value = 0,
                            spawnrate = 0,
                            min = 0,
                            max = 100,
                            sel_notes = {},
                            shuffle_list = {},
                            all_notes = CreateNotesTable(),
                            next_time = 0,
                            mode = 0, -- 0 = Random, 1 = Shuffle
                            curve = CreatePointTable()
                        }
    return default_table
end

function AddToGroup(group)
    for item in enumSelectedItems(FocusedProj) do
        for take in enumTakes(item) do
            group[#group+1] = {take = take, chance = 1, child_takes = {}}
        end
    end
    group.used_idx = TableiCopy(group)   
end

function SetGroup(group)
    DeleteFromGroup(group)
    AddToGroup(group)
end

function DeleteFromGroup(group)
    -- Delete current takes
    for k, v in ipairs(group) do
        group[k] = nil        
    end    
end

-------------------
-- Configs Table
-------------------

function CreateProjectConfigTable(project)
    local is_play = reaper.GetPlayStateEx(project)&1 == 1
    local t = {
        groups = {CreateNewGroup('G1')},
        playing = false,
        oldpos = (is_play and reaper.GetPlayPositionEx( project )) or reaper.GetCursorPositionEx(project), 
        oldtime = reaper.time_precise(),
        oldisplay = is_play,
        is_loopchanged = false, -- If true then the script alternated the items in this loop
        sampler_track = nil,
        starting_note = {},
    }   
    return t
end

function CreateNotesTable()
    return {
        {note = 'c-1', selected = false}, {note = 'c#-1', selected = false}, {note = 'd-1', selected = false}, {note = 'd#-1', selected = false}, {note = 'e-1', selected = false}, {note = 'f-1', selected = false}, {note = 'f#-1', selected = false}, {note = 'g-1', selected = false}, {note = 'g#-1', selected = false},
        {note = 'a0', selected = false}, {note = 'a#0', selected = false}, {note = 'b0', selected = false}, {note = 'c0', selected = false}, {note = 'c#0', selected = false}, {note = 'd0', selected = false}, {note = 'd#0', selected = false}, {note = 'e0', selected = false}, {note = 'f0', selected = false}, {note = 'f#0', selected = false}, {note = 'g0', selected = false}, {note = 'g#0', selected = false},
        {note = 'a1', selected = false}, {note = 'a#1', selected = false}, {note = 'b1', selected = false}, {note = 'c1', selected = false}, {note = 'c#1', selected = false}, {note = 'd1', selected = false}, {note = 'd#1', selected = false}, {note = 'e1', selected = false}, {note = 'f1', selected = false}, {note = 'f#1', selected = false}, {note = 'g1', selected = false}, {note = 'g#1', selected = false},
        {note = 'a2', selected = false}, {note = 'a#2', selected = false}, {note = 'b2', selected = false}, {note = 'c2', selected = false}, {note = 'c#2', selected = false}, {note = 'd2', selected = false}, {note = 'd#2', selected = false}, {note = 'e2', selected = false}, {note = 'f2', selected = false}, {note = 'f#2', selected = false}, {note = 'g2', selected = false}, {note = 'g#2', selected = false},
        {note = 'a3', selected = false}, {note = 'a#3', selected = false}, {note = 'b3', selected = false}, {note = 'c3', selected = false}, {note = 'c#3', selected = false}, {note = 'd3', selected = false}, {note = 'd#3', selected = false}, {note = 'e3', selected = false}, {note = 'f3', selected = false}, {note = 'f#3', selected = false}, {note = 'g3', selected = false}, {note = 'g#3', selected = false},
        {note = 'a4', selected = false}, {note = 'a#4', selected = false}, {note = 'b4', selected = false}, {note = 'c4', selected = false}, {note = 'c#4', selected = false}, {note = 'd4', selected = false}, {note = 'd#4', selected = false}, {note = 'e4', selected = false}, {note = 'f4', selected = false}, {note = 'f#4', selected = false}, {note = 'g4', selected = false}, {note = 'g#4', selected = false},
        {note = 'a5', selected = false}, {note = 'a#5', selected = false}, {note = 'b5', selected = false}, {note = 'c5', selected = false}, {note = 'c#5', selected = false}, {note = 'd5', selected = false}, {note = 'd#5', selected = false}, {note = 'e5', selected = false}, {note = 'f5', selected = false}, {note = 'f#5', selected = false}, {note = 'g5', selected = false}, {note = 'g#5', selected = false},
        {note = 'a6', selected = false}, {note = 'a#6', selected = false}, {note = 'b6', selected = false}, {note = 'c6', selected = false}, {note = 'c#6', selected = false}, {note = 'd6', selected = false}, {note = 'd#6', selected = false}, {note = 'e6', selected = false}, {note = 'f6', selected = false}, {note = 'f#6', selected = false}, {note = 'g6', selected = false}, {note = 'g#6', selected = false},
        {note = 'a7', selected = false}, {note = 'a#7', selected = false}, {note = 'b7', selected = false}, {note = 'c7', selected = false}, {note = 'c#7', selected = false}, {note = 'd7', selected = false}, {note = 'd#7', selected = false}, {note = 'e7', selected = false}, {note = 'f7', selected = false}, {note = 'f#7', selected = false}, {note = 'g7', selected = false}, {note = 'g#7', selected = false},
        {note = 'a8', selected = false}, {note = 'a#8', selected = false}, {note = 'b8', selected = false}, {note = 'c8', selected = false}, {note = 'c#8', selected = false}, {note = 'd8', selected = false}, {note = 'd#8', selected = false}, {note = 'e8', selected = false}, {note = 'f8', selected = false}, {note = 'f#8', selected = false}, {note = 'g8', selected = false}, {note = 'g#8', selected = false},
        {note = 'a9', selected = false}, {note = 'a#9', selected = false}, {note = 'b9', selected = false}, {note = 'c9', selected = false}, {note = 'c#9', selected = false}, {note = 'd9', selected = false}, {note = 'd#9', selected = false}, {note = 'e9', selected = false}, {note = 'f9', selected = false}, {note = 'f#9', selected = false}, {note = 'g9', selected = false}
    }
end