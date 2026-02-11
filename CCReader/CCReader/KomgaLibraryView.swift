//
//  KomgaLibraryView.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import SwiftUI

struct KomgaLibraryView: View {
    @StateObject private var api = KomgaAPI()
    @State private var libraries: [KomgaLibrary] = []
    @State private var selectedLibrary: KomgaLibrary?
    @State private var series: [KomgaSeries] = []
    @State private var selectedSeries: KomgaSeries?
    @State private var books: [KomgaBook] = []
    @State private var selectedBook: KomgaBook?
    @State private var isLoading = false
    @State private var showingSettings = false
    @State private var thumbnails: [String: NSImage] = [:] // Cache for thumbnails
    @State private var errorMessage: String?
    @State private var debugInfo: String = ""
    @State private var selectedLetter: String? = nil // Start with no letter filter (All Series)
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .series // New view mode state
    
    enum ViewMode: String, CaseIterable {
        case series = "Browse Series"
        case recentBooks = "Recently Added"
        case readingLists = "Reading Lists"
        
        var icon: String {
            switch self {
            case .series: return "books.vertical"
            case .recentBooks: return "clock"
            case .readingLists: return "list.bullet"
            }
        }
    }
    
    // All available letters based on series
    private var availableLetters: [String] {
        var letters = Set<String>()
        var hasNumbers = false
        var hasSymbols = false
        
        for series in series {
            let title = series.metadata?.titleSort ?? series.metadata?.title ?? series.name
            if let firstChar = title.first {
                let upperChar = String(firstChar).uppercased()
                
                if upperChar.rangeOfCharacter(from: .letters) != nil {
                    letters.insert(upperChar)
                } else if upperChar.rangeOfCharacter(from: .decimalDigits) != nil {
                    hasNumbers = true
                } else {
                    hasSymbols = true
                }
            }
        }
        
        var result: [String] = []
        
        // Add # for numbers
        if hasNumbers {
            result.append("#")
        }
        
        // Add * for symbols
        if hasSymbols {
            result.append("*")
        }
        
        // Add letters A-Z
        result.append(contentsOf: letters.sorted())
        
        return result
    }
    
    // Complete alphabet A-Z plus special characters for the dropdown
    private var allLetterOptions: [String] {
        var result: [String] = []
        
        // Check if we have any numbers or symbols
        var hasNumbers = false
        var hasSymbols = false
        
        for series in series {
            let title = series.metadata?.titleSort ?? series.metadata?.title ?? series.name
            if let firstChar = title.first {
                let upperChar = String(firstChar).uppercased()
                
                if upperChar.rangeOfCharacter(from: .decimalDigits) != nil {
                    hasNumbers = true
                } else if upperChar.rangeOfCharacter(from: .letters) == nil {
                    hasSymbols = true
                }
            }
        }
        
        // Add special characters only if they exist
        if hasNumbers {
            result.append("#")
        }
        if hasSymbols {
            result.append("*")
        }
        
        // Add full A-Z alphabet
        result.append(contentsOf: stride(from: UnicodeScalar("A").value, through: UnicodeScalar("Z").value, by: 1)
            .compactMap { String(UnicodeScalar($0)!) })
        
        return result
    }
    
