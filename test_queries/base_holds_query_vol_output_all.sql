-- -- OUTPUT
-- -- produce our results for the volume level holds
SELECT
bib_num,
vol,
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
temp_system_wide_holds_volumes as t

ORDER BY
bcode2,
bib_record_id









-- OLD
-- SELECT
-- id2reckey(t.bib_record_id) || 'a' as bib_num,
-- id2reckey(t.record_id) || 'a' as vol_num,
-- v.field_content as vol,
-- t.count_active_holds,
-- t.count_active_copies,
-- COALESCE(t.count_copies_on_order, 0) as count_copies_on_order,
-- t.count_active_copies + COALESCE(t.count_copies_on_order, 0) as total_count_copies,
-- t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float AS ratio_holds_to_copies,
-- t.bcode2
--
-- FROM
-- temp_volume_level_holds_counts as t
--
-- LEFT OUTER JOIN
-- sierra_view.varfield as v
-- ON
--   v.record_id = t.record_id -- t.record_id should be the volume record id
--   AND v.varfield_type_code = 'v'
--
-- WHERE
-- t.count_active_copies > 0
-- AND t.count_active_holds > 0
--
--
-- ORDER BY
-- t.bcode2,
-- ratio_holds_to_copies DESC,
-- t.bib_record_id,
-- vol,
-- t.record_id
-- ;
