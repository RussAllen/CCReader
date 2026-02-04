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

    var body: some View {
        NavigationSplitView {
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
                }
                .onDelete(perform: deleteComics)
            }
            .navigationTitle("Comic Reader")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilePicker = true }) {
                        Label("Open Comic", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.zip, UTType(filenameExtension: "cbz")!],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        } detail: {
            if let selectedComicBook {
                ComicReaderView(comicBook: selectedComicBook)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                    Text("Select a comic or open a new one")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Supported formats: CBZ")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Get a security-scoped bookmark
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access file")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Create the comic book entry with the file URL
            let title = url.deletingPathExtension().lastPathComponent
            let newComic = ComicBook(title: title, fileURL: url)
            
            modelContext.insert(newComic)
            
            // Select the newly added comic
            selectedComicBook = newComic
            
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }

    private func deleteComics(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(comicBooks[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ComicBook.self, inMemory: true)
}
