local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'PassChooser'
obj.version = '0.1'
obj.author = 'Raitis Stengrevics'
obj.homepage = 'https://github.com/daGrevis/PassChooser.spoon'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

-- http://lua-users.org/wiki/StringRecipes
function string.ends(String, End)
   return End == '' or string.sub(String, -string.len(End)) == End
end

-- https://stackoverflow.com/a/15706820
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- https://gist.github.com/Badgerati/3261142
function string.levenshtein(str1, str2)
  local len1 = string.len(str1)
  local len2 = string.len(str2)
  local matrix = {}
  local cost = 0

  -- quick cut-offs to save time
  if (len1 == 0) then
    return len2
  elseif (len2 == 0) then
    return len1
  elseif (str1 == str2) then
    return 0
  end

  -- initialise the base matrix values
  for i = 0, len1, 1 do
    matrix[i] = {}
    matrix[i][0] = i
  end
  for j = 0, len2, 1 do
    matrix[0][j] = j
  end

  -- actual Levenshtein algorithm
  for i = 1, len1, 1 do
    for j = 1, len2, 1 do
      if (str1:byte(i) == str2:byte(j)) then
        cost = 0
      else
        cost = 1
      end

      matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
    end
  end

  -- return the last value - this is the Levenshtein distance
  return matrix[len1][len2]
end

config = {
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
  local front_app = hs.application.frontmostApplication()

  local output = hs.execute('find ' .. config.storePath .. ' -type f')

  local lines = hs.fnutils.filter(hs.fnutils.split(output, '\n'), function(line)
    return line ~= '' and not line:ends('.gpg-id')
  end)

  local all_texts = hs.fnutils.map(lines, function(line)
    local filename = hs.fnutils.split(line, '//')[2]
    return filename:sub(0, filename:len() - 4)
  end)

  function restore()
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

    front_app:activate()
  end

  local chooser = hs.chooser.new(function(choosen)
    restore()
  end)

  local choices = {}
  chooser:queryChangedCallback(function()
    local query = chooser:query()

    local chars = {}
    for i = 1, #query do
      table.insert(chars, query:sub(i, i))
    end

    -- http://lua-users.org/wiki/PatternsTutorial
    local fuzzy_query = table.concat(chars, '.-')

    local matching_texts = hs.fnutils.filter(all_texts, function(text)
      return text:find(fuzzy_query)
    end)

    local items = {}
    for i, text in pairs(matching_texts) do
      local distance
      if query == '' then
        distance = 1
      else
        distance = text:levenshtein(query)
      end
      table.insert(items, { text=text, distance=distance })
    end

    choices = {}
    for k,v in spairs(items, function(t, a, b)
      if t[a].distance == t[b].distance then
        return t[a].text < t[b].text
      else
        return t[a].distance < t[b].distance
      end
    end) do
      table.insert(choices, { text=v.text })
    end

    chooser:choices(choices)
  end)

  function copyPassword(index)
    local item = choices[index]

    local password, status = hs.execute('pass show ' .. item.text, true)

    if not status then
      return
    end

    -- Assumes that password is on the first line just like pass does.
    local password = hs.fnutils.split(password, '\n')[1]

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

function obj:bindHotkeys(mapping)
  if hotkey then
      hotkey:delete()
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
