WITH holds_no_copies as (
	SELECT
	o.*
	FROM
	temp_holds_no_copies_pre_output as o
)


SELECT
-- logic for our sort of titles into the departments...
-- TODO: link to documentation section on sorting

-- note: If the condition evaluates to true, the CASE expression returns the result corresponding to the condition 
-- and all other CASE branches do not process at all.
CASE
	-- first, using bib_locations from the holds_no_copies output, make a determination on the agency we sort to ...
	WHEN regexp_split_to_array('1p,1f', ',') && regexp_split_to_array(h.abbv_bib_locations, ',') THEN 'pop'
	WHEN regexp_split_to_array('2e,2g,2r,2s,2n,3a,3h,3l,3r', ',') && regexp_split_to_array(h.abbv_bib_locations, ',') THEN 'irf'
	WHEN regexp_split_to_array('2t,2k', ',') && regexp_split_to_array(h.abbv_bib_locations, ',') THEN 'tee'
	WHEN regexp_split_to_array('1c,1l', ',') && regexp_split_to_array(h.abbv_bib_locations, ',') THEN 'clc'
	WHEN regexp_split_to_array('3c,3g,3e', ',') && regexp_split_to_array(h.abbv_bib_locations, ',') THEN 'gen'
	WHEN regexp_split_to_array('2m', ',') && regexp_split_to_array(h.abbv_bib_locations, ',') THEN 'mag'
	-- second, use the rest of the sort logic to make a determination based on:
	-- mat_type_code, first_item_itype, and call_number

	-- conditions for 'out'
	WHEN (
		( h.mat_type_code = 'l' AND h.first_item_itype = 20 )
		OR ( h.mat_type_code = 'q' AND h.first_item_itype = 93 )
	) THEN 'out'

	-- conditions for 'pop'
	WHEN (
		   ( mat_type_code = 'a' AND h.first_item_itype = 0 AND call_number ~* '^.*fiction.*' )
		OR ( mat_type_code = '5' )
		OR ( mat_type_code = 'i' AND first_item_itype = 70 )
		OR ( mat_type_code = 'g' AND first_item_itype IN (100, 101) )
		OR ( mat_type_code = '7' ) 
		OR ( mat_type_code = 'j' AND first_item_itype = 77 )
		OR ( mat_type_code = 'q' AND first_item_itype = 90 )
		OR ( mat_type_code = 'h' )
		OR ( mat_type_code = 'm' AND call_number !~* '^.*easy.*' )
	) THEN 'pop'

	-- conditions for irf
	WHEN (
		   ( first_item_itype = 0 AND call_number !~* '^.*fiction.*' )
		OR ( mat_type_code = 's' AND first_item_itype = 30 )
		OR ( mat_type_code = 'c' AND first_item_itype = 157 )
		OR ( mat_type_code = 'a' AND first_item_itype = 10 )

	) THEN 'irf'

	-- conditions for tee
	WHEN (
		   ( mat_type_code = 'i' AND first_item_itype = 72 )
		OR ( mat_type_code = 'g' AND first_item_itype IN (100, 101) )
		OR ( mat_type_code = 'l' AND first_item_itype = 24 )
		OR ( mat_type_code = 's' AND first_item_itype = 32 )
		OR ( mat_type_code = 'q' AND first_item_itype = 92 )
	) THEN 'tee'

	-- conditions for clc
	WHEN (
		   ( first_item_itype = 2 )
		OR ( mat_type_code = 'i' AND first_item_itype = 71 )
		OR ( mat_type_code = 'l' AND first_item_itype = 22 )
		OR ( mat_type_code = 's' AND first_item_itype = 31 )
		OR ( mat_type_code = 'j' AND first_item_itype = 78 )
		OR ( mat_type_code = 'c' AND first_item_itype = 159 )
		OR ( mat_type_code = 'q' AND first_item_itype = 91 )
		OR ( mat_type_code = 'm' AND call_number ~* '^.*easy.*' )
	) THEN 'clc'

	-- conditions for gen
	WHEN (
		( mat_type_code ='a' AND first_item_itype = 46 )
	) THEN 'gen'
	
	ELSE 'other'
END as sort_to_sheet,
h.mat_type_code,
h.mat_type,
h.first_item_itype,
h.call_number,
h.isbn,
h.bib_record_num,
h.bib_record_id,
h.publish_year,
h.cataloging_date,
h.best_title,
h.best_title_norm,
h.call_number,
h.volume_statement,
h.oldest_hold_date,
h.newest_hold_date,
h.bib_locations,
h.abbv_bib_locations,
h.count_active_holds,
h.count_active_copies,
h.count_copies_on_order

FROM
holds_no_copies as h

ORDER BY
sort_to_sheet,
count_active_holds DESC
;