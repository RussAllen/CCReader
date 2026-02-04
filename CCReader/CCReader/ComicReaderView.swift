//
//  ComicReaderView.swift
//  CCReader
//
//  Created by Russell Allen on 2/4/26.
//

import SwiftUI
import SwiftData

struct ComicReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var archiveReader = ComicArchiveReader()
    @State private var currentPage = 0
    @State private var showingControls = true
    
    let comicBook: ComicBook
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if archiveReader.isLoading {
                ProgressView("Loading comic...")
                    .foregroundStyle(.white)
            } else if let error = archiveReader.error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if !archiveReader.pages.isEmpty {
                // Comic page display
                GeometryReader { geometry in
                    Image(nsImage: archiveReader.pages[currentPage])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            withAnimation {
                                showingControls.toggle()
                            }
                        }
                }
                
                // Navigation controls
                if showingControls {
                    VStack {
                        // Top bar
                        HStack {
                            Text(comicBook.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("Page \(currentPage + 1) of \(archiveReader.pages.count)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        
                        Spacer()
                        
                        // Bottom controls
                        HStack(spacing: 30) {
                            Button {
                                goToFirstPage()
                            } label: {
                                Image(systemName: "backward.end.fill")
                                    .font(.title2)
                            }
                            .disabled(currentPage == 0)
                            
                            Button {
                                previousPage()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title)
                            }
                            .disabled(currentPage == 0)
                            .keyboardShortcut(.leftArrow, modifiers: [])
                            
                            Button {
                                nextPage()
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title)
                            }
                            .disabled(currentPage >= archiveReader.pages.count - 1)
                            .keyboardShortcut(.rightArrow, modifiers: [])
                            
                            Button {
                                goToLastPage()
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.title2)
                            }
                            .disabled(currentPage >= archiveReader.pages.count - 1)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 30)
                    }
                    .transition(.opacity)
                }
            } else {
                Text("No pages loaded")
                    .foregroundStyle(.white)
            }
        }
        .task {
            await archiveReader.loadArchive(from: comicBook.fileURL)
            currentPage = comicBook.currentPage
        }
        .onDisappear {
            // Save current page when leaving
            comicBook.currentPage = currentPage
            comicBook.totalPages = archiveReader.pages.count
            comicBook.lastOpenedDate = Date()
        }
    }
    
    private func nextPage() {
        if currentPage < archiveReader.pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        }
    }
    
    private func previousPage() {
        if currentPage > 0 {
            withAnimation {
                currentPage -= 1
            }
        }
    }
    
    private func goToFirstPage() {
        withAnimation {
            currentPage = 0
        }
    }
    
    private func goToLastPage() {
        withAnimation {
            currentPage = archiveReader.pages.count - 1
        }
    }
}

#Preview {
    ComicReaderView(comicBook: ComicBook(
        title: "Sample Comic",
        fileURL: URL(fileURLWithPath: "/path/to/comic.cbz"),
        currentPage: 0,
        totalPages: 10
    ))
    .modelContainer(for: ComicBook.self, inMemory: true)
}
