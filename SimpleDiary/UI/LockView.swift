import Combine
import SwiftUI

struct LockView: View {
    @EnvironmentObject var authGate: AuthGate

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
            Text("Journal Locked")
                .font(.title)
            if let error = authGate.lastError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button {
                authGate.authenticate()
            } label: {
                Label("Unlock", systemImage: "touchid")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Trigger auth once when the lock screen appears
            authGate.authenticate()
        }
    }
}
