# Komga Reading Lists - Quick Reference

## What Changed

### Files Modified:
1. **KomgaModels.swift** - Added `KomgaReadingList` model
2. **KomgaAPI.swift** - Added 4 new reading list API methods
3. **KomgaLibraryView.swift** - Complete reading lists UI implementation

## How to Use

### Viewing Reading Lists:
1. Connect to your Komga server
2. In the toolbar, select "Reading Lists" from the view mode picker
3. Reading lists from your server appear in the left sidebar
4. Click any reading list to see its books

### Reading Books from Lists:
1. Select a reading list
2. Books appear in the middle column (in order if the list is ordered)
3. Click a book to open it in the reader
4. Navigate through pages as normal

### Downloading from Reading Lists:
1. Select a book in a reading list
2. Either:
   - Right-click → "Add to Local Library"
   - Or click the download button in the toolbar
3. Book downloads and appears in your Local Library tab

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ Toolbar: [Local Library] [Komga Server]                             │
├──────────────┬──────────────────────┬──────────────────────────────┤
│ SIDEBAR      │ BOOKS COLUMN         │ READER COLUMN                │
│              │                      │                              │
│ View:        │                      │                              │
│ ▼ Reading    │ Reading List Name    │                              │
│   Lists      │ ─────────────────    │                              │
│              │                      │    [Comic Reader View]       │
│ Reading      │ 📖 Book Title #1     │                              │
│ Lists:       │    Issue #1          │    or                        │
│              │    32 pages          │                              │
│ ☑️ Marvel     │                      │    "Select a comic"          │
│   Events     │ 📖 Book Title #2     │                              │
│   42 books   │    Issue #2          │                              │
│              │    28 pages          │                              │
│ □ DC Crisis  │                      │                              │
│   15 books   │ 📖 Book Title #3     │                              │
│              │    Issue #3          │                              │
│ □ Best of    │    36 pages • Read   │                              │
│   2024       │                      │                              │
│   28 books   │        ⋮             │                              │
│              │                      │                              │
└──────────────┴──────────────────────┴──────────────────────────────┘
```

## API Endpoints

Your Komga server exposes these endpoints (automatically used by the app):

- **List all reading lists:**
  `GET https://your-server/api/v1/readlists`

- **Get specific reading list:**
  `GET https://your-server/api/v1/readlists/{id}`

- **Get books in reading list:**
  `GET https://your-server/api/v1/readlists/{id}/books`

- **Get reading list thumbnail:**
  `GET https://your-server/api/v1/readlists/{id}/thumbnail`

## Reading List Features

### Displayed Information:
- ✅ Reading list name
- ✅ Number of books
- ✅ Summary/description
- ✅ Ordered badge (if books are in specific order)
- ✅ Thumbnail/cover image
- ✅ Download support for all books

### Filtering & Organization:
- Reading lists can be filtered by library
- Books within lists maintain their order
- Empty states provide helpful guidance
- Loading states show progress

## Example Use Cases

### 1. Story Arcs:
- "Infinity War" reading list with issues from multiple series
- Read in the correct order across different titles

### 2. Character Spotlights:
- "Spider-Man's Greatest Hits" with key issues
- Jump between series while following one character

### 3. Curated Collections:
- "Best of 2024" with editor's picks
- "New Reader Starter Pack" for beginners

### 4. Event Crossovers:
- "Secret Wars" with all tie-ins
- Follow complex crossover events in order

## Technical Details

### Performance:
- Pagination support (loads 500 items per page)
- Thumbnail caching prevents redundant downloads
- Asynchronous loading doesn't block UI
- Efficient memory management

### Error Handling:
- Network errors are caught and displayed
- Empty reading lists show helpful message
- Failed thumbnail loads use default icon
- Retry options available

### Data Synchronization:
- Reading lists refresh when changing libraries
- Book status syncs with Komga server
- Download status tracked independently
- Read progress maintained

## Tips

1. **Creating Reading Lists**: Use Komga web interface to create/edit lists
2. **Order Matters**: Enable "ordered" for sequential reading
3. **Cross-Series**: Reading lists are perfect for crossover events
4. **Offline Reading**: Download books from lists to read offline
5. **Progress Tracking**: Book read status is maintained within lists

## Troubleshooting

**No reading lists showing?**
- Check if lists exist on your Komga server
- Verify library is selected (if using library filter)
- Try refreshing with the toolbar button

**Books not loading in list?**
- Check your network connection
- Verify the reading list has books assigned
- Try reloading the reading list

**Thumbnails not appearing?**
- They load asynchronously - give it a moment
- Default icons show if thumbnail fails

**Can't download books?**
- Ensure you're connected to Komga
- Check disk space for downloads
- Verify network connectivity
