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
        for group_idx, group in ipairs(proj.groups) do --for every group
            group.next_time = group.next_time or 0
            if (group.spawnrate > 0) and (now >= group.next_time) then --if time to spawn
                if(group.min <= group.max) then --set next spawn time
                    local multiplier = group.spawnrate/100
                    local min = math.floor(group.min / multiplier) 
                    local max = math.floor(group.max / multiplier)
                    group.next_time = now + math.random(min, max) / 1000
                else
                    group.next_time = now + group.min / 1000
                end
                
                -- Depending on the mode play a note
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
    reaper.gmem_attach("scatterer") -- Attach to the gmem
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
    --Selects a random note from the selected notes
    local notes = {}
    for k in pairs(group.sel_notes) do
        notes[#notes+1] = k
    end
    local randomNoteK = notes[math.random(#notes)]
    local note = group.sel_notes[randomNoteK]
    
    --Send the note to midi virtual keyboard
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
    
    --Send the note to midi virtual keyboard
    if note then
        group.shuffle_list[randomNoteK] = nil --remove note from available notes
        reaper.StuffMIDIMessage(0, 9*16, note.number, 100);
        reaper.StuffMIDIMessage(0, 8*16, note.number, 100);
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
                            min = 500,
                            max = 1500,
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
        starting_note = 60, --Starting note when adding tracks to sampler
    }   
    return t
end

function CreateNotesTable()
    return {
        {note = 'C-1', selected = false}, {note = 'C#-1', selected = false}, {note = 'D-1', selected = false}, {note = 'D#-1', selected = false}, {note = 'E-1', selected = false}, {note = 'F-1', selected = false}, {note = 'F#-1', selected = false}, {note = 'G-1', selected = false}, {note = 'G#-1', selected = false},
        {note = 'A0', selected = false}, {note = 'A#0', selected = false}, {note = 'B0', selected = false}, {note = 'C0', selected = false}, {note = 'C#0', selected = false}, {note = 'D0', selected = false}, {note = 'D#0', selected = false}, {note = 'E0', selected = false}, {note = 'F0', selected = false}, {note = 'F#0', selected = false}, {note = 'G0', selected = false}, {note = 'G#0', selected = false},
        {note = 'A1', selected = false}, {note = 'A#1', selected = false}, {note = 'B1', selected = false}, {note = 'C1', selected = false}, {note = 'C#1', selected = false}, {note = 'D1', selected = false}, {note = 'D#1', selected = false}, {note = 'E1', selected = false}, {note = 'F1', selected = false}, {note = 'F#1', selected = false}, {note = 'G1', selected = false}, {note = 'G#1', selected = false},
        {note = 'A2', selected = false}, {note = 'A#2', selected = false}, {note = 'B2', selected = false}, {note = 'C2', selected = false}, {note = 'C#2', selected = false}, {note = 'D2', selected = false}, {note = 'D#2', selected = false}, {note = 'E2', selected = false}, {note = 'F2', selected = false}, {note = 'F#2', selected = false}, {note = 'G2', selected = false}, {note = 'G#2', selected = false},
        {note = 'A3', selected = false}, {note = 'A#3', selected = false}, {note = 'B3', selected = false}, {note = 'C3', selected = false}, {note = 'C#3', selected = false}, {note = 'D3', selected = false}, {note = 'D#3', selected = false}, {note = 'E3', selected = false}, {note = 'F3', selected = false}, {note = 'F#3', selected = false}, {note = 'G3', selected = false}, {note = 'G#3', selected = false},
        {note = 'A4', selected = false}, {note = 'A#4', selected = false}, {note = 'B4', selected = false}, {note = 'C4', selected = false}, {note = 'C#4', selected = false}, {note = 'D4', selected = false}, {note = 'D#4', selected = false}, {note = 'E4', selected = false}, {note = 'F4', selected = false}, {note = 'F#4', selected = false}, {note = 'G4', selected = false}, {note = 'G#4', selected = false},
        {note = 'A5', selected = false}, {note = 'A#5', selected = false}, {note = 'B5', selected = false}, {note = 'C5', selected = false}, {note = 'C#5', selected = false}, {note = 'D5', selected = false}, {note = 'D#5', selected = false}, {note = 'E5', selected = false}, {note = 'F5', selected = false}, {note = 'F#5', selected = false}, {note = 'G5', selected = false}, {note = 'G#5', selected = false},
        {note = 'A6', selected = false}, {note = 'A#6', selected = false}, {note = 'B6', selected = false}, {note = 'C6', selected = false}, {note = 'C#6', selected = false}, {note = 'D6', selected = false}, {note = 'D#6', selected = false}, {note = 'E6', selected = false}, {note = 'F6', selected = false}, {note = 'F#6', selected = false}, {note = 'G6', selected = false}, {note = 'G#6', selected = false},
        {note = 'A7', selected = false}, {note = 'A#7', selected = false}, {note = 'B7', selected = false}, {note = 'C7', selected = false}, {note = 'C#7', selected = false}, {note = 'D7', selected = false}, {note = 'D#7', selected = false}, {note = 'E7', selected = false}, {note = 'F7', selected = false}, {note = 'F#7', selected = false}, {note = 'G7', selected = false}, {note = 'G#7', selected = false},
        {note = 'A8', selected = false}, {note = 'A#8', selected = false}, {note = 'B8', selected = false}, {note = 'C8', selected = false}, {note = 'C#8', selected = false}, {note = 'D8', selected = false}, {note = 'D#8', selected = false}, {note = 'E8', selected = false}, {note = 'F8', selected = false}, {note = 'F#8', selected = false}, {note = 'G8', selected = false}, {note = 'G#8', selected = false},
        {note = 'A9', selected = false}, {note = 'A#9', selected = false}, {note = 'B9', selected = false}, {note = 'C9', selected = false}, {note = 'C#9', selected = false}, {note = 'D9', selected = false}, {note = 'D#9', selected = false}, {note = 'E9', selected = false}, {note = 'F9', selected = false}, {note = 'F#9', selected = false}, {note = 'G9', selected = false}
    }
end