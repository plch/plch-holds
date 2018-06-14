# PLCH Holds

The holds reports for PLCH consist of three main categories*:

1. **System-wide holds**
1. **Unfilled holds greater than 90 days**
1. **Holds with no active copies**

Holds in all three of these categories are grouped into **titles** that the holds are placed on (bibliographic record), and also share the same characteristics:
  * Title has hold that is Bib-Level or Volume Level
  * Title has hold that is not INN-Reach
  * Title has hold that is not ILL
  * Title has hold that is not Frozen
  * Title has a Cataloging Date

**NOTE**: A title appearing on any one of these lists (meeting criteria defined for that list) will not appear on any other list. The lists are populated with titles in a hierarchical fashion—when they meet all the criteria for the title report in question, they are removed from the larger holds-by-title group defined above.

---

**1. System-wide holds**

A listing of titles that have active copies to active holds ratios that exceed guidelines. This is done for **bib-level** holds and **volume-level** holds separately.

1. Determine the **count of active copies** for the title: To determine if an item is to be considered as an active copy for the title, it must meet these conditions:

   * `item status code` is one of the following:
      * `'-', '!', 'b', 'p', '(', '@', ')', '_', '=', '+'`
      * `'t'`  AND `item_last_update` has age less than 60 days (this identifies in transit items as being an active copy)
   
   * AND `item due date` (if it has one) has age less than 60 days.
   
1. Determine the **count of active holds** for the title. To determine if a hold is an active hold it must meet these conditions:

   * Title has hold that is not Frozen (except for holds placed by patrons with ptype 196)
   * Title has hold with zero delay days OR the hold delay days has passed the report’s date (hold placed date + delay days > today)
   * Title has hold placed by patron with one of the following ptype codes: 
      
      *`( 0, 1, 2, 5, 6, 10, 11, 12, 15, 22, 30, 31, 32, 40, 41, 196 )`
  
1. Determine the count of items ```on order```. To be counted as `on order`, the order record is examined with the following criteria:

   * Order record status code is `'o'` -- this prevents orders that have been canceled from being counted
   * Order is not received
   * Order location code is not 'multi' (the 'multi' location is not a real location, but rather a system-generated location used when there are multiple locations listed among the items on order.)

1. Lastly, determine if the title has active holds that exceed the holds ratio guidelines it must meet these **ratio ```active holds```:```active copies```** (`active copies` are copies considered active plus copies on order) conditions:
   * MatType (bcode2) `'g'` (dvd) has ratio : **greater than 9:1**
   * MatType (bcode2) `'i', 'j', 'q'` (book on cd, music cd, playaway) has ratio : **greater than 6:1**
   * MatType (bcode2) `not any of the above` has ratio : **greater than 3:1**  
