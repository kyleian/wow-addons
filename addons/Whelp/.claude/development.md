# Whelp Development Guide

## Getting Started

### Prerequisites

- World of Warcraft: TBC Anniversary 2026 client
- Text editor with Lua support (VS Code recommended)
- Git for version control

### Installation for Development

1. Clone the repository:
   ```bash
   git clone https://github.com/kyle-ian/whelp-tbc-lua.git
   ```

2. Create a symlink to your WoW AddOns folder:
   ```bash
   # macOS/Linux
   ln -s /path/to/whelp-tbc-lua "/path/to/WoW/_classic_/Interface/AddOns/Whelp"

   # Windows (run as admin)
   mklink /D "C:\WoW\_classic_\Interface\AddOns\Whelp" "C:\path\to\whelp-tbc-lua"
   ```

3. Launch WoW and ensure Whelp appears in the AddOns list

### Development Workflow

1. Make changes to Lua files
2. In-game, type `/reload` to reload UI
3. Test your changes
4. Use `/whelp debug` to enable debug messages
5. Check for errors in the Lua error frame

## Testing

### Manual Testing Checklist

- [ ] Addon loads without errors
- [ ] Minimap button appears and is draggable
- [ ] Main frame opens with `/whelp`
- [ ] All tabs are clickable and display correct content
- [ ] Can add a new vendor
- [ ] Can write a review
- [ ] Can edit/delete own review
- [ ] Search returns correct results
- [ ] Filters work correctly
- [ ] Favorites can be added/removed
- [ ] Data persists after reload
- [ ] Data persists after logout/login

### Debug Commands

```
/whelp debug      - Toggle debug mode
/whelp stats      - Show database statistics
/whelp reset confirm - Reset all data (USE CAREFULLY)
```

### Common Issues

**Addon not loading:**
- Check TOC Interface version matches your game version
- Verify all files listed in TOC exist
- Check for Lua syntax errors

**UI not displaying:**
- Check frame strata and level
- Verify parent frame exists
- Check for nil references in frame creation

**Data not saving:**
- SavedVariables must be listed in TOC
- Data only saves on logout/reload
- Check for serialization errors with complex data

## Adding Features

### Adding a New Category

1. Edit `Core/Constants.lua`:
   ```lua
   Whelp.Categories.NEW_CATEGORY = {
       id = "new_category",
       name = "New Category",
       description = "Description here",
       icon = "Interface\\Icons\\IconName",
   }
   ```

2. Add to CategoryLookup:
   ```lua
   for key, data in pairs(Whelp.Categories) do
       Whelp.CategoryLookup[data.id] = data
   end
   ```

3. Update `Data/Categories.lua` order array if needed

### Adding a New UI Component

1. Create file in `UI/` folder
2. Follow the Templates.lua patterns
3. Add to Whelp.UI namespace
4. Add file to Whelp.toc

Example:
```lua
--[[
    Whelp - NewComponent
    Description of component
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.NewComponent = {}
local NewComponent = Whelp.UI.NewComponent
local Templates = Whelp.UI.Templates

function NewComponent:Create(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Templates:CreateBackdrop(frame)
    -- ... rest of implementation
    return frame
end
```

### Adding a Slash Command

In `Whelp.lua`, add to `HandleSlashCommand`:
```lua
elseif cmd == "newcmd" then
    -- Handle new command
    self:DoNewThing()
```

### Adding Custom Events

1. Define in `Core/EventHandler.lua`:
   ```lua
   EventHandler.CustomEvents = {
       -- existing events...
       MY_NEW_EVENT = "WHELP_MY_NEW_EVENT",
   }
   ```

2. Fire the event:
   ```lua
   Whelp.EventHandler:FireCustomEvent(
       Whelp.EventHandler.CustomEvents.MY_NEW_EVENT,
       arg1, arg2
   )
   ```

3. Register listener:
   ```lua
   Whelp.EventHandler:RegisterCustomEvent(
       Whelp.EventHandler.CustomEvents.MY_NEW_EVENT,
       function(eventName, arg1, arg2)
           -- Handle event
       end
   )
   ```

## Database Migrations

When changing the SavedVariables structure:

1. Increment `Whelp.DB_VERSION` in Constants.lua
2. Add migration logic in `Database:MigrateDatabase()`:

```lua
function Database:MigrateDatabase()
    local currentVersion = WhelpDB.dbVersion or 0

    if currentVersion < 2 then
        -- Migration from v1 to v2
        WhelpDB.global.newField = {}
        -- Move/transform existing data
    end

    WhelpDB.dbVersion = Whelp.DB_VERSION
end
```

## Releasing

### Version Bump Checklist

1. Update version in `Whelp.toc`
2. Update `CHANGELOG.md`
3. Run linting: `luacheck .`
4. Test thoroughly in-game
5. Commit changes
6. Create git tag: `git tag v1.0.1`
7. Push with tags: `git push origin main --tags`

### CurseForge Setup

1. Create project on CurseForge
2. Note your Project ID
3. Generate API token
4. Add secrets to GitHub:
   - `CF_API_KEY`: Your CurseForge API token
   - `CF_PROJECT_ID`: Your project ID

The release workflow will automatically upload when you push a version tag.

## Useful Resources

- [WoW API Documentation](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)
- [WoW Widget API](https://wowpedia.fandom.com/wiki/Widget_API)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
- [TBC Classic API Changes](https://wowpedia.fandom.com/wiki/Patch_2.5.0/API_changes)

## Code Review Checklist

- [ ] Follows naming conventions
- [ ] Has appropriate comments/documentation
- [ ] No debug code left in
- [ ] Error handling for user input
- [ ] No memory leaks (orphaned frames, event handlers)
- [ ] Works with both fresh and existing SavedVariables
- [ ] UI elements have tooltips where appropriate
- [ ] Strings are user-friendly
