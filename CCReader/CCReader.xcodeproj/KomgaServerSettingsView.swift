//
//  KomgaServerSettingsView.swift
//  CCReader
//
//  Created by Russell Allen on 2/11/26.
//

import SwiftUI

struct KomgaServerSettingsView: View {
    @Binding var serverURL: String
    @Binding var username: String
    @Binding var password: String
    @Binding var serverName: String
    @Binding var isPresented: Bool
    
    var onConnect: () -> Void
    
    @State private var showPassword = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server Name", text: $serverName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .help("e.g., http://192.168.1.100:8080 or https://komga.example.com")
                } header: {
                    Text("Server Information")
                } footer: {
                    Text("Enter the complete URL of your Komga server, including http:// or https://")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                        } else {
                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Your credentials are stored locally and used only to connect to your Komga server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Komga")
                            .font(.headline)
                        
                        Text("Komga is a free and open source comics/mangas server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Link("Learn more about Komga", destination: URL(string: "https://komga.org")!)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Komga Server Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        onConnect()
                        isPresented = false
                    }
                    .disabled(serverURL.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    KomgaServerSettingsView(
        serverURL: .constant("http://localhost:8080"),
        username: .constant("user"),
        password: .constant("password"),
        serverName: .constant("My Komga Server"),
        isPresented: .constant(true),
        onConnect: {}
    )
}
