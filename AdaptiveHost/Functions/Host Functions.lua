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
                print("hello")
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

-------------------
-- Group Operations
-------------------

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
                            spawnrate = 0,
                            min = 0,
                            max = 100,
                            sel_notes = {},
                            shuffle_list = {},
                            all_notes = CreateNotesTable(),
                            next_time = 0,
                            mode = 0, -- 0 = Random, 1 = Shuffle
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