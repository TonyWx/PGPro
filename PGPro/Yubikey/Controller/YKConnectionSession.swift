//
//  YKOpenPGP.swift
//  PGPro
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import YubiKit

class YKConnectionSession: NSObject, ObservableObject, YKFManagerDelegate {

    // MARK: - Connection handling
    // According to https://github.com/Yubico/yubikit-ios/blob/master/docs/easy-handling-connections.md

    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
        YubiKitManager.shared.startAccessoryConnection()
    }

    private var nfcConnection: YKFNFCConnection?
    private var accessoryConnection: YKFAccessoryConnection?

    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
    }

    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
    }

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
    }

    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
    }


    // MARK: - Connection helper functions

    private var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    private func getConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            YubiKitManager.shared.startNFCConnection()
        }
    }

    // MARK: - OpenPGP Smartcard helper functions

    enum YKError: Error {
        case nfcSessionClosed
        case invalidAPDU
        case rawCommandServiceNotAvailable
        case executionError(error: Error)
        case emptyExecutionResponse
        case rawCommandService(status: UInt16)
        case invalidResponse
        case notImplemented

        var description: String {
            switch self {
            case .nfcSessionClosed: return "NFC session is closed"
            case .invalidAPDU: return "Invalid APDU command"
            case .rawCommandServiceNotAvailable: return "rawCommandService is not available"
            case .executionError(let error): return "NFC execution error: \(error)"
            case .emptyExecutionResponse: return "Empty NFC execution response"
            case .rawCommandService(let status): return "RawCommandService Status: \(YKConnectionSession.statusDescription(of: status))"
            case .invalidResponse: return "Invalid Response"
            case .notImplemented: return "Not Implemented"
            }
        }
    }

    typealias apduResponse = (UInt16?, Data?)
    private func parseResponse(response: Data) -> apduResponse {
        var statusCode: UInt16?
        if response.count >= 2 {
            statusCode = UInt16(response[response.count - 2]) << 8 + UInt16(response[response.count - 1])
        } else {
            Log.e("Respons too short: \(response.count) bytes")
        }

        var data: Data? = nil
        if response.count >= 2 {
            data = response.subdata(in: 0..<response.count - 2)
        }

        return (statusCode, data)
    }

    private static func statusDescription(of status: UInt16) -> String {
        let sw1 = UInt8(status >> 8)
        Log.d("sw1: " + (String(format:"%02X", sw1)))
        let sw2 = UInt8(status)
        Log.d("sw2: " + (String(format:"%02X", sw2)))

        // Special cases (commented out below)
        if (sw1 == 0x61) {
            return "Command correct, \(sw2) bytes available in response"
        } else if (sw1 == 0x63) {
            let retries = UInt8((sw2 >> 4) & 0x000F)
            return "Password not checked, \(retries) further allowed retries"
        } else if (status >= 0x6280) && (status <= 0x6402) {
            return "Triggering by the card; 0E = Out of Memory (BasicCard specific)"
        }

        switch status {
        // case: 0x61XX: return "Command correct, xx bytes available in response"
        case 0x6285: return "Selected file or DO in termination state"
        // case 0x63CX: return "Password not checked, 'X' encodes the number of further allowed retries"
        // case 0x6402-0x6280: return "Triggering by the card; 0E = Out of Memory (BasicCard specific)"
        case 0x6581: return "Memory failure"
        case 0x6600: return "Security-related issues"
        case 0x6700: return "Wrong length (Lc and/or Le)"
        case 0x6881: return "Logical channel not supported"
        case 0x6882: return "Secure messaging not supported"
        case 0x6883: return "Last command of the chain expected"
        case 0x6884: return "Command chaining not supported"
        case 0x6982: return "Security status not satisfied (PW wrong/PW not checked/SM incorrect)"
        case 0x6983: return "Authentication method blocked; PW blocked (error counter zero)"
        case 0x6985: return "Condition of use not satisfied"
        case 0x6987: return "Expected secure messaging DOs missing (e. g. SM-key)"
        case 0x6988: return "SM data objects incorrect (e. g. wrong TLV-structure in command data)"
        case 0x6A80: return "Incorrect parameters in the command data field"
        case 0x6A82: return "File or application not found"
        case 0x6A88: return "Referenced data, reference data or DO not found"
        case 0x6B00: return "Wrong parameters P1-P2"
        case 0x6D00: return "Instruction code (INS) not supported or invalid"
        case 0x6E00: return "Class (CLA) not supported"
        case 0x6F00: return "No precise diagnosis"
        case 0x9000: return "Command correct"
        default:     return "Other status code: \(String(format:"%02X", status))"
        }
     }

    private func execute(command apdu: YKFAPDU, executionCompletion: @escaping (Data?, YKError) -> Void) {
        getConnection { (connection) in
            guard let SCInterface = connection.smartCardInterface else {
                Log.s("Failed to initialize SmartCardInterface")
                executionCompletion(nil, YKError.rawCommandServiceNotAvailable)
                return
            }

            SCInterface.executeCommand(apdu, completion: { (response, error) in
                if let error = error {
                    Log.s("Error while executing command!")
                    let errorCode = (error as NSError).code
                    executionCompletion(nil, YKError.rawCommandService(status: UInt16(errorCode)))
                    return
                }

                guard let response = response, response.count >= 2 else {
                    Log.s("Received empty response!")
                    executionCompletion(nil, YKError.emptyExecutionResponse)
                    return
                }

                let (statusCode, data) = self.parseResponse(response: response)
                Log.d("Execution status: \(YKConnectionSession.statusDescription(of: statusCode!))")
                executionCompletion(data, YKError.rawCommandService(status: statusCode!))
            })
        }
    }

    func selectApplet() {
        getConnection { (connection) in
            guard let SCInterface = connection.smartCardInterface else {
                Log.s("Failed to initialize SmartCardInterface")
                return
            }
            SCInterface.selectApplication(APDU.selectOpenPGPApplet2) { (response, error) in
                Log.d("Response \(response?.description ?? "null response")")
                Log.d("Error: \(error.debugDescription)")
            }
        }
    }


    // MARK: - Public functions


    /**
    Establishes a new connection to the Yubikey and fetches its configuration from the management application.

    - Parameters:
        - completion: The completion handler gets called once a configuration has been fetched or an has error occured.
    */
    func getConfiguration(completion: @escaping (Result<YKFManagementReadConfigurationResponse, Error>) -> Void) {
        getConnection { connection in
            connection.managementSession { (session, error) in
                if let session = session {
                    session.readConfiguration { (response, error) in
                        if let response = response {
                            completion(.success(response))
                        } else if let error = error {
                            completion(.failure(error))
                        } else {
                            Log.s("Unknown error occured while reading configuration.")
                        }
                    }
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    Log.s("Unknown error occured while establishing the management session.")
                }
            }
        }
    }

    func getCardholder(completion: @escaping (Result<SmartCard.Cardholder, YKError>) -> Void) {
        execute(command: APDU.getCardholderData) { (data, status) in
            switch status {
            case .rawCommandService(let code):
                guard code == 0x9000 else {
                    completion(.failure(status))
                    return
                }

                guard let data = data else {
                    completion(.failure(.invalidResponse))
                    return
                }
                Log.d("Data size: \(data.count)")
                Log.d("Data: \(String(decoding: data, as: UTF8.self))")
                completion(.failure(YKError.notImplemented))
            default:
                completion(.failure(status))
            }
        }
    }

    func getKeyInformation(completion: @escaping (Result<SmartCard.KeyInformation, YKError>) -> Void) {
        execute(command: APDU.getKeyInformation) { (data, status) in
            switch status {
            case .rawCommandService(let code):
                guard code == 0x9000 else {
                    completion(.failure(status))
                    return
                }

                guard let data = data else {
                    completion(.failure(.invalidResponse))
                    return
                }
                Log.d("Data size: \(data.count)")
                Log.d("Data: \(String(decoding: data, as: UTF8.self))")
                completion(.failure(YKError.notImplemented))
            default:
                completion(.failure(status))
            }
        }
    }

}