﻿--
-- These are a series of queries that will create a temporary table of all
-- PLCH holds that meet the shared baseline criteria for holds reports being
-- produced for PLCH staff to examine as possibly problematic
--


-- Grab all of the bib level and volume level holds that exist in the system right now,
-- and link them to a title (bib record):
-- Where holds are not INN-Reach, not ILL and not frozen
DROP TABLE IF EXISTS temp_plch_holds;
CREATE TEMP TABLE temp_plch_holds AS
SELECT
h.*,
p.ptype_code as patron_ptype_code,
p.home_library_code AS patron_home_library_code,
p.expiration_date_gmt AS patron_expiration_date_gmt,
p.block_until_date_gmt AS patron_block_until_date_gmt,
p.owed_amt AS patron_owed_amt,
p.activity_gmt AS patron_activity_gmt,
r.record_type_code,
r.record_num,
CASE
-- 	we are not going to look at item level holds as part of this report, but could be useful later on...
-- 	WHEN r.record_type_code = 'i' THEN (
-- 		SELECT
-- 		l.bib_record_id
--
-- 		FROM
-- 		sierra_view.bib_record_item_record_link as l
--
-- 		WHERE
-- 		l.item_record_id = h.record_id
--
-- 		LIMIT 1
-- 	)

	WHEN r.record_type_code = 'j' THEN (
		SELECT
		l.bib_record_id

		FROM
		sierra_view.bib_record_volume_record_link as l

		WHERE
		l.volume_record_id = h.record_id

		LIMIT 1
	)

	WHEN r.record_type_code = 'b' THEN (
		h.record_id
	)

	ELSE NULL

END AS bib_record_id

FROM
sierra_view.hold as h

LEFT OUTER JOIN
sierra_view.record_metadata as r
ON
  r.id = h.record_id

LEFT OUTER JOIN
sierra_view.patron_record as p
ON
  p.record_id = h.patron_record_id

WHERE
(r.record_type_code = 'b' OR r.record_type_code = 'j')
AND h.is_ir is false -- not INN-Reach
AND h.is_ill is false -- not ILL
AND h.is_frozen is false -- not frozen hold -- considering frozen holds for this
;
---


CREATE INDEX index_record_type_code ON temp_plch_holds (record_type_code);
CREATE INDEX index_bib_record_id ON temp_plch_holds (bib_record_id);
CREATE INDEX index_record_id ON temp_plch_holds (record_id);
---


ANALYZE temp_plch_holds;
---


-- remove all the rows where holds don't have a bib record with a cataloging date.
-- there may be a better way to do this, but I'm leaving it like it is for now
DELETE FROM
temp_plch_holds AS h

WHERE h.id IN (
	SELECT
	hs.id

	FROM
	temp_plch_holds as hs

	JOIN
	sierra_view.bib_record as b
	ON
	  b.record_id = hs.bib_record_id

	WHERE
	b.cataloging_date_gmt IS NULL
);
---


-- count active holds and active copies for volume record holds
DROP TABLE IF EXISTS temp_volume_level_holds_counts;
CREATE TEMP TABLE temp_volume_level_holds_counts AS
SELECT
-- r.record_type_code || r.record_num || 'a' as bib_record_num,
-- v.field_content as volume_number,
t.bib_record_id,
t.record_id,
t.record_type_code,
br.bcode2,
-- count the active holds
(
	SELECT
	COUNT(*)

	FROM
	temp_plch_holds as t1

	WHERE
	t1.record_id = t.record_id
	AND t1.patron_ptype_code IN (0, 1, 2, 3, 5, 6, 10, 11, 12, 15, 22, 30, 31, 32, 40, 41, 196)

) as count_active_holds,
-- count the items attached to the volume record
-- note: this result can be null, so return 0 if that's the case
COALESCE (
(
	SELECT
	COUNT(i.record_id)

	FROM
	sierra_view.volume_record_item_record_link as l

	JOIN
	sierra_view.item_record as i
	ON
	  i.record_id = l.item_record_id

	JOIN
	sierra_view.record_metadata as r
	ON
	  r.id = l.item_record_id

	LEFT OUTER JOIN
	sierra_view.checkout as c
	ON
	  c.item_record_id = l.item_record_id

	WHERE
	l.volume_record_id = t.record_id
	-- removed check for item record suppression for now
	-- AND i.is_suppressed IS false
	AND (
		(
			i.item_status_code IN ('-', '!', 'b', 'p', '(', '@', ')', '_', '=', '+')
			AND COALESCE ( age(c.due_gmt) < INTERVAL '60 days', true ) -- item due date < 60 days old
		)
		OR (
			i.item_status_code = 't'
			AND COALESCE ( age(r.record_last_updated_gmt) < INTERVAL '60 days', true ) -- item in transit < 60 days old
		)
	)
	-- item is in transit, but not long in transit
	-- OR (
	-- i.item_status_code IN ('t')
	-- AND COALESCE ( age(r.record_last_updated_gmt) < INTERVAL '60 days', true ) -- item in transit < 60 days old
	-- )
), 0) as count_active_copies,

