// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        // Deploy the Raffle contract
        deployRaffleContract();
    }

    function deployRaffleContract() public returns (Raffle, HelperConfig) {
        HelperConfig config = new HelperConfig();

        // Get the configuration for the current chain
        // This will return the NetworkConfig for the current chain
        // e.g. Sepolia, Anvil, etc.
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        if (networkConfig.subscriptionId == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (uint256 subId, ) = createSubscription.createSubscription(
                networkConfig.vrfCoordinator
            );

            networkConfig.subscriptionId = subId;
            // fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubcription(
                networkConfig.vrfCoordinator,
                networkConfig.subscriptionId,
                networkConfig.linkTokenContract
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.keyHashGasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        // add consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId
        );

        return (raffle, config);
    }
}
