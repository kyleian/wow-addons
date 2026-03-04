# Changelog

All notable changes to Whelp will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.0.0] - 2026-01-24

### Added
- Initial release of Whelp addon
- Vendor management system
  - Add vendors with name, category, description, and pricing
  - Target integration for quick vendor addition
  - Edit and delete vendors you created
- Rating and review system
  - 5-star rating with written reviews
  - Edit and delete your own reviews
  - Mark reviews as helpful
  - Report inappropriate reviews
- Service categories
  - Profession Packages (1-300/375)
  - Enchanting Services
  - Crafting Services
  - Boosting Services
  - Gold Services
  - Portal Services
  - Arena Services
  - Raid Services
  - Other Services
- User interface
  - Main browsing window with tabs
  - Vendor detail view with all reviews
  - Review creation/editing form
  - Quick search overlay
- Search and filtering
  - Search by vendor name
  - Filter by category
  - Filter by minimum rating
  - Sort by rating, reviews, or recent activity
- Personal features
  - Favorites list
  - Recently viewed vendors
  - Your reviews list
  - Blocked vendors
- Minimap button integration
  - Drag to reposition
  - Left-click to open
  - Shift+Left-click for quick search
  - Right-click for context menu
- Keybinding support
  - Toggle Whelp window
  - Quick search
- Slash commands
  - /whelp - Open main UI
  - /whelp search - Quick search
  - /whelp add - Add vendor
  - /whelp target - Rate target
  - /whelp favorites - View favorites
  - /whelp reviews - View your reviews
  - /whelp minimap - Toggle minimap button
  - /whelp stats - Show statistics
  - /whelp help - Show help

### Technical
- SavedVariables for persistent data storage
- Database migration system for future updates
- CI/CD pipeline for automated testing and releases
- CurseForge integration for easy distribution

---

## Version History

- **1.0.0** - Initial release
