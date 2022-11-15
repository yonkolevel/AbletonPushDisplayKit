//
//  PushDisplayBridge.swift
//  MidiCircuitPlayGround
//
//  Created by Ricardo Abreu on 11/12/2020.
//

import Foundation
import AppKit
import SwiftUI
import Combine

public class Push2ViewController{
    private var displayManager: Push2DisplayManager
    private var window: NSWindow?
    private var subscriptions: Set<AnyCancellable>
    private var isDisplayConnected: Bool
    private var push2View: AnyView
    
    public init(push2View: AnyView) {
        self.push2View = push2View
        self.isDisplayConnected = false
        self.displayManager = Push2DisplayManager()
        self.subscriptions = Set<AnyCancellable>()
        
        self.displayManager.connect { result in
            switch result {
            case .success(let isConnected):
                self.isDisplayConnected = isConnected
            case .failure(let error):
                self.isDisplayConnected = false
                print(error)
            }
        }
        NotificationCenter.default
            .publisher(for: .push2ViewShouldUpdate)
            .sink { [weak self] notification in
                self?.updateDisplay()
            }
            .store(in: &subscriptions)
    }
    
    
    public func start(){
        DispatchQueue.main.async { [weak self] in
            let newWindow = NSWindow()
            
            self?.window = newWindow
            
            DispatchQueue.global(qos: .userInteractive).async {
                self?.updateDisplay()
            }
        }
    }
    
    private func updateDisplay(){
        if self.window == nil{
            return
        }
        
        let contentRect = NSRect(x: 0 , y: 0,width: 960, height:160)
        let scalingFactor = CGFloat(NSScreen.main?.backingScaleFactor ?? 1)
        
        if self.push2View == nil {
            self.push2View = self.push2View.frame(minWidth: 960/scalingFactor, idealWidth: 960/scalingFactor, maxWidth: 960/scalingFactor, minHeight: 160/scalingFactor, idealHeight: 160/scalingFactor, maxHeight: 160/scalingFactor)
                .fixedSize().eraseToAnyView()
        }
        
        
        guard let newWindow = self.window else {return}
        
        DispatchQueue.main.async {
           
            newWindow.contentView = NSHostingView(rootView:  self.push2View)
            newWindow.contentView?.canDrawConcurrently = true
            
            let bitmapRep = newWindow.contentView!.bitmapImageRepForCachingDisplay(in: contentRect)!
            
            newWindow.contentView!.cacheDisplay(in: contentRect, to: bitmapRep)
            
            DispatchQueue.global(qos: .userInteractive).async {
                self.displayManager.updateDisplay(image: bitmapRep)
            }
        }
    }
}


extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

