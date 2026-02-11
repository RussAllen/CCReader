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
    
    @AppStorage("komgaServerURL") private var serverURL = ""
    @AppStorage("komgaUsername") private var username = ""
    @AppStorage("komgaPassword") private var password = "" // Consider using Keychain instead
    @AppStorage("komgaServerName") private var serverName = "Komga Server"
    
    var body: some View {
        NavigationSplitView {
            // Library and Series List
            VStack(spacing: 0) {
                if api.isConnected {
                    List(selection: $selectedSeries) {
                        // Libraries Section
                        if libraries.count > 1 {
                            Section("Libraries") {
                                Picker("Library", selection: $selectedLibrary) {
                                    Text("All Libraries").tag(nil as KomgaLibrary?)
                                    ForEach(libraries) { library in
                                        Text(library.name).tag(library as KomgaLibrary?)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                        
                        // Series Section
                        Section("Series") {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(series) { item in
                                    NavigationLink(value: item) {
                                        HStack(spacing: 12) {
                                            // Thumbnail
                                            if let thumbnail = thumbnails[item.id] {
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
                                                Text(item.metadata?.title ?? item.name)
                                                    .font(.headline)
                                                
                                                HStack {
                                                    if let booksCount = item.booksCount {
                                                        Text("\(booksCount) books")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    
                                                    if let readCount = item.booksReadCount, readCount > 0 {
                                                        Text("• \(readCount) read")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .task {
                                        await loadThumbnail(for: item)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle(serverName)
                } else {
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
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingSettings = true }) {
                        Label("Server Settings", systemImage: "gear")
                    }
                }
                
                if api.isConnected {
                    ToolbarItem(placement: .automatic) {
                        Button(action: { Task { await loadData() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .onChange(of: selectedLibrary) { _, _ in
                Task {
                    await loadSeries()
                }
            }
        } content: {
            // Books List
            if let selectedSeries {
                List(selection: $selectedBook) {
                    ForEach(books) { book in
                        NavigationLink(value: book) {
                            HStack(spacing: 12) {
                                // Book Thumbnail
                                if let thumbnail = thumbnails[book.id] {
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
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.displayTitle)
                                        .font(.headline)
                                    
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
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .task {
                            await loadThumbnail(for: book)
                        }
                    }
                }
                .navigationTitle(selectedSeries.metadata?.title ?? selectedSeries.name)
                .navigationSplitViewColumnWidth(min: 250, ideal: 350)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("Select a series")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        } detail: {
            // Comic Reader
            if let selectedBook {
                KomgaComicReaderView(book: selectedBook, api: api)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 80))
                        .foregroundStyle(.orange)
                    
                    Text("Select a comic to read")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
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
        } catch {
            print("Failed to load libraries: \(error)")
        }
    }
    
    private func loadSeries() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await api.fetchSeries(
                libraryId: selectedLibrary?.id,
                page: 0,
                size: 100
            )
            series = response.content
        } catch {
            print("Failed to load series: \(error)")
        }
    }
    
    private func loadBooks(for series: KomgaSeries) async {
        do {
            let response = try await api.fetchBooks(seriesId: series.id, page: 0, size: 100)
            books = response.content
        } catch {
            print("Failed to load books: \(error)")
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

#Preview {
    KomgaLibraryView()
}
