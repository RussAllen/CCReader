//
//  ContentView.swift
//  CCReader
//
//  Created by Russell Allen on 2/4/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ComicBook.lastOpenedDate, order: .reverse) private var comicBooks: [ComicBook]
    @State private var selectedComicBook: ComicBook?
    @State private var showingFilePicker = false
    @State private var showingDeleteAlert = false
    @State private var comicsToDelete: IndexSet?
    @State private var comicToDelete: ComicBook?
    @State private var selectedSource: LibrarySource = .local
    
    enum LibrarySource: String, Hashable {
        case local = "Local Books"
        case komga = "Komga Books"
        
        var icon: String {
            switch self {
            case .local: return "folder.fill"
            case .komga: return "network"
            }
        }
    }

    var body: some View {
        Group {
            switch selectedSource {
            case .local:
                // Local books uses the three-column layout
                localNavigationView
            case .komga:
                // Komga has its own navigation structure
                komgaNavigationView
            }
        }
    }
    
    private var localNavigationView: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            contentListView
        } detail: {
            localDetailView
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private var komgaNavigationView: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            KomgaLibraryView()
                .id("komga-library") // Stable identity to preserve state
        }
    }
    
    private var sidebarView: some View {
        List(selection: $selectedSource) {
            Section("Collections") {
                NavigationLink(value: LibrarySource.local) {
                    Label("Local Books", systemImage: "folder.fill")
                }
                
                NavigationLink(value: LibrarySource.komga) {
                    Label("Komga Books", systemImage: "network")
                }
            }
        }
        .navigationTitle("Comic Reader")
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    }
    
    @ViewBuilder
    private var contentListView: some View {
        localBooksListView
    }
    
    private var localDetailView: some View {
        Group {
            if let selectedComicBook {
                ComicReaderView(comicBook: selectedComicBook)
                    .id(selectedComicBook.persistentModelID)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: {
                                self.selectedComicBook = nil
                            }) {
                                Label("Back to Library", systemImage: "chevron.left")
                            }
                        }
                    }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 80))
                        .foregroundStyle(.orange)
                    Text("Select a comic to start reading")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Supported formats: CBZ, CBR")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    private var localBooksListView: some View {
        List(selection: $selectedComicBook) {
            ForEach(comicBooks) { comic in
                NavigationLink(value: comic) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comic.title)
                            .font(.headline)
                        HStack {
                            if comic.totalPages > 0 {
                                Text("Page \(comic.currentPage + 1) of \(comic.totalPages)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(comic.lastOpenedDate, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button("Remove from Library Only", role: .destructive) {
                        comicToDelete = comic
                        showingDeleteAlert = true
                        comicsToDelete = nil
                    }
                    Button("Delete File and Remove from Library", role: .destructive) {
                        comicToDelete = comic
                        showingDeleteAlert = true
                        comicsToDelete = IndexSet(integer: -1)
                    }
                }
            }
            .onDelete { offsets in
                comicsToDelete = offsets
                showingDeleteAlert = true
                comicToDelete = nil
            }
        }
        .navigationTitle("Local Books")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingFilePicker = true }) {
                    Label("Open Comic", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                .zip,
                UTType(filenameExtension: "cbz")!,
                UTType(filenameExtension: "cbr")!
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Remove Comic", isPresented: $showingDeleteAlert) {
            if let comic = comicToDelete {
                if comicsToDelete?.first == -1 {
                    Button("Delete File and Remove from Library", role: .destructive) {
                        deleteComic(comic, deleteFile: true)
                    }
                } else {
                    Button("Remove from Library Only", role: .destructive) {
                        deleteComic(comic, deleteFile: false)
                    }
                }
                Button("Cancel", role: .cancel) {
                    comicToDelete = nil
                    comicsToDelete = nil
                }
            } else if let offsets = comicsToDelete {
                Button("Remove from Library Only", role: .destructive) {
                    deleteComics(offsets: offsets, deleteFile: false)
                }
                Button("Delete File and Remove from Library", role: .destructive) {
                    deleteComics(offsets: offsets, deleteFile: true)
                }
                Button("Cancel", role: .cancel) {
                    comicsToDelete = nil
                }
            }
        } message: {
            if comicToDelete != nil {
                if comicsToDelete?.first == -1 {
                    Text("This will permanently delete '\(comicToDelete!.title)' from your device.")
                } else {
                    Text("This will remove '\(comicToDelete!.title)' from your library but keep the file on your device.")
                }
            } else {
                Text("Do you want to remove this comic from your library only, or also delete the file from your device?")
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Try to access security-scoped resource (may not be needed for all files)
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Create a bookmark for persistent access
            var bookmarkData: Data?
            do {
                bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                print("Successfully created bookmark for: \(url.lastPathComponent)")
            } catch {
                print("Failed to create bookmark: \(error.localizedDescription)")
                // Continue anyway - the app might still work without bookmarks
            }
            
            // Verify the file exists and is accessible
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("File does not exist at path: \(url.path)")
                return
            }
            
            // Create the comic book entry with the file URL and bookmark
            let title = url.deletingPathExtension().lastPathComponent
            let newComic = ComicBook(title: title, fileURL: url, bookmarkData: bookmarkData)
            
            modelContext.insert(newComic)
            
            // Select the newly added comic
            selectedComicBook = newComic
            
        case .failure(let error):
            print("File selection failed: \(error.localizedDescription)")
        }
    }

    private func deleteComics(offsets: IndexSet, deleteFile: Bool) {
        withAnimation {
            for index in offsets {
                let comic = comicBooks[index]
                
                // Clear selection if this comic is currently selected
                if selectedComicBook?.persistentModelID == comic.persistentModelID {
                    selectedComicBook = nil
                }
                
                // Optionally delete the physical file
                if deleteFile {
                    let fileURL = comic.fileURL
                    if fileURL.startAccessingSecurityScopedResource() {
                        defer {
                            fileURL.stopAccessingSecurityScopedResource()
                        }
                        
                        do {
                            try FileManager.default.removeItem(at: fileURL)
                            print("Deleted file: \(fileURL.path)")
                        } catch {
                            print("Failed to delete file: \(error.localizedDescription)")
                            // Continue with database deletion even if file deletion fails
                        }
                    }
                }
                
                // Delete from SwiftData
                modelContext.delete(comic)
            }
        }
        
        // Clear the deletion state
        comicsToDelete = nil
    }
    
    private func deleteComic(_ comic: ComicBook, deleteFile: Bool) {
        withAnimation {
            // Clear selection if this comic is currently selected
            if selectedComicBook?.persistentModelID == comic.persistentModelID {
                selectedComicBook = nil
            }
            
            // Optionally delete the physical file
            if deleteFile {
                let fileURL = comic.fileURL
                if fileURL.startAccessingSecurityScopedResource() {
                    defer {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                    
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        print("Deleted file: \(fileURL.path)")
                    } catch {
                        print("Failed to delete file: \(error.localizedDescription)")
                        // Continue with database deletion even if file deletion fails
                    }
                }
            }
            
            // Delete from SwiftData
            modelContext.delete(comic)
        }
        
        // Clear the deletion state
        comicToDelete = nil
        comicsToDelete = nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ComicBook.self, inMemory: true)
}
