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

import drivers.paynet.models;

import ballerinax/financial.iso20022;

function transformPrxy004toPacs002(models:PrxyLookUpRspnCBFT prxyLookUpRspnCbft)
    returns iso20022:FIToFIPmtStsRpt => {
    GrpHdr: {
        MsgId: prxyLookUpRspnCbft.GrpHdr.MsgId,
        CreDtTm: prxyLookUpRspnCbft.GrpHdr.CreDtTm,
        NbOfTxs: 1,
        OrgnlBizQry: {
            MsgId: "",
            MsgNmId: prxyLookUpRspnCbft.OrgnlGrpInf.OrgnlMsgNmId,
            CreDtTm: prxyLookUpRspnCbft.OrgnlGrpInf.OrgnlCreDtTm ?: ""
        }
    },
    TxInfAndSts: {
        InstgAgt: {
            FinInstnId: {
                BICFI: prxyLookUpRspnCbft.GrpHdr.MsgSndr.Agt.FinInstnId.Othr.Id
            }
        },
        OrgnlTxRef: {
            PrvsInstgAgt1Acct: {
                Prxy: {
                    Tp: {
                        Cd: prxyLookUpRspnCbft.LkUpRspn.RegnRspn.Prxy?.Tp,
                        Prtry: prxyLookUpRspnCbft.LkUpRspn.RegnRspn.Prxy?.Val
                    },
                    Id: prxyLookUpRspnCbft.LkUpRspn.RegnRspn.Prxy?.Val ?: ""
                }
            },
            CdtrAgt: {
                FinInstnId: {
                    ClrSysMmbId: {MmbId: getAccountIds(prxyLookUpRspnCbft.LkUpRspn.RegnRspn.Regn)},
                    BICFI: getAgentIds(prxyLookUpRspnCbft.LkUpRspn.RegnRspn.Regn),
                    Nm: getAccountNames(prxyLookUpRspnCbft.LkUpRspn.RegnRspn.Regn)
                }
            },
            Cdtr: {},
            ChrgBr: "",
            Dbtr: {},
            DbtrAgt: {FinInstnId: {}},
            IntrBkSttlmAmt: {\#content: 0, Ccy: ""},
            PmtId: {EndToEndId: ""}

        }
    },
    OrgnlGrpInfAndSts: {
        OrgnlMsgId: prxyLookUpRspnCbft.OrgnlGrpInf.OrgnlMsgId,
        OrgnlMsgNmId: prxyLookUpRspnCbft.OrgnlGrpInf.OrgnlMsgNmId,
        OrgnlCreDtTm: prxyLookUpRspnCbft.OrgnlGrpInf.OrgnlCreDtTm,
        OrgnlNbOfTxs: "1",
        StsRsnInf: {
            Rsn: {
                Cd: prxyLookUpRspnCbft.LkUpRspn.RegnRspn.StsRsnInf?.Cd,
                Prtry: prxyLookUpRspnCbft.LkUpRspn.RegnRspn.StsRsnInf?.Prtry
            }
        }
    }
};

function getAccountIds(models:Regn[]? registers) returns string {
    if (registers is models:Regn[]) {
        
        string result = "";
        foreach models:Regn value in registers {
            result += value.Acct.Id.Othr.Id + "|";
        }
        return result.substring(0, result.length() - 1);
    }
    return "";

};

function getAccountNames(models:Regn[]? registers) returns string {
    if (registers is models:Regn[]) {
        
        string result = ""; 
        foreach models:Regn value in registers {
            result += value.Acct.Nm ?: "" + "|";
        }
        return result.substring(0, result.length() - 1);
    }
    return "";

}

function getAgentIds(models:Regn[]? registers) returns string {
    if (registers is models:Regn[]) {
        
        string result = "";
        foreach models:Regn value in registers {
            result += value.Agt.FinInstnId.Othr.Id + "|";
        }
        return result.substring(0, result.length() - 1);
    }
    return "";

}
isolated function transformPacs008toFundTransfer(iso20022:FIToFICstmrCdtTrf fiToFiCstmrCdtTrf) returns models:fundTransfer|error => {
    data: {
        businessMessageId: check generateXBusinessMsgId(fiToFiCstmrCdtTrf.CdtTrfTxInf[0].DbtrAcct?.Id?.Othr?.Id ?: ""),
        createdDateTime: check getCurrentDateTime(),
        proxy: {
            tp: resolveProxyType(fiToFiCstmrCdtTrf.SplmtryData),
            value: resolveProxy(fiToFiCstmrCdtTrf.SplmtryData)
        },
        account: {
            id: fiToFiCstmrCdtTrf.CdtTrfTxInf[0].DbtrAcct?.Id?.Othr?.Id ?: "",
            name: fiToFiCstmrCdtTrf.CdtTrfTxInf[0].DbtrAcct?.Nm ?: "",
            tp: "CACC",
            accountHolderType: "S"
        },
        secondaryId: {
            tp: "NRIC",
            value: "94771234567"
        }
    }
};

isolated function transformFundTransferResponsetoPacs002(models:fundTransferResponse fundTransferResponse,
        iso20022:FIToFICstmrCdtTrf isoPacs008Msg) returns iso20022:FIToFIPmtStsRpt => {
    GrpHdr: {
        MsgId: fundTransferResponse.data.businessMessageId,
        CreDtTm: fundTransferResponse.data.createdDateTime,
        NbOfTxs: 1,
        OrgnlBizQry: {
            MsgId: isoPacs008Msg.GrpHdr.MsgId,
            MsgNmId: isoPacs008Msg.GrpHdr.MsgId,
            CreDtTm: isoPacs008Msg.GrpHdr.CreDtTm
        }
    },
    TxInfAndSts: {
        InstgAgt: {
            FinInstnId: {
                BICFI: isoPacs008Msg.CdtTrfTxInf[0].DbtrAgt.FinInstnId.Othr?.Id
            }
        }
    },
    OrgnlGrpInfAndSts: {
        OrgnlMsgId: isoPacs008Msg.CdtTrfTxInf[0].PmtId.EndToEndId,
        OrgnlMsgNmId: isoPacs008Msg.GrpHdr.MsgId,
        OrgnlCreDtTm: isoPacs008Msg.GrpHdr.CreDtTm,
        OrgnlNbOfTxs: "1",
        StsRsnInf: {
            Rsn: {
                Cd: fundTransferResponse.data.code,
                Prtry: fundTransferResponse.data.reason
            }
        }
    }
};
