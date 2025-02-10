# Inventory Check
Inventory Check utilizes the "order tracking policy" :: 'Tracking Only'
This means that every item transactions are logged into the "Reservation Entry" table, with the status either <Tracked> or <Surplus>

## Logic for Inventory Check
The Inventory Check logic will first insert a dummy sales order for a given quantity and shipment day. 
Then it will first check if the record got tracked (matched). If so the logic will return a thumbs up.
If the entered sales line has been given the status::'Surplus', then the engine will see if there are some quantities to "steal". If so the logic will return a thumbs up.
If not able to match or steal, then the logic tries to find the first income, and suggests a new shipment date.

## Subscription
OnCheckIsWebshopOrder must be called and set "IsWebshopOrder" variable to true, if you do not want the Inventory to Check if the Order is placed by Web Order Integration

### Steal Logic
The "Steal" engine is located in its own code unit, and tries to reorganize the "Reservation Entries".
First, it will check if an order with a shipment date after CTP (Capable To Promise) has been matched to stock. If so, the system loses up the stock-match and returns OK.
CTP is the timeline, they can set a new purchase order and then support the sales order in the future.
Second, check is to see if any order has been matching to stock, that can be matched up with an income (surplus). If so, the system moves the track, free up stock-match and returns OK.
Third, there is no stock-match to free. Then see if there are any inbound-match to postpone for order with shipment date further down the road and projected income can provide to such a date.
If so, the system moves the track, free up inbound-match and returns OK.
if neither above, then return false, and the salesperson gets a warning with a suggested new shipment date.

### Auto Match Salesline
An event will override the default process and search for the latest income that the sales line can match against. 
This approach will keep high-value entries, such as inventory, open longer for short-term delivery.
The approch will only affect salesline, as demand.
Available from v1.0.9.0

## Recreate Logic
Microsoft has some flaw in the "Dynamic Tracking" processes when it comes to Transfer order. If the transfer order is shipped, and thereafter modifies the receipt date; the reserevation entries may be deleted.
See reported issue: https://experience.dynamics.com/ideas/idea/?ideaid=fada2d64-0c27-ef11-8ee7-6045bdb88c35

Recreate process will search for those situations, and recreate the reservation entries or modify "surplus" quantity to same as value as the transfer order.

v1.0.7.3 Added HandlingMissingTransfQty - This procedure will detect if the reservation entry does not hold the entire quantity specified in the transfer order.

## Trim Logic
By default, the first order will be matched to best (secured) inbound, like stock or first income. Even the order is planned to be shipped in far future. 
The trim process, removes all demands (each item) from the reservation entries, and the recreates them after shipment date.

### Deframentation (defrag) of Surplus
When demand is changed or deleted, or when supply receipt dates are moved, the system may create numerous fragmented records for each quantity split. 
This process will consolidate those similar records into a single entry.
Available from v1.0.9.0