-- count the number of copies on order ...
-- note: this result can be null, so return 0 if that's the case
COALESCE (
	(
	SELECT
	SUM(c.copies)

	FROM
	sierra_view.bib_record_order_record_link as l

	LEFT OUTER JOIN
	sierra_view.order_record as o
	ON
	  o.record_id = l.order_record_id

	JOIN
	sierra_view.order_record_cmf as c
	ON
	  c.order_record_id = l.order_record_id

	LEFT OUTER JOIN
	sierra_view.order_record_received as r
	ON
	  r.order_record_id = l.order_record_id

	WHERE
	l.bib_record_id =  t.bib_record_id
	AND o.order_status_code = 'o' -- this prevents orders that have been canceled from showing up and being counted
	AND r.id IS NULL -- order is not received
	AND c.location_code != 'multi'

	GROUP BY
	l.bib_record_id

), 0) as count_copies_on_order

FROM
temp_plch_holds as t

JOIN
sierra_view.bib_record as br
ON
  br.record_id = t.bib_record_id

WHERE
t.record_type_code = 'j'
AND br.bcode2 NOT IN ('s','n') -- bcode2 don't include magazines (s) or newspapers ('n')

GROUP BY
t.bib_record_id,
t.record_id,
t.record_type_code,
br.bcode2
;
---


-- produce table for bib level holds
-- count active holds and active copies for volume record holds
DROP TABLE IF EXISTS temp_bib_level_holds_counts;
CREATE TEMP TABLE temp_bib_level_holds_counts AS
SELECT
-- r.record_type_code || r.record_num || 'a' as bib_record_num,
-- v.field_content as volume_number,
t.bib_record_id,
t.record_id,
t.record_type_code,
br.bcode2,
-- count the active holds
(
	SELECT
	COUNT(*)

	FROM
	temp_plch_holds as t1

	WHERE
	t1.record_id = t.record_id
	AND t1.patron_ptype_code IN (0, 1, 2, 3, 5, 6, 10, 11, 12, 15, 22, 30, 31, 32, 40, 41, 196)

) as count_active_holds,
-- count the items attached to the bib record
-- note: this result can be null, so return 0 if that's the case
COALESCE((
	SELECT
	COUNT(*)

	FROM
	sierra_view.bib_record_item_record_link as l

	JOIN
	sierra_view.item_record as i
	ON
	  i.record_id = l.item_record_id

	JOIN
	sierra_view.record_metadata as r
	ON
	  r.id = l.item_record_id

	LEFT OUTER JOIN
	sierra_view.checkout as c
	ON
	  c.item_record_id = l.item_record_id

	WHERE
	l.bib_record_id = t.record_id
	-- removed check for item record suppression for now
	-- AND i.is_suppressed IS false
	AND (
		(
			i.item_status_code IN ('-', '!', 'b', 'p', '(', '@', ')', '_', '=', '+')
			AND COALESCE ( age(c.due_gmt) < INTERVAL '60 days', true ) -- item due date < 60 days old
		)
		OR (
			i.item_status_code = 't'
			AND COALESCE ( age(r.record_last_updated_gmt) < INTERVAL '60 days', true ) -- item in transit < 60 days old
		)
	)
), 0) as count_active_copies,

