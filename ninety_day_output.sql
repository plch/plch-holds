SELECT 
t.bib_number as bib_num,
t.vol as vol,
t.pub_year as pub_year,
t.cat_date as cat_date,
t.media_type as media_type,
t.title as title,
t.call_number as call_number,
t.over_90_not_os as over_90_not_os,
t.over_90_os as over_90_os,
t.count_active_holds as count_active_holds,
t.count_active_copies as count_active_copies,
t.count_copies_on_order as count_copies_on_order

FROM 
temp_90_day_output AS t

ORDER BY
t.bcode2,
t.best_title_norm
;