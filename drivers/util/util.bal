import ballerina/log;
import ballerina/tcp;
import ballerina/lang.runtime;

public function initializeDriverListeners(DriverConfig driverConfig, tcp:ConnectionService driverTCPConnectionService) returns error? {
    if ("tcp" == driverConfig.transport) {
        check initiateNewTCPListener(driverConfig, driverTCPConnectionService);
    // } else if ("http" == driverConfig.inbound.transport) {
    //     check initiateNewHTTPListener(driverConfig);
    } else {
        return error("Invalid transport configured for the driver.");
    }
}

function initiateNewTCPListener(DriverConfig driver, tcp:ConnectionService driverTCPConnectionService) returns error? {
    
    tcp:Listener tcpListener = check new tcp:Listener(driver.port);
    tcp:Service tcpService = service object {
        function onConnect(tcp:Caller caller) returns tcp:ConnectionService|error {
            log:printInfo("Client connected to port: " + driver.port.toString());
            return driverTCPConnectionService;
        }
    };
    check tcpListener.attach(tcpService);
    check tcpListener.'start();
    runtime:registerListener(tcpListener);
    log:printInfo("Started " + driver.name + " listener on port: " + driver.port.toString());
    log:printInfo("Initialized http client for driver " + driver.name + " at " + driver.baseUrl);
};
