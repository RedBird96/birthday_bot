module overmind::birthday_bot {
    use aptos_std::table;
    use aptos_std::table::Table;
    use std::signer;
    use std::error;
    use aptos_framework::account;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use std::string::{Self, String};

    //
    // Errors
    //
    const ERROR_DISTRIBUTION_STORE_EXIST: u64 = 0;
    const ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_LENGTHS_NOT_EQUAL: u64 = 2;
    const ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST: u64 = 3;
    const ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED: u64 = 4;

    //
    // Data structures
    //
    struct BirthdayGift has drop, store, copy {
        amount: u64,
        birthday_timestamp_seconds: u64,
    }

    struct DistributionStore has key {
        birthday_gifts: Table<address, BirthdayGift>,
        signer_capability: account::SignerCapability,
    }

    /// This turns a u128 into its UTF-8 string equivalent.
    public fun u128_to_string(value: u128): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    //
    // Assert functions
    //
    public fun assert_distribution_store_exists(
        account_address: address,
    ) {
        // TODO: assert that `DistributionStore` exists
        let store_exists = exists<DistributionStore>(account_address);
        assert!(store_exists, error::not_found(ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST));
    }

    public fun assert_distribution_store_does_not_exist(
        account_address: address,
    ) {
        // TODO: assert that `DistributionStore` does not exist
        let store_exists = exists<DistributionStore>(account_address);
        assert!(!store_exists, ERROR_DISTRIBUTION_STORE_EXIST);
    }

    public fun assert_lengths_are_equal(
        addresses: vector<address>,
        amounts: vector<u64>,
        timestamps: vector<u64>
    ) {
        // TODO: assert that the lengths of `addresses`, `amounts`, and `timestamps` are all equal
        let len = vector::length(&addresses);
        assert!(vector::length(&amounts) == len && vector::length(&timestamps) == len, ERROR_LENGTHS_NOT_EQUAL);
    }

    public fun assert_birthday_gift_exists(
        distribution_address: address,
        account_address: address,
    ) acquires DistributionStore {
        // TODO: assert that `birthday_gifts` exists
        let store = borrow_global<DistributionStore>(distribution_address);
        assert!(
            table::contains(&store.birthday_gifts, account_address), 
            ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST
        );   
    }

    public fun assert_birthday_timestamp_seconds_has_passed(
        distribution_address: address,
        account_address: address,
    ) acquires DistributionStore {
        // TODO: assert that the current timestamp is greater than or equal to `birthday_timestamp_seconds`
        assert_birthday_gift_exists(
            distribution_address,
            account_address
        );
        let store = borrow_global<DistributionStore>(distribution_address);
        let gift = table::borrow(&store.birthday_gifts, account_address);
        let current_timestamp = timestamp::now_seconds();
        assert!(
            gift.birthday_timestamp_seconds <= current_timestamp, 
            ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED);
    }

    //
    // Entry functions
    //
    /**
    * Initializes birthday gift distribution contract
    * @param account - account signer executing the function
    * @param addresses - list of addresses that can claim their birthday gifts
    * @param amounts  - list of amounts for birthday gifts
    * @param birthday_timestamps - list of birthday timestamps in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun initialize_distribution(
        account: &signer,
        addresses: vector<address>,
        amounts: vector<u64>,
        birthday_timestamps: vector<u64>
    ) {

        // TODO: check `DistributionStore` does not exist
        let account_address = signer::address_of(account);
        assert_distribution_store_does_not_exist(account_address);

        // TODO: check all lengths of `addresses`, `amounts`, and `birthday_timestamps` are equal
        assert_lengths_are_equal(addresses, amounts, birthday_timestamps);

        // TODO: create resource account
        let registry_seed = u128_to_string((timestamp::now_microseconds() as u128));
        string::append(&mut registry_seed, string::utf8(b"birthday_bot_seed"));        
        let (token_resource, signer_capability) = account::create_resource_account(account, *string::bytes(&registry_seed));

        // TODO: register Aptos coin to resource account
        coin::register<AptosCoin>(&token_resource); 

        // TODO: loop through the lists and push items to birthday_gifts table
        let birthday_gifts = table::new();
        let len = vector::length(&addresses);
        let index = 0;
        let sum_amount  : u64= 0;
        while (index < len) {
            let addr = *vector::borrow(&addresses, index);
            let amount = *vector::borrow(&amounts, index);
            sum_amount = sum_amount + amount;
            let birthday_timestamp_seconds = *vector::borrow(&birthday_timestamps, index);
            let birthday_gift = BirthdayGift { amount, birthday_timestamp_seconds };
            table::add(&mut birthday_gifts, addr, birthday_gift);
            index = index + 1;
        };

        // TODO: transfer the sum of all items in `amounts` from initiator to resource account
        let resource_address = signer::address_of(&token_resource);
        coin::transfer<AptosCoin>(account, resource_address, sum_amount);

        // TODO: move_to resource `DistributionStore` to account signer
        let distribution_store = DistributionStore { birthday_gifts, signer_capability };
        move_to(account, distribution_store);
    }

    /**
    * Add birthday gift to `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - address that can claim the birthday gift
    * @param amount  - amount for the birthday gift
    * @param birthday_timestamp_seconds - birthday timestamp in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun add_birthday_gift(
        account: &signer,
        claim_address: address,
        amount: u64,
        birthday_timestamp_seconds: u64
    ) acquires DistributionStore {

        // TODO: check that the distribution store exists      
        let account_address = signer::address_of(account);
        assert_distribution_store_exists(account_address);

        // TODO: set new birthday gift to new `amount` and `birthday_timestamp_seconds` (birthday_gift already exists, sum `amounts` and override the `birthday_timestamp_seconds`
        let distribution_store = borrow_global_mut<DistributionStore>(account_address);
        if (table::contains(&distribution_store.birthday_gifts, claim_address)) {
            let gift = table::borrow_mut(&mut distribution_store.birthday_gifts, claim_address);
            gift.amount = gift.amount + amount;
            gift.birthday_timestamp_seconds = birthday_timestamp_seconds;
            table::upsert(&mut distribution_store.birthday_gifts, claim_address, *gift);
        } else {
            let gift = BirthdayGift {
                amount,
                birthday_timestamp_seconds
            };
            table::upsert(&mut distribution_store.birthday_gifts, claim_address, gift);
        };

        // TODO: transfer the `amount` from initiator to resource account
        let resource_address = account::get_signer_capability_address(&distribution_store.signer_capability);
        coin::transfer<AptosCoin>(account, resource_address, amount);

    }

    /**
    * Remove birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - `birthday_gifts` address
    **/
    public entry fun remove_birthday_gift(
        account: &signer,
        claim_address: address,
    ) acquires DistributionStore {

        // TODO: check that the distribution store exists
        let account_address = signer::address_of(account);
        assert_distribution_store_exists(account_address);

        // TODO: if `birthday_gifts` exists, remove `birthday_gift` from table
        let distribution_store = borrow_global_mut<DistributionStore>(account_address);
        let gift = table::borrow(&mut distribution_store.birthday_gifts, claim_address);
        let amount = gift.amount;
        table::remove(&mut distribution_store.birthday_gifts, claim_address);

        // TODO: transfer `amount` from resource account to initiator
        let resource_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
        coin::transfer<AptosCoin>(&resource_signer, account_address, amount);
    }

    /**
    * Claim birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param distribution_address - distribution contract address
    **/
    public entry fun claim_birthday_gift(
        account: &signer,
        distribution_address: address,
    )  acquires DistributionStore {

        // TODO: check that the distribution store exists
        assert_distribution_store_exists(distribution_address);

        // TODO: check that the `birthday_gift` exists
        let account_address = signer::address_of(account);
        assert_birthday_gift_exists(distribution_address, account_address);

        let distribution_store = borrow_global_mut<DistributionStore>(distribution_address);
        let birthday_gift = table::borrow(&distribution_store.birthday_gifts, account_address);

        // TODO: check that the `birthday_timestamp_seconds` has passed
        let current_timestamp = timestamp::now_seconds();
        assert!(
            current_timestamp > birthday_gift.birthday_timestamp_seconds,
            ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED
        );

        //TODO: remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let claim_amount = birthday_gift.amount;
        let resource_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
        table::remove(&mut distribution_store.birthday_gifts, account_address);
        coin::transfer<AptosCoin>(&resource_signer, account_address, claim_amount);

    }
}
