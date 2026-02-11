# Komga Reading Lists Integration

## Overview
Integrated full reading list support from Komga server, allowing users to browse and read curated collections of comics.

## New Features

### 1. Reading Lists Models (KomgaModels.swift)
Added `KomgaReadingList` struct with:
- `id`: Unique identifier
- `name`: Reading list name
- `summary`: Optional description
- `ordered`: Whether books are in specific order
- `bookIds`: Array of book IDs in the list
- `createdDate` and `lastModifiedDate`: Timestamps
- `bookCount`: Computed property for number of books

### 2. Reading Lists API Methods (KomgaAPI.swift)
Added four new API endpoints:
- `fetchReadingLists(libraryId:page:size:)` - Get all reading lists
- `fetchReadingListById(_:)` - Get a specific reading list
- `fetchBooksInReadingList(readingListId:page:size:)` - Get books in a reading list
- `fetchReadingListThumbnail(readingListId:)` - Get reading list cover image

### 3. Enhanced UI (KomgaLibraryView.swift)
**State Management:**
- Added `readingLists: [KomgaReadingList]` array
- Added `selectedReadingList: KomgaReadingList?` selection state

**View Components:**
- Replaced "Coming Soon" placeholder with functional reading lists section
- Added `ReadingListRowView` - Displays reading list with thumbnail, name, book count, and summary
- Added `readingListBooksView` - Shows books in selected reading list
- Added `emptyReadingListView` - Placeholder when no reading list selected
- Added `emptyReadingListBooksState` - Placeholder when reading list has no books

**Navigation:**
- Reading lists appear in sidebar when "Reading Lists" mode is selected
- Clicking a reading list loads its books in the middle column
- Books can be selected and read in the detail column
- Download button available for books in reading lists

**Loading Functions:**
- `loadReadingLists()` - Fetches all reading lists with pagination
- `loadBooksInReadingList(_:)` - Fetches books for specific reading list
- `loadThumbnail(for:)` - Loads thumbnail for reading list

## User Interface

### Reading Lists Sidebar
- Shows all reading lists from Komga server
- Each item displays:
  - Thumbnail (or list icon if unavailable)
  - Reading list name
  - Book count
  - "Ordered" badge if applicable
  - Summary (truncated to 2 lines)
- Selected reading list is highlighted
- Empty state shows friendly message if no lists exist

### Reading List Books View (Middle Column)
- Shows all books in the selected reading list
- Preserves reading list order (if ordered)
- Same book row format as series view:
  - Thumbnail
  - Title
  - Issue number and page count
  - Read status
  - Download status
- Context menu to download books
- Toolbar download button for selected book

### Download Integration
- Full download support for books in reading lists
- Same functionality as series books:
  - Right-click context menu
  - Toolbar button
  - Progress indicators
  - Add to local library

## API Endpoints Used

Based on Komga API v1:
- `GET /api/v1/readlists` - List all reading lists
- `GET /api/v1/readlists/{id}` - Get reading list details
- `GET /api/v1/readlists/{id}/books` - Get books in reading list
- `GET /api/v1/readlists/{id}/thumbnail` - Get reading list thumbnail

All endpoints support:
- Pagination (page, size parameters)
- Sorting (sort parameter)
- Library filtering (library_id parameter)

## How It Works

### User Flow:
1. User selects "Reading Lists" from view mode picker
2. App fetches all reading lists from Komga
3. Reading lists appear in sidebar with thumbnails
4. User clicks a reading list
5. App fetches all books in that reading list
6. Books appear in middle column
7. User can:
   - Click book to read in reader view
   - Right-click to download to local library
   - Use toolbar button to download

### Technical Flow:
1. `viewMode` changes to `.readingLists`
2. `onChange(viewMode)` triggers `loadReadingLists()`
3. API fetches reading lists with pagination
4. Thumbnails loaded asynchronously for each list
5. User selects reading list → `selectedReadingList` updates
6. `onChange(selectedReadingList)` triggers `loadBooksInReadingList()`
7. Books loaded and displayed with thumbnails
8. Books can be read or downloaded

## Data Structure

### Reading List Object:
```swift
{
  "id": "ABC123",
  "name": "Best of Marvel 2024",
  "summary": "Top Marvel comics from 2024",
  "ordered": true,
  "bookIds": ["book1", "book2", "book3"],
  "createdDate": "2024-01-15T10:30:00Z",
  "lastModifiedDate": "2024-01-20T14:45:00Z",
  "filtered": false
}
```

## Benefits

1. **Curated Collections**: Read comics in curated order
2. **Cross-Series Reading**: Reading lists can contain books from multiple series
3. **Organized Reading**: Follow specific reading orders (e.g., event storylines)
4. **Same Features**: Full download support just like series books
5. **Visual Browsing**: Thumbnails make finding lists easy
6. **Efficient Loading**: Pagination prevents overwhelming the UI

## Future Enhancements

Potential additions:
- Create/edit reading lists from the app
- Add/remove books from reading lists
- Reorder books in reading lists
- Filter reading lists by library
- Search within reading lists
- Mark entire reading list as read/unread
- Download entire reading list at once
- Reading list progress tracking
- Sort reading lists by name, date, book count
