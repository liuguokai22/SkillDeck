import Foundation

enum L10nKeys {
    static let appName = "app.name"

    static let settingsTabGeneral = "settings.tab.general"
    static let settingsTabProxy = "settings.tab.proxy"

    static let settingsTabAbout = "settings.tab.about"

    static let settingsProxySectionEnable = "settings.proxy.section.enable"
    static let settingsProxyEnableProxy = "settings.proxy.enableProxy"

    static let settingsProxySectionServer = "settings.proxy.section.server"
    static let settingsProxyImportFromEnvironment = "settings.proxy.importFromEnvironment"
    static let settingsProxyFieldTypeLabel = "settings.proxy.field.type.label"
    static let settingsProxyFieldTypeHint = "settings.proxy.field.type.hint"
    static let settingsProxyFieldHostLabel = "settings.proxy.field.host.label"
    static let settingsProxyFieldHostHint = "settings.proxy.field.host.hint"
    static let settingsProxyFieldPortLabel = "settings.proxy.field.port.label"
    static let settingsProxyFieldPortHint = "settings.proxy.field.port.hint"
    static let settingsProxyValidationInvalidHostPort = "settings.proxy.validation.invalidHostPort"

    static let settingsProxySectionAuthentication = "settings.proxy.section.authentication"
    static let settingsProxyEnableAuthentication = "settings.proxy.enableAuthentication"
    static let settingsProxyFieldUsernameLabel = "settings.proxy.field.username.label"
    static let settingsProxyFieldUsernameHint = "settings.proxy.field.username.hint"
    static let settingsProxyFieldPasswordLabel = "settings.proxy.field.password.label"
    static let settingsProxyFieldPasswordHint = "settings.proxy.field.password.hint"
    static let settingsProxySavePassword = "settings.proxy.savePassword"
    static let settingsProxyClearPassword = "settings.proxy.clearPassword"

    static let settingsProxySectionBypass = "settings.proxy.section.bypass"
    static let settingsProxyBypassDescription = "settings.proxy.bypass.description"
    static let settingsProxyBypassExamples = "settings.proxy.bypass.examples"

    static let settingsProxyStatusImportNoneFound = "settings.proxy.status.import.noneFound"
    static let settingsProxyStatusImportImported = "settings.proxy.status.import.imported"
    static let settingsProxyStatusImportImportedPasswordSaveFailed = "settings.proxy.status.import.importedPasswordSaveFailed"

    static let settingsProxyStatusPasswordSaved = "settings.proxy.status.password.saved"
    static let settingsProxyStatusPasswordSaveFailed = "settings.proxy.status.password.saveFailed"
    static let settingsProxyStatusPasswordCleared = "settings.proxy.status.password.cleared"
    static let settingsProxyStatusPasswordClearFailed = "settings.proxy.status.password.clearFailed"

    static let settingsSectionPaths = "settings.section.paths"
    static let settingsSectionPathsSharedSkills = "settings.section.paths.sharedSkills"
    static let settingsSectionPathsLockFile = "settings.section.paths.lockFile"

    static let settingsSectionLanguage = "settings.section.language"
    static let settingsLanguageAppLanguage = "settings.language.appLanguage"
    static let settingsLanguageSystemDefault = "settings.language.systemDefault"
    static let settingsLanguageEnglish = "settings.language.english"
    static let settingsLanguageChineseHans = "settings.language.chineseHans"

    static let settingsSectionFont = "settings.section.font"
    static let settingsFontFamily = "settings.font.family"
    static let settingsFontSize = "settings.font.size"
    static let settingsFontPreviewSentence = "settings.font.previewSentence"

    static let settingsAboutAppName = "settings.about.appName"
    static let settingsAboutTagline = "settings.about.tagline"
    static let settingsAboutGitHub = "settings.about.github"

    static let settingsUpdateChecking = "settings.update.checking"
    static let settingsUpdateDownloading = "settings.update.downloading"
    static let settingsUpdateRetry = "settings.update.retry"
    static let settingsUpdateAvailablePrefix = "settings.update.availablePrefix"
    static let settingsUpdateNow = "settings.update.now"
    static let settingsUpdateViewOnGitHub = "settings.update.viewOnGitHub"
    static let settingsUpdateCheckForUpdates = "settings.update.checkForUpdates"

