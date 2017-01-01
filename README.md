# passchooser

## Install

Make sure you have working [`pass`](https://www.passwordstore.org/), `gpg-agent`, `pinentry-mac` and [Hammerspoon](https://github.com/Hammerspoon/hammerspoon).

1) Clone repo to `~/.hammerspoon/passchooser`,

2) Require and bind `passchooser` from your `~/.hammerspoon/init.lua`:

```lua
local passchooser = require "passchooser/passchooser"

passchooser.bind()
-- passchooser.bind({"cmd"}, "p")
```
