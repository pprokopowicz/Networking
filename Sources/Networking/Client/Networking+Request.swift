//
//  NetworkingClient+Request.swift
//  
//
//  Created by Piotr Prokopowicz on 08/12/2020.
//

import Foundation
import Combine

extension Networking {
    
    /// Request function is used to perform service request
    /// - Parameter service: Service object that conforms to `NetworkingService` protocol. Has every information that client needs to perform a service call.
    /// - Returns: AnyPublisher with given services output type or an error. In case of Networking error it will be of type `NetworkingError`.
    public func request<Service: NetworkingService>(service: Service) -> AnyPublisher<Service.Output, Error> {
        guard let urlRequest = URLRequest(service: service, encoder: encoder, timeout: timeout) else {
            return Fail(error: NetworkingError<NetworkingEmpty>(status: .unableToParseResponse, response: nil))
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpURLResponse = response as? HTTPURLResponse else {
                    let errorResponse = try? decoder.decode(Service.ErrorResponse.self, from: data)
                    throw NetworkingError(status: .unknown, response: errorResponse)
                }
                
                guard 200...299 ~= httpURLResponse.statusCode else {
                    let errorResponse = try? decoder.decode(Service.ErrorResponse.self, from: data)
                    throw NetworkingError(code: httpURLResponse.statusCode, response: errorResponse)
                }
                
                return try decoder.decode(Service.Output.self, from: data)
            }.eraseToAnyPublisher()
    }
    
}