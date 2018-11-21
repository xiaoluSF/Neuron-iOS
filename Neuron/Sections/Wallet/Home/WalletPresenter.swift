//
//  WalletPresenter.swift
//  Neuron
//
//  Created by 晨风 on 2018/11/20.
//  Copyright © 2018 Cryptape. All rights reserved.
//

import UIKit
import RealmSwift
import BigInt
import PromiseKit
import Web3swift
import EthereumAddress

protocol WalletPresenterDelegate: NSObjectProtocol {
    func walletPresenterBeganRefresh(presenter: WalletPresenter)
    func walletPresenterEndedRefresh(presenter: WalletPresenter)
    func walletPresenter(presenter: WalletPresenter, didSwitchWallet wallet: WalletModel)
    func walletPresenter(presenter: WalletPresenter, didRefreshToken tokens: [Token])
    func walletPresenter(presenter: WalletPresenter, didRefreshTotalAmount amount: Double)
    func walletPresenter(presenter: WalletPresenter, didRefreshCurrency currency: LocalCurrency)
    func walletPresenter(presenter: WalletPresenter, didRefreshTokenAmount token: Token)
}

class WalletPresenter {
    var currentWallet: WalletModel?
    var currency: LocalCurrency!
    private (set) var tokens = [Token]() {
        didSet {
            timestamp = Date().timeIntervalSince1970
            delegate?.walletPresenter(presenter: self, didRefreshToken: self.tokens)
            refreshAmount()
        }
    }
    weak var delegate: WalletPresenterDelegate?

    private var walletObserver: NotificationToken?
    private var tokenObserver: NotificationToken?
    private(set) var refreshing = false
    private var timestamp: TimeInterval = 0.0

    init() {
        walletObserver = WalletRealmTool.getCurrentAppModel().observe { [weak self](change) in
            switch change {
            case .change(let propertys):
                guard let wallet = propertys.first(where: { $0.name == "currentWallet" })?.newValue as? WalletModel else { return }
                guard wallet.address != self?.currentWallet?.address else { return }
                self?.refresh()
            default:
                break
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPrice), name: .changeLocalCurrency, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAmount), name: .switchEthNetwork, object: nil)
    }

    func refresh() {
        guard let appModel = WalletRealmTool.realm.objects(AppModel.self).first(where: { _ in true }) else { return }
        guard let wallet = appModel.currentWallet else { return }
        currentWallet = wallet
        delegate?.walletPresenter(presenter: self, didSwitchWallet: currentWallet!)

        tokenObserver?.invalidate()
        tokenObserver = wallet.selectTokenList.observe({ [weak self](change) in
            guard let self = self else { return }
            switch change {
            case .initial(let selectTokenList):
                var tokens = [Token]()
                tokens += WalletRealmTool.getCurrentAppModel().nativeTokenList.map({ Token($0) })
                tokens += selectTokenList.map({ Token($0) })
                tokens.forEach { (token) in
                    token.walletAddress = self.currentWallet!.address
                }
                self.tokens = tokens
            case .update(let selectTokenList, let deletions, let insertions, modifications: _):
                var tokens = self.tokens
                let selectTokenFirstIndex = tokens.count - selectTokenList.count - deletions.count
                deletions.enumerated().forEach({ (offset, element) in
                    let index = selectTokenFirstIndex + element - offset
                    tokens.remove(at: index)
                })
                insertions.forEach({ (idx) in
                    let token = Token(selectTokenList[idx])
                    token.walletAddress = self.currentWallet!.address
                    tokens.append(token)
                })
                self.tokens = tokens
            default:
                break
            }
        })
    }

    @objc func refreshAmount() {
        refreshing = true
        delegate?.walletPresenterBeganRefresh(presenter: self)
        currency = LocalCurrencyService.shared.getLocalCurrencySelect()
        delegate?.walletPresenter(presenter: self, didRefreshCurrency: currency)
        let timestamp = self.timestamp
        let tokens = self.tokens
        DispatchQueue.global().async {
            var amount = 0.0
            tokens.forEach { (token) in
                guard timestamp == self.timestamp else { return }
                do {
                    let balance = try self.getBalance(token: token)
                    let balanceText = Web3Utils.formatToEthereumUnits(balance, toUnits: .eth, decimals: 8) ?? "0"
                    token.balance = Double(balanceText)
                    token.price = self.getPrice(token: token)

                    if let price = token.price, let balance = token.balance {
                        amount += price * balance
                    }
                    DispatchQueue.main.async {
                        self.delegate?.walletPresenter(presenter: self, didRefreshTokenAmount: token)
                    }
                } catch {
                }
            }
            guard timestamp == self.timestamp else { return }
            DispatchQueue.main.async {
                self.refreshing = false
                self.delegate?.walletPresenterEndedRefresh(presenter: self)
                self.delegate?.walletPresenter(presenter: self, didRefreshTotalAmount: amount)
            }
        }
    }

    @objc func refreshPrice() {
        refreshing = true
        currency = LocalCurrencyService.shared.getLocalCurrencySelect()
        delegate?.walletPresenter(presenter: self, didRefreshCurrency: currency)
        delegate?.walletPresenterBeganRefresh(presenter: self)
        let tokens = self.tokens
        var amount = 0.0
        DispatchQueue.global().async {
            tokens.forEach { (token) in
                token.price = self.getPrice(token: token)
                if let price = token.price, let balance = token.balance {
                    amount += price * balance
                }
                DispatchQueue.main.async {
                    self.delegate?.walletPresenter(presenter: self, didRefreshTokenAmount: token)
                }
            }
            DispatchQueue.main.async {
                self.refreshing = false
                self.delegate?.walletPresenterEndedRefresh(presenter: self)
                self.delegate?.walletPresenter(presenter: self, didRefreshTotalAmount: amount)
            }
        }
    }

    // MARK: - Utils
    func getBalance(token: Token) throws -> BigUInt {
        switch token.type {
        case .ether:
            return try EthereumNetwork().getWeb3().eth.getBalance(address: EthereumAddress(token.walletAddress)!)
        case .appChain, .appChainErc20:
            return try AppChainNetwork.appChain().rpc.getBalance(address: token.walletAddress)
        case .erc20:
            let contractAddress = EthereumAddress(token.address)!
            let walletAddress = EthereumAddress(token.walletAddress)!
            let contract = EthereumNetwork().getWeb3().contract(Web3.Utils.erc20ABI, at: contractAddress, abiVersion: 2)!
            let result = try contract.method("balanceOf", parameters: [walletAddress as AnyObject])?.call()
            return result?["0"] as! BigUInt
        }
    }

    func getPrice(token: Token) -> Double? {
        let currencyToken = CurrencyService().searchCurrencyId(for: token.symbol)
        guard let tokenId = currencyToken?.id else {
            return nil
        }
        return try? Promise<Double>.init { (resolver) in
            CurrencyService().getCurrencyPrice(tokenid: tokenId, currencyType: currency.short, completion: { (result) in
                switch result {
                case .success(let price):
                    resolver.fulfill(price)
                case .error(let error):
                    resolver.reject(error)
                }
            })
        }.wait()
    }
}