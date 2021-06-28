//
//  NetworkingClient+Request.swift
//  
//
//  Created by Piotr Prokopowicz on 08/12/2020.
//

import Foundation
import Combine

extension Networking {
    
    /// Request function is used to perform service request.
    /// 
    /// - Parameter service: Service object that conforms to `NetworkingService` protocol. Has every information that client needs to perform a service call.
    /// - Returns: AnyPublisher with given services output type or an error. In case of Networking error it will be of type `NetworkingError`.
    public func request<Service: NetworkingService>(service: Service) -> AnyPublisher<Service.Output, Error> {
        guard let urlRequest = URLRequest(service: service, encoder: encoder, timeout: timeout) else {
            callPlugins(service: service, event: .unableToParseRequest)
            return Fail(error: NetworkingError<NetworkingEmpty>(status: .unableToParseRequest, response: nil))
                .eraseToAnyPublisher()
        }
        
        callPlugins(service: service, event: .dataRequested)
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpURLResponse = response as? HTTPURLResponse else {
                    let errorResponse = try? decoder.decode(Service.ErrorResponse.self, from: data)
                    callPlugins(service: service, event: .responseError(data: data, status: .unknown))
                    
                    throw NetworkingError(status: .unknown, response: errorResponse)
                }
                
                guard 200...299 ~= httpURLResponse.statusCode else {
                    let errorResponse = try? decoder.decode(Service.ErrorResponse.self, from: data)
                    let status = NetworkingStatus(rawValue: httpURLResponse.statusCode) ?? .unknown
                    callPlugins(service: service, event: .responseError(data: data, status: status))
                    
                    throw NetworkingError(status: status, response: errorResponse)
                }
                
                let status = NetworkingStatus(rawValue: httpURLResponse.statusCode) ?? .unknown
                callPlugins(service: service, event: .success(data: data, status: status))
                
                return try decoder.decode(Service.Output.self, from: data)
            }.eraseToAnyPublisher()
    }
    
    /// Request function is used to perform service request.
    ///
    /// - Parameter service: Service object that conforms to `NetworkingService` protocol. Has every information that client needs to perform a service call.
    /// - Parameter completion: Completion handler with `Result` with either given services output type or an error. In case of Networking error it will be of type `NetworkingError`.
    public func request<Service: NetworkingService>(service: Service, completion: @escaping (Result<Service.Output, Error>) -> Void) {
        guard let urlRequest = URLRequest(service: service, encoder: encoder, timeout: timeout) else {
            callPlugins(service: service, event: .unableToParseRequest)
            
            DispatchQueue.main.async {
                completion(.failure(NetworkingError<NetworkingEmpty>(status: .unableToParseRequest, response: nil)))
            }
            return
        }
        
        callPlugins(service: service, event: .dataRequested)
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            let data = data ?? Data()
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                
                return
            }
            
            guard let httpURLResponse = response as? HTTPURLResponse else {
                let errorResponse = try? decoder.decode(Service.ErrorResponse.self, from: data)
                callPlugins(service: service, event: .responseError(data: data, status: .unknown))
                
                DispatchQueue.main.async {
                    completion(.failure(NetworkingError(status: .unknown, response: errorResponse)))
                }
                
                return
            }
            
            guard 200...299 ~= httpURLResponse.statusCode else {
                let errorResponse = try? decoder.decode(Service.ErrorResponse.self, from: data)
                let status = NetworkingStatus(rawValue: httpURLResponse.statusCode) ?? .unknown
                callPlugins(service: service, event: .responseError(data: data, status: status))
                
                DispatchQueue.main.async {
                    completion(.failure(NetworkingError(status: status, response: errorResponse)))
                }
                
                return
            }
            
            let status = NetworkingStatus(rawValue: httpURLResponse.statusCode) ?? .unknown
            callPlugins(service: service, event: .success(data: data, status: status))
            
            do {
                let model = try decoder.decode(Service.Output.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(model))
                }
            } catch(let error) {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
}

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
extension Networking {
    
    /// Request function is used to perform service request.
    ///
    /// - Parameter service: Service object that conforms to `NetworkingService` protocol. Has every information that client needs to perform a service call.
    /// - Returns: Given services output type
    public func throwingRequest<Service: NetworkingService>(service: Service) async throws -> Service.Output {
        try await withCheckedThrowingContinuation { continuation in
            request(service: service) { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
        }
    }
    
    /// Request function is used to perform service request.
    ///
    /// - Parameter service: Service object that conforms to `NetworkingService` protocol. Has every information that client needs to perform a service call.
    /// - Returns: `Result` with either given services output type or an error. In case of Networking error it will be of type `NetworkingError`.
    public func request<Service: NetworkingService>(service: Service) async -> Result<Service.Output, Error> {
        await withUnsafeContinuation { continuation in
            request(service: service) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
}
