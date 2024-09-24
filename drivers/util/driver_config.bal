public type DriverConfig readonly & record {
    string name;
    string code;
    InboundConfig inbound;
    OutboundConfig outbound;
};

public type InboundConfig readonly & record {
    string transport;
    int port;
};

// Structure for the outbound configuration
public type OutboundConfig readonly & record {
    string baseUrl?;
    string host;
    int port;
};