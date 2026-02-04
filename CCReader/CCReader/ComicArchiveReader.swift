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
        
        // Verify file exists first
        guard FileManager.default.fileExists(atPath: url.path) else {
            error = "File not found at: \(url.path)"
            isLoading = false
            return
        }
        
        // Try to start accessing security-scoped resource
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "cbz", "zip":
            await loadCBZ(from: url)
        case "cbr", "rar":
            await loadCBR(from: url)
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
            
            print("Attempting to unzip: \(url.path)")
            print("Temp directory: \(tempDir.path)")
            
            // Unzip the archive
            do {
                try FileManager.default.unzipItem(at: url, to: tempDir)
                print("Successfully unzipped archive")
            } catch {
                print("Unzip error: \(error.localizedDescription)")
                throw error
            }
            
            // Find all image files
            let imageURLs = try findImageFiles(in: tempDir)
                .sorted { url1, url2 in
                    // Sort naturally (page1.jpg before page10.jpg)
                    url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
                }
            
            print("Found \(imageURLs.count) images")
            
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
    
    /// Load a CBR (RAR) archive
    private func loadCBR(from url: URL) async {
        // Try to find unar or unrar using multiple methods
        var extractorPath: String?
        var extractorTool: String?
        
        // Method 1: Check common installation paths
        let knownPaths: [(path: String, tool: String)] = [
            ("/usr/local/bin/unar", "unar"),
            ("/opt/homebrew/bin/unar", "unar"),
            ("/opt/local/bin/unar", "unar"), // MacPorts
            ("/usr/bin/unar", "unar"),
            ("/usr/local/bin/unrar", "unrar"),
            ("/opt/homebrew/bin/unrar", "unrar"),
            ("/opt/local/bin/unrar", "unrar"),
            ("/usr/bin/unrar", "unrar")
        ]
        
        for (path, tool) in knownPaths {
            if FileManager.default.fileExists(atPath: path) {
                extractorPath = path
                extractorTool = tool
                print("Found \(tool) at: \(path)")
                break
            }
        }
        
        // Method 2: Try using 'which' command to locate the tool
        if extractorPath == nil {
            extractorPath = findExecutable(named: "unar")
            extractorTool = "unar"
        }
        
        if extractorPath == nil {
            extractorPath = findExecutable(named: "unrar")
            extractorTool = "unrar"
        }
        
        guard let finalPath = extractorPath, let finalTool = extractorTool else {
            error = """
            CBR files are not currently supported.
            
            This app is sandboxed and cannot execute external tools like 'unar' or 'unrar'.
            
            Options:
            1. Convert your CBR files to CBZ format (which this app supports)
            2. Disable App Sandbox in Xcode (Signing & Capabilities tab)
            
            To convert CBR to CBZ:
            • Use a tool like Calibre or an online converter
            • Or manually: extract the RAR and re-compress as ZIP, then rename to .cbz
            """
            isLoading = false
            return
        }
        
        do {
            // Create a temporary directory to extract files
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            print("Attempting to extract CBR: \(url.path)")
            print("Temp directory: \(tempDir.path)")
            print("Using \(finalTool) at: \(finalPath)")
            
            // Extract the RAR archive
            do {
                if finalTool == "unar" {
                    try FileManager.default.unarItem(at: url, to: tempDir, unarPath: finalPath)
                } else {
                    try FileManager.default.unrarItem(at: url, to: tempDir, unrarPath: finalPath)
                }
                print("Successfully extracted CBR archive")
            } catch {
                print("Extraction error: \(error.localizedDescription)")
                throw error
            }
            
            // Find all image files
            let imageURLs = try findImageFiles(in: tempDir)
                .sorted { url1, url2 in
                    // Sort naturally (page1.jpg before page10.jpg)
                    url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
                }
            
            print("Found \(imageURLs.count) images")
            
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
            self.error = "Failed to load CBR archive: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Use 'which' command to find an executable
    private func findExecutable(named name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                    print("Found \(name) using 'which': \(path)")
                    return path
                }
            }
        } catch {
            print("Failed to run 'which \(name)': \(error)")
        }
        
        return nil
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

