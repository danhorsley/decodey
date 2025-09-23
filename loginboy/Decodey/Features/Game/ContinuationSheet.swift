//import SwiftUI
//
//struct ContinueGameSheet: View {
//    @EnvironmentObject var gameState: GameState
//    let isDailyChallenge: Bool
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            Text(isDailyChallenge ? "Continue Daily Challenge?" : "Continue Previous Game?")
//                .font(.title2)
//                .fontWeight(.bold)
//                .padding(.top)
//            
//            Text("You have an unfinished game. Would you like to continue where you left off?")
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            
//            HStack(spacing: 20) {
//                Button(action: {
//                    gameState.showContinueGameModal = false
//                    gameState.resetGame() // This will start a new game and purge the old one
//                }) {
//                    Text("New Game")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.gray.opacity(0.2))
//                        .foregroundColor(.primary)
//                        .cornerRadius(10)
//                }
//                
//                Button(action: {
//                    gameState.continueSavedGame()
//                }) {
//                    Text("Continue")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//            }
//            .padding(.horizontal)
//            .padding(.bottom)
//        }
//        .padding()
//    }
//}
//
////
////  ContinuationSheet.swift
////  loginboy
////
////  Created by Daniel Horsley on 13/05/2025.
////
//
