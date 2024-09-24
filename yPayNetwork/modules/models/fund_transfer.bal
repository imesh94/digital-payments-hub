// Copyright 2024 [name of copyright owner]

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

public type fundTransfer record {|
    Data data;
|};

public type Data record {|
    string businessMessageId;
    string createdDateTime;
    Proxy proxy;
    Account account;
    SecondaryId secondaryId;
|};

public type Proxy record {|
    string tp;
    string value;
|}; 

public type Account record {|
    string tp;
    string id;
    string name;
    string accountHolderType;
|};

public type SecondaryId record {|
    string tp;
    string value;
|};

public type fundTransferResponse record {|
    ResposneData data;
|};

public type ResposneData record {|
    string businessMessageId;
    string createdDateTime;
    string code;
    string reason;
    string registrationId;
|};