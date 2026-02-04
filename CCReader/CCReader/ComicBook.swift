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
    var lastOpenedDate: Date
    var currentPage: Int
    var totalPages: Int
    
    init(title: String, fileURL: URL, currentPage: Int = 0, totalPages: Int = 0) {
        self.title = title
        self.fileURL = fileURL
        self.lastOpenedDate = Date()
        self.currentPage = currentPage
        self.totalPages = totalPages
    }
}
