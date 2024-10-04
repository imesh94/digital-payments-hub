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

configurable int servicePort = 9100;

service /payments\-hub on new http:Listener(servicePort) {

    resource function post cross\-border/payments(@http:Header string Country\-Code, models:TransactionsRequest payload)
        returns json {

        log:printDebug("Received payment request payload: " + payload.toJsonString());
        json responseJson = sendPaymentRequestToTargetDriver(Country\-Code, payload);
        return responseJson;
    }

    resource function post cross\-border/accounts/look\-up(@http:Header string Country\-Code,
            models:AccountLookupRequest payload) returns json|models:AccountLookupResponse|models:ErrorResponse {

        // ToDo : Return lookup response
        log:printDebug("Received lookup request payload: " + payload.toJsonString());
        json responseJson = sendLookupRequestToTargetDriver(Country\-Code, payload);
        return responseJson;
    }

    resource function get discover() returns models:DriverRegisterModel[] {

        log:printDebug("Received discover request for all countries");
        models:DriverRegisterModel[] driverArray = driverMap.toArray();
        return driverArray;
    }

    resource function get discover/[string countryCode]() returns models:DriverRegisterModel|http:NotFound {

        log:printDebug("Received discover request for country code " + countryCode);
        models:DriverRegisterModel? discoveryData = driverMap[countryCode];
        if discoveryData is () {
            return http:NOT_FOUND;
        } else {
            return discoveryData;
        }
    }

    resource function post register(@http:Payload models:DriverRegisterModel registerPayload)
        returns models:DriverRegisterModel {

        log:printDebug("Received driver registration request");
        return registerDriver(registerPayload);
    }

    resource function get register/[string countryCode]() returns models:DriverRegisterModel|http:NotFound {

        log:printDebug("Received get registration data request for country code " + countryCode);
        models:DriverRegisterModel? registrationData = getDriverRegistrationData(countryCode);
        if registrationData is () {
            return http:NOT_FOUND;
        } else {
            return registrationData;
        }
    }
}
