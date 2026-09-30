import AppKit
import SwiftUI

/// ContentView is the root view of the application
///
/// NavigationSplitView is macOS's three-column navigation layout (similar to Apple Mail):
/// - Left column (sidebar): navigation menu
/// - Middle column (content): list
/// - Right column (detail): details
///
/// @Environment retrieves injected objects from the View tree (similar to React's useContext)
/// SkillManager is injected via .environment() in SkillDeckApp.swift
struct ContentView: View {

    @Environment(SkillManager.self) private var skillManager
    @Environment(\.localizationBundle) private var localizationBundle
    @Environment(\.locale) private var locale
    @Environment(\.openSettings) private var openSettings

    @AppStorage(LanguageSettings.appLanguageKey) private var appLanguageRaw: String = LanguageSettings.defaultLanguage.rawValue

    /// Sidebar visibility state for NavigationSplitView
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    /// Currently selected sidebar item
    @State private var selectedSidebarItem: SidebarItem? = .dashboard

    /// Currently selected skill ID (used for navigation to detail page)
    @State private var selectedSkillID: String?

    /// Dashboard ViewModel
    @State private var dashboardVM: DashboardViewModel?

    /// Detail ViewModel
    @State private var detailVM: SkillDetailViewModel?

    /// F09: Registry browser ViewModel
    /// Created alongside other VMs in .task; manages leaderboard browsing and search
    @State private var registryVM: RegistryBrowserViewModel?

    /// Dedicated ClawHub browser ViewModel
    /// Kept separate from the skills.sh registry VM because ClawHub has its own API contract and install flow.
    @State private var clawHubVM: ClawHubBrowserViewModel?

