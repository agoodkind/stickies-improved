import StickiesImprovedCore
import SwiftUI

struct PlainTextEditorView: View {
    @Environment(NoteWorkspaceStore.self) private var workspace

    let noteID: NoteID

    var body: some View {
        VStack(spacing: 0) {
            header

            TextEditor(text: workspace.binding(for: noteID))
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .padding(.top, 6)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .background(stickyBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.displayTitle(for: noteID))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("Plain text")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.white.opacity(0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 36)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        }
    }

    private var stickyBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.97, blue: 0.70),
                Color(red: 0.98, green: 0.92, blue: 0.55),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
