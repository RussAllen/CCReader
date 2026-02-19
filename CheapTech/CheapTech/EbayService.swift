//
//  EbayService.swift
//  CheapTech
//
//  Created by Russell Allen on 2/13/26.
//

import Foundation
import Combine

@MainActor
class EbayService: ObservableObject {
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    // You'll need to get your own eBay API key from:
    // https://developer.ebay.com/
    // Note: Sandbox keys work with the production Finding API endpoint
    private let appID = "RussellA-CheapTec-SBX-f4eaa38ed-ecc95ccc"
    
    // The Finding API uses the same endpoint for both sandbox and production keys
    private let baseURL = "https://svcs.ebay.com/services/search/FindingService/v1"
    
    func searchItems(query: String) async throws -> [EbayItem] {
        isSearching = true
        errorMessage = nil
        
        defer {
            isSearching = false
        }
        
        // Calculate the date 2 days from now for the filter
        let twoDaysFromNow = Date().addingTimeInterval(2 * 24 * 60 * 60)
        let dateFormatter = ISO8601DateFormatter()
        let endTimeFilter = dateFormatter.string(from: twoDaysFromNow)
        
        print("🔍 Searching for: '\(query)'")
        print("📅 End time filter: \(endTimeFilter)")
        
        // Build eBay Finding API URL - using simpler findItemsByKeywords first
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "OPERATION-NAME", value: "findItemsByKeywords"),
            URLQueryItem(name: "SERVICE-VERSION", value: "1.0.0"),
            URLQueryItem(name: "SECURITY-APPNAME", value: appID),
            URLQueryItem(name: "RESPONSE-DATA-FORMAT", value: "JSON"),
            URLQueryItem(name: "keywords", value: query),
            URLQueryItem(name: "itemFilter(0).name", value: "ListingType"),
            URLQueryItem(name: "itemFilter(0).value", value: "Auction"),
            URLQueryItem(name: "itemFilter(1).name", value: "EndTimeTo"),
            URLQueryItem(name: "itemFilter(1).value", value: endTimeFilter),
            URLQueryItem(name: "sortOrder", value: "PricePlusShippingLowest"),
            URLQueryItem(name: "paginationInput.entriesPerPage", value: "50")
        ]
        
        guard let url = components.url else {
            throw EbayError.invalidURL
        }
        
        print("🌐 Request URL: \(url.absoluteString)")
        
        // Create URL request with proper headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EbayError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // Print response body for error debugging
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorBody)")
                }
                throw EbayError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Raw response (first 1000 chars): \(jsonString.prefix(1000))")
            }
            
            let items = try parseEbayResponse(data)
            print("✅ Successfully parsed \(items.count) items")
            return items.sorted { $0.currentPrice < $1.currentPrice }
        } catch let error as EbayError {
            print("❌ eBay error: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            print("   Error details: \(error)")
            throw error
        }
    }
    
    private func parseEbayResponse(_ data: Data) throws -> [EbayItem] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        print("🔍 Parsing response...")
        
        // Try findItemsByKeywords response format first
        if let findItemsByKeywordsResponse = json?["findItemsByKeywordsResponse"] as? [[String: Any]],
           let firstResponse = findItemsByKeywordsResponse.first {
            return try parseSearchResult(from: firstResponse)
        }
        
        // Try findItemsAdvanced response format
        if let findItemsAdvancedResponse = json?["findItemsAdvancedResponse"] as? [[String: Any]],
           let firstResponse = findItemsAdvancedResponse.first {
            return try parseSearchResult(from: firstResponse)
        }
        
        print("❌ Could not find expected response format")
        return []
    }
    
    private func parseSearchResult(from response: [String: Any]) throws -> [EbayItem] {
        // Check for errors first
        if let ack = response["ack"] as? [String], ack.first == "Failure" {
            if let errorMessage = response["errorMessage"] as? [[String: Any]],
               let firstError = errorMessage.first,
               let errors = firstError["error"] as? [[String: Any]],
               let firstErrorDetail = errors.first,
               let message = firstErrorDetail["message"] as? [String] {
                print("❌ API Error: \(message.first ?? "Unknown error")")
            }
            return []
        }
        
        guard let searchResult = response["searchResult"] as? [[String: Any]],
              let firstResult = searchResult.first else {
            print("❌ No searchResult found")
            return []
        }
        
        // Check item count
        if let count = firstResult["@count"] as? String {
            print("📊 API returned \(count) items")
        }
        
        guard let items = firstResult["item"] as? [[String: Any]] else {
            print("ℹ️ No items in search result")
            return []
        }
        
        print("🔄 Processing \(items.count) items...")
        
        var ebayItems: [EbayItem] = []
        
        for (index, item) in items.enumerated() {
            guard let itemId = item["itemId"] as? [String],
                  let title = item["title"] as? [String],
                  let viewItemURL = item["viewItemURL"] as? [String],
                  let sellingStatus = item["sellingStatus"] as? [[String: Any]],
                  let firstSellingStatus = sellingStatus.first,
                  let currentPrice = firstSellingStatus["currentPrice"] as? [[String: Any]],
                  let firstPrice = currentPrice.first,
                  let priceValue = firstPrice["__value__"] as? String,
                  let currency = firstPrice["@currencyId"] as? String,
                  let listingInfo = item["listingInfo"] as? [[String: Any]],
                  let firstListingInfo = listingInfo.first,
                  let endTime = firstListingInfo["endTime"] as? [String] else {
                print("⚠️ Skipping item \(index): missing required fields")
                continue
            }
            
            guard let price = Double(priceValue),
                  let url = URL(string: viewItemURL.first ?? ""),
                  let endDate = ISO8601DateFormatter().date(from: endTime.first ?? "") else {
                print("⚠️ Skipping item \(index): invalid data types")
                continue
            }
            
            // Extract image URL if available
            var imageURL: URL?
            if let galleryURL = item["galleryURL"] as? [String],
               let urlString = galleryURL.first {
                imageURL = URL(string: urlString)
            }
            
            let ebayItem = EbayItem(
                id: itemId.first ?? UUID().uuidString,
                title: title.first ?? "Unknown",
                currentPrice: price,
                currency: currency,
                endTime: endDate,
                url: url,
                imageURL: imageURL
            )
            
            ebayItems.append(ebayItem)
        }
        
        print("✅ Successfully parsed \(ebayItems.count) items")
        return ebayItems
    }
}

enum EbayError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from eBay"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .parsingError:
            return "Failed to parse eBay response"
        }
    }
}
