// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    interface IVRFv2Consumer {
        function requestRandomWords() external returns (uint256 requestId);
        function setNum(uint32 _num) external ;
        function Winners() external view returns(uint [] memory _winners);   
    
    }

contract PrizeDistributionSystem {

    // Random Logic Functions
    //function uses interface to get random number from chainlink
    function randomWinners() external  returns(uint [] memory){
        uint[] memory arr = IVRFv2Consumer(chainLink).Winners();
        for(uint i = 0; i < arr.length; i++){
           uint a = arr[i];
           uint b = a % 10;
            winnigNumber.push(b);
            }
        //winning number is an array that will hold all the random numbers returned
        return (winnigNumber);
     }

    function generateRandomNumbers(uint32 _numword) external {
        // user specifies how many random numbers he want and calls the function to generate the numbers from the chainlink contract
        IVRFv2Consumer(chainLink).setNum(_numword);
        IVRFv2Consumer(chainLink).requestRandomWords();
    }

    IERC20 public rewardToken;
    address public owner;
    uint256 public nextParticipantId = 1; // Start participant IDs at 1

    struct Participant {
        uint256 id;
        uint256 entries;
        bool isRegistered;
    }

    // Mapping from participant address to their Participant struct
    mapping(address => Participant) public participants;
    // Mapping from participant ID to their address
    mapping(uint256 => address) public participantIds;

    event ParticipantRegistered(address participant, uint256 participantId);
    event ActivityParticipated(address participant, uint256 entries);

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
// ************************************************************************************************************************************* //
    function distributeRewards(uint256[] memory selectedWinnerIds) external onlyOwner {
    require(selectedWinnerIds.length > 0, "No winners selected");

    uint256 totalEntries = 0;
    uint256 totalPrizePool = 1000000 * (10 ** uint256(rewardToken.decimals())); // Assuming the token has 18 decimals

    // First, calculate the total number of entries for all selected winners
    for (uint256 i = 0; i < selectedWinnerIds.length; i++) {
        address winnerAddress = participantIds[selectedWinnerIds[i]];
        totalEntries += participants[winnerAddress].entries;
    }

    // Ensure the total entries is greater than zero to avoid division by zero
    require(totalEntries > 0, "Total entries must be greater than zero");

    // Now, distribute the rewards based on the number of entries
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

event RewardDistributed(address indexed winner, uint256 amount);


}
