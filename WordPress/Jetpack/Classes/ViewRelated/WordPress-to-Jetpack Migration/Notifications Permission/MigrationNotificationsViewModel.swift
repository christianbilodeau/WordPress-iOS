import Foundation

class MigrationNotificationsViewModel {

    let configuration: MigrationStepConfiguration

    init(coordinator: MigrationFlowCoordinator) {

        let headerConfiguration = MigrationHeaderConfiguration(step: .notifications)

        let actionsConfiguration = MigrationActionsViewConfiguration(step: .notifications,
                                                                     primaryHandler: {},
                                                                     secondaryHandler: { [weak coordinator] in
                                                                                            coordinator?.transitionToNextStep()
                                                                                        })

        configuration = MigrationStepConfiguration(headerConfiguration: headerConfiguration, actionsConfiguration: actionsConfiguration)
    }
}
