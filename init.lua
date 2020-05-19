local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'PassChooser'
obj.version = '0.1'
obj.author = 'Raitis Stengrevics'
obj.homepage = 'https://github.com/daGrevis/PassChooser.spoon'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

local FZF_PATH = '/Users/dagrevis/.fzf/bin/fzf'

local function endsWith(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local config = {
  clearAfter=0,
  storePath='~/.password-store/',
}

function obj:init(userConfig)
  if not userConfig then
    userConfig = {}
  end

  if userConfig.clearAfter then
    config.clearAfter = userConfig.clearAfter
  end
  if userConfig.storePath then
    config.storePath = userConfig.storePath
  end
end

function obj:start()
  local frontApp = hs.application.frontmostApplication()

  local findOutput = hs.execute('find ' .. config.storePath .. ' -type f')

  local findLines = hs.fnutils.split(findOutput, '\n')

  findLines[#findLines] = nil

  findLines = hs.fnutils.filter(findLines, function(line)
    return not endsWith(line, '.gpg-id')
  end)

  findLines = hs.fnutils.map(findLines, function(line)
    local filename = hs.fnutils.split(line, '//')[2]
    return filename:sub(0, filename:len() - 4)
  end)

  local function restore()
    if enterBind['delete'] then enterBind:delete() end
    if escapeBind['delete'] then escapeBind:delete() end
    if ccBind['delete'] then ccBind:delete() end
    if numberBinds then
      for i, bind in pairs(numberBinds) do
        if bind['delete'] then
          bind:delete()
        end
      end
    end

    frontApp:activate()
  end

  local chooser = hs.chooser.new(function()
    restore()
  end)

  local choices = {}
  chooser:queryChangedCallback(function()
    local query = chooser:query()

    local fzfInput = table.concat(findLines, '\n')

    local command = 'echo ' .. "'" .. fzfInput .. "'" .. ' | ' .. FZF_PATH .. ' -f ' .. "'" .. query .. "'"

    local fzfOutput = hs.execute(command)

    local fzfLines = hs.fnutils.split(fzfOutput, '\n')

    fzfLines[#fzfLines] = nil

    choices = {}
    for _, line in pairs(fzfLines) do
      table.insert(choices, { text=line })
    end

    chooser:choices(choices)
  end)

  local function copyPassword(index)
    local item = choices[index]

    local password, status = hs.execute('pass show ' .. item.text, true)

    if not status then
      return
    end

    -- Assumes that password is on the first line just like pass does.
    password = hs.fnutils.split(password, '\n')[1]

    hs.pasteboard.setContents(password)

    -- Clear pasteboard after N seconds if nothing else has been copied.
    if config.clearAfter ~= 0 then
      hs.timer.doAfter(config.clearAfter, function()
        if password == hs.pasteboard.getContents() then
          hs.pasteboard.setContents(' ')
        end
      end)
    end

    hs.alert.show('copied: ' .. item.text)
  end

  enterBind = hs.hotkey.bind('', 'return', function()
    local id = chooser:selectedRow()
    chooser:cancel()
    restore()
    copyPassword(id)
  end)

  escapeBind = hs.hotkey.bind('', 'escape', function()
    chooser:cancel()
    restore()
  end)

  ccBind = hs.hotkey.bind({'ctrl'}, 'c', function()
    chooser:cancel()
    restore()
  end)

  numberBinds = {}
  local i = 1
  while i <= 9 do
    local id = i
    numberBinds[#numberBinds + 1] = hs.hotkey.bind({'cmd'}, tostring(i), function()
      chooser:cancel()
      restore()
      copyPassword(id)
    end)

    i = i + 1
  end

  chooser:show()
end

function obj:bindHotkeys(mapping)
  if hotkey then
      hotkey:cancel()
  end

  local showMapping = mapping['show']
  if showMapping then
    hotkey = hs.hotkey.new(
      showMapping[1],
      showMapping[2],
      function()
        obj:start()
      end
    ):enable()
  end

  return self
end

return obj
