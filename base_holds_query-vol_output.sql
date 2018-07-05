-- OUTPUT
-- produce our results for the volume level holds
SELECT
*

FROM
temp_system_wide_holds_volumes as t

ORDER BY
t.bib_record_id,
t.record_id;
---
