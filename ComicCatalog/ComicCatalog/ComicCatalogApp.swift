import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ZIPFoundation

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
    @Attribute(.externalStorage) var coverImageData: Data?
    
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
        self.coverImageData = nil
    }
}

// MARK: - Comic File Handler
class ComicFileHandler {
    static func extractCover(from fileURL: URL) -> Data? {
        print("=== Attempting to extract cover from: \(fileURL.path)")
        let ext = fileURL.pathExtension.lowercased()
        print("File extension: \(ext)")
        
        if ext == "cbz" {
            print("This is a CBZ file, attempting extraction...")
            return extractCoverFromCBZ(fileURL)
        } else if ext == "cbr" {
            print("This is a CBR file - not yet supported")
            // CBR support would require UnRAR library
            // For now, return nil
            return nil
        }
        
        print("Unknown file type: \(ext)")
        return nil
    }
    
    private static func extractCoverFromCBZ(_ fileURL: URL) -> Data? {
        print("Starting CBZ extraction...")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ERROR: File does not exist at path: \(fileURL.path)")
            return nil
        }
        
        print("File exists, requesting security access...")
        guard fileURL.startAccessingSecurityScopedResource() else {
            print("ERROR: Failed to access security scoped resource")
            return nil
        }
        defer {
            print("Stopping security scoped access")
            fileURL.stopAccessingSecurityScopedResource()
        }
        
