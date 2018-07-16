-- SELECT
-- reckey2id('b3254165')


SELECT
id2reckey(l.bib_record_id) as bib_num,
id2reckey(l.item_record_id) as item_num,
i.is_suppressed,
i.item_status_code,
c.checkout_gmt::date,
c.due_gmt::date,
r.record_last_updated_gmt::date
-- c.*,
-- i.*

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

where
l.bib_record_id = 420910049173

order by
i.is_suppressed DESC,
item_status_code,
c.due_gmt