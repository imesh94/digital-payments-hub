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

// public type DriverConfig record {|
//     DriverRegisterModel driverInfo;
//     InboundConfig inbound;
//     OutboundConfig outbound;
// |};

// public type InboundConfig readonly & record {|
//     string transport;
//     string host;
//     int port;
// |};

// // Structure for the outbound configuration
// public type OutboundConfig readonly & record {|
//     string transport;
//     string host;
//     int port;
// |};


// public type PaymentsHubConfig readonly & record {|
//     string url;
// |};

// [driver]
// name = "sample_driver"
// code = "SD1"

// # inbound url of the driver
// [driver.inbound]
// transport = "tcp"
// host = "localhost"
// port = 8084

// # url of the country switch
// [driver.outbound]
// transport = "tcp"
// host = "localhost"
// port = 8300

// # hub facing api of the driver
// [driver.driver_api]
// host = "localhost"
// port = 9090
// gateway_url = "http://localhost:9090"

// # url of the payments hub
// [payments_hub]
// baseUrl = "http://localhost:9100"

public type DriverConfig record {|
    string name;
    string code;
    InboundConfig inbound;
    OutboundConfig outbound;
    DriverApiConfig driver_api;
|};

public type InboundConfig readonly & record {|
    string transport;
    string host;
    int port;
|};

public type OutboundConfig readonly & record {|
    string transport;
    string host;
    int port;
|};

public type DriverApiConfig record {|
    string host;
    int port;
    string gateway_url;
|};

public type PaymentsHubConfig readonly & record {|
    string base_url;
|};
