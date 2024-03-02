// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    interface IVRFv2Consumer {
        function requestRandomWords() external returns (uint256 requestId);
        function setNum(uint32 _num) external ;
        function Winners() external view returns(uint [] memory _winners);   
    
    }
contract PrizeDistributionSystem {
    IERC20 public rewardToken;
    address public owner;
    uint256 public nextParticipantId = 1; // Start participant IDs at 1

    struct Participant {
        uint256 id;
        uint256 entries;
        bool isRegistered;
    }

    uint[] public winningNumbers;

    // Mapping from participant address to their Participant struct
    mapping(address => Participant) public participants;
    // Mapping from participant ID to their address
    mapping(uint256 => address) public participantIds;

    event ParticipantRegistered(address participant, uint256 participantId);
    event ActivityParticipated(address participant, uint256 entries);
    event RewardDistributed(address indexed winner, uint256 amount);

     address chainLink = 0x1126d0f545350da14fb54e960eaf4f5b030cc451; //Address of chainlink contract that would generate random Numbers

    function generateRandomNumbers(uint32 _numword) external onlyOwner {
   // user specifies how many random numbers he want and calls the function to generate the numbers from the chainlink contract
        IVRFv2Consumer(chainLink).setNum(_numword);
        IVRFv2Consumer(chainLink).requestRandomWords();
    }

     //function uses interface to get random number from chainlink
    function randomWinners(uint256 _range) external onlyOwner  returns(uint [] memory){
         // Clear the winningNumbers array from previous data
        delete winningNumbers;

        uint[] memory arr = IVRFv2Consumer(chainLink).Winners();
        for(uint i = 0; i < arr.length; i++){
           uint a = arr[i];
           uint b = a % _range;
            winningNumbers.push(b);
            }
        //winning number is an array that will hold all the random numbers returned
        return (winningNumbers);
     }
    
    constructor(address _rewardTokenAddress) {
        rewardToken = IERC20(_rewardTokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    function registerParticipant() external {
        require(!participants[msg.sender].isRegistered, "Already registered");

        uint256 participantId = nextParticipantId++;
        participants[msg.sender] = Participant({
            id: participantId,
            entries: 0,
            isRegistered: true
        });
        participantIds[participantId] = msg.sender;

        emit ParticipantRegistered(msg.sender, participantId);
    }

    function participateInActivity(uint256 _entries) external {
        require(participants[msg.sender].isRegistered, "Not registered");
        require(_entries > 0, "Must participate with at least one entry");

        participants[msg.sender].entries += _entries;
        emit ActivityParticipated(msg.sender, _entries);
    }

    // Function to retrieve the random winners and distribute rewards
    function retrieveAndDistributeRewards(uint256 _range) external onlyOwner {
        // Retrieve the array of random numbers from the random number generator
        uint[] memory randomNumbers = IVRFv2Consumer(chainLink).Winners();

        // Initialize an array to store the winner IDs
        uint256[] memory winnerIds = new uint256[](randomNumbers.length);

        // Process the random numbers to get valid participant IDs
        for (uint256 i = 0; i < randomNumbers.length; i++) {
            // Ensure the random number corresponds to a valid participant ID
            uint256 winnerId = randomNumbers[i] % _range + 1; // +1 to avoid zero ID
            require(participantIds[winnerId] != address(0), "Invalid participant ID");

            winnerIds[i] = winnerId;
        }

    function distributeRewards(uint256[] memory selectedWinnerIds) external onlyOwner {
        require(selectedWinnerIds.length > 0, "No winners selected");

        uint256 totalEntries = 0;
        uint256 totalPrizePool = 1000000 * (10 ** uint256(rewardToken.decimals())); // Assuming the token has 18 decimals

        // Calculate the total number of entries for all selected winners
        for (uint256 i = 0; i < selectedWinnerIds.length; i++) {
            address winnerAddress = participantIds[selectedWinnerIds[i]];
            totalEntries += participants[winnerAddress].entries;
        }

        require(totalEntries > 0, "Total entries must be greater than zero");

        // Distribute the rewards based on the number of entries
        for (uint256 i = 0; i < selectedWinnerIds.length; i++) {
            address winnerAddress = participantIds[selectedWinnerIds[i]];
            uint256 winnerEntries = participants[winnerAddress].entries;

            // Calculate the winner's share of the prize pool
            uint256 winnerShare = (totalPrizePool * winnerEntries) / totalEntries;

            // Transfer the reward tokens to the winner
            require(rewardToken.transfer(winnerAddress, winnerShare), "Reward transfer failed");

            // Emit an event for transparency and record-keeping
            emit RewardDistributed(winnerAddress, winnerShare);

            // Reset the winner's entries to zero
            participants[winnerAddress].entries = 0;
        }
    }
}