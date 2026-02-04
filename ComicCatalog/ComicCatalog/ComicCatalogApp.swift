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

// MARK: - Comic Row View (for Library list)
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
    // Track unar availability to avoid repeated checks
    private static var unarAvailable: Bool?
    private static var unarPath: String?
    
    static func extractCover(from fileURL: URL) -> Data? {
        print("=== Attempting to extract cover from: \(fileURL.path)")
        let ext = fileURL.pathExtension.lowercased()
        print("File extension: \(ext)")
        
        // Check if sandboxed
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        print("App is sandboxed: \(isSandboxed)")
        
        if ext == "cbz" {
            print("This is a CBZ file, attempting extraction...")
            return extractCoverFromCBZ(fileURL)
        } else if ext == "cbr" {
            print("This is a CBR file, attempting extraction...")
            
            if isSandboxed {
                print("❌ ERROR: Cannot extract CBR in sandboxed app")
                print("The app is running in sandbox mode which prevents executing external tools")
                print("To fix: Remove 'App Sandbox' capability in Xcode and rebuild")
                
                // Only show alert once
                if unarAvailable == nil {
                    unarAvailable = false
                    DispatchQueue.main.async {
                        showUnarNotInstalledAlert()
                    }
                }
                return nil
            }
            
            // Check unar availability first
            if unarAvailable == nil {
                print("Checking for unar availability...")
                unarPath = findUnarPath()
                unarAvailable = unarPath != nil
                
                print("unar found: \(unarAvailable ?? false)")
                if let path = unarPath {
                    print("unar path: \(path)")
                } else {
                    print("unar path: not found")
                }
                
                if unarAvailable == false {
                    print("⚠️ WARNING: unar is not installed!")
                    print("To extract CBR files, install unar using one of these methods:")
                    print("  • Homebrew: brew install unar")
                    print("  • Download from: https://theunarchiver.com/command-line")
                    
                    // Show alert to user
                    DispatchQueue.main.async {
                        showUnarNotInstalledAlert()
                    }
                }
            }
            
            if unarAvailable == false {
                print("Skipping CBR extraction - unar not available")
                return nil
            }
            
            print("Proceeding with CBR extraction...")
            return extractCoverFromCBR(fileURL)
        }
        
        print("Unknown file type: \(ext)")
        return nil
    }
    
    private static func showUnarNotInstalledAlert() {
        let alert = NSAlert()
        
        // Check if app is sandboxed
        let environment = ProcessInfo.processInfo.environment
        let isSandboxed = environment["APP_SANDBOX_CONTAINER_ID"] != nil
        
        if isSandboxed {
            alert.messageText = "CBR Support Not Available (Sandboxed App)"
            alert.informativeText = """
            This app is running in a sandbox which prevents it from executing external tools like 'unar'.
            
            To enable CBR support:
            1. Open your Xcode project
            2. Select your target
            3. Go to "Signing & Capabilities"
            4. Remove "App Sandbox" capability
            5. Rebuild the app
            
            Note: Sandboxed apps cannot execute external processes for security reasons.
            """
        } else {
            alert.messageText = "CBR Support Not Available"
            alert.informativeText = "To view CBR comic files, you need to install 'unar'.\n\nInstall via Terminal:\nbrew install unar\n\nor download from:\nhttps://theunarchiver.com/command-line"
        }
        
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if !isSandboxed {
            alert.addButton(withTitle: "Copy Command")
        }
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn && !isSandboxed {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew install unar", forType: .string)
        }
    }
    
    private static func extractCoverFromCBR(_ fileURL: URL) -> Data? {
        print("Starting CBR extraction using command-line unar...")
        print("File: \(fileURL.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ ERROR: File does not exist at path: \(fileURL.path)")
            return nil
        }
        
        print("✓ File exists")
        
        // Use cached unar path
        guard let executablePath = unarPath else {
            print("❌ ERROR: unar path not found")
            return nil
        }
        
        print("✓ Using unar at: \(executablePath)")
        
        // Verify unar is executable
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            print("❌ ERROR: unar at \(executablePath) is not executable")
            return nil
        }
        
        print("✓ unar is executable")
        
        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        print("Creating temp directory: \(tempDir.path)")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            print("✓ Temp directory created")
        } catch {
            print("❌ ERROR creating temp directory: \(error)")
            return nil
        }
        
        defer {
            do {
                try FileManager.default.removeItem(at: tempDir)
                print("✓ Cleaned up temp directory")
            } catch {
                print("⚠️ Warning: Could not clean up temp directory: \(error)")
            }
        }
        
        // Extract the entire archive to temp directory
        print("Preparing to extract archive...")
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: executablePath)
        extractProcess.arguments = [
            "-o", tempDir.path,  // Output directory
            "-f",                 // Force overwrite
            "-q",                 // Quiet mode
            "-D",                 // Don't create subdirectory
            fileURL.path
        ]
        
        print("Command: \(executablePath) \(extractProcess.arguments?.joined(separator: " ") ?? "")")
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        extractProcess.standardOutput = outputPipe
        extractProcess.standardError = errorPipe
        
        do {
            print("Launching unar process...")
            try extractProcess.run()
            print("✓ Process launched, waiting for completion...")
            extractProcess.waitUntilExit()
            
            let terminationStatus = extractProcess.terminationStatus
            print("Process terminated with status: \(terminationStatus)")
            
            if terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                
                print("❌ ERROR: unar failed with status \(terminationStatus)")
                print("Error output: \(errorString)")
                print("Standard output: \(outputString)")
                return nil
            }
            
            print("✓ Archive extracted successfully")
            
            // Find the first image file in the extracted contents
            print("Searching for images in extracted files...")
            let result = findFirstImageInDirectory(tempDir)
            
            if result != nil {
                print("✓ Successfully extracted cover image")
            } else {
                print("❌ Failed to find image in extracted files")
            }
            
            return result
            
        } catch {
            print("❌ ERROR running unar process: \(error)")
            if let posixError = error as? POSIXError {
                print("POSIX Error Code: \(posixError.code)")
            }
            return nil
        }
    }
    
    private static func findUnarPath() -> String? {
        // Common installation paths for unar
        let possiblePaths = [
            "/usr/local/bin/unar",
            "/opt/homebrew/bin/unar",
            "/opt/local/bin/unar",
            "/usr/bin/unar"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try using 'which' command as fallback
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["unar"]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = Pipe()
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            print("Error running which: \(error)")
        }
        
        return nil
    }
    
    private static func findFirstImageInDirectory(_ directory: URL) -> Data? {
        print("Searching for images in: \(directory.path)")
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        
        // Get all files recursively
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ ERROR: Could not create directory enumerator")
            return nil
        }
        
        var imageFiles: [(url: URL, name: String)] = []
        var totalFiles = 0
        
        for case let fileURL as URL in enumerator {
            totalFiles += 1
            let ext = fileURL.pathExtension.lowercased()
            
            if imageExtensions.contains(ext) {
                imageFiles.append((url: fileURL, name: fileURL.lastPathComponent))
                print("  Found image: \(fileURL.lastPathComponent)")
            }
        }
        
        print("Scanned \(totalFiles) total files")
        print("Found \(imageFiles.count) image files")
        
        guard !imageFiles.isEmpty else {
            print("❌ ERROR: No image files found in archive")
            return nil
        }
        
        // Sort by filename to get the first page
        imageFiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        let firstImage = imageFiles[0]
        print("Selected first image: \(firstImage.name)")
        
        do {
            let imageData = try Data(contentsOf: firstImage.url)
            print("✓ SUCCESS: Read \(imageData.count) bytes from \(firstImage.name)")
            
            // Verify it's a valid image by trying to create NSImage
            if let nsImage = NSImage(data: imageData) {
                print("✓ Verified as valid image: \(nsImage.size.width)x\(nsImage.size.height)")
            } else {
                print("⚠️ WARNING: Data loaded but NSImage creation failed")
            }
            
            return imageData
        } catch {
            print("❌ ERROR reading image file: \(error)")
            return nil
        }
    }
    
    private static func extractCoverFromCBZ(_ fileURL: URL) -> Data? {
        print("Starting CBZ extraction...")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ERROR: File does not exist at path: \(fileURL.path)")
            return nil
        }
        
        print("File exists")
        
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
    
    // MARK: - Diagnostics
    
    /// Check if the app is sandboxed
    private static func isAppSandboxed() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    
    /// Check if unar is available and return diagnostic information
    static func checkUnarStatus() -> (available: Bool, path: String?, message: String) {
        let isSandboxed = isAppSandboxed()
        
        if isSandboxed {
            let message = """
            ⚠️ App is running in Sandbox mode
            
            Sandboxed apps cannot execute external processes for security reasons.
            CBR files require the 'unar' command-line tool which cannot be run from a sandboxed app.
            
            To enable CBR support:
            1. Open your Xcode project
            2. Select your app target
            3. Go to "Signing & Capabilities" tab
            4. Remove "App Sandbox" capability
            5. Clean build (Product → Clean Build Folder)
            6. Rebuild and run
            
            CBZ files work fine in sandboxed mode (no external tools needed).
            """
            return (false, nil, message)
        }
        
        if let path = findUnarPath() {
            let isExecutable = FileManager.default.isExecutableFile(atPath: path)
            if isExecutable {
                let message = """
                ✓ unar found and ready
                Location: \(path)
                
                CBR file extraction should work!
                """
                return (true, path, message)
            } else {
                let message = """
                ⚠️ unar found but not executable
                Location: \(path)
                
                Fix with: chmod +x \(path)
                """
                return (false, path, message)
            }
        } else {
            let message = """
            ❌ unar not found. CBR files cannot be processed.
            
            Install unar using Homebrew:
              brew install unar
            
            Or download from:
              https://theunarchiver.com/command-line
            
            After installing, restart this app.
            """
            return (false, nil, message)
        }
    }
    
    static func findComicsInFolder(_ folderURL: URL) -> [URL] {
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
    @State private var showingLibrary = false
    @State private var showingComicDetail: Comic?
    @State private var folderTree: [FolderNode] = []
    @State private var folderAccessURLs: [URL] = [] // Store URLs we have access to
    @State private var showingUnarStatus = false
    @State private var unarStatusMessage = ""
    
    var body: some View {
        NavigationSplitView {
            // Left: Folder tree
            VStack(spacing: 0) {
                HStack {
                    Text("Library Folders")
                        .font(.headline)
                    Spacer()
                    
                    // Check unar status button
                    Button {
                        let status = ComicFileHandler.checkUnarStatus()
                        unarStatusMessage = status.message
                        showingUnarStatus = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .help("Check CBR Support Status")
                    
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
                    Button {
                        showingLibrary = true
                    } label: {
                        Image(systemName: "books.vertical")
                    }
                    .help("View Library (\(comics.count) comics)")
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
                                    deleteComic(comic)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Comics")
        }
        .sheet(item: $showingComicDetail) { comic in
            ComicDetailSheet(comic: comic)
        }
        .sheet(isPresented: $showingLibrary) {
            LibraryViewSheet(comics: comics, modelContext: modelContext, onShowDetails: { comic in
                showingLibrary = false
                showingComicDetail = comic
            })
        }
        .alert("CBR Support Status", isPresented: $showingUnarStatus) {
            Button("OK") { }
            if !ComicFileHandler.checkUnarStatus().available {
                Button("Copy Install Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("brew install unar", forType: .string)
                }
            }
        } message: {
            Text(unarStatusMessage)
        }
    }
    
    private func buildFolderTree() {
        print("=== buildFolderTree called ===")
        folderTree = []
        
        print("Library folders count: \(libraryFolders.count)")
        print("Folder access URLs count: \(folderAccessURLs.count)")
        
        for libraryFolder in libraryFolders {
            print("Processing library folder: \(libraryFolder.name) at \(libraryFolder.path)")
            
            // Try to find matching URL in our access list
            guard let folderURL = folderAccessURLs.first(where: { $0.path == libraryFolder.path }) else {
                print("No access URL found for this folder")
                continue
            }
            
            print("Found access URL, creating root node...")
            let rootNode = FolderNode(url: folderURL)
            print("Loading subfolders...")
            loadSubfolders(for: rootNode)
            print("Root node has \(rootNode.children.count) children")
            folderTree.append(rootNode)
        }
        
        print("Final folder tree count: \(folderTree.count)")
    }
    
    private func loadSubfolders(for node: FolderNode) {
        print("Loading subfolders for: \(node.name)")
        let fileManager = FileManager.default
        
        print("Reading contents of: \(node.url.path)")
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: node.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            print("Found \(contents.count) items")
            
            var foundFolders = 0
            for fileURL in contents {
                print("  Checking item: \(fileURL.lastPathComponent)")
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                      let isDirectory = resourceValues.isDirectory else {
                    print("    Could not get resource values")
                    continue
                }
                
                print("    Is directory: \(isDirectory)")
                
                if isDirectory {
                    foundFolders += 1
                    print("  Found subfolder: \(fileURL.lastPathComponent)")
                    let childNode = FolderNode(url: fileURL)
                    // Recursively load subfolders for this child
                    loadSubfolders(for: childNode)
                    node.children.append(childNode)
                }
            }
            
            print("Total subfolders found in \(node.name): \(foundFolders)")
            node.children.sort { $0.name < $1.name }
            
        } catch {
            print("ERROR reading directory contents: \(error)")
        }
    }
    
    private func handleAddFolder(_ result: Result<URL, Error>) {
        print("=== handleAddFolder called ===")
        switch result {
        case .success(let url):
            print("Selected folder: \(url.path)")
            
            // Start accessing the security-scoped resource
            print("Starting security scoped access...")
            guard url.startAccessingSecurityScopedResource() else {
                print("ERROR: Could not start accessing security scoped resource")
                return
            }
            // Don't call stopAccessing - we need to keep access for the app lifetime
            
            // Check if already added
            print("Checking if folder already exists...")
            print("Current library folders count: \(libraryFolders.count)")
            if libraryFolders.contains(where: { $0.path == url.path }) {
                print("Folder already exists in library")
                return
            }
            
            // Store the URL for access
            folderAccessURLs.append(url)
            
            print("Creating new LibraryFolder object...")
            let folder = LibraryFolder(
                path: url.path,
                name: url.lastPathComponent,
                bookmarkData: nil
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
            
            // Automatically import all comics in the newly added folder and subfolders
            print("Auto-importing comics from newly added folder...")
            autoImportComicsFromFolder(url)
            
        case .failure(let error):
            print("ERROR selecting folder: \(error)")
        }
    }
    
    private func autoImportComicsFromFolder(_ folderURL: URL) {
        print("=== autoImportComicsFromFolder called for: \(folderURL.path) ===")
        
        let fileManager = FileManager.default
        
        // Use a recursive enumerator to get all comics in this folder and subfolders
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("ERROR: Could not create enumerator for folder")
            return
        }
        
        var comicsToImport: [URL] = []
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "cbr" || ext == "cbz" {
                comicsToImport.append(fileURL)
            }
        }
        
        print("Found \(comicsToImport.count) comics to auto-import")
        
        // Import each comic
        for (index, comicURL) in comicsToImport.enumerated() {
            print("Auto-importing [\(index + 1)/\(comicsToImport.count)]: \(comicURL.lastPathComponent)")
            
            // Check if already imported
            if comics.contains(where: { $0.filePath == comicURL.path }) {
                print("  Already imported, skipping")
                continue
            }
            
            let filename = comicURL.deletingPathExtension().lastPathComponent
            let newComic = Comic(
                title: filename,
                series: "",
                issueNumber: "",
                filePath: comicURL.path
            )
            
            // Extract cover (this might take time for CBR files)
            if let coverData = ComicFileHandler.extractCover(from: comicURL) {
                print("  Cover extracted successfully")
                newComic.coverImageData = coverData
            } else {
                print("  Cover extraction failed")
            }
            
            modelContext.insert(newComic)
        }
        
        // Save all imported comics
        do {
            try modelContext.save()
            print("Auto-import completed successfully")
        } catch {
            print("ERROR saving auto-imported comics: \(error)")
        }
    }
    
    private func loadComicsInFolder(_ folder: FolderNode?) {
        print("=== loadComicsInFolder called ===")
        guard let folder = folder else {
            print("No folder selected")
            comicsInFolder = []
            return
        }
        
        print("Loading comics from: \(folder.name) at \(folder.url.path)")
        comicsInFolder = ComicFileHandler.findComicsInFolder(folder.url)
        print("Found \(comicsInFolder.count) comics in folder")
        for comic in comicsInFolder {
            print("  - \(comic.lastPathComponent)")
        }
    }
    
    private func findComicByPath(_ path: String) -> Comic? {
        comics.first(where: { $0.filePath == path })
    }
    
    private func importComic(_ fileURL: URL) {
        print("=== importComic called for: \(fileURL.lastPathComponent) ===")
        
        // Check if already imported
        if comics.contains(where: { $0.filePath == fileURL.path }) {
            print("Already imported, skipping")
            return
        }
        
        let filename = fileURL.deletingPathExtension().lastPathComponent
        print("Creating Comic object with title: \(filename)")
        let newComic = Comic(
            title: filename,
            series: "",
            issueNumber: "",
            filePath: fileURL.path
        )
        
        print("Attempting to extract cover...")
        if let coverData = ComicFileHandler.extractCover(from: fileURL) {
            print("Cover extracted successfully, size: \(coverData.count) bytes")
            newComic.coverImageData = coverData
        } else {
            print("Cover extraction failed or returned nil")
        }
        
        print("Inserting comic into context")
        modelContext.insert(newComic)
        print("Comic inserted")
        
        loadComicsInFolder(selectedFolder)
    }
    
    private func importAllComicsInFolder() {
        print("=== importAllComicsInFolder called ===")
        print("Comics in folder count: \(comicsInFolder.count)")
        for fileURL in comicsInFolder {
            print("Importing: \(fileURL.lastPathComponent)")
            importComic(fileURL)
        }
        print("Import all completed")
    }
    
    private func deleteComic(_ comic: Comic) {
        print("Deleting comic: \(comic.title)")
        modelContext.delete(comic)
        
        // Save the deletion
        do {
            try modelContext.save()
            print("Comic deleted successfully")
        } catch {
            print("ERROR saving after comic deletion: \(error)")
        }
        
        // Reload the current folder to update the list
        loadComicsInFolder(selectedFolder)
    }
    
    private func deleteLibraryFolder(_ node: FolderNode) {
        print("Deleting library folder: \(node.url.path)")
        
        // First, find and delete all comics associated with this folder
        let folderPath = node.url.path
        let comicsToDelete = comics.filter { comic in
            // Check if the comic's file path starts with the folder path
            comic.filePath.hasPrefix(folderPath)
        }
        
        print("Found \(comicsToDelete.count) comics to delete from this folder")
        
        for comic in comicsToDelete {
            print("  Deleting comic: \(comic.title) at \(comic.filePath)")
            modelContext.delete(comic)
        }
        
        // Remove from access URLs
        folderAccessURLs.removeAll(where: { $0.path == node.url.path })
        
        // Find and delete the LibraryFolder from database
        if let folderToDelete = libraryFolders.first(where: { $0.path == node.url.path }) {
            modelContext.delete(folderToDelete)
            print("Deleted folder from database")
        }
        
        // Force save
        do {
            try modelContext.save()
            print("ModelContext saved after delete (deleted folder and \(comicsToDelete.count) comics)")
        } catch {
            print("ERROR saving after delete: \(error)")
        }
        
        // Clear selection and comics list
        selectedFolder = nil
        comicsInFolder = []
        
        // Rebuild tree
        buildFolderTree()
    }
    
    private func clearAllLibraryFolders() {
        print("Clearing all library folders from database...")
        folderAccessURLs.removeAll()
        for folder in libraryFolders {
            modelContext.delete(folder)
        }
        
        // Force save
        do {
            try modelContext.save()
            print("ModelContext saved after clearing all")
        } catch {
            print("ERROR saving after clear: \(error)")
        }
        
        // Clear selection and comics list
        selectedFolder = nil
        comicsInFolder = []
        
        buildFolderTree()
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
        if node.children.isEmpty {
            // No children - just show the folder
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text(node.name)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedFolder = node
            }
            .contextMenu {
                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Remove from Library", systemImage: "trash")
                    }
                }
            }
        } else {
            // Has children - show disclosure group
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

// MARK: - Library View Sheet
struct LibraryViewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let comics: [Comic]
    let modelContext: ModelContext
    let onShowDetails: (Comic) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(comics) { comic in
                    ComicRowView(comic: comic)
                        .onTapGesture {
                            onShowDetails(comic)
                        }
                        .contextMenu {
                            Button {
                                onShowDetails(comic)
                            } label: {
                                Label("Show Details", systemImage: "info.circle")
                            }
                            
                            Button {
                                NSWorkspace.shared.open(URL(fileURLWithPath: comic.filePath))
                            } label: {
                                Label("Open File", systemImage: "book.open")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                modelContext.delete(comic)
                            } label: {
                                Label("Delete from Library", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("Library (\(comics.count) comics)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All") {
                        for comic in comics {
                            modelContext.delete(comic)
                        }
                        dismiss()
                    }
                    .disabled(comics.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
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