// Extension to unzip files using native Swift APIs
extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Read the ZIP file data
        let zipData = try Data(contentsOf: sourceURL)
        
        // Use NSFileCoordinator for sandboxed access
        var coordinatorError: NSError?
        var extractError: Error?
        
        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { url in
            do {
                // Try using the ditto command which works better in sandboxed apps
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-x", "-k", url.path, destinationURL.path]
                
                // Capture output for debugging
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("Ditto error output: \(errorString)")
                    
                    throw NSError(
                        domain: "ComicArchiveReader",
                        code: Int(process.terminationStatus),
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to extract archive: \(errorString)"
                        ]
                    )
                }
            } catch {
                extractError = error
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
        
        if let error = extractError {
            throw error
        }
    }
    
    func unrarItem(at sourceURL: URL, to destinationURL: URL, unrarPath: String) throws {
        var coordinatorError: NSError?
        var extractError: Error?
        
        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { url in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: unrarPath)
                // Use 'x' to extract with full path, '-y' to assume yes on all queries
                process.arguments = ["x", "-y", url.path, destinationURL.path + "/"]
                
                // Capture output for debugging
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("Unrar error output: \(errorString)")
                    
                    throw NSError(
                        domain: "ComicArchiveReader",
                        code: Int(process.terminationStatus),
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to extract RAR archive: \(errorString)"
                        ]
                    )
                }
            } catch {
                extractError = error
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
        
        if let error = extractError {
            throw error
        }
    }
    
    func unarItem(at sourceURL: URL, to destinationURL: URL, unarPath: String) throws {
        var coordinatorError: NSError?
        var extractError: Error?
        
        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinatorError) { url in
            do {
                let process = Process()
                
                // Don't resolve symlinks - use the symlink path directly
                // This is important for sandboxed apps
                process.executableURL = URL(fileURLWithPath: unarPath)
                
                // Set current directory to a known accessible location
                process.currentDirectoryURL = destinationURL
                
                // Set environment to include Homebrew paths
                var environment = ProcessInfo.processInfo.environment
                let homebrewPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/homebrew/Cellar"]
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = homebrewPaths.joined(separator: ":") + ":" + existingPath
                } else {
                    environment["PATH"] = homebrewPaths.joined(separator: ":") + ":/usr/bin:/bin"
                }
                process.environment = environment
                
                // -o specifies output directory, -f forces overwrite, -q for quiet mode
                process.arguments = ["-o", destinationURL.path, "-f", "-q", url.path]
                
                // Capture output for debugging
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                print("Executing: \(unarPath) with args: \(process.arguments ?? [])")
                print("Environment PATH: \(environment["PATH"] ?? "none")")
                
                try process.run()
                process.waitUntilExit()
                
                // Read output regardless of exit status for better debugging
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                
                if !outputString.isEmpty {
                    print("Unar standard output: \(outputString)")
                }
                
                if process.terminationStatus != 0 {
                    print("Unar error output: \(errorString)")
                    
                    throw NSError(
                        domain: "ComicArchiveReader",
                        code: Int(process.terminationStatus),
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to extract RAR archive with unar (exit code \(process.terminationStatus)): \(errorString.isEmpty ? outputString : errorString)"
                        ]
                    )
                }
                
                print("Unar completed successfully with status: \(process.terminationStatus)")
                
            } catch let error as NSError {
                print("Exception during unar execution: \(error)")
                print("Error domain: \(error.domain), code: \(error.code)")
                print("Error description: \(error.localizedDescription)")
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("Underlying error: \(underlyingError)")
                }
                extractError = error
            } catch {
                print("Exception during unar execution: \(error)")
                extractError = error
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
        
        if let error = extractError {
            throw error
        }
    }
}
