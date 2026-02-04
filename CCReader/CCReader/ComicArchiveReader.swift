//
//  ComicArchiveReader.swift
//  CCReader
//
//  Created by Russell Allen on 2/4/26.
//

import Foundation
import UniformTypeIdentifiers
import AppKit
import Combine

/// Reads comic book archives (CBZ and CBR formats)
@MainActor
class ComicArchiveReader: ObservableObject {
    @Published var pages: [NSImage] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var fileURL: URL?
    
    /// Supported image extensions for comic pages
    private let supportedImageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "webp"]
    
    /// Load a comic archive file
    func loadArchive(from url: URL) async {
        isLoading = true
        error = nil
        pages = []
        fileURL = url
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            error = "Unable to access file"
            isLoading = false
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "cbz", "zip":
            await loadCBZ(from: url)
        case "cbr", "rar":
            error = "CBR files require additional dependencies. Please convert to CBZ format."
            isLoading = false
        default:
            error = "Unsupported file format: .\(fileExtension)"
            isLoading = false
        }
    }
    
    /// Load a CBZ (ZIP) archive
    private func loadCBZ(from url: URL) async {
        do {
            // Create a temporary directory to extract files
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Unzip the archive
            try FileManager.default.unzipItem(at: url, to: tempDir)
            
            // Find all image files
            let imageURLs = try findImageFiles(in: tempDir)
                .sorted { url1, url2 in
                    // Sort naturally (page1.jpg before page10.jpg)
                    url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
                }
            
            // Load images
            var loadedPages: [NSImage] = []
            for imageURL in imageURLs {
                if let image = NSImage(contentsOf: imageURL) {
                    loadedPages.append(image)
                }
            }
            
            // Clean up temporary directory
            try? FileManager.default.removeItem(at: tempDir)
            
            if loadedPages.isEmpty {
                error = "No valid images found in archive"
            } else {
                pages = loadedPages
            }
            
        } catch {
            self.error = "Failed to load archive: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Recursively find all image files in a directory
    private func findImageFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var imageFiles: [URL] = []
        
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                let fileExtension = fileURL.pathExtension.lowercased()
                if supportedImageExtensions.contains(fileExtension) {
                    imageFiles.append(fileURL)
                }
            }
        }
        
        return imageFiles
    }
}

// Extension to unzip files using the system's unzip utility
extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Use the unzip command-line tool
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", sourceURL.path, "-d", destinationURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ComicArchiveReader", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to unzip archive"
            ])
        }
    }
}
