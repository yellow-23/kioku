#if os(macOS)
import SwiftUI

struct UndoToastView: View {
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Nota eliminada")
                .font(.callout)
            Button("Deshacer", action: onUndo)
                .buttonStyle(.plain)
                .font(.callout.bold())
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 6)
    }
}
#endif
