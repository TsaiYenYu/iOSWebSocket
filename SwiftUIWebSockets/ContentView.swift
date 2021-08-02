//
//  ContentView.swift
//  SwiftUIWebSockets
//
//  Created by Anupam Chugh on 17/02/20.
//  Copyright © 2020 iowncode. All rights reserved.
//

import SwiftUI
import Combine
import Foundation

struct ContentView: View {
    
    @ObservedObject var service = WebSocketService()
    @State var number: Int = 0
    
    
    var body: some View {
        
        VStack{
            
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 150))
                .foregroundColor(Color(red: 247 / 255, green: 142 / 255, blue: 26 / 255))
                .padding()
            
            Text("USD")
                .font(.largeTitle)
                .padding()
            
            Text(service.priceResult)
                .font(.system(size: 60))
            
            Text( String(service.updatedCount) + "updated")
                .font(.system(size: 24))
            
            Text( String(service.number) + "second")
                .font(.system(size: 24))

            
            
        }.onAppear {

            
            
            self.service.connect()
        }
    }
}


class WebSocketService : ObservableObject {

    private let urlSession = URLSession(configuration: .default)
    private var webSocketTask: URLSessionWebSocketTask?
    private let baseURL = URL(string: "wss://ws.finnhub.io?token=yourtoken")!

    let didChange = PassthroughSubject<Void, Never>()
    @Published var price: String = ""
    
    @Published var updatedCount: Int = 0
    @Published var number: Int = 0
    
    private var cancellable: AnyCancellable? = nil
    
    var priceResult: String = "" {
        didSet {
            didChange.send()
        }
    }
    
    
    init() {
        cancellable = AnyCancellable($price
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: \.priceResult, on: self))
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
            self.number += 1
            print(self.number)
            
        }
        
    }

    func connect() {
        stop()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = urlSession.webSocketTask(with: baseURL)
        webSocketTask?.resume()
        
        sendMessage()
        receiveMessage()
        sendPing()
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { (error) in
            
            if let error = error {
                print("Sending PING failed: \(error)")
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.sendPing()
            }
        }
    }

    func stop() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    private func sendMessage()
    {
        let string = "{\"type\":\"subscribe\",\"symbol\":\"BINANCE:BTCUSDT\"}"
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket couldn’t send message because: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?
            .receive {[weak self] result in
            switch result {
            case .failure(let error):
                print("Error in receiving message: \(error)")
            case .success((let Message)):
                switch Message {
                case .string(let dataString):
                    do {
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(APIResponse.self, from: Data(dataString.utf8))
                        DispatchQueue.main.async{
                            self?.price = "\(String(describing: result.data.first?.p ?? 0) )"
                            self?.updatedCount += 1
                        }
                    } catch  {
                        print("error is \(error.localizedDescription)")
                    }
                case .data(let data):
                    do {
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(APIResponse.self, from: data)
                        print(result.data.first?.p ?? 0)
                        
                    } catch  {
                        print("error is \(error.localizedDescription)")
                    }
                default:
                    print(Message)
                    fatalError()
                }
                self?.receiveMessage()

            }
        }
    }
    

    
}

struct APIResponse: Codable {
    var data: [PriceData]
    var type : String
    
    private enum CodingKeys: String, CodingKey {
        case data, type
    }
}

struct PriceData : Codable{
    
    public var p: Float
    
    private enum CodingKeys: String, CodingKey {
        case p = "p"
    }
}
