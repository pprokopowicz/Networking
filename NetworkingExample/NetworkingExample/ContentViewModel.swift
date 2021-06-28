//
//  ContentViewModel.swift
//  NetworkingExample
//
//  Created by Piotr Prokopowicz on 08/12/2020.
//

import Foundation
import Networking
import Combine

final class ContentViewModel: ObservableObject {
    
    @Published var todos: [TodoModel]?
    private var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()
    
    func fetch() {
        Networking.shared
            .request(service: TodoService())
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { _ in
            }, receiveValue: { todos in
                self.todos = todos
            }).store(in: &cancellables)
    }
    
    @available(iOS 15.0, *)
    func asyncFetch() async {
        let result = await Networking.shared.request(service: TodoService())
        
        switch result {
        case .success(let todos):
            self.todos = todos
        case .failure:
            break
        }
    }
    
}
