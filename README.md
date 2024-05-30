# Carbon Credit Exchange Sui Module

This module implements a carbon credit trading platform on the Sui blockchain. It allows users to register carbon credits, list them for sale, place bids on listings, and accept bids to transfer ownership.

**Key Features:**

* **Carbon Credit Registration:** Users can register new carbon credits with unique identifiers, quantities, and metadata.
* **Listing Management:** Owners can list their carbon credits for sale, setting a base price and activating/deactivating listings.
* **Bidding System:** Users can place bids on active listings, specifying the amount of SUI tokens they are willing to pay.
* **Bid Acceptance:** Listing owners can accept bids, transferring ownership of the carbon credit and receiving the bid amount.
* **Bid Withdrawal:** Bidders can withdraw their bids if they haven't been accepted.

**Data Structures:**

* **Contract:** Represents the overall carbon credit exchange contract with:
  * `id`: Unique identifier for the contract.
  * `bids`: Vector of all bids placed on the platform.
  * `listings`: Vector of all active carbon credit listings.
  * `escrow`: Balance of SUI tokens held in escrow for bids.
* **CarbonCredit:** Represents a carbon credit with:
  * `id`: Unique identifier for the carbon credit.
  * `owner`: Address of the current owner.
  * `quantity`: Number of carbon credits.
  * `metadata`: Additional information about the carbon credit.
* **Listing:** Represents a listed carbon credit for sale with:
  * `id`: Unique identifier for the listing.
  * `credit_id`: ID of the carbon credit being listed.
  * `owner`: Address of the listing owner.
  * `base_price`: Minimum price for the carbon credit.
  * `active`: Status of the listing (active or inactive).
* **Bid:** Represents a bid on a carbon credit with:
  * `id`: Unique identifier for the bid.
  * `credit_id`: ID of the carbon credit being bid on.
  * `bidder`: Address of the bidder.
  * `amount`: Amount of SUI tokens offered in the bid.
  * `is_claimed`: Whether the bid amount has been claimed.

**Error Codes:**

* `ENotOwner (0)`: Indicates the caller is not authorized to perform the action on the specified object (e.g., listing, bid).
* `EInactiveListing (2)`: Indicates the attempted action involves an inactive listing.
* `EInsufficientBid (3)`: Indicates the bid amount is less than the base price of the listing.
* `EInvalidBid (4)`: Indicates the bid is associated with a different carbon credit.
* `EClaimedBid (5)`: Indicates the bid amount has already been claimed.
* `ENoListings (6)`: Indicates there are no active listings on the contract.

**Functions:**

* **init (ctx: &mut TxContext):** Initializes a new carbon credit exchange contract.
* **register_carbon_credit (owner: address, quantity: u64, metadata: String, ctx: &mut TxContext): CarbonCredit:** Registers a new carbon credit and returns its details.
* **list_carbon_credit (contract: &mut Contract, credit: &mut CarbonCredit, base_price: u64, ctx: &mut TxContext):** Lists a carbon credit for sale on the contract.
* **deactivate_listing (listing: &mut Listing, ctx: &mut TxContext):** Deactivates a listed carbon credit.
* **get_listings (contract: &Contract): vector<ID>:** Returns a vector of IDs for all active listings on the contract.
* **place_bid (contract: &mut Contract, listing: &Listing, amount: Coin<SUI>, ctx: &mut TxContext):** Places a bid on an active listing.
* **accept_bid (contract: &mut Contract, listing: &mut Listing, bid: &mut Bid, credit: &mut CarbonCredit, ctx: &mut TxContext):** Accepts a bid, transferring ownership of the carbon credit and receiving the bid amount.
* **withdraw_bid (contract: &mut Contract, bid: &mut Bid, ctx: &mut TxContext):** Allows a bidder to withdraw their bid if it hasn't been accepted.

**Additional Notes:**

* This module utilizes Sui Move concepts like objects, vectors, and balances.
* The code includes error handling and access control mechanisms.
* For further details and usage examples, refer to the specific implementation within the `carbon_credit_exchange` module.

**Dependencies:**

* This module requires the `sui` and `candid` crates for Sui blockchain interaction and data serialization.

get more info at [dacade](https://dacade.org/communities/sui/challenges/19885730-fb83-477a-b95b-4ab265b61438/learning-modules/fc2e67a1-520d-4fae-a318-38414babc803)
