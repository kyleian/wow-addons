# Whelp Architecture

## Module Dependency Graph

```
                    ┌─────────────┐
                    │   Whelp.lua │  (Main entry point)
                    │   (global)  │
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
    ┌───────────┐    ┌───────────┐    ┌───────────┐
    │   Core    │    │   Data    │    │    UI     │
    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
          │                │                │
    ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
    │Constants  │    │Categories │    │Templates  │
    │Utils      │    │VendorMgr  │    │MainFrame  │
    │Database   │    │RatingSystem    │VendorCard │
    │EventHandler    └───────────┘    │VendorDetail
    └───────────┘                     │ReviewForm │
                                      │SearchBar  │
                                      │MinimapBtn │
                                      └───────────┘
```

## Namespace

All modules are attached to the `Whelp` namespace table:

```lua
local ADDON_NAME, Whelp = ...
-- Whelp.Utils, Whelp.Database, Whelp.VendorManager, etc.
```

## Core Layer

### Constants.lua
- Version information
- Color definitions
- Category definitions
- UI dimension constants
- Default SavedVariables structure

### Utils.lua
- Table manipulation (DeepCopy, MergeTables)
- String formatting (TruncateText, FormatDate)
- Rating calculations and colors
- Validation functions
- Sorting and filtering helpers

### Database.lua
- SavedVariables initialization
- CRUD operations for vendors and reviews
- Database migration system
- Favorites and history management
- Import/Export functionality

### EventHandler.lua
- WoW event registration
- Custom event system for inter-module communication
- Event definitions (VENDOR_ADDED, REVIEW_ADDED, etc.)

## Data Layer

### Categories.lua
- Service category definitions
- Subcategory management (professions, enchants, etc.)
- Category lookup and validation

### VendorManager.lua
- Vendor creation, update, deletion
- Search and filtering
- Target integration
- Statistics calculation

### RatingSystem.lua
- Review creation and management
- Rating calculations
- Helpful votes
- Trending calculations
- Weighted rating algorithm (Wilson score)

## UI Layer

### Templates.lua
Factory functions for consistent UI elements:
- `CreateBackdrop(frame, bgColor, borderColor)`
- `CreateButton(parent, text, width, height, onClick)`
- `CreateTitleBar(parent, title, movable)`
- `CreateEditBox(parent, width, height, multiLine)`
- `CreateDropdown(parent, width, options, default, onChange)`
- `CreateStarRating(parent, rating, size, interactive)`
- `CreateScrollFrame(parent, width, height)`
- `CreateTabButton(parent, text, index, onClick)`
- `ShowTooltip(frame, title, lines)`

### MainFrame.lua
Main browsing interface with tabs:
- Browse: View all vendors with filters
- Search: Search functionality
- Favorites: User's favorite vendors
- My Reviews: User's written reviews
- Add Vendor: Form to add new vendors

### VendorCard.lua
Compact vendor summary card showing:
- Category icon
- Vendor name
- Star rating with count
- Description snippet
- Favorite toggle

### VendorDetail.lua
Detailed vendor view with:
- Full vendor information
- Rating breakdown
- Paginated reviews
- Write/edit review button

### ReviewForm.lua
Review creation/editing form with:
- Interactive star rating
- Title input
- Multi-line content input
- Character count
- Validation

### SearchBar.lua
Quick search overlay with:
- Live search results
- Category icons
- Rating display
- Click to view details

### MinimapButton.lua
LibDBIcon integration with:
- Click handlers (left, right, shift+left)
- Context menu
- Tooltip with stats

## Event Flow

### Adding a Vendor
```
User submits form
  → VendorManager:CreateVendor()
    → Database:SaveVendor()
      → EventHandler:FireCustomEvent(VENDOR_ADDED)
        → UI refreshes
```

### Submitting a Review
```
User submits review
  → RatingSystem:CreateReview()
    → Database:SaveReview()
      → Database:UpdateVendorStats()
        → EventHandler:FireCustomEvent(REVIEW_ADDED)
          → VendorDetail:Refresh()
```

## SavedVariables Structure

```lua
WhelpDB = {
  dbVersion = 1,
  global = {
    vendors = {
      ["uid_123456"] = {
        id = "uid_123456",
        name = "Vendor-Realm",
        category = "profession_package",
        description = "...",
        averageRating = 4.5,
        reviewCount = 10,
        -- ...
      }
    },
    reviews = {
      ["uid_789012"] = {
        id = "uid_789012",
        vendorId = "uid_123456",
        authorName = "Player-Realm",
        rating = 5,
        content = "...",
        timestamp = 1234567890,
        -- ...
      }
    }
  },
  profile = {
    minimap = { hide = false, minimapPos = 225 },
    ui = { scale = 1.0, locked = false },
    filters = { category = "all", sortBy = "rating" }
  }
}

WhelpCharDB = {
  myReviews = { ["uid_789012"] = true },
  favorites = { ["uid_123456"] = true },
  recentlyViewed = { "uid_123456" },
  blockedVendors = {}
}
```

## Error Handling

- All database operations use pcall internally
- User-facing errors use `Whelp:Print()`
- Debug messages use `Whelp:Debug()` (requires debug mode)
- Form validations return error messages to display

## Performance Considerations

- Pagination for large lists (20 vendors/page, 10 reviews/page)
- Lazy UI creation (frames created on first use)
- Efficient filtering using indexed lookups
- Scroll frames for smooth content scrolling
