-- OUTPUT
-- produce our results for the volume level holds
SELECT
t.bib_num,
t.vol,
t.pub_year,
t.cat_date,
m.name AS media_type,
t.title,
t.best_title_norm,
t.author,
t.call_number,
t.count_active_holds,
t.count_active_copies,
t.count_copies_on_order,
t.total_count_copies,
t.ratio_holds_to_copies,
t.bcode2,
t.bib_record_id,
t.record_id
-- *

FROM
temp_system_wide_holds_volumes as t

JOIN
temp_map_material_type as m
ON
  m.code = t.media_type

ORDER BY
t.bib_record_id,
t.record_id
;
---
