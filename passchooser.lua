function string.ends(String, End)
   return End == '' or string.sub(String, -string.len(End)) == End
end

local mod = {}

function mod.passchooser()
  local front_app = hs.application.frontmostApplication()

  local output = hs.execute("find ~/.password-store/ -type f")

  local lines = hs.fnutils.filter(hs.fnutils.split(output, "\n"), function(line)
    return line ~= '' and not line:ends('.gpg-id')
  end)

  local items = hs.fnutils.map(lines, function(line)
    local filename = hs.fnutils.split(line, '//')[2]
    return filename:sub(0, filename:len() - 4)
  end)

  function restore()
    if enterBind then enterBind:delete() end
    if escapeBind then escapeBind:delete() end
    if ccBind then ccBind:delete() end
    if numberBinds then
      for i, bind in pairs(numberBinds) do
        bind:delete()
      end
    end

    front_app:activate()
  end

  local chooser = hs.chooser.new(function(choosen)
    restore()
  end)

  local choices = {}
  chooser:queryChangedCallback(function()
    local q = chooser:query()

    local foundItems = hs.fnutils.filter(items, function(item)
      return item:find(q)
    end)

    choices = hs.fnutils.map(foundItems, function(item)
      return { text=item }
    end)

    chooser:choices(choices)
  end)

  function copyPassword(index)
    local item = choices[index]

    local password, status = hs.execute("pass show " .. item.text, true)

    if not status then
      return
    end

    local first_line = hs.fnutils.split(password, "\n")[1]

    hs.pasteboard.setContents(first_line)

    local seconds = 45
    hs.timer.doAfter(seconds, function()
      local pb_contents = hs.pasteboard.getContents()
      if first_line == pb_contents then
        hs.pasteboard.setContents('')
      end
    end)

    hs.alert.show("Password for " .. item.text .. " copied!")
  end

  enterBind = hs.hotkey.bind('', 'return', function()
    local id = chooser:selectedRow()
    chooser:delete()
    restore()
    copyPassword(id)
  end)

  escapeBind = hs.hotkey.bind('', 'escape', function()
    chooser:delete()
    restore()
  end)

  ccBind = hs.hotkey.bind({'ctrl'}, 'c', function()
    chooser:delete()
    restore()
  end)

  numberBinds = {}
  local i = 1
  while i <= 9 do
    local id = i
    numberBinds[#numberBinds + 1] = hs.hotkey.bind({'cmd'}, tostring(i), function()
      chooser:delete()
      restore()
      copyPassword(id)
    end)

    i = i + 1
  end

  chooser:show()
end

function mod.bind(mods, key)
  mods = mods or {"cmd"}
  key = key or "p"

  hs.hotkey.bind(mods, key, mod.passchooser)
end

return mod
