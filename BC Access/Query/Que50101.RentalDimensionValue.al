query 50101 "Rental Dimension Value"
{
    APIGroup = 'SMPC';
    APIPublisher = 'SMPC';
    APIVersion = 'v2.0';
    EntityName = 'SMPCEntity';
    EntitySetName = 'SMPCEntitySet';
    QueryType = API;

    elements
    {
        dataitem(dimensionValue; "Dimension Value")
        {
            column(dimensionCode; "Dimension Code")
            {
            }
            column("code"; "Code")
            {
            }
            column(name; Name)
            {
            }
            column(blocked; Blocked)
            {

            }
        }
    }

    trigger OnBeforeOpen()
    begin
        CurrQuery.SetRange(blocked, false);
    end;
}