    // Filtered series based on selected letter and search text
    private var filteredSeries: [KomgaSeries] {
        var result = series
        
        // Filter by letter
        if let letter = selectedLetter {
            result = result.filter { series in
                let title = series.metadata?.titleSort ?? series.metadata?.title ?? series.name
                guard let firstChar = title.first else { return false }
                let upperChar = String(firstChar).uppercased()
                
                if letter == "#" {
                    // Show items starting with numbers
                    return upperChar.rangeOfCharacter(from: .decimalDigits) != nil
                } else if letter == "*" {
                    // Show items starting with symbols
                    return upperChar.rangeOfCharacter(from: .letters) == nil && 
                           upperChar.rangeOfCharacter(from: .decimalDigits) == nil
                } else {
                    // Show items starting with the selected letter
                    return upperChar == letter
                }
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { series in
                let title = (series.metadata?.title ?? series.name).lowercased()
                return title.contains(searchText.lowercased())
            }
        }
        
        return result
    }
    
    @AppStorage("komgaServerURL") private var serverURL = ""
    @AppStorage("komgaUsername") private var username = ""
    @AppStorage("komgaPassword") private var password = "" // Consider using Keychain instead
    @AppStorage("komgaServerName") private var serverName = "Komga Server"
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .sheet(isPresented: $showingSettings) {
            KomgaServerSettingsView(
                serverURL: $serverURL,
                username: $username,
                password: $password,
                serverName: $serverName,
                isPresented: $showingSettings,
                onConnect: {
                    Task {
                        await connectToServer()
                    }
                }
            )
        }
        .task {
            if !serverURL.isEmpty && !username.isEmpty {
                await connectToServer()
            }
        }
        .onChange(of: selectedSeries) { _, newSeries in
            if let series = newSeries {
                Task {
                    await loadBooks(for: series)
                }
            }
        }
        .onChange(of: viewMode) { _, newMode in
            // Clear selections when switching view modes
            selectedSeries = nil
            selectedBook = nil
            selectedLetter = nil
            searchText = ""
            
            Task {
                if newMode == .recentBooks {
                    await loadRecentBooks()
                } else if newMode == .series {
                    await loadSeries()
                }
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            if api.isConnected {
                connectedSidebarView
            } else {
                notConnectedView
            }
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingSettings = true }) {
                    Label("Server Settings", systemImage: "gear")
                }
            }
            
