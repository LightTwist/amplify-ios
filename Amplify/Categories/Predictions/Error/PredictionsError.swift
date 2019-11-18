//
// Copyright 2018-2019 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Error occured while using Prediction category
public enum PredictionsError {

    /// Access denied while executing the operation
    case accessDenied(ErrorDescription, RecoverySuggestion, Error? = nil)
    case auth(ErrorDescription, RecoverySuggestion, Error? = nil)
    case configuration(ErrorDescription, RecoverySuggestion, Error? = nil)
    case httpStatus(Int, RecoverySuggestion, Error? = nil)
    case network(ErrorDescription, RecoverySuggestion, Error? = nil)
    case service(ErrorDescription, RecoverySuggestion, Error? = nil)
    case unknown(ErrorDescription, RecoverySuggestion, Error? = nil)
}

extension PredictionsError: AmplifyError {
    public var errorDescription: ErrorDescription {
        switch self {
        case .accessDenied(let errorDescription, _, _),
             .auth(let errorDescription, _, _),
             .service(let errorDescription, _, _),
             .configuration(let errorDescription, _, _):
            return errorDescription
        case .unknown(let errorDescription, _, _):
            return "Unexpected error occurred with message: \(errorDescription)"
        case .network(let errorDescription, _, _):
            return "Network error occurred with message:\(errorDescription)"
        case .httpStatus(let statusCode, _, _):
            return "The HTTP response status code is [\(statusCode)]."
        }

    }

    public var recoverySuggestion: RecoverySuggestion {
        switch self {
        case .accessDenied(_, let recoverySuggestion, _),
             .auth(_, let recoverySuggestion, _),
             .configuration(_, let recoverySuggestion, _),
             .service( _, let recoverySuggestion, _),
             .network(_, let recoverySuggestion, _):
            return recoverySuggestion

        case .httpStatus(_, let recoverySuggestion, _):
            return """
            \(recoverySuggestion).
            For more information on HTTP status codes, take a look at
            https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
            """
        case .unknown:
            return """
            This should never happen. There is a possibility that there is a bug if this error persists.
            Please take a look at https://github.com/aws-amplify/amplify-ios/issues to see if there are any
            existing issues that match your scenario, and file an issue with the details of the bug if there isn't.
            """
        }
    }

    public var underlyingError: Error? {
        switch self {
        case .accessDenied(_, _, let underlyingError),
             .auth(_, _, let underlyingError),
             .configuration(_, _, let underlyingError),
             .httpStatus(_, _, let underlyingError),
             .network(_, _, let underlyingError),
             .service(_, _, let underlyingError),
             .unknown(_, _, let underlyingError):
            return underlyingError
        }
    }
}
