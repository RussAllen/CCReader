//
//  KomgaComicReaderView.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import SwiftUI
import AppKit

struct KomgaComicReaderView: View {
    let book: KomgaBook
    let api: KomgaAPI
    
    @StateObject private var reader: KomgaBookReader
    @State private var currentPage = 0
    @State private var showControls = true
    @State private var autoHideTask: Task<Void, Never>?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    init(book: KomgaBook, api: KomgaAPI) {
        self.book = book
        self.api = api
        _reader = StateObject(wrappedValue: KomgaBookReader(api: api))
        _currentPage = State(initialValue: book.currentPage)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if reader.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    if reader.loadingProgress > 0 {
                        VStack(spacing: 8) {
                            ProgressView(value: reader.loadingProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 200)
                                .tint(.white)
                            
                            Text("\(Int(reader.loadingProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Text("Loading pages...")
                        .foregroundStyle(.white)
                }
            } else if let error = reader.error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    
                    Text("Error Loading Comic")
                        .font(.title2)
                        .foregroundStyle(.white)
                    
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        reader.loadBook(book)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !reader.pages.isEmpty {
                GeometryReader { geometry in
                    ZStack {
                        if currentPage < reader.pages.count {
                            Image(nsImage: reader.pages[currentPage])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(zoomScale)
                                .offset(offset)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            zoomScale = min(max(value, 0.5), 3.0)
                                        }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if zoomScale > 1.0 {
                                                offset = value.translation
                                            }
                                        }
                                        .onEnded { _ in
                                            // Snap back if zoomed out
                                            if zoomScale <= 1.0 {
                                                offset = .zero
                                            }
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    // Double tap to reset zoom
                                    withAnimation(.spring(response: 0.3)) {
                                        zoomScale = 1.0
                                        offset = .zero
                                    }
                                }
                                .onTapGesture {
                                    // Single tap to toggle controls
                                    withAnimation {
                                        showControls.toggle()
                                    }
                                    scheduleAutoHide()
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Controls Overlay
                if showControls {
                    VStack {
                        // Top toolbar
                        HStack {
                            Text(book.displayTitle)
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if book.metadata?.summary != nil {
                                Button(action: {}) {
                                    Image(systemName: "info.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        
                        Spacer()
                        
                        // Bottom controls
                        VStack(spacing: 12) {
                            // Page slider
                            HStack(spacing: 16) {
                                Button(action: previousPage) {
                                    Image(systemName: "chevron.left")
                                }
                                .disabled(currentPage == 0)
                                
                                Slider(
                                    value: Binding(
                                        get: { Double(currentPage) },
                                        set: { changePage(to: Int($0)) }
                                    ),
                                    in: 0...Double(max(0, reader.pages.count - 1)),
                                    step: 1
                                )
                                
                                Button(action: nextPage) {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(currentPage >= reader.pages.count - 1)
                            }
                            
                            // Page counter
                            Text("Page \(currentPage + 1) of \(reader.pages.count)")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationTitle(book.displayTitle)
        .navigationSubtitle(book.seriesTitle ?? "")
        .onAppear {
            reader.loadBook(book)
            scheduleAutoHide()
        }
        .onDisappear {
            autoHideTask?.cancel()
            // Save progress when leaving
            Task {
                await saveProgress()
            }
        }
        .onChange(of: currentPage) { _, _ in
            // Reset zoom when changing pages
            zoomScale = 1.0
            offset = .zero
        }
        .onKeyPress(.leftArrow) {
            previousPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            nextPage()
            return .handled
        }
    }
    
    private func previousPage() {
        guard currentPage > 0 else { return }
        withAnimation {
            currentPage -= 1
        }
        Task {
            await saveProgress()
        }
    }
    
    private func nextPage() {
        guard currentPage < reader.pages.count - 1 else { return }
        withAnimation {
            currentPage += 1
        }
        Task {
            await saveProgress()
        }
    }
    
    private func changePage(to page: Int) {
        currentPage = page
        Task {
            await saveProgress()
        }
    }
    
    private func saveProgress() async {
        let isCompleted = currentPage >= reader.pages.count - 1
        await reader.updateProgress(currentPage: currentPage, completed: isCompleted)
    }
    
    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        
        guard showControls else { return }
        
        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            
            guard !Task.isCancelled else { return }
            
            withAnimation {
                showControls = false
            }
        }
    }
}

#Preview {
    let api = KomgaAPI()
    let book = KomgaBook(
        id: "1",
        seriesId: "1",
        seriesTitle: "Test Series",
        libraryId: "1",
        name: "Test Book",
        url: "",
        number: 1,
        created: nil,
        lastModified: nil,
        fileLastModified: nil,
        sizeBytes: nil,
        size: nil,
        media: KomgaBook.MediaInfo(status: nil, mediaType: nil, pagesCount: 20, comment: nil),
        metadata: nil,
        readProgress: nil
    )
    
    return KomgaComicReaderView(book: book, api: api)
}
