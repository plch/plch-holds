-- bib-level
SELECT
bt.bib_num AS bib_num,
NULL::varchar as vol,
bt.pub_year AS pub_year,
bt.cat_date AS cat_date,
mb.name AS media_type,
bt.title AS title,
bt.best_title_norm as title_norm,
bt.call_number AS call_number,
bt.count_active_holds AS count_active_holds,
bt.count_active_copies AS count_active_copies,
bt.count_copies_on_order AS count_copies_on_order,
bt.ratio_holds_to_copies AS ratio_holds_to_copies

FROM
temp_system_wide_holds_bibs as bt

JOIN
temp_map_material_type as mb
ON
  mb.code = bt.media_type

UNION

SELECT
tv.bib_num AS bib_num,
tv.vol AS vol,
tv.pub_year AS pub_year,
tv.cat_date AS cat_date,
mv.name AS media_type,
tv.title AS title,
tv.best_title_norm as title_norm,
tv.call_number AS call_number,
tv.count_active_holds AS count_active_holds,
tv.count_active_copies AS count_active_copies,
tv.count_copies_on_order AS count_copies_on_order,
tv.ratio_holds_to_copies AS ratio_holds_to_copies

FROM
temp_system_wide_holds_volumes AS tv

JOIN
temp_map_material_type AS mv
ON
  mv.code = tv.media_type

ORDER BY
media_type,
call_number,
title_norm,
vol
;