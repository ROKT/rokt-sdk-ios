enum HTTPStatusCode: Int {
    case ok = 200
    case unauthorized = 401
    case internalServerError = 500
    case badGateway = 502
    case serverNotAvailable = 503
}