-- count the number of copies on order ...
-- note: this result can be null, so return 0 if that's the case
COALESCE((
	SELECT
	SUM(c.copies)

	FROM
	sierra_view.bib_record_order_record_link as l

	LEFT OUTER JOIN
	sierra_view.order_record as o
	ON
	  o.record_id = l.order_record_id

	JOIN
	sierra_view.order_record_cmf as c
	ON
	  c.order_record_id = l.order_record_id

	LEFT OUTER JOIN
	sierra_view.order_record_received as r
	ON
	  r.order_record_id = l.order_record_id

	WHERE
	l.bib_record_id =  t.bib_record_id
	AND o.order_status_code = 'o' -- this prevents orders that have been canceled from showing up and being counted
	AND r.id IS NULL -- order is not received
	AND c.location_code != 'multi'

	GROUP BY
	l.bib_record_id

), 0) as count_copies_on_order

FROM
temp_plch_holds as t

JOIN
sierra_view.bib_record as br
ON
  br.record_id = t.bib_record_id

WHERE
-- records are of type bib
t.record_type_code = 'b'
AND br.bcode2 NOT IN ('s','n') -- bcode2 don't include magazines (s) or newspapers ('n')

GROUP BY
t.bib_record_id,
t.record_id,
t.record_type_code,
br.bcode2
;
---


---
-- Produce the temporary table that will be used to output System-Wide Holds bib
DROP TABLE IF EXISTS temp_system_wide_holds_bibs;

CREATE TEMP TABLE temp_system_wide_holds_bibs AS
SELECT
r.record_type_code || r.record_num || 'a' as bib_num,
p.publish_year as pub_year,
b.cataloging_date_gmt::date as cat_date,
t.bcode2 as media_type,
-- (
-- 	SELECT
-- 	bn.name::text
--
-- 	FROM
-- 	sierra_view.user_defined_bcode2_myuser as bn
--
-- 	WHERE
-- 	bn.code = t.bcode2
--
-- 	LIMIT 1
-- ) as media_type,

-- n.name as media_type, -- i don't know why this isn't working
p.best_title as title,
p.best_title_norm,
p.best_author as author,
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
t.count_active_holds,
t.count_active_copies,
COALESCE(t.count_copies_on_order, 0) as count_copies_on_order,
t.count_active_copies + COALESCE(t.count_copies_on_order, 0) as total_count_copies,
t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float AS ratio_holds_to_copies,
t.bcode2,
t.bib_record_id,
t.record_id

FROM
temp_bib_level_holds_counts as t

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
sierra_view.user_defined_bcode2_myuser as n
ON
  n.code = t.bcode2

WHERE
t.count_active_copies > 0
AND t.count_active_holds > 0
AND (
	(
		-- dvd (g) and bluray (r)
		t.bcode2 IN ('g', 'r')  
		AND ( t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float
		) > 9.0::float
	)
	OR (
		t.bcode2 IN ('i', 'j', 'q', '8')
		AND (
			t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float
		) > 6.0::float
	)
	-- if bcode2 is none of the above, and it has a ratio above 3:1 show it.
	OR (
		t.bcode2 NOT IN ('g', 'i', 'j', 'q', '8')
		AND (
			t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float
		) > 3.0::float
	)
)

-- ORDER BY
-- t.bcode2,
-- t.bib_record_id,
-- t.record_id;
;
---


---
-- Remove from the temp_plch_holds table the bib records that we produced for our previous output
DELETE FROM
temp_plch_holds as t

WHERE t.record_id IN (
	SELECT
	record_id

	FROM
	temp_system_wide_holds_bibs
)
;
---


-- Produce the temporary table that will be used to output System-Wide Holds volume
---
DROP TABLE IF EXISTS temp_system_wide_holds_volumes;

CREATE TEMP TABLE temp_system_wide_holds_volumes AS
SELECT
-- id2reckey(t.bib_record_id) || 'a' as bib_num,
-- id2reckey(t.record_id) || 'a' as vol_num,
br.record_type_code || br.record_num || 'a' as bib_num,
-- vr.record_type_code || vr.record_num || 'a' as vol_num,
v.field_content as vol,

