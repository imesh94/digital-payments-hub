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

import ballerina/time;
import ballerina/random;
import ballerina/http;

isolated function generateXBusinessMsgId(string bicCode) returns string|error {

    time:Utc utcTime = time:utcNow();
    time:Civil date = time:utcToCivil(utcTime);
    string currentDate = date.year.toString() + date.month.toString().padZero(2) + date.day.toString().padZero(2);
    string originator = "O";
    string channelCode = "RB";
    int randomNumber = check random:createIntInRange(1, 99999999);
    string sequenceNumber = randomNumber.toString().padZero(8);
    return currentDate + bicCode + PROXY_RESOLUTION_ENQUIRY_TRANSACTION_CODE + originator + channelCode 
        + sequenceNumber;
};

public service class ResponseErrorInterceptor {
    *http:ResponseErrorInterceptor;
    remote isolated function interceptResponseError(error err) returns http:BadRequest {
        // In this case, all the errors are sent as `400 BadRequest` responses with a customized
        // media type and body. Moreover, you can send different status code responses according to
        // the error type.        
        return {
            mediaType: "application/json",
            // todo - use camt029 
            body: {message: err.message()}
        };
    }
}
