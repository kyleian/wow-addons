# Whelp - Vendor Rating System for WoW TBC

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Interface](https://img.shields.io/badge/interface-20504-green)
![License](https://img.shields.io/badge/license-MIT-yellow)

A "Yelp-style" addon for World of Warcraft: The Burning Crusade Anniversary 2026 that lets players rate and review in-game service vendors.

## Features

- **Rate Vendors**: 5-star rating system with written reviews
- **Browse Services**: Discover vendors for profession packages, enchanting, boosting, and more
- **Search & Filter**: Find vendors by name, category, or minimum rating
- **Favorites**: Save your preferred vendors for quick access
- **Quick Search**: Pop-up search bar accessible from anywhere
- **Target Integration**: Rate your current target with `/whelp target`
- **Minimap Button**: Quick access with left-click, context menu with right-click

## Installation

### CurseForge (Recommended)
1. Install the CurseForge app
2. Search for "Whelp" in WoW Classic addons
3. Click Install

### Manual Installation
1. Download the latest release from [GitHub Releases](https://github.com/kyle-ian/whelp-tbc-lua/releases)
2. Extract `Whelp` folder to:
   - **Windows**: `C:\World of Warcraft\_classic_\Interface\AddOns\`
   - **macOS**: `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
3. Restart WoW or type `/reload`

## Usage

### Opening Whelp
- Type `/whelp` in chat
- Click the minimap button
- Use a keybinding (set in Key Bindings → Addons → Whelp)

### Commands

| Command | Description |
|---------|-------------|
| `/whelp` | Open main interface |
| `/whelp search` | Open quick search |
| `/whelp add` | Add a new vendor |
| `/whelp target` | Rate current target |
| `/whelp favorites` | View favorites |
| `/whelp reviews` | View your reviews |
| `/whelp minimap` | Toggle minimap button |
| `/whelp stats` | Show statistics |
| `/whelp help` | Show all commands |

### Adding a Vendor

1. Open Whelp with `/whelp`
2. Click the "**+ Add Vendor**" tab
3. Enter the vendor's character name (Name-Realm format)
   - Or target the vendor and click "Use Current Target"
4. Select the service category
5. Add a description and pricing info
6. Click "Add Vendor"

### Writing a Review

1. Click on any vendor card to open their details
2. Click "Write Review"
3. Select a star rating (1-5)
4. Write your review
5. Click "Submit Review"

## Service Categories

- **Profession Packages** - 1-300/375 leveling kits
- **Enchanting Services** - Weapon and armor enchants
- **Crafting Services** - Crafted items and gear
- **Boosting Services** - Dungeon runs, leveling
- **Gold Services** - GDKP runs, etc.
- **Portal Services** - Mage portals
- **Arena Services** - Arena carries and coaching
- **Raid Services** - Raid carries and attunements
- **Other Services** - Miscellaneous

## Screenshots

*Coming soon*

## FAQ

**Q: Is my data shared with other players?**
A: Currently, data is stored locally. Future versions may include data sharing features.

**Q: Can I rate NPCs?**
A: No, Whelp is designed for rating player-run services only.

**Q: How do I report an inappropriate review?**
A: Click the report button on any review. Reported reviews are flagged for review.

**Q: Can I edit my reviews?**
A: Yes! Find your review in the vendor's detail page or in "My Reviews" and click Edit.

## Contributing

Contributions are welcome! Please see our [development guide](.claude/development.md) for details.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Building

```bash
# Run linting
luacheck .

# Package for release
./package.sh  # or use GitHub Actions
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

- **Author**: Kyle
- **Libraries**: LibStub, CallbackHandler, LibDataBroker, LibDBIcon

## Support

- **Issues**: [GitHub Issues](https://github.com/kyle-ian/whelp-tbc-lua/issues)
- **Discord**: *Coming soon*

---

Made with love for the WoW TBC Anniversary 2026 community
