module carbon_credit_exchange::carbon_credit_exchange {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::event;
    use std::vector;

    // Error Definitions
    const ENotOwner: u64 = 0;
    const EInactiveListing: u64 = 2;
    const EInsufficientBid: u64 = 3;
    const EInvalidBid: u64 = 4;
    const EClaimedBid: u64 = 5;
    const ENoListings: u64 = 6;

    // Struct Definitions
    public struct Contract has key, store {
        id: UID,
        bids: vector<Bid>,
        listings: vector<Listing>,
        escrow: Balance<SUI>,
    }

    public struct CarbonCredit has key, store {
        id: UID,
        owner: address,
        quantity: u64,
        metadata: String,
    }

    public struct Listing has key, store {
        id: UID,
        credit_id: UID,
        owner: address,
        base_price: u64,
        active: bool,
    }

    public struct Bid has key, store {
        id: UID,
        credit_id: UID,
        bidder: address,
        amount: u64,
        is_claimed: bool,
    }

    // Event Definitions
    struct ContractInitialized has copy, drop { id: UID, owner: address }
    struct CarbonCreditRegistered has copy, drop { id: UID, owner: address, quantity: u64, metadata: String }
    struct CarbonCreditListed has copy, drop { id: UID, credit_id: UID, owner: address, base_price: u64 }
    struct ListingDeactivated has copy, drop { id: UID }
    struct BidPlaced has copy, drop { id: UID, credit_id: UID, bidder: address, amount: u64 }
    struct BidAccepted has copy, drop { listing_id: UID, bid_id: UID, new_owner: address }
    struct BidWithdrawn has copy, drop { id: UID, bidder: address, amount: u64 }

    // Initialize the contract
    public fun init(ctx: &mut TxContext) {
        let contract = Contract {
            id: object::new(ctx),
            bids: vector::empty<Bid>(),
            listings: vector::empty<Listing>(),
            escrow: balance::zero<SUI>(),
        };

        let contract_address = tx_context::sender(ctx);
        transfer::transfer(contract, contract_address);

        event::emit(ContractInitialized {
            id: object::id(&contract),
            owner: contract_address,
        });
    }

    // Register a new carbon credit
    public fun register_carbon_credit(owner: address, quantity: u64, metadata: String, ctx: &mut TxContext): CarbonCredit {
        let id = object::new(ctx);
        let carbon_credit = CarbonCredit {
            id,
            owner,
            quantity,
            metadata,
        };

        event::emit(CarbonCreditRegistered {
            id,
            owner,
            quantity,
            metadata: metadata.clone(),
        });

        carbon_credit
    }

    // List a carbon credit for sale
    public fun list_carbon_credit(contract: &mut Contract, credit: &mut CarbonCredit, base_price: u64, ctx: &mut TxContext) {
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

        event::emit(CarbonCreditListed {
            id,
            credit_id: object::id(credit),
            owner: credit.owner,
            base_price,
        });
    }

    // Deactivate a listing
    public fun deactivate_listing(listing: &mut Listing, ctx: &mut TxContext) {
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);
        listing.active = false;

        event::emit(ListingDeactivated { id: object::id(listing) });
    }

    // Get all listings
    public fun get_listings(contract: &Contract): vector<UID> {
        let mut listings = vector::empty<UID>();
        let len = vector::length(&contract.listings);
        assert!(len > 0, ENoListings);

        let mut i = 0_u64;
        while (i < len) {
            let listing = &contract.listings[i];
            let id = object::id(listing);
            vector::push_back(&mut listings, id);
            i = i + 1;
        }

        listings
    }

    // Place a bid on a listed carbon credit
    public fun place_bid(contract: &mut Contract, listing: &Listing, amount: Coin<SUI>, ctx: &mut TxContext) {
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
        };

        let bid_amount = coin::into_balance(amount);
        balance::join(&mut contract.escrow, bid_amount);

        vector::push_back(&mut contract.bids, bid);

        event::emit(BidPlaced {
            id,
            credit_id: listing.credit_id,
            bidder: tx_context::sender(ctx),
            amount: amount_u64,
        });
    }

    // Accept a bid and transfer ownership of the carbon credit
    public fun accept_bid(contract: &mut Contract, listing: &mut Listing, bid: &mut Bid, credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(listing.owner == tx_context::sender(ctx), ENotOwner);
        assert!(listing.active, EInactiveListing);
        assert!(bid.credit_id == object::id(credit), EInvalidBid);

        let bid_payment = coin::take(&mut contract.escrow, bid.amount, ctx);
        transfer::public_transfer(bid_payment, listing.owner);

        credit.owner = bid.bidder;
        listing.active = false;
        bid.is_claimed = true;

        event::emit(BidAccepted {
            listing_id: object::id(listing),
            bid_id: object::id(bid),
            new_owner: bid.bidder,
        });
    }

    // Withdraw a bid
    public fun withdraw_bid(contract: &mut Contract, bid: &mut Bid, ctx: &mut TxContext) {
        assert!(bid.bidder == tx_context::sender(ctx), ENotOwner);
        assert!(!bid.is_claimed, EClaimedBid);

        bid.is_claimed = true;

        let bid_amount = coin::take(&mut contract.escrow, bid.amount, ctx);
        transfer::public_transfer(bid_amount, bid.bidder);

        event::emit(BidWithdrawn {
            id: object::id(bid),
            bidder: bid.bidder,
            amount: bid.amount,
        });
    }
}
