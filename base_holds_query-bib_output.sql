-- OUTPUT
-- produce our results for the bib level holds.
-- consider these bibs now off the table for future reports

SELECT
*

FROM
temp_system_wide_holds_bibs as t

ORDER BY
t.bcode2,
t.bib_record_id,
t.record_id
;
---
