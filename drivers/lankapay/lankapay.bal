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
import ballerina/http;
import ballerina/log;
import ballerinax/financial.iso8583;
import ballerinax/financial.iso20022;

import digital.payments.hub.lankapay.util;
import digitalpaymentshub/digital.payments.hub.driver_manager;

service /lankaPay on new http:Listener(9091) {


    # Inbound endpoint of LanakPay ISO 8583 messages.
    #
    # + caller - http caller
    # + req - http request
    # + return - return value description
    isolated resource function post inbound(http:Caller caller, http:Request req) returns error? {

        // Extract the string payload from the request
        string payload = check req.getTextPayload();
        
        anydata|iso8583:ISOError parsedISO8583Msg = iso8583:parse(payload);

        anydata|error response;
        if(parsedISO8583Msg is iso8583:ISOError) {
            log:printError("Error occurred while parsing the ISO 8583 message", err = parsedISO8583Msg);
            response = error("Error occurred while parsing the ISO 8583 message");
        } else {
            map<anydata> parsedISO8583Map = <map<anydata>>parsedISO8583Msg;
            string mti = <string>parsedISO8583Map[util:MTI];

            match mti {
                util:TYPE_MTI_0200 => {
                    // validate the parsed ISO 8583 message
                    iso8583:MTI_0200|error validatedMsg = constraint:validate(parsedISO8583Msg);

                    if (validatedMsg is iso8583:MTI_0200) {
                        // transform to ISO 20022 message
                        iso20022:FIToFICstmrCdtTrf iso20022Msg = transformMTI200ToISO20022(validatedMsg);

                        // Todo implement driver switching logic
                        // call driver manager 
                        // Todo - need to refactor
                        anydata|error? outboundResult = driver_manager:switchToOutboundDriver(iso20022Msg, "paynet");
                        if outboundResult is error {
                            log:printError("Error while retrieving proxy resolution response: " 
                                + outboundResult.message());
                            response = error("Error while retrieving proxy resolution response: " 
                                + outboundResult.message());
                        } else {
                            response = outboundResult;
                        }
                    } else {
                        log:printError("Error while validating incoming message: " + validatedMsg.message());
                        response = error("Error while validating: " + validatedMsg.toBalString());
                    }
                }
                _ => {
                    log:printError("MTI is not supported");
                    response = error("MTI is not supported");
                }
            }
        }
        // return response;
        check caller->respond(response);
    };


}

isolated function transformMTI200ToISO20022(iso8583:MTI_0200 mti0200) returns iso20022:FIToFICstmrCdtTrf => {
    GrpHdr: {
        MsgId: mti0200.ProcessingCode,
        CreDtTm: mti0200.TransmissionDateTime,
        NbOfTxs: 1,
        SttlmInf: {
            SttlmMtd: "CLRG"
        }
    },
    CdtTrfTxInf: [],
    SplmtryData: mapSupplementaryData(parseField120(mti0200.EftTlvData))
};

isolated function mapSupplementaryData(map<string> supplementaryData) returns iso20022:SplmtryData[] {

    iso20022:SplmtryData[] splmtryDataArray = [];
    foreach string dataElement in supplementaryData.keys() {
        
        iso20022:Envlp envlp = {'key: dataElement, value: supplementaryData.get(dataElement)};
        iso20022:SplmtryData splmtryDataElement = {Envlp: envlp};
        splmtryDataArray.push(splmtryDataElement);
    }
    return splmtryDataArray;
}

isolated function parseField120(string field120) returns map<string> {

    map<string> field120Parts = {};
    int i = 0;
    while i < field120.length() {
        string tagId = field120.substring(i, i + 3);
        int elementLength = check int:fromString(field120.substring(i + 3, i + 6));
        string data = field120.substring(i + 6, i + 6 + elementLength);
        field120Parts[tagId] = data;
        i = i + 6 + elementLength;
    } on fail var e {
    	log:printError("Error while parsing field 120: " + e.message());
    }
    return field120Parts;
}

isolated function outbound(anydata iso) returns anydata|error? {
    // Todo implement outbound logic
    return "Outbound message";

}