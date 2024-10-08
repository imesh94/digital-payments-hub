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

import ballerina/log;

map<models:DriverRegisterModel> driverMap = {};

function registerDriver(models:DriverRegisterModel registerPayload) returns models:DriverRegisterModel {

    driverMap[registerPayload.countryCode] = registerPayload;
    log:printInfo(registerPayload.driverName + " driver registered in payments hub with code " +
                registerPayload.countryCode);
    return registerPayload;
}

function getDriverRegistrationData(string countryCode) returns models:DriverRegisterModel? {

    models:DriverRegisterModel? registrationData = driverMap[countryCode];
    return registrationData;
}

# Return payments endpoint corresponding to the given country code.
#
# + countryCode - two character country code
# + return - payments endpoint
function getGatewayEndpointForCountry(string countryCode) returns string {

    models:DriverRegisterModel? registrationData = driverMap[countryCode];

    if (registrationData is models:DriverRegisterModel) {
        return registrationData.driverGatewayUrl;
    }
    return "";
}
