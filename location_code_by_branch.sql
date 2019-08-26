SELECT
l.code as location_code,
l.branch_code_num,
l.is_public::INTEGER

FROM
sierra_view.location as l

JOIN
sierra_view.branch as br
ON
  br.code_num = l.branch_code_num

ORDER BY
branch_code_num