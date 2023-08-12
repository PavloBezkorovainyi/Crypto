//
//  HomeView.swift
//  Crypto
//
//  Created by Павел Бескоровайный on 12.08.2023.
//

import SwiftUI

struct HomeView: View {
  
  @State private var showPortfolio: Bool = false
  
  var body: some View {
    ZStack {
      //background layer
      Color.theme.background
        .ignoresSafeArea()
      
      //content layer
      VStack {
        homeHeader
        
        Spacer(minLength: 0)
      }
    }
  }
}

struct HomeView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      HomeView()
        .navigationBarHidden(true)
    }
  }
}

extension HomeView {
  private var homeHeader: some View {
    HStack {
      CircleButtonView(iconName: showPortfolio ? "plus" : "info")
        .animation(.none, value: showPortfolio)
        .background(
          CircleButtonAnimationView(animate: $showPortfolio)
        )
      Spacer()
      Text(showPortfolio ? "Portfolio" : "Live Prices")
        .animation(.none, value: showPortfolio)
        .font(.headline)
        .fontWeight(.heavy)
        .foregroundColor(Color.theme.accent)
      Spacer()
      CircleButtonView(iconName: "chevron.right")
        .rotationEffect(Angle(degrees: showPortfolio ? 180 : 0))
        .onTapGesture {
          withAnimation(.spring()) {
            showPortfolio.toggle()
          }
        }
    }
    .padding(.horizontal)
  }
}
