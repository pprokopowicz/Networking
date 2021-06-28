//
//  ContentView.swift
//  NetworkingExample
//
//  Created by Piotr Prokopowicz on 08/12/2020.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var viewModel = ContentViewModel()
    
    var body: some View {
        if let todos = viewModel.todos {
            List(todos, id: \.id) { todo in
                Text(todo.title)
            }
        }
        
        Button("Fetch todos") {
            viewModel.fetch()
        }.padding()
        
        if #available(iOS 15.0, *) {
            Button("Async Fetch", role: nil) {
                await viewModel.asyncFetch()
            }.padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
