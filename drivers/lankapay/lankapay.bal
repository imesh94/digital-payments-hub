// Copyright 2024 [name of copyright owner]

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ballerina/constraint;
import ballerina/data.jsondata;
import ballerina/http;
import ballerina/log;

import ballerinax/financial.iso8583;
import ballerinax/financial.iso20022;

import digitalpaymentshub/drivers.util;
import ballerina/uuid;


# Handles inbound transactions and return response.
#
# + data - byte array of the incoming message
# + return - byte array of the response message
public function handleInbound(byte[] & readonly data) returns byte[] {

    string|error dataString = string:fromBytes(data);
    if (dataString is error) {
        log:printError("Error occurred while converting the byte array to string", dataString);
        return ("Error occurred while converting the byte array to string: " + dataString.message()).toBytes();
    }

    string correlationId = uuid:createType4AsString();
    util:Event receivedEvent = util:createEvent(correlationId, util:RECEIVED_FROM_SOURCE, 
        driver.code + "-network", driver.code + "-driver", "success", "N/A");
    util:publishEvent(receivedEvent);

    byte[] response = [];
    // parse ISO 8583 message
    anydata|iso8583:ISOError parsedISO8583Msg = iso8583:parse(dataString);

    if (parsedISO8583Msg is iso8583:ISOError) {
        log:printError("Error occurred while parsing the ISO 8583 message", err = parsedISO8583Msg);
        response = ("Error occurred while parsing the ISO 8583 message: " + parsedISO8583Msg.message).toBytes();
    } else {
        map<anydata> parsedISO8583Map = <map<anydata>>parsedISO8583Msg;
        string mti = <string>parsedISO8583Map[MTI];

        match mti {
            TYPE_MTI_0200 => {
                // validate the parsed ISO 8583 message
                iso8583:MTI_0200|error validatedMsg = constraint:validate(parsedISO8583Msg);
                if (validatedMsg is iso8583:MTI_0200) {
                    // transform to ISO 20022 message
                    iso20022:FIToFICstmrCdtTrf|error iso20022Msg = transformMTI200ToISO20022(validatedMsg);
                    if (iso20022Msg is error) {
                        log:printError("Error while transforming to ISO 20022 message: " + iso20022Msg.message());
                        response = ("Error while transforming to ISO 20022 message: " 
                            + iso20022Msg.message()).toBytes();
                    } else {
                        // resolve destination country
                        string|error destinationCountryCode = getDestinationCountry(
                            getDataFromSupplementaryData(iso20022Msg.SplmtryData, DESTINATION_COUNTRY_CODE));
                        if (destinationCountryCode is error) {
                            log:printError("Error while resolving destination country: " 
                                + destinationCountryCode.message());
                            response = ("Error while resolving destination country: " 
                                + destinationCountryCode.message()).toBytes();
                        } else {
                            // send the transformed ISO 20022 message to the destination driver
                            util:Event sendingtoDestinationDriverEvent = 
                                util:createEvent(correlationId, util:FORWARDING_TO_DESTINATION_DRIVER, 
                                driver.code + "-driver", destinationCountryCode + "-driver", "success", "N/A");
                            util:publishEvent(sendingtoDestinationDriverEvent);
                            // todo - do we need this model?
                            util:DestinationResponse|error destinationDriverResponse = 
                                util:sendToDestinationDriver(destinationCountryCode, iso20022Msg.toJson(), 
                                correlationId);
                            util:Event receivedDestinationDriverResponseEvent = 
                                util:createEvent(correlationId, util:RECEIVED_FROM_DESTINATION_DRIVER, 
                                destinationCountryCode + "-driver", driver.code + "-driver", "success", "N/A");
                            util:publishEvent(receivedDestinationDriverResponseEvent);

                            if (destinationDriverResponse is util:DestinationResponse) {
                                //transform response
                                iso20022:FIToFIPmtStsRpt|error iso20022Response = 
                                    constraint:validate(destinationDriverResponse.responsePayload);
                                if (iso20022Response is error) {
                                    log:printError("Error while transforming response to ISO 20022: " 
                                        + iso20022Response.message());
                                    response = ("Error while transforming response to ISO 20022: " 
                                        + iso20022Response.message()).toBytes();
                                } else {
                                    // transform to ISO 8583 MTI 0210
                                    iso8583:MTI_0210|error mti0210msg = transformPacs002toMTI0210(iso20022Response);
                                    if (mti0210msg is error) {
                                        log:printError("Error while transforming to ISO 8583 MTI 0210: " 
                                            + mti0210msg.message());
                                        response = ("Error while transforming to ISO 8583 MTI 0210: " 
                                            + mti0210msg.message()).toBytes();
                                    } else {
                                        json|error jsonMsg = jsondata:toJson(mti0210msg);
                                        if (jsonMsg is error) {
                                            log:printError("Error occurred while converting the ISO 8583 message to JSON", 
                                                err = jsonMsg.message());
                                            response = ("Error occurred while converting the ISO 8583 message to JSON: " 
                                                + jsonMsg.message()).toBytes();
                                        } else {
                                            // transform to ISO 8583 message
                                            string|iso8583:ISOError iso8583Msg = iso8583:encode(jsonMsg);
                                            if (iso8583Msg is iso8583:ISOError) {
                                                log:printError("Error occurred while encoding the ISO 8583 message", 
                                                    err = iso8583Msg);
                                                response = ("Error occurred while encoding the ISO 8583 message: " 
                                                    + iso8583Msg.message).toBytes();
                                            } else {
                                                util:Event respondingtoSourceEvenet = 
                                                    util:createEvent(correlationId, util:RESPONDING_TO_SOURCE,
                                                    driver.code + "-driver", driver.code + "-network", "success", 
                                                    "N/A");
                                                util:publishEvent(respondingtoSourceEvenet);
                                                response = iso8583Msg.toBytes();
                                            }
                                        }
                                    }
                                }
                            } else if (destinationDriverResponse is error) {
                                log:printError("Error while sending message to destination driver: " 
                                    + destinationDriverResponse.message());
                                response = ("Error while sending message to destination driver: " 
                                    + destinationDriverResponse.message()).toBytes();
                            }
                        }
                    }
                } else {
                    log:printError("Error while validating incoming message: " + validatedMsg.message());
                    response = ("Error while validating: " + validatedMsg.toBalString()).toBytes();
                }
            }
            TYPE_MTI_0800 => {
                log:printInfo("MTI 0800 message received");
                iso8583:MTI_0800|error validatedMsg = constraint:validate(parsedISO8583Msg);
                if (validatedMsg  is error) {
                    log:printError("Error while validating incoming message: " + validatedMsg.message());
                    response = ("Error while validating: " + validatedMsg.toBalString()).toBytes();
                } else {
                    iso8583:MTI_0810 responseMsg = transformMTI0800toMTI0810(validatedMsg);
                    string|iso8583:ISOError encodedMsg = iso8583:encode(responseMsg);
                    if (encodedMsg is iso8583:ISOError) {
                        log:printError("Error occurred while encoding the ISO 8583 message", 
                            err = encodedMsg);
                        response = ("Error occurred while encoding the ISO 8583 message: " 
                            + encodedMsg.message).toBytes();
                    } else {
                        util:Event respondingtoSourceEvenet = 
                            util:createEvent(correlationId, util:RESPONDING_TO_SOURCE,
                            driver.code + "-driver", driver.code + "-network", "success", 
                            "N/A");
                        util:publishEvent(respondingtoSourceEvenet);
                        response = encodedMsg.toBytes();
                    }
                }  
            }
            _ => {
                log:printError("MTI is not supported");
                response = ("MTI is not supported").toBytes();
            }
        }
    }
    return response;
};

# Handles outbound transactions.
#
# + payload - iso 20022 json payload
# + return - http response
public function handleOutbound(json payload) returns http:Response {
    // Todo - implement the logic
    return new;
};
