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

// This file contains the structure mapping to PayNet proxy model.
// https://docs.developer.paynet.my/docs/API-standards/message-signature-qr

public type PrxyLookUpCBFT record {|
    GrpHdr GrpHdr;
    CdtTrfTxInf CdtTrfTxInf;
    LookUp LookUp;
|};

public type PrxyLookUpRspnCBFT record {|
    GrpHdr GrpHdr;
    OrgnlGrpInf OrgnlGrpInf;
    LkUpRspn LkUpRspn;
|};

public type GrpHdr record {|
    string MsgId;
    string CreDtTm;
    MsgSndr MsgSndr;
    TpOfSubmitr TpOfSubmitr?;
|};

public type MsgSndr record {|
    Agt Agt;
|};

public type Agt record {|
    FinInstnId FinInstnId;
|};

public type FinInstnId record {|
    Othr Othr;
|};

public type Othr record {|
    string Id;
|};

public type TpOfSubmitr record {|
    string Cd;
|};

public type CdtTrfTxInf record {|
    string InstdAmt;
    string InstdAmtCcy;
    Dbtr Dbtr;
    Acct DbtrAcct;
|};

public type Dbtr record {|
    string Nm;
|};

public type Acct record {|
    Id Id;
    Tp Tp?;
|};

public type DebtrAcct record {|
    *Acct;
    string Nm?;
|};

public type Id record {|
    Othr Othr;
|};

public type Tp record {|
    string Prtry;
|};

public type LookUp record {|
    PrxyOnly PrxyOnly;
    CustomData CustomData?;
|};

public type PrxyOnly record {|
    string LkUpTp;
    string Id;
    string DestCountryCode;
    string DestCountryBankCode?;
    Requester PrxyRtrvl;
|};

public type CustomData record {|
    string Field1?;
    string Field2?;
    string Field3?;
    string Field4?;
    string Field5?;
    string Field6?;
    string Field7?;
    string Field8?;
    string Field9?;
    string Field10?;
    Requester PrxyRqstr?;
    string DsplNm?;
    Tp AcctTp?;
|};

public type OrgnlGrpInf record {|
    string OrgnlMsgId;
    string OrgnlMsgNmId;
    string OrgnlCreDtTm?;
|};

public type LkUpRspn record {|
    string OrgnlId;
    Requester OrgnlPrxyRtrvl;
    Requester OrgnlPrxyRqstr?;
    string OrgnlDspNm?;
    Tp OrgnlAcctTp?;
    RegnRspn RegnRspn;
|};

public type Requester record {|
    string Tp;
    string Val;
|};

public type RegnRspn record {|
    string PrxRspnSts;
    StsRsnInf StsRsnInf?;
    Requester Prxy?;
    string LkUpRef?;
    Regn Regn?;
    CustomData CustomData?;
|};

public type StsRsnInf record {|
    string Cd;
    string Prtry;
|};

public type Regn record {|
    string RegnId;
    string DsplNm;
    Agt Agt;
    DebtrAcct Acct;
    string PreAuthrsd;
|};
