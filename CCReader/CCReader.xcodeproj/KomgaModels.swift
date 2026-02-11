//
//  KomgaModels.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import Foundation

// MARK: - Server Settings

struct KomgaServer: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: String
    var username: String
    var password: String // In production, use Keychain for passwords
    
    init(id: UUID = UUID(), name: String, url: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
    }
    
    var basicAuthToken: String {
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
    }
}

// MARK: - Komga API Models

struct KomgaLibrary: Codable, Identifiable {
    let id: String
    let name: String
    let root: String?
    let unavailable: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, root, unavailable
    }
}

struct KomgaSeries: Codable, Identifiable {
    let id: String
    let libraryId: String
    let name: String
    let url: String?
    let created: String?
    let lastModified: String?
    let fileLastModified: String?
    let booksCount: Int?
    let booksReadCount: Int?
    let booksUnreadCount: Int?
    let booksInProgressCount: Int?
    let metadata: SeriesMetadata?
    
    struct SeriesMetadata: Codable {
        let status: String?
        let title: String?
        let titleSort: String?
        let summary: String?
        let readingDirection: String?
        let publisher: String?
        let ageRating: Int?
        let language: String?
        let genres: [String]?
        let tags: [String]?
    }
}

struct KomgaBook: Codable, Identifiable {
    let id: String
    let seriesId: String
    let seriesTitle: String?
    let libraryId: String
    let name: String
    let url: String
    let number: Double?
    let created: String?
    let lastModified: String?
    let fileLastModified: String?
    let sizeBytes: Int64?
    let size: String?
    let media: MediaInfo?
    let metadata: BookMetadata?
    let readProgress: ReadProgress?
    
    struct MediaInfo: Codable {
        let status: String?
        let mediaType: String?
        let pagesCount: Int
        let comment: String?
        
        enum CodingKeys: String, CodingKey {
            case status, mediaType, pagesCount, comment
        }
    }
    
    struct BookMetadata: Codable {
        let title: String?
        let summary: String?
        let number: String?
        let numberSort: Double?
        let releaseDate: String?
        let authors: [Author]?
        let tags: [String]?
        let isbn: String?
        let links: [Link]?
        
        struct Author: Codable {
            let name: String
            let role: String
        }
        
        struct Link: Codable {
            let label: String
            let url: String
        }
    }
    
    struct ReadProgress: Codable {
        let page: Int
        let completed: Bool
        let readDate: String?
        let created: String?
        let lastModified: String?
    }
    
    var displayTitle: String {
        metadata?.title ?? name
    }
    
    var pageCount: Int {
        media?.pagesCount ?? 0
    }
    
    var currentPage: Int {
        readProgress?.page ?? 0
    }
    
    var isCompleted: Bool {
        readProgress?.completed ?? false
    }
}

struct KomgaPage: Codable {
    let number: Int
    let fileName: String
    let mediaType: String?
}

// MARK: - API Response Wrappers

struct KomgaPageResponse<T: Codable>: Codable {
    let content: [T]
    let pageable: Pageable?
    let totalPages: Int?
    let totalElements: Int?
    let last: Bool?
    let size: Int?
    let number: Int?
    let sort: Sort?
    let numberOfElements: Int?
    let first: Bool?
    let empty: Bool?
    
    struct Pageable: Codable {
        let sort: Sort?
        let offset: Int?
        let pageNumber: Int?
        let pageSize: Int?
        let paged: Bool?
        let unpaged: Bool?
    }
    
    struct Sort: Codable {
        let sorted: Bool?
        let unsorted: Bool?
        let empty: Bool?
    }
}

// MARK: - Read Progress Update

struct ReadProgressUpdate: Codable {
    let page: Int
    let completed: Bool?
}
