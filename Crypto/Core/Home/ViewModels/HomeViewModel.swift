//
//  HomeViewModel.swift
//  Crypto
//
//  Created by Павел Бескоровайный on 12.08.2023.
//

import Foundation
import Combine

class HomeViewModel: ObservableObject {
  
  @Published var statistics: [StatisticModel] = []
  
  @Published var allCoins: [CoinModel] = []
  @Published var portfolioCoins: [CoinModel] = []
  @Published var isLoading: Bool = false
  @Published var searchText: String = ""
  @Published var sortOption: SortOption = .holdings
  
  private let coinDataService = CoinDataService()
  private let marketDataService = MarketDataService()
  private let portfolioDataService = PortfolioDataService()
  private var cancellables = Set<AnyCancellable>()
  
  enum SortOption {
    case rank, rankReversed, holdings, holdingsReversed, price, priceReversed
  }
  
  
  init() {
    addSubscribers()
  }
  
  private func addSubscribers() {
    //update allCoins
    $searchText
      .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
      .combineLatest(coinDataService.$allCoins, $sortOption)
      .map(filterAndSortCoins)
      .sink { [weak self] returnedCoins in
        self?.allCoins = returnedCoins
      }
      .store(in: &cancellables)
    
    //update portfolio coins
    $allCoins
      .combineLatest(portfolioDataService.$savedEntities)
      .map(mapAllCoinsToPortfolioCoins)
      .sink { [weak self] coins in
        guard let self else { return }
        self.portfolioCoins = self.sortPortfolioCoinsIfNeeded(coins: coins)
      }
      .store(in: &cancellables)
    
    //updates market data
    marketDataService.$marketData
      .combineLatest($portfolioCoins)
      .map(mapGlobalMarketData)
      .sink { [weak self] stats in
        self?.statistics = stats
        self?.isLoading = false
      }
      .store(in: &cancellables)
  }
  
  public func updatePortfolio(coin: CoinModel, amount: Double) {
    portfolioDataService.updatePortfolio(coin: coin, amount: amount)
  }
  
  public func reloadData() {
    isLoading = true
    coinDataService.getCoins()
    marketDataService.getData()
    HapticManager.notification(type: .success)
  }
  
  private func filterAndSortCoins(text: String, coins: [CoinModel], sort: SortOption) -> [CoinModel] {
    var updatedCoins = filterCoins(text: text, coins: coins)
    sortCoins(sort: sort, coins: &updatedCoins)
    return updatedCoins
  }
  
  private func filterCoins(text: String, coins: [CoinModel]) -> [CoinModel] {
    guard !text.isEmpty else {
      return coins
    }
    
    let lowercasedText = text.lowercased()
    
    return coins.filter({ coin in
      return coin.name.contains(lowercasedText) ||
      coin.symbol.contains(lowercasedText) ||
      coin.id.contains(lowercasedText)
    })
  }
  
  private func sortCoins(sort: SortOption, coins: inout [CoinModel]) {
    switch sort {
    case .rank, .holdings, .holdingsReversed:
      coins.sort(by: { $0.rank < $1.rank })
    case .rankReversed:
      coins.sort(by: { $0.rank > $1.rank })
    case .price:
      coins.sort(by: { $0.currentPrice > $1.currentPrice })
    case .priceReversed:
      coins.sort(by: { $0.currentPrice < $1.currentPrice })
    }
  }
  
  private func sortPortfolioCoinsIfNeeded(coins: [CoinModel]) -> [CoinModel] {
    //will only sort by holdings or reversed holdings
    switch sortOption {
    case .holdings:
      return coins.sorted(by: { $0.currentHoldingsValue > $1.currentHoldingsValue })
    case .holdingsReversed:
      return coins.sorted(by: { $0.currentHoldingsValue < $1.currentHoldingsValue })
    default:
      return coins
    }
  }
  
  private func mapAllCoinsToPortfolioCoins(allCoins: [CoinModel], portfolioCoins: [PortfolioEntity]) -> [CoinModel] {
    allCoins.compactMap { (coin) -> CoinModel? in
      guard let entity = portfolioCoins.first(where: {$0.coinID == coin.id}) else {
        return nil
      }
      return coin.updateHoldings(amount: entity.amount)
    }
  }
  
  private func mapGlobalMarketData(data: MarketDataModel?, portfolioCoins: [CoinModel]) -> [StatisticModel] {
    var stats: [StatisticModel] = []
    
    guard let data else {
      return stats
    }
    
    let marketCap = StatisticModel(title: "Market Cap", value: data.marketCap, percentageChange: data.marketCapChangePercentage24HUsd)
    let volume = StatisticModel(title: "24h Volume", value: data.volume)
    let btcDominance = StatisticModel(title: "BTC Dominance", value: data.btcDominance)
    
    
    let portfolioValue = portfolioCoins
      .map{ $0.currentHoldingsValue }
      .reduce(0, +)
    
    let previousValue = portfolioCoins
      .map { coin -> Double in
        let currentValue = coin.currentHoldingsValue
        let percentChange = (coin.priceChangePercentage24H ?? 0) / 100
        let previousValue = currentValue / (1 + percentChange)
        return previousValue
      }
      .reduce(0, +)
    
    let percentageChange = ((portfolioValue - previousValue) / previousValue) * 100
    
    let portfolio = StatisticModel(title: "Portfolio Value", value: portfolioValue.asCurrencyWith2Decimals(), percentageChange: percentageChange)
    
    stats.append(contentsOf: [
      marketCap,
      volume,
      btcDominance,
      portfolio
    ])
    
    return stats
  }
}
