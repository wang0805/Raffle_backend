// raffle

// enter the lottery (paying some ammount)
//pick a random winner
//winner to be selected at a specific time interval

//chainlink oracle for randomness

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";


error Raffle__NotEnoughETHEntered(); //for lower gas
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    //type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //state variable
    uint256 private immutable i_entranceFee; // immutable save gas
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimits;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval; //immutable if we dont intend to change it

    // events
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(address vrfCoordinatorV2, uint256 entranceFee, bytes32 gaslane, uint64 subscriptionId, uint32 callbackGasLimits, uint256 interval) VRFConsumerBaseV2(vrfCoordinatorV2){
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId; 
        i_callbackGasLimits = callbackGasLimits;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable{
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughETHEntered();
        }
        s_players.push(payable(msg.sender));

        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        // emit an event when we update a dynamic aray or mapping
        // named events with the function name reversed
        emit RaffleEnter(msg.sender);
    } 

    // function requestRandomWinner() external{
    //         s_raffleState = RaffleState.CALCULATING;
    //         uint256 requestId = i_vrfCoordinator.requestRandomWords(
    //         i_gaslane, //gaslane
    //         i_subscriptionId,
    //         REQUEST_CONFIRMATIONS,
    //         i_callbackGasLimits,
    //         NUM_WORDS
    //     );
    //     emit RequestedRaffleWinner(requestId); 
    // }

    //override bcos its virtual function on the VRF sol file
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); //reset the players inside to 0 again for next round
        s_lastTimeStamp = block.timestamp;
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
         emit WinnerPicked(recentWinner);
    }

    /** 
    * @dev this is the function that the chainlink keeper node calls 
    * they look for the 'upkeepneeded' to return true
    * the following needs to be true in order to return true
    * 1. our time interval has to be elapsed
    * 2. the lottery should have at least 1 player and have some ETH
    * 3. the subscription must be funded with some LINK
    * 4.  lottery should be in open state
    */

    function checkUpkeep(
        bytes memory /* checkData > have to change from calldata to memory as calldata only available for external function calls!! */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        // if ((block.timestamp - lastTimeStamp) > interval) {
        //     lastTimeStamp = block.timestamp;
        //     counter = counter + 1;
        // }

        //to only call when checkUpKeep is true;
      
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
 
        //request
        s_raffleState = RaffleState.CALCULATING;
        
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane, //gaslane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimits,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId); 
    }

    /* view/pure function */
function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

}