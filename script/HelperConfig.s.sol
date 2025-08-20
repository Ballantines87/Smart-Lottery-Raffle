// SPDX-License-Identifier: MIT

// Here (n.d.r. in this script?) we will:
// 1. Deploy mocks when we're on a local Anvil chain
// 2. Keep track of contract addresses across different chains - e.g.
//   - Sepolia ETH/USD Price Feed Address
//   - Mainnet ETH/USD Price Feed Address
//   - etc...

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

// import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

abstract contract CodeConstants {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_LOCAL_CHAIN_ID = 31337;

    /* VRF Mock Values */
    uint96 public constant BASE_FEE_MOCK = 0.25 ether;
    uint96 public constant GAS_PRICE_MOCK = 1e9;
    int256 public constant WEI_PER_UNIT_LINK_MOCK = 4e15;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId(uint256 chainId);

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    struct NetworkConfig {
        uint256 entranceFee;
        address vrfCoordinator;
        bytes32 keyHashGasLane;
        uint256 subscriptionId;
        uint256 interval;
        uint32 callbackGasLimit; // Gas limit for the callback function
        address linkTokenContract;
    }

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig(); // Sepolia
    }

    function getConfigByChainId(
        uint256 chainId
    ) private returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == ANVIL_LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Sepolia VRF Coordinator
                keyHashGasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Sepolia Key Hash - aka the Gas Lane
                subscriptionId: 32275225250417367007975148958931003992189498697624601186611555273111010214775, // subscription created at Chainlink
                interval: 30, // 30 seconds
                callbackGasLimit: 500000, // 500,000 gas for the callback function
                linkTokenContract: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilEthConfig()
        private
        returns (NetworkConfig memory)
    {
        // check to see if we have already created the Anvil config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // else create it, deploy mocks, etc...
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            BASE_FEE_MOCK,
            GAS_PRICE_MOCK,
            WEI_PER_UNIT_LINK_MOCK
        );
        LinkToken linkToken = new LinkToken();
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, // No price feed on Anvil
            vrfCoordinator: address(vrfCoordinatorMock), // Mock VRF Coordinator address
            keyHashGasLane: bytes32(0), // Mock Key Hash - doesn't matter on Anvil
            subscriptionId: 0, // might have to fix this
            interval: 30, // 30 seconds
            callbackGasLimit: 500000, // does not matter on Anvil
            linkTokenContract: address(linkToken) // our own fake/mock LINK token from our test/mocks folder
        });
        vm.stopBroadcast();
        return localNetworkConfig;
    }
}
