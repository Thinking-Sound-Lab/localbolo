import Observation

/// The app's composition root: creates every long-lived service once and wires
/// them together. SwiftUI views receive it through the environment.
@Observable
final class AppModel {
    let settings: AppSettings
    let permissions: PermissionsMonitor
    let speechModels: SpeechModelStore
    let cleanup: TranscriptCleanup
    let dictation: DictationController

    @ObservationIgnored private let pill: PillController

    init() {
        let settings = AppSettings()
        let permissions = PermissionsMonitor()
        let speechModels = SpeechModelStore()
        let cleanup = TranscriptCleanup(settings: settings, models: CleanupModelStore())
        let dictation = DictationController(
            speechModels: speechModels,
            cleanup: cleanup,
            permissions: permissions,
            inserter: TextInserter(settings: settings)
        )

        self.settings = settings
        self.permissions = permissions
        self.speechModels = speechModels
        self.cleanup = cleanup
        self.dictation = dictation
        self.pill = PillController(dictation: dictation, settings: settings)
    }

    /// True until every permission is granted and a speech model is on disk.
    var needsSetup: Bool {
        !permissions.allGranted || !speechModels.isInstalled(speechModels.activeModel)
    }

    func start() {
        permissions.startMonitoring()
        dictation.start()
        pill.start()
        speechModels.loadActiveModelIfInstalled()
        cleanup.start()
    }
}
