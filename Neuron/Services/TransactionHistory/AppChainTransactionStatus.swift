//
//  AppChainTransactionStatus.swift
//  Neuron
//
//  Created by 晨风 on 2018/11/14.
//  Copyright © 2018 Cryptape. All rights reserved.
//

import UIKit
import Alamofire
import PromiseKit

class AppChainTransactionStatus: NSObject {
    func getTransactionStatus(sentTransaction: SentTransaction) -> TransactionStateResult {
        do {
//            let details = try AppChainNetwork.appChain().rpc.getTransaction(txhash: sentTransaction.txHash)
            let currentBlockNumber = try AppChainNetwork.appChain().rpc.blockNumber()
            if let receipt = try? AppChainNetwork.appChain().rpc.getTransactionReceipt(txhash: sentTransaction.txHash) {
                if let error = receipt.errorMessage {
                    print(error)
                    return .failure
                } else {
                    if let transaction = try? AppChainTransactionHistory().getTransaction(txhash: sentTransaction.txHash, account: sentTransaction.from, from: sentTransaction.from, to: sentTransaction.to) {
                        return .success(transaction: transaction)
                    } else {
                        if sentTransaction.blockNumber < currentBlockNumber {
                            return .failure
                        } else {
                            return .pending
                        }
                    }
                }
            } else {
                if sentTransaction.blockNumber < currentBlockNumber {
                    return .failure
                } else {
                    return .pending
                }
            }
        } catch {
            return .pending
        }
    }
}
