//
//  TransactionGasCostViewController.swift
//  Neuron
//
//  Created by 晨风 on 2018/11/23.
//  Copyright © 2018 Cryptape. All rights reserved.
//

import UIKit
import BigInt

class TransactionGasCostViewController: UITableViewController {
    @IBOutlet weak var gasPriceTextField: UITextField!
    @IBOutlet weak var gasLimitTextField: UITextField!
    @IBOutlet weak var gasCostLabel: UILabel!
    @IBOutlet weak var gasCostDescLabel: UILabel!
    @IBOutlet weak var dataTextView: UITextView!
    @IBOutlet weak var dataTextPlaceholderLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    var param: TransactionParamBuilder!
    private var paramBuilder: TransactionParamBuilder!
    private var observers = [NSKeyValueObservation]()
    private let minGasPrice = 1.0
    @IBOutlet weak var gasCostTitleLabel: UILabel!
    @IBOutlet weak var extenDataTitleLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transaction.Send.gasCostSetting".localized()
        gasCostTitleLabel.text = "Transaction.Send.gasCost".localized()
        extenDataTitleLabel.text = "Transaction.Send.extenData".localized()
        descLabel.text = "Transaction.Send.gasCostSettingDesc".localized()
        confirmButton.setTitle("Common.confirm".localized(), for: .normal)
        gasPriceTextField.placeholder = "Transaction.Send.input".localized()
        gasLimitTextField.placeholder = "Transaction.Send.input".localized()
        dataTextPlaceholderLabel.text = "Transaction.Send.inputHexData".localized()

        paramBuilder = TransactionParamBuilder(builder: param)
        observers.append(paramBuilder.observe(\.txFeeNatural, options: [.initial]) { [weak self](_, _) in
            self?.updateGasCost()
        })
        observers.append(param.observe(\.tokenPrice, options: [.initial]) { [weak self](_, _) in
            self?.updateGasCost()
        })
        if paramBuilder.tokenType == .erc20 {
            dataTextView.isEditable = false
        }
    }

    @IBAction func confirm() {
        let gasPrice = Double(gasPriceTextField.text!)!
        if gasPrice < minGasPrice {
            Toast.showToast(text: "Transaction.Send.gasPriceSettingIsTooLow".localized())
            return
        }

        if paramBuilder.tokenType == .ether {
            if paramBuilder.data.count > 0 {
                let estimateGasLimit = paramBuilder.estimateGasLimit()
                if paramBuilder.gasLimit < UInt(estimateGasLimit) {
                    Toast.showToast(text: "Transaction.Send.gasLimitSettingIsTooLow".localized().replacingOccurrences(of: "[value]", with: "”\(estimateGasLimit)(估算值)*4”"))
                    return
                }
            } else {
                if paramBuilder.gasLimit < GasCalculator.defaultGasLimit {
                    Toast.showToast(text: "Transaction.Send.gasLimitSettingIsTooLow".localized().replacingOccurrences(of: "[value]", with: "\(GasCalculator.defaultGasLimit)"))
                    return
                }
            }
        } else if paramBuilder.tokenType == .erc20 {
            let estimateGasLimit = paramBuilder.estimateGasLimit()
            if paramBuilder.gasLimit < estimateGasLimit {
                Toast.showToast(text: "Transaction.Send.gasLimitSettingIsTooLow".localized().replacingOccurrences(of: "[value]", with: "”\(estimateGasLimit)(估算值)*4”"))
            }
        }

        param.gasPrice = paramBuilder.gasPrice
        param.gasLimit = paramBuilder.gasLimit
        param.data = dataTextView.text.data(using: .utf8) ?? Data()
        navigationController?.popViewController(animated: true)
    }

    private func updateGasCost() {
        gasPriceTextField.text = paramBuilder.gasPrice.weiToGwei().trailingZerosTrimmed
        gasLimitTextField.text = paramBuilder.gasLimit.description
        gasCostLabel.text = "\(paramBuilder.txFeeNatural.decimal) \(paramBuilder.nativeCoinSymbol)"
        gasCostDescLabel.text = "≈Gas Limit(\(gasLimitTextField.text!))*Gas Price(\(gasPriceTextField.text!) Gwei)"
        if paramBuilder.tokenPrice > 0 {
            gasCostLabel.text = gasCostLabel.text! + " ≈ \(paramBuilder.currencySymbol)" + String(format: "%.4lf", paramBuilder.tokenPrice * paramBuilder.txFeeNatural)
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

extension TransactionGasCostViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var character = "0123456789"
        if textField.text!.contains(".") {
            character += "."
        }
        guard CharacterSet(charactersIn: character).isSuperset(of: CharacterSet(charactersIn: string)) else {
            return false
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == gasPriceTextField {
            paramBuilder.gasPrice = Double(gasPriceTextField.text!)!.gweiToWei()
        } else if textField == gasLimitTextField {
            paramBuilder.gasLimit = UInt64(gasLimitTextField.text!) ?? GasCalculator.defaultGasLimit
        }
    }
}

extension TransactionGasCostViewController: UITextPasteDelegate {
}

extension TransactionGasCostViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let character = "0123456789abcdefABCDEF"
        guard CharacterSet(charactersIn: character).isSuperset(of: CharacterSet(charactersIn: text)) else {
            return false
        }
        dataTextPlaceholderLabel.isHidden = textView.text.count + (text.count - range.length) > 0
        return true
    }
}