        do {
            print("Creating archive object...")
            let archive = try Archive(url: fileURL, accessMode: .read)
            print("Archive created successfully")
            
            // Get all image files and sort them
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp"]
            let imageEntries = archive.filter { entry in
                let ext = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
                let isImage = imageExtensions.contains(ext)
                if isImage {
                    print("Found image: \(entry.path)")
                }
                return isImage
            }.sorted { $0.path < $1.path }
            
            print("Total image files found: \(imageEntries.count)")
            
            // Get the first image (cover)
            guard let firstImage = imageEntries.first else {
                print("ERROR: No image files found in archive")
                return nil
            }
            
            print("Extracting first image: \(firstImage.path)")
            var imageData = Data()
            _ = try archive.extract(firstImage) { data in
                imageData.append(data)
            }
            
            print("SUCCESS: Extracted \(imageData.count) bytes")
            return imageData
            
        } catch {
            print("ERROR extracting cover from CBZ: \(error)")
            return nil
        }
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
    @State private var showingFolderBrowser = false
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar - List of comics
            List(selection: $selectedComic) {
                ForEach(comics) { comic in
                    ComicRowView(comic: comic)
                        .tag(comic)
                        .onTapGesture(count: 2) {
                            openComicFile(comic)
                        }
                        .contextMenu {
                            Button {
                                selectedComic = comic
                            } label: {
                                Label("Show Details", systemImage: "info.circle")
                            }
                            
                            Button {
                                openComicFile(comic)
                            } label: {
                                Label("Open File", systemImage: "book.open")
                            }
                            
                            Divider()
                            
                            Button {
                                extractCoverForComic(comic)
                            } label: {
                                Label("Extract Cover", systemImage: "photo")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(comic)
                            } label: {
                                Label("Delete from Library", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: deleteComics)
            }
            .navigationTitle("Comic Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingImporter = true }) {
                            Label("Add Files...", systemImage: "doc.badge.plus")
                        }
                        Button(action: { showingFolderBrowser = true }) {
                            Label("Browse Folders...", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
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
            .sheet(isPresented: $showingFolderBrowser) {
                FolderBrowserView(modelContext: modelContext, existingComics: comics)
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
                
                // Check if already imported
                if comics.contains(where: { $0.filePath == url.path }) {
                    continue
                }
                
                // Create a new comic with basic info from filename
                let filename = url.deletingPathExtension().lastPathComponent
                let newComic = Comic(
                    title: filename,
                    series: "",
                    issueNumber: "",
                    filePath: url.path
                )
                
                // Try to extract cover
                if let coverData = ComicFileHandler.extractCover(from: url) {
                    newComic.coverImageData = coverData
                }
                
                modelContext.insert(newComic)
            }
        case .failure(let error):
            print("Error importing files: \(error.localizedDescription)")
        }
    }
    
    private func extractCoverForComic(_ comic: Comic) {
        let fileURL = URL(fileURLWithPath: comic.filePath)
        if let coverData = ComicFileHandler.extractCover(from: fileURL) {
            comic.coverImageData = coverData
        }
    }
    
    private func openComicFile(_ comic: Comic) {
        let fileURL = URL(fileURLWithPath: comic.filePath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Error: File not found at \(fileURL.path)")
            // Could show an alert here
            return
        }
        
        // Open the file with the default application
        NSWorkspace.shared.open(fileURL)
    }
    
    private func deleteComics(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(comics[index])
        }
    }
}

// MARK: - Folder Browser View
struct FolderBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    let existingComics: [Comic]
    
    @State private var rootFolder: URL?
    @State private var currentFolderContents: [FolderItem] = []
    @State private var selectedItems: Set<String> = []
    @State private var isLoading = false
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Browse Comic Folders")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // Folder path display
            if let rootFolder = rootFolder {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(rootFolder.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Change Folder") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Divider()
            }
            
            // Content area
            if rootFolder == nil {
                // No folder selected yet
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a folder to browse")
                        .font(.title2)
                    Button("Choose Folder") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                // Loading
                ProgressView("Scanning folders...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if currentFolderContents.isEmpty {
                // No comics found
                VStack(spacing: 20) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No comic files found")
                        .font(.title2)
                    Text("Make sure the folder contains .cbr or .cbz files")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // File list
                VStack(spacing: 0) {
                    // Toolbar
                    HStack {
                        Button(action: selectAll) {
                            Label("Select All", systemImage: "checkmark.circle")
                        }
                        Button(action: deselectAll) {
                            Label("Deselect All", systemImage: "circle")
                        }
                        Spacer()
                        Text("\(selectedItems.count) selected")
                            .foregroundColor(.secondary)
                        Button(action: importSelected) {
                            Label("Import Selected", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedItems.isEmpty)
                    }
                    .padding()
                    
                    Divider()
                    
                    // List
                    List {
                        ForEach(currentFolderContents) { item in
                            FolderItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id)
                            ) {
                                toggleSelection(item)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 700, height: 500)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    private func handleFolderSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Request security-scoped access
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return
            }
            
            rootFolder = url
            scanFolder(url)
            
            // Keep access during the session
            // url.stopAccessingSecurityScopedResource() - Don't call this yet
        case .failure(let error):
            print("Error selecting folder: \(error)")
        }
    }
    
    private func scanFolder(_ url: URL) {
        isLoading = true
        currentFolderContents = []
        selectedItems = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            let items = self.findComicFiles(in: url)
            DispatchQueue.main.async {
                self.currentFolderContents = items
                self.isLoading = false
            }
        }
    }
    
    private func findComicFiles(in directory: URL) -> [FolderItem] {
        var results: [FolderItem] = []
        let fileManager = FileManager.default
        
        print("Scanning directory: \(directory.path)")
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("Failed to create enumerator")
            return results
        }
        
        var fileCount = 0
        for case let fileURL as URL in enumerator {
            fileCount += 1
            let ext = fileURL.pathExtension.lowercased()
            print("Found file: \(fileURL.lastPathComponent) with extension: '\(ext)'")
            
            if ext == "cbr" || ext == "cbz" {
                print("  -> This is a comic file!")
                // Check if already imported
                let alreadyImported = existingComics.contains(where: { $0.filePath == fileURL.path })
                
                // Get relative path from root folder
                let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
                
                results.append(FolderItem(
                    url: fileURL,
                    relativePath: relativePath,
                    alreadyImported: alreadyImported
                ))
            }
        }
        
        print("Total files scanned: \(fileCount)")
        print("Comic files found: \(results.count)")
        
        return results.sorted { $0.relativePath < $1.relativePath }
    }
    
    private func toggleSelection(_ item: FolderItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func selectAll() {
        selectedItems = Set(currentFolderContents.filter { !$0.alreadyImported }.map { $0.id })
    }
    
    private func deselectAll() {
        selectedItems.removeAll()
    }
    
    private func importSelected() {
        let itemsToImport = currentFolderContents.filter { selectedItems.contains($0.id) }
        
        for item in itemsToImport {
            let filename = item.url.deletingPathExtension().lastPathComponent
            let newComic = Comic(
                title: filename,
                series: "",
                issueNumber: "",
                filePath: item.url.path
            )
            
            // Try to extract cover
            if let coverData = ComicFileHandler.extractCover(from: item.url) {
                newComic.coverImageData = coverData
            }
            
            modelContext.insert(newComic)
        }
        
        // Rescan to update "already imported" status
        if let rootFolder = rootFolder {
            scanFolder(rootFolder)
        }
    }
}

// MARK: - Folder Item Model
struct FolderItem: Identifiable {
    let id = UUID().uuidString
    let url: URL
    let relativePath: String
    let alreadyImported: Bool
}

// MARK: - Folder Item Row
struct FolderItemRow: View {
    let item: FolderItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(item.alreadyImported)
            
            Image(systemName: item.url.pathExtension.lowercased() == "cbr" ? "doc.zipper" : "doc.zip")
                .foregroundColor(item.alreadyImported ? .gray : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent)
                    .foregroundColor(item.alreadyImported ? .gray : .primary)
                Text(item.relativePath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if item.alreadyImported {
                Text("Already Imported")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comic Row (List Item)
struct ComicRowView: View {
    let comic: Comic
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = comic.coverImageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 60)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(comic.title)
                    .font(.headline)
                if !comic.series.isEmpty {
                    Text(comic.series + (comic.issueNumber.isEmpty ? "" : " #\(comic.issueNumber)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comic Detail and Editor View
struct ComicDetailView: View {
    @Bindable var comic: Comic
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Cover image at top
                if let imageData = comic.coverImageData,
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 5)
                        .padding()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("No cover image")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                }
                
                // Form with details
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
            }
        }
        .frame(minWidth: 500)
        .navigationTitle("Comic Details")
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: Comic.self, inMemory: true)
}

