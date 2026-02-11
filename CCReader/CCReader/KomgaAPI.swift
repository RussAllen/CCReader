//
//  KomgaAPI.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import Foundation
import AppKit
import Combine

/// API client for interacting with a Komga server
@MainActor
class KomgaAPI: ObservableObject {
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private var server: KomgaServer?
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Server Connection
    
    func connect(to server: KomgaServer) async -> Bool {
        self.server = server
        
        // Test connection by fetching libraries
        do {
            _ = try await fetchLibraries()
            isConnected = true
            errorMessage = nil
            return true
        } catch {
            isConnected = false
            errorMessage = "Failed to connect: \(error.localizedDescription)"
            return false
        }
    }
    
    func disconnect() {
        server = nil
        isConnected = false
        errorMessage = nil
    }
    
    // MARK: - Libraries
    
    func fetchLibraries() async throws -> [KomgaLibrary] {
        let endpoint = "/api/v1/libraries"
        return try await performRequest(endpoint: endpoint)
    }
    
    // MARK: - Series
    
    func fetchSeries(libraryId: String? = nil, page: Int = 0, size: Int = 20) async throws -> KomgaPageResponse<KomgaSeries> {
        var endpoint = "/api/v1/series?page=\(page)&size=\(size)&sort=metadata.titleSort,asc"
        
        if let libraryId = libraryId {
            endpoint += "&library_id=\(libraryId)"
        }
        
        return try await performRequest(endpoint: endpoint)
    }
    
    func fetchSeriesById(_ seriesId: String) async throws -> KomgaSeries {
        let endpoint = "/api/v1/series/\(seriesId)"
        return try await performRequest(endpoint: endpoint)
    }
    
    // MARK: - Books
    
    func fetchBooks(seriesId: String, page: Int = 0, size: Int = 100) async throws -> KomgaPageResponse<KomgaBook> {
        let endpoint = "/api/v1/series/\(seriesId)/books?page=\(page)&size=\(size)&sort=metadata.numberSort,asc"
        return try await performRequest(endpoint: endpoint)
    }
    
    func fetchBookById(_ bookId: String) async throws -> KomgaBook {
        let endpoint = "/api/v1/books/\(bookId)"
        return try await performRequest(endpoint: endpoint)
    }
    
    // MARK: - Pages
    
    func fetchPages(bookId: String) async throws -> [KomgaPage] {
        let endpoint = "/api/v1/books/\(bookId)/pages"
        return try await performRequest(endpoint: endpoint)
    }
    
    // MARK: - Reading Lists
    
    func fetchReadingLists(libraryId: String? = nil, page: Int = 0, size: Int = 20) async throws -> KomgaPageResponse<KomgaReadingList> {
        var endpoint = "/api/v1/readlists?page=\(page)&size=\(size)&sort=name,asc"
        
        if let libraryId = libraryId {
            endpoint += "&library_id=\(libraryId)"
        }
        
        return try await performRequest(endpoint: endpoint)
    }
    
    func fetchReadingListById(_ readingListId: String) async throws -> KomgaReadingList {
        let endpoint = "/api/v1/readlists/\(readingListId)"
        return try await performRequest(endpoint: endpoint)
    }
    
    func fetchBooksInReadingList(readingListId: String, page: Int = 0, size: Int = 100) async throws -> KomgaPageResponse<KomgaBook> {
        let endpoint = "/api/v1/readlists/\(readingListId)/books?page=\(page)&size=\(size)"
        return try await performRequest(endpoint: endpoint)
    }
    
    func fetchReadingListThumbnail(readingListId: String) async throws -> NSImage {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/readlists/\(readingListId)/thumbnail"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let image = NSImage(data: data) else {
            throw KomgaError.imageDecodingFailed
        }
        
        return image
    }
    
    // MARK: - Page Images
    
    func fetchPageImage(bookId: String, pageNumber: Int) async throws -> NSImage {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/books/\(bookId)/pages/\(pageNumber)"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let image = NSImage(data: data) else {
            throw KomgaError.imageDecodingFailed
        }
        
        return image
    }
    
    // MARK: - Thumbnails
    
    func fetchSeriesThumbnail(seriesId: String) async throws -> NSImage {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/series/\(seriesId)/thumbnail"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let image = NSImage(data: data) else {
            throw KomgaError.imageDecodingFailed
        }
        
        return image
    }
    
    func fetchBookThumbnail(bookId: String) async throws -> NSImage {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/books/\(bookId)/thumbnail"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let image = NSImage(data: data) else {
            throw KomgaError.imageDecodingFailed
        }
        
        return image
    }
    
    // MARK: - Book Download
    
    func downloadBook(bookId: String) async throws -> (data: Data, filename: String) {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/books/\(bookId)/file"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Try to get filename from Content-Disposition header
        var filename = "comic"
        if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition") {
            // Parse filename from Content-Disposition header
            // Format: attachment; filename="filename.cbz"
            if let filenameMatch = contentDisposition.range(of: "filename=\"([^\"]+)\"", options: .regularExpression) {
                let filenameString = String(contentDisposition[filenameMatch])
                if let start = filenameString.range(of: "\""), 
                   let end = filenameString.range(of: "\"", range: start.upperBound..<filenameString.endIndex) {
                    filename = String(filenameString[start.upperBound..<end.lowerBound])
                }
            }
        }
        
        return (data, filename)
    }
    
    // MARK: - Read Progress
    
    func updateReadProgress(bookId: String, page: Int, completed: Bool = false) async throws {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/books/\(bookId)/read-progress"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let update = ReadProgressUpdate(page: page, completed: completed)
        request.httpBody = try JSONEncoder().encode(update)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    func markBookAsRead(bookId: String) async throws {
        try await updateReadProgress(bookId: bookId, page: 0, completed: true)
    }
    
    func markBookAsUnread(bookId: String) async throws {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        let urlString = "\(baseURL)/api/v1/books/\(bookId)/read-progress"
        
        guard let url = URL(string: urlString) else {
            throw KomgaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Decodable>(endpoint: String) async throws -> T {
        guard let server = server else {
            throw KomgaError.notConnected
        }
        
        // Ensure server URL doesn't end with a slash
        let baseURL = server.url.hasSuffix("/") ? String(server.url.dropLast()) : server.url
        
        // Construct the full URL by appending the endpoint
        let fullURLString = baseURL + endpoint
        
        guard let url = URL(string: fullURLString) else {
            print("❌ Invalid URL: \(fullURLString)")
            throw KomgaError.invalidURL
        }
        
        print("🌐 API Request: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("Basic \(server.basicAuthToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KomgaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ API Error (\(httpResponse.statusCode)): \(errorMessage)")
            }
            throw KomgaError.httpError(statusCode: httpResponse.statusCode)
        }
        
        print("✅ API Response: \(httpResponse.statusCode)")
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            throw KomgaError.decodingFailed(error)
        }
    }
}

// MARK: - Errors

enum KomgaError: LocalizedError {
    case notConnected
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
    case imageDecodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to a Komga server"
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .imageDecodingFailed:
            return "Failed to decode image"
        }
    }
}
