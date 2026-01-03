//
//  ChangePasswordView.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var appState: DiaryAppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Change Master Password")
                .font(.title2)
            
            SecureField("Current password", text: $currentPassword)
                .textFieldStyle(.roundedBorder)
            
            SecureField("New password", text: $newPassword)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Confirm new password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            if let success = successMessage {
                Text(success)
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Change") {
                    changePassword()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 420)
    }
    
    private func changePassword() {
        errorMessage = nil
        successMessage = nil
        
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match."
            return
        }
        
        let old = currentPassword
        let new = newPassword
        
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        
        do {
            try appState.changePassword(currentPassword: old, newPassword: new)
            successMessage = "Master password updated."
            // You can auto-dismiss after a delay if you like
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
