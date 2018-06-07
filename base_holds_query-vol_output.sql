-- OUTPUT
-- produce our results for the volume level holds
SELECT
id2reckey(t.bib_record_id) || 'a' as bib_num,
id2reckey(t.record_id) || 'a' as vol_num,
v.field_content as vol,
t.count_active_holds,
t.count_active_copies,
COALESCE(t.count_copies_on_order, 0) as count_copies_on_order,
t.count_active_copies + COALESCE(t.count_copies_on_order, 0) as total_count_copies,
t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float AS ratio_holds_to_copies,
t.bcode2

FROM
temp_volume_level_holds_counts as t

LEFT OUTER JOIN
sierra_view.varfield as v
ON
  v.record_id = t.record_id -- t.record_id should be the volume record id
  AND v.varfield_type_code = 'v'

WHERE
t.count_active_copies > 0
AND t.count_active_holds > 0
AND (
	(
		t.bcode2 IN ('g')
		AND ( t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float
		) > 9.0::float
	)
	OR (
		t.bcode2 IN ('i', 'j', 'q')
		AND ( 
			t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float 
		) > 6.0::float
	)
	-- if bcode2 is none of the above, and it has a ratio above 3:1 show it.
	OR (
		t.bcode2 NOT IN ('g', 'i', 'j', 'q')
		AND ( 
			t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float 
		) > 3.0::float
	)
)

ORDER BY
t.bib_record_id,
t.record_id;
---
