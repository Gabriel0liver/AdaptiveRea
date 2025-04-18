function AddTracksToSampler(proj, remove)
    if proj.sampler_track == nil or not reaper.ValidatePtr(proj.sampler_track, "MediaTrack*") then --Create sampler track folder if it does not exist
        AddSamplerTrack(proj.sampler_track) --Create sampler track folder if it does not exist
    end

    local items_to_remove = {}

    for i = 1, reaper.CountSelectedMediaItems(-1) do
        --get src
        local item = reaper.GetSelectedMediaItem(-1, i-1)
        local tk = reaper.GetActiveTake(item)
        if not(tk and not reaper.TakeIsMIDI(tk)) then goto nextitem end -- Skip if take is not audio

        if remove then
            local retval, GUID = reaper.GetSetMediaItemInfo_String( item, 'GUID', '', false ) 
            items_to_remove[GUID] = true -- Add to remove list
        end

        local src = reaper.GetMediaItemTake_Source(tk)
        local filenamebuf = reaper.GetMediaSourceFileName(src, "")
        filenamebuf = filenamebuf:gsub("\\", "/") --Replace backslash with forward slash

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
        reaper.GetSetMediaTrackInfo_String(subtrack, "P_NAME", proj.groups[1].all_notes[proj.starting_note+i-1].note .. " - " .. name, true) --Change name

        --add samplomatic
        reaper.TrackFX_AddByName(subtrack, 'ReaSamplomatic5000', false, -1000)
        reaper.TrackFX_SetNamedConfigParm(subtrack, 0, 'FILE0', filenamebuf) --set samplomatic sample to file

        -- Set the Note Range to Selected note
        reaper.TrackFX_SetParamNormalized(subtrack, 0, 3, (proj.starting_note + i-2)/128)
        reaper.TrackFX_SetParamNormalized(subtrack, 0, 4, (proj.starting_note + i-2)/128)

        ::nextitem::
    end

    if remove then --Remove added items if remove flag is true
        for itemGUID in pairs(items_to_remove ) do
            local it = reaper.BR_GetMediaItemByGUID(proj, itemGUID)
            if it then reaper.DeleteTrackMediaItem(  reaper.GetMediaItemTrack( it ), it ) end
        end
    end
    reaper.UpdateArrange() --Update arrange view
end

function AddSamplerTrack(sampler_track)
    local idx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(idx, true) --InsertTrackAtIndex
    sampler_track = reaper.GetTrack(0, idx) --GetTrack

    reaper.GetSetMediaTrackInfo_String(sampler_track, "P_NAME", "Sampler Track", true) --Change name
    reaper.SetMediaTrackInfo_Value(sampler_track, "I_FOLDERDEPTH", 1) -- Set as a folder track
    reaper.SetMediaTrackInfo_Value(sampler_track, "I_FOLDERCOMPACT", 2) -- Set folder as collapsed
    reaper.UpdateArrange() --Update arrange view
end