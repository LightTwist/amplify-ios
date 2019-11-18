//
// Copyright 2018-2019 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify

class InterpretTextMultiService: MultiServiceBehavior {

    typealias Event = PredictionsEvent<InterpretResult, PredictionsError>
    typealias InterpretTextEventHandler = (Event) -> Void

    var textToInterpret: String?
    weak var coreMLService: CoreMLPredictionBehavior?
    weak var predictionsService: AWSPredictionsService?

    init(coreMLService: CoreMLPredictionBehavior?,
         predictionsService: AWSPredictionsService?) {
        self.coreMLService = coreMLService
        self.predictionsService = predictionsService
    }

    func fetchOnlineResult(callback: @escaping InterpretTextEventHandler) {
        guard let onlineService = predictionsService else {
            let message = PredictionsServiceErrorMessage.onlineInterpretServiceNotAvailable.errorDescription
            let recoveryMessage = PredictionsServiceErrorMessage.onlineInterpretServiceNotAvailable.recoverySuggestion
            let predictionError = PredictionsError.service(message, recoveryMessage, nil)
            callback(.failed(predictionError))
            return
        }
        guard let text = textToInterpret else {
            let message = PredictionsServiceErrorMessage.textNotFoundToInterpret.errorDescription
            let recoveryMessage = PredictionsServiceErrorMessage.textNotFoundToInterpret.recoverySuggestion
            let predictionError = PredictionsError.service(message, recoveryMessage, nil)
            callback(.failed(predictionError))
            return
        }
        onlineService.comprehend(text: text, onEvent: callback)
    }

    func fetchOfflineResult(callback: @escaping InterpretTextEventHandler) {
        guard let offlineService = coreMLService else {
            let message = PredictionsServiceErrorMessage.offlineInterpretServiceNotAvailable.errorDescription
            let recoveryMessage = PredictionsServiceErrorMessage.offlineInterpretServiceNotAvailable.recoverySuggestion
            let predictionError = PredictionsError.service(message, recoveryMessage, nil)
            callback(.failed(predictionError))
            return
        }
        guard let text = textToInterpret else {
            let message = PredictionsServiceErrorMessage.textNotFoundToInterpret.errorDescription
            let recoveryMessage = PredictionsServiceErrorMessage.textNotFoundToInterpret.recoverySuggestion
            let predictionError = PredictionsError.service(message, recoveryMessage, nil)
            callback(.failed(predictionError))
            return
        }
        offlineService.comprehend(text: text, onEvent: callback)
    }

    func setTextToInterpret(text: String) {
        textToInterpret = text
    }

    // MARK: -

    func combineResults(offlineResult: InterpretResult?,
                        onlineResult: InterpretResult?,
                        callback: @escaping  InterpretTextEventHandler) {
        // TODO: Combine logic to be added

    }
}
