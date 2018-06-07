#PLCH Holds

The holds reports for PLCH consist of three main categories*:
1. System-wide holds
1. Unfilled holds greater than 90 days
1. Holds with no active copies

Holds in all three of these categories are grouped into the titles (bibliographic record) the holds are placed on, and also share the same characteristics:
Title has hold that is Bib-Level or Volume Level
Title has hold that is not INN-Reach
Title has hold that is not ILL
Title has hold that is not Frozen
Title has a Cataloging Date

* NOTE: A title appearing on any one of these lists (meeting criteria defined for that list) will not appear on any other list. The lists are populated with titles in a hierarchical fashion—when they meet all the criteria for the title report in question, they are removed from the larger holds-by-title group defined above.

##System-wide holds

A listing of titles that have active copies to active holds ratios that exceed guidelines.

First, determine the count of active copies for the title. To determine if an item is to be considered as an active copy for the title, it must meet these conditions:
Item status code is one of the following: ‘-’, ,’t’, ‘!’, ‘b’, ‘p’, ‘(’, ‘@’, ‘)’, ‘_’, ‘=’, ‘+’ 
OR item status code ‘t’ and item last update date older than 60 days.
Item has a due date 
OR due date not older than 60 days

Second, determine the count of active holds for the title. To determine if a hold is an active hold it must meet these conditions:
Title has hold that is not Frozen (except for holds placed by patrons with ptype 196)
Title has hold with zero delay days
OR the hold delay days has passed the report’s date (hold placed date + delay days > today)
Title has hold placed by patron with one of the following ptype codes: 
( 0, 1, 2, 5, 6, 10, 11, 12, 15, 22, 30, 31, 32, 40, 41, 196 )


Lastly, determine if the title has active holds that exceed the holds ratio guidelines it must meet these conditions:
MatType (bcode2) ‘g’ (dvd) has ratio active holds:active copies greater than 9:1
MatType (bcode2) ‘i’, ‘j’, ‘q’ (book on cd, music cd, playaway) has ratio active holds:active copies greater than 6:1
MatType (bcode2) not any of the above has ratio active holds:active copies greater than 3:1