    static let sidebarSectionOverview = "sidebar.section.overview"
    static let sidebarSectionAgents = "sidebar.section.agents"
    static let sidebarDashboard = "sidebar.dashboard"
    static let sidebarRegistry = "sidebar.registry"
    static let sidebarClawHub = "sidebar.clawhub"
    static let sidebarHelpUpdateAvailable = "sidebar.help.updateAvailable"
    static let sidebarInstallFromGitHub = "sidebar.install.fromGitHub"
    static let sidebarInstallFromLocalFolder = "sidebar.install.fromLocalFolder"
    static let sidebarHelpInstallSkill = "sidebar.help.installSkill"
    static let sidebarHelpCheckAllUpdates = "sidebar.help.checkAllUpdates"
    static let sidebarHelpRefreshSkills = "sidebar.help.refreshSkills"
    static let sidebarHelpShow = "sidebar.help.show"
    static let sidebarHelpHide = "sidebar.help.hide"

    static let emptySelectSkillTitle = "empty.selectSkill.title"
    static let emptySelectSkillSubtitleList = "empty.selectSkill.subtitle.list"
    static let emptySelectSkillSubtitleRegistry = "empty.selectSkill.subtitle.registry"
    static let emptySelectSkillSubtitleClawHub = "empty.selectSkill.subtitle.clawhub"

    static let dashboardLanguageMenuLabel = "dashboard.language.menuLabel"
    static let dashboardLanguageMenuHelp = "dashboard.language.menuHelp"

    static let usageSectionTitle = "usage.section.title"
    static let usageScanAction = "usage.scan.action"
    static let usageNotScanned = "usage.notScanned"
    static let usageScanning = "usage.scanning"
    static let usageDetectedCalls = "usage.detectedCalls"
    static let usageLastUsed = "usage.lastUsed"
    static let usageNeverDetected = "usage.neverDetected"
    static let usageUnavailable = "usage.unavailable"
    static let usageSource = "usage.source"
    static let usageSourceCodex = "usage.source.codex"
    static let usageCaveat = "usage.caveat"
    static let usageRefreshHelp = "usage.refresh.help"
    static let usageIncompleteHelp = "usage.incomplete.help"

    static let documentationSectionTitle = "documentation.section.title"
    static let agentAssignmentTitle = "agentAssignment.title"
    static let agentAssignmentSummary = "agentAssignment.summary"
    static let agentAssignmentManage = "agentAssignment.manage"
    static let agentAssignmentNone = "agentAssignment.none"

    static let tagsSectionTitle = "tags.section.title"
    static let tagsAddTag = "tags.add"
    static let tagsRemoveTag = "tags.remove"
    static let tagsManage = "tags.manage"
    static let tagsFilterAll = "tags.filter.all"
    static let tagsCreateNew = "tags.create.new"
    static let tagsCreatePlaceholder = "tags.create.placeholder"
    static let tagsEmpty = "tags.empty"
    static let tagsSectionManageTitle = "tags.section.manage.title"
    static let tagsDeleteConfirm = "tags.delete.confirm"

    static let sidebarSettings = "sidebar.settings"
    static let settingsTabAgents = "settings.tab.agents"
    static let settingsAgentsSectionTitle = "settings.agents.section.title"
    static let settingsAgentsSectionSubtitle = "settings.agents.section.subtitle"
    static let settingsAgentsShowAll = "settings.agents.showAll"
    static let settingsAgentsShowInstalledOnly = "settings.agents.showInstalledOnly"
    static let settingsAgentsInstalledBadge = "settings.agents.installed"
    static let settingsAgentsNotInstalledBadge = "settings.agents.notInstalled"
    static let settingsAgentsHideAction = "settings.agents.hideAction"
    static let settingsAgentsShowAction = "settings.agents.showAction"
    static let commonCancel = "common.cancel"
    static let commonDelete = "common.delete"
    static let commonClose = "common.close"

