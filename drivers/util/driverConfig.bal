public type DriverConfig readonly & record {
    string name;
    string code;
    string transport;
    int port;
    string baseUrl;
};
