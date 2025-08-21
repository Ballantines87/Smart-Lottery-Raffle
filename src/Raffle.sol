// SPDX-License-Identifier: MIT

/* Layout of the contract file: */
// version
// imports
// interfaces, libraries, contract

// Inside Contract:
// Errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @dev A simple contract for a raffle system - implements Chainlink VRF for randomness.
 * @author Paolo Montecchiani
 * @notice This contract is for creating a simple raffle system.
 */

contract Raffle is VRFConsumerBaseV2Plus {
    // Errors //
    error Raffle__SendMoreToEnterRaffle(uint256 sent, uint256 required);
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    // Type declarations //
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // State variables //
    uint256 private immutable i_entranceFee;
    /// @dev Our raffle will last i_interval seconds.
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit; // MAX amount of gas we're willing to pay for the callback request for the FulfillRandomWords function

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;

    RaffleState private s_raffleState; // start with OPEN state

    // Events //
    event Raffle__RaffleEntered(address indexed player);
    event Raffle_WinnerPicked(
        address indexed winnder,
        uint256 indexed requestId,
        uint256 indexed prizeAmount
    );
    event Raffle__RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN; // C for calculating the winner;
    }

    function enterRaffle() external payable {
        // participants must pay the entrance fee to enter the raffle
        // A) require(msg.value > 0, "You must send some ether to enter the raffle"); - Less gas efficient because you need to store a string
        // B) require(
        //     msg.value >= i_entranceFee,
        //     Raffle__SendMoreToEnterRaffle(msg.value, i_entranceFee)
        // ); - only works specific (newer) compiler versions of Solidity and still less gas efficient than below

        // ---------
        // Checks // -- e.g. require() or conditional statements
        // ---------
        if (msg.value <= i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle(msg.value, i_entranceFee);
        }

        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle__RaffleNotOpen();
        }

        // ---------
        // Effects (internal contract state changes)
        // ---------
        s_players.push(payable(msg.sender));
        emit Raffle__RaffleEntered(msg.sender);

        // ---------
        // Interactions (external contract interactions)
        // ---------
    }

    // Chainlink Automation compatible checkUpkeep function
    // This function is called by Chainlink Automation to check if upkeep is needed
    /**
     * @dev This function checks if the upkeep is needed for the raffle.
     * It checks the following conditions:
     * 1. If the raffle is open (not in calculating state).
     * 2. If enough time has passed since the last winner was picked.
     * 3. The contract has ETH
     * 4. Implicitly, your subsciption is funded with LINK
     * @param - IGNORED - This is the data that Chainlink Automation passes to the checkUpkeep function
     * @return upkeepNeeded - True if it's time to restart the raffle and pick a winner, false otherwise.
     * @return bytes memory performData - IGNORED - This is the data that Chainlink Automation passes to the performUpkeep function
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // 1. Check if the raffle is open
        // 2. Check if enough time has passed since the last winner was picked
        // 3. The contract has ETH (which means the raffle has participants)
        // 4. Implicitly, your subsciption is funded with/has LINK

        bool enoughTimeHasPassed = (block.timestamp - s_lastTimestamp) >=
            i_interval; // Enough time has passed since the last winner was picked
        bool lotteryIsOpen = s_raffleState == RaffleState.OPEN; // The raffle is open
        bool contractHasBalance = address(this).balance > 0; // The contract has ETH
        bool hasPlayers = s_players.length > 0; // There are players in the raffle

        upkeepNeeded =
            enoughTimeHasPassed &&
            lotteryIsOpen &&
            contractHasBalance &&
            hasPlayers;

        return (
            upkeepNeeded,
            "" // No data to pass to the performUpkeep function
        );
    }

    // Chainlink Automation compatible performUpkeep function
    // This function is called by Chainlink Automation to perform the upkeep
    /**
     *
     * @param - IGNORED- This is the data that Chainlink Automation passes to the performUpkeep function
     * @dev This function is called by Chainlink Automation to perform the upkeep.
     * It is called automatically by Chainlink Automation when the checkUpkeep function returns true.
     * It is used to pick a winner and reset the raffle for the next round.
     */
    function performUpkeep(bytes calldata /*performData*/) external {
        // 1. Get a random number
        // 2. Use the random number to select a winner from s_players
        // 3. Transfer the prize to the winner
        // 4. Reset the raffle for the next round
        // Note: all of this needs to be automatically/programmatically triggered/called by a Chainlink VRF callback

        // ---------
        // Checks // -- e.g. require() or conditional statements
        // ---------
        (bool upkeepNeeded, ) = checkUpkeep(""); // Call the checkUpkeep function to see if upkeep is needed
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        if (block.timestamp - s_lastTimestamp < i_interval) {
            revert Raffle__NotEnoughTimePassed();
        }

        // ---------
        // Effects (internal contract state changes)
        // ---------
        s_raffleState = RaffleState.CALCULATING;

        // ---------
        // Interactions (external contract interactions)
        // ---------
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, //gasLane - also the gas you are paying for the request
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit, // MAX amount of gas we're willing to pay for the callback request for the FulfillRandomWords function
                numWords: NUM_WORDS, // number of random words (n.d.r. random numbers) we want to get
                extraArgs: VRFV2PlusClient._argsToBytes( // we can pass extra arguments to the request
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // here true means paying the request in native currency (e.g. ETH), false means paying in LINK
                )
            })
        );

        // redundant, already emitted by the vrfCoordinator's requestRandomWords(...) function
        emit Raffle__RequestRaffleWinner(requestId);
    }

    // CEI Pattern for setting up Smart Contracts functions: Checks, Effects, Interactions
    // Checks: Check the state of the contract and the parameters
    // Effects: Change the state of the contract
    // Interactions: Interact with other contracts (e.g. transfer funds, call other

    // Callback function that Chainlink VRF will call with the random number
    // This function is called by the VRFCoordinatorV2Plus contract
    // It is called automatically by the Chainlink VRF Coordinator when the random number is ready
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        // 1. Get the random number from the randomWords array
        // 2. Use the random number to select a winner from s_players
        // 3. Transfer the prize to the winner
        // 4. Reset the raffle for the next round

        // ---------
        // Checks // -- e.g. require() or conditional statements
        // ---------

        // ---------
        // Effects (internal contract state changes)
        // ---------
        uint winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        // Reset the players array for the next round
        s_players = new address payable[](0);

        // change the raffle state to open for the next round
        s_raffleState = RaffleState.OPEN;

        // Reset the last timestamp to the current block timestamp
        s_lastTimestamp = block.timestamp;
        uint256 prizeAmount = address(this).balance;
        // Emit an event for the winner
        emit Raffle_WinnerPicked(recentWinner, requestId, prizeAmount);

        // ---------
        // Interactions (external contract interactions)
        // ---------
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); // transfer the entire balance of the contract to the winner
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /*
    Getter Functions
    */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(
        uint256 indexOfPlayer
    ) external view returns (address payable player) {
        return s_players[indexOfPlayer];
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }
}
