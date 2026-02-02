import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Data Model
// This defines what information we store about each comic
@Model
class Comic {
    var title: String
    var series: String
    var issueNumber: String
    var publisher: String
    var writer: String
    var artist: String
    var publicationDate: Date
    var summary: String
    var genre: String
    var filePath: String
    var dateAdded: Date
    
    init(title: String = "", series: String = "", issueNumber: String = "",
         publisher: String = "", writer: String = "", artist: String = "",
         publicationDate: Date = Date(), summary: String = "",
         genre: String = "", filePath: String = "") {
        self.title = title
        self.series = series
        self.issueNumber = issueNumber
        self.publisher = publisher
        self.writer = writer
        self.artist = artist
        self.publicationDate = publicationDate
        self.summary = summary
        self.genre = genre
        self.filePath = filePath
        self.dateAdded = Date()
    }
}

// MARK: - Main App
@main
struct ComicCatalogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Comic.self)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Comic.dateAdded, order: .reverse) private var comics: [Comic]
    @State private var selectedComic: Comic?
    @State private var showingImporter = false
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar - List of comics
            List(selection: $selectedComic) {
                ForEach(comics) { comic in
                    ComicRowView(comic: comic)
                        .tag(comic)
                }
                .onDelete(perform: deleteComics)
            }
            .navigationTitle("Comic Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingImporter = true }) {
                        Label("Add Comic", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
        } detail: {
            // Right side - Comic details and editor
            if let comic = selectedComic {
                ComicDetailView(comic: comic)
            } else {
                Text("Select a comic to view details")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                // Only process .cbr and .cbz files
                let ext = url.pathExtension.lowercased()
                guard ext == "cbr" || ext == "cbz" else { continue }
                
                // Create a new comic with basic info from filename
                let filename = url.deletingPathExtension().lastPathComponent
                let newComic = Comic(
                    title: filename,
                    series: "",
                    issueNumber: "",
                    filePath: url.path
                )
                modelContext.insert(newComic)
            }
        case .failure(let error):
            print("Error importing files: \(error.localizedDescription)")
        }
    }
    
    private func deleteComics(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(comics[index])
        }
    }
}

// MARK: - Comic Row (List Item)
struct ComicRowView: View {
    let comic: Comic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comic.title)
                .font(.headline)
            if !comic.series.isEmpty {
                Text(comic.series + (comic.issueNumber.isEmpty ? "" : " #\(comic.issueNumber)"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comic Detail and Editor View
struct ComicDetailView: View {
    @Bindable var comic: Comic
    
    var body: some View {
        Form {
            Section("Basic Information") {
                LabeledContent("Title") {
                    TextField("Title", text: $comic.title)
                        .textFieldStyle(.roundedBorder)
                }
                
                LabeledContent("Series") {
                    TextField("Series", text: $comic.series)
                        .textFieldStyle(.roundedBorder)
                }
                
                LabeledContent("Issue #") {
                    TextField("Issue Number", text: $comic.issueNumber)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                }
            }
            
            Section("Credits") {
                LabeledContent("Publisher") {
                    TextField("Publisher", text: $comic.publisher)
                        .textFieldStyle(.roundedBorder)
                }
                
                LabeledContent("Writer") {
                    TextField("Writer", text: $comic.writer)
                        .textFieldStyle(.roundedBorder)
                }
                
                LabeledContent("Artist") {
                    TextField("Artist", text: $comic.artist)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Section("Details") {
                LabeledContent("Genre") {
                    TextField("Genre", text: $comic.genre)
                        .textFieldStyle(.roundedBorder)
                }
                
                DatePicker("Publication Date", selection: $comic.publicationDate, displayedComponents: .date)
                
                VStack(alignment: .leading) {
                    Text("Summary")
                        .font(.headline)
                    TextEditor(text: $comic.summary)
                        .frame(minHeight: 100)
                        .border(Color.gray.opacity(0.2))
                }
            }
            
            Section("File Information") {
                LabeledContent("File Path") {
                    Text(comic.filePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Date Added") {
                    Text(comic.dateAdded, style: .date)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500)
        .navigationTitle("Comic Details")
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: Comic.self, inMemory: true)
}
