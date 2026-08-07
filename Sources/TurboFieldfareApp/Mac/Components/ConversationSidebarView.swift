import AppKit
import SwiftUI
import TurboFieldfareAppCore
import TurboFieldfareMacPresentation
import UniformTypeIdentifiers

/// Lists saved conversations. Selecting one loads its turns as history, so the
/// transcript shows the whole thing and the next prompt continues it.
struct ConversationSidebarView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.conversations.isEmpty {
                empty
            } else {
                list
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.refreshConversations() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Conversations")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                model.startNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .help("New conversation")
            .disabled(model.isRunning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var empty: some View {
        VStack {
            Spacer()
            Text("No saved conversations")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(model.conversations) { record in
                    row(record)
                }
            }
            .padding(8)
        }
    }

    private func row(_ record: ConversationRecord) -> some View {
        let isCurrent = record.id == model.currentConversationID
        return Button {
            model.openConversation(record.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.callout)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(
                    isCurrent
                        ? TurboFieldfareMacTheme.accentColor.opacity(0.18)
                        : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning)
        .contextMenu {
            Button("Export as Markdown\u{2026}") { export(record) }
            Divider()
            Button("Delete", role: .destructive) {
                model.deleteConversation(record.id)
            }
        }
    }

    private func export(_ record: ConversationRecord) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue =
            record.title.replacingOccurrences(of: "/", with: "-") + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? record.markdown.write(to: url, atomically: true, encoding: .utf8)
    }
}