p.publish_year as pub_year,
b.cataloging_date_gmt::date as cat_date,
t.bcode2 as media_type,
p.best_title as title,
p.best_title_norm,
p.best_author as author,
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


t.count_active_holds,
t.count_active_copies,
COALESCE(t.count_copies_on_order, 0) as count_copies_on_order,
t.count_active_copies + COALESCE(t.count_copies_on_order, 0) as total_count_copies,
t.count_active_holds::float / ( t.count_active_copies + COALESCE(t.count_copies_on_order, 0) )::float AS ratio_holds_to_copies,
t.bcode2,
t.bib_record_id,
t.record_id

FROM
temp_volume_level_holds_counts as t

JOIN
sierra_view.record_metadata as br
ON
  br.id = t.bib_record_id

JOIN
sierra_view.record_metadata as vr
ON
  vr.id = t.record_id

LEFT OUTER JOIN
sierra_view.varfield as v
ON
  v.record_id = t.record_id -- t.record_id should be the volume record id
  AND v.varfield_type_code = 'v'

JOIN
sierra_view.bib_record_property as p
ON
  p.bib_record_id = t.bib_record_id

JOIN
sierra_view.bib_record as b
ON
  b.record_id = t.bib_record_id

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

-- ORDER BY
-- t.bib_record_id,
-- t.record_id;

;
---


---
-- Remove from the temp_plch_holds table the records that we produced for our previous output
DELETE FROM
temp_plch_holds as t

WHERE t.record_id IN (
	SELECT
	record_id

	FROM
	temp_system_wide_holds_volumes
)
;
---


--- --- 
--- ---
--- 90 Days Holds related queries
--- ---
--- ---

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
---


-- create output for the 90-day unfilled holds report
DROP TABLE IF EXISTS temp_90_day_output;
CREATE TEMP TABLE temp_90_day_output AS
SELECT
r.record_type_code || r.record_num || 'a' as bib_number,
v.field_content as vol,
-- id2reckey(t.bib_record_id),
p.publish_year as pub_year,
b.cataloging_date_gmt::date as cat_date,
t.bcode2 as media_type,
-- (
-- 	SELECT
-- 	bc.name
--
-- 	FROM
-- 	sierra_view.user_defined_bcode2_myuser as bc
--
-- 	WHERE
-- 	bc.code = t.bcode2
-- ) as media_type,
p.best_title as title,
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
t.count_copies_on_order,
t.bcode2,
t.bib_record_id,
t.record_id,
p.best_title_norm,
p.best_author,
p.best_author_norm

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

-- ORDER BY
-- t.bcode2,
-- t.bib_record_id,
-- t.record_id,
-- p.best_title_norm
;
---


-- remove the 90 day holds from the main table 
DELETE FROM
temp_plch_holds AS h

WHERE h.record_id IN (

	SELECT
	record_id
	FROM
	temp_90_day_pre_output
);



--- ---
--- ---
--- Holds no active copies:
--- ---
--- ---

-- we've been whittling down our temp_plch_holds by removing the holds as we fill our reports ...
-- start there:
-- SELECT * FROM temp_plch_holds limit 100

-- bib level holds meeting our criteria:
DROP TABLE IF EXISTS temp_bib_level_holds_no_copies;
CREATE TEMP TABLE temp_bib_level_holds_no_copies AS
WITH temp_plch_holds_cte AS (
	SELECT DISTINCT
	t.record_id
	FROM
	temp_plch_holds as t
	WHERE
	t.record_type_code = 'b'
)

SELECT
c.*

FROM
temp_plch_holds_cte as t

JOIN
temp_bib_level_holds_counts as c
ON
  c.record_id = t.record_id

WHERE
c.count_active_copies = 0
AND c.count_copies_on_order = 0
;


-- vol level holds meeting our criteria:
DROP TABLE IF EXISTS temp_volume_level_holds_no_copies;
CREATE TEMP TABLE temp_volume_level_holds_no_copies AS
WITH temp_plch_holds_cte AS (
	SELECT DISTINCT
	t.record_id
	FROM
	temp_plch_holds as t
	WHERE
	t.record_type_code = 'j'
)

