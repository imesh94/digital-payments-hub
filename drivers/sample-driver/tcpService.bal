import ballerina/log;
import ballerina/tcp;

import digitalpaymentshub/drivers.util;

configurable util:DriverConfig driver = ?;
configurable map<string> payment_hub = ?;
configurable map<string> payment_network = ?;

public function main() returns error? {

    check util:registerDriverAtHub(driver.name, driver.code, driver.outbound.baseUrl);
    check util:initializeDriverListeners(driver, new DriverTCPConnectionService(driver.name));
    check util:initializeDriverHttpClients(payment_hub["baseUrl"], payment_network["baseUrl"]);
    check util:initializeDestinationDriverClients();
}

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {

        log:printInfo("Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns byte[]|error|tcp:Error? {

        log:printInfo("Received inbound request");
        // Publish event

        // Convert data to iso20022
        json sampleJson = {"data": "sample data"};

        // Send to destination driver
        log:printInfo("Forwarding request to destination driver");
        json destinationResponse = check util:sendToDestinationDriver("MY", sampleJson, "correlation-id");
        log:printInfo("Response received from destination driver: " + destinationResponse.toString());

        // Convert response to iso8583

        // Respond
        log:printInfo("Responding to source");
        return data;
    }

    function onError(tcp:Error err) {
        log:printError("An error occurred", 'error = err);
    }

    function onClose() {
        log:printInfo("Client left");
    }
}
