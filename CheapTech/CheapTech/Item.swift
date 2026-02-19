//
//  Item.swift
//  CheapTech
//
//  Created by Russell Allen on 2/13/26.
//

import Foundation
import SwiftData

@Model
final class SavedSearch {
    var searchTerm: String
    var dateCreated: Date
    var lastSearched: Date?
    
    init(searchTerm: String, dateCreated: Date = Date()) {
        self.searchTerm = searchTerm
        self.dateCreated = dateCreated
    }
}
struct EbayItem: Identifiable {
    let id: String // eBay item ID
    let title: String
    let currentPrice: Double
    let currency: String
    let endTime: Date
    let url: URL
    let imageURL: URL?
    
    var timeRemaining: TimeInterval {
        endTime.timeIntervalSinceNow
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: currentPrice)) ?? "\(currentPrice)"
    }
    
    var formattedTimeRemaining: String {
        let interval = timeRemaining
        
        if interval < 0 {
            return "Ended"
        }
        
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

