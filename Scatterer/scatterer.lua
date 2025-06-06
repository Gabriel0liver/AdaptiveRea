-- @version 1.0.1
-- @description Scatterer
-- @author Gabriel Oliver
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + Fix atexit trying to reach project when reaper is closing
-- @license MIT



-- get script path\
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Scatterer Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/GUI Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Imgui General Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Main Loop.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Theme.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Json Main.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Settings.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Serialize Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/BirdBird Curve Editor.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Sampler Functions.lua') -- Functions for using the markov in reaper


if not CheckReaImGUI('0.8') or not CheckJS() or not CheckSWS() or not CheckREAPERVersion('6.0') then return end -- Check Extensions
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8') -- Made with Imgui 0.8 add schims for future versions.


----- Script Names
ScriptName = 'Scatterer'
Version = '1.0.1'

-- Load Settings
SettingsFileName = 'scatterer settings'
Settings()

-- Project configs (Loaded in the main loop at CheckProjects()) Need to start with an blank table
ProjConfigs = {}
ExtKey = 'project_config' -- ext state key
ProjPaths = {} -- Table with the paths for each project tab. ProjPaths[proj] = path

-- Gui Style
GroupIndent = 15 -- indentation of the group child
Gui_W_init = 300 -- Init 
Gui_H_init = 450 -- Init 
FLTMIN, FLTMAX = reaper.ImGui_NumericLimits_Float() --set the padding to the right side

-- Start
FirstRun = true -- prevent triggering on the first loop
GuiInit(ScriptName)
reaper.defer(main_loop)
reaper.atexit(Save) -- register function to run at the end

