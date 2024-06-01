module carbon_credit_exchange::carbon_credit_exchange {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    // use sui::clock::{Self, Clock}; 

    // Struct definitions

    // Struct to represent a contract
    public struct Contract has key, store {
        id: UID, // Unique identifier for the contract
        bids: vector<Bid>, // Vector of bids on the contract
        listings: vector<Listing>, // Vector of listings on the contract
        escrow: Balance<SUI>, // Balance of SUI tokens in the contract
    }

    // Struct to represent a carbon credit
    public struct CarbonCredit has key, store {
        id: UID, // Unique identifier for the carbon credit
        owner: address, // Owner of the carbon credit
        quantity: u64, // Quantity of carbon credits
        metadata: String, // Metadata about the carbon credit
    }

    // Struct to represent a listed carbon credit for sale
    public struct Listing has key, store {
        id: UID, // Unique identifier for the listing
        credit_id: ID, // ID of the carbon credit being listed
        owner: address, // Owner of the listing
        base_price: u64, // Fixed base price for the carbon credit
        active: bool, // Status of the listing
    }

    // Struct to represent a bid on a carbon credit
    public struct Bid has key, store {
        id: UID, // Unique identifier for the bid
        credit_id: ID, // ID of the carbon credit being bid on
        bidder: address, // Address of the bidder
        amount: u64, // Amount of the bid in SUI tokens
        is_claimed: bool, // Status of the bid escrow claim
    }

    // Error definitions
    const ENotOwner: u64 = 0;
    const EInactiveListing: u64 = 2;
    const EInsufficientBid: u64 = 3;
    const EInvalidBid: u64 = 4;
    const EClaimedBid: u64 = 5;
    const ENoListings: u64 = 6;

    // Functions for managing the carbon credit trading platform

    // Initialize the contract
    public fun init(
        ctx: &mut TxContext
    ) {
        // Create a new contract object
        let contract = Contract {
            id: object::new(ctx),
            bids: vector::empty<Bid>(),
            listings: vector::empty<Listing>(),
            escrow: balance::zero<SUI>(),
        };

        let contract_address = tx_context::sender(ctx);

        // Transfer the contract object to the contract owner
        transfer::transfer(contract, contract_address);
    }

    // Function to register a new carbon credit
    public fun register_carbon_credit(
        owner: address,
        quantity: u64,
        metadata: String,
        ctx: &mut TxContext
    ) : CarbonCredit {
        let id = object::new(ctx); // Generate a new unique ID
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
    ) {
        // Ensure the caller is the owner of the carbon credit
        assert!(credit.owner == tx_context::sender(ctx), ENotOwner);

        let id = object::new(ctx); // Generate a new unique ID
        let listing = Listing {
            id,
            credit_id: object::id(credit),
            owner: credit.owner,
            base_price,
            active: true, // Set the listing as active
        };

        // Add the listing to the contract
        vector::push_back(&mut contract.listings, listing);
    }

    // Function to deactivate a listing
    public fun deactivate_listing(
        listing: &mut Listing,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the listing
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);

        // Mark the listing as inactive
        listing.active = false;
    }

    // Function to get all listings
    public fun get_listings(
        contract: &Contract,
    ) : vector<ID> {
        let mut listings = vector::empty<ID>();
        let len: u64 = vector::length(&contract.listings);

        assert!(len > 0, ENoListings);

        let mut i = 0_u64;

        while (i < len) {
            let listing = &contract.listings[i];
            let id = object::uid_to_inner(&listing.id);

            vector::push_back(&mut listings, id);

            i = i + 1;
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
        // Ensure the listing is active
        assert!(listing.active, EInactiveListing);

        let amount_u64 = coin::value(&amount);

        // Ensure the bid amount is greater than or equal to the base price
        assert!(amount_u64 >= listing.base_price, EInsufficientBid);

        let id = object::new(ctx); // Generate a new unique ID
        let bid = Bid {
            id,
            credit_id: listing.credit_id,
            bidder: tx_context::sender(ctx),
            amount: amount_u64,
            is_claimed: false,
        };

        // Transfer the bid amount to the escrow
        let bid_amount = coin::into_balance(amount);
        balance::join(&mut contract.escrow, bid_amount);

        // Add the bid to the contract
        vector::push_back(&mut contract.bids, bid);
    }

    // Function to accept a bid and transfer ownership of the carbon credit
    public fun accept_bid(
        contract: &mut Contract,
        listing: &mut Listing,
        bid: &mut Bid,
        credit: &mut CarbonCredit,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the listing
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);
        // Ensure the listing is active
        assert!(listing.active, EInactiveListing);
        // Ensure the bid is valid
        assert!(bid.credit_id == object::id(credit), EInvalidBid);

        // Transfer the bid amount to the listing owner
        let bid_payment = coin::take(&mut contract.escrow, bid.amount, ctx);
        transfer::public_transfer(bid_payment, listing.owner);

        // Transfer the ownership of the carbon credit to the bidder
        credit.owner = bid.bidder;

        // Mark the listing as inactive
        listing.active = false;

        // Mark the bid as claimed
        bid.is_claimed = true;
    }

    // Function to withdraw a bid
    public fun withdraw_bid(
        contract: &mut Contract,
        bid: &mut Bid,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the bidder
        assert!(bid.bidder == tx_context::sender(ctx), ENotOwner);

        // Ensure the bid is not already claimed
        assert!(!bid.is_claimed, EClaimedBid);

        // Mark the bid as claimed
        bid.is_claimed = true;

        // Transfer the bid amount back to the bidder
        let bid_amount = coin::take(&mut contract.escrow, bid.amount, ctx);
        transfer::public_transfer(bid_amount, bid.bidder);
    }
}
