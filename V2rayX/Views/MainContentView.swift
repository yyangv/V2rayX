//
//  MainContentView.swift
//  V2rayX
//
//  Created by 杨洋 on 2024/12/28.
//

import SwiftUI
import SwiftData

struct MainContentView: View {
    var body: some View {
         Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    MainContentView()
}

extension View {
    fileprivate func alert2<A, B>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping () -> A,
        @ViewBuilder message: @escaping () -> B
    ) -> some View where A: View, B: View {
        ZStack {
            self
            if isPresented.wrappedValue {
                Alert(title: title, actions: actions, message: message)
            }
        }
    }
}

fileprivate struct Alert<A, B>: View where A: View, B: View {
    let title: String
    @ViewBuilder let actions: ()->A
    @ViewBuilder let message: ()->B
    
    var body: some View {
        Group {
            VStack {
                Text("⚠️").font(.system(size: 58, weight: .black))
                    .padding(.bottom, 5)
                Text(title).font(.headline)
                
                message()
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                
                Divider()
                
                HStack {
                    actions()
                        .buttonStyle(AlertButtonStyle())
                }
            }
            .frame(width: 220)
            .padding(12)
            .background(.windowBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.secondary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 2, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground.opacity(0.5))
    }
    
    private struct AlertButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: 200)
                .padding(.vertical, 6)
                .background(.tint)
                .foregroundColor(.white)
                .cornerRadius(6)
        }
    }
}

#Preview {
    @Previewable @State var open = true
    
    VStack {
        Rectangle()
            .foregroundColor(.green)
            .onTapGesture {
                open.toggle()
            }
        Rectangle()
            .foregroundColor(.red).onTapGesture {
                open.toggle()
            }
        Rectangle()
            .foregroundColor(.yellow).onTapGesture {
                open.toggle()
            }
        Button("Open") {
            open = true
        }
        Rectangle()
            .foregroundColor(.green).onTapGesture {
                open.toggle()
            }
        Rectangle()
            .foregroundColor(.red).onTapGesture {
                open.toggle()
            }
        Rectangle()
            .foregroundColor(.yellow).onTapGesture {
                open.toggle()
            }
    }
    .alert2("Title", isPresented: $open, actions: {
        Button("OK") {
            open.toggle()
        }
    }, message: {
        Text("This is a very long message, A long message will wrap to multiple lines.")
    })
    .frame(width: 300, height: 300, alignment: .center)
}
