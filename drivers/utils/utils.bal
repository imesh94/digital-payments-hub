import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/tcp;

http:Client hubClient = check new ("localhost:9090");
map<http:Client> httpClientMap = {};

type Metadata readonly & record {
    string driver;
    string countryCode;
    string inboundEndpoint;
    string paymentEndpoint;
};

public function initializeDriverListeners(DriverConfig driverConfig, tcp:ConnectionService|
        HTTPConnectionService driverConnectionService)
    returns error? {

    if ("tcp" == driverConfig.inbound.transport && driverConnectionService is tcp:ConnectionService) {
        check initiateNewTCPListener(driverConfig, driverConnectionService);
    } else if ("http" == driverConfig.inbound.transport && driverConnectionService is HTTPConnectionService) {
        check initiateNewHTTPListener(driverConfig, driverConnectionService);
    } else {
        return error("Invalid transport configured for the driver.");
    }
}

public function initializeDestinationDriverClients() returns error? {

    // ToDo: This should be called by a periodic scheduler
    Metadata[] metadataList = check getdriverMetadataFromHub();

    foreach var metadata in metadataList {
        http:Client driverHttpClient = check new (metadata.paymentEndpoint);
        // Add the client to the map with countryCode as the key
        httpClientMap[metadata.countryCode] = driverHttpClient;
    }
}

public function registerDriverAtHub(string driverName, string countryCode, string paymentsEndpoint) returns error? {

    log:printInfo("Registering driver at payments hub.");
    json registerResponse = check hubClient->/payments\-hub/register.post({
        driverName: driverName,
        countryCode: countryCode,
        paymentsEndpoint: paymentsEndpoint
    });

    // ToDo: Add error handling and retry logic
    log:printInfo("\nRegistration response from hub:" + registerResponse.toJsonString());

}

public function sendToDestinationDriver(string countryCode, json data) returns json|error? {
    // ToDo
}

public function sendToPaymentNetwork(json data) returns json|error? {
    // ToDo
}

public function publishEvent(Event event) {

    log:printInfo("Publishing event to payments hub.");
    json|http:ClientError eventResponse = hubClient->/payments\-hub/events.post(event.toJson());
    if (eventResponse is error) {
        log:printInfo("Error occurred when publishing event");
    } else {
        log:printInfo("\n Event published:" + event.toJsonString());
    }
}

function getdriverMetadataFromHub() returns Metadata[]|error {

    Metadata[]|http:ClientError metadataList = hubClient->get("/payments-hub/metadata");

    if (metadataList is error) {
        log:printError("Error occurred when getting driver metadata from payments hub");
        return error("Error occurred when getting driver metadata from payments hub", metadataList);
    }
    return metadataList;
}

function initiateNewTCPListener(DriverConfig driver, tcp:ConnectionService driverTCPConnectionService) returns error? {

    tcp:Listener tcpListener = check new tcp:Listener(driver.inbound.port);
    tcp:Service tcpService = service object {
        function onConnect(tcp:Caller caller) returns tcp:ConnectionService|error {
            log:printInfo("Client connected to port: " + driver.inbound.port.toString());
            return driverTCPConnectionService;
        }
    };
    check tcpListener.attach(tcpService);
    check tcpListener.'start();
    runtime:registerListener(tcpListener);
    log:printInfo("Started " + driver.name + " TCP listener on port: " + driver.inbound.port.toString());
};

public function initiateNewHTTPListener(DriverConfig driver, HTTPConnectionService driverHTTPConnectionService)
    returns error? {

    http:Listener httpListener = check new http:Listener(driver.inbound.port);
    http:Service httpService = service object {
        resource function post .(http:Caller caller, http:Request req) returns error? {
            log:printInfo("Client connected to HTTP service on port: " + driver.inbound.port.toString());
            check driverHTTPConnectionService.onRequest(caller, req);
        }
    };

    check httpListener.attach(httpService);
    check httpListener.'start();
    runtime:registerListener(httpListener);
    log:printInfo("Started " + driver.name + " HTTP listener on port: " + driver.inbound.port.toString());
}

# Represent HTTP Listener ConnectionService service type.
public type HTTPConnectionService distinct service object {

    function onRequest(http:Caller caller, http:Request req) returns error?;
};
