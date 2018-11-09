//
//  NervosNativeTokenService.swift
//  Neuron
//
//  Created by XiaoLu on 2018/7/31.
//  Copyright © 2018年 cryptape. All rights reserved.
//

import Foundation
import AppChain
import BigInt

struct NervosNativeTokenService {
    static func getNervosNativeTokenMsg(blockNumber: String = "latest", completion: @escaping (AppChainServiceResult<TokenModel>) -> Void) {
        let appChain = AppChainNetwork.appChain()
        DispatchQueue.global().async {
            let result = appChain.rpc.getMetaData(blockNumber: blockNumber)
            DispatchQueue.main.async {
                switch result {
                case .success(let metaData):
                    let tokenModel = TokenModel()
                    tokenModel.address = ""
                    tokenModel.chainId = metaData.chainId.description
                    tokenModel.chainName = metaData.chainName
                    tokenModel.iconUrl = metaData.tokenAvatar
                    tokenModel.isNativeToken = true
                    tokenModel.name = metaData.tokenName
                    tokenModel.symbol = metaData.tokenSymbol
                    tokenModel.decimals = NativeDecimals.nativeTokenDecimals
                    tokenModel.chainidName = metaData.chainName + metaData.chainId.description
                    completion(AppChainServiceResult.success(tokenModel))
                case .failure(let error):
                    completion(AppChainServiceResult.error(error))
                }
            }
        }
    }

    static func getNervosNativeTokenBalance(walletAddress: String, completion: @escaping (AppChainServiceResult<String>) -> Void) {
        let appChain = AppChainNetwork.appChain()
        DispatchQueue.global().async {
            let result = appChain.rpc.getBalance(address: Address(walletAddress)!)
            DispatchQueue.main.async {
                switch result {
                case .success(let balance):
                    let balanceNumber = self.formatBalanceValue(value: balance)
                    completion(AppChainServiceResult.success(balanceNumber))
                case .failure(let error):
                    completion(AppChainServiceResult.error(error))
                }
            }
        }
    }

    private static func formatBalanceValue(value: BigUInt) -> String {
        let format = Web3Utils.formatToPrecision(value, formattingDecimals: 8, fallbackToScientific: false)!
        let finalValue = Double(format)!
        return finalValue.clean
    }

}