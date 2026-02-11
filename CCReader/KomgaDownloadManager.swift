//
//  KomgaDownloadManager.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import Foundation
import SwiftData
import Combine

/// Manages downloading comics from Komga server to local library
@MainActor
class KomgaDownloadManager: ObservableObject {
    @Published var activeDownloads: [String: DownloadProgress] = [:]
    @Published var errorMessage: String?
    
    private let api: KomgaAPI
    private let modelContext: ModelContext
    
    init(api: KomgaAPI, modelContext: ModelContext) {
        self.api = api
        self.modelContext = modelContext
    }
    
    /// Download a book from Komga and add it to the local library
    func downloadBook(_ book: KomgaBook) async throws {
        let bookId = book.id
        
        // Create download progress tracker
        let progress = DownloadProgress(bookId: bookId, bookTitle: book.displayTitle)
        activeDownloads[bookId] = progress
        
        do {
            // Update progress
            progress.status = .downloading
            
            // Download the file
            let (data, filename) = try await api.downloadBook(bookId: bookId)
            
            // Update progress
            progress.status = .saving
            
            // Determine file extension
            let fileExtension: String
            if filename.lowercased().hasSuffix(".cbz") {
                fileExtension = "cbz"
            } else if filename.lowercased().hasSuffix(".cbr") {
                fileExtension = "cbr"
            } else {
                // Try to determine from media type if available
                if let mediaType = book.media?.mediaType?.lowercased() {
                    if mediaType.contains("zip") {
                        fileExtension = "cbz"
                    } else if mediaType.contains("rar") {
                        fileExtension = "cbr"
                    } else {
                        fileExtension = "cbz" // Default to cbz
                    }
                } else {
                    fileExtension = "cbz" // Default to cbz
                }
            }
            
            // Create a safe filename
            let safeTitle = book.displayTitle
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "?", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "|", with: "")
            
            // Save to application support directory
            let fileURL = try saveToLocalLibrary(data: data, title: safeTitle, fileExtension: fileExtension)
            
            // Update progress
            progress.status = .addingToLibrary
            
            // Create a security-scoped bookmark
            let bookmarkData: Data?
            do {
                bookmarkData = try fileURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                print("Warning: Failed to create bookmark: \(error)")
                bookmarkData = nil
            }
            
            // Add to local library using SwiftData
            let comicBook = ComicBook(
                title: book.displayTitle,
                fileURL: fileURL,
                bookmarkData: bookmarkData,
                currentPage: 0,
                totalPages: book.pageCount
            )
            
            modelContext.insert(comicBook)
            
            // Try to save the context
            do {
                try modelContext.save()
            } catch {
                print("Failed to save context: \(error)")
                // Clean up the file if we can't save to the database
                try? FileManager.default.removeItem(at: fileURL)
                throw error
            }
            
            // Update progress
            progress.status = .completed
            
            // Remove from active downloads after a short delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                activeDownloads.removeValue(forKey: bookId)
            }
            
            print("✅ Successfully downloaded and added '\(book.displayTitle)' to local library")
            
        } catch {
            // Update progress
            activeDownloads[bookId]?.status = .failed(error)
            
            // Remove from active downloads after showing error
            Task {
                try? await Task.sleep(for: .seconds(5))
                activeDownloads.removeValue(forKey: bookId)
            }
            
            errorMessage = "Failed to download '\(book.displayTitle)': \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Save downloaded data to local library directory
    private func saveToLocalLibrary(data: Data, title: String, fileExtension: String) throws -> URL {
        // Get the application support directory
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        // Create a "ComicLibrary" subdirectory
        let libraryURL = appSupportURL.appendingPathComponent("ComicLibrary", isDirectory: true)
        
        if !fileManager.fileExists(atPath: libraryURL.path) {
            try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        }
        
        // Create unique filename to avoid conflicts
        var fileURL = libraryURL.appendingPathComponent("\(title).\(fileExtension)")
        var counter = 1
        
        // If file exists, append a number
        while fileManager.fileExists(atPath: fileURL.path) {
            fileURL = libraryURL.appendingPathComponent("\(title) (\(counter)).\(fileExtension)")
            counter += 1
        }
        
        // Write the data
        try data.write(to: fileURL)
        
        print("📁 Saved file to: \(fileURL.path)")
        
        return fileURL
    }
    
    /// Check if a book is currently being downloaded
    func isDownloading(_ bookId: String) -> Bool {
        return activeDownloads[bookId] != nil
    }
    
    /// Get download progress for a book
    func downloadProgress(for bookId: String) -> DownloadProgress? {
        return activeDownloads[bookId]
    }
}

// MARK: - Download Progress

@MainActor
class DownloadProgress: ObservableObject, Identifiable {
    let id: String
    let bookId: String
    let bookTitle: String
    @Published var status: DownloadStatus = .queued
    
    init(bookId: String, bookTitle: String) {
        self.id = bookId
        self.bookId = bookId
        self.bookTitle = bookTitle
    }
}

enum DownloadStatus {
    case queued
    case downloading
    case saving
    case addingToLibrary
    case completed
    case failed(Error)
    
    var description: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .saving: return "Saving"
        case .addingToLibrary: return "Adding to library"
        case .completed: return "Completed"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
    
    var isInProgress: Bool {
        switch self {
        case .queued, .downloading, .saving, .addingToLibrary:
            return true
        case .completed, .failed:
            return false
        }
    }
}
