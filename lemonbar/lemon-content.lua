#!/bin/lua

-- unicode helpers
u = utf8.char
function ul(...)
   c={}
   for i,x in ipairs({...}) do
      table.insert(c, u(x))
   end
   return c
end


-- string helpers
function string:split(sep)
   local sep, fields = sep or " ", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)

   return fields
end

function string:join(list)
   local str = ''

   for i, item in ipairs(list) do
      str = str .. tostring(item) .. self
   end

   return (str:sub(0, (#self>0 and -#self-1 or nil)))
end

function string:onClick(call, ...)
   local fn = call
   for i, arg in ipairs({...}) do
      fn = fn .. ' ' .. tostring(arg)
   end

   return "%{A:"..fn..":}"..self.."%{A}"
end



function round(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end



local icons = {
   bat = ul(0xe242,0xe24c,0xe24d,0xe24e,0xe24f,0xe250,0xe251,0xe252,0xe253,0xe254),
--   bat = ul(0xe034,0xe035,0xe036,0xe037),
   net = ul(0xe0f1,0xe0f2,0xe0f3,0xe0f0),
   app = {
      term = u(0xe1ef),
      search = u(0xe1ee),
      files = u(0xe1e0),
      git = u(0xe1d3),
      task = u(0xe223),
      net = u(0xe1a0),
      sys = u(0xe021),
      pac = u(0xe14d)
   }
}



function hasFocus(windowID)
   return tonumber(io.popen("xdotool getwindowfocus"):read()) == tonumber(windowID)
end

function iconify(name, focused)
   if not focused then
      local app = function(n) return (name:lower()):find(n) end

      if app "firefox" then return icons.app.net
      elseif app "terminal" then return icons.app.term
      elseif app "xfd" then return icons.app.sys
      elseif app "discord" then return icons.app.pac
      elseif app "task manager" then return icons.app.task
      elseif app "finder" then return icons.app.search
      elseif app "file manager" then return icons.app.files
      end
   end
   return name
end



function windows()
   local windowlist = {}

   for window in io.popen("wmctrl -l"):lines() do

      local wargs = window:split()

      if wargs[2] == '0' then
         local windowName = {}

         for i=4, #(wargs) do
            table.insert(windowName, wargs[i])
         end

         windowName = ' '..iconify(((' '):join(windowName)))..' '

         if hasFocus(wargs[1]) then
            windowName = '%{!u}'..windowName..'%{!u}'
         end

         windowName = windowName:onClick('xdotool', 'windowactivate', wargs[1])

         table.insert(windowlist, windowName)
      end

   end

   return (''):join(windowlist)
end

function time()
   local ctime = io.popen("date +%H:%M"):read()
   ctime = ctime:onClick('notify-send', '-u critical', '"`date +\'%A %B %d\'`"','"`cal`"')
   return ' '..ctime..' '
end

function battery()
   local level = io.popen('cat /sys/class/power_supply/BAT0/capacity'):read()
   local status = io.popen('cat /sys/class/power_supply/BAT0/status'):read()

   local icon = icons.bat[round(tonumber(level)/(100/#icons.bat)+.5)]
   icon = icon:onClick('notify-send ', '"Battery\\: '..level..'"')

   if tonumber(level) <= 25 and not status == 'Charging' then
      icon = "%{F#ff3070}"..icon.." %{F#-}"
   end
   if status == 'Charging' then
      icon = "%{F#66cc9e}"..icon.." %{F#-}"
   end
   return icon..' '
end

function network()
   local net=io.popen("iwgetid -r"):read()
   icon = net and (icons.net[4]):onClick('xfce4-terminal -e nmtui-connect') or ''
   return icon..' '
end



function L() return "%{l}" end
function R() return "%{r}" end
function C() return "%{c}" end

function glue(...)
   local contents = ''

   for i, arg in ipairs({...}) do
      contents = contents .. tostring(arg())
   end

   return contents
end



while true do
   print(glue(
      L, windows,
      C,
      R, network, battery, time
   ))
   os.execute('sleep 1s')
end
