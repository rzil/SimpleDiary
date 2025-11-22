//
//  ForceResetPasswordView.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import SwiftUI

struct ForceResetPasswordView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Force Reset Master Password")
                .font(.title2)
            
            Text("You are currently unlocked (e.g. via biometrics). This will set a NEW master password without verifying the old one. Make sure you remember it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            SecureField("New password", text: $newPassword)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Confirm new password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Reset") {
                    performReset()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 420)
    }
    
    private func performReset() {
        errorMessage = nil
        
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match."
            return
        }
        
        let new = newPassword
        newPassword = ""
        confirmPassword = ""
        
        do {
            try appState.forceSetNewMasterPassword(newPassword: new)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
