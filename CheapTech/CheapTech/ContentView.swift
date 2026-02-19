//
//  ContentView.swift
//  CheapTech
//
//  Created by Russell Allen on 2/13/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSearch.dateCreated, order: .reverse) 
    private var savedSearches: [SavedSearch]
    
    @StateObject private var ebayService = EbayService()
    @State private var selectedSearch: SavedSearch?
    @State private var searchResults: [EbayItem] = []
    @State private var isShowingNewSearchSheet = false
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Saved Searches List
                List(selection: $selectedSearch) {
                    ForEach(savedSearches) { search in
                        NavigationLink(value: search) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(search.searchTerm)
                                    .font(.headline)
                                if let lastSearched = search.lastSearched {
                                    Text("Last searched: \(lastSearched, format: .relative(presentation: .named))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteSearches)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .navigationTitle("Saved Searches")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingNewSearchSheet = true }) {
                        Label("New Search", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: clearAllSearches) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .disabled(savedSearches.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingNewSearchSheet) {
                NewSearchView(ebayService: ebayService) { searchTerm in
                    addSearch(searchTerm: searchTerm)
                }
            }
        } detail: {
            if let selectedSearch = selectedSearch {
                SearchResultsView(
                    search: selectedSearch,
                    ebayService: ebayService,
                    results: $searchResults
                )
            } else {
                ContentUnavailableView(
                    "No Search Selected",
                    systemImage: "magnifyingglass",
                    description: Text("Select a saved search or create a new one to find cheap eBay auctions")
                )
            }
        }
    }
    
    private func addSearch(searchTerm: String) {
        withAnimation {
            let newSearch = SavedSearch(searchTerm: searchTerm)
            modelContext.insert(newSearch)
            selectedSearch = newSearch
        }
    }
    
    private func deleteSearches(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(savedSearches[index])
            }
        }
    }
    
    private func clearAllSearches() {
        withAnimation {
            for search in savedSearches {
                modelContext.delete(search)
            }
            selectedSearch = nil
            searchResults = []
        }
    }
}

struct NewSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var ebayService: EbayService
    let onSave: (String) -> Void
    
    @State private var searchTerm = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $searchTerm)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Search Details")
                } footer: {
                    Text("Enter the name of the item you want to search for on eBay. The app will find auctions ending within 2 days, sorted by lowest price.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(searchTerm)
                        dismiss()
                    }
                    .disabled(searchTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}

struct SearchResultsView: View {
    let search: SavedSearch
    @ObservedObject var ebayService: EbayService
    @Binding var results: [EbayItem]
    
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(search.searchTerm)
                        .font(.title2)
                        .bold()
                    if let lastSearched = search.lastSearched {
                        Text("Last searched: \(lastSearched, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: performSearch) {
                    Label("Search eBay", systemImage: "magnifyingglass")
                }
                .disabled(isSearching)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Results
            if isSearching {
                VStack {
                    Spacer()
                    ProgressView("Searching eBay...")
                    Spacer()
                }
            } else if results.isEmpty {
                ContentUnavailableView(
                    "No Results Yet",
                    systemImage: "tray",
                    description: Text("Tap 'Search eBay' to find auctions ending soon")
                )
            } else {
                List(results) { item in
                    EbayItemRow(item: item)
                        .padding(.vertical, 4)
                }
            }
        }
        .task {
            // Automatically search when view appears
            if results.isEmpty {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        isSearching = true
        Task {
            do {
                results = try await ebayService.searchItems(query: search.searchTerm)
                search.lastSearched = Date()
            } catch {
                print("Search error: \(error)")
            }
            isSearching = false
        }
    }
}

struct EbayItemRow: View {
    let item: EbayItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Image
            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    Label(item.formattedPrice, systemImage: "dollarsign.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    
                    Label(item.formattedTimeRemaining, systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundStyle(item.timeRemaining < 86400 ? .red : .orange)
                }
            }
            
            Spacer()
            
            // Link button
            Link(destination: item.url) {
                Label("View", systemImage: "arrow.up.forward.square")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Open in browser")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedSearch.self, inMemory: true)
}
