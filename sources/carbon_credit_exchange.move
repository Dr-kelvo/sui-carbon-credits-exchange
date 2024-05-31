module carbon_credit_exchange::carbon_credit_exchange {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    // Struct definitions

    // Struct to represent a contract
    public struct Contract has key, store {
        id: UID,
        bids: vector<Bid>,
        listings: vector<Listing>,
        escrow: Balance<SUI>,
    }

    // Struct to represent a carbon credit
    public struct CarbonCredit has key, store {
        id: UID,
        owner: address,
        quantity: u64,
        metadata: String,
    }

    // Struct to represent a listed carbon credit for sale
    public struct Listing has key, store {
        id: UID,
        credit_id: ID,
        owner: address,
        base_price: u64,
        active: bool,
    }

    // Struct to represent a bid on a carbon credit
    public struct Bid has key, store {
        id: UID,
        credit_id: ID,
        bidder: address,
        amount: u64,
        is_claimed: bool,
        highest_bid: u64, // Additional field to store the current highest bid
    }

    // Error codes
    const ENotOwner: u64 = 0;
    const EInactiveListing: u64 = 2;
    const EInsufficientBid: u64 = 3;
    const EInvalidBid: u64 = 4;
    const EClaimedBid: u64 = 5;

    // Functions for managing the carbon credit trading platform

    // initialize the contract
    fun init(
        ctx: &mut TxContext
    ) {
        let contract = Contract {
            id: object::new(ctx),
            bids: vector::empty<Bid>(),
            listings: vector::empty<Listing>(),
            escrow: balance::zero<SUI>(),
        };

        let contract_address = tx_context::sender(ctx);
        transfer::transfer(contract, contract_address);
    }

    // Function to register a new carbon credit
    public fun register_carbon_credit(
        owner: address,
        quantity: u64,
        metadata: String,
        ctx: &mut TxContext
    ) : CarbonCredit {
        let id = object::new(ctx);
        CarbonCredit {
            id,
            owner,
            quantity,
            metadata,
        }
    }

    // Function to list a carbon credit for sale
    public fun list_carbon_credit(
        contract: &mut Contract,
        credit: &mut CarbonCredit,
        base_price: u64,
        ctx: &mut TxContext
    ) : Listing {
        assert!(credit.owner == tx_context::sender(ctx), ENotOwner);

        let id = object::new(ctx);
        let listing = Listing {
            id,
            credit_id: object::id(credit),
            owner: credit.owner,
            base_price,
            active: true,
        };

        vector::push_back(&mut contract.listings, listing);
        listing
    }

    // deactivate listing
    public fun deactivate_listing(
        listing: &mut Listing,
        ctx: &mut TxContext
    ) {
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);
        listing.active = false;
    }

    // function to get all listings
    public fun get_listings(
        contract: &Contract,
    ) : vector<ID> {
        let mut listings = vector::empty<ID>();

        for listing in contract.listings.iter() {
            let id = object::uid_to_inner(&listing.id);
            vector::push_back(&mut listings, id);
        };

        listings
    }

    // Function to place a bid on a listed carbon credit
    public fun place_bid(
        contract: &mut Contract,
        listing: &Listing,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(listing.active, EInactiveListing);

        let amount_u64 = coin::value(&amount);
        assert!(amount_u64 >= listing.base_price, EInsufficientBid);

        let id = object::new(ctx);
        let bid = Bid {
            id,
            credit_id: listing.credit_id,
            bidder: tx_context::sender(ctx),
            amount: amount_u64,
            is_claimed: false,
            highest_bid: listing.base_price, // Initialize with the base price
        };

        let bid_amount = coin::into_balance(amount);
        balance::join(&mut contract.escrow, bid_amount);

        contract.bids.push_back(bid);
    }

    // Function to transfer ownership of the carbon credit
    public fun transfer_carbon_credit(
        contract: &mut Contract,
        listing: &mut Listing,
        bid: &mut Bid,
        credit: &mut CarbonCredit,
        ctx: &mut TxContext
    ) {
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);
        assert!(listing.active, EInactiveListing);
        assert!(bid.credit_id == object::id(credit), EInvalidBid);

        credit.owner = bid.bidder;
        listing.active = false;
        bid.is_claimed = true;
    }

    // Function to transfer the bid amount to the listing owner
    public fun transfer_bid_amount(
        contract: &mut Contract,
        listing: &Listing,
        bid: &mut Bid,
        ctx: &mut TxContext
    ) {
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);
        assert!(listing.active, EInactiveListing);
        assert!(bid.credit_id == listing.credit_id, EInvalidBid);

        let bid_payment = coin::take(&mut contract.escrow, bid.amount, ctx);
        transfer::public_transfer(bid_payment, listing.owner);
    }

    // withdraw bid
    public fun withdraw_bid(
        contract: &mut Contract,
        bid: &mut Bid,
        ctx: &mut TxContext
    ) {
        assert!(bid.bidder == tx_context::sender(ctx), ENotOwner);
        assert!(!bid.is_claimed, EClaimedBid);

        bid.is_claimed = true;

        let bid_amount = coin::take(&mut contract.escrow, bid.amount, ctx);
        transfer::public_transfer(bid_amount, bid.bidder);
    }
}