            if api.isConnected {
                ToolbarItem(placement: .status) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                        
                        Text(debugInfo.isEmpty ? "Connected" : debugInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: { Task { await loadData() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onChange(of: selectedLibrary) { _, _ in
            // Reset filters when changing libraries
            selectedLetter = nil
            searchText = ""
            Task {
                await loadSeries()
            }
        }
    }
    
    private var connectedSidebarView: some View {
        List(selection: viewMode == .series ? $selectedSeries : .constant(nil)) {
            // View Mode Picker
            viewModeSection
            
            // Library picker (only for series view)
            if viewMode == .series && libraries.count > 1 {
                librarySection
            }
            
            // Content based on view mode
            switch viewMode {
            case .series:
                // Search bar and alphabet filter
                if !series.isEmpty {
                    searchSection
                    alphabetFilterSection
                }
                seriesSection
                
            case .recentBooks:
                recentBooksSection
                
            case .readingLists:
                readingListsSection
            }
        }
        .navigationTitle(serverName)
    }
    
    private var librarySection: some View {
        Section("Library") {
            Picker("Select Library", selection: $selectedLibrary) {
                Text("Choose a library...").tag(nil as KomgaLibrary?)
                ForEach(libraries) { library in
                    Text(library.name).tag(library as KomgaLibrary?)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var viewModeSection: some View {
        Section {
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var searchSection: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search series...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        selectedLetter = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var alphabetFilterSection: some View {
        Section {
            Picker("Filter by Letter", selection: $selectedLetter) {
                Text("All Series").tag(nil as String?)
                
                ForEach(allLetterOptions, id: \.self) { letter in
                    if letter == "#" {
                        Text("# (Numbers)").tag(letter as String?)
                    } else if letter == "*" {
                        Text("* (Symbols)").tag(letter as String?)
                    } else {
                        // Show count if series exist for this letter
                        let count = series.filter { s in
                            let title = s.metadata?.titleSort ?? s.metadata?.title ?? s.name
                            return title.uppercased().hasPrefix(letter)
                        }.count
                        
                        if count > 0 {
                            Text("\(letter) (\(count))").tag(letter as String?)
                        } else {
                            Text(letter).tag(letter as String?)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
        } header: {
            HStack {
                Text("Filter")
                Spacer()
                if selectedLetter != nil || !searchText.isEmpty {
                    Text("\(filteredSeries.count) of \(series.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var seriesSection: some View {
        Section("Series") {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading series...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if filteredSeries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    if selectedLetter != nil {
                        Text("No series starting with '\(selectedLetter!)'")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Button("Show All") {
                            selectedLetter = nil
                        }
                        .buttonStyle(.bordered)
                    } else if selectedLibrary == nil {
                        Text("Choose a library to view series")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Select a library from the dropdown above")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("No series found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Library: \(selectedLibrary!.name)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(filteredSeries) { item in
                    SeriesRowView(series: item, thumbnail: thumbnails[item.id])
                        .task {
                            await loadThumbnail(for: item)
                        }
                }
            }
        }
    }
    
    private var recentBooksSection: some View {
        Section("Recently Added Books (Last 7 Days)") {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading recent books...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if books.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No books added recently")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("No books have been added to Komga in the last 7 days")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(books) { book in
                    Button(action: {
                        selectedBook = book
                    }) {
                        BookRowView(book: book, thumbnail: thumbnails[book.id], showSeriesName: true)
                            .task {
                                await loadThumbnail(for: book)
                            }
                    }
                    .buttonStyle(.plain)
                    .background(selectedBook?.id == book.id ? Color.accentColor.opacity(0.1) : Color.clear)
                }
            }
        }
    }
    
    private var readingListsSection: some View {
        Section("Reading Lists") {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                Text("Reading Lists")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Text("Reading lists will allow you to create custom collections of books from different series.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    private var notConnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Not Connected")
                .font(.title2)
            
            if let error = api.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Connect to Server") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content Column
    
    private var contentColumn: some View {
        Group {
            if viewMode == .series {
                // Show books for selected series
                if let selectedSeries {
                    booksListView(for: selectedSeries)
                } else {
                    emptyBooksView
                }
            } else {
                // For recent books and reading lists, hide the middle column
                EmptyView()
            }
        }
    }
    
    private func booksListView(for series: KomgaSeries) -> some View {
        List(selection: $selectedBook) {
            booksListContent(for: series)
        }
        .navigationTitle(series.metadata?.title ?? series.name)
        .navigationSplitViewColumnWidth(min: 250, ideal: 350)
    }
    
    @ViewBuilder
    private func booksListContent(for series: KomgaSeries) -> some View {
        if books.isEmpty && !isLoading {
            emptyBooksState(for: series)
        } else if isLoading {
            loadingBooksState
        } else {
            booksList
        }
    }
    
    private var loadingBooksState: some View {
        ProgressView("Loading books...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var booksList: some View {
        ForEach(books) { book in
            BookRowView(book: book, thumbnail: thumbnails[book.id])
                .task {
                    await loadThumbnail(for: book)
                }
        }
    }
    
    private func emptyBooksState(for series: KomgaSeries) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "book")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No books found in this series")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(series.metadata?.title ?? series.name)
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            if let count = series.booksCount, count > 0 {
                Text("Expected \(count) books from server")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Button("Reload Books") {
                Task {
                    await loadBooks(for: series)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyBooksView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Select a series")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Detail Column
    
    private var detailColumn: some View {
        Group {
            if let selectedBook {
                KomgaComicReaderView(book: selectedBook, api: api)
                    .id(selectedBook.id) // Force view to recreate when book changes
            } else {
                emptyReaderView
            }
        }
    }
    
    private var emptyReaderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            
            Text("Select a comic to read")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func connectToServer() async {
        guard !serverURL.isEmpty, !username.isEmpty else {
            showingSettings = true
            return
        }
        
        let server = KomgaServer(
            name: serverName,
            url: serverURL,
            username: username,
            password: password
        )
        
        let connected = await api.connect(to: server)
        if connected {
            await loadData()
        }
    }
    
    private func loadData() async {
        await loadLibraries()
        await loadSeries()
    }
    
    private func loadLibraries() async {
        do {
            libraries = try await api.fetchLibraries()
            debugInfo = "Loaded \(libraries.count) libraries"
            print("✅ Loaded \(libraries.count) libraries: \(libraries.map { $0.name }.joined(separator: ", "))")
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load libraries: \(error.localizedDescription)"
            print("❌ Failed to load libraries: \(error)")
        }
    }
    
    private func loadSeries() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        // Don't load series if no library is selected
        guard selectedLibrary != nil else {
            series = []
            return
        }
        
        do {
            var allSeries: [KomgaSeries] = []
            var currentPage = 0
            var totalPages = 1
            
            // Load all pages
            while currentPage < totalPages {
                print("📚 Loading series page \(currentPage + 1)...")
                
                let response = try await api.fetchSeries(
                    libraryId: selectedLibrary?.id,
                    page: currentPage,
                    size: 500 // Larger page size for efficiency
                )
                
                allSeries.append(contentsOf: response.content)
                
                // Update total pages from response
                if let pages = response.totalPages {
                    totalPages = pages
                }
                
                currentPage += 1
                
                // Safety check to prevent infinite loops
                if currentPage > 100 {
                    print("⚠️ Too many pages, stopping at page 100")
                    break
                }
            }
            
            series = allSeries
            
            let libraryName = selectedLibrary?.name ?? "All Libraries"
            debugInfo = "Loaded \(series.count) series from \(libraryName)"
            print("✅ Loaded \(series.count) series from \(libraryName) (across \(currentPage) page(s))")
            
            if series.isEmpty {
                errorMessage = "No series found in this library"
            }
        } catch {
            errorMessage = "Failed to load series: \(error.localizedDescription)"
            print("❌ Failed to load series: \(error)")
        }
    }
    
    private func loadBooks(for series: KomgaSeries) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            print("📖 Loading books for series: \(series.name) (ID: \(series.id))")
            print("   Series reports \(series.booksCount ?? 0) books")
            
            var allBooks: [KomgaBook] = []
            var currentPage = 0
            var totalPages = 1
            
            // Load all pages
            while currentPage < totalPages {
                let response = try await api.fetchBooks(seriesId: series.id, page: currentPage, size: 500)
                allBooks.append(contentsOf: response.content)
                
                // Update total pages from response
                if let pages = response.totalPages {
                    totalPages = pages
                }
                
                currentPage += 1
                
                // Safety check
                if currentPage > 50 {
                    print("⚠️ Too many book pages, stopping at page 50")
                    break
                }
            }
            
            books = allBooks
            
            print("✅ API returned \(books.count) books from series '\(series.name)' (across \(currentPage) page(s))")
            
            if books.isEmpty {
                errorMessage = "No books found in this series"
                print("⚠️ Series reports \(series.booksCount ?? 0) books but none were loaded")
            } else {
                debugInfo = "Loaded \(books.count) books"
                // Print first few book titles for verification
                let titles = books.prefix(3).map { $0.displayTitle }.joined(separator: ", ")
                print("   First books: \(titles)")
            }
        } catch {
            errorMessage = "Failed to load books: \(error.localizedDescription)"
            print("❌ Failed to load books: \(error)")
        }
    }
    
    private func loadRecentBooks() async {
        isLoading = true
        errorMessage = nil
        books = []
        defer { isLoading = false }
        
        do {
            print("📚 Loading recently added books (last 7 days)...")
            
            // Calculate date 7 days ago
            let calendar = Calendar.current
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            print("   Looking for books added after: \(oneWeekAgo)")
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Fetch recent books across all libraries or selected library
            var allBooks: [KomgaBook] = []
            var currentPage = 0
            let maxPages = 20 // Increased to ensure we get all recent content
            
            while currentPage < maxPages {
                let response = try await api.fetchSeries(
                    libraryId: selectedLibrary?.id,
                    page: currentPage,
                    size: 100
                )
                
                guard !response.content.isEmpty else {
                    print("   No more series to check")
                    break
                }
                
                // For each series, get ALL books (not just first 20)
                for series in response.content {
                    let booksResponse = try await api.fetchBooks(seriesId: series.id, page: 0, size: 1000)
                    
                    // Filter books added in the last week
                    let recentBooks = booksResponse.content.filter { book in
                        guard let created = book.created else { 
                            print("   ⚠️ Book '\(book.displayTitle)' has no creation date")
                            return false 
                        }
                        
                        // Try parsing with different formatters
                        var bookDate: Date?
                        
                        // Try ISO8601 with fractional seconds
                        if bookDate == nil {
                            bookDate = dateFormatter.date(from: created)
                        }
                        
                        // Try ISO8601 without fractional seconds
                        if bookDate == nil {
                            let simpleFormatter = ISO8601DateFormatter()
                            bookDate = simpleFormatter.date(from: created)
                        }
                        
                        // Try with custom format
                        if bookDate == nil {
                            let fallbackFormatter = DateFormatter()
                            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
                            bookDate = fallbackFormatter.date(from: created)
                        }
                        
                        // Another fallback without milliseconds
                        if bookDate == nil {
                            let fallbackFormatter = DateFormatter()
                            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
                            bookDate = fallbackFormatter.date(from: created)
                        }
                        
                        guard let bookDate = bookDate else {
                            print("   ⚠️ Could not parse date for '\(book.displayTitle)': \(created)")
                            return false
                        }
                        
                        let isRecent = bookDate >= oneWeekAgo
                        if isRecent {
                            print("   ✅ Found recent book: '\(book.displayTitle)' from \(bookDate)")
                        }
                        return isRecent
                    }
                    
                    allBooks.append(contentsOf: recentBooks)
                }
                
                currentPage += 1
                
                // Check if this was the last page
                if response.content.count < 100 {
                    break
                }
            }
            
            // Sort all books by created date (newest first)
            books = allBooks.sorted { book1, book2 in
                guard let date1 = book1.created, let date2 = book2.created else {
                    return false
                }
                return date1 > date2
            }.prefix(200).map { $0 } // Increased to 200 to show more books
            
            print("✅ Loaded \(books.count) recent books from last 7 days")
            debugInfo = "Showing \(books.count) recent books"
            
            if books.isEmpty {
                errorMessage = "No books added in the last 7 days"
            }
            
        } catch {
            errorMessage = "Failed to load recent books: \(error.localizedDescription)"
            print("❌ Failed to load recent books: \(error)")
        }
    }
    
    private func loadThumbnail(for series: KomgaSeries) async {
        guard thumbnails[series.id] == nil else { return }
        
        do {
            let thumbnail = try await api.fetchSeriesThumbnail(seriesId: series.id)
            thumbnails[series.id] = thumbnail
        } catch {
            // Silently fail - thumbnail is optional
        }
    }
    
    private func loadThumbnail(for book: KomgaBook) async {
        guard thumbnails[book.id] == nil else { return }
        
        do {
            let thumbnail = try await api.fetchBookThumbnail(bookId: book.id)
            thumbnails[book.id] = thumbnail
        } catch {
            // Silently fail - thumbnail is optional
        }
    }
}

// MARK: - Helper Views

private struct SeriesRowView: View {
    let series: KomgaSeries
    let thumbnail: NSImage?
    
    var body: some View {
        NavigationLink(value: series) {
            HStack(spacing: 12) {
                // Thumbnail
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 60)
                        .overlay {
                            Image(systemName: "book.closed")
                                .foregroundStyle(.secondary)
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.metadata?.title ?? series.name)
                        .font(.headline)
                    
                    HStack {
                        if let booksCount = series.booksCount {
                            Text("\(booksCount) books")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let readCount = series.booksReadCount, readCount > 0 {
                            Text("• \(readCount) read")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct BookRowView: View {
    let book: KomgaBook
    let thumbnail: NSImage?
    var showSeriesName: Bool = false
    
    var body: some View {
        NavigationLink(value: book) {
            HStack(spacing: 12) {
                bookThumbnailView
                bookDetailsView
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private var bookThumbnailView: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 60)
                    .overlay {
                        Image(systemName: "book")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
    
    private var bookDetailsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showSeriesName, let seriesTitle = book.seriesTitle {
                Text(seriesTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(book.displayTitle)
                .font(.headline)
            
            bookMetadataView
        }
    }
    
    @ViewBuilder
    private var bookMetadataView: some View {
        HStack {
            if let number = book.number {
                Text("Issue #\(String(format: "%.0f", number))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if book.pageCount > 0 {
                Text("• \(book.pageCount) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            readStatusView
        }
    }
    
    @ViewBuilder
    private var readStatusView: some View {
        if book.isCompleted {
            Text("• Read")
                .font(.caption)
                .foregroundStyle(.green)
        } else if book.currentPage > 0 {
            Text("• Page \(book.currentPage)")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    KomgaLibraryView()
}
