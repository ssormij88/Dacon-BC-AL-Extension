codeunit 50100 NavAccess
{
    var
        PurchInvoice: Record "Purchase Header";
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        DimSetEntry: Record "Dimension Set Entry";
        DimMgt: Codeunit DimensionManagement;
        GenJournalBatch: Record "Gen. Journal Batch";
        JournalBatchName: Code[30];
        GenJnlTemplate: Record "Gen. Journal Template";
        GenJournalLine: Record "Gen. Journal Line";
    //ARS RET SALES HEADER
    procedure CreatePurchaseInvoiceHeader(vendorNo: Code[20]): Text
    var
        jVendor: Record Vendor;
        //  JSONProperty: JsonObject;
        Output: Text;
    begin
        // jVendor.ChangeCompany(jCompany);
        jVendor.Reset();
        jVendor.SetRange("No.", vendorNo);
        IF jVendor.FINDFIRST THEN BEGIN
            PurchInvoice.INIT;
            PurchInvoice."Document Type" := PurchInvoice."Document Type"::Invoice;
            PurchInvoice.VALIDATE("Buy-from Vendor No.", jVendor."No.");
            PurchInvoice."Posting Date" := WorkDate();

            PurchInvoice.INSERT(TRUE);

            EXIT(PurchInvoice."No.");
        END;

        EXIT('NOT OK');
    end;

    procedure ProcedureJson(vendorNo: Code[20]; name: text[50]): Text
    var
        JSONProperty: JsonObject;
        Output: Text;
        JsonArray: JsonArray;
    begin
        Clear(JSONProperty);
        JSONProperty.Add('No:', PurchInvoice."No.");
        JSONProperty.Add('Name:', PurchInvoice."Pay-to Name");
        JSONProperty.Add('Status:', 'OK');

        JsonArray.Add(JSONProperty);
        JsonArray.WriteTo(Output);
        EXIT(Output);
    end;

    //ARS RET PAYMENT SALES LINE
    procedure CreateSalesInvoiceLine(pPINo: Code[20]; estateTax: Decimal; description: Text[50]; assetNo: Code[50]; lineNo: Integer): Integer
    var
        jLineNo: Integer;
        PurchInvLine: Record "Purchase Line";

    begin
        //JRV
        jLineNo := 10000;

        PurchInvLine.RESET;
        PurchInvLine.SETRANGE("Document Type", PurchInvLine."Document Type"::Invoice);
        PurchInvLine.SETRANGE("Document No.", pPINo);
        IF PurchInvLine.FINDLAST THEN
            jLineNo := PurchInvLine."Line No." + 10000;


        PurchInvLine.RESET;
        PurchInvLine.SETRANGE("Document Type", PurchInvLine."Document Type"::Invoice);
        PurchInvLine.SETRANGE("Document No.", PPINo);
        //PurchInvLine.SETRANGE("Asset No.",AssetNo);
        PurchInvLine.SETRANGE("Line No.", lineNo);

        IF NOT PurchInvLine.FINDFIRST THEN BEGIN
            PurchInvLine.INIT;
            PurchInvLine."Document Type" := PurchInvLine."Document Type"::Invoice;

            PurchInvLine."Document No." := pPINo;
            PurchInvLine."Line No." := jLineNo;
            PurchInvLine.Type := PurchInvLine.Type::"G/L Account";

            PurchInvLine.VALIDATE("No.", '603011');
            PurchInvLine.VALIDATE(Quantity, 1);
            PurchInvLine.VALIDATE("Direct Unit Cost", estateTax);
            PurchInvLine.Description := description;

            // PurchInvLine."Asset No." := AssetNo;
            PurchInvLine.VALIDATE("Gen. Bus. Posting Group", 'DOMESTIC');
            PurchInvLine.VALIDATE("Gen. Prod. Posting Group", 'GL');

            PurchInvLine.VALIDATE("VAT Prod. Posting Group", 'EXEMPT');
            PurchInvLine.VALIDATE("VAT Bus. Posting Group", 'VEXEMPT');


            PurchInvLine.INSERT;
        END ELSE BEGIN
            jLineNo := PurchInvLine."Line No.";
            PurchInvLine.VALIDATE("Direct Unit Cost", estateTax);
            PurchInvLine.VALIDATE(Quantity, 1);
            PurchInvLine.Description := description;
            PurchInvLine.MODIFY;
        END;

        EXIT(jLineNo);
    end;

    //ARS RET SALES LINE DIMENSION
    procedure CreatePuchJnlDimension(pPINNo: Code[20]; dimCode: Code[20]; dimValue: Code[20])
    var
        OldDimSetID: Integer;
        NewDimSetID: Integer;

    begin
        PurchInvoice.RESET;
        PurchInvoice.SETRANGE("Document Type", PurchInvoice."Document Type"::Invoice);
        PurchInvoice.SETRANGE("No.", pPINNo);
        IF PurchInvoice.FINDFIRST THEN BEGIN
            OldDimSetID := PurchInvoice."Dimension Set ID";


            TempDimSetEntry.DELETEALL;
            DimMgt.GetDimensionSet(TempDimSetEntry, OldDimSetID);


            //DIMENSION
            TempDimSetEntry.DELETEALL;

            DimSetEntry.RESET;
            DimSetEntry.SETRANGE("Dimension Set ID", PurchInvoice."Dimension Set ID");
            IF DimSetEntry.FINDSET THEN BEGIN
                REPEAT
                    TempDimSetEntry.RESET;
                    TempDimSetEntry.SETRANGE("Dimension Code", DimSetEntry."Dimension Code");
                    TempDimSetEntry.SETRANGE("Dimension Value Code", DimSetEntry."Dimension Value Code");
                    IF NOT TempDimSetEntry.FINDFIRST THEN BEGIN
                        TempDimSetEntry.INIT;
                        TempDimSetEntry.VALIDATE("Dimension Code", DimSetEntry."Dimension Code");
                        TempDimSetEntry.VALIDATE("Dimension Value Code", DimSetEntry."Dimension Value Code");
                        TempDimSetEntry.INSERT;
                    END;
                UNTIL DimSetEntry.NEXT = 0;
            END;

            TempDimSetEntry.RESET;
            TempDimSetEntry.SETRANGE("Dimension Code", dimCode);
            TempDimSetEntry.SETRANGE("Dimension Value Code", dimValue);
            IF NOT TempDimSetEntry.FINDFIRST THEN BEGIN
                TempDimSetEntry.INIT;
                TempDimSetEntry.VALIDATE("Dimension Code", dimCode);
                TempDimSetEntry.VALIDATE("Dimension Value Code", dimValue);
                TempDimSetEntry.INSERT;
            END;
            TempDimSetEntry.RESET;
            NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry); //get new DimSetID, after existing PO dimensions are modified


            IF OldDimSetID <> NewDimSetID THEN BEGIN
                PurchInvoice."Dimension Set ID" := NewDimSetID; //assign new DimSetID 
                PurchInvoice.MODIFY;
            END;
        END;
    end;

    procedure GetNextNoSeries(nSeries: Code[50]): Code[20]
    var
        NoSeriesMgt: Codeunit "No. Series";
    begin
        EXIT(NoSeriesMgt.GetNextNo(NSeries, WORKDATE, TRUE));
    end;

    procedure CreateJournalBatches(jTemplate: Code[30]; jBatchName: Code[30]; batchNoSeries: Code[30]): Integer
    var
        jLineNo: Integer;

    begin
        jLineNo := 10000;
        GenJournalBatch.RESET;
        GenJournalBatch.SETRANGE("Journal Template Name", jTemplate);
        GenJournalBatch.SETRANGE(Name, JBatchName);
        IF NOT GenJournalBatch.FINDFIRST THEN BEGIN
            JournalBatchName := JBatchName;// NoSeriesMgt.GetNextNo('ARS-RENTAL',WORKDATE,TRUE);
            GenJnlTemplate.RESET;
            GenJnlTemplate.GET(jTemplate);
            //JournalBatchName :=  NoSeriesMgt.GetNextNo('ARS-RENTAL',WORKDATE,TRUE);
            GenJournalBatch.INIT;
            GenJournalBatch.Name := JournalBatchName;
            GenJournalBatch."Journal Template Name" := jTemplate;
            GenJournalBatch."Bal. Account Type" := GenJnlTemplate."Bal. Account Type";
            GenJournalBatch."Bal. Account No." := GenJnlTemplate."Bal. Account No.";
            GenJournalBatch."No. Series" := BatchNoSeries; //'GJNL-RCPT';;
            GenJournalBatch."Posting No. Series" := GenJnlTemplate."Posting No. Series";
            GenJournalBatch."Reason Code" := GenJnlTemplate."Reason Code";
            GenJournalBatch."Copy VAT Setup to Jnl. Lines" := GenJnlTemplate."Copy VAT Setup to Jnl. Lines";
            GenJournalBatch."Allow VAT Difference" := GenJnlTemplate."Allow VAT Difference";
            GenJournalBatch.INSERT(TRUE);
        END;
        GenJournalLine.RESET;
        GenJournalLine.SETRANGE("Journal Template Name", jTemplate);
        GenJournalLine.SETRANGE("Journal Batch Name", JBatchName);
        IF GenJournalLine.FINDLAST THEN
            jLineNo := GenJournalLine."Line No." + 10000;

        EXIT(jLineNo);
    end;

    procedure CreateDimension(jTemplate: Code[30]; jBatchName: Code[30]; jLineNo: Integer; dimCode: Code[30]; dimValue: Code[30])
    var
        OldDimSetID: Integer;
        NewDimSetID: Integer;
    begin
        GenJournalLine.RESET;
        GenJournalLine.SETRANGE("Journal Template Name", jTemplate);
        GenJournalLine.SETRANGE("Journal Batch Name", jBatchName);
        GenJournalLine.SETRANGE("Line No.", jLineNo);
        IF GenJournalLine.FINDFIRST THEN BEGIN
            OldDimSetID := GenJournalLine."Dimension Set ID";


            TempDimSetEntry.DELETEALL;
            DimMgt.GetDimensionSet(TempDimSetEntry, OldDimSetID);


            //DIMENSION
            TempDimSetEntry.DELETEALL;

            DimSetEntry.RESET;
            DimSetEntry.SETRANGE("Dimension Set ID", GenJournalLine."Dimension Set ID");
            IF DimSetEntry.FINDSET THEN BEGIN
                REPEAT
                    TempDimSetEntry.RESET;
                    TempDimSetEntry.SETRANGE("Dimension Code", DimSetEntry."Dimension Code");
                    IF TempDimSetEntry.FINDFIRST THEN BEGIN
                        TempDimSetEntry.VALIDATE("Dimension Value Code", DimValue);
                        TempDimSetEntry.MODIFY;
                    END ELSE BEGIN
                        TempDimSetEntry.INIT;
                        TempDimSetEntry.VALIDATE("Dimension Code", DimSetEntry."Dimension Code");
                        TempDimSetEntry.VALIDATE("Dimension Value Code", DimSetEntry."Dimension Value Code");
                        TempDimSetEntry.INSERT;
                    END;
                UNTIL DimSetEntry.NEXT = 0;
            END;

            TempDimSetEntry.INIT;
            TempDimSetEntry.VALIDATE("Dimension Code", DimCode);
            TempDimSetEntry.VALIDATE("Dimension Value Code", DimValue);
            TempDimSetEntry.INSERT;

            TempDimSetEntry.RESET;
            NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry); //get new DimSetID, after existing PO dimensions are modified


            IF OldDimSetID <> NewDimSetID THEN BEGIN
                GenJournalLine."Dimension Set ID" := NewDimSetID; //assign new DimSetID 
                GenJournalLine.MODIFY;
            END;
        END;
    end;
}
