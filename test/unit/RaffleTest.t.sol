// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle, HelperConfig} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract RaffleTest is Test {
    Raffle public raffleContract;
    HelperConfig public helperConfig;
    uint256 entranceFee;
    address vrfCoordinator;
    bytes32 keyHashGasLane;
    uint256 subscriptionId;
    uint256 interval;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    address public PLAYER_2 = makeAddr("player2");
    address public PLAYER_3 = makeAddr("player3");

    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    // Events // -- these need to be copy-pasted UNFORTUNATELY from the Raffle contract
    // to the test contract to be used in vm.expectEmit
    // This is a limitation of Foundry's testing framework
    event Raffle__RaffleEntered(address indexed player);
    event Raffle_WinnerPicked(
        address indexed winnder,
        uint256 indexed requestId,
        uint256 indexed prizeAmount
    );

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffleContract, helperConfig) = deployer.deployRaffleContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        vrfCoordinator = config.vrfCoordinator;
        keyHashGasLane = config.keyHashGasLane;
        subscriptionId = config.subscriptionId;
        interval = config.interval;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // Give PLAYER some ether for testing
        vm.deal(PLAYER_2, STARTING_PLAYER_BALANCE); // Give PLAYER_2 some ether for testing
        vm.deal(PLAYER_3, STARTING_PLAYER_BALANCE); // Give PLAYER_3 some ether for testing
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffleContract.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testLowEntranceFeeReverts() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__SendMoreToEnterRaffle.selector, // Custom error for low entrance fee
                entranceFee - 1, // Less than the required entrance fee
                entranceFee // The required entrance fee
            )
        );
        raffleContract.enterRaffle{value: entranceFee - 1}();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee + 1}();
        address payable[] memory rafflePlayers = raffleContract.getPlayers();
        assertEq(rafflePlayers.length, 1); // Check if one player is recorded
        assertEq(raffleContract.getPlayer(0), PLAYER); // Check if the player is recorded
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffleContract));
        emit Raffle__RaffleEntered(PLAYER);
        raffleContract.enterRaffle{value: entranceFee + 1}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // ARRANGE - we make sure we have some players already in the raffle
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee + 1}();
        vm.prank(PLAYER_2);
        raffleContract.enterRaffle{value: entranceFee + 1}();

        // foundry cheat code that we set the block timestamp to
        // the actual block + the time interval + 1 second
        // to make sure enough time has passed (more than the interval == 30 seconds)
        // and such that the conditions are met to start calculating the lottery winner
        // and change the raffle state to calculating
        vm.warp(block.timestamp + interval + 1);

        // foundry cheat code used to change the block.number
        // we set it to block.number + 1 to simulate not just the time changed but also
        // the block number (we don't really need this here, but it's good practice)
        vm.roll(block.number + 1);

        // ACT
        raffleContract.performUpkeep("");

        // ASSERT
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__RaffleNotOpen.selector)
        );
        vm.prank(PLAYER_3);
        raffleContract.enterRaffle{value: entranceFee + 1}();
    }
}
