# Whelp - Claude Code Context

## Project Summary

Whelp is a World of Warcraft addon for TBC Anniversary 2026 that provides a "Yelp-style" rating system for player-run services like profession packages, enchanting, boosting, and more.

## Quick Reference

### Key Files
- [Whelp.toc](Whelp.toc) - Addon manifest and load order
- [Whelp.lua](Whelp.lua) - Main entry point, slash commands
- [Core/Constants.lua](Core/Constants.lua) - All configuration values
- [Core/Database.lua](Core/Database.lua) - SavedVariables management
- [UI/MainFrame.lua](UI/MainFrame.lua) - Main browsing interface

### Architecture
```
Whelp (global namespace)
├── Utils        - Utility functions
├── Database     - Data persistence
├── EventHandler - Event system
├── CategoryManager - Service categories
├── VendorManager   - Vendor CRUD
├── RatingSystem    - Reviews/ratings
└── UI
    ├── Templates    - Reusable components
    ├── MainFrame    - Main window
    ├── VendorCard   - Vendor cards
    ├── VendorDetail - Detail view
    ├── ReviewForm   - Review editor
    ├── SearchBar    - Quick search
    └── MinimapButton - Minimap icon
```

### Common Tasks

**Add a new category:**
1. Edit `Core/Constants.lua` - Add to `Whelp.Categories`
2. Update `Data/Categories.lua` - Add to order array

**Add a slash command:**
1. Edit `Whelp.lua` - Add case in `HandleSlashCommand`

**Create new UI component:**
1. Create file in `UI/` directory
2. Use `Templates` for consistent styling
3. Add to `Whelp.UI` namespace
4. Add to `Whelp.toc`

**Test changes:**
1. Save files
2. In-game: `/reload`
3. Check for errors
4. Use `/whelp debug` for debug messages

### Data Structures

**Vendor:**
```lua
{
    id = "uid_123",
    name = "Player-Realm",
    category = "profession_package",
    description = "...",
    pricing = "...",
    averageRating = 4.5,
    reviewCount = 10,
}
```

**Review:**
```lua
{
    id = "uid_456",
    vendorId = "uid_123",
    authorName = "Reviewer-Realm",
    rating = 5,
    content = "...",
    timestamp = 1234567890,
}
```

### Debugging

```
/whelp debug    - Toggle debug mode
/whelp stats    - Show database stats
/whelp reset confirm - Clear all data
```

### Documentation

- [.claude/project.md](.claude/project.md) - Full project overview
- [.claude/architecture.md](.claude/architecture.md) - Technical architecture
- [.claude/coding-standards.md](.claude/coding-standards.md) - Style guide
- [.claude/development.md](.claude/development.md) - Development guide

### CI/CD

- `.github/workflows/ci.yml` - Linting, validation, packaging
- `.github/workflows/release.yml` - GitHub releases, CurseForge upload

Tag a version to release: `git tag v1.0.1 && git push --tags`
