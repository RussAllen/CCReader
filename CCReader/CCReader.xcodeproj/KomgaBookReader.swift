//
//  KomgaBookReader.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import Foundation
import AppKit
import Combine

/// Reads comic book pages from a Komga server
@MainActor
class KomgaBookReader: ObservableObject {
    @Published var pages: [NSImage] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var loadingProgress: Double = 0
    
    private let api: KomgaAPI
    private var book: KomgaBook?
    private var currentTask: Task<Void, Never>?
    
    init(api: KomgaAPI) {
        self.api = api
    }
    
    /// Load a book from Komga
    func loadBook(_ book: KomgaBook) {
        // Cancel any existing loading task
        currentTask?.cancel()
        
        self.book = book
        
        currentTask = Task {
            await performLoad(book)
        }
    }
    
    private func performLoad(_ book: KomgaBook) async {
        isLoading = true
        error = nil
        pages = []
        loadingProgress = 0
        
        do {
            // Fetch page information
            let pageInfos = try await api.fetchPages(bookId: book.id)
            
            let totalPages = pageInfos.count
            guard totalPages > 0 else {
                error = "No pages found in this book"
                isLoading = false
                return
            }
            
            // Create placeholder array
            var loadedPages: [NSImage?] = Array(repeating: nil, count: totalPages)
            
            // Load pages concurrently, but limit concurrency
            await withTaskGroup(of: (Int, NSImage?)?.self) { group in
                for (index, _) in pageInfos.enumerated() {
                    // Limit concurrent downloads to 5 at a time
                    if index >= 5 {
                        // Wait for one to complete before adding another
                        if let result = await group.next() {
                            if let (pageIndex, image) = result {
                                loadedPages[pageIndex] = image
                                loadingProgress = Double(loadedPages.compactMap { $0 }.count) / Double(totalPages)
                            }
                        }
                    }
                    
                    group.addTask {
                        do {
                            let image = try await self.api.fetchPageImage(bookId: book.id, pageNumber: index + 1)
                            return (index, image)
                        } catch {
                            print("Failed to load page \(index + 1): \(error)")
                            return nil
                        }
                    }
                }
                
                // Collect remaining results
                for await result in group {
                    if let (pageIndex, image) = result {
                        loadedPages[pageIndex] = image
                        loadingProgress = Double(loadedPages.compactMap { $0 }.count) / Double(totalPages)
                    }
                }
            }
            
            // Filter out any failed pages and update
            let finalPages = loadedPages.compactMap { $0 }
            
            if finalPages.isEmpty {
                error = "Failed to load any pages"
            } else {
                pages = finalPages
                if finalPages.count < totalPages {
                    error = "Some pages failed to load (\(finalPages.count) of \(totalPages))"
                }
            }
            
        } catch {
            self.error = "Failed to load book: \(error.localizedDescription)"
        }
        
        isLoading = false
        loadingProgress = 0
    }
    
    /// Update read progress on the server
    func updateProgress(currentPage: Int, completed: Bool = false) async {
        guard let book = book else { return }
        
        do {
            try await api.updateReadProgress(bookId: book.id, page: currentPage, completed: completed)
        } catch {
            print("Failed to update read progress: \(error)")
        }
    }
    
    /// Cancel loading
    func cancel() {
        currentTask?.cancel()
        isLoading = false
        loadingProgress = 0
    }
}