SELECT
c.*

FROM
temp_plch_holds_cte as t

JOIN
temp_volume_level_holds_counts as c
ON
  c.record_id = t.record_id

WHERE
c.count_active_copies = 0
AND c.count_copies_on_order = 0
;

-- SELECT * FROM temp_bib_level_holds_no_copies;


-- look at what's going on with the count_copies_on_order ...it might be wrong?
-- bib_record_id;record_id
-- 420910240967;455268032430;j;g;10;0;0

---
-- CREATING TEMP TABLE FOR THE MATERIAL TYPE CODES IN OUTPUT
DROP TABLE IF EXISTS temp_map_material_type
;

CREATE TEMP TABLE temp_map_material_type AS
SELECT
p.code as code,
n.name as name

FROM
sierra_view.material_property as p

JOIN
sierra_view.material_property_name as n
ON
  n.material_property_id = p.id
;
---


--- 
---
--- holds no active copies - pre output
---
---

DROP TABLE IF EXISTS temp_holds_no_copies_pre_output;
CREATE TEMP TABLE temp_holds_no_copies_pre_output AS
WITH temp_holds_no_copies AS (
	SELECT
	*
	FROM
	temp_bib_level_holds_no_copies

	UNION

	SELECT
	*
	FROM
	temp_volume_level_holds_no_copies
)

SELECT
r.record_type_code || r.record_num || 'a' as bib_record_num,
-- r.id,
h.bib_record_id,
p.publish_year,
b.cataloging_date_gmt::date as cataloging_date,

(
	SELECT
	m.name
	FROM
	temp_map_material_type as m
	WHERE
	m.code = h.bcode2
) as mat_type,

h.bcode2 as mat_type_code,


-- r.creation_date_gmt::date as creation_date,
p.best_title,
p.best_title_norm,

-- if no item call numbers, get it from the bib
COALESCE(
	-- call number from item...
	(
		SELECT
		-- string_agg(DISTINCT i.call_number_norm, ',')
		
		i.call_number_norm
		FROM
		sierra_view.bib_record_item_record_link as l
		JOIN
		sierra_view.item_record_property as i
		ON
		  i.item_record_id = l.item_record_id
		WHERE
		l.bib_record_id = h.bib_record_id
		ORDER BY
		l.items_display_order ASC
		LIMIT 1
	),
	-- call number from bib
	(
		SELECT
		-- get the call number strip the subfield indicators
		lower(
			regexp_replace( 
				trim(
					v.field_content
				),
				'(\|[a-z]{1})', '', 'ig'
			)
		)
		FROM
		sierra_view.varfield as v

		WHERE
		v.record_id = h.bib_record_id
		AND v.varfield_type_code = 'c'

		ORDER BY
		v.occ_num

		LIMIT 1
	)
) as call_number,

(
	SELECT
	v.field_content
	FROM
	sierra_view.varfield as v
	WHERE
	h.record_type_code = 'j'
	AND v.record_id = h.record_id
	AND v.varfield_type_code = 'v'
	ORDER BY
	v.occ_num
	LIMIT 1
) as volume_statement,

(
	SELECT
	MIN(t.placed_gmt)::date
	FROM
	temp_plch_holds as t
	WHERE
	t.record_id = h.record_id
) as oldest_hold_date,
(
	SELECT
	MAX(t.placed_gmt)::date
	FROM
	temp_plch_holds as t
	WHERE
	t.record_id = h.record_id
) as newest_hold_date,