    /// Window-level install sheets keep the toolbar available even while the sidebar is hidden.
    @State private var installVM: SkillInstallViewModel?
    @State private var localImportVM: LocalImportViewModel?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left column: sidebar navigation
            // navigationSplitViewColumnWidth constrains sidebar width range,
            // preventing content from being clipped when sidebar is too narrow after window restoration
            SidebarView(selection: $selectedSidebarItem)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            ZStack {
                // A full-bleed paper surface prevents NavigationSplitView's default material from
                // tinting the middle column gray near safe areas or during column transitions.
                LiquidGlass.Surface.content.ignoresSafeArea()

                Group {
                // Middle column: content varies based on sidebar selection
                // F09: When "Registry" is selected, show RegistryBrowserView instead of DashboardView
                if selectedSidebarItem == .registry {
                    // F09: Registry browser — browse and search skills.sh catalog
                    if let vm = registryVM {
                        RegistryBrowserView(viewModel: vm)
                            // Registry needs wider column for skill info + install buttons
                            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                    }
                } else if selectedSidebarItem == .clawHub {
                    if let vm = clawHubVM {
                        ClawHubBrowserView(viewModel: vm)
                            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                    }
                } else if selectedSidebarItem == .settings {
                    AgentSettingsView()
                        .navigationSplitViewColumnWidth(min: 300, ideal: 450, max: 600)
                } else {
                    // Default: show skill dashboard list
                    if let vm = dashboardVM {
                        DashboardView(viewModel: vm, selectedSkillID: $selectedSkillID)
                            // Constrain middle column (skill list) width range,
                            // preventing content from being squeezed when first opening
                            .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 450)
                    }
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            ZStack {
                // Use the exact same full-bleed surface as the middle column so both reading panes
                // appear white and continuous below the single toolbar divider.
                LiquidGlass.Surface.content.ignoresSafeArea()

                Group {
                // Right column: detail view varies based on sidebar selection
                if selectedSidebarItem == .registry {
                    // F09: Show registry skill detail when a registry skill is selected
                    if let vm = registryVM, let skill = vm.selectedSkill {
                        RegistrySkillDetailView(
                            skill: skill,
                            isInstalled: vm.isInstalled(skill),
                            onInstall: { vm.installSkill(skill) },
                            viewModel: vm
                        )
                    } else {
                        EmptyStateView(
                            icon: "globe",
                            title: L10n.string(L10nKeys.emptySelectSkillTitle, bundle: localizationBundle, locale: locale),
                            subtitle: L10n.string(L10nKeys.emptySelectSkillSubtitleRegistry, bundle: localizationBundle, locale: locale)
                        )
                    }
                } else if selectedSidebarItem == .clawHub {
                    if let vm = clawHubVM, let skill = vm.selectedSkill {
                        ClawHubSkillDetailView(
                            skill: skill,
                            isInstalled: vm.isInstalled(skill),
                            isInstalling: vm.isInstalling(skill),
                            onInstall: { vm.installSkill(skill) },
                            viewModel: vm
                        )
                    } else {
                        EmptyStateView(
                            icon: "shippingbox",
                            title: L10n.string(L10nKeys.emptySelectSkillTitle, bundle: localizationBundle, locale: locale),
                            subtitle: L10n.string(L10nKeys.emptySelectSkillSubtitleClawHub, bundle: localizationBundle, locale: locale)
                        )
                    }
                } else if selectedSidebarItem == .settings {
                    EmptyStateView(
                        icon: "gearshape",
                        title: L10n.string(L10nKeys.sidebarSettings, bundle: localizationBundle, locale: locale),
                        subtitle: L10n.string(L10nKeys.settingsAgentsSectionSubtitle, bundle: localizationBundle, locale: locale)
                    )
                } else if let skillID = selectedSkillID, let vm = detailVM {
                    SkillDetailView(skillID: skillID, viewModel: vm)
                } else {
                    EmptyStateView(
                        icon: "square.stack.3d.up",
                        title: L10n.string(L10nKeys.emptySelectSkillTitle, bundle: localizationBundle, locale: locale),
                        subtitle: L10n.string(L10nKeys.emptySelectSkillSubtitleList, bundle: localizationBundle, locale: locale)
                    )
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // .task executes async task when View first appears (similar to React's useEffect([], ...))
        .task {
            dashboardVM = DashboardViewModel(skillManager: skillManager)
            detailVM = SkillDetailViewModel(skillManager: skillManager)
            // F09: Initialize registry browser ViewModel
            registryVM = RegistryBrowserViewModel(skillManager: skillManager)
            clawHubVM = ClawHubBrowserViewModel(skillManager: skillManager)
            await skillManager.refresh()
            // Auto-check for updates on app launch (subject to 4-hour interval limit, not every launch requests GitHub API)
            await skillManager.checkForAppUpdate()
        }
        // .onChange(of:) triggers closure when specified value changes (similar to React's useEffect with dependency array)
        // When user clicks sidebar navigation item, maps selection to Agent filter and syncs to DashboardViewModel
        // Implements sidebar click → Dashboard list filter linkage effect
        .onChange(of: selectedSidebarItem) { _, newValue in
            dashboardVM?.selectedAgentFilter = newValue?.agentFilter
        }
        .alert(
            item: Binding(
                get: { skillManager.translationPackPrompt },
                set: { skillManager.translationPackPrompt = $0 }
            )
        ) { prompt in
            Alert(
                title: Text(prompt.title),
                message: Text(prompt.message),
                primaryButton: .default(Text("知道了")) {
                    skillManager.dismissTranslationPackPrompt()
                },
                secondaryButton: .default(Text("下次不再提示")) {
                    skillManager.dontShowTranslationPackPromptAgain()
                }
            )
        }
        // The toolbar belongs to the root split view, not to one of its columns. On macOS,
        // WindowToolbarLayout keeps this action cluster at the true window trailing edge.
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                globalToolbarControls

                Color.clear
                    .frame(width: 8, height: 1)
                    .accessibilityHidden(true)

                destinationToolbarControls
            }
        }
        .sheet(item: $installVM, onDismiss: {
            installVM?.cleanup()
            installVM = nil
        }) { vm in
            SkillInstallView(viewModel: vm)
                .environment(skillManager)
        }
        .sheet(item: $localImportVM, onDismiss: {
            localImportVM = nil
        }) { vm in
            LocalImportView(viewModel: vm)
                .environment(skillManager)
        }
        // Keep NavigationSplitView's native sidebar toggle. On macOS 26 it receives the same
        // system Liquid Glass treatment, dynamic Hide/Show label, and split-view animation as Mail.
    }

    private var globalToolbarControls: some View {
        HStack(spacing: 6) {
            if skillManager.appUpdateInfo != nil {
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
                .help(L10n.string(L10nKeys.sidebarHelpUpdateAvailable, bundle: localizationBundle, locale: locale))
            }

            Menu {
                Button {
                    installVM = SkillInstallViewModel(skillManager: skillManager)
                } label: {
                    Label {
                        LText(key: L10nKeys.sidebarInstallFromGitHub)
                    } icon: {
                        Image(systemName: "globe")
                    }
                }

                Button {
                    localImportVM = LocalImportViewModel(skillManager: skillManager)
                } label: {
                    Label {
                        LText(key: L10nKeys.sidebarInstallFromLocalFolder)
                    } icon: {
                        Image(systemName: "folder")
                    }
                }
            } label: {
                Image(systemName: "plus")
            } primaryAction: {
                installVM = SkillInstallViewModel(skillManager: skillManager)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 9)
            .liquidGlassToolbarControl()
            .help(L10n.string(L10nKeys.sidebarHelpInstallSkill, bundle: localizationBundle, locale: locale))

            Button {
                Task { await skillManager.checkAllUpdates() }
            } label: {
                if skillManager.isCheckingUpdates {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(.plain)
            .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
            .help(L10n.string(L10nKeys.sidebarHelpCheckAllUpdates, bundle: localizationBundle, locale: locale))
            .disabled(skillManager.isCheckingUpdates)

            Button {
                Task { await skillManager.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
            .help(L10n.string(L10nKeys.sidebarHelpRefreshSkills, bundle: localizationBundle, locale: locale))
        }
    }

    @ViewBuilder
    private var destinationToolbarControls: some View {
        if selectedSidebarItem == .registry, let viewModel = registryVM {
            HStack(spacing: 6) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
                .help("Refresh registry data")

                Button {
                    if let url = URL(string: "https://skills.sh") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.plain)
                .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
                .help("Open skills.sh in browser")

                LiquidGlassSearchField(text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ), prompt: "Search skills.sh...")
            }
        } else if selectedSidebarItem == .clawHub, let viewModel = clawHubVM {
            HStack(spacing: 6) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
                .help("Refresh ClawHub results")

                Button {
                    if let url = URL(string: "https://clawhub.ai") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.plain)
                .liquidGlassToolbarControl(width: LiquidGlass.Metrics.toolbarControlHeight)
                .help("Open ClawHub in browser")

                LiquidGlassSearchField(text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ), prompt: "Search ClawHub skills...")
            }
        } else if selectedSidebarItem != .settings, let viewModel = dashboardVM {
            HStack(spacing: 10) {
                Menu {
                    Button {
                        appLanguageRaw = AppLanguage.system.rawValue
                    } label: {
                        LText(key: L10nKeys.settingsLanguageSystemDefault)
                    }

                    Button {
                        appLanguageRaw = AppLanguage.english.rawValue
                    } label: {
                        LText(key: L10nKeys.settingsLanguageEnglish)
                    }

                    Button {
                        appLanguageRaw = AppLanguage.simplifiedChinese.rawValue
                    } label: {
                        LText(key: L10nKeys.settingsLanguageChineseHans)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text(languageBadge)
                            .appFont(.caption2)
                            .monospaced()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .liquidGlassToolbarControl(width: LiquidGlass.Metrics.languageControlWidth)
                .help(L10n.string(L10nKeys.dashboardLanguageMenuHelp, bundle: localizationBundle, locale: locale))

                LiquidGlassSearchField(text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ), prompt: "Search skills...")
            }
        }
    }

    private var languageBadge: String {
        switch AppLanguage(storedRawValue: appLanguageRaw) {
        case .system: "Auto"
        case .english: "EN"
        case .simplifiedChinese: "中"
        }
    }
}
