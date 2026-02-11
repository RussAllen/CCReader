# Reading Lists Alphabetic/Numeric Filter Enhancement

## Overview
Added alphabetic and numeric filtering to the Reading Lists view, matching the functionality already available in the Series view.

## Changes Made

### 1. New Computed Properties (KomgaLibraryView.swift)

#### `filteredReadingLists`
Filters reading lists based on:
- **Letter filter**: Shows only reading lists starting with selected letter
- **Search text**: Searches in both reading list name and summary
- Returns filtered array of `KomgaReadingList`

#### `availableReadingListLetters`
Returns an array of letters that have reading lists:
- `#` - For reading lists starting with numbers
- `*` - For reading lists starting with symbols
- `A-Z` - Only letters that have reading lists

#### `allReadingListLetterOptions`
Returns complete alphabet for the dropdown picker:
- `#` - If any reading lists start with numbers
- `*` - If any reading lists start with symbols  
- `A-Z` - Full alphabet

### 2. New UI Components

#### `readingListSearchSection`
Search bar for filtering reading lists by name or summary:
- Magnifying glass icon
- TextField with placeholder "Search reading lists..."
- Clear button (X) that appears when text is entered
- Clears both search text and letter filter when X is tapped

#### `readingListAlphabetFilterSection`
Dropdown picker for filtering by letter:
- "All Reading Lists" option to show all
- Special characters:
  - "# (Numbers)" - For reading lists starting with digits
  - "* (Symbols)" - For reading lists starting with non-alphanumeric characters
- Letters A-Z with counts in parentheses (e.g., "A (5)")
- Header showing filtered count: "X of Y" when filters are active

### 3. Updated Views

#### Sidebar Content
Modified to show search and filter controls for reading lists:
```swift
case .readingLists:
    // Search bar and alphabet filter for reading lists
    if !readingLists.isEmpty {
        readingListSearchSection
        readingListAlphabetFilterSection
    }
    readingListsSection
```

#### Reading Lists Section
Updated to use filtered list and show appropriate empty states:
- Uses `filteredReadingLists` instead of `readingLists`
- Empty state when filtered by letter: "No reading lists starting with 'X'"
- Empty state when searching: "No reading lists matching 'search term'"
- Empty state when no lists exist: Original "No Reading Lists" message
- "Show All" button to clear letter filter
- "Clear Search" button to clear search text

## User Experience

### Filtering by Letter:
1. Select "Reading Lists" view mode
2. Reading lists load and display
3. Search bar and filter dropdown appear above the list
4. Select a letter from the "Filter by Letter" dropdown
5. List updates to show only reading lists starting with that letter
6. Count updates in the header: "5 of 23"
7. If no matches, shows "No reading lists starting with 'X'" with "Show All" button

### Searching:
1. Type in the search bar
2. List filters in real-time
3. Searches both name and summary fields
4. Works in combination with letter filter
5. Clear button (X) appears when typing
6. Tapping X clears search and letter filter

### Combined Filtering:
- Can use letter filter AND search together
- Example: Filter by "M" then search for "marvel"
- Shows only Marvel reading lists starting with M
- Count reflects both filters

## Features

✅ **Alphabetic filtering** - A-Z letters
✅ **Numeric filtering** - # for numbers  
✅ **Symbol filtering** - * for symbols
✅ **Search filtering** - Text search in name and summary
✅ **Combined filters** - Use letter and search together
✅ **Count display** - Shows "X of Y" when filtered
✅ **Letter counts** - Shows count per letter in dropdown
✅ **Empty states** - Context-aware messages
✅ **Quick clear** - Buttons to clear filters
✅ **Real-time updates** - Filters apply immediately

## Benefits

1. **Large Collections**: Easy to navigate many reading lists
2. **Quick Access**: Jump to reading lists by first letter
3. **Search Flexibility**: Find lists by name or description
4. **Consistent UX**: Matches existing Series view behavior
5. **Visual Feedback**: Clear count indicators
6. **Context-Aware**: Smart empty states guide users

## Implementation Notes

### Filter Logic:
- **Letter Filter**: Checks first character of reading list name
- **Number Filter** (#): Matches any digit 0-9
- **Symbol Filter** (*): Matches non-letter, non-digit characters
- **Search Filter**: Case-insensitive search in name and summary
- **Combination**: Filters are AND-ed together

### Performance:
- Filters use computed properties for efficiency
- Updates happen on the main thread
- No network calls when filtering (client-side)
- Minimal memory overhead

### UI Polish:
- Matches Series view styling exactly
- Consistent spacing and alignment
- Same empty state design patterns
- Familiar interaction patterns

## Example Usage Scenarios

### Scenario 1: Find Marvel Lists
1. Select Reading Lists view
2. Type "marvel" in search
3. See all Marvel-related reading lists
4. Filter further by letter if needed

### Scenario 2: Browse by Letter
1. Select Reading Lists view
2. Choose "M" from dropdown
3. See all lists starting with M (e.g., "Marvel Events", "Modern Classics")
4. Counts show in dropdown: "M (8)"

### Scenario 3: Find Numbered Lists
1. Select Reading Lists view  
2. Choose "# (Numbers)" from dropdown
3. See lists like "100 Best Comics", "2024 Favorites"

### Scenario 4: Quick Navigation
1. Have 100+ reading lists
2. Know list starts with "S"
3. Click dropdown, select "S"
4. Instantly see only S lists (maybe 8-10 items)
5. Much faster than scrolling through 100+

## Comparison with Series View

Both views now have identical filtering capabilities:

| Feature | Series View | Reading Lists View |
|---------|------------|-------------------|
| Search bar | ✅ | ✅ |
| Letter filter | ✅ | ✅ |
| Number filter (#) | ✅ | ✅ |
| Symbol filter (*) | ✅ | ✅ |
| Count display | ✅ | ✅ |
| Empty states | ✅ | ✅ |
| Clear buttons | ✅ | ✅ |

The only difference is the search scope:
- **Series**: Searches only title
- **Reading Lists**: Searches name AND summary (more comprehensive)
