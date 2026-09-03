select "MARKETSEGMENT",
    "COUNTRY",
    "BRAND",
    "C1",
    "C2"
from 
(
    select "MARKETSEGMENT",
        "COUNTRY",
        "BRAND",
        SUM("DISCOUNTAMOUNT") as "C1",
        SUM("SALESAMOUNT") as "C2"
    from 
    (
        select "OTBL"."SALESAMOUNT",
            "OTBL"."DISCOUNTAMOUNT",
            "OTBL"."MARKETSEGMENT",
            "OTBL"."COUNTRY",
            "ITBL"."BRAND"
        from 
        (
            select "OTBL"."ORDERKEY",
                "OTBL"."PRODUCTKEY",
                "OTBL"."CUSTOMERKEY",
                "OTBL"."DATEKEY",
                "OTBL"."QUANTITY",
                "OTBL"."SALESAMOUNT",
                "OTBL"."DISCOUNTAMOUNT",
                "ITBL"."CUSTOMERKEY" as "C1",
                "ITBL"."CUSTOMERNAME",
                "ITBL"."MARKETSEGMENT",
                "ITBL"."COUNTRY"
            from "CPG_ANALYTICS"."SALES_MODEL"."FACT_SALES" as "OTBL"
            left outer join "CPG_ANALYTICS"."SALES_MODEL"."DIM_CUSTOMER" as "ITBL" on ("OTBL"."CUSTOMERKEY" = "ITBL"."CUSTOMERKEY")
        ) as "OTBL"
        left outer join "CPG_ANALYTICS"."SALES_MODEL"."DIM_PRODUCT" as "ITBL" on ("OTBL"."PRODUCTKEY" = "ITBL"."PRODUCTKEY")
    ) as "ITBL"
    group by "MARKETSEGMENT",
        "COUNTRY",
        "BRAND"
) as "ITBL"
where not "C1" is null or not "C2" is null
limit 1000001