# Komga Integration for CCReader

This comic reader app now supports both local comic files (CBZ/CBR) and remote comics from a Komga server.

## Features

### Komga Support
- **Browse Libraries**: Access all your Komga libraries
- **View Series**: See all series with thumbnails and metadata
- **Read Comics**: Stream comics directly from your server
- **Sync Progress**: Automatically sync reading progress with Komga
- **Thumbnails**: Display cover art for series and books

### What is Komga?

Komga is a free and open-source comics/manga server. It allows you to:
- Host your comic collection on a server
- Access your comics from anywhere
- Track reading progress
- Organize comics by series and libraries
- Support for CBZ, CBR, PDF, and more

Learn more at: https://komga.org

## Setup

### 1. Install and Configure Komga

First, you need a running Komga server:

1. Install Komga on your server (see https://komga.org/guides/install.html)
2. Add your comic libraries to Komga
3. Create a user account (or use the default admin account)

### 2. Connect CCReader to Komga

1. Launch CCReader
2. Click on the **Komga** tab
3. Click **Connect to Server** (or the gear icon)
4. Enter your server details:
   - **Server Name**: A friendly name (e.g., "Home Server")
   - **Server URL**: Complete URL including protocol (e.g., `http://192.168.1.100:8080` or `https://komga.example.com`)
   - **Username**: Your Komga username
   - **Password**: Your Komga password
5. Click **Connect**

### 3. Browse and Read

Once connected:
- Browse your libraries and series in the sidebar
- Select a series to see all books
- Click a book to start reading
- Your reading progress is automatically saved to the server

## Using the Reader

### Navigation
- **Click** on the page to show/hide controls
- **Double-click** to reset zoom
- **Left/Right arrow keys** to navigate pages
- **Pinch gesture** to zoom (trackpad)
- **Drag** to pan when zoomed

### Progress Tracking
- Your current page is automatically synced with Komga
- When you finish a book, it's marked as read
- Return to reading where you left off from any device

## Security Notes

⚠️ **Important**: 
- Currently, passwords are stored in UserDefaults (not secure for production)
- For better security, consider using Keychain to store credentials
- Always use HTTPS when accessing Komga over the internet
- Consider using a VPN when accessing your server remotely

## Troubleshooting

### Cannot connect to server
- Verify the server URL is correct (include `http://` or `https://`)
- Check that Komga is running and accessible
- Verify username and password are correct
- Check firewall settings on your server

### Pages won't load
- Check your internet connection
- Verify the server is still running
- Try refreshing the library

### Slow performance
- Large images may take time to download
- Consider optimizing your comic files
- Check your network speed

## Architecture

The Komga integration consists of:

- **KomgaAPI**: REST API client for communicating with Komga
- **KomgaModels**: Data models matching Komga's API
- **KomgaBookReader**: Handles downloading and caching pages
- **KomgaLibraryView**: Main browsing interface
- **KomgaComicReaderView**: Reading interface for Komga books
- **KomgaServerSettingsView**: Server configuration UI

## API Reference

The app uses Komga's REST API v1. Key endpoints:

- `GET /api/v1/libraries` - List all libraries
- `GET /api/v1/series` - List series
- `GET /api/v1/series/{id}/books` - List books in a series
- `GET /api/v1/books/{id}/pages/{page}` - Get page image
- `PATCH /api/v1/books/{id}/read-progress` - Update reading progress

For full API documentation, see: https://komga.org/api/

## Future Enhancements

Potential improvements:
- [ ] Offline mode with local caching
- [ ] Download entire books for offline reading
- [ ] Collections support
- [ ] Advanced filtering and search
- [ ] Reading lists
- [ ] Multiple server support
- [ ] Secure credential storage with Keychain

## Contributing

To extend the Komga integration:

1. Update `KomgaModels.swift` for new API entities
2. Add endpoints to `KomgaAPI.swift`
3. Update UI components as needed
4. Test with your Komga server

## License

This integration uses Komga's public REST API and follows their API usage guidelines.
