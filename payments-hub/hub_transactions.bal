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

import payments_hub.models;

import ballerina/http;
import ballerina/log;

# Send payment message to target driver and get the response.
#
# + countryCode - country code of the target driver  
# + payload - request payload  
# + return - response from the destination driver | error response
function sendPaymentRequestToTargetDriver(string countryCode, models:TransactionsRequest payload)
    returns json {

    http:Request request = new;
    request.setHeader("Content-Type", "application/json");
    request.setPayload(payload.data);

    string paymentsEndpoint = getPaymentsEndpointForCountry(countryCode);
    // ToDo: Cache http clients
    http:Client|error targetHttpClient = new (paymentsEndpoint);
    if (targetHttpClient is http:Client) {
        http:Response|http:ClientError response = targetHttpClient->/.post(request);

        if (response is http:Response) {
            int responseStatusCode = response.statusCode;
            json|http:ClientError responsePayload = response.getJsonPayload();

            if (responseStatusCode == 200 && responsePayload is json) {
                return responsePayload;
            } else if (responsePayload is json) {
                log:printError("Error returned from the target driver");
                log:printDebug(responsePayload.toJsonString());
                return responsePayload;
            } else {
                log:printError("Error occurred while forwarding request to the destination driver");
                json errorResponse = {
                    "error": "Error occurred while processing response",
                    "statusCode": responseStatusCode
                };
                return errorResponse;
            }
        } else {
            log:printError("Client error occurred while sending request");
            json clientErrorResponse = {
                "error": "Failed to get a valid response from the target",
                "details": response.message()
            };
            return clientErrorResponse;
        }

    } else {
        // TargetHttpClient is not initialized properly
        log:printError("Error creating HTTP client for the target");
        json clientInitError = {"error": "Failed to initialize client", "details": targetHttpClient.message()};
        return clientInitError;
    }
}

# Send lookup message to target driver and get the response.
#
# + countryCode - country code of the target driver  
# + payload - request payload  
# + return - response from the destination driver | error response
function sendLookupRequestToTargetDriver(string countryCode, models:AccountLookupRequest payload)
    returns json {

    http:Request request = new;
    request.setHeader("Content-Type", "application/json");
    request.setPayload(payload.toJson());

    string paymentsEndpoint = getPaymentsEndpointForCountry(countryCode);
    // ToDo: Cache http clients
    http:Client|error targetHttpClient = new (paymentsEndpoint);
    if (targetHttpClient is http:Client) {
        http:Response|http:ClientError response = targetHttpClient->/.post(request);

        if (response is http:Response) {
            int responseStatusCode = response.statusCode;
            json|http:ClientError responsePayload = response.getJsonPayload();

            if (responseStatusCode == 200 && responsePayload is json) {
                return responsePayload;
            } else if (responsePayload is json) {
                log:printError("Error returned from the target driver");
                log:printDebug(responsePayload.toJsonString());
                return responsePayload;
            } else {
                log:printError("Error occurred while forwarding request to the destination driver");
                json errorResponse = {
                    "error": "Error occurred while processing response",
                    "statusCode": responseStatusCode
                };
                return errorResponse;
            }
        } else {
            log:printError("Client error occurred while sending request");
            json clientErrorResponse = {
                "error": "Failed to get a valid response from the target",
                "details": response.message()
            };
            return clientErrorResponse;
        }

    } else {
        // TargetHttpClient is not initialized properly
        log:printError("Error creating HTTP client for the target");
        json clientInitError = {"error": "Failed to initialize client", "details": targetHttpClient.message()};
        return clientInitError;
    }
}

//function getAccountLookupResponseFromJson(json lookupResponse) returns AccountLookupResponse {
// ToDo
//}
