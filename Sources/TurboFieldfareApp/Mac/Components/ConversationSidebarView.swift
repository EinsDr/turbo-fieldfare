import AppKit
import SwiftUI
import TurboFieldfareAppCore
import TurboFieldfareMacPresentation
import UniformTypeIdentifiers

/// Lists saved conversations. Selecting one loads its turns as history, so the
/// transcript shows the whole thing and the next prompt continues it.
struct ConversationSidebarView: View {
    let model: AppModel
    @State private var selection: UUID?

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
        .onAppear {
            model.refreshConversations()
            selection = model.currentConversationID
        }
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
        List(selection: $selection) {
            ForEach(model.conversations) { record in
                rowLabel(record)
                    .tag(record.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            model.deleteConversation(record.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button("Export as Markdown\u{2026}") { export(record) }
                        Divider()
                        Button("Delete", role: .destructive) {
                            model.deleteConversation(record.id)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .disabled(model.isRunning)
        .onChange(of: selection) { _, newValue in
            guard let newValue, newValue != model.currentConversationID else { return }
            model.openConversation(newValue)
        }
        .onChange(of: model.currentConversationID) { _, newValue in
            selection = newValue
        }
    }

    /// Plain label rather than a Button: controls inside a List row compete
    /// with the swipe gesture, so selection drives opening instead.
    private func rowLabel(_ record: ConversationRecord) -> some View {
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
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