(
	SELECT
	string_agg(bl.location_code, ',' order by bl.display_order)
	FROM
	sierra_view.bib_record_location as bl
	WHERE
	bl.bib_record_id = h.bib_record_id
	AND bl.location_code != 'multi'
) as bib_locations,
(
	SELECT
	string_agg( substring(bl.location_code from 1 for 2), ',' order by bl.display_order)
	FROM
	sierra_view.bib_record_location as bl
	WHERE
	bl.bib_record_id = h.bib_record_id
	AND bl.location_code != 'multi'
) as abbv_bib_locations,
(
	SELECT
-- 	string_agg(DISTINCT i.call_number_norm, ',')
	i.itype_code_num
	FROM
	sierra_view.bib_record_item_record_link as l
	JOIN
	sierra_view.item_record as i
	ON
	  i.record_id = l.item_record_id
	WHERE
	l.bib_record_id = h.bib_record_id
	ORDER BY
	l.items_display_order ASC
	LIMIT 1
	
) as first_item_itype,
(
	-- get the longest isbn from the record
	SELECT
	substring(p.index_entry FROM '[0-9]+')
	FROM
	sierra_view.phrase_entry as p
	WHERE
	p.record_id = h.bib_record_id
	AND p.index_tag = 'i'

	ORDER BY
	p.occurrence,
	-- LENGTH(substring(p.index_entry FROM '[0-9]+')) DESC,
	substring(p.index_entry FROM '[0-9]+') DESC
	LIMIT 1
) as isbn,
h.count_active_holds,
h.count_active_copies,
h.count_copies_on_order

FROM
temp_holds_no_copies as h

JOIN
sierra_view.record_metadata as r
ON
  r.id = h.bib_record_id

JOIN
sierra_view.bib_record as b
ON
  b.record_id = h.bib_record_id

JOIN
sierra_view.bib_record_property as p
ON
  p.bib_record_id = h.bib_record_id
;

---
-- Additional useful queries for troubleshooting / further development
---

-- test a bib record number to see why it maybe didn't appear on the report
-- SELECT
-- *
-- FROM
-- temp_bib_level_holds_counts as t
--
-- WHERE
-- t.bib_record_id = reckey2id('b2812314a')
--
-- LIMIT 100

----------

---
-- JOIN
-- sierra_view.record_metadata as r
-- ON
--   r.id = t.bib_record_id
--
-- -- get the volume number
-- LEFT OUTER JOIN
-- sierra_view.varfield as v
-- ON
--   v.record_id = t.record_id -- t.record_id should be the volume record id
--   AND v.varfield_type_code = 'v'
--
-- WHERE
-- t.record_type_code = 'j'

-- limit 100

----------

-- SELECT
--
-- t.id,
-- t.is_frozen,
-- t.placed_gmt,
-- t.delay_days,
-- ( INTERVAL '1 day' * t.delay_days ) as interval_delay,
-- t.placed_gmt::timestamp + ( INTERVAL '1 day' * t.delay_days ) as not_wanted_before,
--
-- -- make a determination if we want to count the hold
-- CASE
-- 	WHEN delay_days = 0 THEN false
-- 	WHEN NOW()::timestamp >= t.placed_gmt::timestamp + ( INTERVAL '1 day' * t.delay_days ) THEN true
-- 	ELSE false
-- END as past_not_wanted_before,
-- t.patron_record_id
--
-- FROM
-- temp_plch_holds as t
--
-- WHERE
-- t.patron_record_id = 481038535591
--
-- limit 100

----------

-- sum up the results ...
-- SELECT
-- t.record_type_code,
-- count(t.record_type_code)
--
-- FROM
-- temp_plch_holds as t
--
-- GROUP BY
-- t.record_type_code;
---

----------

-- do some counting ...
-- SELECT
-- h.bib_record_id,
-- id2reckey(h.bib_record_id) as bib_record_num,
-- h.record_type_code,
-- (
-- 	SELECT
-- 	count(l.item_record_id)
--
-- 	FROM
-- 	sierra_view.bib_record_item_record_link as l
--
-- 	WHERE
-- 	l.bib_record_id = h.bib_record_id
-- ) as count_items_linked,
-- (
-- 	SELECT
-- 	count(l.volume_record_id)
--
-- 	FROM
-- 	sierra_view.bib_record_volume_record_link as l
--
-- 	WHERE
-- 	l.bib_record_id = h.bib_record_id
-- ) as count_volumes_linked
--
-- FROM
-- temp_plch_holds as h
--
-- WHERE
-- h.record_type_code = 'b'
-- OR h.record_type_code = 'j'
--
-- GROUP BY
-- h.bib_record_id,
-- h.record_type_code
--
-- ORDER BY
-- h.bib_record_id;