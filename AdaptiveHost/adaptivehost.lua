-- @version 1.0.1
-- @description Scatterer
-- @author Gabriel Oliver
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + Fix atexit trying to reach project when reaper is closing
-- @license MIT

local opsys = reaper.GetOS()
local extension 
if opsys:match('Win') then
  extension = 'dll'
else -- Linux and Macos
  extension = 'so'
end

local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?."..extension  -- Add current folder/socket module for looking at .dll (need for loading basic luasocket)
package.path = package.path .. ";" .. script_path .. "/socket module/?.lua" -- Add current folder/socket module for looking at .lua ( Only need for loading the other functions packages lua osc.lua, url.lua etc... You can change those files path and update this line)ssssssssssssssssssssssssssssssssssss


-- get script path\
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Host Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/GUI Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Imgui General Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Main Loop.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Theme.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Json Main.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Settings.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Serialize Functions.lua') -- Functions for using the markov in reaper

if not CheckReaImGUI('0.8') or not CheckJS() or not CheckSWS() or not CheckREAPERVersion('6.0') then return end -- Check Extensions
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8') -- Made with Imgui 0.8 add schims for future versions.


----- Script Names
ScriptName = 'AdaptiveHost'
Version = '1.0.1'

-- Load Settings
SettingsFileName = 'AdaptiveHost settings'
Settings()

-- Project configs (Loaded in the main loop at CheckProjects()) Need to start with an blank table
ProjConfigs = {}
ExtKey = 'project_config' -- ext state key
ProjPaths = {} -- Table with the paths for each project tab. ProjPaths[proj] = path

-- Gui Style
GroupIndent = 15 -- indentation of the group child
Gui_W_init = 275 -- Init 
Gui_H_init = 450 -- Init 
FLTMIN, FLTMAX = reaper.ImGui_NumericLimits_Float() --set the padding to the right side

-- Get socket and osc modules
socket = require('socket.core')
osc = require('osc')

-- Get UDP
udp = assert(socket.udp())
assert(udp:setsockname("127.0.0.1",9004)) -- Set IP and PORT
udp:settimeout(0.0001) -- Dont forget to set a low timeout! udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.


-- Start
FirstRun = true -- prevent triggering on the first loop
GuiInit(ScriptName)
reaper.defer(main_loop)
reaper.atexit(Save) -- register function to run at the end