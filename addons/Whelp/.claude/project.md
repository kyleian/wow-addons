# Whelp - WoW TBC Vendor Rating Addon

## Project Overview

Whelp is a "Yelp-style" addon for World of Warcraft: The Burning Crusade Anniversary 2026 that allows players to rate and review in-game service vendors. This includes profession package sellers, enchanters, boosters, and other player-run services.

## Tech Stack

- **Language**: Lua 5.1 (WoW's embedded interpreter)
- **Framework**: WoW Addon API (Interface 20504 - TBC 2.5.4)
- **Libraries**:
  - LibStub - Library versioning
  - CallbackHandler-1.0 - Event callbacks
  - LibDataBroker-1.1 - Data broker for minimap
  - LibDBIcon-1.0 - Minimap button management

## Project Structure

```
whelp-tbc-lua/
├── .claude/              # Claude AI context files
├── .github/workflows/    # CI/CD pipelines
├── Core/                 # Core functionality
│   ├── Constants.lua     # Global constants and defaults
│   ├── Utils.lua         # Utility functions
│   ├── Database.lua      # SavedVariables management
│   └── EventHandler.lua  # WoW event handling
├── Data/                 # Data management
│   ├── Categories.lua    # Service categories
│   ├── VendorManager.lua # Vendor CRUD operations
│   └── RatingSystem.lua  # Review/rating logic
├── UI/                   # User interface
│   ├── Templates.lua     # Reusable UI components
│   ├── MainFrame.lua     # Main browsing window
│   ├── VendorCard.lua    # Vendor card component
│   ├── VendorDetail.lua  # Detailed vendor view
│   ├── ReviewForm.lua    # Review creation form
│   ├── SearchBar.lua     # Quick search overlay
│   └── MinimapButton.lua # Minimap integration
├── Libs/                 # External libraries
├── Bindings.xml          # Keybinding definitions
├── Whelp.toc             # Addon manifest
└── Whelp.lua             # Main entry point
```

## Key Features

1. **Vendor Management**: Add, view, and manage service vendors
2. **Rating System**: 5-star rating with written reviews
3. **Categories**: Profession packages, enchanting, boosting, etc.
4. **Search & Filter**: Find vendors by name, category, rating
5. **Favorites**: Save preferred vendors
6. **Quick Search**: Overlay search accessible anywhere
7. **Target Integration**: Rate your current target directly

## Data Storage

- **WhelpDB**: Global saved variables (shared across characters)
  - `vendors`: All vendor data
  - `reviews`: All review data
  - `profile`: UI settings, filters

- **WhelpCharDB**: Per-character saved variables
  - `myReviews`: Reviews written by this character
  - `favorites`: Favorited vendors
  - `recentlyViewed`: Recently viewed vendors
  - `blockedVendors`: Blocked vendors

## Commands

- `/whelp` - Open main interface
- `/whelp search` - Quick search
- `/whelp add` - Add new vendor
- `/whelp target` - Rate current target
- `/whelp favorites` - View favorites
- `/whelp minimap` - Toggle minimap button

## Development Guidelines

### Adding New Features

1. Check if it fits an existing module or needs a new one
2. Follow the established patterns (especially for UI components)
3. Use the Utils module for common operations
4. Fire custom events for cross-module communication
5. Update Constants.lua for new configuration values

### UI Development

- Use Templates.lua for creating consistent UI elements
- Follow the color scheme defined in Constants.lua
- Support ESC key to close frames (add to UISpecialFrames)
- Make frames movable when appropriate

### Testing

- Use `/whelp debug` to enable debug mode
- Check the Lua errors frame for issues
- Test with clean SavedVariables occasionally

## CI/CD

- **CI Pipeline**: Runs on push/PR to main
  - Lua linting with luacheck
  - TOC validation
  - Package creation

- **Release Pipeline**: Runs on version tags
  - Creates GitHub release
  - Uploads to CurseForge (when configured)

## Version History

- **1.0.0** - Initial release
  - Full vendor management
  - Rating and review system
  - Search and filtering
  - Minimap button integration
