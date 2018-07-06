
-- to get the _real_ date of the hold (with delay days) do something like this ...
-- EXAMPLE : 
-- SELECT
-- t.placed_gmt,
-- t.delay_days,
-- (t.placed_gmt + concat(t.delay_days, ' days')::INTERVAL) as date_until_wanted
-- 
-- FROM
-- temp_plch_holds as t
-- 
-- WHERE
-- t.delay_days > 0


-- find titles with at least one hold that has an age of hold >= 90
DROP TABLE IF EXISTS temp_titles_holds_greater_90_days;
CREATE TEMP TABLE temp_titles_holds_greater_90_days AS
SELECT
t.bib_record_id,
t.record_type_code,
t.record_id
-- ( ( extract(epoch FROM age(t.placed_gmt)) / 3600 ) / 24 )::int as age_days_placed

FROM
temp_plch_holds as t

WHERE
-- age of hold is >= 90 days
( ( extract(epoch FROM age( 
	(t.placed_gmt + concat(t.delay_days, ' days')::INTERVAL)
)) / 3600 ) / 24 )::int >= 90

GROUP BY
t.bib_record_id,
t.record_type_code,
t.record_id
;

CREATE INDEX record_type_code_temp_titles_holds_greater_90_days ON temp_titles_holds_greater_90_days (record_type_code);
CREATE INDEX bib_record_id_temp_titles_holds_greater_90_days ON temp_titles_holds_greater_90_days (bib_record_id);
CREATE INDEX record_id_temp_titles_holds_greater_90_days ON temp_titles_holds_greater_90_days (record_id);
---


---
-- grab all the bibs and volumes for 90 day holds
DROP TABLE IF EXISTS temp_90_day_pre_output;
CREATE TEMP TABLE temp_90_day_pre_output AS
SELECT
c.*

FROM
temp_titles_holds_greater_90_days as t

JOIN
temp_volume_level_holds_counts as c
ON
  c.record_id = t.record_id

WHERE
t.record_type_code = 'j'
AND c.count_active_copies > 0
AND c.count_active_holds > 0


UNION


SELECT
c.*

FROM
temp_titles_holds_greater_90_days as t

JOIN
temp_bib_level_holds_counts as c
ON
  c.record_id = t.record_id

WHERE
t.record_type_code = 'b'
AND c.count_active_copies > 0
AND c.count_active_holds > 0
;



-- create output for the 90-day unfilled holds report
-- DROP TABLE IF EXISTS temp_90_day_output;
-- CREATE TEMP TABLE temp_90_day_pre_output AS
SELECT
t.bib_record_id,
r.record_type_code || r.record_num || 'a' as bib_number,
-- id2reckey(t.bib_record_id),

p.publish_year as pub_year,
b.cataloging_date_gmt::date as cat_date,
(
	SELECT
	bc.name

	FROM
	sierra_view.user_defined_bcode2_myuser as bc

	WHERE
	bc.code = t.bcode2
) as media_type,

p.best_title,

(
	SELECT
	regexp_replace(trim(v.field_content), '(\|[a-z]{1})', '', 'ig') as call_number -- get the call number strip the subfield indicators

	FROM
	sierra_view.varfield as v

	WHERE
	v.record_id = t.bib_record_id
	AND v.varfield_type_code = 'c'

	ORDER BY
	v.occ_num

	LIMIT 1
) as call_number,


v.field_content as vol,
(
	SELECT
	count(th.id)

	FROM
	temp_plch_holds as th

	WHERE
	th.record_id = t.record_id
	AND th.pickup_location_code <> 'os'
	AND ( ( extract(epoch FROM age( 
		(th.placed_gmt + concat(th.delay_days, ' days')::INTERVAL)
	)) / 3600 ) / 24 )::int >= 90
) AS over_90_not_os,
(
	SELECT
	count(th.id)

	FROM
	temp_plch_holds as th

	WHERE
	th.record_id = t.record_id
	AND th.pickup_location_code = 'os'
	AND ( ( extract(epoch FROM age( 
		(th.placed_gmt + concat(th.delay_days, ' days')::INTERVAL)
	)) / 3600 ) / 24 )::int >= 90
) AS over_90_os,

t.count_active_holds,
t.count_active_copies,
t.count_copies_on_order

FROM 
temp_90_day_pre_output as t

JOIN
sierra_view.record_metadata as r
ON
  r.id = t.bib_record_id

JOIN
sierra_view.bib_record_property as p
ON
  p.bib_record_id = t.bib_record_id

JOIN
sierra_view.bib_record as b
ON
  b.record_id = t.bib_record_id

LEFT OUTER JOIN
sierra_view.varfield as v
ON
  v.record_id = t.record_id -- t.record_id should be the volume record id
  AND v.varfield_type_code = 'v'
  AND t.record_type_code = 'j' -- only grab volume statement from records that have them ('j')

ORDER BY
t.bcode2,
t.bib_record_id,
t.record_id,
p.best_title_norm