    static let allKeys: [String] = [
        appName,
        settingsTabGeneral,
        settingsTabProxy,
        settingsTabAbout,
        settingsProxySectionEnable,
        settingsProxyEnableProxy,
        settingsProxySectionServer,
        settingsProxyImportFromEnvironment,
        settingsProxyFieldTypeLabel,
        settingsProxyFieldTypeHint,
        settingsProxyFieldHostLabel,
        settingsProxyFieldHostHint,
        settingsProxyFieldPortLabel,
        settingsProxyFieldPortHint,
        settingsProxyValidationInvalidHostPort,
        settingsProxySectionAuthentication,
        settingsProxyEnableAuthentication,
        settingsProxyFieldUsernameLabel,
        settingsProxyFieldUsernameHint,
        settingsProxyFieldPasswordLabel,
        settingsProxyFieldPasswordHint,
        settingsProxySavePassword,
        settingsProxyClearPassword,
        settingsProxySectionBypass,
        settingsProxyBypassDescription,
        settingsProxyBypassExamples,
        settingsProxyStatusImportNoneFound,
        settingsProxyStatusImportImported,
        settingsProxyStatusImportImportedPasswordSaveFailed,
        settingsProxyStatusPasswordSaved,
        settingsProxyStatusPasswordSaveFailed,
        settingsProxyStatusPasswordCleared,
        settingsProxyStatusPasswordClearFailed,
        settingsSectionPaths,
        settingsSectionPathsSharedSkills,
        settingsSectionPathsLockFile,
        settingsSectionLanguage,
        settingsLanguageAppLanguage,
        settingsLanguageSystemDefault,
        settingsLanguageEnglish,
        settingsLanguageChineseHans,
        settingsSectionFont,
        settingsFontFamily,
        settingsFontSize,
        settingsFontPreviewSentence,
        settingsAboutAppName,
        settingsAboutTagline,
        settingsAboutGitHub,
        settingsUpdateChecking,
        settingsUpdateDownloading,
        settingsUpdateRetry,
        settingsUpdateAvailablePrefix,
        settingsUpdateNow,
        settingsUpdateViewOnGitHub,
        settingsUpdateCheckForUpdates,
        sidebarSectionOverview,
        sidebarSectionAgents,
        sidebarDashboard,
        sidebarRegistry,
        sidebarClawHub,
        sidebarHelpUpdateAvailable,
        sidebarInstallFromGitHub,
        sidebarInstallFromLocalFolder,
        sidebarHelpInstallSkill,
        sidebarHelpCheckAllUpdates,
        sidebarHelpRefreshSkills,
        sidebarHelpShow,
        sidebarHelpHide,
        emptySelectSkillTitle,
        emptySelectSkillSubtitleList,
        emptySelectSkillSubtitleRegistry,
        emptySelectSkillSubtitleClawHub,
        dashboardLanguageMenuLabel,
        dashboardLanguageMenuHelp,
        usageSectionTitle,
        usageScanAction,
        usageNotScanned,
        usageScanning,
        usageDetectedCalls,
        usageLastUsed,
        usageNeverDetected,
        usageUnavailable,
        usageSource,
        usageSourceCodex,
        usageCaveat,
        usageRefreshHelp,
        usageIncompleteHelp,
        documentationSectionTitle,
        agentAssignmentTitle,
        agentAssignmentSummary,
        agentAssignmentManage,
        agentAssignmentNone,
        tagsSectionTitle,
        tagsAddTag,
        tagsRemoveTag,
        tagsManage,
        tagsFilterAll,
        tagsCreateNew,
        tagsCreatePlaceholder,
        tagsEmpty,
        tagsSectionManageTitle,
        tagsDeleteConfirm,
        sidebarSettings,
        settingsTabAgents,
        settingsAgentsSectionTitle,
        settingsAgentsSectionSubtitle,
        settingsAgentsShowAll,
        settingsAgentsShowInstalledOnly,
        settingsAgentsInstalledBadge,
        settingsAgentsNotInstalledBadge,
        settingsAgentsHideAction,
        settingsAgentsShowAction,
        commonCancel,
        commonDelete,
        commonClose,
    ]
}
