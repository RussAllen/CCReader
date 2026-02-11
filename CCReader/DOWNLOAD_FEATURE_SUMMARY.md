# Komga to Local Library Download Feature

## Overview
Added the ability to download CBR/CBZ files from Komga server and add them to the local library for offline reading.

## New Files Created

### 1. KomgaDownloadManager.swift
A new manager class that handles downloading comics from Komga and adding them to the local SwiftData library.

**Key Features:**
- Downloads books from Komga server using the API
- Saves files to Application Support directory under "ComicLibrary"
- Creates security-scoped bookmarks for persistent file access
- Automatically adds downloaded comics to SwiftData
- Tracks download progress with status updates
- Handles file naming conflicts automatically
- Supports both CBZ and CBR formats

**Classes:**
- `KomgaDownloadManager`: Main manager for handling downloads
- `DownloadProgress`: Observable object tracking individual download progress
- `DownloadStatus`: Enum representing download states (queued, downloading, saving, etc.)

## Modified Files

### 1. KomgaAPI.swift
**Added:**
- `downloadBook(bookId:)` method that downloads the comic file from Komga
- Returns both the file data and filename
- Parses Content-Disposition header to get the original filename

### 2. KomgaLibraryView.swift
**Major Changes:**
- Added `@Environment(\.modelContext)` to access SwiftData context
- Added `downloadManager` state variable
- Initialized download manager in `.task` modifier
- Added context menus to book items with "Add to Local Library" option
- Added toolbar button in books list to download selected book
- Added visual download status indicators in book rows
- Added floating download notification panel showing active downloads

**New UI Components:**
- `DownloadNotificationView`: Expandable floating panel showing all active downloads
- `DownloadItemView`: Individual download progress item
- Enhanced `BookRowView` with download status display

**New Functions:**
- `downloadBook(_:)`: Triggers download of a book

## How It Works

### User Flow:
1. User browses Komga library (series or recent books)
2. Right-clicks on a book and selects "Add to Local Library"
3. Download begins and shows progress in the book row
4. A floating notification panel appears showing active downloads
5. Once complete, the comic is saved to disk and added to the local library
6. The comic now appears in the "Local Library" tab

### Technical Flow:
1. `KomgaDownloadManager.downloadBook()` is called
2. Creates a `DownloadProgress` tracker
3. Calls `KomgaAPI.downloadBook()` to fetch the file
4. Saves file to `~/Library/Application Support/ComicLibrary/`
5. Creates a security-scoped bookmark
6. Creates a `ComicBook` model and inserts into SwiftData
7. Updates progress status to completed
8. Auto-removes from active downloads after 2 seconds

### File Storage:
- Files are saved to: `~/Library/Application Support/ComicLibrary/`
- Filenames are sanitized to remove invalid characters
- Duplicate names get numbered suffixes: "Comic Name (1).cbz"

## User Interface Elements

### Context Menu (Right-click on book):
- "Add to Local Library" - Downloads the book
- Shows "Downloading..." when in progress

### Toolbar Button:
- Appears when a book is selected
- Icon: arrow.down.circle
- Label: "Add to Local Library"
- Disabled while download is in progress

### Download Indicators:
- In-line progress in book rows
- Status text (Downloading, Saving, Adding to library)
- Checkmark when complete
- Warning icon if failed

### Download Notification Panel:
- Appears in bottom-right corner
- Shows count of active downloads
- Expandable to show detailed list
- Automatically updates as downloads progress
- Shows status for each download

## Error Handling
- Network errors are caught and displayed
- File system errors (permissions, disk space) are handled
- Failed downloads show error message
- Files are cleaned up if database insertion fails
- Download manager tracks failed downloads for 5 seconds before removing

## Future Enhancements
- Batch download multiple books at once
- Download entire series
- Progress bar showing download percentage
- Pause/resume downloads
- Download queue management
- Settings for download location
- Automatic cleanup of old downloads
