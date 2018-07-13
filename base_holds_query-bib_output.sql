-- OUTPUT
-- produce our results for the bib level holds.
-- consider these bibs now off the table for future reports

-- SELECT
-- *
--
-- FROM
-- temp_system_wide_holds_bibs as t
--
-- ORDER BY
-- t.bcode2,
-- t.bib_record_id,
-- t.record_id
-- ;
---


SELECT
bib_num,
pub_year,
cat_date,
media_type,
title,
call_number,
count_active_holds,
count_active_copies,
total_count_copies,
count_copies_on_order,
ratio_holds_to_copies

FROM
temp_system_wide_holds_bibs as t

ORDER BY
bcode2,
bib_record_id
