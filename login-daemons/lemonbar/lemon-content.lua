#!/bin/lua

-- string helpers
function string:split(sep)
   local sep, fields = sep or " ", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function string:join(list)
   local str = ''
   for i, item in ipairs(list) do str = str..tostring(item)..self end
   return str:sub(0, (#self>0 and -#self-1 or nil))
end

function round(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or '0') .. "f", num))
end

function string:trim()
  return (self:gsub("^%s*(.-)%s*$", "%1"))
end

function table.cat(a, b)
   local c = {unpack(a)}
   for i=1, #b do c[#c+1] = b[i] end
   return c
end



HPATH = '/home/evolbug/.hooks'

local hook = {
   battery = {
      status = io.open (HPATH..'/bat/status'),
      level  = io.open (HPATH..'/bat/capacity')
   };

   network = {
      ssid     = io.open (HPATH..'/net/ssid'),
      strength = io.open (HPATH..'/net/strength')
   };

   wm = {
      windows = io.open (HPATH..'/wm/windows'),
      focus   = io.open (HPATH..'/wm/focused')
   };

   time = io.open (HPATH..'/time/time')
}

function query(h)
   h:seek "set"
   return h:read("*all"):trim()
end

local data = {
   battery = {
      status   = function() return query(hook.battery.status) end,
      level    = function() return tonumber(query(hook.battery.level)) end
   };

   network = {
      ssid     = function() return query(hook.network.ssid) end,
      strength = function()
         local str = query(hook.network.strength):split("/")
         return #str>0 and round(str[1]/str[2], 1) or .2
      end
   };

   wm = {
      windows  = function()
         local wlist = {}
         local wraw = query(hook.wm.windows):split('\n')

         for _, wline in ipairs(wraw) do
            wargs = wline:split()

            if wargs[2] == '0' then
               local wname = ""

               for i=4, #wargs do
                  wname = wname .. ' ' .. wargs[i]
               end

               wlist[tonumber(wargs[1])] = wname:trim() -- id = name
            end
         end

         return wlist
      end,

      focus = function() return tonumber(query(hook.wm.focus)) end
   };
   time = function() return query(hook.time) end;
}



-- unicode helpers
function u (...) -- convert stream of utf8 indices to chars
   -- u (utf8id, ...)
   -- u (start, "amount")

   local args = {...}

   if type(args[2]) == "string" then
      local forward = tonumber(args[2])
      args = {args[1]}
      for i=1, forward do args[#args+1] = args[1]+i end
   end

   local c = {}
   for i, x in ipairs(args) do
      c[i] = utf8.char(x)
   end

   return unpack(c)
end



function string:onClick(call, ...)
   local fn = call
   for i, arg in ipairs{...} do fn = fn..' '..tostring(arg) end
   return "%{A:"..fn..":}"..self.."%{A}"
end


local icons = {
--   bat = {u(0xe242, "9")},
   bat = {u(0xe242), u(0xe24c,"8")},
--   bat = {u(0xe210, "4")},
--   bat = {u(0xe034,"3")},
--   bat = {u(0xe1fd, "2")},
--   bat = {u(0xe211, "3")},
--   net = {u(0xe25d, "4")},
   net = {u(0xe21b, "3")},
   app = {
      term     = u(0xe1ef),
      search   = u(0xe1ee),
      files    = u(0xe1e0),
      git      = u(0xe1d3),
      task     = u(0xe223),
      net      = u(0xe1a0),
      sys      = u(0xe021),
      pac      = u(0xe14d),
      writer   = u(0xe1ed),
      ssheets  = u(0xe267),
      present  = u(0xe1d1),
      pencil   = u(0xe22a),
      pencil2  = u(0xe1e5),
   }
}


function iconify(name, focused)
   if not focused then
      local app = function(n) return name:lower():find(n) end

      if     app "firefox"       then return icons.app.net
      elseif app "terminal"      then return icons.app.term
      elseif app "xfd"           then return icons.app.sys
      elseif app "discord"       then return icons.app.pac
      elseif app "task manager"  then return icons.app.task
      elseif app "finder"        then return icons.app.search
      elseif app "file manager"  then return icons.app.files
      elseif app "writer"        then return icons.app.writer
      elseif app "spreadsheets"  then return icons.app.ssheets
      elseif app "presentation"  then return icons.app.present
      end
   end

   return name
end



function glue(...)
   local string = ''
   for i, arg in ipairs{...} do
      arg = type(arg)=="function" and arg() or type(arg)=="table" and glue(unpack(arg)) or arg
      string = string..tostring(arg)
   end
   return string
end


function _() return " " end
function __() return "  " end
function R(...) return "%{R}"..glue(...).."%{R}" end -- reverse
function U(...) return "%{!u}"..glue(...).."%{!u}" end -- underline
function O(...) return "%{!o}"..glue(...).."%{!o}" end -- overline



function windows()
   local wbar = ""

   for id, title in pairs(data.wm.windows()) do
      local wicon = iconify(title)

      if data.wm.focus() == id then
         wicon = U(' '..wicon..' ')
      end

      wicon = wicon:onClick ('xdotool windowactivate', id)
      wbar = wbar..' '..wicon
   end

   return wbar
end

function window_title()
   for id, title in pairs(data.wm.windows()) do
      if data.wm.focus() == id then return title end
   end
   return ''
end

function time()
   local ctime = data.time():onClick 'notify-send -u critical "`date +\'%A %B %d\'`" "`cal`"'
   return ctime
end

function battery()
   local level  = data.battery.level() or 1
   local status = data.battery.status()
   local icon = icons.bat[round(level/(100/#icons.bat+1)+.5)]
   icon = icon:onClick ('notify-send "Battery\\: ', level, '"')

   if level <= 25 and status ~= 'Charging' then
      icon = "%{F#ff3070}"..icon
   elseif status == 'Charging' then
      icon = "%{F#66cc9e}"..icon
   end

   return icon.."%{F-}"
end

function network()
   local net = data.network.ssid()
   local strength = round(data.network.strength() * #icons.net)
   icon = (net or '')..icons.net[strength]
   return icon:onClick 'xfce4-terminal -e nmtui-connect &'
end

function editbar()
   return icons.app.pencil:onClick'xfce4-terminal -e "micro /home/evolbug/.login-daemons/lemonbar/lemon-content.lua"'
end




function bar(left, center, right)
   print (glue("%{l}", left, "%{c}", center, "%{r}", right))
end



while true do
   bar (windows, window_title, {network,_,battery,__,time,__})
   os.execute 'sleep 1'
end
