# PassChooser

macOS UI for selecting and copying password into clipboard

![](PassChooser.gif)

## Installation

- Make sure [`pass`](https://www.passwordstore.org/) command works in the terminal

- Install [Hammerspoon](http://www.hammerspoon.org/)

- Install `PassChooser.spoon`
    - Download [the `.zip`](https://github.com/daGrevis/PassChooser.spoon/archive/master.zip), uncompress it and double-click on the Spoon
    - ...or clone the repo and move it to `~/.hammerspoon/Spoons/`

- Load and configure the Spoon via `~/.hammerspoon/init.lua`

```lua
local PassChooser = hs.loadSpoon('PassChooser')

-- Bind ⌘+p
PassChooser:bindHotkeys({
  show={{'cmd'}, 'p'},
})

-- Optional config
PassChooser:init({
  -- Clear password from clipboard after N seconds
  -- Defaults to 0 which disables this
  clearAfter=10,
  -- Path to GPG-encrypted passwords
  storePath='~/.password-store/',
})
```

- Reload Hammerspoon
