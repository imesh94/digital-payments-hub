import ballerina/log;
import ballerina/tcp;
import digitalpaymentshub/drivers.util;


configurable util:DriverConfig driver = ?;

public function main() returns error? {
    // register the service
    // connection initialization
    check util:initializeDriverListeners(driver, new DriverTCPConnectionService(driver.name));
}

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {
        log:printInfo("Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns byte[]|error|tcp:Error? {

        byte[] response = check handleInbound(data);
        log:printDebug("Responding to origin of the payment");
        return response;
    }

    function onError(tcp:Error err) {

        log:printError("An error occurred", 'error = err);
    }

    function onClose() {

        log:printInfo("Client left");
    }
}