import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ZIPFoundation

// MARK: - Data Model
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

// MARK: - Library Folder Model
@Model
class LibraryFolder {
    var path: String
    var name: String
    var dateAdded: Date
    @Attribute(.externalStorage) var bookmarkData: Data?
    
    init(path: String, name: String, bookmarkData: Data? = nil) {
        self.path = path
        self.name = name
        self.dateAdded = Date()
        self.bookmarkData = bookmarkData
    }
}

// MARK: - Folder Tree Node
class FolderNode: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    var children: [FolderNode] = []
    var isExpanded: Bool = false
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
    }
    
    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
            return nil
        }
        
        print("Unknown file type: \(ext)")
        return nil
    }
    
    private static func extractCoverFromCBZ(_ fileURL: URL) -> Data? {
        print("Starting CBZ extraction...")
        
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
    
    static func findComicsInFolder(_ folderURL: URL) -> [URL] {
        guard folderURL.startAccessingSecurityScopedResource() else {
            return []
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }
        
        var results: [URL] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return results
        }
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "cbr" || ext == "cbz" {
                results.append(fileURL)
            }
        }
        
        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

// MARK: - Main App
@main
struct ComicCatalogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Comic.self, LibraryFolder.self])
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryFolders: [LibraryFolder]
    @Query private var comics: [Comic]
    
    @State private var selectedFolder: FolderNode?
    @State private var comicsInFolder: [URL] = []
    @State private var showingAddFolder = false
    @State private var showingManageFolders = false
    @State private var showingComicDetail: Comic?
    @State private var folderTree: [FolderNode] = []
    
    var body: some View {
        NavigationSplitView {
            // Left: Folder tree
            VStack(spacing: 0) {
                HStack {
                    Text("Library Folders")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingManageFolders = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .help("Manage Library Folders")
                    Button {
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add Library Folder")
                }
                .padding()
                
                Divider()
                
                if folderTree.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No library folders")
                            .foregroundColor(.secondary)
                        Button("Add Folder") {
                            showingAddFolder = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if !libraryFolders.isEmpty {
                            Divider()
                                .padding()
                            
                            Text("Found \(libraryFolders.count) folder(s) in database but can't access them")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                            
                            Button("Clear All Library Folders") {
                                clearAllLibraryFolders()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedFolder) {
                        ForEach(folderTree) { node in
                            FolderTreeRow(
                                node: node,
                                selectedFolder: $selectedFolder,
                                onDelete: {
                                    deleteLibraryFolder(node)
                                }
                            )
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 200)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
            .fileImporter(
                isPresented: $showingAddFolder,
                allowedContentTypes: [.folder]
            ) { result in
                handleAddFolder(result)
            }
            .onChange(of: selectedFolder) { _, newFolder in
                loadComicsInFolder(newFolder)
            }
            .onAppear {
                buildFolderTree()
            }
            .sheet(isPresented: $showingManageFolders) {
                ManageFoldersSheet(
                    libraryFolders: libraryFolders,
                    onDelete: { folder in
                        modelContext.delete(folder)
                        buildFolderTree()
                    }
                )
            }
        } detail: {
            // Right: Comics in selected folder
            VStack(spacing: 0) {
                if let folder = selectedFolder {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(folder.name)
                            .font(.headline)
                        Spacer()
                        Text("\(comicsInFolder.count) comics")
                            .foregroundColor(.secondary)
                        
                        Button {
                            importAllComicsInFolder()
                        } label: {
                            Label("Import All", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(comicsInFolder.isEmpty)
                    }
                    .padding()
                    
                    Divider()
                }
                
                if comicsInFolder.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: selectedFolder == nil ? "sidebar.left" : "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(selectedFolder == nil ? "Select a folder" : "No comics in this folder")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(comicsInFolder, id: \.path) { fileURL in
                            ComicFileRow(
                                fileURL: fileURL,
                                comic: findComicByPath(fileURL.path),
                                onShowDetails: { comic in
                                    showingComicDetail = comic
                                },
                                onOpen: {
                                    NSWorkspace.shared.open(fileURL)
                                },
                                onImport: {
                                    importComic(fileURL)
                                },
                                onDelete: { comic in
                                    modelContext.delete(comic)
                                    loadComicsInFolder(selectedFolder)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Comics")
            .sheet(item: $showingComicDetail) { comic in
                ComicDetailSheet(comic: comic)
            }
        }
    }
    
    private func buildFolderTree() {
        print("=== buildFolderTree called ===")
        folderTree = []
        
        print("Library folders count: \(libraryFolders.count)")
        
        for libraryFolder in libraryFolders {
            print("Processing library folder: \(libraryFolder.name) at \(libraryFolder.path)")
            
            // Resolve URL from bookmark
            guard let bookmarkData = libraryFolder.bookmarkData else {
                print("ERROR: No bookmark data for folder")
                continue
            }
            
            var isStale = false
            guard let folderURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                print("ERROR: Failed to resolve bookmark")
                continue
            }
            
            if isStale {
                print("WARNING: Bookmark is stale")
            }
            
            print("Requesting security access for: \(folderURL.path)")
            guard folderURL.startAccessingSecurityScopedResource() else {
                print("ERROR: Failed to get security access for \(folderURL.path)")
                continue
            }
            defer {
                print("Stopping security access for: \(folderURL.path)")
                folderURL.stopAccessingSecurityScopedResource()
            }
            
            print("Creating root node...")
            let rootNode = FolderNode(url: folderURL)
            print("Loading subfolders...")
            loadSubfolders(for: rootNode)
            print("Root node has \(rootNode.children.count) children")
            folderTree.append(rootNode)
        }
        
        print("Final folder tree count: \(folderTree.count)")
    }
    
    private func loadSubfolders(for node: FolderNode) {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: node.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory,
                  isDirectory else {
                continue
            }
            
            let childNode = FolderNode(url: fileURL)
            node.children.append(childNode)
        }
        
        node.children.sort { $0.name < $1.name }
    }
    
    private func handleAddFolder(_ result: Result<URL, Error>) {
        print("=== handleAddFolder called ===")
        switch result {
        case .success(let url):
            print("Selected folder: \(url.path)")
            
            // Check if already added
            print("Checking if folder already exists...")
            print("Current library folders count: \(libraryFolders.count)")
            if libraryFolders.contains(where: { $0.path == url.path }) {
                print("Folder already exists in library")
                return
            }
            
            // Create security-scoped bookmark
            print("Creating security bookmark...")
            guard let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) else {
                print("ERROR: Failed to create bookmark data")
                return
            }
            
            print("Creating new LibraryFolder object...")
            let folder = LibraryFolder(
                path: url.path,
                name: url.lastPathComponent,
                bookmarkData: bookmarkData
            )
            print("Inserting into modelContext...")
            modelContext.insert(folder)
            
            // Force save
            do {
                try modelContext.save()
                print("ModelContext saved successfully")
            } catch {
                print("ERROR saving modelContext: \(error)")
            }
            
            print("Rebuilding folder tree...")
            buildFolderTree()
            print("Folder tree rebuilt. New tree count: \(folderTree.count)")
            
        case .failure(let error):
            print("ERROR selecting folder: \(error)")
        }
    }
    
    private func loadComicsInFolder(_ folder: FolderNode?) {
        guard let folder = folder else {
            comicsInFolder = []
            return
        }
        
        comicsInFolder = ComicFileHandler.findComicsInFolder(folder.url)
    }
    
    private func findComicByPath(_ path: String) -> Comic? {
        comics.first(where: { $0.filePath == path })
    }
    
    private func importComic(_ fileURL: URL) {
        // Check if already imported
        if comics.contains(where: { $0.filePath == fileURL.path }) {
            return
        }
        
        let filename = fileURL.deletingPathExtension().lastPathComponent
        let newComic = Comic(
            title: filename,
            series: "",
            issueNumber: "",
            filePath: fileURL.path
        )
        
        if let coverData = ComicFileHandler.extractCover(from: fileURL) {
            newComic.coverImageData = coverData
        }
        
        modelContext.insert(newComic)
        loadComicsInFolder(selectedFolder)
    }
    
    private func importAllComicsInFolder() {
        for fileURL in comicsInFolder {
            importComic(fileURL)
        }
    }
    
    private func deleteLibraryFolder(_ node: FolderNode) {
        print("Deleting library folder: \(node.url.path)")
        
        // Find and delete the LibraryFolder from database
        if let folderToDelete = libraryFolders.first(where: { $0.path == node.url.path }) {
            modelContext.delete(folderToDelete)
            print("Deleted folder from database")
        }
        
        // Rebuild tree
        buildFolderTree()
        
        // Clear selection if we deleted the selected folder
        if selectedFolder?.url.path == node.url.path {
            selectedFolder = nil
        }
    }
    
    private func clearAllLibraryFolders() {
        print("Clearing all library folders from database...")
        for folder in libraryFolders {
            modelContext.delete(folder)
        }
        buildFolderTree()
        selectedFolder = nil
        print("All library folders cleared")
    }
}

// MARK: - Folder Tree Row
struct FolderTreeRow: View {
    let node: FolderNode
    @Binding var selectedFolder: FolderNode?
    @State private var isExpanded: Bool = false
    let onDelete: (() -> Void)?
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                ForEach(node.children) { child in
                    FolderTreeRow(node: child, selectedFolder: $selectedFolder, onDelete: nil)
                }
            },
            label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(node.name)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFolder = node
                }
            }
        )
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Comic File Row
struct ComicFileRow: View {
    let fileURL: URL
    let comic: Comic?
    let onShowDetails: (Comic) -> Void
    let onOpen: () -> Void
    let onImport: () -> Void
    let onDelete: (Comic) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let comic = comic,
               let imageData = comic.coverImageData,
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
                if let comic = comic {
                    Text(comic.title)
                        .font(.headline)
                    if !comic.series.isEmpty {
                        Text(comic.series + (comic.issueNumber.isEmpty ? "" : " #\(comic.issueNumber)"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(fileURL.deletingPathExtension().lastPathComponent)
                        .font(.headline)
                    Text("Not imported")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if comic == nil {
                Button("Import") {
                    onImport()
                }
                .buttonStyle(.bordered)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpen()
        }
        .contextMenu {
            Button {
                onOpen()
            } label: {
                Label("Open File", systemImage: "book.open")
            }
            
            if let comic = comic {
                Button {
                    onShowDetails(comic)
                } label: {
                    Label("Show Details", systemImage: "info.circle")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    onDelete(comic)
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                }
            } else {
                Button {
                    onImport()
                } label: {
                    Label("Import to Library", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}

// MARK: - Comic Detail Sheet
struct ComicDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var comic: Comic
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Cover image
                    if let imageData = comic.coverImageData,
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 5)
                            .padding()
                    }
                    
                    // Form
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
            .navigationTitle("Comic Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }
}

// MARK: - Manage Folders Sheet
struct ManageFoldersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let libraryFolders: [LibraryFolder]
    let onDelete: (LibraryFolder) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if libraryFolders.isEmpty {
                    ContentUnavailableView(
                        "No Library Folders",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Add folders using the + button")
                    )
                } else {
                    ForEach(libraryFolders, id: \.path) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.name)
                                    .font(.headline)
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                onDelete(folder)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Manage Library Folders")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: [Comic.self, LibraryFolder.self], inMemory: true)
}

