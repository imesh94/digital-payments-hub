// Copyright (c) 2024 WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/constraint;
import ballerina/data.jsondata;
import ballerina/lang.array;
import ballerina/log;
import ballerina/uuid;
import ballerinax/financial.iso20022;
import ballerinax/financial.iso8583;

import digitalpaymentshub/drivers.utils;
import digitalpaymentshub/payments_hub.models;

# Handles inbound transactions and return response.
#
# + data - byte array of the incoming message
# + return - byte array of the response message
public function handleInbound(byte[] & readonly data) returns byte[]|error {

    // XPay message
    // message len = 4 bytes
    // message header = 20 bytes
    // message type identifier = 4 bytes
    // 1 st bitmap = 16 bytes
    // if present - 2nd bitmap = 16 bytes
    string hex = array:toBase16(data);
    log:printDebug("[XPay driver] Received message from the network driver: " + hex);
    log:printDebug("[XPay driver] Recieived data string: " + data.toString());
    int headerLength = 8;
    int versionNameLength = 40;
    int mtiLLength = 8;
    int nextIndex = headerLength + versionNameLength;
    // let's convert all to the original hex representation. Even though this is a string,
    // it represents the actual hexa decimal encoded byte stream.
    // extract the message type identifier 
    string mtiMsg = hex.substring(nextIndex, nextIndex + mtiLLength);
    nextIndex = nextIndex + mtiLLength;
    // count the number of bitmaps. there can be multiple bitmaps. but the first bit of the bitmap indicates whether 
    // there is another bitmap.
    int bitmapCount = check countBitmapsFromHexString(hex.substring(nextIndex));

    // a bitmap in the hex representation is represented in 16 chars.
    int bitmapLastIndex = nextIndex + 16 * bitmapCount;
    string bitmaps = hex.substring(nextIndex, bitmapLastIndex);
    string dataString = hex.substring(bitmapLastIndex);

    string correlationId = uuid:createType4AsString();
    // parse ISO 8583 message
    string convertedMti = check hexStringToString(mtiMsg.padZero(4));
    string convertedDataString = check hexStringToString(dataString);

    log:printDebug(string `[XPay driver] Decoded message successfully.`, 
        MTI = convertedMti, Bitmaps= bitmaps, Data= convertedDataString);
    string msgToParse = convertedMti + bitmaps + convertedDataString;
    log:printDebug(string `[XPay driver] Parsing the iso 8583 message.`, Message = msgToParse);

    anydata|iso8583:ISOError parsedISO8583Msg = iso8583:parse(msgToParse);

    if (parsedISO8583Msg is iso8583:ISOError) {
        log:printError("[XPay driver] Error occurred while parsing the ISO 8583 message", err = parsedISO8583Msg);
        return error("Error occurred while parsing the ISO 8583 message: " + parsedISO8583Msg.message);
    }
    match convertedMti {
        TYPE_MTI_0200 => {
            // validate the parsed ISO 8583 message
            iso8583:MTI_0200 validatedMsg = check constraint:validate(parsedISO8583Msg);
            // resolve destination country
            string destinationIdentifier = getDataFromField120(parseField120(validatedMsg.EftTlvData), "007");
            string|error destinationCountryCode = getDestinationCountry(destinationIdentifier);
            if (destinationCountryCode is error) {
                log:printError("[XPay driver] Error while resolving destination country: "
                    + destinationCountryCode.message());
                return sendError("06", convertedMti, validatedMsg);
            }
            // send the transformed ISO 20022 message to the destination driver
            // resolve accounts lookup and payment requests
            boolean isAccountsLookUpReq = isAccountsLookUpRequest(validatedMsg, TYPE_MTI_0200);
            json|error responseJson;
            if (isAccountsLookUpReq) {
                log:printDebug("[XPay driver] Sending accounts lookup request to the hub.");
                models:AccountLookupRequest accountLookupRequest = transformToAccountLookupRequest(validatedMsg);
                responseJson = utils:sendAccountsLookUpRequestToHub(destinationCountryCode, 
                    accountLookupRequest.toJson(), correlationId);
            } else {
                // transform to ISO 20022 message
                iso20022:FIToFICstmrCdtTrf|error iso20022Msg = transformMTI200ToISO20022(validatedMsg);

                if (iso20022Msg is error) {
                    log:printError("[XPay driver] Error while transforming to ISO 20022 message: " 
                        + iso20022Msg.message());
                    return sendError("06", convertedMti, validatedMsg);
                }
                log:printDebug("[XPay driver] Sending payments request to the hub.");
                responseJson = utils:sendPaymentRequestToHub(destinationCountryCode, iso20022Msg.toJson(), 
                    correlationId);
            }

            if (responseJson is error) {
                log:printError("[XPay driver] Network failure while connecting to the payments hub.");
                return sendError("92", convertedMti, validatedMsg);
            }
            //transform response
            iso20022:FIToFIPmtStsRpt|error iso20022Response = constraint:validate(responseJson);
            if (iso20022Response is error) {
                log:printError("[XPay driver] Error while transforming response to ISO 20022: " 
                    + iso20022Response.message());
                return sendError("06", convertedMti, validatedMsg);
            }
            // transform to ISO 8583 MTI 0210
            iso8583:MTI_0210|error mti0210msg = transformPacs002toMTI0210(iso20022Response, validatedMsg);
            if (mti0210msg is error) {
                log:printError("[XPay driver] Error while transforming to ISO 8583 MTI 0210: " + mti0210msg.message());
                return sendError("06", convertedMti, validatedMsg);
            }
            json jsonMsg = check jsondata:toJson(mti0210msg);
            // transform to ISO 8583 message
            log:printDebug(string `[XPay driver] Encoding response message to iso 8583.`, Message = jsonMsg);
            string|iso8583:ISOError iso8583Msg = iso8583:encode(jsonMsg);
            if (iso8583Msg is iso8583:ISOError) {
                log:printError("[XPay driver] Error occurred while encoding the ISO 8583 message", err = iso8583Msg);
                return sendError("06", convertedMti, validatedMsg);
            }
            log:printDebug("[XPay driver] ISO 8583 message encoded successfully : " + iso8583Msg);
            byte[]|error responsebytes = build8583Response(iso8583Msg);
            if responsebytes is error {
                log:printError("[XPay driver] Error occurred while building the response message: " 
                    + responsebytes.message());
                return sendError("06", convertedMti, validatedMsg);
            }
            log:printDebug("[XPay driver] Response: " + responsebytes.toString());
            return responsebytes;
        }
        TYPE_MTI_0800 => {
            log:printDebug("[XPay driver] MTI 0800 message received");
            iso8583:MTI_0800 validatedMsg = check constraint:validate(parsedISO8583Msg);
            iso8583:MTI_0810 responseMsg = transformMTI0800toMTI0810(validatedMsg);
            string|iso8583:ISOError encodedMsg = iso8583:encode(responseMsg);
            if (encodedMsg is iso8583:ISOError) {
                log:printError("[XPay driver] Error occurred while encoding the ISO 8583 message", err = encodedMsg);
                return sendError("06", convertedMti, validatedMsg);
            }
            byte[]|error responsebytes = build8583Response(encodedMsg);
            if responsebytes is error {
                log:printError("[XPay driver] Error occurred while building the response message: " 
                    + responsebytes.message());
                return sendError("06", convertedMti, validatedMsg);
            }
            return responsebytes;
        }
        _ => {
            log:printError("[XPay driver] MTI is not supported");
            return error("MTI is not supported");
        }
    }
};
