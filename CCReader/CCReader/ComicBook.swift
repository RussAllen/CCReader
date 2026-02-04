//
//  ComicBook.swift
//  CCReader
//
//  Created by Russell Allen on 2/4/26.
//

import Foundation
import SwiftData

@Model
final class ComicBook {
    var title: String
    var fileURL: URL
    var bookmarkData: Data?
    var lastOpenedDate: Date
    var currentPage: Int
    var totalPages: Int
    
    init(title: String, fileURL: URL, bookmarkData: Data? = nil, currentPage: Int = 0, totalPages: Int = 0) {
        self.title = title
        self.fileURL = fileURL
        self.bookmarkData = bookmarkData
        self.lastOpenedDate = Date()
        self.currentPage = currentPage
        self.totalPages = totalPages
    }
    
    /// Get a URL from the stored bookmark, if available
    func resolvedURL() -> URL? {
        guard let bookmarkData = bookmarkData else {
            return fileURL
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return fileURL
        }
    }
}
