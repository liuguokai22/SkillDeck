import SwiftUI

/// DashboardView is the skill list page (F02)
///
/// Displays all installed skills, supporting search, filtering, and sorting
struct DashboardView: View {

    /// @Bindable allows @Observable object properties to be prefixed with $ to create Binding
    /// For example, $viewModel.searchText creates a Binding<String>
    @Bindable var viewModel: DashboardViewModel
    @Binding var selectedSkillID: String?
    @Environment(SkillManager.self) private var skillManager

    @Environment(\.localizationBundle) private var localizationBundle
    @Environment(\.locale) private var locale

    @State private var tagPendingDeletion: String?
    @State private var showDeleteTagAlert = false
    @State private var showManageTagsSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Column-local controls keep sorting and tag filtering aligned with the skill list.
            // They no longer intrude into the sidebar portion of the unified window toolbar.
            dashboardControlBar

            Group {
                if skillManager.isLoading && skillManager.skills.isEmpty {
                    // Show progress indicator on first load
                    ProgressView("Scanning skills...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredSkills.isEmpty {
                    // Empty state
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Skills Found",
                        subtitle: viewModel.searchText.isEmpty
                            ? "Install skills using npx skills add or the CLI"
                            : "No skills match your search"
                    )
                } else {
                    // Skill list
                    List(viewModel.filteredSkills, selection: $selectedSkillID) { skill in
                        SkillRowView(skill: skill)
                            .tag(skill.id)
                            // contextMenu is macOS's right-click menu
                            .contextMenu {
                                Button("Open in Finder") {
                                    NSWorkspace.shared.selectFile(
                                        nil,
                                        inFileViewerRootedAtPath: skill.canonicalURL.path
                                    )
                                }
                                Divider()  // Menu separator
                                Button("Delete", role: .destructive) {
                                    viewModel.requestDelete(skill: skill)
                                }
                            }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .scrollContentBackground(.hidden)
                    .background(LiquidGlass.Surface.content)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiquidGlass.Surface.content)
        .navigationTitle(navigationTitle)
        // Delete confirmation dialog
        // .alert similar to Android's AlertDialog or Web's confirm()
        .alert("Delete Skill", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
        } message: {
            if let skill = viewModel.skillToDelete {
                Text("Are you sure you want to delete \"\(skill.displayName)\"? This will remove the skill directory and all symlinks. This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showManageTagsSheet) {
            TagManagementView(isPresented: $showManageTagsSheet)
                .environment(skillManager)
        }
        .alert(
            L10n.string(L10nKeys.tagsRemoveTag, bundle: localizationBundle, locale: locale),
            isPresented: $showDeleteTagAlert
        ) {
            Button(L10n.string(L10nKeys.commonCancel, bundle: localizationBundle, locale: locale), role: .cancel) {
                tagPendingDeletion = nil
            }
            Button(L10n.string(L10nKeys.commonDelete, bundle: localizationBundle, locale: locale), role: .destructive) {
                if let tag = tagPendingDeletion {
                    Task {
                        if viewModel.selectedTagFilter == tag {
                            viewModel.selectedTagFilter = nil
                        }
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
        // Error message
        .overlay(alignment: .bottom) {
            if let error = skillManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                    Spacer()
                    Button("Dismiss") {
                        skillManager.errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(.red.opacity(0.1))
                .cornerRadius(8)
                .padding()
            }
        }
    }

    private var navigationTitle: String {
        if let agent = viewModel.selectedAgentFilter {
            return agent.displayName
        }
        return "All Skills"
    }

    // MARK: - Dashboard Controls

    /// Column-local filter and sort controls.
    ///
    /// The horizontal tag list can scroll when labels are long, while the sort menu remains
    /// reachable at the trailing edge. All controls use the same native Liquid Glass hierarchy.
    private var dashboardControlBar: some View {
        HStack(spacing: 8) {
            if !skillManager.knownTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LiquidGlassGroup(spacing: 4) {
                        HStack(spacing: 6) {
                    // "All" chip — clears the tag filter
                    tagChip(
                        label: L10n.string(L10nKeys.tagsFilterAll, bundle: localizationBundle, locale: locale),
                        isSelected: viewModel.selectedTagFilter == nil,
                        color: .accentColor
                    ) {
                        viewModel.selectedTagFilter = nil
                    }

                    // One chip per known tag
                    ForEach(skillManager.knownTags, id: \.self) { tag in
                        tagChip(
                            label: tag,
                            isSelected: viewModel.selectedTagFilter == tag,
                            color: .accentColor
                        ) {
                            if viewModel.selectedTagFilter == tag {
                                // Clicking the currently selected tag deselects it
                                viewModel.selectedTagFilter = nil
                            } else {
                                viewModel.selectedTagFilter = tag
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                tagPendingDeletion = tag
                                showDeleteTagAlert = true
                            } label: {
                                Label(
                                    L10n.string(L10nKeys.tagsRemoveTag, bundle: localizationBundle, locale: locale),
                                    systemImage: "trash"
                                )
                            }
                        }
                    }

                            // Manage tags button
                            Button {
                                showManageTagsSheet = true
                            } label: {
                                Image(systemName: "tag")
                                    .appFont(.caption)
                                    .frame(width: 14, height: 14)
                                    .padding(.horizontal, 12)
                                    .frame(height: LiquidGlass.Metrics.filterControlHeight)
                                    .liquidGlassControl()
                            }
                            .buttonStyle(.plain)
                            .help(L10n.string(L10nKeys.tagsManage, bundle: localizationBundle, locale: locale))
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            sortMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // The filter strip belongs to navigation chrome rather than list content. A system bar
        // material keeps it connected to the split view while the controls use native glass.
        .background(LiquidGlass.Surface.content)
        .overlay(
            Divider().opacity(0.3),
            alignment: .bottom
        )
    }

    /// Sort menu moved from the unified toolbar into the middle column to avoid crossing the
    /// sidebar/content divider at narrow window widths.
    private var sortMenu: some View {
        Menu {
            Section("Sort By") {
                ForEach(DashboardViewModel.SortOrder.allCases, id: \.self) { order in
                    Button {
                        if viewModel.sortOrder == order {
                            viewModel.sortDirection = viewModel.sortDirection.toggled
                        } else {
                            viewModel.sortOrder = order
                            viewModel.sortDirection = .ascending
                        }
                    } label: {
                        HStack {
                            Label(order.rawValue, systemImage: order.iconName)
                            if viewModel.sortOrder == order {
                                Spacer()
                                Image(systemName: viewModel.sortDirection.iconName)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .appFont(.caption)
                .frame(width: 14, height: 14)
                .padding(.horizontal, 12)
                .frame(height: LiquidGlass.Metrics.filterControlHeight)
                .liquidGlassControl()
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Sort by \(viewModel.sortOrder.rawValue), \(viewModel.sortDirection.displayName)")
        .accessibilityLabel("Sort skills by \(viewModel.sortOrder.rawValue)")
    }

    /// Reusable tag chip button with Liquid Glass styling
    /// - Parameters:
    ///   - label: Text displayed on the chip
    ///   - isSelected: Whether this chip is currently selected (uses filled style)
    ///   - color: Accent color for the chip
    ///   - action: Action when the chip is tapped
    @ViewBuilder
    private func tagChip(label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .appFont(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .frame(height: LiquidGlass.Metrics.filterControlHeight)
                .foregroundStyle(isSelected ? color : .secondary)
                .liquidGlassControl(tint: isSelected ? color.opacity(0.28) : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

}
