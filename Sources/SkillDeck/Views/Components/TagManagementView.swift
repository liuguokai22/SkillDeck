import SwiftUI

/// TagManagementView provides a dedicated interface to view, create, and delete skill tags.
///
/// Users can see all existing tags, how many skills use each tag, delete tags (with confirmation),
/// and create new tags.
struct TagManagementView: View {

    @Binding var isPresented: Bool
    @Environment(SkillManager.self) private var skillManager
    @Environment(\.localizationBundle) private var localizationBundle
    @Environment(\.locale) private var locale

    @State private var newTagName = ""
    @State private var tagPendingDeletion: String?
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    LText(key: L10nKeys.tagsSectionManageTitle)
                        .appFont(.headline)
                    Text("Tags help categorize skills for quick filtering")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            // Tag list
            if skillManager.knownTags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash")
                        .appFont(.title)
                        .foregroundStyle(.tertiary)
                    LText(key: L10nKeys.tagsEmpty)
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    ForEach(skillManager.knownTags, id: \.self) { tag in
                        let count = skillManager.skills(withTag: tag).count
                        HStack {
                            Text(tag)
                                .appFont(.body)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(count) skills")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)

                            Button(role: .destructive) {
                                tagPendingDeletion = tag
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(L10n.string(L10nKeys.tagsRemoveTag, bundle: localizationBundle, locale: locale))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 150, maxHeight: 250)
            }

            Divider()

            // Create new tag input
            HStack(spacing: 8) {
                TextField(
                    L10n.string(L10nKeys.tagsCreatePlaceholder, bundle: localizationBundle, locale: locale),
                    text: $newTagName
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    createTag()
                }

                Button {
                    createTag()
                } label: {
                    LText(key: L10nKeys.tagsCreateNew)
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 360, maxWidth: 450)
        .alert(
            L10n.string(L10nKeys.tagsRemoveTag, bundle: localizationBundle, locale: locale),
            isPresented: $showDeleteAlert
        ) {
            Button(L10n.string(L10nKeys.commonCancel, bundle: localizationBundle, locale: locale), role: .cancel) {
                tagPendingDeletion = nil
            }
            Button(L10n.string(L10nKeys.commonDelete, bundle: localizationBundle, locale: locale), role: .destructive) {
                if let tag = tagPendingDeletion {
                    Task {
                        await skillManager.deleteKnownTag(tag)
                    }
                }
                tagPendingDeletion = nil
            }
        } message: {
            if let tag = tagPendingDeletion {
                Text(String(format: L10n.string(L10nKeys.tagsDeleteConfirm, bundle: localizationBundle, locale: locale), tag))
            }
        }
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await skillManager.createKnownTag(trimmed)
            newTagName = ""
        }
    }
}
